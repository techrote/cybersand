extends SceneTree

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var world: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	var recipe: PackedInt32Array=CyberExperimentTower.rectangles()
	var hashes: Array=[]
	for i: int in range(3):
		var p: Dictionary=CyberTransportProfiles.preset(i)
		var resolved: Dictionary=CyberTransportProfiles.resolve(p)
		assert(resolved.ok)
		assert(resolved.packed.size()==39529)
		assert(CyberTransportProfiles.parse(JSON.stringify(p)).hash==resolved.hash)
		assert(bridge.build_tuned_world(world,recipe,resolved.packed))
		assert(world.get_tick_index()==0)
		assert(int(CyberTransportProfiles.effective(p,33,2)["values"][5])==30)
		assert(int(CyberTransportProfiles.effective(p,2,33)["values"][5])==30)
		assert(int(CyberTransportProfiles.effective(p,33,2)["values"][1])==0)
		hashes.append(resolved.hash)
	var original: PackedByteArray=bridge.export_level(world)
	var bad: PackedInt32Array=CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0)).packed
	bad[1]=0
	assert(not bridge.build_tuned_world(world,recipe,bad))
	assert(bridge.export_level(world)==original)
	bad[1]=3
	assert(not bridge.build_tuned_world(world,recipe,bad))
	assert(bridge.export_level(world)==original)
	assert(not CyberTransportProfiles.parse("{}").ok)
	assert(not CyberTransportProfiles.parse("[]").ok)
	assert(not CyberTransportProfiles.parse("x").ok)
	var p: Dictionary=CyberTransportProfiles.preset(0)
	p.materials["2"]={"mixing":12,"pickup":90}
	p.pairs=[{"source":2,"target":14,"direction":"symmetric","values":{"mixing":23}}]
	assert(CyberTransportProfiles.resolve(p).ok)
	assert(CyberTransportProfiles.effective(p,2,14)["values"][0]==23)
	assert(CyberTransportProfiles.effective(p,14,2)["values"][0]==23)
	assert(CyberTransportProfiles.effective(p,3,2)["values"][2]==90)
	p.pairs.append(p.pairs[0].duplicate(true))
	assert(not CyberTransportProfiles.resolve(p).ok)
	for index: int in range(8):
		for n: int in [CyberTransportProfiles.MINIMUM[index],CyberTransportProfiles.MAXIMUM[index]]:
			assert(CyberTransportProfiles.valid_values({CyberTransportProfiles.FIELDS[index]:n}))
		assert(not CyberTransportProfiles.valid_values({CyberTransportProfiles.FIELDS[index]:CyberTransportProfiles.MAXIMUM[index]+1}))
	assert(not CyberTransportProfiles.valid_values({"mixing":0.5}))
	assert(not CyberTransportProfiles.valid_values({"mixing":true}))
	assert(not CyberTransportProfiles.valid_values({"unexpected":1}))
	print("TRANSPORT_PROFILES: preset/roundtrip/inheritance/pair/minimum/extreme/invalid-preservation passed ",hashes)
	quit()
