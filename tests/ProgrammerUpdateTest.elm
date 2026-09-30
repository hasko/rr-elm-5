module ProgrammerUpdateTest exposing (..)

import Expect
import Planning.Types exposing (..)
import Programmer.Types as PT exposing (Order(..), ReverserPosition(..), SpotTarget(..), emptyProgram)
import Programmer.Update exposing (..)
import Test exposing (..)
import Util.GameTime as GameTime



-- FIXTURES


loco : StockItem
loco =
    { id = 1, stockType = Locomotive, reversed = False, provisional = False }


boxcar : StockItem
boxcar =
    { id = 2, stockType = Boxcar, reversed = False, provisional = False }


existingProgram : PT.Program
existingProgram =
    [ SetReverser Forward, MoveTo "mill" TrainHead ]


{-| Planning state while editing train 5 (loaded into the builder).
-}
editingPlanning : PlanningState
editingPlanning =
    let
        initial =
            initPlanningState []
    in
    { initial
        | selectedSpawnPoint = "east"
        , consistBuilder = { items = [ loco, boxcar ], selectedStock = Nothing }
        , timePickerDay = 1
        , timePickerHour = 7
        , timePickerMinute = 45
        , editingTrainId = Just 5
        , editingTrainProgram = existingProgram
    }


{-| Planning state with the programmer open for train 5.
-}
openPlanning : PlanningState
openPlanning =
    openProgrammer 5 editingPlanning


{-| Programmer open with program [A, B, C].
-}
orderA : PT.Order
orderA =
    WaitSeconds 1


orderB : PT.Order
orderB =
    Couple


orderC : PT.Order
orderC =
    Uncouple 2


threeOrders : PlanningState
threeOrders =
    openProgrammer 5 { editingPlanning | editingTrainProgram = [ orderA, orderB, orderC ] }


programOf : PlanningState -> Maybe PT.Program
programOf planning =
    Maybe.map .program planning.programmerState


selectedIndexOf : PlanningState -> Maybe Int
selectedIndexOf planning =
    Maybe.andThen .selectedOrderIndex planning.programmerState



-- TESTS


suite : Test
suite =
    describe "Programmer.Update"
        [ openCloseTests
        , addRemoveTests
        , moveTests
        , selectTests
        , saveProgramTests
        , noProgrammerTests
        ]


openCloseTests : Test
openCloseTests =
    describe "openProgrammer / closeProgrammer"
        [ test "opens the programmer for the train being edited" <|
            \_ ->
                openPlanning
                    |> Expect.all
                        [ .panelMode >> Expect.equal (ProgrammerView 5)
                        , .programmerState
                            >> Expect.equal
                                (Just { trainId = 5, program = existingProgram, selectedOrderIndex = Nothing })
                        ]
        , test "does nothing for a train that is not being edited" <|
            \_ ->
                openProgrammer 6 editingPlanning
                    |> Expect.equal editingPlanning
        , test "does nothing when no train is being edited" <|
            \_ ->
                let
                    notEditing =
                        { editingPlanning | editingTrainId = Nothing }
                in
                openProgrammer 5 notEditing
                    |> Expect.equal notEditing
        , test "closeProgrammer returns to planning view and drops programmer state" <|
            \_ ->
                closeProgrammer openPlanning
                    |> Expect.all
                        [ .panelMode >> Expect.equal PlanningView
                        , .programmerState >> Expect.equal Nothing
                        ]
        , test "closeProgrammer keeps the train being edited" <|
            \_ ->
                closeProgrammer openPlanning
                    |> Expect.all
                        [ .editingTrainId >> Expect.equal (Just 5)
                        , .editingTrainProgram >> Expect.equal existingProgram
                        , .consistBuilder >> .items >> Expect.equal [ loco, boxcar ]
                        ]
        , test "closeProgrammer discards unsaved program changes" <|
            \_ ->
                openPlanning
                    |> addOrder Couple
                    |> closeProgrammer
                    |> .editingTrainProgram
                    |> Expect.equal existingProgram
        ]


addRemoveTests : Test
addRemoveTests =
    describe "addOrder / removeOrder"
        [ test "addOrder appends to the program" <|
            \_ ->
                addOrder Couple openPlanning
                    |> programOf
                    |> Expect.equal (Just (existingProgram ++ [ Couple ]))
        , test "addOrder to an empty program" <|
            \_ ->
                openProgrammer 5 { editingPlanning | editingTrainProgram = [] }
                    |> addOrder (WaitSeconds 3)
                    |> programOf
                    |> Expect.equal (Just [ WaitSeconds 3 ])
        , test "removeOrder removes the order at the index" <|
            \_ ->
                removeOrder 1 threeOrders
                    |> programOf
                    |> Expect.equal (Just [ orderA, orderC ])
        , test "removeOrder clears the selection" <|
            \_ ->
                threeOrders
                    |> selectProgramOrder 2
                    |> removeOrder 0
                    |> selectedIndexOf
                    |> Expect.equal Nothing
        , test "removeOrder with an out-of-range index keeps the program" <|
            \_ ->
                removeOrder 10 threeOrders
                    |> programOf
                    |> Expect.equal (Just [ orderA, orderB, orderC ])
        ]


moveTests : Test
moveTests =
    describe "moveOrderUp / moveOrderDown"
        [ test "moveOrderUp swaps with the previous order" <|
            \_ ->
                moveOrderUp 1 threeOrders
                    |> programOf
                    |> Expect.equal (Just [ orderB, orderA, orderC ])
        , test "moveOrderUp selects the moved order" <|
            \_ ->
                moveOrderUp 2 threeOrders
                    |> selectedIndexOf
                    |> Expect.equal (Just 1)
        , test "moveOrderUp on the first order does nothing" <|
            \_ ->
                moveOrderUp 0 threeOrders
                    |> Expect.equal threeOrders
        , test "moveOrderDown swaps with the next order" <|
            \_ ->
                moveOrderDown 1 threeOrders
                    |> programOf
                    |> Expect.equal (Just [ orderA, orderC, orderB ])
        , test "moveOrderDown selects the moved order" <|
            \_ ->
                moveOrderDown 0 threeOrders
                    |> selectedIndexOf
                    |> Expect.equal (Just 1)
        , test "moveOrderDown on the last order does nothing" <|
            \_ ->
                moveOrderDown 2 threeOrders
                    |> Expect.equal threeOrders
        , test "moveOrderDown past the end does nothing" <|
            \_ ->
                moveOrderDown 7 threeOrders
                    |> Expect.equal threeOrders
        , test "up then down restores the original order" <|
            \_ ->
                threeOrders
                    |> moveOrderUp 2
                    |> moveOrderDown 1
                    |> programOf
                    |> Expect.equal (Just [ orderA, orderB, orderC ])
        ]


selectTests : Test
selectTests =
    describe "selectProgramOrder"
        [ test "selects the given order index" <|
            \_ ->
                selectProgramOrder 2 threeOrders
                    |> selectedIndexOf
                    |> Expect.equal (Just 2)
        , test "selecting leaves the program unchanged" <|
            \_ ->
                selectProgramOrder 1 threeOrders
                    |> programOf
                    |> Expect.equal (Just [ orderA, orderB, orderC ])
        ]


saveProgramTests : Test
saveProgramTests =
    describe "saveProgram"
        [ test "saves the train with the edited program back to the schedule" <|
            \_ ->
                openPlanning
                    |> addOrder Couple
                    |> saveProgram
                    |> .scheduledTrains
                    |> Expect.equal
                        [ { id = 5
                          , spawnPoint = "east"
                          , departureTime = GameTime.fromDayHourMinute 1 7 45
                          , consist = [ loco, boxcar ]
                          , program = existingProgram ++ [ Couple ]
                          }
                        ]
        , test "closes the programmer and clears editing state" <|
            \_ ->
                saveProgram openPlanning
                    |> Expect.all
                        [ .panelMode >> Expect.equal PlanningView
                        , .programmerState >> Expect.equal Nothing
                        , .editingTrainId >> Expect.equal Nothing
                        , .editingTrainProgram >> Expect.equal emptyProgram
                        , .consistBuilder >> Expect.equal emptyConsistBuilder
                        ]
        , test "does nothing when the programmer is not open" <|
            \_ ->
                saveProgram editingPlanning
                    |> Expect.equal editingPlanning
        , test "does nothing when no train is being edited" <|
            \_ ->
                let
                    notEditing =
                        { openPlanning | editingTrainId = Nothing }
                in
                saveProgram notEditing
                    |> Expect.equal notEditing
        ]


noProgrammerTests : Test
noProgrammerTests =
    describe "order edits without an open programmer"
        [ test "addOrder is a no-op" <|
            \_ ->
                addOrder Couple editingPlanning
                    |> Expect.equal editingPlanning
        , test "removeOrder is a no-op" <|
            \_ ->
                removeOrder 0 editingPlanning
                    |> Expect.equal editingPlanning
        , test "moveOrderUp is a no-op" <|
            \_ ->
                moveOrderUp 1 editingPlanning
                    |> Expect.equal editingPlanning
        , test "moveOrderDown is a no-op" <|
            \_ ->
                moveOrderDown 0 editingPlanning
                    |> Expect.equal editingPlanning
        , test "selectProgramOrder is a no-op" <|
            \_ ->
                selectProgramOrder 0 editingPlanning
                    |> Expect.equal editingPlanning
        ]
