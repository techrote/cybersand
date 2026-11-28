extends "res://scripts/simulation_worker.gd"

# Qualification-only adversary. Native really moves both resident owners and
# publishes its new Main snapshot, then one completion is delayed beyond the
# production controller deadline. The owner lease remains held throughout.
var _qualification_delay_hot := false
var _qualification_delayed_token := 0
var _qualification_delay_release := false
var _qualification_delay_cold := false
var _qualification_cold_reference: Dictionary = {}


func qualification_delay_hot_completion() -> void:
	_mutex.lock()
	_qualification_delay_hot = true
	_mutex.unlock()


func qualification_delay_owner_release() -> void:
	_mutex.lock()
	_qualification_delay_release = true
	_mutex.unlock()


func qualification_delay_cold_completion() -> void:
	_mutex.lock()
	_qualification_delay_cold = true
	_qualification_cold_reference = {}
	_mutex.unlock()


func qualification_cold_reference() -> Dictionary:
	_mutex.lock()
	var result := _qualification_cold_reference.duplicate(true)
	_mutex.unlock()
	return result


func _persistent_finish(token: int, result: Dictionary, error: String = "") -> void:
	_mutex.lock()
	var delay: bool = _qualification_delay_hot and result.get("committed",false) \
		and result.has("source_receipt") and result.has("target_receipt")
	var delay_release: bool = _qualification_delay_release and result.get("released",false)
	var delay_cold: bool = _qualification_delay_cold and result.get("committed",false) and not result.has("source_receipt")
	if delay_cold:
		_qualification_delay_cold = false
		delay = true
	if delay_release:
		_qualification_delay_release = false
		delay = true
	if delay:
		_qualification_delay_hot = false
		_qualification_delayed_token = token
	_mutex.unlock()
	if delay_cold:
		var bridge: Variant = ClassDB.instantiate(&"CyberDemoBridge")
		var capsule: Dictionary = bridge.capture_workbench_continuation(_world)
		_mutex.lock()
		_qualification_cold_reference = {"sha256":capsule.get("sha256",""),
			"physical_hash":capsule.get("physical_hash",""),"completed_tick":capsule.get("completed_tick",-1)}
		_mutex.unlock()
	if delay: OS.delay_msec(31500)
	super._persistent_finish(token,result,error)
