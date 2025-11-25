module Main exposing (main)

{-| Railroad Switching Puzzle Game

Main entry point and application shell.

-}

import Browser
import Browser.Events
import Html exposing (Html, div, text)
import Html.Attributes exposing (style)
import Sawmill.Layout as Layout exposing (ElementId(..), SwitchState(..))
import Sawmill.View as SawmillView
import Svg exposing (Svg, svg)
import Svg.Attributes as SvgA
import Time
import Util.Vec2 as Vec2 exposing (Vec2)



-- MAIN


main : Program () Model Msg
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
    { day : Int -- 0 = Monday, 4 = Friday
    , hour : Int -- 0-23
    , minute : Int -- 0-59
    }


type alias Camera =
    { center : Vec2 -- World coordinates
    , zoom : Float -- Pixels per meter
    }


type alias Model =
    { mode : GameMode
    , gameTime : GameTime
    , camera : Camera
    , viewportSize : { width : Float, height : Float }

    -- Sawmill puzzle state
    , turnoutState : SwitchState
    , hoveredElement : Maybe ElementId
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { mode = Planning
      , gameTime = { day = 0, hour = 6, minute = 0 }
      , camera =
            { center = Vec2.vec2 -50 60
            , zoom = 2.0 -- 2 pixels per meter
            }
      , viewportSize = { width = 800, height = 600 }
      , turnoutState = Normal
      , hoveredElement = Nothing
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = Tick Float -- Delta time in milliseconds
    | TogglePlayPause
    | SetMode GameMode
    | ElementHovered ElementId
    | ElementUnhovered
    | ElementClicked ElementId
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick deltaMs ->
            if model.mode == Running then
                ( { model | gameTime = advanceGameTime deltaMs model.gameTime }
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
                    in
                    ( { model | turnoutState = newState }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


{-| Advance game time. 1 real second = 1 game minute.
-}
advanceGameTime : Float -> GameTime -> GameTime
advanceGameTime deltaMs time =
    let
        -- Convert delta to game minutes (1 real ms = 1/1000 real sec = 1/1000 game min)
        deltaMinutes =
            deltaMs / 1000

        totalMinutes =
            toFloat time.minute + deltaMinutes

        newMinute =
            floor totalMinutes |> modBy 60

        carryHours =
            floor totalMinutes // 60

        totalHours =
            time.hour + carryHours

        newHour =
            modBy 24 totalHours

        carryDays =
            totalHours // 24

        newDay =
            modBy 5 (time.day + carryDays)

        -- Week is Mon-Fri (0-4)
    in
    { day = newDay
    , hour = newHour
    , minute = newMinute
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    if model.mode == Running then
        Browser.Events.onAnimationFrameDelta Tick

    else
        Sub.none



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
        , viewCanvas model
        ]


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
            , viewModeIndicator model.mode
            ]
        ]


viewGameTime : GameTime -> Html Msg
viewGameTime time =
    let
        dayName =
            case time.day of
                0 ->
                    "Mon"

                1 ->
                    "Tue"

                2 ->
                    "Wed"

                3 ->
                    "Thu"

                _ ->
                    "Fri"

        hourStr =
            String.padLeft 2 '0' (String.fromInt time.hour)

        minuteStr =
            String.padLeft 2 '0' (String.fromInt time.minute)
    in
    div []
        [ text (dayName ++ " " ++ hourStr ++ ":" ++ minuteStr) ]


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
            }

        -- Tooltip (rendered last so it's on top)
        , tooltipView
        ]


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
