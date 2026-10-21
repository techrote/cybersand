class_name CyberSemanticPlaneRuntime
extends "res://scripts/depth/depth_layer_runtime.gd"

# A complete immutable GEN-005 bundle is admitted into four private native
# owners. Camera, renderer, chunk completion order and material overlap are not
# inputs to this owner. All public packets and lifecycle records are copies.
const ActorSession = preload("res://scripts/actor_prototype_session.gd")
const ActorCatalog = preload("res://scripts/actor_rig_catalog.gd")
const MAX_FIXTURES: int = 1024
const MAX_LINKS: int = 2048
const MAX_PROJECTIONS: int = 8192
const MAX_FEATURES: int = 8192
const MAX_FIXTURE_AREA: int = 512
const MAX_FIXTURE_WRITES_PER_TICK: int = 8192
const MAX_FIXTURE_LIFETIME_WRITES: int = 4194304
const MAX_SCHEDULE_TICK: int = 360000
const MAX_REPEAT: int = 10000
const MAX_EVENT_RATE: int = 256
const MAX_PACKET_BYTES: int = 67108864
const MAX_METADATA_NODES: int = 262144
const MAX_RETIRED_REVISIONS: int = 128
const OBSERVATION_KEYS: Array[String] = ["accepted", "id", "revision", "generation", "link_id", "link_revision", "source_feature", "source_revision", "target_feature", "target_revision", "source_plane", "target_plane", "source_tick", "serial", "cell", "radius", "material"]

var _bundle: Dictionary = {}
var _features: Dictionary = {}
var _fixtures: Dictionary = {}
var _links: Dictionary = {}
var _fixture_states: Dictionary = {}
var _link_states: Dictionary = {}
var _issued: Dictionary = {}
var _observation_serial: int = 0
var _origin: Vector2i = Vector2i.ZERO
var _commit_generation: int = 0
var _applications: int = 0
var _fixture_writes: int = 0
var _cleanup_writes: int = 0
var _event_rate: int = MAX_EVENT_RATE
var _event_ticks: Dictionary = {}
var _event_counts: Dictionary = {}
var _last_transition: Dictionary = {}
var _transition_counts: Dictionary = {"install": 0, "activate": 0, "reset": 0, "retire": 0, "duplicate": 0}
var _metadata_nodes: int = 0
var _retired_revisions: Dictionary = {}
var _actor_session: CyberActorPrototypeSession
var _pending_actor_session: CyberActorPrototypeSession
var _pending_actor_definitions: Array[Dictionary] = []
var _actor_indices: Dictionary = {}
var _actor_receipts: Dictionary = {}

func install_bundle(candidate: Dictionary, expected_generation: int = -1) -> bool:
	if expected_generation != -1 and expected_generation != generation():
		last_error = "semantic_stale_admission_generation"
		return false
	last_error = _validate_bundle(candidate)
	if not last_error.is_empty():
		return false
	if not _bundle.is_empty() and candidate["id"] == _bundle["id"] and candidate["revision"] == _bundle["revision"]:
		if not _same_content(candidate, _bundle):
			last_error = "semantic_revision_content_conflict"
			return false
		_transition_counts["duplicate"] += 1
		_last_transition = _receipt("duplicate", str(candidate["id"]))
		last_error = ""
		return true
	var key: String = str(candidate["id"]) + "|" + str(candidate["revision"])
	if _retired_revisions.has(key):
		last_error = "semantic_retired_revision"
		return false
	if not _bundle.is_empty() and expected_generation == -1:
		last_error = "semantic_replacement_generation_required"
		return false
	if not _bundle.is_empty() and _retired_revisions.size() >= MAX_RETIRED_REVISIONS:
		last_error = "semantic_revision_history_capacity"
		return false
	return _publish(candidate, "install")

func install(candidate: Dictionary) -> bool:
	return install_bundle(candidate)

func reset_bundle(expected_generation: int = -1, revision: String = "") -> Dictionary:
	var error: String = _identity_error(expected_generation, revision)
	if not error.is_empty():
		return _reject(error)
	if not _publish(_bundle, "reset"):
		return _reject(last_error)
	return _last_transition.duplicate(true)

func activate_bundle(expected_generation: int = -1, revision: String = "") -> Dictionary:
	var error: String = _identity_error(expected_generation, revision)
	if not error.is_empty():
		return _reject(error)
	# Activation is idempotent. Completed/retired programmes cannot be revived
	# under the same incarnation; explicit reset constructs a new native world.
	for id: String in _fixture_states:
		if not _fixture_states[id]["retired"]:
			_fixture_states[id]["active"] = true
	for id: String in _link_states:
		if not _link_states[id]["retired"]:
			_link_states[id]["active"] = true
	return _receipt("activate", str(_bundle["id"]))

func retire_fixture(id: String, expected_generation: int, revision: String) -> Dictionary:
	var error: String = _identity_error(expected_generation, revision)
	if not error.is_empty():
		return _reject(error)
	if not _fixture_states.has(id):
		return _reject("semantic_unknown_fixture")
	return _retire_fixture(id)

func retire_link(id: String, expected_generation: int, revision: String) -> Dictionary:
	var error: String = _identity_error(expected_generation, revision)
	if not error.is_empty():
		return _reject(error)
	if not _link_states.has(id):
		return _reject("semantic_unknown_link")
	var receipt: Dictionary = _retire(_link_states, id)
	for serial: Variant in _issued.keys():
		if _issued[serial]["link_id"] == id:
			_issued.erase(serial)
	return receipt

func event_observation(link_id: String) -> Dictionary:
	if not _links.has(link_id):
		return _reject("semantic_unknown_link")
	var link: Dictionary = _links[link_id]
	if link["classification"] != "runtime":
		return _reject("semantic_link_is_not_runtime")
	if not _link_states[link_id]["active"] or _link_states[link_id]["retired"]:
		return _reject("semantic_link_retired")
	if _issued.size() >= MAX_PENDING_COMMANDS:
		return _reject("semantic_observation_capacity")
	var source: String = str(link["source_plane"])
	if bool(_layers[source]["failed"]):
		return _reject("source_failed")
	_observation_serial += 1
	var bounds: Rect2i = link["bounds"]
	var observation: Dictionary = {
		"accepted": true, "id": _bundle["id"], "revision": _bundle["revision"],
		"generation": generation(), "link_id": link_id, "link_revision": link["revision"],
		"source_feature": link["source_feature"], "target_feature": link["target_feature"],
		"source_revision": _features[link["source_feature"]]["revision"],
		"target_revision": _features[link["target_feature"]]["revision"],
		"source_plane": source, "target_plane": link["target_plane"],
		"source_tick": layer_tick(source), "serial": _observation_serial,
		"cell": bounds.position + bounds.size / 2,
		"radius": link["radius"], "material": link["material"],
	}
	_issued[_observation_serial] = observation.duplicate(true)
	return observation

func issue_observation(link_id: String) -> Dictionary:
	return event_observation(link_id)

func submit_event(command: Dictionary) -> Dictionary:
	# The only caller-adjustable observation fields are the bounded center and
	# radius. Endpoint identity, route, material, generation and native source
	# tick come from a copied owner-issued observation, consumed once on success.
	if command.size() != OBSERVATION_KEYS.size():
		return _reject("semantic_event_fields")
	for key: Variant in command:
		if not key in OBSERVATION_KEYS:
			return _reject("semantic_event_fields")
	if typeof(command.get("serial")) != TYPE_INT or not _issued.has(command["serial"]):
		return _reject("semantic_observation_missing_or_consumed")
	var issued: Dictionary = _issued[command["serial"]]
	for key: String in OBSERVATION_KEYS:
		if key != "cell" and key != "radius" and command.get(key) != issued[key]:
			return _reject("semantic_observation_identity_mismatch")
	var error: String = _identity_error(int(command["generation"]), str(command["revision"]))
	if not error.is_empty():
		return _reject(error)
	var id: String = str(command["link_id"])
	if not _links.has(id) or _link_states[id]["retired"] or not _link_states[id]["active"]:
		return _reject("semantic_link_retired")
	var link: Dictionary = _links[id]
	var source: String = str(link["source_plane"])
	var target: String = str(link["target_plane"])
	if layer_tick(source) != int(command["source_tick"]):
		_issued.erase(command["serial"])
		return _reject("semantic_observation_stale_tick")
	if not command["cell"] is Vector2i or typeof(command["radius"]) != TYPE_INT:
		return _reject("semantic_event_geometry")
	var cell: Vector2i = command["cell"]
	var radius: int = command["radius"]
	if radius < 0 or radius > int(link["radius"]) or (link["effect"] == "blast" and radius < 4):
		return _reject("semantic_event_radius")
	if not _disc_enclosed(link["bounds"], cell, radius):
		return _reject("semantic_event_outside_link")
	var tick: int = layer_tick(target)
	var state: Dictionary = _link_states[id]
	var link_count: int = int(state["event_count"]) if int(state["event_tick"]) == tick else 0
	var total_count: int = int(_event_counts.get(target, 0)) if int(_event_ticks.get(target, -1)) == tick else 0
	if link_count >= int(link["max_events_per_tick"]) or total_count >= _event_rate:
		return _reject("semantic_event_rate_budget")
	var result: Dictionary = super.route_event(source, target, str(link["effect"]), cell - _origin,
		radius, int(link["material"]), generation())
	if not result.get("accepted", false):
		return result
	_commands.back()["semantic_link"] = id
	_commands.back()["semantic_revision"] = _bundle["revision"]
	_commands.back()["semantic_link_revision"] = link["revision"]
	state["event_tick"] = tick
	state["event_count"] = link_count + 1
	state["events"] += 1
	_event_ticks[target] = tick
	_event_counts[target] = total_count + 1
	_issued.erase(command["serial"])
	result["link_id"] = id
	result["revision"] = _bundle["revision"]
	return result

func route_link_event(observation: Dictionary, cell: Vector2i, radius: int = -1) -> Dictionary:
	var command: Dictionary = observation.duplicate(true)
	command["cell"] = cell
	if radius >= 0:
		command["radius"] = radius
	return submit_event(command)

func lifecycle_stats() -> Dictionary:
	return {
		"id": _bundle.get("id", ""), "revision": _bundle.get("revision", ""),
		"generation": generation(), "commit_generation": _commit_generation,
		"fixtures": _fixture_states.duplicate(true), "links": _link_states.duplicate(true),
		"registered_fixtures": _fixtures.size(), "registered_links": _links.size(),
		"registered_actors": _actor_indices.size(), "actor_receipts": _actor_receipts.duplicate(true),
		"applications": _applications, "fixture_cell_writes": _fixture_writes,
		"cleanup_cell_writes": _cleanup_writes, "outstanding_observations": _issued.size(),
		"retired_revisions": _retired_revisions.size(), "transition_counts": _transition_counts.duplicate(), "last_transition": _last_transition.duplicate(true),
	}

func actor_snapshot() -> Dictionary:
	var result: Dictionary = _actor_session.snapshot() if _actor_session != null else {}
	result["generation"] = generation()
	result["revision"] = _bundle.get("revision", "")
	result["plane"] = "play"
	result["world_origin"] = _origin
	result["semantic_ids"] = _actor_indices.keys()
	result["count"] = _actor_indices.size()
	return result

func submit_actor_action(command: Dictionary) -> Dictionary:
	for field: String in ["generation", "epoch", "sequence", "observed_tick", "lease_ticks"]:
		if typeof(command.get(field)) != TYPE_INT:
			return _reject("semantic_actor_action_identity")
	if not command.get("revision") is String or command["generation"] != generation() or command["revision"] != _bundle.get("revision"):
		return _reject("semantic_actor_stale_identity")
	var identity: Variant = command.get("actor_id")
	if not identity is String or not _actor_indices.has(identity) or _actor_session == null:
		return _reject("semantic_actor_unknown")
	if not command.get("movement") is Vector2 or typeof(command.get("primary")) != TYPE_BOOL or typeof(command.get("secondary")) != TYPE_BOOL:
		return _reject("semantic_actor_action_type")
	var index: int = _actor_indices[identity]
	var actor: Dictionary = _bundle["actors"][index]
	if command.get("producer") != actor["producer"]:
		return _reject("semantic_actor_wrong_producer")
	if bool(_layers["play"]["paused"]) or float(_layers["play"]["rate_hz"]) <= 0.0 or bool(_layers["play"]["failed"]):
		return _reject("semantic_actor_play_paused_or_failed")
	var accepted: bool = _actor_session.submit_action(index, command["epoch"], command["sequence"],
		command["observed_tick"], command["movement"], command["primary"], command["secondary"],
		command["lease_ticks"], StringName(actor["producer"]))
	return _receipt("actor_action", identity) if accepted else _reject("semantic_actor_mailbox_rejected")

func configure_rates(rates: Dictionary) -> bool:
	if not super.configure_rates(rates):
		return false
	_sync_actor_suspension(false)
	return true

func set_layer_paused(id: String, paused: bool) -> bool:
	if not super.set_layer_paused(id, paused):
		return false
	_sync_actor_suspension(false)
	return true

func advance(delta: float, paused: bool = false) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or delta > 3600.0:
		return super.advance(delta, paused)
	_sync_actor_suspension(paused)
	return super.advance(delta, paused)

func _sync_actor_suspension(paused: bool) -> void:
	if _actor_session != null and _layers.has("play"):
		_actor_session.set_suspended(paused or bool(_layers["play"]["paused"]) or float(_layers["play"]["rate_hz"]) <= 0.0)

func _prepare_candidate_owners(candidates: Dictionary, _authored_size: Vector2i) -> String:
	var session: CyberActorPrototypeSession = ActorSession.new()
	# The existing sampled owner can repair invalid spawns. Generation rejects
	# that case before configure so authored placement and provenance stay exact.
	for actor: Dictionary in _pending_actor_definitions:
		var body: Vector2 = ActorCatalog.entry(StringName(actor["model"])).get("body_size", Vector2(8, 14))
		if candidates["play"].box_collides(actor["position"], body):
			return "semantic_actor_spawn_blocked"
	if not session.configure(_pending_actor_definitions, candidates["play"]):
		return "semantic_actor_owner_rejected"
	_pending_actor_session = session
	return ""

func _actor_definitions(actors: Array, origin: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor: Dictionary in actors:
		result.append({"model": actor["model"], "producer": actor["producer"],
			"position": Vector2(actor["position"] - origin)})
	return result

func _validate_actors(raw: Variant, features: Dictionary, projected: Dictionary,
		bounds: Rect2i, budgets: Dictionary) -> String:
	if not raw is Array or raw.size() > ActorSession.MAX_ACTORS:
		return "semantic_actor_capacity"
	if budgets.has("max_actors") and (typeof(budgets["max_actors"]) != TYPE_INT or budgets["max_actors"] < 0 or raw.size() > budgets["max_actors"]):
		return "semantic_actor_capacity"
	var ids: Dictionary = {}
	for actor: Variant in raw:
		if not actor is Dictionary or not _string(actor.get("id")) or not _revision(actor.get("revision")):
			return "semantic_actor_record"
		if ids.has(actor["id"]):
			return "semantic_actor_duplicate"
		ids[actor["id"]] = true
		if actor.get("plane") != "play" or actor.get("lifecycle") != "play-owner-v1":
			return "semantic_actor_owner"
		var feature: Variant = actor.get("feature_id")
		if not features.has(feature) or not projected.has(str(feature) + "|play"):
			return "semantic_actor_feature"
		if not actor.get("position") is Vector2i or not actor.get("model") is String or not actor.get("producer") in ["policy", "demo"]:
			return "semantic_actor_parameters"
		if not ActorCatalog.has_rig(StringName(actor["model"])):
			return "semantic_actor_model"
		var body: Vector2 = ActorCatalog.entry(StringName(actor["model"])).get("body_size", Vector2(8, 14))
		var footprint := Rect2i(actor["position"], Vector2i(ceili(body.x), ceili(body.y)))
		if not _inside_guard(bounds, footprint) or not _encloses(features[feature]["bounds"], footprint):
			return "semantic_actor_bounds"
	if not ActorSession.valid_definitions(_actor_definitions(raw, bounds.position)):
		return "semantic_actor_definitions"
	return ""

func bundle_metadata() -> Dictionary:
	var copy: Dictionary = _bundle.duplicate(true)
	copy.erase("layers")
	return copy

func snapshot_layer(id: String, force: bool = false) -> Dictionary:
	var packet: Dictionary = super.snapshot_layer(id, force)
	packet["bundle_id"] = _bundle.get("id", "")
	packet["bundle_revision"] = _bundle.get("revision", "")
	packet["commit_generation"] = _commit_generation
	packet["world_origin"] = _origin
	return packet

func material_at_world(id: String, cell: Vector2i) -> int:
	return material_at(id, cell - _origin)

# Raw mutation interfaces remain available on the original depth prototype.
# Semantic generation admits only installed finite fixtures and typed routes.
func reset(_definitions: Dictionary, _authored_size: Vector2i = WORLD_SIZE) -> bool:
	last_error = "semantic_complete_bundle_required"
	return false

func paint_disc(_id: String, _cell: Vector2i, _radius: int, _material: int) -> Dictionary:
	return _reject("semantic_registered_mutation_required")

func route_event(_source: String, _target: String, _kind: String, _cell: Vector2i,
		_radius: int, _material: int = Cell.FIRE, _requested_generation: int = -1) -> Dictionary:
	return _reject("semantic_registered_observation_required")

func scripted_blast(_cell: Vector2i, _radius: int, _requested_generation: int = -1) -> Dictionary:
	return _reject("semantic_registered_observation_required")

func set_weather(mode: String) -> bool:
	if mode != "off":
		last_error = "semantic_registered_fixture_required"
		return false
	return super.set_weather(mode)

func _publish(candidate: Dictionary, transition: String) -> bool:
	# Prepare every copied registry and fixed schedule before constructing Worlds.
	# No consumer callback occurs between base's all-world swap and the metadata
	# swap, so no packet can mix feature revisions from separate publications.
	var copy: Dictionary = candidate.duplicate(true)
	var next_features: Dictionary = {}
	var next_fixtures: Dictionary = {}
	var next_links: Dictionary = {}
	for feature: Dictionary in copy["features"]:
		next_features[feature["id"]] = feature
	for fixture: Dictionary in copy["fixtures"]:
		next_fixtures[fixture["id"]] = fixture
	for link: Dictionary in copy["links"]:
		next_links[link["id"]] = link
	var bounds: Rect2i = copy["bounds"]
	_pending_actor_definitions = _actor_definitions(copy.get("actors", []), bounds.position)
	_pending_actor_session = null
	if not super.reset(copy["layers"], bounds.size):
		_pending_actor_definitions.clear()
		_pending_actor_session = null
		return false
	if _actor_session != null:
		_actor_session.clear()
	_actor_session = _pending_actor_session
	_pending_actor_session = null
	_pending_actor_definitions.clear()
	if transition == "install" and not _bundle.is_empty():
		_retired_revisions[str(_bundle["id"]) + "|" + str(_bundle["revision"])] = true
	_bundle = copy
	_features = next_features
	_fixtures = next_fixtures
	_links = next_links
	_origin = bounds.position
	_commit_generation = generation()
	_actor_indices = {}
	_actor_receipts = {}
	for actor: Dictionary in copy.get("actors", []):
		_actor_indices[actor["id"]] = _actor_indices.size()
		_actor_receipts[actor["id"]] = {"install": _receipt("install", actor["id"]), "activate": _receipt("activate", actor["id"])}
	_fixture_states = {}
	_link_states = {}
	_issued.clear()
	_event_ticks.clear()
	_event_counts.clear()
	_applications = 0
	_fixture_writes = 0
	_cleanup_writes = 0
	_weather = "off"
	_event_rate = int(copy.get("budgets", {}).get("max_events_per_tick", MAX_EVENT_RATE))
	for id: String in IDS:
		_layers[id]["rate_hz"] = float(copy["rates"][id])
	for id: String in _fixtures:
		_fixture_states[id] = {"active": true, "retired": false, "fired": 0, "cleaned": false,
			"receipts": {"install": _receipt("install", id), "activate": _receipt("activate", id)}}
	for id: String in _links:
		_link_states[id] = {"active": true, "retired": false, "events": 0, "event_tick": -1, "event_count": 0,
			"receipts": {"install": _receipt("install", id), "activate": _receipt("activate", id)}}
	if transition == "reset":
		for id: String in _actor_receipts:
			_actor_receipts[id]["reset"] = _receipt("reset", id)
		for id: String in _fixture_states:
			_fixture_states[id]["receipts"]["reset"] = _receipt("reset", id)
		for id: String in _link_states:
			_link_states[id]["receipts"]["reset"] = _receipt("reset", id)
	_transition_counts[transition] += 1
	_transition_counts["activate"] += 1
	_last_transition = _receipt(transition, str(copy["id"]))
	last_error = ""
	return true

func _step_layer(id: String) -> bool:
	var tick: int = layer_tick(id)
	for fixture_id: String in _fixtures:
		var fixture: Dictionary = _fixtures[fixture_id]
		var state: Dictionary = _fixture_states[fixture_id]
		if fixture["plane"] != id or not state["active"] or state["retired"]:
			continue
		var first: int = fixture["first_tick"]
		var cleanup: int = fixture["cleanup_tick"]
		var rect: Rect2i = fixture["bounds"]
		var local: Vector2i = rect.position - _origin
		if cleanup > 0 and tick >= cleanup:
			if not state["cleaned"]:
				if not _worlds[id].diagnostic_fill_rect(local, rect.size, Cell.EMPTY):
					_fail_layer(id, "semantic_fixture_cleanup_failed:" + fixture_id)
					return false
				state["cleaned"] = true
				_cleanup_writes += rect.size.x * rect.size.y
			_retire_fixture(fixture_id)
			continue
		if tick < first or (tick - first) % int(fixture["period"]) != 0 or int(state["fired"]) >= int(fixture["repeat"]):
			continue
		if not _worlds[id].diagnostic_fill_rect(local, rect.size, int(fixture["material"])):
			_fail_layer(id, "semantic_fixture_source_failed:" + fixture_id)
			return false
		state["fired"] += 1
		_applications += 1
		_fixture_writes += rect.size.x * rect.size.y
		if int(state["fired"]) == int(fixture["repeat"]) and cleanup == 0:
			_retire_fixture(fixture_id)
	if not super._step_layer(id):
		return false
	if id == "play" and _actor_session != null:
		_actor_session.set_suspended(false)
		_actor_session.step(1.0 / float(_layers[id]["rate_hz"]), _worlds["play"])
	return true

func _flush_pending() -> void:
	var kept: Array[Dictionary] = []
	for command: Dictionary in _commands:
		var id: String = str(command.get("semantic_link", ""))
		if (not _links.has(id) or _link_states[id]["retired"] or not _link_states[id]["active"]
				or command.get("semantic_revision") != _bundle.get("revision")
				or command.get("semantic_link_revision") != _links[id]["revision"]):
			_discarded_commands += 1
		else:
			kept.append(command)
	_commands = kept
	super._flush_pending()

func _retire_fixture(id: String) -> Dictionary:
	var receipt: Dictionary = _retire(_fixture_states, id)
	# A link to a retired programme keeps its immutable provenance but loses
	# activation; it cannot become an orphan registration with write authority.
	for link_id: String in _links:
		if _links[link_id].get("fixture_id", "") == id:
			_retire(_link_states, link_id)
			for serial: Variant in _issued.keys():
				if _issued[serial]["link_id"] == link_id:
					_issued.erase(serial)
	return receipt

func _retire(states: Dictionary, id: String) -> Dictionary:
	var state: Dictionary = states[id]
	if not state["retired"]:
		state["active"] = false
		state["retired"] = true
		state["receipts"]["retire"] = _receipt("retire", id)
		_transition_counts["retire"] += 1
	return state["receipts"]["retire"].duplicate(true)

func _receipt(action: String, identity: String) -> Dictionary:
	return {"accepted": true, "action": action, "identity": identity,
		"generation": generation(), "revision": _bundle.get("revision", ""),
		"id": _bundle.get("id", "")}

func _identity_error(expected_generation: int, revision: String) -> String:
	if _bundle.is_empty():
		return "semantic_bundle_not_installed"
	if expected_generation != -1 and expected_generation != generation():
		return "semantic_stale_generation"
	if not revision.is_empty() and revision != _bundle["revision"]:
		return "semantic_stale_revision"
	return ""

func _validate_bundle(candidate: Dictionary) -> String:
	_metadata_nodes = 0
	var measured: int = _measure(candidate, 0)
	if measured < 0 or measured > MAX_PACKET_BYTES:
		return "semantic_publication_budget"
	if candidate.has("complete") and (typeof(candidate["complete"]) != TYPE_BOOL or not candidate["complete"]):
		return "semantic_incomplete_bundle"
	if typeof(candidate.get("schema")) != TYPE_INT or candidate["schema"] != 1:
		return "semantic_bundle_schema"
	if not _string(candidate.get("id"), 256) or not _revision(candidate.get("revision")):
		return "semantic_bundle_identity"
	if not candidate.get("bounds") is Rect2i:
		return "semantic_bundle_bounds"
	var bounds: Rect2i = candidate["bounds"]
	if bounds.size.x < 8 or bounds.size.y < 8 or bounds.size.x > 1024 or bounds.size.y > 1024:
		return "semantic_bundle_dimensions"
	if not candidate.get("layers") is Dictionary:
		return "semantic_bundle_layers"
	var definition_error: String = _validate_definitions(candidate["layers"], bounds.size)
	if not definition_error.is_empty():
		return definition_error
	for name: String in ["features", "projections", "fixtures", "links"]:
		if not candidate.get(name) is Array:
			return "semantic_bundle_" + name
	if (candidate["features"].size() > MAX_FEATURES or candidate["fixtures"].size() > MAX_FIXTURES
			or candidate["links"].size() > MAX_LINKS or candidate["projections"].size() > MAX_PROJECTIONS):
		return "semantic_registration_budget"
	if not candidate.get("rates") is Dictionary or candidate["rates"].size() != 4:
		return "semantic_bundle_rates"
	for id: String in IDS:
		var rate: Variant = candidate["rates"].get(id)
		if not (rate is int or rate is float) or not is_finite(float(rate)) or float(rate) < 0.0 or float(rate) > 60.0:
			return "semantic_bundle_rate"
		if id == "background" and float(rate) != 0.0:
			return "semantic_background_frozen"
	var budgets: Variant = candidate.get("budgets", {})
	if not budgets is Dictionary:
		return "semantic_bundle_budgets"
	for field: String in ["max_events_per_tick", "max_fixture_cell_writes", "max_publication_bytes"]:
		var value: Variant = budgets.get(field, {"max_events_per_tick": MAX_EVENT_RATE, "max_fixture_cell_writes": MAX_FIXTURE_LIFETIME_WRITES, "max_publication_bytes": MAX_PACKET_BYTES}[field])
		if typeof(value) != TYPE_INT or value < 1:
			return "semantic_budget_" + field
	if int(budgets.get("max_events_per_tick", MAX_EVENT_RATE)) > MAX_EVENT_RATE:
		return "semantic_event_rate_budget"
	if measured * 2 > int(budgets.get("max_publication_bytes", MAX_PACKET_BYTES)):
		return "semantic_publication_budget"
	for field: String in ["max_fixtures", "max_links", "max_projections", "max_cells_per_plane"]:
		if budgets.has(field) and (typeof(budgets[field]) != TYPE_INT or budgets[field] < 1):
			return "semantic_budget_" + field
	if (candidate["fixtures"].size() > int(budgets.get("max_fixtures", MAX_FIXTURES))
			or candidate["links"].size() > int(budgets.get("max_links", MAX_LINKS))
			or candidate["projections"].size() > int(budgets.get("max_projections", MAX_PROJECTIONS))
			or bounds.size.x * bounds.size.y > int(budgets.get("max_cells_per_plane", 1048576))):
		return "semantic_registration_budget"
	var material_error: String = _validate_material_payload(candidate, bounds.size)
	if not material_error.is_empty():
		return material_error
	var features: Dictionary = {}
	for raw: Variant in candidate["features"]:
		if not raw is Dictionary or not _string(raw.get("id")) or not _revision(raw.get("revision")) or not raw.get("bounds") is Rect2i:
			return "semantic_feature_record"
		if features.has(raw["id"]):
			return "semantic_duplicate_feature"
		if not _encloses(bounds, raw["bounds"]):
			return "semantic_feature_bounds"
		features[raw["id"]] = raw
	if features.is_empty():
		return "semantic_missing_features"
	var projected: Dictionary = {}
	var projection_ids: Dictionary = {}
	for raw: Variant in candidate["projections"]:
		if not raw is Dictionary or not _string(raw.get("id")) or not _revision(raw.get("revision")) or not raw.get("plane") in IDS:
			return "semantic_projection_record"
		var feature_id: Variant = raw.get("feature_id", raw.get("feature", ""))
		if not features.has(feature_id):
			return "semantic_projection_feature"
		if projection_ids.has(raw["id"]):
			return "semantic_duplicate_projection"
		if not raw.get("bounds") is Rect2i or not _encloses(bounds, raw["bounds"]):
			return "semantic_projection_bounds"
		for material_field: String in ["material", "interior"]:
			if raw.has(material_field) and not _material(raw[material_field]):
				return "semantic_projection_material"
		if not raw.get("shape") in ["fill", "shell", "omit", "native"]:
			return "semantic_projection_shape"
		if raw.has("density") and (not (raw["density"] is int or raw["density"] is float) or not is_finite(float(raw["density"])) or raw["density"] < 0 or raw["density"] > 1):
			return "semantic_projection_density"
		if raw.has("wall_thickness") and (typeof(raw["wall_thickness"]) != TYPE_INT or raw["wall_thickness"] < 0 or raw["wall_thickness"] > 128):
			return "semantic_projection_wall"
		if raw.get("shape", "fill") == "omit" and not _string(raw.get("omission")):
			return "semantic_projection_omission"
		projection_ids[raw["id"]] = true
		# Composition omissions retain provenance but cannot authorize fixture,
		# actor or link endpoints, matching the native plan compiler's endpoint.
		if raw["shape"] != "omit":
			projected[str(feature_id) + "|" + str(raw["plane"])] = true
	var actor_error: String = _validate_actors(candidate.get("actors", []), features, projected, bounds, budgets)
	if not actor_error.is_empty():
		return actor_error
	var fixtures: Dictionary = {}
	var per_tick: Dictionary = {"play": 0, "scripted": 0, "effects": 0}
	var lifetime_writes: int = 0
	for raw: Variant in candidate["fixtures"]:
		var error: String = _validate_fixture(raw, features, projected, bounds)
		if not error.is_empty():
			return error
		if fixtures.has(raw["id"]):
			return "semantic_duplicate_fixture"
		fixtures[raw["id"]] = raw
		var rect: Rect2i = raw["bounds"]
		var area: int = rect.size.x * rect.size.y
		per_tick[raw["plane"]] += area
		if per_tick[raw["plane"]] > MAX_FIXTURE_WRITES_PER_TICK:
			return "semantic_fixture_tick_budget"
		lifetime_writes += area * (int(raw["repeat"]) + (1 if int(raw["cleanup_tick"]) > 0 else 0))
		if lifetime_writes > mini(MAX_FIXTURE_LIFETIME_WRITES, int(budgets.get("max_fixture_cell_writes", MAX_FIXTURE_LIFETIME_WRITES))):
			return "semantic_fixture_lifetime_budget"
	var links: Dictionary = {}
	for raw: Variant in candidate["links"]:
		var error: String = _validate_link(raw, features, projected, fixtures, bounds, int(budgets.get("max_events_per_tick", MAX_EVENT_RATE)))
		if not error.is_empty():
			return error
		if links.has(raw["id"]):
			return "semantic_duplicate_link"
		links[raw["id"]] = true
	return ""

func _validate_fixture(raw: Variant, features: Dictionary, projected: Dictionary, bounds: Rect2i) -> String:
	if not raw is Dictionary or not _string(raw.get("id")) or not _revision(raw.get("revision")):
		return "semantic_fixture_record"
	var feature_id: Variant = raw.get("feature_id", raw.get("feature", ""))
	var plane: Variant = raw.get("plane")
	if not features.has(feature_id) or not plane in ["play", "scripted", "effects"]:
		return "semantic_fixture_endpoint"
	if not projected.has(str(feature_id) + "|" + str(plane)):
		return "semantic_fixture_projection"
	if raw.get("clock") != plane or raw.get("lifecycle") != "finite-owner-v1":
		return "semantic_fixture_clock_or_lifecycle"
	if not raw.get("bounds") is Rect2i or not _inside_guard(bounds, raw["bounds"]) or not _encloses(features[feature_id]["bounds"], raw["bounds"]):
		return "semantic_fixture_bounds"
	var rect: Rect2i = raw["bounds"]
	if rect.size.x * rect.size.y > MAX_FIXTURE_AREA:
		return "semantic_fixture_area"
	if not _material(raw.get("material")):
		return "semantic_fixture_material"
	if plane == "effects" and not raw["material"] in EFFECT_MATERIALS:
		return "semantic_fixture_effects_material"
	if not raw.get("mode") in ["source", "drain", "setup"]:
		return "semantic_fixture_mode"
	if (raw["mode"] == "drain" and raw["material"] != Cell.EMPTY) or (raw["mode"] == "source" and raw["material"] == Cell.EMPTY):
		return "semantic_drain_material"
	for field: String in ["first_tick", "period", "repeat", "cleanup_tick"]:
		if typeof(raw.get(field)) != TYPE_INT:
			return "semantic_fixture_schedule_type"
	if raw["first_tick"] < 0 or raw["first_tick"] > MAX_SCHEDULE_TICK or raw["period"] < 1 or raw["period"] > MAX_SCHEDULE_TICK or raw["repeat"] < 1 or raw["repeat"] > MAX_REPEAT:
		return "semantic_fixture_schedule"
	var last: int = raw["first_tick"] + (raw["repeat"] - 1) * raw["period"]
	if last > MAX_SCHEDULE_TICK or raw["cleanup_tick"] < 0 or raw["cleanup_tick"] > MAX_SCHEDULE_TICK:
		return "semantic_fixture_schedule"
	if raw["cleanup_tick"] > 0 and raw["cleanup_tick"] <= last:
		return "semantic_fixture_cleanup_schedule"
	if raw["mode"] != "setup" and raw["first_tick"] == 0:
		return "semantic_source_starts_after_installation"
	if raw["mode"] == "setup" and (raw["repeat"] != 1 or raw["first_tick"] != 0):
		return "semantic_setup_schedule"
	var products: Variant = raw.get("expected_products", [])
	if not products is Array or products.size() > 16:
		return "semantic_fixture_products"
	for product: Variant in products:
		if not _material(product) or product == Cell.EMPTY or product == raw["material"]:
			return "semantic_fixture_product_is_feed"
	return ""

func _validate_link(raw: Variant, features: Dictionary, projected: Dictionary, fixtures: Dictionary,
		bounds: Rect2i, event_rate: int) -> String:
	if not raw is Dictionary or not _string(raw.get("id")) or not _revision(raw.get("revision")) or raw.get("lifecycle") != "bundle-generation-v1":
		return "semantic_link_record"
	var source: Variant = raw.get("source_feature")
	var target: Variant = raw.get("target_feature")
	var from: Variant = raw.get("source_plane")
	var to: Variant = raw.get("target_plane")
	if not features.has(source) or not features.has(target) or not from in IDS or not to in IDS:
		return "semantic_link_endpoint"
	if not projected.has(str(source) + "|" + str(from)) or not projected.has(str(target) + "|" + str(to)):
		return "semantic_link_projection"
	if not raw.get("bounds") is Rect2i or not _encloses(bounds, raw["bounds"]) or not _encloses(features[target]["bounds"], raw["bounds"]):
		return "semantic_link_bounds"
	var family: Variant = raw.get("family")
	var classification: Variant = raw.get("classification")
	var effect: Variant = raw.get("effect")
	if not family in ["explosion", "vent", "window", "pipe", "waterfall", "machinery"] or not classification in ["static", "presentation", "runtime"]:
		return "semantic_link_kind"
	if not _material(raw.get("material")) or typeof(raw.get("radius")) != TYPE_INT or typeof(raw.get("max_events_per_tick")) != TYPE_INT:
		return "semantic_link_parameters"
	if raw["radius"] < 0 or raw["radius"] > MAX_RADIUS or raw["max_events_per_tick"] < 1 or raw["max_events_per_tick"] > mini(32, event_rate):
		return "semantic_link_budget"
	if classification == "runtime":
		var blast: bool = family == "explosion" and from == "play" and to == "scripted" and effect == "blast"
		var burst: bool = family == "vent" and from == "scripted" and to == "effects" and effect == "burst"
		if not blast and not burst:
			return "semantic_link_runtime_direction"
		if blast and (raw["material"] != Cell.FIRE or raw["radius"] < 4):
			return "semantic_link_blast_parameters"
		if burst and not raw["material"] in EFFECT_MATERIALS:
			return "semantic_link_burst_material"
		var zone: Rect2i = raw["bounds"]
		if not _inside_guard(bounds, zone) or zone.size.x < raw["radius"] * 2 + 1 or zone.size.y < raw["radius"] * 2 + 1:
			return "semantic_link_runtime_bounds"
	else:
		if raw["radius"] != 0:
			return "semantic_static_radius"
		if family == "explosion":
			return "semantic_explosion_requires_runtime"
		if family == "window":
			if classification != "presentation" or from != "play" or to != "background" or effect != "visibility":
				return "semantic_link_window_direction"
		elif classification != "static":
			return "semantic_link_static_classification"
		elif family in ["pipe", "machinery"] and (from != "play" or to != "scripted" or effect != "correspondence"):
			return "semantic_link_service_direction"
		elif family == "waterfall" and (from != "play" or to != "effects" or effect != "source_and_spray"):
			return "semantic_link_waterfall_direction"
		elif family == "vent" and (not from in ["play", "scripted"] or to != "effects" or not effect in ["source", "drain"]):
			return "semantic_link_vent_direction"
	var fixture_id: Variant = raw.get("fixture_id", "")
	if not fixture_id is String:
		return "semantic_link_fixture"
	if classification == "static" and family in ["vent", "waterfall"] and fixture_id.is_empty():
		return "semantic_link_requires_fixture"
	if not fixture_id.is_empty():
		if not fixtures.has(fixture_id) or fixtures[fixture_id]["plane"] != to or fixtures[fixture_id].get("feature_id", fixtures[fixture_id].get("feature")) != target or not _encloses(raw["bounds"], fixtures[fixture_id]["bounds"]):
			return "semantic_link_fixture"
		if classification == "static" and family == "vent" and fixtures[fixture_id]["mode"] != ("drain" if effect == "drain" else "source"):
			return "semantic_link_fixture_mode"
	if family == "waterfall":
		var water: bool = false
		for fixture: Dictionary in fixtures.values():
			water = water or (fixture.get("feature_id", fixture.get("feature")) == source and fixture["plane"] == "play" and fixture["mode"] == "source" and fixture["material"] == Cell.WATER)
		if not water:
			return "semantic_waterfall_requires_water_source"
	return ""

func _same_content(left: Dictionary, right: Dictionary) -> bool:
	# The generator's adapter serial identifies a configure attempt; it is not
	# semantic content and may increase when regenerating the identical recipe.
	for key: Variant in left:
		if key != "adapter_serial" and (not right.has(key) or left[key] != right[key]):
			return false
	for key: Variant in right:
		if key != "adapter_serial" and not left.has(key):
			return false
	return true

func _validate_material_payload(candidate: Dictionary, size: Vector2i) -> String:
	if not candidate.has("materials"):
		return ""
	var materials: Variant = candidate["materials"]
	if not materials is Dictionary or materials.size() != 4:
		return "semantic_material_packet"
	for id: String in IDS:
		if not materials.get(id) is PackedByteArray or materials[id].size() != size.x * size.y:
			return "semantic_material_packet"
		var expanded := PackedByteArray()
		expanded.resize(size.x * size.y)
		var rects: PackedInt32Array = candidate["layers"][id]
		for offset: int in range(0, rects.size(), 5):
			for y: int in range(rects[offset + 1], rects[offset + 1] + rects[offset + 3]):
				for x: int in range(rects[offset], rects[offset] + rects[offset + 2]):
					expanded[y * size.x + x] = rects[offset + 4]
		if expanded != materials[id]:
			return "semantic_material_rectangle_mismatch"
	return ""

func _string(value: Variant, limit: int = 2048) -> bool:
	return value is String and not value.is_empty() and value.length() <= limit

func _revision(value: Variant) -> bool:
	return value is String and value.length() == 16 and value.is_valid_hex_number(false)

func _material(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= Cell.LAST_MATERIAL and value != 10

func _encloses(outer: Rect2i, inner: Rect2i) -> bool:
	# Widen scalar math before addition; Rect2i.end is signed32 and may wrap.
	var x: int = inner.position.x
	var y: int = inner.position.y
	var ox: int = outer.position.x
	var oy: int = outer.position.y
	return inner.size.x > 0 and inner.size.y > 0 and x >= ox and y >= oy and x + int(inner.size.x) <= ox + int(outer.size.x) and y + int(inner.size.y) <= oy + int(outer.size.y)

func _inside_guard(outer: Rect2i, inner: Rect2i) -> bool:
	return _encloses(outer, inner) and int(inner.position.x) > int(outer.position.x) and int(inner.position.y) > int(outer.position.y) and int(inner.position.x) + int(inner.size.x) < int(outer.position.x) + int(outer.size.x) and int(inner.position.y) + int(inner.size.y) < int(outer.position.y) + int(outer.size.y)

func _disc_enclosed(bounds: Rect2i, cell: Vector2i, radius: int) -> bool:
	return int(cell.x) - radius >= int(bounds.position.x) and int(cell.y) - radius >= int(bounds.position.y) and int(cell.x) + radius < int(bounds.position.x) + int(bounds.size.x) and int(cell.y) + radius < int(bounds.position.y) + int(bounds.size.y)

func _measure(value: Variant, depth: int) -> int:
	_metadata_nodes += 1
	if depth > 24 or _metadata_nodes > MAX_METADATA_NODES:
		return -1
	var size: int = 32
	match typeof(value):
		TYPE_DICTIONARY:
			if value.size() > MAX_METADATA_NODES:
				return -1
			for key: Variant in value:
				if not (key is String or key is StringName) or str(key).length() > 2048:
					return -1
				var child: int = _measure(value[key], depth + 1)
				if child < 0:
					return -1
				size += str(key).length() * 4 + child + 64
				if size > MAX_PACKET_BYTES:
					return -1
		TYPE_ARRAY:
			if value.size() > MAX_METADATA_NODES:
				return -1
			for item: Variant in value:
				var child: int = _measure(item, depth + 1)
				if child < 0:
					return -1
				size += child
				if size > MAX_PACKET_BYTES:
					return -1
		TYPE_STRING, TYPE_STRING_NAME:
			if str(value).length() > 4096:
				return -1
			size += str(value).length() * 4
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			size += value.size() * 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			size += value.size() * 8
		TYPE_PACKED_BYTE_ARRAY:
			size += value.size()
		TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I, TYPE_RECT2I, TYPE_NIL:
			pass
		TYPE_FLOAT:
			if not is_finite(value):
				return -1
		_:
			return -1
	return size
