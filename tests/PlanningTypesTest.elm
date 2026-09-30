module PlanningTypesTest exposing (..)

import Expect
import Planning.Types exposing (..)
import Scenario exposing (Station)
import Test exposing (..)
import Util.GameTime as GameTime


{-| Test stations matching the sawmill scenario.
-}
testStations : List Station
testStations =
    [ { id = "east"
      , name = "Millville"
      , portal = "e-portal"
      , stock =
            [ { stockType = "locomotive", count = 1 }
            , { stockType = "coach", count = 2 }
            ]
      }
    , { id = "west"
      , name = "Lumber Junction"
      , portal = "w-portal"
      , stock =
            [ { stockType = "locomotive", count = 1 }
            , { stockType = "flatbed", count = 1 }
            , { stockType = "coach", count = 1 }
            ]
      }
    ]


testPlanningState : PlanningState
testPlanningState =
    initPlanningState testStations


suite : Test
suite =
    describe "Planning.Types"
        [ describe "emptyConsistBuilder"
            [ test "has empty items list" <|
                \_ ->
                    emptyConsistBuilder.items
                        |> Expect.equal []
            , test "has no selected stock" <|
                \_ ->
                    emptyConsistBuilder.selectedStock
                        |> Expect.equal Nothing
            ]
        , describe "initPlanningState"
            [ test "selects first station as default spawn point" <|
                \_ ->
                    testPlanningState.selectedSpawnPoint
                        |> Expect.equal "east"
            , test "has empty scheduled trains list" <|
                \_ ->
                    testPlanningState.scheduledTrains
                        |> Expect.equal []
            , test "has two inventories (one per station)" <|
                \_ ->
                    testPlanningState.inventories
                        |> List.length
                        |> Expect.equal 2
            , test "east inventory has 3 stock items (1 loco + 2 coaches)" <|
                \_ ->
                    let
                        eastInventory =
                            testPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == "east")
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map List.length
                    in
                    eastInventory
                        |> Expect.equal (Just 3)
            , test "west inventory has 3 stock items (1 loco + 1 flatbed + 1 coach)" <|
                \_ ->
                    let
                        westInventory =
                            testPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == "west")
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map List.length
                    in
                    westInventory
                        |> Expect.equal (Just 3)
            , test "east has Locomotive, PassengerCar, PassengerCar (from coach)" <|
                \_ ->
                    let
                        eastStockTypes =
                            testPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == "east")
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map (List.map .stockType)
                    in
                    eastStockTypes
                        |> Expect.equal (Just [ Locomotive, PassengerCar, PassengerCar ])
            , test "west has Locomotive, Flatbed, PassengerCar" <|
                \_ ->
                    let
                        westStockTypes =
                            testPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == "west")
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map (List.map .stockType)
                    in
                    westStockTypes
                        |> Expect.equal (Just [ Locomotive, Flatbed, PassengerCar ])
            , test "stock items have sequential IDs starting at 1" <|
                \_ ->
                    let
                        allIds =
                            testPlanningState.inventories
                                |> List.concatMap .availableStock
                                |> List.map .id
                    in
                    allIds
                        |> Expect.equal [ 1, 2, 3, 4, 5, 6 ]
            , test "has empty consist builder" <|
                \_ ->
                    testPlanningState.consistBuilder
                        |> Expect.equal emptyConsistBuilder
            , test "time picker defaults to Monday 06:00" <|
                \_ ->
                    let
                        time =
                            { day = testPlanningState.timePickerDay
                            , hour = testPlanningState.timePickerHour
                            , minute = testPlanningState.timePickerMinute
                            }
                    in
                    time
                        |> Expect.equal { day = 0, hour = 6, minute = 0 }
            , test "nextTrainId starts at 1" <|
                \_ ->
                    testPlanningState.nextTrainId
                        |> Expect.equal 1
            , test "editingTrainId is Nothing" <|
                \_ ->
                    testPlanningState.editingTrainId
                        |> Expect.equal Nothing
            ]
        , describe "stockTypeName"
            [ test "returns 'Locomotive' for Locomotive" <|
                \_ ->
                    stockTypeName Locomotive
                        |> Expect.equal "Locomotive"
            , test "returns 'Passenger Car' for PassengerCar" <|
                \_ ->
                    stockTypeName PassengerCar
                        |> Expect.equal "Passenger Car"
            , test "returns 'Flatbed' for Flatbed" <|
                \_ ->
                    stockTypeName Flatbed
                        |> Expect.equal "Flatbed"
            , test "returns 'Boxcar' for Boxcar" <|
                \_ ->
                    stockTypeName Boxcar
                        |> Expect.equal "Boxcar"
            ]
        , describe "stockTypeFromString"
            [ test "maps 'locomotive' to Locomotive" <|
                \_ ->
                    stockTypeFromString "locomotive"
                        |> Expect.equal Locomotive
            , test "maps 'coach' to PassengerCar" <|
                \_ ->
                    stockTypeFromString "coach"
                        |> Expect.equal PassengerCar
            , test "maps 'flatbed' to Flatbed" <|
                \_ ->
                    stockTypeFromString "flatbed"
                        |> Expect.equal Flatbed
            , test "maps 'boxcar' to Boxcar" <|
                \_ ->
                    stockTypeFromString "boxcar"
                        |> Expect.equal Boxcar
            ]
        , describe "StockItem"
            [ test "can create stock item with id and type" <|
                \_ ->
                    let
                        item =
                            { id = 42, stockType = Locomotive, reversed = False, provisional = False }
                    in
                    ( item.id, item.stockType )
                        |> Expect.equal ( 42, Locomotive )
            ]
        , describe "SpawnPointInventory"
            [ test "can create inventory with spawn point and stock list" <|
                \_ ->
                    let
                        inventory =
                            { spawnPointId = "east"
                            , availableStock =
                                [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                                ]
                            }
                    in
                    ( inventory.spawnPointId, List.length inventory.availableStock )
                        |> Expect.equal ( "east", 2 )
            ]
        , describe "ScheduledTrain"
            [ test "can create scheduled train" <|
                \_ ->
                    let
                        train =
                            { id = 5
                            , spawnPoint = "west"
                            , departureTime = GameTime.fromDayHourMinute 1 8 30
                            , consist = [ { id = 10, stockType = Locomotive, reversed = False, provisional = False } ]
                            , program = []
                            }
                    in
                    ( train.id, train.spawnPoint, List.length train.consist )
                        |> Expect.equal ( 5, "west", 1 )
            ]
        ]
