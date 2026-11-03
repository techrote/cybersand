extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
const Lab = preload("res://scripts/solid_detachment_lab.gd")
const Review = preload("res://scripts/gcr_load_review.gd")
var checks: int = 0
var failures: Array[String] = []
func check(value: bool, why: String) -> void:
	checks+=1
	if not value:
		failures.append(why)
		printerr("FAIL REST CONTROLS ",why)
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for parameters: Dictionary in [{"mass_multiplier":64.01},{"inertia_multiplier":64.01},{"friction":4.01}]:
		var invalid = Session.new()
		check(not await invalid.open(root,1,"empty",true,"LA",parameters),"over-limit parameter refuses")
		check(invalid.worker==null,"refusal creates no native owner")
	for options: Dictionary in [{"mode":"invalid","budget":20},{"mode":"P","budget":4.99},{"mode":"C","budget":80.01},{"mode":"R","budget":NAN}]:
		var invalid = Session.new()
		check(not await invalid.open(root,1,"empty",true,"LA",{},options),"invalid experimental option refuses")
		check(invalid.worker==null,"option refusal creates no owner")
	var session = Session.new()
	check(await session.open(root,1,"packed_sand",true,"LA",{"mass_multiplier":64.0,"inertia_multiplier":64.0},{"mode":"control","budget":20}),"64 payload multipliers construct")
	if session.worker!=null:
		check(await session.cut_and_release(),"64 multipliers pass actual native geometry/physical-state handoff")
		if session.active:
			session.set_paused(true)
			check(is_equal_approx(session.body.mass,33280.0),"actual physical mass33280")
			check(absf(session.body.inertia-109907693.0/1560.0*64.0)<1.0,"actual physical inertia scaled64")
			check(int(session.source_receipt.member_count)==520 and float(session.source_receipt.mass)==520.0,"native payload properties remain520")
		session.close()
	var lab := Lab.new()
	lab.workers=1
	root.add_child(lab)
	var deadline: int = Time.get_ticks_msec()+15000
	while lab.busy and Time.get_ticks_msec()<deadline: await process_frame
	check(not lab.busy and lab.session.worker!=null,"structure UI ready")
	check(lab._parameter_inputs.mass_multiplier.max_value==64.0 and lab._parameter_inputs.inertia_multiplier.max_value==64.0,"structure multiplier limits64")
	check(lab._parameter_inputs.friction.max_value==4.0,"structure friction limit preserved")
	check(lab._budget_input.min_value==5.0 and lab._budget_input.max_value==80.0,"budget range5to80")
	check(lab._rest_mode_input.item_count==5,"five rest modes exposed")
	lab.queue_free()
	await process_frame
	var review := Review.new()
	root.add_child(review)
	deadline=Time.get_ticks_msec()+15000
	while (review.fixture==null or review.resetting) and Time.get_ticks_msec()<deadline: await process_frame
	check(review.fixture!=null and not review.resetting,"barrel UI ready")
	check(review.parameters.inertia_multiplier.max_value==64.0,"barrel inertia factor64")
	check(review.parameters.mass.max_value==32.0 and review.parameters.friction.max_value==4.0,"absolute barrel mass and friction limits retained")
	check(review.rest_mode_input.item_count==5 and review.budget_input.value==20.0,"barrel rest modes/control budget")
	check(review.paused and review.fixture.tick==0,"no barrel efficacy trajectory during UI gate")
	review.queue_free()
	await process_frame
	print("GCR_REST_CONTROLS ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"scope":"parameter bounds/native handoff/UI controls; no candidate efficacy trajectory"}))
	quit(0 if failures.is_empty() else 1)
