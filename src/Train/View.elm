module Train.View exposing (viewTrains)

{-| Train rendering as top-down SVG.
-}

import Planning.Types exposing (StockItem, StockType(..))
import Svg exposing (Svg)
import Svg.Attributes as SvgA
import Train.Route as Route
import Train.Stock exposing (couplerGap, stockLength)
import Train.Types exposing (ActiveTrain)
import Util.Vec2 exposing (Vec2)


{-| Render all active trains.
-}
viewTrains : List ActiveTrain -> Svg msg
viewTrains trains =
    Svg.g [] (List.map viewTrain trains)


{-| Render a single train.
-}
viewTrain : ActiveTrain -> Svg msg
viewTrain train =
    let
        carPositions =
            positionCars train
    in
    Svg.g []
        (List.filterMap
            (\car ->
                -- Only render cars that are on the visible part of the route
                if car.centerDistance >= 0 && car.centerDistance <= train.route.totalLength then
                    car.worldPosition
                        |> Maybe.map
                            (\pos ->
                                viewTrainCar pos.position pos.orientation car.stockType
                            )

                else
                    Nothing
            )
            carPositions
        )


{-| Position data for a car.
-}
type alias CarPosition =
    { stockType : StockType
    , centerDistance : Float
    , worldPosition : Maybe { position : Vec2, orientation : Float }
    }


{-| Calculate positions for all cars in a consist.
-}
positionCars : ActiveTrain -> List CarPosition
positionCars train =
    let
        -- Build list of car positions, starting from lead car
        positionCar : StockItem -> ( Float, List CarPosition ) -> ( Float, List CarPosition )
        positionCar item ( frontCouplerDist, accCars ) =
            let
                carLen =
                    stockLength item.stockType

                centerDist =
                    frontCouplerDist - carLen / 2

                rearCouplerDist =
                    frontCouplerDist - carLen - couplerGap

                worldPos =
                    Route.positionOnRoute centerDist train.route

                carPos =
                    { stockType = item.stockType
                    , centerDistance = centerDist
                    , worldPosition = worldPos
                    }
            in
            ( rearCouplerDist, carPos :: accCars )

        ( _, reversedCars ) =
            List.foldl positionCar ( train.position, [] ) train.consist
    in
    List.reverse reversedCars


{-| Render a single car at its position on the track.
-}
viewTrainCar : Vec2 -> Float -> StockType -> Svg msg
viewTrainCar position orientation stockType =
    let
        -- Convert from custom system (0° = North, CW) to SVG (0° = East, CCW)
        -- Formula: svgAngle = 90° - customAngle (in radians: pi/2 - orientation)
        rotationDeg =
            (pi / 2 - orientation) * 180 / pi

        -- SVG transform: translate to position, then rotate
        transform =
            "translate("
                ++ String.fromFloat position.x
                ++ ","
                ++ String.fromFloat -position.y
                ++ ") rotate("
                ++ String.fromFloat rotationDeg
                ++ ")"
    in
    Svg.g [ SvgA.transform transform ]
        (case stockType of
            Flatbed ->
                viewFlatbed

            _ ->
                viewSimpleCar stockType
        )


{-| Render a simple rectangular car (locomotive, passenger, boxcar).
-}
viewSimpleCar : StockType -> List (Svg msg)
viewSimpleCar stockType =
    let
        -- Dimensions (length x width in meters) and color based on stock type
        -- V60 switcher: 10.45m long, 3.1m wide (axles 4.4m apart)
        -- Donnerbüchse: 13.92m long, 3.096m wide (axles 8.5m apart)
        ( length, carWidth, color ) =
            case stockType of
                Locomotive ->
                    ( 10.45, 3.1, "#4a6a8a" )

                PassengerCar ->
                    ( 13.92, 3.096, "#8a6a4a" )

                Boxcar ->
                    ( 12, 2.7, "#8a4a4a" )

                Flatbed ->
                    -- Should not happen, handled separately
                    ( 13.96, 3.0, "#6a5a4a" )
    in
    [ Svg.rect
        [ SvgA.x (String.fromFloat (-length / 2))
        , SvgA.y (String.fromFloat (-carWidth / 2))
        , SvgA.width (String.fromFloat length)
        , SvgA.height (String.fromFloat carWidth)
        , SvgA.fill color
        , SvgA.stroke "#333"
        , SvgA.strokeWidth "0.3"
        , SvgA.rx "1"
        ]
        []
    ]


{-| Render a wood transport flatbed car with Rungen (stakes).
Dimensions: 13.96m long, ~3m wide (2.768m load + sides), 12.5m load length, 8m axle spacing
-}
viewFlatbed : List (Svg msg)
viewFlatbed =
    let
        -- Overall dimensions
        length =
            13.96

        carWidth =
            3.0

        -- Deck/platform color
        deckColor =
            "#6a5a4a"

        -- Rungen (stakes) - 8 on each side, equally spaced, outermost at corners
        -- rungeHeight is the dimension perpendicular to track (adds to visual width)
        -- rungeWidth is the dimension along the track
        rungeHeight =
            0.6

        rungeWidth =
            0.4

        rungeColor =
            "#4a4a4a"

        -- 8 stakes from -length/2 to +length/2, equally spaced
        -- Spacing = length / 7 (7 gaps between 8 stakes)
        halfLength =
            length / 2

        spacing =
            length / 7

        -- Positions: -6.98, -4.99, -3.0, -1.0, 1.0, 3.0, 4.99, 6.98
        rungePositions =
            List.map (\i -> -halfLength + toFloat i * spacing) (List.range 0 7)

        -- Create a single Runge (stake) at given x position and y offset
        makeRunge xPos yOffset =
            Svg.rect
                [ SvgA.x (String.fromFloat (xPos - rungeWidth / 2))
                , SvgA.y (String.fromFloat (yOffset - rungeHeight / 2))
                , SvgA.width (String.fromFloat rungeWidth)
                , SvgA.height (String.fromFloat rungeHeight)
                , SvgA.fill rungeColor
                , SvgA.stroke "#333"
                , SvgA.strokeWidth "0.15"
                ]
                []

        -- Create pairs of Rungen (one on each side)
        -- Position stakes centered on deck edge so they extend beyond
        makeRungePair xPos =
            [ makeRunge xPos (carWidth / 2)
            , makeRunge xPos (-carWidth / 2)
            ]

        allRungen =
            List.concatMap makeRungePair rungePositions
    in
    -- Base deck
    [ Svg.rect
        [ SvgA.x (String.fromFloat (-length / 2))
        , SvgA.y (String.fromFloat (-carWidth / 2))
        , SvgA.width (String.fromFloat length)
        , SvgA.height (String.fromFloat carWidth)
        , SvgA.fill deckColor
        , SvgA.stroke "#333"
        , SvgA.strokeWidth "0.3"
        , SvgA.rx "0.5"
        ]
        []
    ]
        ++ allRungen
