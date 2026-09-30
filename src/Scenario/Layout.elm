module Scenario.Layout exposing
    ( LayoutResult
    , SpotLocation
    , SpotPosition
    , buildLayout
    )

{-| Build a Track.Layout from a scenario's node/edge graph.

The graph walker starts at the first portal node at (0, 0) with connector 0
orientation = pi/2 (track extends rightward). It traverses edges depth-first,
placing track elements using the existing Track.Element geometry engine.

-}

import Dict exposing (Dict)
import Scenario exposing (NodeType(..), Scenario, Segment(..), TrackEdge, TrackNode)
import Track.Element as Element exposing (Connector, ElementId, Hand(..), SwitchState(..), TrackElementType)
import Track.Layout as Layout exposing (Layout)
import Util.Vec2 as Vec2


type alias SpotPosition =
    { position : Vec2.Vec2
    , orientation : Float
    }


{-| Where a spot sits on the track: which element and how far along it
(measured from the element's connector 0).
-}
type alias SpotLocation =
    { elementId : ElementId
    , localDistance : Float
    , elementLength : Float
    }


type alias LayoutResult =
    { layout : Layout
    , nodeElementMap : Dict String ElementId
    , spotPositions : Dict String SpotPosition
    , spotLocations : Dict String SpotLocation
    , turnoutStates : Dict String SwitchState
    }


type alias WalkerState =
    { layout : Layout
    , nodeElementMap : Dict String ElementId
    , nodePositions : Dict String Vec2.Vec2
    , spotPositions : Dict String SpotPosition
    , spotLocations : Dict String SpotLocation
    , turnoutStates : Dict String SwitchState
    , errors : List String
    }


{-| Build a track layout from a scenario's graph.
Returns Ok with the layout result, or Err with validation errors.
-}
buildLayout : Scenario -> Result String LayoutResult
buildLayout scenario =
    let
        firstPortal =
            scenario.track.nodes
                |> List.filter (\n -> n.nodeType == Portal)
                |> List.head
    in
    case firstPortal of
        Nothing ->
            Err "No portal node found in scenario"

        Just portal ->
            let
                -- Place the first portal (TrackEnd) at (0, 0)
                -- connector 0 faces right (orientation = pi/2 = track exit direction)
                -- Track extends rightward from this portal
                anchorConnector =
                    { position = Vec2.vec2 0 0
                    , orientation = pi / 2
                    }

                ( layoutWithPortal, portalElementId ) =
                    Layout.placeElement Element.TrackEnd anchorConnector Layout.emptyLayout

                initialState =
                    { layout = layoutWithPortal
                    , nodeElementMap = Dict.singleton portal.id portalElementId
                    , nodePositions = Dict.singleton portal.id (Vec2.vec2 0 0)
                    , spotPositions = Dict.empty
                    , spotLocations = Dict.empty
                    , turnoutStates = Dict.empty
                    , errors = []
                    }

                -- The portal's connector 0 is the attachment point.
                -- Edges from the portal connect to (portalElementId, 0).
                state =
                    walkFromNode portal.id ( portalElementId, 0 ) scenario initialState
            in
            if List.isEmpty state.errors then
                Ok
                    { layout = state.layout
                    , nodeElementMap = state.nodeElementMap
                    , spotPositions = state.spotPositions
                    , spotLocations = state.spotLocations
                    , turnoutStates = state.turnoutStates
                    }

            else
                Err (String.join "; " state.errors)


{-| Walk outgoing edges from a node.
-}
walkFromNode : String -> ( ElementId, Int ) -> Scenario -> WalkerState -> WalkerState
walkFromNode nodeId attachPoint scenario state =
    case findNode nodeId scenario of
        Nothing ->
            { state | errors = state.errors ++ [ "Node not found: " ++ nodeId ] }

        Just node ->
            let
                -- Find edges FROM this node
                outgoingEdges =
                    scenario.track.edges
                        |> List.filter (\e -> e.from == nodeId)
            in
            case node.nodeType of
                Scenario.Turnout _ ->
                    -- For turnouts, edges are walked from specific connectors
                    -- through edge from connector 1, diverge from connector 2
                    case Dict.get nodeId state.nodeElementMap of
                        Just elemId ->
                            -- Walk through edges from connector 1
                            let
                                throughEdges =
                                    outgoingEdges |> List.filter (\e -> e.port_ == Just "through")

                                divergeEdges =
                                    outgoingEdges |> List.filter (\e -> e.port_ == Just "diverge")

                                stateAfterThrough =
                                    List.foldl
                                        (\edge s -> walkEdge edge ( elemId, 1 ) scenario s)
                                        state
                                        throughEdges
                            in
                            List.foldl
                                (\edge s -> walkEdge edge ( elemId, 2 ) scenario s)
                                stateAfterThrough
                                divergeEdges

                        Nothing ->
                            { state | errors = state.errors ++ [ "Turnout element not found for node: " ++ nodeId ] }

                _ ->
                    -- For portal/buffer nodes, edges connect at connector 0
                    List.foldl
                        (\edge s -> walkEdge edge attachPoint scenario s)
                        state
                        outgoingEdges


{-| Walk an edge, placing track elements for each segment and spots.
-}
walkEdge : TrackEdge -> ( ElementId, Int ) -> Scenario -> WalkerState -> WalkerState
walkEdge edge attachPoint scenario state =
    let
        -- Place track elements for each segment
        ( stateAfterSegments, currentAttach, segmentInfos ) =
            List.foldl
                (\segment ( s, attach, infos ) ->
                    let
                        elementType =
                            segmentToElement segment

                        ( newLayout, newElemId ) =
                            Layout.placeElementAt elementType attach s.layout

                        newAttach =
                            ( newElemId, 1 )

                        segLen =
                            segmentLength segment
                    in
                    ( { s | layout = newLayout }
                    , newAttach
                    , infos ++ [ { elementId = newElemId, length = segLen } ]
                    )
                )
                ( state, attachPoint, [] )
                edge.segments

        -- Compute spot positions
        stateWithSpots =
            List.foldl
                (\spot s -> placeSpot spot segmentInfos edge.segments s)
                stateAfterSegments
                edge.spots
    in
    arriveAtNode edge.to currentAttach scenario stateWithSpots


{-| Arrive at a destination node. If already visited, validate merge point.
If new, place the node's element and continue walking.
-}
arriveAtNode : String -> ( ElementId, Int ) -> Scenario -> WalkerState -> WalkerState
arriveAtNode nodeId attachPoint scenario state =
    case Dict.get nodeId state.nodePositions of
        Just existingPos ->
            -- Already visited — validate merge point
            case Layout.getConnector (Tuple.first attachPoint) (Tuple.second attachPoint) state.layout of
                Just connector ->
                    let
                        dist =
                            Vec2.distance existingPos connector.position
                    in
                    if dist <= 0.001 then
                        state

                    else
                        { state
                            | errors =
                                state.errors
                                    ++ [ "Merge point validation failed for node "
                                            ++ nodeId
                                            ++ ": position differs by "
                                            ++ String.fromFloat dist
                                            ++ " units"
                                       ]
                        }

                Nothing ->
                    { state | errors = state.errors ++ [ "Could not find connector for merge validation at node " ++ nodeId ] }

        Nothing ->
            -- New node — place its element
            case findNode nodeId scenario of
                Nothing ->
                    { state | errors = state.errors ++ [ "Node not found: " ++ nodeId ] }

                Just node ->
                    let
                        ( elementType, maybeTurnoutState ) =
                            nodeToElement node

                        ( newLayout, newElemId ) =
                            Layout.placeElementAt elementType attachPoint state.layout

                        -- Get the new element's connector 0 position for tracking
                        nodePos =
                            Layout.getConnector newElemId 0 newLayout
                                |> Maybe.map .position
                                |> Maybe.withDefault (Vec2.vec2 0 0)

                        stateWithNode =
                            { state
                                | layout = newLayout
                                , nodeElementMap = Dict.insert nodeId newElemId state.nodeElementMap
                                , nodePositions = Dict.insert nodeId nodePos state.nodePositions
                            }

                        newState =
                            case maybeTurnoutState of
                                Just "through" ->
                                    { stateWithNode | turnoutStates = Dict.insert nodeId Normal stateWithNode.turnoutStates }

                                Just "diverge" ->
                                    { stateWithNode | turnoutStates = Dict.insert nodeId Reverse stateWithNode.turnoutStates }

                                Just other ->
                                    { stateWithNode
                                        | errors =
                                            stateWithNode.errors
                                                ++ [ "Unknown initialState \"" ++ other ++ "\" for turnout " ++ nodeId ]
                                    }

                                Nothing ->
                                    stateWithNode
                    in
                    -- Continue walking from this node
                    walkFromNode nodeId ( newElemId, 0 ) scenario newState


{-| Convert a scenario node to a track element type.
Returns the element type and optionally the initial turnout state.
-}
nodeToElement : TrackNode -> ( TrackElementType, Maybe String )
nodeToElement node =
    case node.nodeType of
        Portal ->
            ( Element.TrackEnd, Nothing )

        Buffer ->
            ( Element.TrackEnd, Nothing )

        Scenario.Turnout props ->
            let
                hand =
                    if props.hand == "left" then
                        LeftHand

                    else
                        RightHand

                sweepRadians =
                    props.sweep * pi / 180
            in
            ( Element.Turnout
                { throughLength = props.throughLength
                , radius = props.radius
                , sweep = sweepRadians
                , hand = hand
                }
            , Just props.initialState
            )


{-| Convert a scenario segment to a track element type.
-}
segmentToElement : Segment -> TrackElementType
segmentToElement segment =
    case segment of
        StraightSegment len ->
            Element.StraightTrack len

        CurveSegment { radius, sweep } ->
            Element.CurvedTrack { radius = radius, sweep = sweep * pi / 180 }


{-| Compute the length of a segment (arc length for curves).
-}
segmentLength : Segment -> Float
segmentLength segment =
    case segment of
        StraightSegment len ->
            len

        CurveSegment { radius, sweep } ->
            radius * abs (sweep * pi / 180)


{-| Place a spot at its distance along the edge's segments.
-}
placeSpot :
    Scenario.Spot
    -> List { elementId : ElementId, length : Float }
    -> List Segment
    -> WalkerState
    -> WalkerState
placeSpot spot segmentInfos segments state =
    let
        -- Find which segment the spot falls in
        result =
            findSegmentForDistance spot.at segmentInfos
    in
    case result of
        Nothing ->
            { state | errors = state.errors ++ [ "Spot " ++ spot.id ++ " at distance " ++ String.fromFloat spot.at ++ " is beyond edge length" ] }

        Just ( elemId, localDistance, segIdx ) ->
            -- Get the element to compute position
            case Layout.getConnector elemId 0 state.layout of
                Just connector0 ->
                    let
                        segmentAtIdx =
                            List.drop segIdx segments |> List.head

                        spotPos =
                            case segmentAtIdx of
                                Just (StraightSegment _) ->
                                    -- Linear interpolation along straight
                                    let
                                        travelDir =
                                            Vec2.fromAngle (Element.flipOrientation connector0.orientation)

                                        pos =
                                            Vec2.add connector0.position (Vec2.scale localDistance travelDir)

                                        orient =
                                            Element.flipOrientation connector0.orientation
                                    in
                                    Just { position = pos, orientation = orient }

                                Just (CurveSegment { radius, sweep }) ->
                                    -- Partial arc along curve
                                    let
                                        sweepRadians =
                                            sweep * pi / 180

                                        arcLength =
                                            radius * abs sweepRadians

                                        fraction =
                                            if arcLength > 0 then
                                                localDistance / arcLength

                                            else
                                                0

                                        partialSweep =
                                            sweepRadians * fraction

                                        partialConnector =
                                            computePartialCurve connector0 radius partialSweep
                                    in
                                    Just { position = partialConnector.position, orientation = partialConnector.orientation }

                                Nothing ->
                                    Nothing
                    in
                    case spotPos of
                        Just sp ->
                            let
                                elementLength =
                                    List.drop segIdx segmentInfos
                                        |> List.head
                                        |> Maybe.map .length
                                        |> Maybe.withDefault 0
                            in
                            { state
                                | spotPositions = Dict.insert spot.id sp state.spotPositions
                                , spotLocations =
                                    Dict.insert spot.id
                                        { elementId = elemId
                                        , localDistance = localDistance
                                        , elementLength = elementLength
                                        }
                                        state.spotLocations
                            }

                        Nothing ->
                            { state | errors = state.errors ++ [ "Could not compute position for spot " ++ spot.id ] }

                Nothing ->
                    { state | errors = state.errors ++ [ "Could not find connector for spot " ++ spot.id ] }


{-| Find which segment a distance falls in.
Returns (elementId, localDistanceWithinSegment, segmentIndex).
-}
findSegmentForDistance :
    Float
    -> List { elementId : ElementId, length : Float }
    -> Maybe ( ElementId, Float, Int )
findSegmentForDistance targetDist infos =
    findSegmentHelper targetDist 0 0 infos


findSegmentHelper :
    Float
    -> Float
    -> Int
    -> List { elementId : ElementId, length : Float }
    -> Maybe ( ElementId, Float, Int )
findSegmentHelper targetDist cumulative idx infos =
    case infos of
        [] ->
            Nothing

        info :: rest ->
            let
                endOfSegment =
                    cumulative + info.length
            in
            if targetDist <= endOfSegment then
                Just ( info.elementId, targetDist - cumulative, idx )

            else
                findSegmentHelper targetDist endOfSegment (idx + 1) rest


{-| Compute a partial curve exit (for spot positioning within a curve).
-}
computePartialCurve : Connector -> Float -> Float -> Connector
computePartialCurve entry radius sweep =
    let
        entryTravelOrientation =
            Element.flipOrientation entry.orientation

        travelDirection =
            Vec2.fromAngle entryTravelOrientation

        toCenter =
            if sweep >= 0 then
                Vec2.perpendicular travelDirection

            else
                Vec2.negate (Vec2.perpendicular travelDirection)

        center =
            Vec2.add entry.position (Vec2.scale radius toCenter)

        entryRelative =
            Vec2.subtract entry.position center

        exitRelative =
            Vec2.rotate sweep entryRelative

        exitPosition =
            Vec2.add center exitRelative

        exitOrientation =
            Element.normalizeAngle (entryTravelOrientation + sweep)
    in
    { position = exitPosition
    , orientation = exitOrientation
    }


{-| Find a node by ID in the scenario.
-}
findNode : String -> Scenario -> Maybe TrackNode
findNode nodeId scenario =
    scenario.track.nodes
        |> List.filter (\n -> n.id == nodeId)
        |> List.head
