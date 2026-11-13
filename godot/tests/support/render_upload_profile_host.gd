extends "res://scripts/main.gd"

# Reuses the same override seams as support/render_copy_consumer.gd. All
# intervals are CPU elapsed time; nested stages must not be summed twice.
var measuring := false
var upload_samples: Array[Dictionary] = []
var publication_samples: Array[Dictionary] = []
var validation_usec := 0
var patch_usec := 0
var submission_usec := 0
var main_usec := 0
var shader_usec := 0
var _seen_publication := -1
var _material_generated_usec := 0
var _material_serial := -1
var _material_generation := -1

func record_render_payload(snapshot: CyberSimulationSnapshot) -> void:
	_material_generated_usec=snapshot.render_generated_usec
	_material_serial=snapshot.render_snapshot_serial
	_material_generation=snapshot.render_world_generation
	super.record_render_payload(snapshot)

func _actor_window_has_focus() -> bool:
	return true

func _process(delta: float) -> void:
	shader_usec = 0
	var start := Time.get_ticks_usec()
	super._process(delta)
	main_usec = Time.get_ticks_usec() - start

func update_shader_parameters() -> void:
	var start := Time.get_ticks_usec()
	super.update_shader_parameters()
	shader_usec += Time.get_ticks_usec() - start

func validate_render_patch_payload(rectangles: PackedInt32Array, cells: PackedByteArray, channels: int) -> String:
	var start := Time.get_ticks_usec()
	var result: String = super.validate_render_patch_payload(rectangles, cells, channels)
	validation_usec += Time.get_ticks_usec() - start
	return result

func apply_render_patches_to_image(rectangles: PackedInt32Array, cells: PackedByteArray, channels: int) -> bool:
	var start := Time.get_ticks_usec()
	var result: bool = super.apply_render_patches_to_image(rectangles, cells, channels)
	patch_usec += Time.get_ticks_usec() - start
	return result

func update_render_texture() -> void:
	var start := Time.get_ticks_usec()
	super.update_render_texture()
	submission_usec += Time.get_ticks_usec() - start

func upload_texture_patches(rectangles: PackedInt32Array, cells: PackedByteArray, revision: int, channels: int) -> bool:
	validation_usec = 0
	patch_usec = 0
	submission_usec = 0
	var start := Time.get_ticks_usec()
	var result: bool = super.upload_texture_patches(rectangles, cells, revision, channels)
	var ended := Time.get_ticks_usec()
	if measuring:
		var metrics: Dictionary = render_upload_metrics.duplicate(true)
		var submit_us: int = int(metrics.get("texture_update_usec",submission_usec))
		if metrics.has("source_create_usec"):
			submit_us = int(metrics.source_create_usec) + int(metrics.get("blit_submit_usec", 0))
		var area:=0
		var max_width:=0
		var max_height:=0
		for offset: int in range(0,rectangles.size(),6):
			area+=rectangles[offset+2]*rectangles[offset+3]
			max_width=maxi(max_width,rectangles[offset+2])
			max_height=maxi(max_height,rectangles[offset+3])
		upload_samples.append({"accepted":result,"revision":revision,
			"render_serial":_material_serial,"generation":_material_generation,
			"material_generated_usec":_material_generated_usec,
			"material_to_submit_ms":float(ended-_material_generated_usec)/1000.0 if _material_generated_usec>0 else null,
			"start_usec":start,"end_usec":ended,
			"upload_ms":float(ended-start)/1000.0,
			"cpu_patch_ms":float(patch_usec)/1000.0,
			"validation_ms":float(validation_usec)/1000.0,
			"image_maintenance_ms":float(maxi(0,patch_usec-validation_usec))/1000.0,
			"submit_ms":float(submit_us)/1000.0,
			"dirty_bytes":cells.size(),"patch_count":rectangles.size()/6,
			"patch_area_sum_including_overlap":area,"maximum_patch_width":max_width,"maximum_patch_height":max_height,
			"logical_bytes":int(metrics.get("logical_staging_bytes",world_extent.x*world_extent.y*channels)),
			"strategy":render_upload_strategy_override,"metrics":metrics})
	return result

func consume_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	if measuring and snapshot.serial != _seen_publication:
		_seen_publication = snapshot.serial
		publication_samples.append({"serial":snapshot.serial,"render_serial":snapshot.render_snapshot_serial,
			"generation":snapshot.render_world_generation,"revision":snapshot.world_revision,
			"tick":snapshot.tick_index,"native_tick_ms":snapshot.simulation_time_ms,
			"worker_step_ms":snapshot.worker_step_time_ms,"snapshot_copy_ms":snapshot.snapshot_copy_time_ms,
			"render_exchange_ms":snapshot.render_exchange_time_ms,
			"snapshot_publication_ms":snapshot.snapshot_publication_time_ms,
			"hard_surface_packet_ms":snapshot.hard_surface_packet_time_ms,
			"publication_to_consume_ms":float(Time.get_ticks_usec()-snapshot.published_usec)/1000.0,
			"active_blocks":snapshot.active_blocks_last_tick,"scanned":snapshot.scanned_last_tick,
			"actual_native_worker_capacity":snapshot.scheduler_thread_capacity_hint,
			"moves":snapshot.moves_last_tick,"worker_overruns":snapshot.worker_overruns})
	super.consume_render_snapshot(snapshot)
