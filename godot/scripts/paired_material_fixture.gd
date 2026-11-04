extends RefCounted

# Authoring only. Reactions, cure state, material and terrain remain native.
const VIEW := Rect2i(16,16,992,480)
const FAMILIES: Array[String] = ["Stone", "Salt", "Coal"]
const LOOSE: Array[int] = [13,23,27]
const WALLS: Array[int] = [132,133,134]
const DRY: int = 135
const ACTIVE: int = 136
const CRUST: int = 137
const BAY_X: Array[int] = [80,320,560]
const ROOF_Y: int = 390
const ROOF_BREACH := Rect2i(373,390,44,4)
const TRAY := Rect2i(790,420,152,46)

static func build(world: Object, family: int) -> bool:
	if family<0 or family>=FAMILIES.size(): return false
	if not world.diagnostic_fill_rect(Vector2i.ZERO,Vector2i(1024,512),0): return false
	for rectangle: Rect2i in [Rect2i(16,475,992,21),Rect2i(16,16,6,480),Rect2i(1002,16,6,480),Rect2i(16,16,992,6)]:
		if not world.diagnostic_fill_rect(rectangle.position,rectangle.size,58): return false
	for index: int in range(3):
		var x: int = BAY_X[index]
		if not world.diagnostic_fill_rect(Vector2i(x+4,394),Vector2i(142,77),LOOSE[family]): return false
		if index==0: continue
		for rectangle: Rect2i in [Rect2i(x,390,150,4),Rect2i(x,394,4,81),Rect2i(x+146,394,4,81),Rect2i(x,471,150,4)]:
			if not world.diagnostic_fill_rect(rectangle.position,rectangle.size,WALLS[family]): return false
		if index==2 and not world.diagnostic_fill_rect(Vector2i(x+53,390),Vector2i(44,4),0): return false
	# Independent finite-dose tray; no neighboring Concrete is an activator.
	for rectangle: Rect2i in [Rect2i(788,420,4,48),Rect2i(940,420,4,48),Rect2i(788,464,156,4)]:
		if not world.diagnostic_fill_rect(rectangle.position,rectangle.size,58): return false
	return world.diagnostic_fill_rect(Vector2i(794,440),Vector2i(144,24),DRY)

static func breach(world: Object) -> Dictionary:
	var before: Dictionary = world.diagnostic_snapshot(ROOF_BREACH.position,ROOF_BREACH.size,false)
	var accepted: bool = world.diagnostic_fill_rect(ROOF_BREACH.position,ROOF_BREACH.size,0)
	var removed: int = 0
	for material: int in before.get("cells",PackedByteArray()): removed+=int(material!=0)
	return {"operation":"roof-breach","accepted":accepted,"rect":ROOF_BREACH,
		"removed_cells":removed if accepted else 0,
		"scope":"explicit destructive authoring edit; no automatic load damage"}

static func dose(world: Object) -> Dictionary:
	var changed: int = 0
	var before: Dictionary = world.diagnostic_snapshot(TRAY.position,TRAY.size,false)
	for x: int in range(814,830):
		if int(world.material_at(x,439))!=0 or int(world.rigid_body_id_at(x,439))!=0: continue
		world.emit_disc(x,439,0,3)
		changed+=int(world.material_at(x,439)==3)
	var after: Dictionary = world.diagnostic_snapshot(TRAY.position,TRAY.size,false)
	return {"operation":"finite-water-dose","changed_cells":changed,
		"added_free_water":int(after.get("water_mass",0))-int(before.get("water_mass",0)),
		"scope":"up to16 empty full-quantity cells; occupied positions refuse"}

static func remove_water(world: Object) -> Dictionary:
	var removed: int = 0
	var before: Dictionary = world.diagnostic_snapshot(TRAY.position,TRAY.size,false)
	for y: int in range(TRAY.position.y,TRAY.end.y):
		for x: int in range(TRAY.position.x,TRAY.end.x):
			if int(world.material_at(x,y))!=3 or int(world.rigid_body_id_at(x,y))!=0: continue
			world.paint_disc(x,y,0,0,0)
			removed+=1
	var after: Dictionary = world.diagnostic_snapshot(TRAY.position,TRAY.size,false)
	return {"operation":"remove-free-water","removed_cells":removed,
		"removed_free_water":int(before.get("water_mass",0))-int(after.get("water_mass",0)),
		"scope":"bounded tray external removal; bound Water in binder is retained"}
