module Train.Execution exposing (stepProgram)

{-| Program execution engine for active trains.

Each tick, trains with a program advance through their orders:

  - MoveTo: Accelerate toward target, decelerate to stop at destination
  - SetReverser: Instant, advances immediately
  - SetSwitch: Returns effect for Main to apply, advances immediately
  - WaitSeconds: Counts down timer, advances when done
  - Couple/Uncouple: Stops with error (not yet implemented)

-}

import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotId(..), spotName)
import Train.Route as Route
import Train.Stock exposing (consistLength)
import Train.Types exposing (ActiveTrain, Effect(..), Route, TrainState(..))


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
stepProgram : Float -> ActiveTrain -> ( ActiveTrain, List Effect )
stepProgram deltaSeconds train =
    case train.trainState of
        Executing ->
            executeCurrentOrder deltaSeconds train

        WaitingForOrders ->
            -- No program or program complete, coast to stop
            ( coastToStop deltaSeconds train, [] )

        Stopped _ ->
            -- Train is stopped with an error
            ( { train | speed = 0 }, [] )


{-| Execute the current order based on programCounter.
-}
executeCurrentOrder : Float -> ActiveTrain -> ( ActiveTrain, List Effect )
executeCurrentOrder deltaSeconds train =
    case getOrder train.programCounter train.program of
        Nothing ->
            -- Program complete
            ( coastToStop deltaSeconds { train | trainState = WaitingForOrders }, [] )

        Just order ->
            case order of
                MoveTo spotId ->
                    executeMoveTo deltaSeconds spotId train

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
executeMoveTo : Float -> SpotId -> ActiveTrain -> ( ActiveTrain, List Effect )
executeMoveTo deltaSeconds spotId train =
    case Route.spotPosition spotId train.route of
        Nothing ->
            -- Spot not reachable on this route
            ( { train
                | speed = 0
                , trainState = Stopped ("Cannot reach " ++ spotName spotId)
              }
            , []
            )

        Just targetDistance ->
            let
                -- Determine direction based on reverser
                directionSign =
                    case train.reverser of
                        Forward ->
                            1.0

                        Reverse ->
                            -1.0

                -- Signed distance to target (positive = target is ahead in travel direction)
                distanceToTarget =
                    (targetDistance - train.position) * directionSign

                -- Buffer stop safety check
                bufferStopDistance =
                    bufferStopMargin train

                -- Determine desired speed
                ( desiredSpeed, newPosition ) =
                    if abs distanceToTarget < arrivalThreshold then
                        -- Arrived at target
                        ( 0, targetDistance )

                    else if distanceToTarget > 0 then
                        -- Target is ahead: accelerate or brake as needed
                        let
                            brakingDistance =
                                (train.speed * train.speed) / (2 * braking)

                            shouldBrake =
                                brakingDistance >= abs distanceToTarget

                            newSpeed =
                                if shouldBrake then
                                    max 0 (train.speed - braking * deltaSeconds)

                                else
                                    min maxSpeed (train.speed + acceleration * deltaSeconds)

                            avgSpeed =
                                (train.speed + newSpeed) / 2

                            pos =
                                train.position + avgSpeed * directionSign * deltaSeconds
                        in
                        ( newSpeed, pos )

                    else
                        -- Target is behind: we overshot, stop
                        ( 0, train.position )

                -- Apply buffer stop safety brake
                ( finalSpeed, finalPosition ) =
                    applyBufferStopBrake train bufferStopDistance desiredSpeed newPosition deltaSeconds
            in
            if abs distanceToTarget < arrivalThreshold || (desiredSpeed == 0 && abs distanceToTarget < arrivalThreshold * 2) then
                -- Arrived: advance to next order
                ( advanceProgram { train | position = targetDistance, speed = 0 }, [] )

            else
                ( { train | position = finalPosition, speed = finalSpeed }, [] )


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


{-| Coast to a stop (decelerate without a target).
-}
coastToStop : Float -> ActiveTrain -> ActiveTrain
coastToStop deltaSeconds train =
    if train.speed <= 0 then
        { train | speed = 0 }

    else
        let
            newSpeed =
                max 0 (train.speed - braking * deltaSeconds)

            avgSpeed =
                (train.speed + newSpeed) / 2

            directionSign =
                case train.reverser of
                    Forward ->
                        1.0

                    Reverse ->
                        -1.0

            newPosition =
                train.position + avgSpeed * directionSign * deltaSeconds
        in
        { train | speed = newSpeed, position = newPosition }


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


{-| Calculate distance to buffer stop (end of route) for safety braking.
-}
bufferStopMargin : ActiveTrain -> Float
bufferStopMargin train =
    train.route.totalLength - train.position


{-| Apply emergency braking if approaching buffer stop.
-}
applyBufferStopBrake : ActiveTrain -> Float -> Float -> Float -> Float -> ( Float, Float )
applyBufferStopBrake train bufferDist speed position deltaSeconds =
    let
        -- Only apply in forward direction
        isForward =
            case train.reverser of
                Forward ->
                    True

                Reverse ->
                    False

        emergencyBrakeDist =
            (speed * speed) / (2 * emergencyBraking) + consistLength train.consist
    in
    if isForward && bufferDist < emergencyBrakeDist && speed > 0 then
        let
            brakedSpeed =
                max 0 (speed - emergencyBraking * deltaSeconds)

            avgSpeed =
                (speed + brakedSpeed) / 2

            newPos =
                train.position + avgSpeed * deltaSeconds

            -- Hard clamp: never exceed route length
            clampedPos =
                min newPos train.route.totalLength
        in
        ( brakedSpeed, clampedPos )

    else
        ( speed, position )


