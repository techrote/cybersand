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

	var before_invalid: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	_expect(not bridge.build_water_feel_world(world,recipe.rectangles,transport.packed,
		PackedInt32Array([1,2,12,0]),recipe.partial_water_fills),
		"invalid mass precision was accepted")
	var after_invalid: Dictionary=world.water_experiment_observation(Vector2i.ZERO,
		Vector2i(CyberCellWorld.WORLD_WIDTH,CyberCellWorld.WORLD_HEIGHT))
	_expect(before_invalid==after_invalid,"invalid application mutated the running World")

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
		print("WATER_FEEL_INTEGRATION: 24 policies/reset/invalid/actions/RG8/authority passed default_hash=",correspondence_hash)
	quit(failures)
