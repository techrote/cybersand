extends SceneTree
const P = preload("res://scripts/art_provider.gd")
var p: Node
var completions := 0
var error := ""
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("HTTP_CHECK ",label," ",ok)
	if not ok: failures+=1; push_error(label)
func wait_done() -> void:
	var deadline := Time.get_ticks_msec()+10000
	while p.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not p.active,"HTTP request ended")
func run() -> void:
	p=P.new(); root.add_child(p)
	p.finished.connect(func(_id: int,_text: String,_data: Dictionary,why: String) -> void: completions+=1; error=why)
	var base := OS.get_environment("WB_ART_TEST_ENDPOINT")
	p.send("OpenAI",base,"rate","dummy-key-123","hello","rules",4096,5)
	await wait_done()
	check(error.contains("429") and not error.contains("dummy-key-123"),"rate error actionable and credential redacted")
	check(p.traffic.contains("Retry-After") and not p.traffic.contains("dummy-key-123"),"rate feedback retained without credential")
	var count := completions
	p.send("LM Studio",base,"slow","","hello","rules",4096,5)
	p.cancel()
	var end := Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<end: await process_frame
	check(completions==count,"cancel fences delayed HTTP callback")
	p.send("LM Studio",base,"slow","","hello","rules",4096,0.1)
	await wait_done()
	check(error.contains("timeout"),"timeout recoverable and visible")
	p.queue_free(); await process_frame
	print("ART_PROVIDER_HTTP failures=",failures)
	quit(1 if failures else 0)
