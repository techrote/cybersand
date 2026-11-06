extends SceneTree
# Genuine Godot framebuffer capture of external provisional world-design packs.
# Reuses the production palette, material LUT, emission and glow shaders exactly.
# Does NOT run World/physics, infer simulation conditions, or modify any pack.
#
# godot --path godot --script res://tools/capture_world_design_pack.gd -- \
#   --pack=/absolute/pack.json --output=/absolute/captures --mode=both \
#   --scale=2 --time=1.37 --glow=on --design-revision=<exact SHA>
#
# Output includes actual readback PNGs, native RG8 inputs and a success-only
# manifest; errors print machine-readable status and exit with a nonzero code.

const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const BACKGROUND: Color = Color(0.031, 0.043, 0.071, 1.0)
const PAD_CELLS: int = 32 # More than the glow/emission footprint at tile seams.
# The half-resolution emission pass evaluates UV*view_size exactly at intended
# odd integer cell coordinates before floor(). A tiny positive capture-uniform
# bias keeps those values on the intended side of the boundary across GLSL and
# ANGLE/D3D floating-point interpolation without changing shader source.
const EMISSION_COORD_EPSILON: float = 0.001
const DEFAULT_TILE_CELLS: int = 512

var pack_path: String = ""
var output_path: String = ""
var mode: String = "both"
var scale: int = 2
var presentation_time: float = 1.37
var glow_enabled: bool = true
var tile_cells: int = DEFAULT_TILE_CELLS
var design_revision: String = ""
var max_working_mib: int = 256
var require_verified_source: bool = false
var test_fail_publication: bool = false
var test_fail_rollback: bool = false
var test_fail_claim_release: bool = false
var test_pause_before_publication_ms: int = 0
var test_pause_phase: String = "prepared"
var recover_claim_id: String = ""
var attempt_id: String = ""
var staging_path: String = ""
var generation_path: String = ""
var claim_path: String = ""
var claim_acquired: bool = false
var owner_host: String = ""
var owner_process_started: String = ""
var transaction_requires_recovery: bool = false
var framebuffer_pause_consumed: bool = false
var manifest: Dictionary = {}
var resource_budget: Dictionary = {}
var palette_selection: Dictionary = {}
var palette_shader: Shader
var emission_shader: Shader
var composite_shader: Shader
var palette_lut: ImageTexture
var program_lut: ImageTexture


func _init() -> void:
	call_deferred("_run")


func _parse_arguments() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			pack_path = argument.trim_prefix("--pack=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--scale="):
			var number: String = argument.trim_prefix("--scale=")
			if not number.is_valid_int():
				return "--scale requires an integer"
			scale = int(number)
		elif argument.begins_with("--time="):
			var number: String = argument.trim_prefix("--time=")
			if not number.is_valid_float():
				return "--time requires a finite number"
			presentation_time = float(number)
		elif argument.begins_with("--glow="):
			var value: String = argument.trim_prefix("--glow=")
			if value != "on" and value != "off":
				return "--glow must be on or off"
			glow_enabled = value == "on"
		elif argument.begins_with("--tile-cells="):
			var number: String = argument.trim_prefix("--tile-cells=")
			if not number.is_valid_int():
				return "--tile-cells requires an integer"
			tile_cells = int(number)
		elif argument.begins_with("--design-revision="):
			design_revision = argument.trim_prefix("--design-revision=")
		elif argument.begins_with("--max-working-mib="):
			var number: String = argument.trim_prefix("--max-working-mib=")
			if not number.is_valid_int():
				return "--max-working-mib requires an integer"
			max_working_mib = int(number)
		elif argument.begins_with("--require-verified-source="):
			var value: String = argument.trim_prefix("--require-verified-source=")
			if value not in ["on", "off"]:
				return "--require-verified-source must be on or off"
			require_verified_source = value == "on"
		elif argument == "--test-fail-publication=on":
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "publication fault injection requires explicit test environment"
			test_fail_publication = true
		elif argument == "--test-fail-rollback=on":
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "rollback fault injection requires explicit test environment"
			test_fail_rollback = true
		elif argument == "--test-fail-claim-release=on":
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "claim-release fault injection requires explicit test environment"
			test_fail_claim_release = true
		elif argument.begins_with("--test-pause-before-publication-ms="):
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "publication pause injection requires explicit test environment"
			var number: String = argument.trim_prefix("--test-pause-before-publication-ms=")
			if not number.is_valid_int() or int(number) < 1 or int(number) > 30000:
				return "test pause must be between 1 and 30000 milliseconds"
			test_pause_before_publication_ms = int(number)
		elif argument.begins_with("--test-pause-phase="):
			if OS.get_environment("CYBERSAND_CAPTURE_FAULT_INJECTION") != "1":
				return "publication phase pause requires explicit test environment"
			test_pause_phase = argument.trim_prefix("--test-pause-phase=")
			if test_pause_phase not in ["framebuffer", "validated", "prepared", "published-data"]:
				return "test pause phase must be framebuffer, validated, prepared or published-data"
		elif argument.begins_with("--recover-claim="):
			recover_claim_id = argument.trim_prefix("--recover-claim=")
			if recover_claim_id.is_empty():
				return "--recover-claim requires the exact stale attempt id"
		else:
			return "unknown argument: " + argument
	if pack_path.is_empty() or output_path.is_empty():
		return "explicit --pack and --output are required"
	if not pack_path.is_absolute_path():
		return "--pack must be absolute"
	if not output_path.is_absolute_path():
		return "--output must be an absolute directory"
	if max_working_mib < 16 or max_working_mib > Adapter.MAX_BUDGET_MIB:
		return "--max-working-mib must be within 16..1024"
	if not (mode in ["both", "combined", "individual"]):
		return "--mode must be both, combined or individual"
	if scale < 1 or scale > 8:
		return "--scale must be between 1 and 8"
	if is_nan(presentation_time) or is_inf(presentation_time) or presentation_time < 0.0:
		return "--time must be finite and nonnegative"
	if tile_cells < 64 or tile_cells > 2048 or tile_cells % 2 != 0 or (tile_cells + PAD_CELLS * 2) * scale > 8192:
		return "--tile-cells must be even (64..2048), with padded view <=8192 pixels"
	pack_path = pack_path.replace("\\", "/").simplify_path()
	output_path = output_path.replace("\\", "/").simplify_path()
	return _validate_paths()


func _path_key(path: String) -> String:
	var value: String = path.replace("\\", "/").simplify_path()
	while value.length() > 1 and value.ends_with("/"):
		if value.length() == 3 and value.substr(1, 2) == ":/":
			break
		value = value.substr(0, value.length() - 1)
	return value.to_lower() if OS.get_name() == "Windows" else value


func _path_contains(ancestor: String, child: String) -> bool:
	var a: String = _path_key(ancestor)
	var c: String = _path_key(child)
	if a == c:
		return true
	if a == "/":
		return c.begins_with("/")
	return c.begins_with(a + "/")


func _linked_component(path: String) -> String:
	var cursor: String = path.replace("\\", "/").simplify_path()
	while true:
		var parent: String = cursor.get_base_dir()
		if parent.is_empty() or parent == cursor:
			return ""
		var access: DirAccess = DirAccess.open(parent)
		if access != null and access.is_link(cursor.get_file()):
			return cursor
		cursor = parent
	return ""


# Compare an existing target directory against every existing ancestor of a
# possibly-nonexistent path. This supplements lexical containment for filesystem
# aliases such as Windows short-name/subst paths without resolving through links
# (links/reparse points are rejected separately above).
func _ancestor_equivalent(path: String, target: String) -> bool:
	if not DirAccess.dir_exists_absolute(target):
		return false
	var cursor: String = path.replace("\\", "/").simplify_path()
	while true:
		if DirAccess.dir_exists_absolute(cursor):
			var access: DirAccess = DirAccess.open(cursor)
			if access != null and access.is_equivalent(cursor, target):
				return true
		var parent: String = cursor.get_base_dir()
		if parent.is_empty() or parent == cursor:
			break
		cursor = parent
	return false


func _validate_paths() -> String:
	var source_dir: String = pack_path.get_base_dir().replace("\\", "/").simplify_path()
	var destination: String = output_path.replace("\\", "/").simplify_path()
	var source_alias: String = _linked_component(pack_path)
	if not source_alias.is_empty():
		return "input pack path contains a symlink/junction/reparse point: " + source_alias
	var destination_alias: String = _linked_component(destination)
	if not destination_alias.is_empty():
		return "output path contains a symlink/junction/reparse point: " + destination_alias
	if _path_contains(source_dir, destination) or _ancestor_equivalent(destination, source_dir):
		return "--output must not be equal to or inside the input pack directory"
	if _path_contains(destination, source_dir) or (
		DirAccess.dir_exists_absolute(destination) and _ancestor_equivalent(source_dir, destination)):
		return "--output must not equal or contain the input pack directory"
	var project_root: String = ProjectSettings.globalize_path("res://").get_base_dir().replace("\\", "/").simplify_path()
	if _path_contains(destination, project_root) or (
		DirAccess.dir_exists_absolute(destination) and _ancestor_equivalent(project_root, destination)):
		return "--output must not equal or contain the CyberSand source/workspace root"
	var key: String = _path_key(destination)
	if key == "/" or (key.length() == 3 and key.substr(1, 2) == ":/"):
		return "--output must not be a filesystem root"
	if DirAccess.dir_exists_absolute(destination):
		var source_access: DirAccess = DirAccess.open(source_dir)
		if source_access != null and source_access.is_equivalent(source_dir, destination):
			return "--output resolves to the input pack directory"
	return ""


func _output_custody_error() -> String:
	if FileAccess.file_exists(output_path) and not DirAccess.dir_exists_absolute(output_path):
		return "output path already exists as a file"
	if not DirAccess.dir_exists_absolute(output_path):
		return ""
	var access: DirAccess = DirAccess.open(output_path)
	if access == null:
		return "cannot inspect existing output directory"
	var files: PackedStringArray = access.get_files()
	var dirs: PackedStringArray = access.get_directories()
	if files.is_empty() and dirs.is_empty():
		return ""
	var owner_path: String = output_path.path_join(".world-capture-owner.json")
	if FileAccess.file_exists(owner_path):
		var owner: Variant = JSON.parse_string(FileAccess.get_file_as_string(owner_path))
		if typeof(owner) == TYPE_DICTIONARY and owner.get("owner") == "cybersand-world-design-capture":
			return ""
	var manifest_path: String = output_path.path_join("capture-manifest.json")
	if FileAccess.file_exists(manifest_path):
		var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if typeof(record) == TYPE_DICTIONARY and record.get("fixture") == "res://tools/capture_world_design_pack.gd":
			return ""
	return "refusing non-empty output directory without CyberSand capture ownership metadata"


func _write_transaction(state: String, extra: Dictionary = {}) -> bool:
	if claim_path.is_empty() or not DirAccess.dir_exists_absolute(claim_path):
		return false
	var record: Dictionary = {"schema": 3, "state": state, "attempt_id": attempt_id,
		"output_path": output_path, "pack_path": pack_path,
		"process_id": OS.get_process_id(), "owner_host": owner_host,
		"owner_process_started": owner_process_started,
		"requires_recovery": transaction_requires_recovery}
	record.merge(extra, true)
	return _write_json(claim_path.path_join("transaction.json"), record)


func _release_claim() -> bool:
	if not claim_acquired:
		return true
	if transaction_requires_recovery:
		return false
	if test_fail_claim_release:
		transaction_requires_recovery = true
		_write_transaction("release_failed", {
			"error": "fault-injected claim release failure",
			"fault_injected": true})
		return false
	# Relinquish the fixed claim name with one same-parent rename. If this fails,
	# the original claim and its transaction remain intact and explicitly
	# recoverable. Cleanup of the released archive is non-authoritative.
	var released_path: String = output_path + ".world-capture-released-" + attempt_id
	if DirAccess.dir_exists_absolute(released_path) or FileAccess.file_exists(released_path):
		transaction_requires_recovery = true
		_write_transaction("release_failed", {
			"error": "claim release archive path is unexpectedly occupied",
			"released_path": released_path})
		return false
	_write_transaction("releasing", {"released_path": released_path})
	if DirAccess.rename_absolute(claim_path, released_path) != OK:
		transaction_requires_recovery = true
		_write_transaction("release_failed", {
			"error": "cannot atomically relinquish publication claim",
			"released_path": released_path})
		return false
	claim_acquired = false
	var transaction_file: String = released_path.path_join("transaction.json")
	if FileAccess.file_exists(transaction_file) and DirAccess.remove_absolute(transaction_file) != OK:
		push_warning("retained released publication transaction archive: " + released_path)
		return true
	if DirAccess.dir_exists_absolute(released_path) and DirAccess.remove_absolute(released_path) != OK:
		push_warning("retained released publication claim archive: " + released_path)
	return true


# Recovery requires a stable OS instance + process-namespace identity and
# the original process's start identity. A user-supplied hostname alone cannot
# establish process-table visibility on shared volumes (e.g. Linux containers).
# Failed or unsupported identity probes are UNKNOWN and deny recovery.
func _identity_command(program: String, arguments: PackedStringArray) -> String:
	var output: Array = []
	var code: int = OS.execute(program, arguments, output, true)
	if code != 0 or output.size() != 1:
		return ""
	return str(output[0]).strip_edges()


func _owner_host_identity() -> String:
	if OS.get_name() == "Linux":
		var boot: String = _identity_command("cat", PackedStringArray(["/proc/sys/kernel/random/boot_id"]))
		var pid_ns: String = _identity_command("readlink", PackedStringArray(["/proc/self/ns/pid"]))
		if boot.is_empty() or not pid_ns.begins_with("pid:[") or not pid_ns.ends_with("]"):
			return ""
		return "Linux:" + boot + ":" + pid_ns
	if OS.get_name() == "Windows":
		# MachineGuid alone is insufficient across OS boots. Include the real
		# system boot timestamp; never trust the inherited COMPUTERNAME string.
		var probe: String = ("$ErrorActionPreference = 'Stop'; try { " +
			"$id = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Cryptography' -Name 'MachineGuid').MachineGuid; " +
			"$boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks; " +
			"if ([string]::IsNullOrWhiteSpace($id)) { exit 2 }; " +
			"[Console]::Out.Write($id.ToLowerInvariant() + ':' + $boot.ToString()) " +
			"} catch { exit 3 }")
		var result: String = _identity_command("powershell.exe",
			PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", probe]))
		if result.length() < 40 or result.find(":") < 0:
			return ""
		return "Windows:" + result
	return ""


# Linux /proc/<pid>/stat field 22 is the process-start tick. The comm field
# may include spaces and closing parentheses; split after the LAST ')'.
func _linux_process_started(pid: int) -> String:
	var file: String = "/proc/" + str(pid) + "/stat"
	if not FileAccess.file_exists(file):
		return ""
	var stat: String = _identity_command("cat", PackedStringArray([file]))
	var end_comm: int = stat.rfind(")")
	if end_comm < 0 or end_comm + 2 >= stat.length():
		return ""
	var fields: PackedStringArray = stat.substr(end_comm + 2).split(" ", false)
	if fields.size() < 20:
		return ""
	var start: String = fields[19].strip_edges()
	return start if start.is_valid_int() and int(start) > 0 else ""


func _owner_process_started(pid: int) -> String:
	if pid <= 0:
		return ""
	if OS.get_name() == "Linux":
		return _linux_process_started(pid)
	if OS.get_name() == "Windows":
		var probe: String = ("$ErrorActionPreference = 'Stop'; try { " +
			"$p = Get-Process -Id %d -ErrorAction Stop; " +
			"[Console]::Out.Write($p.StartTime.ToUniversalTime().Ticks.ToString()) " +
			"} catch { exit 3 }") % pid
		var result: String = _identity_command("powershell.exe",
			PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", probe]))
		return result if result.is_valid_int() and int(result) > 0 else ""
	return ""


# "dead" is permitted only within the SAME verified OS/PID namespace.
# A live, different process using the original numeric PID is NOT the owner;
# its distinct start identity permits recovery of the original dead attempt.
func _owner_liveness(pid: int, expected_started: String) -> String:
	if pid <= 0 or expected_started.is_empty() or not expected_started.is_valid_int():
		return "unknown"
	if OS.get_name() == "Linux":
		if not DirAccess.dir_exists_absolute("/proc") or not FileAccess.file_exists("/proc/self/stat"):
			return "unknown"
		if not DirAccess.dir_exists_absolute("/proc/" + str(pid)):
			return "dead"
		var current: String = _linux_process_started(pid)
		if current.is_empty():
			return "unknown"
		return "alive" if current == expected_started else "dead"
	if OS.get_name() == "Windows":
		var probe: String = ("$ErrorActionPreference = 'Stop'; try { " +
			"$p = Get-Process -Id %d -ErrorAction Stop; " +
			"[Console]::Out.Write('alive:' + $p.StartTime.ToUniversalTime().Ticks.ToString()) " +
			"} catch { if ($_.CategoryInfo.Category -eq 'ObjectNotFound') { " +
			"[Console]::Out.Write('dead') } else { [Console]::Out.Write('unknown') } }") % pid
		var result: String = _identity_command("powershell.exe",
			PackedStringArray(["-NoProfile", "-NonInteractive", "-Command", probe]))
		if result == "dead":
			return "dead"
		if not result.begins_with("alive:"):
			return "unknown"
		var current: String = result.trim_prefix("alive:")
		if not current.is_valid_int():
			return "unknown"
		return "alive" if current == expected_started else "dead"
	return "unknown"


func _prepare_target() -> String:
	var custody: String = _output_custody_error()
	if not custody.is_empty():
		return custody
	owner_host = _owner_host_identity()
	if owner_host.is_empty():
		return "cannot establish OS boot and PID namespace identity for safe publication claim"
	owner_process_started = _owner_process_started(OS.get_process_id())
	if owner_process_started.is_empty():
		return "cannot establish process-start identity for safe publication claim"
	attempt_id = "%d-%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec(), OS.get_process_id()]
	claim_path = output_path + ".world-capture-claim"
	if FileAccess.file_exists(claim_path) and not DirAccess.dir_exists_absolute(claim_path):
		return "publication claim path is occupied by a file: " + claim_path
	if DirAccess.dir_exists_absolute(claim_path):
		var stale: Variant = JSON.parse_string(FileAccess.get_file_as_string(claim_path.path_join("transaction.json")))
		var stale_id: String = str(stale.get("attempt_id", "")) if typeof(stale) == TYPE_DICTIONARY else ""
		if recover_claim_id.is_empty():
			return "output is already claimed by attempt " + stale_id + "; explicit --recover-claim=<attempt-id> is required after confirming the process is no longer active"
		if recover_claim_id != stale_id:
			return "--recover-claim does not match the existing transaction attempt id"
		# Refuse schema-1/2, incomplete or cross-namespace records: there is no trustworthy
		# evidence that their recorded PID can be checked in this OS namespace.
		if typeof(stale) != TYPE_DICTIONARY or int(stale.get("schema", 0)) != 3:
			return "output is already claimed; legacy or incomplete transaction cannot be safely recovered"
		var owner_pid_value: Variant = stale.get("process_id", null)
		if typeof(owner_pid_value) not in [TYPE_INT, TYPE_FLOAT]:
			return "output is already claimed; owner process identity is malformed"
		var previous_pid: int = int(owner_pid_value)
		if previous_pid <= 0 or not stale_id.ends_with("-" + str(previous_pid)):
			return "output is already claimed; attempt and owner process identity disagree"
		if str(stale.get("owner_host", "")) != owner_host or stale.get("output_path") != output_path:
			return "output is already claimed; owner host or output identity cannot be verified"
		var previous_start: String = str(stale.get("owner_process_started", ""))
		if previous_start.is_empty() or not previous_start.is_valid_int():
			return "output is already claimed; previous owner process-start identity is missing"
		var state: String = _owner_liveness(previous_pid, previous_start)
		if state == "alive":
			return "output is already claimed by live attempt " + stale_id + "; recovery cannot evict an active process"
		if state != "dead":
			return "output is already claimed; previous owner liveness is unverified"
		var recovered: String = output_path + ".world-capture-recovered-" + recover_claim_id
		if DirAccess.dir_exists_absolute(recovered) or FileAccess.file_exists(recovered):
			return "recovery archive already exists: " + recovered
		if DirAccess.rename_absolute(claim_path, recovered) != OK:
			return "cannot archive stale publication claim"
	if DirAccess.make_dir_absolute(claim_path) != OK:
		return "cannot acquire exclusive publication claim"
	claim_acquired = true
	if not _write_transaction("claimed"):
		transaction_requires_recovery = true
		return "cannot write publication transaction record"
	return ""

func _status(code: int, error: String) -> void:
	var preliminary: Dictionary = {"status": "failed" if code != 0 else "complete",
		"success": code == 0, "exit_code": code, "attempt_id": attempt_id,
		"message": error}
	if code != 0:
		if not staging_path.is_empty() and DirAccess.dir_exists_absolute(staging_path):
			var unpublished: String = staging_path.path_join("capture-manifest.json")
			if FileAccess.file_exists(unpublished):
				if DirAccess.remove_absolute(unpublished) != OK:
					push_error("failed to invalidate uncommitted staging manifest: " + unpublished)
			_write_json(staging_path.path_join("capture-status.json"), preliminary)
		if claim_acquired:
			_write_transaction("recovery_required" if transaction_requires_recovery else "failed",
				{"exit_code": code, "message": error,
					"staging_path": staging_path, "generation_path": generation_path,
					"rollback_or_transaction_failure": transaction_requires_recovery})
	var final_code: int = code
	var final_error: String = error
	var released: bool = _release_claim()
	if not released and claim_acquired:
		if code == 0:
			final_code = 5
			final_error = error + "; publication committed but claim release failed; explicit recovery required"
			transaction_requires_recovery = true
			_write_transaction("release_failed", {
				"exit_code": final_code, "message": final_error,
				"publication_committed": manifest.get("success", false)})
			if DirAccess.dir_exists_absolute(output_path):
				_write_json(output_path.path_join("capture-status.json"), {
					"status": "committed_recovery_required", "success": true,
					"exit_code": final_code, "attempt_id": attempt_id,
					"message": final_error, "claim_recovery_required": true})
		push_error("publication claim retained for recovery: " + claim_path)
	var result: Dictionary = {"status": "failed" if final_code != 0 else "complete",
		"success": final_code == 0, "exit_code": final_code, "attempt_id": attempt_id,
		"message": final_error, "publication_committed": manifest.get("success", false)}
	print("WORLD_DESIGN_CAPTURE ", JSON.stringify(result))
	quit(final_code)

func _write_json(path: String, value: Variant) -> bool:
	var temp: String = path + ".pending"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(temp, path) == OK


func _save_png(image: Image, relative: String, category: String, extra: Dictionary = {}) -> bool:
	var absolute: String = staging_path.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	if image == null or image.is_empty() or image.save_png(absolute) != OK:
		return false
	var entry: Dictionary = {"file": relative, "kind": category,
		"size": [image.get_width(), image.get_height()],
		"bytes": FileAccess.get_file_as_bytes(absolute).size(),
		"sha256": FileAccess.get_sha256(absolute),
		"provenance": "Godot SubViewport framebuffer readback"}
	entry.merge(extra, true)
	manifest.captures.append(entry)
	if not framebuffer_pause_consumed:
		framebuffer_pause_consumed = true
		_test_pause("framebuffer")
	return true


func _save_input(input: Dictionary, relative: String) -> bool:
	var absolute: String = staging_path.path_join(relative)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var file: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(input.data)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_sha256(absolute) != input.rg8_sha256:
		return false
	manifest.inputs.append({"file": relative, "format": "Image.FORMAT_RG8",
		"size": [input["size"].x, input["size"].y], "bytes": input.rg8_bytes,
		"sha256": input.rg8_sha256, "condition_policy": "synthetic_native_initial",
		"geometry": input.geometry})
	return true


func _read_pack() -> Dictionary:
	if not FileAccess.file_exists(pack_path):
		return {"ok": false, "error": "pack not found: " + pack_path}
	var content: String = FileAccess.get_file_as_string(pack_path)
	var parser: JSON = JSON.new()
	var code: Error = parser.parse(content)
	if code != OK:
		return {"ok": false, "error": "invalid pack JSON line %d: %s" % [
			parser.get_error_line(), parser.get_error_message()]}
	var info: Dictionary = Adapter.inspect(parser.data)
	if not info.ok:
		return info
	return {"ok": true, "pack": parser.data, "info": info,
		"sha256": FileAccess.get_sha256(pack_path)}


func _load_shaders() -> bool:
	var original_palette: Shader = load("res://shaders/material_palette.gdshader")
	if original_palette == null:
		return false
	palette_shader = CyberPaletteShader.for_current_renderer(original_palette)
	palette_selection = CyberPaletteShader.provenance(palette_shader)
	if not palette_selection.get("source_bound", false) or not palette_selection.get("source_file_bound", false):
		return false
	emission_shader = load("res://shaders/material_emission.gdshader")
	composite_shader = load("res://shaders/glow_composite.gdshader")
	if palette_shader == null or emission_shader == null or composite_shader == null:
		return false
	palette_lut = CyberMaterialAppearanceLut.create_texture()
	program_lut = CyberMaterialAppearanceLut.create_program_texture()
	if palette_lut == null or program_lut == null:
		return false
	return true



# Best-effort Git checkout identity is separate from caller-supplied strings.
# An exported pack outside Git still has a verified content SHA-256.
func _source_identity() -> Dictionary:
	var declared: String = OS.get_environment("CYBERSAND_SOURCE_REVISION")
	var checkout: String = ""
	var clean: bool = false
	var project_path: String = ProjectSettings.globalize_path("res://").simplify_path()
	var repo_root: String = ""
	var result: Array = []
	var code: int = OS.execute("git", PackedStringArray([
		"-C", project_path, "rev-parse", "--show-toplevel"]), result, true)
	if code == 0 and result.size() > 0:
		repo_root = str(result[0]).strip_edges()
	if not repo_root.is_empty():
		result.clear()
		code = OS.execute("git", PackedStringArray([
			"-C", repo_root, "rev-parse", "--verify", "HEAD"]), result, true)
		if code == 0 and result.size() > 0:
			var value: String = str(result[0]).strip_edges()
			if value.length() == 40 and value.is_valid_hex_number():
				checkout = value
	if not checkout.is_empty():
		result.clear()
		code = OS.execute("git", PackedStringArray([
			"-C", repo_root, "status", "--porcelain", "--untracked-files=no",
			"--", "godot/project.godot", "godot/tools", "godot/shaders", "godot/scripts"]), result, true)
		clean = code == 0 and (result.is_empty() or str(result[0]).strip_edges().is_empty())
	return {"source_revision_declared": declared,
		"verified_source_revision": checkout if clean else "",
		"git_checkout_head": checkout,
		"git_worktree_root": repo_root,
		"capture_source_tree_clean": clean,
		"verification_paths": ["godot/project.godot", "godot/tools", "godot/shaders", "godot/scripts"],
		"declared_matches_verified": clean and not declared.is_empty() and declared == checkout,
		"source_verification": "clean Git checkout for project/render config, capture tools, shaders and scripts" if clean else "unverified working source"}


func _test_pause(phase: String) -> void:
	if test_pause_before_publication_ms > 0 and test_pause_phase == phase:
		print("WORLD_DESIGN_CAPTURE test pause phase=" + phase + " attempt=" + attempt_id)
		OS.delay_msec(test_pause_before_publication_ms)


func _create_stage() -> bool:
	if not claim_acquired:
		return false
	staging_path = output_path + ".world-capture-stage-" + attempt_id
	if DirAccess.dir_exists_absolute(staging_path) or FileAccess.file_exists(staging_path):
		return false
	if DirAccess.make_dir_absolute(staging_path) != OK:
		return false
	_write_transaction("staging", {"staging_path": staging_path})
	return true


func _verify_staging() -> bool:
	for entry: Dictionary in manifest.inputs + manifest.captures:
		var path: String = staging_path.path_join(str(entry["file"]))
		if not FileAccess.file_exists(path):
			return false
		if FileAccess.get_sha256(path) != entry["sha256"]:
			return false
		if FileAccess.get_file_as_bytes(path).size() != int(entry["bytes"]):
			return false
	return true


func _rollback_generation(reason: String) -> bool:
	if generation_path.is_empty() or not DirAccess.dir_exists_absolute(generation_path):
		return true
	if test_fail_rollback:
		transaction_requires_recovery = true
		_write_transaction("rollback_failed", {"reason": reason,
			"generation_path": generation_path, "staging_path": staging_path,
			"fault_injected": true})
		return false
	if DirAccess.dir_exists_absolute(staging_path) or FileAccess.file_exists(staging_path):
		transaction_requires_recovery = true
		_write_transaction("rollback_failed", {"reason": reason,
			"generation_path": generation_path, "staging_path": staging_path,
			"error": "staging path unexpectedly occupied"})
		return false
	if DirAccess.rename_absolute(generation_path, staging_path) != OK:
		transaction_requires_recovery = true
		_write_transaction("rollback_failed", {"reason": reason,
			"generation_path": generation_path, "staging_path": staging_path,
			"error": "generation rename rollback failed"})
		return false
	generation_path = ""
	_write_transaction("rolled_back", {"reason": reason, "staging_path": staging_path})
	return true


func _publish_capture() -> bool:
	if not _verify_staging():
		return false
	_test_pause("validated")
	manifest.status = "prepared"
	manifest.success = false
	manifest.capture_count = manifest.captures.size()
	manifest.input_count = manifest.inputs.size()
	manifest.attempt_id = attempt_id
	if not _write_json(staging_path.path_join("capture-prepared.json"), manifest):
		return false
	if not _write_json(staging_path.path_join("capture-status.json"),
		{"status": "prepared", "success": false, "attempt_id": attempt_id,
			"capture_count": manifest.capture_count, "input_count": manifest.input_count}):
		return false
	_write_transaction("prepared", {"staging_path": staging_path})
	_test_pause("prepared")
	var path_error: String = _validate_paths()
	if not path_error.is_empty():
		_write_transaction("path_revalidation_failed", {"message": path_error})
		return false
	var custody: String = _output_custody_error()
	if not custody.is_empty():
		_write_transaction("custody_revalidation_failed", {"message": custody})
		return false
	if not DirAccess.dir_exists_absolute(output_path):
		if DirAccess.make_dir_recursive_absolute(output_path) != OK:
			return false
	var owner_path: String = output_path.path_join(".world-capture-owner.json")
	if not FileAccess.file_exists(owner_path):
		if not _write_json(owner_path, {"schema": 1, "owner": "cybersand-world-design-capture"}):
			return false
	var generation_root: String = output_path.path_join(".world-capture-generations")
	if DirAccess.make_dir_recursive_absolute(generation_root) != OK:
		return false
	generation_path = generation_root.path_join(attempt_id)
	if DirAccess.dir_exists_absolute(generation_path) or FileAccess.file_exists(generation_path):
		return false
	if DirAccess.rename_absolute(staging_path, generation_path) != OK:
		return false
	_write_transaction("generation_published", {"generation_path": generation_path})
	_test_pause("published-data")
	if test_fail_publication:
		_rollback_generation("fault-injected failure after generation publication")
		return false
	var prefix: String = ".world-capture-generations/" + attempt_id
	var final_manifest: Dictionary = manifest.duplicate(true)
	for entry: Dictionary in final_manifest.inputs:
		entry.file = prefix + "/" + str(entry.file)
	for entry: Dictionary in final_manifest.captures:
		entry.file = prefix + "/" + str(entry.file)
	final_manifest.status = "complete"
	final_manifest.success = true
	final_manifest.publication_model = "immutable generation + atomic root manifest"
	final_manifest.generation = prefix
	if not _write_json(output_path.path_join("capture-manifest.json"), final_manifest):
		_rollback_generation("root manifest commit failed")
		return false
	manifest = final_manifest
	staging_path = ""
	_write_transaction("committed", {"generation_path": generation_path,
		"manifest_path": output_path.path_join("capture-manifest.json")})
	# The manifest is the authoritative commit point. A status write after this
	# may be absent after hard termination, but cannot make the committed bytes
	# incomplete or misleading.
	_write_json(output_path.path_join("capture-status.json"),
		{"status": "complete", "success": true, "attempt_id": attempt_id,
			"capture_count": manifest.capture_count, "input_count": manifest.input_count,
			"generation": prefix})
	generation_path = ""
	return true

func _make_rig(input: Image, camera: Vector2i, view: Vector2i) -> Dictionary:
	var output_size: Vector2i = view * scale
	var viewport: SubViewport = SubViewport.new()
	viewport.size = output_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.use_hdr_2d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(output_size)
	viewport.add_child(background)
	var source_texture: ImageTexture = ImageTexture.create_from_image(input)
	var world_size: Vector2 = Vector2(input.get_size())
	var palette: ShaderMaterial = ShaderMaterial.new()
	palette.shader = palette_shader
	palette.set_shader_parameter("world_size_px", world_size)
	palette.set_shader_parameter("view_size_px", Vector2(view))
	palette.set_shader_parameter("view_rect_uv", Vector4(0.0, 0.0, 1.0, 1.0))
	palette.set_shader_parameter("camera_origin_px", Vector2(camera))
	palette.set_shader_parameter("player_origin_px", Vector2(-1000, -1000))
	palette.set_shader_parameter("condition_projection_enabled", 1.0)
	palette.set_shader_parameter("water_presentation_mode", 0.0)
	palette.set_shader_parameter("structured_detail", 1.0)
	palette.set_shader_parameter("growth_decor", 1.0)
	palette.set_shader_parameter("snapshot_blend", 1.0)
	palette.set_shader_parameter("presentation_time_override", presentation_time)
	palette.set_shader_parameter("current_world_texture", source_texture)
	palette.set_shader_parameter("previous_world_texture", source_texture)
	palette.set_shader_parameter("material_lut", palette_lut)
	palette.set_shader_parameter("material_program_lut", program_lut)
	palette.set_shader_parameter("material_lut_size", Vector2(
		CyberMaterialAppearanceLut.ATLAS_WIDTH, CyberMaterialAppearanceLut.ATLAS_HEIGHT))
	var world_rect: TextureRect = TextureRect.new()
	world_rect.size = Vector2(output_size)
	world_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	world_rect.stretch_mode = TextureRect.STRETCH_SCALE
	world_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_rect.texture = source_texture
	world_rect.material = palette
	viewport.add_child(world_rect)
	# Same three stages as capture_material_review.gd, with a world-aligned camera.
	var glow_viewport: SubViewport = SubViewport.new()
	glow_viewport.disable_3d = true
	glow_viewport.transparent_bg = true
	glow_viewport.use_hdr_2d = true
	glow_viewport.size = Vector2i(maxi(1, (view.x + 1) / 2), maxi(1, (view.y + 1) / 2))
	glow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(glow_viewport)
	var emission: ShaderMaterial = ShaderMaterial.new()
	emission.shader = emission_shader
	emission.set_shader_parameter("world_texture", source_texture)
	emission.set_shader_parameter("material_program_lut", program_lut)
	emission.set_shader_parameter("world_size_px", world_size)
	emission.set_shader_parameter("view_size_px",
		Vector2(view) + Vector2(EMISSION_COORD_EPSILON, EMISSION_COORD_EPSILON))
	emission.set_shader_parameter("camera_origin_px", Vector2(camera))
	emission.set_shader_parameter("condition_projection_enabled", 1.0)
	emission.set_shader_parameter("presentation_time_override", presentation_time)
	var source: ColorRect = ColorRect.new()
	source.size = Vector2(glow_viewport.size)
	source.color = Color.WHITE
	source.material = emission
	glow_viewport.add_child(source)
	var composite: ShaderMaterial = ShaderMaterial.new()
	composite.shader = composite_shader
	var overlay: TextureRect = TextureRect.new()
	overlay.size = Vector2(output_size)
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	overlay.texture = glow_viewport.get_texture()
	overlay.material = composite
	overlay.visible = glow_enabled
	viewport.add_child(overlay)
	if not glow_enabled:
		glow_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	return {"viewport": viewport, "camera": camera, "view": view}


func _readback(input: Image, camera: Vector2i, view: Vector2i) -> Dictionary:
	var rig: Dictionary = _make_rig(input, camera, view)
	# The child glow viewport must submit before the parent samples it.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result: Image = rig.viewport.get_texture().get_image()
	rig.viewport.queue_free()
	await process_frame
	if result == null or result.is_empty() or result.get_size() != view * scale:
		return {"ok": false, "error": "Godot viewport did not submit requested pixels"}
	result.convert(Image.FORMAT_RGB8) # Same display-clamped readback as material review.
	return {"ok": true, "image": result}


func _render_rg8(input: Dictionary) -> Dictionary:
	var size: Vector2i = input["size"]
	if size.x * scale > 32768 or size.y * scale > 32768:
		return {"ok": false, "error": "output exceeds bounded Image extent"}
	var img: Image = Image.create_from_data(size.x, size.y, false,
		Image.FORMAT_RG8, input.data)
	if img == null or img.is_empty() or img.get_data() != input.data:
		return {"ok": false, "error": "RG8 Image bytes did not survive construction"}
	var output: Image = Image.create_empty(size.x * scale, size.y * scale,
		false, Image.FORMAT_RGB8)
	for y: int in range(0, size.y, tile_cells):
		for x: int in range(0, size.x, tile_cells):
			var inner: Rect2i = Rect2i(x, y, mini(tile_cells, size.x - x),
				mini(tile_cells, size.y - y))
			# Every tile begins on the same even world-cell sampling phase.
			# Constant 32-cell overdraw (including outside world bounds) makes
			# the half-resolution emission shader phase-consistent at seams.
			var start: Vector2i = inner.position - Vector2i(PAD_CELLS, PAD_CELLS)
			var view: Vector2i = inner.size + Vector2i(PAD_CELLS * 2, PAD_CELLS * 2)
			if view.x % 2 != 0:
				view.x += 1
			if view.y % 2 != 0:
				view.y += 1
			var tile: Dictionary = await _readback(img, start, view)
			if not tile.ok:
				return tile
			var source_rect: Rect2i = Rect2i((inner.position - start) * scale,
				inner.size * scale)
			output.blit_rect(tile.image, source_rect, inner.position * scale)
	return {"ok": true, "image": output, "tiles": [
		(size.x + tile_cells - 1) / tile_cells, (size.y + tile_cells - 1) / tile_cells]}


func _details(combined: Image, info: Dictionary) -> bool:
	var placements: Array[Dictionary] = info.placements
	if placements.size() < 2:
		return true # Not possible to provide two distinct placement details.
	for i: int in [0, placements.size() - 1]:
		var p: Dictionary = placements[i]
		var f: Dictionary = info.features[p.feature]
		var f_size: Vector2i = Vector2i(f["size"][0], f["size"][1])
		var origin: Vector2i = Vector2i(p.origin[0], p.origin[1])
		var min_point: Vector2i = Vector2i(maxi(0, origin.x - 16),
			maxi(0, origin.y - 16))
		var end: Vector2i = Vector2i(mini(info["size"].x, origin.x + f_size.x + 16),
			mini(info["size"].y, origin.y + f_size.y + 16))
		var rect: Rect2i = Rect2i(min_point * scale, (end - min_point) * scale)
		var crop: Image = combined.get_region(rect)
		var filename: String = "details/%s-%s.png" % [
			"first" if i == 0 else "last", p.feature]
		if not _save_png(crop, filename, "full-resolution crop",
			{"source": "combined.png", "world_rect": [
				min_point.x, min_point.y, end.x - min_point.x, end.y - min_point.y]}):
			return false
	return true


func _run() -> void:
	var error: String = _parse_arguments()
	if not error.is_empty():
		_status(2, error)
		return
	error = _prepare_target()
	if not error.is_empty():
		_status(5, error)
		return
	if DisplayServer.get_name() == "headless":
		_status(3, "graphical DisplayServer required; headless is NOT a pass")
		return
	var loaded: Dictionary = _read_pack()
	if not loaded.ok:
		_status(2, loaded.error)
		return
	var info: Dictionary = loaded.info
	resource_budget = Adapter.capture_resource_budget(info, scale, tile_cells, mode, max_working_mib)
	if not resource_budget.ok:
		_status(2, resource_budget.error)
		return
	var source_identity: Dictionary = _source_identity()
	if require_verified_source and not source_identity.declared_matches_verified:
		_status(2, "mandatory source revision verification failed; declared revision does not match a clean Git checkout")
		return
	if not _load_shaders():
		_status(3, "failed to load production material shaders/LUT")
		return
	if not _create_stage():
		_status(5, "cannot create isolated capture staging directory")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	manifest = {"status": "incomplete", "success": false,
		"fixture": "res://tools/capture_world_design_pack.gd",
		"source_revision": OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"source_revision_role": "caller declaration; not independently verified",
		"source_identity": source_identity,
		"design_pack_revision": design_revision,
		"design_revision_declared": design_revision,
		"design_revision_verified": null,
		"design_revision_verification": "external content-addressed pack; Git revision not asserted",
		"pack_path": pack_path,
		"pack_sha256": loaded.sha256, "family": info.family,
		"scene_dimensions_cells": [info["size"].x, info["size"].y],
		"features_declared": info.features.size(),
		"godot_version": Engine.get_version_info().string,
		"os": OS.get_name(), "display": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"palette_selection": palette_selection,
		"executable_path": OS.get_executable_path(),
		"executable_sha256": FileAccess.get_sha256(OS.get_executable_path()),
		"resource_budget": resource_budget,
		"graphics_adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"rendering_config": {"mode": mode, "scale": scale, "time": presentation_time,
			"glow": glow_enabled, "tile_cells": tile_cells, "tile_padding_cells": PAD_CELLS,
			"hdr_2d": true, "condition_projection_enabled": 1.0,
			"water_presentation_mode": 0.0, "structured_detail": 1.0},
		"condition_policy": {
			"kind": "SYNTHETIC, not native simulation observation",
			"initial_material_condition_bytes": Adapter.INITIAL_CONDITION,
			"molten_glass_id_36_synthetic_heat": Adapter.SYNTHETIC_MOLTEN_GLASS_HEAT,
			"other_material_ids": 0,
			"source": "godot/tests/capture_material_review.gd creation-state policy"},
		"shader_sha256": {
			"palette": FileAccess.get_sha256("res://shaders/material_palette.gdshader"),
			"emission": FileAccess.get_sha256("res://shaders/material_emission.gdshader"),
			"glow_composite": FileAccess.get_sha256("res://shaders/glow_composite.gdshader"),
			"appearance_lut_script": FileAccess.get_sha256("res://scripts/material_appearance_lut.gd")},
		"render_source_sha256": {
			"project.godot": FileAccess.get_sha256("res://project.godot"),
			"palette_selector": FileAccess.get_sha256("res://scripts/palette_shader_selector.gd"),
			"appearance_lut_script": FileAccess.get_sha256("res://scripts/material_appearance_lut.gd"),
			"palette": FileAccess.get_sha256("res://shaders/material_palette.gdshader"),
			"emission": FileAccess.get_sha256("res://shaders/material_emission.gdshader"),
			"glow_composite": FileAccess.get_sha256("res://shaders/glow_composite.gdshader")},
		"inputs": [], "captures": []}
	if mode == "combined" or mode == "both":
		var combined: Dictionary = Adapter.build_combined(loaded.pack)
		if not combined.ok:
			_status(2, combined.error)
			return
		if not _save_input(combined, "inputs/combined.rg8"):
			_status(5, "cannot persist/verify combined RG8")
			return
		var rendered: Dictionary = await _render_rg8(combined)
		if not rendered.ok:
			_status(4, "combined renderer: " + rendered.error)
			return
		if not _save_png(rendered.image, "combined.png", "combined viewport render",
			{"tiles": rendered.tiles, "world_origin": [0, 0]}):
			_status(5, "cannot save combined PNG")
			return
		if not _details(rendered.image, info):
			_status(5, "cannot save combined detail crops")
			return
	if mode == "individual" or mode == "both":
		for feature: Dictionary in loaded.pack.features:
			var feature_id: String = feature.id
			var standalone: Dictionary = Adapter.build_feature(loaded.pack, feature_id)
			if not standalone.ok:
				_status(2, standalone.error)
				return
			if not _save_input(standalone, "inputs/%s.rg8" % feature_id):
				_status(5, "cannot persist/verify feature RG8: " + feature_id)
				return
			var rendered: Dictionary = await _render_rg8(standalone)
			if not rendered.ok:
				_status(4, "feature %s renderer: %s" % [feature_id, rendered.error])
				return
			if not _save_png(rendered.image, "features/%s.png" % feature_id,
				"standalone feature viewport render", {"variant": "base"}):
				_status(5, "cannot save feature PNG: " + feature_id)
				return
	if not _publish_capture():
		_status(5, "failed to verify/publish isolated capture; incomplete staging retained")
		return
	_status(0, "published verified genuine Godot framebuffer captures in " + output_path)
