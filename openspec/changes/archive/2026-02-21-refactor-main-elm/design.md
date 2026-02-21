## Context

Main.elm is 2024 lines containing the full Elm architecture (Model, Msg, update, subscriptions, view) plus all update helpers and view functions. The update helpers fall into clear groups that only touch specific slices of the model, but they all take and return `Model` directly. Existing module splits (`Planning.Types`/`Planning.View`, `Programmer.Types`/`Programmer.View`) already established the pattern of separating types, view, and update logic — the update leg is just missing.

## Goals / Non-Goals

**Goals:**
- Reduce Main.elm to ~600-700 lines: types, init, top-level update dispatch, subscriptions, and view routing
- Each extracted module has a clear, narrow responsibility
- All existing tests pass unchanged — no behavior changes

**Non-Goals:**
- Changing function signatures beyond what's needed for extraction (e.g., we won't refactor planning helpers to take `PlanningState` instead of `Model` — that's a follow-up)
- Extracting view code (header, canvas, train info panel) — low payoff for now
- Introducing new abstractions or patterns

## Decisions

### 1. Planning helpers → `Planning.Update`

**What moves:** `updateAddToConsist`, `updateInsertInConsist`, `updateRemoveFromConsist`, `updateScheduleTrain`, `updateSelectScheduledTrain`, `updateRemoveScheduledTrain` (~275 lines).

**Signature approach:** The functions currently take `Model` but only touch `model.planningState`. Since `Model` is defined in Main.elm and can't be imported without a circular dependency, refactor them to take and return `PlanningState`:

```elm
-- Planning.Update
addToConsist : Bool -> PlanningState -> PlanningState
insertInConsist : Int -> PlanningState -> PlanningState
removeFromConsist : Int -> PlanningState -> PlanningState
scheduleTrain : PlanningState -> PlanningState
selectScheduledTrain : Int -> PlanningState -> PlanningState
removeScheduledTrain : Int -> PlanningState -> PlanningState
```

Main.elm wraps the calls:

```elm
AddToConsistFront ->
    ( { model | planningState = Planning.Update.addToConsist True model.planningState }, Cmd.none )
```

**Why `PlanningState` over extensible records (`{ a | planningState : PlanningState }`):**
- `PlanningState` is the actual boundary — these functions don't read or write anything else
- Extensible record constraints add complexity for no real benefit here
- Cleaner API that makes the dependency explicit

### 2. Programmer helpers → `Programmer.Update`

**What moves:** `updateOpenProgrammer`, `updateCloseProgrammer`, `updateAddOrder`, `updateRemoveOrder`, `updateMoveOrderUp`, `updateMoveOrderDown`, `updateSelectProgramOrder`, `updateSaveProgram`, `updateProgrammerState` helper (~210 lines).

**Same approach:** Refactor to take and return `PlanningState` (since programmer state lives inside `PlanningState`).

```elm
-- Programmer.Update
openProgrammer : Int -> PlanningState -> PlanningState
closeProgrammer : PlanningState -> PlanningState
addOrder : Order -> PlanningState -> PlanningState
removeOrder : Int -> PlanningState -> PlanningState
moveOrderUp : Int -> PlanningState -> PlanningState
moveOrderDown : Int -> PlanningState -> PlanningState
selectProgramOrder : Int -> PlanningState -> PlanningState
saveProgram : PlanningState -> PlanningState
```

**List utilities** (`removeAt`, `swapAt`): Move to `Util.List` since they're generic and may be reused.

### 3. Camera → `Camera.elm`

**What moves:** `Camera` type, `DragState` type, and update logic for `StartDrag`, `Drag`, `EndDrag`, `Zoom` (~135 lines).

**Signature approach:** Camera operations only need camera state and viewport size. Define self-contained update functions:

```elm
-- Camera
type alias Camera = { center : Vec2, zoom : Float }
type alias DragState = { startScreenPos : Vec2, startCameraCenter : Vec2 }

startDrag : Float -> Float -> Camera -> DragState
drag : Float -> Float -> DragState -> Camera -> Float -> Camera  -- screenX screenY drag camera zoom
endDrag : ()  -- just set dragState to Nothing in Main
zoom : Float -> Float -> Float -> { width : Float, height : Float } -> Camera -> Camera
```

Or simpler — a single `CameraState` record with an `update` function:

```elm
type alias CameraState = { center : Vec2, zoom : Float, dragState : Maybe DragState }

type CameraMsg = StartDrag Float Float | Drag Float Float | EndDrag | Zoom Float Float Float

update : { width : Float, height : Float } -> CameraMsg -> CameraState -> CameraState
```

**Decision:** Use the `CameraMsg`/`update` approach. It's clean, self-contained, and Main just forwards messages. The `viewBox` calculation also moves here since it only depends on camera state and viewport size.

### 4. Simulation tick → `Simulation.elm`

**What moves:** The `Tick` handler body and its helpers `applySwitchEffect`, `rebuildIfBeforeTurnout`, `exitSpawnPoint`, `lastRouteSegment`, `spawnPointForRoute` (~155 lines).

**Challenge:** The tick touches many model fields: `gameTime`, `activeTrains`, `spawnedTrainIds`, `planningState.inventories`, `turnoutState`, `selectedTrainId`, `timeMultiplier`. Can't take `Model` (circular dep).

**Approach:** Define a single `SimState` record that carries everything the tick needs. The same type goes in and comes out:

```elm
type alias SimState =
    { timeMultiplier : Float
    , gameTime : GameTime
    , activeTrains : List ActiveTrain
    , spawnedTrainIds : Set Int
    , scheduledTrains : List ScheduledTrain
    , inventories : List SpawnPointInventory
    , turnoutState : SwitchState
    , selectedTrainId : Maybe Int
    }

tick : Float -> SimState -> SimState
tick deltaMs state = ...
```

`deltaMs` is the tick input (how much time passed), `SimState` is the world state being evolved — conceptually different things. A few fields in `SimState` (`timeMultiplier`, `scheduledTrains`) are only read and never modified by the tick, but a single type avoids unnecessary wiring in Main.

## Risks / Trade-offs

- **Boilerplate in Main.elm**: Each extracted module requires Main to pack/unpack state. This is the standard Elm trade-off for modularity. The total line count across all files will increase slightly, but Main.elm becomes a thin dispatch layer.
- **Planning.Update and Programmer.Update both operate on PlanningState**: This is fine — programmer state lives inside planning state. If that nesting ever feels wrong, it's a separate refactor to restructure the state tree.
- **Simulation.elm touches the most fields**: The `SimState` pattern is more ceremony than the others. Worth it because the tick logic is the most complex single function and will grow as features are added (collision detection, coupling, multi-train).
