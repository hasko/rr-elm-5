port module Main exposing (main)

{-| Railroad Switching Puzzle Game

Main entry point and application shell.

-}

import Browser
import Browser.Events
import Camera
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (disabled, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import Planning.Helpers exposing (returnStockToInventory)
import Planning.Types as Planning exposing (PanelMode(..), SpawnPointId(..), StockItem, StockType(..))
import Planning.Update
import Programmer.Types as Programmer
import Programmer.Update
import Planning.View as PlanningView
import Programmer.View as ProgrammerView
import Sawmill.Layout as Layout exposing (ElementId(..), SwitchState(..))
import Simulation
import Sawmill.View as SawmillView
import Set exposing (Set)
import Storage
import Svg exposing (Svg, svg)
import Svg.Attributes as SvgA
import Svg.Events as SvgE
import Time
import Train.Types exposing (ActiveTrain, TrainState(..))
import Train.View as TrainView
import Util.GameTime as GameTime exposing (GameTime)
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


type alias Model =
    { mode : GameMode
    , gameTime : GameTime
    , cameraState : Camera.CameraState
    , viewportSize : { width : Float, height : Float }

    -- Sawmill puzzle state
    , turnoutState : SwitchState
    , hoveredElement : Maybe ElementId

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
    , gameTime = GameTime.fromHourMinute 6 0
    , cameraState =
        { camera =
            { center = Vec2.vec2 -50 60
            , zoom = 2.0 -- 2 pixels per meter
            }
        , dragState = Nothing
        }
    , viewportSize = { width = 800, height = 600 }
    , turnoutState = Normal
    , hoveredElement = Nothing
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
    , gameTime = saved.gameTime
    , cameraState =
        { camera =
            { center = Vec2.vec2 saved.cameraX saved.cameraY
            , zoom = saved.cameraZoom
            }
        , dragState = Nothing
        }
    , viewportSize = { width = 800, height = 600 }
    , turnoutState = turnoutState
    , hoveredElement = Nothing
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
    | CameraMsg Camera.CameraMsg
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
                    simState =
                        { timeMultiplier = model.timeMultiplier
                        , gameTime = model.gameTime
                        , activeTrains = model.activeTrains
                        , spawnedTrainIds = model.spawnedTrainIds
                        , scheduledTrains = model.planningState.scheduledTrains
                        , inventories = model.planningState.inventories
                        , turnoutState = model.turnoutState
                        , selectedTrainId = model.selectedTrainId
                        }

                    result =
                        Simulation.tick deltaMs simState

                    planning =
                        model.planningState
                in
                ( { model
                    | gameTime = result.gameTime
                    , activeTrains = result.activeTrains
                    , spawnedTrainIds = result.spawnedTrainIds
                    , planningState = { planning | inventories = result.inventories }
                    , turnoutState = result.turnoutState
                    , selectedTrainId = result.selectedTrainId
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
                            List.map (Simulation.rebuildIfBeforeTurnout newState) model.activeTrains
                    in
                    ( { model | turnoutState = newState, activeTrains = rebuiltTrains }, Cmd.none )

                TunnelPortalId ->
                    -- Open planning panel with West Station selected (left/west portal)
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

                WestTunnelPortalId ->
                    -- Open planning panel with East Station selected (right/east portal)
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

                _ ->
                    ( model, Cmd.none )

        CameraMsg camMsg ->
            ( { model | cameraState = Camera.update model.viewportSize camMsg model.cameraState }
            , Cmd.none
            )

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
            ( { model | planningState = Planning.Update.addToConsist True model.planningState }, Cmd.none )

        AddToConsistBack ->
            ( { model | planningState = Planning.Update.addToConsist False model.planningState }, Cmd.none )

        InsertInConsist index ->
            ( { model | planningState = Planning.Update.insertInConsist index model.planningState }, Cmd.none )

        RemoveFromConsist index ->
            ( { model | planningState = Planning.Update.removeFromConsist index model.planningState }, Cmd.none )

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
            ( { model | planningState = Planning.Update.scheduleTrain model.planningState }, Cmd.none )

        RemoveScheduledTrain trainId ->
            ( { model | planningState = Planning.Update.removeScheduledTrain trainId model.planningState }, Cmd.none )

        SelectScheduledTrain trainId ->
            ( { model | planningState = Planning.Update.selectScheduledTrain trainId model.planningState }, Cmd.none )

        OpenProgrammer trainId ->
            ( { model | planningState = Programmer.Update.openProgrammer trainId model.planningState }, Cmd.none )

        CloseProgrammer ->
            ( { model | planningState = Programmer.Update.closeProgrammer model.planningState }, Cmd.none )

        AddOrder order ->
            ( { model | planningState = Programmer.Update.addOrder order model.planningState }, Cmd.none )

        RemoveOrder index ->
            ( { model | planningState = Programmer.Update.removeOrder index model.planningState }, Cmd.none )

        MoveOrderUp index ->
            ( { model | planningState = Programmer.Update.moveOrderUp index model.planningState }, Cmd.none )

        MoveOrderDown index ->
            ( { model | planningState = Programmer.Update.moveOrderDown index model.planningState }, Cmd.none )

        SelectProgramOrder index ->
            ( { model | planningState = Programmer.Update.selectProgramOrder index model.planningState }, Cmd.none )

        SaveProgram ->
            ( { model | planningState = Programmer.Update.saveProgram model.planningState }, Cmd.none )

        TrainClicked trainId ->
            ( { model | selectedTrainId = Just trainId }, Cmd.none )

        DeselectTrain ->
            ( { model | selectedTrainId = Nothing }, Cmd.none )

        SaveTick _ ->
            ( model, saveToStorage (Encode.encode 0 (extractSavedState model)) )

        ResetGame ->
            ( model, clearStorage () )



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
            { gameTime = model.gameTime
            , mode = modeString
            , turnoutState = turnoutString
            , activeTrains = savedTrains
            , spawnedTrainIds = Set.toList model.spawnedTrainIds
            , scheduledTrains = model.planningState.scheduledTrains
            , inventories = model.planningState.inventories
            , nextTrainId = model.planningState.nextTrainId
            , cameraX = model.cameraState.camera.center.x
            , cameraY = model.cameraState.camera.center.y
            , cameraZoom = model.cameraState.camera.zoom
            , timeMultiplier = model.timeMultiplier
            }
    in
    Storage.encodeSavedState savedState


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
        , Html.Attributes.attribute "data-testid" "play-pause-button"
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
                , Html.Attributes.attribute "data-testid" ("speed-control-" ++ label)
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
            floor time

        seconds =
            modBy 60 totalSeconds

        secStr =
            String.padLeft 2 '0' (String.fromInt seconds)
    in
    div [ Html.Attributes.attribute "data-testid" "game-clock" ]
        [ text (GameTime.formatTime time)
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
        [ Html.Attributes.attribute "data-testid" "mode-indicator"
        , style "background" color
        , style "color" "#000"
        , style "padding" "4px 12px"
        , style "border-radius" "4px"
        , style "font-weight" "bold"
        ]
        [ text label ]


viewCanvas : Model -> Html Msg
viewCanvas model =
    let
        viewBoxStr =
            Camera.viewBoxString model.viewportSize model.cameraState.camera

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
        , Html.Attributes.attribute "data-testid" "svg-canvas"
        , style "background" "#3a5a3a" -- Grass green
        , style "flex" "1"
        , style "cursor"
            (if model.cameraState.dragState /= Nothing then
                "grabbing"

             else
                "default"
            )
        , SvgE.on "mousedown" (decodeMousePosition (\x y -> CameraMsg (Camera.StartDrag x y)))
        , SvgE.on "mousemove" (decodeMousePosition (\x y -> CameraMsg (Camera.Drag x y)))
        , SvgE.on "mouseup" (Decode.succeed (CameraMsg Camera.EndDrag))
        , SvgE.on "mouseleave" (Decode.succeed (CameraMsg Camera.EndDrag))
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
    Decode.map3 (\dy mx my -> ( CameraMsg (Camera.Zoom dy mx my), True ))
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
