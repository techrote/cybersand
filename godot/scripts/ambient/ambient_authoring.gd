extends RefCounted

# Scene-local reusable authored profiles. Assignment always copies a profile;
# editing this library never mutates an admitted controller or its private memory.
const Profile = preload("res://scripts/ambient/ambient_profile.gd")
const MAX_PROFILES := 32


static func blank() -> Dictionary:
	return {"version":1, "profiles":[]}


static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["version", "profiles"]):
		return "Missing or unknown ambient library fields."
	if not (value.version is int or value.version is float) or float(value.version) != 1.0:
		return "Unsupported ambient library version."
	if not value.profiles is Array or value.profiles.size() > MAX_PROFILES:
		return "The scene library supports at most thirty-two profiles."
	var seen := {}
	for item: Variant in value.profiles:
		var error := Profile.validate(item)
		if not error.is_empty(): return "Library profile: " + error
		if seen.has(str(item.id)): return "Library profile IDs must be unique."
		seen[str(item.id)] = true
	return ""


static func canonicalize(value: Dictionary) -> Dictionary:
	if not validate(value).is_empty(): return {}
	var result := blank()
	for profile: Dictionary in value.profiles:
		result.profiles.append(Profile.canonicalize(profile))
	return result
