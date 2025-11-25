module Train.Route exposing
    ( eastToWestRoute
    , positionOnRoute
    , westToEastRoute
    )

{-| Route building and position lookup for trains.
-}

import Array
import Sawmill.Layout exposing (trackLayout)
import Track.Element as Element exposing (ElementId(..), TrackElementType(..))
import Track.Layout as Layout exposing (Layout)
import Train.Types exposing (Route, RouteSegment, SegmentGeometry(..))
import Util.Vec2 as Vec2 exposing (Vec2, vec2)


{-| Build the East-to-West mainline route.

Elements traversed:

  - Element 0: East tunnel portal (TrackEnd) - start point
  - Element 1: Mainline east (250m straight)
  - Element 2: Turnout (through route, ~50m)
  - Element 3: Mainline west (200m straight)
  - Element 7: West tunnel portal (TrackEnd) - end point

-}
eastToWestRoute : Route
eastToWestRoute =
    buildMainlineRoute trackLayout


{-| Build the West-to-East mainline route (reverse direction).
-}
westToEastRoute : Route
westToEastRoute =
    reverseRoute eastToWestRoute


{-| Build the mainline route from the layout.
-}
buildMainlineRoute : Layout -> Route
buildMainlineRoute layout =
    let
        -- Get connectors for each element
        getConn elementIdx connIdx =
            Layout.getConnector (ElementId elementIdx) connIdx layout

        -- Element 1: Mainline east (250m straight)
        segment1 =
            case ( getConn 1 0, getConn 1 1 ) of
                ( Just c0, Just c1 ) ->
                    { elementId = ElementId 1
                    , length = 250.0
                    , startDistance = 0.0
                    , geometry =
                        StraightGeometry
                            { start = c0.position
                            , end = c1.position
                            , orientation = Element.flipOrientation c0.orientation
                            }
                    }

                _ ->
                    defaultSegment 1 250.0 0.0

        -- Element 2: Turnout through route (~50m)
        -- Through route goes from connector 0 to connector 1
        segment2 =
            case ( getConn 2 0, getConn 2 1 ) of
                ( Just c0, Just c1 ) ->
                    { elementId = ElementId 2
                    , length = 50.0
                    , startDistance = 250.0
                    , geometry =
                        StraightGeometry
                            { start = c0.position
                            , end = c1.position
                            , orientation = Element.flipOrientation c0.orientation
                            }
                    }

                _ ->
                    defaultSegment 2 50.0 250.0

        -- Element 3: Mainline west (200m straight)
        segment3 =
            case ( getConn 3 0, getConn 3 1 ) of
                ( Just c0, Just c1 ) ->
                    { elementId = ElementId 3
                    , length = 200.0
                    , startDistance = 300.0
                    , geometry =
                        StraightGeometry
                            { start = c0.position
                            , end = c1.position
                            , orientation = Element.flipOrientation c0.orientation
                            }
                    }

                _ ->
                    defaultSegment 3 200.0 300.0

        segments =
            [ segment1, segment2, segment3 ]

        totalLength =
            List.foldl (\s acc -> acc + s.length) 0 segments
    in
    { segments = segments
    , totalLength = totalLength
    }


{-| Reverse a route for travel in opposite direction.
-}
reverseRoute : Route -> Route
reverseRoute route =
    let
        reversedSegments =
            route.segments
                |> List.reverse
                |> List.indexedMap
                    (\idx seg ->
                        let
                            -- Recalculate start distance
                            newStartDistance =
                                List.take idx (List.reverse route.segments)
                                    |> List.foldl (\s acc -> acc + s.length) 0
                        in
                        { seg
                            | startDistance = newStartDistance
                            , geometry = reverseGeometry seg.geometry
                        }
                    )
    in
    { segments = reversedSegments
    , totalLength = route.totalLength
    }


{-| Reverse the geometry of a segment.
-}
reverseGeometry : SegmentGeometry -> SegmentGeometry
reverseGeometry geom =
    case geom of
        StraightGeometry { start, end, orientation } ->
            StraightGeometry
                { start = end
                , end = start
                , orientation = Element.normalizeAngle (orientation + pi)
                }

        ArcGeometry { center, radius, startAngle, sweep } ->
            ArcGeometry
                { center = center
                , radius = radius
                , startAngle = startAngle + sweep
                , sweep = -sweep
                }


{-| Default segment for fallback.
-}
defaultSegment : Int -> Float -> Float -> RouteSegment
defaultSegment elementIdx length startDist =
    { elementId = ElementId elementIdx
    , length = length
    , startDistance = startDist
    , geometry =
        StraightGeometry
            { start = vec2 0 0
            , end = vec2 length 0
            , orientation = 0
            }
    }


{-| Get position and orientation at a distance along the route.
Returns Nothing if distance is outside the route.
-}
positionOnRoute : Float -> Route -> Maybe { position : Vec2, orientation : Float }
positionOnRoute distance route =
    if distance < 0 || distance > route.totalLength then
        Nothing

    else
        findSegmentAndInterpolate distance route.segments


{-| Find the segment containing the distance and interpolate position.
-}
findSegmentAndInterpolate : Float -> List RouteSegment -> Maybe { position : Vec2, orientation : Float }
findSegmentAndInterpolate distance segments =
    case segments of
        [] ->
            Nothing

        segment :: rest ->
            let
                segmentEnd =
                    segment.startDistance + segment.length
            in
            if distance <= segmentEnd then
                -- Distance is within this segment
                let
                    localDistance =
                        distance - segment.startDistance

                    t =
                        if segment.length > 0 then
                            localDistance / segment.length

                        else
                            0
                in
                Just (interpolateGeometry t segment.geometry)

            else
                -- Try next segment
                findSegmentAndInterpolate distance rest


{-| Interpolate position within a segment geometry.
t is 0..1 representing progress through the segment.
-}
interpolateGeometry : Float -> SegmentGeometry -> { position : Vec2, orientation : Float }
interpolateGeometry t geom =
    case geom of
        StraightGeometry { start, end, orientation } ->
            { position = Vec2.lerp t start end
            , orientation = orientation
            }

        ArcGeometry { center, radius, startAngle, sweep } ->
            let
                -- Current angle along the arc
                currentAngle =
                    startAngle + t * sweep

                -- Position on arc
                position =
                    vec2
                        (center.x + radius * cos currentAngle)
                        (center.y + radius * sin currentAngle)

                -- Orientation is tangent to arc (perpendicular to radius)
                -- For CCW (positive sweep), tangent is 90° CCW from radius
                -- For CW (negative sweep), tangent is 90° CW from radius
                orientation =
                    if sweep >= 0 then
                        currentAngle + pi / 2

                    else
                        currentAngle - pi / 2
            in
            { position = position
            , orientation = Element.normalizeAngle orientation
            }
