# Railroad Switching Puzzle Game

A browser-based railroad game focusing on realistic switching operations, written in Elm with SVG graphics.

## Core Philosophy

Most railroad games treat trains as monolithic units that reverse instantly with locomotives magically changing orientation. This game takes a different approach:

- **Individual rolling stock**: Locomotives, coaches, and freight cars are separate resources with their own properties
- **Realistic switching**: Trains can be split and coupled. Cars can be pushed while uncoupled. Locomotives maintain their physical orientation on the track
- **Simplified physics**: Heavy loads are harder to pull, heavy trains are harder to brake. Weight and length matter
- **Operational puzzles**: The challenge is planning track layouts and schedules to accomplish tasks efficiently

## Gameplay

The player is presented with a scenario (e.g., serve a sawmill) with:
- A pre-built mainline with tunnel portals leading to imaginary off-map stations
- A task requiring freight and/or passenger service
- Available rolling stock to form consists

The player must:
1. Plan the consist order (which cars, in what sequence, loco position)
2. Write schedules (sequences of orders for each run)
3. Execute operations without delays or incidents

## MVP Scope

**First puzzle: Sawmill**
- Single-track mainline with one facing turnout
- One siding with platform (passengers) and team track (freight)
- Morning run: deliver empty flatcar, drop passengers
- Evening run: pick up loaded flatcar and passengers
- Goal: Complete a week of operations

**Technical MVP:**
- Elm + SVG, browser only
- Mouse input
- Pausable real-time (track operations in pause mode)
- Single train operation
- Save/load to localStorage and file export

## Running the Game

```bash
# Install dependencies
npm install

# Development server
npm run dev

# Build for production
npm run build
```

## Project Structure

```
src/
├── Main.elm              -- Application entry, Model/Msg/update/view
├── Track/                -- Track geometry, segments, switches, layout
├── Rolling/              -- Rolling stock types, consists, physics
├── Train/                -- Train state, orders, schedules
├── World/                -- World state, simulation tick
├── Puzzle/               -- Puzzle definitions, goals, scenarios
├── Ui/                   -- Camera, controls, rendering helpers
└── Util/                 -- Vec2, transforms, JSON helpers

docs/
├── game-design.md        -- Core mechanics and concepts
├── track-geometry.md     -- Track math, turnout orientation
└── sawmill-puzzle.md     -- First puzzle specification
```

## Future Enhancements

- Multiple simultaneous trains
- Mainline traffic to schedule around
- Collision detection and automatic braking
- More track elements: crossings, double-slips, wyes
- Time acceleration/deceleration
- Curve easing
- Level editor
- Procedural puzzle generation

## License

TBD
