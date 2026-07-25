module Train.Spawn exposing (checkSpawns)

{-| Train spawning logic.
-}

import Dict exposing (Dict)
import Planning.Types exposing (ScheduledTrain)
import Programmer.Types exposing (ReverserPosition(..))
import Set exposing (Set)
import Track.Element exposing (SwitchState)
import Train.Route as Route exposing (TrackContext)
import Train.Stock exposing (consistLength, trainSpeed)
import Train.Types exposing (ActiveTrain, TrainState(..))
import Util.GameTime exposing (GameTime)


{-| Check for trains that should spawn at the current elapsed time.
Returns list of newly spawned ActiveTrains.
-}
checkSpawns :
    TrackContext
    -> GameTime
    -> List ScheduledTrain
    -> Set Int
    -> Dict String SwitchState
    -> List ActiveTrain
checkSpawns ctx currentTime scheduledTrains spawnedIds switchStates =
    scheduledTrains
        |> List.filter (\train -> shouldSpawn train currentTime spawnedIds)
        |> List.map (createActiveTrain ctx switchStates)


{-| Check if a scheduled train should spawn.
-}
shouldSpawn : ScheduledTrain -> GameTime -> Set Int -> Bool
shouldSpawn train currentTime spawnedIds =
    not (Set.member train.id spawnedIds)
        && currentTime >= train.departureTime


{-| Create an ActiveTrain from a ScheduledTrain.
-}
createActiveTrain : TrackContext -> Dict String SwitchState -> ScheduledTrain -> ActiveTrain
createActiveTrain ctx switchStates scheduled =
    let
        route =
            Route.routeFromStation ctx switchStates scheduled.spawnPoint

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
