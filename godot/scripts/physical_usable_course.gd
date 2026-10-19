class_name CyberPhysicalUsableCourse
extends RefCounted

# Deterministic native authoring for the physical equipment course. Geometry is
# finite fixture content; actor scripts still act through copied observations.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const Loadouts = preload("res://scripts/physical_usable_loadouts.gd")
const Equipment = preload("res://scripts/physical_usable_equipment.gd")
const ID: String = "usables-v1"
const DEFAULT_ROSTER: Array[StringName] = [
	&"digger", &"crawler", &"ripper", &"jev", &"astra", &"tricopter", &"hammerhead", &"heavylift"]


static func config(first_model: StringName = &"digger", count: int = 8) -> Dictionary:
	var models: Array[StringName] = [first_model if Catalog.has_rig(first_model) else &"digger"]
	for model: StringName in DEFAULT_ROSTER:
		if model not in models:
			models.append(model)
	var actors: Array = []
	for index: int in range(clampi(count, 1, 8)):
		var model: StringName = models[index]
		var data: Dictionary = Equipment.definition(Catalog.entry(model))
		var flight: bool = str(data.profile.movement) == "flight"
		actors.append({"model": str(model), "producer": "demo",
			"position": Vector2(162.0 + index * 59.0,
				300.0 if flight else 350.0 - float(data.spawn_floor_clearance))})
	return {"version": 2, "seed": 0, "max_ticks": 36000,
		"local_patch_radius": 8, "course": ID, "actors": actors}


static func sections() -> Array:
	return [
		{"id": "excavation", "name": "01  BORE / CUT", "position": Vector2(144, 286),
			"purpose": "Cut packed-earth seams while the ground rig continues to advance."},
		{"id": "salvage", "name": "02  SORT / DRAIN", "position": Vector2(204, 286),
			"purpose": "Selective powder and liquid removal; glass scoring on separate panels."},
		{"id": "breach", "name": "03  PENETRATE", "position": Vector2(264, 286),
			"purpose": "Swept impact and a three-leaf editable penetration target."},
		{"id": "bounce", "name": "04  RICOCHET", "position": Vector2(324, 260),
			"purpose": "Hard protected faces expose damped projectile bounce and recoil."},
		{"id": "timer", "name": "05  STAGE / BURST", "position": Vector2(384, 232),
			"purpose": "Clear flight space for fuses, airburst children and staged ignition."},
		{"id": "payload", "name": "06  DROP / DEPOSIT", "position": Vector2(444, 286),
			"purpose": "Shallow receiving bins for downward flight payloads and native deposits."},
		{"id": "grip", "name": "07  RELEASE / GRIP", "position": Vector2(504, 286),
			"purpose": "Release the same live body, preserve momentum, then approach and reattach."},
		{"id": "processor", "name": "08  PLACE / JAM", "position": Vector2(558, 258),
			"purpose": "Lower a processor onto the service pad; feed it, block an output and recover it."},
	]


static func layout() -> Array:
	return [
		{"origin": Vector2i(128, 352), "size": Vector2i(512, 8), "material": 1},
		{"origin": Vector2i(128, 136), "size": Vector2i(4, 224), "material": 1},
		{"origin": Vector2i(636, 136), "size": Vector2i(4, 224), "material": 1},
		{"origin": Vector2i(128, 136), "size": Vector2i(512, 4), "material": 1},
		{"origin": Vector2i(185, 330), "size": Vector2i(5, 22), "material": 56},
		{"origin": Vector2i(194, 338), "size": Vector2i(5, 14), "material": 56},
		{"origin": Vector2i(215, 349), "size": Vector2i(16, 3), "material": 2},
		{"origin": Vector2i(237, 338), "size": Vector2i(2, 14), "material": 35},
		{"origin": Vector2i(246, 348), "size": Vector2i(12, 4), "material": 3},
		{"origin": Vector2i(279, 328), "size": Vector2i(1, 24), "material": 56},
		{"origin": Vector2i(285, 328), "size": Vector2i(1, 24), "material": 56},
		{"origin": Vector2i(291, 328), "size": Vector2i(1, 24), "material": 56},
		{"origin": Vector2i(346, 297), "size": Vector2i(3, 23), "material": 1},
		{"origin": Vector2i(326, 296), "size": Vector2i(23, 3), "material": 1},
		{"origin": Vector2i(407, 343), "size": Vector2i(12, 9), "material": 13},
		{"origin": Vector2i(455, 344), "size": Vector2i(3, 8), "material": 1},
		{"origin": Vector2i(490, 344), "size": Vector2i(3, 8), "material": 1},
		{"origin": Vector2i(460, 349), "size": Vector2i(28, 3), "material": 24},
		{"origin": Vector2i(555, 349), "size": Vector2i(76, 3), "material": 1},
	]
