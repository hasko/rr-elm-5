module Train.Spawn exposing (checkSpawns)

{-| Train spawning logic.
-}

import Planning.Types exposing (DepartureTime, ScheduledTrain, SpawnPointId(..))
import Programmer.Types exposing (ReverserPosition(..))
import Sawmill.Layout exposing (SwitchState)
import Set exposing (Set)
import Train.Route as Route
import Train.Stock exposing (consistLength, trainSpeed)
import Train.Types exposing (ActiveTrain, Route, TrainState(..))


{-| Check for trains that should spawn at the current elapsed time.
Returns list of newly spawned ActiveTrains.
-}
checkSpawns :
    Float
    -> List ScheduledTrain
    -> Set Int
    -> SwitchState
    -> List ActiveTrain
checkSpawns elapsedSeconds scheduledTrains spawnedIds switchState =
    scheduledTrains
        |> List.filter (\train -> shouldSpawn train elapsedSeconds spawnedIds)
        |> List.map (createActiveTrain switchState)


{-| Check if a scheduled train should spawn.
-}
shouldSpawn : ScheduledTrain -> Float -> Set Int -> Bool
shouldSpawn train elapsedSeconds spawnedIds =
    let
        departureSeconds =
            departureTimeToSeconds train.departureTime
    in
    not (Set.member train.id spawnedIds)
        && elapsedSeconds >= departureSeconds


{-| Convert DepartureTime to seconds from simulation start.
For MVP, we'll treat day=0, hour=0, minute=0 as t=0.
So departure at minute=10 means spawn at 10 seconds (we scale 1 minute = 1 second).

TODO: Update Planning/Types to use departureSeconds directly.

-}
departureTimeToSeconds : DepartureTime -> Float
departureTimeToSeconds { day, hour, minute } =
    -- For MVP: minute value directly corresponds to seconds
    -- This lets us test with existing UI (set minute=10 = spawn at 10 seconds)
    toFloat minute


{-| Create an ActiveTrain from a ScheduledTrain.
-}
createActiveTrain : SwitchState -> ScheduledTrain -> ActiveTrain
createActiveTrain switchState scheduled =
    let
        route =
            case scheduled.spawnPoint of
                EastStation ->
                    Route.eastToWestRoute switchState

                WestStation ->
                    Route.westToEastRoute switchState

        -- Start position: negative so train is "inside" the tunnel
        -- Lead car front at 0 means the car just emerged
        -- We want entire train hidden initially, so start at -(consistLength)
        startPosition =
            -(consistLength scheduled.consist)
    in
    { id = scheduled.id
    , consist = scheduled.consist
    , position = startPosition
    , speed = trainSpeed
    , route = route
    , spawnPoint = scheduled.spawnPoint
    , program = scheduled.program
    , programCounter = 0
    , trainState =
        if List.isEmpty scheduled.program then
            WaitingForOrders

        else
            Executing
    , reverser = Forward
    , waitTimer = 0
    }
