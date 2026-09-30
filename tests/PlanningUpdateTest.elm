module PlanningUpdateTest exposing (..)

import Expect
import Planning.Types exposing (..)
import Planning.Update exposing (..)
import Programmer.Types exposing (Order(..), ReverserPosition(..))
import Test exposing (..)
import Util.GameTime as GameTime



-- FIXTURES


stock : Int -> StockType -> StockItem
stock id stockType =
    { id = id, stockType = stockType, reversed = False, provisional = False }


loco1 : StockItem
loco1 =
    stock 1 Locomotive


loco2 : StockItem
loco2 =
    stock 2 Locomotive


boxcar3 : StockItem
boxcar3 =
    stock 3 Boxcar


flatbed4 : StockItem
flatbed4 =
    stock 4 Flatbed


passenger10 : StockItem
passenger10 =
    stock 10 PassengerCar


{-| Two stations: "east" with two locos, a boxcar and a flatbed; "west" with a
passenger car.
-}
basePlanning : PlanningState
basePlanning =
    let
        initial =
            initPlanningState []
    in
    { initial
        | selectedSpawnPoint = "east"
        , inventories =
            [ { spawnPointId = "east", availableStock = [ loco1, loco2, boxcar3, flatbed4 ] }
            , { spawnPointId = "west", availableStock = [ passenger10 ] }
            ]
    }


inventoryOf : String -> PlanningState -> List StockItem
inventoryOf spawnId planning =
    planning.inventories
        |> List.filter (\inv -> inv.spawnPointId == spawnId)
        |> List.concatMap .availableStock


consistItems : PlanningState -> List StockItem
consistItems planning =
    planning.consistBuilder.items


{-| Select a stock type and add it to the back of the consist.
-}
addBack : StockType -> PlanningState -> PlanningState
addBack stockType planning =
    planning
        |> selectStockItem (stock 0 stockType)
        |> addToConsist False


{-| A planning state with consist [loco1, boxcar3] already built at "east".
-}
withLocoAndBoxcar : PlanningState
withLocoAndBoxcar =
    basePlanning
        |> addBack Locomotive
        |> addBack Boxcar


sampleProgram : Programmer.Types.Program
sampleProgram =
    [ SetReverser Forward, WaitSeconds 5 ]


{-| A planning state with one scheduled train (id 7) departing from "east".
-}
withScheduledTrain : PlanningState
withScheduledTrain =
    { basePlanning
        | inventories =
            [ { spawnPointId = "east", availableStock = [ loco2, flatbed4 ] }
            , { spawnPointId = "west", availableStock = [ passenger10 ] }
            ]
        , scheduledTrains =
            [ { id = 7
              , spawnPoint = "east"
              , departureTime = GameTime.fromDayHourMinute 1 8 30
              , consist = [ loco1, boxcar3 ]
              , program = sampleProgram
              }
            ]
        , nextTrainId = 8
    }



-- TESTS


suite : Test
suite =
    describe "Planning.Update"
        [ selectionTests
        , addToConsistTests
        , insertInConsistTests
        , removeFromConsistTests
        , clearConsistBuilderTests
        , flipLocoTests
        , consistDragTests
        , timePickerTests
        , scheduleTrainTests
        , selectScheduledTrainTests
        , removeScheduledTrainTests
        ]


selectionTests : Test
selectionTests =
    describe "selection"
        [ test "selectSpawnPoint changes the selected spawn point" <|
            \_ ->
                selectSpawnPoint "west" basePlanning
                    |> .selectedSpawnPoint
                    |> Expect.equal "west"
        , test "selectStockItem sets the selected stock in the builder" <|
            \_ ->
                selectStockItem boxcar3 basePlanning
                    |> .consistBuilder
                    |> .selectedStock
                    |> Expect.equal (Just boxcar3)
        , test "selectStockItem does not change consist items" <|
            \_ ->
                selectStockItem boxcar3 withLocoAndBoxcar
                    |> consistItems
                    |> Expect.equal [ loco1, boxcar3 ]
        ]


addToConsistTests : Test
addToConsistTests =
    describe "addToConsist"
        [ test "does nothing when no stock is selected" <|
            \_ ->
                addToConsist False basePlanning
                    |> Expect.equal basePlanning
        , test "adding to back appends the item" <|
            \_ ->
                withLocoAndBoxcar
                    |> consistItems
                    |> Expect.equal [ loco1, boxcar3 ]
        , test "adding to front prepends the item" <|
            \_ ->
                basePlanning
                    |> addBack Locomotive
                    |> selectStockItem (stock 0 Boxcar)
                    |> addToConsist True
                    |> consistItems
                    |> Expect.equal [ boxcar3, loco1 ]
        , test "takes the item from the selected station's inventory" <|
            \_ ->
                withLocoAndBoxcar
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4 ]
        , test "does not touch other stations' inventories" <|
            \_ ->
                withLocoAndBoxcar
                    |> inventoryOf "west"
                    |> Expect.equal [ passenger10 ]
        , test "keeps the stock selected after adding" <|
            \_ ->
                withLocoAndBoxcar
                    |> .consistBuilder
                    |> .selectedStock
                    |> Maybe.map .stockType
                    |> Expect.equal (Just Boxcar)
        , test "real stock does not consume a provisional id" <|
            \_ ->
                withLocoAndBoxcar
                    |> .nextProvisionalId
                    |> Expect.equal basePlanning.nextProvisionalId
        , test "creates a provisional item when inventory has none of that type" <|
            \_ ->
                basePlanning
                    |> addBack PassengerCar
                    |> consistItems
                    |> Expect.equal
                        [ { id = -1, stockType = PassengerCar, reversed = False, provisional = True } ]
        , test "provisional item decrements nextProvisionalId" <|
            \_ ->
                basePlanning
                    |> addBack PassengerCar
                    |> .nextProvisionalId
                    |> Expect.equal -2
        , test "successive provisional items get distinct decreasing ids" <|
            \_ ->
                basePlanning
                    |> addBack PassengerCar
                    |> addBack PassengerCar
                    |> consistItems
                    |> List.map .id
                    |> Expect.equal [ -1, -2 ]
        , test "provisional item leaves inventories unchanged" <|
            \_ ->
                basePlanning
                    |> addBack PassengerCar
                    |> .inventories
                    |> Expect.equal basePlanning.inventories
        , test "falls back to provisional once inventory of that type runs out" <|
            \_ ->
                basePlanning
                    |> addBack Boxcar
                    |> addBack Boxcar
                    |> consistItems
                    |> List.map (\s -> ( s.id, s.provisional ))
                    |> Expect.equal [ ( 3, False ), ( -1, True ) ]
        ]


insertInConsistTests : Test
insertInConsistTests =
    describe "insertInConsist"
        [ test "inserts at the given index" <|
            \_ ->
                withLocoAndBoxcar
                    |> selectStockItem (stock 0 Flatbed)
                    |> insertInConsist 1
                    |> consistItems
                    |> Expect.equal [ loco1, flatbed4, boxcar3 ]
        , test "index 0 inserts at the front" <|
            \_ ->
                withLocoAndBoxcar
                    |> selectStockItem (stock 0 Flatbed)
                    |> insertInConsist 0
                    |> consistItems
                    |> Expect.equal [ flatbed4, loco1, boxcar3 ]
        , test "index past the end appends" <|
            \_ ->
                withLocoAndBoxcar
                    |> selectStockItem (stock 0 Flatbed)
                    |> insertInConsist 99
                    |> consistItems
                    |> Expect.equal [ loco1, boxcar3, flatbed4 ]
        , test "takes the inserted item from inventory" <|
            \_ ->
                withLocoAndBoxcar
                    |> selectStockItem (stock 0 Flatbed)
                    |> insertInConsist 1
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2 ]
        , test "does nothing when no stock is selected" <|
            \_ ->
                insertInConsist 0 basePlanning
                    |> Expect.equal basePlanning
        , test "inserts a provisional item when inventory is empty" <|
            \_ ->
                withLocoAndBoxcar
                    |> selectStockItem (stock 0 PassengerCar)
                    |> insertInConsist 1
                    |> consistItems
                    |> List.map .provisional
                    |> Expect.equal [ False, True, False ]
        ]


removeFromConsistTests : Test
removeFromConsistTests =
    describe "removeFromConsist"
        [ test "removes the item at the index" <|
            \_ ->
                removeFromConsist 0 withLocoAndBoxcar
                    |> consistItems
                    |> Expect.equal [ boxcar3 ]
        , test "returns the removed stock to the selected station" <|
            \_ ->
                removeFromConsist 0 withLocoAndBoxcar
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4, loco1 ]
        , test "out-of-range index leaves state unchanged" <|
            \_ ->
                removeFromConsist 5 withLocoAndBoxcar
                    |> Expect.equal withLocoAndBoxcar
        , test "removing a provisional item does not add it to inventory" <|
            \_ ->
                let
                    withProvisional =
                        addBack PassengerCar basePlanning
                in
                removeFromConsist 0 withProvisional
                    |> Expect.all
                        [ consistItems >> Expect.equal []
                        , .inventories >> Expect.equal basePlanning.inventories
                        ]
        ]


clearConsistBuilderTests : Test
clearConsistBuilderTests =
    describe "clearConsistBuilder"
        [ test "empties the builder" <|
            \_ ->
                clearConsistBuilder withLocoAndBoxcar
                    |> .consistBuilder
                    |> Expect.equal emptyConsistBuilder
        , test "returns all stock to the selected station" <|
            \_ ->
                clearConsistBuilder withLocoAndBoxcar
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4, loco1, boxcar3 ]
        , test "resets editingTrainId" <|
            \_ ->
                clearConsistBuilder { withLocoAndBoxcar | editingTrainId = Just 3 }
                    |> .editingTrainId
                    |> Expect.equal Nothing
        , test "resets consistPanOffset" <|
            \_ ->
                clearConsistBuilder { withLocoAndBoxcar | consistPanOffset = 42 }
                    |> .consistPanOffset
                    |> Expect.within (Expect.Absolute 0.0001) 0
        , test "provisional items are discarded, not returned" <|
            \_ ->
                basePlanning
                    |> addBack PassengerCar
                    |> clearConsistBuilder
                    |> .inventories
                    |> Expect.equal basePlanning.inventories
        ]


flipLocoTests : Test
flipLocoTests =
    describe "flipLocoInConsist"
        [ test "flips a locomotive" <|
            \_ ->
                flipLocoInConsist 0 withLocoAndBoxcar
                    |> consistItems
                    |> List.map .reversed
                    |> Expect.equal [ True, False ]
        , test "flipping twice restores the original orientation" <|
            \_ ->
                withLocoAndBoxcar
                    |> flipLocoInConsist 0
                    |> flipLocoInConsist 0
                    |> consistItems
                    |> Expect.equal [ loco1, boxcar3 ]
        , test "does not flip non-locomotive stock" <|
            \_ ->
                flipLocoInConsist 1 withLocoAndBoxcar
                    |> consistItems
                    |> Expect.equal [ loco1, boxcar3 ]
        , test "out-of-range index changes nothing" <|
            \_ ->
                flipLocoInConsist 9 withLocoAndBoxcar
                    |> Expect.equal withLocoAndBoxcar
        ]


consistDragTests : Test
consistDragTests =
    describe "consist drag"
        [ test "startConsistDrag records start position and current offset" <|
            \_ ->
                startConsistDrag 100 { basePlanning | consistPanOffset = 20 }
                    |> .consistDragState
                    |> Expect.equal (Just { startX = 100, startOffset = 20 })
        , test "moveConsistDrag pans by the pointer delta from the start offset" <|
            \_ ->
                { basePlanning | consistPanOffset = 20 }
                    |> startConsistDrag 100
                    |> moveConsistDrag 130
                    |> .consistPanOffset
                    |> Expect.within (Expect.Absolute 0.0001) 50
        , test "successive moves are relative to the drag start, not cumulative" <|
            \_ ->
                { basePlanning | consistPanOffset = 20 }
                    |> startConsistDrag 100
                    |> moveConsistDrag 130
                    |> moveConsistDrag 90
                    |> .consistPanOffset
                    |> Expect.within (Expect.Absolute 0.0001) 10
        , test "moveConsistDrag without an active drag does nothing" <|
            \_ ->
                moveConsistDrag 130 basePlanning
                    |> Expect.equal basePlanning
        , test "endConsistDrag clears drag state but keeps the offset" <|
            \_ ->
                basePlanning
                    |> startConsistDrag 100
                    |> moveConsistDrag 60
                    |> endConsistDrag
                    |> Expect.all
                        [ .consistDragState >> Expect.equal Nothing
                        , .consistPanOffset >> Expect.within (Expect.Absolute 0.0001) -40
                        ]
        , test "moves after endConsistDrag are ignored" <|
            \_ ->
                basePlanning
                    |> startConsistDrag 100
                    |> moveConsistDrag 60
                    |> endConsistDrag
                    |> moveConsistDrag 500
                    |> .consistPanOffset
                    |> Expect.within (Expect.Absolute 0.0001) -40
        ]


timePickerTests : Test
timePickerTests =
    describe "time picker"
        [ test "setTimePickerHour" <|
            \_ ->
                setTimePickerHour 14 basePlanning
                    |> .timePickerHour
                    |> Expect.equal 14
        , test "setTimePickerMinute" <|
            \_ ->
                setTimePickerMinute 45 basePlanning
                    |> .timePickerMinute
                    |> Expect.equal 45
        , test "setTimePickerDay" <|
            \_ ->
                setTimePickerDay 3 basePlanning
                    |> .timePickerDay
                    |> Expect.equal 3
        ]


scheduleTrainTests : Test
scheduleTrainTests =
    describe "scheduleTrain"
        [ test "rejects an empty consist" <|
            \_ ->
                scheduleTrain basePlanning
                    |> Expect.equal basePlanning
        , test "rejects a consist without a locomotive" <|
            \_ ->
                let
                    noLoco =
                        addBack Boxcar basePlanning
                in
                scheduleTrain noLoco
                    |> Expect.equal noLoco
        , test "schedules a new train with the builder consist and picker time" <|
            \_ ->
                withLocoAndBoxcar
                    |> setTimePickerDay 2
                    |> setTimePickerHour 9
                    |> setTimePickerMinute 15
                    |> scheduleTrain
                    |> .scheduledTrains
                    |> Expect.equal
                        [ { id = 1
                          , spawnPoint = "east"
                          , departureTime = GameTime.fromDayHourMinute 2 9 15
                          , consist = [ loco1, boxcar3 ]
                          , program = []
                          }
                        ]
        , test "new train increments nextTrainId" <|
            \_ ->
                scheduleTrain withLocoAndBoxcar
                    |> .nextTrainId
                    |> Expect.equal 2
        , test "clears the builder after scheduling" <|
            \_ ->
                scheduleTrain withLocoAndBoxcar
                    |> .consistBuilder
                    |> Expect.equal emptyConsistBuilder
        , test "scheduled stock is not returned to inventory" <|
            \_ ->
                scheduleTrain withLocoAndBoxcar
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4 ]
        , test "second new train gets the next id" <|
            \_ ->
                withLocoAndBoxcar
                    |> scheduleTrain
                    |> addBack Locomotive
                    |> scheduleTrain
                    |> .scheduledTrains
                    |> List.map .id
                    |> Expect.equal [ 1, 2 ]
        , test "editing path reuses the train id and program" <|
            \_ ->
                withScheduledTrain
                    |> selectScheduledTrain 7
                    |> scheduleTrain
                    |> .scheduledTrains
                    |> List.map (\t -> ( t.id, t.program ))
                    |> Expect.equal [ ( 7, sampleProgram ) ]
        , test "editing path does not increment nextTrainId" <|
            \_ ->
                withScheduledTrain
                    |> selectScheduledTrain 7
                    |> scheduleTrain
                    |> .nextTrainId
                    |> Expect.equal 8
        , test "editing path clears editing state" <|
            \_ ->
                withScheduledTrain
                    |> selectScheduledTrain 7
                    |> scheduleTrain
                    |> Expect.all
                        [ .editingTrainId >> Expect.equal Nothing
                        , .editingTrainProgram >> Expect.equal []
                        , .consistBuilder >> Expect.equal emptyConsistBuilder
                        ]
        , test "editing path saves changed consist and time" <|
            \_ ->
                withScheduledTrain
                    |> selectScheduledTrain 7
                    |> selectStockItem (stock 0 Flatbed)
                    |> addToConsist False
                    |> setTimePickerHour 10
                    |> scheduleTrain
                    |> .scheduledTrains
                    |> List.map (\t -> ( t.consist, t.departureTime ))
                    |> Expect.equal [ ( [ loco1, boxcar3, flatbed4 ], GameTime.fromDayHourMinute 1 10 30 ) ]
        ]


selectScheduledTrainTests : Test
selectScheduledTrainTests =
    describe "selectScheduledTrain"
        [ test "unknown train id leaves state unchanged" <|
            \_ ->
                selectScheduledTrain 99 withScheduledTrain
                    |> Expect.equal withScheduledTrain
        , test "loads the train's consist into the builder" <|
            \_ ->
                selectScheduledTrain 7 withScheduledTrain
                    |> .consistBuilder
                    |> Expect.equal { items = [ loco1, boxcar3 ], selectedStock = Nothing }
        , test "loads the departure time into the picker" <|
            \_ ->
                selectScheduledTrain 7 withScheduledTrain
                    |> (\p -> ( p.timePickerDay, p.timePickerHour, p.timePickerMinute ))
                    |> Expect.equal ( 1, 8, 30 )
        , test "sets editing train id and program" <|
            \_ ->
                selectScheduledTrain 7 withScheduledTrain
                    |> Expect.all
                        [ .editingTrainId >> Expect.equal (Just 7)
                        , .editingTrainProgram >> Expect.equal sampleProgram
                        ]
        , test "selects the train's spawn point" <|
            \_ ->
                selectScheduledTrain 7 { withScheduledTrain | selectedSpawnPoint = "west" }
                    |> .selectedSpawnPoint
                    |> Expect.equal "east"
        , test "removes the train from the scheduled list while editing" <|
            \_ ->
                selectScheduledTrain 7 withScheduledTrain
                    |> .scheduledTrains
                    |> Expect.equal []
        , test "does not return the train's stock to inventory" <|
            \_ ->
                selectScheduledTrain 7 withScheduledTrain
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4 ]
        , test "returns items already in the builder to the previously selected station" <|
            \_ ->
                withScheduledTrain
                    |> selectSpawnPoint "west"
                    |> selectStockItem (stock 0 PassengerCar)
                    |> addToConsist False
                    |> selectScheduledTrain 7
                    |> inventoryOf "west"
                    |> Expect.equal [ passenger10 ]
        ]


removeScheduledTrainTests : Test
removeScheduledTrainTests =
    describe "removeScheduledTrain"
        [ test "removes the train from the schedule" <|
            \_ ->
                removeScheduledTrain 7 withScheduledTrain
                    |> .scheduledTrains
                    |> Expect.equal []
        , test "returns the train's stock to its spawn point" <|
            \_ ->
                removeScheduledTrain 7 { withScheduledTrain | selectedSpawnPoint = "west" }
                    |> inventoryOf "east"
                    |> Expect.equal [ loco2, flatbed4, loco1, boxcar3 ]
        , test "unknown train id leaves state unchanged" <|
            \_ ->
                removeScheduledTrain 99 withScheduledTrain
                    |> Expect.equal withScheduledTrain
        , test "only removes the matching train" <|
            \_ ->
                withScheduledTrain
                    |> addBack Locomotive
                    |> scheduleTrain
                    |> removeScheduledTrain 7
                    |> .scheduledTrains
                    |> List.map .id
                    |> Expect.equal [ 8 ]
        ]
