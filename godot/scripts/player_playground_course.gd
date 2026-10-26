class_name CyberPlayerPlaygroundCourse
extends RefCounted
const Districts = preload("res://scripts/player_playground_districts.gd")
const Expeditions = preload("res://scripts/player_playground_expeditions.gd")

# Native-cell course shared by the articulated and material player owners.
const ID: String = "player-playground"
# Retained small regression fixture only; public districts use map_view().
const VIEW := Rect2i(128, 128, 512, 256)
const FLOOR_Y: int = 352
const MAP_IDS: Array[StringName] = Districts.IDS + Expeditions.IDS
const MAP_NAMES: Array[String] = ["Flood Market · all players", "Quarry Rally · buggy", "Terraced Aqueduct · trials bike",
	"Textile Mill · acrobat", "Crater Port · lander", "Inverted Foundry · Sand cloud",
	"Filtration Cathedral · Water blob", "Silo Facility · jet barrel"] + Expeditions.NAMES
const MAP_HINTS: Array[String] = ["Follow the dry market street, explore the covered bazaar, then take the courier rooftops. Large canal stores overlook the street.",
	"Carry speed across the optional quarry jump, then brake on the suspended landing. The lower recovery road rejoins the baseline route.",
	"Follow the broad aqueduct grade or take the optional upper balance shelves. Explore the arches and open a cistern valve with a tool.",
	"Run the loading street and try the movable first step, optional mill vent and staggered roofs. The ground road remains open to every player.",
	"Launch into the crater's open volume, thread asymmetric gantry apertures and brake onto the arms above the ballast stores.",
	"Break the plywood hopper throats, gather Sand through hanging combs and follow the discharge terraces. The dry lower street stays open.",
	"Explore three deep cisterns below the stone/glass cathedral, copper organ and filter gallery. Use a tool to open channels between stores.",
	"Rise through nested launch wells and land on cantilever pads above the coolant farm. Ground players can use the dry bunker road."] + Expeditions.HINTS
const PRESETS: Array[StringName] = [&"stuntbuggy", &"trialsbike", &"acrobat",
	&"arcadelander", &"dryswarm", &"liquidswarm", &"jetbarrel"]
const NAMES: Array[String] = ["Loose Cannon", "Trials Rat", "Afterimage",
	"Vector Rush", "Dust Devil", "Undertow", "Barrel Rocket"]
const COLORS: Array[Color] = [Color("ffb45b"), Color("ff6978"), Color("ca91ff"),
	Color("7be5ff"), Color("efc567"), Color("65b6ff"), Color("a9ed80")]
const TAGLINES: Array[String] = ["A loose-jointed stunt buggy with an unruly passenger.",
	"Throttle, lean, preload. Make the landing your own.",
	"Build speed. Slide, roll, launch, cancel, and glide.",
	"Fast body-axis thrust with responsive rotation and damping.",
	"Fly a cloud of real Sand. Scatter it, then gather it again.",
	"Guide real Water through gaps as a cohesive flowing blob.",
	"A jetpack on a barrel. Plenty of torque. Questionable judgement."]


static func is_swarm(id: StringName) -> bool:
	return id in [&"dryswarm", &"liquidswarm"]


static func map_view(map_id: StringName) -> Rect2i:
	return VIEW if map_id == &"legacy" else Districts.VIEW


static func floor_y(map_id: StringName) -> int:
	if map_id in Expeditions.IDS: return Expeditions.floor_y(map_id)
	return FLOOR_Y if map_id == &"legacy" else Districts.floor_y(map_id)


static func spawn(map_id: StringName) -> Vector2:
	if map_id in Expeditions.IDS: return Expeditions.spawn(map_id)
	return Vector2(178,304) if map_id == &"legacy" else Districts.spawn(map_id)


static func props(map_id: StringName) -> Array:
	if map_id in Expeditions.IDS: return Expeditions.props(map_id)
	return [] if map_id == &"legacy" else Districts.props(map_id)


static func npc_spawns(map_id: StringName) -> PackedVector2Array:
	if map_id in Expeditions.IDS: return Expeditions.npc_spawns(map_id)
	return PackedVector2Array([Vector2(210, 320)]) if map_id == &"legacy" else Districts.npc_spawns(map_id)


static func editable(map_id: StringName) -> Rect2i:
	return Rect2i(132,132,504,220) if map_id == &"legacy" else Rect2i(6,6,1012,730)


static func layout(map_id: StringName = &"legacy") -> Array:
	if map_id in Expeditions.IDS: return Expeditions.layout(map_id)
	if map_id != &"legacy":
		return Districts.layout(map_id)
	var result: Array = []
	_rect(result, 128, FLOOR_Y, 512, 16, 58)
	_rect(result, 128, 128, 4, 240, 62)
	_rect(result, 636, 128, 4, 240, 62)
	_rect(result, 128, 128, 512, 4, 62)
	_rect(result, 132, FLOOR_Y, 504, 2, 59)
	# A 1:2 stair raster approximates a smooth, rideable launch ramp.
	for index: int in range(28):
		_rect(result, 224 + index * 2, FLOOR_Y - index - 1, 2, index + 1, 58)
	_rect(result, 280, 324, 24, 28, 58)
	for index: int in range(24):
		_rect(result, 304 + index * 2, 324 + index, 2, 28 - index, 58)
	# A separate low tunnel rewards the acrobat's actual compact posture.
	_rect(result, 378, 326, 62, 14, 63)
	_rect(result, 376, 324, 66, 2, 76)
	# Flight slalom, landing decks, and a route above the low tunnel.
	_rect(result, 334, 132, 6, 37, 62)
	_rect(result, 334, 221, 6, 42, 62)
	_rect(result, 454, 132, 6, 26, 62)
	_rect(result, 454, 216, 6, 47, 62)
	_rect(result, 482, 266, 57, 4, 63)
	_rect(result, 550, 260, 70, 4, 63)
	_rect(result, 482, 266, 57, 1, 77)
	_rect(result, 550, 260, 70, 1, 78)
	# Three-cell apertures let actual material parcels pass individually.
	for index: int in range(5):
		_rect(result, 520, 282 + index * 13, 5, 10, 62)
	# Environmental samples sit away from the initial swarm seed.
	_rect(result, 454, 346, 34, 6, 2)
	_rect(result, 552, 344, 60, 8, 3)
	_rect(result, 548, 338, 4, 14, 62)
	_rect(result, 612, 338, 4, 14, 62)
	for x: int in range(144, 630, 32):
		_rect(result, x, 358, 9, 2, 77 if x % 64 < 32 else 79)
	return result


static func _rect(result: Array, x: int, y: int, width: int, height: int, material: int) -> void:
	result.append({"origin": Vector2i(x, y), "size": Vector2i(width, height), "material": material})


static func checkpoints(id: StringName, map_id: StringName = &"legacy") -> PackedVector2Array:
	if map_id in Expeditions.IDS: return Expeditions.checkpoints(map_id)
	if map_id != &"legacy": return Districts.checkpoints(map_id)
	if id in [&"arcadelander", &"jetbarrel"]:
		return PackedVector2Array([Vector2(220, 286), Vector2(337, 195), Vector2(457, 186), Vector2(577, 242)])
	if is_swarm(id):
		return PackedVector2Array([Vector2(212, 296), Vector2(362, 286), Vector2(522, 294), Vector2(592, 318)])
	if id == &"acrobat":
		return PackedVector2Array([Vector2(208, 339), Vector2(294, 311), Vector2(407, 343), Vector2(566, 246)])
	return PackedVector2Array([Vector2(208, 336), Vector2(294, 309), Vector2(365, 336), Vector2(592, 327)])


static func controls(id: StringName) -> String:
	match id:
		&"stuntbuggy": return "W / S   Drive / reverse\nA / D or Q / E   Lean around rear axle\nSPACE   Hop from support\nSHIFT   Brake\nC   Help the buggy recover"
		&"trialsbike": return "W / S   Throttle / reverse\nA / D or Q / E   Rear-wheel pivot / rider lean\nHold SPACE, release   Preload hop\nSHIFT   Brake / landing control\nC   Recovery assist"
		&"acrobat": return "A / D   Run and steer in the air\nSPACE   Jump / double jump\nSHIFT   Slide; tap for roll\nSHIFT + SPACE   Bullet jump\nSPACE during roll   Jump cancel\nCTRL   Cancel / brake; hold in air to glide"
		&"arcadelander": return "SPACE or W   Main thruster\nA / D or Q / E   Rotate\nS   Reverse thrust\nSHIFT   Strong airbrake\nC   Toggle damped flight / coast"
		&"jetbarrel": return "SPACE or W   Body-axis jetpack\nA / D or Q / E   Strong torque\nS   Reverse thrust\nSHIFT   Brake\nHold C   Upright assistance"
		&"dryswarm": return "WASD   Guide the Sand cloud\nSPACE   Directional surge\nSHIFT   Spread / disperse\nC   Gather / compact\nRelease controls   Swirl / gather idly"
		&"liquidswarm": return "WASD   Guide the Water blob\nSPACE   Directional surge\nSHIFT   Squeeze into a stream\nC   Gather / compact\nRelease controls   Flow / gather idly"
	return ""
