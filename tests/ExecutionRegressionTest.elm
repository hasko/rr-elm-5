module ExecutionRegressionTest exposing (suite)

{-| Regression tests for execution bugs found in review: trains that could
never despawn, MoveTo orders that froze after overshooting on coarse time
steps, and targets beyond the end of the track.
-}

import Expect
import Planning.Types exposing (StockItem, StockType(..))
import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotTarget(..))
import ScenarioFixtures exposing (ctx, eastRouteNormal, eastRouteReverse)
import Test exposing (Test, describe, test)
import Train.Execution as Execution
import Train.Movement exposing (shouldDespawn)
import Train.Route as Route
import Train.Types exposing (ActiveTrain, Route, TrainState(..))


suite : Test
suite =
    describe "Execution regressions"
        [ describe "MoveTo never freezes after overshooting"
            [ test "arrives from every start position at a coarse 0.8 s time step" <|
                \_ ->
                    let
                        platformDist =
                            Route.spotPosition ctx "platform" eastRouteReverse
                                |> Maybe.withDefault 0

                        stuck =
                            List.range 0 200
                                |> List.map (\i -> toFloat i)
                                |> List.filter (\start -> start < platformDist - 1)
                                |> List.filter
                                    (\start ->
                                        let
                                            final =
                                                train eastRouteReverse [ loco ] [ MoveTo "platform" TrainHead ]
                                                    |> (\t -> { t | position = start })
                                                    |> runFor 0.8 300
                                        in
                                        final.programCounter /= 1
                                    )
                    in
                    stuck |> Expect.equal []
            , test "comes to rest exactly on the target" <|
                \_ ->
                    let
                        platformDist =
                            Route.spotPosition ctx "platform" eastRouteReverse
                                |> Maybe.withDefault 0

                        final =
                            train eastRouteReverse [ loco ] [ MoveTo "platform" TrainHead ]
                                |> runFor (1 / 60) 6000
                    in
                    Expect.all
                        [ \t -> t.position |> Expect.within (Expect.Absolute 0.001) platformDist
                        , \t -> t.speed |> Expect.equal 0
                        , \t -> t.programCounter |> Expect.equal 1
                        ]
                        final
            ]
        , describe "trains leave through portals"
            [ test "MoveTo the far portal departs and despawns" <|
                \_ ->
                    train eastRouteNormal [ loco, flatbed ] [ MoveTo "w-portal" TrainHead ]
                        |> runUntil (1 / 60) 6000 shouldDespawn
                        |> shouldDespawn
                        |> Expect.equal True
            , test "a train with no program runs through and despawns" <|
                \_ ->
                    train eastRouteNormal [ loco ] []
                        |> (\t -> { t | trainState = WaitingForOrders })
                        |> runUntil (1 / 60) 6000 shouldDespawn
                        |> shouldDespawn
                        |> Expect.equal True
            , test "reversing to the spawn portal backs out and despawns" <|
                \_ ->
                    train eastRouteNormal [ loco ] [ MoveTo "platform" TrainHead, SetReverser Reverse, MoveTo "e-portal" TrainHead ]
                        |> (\t -> { t | route = eastRouteReverse })
                        |> runUntil (1 / 60) 12000 shouldDespawn
                        |> shouldDespawn
                        |> Expect.equal True
            ]
        , describe "spotting"
            [ test "a car that cannot be spotted before the buffer stops with an error" <|
                \_ ->
                    let
                        final =
                            train eastRouteReverse [ loco, boxcar 2, boxcar 3, boxcar 4, boxcar 5 ] [ MoveTo "team-track" (SpotCar 4) ]
                                |> runFor 0.1 10
                    in
                    final.trainState |> Expect.equal (Stopped "Cannot spot at team-track: not enough track")
            , test "spotting a car near the buffer takes seconds, not minutes" <|
                \_ ->
                    let
                        start =
                            train eastRouteReverse [ loco, flatbed ] [ MoveTo "team-track" (SpotCar 1) ]
                                |> (\t -> { t | position = 0 })

                        ( ticks, final ) =
                            countUntil (1 / 60) 60000 (\t -> t.programCounter == 1) start
                    in
                    Expect.all
                        [ \_ -> final.programCounter |> Expect.equal 1
                        , \_ -> toFloat ticks / 60 |> Expect.lessThan 120
                        ]
                        ()
            ]
        ]



-- HELPERS


maxSpeed : Float
maxSpeed =
    40.0 * 1000.0 / 3600.0


loco : StockItem
loco =
    { id = 1, stockType = Locomotive, reversed = False, provisional = False }


flatbed : StockItem
flatbed =
    { id = 2, stockType = Flatbed, reversed = False, provisional = False }


boxcar : Int -> StockItem
boxcar id =
    { id = id, stockType = Boxcar, reversed = False, provisional = False }


train : Route -> List StockItem -> List Order -> ActiveTrain
train route consist program =
    { id = 1
    , consist = consist
    , position = 0
    , speed = maxSpeed
    , route = route
    , spawnPoint = "east"
    , program = program
    , programCounter = 0
    , trainState = Executing
    , reverser = Forward
    , waitTimer = 0
    }


step : Float -> ActiveTrain -> ActiveTrain
step dt t =
    Tuple.first (Execution.stepProgram ctx dt t)


runFor : Float -> Int -> ActiveTrain -> ActiveTrain
runFor dt n t =
    if n <= 0 then
        t

    else
        runFor dt (n - 1) (step dt t)


runUntil : Float -> Int -> (ActiveTrain -> Bool) -> ActiveTrain -> ActiveTrain
runUntil dt maxSteps done t =
    Tuple.second (countUntil dt maxSteps done t)


countUntil : Float -> Int -> (ActiveTrain -> Bool) -> ActiveTrain -> ( Int, ActiveTrain )
countUntil dt maxSteps done =
    let
        go n t =
            if done t || n >= maxSteps then
                ( n, t )

            else
                go (n + 1) (step dt t)
    in
    go 0
