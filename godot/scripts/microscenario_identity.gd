class_name CyberMicroScenarioIdentity
extends RefCounted

# Fingerprint executable inputs, not an old publication manifest. A checkout SHA
# is supplied by a runner/build; it is never inferred from historical BUILD_ID.
const SOURCES: Array[String] = [
	"scripts/microscenario_contract.gd", "scripts/microscenario_catalogue.gd",
	"scripts/microscenario_host.gd", "scripts/microscenario_panel.gd",
	"scripts/microscenario_identity.gd", "scripts/cell_world.gd",
	"scripts/material_appearance_lut.gd", "scripts/sampled_character.gd",
	"scripts/simulation_worker.gd", "scripts/main.gd", "scripts/web_demo_controller.gd",
	"scripts/experiment_tower.gd", "scripts/water_feel_scenarios.gd",
	"scripts/transport_profiles.gd", "scripts/water_experiment_profiles.gd",
	"scripts/water_experiment_contract.gd"]

static func current(source_revision: String = "unavailable") -> Dictionary:
	var sources: Dictionary = {}
	for path: String in SOURCES:
		sources[path] = FileAccess.get_sha256("res://" + path) if FileAccess.file_exists("res://" + path) else "unavailable"
	var native_path: String = "res://addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so"
	if OS.get_name() == "Windows": native_path = "res://addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll"
	if OS.has_feature("web"):
		native_path = "res://addons/cybersand_native/bin/libcybersand_native.web.%s.wasm" % ("threads" if OS.has_feature("threads") else "nothreads")
	return {"source_revision":source_revision, "revision_status":"caller-supplied" if source_revision != "unavailable" else "not-embedded",
		"script_sha256":sources, "script_set_sha256":JSON.stringify(sources).sha256_text(),
		"source_scope":"listed apparatus scripts; not a full checkout manifest",
		"native_path":native_path, "native_sha256":FileAccess.get_sha256(native_path) if FileAccess.file_exists(native_path) else "unavailable",
		"material_catalogue":{"count":81, "reserved_ids":[10],
			"authority":"native artifact; cell_world.gd identifies the UI mirror"},
		"platform":OS.get_name(), "godot":Engine.get_version_info().get("string", "unknown")}
