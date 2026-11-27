extends SceneTree

# Authored recipe/schema coverage only. Real body registration, runtime tick
# progression and measured performance belong to the native capacity campaign.
const Sandbox = preload("res://scripts/workbench_actor_sandbox.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var policy := PackedInt32Array([0])
	if ClassDB.class_exists(&"CyberDemoBridge"):
		var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
		policy = bridge.call(&"default_liquid_policy")
	for kind: String in Sandbox.IDS:
		var data := Sandbox.build(kind,policy)
		check(not data.is_empty(),"available authored playground: "+kind)
		check(Setup.validate(data).is_empty(),"validated playground "+kind+": "+Setup.validate(data))
		check(not Setup.rectangles(data).has("error"),"material rectangles compile: "+kind)
		check(Setup.validate(JSON.parse_string(JSON.stringify(data))).is_empty(),"JSON round trip preserves "+kind)
		var parts := 0
		var proxies := 0
		for actor: Dictionary in data.actors:
			parts += Catalog.part_count(str(actor.model))
			proxies += Catalog.proxy_count(str(actor.model))
		check(data.sandbox_capacity.body_limit >= parts and data.sandbox_capacity.proxy_limit >= proxies,
			"actual prepared parts and masks budgeted: "+kind)
	for count: int in [16,32,64,128,256]:
		var data := Sandbox.barrel_crowd(policy,count)
		check(data.actors.size() == count,"authored barrel count "+str(count))
		check(Setup.validate(data).is_empty(),"barrel recipe validates "+str(count)+": "+Setup.validate(data))
		check(data.sandbox_capacity.body_limit == maxi(64,count) and data.sandbox_capacity.proxy_limit == maxi(64,count),
			"barrels charge one body and one mask per actor "+str(count))
		var ids := {}
		var positions := {}
		for actor: Dictionary in data.actors:
			ids[actor.id] = true
			positions[str(actor.spawn)] = true
			check(actor.model == Setup.BARREL and Catalog.part_count(actor.model) == 1,"real passive definition "+str(actor.id))
		check(ids.size() == count and positions.size() == count,"stable distinct identities and separated starts "+str(count))
	check(Sandbox.build("missing",policy).is_empty(),"unknown playground refuses")
	check(Sandbox.barrel_crowd(policy,0).is_empty(),"zero count refuses")
	check(Sandbox.barrel_crowd(policy,Sandbox.MAX_BARRELS+1).is_empty(),"representable bound refuses rather than truncates")
	var frontier := Sandbox.barrel_crowd(policy,Sandbox.MAX_BARRELS)
	check(frontier.actors.size() == Sandbox.MAX_BARRELS,"highest authorable count is not silently lowered")
	check(Setup.validate(frontier).is_empty(),"highest authored recipe fits geometry and resource bounds; runtime performance is unqualified")
	print("WB_ACTOR_SANDBOX ",JSON.stringify({"checks":checks,"failures":failures,"kind":"authored-schema-only"}))
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WB_ACTOR_SANDBOX: "+label)
