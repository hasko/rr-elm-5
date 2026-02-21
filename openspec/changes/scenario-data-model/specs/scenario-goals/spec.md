## ADDED Requirements

### Requirement: Visit tracking during simulation

The simulation SHALL record visit events when a car arrives at a location (station or spot). Each visit event records the car id, stock type, location id, game time, and the car's most recent origin (the station it departed from).

#### Scenario: Car arrives at a spot
- **WHEN** a coach that departed from station "east" stops at spot "platform" during simulation
- **THEN** a visit event is recorded: `{ carId, stockType: "coach", location: "platform", origin: "east", time }`

#### Scenario: Car arrives at a station (exits through portal)
- **WHEN** a flatbed exits through the portal linked to station "west"
- **THEN** a visit event is recorded: `{ carId, stockType: "flatbed", location: "west", origin: <previous station>, time }`

#### Scenario: Car departs from a station
- **WHEN** a car spawns from station "east" (enters through the east portal)
- **THEN** the car's current origin is set to "east" so that subsequent visits record where it came from

### Requirement: Visit log is append-only

The visit log SHALL be an append-only list of events accumulated during simulation. No visit events are modified or removed once recorded.

#### Scenario: Multiple visits by same car
- **WHEN** a coach departs from "east", stops at "platform", then continues to "west"
- **THEN** the visit log contains two entries for that car: one at "platform" with origin "east", and one at "west" with origin "east"

### Requirement: Goal verification at scenario end

At scenario end time, each goal SHALL be checked against the visit log. A goal is satisfied if at least one visit event matches the goal's criteria.

#### Scenario: Directional goal satisfied
- **GIVEN** a goal `{ what: "coach", from: "east", at: "west" }`
- **WHEN** the visit log contains a visit by a coach at location "west" with origin "east"
- **THEN** the goal is marked as satisfied

#### Scenario: Directional goal not satisfied — wrong origin
- **GIVEN** a goal `{ what: "coach", from: "east", at: "west" }`
- **WHEN** the visit log contains a visit by a coach at "west" but with origin "west" (round trip)
- **THEN** the goal is not satisfied

#### Scenario: Non-directional goal satisfied
- **GIVEN** a goal `{ what: "flatbed", at: "team-track" }`
- **WHEN** the visit log contains a visit by a flatbed at "team-track" from any origin
- **THEN** the goal is marked as satisfied regardless of where the flatbed came from

#### Scenario: Goal not satisfied — wrong stock type
- **GIVEN** a goal `{ what: "coach", at: "platform" }`
- **WHEN** only locomotives have visited "platform"
- **THEN** the goal is not satisfied

### Requirement: Goal count matching

When multiple goals require the same stock type at the same location, each goal SHALL be matched by a distinct visit event. A single visit cannot satisfy multiple identical goals.

#### Scenario: Two coaches needed at west station
- **GIVEN** two goals both requiring `{ what: "coach", from: "east", at: "west" }`
- **WHEN** only one coach from "east" visited "west"
- **THEN** only one of the two goals is satisfied

#### Scenario: Two coaches delivered
- **GIVEN** two goals both requiring `{ what: "coach", from: "east", at: "west" }`
- **WHEN** two distinct coaches from "east" visited "west"
- **THEN** both goals are satisfied

### Requirement: Goal display with flavor text

Each goal SHALL be displayed to the player with its `flavor` text and a status indicator (pending/satisfied). Goals SHALL be visible during the scenario so the player can track progress.

#### Scenario: Goals shown at start
- **WHEN** the sawmill scenario loads with 4 goals
- **THEN** all 4 goals are displayed with their flavor text and pending status

#### Scenario: Goal becomes satisfied during play
- **WHEN** a coach from "east" arrives at "west" during simulation
- **THEN** the corresponding goal's status updates from pending to satisfied in the UI
