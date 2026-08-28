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
	_expect(CyberMaterialAppearanceLut.MATERIAL_COUNT == 81, "themed material extent changed")
	_expect(
		CyberMaterialAppearanceLut.FLAIR_CLASS_COUNT == 42,
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
	for liquid_id: int in [
		CyberCellWorld.OIL,
		CyberCellWorld.PASTE,
		CyberCellWorld.SLUSH,
		CyberCellWorld.BRINE,
		CyberCellWorld.CEMENT,
	]:
		_expect(
			roundi(programs.get_pixel(3, liquid_id).a) ==
				CyberMaterialAppearanceLut.FLAIR_WET,
			"liquid %d did not compile to animated flow flair" % liquid_id
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
	_expect(ClassDB.class_exists(&"CyberNativeCellWorld"), "native world is unavailable")
	if ClassDB.class_exists(&"CyberNativeCellWorld"):
		var native_world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
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
		print("Material appearance LUT regression passed; 81 IDs and 42 flair classes")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
