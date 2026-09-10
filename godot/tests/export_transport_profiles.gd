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
	for knob: String in ["mixing","carrying","pickup","packing","cadence","permeability"]:
		for value: int in ({"mixing":[0,255],"carrying":[0,64],"pickup":[0,255],"packing":[0,32],"cadence":[4,60],"permeability":[1,60]}[knob]):
			var p: Dictionary=CyberTransportProfiles.preset(2)
			p.name="User copy / "+knob+" "+str(value)
			if knob=="carrying":
				for pair: Dictionary in p.pairs: pair["values"].carrying=value
			elif knob=="permeability": p.materials["33"].permeability=value
			else: p.families["liquid" if knob=="cadence" else "powder"][knob]=value
			var r: Dictionary=CyberTransportProfiles.resolve(p)
			if not r.ok: quit(1);return
			var key: String=knob+"-"+str(value)
			var file: FileAccess=FileAccess.open(args[0]+"/"+key+".ints",FileAccess.WRITE)
			var values: PackedStringArray=[]
			for n: int in r.packed: values.append(str(n))
			file.store_string(" ".join(values))
			file=FileAccess.open(args[0]+"/"+key+".json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"profile":p,"hash":r.hash},"  "))
	print("Exported six immutable comparison inputs and twelve independent knob screens")
	quit()
