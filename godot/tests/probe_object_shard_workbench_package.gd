extends SceneTree

# Invoked only by the delivered Open Workbench.cmd --self-test path.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var startup_scene: String = ""

func _launch_ordinary_entry() -> bool:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")))
	if not f.expect(manifest is Dictionary and manifest.get("entry",{}).get("rendering_driver")=="opengl3_angle",
		"delivered manifest binds the common ordinary and self-test renderer"): return false
	if not f.expect(RenderingServer.get_current_rendering_driver_name()==str(manifest.entry.rendering_driver),
		"actual graphical backend equals the shipped ordinary launch renderer"): return false
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if not f.expect("--shared-workbench" in arguments and "--objectshard-m4-workbench" in arguments \
		and "--object-shard-scene=tower" in arguments,"shipped CMD supplies the actual ordinary opt-in and scene arguments"): return false
	f.expect(not has_meta("cybersand_feature"),"probe does not preselect a feature or synthesize Workbench metadata")
	startup_scene = str(ProjectSettings.get_setting("application/run/main_scene",""))
	if not f.expect(startup_scene=="res://feature_launcher.tscn","ordinary project startup selects the actual feature launcher"): return false
	if not f.expect(change_scene_to_file(startup_scene)==OK,"actual project entry scene starts"): return false
	if not await f.until(func(): return current_scene != null and current_scene.scene_file_path=="res://main.tscn" \
		and current_scene.shared_workbench != null,"real CLI feature launcher opens ordinary Workbench Main"): return false
	f.host = current_scene
	f.bench = f.host.shared_workbench
	process_frame.connect(f._observe_callback)
	RenderingServer.frame_post_draw.connect(f._observe_draw)
	if not await f.until(func(): return f.installed() and f.bench._object_shard_scene=="tower" \
		and f.bench._pending_object_shard_scene.is_empty(),"ordinary CLI scene selection installs the authored Tower"): return false
	f.expect(f.bench.object_shard_m4_port.enabled,"actual CLI activation enables the ordinary Structures controls")
	f.bench.set_camera(2)
	if not f.play(): return false
	if not await f.until(func(): return f.runtime().enabled and f.diagnostics().get("attached",false),
		"ordinary CLI owner attaches to the existing native World and Main space"): return false
	return await f.pause()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	f = Fixture.new(self)
	f.expect(not OS.get_environment("OBJECTSHARD_LAUNCH_RECEIPT").is_empty(),"shipped CMD supplied receipt destination")
	f.expect(FileAccess.file_exists(OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")),"shipped exact-byte manifest is present")
	f.expect(DisplayServer.get_name() != "headless","shipped graphical engine actually opened a display")
	if await _launch_ordinary_entry():
		await f.pause()
		await f.cut_supports("tower")
		f.play()
		await f.until(func(): return f.body_count() >= 1,"shipped ordinary Workbench creates a real physical shard")
		await f.advance(12,"shipped worker/native/Rapier progression")
		f.expect(int(f.diagnostics().get("native_pose_acknowledgements",0))>0,"shipped native poses acknowledged")
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		f.expect(not image.is_empty(),"shipped ordinary scene rendered pixels")
	f.validate_display()
	var result: Dictionary = {"schema":"objectshard-m4-workbench-package-launch-v1","source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"host":"ordinary-workbench","startup_scene":startup_scene,"scene_id":f.bench._object_shard_scene if f.bench != null else "",
		"launch_arguments":OS.get_cmdline_user_args(),"checks":f.checks,"failures":f.failures.size(),"failure_details":f.failures,
		"diagnostics":f.diagnostics(),"display_driver":DisplayServer.get_name(),"display_coherence":f.display_witness(),
		"rendering_driver":RenderingServer.get_current_rendering_driver_name(),
		"rendering_method":RenderingServer.get_current_rendering_method(),"engine_arguments":OS.get_cmdline_args(),
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
