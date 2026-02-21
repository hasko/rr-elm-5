## ADDED Requirements

### Requirement: Graph walker computes track geometry from nodes and edges

The layout engine SHALL walk the scenario's node/edge graph starting from a designated anchor node at position (0, 0) with orientation 0, computing connector positions and orientations for each element using the existing `Track.Element` geometry math.

#### Scenario: Straight edge becomes a straight track element
- **WHEN** the walker processes a straight edge with `length: 250` between two nodes
- **THEN** a `StraightTrack 250` element is placed with connector0 at the current position/orientation and connector1 computed by the geometry engine

#### Scenario: Curve edge becomes a curved track element
- **WHEN** the walker processes a curve edge with `radius: 170` and `sweep: 15` degrees
- **THEN** a `CurvedTrack { radius = 170, sweep = (15 * pi/180) }` element is placed with connectors computed by the geometry engine

#### Scenario: Turnout node becomes a turnout element
- **WHEN** the walker reaches a turnout node with `hand: "right"`, `radius: 170`, `sweep: 15`, and two outgoing edges (one `port: "through"`, one `port: "diverge"`)
- **THEN** a `Turnout` element is placed with through and diverge connectors, and the walker continues along both outgoing edges

#### Scenario: Portal node becomes a track end element
- **WHEN** the walker reaches a portal node
- **THEN** a `TrackEnd` element is placed at that position, representing the tunnel portal

#### Scenario: Buffer node becomes a track end element
- **WHEN** the walker reaches a buffer node
- **THEN** a `TrackEnd` element is placed at the terminal position

### Requirement: Depth-first traversal order

The walker SHALL traverse the graph depth-first from the anchor node, following edges in order. When a turnout node is encountered, the walker SHALL process the through edge first, then the diverge edge.

#### Scenario: Sawmill layout traversal
- **WHEN** the sawmill scenario graph (4 nodes, 3 edges) is walked from the east portal
- **THEN** elements are created in order: east portal → mainline straight → turnout → through straight → west portal, then diverge curve → siding → buffer, producing a valid `Track.Layout`

### Requirement: Merge point validation

When the walker encounters a node that has already been visited (e.g., a passing loop), it SHALL validate that the computed position matches the previously computed position within a tolerance of 1 millimeter (0.001 track units).

#### Scenario: Valid merge point
- **WHEN** two paths through a passing loop converge at a node and the computed positions differ by less than 0.001 units
- **THEN** the merge is accepted and the layout is valid

#### Scenario: Invalid merge point
- **WHEN** two paths converge at a node and the computed positions differ by more than 0.001 units
- **THEN** a validation error is reported with the node id and the position discrepancy

### Requirement: Spot positions from edges

Spots defined on edges SHALL be placed at their specified distance along the edge, with positions and orientations computed from the track element geometry.

#### Scenario: Spot placement on a straight edge
- **WHEN** a straight edge of length 100 has a spot at distance 60
- **THEN** the spot is placed at 60% along the straight element, with the correct position and orientation for that point on the track

#### Scenario: Multiple spots on one edge
- **WHEN** an edge has spots at distances 30 and 80
- **THEN** both spots are placed at their respective distances along the element, each with correct position and orientation

### Requirement: Turnout initial state from scenario data

Each turnout node in the scenario SHALL specify an `initialState` (`"through"` or `"diverge"`). The layout engine SHALL initialize the turnout switch states from this data.

#### Scenario: Turnout starts in through position
- **WHEN** a turnout node has `"initialState": "through"`
- **THEN** the turnout's switch state is initialized to the through position

#### Scenario: Turnout starts in diverge position
- **WHEN** a turnout node has `"initialState": "diverge"`
- **THEN** the turnout's switch state is initialized to the diverge position

### Requirement: Multiple turnout state tracking

The simulation SHALL maintain a `Dict String SwitchState` keyed by turnout node id, replacing the current single `turnoutState` field. All turnout-related operations (switch commands, route building, simulation tick) SHALL use this dictionary.

#### Scenario: Two turnouts with independent state
- **WHEN** a scenario has two turnout nodes "t1" and "t2"
- **THEN** each turnout's switch state is tracked independently, and toggling "t1" does not affect "t2"

### Requirement: Layout produces element-to-node-id mapping

The layout engine SHALL produce a mapping from `ElementId` to scenario node/edge ids, so that simulation and UI code can look up scenario data (station portal, spot id) from track element references.

#### Scenario: Portal element maps to station
- **WHEN** the layout is built and a portal element corresponds to node "e-portal"
- **THEN** the element-to-node mapping allows looking up that this element is the portal for the station linked to "e-portal"
