class_name CyberPlayerPlaygroundCourse
extends RefCounted

# Native-cell course shared by the articulated and material player owners.
const ID: String = "player-playground"
const VIEW := Rect2i(128, 128, 512, 256)
const FLOOR_Y: int = 352
const MAP_IDS: Array[StringName] = [&"mixed", &"cannon_run", &"rat_steps", &"afterimage_works",
	&"vector_port", &"dust_foundry", &"undertow_lab", &"rocket_yard"]
const MAP_NAMES: Array[String] = ["Original mixed course", "Cannon Run · buggy", "Rat Steps · trials bike",
	"Afterimage Works · acrobat", "Vector Port · lander", "Dust Foundry · Sand cloud",
	"Undertow Lab · Water blob", "Rocket Yard · jet barrel"]
const MAP_HINTS: Array[String] = ["Ramp, tuck tunnel, flight slalom and material sieve.",
	"Build speed on the long launch ramp; brake on the landing straight. The lower lane stays open.",
	"Preload hops up the low steps, then balance across the narrow spine. Try the open lower lane with another player.",
	"Chain a running slide through the low tunnel, then bullet jump or glide between the upper decks.",
	"Thread the wide vertical flight slots, brake over the landing pads, then reverse course.",
	"Spread the Sand through combs, gather it beyond each sieve, or take another player over the top.",
	"Guide Water through the low channels and catch basins. Paint a reservoir to compare the selected solver.",
	"Use short thrust bursts and upright assistance to land on the staggered pads. Ground players have a clear lower route."]
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


static func layout(map_id: StringName = &"mixed") -> Array:
	if map_id != &"mixed":
		return _special_layout(map_id)
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


static func _special_layout(map_id: StringName) -> Array:
	var result: Array = []
	_rect(result, 128, FLOOR_Y, 512, 16, 58)
	_rect(result, 128, 128, 4, 224, 62)
	_rect(result, 636, 128, 4, 224, 62)
	_rect(result, 128, 128, 512, 4, 62)
	match map_id:
		&"cannon_run":
			for i: int in range(40):
				_rect(result, 230 + i * 2, 351 - i, 2, i + 1, 58)
			_rect(result, 310, 312, 36, 40, 58)
			for i: int in range(40):
				_rect(result, 346 + i * 2, 312 + i, 2, 40 - i, 58)
			_rect(result, 480, 346, 20, 6, 59)
			_rect(result, 542, 342, 22, 10, 59)
		&"rat_steps":
			for i: int in range(6):
				_rect(result, 238 + i * 24, 348 - i * 4, 24, 4 + i * 4, 58)
			_rect(result, 382, 324, 80, 4, 63)
			for i: int in range(5):
				_rect(result, 466 + i * 24, 328 + i * 4, 24, 24 - i * 4, 58)
		&"afterimage_works":
			_rect(result, 246, 326, 80, 14, 63)
			_rect(result, 244, 324, 84, 2, 76)
			_rect(result, 374, 290, 64, 5, 63)
			_rect(result, 478, 250, 56, 5, 63)
			_rect(result, 560, 286, 54, 5, 63)
		&"vector_port":
			for i: int in range(3):
				var x: int = 276 + i * 110
				var gap: int = 178 + (i % 2) * 44
				_rect(result, x, 132, 6, gap - 132, 62)
				_rect(result, x, gap + 60, 6, 70 if i % 2 == 0 else 26, 62)
				_rect(result, x + 22, 314 - i * 20, 54, 4, 63)
		&"dust_foundry":
			for i: int in range(3):
				for tooth: int in range(6):
					_rect(result, 282 + i * 108, 246 + tooth * 16, 6, 11, 62)
				_rect(result, 308 + i * 108, 342, 30, 10, 2)
		&"undertow_lab":
			for i: int in range(3):
				var x: int = 264 + i * 112
				_rect(result, x, 278 - i * 20, 62, 5, 63)
				_rect(result, x + 24, 315, 5, 37, 62)
				_rect(result, x + 29, 342, 56, 10, 3)
				_rect(result, x + 85, 324, 5, 28, 62)
		&"rocket_yard":
			for i: int in range(5):
				var x: int = 254 + i * 72
				var y: int = 302 - (i % 3) * 42
				_rect(result, x, y, 38, 5, 63)
				_rect(result, x, y, 38, 1, 78)
	# Quiet, non-simulating lane markers; all maps keep the same safe spawn bay.
	for x: int in range(144, 630, 32):
		_rect(result, x, 358, 9, 2, 77)
	return result


static func _rect(result: Array, x: int, y: int, width: int, height: int, material: int) -> void:
	result.append({"origin": Vector2i(x, y), "size": Vector2i(width, height), "material": material})


static func checkpoints(id: StringName, map_id: StringName = &"mixed") -> PackedVector2Array:
	match map_id:
		&"cannon_run": return PackedVector2Array([Vector2(212, 336), Vector2(324, 299), Vector2(448, 336), Vector2(600, 330)])
		&"rat_steps": return PackedVector2Array([Vector2(212, 336), Vector2(350, 312), Vector2(426, 308), Vector2(600, 332)])
		&"afterimage_works": return PackedVector2Array([Vector2(212, 339), Vector2(284, 343), Vector2(406, 274), Vector2(504, 234)])
		&"vector_port": return PackedVector2Array([Vector2(240, 286), Vector2(279, 208), Vector2(389, 252), Vector2(499, 208)])
		&"dust_foundry": return PackedVector2Array([Vector2(226, 296), Vector2(285, 291), Vector2(393, 307), Vector2(501, 323)])
		&"undertow_lab": return PackedVector2Array([Vector2(228, 304), Vector2(304, 300), Vector2(416, 280), Vector2(528, 260)])
		&"rocket_yard": return PackedVector2Array([Vector2(273, 286), Vector2(345, 244), Vector2(417, 202), Vector2(561, 244)])
	if id in [&"arcadelander", &"jetbarrel"]:
		return PackedVector2Array([Vector2(220, 286), Vector2(337, 195), Vector2(457, 186), Vector2(577, 242)])
	if is_swarm(id):
		return PackedVector2Array([Vector2(212, 296), Vector2(362, 286), Vector2(522, 294), Vector2(592, 318)])
	if id == &"acrobat":
		return PackedVector2Array([Vector2(208, 339), Vector2(294, 311), Vector2(407, 343), Vector2(566, 246)])
	return PackedVector2Array([Vector2(208, 336), Vector2(294, 309), Vector2(365, 336), Vector2(592, 327)])


static func controls(id: StringName) -> String:
	match id:
		&"stuntbuggy": return "W / S   Drive / reverse\nA / D or Q / E   Lean the chassis\nSPACE   Hop from support\nSHIFT   Brake\nC   Help the buggy recover"
		&"trialsbike": return "W / S   Throttle / reverse\nA / D or Q / E   Rider lean\nHold SPACE, release   Preload hop\nSHIFT   Brake / landing control\nC   Recovery assist"
		&"acrobat": return "A / D   Run and steer in the air\nSPACE   Jump / double jump\nSHIFT   Slide; tap for roll\nSHIFT + SPACE   Bullet jump\nSPACE during roll   Jump cancel\nC   Cancel / brake; hold in air to glide"
		&"arcadelander": return "SPACE or W   Main thruster\nA / D or Q / E   Rotate\nS   Reverse thrust\nSHIFT   Strong airbrake\nC   Toggle damped flight / coast"
		&"jetbarrel": return "SPACE or W   Body-axis jetpack\nA / D or Q / E   Strong torque\nS   Reverse thrust\nSHIFT   Brake\nHold C   Upright assistance"
		&"dryswarm": return "WASD   Guide the Sand cloud\nSPACE   Directional surge\nSHIFT   Spread / disperse\nC   Gather / compact\nRelease controls   Hover together"
		&"liquidswarm": return "WASD   Guide the Water blob\nSPACE   Directional surge\nSHIFT   Squeeze into a stream\nC   Gather / compact\nRelease controls   Hover together"
	return ""
