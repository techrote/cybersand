extends SceneTree

const Preferences = preload("res://scripts/flyer_preferences.gd")
const InputReference = preload("res://scripts/player_playground_input.gd")
var failures: Array[String] = []
var checks: int = 0
var paths: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] in ["--flyer-profile-write","--flyer-profile-read"]:
		child_process.call_deferred(args[0],args[1])
		return
	run.call_deferred()


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FLYER_PREFERENCES "+message)


func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	expect(file != null,"test file opens")
	if file != null:
		file.store_string(content)
		file.close()


func schema_controls() -> void:
	var caps := {"side_thrusters":false,"reverse_thrust":true,"dispenser_q":12,"dispenser_e":8,"dispenser_s":0}
	var value := Preferences.default_profile(caps)
	expect(Preferences.validate_profile(value,caps).is_empty(),"authored capability defaults validate")
	expect(value.tuning.q_material==12 and value.tuning.e_material==8 and value.tuning.s_material==0,"per-port defaults derive from authored capabilities")
	value.options.mass_multiplier=2.0
	expect(Preferences.default_profile(caps).options.mass_multiplier==1.0,"default profiles are defensive copies")
	var bad: Dictionary = value.duplicate(true)
	bad.tuning.acceleration=NAN
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"NaN is refused")
	bad=value.duplicate(true);bad.tuning.fire_amount=8.01
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"emission quantity is bounded")
	bad=value.duplicate(true);bad.tuning.q_material=10
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"reserved material ID is refused")
	bad=value.duplicate(true);bad.tuning.q_material=CyberCellWorld.LAST_MATERIAL+1
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"unknown material is refused")
	bad=value.duplicate(true);bad.tuning.s_material=3
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"a material override cannot add an unauthored dispenser")
	bad=value.duplicate(true);bad.tuning.swap_side_thrusters=1
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"switch fields require bool")
	bad=value.duplicate(true);bad.options.unexpected=1
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"unknown body options refuse")
	for mat: int in range(CyberCellWorld.LAST_MATERIAL+1):
		expect(Preferences.valid_material(mat)==(mat!=10),"registered emission material policy "+str(mat))
	for code: Key in [KEY_1,KEY_0,KEY_KP_4,KEY_F2,KEY_P,KEY_R,KEY_B,KEY_F,KEY_TAB,KEY_PERIOD,KEY_ESCAPE,KEY_BRACKETLEFT,KEY_BRACKETRIGHT]:
		bad=value.duplicate(true);bad.bindings.primary=[code]
		expect(not Preferences.validate_profile(bad,caps).is_empty(),"workbench key remains reserved "+str(code))
	bad=value.duplicate(true);bad.bindings.primary=[KEY_I,KEY_I]
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"duplicate alternative refuses")
	bad=value.duplicate(true);bad.bindings.primary=[KEY_I+KEY_MASK_SHIFT]
	expect(not Preferences.validate_profile(bad,caps).is_empty(),"modifier masks are not physical keys")
	bad=value.duplicate(true);bad.bindings.primary=[]
	expect(Preferences.validate_profile(bad,caps).is_empty(),"explicit unbound action is allowed")
	bad=value.duplicate(true);bad.bindings.primary=[KEY_Q]
	expect(Preferences.validate_profile(bad,caps).is_empty(),"intentional shared keys between actions remain possible")
	expect(Preferences.binding_label([])=="Unbound" and Preferences.binding_label([KEY_Q,KEY_E]).contains("Q"),"readable key labels")


func input_controls() -> void:
	var bindings := Preferences.default_bindings()
	var states: Array[Dictionary] = [{}]
	var codes: Array[Key] = [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT,KEY_SPACE,KEY_Q,KEY_E,KEY_CTRL,KEY_SHIFT,KEY_C]
	for code: Key in codes:
		states.append({code:true})
	for first: int in codes.size():
		for second: int in range(first+1,codes.size()): states.append({codes[first]:true,codes[second]:true})
	states.append({KEY_W:true,KEY_A:true,KEY_Q:true,KEY_SPACE:true,KEY_CTRL:true,KEY_SHIFT:true,KEY_C:true})
	for state: Dictionary in states:
		var reference: Dictionary = InputReference.from_state(state)
		reference.secondary=bool(state.get(KEY_CTRL,false))
		var mapped := Preferences.from_state(bindings,state)
		expect(mapped.action==reference,"neutral-default keyboard sampler equivalence "+str(state))
		expect(mapped.ports.q==bool(state.get(KEY_Q,false)) and mapped.ports.e==bool(state.get(KEY_E,false)) and mapped.ports.boost==bool(state.get(KEY_SHIFT,false)),"utility and boost defaults "+str(state))
		expect(mapped.ports.s==(bool(state.get(KEY_S,false)) or bool(state.get(KEY_DOWN,false))),"rear-dispenser defaults "+str(state))
	var pad := Preferences.from_state(bindings,{},Vector2(.3,-.7),Vector3i(1,1,1),-1.0,{"q":true,"e":false,"s":false})
	var pad_reference := InputReference.from_state({},Vector2(.3,-.7),Vector3i(1,1,1),-1.0)
	expect(pad.action==pad_reference and pad.ports.q and not pad.ports.e,"gamepad movement and buttons preserve the shared sampler")
	pad=Preferences.from_state(bindings,{},Vector2.ZERO,Vector3i.ZERO,0,{"q":true,"e":true,"s":true})
	expect(pad.ports.q and pad.ports.e and pad.ports.s and pad.action.trim==0,"both shoulders preserve both dispenser intents")
	bindings.move_up=[KEY_I];bindings.utility_left=[KEY_Z];bindings.boost=[KEY_ALT];bindings.brake=[KEY_J]
	var rebound := Preferences.from_state(bindings,{KEY_I:true,KEY_Z:true,KEY_ALT:true,KEY_J:true})
	expect(rebound.action.move.y == -1 and rebound.action.trim == -1 and rebound.action.secondary and rebound.ports.boost and rebound.ports.q,"rebound actions produce existing action and port values")
	var old := Preferences.from_state(bindings,{KEY_W:true,KEY_Q:true,KEY_SHIFT:true,KEY_CTRL:true})
	expect(not InputReference.active(old.action) and not old.ports.boost and not old.ports.q,"replaced keys no longer act")
	var kestrel := Preferences.from_state(Preferences.default_bindings(),{KEY_W:true,KEY_S:true},Vector2.ZERO,Vector3i.ZERO,0,{},false)
	expect(kestrel.action.move.y == -1 and kestrel.ports.s,"Kestrel can propel forward while dispensing")
	kestrel=Preferences.from_state(Preferences.default_bindings(),{KEY_A:true,KEY_W:true,KEY_S:true},Vector2.ZERO,Vector3i.ZERO,0,{},false)
	expect(Vector2(kestrel.action.move).length()<=1.000001,"non-reversing diagonal retains action magnitude bound")
	var key := InputEventKey.new()
	key.keycode=KEY_I;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	expect(Preferences.sample(bindings,false).action.move.y == -1,"actual logical-key fallback consumes saved binding")
	key=InputEventKey.new();key.keycode=KEY_I;key.pressed=false
	Input.parse_input_event(key);Input.flush_buffered_events()
	expect(not InputReference.active(Preferences.sample(bindings,false).action),"release clears sampled action")


func persistence_controls() -> void:
	var caps := {"dispenser_q":12,"dispenser_e":8,"dispenser_s":0}
	var models := {"midge":caps,"kestrel":{"dispenser_q":0,"dispenser_e":0,"dispenser_s":26}}
	var path: String = "user://test-flyer-préférences-%d.json" % OS.get_process_id()
	paths.append(path)
	var prefs := Preferences.new()
	prefs.file_path=path;prefs.configure_models(models)
	expect(prefs.load_profiles().is_empty() and not prefs.has_saved("midge"),"absent file uses defaults without creating a file")
	expect(not FileAccess.file_exists(path),"missing-profile load performs no write")
	var profile: Dictionary = prefs.profile("midge")
	profile.options.mass_multiplier=3.25
	profile.tuning.q_material=14;profile.tuning.q_amount=2.5
	profile.bindings.utility_left=[KEY_Z]
	profile.fire_enabled=true
	expect(prefs.commit_profile("midge",profile).is_empty(),"bounded UTF-8 preference commit succeeds")
	var first_hash: String = FileAccess.get_sha256(path)
	var readback: Dictionary = prefs.profile("midge")
	readback.options.mass_multiplier=40
	expect(prefs.profile("midge").options.mass_multiplier==3.25,"profile getter cannot mutate stored preferences")
	var fresh := Preferences.new()
	fresh.file_path=path;fresh.configure_models(models)
	expect(fresh.load_profiles().is_empty() and fresh.profile("midge")==profile,"fresh owner restores all profile values")
	expect(not fresh.has_saved("kestrel") and fresh.profile("kestrel").tuning.s_material==26,"models keep independent authored defaults")
	var bad: Dictionary = profile.duplicate(true);bad.tuning.drag=INF
	expect(not fresh.commit_profile("midge",bad).is_empty() and FileAccess.get_sha256(path)==first_hash and fresh.profile("midge")==profile,"invalid commit preserves memory and previous file")
	var second: Dictionary = fresh.profile("kestrel")
	second.tuning.swap_side_thrusters=true;second.bindings.boost=[KEY_ALT]
	expect(fresh.commit_profile("kestrel",second).is_empty(),"atomic replacement retains existing models")
	var another := Preferences.new();another.file_path=path;another.configure_models(models)
	expect(another.load_profiles().is_empty() and another.profile("midge")==profile and another.profile("kestrel")==second,"replacement reload keeps per-model values")
	var last_good: Dictionary = fresh.profile("midge")
	for corrupted: String in ["{\"version\":1",JSON.stringify({"version":2,"profiles":{}}),JSON.stringify({"version":1,"profiles":{"unknown":profile}})," ".repeat(Preferences.BYTE_LIMIT+1)]:
		write_text(path,corrupted)
		var bad_hash: String = FileAccess.get_sha256(path)
		expect(not fresh.load_profiles().is_empty() and fresh.profile("midge")==last_good,"malformed, future, unavailable and oversized inputs retain memory")
		expect(FileAccess.get_sha256(path)==bad_hash,"refused saved preferences are not silently rewritten")
	# A file at the directory path forces an actual write failure without
	# changing permissions or touching any application/user preference file.
	var blocker: String = "user://test-flyer-blocker-%d" % OS.get_process_id()
	paths.append(blocker);write_text(blocker,"blocked")
	fresh.file_path=blocker+"/profiles.json"
	var changed: Dictionary = profile.duplicate(true);changed.options.mass_multiplier=6.0
	expect(not fresh.commit_profile("midge",changed).is_empty() and fresh.profile("midge")==last_good,"disk write refusal cannot pretend accepted memory was saved")
	var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(profile))
	expect(Preferences.validate_profile(json_roundtrip,caps).is_empty(),"integral JSON keycodes validate before canonicalization")


func capacity_controls() -> void:
	var models: Dictionary = {}
	for index: int in range(Preferences.MAX_MODELS+1): models["craft_"+str(index)]={}
	var prefs := Preferences.new()
	var path: String = "user://test-flyer-capacity-%d.json" % OS.get_process_id()
	paths.append(path);prefs.file_path=path;prefs.configure_models(models)
	for index: int in range(Preferences.MAX_MODELS):
		expect(prefs.commit_profile("craft_"+str(index),Preferences.default_profile()).is_empty(),"save bounded model "+str(index))
	var stable_hash: String = FileAccess.get_sha256(path)
	expect(not prefs.commit_profile("craft_16",Preferences.default_profile()).is_empty() and not prefs.has_saved("craft_16") and FileAccess.get_sha256(path)==stable_hash,"profile count capacity refuses without losing saved state")


func child_process(mode: String, path: String) -> void:
	if not path.begins_with("user://test-flyer-relaunch-") or path.contains(".."):
		quit(1)
		return
	var prefs := Preferences.new()
	prefs.file_path=path
	prefs.configure_models({"midge":{"dispenser_q":12,"dispenser_e":8,"dispenser_s":0}})
	if mode == "--flyer-profile-write":
		var value: Dictionary = prefs.profile("midge")
		value.options.mass_multiplier=4.25
		value.options.boost_multiplier=5.0
		value.tuning.q_material=14
		value.tuning.q_amount=2.5
		value.tuning.thruster_visuals=false
		value.bindings.move_up=[KEY_I]
		value.bindings.boost=[KEY_ALT]
		value.fire_enabled=true
		expect(prefs.commit_profile("midge",value).is_empty(),"fresh writer saves profile")
	else:
		expect(prefs.load_profiles().is_empty() and prefs.has_saved("midge"),"fresh reader loads prior process profile")
		var value: Dictionary = prefs.profile("midge")
		expect(value.options.mass_multiplier==4.25 and value.options.boost_multiplier==5.0,"movement/body values survive process exit")
		expect(value.tuning.q_material==14 and value.tuning.q_amount==2.5 and not value.tuning.thruster_visuals and value.fire_enabled,"emission and graphical options survive process exit")
		expect(value.bindings.move_up==[KEY_I] and value.bindings.boost==[KEY_ALT],"bindings survive process exit")
	print("FLYER_PROFILE_CHILD ",JSON.stringify({"mode":mode,"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))


func relaunch_controls() -> void:
	var path: String = "user://test-flyer-relaunch-%d.json" % OS.get_process_id()
	paths.append(path)
	for mode: String in ["--flyer-profile-write","--flyer-profile-read"]:
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(),PackedStringArray([
			"--headless","--path",ProjectSettings.globalize_path("res://"),
			"--script","res://tests/test_flyer_preferences.gd","--",mode,path]),output,true)
		var captured: String = "\n".join(output)
		expect(code==0 and captured.contains("FLYER_PROFILE_CHILD") and not captured.contains("ERROR:")
			and not captured.contains("ObjectDB instances were leaked"),"separate process completes "+mode)
		for line: String in captured.split("\n"):
			if line.begins_with("FLYER_PROFILE_CHILD"): print(line)


func run() -> void:
	schema_controls()
	input_controls()
	persistence_controls()
	capacity_controls()
	relaunch_controls()
	for path: String in paths:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("FLYER_PREFERENCES ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
