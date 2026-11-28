extends SceneTree

const Profiles = preload("res://scripts/transport_profiles.gd")
# Captured from the unchanged production compiler at cf6ec2e255, before the
# reuse repair. These bind all 39,529 integer values, including directed pairs.
const GOLDEN := ["1b27b4e934dc7560e6901eb09e634ed604c0111dcf26d5dac6b10885a3e5e268",
	"a4593c9c8632463d5b9100233809b530ef7043502bcd66444fa7930a422816e7",
	"57d8ed905b2ad52c6f1372560c4fafb9dad5a03135ca987dee05f6167428e079"]
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("TRANSPORT_REUSE: "+label)

func digest(value: PackedInt32Array) -> String:
	return value.to_byte_array().hex_encode().sha256_text()

func thread_calls(offset: int) -> Array[String]:
	var errors: Array[String] = []
	for repeat in range(3):
		for index in range(3):
			var preset := (index+offset)%3
			var profile := Profiles.preset(preset)
			for warm in range(3):
				var result := Profiles.resolve(profile)
				if not result.get("ok",false) or result.hash != GOLDEN[preset] or digest(result.packed) != GOLDEN[preset]:
					errors.append("Concurrent caller received a foreign or changed compiled table")
				# Each thread may edit its returned values without changing another
				# thread's retained input, table or profile metadata.
				result.packed[0] = 99
				result.profile.materials["33"].permeability = 5
	return errors

func _initialize() -> void:
	for preset in range(3):
		var profile := Profiles.preset(preset)
		var first := Profiles.resolve(profile)
		var second := Profiles.resolve(profile)
		check(first.ok and second.ok and first.packed.size()==39529,
			"Cold and warm production compilation admit preset "+str(preset))
		check(digest(first.packed)==GOLDEN[preset] and digest(second.packed)==GOLDEN[preset]
			and first.hash==GOLDEN[preset] and second.hash==GOLDEN[preset],"All compiled bytes match the prior compiler")
		first.packed[0] = 99
		first.profile.families.powder.mixing = 255
		if not first.profile.pairs.is_empty(): first.profile.pairs[0].values.carrying = 0
		var isolated := Profiles.resolve(profile)
		check(digest(isolated.packed)==GOLDEN[preset] and isolated.profile==profile,
			"Returned packed arrays and nested profile edits cannot mutate retained values")
	var mutable := Profiles.preset(0)
	Profiles.resolve(mutable)
	mutable.materials["33"].permeability = 17
	var changed := Profiles.resolve(mutable)
	check(changed.ok and changed.hash!=GOLDEN[0] and changed.profile==mutable,
		"In-place changes to the caller's original nested profile invalidate reuse")
	mutable.materials["33"].permeability = 30
	check(Profiles.resolve(mutable).hash==GOLDEN[0],"Returning to the original input preserves original compiled bytes")
	mutable.name = "Renamed same laws"
	var renamed := Profiles.resolve(mutable)
	check(renamed.hash==GOLDEN[0] and renamed.profile.name==mutable.name,
		"Profile metadata is the actual current request even when compiled laws are equal")
	var bad := Profiles.preset(0)
	bad.pairs = [{"source":2,"target":3,"direction":"directed","values":{"carrying":1}}]
	check(not Profiles.resolve(bad).ok,"A warmed profile never admits forbidden carrying direction")
	bad = Profiles.preset(0)
	bad.materials["33"].permeability = 0
	check(not Profiles.resolve(bad).ok,"A warmed profile never admits an invalid material range")
	bad = Profiles.preset(0)
	bad.version = 2
	check(not Profiles.resolve(bad).ok,"A warmed profile never admits a foreign schema")
	var left := Thread.new()
	var right := Thread.new()
	check(left.start(thread_calls.bind(0))==OK,"First concurrent value compiler starts")
	check(right.start(thread_calls.bind(1))==OK,"Second concurrent value compiler starts")
	var left_errors: Array = left.wait_to_finish()
	var right_errors: Array = right.wait_to_finish()
	check(left_errors.is_empty() and right_errors.is_empty(),"Concurrent Main/worker-style callers retain complete isolated values")
	print("PUBPRES_TRANSPORT_REUSE_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(int(not failures.is_empty()))
