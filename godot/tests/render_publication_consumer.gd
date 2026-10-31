extends "res://scripts/main.gd"

var trace: RefCounted
var _render_identity: Dictionary = {}

func record_render_payload(snapshot: CyberSimulationSnapshot) -> void:
	_render_identity = {"serial": snapshot.render_snapshot_serial, "generation": snapshot.render_world_generation,
		"snapshot_serial": snapshot.serial, "revision": snapshot.world_revision}
	trace.record("payload", _render_identity)
	super.record_render_payload(snapshot)

func create_render_textures() -> void:
	trace.record("texture_create_begin", _render_identity)
	super.create_render_textures()
	trace.record("texture_create_success", _render_identity)

func consume_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	_render_identity = {"serial": snapshot.render_snapshot_serial, "generation": snapshot.render_world_generation,
		"snapshot_serial": snapshot.serial, "revision": snapshot.world_revision}
	trace.record("render_consume", _render_identity)
	super.consume_render_snapshot(snapshot)

func validate_render_patch_payload(rectangles: PackedInt32Array, cells: PackedByteArray, channels: int) -> String:
	trace.record("validation_begin", _render_identity)
	var result: String = super.validate_render_patch_payload(rectangles, cells, channels)
	var event := _render_identity.duplicate()
	event["reason"] = result
	trace.record("validation_end", event)
	return result

func apply_render_patches_to_image(rectangles: PackedInt32Array, cells: PackedByteArray, channels: int) -> bool:
	trace.record("patch_begin", _render_identity)
	var result: bool = super.apply_render_patches_to_image(rectangles, cells, channels)
	trace.record("patch_end", _render_identity)
	return result

func finish_texture_upload(revision: int, start: int) -> void:
	trace.record("texture_begin", _render_identity)
	super.finish_texture_upload(revision, start)
	trace.record("texture_success", _render_identity)

func update_render_texture() -> void:
	trace.record("texture_update_begin", _render_identity)
	super.update_render_texture()
	trace.record("texture_update_end", _render_identity)

func reject_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	var event := _render_identity.duplicate()
	event["reason"] = last_render_patch_validation_error
	trace.record("reject", event)
	super.reject_render_snapshot(snapshot)
