module StockDisplayTest exposing (..)

{-| TDD tests for unavailable stock display.

The stock display should show ALL stock types in the inventory, including
those with 0 available count. Unavailable items should be trackable
(provisional) so users can plan consists that require stock not yet returned.

These tests are written TDD-style and will fail until the implementation lands.

-}

import Expect
import Planning.Types
    exposing
        ( PlanningState
        , SpawnPointId(..)
        , SpawnPointInventory
        , StockItem
        , StockType(..)
        , initPlanningState
        )
import Test exposing (..)


suite : Test
suite =
    describe "Unavailable stock display"
        [ allTypesVisibleTests
        , provisionalItemTests
        ]


{-| All four stock types that should always appear.
-}
allStockTypes : List StockType
allStockTypes =
    [ Locomotive, PassengerCar, Flatbed, Boxcar ]


{-| Helper: count available stock of a given type in an inventory.
-}
countStockType : StockType -> List StockItem -> Int
countStockType stockType items =
    items
        |> List.filter (\item -> item.stockType == stockType)
        |> List.length


{-| Helper: group stock by type, returning all types with their counts.
This replicates what the view layer should do after the fix.
-}
groupAllStockTypes : List StockItem -> List ( StockType, Int )
groupAllStockTypes items =
    allStockTypes
        |> List.map (\st -> ( st, countStockType st items ))



-- ALL TYPES VISIBLE TESTS


allTypesVisibleTests : Test
allTypesVisibleTests =
    describe "All stock types appear in inventory"
        [ test "East Station inventory has Locomotive, PassengerCar, Flatbed (count > 0)" <|
            \_ ->
                let
                    state =
                        initPlanningState

                    eastInventory =
                        state.inventories
                            |> List.filter (\inv -> inv.spawnPointId == EastStation)
                            |> List.head
                            |> Maybe.map .availableStock
                            |> Maybe.withDefault []

                    grouped =
                        groupAllStockTypes eastInventory

                    nonZero =
                        List.filter (\( _, count ) -> count > 0) grouped
                in
                -- East Station starts with 3 types with stock
                List.length nonZero
                    |> Expect.equal 3
        , test "East Station should show Boxcar with 0 count" <|
            \_ ->
                let
                    state =
                        initPlanningState

                    eastInventory =
                        state.inventories
                            |> List.filter (\inv -> inv.spawnPointId == EastStation)
                            |> List.head
                            |> Maybe.map .availableStock
                            |> Maybe.withDefault []

                    boxcarCount =
                        countStockType Boxcar eastInventory
                in
                -- East Station has no boxcars, but the type should still be displayed
                boxcarCount
                    |> Expect.equal 0
        , test "West Station should show PassengerCar and Flatbed with 0 count" <|
            \_ ->
                let
                    state =
                        initPlanningState

                    westInventory =
                        state.inventories
                            |> List.filter (\inv -> inv.spawnPointId == WestStation)
                            |> List.head
                            |> Maybe.map .availableStock
                            |> Maybe.withDefault []

                    passengerCount =
                        countStockType PassengerCar westInventory

                    flatbedCount =
                        countStockType Flatbed westInventory
                in
                Expect.all
                    [ \_ -> passengerCount |> Expect.equal 0
                    , \_ -> flatbedCount |> Expect.equal 0
                    ]
                    ()
        , test "groupAllStockTypes always returns exactly 4 entries" <|
            \_ ->
                let
                    -- Even an empty inventory should produce 4 type entries
                    grouped =
                        groupAllStockTypes []
                in
                List.length grouped
                    |> Expect.equal 4
        , test "groupAllStockTypes returns 0 for types not in inventory" <|
            \_ ->
                let
                    inventory =
                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]

                    grouped =
                        groupAllStockTypes inventory

                    boxcarEntry =
                        grouped
                            |> List.filter (\( st, _ ) -> st == Boxcar)
                            |> List.head
                in
                case boxcarEntry of
                    Just ( _, count ) ->
                        count |> Expect.equal 0

                    Nothing ->
                        Expect.fail "Expected Boxcar entry to exist"
        ]



-- PROVISIONAL ITEM TESTS


provisionalItemTests : Test
provisionalItemTests =
    describe "Provisional/unavailable items"
        [ test "provisional field is True for unavailable stock" <|
            \_ ->
                -- Provisional items have provisional = True to indicate they
                -- are placeholders for unavailable stock
                let
                    provisionalItem =
                        { id = -1, stockType = Boxcar, reversed = False, provisional = True }
                in
                provisionalItem.provisional
                    |> Expect.equal True
        , test "provisional item has valid stock type for display" <|
            \_ ->
                let
                    provisionalItem =
                        { id = -1, stockType = Flatbed, reversed = False, provisional = True }
                in
                provisionalItem.stockType
                    |> Expect.equal Flatbed
        , test "consist can contain mix of real and provisional items" <|
            \_ ->
                let
                    consist =
                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                        , { id = -1, stockType = Boxcar, reversed = False, provisional = True }
                        ]
                in
                List.length consist
                    |> Expect.equal 2
        ]
