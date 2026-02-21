## Context

The sawmill layout defines two tunnel portals with element IDs `TunnelPortalId` (left/low-X, labeled "West Station") and `WestTunnelPortalId` (right/high-X, labeled "East Station"). The `ElementClicked` handler in Main.elm maps these to `SpawnPointId` values — currently backwards.

## Goals / Non-Goals

**Goals:**
- Clicking the west tunnel portal selects `WestStation`
- Clicking the east tunnel portal selects `EastStation`

**Non-Goals:**
- Renaming the confusing element IDs (`TunnelPortalId`, `WestTunnelPortalId`) — separate cleanup

## Decisions

### 1. Swap SpawnPointId in click handlers only

Swap the two `selectedSpawnPoint` assignments in the `ElementClicked` handler. No other files need changes — the map labels and planning panel are already correct.
