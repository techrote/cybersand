extends "res://scripts/player_playground_runtime.gd"

const Fixture = preload("res://scripts/paired_material_fixture.gd")
# Observation work has its own monotonic clock. Painting, simulation speed and
# pause never renew this budget or force an expensive whole-World state hash.
const TRAY_OBSERVATION_INTERVAL_USEC: int = 500_000
var family: int = 0
var authoring_receipt: Dictionary = {}
var profile_identity: Dictionary = {}
var _tray_sample_usec: int = -1
var _tray_edit_serial: int = 0
var _tray_sample_edit_serial: int = -1
var _tray_sample_host_failed: bool = false
var _tray_readbacks: int = 0
var _tray_cache: Dictionary = {}

static func supported() -> bool:
	if OS.has_feature("web") or bool(ProjectSettings.get_setting("cybersand/web_demo",false)): return false
	if not ClassDB.class_exists(&"CyberDemoBridge") or not ClassDB.class_exists(&"CyberNativeCellWorld"): return false
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	if not bridge.has_method(&"inspect_interaction_profile"): return false
	var profile: Dictionary = bridge.inspect_interaction_profile()
	return int(profile.get("profile_version",0))==3 and int(profile.get("material_count",0))==138

func configure_lab(id: StringName, requested_family: int=0, spawn: Vector2=Vector2(178,240)) -> bool:
	if not supported():
		last_error="This lab requires the source-matched paired-material native runtime (profile3/catalogue138); Web/fallback and older runtimes are unsupported."
		return false
	if id not in [&"arcadelander",&"jetbarrel"] or requested_family not in range(3):
		last_error="Unknown lab actor or material family."
		return false
	var candidate := Arena.new()
	add_child(candidate)
	var request: Dictionary = {"version":Arena.VERSION,"seed":0,"max_ticks":Arena.MAX_TICKS,
		"local_patch_radius":0,"actors":[{"model":str(id),"producer":"human","position":spawn}]}
	if not candidate.configure(request) or not Fixture.build(candidate._world,requested_family):
		last_error=candidate.last_error if not candidate.last_error.is_empty() else "Lab authoring refused."
		candidate.close()
		candidate.free()
		return false
	candidate._sync_terrain()
	if bool(candidate.snapshot().failed):
		last_error=candidate.last_error
		candidate.close()
		candidate.free()
		return false
	close()
	selection=id
	_arena=candidate
	family=requested_family
	epoch+=1
	tick=0
	paused=false
	failed=false
	last_error=""
	authoring_receipt={"operation":"fresh-lab","family":Fixture.FAMILIES[family],"external_edits":true}
	_tray_sample_usec=-1
	_tray_edit_serial=0
	_tray_sample_edit_serial=-1
	_tray_sample_host_failed=false
	_tray_readbacks=0
	_tray_cache.clear()
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	profile_identity=bridge.inspect_interaction_profile()
	return true

func breach_shell() -> Dictionary:
	if not active() or failed: return {}
	authoring_receipt=Fixture.breach(_arena._world)
	_arena._sync_terrain()
	_tray_edit_serial+=1
	return authoring_receipt.duplicate(true)

func add_water_dose() -> Dictionary:
	if not active() or failed: return {}
	authoring_receipt=Fixture.dose(_arena._world)
	_tray_edit_serial+=1
	return authoring_receipt.duplicate(true)

func remove_water_dose() -> Dictionary:
	if not active() or failed: return {}
	authoring_receipt=Fixture.remove_water(_arena._world)
	_tray_edit_serial+=1
	return authoring_receipt.duplicate(true)

func _observation_clock_usec() -> int:
	return Time.get_ticks_usec()

func _read_tray_snapshot() -> Dictionary:
	# Count the actual expensive call, not cache requests or painted cells.
	_tray_readbacks+=1
	return _arena._world.diagnostic_snapshot(Fixture.TRAY.position,Fixture.TRAY.size,false)

func tray_observation() -> Dictionary:
	if not active(): return {}
	var now_usec: int = _observation_clock_usec()
	if _tray_sample_usec<0 or now_usec-_tray_sample_usec>=TRAY_OBSERVATION_INTERVAL_USEC:
		_tray_cache=_read_tray_snapshot()
		_tray_sample_usec=now_usec
		_tray_sample_edit_serial=_tray_edit_serial
		_tray_sample_host_failed=failed
	var result: Dictionary = _tray_cache.duplicate(true)
	# Never present cached counts/hash as a fresh native observation. Even a
	# no-op brush conservatively marks the sample stale until its next deadline.
	result["sample_tick"]=int(_tray_cache.get("completed_ticks",-1))
	result["sample_age_usec"]=maxi(0,now_usec-_tray_sample_usec)
	# Host/actor quarantine can occur while the native World remains healthy.
	# Preserve native `failed`; compare each host status with its own sample.
	result["sample_stale"]=(_tray_sample_edit_serial!=_tray_edit_serial
		or int(result.sample_tick)!=tick or _tray_sample_host_failed!=failed)
	result["diagnostic_readbacks"]=_tray_readbacks
	return result

func paint_lab(cell: Vector2i, material: int, radius: int) -> bool:
	if not active() or failed or radius<1 or radius>24 or not Fixture.VIEW.grow(-radius-6).has_point(cell): return false
	if material not in [0,1,2,3,6,8,12,13,14,23,24,27,30,31,132,133,134,135,137]: return false
	_arena._world.paint_disc(cell.x,cell.y,radius,material,0)
	_arena._sync_terrain()
	_tray_edit_serial+=1
	authoring_receipt={"operation":"free-paint","material":material,"radius":radius,"centre":cell,"scope":"external authoring; separate from closed fixtures"}
	return true
