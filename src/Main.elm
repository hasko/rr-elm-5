port module Main exposing (main)

{-| Railroad Switching Puzzle Game

Main entry point and application shell.

-}

import Browser
import Browser.Events
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (disabled, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Planning.Helpers exposing (returnStockToInventory, takeStockFromInventory)
import Planning.Types as Planning exposing (PanelMode(..), SpawnPointId(..), StockItem, StockType(..))
import Programmer.Types as Programmer
import Planning.View as PlanningView
import Programmer.View as ProgrammerView
import Sawmill.Layout as Layout exposing (ElementId(..), SwitchState(..))
import Sawmill.View as SawmillView
import Set exposing (Set)
import Storage
import Svg exposing (Svg, svg)
import Svg.Attributes as SvgA
import Svg.Events as SvgE
import Time
import Track.Element
import Train.Execution as Execution
import Train.Movement as Movement
import Train.Route as Route
import Train.Spawn as Spawn
import Train.Types exposing (ActiveTrain, Effect(..), TrainState(..))
import Train.View as TrainView
import Util.Vec2 as Vec2 exposing (Vec2)


{-| Port to save state to localStorage.
-}
port saveToStorage : String -> Cmd msg


{-| Port to clear localStorage and reload.
-}
port clearStorage : () -> Cmd msg



-- MAIN


main : Program (Maybe String) Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type GameMode
    = Planning
    | Running
    | Paused


type alias GameTime =
    { elapsedSeconds : Float -- Total simulation time in seconds
    }


type alias Camera =
    { center : Vec2 -- World coordinates
    , zoom : Float -- Pixels per meter
    }


type alias DragState =
    { startScreenPos : Vec2 -- Screen position where drag started
    , startCameraCenter : Vec2 -- Camera center when drag started
    }


type alias Model =
    { mode : GameMode
    , gameTime : GameTime
    , camera : Camera
    , viewportSize : { width : Float, height : Float }

    -- Sawmill puzzle state
    , turnoutState : SwitchState
    , hoveredElement : Maybe ElementId

    -- Panning state
    , dragState : Maybe DragState

    -- Planning state
    , planningState : Planning.PlanningState

    -- Active trains
    , activeTrains : List ActiveTrain
    , spawnedTrainIds : Set Int
    , timeMultiplier : Float

    -- Train info panel
    , selectedTrainId : Maybe Int
    }


init : Maybe String -> ( Model, Cmd Msg )
init maybeJson =
    case maybeJson of
        Just jsonString ->
            case Decode.decodeString Storage.decodeSavedState jsonString of
                Ok saved ->
                    ( restoreModel saved, Cmd.none )

                Err _ ->
                    -- Corrupt data, start fresh
                    ( defaultModel, Cmd.none )

        Nothing ->
            ( defaultModel, Cmd.none )


{-| Default model for first-time users or corrupt saved data.
-}
defaultModel : Model
defaultModel =
    { mode = Planning
    , gameTime = { elapsedSeconds = 6 * 60 * 60 } -- Start at 06:00
    , camera =
        { center = Vec2.vec2 -50 60
        , zoom = 2.0 -- 2 pixels per meter
        }
    , viewportSize = { width = 800, height = 600 }
    , turnoutState = Normal
    , hoveredElement = Nothing
    , dragState = Nothing
    , planningState = Planning.initPlanningState
    , activeTrains = []
    , spawnedTrainIds = Set.empty
    , timeMultiplier = 1.0
    , selectedTrainId = Nothing
    }


{-| Restore model from saved state.
-}
restoreModel : Storage.SavedState -> Model
restoreModel saved =
    let
        mode =
            case saved.mode of
                "Running" ->
                    Running

                "Paused" ->
                    Paused

                _ ->
                    Planning

        turnoutState =
            case saved.turnoutState of
                "Reverse" ->
                    Reverse

                _ ->
                    Normal

        -- Restore active trains by reconstructing routes
        activeTrains =
            List.map
                (\t ->
                    { id = t.id
                    , consist = t.consist
                    , position = t.position
                    , speed = t.speed
                    , route = Storage.routeForSpawnPoint t.spawnPoint turnoutState
                    , spawnPoint = t.spawnPoint
                    , program = []
                    , programCounter = 0
                    , trainState = WaitingForOrders
                    , reverser = Programmer.Forward
                    , waitTimer = 0
                    }
                )
                saved.activeTrains

        -- Restore planning state
        planningState =
            let
                base =
                    Planning.initPlanningState
            in
            { base
                | scheduledTrains = saved.scheduledTrains
                , inventories = saved.inventories
                , nextTrainId = saved.nextTrainId
            }
    in
    { mode = mode
    , gameTime = { elapsedSeconds = saved.gameTime }
    , camera =
        { center = Vec2.vec2 saved.cameraX saved.cameraY
        , zoom = saved.cameraZoom
        }
    , viewportSize = { width = 800, height = 600 }
    , turnoutState = turnoutState
    , hoveredElement = Nothing
    , dragState = Nothing
    , planningState = planningState
    , activeTrains = activeTrains
    , spawnedTrainIds = Set.fromList saved.spawnedTrainIds
    , timeMultiplier = saved.timeMultiplier
    , selectedTrainId = Nothing
    }



-- UPDATE


type Msg
    = Tick Float -- Delta time in milliseconds
    | TogglePlayPause
    | SetMode GameMode
    | ElementHovered ElementId
    | ElementUnhovered
    | ElementClicked ElementId
    | StartDrag Float Float -- Screen x, y where mousedown occurred
    | Drag Float Float -- Current screen x, y during drag
    | EndDrag -- Mouseup or mouseleave
    | Zoom Float Float Float -- deltaY, mouseX, mouseY in screen coords
    | SetTimeMultiplier Float
    | NoOp
      -- Storage messages
    | SaveTick Time.Posix
    | ResetGame
      -- Planning panel messages
    | ClosePlanningPanel
    | SelectSpawnPoint SpawnPointId
    | SelectStockItem StockItem
    | AddToConsistFront -- Add selected stock to front
    | AddToConsistBack -- Add selected stock to back
    | InsertInConsist Int -- Insert selected stock at index
    | RemoveFromConsist Int -- Remove item at index
    | ClearConsistBuilder
    | FlipLocoInConsist Int -- Toggle reversed flag on loco at index
    | ConsistDragStart Float -- Screen X where mousedown occurred
    | ConsistDragMove Float -- Current screen X during drag
    | ConsistDragEnd
    | SetTimePickerHour Int
    | SetTimePickerMinute Int
    | SetTimePickerDay Int
    | ScheduleTrain
    | RemoveScheduledTrain Int
    | SelectScheduledTrain Int -- Load train into editor
      -- Programmer panel messages
    | OpenProgrammer Int
    | CloseProgrammer
    | AddOrder Programmer.Order
    | RemoveOrder Int
    | MoveOrderUp Int
    | MoveOrderDown Int
    | SelectProgramOrder Int
    | SaveProgram
      -- Train info panel messages
    | TrainClicked Int
    | DeselectTrain


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick deltaMs ->
            if model.mode == Running then
                let
                    -- Cap delta to prevent teleportation when returning from background tab
                    cappedDeltaMs =
                        min deltaMs 100

                    -- Apply time multiplier
                    scaledDeltaSeconds =
                        (cappedDeltaMs / 1000) * model.timeMultiplier

                    -- Advance simulation time
                    newElapsed =
                        model.gameTime.elapsedSeconds + scaledDeltaSeconds

                    -- Spawn new trains
                    newTrains =
                        Spawn.checkSpawns
                            newElapsed
                            model.planningState.scheduledTrains
                            model.spawnedTrainIds
                            model.turnoutState

                    -- Execute programs and update positions
                    executedResults =
                        model.activeTrains
                            |> List.map (Execution.stepProgram scaledDeltaSeconds)

                    executedTrains =
                        List.map Tuple.first executedResults

                    -- Collect all effects from execution
                    allEffects =
                        List.concatMap Tuple.second executedResults

                    -- Apply switch effects to turnout state
                    newTurnoutState =
                        List.foldl applySwitchEffect model.turnoutState allEffects

                    -- Rebuild routes if turnout state changed, but only for trains
                    -- that haven't passed the turnout yet (to prevent position jumps)
                    routeRebuiltTrains =
                        if newTurnoutState /= model.turnoutState then
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
                            model.planningState.inventories
                            despawningTrains

                    planning =
                        model.planningState

                    -- Combine trains
                    allTrains =
                        updatedTrains ++ newTrains

                    -- Track newly spawned IDs
                    newSpawnedIds =
                        Set.union model.spawnedTrainIds
                            (Set.fromList (List.map .id newTrains))

                    -- Auto-deselect if selected train despawned
                    newSelectedTrainId =
                        case model.selectedTrainId of
                            Just id ->
                                if List.any (\t -> t.id == id) allTrains then
                                    Just id

                                else
                                    Nothing

                            Nothing ->
                                Nothing
                in
                ( { model
                    | gameTime = { elapsedSeconds = newElapsed }
                    , activeTrains = allTrains
                    , spawnedTrainIds = newSpawnedIds
                    , planningState = { planning | inventories = newInventories }
                    , turnoutState = newTurnoutState
                    , selectedTrainId = newSelectedTrainId
                  }
                , Cmd.none
                )

            else
                ( model, Cmd.none )

        TogglePlayPause ->
            let
                newMode =
                    case model.mode of
                        Planning ->
                            Running

                        Running ->
                            Paused

                        Paused ->
                            Running
            in
            ( { model | mode = newMode }, Cmd.none )

        SetMode newMode ->
            ( { model | mode = newMode }, Cmd.none )

        ElementHovered elementId ->
            ( { model | hoveredElement = Just elementId }, Cmd.none )

        ElementUnhovered ->
            ( { model | hoveredElement = Nothing }, Cmd.none )

        ElementClicked elementId ->
            case elementId of
                TurnoutId ->
                    let
                        newState =
                            case model.turnoutState of
                                Normal ->
                                    Reverse

                                Reverse ->
                                    Normal

                        rebuiltTrains =
                            List.map (rebuildIfBeforeTurnout newState) model.activeTrains
                    in
                    ( { model | turnoutState = newState, activeTrains = rebuiltTrains }, Cmd.none )

                TunnelPortalId ->
                    -- Open planning panel with East Station selected
                    let
                        planning =
                            model.planningState
                    in
                    ( { model
                        | mode = Planning
                        , planningState = { planning | selectedSpawnPoint = EastStation }
                      }
                    , Cmd.none
                    )

                WestTunnelPortalId ->
                    -- Open planning panel with West Station selected
                    let
                        planning =
                            model.planningState
                    in
                    ( { model
                        | mode = Planning
                        , planningState = { planning | selectedSpawnPoint = WestStation }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        StartDrag screenX screenY ->
            ( { model
                | dragState =
                    Just
                        { startScreenPos = Vec2.vec2 screenX screenY
                        , startCameraCenter = model.camera.center
                        }
              }
            , Cmd.none
            )

        Drag screenX screenY ->
            case model.dragState of
                Just drag ->
                    let
                        -- Calculate screen delta
                        deltaScreenX =
                            screenX - drag.startScreenPos.x

                        deltaScreenY =
                            screenY - drag.startScreenPos.y

                        -- Convert to world delta (divide by zoom)
                        deltaWorldX =
                            deltaScreenX / model.camera.zoom

                        deltaWorldY =
                            deltaScreenY / model.camera.zoom

                        -- Move camera opposite to drag direction
                        newCenter =
                            Vec2.vec2
                                (drag.startCameraCenter.x - deltaWorldX)
                                (drag.startCameraCenter.y - deltaWorldY)

                        newCamera =
                            { center = newCenter, zoom = model.camera.zoom }
                    in
                    ( { model | camera = newCamera }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        EndDrag ->
            ( { model | dragState = Nothing }, Cmd.none )

        Zoom deltaY mouseX mouseY ->
            let
                -- Zoom factor: scroll up = zoom in, scroll down = zoom out
                zoomFactor =
                    if deltaY < 0 then
                        1.1

                    else
                        1 / 1.1

                oldZoom =
                    model.camera.zoom

                newZoom =
                    clamp 0.5 10.0 (oldZoom * zoomFactor)

                -- Convert mouse screen position to world coordinates (before zoom)
                halfWidth =
                    model.viewportSize.width / 2

                halfHeight =
                    model.viewportSize.height / 2

                worldX =
                    model.camera.center.x + (mouseX - halfWidth) / oldZoom

                worldY =
                    model.camera.center.y + (mouseY - halfHeight) / oldZoom

                -- Adjust camera center so the world point under mouse stays fixed
                newCenterX =
                    worldX - (mouseX - halfWidth) / newZoom

                newCenterY =
                    worldY - (mouseY - halfHeight) / newZoom

                newCamera =
                    { center = Vec2.vec2 newCenterX newCenterY
                    , zoom = newZoom
                    }
            in
            ( { model | camera = newCamera }, Cmd.none )

        SetTimeMultiplier multiplier ->
            ( { model | timeMultiplier = multiplier }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        -- Planning panel messages
        ClosePlanningPanel ->
            ( { model | mode = Paused }, Cmd.none )

        SelectSpawnPoint spawnId ->
            let
                planning =
                    model.planningState
            in
            ( { model | planningState = { planning | selectedSpawnPoint = spawnId } }
            , Cmd.none
            )

        SelectStockItem stock ->
            let
                planning =
                    model.planningState

                builder =
                    planning.consistBuilder

                newBuilder =
                    { builder | selectedStock = Just stock }
            in
            ( { model | planningState = { planning | consistBuilder = newBuilder } }
            , Cmd.none
            )

        AddToConsistFront ->
            ( updateAddToConsist True model, Cmd.none )

        AddToConsistBack ->
            ( updateAddToConsist False model, Cmd.none )

        InsertInConsist index ->
            ( updateInsertInConsist index model, Cmd.none )

        RemoveFromConsist index ->
            ( updateRemoveFromConsist index model, Cmd.none )

        ClearConsistBuilder ->
            let
                planning =
                    model.planningState

                -- Return all stock from builder to inventory
                stockToReturn =
                    planning.consistBuilder.items

                newInventories =
                    returnStockToInventory planning.selectedSpawnPoint stockToReturn planning.inventories
            in
            ( { model
                | planningState =
                    { planning
                        | consistBuilder = Planning.emptyConsistBuilder
                        , inventories = newInventories
                        , editingTrainId = Nothing
                        , consistPanOffset = 0
                    }
              }
            , Cmd.none
            )

        FlipLocoInConsist index ->
            let
                planning =
                    model.planningState

                builder =
                    planning.consistBuilder

                newItems =
                    List.indexedMap
                        (\i item ->
                            if i == index && item.stockType == Locomotive then
                                { item | reversed = not item.reversed }

                            else
                                item
                        )
                        builder.items

                newBuilder =
                    { builder | items = newItems }
            in
            ( { model | planningState = { planning | consistBuilder = newBuilder } }
            , Cmd.none
            )

        ConsistDragStart screenX ->
            let
                planning =
                    model.planningState
            in
            ( { model
                | planningState =
                    { planning
                        | consistDragState =
                            Just
                                { startX = screenX
                                , startOffset = planning.consistPanOffset
                                }
                    }
              }
            , Cmd.none
            )

        ConsistDragMove screenX ->
            let
                planning =
                    model.planningState
            in
            case planning.consistDragState of
                Just drag ->
                    let
                        deltaX =
                            screenX - drag.startX

                        newOffset =
                            drag.startOffset + deltaX
                    in
                    ( { model
                        | planningState =
                            { planning | consistPanOffset = newOffset }
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        ConsistDragEnd ->
            let
                planning =
                    model.planningState
            in
            ( { model
                | planningState =
                    { planning | consistDragState = Nothing }
              }
            , Cmd.none
            )

        SetTimePickerHour hour ->
            let
                planning =
                    model.planningState
            in
            ( { model | planningState = { planning | timePickerHour = hour } }
            , Cmd.none
            )

        SetTimePickerMinute minute ->
            let
                planning =
                    model.planningState
            in
            ( { model | planningState = { planning | timePickerMinute = minute } }
            , Cmd.none
            )

        SetTimePickerDay day ->
            let
                planning =
                    model.planningState
            in
            ( { model | planningState = { planning | timePickerDay = day } }
            , Cmd.none
            )

        ScheduleTrain ->
            ( updateScheduleTrain model, Cmd.none )

        RemoveScheduledTrain trainId ->
            ( updateRemoveScheduledTrain trainId model, Cmd.none )

        SelectScheduledTrain trainId ->
            ( updateSelectScheduledTrain trainId model, Cmd.none )

        OpenProgrammer trainId ->
            ( updateOpenProgrammer trainId model, Cmd.none )

        CloseProgrammer ->
            ( updateCloseProgrammer model, Cmd.none )

        AddOrder order ->
            ( updateAddOrder order model, Cmd.none )

        RemoveOrder index ->
            ( updateRemoveOrder index model, Cmd.none )

        MoveOrderUp index ->
            ( updateMoveOrderUp index model, Cmd.none )

        MoveOrderDown index ->
            ( updateMoveOrderDown index model, Cmd.none )

        SelectProgramOrder index ->
            ( updateSelectProgramOrder index model, Cmd.none )

        SaveProgram ->
            ( updateSaveProgram model, Cmd.none )

        TrainClicked trainId ->
            ( { model | selectedTrainId = Just trainId }, Cmd.none )

        DeselectTrain ->
            ( { model | selectedTrainId = Nothing }, Cmd.none )

        SaveTick _ ->
            ( model, saveToStorage (Encode.encode 0 (extractSavedState model)) )

        ResetGame ->
            ( model, clearStorage () )



-- EFFECT HELPERS


{-| Apply a switch effect to the turnout state.
-}
applySwitchEffect : Effect -> SwitchState -> SwitchState
applySwitchEffect effect currentState =
    case effect of
        SetSwitchEffect _ pos ->
            case pos of
                Programmer.Normal ->
                    Normal

                Programmer.Diverging ->
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



-- STORAGE HELPERS


{-| Extract current state for saving.
-}
extractSavedState : Model -> Encode.Value
extractSavedState model =
    let
        modeString =
            case model.mode of
                Planning ->
                    "Planning"

                Running ->
                    "Running"

                Paused ->
                    "Paused"

        turnoutString =
            case model.turnoutState of
                Normal ->
                    "Normal"

                Reverse ->
                    "Reverse"

        -- Filter out trains that are exiting (position > route length)
        validTrains =
            model.activeTrains
                |> List.filter (\t -> t.position <= t.route.totalLength)

        savedTrains =
            List.map
                (\t ->
                    { id = t.id
                    , consist = t.consist
                    , position = t.position
                    , speed = t.speed
                    , spawnPoint = t.spawnPoint
                    }
                )
                validTrains

        savedState : Storage.SavedState
        savedState =
            { gameTime = model.gameTime.elapsedSeconds
            , mode = modeString
            , turnoutState = turnoutString
            , activeTrains = savedTrains
            , spawnedTrainIds = Set.toList model.spawnedTrainIds
            , scheduledTrains = model.planningState.scheduledTrains
            , inventories = model.planningState.inventories
            , nextTrainId = model.planningState.nextTrainId
            , cameraX = model.camera.center.x
            , cameraY = model.camera.center.y
            , cameraZoom = model.camera.zoom
            , timeMultiplier = model.timeMultiplier
            }
    in
    Storage.encodeSavedState savedState


{-| Determine spawn point from route (by checking route direction).
-}
spawnPointForRoute : Train.Types.Route -> SpawnPointId
spawnPointForRoute route =
    -- Check first segment orientation to determine direction
    case List.head route.segments of
        Just segment ->
            case segment.geometry of
                Train.Types.StraightGeometry geo ->
                    -- East-to-West starts heading West (positive X direction)
                    if geo.orientation > pi / 2 && geo.orientation < 3 * pi / 2 then
                        WestStation

                    else
                        EastStation

                Train.Types.ArcGeometry _ ->
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
exitSpawnPoint : Train.Types.Route -> SpawnPointId
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


lastRouteSegment : List Train.Types.RouteSegment -> Maybe Train.Types.RouteSegment
lastRouteSegment segments =
    case segments of
        [] ->
            Nothing

        [ x ] ->
            Just x

        _ :: rest ->
            lastRouteSegment rest



-- PLANNING HELPERS


{-| Add selected stock item to consist (front or back).
-}
updateAddToConsist : Bool -> Model -> Model
updateAddToConsist toFront model =
    let
        planning =
            model.planningState

        builder =
            planning.consistBuilder
    in
    case builder.selectedStock of
        Nothing ->
            model

        Just selectedStock ->
            let
                -- Find the inventory for current spawn point
                maybeInventory =
                    planning.inventories
                        |> List.filter (\inv -> inv.spawnPointId == planning.selectedSpawnPoint)
                        |> List.head

                -- Check if stock of this type is available
                stockAvailable =
                    maybeInventory
                        |> Maybe.map (\inv -> List.any (\s -> s.stockType == selectedStock.stockType) inv.availableStock)
                        |> Maybe.withDefault False
            in
            if not stockAvailable then
                -- Per plan: allow adding even if not available (for future: dashed outline)
                -- For now, we still need stock from inventory
                model

            else
                let
                    -- Take one item of this type from inventory
                    ( maybeActualStock, newInventories ) =
                        takeStockFromInventory planning.selectedSpawnPoint selectedStock.stockType planning.inventories

                    -- Add to front or back
                    newItems =
                        case maybeActualStock of
                            Just actualStock ->
                                if toFront then
                                    actualStock :: builder.items

                                else
                                    builder.items ++ [ actualStock ]

                            Nothing ->
                                builder.items

                    -- Check if any of this type remain
                    remainingOfType =
                        newInventories
                            |> List.filter (\inv -> inv.spawnPointId == planning.selectedSpawnPoint)
                            |> List.head
                            |> Maybe.map (\inv -> List.filter (\s -> s.stockType == selectedStock.stockType) inv.availableStock)
                            |> Maybe.map List.length
                            |> Maybe.withDefault 0

                    -- Clear selection if no more of this type
                    newSelection =
                        if remainingOfType > 0 then
                            builder.selectedStock

                        else
                            Nothing

                    newBuilder =
                        { builder | items = newItems, selectedStock = newSelection }
                in
                { model
                    | planningState =
                        { planning
                            | consistBuilder = newBuilder
                            , inventories = newInventories
                        }
                }


{-| Insert selected stock into consist at specified index.
-}
updateInsertInConsist : Int -> Model -> Model
updateInsertInConsist index model =
    let
        planning =
            model.planningState

        builder =
            planning.consistBuilder
    in
    case builder.selectedStock of
        Nothing ->
            model

        Just selectedStock ->
            let
                -- Find the inventory for current spawn point
                maybeInventory =
                    planning.inventories
                        |> List.filter (\inv -> inv.spawnPointId == planning.selectedSpawnPoint)
                        |> List.head

                -- Check if stock of this type is available
                stockAvailable =
                    maybeInventory
                        |> Maybe.map (\inv -> List.any (\s -> s.stockType == selectedStock.stockType) inv.availableStock)
                        |> Maybe.withDefault False
            in
            if not stockAvailable then
                model

            else
                let
                    -- Take one item of this type from inventory
                    ( maybeActualStock, newInventories ) =
                        takeStockFromInventory planning.selectedSpawnPoint selectedStock.stockType planning.inventories

                    -- Insert at specified index
                    newItems =
                        case maybeActualStock of
                            Just actualStock ->
                                List.take index builder.items
                                    ++ [ actualStock ]
                                    ++ List.drop index builder.items

                            Nothing ->
                                builder.items

                    -- Check if any of this type remain
                    remainingOfType =
                        newInventories
                            |> List.filter (\inv -> inv.spawnPointId == planning.selectedSpawnPoint)
                            |> List.head
                            |> Maybe.map (\inv -> List.filter (\s -> s.stockType == selectedStock.stockType) inv.availableStock)
                            |> Maybe.map List.length
                            |> Maybe.withDefault 0

                    -- Clear selection if no more of this type
                    newSelection =
                        if remainingOfType > 0 then
                            builder.selectedStock

                        else
                            Nothing

                    newBuilder =
                        { builder | items = newItems, selectedStock = newSelection }
                in
                { model
                    | planningState =
                        { planning
                            | consistBuilder = newBuilder
                            , inventories = newInventories
                        }
                }


{-| Remove stock from consist at index and return to inventory.
-}
updateRemoveFromConsist : Int -> Model -> Model
updateRemoveFromConsist index model =
    let
        planning =
            model.planningState

        builder =
            planning.consistBuilder

        maybeStock =
            builder.items
                |> List.drop index
                |> List.head
    in
    case maybeStock of
        Nothing ->
            model

        Just stock ->
            let
                newItems =
                    List.take index builder.items ++ List.drop (index + 1) builder.items

                newInventories =
                    returnStockToInventory planning.selectedSpawnPoint [ stock ] planning.inventories

                newBuilder =
                    { builder | items = newItems }
            in
            { model
                | planningState =
                    { planning
                        | consistBuilder = newBuilder
                        , inventories = newInventories
                    }
            }


{-| Schedule a train with the current consist (or update existing train).
-}
updateScheduleTrain : Model -> Model
updateScheduleTrain model =
    let
        planning =
            model.planningState

        builder =
            planning.consistBuilder

        -- Extract consist from builder items
        consist =
            builder.items

        -- Check validation: must have items and at least one locomotive
        hasLoco =
            List.any (\item -> item.stockType == Locomotive) consist
    in
    if List.isEmpty consist || not hasLoco then
        -- Don't schedule empty trains or trains without locomotive
        model

    else
        case planning.editingTrainId of
            Just trainId ->
                -- Update existing train - recreate it with new data
                let
                    updatedTrain =
                        { id = trainId
                        , spawnPoint = planning.selectedSpawnPoint
                        , departureTime =
                            { day = planning.timePickerDay
                            , hour = planning.timePickerHour
                            , minute = planning.timePickerMinute
                            }
                        , consist = consist
                        , program = planning.editingTrainProgram
                        }
                in
                { model
                    | planningState =
                        { planning
                            | scheduledTrains = planning.scheduledTrains ++ [ updatedTrain ]
                            , consistBuilder = Planning.emptyConsistBuilder
                            , editingTrainId = Nothing
                            , editingTrainProgram = Programmer.emptyProgram
                        }
                }

            Nothing ->
                -- Create new train
                let
                    newTrain =
                        { id = planning.nextTrainId
                        , spawnPoint = planning.selectedSpawnPoint
                        , departureTime =
                            { day = planning.timePickerDay
                            , hour = planning.timePickerHour
                            , minute = planning.timePickerMinute
                            }
                        , consist = consist
                        , program = Programmer.emptyProgram
                        }
                in
                { model
                    | planningState =
                        { planning
                            | scheduledTrains = planning.scheduledTrains ++ [ newTrain ]
                            , consistBuilder = Planning.emptyConsistBuilder
                            , nextTrainId = planning.nextTrainId + 1
                        }
                }


{-| Load a scheduled train into the consist builder for editing.
-}
updateSelectScheduledTrain : Int -> Model -> Model
updateSelectScheduledTrain trainId model =
    let
        planning =
            model.planningState

        maybeTrain =
            planning.scheduledTrains
                |> List.filter (\t -> t.id == trainId)
                |> List.head
    in
    case maybeTrain of
        Nothing ->
            model

        Just train ->
            let
                -- First return any current builder items to inventory
                currentItems =
                    planning.consistBuilder.items

                newInventories =
                    returnStockToInventory planning.selectedSpawnPoint currentItems planning.inventories

                -- Keep train in scheduled list but mark as being edited
                -- Stock remains "in use" by the train, not returned to inventory
                newTrains =
                    planning.scheduledTrains
                        |> List.filter (\t -> t.id /= trainId)

                -- Load consist into builder
                newBuilder =
                    { items = train.consist
                    , selectedStock = Nothing
                    }
            in
            { model
                | planningState =
                    { planning
                        | selectedSpawnPoint = train.spawnPoint
                        , scheduledTrains = newTrains
                        , inventories = newInventories
                        , consistBuilder = newBuilder
                        , timePickerDay = train.departureTime.day
                        , timePickerHour = train.departureTime.hour
                        , timePickerMinute = train.departureTime.minute
                        , editingTrainId = Just trainId
                        , editingTrainProgram = train.program
                    }
            }


{-| Remove a scheduled train and return its stock to inventory.
-}
updateRemoveScheduledTrain : Int -> Model -> Model
updateRemoveScheduledTrain trainId model =
    let
        planning =
            model.planningState

        maybeTrain =
            planning.scheduledTrains
                |> List.filter (\t -> t.id == trainId)
                |> List.head
    in
    case maybeTrain of
        Nothing ->
            model

        Just train ->
            let
                newTrains =
                    planning.scheduledTrains
                        |> List.filter (\t -> t.id /= trainId)

                newInventories =
                    returnStockToInventory train.spawnPoint train.consist planning.inventories
            in
            { model
                | planningState =
                    { planning
                        | scheduledTrains = newTrains
                        , inventories = newInventories
                    }
            }



-- PROGRAMMER HELPERS


{-| Open the programmer for a train.
-}
updateOpenProgrammer : Int -> Model -> Model
updateOpenProgrammer trainId model =
    let
        planning =
            model.planningState
    in
    -- Only open programmer if we're editing this train
    case planning.editingTrainId of
        Just editId ->
            if editId == trainId then
                { model
                    | planningState =
                        { planning
                            | panelMode = ProgrammerView trainId
                            , programmerState =
                                Just (Programmer.initProgrammerState trainId planning.editingTrainProgram)
                        }
                }

            else
                model

        Nothing ->
            model


{-| Close the programmer without saving.
-}
updateCloseProgrammer : Model -> Model
updateCloseProgrammer model =
    let
        planning =
            model.planningState
    in
    { model
        | planningState =
            { planning
                | panelMode = PlanningView
                , programmerState = Nothing
            }
    }


{-| Save the program and close the programmer.
    This also saves the entire train back to scheduledTrains.
-}
updateSaveProgram : Model -> Model
updateSaveProgram model =
    let
        planning =
            model.planningState
    in
    case ( planning.programmerState, planning.editingTrainId ) of
        ( Just progState, Just trainId ) ->
            let
                -- Reconstruct the train with current editing data and new program
                savedTrain =
                    { id = trainId
                    , spawnPoint = planning.selectedSpawnPoint
                    , departureTime =
                        { day = planning.timePickerDay
                        , hour = planning.timePickerHour
                        , minute = planning.timePickerMinute
                        }
                    , consist = planning.consistBuilder.items
                    , program = progState.program
                    }
            in
            { model
                | planningState =
                    { planning
                        | scheduledTrains = planning.scheduledTrains ++ [ savedTrain ]
                        , consistBuilder = Planning.emptyConsistBuilder
                        , editingTrainId = Nothing
                        , editingTrainProgram = Programmer.emptyProgram
                        , panelMode = PlanningView
                        , programmerState = Nothing
                    }
            }

        _ ->
            model


{-| Add an order to the program.
-}
updateAddOrder : Programmer.Order -> Model -> Model
updateAddOrder order model =
    updateProgrammerState model
        (\progState ->
            { progState | program = progState.program ++ [ order ] }
        )


{-| Remove an order from the program.
-}
updateRemoveOrder : Int -> Model -> Model
updateRemoveOrder index model =
    updateProgrammerState model
        (\progState ->
            { progState
                | program = removeAt index progState.program
                , selectedOrderIndex = Nothing
            }
        )


{-| Move an order up in the program.
-}
updateMoveOrderUp : Int -> Model -> Model
updateMoveOrderUp index model =
    if index > 0 then
        updateProgrammerState model
            (\progState ->
                { progState
                    | program = swapAt (index - 1) index progState.program
                    , selectedOrderIndex = Just (index - 1)
                }
            )

    else
        model


{-| Move an order down in the program.
-}
updateMoveOrderDown : Int -> Model -> Model
updateMoveOrderDown index model =
    updateProgrammerState model
        (\progState ->
            if index < List.length progState.program - 1 then
                { progState
                    | program = swapAt index (index + 1) progState.program
                    , selectedOrderIndex = Just (index + 1)
                }

            else
                progState
        )


{-| Select an order in the program.
-}
updateSelectProgramOrder : Int -> Model -> Model
updateSelectProgramOrder index model =
    updateProgrammerState model
        (\progState ->
            { progState | selectedOrderIndex = Just index }
        )


{-| Helper to update programmer state.
-}
updateProgrammerState : Model -> (Programmer.ProgrammerState -> Programmer.ProgrammerState) -> Model
updateProgrammerState model updater =
    let
        planning =
            model.planningState
    in
    case planning.programmerState of
        Nothing ->
            model

        Just progState ->
            { model
                | planningState =
                    { planning
                        | programmerState = Just (updater progState)
                    }
            }


{-| Remove element at index from list.
-}
removeAt : Int -> List a -> List a
removeAt index list =
    List.take index list ++ List.drop (index + 1) list


{-| Swap elements at two indices.
-}
swapAt : Int -> Int -> List a -> List a
swapAt i j list =
    let
        arr =
            List.indexedMap Tuple.pair list

        getAt idx =
            arr
                |> List.filter (\( k, _ ) -> k == idx)
                |> List.head
                |> Maybe.map Tuple.second
    in
    case ( getAt i, getAt j ) of
        ( Just vi, Just vj ) ->
            arr
                |> List.map
                    (\( k, v ) ->
                        if k == i then
                            vj

                        else if k == j then
                            vi

                        else
                            v
                    )

        _ ->
            list


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Save every second
          Time.every 1000 SaveTick

        -- Animation when running
        , if model.mode == Running then
            Browser.Events.onAnimationFrameDelta Tick

          else
            Sub.none
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style "width" "100%"
        , style "height" "100%"
        , style "display" "flex"
        , style "flex-direction" "column"
        ]
        [ viewHeader model
        , viewMainContent model
        ]


viewMainContent : Model -> Html Msg
viewMainContent model =
    case model.mode of
        Planning ->
            div
                [ style "display" "flex"
                , style "flex" "1"
                , style "overflow" "hidden"
                ]
                [ div [ style "flex" "1" ] [ viewCanvas model ]
                , viewRightPanel model
                ]

        _ ->
            case model.selectedTrainId of
                Just trainId ->
                    div
                        [ style "display" "flex"
                        , style "flex" "1"
                        , style "overflow" "hidden"
                        ]
                        [ div [ style "flex" "1" ] [ viewCanvas model ]
                        , viewTrainInfoPanel model trainId
                        ]

                Nothing ->
                    viewCanvas model


viewRightPanel : Model -> Html Msg
viewRightPanel model =
    case model.planningState.panelMode of
        PlanningView ->
            PlanningView.viewPlanningPanel
                { state = model.planningState
                , onClose = ClosePlanningPanel
                , onSelectSpawnPoint = SelectSpawnPoint
                , onSelectStock = SelectStockItem
                , onAddToFront = AddToConsistFront
                , onAddToBack = AddToConsistBack
                , onInsertInConsist = InsertInConsist
                , onRemoveFromConsist = RemoveFromConsist
                , onClearConsist = ClearConsistBuilder
                , onFlipLoco = FlipLocoInConsist
                , onSetHour = SetTimePickerHour
                , onSetMinute = SetTimePickerMinute
                , onSetDay = SetTimePickerDay
                , onSchedule = ScheduleTrain
                , onRemoveTrain = RemoveScheduledTrain
                , onSelectTrain = SelectScheduledTrain
                , onOpenProgrammer = OpenProgrammer
                , onReset = ResetGame
                , onConsistDragStart = ConsistDragStart
                , onConsistDragMove = ConsistDragMove
                , onConsistDragEnd = ConsistDragEnd
                }

        ProgrammerView trainId ->
            case model.planningState.programmerState of
                Just progState ->
                    ProgrammerView.viewProgrammerPanel
                        { state = progState
                        , trainId = trainId
                        , onBack = CloseProgrammer
                        , onSave = SaveProgram
                        , onAddOrder = AddOrder
                        , onRemoveOrder = RemoveOrder
                        , onMoveOrderUp = MoveOrderUp
                        , onMoveOrderDown = MoveOrderDown
                        , onSelectOrder = SelectProgramOrder
                        }

                Nothing ->
                    -- Should not happen, but fallback to planning view
                    text "Error: No programmer state"


viewTrainInfoPanel : Model -> Int -> Html Msg
viewTrainInfoPanel model trainId =
    case List.filter (\t -> t.id == trainId) model.activeTrains |> List.head of
        Just train ->
            let
                speedKmh =
                    train.speed * 3.6

                stateText =
                    case train.trainState of
                        Executing ->
                            "Executing"

                        WaitingForOrders ->
                            "Waiting for Orders"

                        Stopped reason ->
                            "Stopped: " ++ reason

                currentOrder =
                    if List.isEmpty train.program then
                        "No program"

                    else
                        case List.drop train.programCounter train.program |> List.head of
                            Just order ->
                                String.fromInt (train.programCounter + 1)
                                    ++ ". "
                                    ++ Programmer.orderDescription order

                            Nothing ->
                                "Program complete"

                infoRow labelText valueText =
                    div [ style "margin-bottom" "12px" ]
                        [ div
                            [ style "font-size" "12px"
                            , style "color" "#888"
                            , style "margin-bottom" "2px"
                            ]
                            [ text labelText ]
                        , div [ style "font-size" "14px" ] [ text valueText ]
                        ]
            in
            div
                [ style "width" "400px"
                , style "background" "#1a1a2e"
                , style "border-left" "2px solid #333"
                , style "display" "flex"
                , style "flex-direction" "column"
                , style "font-family" "sans-serif"
                , style "color" "#e0e0e0"
                , style "overflow-y" "auto"
                ]
                [ -- Header
                  div
                    [ style "display" "flex"
                    , style "justify-content" "space-between"
                    , style "align-items" "center"
                    , style "padding" "12px 16px"
                    , style "background" "#252540"
                    , style "border-bottom" "1px solid #333"
                    ]
                    [ span
                        [ style "font-weight" "bold"
                        , style "font-size" "16px"
                        ]
                        [ text ("Train #" ++ String.fromInt trainId) ]
                    , button
                        [ style "background" "#3a3a5a"
                        , style "border" "none"
                        , style "color" "#e0e0e0"
                        , style "padding" "6px 12px"
                        , style "border-radius" "4px"
                        , style "cursor" "pointer"
                        , style "font-size" "14px"
                        , onClick DeselectTrain
                        ]
                        [ text "X" ]
                    ]

                -- Info content
                , div [ style "padding" "16px" ]
                    [ infoRow "SPEED" (String.fromFloat (toFloat (round (speedKmh * 10)) / 10) ++ " km/h")
                    , infoRow "STATE" stateText
                    , infoRow "CURRENT ORDER" currentOrder
                    , div [ style "margin-bottom" "12px" ]
                        [ div
                            [ style "font-size" "12px"
                            , style "color" "#888"
                            , style "margin-bottom" "4px"
                            ]
                            [ text "CONSIST" ]
                        , div []
                            (List.indexedMap
                                (\i item ->
                                    div
                                        [ style "padding" "4px 8px"
                                        , style "background" "#252540"
                                        , style "border-radius" "4px"
                                        , style "margin-bottom" "2px"
                                        , style "font-size" "14px"
                                        ]
                                        [ text (String.fromInt (i + 1) ++ ". " ++ Planning.stockTypeName item.stockType) ]
                                )
                                train.consist
                            )
                        ]
                    ]
                ]

        Nothing ->
            text ""


viewHeader : Model -> Html Msg
viewHeader model =
    div
        [ style "background" "#1a1a1a"
        , style "color" "#e0e0e0"
        , style "padding" "10px 20px"
        , style "display" "flex"
        , style "justify-content" "space-between"
        , style "align-items" "center"
        , style "font-family" "monospace"
        ]
        [ div []
            [ text "Railroad Switching Puzzle - Sawmill" ]
        , div [ style "display" "flex", style "gap" "20px", style "align-items" "center" ]
            [ viewGameTime model.gameTime
            , viewSpeedControls model.timeMultiplier
            , viewPlayPauseButton model.mode
            , viewModeIndicator model.mode
            ]
        ]


viewPlayPauseButton : GameMode -> Html Msg
viewPlayPauseButton mode =
    let
        ( label, bgColor, isDisabled ) =
            case mode of
                Planning ->
                    ( "Start", "#666", True )

                Running ->
                    ( "Pause", "#ffaa4a", False )

                Paused ->
                    ( "Start", "#4aff6a", False )
    in
    button
        [ onClick TogglePlayPause
        , disabled isDisabled
        , style "background" bgColor
        , style "color" "#000"
        , style "border" "none"
        , style "padding" "6px 16px"
        , style "border-radius" "4px"
        , style "font-weight" "bold"
        , style "cursor"
            (if isDisabled then
                "not-allowed"

             else
                "pointer"
            )
        , style "opacity"
            (if isDisabled then
                "0.5"

             else
                "1"
            )
        , style "font-family" "monospace"
        ]
        [ text label ]


viewSpeedControls : Float -> Html Msg
viewSpeedControls currentMultiplier =
    let
        speeds =
            [ ( 1, "1x" ), ( 2, "2x" ), ( 4, "4x" ), ( 8, "8x" ) ]

        viewSpeedButton ( mult, label ) =
            let
                isActive =
                    currentMultiplier == mult
            in
            button
                [ onClick (SetTimeMultiplier mult)
                , style "background"
                    (if isActive then
                        "#4a9eff"

                     else
                        "#333"
                    )
                , style "color"
                    (if isActive then
                        "#000"

                     else
                        "#e0e0e0"
                    )
                , style "border" "none"
                , style "padding" "4px 8px"
                , style "border-radius" "3px"
                , style "cursor" "pointer"
                , style "font-family" "monospace"
                , style "font-size" "12px"
                , style "font-weight"
                    (if isActive then
                        "bold"

                     else
                        "normal"
                    )
                ]
                [ text label ]
    in
    div [ style "display" "flex", style "gap" "4px", style "align-items" "center" ]
        (List.map viewSpeedButton speeds)


viewGameTime : GameTime -> Html Msg
viewGameTime time =
    let
        totalSeconds =
            floor time.elapsedSeconds

        hours =
            modBy 24 (totalSeconds // 3600)

        minutes =
            modBy 60 (totalSeconds // 60)

        seconds =
            modBy 60 totalSeconds

        hourStr =
            String.padLeft 2 '0' (String.fromInt hours)

        minStr =
            String.padLeft 2 '0' (String.fromInt minutes)

        secStr =
            String.padLeft 2 '0' (String.fromInt seconds)
    in
    div []
        [ text (hourStr ++ ":" ++ minStr)
        , span [ style "font-size" "0.7em", style "opacity" "0.7" ]
            [ text (":" ++ secStr) ]
        ]


viewModeIndicator : GameMode -> Html Msg
viewModeIndicator mode =
    let
        ( label, color ) =
            case mode of
                Planning ->
                    ( "PLANNING", "#4a9eff" )

                Running ->
                    ( "RUNNING", "#4aff6a" )

                Paused ->
                    ( "PAUSED", "#ffaa4a" )
    in
    div
        [ style "background" color
        , style "color" "#000"
        , style "padding" "4px 12px"
        , style "border-radius" "4px"
        , style "font-weight" "bold"
        ]
        [ text label ]


viewCanvas : Model -> Html Msg
viewCanvas model =
    let
        -- Calculate viewBox from camera
        halfWidth =
            model.viewportSize.width / 2 / model.camera.zoom

        halfHeight =
            model.viewportSize.height / 2 / model.camera.zoom

        minX =
            model.camera.center.x - halfWidth

        minY =
            model.camera.center.y - halfHeight

        viewBoxWidth =
            halfWidth * 2

        viewBoxHeight =
            halfHeight * 2

        viewBoxStr =
            String.join " "
                [ String.fromFloat minX
                , String.fromFloat minY
                , String.fromFloat viewBoxWidth
                , String.fromFloat viewBoxHeight
                ]

        -- Get tooltip for hovered element
        tooltipView =
            case model.hoveredElement of
                Just elemId ->
                    let
                        maybeElem =
                            Layout.interactiveElements model.turnoutState
                                |> List.filter (\e -> e.id == elemId)
                                |> List.head
                    in
                    case maybeElem of
                        Just elem ->
                            let
                                -- Position tooltip at center-right of element bounds
                                tooltipPos =
                                    Vec2.vec2
                                        (elem.bounds.x + elem.bounds.width)
                                        (elem.bounds.y + elem.bounds.height / 2)
                            in
                            SawmillView.viewTooltip tooltipPos elem.tooltip

                        Nothing ->
                            Svg.g [] []

                Nothing ->
                    Svg.g [] []
    in
    svg
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.viewBox viewBoxStr
        , style "background" "#3a5a3a" -- Grass green
        , style "flex" "1"
        , style "cursor"
            (if model.dragState /= Nothing then
                "grabbing"

             else
                "default"
            )
        , SvgE.on "mousedown" (decodeMousePosition StartDrag)
        , SvgE.on "mousemove" (decodeMousePosition Drag)
        , SvgE.on "mouseup" (Decode.succeed EndDrag)
        , SvgE.on "mouseleave" (Decode.succeed EndDrag)
        , Html.Events.preventDefaultOn "wheel" decodeWheelEvent
        ]
        [ -- Grid for reference
          viewGrid

        -- Sawmill layout
        , SawmillView.view
            { turnoutState = model.turnoutState
            , hoveredElement = model.hoveredElement
            , onElementClick = ElementClicked
            , onElementHover = ElementHovered
            , onElementUnhover = ElementUnhovered
            , noop = NoOp
            }

        -- Active trains
        , TrainView.viewTrains TrainClicked model.activeTrains

        -- Tooltip (rendered last so it's on top)
        , tooltipView
        ]


{-| Decode mouse position from mouse event.
-}
decodeMousePosition : (Float -> Float -> msg) -> Decode.Decoder msg
decodeMousePosition toMsg =
    Decode.map2 toMsg
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)


{-| Decode wheel event for zoom. Returns (msg, preventDefault=True).
-}
decodeWheelEvent : Decode.Decoder ( Msg, Bool )
decodeWheelEvent =
    Decode.map3 (\dy mx my -> ( Zoom dy mx my, True ))
        (Decode.field "deltaY" Decode.float)
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)


{-| Grid for visual reference during development.
-}
viewGrid : Svg Msg
viewGrid =
    let
        gridLines =
            List.range -10 10
                |> List.concatMap
                    (\i ->
                        let
                            pos =
                                toFloat i * 50
                        in
                        [ Svg.line
                            [ SvgA.x1 (String.fromFloat pos)
                            , SvgA.y1 "-500"
                            , SvgA.x2 (String.fromFloat pos)
                            , SvgA.y2 "500"
                            , SvgA.stroke "#2a4a2a"
                            , SvgA.strokeWidth "0.5"
                            ]
                            []
                        , Svg.line
                            [ SvgA.x1 "-500"
                            , SvgA.y1 (String.fromFloat pos)
                            , SvgA.x2 "500"
                            , SvgA.y2 (String.fromFloat pos)
                            , SvgA.stroke "#2a4a2a"
                            , SvgA.strokeWidth "0.5"
                            ]
                            []
                        ]
                    )
    in
    Svg.g [] gridLines
