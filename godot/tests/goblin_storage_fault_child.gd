extends SceneTree

# Fixed audit-file writer only: no campaign, application action, model or
# transcript/replay qualification is claimed by this disposable-byte fixture.
const Controller = preload("res://goblin/goblin_controller.gd")
const Adapter = preload("res://goblin/goblin_adapter.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var profile := Adapter.verify_profile()
	if not profile.get("ok", false):
		push_error("GOBLIN_STORAGE_FIXTURE: the actual isolated-profile guard refused the fixture")
		quit(3)
		return
	var controller := Controller.new()
	var target := ProjectSettings.globalize_path(Controller.TRANSCRIPT_PATH)
	var old_exists := FileAccess.file_exists(target)
	var old_digest := FileAccess.get_sha256(target) if old_exists else ""
	var forbidden := "user://ultima-outside-goblin-allowlist.json"
	var wrong_path_refused := not controller._write_fixed(forbidden,{"seed":-1})
	var supplied := OS.get_environment("CYBERSAND_GOBLIN_PROFILE")
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE",supplied.path_join("not-selected"))
	var wrong_profile_refused := not controller._write_fixed(Controller.TRANSCRIPT_PATH,{"seed":-1})
	OS.set_environment("CYBERSAND_GOBLIN_PROFILE",supplied)
	var guards_preserved := old_exists == FileAccess.file_exists(target) \
		and (not old_exists or old_digest == FileAccess.get_sha256(target)) \
		and not FileAccess.file_exists(forbidden)
	if not wrong_path_refused or not wrong_profile_refused or not guards_preserved:
		push_error("GOBLIN_STORAGE_FIXTURE: fixed-path/profile refusal changed storage")
		controller.free()
		quit(3)
		return
	var seed := int(OS.get_environment("CYBERSAND_DIAGNOSTIC_VALUE"))
	var payload := {"fixture":"ULTIMA fixed audit writer, not a campaign transcript",
		"seed":seed,"payload":"Complete observed bytes. ".repeat(64)}
	var saved: bool = controller._write_fixed(Controller.TRANSCRIPT_PATH,payload)
	print("GOBLIN_STORAGE_RESULT ",JSON.stringify({"acknowledged":saved,
		"error":controller.last_error,"path":target,"profile_verified":profile.ok,
		"wrong_path_refused":wrong_path_refused,"wrong_profile_refused":wrong_profile_refused,
		"guards_preserved":guards_preserved}))
	controller.free()
	quit(0 if saved else 2)
