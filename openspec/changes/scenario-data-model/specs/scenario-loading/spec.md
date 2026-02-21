## ADDED Requirements

### Requirement: HTTP scenario loading

The app SHALL fetch a scenario JSON file via HTTP on startup and transition from a loading state to a ready state with the parsed scenario.

#### Scenario: Successful load
- **WHEN** the app starts and the scenario JSON is fetched successfully
- **THEN** the JSON is decoded into a `Scenario` record and the app enters the ready state with the scenario data available to all modules

#### Scenario: Load failure
- **WHEN** the scenario JSON fetch fails (network error, 404, etc.)
- **THEN** the app enters a `LoadFailed` state and displays an error message

#### Scenario: Decode failure
- **WHEN** the scenario JSON is fetched but contains invalid or malformed data
- **THEN** the app enters a `LoadFailed` state with a descriptive decode error message

### Requirement: Scenario JSON structure

The scenario JSON SHALL contain the following top-level fields: `name` (string), `description` (string), `startTime` (string HH:MM), `endTime` (string HH:MM), `track` (object with `nodes` and `edges`), `stations` (array), and `goals` (array).

#### Scenario: Decode complete sawmill scenario
- **WHEN** the sawmill scenario JSON is decoded
- **THEN** the resulting `Scenario` record contains name "Morning Run", 4 track nodes, 3 track edges, 2 stations with stock, 2 spots, and 4 goals

### Requirement: JSON decoder for track nodes

Each track node SHALL have an `id` (string) and a `type` (one of `"portal"`, `"turnout"`, `"buffer"`). Turnout nodes SHALL additionally have `hand` (`"left"` or `"right"`), `radius` (float), and `sweep` (float, degrees).

#### Scenario: Decode portal node
- **WHEN** a JSON object `{"id": "e-portal", "type": "portal"}` is decoded
- **THEN** the result is a portal node with id "e-portal"

#### Scenario: Decode turnout node
- **WHEN** a JSON object `{"id": "t1", "type": "turnout", "hand": "right", "radius": 170, "sweep": 15}` is decoded
- **THEN** the result is a turnout node with id "t1", right hand, radius 170, sweep 15 degrees

#### Scenario: Reject unknown node type
- **WHEN** a JSON object with `"type": "bridge"` is decoded
- **THEN** the decoder fails with a descriptive error

### Requirement: JSON decoder for track edges

Each track edge SHALL have `from` (node id), `to` (node id), and `type` (one of `"straight"`, `"curve"`). Straight edges SHALL have `length` (float). Curve edges SHALL have `radius` (float) and `sweep` (float, degrees). Edges from turnout nodes SHALL have a `port` field (`"through"` or `"diverge"`). Edges MAY have a `spots` array.

#### Scenario: Decode straight edge
- **WHEN** a JSON object `{"from": "e-portal", "to": "t1", "type": "straight", "length": 250}` is decoded
- **THEN** the result is a straight edge of length 250 from "e-portal" to "t1"

#### Scenario: Decode edge with spots
- **WHEN** a JSON edge includes `"spots": [{"id": "platform", "at": 60, "name": "Platform"}]`
- **THEN** the decoded edge contains one spot with id "platform" at distance 60

#### Scenario: Decode turnout through edge
- **WHEN** a JSON edge from a turnout node includes `"port": "through"`
- **THEN** the decoded edge is marked as the through route of that turnout

### Requirement: JSON decoder for stations

Each station SHALL have `id` (string), `name` (string), `portal` (node id reference), and `stock` (array of `{type, count}` objects).

#### Scenario: Decode station with stock
- **WHEN** a JSON station `{"id": "east", "name": "Millville", "portal": "e-portal", "stock": [{"type": "locomotive", "count": 1}, {"type": "coach", "count": 2}]}` is decoded
- **THEN** the result is a station with id "east", name "Millville", linked to portal "e-portal", with 1 locomotive and 2 coaches

### Requirement: JSON decoder for goals

Each goal SHALL have `what` (stock type string) and `at` (location id — a station id or spot id). Goals MAY have a `from` (station id) for directional demand. Goals SHALL have a `flavor` (string) for display text.

#### Scenario: Decode directional goal
- **WHEN** a JSON goal `{"what": "coach", "from": "east", "at": "west", "flavor": "Morning commuters"}` is decoded
- **THEN** the result is a goal requiring a coach from station "east" at station "west"

#### Scenario: Decode non-directional goal
- **WHEN** a JSON goal `{"what": "flatbed", "at": "team-track", "flavor": "Spot for loading"}` is decoded
- **THEN** the result is a goal requiring a flatbed at spot "team-track" with no origin constraint
