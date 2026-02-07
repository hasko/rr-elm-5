module ZoomAndTimeTest exposing (..)

{-| Tests for zoom bounds and time multiplier logic.

Since Main.elm uses ports and can't be imported in tests, these tests
replicate the pure zoom/time logic and verify the bounds and calculations
match the expected behavior from Main.elm.

-}

import Expect
import Test exposing (..)


suite : Test
suite =
    describe "Zoom and Time Controls"
        [ zoomBoundsTests
        , zoomFactorTests
        , timeMultiplierTests
        ]



-- ZOOM TESTS


{-| Replicate the zoom factor calculation from Main.elm Zoom handler.
-}
zoomFactor : Float -> Float
zoomFactor deltaY =
    if deltaY < 0 then
        1.1

    else
        1 / 1.1


{-| Replicate the zoom clamping from Main.elm Zoom handler.
-}
applyZoom : Float -> Float -> Float
applyZoom currentZoom deltaY =
    clamp 0.5 10.0 (currentZoom * zoomFactor deltaY)


zoomBoundsTests : Test
zoomBoundsTests =
    describe "Zoom bounds (min 0.5, max 10.0)"
        [ test "zoom never goes below 0.5 when zooming out repeatedly" <|
            \_ ->
                let
                    -- Start at 0.6 and zoom out many times
                    result =
                        List.foldl
                            (\_ z -> applyZoom z 100)
                            0.6
                            (List.range 1 50)
                in
                result
                    |> Expect.atLeast 0.5
        , test "zoom never exceeds 10.0 when zooming in repeatedly" <|
            \_ ->
                let
                    -- Start at 9.0 and zoom in many times
                    result =
                        List.foldl
                            (\_ z -> applyZoom z -100)
                            9.0
                            (List.range 1 50)
                in
                result
                    |> Expect.atMost 10.0
        , test "zoom at minimum stays at 0.5" <|
            \_ ->
                applyZoom 0.5 100
                    |> Expect.within (Expect.Absolute 0.001) 0.5
        , test "zoom at maximum stays at 10.0" <|
            \_ ->
                applyZoom 10.0 -100
                    |> Expect.within (Expect.Absolute 0.001) 10.0
        , test "default zoom (2.0) is within bounds" <|
            \_ ->
                Expect.all
                    [ \z -> z |> Expect.atLeast 0.5
                    , \z -> z |> Expect.atMost 10.0
                    ]
                    2.0
        , test "zoom in increases zoom value" <|
            \_ ->
                applyZoom 2.0 -100
                    |> Expect.greaterThan 2.0
        , test "zoom out decreases zoom value" <|
            \_ ->
                applyZoom 2.0 100
                    |> Expect.lessThan 2.0
        ]


zoomFactorTests : Test
zoomFactorTests =
    describe "Zoom factor calculation"
        [ test "negative deltaY (scroll up) gives zoom-in factor > 1" <|
            \_ ->
                zoomFactor -100
                    |> Expect.greaterThan 1.0
        , test "positive deltaY (scroll down) gives zoom-out factor < 1" <|
            \_ ->
                zoomFactor 100
                    |> Expect.lessThan 1.0
        , test "zoom-in factor is 1.1" <|
            \_ ->
                zoomFactor -100
                    |> Expect.within (Expect.Absolute 0.001) 1.1
        , test "zoom-out factor is 1/1.1" <|
            \_ ->
                zoomFactor 100
                    |> Expect.within (Expect.Absolute 0.001) (1 / 1.1)
        , test "zoom in then out returns approximately to original zoom" <|
            \_ ->
                let
                    zoomed =
                        applyZoom (applyZoom 2.0 -100) 100
                in
                zoomed
                    |> Expect.within (Expect.Absolute 0.01) 2.0
        ]



-- TIME MULTIPLIER TESTS


{-| Replicate the time scaling logic from Main.elm Tick handler.
-}
scaledDeltaSeconds : Float -> Float -> Float
scaledDeltaSeconds deltaMs multiplier =
    let
        cappedDeltaMs =
            min deltaMs 100
    in
    (cappedDeltaMs / 1000) * multiplier


timeMultiplierTests : Test
timeMultiplierTests =
    describe "Time speed controls"
        [ test "time multiplier 1x: 16ms frame produces ~0.016 seconds" <|
            \_ ->
                scaledDeltaSeconds 16.67 1.0
                    |> Expect.within (Expect.Absolute 0.001) 0.01667
        , test "time multiplier 2x: 16ms frame produces ~0.033 seconds" <|
            \_ ->
                scaledDeltaSeconds 16.67 2.0
                    |> Expect.within (Expect.Absolute 0.001) 0.03334
        , test "time multiplier 4x: 16ms frame produces ~0.067 seconds" <|
            \_ ->
                scaledDeltaSeconds 16.67 4.0
                    |> Expect.within (Expect.Absolute 0.001) 0.06668
        , test "time multiplier 8x: 16ms frame produces ~0.133 seconds" <|
            \_ ->
                scaledDeltaSeconds 16.67 8.0
                    |> Expect.within (Expect.Absolute 0.001) 0.13336
        , test "delta time is capped at 100ms to prevent teleportation" <|
            \_ ->
                -- If browser returns from background tab with 5000ms delta,
                -- it should be capped at 100ms
                scaledDeltaSeconds 5000 1.0
                    |> Expect.within (Expect.Absolute 0.001) 0.1
        , test "8x speed with large delta still capped at 100ms * 8 = 0.8s" <|
            \_ ->
                scaledDeltaSeconds 5000 8.0
                    |> Expect.within (Expect.Absolute 0.001) 0.8
        , test "zero delta produces zero elapsed time" <|
            \_ ->
                scaledDeltaSeconds 0 1.0
                    |> Expect.within (Expect.Absolute 0.001) 0.0
        , test "valid multiplier values are 1, 2, 4, 8" <|
            \_ ->
                -- Just verify the expected multiplier values produce distinct results
                let
                    results =
                        List.map (\m -> scaledDeltaSeconds 16.67 m) [ 1, 2, 4, 8 ]

                    allDistinct =
                        List.length results == List.length (List.foldl (\x acc -> if List.member x acc then acc else x :: acc) [] results)
                in
                allDistinct
                    |> Expect.equal True
        ]
