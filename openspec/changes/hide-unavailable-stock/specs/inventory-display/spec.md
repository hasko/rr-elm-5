## ADDED Requirements

### Requirement: Only available stock types are shown

The stock inventory panel SHALL only display stock types that have at least one item available at the currently selected station. Stock types with 0 items SHALL NOT appear.

#### Scenario: East Station shows 3 types
- **WHEN** the player views East Station inventory (which has Locomotive, PassengerCar, Flatbed)
- **THEN** exactly 3 stock type items are displayed

#### Scenario: West Station shows 2 types
- **WHEN** the player views West Station inventory (which has Locomotive, Boxcar)
- **THEN** exactly 2 stock type items are displayed

#### Scenario: Unavailable type is hidden
- **WHEN** East Station has no Boxcar items
- **THEN** no Boxcar entry appears in the inventory panel
