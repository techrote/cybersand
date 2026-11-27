extends SceneTree

## Fixed data-only import admission used by the portable launcher. No scene is
## mounted and no proposed corpus action is executed during validation.
const Adapter = preload("res://goblin/goblin_adapter.gd")
const Corpus = preload("res://goblin/goblin_corpus.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")


func _initialize() -> void:
	var profile: Dictionary = Adapter.verify_profile()
	if not profile.get("ok", false):
		print("GOBLIN_CORPUS_IMPORT_REFUSED ", JSON.stringify(profile))
		quit(2)
		return
	var path: String = str(profile.root).path_join("goblin-corpus.json")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Corpus.MAX_BYTES:
		print("GOBLIN_CORPUS_IMPORT_REFUSED missing or oversized fixed corpus")
		quit(2)
		return
	var value: Variant = JSON.parse_string(file.get_as_text())
	var memory := Corpus.new()
	var checked: Dictionary = memory.import_data(value, Transcript.validate_action)
	print("GOBLIN_CORPUS_IMPORT_VALID " if checked.get("ok", false) else "GOBLIN_CORPUS_IMPORT_REFUSED ", JSON.stringify(checked))
	quit(0 if checked.get("ok", false) else 2)
