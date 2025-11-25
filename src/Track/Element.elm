module Track.Element exposing
    ( Connector
    , ConnectorIndex
    , ElementId(..)
    , Hand(..)
    , PlacedElement
    , TrackElementType(..)
    , computeConnectors
    , connectorCount
    , flipOrientation
    , normalizeAngle
    , routes
    )

{-| Track element types and geometry computation.

Coordinates use math convention:
- 0° = East, angles increase counter-clockwise
- Y increases northward (flipped for SVG rendering)

-}

import Array exposing (Array)
import Util.Vec2 as Vec2 exposing (Vec2, vec2)


{-| A connector represents a track end point with position and orientation.
Orientation is the direction a train would travel OUTWARD from this connector.
-}
type alias Connector =
    { position : Vec2
    , orientation : Float -- radians, math convention
    }


{-| Index into a track element's connector array.
-}
type alias ConnectorIndex =
    Int


{-| Unique identifier for elements in a layout.
-}
type ElementId
    = ElementId Int


{-| Which way a turnout diverges.
-}
type Hand
    = LeftHand -- diverges counter-clockwise (left when facing forward)
    | RightHand -- diverges clockwise (right when facing forward)


{-| Track element types with their defining parameters.
-}
type TrackElementType
    = StraightTrack Float -- length in meters
    | CurvedTrack
        { radius : Float -- meters
        , sweep : Float -- radians, positive = left/CCW
        }
    | Turnout
        { throughLength : Float -- length of straight through route
        , radius : Float -- radius of diverging curve
        , sweep : Float -- sweep angle of diverging curve (always positive)
        , hand : Hand -- which way diverging route curves
        }
    | TrackEnd -- buffer stop, tunnel portal (single connector, no routes)


{-| A placed element with computed connectors.
-}
type alias PlacedElement =
    { id : ElementId
    , elementType : TrackElementType
    , connectors : Array Connector
    }



-- GEOMETRY


{-| Normalize an angle to the range [-pi, pi].
-}
normalizeAngle : Float -> Float
normalizeAngle angle =
    let
        twoPi =
            2 * pi

        -- Shift to [0, 2pi) first
        shifted =
            angle - twoPi * toFloat (floor (angle / twoPi))
    in
    if shifted > pi then
        shifted - twoPi

    else
        shifted


{-| Flip an orientation by 180° (add pi).
Connected connectors face opposite directions.
-}
flipOrientation : Float -> Float
flipOrientation orientation =
    normalizeAngle (orientation + pi)


{-| Compute all connectors for an element given connector 0's position/orientation.
-}
computeConnectors : Connector -> TrackElementType -> Array Connector
computeConnectors connector0 elementType =
    case elementType of
        StraightTrack length ->
            computeStraightConnectors connector0 length

        CurvedTrack { radius, sweep } ->
            computeCurvedConnectors connector0 radius sweep

        Turnout spec ->
            computeTurnoutConnectors connector0 spec

        TrackEnd ->
            Array.fromList [ connector0 ]


{-| Compute connectors for a straight track.
Connector 0: entry (given)
Connector 1: exit (position + length along travel direction)

Note: connector orientation points OUTWARD (direction a train exits from that connector).
The track extends in the TRAVEL direction (opposite of connector 0's orientation).
Connector 1's orientation = travel direction (a train exiting continues forward).
-}
computeStraightConnectors : Connector -> Float -> Array Connector
computeStraightConnectors connector0 length =
    let
        -- Travel direction is opposite of connector 0's exit direction
        travelOrientation =
            flipOrientation connector0.orientation

        travelDirection =
            Vec2.fromAngle travelOrientation

        exitPosition =
            Vec2.add connector0.position (Vec2.scale length travelDirection)

        connector1 =
            { position = exitPosition
            , orientation = travelOrientation
            }
    in
    Array.fromList [ connector0, connector1 ]


{-| Compute connectors for a curved track.
Connector 0: entry (given)
Connector 1: exit (rotated around arc center, orientation flipped)
-}
computeCurvedConnectors : Connector -> Float -> Float -> Array Connector
computeCurvedConnectors connector0 radius sweep =
    let
        connector1 =
            computeCurveExit connector0 radius sweep
    in
    Array.fromList [ connector0, connector1 ]


{-| Compute the exit connector for a curve.

Note: entry.orientation points OUTWARD (direction a train exits from entry connector).
The curve arcs in the TRAVEL direction (opposite of entry.orientation).
Exit orientation = entry travel direction + sweep (rotated by the curve).
-}
computeCurveExit : Connector -> Float -> Float -> Connector
computeCurveExit entry radius sweep =
    let
        -- Entry travel orientation is opposite of entry's exit direction
        entryTravelOrientation =
            flipOrientation entry.orientation

        -- Travel direction as a vector
        travelDirection =
            Vec2.fromAngle entryTravelOrientation

        -- For positive sweep (right/CW turn), center is to the right of travel direction
        -- perpendicular gives 90° CW rotation, which is the right side
        toCenter =
            if sweep >= 0 then
                Vec2.perpendicular travelDirection

            else
                Vec2.negate (Vec2.perpendicular travelDirection)

        center =
            Vec2.add entry.position (Vec2.scale radius toCenter)

        -- Rotate entry position around center by sweep angle
        entryRelative =
            Vec2.subtract entry.position center

        exitRelative =
            Vec2.rotate sweep entryRelative

        exitPosition =
            Vec2.add center exitRelative

        -- Exit orientation = entry travel direction rotated by sweep
        exitOrientation =
            normalizeAngle (entryTravelOrientation + sweep)
    in
    { position = exitPosition
    , orientation = exitOrientation
    }


{-| Compute connectors for a turnout.
Connector 0: toe/facing point (given)
Connector 1: normal heel (straight through route exit)
Connector 2: reverse heel (diverging route exit)

Note: connector0.orientation points OUTWARD. Track extends in travel direction (opposite).
-}
computeTurnoutConnectors :
    Connector
    -> { throughLength : Float, radius : Float, sweep : Float, hand : Hand }
    -> Array Connector
computeTurnoutConnectors connector0 spec =
    let
        -- Travel orientation is opposite of connector 0's exit direction
        travelOrientation =
            flipOrientation connector0.orientation

        travelDirection =
            Vec2.fromAngle travelOrientation

        -- Through route: straight along travel direction
        throughExitPosition =
            Vec2.add connector0.position (Vec2.scale spec.throughLength travelDirection)

        connector1 =
            { position = throughExitPosition
            , orientation = travelOrientation
            }

        -- Diverging route: curved
        -- Adjust sweep sign based on hand (clockwise = positive)
        actualSweep =
            case spec.hand of
                LeftHand ->
                    -spec.sweep -- left = CCW = negative

                RightHand ->
                    spec.sweep -- right = CW = positive

        connector2 =
            computeCurveExit connector0 spec.radius actualSweep
    in
    Array.fromList [ connector0, connector1, connector2 ]



-- ROUTES


{-| Get the number of connectors for an element type.
-}
connectorCount : TrackElementType -> Int
connectorCount elementType =
    case elementType of
        StraightTrack _ ->
            2

        CurvedTrack _ ->
            2

        Turnout _ ->
            3

        TrackEnd ->
            1


{-| Get the valid routes through an element.
Each route is a pair of connector indices that can be traversed.
-}
routes : TrackElementType -> List ( ConnectorIndex, ConnectorIndex )
routes elementType =
    case elementType of
        StraightTrack _ ->
            [ ( 0, 1 ) ]

        CurvedTrack _ ->
            [ ( 0, 1 ) ]

        Turnout _ ->
            [ ( 0, 1 ), ( 0, 2 ) ] -- through and diverging

        TrackEnd ->
            []
