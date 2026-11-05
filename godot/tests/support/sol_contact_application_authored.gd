extends "res://tests/support/sol_node_trace_authored.gd"

func body_state(body: RigidBody2D) -> Dictionary:
	var state: Dictionary = super.body_state(body)
	state["center_of_mass_local"]=PhysicsServer2D.body_get_direct_state(body.get_rid()).center_of_mass_local
	return state

func application_variant_for_arm(_arm: String) -> String:
	return OS.get_environment("SOL_CONTACT_APPLICATION")

func expected_application_velocity(live: Dictionary, action: Dictionary) -> Vector2:
	# The configured experiment, independently of the action tag, selects the
	# real-RID oracle. Native/candidate decision code does not select this result.
	if OS.get_environment("SOL_CONTACT_APPLICATION")=="retain-linear-001":
		check(action.get("linear_clip_policy")=="retain-linear-001","actual retain-linear application")
		return Vector2(live.velocity)+Vector2(action.impulse)/live.mass
	check(not action.has("linear_clip_policy"),"baseline ledger unchanged")
	return super.expected_application_velocity(live,action)

func record_step_checkpoint(world: Variant, preparer: Variant, report: Dictionary, step: int, output: String, name: String) -> void:
	if report.case.id!="shared-granular-bodies-extended360" or step!=179:return
	var started: int = Time.get_ticks_usec()
	var physical: String = world.get_physical_state_hash();var revision: int = world.get_revision()
	report["prefix_payload"]=save_payload(preparer,world,output+"/"+name+"-prefix180.cyps")
	check(world.get_physical_state_hash()==physical and world.get_revision()==revision,"nonmutating full prefix export")
	report["prefix_export_us"]=Time.get_ticks_usec()-started
	report.steps[-1]["checkpoint_export_us"]=report.prefix_export_us
