extends RefCounted

# Main-thread facade for the existing Workbench. Never reads its live World.
var _workbench: WeakRef
var _source_identity := ""
var _native_path := ""

func bind(workbench: Control) -> void:
	_workbench = weakref(workbench)
	_native_path = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll" if OS.get_name() == "Windows" else "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	var digest: String = FileAccess.get_sha256(_native_path) if FileAccess.file_exists(_native_path) else ""
	_source_identity = "native-file-sha256:" + digest if digest.length() == 64 else ""

func _owner() -> Variant:
	return _workbench.get_ref() if _workbench != null else null

func _worker() -> Variant:
	var owner: Variant = _owner()
	return owner.host.simulation_worker if owner != null and is_instance_valid(owner.host) else null

func material_audition_state() -> Dictionary:
	var worker: Variant = _worker()
	if worker == null:
		return {"ok":false,"status":"unavailable","error":"The Workbench host session has retired."}
	var result: Dictionary = worker.material_audition_state()
	result["source_identity"] = _source_identity
	result["source_identity_scope"] = "Native file fingerprint observed when this Lab was attached; mapped-module identity is not independently measured. Profiles require this runtime file identity. Evaluator manifests bind exact source."
	result["retention"] = "Session-only until explicitly saved as a named profile. Authored Save start does not retain this configuration."
	return result

func request_material_audition(request: Dictionary) -> Dictionary:
	var worker: Variant = _worker()
	if worker == null: return {"ok":false,"status":"refused","error":"The Workbench host session has retired."}
	return worker.material_audition_request(request)

func poll_material_audition(request_id: String) -> Dictionary:
	var worker: Variant = _worker()
	if worker == null: return {"ok":false,"status":"unavailable","code":"host_retired","request_id":request_id,"error":"The Workbench host session has retired; the transaction outcome is unavailable."}
	var receipt: Dictionary = worker.material_audition_poll(request_id)
	if receipt.has("state"):
		receipt.state["source_identity"] = _source_identity
	return receipt

func cancel_material_audition(request_id: String) -> Dictionary:
	var worker: Variant = _worker()
	if worker == null: return {"ok":false,"status":"unavailable","code":"host_retired","request_id":request_id,"error":"The Workbench host session has retired; the transaction outcome is unavailable."}
	var receipt: Dictionary = worker.material_audition_cancel(request_id)
	if receipt.has("state"):
		receipt.state["source_identity"] = _source_identity
	return receipt

func request_material_audition_demo(scene_id: String) -> Dictionary:
	var owner: Variant = _owner()
	if owner == null: return {"ok":false,"error":"The Workbench has closed."}
	return owner.load_material_audition_demo(scene_id)
