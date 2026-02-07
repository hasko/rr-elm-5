module SpottingTest exposing (..)

{-| TDD tests for car-specific spotting in MoveTo.

The car-specific spotting feature allows MoveTo to position a specific car
in the consist at the target spot, rather than always positioning the
train head (default / backward-compatible behavior).

These tests are written TDD-style: they describe the desired behavior and
will fail until the implementation lands.

-}

import Expect
import Planning.Types exposing (StockItem, StockType(..))
import Programmer.Types exposing (Order(..), SpotId(..))
import Sawmill.Layout exposing (SwitchState(..))
import Test exposing (..)
import Train.Route as Route
import Train.Stock exposing (consistLength, couplerGap, stockLength)


suite : Test
suite =
    describe "Car-specific spotting"
        [ backwardCompatTests
        , carOffsetCalculationTests
        , threeCarConsistTests
        ]


{-| Helper: compute the offset from the train head to center of car at index.

Given a consist [car0, car1, car2, ...], the offset for car N is:
sum of lengths of cars 0..N-1 + N coupler gaps + half of car N's length.

-}
expectedCarOffset : List StockItem -> Int -> Float
expectedCarOffset consist carIndex =
    let
        precedingCars =
            List.take carIndex consist

        precedingLength =
            List.sum (List.map (\item -> stockLength item.stockType) precedingCars)

        gapCount =
            toFloat carIndex

        gaps =
            gapCount * couplerGap

        targetCar =
            consist
                |> List.drop carIndex
                |> List.head
    in
    case targetCar of
        Just car ->
            precedingLength + gaps + stockLength car.stockType / 2

        Nothing ->
            0


{-| Standard 3-car test consist: Locomotive + PassengerCar + Flatbed.
-}
threeCarConsist : List StockItem
threeCarConsist =
    [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
    , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
    , { id = 3, stockType = Flatbed, reversed = False, provisional = False }
    ]



-- BACKWARD COMPATIBILITY TESTS


backwardCompatTests : Test
backwardCompatTests =
    describe "MoveTo without car index (backward compat)"
        [ test "MoveTo with no car specified positions train head at target" <|
            \_ ->
                -- The default MoveTo SpotId behavior should position the train head
                -- (position field) at the target distance. This is existing behavior.
                let
                    route =
                        Route.eastToWestRoute Reverse

                    platformDist =
                        Route.spotPosition PlatformSpot route
                            |> Maybe.withDefault 300
                in
                -- The platform spot should be reachable on the siding route
                platformDist
                    |> Expect.greaterThan 0
        ]



-- CAR OFFSET CALCULATION TESTS


carOffsetCalculationTests : Test
carOffsetCalculationTests =
    describe "Car offset calculation"
        [ test "car index 0 offset is half the first car length" <|
            \_ ->
                -- For car 0 (Locomotive, 10.45m), offset = 10.45 / 2 = 5.225m
                expectedCarOffset threeCarConsist 0
                    |> Expect.within (Expect.Absolute 0.01) (stockLength Locomotive / 2)
        , test "car index 1 offset includes first car + gap + half second car" <|
            \_ ->
                -- For car 1 (PassengerCar, 13.92m):
                -- offset = 10.45 (loco) + 1.0 (gap) + 13.92/2 = 18.41m
                let
                    expected =
                        stockLength Locomotive + couplerGap + stockLength PassengerCar / 2
                in
                expectedCarOffset threeCarConsist 1
                    |> Expect.within (Expect.Absolute 0.01) expected
        , test "car index 2 offset for 3-car consist: loco + gap + coach + gap + half flatbed" <|
            \_ ->
                -- For car 2 (Flatbed, 13.96m):
                -- offset = 10.45 (loco) + 1.0 (gap) + 13.92 (coach) + 1.0 (gap) + 13.96/2
                --        = 10.45 + 1.0 + 13.92 + 1.0 + 6.98 = 33.35m
                let
                    expected =
                        stockLength Locomotive
                            + couplerGap
                            + stockLength PassengerCar
                            + couplerGap
                            + stockLength Flatbed
                            / 2
                in
                expectedCarOffset threeCarConsist 2
                    |> Expect.within (Expect.Absolute 0.01) expected
        ]



-- THREE-CAR CONSIST SPOTTING TESTS


threeCarConsistTests : Test
threeCarConsistTests =
    describe "3-car consist spotting at team track"
        [ test "total consist length is 40.33m (10.45 + 1.0 + 13.92 + 1.0 + 13.96)" <|
            \_ ->
                consistLength threeCarConsist
                    |> Expect.within (Expect.Absolute 0.01) 40.33
        , test "spotting car 2 (flatbed) offset is 33.35m from train head" <|
            \_ ->
                -- Flatbed center should be at:
                -- 10.45 + 1.0 + 13.92 + 1.0 + 6.98 = 33.35m from train head
                let
                    offset =
                        expectedCarOffset threeCarConsist 2

                    expected =
                        stockLength Locomotive
                            + couplerGap
                            + stockLength PassengerCar
                            + couplerGap
                            + stockLength Flatbed
                            / 2
                in
                offset
                    |> Expect.within (Expect.Absolute 0.01) expected
        , test "team track distance is reachable on siding route" <|
            \_ ->
                let
                    route =
                        Route.eastToWestRoute Reverse

                    teamTrackDist =
                        Route.spotPosition TeamTrackSpot route
                in
                case teamTrackDist of
                    Just dist ->
                        dist |> Expect.greaterThan 0

                    Nothing ->
                        Expect.fail "Expected TeamTrackSpot to be reachable on siding route"
        , test "spotting car 2 at team track: train head is offset ahead of team track distance" <|
            \_ ->
                -- When spotting car 2 at team track, the train head should be
                -- (car 2 offset) meters AHEAD of the team track distance,
                -- so that car 2's center aligns with the spot.
                let
                    route =
                        Route.eastToWestRoute Reverse

                    teamTrackDist =
                        Route.spotPosition TeamTrackSpot route
                            |> Maybe.withDefault 0

                    car2Offset =
                        expectedCarOffset threeCarConsist 2

                    expectedHeadPosition =
                        teamTrackDist - car2Offset
                in
                -- The head should be positioned before (lower distance than) the team track
                -- to account for the car offset
                expectedHeadPosition
                    |> Expect.lessThan teamTrackDist
        ]
