module ProgrammerTypesTest exposing (..)

import Expect
import Programmer.Types exposing (..)
import Test exposing (..)


{-| A simple spot name function for tests that maps IDs to display names.
-}
testSpotName : String -> String
testSpotName spotId =
    case spotId of
        "platform" ->
            "Platform"

        "team-track" ->
            "Team Track"

        "e-portal" ->
            "East Tunnel"

        "w-portal" ->
            "West Tunnel"

        other ->
            other


suite : Test
suite =
    describe "Programmer.Types"
        [ describe "orderDescription"
            [ test "MoveTo platform shows correct description" <|
                \_ ->
                    orderDescription testSpotName (MoveTo "platform" TrainHead)
                        |> Expect.equal "Move To Platform"
            , test "MoveTo team-track shows correct description" <|
                \_ ->
                    orderDescription testSpotName (MoveTo "team-track" TrainHead)
                        |> Expect.equal "Move To Team Track"
            , test "MoveTo east portal shows correct description" <|
                \_ ->
                    orderDescription testSpotName (MoveTo "e-portal" TrainHead)
                        |> Expect.equal "Move To East Tunnel"
            , test "MoveTo west portal shows correct description" <|
                \_ ->
                    orderDescription testSpotName (MoveTo "w-portal" TrainHead)
                        |> Expect.equal "Move To West Tunnel"
            , test "SetReverser Forward shows correct description" <|
                \_ ->
                    orderDescription testSpotName (SetReverser Forward)
                        |> Expect.equal "Set Reverser Forward"
            , test "SetReverser Reverse shows correct description" <|
                \_ ->
                    orderDescription testSpotName (SetReverser Reverse)
                        |> Expect.equal "Set Reverser Reverse"
            , test "SetSwitch Normal shows correct description" <|
                \_ ->
                    orderDescription testSpotName (SetSwitch "main" Normal)
                        |> Expect.equal "Set main Normal"
            , test "SetSwitch Diverging shows correct description" <|
                \_ ->
                    orderDescription testSpotName (SetSwitch "siding" Diverging)
                        |> Expect.equal "Set siding Diverging"
            , test "WaitSeconds shows correct description" <|
                \_ ->
                    orderDescription testSpotName (WaitSeconds 30)
                        |> Expect.equal "Wait 30 seconds"
            , test "Couple shows correct description" <|
                \_ ->
                    orderDescription testSpotName Couple
                        |> Expect.equal "Couple"
            , test "Uncouple 1 shows correct description" <|
                \_ ->
                    orderDescription testSpotName (Uncouple 1)
                        |> Expect.equal "Uncouple (keep 1)"
            , test "Uncouple 3 shows correct description" <|
                \_ ->
                    orderDescription testSpotName (Uncouple 3)
                        |> Expect.equal "Uncouple (keep 3)"
            ]
        , describe "emptyProgram"
            [ test "emptyProgram is an empty list" <|
                \_ ->
                    emptyProgram
                        |> Expect.equal []
            ]
        , describe "initProgrammerState"
            [ test "initializes with given trainId" <|
                \_ ->
                    let
                        state =
                            initProgrammerState 42 []
                    in
                    state.trainId
                        |> Expect.equal 42
            , test "initializes with given program" <|
                \_ ->
                    let
                        program =
                            [ SetReverser Forward, MoveTo "platform" TrainHead ]

                        state =
                            initProgrammerState 1 program
                    in
                    state.program
                        |> Expect.equal program
            , test "initializes with no selected order" <|
                \_ ->
                    let
                        state =
                            initProgrammerState 1 []
                    in
                    state.selectedOrderIndex
                        |> Expect.equal Nothing
            ]
        , describe "Program operations"
            [ test "adding orders to program appends to end" <|
                \_ ->
                    let
                        program =
                            [ SetReverser Forward ]

                        newProgram =
                            program ++ [ MoveTo "platform" TrainHead ]
                    in
                    newProgram
                        |> Expect.equal [ SetReverser Forward, MoveTo "platform" TrainHead ]
            , test "program can contain multiple orders of same type" <|
                \_ ->
                    let
                        program =
                            [ WaitSeconds 10, WaitSeconds 20, WaitSeconds 30 ]
                    in
                    List.length program
                        |> Expect.equal 3
            , test "program preserves order sequence" <|
                \_ ->
                    let
                        program =
                            [ SetSwitch "main" Diverging
                            , SetReverser Reverse
                            , MoveTo "team-track" TrainHead
                            , WaitSeconds 60
                            , SetReverser Forward
                            , MoveTo "e-portal" TrainHead
                            ]
                    in
                    List.map (orderDescription testSpotName) program
                        |> Expect.equal
                            [ "Set main Diverging"
                            , "Set Reverser Reverse"
                            , "Move To Team Track"
                            , "Wait 60 seconds"
                            , "Set Reverser Forward"
                            , "Move To East Tunnel"
                            ]
            , test "program with coupling orders preserves sequence" <|
                \_ ->
                    let
                        program =
                            [ MoveTo "team-track" TrainHead
                            , Couple
                            , SetReverser Reverse
                            , MoveTo "platform" TrainHead
                            , Uncouple 1
                            , SetReverser Forward
                            , MoveTo "e-portal" TrainHead
                            ]
                    in
                    List.map (orderDescription testSpotName) program
                        |> Expect.equal
                            [ "Move To Team Track"
                            , "Couple"
                            , "Set Reverser Reverse"
                            , "Move To Platform"
                            , "Uncouple (keep 1)"
                            , "Set Reverser Forward"
                            , "Move To East Tunnel"
                            ]
            ]
        ]
