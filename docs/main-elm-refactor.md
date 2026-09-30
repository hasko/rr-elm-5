# Main.elm Refactor

Main.elm was 2024 lines. The original plan extracted four cohesive pieces;
all four are done:

| Module             | Owns                                                        |
| ------------------ | ----------------------------------------------------------- |
| `Planning.Update`  | Consist builder, time picker, consist panning, scheduling   |
| `Programmer.Update`| Program editing (orders, reorder, save)                     |
| `Camera`           | Camera/drag types, pan and zoom update, viewBox             |
| `Simulation`       | Tick loop: time, spawn, execute, move, despawn, switches    |

Main.elm now keeps the TEA skeleton (Model, Msg, init, update, view,
subscriptions), scenario loading, storage glue, and map/overlay views. The
planning and programmer `Msg` branches are one-line delegations.

## Remaining ideas

- **Group `Msg`** into sub-types (`PlanningMsg`, `ProgrammerMsg`, `CameraMsg`,
  …) so each module owns its own `update` and Main only maps.
- **Single editing session.** An edit in progress is spread over
  `editingTrainId`, `editingTrainProgram`, `panelMode = ProgrammerView id` and
  `programmerState.trainId`. A single `Maybe EditingSession` would rule out the
  "leave the editor and the train disappears" class of bugs.
- **Map view.** The canvas is still drawn from the legacy `Sawmill.Layout`;
  it should render from the scenario layout (phase 16) so that editing the
  scenario JSON moves the drawn track as well as the trains.
