extends RefCounted

# 4LY-003 final scoring is strictly external and sealed. The public game
# checkout contains no admissible final geometry. A reviewer provides an
# independently authored suite and its committed checksum only AFTER the
# teacher has been frozen. Geometry is evaluator-only and never reaches the
# policy observation or actuator.
const SUITE_PATH: String = "user://4ly003_sealed_final_suite.json"
const ADMISSION_PATH: String = "user://4ly003_final_admission.json"
const VERSION: String = "4ly003-sealed-final-suite/v1"
const MAX_OBSTACLES: int = 16
const MAX_GOALS: int = 3
const MAX_CASES: int = 240
const WORLD_RECT := Rect2i(128, 128, 512, 224)


static func _finite_number(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))


static func _integer(v: Variant, min_value: int, max_value: int) -> bool:
	return _finite_number(v) and float(v) == floorf(float(v)) \
		and int(v) >= min_value and int(v) <= max_value


static func _point(data: Variant) -> Vector2:
	if not data is Array or data.size() != 2 or not _finite_number(data[0]) or not _finite_number(data[1]):
		return Vector2.INF
	var position := Vector2(float(data[0]), float(data[1]))
	if not position.is_finite() or not Rect2(WORLD_RECT).has_point(position):
		return Vector2.INF
	# Leave at least the Hauler half-collider clearance from the perimeter.
	if position.x < 141.0 or position.x > 627.0 or position.y < 144.0 or position.y > 339.0:
		return Vector2.INF
	return position


static func _rect(data: Variant) -> Dictionary:
	if not data is Dictionary or data.size() != 3 \
		or not data.has("origin") or not data.has("size") or not data.has("material") \
		or data.material != 1:
		return {}
	var origin: Variant = data.origin
	var size: Variant = data.size
	if not origin is Array or origin.size() != 2 or not size is Array or size.size() != 2:
		return {}
	if not _integer(origin[0], 132, 634) or not _integer(origin[1], 132, 346) \
		or not _integer(size[0], 1, 250) or not _integer(size[1], 1, 212):
		return {}
	var v_origin := Vector2i(int(origin[0]), int(origin[1]))
	var v_size := Vector2i(int(size[0]), int(size[1]))
	if v_origin.x + v_size.x > 636 or v_origin.y + v_size.y > 348:
		return {}
	return {"origin": v_origin, "size": v_size, "material": 1}


static func resolve(id: String, seed: int, template: Dictionary) -> Dictionary:
	if template.is_empty() or not FileAccess.file_exists(SUITE_PATH) \
		or not FileAccess.file_exists(ADMISSION_PATH):
		return {}
	var raw_suite: String = FileAccess.get_file_as_string(SUITE_PATH)
	var admission: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADMISSION_PATH))
	if not admission is Dictionary or str(admission.get("version", "")) != "4ly003-final-admission/v1" \
		or not bool(admission.get("independent_preflight_accepted", false)) \
		or str(admission.get("reviewer", "")).is_empty() \
		or str(admission.get("suite_sha256", "")).length() != 64 \
		or raw_suite.sha256_text() != str(admission.suite_sha256):
		return {}
	var source: String = OS.get_environment("GITHUB_SHA")
	if source.is_empty() or str(admission.get("source_git_sha", "")) != source:
		return {}
	var suite: Variant = JSON.parse_string(raw_suite)
	if not suite is Dictionary or str(suite.get("version", "")) != VERSION \
		or not suite.get("cases") is Array or suite.cases.is_empty() \
		or suite.cases.size() > MAX_CASES:
		return {}
	var selected: Dictionary = {}
	for candidate: Variant in suite.cases:
		if not candidate is Dictionary or not candidate.has("id") or not candidate.has("seed"):
			return {}
		if not candidate.id is String or not _integer(candidate.seed, 0, 2147483647):
			return {}
		if str(candidate.id) == id and int(candidate.seed) == seed:
			if not selected.is_empty():
				return {} # Duplicate final fixture identity is inadmissible.
			selected = candidate
	if selected.is_empty() or selected.size() != 5 \
		or not selected.has("start") or not selected.has("goals") or not selected.has("obstacles"):
		return {}
	var start: Vector2 = _point(selected.start)
	if not start.is_finite() or not selected.goals is Array \
		or selected.goals.is_empty() or selected.goals.size() > MAX_GOALS:
		return {}
	var goals: Array[Vector2] = []
	for value: Variant in selected.goals:
		var target: Vector2 = _point(value)
		if not target.is_finite():
			return {}
		goals.append(target)
	if not selected.obstacles is Array or selected.obstacles.size() > MAX_OBSTACLES:
		return {}
	var obstacles: Array = []
	for item: Variant in selected.obstacles:
		var rect: Dictionary = _rect(item)
		if rect.is_empty():
			return {}
		obstacles.append(rect)
	var result: Dictionary = template.duplicate(true)
	result["start"] = start
	result["goals"] = goals
	result["obstacles"] = obstacles
	result["split"] = "final"
	result["sealed_source"] = "externally_admitted_sha256_only"
	result["sealed_suite_sha256"] = str(admission.suite_sha256)
	return result
