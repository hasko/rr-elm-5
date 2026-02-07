module Storage exposing
    ( SavedState
    , SavedTrain
    , decodeSavedState
    , encodeSavedState
    , routeForSpawnPoint
    )

{-| Local storage persistence for game state.
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Planning.Types exposing (DepartureTime, ScheduledTrain, SpawnPointId(..), SpawnPointInventory, StockItem, StockType(..))
import Programmer.Types exposing (Order(..), ReverserPosition(..), SpotId(..), SpotTarget(..), SwitchPosition(..))
import Sawmill.Layout exposing (SwitchState)
import Train.Route as Route
import Train.Types exposing (Route)


{-| Saved state structure for localStorage.
-}
type alias SavedState =
    { gameTime : Float
    , mode : String -- "Planning" | "Running" | "Paused"
    , turnoutState : String -- "Normal" | "Reverse"
    , activeTrains : List SavedTrain
    , spawnedTrainIds : List Int
    , scheduledTrains : List ScheduledTrain
    , inventories : List SpawnPointInventory
    , nextTrainId : Int
    , cameraX : Float
    , cameraY : Float
    , cameraZoom : Float
    , timeMultiplier : Float
    }


{-| Simplified train for storage (route reconstructed from spawnPoint).
-}
type alias SavedTrain =
    { id : Int
    , consist : List StockItem
    , position : Float
    , speed : Float
    , spawnPoint : SpawnPointId
    }


{-| Get route for a spawn point with the given turnout state.
-}
routeForSpawnPoint : SpawnPointId -> SwitchState -> Route
routeForSpawnPoint spawnPoint switchState =
    case spawnPoint of
        EastStation ->
            Route.eastToWestRoute switchState

        WestStation ->
            Route.westToEastRoute switchState



-- ENCODERS


{-| Encode saved state to JSON.
-}
encodeSavedState : SavedState -> Encode.Value
encodeSavedState state =
    Encode.object
        [ ( "gameTime", Encode.float state.gameTime )
        , ( "mode", Encode.string state.mode )
        , ( "turnoutState", Encode.string state.turnoutState )
        , ( "activeTrains", Encode.list encodeSavedTrain state.activeTrains )
        , ( "spawnedTrainIds", Encode.list Encode.int state.spawnedTrainIds )
        , ( "scheduledTrains", Encode.list encodeScheduledTrain state.scheduledTrains )
        , ( "inventories", Encode.list encodeInventory state.inventories )
        , ( "nextTrainId", Encode.int state.nextTrainId )
        , ( "cameraX", Encode.float state.cameraX )
        , ( "cameraY", Encode.float state.cameraY )
        , ( "cameraZoom", Encode.float state.cameraZoom )
        , ( "timeMultiplier", Encode.float state.timeMultiplier )
        ]


encodeSavedTrain : SavedTrain -> Encode.Value
encodeSavedTrain train =
    Encode.object
        [ ( "id", Encode.int train.id )
        , ( "consist", Encode.list encodeStockItem train.consist )
        , ( "position", Encode.float train.position )
        , ( "speed", Encode.float train.speed )
        , ( "spawnPoint", encodeSpawnPointId train.spawnPoint )
        ]


encodeScheduledTrain : ScheduledTrain -> Encode.Value
encodeScheduledTrain train =
    Encode.object
        [ ( "id", Encode.int train.id )
        , ( "spawnPoint", encodeSpawnPointId train.spawnPoint )
        , ( "departureTime", encodeDepartureTime train.departureTime )
        , ( "consist", Encode.list encodeStockItem train.consist )
        , ( "program", Encode.list encodeOrder train.program )
        ]


encodeInventory : SpawnPointInventory -> Encode.Value
encodeInventory inv =
    Encode.object
        [ ( "spawnPointId", encodeSpawnPointId inv.spawnPointId )
        , ( "availableStock", Encode.list encodeStockItem inv.availableStock )
        ]


encodeStockItem : StockItem -> Encode.Value
encodeStockItem item =
    Encode.object
        [ ( "id", Encode.int item.id )
        , ( "stockType", encodeStockType item.stockType )
        , ( "reversed", Encode.bool item.reversed )
        , ( "provisional", Encode.bool item.provisional )
        ]


encodeStockType : StockType -> Encode.Value
encodeStockType st =
    Encode.string <|
        case st of
            Locomotive ->
                "Locomotive"

            PassengerCar ->
                "PassengerCar"

            Flatbed ->
                "Flatbed"

            Boxcar ->
                "Boxcar"


encodeSpawnPointId : SpawnPointId -> Encode.Value
encodeSpawnPointId sp =
    Encode.string <|
        case sp of
            EastStation ->
                "EastStation"

            WestStation ->
                "WestStation"


encodeDepartureTime : DepartureTime -> Encode.Value
encodeDepartureTime dt =
    Encode.object
        [ ( "day", Encode.int dt.day )
        , ( "hour", Encode.int dt.hour )
        , ( "minute", Encode.int dt.minute )
        ]


encodeOrder : Order -> Encode.Value
encodeOrder order =
    case order of
        MoveTo spot target ->
            Encode.object
                ([ ( "type", Encode.string "MoveTo" )
                 , ( "spot", encodeSpotId spot )
                 ]
                    ++ (case target of
                            TrainHead ->
                                []

                            SpotCar carIndex ->
                                [ ( "spotCar", Encode.int carIndex ) ]
                       )
                )

        SetReverser pos ->
            Encode.object
                [ ( "type", Encode.string "SetReverser" )
                , ( "position", encodeReverserPosition pos )
                ]

        SetSwitch switchId pos ->
            Encode.object
                [ ( "type", Encode.string "SetSwitch" )
                , ( "switchId", Encode.string switchId )
                , ( "position", encodeSwitchPosition pos )
                ]

        WaitSeconds n ->
            Encode.object
                [ ( "type", Encode.string "WaitSeconds" )
                , ( "seconds", Encode.int n )
                ]

        Couple ->
            Encode.object
                [ ( "type", Encode.string "Couple" )
                ]

        Uncouple n ->
            Encode.object
                [ ( "type", Encode.string "Uncouple" )
                , ( "keep", Encode.int n )
                ]


encodeSpotId : SpotId -> Encode.Value
encodeSpotId spot =
    Encode.string <|
        case spot of
            PlatformSpot ->
                "PlatformSpot"

            TeamTrackSpot ->
                "TeamTrackSpot"

            EastTunnelSpot ->
                "EastTunnelSpot"

            WestTunnelSpot ->
                "WestTunnelSpot"


encodeReverserPosition : ReverserPosition -> Encode.Value
encodeReverserPosition pos =
    Encode.string <|
        case pos of
            Forward ->
                "Forward"

            Reverse ->
                "Reverse"


encodeSwitchPosition : SwitchPosition -> Encode.Value
encodeSwitchPosition pos =
    Encode.string <|
        case pos of
            Normal ->
                "Normal"

            Diverging ->
                "Diverging"



-- DECODERS


{-| Decode saved state from JSON.
-}
decodeSavedState : Decoder SavedState
decodeSavedState =
    Decode.map8
        (\gameTime mode turnoutState activeTrains spawnedTrainIds scheduledTrains inventories rest ->
            { gameTime = gameTime
            , mode = mode
            , turnoutState = turnoutState
            , activeTrains = activeTrains
            , spawnedTrainIds = spawnedTrainIds
            , scheduledTrains = scheduledTrains
            , inventories = inventories
            , nextTrainId = rest.nextTrainId
            , cameraX = rest.cameraX
            , cameraY = rest.cameraY
            , cameraZoom = rest.cameraZoom
            , timeMultiplier = rest.timeMultiplier
            }
        )
        (Decode.field "gameTime" Decode.float)
        (Decode.field "mode" Decode.string)
        (Decode.field "turnoutState" Decode.string)
        (Decode.field "activeTrains" (Decode.list decodeSavedTrain))
        (Decode.field "spawnedTrainIds" (Decode.list Decode.int))
        (Decode.field "scheduledTrains" (Decode.list decodeScheduledTrain))
        (Decode.field "inventories" (Decode.list decodeInventory))
        decodeRestOfState


{-| Helper to decode remaining fields (avoids Decode.map8 limit).
-}
decodeRestOfState :
    Decoder
        { nextTrainId : Int
        , cameraX : Float
        , cameraY : Float
        , cameraZoom : Float
        , timeMultiplier : Float
        }
decodeRestOfState =
    Decode.map5
        (\nextTrainId cameraX cameraY cameraZoom timeMultiplier ->
            { nextTrainId = nextTrainId
            , cameraX = cameraX
            , cameraY = cameraY
            , cameraZoom = cameraZoom
            , timeMultiplier = timeMultiplier
            }
        )
        (Decode.field "nextTrainId" Decode.int)
        (Decode.field "cameraX" Decode.float)
        (Decode.field "cameraY" Decode.float)
        (Decode.field "cameraZoom" Decode.float)
        (Decode.field "timeMultiplier" Decode.float)


decodeSavedTrain : Decoder SavedTrain
decodeSavedTrain =
    Decode.map5 SavedTrain
        (Decode.field "id" Decode.int)
        (Decode.field "consist" (Decode.list decodeStockItem))
        (Decode.field "position" Decode.float)
        (Decode.field "speed" Decode.float)
        (Decode.field "spawnPoint" decodeSpawnPointId)


decodeScheduledTrain : Decoder ScheduledTrain
decodeScheduledTrain =
    Decode.map5 ScheduledTrain
        (Decode.field "id" Decode.int)
        (Decode.field "spawnPoint" decodeSpawnPointId)
        (Decode.field "departureTime" decodeDepartureTime)
        (Decode.field "consist" (Decode.list decodeStockItem))
        (Decode.field "program" (Decode.list decodeOrder))


decodeInventory : Decoder SpawnPointInventory
decodeInventory =
    Decode.map2 SpawnPointInventory
        (Decode.field "spawnPointId" decodeSpawnPointId)
        (Decode.field "availableStock" (Decode.list decodeStockItem))


decodeStockItem : Decoder StockItem
decodeStockItem =
    Decode.map4 StockItem
        (Decode.field "id" Decode.int)
        (Decode.field "stockType" decodeStockType)
        (Decode.oneOf
            [ Decode.field "reversed" Decode.bool
            , Decode.succeed False
            ]
        )
        (Decode.oneOf
            [ Decode.field "provisional" Decode.bool
            , Decode.succeed False
            ]
        )


decodeStockType : Decoder StockType
decodeStockType =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "Locomotive" ->
                        Decode.succeed Locomotive

                    "PassengerCar" ->
                        Decode.succeed PassengerCar

                    "Flatbed" ->
                        Decode.succeed Flatbed

                    "Boxcar" ->
                        Decode.succeed Boxcar

                    _ ->
                        Decode.fail ("Unknown stock type: " ++ s)
            )


decodeSpawnPointId : Decoder SpawnPointId
decodeSpawnPointId =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "EastStation" ->
                        Decode.succeed EastStation

                    "WestStation" ->
                        Decode.succeed WestStation

                    _ ->
                        Decode.fail ("Unknown spawn point: " ++ s)
            )


decodeDepartureTime : Decoder DepartureTime
decodeDepartureTime =
    Decode.map3 DepartureTime
        (Decode.field "day" Decode.int)
        (Decode.field "hour" Decode.int)
        (Decode.field "minute" Decode.int)


decodeOrder : Decoder Order
decodeOrder =
    Decode.field "type" Decode.string
        |> Decode.andThen
            (\orderType ->
                case orderType of
                    "MoveTo" ->
                        Decode.map2 MoveTo
                            (Decode.field "spot" decodeSpotId)
                            (Decode.field "spotCar" Decode.int
                                |> Decode.map SpotCar
                                |> Decode.maybe
                                |> Decode.map (Maybe.withDefault TrainHead)
                            )

                    "SetReverser" ->
                        Decode.map SetReverser (Decode.field "position" decodeReverserPosition)

                    "SetSwitch" ->
                        Decode.map2 SetSwitch
                            (Decode.field "switchId" Decode.string)
                            (Decode.field "position" decodeSwitchPosition)

                    "WaitSeconds" ->
                        Decode.map WaitSeconds (Decode.field "seconds" Decode.int)

                    "Couple" ->
                        Decode.succeed Couple

                    "Uncouple" ->
                        Decode.map Uncouple (Decode.field "keep" Decode.int)

                    _ ->
                        Decode.fail ("Unknown order type: " ++ orderType)
            )


decodeSpotId : Decoder SpotId
decodeSpotId =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "PlatformSpot" ->
                        Decode.succeed PlatformSpot

                    "TeamTrackSpot" ->
                        Decode.succeed TeamTrackSpot

                    "EastTunnelSpot" ->
                        Decode.succeed EastTunnelSpot

                    "WestTunnelSpot" ->
                        Decode.succeed WestTunnelSpot

                    _ ->
                        Decode.fail ("Unknown spot: " ++ s)
            )


decodeReverserPosition : Decoder ReverserPosition
decodeReverserPosition =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "Forward" ->
                        Decode.succeed Forward

                    "Reverse" ->
                        Decode.succeed Reverse

                    _ ->
                        Decode.fail ("Unknown reverser position: " ++ s)
            )


decodeSwitchPosition : Decoder SwitchPosition
decodeSwitchPosition =
    Decode.string
        |> Decode.andThen
            (\s ->
                case s of
                    "Normal" ->
                        Decode.succeed Normal

                    "Diverging" ->
                        Decode.succeed Diverging

                    _ ->
                        Decode.fail ("Unknown switch position: " ++ s)
            )
