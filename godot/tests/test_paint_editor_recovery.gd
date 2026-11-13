extends SceneTree

# Actual native interrupted recovery; the small bench owns only the start recipe.
const Controller = preload("res://scripts/workbench_paint_editor_controller.gd")
const Executor = preload("res://scripts/workbench_paint_editor_executor.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
class Bench extends Control:
	var applied: Dictionary = {}
	var message := ""
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error("PAINT_RECOVERY "+label)
func context(world: Variant,epoch: int = 1) -> Dictionary:
	return {"epoch":epoch,"generation":1,"revision":int(world.revision),"tick":int(world.tick_index),"paused":true,"settings_revision":0,"error":"","paint_allowed":true,"erase_allowed":true}
func begin(world: Variant,cells: PackedInt32Array,operation_id: int) -> RefCounted:
	var command := {"kind":"edit","cells":cells,"expected_generation":1,"expected_revision":int(world.revision),"expected_tick":int(world.tick_index),"operation_id":operation_id,"_epoch":1,"_settings_revision":0}
	var owner := Executor.new()
	owner.begin(command,Vector2i(1024,1024),Executor.native_materials())
	return owner
func run() -> void:
	ProjectSettings.set_setting("cybersand/native_worker_threads",1)
	var world: Variant = ClassDB.instantiate(&"CyberNativeCellWorld")
	var forward := PackedInt32Array()
	var inverse := PackedInt32Array()
	for y: int in range(100,164):
		for x: int in range(100,228):
			forward.append_array([x,y,2]); inverse.append_array([x,y,0])
	var owner: RefCounted = begin(world,forward,1)
	var receipt: Dictionary = {}
	while receipt.is_empty(): receipt=owner.step(world,context(world))
	check(receipt.status=="completed" and receipt.applied==8192,"original native prefix exists")
	var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
	var before := Setup.fresh(bridge.default_liquid_policy(),Vector2i(1024,1024))
	var bench := Bench.new()
	bench.applied=before.duplicate(true)
	var editor := Controller.new()
	editor.bench=bench
	editor._save_hold=true
	var zeros := PackedInt32Array(); zeros.resize(8192); zeros.fill(0)
	var sand := PackedInt32Array(); sand.resize(8192); sand.fill(2)
	var record := {"label":"unsavable prefix","cells":forward,"before":zeros,"after":sand,"before_edits":[],"after_edits":[],"recover_only":true}
	editor._undo_stack=[record]
	var job := {"setup":before,"label":"Undo unsavable prefix","generated":{},"history_action":"undo","history_record":record}
	var operation := {"job":job,"planned":{"cells":inverse,"setup":before}}
	owner=begin(world,inverse,2)
	owner.step(world,context(world)); owner.step(world,context(world)); owner.step(world,context(world))
	receipt=owner.step(world,context(world,2))
	check(receipt.status=="partial" and receipt.applied==4096,"recovery stopped after exact native prefix")
	check(int(world.material_at(100,100))==0 and int(world.material_at(100,150))==2,"unsaved native suffix remains")
	editor._receive_edit(operation,receipt,context(world))
	check(editor._save_hold and not editor.save_allowed(),"interrupted recovery cannot release Save")
	check(bench.applied.edits.is_empty(),"saved start is not replaced by invented completion")
	for node: Node in [editor._tools,editor._status,editor._copy,editor._paste,editor._undo_button,editor._redo_button,editor._cancel_button]:
		if node.get_parent()==null: node.free()
	editor.free(); bench.free(); world=null
	print("PAINT_RECOVERY ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
