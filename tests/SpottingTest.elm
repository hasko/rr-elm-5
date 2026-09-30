module SpottingTest exposing (..)

{-| Tests for car-specific spotting in MoveTo.

The car-specific spotting feature allows MoveTo to position a specific car
in the consist at the target spot, rather than always positioning the
train head (default behavior).

-}

import Expect
import Planning.Types exposing (StockItem, StockType(..))
import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotTarget(..))
import ScenarioFixtures exposing (ctx, eastRouteReverse)
import Test exposing (..)
import Train.Execution as Execution
import Train.Route as Route
import Train.Stock exposing (consistLength, couplerGap, stockLength)
import Train.Types exposing (ActiveTrain, TrainState(..))


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
        targetCar =
            consist
                |> List.drop carIndex
                |> List.head
    in
    case targetCar of
        Just car ->
            let
                precedingCars =
                    List.take carIndex consist

                precedingLength =
                    List.sum (List.map (\item -> stockLength item.stockType) precedingCars)

                gapCount =
                    toFloat carIndex

                gaps =
                    gapCount * couplerGap
            in
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
                let
                    platformDist =
                        Route.spotPosition ctx "platform" eastRouteReverse
                            |> Maybe.withDefault 0

                    final =
                        runToArrival threeCarConsist (MoveTo "platform" TrainHead)
                in
                Expect.all
                    [ \t -> t.programCounter |> Expect.equal 1
                    , \t -> t.position |> Expect.within (Expect.Absolute 0.01) platformDist
                    ]
                    final
        ]


{-| Run a single MoveTo from the start of the siding route until it completes.
-}
runToArrival : List StockItem -> Order -> ActiveTrain
runToArrival consist order =
    let
        go n train =
            if train.programCounter >= 1 || n <= 0 then
                train

            else
                go (n - 1) (Tuple.first (Execution.stepProgram ctx (1 / 60) train))
    in
    go 20000
        { id = 1
        , consist = consist
        , position = 0
        , speed = 0
        , route = eastRouteReverse
        , spawnPoint = "east"
        , program = [ order ]
        , programCounter = 0
        , trainState = Executing
        , reverser = Forward
        , waitTimer = 0
        }



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
                        eastRouteReverse

                    teamTrackDist =
                        Route.spotPosition ctx "team-track" route
                in
                case teamTrackDist of
                    Just dist ->
                        dist |> Expect.greaterThan 0

                    Nothing ->
                        Expect.fail "Expected team-track to be reachable on siding route"
        , test "spotting car 2 at the platform: train head stops car 2's offset beyond the spot" <|
            \_ ->
                -- Cars trail the head at lower route distances, so to put car 2's
                -- center on the spot the head must stop (car 2 offset) meters
                -- further along the route.
                let
                    platformDist =
                        Route.spotPosition ctx "platform" eastRouteReverse
                            |> Maybe.withDefault 0

                    final =
                        runToArrival threeCarConsist (MoveTo "platform" (SpotCar 2))
                in
                Expect.all
                    [ \t -> t.programCounter |> Expect.equal 1
                    , \t ->
                        t.position
                            |> Expect.within (Expect.Absolute 0.01) (platformDist + expectedCarOffset threeCarConsist 2)
                    ]
                    final
        , test "spotting car 2 at team track needs track beyond the buffer, so it stops with an error" <|
            \_ ->
                (runToArrival threeCarConsist (MoveTo "team-track" (SpotCar 2))).trainState
                    |> Expect.equal (Stopped "Cannot spot at team-track: not enough track")
        ]
