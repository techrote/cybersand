extends SceneTree

# Invoked only by the delivered Open Workbench.cmd --self-test path.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	f = Fixture.new(self)
	f.expect(not OS.get_environment("OBJECTSHARD_LAUNCH_RECEIPT").is_empty(),"shipped CMD supplied receipt destination")
	f.expect(FileAccess.file_exists(OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")),"shipped exact-byte manifest is present")
	f.expect(DisplayServer.get_name() != "headless","shipped graphical engine actually opened a display")
	if await f.open("tower"):
		await f.cut_supports("tower")
		await f.until(func(): return f.body_count() >= 1,"shipped ordinary Workbench creates a real physical shard")
		await f.advance(12,"shipped worker/native/Rapier progression")
		f.expect(int(f.diagnostics().get("native_pose_acknowledgements",0))>0,"shipped native poses acknowledged")
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		f.expect(not image.is_empty(),"shipped ordinary scene rendered pixels")
	f.validate_display()
	var result: Dictionary = {"schema":"objectshard-m4-workbench-package-launch-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"host":"ordinary-workbench","checks":f.checks,"failures":f.failures.size(),"failure_details":f.failures,
		"diagnostics":f.diagnostics(),"display_driver":DisplayServer.get_name(),"display_coherence":f.display_witness(),
		"scope":"immutable delivered ZIP / shipped CMD / actual ordinary Workbench; physical GPU acceptance separate"}
	await f.close()
	var path: String = OS.get_environment("OBJECTSHARD_LAUNCH_RECEIPT")
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"\t")+"\n")
		file.close()
	else:
		push_error("Could not write shipped launcher receipt")
		quit(1)
		return
	print(JSON.stringify(result))
	quit(0 if f.failures.is_empty() else 1)
