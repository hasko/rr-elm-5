module Programmer.Types exposing
    ( SpotId(..)
    , ReverserPosition(..)
    , SwitchPosition(..)
    , Order(..)
    , Program
    , ProgrammerState
    , emptyProgram
    , initProgrammerState
    , orderDescription
    , spotName
    )

{-| Types for the train programmer system.
-}


{-| Named spots that can be targets for MoveTo orders.
-}
type SpotId
    = PlatformSpot
    | TeamTrackSpot
    | EastTunnelSpot
    | WestTunnelSpot


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


{-| Train orders - explicit commands that trains execute sequentially.
-}
type Order
    = MoveTo SpotId
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


{-| Get display name for a spot.
-}
spotName : SpotId -> String
spotName spot =
    case spot of
        PlatformSpot ->
            "Platform"

        TeamTrackSpot ->
            "Team Track"

        EastTunnelSpot ->
            "East Tunnel"

        WestTunnelSpot ->
            "West Tunnel"


{-| Get description for an order.
-}
orderDescription : Order -> String
orderDescription order =
    case order of
        MoveTo spot ->
            "Move To " ++ spotName spot

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
