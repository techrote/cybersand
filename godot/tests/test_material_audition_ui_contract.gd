extends SceneTree

# Adversarial view/state-machine qualification with an explicit fake owner.
# This does not claim native activation or native material behavior evidence.
const PanelScript = preload("res://scripts/material_lab_audition_panel.gd")
const Profiles = preload("res://scripts/material_audition_profile.gd")
const Fixtures = preload("res://tests/test_material_audition_profile.gd")
var checks := 0
var failures := 0

class Owner extends RefCounted:
	var state := Fixtures.fixture_state()
	var submitted: Dictionary = {}
	var completion: Dictionary = {}
	var requests := 0
	var request_id := ""
	func material_audition_state() -> Dictionary: return state.duplicate(true)
	func request_material_audition(request: Dictionary) -> Dictionary:
		requests += 1
		submitted = request.duplicate(true)
		request_id = "request-%d" % requests
		return {"ok":true,"status":"pending","request_id":request_id}
	func poll_material_audition(_request: String) -> Dictionary:
		return completion.duplicate(true) if not completion.is_empty() else {"ok":true,"status":"pending","request_id":request_id}
	func cancel_material_audition(_request: String) -> Dictionary:
		completion = {"ok":false,"status":"cancelled","error":"Cancelled before admission","request_id":request_id}
		return completion.duplicate(true)
	func activate() -> Dictionary:
		state.revision += 1
		state.profile = submitted.profile.duplicate(true)
		for row: Dictionary in state.capabilities:
			if row.change_class == "live": row.effective = Profiles.value_for(state.profile,row)
		completion = {"ok":true,"status":"active","request_id":request_id,"session_id":state.session_id,"world_id":state.world_id,"revision":state.revision,"state":state.duplicate(true)}
		return completion.duplicate(true)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAT_AUDITION_UI_CONTRACT: " + message)

func _initialize() -> void:
	run.call_deferred()

func late_receipts() -> void:
	for change: String in ["world","session","revision","unavailable"]:
		for refreshed: bool in [false,true]:
			var context := "%s / explicit refresh=%s" % [change,refreshed]
			var panel := PanelScript.new()
			root.add_child(panel)
			panel.set_process(false)
			var owner := Owner.new()
			panel.bind_current_scene(owner)
			panel.select_material(2)
			panel._controls["material:2:density"].value = 400
			panel.apply_draft()
			panel._complete(owner.activate())
			owner.completion.clear()
			panel._controls["material:2:density"].value = 500
			panel.apply_draft()
			var receipt := owner.activate()
			panel._controls["material:2:density"].value = 700
			var draft_binding: Dictionary = panel._draft_binding.duplicate(true)
			if change == "unavailable":
				owner.state = {"ok":false,"status":"unavailable","error":"The native owner retired after activation."}
			else:
				owner.state.profile = Profiles.defaults("later-authority")
				if change == "world": owner.state.world_id = "replacement-world"
				elif change == "session": owner.state.session_id = "replacement-session"
				else: owner.state.profile.materials = [{"material_id":2,"density":900}]
				owner.state.revision = int(owner.state.revision)+1 if change == "revision" else 0
				for row: Dictionary in owner.state.capabilities:
					if row.change_class == "live": row.effective = Profiles.value_for(owner.state.profile,row)
			var current: Dictionary = owner.state.duplicate(true)
			if refreshed: panel.refresh_scene()
			panel._complete(receipt)
			expect(panel.active_state==current,"late activation cannot overwrite current owner authority: " + context)
			expect(panel.last_receipt==receipt and panel._pending.is_empty(),"valid older receipt remains historical activation evidence: " + context)
			expect(panel._previous_profile.is_empty() and panel._buttons.revert.disabled,"late receipt cannot resurrect old Revert history: " + context)
			expect(int(panel.draft_profile.materials[0].density)==700 and panel._draft_binding==draft_binding,"genuine newer draft and its unreconciled binding survive: " + context)
			expect(panel._status.text.contains("Earlier activation acknowledged") and not panel._status.text.contains("refused"),"committed older transaction is not reported as refused: " + context)
			expect(owner.requests==2 and panel._buttons.apply.disabled,"later authority requires deliberate reconciliation, never automatic reapplication: " + context)
			panel.queue_free()
			await process_frame

func restored_controls() -> void:
	for action: String in ["revert","reset"]:
		var panel := PanelScript.new()
		root.add_child(panel)
		panel.set_process(false)
		var owner := Owner.new()
		panel.bind_current_scene(owner)
		panel.select_material(2)
		for density: int in [500,700]:
			panel._controls["material:2:density"].value = density
			panel.apply_draft()
			panel._complete(owner.activate())
			owner.completion.clear()
		if action == "revert": panel.revert_configuration()
		else: panel.reset_configuration()
		var restored: Dictionary = owner.submitted.profile.duplicate(true)
		panel._complete(owner.activate())
		var row: Dictionary = panel._capabilities["material:2:density"]
		var value: int = Profiles.value_for(restored,row)
		expect(panel.active_state.profile==restored and panel.draft_profile==restored,"acknowledged restoration becomes both active and draft: " + action)
		expect(int(panel._controls["material:2:density"].value)==value,"restoration updates the numeric control alongside the draft: " + action)
		expect(panel._controls["material:2:density"].get_line_edit().text==str(value),"restored draft is what the owner sees in the field: " + action)
		owner.completion.clear()
		panel.apply_draft()
		expect(owner.submitted.profile==restored,"next unchanged Apply cannot resurrect the pre-restoration value: " + action)
		panel._complete(owner.activate())
		expect(panel.active_state.profile==restored and panel.draft_profile==restored,"unchanged repeat preserves the restored profile: " + action)
		panel.queue_free()
		await process_frame

func failed_readback_correlation() -> void:
	for change: String in ["later_same_profile","receipt_revision","receipt_world","receipt_session"]:
		var panel := PanelScript.new()
		root.add_child(panel)
		panel.set_process(false)
		var owner := Owner.new()
		panel.bind_current_scene(owner)
		panel.select_material(2)
		panel._controls["material:2:density"].value = 400
		panel.apply_draft()
		panel._complete(owner.activate())
		owner.completion.clear()
		panel._controls["material:2:density"].value = 500
		panel.apply_draft()
		owner.activate()
		var receipt := {"ok":false,"accepted":true,"status":"active_readback_failed","request_id":owner.request_id,"session_id":owner.state.session_id,"world_id":owner.state.world_id,"revision":owner.state.revision,"error":"Receipt readback failed after commit"}
		panel._controls["material:2:density"].value = 700
		var draft_binding: Dictionary = panel._draft_binding.duplicate(true)
		if change == "later_same_profile": owner.state.revision += 1
		elif change == "receipt_revision": receipt.revision += 1
		elif change == "receipt_world": receipt.world_id = "different-world"
		else: receipt.session_id = "different-session"
		panel._complete(receipt)
		expect(panel.active_state==owner.state,"failed receipt retains the current owner readback: " + change)
		expect(panel.last_receipt==receipt and panel._pending.is_empty(),"failed readback retains the activation evidence: " + change)
		expect(panel._previous_profile.is_empty() and panel._buttons.revert.disabled,"an uncorrelated activation cannot acquire old Revert history: " + change)
		expect(int(panel.draft_profile.materials[0].density)==700 and panel._draft_binding==draft_binding,"uncorrelated receipt preserves newer draft and its original binding: " + change)
		expect(not panel._status.text.contains("refused") and not panel._status.text.contains("refreshed native values confirm activation"),"later or conflicting receipt is not described as refused or successfully correlated: " + change)
		expect(owner.requests==2 and panel._buttons.apply.disabled,"failed correlation requires deliberate draft reconciliation: " + change)
		panel.queue_free()
		await process_frame

func run() -> void:
	root.size = Vector2i(1000,650)
	var panel := PanelScript.new()
	root.add_child(panel)
	await process_frame
	expect(panel._buttons.apply.disabled,"standalone Lab cannot imply current-scene activation")
	var owner := Owner.new()
	var initial_state := owner.state.duplicate(true)
	owner.state = {"ok":false,"error":"Waiting for the native owner boundary."}
	panel.bind_current_scene(owner)
	expect(panel._status.text.contains("Waiting"),"initial unavailable readback reports the actual pending owner state")
	owner.state = initial_state
	panel.refresh_scene()
	expect(panel._status.text.contains("readback is ready") and not panel._status.text.contains("Waiting"),"first native readback replaces initial waiting feedback")
	panel.select_material(2)
	await process_frame
	expect(not panel._buttons.apply.disabled,"bound current-scene owner admits an explicit application control")
	var density_key := "material:2:density"
	expect(panel._controls.has(density_key),"capability-driven density control is present")
	panel._controls[density_key].value = 500
	expect(owner.requests==0,"changing a numeric control never submits intermediate native transactions")
	var result: Dictionary = panel.apply_draft()
	expect(result.get("status")=="pending" and owner.requests==1,"one deliberate Apply queues one complete profile")
	expect(owner.submitted.session_id=="fixture-session" and owner.submitted.world_id=="123" and owner.submitted.expected_revision==0,"request captures host, World and prior revision")
	expect(panel.active_state.profile.materials.is_empty(),"pending draft is not advertised as native-active")
	panel._controls[density_key].value = 700
	panel._complete(owner.activate())
	expect(int(panel.active_state.profile.materials[0].density)==500,"native acknowledgement owns active value")
	expect(int(panel.draft_profile.materials[0].density)==700,"newer edits survive a late successful receipt")
	expect(panel._draft_binding.expected_revision==1,"new draft is bound to acknowledged configuration revision")
	expect(not panel._buttons.revert.disabled,"accepted previous configuration can be restored separately")
	owner.completion.clear()
	panel.revert_configuration()
	expect(owner.submitted.profile.materials.is_empty(),"Revert requests the prior configuration, without a cell mutation command")
	panel._complete(owner.activate())
	expect(panel.active_state.profile.materials.is_empty(),"reversion updates active configuration readback")
	owner.completion.clear()
	var typed_field: SpinBox = panel._controls[density_key]
	typed_field.get_line_edit().text = "360"
	typed_field.get_line_edit().text_changed.emit("360")
	panel.apply_draft()
	var submitted_draft_revision: int = panel._draft_revision
	var submitted_profile: Dictionary = owner.submitted.profile.duplicate(true)
	expect(int(typed_field.value)==360,"typed Apply reconciles the numeric control before an asynchronous receipt")
	# Godot can emit the numeric focus-loss signal after the Apply button has
	# already committed the same typed value. Reproduce that desktop ordering.
	typed_field.value_changed.emit(360.0)
	expect(panel._draft_revision==submitted_draft_revision and panel.draft_profile==submitted_profile,"late focus commit of the submitted value is not a newer draft")
	expect(panel._status.text.contains("Applying at the native owner boundary"),"late duplicate control notification cannot erase pending admission feedback")
	panel._complete(owner.activate())
	expect(panel._status.text.contains("activated") and not panel._status.text.contains("newer draft"),"ordinary typed Apply reports activation without a false unapplied draft")
	owner.completion.clear()
	panel._controls[density_key].get_line_edit().text = "-1"
	panel._controls[density_key].get_line_edit().text_changed.emit("-1")
	var prior_requests := owner.requests
	expect(not panel.apply_draft().get("ok",true) and owner.requests==prior_requests,"out-of-range typed input refuses before native submission")
	expect(not panel.select_material(24) and panel.selected_id==2,"invalid current-scene input explicitly refuses a material selection change")
	panel.use_active_as_draft()
	panel._controls[density_key].value = 400
	owner.completion.clear()
	panel.apply_draft()
	var before_cancel := panel.active_state.duplicate(true)
	panel.cancel_pending()
	expect(panel._pending.is_empty() and panel.active_state==before_cancel,"acknowledged cancellation leaves active configuration unchanged")
	owner.completion.clear()
	owner.state.ok = false
	owner.state.error = "Waiting for native readback recovery."
	panel.refresh_scene()
	owner.state.ok = true
	owner.state.erase("error")
	panel.refresh_scene()
	expect(panel._status.text.contains("readback restored") and int(panel.draft_profile.materials[0].density)==400,"same-World recovery clears waiting feedback and preserves the unsubmitted draft")
	owner.state.revision += 1
	panel.refresh_scene()
	expect(panel._buttons.apply.disabled and not panel._buttons.rebase.disabled,"an external revision makes the old draft visibly stale")
	prior_requests = owner.requests
	panel.apply_draft()
	expect(owner.requests==prior_requests,"stale UI intent cannot be silently rebased by Apply")
	panel.rebase_draft()
	expect(not panel._buttons.apply.disabled,"explicit Keep draft captures the newer revision")
	panel.apply_draft()
	var unrelated := owner.activate()
	unrelated.request_id = "unrelated"
	panel._complete(unrelated)
	expect(not panel._pending.is_empty(),"unrelated asynchronous receipt cannot complete this request")
	panel._complete(owner.completion)
	expect(panel._pending.is_empty(),"matching terminal receipt completes the request")
	owner.completion.clear()
	panel._controls[density_key].value = 650
	panel.apply_draft()
	owner.activate()
	panel._complete({"ok":false,"accepted":true,"status":"active_readback_failed","request_id":owner.request_id,"error":"Receipt allocation failed after commit"})
	expect(panel._pending.is_empty() and int(panel.active_state.profile.materials[0].density)==650,"post-commit receipt failure recovers actual active values through authoritative refresh")
	expect(panel._status.text.contains("activated") and panel._status.text.contains("initial readback failed") and not panel._status.text.contains("refused"),"post-commit readback failure never reports a refused activation")
	expect(panel._draft_binding.expected_revision==owner.state.revision and not panel._buttons.revert.disabled,"recovered activation restores revision binding and previous configuration")
	owner.completion.clear()
	panel._controls[density_key].value = 750
	panel.apply_draft()
	# The owner declares a commit, but its first readback is the old cached state.
	panel._complete({"ok":false,"status":"active_readback_failed","request_id":owner.request_id,"error":"Effective state unavailable after commit"})
	expect(panel._pending.is_empty() and not panel.active_state.get("ok",false) and panel._buttons.apply.disabled,"unrecovered post-commit readback does not publish stale effective values or enable another Apply")
	expect(panel._status.text.contains("activated") and not panel._status.text.contains("refused"),"status-only post-commit receipt preserves truthful activation feedback")
	owner.activate()
	panel.refresh_scene()
	expect(panel.active_state.profile.materials[0].density==750 and panel._buttons.apply.disabled,"later native recovery shows actual values while retaining explicit stale-draft rebase")
	owner.completion.clear()
	panel.use_active_as_draft()
	panel._controls[density_key].value = 850
	panel.apply_draft()
	owner.activate()
	panel._complete({"ok":false,"status":"unavailable","code":"unknown_request","request_id":owner.request_id,"error":"Expired receipt"})
	expect(panel.active_state.profile.materials[0].density==850 and panel._previous_profile.is_empty(),"expired transaction receipt refreshes actual active values and retires uncorrelated revert history")
	expect(panel._status.text.contains("outcome unavailable") and not panel._status.text.contains("refused"),"unknown outcome never claims refusal of an already committed configuration")
	owner.completion.clear()
	owner.state.world_id = "replacement-world"
	owner.state.revision = 0
	owner.state.profile = Profiles.defaults()
	panel.refresh_scene()
	expect(panel._buttons.apply.disabled and panel._previous_profile.is_empty(),"World replacement retires the prior configuration history and old binding")
	panel.use_active_as_draft()
	expect(panel._draft_binding.world_id=="replacement-world" and panel.draft_profile.materials.is_empty(),"explicit adoption binds to replacement World defaults")
	panel.select_material(3)
	expect(not panel._controls.has("material:3:viscosity"),"unsupported Water viscosity is visible without an actionable live slider")
	expect(panel._controls.has("reaction:5:probability_threshold"),"admitted selected-material pair exposes its actual inclusive threshold")
	panel._controls["reaction:5:probability_threshold"].value = 0
	panel._name.text = "Slow contact"
	var path := "user://mat-audition-ui-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	expect(panel.save_profile(path).get("ok",false),"mounted profile action writes a named draft")
	panel.use_active_as_draft()
	prior_requests = owner.requests
	expect(panel.load_profile(path).get("ok",false) and owner.requests==prior_requests,"loading a named profile prepares a draft without activation")
	expect(panel.draft_profile.reactions==[{"slot":5,"probability_threshold":0}],"profile load restores exact admitted reaction values")
	DirAccess.remove_absolute(path)
	panel.apply_draft()
	owner = null
	panel._process(1.0)
	expect(panel._pending.is_empty() and not panel.active_state.get("ok",false),"destroyed host terminates pending UI state without claiming cancellation or activation")
	expect(panel._status.text.contains("outcome unavailable") and not panel._status.text.contains("refused"),"host retirement reports the unobserved outcome rather than inventing a pre-commit refusal")
	panel.queue_free()
	await process_frame
	await late_receipts()
	await restored_controls()
	await failed_readback_correlation()
	print("MAT_AUDITION_UI_CONTRACT: %d checks, %d failures; fake-owner state machine only" % [checks,failures])
	quit(1 if failures else 0)
