extends "res://scripts/simulation_worker.gd"

# Qualification-only fault: actual native slices complete under the ordinary
# owner lease, then the second positive acknowledgement exceeds the unchanged
# production deadline. A separate release fault attacks recovery idempotence.
var _qualification_area := ""
var _qualification_active := false
var _qualification_armed := false
var _qualification_slices: Array[Dictionary] = []
var _qualification_delay_release := false


func qualification_arm(area: String, active: bool) -> void:
	_mutex.lock()
	_qualification_area = area
	_qualification_active = active
	_qualification_armed = true
	_qualification_slices = []
	_mutex.unlock()


func qualification_slices() -> Array[Dictionary]:
	_mutex.lock()
	var result: Array[Dictionary] = _qualification_slices.duplicate(true)
	_mutex.unlock()
	return result


func qualification_delay_release() -> void:
	_mutex.lock()
	_qualification_delay_release = true
	_mutex.unlock()


func _persistent_finish(token: int, result: Dictionary, error: String = "") -> void:
	_mutex.lock()
	var receipt: Dictionary = result.get("receipt",{})
	var relevant: bool = _qualification_armed and error.is_empty() and int(result.get("completed_ticks",0))>0 \
		and str(receipt.get("identity",{}).get("area_id",""))==_qualification_area \
		and receipt.get("active",null)==_qualification_active
	var delayed := false
	var observation := {}
	if relevant:
		observation = {"token":token,"result":result.duplicate(true),"native_completed_usec":Time.get_ticks_usec(),
			"slice":_qualification_slices.size()+1}
		delayed = _qualification_slices.size()==1
		if delayed: _qualification_armed = false
	var delayed_release: bool = _qualification_delay_release and bool(result.get("released",false))
	if delayed_release: _qualification_delay_release = false
	_mutex.unlock()
	if delayed:
		var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
		var capsule: Dictionary
		if bool(receipt.active):
			capsule = bridge.capture_workbench_continuation(_world)
		else:
			var captured: Dictionary = bridge.resident_capture(_world,receipt)
			capsule = captured.get("capsule",{})
		observation["native_identity"] = {"native_sha256":str(capsule.get("sha256","")),
			"physical_hash":str(capsule.get("physical_hash","")),"completed_tick":int(capsule.get("completed_tick",-1)),
			"authored_source_sha256":str(capsule.get("authored_source_sha256",""))}
		observation["native_status"] = bridge.resident_status(_world)
	if relevant:
		_mutex.lock()
		_qualification_slices.append(observation)
		_mutex.unlock()
	if delayed or delayed_release: OS.delay_msec(31500)
	super._persistent_finish(token,result,error)
