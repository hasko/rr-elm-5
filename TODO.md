# Implementation Progress

## Phase 1: Project Setup & Foundation
- [x] 1.1 Build Configuration
  - [x] Create `elm.json` with dependencies
  - [x] Create `package.json` with dev scripts
  - [x] Create `index.html` shell
  - [x] Verify `npm run dev` works
- [x] 1.2 Core Utilities
  - [x] `src/Util/Vec2.elm` - 2D vector operations
  - [x] `src/Util/Transform.elm` - SVG transform helpers
- [x] 1.3 Application Shell
  - [x] `src/Main.elm` - Browser.element with placeholder SVG

## Phase 1.5: Sawmill Visual Layout (Simplified)
- [x] 1.5.1 Track Rendering
  - [x] `src/Sawmill/Layout.elm` - Layout definition using composable track system
  - [x] Mainline, turnout, siding, buffer stop, tunnel portal
- [x] 1.5.2 Interactive Elements
  - [x] Tunnel portal (spawn point)
  - [x] Turnout (clickable, shows state)
  - [x] Platform spot
  - [x] Team track spot
- [x] 1.5.3 Map Furniture
  - [x] Sawmill building
  - [x] Team track ramp
  - [x] Passenger platform
- [x] 1.5.4 Mouse Interaction
  - [x] SVG-native hover detection (mouseenter/mouseleave on hit areas)
  - [x] Dashed outline on hover
  - [x] Tooltip near element
  - [x] Click turnout to toggle

## Phase 2: Track System
- [x] 2.1 Track Geometry (`src/Track/Element.elm`)
  - [x] Connector type (position + orientation)
  - [x] TrackElementType (Straight, Curved, Turnout, TrackEnd)
  - [x] Geometry computation for all element types
- [x] 2.2 Track Segments
  - [x] StraightTrack with length
  - [x] CurvedTrack with radius and sweep
- [x] 2.3 Switches/Turnouts
  - [x] Turnout with through/diverging routes
  - [x] Left/Right hand support
- [x] 2.4 Track Layout (`src/Track/Layout.elm`)
  - [x] Layout builder with placeElement/placeElementAt
  - [x] Connection tracking
  - [x] Connector lookup
- [x] 2.5 Track Ends
  - [x] TrackEnd element type (buffer stops, tunnel portals)
- [x] 2.6 Track Rendering (`src/Track/Render.elm`)
  - [x] RenderSegment types (straight, arc)
  - [x] Ballast and rail rendering
- [x] 2.7 Track Validation (`src/Track/Validation.elm`)
  - [x] Connection continuity validation (position and orientation)

## Phase 3: Rolling Stock
- [ ] 3.1 Stock Types
- [ ] 3.2 Stock Rendering
- [ ] 3.3 Consists

## Phase 4: Train Positioning & Movement
- [ ] 4.1 Train State
- [ ] 4.2 Car Positioning on Curves
- [ ] 4.3 Physics

## Phase 5: Orders & Scheduling
- [ ] 5.1 Order Types
- [ ] 5.2 Schedule
- [ ] 5.3 Spots

## Phase 6: World & Simulation
- [ ] 6.1 World State
- [ ] 6.2 Simulation Tick
- [ ] 6.3 Spawn/Despawn

## Phase 7: Camera & View
- [x] 7.1 Camera
  - [x] ViewBox-based camera with center and zoom
  - [x] Click-and-drag panning
  - [x] Cursor feedback (default/grabbing)
- [ ] 7.2 Zoom controls

## Phase 8: UI Panels
- [ ] 8.1 Time Controls
- [ ] 8.2 Train Inspector
- [ ] 8.3 Mode Switching

## Phase 9: Consist Planning UI
- [x] 9.1 Planning Screen
  - [x] Planning panel (right side, 400px)
  - [x] Spawn point selector (East/West Station)
  - [x] Available stock display with SVG profiles
  - [x] Consist builder with click-to-select, click-to-place
  - [x] Schedule controls (day/hour/minute pickers)
  - [x] Scheduled trains list with remove button
- [x] 9.2 Stock Arrangement
  - [x] Per-spawn-point inventory
  - [x] Stock types: Locomotive, PassengerCar, Flatbed, Boxcar

## Phase 10: Schedule Editor UI
- [ ] 10.1 Order Blocks
- [ ] 10.2 Schedule Editor (click-based)

## Phase 11: Puzzle System
- [ ] 11.1 Puzzle Definition
- [ ] 11.2 Sawmill Puzzle
- [ ] 11.3 Goal Tracking
- [ ] 11.4 End-of-Week Stats

## Phase 12: Save/Load
- [ ] 12.1 Solution Encoding
- [ ] 12.2 Solution Decoding
- [ ] 12.3 Storage
