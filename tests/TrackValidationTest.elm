module TrackValidationTest exposing (..)

import Expect
import Test exposing (..)
import Track.Element as Element exposing (ElementId(..), TrackElementType(..))
import Track.Layout as Layout exposing (Layout)
import Track.Validation
    exposing
        ( ValidationError(..)
        , orientationTolerance
        , positionTolerance
        , validateConnection
        , validateLayout
        )
import Sawmill.Layout
import Util.Vec2 exposing (vec2)


suite : Test
suite =
    describe "Track.Validation"
        [ toleranceTests
        , validConnectionTests
        , invalidConnectionTests
        , layoutValidationTests
        ]


toleranceTests : Test
toleranceTests =
    describe "tolerances"
        [ test "position tolerance is 1cm" <|
            \_ ->
                positionTolerance
                    |> Expect.within (Expect.Absolute 0.001) 0.01
        , test "orientation tolerance is 1 degree" <|
            \_ ->
                orientationTolerance
                    |> Expect.within (Expect.Absolute 0.0001) (pi / 180)
        ]


{-| Build a layout with two properly connected straight tracks.
-}
validTwoStraightLayout : Layout
validTwoStraightLayout =
    let
        -- Place first element: TrackEnd at origin
        connector0 =
            { position = vec2 0 0, orientation = -(pi / 2) }

        ( layout1, _ ) =
            Layout.placeElement TrackEnd connector0 Layout.emptyLayout

        -- Place second element connected to first
        ( layout2, _ ) =
            Layout.placeElementAt (StraightTrack 100) ( ElementId 0, 0 ) layout1
    in
    layout2


validConnectionTests : Test
validConnectionTests =
    describe "valid connections"
        [ test "properly connected elements have no errors" <|
            \_ ->
                let
                    result =
                        validateLayout validTwoStraightLayout
                in
                result.valid
                    |> Expect.equal True
        , test "properly connected layout has empty error list" <|
            \_ ->
                let
                    result =
                        validateLayout validTwoStraightLayout
                in
                List.length result.errors
                    |> Expect.equal 0
        , test "sawmill layout validates correctly" <|
            \_ ->
                let
                    -- The sawmill layout is built with placeElementAt which
                    -- ensures geometric consistency
                    layout =
                        Sawmill.Layout.trackLayout

                    result =
                        validateLayout layout
                in
                result.valid
                    |> Expect.equal True
        ]


invalidConnectionTests : Test
invalidConnectionTests =
    describe "invalid connections"
        [ test "position mismatch detected" <|
            \_ ->
                let
                    -- Create two elements with mismatched positions
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout1, _ ) =
                        Layout.placeElement TrackEnd c0 Layout.emptyLayout

                    -- Place second element at a different position manually
                    c1 =
                        { position = vec2 10 10, orientation = pi / 2 }

                    ( layout2, _ ) =
                        Layout.placeElement (StraightTrack 100) c1 layout1

                    -- Manually connect them (positions don't match!)
                    layoutWithBadConnection =
                        Layout.connect ( ElementId 0, 0 ) ( ElementId 1, 0 ) layout2

                    result =
                        validateLayout layoutWithBadConnection
                in
                Expect.all
                    [ \_ -> result.valid |> Expect.equal False
                    , \_ ->
                        result.errors
                            |> List.any
                                (\err ->
                                    case err of
                                        PositionMismatch _ ->
                                            True

                                        _ ->
                                            False
                                )
                            |> Expect.equal True
                    ]
                    ()
        , test "orientation mismatch detected" <|
            \_ ->
                let
                    -- Two elements at same position but wrong orientations
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout1, _ ) =
                        Layout.placeElement TrackEnd c0 Layout.emptyLayout

                    -- Same position, but orientation is NOT opposite (should be pi for valid)
                    c1 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout2, _ ) =
                        Layout.placeElement (StraightTrack 100) c1 layout1

                    layoutWithBadOrientation =
                        Layout.connect ( ElementId 0, 0 ) ( ElementId 1, 0 ) layout2

                    result =
                        validateLayout layoutWithBadOrientation
                in
                Expect.all
                    [ \_ -> result.valid |> Expect.equal False
                    , \_ ->
                        result.errors
                            |> List.any
                                (\err ->
                                    case err of
                                        OrientationMismatch _ ->
                                            True

                                        _ ->
                                            False
                                )
                            |> Expect.equal True
                    ]
                    ()
        , test "dangling connection detected when element missing" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout1, _ ) =
                        Layout.placeElement TrackEnd c0 Layout.emptyLayout

                    -- Connect to non-existent element
                    layoutWithDangling =
                        Layout.connect ( ElementId 0, 0 ) ( ElementId 99, 0 ) layout1

                    result =
                        validateLayout layoutWithDangling
                in
                Expect.all
                    [ \_ -> result.valid |> Expect.equal False
                    , \_ ->
                        result.errors
                            |> List.any
                                (\err ->
                                    case err of
                                        DanglingConnection _ ->
                                            True

                                        _ ->
                                            False
                                )
                            |> Expect.equal True
                    ]
                    ()
        ]


layoutValidationTests : Test
layoutValidationTests =
    describe "layout validation"
        [ test "empty layout is valid" <|
            \_ ->
                let
                    result =
                        validateLayout Layout.emptyLayout
                in
                result.valid
                    |> Expect.equal True
        , test "layout with no connections is valid" <|
            \_ ->
                let
                    c0 =
                        { position = vec2 0 0, orientation = 0 }

                    ( layout, _ ) =
                        Layout.placeElement TrackEnd c0 Layout.emptyLayout

                    result =
                        validateLayout layout
                in
                result.valid
                    |> Expect.equal True
        , test "chained elements with placeElementAt validate" <|
            \_ ->
                let
                    -- Build a chain: TrackEnd -> Straight -> Straight -> TrackEnd
                    c0 =
                        { position = vec2 0 0, orientation = -(pi / 2) }

                    ( layout1, _ ) =
                        Layout.placeElement TrackEnd c0 Layout.emptyLayout

                    ( layout2, _ ) =
                        Layout.placeElementAt (StraightTrack 100) ( ElementId 0, 0 ) layout1

                    ( layout3, _ ) =
                        Layout.placeElementAt (StraightTrack 100) ( ElementId 1, 1 ) layout2

                    ( layout4, _ ) =
                        Layout.placeElementAt TrackEnd ( ElementId 2, 1 ) layout3

                    result =
                        validateLayout layout4
                in
                result.valid
                    |> Expect.equal True
        ]
