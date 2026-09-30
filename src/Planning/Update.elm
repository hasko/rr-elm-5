module Planning.Update exposing
    ( addToConsist
    , clearConsistBuilder
    , endConsistDrag
    , flipLocoInConsist
    , insertInConsist
    , moveConsistDrag
    , removeFromConsist
    , removeScheduledTrain
    , scheduleTrain
    , selectScheduledTrain
    , selectSpawnPoint
    , selectStockItem
    , setTimePickerDay
    , setTimePickerHour
    , setTimePickerMinute
    , startConsistDrag
    )

{-| Update logic for planning state: consist builder and train scheduling.
-}

import Planning.Helpers exposing (returnStockToInventory, takeStockFromInventory)
import Planning.Types exposing (PlanningState, StockItem, StockType(..), emptyConsistBuilder)
import Programmer.Types as Programmer
import Util.GameTime as GameTime


{-| Switch the station whose inventory the consist builder draws from.
-}
selectSpawnPoint : String -> PlanningState -> PlanningState
selectSpawnPoint spawnId planning =
    { planning | selectedSpawnPoint = spawnId }


{-| Pick a stock type to place into the consist.
-}
selectStockItem : StockItem -> PlanningState -> PlanningState
selectStockItem stock planning =
    let
        builder =
            planning.consistBuilder
    in
    { planning | consistBuilder = { builder | selectedStock = Just stock } }


{-| Add selected stock item to consist (front or back).
-}
addToConsist : Bool -> PlanningState -> PlanningState
addToConsist toFront =
    placeSelectedStock
        (\stock items ->
            if toFront then
                stock :: items

            else
                items ++ [ stock ]
        )


{-| Insert selected stock into consist at specified index.
-}
insertInConsist : Int -> PlanningState -> PlanningState
insertInConsist index =
    placeSelectedStock
        (\stock items -> List.take index items ++ stock :: List.drop index items)


{-| Take one of the selected stock type from the station inventory (or create
a provisional item if none is available) and place it with `place`.
-}
placeSelectedStock : (StockItem -> List StockItem -> List StockItem) -> PlanningState -> PlanningState
placeSelectedStock place planning =
    let
        builder =
            planning.consistBuilder
    in
    case builder.selectedStock of
        Nothing ->
            planning

        Just selectedStock ->
            let
                ( stockToAdd, finalInventories, finalProvisionalId ) =
                    case takeStockFromInventory planning.selectedSpawnPoint selectedStock.stockType planning.inventories of
                        ( Just actualStock, newInventories ) ->
                            ( actualStock, newInventories, planning.nextProvisionalId )

                        ( Nothing, _ ) ->
                            ( { id = planning.nextProvisionalId
                              , stockType = selectedStock.stockType
                              , reversed = False
                              , provisional = True
                              }
                            , planning.inventories
                            , planning.nextProvisionalId - 1
                            )
            in
            { planning
                | consistBuilder = { builder | items = place stockToAdd builder.items }
                , inventories = finalInventories
                , nextProvisionalId = finalProvisionalId
            }


{-| Return all stock in the builder to inventory and reset the builder.
-}
clearConsistBuilder : PlanningState -> PlanningState
clearConsistBuilder planning =
    { planning
        | consistBuilder = emptyConsistBuilder
        , inventories = returnStockToInventory planning.selectedSpawnPoint planning.consistBuilder.items planning.inventories
        , editingTrainId = Nothing
        , consistPanOffset = 0
    }


{-| Turn a locomotive in the consist around. Other stock is unaffected.
-}
flipLocoInConsist : Int -> PlanningState -> PlanningState
flipLocoInConsist index planning =
    let
        builder =
            planning.consistBuilder

        newItems =
            List.indexedMap
                (\i item ->
                    if i == index && item.stockType == Locomotive then
                        { item | reversed = not item.reversed }

                    else
                        item
                )
                builder.items
    in
    { planning | consistBuilder = { builder | items = newItems } }


{-| Begin panning the consist strip at the given screen X.
-}
startConsistDrag : Float -> PlanningState -> PlanningState
startConsistDrag screenX planning =
    { planning
        | consistDragState =
            Just
                { startX = screenX
                , startOffset = planning.consistPanOffset
                }
    }


{-| Pan the consist strip to follow the pointer, if a drag is in progress.
-}
moveConsistDrag : Float -> PlanningState -> PlanningState
moveConsistDrag screenX planning =
    case planning.consistDragState of
        Just drag ->
            { planning | consistPanOffset = drag.startOffset + screenX - drag.startX }

        Nothing ->
            planning


{-| Finish panning the consist strip.
-}
endConsistDrag : PlanningState -> PlanningState
endConsistDrag planning =
    { planning | consistDragState = Nothing }


{-| Set the departure hour in the time picker.
-}
setTimePickerHour : Int -> PlanningState -> PlanningState
setTimePickerHour hour planning =
    { planning | timePickerHour = hour }


{-| Set the departure minute in the time picker.
-}
setTimePickerMinute : Int -> PlanningState -> PlanningState
setTimePickerMinute minute planning =
    { planning | timePickerMinute = minute }


{-| Set the departure day in the time picker.
-}
setTimePickerDay : Int -> PlanningState -> PlanningState
setTimePickerDay day planning =
    { planning | timePickerDay = day }


{-| Remove stock from consist at index and return to inventory.
-}
removeFromConsist : Int -> PlanningState -> PlanningState
removeFromConsist index planning =
    let
        builder =
            planning.consistBuilder

        maybeStock =
            builder.items
                |> List.drop index
                |> List.head
    in
    case maybeStock of
        Nothing ->
            planning

        Just stock ->
            let
                newItems =
                    List.take index builder.items ++ List.drop (index + 1) builder.items

                newInventories =
                    returnStockToInventory planning.selectedSpawnPoint [ stock ] planning.inventories

                newBuilder =
                    { builder | items = newItems }
            in
            { planning
                | consistBuilder = newBuilder
                , inventories = newInventories
            }


{-| Schedule a train with the current consist (or update existing train).
-}
scheduleTrain : PlanningState -> PlanningState
scheduleTrain planning =
    let
        builder =
            planning.consistBuilder

        -- Extract consist from builder items
        consist =
            builder.items

        -- Check validation: must have items and at least one locomotive
        hasLoco =
            List.any (\item -> item.stockType == Locomotive) consist
    in
    if List.isEmpty consist || not hasLoco then
        -- Don't schedule empty trains or trains without locomotive
        planning

    else
        case planning.editingTrainId of
            Just trainId ->
                -- Update existing train - recreate it with new data
                let
                    updatedTrain =
                        { id = trainId
                        , spawnPoint = planning.selectedSpawnPoint
                        , departureTime = GameTime.fromDayHourMinute planning.timePickerDay planning.timePickerHour planning.timePickerMinute
                        , consist = consist
                        , program = planning.editingTrainProgram
                        }
                in
                { planning
                    | scheduledTrains = planning.scheduledTrains ++ [ updatedTrain ]
                    , consistBuilder = emptyConsistBuilder
                    , editingTrainId = Nothing
                    , editingTrainProgram = Programmer.emptyProgram
                }

            Nothing ->
                -- Create new train
                let
                    newTrain =
                        { id = planning.nextTrainId
                        , spawnPoint = planning.selectedSpawnPoint
                        , departureTime = GameTime.fromDayHourMinute planning.timePickerDay planning.timePickerHour planning.timePickerMinute
                        , consist = consist
                        , program = Programmer.emptyProgram
                        }
                in
                { planning
                    | scheduledTrains = planning.scheduledTrains ++ [ newTrain ]
                    , consistBuilder = emptyConsistBuilder
                    , nextTrainId = planning.nextTrainId + 1
                }


{-| Load a scheduled train into the consist builder for editing.
-}
selectScheduledTrain : Int -> PlanningState -> PlanningState
selectScheduledTrain trainId planning =
    let
        maybeTrain =
            planning.scheduledTrains
                |> List.filter (\t -> t.id == trainId)
                |> List.head
    in
    case maybeTrain of
        Nothing ->
            planning

        Just train ->
            let
                -- First return any current builder items to inventory
                currentItems =
                    planning.consistBuilder.items

                newInventories =
                    returnStockToInventory planning.selectedSpawnPoint currentItems planning.inventories

                -- Keep train in scheduled list but mark as being edited
                -- Stock remains "in use" by the train, not returned to inventory
                newTrains =
                    planning.scheduledTrains
                        |> List.filter (\t -> t.id /= trainId)

                -- Load consist into builder
                newBuilder =
                    { items = train.consist
                    , selectedStock = Nothing
                    }

                ( pickerDay, pickerHour, pickerMinute ) =
                    GameTime.toDayHourMinute train.departureTime
            in
            { planning
                | selectedSpawnPoint = train.spawnPoint
                , scheduledTrains = newTrains
                , inventories = newInventories
                , consistBuilder = newBuilder
                , timePickerDay = pickerDay
                , timePickerHour = pickerHour
                , timePickerMinute = pickerMinute
                , editingTrainId = Just trainId
                , editingTrainProgram = train.program
            }


{-| Remove a scheduled train and return its stock to inventory.
-}
removeScheduledTrain : Int -> PlanningState -> PlanningState
removeScheduledTrain trainId planning =
    let
        maybeTrain =
            planning.scheduledTrains
                |> List.filter (\t -> t.id == trainId)
                |> List.head
    in
    case maybeTrain of
        Nothing ->
            planning

        Just train ->
            let
                newTrains =
                    planning.scheduledTrains
                        |> List.filter (\t -> t.id /= trainId)

                newInventories =
                    returnStockToInventory train.spawnPoint train.consist planning.inventories
            in
            { planning
                | scheduledTrains = newTrains
                , inventories = newInventories
            }
