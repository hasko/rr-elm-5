# Elm Architecture Review

Review of the Railroad Switching Puzzle codebase for idiomatic Elm patterns and TEA compliance.

**Reviewed files:** All 22 `.elm` files under `src/`.

---

## 1. TEA Compliance

### Overall structure: Good

The `Main.elm` module follows canonical TEA:
- `main` uses `Browser.element` with `init`, `update`, `subscriptions`, `view` (line 53-60)
- `Model` is a plain record (line 90-113)
- `Msg` is a union type covering all events (line 232-272)
- `update` returns `( Model, Cmd Msg )` (line 275)
- Ports are correctly declared at module level (lines 41-48)

### Issue: Stringly-typed GameMode and SwitchState in SavedState

`Storage.SavedState` stores `mode` and `turnoutState` as `String` (lines 25-26). The `restoreModel` function in `Main.elm` (lines 157-224) manually pattern-matches these strings back to union types. This creates a silent failure path: an unrecognized string falls through to a default.

**Recommendation:** Either:
- Store these as their union types and use proper encoders/decoders that roundtrip through the custom types, or
- At minimum, add the encoder/decoder pair inside `Storage.elm` so the string mapping is localized to one module.

### Issue: Msg type is flat and large

The `Msg` type has 30+ variants (lines 232-272). This is a single flat namespace for game simulation, camera control, planning UI, programmer UI, train selection, and storage. While not a correctness issue, it makes the update function 400+ lines and harder to navigate.

**Recommendation:** Consider grouping related messages under sub-types:
```elm
type Msg
    = PlanningMsg PlanningMsg
    | ProgrammerMsg ProgrammerMsg
    | SimulationMsg SimulationMsg
    | CameraMsg CameraMsg
    | StorageMsg StorageMsg
```
Each sub-module would own its own `update` function that returns `( subModel, Cmd subMsg )`, mapped in `Main.update`.

---

## 2. Pure Functions

### Good: All logic is pure

The codebase is fully pure outside of the two ports (`saveToStorage`, `clearStorage`). Side effects are correctly handled through `Cmd`:
- Storage saves go through port commands via `SaveTick` (line 674)
- Animation uses `Browser.Events.onAnimationFrameDelta` subscription (line 1453)
- No `Debug.log` or other impure calls detected

### Good: Extracted helpers are pure

`Planning.Helpers`, `Train.Movement`, `Train.Execution`, `Train.Route`, `Train.Spawn`, and `Train.Stock` are all pure modules with no dependencies on Browser or ports.

---

## 3. Type Safety

### Good: Extensive use of custom types

- `SpawnPointId` (`EastStation | WestStation`) instead of strings (`src/Planning/Types.elm:29-31`)
- `StockType` (`Locomotive | PassengerCar | Flatbed | Boxcar`) (`src/Planning/Types.elm:36-40`)
- `TrainState` (`Executing | WaitingForOrders | Stopped String`) (`src/Train/Types.elm:21-24`)
- `Order` union type for all train commands (`src/Programmer/Types.elm:43-49`)
- `ElementId` is a proper wrapper type (`src/Track/Element.elm:44-45`)
- `Hand` (`LeftHand | RightHand`) for turnout divergence (`src/Track/Element.elm:49-51`)

### Issue: SwitchState exists in two places

`Sawmill.Layout.SwitchState` (Normal | Reverse) at `src/Sawmill/Layout.elm:63-65` and `Programmer.Types.SwitchPosition` (Normal | Diverging) at `src/Programmer/Types.elm:36-38` represent the same concept with different names. The mapping between them happens in `Main.applySwitchEffect` (lines 686-696). This is a semantic gap that could cause bugs.

**Recommendation:** Unify into a single type, or make the mapping explicit in a single place with documentation explaining why two representations exist (if the distinction is intentional).

### Issue: SetSwitch uses String for switch identification

`Order.SetSwitch String SwitchPosition` (`src/Programmer/Types.elm:46`) uses a `String` to identify switches. Currently the only value is `"main"`, and the `applySwitchEffect` function in `Main.elm` (line 689) ignores the switch ID entirely with a wildcard `_`. If a second switch is ever added, this will silently apply effects to the wrong switch.

**Recommendation:** Replace with a `SwitchId` union type:
```elm
type SwitchId = MainSwitch
```

### Issue: Inventory lookup by SpawnPointId is always a linear search

Throughout the codebase, inventories are stored as `List SpawnPointInventory` and looked up via:
```elm
inventories |> List.filter (\inv -> inv.spawnPointId == spawnId) |> List.head
```
This pattern appears in `Main.elm` (lines 880-882, 916-920, 960-964), `Planning.Helpers` (line 25-26), and `Planning.View` (lines 317-320).

**Recommendation:** Use `Dict SpawnPointId SpawnPointInventory` (requires making `SpawnPointId` comparable, e.g., via a wrapper). Alternatively, since there are only two spawn points, a record `{ east : Inventory, west : Inventory }` would be simpler and eliminate the impossible "not found" case.

---

## 4. Module Organization

### Good: Clear domain separation

The module tree is well-organized:
- `Track/` - Track geometry and layout (Element, Layout, Render, Validation)
- `Train/` - Train simulation (Types, Route, Movement, Execution, Spawn, Stock, View)
- `Planning/` - UI state and planning logic (Types, View, Helpers)
- `Programmer/` - Program editor (Types, View)
- `Sawmill/` - Puzzle-specific layout and view (Layout, View)
- `Util/` - Shared utilities (Vec2, Transform)

### Issue: Main.elm is a God module (1924 lines)

`Main.elm` contains:
- All 30+ Msg variants
- All update logic (lines 276-678, ~400 lines)
- Planning helpers (lines 860-1222, ~360 lines)
- Programmer helpers (lines 1225-1440, ~215 lines)
- View code including the train info panel (lines 1464-1924, ~460 lines)
- Utility functions like `removeAt`, `swapAt`, `lastRouteSegment` (lines 1404-1440, 843-853)

**Recommendation:** Extract:
1. `updateAddToConsist`, `updateInsertInConsist`, `updateRemoveFromConsist`, `updateScheduleTrain`, `updateSelectScheduledTrain`, `updateRemoveScheduledTrain` into `Planning.Update` or expand `Planning.Helpers`
2. `updateOpenProgrammer`, `updateCloseProgrammer`, `updateAddOrder`, `updateRemoveOrder`, `updateMoveOrderUp`, `updateMoveOrderDown`, `updateSelectProgramOrder`, `updateSaveProgram` into `Programmer.Update`
3. `viewTrainInfoPanel` into `Train.View`
4. `removeAt`, `swapAt` into a `Util.List` module
5. `lastRouteSegment` duplicates `lastElement` in `Train.Route` (line 651-661) -- consolidate

### Issue: Sawmill.Layout has a dual ElementId

`Sawmill.Layout.ElementId` (line 41-47) is a separate type from `Track.Element.ElementId` (line 44-45). The former is for interactive UI elements (TunnelPortalId, TurnoutId, etc.), the latter is for track geometry elements (ElementId Int). They serve different purposes but having two `ElementId` types in the project is confusing. `Sawmill.Layout` re-exports its own `ElementId` which shadows `Track.Element.ElementId` wherever both are imported.

**Recommendation:** Rename `Sawmill.Layout.ElementId` to something like `InteractiveElementId` or `UiElementId`.

---

## 5. Elm Idioms

### Good: Pipeline style

The codebase makes good use of pipelines for data transformation:
```elm
-- src/Train/Spawn.elm:24-27
scheduledTrains
    |> List.filter (\train -> shouldSpawn train elapsedSeconds spawnedIds)
    |> List.map (createActiveTrain switchState)
```

### Good: Pattern matching

Exhaustive pattern matching on union types is used throughout. The compiler enforces completeness.

### Good: Maybe/Result handling

`Maybe` is used appropriately for optional values. The `Storage` module uses `Result` (via `Decode.decodeString`) for JSON parsing with a graceful fallback to defaults (Main.elm:120-126).

### Issue: Repeated `List.filter + List.head` pattern

Finding items by ID is done via `List.filter (\x -> x.id == id) |> List.head` throughout:
- `Main.elm:1146, 1199, 1553`
- `Track.Layout.elm:136-138`
- `Sawmill.Layout.elm:224-229, 232-237, 252-257`

**Recommendation:** Use `List.Extra.find` from `elm-community/list-extra`, or define a local `find` helper:
```elm
find : (a -> Bool) -> List a -> Maybe a
find pred list =
    case list of
        [] -> Nothing
        x :: xs -> if pred x then Just x else find pred xs
```

### Issue: Repeated index-based list operations

`getItemAt`, `removeAt`, `swapAt` are all O(n) index-based operations on lists. This is acceptable for small lists (consist items, program orders), but the patterns are duplicated:
- `getItemAt` in `Planning.View` (line 496-500)
- `removeAt` in `Main.elm` (line 1404-1406)
- `swapAt` in `Main.elm` (line 1411-1439)
- `getOrder` in `Train.Execution` (line 284-288) is equivalent to `getItemAt`

**Recommendation:** Consolidate these into a `Util.List` module.

### Issue: Planning.Helpers uses exposing (..)

`Planning.Helpers` imports `Planning.Types exposing (..)` (line 14). While convenient, this obscures which types are actually used.

**Recommendation:** Use explicit imports: `import Planning.Types exposing (SpawnPointId, SpawnPointInventory, StockItem, StockType)`.

---

## 6. Performance

### Good: No obvious O(n^2) patterns in hot paths

The tick handler (`Tick` message, Main.elm:278-397) is the hot path. It:
1. Maps over `activeTrains` (O(n))
2. Folds effects (O(effects))
3. Conditionally rebuilds routes (O(n * segments))
4. Filters for despawning (O(n))
5. Updates inventories (O(despawned * inventory))

With a small number of trains (likely <10), this is fine.

### Issue: Route rebuilding on every switch change

When the turnout state changes, `rebuildIfBeforeTurnout` (Main.elm:706-718) is called for every active train. Each call to `Route.rebuildRoute` walks the entire track graph. With the current small layout (8 elements), this is negligible, but the pattern doesn't scale.

### Issue: `walkGraph` appends to accumulator list with ++

In `Train.Route.walkGraph` (line 150):
```elm
(accSegments ++ [ segment ])
```
This is O(n) per step, making the full walk O(n^2) where n is the number of segments. With the current layout (~5-7 segments per route), this is fine, but idiomatic Elm would cons to the front and reverse at the end:
```elm
walkGraph ... (segment :: accSegments) ...
-- then at the end:
List.reverse accSegments
```

### Issue: `Layout.findElement` and `Layout.findConnected` are linear searches

`Layout.findElement` (line 134-138) and `Layout.findConnected` (line 153-174) do linear scans. With 8 elements and ~8 connections, this is negligible. If the layout grew significantly, a `Dict ElementId PlacedElement` would be appropriate.

### Good: `positionOnRoute` and `findSegmentAndInterpolate` are efficient

These use early-exit recursion over segments (Train.Route.elm:458-484), stopping as soon as the containing segment is found.

---

## 7. Specific Suggestions

### 7.1 Extract a `Tick` update module

The `Tick` handler (Main.elm:278-397) is 120 lines of deeply nested `let` bindings. This is the most complex single function in the codebase. Extracting it into a `Simulation.Update` or `Game.Tick` module would improve readability.

### 7.2 Use `Cmd.map` for sub-module commands

Currently all update helpers return `Model` instead of `( Model, Cmd Msg )`. This works because none of them produce commands, but it breaks the TEA convention and makes it harder to add effects later. For example:
```elm
ScheduleTrain ->
    ( updateScheduleTrain model, Cmd.none )
```
If `updateScheduleTrain` ever needs to produce a command (e.g., play a sound), the signature must change. Consider making all update helpers return `( Model, Cmd Msg )` from the start.

### 7.3 Consolidate `lastElement` / `lastRouteSegment`

`Main.lastRouteSegment` (line 843-853) and `Train.Route.lastElement` (line 651-661) are identical functions. Use one shared implementation.

### 7.4 Consolidate `stockTypeTestId`

`stockTypeTestId` is defined identically in both `Planning.View` (line 424-437) and `Train.View` (line 96-109). Extract to `Planning.Types` alongside `stockTypeName`.

### 7.5 Consider using `Util.Transform` in view code

`Util.Transform` is defined but appears unused in the actual view code. `Sawmill.View`, `Train.View`, and `Main.viewCanvas` all construct transform strings manually. Either use the utility or remove it.

### 7.6 The `reverseRoute` function is defined but not exposed

`Train.Route.reverseRoute` (line 395-416) and `reverseGeometry` (line 421-437) are defined but not in the module's `exposing` list (line 1-9) and not called anywhere. These are dead code.

**Recommendation:** Remove them, or expose them if they're planned for future use (with a TODO comment).

### 7.7 Nested record updates are verbose

The codebase has many instances of the pattern:
```elm
let planning = model.planningState
in { model | planningState = { planning | field = value } }
```
This is a known Elm pain point (no nested record update syntax). The current approach is idiomatic and correct. Consider extracting helper functions like `mapPlanningState : (PlanningState -> PlanningState) -> Model -> Model` to reduce boilerplate:
```elm
mapPlanningState : (PlanningState -> PlanningState) -> Model -> Model
mapPlanningState f model =
    { model | planningState = f model.planningState }
```

### 7.8 View functions pass too many arguments positionally

`viewConsistBuilder` in `Planning.View` (line 503) takes 8 arguments. `viewScheduleControls` takes 6 arguments. These are hard to read and easy to mis-order.

**Recommendation:** Use config records (as already done for `viewPlanningPanel` and `viewProgrammerPanel`):
```elm
viewConsistBuilder :
    { builder : ConsistBuilder
    , spawnPoint : SpawnPointId
    , onAddFront : msg
    , onAddBack : msg
    , ...
    }
    -> Html msg
```

---

## 8. Summary

| Category | Rating | Notes |
|----------|--------|-------|
| TEA Compliance | Good | Canonical structure, correct Cmd/Sub handling |
| Pure Functions | Excellent | All logic is pure, side effects only through ports |
| Type Safety | Good | Strong use of union types; minor issues with String-typed fields |
| Module Organization | Needs Work | Main.elm is overloaded; some duplicate code across modules |
| Elm Idioms | Good | Pipelines, pattern matching, Maybe handling are idiomatic |
| Performance | Fine for now | No blocking issues at current scale; some O(n^2) patterns to watch |

### Top 5 action items (ordered by impact):

1. **Split Main.elm** -- Extract planning update logic, programmer update logic, and train info panel view into their respective module directories
2. **Unify SwitchState/SwitchPosition** -- Eliminate the dual representation of switch state
3. **Replace String switch IDs** with a `SwitchId` union type in `Programmer.Types`
4. **Consolidate duplicate functions** -- `lastElement`/`lastRouteSegment`, `stockTypeTestId`, `getItemAt`/`getOrder`
5. **Remove dead code** -- `reverseRoute`, `reverseGeometry` in `Train.Route`; unused `Util.Transform` module; `pointsToPath` in `Sawmill.View` (line 560-564)
