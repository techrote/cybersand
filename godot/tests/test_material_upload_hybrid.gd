extends SceneTree

# Exact per-publication material/history oracle on an actual graphical backend.
const Context = preload("res://tests/palette_qualification_context.gd")
const Hybrid = preload("res://scripts/material_upload_hybrid.gd")
const SIZE := Vector2i(513, 513)
var checks := 0
var failures: Array[String] = []
var records: Array = []
var output_path := "user://material-upload-hybrid.json"


func _init() -> void:
	call_deferred("_run")


func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error("MATERIAL_UPLOAD_HYBRID: " + label)


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_path = arg.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless":
		_expect(false, "graphical backend required")
		_finish()
		return
	root.size = Vector2i(320, 240)
	await process_frame
	for fmt: Image.Format in [Image.FORMAT_R8, Image.FORMAT_RG8]:
		await _sequence(fmt)
	_finish()


func _sequence(fmt: Image.Format) -> void:
	var h := Hybrid.new()
	var source := _pattern(fmt)
	var channels := 1 if fmt == Image.FORMAT_R8 else 2
	var label := "R8" if channels == 1 else "RG8"
	_expect(h.initialize(source, 1, 4), label + " initializes compact pair")
	if not h.initialized:
		return
	_expect(h.current is ImageTexture and h.previous is ImageTexture, label + " initial resources compact")
	_check_texture(h.current, source, label + " initial current")
	_check_texture(h.previous, source, label + " initial previous")
	var serial := 1
	var generation := 4
	# First sustained sparse run enters only after its four accepted publications,
	# seeds exactly two destinations, then repairs a reused slot's entire history.
	for i: int in range(12):
		serial += 1
		var old: Image = source.duplicate()
		var rect := Rect2i(2 + (i % 2) * 128, 3, 4, 4)
		source.fill_rect(rect, Color8((i * 13 + 17) % 256, (i * 29) % 256, 0, 255))
		var accepted: Dictionary = h.publish(source, _metadata([rect], channels), serial, generation, false)
		_check_publication(h, accepted, source, old, label + " sparse " + str(i))
		if i < 3:
			_expect(accepted.metrics.mode == "compact_full", label + " sparse dwell " + str(i))
		elif i < 5:
			_expect(accepted.metrics.mode == "transition_seed", label + " measured seed " + str(i))
		else:
			_expect(accepted.metrics.mode == "partial_blit", label + " sparse history repair " + str(i))
		await process_frame
	_expect(h._seed_blits_total == 2, label + " exactly two seeds in initial sparse epoch")
	_expect(h._source_pool.size() <= h.MAX_POOLED_STAGING_TEXTURES,
		label + " staging pool count bounded")
	_expect(h._pooled_bytes <= h.MAX_POOLED_STAGING_BYTES, label + " staging pool bytes bounded")
	# Dense/sparse alternation must never pay a full drawable reseed. Each current
	# and previous readback remains exact across the compact/drawable transition.
	var seeds_before: int = h._seed_blits_total
	for i: int in range(12):
		serial += 1
		var old: Image = source.duplicate()
		var full := i % 2 == 0
		var rect := Rect2i(Vector2i.ZERO, SIZE) if full else Rect2i(512, 512, 1, 1)
		source.fill_rect(rect, Color8((i * 19 + 41) % 256, (i * 37) % 256, 0, 255))
		var accepted: Dictionary = h.publish(source, _metadata([rect], channels), serial, generation, full)
		_check_publication(h, accepted, source, old, label + " dense alternating " + str(i))
		_expect(h.current is ImageTexture and accepted.metrics.mode == "compact_full",
			label + " dense/sparse alternation stays compact " + str(i))
		_expect(accepted.metrics.blit_count == 0 and accepted.metrics.texture_allocations == 0,
			label + " dense fallback never blits or replaces resources " + str(i))
		await process_frame
	_expect(h._seed_blits_total == seeds_before, label + " no alternating seed storm")
	# Sparse returns after dense history; nonconsecutive locations require the
	# reused temporal target to repair more than the current patch alone.
	for i: int in range(9):
		serial += 1
		var old: Image = source.duplicate()
		var rect := Rect2i(10 + (i % 3) * 128, 200, 1, 1)
		source.fill_rect(rect, Color8(100 + i, 200 - i, 0, 255))
		var accepted: Dictionary = h.publish(source, _metadata([rect], channels), serial, generation, false)
		_check_publication(h, accepted, source, old, label + " sparse reentry " + str(i))
		await process_frame
	_expect(h._seed_blits_total == seeds_before + 2, label + " exactly two reentry seeds")
	# Ordinary full refresh is compact but preserves the accepted previous image.
	serial += 1
	var old: Image = source.duplicate()
	source.fill(Color8(7, 254, 0, 255))
	var full_metadata := _metadata([Rect2i(Vector2i.ZERO, SIZE)], channels)
	var full_result: Dictionary = h.publish(source, full_metadata, serial, generation, true)
	_check_publication(h, full_result, source, old, label + " full refresh")
	_expect(full_result.metrics.destination_write_bytes == SIZE.x * SIZE.y * channels,
		label + " full fallback retains compact channel width")
	# Refusals preserve accepted GPU identities, both complete images and serials.
	var state := _state(h)
	var invalid := [
		{"metadata": full_metadata, "serial": serial, "generation": generation, "full": true},
		{"metadata": PackedInt32Array(), "serial": serial + 1, "generation": generation, "full": false},
		{"metadata": _metadata([Rect2i(512, 512, 2, 1)], channels), "serial": serial + 1, "generation": generation, "full": false},
		{"metadata": _metadata([Rect2i(0, 0, 1, 1)], channels), "serial": serial + 1, "generation": generation + 1, "full": false},
		{"metadata": full_metadata, "serial": serial + 1, "generation": generation - 1, "full": true},
	]
	for i: int in range(invalid.size()):
		var item: Dictionary = invalid[i]
		var refused: Dictionary = h.publish(source, item.metadata, item.serial, item.generation, item.full)
		_expect(not refused.accepted, label + " expected refusal " + str(i))
		_expect(_state(h) == state, label + " refusal preserves full accepted state " + str(i))
	# Generation replacement is admitted only with complete transport coverage.
	serial += 1
	generation += 1
	old = source.duplicate()
	source = _pattern(fmt)
	var replaced: Dictionary = h.publish(source, full_metadata, serial, generation, true)
	_check_publication(h, replaced, source, old, label + " generation replacement")
	_expect(replaced.metrics.seed_blit_count == 0, label + " reset never full drawable blits")
	await process_frame
	# Deliberately publish without a new engine draw boundary. Immutable staging
	# must remain bounded and fall back to compact upload rather than reject state
	# or reuse source textures while an earlier draw may still reference them.
	var capacity_fallbacks := 0
	for i: int in range(42):
		serial += 1
		old = source.duplicate()
		var rect := Rect2i(7, 11, 1, 1)
		source.fill_rect(rect, Color8(10 + i, 180 - i, 0, 255))
		var result: Dictionary = h.publish(source, _metadata([rect], channels), serial, generation, false)
		_check_publication(h, result, source, old, label + " retained staging " + str(i))
		if result.metrics.full_reason == "staging_capacity":
			capacity_fallbacks += 1
		_expect(h._pending_staging_bytes <= h.MAX_PENDING_STAGING_BYTES,
			label + " pending bytes bounded " + str(i))
		_expect(h._staging_batches.size() <= h.MAX_PENDING_BATCHES,
			label + " pending batches bounded " + str(i))
	_expect(capacity_fallbacks > 0, label + " missing draw boundary causes explicit compact recovery")
	await process_frame
	h.close()
	_expect(not h.initialized and h.current == null and h.previous == null,
		label + " shutdown releases texture bindings")
	_expect(h._source_pool.is_empty() and h._drawables.is_empty() and h._compact.is_empty(),
		label + " shutdown releases every retained resource")
	# Engine Lab can adopt an already accepted pair without flattening history.
	var accepted_current := ImageTexture.create_from_image(source)
	var previous_image := _pattern(fmt)
	var accepted_previous := ImageTexture.create_from_image(previous_image)
	_expect(h.initialize(source, serial, generation, accepted_current, accepted_previous),
		label + " adopt accepted external history")
	_expect(h.current == accepted_current and h.previous == accepted_previous,
		label + " adoption preserves exact resource bindings")
	_check_texture(h.previous, previous_image, label + " adopted previous")
	old = source.duplicate()
	source.fill_rect(Rect2i(1, 1, 1, 1), Color8(254, 1, 0, 255))
	var adopted: Dictionary = h.publish(source, _metadata([Rect2i(1, 1, 1, 1)], channels),
		serial + 1, generation, false)
	_check_publication(h, adopted, source, old, label + " first publication after adoption")
	_check_texture(accepted_current, old, label + " adopted source remains immutable")
	h.close()


func _pattern(fmt: Image.Format) -> Image:
	var channels := 1 if fmt == Image.FORMAT_R8 else 2
	var bytes := PackedByteArray()
	bytes.resize(SIZE.x * SIZE.y * channels)
	for i: int in range(SIZE.x * SIZE.y):
		bytes[i * channels] = i % 256
		if channels == 2:
			bytes[i * channels + 1] = (i * 29) % 256
	return Image.create_from_data(SIZE.x, SIZE.y, false, fmt, bytes)


func _metadata(rectangles: Array[Rect2i], channels: int) -> PackedInt32Array:
	var metadata := PackedInt32Array()
	var offset := 0
	for rect: Rect2i in rectangles:
		metadata.append_array(PackedInt32Array([rect.position.x, rect.position.y,
			rect.size.x, rect.size.y, offset, rect.size.x * channels]))
		offset += rect.get_area() * channels
	return metadata


func _rgba(image: Image) -> PackedByteArray:
	var copy: Image = image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()


func _sha(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _check_texture(texture: Texture2D, wanted: Image, label: String) -> void:
	var actual := texture.get_image()
	_expect(actual != null and actual.get_size() == wanted.get_size(), label + " readback dimensions")
	if actual == null or actual.get_size() != wanted.get_size():
		return
	var received := _rgba(actual)
	var expected := _rgba(wanted)
	_expect(received == expected, label + " exact complete material/condition bytes")
	records.append({"case": label, "equal": received == expected,
		"actual_sha256": _sha(received), "expected_sha256": _sha(expected)})


func _check_publication(h: RefCounted, result: Dictionary, source: Image, old: Image, label: String) -> void:
	_expect(result.accepted, label + " accepted")
	if not result.accepted:
		return
	_expect(h.current != h.previous, label + " independent temporal resources")
	_check_texture(h.current, source, label + " current")
	_check_texture(h.previous, old, label + " previous")
	records.append({"case": label, "metrics": result.metrics})


func _state(h: RefCounted) -> Dictionary:
	return {"serial": h.accepted_serial, "generation": h.accepted_generation,
		"current_rid": h.current.get_rid(), "previous_rid": h.previous.get_rid(),
		"current": _rgba(h.current.get_image()), "previous": _rgba(h.previous.get_image()),
		"streak": h._sparse_streak, "seed_total": h._seed_blits_total,
		"journals": [h._dirty_slots[0].duplicate(), h._dirty_slots[1].duplicate()]}


func _finish() -> void:
	var receipt := {"schema": "material-upload-hybrid-correctness-v1", "ok": failures.is_empty(),
		"checks": checks, "failures": failures, "records": records,
		"context": Context.identity(get_script().resource_path, Hybrid.COPY_SHADER),
		"scope": "graphical exact current/previous texture bytes for every publication; no scanout or GPU-performance claim"}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write graphical material-upload receipt")
		quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("MATERIAL_UPLOAD_HYBRID ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "output": output_path}))
	quit(0 if failures.is_empty() else 1)
