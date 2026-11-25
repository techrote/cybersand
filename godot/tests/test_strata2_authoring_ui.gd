extends SceneTree

## Synthetic mediator exercise. Tests actual controls and preview permission;
## native placement and real framebuffer qualification are separate witnesses.
const StrataPanel = preload("res://scripts/depth/workbench_strata_panel.gd")
var checks: Array[Dictionary] = []

class Mediator extends Node:
	var state := {"status":"idle", "busy":false, "can_approve":false, "cancellable":false}
	var calls: Array[Dictionary] = []
	var preview_serial := 0
	var refuse_preview := false
	var library: Array = [{"id":"native-part","label":"Native part"}]
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
	func module_catalogue() -> Array: return library
	func authoring_inspect_source(path: String) -> Dictionary:
		return {"ok":true,"kind":"native_module" if path.ends_with(".json") else "png","extent":[64,48],"source_sha256":"synthetic-inspection"}
	func composition_catalogue() -> Array: return [{"id":"layered-preset","label":"Layered preset"}]
	func scene_catalogue() -> Array: return [{"id":"successor-scene","label":"Successor scene","description":"Synthetic UI fixture"}]
	func atmosphere_profiles() -> Array: return [{"id":"vent_steam","label":"Vent steam","description":"Seeded visual steam motifs, not native Steam mass."}]
	func atmosphere_state() -> Dictionary: return effects.duplicate(true)
	func preview_import(path: String, options: Dictionary) -> void:
		calls.append({"method":"preview_import","path":path,"options":options})
		if refuse_preview: return
		preview_serial += 1
		state = {"status":"ready","token":"review-"+str(preview_serial),"busy":false,"can_approve":true,"cancellable":true,"plane":options.plane,"stages":[{"id":"import-1","plane":options.plane,"region":[32,32,64,64]}],"changed_cells":20,"mapped":20,"no_write":4076}
	func approve_plan(token: Variant) -> void: calls.append({"method":"approve_plan","token":token})
	func apply_composition_settings(token: String) -> void: calls.append({"method":"apply_composition_settings","token":token})
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
	_check("coherent workflow plus appended Optics Lab", panel._tabs.get_tab_count() == 6)
	_check("source catalogue keeps successor identity", panel._demo_ids == ["successor-scene"])
	_check("initial authoring loop idle", not ui.is_processing())
	var options: Dictionary = ui._import_options()
	_check("overlay is explicit default", options.alpha_mode == "overlay")
	_check("decorative target is explicit", options.plane == "scripted")
	_check("native import exposes explicit Play target", ui._import_plane.get_item_metadata(0) == "play")
	_check("native construction exposes explicit Play target", ui._module_plane.get_item_metadata(0) == "play")
	_check("atmosphere never exposes Play target", ui._effect_plane.item_count == 3 and ui._effect_plane.get_item_metadata(0) == "scripted")
	_check("palette uses admitted IDs", options.palette.size() == 2 and options.palette[0].material == 58 and options.palette[1].material == 77)
	_check("unknown colours default to refusal", options.unmapped == "refuse" and options.color_distance == 0)
	ui._preview_import()
	_check("reviewed proposal enables approval", not ui._approve.disabled and not ui._compose_approve.disabled)
	_check("single-stage import displays reviewed target and region without top-level alias", ui._preview_summary.text.begins_with("Target: scripted · region [32, 32, 64, 64]"))
	mediator.state.region = [0,0,1,1]
	ui.refresh({}, "")
	_check("actual stage region takes precedence over stale conversion summary", ui._preview_summary.text.begins_with("Target: scripted · region [32, 32, 64, 64]"))
	mediator.state.erase("region")
	ui._origin[0].value += 1
	ui.refresh({}, "")
	_check("edited origin cannot revive old approval", ui._approve.disabled and ui._compose_approve.disabled)
	var before: int = mediator.calls.size()
	ui._approve.pressed.emit()
	_check("stale UI token cannot dispatch approval", mediator.calls.size() == before)
	ui._preview_import()
	ui._approve.pressed.emit()
	_check("fresh approval passes reviewed token", mediator.calls.back() == {"method":"approve_plan","token":"review-2"})
	mediator.refuse_preview = true
	ui._origin[0].value += 1
	ui._preview_import()
	_check("refused new preview cannot revive retained old token", ui._approve.disabled and ui._compose_approve.disabled)
	before = mediator.calls.size()
	ui._approve.pressed.emit()
	_check("refused preview cannot dispatch prior approval", mediator.calls.size() == before)
	mediator.refuse_preview = false
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
	ui._source.text = "synthetic-native.json"
	ui._inspect_source()
	_check("native mode disables raster crop scale and mask", not ui._crop[0].editable and not ui._scale.editable and not ui._mask.editable)
	_check("native mode disables raster palette controls", ui._palette[0].material.disabled and ui._palette[0].colour.disabled and ui._unmapped.disabled)
	_check("native mode keeps exact transform and placement", not ui._transform.disabled and ui._origin[0].editable)
	ui._source.text = "synthetic-raster.png"
	ui._inspect_source()
	_check("PNG inspection restores raster controls", ui._crop[0].editable and ui._scale.editable and ui._mask.editable and not ui._palette[0].material.disabled)
	mediator.library.append({"id":"harvested-part","label":"Harvested part"})
	mediator.state.harvested_modules = ["harvested-part"]
	ui.refresh({}, "")
	_check("async harvest completion refreshes native library", ui._modules.size() == 2 and ui._modules.back().id == "harvested-part")
	mediator.state.status = "applying"
	mediator.state.stages = [{"id":"stage-1","plane":"scripted","status":"applying","applied":10}]
	ui.refresh({}, "")
	mediator.state.stages[0].applied = 20
	ui.refresh({}, "")
	_check("stage progress refreshes within same overall status", "applied 20" in ui._plan_rows.text)
	panel._tabs.current_tab = 1
	await process_frame
	var field: LineEdit = ui._origin[0].get_line_edit()
	field.grab_focus()
	field.text = "117"
	ui._commit_field()
	_check("focused typed number commits before reading controls", ui._origin[0].value == 117)
	ui._preview_import()
	var before_image := Image.create(4,4,false,Image.FORMAT_RGBA8)
	before_image.fill(Color.RED)
	var after_image := Image.create(4,4,false,Image.FORMAT_RGBA8)
	after_image.fill(Color.GREEN)
	mediator.state.merge({"message":"Native observation is ready for explicit approval.","error":"ready",
		"history_warnings":["This placement exceeds the remaining 32-entry history; there is no group rollback."],
		"preview_regions":[{"id":"rear-stage","plane":"scripted","region":[0,0,4,4],"before_image":before_image,"output_image":after_image},
			{"id":"far-stage","plane":"background","region":[8,8,4,4],"before_image":after_image,"output_image":before_image}],
		"composite_image":after_image,"visual_settings_proposal":{"atmosphere":mediator.effects},
		"visual_settings_token":"visual-review-1","can_apply_visual_settings":false,
		"visual_settings_summary":"Rear opacity 0.8; atmosphere has one visual effect."},true)
	ui.refresh({},"")
	_check("ready status preserves useful backend message", "Native observation" in ui._authoring_status.text)
	_check("history capacity warnings visible before approval", "32-entry" in ui._history_warning.text and "no group rollback" in ui._compose_history_warning.text)
	_check("all proposed stages can be independently inspected", ui._stage_picker.item_count == 2 and ui._stage_before.image_reference == before_image and ui._stage_after.image_reference == after_image)
	ui._stage_picker.select(1)
	ui._stage_picker.item_selected.emit(1)
	_check("stage selector changes both native observations", ui._stage_before.image_reference == after_image and ui._stage_after.image_reference == before_image)
	var texture_before: int = ui._compose_preview.image_texture.get_instance_id()
	for _index: int in 5: ui.refresh({},"")
	_check("progress polling reuses immutable proposal texture", ui._compose_preview.image_texture.get_instance_id() == texture_before)
	_check("visual settings cannot apply before native completion", ui._apply_visual_settings.disabled)
	mediator.state.status = "completed"
	mediator.state.message = ""
	mediator.state.error = "completed"
	mediator.state.can_approve = false
	mediator.state.can_apply_visual_settings = true
	ui.refresh({},"")
	_check("reviewed completed preset exposes separate settings approval", not ui._apply_visual_settings.disabled and "replaces the existing" in ui._visual_settings_summary.text)
	_check("completed status remains visible without backend explanation", ui._authoring_status.text == "completed")
	ui._apply_visual_settings.pressed.emit()
	_check("settings approval dispatches its distinct reviewed token", mediator.calls.back() == {"method":"apply_composition_settings","token":"visual-review-1"})
	ui._module_origin[0].value += 1
	ui.refresh({},"")
	before = mediator.calls.size()
	ui._apply_visual_settings.pressed.emit()
	_check("changed construction controls fence visual approval too", ui._apply_visual_settings.disabled and mediator.calls.size() == before)
	_check("profile description explains visual category", "not native Steam" in ui._effect_description.text)
	mediator.effects.effects[0].kind = "beacon"
	ui._refresh_atmosphere()
	_check("beacon direction controls visibly inactive", not ui._effect_direction[0].editable and "0.2 cycles" in ui._effect_speed.tooltip_text)
	mediator.state.stages = [{"id":"rear","plane":"scripted","region":[32,32,64,64]}, {"id":"far","plane":"background","region":[96,32,64,64]}]
	ui.refresh({}, "")
	_check("multiple stages direct location review to explicit Compose targets", ui._preview_summary.text.begins_with("Target: per stage · region 2 explicit stages · inspect Compose"))
	var failures := 0
	for record: Dictionary in checks:
		if not record.passed: failures += 1
	print("STRATA2_UI_RESULT " + JSON.stringify({"schema":"cybersand.strata2-ui.v1","scope":"synthetic mediator; actual controls; no native or framebuffer claim","checks":checks,"passed":failures == 0}))
	panel.queue_free()
	mediator.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
