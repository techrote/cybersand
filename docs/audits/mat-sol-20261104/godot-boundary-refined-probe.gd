extends SceneTree

# Run only in a separate watchdog-controlled process. This is a native-facade
# compatibility probe; the reservation receipt is synthetic, not a live Rapier
# body or a contact/clearance qualification. The native payload is the retained
# 520-cell, six-proxy fixture. A C++ exception escaping this facade can terminate
# the child process, which is evidence to preserve rather than a successful test.
var target_phase: String
var call_kind: String
var workers: int

func _init() -> void:
	call_deferred("_run")

func checked(condition: bool, label: String) -> bool:
	if condition:
		return true
	printerr("MAT_SOL_SETUP_FAILURE ", label)
	quit(3)
	return false

func command(world: Object, request: Dictionary) -> Dictionary:
	var result: Dictionary = world.solid_detachment_command(request)
	print("MAT_SOL_STAGE ", JSON.stringify({"action":request.action, "ok":result.get("ok",false),
		"phase":result.get("phase",-1), "outcome":result.get("outcome",""),
		"member_count":result.get("member_count",0), "shape_count":result.get("shape_count",0)}))
	return result

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not checked(args.size() == 3, "usage: PHASE CALL WORKERS"):
		return
	target_phase = args[0]
	call_kind = args[1]
	workers = int(args[2])
	if not checked(workers in [1,4], "registered worker count"):
		return
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	if not checked(world != null, "native extension is registered"):
		return
	if not checked(bool(world.diagnostic_reset({"workers":workers, "telemetry":false})), "reset"):
		return
	world.set_simulation_window_enabled(false)
	for rectangle in [Rect2i(0,72,128,4), Rect2i(50,40,4,32), Rect2i(44,27,29,13),
		Rect2i(54,40,11,4), Rect2i(88,45,3,27)]:
		var material: int = 1 if rectangle.position.y == 72 else 43
		if not checked(bool(world.diagnostic_fill_rect(rectangle.position, rectangle.size, material)), "fixture fill"):
			return
	if not checked(bool(world.diagnostic_fill_rect(Vector2i(60,32),Vector2i(1,1),0)), "hole"):
		return
	if not checked(bool(world.diagnostic_fill_rect(Vector2i(50,65),Vector2i(4,2),0)), "cut"):
		return
	if not checked(bool(world.simulation_tick()), "apply simulation region"):
		return
	var state: Dictionary = {}
	if target_phase != "disabled":
		state = command(world, {"action":"configure","members":1024,"shapes":64})
		if not checked(state.get("ok",false), "configure"):
			return
	if target_phase not in ["disabled","idle"]:
		state = command(world, {"action":"prepare","domain":Rect2i(32,16,64,64),
			"anchors":Rect2i(0,67,128,13),"seed":Vector2i(51,34)})
		if not checked(state.get("ok",false) and state.get("member_count",0) == 520
			and state.get("shape_count",0) == 6, "prepare exact 520-cell/six-proxy payload"):
			return
		if target_phase == "cancel":
			state = command(world, {"action":"cancel","token":state.token})
		elif target_phase not in ["prepared","reset"]:
			state = command(world, {"action":"acknowledge","token":state.token,"body_id":1,
				"body_generation":7,"shape_count":state.shape_count,"payload_digest":state.payload_digest,
				"shape_digest":state.shape_digest})
			if not checked(state.get("ok",false), "acknowledge"):
				return
			if target_phase != "acknowledged":
				state = command(world, {"action":"commit","token":state.token})
				if not checked(state.get("ok",false), "commit"):
					return
				if target_phase in ["restored","rollback"]:
					state = command(world, {"action":"rollback","token":state.token})
					if not checked(state.get("ok",false), "rollback"):
						return
				if target_phase in ["active","rollback"]:
					var action: String = "finalize" if target_phase == "active" else "finish_rollback"
					state = command(world, {"action":action,"token":state.token,"body_id":1,
						"body_generation":7,"terrain_revision":state.commit_revision,"physics_epoch":17})
					if not checked(state.get("ok",false), action):
						return
	if target_phase == "reset":
		if not checked(bool(world.diagnostic_reset({"workers":workers,"telemetry":false})), "reset retires SOL"):
			return
	print("MAT_SOL_BEFORE_CALL ", JSON.stringify({"phase":target_phase,"call":call_kind,
		"native_phase":state.get("phase",-1),"workers":workers,"platform":OS.get_name()}))
	var result: Variant
	match call_kind:
		"physical":
			result = world.get_physical_state_hash()
		"liquid1":
			result = world.get_liquid_comparison_hash(1)
		"liquid2":
			result = world.get_liquid_comparison_hash(2)
		"window":
			world.set_simulation_window_enabled(true)
			result = {"reported_enabled":world.get_simulation_window_enabled()}
		"export":
			var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
			if not checked(bridge != null, "native export facade exists"):
				return
			var bytes: PackedByteArray = bridge.export_physical_state(world)
			result = {"bytes":bytes.size()}
		"diagnostic":
			var diagnostic: Dictionary = world.diagnostic_snapshot(Vector2i(0,0),Vector2i(128,128),false)
			result = {"returned":true,"state_hash":diagnostic.get("state_hash","unreported")}
		"adhesion":
			var before: bool = bool(world.get_liquid_surface_adhesion_enabled())
			world.set_liquid_surface_adhesion_enabled(not before)
			var reported: bool = bool(world.get_liquid_surface_adhesion_enabled())
			if target_phase in ["prepared","acknowledged"]:
				state = command(world, {"action":"cancel","token":state.token})
			elif target_phase in ["committed","restored"]:
				if target_phase == "committed":
					state = command(world, {"action":"rollback","token":state.token})
				state = command(world, {"action":"finish_rollback","token":state.token,"body_id":1,
					"body_generation":7,"terrain_revision":state.commit_revision,"physics_epoch":17})
			var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
			var saved: PackedByteArray = bridge.export_physical_state(world)
			if not checked(saved.size() > 0, "idle export after safe transaction completion"):
				return
			var restored_world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
			if not checked(bool(restored_world.diagnostic_reset({"workers":workers,"telemetry":false})), "restore owner"):
				return
			if not checked(bool(bridge.import_physical_state(restored_world,saved)), "native CYPS roundtrip"):
				return
			var applied: bool = bool(restored_world.get_liquid_surface_adhesion_enabled())
			result = {"prior_reported":before,"requested":not before,"reported_after_request":reported,
				"applied_from_native_cyps":applied,"matches_authority":reported == applied}
		_:
			if not checked(false,"unknown call"):
				return
	print("MAT_SOL_AFTER_CALL ", JSON.stringify({"phase":target_phase,"call":call_kind,"result":result}))
	quit(0)
