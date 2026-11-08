extends SceneTree
## Actual NVIDIA/Ollama Chat wire shapes, projected only; no provider requests.
const TrafficProjection = preload("res://scripts/workbench_agent_traffic_projection.gd")
var checks := 0
var failures := 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WB_PROVIDER_UI_TRAFFIC: " + detail)

func record(number: int, kind: String, body: Dictionary) -> Dictionary:
	return {"session":"chat-fixture","sequence":number,"identity":{"epoch":1},"utc":"fixture","kind":kind,"payload":{"http_status":200,"body":JSON.stringify(body)}}

func _init() -> void:
	var call := {"id":"chat-call","type":"function","function":{"name":"observe","arguments":"{\"region\":null,\"detail\":\"cells\"}"}}
	var human := {"role":"user","content":[{"type":"text","text":"Inspect this corner."},{"type":"image_url","image_url":{"sha256":"original image metadata"}}]}
	var reply := {"role":"assistant","content":"I will inspect the corner.","tool_calls":[call],"reasoning_content":"NOT_A_REASONING_SUMMARY"}
	var request := record(1,"http.request",{"messages":[{"role":"system","content":"Protected native World only."},human]})
	var response := record(2,"http.response",{"id":"chat-1","choices":[{"message":reply}],"usage":{"prompt_tokens":11,"completion_tokens":5}})
	var continuation := record(3,"http.request",{"messages":[human,reply,{"role":"tool","tool_call_id":"chat-call","content":"{\"status\":\"observed\",\"observation_id\":\"obs-chat\"}"}]})
	var function_only := record(4,"http.response",{"id":"chat-2","choices":[{"message":{"role":"assistant","content":null,"tool_calls":[{"id":"apply-chat","type":"function","function":{"name":"apply_edit","arguments":"{\"proposal_id\":\"p-chat\"}"}}]}}]})
	var records := [request,response,continuation,function_only]
	var original := JSON.stringify(records)
	var text := TrafficProjection.conversation(records,TrafficProjection.DEFAULT_FILTERS)
	check(text.count("Inspect this corner.") == 1,"Chat continuation duplicates human prompt")
	check(text.contains("Protected native World only."),"Chat system instructions missing")
	check(text.count("I will inspect the corner.") == 1,"stateless Chat history duplicates model prose")
	check(text.count("Model → tool · observe [chat-call]") == 1,"stateless Chat history duplicates tool calls")
	check(text.contains("Tool → model [chat-call]") and text.contains("obs-chat"),"Chat tool result/back-and-forth missing")
	check(text.contains("apply_edit") and text.contains("No assistant prose returned"),"Chat function-only response not explained")
	check(not text.contains("NOT_A_REASONING_SUMMARY"),"Chat reasoning_content exposed as a reasoning summary")
	check(TrafficProjection.categories(response).has("Messages") and TrafficProjection.categories(response).has("Tools") and TrafficProjection.categories(response).has("Metrics"),"Chat categories do not overlap")
	check(JSON.stringify(records) == original,"Chat projection changes original raw data")
	var malformed := record(5,"http.response",{"choices":[{"message":{"tool_calls":[{"function":[]}]}}]})
	check(TrafficProjection.categories(malformed).has("Errors"),"incorrectly typed Chat tool function crashes or disappears")
	var stale: Dictionary = response.duplicate(true)
	stale.payload["stale"] = true
	check(TrafficProjection.conversation([stale],TrafficProjection.DEFAULT_FILTERS).contains("Ignored stale event"),"late Chat response appears current")
	var report := {"kind":"runner.finished","payload":{"model_final_unverified_report":"Provider final report, subject to native checks."}}
	check(TrafficProjection.conversation([report],TrafficProjection.DEFAULT_FILTERS).contains("Model report (unverified)"),"Runner final report not available as recorded prose")
	print("WB_PROVIDER_UI_TRAFFIC: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
