module Train.Execution exposing (stepProgram)

{-| Program execution engine for active trains.

Each tick, trains with a program advance through their orders:

  - MoveTo: Accelerate toward target, decelerate to stop at destination.
    MoveTo a station portal at the matching end of the route departs
    through it: the train keeps going and is despawned by the simulation.
  - SetReverser: Instant, advances immediately
  - SetSwitch: Returns effect for Main to apply, advances immediately
  - WaitSeconds: Counts down timer, advances when done
  - Couple/Uncouple: Stops with error (not yet implemented)

-}

import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotTarget(..))
import Train.Route as Route exposing (TrackContext)
import Train.Stock exposing (carCenterOffset)
import Train.Types exposing (ActiveTrain, Effect(..), TrainState(..))


{-| Acceleration rate in m/s^2 (simple linear acceleration).
-}
acceleration : Float
acceleration =
    2.0


{-| Braking deceleration rate in m/s^2.
-}
braking : Float
braking =
    3.0


{-| Emergency braking deceleration rate in m/s^2.
-}
emergencyBraking : Float
emergencyBraking =
    5.0


{-| Distance threshold for considering a train "at" its target (meters).
-}
arrivalThreshold : Float
arrivalThreshold =
    0.5


{-| Maximum speed in m/s (~40 km/h).
-}
maxSpeed : Float
maxSpeed =
    40.0 * 1000.0 / 3600.0


{-| Step the program execution for a train.

Returns the updated train and any side effects.

-}
stepProgram : TrackContext -> Float -> ActiveTrain -> ( ActiveTrain, List Effect )
stepProgram ctx deltaSeconds train =
    case train.trainState of
        Executing ->
            executeCurrentOrder ctx deltaSeconds train

        WaitingForOrders ->
            if List.isEmpty train.program then
                -- No program: run through at constant speed
                ( runThrough ctx deltaSeconds train, [] )

            else
                -- Program complete: coast to stop
                ( coastToStop ctx deltaSeconds train, [] )

        Stopped _ ->
            -- Train is stopped with an error
            ( { train | speed = 0 }, [] )


{-| Execute the current order based on programCounter.
-}
executeCurrentOrder : TrackContext -> Float -> ActiveTrain -> ( ActiveTrain, List Effect )
executeCurrentOrder ctx deltaSeconds train =
    case getOrder train.programCounter train.program of
        Nothing ->
            -- Program complete
            ( coastToStop ctx deltaSeconds { train | trainState = WaitingForOrders }, [] )

        Just order ->
            case order of
                MoveTo spotId spotTarget ->
                    executeMoveTo ctx deltaSeconds spotId spotTarget train

                SetReverser pos ->
                    -- Instant: set reverser and advance
                    ( advanceProgram { train | reverser = pos }, [] )

                SetSwitch switchId pos ->
                    -- Instant: emit effect and advance
                    ( advanceProgram train, [ SetSwitchEffect switchId pos ] )

                WaitSeconds seconds ->
                    executeWait deltaSeconds seconds train

                Couple ->
                    -- Coupling requires standing consists on the map.
                    -- Until standing consist tracking is implemented, stop with error.
                    ( { train
                        | speed = 0
                        , trainState = Stopped "Couple: no adjacent cars found"
                      }
                    , []
                    )

                Uncouple _ ->
                    -- Uncoupling requires standing consist tracking.
                    -- Until implemented, stop with error.
                    ( { train
                        | speed = 0
                        , trainState = Stopped "Uncouple: not yet supported"
                      }
                    , []
                    )


{-| Execute a MoveTo order: accelerate toward target, brake to stop.
-}
executeMoveTo : TrackContext -> Float -> String -> SpotTarget -> ActiveTrain -> ( ActiveTrain, List Effect )
executeMoveTo ctx deltaSeconds spotId spotTarget train =
    case Route.spotPosition ctx spotId train.route of
        Nothing ->
            -- Spot not reachable on this route
            ( stopWithError ("Cannot reach " ++ spotId) train, [] )

        Just spotDistance ->
            if isExitPortal ctx spotId spotDistance train then
                ( departThroughPortal deltaSeconds train, [] )

            else
                let
                    -- Compute offset for car-specific spotting
                    -- The train head needs to be ahead of the car center by the offset
                    targetDistance =
                        case spotTarget of
                            TrainHead ->
                                spotDistance

                            SpotCar carIndex ->
                                case carCenterOffset carIndex train.consist of
                                    Just offset ->
                                        spotDistance + offset

                                    Nothing ->
                                        -- Invalid car index, fall back to train head
                                        spotDistance
                in
                if targetDistance < 0 || targetDistance > train.route.totalLength then
                    -- Spotting that car would put the head beyond the end of the track
                    ( stopWithError ("Cannot spot at " ++ spotId ++ ": not enough track") train, [] )

                else
                    ( moveTowards ctx deltaSeconds spotId targetDistance train, [] )


{-| Drive toward `targetDistance` and come to rest there.

Speed is capped at what can still be braked away in the remaining distance,
and a tick whose movement would reach or cross the target arrives, so coarse
time steps cannot overshoot.

-}
moveTowards : TrackContext -> Float -> String -> Float -> ActiveTrain -> ActiveTrain
moveTowards ctx deltaSeconds spotId targetDistance train =
    let
        directionSign =
            reverserSign train

        -- Signed distance to target (positive = target is ahead in travel direction)
        distanceToTarget =
            (targetDistance - train.position) * directionSign
    in
    if abs distanceToTarget < arrivalThreshold then
        arrive targetDistance train

    else if distanceToTarget < 0 then
        -- Target lies behind the direction of travel; the order can never complete
        stopWithError ("Cannot reach " ++ spotId ++ ": it is behind the train") train

    else
        let
            newSpeed =
                (train.speed + acceleration * deltaSeconds)
                    |> min maxSpeed
                    |> min (sqrt (2 * braking * distanceToTarget))

            travelled =
                (train.speed + newSpeed) / 2 * deltaSeconds
        in
        if travelled >= distanceToTarget - arrivalThreshold then
            arrive targetDistance train

        else
            let
                ( finalSpeed, finalPosition ) =
                    applyBufferStopBrake ctx train newSpeed (train.position + travelled * directionSign) deltaSeconds
            in
            { train | position = finalPosition, speed = finalSpeed }


{-| Snap to the target at rest and move on to the next order.
-}
arrive : Float -> ActiveTrain -> ActiveTrain
arrive targetDistance train =
    advanceProgram { train | position = targetDistance, speed = 0 }


stopWithError : String -> ActiveTrain -> ActiveTrain
stopWithError message train =
    { train | speed = 0, trainState = Stopped message }


{-| Is `spotId` a station portal the train leaves through by continuing in
its current direction? Forward trains exit at the far end of the route;
reversing trains exit through the portal they entered by (route start).
-}
isExitPortal : TrackContext -> String -> Float -> ActiveTrain -> Bool
isExitPortal ctx spotId spotDistance train =
    List.any (\station -> station.portal == spotId) ctx.stations
        && (case train.reverser of
                Forward ->
                    spotDistance >= train.route.totalLength

                Reverse ->
                    spotDistance <= 0
           )


{-| Accelerate out through the portal. The order never completes; the
simulation despawns the train once it has fully left the track.
-}
departThroughPortal : Float -> ActiveTrain -> ActiveTrain
departThroughPortal deltaSeconds train =
    let
        newSpeed =
            min maxSpeed (train.speed + acceleration * deltaSeconds)
    in
    { train
        | speed = newSpeed
        , position = train.position + (train.speed + newSpeed) / 2 * reverserSign train * deltaSeconds
    }


{-| Execute a WaitSeconds order.
-}
executeWait : Float -> Int -> ActiveTrain -> ( ActiveTrain, List Effect )
executeWait deltaSeconds seconds train =
    let
        timer =
            if train.waitTimer <= 0 then
                -- First tick of wait: initialize timer
                toFloat seconds

            else
                train.waitTimer

        newTimer =
            timer - deltaSeconds
    in
    if newTimer <= 0 then
        -- Wait complete
        ( advanceProgram { train | waitTimer = 0, speed = 0 }, [] )

    else
        ( { train | waitTimer = newTimer, speed = 0 }, [] )


{-| Keep a train without a program moving at constant speed. It leaves
through the exit portal, or is brought to a stand by the buffer stop.
-}
runThrough : TrackContext -> Float -> ActiveTrain -> ActiveTrain
runThrough ctx deltaSeconds train =
    let
        ( newSpeed, newPosition ) =
            applyBufferStopBrake ctx train train.speed (train.position + train.speed * reverserSign train * deltaSeconds) deltaSeconds
    in
    { train | speed = newSpeed, position = newPosition }


{-| Coast to a stop (decelerate without a target).
-}
coastToStop : TrackContext -> Float -> ActiveTrain -> ActiveTrain
coastToStop ctx deltaSeconds train =
    if train.speed <= 0 then
        { train | speed = 0 }

    else
        let
            newSpeed =
                max 0 (train.speed - braking * deltaSeconds)

            avgSpeed =
                (train.speed + newSpeed) / 2

            ( finalSpeed, finalPosition ) =
                applyBufferStopBrake ctx train newSpeed (train.position + avgSpeed * reverserSign train * deltaSeconds) deltaSeconds
        in
        { train | speed = finalSpeed, position = finalPosition }


reverserSign : ActiveTrain -> Float
reverserSign train =
    case train.reverser of
        Forward ->
            1.0

        Reverse ->
            -1.0


{-| Advance program counter to the next order.
-}
advanceProgram : ActiveTrain -> ActiveTrain
advanceProgram train =
    let
        nextCounter =
            train.programCounter + 1
    in
    if nextCounter >= List.length train.program then
        { train | programCounter = nextCounter, trainState = WaitingForOrders }

    else
        { train | programCounter = nextCounter }


{-| Get order at index.
-}
getOrder : Int -> List Order -> Maybe Order
getOrder index orders =
    orders
        |> List.drop index
        |> List.head


{-| Apply emergency braking when approaching a buffer stop.

Only a forward-moving train on a route that ends at a buffer stop (rather than
a station portal) can hit one; the route start is always a portal. Given the
speed and position the train would otherwise have after this tick, returns
the braked speed and position, never past the buffer.

-}
applyBufferStopBrake : TrackContext -> ActiveTrain -> Float -> Float -> Float -> ( Float, Float )
applyBufferStopBrake ctx train speed position deltaSeconds =
    let
        bufferAhead =
            case train.reverser of
                Forward ->
                    Route.routeEndStation ctx train.route == Nothing

                Reverse ->
                    False
    in
    if not bufferAhead then
        ( speed, position )

    else
        let
            -- The head leads when moving forward, so only its stopping
            -- distance matters
            emergencyBrakeDist =
                (speed * speed) / (2 * emergencyBraking)

            distanceToBuffer =
                train.route.totalLength - train.position
        in
        if speed > 0 && distanceToBuffer < emergencyBrakeDist then
            let
                brakedSpeed =
                    max 0 (speed - emergencyBraking * deltaSeconds)
            in
            ( brakedSpeed
            , min train.route.totalLength (train.position + (speed + brakedSpeed) / 2 * deltaSeconds)
            )

        else
            ( speed, min train.route.totalLength position )
