# Sawmill Puzzle

The first puzzle introduces core mechanics: consist planning, switching, and scheduling.

## Story

A small sawmill needs rail service:
- Workers arrive in the morning and leave in the evening
- Lumber is loaded onto flatcars during the day
- Empty flatcars must be delivered, loaded ones picked up

The mainline runs east-west with a single siding serving the sawmill. The lumber receiver (a furniture factory) is located at East Station, so all trains originate there and travel westward to the sawmill.

## Track Layout

```
EAST                                                           WEST

═══════════════════════════╗═══════════════════════════════════════════
Tunnel Portal               ║╲                                    Mainline
"East Station"              ║ ╲                                  (continues,
                            ║  ╲                                  no traffic
                                 ║                                in MVP)
                                 ║
                            ┌────┴────┐
                            │Platform │  ← Passenger spot
                            └────┬────┘
                                 ║
                            ┌────┴────┐
                            │  Team   │  ← Freight spot
                            │  Track  │
                            └────┬────┘
                                 ║
                                 ╨
                              Buffer
```

### Turnout Details

- **Type**: Standard 15°, 170m radius
- **Orientation**: Toe faces EAST (facing turnout for eastbound trains)
- **Normal route**: Continues west on mainline
- **Reverse route**: Diverges south into siding

### Spots

| Spot | Type | Track Position | Capacity |
|------|------|----------------|----------|
| Platform | Passenger | Siding, ~50m from turnout | 1 coach |
| Team Track | Freight | Siding, ~100m from turnout | 2 cars |
| East Station | Tunnel | Mainline, east end | N/A (spawn point) |

### Distances

- Turnout to Platform: ~50m
- Platform to Team Track: ~50m
- Team Track to Buffer: ~20m
- Total siding length: ~120m

## Available Rolling Stock

| ID | Type | Notes |
|----|------|-------|
| loco-1 | Locomotive | Standard switcher |
| coach-1 | Coach | For workers |
| flat-1 | Flatcar | For lumber |

## Initial State

All rolling stock is available at East Station (off-map, through the tunnel portal).

### Consist Planning UI

Before starting the simulation, the player uses the **consist planning screen** to:

1. Arrange the available cars in the desired order
2. Position the locomotive (which end of the consist)
3. Set the locomotive's initial reverser position
4. Assign the morning schedule and departure time

The train formation itself is not simulated - it happens "off-screen" at the imaginary East Station. This focuses the puzzle on the on-map switching operations while still requiring the player to think ahead about consist order.

## Task Requirements

### Morning Run (depart ~06:30, arrive sawmill ~06:45)

1. Deliver empty flatcar to team track
2. Deliver workers (coach to platform)
3. Return locomotive and coach to East Station

### Evening Run (depart East Station ~17:00, arrive sawmill ~17:15)

1. Pick up loaded flatcar from team track
2. Pick up workers (coach at platform)
3. Return full consist to East Station

### Schedule

| Day | Morning | Evening |
|-----|---------|---------|
| Mon-Fri | Run | Run |
| Sat-Sun | No service | No service |

**Goal**: Complete 5 days (Mon-Fri) without delays.

## Solution

### Consist Order (via planning UI)

In the consist planning screen at East Station, arrange the cars as:

```
[Loco]═══[Coach]═══[Flatcar]
   ↑                    ↑
East end            West end
(at spawn)        (leads when pushing)
```

Set reverser to **Reverse** (train will move westward, pushing).

The locomotive is at the east end so it can:
- Push the consist into the siding (flatcar leads)
- Pull back out with the coach

### Morning Schedule

```
 1. SetSwitch turnout Reverse        -- Align for siding
 2. SetReverser Reverse              -- Loco will push (move west)
 3. MoveTo platform                  -- Push in, coach at platform
 4. WaitSeconds 60                   -- Workers disembark
 5. MoveTo teamTrack                 -- Push flatcar to team track
 6. Uncouple 1                       -- Detach flatcar
 7. SetReverser Forward              -- Loco will pull (move east)
 8. MoveTo eastStation               -- Pull coach back to tunnel
 9. SetSwitch turnout Normal         -- Clear mainline (good practice)
```

### Evening Schedule

```
 1. SetSwitch turnout Reverse        -- Align for siding
 2. SetReverser Reverse              -- Push into siding
 3. MoveTo teamTrack                 -- Coach reaches flatcar
 4. Couple                           -- Attach loaded flatcar
 5. SetReverser Forward              -- Pull toward mainline
 6. MoveTo platform                  -- Spot coach at platform
 7. WaitSeconds 60                   -- Workers board
 8. MoveTo eastStation               -- Depart with full consist
 9. SetSwitch turnout Normal         -- Clear mainline
```

## Success Criteria

- All 5 morning runs completed (flatcar spotted, workers delivered)
- All 5 evening runs completed (flatcar retrieved, workers picked up)
- No collisions
- No significant delays (train arrives within 10 minutes of scheduled time)

## Failure Conditions

- Wrong consist order (can't complete switching moves)
- Missed schedule (train doesn't depart on time)
- Forgot to set switch (train takes wrong route)
- Hit buffer stop at speed (incident)

## Learning Objectives

This puzzle teaches:
1. **Consist planning**: Car order matters for switching
2. **Reverser operation**: Understanding loco direction
3. **Switch alignment**: Explicit turnout control
4. **Spotting**: Positioning cars at specific locations
5. **Coupling/uncoupling**: Splitting and joining consists
6. **Scheduling**: Sequencing orders correctly

## Future Variations

- **Sawmill+**: Same layout but with mainline traffic to avoid
- **Busy Sawmill**: Multiple flatcars, more complex spotting
- **Two Sidings**: Add a runaround track for more flexibility
