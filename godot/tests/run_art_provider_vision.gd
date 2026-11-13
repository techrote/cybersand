extends SceneTree
const Provider=preload("res://scripts/art_provider.gd")
var p: Node
var done := false
var failure := false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	p=Provider.new(); root.add_child(p)
	var path := OS.get_environment("WB_ART_VISION_PNG")
	var png := Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	p.finished.connect(func(_id: int,text: String,_data: Dictionary,error: String) -> void:
		print("ART_VISION ",JSON.stringify({"text":text,"error":error,"usage":p.usage,"returned_model":p.returned_model}))
		failure = not error.is_empty() or text.is_empty(); done=true)
	var error: String = p.send("LM Studio","http://127.0.0.1:1234/v1","wb-art-vision","","Describe the visible workbench controls and shapes in the image concisely.","Assess the supplied actual native workbench screenshot. Return plain text, no drawing commands.",1024,120,png)
	if not error.is_empty(): print(error); quit(1); return
	var deadline := Time.get_ticks_msec()+125000
	while not done and Time.get_ticks_msec()<deadline: await process_frame
	var folder := OS.get_environment("WB_ART_EVIDENCE_DIR")
	if not folder.is_empty(): DirAccess.copy_absolute(p.log_path,folder+"/vision-provider-traffic.jsonl")
	p.queue_free(); await process_frame
	quit(1 if failure or not done else 0)
