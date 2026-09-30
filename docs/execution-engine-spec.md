# Program Execution Engine Specification

This document specifies how trains execute their programs (sequences of orders) during simulation. The elm-programmer implements from this spec; the QA agent writes tests from it.

## 1. Execution State Model

### ActiveTrain Fields for Execution

The following fields on `ActiveTrain` support program execution:

| Field | Type | Purpose |
|-------|------|---------|
| `program` | `List Order` | The sequence of orders to execute |
| `programCounter` | `Int` | Index of the current order (0-based) |
| `trainState` | `TrainState` | Current execution state |
| `reverser` | `ReverserPosition` | Forward or Reverse |
| `waitTimer` | `Float` | Seconds remaining for WaitSeconds (0 when not waiting) |

Existing fields used by execution:

| Field | Type | Role in Execution |
|-------|------|-------------------|
| `position` | `Float` | Distance of lead car front along route (meters) |
| `speed` | `Float` | Current speed in m/s (always >= 0) |
| `route` | `Route` | The track path this train follows |
| `consist` | `List StockItem` | Cars in the train (needed for buffer stop safety margin) |

### TrainState

```
type TrainState
    = Executing         -- Actively running through the program
    | WaitingForOrders  -- Program complete or no program; coasting to stop
    | Stopped String    -- Halted due to error; String is the driver's message
```

### State Transitions

```
                   program assigned
    [spawn] ─────────────────────────► Executing
       │                                  │
       │ no program                       │ order unexecutable
       ▼                                  ▼
  WaitingForOrders ◄──────────────── Stopped "reason"
                     program complete      │
                     (counter past end)    │ (no automatic recovery)
                                           │
                                      [stays stopped until
                                       player intervenes]
```

Key rules:
- A train spawns as `Executing` if it has a non-empty program, `WaitingForOrders` otherwise.
- When `programCounter` reaches past the end of the program list, the train transitions to `WaitingForOrders`.
- `Stopped` is a terminal state for the current program execution. The train halts and displays the error message. No automatic recovery -- the player must intervene (future: re-program the train).
- A `WaitingForOrders` train with speed > 0 coasts to a stop using normal braking deceleration.

## 2. Physics Constants

| Constant | Value | Notes |
|----------|-------|-------|
| `acceleration` | 2.0 m/s^2 | Linear acceleration rate |
| `braking` | 3.0 m/s^2 | Normal braking deceleration |
| `emergencyBraking` | 5.0 m/s^2 | Buffer stop safety brake |
| `maxSpeed` | 11.11 m/s | ~40 km/h (40 * 1000 / 3600) |
| `arrivalThreshold` | 0.5 m | Distance below which train is "at" the target |

Speed is always stored as a non-negative value. Direction of travel is determined by the `reverser` field, not by the sign of speed.

## 3. Order Execution Specifications

### 3.1 MoveTo (SpotId)

**Purpose**: Move the train until the lead car front reaches the named spot.

**Preconditions**:
- The spot must be reachable on the train's current route.
- Route distance for the spot is obtained via `Route.spotPosition spotId train.route`.

**Behavior**:

1. Look up target distance on route via `spotPosition`. If `Nothing`, transition to `Stopped` with message `"Cannot reach <spotName>"`.

2. Compute signed distance to target:
   ```
   directionSign = if reverser == Forward then 1.0 else -1.0
   distanceToTarget = (targetDistance - position) * directionSign
   ```
   Positive means target is ahead in the travel direction.

   **Departing through a portal**: if the spot is a station portal at the end of the route the train is heading for (route end when `Forward`, route start when `Reverse`), the train does not stop there. It accelerates toward `maxSpeed` and keeps going; the order never completes and the train is despawned once it has fully left the track (section 7).

   **Car spotting**: `targetDistance = spotDistance + carCenterOffset`. If that lies outside `[0, route.totalLength]` (the consist is too long to spot that car there), transition to `Stopped "Cannot spot at <spotName>: not enough track"`.

3. Movement logic (each tick):
   - **Arrived** (`|distanceToTarget| < arrivalThreshold`): Snap position to `targetDistance`, set speed to 0, advance program counter.
   - **Target behind** (`distanceToTarget < 0`): The order can never complete in this direction. Transition to `Stopped "Cannot reach <spotName>: it is behind the train"`.
   - **Target ahead** (`distanceToTarget > 0`):
     - `newSpeed = min(speed + acceleration * dt, maxSpeed, sqrt(2 * braking * distanceToTarget))` -- never faster than can still be braked away in the remaining distance
     - `travelled = (oldSpeed + newSpeed) / 2 * dt`
     - If `travelled >= distanceToTarget - arrivalThreshold`, this tick reaches or crosses the target: snap to `targetDistance`, speed 0, advance. This makes arrival independent of the time step, so coarse ticks (high time multiplier, returning from a background tab) cannot overshoot.
     - Otherwise move by `travelled * directionSign`, then apply the buffer stop safety brake (section 4).

**Postconditions on completion**:
- `position` is exactly `targetDistance`
- `speed` is 0
- `programCounter` is incremented

**Error cases**:
- Spot not on route: `Stopped "Cannot reach <spotName>"`
- Spot behind the train: `Stopped "Cannot reach <spotName>: it is behind the train"`
- Car cannot be spotted within the track: `Stopped "Cannot spot at <spotName>: not enough track"`

### 3.2 SetReverser (ReverserPosition)

**Purpose**: Change the locomotive's direction of travel.

**Preconditions**: None. This is an instant order.

**Behavior**: Set `train.reverser` to the specified position. Advance program counter immediately.

**Important design note**: Changing the reverser does NOT change the route. The train continues on the same route but moves in the opposite direction along it. This means a forward-moving train becomes a backward-moving train on the same path.

For future consideration: when turnout state changes between a MoveTo and the next reversal, the route should be rechecked. But for MVP, the route is fixed at spawn time.

**Postconditions**:
- `reverser` updated
- `programCounter` incremented
- No effects produced

**Error cases**: None.

### 3.3 SetSwitch (String, SwitchPosition)

**Purpose**: Command a turnout to change position. This is a world-state side effect.

**Preconditions**: None for MVP. The switch ID is a string identifier.

**Behavior**: Emit a `SetSwitchEffect switchId switchPosition` effect. Advance program counter immediately.

The execution engine does NOT apply the effect itself. It returns the effect in the `List Effect`, and Main.elm applies it to the world state. This keeps the execution engine pure.

**Postconditions**:
- `programCounter` incremented
- Effect list contains `SetSwitchEffect switchId switchPosition`

**Error cases**: None for MVP. Future: invalid switch ID, switch locked by route, switch occupied by train.

**Main.elm effect application**:
```
SetSwitchEffect _ Normal    -> turnoutState = Normal
SetSwitchEffect _ Diverging -> turnoutState = Reverse
```

### 3.4 WaitSeconds (Int)

**Purpose**: Pause program execution for the specified number of game-time seconds.

**Preconditions**: None. The train should be stopped (but this is not enforced -- the wait will hold speed at 0).

**Behavior**:

1. On the first tick of this order (`waitTimer <= 0`): initialize `waitTimer` to `toFloat seconds`.
2. Each tick: decrement `waitTimer` by `deltaSeconds`.
3. When `waitTimer <= 0`: set `waitTimer` to 0, set `speed` to 0, advance program counter.
4. While waiting: `speed` is forced to 0.

**Postconditions on completion**:
- `waitTimer` is 0
- `speed` is 0
- `programCounter` incremented

**Error cases**: None.

### 3.5 Couple

**Purpose**: Couple to an adjacent standing consist (cars left on the track by a previous Uncouple).

**Current status**: NOT YET IMPLEMENTED. Requires standing consist tracking on the map.

**MVP behavior**: Immediately transition to `Stopped "Couple: no adjacent cars found"`. This is the "driver asks for instructions" pattern -- the train stops and the player sees the error in the status panel.

**Future specification** (for when standing consists are implemented):

1. Check for a standing consist within coupling distance (e.g., 2m) in the current travel direction.
2. If found: merge the standing consist into the train's consist (append to the appropriate end based on travel direction). Remove the standing consist from the map.
3. If not found: `Stopped "Couple: no adjacent cars found"`.

**Coupling distance**: The gap between the last car of the train and the first car of the standing consist must be <= coupler reach distance (approximately 2m, to be tuned).

**Direction matters**: Coupling happens at the end of the train that faces the travel direction. If reverser is Forward, couple at the front (position end). If reverser is Reverse, couple at the rear.

### 3.6 Uncouple (Int)

**Purpose**: Split the consist after the n-th car from the locomotive. The detached cars become a standing consist on the track.

**Current status**: NOT YET IMPLEMENTED. Requires standing consist tracking on the map.

**MVP behavior**: Immediately transition to `Stopped "Uncouple: not yet supported"`.

**Future specification**:

1. The `Int` parameter specifies how many cars to keep (counting from the locomotive). Example: `Uncouple 1` with consist `[Loco, Coach, Flatcar]` keeps `[Loco, Coach]` and detaches `[Flatcar]`.
2. The detached cars become a standing consist at their current position on the track.
3. The train's consist is updated to only include the kept cars.
4. The standing consist does not move -- it stays at the exact track position where it was uncoupled.
5. Speed must be 0 to uncouple. If speed > 0, transition to `Stopped "Cannot uncouple while moving"`.
6. If `n >= length(consist)`, there's nothing to detach: `Stopped "Nothing to uncouple"`.
7. If `n < 1`, that would detach the locomotive: `Stopped "Cannot detach locomotive"`.

## 4. Auto-Braking: Buffer Stop Safety

Trains must automatically emergency-brake before hitting a buffer stop at the end of their route.

### Detection

Each tick, compute:
```
bufferStopDistance = route.totalLength - train.position
emergencyBrakeDist = (speed^2) / (2 * emergencyBraking)
```

Moving forward, the head leads, so only the head's stopping distance matters; no consist-length margin is added (it made trains crawl the last ~25 m to spots near the buffer).

### Application

Only applies when:
- Reverser is `Forward` (moving toward higher position values, toward the route end)
- The route ends at a buffer stop, not a station portal (`Route.routeEndStation` is `Nothing`); trains run out through portals
- `bufferStopDistance < emergencyBrakeDist`
- `speed > 0`

When triggered:
```
brakedSpeed = max(0, speed - emergencyBraking * dt)
avgSpeed = (speed + brakedSpeed) / 2
newPos = position + avgSpeed * dt
clampedPos = min(newPos, route.totalLength)  -- Hard clamp: never exceed route
```

### Important Notes

- The route start is always the spawn portal, so a reversing train is never braked there; it backs out through the portal and despawns.
- This safety brake overrides the MoveTo speed calculation. The buffer stop brake is applied AFTER the normal movement calculation.
- The hard clamp ensures the train can never exceed `route.totalLength` even with floating point drift.

## 5. Program Advancement

When an order completes, the program counter advances:

```
nextCounter = programCounter + 1
if nextCounter >= length(program):
    trainState = WaitingForOrders
else:
    programCounter = nextCounter (trainState stays Executing)
```

Instant orders (SetReverser, SetSwitch) advance within the same tick. Non-instant orders (MoveTo, WaitSeconds) advance on the tick where their completion condition is met.

## 6. Coast to Stop / Run Through

A `WaitingForOrders` train with **no program** runs through at constant speed in its reverser direction: out through the exit portal (then despawned), or brought to a stand by the buffer stop brake on a route that ends at a buffer.

A `WaitingForOrders` train whose program has **finished** and whose speed > 0 decelerates to a stop:

```
newSpeed = max(0, speed - braking * dt)
avgSpeed = (oldSpeed + newSpeed) / 2
position = position + avgSpeed * directionSign * dt
```

This uses normal braking, not emergency braking. The buffer stop brake still applies; nothing else clamps the position, so a train still inside the entry tunnel (negative position) is not teleported onto the track.

## 7. Integration with Main.elm Tick Handler

Each simulation tick processes in this order:

1. **Cap delta time**: `cappedDeltaMs = min(deltaMs, 100)` -- prevents teleportation when returning from a background tab.
2. **Scale time**: `scaledDeltaSeconds = (cappedDeltaMs / 1000) * timeMultiplier`
3. **Advance simulation clock**: `elapsedSeconds += scaledDeltaSeconds`
4. **Spawn new trains**: Check scheduled trains against elapsed time. New trains get routes built from current switch state.
5. **Execute programs**: Call `Execution.stepProgram scaledDeltaSeconds` on every active train. Collect `(updatedTrain, List Effect)` pairs.
6. **Apply effects**: Fold all effects into world state (switch effects update turnout state).
7. **Despawn check**: Remove trains that have exited the track (`Movement.shouldDespawn`): a forward train once its last car is past `route.totalLength`, a reversing train once its head is back behind position 0.
8. **Stock return**: Return despawned trains' consist items to the exit station's inventory (the spawn station for trains that backed out).
9. **Update model**: Apply all changes.

All movement happens in `Execution.stepProgram`; there is no second movement pass.

### Effect Types

Currently only one effect type:

```
type Effect = SetSwitchEffect String SwitchPosition
```

Future effects might include: `PlaySoundEffect`, `ShowMessageEffect`, `SpawnStandingConsistEffect`, etc.

## 8. Error Message Conventions

Error messages follow the pattern: `"<OrderName>: <reason>"`. These are displayed to the player as the "driver asking for instructions."

| Situation | Message |
|-----------|---------|
| MoveTo unreachable spot | `"Cannot reach <spotName>"` |
| MoveTo spot behind the train | `"Cannot reach <spotName>: it is behind the train"` |
| MoveTo car spot needs track past the end | `"Cannot spot at <spotName>: not enough track"` |
| Couple with no adjacent cars | `"Couple: no adjacent cars found"` |
| Uncouple not yet supported | `"Uncouple: not yet supported"` |
| Future: uncouple while moving | `"Cannot uncouple while moving"` |
| Future: nothing to uncouple | `"Nothing to uncouple"` |
| Future: can't detach loco | `"Cannot detach locomotive"` |

## 9. Test Cases for QA

### Instant Orders
- SetReverser updates reverser field and advances programCounter in one tick
- SetSwitch produces SetSwitchEffect and advances programCounter in one tick
- Two consecutive instant orders execute across two ticks (one per tick)

### MoveTo
- Train accelerates from rest toward a reachable spot
- Train brakes to stop at the target (position snaps to targetDistance)
- Train on mainline cannot reach PlatformSpot (stops with error)
- Target behind the train stops with an error
- Coarse time steps (e.g. 0.8 s) never overshoot: arrival from every start position
- MoveTo a portal at the route end departs and despawns; reversing to the spawn portal backs out and despawns

### WaitSeconds
- Timer initializes on first tick, decrements each tick
- Speed forced to 0 during wait
- Advances when timer expires

### Couple / Uncouple
- Both immediately stop with error message (MVP behavior)
- Speed set to 0

### Program Flow
- Empty program: train is WaitingForOrders at spawn
- Program completion: last order finishes, trainState becomes WaitingForOrders
- Multi-order sequence: orders execute in order across ticks

### Coast to Stop / Run Through
- Finished-program train with speed > 0 decelerates
- WaitingForOrders train with speed 0 stays put
- Programless train keeps constant speed, is not teleported out of the tunnel, and despawns at the exit portal
- Programless train on a siding stops at the buffer

### Stopped State
- Stopped train stays stopped (speed 0, same error message) on subsequent ticks

### Buffer Stop Safety
- Train approaching route end triggers emergency braking
- Train position never exceeds route.totalLength
- Only applies in Forward direction on routes ending at a buffer (not a portal)
