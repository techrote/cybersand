extends SceneTree
const BaselinePlanner=preload("res://control.gd")
const Candidate=preload("res://candidate.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,why: String) -> void:
	checks+=1
	if not ok:failures.append(why);printerr("SOL_STRUCTURE_REPLAY ",why)
func vector(a: Array) -> Vector2:return Vector2(a[0],a[1])
func transform(a: Array) -> Transform2D:return Transform2D(Vector2(a[0],a[1]),Vector2(a[2],a[3]),Vector2(a[4],a[5]))
func restore(raw: Dictionary) -> Dictionary:
	var out: Dictionary = raw.duplicate(true);out.source_transform=transform(out.source_transform)
	for key: String in ["sample_serial","tick","snapshot_serial","physics_epoch","published_usec"]:
		out[key]=int(out[key])
	for contact: Dictionary in out.contacts:
		contact.proxy=int(contact.proxy);contact.face=int(contact.face);contact.cell=Vector2i(contact.cell[0],contact.cell[1])
		for key: String in ["point","a","b","normal"]:contact[key]=vector(contact[key])
	return out
func plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:result[str(key)]=plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:result.append(plain(item))
		return result
	return value
func bits(plan: Dictionary) -> String:
	if not plan.get("accepted",false):return ""
	var bytes := PackedByteArray();bytes.resize(48)
	var values: Array = [plan.velocity.x,plan.velocity.y,plan.omega,plan.energy_before,plan.energy_after,plan.energy_tolerance]
	for index: int in values.size():bytes.encode_double(index*8,float(values[index]))
	return bytes.hex_encode()
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output: String = OS.get_environment("SOL_REPLAY_OUTPUT")
	if output.is_empty() or FileAccess.file_exists(output):printerr("SOL_STRUCTURE_REPLAY refuses output");quit(1);return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SOL_REPLAY_INPUT")))
	var results: Array = []
	for item: Dictionary in data.cases:
		var state: PackedByteArray = str(item.state_bits).hex_decode()
		check(state.size()==88,"lossless actual11scalar input")
		var a: Array = []
		for index: int in 11:a.append(state.decode_double(index*8))
		var pose: Transform2D = transform(a);var velocity:=Vector2(a[6],a[7])
		var centres := PackedVector2Array();var sizes := PackedVector2Array()
		for centre: Array in item.proxy_centres:centres.append(vector(centre))
		for size: Array in item.proxy_sizes:sizes.append(vector(size))
		var observation: Dictionary = restore(item.observation)
		var old: Dictionary = BaselinePlanner.plan(observation,pose,velocity,a[8],a[9],a[10],centres,sizes)
		var candidate: Dictionary = Candidate.plan(observation,pose,velocity,a[8],a[9],a[10],centres,sizes)
		check(old.get("outcome")==item.expected_outcome and not old.get("accepted",true),"actual refusal reproduces "+str(item.id))
		results.append({"id":item.id,"control":plain(old),"candidate":plain(candidate),"control_bits":bits(old),"candidate_bits":bits(candidate)})
	var file := FileAccess.open(output,FileAccess.WRITE)
	check(file!=null,"output writable")
	if file==null:quit(1);return
	file.store_string(JSON.stringify({"registration":data.registration,"checks":checks,"failures":failures,"results":results},"",true,true));file.flush()
	var error: Error = file.get_error();file.close()
	print("SOL_STRUCTURE_REPLAY checks=",checks," failures=",failures.size()," cases=",results.size());quit(int(not failures.is_empty() or error!=OK))
