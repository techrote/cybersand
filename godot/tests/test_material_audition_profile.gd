extends SceneTree

# Schema/provenance/admission regression, separate from native effect evidence.
const Profiles = preload("res://scripts/material_audition_profile.gd")
const Scenes = preload("res://scripts/workbench_material_audition_scenes.gd")
var checks := 0
var failures := 0

static func fixture_state() -> Dictionary:
	return {"ok":true,"session_id":"fixture-session","world_id":"123","revision":0,
		"source_identity":"fixture-runtime-sha256","native_compatibility":"fixture-material-abi-1",
		"profile":Profiles.defaults(),"capabilities":[
			{"kind":"material","material_id":2,"property":"density","declared":1600,"effective":1600,"minimum":1,"maximum":65535,"change_class":"live","consumer":"density exchange","applicability":"Directional exchange only"},
			{"kind":"material","material_id":24,"property":"viscosity","declared":12,"effective":12,"minimum":0,"maximum":255,"change_class":"live","consumer":"generic liquid","applicability":"Brine movement"},
			{"kind":"material","material_id":3,"property":"viscosity","declared":0,"effective":0,"minimum":0,"maximum":255,"change_class":"unsupported","consumer":"Water solver policy","applicability":"Descriptor viscosity is not Water movement"},
			{"kind":"reaction","slot":5,"first":3,"second":23,"property":"probability_threshold","declared":255,"effective":255,"minimum":0,"maximum":255,"change_class":"live","consumer":"sparse pair resolver","applicability":"Role-preserving products"}]}

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MAT_AUDITION_PROFILE: " + message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var state := fixture_state()
	var profile := Profiles.defaults("test-trial")
	profile.materials = [{"material_id":24,"viscosity":240},{"material_id":2,"density":500}]
	profile.reactions = [{"slot":5,"probability_threshold":0}]
	var checked := Profiles.validate_profile(profile,state)
	expect(checked.get("ok",false),"admitted density, viscosity and inclusive probability can coexist")
	expect(int(checked.profile.materials[0].material_id)==2,"validated profile sorts stable IDs deterministically")
	var bad_identity := profile.duplicate(true)
	bad_identity.profile_id = "trial:colon"
	expect(not Profiles.validate_profile(bad_identity,state).ok,"profile identity matches native ASCII grammar; colon refused")
	var zero: Dictionary = profile.duplicate(true)
	zero.materials[1].density = 0
	expect(not Profiles.validate_profile(zero,state).ok,"zero density refused")
	for value: Variant in [-1,65536,1.5,true,"500"]:
		var bad := profile.duplicate(true)
		bad.materials[1].density = value
		expect(not Profiles.validate_profile(bad,state).ok,"invalid density refused: " + str(value))
	var unsupported := Profiles.defaults("water-viscosity")
	unsupported.materials = [{"material_id":3,"viscosity":10}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"metadata-only Water viscosity is not exposed as live")
	unsupported.materials = [{"material_id":132,"density":1000}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"synthetic material132 cannot enter a current-scene profile")
	unsupported.materials = [{"material_id":2,"rgba":[1,2,3,4]}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"unsupported appearance cannot be silently discarded")
	unsupported.materials = [{"material_id":2,"density":500},{"material_id":2,"viscosity":20}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"duplicate material IDs refused")
	unsupported = Profiles.defaults()
	unsupported.reactions = [{"slot":5,"probability_threshold":0,"first_product":13}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"changing role or product contract refused")
	unsupported.reactions = [{"slot":5,"probability_threshold":256}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"threshold above byte range refused")
	unsupported.reactions = [{"slot":5,"probability_threshold":0},{"slot":5,"probability_threshold":255}]
	expect(not Profiles.validate_profile(unsupported,state).ok,"duplicate reaction slot refused")
	var cap: Dictionary = state.capabilities[0]
	var changed := Profiles.set_value(Profiles.defaults(),cap,500)
	expect(changed.materials==[{"material_id":2,"density":500}],"editing a control uses the stable material_id key")
	expect(Profiles.set_value(changed,cap,1600).materials.is_empty(),"restoring compiled value removes an unnecessary override")
	var envelope := Profiles.make_envelope(profile,state,"Floating sand","Observe current-scene penetration")
	expect(envelope.get("ok",false),"named profile envelopes retain native source and compatibility")
	var serialized := JSON.stringify(envelope.envelope,"\t")
	var reopened := Profiles.parse_envelope(serialized,state)
	expect(reopened.get("ok",false) and reopened.profile==checked.profile,"same-runtime profile roundtrip restores exact admitted values")
	var foreign := state.duplicate(true)
	foreign.source_identity = "another-runtime"
	expect(not Profiles.parse_envelope(serialized,foreign).ok,"different runtime provenance refused")
	foreign = state.duplicate(true)
	foreign.native_compatibility = "another-abi"
	expect(not Profiles.parse_envelope(serialized,foreign).ok,"different native material compatibility refused")
	var tampered: Dictionary = envelope.envelope.duplicate(true)
	tampered.payload.profile.materials[0].density = 2000
	expect(not Profiles.parse_envelope(JSON.stringify(tampered),state).ok,"tampering with a native property invalidates the digest")
	expect(not Profiles.parse_envelope(serialized.replace('"payload":','"payload": {}, "payload":'),state).ok,"duplicate JSON keys rejected before import")
	expect(not Profiles.parse_envelope(serialized.replace('"payload":','"pay\\u006coad": {}, "payload":'),state).ok,"escaped duplicate key aliases are rejected")
	expect(not Profiles.parse_envelope('"'+"x".repeat(Profiles.MAX_BYTES)+'"',state).ok,"oversized import refused before unbounded processing")
	var output := "user://mat-audition-profile-contract-" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	expect(Profiles.save(output,profile,state,"Saved trial").ok,"profile writes complete through temporary sibling")
	expect(Profiles.load_file(output,state).get("profile",{})==checked.profile,"saved file reopens exact profile")
	var original := FileAccess.get_file_as_bytes(output)
	expect(not Profiles.save(output,unsupported,state,"Invalid trial").ok and FileAccess.get_file_as_bytes(output)==original,"failed validation preserves previous saved profile bytes")
	DirAccess.remove_absolute(output)
	for entry: Dictionary in Scenes.SCENES:
		var built := Scenes.build(str(entry.id),PackedInt32Array([1]))
		expect(built.get("ok",false),"ordinary authored scene validates: " + str(entry.id))
		expect(built.setup.liquid_policy == [1],"demo preserves incoming solver family without implicit retuning: " + str(entry.id))
		expect(built.setup.edits.size() > 10 and built.setup.edits.size() < 512,"demo construction stays finite and bounded: " + str(entry.id))
		expect(not built.setup.has("material_profile"),"scene recipe and runtime material profile remain explicit separate artifacts")
	print("MAT_AUDITION_PROFILE: %d checks, %d failures; schema and UI-contract evidence only" % [checks,failures])
	quit(1 if failures else 0)
