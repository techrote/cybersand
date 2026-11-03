extends SceneTree

# Actual paused worker-owner inspection only. No Rapier steps, impact run or
# Rest efficacy population. Remote Water pockets exercise all four census tiles.
const Session = preload("res://scripts/solid_detachment_session.gd")
const TOTAL: int = 1024*1024
const REGION := Rect2i(0,0,160,128)

class WaterCensusSession:
	extends Session
	var water_maximum: int = 0
	func _author_surroundings(native: Object,kind: String) -> bool:
		if not super._author_surroundings(native,kind): return false
		water_maximum=int(native.get_water_experiment_policy().maximum)
		# Each closed4x4 pocket contains12 Wall and4 full Water cells. They
		# remain inside distinct global census tiles, far outside REGION.
		for origin: Vector2i in [Vector2i(500,200),Vector2i(700,200),Vector2i(500,900),Vector2i(700,900)]:
			if not native.diagnostic_fill_rect(origin-Vector2i.ONE,Vector2i(4,4),1): return false
			if not native.diagnostic_fill_rect(origin,Vector2i(2,2),3): return false
		return true

var checks: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		printerr("FAIL REST CENSUS ",message)

func census(reply: Dictionary,label: String) -> Dictionary:
	check(reply.get("ok",false),label+" owner inspect succeeds")
	var value: Dictionary = reply.get("global_census",{})
	check(value.get("ok",false),label+" complete global census")
	check(value.get("domain",[])==[0,0,1024,1024] and int(value.get("tiles",0))==4,label+" full four-tile domain")
	check(not value.has("cells") and not value.has("hash"),label+" compact publication discards cells/hash")
	var counts: Array = value.get("counts",[])
	var sum: int = 0
	for count: Variant in counts:
		check(count is int and int(count)>=0,label+" exact nonnegative integer count")
		if count is int: sum+=int(count)
	check(sum==TOTAL,label+" exact1048576 cell population")
	var regional: Dictionary = reply.get("diagnostic_snapshot",{})
	check(int(value.get("completed_ticks",-1))==int(regional.get("completed_ticks",-2)),label+" all census tiles and regional observation share native tick")
	observations.append({"label":label,"completed_ticks":value.get("completed_ticks",-1),"counts":counts.duplicate(),"water_mass":value.get("water_mass",-1)})
	return value

func known_counts(value: Dictionary,expected: Dictionary,label: String) -> void:
	var counts: Array = value.get("counts",[])
	check(counts.size()>43,label+" full material table")
	if counts.size()<=43: return
	var occupied: int = 0
	for index: int in range(1,counts.size()):
		var wanted: int = int(expected.get(index,0))
		occupied+=wanted
		check(int(counts[index])==wanted,label+" material"+str(index))
	check(int(counts[0])==TOTAL-occupied,label+" exact Empty complement")

func regional_equivalence(value: Dictionary,regional: Dictionary,label: String) -> void:
	var global_counts: Array = value.get("counts",[])
	var regional_counts: Array = regional.get("counts",[])
	check(global_counts.size()==regional_counts.size(),label+" regional material table matches")
	if global_counts.size()!=regional_counts.size(): return
	for index: int in range(global_counts.size()):
		var outside: int = TOTAL-REGION.size.x*REGION.size.y if index==0 else 0
		check(int(global_counts[index])==int(regional_counts[index])+outside,label+" all material inside regional bounds"+str(index))
	check(value.get("water_mass",-1)==regional.get("water_mass",-2),label+" exact regional/global Water quantity")

func same_material(before: Dictionary,after: Dictionary,label: String) -> void:
	var a: Dictionary = before.get("diagnostic_snapshot",{})
	var b: Dictionary = after.get("diagnostic_snapshot",{})
	check(a.get("hash","")==b.get("hash","missing"),label+" full native state hash unchanged by inspection")
	check(a.get("cells",PackedByteArray())==b.get("cells",PackedByteArray([255])),label+" regional material cells unchanged")
	check(a.get("counts",[])==b.get("counts",[999]) and a.get("water_mass",-1)==b.get("water_mass",-2),label+" exact regional quantities unchanged")
	check(int(a.get("completed_ticks",-1))==int(b.get("completed_ticks",-2)),label+" paused owner did not tick")

func plain_and_payload() -> void:
	var session = Session.new()
	check(await session.open(root,1,"empty",true,"LA",{"gravity":0.},{"mode":"control","budget":20.}),"actual paused control owner opens")
	if session.worker==null: return
	session.set_paused(true)
	var ordinary: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION)
	check(not ordinary.has("global_census"),"ordinary inspection keeps optional census disabled")
	var before: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
	var first: Dictionary = census(before,"intact")
	known_counts(first,{1:512,43:629},"known initial recipe")
	check(int(first.get("water_mass",-1))==0,"dry initial exact Water quantity0")
	regional_equivalence(first,before.get("diagnostic_snapshot",{}),"intact")
	same_material(ordinary,before,"optional census")
	var again: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
	var second: Dictionary = census(again,"intact repeated")
	check(first==second,"repeated census returns identical compact totals")
	same_material(before,again,"repeated census")
	# Replies are caller-owned copies. Altering one can never alter native cells
	# or a subsequent exclusive-worker publication.
	if not first.get("counts",[]).is_empty(): first.counts[0]=-123
	first.water_mass=-456
	var copied: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
	var intact: Dictionary = census(copied,"after caller mutation")
	known_counts(intact,{1:512,43:629},"copied reply isolated")
	check(int(intact.get("water_mass",-1))==0,"caller Water mutation cannot affect World")
	same_material(again,copied,"caller reply mutation")
	check(await session.cut_and_release(),"actual native cut/lease transfer")
	if session.active:
		session.set_paused(true)
		var released: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
		var payload: Dictionary = census(released,"detached payload")
		known_counts(payload,{1:512,43:101},"native remainder after transfer")
		check(int(released.get("aggregate_owned",-1))==520 and int(session.source_receipt.get("member_count",-1))==520,"one native payload owns520 Brick cells")
		check(int(payload.counts[43])+int(released.get("aggregate_owned",-1))+Session.CUT.size.x*Session.CUT.size.y==629,"native101 plus detached520 plus intentional cut8 closes629")
		regional_equivalence(payload,released.get("diagnostic_snapshot",{}),"detached")
		var repeated: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
		census(repeated,"detached repeated")
		same_material(released,repeated,"detached inspection")
		check(session.bridge.manual_step_count()==0,"census/payload mechanics take no Rapier steps")
	session.close()

func remote_water_tiles() -> void:
	var session := WaterCensusSession.new()
	check(await session.open(root,1,"empty",true,"LA",{"gravity":0.},{"mode":"control","budget":20.}),"four-quadrant Water owner opens")
	if session.worker==null: return
	session.set_paused(true)
	var first: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
	var full: Dictionary = census(first,"four-quadrant Water")
	known_counts(full,{1:560,3:16,43:629},"known four-pocket recipe")
	check(session.water_maximum>0 and int(full.get("water_mass",-1))==16*session.water_maximum,"exact16 full-cell Water quantities from applied native maximum")
	var regional: Dictionary = first.get("diagnostic_snapshot",{})
	check(int(regional.get("water_mass",-1))==0 and int(regional.get("counts",[0,0,0,999])[3])==0,"regional snapshot cannot observe remote Water")
	check(int(full.counts[1])-int(regional.counts[1])==48,"global census includes remote hard containers")
	var native_tick: int = int(full.completed_ticks)
	for origin: Vector2i in [Vector2i(500,200),Vector2i(700,200),Vector2i(500,900),Vector2i(700,900)]:
		var local: Dictionary = await session.inspect_coupling(PackedInt32Array(),Rect2i(origin-Vector2i.ONE,Vector2i(4,4)),true)
		var current: Dictionary = census(local,"Water tile "+str(origin))
		check(current==full and int(current.completed_ticks)==native_tick,"each quadrant inspection sees one unchanged global population")
		var pocket: Dictionary = local.get("diagnostic_snapshot",{})
		check(int(pocket.counts[1])==12 and int(pocket.counts[3])==4 and int(pocket.water_mass)==4*session.water_maximum,"known pocket exact local counts/Water")
	var last: Dictionary = await session.inspect_coupling(PackedInt32Array(),REGION,true)
	census(last,"Water repeated")
	same_material(first,last,"global Water inspection")
	session.close()

func _run() -> void:
	await plain_and_payload()
	await remote_water_tiles()
	print("GCR_REST_CENSUS ",JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"observations":observations,
		"scope":"actual paused exclusive worker; exact global stored-cell/Water census, tile coverage, immutable copied replies and detached-payload accounting; zero Rapier steps or efficacy trajectory"}))
	quit(0 if failures.is_empty() else 1)
