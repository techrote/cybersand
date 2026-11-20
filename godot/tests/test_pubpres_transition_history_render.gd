extends SceneTree

const Publisher = preload("res://scripts/blit_material_publisher.gd")
const EXTENT := Vector2i(2053,1027)
const FULL := Rect2i(Vector2i.ZERO,EXTENT)
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func require(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PUBPRES transition history: " + detail)

func run() -> void:
	if not Publisher.supported_driver():
		require(false,"real Compatibility backend required")
		quit(1)
		return
	var initial := Image.create(EXTENT.x,EXTENT.y,false,Image.FORMAT_RG8)
	initial.fill(Color8(9,72,0))
	var publisher := Publisher.create_pair(initial,initial)
	if publisher == null:
		require(false,"staging preparation refused")
		quit(1)
		return
	var resources: Array[int] = publisher.resource_identity()
	var prior: Image = initial
	for cycle: int in range(3):
		for phase: int in range(4):
			var next: Image = prior.duplicate()
			var region: Rect2i = FULL
			if phase < 2:
				next.fill(Color8(87 + phase + cycle, 52 + phase + cycle, 0))
				# Asymmetric bytes catch orientation and sampling errors in the
				# whole-target copy, outside the following sparse atlas tile.
				next.fill_rect(Rect2i(EXTENT.x-173,11,156,9),Color8(71+cycle,202-phase,0))
				next.set_pixel(1,EXTENT.y-1,Color8(95,83+cycle,0))
			else:
				region = Rect2i(17+cycle,EXTENT.y-47+phase,1,1)
				next.set_pixelv(region.position,Color8(4+cycle,116+phase,0))
			require(publisher.publish(next,[region]),"publication admitted")
			var stats: Dictionary = publisher.last_update
			if phase == 2:
				require(stats.get("history_copy",false) and stats.submitted_bytes == publisher.tile_side*publisher.tile_side*2,
					"first sparse publication copies accepted history and stages exactly one tile")
			else:
				require(not stats.get("history_copy",false),"only first sparse transition copies the current target")
			await RenderingServer.frame_post_draw
			require(publisher.current.get_image().get_data() == next.get_data(),"current GPU bytes match the new receipt")
			require(publisher.previous.get_image().get_data() == prior.get_data(),"previous GPU bytes match the prior receipt")
			require(publisher.resource_identity() == resources,"all stages and both draw targets retain their original identities")
			prior = next
	print("PUBPRES_TRANSITION_HISTORY checks=%d failures=%d" % [checks,failures])
	quit(int(failures > 0))
