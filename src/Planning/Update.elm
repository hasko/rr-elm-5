module Planning.Update exposing
    ( addToConsist
    , insertInConsist
    , removeFromConsist
    , removeScheduledTrain
    , scheduleTrain
    , selectScheduledTrain
    )

{-| Update logic for planning state: consist builder and train scheduling.
-}

import Planning.Helpers exposing (returnStockToInventory, takeStockFromInventory)
import Planning.Types exposing (..)
import Programmer.Types as Programmer
import Util.GameTime as GameTime


{-| Add selected stock item to consist (front or back).
-}
addToConsist : Bool -> PlanningState -> PlanningState
addToConsist toFront planning =
    let
        builder =
            planning.consistBuilder
    in
    case builder.selectedStock of
        Nothing ->
            planning

        Just selectedStock ->
            let
                -- Try to take one item of this type from inventory
                ( maybeActualStock, newInventories ) =
                    takeStockFromInventory planning.selectedSpawnPoint selectedStock.stockType planning.inventories

                -- If not available, create a provisional item
                ( stockToAdd, finalInventories, finalProvisionalId ) =
                    case maybeActualStock of
                        Just actualStock ->
                            ( actualStock, newInventories, planning.nextProvisionalId )

                        Nothing ->
                            ( { id = planning.nextProvisionalId
                              , stockType = selectedStock.stockType
                              , reversed = False
                              , provisional = True
                              }
                            , planning.inventories
                            , planning.nextProvisionalId - 1
                            )

                -- Add to front or back
                newItems =
                    if toFront then
                        stockToAdd :: builder.items

                    else
                        builder.items ++ [ stockToAdd ]

                newBuilder =
                    { builder | items = newItems, selectedStock = builder.selectedStock }
            in
            { planning
                | consistBuilder = newBuilder
                , inventories = finalInventories
                , nextProvisionalId = finalProvisionalId
            }


{-| Insert selected stock into consist at specified index.
-}
insertInConsist : Int -> PlanningState -> PlanningState
insertInConsist index planning =
    let
        builder =
            planning.consistBuilder
    in
    case builder.selectedStock of
        Nothing ->
            planning

        Just selectedStock ->
            let
                -- Try to take one item of this type from inventory
                ( maybeActualStock, newInventories ) =
                    takeStockFromInventory planning.selectedSpawnPoint selectedStock.stockType planning.inventories

                -- If not available, create a provisional item
                ( stockToAdd, finalInventories, finalProvisionalId ) =
                    case maybeActualStock of
                        Just actualStock ->
                            ( actualStock, newInventories, planning.nextProvisionalId )

                        Nothing ->
                            ( { id = planning.nextProvisionalId
                              , stockType = selectedStock.stockType
                              , reversed = False
                              , provisional = True
                              }
                            , planning.inventories
                            , planning.nextProvisionalId - 1
                            )

                -- Insert at specified index
                newItems =
                    List.take index builder.items
                        ++ [ stockToAdd ]
                        ++ List.drop index builder.items

                newBuilder =
                    { builder | items = newItems, selectedStock = builder.selectedStock }
            in
            { planning
                | consistBuilder = newBuilder
                , inventories = finalInventories
                , nextProvisionalId = finalProvisionalId
            }


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
