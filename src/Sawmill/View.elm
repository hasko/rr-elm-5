module Sawmill.View exposing (view, viewTooltip)

{-| SVG rendering for the Sawmill puzzle layout.
-}

import Sawmill.Layout as Layout
    exposing
        ( Element(..)
        , ElementId(..)
        , InteractiveElement
        , SwitchState(..)
        )
import Svg exposing (Svg)
import Svg.Attributes as SvgA
import Svg.Events as SvgE
import Track.Element as TrackElement
import Track.Layout as TrackLayout
import Track.Render as TrackRender
import Util.Vec2 exposing (Vec2)


{-| Render the entire sawmill layout.
-}
view :
    { turnoutState : SwitchState
    , hoveredElement : Maybe ElementId
    , onElementClick : ElementId -> msg
    , onElementHover : ElementId -> msg
    , onElementUnhover : msg
    }
    -> Svg msg
view config =
    Svg.g []
        [ viewFurniture
        , viewTrack config.turnoutState
        , viewInteractiveElements config
        ]



-- FURNITURE (DECORATIVE)


viewFurniture : Svg msg
viewFurniture =
    let
        furn =
            Layout.furniture
    in
    Svg.g []
        [ -- Trees
          Svg.g [] (List.map viewTree furn.trees)

        -- Sawmill building
        , viewSawmill furn.sawmill

        -- Passenger platform structure
        , viewPlatformStructure furn.platform

        -- Team track ramp
        , viewRamp furn.teamTrackRamp
        ]


viewTree : Vec2 -> Svg msg
viewTree pos =
    Svg.circle
        [ SvgA.cx (String.fromFloat pos.x)
        , SvgA.cy (String.fromFloat pos.y)
        , SvgA.r "8"
        , SvgA.fill "#2d5a2d"
        , SvgA.opacity "0.7"
        ]
        []


viewSawmill : { position : Vec2, width : Float, height : Float } -> Svg msg
viewSawmill { position, width, height } =
    Svg.g []
        [ -- Main building
          Svg.rect
            [ SvgA.x (String.fromFloat (position.x - width / 2))
            , SvgA.y (String.fromFloat (position.y - height / 2))
            , SvgA.width (String.fromFloat width)
            , SvgA.height (String.fromFloat height)
            , SvgA.fill "#8b7355"
            , SvgA.stroke "#5a4a3a"
            , SvgA.strokeWidth "2"
            ]
            []

        -- Roof indication (darker strip)
        , Svg.rect
            [ SvgA.x (String.fromFloat (position.x - width / 2))
            , SvgA.y (String.fromFloat (position.y - height / 2))
            , SvgA.width (String.fromFloat width)
            , SvgA.height "10"
            , SvgA.fill "#6a5a4a"
            ]
            []

        -- Log pile
        , Svg.g []
            (List.range 0 4
                |> List.map
                    (\i ->
                        Svg.rect
                            [ SvgA.x (String.fromFloat (position.x + width / 2 + 5))
                            , SvgA.y (String.fromFloat (position.y - 20 + toFloat i * 8))
                            , SvgA.width "20"
                            , SvgA.height "6"
                            , SvgA.fill "#a08060"
                            , SvgA.rx "2"
                            ]
                            []
                    )
            )
        ]


viewPlatformStructure : { position : Vec2, width : Float, height : Float } -> Svg msg
viewPlatformStructure { position, width, height } =
    Svg.g []
        [ -- Platform surface
          Svg.rect
            [ SvgA.x (String.fromFloat (position.x - width / 2))
            , SvgA.y (String.fromFloat (position.y - height / 2))
            , SvgA.width (String.fromFloat width)
            , SvgA.height (String.fromFloat height)
            , SvgA.fill "#888"
            , SvgA.stroke "#666"
            , SvgA.strokeWidth "1"
            ]
            []

        -- Small shelter
        , Svg.rect
            [ SvgA.x (String.fromFloat (position.x - width / 2 + 5))
            , SvgA.y (String.fromFloat (position.y - height / 2 + 2))
            , SvgA.width "12"
            , SvgA.height "8"
            , SvgA.fill "#666"
            ]
            []
        ]


viewRamp : { position : Vec2, width : Float, height : Float } -> Svg msg
viewRamp { position, width, height } =
    Svg.rect
        [ SvgA.x (String.fromFloat (position.x - width / 2))
        , SvgA.y (String.fromFloat (position.y - height / 2))
        , SvgA.width (String.fromFloat width)
        , SvgA.height (String.fromFloat height)
        , SvgA.fill "#9a8a7a"
        , SvgA.stroke "#7a6a5a"
        , SvgA.strokeWidth "1"
        ]
        []



-- TRACK


viewTrack : SwitchState -> Svg msg
viewTrack turnoutState =
    let
        -- Get render segments from the track layout
        segments =
            TrackRender.layoutToRenderSegments Layout.trackLayout
    in
    Svg.g []
        (-- Render all ballast first
         List.map TrackRender.renderBallast segments
            ++ -- Then render all rails
               List.map TrackRender.renderRails segments
            ++ -- Turnout switch point indicator
               [ viewTurnoutIndicator turnoutState ]
        )


viewTurnoutIndicator : SwitchState -> Svg msg
viewTurnoutIndicator state =
    let
        -- Get turnout position from layout (element 2, connector 0)
        turnoutPos =
            case TrackLayout.getConnector (TrackElement.ElementId 2) 0 Layout.trackLayout of
                Just c ->
                    c.position

                Nothing ->
                    { x = 0, y = 0 }

        -- Switch blade indication
        ( activeColor, indicatorAngle ) =
            case state of
                Normal ->
                    ( "#4a4", 0 )  -- Green, pointing along mainline

                Reverse ->
                    ( "#44a", 15 )  -- Blue, pointing toward siding
    in
    Svg.g
        [ SvgA.transform
            ("translate("
                ++ String.fromFloat turnoutPos.x
                ++ ","
                ++ String.fromFloat turnoutPos.y
                ++ ")"
            )
        ]
        [ -- Small indicator at the toe
          Svg.circle
            [ SvgA.cx "0"
            , SvgA.cy "0"
            , SvgA.r "4"
            , SvgA.fill activeColor
            , SvgA.stroke "#333"
            , SvgA.strokeWidth "1"
            ]
            []

        -- Direction indicator line showing which route is set
        , Svg.line
            [ SvgA.x1 "0"
            , SvgA.y1 "0"
            , SvgA.x2 (String.fromFloat (12 * cos (degrees indicatorAngle)))
            , SvgA.y2 (String.fromFloat (12 * sin (degrees indicatorAngle)))
            , SvgA.stroke activeColor
            , SvgA.strokeWidth "3"
            , SvgA.strokeLinecap "round"
            ]
            []
        ]



-- INTERACTIVE ELEMENTS


viewInteractiveElements :
    { turnoutState : SwitchState
    , hoveredElement : Maybe ElementId
    , onElementClick : ElementId -> msg
    , onElementHover : ElementId -> msg
    , onElementUnhover : msg
    }
    -> Svg msg
viewInteractiveElements config =
    Svg.g []
        (Layout.interactiveElements config.turnoutState
            |> List.map (viewInteractiveElement config)
        )


viewInteractiveElement :
    { turnoutState : SwitchState
    , hoveredElement : Maybe ElementId
    , onElementClick : ElementId -> msg
    , onElementHover : ElementId -> msg
    , onElementUnhover : msg
    }
    -> InteractiveElement
    -> Svg msg
viewInteractiveElement config elem =
    let
        isHovered =
            config.hoveredElement == Just elem.id

        hoverOutline =
            if isHovered then
                [ Svg.rect
                    [ SvgA.x (String.fromFloat elem.bounds.x)
                    , SvgA.y (String.fromFloat elem.bounds.y)
                    , SvgA.width (String.fromFloat elem.bounds.width)
                    , SvgA.height (String.fromFloat elem.bounds.height)
                    , SvgA.fill "none"
                    , SvgA.stroke "#fff"
                    , SvgA.strokeWidth "2"
                    , SvgA.strokeDasharray "4,2"
                    , SvgA.rx "3"
                    ]
                    []
                ]

            else
                []
    in
    Svg.g []
        (viewElement elem.element
            :: hoverOutline
            ++ [ -- Invisible hit area with hover events
                 Svg.rect
                    [ SvgA.x (String.fromFloat elem.bounds.x)
                    , SvgA.y (String.fromFloat elem.bounds.y)
                    , SvgA.width (String.fromFloat elem.bounds.width)
                    , SvgA.height (String.fromFloat elem.bounds.height)
                    , SvgA.fill "transparent"
                    , SvgA.style "cursor: pointer"
                    , SvgE.onClick (config.onElementClick elem.id)
                    , SvgE.onMouseOver (config.onElementHover elem.id)
                    , SvgE.onMouseOut config.onElementUnhover
                    ]
                    []
               ]
        )


viewElement : Element -> Svg msg
viewElement element =
    case element of
        TunnelPortal pos name ->
            viewTunnelPortal pos name

        Turnout pos orientation state ->
            -- Already rendered in track section
            Svg.g [] []

        Spot pos name spotType ->
            viewSpot pos name spotType

        BufferStop pos orientation ->
            viewBufferStop pos orientation


viewTunnelPortal : Vec2 -> String -> Svg msg
viewTunnelPortal pos name =
    Svg.g []
        [ -- Tunnel arch
          Svg.path
            [ SvgA.d
                ("M "
                    ++ String.fromFloat (pos.x - 15)
                    ++ " "
                    ++ String.fromFloat (pos.y + 15)
                    ++ " L "
                    ++ String.fromFloat (pos.x - 15)
                    ++ " "
                    ++ String.fromFloat (pos.y - 10)
                    ++ " A 15 15 0 0 1 "
                    ++ String.fromFloat (pos.x + 15)
                    ++ " "
                    ++ String.fromFloat (pos.y - 10)
                    ++ " L "
                    ++ String.fromFloat (pos.x + 15)
                    ++ " "
                    ++ String.fromFloat (pos.y + 15)
                )
            , SvgA.fill "#3a3a3a"
            , SvgA.stroke "#2a2a2a"
            , SvgA.strokeWidth "2"
            ]
            []

        -- Dark interior
        , Svg.ellipse
            [ SvgA.cx (String.fromFloat pos.x)
            , SvgA.cy (String.fromFloat pos.y)
            , SvgA.rx "10"
            , SvgA.ry "12"
            , SvgA.fill "#1a1a1a"
            ]
            []

        -- Label
        , Svg.text_
            [ SvgA.x (String.fromFloat pos.x)
            , SvgA.y (String.fromFloat (pos.y - 25))
            , SvgA.textAnchor "middle"
            , SvgA.fontSize "8"
            , SvgA.fill "#ddd"
            , SvgA.fontFamily "sans-serif"
            ]
            [ Svg.text name ]
        ]


viewSpot : Vec2 -> String -> Layout.SpotType -> Svg msg
viewSpot pos name spotType =
    let
        ( color, symbol ) =
            case spotType of
                Layout.Passenger ->
                    ( "#4a9eff", "P" )

                Layout.Freight ->
                    ( "#ffaa4a", "F" )
    in
    Svg.g []
        [ -- Spot marker
          Svg.rect
            [ SvgA.x (String.fromFloat (pos.x - 8))
            , SvgA.y (String.fromFloat (pos.y - 8))
            , SvgA.width "16"
            , SvgA.height "16"
            , SvgA.fill color
            , SvgA.fillOpacity "0.3"
            , SvgA.stroke color
            , SvgA.strokeWidth "2"
            , SvgA.rx "2"
            ]
            []

        -- Symbol
        , Svg.text_
            [ SvgA.x (String.fromFloat pos.x)
            , SvgA.y (String.fromFloat (pos.y + 3))
            , SvgA.textAnchor "middle"
            , SvgA.fontSize "10"
            , SvgA.fill color
            , SvgA.fontFamily "sans-serif"
            , SvgA.fontWeight "bold"
            ]
            [ Svg.text symbol ]

        -- Label
        , Svg.text_
            [ SvgA.x (String.fromFloat (pos.x + 20))
            , SvgA.y (String.fromFloat (pos.y + 3))
            , SvgA.fontSize "7"
            , SvgA.fill "#ccc"
            , SvgA.fontFamily "sans-serif"
            ]
            [ Svg.text name ]
        ]


viewBufferStop : Vec2 -> Float -> Svg msg
viewBufferStop pos orientation =
    Svg.g
        [ SvgA.transform
            ("translate("
                ++ String.fromFloat pos.x
                ++ ","
                ++ String.fromFloat pos.y
                ++ ") rotate("
                ++ String.fromFloat (orientation * 180 / pi)
                ++ ")"
            )
        ]
        [ -- Buffer beam
          Svg.rect
            [ SvgA.x "-8"
            , SvgA.y "-2"
            , SvgA.width "16"
            , SvgA.height "4"
            , SvgA.fill "#8a2a2a"
            ]
            []

        -- Buffer posts
        , Svg.rect
            [ SvgA.x "-6"
            , SvgA.y "2"
            , SvgA.width "3"
            , SvgA.height "6"
            , SvgA.fill "#6a1a1a"
            ]
            []
        , Svg.rect
            [ SvgA.x "3"
            , SvgA.y "2"
            , SvgA.width "3"
            , SvgA.height "6"
            , SvgA.fill "#6a1a1a"
            ]
            []
        ]



-- TOOLTIP


viewTooltip : Vec2 -> String -> Svg msg
viewTooltip pos text =
    let
        padding =
            4

        fontSize =
            10

        textWidth =
            toFloat (String.length text) * 5.5

        boxWidth =
            textWidth + padding * 2

        boxHeight =
            toFloat fontSize + padding * 2
    in
    Svg.g []
        [ -- Background
          Svg.rect
            [ SvgA.x (String.fromFloat (pos.x + 10))
            , SvgA.y (String.fromFloat (pos.y - boxHeight / 2))
            , SvgA.width (String.fromFloat boxWidth)
            , SvgA.height (String.fromFloat boxHeight)
            , SvgA.fill "#222"
            , SvgA.fillOpacity "0.9"
            , SvgA.rx "3"
            ]
            []

        -- Text
        , Svg.text_
            [ SvgA.x (String.fromFloat (pos.x + 10 + padding))
            , SvgA.y (String.fromFloat (pos.y + 3))
            , SvgA.fontSize (String.fromInt fontSize)
            , SvgA.fill "#fff"
            , SvgA.fontFamily "sans-serif"
            ]
            [ Svg.text text ]
        ]



-- HELPERS


pointsToPath : List Vec2 -> String
pointsToPath points =
    points
        |> List.map (\p -> String.fromFloat p.x ++ " " ++ String.fromFloat p.y)
        |> String.join " L "
