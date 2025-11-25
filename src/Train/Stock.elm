module Train.Stock exposing
    ( stockLength
    , couplerGap
    , consistLength
    , trainSpeed
    )

{-| Physical dimensions and properties for rolling stock.
-}

import Planning.Types exposing (StockItem, StockType(..))


{-| Length of a stock item in meters.
V60 switcher locomotive: 10.45m
Donnerbüchse passenger car: 13.92m
-}
stockLength : StockType -> Float
stockLength stockType =
    case stockType of
        Locomotive ->
            10.45

        PassengerCar ->
            13.92

        Flatbed ->
            13.96

        Boxcar ->
            12.0


{-| Gap between coupled cars in meters.
-}
couplerGap : Float
couplerGap =
    1.0


{-| Total length of a consist (all cars + gaps between them).
-}
consistLength : List StockItem -> Float
consistLength items =
    let
        carLengths =
            List.sum (List.map (\item -> stockLength item.stockType) items)

        gaps =
            couplerGap * toFloat (max 0 (List.length items - 1))
    in
    carLengths + gaps


{-| Default train speed in m/s (40 km/h).
-}
trainSpeed : Float
trainSpeed =
    40.0 * 1000.0 / 3600.0
