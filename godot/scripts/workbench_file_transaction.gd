extends RefCounted

# Already-validated authored/capture JSON documents only. Keep validation and
# directory/naming policy in each owning format. This helper establishes one
# complete closed staging file, then reuses the accepted native sibling-file
# replacement primitive. It does not serialize live simulation state or promise
# fsync/power-loss durability. The material-baseline writer retains its own path.
#
# FileOperations is the injectable I/O boundary for deterministic fault tests;
# production callers use the default instance, never environment fault switches.
class FileOperations extends RefCounted:
	func replacement_bridge() -> Object:
		if not ClassDB.class_exists(&"CyberDemoBridge"): return null
		return ClassDB.instantiate(&"CyberDemoBridge")

	func random_suffix() -> String:
		return Crypto.new().generate_random_bytes(16).hex_encode()

	func exists(path: String) -> bool:
		var directory := DirAccess.open(path.get_base_dir())
		return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) \
			or (directory != null and directory.is_link(path.get_file()))

	func create(path: String) -> FileAccess:
		return FileAccess.open(path, FileAccess.WRITE)

	func store(file: FileAccess, bytes: PackedByteArray) -> bool:
		return file.store_buffer(bytes)

	func flush(file: FileAccess) -> Error:
		file.flush()
		return file.get_error()

	func close(file: FileAccess) -> Error:
		# Godot 4.7 exposes no fclose result. Verify the closed file below;
		# get_error alone also does not report every buffered fflush failure.
		file.close()
		return OK

	func verify(path: String, expected: PackedByteArray) -> String:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null: return "Cannot reopen the staged file for verification."
		if file.get_length() != expected.size():
			file.close()
			return "The staged file is incomplete; check free space and write permissions."
		var observed := file.get_buffer(expected.size())
		var state := file.get_error()
		file.close()
		if (state != OK and state != ERR_FILE_EOF) or observed != expected:
			return "The staged bytes failed verification; the file was not committed."
		return ""

	func replace(bridge: Object, staging: String, target: String) -> Dictionary:
		return bridge.call(&"replace_material_baseline_file", staging, target)

	func remove(path: String) -> Error:
		return DirAccess.remove_absolute(path)


static func _refused(io: FileOperations, phase: String, reason: String,
		staging: String = "") -> Dictionary:
	var cleanup := ""
	if not staging.is_empty() and io.exists(staging):
		if io.remove(staging) != OK:
			cleanup = " Temporary file remains at " + staging + "; it is not a committed file."
	return {"ok":false, "committed":false, "phase":phase,
		"error":"Save refused; this save did not replace the previous file. " + reason + cleanup,
		"staging_retained":staging if not cleanup.is_empty() else ""}


static func write_text(path: String, text: String, byte_limit: int,
		io: FileOperations = null) -> Dictionary:
	if io == null: io = FileOperations.new()
	var target := ProjectSettings.globalize_path(path)
	var embedded_nul := false
	for index: int in path.length():
		if path.unicode_at(index) == 0: embedded_nul = true
	if path.is_empty() or embedded_nul or not target.is_absolute_path() \
			or target.ends_with("/") or target.ends_with("\\"):
		return _refused(io, "validate", "Choose an absolute file path with a file name.")
	target = target.simplify_path()
	var bytes := text.to_utf8_buffer()
	if byte_limit <= 0 or bytes.is_empty() or bytes.size() > byte_limit:
		return _refused(io, "validate", "The document exceeds its bounded file budget or is empty.")
	var bridge := io.replacement_bridge()
	if bridge == null or not bridge.has_method(&"replace_material_baseline_file"):
		return _refused(io, "capability", "This runtime lacks safe file replacement; use a source-matched native build.")
	# Calls in one Workbench are synchronous. Random sibling names keep separate
	# processes from sharing a staging file; complete concurrent commits remain
	# last-writer-wins. This is not a cross-process edit/locking protocol.
	var staging := ""
	for attempt: int in 8:
		var suffix := io.random_suffix()
		if suffix.length() != 32 or not suffix.is_valid_hex_number():
			return _refused(io, "stage-name", "Could not obtain a safe temporary file name.")
		var candidate := target + "." + suffix + ".tmp"
		if not io.exists(candidate):
			staging = candidate
			break
	if staging.is_empty():
		return _refused(io, "stage-name", "Temporary file names are already in use; retry the save.")
	var file := io.create(staging)
	if file == null:
		return _refused(io, "create", "Cannot create a temporary file in the selected directory.")
	var stored := io.store(file, bytes)
	var state := io.flush(file)
	var closed := io.close(file)
	if not stored or state != OK or closed != OK:
		return _refused(io, "write", "The temporary write could not be completed.", staging)
	var verification := io.verify(staging, bytes)
	if not verification.is_empty():
		return _refused(io, "verify", verification, staging)
	# Never use DirAccess.rename_absolute here: the pinned Windows implementation
	# removes the destination before moving the source. The native primitive
	# refuses directory/link collisions and uses one same-directory replacement.
	var replaced := io.replace(bridge, staging, target)
	if not replaced.get("ok", false):
		return _refused(io, "replace", str(replaced.get("error", "Native replacement failed.")), staging)
	return {"ok":true, "committed":true, "phase":"committed", "error":"", "staging_retained":""}
