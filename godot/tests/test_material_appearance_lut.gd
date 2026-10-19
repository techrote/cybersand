extends SceneTree

# Focused startup-compiler check for the themed palette and bounded flair
# programs. This validates texture layout and representative rows without
# depending on a rendered screenshot or authoritative simulation state.

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		CyberMaterialAppearanceLut.BASE_RGBA8.size() == CyberMaterialAppearanceLut.MATERIAL_COUNT,
		"base palette and material count diverged"
	)
	_expect(
		CyberMaterialAppearanceLut.VALUE_VARIATION.size() == CyberMaterialAppearanceLut.MATERIAL_COUNT,
		"variation table and material count diverged"
	)
	_expect(CyberMaterialAppearanceLut.MATERIAL_COUNT == 132, "building material extent changed")
	_expect(
		CyberMaterialAppearanceLut.MATERIAL_COUNT == CyberCellWorld.LAST_MATERIAL + 1 and
			CyberCellWorld.BUILDING_MATERIAL_NAMES.size() ==
			CyberCellWorld.LAST_MATERIAL - CyberCellWorld.FIRST_BUILDING_MATERIAL + 1,
		"fallback catalogue and appearance extent diverged"
	)
	_expect(
		CyberMaterialAppearanceLut.FLAIR_CLASS_COUNT == 50,
		"expanded GPU flair class count changed"
	)
	_expect(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 1920 and
			int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 1080,
		"default output viewport is not 1920x1080"
	)

	var atlas: Image = CyberMaterialAppearanceLut.create_texture().get_image()
	_expect(
		atlas.get_width() == 64 and atlas.get_height() == 256,
		"palette atlas dimensions changed"
	)
	var limestone_dark: Color = atlas.get_pixel(0, CyberCellWorld.LIMESTONE_BLOCK)
	var limestone_light: Color = atlas.get_pixel(63, CyberCellWorld.LIMESTONE_BLOCK)
	_expect(
		limestone_light.get_luminance() - limestone_dark.get_luminance() > 0.09,
		"expanded solid texture contrast is too small"
	)

	var programs: Image = CyberMaterialAppearanceLut.create_program_texture().get_image()
	_expect(
		programs.get_width() == 4 and programs.get_height() == 256,
		"appearance program dimensions changed"
	)
	# Exercise the complete byte address space. An unassigned catalogue row
	# must be explicit magenta, with a neutral, finite, non-emitting program;
	# every defined ID must have a usable row, not just the selected examples.
	for material_id: int in range(256):
		var invalid: bool = material_id == 10 or material_id >= CyberMaterialAppearanceLut.MATERIAL_COUNT
		for variant: int in range(CyberMaterialAppearanceLut.ATLAS_WIDTH):
			var colour: Color = atlas.get_pixel(variant, material_id)
			if invalid:
				_expect(colour == Color(1, 0, 1, 1),
					"invalid ID %d variant %d lacks the explicit fallback" % [material_id, variant])
			elif material_id != CyberCellWorld.EMPTY:
				_expect(colour != Color(1, 0, 1, 1) and colour.a > 0.0,
					"defined ID %d variant %d lacks a visible palette row" % [material_id, variant])
		for instruction: int in range(4):
			var value: Color = programs.get_pixel(instruction, material_id)
			_expect(Vector4(value.r, value.g, value.b, value.a).is_finite(),
				"material %d instruction %d contains a non-finite parameter" % [material_id, instruction])
		var curve: Color = programs.get_pixel(1, material_id)
		_expect(curve.g > curve.r, "material %d has an undefined smoothstep range" % material_id)
		var emission: Color = programs.get_pixel(3, material_id)
		_expect(emission.a == float(roundi(emission.a)) and emission.a >= 0.0 and
			emission.a <= float(CyberMaterialAppearanceLut.FLAIR_CLASS_COUNT),
			"material %d has an invalid flair selector" % material_id)
		if invalid or material_id == CyberCellWorld.EMPTY:
			var response: Color = programs.get_pixel(2, material_id)
			_expect(response.b == 0.0 and response.a == 0.0 and emission == Color(0, 0, 0, 0),
				"empty/invalid material %d can emit light or select a finish" % material_id)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.RED_BRICK).a) ==
			CyberMaterialAppearanceLut.FLAIR_MASONRY,
		"brick did not compile to masonry flair"
	)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.CORRUGATED_STEEL).a) ==
			CyberMaterialAppearanceLut.FLAIR_CORRUGATED,
		"corrugated steel did not compile to corrugation flair"
	)
	_expect(
		programs.get_pixel(2, CyberCellWorld.SMOKE).r < 0.2 and
			programs.get_pixel(2, CyberCellWorld.SMOKE).g >= 1.0,
		"smoke lifetime did not compile to a long fade curve"
	)
	# The former shared wet finish is split by family (material readability pass).
	var wet_family: Dictionary = {
		CyberCellWorld.OIL: CyberMaterialAppearanceLut.FLAIR_OIL,
		CyberCellWorld.PASTE: CyberMaterialAppearanceLut.FLAIR_PASTE,
		CyberCellWorld.CEMENT: CyberMaterialAppearanceLut.FLAIR_PASTE,
		CyberCellWorld.SLUSH: CyberMaterialAppearanceLut.FLAIR_SLUSH,
		CyberCellWorld.BRINE: CyberMaterialAppearanceLut.FLAIR_WATER,
		CyberCellWorld.WATER: CyberMaterialAppearanceLut.FLAIR_WATER,
		CyberCellWorld.WET_ASPHALT: CyberMaterialAppearanceLut.FLAIR_WET_SURFACE,
		CyberCellWorld.WET_COBBLESTONE: CyberMaterialAppearanceLut.FLAIR_WET_SURFACE,
	}
	for liquid_id: int in wet_family:
		_expect(
			roundi(programs.get_pixel(3, liquid_id).a) == int(wet_family[liquid_id]),
			"material %d did not compile to its wet-family flair" % liquid_id
		)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.SMOKE).a) ==
			CyberMaterialAppearanceLut.FLAIR_SMOKE and
			roundi(programs.get_pixel(3, CyberCellWorld.STEAM).a) ==
			CyberMaterialAppearanceLut.FLAIR_STEAM and
			roundi(programs.get_pixel(3, CyberCellWorld.FOAM).a) ==
			CyberMaterialAppearanceLut.FLAIR_FOAM,
		"gas/foam special-effect programs were not compiled"
	)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.ACID).a) ==
			CyberMaterialAppearanceLut.FLAIR_REACTIVE_LIQUID and
			roundi(programs.get_pixel(3, CyberCellWorld.TOXIC_SLUDGE).a) ==
			CyberMaterialAppearanceLut.FLAIR_REACTIVE_LIQUID and
			roundi(programs.get_pixel(3, CyberCellWorld.MERCURY).a) ==
			CyberMaterialAppearanceLut.FLAIR_MERCURY,
		"reactive/metallic liquid programs were not specialized"
	)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.METAL).a) ==
			CyberMaterialAppearanceLut.FLAIR_CHARGED_METAL and
			roundi(programs.get_pixel(3, CyberCellWorld.CLONER).a) ==
			CyberMaterialAppearanceLut.FLAIR_CLONER,
		"condition-driven manufactured effects were not compiled"
	)
	_expect(
		roundi(programs.get_pixel(3, CyberCellWorld.NEON_CYAN).a) ==
			CyberMaterialAppearanceLut.FLAIR_NEON,
		"neon did not compile to animated flair"
	)
	_expect(
		programs.get_pixel(3, CyberCellWorld.NEON_CYAN).g > 1.0,
		"neon HDR emission was clamped"
	)
	_expect(
		CyberCellWorld.new().is_character_solid(CyberCellWorld.STEEL_GRATING),
		"fallback collision does not recognize themed hard surfaces"
	)
	# Second fidelity pass: living/firework finishes and the building catalogue.
	var living: Dictionary = {
		CyberCellWorld.PLANT: CyberMaterialAppearanceLut.FLAIR_PLANT,
		CyberCellWorld.FUNGUS: CyberMaterialAppearanceLut.FLAIR_FUNGUS,
		CyberCellWorld.MITE: CyberMaterialAppearanceLut.FLAIR_MITE,
		CyberCellWorld.ROCKET: CyberMaterialAppearanceLut.FLAIR_ROCKET,
		CyberCellWorld.SEED: CyberMaterialAppearanceLut.FLAIR_ORGANIC,
	}
	for living_id: int in living:
		_expect(roundi(programs.get_pixel(3, living_id).a) == int(living[living_id]),
			"material %d did not compile to its living/firework flair" % living_id)
	for building_id: int in range(CyberCellWorld.FIRST_BUILDING_MATERIAL, CyberCellWorld.LAST_MATERIAL + 1):
		_expect(roundi(programs.get_pixel(3, building_id).a) == CyberMaterialAppearanceLut.FLAIR_BUILDING,
			"building material %d did not compile to the building flair" % building_id)
		_expect(atlas.get_pixel(32, building_id).to_rgba32() != Color(1.0, 0.0, 1.0, 1.0).to_rgba32(),
			"building material %d has no palette row" % building_id)
		_expect(CyberCellWorld.new().is_character_solid(building_id),
			"fallback collision does not recognize building material %d" % building_id)
	# An idle Rocket emits nothing; any flight state (byte >= 1) blooms.
	_expect(programs.get_pixel(2, CyberCellWorld.ROCKET).b == 0.0 and
		programs.get_pixel(2, CyberCellWorld.ROCKET).a > 1.0 and
		programs.get_pixel(1, CyberCellWorld.ROCKET).g <= 1.0 / 255.0 + 0.001,
		"activated firework emission curve is wrong")
	# Woods/fibres burn through the shared condition curve.
	_expect(programs.get_pixel(2, CyberCellWorld.PINE_PLANKS).a > 0.1 and
		programs.get_pixel(0, CyberCellWorld.PINE_PLANKS).a > 0.5,
		"building combustible lacks a burn appearance curve")
	var sludge: Color = atlas.get_pixel(32, CyberCellWorld.TOXIC_SLUDGE)
	_expect(sludge.g > sludge.r and sludge.g > sludge.b and sludge.v < 0.5,
		"toxic sludge is not a deep, dark green")
	var steam: Color = atlas.get_pixel(32, CyberCellWorld.STEAM)
	_expect(steam.s < 0.08 and steam.v > 0.9, "steam is not a near-white vapour")
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		var native_world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
		for material_id: int in range(CyberCellWorld.LAST_MATERIAL + 1):
			if material_id == 10:
				continue
			var location := Vector2i(500 + (material_id % 22) * 2, 300 + (material_id / 22) * 2)
			native_world.emit_disc(location.x, location.y, 0, material_id)
			_expect(int(native_world.material_at(location.x, location.y)) == material_id,
				"bundled native extension rejected catalogue material %d" % material_id)
		var hard_revision_before: int = int(native_world.get_hard_surface_revision())
		native_world.emit_disc(500, 300, 0, CyberCellWorld.REINFORCED_CONCRETE)
		_expect(
			int(native_world.material_at(500, 300)) == CyberCellWorld.REINFORCED_CONCRETE,
			"bundled native extension rejected a themed material ID"
		)
		_expect(
			int(native_world.get_hard_surface_revision()) > hard_revision_before,
			"native themed solid did not invalidate hard-surface geometry"
		)
		var hard_chunks: PackedInt32Array = native_world.get_hard_surface_chunk_rectangles()
		_expect(
			not hard_chunks.is_empty() and hard_chunks[0] == 256,
			"hard-surface collision was not partitioned into bounded 64x64 chunks"
		)

	if _failures == 0:
		print("Material appearance LUT regression passed; all 132 ID slots, 256 palette/program rows, 50 flair classes")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
