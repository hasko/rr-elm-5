module GameTimeTest exposing (..)

import Expect
import Test exposing (..)
import Util.GameTime exposing (fromDayHourMinute, fromHourMinute, toDayHourMinute, formatTime, formatDayTime)


suite : Test
suite =
    describe "Util.GameTime"
        [ describe "fromDayHourMinute"
            [ test "Monday 06:30" <|
                \_ ->
                    fromDayHourMinute 0 6 30
                        |> Expect.equal 23400.0
            , test "Tuesday 01:01" <|
                \_ ->
                    fromDayHourMinute 1 1 1
                        |> Expect.equal 90060.0
            , test "Monday 00:00 is zero" <|
                \_ ->
                    fromDayHourMinute 0 0 0
                        |> Expect.equal 0.0
            ]
        , describe "fromHourMinute"
            [ test "06:30 same as day 0" <|
                \_ ->
                    fromHourMinute 6 30
                        |> Expect.equal (fromDayHourMinute 0 6 30)
            ]
        , describe "toDayHourMinute"
            [ test "Monday 06:30" <|
                \_ ->
                    toDayHourMinute 23400.0
                        |> Expect.equal ( 0, 6, 30 )
            , test "Tuesday 01:01" <|
                \_ ->
                    toDayHourMinute 90060.0
                        |> Expect.equal ( 1, 1, 1 )
            , test "midnight" <|
                \_ ->
                    toDayHourMinute 0.0
                        |> Expect.equal ( 0, 0, 0 )
            , test "roundtrip" <|
                \_ ->
                    fromDayHourMinute 3 14 59
                        |> toDayHourMinute
                        |> Expect.equal ( 3, 14, 59 )
            ]
        , describe "formatTime"
            [ test "06:30" <|
                \_ ->
                    formatTime (fromHourMinute 6 30)
                        |> Expect.equal "06:30"
            , test "zero-pads" <|
                \_ ->
                    formatTime (fromHourMinute 0 5)
                        |> Expect.equal "00:05"
            ]
        , describe "formatDayTime"
            [ test "Mon 06:30" <|
                \_ ->
                    formatDayTime (fromDayHourMinute 0 6 30)
                        |> Expect.equal "Mon 06:30"
            , test "Fri 23:59" <|
                \_ ->
                    formatDayTime (fromDayHourMinute 4 23 59)
                        |> Expect.equal "Fri 23:59"
            , test "day names" <|
                \_ ->
                    [ 0, 1, 2, 3, 4 ]
                        |> List.map (\d -> formatDayTime (fromDayHourMinute d 0 0))
                        |> Expect.equal [ "Mon 00:00", "Tue 00:00", "Wed 00:00", "Thu 00:00", "Fri 00:00" ]
            ]
        ]
