extends SceneTree

# The owner's exact uploaded recipe is reconstructed in the ordinary native
# Workbench. Its former live poses/sleep state are deliberately not asserted.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
var f: RefCounted
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	f = Fixture.new(self)
	if not await f.open("owner_tower"): await _finish(); return
	observations.recipe_sha256 = FileAccess.get_sha256(Fixture.Scenes.OWNER_TOWER_PATH)
	f.expect(observations.recipe_sha256=="ad00c753b10c0a1372f2a12ef0e81300ad335ca6d5cdb81290586e13f1dad19a",
		"actual installed owner recipe preserves the exact attached bytes")
	var before: Dictionary = {"wood":f.material_count(7),"brick":f.material_count(43)}
	f.expect(int(before.wood)+int(before.brick)==5465,"reconstructed owner recipe has the independently censused structural population")
	f.play()
	if not await f.advance(90,"owner-authored eroded construction sustains ordinary native and physical progression"):
		await _finish(); return
	if not await f.pause(): await _finish(); return
	f.expect(f.body_count()>0 and f.body_count()<=16,"ordinary discovery creates a bounded current physical owner population")
	f.expect(f.material_count(7)==int(before.wood) and f.material_count(43)==int(before.brick),
		"owner-authored Wood and Brick remain singly owned through fresh collapse")
	f.validate_physics()
	await f.validate_quantity_ledger()
	observations.authored_population = before
	observations.reconstructed_owned_bodies = f.body_count()
	observations.original_live_state_restored = false
	await _finish()

func _finish() -> void:
	if f.host!=null:
		observations.final = f.diagnostics()
		observations.display = f.display_witness()
		f.validate_display()
	await f.close()
	print(JSON.stringify({"schema":"objectshard-m4-owner-authored-v1","checks":f.checks,"failures":f.failures,
		"observations":observations,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
		"scope":"actual native/Rapier reconstruction of exact owner-authored start; no prior live-state or physical-owner replay claim"}))
	quit(0 if f.failures.is_empty() else 1)
