module Track.Render exposing
    ( RenderSegment(..)
    , elementToRenderSegments
    , layoutToRenderSegments
    , renderBallast
    , renderRails
    , renderSegmentToPath
    )

{-| SVG rendering for track elements.

Converts track elements to render segments, then to SVG paths.
Apply scale(1,-1) transform at SVG group level to flip Y axis
from math coords to screen coords.

-}

import Array
import Svg exposing (Svg)
import Svg.Attributes as SvgA
import Track.Element as Element
    exposing
        ( Connector
        , PlacedElement
        , TrackElementType(..)
        )
import Track.Layout exposing (Layout)
import Util.Vec2 exposing (Vec2)


{-| A renderable track segment.
-}
type RenderSegment
    = RenderStraight { start : Vec2, end : Vec2 }
    | RenderArc
        { start : Vec2
        , end : Vec2
        , radius : Float
        , sweepFlag : Int -- 0 = CCW, 1 = CW (SVG convention)
        }


{-| Convert a placed element to render segments (one per route).
-}
elementToRenderSegments : PlacedElement -> List RenderSegment
elementToRenderSegments element =
    case element.elementType of
        StraightTrack _ ->
            case ( Array.get 0 element.connectors, Array.get 1 element.connectors ) of
                ( Just c0, Just c1 ) ->
                    [ RenderStraight { start = c0.position, end = c1.position } ]

                _ ->
                    []

        CurvedTrack { sweep } ->
            case ( Array.get 0 element.connectors, Array.get 1 element.connectors ) of
                ( Just c0, Just c1 ) ->
                    [ curvedSegmentToRender c0 c1 sweep ]

                _ ->
                    []

        Turnout spec ->
            let
                maybeC0 =
                    Array.get 0 element.connectors

                maybeC1 =
                    Array.get 1 element.connectors

                maybeC2 =
                    Array.get 2 element.connectors
            in
            case ( maybeC0, maybeC1, maybeC2 ) of
                ( Just c0, Just c1, Just c2 ) ->
                    let
                        -- Through route (straight)
                        throughSegment =
                            RenderStraight { start = c0.position, end = c1.position }

                        -- Diverging route (curved)
                        -- Must match the sign convention in Element.computeTurnoutConnectors
                        actualSweep =
                            case spec.hand of
                                Element.LeftHand ->
                                    -spec.sweep -- left = CCW = negative

                                Element.RightHand ->
                                    spec.sweep -- right = CW = positive

                        divergingSegment =
                            curvedSegmentToRender c0 c2 actualSweep
                    in
                    [ throughSegment, divergingSegment ]

                _ ->
                    []

        TrackEnd ->
            -- Track ends don't render track segments
            []


{-| Create a render segment for a curve.
-}
curvedSegmentToRender : Connector -> Connector -> Float -> RenderSegment
curvedSegmentToRender start end sweep =
    RenderArc
        { start = start.position
        , end = end.position
        , radius = abs (computeRadiusFromConnectors start end sweep)
        , sweepFlag =
            if sweep >= 0 then
                1
                -- CW (positive sweep = clockwise in our coords)

            else
                0
        -- CCW (negative sweep = counter-clockwise)
        }


{-| Compute radius from two connectors and sweep angle.
This is needed because we store connectors, not the original radius.
For better accuracy, we could store the radius in the element.
-}
computeRadiusFromConnectors : Connector -> Connector -> Float -> Float
computeRadiusFromConnectors start end sweep =
    let
        -- Distance between start and end
        dx =
            end.position.x - start.position.x

        dy =
            end.position.y - start.position.y

        chordLength =
            sqrt (dx * dx + dy * dy)

        -- For a circular arc: chord = 2 * radius * sin(sweep/2)
        -- So radius = chord / (2 * sin(sweep/2))
        halfSweep =
            abs sweep / 2
    in
    if halfSweep > 0.001 then
        chordLength / (2 * sin halfSweep)

    else
        -- Nearly straight, use large radius
        1000


{-| Convert all elements in a layout to render segments.
-}
layoutToRenderSegments : Layout -> List RenderSegment
layoutToRenderSegments layout =
    layout.elements
        |> List.concatMap elementToRenderSegments


{-| Convert a render segment to an SVG path string.
-}
renderSegmentToPath : RenderSegment -> String
renderSegmentToPath segment =
    case segment of
        RenderStraight { start, end } ->
            "M "
                ++ String.fromFloat start.x
                ++ " "
                ++ String.fromFloat start.y
                ++ " L "
                ++ String.fromFloat end.x
                ++ " "
                ++ String.fromFloat end.y

        RenderArc { start, end, radius, sweepFlag } ->
            "M "
                ++ String.fromFloat start.x
                ++ " "
                ++ String.fromFloat start.y
                ++ " A "
                ++ String.fromFloat radius
                ++ " "
                ++ String.fromFloat radius
                ++ " 0 0 "
                ++ String.fromInt sweepFlag
                ++ " "
                ++ String.fromFloat end.x
                ++ " "
                ++ String.fromFloat end.y



-- SVG RENDERING


{-| Render ballast (track bed) for a segment.
-}
renderBallast : RenderSegment -> Svg msg
renderBallast segment =
    Svg.path
        [ SvgA.d (renderSegmentToPath segment)
        , SvgA.stroke "#8b7355"
        , SvgA.strokeWidth "12"
        , SvgA.strokeLinecap "round"
        , SvgA.fill "none"
        ]
        []


{-| Render rails for a segment.
-}
renderRails : RenderSegment -> Svg msg
renderRails segment =
    case segment of
        RenderStraight { start, end } ->
            renderStraightRails start end

        RenderArc arc ->
            renderArcRails arc


{-| Render rails for a straight segment.
-}
renderStraightRails : Vec2 -> Vec2 -> Svg msg
renderStraightRails start end =
    let
        pathStr =
            "M "
                ++ String.fromFloat start.x
                ++ " "
                ++ String.fromFloat start.y
                ++ " L "
                ++ String.fromFloat end.x
                ++ " "
                ++ String.fromFloat end.y
    in
    Svg.g []
        [ -- Left rail
          Svg.path
            [ SvgA.d pathStr
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            , SvgA.transform "translate(0, -2)"
            ]
            []

        -- Right rail
        , Svg.path
            [ SvgA.d pathStr
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            , SvgA.transform "translate(0, 2)"
            ]
            []
        ]


{-| Render rails for an arc segment.
-}
renderArcRails : { start : Vec2, end : Vec2, radius : Float, sweepFlag : Int } -> Svg msg
renderArcRails arc =
    let
        -- Inner and outer rail radii
        innerRadius =
            arc.radius - 2

        outerRadius =
            arc.radius + 2

        -- Approximate inner/outer endpoints (good enough for small gauge)
        innerPath =
            "M "
                ++ String.fromFloat arc.start.x
                ++ " "
                ++ String.fromFloat (arc.start.y - 2)
                ++ " A "
                ++ String.fromFloat innerRadius
                ++ " "
                ++ String.fromFloat innerRadius
                ++ " 0 0 "
                ++ String.fromInt arc.sweepFlag
                ++ " "
                ++ String.fromFloat arc.end.x
                ++ " "
                ++ String.fromFloat (arc.end.y - 2)

        outerPath =
            "M "
                ++ String.fromFloat arc.start.x
                ++ " "
                ++ String.fromFloat (arc.start.y + 2)
                ++ " A "
                ++ String.fromFloat outerRadius
                ++ " "
                ++ String.fromFloat outerRadius
                ++ " 0 0 "
                ++ String.fromInt arc.sweepFlag
                ++ " "
                ++ String.fromFloat arc.end.x
                ++ " "
                ++ String.fromFloat (arc.end.y + 2)
    in
    Svg.g []
        [ Svg.path
            [ SvgA.d innerPath
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            ]
            []
        , Svg.path
            [ SvgA.d outerPath
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            ]
            []
        ]
