extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cases: Array = [{"id":"smoke-sand","mode":"player","material":2,"ticks":120}]
	var output: String = ""
	if args.size() >= 2:
		cases = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		output = args[1]
	var result: Dictionary = await CyberPhysicsCharacterisation.run(root,cases,output)
	quit(0 if result.ok else 1)
