extends SceneTree

# Child of run_flatten_qualification.py. OS-level limits/locks are supplied by
# its parent so the unchanged production writer encounters a real storage fault.
const Setup = preload("res://scripts/workbench_setup.gd")
const Baseline = preload("res://scripts/workbench_material_baseline.gd")
const Generated = preload("res://scripts/workbench_generated_map.gd")
const SAVE_LABEL := "gen008-storage-fault-acceptance"
const Expected := "user://gen008-storage-fault-before.json"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var phase := OS.get_environment("FLATTEN_STORAGE_PHASE")
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var setup: Dictionary = Setup.fresh(bridge.default_liquid_policy(),Vector2i(512,512))
	var cells := PackedByteArray()
	cells.resize(512*512*2)
	cells.encode_u16(0,58 if phase=="prepare" else 131)
	var capture := {"ok":true,"schema":1,"extent":Vector2i(512,512),"cells":cells,"sha256":Generated.digest(cells)}
	var staged: Dictionary = Baseline.stage(capture,Vector2i(512,512))
	var result := {"phase":phase,"checks":0,"failures":[],"path":ProjectSettings.globalize_path(Setup._path(SAVE_LABEL)),
		"pid":OS.get_process_id(),"attempted_plane_bytes":cells.size()}
	if staged.has("error"):
		result.failures.append(str(staged.error))
	else:
		var old_hash := FileAccess.get_sha256(Setup._path(SAVE_LABEL)) if FileAccess.file_exists(Setup._path(SAVE_LABEL)) else ""
		print("FLATTEN_STORAGE_WRITING ",JSON.stringify({"phase":phase,"prior_sha256":old_hash,"attempted_plane_bytes":cells.size()}))
		var error := Baseline.write_named(SAVE_LABEL,setup,staged.baseline)
		result.error=error
		result.prior_sha256=old_hash
		result.after_sha256=FileAccess.get_sha256(Setup._path(SAVE_LABEL))
		if phase=="prepare":
			result.checks=2
			if not error.is_empty(): result.failures.append("ordinary initial save failed: "+error)
			if not Baseline.read_named(SAVE_LABEL).get("flattened",false): result.failures.append("initial save cannot be reopened")
			var expected := FileAccess.open(Expected,FileAccess.WRITE)
			expected.store_string(JSON.stringify({"sha256":result.after_sha256})); expected.close()
		elif phase in ["refusal","process_fault"]:
			result.checks=3
			if error.is_empty(): result.failures.append("injected OS write/replacement failure silently succeeded")
			if old_hash.is_empty() or result.after_sha256!=old_hash: result.failures.append("existing named file changed during failed replacement")
			if not Baseline.read_named(SAVE_LABEL).get("flattened",false): result.failures.append("existing named file no longer readable")
		elif phase=="recover":
			result.checks=3
			if not error.is_empty(): result.failures.append("normal retry failed: "+error)
			if result.after_sha256==old_hash: result.failures.append("normal retry did not publish the new material plane")
			var readback: Dictionary = Baseline.read_named(SAVE_LABEL)
			if not readback.get("flattened",false) or readback.baseline.cells!=cells: result.failures.append("normal retry did not reconstruct exact new bytes")
		else: result.failures.append("unknown storage phase")
	print("FLATTEN_STORAGE_RESULT ",JSON.stringify(result))
	quit(0 if result.failures.is_empty() else 1)
