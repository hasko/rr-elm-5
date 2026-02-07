module ConsistBuilderTest exposing (..)

import Expect
import Planning.Helpers exposing (..)
import Planning.Types exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Planning.Helpers"
        [ describe "takeFirst"
            [ test "returns Nothing and original list when list is empty" <|
                \_ ->
                    takeFirst (\x -> x > 5) []
                        |> Expect.equal ( Nothing, [] )
            , test "returns first matching item and remaining list" <|
                \_ ->
                    takeFirst (\x -> x > 5) [ 1, 2, 6, 7, 8 ]
                        |> Expect.equal ( Just 6, [ 1, 2, 7, 8 ] )
            , test "returns Nothing when no item matches" <|
                \_ ->
                    takeFirst (\x -> x > 10) [ 1, 2, 3 ]
                        |> Expect.equal ( Nothing, [ 1, 2, 3 ] )
            , test "returns first match when multiple items match" <|
                \_ ->
                    takeFirst (\x -> x > 5) [ 1, 6, 7, 8 ]
                        |> Expect.equal ( Just 6, [ 1, 7, 8 ] )
            , test "preserves order of remaining items" <|
                \_ ->
                    takeFirst (\x -> x == 2) [ 1, 2, 3, 4 ]
                        |> Expect.equal ( Just 2, [ 1, 3, 4 ] )
            , test "removes item from front of list" <|
                \_ ->
                    takeFirst (\x -> x == 1) [ 1, 2, 3 ]
                        |> Expect.equal ( Just 1, [ 2, 3 ] )
            , test "removes item from end of list" <|
                \_ ->
                    takeFirst (\x -> x == 3) [ 1, 2, 3 ]
                        |> Expect.equal ( Just 3, [ 1, 2 ] )
            ]
        , describe "takeStockFromInventory"
            [ test "returns Nothing when inventories list is empty" <|
                \_ ->
                    takeStockFromInventory EastStation Locomotive []
                        |> Expect.equal ( Nothing, [] )
            , test "takes one stock item of specified type from correct spawn point" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock =
                                    [ { id = 1, stockType = Locomotive, reversed = False }
                                    , { id = 2, stockType = PassengerCar, reversed = False }
                                    ]
                              }
                            ]

                        ( taken, newInventories ) =
                            takeStockFromInventory EastStation Locomotive inventories
                    in
                    Expect.all
                        [ \_ -> taken |> Expect.equal (Just { id = 1, stockType = Locomotive, reversed = False })
                        , \_ ->
                            newInventories
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Expect.equal (Just [ { id = 2, stockType = PassengerCar, reversed = False } ])
                        ]
                        ()
            , test "takes first matching item when multiple of same type exist" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = WestStation
                              , availableStock =
                                    [ { id = 5, stockType = Boxcar, reversed = False }
                                    , { id = 6, stockType = Boxcar, reversed = False }
                                    ]
                              }
                            ]

                        ( taken, _ ) =
                            takeStockFromInventory WestStation Boxcar inventories
                    in
                    taken
                        |> Expect.equal (Just { id = 5, stockType = Boxcar, reversed = False })
            , test "returns Nothing when stock type not available" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        ( taken, _ ) =
                            takeStockFromInventory EastStation Flatbed inventories
                    in
                    taken
                        |> Expect.equal Nothing
            , test "returns Nothing when spawn point not found" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        ( taken, _ ) =
                            takeStockFromInventory WestStation Locomotive inventories
                    in
                    taken
                        |> Expect.equal Nothing
            , test "preserves other spawn point inventories" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            , { spawnPointId = WestStation
                              , availableStock = [ { id = 2, stockType = Boxcar, reversed = False } ]
                              }
                            ]

                        ( _, newInventories ) =
                            takeStockFromInventory EastStation Locomotive inventories
                    in
                    newInventories
                        |> List.filter (\inv -> inv.spawnPointId == WestStation)
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Expect.equal (Just [ { id = 2, stockType = Boxcar, reversed = False } ])
            , test "handles taking last item from inventory" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        ( taken, newInventories ) =
                            takeStockFromInventory EastStation Locomotive inventories
                    in
                    Expect.all
                        [ \_ -> taken |> Expect.equal (Just { id = 1, stockType = Locomotive, reversed = False })
                        , \_ ->
                            newInventories
                                |> List.head
                                |> Maybe.map .availableStock
                                |> Expect.equal (Just [])
                        ]
                        ()
            ]
        , describe "returnStockToInventory"
            [ test "returns empty list when inventories list is empty" <|
                \_ ->
                    returnStockToInventory EastStation [ { id = 1, stockType = Locomotive, reversed = False } ] []
                        |> Expect.equal []
            , test "adds stock items to correct spawn point inventory" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        itemsToReturn =
                            [ { id = 2, stockType = PassengerCar, reversed = False }
                            , { id = 3, stockType = Flatbed, reversed = False }
                            ]

                        newInventories =
                            returnStockToInventory EastStation itemsToReturn inventories
                    in
                    newInventories
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Maybe.map List.length
                        |> Expect.equal (Just 3)
            , test "preserves order by appending returned items" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        itemsToReturn =
                            [ { id = 2, stockType = PassengerCar, reversed = False } ]

                        newInventories =
                            returnStockToInventory EastStation itemsToReturn inventories
                    in
                    newInventories
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Expect.equal
                            (Just
                                [ { id = 1, stockType = Locomotive, reversed = False }
                                , { id = 2, stockType = PassengerCar, reversed = False }
                                ]
                            )
            , test "does not modify other spawn point inventories" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            , { spawnPointId = WestStation
                              , availableStock = [ { id = 4, stockType = Boxcar, reversed = False } ]
                              }
                            ]

                        itemsToReturn =
                            [ { id = 2, stockType = PassengerCar, reversed = False } ]

                        newInventories =
                            returnStockToInventory EastStation itemsToReturn inventories
                    in
                    newInventories
                        |> List.filter (\inv -> inv.spawnPointId == WestStation)
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Expect.equal (Just [ { id = 4, stockType = Boxcar, reversed = False } ])
            , test "handles returning empty list" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        newInventories =
                            returnStockToInventory EastStation [] inventories
                    in
                    newInventories
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Expect.equal (Just [ { id = 1, stockType = Locomotive, reversed = False } ])
            , test "handles returning to empty inventory" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = []
                              }
                            ]

                        itemsToReturn =
                            [ { id = 1, stockType = Locomotive, reversed = False } ]

                        newInventories =
                            returnStockToInventory EastStation itemsToReturn inventories
                    in
                    newInventories
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Expect.equal (Just [ { id = 1, stockType = Locomotive, reversed = False } ])
            ]
        , describe "Integration scenarios"
            [ test "take and return cycle preserves inventory" <|
                \_ ->
                    let
                        initialInventories =
                            [ { spawnPointId = EastStation
                              , availableStock =
                                    [ { id = 1, stockType = Locomotive, reversed = False }
                                    , { id = 2, stockType = PassengerCar, reversed = False }
                                    ]
                              }
                            ]

                        ( takenItem, afterTake ) =
                            takeStockFromInventory EastStation Locomotive initialInventories

                        afterReturn =
                            case takenItem of
                                Just item ->
                                    returnStockToInventory EastStation [ item ] afterTake

                                Nothing ->
                                    afterTake
                    in
                    afterReturn
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Maybe.map List.length
                        |> Expect.equal (Just 2)
            , test "multiple takes from same inventory" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock =
                                    [ { id = 1, stockType = Locomotive, reversed = False }
                                    , { id = 2, stockType = PassengerCar, reversed = False }
                                    , { id = 3, stockType = Flatbed, reversed = False }
                                    ]
                              }
                            ]

                        ( _, afterFirst ) =
                            takeStockFromInventory EastStation Locomotive inventories

                        ( _, afterSecond ) =
                            takeStockFromInventory EastStation PassengerCar afterFirst
                    in
                    afterSecond
                        |> List.head
                        |> Maybe.map .availableStock
                        |> Maybe.map List.length
                        |> Expect.equal (Just 1)
            , test "cannot take more items than available" <|
                \_ ->
                    let
                        inventories =
                            [ { spawnPointId = EastStation
                              , availableStock = [ { id = 1, stockType = Locomotive, reversed = False } ]
                              }
                            ]

                        ( _, afterFirst ) =
                            takeStockFromInventory EastStation Locomotive inventories

                        ( secondTake, _ ) =
                            takeStockFromInventory EastStation Locomotive afterFirst
                    in
                    secondTake
                        |> Expect.equal Nothing
            ]
        ]
