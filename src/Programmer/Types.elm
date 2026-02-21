module Programmer.Types exposing
    ( SpotTarget(..)
    , ReverserPosition(..)
    , SwitchPosition(..)
    , Order(..)
    , Program
    , ProgrammerState
    , emptyProgram
    , initProgrammerState
    , orderDescription
    )

{-| Types for the train programmer system.
-}


{-| Reverser positions for locomotive direction control.
-}
type ReverserPosition
    = Forward
    | Reverse


{-| Switch/turnout positions.
-}
type SwitchPosition
    = Normal
    | Diverging


{-| Target specification for a MoveTo order.
TrainHead = position train head at spot (default, backward compatible).
SpotCar Int = position the center of car at given 0-based index at the spot.
-}
type SpotTarget
    = TrainHead
    | SpotCar Int


{-| Train orders - explicit commands that trains execute sequentially.
Spot IDs are strings matching scenario spot IDs or portal node IDs.
-}
type Order
    = MoveTo String SpotTarget
    | SetReverser ReverserPosition
    | SetSwitch String SwitchPosition
    | WaitSeconds Int
    | Couple
    | Uncouple Int


{-| A program is a sequence of orders.
-}
type alias Program =
    List Order


{-| State for the programmer UI.
-}
type alias ProgrammerState =
    { trainId : Int
    , program : Program
    , selectedOrderIndex : Maybe Int
    }


{-| Empty program.
-}
emptyProgram : Program
emptyProgram =
    []


{-| Initialize programmer state for a train.
-}
initProgrammerState : Int -> Program -> ProgrammerState
initProgrammerState trainId existingProgram =
    { trainId = trainId
    , program = existingProgram
    , selectedOrderIndex = Nothing
    }


{-| Get description for an order.
The spotName function is passed in to resolve spot ID strings to display names.
-}
orderDescription : (String -> String) -> Order -> String
orderDescription spotNameFn order =
    case order of
        MoveTo spotId target ->
            case target of
                TrainHead ->
                    "Move To " ++ spotNameFn spotId

                SpotCar carIndex ->
                    "Spot Car " ++ String.fromInt (carIndex + 1) ++ " at " ++ spotNameFn spotId

        SetReverser Forward ->
            "Set Reverser Forward"

        SetReverser Reverse ->
            "Set Reverser Reverse"

        SetSwitch switchId Normal ->
            "Set " ++ switchId ++ " Normal"

        SetSwitch switchId Diverging ->
            "Set " ++ switchId ++ " Diverging"

        WaitSeconds n ->
            "Wait " ++ String.fromInt n ++ " seconds"

        Couple ->
            "Couple"

        Uncouple n ->
            "Uncouple (keep " ++ String.fromInt n ++ ")"
