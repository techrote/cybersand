extends "res://tests/test_la_physical_campaign.gd"
const NormalPolicy = preload("res://tests/support/sol_active_normal_policy.gd")
var constructed_workers: int = 0

func observed_f64_bits(values: Array) -> String:
	var raw := PackedByteArray();raw.resize(values.size()*8)
	for index: int in values.size():raw.encode_double(index*8,float(values[index]))
	return raw.hex_encode()

func body_state(body: RigidBody2D) -> Dictionary:
	var state: Dictionary = super.body_state(body)
	var velocity: Vector2 = state.velocity
	var vx: float = float(velocity.x);var vy: float = float(velocity.y)
	var omega: float = float(state.omega)
	state["kinetic_legacy_f32_length_squared"]=state.kinetic
	state["kinetic"]=0.5*float(state.mass)*(vx*vx+vy*vy)+0.5*float(state.inertia)*omega*omega
	var pose: Transform2D = state.pose
	state["pose_f64le"]=observed_f64_bits([pose.x.x,pose.x.y,pose.y.x,pose.y.y,pose.origin.x,pose.origin.y])
	state["velocity_omega_f64le"]=observed_f64_bits([vx,vy,omega])
	return state

func configure_fresh_world(world: Variant, mode: String, _report: Dictionary) -> bool:
	if not NormalPolicy.configure(world,mode):return false
	var construction: Dictionary = world.get_applied_liquid_construction_receipt()
	constructed_workers=int(construction.get("worker_threads",0))
	return constructed_workers==int(OS.get_environment("LA_PHYSICAL_WORKERS"))

func coupling_result(world: Variant) -> Dictionary:
	var packet: Dictionary = NormalPolicy.result(world,"LA-SELECTIVE")
	packet["native_workers_configured"]=world.get_worker_threads()
	packet["native_workers_constructed"]=constructed_workers
	check(not packet.has("policy_refusal"),"native policy readback before application")
	return packet
