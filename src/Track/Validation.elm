module Track.Validation exposing
    ( ValidationError(..)
    , ValidationResult
    , orientationTolerance
    , positionTolerance
    , validateConnection
    , validateLayout
    )

{-| Track layout continuity validation.

Validates that connected connectors match within tolerance:
- Position: 1 cm
- Orientation: 1 degree (connected ends face opposite directions)

-}

import Track.Element as Element exposing (Connector, ConnectorIndex, ElementId)
import Track.Layout as Layout exposing (Connection, Layout)
import Util.Vec2 as Vec2


{-| Position tolerance in meters (1 cm).
-}
positionTolerance : Float
positionTolerance =
    0.01


{-| Orientation tolerance in radians (1 degree).
-}
orientationTolerance : Float
orientationTolerance =
    pi / 180


{-| Validation errors.
-}
type ValidationError
    = PositionMismatch
        { connection : Connection
        , distance : Float -- actual distance in meters
        }
    | OrientationMismatch
        { connection : Connection
        , angleDiff : Float -- actual difference in radians
        }
    | DanglingConnection
        { connection : Connection
        , missing : ( ElementId, ConnectorIndex )
        }


{-| Result of validating a layout.
-}
type alias ValidationResult =
    { valid : Bool
    , errors : List ValidationError
    }


{-| Validate all connections in a layout.
-}
validateLayout : Layout -> ValidationResult
validateLayout layout =
    let
        errors =
            layout.connections
                |> List.filterMap (validateConnection layout)
    in
    { valid = List.isEmpty errors
    , errors = errors
    }


{-| Validate a single connection. Returns Just error if invalid.
-}
validateConnection : Layout -> Connection -> Maybe ValidationError
validateConnection layout connection =
    let
        maybeFromConnector =
            Layout.getConnector (Tuple.first connection.from) (Tuple.second connection.from) layout

        maybeToConnector =
            Layout.getConnector (Tuple.first connection.to) (Tuple.second connection.to) layout
    in
    case ( maybeFromConnector, maybeToConnector ) of
        ( Just fromConnector, Just toConnector ) ->
            validateConnectorPair connection fromConnector toConnector

        ( Nothing, _ ) ->
            Just (DanglingConnection { connection = connection, missing = connection.from })

        ( _, Nothing ) ->
            Just (DanglingConnection { connection = connection, missing = connection.to })


{-| Validate that two connectors match within tolerance.
Connected connectors should:
1. Have the same position (within tolerance)
2. Face opposite directions (orientations differ by pi radians, within tolerance)
-}
validateConnectorPair : Connection -> Connector -> Connector -> Maybe ValidationError
validateConnectorPair connection fromConnector toConnector =
    let
        -- Check position
        distance =
            Vec2.distance fromConnector.position toConnector.position

        positionOk =
            distance <= positionTolerance

        -- Check orientation
        -- Connected ends should face opposite directions
        -- (orientation points outward, so they should differ by ~pi)
        orientationDiff =
            abs (Element.normalizeAngle (fromConnector.orientation - toConnector.orientation))

        -- The difference should be close to pi (180 degrees)
        angleDiffFromPi =
            abs (orientationDiff - pi)

        orientationOk =
            angleDiffFromPi <= orientationTolerance
    in
    if not positionOk then
        Just (PositionMismatch { connection = connection, distance = distance })

    else if not orientationOk then
        Just (OrientationMismatch { connection = connection, angleDiff = angleDiffFromPi })

    else
        Nothing
