class_name CyberSimulationSnapshot
extends RefCounted

# Immutable after publication. The worker creates a fresh object for every
# published state, while the material byte array is replaced only when the
# cellular revision changes.
var serial: int = 0
var published_usec: int = 0
var world_revision: int = -1
var hard_surface_revision: int = -1
var cells: PackedByteArray = PackedByteArray()
# Native RenderBridge payload. Rectangles use six integers per patch:
# x, y, width, height, data offset, row stride. Data is R8 for the script
# fallback and RG8 (material ID + read-only visual condition) for native.
var render_snapshot_serial: int = 0
var render_channels: int = 1
var render_full_refresh: bool = false
var render_patch_rectangles: PackedInt32Array = PackedInt32Array()
var render_patch_cells: PackedByteArray = PackedByteArray()
var hard_surface_rectangles: PackedInt32Array = PackedInt32Array()
var hard_surface_rectangles_valid: bool = false
var hard_surface_chunk_rectangles: PackedInt32Array = PackedInt32Array()
var hard_surface_chunk_rectangles_valid: bool = false

var character_position: Vector2 = Vector2.ZERO
var character_velocity: Vector2 = Vector2.ZERO
var character_grounded: bool = false

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
var paused: bool = false
