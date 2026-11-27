extends RefCounted

# Committed authoring recipes for the developer-only goblin scene. These are
# ordinary Setup-v2 starts, not observations or a replacement material model.
# The adapter supplies the actual application's liquid-policy envelope.
const Setup = preload("res://scripts/workbench_setup.gd")
const IDS := ["material_playground", "actor_workshop", "construction", "liquid_channel", "save_reopen",
	"history_edges", "boundary_lab", "alchemy", "mixed_stress", "conservation_cell"]
const EXTENT := Vector2i(512, 512)
const VERSION := 2


static func ids() -> Array[String]:
	var result: Array[String] = []
	for fixture_id: String in IDS:
		result.append(fixture_id)
	return result


static func describe(fixture_id: String) -> Dictionary:
	var descriptions := {
		"material_playground": ["Material playground", "Sand, Water and Wood above a hard floor; open space for small experiments."],
		"actor_workshop": ["Actor workshop", "A Kestrel, a passive barrel and a short stepped route in the ordinary physical session."],
		"construction": ["Construction table", "A small Wood frame and open room for painting, selection, copying and authoring history."],
		"liquid_channel": ["Liquid channel", "A bounded Water reservoir and a low channel beside an editable Wood gate."],
		"save_reopen": ["Save and reopen", "An asymmetric authored material pattern and a barrel for exact authored-layout comparisons."],
		"history_edges": ["History and editing", "Repeated reversible edits over asymmetric Wood and Metal tiles, with an empty adjacent translation control."],
		"boundary_lab": ["World boundary laboratory", "Hard boundary markers and narrow passages for clipped camera views, replacement and explicit edit refusals."],
		"alchemy": ["Material alchemy", "Separate bounded pockets of Oil, Water, Ice and Wood for observed interactions; no assumed chemistry or conservation law."],
		"mixed_stress": ["Mixed interaction yard", "A physical runner, Kestrel and barrel beside a reservoir, loose Sand and an editable wall."],
		"conservation_cell": ["Closed Sand cell", "A hard enclosure containing exactly 64 Sand cells; isolated nonreactive conservation and translated-edit controls."],
	}
	if not descriptions.has(fixture_id):
		return {}
	var text: Array = descriptions[fixture_id]
	return {"id":fixture_id, "version":VERSION, "label":text[0], "description":text[1],
		"extent":[EXTENT.x, EXTENT.y], "fill_probe":[380, 44],
		"initial_probes":[{"x":380, "y":44, "material":0},
			{"x":368, "y":32, "material":58}, {"x":12, "y":248, "material":58}],
		"evidence_kind":"committed_authored_recipe"}


static func build(fixture_id: String, policy: PackedInt32Array) -> Dictionary:
	if fixture_id not in IDS or policy.is_empty():
		return {}
	var data: Dictionary = Setup.fresh(policy, EXTENT)
	data.brush = 2
	var edits: Array = data.edits
	# A common floor and a small sealed test pocket leave most of the scene open.
	_box(edits, 8, 246, 496, 6, Setup.WALL)
	_box(edits, 368, 32, 24, 2, Setup.WALL)
	_box(edits, 368, 54, 24, 2, Setup.WALL)
	_box(edits, 368, 34, 2, 20, Setup.WALL)
	_box(edits, 390, 34, 2, 20, Setup.WALL)
	match fixture_id:
		"material_playground":
			_box(edits, 24, 174, 4, 72, Setup.WALL)
			_box(edits, 196, 174, 4, 72, Setup.WALL)
			_box(edits, 72, 170, 64, 4, Setup.WOOD)
			_box(edits, 48, 100, 24, 16, Setup.SAND)
			_box(edits, 140, 192, 40, 48, Setup.WATER)
		"actor_workshop":
			_box(edits, 300, 230, 20, 16, Setup.WALL)
			_box(edits, 320, 214, 20, 32, Setup.WALL)
			_box(edits, 340, 198, 20, 48, Setup.WALL)
			data.actors = [Setup.instance("kestrel", 1, Vector2(96, 160)),
				Setup.instance(Setup.BARREL, 2, Vector2(224, 180))]
			data.next_id = 3
			data.selected = 1
		"construction":
			_box(edits, 72, 162, 6, 84, Setup.WOOD)
			_box(edits, 150, 162, 6, 84, Setup.WOOD)
			_box(edits, 72, 156, 84, 6, Setup.WOOD)
			_box(edits, 90, 132, 24, 12, Setup.SAND)
		"liquid_channel":
			_box(edits, 24, 120, 4, 126, Setup.WALL)
			_box(edits, 28, 238, 252, 8, Setup.WALL)
			_box(edits, 144, 120, 4, 60, Setup.WALL)
			_box(edits, 144, 180, 4, 58, Setup.WOOD)
			_box(edits, 276, 210, 4, 28, Setup.WALL)
			_box(edits, 28, 144, 116, 94, Setup.WATER)
			_box(edits, 200, 198, 20, 10, Setup.SAND)
		"save_reopen":
			_box(edits, 312, 144, 8, 40, Setup.WOOD)
			_box(edits, 320, 168, 24, 8, Setup.WALL)
			_box(edits, 344, 168, 12, 8, Setup.SAND)
			_box(edits, 320, 184, 36, 4, Setup.WALL)
			_box(edits, 320, 176, 4, 8, Setup.WALL)
			_box(edits, 352, 176, 4, 8, Setup.WALL)
			_box(edits, 324, 176, 28, 8, Setup.WATER)
			data.actors = [Setup.instance(Setup.BARREL, 1, Vector2(420, 200))]
			data.next_id = 2
		"history_edges":
			_box(edits, 48, 72, 8, 8, Setup.WOOD)
			_box(edits, 56, 76, 8, 4, Setup.METAL)
			_box(edits, 72, 96, 32, 4, Setup.WALL)
			_box(edits, 104, 72, 4, 28, Setup.WALL)
		"boundary_lab":
			_box(edits, 0, 0, 512, 4, Setup.WALL)
			_box(edits, 0, 4, 4, 508, Setup.WALL)
			_box(edits, 508, 4, 4, 508, Setup.WALL)
			_box(edits, 4, 508, 504, 4, Setup.WALL)
			_box(edits, 12, 232, 4, 14, Setup.WOOD)
			_box(edits, 492, 220, 4, 26, Setup.WOOD)
			_box(edits, 240, 240, 16, 6, Setup.SAND)
		"alchemy":
			for x: int in [32, 96, 160, 224]:
				_box(edits, x, 144, 2, 60, Setup.WALL)
				_box(edits, x + 46, 144, 2, 60, Setup.WALL)
			# One ordinary floor rectangle supports all four separate pockets.
			_box(edits, 34, 202, 236, 2, Setup.WALL)
			_box(edits, 34, 178, 44, 24, Setup.OIL)
			_box(edits, 98, 178, 44, 24, Setup.WATER)
			_box(edits, 162, 178, 44, 24, Setup.ICE)
			_box(edits, 226, 178, 44, 24, Setup.WOOD)
		"mixed_stress":
			_box(edits, 300, 170, 4, 76, Setup.WALL)
			_box(edits, 348, 170, 4, 76, Setup.WOOD)
			_box(edits, 304, 220, 44, 26, Setup.WATER)
			_box(edits, 180, 120, 24, 12, Setup.SAND)
			_box(edits, 160, 220, 24, 26, Setup.WOOD)
			data.actors = [Setup.instance("runner", 1, Vector2(72, 200)),
				Setup.instance("kestrel", 2, Vector2(200, 96)),
				Setup.instance(Setup.BARREL, 3, Vector2(400, 200))]
			data.next_id = 4
			data.selected = 1
		"conservation_cell":
			_box(edits, 48, 48, 48, 2, Setup.WALL)
			_box(edits, 48, 94, 48, 2, Setup.WALL)
			_box(edits, 48, 50, 2, 44, Setup.WALL)
			_box(edits, 94, 50, 2, 44, Setup.WALL)
			_box(edits, 64, 56, 8, 8, Setup.SAND)
	return data


static func _box(edits: Array, x: int, y: int, width: int, height: int, material: int) -> void:
	edits.append([x, y, width, height, material])
