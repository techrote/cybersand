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

func check_staging_slot(stats: Dictionary, expected_slot: int, slots: Dictionary,
		owners: Dictionary, ring: String, context: String) -> void:
	var rid: int = stats.staging_resource_rid
	require(stats.staging_slot == expected_slot and rid > 0,context + " advances its own staging cursor")
	require(int(slots.get(expected_slot,rid)) == rid,context + " reuses the same resource after wrap")
	var owner: String = "%s slot %d" % [ring,expected_slot]
	require(owners.get(rid,owner) == owner,context + " has a staging resource disjoint from every other slot")
	slots[expected_slot] = rid
	owners[rid] = owner

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
	var owners: Dictionary = {}
	var cadence: int = publisher.staging_slots
	for capacity: int in [1,4]:
		var history_slots: Dictionary = {}
		var ordinary_slots: Dictionary = {}
		for cycle: int in range(cadence + 1):
			for phase: int in range(4):
				var context := "capacity %d cycle %d phase %d" % [capacity,cycle,phase]
				var next: Image = prior.duplicate()
				var regions: Array[Rect2i] = [FULL]
				if phase < 2:
					next.fill(Color8(87 + phase + cycle,52 + capacity + cycle,0))
					# Preserve an asymmetric landmark well outside either sparse patch.
					next.fill_rect(Rect2i(EXTENT.x-173,11,156,9),Color8(71+cycle,202-phase,0))
					next.set_pixel(1,EXTENT.y-1,Color8(95,83+cycle,0))
				else:
					regions = [Rect2i(17+cycle,EXTENT.y-47+phase,1,1)]
					next.set_pixelv(regions[0].position,Color8(4+cycle,116+phase,0))
					if capacity == 4:
						# A second touched tile selects the four-tile atlas and exercises NPOT padding.
						regions.append(Rect2i(EXTENT.x-1,EXTENT.y-1,1,1))
						next.set_pixelv(regions[1].position,Color8(57+phase,199+cycle,0))
				if not publisher.publish(next,regions):
					require(false,context + " publication was refused")
					quit(1)
					return
				var stats: Dictionary = publisher.last_update
				var history: bool = phase == 2
				require(bool(stats.get("history_copy",false)) == history,context + " history copy selection")
				require(bool(stats.get("history_staging",false)) == history,context + " history staging selection")
				if phase >= 2:
					require(stats.atlas_capacity == capacity and stats.submitted_bytes == capacity*publisher.tile_side*publisher.tile_side*2,
						context + " stages exactly its sparse atlas in RG8")
					var ring := "%s capacity %d" % ["history" if history else "ordinary",capacity]
					check_staging_slot(stats,(cycle+1)%cadence,history_slots if history else ordinary_slots,owners,ring,context)
				await RenderingServer.frame_post_draw
				require(publisher.current.get_image().get_data() == next.get_data(),context + " current GPU bytes match the new receipt")
				require(publisher.previous.get_image().get_data() == prior.get_data(),context + " previous GPU bytes match the prior receipt")
				require(publisher.resource_identity() == resources,context + " retains the original stages and draw targets")
				prior = next
	print("PUBPRES_TRANSITION_HISTORY staging_slots=%d checks=%d failures=%d" % [cadence,checks,failures])
	quit(int(failures > 0))
