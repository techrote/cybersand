extends "res://tools/qualify_workbench_strata.gd"

## External, read-only evidence fixture. Application files are unchanged.
const Provenance = preload("res://scripts/depth/strata_authoring_provenance.gd")

func run() -> void:
	scene_id = "source4-retained-native-import-save"
	phase = "supplemental-fresh-process-reopen"
	var oracle_path := OS.get_environment("STRATA_REOPEN_ORACLE")
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	output = OS.get_environment("STRATA_EVIDENCE")
	record = {"schema":"strata2-supplemental-fresh-import-reopen-v1", "completed":false,
		"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION"), "process_id":OS.get_process_id(),
		"display_server":DisplayServer.get_name(), "writer_process_id":int(oracle.writer_process_id),
		"writer_source_field":str(oracle.writer_source_field), "oracle_sha256":FileAccess.get_sha256(oracle_path),
		"fixture_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scope":"Fresh headless ordinary Main/Workbench load of an unchanged prior writer save; actual native readback, no new authoring, graphical or physical-owner claim."}
	check(record.source_revision == oracle.source_commit, "reader exact application source is explicit")
	check(record.process_id != int(oracle.writer_process_id), "reader OS process differs from retained writer process")
	var saved_path: String = Setup._path(str(oracle.save_name))
	record.saved_path = ProjectSettings.globalize_path(saved_path)
	record.save_sha256_before = FileAccess.get_sha256(saved_path)
	check(record.save_sha256_before == oracle.save_sha256, "isolated user directory contains exact original save bytes")
	set_meta("cybersand_feature", "shared_workbench")
	host = load("res://main.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	wb = host.shared_workbench
	for control: SpinBox in wb._extent: control.value = 512
	if not await until(idle, "fresh ordinary default initial admission"): finish(); return
	check(wb.strata == null, "fresh ordinary default has no Strata controller")
	wb._name.text = str(oracle.save_name)
	if not check(wb.load_setup(), "ordinary Workbench named loader accepts retained authored scene"): finish(); return
	strata = wb.strata
	if not await until(func() -> bool: return idle() and is_instance_valid(strata) and strata.has_document() and host.physical_actor_session != null,
			"fresh Workbench adopts play and three decorative native owners"): finish(); return
	check(host.paused, "fresh authored composition starts with Play paused")
	var owners: Dictionary = strata.layer_owner.stats()
	check(owners.native_world_count == 3 and not owners.owns_play_world, "fresh composition has three independent decorative owners and one borrowed Play")
	check(str(owners.session_id) != str(oracle.writer_owner_session), "fresh decorative owner session is distinct from historical writer")
	record.fresh_play_identity = play_identity()
	record.fresh_owner_session = owners.session_id
	var document: Dictionary = strata.document()
	check(document == Document.canonical(oracle.document), "all authored document fields exactly survive ordinary fresh loading")
	check(document.authoring == Provenance.canonical(oracle.writer_provenance), "all historical import/construction records survive exactly")
	check(document.authoring.records.size() == int(oracle.provenance_records), "historical record count is retained")
	check(document.atmosphere == Document.canonical(oracle.document).atmosphere, "atmosphere seed/region/settings survive authored reload")
	record.document = document
	record.native_hashes = {}
	var play := await play_bytes()
	record.native_hashes.play = digest(play)
	check(record.native_hashes.play == oracle.native_hashes.play and record.native_hashes.play == oracle.writer_play_hash_imported,
		"fresh full Play native hash equals independent saved-layout oracle and original imported writer state")
	var probes := {}
	for row: Array in oracle.play_probes:
		var actual := int(play.decode_u16((int(row[1]) * 512 + int(row[0])) * 2))
		probes[str(row[0]) + "," + str(row[1])] = actual
		check(actual == int(row[2]), "fresh actual Play imported pixel/cutout " + str(row))
	record.play_probes = probes
	for id: String in ["scripted", "effects", "background"]:
		var native := decorative_bytes(id)
		record.native_hashes[id] = digest(native)
		check(record.native_hashes[id] == oracle.native_hashes[id], "fresh full native " + id + " equals independent ordered-layout oracle")
		check(record.native_hashes[id] == oracle.writer_decorative_hashes[id], "fresh native " + id + " retains actual completed writer composition")
		var row: Dictionary = owners.layers[id]
		check(row.clock_mode == "static" and row.paused and row.rate_hz == 0 and row.native_tick == 0,
			"fresh decorative " + id + " remains static with no actor simulation")
	record.save_sha256_after = FileAccess.get_sha256(saved_path)
	check(record.save_sha256_after == oracle.save_sha256, "fresh read-only loading leaves exact saved file unchanged")
	record.fresh_process_reopen = true
	record.explicit_native_edit_requests_by_fixture = 0
	record.composition_material_hashes_match_writer = true
	finish()
