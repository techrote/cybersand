extends SceneTree

const Controller = preload("res://goblin/goblin_controller.gd")
const Transcript = preload("res://goblin/goblin_transcript.gd")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var launch: Dictionary = Controller.read_launch()
	if not launch.get("ok", false):
		print("GOBLIN_LAUNCH_REFUSED ", JSON.stringify(launch))
		quit(2)
		return
	var replay := {}
	var reproduction := {}
	if launch.launch.get("replay", false):
		var selected: Dictionary = Controller.read_replay()
		if not selected.get("ok", false):
			print("GOBLIN_REPLAY_REFUSED ", JSON.stringify(selected))
			quit(2)
			return
		replay = selected.transcript
	if launch.launch.get("reproduce", false):
		var selected: Dictionary = Controller.read_reproduction(launch.provenance)
		if not selected.get("ok", false):
			print("GOBLIN_REPRODUCTION_REFUSED ", JSON.stringify(selected))
			quit(2)
			return
		reproduction = selected.plan
	var controller := Controller.new()
	root.add_child(controller)
	var tape: Dictionary = await controller.run_campaign(launch.launch, launch.provenance, replay, reproduction)
	var validation: Dictionary = Transcript.validate(tape)
	var completed: bool = tape.get("summary", {}).get("termination") == "budget_complete"
	var assertions_pass: bool = tape.get("summary", {}).get("failures", ["missing evidence"]).is_empty()
	var replay_pass: bool = replay.is_empty() or tape.get("replay_result", {}).get("semantic_match", false)
	var evidence_saved: bool = not controller.export_path.is_empty()
	print("GOBLIN_CAMPAIGN_RESULT ", JSON.stringify({"summary": tape.get("summary", {}),
		"validation": validation, "replay": tape.get("replay_result", {}), "output": controller.export_path,
		"evidence_exported": evidence_saved, "evidence_error": controller.last_error}))
	await controller.close()
	controller.queue_free()
	await process_frame
	print("GOBLIN_CAMPAIGN_COMPLETE")
	quit(0 if validation.ok and completed and assertions_pass and replay_pass and evidence_saved else 1)
