extends SceneTree

const PlayerInput=preload("res://scripts/player_playground_input.gd")
var checks:=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("_run")
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: failures.append(why);push_error(why);quit(1)
func neutral() -> Dictionary: return {"move":Vector2.ZERO,"aim":Vector2.RIGHT,"effort":1.0,"trim":0.0,"primary":false,"secondary":false,"auxiliary":false}
func key_event(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
	event.shift_pressed=pressed and code==KEY_SHIFT
	event.ctrl_pressed=pressed and code==KEY_CTRL
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _run() -> void:
	var scene=load("res://gcr_fleet_playground.tscn").instantiate()
	root.add_child(scene);scene.set_physics_process(false);await process_frame
	check(not scene.room_source.armed and not scene.room_source_enabled.button_pressed,"room source initially off")
	check(scene.control_fields.boost_multiplier.value==2.0,"visible default Shift multiplier")
	for keys: Dictionary in [{KEY_SHIFT:true},{KEY_CTRL:true},{KEY_SHIFT:true,KEY_CTRL:true}]:
		var action: Dictionary=scene.remap_fleet_brake(PlayerInput.from_state(keys),bool(keys.get(KEY_CTRL,false)),false)
		check(action.secondary==bool(keys.get(KEY_CTRL,false)) and not action.has("boost"),"fleet remap preserves shared action schema; Ctrl is brake")
	check(scene.remap_fleet_brake(neutral(),false,true).secondary,"gamepad brake remains available")
	key_event(KEY_SHIFT,true)
	check(scene._review_ports().boost and not scene._sample_action().secondary,"actual sampled Shift boosts without old braking")
	scene._rearm=true;scene.advance_frame(scene._sample_action(),true)
	check(scene._rearm,"held Shift cannot rearm after cancellation")
	key_event(KEY_SHIFT,false);scene.advance_frame(neutral(),true)
	check(not scene._rearm,"released Shift permits rearm")
	key_event(KEY_CTRL,true)
	check(scene._sample_action().secondary and not scene._review_ports().boost,"actual Ctrl sampler applies old brake")
	key_event(KEY_CTRL,false)
	for index: int in range(7):
		check(scene.select_preset(index),"full flyer roster admitted")
		var arena=scene.runtime._arena
		var session_id: int=arena.session.get_instance_id()
		var body: RigidBody2D=arena.session.bodies()[0]
		var initial_pose: Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
		check(scene.place_room_source() and scene.emit_room_burst(),"source placement and burst on any flyer")
		check(arena.session.get_instance_id()==session_id and PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)==initial_pose,"arming/burst cannot reset actor or map")
		check(is_equal_approx(body.gravity_scale,38.0/980.0) and not scene.powder_test.active(),"normal gravity and gameplay retained")
		check(scene.room_source.inserted==0 and scene.room_source.burst_queued,"source edits deferred to next actual owner step")
		scene.runtime.set_paused(true);scene.advance_frame(neutral(),false)
		check(scene.room_source.inserted==0 and scene.room_source.burst_queued,"pause freezes queued burst")
		scene.runtime.set_paused(false);scene.advance_frame(neutral(),false)
		check(scene.room_source.inserted==96 and scene.room_source.attempted==96,"one normal owner step supplies bounded real burst")
		var fixed: Vector2i=scene.room_source.origin
		check(scene.set_room_stream(true),"normal room stream toggle on")
		scene.advance_frame(neutral(),false)
		check(scene.room_source.origin==fixed and scene.room_source.attempted==100,"stream stays world-fixed while physics continues")
		check(scene.set_room_stream(false),"stream toggle off")
		scene.advance_frame(neutral(),false)
		check(scene.room_source.attempted==100,"off toggle stops authoring")
		check(scene.paint_at(Vector2i(800,100),23) and not scene.runtime.paused,"normal painting remains live and does not invoke isolated-test edit lock")
		scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check(not scene.room_source.armed and not scene.room_stream.button_pressed,"focus loss disarms source")
		scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
		check(not scene.room_source.armed,"focus gain cannot restart source")
	scene.paint_material=14
	check(scene.place_room_source() and scene.room_source.material==14,"source captures selected powder palette material")
	scene.paint_material=3
	check(not scene.place_room_source() and not scene.room_source.armed and not scene.control_error.is_empty(),"Water is refused explicitly as a powder source")
	scene.paint_material=2
	check(scene.place_room_source(),"source rearms deliberately after refusal")
	check(scene.start_powder_test("burst") and not scene.room_source.armed and scene.room_source_enabled.disabled and scene.room_stream.disabled,"isolated zero-gravity test keeps live room source disabled")
	check(scene.return_to_painting() and not scene.room_source_enabled.disabled,"return restores source controls and flight")
	scene.control_fields.boost_multiplier.value=3.0
	check(scene.apply_controls() and scene.applied_controls.boost_multiplier==3.0 and scene.runtime._arena.session._rigs[0]._profile.fleet_boost_multiplier==3.0,"Shift value stages through fresh actor construction")
	check(not scene.room_source.armed,"Apply reset disarms source")
	scene.restore_controls()
	check(scene.applied_controls.boost_multiplier==2.0 and scene.applied_controls.response=="LA","Restore preserves default comparison and modifier")
	scene.queue_free();await process_frame
	print("GCR_FLEET_ROOM_CONTROLS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
