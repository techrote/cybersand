extends SceneTree

# Native execution of ordinary authored recipes with an explicit full-canvas
# observer. These isolated fixtures qualify the demonstrations' consumers;
# test_material_audition.gd separately qualifies the mounted current Workbench.
const Scenes = preload("res://scripts/workbench_material_audition_scenes.gd")
var checks := 0
var failures := 0
var trials: Array = []
var policy := PackedInt32Array()
var native_path := ""
var native_digest := ""

func _initialize() -> void:
	run.call_deferred()

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAT_AUDITION_AUTHORED_SCENES: " + message)

func profile(id: String, materials: Array = [], reactions: Array = []) -> Dictionary:
	return {"schema_version":1,"profile_id":id,"materials":materials,"reactions":reactions}

func metrics(world: Variant, extent: Vector2i, channel: bool = false) -> Dictionary:
	var counts: Dictionary = {}
	var sums: Dictionary = {}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var first_cells := PackedByteArray()
	for x: int in range(0,extent.x,512):
		var size := Vector2i(mini(512,extent.x-x),extent.y)
		var snapshot: Dictionary = world.diagnostic_snapshot(Vector2i(x,0),size)
		if not snapshot.has("cells"):
			expect(false,"native authored-scene readback is available")
			return {}
		var cells: PackedByteArray = snapshot.cells
		digest.update(cells)
		if x == 0: first_cells = cells
		for id: int in [2,14,16,23,24]:
			var key := str(id)
			counts[key] = int(counts.get(key,0)) + int(snapshot.counts[id])
			sums[key] = int(sums.get(key,0)) + int(snapshot.sum_y[id])
	var means: Dictionary = {}
	for key: String in counts: means[key] = float(sums[key])/maxi(int(counts[key]),1)
	var result := {"tick":int(world.tick_index),"counts":counts,"mean_y":means,
		"material_cells_sha256":digest.finish().hex_encode()}
	if channel:
		result["throat_front"] = []
		result["throat_brine"] = 0
		for bay: int in range(3):
			var left := 12 + bay*168
			var front := 0
			for y: int in range(173,176):
				for x: int in range(left+68,left+138):
					if first_cells[y*512+x] == 24:
						result.throat_brine += 1
						front = maxi(front,x-left-68+1)
			result.throat_front.append(front)
	return result

func activate(world: Variant, proposed: Dictionary, extent: Vector2i) -> Dictionary:
	var before: Dictionary = world.get_material_audition_state()
	var cells := metrics(world,extent)
	var receipt: Dictionary = world.apply_material_audition({"world_id":before.world_id,
		"expected_revision":before.revision,"profile":proposed})
	expect(receipt.get("ok",false),"native authored-scene configuration admits: " + str(receipt.get("error","")))
	var after: Dictionary = world.get_material_audition_state()
	expect(after.world_id == before.world_id and after.revision == before.revision + 1,
		"configuration transition retains this World and advances its revision")
	expect(after.observed_tick == before.observed_tick and metrics(world,extent).material_cells_sha256 == cells.material_cells_sha256,
		"configuration transition changes neither the native tick nor stored material cells")
	return after

func step(world: Variant, ticks: int) -> void:
	var completed := true
	for tick: int in range(ticks):
		if not world.simulation_tick():
			completed = false
			break
	expect(completed,"authored scene completes %d actual native ticks" % ticks)

func trial(scene_id: String, proposed: Dictionary, wave: bool = false, wake_revert: bool = false) -> Dictionary:
	var setup: Dictionary = Scenes.create(scene_id,policy)
	var extent := Vector2i(setup.extent[0],setup.extent[1])
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	expect(world.diagnostic_reset({"workers":1,"extent":extent,"liquid_policy":policy,"wave_flow":wave}),
		"source-built native World accepts the authored recipe construction")
	# Fresh adapters otherwise observe only 320×180 plus a 36-cell buffer. The
	# ordinary Workbench loader selects Overview after its scene acknowledgement.
	world.set_simulation_window_enabled(true)
	world.set_simulation_window(Vector2i.ZERO,extent,0,0)
	var painted := true
	for edit: Array in setup.edits:
		painted = bool(world.diagnostic_fill_rect(Vector2i(edit[0],edit[1]),Vector2i(edit[2],edit[3]),edit[4])) and painted
	expect(painted,"all finite ordinary authored material rectangles are stored")
	var activated := activate(world,proposed,extent)
	var channel := scene_id == "viscosity-channel"
	var samples: Array = [metrics(world,extent,channel)]
	for interval: int in [180,180]:
		step(world,interval)
		samples.append(metrics(world,extent,channel))
	var result := {"scene_id":scene_id,"profile":proposed,"native_world_id":activated.world_id,
		"workers":1,"wave_water":wave,"liquid_policy":Array(policy),
		"observer":{"origin":[0,0],"size":setup.extent,"horizontal_buffer":0,"vertical_buffer":0,
			"simulation_window_enabled":true},
		"authored_rectangles":setup.edits.size(),"samples":samples}
	if wake_revert:
		var prior: Dictionary = samples.back()
		var resumed := activate(world,profile("channel-resume",[{"material_id":24,"viscosity":0}]),extent)
		step(world,180)
		var after_wake := metrics(world,extent,true)
		expect(after_wake.throat_brine > prior.throat_brine,"lower viscosity wakes and advances the existing resting Brine cells")
		var reverted := activate(world,proposed,extent)
		var after_revert := metrics(world,extent,true)
		expect(after_revert.material_cells_sha256 == after_wake.material_cells_sha256,
			"configuration Revert preserves the actual prior movement consequences")
		expect(resumed.world_id == activated.world_id and reverted.world_id == activated.world_id,
			"wake and Revert operate on the same existing native World")
		expect(after_revert.counts["24"] == samples[0].counts["24"],"Brine inventory is invariant through configuration wake and Revert")
		result["same_world_wake_revert"] = {"original_revision":activated.revision,"resumed_revision":resumed.revision,
			"reverted_revision":reverted.revision,"after_wake":after_wake,"after_revert":after_revert}
	trials.append(result)
	print("MAT_AUDITION_AUTHORED_TRIAL " + JSON.stringify(result))
	return result

func _run_trials() -> void:
	var defaults := trial("density-sorter",profile("accepted-default"))
	var density: Array = []
	for value: int in [500,1600,2400]:
		density.append(trial("density-sorter",profile("density-%d" % value,[{"material_id":2,"density":value}])))
	var baseline: Dictionary = defaults.samples.back()
	var low: Dictionary = density[0].samples.back()
	var equivalent: Dictionary = density[1].samples.back()
	var high: Dictionary = density[2].samples.back()
	expect(baseline.material_cells_sha256 == equivalent.material_cells_sha256,
		"accepted defaults and explicit equivalent density preserve all authored-scene material cells")
	expect(float(equivalent.mean_y["2"]) > float(low.mean_y["2"]) + 80.0,
		"authored Sand reaches measurably deeper Oil contacts with its admitted heavier density")
	expect(equivalent.material_cells_sha256 == high.material_cells_sha256,
		"two densities above Oil's threshold preserve the canonical boolean exchange law")
	for result: Dictionary in density:
		var last: Dictionary = result.samples.back()
		expect(last.counts == low.counts and last.mean_y["14"] == low.mean_y["14"],
			"density trials conserve material inventory and the independent Dust control")
	var viscosity: Array = []
	for value: int in [0,96,240]:
		viscosity.append(trial("viscosity-channel",profile("viscosity-%d" % value,[{"material_id":24,"viscosity":value}]),false,value==240))
	var fast: Dictionary = viscosity[0].samples.back()
	var medium: Dictionary = viscosity[1].samples.back()
	var resting: Dictionary = viscosity[2].samples.back()
	expect(fast.throat_brine > medium.throat_brine and medium.throat_brine > resting.throat_brine,
		"three admitted viscosities give ordered actual lateral advance through the authored throats")
	for result: Dictionary in viscosity:
		expect(result.samples.back().counts["24"] == result.samples[0].counts["24"],
			"each authored Brine trial preserves its finite material inventory")
	for wave: bool in [false,true]:
		var slow := trial("reaction-contact",profile("slow-contact",[],[{"slot":2,"probability_threshold":0}]),wave)
		var quick := trial("reaction-contact",profile("quick-contact",[],[{"slot":2,"probability_threshold":255}]),wave)
		expect(quick.samples.back().counts["24"] > slow.samples.back().counts["24"] + 1000,
			"actual stored Brine products separate admitted thresholds with Wave Water %s" % str(wave))
	var industrial := trial("industrial-loop",profile("industrial-default"),true)
	expect(industrial.samples.back().mean_y["2"] > industrial.samples[0].mean_y["2"] + 100.0,
		"mixed industrial apparatus advances real Sand through its classifier")
	expect(industrial.samples.back().counts["23"] < industrial.samples[0].counts["23"] and
		industrial.samples.back().counts["24"] > industrial.samples[0].counts["24"],
		"mixed industrial apparatus contains actual consumed Salt and additional Brine products")

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativeCellWorld") or not ClassDB.class_exists(&"CyberDemoBridge"):
		expect(false,"native extension is present; an unexecuted fixture is never a pass")
	else:
		var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
		policy = bridge.default_liquid_policy()
		native_path = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
		native_digest = FileAccess.get_sha256(native_path)
		var probe: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
		expect(probe.has_method("apply_material_audition"),"current-scene native API is present")
		if failures == 0: _run_trials()
		expect(FileAccess.get_sha256(native_path) == native_digest,"observed native library file remains unchanged during execution")
	var report := {"checks":checks,"failures":failures,"status":"passed" if failures==0 else "failed",
		"scope":"Isolated native execution of ordinary authored recipes; mounted current-scene UI and graphical qualification are separate",
		"godot":Engine.get_version_info().string,"display":DisplayServer.get_name(),"native_file_sha256":native_digest,
		"native_identity_scope":"Observed runtime file; source/build closure is supplied by evaluator provenance",
		"recipe_sha256":FileAccess.get_sha256("res://scripts/workbench_material_audition_scenes.gd"),"trials":trials}
	var directory := OS.get_environment("MAT_AUDITION_DEMO_EVIDENCE_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("authored-scene-readback.json"),FileAccess.WRITE)
		if file == null:
			expect(false,"authored-scene evidence file is writable")
		else: file.store_string(JSON.stringify(report,"\t") + "\n")
	print("MAT_AUDITION_AUTHORED_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"trials":trials.size(),"native_file_sha256":native_digest}))
	quit(1 if failures else 0)
