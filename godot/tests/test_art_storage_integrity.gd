extends SceneTree

const Archive = preload("res://scripts/art_traffic_archive.gd")
const Provider = preload("res://scripts/art_provider.gd")
var checks := 0
var failures: Array[String] = []
var prefix := ""

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func verify(path: String, offset: int, length: int, digest: String) -> RefCounted:
	var reader := Archive.ClosedFileVerification.new(path, offset, length, digest)
	while not reader.done: reader.step(97)
	return reader

func _run() -> void:
	prefix = "user://art-storage-" + Crypto.new().generate_random_bytes(8).hex_encode()
	var path := prefix + ".jsonl"
	var original := "immutable prefix\n"
	var suffix := "complete-record-".repeat(400)
	write(path, original + suffix)
	var reader := Archive.ClosedFileVerification.new(path, original.length(), original.length()+suffix.length(), suffix.sha256_text())
	check(not reader.done, "closed verification does not invent a completed read")
	reader.step(17)
	check(not reader.done, "bounded verification yields before the complete region is read")
	while not reader.done: reader.step(113)
	check(reader.error.is_empty(), "exact appended region verifies without copying the prior archive")
	check(not verify(path, 0, 2, "wrong").error.is_empty(), "malformed digest refused")
	check(not verify(path, -1, 2, suffix.sha256_text()).error.is_empty(), "negative region refused")
	check(not verify(path, 20, 10, suffix.sha256_text()).error.is_empty(), "reversed region refused")
	check(not verify(path, 0, original.length()+suffix.length()+1, suffix.sha256_text()).error.is_empty(), "truncated closed length refused")
	write(path, original + suffix.replace("complete", "modified"))
	check(not verify(path, original.length(), original.length()+suffix.length(), suffix.sha256_text()).error.is_empty(), "same-length corrupted region refused by digest")
	write(path, original + suffix)
	reader = Archive.ClosedFileVerification.new(path, 0, original.length()+suffix.length(), (original+suffix).sha256_text())
	reader.step(17)
	var append := FileAccess.open(path, FileAccess.READ_WRITE)
	append.seek_end()
	append.store_string("unverified tail")
	append.close()
	while not reader.done: reader.step(113)
	check(not reader.error.is_empty(), "growth during cooperative verification refused")
	check(not verify(prefix + "-missing", 0, 1, suffix.sha256_text()).error.is_empty(), "missing closed file refused")
	DirAccess.make_dir_recursive_absolute("user://art-traffic")
	var source := "user://art-traffic/storage-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".jsonl"
	var content := JSON.stringify({"kind":"conversation","data":{"role":"user","content":suffix}}) + "\n"
	write(source, content)
	write(path, "previous valid destination\n")
	var before := FileAccess.get_sha256(path)
	var provider := Provider.new()
	root.add_child(provider)
	provider.prepare_resume(source)
	check(provider.begin_export(path) == OK, "export starts without modifying destination")
	var attempts := 0
	while provider.export_active and provider.get("_export_verifier") == null and attempts < 100:
		provider.poll_export(256)
		attempts += 1
	check(provider.export_active and provider.get("_export_verifier") != null, "export enters explicit closed verification before commit")
	check(FileAccess.get_sha256(path) == before, "destination preserved before verification completes")
	provider.cancel_export()
	check(not provider.export_active and provider.export_error == ERR_SKIP and FileAccess.get_sha256(path) == before, "cancel during verification preserves old destination")
	check(provider.export_traffic(path) == OK and FileAccess.get_file_as_string(path) == content, "normal verified export keeps exact source bytes")
	write(path, "previous valid destination\n")
	check(provider.begin_export(path) == OK, "second export starts")
	attempts = 0
	while provider.export_active and provider.get("_export_verifier") == null and attempts < 100:
		provider.poll_export(256)
		attempts += 1
	var temporary: String = provider.get("_export_temporary")
	var changed := FileAccess.open(temporary, FileAccess.READ_WRITE)
	changed.store_8(88)
	changed.close()
	while provider.export_active: provider.poll_export(256)
	check(provider.export_error != OK and FileAccess.get_sha256(path) == before, "corrupt closed staging bytes never replace prior export")
	check(not FileAccess.file_exists(temporary), "failed export removes its uncommitted staging file")
	check(FileAccess.get_file_as_string(source) == content, "source archive stays byte-identical")
	provider.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(source)
	print("ART_STORAGE_INTEGRITY checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
