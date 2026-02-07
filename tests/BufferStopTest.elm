module BufferStopTest exposing (..)

import Array
import Expect
import Sawmill.Layout exposing (SwitchState(..), trackLayout)
import Test exposing (..)
import Track.Element as Element
    exposing
        ( Connector
        , ElementId(..)
        , TrackElementType(..)
        , computeConnectors
        )
import Track.Layout as Layout
import Util.Vec2 as Vec2 exposing (vec2)


suite : Test
suite =
    describe "Buffer Stop"
        [ bufferStopOrientationTests
        , bufferStopLayoutTests
        , arcOrientationExtendedTests
        ]


bufferStopOrientationTests : Test
bufferStopOrientationTests =
    describe "Buffer stop orientation is perpendicular to track"
        [ test "buffer stop at siding end has correct orientation relative to siding direction" <|
            \_ ->
                -- Element 6 is the buffer stop at end of siding
                -- Element 5 is the siding straight track
                -- The buffer stop connector should face opposite the siding travel direction
                let
                    -- Get siding connector 1 (exit end, where buffer connects)
                    sidingExit =
                        Layout.getConnector (ElementId 5) 1 trackLayout

                    -- Get buffer stop connector 0
                    bufferConnector =
                        Layout.getConnector (ElementId 6) 0 trackLayout
                in
                case ( sidingExit, bufferConnector ) of
                    ( Just siding, Just buffer ) ->
                        -- Buffer stop connector should be at the same position as siding exit
                        let
                            posError =
                                Vec2.length (Vec2.subtract siding.position buffer.position)
                        in
                        posError
                            |> Expect.atMost 0.01

                    _ ->
                        Expect.fail "Expected both siding exit and buffer stop connectors to exist"
        , test "buffer stop connector orientation is opposite of siding exit orientation" <|
            \_ ->
                -- When tracks connect, connectors face each other (opposite orientations)
                -- So their orientations differ by pi (180 degrees)
                let
                    sidingExit =
                        Layout.getConnector (ElementId 5) 1 trackLayout

                    bufferConnector =
                        Layout.getConnector (ElementId 6) 0 trackLayout
                in
                case ( sidingExit, bufferConnector ) of
                    ( Just siding, Just buffer ) ->
                        let
                            diff =
                                Element.normalizeAngle (siding.orientation - buffer.orientation)

                            -- Difference should be approximately pi (connected connectors face opposite)
                            absDiff =
                                abs diff
                        in
                        absDiff
                            |> Expect.within (Expect.Absolute 0.01) pi

                    _ ->
                        Expect.fail "Expected both connectors to exist"
        , test "TrackEnd element has exactly one connector" <|
            \_ ->
                let
                    connector0 =
                        { position = vec2 100 100, orientation = 0 }

                    connectors =
                        computeConnectors connector0 TrackEnd
                in
                Array.length connectors
                    |> Expect.equal 1
        , test "TrackEnd preserves the given connector exactly" <|
            \_ ->
                let
                    connector0 =
                        { position = vec2 42 17, orientation = 1.234 }

                    connectors =
                        computeConnectors connector0 TrackEnd
                in
                case Array.get 0 connectors of
                    Just c ->
                        Expect.all
                            [ \conn -> conn.position.x |> Expect.within (Expect.Absolute 0.001) 42
                            , \conn -> conn.position.y |> Expect.within (Expect.Absolute 0.001) 17
                            , \conn -> conn.orientation |> Expect.within (Expect.Absolute 0.001) 1.234
                            ]
                            c

                    Nothing ->
                        Expect.fail "Expected connector 0 to exist"
        ]


bufferStopLayoutTests : Test
bufferStopLayoutTests =
    describe "Buffer stop layout placement"
        [ test "element 6 (buffer stop) exists in layout" <|
            \_ ->
                case Layout.getConnector (ElementId 6) 0 trackLayout of
                    Just _ ->
                        Expect.pass

                    Nothing ->
                        Expect.fail "Expected buffer stop element 6 to exist"
        , test "element 7 (west tunnel portal) exists in layout" <|
            \_ ->
                case Layout.getConnector (ElementId 7) 0 trackLayout of
                    Just _ ->
                        Expect.pass

                    Nothing ->
                        Expect.fail "Expected west tunnel portal element 7 to exist"
        , test "buffer stop is south of mainline (positive Y in math coords)" <|
            \_ ->
                -- The siding goes southeast from the turnout, so buffer should have positive Y
                case Layout.getConnector (ElementId 6) 0 trackLayout of
                    Just c ->
                        c.position.y
                            |> Expect.greaterThan 0

                    Nothing ->
                        Expect.fail "Expected buffer stop connector to exist"
        , test "siding direction is approximately 45 degrees from mainline" <|
            \_ ->
                -- The continuation curve adds 30 degrees to the turnout's 15 degrees
                -- so total siding angle = 45 degrees from the mainline
                let
                    sidingStart =
                        Layout.getConnector (ElementId 4) 1 trackLayout

                    sidingEnd =
                        Layout.getConnector (ElementId 5) 1 trackLayout
                in
                case ( sidingStart, sidingEnd ) of
                    ( Just start, Just end ) ->
                        let
                            dx =
                                end.position.x - start.position.x

                            dy =
                                end.position.y - start.position.y

                            -- Angle from horizontal (atan2(dy, dx))
                            angle =
                                atan2 dy dx

                            -- Should be approximately 45 degrees = pi/4
                            expectedAngle =
                                pi / 4
                        in
                        angle
                            |> Expect.within (Expect.Absolute 0.05) expectedAngle

                    _ ->
                        Expect.fail "Expected siding connectors to exist"
        ]


arcOrientationExtendedTests : Test
arcOrientationExtendedTests =
    describe "Extended arc orientation tests"
        [ test "continuation curve (element 4) has two connectors" <|
            \_ ->
                let
                    c0 =
                        Layout.getConnector (ElementId 4) 0 trackLayout

                    c1 =
                        Layout.getConnector (ElementId 4) 1 trackLayout
                in
                case ( c0, c1 ) of
                    ( Just _, Just _ ) ->
                        Expect.pass

                    _ ->
                        Expect.fail "Expected continuation curve to have 2 connectors"
        , test "continuation curve exit orientation differs from entry by sweep angle" <|
            \_ ->
                -- Element 4 is CurvedTrack with 30 degree sweep
                let
                    c0 =
                        Layout.getConnector (ElementId 4) 0 trackLayout

                    c1 =
                        Layout.getConnector (ElementId 4) 1 trackLayout
                in
                case ( c0, c1 ) of
                    ( Just entry, Just exit ) ->
                        let
                            -- Entry travel direction = flip of entry orientation
                            entryTravel =
                                Element.flipOrientation entry.orientation

                            -- Exit orientation should be entry travel + sweep (30 deg)
                            orientationDiff =
                                Element.normalizeAngle (exit.orientation - entryTravel)

                            -- Continuation sweep is 30 degrees
                            expectedSweep =
                                30 * pi / 180
                        in
                        abs orientationDiff
                            |> Expect.within (Expect.Absolute 0.05) expectedSweep

                    _ ->
                        Expect.fail "Expected continuation curve connectors to exist"
        , test "turnout diverge connector orientation accounts for 15-degree sweep" <|
            \_ ->
                -- Element 2 is the turnout with 15 degree diverge
                let
                    c0 =
                        Layout.getConnector (ElementId 2) 0 trackLayout

                    c2 =
                        Layout.getConnector (ElementId 2) 2 trackLayout
                in
                case ( c0, c2 ) of
                    ( Just toe, Just diverge ) ->
                        let
                            -- Toe travel direction
                            toeTravel =
                                Element.flipOrientation toe.orientation

                            -- Diverge exit orientation should differ from toe travel
                            -- by approximately 15 degrees (RightHand = positive sweep)
                            orientationDiff =
                                Element.normalizeAngle (diverge.orientation - toeTravel)

                            expectedSweep =
                                15 * pi / 180
                        in
                        abs orientationDiff
                            |> Expect.within (Expect.Absolute 0.05) expectedSweep

                    _ ->
                        Expect.fail "Expected turnout connectors to exist"
        , test "through route connector (element 2, connector 1) is parallel to mainline" <|
            \_ ->
                -- The through route should keep the same orientation as the mainline
                let
                    c0 =
                        Layout.getConnector (ElementId 2) 0 trackLayout

                    c1 =
                        Layout.getConnector (ElementId 2) 1 trackLayout
                in
                case ( c0, c1 ) of
                    ( Just toe, Just through ) ->
                        let
                            -- Through route exit should be same orientation as entry travel
                            toeTravel =
                                Element.flipOrientation toe.orientation

                            diff =
                                Element.normalizeAngle (through.orientation - toeTravel)
                        in
                        abs diff
                            |> Expect.atMost 0.01

                    _ ->
                        Expect.fail "Expected turnout connectors to exist"
        ]
