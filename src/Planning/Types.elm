module Planning.Types exposing
    ( SpawnPointId(..)
    , StockType(..)
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
    )

import Programmer.Types exposing (Program, ProgrammerState, emptyProgram)
import Util.GameTime exposing (GameTime)


{-| What the right panel is showing.
-}
type PanelMode
    = PlanningView
    | ProgrammerView Int -- trainId being programmed


{-| Spawn point identifier for where trains enter the puzzle.
-}
type SpawnPointId
    = EastStation
    | WestStation


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
    , spawnPoint : SpawnPointId
    , departureTime : GameTime
    , consist : Consist
    , program : Program
    }


{-| Inventory for a spawn point.
-}
type alias SpawnPointInventory =
    { spawnPointId : SpawnPointId
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
    { selectedSpawnPoint : SpawnPointId
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


{-| Initial planning state with default inventories.
-}
initPlanningState : PlanningState
initPlanningState =
    { selectedSpawnPoint = EastStation
    , scheduledTrains = []
    , inventories =
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
                , { id = 6, stockType = Boxcar, reversed = False, provisional = False }
                ]
          }
        ]
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
