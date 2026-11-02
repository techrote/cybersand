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
			if str(key) not in ["contact_bins","cells","terrain_chunks","members"]: copy[str(key)]=portable(value[key])
		return copy
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat64Array or value is PackedFloat32Array:
		var copy: Array = []
		for item: Variant in value: copy.append(portable(item))
		return copy
	return value
func _run() -> void:
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var protocol: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("protocol",""))))
	if not protocol is Dictionary or protocol.get("registration","")!="GCR-LA-001-2026-11-02": quit(1); return
	var spec: Dictionary = {}
	for entry: Dictionary in protocol.cases:
		if entry.id==args.get("case",""): spec=entry
	var arm: String = str(args.get("candidate",""))
	if spec.is_empty() or arm not in protocol.arms: quit(1); return
	var report: Dictionary = {"case":spec,"arm":arm,"platform":OS.get_name(),"rows":[],"edits":[],"errors":[],"ok":false,
		"identity":{"source":OS.get_environment("GCR_LA_SOURCE"),"native_sha256":FileAccess.get_sha256("res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name()=="Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"),"protocol_sha256":FileAccess.get_sha256(str(args.protocol))}}
	if spec.kind=="barrel":
		var fixture = Fixture.new()
		if await fixture.setup(root,spec.spec,"GCR-A1" if arm=="A1" else "GCR-LA"):
			for step: int in range(int(protocol.ticks)):
				var rows: Array = fixture.step()
				for row: Dictionary in rows:
					row.erase("admission")
					row.erase("ablation")
					row.erase("local_slip")
					report.rows.append(portable(row))
					if not row.conserved: report.errors.append("material conservation at "+str(step))
				if not fixture.error.is_empty(): report.errors.append(fixture.error); break
		else: report.errors.append("barrel setup: "+fixture.error)
		fixture.close()
	else:
		var session = Session.new()
		if await session.open(root,1,str(spec.surroundings),true,arm):
			report.before=portable(await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128)))
			if await session.cut_and_release():
				report.mass=session.body.mass
				report.inertia=session.body.inertia
				report.payload_count=session.source_receipt.member_count
				report.cut_applied=session.source_receipt.get("cut_applied",false)
				var initial: Vector2 = session.body_transform().origin
				var target: int = int(session.coupling_metrics().native_tick)+int(protocol.ticks)
				var started: int = Time.get_ticks_msec()
				var step: int = 0
				while int(session.coupling_metrics().native_tick)<target:
					await physics_frame
					session.physics_step()
					var pose: Transform2D = session.body_transform()
					var velocity: Vector2 = PhysicsServer2D.body_get_state(session.body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
					var metrics: Dictionary = session.coupling_metrics()
					report.rows.append({"tick":metrics.native_tick,"rapier_steps":session.bridge.manual_step_count(),"position":portable(pose.origin),"rotation":pose.get_rotation(),"velocity":portable(velocity),"omega":session.angular_velocity(),"entry_com":maxf(0,pose.origin.y-initial.y),"metrics":portable(metrics)})
					if step==600 and spec.surroundings=="isolated_excavate":
						var before: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128))
						if not session.excavate_support(): report.errors.append("excavation refused")
						if not await session.wait_native_ticks(2): report.errors.append("excavation owner wait failed")
						var after: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128))
						report.edits.append({"step":step,"before":portable(before),"after":portable(after)})
						session.set_paused(false)
					if session.physics_paused or session.worker.has_failed(): report.errors.append("owner paused or failed"); break
					if Time.get_ticks_msec()-started>int(protocol.wall_timeout_seconds)*1000: report.errors.append("wall timeout"); break
					step+=1
				report.after=portable(await session.inspect_coupling(PackedInt32Array(),Rect2i(0,0,160,128)))
			else: report.errors.append("handoff: "+session.last_error)
		else: report.errors.append("session: "+session.last_error)
		session.close()
	report.ok=report.errors.is_empty() and not report.rows.is_empty()
	var file := FileAccess.open(str(args.get("output","")),FileAccess.WRITE)
	if file==null: quit(1); return
	file.store_string(JSON.stringify(report))
	file.close()
	print("GCR_LA_CAPTURE ",JSON.stringify({"case":spec.id,"arm":arm,"ok":report.ok,"rows":report.rows.size(),"errors":report.errors}))
	quit(0 if report.ok else 1)
