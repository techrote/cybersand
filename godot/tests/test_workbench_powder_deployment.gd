extends "res://tests/test_workbench_articulated.gd"

# Actual native powder contacts and Rapier steps. The initial released chassis
# pose is deliberately injected to isolate deployment from throwing/aiming.
var metrics: Dictionary = {}
func powder_deployment() -> void:
	var definition := actor("jetbarrel",17,Vector2(80,60)); definition.usable_index = 22
	check(instantiate([definition],31),"powder processor fixture")
	if not session.active(): return
	var rig = session._rigs[0]
	var equipment = session._equipment[0]
	equipment._drop(true)
	var held: int = int(rig.equipment_mount_state().held_part)
	var chassis: RigidBody2D = rig.bodies()[held]
	var half: Vector2 = rig.body_sizes()[held]*0.5
	PhysicsServer2D.body_set_state(chassis.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM,Transform2D(0.0,Vector2(160,102-half.y)))
	PhysicsServer2D.body_set_state(chassis.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,Vector2.ZERO)
	rig.refresh_observation()
	session.bridge.refresh_all_states()
	var sample := session.pack_workbench_sample()
	var token: int = candidate(sample,PackedInt32Array([0,102,512,410,2]))
	print("POWDER_DEPLOY_PREPARE ",JSON.stringify({"token":token,"error":adapter.get_last_error()}))
	check(token>0 and adapter.commit_liquid_world(world,token),"actual deep packed native Sand bed")
	check(session.bridge.hard_surface_shape_count()==0,"no Rapier hard terrain collider supports chassis")
	var observed := false
	var deployment_tick := -1
	for tick: int in 180:
		sample = session.pack_workbench_sample()
		if not check_native_sample(sample,tick): break
		var packet: Dictionary = world.workbench_coupling_results()
		session.apply_workbench_results(tick+1,packet)
		rig.refresh_observation()
		if not packet.rows[held].support.is_empty():
			observed = true
			if tick==0:
				check(rig.equipment_mount_state().supported,"fresh held-part granular observation supports released chassis")
				check(rig._support.is_empty(),"remote dropped chassis never grounds controlled body")
		check(session.submit_workbench_action(17,{"move":Vector2.ZERO,"effort":1.0},{"q":false,"e":false,"s":false,"boost":false},false),"neutral live lease")
		session.advance(1.0/60.0); session.bridge.step(); session.complete_step()
		if equipment.state=="fixed": deployment_tick=tick; break
	check(observed,"real native upward powder witness observed")
	check(deployment_tick>=0 and chassis.freeze,"quiet powder contact reaches real fixed processor state")
	metrics={"deployment_tick":deployment_tick,"state":equipment.state,"mount":rig.equipment_mount_state(),"root_support":rig._support,"position":str(PhysicsServer2D.body_get_state(chassis.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM))}
	# Genuine native excavation retires the contact. A deployed device stays
	# deliberately fixed, but its old contact cannot remain fresh support.
	world.emit_disc(160,110,35,0)
	sample = session.pack_workbench_sample()
	check(check_native_sample(sample,181) and world.workbench_coupling_results().rows[held].support.is_empty(),"actual excavation retires native held-part witness")
	for step: int in 2:
		session.advance(1.0/60.0); session.bridge.step(); session.complete_step()
	rig.refresh_observation()
	check(not rig.equipment_mount_state().supported,"retired contact ages out of powder deployment support")

func check_native_sample(sample: Dictionary,tick: int) -> bool:
	if not world.prepare_workbench_coupling(sample.states,sample.geometry,sample.bodies,sample.session,sample.epoch,true):
		check(false,"native powder sample admitted tick%d"%tick); return false
	if not world.simulation_tick():
		check(false,"native powder tick succeeds"); return false
	return true

func run() -> void:
	host=Node2D.new(); root.add_child(host)
	adapter=ClassDB.instantiate(&"CyberDemoBridge"); world=ClassDB.instantiate(&"CyberNativeCellWorld")
	checked=Contract.validate(Contract.parse(FileAccess.get_file_as_string(DAM)).definition)
	powder_deployment()
	if session!=null: session.free()
	host.free(); adapter=null; world=null
	print("WORKBENCH_POWDER_DEPLOYMENT ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	quit(0 if failures.is_empty() else 1)
