extends RefCounted

# Frozen native Water cohorts; no runtime owner or simulation behavior.
const WAVE_REFERENCE_PARAMETERS := {
	"active_rows":32,"gain":32,"gain_confined":4,"stiffness":256,"damp_shift":7,
	"coast":16,"level_shift":3,"sleep_after":30,"wake_peak":1,"rest_head":1,
	"stick":512,"calm":512,"calm_damp_shift":3,"maximum_mass":32000,
	"empty_pour_shift":2,"flow_share_shift":1,"adhesion_shift":1,
	"body_push":256,"body_push_by_mass":1}
const GAMEPLAY_OPTIONS := {
	"workbench_wave_flow":true,"workbench_ballistic":true,"workbench_wave_substeps":2,
	"workbench_wave_gain":32,"workbench_wave_deep_gain":32,"workbench_wave_floor_gain":1024,
	"workbench_wave_flux_smoothing":16,"workbench_wave_coast":32,"workbench_wave_empty_pour_shift":2,
	"workbench_wave_damp_shift":16,"workbench_wave_calm_damp_shift":8,"workbench_wave_calm":128,
	"workbench_wave_stick":128,"workbench_wave_sleep_after":90,"workbench_wave_body_push_by_mass":1,
	"workbench_wave_spill":true,"workbench_wave_spill_parcels":true,"workbench_wave_spill_sheet_rate":64,
	"workbench_wave_spill_coyote_ticks":4,"workbench_wave_spill_full_face":true,"workbench_wave_spill_fall":3,
	"workbench_wave_spill_draw":127,"workbench_wave_spill_draw_head":255,"workbench_wave_spill_deep_draw":64,
	"workbench_wave_spill_launch_budget":128}

# These are copied packet fields, not new native reads. A physics-only packet
# intentionally has no render-generation authority or material payload.
const SNAPSHOT_OBSERVATION_FIELDS := ["physics_world_generation","last_native_tick_completed_usec",
	"physics_handoff_usec","last_native_tick_world_generation","last_native_tick_body_sample"]

static func snapshot_properties(packet: Object) -> Dictionary:
	var result := {}
	for item: Dictionary in packet.get_property_list(): result[str(item.name)] = true
	return result

static func snapshot_capabilities(properties: Dictionary) -> Dictionary:
	var result := {}
	for field: String in SNAPSHOT_OBSERVATION_FIELDS: result[field] = properties.has(field)
	return result

static func packet_observation(packet: Object, properties: Dictionary) -> Dictionary:
	var owner := "physics_world_generation" if properties.has("physics_world_generation") else "render_world_generation"
	var completed: Variant = packet.get("last_native_tick_completed_usec") if properties.has("last_native_tick_completed_usec") else null
	var handoff: Variant = packet.get("physics_handoff_usec") if properties.has("physics_handoff_usec") else null
	return {"world_generation_field":owner,"world_generation":packet.get(owner),
		"render_world_generation":packet.get("render_world_generation"),
		"native_completed_source_usec":completed,
		"native_completed_usec":completed if completed != null and int(completed) >= 0 else null,
		"physics_handoff_source_usec":handoff,
		"physics_handoff_usec":handoff if handoff != null and int(handoff) >= 0 else null,
		"native_completion_world_generation":packet.get("last_native_tick_world_generation") if properties.has("last_native_tick_world_generation") else null,
		"native_completion_body_sample":packet.get("last_native_tick_body_sample") if properties.has("last_native_tick_body_sample") else null}
