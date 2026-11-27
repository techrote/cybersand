extends Node
## Lazy ordinary-Workbench mount. Art owns one provider/configuration/audit;
## Architecture owns typed proposals, native previews, approvals and history.
## Preparing a disclosure never binds transport or sends a model request.
signal changed(message: String)
const Transport = preload("res://scripts/art_proposal_transport.gd")
const Bridge = preload("res://scripts/batch_lab/architecture_proposal_bridge.gd")
const Capabilities = preload("res://scripts/art_provider_capabilities.gd")
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
var architecture: Window
var art: Window
var workflow: Node
var session: Node
var transport := Transport.new()
var bridge := Bridge.new()
var message := "Prepare a request, review its disclosed context, then explicitly Send."
var _preparing := false
var _generation := 0
var _pending: Dictionary = {}
var _configuration: Dictionary = {}
var _intent: Dictionary = {}
var _fence: Dictionary = {}
var _disclosure_digest := ""
var _approved_serial := -1
var _provider_identity := 0
var _retiring := false

func _ready() -> void:
	set_process(false)

func bind(owner: Window) -> void:
	architecture = owner
	workflow = owner.workflow
	session = owner.session
	workflow.proposal_transport_requested.connect(_capture_request)
	bridge.outcome.connect(_bridge_outcome)

func _answer(ok: bool, reason: String) -> Dictionary:
	message = reason
	changed.emit(reason)
	return {"ok":ok,"reason":reason,"zero_writes":true}

func _same_owners() -> bool:
	return is_instance_valid(architecture) and architecture.is_inside_tree() and not architecture.is_queued_for_deletion() \
		and is_instance_valid(art) and art.is_inside_tree() and not art.is_queued_for_deletion() \
		and is_instance_valid(art.provider) and art.provider.get_instance_id() == _provider_identity \
		and is_instance_valid(workflow) and architecture.workflow == workflow \
		and is_instance_valid(session) and architecture.session == session and workflow.session == session \
		and is_instance_valid(architecture.wb) and architecture.wb.art_batches == art \
		and is_instance_valid(architecture.wb.host)

func _context_current() -> bool:
	if not _same_owners() or _pending.is_empty() or _fence.is_empty(): return false
	if not bool(architecture.wb.host.paused) or architecture.wb.busy() or session.busy(): return false
	if architecture.workflow_panel.intent_snapshot() != _intent: return false
	if art.proposal_configuration_identity() != _configuration: return false
	if session._observation_fence() != _fence or workflow._planning_fence != _fence: return false
	var planning: Dictionary = workflow.planning.summary()
	return planning.get("state") == "awaiting-proposal" and planning.get("request_id") == _pending.get("request_id")

func prepare() -> Dictionary:
	if _preparing or transport.summary().active or workflow.busy():
		return _answer(false,"Finish or Stop the current Architecture action first.")
	# This is reached only from the explicit proposal action, never on panel open.
	art = architecture.wb._ensure_art_batches()
	_provider_identity = art.provider.get_instance_id()
	var blocked: String = art.proposal_transport_block_reason()
	if not blocked.is_empty(): return _answer(false,blocked)
	cancel("Earlier unsent proposal retired.")
	_intent = architecture.workflow_panel.intent_snapshot().duplicate(true)
	_configuration = art.proposal_configuration_identity().duplicate(true)
	_preparing = true
	var generation := _generation
	var answer: Dictionary = await workflow.propose_intent(_intent,Compiler.rect(_intent.region),
		{"mode":"proposal_transport","max_alternatives":3,"materials":[58,28]})
	if generation != _generation: return _answer(false,"Proposal preparation was cancelled.")
	_preparing = false
	if not answer.get("ok",false) or _pending.is_empty():
		return _answer(false,str(answer.get("reason","Choose an architectural family before preparing a provider request.")))
	if not _context_current() or not art.proposal_transport_block_reason().is_empty():
		cancel("The World, intent or Art settings changed. Prepare a fresh request.")
		return _answer(false,message)
	_disclosure_digest = Compiler.digest(Compiler.canonical({"request":_pending,"configuration":_configuration,
		"fence":_fence,"generation":_generation}).to_utf8_buffer())
	set_process(true)
	return _answer(true,"Review the exact request and Art destination. No network request has been sent.")

func _capture_request(request: Dictionary) -> void:
	if not _preparing: return
	var budget := {"bytes":Transport.MAX_REQUEST_BYTES,"items":16384}
	if not Transport.Provider.bounded_json_values(request,budget):
		workflow.cancel()
		return
	_pending = request.duplicate(true)
	_fence = session._observation_fence().duplicate(true)

func disclosure() -> Dictionary:
	if _pending.is_empty() or _disclosure_digest.is_empty(): return {}
	# No credential, prior Art conversation, image, complete material plane or
	# mutable native object enters this disclosure or the transport context.
	return {"digest":_disclosure_digest,"provider":_configuration.provider,
		"endpoint":art.provider.redact(str(_configuration.endpoint)),"model":art.provider.redact(str(_configuration.model)),
		"endpoint_category":Capabilities.endpoint_category(str(_configuration.endpoint)),
		"tokens":_configuration.tokens,"seconds":_configuration.seconds,
		"instructions":Transport.INSTRUCTIONS,
		"request_text":art.provider.redact(JSON.stringify(_pending,"  ")),
		"scope":"Intent, inspected material counts/source identity and bounded architectural references only. Known credentials are redacted in this display. No image or earlier Art conversation is included."}

func send_disclosed(digest: String) -> Dictionary:
	if _preparing or digest.is_empty() or digest != _disclosure_digest or not _context_current():
		cancel("The disclosed request is stale. Prepare and review a fresh request.")
		return _answer(false,message)
	var blocked: String = art.proposal_transport_block_reason()
	if not blocked.is_empty(): return _answer(false,blocked)
	_approved_serial = int(art.provider.serial)+1
	var admitted: Dictionary = transport.bind_owner(art.provider,_configuration_snapshot,_live_guard)
	if not admitted.ok: return _answer(false,str(admitted.reason))
	admitted = bridge.bind_owner_seam(workflow,transport.dispatch,transport.cancel,_live_guard)
	if not admitted.ok:
		transport.detach_owner()
		return _answer(false,str(admitted.reason))
	# The pending request was emitted with no transport bound. Only this explicit
	# action may dispatch it; Bridge checks the same current identity and guards.
	admitted = bridge.dispatch_pending_request(_pending)
	return _answer(bool(admitted.ok),str(admitted.reason))

func _configuration_snapshot() -> Dictionary:
	return art.proposal_configuration_snapshot() if _context_current() else {}

func _live_guard(request: Dictionary) -> bool:
	return _approved_serial > 0 and _context_current() and int(art.provider.serial) == _approved_serial \
		and request == _pending

func _bridge_outcome(record: Dictionary) -> void:
	if _retiring or record.get("request_id") != _pending.get("request_id"): return
	if record.get("status") in ["dispatching","awaiting-response"]:
		_answer(true,str(record.reason))
		return
	if not bridge.summary().active:
		_pending = {}; _approved_serial = -1; _disclosure_digest = ""
		set_process(false)
	_answer(record.get("status") == "proposed",str(record.get("reason","Proposal request retired.")))

func cancel(reason: String = "Architecture proposal cancelled") -> void:
	if _retiring: return
	_retiring = true
	_generation += 1
	var had_pending := _preparing or not _pending.is_empty()
	_preparing = false
	_pending = {}; _approved_serial = -1; _disclosure_digest = ""
	bridge.detach_owner_seam()
	transport.detach_owner()
	if had_pending and is_instance_valid(workflow): workflow.cancel()
	set_process(false)
	_retiring = false
	_answer(false,reason)

func _process(_delta: float) -> void:
	if not _pending.is_empty() and not _context_current():
		cancel("The World, intent or Art settings changed. The proposal request was retired.")

func _exit_tree() -> void:
	cancel("Architecture owner closed")
	if is_instance_valid(workflow) and workflow.proposal_transport_requested.is_connected(_capture_request):
		workflow.proposal_transport_requested.disconnect(_capture_request)
