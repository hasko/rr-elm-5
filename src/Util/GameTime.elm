module Util.GameTime exposing
    ( GameTime
    , fromDayHourMinute
    , fromHourMinute
    , toDayHourMinute
    , formatTime
    , formatDayTime
    )

{-| Game time representation.

GameTime is a transparent Float alias representing seconds since Monday 00:00.
The game week runs Mon–Fri (days 0–4). Standard comparison operators work directly.

-}


{-| Seconds since Monday 00:00.
-}
type alias GameTime =
    Float


{-| Construct from day (0–4), hour (0–23), minute (0–59).
-}
fromDayHourMinute : Int -> Int -> Int -> GameTime
fromDayHourMinute day hour minute =
    toFloat (day * 86400 + hour * 3600 + minute * 60)


{-| Construct from hour and minute (assumes day 0).
-}
fromHourMinute : Int -> Int -> GameTime
fromHourMinute hour minute =
    fromDayHourMinute 0 hour minute


{-| Decompose into (day, hour, minute). Seconds are truncated.
-}
toDayHourMinute : GameTime -> ( Int, Int, Int )
toDayHourMinute time =
    let
        totalMinutes =
            floor time // 60

        minute =
            modBy 60 totalMinutes

        totalHours =
            totalMinutes // 60

        hour =
            modBy 24 totalHours

        day =
            totalHours // 24
    in
    ( day, hour, minute )


{-| Format as "HH:MM".
-}
formatTime : GameTime -> String
formatTime time =
    let
        ( _, hour, minute ) =
            toDayHourMinute time
    in
    String.padLeft 2 '0' (String.fromInt hour)
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt minute)


{-| Format as "Day HH:MM" (e.g. "Mon 06:30").
-}
formatDayTime : GameTime -> String
formatDayTime time =
    let
        ( day, _, _ ) =
            toDayHourMinute time
    in
    dayName day ++ " " ++ formatTime time


dayName : Int -> String
dayName day =
    case day of
        0 ->
            "Mon"

        1 ->
            "Tue"

        2 ->
            "Wed"

        3 ->
            "Thu"

        _ ->
            "Fri"
