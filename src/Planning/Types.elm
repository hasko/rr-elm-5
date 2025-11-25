module Planning.Types exposing
    ( SpawnPointId(..)
    , StockType(..)
    , StockItem
    , Consist
    , DepartureTime
    , ScheduledTrain
    , SpawnPointInventory
    , ConsistBuilder
    , PlanningState
    , initPlanningState
    , emptyConsistBuilder
    , stockTypeName
    )

{-| Types for the train planning system.
-}


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
    }


{-| A consist is an ordered list of stock items.
-}
type alias Consist =
    List StockItem


{-| Departure time within the game week.
-}
type alias DepartureTime =
    { day : Int -- 0-4 (Mon-Fri)
    , hour : Int -- 0-23
    , minute : Int -- 0-59
    }


{-| A scheduled train with spawn point, time, and consist.
-}
type alias ScheduledTrain =
    { id : Int
    , spawnPoint : SpawnPointId
    , departureTime : DepartureTime
    , consist : Consist
    }


{-| Inventory for a spawn point.
-}
type alias SpawnPointInventory =
    { spawnPointId : SpawnPointId
    , availableStock : List StockItem
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
    , editingTrainId : Maybe Int -- When editing existing train
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
                [ { id = 1, stockType = Locomotive }
                , { id = 2, stockType = PassengerCar }
                , { id = 3, stockType = Flatbed }
                ]
          }
        , { spawnPointId = WestStation
          , availableStock =
                [ { id = 4, stockType = Locomotive }
                , { id = 5, stockType = Boxcar }
                , { id = 6, stockType = Boxcar }
                ]
          }
        ]
    , consistBuilder = emptyConsistBuilder
    , timePickerHour = 6
    , timePickerMinute = 0
    , timePickerDay = 0
    , nextTrainId = 1
    , editingTrainId = Nothing
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
