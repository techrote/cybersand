extends SceneTree

func _init() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	if args.is_empty(): quit(1);return
	for i: int in range(3):
		for sampled: int in range(2):
			var p: Dictionary=CyberTransportProfiles.preset(i)
			if sampled: p.families.liquid.horizontal=1;p.name+=" sampled"
			var resolved: Dictionary=CyberTransportProfiles.resolve(p)
			if not resolved.ok: quit(1);return
			var key: String="%d-%d" % [i,sampled]
			var file: FileAccess=FileAccess.open(args[0]+"/"+key+".ints",FileAccess.WRITE)
			var values: PackedStringArray=[]
			for n: int in resolved.packed: values.append(str(n))
			file.store_string(" ".join(values))
			file=FileAccess.open(args[0]+"/"+key+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"profile":p,"hash":resolved.hash},"  "))
	print("Exported six immutable resolved comparison inputs")
	quit()
