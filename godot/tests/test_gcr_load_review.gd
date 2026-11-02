extends SceneTree
const Review = preload("res://scripts/gcr_load_review.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		printerr("FAIL LA REVIEW ",message)
func _init() -> void:
	call_deferred("_run")
func wait_review(view: Node) -> bool:
	var deadline: int = Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline:
		if view.fixture!=null and not view.resetting: return true
		await process_frame
	return false
func _run() -> void:
	var view := Review.new()
	root.add_child(view)
	current_scene=view
	check(await wait_review(view),"source-matched barrel scene ready")
	if view.fixture!=null:
		check(view.fixture.candidate=="GCR-REST" and str(view.fixture.spec.get("rest_mode",""))=="control" and float(view.fixture.spec.get("base_budget",0))==20.0,"explicit experimental LA selection")
		check(view.paused and view.fixture.tick==0,"owner starts paused without efficacy trajectory")
		check(view.cases.size()>=11,"original references and registered rest mechanisms exposed")
		check(is_equal_approx(view.fixture.bodies[0].mass,1.0),"registered mass1 default")
		var old_fixture: RefCounted = view.fixture
		view.parameters.mass.value=2.0
		view.parameters.gravity.value=46.06
		view.parameters.friction.value=.1
		view.parameters.inertia_multiplier.value=2.0
		await process_frame # SpinBox formats its programmatically staged text deferred.
		check(view.fixture==old_fixture and is_equal_approx(view.fixture.bodies[0].mass,1.0),"staging does not mutate active physical state")
		await view._apply_parameters()
		check(old_fixture.world==null,"apply closes old native owner")
		var body: RigidBody2D = view.fixture.bodies[0]
		check(is_equal_approx(body.mass,2.0),"actual overridden barrel mass")
		check(is_equal_approx(body.gravity_scale,.047),"actual overridden gravity")
		check(absf(body.inertia-260.0/3.0)<.001,"independent actual inertia override")
		check(absf(float(PhysicsServer2D.body_get_param(body.get_rid(),PhysicsServer2D.BODY_PARAM_FRICTION))-.1)<.0001,"actual backend friction override")
		check("EXPLORATORY" in view.parameter_status.text,"override visibly labelled")
		await view.reset_case()
		check(is_equal_approx(view.fixture.bodies[0].mass,1.0) and "Registered" in view.parameter_status.text,"reset restores registered selected case")
		old_fixture=view.fixture
		view._structure_room()
		await process_frame
		await process_frame
		var lab: Node = current_scene
		var deadline: int = Time.get_ticks_msec()+15000
		while lab.busy and Time.get_ticks_msec()<deadline: await process_frame
		check(old_fixture.world==null,"room switch retires barrel owner")
		check(lab.session!=null and lab.session.worker!=null and not lab.session.active,"original structure room ready anchored")
		var old_session: RefCounted = lab.session
		var key := InputEventKey.new()
		key.keycode=KEY_F6
		key.pressed=true
		lab._unhandled_key_input(key)
		await process_frame
		await process_frame
		view=current_scene
		check(await wait_review(view),"round trip returns to barrel controls")
		check(old_session.worker==null and old_session.status=="closed","structure owner retired before barrel review")
	view.queue_free()
	await process_frame
	print("GCR_LOAD_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"fresh parameter transport and actual room retirement; zero barrel physics steps"}))
	quit(0 if failures.is_empty() else 1)
