extends SceneTree

# Run in a fresh installed project and a copy with BOTH recipe roots absent.
const Dialog = preload("res://scripts/workbench_generator_dialog.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var owner := Control.new()
	root.add_child(owner)
	var dialog := Dialog.new()
	owner.add_child(dialog)
	dialog.mount(owner)
	dialog.open_new()
	var missing := OS.get_environment("WB_GENERATOR_EXPECT_MISSING") == "1"
	if missing:
		check(dialog._profile.item_count == 0, "missing-folder fixture has no hidden checkout recipes")
		check(dialog._preview_button.disabled, "missing profiles disable preview")
		check(dialog._status.text.contains("Reinstall") and dialog._status.text.contains("Choose profile file"), "missing profile diagnosis provides both recovery actions")
	else:
		var files := {}
		for directory: String in [Dialog.PACKAGED_PROFILES, ProjectSettings.globalize_path(Dialog.CHECKOUT_PROFILES)]:
			if not DirAccess.dir_exists_absolute(directory): continue
			for filename: String in DirAccess.get_files_at(directory):
				if filename.ends_with(".json"): files[filename] = true
		check(files.size() >= 2 and files.has("gen007-deepworks.json") and files.has("gen007-qualification.json"), "actual required GEN-007 profiles are installed")
		check(dialog._profile.item_count == files.size(), "dropdown contains every available profile exactly once")
		var expected := OS.get_environment("WB_GENERATOR_PROFILE_COUNT")
		if not expected.is_empty(): check(dialog._profile.item_count == int(expected), "profile count matches packaging manifest")
		check(not dialog._preview_button.disabled, "installed recipes enable preview")
		check(dialog._profile.get_item_text(dialog._profile.selected) == "gen007-deepworks", "Deepworks is selected from actual discovery")
		for i: int in dialog._profile.item_count:
			var path := str(dialog._profile.get_item_metadata(i))
			check(FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary, "readable actual JSON: " + path)
	var manual_path := "user://wb-generator-manual-regression.json"
	var file := FileAccess.open(manual_path, FileAccess.WRITE)
	file.store_string('{"schema":1,"seed":9,"chunk_size":64,"candidate":"strata"}')
	file.close()
	dialog._browse.file_selected.emit(ProjectSettings.globalize_path(manual_path))
	check(not dialog._preview_button.disabled and dialog._profile_error.is_empty(), "manual profile selection recovers missing-profile state")
	check(str(dialog._profile.get_item_metadata(dialog._profile.selected)) == ProjectSettings.globalize_path(manual_path), "manual chooser retains selected file")
	dialog._select_profile_file(ProjectSettings.globalize_path("user://wb-profile-does-not-exist.json"))
	dialog._start()
	check(dialog._status.text.contains("Cannot read profile") and dialog._status.text.contains("Choose profile file"), "unreadable profile identifies file and recovery action")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manual_path))
	owner.queue_free()
	await process_frame
	print("WB_GENERATOR_DISCOVERY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
