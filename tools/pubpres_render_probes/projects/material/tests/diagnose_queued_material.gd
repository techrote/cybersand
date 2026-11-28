extends "res://tests/test_material_staging_reachability.gd"

# Prospective hosted diagnostic. The original input tape, queue gate and first
# full-byte comparisons are preserved. Every extra read is AFTER that first
# comparison; none is inserted into the publication burst.
var diagnostics: Array[Dictionary] = []
var retained_owner: Publisher
var retained_expected_current: Image
var retained_expected_previous: Image
var pending_index := -1
var diagnostic_output := ""
var binary_directory := ""

func _snapshot(image: Image, leaf: String) -> Dictionary:
	if image == null:
		return {"present":false}
	var data: PackedByteArray = image.get_data()
	var samples: Array[Dictionary] = []
	for point: Vector2i in [Vector2i(0,0),Vector2i(63,63),Vector2i(127,63),
			Vector2i(191,63),Vector2i(255,63),Vector2i(63,127),Vector2i(127,127)]:
		if point.x < image.get_width() and point.y < image.get_height():
			var color: Color = image.get_pixelv(point)
			samples.append({"point":[point.x,point.y],"rgba8":[color.r8,color.g8,color.b8,color.a8]})
	var result := {"present":true,"size":[image.get_width(),image.get_height()],
		"format":image.get_format(),"bytes":data.size(),"sha256":_hash(data),"samples":samples}
	if not binary_directory.is_empty():
		var path: String = binary_directory.path_join(leaf+".bin")
		var writer := FileAccess.open(path,FileAccess.WRITE)
		check(writer != null,"diagnostic raw byte output opens")
		if writer != null:
			writer.store_buffer(data)
			result["raw"] = path
	return result

func _histories(owner: Publisher, current: Image, previous: Image, label: String) -> Dictionary:
	if not label.ends_with("burst completion"):
		return super._histories(owner,current,previous,label)
	# Keep these first two reads and byte assertions identical to the base
	# fixture. Later correct bytes cannot turn an original failure into a pass.
	var a: Image = owner.current.get_image()
	var b: Image = owner.previous.get_image()
	check(a != null and a.get_size() == current.get_size() and a.get_format() == current.get_format()
		and a.get_data() == current.get_data(),label+" exact current GPU bytes")
	check(b != null and b.get_size() == previous.get_size() and b.get_format() == previous.get_format()
		and b.get_data() == previous.get_data(),label+" exact previous GPU bytes")
	# Repeat before hashing or writing the diagnostic captures.
	var immediate_repeat: Image = owner.current.get_image()
	var result := {"current_sha256":_hash(a.get_data()) if a != null else "",
		"previous_sha256":_hash(b.get_data()) if b != null else ""}
	var key: String = "%02d" % diagnostics.size()
	var observation := {"label":label,"current_rid":owner.current.get_rid().get_id(),
		"previous_rid":owner.previous.get_rid().get_id(),
		"last_submission":owner.last_update.duplicate(true),
		"first_current":_snapshot(a,key+"-first-current"),
		"first_previous":_snapshot(b,key+"-first-previous"),
		"expected_current":_snapshot(current,key+"-expected-current"),
		"expected_previous":_snapshot(previous,key+"-expected-previous"),
		"immediate_repeat_current":_snapshot(immediate_repeat,key+"-repeat-current")}
	var stage_samples: Array[Dictionary] = []
	for pool_name: String in ["ordinary4","history4","full"]:
		var pool: Publisher.StagingPool = owner.full_staging
		if pool_name == "ordinary4": pool = owner.staging[4]
		if pool_name == "history4": pool = owner._history_staging[4]
		for slot: int in range(pool.resources.size()):
			var resource: Publisher.StagingResource = pool.resources[slot]
			var sampled: Image = resource.texture.get_layer_data(0)
			stage_samples.append({"pool":pool_name,"slot":slot,"next_slot":pool.next_slot,
				"last_used_slot":(pool.next_slot+owner.staging_slots-1)%owner.staging_slots,
				"texture_rid":resource.texture.get_rid().get_id(),
				"material_rid":resource.material.get_rid().get_id(),
				"image":_snapshot(sampled,key+"-"+pool_name+"-"+str(slot))})
	observation["stages"] = stage_samples
	observation["after_stage_reads_current"] = _snapshot(owner.current.get_image(),key+"-after-stages-current")
	diagnostics.append(observation)
	pending_index = diagnostics.size()-1
	retained_owner = owner
	retained_expected_current = current
	retained_expected_previous = previous
	return result

func _run() -> void:
	check(GDExtensionManager.get_loaded_extensions().is_empty(),"isolated probe must load no native extensions")
	diagnostic_output = OS.get_environment("PUBPRES_QUEUED_DIAGNOSTIC_OUTPUT")
	check(not diagnostic_output.is_empty(),"explicit diagnostic output required")
	if not diagnostic_output.is_empty():
		binary_directory = diagnostic_output.get_basename()+"-bytes"
		check(DirAccess.make_dir_recursive_absolute(binary_directory) == OK,"diagnostic byte directory created")
	var prior_policy: String = OS.get_environment(POLICY_ENV)
	var prior_slots: String = OS.get_environment(SLOTS_ENV)
	var prior_copy: String = OS.get_environment(COPY_ENV)
	OS.set_environment(COPY_ENV,"runs")
	separate = not RenderingServer.is_on_render_thread()
	var requested_thread: String = OS.get_environment("CYBERSAND_MATERIAL_QUEUE_THREAD")
	check(requested_thread in ["safe","separate"] and separate == (requested_thread == "separate"),
		"requested and actual rendering ownership agree")
	check(Publisher.supported_driver(),"real graphical supported Compatibility renderer required")
	# Selectors are diagnostic isolation, never an acceptance replacement for
	# the full original fixture. Blank selectors preserve all twelve cases.
	var selected_channels: String = OS.get_environment("PUBPRES_QUEUED_CHANNELS")
	var selected_slots: String = OS.get_environment("PUBPRES_QUEUED_SLOTS")
	var selected_policy: String = OS.get_environment("PUBPRES_QUEUED_POLICY")
	check(selected_channels in ["","1","2"],"diagnostic channel selector valid")
	check(selected_slots in ["","1","2","3"],"diagnostic slot selector valid")
	check(selected_policy in ["","eager","reachable"],"diagnostic pool selector valid")
	if failures.is_empty():
		for channels: int in [1,2]:
			if not selected_channels.is_empty() and channels != int(selected_channels): continue
			for slots: int in [1,2,3]:
				if not selected_slots.is_empty() and slots != int(selected_slots): continue
				for policy: String in ["eager","reachable"]:
					if not selected_policy.is_empty() and policy != selected_policy: continue
					_queued_history_case(channels,slots,policy)
					if retained_owner != null:
						await RenderingServer.frame_post_draw
						var later_a: Image = retained_owner.current.get_image()
						var later_b: Image = retained_owner.previous.get_image()
						var key: String = "%02d" % pending_index
						diagnostics[pending_index]["later_frame_current"] = _snapshot(later_a,key+"-later-current")
						diagnostics[pending_index]["later_frame_previous"] = _snapshot(later_b,key+"-later-previous")
						diagnostics[pending_index]["later_current_exact"] = later_a != null and later_a.get_data() == retained_expected_current.get_data()
						diagnostics[pending_index]["later_previous_exact"] = later_b != null and later_b.get_data() == retained_expected_previous.get_data()
						retained_owner = null
						retained_expected_current = null
						retained_expected_previous = null
					await process_frame
	OS.set_environment(POLICY_ENV,prior_policy)
	OS.set_environment(SLOTS_ENV,prior_slots)
	OS.set_environment(COPY_ENV,prior_copy)
	var report := {"schema":"pubpres-queued-material-diagnostic-v1","checks":checks,"failures":failures,
		"source_commit":OS.get_environment("PUBPRES_PROBE_SOURCE"),
		"nonce":OS.get_environment("PUBPRES_PROBE_NONCE"),
		"native_independent":true,"loaded_extensions":GDExtensionManager.get_loaded_extensions(),
		"project_sha256":FileAccess.get_sha256("res://project.godot"),
		"pid":OS.get_process_id(),"engine":Engine.get_version_info(),
		"engine_sha256":FileAccess.get_sha256(OS.get_executable_path()),
		"source_files":{"publisher":FileAccess.get_sha256("res://scripts/blit_material_publisher.gd"),
			"original_fixture":FileAccess.get_sha256("res://tests/test_material_staging_reachability.gd"),
			"diagnostic":FileAccess.get_sha256("res://tests/diagnose_queued_material.gd"),
			"shader":FileAccess.get_sha256("res://shaders/material_publication_blit.gdshader")},
		"platform":OS.get_name(),"display":DisplayServer.get_name(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"render_thread_inline":RenderingServer.is_on_render_thread(),
		"queued_observations":queued_observations,"diagnostics":diagnostics,
		"scope":"Extra reads are post-burst and post-original first-read oracle only. Any original pixel failure remains a failure. No gameplay or performance acceptance."}
	if not diagnostic_output.is_empty():
		var writer := FileAccess.open(diagnostic_output,FileAccess.WRITE)
		check(writer != null,"diagnostic receipt output opens")
		if writer != null: writer.store_string(JSON.stringify(report,"  ")+"\n")
	print("QUEUED_MATERIAL_DIAGNOSTIC_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"cases":diagnostics.size()}))
	quit(int(not failures.is_empty()))
