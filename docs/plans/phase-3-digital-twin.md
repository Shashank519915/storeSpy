# RIP Phase 3: Digital Twin & Spatial Mapping
**Prerequisites:** Phase 2 exit criteria met
**Governance:** code_style.md, design-tokens.md
**Master plan:** rip-execution-plan.md (this is the standalone working copy)


## Phase Objective
Build the mathematically rigorous spatial substrate: event-sourced Scene Graph DAG in PostgreSQL/PostGIS, spatial query enrichment service, raycasting-based camera coverage and blind-spot estimation, navigation graph for walking-distance reasoning, and time-travel twin versioning. At exit, a CV `HandMoved` coordinate is enriched to `ShelfInteraction(shelf_id, zone, session_id)` via point-in-polygon; camera placement validation renders a blind-spot heatmap; historical twin state is reconstructable at any timestamp.

## Sub-systems Involved
- `apps/twin-api` (Go mutation API + Outbox)
- `apps/spatial-query` (Go PostGIS enrichment)
- PostgreSQL `twin` schema + PostGIS geometry
- Kafka topic `twin.mutations.*`
- Scene Graph DAG (Store → Zone → Aisle → Fixture → Shelf → Facing)
- Navigation graph (waypoints for walking distance)
- Raycasting engine (1° FOV increments, shelf height occlusion)
- Homography calibration API
- `packages/spatial-math` (TypeScript + Go shared math)
- R3F Store Designer (frontend scaffold — full UI in Phase 5; API + math here)

---

## Granular Tasks

### 3.1 Scene Graph Data Model
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-001 | Protobuf: `TwinNode`, `TwinEdge`, `SpatialTransform`, `MutationEvent` oneofs | `packages/proto/rip/twin/v1/scene_graph.proto` |
| RIP-3-002 | PostgreSQL `twin.nodes`: `id`, `store_id`, `parent_id`, `node_type`, `transform JSONB`, `metadata JSONB`, `valid_from`, `valid_to` | `infra/migrations/020_twin_nodes.sql` |
| RIP-3-003 | PostgreSQL `twin.edges`: navigation graph edges between waypoint nodes | `infra/migrations/021_twin_edges.sql` |
| RIP-3-004 | PostgreSQL `twin.spatial_objects`: PostGIS `geometry(Polygon)` for zones; `geometry(LineString)` for shelf centerlines | `infra/migrations/022_twin_spatial.sql` |
| RIP-3-005 | PostgreSQL `twin.cameras`: mount `(x,y,z)`, `pan`, `tilt`, `fov_degrees`, `homography_matrix FLOAT[9]`, `twin_version_id` FK | `infra/migrations/023_twin_cameras.sql` |
| RIP-3-006 | PostgreSQL `twin.versions`: `version INT`, `snapshot JSONB`, `valid_from`, `valid_to NULL` for active | `infra/migrations/024_twin_versions.sql` |
| RIP-3-007 | GIN index on `nodes.metadata`; GiST on `spatial_objects.geom` and `cameras.mount_point` | `infra/migrations/025_twin_indexes.sql` |
| RIP-3-008 | Seed reference store layout JSON (lab store) for K3s integration tests | `infra/seeds/twin_lab_store.json` |

### 3.2 Event-Sourced Twin Mutations
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-010 | `apps/twin-api`: CRUD mutations as commands → Outbox rows (never in-place UPDATE of geometry) | `apps/twin-api/` |
| RIP-3-011 | Mutation types: `ShelfMoved`, `CameraPitchChanged`, `ZoneAdded`, `SKUAssignedToFacing`, `NavigationEdgeAdded` | `apps/twin-api/internal/commands/` |
| RIP-3-012 | Debezium routes `twin.mutations.*` to Kafka; consumer projects mutations into materialized snapshot | `apps/twin-projector/` |
| RIP-3-013 | Snapshot cadence: update `twin.versions.snapshot` every N mutations or 60s batch window | `twin-projector/internal/snapshotter/` |
| RIP-3-014 | Time-travel API: `GET /api/twin/{store_id}?timestamp=ISO8601` — load nearest snapshot + replay mutations ≤ timestamp | `apps/twin-api/internal/timetravel/` |
| RIP-3-015 | Optimistic concurrency: `expected_version` field on mutation commands; reject stale writes with 409 | `twin-api/internal/commands/versioning.go` |
| RIP-3-016 | Emit `TwinLayoutChanged` to Kafka on every successful mutation batch | `twin-projector/internal/events/` |

### 3.3 Spatial Query Service
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-020 | `apps/spatial-query` (Go): consume `vision.interaction.*` with raw `(world_x, world_y)` | `apps/spatial-query/` |
| RIP-3-021 | PostGIS `ST_Contains(zone.geom, ST_SetSRID(ST_MakePoint(x,y), 4326))` for zone classification | `spatial-query/internal/queries/zone.go` |
| RIP-3-022 | Shelf interaction zones: point-in-polygon against `spatial_objects` where `node_type='Shelf'` | `spatial-query/internal/queries/shelf.go` |
| RIP-3-023 | Enrichment transform: `HandMoved` → `ShelfInteraction{shelf_id, zone, session_id}` Protobuf | `spatial-query/internal/enricher/` |
| RIP-3-024 | Checkout zone geofence: emit `EnteredCheckoutZone`, `ExitedCheckoutZone` on boundary crossing with hysteresis (0.3m) | `spatial-query/internal/geofence/checkout.go` |
| RIP-3-025 | Exit gate geofence: emit `ExitGateCrossed` when trajectory crosses `Zone:Exit` polygon | `spatial-query/internal/geofence/exit.go` |
| RIP-3-026 | Opt-Out Zone handler: on `ST_Contains(opt_out.geom, point)`, emit `ForgetMe` command to ReID purge topic | `spatial-query/internal/privacy/optout.go` |
| RIP-3-027 | Cache hot spatial index in Redis: R-tree serialized per `store_id` + `twin_version_id`; invalidate on `TwinLayoutChanged` | `spatial-query/internal/cache/` |

### 3.4 Navigation Graph & Walking Distance
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-030 | Build directed graph from `twin.edges` (waypoint nodes on walkable paths) | `spatial-query/internal/navgraph/build.go` |
| RIP-3-031 | Dijkstra shortest path on navigation graph for walking distance (not Euclidean) | `spatial-query/internal/navgraph/dijkstra.go` |
| RIP-3-032 | gRPC `GetWalkingDistance(camera_a_exit, camera_b_entrance)` for ReID travel-time validation | `spatial-query/proto/nav.proto` |
| RIP-3-033 | Average human walking speed constant 1.4 m/s; compute expected Δt min/max with ±30% tolerance | `spatial-query/internal/navgraph/travel_time.go` |
| RIP-3-034 | Expose walking path polyline for LP trajectory evidence packages | `spatial-query/internal/navgraph/path_export.go` |

### 3.5 Raycasting: Camera Coverage & Blind Spots
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-040 | Go raycasting engine: cast rays from camera floor projection at 1° increments across `fov_degrees` | `packages/go-common/raycast/` |
| RIP-3-041 | For each ray: intersect shelf/wall polygons considering height profile (shelf `z_max` blocks ray below mount `z`) | `raycast/occlusion_height.go` |
| RIP-3-042 | Unblocked ray endpoints form visible polygon; complement = blind spot regions | `raycast/coverage_polygon.go` |
| RIP-3-043 | Critical zone audit: flag if `Zone:Checkout` or high-value merchandise polygons overlap blind spots > 10% area | `raycast/critical_audit.go` |
| RIP-3-044 | Persist coverage heatmap grid to PostgreSQL `twin.camera_coverage` (JSONB grid) per camera per version | `infra/migrations/026_camera_coverage.sql` |
| RIP-3-045 | API `POST /api/twin/{store_id}/cameras/{id}/coverage/recalculate` triggers async raycast job | `apps/twin-api/internal/coverage/` |
| RIP-3-046 | Emit `BlindSpotIdentified` event when critical zone coverage < threshold | `twin-api/internal/coverage/events.go` |
| RIP-3-047 | LP confidence adjustment hook: blind-spot flag stored on session state (consumed Phase 4) | `twin.camera_coverage.blind_spot_penalty` metadata |

### 3.6 Homography Calibration API
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-050 | API `POST /api/twin/{store_id}/cameras/{id}/calibrate` accepts ≥4 point pairs `(pixel_u, pixel_v, world_x, world_y)` | `apps/twin-api/internal/calibration/` |
| RIP-3-051 | DLT homography computation; reprojection error RMS validation (reject if > 0.5m) | `packages/go-common/spatial/homography.go` |
| RIP-3-052 | Pinhole fallback for angled cameras: accept `mount_z`, `pitch`, `roll`, `intrinsic_matrix` | `packages/go-common/spatial/pinhole.go` |
| RIP-3-053 | On success: emit `CameraCalibrated` mutation; push matrix to edge via GitOps `StoreCustomResource` | `twin-api/internal/calibration/publish.go` |
| RIP-3-054 | Shared TS math lib mirror for frontend real-time overlay validation | `packages/spatial-math/homography.ts` |

### 3.7 3D Frustum Projection (Backend Validation)
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-060 | Compute 3D camera frustum truncated pyramid from mount pose + FoV | `packages/go-common/spatial/frustum.go` |
| RIP-3-061 | Project frustum base onto Z=0 floor plane → 2D coverage polygon | `spatial/frustum_project.go` |
| RIP-3-062 | Cross-validate frustum polygon vs raycast coverage (area delta < 5%) | `twin-api/internal/coverage/validate.go` |
| RIP-3-063 | Occlusion shadow polygons behind tall fixtures relative to camera | `raycast/occlusion_shadow.go` |

### 3.8 Twin Projector & Edge Sync
| Ticket ID | Task | Output Path |
|-----------|------|-------------|
| RIP-3-070 | `StoreCustomResource` CRD: `spec.cameras[].homography_matrix`, `spec.shelves[].polygons` | `edge/fleet-crds/store-custom-resource.yaml` |
| RIP-3-071 | Fleet agent watches twin version; rolling update edge cv-orchestrator calibration without pod restart (SIGHUP reload) | `edge/fleet-crds/twin-sync-agent.yaml` |
| RIP-3-072 | Edge spatial-query lightweight cache: subscribe to `twin.mutations.layout-changed`; hot-reload shelf ROIs | `services/edge/cv-orchestrator/spatial/twin_cache.py` |

---

## Infrastructure/DevOps Tasks (Phase 3)

| Asset | Detail |
|-------|--------|
| `twin-api` Deployment | EKS, 3 replicas, PgBouncer, Vault dynamic creds `twin` schema |
| `spatial-query` Deployment | Kafka consumer group `spatial-enricher`, 6 replicas, partition by `store_id` |
| `twin-projector` Deployment | Single leader election via Redis lock; snapshot writer |
| PostGIS upgrade | Ensure `postgis` 3.4+ on RDS parameter group |
| Coverage batch jobs | K8s CronJob nightly recalculate all camera coverage after layout changes |
| Redis cache | `twin:spatial_index:{store_id}:{version}` with 1h TTL, invalidate on mutation |

---

## Production-Ready Implementation Details (Phase 3)

### Raycasting Blind Spot Algorithm (Exact Steps)
1. Load camera node: floor position `(cx, cy)`, mount height `z_cam`, pan `ψ`, tilt `θ`, `fov_degrees = φ`.
2. Compute left/right bearing: `ψ ± φ/2` in floor-plane coordinates.
3. For `bearing` from `ψ - φ/2` to `ψ + φ/2` step 1°:
   - Cast ray from `(cx, cy)` along `bearing` as half-line.
   - For each shelf/wall polygon with height `z_max`:
     - If `z_max < z_cam × tan(elevation_angle)` → ray blocked at intersection point; stop ray.
     - Else ray passes over (shelf shorter than sight line).
   - Record terminal point (wall hit or max range 30m).
4. Triangulate visible region from ray endpoints; compute `visible_area`.
5. `blind_area = sales_floor_polygon - visible_area`.
6. Intersect `blind_area` with critical zones (checkout, high-value SKUs).
7. If `intersection_area / critical_zone_area > 0.10` → `BlindSpotIdentified` with severity score.

### Time-Travel Twin Reconstruction
1. Query `twin.versions` for `store_id` where `valid_from ≤ T` ORDER BY `valid_from DESC LIMIT 1` → snapshot S₀.
2. Fetch Kafka/ClickHouse mutations from `twin.mutations.*` where `occurred_at ∈ (S₀.valid_from, T]`.
3. Apply mutations in `occurred_at` order to in-memory Scene Graph DAG.
4. Return materialized graph; cache result in Redis keyed `(store_id, T)` for 15 min.
5. Historical LP investigation at T uses this graph for spatial context — not current layout.

### Spatial Enrichment Pipeline
1. Consumer receives `vision.interaction.HandMoved{world_x, world_y, session_id}`.
2. Load spatial index for active `twin_version_id` (Redis cache or PostGIS direct).
3. `ST_Contains(shelf.geom, point)` → if match, determine `zone` (left_side/right_side/front) via shelf centerline normal.
4. Emit `vision.interaction.ShelfInteraction{shelf_id, zone, session_id}` with same `trace_id`.
5. Geofence state machine per session in Redis: track `current_zone`; on transition across checkout polygon boundary → emit zone events.

### Walking Distance for ReID (Prep Phase 4)
1. Camera A exit waypoint: nearest navigation graph node to camera A exit ray endpoint.
2. Camera B entrance waypoint: nearest node to camera B entrance.
3. Dijkstra on `twin.edges` weighted by edge length (meters).
4. `distance_m / 1.4 m/s = expected_travel_sec`; tolerance window `[0.7×, 1.3×] × expected_travel_sec`.
5. ReID service rejects candidate matches outside temporal window.

---

## Testing & Validation (Phase 3)

| Test | Procedure | Pass Criteria |
|------|-----------|---------------|
| Point-in-polygon | 10k random points against 50 shelf polygons | p99 < 2ms via GiST; 100% accuracy vs brute-force |
| Shelf enrichment | Inject `HandMoved` at known shelf coordinate | `ShelfInteraction` with correct `shelf_id` and `zone` |
| Geofence hysteresis | Oscillate point on checkout boundary ±0.2m | No flapping; single `EnteredCheckoutZone` |
| Time-travel | Apply 50 mutations; query T mid-sequence | Graph matches manual replay; ≠ current state |
| Optimistic lock | Two concurrent `ShelfMoved` with same `expected_version` | One succeeds; one 409 Conflict |
| Raycast coverage | Known L-shaped store with 1 camera | Blind spot area matches manual CAD within 3% |
| Critical zone flag | Place checkout in blind spot | `BlindSpotIdentified` severity > 0.8 |
| Homography calibrate | 4-point calibration with known error injection | Reject RMS > 0.5m; accept < 0.2m |
| Navigation distance | Compare Dijkstra vs measured tape distance on floor plan | Error < 5% |
| Twin edge sync | Mutate shelf in cloud; wait Fleet reconcile | Edge cv-orchestrator shelf ROI updated < 5 min |
| Opt-Out zone | Track enters opt-out polygon | `ForgetMe` emitted; Qdrant vector purged (Phase 4 integration) |

---

## Exit Criteria (Phase 3)

- [ ] Scene Graph DAG persisted with full hierarchy; lab store seeded
- [ ] All twin mutations event-sourced via Outbox → Kafka → projector → snapshot
- [ ] Time-travel API returns correct layout at historical timestamps
- [ ] Spatial-query enriching `HandMoved` → `ShelfInteraction` in real-time (< 10ms p99)
- [ ] Checkout and exit geofences emitting zone transition events
- [ ] Raycasting coverage + blind-spot heatmap for all cameras in lab store
- [ ] Critical zone blind-spot audit flagging operational
- [ ] Homography calibration API with reprojection validation; matrix synced to edge
- [ ] Navigation graph walking distance API operational
- [ ] Twin version synced to edge `StoreCustomResource` via Fleet GitOps
- [ ] PostGIS spatial query p99 < 2ms at 10k QPS synthetic load

**Phase 3 outputs are strict dependencies for Phase 4.**

---

