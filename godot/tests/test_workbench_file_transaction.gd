extends SceneTree

const Transaction = preload("res://scripts/workbench_file_transaction.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const OLD := "{\"version\":1,\"value\":\"old complete document\"}"
const NEW := "{\"version\":1,\"value\":\"new complete document\"}"

class FaultIO extends Transaction.FileOperations:
	var fault := ""
	var staging := ""
	var replace_calls := 0
	var create_calls := 0
	var forced_suffix := ""

	func replacement_bridge() -> Object:
		return null if fault == "capability" else super.replacement_bridge()

	func random_suffix() -> String:
		return forced_suffix if not forced_suffix.is_empty() else super.random_suffix()

	func create(path: String) -> FileAccess:
		create_calls += 1
		staging = path
		return null if fault == "create" else super.create(path)

	func store(file: FileAccess, bytes: PackedByteArray) -> bool:
		if fault in ["write", "silent-truncate"]:
			file.store_buffer(bytes.slice(0, 7))
			return fault == "silent-truncate"
		if fault == "same-length-corruption":
			var corrupt := bytes.duplicate()
			corrupt[0] = 33
			return super.store(file, corrupt)
		return super.store(file, bytes)

	func flush(file: FileAccess) -> Error:
		var result := super.flush(file)
		return ERR_FILE_CANT_WRITE if fault == "flush" else result

	func close(file: FileAccess) -> Error:
		var result := super.close(file)
		return ERR_FILE_CANT_WRITE if fault == "close" else result

	func verify(path: String, expected: PackedByteArray) -> String:
		return "Injected readback-open failure." if fault == "verify" else super.verify(path, expected)

	func replace(bridge: Object, source: String, target: String) -> Dictionary:
		replace_calls += 1
		if fault in ["replace", "cleanup"]:
			return {"ok":false, "error":"Injected native replacement refusal."}
		return super.replace(bridge, source, target)

	func remove(path: String) -> Error:
		return ERR_BUSY if fault == "cleanup" else super.remove(path)

var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FILE_TRANSACTION: " + label)

func put(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "fixture file opened")
	if file != null:
		check(file.store_string(content), "fixture bytes written")
		file.close()

func run() -> void:
	var directory := ProjectSettings.globalize_path("user://file-transaction-tests")
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "disposable directory exists")
	var target := directory.path_join("named.json")
	put(target, OLD)
	var old_sha := FileAccess.get_sha256(target)
	for fault: String in ["capability", "create", "write", "silent-truncate",
			"same-length-corruption", "flush", "close", "verify", "replace", "cleanup"]:
		var io := FaultIO.new()
		io.fault = fault
		var result := Transaction.write_text(target, NEW, 1024, io)
		check(not result.ok and not result.committed, fault + " explicitly refuses")
		check(FileAccess.get_sha256(target) == old_sha, fault + " preserves old bytes")
		check(result.error.contains("did not replace"), fault + " truthful failure text")
		if fault in ["replace", "cleanup"]:
			check(io.replace_calls == 1, fault + " reaches commit boundary")
		else:
			check(io.replace_calls == 0, fault + " never reaches commit boundary")
		if fault == "cleanup":
			check(result.staging_retained == io.staging and FileAccess.file_exists(io.staging), "cleanup refusal identifies retained staging")
			check(result.error.contains(io.staging), "retained staging is visible in failure feedback")
			DirAccess.remove_absolute(io.staging)
		elif not io.staging.is_empty():
			check(not FileAccess.file_exists(io.staging), fault + " cleans only its own staging")
		cases.append({"kind":"injected", "fault":fault, "phase":result.phase,
			"old_sha256":old_sha, "after_sha256":FileAccess.get_sha256(target),
			"replacement_calls":io.replace_calls})
	# Collision refuses without opening or cleaning somebody else's file.
	var collision := FaultIO.new()
	collision.forced_suffix = "1234567890abcdef1234567890abcdef"
	var stale := target + "." + collision.forced_suffix + ".tmp"
	put(stale, "unrelated stale staging bytes")
	var stale_sha := FileAccess.get_sha256(stale)
	var refused := Transaction.write_text(target, NEW, 1024, collision)
	check(not refused.ok and refused.phase == "stage-name", "staging collision refuses")
	check(collision.create_calls == 0 and FileAccess.get_sha256(stale) == stale_sha, "collision never truncates or deletes existing staging")
	if OS.get_name() == "Linux":
		DirAccess.remove_absolute(stale)
		check(DirAccess.open(directory).create_link(target, stale) == OK, "pre-existing staging symlink prepared")
		refused = Transaction.write_text(target, NEW, 1024, collision)
		check(not refused.ok and refused.phase == "stage-name" and collision.create_calls == 0, "staging symlink is never opened or removed")
		check(FileAccess.get_sha256(target) == old_sha and DirAccess.open(directory).is_link(stale.get_file()), "staging symlink and its destination remain unchanged")
		DirAccess.remove_absolute(stale)
		put(stale, "unrelated stale staging bytes")
		check(FileAccess.get_sha256(stale) == stale_sha, "stale regular fixture restored")
	var saved := Transaction.write_text(target, NEW, 1024)
	check(saved.ok and saved.committed and saved.error.is_empty(), "native normal replacement succeeds")
	check(FileAccess.get_file_as_string(target) == NEW, "native replacement publishes complete new bytes")
	check(FileAccess.get_sha256(stale) == stale_sha, "success leaves unrelated stale file intact")
	var fresh := directory.path_join("fresh-水.json")
	DirAccess.remove_absolute(fresh)
	saved = Transaction.write_text(fresh, NEW, 1024)
	check(saved.ok and FileAccess.get_file_as_string(fresh) == NEW, "new Unicode-named file succeeds")
	var missing := directory.path_join("missing-parent/file.json")
	refused = Transaction.write_text(missing, NEW, 1024)
	check(not refused.ok and refused.phase == "create" and not FileAccess.file_exists(missing), "actual missing directory refuses")
	var occupied := directory.path_join("occupied.json")
	check(DirAccess.make_dir_recursive_absolute(occupied) == OK, "directory collision prepared")
	put(occupied.path_join("keep.txt"), OLD)
	refused = Transaction.write_text(occupied, NEW, 1024)
	check(not refused.ok and refused.phase == "replace", "actual native directory collision refuses")
	check(FileAccess.get_file_as_string(occupied.path_join("keep.txt")) == OLD, "directory collision preserves contents")
	for invalid: String in ["", "relative.json", directory + "/"]:
		refused = Transaction.write_text(invalid, NEW, 1024)
		check(not refused.ok and refused.phase == "validate", "invalid path refused: " + invalid)
	refused = Transaction.write_text(target, NEW, 3)
	check(not refused.ok and refused.phase == "validate", "bounded payload limit precedes I/O")
	for label: String in ["../escape", "a/b", "", "x".repeat(49)]:
		check(Setup._path(label).is_empty(), "named-save path traversal/invalid name rejected")
	# Actual endpoint symlink refusal. The POSIX test does not stand in for
	# Windows reparse-point execution; native Windows qualification runs there.
	if OS.get_name() == "Linux":
		var link := directory.path_join("link.json")
		DirAccess.remove_absolute(link)
		check(DirAccess.open(directory).create_link(fresh, link) == OK, "symlink fixture created")
		refused = Transaction.write_text(link, OLD, 1024)
		check(not refused.ok and refused.phase == "replace", "actual native symlink collision refuses")
		check(FileAccess.get_file_as_string(fresh) == NEW and DirAccess.open(directory).is_link(link.get_file()), "symlink target and link preserved")
		DirAccess.remove_absolute(link)
	print("FILE_TRANSACTION_RESULT ", JSON.stringify({"schema":1, "checks":checks,
		"failures":failures, "cases":cases, "platform":OS.get_name(),
		"native_commit":"CyberDemoBridge.replace_material_baseline_file"}))
	quit(0 if failures.is_empty() else 1)
