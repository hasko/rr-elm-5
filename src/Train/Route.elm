module Train.Route exposing
    ( TrackContext
    , buildRoute
    , elementStartDistance
    , makeTrackContext
    , positionOnRoute
    , routeEndStation
    , routeFromStation
    , spotPosition
    , turnoutElements
    , turnoutStartDistance
    )

{-| Route building and position lookup for trains.

Routes are built dynamically by walking the track layout graph,
respecting turnout states to choose between through and diverging paths.

All scenario-specific knowledge (which element is a portal, where spots
sit, which elements are turnouts) comes from the `TrackContext`, built
from the loaded scenario and its computed layout.

-}

import Array
import Dict exposing (Dict)
import Scenario exposing (Scenario, Station)
import Scenario.Layout exposing (LayoutResult, SpotLocation)
import Track.Element as Element
    exposing
        ( Connector
        , ElementId(..)
        , Hand(..)
        , PlacedElement
        , SwitchState(..)
        , TrackElementType(..)
        )
import Track.Layout as Layout exposing (Layout)
import Train.Types exposing (Route, RouteSegment, SegmentGeometry(..))
import Util.Vec2 as Vec2 exposing (Vec2, vec2)



-- CONTEXT


{-| Everything route building needs to know about the world:
the computed track layout plus lookups from scenario ids to elements.
-}
type alias TrackContext =
    { layout : Layout
    , nodeElementMap : Dict String ElementId
    , spotLocations : Dict String SpotLocation
    , stations : List Station
    , turnoutNodes : List String
    }


{-| Build a TrackContext from a loaded scenario and its layout result.
-}
makeTrackContext : Scenario -> LayoutResult -> TrackContext
makeTrackContext scenario layoutResult =
    { layout = layoutResult.layout
    , nodeElementMap = layoutResult.nodeElementMap
    , spotLocations = layoutResult.spotLocations
    , stations = scenario.stations
    , turnoutNodes =
        scenario.track.nodes
            |> List.filterMap
                (\node ->
                    case node.nodeType of
                        Scenario.Turnout _ ->
                            Just node.id

                        _ ->
                            Nothing
                )
    }


{-| The turnout nodes with their track elements.
-}
turnoutElements : TrackContext -> List ( String, ElementId )
turnoutElements ctx =
    ctx.turnoutNodes
        |> List.filterMap
            (\nodeId ->
                Dict.get nodeId ctx.nodeElementMap
                    |> Maybe.map (Tuple.pair nodeId)
            )



-- ROUTE BUILDING


{-| Build the route a train travels when departing from the given station,
walking away from the station's portal and respecting turnout states.
Returns an empty route if the station or its portal is unknown.
-}
routeFromStation : TrackContext -> Dict String SwitchState -> String -> Route
routeFromStation ctx switchStates stationId =
    case stationPortalElement ctx stationId of
        Just portalElem ->
            buildRoute ctx switchStates portalElem 0

        Nothing ->
            emptyRoute


stationPortalElement : TrackContext -> String -> Maybe ElementId
stationPortalElement ctx stationId =
    ctx.stations
        |> List.filter (\s -> s.id == stationId)
        |> List.head
        |> Maybe.andThen (\s -> Dict.get s.portal ctx.nodeElementMap)


emptyRoute : Route
emptyRoute =
    { segments = [], totalLength = 0 }


{-| Build a route by walking the track layout graph from a starting connector.

Starting from the given element's connector, we:

1.  Follow the connection to enter the first track element
2.  Determine the exit connector for that element (based on turnout state)
3.  Build a route segment for the traversal
4.  Follow the connection from the exit connector to the next element
5.  Repeat until we reach a TrackEnd or dead end

-}
buildRoute : TrackContext -> Dict String SwitchState -> ElementId -> Int -> Route
buildRoute ctx switchStates startElementId startConnIdx =
    case Layout.findConnected startElementId startConnIdx ctx.layout of
        Nothing ->
            -- Start point has no connection, empty route
            emptyRoute

        Just ( firstElementId, entryConnIdx ) ->
            let
                elementStates =
                    elementSwitchStates ctx switchStates

                segments =
                    walkGraph firstElementId entryConnIdx elementStates ctx.layout [] 0.0 20
            in
            { segments = segments
            , totalLength = List.foldl (\s acc -> acc + s.length) 0 segments
            }


{-| Resolve turnout switch states from node ids to element ids.
-}
elementSwitchStates : TrackContext -> Dict String SwitchState -> Dict Int SwitchState
elementSwitchStates ctx switchStates =
    ctx.nodeElementMap
        |> Dict.toList
        |> List.filterMap
            (\( nodeId, ElementId n ) ->
                Dict.get nodeId switchStates
                    |> Maybe.map (Tuple.pair n)
            )
        |> Dict.fromList


{-| Walk the track graph, building route segments.

The maxSteps parameter prevents infinite loops in case of circular tracks.

-}
walkGraph :
    ElementId
    -> Int
    -> Dict Int SwitchState
    -> Layout
    -> List RouteSegment
    -> Float
    -> Int
    -> List RouteSegment
walkGraph elementId entryConnIdx elementStates layout accSegments accDistance maxSteps =
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
                            switchState =
                                case elementId of
                                    ElementId n ->
                                        Dict.get n elementStates
                                            |> Maybe.withDefault Normal

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
                                            elementStates
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



-- TURNOUT DISTANCES


{-| Find the cumulative distance where a given element begins in a route.
Returns Nothing if the element is not on the route.
-}
elementStartDistance : ElementId -> Route -> Maybe Float
elementStartDistance elementId route =
    route.segments
        |> List.filter (\s -> s.elementId == elementId)
        |> List.head
        |> Maybe.map .startDistance


{-| The cumulative distance where the first turnout on the route begins.
Returns Nothing if no turnout is on the route.
-}
turnoutStartDistance : TrackContext -> Route -> Maybe Float
turnoutStartDistance ctx route =
    turnoutElements ctx
        |> List.filterMap (\( _, elemId ) -> elementStartDistance elemId route)
        |> List.minimum



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

                -- Convert tangent direction from standard math angle to custom
                -- angle system (0° = North, CW positive).
                -- For positive sweep (CW), tangent = (-sin θ, cos θ),
                --   custom angle = atan2(-sin θ, -cos θ) = θ + pi
                -- For negative sweep (CCW), tangent = (sin θ, -cos θ),
                --   custom angle = atan2(sin θ, cos θ) = θ
                orientation =
                    if sweep >= 0 then
                        currentAngle + pi

                    else
                        currentAngle
            in
            { position = position
            , orientation = Element.normalizeAngle orientation
            }



-- SPOT POSITION MAPPING


{-| Get the route distance for a spot or node target on the given route.

Spot ids resolve through the scenario's spot locations (a point along a
track element). Node ids (portals, buffers) resolve to the start or end
of the route if the route touches that node.

Returns Nothing if the target is not reachable on this route.

-}
spotPosition : TrackContext -> String -> Route -> Maybe Float
spotPosition ctx spotId route =
    case Dict.get spotId ctx.spotLocations of
        Just location ->
            findSpotOnRoute ctx location route

        Nothing ->
            Dict.get spotId ctx.nodeElementMap
                |> Maybe.andThen (\nodeElem -> nodePositionOnRoute ctx nodeElem route)


{-| Route distance of a node's element (portal/buffer), if the route
starts or ends at that node's connector.
-}
nodePositionOnRoute : TrackContext -> ElementId -> Route -> Maybe Float
nodePositionOnRoute ctx nodeElem route =
    Layout.getConnector nodeElem 0 ctx.layout
        |> Maybe.andThen
            (\conn ->
                let
                    isAt dist =
                        positionOnRoute dist route
                            |> Maybe.map (\p -> Vec2.distance p.position conn.position < 1.0)
                            |> Maybe.withDefault False
                in
                if isAt 0.0 then
                    Just 0.0

                else if isAt route.totalLength then
                    Just route.totalLength

                else
                    Nothing
            )


{-| The station whose portal sits at the end of this route, if any.
-}
routeEndStation : TrackContext -> Route -> Maybe String
routeEndStation ctx route =
    ctx.stations
        |> List.filter
            (\station ->
                case Dict.get station.portal ctx.nodeElementMap of
                    Just portalElem ->
                        nodePositionOnRoute ctx portalElem route == Just route.totalLength

                    Nothing ->
                        False
            )
        |> List.head
        |> Maybe.map .id


findSpotOnRoute : TrackContext -> SpotLocation -> Route -> Maybe Float
findSpotOnRoute ctx location route =
    findSpotOnRouteHelper ctx location route.segments


findSpotOnRouteHelper : TrackContext -> SpotLocation -> List RouteSegment -> Maybe Float
findSpotOnRouteHelper ctx location segments =
    case segments of
        [] ->
            Nothing

        segment :: rest ->
            if segment.elementId == location.elementId then
                let
                    isReversed =
                        isSegmentReversed ctx segment

                    adjustedLocal =
                        if isReversed then
                            location.elementLength - location.localDistance

                        else
                            location.localDistance
                in
                Just (segment.startDistance + adjustedLocal)

            else
                findSpotOnRouteHelper ctx location rest


isSegmentReversed : TrackContext -> RouteSegment -> Bool
isSegmentReversed ctx segment =
    let
        segmentStart =
            geometryStartPosition segment.geometry

        maybeConn0 =
            Layout.getConnector segment.elementId 0 ctx.layout
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
