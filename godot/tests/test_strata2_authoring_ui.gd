extends SceneTree

## Synthetic mediator exercise. Tests actual controls and preview permission;
## native placement and real framebuffer qualification are separate witnesses.
const StrataPanel = preload("res://scripts/depth/workbench_strata_panel.gd")
var checks: Array[Dictionary] = []

class Mediator extends Node:
	var state := {"status":"idle", "busy":false, "can_approve":false, "cancellable":false}
	var calls: Array[Dictionary] = []
	var effects := {"version":1,"enabled":true,"paused":false,"seed":1,"effects":[
		{"id":"steam-one","plane":"effects","kind":"steam","region":[64,64,128,128],"seed":2,
		"count":12,"speed":18.0,"strength":0.5,"direction":[0.1,-1.0],"colour":[0.6,0.7,0.8,0.4],"enabled":true}]}
	func document() -> Dictionary:
		var planes: Array = []
		for id: String in ["play","scripted","effects","background"]:
			planes.append({"id":id,"visible":true,"locked":false,"opacity":1.0,"depth":0.0})
		return {"presentation":{"enabled":true,"active":"scripted","mode":"stack","solo":"","parallax_strength":0.75,"fog_strength":0.2},"planes":planes}
	func authoring_materials() -> Array: return [{"id":58,"label":"Steel"},{"id":77,"label":"Glass"}]
	func authoring_state() -> Dictionary: return state
	func import_fixture_catalogue() -> Array: return []
	func module_catalogue() -> Array: return [{"id":"native-part","label":"Native part"}]
	func composition_catalogue() -> Array: return [{"id":"layered-preset","label":"Layered preset"}]
	func scene_catalogue() -> Array: return [{"id":"successor-scene","label":"Successor scene","description":"Synthetic UI fixture"}]
	func atmosphere_profiles() -> Array: return [{"id":"vent_steam","label":"Vent steam"}]
	func atmosphere_state() -> Dictionary: return effects.duplicate(true)
	func preview_import(path: String, options: Dictionary) -> void:
		calls.append({"method":"preview_import","path":path,"options":options})
		state = {"status":"ready","token":"review-1","busy":false,"can_approve":true,"cancellable":true,"plane":options.plane,"region":[32,32,64,64],"changed_cells":20,"mapped":20,"no_write":4076}
	func approve_plan(token: Variant) -> void: calls.append({"method":"approve_plan","token":token})
	func stop_authoring() -> void: calls.append({"method":"stop_authoring"})
	func update_atmosphere_effect(id: String, patch: Dictionary) -> void:
		calls.append({"method":"update_atmosphere_effect","id":id,"patch":patch})
		for effect: Dictionary in effects.effects:
			if effect.id == id: effect.merge(patch,true)


func _initialize() -> void:
	call_deferred("_run")


func _check(name: String, passed: bool, detail: Variant = null) -> void:
	checks.append({"name":name,"passed":passed,"detail":detail})
	if not passed: push_error(name + " failed: " + str(detail))


func _run() -> void:
	var mediator := Mediator.new()
	root.add_child(mediator)
	var panel := StrataPanel.new()
	root.add_child(panel)
	panel.mount(mediator)
	await process_frame
	var ui: Node = panel._authoring
	_check("coherent five-tab workflow", panel._tabs.get_tab_count() == 5)
	_check("source catalogue keeps successor identity", panel._demo_ids == ["successor-scene"])
	_check("initial authoring loop idle", not ui.is_processing())
	var options: Dictionary = ui._import_options()
	_check("overlay is explicit default", options.alpha_mode == "overlay")
	_check("decorative target is explicit", options.plane == "scripted")
	_check("palette uses admitted IDs", options.palette.size() == 2 and options.palette[0].material == 58 and options.palette[1].material == 77)
	_check("unknown colours default to refusal", options.unmapped == "refuse" and options.color_distance == 0)
	ui._preview_import()
	_check("reviewed proposal enables approval", not ui._approve.disabled and not ui._compose_approve.disabled)
	ui._origin[0].value += 1
	ui.refresh({}, "")
	_check("edited origin cannot revive old approval", ui._approve.disabled and ui._compose_approve.disabled)
	var before: int = mediator.calls.size()
	ui._approve.pressed.emit()
	_check("stale UI token cannot dispatch approval", mediator.calls.size() == before)
	ui._preview_import()
	ui._approve.pressed.emit()
	_check("fresh approval passes reviewed token", mediator.calls.back() == {"method":"approve_plan","token":"review-1"})
	ui._alpha_mode.select(1)
	ui._alpha_mode.item_selected.emit(1)
	ui.refresh({}, "")
	_check("replace selection needs new review", ui._approve.disabled and ui._import_options().alpha_mode == "replace")
	ui._preview_import()
	ui._add_palette_row(Color.RED,58)
	ui.refresh({}, "")
	_check("adding palette mapping invalidates review", ui._approve.disabled)
	ui._preview_import()
	ui._module_origin[1].value += 1
	ui.refresh({}, "")
	_check("construction anchor changes invalidate review", ui._compose_approve.disabled)
	_check("effect controls enforce backend ranges", ui._effect_count.max_value == 96 and ui._effect_speed.max_value == 64)
	_check("effect alpha is retained", is_equal_approx(ui._effect_colour.color.a,0.4))
	ui._effect_speed.value = 23
	ui.refresh({}, "")
	_check("unrelated status refresh keeps pending effect edit", ui._effect_speed.value == 23)
	ui._apply_effect()
	var patch: Dictionary = mediator.calls.back().patch
	_check("effect approval uses RGBA", patch.colour.size() == 4 and is_equal_approx(patch.colour[3],0.4))
	_check("effect explicit Apply preserves selected speed", patch.speed == 23)
	ui._stop.pressed.emit()
	_check("Stop dispatches through mediator", mediator.calls.back().method == "stop_authoring")
	_check("idle refresh stops own process", not ui.is_processing())
	var failures := 0
	for record: Dictionary in checks:
		if not record.passed: failures += 1
	print("STRATA2_UI_RESULT " + JSON.stringify({"schema":"cybersand.strata2-ui.v1","scope":"synthetic mediator; actual controls; no native or framebuffer claim","checks":checks,"passed":failures == 0}))
	panel.queue_free()
	mediator.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
