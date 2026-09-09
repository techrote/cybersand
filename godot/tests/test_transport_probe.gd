extends SceneTree

func _init() -> void: call_deferred("_run")
func _run() -> void:
	var host: Node=Node.new();root.add_child(host)
	var report: Dictionary=await CyberTransportProbe.run(host,4)
	print("TRANSPORT_PROBE ",JSON.stringify(report))
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if not args.is_empty():
		var file: FileAccess=FileAccess.open(args[0],FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	quit(0 if report.ok else 1)
