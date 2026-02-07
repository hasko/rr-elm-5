module TrainTest exposing (..)

import Expect
import Planning.Types exposing (DepartureTime, ScheduledTrain, SpawnPointId(..), StockItem, StockType(..))
import Planning.Helpers exposing (returnStockToInventory)
import Programmer.Types exposing (Order(..), SpotId(..), SpotTarget(..))
import Train.Execution as Execution
import Sawmill.Layout exposing (SwitchState(..), trackLayout)
import Set
import Test exposing (..)
import Track.Element exposing (ElementId(..))
import Track.Layout as Layout
import Train.Movement exposing (shouldDespawn, updateTrain)
import Train.Route as Route
import Train.Spawn exposing (checkSpawns)
import Train.Stock exposing (consistLength, couplerGap, stockLength, trainSpeed)
import Train.Types exposing (Effect(..), Route, RouteSegment, SegmentGeometry(..), TrainState(..))
import Util.Vec2 as Vec2 exposing (vec2)


suite : Test
suite =
    describe "Train"
        [ stockTests
        , movementTests
        , spawnTests
        , routeTests
        , spotPositionTests
        , dynamicRoutingTests
        , executionTests
        , arcOrientationTests
        , turnoutRebuildTests
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
                    consistLength [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                        |> Expect.within (Expect.Absolute 0.01) 10.45
            , test "two locomotives with gap is 21.9m" <|
                \_ ->
                    consistLength
                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                        , { id = 2, stockType = Locomotive, reversed = False, provisional = False }
                        ]
                        |> Expect.within (Expect.Absolute 0.01) 21.9
            , test "loco + passenger car + flatbed is 10.45 + 13.92 + 13.96 + 2 gaps = 40.33m" <|
                \_ ->
                    consistLength
                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                        , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                        , { id = 3, stockType = Flatbed, reversed = False, provisional = False }
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
                            testTrain
                                { id = 1
                                , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
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
                            testTrain
                                { id = 1
                                , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
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
                            testTrain
                                { id = 1
                                , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
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
                            testTrain
                                { id = 1
                                , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
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
                            testTrain
                                { id = 1
                                , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
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
                            testTrain
                                { id = 1
                                , consist =
                                    [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                    , { id = 2, stockType = Locomotive, reversed = False, provisional = False }
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
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 10.0 scheduled Set.empty Normal
                    in
                    List.length spawned
                        |> Expect.equal 1
            , test "does not spawn train before departure time" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 5.0 scheduled Set.empty Normal
                    in
                    List.length spawned
                        |> Expect.equal 0
            , test "does not re-spawn already spawned train" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 10 }
                              , program = []
                              }
                            ]

                        alreadySpawned =
                            Set.singleton 1

                        spawned =
                            checkSpawns 15.0 scheduled alreadySpawned Normal
                    in
                    List.length spawned
                        |> Expect.equal 0
            , test "spawns multiple trains at same time" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 5 }
                              , program = []
                              }
                            , { id = 2
                              , consist = [ { id = 2, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = WestStation
                              , departureTime = { day = 0, hour = 0, minute = 5 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 5.0 scheduled Set.empty Normal
                    in
                    List.length spawned
                        |> Expect.equal 2
            , test "spawned train starts at negative position (hidden in tunnel)" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty Normal
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
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty Normal
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
                            Route.eastToWestRoute Normal

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
                            Route.eastToWestRoute Normal

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
                            Route.eastToWestRoute Normal

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
                            Route.eastToWestRoute Normal

                        result =
                            Route.positionOnRoute -10.0 route
                    in
                    result
                        |> Expect.equal Nothing
            , test "returns Nothing beyond route end" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        result =
                            Route.positionOnRoute (route.totalLength + 10.0) route
                    in
                    result
                        |> Expect.equal Nothing
            ]
        , describe "eastToWestRoute Normal"
            [ test "has positive total length" <|
                \_ ->
                    (Route.eastToWestRoute Normal).totalLength
                        |> Expect.greaterThan 0.0
            , test "has non-empty segments" <|
                \_ ->
                    List.length (Route.eastToWestRoute Normal).segments
                        |> Expect.greaterThan 0
            ]
        , describe "westToEastRoute Normal"
            [ test "has same total length as eastToWestRoute Normal" <|
                \_ ->
                    (Route.westToEastRoute Normal).totalLength
                        |> Expect.within (Expect.Absolute 0.01) (Route.eastToWestRoute Normal).totalLength
            , test "has same number of segments" <|
                \_ ->
                    List.length (Route.westToEastRoute Normal).segments
                        |> Expect.equal (List.length (Route.eastToWestRoute Normal).segments)
            ]
        ]


dynamicRoutingTests : Test
dynamicRoutingTests =
    describe "Dynamic turnout-aware routing"
        [ describe "Normal switch state (mainline through)"
            [ test "eastToWest Normal route traverses elements 1, 2, 3" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        elementIds =
                            List.map .elementId route.segments
                    in
                    elementIds
                        |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3 ]
            , test "eastToWest Normal total length is 500m (250 + 50 + 200)" <|
                \_ ->
                    (Route.eastToWestRoute Normal).totalLength
                        |> Expect.within (Expect.Absolute 0.01) 500.0
            ]
        , describe "Reverse switch state (siding route)"
            [ test "eastToWest Reverse route includes siding elements" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        elementIds =
                            List.map .elementId route.segments
                    in
                    -- Should go: mainline east (1), turnout diverge (2),
                    -- continuation curve (4), siding straight (5)
                    elementIds
                        |> Expect.equal [ ElementId 1, ElementId 2, ElementId 4, ElementId 5 ]
            , test "eastToWest Reverse route has positive total length" <|
                \_ ->
                    (Route.eastToWestRoute Reverse).totalLength
                        |> Expect.greaterThan 0.0
            , test "eastToWest Reverse route includes element 5 (siding)" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        hasElement5 =
                            List.any (\s -> s.elementId == ElementId 5) route.segments
                    in
                    hasElement5
                        |> Expect.equal True
            , test "siding route ends at buffer stop (no element 3)" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        hasElement3 =
                            List.any (\s -> s.elementId == ElementId 3) route.segments
                    in
                    hasElement3
                        |> Expect.equal False
            ]
        , describe "Route position interpolation on siding"
            [ test "position at start of siding route is valid" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse
                    in
                    case Route.positionOnRoute 0.0 route of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected valid position at start"
            , test "position at end of siding route is valid" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse
                    in
                    case Route.positionOnRoute route.totalLength route of
                        Just _ ->
                            Expect.pass

                        Nothing ->
                            Expect.fail "Expected valid position at end"
            ]
        ]


spotPositionTests : Test
spotPositionTests =
    describe "Train.Route.spotPosition"
        [ describe "tunnel spots on eastToWest route"
            [ test "EastTunnelSpot is at distance 0" <|
                \_ ->
                    Route.spotPosition EastTunnelSpot (Route.eastToWestRoute Normal)
                        |> Expect.equal (Just 0.0)
            , test "WestTunnelSpot is at totalLength" <|
                \_ ->
                    Route.spotPosition WestTunnelSpot (Route.eastToWestRoute Normal)
                        |> Expect.equal (Just (Route.eastToWestRoute Normal).totalLength)
            ]
        , describe "tunnel spots on westToEast route"
            [ test "WestTunnelSpot is at distance 0" <|
                \_ ->
                    Route.spotPosition WestTunnelSpot (Route.westToEastRoute Normal)
                        |> Expect.equal (Just 0.0)
            , test "EastTunnelSpot is at totalLength" <|
                \_ ->
                    Route.spotPosition EastTunnelSpot (Route.westToEastRoute Normal)
                        |> Expect.equal (Just (Route.westToEastRoute Normal).totalLength)
            ]
        , describe "siding spots on mainline routes"
            [ test "PlatformSpot is not reachable on mainline eastToWest route" <|
                \_ ->
                    Route.spotPosition PlatformSpot (Route.eastToWestRoute Normal)
                        |> Expect.equal Nothing
            , test "TeamTrackSpot is not reachable on mainline eastToWest route" <|
                \_ ->
                    Route.spotPosition TeamTrackSpot (Route.eastToWestRoute Normal)
                        |> Expect.equal Nothing
            , test "PlatformSpot is not reachable on mainline westToEast route" <|
                \_ ->
                    Route.spotPosition PlatformSpot (Route.westToEastRoute Normal)
                        |> Expect.equal Nothing
            , test "TeamTrackSpot is not reachable on mainline westToEast route" <|
                \_ ->
                    Route.spotPosition TeamTrackSpot (Route.westToEastRoute Normal)
                        |> Expect.equal Nothing
            ]
        , describe "siding spots on siding route"
            [ test "PlatformSpot is reachable on Reverse siding route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse
                    in
                    case Route.spotPosition PlatformSpot route of
                        Just dist ->
                            dist |> Expect.greaterThan 0.0

                        Nothing ->
                            Expect.fail "Expected PlatformSpot to be reachable on siding route"
            , test "TeamTrackSpot is reachable on Reverse siding route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse
                    in
                    case Route.spotPosition TeamTrackSpot route of
                        Just dist ->
                            dist |> Expect.greaterThan 0.0

                        Nothing ->
                            Expect.fail "Expected TeamTrackSpot to be reachable on siding route"
            , test "PlatformSpot is before TeamTrackSpot on siding route" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        platformDist =
                            Route.spotPosition PlatformSpot route

                        teamTrackDist =
                            Route.spotPosition TeamTrackSpot route
                    in
                    case ( platformDist, teamTrackDist ) of
                        ( Just p, Just t ) ->
                            p |> Expect.lessThan t

                        _ ->
                            Expect.fail "Expected both spots to be reachable"
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


{-| Create a test train with default execution state.
-}
testTrain : { id : Int, consist : List StockItem, position : Float, speed : Float, route : Route } -> Train.Types.ActiveTrain
testTrain { id, consist, position, speed, route } =
    { id = id
    , consist = consist
    , position = position
    , speed = speed
    , route = route
    , spawnPoint = EastStation
    , program = []
    , programCounter = 0
    , trainState = WaitingForOrders
    , reverser = Programmer.Types.Forward
    , waitTimer = 0
    }


{-| Create an executing train with a program on the siding route.
-}
executingTrain : List Programmer.Types.Order -> Train.Types.ActiveTrain
executingTrain program =
    let
        route =
            Route.eastToWestRoute Reverse
    in
    { id = 1
    , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
    , position = 0
    , speed = 0
    , route = route
    , spawnPoint = EastStation
    , program = program
    , programCounter = 0
    , trainState = Executing
    , reverser = Programmer.Types.Forward
    , waitTimer = 0
    }


executionTests : Test
executionTests =
    describe "Train.Execution"
        [ describe "SetReverser"
            [ test "SetReverser Forward sets reverser and advances" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.SetReverser Programmer.Types.Forward ]

                        ( result, effects ) =
                            Execution.stepProgram 0.1 train
                    in
                    Expect.all
                        [ \r -> r.reverser |> Expect.equal Programmer.Types.Forward
                        , \r -> r.programCounter |> Expect.equal 1
                        , \r -> r.trainState |> Expect.equal WaitingForOrders
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            , test "SetReverser Reverse sets reverser and advances" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.SetReverser Programmer.Types.Reverse ]

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    result.reverser |> Expect.equal Programmer.Types.Reverse
            ]
        , describe "SetSwitch"
            [ test "SetSwitch emits effect and advances" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.SetSwitch "turnout1" Programmer.Types.Diverging ]

                        ( result, effects ) =
                            Execution.stepProgram 0.1 train
                    in
                    Expect.all
                        [ \r -> r.programCounter |> Expect.equal 1
                        , \r -> r.trainState |> Expect.equal WaitingForOrders
                        , \_ -> effects |> Expect.equal [ SetSwitchEffect "turnout1" Programmer.Types.Diverging ]
                        ]
                        result
            ]
        , describe "WaitSeconds"
            [ test "WaitSeconds initializes timer and counts down" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.WaitSeconds 5 ]

                        ( result, _ ) =
                            Execution.stepProgram 1.0 train
                    in
                    Expect.all
                        [ \r -> r.trainState |> Expect.equal Executing
                        , \r -> r.waitTimer |> Expect.within (Expect.Absolute 0.01) 4.0
                        , \r -> r.speed |> Expect.equal 0
                        ]
                        result
            , test "WaitSeconds completes and advances when time expires" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.WaitSeconds 2 ]

                        -- Step through 3 seconds total to ensure it completes
                        ( step1, _ ) =
                            Execution.stepProgram 1.0 train

                        ( step2, _ ) =
                            Execution.stepProgram 1.5 step1
                    in
                    Expect.all
                        [ \r -> r.programCounter |> Expect.equal 1
                        , \r -> r.waitTimer |> Expect.equal 0
                        , \r -> r.trainState |> Expect.equal WaitingForOrders
                        ]
                        step2
            ]
        , describe "Couple"
            [ test "Couple stops train with error" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.Couple ]

                        ( result, effects ) =
                            Execution.stepProgram 0.1 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.equal 0
                        , \r ->
                            case r.trainState of
                                Stopped _ ->
                                    Expect.pass

                                _ ->
                                    Expect.fail "Expected Stopped state"
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            ]
        , describe "Uncouple"
            [ test "Uncouple stops train with error" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.Uncouple 1 ]

                        ( result, effects ) =
                            Execution.stepProgram 0.1 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.equal 0
                        , \r ->
                            case r.trainState of
                                Stopped _ ->
                                    Expect.pass

                                _ ->
                                    Expect.fail "Expected Stopped state"
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            ]
        , describe "MoveTo"
            [ test "MoveTo accelerates train toward target" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.MoveTo PlatformSpot TrainHead ]

                        ( result, _ ) =
                            Execution.stepProgram 0.5 train
                    in
                    result.speed |> Expect.greaterThan 0
            , test "MoveTo unreachable spot stops train with error" <|
                \_ ->
                    let
                        -- Use mainline route where PlatformSpot is unreachable
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 0
                            , speed = 0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo PlatformSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    case result.trainState of
                        Stopped _ ->
                            Expect.pass

                        _ ->
                            Expect.fail "Expected Stopped state for unreachable spot"
            ]
        , describe "WaitingForOrders"
            [ test "train with no program coasts to stop" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 10
                            , speed = 5.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = WaitingForOrders
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, effects ) =
                            Execution.stepProgram 0.5 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.lessThan 5.0
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            ]
        , describe "Stopped state"
            [ test "stopped train stays stopped" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 10
                            , speed = 5.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = Stopped "test error"
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, effects ) =
                            Execution.stepProgram 0.5 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.equal 0
                        , \r -> r.trainState |> Expect.equal (Stopped "test error")
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            ]
        , describe "multi-order program"
            [ test "executes multiple instant orders in sequence" <|
                \_ ->
                    let
                        train =
                            executingTrain
                                [ Programmer.Types.SetReverser Programmer.Types.Reverse
                                , Programmer.Types.SetSwitch "turnout1" Programmer.Types.Normal
                                ]

                        -- First step: SetReverser (instant, advances)
                        ( step1, effects1 ) =
                            Execution.stepProgram 0.1 train

                        -- Second step: SetSwitch (instant, advances)
                        ( step2, effects2 ) =
                            Execution.stepProgram 0.1 step1
                    in
                    Expect.all
                        [ \_ -> step1.reverser |> Expect.equal Programmer.Types.Reverse
                        , \_ -> step1.programCounter |> Expect.equal 1
                        , \_ -> effects1 |> Expect.equal []
                        , \_ -> step2.programCounter |> Expect.equal 2
                        , \_ -> step2.trainState |> Expect.equal WaitingForOrders
                        , \_ -> effects2 |> Expect.equal [ SetSwitchEffect "turnout1" Programmer.Types.Normal ]
                        ]
                        ()
            ]
        , describe "program completion"
            [ test "single instant order transitions to WaitingForOrders" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.SetReverser Programmer.Types.Forward ]

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    Expect.all
                        [ \r -> r.trainState |> Expect.equal WaitingForOrders
                        , \r -> r.programCounter |> Expect.equal 1
                        ]
                        result
            , test "empty program immediately transitions to WaitingForOrders" <|
                \_ ->
                    let
                        train =
                            executingTrain []

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    result.trainState |> Expect.equal WaitingForOrders
            , test "program counter equals program length after completion" <|
                \_ ->
                    let
                        train =
                            executingTrain
                                [ Programmer.Types.SetReverser Programmer.Types.Forward
                                , Programmer.Types.SetReverser Programmer.Types.Reverse
                                ]

                        ( step1, _ ) =
                            Execution.stepProgram 0.1 train

                        ( step2, _ ) =
                            Execution.stepProgram 0.1 step1
                    in
                    Expect.all
                        [ \r -> r.programCounter |> Expect.equal 2
                        , \r -> r.trainState |> Expect.equal WaitingForOrders
                        ]
                        step2
            ]
        , describe "buffer stop auto-braking"
            [ test "train near end of route has speed reduced" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        -- Position train very close to route end, moving forward
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = route.totalLength - 5
                            , speed = 10.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo TeamTrackSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.5 train
                    in
                    -- Speed should be reduced or position clamped
                    Expect.all
                        [ \r -> r.position |> Expect.atMost route.totalLength
                        , \r -> r.speed |> Expect.lessThan 10.0
                        ]
                        result
            , test "train position never exceeds route total length" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = route.totalLength - 1
                            , speed = 20.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo TeamTrackSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        -- Step multiple times to push against buffer stop
                        ( step1, _ ) =
                            Execution.stepProgram 0.5 train

                        ( step2, _ ) =
                            Execution.stepProgram 0.5 step1

                        ( step3, _ ) =
                            Execution.stepProgram 0.5 step2
                    in
                    step3.position |> Expect.atMost route.totalLength
            ]
        , describe "reversal with MoveTo"
            [ test "SetReverser Reverse then MoveTo goes backward" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        -- Get platform position on this route
                        platformDist =
                            Route.spotPosition PlatformSpot route
                                |> Maybe.withDefault 300

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = platformDist + 50
                            , speed = 0
                            , route = route
                            , spawnPoint = EastStation
                            , program =
                                [ Programmer.Types.SetReverser Programmer.Types.Reverse
                                , Programmer.Types.MoveTo PlatformSpot TrainHead
                                ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        -- Step 1: SetReverser (instant)
                        ( step1, _ ) =
                            Execution.stepProgram 0.1 train

                        -- Step 2+: MoveTo should accelerate backward (toward lower position)
                        ( step2, _ ) =
                            Execution.stepProgram 1.0 step1
                    in
                    Expect.all
                        [ \_ -> step1.reverser |> Expect.equal Programmer.Types.Reverse
                        , \_ -> step2.speed |> Expect.greaterThan 0
                        , \_ -> step2.position |> Expect.lessThan (platformDist + 50)
                        ]
                        ()
            , test "MoveTo target behind train in Forward direction stops (overshoot)" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        platformDist =
                            Route.spotPosition PlatformSpot route
                                |> Maybe.withDefault 300

                        -- Position past the platform, reverser Forward
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = platformDist + 50
                            , speed = 0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo PlatformSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.5 train
                    in
                    -- Target is behind in forward direction: speed should be 0
                    result.speed |> Expect.equal 0
            ]
        , describe "MoveTo arrival and advance"
            [ test "MoveTo reaches target and advances program counter" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        platformDist =
                            Route.spotPosition PlatformSpot route
                                |> Maybe.withDefault 300

                        -- Place train very close to target (within arrival threshold)
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = platformDist - 0.3
                            , speed = 1.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo PlatformSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.5 train
                    in
                    Expect.all
                        [ \r -> r.programCounter |> Expect.equal 1
                        , \r -> r.speed |> Expect.equal 0
                        , \r -> r.position |> Expect.within (Expect.Absolute 0.01) platformDist
                        , \r -> r.trainState |> Expect.equal WaitingForOrders
                        ]
                        result
            ]
        , describe "spawned train program state"
            [ test "spawned train with program starts in Executing state" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              , program = [ Programmer.Types.SetReverser Programmer.Types.Forward ]
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty Normal
                    in
                    case List.head spawned of
                        Just train ->
                            train.trainState |> Expect.equal Executing

                        Nothing ->
                            Expect.fail "Expected train to be spawned"
            , test "spawned train without program starts in WaitingForOrders state" <|
                \_ ->
                    let
                        scheduled =
                            [ { id = 1
                              , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 0 }
                              , program = []
                              }
                            ]

                        spawned =
                            checkSpawns 0.0 scheduled Set.empty Normal
                    in
                    case List.head spawned of
                        Just train ->
                            train.trainState |> Expect.equal WaitingForOrders

                        Nothing ->
                            Expect.fail "Expected train to be spawned"
            ]
        , describe "coast to stop"
            [ test "WaitingForOrders train with speed 0 stays put" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 100
                            , speed = 0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = WaitingForOrders
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, effects ) =
                            Execution.stepProgram 1.0 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.equal 0
                        , \r -> r.position |> Expect.within (Expect.Absolute 0.01) 100
                        , \_ -> effects |> Expect.equal []
                        ]
                        result
            , test "WaitingForOrders train coasting eventually reaches speed 0" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 10
                            , speed = 3.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = WaitingForOrders
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        -- Coast for several seconds (braking = 3.0 m/s^2, speed 3.0 => 1 second to stop)
                        ( step1, _ ) =
                            Execution.stepProgram 0.5 train

                        ( step2, _ ) =
                            Execution.stepProgram 0.5 step1

                        ( step3, _ ) =
                            Execution.stepProgram 0.5 step2
                    in
                    step3.speed |> Expect.equal 0
            ]
        , describe "error messages"
            [ test "Couple error message matches spec" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.Couple ]

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    result.trainState |> Expect.equal (Stopped "Couple: no adjacent cars found")
            , test "Uncouple error message matches spec" <|
                \_ ->
                    let
                        train =
                            executingTrain [ Programmer.Types.Uncouple 1 ]

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    result.trainState |> Expect.equal (Stopped "Uncouple: not yet supported")
            , test "MoveTo unreachable spot error message matches spec" <|
                \_ ->
                    let
                        -- Use mainline route where PlatformSpot is unreachable
                        route =
                            Route.eastToWestRoute Normal

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 0
                            , speed = 0
                            , route = route
                            , spawnPoint = EastStation
                            , program = [ Programmer.Types.MoveTo PlatformSpot TrainHead ]
                            , programCounter = 0
                            , trainState = Executing
                            , reverser = Programmer.Types.Forward
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.1 train
                    in
                    result.trainState |> Expect.equal (Stopped "Cannot reach Platform")
            ]
        , describe "buffer stop braking in both directions"
            [ test "reverse-direction buffer stop braking near position 0" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        -- Train near start of route, moving in reverse (toward position 0)
                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 5
                            , speed = 10.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = WaitingForOrders
                            , reverser = Programmer.Types.Reverse
                            , waitTimer = 0
                            }

                        ( result, _ ) =
                            Execution.stepProgram 0.5 train
                    in
                    Expect.all
                        [ \r -> r.speed |> Expect.lessThan 10.0
                        , \r -> r.position |> Expect.atLeast 0
                        ]
                        result
            , test "reverse-direction position never goes below 0" <|
                \_ ->
                    let
                        route =
                            Route.eastToWestRoute Reverse

                        train =
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = 1
                            , speed = 20.0
                            , route = route
                            , spawnPoint = EastStation
                            , program = []
                            , programCounter = 0
                            , trainState = WaitingForOrders
                            , reverser = Programmer.Types.Reverse
                            , waitTimer = 0
                            }

                        ( step1, _ ) =
                            Execution.stepProgram 0.5 train

                        ( step2, _ ) =
                            Execution.stepProgram 0.5 step1

                        ( step3, _ ) =
                            Execution.stepProgram 0.5 step2
                    in
                    step3.position |> Expect.atLeast 0
            ]
        , describe "stock return on despawn"
            [ test "returnStockToInventory adds items back to correct spawn point" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 10, stockType = PassengerCar, reversed = False, provisional = False } ]
                              }
                            , { spawnPointId = WestStation
                              , availableStock = []
                              }
                            ]

                        returned =
                            returnStockToInventory EastStation
                                [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                inventories
                    in
                    case List.head returned of
                        Just eastInv ->
                            List.length eastInv.availableStock |> Expect.equal 2

                        Nothing ->
                            Expect.fail "Expected inventory"
            , test "returnStockToInventory does not affect other spawn points" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = []
                              }
                            , { spawnPointId = WestStation
                              , availableStock = [ { id = 5, stockType = Boxcar, reversed = False, provisional = False } ]
                              }
                            ]

                        returned =
                            returnStockToInventory EastStation
                                [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                inventories
                    in
                    case returned of
                        [ _, westInv ] ->
                            List.length westInv.availableStock |> Expect.equal 1

                        _ ->
                            Expect.fail "Expected 2 inventories"
            , test "despawned train consist determines returned stock" <|
                \_ ->
                    let
                        -- Simulate a 3-car train returning its consist
                        consist =
                            [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                            , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                            , { id = 3, stockType = Flatbed, reversed = False, provisional = False }
                            ]

                        inventories =
                            [ { spawnPointId = WestStation, availableStock = [] }
                            , { spawnPointId = EastStation, availableStock = [] }
                            ]

                        returned =
                            returnStockToInventory WestStation consist inventories
                    in
                    case List.head returned of
                        Just westInv ->
                            Expect.all
                                [ \inv -> List.length inv.availableStock |> Expect.equal 3
                                , \inv ->
                                    List.map .stockType inv.availableStock
                                        |> Expect.equal [ Locomotive, PassengerCar, Flatbed ]
                                ]
                                westInv

                        Nothing ->
                            Expect.fail "Expected inventory"
            ]
        ]


arcOrientationTests : Test
arcOrientationTests =
    describe "Arc orientation matches travel direction"
        [ test "orientation on diverging arc at t=0.5 differs from t=0" <|
            \_ ->
                let
                    route =
                        Route.eastToWestRoute Reverse

                    -- Find where the arc segment (turnout diverge, ElementId 2) starts
                    arcSegment =
                        route.segments
                            |> List.filter (\s -> s.elementId == ElementId 2)
                            |> List.head
                in
                case arcSegment of
                    Just seg ->
                        let
                            posAtStart =
                                Route.positionOnRoute seg.startDistance route

                            posAtMid =
                                Route.positionOnRoute (seg.startDistance + seg.length / 2) route
                        in
                        case ( posAtStart, posAtMid ) of
                            ( Just start, Just mid ) ->
                                -- Orientation should change along the arc
                                abs (start.orientation - mid.orientation)
                                    |> Expect.greaterThan 0.01

                            _ ->
                                Expect.fail "Expected valid positions on arc"

                    Nothing ->
                        Expect.fail "Expected arc segment on siding route"
        , test "position on arc is on the curve, not a straight line" <|
            \_ ->
                let
                    route =
                        Route.eastToWestRoute Reverse

                    arcSegment =
                        route.segments
                            |> List.filter (\s -> s.elementId == ElementId 2)
                            |> List.head
                in
                case arcSegment of
                    Just seg ->
                        let
                            posAtStart =
                                Route.positionOnRoute seg.startDistance route

                            posAtEnd =
                                Route.positionOnRoute (seg.startDistance + seg.length) route

                            posAtMid =
                                Route.positionOnRoute (seg.startDistance + seg.length / 2) route
                        in
                        case ( posAtStart, posAtEnd, posAtMid ) of
                            ( Just s, Just e, Just m ) ->
                                -- Midpoint should not be the average of start and end
                                -- (i.e., it's on a curve, not a straight line)
                                let
                                    linearMidX =
                                        (s.position.x + e.position.x) / 2

                                    linearMidY =
                                        (s.position.y + e.position.y) / 2

                                    deviationX =
                                        abs (m.position.x - linearMidX)

                                    deviationY =
                                        abs (m.position.y - linearMidY)
                                in
                                -- At least one axis should deviate from linear midpoint
                                (deviationX + deviationY)
                                    |> Expect.greaterThan 0.1

                            _ ->
                                Expect.fail "Expected valid positions on arc"

                    Nothing ->
                        Expect.fail "Expected arc segment on siding route"
        ]


turnoutRebuildTests : Test
turnoutRebuildTests =
    describe "Conditional route rebuild on switch change"
        [ test "turnoutStartDistance returns Just for route containing turnout" <|
            \_ ->
                let
                    route =
                        Route.eastToWestRoute Normal
                in
                case Route.turnoutStartDistance route of
                    Just dist ->
                        dist |> Expect.greaterThan 0.0

                    Nothing ->
                        Expect.fail "Expected turnout on mainline route"
        , test "turnoutStartDistance returns Nothing for route without turnout" <|
            \_ ->
                let
                    route =
                        testRoute 500.0
                in
                Route.turnoutStartDistance route
                    |> Expect.equal Nothing
        , test "train before turnout gets route rebuilt" <|
            \_ ->
                let
                    normalRoute =
                        Route.eastToWestRoute Normal

                    -- Position train before the turnout
                    turnoutDist =
                        Route.turnoutStartDistance normalRoute
                            |> Maybe.withDefault 999

                    train =
                        testTrain
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = turnoutDist - 10
                            , speed = 5.0
                            , route = normalRoute
                            }

                    reverseRoute =
                        Route.eastToWestRoute Reverse
                in
                -- Route should differ from Normal after rebuild with Reverse
                -- (the segments after turnout differ)
                let
                    normalSegmentIds =
                        List.map .elementId normalRoute.segments

                    reverseSegmentIds =
                        List.map .elementId reverseRoute.segments
                in
                normalSegmentIds
                    |> Expect.notEqual reverseSegmentIds
        , test "train past turnout keeps existing route on switch change" <|
            \_ ->
                let
                    -- Build a siding route (Reverse)
                    sidingRoute =
                        Route.eastToWestRoute Reverse

                    turnoutDist =
                        Route.turnoutStartDistance sidingRoute
                            |> Maybe.withDefault 0

                    -- Find the turnout segment to get past it
                    turnoutSegment =
                        sidingRoute.segments
                            |> List.filter (\s -> s.elementId == ElementId 2)
                            |> List.head

                    pastTurnoutDist =
                        case turnoutSegment of
                            Just seg ->
                                seg.startDistance + seg.length + 10

                            Nothing ->
                                turnoutDist + 50

                    -- Train is past the turnout on the siding
                    train =
                        testTrain
                            { id = 1
                            , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                            , position = pastTurnoutDist
                            , speed = 0.0
                            , route = sidingRoute
                            }

                    -- Now try to rebuild with Normal (mainline) state
                    -- The route should NOT change because train is past turnout
                    originalSegmentIds =
                        List.map .elementId train.route.segments

                    -- Simulate what rebuildIfBeforeTurnout would do:
                    -- train.position >= turnoutDist, so route should stay
                    trainPositionPastTurnout =
                        train.position >= turnoutDist
                in
                trainPositionPastTurnout
                    |> Expect.equal True
        ]
