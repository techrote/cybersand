extends SceneTree

# Actual graphical ImageTexture pixel readback for the ordinary overlay cache.
# Godot4.7 DummyRenderer texture_2d_update is a no-op; headless is unsupported.
# These authored publications test identity handling, not native physics.
const Overlay = preload("res://scripts/object_shard_workbench_overlay.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _publication(sequence: int, generation: int, body_generation: int, session: int,
		width: int, height: int, color: Color) -> Dictionary:
	var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
	image.fill(color)
	return {"session":session,"world_generation":2,"world_incarnation":3,"publication_sequence":sequence,
		"shards":[{"session":session,"id":1,"generation":generation,"body_generation":body_generation,
			"material_revision":7,"width":width,"height":height,"owns_inventory":true,"rgba":image.get_data()}]}

func _pixels(overlay: Control, expected: Dictionary) -> bool:
	if not overlay.textures.has(1): return false
	var actual: Image = overlay.textures[1].texture.get_image()
	var shard: Dictionary = expected.shards[0]
	return actual!=null and actual.get_width()==int(shard.width) and actual.get_height()==int(shard.height) \
		and actual.get_data()==shard.rgba

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Overlay texture pixel qualification requires a graphical renderer; DummyRenderer does not update textures")
		quit(1)
		return
	var overlay: Control = Overlay.new()
	root.add_child(overlay)
	var first: Dictionary = _publication(10,1,1,4,2,1,Color.RED)
	overlay.present(first)
	_expect(_pixels(overlay,first),"first native-style publication uploads exact RGBA pixels")
	var original_texture: ImageTexture = overlay.textures[1].texture
	var same: Dictionary = first.duplicate(true)
	same.publication_sequence = 11
	overlay.present(same)
	_expect(overlay.textures[1].texture==original_texture and _pixels(overlay,same),
		"unchanged complete identity reuses the same texture across pose-only publications")
	var recycled: Dictionary = _publication(12,2,1,4,2,1,Color.GREEN)
	overlay.present(recycled)
	await process_frame
	_expect(_pixels(overlay,recycled),"same slot and material revision with a new generation cannot retain old pixels")
	var new_body: Dictionary = _publication(13,2,2,4,2,1,Color.BLUE)
	overlay.present(new_body)
	await process_frame
	_expect(_pixels(overlay,new_body),"body incarnation participates in texture identity independently of material revision")
	var resized: Dictionary = _publication(14,2,2,4,3,2,Color.YELLOW)
	overlay.present(resized)
	_expect(_pixels(overlay,resized),"different dimensions rebuild storage even when all local revision numbers repeat")
	var new_session: Dictionary = _publication(14,2,2,5,3,2,Color.MAGENTA)
	overlay.present(new_session)
	await process_frame
	_expect(_pixels(overlay,new_session),"a new native session can reuse both publication sequence and shard revisions")
	var new_world: Dictionary = new_session.duplicate(true)
	new_world.world_generation = 3
	new_world.world_incarnation = 4
	new_world.shards[0].rgba = resized.shards[0].rgba
	overlay.present(new_world)
	await process_frame
	_expect(_pixels(overlay,new_world),"World identity also invalidates cached pixels if an intermediate clear is coalesced")
	var malformed: Dictionary = _publication(15,3,3,5,3,2,Color.CYAN)
	malformed.shards[0].rgba = PackedByteArray([1,2,3,4])
	overlay.present(malformed)
	_expect(not overlay.textures.has(1),"invalid replacement payload never renders a retired owner's cached image")
	overlay.present(_publication(16,4,4,5,3,2,Color.CYAN))
	overlay.present({"session":5,"world_generation":2,"world_incarnation":3,"publication_sequence":17,"shards":[]})
	_expect(overlay.textures.is_empty(),"a published empty owning inventory releases its image cache")
	overlay.present(first)
	overlay.clear()
	_expect(overlay.frame.is_empty() and overlay.textures.is_empty() and overlay.publication_sequence==-1 \
		and overlay._publication_identity.is_empty(),"World retirement clears publication and every ownership-qualified texture")
	var replacement: Dictionary = _publication(10,1,1,4,2,1,Color.WHITE)
	overlay.present(replacement)
	_expect(_pixels(overlay,replacement),"fresh World after clear can safely reuse every prior numeric identity")
	overlay.queue_free()
	await process_frame
	print(JSON.stringify({"schema":"objectshard-m4-overlay-identity-v1", "source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"checks":checks,"failures":failures,"display_driver":DisplayServer.get_name(),
		"scope":"actual graphical texture storage readback; synthetic native-style publications; no native or Rapier claims"}))
	quit(0 if failures.is_empty() else 1)
