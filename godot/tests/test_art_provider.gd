extends SceneTree
const P = preload("res://scripts/art_provider.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for name_text: String in ["OpenAI","NVIDIA","LM Studio"]:
		for cap: int in [4096,8192,16384]:
			var packet := P.payload(name_text,"manual-model-alias","hello","rules",cap,"png")
			check(packet.model=="manual-model-alias","manual model preserved")
			check(packet.get("max_output_tokens",packet.get("max_tokens"))==cap,"output allowance enforced")
			check(not packet.has("api_key"),"no credentials in body")
	check(P.decode("OpenAI",{"output":[{"content":[{"type":"output_text","text":"[]"}]}],"model":"deployment-alias"}).text=="[]","Responses output parsing does not reject deployment alias")
	check(P.decode("NVIDIA",{"choices":[{"message":{"content":"[]"},"finish_reason":"stop"}],"model":"deployment-alias"}).text=="[]","chat response alias accepted")
	for value: Variant in [null,{},"bad",123]:
		check(not P.decode("OpenAI",{"output":value}).error.is_empty(),"malformed Responses safely reported")
		check(not P.decode("NVIDIA",{"choices":value}).error.is_empty(),"malformed chat safely reported")
	check(P.decode("OpenAI",{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}).error.contains("incomplete"),"incomplete reasoning/output response explicit")
	check(P.decode("LM Studio",{"choices":[{"finish_reason":"length","message":{"content":"["}}]}).error.contains("limit"),"truncated packet never executed")
	check(P.operations('reasoning</think> [{"type":"rectangle","material":58}]')[0].shape=="rectangle","vendor reasoning suffix and shape alias normalized")
	check(P.operations('{"shape":"disc","material":0}').size()==1,"single shape normalized")
	check(P.operations('{"operations":[]}') is Array,"operations envelope accepted")
	check(P.operations('```json\n[]\n```') is Array,"fenced JSON accepted")
	check(P.operations('broken')==null,"malformed output recoverable")
	check(P.operations('[{"operation":"draw_rectangle","x0":1,"y0":1,"x1":2,"y1":2}]')[0].shape=="rectangle","equivalent operation names accepted")
	check(P.operations('[{"shape":"pixel","points":[[1,2]]}]')[0].material==58,"omitted drawing material explicitly defaults to Hard Wall")
	check(P.operations('[{"shape":"circle"}]')[0].shape=="disc","circle spelling normalized")
	check(P.operations('[{"shape":"disc"}]}') is Array,"complete array with stray closing wrapper accepted")
	check(P.operations('[{"shape":"disc"}')==null,"truncated array still rejected")
	var p := P.new()
	root.add_child(p)
	p.secrets.append("dummy-key-123")
	var raw := 'dummy-key-123 Bearer secret sk-abcdefghijklmnop nvapi-abcdefghijklmnop ?api_key=secret'
	var redacted := p.redact(raw)
	check(not redacted.contains("dummy-key-123") and not redacted.contains("abcdefghijklmnop") and not redacted.contains("secret"),"headers URL and body redaction")
	p.log_path = "user://does-not-exist/no/log.jsonl"
	p.log_event("request","test")
	check(not p.log_warning.is_empty() and p.traffic.contains("test"),"logging failure does not block live inspection")
	p.log_path = ""
	for index: int in range(300):
		p.log_event("retention_fixture",{"index":index})
	var archived := FileAccess.get_file_as_string(p.log_path)
	check(archived.count('"kind":"retention_fixture"')==300 and archived.contains('"index":0') and archived.contains('"index":299'),"full traffic retains beginning and end beyond 256 events")
	if not p.log_path.is_empty(): DirAccess.remove_absolute(p.log_path)
	print("ART_PROVIDER_KEYLESS ",checks," checks, ",failures," failures")
	p.queue_free()
	await process_frame
	quit(1 if failures else 0)
