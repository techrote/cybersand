extends SceneTree
const AgentPanel = preload("res://scripts/workbench_agent_panel.gd")
var checks := 0
var failures := 0
func check(ok: bool) -> void:
 checks += 1
 if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var p := AgentPanel.new()
 root.add_child(p)
 await process_frame
 p.client.configure_fake_transport_for_tests(true)
 p.bind_authoritative_dispatcher(func(_a,_b,_c,_d,_e): pass)
 p._task.text = "test"
 p._match_area.button_pressed = true
 check(p._cell_limit.value == 1024 and not p._cell_limit.editable)
 p._region[2].value = 128
 p._region[3].value = 128
 check(p._cell_limit.value == 16384)
 p._on_start()
 check(p.client.is_active() and p.client._scope.cell_limit == 16384)
 p._region[2].value = 256
 check(not p.client.is_active() and p._cell_limit.value == 32768)
 p._region[3].value = 256
 check(p._cell_limit.value == 65536)
 p._on_start()
 check(p.client.is_active() and p.client._scope.cell_limit == 65536)
 p._region[2].value = 257
 check(not p.client.is_active() and not p._match_area_problem().is_empty())
 p._on_start()
 check(not p.client.is_active())
 p._match_area.button_pressed = false
 check(p._cell_limit.editable and p._match_area_problem().is_empty())
 p._on_start()
 check(p.client.is_active())
 p._on_stop()
 p.queue_free()
 await process_frame
 print("WB_MATCH_AREA: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)

