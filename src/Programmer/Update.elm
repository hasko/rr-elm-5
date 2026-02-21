module Programmer.Update exposing
    ( addOrder
    , closeProgrammer
    , moveOrderDown
    , moveOrderUp
    , openProgrammer
    , removeOrder
    , saveProgram
    , selectProgramOrder
    )

{-| Update logic for the train programmer: order manipulation and program save.
-}

import Planning.Types exposing (..)
import Programmer.Types as Programmer
import Util.GameTime as GameTime
import Util.List


{-| Open the programmer for a train.
-}
openProgrammer : Int -> PlanningState -> PlanningState
openProgrammer trainId planning =
    -- Only open programmer if we're editing this train
    case planning.editingTrainId of
        Just editId ->
            if editId == trainId then
                { planning
                    | panelMode = ProgrammerView trainId
                    , programmerState =
                        Just (Programmer.initProgrammerState trainId planning.editingTrainProgram)
                }

            else
                planning

        Nothing ->
            planning


{-| Close the programmer without saving.
-}
closeProgrammer : PlanningState -> PlanningState
closeProgrammer planning =
    { planning
        | panelMode = PlanningView
        , programmerState = Nothing
    }


{-| Save the program and close the programmer.
This also saves the entire train back to scheduledTrains.
-}
saveProgram : PlanningState -> PlanningState
saveProgram planning =
    case ( planning.programmerState, planning.editingTrainId ) of
        ( Just progState, Just trainId ) ->
            let
                -- Reconstruct the train with current editing data and new program
                savedTrain =
                    { id = trainId
                    , spawnPoint = planning.selectedSpawnPoint
                    , departureTime = GameTime.fromDayHourMinute planning.timePickerDay planning.timePickerHour planning.timePickerMinute
                    , consist = planning.consistBuilder.items
                    , program = progState.program
                    }
            in
            { planning
                | scheduledTrains = planning.scheduledTrains ++ [ savedTrain ]
                , consistBuilder = emptyConsistBuilder
                , editingTrainId = Nothing
                , editingTrainProgram = Programmer.emptyProgram
                , panelMode = PlanningView
                , programmerState = Nothing
            }

        _ ->
            planning


{-| Add an order to the program.
-}
addOrder : Programmer.Order -> PlanningState -> PlanningState
addOrder order planning =
    updateProgrammerState planning
        (\progState ->
            { progState | program = progState.program ++ [ order ] }
        )


{-| Remove an order from the program.
-}
removeOrder : Int -> PlanningState -> PlanningState
removeOrder index planning =
    updateProgrammerState planning
        (\progState ->
            { progState
                | program = Util.List.removeAt index progState.program
                , selectedOrderIndex = Nothing
            }
        )


{-| Move an order up in the program.
-}
moveOrderUp : Int -> PlanningState -> PlanningState
moveOrderUp index planning =
    if index > 0 then
        updateProgrammerState planning
            (\progState ->
                { progState
                    | program = Util.List.swapAt (index - 1) index progState.program
                    , selectedOrderIndex = Just (index - 1)
                }
            )

    else
        planning


{-| Move an order down in the program.
-}
moveOrderDown : Int -> PlanningState -> PlanningState
moveOrderDown index planning =
    updateProgrammerState planning
        (\progState ->
            if index < List.length progState.program - 1 then
                { progState
                    | program = Util.List.swapAt index (index + 1) progState.program
                    , selectedOrderIndex = Just (index + 1)
                }

            else
                progState
        )


{-| Select an order in the program.
-}
selectProgramOrder : Int -> PlanningState -> PlanningState
selectProgramOrder index planning =
    updateProgrammerState planning
        (\progState ->
            { progState | selectedOrderIndex = Just index }
        )


{-| Helper to update programmer state within planning state.
-}
updateProgrammerState : PlanningState -> (Programmer.ProgrammerState -> Programmer.ProgrammerState) -> PlanningState
updateProgrammerState planning updater =
    case planning.programmerState of
        Nothing ->
            planning

        Just progState ->
            { planning
                | programmerState = Just (updater progState)
            }
