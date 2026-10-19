class_name CyberSimulationSnapshot
extends RefCounted

# Immutable after publication. The worker creates a fresh object for every
# published state, while the material byte array is replaced only when the
# cellular revision changes.
var serial: int = 0
var lab_context: Dictionary = {} # Copied owner values; immutable after publication.
var published_usec: int = 0
# Revision represented by the retained material render publication.
var world_revision: int = -1
# Current authoritative cellular revision at this worker publication. Equality
# with world_revision proves the retained material bytes are still current.
var simulation_world_revision: int = -1
var hard_surface_revision: int = -1
var cells: PackedByteArray = PackedByteArray()
# Native RenderBridge payload. Rectangles use six integers per patch:
# x, y, width, height, data offset, row stride. Data is R8 for the script
# fallback and RG8 (material ID + read-only visual condition) for native.
var render_snapshot_serial: int = 0
# Accepted World/reset generation represented by these exact render bytes.
# Full refresh is a transport choice (always true for R8 fallback), not a reset.
var render_world_generation: int = 0
var render_channels: int = 1
var render_full_refresh: bool = false
var render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var render_patch_cells: PackedByteArray = PackedByteArray()
# Value-only state bound to the exact render generation above. These values
# remain stable while later worker snapshots may advance simulation state.
var render_tick_index: int = 0
var render_generated_usec: int = 0
var render_character_position: Vector2 = Vector2.ZERO
var render_character_velocity: Vector2 = Vector2.ZERO
var render_character_grounded: bool = false
var render_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var render_simulation_time_ms: float = 0.0
var render_worker_step_time_ms: float = 0.0
var render_worker_overruns: int = 0
var render_context: Dictionary = {}
var hard_surface_rectangles: PackedInt32Array = PackedInt32Array()
var hard_surface_rectangles_valid: bool = false
var hard_surface_chunk_rectangles: PackedInt32Array = PackedInt32Array()
var hard_surface_chunk_rectangles_valid: bool = false

var character_position: Vector2 = Vector2.ZERO
var character_velocity: Vector2 = Vector2.ZERO
var character_grounded: bool = false
# Active gameplay actor identity at this worker publication. Body ID is zero for
# the sampled character and the 1-based coupling ID for a Rapier player body.
var player_representation: String = "sampled-baseline"
var player_body_id: int = 0
# ACT-001 current actor sample, independently timestamped from material bytes.
# Value-only, immutable after publication; no motor or World references.
var actor_prototypes: Dictionary = {}
# USABLE-001 copied equipment/runtime state for the actor sample.
var actor_usables: Dictionary = {}
var actor_prototype_status: String = ""
var actor_prototype_reset_serial: int = 0
var actor_prototype_reset_applied: bool = false
# Exact copied body input sample consumed by this worker publication.
var current_rigid_body_states: PackedFloat32Array = PackedFloat32Array()
var rigid_body_epoch: int = 0 # Main-thread physical owner incarnation, or reference 0.
var physical_actor_effects: Array = [] # Bounded copied native-owner receipts.
var physical_actor_effect_admission: Dictionary = {} # Copied queue counts and last batch outcome.
var physical_usables: Dictionary = {} # Worker-owned U01-U32 state and retained per-actor receipts.
var character_runtime_recovery_enabled: bool = true
var character_runtime_enclosed: bool = false
var character_runtime_recovery_attempts: int = 0
var character_runtime_recovery_successes: int = 0
var character_runtime_recovery_upward_cells: int = 0
var character_invalid_spawn_recovery_attempts: int = 0
var character_invalid_spawn_recovery_successes: int = 0
var character_last_recovery_kind: String = ""
var character_last_recovery_offset: Vector2 = Vector2.ZERO

var tick_index: int = 0
var moves_last_tick: int = 0
var scanned_last_tick: int = 0
var dormant_cells_skipped_last_tick: int = 0
var active_blocks_last_tick: int = 0
var eligible_blocks_last_tick: int = 0
var adaptive_block_stride_last_tick: int = 1
var deferred_blocks_last_tick: int = 0
var frozen_blocks_last_tick: int = 0
var scheduler_jobs_last_tick: int = 0
var scheduler_parallel_phases_last_tick: int = 0
var scheduler_thread_capacity_hint: int = 1
var backend_name: String = "unknown"
var sparse_flight_moves_last_tick: int = 0
var rigid_body_results: PackedFloat32Array = PackedFloat32Array()
var rigid_body_contacts_last_tick: int = 0
var rigid_body_displaced_last_tick: int = 0
var rigid_body_unresolved_last_tick: int = 0
var simulation_time_ms: float = 0.0
var worker_step_time_ms: float = 0.0
var snapshot_copy_time_ms: float = 0.0
var worker_overruns: int = 0
var tick_failure_count: int = 0
var last_tick_error: String = ""
var simulation_failed: bool = false
var failed_tick_index: int = 0
var paused: bool = false
