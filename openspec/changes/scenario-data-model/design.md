## Context

Scenario data is scattered across 7 files with hardcoded values. The app currently uses `Browser.element` with `Program (Maybe String) Model Msg` — init receives saved state from localStorage, not scenario data. Track layout is procedurally built in `Sawmill/Layout.elm`. Planning state is initialized in `Planning/Types.initPlanningState` with hardcoded `SpawnPointId` enum and inventories.

## Goals / Non-Goals

**Goals:**
- Scenarios defined in JSON files, loaded via HTTP
- Track layout computed from a node/edge graph — no hardcoded geometry
- All station names, stock, spots, and goals driven by scenario data
- Consist builder shows departure direction, not station names
- Sawmill puzzle recreated as the first JSON scenario
- Test coverage for JSON decoding, layout computation, and goal verification

**Non-Goals:**
- Scenario picker UI (just load the sawmill scenario)
- Scenario completion flow (win screen, next puzzle)
- User-created scenarios or scenario editor
- Multiplayer or scenario sharing

## Decisions

### 1. Scenario type as a first-class value threaded through the app

A `Scenario` record loaded from JSON and stored in `Model`. All modules that need scenario data receive it as a parameter — no global state, no hardcoded fallbacks.

```
Model = { scenario : Scenario, ... }
```

Alternative: store scenario data in multiple places (planning state, simulation state, etc). Rejected — single source of truth prevents the cross-file mismatch problem we're fixing.

### 2. Two-phase init: Loading → Ready

The app starts in a `Loading` state, fires an HTTP request for the scenario JSON, then transitions to `Ready` with the loaded scenario. The current `defaultModel` becomes a function of `Scenario`.

```
type AppState
    = Loading
    | LoadFailed String
    | Ready Model

init : () -> ( AppState, Cmd Msg )
```

This replaces the current `Program (Maybe String)` flags approach. Saved state restore (localStorage) can be layered back in later — for now the scenario JSON is the sole init source.

Alternative: embed the scenario JSON in the Elm bundle or as a flag. Rejected — HTTP loading is the target architecture for multiple scenarios, and it's not much more complex.

### 3. String IDs everywhere, no enums

Station IDs, spot IDs, node IDs, stock type names — all strings from the JSON. The `SpawnPointId` enum (`EastStation | WestStation`) and `StockType` enum (`Locomotive | PassengerCar | ...`) get replaced with strings.

This means station buttons, stock displays, and goal checks all work with string lookups into the scenario data. Type safety comes from the `Scenario` record structure, not from union types.

Alternative: generate Elm union types from JSON. Rejected — overly complex, and string IDs are the natural representation for data-driven content.

### 4. Track graph: nodes and edges with geometry attributes

```
Node: { id, type (portal|turnout|buffer), properties }
Edge: { from, to, type (straight|curve), length/radius/sweep, port, spots }
```

The engine walks the graph from the first portal node at (0,0) orientation 0, computing positions using existing `Track.Element` geometry math. Each edge becomes one or more track elements. Turnout nodes become turnout elements with through/diverge ports mapping to edges.

The existing `Track.Layout` module (connection tracking, connector lookup) stays — it's engine code, not scenario data. What changes is how elements are created: from graph data instead of `Sawmill/Layout.elm`.

### 5. Goals as visit records checked at scenario end

During simulation, the engine records "car X of type T visited location L at time T, having previously been at origin O." At scenario end, each goal is checked against the visit log.

A goal `{ what: "coach", from: "east", at: "platform" }` is satisfied if any coach visited "platform" having most recently been at "east" (or departed from "east" station).

Visit tracking is append-only during simulation — a list of events, not mutable state on each car.

### 6. Consist builder shows a departure arrow, not station name

The `destinationLabel` function is removed. The consist builder shows a directional indicator (arrow or "← departs" label) to communicate which end is the front. The station name is already visible in the station selector above — no need to repeat or guess a destination.

## Risks / Trade-offs

- **String IDs lose compile-time safety** → Mitigated by decoder validation (reject unknown IDs at load time) and thorough test coverage for the sawmill scenario.
- **HTTP loading adds a failure mode** → `LoadFailed` state shows an error message. For now just one hardcoded URL; failure is unlikely in practice.
- **Graph layout algorithm complexity** → The sawmill layout is simple (4 nodes, 3 edges). The walker only needs to handle straight segments, curves, and turnout fan-out. No need for a general graph layout solver — just depth-first traversal from the anchor node.
- **Breaking saved state** → Existing localStorage saves won't load since `Model` changes fundamentally. Accept this — reset saved state on this version.

## Open Questions

- **Stock type rendering**: Currently each stock type has a hardcoded SVG side-profile in the view. With string-based stock types, how do we map type names to visuals? Options: (a) a finite set of known visual styles the JSON picks from, (b) SVG data in the JSON itself. Leaning toward (a) — a lookup table of known car appearances.
- **Turnout state in scenarios with multiple turnouts**: The current model has a single `turnoutState : SwitchState`. With multiple turnouts from the graph, this needs to become a `Dict String SwitchState` keyed by turnout node ID. This is a natural extension but affects the simulation tick and programmer order types.
