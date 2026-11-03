extends "res://tests/play_pace003_palette_atlas.gd"

# Preserve the original atlas and comparator byte-for-byte. This adapter adds
# only actual process/backend custody before the inherited isolated render.
const Context = preload("res://tests/palette_qualification_context.gd")

func _run() -> void:
	Context.emit(get_script().resource_path)
	await super._run()
