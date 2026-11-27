extends SceneTree

# Manifest selection/admission only. The distinct file contents below are inert
# fixtures: no executable is launched and no native World is constructed.
const Composer=preload("res://scripts/workbench_reciprocal_panel.gd")
const Protocol=preload("res://scripts/workbench_reciprocal_protocol.gd")
var checks:=0
var failures:Array[String]=[]
var directory:=""

func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error("SWARM45_RUNTIME "+label)

func write_text(name:String,value:String)->void:
	var file:=FileAccess.open(directory.path_join(name),FileAccess.WRITE)
	if file==null:check(false,"fixture write "+name);return
	file.store_string(value);file.close()

func write_manifest(name:String,value:Dictionary)->void:
	write_text(name,JSON.stringify(value))

func read_runtime(platform:String)->Dictionary:
	return Composer._packaged_runtime_info(directory,platform)

func _initialize()->void:
	directory="user://swarm45-runtime-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))!=OK:
		check(false,"isolated runtime fixture directory");quit(1);return
	write_text("gentek_reciprocal","inert Linux runtime fixture; never execute\n")
	write_text("gentek_reciprocal.exe","inert Windows runtime fixture; never execute\n")
	var linux_sha:=FileAccess.get_sha256(directory.path_join("gentek_reciprocal"))
	var windows_sha:=FileAccess.get_sha256(directory.path_join("gentek_reciprocal.exe"))
	check(not read_runtime("Linux").ok,"an executable without a source manifest is refused")
	var legacy:Dictionary={"source":"legacy-fixture","sha256":linux_sha}
	write_manifest("swarm004-runtime.json",legacy)
	var actual:=read_runtime("Linux")
	check(actual.ok and actual.source==legacy.source and actual.sha256==linux_sha,
		"older packages retain their explicit legacy source/hash binding")
	var windows:Dictionary={"source":"windows-fixture","sha256":windows_sha,"platform":"windows",
		"native_definition_sha256":Protocol.NATIVE_DEFINITION}
	write_manifest("swarm004-runtime.windows.json",windows)
	actual=read_runtime("Linux")
	check(actual.ok and actual.source==legacy.source,"a Windows manifest does not replace Linux legacy selection")
	actual=read_runtime("Windows")
	check(actual.ok and actual.source==windows.source and actual.sha256==windows_sha and actual.path.ends_with(".exe"),
		"Windows selects its own manifest and executable bytes")
	var linux:Dictionary={"source":"linux-fixture","sha256":linux_sha,"platform":"linux",
		"native_definition_sha256":Protocol.NATIVE_DEFINITION}
	write_manifest("swarm004-runtime.linux.json",linux)
	actual=read_runtime("Linux")
	check(actual.ok and actual.source==linux.source and actual.sha256==linux_sha and not actual.path.ends_with(".exe"),
		"Linux prefers its platform binding over a valid legacy manifest")
	var changed:=linux.duplicate();changed.sha256=windows_sha
	write_manifest("swarm004-runtime.linux.json",changed)
	check(not read_runtime("Linux").ok,"stale platform executable hash cannot fall back to valid legacy authority")
	check(read_runtime("Windows").ok,"a stale Linux binding does not poison the independent Windows binding")
	write_text("swarm004-runtime.linux.json","[]")
	check(not read_runtime("Linux").ok,"malformed platform manifest cannot silently use the valid legacy file")
	changed=linux.duplicate();changed.platform="windows"
	write_manifest("swarm004-runtime.linux.json",changed)
	check(not read_runtime("Linux").ok,"wrong platform metadata fails closed despite a matching executable hash")
	changed=linux.duplicate();changed.native_definition_sha256="0".repeat(64)
	write_manifest("swarm004-runtime.linux.json",changed)
	check(not read_runtime("Linux").ok,"stale optional definition identity fails closed before native execution")
	write_manifest("swarm004-runtime.linux.json",linux)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("gentek_reciprocal")))
	check(not read_runtime("Linux").ok,"a matching manifest cannot admit an absent executable")
	write_text("gentek_reciprocal","inert Linux runtime fixture; never execute\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("swarm004-runtime.linux.json")))
	actual=read_runtime("Linux")
	check(actual.ok and actual.source==legacy.source,"legacy fallback is restored only when the platform binding is absent")
	for name:String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	print("SWARM45_RUNTIME ",JSON.stringify({"checks":checks,"completed":true,"failures":failures,
		"scope":"platform/legacy runtime manifest selection and fail-closed admission; no native execution or World"}))
	quit(0 if failures.is_empty() else 1)
