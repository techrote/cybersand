extends SceneTree

# Diagnostic only: identify the exact persisted GEN-007 identity that fails
# between a saving Godot process and this fresh process.
const Store = preload("res://scripts/workbench_generated_map.gd")
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var label := "explore001-generated-acceptance"
	var saved: Dictionary = Store.read_named(label)
	print("EXPLORE_REOPEN_PROBE_SOURCE",JSON.stringify({
		"generated":saved.get("generated",false),
		"error":saved.get("error",""),
		"generation":saved.get("generation",{}).keys(),
		"recipe_sha":saved.get("generation",{}).get("recipe_sha256",""),
		"source_sha":saved.get("generation",{}).get("sha256",""),
		"generator_fingerprint":saved.get("generation",{}).get("generator_fingerprint",""),
		"plane_revision":saved.get("generation",{}).get("plane_revision",""),
		"revision":saved.get("generation",{}).get("generator_revision",-1),
		"receipt_hashes":saved.get("generation",{}).get("receipt_hashes",[])}))
	if not saved.get("generated",false):
		print("EXPLORE_REOPEN_PROBE_ERROR saved manifest absent or rejected")
		quit(1)
		return
	change_scene_to_file("res://feature_launcher.tscn")
	await scene_changed
	current_scene.launch("shared_workbench")
	await scene_changed
	var host: Control = current_scene
	var panel: Control = host.shared_workbench
	if panel == null or panel._generated_dialog == null:
		print("EXPLORE_REOPEN_PROBE_ERROR dialog absent")
		quit(1)
		return
	var until_ms := Time.get_ticks_msec()+25000
	while (panel.applied.is_empty() or not host.pending_microscenario_apply.is_empty()) and Time.get_ticks_msec()<until_ms:
		await process_frame
	if panel.applied.is_empty():
		print("EXPLORE_REOPEN_PROBE_ERROR initial World not mounted ",host.microscenario_error)
		quit(1)
		return
	var dialog: ConfirmationDialog = panel._generated_dialog
	dialog.open_saved(saved.setup,saved.generation)
	until_ms = Time.get_ticks_msec()+55000
	while dialog._phase not in ["ready","idle"] and Time.get_ticks_msec()<until_ms:
		await process_frame
	print("EXPLORE_REOPEN_PROBE_RESULT",JSON.stringify({"phase":dialog._phase,"status":dialog._status.text,
		"generation_revision":dialog._configuration.get("revision",-1),
		"generation_fingerprint":dialog._configuration.get("fingerprint",""),
		"plane_fingerprint":dialog._configuration.get("plane_fingerprint",""),
		"preview_receipts":dialog._receipts,
		"source_seed":dialog._recipe.get("seed",-1),
		"recipe_hash":Store.recipe_hash(dialog._recipe)}))
	host.queue_free()
	await process_frame
	# A deliberate source mismatch is a successful diagnostic reproduction.
	quit(0)
