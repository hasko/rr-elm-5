module Planning.Helpers exposing
    ( takeStockFromInventory
    , returnStockToInventory
    , takeFirst
    )

{-| Helper functions for managing planning state and inventory.

These functions are extracted from Main.elm to make them testable.

-}

import Planning.Types exposing (..)


{-| Take one stock item of a given type from a spawn point's inventory.

Returns the taken item (if found) and the updated inventories.

-}
takeStockFromInventory : SpawnPointId -> StockType -> List SpawnPointInventory -> ( Maybe StockItem, List SpawnPointInventory )
takeStockFromInventory spawnId stockType inventories =
    let
        updateInventory inv =
            if inv.spawnPointId == spawnId then
                let
                    ( taken, remaining ) =
                        takeFirst (\s -> s.stockType == stockType) inv.availableStock
                in
                ( taken, { inv | availableStock = remaining } )

            else
                ( Nothing, inv )

        ( takenItems, newInventories ) =
            List.map updateInventory inventories
                |> List.unzip

        takenStock =
            takenItems |> List.filterMap identity |> List.head
    in
    ( takenStock, newInventories )


{-| Return stock items to a spawn point's inventory.

Adds the given items back to the inventory for the specified spawn point.

-}
returnStockToInventory : SpawnPointId -> List StockItem -> List SpawnPointInventory -> List SpawnPointInventory
returnStockToInventory spawnId items inventories =
    List.map
        (\inv ->
            if inv.spawnPointId == spawnId then
                { inv | availableStock = inv.availableStock ++ items }

            else
                inv
        )
        inventories


{-| Take the first item matching a predicate from a list.

Returns the matching item (if found) and the remaining list without that item.

-}
takeFirst : (a -> Bool) -> List a -> ( Maybe a, List a )
takeFirst predicate list =
    takeFirstHelper predicate [] list


{-| Helper function for takeFirst that accumulates the prefix.
-}
takeFirstHelper : (a -> Bool) -> List a -> List a -> ( Maybe a, List a )
takeFirstHelper predicate acc list =
    case list of
        [] ->
            ( Nothing, List.reverse acc )

        x :: xs ->
            if predicate x then
                ( Just x, List.reverse acc ++ xs )

            else
                takeFirstHelper predicate (x :: acc) xs
