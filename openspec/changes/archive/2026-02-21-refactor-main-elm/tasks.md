## 1. Utilities

- [x] 1.1 Create `src/Util/List.elm` with `removeAt` and `swapAt` functions (moved from Main.elm)

## 2. Camera module

- [x] 2.1 Create `src/Camera.elm` with `Camera`, `DragState`, `CameraState`, `CameraMsg` types and `update` function
- [x] 2.2 Move `viewBox` calculation into `Camera.elm`
- [x] 2.3 Update Main.elm to use `Camera.update` for StartDrag, Drag, EndDrag, Zoom messages
- [x] 2.4 Run `npx elm-test` — all Elm unit tests pass

## 3. Planning.Update module

- [x] 3.1 Create `src/Planning/Update.elm` with functions taking and returning `PlanningState`: `addToConsist`, `insertInConsist`, `removeFromConsist`, `scheduleTrain`, `selectScheduledTrain`, `removeScheduledTrain`
- [x] 3.2 Update Main.elm to delegate planning messages to `Planning.Update` and wrap with `{ model | planningState = ... }`
- [x] 3.3 Run `npx elm-test` — all Elm unit tests pass

## 4. Programmer.Update module

- [x] 4.1 Create `src/Programmer/Update.elm` with functions taking and returning `PlanningState`: `openProgrammer`, `closeProgrammer`, `addOrder`, `removeOrder`, `moveOrderUp`, `moveOrderDown`, `selectProgramOrder`, `saveProgram`
- [x] 4.2 Update Main.elm to delegate programmer messages to `Programmer.Update` and wrap with `{ model | planningState = ... }`
- [x] 4.3 Run `npx elm-test` — all Elm unit tests pass

## 5. Simulation module

- [x] 5.1 Create `src/Simulation.elm` with `SimState` type and `tick : Float -> SimState -> SimState` function
- [x] 5.2 Move `applySwitchEffect`, `rebuildIfBeforeTurnout`, `exitSpawnPoint`, `lastRouteSegment`, `spawnPointForRoute` into `Simulation.elm`
- [x] 5.3 Update Main.elm Tick handler to pack `SimState`, call `Simulation.tick`, and unpack result
- [x] 5.4 Run `npx elm-test` — all Elm unit tests pass

## 6. Final verification

- [x] 6.1 Remove any dead code remaining in Main.elm
- [x] 6.2 Run Playwright E2E tests — all pass without modification (4 pre-existing failures, same as before refactor)
