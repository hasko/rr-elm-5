## Why

Clicking a tunnel portal on the map opens the planning panel with the wrong station selected. The left portal (labeled "West Station") selects `EastStation` internally, and the right portal ("East Station") selects `WestStation`. The map labels are correct (west is left, east is right), but the click handler wiring is backwards.

## What Changes

- Swap the `SpawnPointId` assigned in the two tunnel portal click handlers in Main.elm so `TunnelPortalId` (left/west portal) selects `WestStation` and `WestTunnelPortalId` (right/east portal) selects `EastStation`
- Update the comments on those handlers to match

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

_(none — this is a two-line bug fix)_

## Impact

- `src/Main.elm` — `ElementClicked` handler for `TunnelPortalId` and `WestTunnelPortalId`
