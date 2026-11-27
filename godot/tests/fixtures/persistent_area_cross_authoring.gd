extends "res://tests/test_persistent_areas_workbench.gd"

## Run write and reopen as separate processes on one fresh, cache-enabled profile.
const Goblin = preload("res://goblin/goblin_adapter.gd")
const Recipes = preload("res://scripts/batch_lab/architecture_intent_recipes.gd")
const StageSession = preload("res://scripts/batch_lab/architecture_stage_session.gd")

const REGION := Rect2i(320, 8, 96, 96)
const MARKER := Vector2i(42, 33)
const ART_RECT := Rect2i(MARKER, Vector2i(15, 12))
const PALETTE := [0, 28, 58]


func layout_checks() -> void:
	# The donor verifies layout. These phases verify native state and owned transitions.
	pass


func screenshot(_name: String) -> void:
	pass


func capture() -> PackedByteArray:
	var read: Dictionary = await bench.capture_batch_source(REGION)
	check(read.get("ok", false), "Read Architecture region through the native Workbench")
	return read.get("config", {}).get("source_cells", PackedByteArray())


func digest(value: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()


func held_controls() -> void:
	var goblin := Goblin.new()
	root.add_child(goblin)
	var mount: Dictionary = await goblin.mount()
	check(not mount.ok and not goblin.mounted and goblin.host == null,
		"Resident profile refuses Goblin's separate mount before another World is created")
	goblin.queue_free()
	var place := {"id": "actor_place", "args": {"model": "runner", "x": 100, "y": 80}}
	var control := {"id": "actor_control", "args": {"actor_id": 1, "producer": "scripted", "enabled": true}}
	check(Goblin.validate_action(place).ok and Goblin.validate_action(control).ok,
		"Goblin accepts the typed placement and control payloads")
	check(not bench.place(place.args.model, Vector2(place.args.x, place.args.y)),
		"Resident transition refuses Goblin's Workbench placement entry point")
	check(not bench.set_actor_control(control.args.actor_id, {"source": control.args.producer, "enabled": control.args.enabled}),
		"Resident transition refuses Goblin's Workbench control entry point")
	check(bench.pilot_id() <= 0 and bench.applied.actors.is_empty()
		and (host.physical_actor_session == null or host.physical_actor_session.bodies().is_empty()),
		"Refusals leave no pilot, authored actor or Rapier actor body")


func exercise_write() -> void:
	var worker_identity: int = worker.get_instance_id()
	var generation: int = worker.paint_state().generation
	var revision: int = controller.manifest.revision
	var baseline := await capture()
	var material := 58 if await native_cell(MARKER) != 58 else 28
	var art: Window = bench._ensure_art_batches()
	var receipts: Array = []
	art.executor.native_receipt.connect(func(receipt: Dictionary) -> void: receipts.append(receipt.duplicate(true)))
	var rectangle := [{"shape": "rectangle", "x0": MARKER.x, "y0": MARKER.y,
		"x1": ART_RECT.end.x - 1, "y1": ART_RECT.end.y - 1, "material": material}]
	var offer: Dictionary = art.executor.submit(rectangle, ART_RECT, [], PALETTE)
	if not check(offer.status == "queued" and art.executor.active and art.native_authoring_pending(),
		"Existing Art executor takes a native write lease"):
		return
	check(not controller.request_travel("b") and not controller.busy and controller.active_area == "a",
		"Travel refuses while Art owns an active transaction")
	check(not controller.request_save() and controller.manifest.revision == revision,
		"No partial Art operation reaches the durable frontier")
	if not await until(func() -> bool: return not art.executor.active, "Art transaction finishes"):
		return
	var art_changed: int = art.executor.result.changed
	var art_receipt_count: int = receipts.size()
	check(art.executor.result.status == "completed" and art_receipt_count == 1
		and receipts[0].backend == "CyberNativeCellWorld" and art_changed == ART_RECT.get_area(),
		"One native Art receipt accounts for every changed rectangle cell")
	check(await native_cell(MARKER) == material, "Native readback returns the Art marker")

	bench.open_architecture_lab()
	var panel: Window = bench.architecture_lab
	var flow: Node = panel.workflow
	var built: Dictionary = Recipes.build("cross-area-hall", "industrial_hangar", 0, REGION, 431, [58, 28])
	if not check(built.ok and flow.load_campaign(built.campaign).ok and flow.select(0).ok,
		"Architecture accepts a deterministic authored campaign"):
		return
	var preview: Dictionary = await flow.preview_selected()
	if not check(preview.ok, "Fresh native Architecture preview / " + str(preview.get("reason", ""))):
		return
	var projection: PackedByteArray = panel.session.preview.projected_cells.duplicate()
	check((await capture()) == baseline and projection != baseline,
		"Preview leaves the native plane unchanged and proposes different cells")
	var approval: Dictionary = await flow.approve()
	if not check(approval.ok and approval.queued and not approval.completed and flow.busy(),
		"Explicit approval starts an asynchronous Architecture stage"):
		return
	check(not controller.request_save() and not controller.busy and controller.manifest.revision == revision,
		"Save refuses during an approved Architecture write")
	check(not controller.request_travel("c") and controller.active_area == "a",
		"Resident handoff refuses during an approved Architecture write")
	if not await until(func() -> bool: return not flow.busy(), "Architecture native owner finishes"):
		return
	var record: Dictionary = panel.session.records.back()
	check(panel.session.stage_state() == "completed"
		and StageSession.receipt_accounting(record.native_receipts, record.budget).complete,
		"Native receipts account for every approved Architecture operation")
	check((await capture()) == projection and int(worker.paint_state().generation) == generation
		and worker.get_instance_id() == worker_identity,
		"Art and Architecture share the same native World and worker")
	panel.hide()

	if not await save_current("Durable edit frontier"):
		return
	check(int(controller.manifest.revision) > revision, "Acknowledgment advances the durable manifest")
	if not check(controller.request_travel("b") and controller.busy, "RAMCACHE takes authority for B"):
		return
	var blocked: Dictionary = art.executor.submit(rectangle, ART_RECT, [], PALETTE)
	check(blocked.status == "refused" and not art.executor.active, "Resident lease refuses a fresh Art writer")
	await held_controls()
	if not await operation_finished("Resident B handoff"):
		return
	check(controller.active_area == "b" and worker.get_instance_id() == worker_identity,
		"B activation retains the owner SimulationWorker")
	if not await travel("c") or not await travel("a"):
		return
	check(worker.get_instance_id() == worker_identity and (await capture()) == projection
		and await native_cell(MARKER) == material, "A-B-C-A retains both sets of authored native cells")
	write_json(output.path_join("cross-authoring.json"), {
		"process_id": OS.get_process_id(), "art_receipt_count": art_receipt_count, "art_changed": art_changed,
		"architecture_receipts": record.native_receipts.size(), "marker": material,
		"projected_sha256": digest(projection), "durable_revision": controller.manifest.revision,
		"session_id": controller.manifest.session_id})


func exercise_reopen() -> void:
	var original = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("cross-authoring.json")))
	if not check(original is Dictionary and original.has_all(["process_id", "session_id", "projected_sha256",
		"marker", "durable_revision"]), "A completed writer receipt is required"):
		return
	check(int(original.process_id) != OS.get_process_id() and controller.active_area == "a"
		and controller.manifest.session_id == original.session_id,
		"A fresh OS process reopens the same durable session and selected Area A")
	var restored := {"process_id": OS.get_process_id(), "session_id": controller.manifest.session_id,
		"area": controller.active_area, "durable_revision": controller.manifest.revision,
		"projected_sha256": digest(await capture()), "marker": await native_cell(MARKER)}
	check(restored.projected_sha256 == original.projected_sha256 and restored.marker == int(original.marker),
		"Reopened native cells match both the entire Architecture projection and the Art marker")
	check(int(restored.durable_revision) >= int(original.durable_revision), "The acknowledged durable revision survives")
	write_json(output.path_join("cross-authoring-reopen.json"), restored)
