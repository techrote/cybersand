extends "res://tools/qualify_workbench_strata2.gd"

## Real ordinary Midge/native ownership probe for the horizontal input semantics.
## A compact native fixture tests the actual yaw+propulsion action independently
## of large showcase rendering; full scene routes remain graphical witnesses.
func _route_definition() -> Dictionary:
	return {"id":"compact-horizontal-input","from":[128,256],"to":[400,256]}


func run() -> void:
	scene_id = "orbital-terminal"
	phase = "bounded-horizontal-control"
	output = OS.get_environment("STRATA_EVIDENCE")
	diagnostic_headless = DisplayServer.get_name() == "headless"
	record = {"schema":"strata2-actor-route-v1","completed":false,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"display_server":DisplayServer.get_name(),"process_id":OS.get_process_id(),
		"scope":"Actual ordinary Midge yaw/propulsion and native ticks in a512x512 fixture; no full-route or graphical claim."}
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	set_meta("cybersand_feature","shared_workbench")
	host = load("res://main.tscn").instantiate()
	host.set_script(RouteHost)
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle,"ordinary route fixture admission",180000): finish(); return
	strata = wb.ensure_strata()
	var setup := Setup.fresh(PackedInt32Array(wb.applied.liquid_policy),Vector2i(512,512))
	setup.edits = [[8,456,496,8,58]]
	setup.actors = [Setup.instance(Setup.Fleet.stable_id(0),1,Vector2(128,256))]
	setup.next_id = 2
	setup.selected = 1
	var document := Document.default_document(Vector2i(512,512))
	document.presentation.enabled = true
	check(strata.load_document({"setup":setup,"document":document}),"real native route fixture requested")
	if not await until(func() -> bool: return idle() and strata.has_document() and host.physical_actor_session != null,"real native route fixture adopted"): finish(); return
	check(wb.select_instance(1) and wb.pilot_instance(1),"route fixture explicitly selects and pilots its actual Midge")
	await route_segment()
	if not record.has("route_probe"): finish(); return
	check(record.route_probe.samples.any(func(row: Dictionary) -> bool: return absf(float(row.applied_force[0])) > 0.01),
		"ordinary body-local thrust produces actual horizontal force after yaw")
	print("STRATA2_ACTOR_ROUTE ",JSON.stringify({"checks":checks,"failures":failures,"route":record.route_probe}))
	finish()
