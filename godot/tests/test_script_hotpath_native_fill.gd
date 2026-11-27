extends SceneTree

# SCRIPT-HOTPATH-001: compare the compiled GDExtension and the exact GDScript
# PAINT oracle. Test with a freshly rebuilt source-matched native library.
const Shapes = preload("res://scripts/workbench_paint_editor_shapes.gd")

var checks := 0
var failures: Array[String] = []
var native: Object

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("SCRIPT_HOTPATH " + label)

func compare(label: String, expected: Dictionary, actual: Dictionary) -> void:
	check(expected.keys().size() == actual.keys().size(), label + " key count")
	for key: Variant in expected:
		check(actual.has(key), label + " missing " + str(key))
		if actual.has(key):
			check(actual[key] == expected[key], label + " mismatch " + str(key))

func case(label: String, seed: Vector2i, origin: Vector2i, size: Vector2i,
		materials: PackedInt32Array, extent: Vector2i, limit: int = 262144) -> void:
	var original: Dictionary = Shapes.fill_connected_reference(
		seed, origin, size, materials, extent, limit)
	var compiled: Dictionary = native.fill_connected(
		seed, origin, size, materials, extent, limit)
	compare(label + " native", original, compiled)
	compare(label + " dispatch", original,
		Shapes.fill_connected(seed, origin, size, materials, extent, limit))

func grid(width: int, height: int, value: int) -> PackedInt32Array:
	var values := PackedInt32Array()
	values.resize(width * height)
	values.fill(value)
	return values

func run() -> void:
	if not ClassDB.class_exists(&"CyberNativePaintPlanner"):
		check(false, "new CyberNativePaintPlanner absent (rebuild the GDExtension)")
		print("SCRIPT_HOTPATH_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
		quit(1)
		return
	native = ClassDB.instantiate(&"CyberNativePaintPlanner")
	if native == null or not native.has_method(&"fill_connected") or \
			not native.has_method(&"interface_version"):
		check(false, "native interface absent")
		print("SCRIPT_HOTPATH_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
		quit(1)
		return
	check(int(native.interface_version()) == 1, "native interface version")
	var all := grid(512, 512, 2)
	case("full 262144", Vector2i(256, 256), Vector2i.ZERO,
		Vector2i(512, 512), all, Vector2i(512, 512), 262144)
	case("full budget overflow", Vector2i(256, 256), Vector2i.ZERO,
		Vector2i(512, 512), all, Vector2i(512, 512), 262143)
	case("empty sample", Vector2i.ZERO, Vector2i.ZERO,
		Vector2i(0, 64), PackedInt32Array(), Vector2i(512, 512))
	case("invalid extent", Vector2i(0, 0), Vector2i.ZERO,
		Vector2i(512, 512), all, Vector2i(500, 512))
	case("invalid limit", Vector2i.ZERO, Vector2i.ZERO,
		Vector2i(512, 512), all, Vector2i(512, 512), 0)
	case("outside source", Vector2i(0, 0), Vector2i(500, 0),
		Vector2i(64, 64), grid(64, 64, 2), Vector2i(512, 512))
	case("size mismatch", Vector2i.ZERO, Vector2i.ZERO,
		Vector2i(64, 64), grid(64, 63, 2), Vector2i(512, 512))
	case("seed outside", Vector2i(300, 300), Vector2i.ZERO,
		Vector2i(64, 64), grid(64, 64, 2), Vector2i(512, 512))
	var special := grid(64, 64, 2)
	special[4095] = 10
	case("reserved material", Vector2i(2, 2), Vector2i.ZERO,
		Vector2i(64, 64), special, Vector2i(512, 512))
	special[4095] = -1
	case("negative material", Vector2i(2, 2), Vector2i.ZERO,
		Vector2i(64, 64), special, Vector2i(512, 512))
	special[4095] = 132
	case("out of range material", Vector2i(2, 2), Vector2i.ZERO,
		Vector2i(64, 64), special, Vector2i(512, 512))
	case("unread edges", Vector2i(32, 32), Vector2i(16, 16),
		Vector2i(64, 64), grid(64, 64, 3), Vector2i(512, 512))
	var bordered := grid(128, 128, 1)
	for y: int in range(32, 96):
		for x: int in range(32, 96):
			bordered[y * 128 + x] = 2
	case("exact 4096", Vector2i(64, 64), Vector2i.ZERO,
		Vector2i(128, 128), bordered, Vector2i(512, 512), 4096)
	case("one past 4096", Vector2i(64, 64), Vector2i.ZERO,
		Vector2i(128, 128), bordered, Vector2i(512, 512), 4095)
	bordered[64 * 128 + 96] = 2
	case("4097 component", Vector2i(64, 64), Vector2i.ZERO,
		Vector2i(128, 128), bordered, Vector2i(512, 512), 4096)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	for sample: int in range(24):
		var width := 64 if sample % 2 == 0 else 128
		var height := 128 if sample % 3 == 0 else 64
		var values := grid(width, height, 0)
		for index: int in range(values.size()):
			values[index] = rng.randi_range(0, 4)
		var origin := Vector2i(sample * 3, sample * 5)
		var seed := origin + Vector2i(rng.randi_range(0, width - 1),
			rng.randi_range(0, height - 1))
		case("random %d" % sample, seed, origin, Vector2i(width, height),
			values, Vector2i(512, 512), 100 + sample * 4)
	print("SCRIPT_HOTPATH_RESULT ", JSON.stringify({
		"checks": checks, "failures": failures, "backend_version": native.interface_version()
	}))
	quit(0 if failures.is_empty() else 1)
