module Simulation exposing (SimState, rebuildIfBeforeTurnout, tick)

{-| Simulation tick: advances the world state by one frame.

Each tick:

1.  Advance game time
2.  Spawn new trains
3.  Execute programs and collect effects
4.  Apply switch effects
5.  Rebuild routes if turnout changed
6.  Move unprogrammed trains
7.  Despawn and return stock

-}

import Planning.Helpers exposing (returnStockToInventory)
import Planning.Types exposing (ScheduledTrain, SpawnPointId(..), SpawnPointInventory)
import Programmer.Types exposing (SwitchPosition)
import Sawmill.Layout exposing (SwitchState(..))
import Set exposing (Set)
import Track.Element
import Train.Execution as Execution
import Train.Movement as Movement
import Train.Route as Route
import Train.Spawn as Spawn
import Train.Types exposing (ActiveTrain, Effect(..), Route, RouteSegment, SegmentGeometry(..), TrainState(..))
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
    , turnoutState : SwitchState
    , selectedTrainId : Maybe Int
    }


{-| Advance the simulation by deltaMs milliseconds.
-}
tick : Float -> SimState -> SimState
tick deltaMs state =
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
                newElapsed
                state.scheduledTrains
                state.spawnedTrainIds
                state.turnoutState

        -- Execute programs and update positions
        executedResults =
            state.activeTrains
                |> List.map (Execution.stepProgram scaledDeltaSeconds)

        executedTrains =
            List.map Tuple.first executedResults

        -- Collect all effects from execution
        allEffects =
            List.concatMap Tuple.second executedResults

        -- Apply switch effects to turnout state
        newTurnoutState =
            List.foldl applySwitchEffect state.turnoutState allEffects

        -- Rebuild routes if turnout state changed, but only for trains
        -- that haven't passed the turnout yet (to prevent position jumps)
        routeRebuiltTrains =
            if newTurnoutState /= state.turnoutState then
                List.map (rebuildIfBeforeTurnout newTurnoutState) executedTrains

            else
                executedTrains

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
                    let
                        exitStation =
                            exitSpawnPoint train.route
                    in
                    returnStockToInventory exitStation train.consist invs
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
        , turnoutState = newTurnoutState
        , selectedTrainId = newSelectedTrainId
    }



-- INTERNAL HELPERS


{-| Apply a switch effect to the turnout state.
-}
applySwitchEffect : Effect -> SwitchState -> SwitchState
applySwitchEffect effect _ =
    case effect of
        SetSwitchEffect _ pos ->
            case pos of
                Programmer.Types.Normal ->
                    Sawmill.Layout.Normal

                Programmer.Types.Diverging ->
                    Reverse


{-| Rebuild a train's route only if the train hasn't passed the turnout yet.

Trains past the turnout keep their existing route to prevent position jumps
when the switch changes — the same position value would map to a different
physical location on the new route.

-}
rebuildIfBeforeTurnout : SwitchState -> ActiveTrain -> ActiveTrain
rebuildIfBeforeTurnout newSwitchState train =
    case Route.turnoutStartDistance train.route of
        Just turnoutDist ->
            if train.position < turnoutDist then
                { train | route = Route.rebuildRoute train.spawnPoint newSwitchState }

            else
                train

        Nothing ->
            -- Turnout not on this route, rebuild is safe
            { train | route = Route.rebuildRoute train.spawnPoint newSwitchState }


{-| Determine spawn point from route (by checking route direction).
-}
spawnPointForRoute : Route -> SpawnPointId
spawnPointForRoute route =
    -- Check first segment orientation to determine direction
    case List.head route.segments of
        Just segment ->
            case segment.geometry of
                StraightGeometry geo ->
                    -- East-to-West starts heading West (positive X direction)
                    if geo.orientation > pi / 2 && geo.orientation < 3 * pi / 2 then
                        WestStation

                    else
                        EastStation

                ArcGeometry _ ->
                    -- Default to EastStation for arcs
                    EastStation

        Nothing ->
            EastStation


{-| Determine the exit spawn point for a despawning train.

Checks which tunnel the route ends at (the last segment's element ID).
A train that reversed and returned to its origin will have a rebuilt route
whose last segment is near the origin tunnel, so stock returns correctly.

Falls back to opposite-of-spawn if the route end can't be identified
(e.g., route ends at buffer stop -- shouldn't happen for despawning trains).

-}
exitSpawnPoint : Route -> SpawnPointId
exitSpawnPoint route =
    case lastRouteSegment route.segments of
        Just segment ->
            if segment.elementId == Track.Element.ElementId 1 then
                -- Route ends at mainline east (near East tunnel)
                EastStation

            else if segment.elementId == Track.Element.ElementId 3 then
                -- Route ends at mainline west (near West tunnel)
                WestStation

            else
                -- Route ends at siding or other element; fall back
                case spawnPointForRoute route of
                    EastStation ->
                        WestStation

                    WestStation ->
                        EastStation

        Nothing ->
            EastStation


lastRouteSegment : List RouteSegment -> Maybe RouteSegment
lastRouteSegment segments =
    case segments of
        [] ->
            Nothing

        [ x ] ->
            Just x

        _ :: rest ->
            lastRouteSegment rest
