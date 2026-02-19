module Train.Spawn exposing (checkSpawns)

{-| Train spawning logic.
-}

import Planning.Types exposing (ScheduledTrain, SpawnPointId(..))
import Programmer.Types exposing (ReverserPosition(..))
import Sawmill.Layout exposing (SwitchState)
import Set exposing (Set)
import Train.Route as Route
import Train.Stock exposing (consistLength, trainSpeed)
import Train.Types exposing (ActiveTrain, Route, TrainState(..))
import Util.GameTime exposing (GameTime)


{-| Check for trains that should spawn at the current elapsed time.
Returns list of newly spawned ActiveTrains.
-}
checkSpawns :
    GameTime
    -> List ScheduledTrain
    -> Set Int
    -> SwitchState
    -> List ActiveTrain
checkSpawns currentTime scheduledTrains spawnedIds switchState =
    scheduledTrains
        |> List.filter (\train -> shouldSpawn train currentTime spawnedIds)
        |> List.map (createActiveTrain switchState)


{-| Check if a scheduled train should spawn.
-}
shouldSpawn : ScheduledTrain -> GameTime -> Set Int -> Bool
shouldSpawn train currentTime spawnedIds =
    not (Set.member train.id spawnedIds)
        && currentTime >= train.departureTime


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
