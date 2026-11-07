extends RefCounted
## WB-AGENT-001 main-thread-only render join for one immutable owner observation.
## No World access; it refuses absent/mismatched post-draw framebuffer evidence.
## A model may never treat a native-only observation as a matched image.

const MAX_CAPTURE_BYTES: int = 16 * 1024 * 1024


static func _pending(reason: String, native: Dictionary) -> Dictionary:
	return {
		"status":"pending",
		"reason":reason,
		"observation_id":native.get("observation_id",""),
		"identity":native.get("identity",{}).duplicate(true),
		"image_status":"unavailable"
	}


static func _matched(host: Control, identity: Dictionary) -> bool:
	if host.latest_snapshot == null or not host.paused:
		return false
	if host.simulation_worker.has_failed() or host.simulation_worker.agent_manual_intent_revision() \
			!= int(identity.get("manual_intent_revision",-1)):
		return false
	var snapshot: CyberSimulationSnapshot = host.latest_snapshot
	return (
		host.last_uploaded_world_generation == int(identity.get("world_generation",-1))
		and host.last_uploaded_revision == int(identity.get("world_revision",-1))
		and host.last_uploaded_render_snapshot_serial > 0
		and snapshot.render_snapshot_serial == host.last_uploaded_render_snapshot_serial
		and snapshot.render_world_generation == host.last_uploaded_world_generation
		and snapshot.world_revision == host.last_uploaded_revision
		and snapshot.render_tick_index == int(identity.get("completed_tick",-1))
		and snapshot.tick_index == int(identity.get("completed_tick",-1))
		and snapshot.simulation_world_revision == int(identity.get("world_revision",-1))
	)


## Must be awaited on the existing application's MAIN thread. The only
## capture occurs after RenderingServer's real post-draw notification.
## Rechecks the same identities AFTER the potentially delayed frame await.
static func join_after_draw(host: Control, native: Dictionary) -> Dictionary:
	if str(native.get("status","")) != "native_observed" \
			or not native.has("identity"):
		return _pending("no_authoritative_native_observation",native)
	var identity: Dictionary = native.identity
	if not _matched(host,identity):
		return _pending("native_and_uploaded_render_not_matched",native)
	await RenderingServer.frame_post_draw
	if not _matched(host,identity):
		return _pending("publication_changed_during_draw",native)
	var viewport: Viewport = host.get_viewport()
	if viewport == null or viewport.get_texture() == null:
		return _pending("framebuffer_not_available",native)
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return _pending("framebuffer_not_available",native)
	var bytes: PackedByteArray = image.save_png_to_buffer()
	if bytes.is_empty() or bytes.size() > MAX_CAPTURE_BYTES:
		return _pending("framebuffer_capture_limit",native)
	# No yield between this final identity check and the copied result.
	if not _matched(host,identity):
		return _pending("publication_changed_after_capture",native)
	var joined: Dictionary = native.duplicate(true)
	joined["status"] = "observed"
	joined["image_status"] = "matched_post_draw"
	joined["framebuffer_png"] = bytes
	joined["render_identity"] = {
		"render_snapshot_serial":host.last_uploaded_render_snapshot_serial,
		"world_generation":host.last_uploaded_world_generation,
		"world_revision":host.last_uploaded_revision,
		"tick":host.latest_snapshot.render_tick_index,
		"viewport_width":image.get_width(),
		"viewport_height":image.get_height()
	}
	return joined
