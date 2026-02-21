## Why

Scenario data is hardcoded across 7 source files — station names, inventories, track geometry, spot positions, portal mappings, route entry points, and exit detection all live in different places with no shared source of truth. This caused a cascade of East/West mismatch bugs when display names were swapped. Adding a new scenario currently means editing every one of these files.

Scenarios should live in JSON files, loaded at runtime. Each file fully describes its track layout, stations, stock, spots, and goals. The engine computes geometry, renders the map, and drives the simulation from this data — with zero hardcoded scenario knowledge.

## What Changes

- **Scenario JSON format**: Define a schema for scenario files covering track graph (nodes + edges), stations (name, portal, stock), spots (on edges), goals (car type + location + optional origin + flavor text), and metadata (name, description, start/end time).
- **HTTP loader**: Fetch scenario JSON at startup (or on selection) using `Http.get`.
- **JSON decoders**: Elm decoders for all scenario types (track nodes, edges, stations, spots, goals, stock).
- **Scenario data module**: A `Scenario` type that the engine consumes — replaces `SpawnPointId` enum, `initPlanningState` hardcoded inventories, and all scattered element ID references.
- **Track layout from graph**: Build track geometry by walking the node/edge graph from an anchor point at (0,0) orientation 0, using existing `Element.elm` geometry math.
- **Planning UI driven by scenario data**: Station buttons, stock display, and spot names all read from the loaded scenario. No hardcoded strings.
- **Consist builder direction indicator**: Replace the "towards East Station" / "towards West Station" label with a directionality arrow showing departure direction. No station name in the consist builder.
- **Goal system**: Track car visits to locations during simulation. Goals verified against visit history and end-state positions.
- **Remove hardcoded sawmill data**: Delete `Sawmill/Layout.elm` procedural track building, `SpawnPointId` enum, hardcoded inventories, portal-to-station mappings, `destinationLabel`, scattered `ElementId` checks in Simulation and Route modules.
- **Sawmill scenario JSON file**: Recreate the current sawmill puzzle as the first JSON scenario file.

## Capabilities

### New Capabilities

- `scenario-loading`: HTTP fetching and JSON decoding of scenario files into typed Elm data
- `scenario-track-layout`: Building track geometry from a graph of nodes and edges
- `scenario-goals`: Goal definition, tracking car visits during simulation, and verification at scenario end
- `scenario-ui`: Planning UI (stations, stock, consist builder, spots) driven by scenario data instead of hardcoded values

### Modified Capabilities

_(no existing specs affected — this replaces hardcoded data with data-driven equivalents)_

## Impact

- **New files**: `Scenario.elm` (types + decoders), `Scenario/Layout.elm` (graph → track geometry), scenario JSON file(s) in `public/scenarios/`
- **Major rewrites**: `Planning/Types.elm` (remove `SpawnPointId`, derive from scenario), `Planning/View.elm` (station buttons, stock, consist builder label), `Simulation.elm` (exit point detection from scenario data), `Train/Route.elm` (route building from scenario graph, spot locations from scenario)
- **Deleted**: `Sawmill/Layout.elm` (replaced by data-driven layout), hardcoded inventories in `initPlanningState`
- **Changed**: `Main.elm` (load scenario on init, pass scenario through model, portal click handlers use scenario data)
- **Runtime dependency**: Scenario JSON must be fetched before the app can render — need a loading state
