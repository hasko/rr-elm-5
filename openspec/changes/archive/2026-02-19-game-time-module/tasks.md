## 1. Create Util/GameTime.elm

- [x] 1.1 Create `src/Util/GameTime.elm` with type alias, constructors (`fromDayHourMinute`, `fromHourMinute`), decomposer (`toDayHourMinute`), and formatters (`formatTime`, `formatDayTime`)
- [x] 1.2 Create `tests/GameTimeTest.elm` with tests for construction, decomposition, and formatting

## 2. Update Planning/Types.elm

- [x] 2.1 Remove `DepartureTime` type and its export
- [x] 2.2 Import `Util.GameTime` and change `ScheduledTrain.departureTime` to `GameTime`
- [x] 2.3 Update `initPlanningState` — scheduled trains (if any defaults exist) use `GameTime.fromDayHourMinute`

## 3. Update Main.elm

- [x] 3.1 Remove local `GameTime` type alias, import `Util.GameTime exposing (GameTime)`
- [x] 3.2 Update `model.gameTime` field to use the shared `GameTime` type (just a `Float` now, no more `{ elapsedSeconds }` wrapper)
- [x] 3.3 Update all `model.gameTime.elapsedSeconds` references to just `model.gameTime`
- [x] 3.4 Update `viewGameTime` to use `GameTime` formatting helpers
- [x] 3.5 Update train scheduling code to use `GameTime.fromDayHourMinute` when creating/editing trains
- [x] 3.6 Update train editing to use `GameTime.toDayHourMinute` to populate pickers

## 4. Update Planning/View.elm

- [x] 4.1 Replace `formatDepartureTime` with `GameTime.formatDayTime`
- [x] 4.2 Replace inline sort formula with direct `GameTime` comparison (transparent Float, so `List.sortBy .departureTime` just works)

## 5. Update Train/Spawn.elm

- [x] 5.1 Remove `departureTimeToSeconds` function and TODO comment
- [x] 5.2 Compare `GameTime` values directly (both are `Float` now)

## 6. Update Storage.elm

- [x] 6.1 Replace `encodeDepartureTime`/`decodeDepartureTime` with plain float encode/decode
- [x] 6.2 Update `SavedState.gameTime` to use the shared type
- [x] 6.3 Remove `DepartureTime` import

## 7. Update tests

- [x] 7.1 Update `tests/PlanningTypesTest.elm` — remove `DepartureTime` references
- [x] 7.2 Update `tests/TrainTest.elm` — use `GameTime` for departure times
- [x] 7.3 Update `tests/StorageTest.elm` — use `GameTime` for departure times

## 8. Verify

- [x] 8.1 Run `elm make` — no errors
- [x] 8.2 Run `elm-test` — all 634 tests pass
- [x] 8.3 Manual check: sim clock displays correctly, trains spawn at right times
