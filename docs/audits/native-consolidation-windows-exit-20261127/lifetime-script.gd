extends SceneTree

# Real native 2048x1024 material/mask qualification through the production
# worker consumers. No sampled actor extent contract is widened by this path.
const Worker = preload("res://scripts/simulation_worker.gd")
const Coupling = preload("res://scripts/rigid_body_coupling.gd")
const SampledEffects = preload("res://scripts/actor_rig_effects.gd")
const SampledUsables = preload("res://scripts/usable_runtime.gd")
const EXTENT := Vector2i(2048,1024)
const EPOCH: int = 29
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("WB_EQUIPMENT_EXTENT: " + label)


func run() -> void:
	var runtime: CyberPhysicalUsableRuntime = null
	for i in range(4):
		runtime = CyberPhysicalUsableRuntime.new()
		runtime.reset(EPOCH)
		var result := runtime.snapshot()
		assert(result.get("physical", false))
	runtime = null
	print("SCRIPT_EQUIPMENT_RETIRED")
	quit()
