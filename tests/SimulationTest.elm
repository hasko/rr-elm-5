module SimulationTest exposing (..)

{-| Tests for the simulation tick working from scenario data:
turnout state dictionary updates, conditional route rebuilds, and
exit-station detection for returned stock.
-}

import Dict
import Expect
import Planning.Types exposing (StockItem, StockType(..))
import Programmer.Types
import ScenarioFixtures exposing (ctx, eastRouteNormal, normalStates, reverseStates)
import Set
import Simulation
import Test exposing (..)
import Track.Element exposing (ElementId(..), SwitchState(..))
import Train.Types exposing (ActiveTrain, TrainState(..))
import Util.GameTime as GameTime


locomotive : StockItem
locomotive =
    { id = 1, stockType = Locomotive, reversed = False, provisional = False }


baseTrain : ActiveTrain
baseTrain =
    { id = 1
    , consist = [ locomotive ]
    , position = 0
    , speed = 0
    , route = eastRouteNormal
    , spawnPoint = "east"
    , program = []
    , programCounter = 0
    , trainState = WaitingForOrders
    , reverser = Programmer.Types.Forward
    , waitTimer = 0
    }


baseState : Simulation.SimState
baseState =
    { timeMultiplier = 1.0
    , gameTime = 0
    , activeTrains = []
    , spawnedTrainIds = Set.empty
    , scheduledTrains = []
    , inventories =
        [ { spawnPointId = "east", availableStock = [] }
        , { spawnPointId = "west", availableStock = [] }
        ]
    , turnoutStates = normalStates
    , selectedTrainId = Nothing
    }


suite : Test
suite =
    describe "Simulation with scenario data"
        [ switchEffectTests
        , rebuildTests
        , exitStationTests
        , spawnTests
        ]


switchEffectTests : Test
switchEffectTests =
    describe "SetSwitch effects update the turnout state dictionary"
        [ test "SetSwitch t1 Diverging flips t1 to Reverse" <|
            \_ ->
                let
                    train =
                        { baseTrain
                            | program = [ Programmer.Types.SetSwitch "t1" Programmer.Types.Diverging ]
                            , trainState = Executing
                        }

                    result =
                        Simulation.tick ctx 100 { baseState | activeTrains = [ train ] }
                in
                Dict.get "t1" result.turnoutStates
                    |> Expect.equal (Just Reverse)
        , test "SetSwitch only touches the addressed turnout" <|
            \_ ->
                let
                    train =
                        { baseTrain
                            | program = [ Programmer.Types.SetSwitch "t9" Programmer.Types.Diverging ]
                            , trainState = Executing
                        }

                    result =
                        Simulation.tick ctx 100 { baseState | activeTrains = [ train ] }
                in
                Dict.get "t1" result.turnoutStates
                    |> Expect.equal (Just Normal)
        ]


rebuildTests : Test
rebuildTests =
    describe "rebuildIfBeforeTurnouts"
        [ test "train before the changed turnout gets the new route" <|
            \_ ->
                let
                    train =
                        { baseTrain | position = 10 }

                    rebuilt =
                        Simulation.rebuildIfBeforeTurnouts ctx reverseStates [ "t1" ] train
                in
                List.map .elementId rebuilt.route.segments
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 5, ElementId 6 ]
        , test "train past the changed turnout keeps its route" <|
            \_ ->
                let
                    train =
                        { baseTrain | position = 400 }

                    rebuilt =
                        Simulation.rebuildIfBeforeTurnouts ctx reverseStates [ "t1" ] train
                in
                List.map .elementId rebuilt.route.segments
                    |> Expect.equal [ ElementId 1, ElementId 2, ElementId 3 ]
        , test "tick rebuilds routes of trains before a program-thrown switch" <|
            \_ ->
                let
                    switcher =
                        { baseTrain
                            | id = 1
                            , program = [ Programmer.Types.SetSwitch "t1" Programmer.Types.Diverging ]
                            , trainState = Executing
                        }

                    follower =
                        { baseTrain | id = 2, position = 5 }

                    result =
                        Simulation.tick ctx 100 { baseState | activeTrains = [ switcher, follower ] }

                    followerRoute =
                        result.activeTrains
                            |> List.filter (\t -> t.id == 2)
                            |> List.head
                            |> Maybe.map (\t -> List.map .elementId t.route.segments)
                in
                followerRoute
                    |> Expect.equal (Just [ ElementId 1, ElementId 2, ElementId 5, ElementId 6 ])
        ]


exitStationTests : Test
exitStationTests =
    describe "despawned trains return stock to the exit station"
        [ test "train exiting the east-to-west route returns stock at west" <|
            \_ ->
                let
                    -- Last car rear (600 - 10.45) is past the 500m route end
                    train =
                        { baseTrain | position = 600 }

                    result =
                        Simulation.tick ctx 100 { baseState | activeTrains = [ train ] }

                    westStock =
                        result.inventories
                            |> List.filter (\inv -> inv.spawnPointId == "west")
                            |> List.head
                            |> Maybe.map (.availableStock >> List.length)
                in
                Expect.all
                    [ \_ -> westStock |> Expect.equal (Just 1)
                    , \_ -> List.length result.activeTrains |> Expect.equal 0
                    ]
                    ()
        , test "train exiting the west-to-east route returns stock at east" <|
            \_ ->
                let
                    train =
                        { baseTrain
                            | spawnPoint = "west"
                            , route = ScenarioFixtures.westRouteNormal
                            , position = 600
                        }

                    result =
                        Simulation.tick ctx 100 { baseState | activeTrains = [ train ] }

                    eastStock =
                        result.inventories
                            |> List.filter (\inv -> inv.spawnPointId == "east")
                            |> List.head
                            |> Maybe.map (.availableStock >> List.length)
                in
                eastStock
                    |> Expect.equal (Just 1)
        ]


spawnTests : Test
spawnTests =
    describe "spawning through the tick"
        [ test "scheduled train spawns with the station's route" <|
            \_ ->
                let
                    scheduled =
                        { id = 7
                        , spawnPoint = "east"
                        , departureTime = GameTime.fromHourMinute 0 0
                        , consist = [ locomotive ]
                        , program = []
                        }

                    result =
                        Simulation.tick ctx 100 { baseState | scheduledTrains = [ scheduled ] }
                in
                case result.activeTrains of
                    [ spawnedTrain ] ->
                        Expect.all
                            [ \t -> t.route.totalLength |> Expect.within (Expect.Absolute 0.01) 500.0
                            , \t -> t.position |> Expect.lessThan 0
                            ]
                            spawnedTrain

                    _ ->
                        Expect.fail "Expected exactly one spawned train"
        ]
