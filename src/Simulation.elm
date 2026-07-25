module Simulation exposing (SimState, rebuildIfBeforeTurnouts, tick)

{-| Simulation tick: advances the world state by one frame.

Each tick:

1.  Advance game time
2.  Spawn new trains
3.  Execute programs and collect effects
4.  Apply switch effects
5.  Rebuild routes if turnouts changed
6.  Move unprogrammed trains
7.  Despawn and return stock

-}

import Dict exposing (Dict)
import Planning.Helpers exposing (returnStockToInventory)
import Planning.Types exposing (ScheduledTrain, SpawnPointInventory)
import Programmer.Types
import Set exposing (Set)
import Track.Element exposing (SwitchState(..))
import Train.Execution as Execution
import Train.Movement as Movement
import Train.Route as Route exposing (TrackContext)
import Train.Spawn as Spawn
import Train.Types exposing (ActiveTrain, Effect(..), TrainState(..))
import Util.GameTime exposing (GameTime)


{-| All the world state the simulation tick reads and writes.
-}
type alias SimState =
    { timeMultiplier : Float
    , gameTime : GameTime
    , activeTrains : List ActiveTrain
    , spawnedTrainIds : Set Int
    , scheduledTrains : List ScheduledTrain
    , inventories : List SpawnPointInventory
    , turnoutStates : Dict String SwitchState
    , selectedTrainId : Maybe Int
    }


{-| Advance the simulation by deltaMs milliseconds.
-}
tick : TrackContext -> Float -> SimState -> SimState
tick ctx deltaMs state =
    let
        -- Cap delta to prevent teleportation when returning from background tab
        cappedDeltaMs =
            min deltaMs 100

        -- Apply time multiplier
        scaledDeltaSeconds =
            (cappedDeltaMs / 1000) * state.timeMultiplier

        -- Advance simulation time
        newElapsed =
            state.gameTime + scaledDeltaSeconds

        -- Spawn new trains
        newTrains =
            Spawn.checkSpawns
                ctx
                newElapsed
                state.scheduledTrains
                state.spawnedTrainIds
                state.turnoutStates

        -- Execute programs and update positions
        executedResults =
            state.activeTrains
                |> List.map (Execution.stepProgram ctx scaledDeltaSeconds)

        executedTrains =
            List.map Tuple.first executedResults

        -- Collect all effects from execution
        allEffects =
            List.concatMap Tuple.second executedResults

        -- Apply switch effects to the turnout states
        newTurnoutStates =
            List.foldl applySwitchEffect state.turnoutStates allEffects

        -- Turnouts whose state changed this tick
        changedTurnouts =
            Dict.keys newTurnoutStates
                |> List.filter
                    (\nodeId ->
                        Dict.get nodeId newTurnoutStates /= Dict.get nodeId state.turnoutStates
                    )

        -- Rebuild routes if turnout states changed, but only for trains
        -- that haven't passed the changed turnouts yet (to prevent position jumps)
        routeRebuiltTrains =
            if List.isEmpty changedTurnouts then
                executedTrains

            else
                List.map (rebuildIfBeforeTurnouts ctx newTurnoutStates changedTurnouts) executedTrains

        -- Move trains that are still using simple movement (no program).
        -- Trains with programs are fully handled by stepProgram
        -- (including coasting to stop after program completion).
        movedTrains =
            routeRebuiltTrains
                |> List.map
                    (\t ->
                        if List.isEmpty t.program then
                            Movement.updateTrain scaledDeltaSeconds t

                        else
                            t
                    )

        -- Separate despawning trains from surviving trains
        despawningTrains =
            List.filter Movement.shouldDespawn movedTrains

        updatedTrains =
            List.filter (not << Movement.shouldDespawn) movedTrains

        -- Return despawned trains' consist items to exit station inventory
        newInventories =
            List.foldl
                (\train invs ->
                    returnStockToInventory (exitStation ctx train) train.consist invs
                )
                state.inventories
                despawningTrains

        -- Combine trains
        allTrains =
            updatedTrains ++ newTrains

        -- Track newly spawned IDs
        newSpawnedIds =
            Set.union state.spawnedTrainIds
                (Set.fromList (List.map .id newTrains))

        -- Auto-deselect if selected train despawned
        newSelectedTrainId =
            case state.selectedTrainId of
                Just id ->
                    if List.any (\t -> t.id == id) allTrains then
                        Just id

                    else
                        Nothing

                Nothing ->
                    Nothing
    in
    { state
        | gameTime = newElapsed
        , activeTrains = allTrains
        , spawnedTrainIds = newSpawnedIds
        , inventories = newInventories
        , turnoutStates = newTurnoutStates
        , selectedTrainId = newSelectedTrainId
    }



-- INTERNAL HELPERS


{-| Apply a switch effect to the turnout states.
-}
applySwitchEffect : Effect -> Dict String SwitchState -> Dict String SwitchState
applySwitchEffect effect states =
    case effect of
        SetSwitchEffect switchId pos ->
            case pos of
                Programmer.Types.Normal ->
                    Dict.insert switchId Normal states

                Programmer.Types.Diverging ->
                    Dict.insert switchId Reverse states


{-| Rebuild a train's route only if the train hasn't reached any of the
changed turnouts yet.

Trains past a changed turnout keep their existing route to prevent position
jumps when the switch changes — the same position value would map to a
different physical location on the new route.

-}
rebuildIfBeforeTurnouts : TrackContext -> Dict String SwitchState -> List String -> ActiveTrain -> ActiveTrain
rebuildIfBeforeTurnouts ctx newStates changedTurnouts train =
    let
        changedDistances =
            changedTurnouts
                |> List.filterMap (\nodeId -> Dict.get nodeId ctx.nodeElementMap)
                |> List.filterMap (\elemId -> Route.elementStartDistance elemId train.route)

        rebuild =
            { train | route = Route.routeFromStation ctx newStates train.spawnPoint }
    in
    case List.minimum changedDistances of
        Just turnoutDist ->
            if train.position < turnoutDist then
                rebuild

            else
                train

        Nothing ->
            -- No changed turnout on this route, rebuild is safe
            rebuild


{-| Determine the exit station for a despawning train.

Checks which station's portal the route ends at. Falls back to the
station opposite the spawn point if the route end isn't a portal
(e.g., route ends at a buffer stop — shouldn't happen for despawning trains).

-}
exitStation : TrackContext -> ActiveTrain -> String
exitStation ctx train =
    case Route.routeEndStation ctx train.route of
        Just stationId ->
            stationId

        Nothing ->
            ctx.stations
                |> List.map .id
                |> List.filter ((/=) train.spawnPoint)
                |> List.head
                |> Maybe.withDefault train.spawnPoint
