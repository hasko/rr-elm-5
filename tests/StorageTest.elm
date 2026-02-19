module StorageTest exposing (..)

import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Planning.Types exposing (SpawnPointId(..), StockType(..))
import Util.GameTime as GameTime
import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotId(..), SpotTarget(..), SwitchPosition(..))
import Storage exposing (SavedState, SavedTrain, decodeSavedState, encodeSavedState)
import Test exposing (..)


suite : Test
suite =
    describe "Storage"
        [ roundTripTests
        , edgeCaseTests
        ]


{-| Helper to encode then decode a SavedState.
-}
roundTrip : SavedState -> Result Decode.Error SavedState
roundTrip state =
    state
        |> encodeSavedState
        |> Decode.decodeValue decodeSavedState


{-| A minimal valid SavedState for testing.
-}
minimalState : SavedState
minimalState =
    { gameTime = 0
    , mode = "Planning"
    , turnoutState = "Normal"
    , activeTrains = []
    , spawnedTrainIds = []
    , scheduledTrains = []
    , inventories = []
    , nextTrainId = 1
    , cameraX = 0
    , cameraY = 0
    , cameraZoom = 1
    , timeMultiplier = 1
    }


roundTripTests : Test
roundTripTests =
    describe "encode/decode round-trip"
        [ test "minimal state preserves all fields" <|
            \_ ->
                case roundTrip minimalState of
                    Ok decoded ->
                        Expect.all
                            [ \_ -> decoded.gameTime |> Expect.within (Expect.Absolute 0.01) 0
                            , \_ -> decoded.mode |> Expect.equal "Planning"
                            , \_ -> decoded.turnoutState |> Expect.equal "Normal"
                            , \_ -> decoded.activeTrains |> Expect.equal []
                            , \_ -> decoded.spawnedTrainIds |> Expect.equal []
                            , \_ -> decoded.scheduledTrains |> Expect.equal []
                            , \_ -> decoded.inventories |> Expect.equal []
                            , \_ -> decoded.nextTrainId |> Expect.equal 1
                            , \_ -> decoded.cameraX |> Expect.within (Expect.Absolute 0.01) 0
                            , \_ -> decoded.cameraY |> Expect.within (Expect.Absolute 0.01) 0
                            , \_ -> decoded.cameraZoom |> Expect.within (Expect.Absolute 0.01) 1
                            , \_ -> decoded.timeMultiplier |> Expect.within (Expect.Absolute 0.01) 1
                            ]
                            ()

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "state with active trains round-trips" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | activeTrains =
                                [ { id = 1
                                  , consist =
                                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                        , { id = 2, stockType = Flatbed, reversed = False, provisional = False }
                                        ]
                                  , position = 123.45
                                  , speed = 11.11
                                  , spawnPoint = EastStation
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        case List.head decoded.activeTrains of
                            Just train ->
                                Expect.all
                                    [ \_ -> train.id |> Expect.equal 1
                                    , \_ -> List.length train.consist |> Expect.equal 2
                                    , \_ -> train.position |> Expect.within (Expect.Absolute 0.01) 123.45
                                    , \_ -> train.speed |> Expect.within (Expect.Absolute 0.01) 11.11
                                    , \_ -> train.spawnPoint |> Expect.equal EastStation
                                    ]
                                    ()

                            Nothing ->
                                Expect.fail "No active trains after decode"

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "state with scheduled trains round-trips" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = WestStation
                                  , departureTime = GameTime.fromDayHourMinute 2 14 30
                                  , consist = [ { id = 4, stockType = Boxcar, reversed = False, provisional = False } ]
                                  , program =
                                        [ SetReverser Forward
                                        , MoveTo PlatformSpot TrainHead
                                        , WaitSeconds 30
                                        , SetSwitch "main" Diverging
                                        ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        case List.head decoded.scheduledTrains of
                            Just train ->
                                Expect.all
                                    [ \_ -> train.id |> Expect.equal 1
                                    , \_ -> train.spawnPoint |> Expect.equal WestStation
                                    , \_ -> train.departureTime |> Expect.equal (GameTime.fromDayHourMinute 2 14 30)
                                    , \_ -> List.length train.program |> Expect.equal 4
                                    ]
                                    ()

                            Nothing ->
                                Expect.fail "No scheduled trains after decode"

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "inventories round-trip" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | inventories =
                                [ { spawnPointId = EastStation
                                  , availableStock =
                                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                        , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                                        , { id = 3, stockType = Flatbed, reversed = False, provisional = False }
                                        ]
                                  }
                                , { spawnPointId = WestStation
                                  , availableStock =
                                        [ { id = 4, stockType = Locomotive, reversed = False, provisional = False }
                                        , { id = 5, stockType = Boxcar, reversed = False, provisional = False }
                                        ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        Expect.all
                            [ \_ -> List.length decoded.inventories |> Expect.equal 2
                            , \_ ->
                                decoded.inventories
                                    |> List.filter (\inv -> inv.spawnPointId == EastStation)
                                    |> List.head
                                    |> Maybe.map (.availableStock >> List.length)
                                    |> Expect.equal (Just 3)
                            , \_ ->
                                decoded.inventories
                                    |> List.filter (\inv -> inv.spawnPointId == WestStation)
                                    |> List.head
                                    |> Maybe.map (.availableStock >> List.length)
                                    |> Expect.equal (Just 2)
                            ]
                            ()

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "all stock types round-trip" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | inventories =
                                [ { spawnPointId = EastStation
                                  , availableStock =
                                        [ { id = 1, stockType = Locomotive, reversed = False, provisional = False }
                                        , { id = 2, stockType = PassengerCar, reversed = False, provisional = False }
                                        , { id = 3, stockType = Flatbed, reversed = False, provisional = False }
                                        , { id = 4, stockType = Boxcar, reversed = False, provisional = False }
                                        ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.inventories
                            |> List.head
                            |> Maybe.map (.availableStock >> List.map .stockType)
                            |> Expect.equal (Just [ Locomotive, PassengerCar, Flatbed, Boxcar ])

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "all order types round-trip" <|
            \_ ->
                let
                    allOrders =
                        [ MoveTo PlatformSpot TrainHead
                        , MoveTo TeamTrackSpot TrainHead
                        , MoveTo EastTunnelSpot TrainHead
                        , MoveTo WestTunnelSpot TrainHead
                        , SetReverser Forward
                        , SetReverser Reverse
                        , SetSwitch "main" Normal
                        , SetSwitch "siding" Diverging
                        , WaitSeconds 42
                        , Couple
                        , Uncouple 1
                        , Uncouple 3
                        ]

                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = EastStation
                                  , departureTime = GameTime.fromDayHourMinute 0 0 0
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , program = allOrders
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.scheduledTrains
                            |> List.head
                            |> Maybe.map .program
                            |> Expect.equal (Just allOrders)

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "spawned train IDs round-trip" <|
            \_ ->
                let
                    state =
                        { minimalState | spawnedTrainIds = [ 1, 2, 5 ] }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.spawnedTrainIds
                            |> Expect.equal [ 1, 2, 5 ]

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "camera state round-trips" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | cameraX = -123.45
                            , cameraY = 67.89
                            , cameraZoom = 0.75
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        Expect.all
                            [ \_ -> decoded.cameraX |> Expect.within (Expect.Absolute 0.01) -123.45
                            , \_ -> decoded.cameraY |> Expect.within (Expect.Absolute 0.01) 67.89
                            , \_ -> decoded.cameraZoom |> Expect.within (Expect.Absolute 0.01) 0.75
                            ]
                            ()

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "game time and multiplier round-trip" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | gameTime = 3600.5
                            , timeMultiplier = 2.5
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        Expect.all
                            [ \_ -> decoded.gameTime |> Expect.within (Expect.Absolute 0.01) 3600.5
                            , \_ -> decoded.timeMultiplier |> Expect.within (Expect.Absolute 0.01) 2.5
                            ]
                            ()

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "both spawn points round-trip" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | activeTrains =
                                [ { id = 1
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , position = 50
                                  , speed = 10
                                  , spawnPoint = EastStation
                                  }
                                , { id = 2
                                  , consist = [ { id = 2, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , position = 100
                                  , speed = 10
                                  , spawnPoint = WestStation
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.activeTrains
                            |> List.map .spawnPoint
                            |> Expect.equal [ EastStation, WestStation ]

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        ]


edgeCaseTests : Test
edgeCaseTests =
    describe "edge cases"
        [ test "mode values preserved as strings" <|
            \_ ->
                let
                    states =
                        [ { minimalState | mode = "Running" }
                        , { minimalState | mode = "Paused" }
                        , { minimalState | mode = "Planning" }
                        ]
                in
                states
                    |> List.map (\s -> roundTrip s |> Result.map .mode)
                    |> Expect.equal [ Ok "Running", Ok "Paused", Ok "Planning" ]
        , test "turnout state values preserved as strings" <|
            \_ ->
                let
                    states =
                        [ { minimalState | turnoutState = "Normal" }
                        , { minimalState | turnoutState = "Reverse" }
                        ]
                in
                states
                    |> List.map (\s -> roundTrip s |> Result.map .turnoutState)
                    |> Expect.equal [ Ok "Normal", Ok "Reverse" ]
        , test "empty program round-trips" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = EastStation
                                  , departureTime = GameTime.fromDayHourMinute 0 0 0
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , program = []
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.scheduledTrains
                            |> List.head
                            |> Maybe.map .program
                            |> Expect.equal (Just [])

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "decoding invalid JSON fails gracefully" <|
            \_ ->
                let
                    result =
                        Decode.decodeString decodeSavedState "{\"invalid\": true}"
                in
                case result of
                    Err _ ->
                        Expect.pass

                    Ok _ ->
                        Expect.fail "Should have failed to decode invalid JSON"
        , test "Couple order round-trips" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = EastStation
                                  , departureTime = GameTime.fromDayHourMinute 0 0 0
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , program = [ Couple ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.scheduledTrains
                            |> List.head
                            |> Maybe.map .program
                            |> Expect.equal (Just [ Couple ])

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "Uncouple order round-trips with keep count" <|
            \_ ->
                let
                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = EastStation
                                  , departureTime = GameTime.fromDayHourMinute 0 0 0
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , program = [ Uncouple 2 ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.scheduledTrains
                            |> List.head
                            |> Maybe.map .program
                            |> Expect.equal (Just [ Uncouple 2 ])

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "old saves without Couple/Uncouple still decode" <|
            \_ ->
                -- Simulate an old save that only has the original order types
                let
                    state =
                        { minimalState
                            | scheduledTrains =
                                [ { id = 1
                                  , spawnPoint = EastStation
                                  , departureTime = GameTime.fromDayHourMinute 0 0 0
                                  , consist = [ { id = 1, stockType = Locomotive, reversed = False, provisional = False } ]
                                  , program = [ SetReverser Forward, MoveTo PlatformSpot TrainHead ]
                                  }
                                ]
                        }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.scheduledTrains
                            |> List.head
                            |> Maybe.map .program
                            |> Expect.equal (Just [ SetReverser Forward, MoveTo PlatformSpot TrainHead ])

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        , test "nextTrainId preserves high values" <|
            \_ ->
                let
                    state =
                        { minimalState | nextTrainId = 999 }
                in
                case roundTrip state of
                    Ok decoded ->
                        decoded.nextTrainId |> Expect.equal 999

                    Err err ->
                        Expect.fail ("Decode failed: " ++ Decode.errorToString err)
        ]
