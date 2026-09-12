extends SceneTree

const Profiles=preload("res://scripts/water_experiment_profiles.gd")
const Scenarios=preload("res://scripts/water_feel_scenarios.gd")

var failures: int=0

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	if condition: return
	failures+=1
	push_error(message)

func _run() -> void:
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"),"native World is unavailable")
	_expect(ClassDB.class_exists(&"CyberDemoBridge"),"native demo bridge is unavailable")
	if failures!=0:
		quit(failures);return
	var world: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Object=ClassDB.instantiate(&"CyberDemoBridge")
	var transport: Dictionary=CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	var recipe: Dictionary=Scenarios.recipe("shallow-pool",1729)
	var correspondence_hash: String=""
	for bits: int in range(3,9):
		for coherence: int in [0,3,7,12]:
			var resolved: Dictionary=Profiles.resolve({},{},{"mass_bits":bits,
				"coherence_ticks":coherence,"scenario_id":"shallow-pool","seed":1729})
			_expect(resolved.ok,"registered policy did not resolve")
			_expect(bridge.build_water_feel_world(world,recipe.rectangles,
				transport.packed,resolved.semantic,recipe.partial_water_fills),
				"registered policy did not build")
			var actual: Dictionary=world.get_water_experiment_policy()
			_expect(actual.get("mass_bits",-1)==bits,"native mass bits differ")
			_expect(actual.get("coherence_ticks",-1)==coherence,"native coherence differs")
			_expect(actual.get("maximum",-1)==(1<<bits)-1,"native maximum differs")
			var first: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
				Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
			var packet: Dictionary=world.take_render_snapshot(true)
			_expect(int(packet.get("channels",0))==2,"Water experiment did not publish RG8")
			_expect(not PackedByteArray(packet.get("cells",PackedByteArray())).is_empty(),
				"Water experiment full publication is empty")
			_expect(bridge.build_water_feel_world(world,recipe.rectangles,
				transport.packed,resolved.semantic,recipe.partial_water_fills),
				"identical reset failed")
			var second: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
				Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
			_expect(first==second,"identical Apply + Reset was not bit-repeatable")
			if bits==8 and coherence==12: correspondence_hash=str(first.state_hash)
	_expect(not correspondence_hash.is_empty(),"default correspondence observation missing")
	for scenario_id: String in Scenarios.ids():
		for bits: int in [3,8]:
			var coherence: int=0 if bits==3 else 12
			var scenario_policy: Dictionary=Profiles.resolve({},{},{"mass_bits":bits,
				"coherence_ticks":coherence,"scenario_id":scenario_id,"seed":31})
			var scenario_recipe: Dictionary=Scenarios.recipe(scenario_id,31)
			var built: bool=bridge.build_water_feel_world(world,scenario_recipe.rectangles,
				transport.packed,scenario_policy.semantic,scenario_recipe.partial_water_fills)
			_expect(built,"scenario %s rejected mass%d/coherence%d" % [scenario_id,bits,coherence])
			if built:
				for action: Dictionary in scenario_recipe.actions:
					var action_ok: bool=true
					if str(action.kind)=="fill":
						var action_coherence: int=int((2*int(action.coherence)*coherence+12)/24)
						action_ok=world.water_experiment_fill_rect(
							Vector2i(int(action.x),int(action.y)),
							Vector2i(int(action.width),int(action.height)),
							int(action.normalized_mass),action_coherence)
					elif str(action.kind)=="erase":
						action_ok=world.water_experiment_erase_rect(
							Vector2i(int(action.x),int(action.y)),
							Vector2i(int(action.width),int(action.height)))
					elif str(action.kind)=="sample":
						action_ok=not world.water_experiment_observation(
							Vector2i(int(action.x),int(action.y)),
							Vector2i(int(action.width),int(action.height))).is_empty()
					_expect(action_ok,"scenario %s action rejected mass%d/coherence%d" % [
						scenario_id,bits,coherence])

	var before_invalid: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	_expect(not bridge.build_water_feel_world(world,recipe.rectangles,transport.packed,
		PackedInt32Array([1,2,12,0]),recipe.partial_water_fills),
		"invalid mass precision was accepted")
	var after_invalid: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	_expect(before_invalid==after_invalid,"invalid application mutated the running World")

	# Ordinary construction is an isolation boundary: a prior experimental
	# lattice must not leak into a Fresh Tower/profile reset or another demo.
	var non_default: Dictionary=Profiles.resolve({},{},{"mass_bits":3,
		"coherence_ticks":7,"scenario_id":"shallow-pool","seed":1729})
	_expect(bridge.build_water_feel_world(world,recipe.rectangles,transport.packed,
		non_default.semantic,recipe.partial_water_fills),"non-default isolation setup failed")
	_expect(bridge.build_tuned_world(world,CyberExperimentTower.rectangles(),transport.packed),
		"ordinary tuned world did not rebuild after Water Feel")
	var tuned_policy: Dictionary=world.get_water_experiment_policy()
	_expect(int(tuned_policy.get("mass_bits",-1))==8
		and int(tuned_policy.get("coherence_ticks",-1))==12,
		"ordinary tuned world retained the experimental Water policy")
	var clean_tuned: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(bridge.build_tuned_world(clean_tuned,CyberExperimentTower.rectangles(),transport.packed),
		"clean ordinary tuned-world control did not build")
	var tuned_hash: String=str(world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)).state_hash)
	var clean_tuned_hash: String=str(clean_tuned.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)).state_hash)
	_expect(tuned_hash==clean_tuned_hash,
		"ordinary tuned-world state hash depended on the preceding Water policy")

	_expect(bridge.build_water_feel_world(world,recipe.rectangles,transport.packed,
		non_default.semantic,recipe.partial_water_fills),"ordinary-demo isolation setup failed")
	var ordinary_rectangles: PackedInt32Array=CyberDemoWorlds.rectangles("waterworks")
	_expect(bridge.build_world(world,ordinary_rectangles),
		"ordinary demo did not rebuild after Water Feel")
	var demo_policy: Dictionary=world.get_water_experiment_policy()
	_expect(int(demo_policy.get("mass_bits",-1))==8
		and int(demo_policy.get("coherence_ticks",-1))==12,
		"ordinary demo retained the experimental Water policy")
	var clean_demo: Object=ClassDB.instantiate(&"CyberNativeCellWorld")
	_expect(bridge.build_world(clean_demo,ordinary_rectangles),
		"clean ordinary-demo control did not build")
	var demo_hash: String=str(world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)).state_hash)
	var clean_demo_hash: String=str(clean_demo.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT)).state_hash)
	_expect(demo_hash==clean_demo_hash,
		"ordinary-demo state hash depended on the preceding Water policy")

	var action_region:=Vector2i(8,8)
	var before_action: Dictionary=world.water_experiment_observation(Vector2i(500,500),action_region)
	_expect(world.water_experiment_fill_rect(Vector2i(500,500),action_region,128,7),
		"registered source action failed")
	var after_fill: Dictionary=world.water_experiment_observation(Vector2i(500,500),action_region)
	_expect(int(after_fill.water_integer)>int(before_action.water_integer),"source was not observable")
	_expect(world.water_experiment_erase_rect(Vector2i(500,500),action_region),
		"registered sink action failed")
	var after_erase: Dictionary=world.water_experiment_observation(Vector2i(500,500),action_region)
	_expect(int(after_erase.water_integer)==0,"sink did not remove its bounded Water")

	var worker_policy: Dictionary=Profiles.resolve({},{},{"mass_bits":3,
		"coherence_ticks":7,"scenario_id":"drips","seed":91})
	var owner:=CyberSimulationWorker.new()
	owner._world=world
	owner.queue_lab({"water_reset":true,"water_policy":worker_policy.policy,
		"water_policy_hash":worker_policy.hash,"water_policy_provenance":worker_policy.provenance})
	_expect(owner.start_worker(Vector2(24,222))==OK,"desktop Water owner did not start")
	var deadline: int=Time.get_ticks_msec()+15_000
	var owner_snapshot: CyberSimulationSnapshot
	while Time.get_ticks_msec()<deadline:
		await process_frame
		owner_snapshot=owner.take_latest_snapshot(-1)
		if owner_snapshot!=null and owner_snapshot.lab_context.get("water_active",false): break
	_expect(owner_snapshot!=null and owner_snapshot.lab_context.get("water_active",false),
		"desktop owner did not apply Water reset: "+str(owner_snapshot.lab_context if owner_snapshot!=null else {}))
	if owner_snapshot!=null:
		_expect(str(owner_snapshot.lab_context.water_policy_hash)==str(worker_policy.hash),
			"desktop owner published a different policy hash")
		_expect(owner_snapshot.lab_context.water_accounting.has(
			"initial_quantization_error_numerator_255"),"initial quantization error is absent")
	owner.queue_lab({"step":true})
	deadline=Time.get_ticks_msec()+15_000
	while Time.get_ticks_msec()<deadline:
		await process_frame
		owner_snapshot=owner.take_latest_snapshot(-1)
		if owner_snapshot!=null and owner_snapshot.tick_index>=1: break
	owner.stop_worker()
	_expect(owner_snapshot.tick_index==1,"desktop Water single-step was not exact: "+str(owner_snapshot.lab_context))
	_expect(owner_snapshot.lab_context.water_actions.size()>=1,
		"tick-zero deterministic Water action was not recorded")

	# Presentation switches consume copied RG8 data only. They cannot reach the
	# World and therefore leave both authoritative hashes unchanged, including
	# while an older immutable packet remains retained by a delayed consumer.
	var retained: PackedByteArray=PackedByteArray(world.take_render_snapshot(true).cells).duplicate()
	var retained_hash: int=hash(retained)
	var authoritative_before: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/material_palette.gdshader")
	material.set_shader_parameter("water_presentation_mode",1.0)
	material.set_shader_parameter("water_presentation_mode",2.0)
	var authoritative_after: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	_expect(authoritative_before==authoritative_after,"presentation mode changed authoritative state")
	_expect(hash(retained)==retained_hash,"retained RG8 packet changed after presentation switch")

	if failures==0:
		print("WATER_FEEL_INTEGRATION: 24 policy cases + 70 scenario builds/reset/invalid/actions/RG8/authority passed default_hash=",correspondence_hash)
	quit(failures)
