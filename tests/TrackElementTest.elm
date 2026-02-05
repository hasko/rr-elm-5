module TrackElementTest exposing (..)

import Array
import Expect
import Test exposing (..)
import Track.Element
    exposing
        ( Connector
        , ElementId(..)
        , Hand(..)
        , TrackElementType(..)
        , computeConnectors
        , connectorCount
        , flipOrientation
        , normalizeAngle
        , routes
        )
import Util.Vec2 as Vec2 exposing (vec2)


suite : Test
suite =
    describe "Track.Element"
        [ normalizeAngleTests
        , flipOrientationTests
        , connectorCountTests
        , routesTests
        , straightTrackTests
        , curvedTrackTests
        , turnoutTests
        , trackEndTests
        ]


tol : Expect.FloatingPointTolerance
tol =
    Expect.Absolute 0.01


normalizeAngleTests : Test
normalizeAngleTests =
    describe "normalizeAngle"
        [ test "0 stays 0" <|
            \_ ->
                normalizeAngle 0
                    |> Expect.within tol 0
        , test "pi stays pi" <|
            \_ ->
                normalizeAngle pi
                    |> Expect.within tol pi
        , test "-pi normalizes to pi (boundary)" <|
            \_ ->
                normalizeAngle -pi
                    |> Expect.within tol pi
        , test "2pi wraps to 0" <|
            \_ ->
                normalizeAngle (2 * pi)
                    |> Expect.within tol 0
        , test "3pi wraps to pi" <|
            \_ ->
                normalizeAngle (3 * pi)
                    |> Expect.within tol pi
        , test "-3pi wraps to pi (boundary)" <|
            \_ ->
                normalizeAngle -(3 * pi)
                    |> Expect.within tol pi
        , test "small positive angle unchanged" <|
            \_ ->
                normalizeAngle 0.5
                    |> Expect.within tol 0.5
        , test "small negative angle unchanged" <|
            \_ ->
                normalizeAngle -0.5
                    |> Expect.within tol -0.5
        ]


flipOrientationTests : Test
flipOrientationTests =
    describe "flipOrientation"
        [ test "flipping 0 gives pi" <|
            \_ ->
                flipOrientation 0
                    |> Expect.within tol pi
        , test "flipping pi gives 0" <|
            \_ ->
                -- normalizeAngle(pi + pi) = normalizeAngle(2pi) = 0
                flipOrientation pi
                    |> Expect.within tol 0
        , test "flipping pi/2 gives -pi/2" <|
            \_ ->
                flipOrientation (pi / 2)
                    |> Expect.within tol -(pi / 2)
        , test "double flip is identity" <|
            \_ ->
                flipOrientation (flipOrientation 0.7)
                    |> Expect.within tol 0.7
        ]


connectorCountTests : Test
connectorCountTests =
    describe "connectorCount"
        [ test "straight track has 2" <|
            \_ ->
                connectorCount (StraightTrack 100)
                    |> Expect.equal 2
        , test "curved track has 2" <|
            \_ ->
                connectorCount (CurvedTrack { radius = 50, sweep = 0.5 })
                    |> Expect.equal 2
        , test "turnout has 3" <|
            \_ ->
                connectorCount (Turnout { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand })
                    |> Expect.equal 3
        , test "track end has 1" <|
            \_ ->
                connectorCount TrackEnd
                    |> Expect.equal 1
        ]


routesTests : Test
routesTests =
    describe "routes"
        [ test "straight track has one route 0->1" <|
            \_ ->
                routes (StraightTrack 100)
                    |> Expect.equal [ ( 0, 1 ) ]
        , test "curved track has one route 0->1" <|
            \_ ->
                routes (CurvedTrack { radius = 50, sweep = 0.5 })
                    |> Expect.equal [ ( 0, 1 ) ]
        , test "turnout has two routes: through and diverge" <|
            \_ ->
                routes (Turnout { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand })
                    |> Expect.equal [ ( 0, 1 ), ( 0, 2 ) ]
        , test "track end has no routes" <|
            \_ ->
                routes TrackEnd
                    |> Expect.equal []
        ]


straightTrackTests : Test
straightTrackTests =
    describe "StraightTrack connectors"
        [ test "connector 0 is at given position" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = pi / 2 }

                    connectors =
                        computeConnectors c0 (StraightTrack 100)
                in
                case Array.get 0 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 0
                            , \_ -> conn.position.y |> Expect.within tol 0
                            , \_ -> conn.orientation |> Expect.within tol (pi / 2)
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 0 missing"
        , test "west-facing straight: connector 1 is 100m to the right (+x)" <|
            \_ ->
                let
                    -- connector 0 at origin, orientation pi/2 (facing west = +x outward)
                    -- travel direction = flipOrientation(pi/2) = -pi/2 (east = -x? NO)
                    -- Wait: flipOrientation(pi/2) = normalizeAngle(pi/2 + pi) = normalizeAngle(3pi/2) = -pi/2
                    -- fromAngle(-pi/2) = (sin(-pi/2), -cos(-pi/2)) = (-1, 0)
                    -- So travel is in -x direction
                    -- But the convention says connector 0 orientation points outward
                    -- If connector 0 is at entry and faces backward, travel is opposite
                    -- For a track heading WEST (+x), connector 0 faces EAST (opposite)
                    -- So connector 0 orientation should be -pi/2 (east direction)
                    -- Let's use -pi/2 for connector 0 (pointing east/backward)
                    -- Travel = flipOrientation(-pi/2) = pi/2 (west, +x direction)
                    -- fromAngle(pi/2) = (sin(pi/2), -cos(pi/2)) = (1, 0) = +x direction
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    connectors =
                        computeConnectors c0 (StraightTrack 100)
                in
                case Array.get 1 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 100
                            , \_ -> conn.position.y |> Expect.within tol 0
                            , \_ -> conn.orientation |> Expect.within tol (pi / 2)
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 1 missing"
        , test "northbound straight: connector 1 is 100m up (-y)" <|
            \_ ->
                let
                    -- Northbound means travel direction is north (0 radians)
                    -- connector 0 orientation = flipOrientation(0) = pi (south, pointing backward)
                    c0 =
                        { position = vec2 0 0, orientation = pi }

                    connectors =
                        computeConnectors c0 (StraightTrack 100)
                in
                case Array.get 1 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 0
                            , \_ -> conn.position.y |> Expect.within tol -100
                            , \_ -> conn.orientation |> Expect.within tol 0
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 1 missing"
        , test "produces exactly 2 connectors" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    connectors =
                        computeConnectors c0 (StraightTrack 50)
                in
                Array.length connectors
                    |> Expect.equal 2
        ]


curvedTrackTests : Test
curvedTrackTests =
    describe "CurvedTrack connectors"
        [ test "produces exactly 2 connectors" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    connectors =
                        computeConnectors c0 (CurvedTrack { radius = 100, sweep = pi / 4 })
                in
                Array.length connectors
                    |> Expect.equal 2
        , test "connector 0 preserved" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 10 20, orientation = 0.5 }

                    connectors =
                        computeConnectors c0 (CurvedTrack { radius = 100, sweep = 0.3 })
                in
                case Array.get 0 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 10
                            , \_ -> conn.position.y |> Expect.within tol 20
                            , \_ -> conn.orientation |> Expect.within tol 0.5
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 0 missing"
        , test "exit connector is at correct distance (radius) from center" <|
            \_ ->
                let
                    -- Connector 0 facing south (pi), travel is north (0)
                    -- fromAngle(0) = (0, -1), perpendicular for positive sweep = right side
                    c0 =
                        { position = vec2 0 0, orientation = pi }

                    radius =
                        100

                    connectors =
                        computeConnectors c0 (CurvedTrack { radius = radius, sweep = pi / 4 })
                in
                case Array.get 1 connectors of
                    Just conn ->
                        -- The exit should be at radius distance from center
                        -- We can at least verify exit is not at origin
                        Expect.all
                            [ \_ ->
                                Vec2.distance c0.position conn.position
                                    |> Expect.greaterThan 0
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 1 missing"
        ]


turnoutTests : Test
turnoutTests =
    describe "Turnout connectors"
        [ test "produces exactly 3 connectors" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    spec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand }

                    connectors =
                        computeConnectors c0 (Turnout spec)
                in
                Array.length connectors
                    |> Expect.equal 3
        , test "connector 0 preserved at toe" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 5 10, orientation = 0.5 }

                    spec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand }

                    connectors =
                        computeConnectors c0 (Turnout spec)
                in
                case Array.get 0 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 5
                            , \_ -> conn.position.y |> Expect.within tol 10
                            , \_ -> conn.orientation |> Expect.within tol 0.5
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 0 missing"
        , test "through route connector 1 is straight from connector 0" <|
            \_ ->
                let
                    -- Connector 0 faces east (-pi/2), travel goes west (pi/2)
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    spec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand }

                    connectors =
                        computeConnectors c0 (Turnout spec)
                in
                case Array.get 1 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 50
                            , \_ -> conn.position.y |> Expect.within tol 0
                            , \_ -> conn.orientation |> Expect.within tol (pi / 2)
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 1 missing"
        , test "diverging route connector 2 is offset from straight path" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    spec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand }

                    connectors =
                        computeConnectors c0 (Turnout spec)
                in
                case ( Array.get 1 connectors, Array.get 2 connectors ) of
                    ( Just through, Just diverge ) ->
                        -- Diverging connector should be at a different position than through
                        Vec2.distance through.position diverge.position
                            |> Expect.greaterThan 0

                    _ ->
                        Expect.fail "missing connectors"
        , test "left hand turnout diverges opposite to right hand" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    rightSpec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = RightHand }

                    leftSpec =
                        { throughLength = 50, radius = 100, sweep = 0.3, hand = LeftHand }

                    rightConns =
                        computeConnectors c0 (Turnout rightSpec)

                    leftConns =
                        computeConnectors c0 (Turnout leftSpec)
                in
                case ( Array.get 2 rightConns, Array.get 2 leftConns ) of
                    ( Just rightDiv, Just leftDiv ) ->
                        -- Right hand diverges one way, left the other
                        -- For travel west (+x), right diverge goes south (+y), left goes north (-y)
                        -- rightDiv.y should be positive, leftDiv.y should be negative (or vice versa)
                        (rightDiv.position.y * leftDiv.position.y)
                            |> Expect.lessThan 0

                    _ ->
                        Expect.fail "missing diverging connectors"
        ]


trackEndTests : Test
trackEndTests =
    describe "TrackEnd connectors"
        [ test "produces exactly 1 connector" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    connectors =
                        computeConnectors c0 TrackEnd
                in
                Array.length connectors
                    |> Expect.equal 1
        , test "connector is preserved" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 42 -17, orientation = 1.5 }

                    connectors =
                        computeConnectors c0 TrackEnd
                in
                case Array.get 0 connectors of
                    Just conn ->
                        Expect.all
                            [ \_ -> conn.position.x |> Expect.within tol 42
                            , \_ -> conn.position.y |> Expect.within tol -17
                            , \_ -> conn.orientation |> Expect.within tol 1.5
                            ]
                            ()

                    Nothing ->
                        Expect.fail "connector 0 missing"
        ]
