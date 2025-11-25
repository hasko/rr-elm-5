# Game Design

## Time Model

- **Pausable real-time**: Game runs continuously but can be paused
- **Track building**: Only allowed in pause mode
- **Game time**: Simulated clock (e.g., 06:00 - 22:00 for a day)
- **Future**: Speed controls (0.5x, 1x, 2x, 4x)

## Rolling Stock

### Types

| Type | Purpose | Typical Length | Typical Weight (empty/loaded) |
|------|---------|----------------|-------------------------------|
| Locomotive | Provides motive power | 20m | 80t / 80t |
| Coach | Passenger transport | 15m | 30t / 35t |
| Boxcar | General freight | 12m | 20t / 60t |
| Flatcar | Lumber, machinery | 12m | 15t / 55t |
| Brake car | Braking assist | 10m | 15t / 15t |

### Properties

Each piece of rolling stock has:
- **Length**: End-to-end measurement in meters
- **Axle distance**: Distance between truck centers (for curve rendering)
- **Weight (empty)**: Tare weight in tonnes
- **Weight (loaded)**: Gross weight when carrying cargo
- **Max speed**: Maximum safe operating speed

### Locomotive Properties

Locomotives additionally have:
- **Tractive effort**: Pulling/pushing force
- **Braking power**: Deceleration capability
- **Orientation**: Physical direction on track (doesn't change without wye/turntable)
- **Reverser position**: Forward or Reverse (determines movement direction relative to orientation)

## Consists

A **consist** is a group of coupled rolling stock. Properties:
- Ordered list of cars (coupling order matters)
- Total length (sum of car lengths + coupler gaps)
- Total weight (sum of car weights)
- Can be split (uncouple) and joined (couple)

## Trains

A **train** is:
- A consist with at least one locomotive
- A position on the track
- A current order (or idle)
- A schedule (sequence of orders)

## Orders

Orders are explicit commands. The train does not auto-route or auto-align switches.

### Movement Orders

| Order | Description |
|-------|-------------|
| `MoveTo spot` | Move until lead car/loco reaches the specified spot |
| `MoveDistance meters` | Move a specific distance in current direction |
| `Stop` | Halt immediately |

### Locomotive Orders

| Order | Description |
|-------|-------------|
| `SetReverser Forward` | Movement toward loco's front |
| `SetReverser Reverse` | Movement toward loco's rear |

### Switching Orders

| Order | Description |
|-------|-------------|
| `SetSwitch id Normal` | Set turnout to main route |
| `SetSwitch id Reverse` | Set turnout to diverging route |

### Coupling Orders

| Order | Description |
|-------|-------------|
| `Couple` | Couple to adjacent car |
| `Uncouple n` | Uncouple after n-th car from locomotive |

### Timing Orders

| Order | Description |
|-------|-------------|
| `WaitSeconds n` | Pause execution for n seconds (game time) |
| `WaitUntil time` | Wait until specified game time |

## Spots

A **spot** is a named location on a track, used as a destination for orders.

### Spot Types

| Type | Purpose |
|------|---------|
| `Platform` | Passenger boarding/alighting |
| `TeamTrack` | Freight loading/unloading |
| `Storage` | Car storage |
| `Tunnel` | Entry/exit point to off-map locations |

### Spot Properties

- **Position**: Location on track (track ID + distance along track)
- **Capacity**: How many cars can be spotted here
- **Purpose**: Determines what operations occur (loading, passengers, etc.)

## Spawn Points

Trains enter the map from **spawn points** (tunnel portals). These represent connections to imaginary off-map locations (stations, yards).

A spawn point has:
- Position and direction on track
- Name (e.g., "East Station")
- Available rolling stock (assigned by the puzzle)

## Consist Planning (Off-Map)

Train formation happens at off-map stations through a **management UI**, not through simulated switching:

1. Player opens the consist planning screen for a spawn point
2. Available rolling stock is shown (locomotives, cars)
3. Player arranges cars in the desired order (drag-and-drop or similar)
4. Player sets the locomotive's initial reverser position
5. Player assigns a schedule and departure time
6. Train spawns from the tunnel portal when departure time arrives

This abstraction keeps the focus on the on-map switching puzzle while still requiring the player to think about consist order. The puzzle context determines which spawn point receives which stock (e.g., "the lumber receiver is connected to East Station, so trains form there").

## Schedules

A **schedule** is a timed sequence of orders, like a mini-program:

```
Morning Run (depart 06:30):
  1. SetSwitch mainTurnout Reverse
  2. SetReverser Reverse
  3. MoveTo platform
  4. WaitSeconds 60
  5. MoveTo teamTrack
  6. Uncouple 1
  7. SetReverser Forward
  8. MoveTo eastTunnel
  9. SetSwitch mainTurnout Normal
```

The player creates schedules for each service. Schedules can be triggered by time or manually.

## Physics (Simplified)

### Movement

- Acceleration depends on: tractive effort / total train weight
- Heavier trains accelerate slower
- Maximum speed limited by slowest car in consist

### Braking

- Deceleration depends on: total braking power / total train weight
- Heavier trains need more distance to stop
- Brake cars add braking power to the train

### No Gradients (MVP)

The MVP assumes flat terrain. No grades, no momentum from hills.

## Puzzle Structure

Each puzzle provides:
- **Track layout**: Pre-built mainline and sidings
- **Available stock**: What rolling stock the player can use
- **Tasks**: What needs to be accomplished (deliveries, passenger service)
- **Duration**: How many game-days to run
- **Success criteria**: No delays, no incidents, specific delivery counts

The player solves the puzzle by:
1. Planning consists (car order, loco position)
2. Writing schedules (order sequences)
3. Running the simulation successfully
