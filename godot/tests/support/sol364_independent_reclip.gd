extends SceneTree

# Independent review apparatus, deliberately outside the automatic test matrix.
# It transports actual owner-created witnesses from the retained 520-cell tree.
# tools/sol281/independent_reclip_oracle.py independently intersects those spans
# with cell edges using exact rational arithmetic and checks the response lever.
# This frozen value-plan review is not a live Rapier clearance qualification.
const Response = preload("res://scripts/solid_contact_response.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var output: String = "user://sol364-independent-reclip.json"
var source_identity: Dictionary = {}
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			output = argument.trim_prefix("--report=")
	call_deferred("_run")
func require(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		printerr(label)
func coordinates(value: Vector2) -> Array:
	return [value.x, value.y]
func _run() -> void:
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	require(world != null, "native API available")
	require(world.diagnostic_reset({"workers":1,"telemetry":false}), "native reset")
	world.set_simulation_window_enabled(false)
	for item: Array in [[0,72,128,4,1], [50,40,4,32,43], [44,27,29,13,43],
		[54,40,11,4,43], [8,45,3,27,43], [60,32,1,1,0]]:
		require(world.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]), "tree author")
	require(world.simulation_tick(), "inclusion tick")
	var configured: Dictionary = world.solid_detachment_command({"action":"configure","members":1024,"shapes":128})
	require(configured.get("ok",false), "capacity configure")
	var source: Dictionary = world.solid_detachment_command({"action":"cut_prepare","domain":Rect2i(32,16,64,64),
		"anchors":Rect2i(0,67,128,13),"seed":Vector2i(51,34),"cut":Rect2i(50,65,4,2)})
	require(source.get("ok",false) and int(source.get("member_count",0))==520 and int(source.get("shape_count",0))==6,"exact 520-cell six-proxy tree")
	if not failures.is_empty():
		finish();return
	source_identity = {"member_count":source.member_count,"shape_count":source.shape_count,
		"mass":source.mass,"inertia":source.inertia,"center":coordinates(source.center),
		"members":Array(source.members),"rectangles":Array(source.rectangles),
		"payload_digest":source.payload_digest,"shape_digest":source.shape_digest,
		"empty_witness_cells":[[60,32],[68,50]],
		"empty_witness_meanings":["enclosed authored crown hole","unoccupied concavity inside the aggregate AABB"]}
	var ack: Dictionary = world.solid_detachment_command({"action":"acknowledge","token":source.token,
		"body_id":1,"body_generation":7,"shape_count":source.shape_count,
		"payload_digest":source.payload_digest,"shape_digest":source.shape_digest})
	require(ack.get("ok",false),"ack")
	var committed: Dictionary = world.solid_detachment_command({"action":"commit","token":source.token})
	require(committed.get("ok",false),"commit")
	var active: Dictionary = world.solid_detachment_command({"action":"finalize","token":source.token,
		"body_id":1,"body_generation":7,"terrain_revision":committed.commit_revision,"physics_epoch":17})
	require(active.get("ok",false),"finalize")
	for item: Array in [[179,239,122,1,1], [179,120,1,119,1], [300,120,1,119,1], [180,120,120,119,2]]:
		require(world.diagnostic_fill_rect(Vector2i(item[0],item[1]),Vector2i(item[2],item[3]),item[4]), "frozen dense bank")
	require(world.simulation_tick(),"bank inclusion tick")
	var before: Dictionary = world.diagnostic_snapshot(Vector2i(170,110),Vector2i(140,140),false)
	var centers := PackedVector2Array()
	var sizes := PackedVector2Array()
	for i: int in range(0,source.rectangles.size(),4):
		var size := Vector2(source.rectangles[i+2],source.rectangles[i+3])
		sizes.append(size)
		centers.append(Vector2(source.rectangles[i],source.rectangles[i+1])+size*0.5-source.center)
	var normal_list := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]
	for angle: float in [0.13,0.37,-0.79,1.11]:
		var pose := Transform2D(angle,Vector2(240.25,180.5))
		var states := PackedFloat32Array()
		for i: int in range(centers.size()):
			Coupling.append_input(states,i+1,pose*centers[i],angle,sizes[i],Vector2.ZERO,0.0,sizes[i].x*sizes[i].y,100)
		world.prepare_rigid_body_coupling(states,false)
		var observation: Dictionary = world.solid_detachment_contact_observation()
		require(observation.get("ok",false),"frozen observation %.2f: %s" % [angle,observation.get("outcome")])
		if not observation.get("ok",false):continue
		var source_pose: Transform2D = observation.source_transform
		var inverse: Transform2D = source_pose.affine_inverse()
		for face: int in range(4):
			var selected: Array = []
			for contact: Dictionary in observation.contacts:
				if int(contact.face)==face:selected.append(contact)
			require(not selected.is_empty(),"each tree direction has witnessed exterior support")
			for turn: float in [-0.003,0.0,0.003]:
				for shift: Vector2 in [Vector2(-0.08,0.03),Vector2.ZERO,Vector2(0.08,-0.03)]:
					var current := Transform2D(source_pose.get_rotation()+turn,source_pose.origin+shift)
					var input: Dictionary = observation.duplicate(true)
					input.contacts=selected
					var outward: Vector2 = current.basis_xform(normal_list[face]).normalized()
					var plan: Dictionary = Response.plan(input,current,outward*12.0,0.0,float(source.mass),float(source.inertia),centers,sizes)
					var spans: Array[Dictionary] = []
					for contact: Dictionary in selected:
						var a: Vector2 = current*(inverse*(contact.a as Vector2))
						var b: Vector2 = current*(inverse*(contact.b as Vector2))
						spans.append({"proxy":contact.proxy,"face":contact.face,"a":coordinates(a),"b":coordinates(b),"cell":[contact.cell.x,contact.cell.y],
							"old_point":coordinates(current*(inverse*(contact.point as Vector2)))})
					var actions: Array[Dictionary] = []
					for action: Dictionary in plan.get("impulses",[]):
						actions.append({"offset":coordinates(action.offset),"impulse":coordinates(action.impulse)})
					cases.append({"angle":angle,"face":face,"turn":turn,"shift":coordinates(shift),"origin":coordinates(current.origin),
						"outcome":plan.get("outcome"),"accepted":plan.get("accepted",false),"contact_count":plan.get("contact_count",-1),
						"source_contact_count":plan.get("source_contact_count",-1),"energy_before":plan.get("energy_before",-1.0),
						"energy_after":plan.get("energy_after",-1.0),"energy_tolerance":plan.get("energy_tolerance",-1.0),"spans":spans,"impulses":actions})
	var after: Dictionary = world.diagnostic_snapshot(Vector2i(170,110),Vector2i(140,140),false)
	require(before.get("cells")==after.get("cells") and before.get("counts")==after.get("counts"),"unchanged authoritative cells")
	var retained: Dictionary = world.solid_detachment_command({"action":"inspect"})
	require(retained.members==source.members and retained.aggregate_owned==520 and retained.native_source_members==0,"exclusive exact 520 tuples")
	finish()
func finish() -> void:
	var code_hashes: Dictionary = {}
	for path: String in ["res://scripts/solid_contact_response.gd", "res://scripts/rigid_body_coupling.gd",
		"res://tests/support/sol364_independent_reclip.gd",
		"res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"]:
		code_hashes[path] = FileAccess.get_sha256(path)
	var report := {"schema":"sol364.independent-reclip.v1","cases":cases,"failures":failures,
		"fixture":source_identity,"platform":OS.get_name(),"engine":Engine.get_version_info().string,
		"workers":1,"code_hashes":code_hashes}
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SOL364_INDEPENDENT_RECLIP ",cases.size()," cases failures=",failures)
	quit(0 if failures.is_empty() else 1)
