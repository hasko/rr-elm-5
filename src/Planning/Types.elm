module Planning.Types exposing
    ( StockType(..)
    , StockItem
    , Consist
    , ScheduledTrain
    , SpawnPointInventory
    , ConsistBuilder
    , ConsistDragState
    , PlanningState
    , PanelMode(..)
    , initPlanningState
    , emptyConsistBuilder
    , stockTypeName
    , stockTypeFromString
    )

import Programmer.Types exposing (Program, ProgrammerState, emptyProgram)
import Scenario exposing (Station, StockEntry)
import Util.GameTime exposing (GameTime)


{-| What the right panel is showing.
-}
type PanelMode
    = PlanningView
    | ProgrammerView Int -- trainId being programmed


{-| Rolling stock types.
-}
type StockType
    = Locomotive
    | PassengerCar
    | Flatbed
    | Boxcar


{-| A stock item with unique ID for tracking.
-}
type alias StockItem =
    { id : Int
    , stockType : StockType
    , reversed : Bool
    , provisional : Bool
    }


{-| A consist is an ordered list of stock items.
-}
type alias Consist =
    List StockItem


{-| A scheduled train with spawn point, time, and consist.
-}
type alias ScheduledTrain =
    { id : Int
    , spawnPoint : String
    , departureTime : GameTime
    , consist : Consist
    , program : Program
    }


{-| Inventory for a spawn point.
-}
type alias SpawnPointInventory =
    { spawnPointId : String
    , availableStock : List StockItem
    }


{-| Drag state for consist horizontal panning.
-}
type alias ConsistDragState =
    { startX : Float -- Screen X where drag started
    , startOffset : Float -- Pan offset when drag started
    }


{-| State for the consist builder UI.
-}
type alias ConsistBuilder =
    { items : List StockItem -- Variable length list, no holes
    , selectedStock : Maybe StockItem -- Currently selected item to place
    }


{-| Planning panel UI state.
-}
type alias PlanningState =
    { selectedSpawnPoint : String
    , scheduledTrains : List ScheduledTrain
    , inventories : List SpawnPointInventory
    , consistBuilder : ConsistBuilder
    , timePickerHour : Int
    , timePickerMinute : Int
    , timePickerDay : Int
    , nextTrainId : Int
    , nextProvisionalId : Int
    , editingTrainId : Maybe Int -- When editing existing train
    , editingTrainProgram : Program -- Program of train being edited
    , panelMode : PanelMode
    , programmerState : Maybe ProgrammerState
    , consistPanOffset : Float -- Horizontal pan offset in pixels
    , consistDragState : Maybe ConsistDragState
    }


{-| Empty consist builder.
-}
emptyConsistBuilder : ConsistBuilder
emptyConsistBuilder =
    { items = []
    , selectedStock = Nothing
    }


{-| Initial planning state with inventories derived from scenario stations.
-}
initPlanningState : List Station -> PlanningState
initPlanningState stations =
    let
        defaultStation =
            stations |> List.head |> Maybe.map .id |> Maybe.withDefault ""

        ( inventories, _ ) =
            List.foldl
                (\station ( accInv, nextId ) ->
                    let
                        ( items, endId ) =
                            expandStock nextId station.stock
                    in
                    ( accInv ++ [ { spawnPointId = station.id, availableStock = items } ], endId )
                )
                ( [], 1 )
                stations
    in
    { selectedSpawnPoint = defaultStation
    , scheduledTrains = []
    , inventories = inventories
    , consistBuilder = emptyConsistBuilder
    , timePickerHour = 6
    , timePickerMinute = 0
    , timePickerDay = 0
    , nextTrainId = 1
    , nextProvisionalId = -1
    , editingTrainId = Nothing
    , editingTrainProgram = emptyProgram
    , panelMode = PlanningView
    , programmerState = Nothing
    , consistPanOffset = 0
    , consistDragState = Nothing
    }


{-| Expand stock entries (type + count) into individual StockItems with unique IDs.
-}
expandStock : Int -> List StockEntry -> ( List StockItem, Int )
expandStock startId entries =
    List.foldl
        (\entry ( accItems, nextId ) ->
            let
                stockType =
                    stockTypeFromString entry.stockType

                newItems =
                    List.range 0 (entry.count - 1)
                        |> List.map
                            (\i ->
                                { id = nextId + i
                                , stockType = stockType
                                , reversed = False
                                , provisional = False
                                }
                            )
            in
            ( accItems ++ newItems, nextId + entry.count )
        )
        ( [], startId )
        entries


{-| Get display name for a stock type.
-}
stockTypeName : StockType -> String
stockTypeName stockType =
    case stockType of
        Locomotive ->
            "Locomotive"

        PassengerCar ->
            "Passenger Car"

        Flatbed ->
            "Flatbed"

        Boxcar ->
            "Boxcar"


{-| Map a scenario stock type string to a StockType.
-}
stockTypeFromString : String -> StockType
stockTypeFromString s =
    case s of
        "locomotive" ->
            Locomotive

        "coach" ->
            PassengerCar

        "passenger" ->
            PassengerCar

        "flatbed" ->
            Flatbed

        "boxcar" ->
            Boxcar

        _ ->
            Boxcar
