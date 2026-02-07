module PlanningTypesTest exposing (..)

import Expect
import Planning.Types as Planning exposing (..)
import Test exposing (..)


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
            [ test "has EastStation as default selected spawn point" <|
                \_ ->
                    initPlanningState.selectedSpawnPoint
                        |> Expect.equal EastStation
            , test "has empty scheduled trains list" <|
                \_ ->
                    initPlanningState.scheduledTrains
                        |> Expect.equal []
            , test "has two inventories (EastStation and WestStation)" <|
                \_ ->
                    initPlanningState.inventories
                        |> List.length
                        |> Expect.equal 2
            , test "EastStation inventory has 3 stock items" <|
                \_ ->
                    let
                        eastInventory =
                            initPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == EastStation)
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map List.length
                    in
                    eastInventory
                        |> Expect.equal (Just 3)
            , test "WestStation inventory has 3 stock items" <|
                \_ ->
                    let
                        westInventory =
                            initPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == WestStation)
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map List.length
                    in
                    westInventory
                        |> Expect.equal (Just 3)
            , test "EastStation has Locomotive, PassengerCar, Flatbed" <|
                \_ ->
                    let
                        eastStockTypes =
                            initPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == EastStation)
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map (List.map .stockType)
                    in
                    eastStockTypes
                        |> Expect.equal (Just [ Locomotive, PassengerCar, Flatbed ])
            , test "WestStation has Locomotive and two Boxcars" <|
                \_ ->
                    let
                        westStockTypes =
                            initPlanningState.inventories
                                |> List.filter (\inv -> inv.spawnPointId == WestStation)
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Maybe.map (List.map .stockType)
                    in
                    westStockTypes
                        |> Expect.equal (Just [ Locomotive, Boxcar, Boxcar ])
            , test "has empty consist builder" <|
                \_ ->
                    initPlanningState.consistBuilder
                        |> Expect.equal emptyConsistBuilder
            , test "time picker defaults to Monday 06:00" <|
                \_ ->
                    let
                        time =
                            { day = initPlanningState.timePickerDay
                            , hour = initPlanningState.timePickerHour
                            , minute = initPlanningState.timePickerMinute
                            }
                    in
                    time
                        |> Expect.equal { day = 0, hour = 6, minute = 0 }
            , test "nextTrainId starts at 1" <|
                \_ ->
                    initPlanningState.nextTrainId
                        |> Expect.equal 1
            , test "editingTrainId is Nothing" <|
                \_ ->
                    initPlanningState.editingTrainId
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
        , describe "DepartureTime"
            [ test "can create departure time with day, hour, minute" <|
                \_ ->
                    let
                        time =
                            { day = 2, hour = 14, minute = 30 }
                    in
                    ( time.day, time.hour, time.minute )
                        |> Expect.equal ( 2, 14, 30 )
            ]
        , describe "SpawnPointInventory"
            [ test "can create inventory with spawn point and stock list" <|
                \_ ->
                    let
                        inventory =
                            { spawnPointId = EastStation
                            , availableStock =
                                [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                                ]
                            }
                    in
                    ( inventory.spawnPointId, List.length inventory.availableStock )
                        |> Expect.equal ( EastStation, 2 )
            ]
        , describe "ScheduledTrain"
            [ test "can create scheduled train" <|
                \_ ->
                    let
                        train =
                            { id = 5
                            , spawnPoint = WestStation
                            , departureTime = { day = 1, hour = 8, minute = 30 }
                            , consist = [ { id = 10, stockType = Locomotive, reversed = False, provisional = False } ]
                            }
                    in
                    ( train.id, train.spawnPoint, List.length train.consist )
                        |> Expect.equal ( 5, WestStation, 1 )
            ]
        ]
