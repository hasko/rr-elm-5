- Do NOT restart the dev server after compiles. The vite dev server is able to auto-reload. Only when there is a confirmed issue with the vite server itself is it necessary to restart.

## Coordinate System

The simulation uses a clockwise angle convention:
- 0° = North (up, -Y on screen)
- 90° = West (right, +X on screen)
- Angles increase clockwise

Key functions in `Util/Vec2.elm`:
- `fromAngle(θ)` returns `(sin θ, -cos θ)`
- `angle(v)` returns `atan2(x, -y)`

## Track System

Track elements are defined in `src/Track/`:
- `Element.elm` - Types and geometry computation
- `Layout.elm` - Layout builder and connection tracking
- `Render.elm` - SVG rendering
- `Validation.elm` - Connection continuity checks

### Connector Convention

Each connector has a position and orientation. The orientation points **outward** - the direction a train would travel if it exited through that connector.

For a straight track from A to B:
- connector0 at A, orientation points away from B (back toward where you came from)
- connector1 at B, orientation points away from A (forward in travel direction)

The track extends in the **travel direction** (opposite of connector0's orientation).

### Element Types

- `StraightTrack length` - 2 connectors
- `CurvedTrack { radius, sweep }` - 2 connectors, positive sweep = clockwise
- `Turnout { throughLength, radius, sweep, hand }` - 3 connectors (toe, through, diverge)
- `TrackEnd` - 1 connector (buffer stops, tunnel portals)