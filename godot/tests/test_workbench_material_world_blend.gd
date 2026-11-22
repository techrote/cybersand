extends SceneTree

## The production Main intake receives exact complete render messages. This
## isolates same-size World replacement from native turn and wall scheduling.
const Main = preload("res://scripts/main.gd")
const EXTENT := Vector2i(16, 16)
const TIMING_ENV := "CYBERSAND_DIAG_MATERIAL_TIMING"

class AckProbe extends "res://scripts/simulation_worker.gd":
	var serials: Array[int] = []
	func acknowledge_render_snapshot(serial: int) -> void:
		serials.append(serial)

var assertions := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _require(ok: bool, detail: String) -> void:
	assertions += 1
	if not ok:
		failures.append(detail)
		push_error("WORKBENCH_MATERIAL_WORLD_BLEND " + detail)


func _packet(serial: int, generation: int, revision: int, material: int) -> CyberSimulationSnapshot:
	var snapshot := CyberSimulationSnapshot.new()
	snapshot.render_world_generation = generation
	snapshot.world_revision = revision
	snapshot.render_snapshot_serial = serial
	snapshot.render_tick_index = revision
	snapshot.render_generated_usec = Time.get_ticks_usec()
	snapshot.render_channels = 2
	snapshot.render_full_refresh = true
	snapshot.render_patch_rectangles = PackedInt32Array([0,0,EXTENT.x,EXTENT.y,0,EXTENT.x*2])
	var pixels := Image.create(EXTENT.x,EXTENT.y,false,Image.FORMAT_RG8)
	pixels.fill(Color8(material,137,0))
	snapshot.render_patch_cells = pixels.get_data()
	return snapshot


func _case(timing: String) -> void:
	OS.set_environment(TIMING_ENV,timing)
	var host = Main.new()
	var ack := AckProbe.new()
	host.simulation_worker = ack
	host.shared_workbench = Control.new()
	host.world_extent = EXTENT
	host.render_channels = 2
	host.render_image_format = Image.FORMAT_RG8
	host.image = Image.create(EXTENT.x,EXTENT.y,false,Image.FORMAT_RG8)
	host.cadence_lod_enabled = true
	host.create_render_textures()

	var first := _packet(1,42,1,58)
	var same_world := _packet(2,42,2,3)
	var replacement := _packet(3,43,1,6)
	host.consume_render_snapshot(first)
	host.consume_render_snapshot(same_world)
	var same_state: Dictionary = host._material_presentation_state(host.snapshot_blend_start_usec)
	_require(same_state.previous_blend_active and same_state.previous.generation == 42,
		timing+" same-World transport refresh retains truthful previous material")
	var old_current: RID = host.texture.get_rid()
	host.consume_render_snapshot(replacement)
	var replacement_state: Dictionary = host._material_presentation_state(host.snapshot_blend_start_usec)
	_require(host.last_uploaded_world_generation == 43 and host.last_uploaded_render_snapshot_serial == 3
		and ack.serials == [1,2,3],timing+" exact replacement advances generation and ACK")
	_require(host.previous_texture.get_rid() == old_current
		and host._presentation_previous_bytes == same_world.render_patch_cells
		and host.image.get_data() == replacement.render_patch_cells,
		timing+" keeps both physical histories in their exact transaction order")
	_require(replacement_state.current.generation == 43 and replacement_state.previous.is_empty()
		and not replacement_state.previous_blend_active and replacement_state.snapshot_blend == 1.0,
		timing+" replacement gives old-World material zero presentation weight")
	host.consume_render_snapshot(_packet(4,43,2,9))
	var renewed_state: Dictionary = host._material_presentation_state(host.snapshot_blend_start_usec)
	_require(renewed_state.previous_blend_active and renewed_state.previous.generation == 43
		and ack.serials == [1,2,3,4],timing+" blending resumes after an exact same-World predecessor")
	observations.append({"timing":timing,"replacement_state":replacement_state,
		"same_world_previous_active":same_state.previous_blend_active,
		"renewed_world_previous_active":renewed_state.previous_blend_active,"acknowledged_serials":ack.serials})
	host.shared_workbench.free()
	host.shared_workbench = null
	host.free()


func _run() -> void:
	var prior: String = OS.get_environment(TIMING_ENV)
	_case("legacy")
	_case("measured")
	OS.set_environment(TIMING_ENV,prior)
	print("WORKBENCH_MATERIAL_WORLD_BLEND_RESULT ",JSON.stringify({"assertions":assertions,
		"failures":failures,"observations":observations,"source_revision":OS.get_environment("CYBERSAND_SOURCE_REVISION")}))
	quit(int(not failures.is_empty()))
