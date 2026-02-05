module ProgrammerTypesTest exposing (..)

import Expect
import Programmer.Types exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Programmer.Types"
        [ describe "orderDescription"
            [ test "MoveTo Platform shows correct description" <|
                \_ ->
                    orderDescription (MoveTo PlatformSpot)
                        |> Expect.equal "Move To Platform"
            , test "MoveTo Team Track shows correct description" <|
                \_ ->
                    orderDescription (MoveTo TeamTrackSpot)
                        |> Expect.equal "Move To Team Track"
            , test "MoveTo East Tunnel shows correct description" <|
                \_ ->
                    orderDescription (MoveTo EastTunnelSpot)
                        |> Expect.equal "Move To East Tunnel"
            , test "MoveTo West Tunnel shows correct description" <|
                \_ ->
                    orderDescription (MoveTo WestTunnelSpot)
                        |> Expect.equal "Move To West Tunnel"
            , test "SetReverser Forward shows correct description" <|
                \_ ->
                    orderDescription (SetReverser Forward)
                        |> Expect.equal "Set Reverser Forward"
            , test "SetReverser Reverse shows correct description" <|
                \_ ->
                    orderDescription (SetReverser Reverse)
                        |> Expect.equal "Set Reverser Reverse"
            , test "SetSwitch Normal shows correct description" <|
                \_ ->
                    orderDescription (SetSwitch "main" Normal)
                        |> Expect.equal "Set main Normal"
            , test "SetSwitch Diverging shows correct description" <|
                \_ ->
                    orderDescription (SetSwitch "siding" Diverging)
                        |> Expect.equal "Set siding Diverging"
            , test "WaitSeconds shows correct description" <|
                \_ ->
                    orderDescription (WaitSeconds 30)
                        |> Expect.equal "Wait 30 seconds"
            , test "Couple shows correct description" <|
                \_ ->
                    orderDescription Couple
                        |> Expect.equal "Couple"
            , test "Uncouple 1 shows correct description" <|
                \_ ->
                    orderDescription (Uncouple 1)
                        |> Expect.equal "Uncouple (keep 1)"
            , test "Uncouple 3 shows correct description" <|
                \_ ->
                    orderDescription (Uncouple 3)
                        |> Expect.equal "Uncouple (keep 3)"
            ]
        , describe "spotName"
            [ test "PlatformSpot returns Platform" <|
                \_ ->
                    spotName PlatformSpot
                        |> Expect.equal "Platform"
            , test "TeamTrackSpot returns Team Track" <|
                \_ ->
                    spotName TeamTrackSpot
                        |> Expect.equal "Team Track"
            , test "EastTunnelSpot returns East Tunnel" <|
                \_ ->
                    spotName EastTunnelSpot
                        |> Expect.equal "East Tunnel"
            , test "WestTunnelSpot returns West Tunnel" <|
                \_ ->
                    spotName WestTunnelSpot
                        |> Expect.equal "West Tunnel"
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
                            [ SetReverser Forward, MoveTo PlatformSpot ]

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
                            program ++ [ MoveTo PlatformSpot ]
                    in
                    newProgram
                        |> Expect.equal [ SetReverser Forward, MoveTo PlatformSpot ]
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
                            , MoveTo TeamTrackSpot
                            , WaitSeconds 60
                            , SetReverser Forward
                            , MoveTo EastTunnelSpot
                            ]
                    in
                    List.map orderDescription program
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
                            [ MoveTo TeamTrackSpot
                            , Couple
                            , SetReverser Reverse
                            , MoveTo PlatformSpot
                            , Uncouple 1
                            , SetReverser Forward
                            , MoveTo EastTunnelSpot
                            ]
                    in
                    List.map orderDescription program
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
