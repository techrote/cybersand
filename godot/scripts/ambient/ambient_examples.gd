extends RefCounted

# Ordinary authored Setup-v2 recipes. Every visible architectural surface and
# fluid patch is real native material, and every inhabitant is an existing rig.
# The helper owns no live World, simulation loop or alternative actor host.
const Setup = preload("res://scripts/workbench_setup.gd")
const Living = preload("res://scripts/ambient/ambient_living_examples.gd")
const Catalog = preload("res://scripts/workbench_actor_catalog.gd")
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const CONCRETE := 58
const STEEL := 62
const PIPE := 68
const BRICK := 57
const GLASS := 71
const CYAN := 77
const AMBER := 79
const WATER := 3
const OIL := 16


static func entries() -> Array:
	return legacy_entries() + Living.entries()


static func legacy_entries() -> Array:
	return [
		{"id":"ambient-oil-water", "name":"Oil / Water preference garden", "description":"Three ground and wheel actors notice Oil and Water. Paint or erase nearby material and inspect the resulting intent."},
		{"id":"ambient-ledge-walkway", "name":"Ten-second retreat walkway", "description":"A broken elevated gantry makes physical ledges distinct from walls and the canvas boundary. Shy Crawler retains its ten-second retreat."},
		{"id":"ambient-industrial-yard", "name":"Living industrial yard", "description":"A mixed working yard with actual flowing material, open routes and editable obstacles. Four ground inhabitants and one flyer use shared modules."},
		{"id":"ambient-settlement", "name":"Eight-inhabitant settlement", "description":"The accepted eight-actor limit, mixing six personalities and three locomotion families. Placement provides each actor's home."},
		{"id":"ambient-flight", "name":"Flight exploration hangar", "description":"Two existing 4LY flight rigs drift through an open hangar with altitude, crowd and region-boundary steering."},
	]


static func make(id: String, policy: PackedInt32Array) -> Dictionary:
	if id.begins_with("ambient2-"): return Living.make(id, policy)
	match id:
		"ambient-oil-water": return _oil_water(policy)
		"ambient-ledge-walkway": return _walkway(policy)
		"ambient-industrial-yard": return _industrial(policy)
		"ambient-settlement": return _settlement(policy)
		"ambient-flight": return _flight(policy)
	return {}


static func _box(data: Dictionary, x: int, y: int, width: int, height: int, material: int) -> void:
	data.edits.append([x, y, width, height, material])


static func _deck(data: Dictionary, y: int) -> void:
	_box(data, 0, y, 1024, 12, CONCRETE)
	_box(data, 0, y, 1024, 3, STEEL)
	_box(data, 0, 50, 8, y - 50, CONCRETE)
	_box(data, 1016, 50, 8, y - 50, CONCRETE)
	for x: int in range(24, 1000, 64):
		_box(data, x, y + 12, 8, 28, STEEL)
		_box(data, x + 12, y + 16, 22, 3, AMBER)


static func _actor(data: Dictionary, model: String, position: Vector2, profile_id: String, seed_offset: int = 0) -> void:
	var id: int = data.actors.size() + 1
	var actor := Setup.instance(model, id, position)
	var profile := Profile.preset(profile_id)
	profile.seed = (int(profile.seed) + seed_offset) % (Profile.MAX_SEED + 1)
	var control := Catalog.default_control(model)
	control.source = "policy"
	control.policy = "ambient"
	control.enabled = true
	control.decision_ticks = 6
	control.usable_index = -1
	control.ambient = profile
	actor.control = control
	data.actors.append(actor)
	data.next_id = id + 1
	if data.selected == 0: data.selected = id


static func _basin(data: Dictionary, x: int, floor_y: int, material: int) -> void:
	# Shallow real-fluid basin; nearby material is not an invisible target.
	_box(data, x, floor_y - 8, 3, 8, STEEL)
	_box(data, x + 33, floor_y - 8, 3, 8, STEEL)
	_box(data, x + 3, floor_y - 5, 30, 5, material)


static func _oil_water(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(1024, 512))
	_deck(data, 390)
	for x: int in [58, 390, 722]:
		_box(data, x, 185, 234, 7, STEEL)
		_box(data, x + 10, 177, 96, 4, CYAN)
		_box(data, x + 120, 177, 96, 4, AMBER)
		_box(data, x + 4, 192, 5, 56, PIPE)
		_box(data, x + 225, 192, 5, 56, PIPE)
	_basin(data, 106, 390, WATER)
	_basin(data, 200, 390, OIL)
	_basin(data, 438, 390, WATER)
	_basin(data, 532, 390, OIL)
	_basin(data, 770, 390, WATER)
	_basin(data, 864, 390, OIL)
	_actor(data, "runner", Vector2(174, 366), "oil_moth")
	_actor(data, "crawler", Vector2(506, 364), "shy_crawler")
	_actor(data, "monowheel", Vector2(838, 364), "curious_surveyor")
	data.material = OIL
	return data


static func _walkway(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(1024, 512))
	_deck(data, 468)
	_box(data, 56, 344, 370, 10, STEEL)
	_box(data, 622, 344, 346, 10, STEEL)
	_box(data, 56, 354, 14, 114, CONCRETE)
	_box(data, 388, 354, 14, 114, CONCRETE)
	_box(data, 646, 354, 14, 114, CONCRETE)
	_box(data, 954, 354, 14, 114, CONCRETE)
	for x: int in range(88, 390, 48): _box(data, x, 358, 24, 3, AMBER)
	for x: int in range(680, 954, 48): _box(data, x, 358, 24, 3, AMBER)
	# Low wall and high opening are intentionally different from the drop.
	_box(data, 76, 308, 10, 36, BRICK)
	_box(data, 934, 304, 10, 40, BRICK)
	_box(data, 450, 454, 140, 14, WATER)
	_box(data, 430, 220, 180, 6, PIPE)
	_box(data, 502, 214, 36, 6, CYAN)
	# This cautious inhabitant begins near the real break so its first grounded
	# lookahead can demonstrate a finite retreat without a scripted approach.
	_actor(data, "crawler", Vector2(410, 318), "shy_crawler", 4)
	_actor(data, "runner", Vector2(698, 320), "oil_moth", 8)
	data.material = CONCRETE
	return data


static func _industrial(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(1024, 512))
	_deck(data, 438)
	# Overhead pipework leaves a real, open ground route underneath.
	_box(data, 54, 122, 894, 7, PIPE)
	_box(data, 88, 129, 5, 146, PIPE)
	_box(data, 928, 129, 5, 146, PIPE)
	for x: int in [130, 370, 610, 850]:
		_box(data, x, 154, 108, 6, STEEL)
		_box(data, x + 8, 142, 24, 6, CYAN)
		_box(data, x + 78, 160, 6, 72, PIPE)
	# Oil and Water pour through genuine narrow outlets onto separate trays.
	_box(data, 182, 224, 6, 56, STEEL)
	_box(data, 266, 224, 6, 56, STEEL)
	_box(data, 188, 274, 30, 6, STEEL)
	_box(data, 226, 274, 40, 6, STEEL)
	_box(data, 188, 236, 78, 38, OIL)
	_box(data, 182, 418, 98, 4, STEEL)
	_box(data, 760, 218, 6, 62, STEEL)
	_box(data, 852, 218, 6, 62, STEEL)
	_box(data, 766, 274, 38, 6, STEEL)
	_box(data, 812, 274, 40, 6, STEEL)
	_box(data, 766, 230, 86, 44, WATER)
	_box(data, 752, 426, 120, 12, WATER)
	_box(data, 752, 418, 6, 20, STEEL)
	_box(data, 866, 418, 6, 20, STEEL)
	# Editable crates interrupt the otherwise open lane without a scripted route.
	_box(data, 480, 426, 18, 12, 81)
	_box(data, 500, 418, 18, 20, 81)
	_box(data, 576, 430, 22, 8, BRICK)
	_actor(data, "runner", Vector2(166, 414), "oil_moth", 11)
	_actor(data, "crawler", Vector2(680, 412), "shy_crawler", 12)
	_actor(data, "monowheel", Vector2(344, 412), "idle_mechanic", 13)
	_actor(data, "runner", Vector2(570, 405), "curious_surveyor", 14)
	_actor(data, "4ly_trainer", Vector2(500, 250), "drifting_flyer", 15)
	data.material = OIL
	return data


static func _settlement(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(1024, 512))
	_deck(data, 436)
	# A raised service street frames open foreground activity. Its supports sit
	# outside the ground actors' initial patrol space and remain ordinary material.
	_box(data, 48, 210, 928, 10, STEEL)
	_box(data, 48, 220, 10, 216, CONCRETE)
	_box(data, 966, 220, 10, 216, CONCRETE)
	for x: int in [90, 296, 502, 708]:
		_box(data, x, 82, 144, 8, BRICK)
		_box(data, x, 90, 8, 120, BRICK)
		_box(data, x + 136, 90, 8, 120, BRICK)
		_box(data, x + 12, 104, 44, 30, GLASS)
		_box(data, x + 84, 104, 44, 30, GLASS)
		_box(data, x + 12, 143, 44, 3, CYAN)
		_box(data, x + 84, 143, 44, 3, AMBER)
		_box(data, x + 60, 90, 24, 8, STEEL)
	_basin(data, 256, 436, OIL)
	_basin(data, 740, 436, WATER)
	_actor(data, "runner", Vector2(146, 412), "oil_moth", 21)
	_actor(data, "crawler", Vector2(366, 410), "shy_crawler", 22)
	_actor(data, "monowheel", Vector2(468, 410), "idle_mechanic", 23)
	_actor(data, "runner", Vector2(566, 412), "curious_surveyor", 24)
	_actor(data, "runner", Vector2(626, 412), "social_roamer", 25)
	_actor(data, "crawler", Vector2(858, 410), "social_roamer", 26)
	_actor(data, "4ly_trainer", Vector2(226, 294), "drifting_flyer", 27)
	_actor(data, "4ly_drifter", Vector2(794, 280), "drifting_flyer", 28)
	data.material = OIL
	return data


static func _flight(policy: PackedInt32Array) -> Dictionary:
	var data := Setup.fresh(policy, Vector2i(1024, 512))
	_deck(data, 456)
	_box(data, 8, 48, 1008, 10, STEEL)
	for x: int in [42, 238, 434, 630, 826]:
		_box(data, x, 65, 120, 4, CYAN)
		_box(data, x + 10, 72, 100, 12, GLASS)
	_box(data, 68, 368, 180, 8, STEEL)
	_box(data, 776, 368, 180, 8, STEEL)
	_box(data, 68, 376, 10, 80, CONCRETE)
	_box(data, 946, 376, 10, 80, CONCRETE)
	_box(data, 410, 402, 204, 10, STEEL)
	_box(data, 422, 394, 180, 8, WATER)
	_box(data, 410, 384, 6, 18, STEEL)
	_box(data, 608, 384, 6, 18, STEEL)
	_actor(data, "4ly_trainer", Vector2(260, 234), "drifting_flyer", 31)
	_actor(data, "4ly_drifter", Vector2(760, 222), "drifting_flyer", 32)
	data.material = WATER
	return data
