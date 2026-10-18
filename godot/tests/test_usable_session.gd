extends SceneTree

const Session = preload("res://scripts/usable_session.gd")
const Catalog = preload("res://scripts/usable_catalog.gd")

class FakeWorld:
	extends RefCounted
	var cells: Dictionary = {}
	func has_failed() -> bool: return false
	func material_at(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= 1024 or y >= 1024: return 1
		return int(cells.get(Vector2i(x,y),0))
	func emit_disc(x: int, y: int, radius: int, material: int, _flags: int = 0) -> void:
		for yy: int in range(y-radius,y+radius+1):
			for xx: int in range(x-radius,x+radius+1):
				if Vector2(xx-x,yy-y).length() <= float(radius)+0.25:
					cells[Vector2i(xx,yy)] = material

var failures: int = 0
var assertions: int = 0
var session := Session.new()
var world := FakeWorld.new()

func _init() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _context(tick: int, epoch: int = 1, suspended: bool = false) -> Dictionary:
	var rig := PackedFloat32Array()
	rig.resize(40)
	rig[0] = 96.0
	rig[1] = 93.0
	rig[35] = 8.0
	rig[36] = 14.0
	return {
		"count":1, "epoch":epoch, "tick":tick, "suspended":suspended,
		"producers":[&"human"], "rig_observation_stride":40, "rig_states":rig,
	}

func _submit(seq: int, tick: int, usable: int, trigger: bool, alternate: bool = false, lease: int = 6, epoch: int = 1, producer: StringName = &"human") -> bool:
	return session.submit_action(0,epoch,seq,tick,usable,Vector2.RIGHT,1.0,trigger,alternate,lease,producer)

func _run() -> void:
	var slug: int = Catalog.index_for(&"impact_slug")
	_expect(session.configure(_context(0)), "session configure failed")
	_expect(_submit(1,0,slug,false), "equip command refused")
	session.step(1.0/60.0,world,_context(1))
	_expect(int(session.snapshot().equipped[0]) == slug, "equipment selection was not applied")

	# Switching equipment while a trigger is already held must not synthesize a shot.
	var airburst_switch: int = Catalog.index_for(&"timer_airburst")
	_expect(_submit(2,1,airburst_switch,true), "held equipment switch was refused")
	session.step(1.0/60.0,world,_context(2))
	_expect(session.snapshot().projectiles.is_empty(), "held input fired during an equipment switch")
	_expect(_submit(3,2,airburst_switch,false), "release/rearm packet was refused")
	session.step(1.0/60.0,world,_context(3))
	_expect(_submit(4,3,slug,false), "switch back to slug was refused")
	session.step(1.0/60.0,world,_context(4))

	# A press/release between owner ticks must survive as one bounded edge.
	_expect(_submit(5,4,slug,true), "quick-click press refused")
	_expect(_submit(6,4,slug,false), "quick-click release refused")
	_expect(not _submit(6,4,slug,false), "duplicate sequence was accepted")
	_expect(not _submit(7,4,slug,false,false,6,1,&"policy"), "wrong producer was accepted")
	session.step(1.0/60.0,world,_context(5))
	_expect(session.snapshot().projectiles.size() == 1, "press-release between ticks was lost")

	# Cancellation neutralizes input but does not delete committed projectiles.
	var age_before: float = float(session.snapshot().projectiles[0].age)
	_expect(session.cancel_input(0,1,&"human"), "usable cancellation refused")
	session.step(1.0/60.0,world,_context(6))
	_expect(session.snapshot().projectiles.size() == 1, "cancellation deleted committed projectile")
	_expect(float(session.snapshot().projectiles[0].age) > age_before, "committed projectile stopped after input cancellation")

	# Pause freezes committed entity time. Actor epoch changes invalidate stale actions.
	var paused_age: float = float(session.snapshot().projectiles[0].age)
	session.step(1.0/15.0,world,_context(6,2,true))
	_expect(is_equal_approx(float(session.snapshot().projectiles[0].age), paused_age), "pause advanced projectile time")
	_expect(not _submit(8,6,slug,true,false,6,1), "old epoch was accepted after pause")
	session.step(1.0/60.0,world,_context(7,3,false))
	_expect(session.snapshot().projectiles.size() == 1, "resume cleared committed projectile")

	# A held tool expires to neutral without unequipping. Equipment cooldown is
	# actor-wide, so cancellation/epoch changes do not manufacture a fresh tool.
	var sand: int = Catalog.index_for(&"sand_scatter")
	_expect(_submit(1,7,sand,false,false,6,3), "post-resume equipment change refused")
	var tool_tick: int = 8
	session.step(1.0/60.0,world,_context(tool_tick,3,false))
	while float(session.snapshot().actors[0].cooldown) > 0.0 and tool_tick < 32:
		tool_tick += 1
		session.step(1.0/60.0,world,_context(tool_tick,3,false))
	_expect(float(session.snapshot().actors[0].cooldown) <= 0.0, "shared equipment cooldown did not expire")
	_expect(_submit(2,tool_tick,sand,true,false,1,3), "short tool lease refused")
	tool_tick += 1
	session.step(1.0/60.0,world,_context(tool_tick,3,false))
	var writes_live: int = int(session.snapshot().write_count_last)
	tool_tick += 1
	session.step(1.0/60.0,world,_context(tool_tick,3,false))
	_expect(writes_live > 0, "live Sand Scatter lease produced no work")
	_expect(int(session.snapshot().write_count_last) == 0, "expired tool lease continued applying")
	_expect(int(session.snapshot().equipped[0]) == sand, "lease expiry unequipped the tool")

	# Reconfiguration is a hard lifecycle reset and clears committed entities.
	_expect(session.configure(_context(0,4,false)), "session reconfigure failed")
	_expect(session.snapshot().projectiles.is_empty() and session.snapshot().objects.is_empty(), "hard reconfigure retained committed entities")
	_expect(int(session.snapshot().equipped[0]) == -1, "hard reconfigure retained equipment selection")

	# Snapshot storage is copied.
	var snap: Dictionary = session.snapshot()
	snap.equipped[0] = 99
	_expect(int(session.snapshot().equipped[0]) == -1, "session snapshot aliases equipped storage")

	print("USABLE_SESSION: %d assertions; %d failures" % [assertions, failures])
	quit(1 if failures else 0)
