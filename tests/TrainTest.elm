module TrainTest exposing (..)

import Expect
import Planning.Types exposing (DepartureTime, ScheduledTrain, SpawnPointId(..), StockItem, StockType(..))
import Programmer.Types exposing (Order(..), SpotId(..))
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
                            testTrain
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
                            testTrain
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
                            testTrain
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
                            testTrain
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
                            testTrain
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
                            testTrain
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
                              , consist = [ { id = 1, stockType = Locomotive } ]
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
                              , consist = [ { id = 1, stockType = Locomotive } ]
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
                              , consist = [ { id = 1, stockType = Locomotive } ]
                              , spawnPoint = EastStation
                              , departureTime = { day = 0, hour = 0, minute = 5 }
                              , program = []
                              }
                            , { id = 2
                              , consist = [ { id = 2, stockType = Locomotive } ]
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
                              , consist = [ { id = 1, stockType = Locomotive } ]
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
                              , consist = [ { id = 1, stockType = Locomotive } ]
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
    , consist = [ { id = 1, stockType = Locomotive } ]
    , position = 0
    , speed = 0
    , route = route
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
                            executingTrain [ Programmer.Types.MoveTo PlatformSpot ]

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
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 0
                            , speed = 0
                            , route = route
                            , program = [ Programmer.Types.MoveTo PlatformSpot ]
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
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 10
                            , speed = 5.0
                            , route = route
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
                            , consist = [ { id = 1, stockType = Locomotive } ]
                            , position = 10
                            , speed = 5.0
                            , route = route
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
        ]
