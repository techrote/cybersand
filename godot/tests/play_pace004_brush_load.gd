extends RefCounted

# Opt-in qualification load. Main submits ordinary bounded paint requests; only
# the existing production worker applies them. This helper never reads a World.
# Frozen brush_rain_v1 recipe; the independent Python contract owns acceptance.
const RECIPE: String = "brush_rain_v1;square=8;period_usec=100000;pulses=150;sand=2@396,176;water=3@576,176;flags=0;priming=0"
const PERIOD_USEC: int = 100000
const PULSES: int = 150
const CENTRES: Array[Vector2i] = [Vector2i(396,176), Vector2i(576,176)]
const MATERIALS: Array[int] = [2,3]
const OWNER_FIELDS: Array[String] = ["worker","session","bridge","run_id","epoch","generation","world_generation"]
var mode: String = "none"
var started_usec: int = 0
var stopped_usec: int = 0
var original_shape: String = ""
var original_size: int = 0
var owner: Dictionary = {}
var pulses: Array[Dictionary] = []
var errors: Array[String] = []
var active: bool = false


func begin(desktop: Control, selected_mode: String, started: int, initial: Dictionary) -> void:
	mode = selected_mode
	if mode == "none":
		return
	started_usec = started
	owner = initial.duplicate(true)
	original_shape = desktop.brush_shape
	original_size = desktop.brush_size_px
	desktop.set_brush_shape("square")
	desktop.set_brush_size(8)
	active = true


func pump(desktop: Control) -> void:
	if not active or pulses.size() >= PULSES:
		return
	var entered: int = Time.get_ticks_usec()
	var due: int = started_usec + pulses.size() * PERIOD_USEC
	if entered < due:
		return
	var current: Dictionary = desktop.state()
	for field: String in OWNER_FIELDS:
		if current.get(field) != owner.get(field):
			errors.append("brush producer owner changed: " + field)
			active = false
			return
	if current.get("paused",true) or current.get("native_paused",true) or current.get("suspended",true) \
		or current.get("pending",true) or current.get("rearm",true) \
		or not current.get("focus",false) or not str(current.get("fault", "missing")).is_empty():
		errors.append("brush producer lost playable input authority")
		active = false
		return
	var pulse_id: int = pulses.size() + 1
	var pulse: Dictionary = {"id":pulse_id, "scheduled_usec":due, "entered_usec":entered,
		"before":current, "commands":[], "recipe_sha256":RECIPE.sha256_text()}
	for slot: int in range(CENTRES.size()):
		var centre: Vector2i = CENTRES[slot]
		var footprint: PackedInt32Array = desktop.brush_footprint_cells(centre.x,centre.y)
		var command_started: int = Time.get_ticks_usec()
		var attempted: bool = mode == "brush_rain_v1"
		var accepted: bool = desktop.queue_brush_footprint_mutation(centre.x,centre.y,MATERIALS[slot],0) if attempted else false
		var command_ended: int = Time.get_ticks_usec()
		pulse.commands.append({"id":(pulse_id-1)*2+slot+1, "pulse_id":pulse_id,
			"slot":slot, "centre":[centre.x,centre.y], "material":MATERIALS[slot], "flags":0,
			"shape":desktop.brush_shape, "size":desktop.brush_size_px, "points":Array(footprint),
			"started_usec":command_started, "ended_usec":command_ended,
			"attempted":attempted, "accepted":accepted, "control_skipped":not attempted})
		if attempted and not accepted:
			errors.append("normal brush queue refused command %d" % ((pulse_id-1)*2+slot+1))
	pulse["after"] = desktop.state()
	pulse["ended_usec"] = Time.get_ticks_usec()
	pulses.append(pulse)


func stop(desktop: Control) -> void:
	if mode == "none" or stopped_usec > 0:
		return
	stopped_usec = Time.get_ticks_usec()
	active = false
	if started_usec == 0:
		errors.append("workload never started after playable-session acknowledgement")
		return
	desktop.set_brush_shape(original_shape)
	desktop.set_brush_size(original_size)
	if pulses.size() != PULSES:
		errors.append("incomplete pulse inventory: %d/%d" % [pulses.size(),PULSES])


func report() -> Dictionary:
	if mode == "none":
		return {"mode":"none"}
	return {"mode":mode, "recipe":RECIPE, "recipe_sha256":RECIPE.sha256_text(),
		"helper_sha256":FileAccess.get_sha256("res://tests/play_pace004_brush_load.gd"),
		"started":started_usec > 0, "started_usec":started_usec, "stopped_usec":stopped_usec, "owner":owner,
		"pulses":pulses.duplicate(true), "errors":errors.duplicate(),
		"scope":{"normal_brush_queue":true,"native_world_queries_from_main":0,
			"priming_usec":0,"per_command_native_applied_receipts":false,
			"individual_admission_then_measured_cell_activity":true,
			"producer_cost_outside_main_callback":true}}
