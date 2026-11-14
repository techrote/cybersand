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

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func locked_source(phase: String, bridge: Object, setup: Dictionary, baseline: Dictionary,
		cells: PackedByteArray, result: Dictionary) -> Dictionary:
	# The parent holds only this fully closed source open without DELETE sharing.
	# The old destination is deliberately unlocked: remove-then-move would lose it.
	var target: String = result.path
	var temporary := target+".0123456789abcdef.tmp"
	result.source_path=temporary
	result.operation="production-native-replacement"
	result.native_api="CyberDemoBridge.replace_material_baseline_file"
	result.error=""
	result.prior_sha256=file_hash(target)
	result.source_sha256_before=file_hash(temporary)
	if not bridge.has_method(&"replace_material_baseline_file"):
		result.failures.append("source-matched native atomic replacement API is absent")
		return result
	if phase=="prepare":
		result.checks=4
		result.error=Baseline.write_named(SAVE_LABEL,setup,baseline)
		if not result.error.is_empty():
			result.failures.append("ordinary initial save failed: "+result.error)
		else:
			var replacement: Dictionary = baseline.duplicate(true)
			replacement.cells=cells.duplicate()
			replacement.cells.encode_u16(0,131)
			replacement.sha256=Generated.digest(replacement.cells)
			var source_label := SAVE_LABEL+"-replacement"
			result.error=Baseline.write_named(source_label,setup,replacement)
			if not result.error.is_empty(): result.failures.append("valid replacement staging failed: "+result.error)
			else:
				var staged_path := ProjectSettings.globalize_path(Setup._path(source_label))
				var copied := DirAccess.copy_absolute(staged_path,temporary)
				if copied!=OK or file_hash(temporary)!=file_hash(staged_path):
					result.failures.append("complete canonical source bytes were not staged")
				DirAccess.remove_absolute(staged_path)
		if not Baseline.read_named(SAVE_LABEL).get("flattened",false):
			result.failures.append("old destination cannot be reopened before the source lock")
	else:
		result.checks=5
		print("FLATTEN_STORAGE_WRITING ",JSON.stringify({"phase":phase,"operation":result.operation,
			"prior_sha256":result.prior_sha256,"source_sha256":result.source_sha256_before,
			"attempted_plane_bytes":cells.size()}))
		var replaced: Dictionary = bridge.call(&"replace_material_baseline_file",temporary,target)
		result.error=str(replaced.get("error",""))
		if phase=="refusal":
			if replaced.get("ok",false) or result.error.is_empty():
				result.failures.append("locked-source native replacement did not explicitly refuse")
			if result.prior_sha256.is_empty() or file_hash(target)!=result.prior_sha256:
				result.failures.append("locked-source refusal deleted or changed the unlocked destination")
			if result.source_sha256_before.is_empty() or file_hash(temporary)!=result.source_sha256_before:
				result.failures.append("locked-source refusal changed the complete staged source")
			if not Baseline.read_named(SAVE_LABEL).get("flattened",false):
				result.failures.append("old destination is unreadable after locked-source refusal")
		elif phase=="recover":
			result.retry_used_same_source=true
			if not replaced.get("ok",false) or not result.error.is_empty():
				result.failures.append("unlocked retry of the exact staged source failed: "+result.error)
			if file_hash(target)!=result.source_sha256_before or file_hash(target)==result.prior_sha256:
				result.failures.append("retry did not publish the same complete staged bytes")
			if FileAccess.file_exists(temporary): result.failures.append("successful native replacement did not consume its source")
			var readback: Dictionary = Baseline.read_named(SAVE_LABEL)
			if not readback.get("flattened",false) or readback.baseline.cells!=cells:
				result.failures.append("same-source retry does not reconstruct the new canonical plane")
		else: result.failures.append("unknown locked-source phase")
	result.after_sha256=file_hash(target)
	result.source_sha256_after=file_hash(temporary)
	result.source_exists_after=FileAccess.file_exists(temporary)
	return result

func run() -> void:
	var phase := OS.get_environment("FLATTEN_STORAGE_PHASE")
	var kind := OS.get_environment("FLATTEN_STORAGE_KIND")
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
	elif kind=="locked-source":
		result=locked_source(phase,bridge,setup,staged.baseline,cells,result)
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
