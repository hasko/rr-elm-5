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
import Util.Vec2 as Vec2 exposing (Vec2)


{-| Half of standard rail gauge (1.435m / 2).
Used for offsetting rails from track centerline.
-}
halfGauge : Float
halfGauge =
    1.435 / 2


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
        -- Calculate direction vector and perpendicular offset
        direction =
            Vec2.subtract end start

        perp =
            Vec2.normalize (Vec2.perpendicular direction)

        -- Offset perpendicular to track direction (standard gauge = 1.435m)
        offset =
            Vec2.scale halfGauge perp

        -- Left rail points (offset in one direction)
        leftStart =
            Vec2.subtract start offset

        leftEnd =
            Vec2.subtract end offset

        leftPathStr =
            "M "
                ++ String.fromFloat leftStart.x
                ++ " "
                ++ String.fromFloat leftStart.y
                ++ " L "
                ++ String.fromFloat leftEnd.x
                ++ " "
                ++ String.fromFloat leftEnd.y

        -- Right rail points (offset in opposite direction)
        rightStart =
            Vec2.add start offset

        rightEnd =
            Vec2.add end offset

        rightPathStr =
            "M "
                ++ String.fromFloat rightStart.x
                ++ " "
                ++ String.fromFloat rightStart.y
                ++ " L "
                ++ String.fromFloat rightEnd.x
                ++ " "
                ++ String.fromFloat rightEnd.y
    in
    Svg.g []
        [ -- Left rail
          Svg.path
            [ SvgA.d leftPathStr
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            ]
            []

        -- Right rail
        , Svg.path
            [ SvgA.d rightPathStr
            , SvgA.stroke "#555"
            , SvgA.strokeWidth "1.5"
            , SvgA.fill "none"
            ]
            []
        ]


{-| Render rails for an arc segment.
-}
renderArcRails : { start : Vec2, end : Vec2, radius : Float, sweepFlag : Int } -> Svg msg
renderArcRails arc =
    let
        -- Inner and outer rail radii (standard gauge = 1.435m)
        innerRadius =
            arc.radius - halfGauge

        outerRadius =
            arc.radius + halfGauge

        -- Calculate the center of the arc to determine proper offsets
        -- We need to find perpendicular offsets at start and end points

        -- Direction from start to end
        chordVector =
            Vec2.subtract arc.end arc.start

        chordLength =
            Vec2.length chordVector

        -- Perpendicular to chord (points toward center for one direction)
        perpToChord =
            Vec2.normalize (Vec2.perpendicular chordVector)

        -- Distance from chord midpoint to center
        -- Using: h = sqrt(r^2 - (c/2)^2) where c is chord length
        halfChord =
            chordLength / 2

        heightToCenter =
            sqrt (max 0 (arc.radius * arc.radius - halfChord * halfChord))

        -- Midpoint of chord
        chordMid =
            Vec2.scale 0.5 (Vec2.add arc.start arc.end)

        -- Center is perpendicular from chord midpoint
        -- sweepFlag determines which side
        centerOffset =
            if arc.sweepFlag == 1 then
                Vec2.scale heightToCenter perpToChord
            else
                Vec2.scale -heightToCenter perpToChord

        center =
            Vec2.add chordMid centerOffset

        -- Tangent at start (perpendicular to radius at start)
        radiusAtStart =
            Vec2.subtract arc.start center

        tangentAtStart =
            Vec2.normalize (Vec2.perpendicular radiusAtStart)

        -- Tangent at end (perpendicular to radius at end)
        radiusAtEnd =
            Vec2.subtract arc.end center

        tangentAtEnd =
            Vec2.normalize (Vec2.perpendicular radiusAtEnd)

        -- For CW arcs (sweepFlag = 1), tangent points in positive perpendicular direction
        -- For CCW arcs (sweepFlag = 0), tangent points in negative perpendicular direction
        -- We want rails offset perpendicular to tangent (i.e., radially)

        -- Radial offset direction at start (toward/away from center)
        radialDirStart =
            Vec2.normalize radiusAtStart

        radialDirEnd =
            Vec2.normalize radiusAtEnd

        -- Inner rail points (closer to center)
        innerStart =
            Vec2.subtract arc.start (Vec2.scale 2 radialDirStart)

        innerEnd =
            Vec2.subtract arc.end (Vec2.scale 2 radialDirEnd)

        -- Outer rail points (farther from center)
        outerStart =
            Vec2.add arc.start (Vec2.scale 2 radialDirStart)

        outerEnd =
            Vec2.add arc.end (Vec2.scale 2 radialDirEnd)

        innerPath =
            "M "
                ++ String.fromFloat innerStart.x
                ++ " "
                ++ String.fromFloat innerStart.y
                ++ " A "
                ++ String.fromFloat innerRadius
                ++ " "
                ++ String.fromFloat innerRadius
                ++ " 0 0 "
                ++ String.fromInt arc.sweepFlag
                ++ " "
                ++ String.fromFloat innerEnd.x
                ++ " "
                ++ String.fromFloat innerEnd.y

        outerPath =
            "M "
                ++ String.fromFloat outerStart.x
                ++ " "
                ++ String.fromFloat outerStart.y
                ++ " A "
                ++ String.fromFloat outerRadius
                ++ " "
                ++ String.fromFloat outerRadius
                ++ " 0 0 "
                ++ String.fromInt arc.sweepFlag
                ++ " "
                ++ String.fromFloat outerEnd.x
                ++ " "
                ++ String.fromFloat outerEnd.y
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
