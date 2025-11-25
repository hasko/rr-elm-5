module TrainTest exposing (..)

import Expect
import Planning.Types exposing (DepartureTime, ScheduledTrain, SpawnPointId(..), StockItem, StockType(..))
import Set
import Test exposing (..)
import Track.Element exposing (ElementId(..))
import Train.Movement exposing (shouldDespawn, updateTrain)
import Train.Route as Route
import Train.Spawn exposing (checkSpawns)
import Train.Stock exposing (consistLength, couplerGap, stockLength, trainSpeed)
import Train.Types exposing (Route, RouteSegment, SegmentGeometry(..))
import Util.Vec2 exposing (vec2)


suite : Test
suite =
    describe "Train"
        [ stockTests
        , movementTests
        , spawnTests
        , routeTests
        ]


stockTests : Test
stockTests =
    describe "Train.Stock"
        [ describe "stockLength"
            [ test "locomotive (V60) is 10.45m" <|
                \_ ->
                    stockLength Locomotive
                        |> Expect.within (Expect.Absolute 0.01) 10.45
            , test "passenger car (Donnerbüchse) is 13.92m" <|
                \_ ->
                    stockLength PassengerCar
                        |> Expect.within (Expect.Absolute 0.01) 13.92
            , test "flatbed is 13.96m" <|
                \_ ->
                    stockLength Flatbed
                        |> Expect.within (Expect.Absolute 0.01) 13.96
            , test "boxcar is 12m" <|
                \_ ->
                    stockLength Boxcar
                        |> Expect.within (Expect.Absolute 0.01) 12.0
            ]
        , describe "couplerGap"
            [ test "is 1m" <|
                \_ ->
                    couplerGap
                        |> Expect.within (Expect.Absolute 0.01) 1.0
            ]
        , describe "consistLength"
            [ test "empty consist has zero length" <|
                \_ ->
                    consistLength []
                        |> Expect.within (Expect.Absolute 0.01) 0.0
            , test "single locomotive is 10.45m" <|
                \_ ->
                    consistLength [ { id = 1, stockType = Locomotive } ]
                        |> Expect.within (Expect.Absolute 0.01) 10.45
            , test "two locomotives with gap is 21.9m" <|
                \_ ->
                    consistLength
                        [ { id = 1, stockType = Locomotive }
                        , { id = 2, stockType = Locomotive }
                        ]
                        |> Expect.within (Expect.Absolute 0.01) 21.9
            , test "loco + passenger car + flatbed is 10.45 + 13.92 + 13.96 + 2 gaps = 40.33m" <|
                \_ ->
                    consistLength
                        [ { id = 1, stockType = Locomotive }
                        , { id = 2, stockType = PassengerCar }
                        , { id = 3, stockType = Flatbed }
                        ]
                        |> Expect.within (Expect.Absolute 0.01) 40.33
            ]
        , describe "trainSpeed"
            [ test "is approximately 11.11 m/s (40 km/h)" <|
                \_ ->
                    trainSpeed
                        |> Expect.within (Expect.Absolute 0.01) (40.0 * 1000.0 / 3600.0)
            ]
        ]


movementTests : Test
movementTests =
    describe "Train.Movement"
        [ describe "updateTrain"
            [ test "moves train forward by speed * delta" <|
                \_ ->
                    let
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 0.0
                            , speed = 10.0
                            , route = testRoute 500.0
                            }

                        updated =
                            updateTrain 1.0 train
                    in
                    updated.position
                        |> Expect.within (Expect.Absolute 0.01) 10.0
            , test "updates position correctly with fractional delta" <|
                \_ ->
                    let
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 100.0
                            , speed = 11.11
                            , route = testRoute 500.0
                            }

                        updated =
                            updateTrain 0.5 train
                    in
                    updated.position
                        |> Expect.within (Expect.Absolute 0.01) 105.555
            ]
        , describe "shouldDespawn"
            [ test "returns False when train is on route" <|
                \_ ->
                    let
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 100.0
                            , speed = 10.0
                            , route = testRoute 500.0
                            }
                    in
                    shouldDespawn train
                        |> Expect.equal False
            , test "returns False when lead car is past end but last car is still on route" <|
                \_ ->
                    let
                        -- Train at position 510 with 10.45m locomotive
                        -- Last car rear is at 510 - 10.45 = 499.55, still on 500m route
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 510.0
                            , speed = 10.0
                            , route = testRoute 500.0
                            }
                    in
                    shouldDespawn train
                        |> Expect.equal False
            , test "returns True when last car has exited route" <|
                \_ ->
                    let
                        -- Train at position 530 with 10.45m locomotive
                        -- Last car rear is at 530 - 10.45 = 519.55 > 500
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 530.0
                            , speed = 10.0
                            , route = testRoute 500.0
                            }
                    in
                    shouldDespawn train
                        |> Expect.equal True
            , test "accounts for multi-car consist length" <|
                \_ ->
                    let
                        -- 2 locos = 10.45 + 10.45 + 1 gap = 21.9m
                        -- Position 550 - 21.9 = 528.1 > 500
                        train =
                            { id = 1
                            , consist =
                                [ { id = 1, stockType = Locomotive }
                                , { id = 2, stockType = Locomotive }
                                ]
                            , position = 550.0
                            , speed = 10.0
                            , route = testRoute 500.0
                            }
                    in
                    shouldDespawn train
                        |> Expect.equal True
            ]
        ]


spawnTests : Test
spawnTests =
    describe "Train.Spawn"
        [ describe "checkSpawns"
            [ test "spawns train when elapsed time reaches departure time" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              }
                            ]

                        spawned =
                            checkSpawns 10.0 scheduled Set.empty
                    in
                    List.length spawned
                        |> Expect.equal 1
            , test "does not spawn train before departure time" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              }
                            ]

                        spawned =
                            checkSpawns 5.0 scheduled Set.empty
                    in
                    List.length spawned
                        |> Expect.equal 0
            , test "does not re-spawn already spawned train" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              }
                            ]

                        alreadySpawned =
                            Set.singleton 1

                        spawned =
                            checkSpawns 15.0 scheduled alreadySpawned
                    in
                    List.length spawned
                        |> Expect.equal 0
            , test "spawns multiple trains at same time" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 5 }
                              }
                            , { id = 2
                              , consist = [ { id = 2, stockType = Locomotive } ]
                              , spawnPoint = WestStation
                              , departureTime = { day = 0, hour = 0, minute = 5 }
                              }
                            ]

                        spawned =
                            checkSpawns 5.0 scheduled Set.empty
                    in
                    List.length spawned
                        |> Expect.equal 2
            , test "spawned train starts at negative position (hidden in tunnel)" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty
                    in
                    case List.head spawned of
                        Just train ->
                            train.position
                                |> Expect.lessThan 0

                        Nothing ->
                            Expect.fail "Expected train to be spawned"
            , test "spawned train has correct speed" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty
                    in
                    case List.head spawned of
                        Just train ->
                            train.speed
                                |> Expect.within (Expect.Absolute 0.01) trainSpeed

                        Nothing ->
                            Expect.fail "Expected train to be spawned"
            ]
        ]


routeTests : Test
routeTests =
    describe "Train.Route"
        [ describe "positionOnRoute"
            [ test "returns position at start of route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute

                        result =
                            Route.positionOnRoute 0.0 route
                    in
                    case result of
                        Just pos ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected valid position at start of route"
            , test "returns position in middle of route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute

                        result =
                            Route.positionOnRoute (route.totalLength / 2) route
                    in
                    case result of
                        Just pos ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected valid position in middle of route"
            , test "returns position at end of route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute

                        result =
                            Route.positionOnRoute route.totalLength route
                    in
                    case result of
                        Just pos ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected valid position at end of route"
            , test "returns Nothing for negative distance" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute

                        result =
                            Route.positionOnRoute -10.0 route
                    in
                    result
                        |> Expect.equal Nothing
            , test "returns Nothing beyond route end" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute

                        result =
                            Route.positionOnRoute (route.totalLength + 10.0) route
                    in
                    result
                        |> Expect.equal Nothing
            ]
        , describe "eastToWestRoute"
            [ test "has positive total length" <|
                \_ ->
                    Route.eastToWestRoute.totalLength
                        |> Expect.greaterThan 0.0
            , test "has non-empty segments" <|
                \_ ->
                    List.length Route.eastToWestRoute.segments
                        |> Expect.greaterThan 0
            ]
        , describe "westToEastRoute"
            [ test "has same total length as eastToWestRoute" <|
                \_ ->
                    Route.westToEastRoute.totalLength
                        |> Expect.within (Expect.Absolute 0.01) Route.eastToWestRoute.totalLength
            , test "has same number of segments" <|
                \_ ->
                    List.length Route.westToEastRoute.segments
                        |> Expect.equal (List.length Route.eastToWestRoute.segments)
            ]
        ]



-- Helper functions


{-| Create a test route with simple geometry.
-}
testRoute : Float -> Route
testRoute length =
    { segments =
        [ { elementId = ElementId 1
          , length = length
          , startDistance = 0.0
          , geometry =
                StraightGeometry
                    { start = vec2 0 0
                    , end = vec2 length 0
                    , orientation = 0
                    }
          }
        ]
    , totalLength = length
    }
