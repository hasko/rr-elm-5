# Track Geometry

## Coordinate System

- **World coordinates**: Meters, origin at map center (or corner TBD)
- **X axis**: West (-) to East (+)
- **Y axis**: North (+) to South (-) (or screen-style: North (-) to South (+) TBD)
- **Angles**: Radians, 0 = East, counter-clockwise positive

## Track Segments

### Straight

A straight segment connects two points in a line.

Properties:
- Start point (x, y)
- End point (x, y)
- Length (derived)

### Curve

A curve is an arc of a circle with a fixed radius.

Properties:
- Center point (x, y)
- Radius: 170m (tight) or 300m (standard)
- Start angle
- End angle (arc length derived)
- Direction: Clockwise or Counter-clockwise

### Standard Radii

| Radius | Use |
|--------|-----|
| 170m | Tight curves, turnout diverging routes |
| 300m | Standard curves, mainline |

These match common model railroad set-track proportions scaled to real meters.

## Turnouts (Switches/Points)

A turnout allows a train to diverge from one track to another.

### Anatomy

```
            A (toe/points)
            │
            │
        ────┼────────── B (normal route / heel)
             ╲
              ╲
               ╲
                C (reverse/diverging route)
```

- **Point A (toe)**: The single-track end where switch blades are located
- **Point B (heel, normal)**: Continues straight (main route)
- **Point C (heel, reverse)**: Diverges at an angle (diverging route)

### Facing vs Trailing

The distinction depends on approach direction:

**Facing movement** (approaching the toe):
```
    Train ──────►─────┬────────
                       ╲
                        ╲
```
- Train approaches the points (A)
- Can choose to go straight (B) or diverge (C)
- Switch position determines route

**Trailing movement** (approaching a heel):
```
                ──────┬───────◄────── Train
                       ╲
                        ╲
```
- Train approaches from B or C
- Merges into the single track at A
- Switch must be aligned correctly or train takes wrong route/derails

### Turnout Properties

| Property | Description |
|----------|-------------|
| Position | World coordinates of the toe (point A) |
| Orientation | Angle the toe faces (direction of approach for facing moves) |
| Diverge angle | Angle of the curve (15° standard) |
| Radius | Radius of diverging curve (170m standard) |
| State | Normal (straight) or Reverse (diverging) |
| Length | Track length through the turnout (~30-40m typical) |

### Standard Turnout

For MVP, we use one turnout type:
- **Diverge angle**: 15°
- **Radius**: 170m
- **Length**: ~35m

### Connection Points

Each turnout has three connection points for linking to other track segments:
- **Toe (A)**: Single track end
- **Normal heel (B)**: Straight-through end
- **Reverse heel (C)**: Diverging end

## Track Ends

### Buffer Stop

A fixed end-of-track with a bumper. Trains must stop before hitting it.

Properties:
- Position on track
- Visual: bumper/barrier graphic

### Tunnel Portal

An open end leading to an imaginary off-map location. Trains can enter/exit here.

Properties:
- Position and direction on track
- Name of destination (e.g., "East Station")
- Acts as spawn/despawn point

## Track Layout (Graph)

The track forms a graph:
- **Nodes**: Connection points (turnout ends, segment ends, buffer stops, portals)
- **Edges**: Track segments (straights, curves)

Trains traverse edges between nodes. At turnouts, the switch state determines which edge is active.

## Position on Track

A position on the layout is represented as:
- **Track segment ID**: Which segment
- **Distance**: Meters from segment start (0 to segment length)
- **Direction**: Which way along the segment (for orientation)

Or alternatively:
- **Edge ID + offset** in the graph representation

## Car Positioning on Curves

Cars have two axles (truck centers) at a fixed distance. On curves:
- Each axle follows the track independently
- Car body spans between axles
- Car center may be inside or outside the curve
- This creates the realistic "chord" effect on tight curves

```
        Track curve
          ╭───────╮
         ╱         ╲
        │   ┌───┐   │  ← Car body (chord)
        │   │   │   │
         ╲  └───┘  ╱
          ╰───────╯
              ↑
        Axles follow track
```

### Axle Distance

| Car Type | Typical Axle Distance |
|----------|----------------------|
| Locomotive | 12m |
| Coach | 10m |
| Freight car | 7m |

## Rendering Scale

- **World units**: Meters
- **View scale**: Configurable zoom (e.g., 1 pixel = 0.5m at default zoom)
- **Zoom levels**: Discrete steps for cleaner rendering at different scales
