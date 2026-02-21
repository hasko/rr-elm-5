# Main.elm Refactor Plan

Main.elm is 2024 lines. The main Elm loop (Model/Msg/update/view/subscriptions) stays, but these cohesive pieces can be extracted.

## Priority Order

### 1. Planning.Update (~275 lines)

Extract consist builder and scheduling update logic. Already have `Planning.Types` and `Planning.View` — this is the missing third leg.

Functions to move:
- `updateAddToConsist`
- `updateInsertInConsist`
- `updateRemoveFromConsist`
- `updateScheduleTrain`
- `updateSelectScheduledTrain`
- `updateRemoveScheduledTrain`

These all operate on `PlanningState` + `inventories`. Can be refactored to take/return `PlanningState` instead of `Model`.

### 2. Programmer.Update (~210 lines)

Same pattern as Planning. Types and View already exist.

Functions to move:
- `updateOpenProgrammer`
- `updateCloseProgrammer`
- `updateAddOrder`, `updateRemoveOrder`
- `updateMoveOrderUp`, `updateMoveOrderDown`
- `updateSelectProgramOrder`
- `updateSaveProgram`
- `updateProgrammerState` (generic helper)
- `removeAt`, `swapAt` (list utilities — could go to Util)

### 3. Camera.elm (~135 lines)

Self-contained, no game state dependencies beyond `viewportSize`.

Extract:
- `Camera` type
- `DragState` type
- StartDrag/Drag/EndDrag/Zoom update logic
- viewBox calculation (currently inline in `viewCanvas`)

### 4. Simulation.elm (~120 lines)

The `Tick` handler — core game loop. Hardest extraction because it orchestrates across trains, routes, spawning, planning state, and turnouts. Could be a single function taking Model and returning Model.

Extract:
- Tick update logic (time advance, spawn, execute, move, despawn, return stock)
- `applySwitchEffect`
- `rebuildIfBeforeTurnout`

## Current line map

```
 68-109   Model types                                         ~40 lines
112-220   Init + restore from storage                         ~110 lines
227-273   Msg type                                            ~50 lines
276-398   Tick handler (simulation loop)                      ~120 lines
400-468   TogglePlayPause, Element hover/click                ~65 lines
470-563   Camera: StartDrag, Drag, EndDrag, Zoom              ~95 lines
566-779   Planning/Programmer msg delegation                  ~210 lines
786-820   Effect helpers                                      ~35 lines
829-955   Storage helpers                                     ~125 lines
962-1237  Planning update helpers                             ~275 lines
1279-1486 Programmer update helpers                           ~210 lines
1511-1600 View layout routing                                 ~90 lines
1601-1713 Train info panel                                    ~110 lines
1716-1870 Header bar                                          ~155 lines
1873-2025 Canvas + grid + mouse decoders                      ~150 lines
```
