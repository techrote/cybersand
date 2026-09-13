class_name CyberTransportProbe
extends RefCounted

static func run(host: Node,workers: int) -> Dictionary:
	var failures: Array=[];var rows: Array=[]
	for variant: int in range(6):
		var preset: int=variant%3
		var profile: Dictionary=CyberTransportProfiles.preset(preset)
		if variant>=3: profile.families.liquid.horizontal=1
		var resolved: Dictionary=CyberTransportProfiles.resolve(profile)
		if not resolved.ok: return {"ok":false,"failures":["profile resolution"]}
		for layout: String in ["packed","powder","erosion","loose"]:
			var world: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
			await host.get_tree().process_frame
			if not world.diagnostic_reset({"workers":workers,"transport":resolved.packed}): return {"ok":false,"failures":["native reset"]}
			await host.get_tree().process_frame
			world.set_simulation_window(Vector2i(64,64),Vector2i(192,192),0,0)
			var recipe: PackedInt32Array=PackedInt32Array([64,64,160,1,1,64,223,160,1,1,64,64,1,160,1,223,64,1,160,1])
			if layout=="packed":
				recipe.append_array(PackedInt32Array([99,65,1,158,1,101,65,1,158,1,100,190,1,33,2,100,189,1,1,33]))
			elif layout=="powder":
				recipe.append_array(PackedInt32Array([119,69,20,70,2,139,69,20,70,14]))
			else:
				recipe.append_array(PackedInt32Array([69,69,35,90,3,104,69,2,82,1]))
				for x: int in range(110): recipe.append_array(PackedInt32Array([67+x,172+x/4,1,51-x/4,2]))
			if layout=="loose":
				for x: int in range(45,130,2): recipe.append_array(PackedInt32Array([64+x,167,1,1,2]))
			for at: int in range(0,recipe.size(),5):
				if not world.diagnostic_fill_rect(Vector2i(recipe[at],recipe[at+1]),Vector2i(recipe[at+2],recipe[at+3]),recipe[at+4],0): failures.append("fill")
			var before: Dictionary=world.diagnostic_snapshot(Vector2i(64,64),Vector2i(160,160),false)
			var ticks: int=990 if layout=="packed" else 600
			for tick: int in range(1,ticks+1):
				if not world.simulation_tick(): failures.append("failed tick");break
				if layout=="packed" and tick%30==0:
					var expected: int=189+mini(tick/30,33)
					if int(world.material_at(100,expected))!=33: failures.append("Mercury front %d" % tick)
				if tick%30==0: await host.get_tree().process_frame
			var after: Dictionary=world.diagnostic_snapshot(Vector2i(64,64),Vector2i(160,160),true)
			for material: int in [2,14,33]:
				if before.counts[material]!=after.counts[material]: failures.append("grain conservation")
			if before.water_mass!=after.water_mass or after.overflow!=0: failures.append("mass/telemetry")
			var event_totals: Dictionary={}
			for event: Array in after.histogram:
				var kind: int=int(event[0])>>24
				event_totals[str(kind)]=int(event_totals.get(str(kind),0))+int(event[1])
			rows.append({"sampled":variant>=3,"profile":preset,"profile_hash":resolved.hash,"layout":layout,"ticks":ticks,"hash":after.hash,"counts":after.counts,"water":after.water_mass,"events":event_totals})
			world=null
			await host.get_tree().process_frame
	# Same shared tower constructor, all floor plugs and safe landings, and
	# invalid profile replacement through the actual native bridge on each Web.
	var tower: Variant=ClassDB.instantiate(&"CyberNativeCellWorld")
	await host.get_tree().process_frame
	var bridge: Variant=ClassDB.instantiate(&"CyberDemoBridge")
	var resolved: Dictionary=CyberTransportProfiles.resolve(CyberTransportProfiles.preset(0))
	if not bridge.build_tuned_world(tower,CyberExperimentTower.rectangles(),resolved.packed): failures.append("tower build")
	await host.get_tree().process_frame
	for f: int in range(5):
		if tower.character_box_collides(CyberExperimentTower.landing(f),Vector2(8,14),0): failures.append("landing")
		for plug: Rect2i in CyberExperimentTower.plugs(f):
			if int(tower.material_at(plug.position.x,plug.end.y-1))!=79: failures.append("plug")
	tower.set_simulation_window(Vector2i(350,796),Vector2i(160,200),0,0)
	for tick: int in range(180):
		if not tower.simulation_tick(): failures.append("Acid containment tick");break
		if tick%30==0: await host.get_tree().process_frame
	if int(tower.material_at(400,CyberExperimentTower.floor_y(4)+109))!=12 or int(tower.material_at(400,CyberExperimentTower.floor_y(4)+110))!=1: failures.append("Acid auto-release")
	var revision: int=int(tower.get_revision())
	if bridge.build_tuned_world(tower,CyberExperimentTower.rectangles(),PackedInt32Array([0])) or int(tower.get_revision())!=revision: failures.append("invalid replacement")
	tower=null
	await host.get_tree().process_frame
	return {"ok":failures.is_empty(),"failures":failures,"results":rows,"workers":workers,"recipe":CyberExperimentTower.VERSION}
