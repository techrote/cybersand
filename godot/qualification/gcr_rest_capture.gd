extends SceneTree
const Session = preload("res://scripts/solid_detachment_session.gd")
const Fixture = preload("res://tests/support/y1_envelope_fixture.gd")
func _init() -> void:
	call_deferred("_run")
func portable(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value:
			if str(key) not in ["contact_bins","cells","terrain_chunks","members","witness_offset_counts"]: copy[str(key)]=portable(value[key])
		return copy
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat64Array or value is PackedFloat32Array:
		var copy: Array = []
		for item: Variant in value: copy.append(portable(item))
		return copy
	return value
func bounds(session: RefCounted, pose: Transform2D) -> Rect2:
	var minimum := Vector2(INF,INF)
	var maximum := Vector2(-INF,-INF)
	var rectangles: PackedInt32Array = session.source_rectangles
	for offset: int in range(0,rectangles.size(),4):
		for corner: Vector2 in [Vector2.ZERO,Vector2(rectangles[offset+2],0),Vector2(0,rectangles[offset+3]),Vector2(rectangles[offset+2],rectangles[offset+3])]:
			var point: Vector2 = pose*(Vector2(rectangles[offset],rectangles[offset+1])+corner-session.source_center)
			minimum=minimum.min(point); maximum=maximum.max(point)
	return Rect2(minimum,maximum-minimum)
func application_step(before: int, after: int, physics_call: int, application: Dictionary) -> Dictionary:
	return {"version":1,"physics_call":physics_call,"snapshot_before":before,"snapshot_after":after,
		"delivered_this_step":after>before and application.get("accepted",false) and int(application.get("snapshot",-1))==after}
func admitted_current(receipt: Dictionary, application: Dictionary, step_receipt: Dictionary) -> bool:
	if not step_receipt.get("delivered_this_step",false) or not application.get("accepted",false): return false
	if int(step_receipt.get("snapshot_after",-1))<=int(step_receipt.get("snapshot_before",-1)) or int(application.get("snapshot",-1))!=int(step_receipt.get("snapshot_after",-2)): return false
	var native: Array = receipt.get("bodies",[])
	var applied: Array = application.get("bodies",[])
	if native.size()!=1 or applied.size()!=1: return false
	return bool(native[0].get("quiet_admitted",false)) and int(native[0].get("sample",-1))==int(applied[0].get("sample",-2)) and int(native[0].get("session",receipt.get("session",-1)))==int(applied[0].get("session",-2)) and int(applied[0].get("age",-1))==0
func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not protocol is Dictionary or protocol.get("registration","")!="GCR-REST-001-2026-11-02": quit(1); return
	var spec: Dictionary = {}
	for entry: Dictionary in protocol.cases:
		if entry.id==args.get("case",""): spec=entry
	if spec.is_empty(): quit(1); return
	var report: Dictionary = {"schema":1,"case":spec,"platform":OS.get_name(),"rows":[],"edits":[],"errors":[],"ok":false,"outcome":"CAPTURED","support_loss_qualified":null,"support_loss_triggered_under_admitted_rest":false,
		"identity":{"source":OS.get_environment("GCR_REST_SOURCE"),"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),"engine_version":Engine.get_version_info().string,"physics_backend":ProjectSettings.get_setting("physics/2d/physics_engine"),"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),"protocol_sha256":FileAccess.get_sha256(str(args.protocol))}}
	if spec.kind=="barrel":
		var fixture = Fixture.new()
		var configuration: Dictionary = spec.spec.duplicate(true)
		configuration.rest_mode=spec.mode
		configuration.base_budget=spec.budget
		configuration.ticks=spec.ticks
		if await fixture.setup(root,configuration,"GCR-REST"):
			var previous_snapshot: int = -1
			for step: int in range(int(spec.ticks)):
				var rows: Array = fixture.step()
				for row: Dictionary in rows:
					var application: Dictionary = row.get("application",{})
					var current_snapshot: int = int(application.get("snapshot",-1))
					row["application_step"]=application_step(previous_snapshot,current_snapshot,step,application)
					previous_snapshot=current_snapshot
					row.erase("ablation")
					report.rows.append(portable(row))
					if not row.conserved: report.errors.append("material conservation at "+str(step))
				if not fixture.error.is_empty(): report.errors.append(fixture.error); break
		else: report.errors.append("barrel setup: "+fixture.error)
		fixture.close()
	else:
		var session = Session.new()
		if await session.open(root,1,str(spec.surroundings),true,"LA",{}, {"mode":str(spec.mode),"budget":float(spec.budget)}):
			report.before=portable(await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128),true))
			if await session.cut_and_release():
				report.mass=session.body.mass
				report.inertia=session.body.inertia
				report.payload_count=session.source_receipt.member_count
				report.source_rectangles=Array(session.source_rectangles)
				report.source_center=portable(session.source_center)
				report.cut_applied=session.source_receipt.get("cut_applied",false)
				var initial: Vector2 = session.body_transform().origin
				var start_tick: int = int(session.coupling_metrics().native_tick)
				var target: int = start_tick+int(spec.ticks)
				report.release_tick=start_tick
				report.target_native_tick=target
				var started: int = Time.get_ticks_msec()
				var step: int = 0
				var excavated: bool = false
				while int(session.coupling_metrics().native_tick)<target:
					await physics_frame
					var snapshot_before: int = int(session.coupling_metrics().get("last_compound_observation",{}).get("snapshot_serial",-1))
					session.physics_step()
					var pose: Transform2D = session.body_transform()
					var velocity: Vector2 = PhysicsServer2D.body_get_state(session.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
					if not pose.origin.is_finite() or not velocity.is_finite() or not is_finite(pose.get_rotation()) or not is_finite(session.angular_velocity()): report.errors.append("nonfinite physical state"); break
					var metrics: Dictionary = session.coupling_metrics()
					var extent: Rect2 = bounds(session,pose)
					var floor_y: float = 118.0 if str(spec.surroundings).begins_with("isolated_") else 72.0
					var observation: Dictionary = metrics.get("last_compound_observation",{})
					var receipt: Dictionary = observation.get("rest_receipt",{})
					var application: Dictionary = observation.get("application",{})
					var delivery: Dictionary = application_step(snapshot_before,int(observation.get("snapshot_serial",-1)),step,application)
					var hard_clear: bool = session.rest_hard_clearance()
					report.rows.append({"row":step,"tick":metrics.native_tick,"native_relative_tick":int(metrics.native_tick)-start_tick,"rapier_steps":session.bridge.manual_step_count(),"position":portable(pose.origin),"rotation":pose.get_rotation(),"velocity":portable(velocity),"omega":session.angular_velocity(),"entry_com":maxf(0,pose.origin.y-initial.y),"union_bounds":[extent.position.x,extent.position.y,extent.end.x,extent.end.y],"floor_plane_flag":extent.end.y>=floor_y,"wall_plane_flag":extent.position.x<=31.0 or extent.end.x>=119.0,"hard_clearance":hard_clear,"application_step":delivery,"quiet_admitted_current":admitted_current(receipt,application,delivery),"metrics":portable(metrics)})
					if bool(spec.get("conditional_excavation",false)) and not excavated and step>=600 and hard_clear and admitted_current(receipt,application,delivery):
						var before: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128),true)
						if not session.excavate_support(): report.errors.append("excavation refused")
						if not await session.wait_native_ticks(2): report.errors.append("excavation owner wait failed")
						var after: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128),true)
						report.edits.append({"step":step,"receipt_sample":receipt.get("bodies",[{}])[0].get("sample"),"before":portable(before),"after":portable(after)})
						report.support_loss_triggered_under_admitted_rest=true
						excavated=true
						session.set_paused(false)
					if session.physics_paused or session.worker.has_failed(): report.errors.append("owner paused or failed"); break
					if Time.get_ticks_msec()-started>int(protocol.wall_timeout_seconds)*1000: report.errors.append("wall timeout"); break
					step+=1
				if bool(spec.get("conditional_excavation",false)) and not excavated: report.outcome="NO_VALID_REST_ADMISSION"
				report.stop_native_tick=int(session.coupling_metrics().native_tick)
				report.observed_native_cutoff_overshoot=maxi(0,int(report.stop_native_tick)-target)
				report.after=portable(await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128),true))
			else: report.errors.append("handoff: "+session.last_error)
		else: report.errors.append("session: "+session.last_error)
		session.close()
	report.ok=report.errors.is_empty() and not report.rows.is_empty()
	var file := FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file==null: quit(1); return
	file.store_string(JSON.stringify(report)); file.close()
	print("GCR_REST_CAPTURE ",JSON.stringify({"case":spec.id,"ok":report.ok,"outcome":report.outcome,"rows":report.rows.size(),"errors":report.errors}))
	quit(0 if report.ok else 1)
