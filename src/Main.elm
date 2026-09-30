port module Main exposing (main)

{-| Railroad Switching Puzzle Game

Main entry point and application shell.

-}

import Browser
import Browser.Events
import Camera
import Dict exposing (Dict)
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (disabled, style)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Planning.Types as Planning exposing (PanelMode(..), StockItem)
import Planning.Update
import Planning.View as PlanningView
import Programmer.Types as Programmer
import Programmer.Update
import Programmer.View as ProgrammerView
import Sawmill.Layout as Layout exposing (ElementId(..))
import Sawmill.View as SawmillView
import Scenario exposing (NodeType(..), Scenario)
import Scenario.Layout
import Set exposing (Set)
import Simulation
import Storage
import Svg exposing (Svg, svg)
import Svg.Attributes as SvgA
import Svg.Events as SvgE
import Time
import Track.Element exposing (SwitchState(..))
import Train.Route as Route
import Train.Types exposing (ActiveTrain, TrainState(..))
import Train.View as TrainView
import Util.GameTime as GameTime exposing (GameTime)
import Util.Vec2 as Vec2


{-| Port to save state to localStorage.
-}
port saveToStorage : String -> Cmd msg


{-| Port to clear localStorage and reload.
-}
port clearStorage : () -> Cmd msg



-- MAIN


type AppState
    = Loading
    | LoadFailed String
    | Ready Model


main : Program () AppState Msg
main =
    Browser.element
        { init = appInit
        , update = appUpdate
        , subscriptions = appSubscriptions
        , view = appView
        }



-- MODEL


type GameMode
    = Planning
    | Running
    | Paused


type alias Model =
    { scenario : Scenario
    , layoutResult : Scenario.Layout.LayoutResult
    , trackContext : Route.TrackContext
    , mode : GameMode
    , gameTime : GameTime
    , cameraState : Camera.CameraState
    , viewportSize : { width : Float, height : Float }

    -- Puzzle state
    , turnoutStates : Dict String SwitchState
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


appInit : () -> ( AppState, Cmd Msg )
appInit _ =
    ( Loading
    , Http.get
        { url = "/scenarios/sawmill.json"
        , expect = Http.expectJson ScenarioLoaded Scenario.decoder
        }
    )


{-| Default model for a loaded scenario with its computed layout.
-}
defaultModel : Scenario -> Scenario.Layout.LayoutResult -> Model
defaultModel scenario layoutResult =
    { scenario = scenario
    , layoutResult = layoutResult
    , trackContext = Route.makeTrackContext scenario layoutResult
    , mode = Planning
    , gameTime = GameTime.fromHourMinute 6 0
    , cameraState =
        { camera =
            { center = Vec2.vec2 200 60
            , zoom = 2.0 -- 2 pixels per meter
            }
        , dragState = Nothing
        }
    , viewportSize = { width = 800, height = 600 }
    , turnoutStates = layoutResult.turnoutStates
    , hoveredElement = Nothing
    , planningState = Planning.initPlanningState scenario.stations
    , activeTrains = []
    , spawnedTrainIds = Set.empty
    , timeMultiplier = 1.0
    , selectedTrainId = Nothing
    }



-- UPDATE


type Msg
    = ScenarioLoaded (Result Http.Error Scenario)
    | Tick Float -- Delta time in milliseconds
    | TogglePlayPause
    | ElementHovered ElementId
    | ElementUnhovered
    | ElementClicked ElementId
    | CameraMsg Camera.CameraMsg
    | SetTimeMultiplier Float
    | NoOp
      -- Storage messages
    | SaveTick
    | ResetGame
      -- Planning panel messages
    | ClosePlanningPanel
    | SelectSpawnPoint String
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


appUpdate : Msg -> AppState -> ( AppState, Cmd Msg )
appUpdate msg state =
    case state of
        Loading ->
            case msg of
                ScenarioLoaded (Ok scenario) ->
                    case Scenario.Layout.buildLayout scenario of
                        Ok layoutResult ->
                            ( Ready (defaultModel scenario layoutResult), Cmd.none )

                        Err layoutErr ->
                            ( LoadFailed ("Invalid scenario track layout: " ++ layoutErr), Cmd.none )

                ScenarioLoaded (Err err) ->
                    ( LoadFailed (httpErrorToString err), Cmd.none )

                _ ->
                    ( state, Cmd.none )

        LoadFailed _ ->
            ( state, Cmd.none )

        Ready model ->
            let
                ( newModel, cmd ) =
                    update msg model
            in
            ( Ready newModel, cmd )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ScenarioLoaded _ ->
            -- Handled by appUpdate
            ( model, Cmd.none )

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
                        , turnoutStates = model.turnoutStates
                        , selectedTrainId = model.selectedTrainId
                        }

                    result =
                        Simulation.tick model.trackContext deltaMs simState

                    planning =
                        model.planningState
                in
                ( { model
                    | gameTime = result.gameTime
                    , activeTrains = result.activeTrains
                    , spawnedTrainIds = result.spawnedTrainIds
                    , planningState = { planning | inventories = result.inventories }
                    , turnoutStates = result.turnoutStates
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

        ElementHovered elementId ->
            ( { model | hoveredElement = Just elementId }, Cmd.none )

        ElementUnhovered ->
            ( { model | hoveredElement = Nothing }, Cmd.none )

        ElementClicked elementId ->
            case elementId of
                TurnoutId ->
                    -- The map shows a single turnout marker; it controls the
                    -- scenario's first turnout node.
                    case model.trackContext.turnoutNodes of
                        turnoutNodeId :: _ ->
                            let
                                currentState =
                                    Dict.get turnoutNodeId model.turnoutStates
                                        |> Maybe.withDefault Normal

                                newState =
                                    case currentState of
                                        Normal ->
                                            Reverse

                                        Reverse ->
                                            Normal

                                newStates =
                                    Dict.insert turnoutNodeId newState model.turnoutStates

                                rebuiltTrains =
                                    List.map
                                        (Simulation.rebuildIfBeforeTurnouts model.trackContext newStates [ turnoutNodeId ])
                                        model.activeTrains
                            in
                            ( { model | turnoutStates = newStates, activeTrains = rebuiltTrains }, Cmd.none )

                        [] ->
                            ( model, Cmd.none )

                TunnelPortalId ->
                    -- Anchor portal (left): open planning with its linked station
                    ( openPlanningForPortal 0 model, Cmd.none )

                WestTunnelPortalId ->
                    -- Far portal (right): open planning with its linked station
                    ( openPlanningForPortal 1 model, Cmd.none )

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
            ( { model | planningState = Planning.Update.selectSpawnPoint spawnId model.planningState }, Cmd.none )

        SelectStockItem stock ->
            ( { model | planningState = Planning.Update.selectStockItem stock model.planningState }, Cmd.none )

        AddToConsistFront ->
            ( { model | planningState = Planning.Update.addToConsist True model.planningState }, Cmd.none )

        AddToConsistBack ->
            ( { model | planningState = Planning.Update.addToConsist False model.planningState }, Cmd.none )

        InsertInConsist index ->
            ( { model | planningState = Planning.Update.insertInConsist index model.planningState }, Cmd.none )

        RemoveFromConsist index ->
            ( { model | planningState = Planning.Update.removeFromConsist index model.planningState }, Cmd.none )

        ClearConsistBuilder ->
            ( { model | planningState = Planning.Update.clearConsistBuilder model.planningState }, Cmd.none )

        FlipLocoInConsist index ->
            ( { model | planningState = Planning.Update.flipLocoInConsist index model.planningState }, Cmd.none )

        ConsistDragStart screenX ->
            ( { model | planningState = Planning.Update.startConsistDrag screenX model.planningState }, Cmd.none )

        ConsistDragMove screenX ->
            ( { model | planningState = Planning.Update.moveConsistDrag screenX model.planningState }, Cmd.none )

        ConsistDragEnd ->
            ( { model | planningState = Planning.Update.endConsistDrag model.planningState }, Cmd.none )

        SetTimePickerHour hour ->
            ( { model | planningState = Planning.Update.setTimePickerHour hour model.planningState }, Cmd.none )

        SetTimePickerMinute minute ->
            ( { model | planningState = Planning.Update.setTimePickerMinute minute model.planningState }, Cmd.none )

        SetTimePickerDay day ->
            ( { model | planningState = Planning.Update.setTimePickerDay day model.planningState }, Cmd.none )

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

        SaveTick ->
            ( model, saveToStorage (Encode.encode 0 (extractSavedState model)) )

        ResetGame ->
            ( model, clearStorage () )



-- SCENARIO HELPERS


{-| Open the planning panel with the station linked to the portal at the
given index (in scenario portal definition order) selected.
Keeps the current selection if the portal has no linked station.
-}
openPlanningForPortal : Int -> Model -> Model
openPlanningForPortal portalIndex model =
    let
        planning =
            model.planningState

        selectedSpawnPoint =
            Scenario.portalNodeIds model.scenario
                |> List.drop portalIndex
                |> List.head
                |> Maybe.andThen (\portalId -> Scenario.stationForPortal portalId model.scenario)
                |> Maybe.map .id
                |> Maybe.withDefault planning.selectedSpawnPoint
    in
    { model
        | mode = Planning
        , planningState = { planning | selectedSpawnPoint = selectedSpawnPoint }
    }


{-| Display name of the portal at the given index (station name, or the
portal node id if no station is linked).
-}
portalDisplayName : Int -> Model -> String
portalDisplayName portalIndex model =
    case Scenario.portalNodeIds model.scenario |> List.drop portalIndex |> List.head of
        Just portalId ->
            Scenario.stationForPortal portalId model.scenario
                |> Maybe.map .name
                |> Maybe.withDefault portalId

        Nothing ->
            ""


{-| Switch state of the scenario's first turnout, for the map's single
turnout indicator.
-}
displayedTurnoutState : Model -> SwitchState
displayedTurnoutState model =
    model.trackContext.turnoutNodes
        |> List.head
        |> Maybe.andThen (\nodeId -> Dict.get nodeId model.turnoutStates)
        |> Maybe.withDefault Normal



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

        turnoutStrings =
            Dict.map
                (\_ state ->
                    case state of
                        Normal ->
                            "Normal"

                        Reverse ->
                            "Reverse"
                )
                model.turnoutStates

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
            , turnoutStates = turnoutStrings
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


appSubscriptions : AppState -> Sub Msg
appSubscriptions state =
    case state of
        Ready model ->
            subscriptions model

        _ ->
            Sub.none


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ -- Save every second
          Time.every 1000 (always SaveTick)

        -- Animation when running
        , if model.mode == Running then
            Browser.Events.onAnimationFrameDelta Tick

          else
            Sub.none
        ]



-- VIEW


appView : AppState -> Html Msg
appView state =
    case state of
        Loading ->
            viewLoading

        LoadFailed errMsg ->
            viewLoadFailed errMsg

        Ready model ->
            view model


viewLoading : Html Msg
viewLoading =
    div
        [ style "width" "100%"
        , style "height" "100%"
        , style "display" "flex"
        , style "justify-content" "center"
        , style "align-items" "center"
        , style "background" "#2a2a2a"
        , style "color" "#e0e0e0"
        , style "font-family" "monospace"
        , style "font-size" "18px"
        ]
        [ text "Loading scenario..." ]


viewLoadFailed : String -> Html Msg
viewLoadFailed errMsg =
    div
        [ style "width" "100%"
        , style "height" "100%"
        , style "display" "flex"
        , style "flex-direction" "column"
        , style "justify-content" "center"
        , style "align-items" "center"
        , style "background" "#2a2a2a"
        , style "color" "#ff6b6b"
        , style "font-family" "monospace"
        , style "gap" "12px"
        ]
        [ div [ style "font-size" "20px", style "font-weight" "bold" ] [ text "Failed to load scenario" ]
        , div [ style "font-size" "14px", style "color" "#aaa" ] [ text errMsg ]
        ]


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
                , stations = model.scenario.stations
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
                        , spots = scenarioSpots model.scenario
                        , switches = scenarioSwitches model.scenario
                        , spotNameFn = scenarioSpotName model.scenario
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


{-| Build spot info list from scenario data for the programmer view.
Includes edge spots and station portal spots.
-}
scenarioSpots : Scenario -> List ProgrammerView.SpotInfo
scenarioSpots scenario =
    let
        edgeSpots =
            scenario.track.edges
                |> List.concatMap .spots
                |> List.map
                    (\spot ->
                        { id = spot.id
                        , name = spot.name
                        , shortName = abbreviate spot.name
                        }
                    )

        portalSpots =
            scenario.stations
                |> List.map
                    (\station ->
                        { id = station.portal
                        , name = station.name
                        , shortName = abbreviate station.name
                        }
                    )
    in
    edgeSpots ++ portalSpots


{-| Build switch info list from scenario turnout nodes.
-}
scenarioSwitches : Scenario -> List ProgrammerView.SwitchInfo
scenarioSwitches scenario =
    scenario.track.nodes
        |> List.filterMap
            (\node ->
                case node.nodeType of
                    Turnout _ ->
                        Just { id = node.id, label = node.id }

                    _ ->
                        Nothing
            )


{-| Build a spot name lookup function from scenario data.
-}
scenarioSpotName : Scenario -> String -> String
scenarioSpotName scenario spotId =
    let
        edgeSpot =
            scenario.track.edges
                |> List.concatMap .spots
                |> List.filter (\s -> s.id == spotId)
                |> List.head
                |> Maybe.map .name
    in
    case edgeSpot of
        Just name ->
            name

        Nothing ->
            let
                stationPortal =
                    scenario.stations
                        |> List.filter (\s -> s.portal == spotId)
                        |> List.head
                        |> Maybe.map .name
            in
            case stationPortal of
                Just name ->
                    name

                Nothing ->
                    spotId


{-| Abbreviate a name to a short label (max ~4 chars).
-}
abbreviate : String -> String
abbreviate name =
    let
        words =
            String.words name
    in
    case words of
        [ single ] ->
            String.left 4 single

        first :: _ ->
            String.left 4 first

        [] ->
            name


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
                                    ++ Programmer.orderDescription (scenarioSpotName model.scenario) order

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
                            Layout.interactiveElements
                                { turnoutState = displayedTurnoutState model
                                , anchorPortalName = portalDisplayName 0 model
                                , farPortalName = portalDisplayName 1 model
                                }
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
            { turnoutState = displayedTurnoutState model
            , anchorPortalName = portalDisplayName 0 model
            , farPortalName = portalDisplayName 1 model
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
