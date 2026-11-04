extends RefCounted

# Explicit room-only authoring candidates, not production actor calibration.
const Catalog = preload("res://scripts/physical_actor_catalog.gd")
const NAMES: Array[String] = ["Midge", "Needle", "Kestrel", "Afterglow", "Surveyor", "Cartographer", "Observatory"]
const DESCRIPTIONS: Array[String] = [
	"Ultralight microscout. Tiny hull, quick bursts, free contact tumble.",
	"Recon dart. Fast, narrow and precise; ease off before landing.",
	"Agile field drone. A balanced explorer with a forgiving airbrake.",
	"Hoverboard. Pink deck, cyan lift pads, and a very questionable future.",
	"Scientific sampler. A broad, unhurried instrument carrier.",
	"Terrain scanner. Long survey arcs and deliberate course changes.",
	"Sensor platform. Lumbering attitude response and a wide instrument bay."]
const COLORS: Array[Color] = [Color("99ffe0"),Color("8fcaff"),Color("ffcb7d"),Color("ff69bb"),Color("a4dd8b"),Color("c3a7ff"),Color("e9dba5")]
# size, mass, acceleration, speed, angular speed, angular acceleration,
# throttle slew, linear drag, force ceiling, torque ceiling.
const ROWS: Array = [
	[Vector2(4,3),.035,180.,115.,8.,38.,8.,.22,8.,3.],
	[Vector2(7,3),.065,160.,130.,6.,28.,6.,.16,12.,10.],
	[Vector2(9,6),.10,145.,115.,4.8,20.,5.,.35,18.,22.],
	[Vector2(18,3),.14,125.,95.,2.8,12.,4.,.55,23.,36.],
	[Vector2(16,9),.18,110.,90.,2.5,9.,2.5,.38,26.,48.],
	[Vector2(23,10),.24,85.,75.,1.7,5.,1.6,.26,26.,64.],
	[Vector2(30,12),.32,70.,60.,1.15,2.6,1.,.20,28.,82.]]

static func valid_index(index: int) -> bool: return index >= 0 and index < ROWS.size()

static func definition(index: int) -> Dictionary:
	if not valid_index(index): return {}
	var row: Array = ROWS[index]
	var data: Dictionary = Catalog.entry(&"arcadelander")
	data.name = NAMES[index]
	data.description = DESCRIPTIONS[index]
	data.color = COLORS[index]
	data.equipment_preparation = "none"
	data.joints = []
	data.mounts = []
	data.parts = [{"id":"chassis","offset":Vector2.ZERO,"size":row[0],"mass":row[1],
		"angle":0.,"shape":"rectangle","friction":.8,"bounce":.04,"role":"hull","color":COLORS[index]}]
	data.profile.merge({"player_controller":"gcr_review_fleet","fleet_index":index,
		"fleet_boost_multiplier":2.0,
		"gravity":38.,"air_drag":0.,"angular_drag":.18,"fleet_accel":row[2],
		"speed":row[3],"fleet_turn_speed":row[4],"fleet_turn_accel":row[5],
		"fleet_slew":row[6],"fleet_drag":row[7],"fleet_force":row[8],"fleet_torque":row[9]},true)
	data.bounds = Rect2(-Vector2(row[0])*.5,Vector2(row[0]))
	data.body_size = row[0]
	data.spawn_floor_clearance = Vector2(row[0]).y*.5+2.
	data.spawn_radius = Vector2(row[0]).length()*.5+2.
	data.part_count = 1
	return data

static func controls(index: int) -> String:
	if index == 3: return "W / S   Rise / descend\nA / D   Strafe\nSPACE   Lift burst\nQ / E   Tilt deck\nSHIFT   Thrust multiplier · CTRL   Brake\nC   Level assistance"
	var utility: String = ""
	match index:
		0: utility="Q   Acid · E   Lava dispenser"
		1,2,4: utility="Q / E   Left / right side thrust"
		5: utility="Q / E   Left / right water dispenser"
		6: utility="Q / E   Left / right lava dispenser"
	return "W / SPACE   Body-axis thrust\nA / D   Rotate\n%s\n%s\nSHIFT   Thrust multiplier · CTRL   Brake\nC   Upright assistance" % [utility,"S   Gunpowder dispenser" if index==2 else "S   Reverse thrust"]
