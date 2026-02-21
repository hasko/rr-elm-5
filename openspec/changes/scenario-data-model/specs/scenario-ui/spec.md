## ADDED Requirements

### Requirement: Station selector driven by scenario data

The planning panel SHALL display one button per station defined in the scenario, using the station's `name` field as the button label. No station names are hardcoded.

#### Scenario: Two-station scenario
- **WHEN** the sawmill scenario loads with stations "Millville" (id: east) and "Lumber Junction" (id: west)
- **THEN** the station selector shows two buttons labeled "Millville" and "Lumber Junction"

#### Scenario: Station selection shows correct stock
- **WHEN** the player selects station "Millville" which has 1 locomotive and 2 coaches
- **THEN** the stock display shows locomotive (1) and coach (2), and no other stock types

### Requirement: Stock display from scenario inventory

The stock display SHALL show only stock types that have at least one item at the selected station, with counts derived from the scenario's station stock data. Stock types with zero count are not shown.

#### Scenario: Station with mixed stock
- **WHEN** station "west" has stock `[{type: "locomotive", count: 1}, {type: "flatbed", count: 1}, {type: "coach", count: 1}]`
- **THEN** the stock display shows locomotive (1), flatbed (1), and coach (1)

#### Scenario: Stock decreases as cars are scheduled
- **WHEN** 1 of 2 coaches has been added to a scheduled consist
- **THEN** the stock display shows coach (1) for the remaining available count

### Requirement: Stock type visuals from lookup table

Stock type rendering (SVG side-profile in consist builder, on-map car appearance) SHALL use a hardcoded Elm lookup table that maps well-known stock type strings to their visual representations. Unknown stock types SHALL use a generic fallback visual.

#### Scenario: Known stock type rendering
- **WHEN** a car with stock type "locomotive" is rendered
- **THEN** the locomotive SVG side-profile is used in the consist builder and the locomotive appearance is used on the map

#### Scenario: Unknown stock type fallback
- **WHEN** a car with stock type "tank-car" is rendered and no visual is defined for "tank-car"
- **THEN** a generic car visual is used as a fallback

### Requirement: Consist builder shows departure direction, not station name

The consist builder SHALL show a directional indicator (arrow) communicating which end of the consist is the front (departure direction). It SHALL NOT display a destination station name.

#### Scenario: Departure direction shown
- **WHEN** the player is building a consist at any station
- **THEN** the consist builder shows an arrow indicating the departure direction (outward from the station portal) and does not mention any destination station name

#### Scenario: Direction is consistent with portal orientation
- **WHEN** a station's portal faces left on the map
- **THEN** the departure arrow points left, indicating trains depart in that direction

### Requirement: Spot names from scenario data

Spot names displayed in the programmer and on the map SHALL come from the scenario's spot `name` field. No spot names are hardcoded.

#### Scenario: Sawmill spots
- **WHEN** the sawmill scenario defines spots "Platform" (id: platform) and "Team Track" (id: team-track)
- **THEN** the programmer shows "Platform" and "Team Track" as spot destinations, and the map labels show these names

### Requirement: Portal labels from scenario data

Tunnel portal labels on the map SHALL display the linked station's `name` from the scenario data.

#### Scenario: Portal shows station name
- **WHEN** the east portal is linked to station "Millville"
- **THEN** the map renders "Millville" as the tunnel portal label

### Requirement: Scenario metadata display

The app SHALL display the scenario name and the game time range (start time to end time) derived from the scenario's metadata fields.

#### Scenario: Sawmill metadata
- **WHEN** the sawmill scenario loads with name "Morning Run", startTime "06:00", endTime "07:00"
- **THEN** the UI displays "Morning Run" and the clock shows time starting at 06:00 with the scenario ending at 07:00
