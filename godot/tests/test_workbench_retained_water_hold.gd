extends SceneTree

# Focused production-admission test. The owner and completed-step values below
# are explicit synthetic inputs; mounted native/framebuffer qualification is
# separate. Real immutable Images, ImageTextures and a real Rapier RID exercise
# the material/ownership seam. No fake physical completion is reported.
const Main = preload("res://scripts/main.gd")
const Session = preload("res://scripts/physical_actor_session.gd")
const Bridge = preload("res://scripts/workbench_physics_bridge.gd")
var checks := 0
var failures: Array[String] = []
var app: Control
var session: Node2D
var bridge: RefCounted
var previous: Dictionary
var context: Dictionary
var original_proof: Dictionary
var pose := Transform2D(0,Vector2(16,16))

func _initialize() -> void:
	OS.set_environment("CYBERSAND_DIAG_PRESENTATION","coherent")
	OS.set_environment("CYBERSAND_DIAG_WATER_COMPOSITION","1")
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("RETAINED_WATER_HOLD: "+label)

func fresh_context() -> Dictionary:
	var result := context.duplicate(true)
	result.deadline_usec = Time.get_ticks_usec()+1000000
	return result

func hold(settings: Dictionary = {}, summary: Dictionary = {}) -> Dictionary:
	var current := fresh_context() if settings.is_empty() else settings
	var budget := {"cells_examined":0,"budget_vetoes":0} if summary.is_empty() else summary
	var result: Dictionary = app._submitted_water_hold(0,previous,current)
	# The baseline has only strict transport-identity retention. Calling it
	# first reproduces the actual resolver's existing admission order.
	if result.is_empty() and app.has_method("_revalidated_submitted_water_hold"):
		result = app._revalidated_submitted_water_hold(0,previous,current,budget)
	return result

func new_material(front: int = 3, back: int = 3) -> void:
	app.image.fill(Color(float(front)/255.0,0,0,1))
	app._presentation_previous_image.fill(Color(float(back)/255.0,0,0,1))
	app._presentation_current_bytes = app.image.get_data()
	app._presentation_previous_bytes = app._presentation_previous_image.get_data()
	app.texture.update(app.image)
	app.previous_texture.update(app._presentation_previous_image)
	app._presentation_current_content_id += 1
	app._presentation_previous_content_id += 1
	app.last_uploaded_render_snapshot_serial += 1
	app.last_uploaded_revision += 1

func _run() -> void:
	app = Main.new()
	session = Session.new()
	bridge = Bridge.new()
	var body := PhysicsServer2D.body_create()
	bridge._session = 5
	bridge._epoch = 7
	bridge._members.append({"instance_id":11,"generation":7})
	bridge._body_rids.append(body)
	bridge._rects.append([{"center":Vector2.ZERO,"size":Vector2(5,4)}])
	session.bridge = bridge
	session.tick = 8
	app.physical_actor_session = session
	app.rapier_bridge = bridge
	app._physical_terrain_ready = true
	app._workbench_sample_identity = [5,7]
	app.image = Image.create(32,32,false,Image.FORMAT_RG8)
	app.image.fill(Color(3.0/255.0,0,0,1))
	app._presentation_previous_image = app.image.duplicate()
	app._presentation_previous_unknown = false
	app._presentation_current_content_id = 21
	app._presentation_previous_content_id = 20
	app._presentation_current_content_shape = Vector3i(32,32,Image.FORMAT_RG8)
	app._presentation_previous_content_shape = app._presentation_current_content_shape
	app.last_uploaded_world_generation = 4
	app.last_uploaded_revision = 9
	app.last_uploaded_render_snapshot_serial = 30
	app.texture = ImageTexture.create_from_image(app.image)
	app.previous_texture = ImageTexture.create_from_image(app._presentation_previous_image)
	context = {"previous_blend_active":true,"mask_native_tick":40,
		"mask_frame":{"instances":{11:{"sample":9}}},"deadline_usec":0}
	var endpoint: Dictionary = app._workbench_water_coverage_identity(0,pose,pose,bridge._rects[0],context).duplicate(true)
	previous = {"step":7,"pose":pose,"water_composed":true,"water_coverage_identity":endpoint,
		"withheld_frames":0,"instance_id":11,"generation":7,"contact_clipped":false}
	original_proof = {"schema":"workbench-water-composition-v2","kind":"current_completed_native_dependency",
		"physical_completion_claim":true,"consumed_by_step":true,"step":7,"sample":9,"native_tick":40,
		"instance_id":11,"generation":7,"completed_usec":200,"native_completed_usec":100,
		"visible_material":{"world":4,"revision":9,"upload_serial":30,"current_content":21,
			"previous_content":20,"native_tick":40,"native_sample":9}}
	app.workbench_presentation_frame = {"water_proofs":{0:original_proof},"poses":{0:pose}}
	var immutable_original := original_proof.duplicate(true)
	check(hold()==original_proof,"unchanged transport retains the already-submitted original proof")
	context.mask_native_tick = 41
	context.mask_frame.instances[11].sample = 10
	check(app._submitted_water_hold(0,previous,fresh_context()).is_empty(),
		"new native sample is never relabelled as the original strict proof")
	var kept := hold()
	check(not kept.is_empty(),"new native response identity can retain a separately certified old endpoint")
	if not kept.is_empty():
		check(kept.step==7 and kept.sample==9 and kept.native_tick==40 and kept.completed_usec==200,
			"retention preserves the original physical and native clocks")
		check(kept.visible_material.native_tick==41 and kept.visible_material.native_sample==10,
			"visible material keeps the newer native receipt identity separately")
		check(kept.get("held_material_revalidation",{}).get("selected_pose")==pose,
			"the retained endpoint is explicit rather than a newly completed current pose")
	new_material()
	kept = hold()
	check(not kept.is_empty(),"a newer all-Water publication may independently recertify the same held endpoint")
	if not kept.is_empty():
		check(kept.visible_material.revision==app.last_uploaded_revision
			and kept.visible_material.upload_serial==app.last_uploaded_render_snapshot_serial,
			"new coverage records the actual changed material revision and upload")
	check(original_proof==immutable_original,"retention never mutates the original submitted proof")
	new_material(2,3)
	check(hold().is_empty(),"new current Sand cannot inherit an old Water clearance")
	new_material(3,2)
	check(hold().is_empty(),"active previous Sand independently prevents Water retention")
	new_material()
	var expired := fresh_context()
	expired.deadline_usec = 1
	check(hold(expired).is_empty(),"changed material cannot rescan after the shared time allowance expires")
	check(hold(fresh_context(),{"cells_examined":app.PRESENTATION_FRAME_SCAN_BUDGET,"budget_vetoes":0}).is_empty(),
		"changed material cannot acquire a second shared cell allowance")
	app._presentation_previous_unknown = true
	check(hold().is_empty(),"unknown active previous history cannot be retained")
	app._presentation_previous_unknown = false
	for field: String in ["last_uploaded_world_generation","_actor_reset_receipt"]:
		var value: int = app.get(field)
		app.set(field,value+1)
		check(hold().is_empty(),"changed ownership fence refuses retention: "+field)
		app.set(field,value)
	bridge._epoch += 1
	check(hold().is_empty(),"a replacement owner epoch cannot borrow the submitted endpoint")
	bridge._epoch -= 1
	bridge._members[0].generation += 1
	check(hold().is_empty(),"a new member generation cannot inherit the old endpoint")
	bridge._members[0].generation -= 1
	bridge._rects[0][0].size.x += 1
	check(hold().is_empty(),"reconstructed geometry needs its own current presentation authority")
	bridge._rects[0][0].size.x -= 1
	app.pending_microscenario_apply = {"serial":1}
	check(hold().is_empty(),"a staged scene replacement cannot recertify a historical hold")
	app.pending_microscenario_apply = {}
	app._workbench_frame_error = "refused"
	check(hold().is_empty(),"a refused native owner cannot retain the historical endpoint")
	app._workbench_frame_error = ""
	previous.pose = Transform2D(0,Vector2(16.5,16))
	check(hold().is_empty(),"retention cannot invent a pose between completed observations")
	previous.pose = pose
	previous.step = 6
	check(hold().is_empty(),"the originally submitted physical step cannot be changed")
	previous.step = 7
	previous.withheld_frames = 1
	check(hold().is_empty(),"a withheld frame cannot restart this submitted-pose hold")
	previous.withheld_frames = 0
	app.workbench_presentation_frame.water_proofs.clear()
	check(hold().is_empty(),"there is no hold without an actual previous submitted proof")
	check(session.tick==8 and bridge.manual_step_count()==0,
		"presentation revalidation creates no physical or manual-step completion")
	bridge._body_rids.clear()
	PhysicsServer2D.free_rid(body)
	app.physical_actor_session = null
	session.bridge = null
	session.free()
	app.free()
	print("PUBPRES_RETAINED_WATER_HOLD_RESULT "+JSON.stringify({"checks":checks,"failures":failures,
		"scope":"Synthetic owner admission with real image/texture/RID resources; no mounted physical claim"}))
	quit(int(not failures.is_empty()))
