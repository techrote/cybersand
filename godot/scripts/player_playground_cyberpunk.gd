class_name CyberPlayerPlaygroundCyberpunk
extends RefCounted

const Streets = preload("res://scripts/player_playground_neon_streets.gd")
const Works = preload("res://scripts/player_playground_neon_works.gd")
const VIEW := Rect2i(0,0,1024,768)
const IDS: Array[StringName] = Streets.IDS+Works.IDS
const NAMES: Array[String] = Streets.NAMES+Works.NAMES
const HINTS: Array[String] = Streets.HINTS+Works.HINTS
const SUGGESTED: Array[StringName] = Streets.SUGGESTED+Works.SUGGESTED


static func _module(id: StringName):
	if id in Streets.IDS: return Streets
	if id in Works.IDS: return Works
	assert(false,"Unknown Cyberpunk Backchannels map: "+str(id))
	return null


static func floor_y(id: StringName) -> int:
	return int(_module(id).floor_y(id))


static func spawn(id: StringName) -> Vector2:
	return _module(id).spawn(id)


static func road_y(id: StringName, x: int) -> int:
	return int(_module(id).road_y(id,x))


static func layout(id: StringName) -> Array:
	return _module(id).layout(id)


static func checkpoints(id: StringName) -> PackedVector2Array:
	return _module(id).checkpoints(id)


static func props(id: StringName) -> Array:
	return _module(id).props(id)


static func npc_spawns(id: StringName) -> PackedVector2Array:
	return _module(id).npc_spawns(id)


static func reservoirs(id: StringName) -> Array:
	return _module(id).reservoirs(id)


static func reservoir_outlet(id: StringName) -> Vector2i:
	return _module(id).reservoir_outlet(id)
