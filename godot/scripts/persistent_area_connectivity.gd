extends RefCounted

# Authored editor-travel metadata. Bounds and edge regions belong to each area;
# neither cache identity nor destination selection assumes a square tile grid.
# Future player observations can use the same rank() value interface.
const AREAS := {
	"a":{"bounds":Rect2(0,0,512,512),"edges":[
		{"to":"b","region":Rect2(440,160,72,280),"direction":Vector2.RIGHT},
		{"to":"c","region":Rect2(160,440,280,72),"direction":Vector2.DOWN}]},
	"b":{"bounds":Rect2(0,0,512,512),"edges":[
		{"to":"a","region":Rect2(0,160,72,280),"direction":Vector2.LEFT},
		{"to":"c","region":Rect2(440,160,72,280),"direction":Vector2.RIGHT}]},
	"c":{"bounds":Rect2(0,0,512,512),"edges":[
		{"to":"b","region":Rect2(0,160,72,280),"direction":Vector2.LEFT},
		{"to":"a","region":Rect2(160,0,280,72),"direction":Vector2.UP}]},
}


static func adjacent(area_id: String) -> Array[String]:
	var result: Array[String] = []
	for edge: Dictionary in AREAS.get(area_id,{}).get("edges",[]):
		result.append(str(edge.to))
	return result


static func rank(area_id: String, view_origin: Vector2, view_size: Vector2,
		previous_origin: Vector2, explicit_intent: String = "", recent: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not AREAS.has(area_id): return result
	var centre := view_origin + view_size * 0.5
	var motion := view_origin - previous_origin
	var focused := view_size.x < float(AREAS[area_id].bounds.size.x) * 0.9 \
		or view_size.y < float(AREAS[area_id].bounds.size.y) * 0.9
	for edge: Dictionary in AREAS[area_id].edges:
		var priority := 10
		var reason := "declared adjacency"
		if str(edge.to) in recent:
			priority = 20
			reason = "recently visited adjacent area"
		if focused and edge.region.grow(48.0).has_point(centre):
			priority = 50
			reason = "camera near authored exit"
			if motion.length_squared() > 0.01 and motion.normalized().dot(edge.direction) > 0.25:
				priority = 70
				reason = "camera moving toward authored exit"
		if str(edge.to) == explicit_intent:
			priority = 100
			reason = "explicit destination intent"
		result.append({"area_id":str(edge.to),"priority":priority,"reason":reason,
			"edge_region":edge.region,"direction":edge.direction})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return int(a.priority)>int(b.priority) if a.priority!=b.priority else str(a.area_id)<str(b.area_id))
	return result


static func metadata() -> Dictionary:
	var result := {}
	for id: String in AREAS:
		var area: Dictionary = AREAS[id]
		var edges := []
		for edge: Dictionary in area.edges:
			edges.append({"to":edge.to,"region":[edge.region.position.x,edge.region.position.y,
				edge.region.size.x,edge.region.size.y],"direction":[edge.direction.x,edge.direction.y]})
		result[id] = {"bounds":[area.bounds.position.x,area.bounds.position.y,area.bounds.size.x,area.bounds.size.y],
			"edges":edges,"traveller":"editor_camera"}
	return result
