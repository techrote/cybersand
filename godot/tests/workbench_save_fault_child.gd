extends SceneTree

# A disposable-profile child of run_workbench_save_qualification.py. Ordinary,
# generated and project modes call the real public writers without injected I/O.
# The helper mode can pause at a real file boundary so the parent establishes an
# OS lock/permission change or terminates the process before native replacement.
const Setup = preload("res://scripts/workbench_setup.gd")
const Generated = preload("res://scripts/workbench_generated_map.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
const Project = preload("res://scripts/architectural_generator_project.gd")
const Architecture = preload("res://scripts/architectural_generator_dialog.gd")
const Transaction = preload("res://scripts/workbench_file_transaction.gd")

class PausedIO extends Transaction.FileOperations:
	func replace(bridge: Object, source: String, target: String) -> Dictionary:
		print("SAVE_COMMIT_READY ", JSON.stringify({"staging":source, "target":target}))
		var gate := OS.get_environment("CYBERSAND_SAVE_GATE")
		var deadline := Time.get_ticks_msec() + 30000
		while not FileAccess.file_exists(gate) and Time.get_ticks_msec() < deadline:
			OS.delay_msec(5)
		if not FileAccess.file_exists(gate): return {"ok":false, "error":"Test parent did not release the commit gate."}
		return super.replace(bridge, source, target)

func _initialize() -> void:
	run.call_deferred()

func generated_packet() -> Dictionary:
	var recipe := {"schema":1, "seed":543, "chunk_size":64, "candidate":"strata",
		"parameters":{"surface_y":180, "relief":0, "cave_threshold":1, "detail":0},
		"themes":{"weights":{"basalt":1}}}
	var generator: Object = ClassDB.instantiate(&"CyberWorldGenerator")
	var configured: Dictionary = generator.configure(recipe)
	if not configured.get("ok", false): return {"error":"Fixture native recipe refused."}
	var cells := PackedByteArray()
	cells.resize(512 * 512)
	var receipts := []
	for cy: int in 8:
		for cx: int in 8:
			var chunk: Dictionary = generator.generate_chunk(Vector2i(cx,cy))
			if not chunk.get("ok",false) or chunk.get("state","") != "ready":
				return {"error":"Fixture native generation failed."}
			for y: int in 64:
				for x: int in 64: cells[(cy*64+y)*512+cx*64+x] = chunk.cells[y*64+x]
			receipts.append(str(chunk.receipt_hash))
	return {"recipe":recipe, "origin":Vector2i.ZERO, "extent":Vector2i(512,512),
		"cells":cells, "sha256":Generated.digest(cells), "recipe_sha256":Generated.recipe_hash(recipe),
		"generator_fingerprint":str(configured.fingerprint), "plane_revision":"",
		"generator_revision":int(configured.revision), "receipt_hashes":receipts}

func run() -> void:
	var kind := OS.get_environment("CYBERSAND_SAVE_KIND")
	var phase := OS.get_environment("CYBERSAND_SAVE_PHASE")
	var label := "ultima-save-" + kind
	var path: String = Setup._path(label)
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var setup: Dictionary = Setup.fresh(bridge.default_liquid_policy(), Vector2i(512,512))
	setup.material = 2 if phase == "prepare" else 14
	var prior := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	var error := ""
	var dialog: ConfirmationDialog
	var readback := {}
	var result := {"kind":kind, "phase":phase, "pid":OS.get_process_id(),
		"path":ProjectSettings.globalize_path(path), "prior_sha256":prior}
	if phase != "verify":
		match kind:
			"ordinary":
				error = Setup.write_named(label, setup)
			"generated":
				var packet := generated_packet()
				error = str(packet.error) if packet.has("error") else Generated.write_named(label, setup, packet)
			"project":
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Setup.DIRECTORY))
				dialog = Architecture.new()
				root.add_child(dialog)
				dialog.mount()
				var project := Project.default_project()
				project.seed = 123 if phase == "prepare" else 456
				if not dialog.set_project(project): error = "Fixture project refused."
				elif not dialog.save_project(path): error = dialog._status.text
			"material-baseline":
				var cells := PackedByteArray()
				cells.resize(512*512*2)
				cells.encode_u16(0, 58 if phase == "prepare" else 131)
				var staged: Dictionary = Baseline.stage({"ok":true, "schema":1,
					"extent":Vector2i(512,512), "cells":cells, "sha256":Generated.digest(cells)}, Vector2i(512,512))
				error = str(staged.error) if staged.has("error") else Baseline.write_named(label, setup, staged.baseline)
			"helper":
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Setup.DIRECTORY))
				var payload := JSON.stringify({"format":"transaction-fixture", "value":OS.get_environment("CYBERSAND_SAVE_VALUE")})
				var io := PausedIO.new() if not OS.get_environment("CYBERSAND_SAVE_GATE").is_empty() else null
				var saved: Dictionary = Transaction.write_text(path, payload, 1024, io)
				result.transaction = saved
				error = str(saved.error)
			_:
				error = "Unknown fixture kind."
	match kind:
		"ordinary": readback = Setup.read_named(label)
		"generated": readback = Generated.read_named(label)
		"material-baseline": readback = Baseline.read_named(label)
		"project":
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			readback = Project.compile(value) if value is Dictionary else {"error":"Invalid project file."}
		"helper":
			var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
			readback = value if value is Dictionary else {"error":"Invalid helper JSON."}
	result.error = error
	result.after_sha256 = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	result.readable = not readback.has("error") or str(readback.get("error", "")).is_empty()
	result.read_error = str(readback.get("error", ""))
	var file := FileAccess.open(path, FileAccess.READ)
	result.file_bytes = file.get_length() if file != null else 0
	if file != null: file.close()
	if readback.has("setup"): result.material = readback.setup.material
	if readback.has("project"): result.seed = readback.project.seed
	if readback.has("value"): result.value = readback.value
	if readback.has("baseline"): result.plane_sha256 = readback.baseline.sha256
	print("WORKBENCH_SAVE_RESULT ", JSON.stringify(result))
	if dialog != null: dialog.queue_free()
	quit()
