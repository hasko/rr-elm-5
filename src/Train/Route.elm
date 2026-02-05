module Train.Route exposing
    ( buildRoute
    , eastToWestRoute
    , positionOnRoute
    , rebuildRoute
    , spotPosition
    , westToEastRoute
    )

{-| Route building and position lookup for trains.

Routes are built dynamically by walking the track layout graph,
respecting turnout state to choose between through and diverging paths.

-}

import Array
import Planning.Types exposing (SpawnPointId(..))
import Programmer.Types exposing (SpotId(..))
import Sawmill.Layout exposing (SwitchState(..), trackLayout)
import Track.Element as Element
    exposing
        ( Connector
        , ElementId(..)
        , Hand(..)
        , PlacedElement
        , TrackElementType(..)
        )
import Track.Layout as Layout exposing (Layout)
import Train.Types exposing (Route, RouteSegment, SegmentGeometry(..))
import Util.Vec2 as Vec2 exposing (Vec2, vec2)


{-| Build the East-to-West route respecting turnout state.

Starts from element 0 (east tunnel portal) connector 0,
walks through the layout following connections.

-}
eastToWestRoute : SwitchState -> Route
eastToWestRoute switchState =
    buildRoute (ElementId 0) 0 switchState trackLayout


{-| Build the West-to-East route respecting turnout state.
-}
westToEastRoute : SwitchState -> Route
westToEastRoute switchState =
    buildRoute (ElementId 7) 0 switchState trackLayout


{-| Rebuild a route for a spawn point with a new switch state.

The train's position (distance along route) remains valid because
route segments before the turnout divergence are identical regardless
of switch state. After the turnout, the route takes the new path.

-}
rebuildRoute : SpawnPointId -> SwitchState -> Route
rebuildRoute spawnPoint switchState =
    case spawnPoint of
        EastStation ->
            eastToWestRoute switchState

        WestStation ->
            westToEastRoute switchState


{-| Build a route by walking the track layout graph from a starting connector.

Starting from the given element's connector, we:
1. Follow the connection to enter the first track element
2. Determine the exit connector for that element (based on turnout state)
3. Build a route segment for the traversal
4. Follow the connection from the exit connector to the next element
5. Repeat until we reach a TrackEnd or dead end

-}
buildRoute : ElementId -> Int -> SwitchState -> Layout -> Route
buildRoute startElementId startConnIdx switchState layout =
    case Layout.findConnected startElementId startConnIdx layout of
        Nothing ->
            -- Start point has no connection, empty route
            { segments = [], totalLength = 0 }

        Just ( firstElementId, entryConnIdx ) ->
            let
                segments =
                    walkGraph firstElementId entryConnIdx switchState layout [] 0.0 20
            in
            { segments = segments
            , totalLength = List.foldl (\s acc -> acc + s.length) 0 segments
            }


{-| Walk the track graph, building route segments.

The maxSteps parameter prevents infinite loops in case of circular tracks.

-}
walkGraph :
    ElementId
    -> Int
    -> SwitchState
    -> Layout
    -> List RouteSegment
    -> Float
    -> Int
    -> List RouteSegment
walkGraph elementId entryConnIdx switchState layout accSegments accDistance maxSteps =
    if maxSteps <= 0 then
        accSegments

    else
        case Layout.findElement elementId layout of
            Nothing ->
                accSegments

            Just element ->
                case element.elementType of
                    TrackEnd ->
                        -- Reached the end of the line
                        accSegments

                    _ ->
                        -- Determine exit connector
                        let
                            exitConnIdx =
                                exitConnectorForElement element.elementType entryConnIdx switchState
                        in
                        case ( Array.get entryConnIdx element.connectors, Array.get exitConnIdx element.connectors ) of
                            ( Just entryConn, Just exitConn ) ->
                                let
                                    segment =
                                        buildSegment element entryConnIdx exitConnIdx entryConn exitConn accDistance
                                in
                                -- Follow connection from exit connector to next element
                                case Layout.findConnected elementId exitConnIdx layout of
                                    Nothing ->
                                        -- Dead end
                                        accSegments ++ [ segment ]

                                    Just ( nextElementId, nextEntryConnIdx ) ->
                                        walkGraph
                                            nextElementId
                                            nextEntryConnIdx
                                            switchState
                                            layout
                                            (accSegments ++ [ segment ])
                                            (accDistance + segment.length)
                                            (maxSteps - 1)

                            _ ->
                                accSegments


{-| Determine which connector to exit through, given the entry connector and turnout state.
-}
exitConnectorForElement : TrackElementType -> Int -> SwitchState -> Int
exitConnectorForElement elementType entryConnIdx switchState =
    case elementType of
        StraightTrack _ ->
            if entryConnIdx == 0 then
                1

            else
                0

        CurvedTrack _ ->
            if entryConnIdx == 0 then
                1

            else
                0

        Turnout _ ->
            -- Entry from toe (0) goes to through (1) or diverge (2)
            -- Entry from heel (1 or 2) always goes to toe (0)
            if entryConnIdx == 0 then
                case switchState of
                    Normal ->
                        1

                    Reverse ->
                        2

            else
                0

        TrackEnd ->
            0


{-| Build a RouteSegment for traversing an element from entry to exit connector.
-}
buildSegment : PlacedElement -> Int -> Int -> Connector -> Connector -> Float -> RouteSegment
buildSegment element entryConnIdx exitConnIdx entryConn exitConn startDistance =
    { elementId = element.id
    , length = segmentLength element.elementType entryConnIdx exitConnIdx
    , startDistance = startDistance
    , geometry = buildSegmentGeometry element entryConnIdx exitConnIdx entryConn exitConn
    }


{-| Compute the length of a traversal through an element.
-}
segmentLength : TrackElementType -> Int -> Int -> Float
segmentLength elementType entryConnIdx exitConnIdx =
    case elementType of
        StraightTrack len ->
            len

        CurvedTrack { radius, sweep } ->
            radius * abs sweep

        Turnout spec ->
            if (entryConnIdx == 0 && exitConnIdx == 1) || (entryConnIdx == 1 && exitConnIdx == 0) then
                spec.throughLength

            else
                spec.radius * spec.sweep

        TrackEnd ->
            0


{-| Build segment geometry for the traversal direction.
-}
buildSegmentGeometry : PlacedElement -> Int -> Int -> Connector -> Connector -> SegmentGeometry
buildSegmentGeometry element entryConnIdx exitConnIdx entryConn exitConn =
    case element.elementType of
        StraightTrack _ ->
            StraightGeometry
                { start = entryConn.position
                , end = exitConn.position
                , orientation = Element.flipOrientation entryConn.orientation
                }

        CurvedTrack { radius, sweep } ->
            buildArcGeometry entryConn exitConn radius sweep (entryConnIdx == 0)

        Turnout spec ->
            if (entryConnIdx == 0 && exitConnIdx == 1) || (entryConnIdx == 1 && exitConnIdx == 0) then
                -- Through route (straight)
                StraightGeometry
                    { start = entryConn.position
                    , end = exitConn.position
                    , orientation = Element.flipOrientation entryConn.orientation
                    }

            else
                -- Diverging route (curved)
                let
                    actualSweep =
                        case spec.hand of
                            LeftHand ->
                                -spec.sweep

                            RightHand ->
                                spec.sweep

                    isForward =
                        entryConnIdx == 0
                in
                buildArcGeometry entryConn exitConn spec.radius actualSweep isForward

        TrackEnd ->
            StraightGeometry
                { start = entryConn.position
                , end = entryConn.position
                , orientation = 0
                }


{-| Build arc geometry from entry/exit connectors.

Uses the same center computation as Track.Element.computeCurveExit
to ensure consistency.

isForward: True if traversing from connector 0 to connector 1 (or 2).

-}
buildArcGeometry : Connector -> Connector -> Float -> Float -> Bool -> SegmentGeometry
buildArcGeometry entryConn exitConn radius sweep isForward =
    let
        -- The curve start connector is at the connector 0 position.
        -- We always compute center from that end.
        ( curveStartConn, curveSweep ) =
            if isForward then
                ( entryConn, sweep )

            else
                ( exitConn, sweep )

        -- Travel direction from curve start
        travelDirection =
            Vec2.fromAngle (Element.flipOrientation curveStartConn.orientation)

        -- Center is perpendicular to travel direction
        toCenter =
            if curveSweep >= 0 then
                Vec2.perpendicular travelDirection

            else
                Vec2.negate (Vec2.perpendicular travelDirection)

        center =
            Vec2.add curveStartConn.position (Vec2.scale radius toCenter)

        -- Compute start and end angles (standard atan2 from center)
        entryAngle =
            atan2 (entryConn.position.y - center.y) (entryConn.position.x - center.x)

        exitAngle =
            atan2 (exitConn.position.y - center.y) (exitConn.position.x - center.x)

        -- Compute the actual sweep in standard angle space
        rawSweep =
            exitAngle - entryAngle

        actualSweep =
            if isForward then
                normalizeSweep rawSweep curveSweep

            else
                normalizeSweep rawSweep -curveSweep
    in
    ArcGeometry
        { center = center
        , radius = radius
        , startAngle = entryAngle
        , sweep = actualSweep
        }


{-| Normalize a raw sweep angle to match the expected direction.
-}
normalizeSweep : Float -> Float -> Float
normalizeSweep rawSweep expectedSweep =
    let
        twoPi =
            2 * pi

        -- Normalize to [0, 2pi) range first
        normalized =
            rawSweep - twoPi * toFloat (floor (rawSweep / twoPi))
    in
    if expectedSweep >= 0 then
        if normalized <= 0 then
            normalized + twoPi

        else
            normalized

    else if normalized >= 0 then
        normalized - twoPi

    else
        normalized



-- REVERSE


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



-- POSITION LOOKUP


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
                currentAngle =
                    startAngle + t * sweep

                position =
                    vec2
                        (center.x + radius * cos currentAngle)
                        (center.y + radius * sin currentAngle)

                orientation =
                    if sweep >= 0 then
                        currentAngle + pi / 2

                    else
                        currentAngle - pi / 2
            in
            { position = position
            , orientation = Element.normalizeAngle orientation
            }



-- SPOT POSITION MAPPING


{-| A spot's physical location on the track: which element and how far
along that element from connector 0 (the element's native start).
-}
type alias SpotLocation =
    { elementId : ElementId
    , localDistance : Float -- meters from connector 0
    , elementLength : Float -- total length of the element
    }


{-| Get the physical location of a spot on the track layout.

Distances are measured from the element's connector 0 along its travel direction:

  - PlatformSpot: 60m along siding straight (element 5, 150m total)
  - TeamTrackSpot: 120m along siding straight (element 5, 150m total)
  - EastTunnelSpot: at east tunnel portal (element 0, TrackEnd)
  - WestTunnelSpot: at west tunnel portal (element 7, TrackEnd)

-}
spotLocation : SpotId -> SpotLocation
spotLocation spotId =
    case spotId of
        PlatformSpot ->
            { elementId = ElementId 5
            , localDistance = 60.0
            , elementLength = 150.0
            }

        TeamTrackSpot ->
            { elementId = ElementId 5
            , localDistance = 120.0
            , elementLength = 150.0
            }

        EastTunnelSpot ->
            { elementId = ElementId 0
            , localDistance = 0.0
            , elementLength = 0.0
            }

        WestTunnelSpot ->
            { elementId = ElementId 7
            , localDistance = 0.0
            , elementLength = 0.0
            }


{-| Get the route distance for a spot on the given route.

Returns Nothing if the spot's element is not part of the route
(e.g., PlatformSpot is not reachable on the mainline-through route).

-}
spotPosition : SpotId -> Route -> Maybe Float
spotPosition spotId route =
    case spotId of
        EastTunnelSpot ->
            if routeStartsFromEast route then
                Just 0.0

            else if routeEndsAtEast route then
                Just route.totalLength

            else
                Nothing

        WestTunnelSpot ->
            if routeStartsFromWest route then
                Just 0.0

            else if routeEndsAtWest route then
                Just route.totalLength

            else
                Nothing

        _ ->
            findSpotOnRoute (spotLocation spotId) route


routeStartsFromEast : Route -> Bool
routeStartsFromEast route =
    case List.head route.segments of
        Just segment ->
            segment.elementId == ElementId 1

        Nothing ->
            False


routeEndsAtEast : Route -> Bool
routeEndsAtEast route =
    case lastElement route.segments of
        Just segment ->
            segment.elementId == ElementId 1

        Nothing ->
            False


routeStartsFromWest : Route -> Bool
routeStartsFromWest route =
    case List.head route.segments of
        Just segment ->
            segment.elementId == ElementId 3

        Nothing ->
            False


routeEndsAtWest : Route -> Bool
routeEndsAtWest route =
    case lastElement route.segments of
        Just segment ->
            segment.elementId == ElementId 3

        Nothing ->
            False


lastElement : List a -> Maybe a
lastElement list =
    case list of
        [] ->
            Nothing

        [ x ] ->
            Just x

        _ :: rest ->
            lastElement rest


findSpotOnRoute : SpotLocation -> Route -> Maybe Float
findSpotOnRoute location route =
    findSpotOnRouteHelper location route.segments


findSpotOnRouteHelper : SpotLocation -> List RouteSegment -> Maybe Float
findSpotOnRouteHelper location segments =
    case segments of
        [] ->
            Nothing

        segment :: rest ->
            if segment.elementId == location.elementId then
                let
                    isReversed =
                        isSegmentReversed segment

                    adjustedLocal =
                        if isReversed then
                            location.elementLength - location.localDistance

                        else
                            location.localDistance
                in
                Just (segment.startDistance + adjustedLocal)

            else
                findSpotOnRouteHelper location rest


isSegmentReversed : RouteSegment -> Bool
isSegmentReversed segment =
    let
        segmentStart =
            geometryStartPosition segment.geometry

        maybeConn0 =
            Layout.getConnector segment.elementId 0 trackLayout
    in
    case maybeConn0 of
        Just conn0 ->
            not (Vec2.distance segmentStart conn0.position < 1.0)

        Nothing ->
            False


geometryStartPosition : SegmentGeometry -> Vec2
geometryStartPosition geom =
    case geom of
        StraightGeometry { start } ->
            start

        ArcGeometry { center, radius, startAngle } ->
            vec2
                (center.x + radius * cos startAngle)
                (center.y + radius * sin startAngle)
