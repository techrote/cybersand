extends SceneTree
# Exact PR #454 pack-geometry qualification. Requires a separate READ-ONLY
# export of its docs/world-design directory; does not render or simulate.
# godot --headless --path godot --script res://tests/check_world_design_pack_oracle.gd -- \
#    --packs=/absolute/PR454/docs/world-design --design-revision=<exact PR head>

const Adapter = preload("res://tools/world_design_pack_adapter.gd")
const EXPECTED_REVISION: String = "f68516b7e4faefb8c776a89169365a7e8dd55d37"
var packs_dir: String = ""
var design_revision: String = ""
var expected_path: String = "res://tools/world_design_pack_expected_rg8_20261105.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--packs="):
			packs_dir = argument.trim_prefix("--packs=")
		elif argument.begins_with("--design-revision="):
			design_revision = argument.trim_prefix("--design-revision=")
		elif argument.begins_with("--oracle="):
			expected_path = argument.trim_prefix("--oracle=")
		else:
			push_error("WORLD_PACK_ORACLE: unknown argument " + argument)
			quit(2)
			return
	if packs_dir.is_empty() or design_revision != EXPECTED_REVISION:
		push_error("WORLD_PACK_ORACLE: require --packs and exact PR454 --design-revision=" +
			EXPECTED_REVISION + " (cannot compare moving pack heads to frozen oracles)")
		quit(2)
		return
	if not FileAccess.file_exists(expected_path):
		push_error("WORLD_PACK_ORACLE: missing oracle file")
		quit(2)
		return
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(expected_path)) != OK:
		push_error("WORLD_PACK_ORACLE: invalid oracle JSON")
		quit(2)
		return
	var record: Variant = parser.data
	if typeof(record) != TYPE_DICTIONARY or record.get("design_revision") != design_revision:
		push_error("WORLD_PACK_ORACLE: oracle source does not match exact design revision")
		quit(2)
		return
	var passed: int = 0
	var failed: int = 0
	var expected: Array = record.get("entries", [])
	for entry: Variant in expected:
		var slug: String = entry.get("collection", "")
		var path: String = packs_dir.path_join(slug).path_join("pack.json")
		if not FileAccess.file_exists(path):
			push_error("WORLD_PACK_ORACLE: missing " + path)
			failed += 1
			continue
		var source: String = FileAccess.get_file_as_string(path)
		var json: JSON = JSON.new()
		if json.parse(source) != OK:
			push_error("WORLD_PACK_ORACLE: invalid JSON " + path)
			failed += 1
			continue
		var built: Dictionary = Adapter.build_combined(json.data)
		if not built.ok:
			push_error("WORLD_PACK_ORACLE: " + slug + ": " + built.error)
			failed += 1
			continue
		var expected_size: Array = entry["dimensions_cells"]
		var size_ok: bool = built["size"] == Vector2i(expected_size[0], expected_size[1])
		var sha_ok: bool = built.rg8_sha256 == entry.get("rg8_sha256", "")
		var bytes_ok: bool = built.rg8_bytes == entry.get("rg8_bytes", -1)
		if size_ok and sha_ok and bytes_ok:
			passed += 1
			print("WORLD_PACK_ORACLE: PASS ", slug, " rg8_sha256=", built.rg8_sha256)
		else:
			failed += 1
			push_error("WORLD_PACK_ORACLE: mismatch " + slug + " size=" +
				str(built["size"]) + " sha256=" + built.rg8_sha256 + " bytes=" +
				str(built.rg8_bytes))
	var total: int = expected.size()
	print("WORLD_PACK_ORACLE: expected=%d passed=%d failed=%d design=%s" % [
		total, passed, failed, design_revision])
	quit(0 if total == 15 and passed == total and failed == 0 else 1)
