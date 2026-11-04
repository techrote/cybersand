extends SceneTree

# Actual copied native descriptors, public authoring/save boundary and fallback
# refusal. Native cure/reaction efficacy belongs to the separate core fixtures.
const Cell = preload("res://scripts/cell_world.gd")
const Codec = preload("res://scripts/demo_save_codec.gd")
const Effects = preload("res://scripts/actor_rig_effects.gd")
const Rig = preload("res://scripts/actor_rig_motor.gd")
const Appearance = preload("res://scripts/material_appearance_lut.gd")
var checks: int = 0
var failures: int = 0

func _init() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Paired catalogue: "+reason)

func metadata(material: int) -> Dictionary:
	return {"demo":"material_lab","player":[24.,24.,0.,0.],"material":material,
		"quality":1,"coherent":false,"adhesion":true,"glow":true,"bodies":[]}

func internal_selection_save(encoded: Dictionary) -> PackedByteArray:
	# Forge a correctly checksummed save whose cells remain valid but whose
	# selected paint brush is internal state. This must fail semantic admission.
	var original: PackedByteArray = encoded.binary
	var header: PackedByteArray = original.slice(0,24)
	var body: PackedByteArray = JSON.stringify(metadata(Cell.ACTIVATED_BINDER)).to_utf8_buffer()
	check(body.size()==header.decode_u32(12),"adversarial metadata preserves header lengths")
	body.append_array(original.slice(Codec.HEADER_SIZE+body.size()))
	var forged: PackedByteArray = header.duplicate()
	forged.append_array(Codec._digest(header,body))
	forged.append_array(body)
	return forged

func check_web_selection_refusal(binary: PackedByteArray) -> void:
	var web: Control = load("res://web_main.tscn").instantiate()
	root.add_child(web)
	await process_frame
	web.set_process(false)
	web.set_physics_process(false)
	check(web.ready_to_play,"actual Web import owner is ready")
	if web.ready_to_play:
		var owner: Object = web.native_world
		var before: PackedByteArray = web.demo_bridge.export_level(owner)
		var selected: int = web.selected_material_id
		var imports: int = web.imported_count
		web.ui.show_page("save")
		web.ui.save_text.text=Marshalls.raw_to_base64(binary)
		web.ui.buttons["import"].pressed.emit()
		check(web.last_save_error.contains("internal curing state"),"actual user import explains the internal brush refusal")
		check(web.native_world==owner and web.demo_bridge.export_level(owner)==before and web.selected_material_id==selected and web.imported_count==imports,"rejected internal brush preserves active owner, cells and selection")
	web.queue_free()
	await process_frame

func run() -> void:
	check(ClassDB.class_exists(&"CyberNativeCellWorld") and ClassDB.class_exists(&"CyberDemoBridge"),"native extension available")
	if failures:
		quit(1)
		return
	var bridge: Object = ClassDB.instantiate(&"CyberDemoBridge")
	var profile: Dictionary = bridge.inspect_interaction_profile()
	check(int(profile.get("profile_version",0))==3 and int(profile.get("material_count",0))==138,"matching new native catalogue; stale runtime is refused")
	if failures:
		quit(1)
		return
	var descriptors: Dictionary = {}
	for value: Dictionary in profile.material_catalogue: descriptors[int(value.id)] = value
	check(descriptors.size()==137 and not descriptors.has(10),"reserved ID remains absent")
	var old_hard: int = 0
	for id: int in range(132):
		if id==10: continue
		if id>0: check(Codec.validate_metadata(metadata(id)).is_empty(),"old selected material remains valid: "+str(id))
		var hard: bool = bool(descriptors[id].hard_surface)
		old_hard += int(hard)
		check(Cell.is_hard_material(id)==hard and Rig._hard_material(id)==hard,"native and gameplay old hard capability agree: "+str(id))
	check(old_hard==101,"all 101 prior hard members retained")
	for pair: Array in [[13,132],[23,133],[27,134]]:
		var loose: Dictionary = descriptors[pair[0]]
		var wall: Dictionary = descriptors[pair[1]]
		check(wall.paired_wall and wall.hard_surface and not wall.movable and not wall.supports_granular_load,"wall retains hard form")
		check(int(wall.chemical_parent)==pair[0] and int(wall.loose_counterpart)==pair[0] and int(loose.wall_counterpart)==pair[1],"copied native pair relationship")
		check(int(loose.density)==int(wall.density),"paired form does not fake density")
		check(Cell.is_hard_material(pair[1]) and Rig._hard_material(pair[1]) and Effects.protected_material(pair[1]),"wall gameplay consumers agree")
	for id: int in [135,136]:
		check(not descriptors[id].hard_surface and descriptors[id].movable and descriptors[id].supports_granular_load,"new binder powders are granular, not hard")
		check(CyberInteractionPolicy.supports_load(id),"shared gameplay granular capability includes binder powder")
		check(not Cell.is_hard_material(id) and not Rig._hard_material(id) and not Effects.protected_material(id),"app hard range does not swallow binder powder")
	check(descriptors[137].hard_surface and not descriptors[137].movable and not descriptors[137].supports_granular_load,"crust is hard terrain")
	check([descriptors[135].density,descriptors[136].density,descriptors[137].density]==[1600,1800,2000],"registered binder densities")
	check(int(descriptors[136].initial_state_a)==180 and int(descriptors[136].initial_state_b)==0,"authored activated material carries no manufactured Water")
	profile.material_catalogue.clear()
	check(bridge.inspect_interaction_profile().material_catalogue.size()==137,"descriptor projection is copied, not mutable authority")
	check(Appearance.MATERIAL_COUNT==138 and Appearance.BASE_RGBA8.size()==138 and Appearance.VALUE_VARIATION.size()==138,"palette includes every appended material")
	var program: Image = Appearance.create_program_image()
	check(roundi(program.get_pixel(3,135).a)==Appearance.FLAIR_POWDER and roundi(program.get_pixel(3,136).a)==Appearance.FLAIR_POWDER,"binder powder is presented as grains")
	check(roundi(program.get_pixel(3,137).a)==Appearance.FLAIR_CONCRETE,"crust has a coherent hard finish")
	var fallback = Cell.new()
	fallback.cells.fill(Cell.EMPTY)
	fallback.set_cell(50,50,Cell.SAND)
	check(fallback.material_at(50,50)==Cell.SAND,"fallback retained ordinary material control")
	for id: int in range(132,138):
		var revision: int = fallback.revision
		fallback.set_cell(50,50,id)
		fallback.paint_disc(50,50,0,id)
		fallback._write_direct(50,50,id)
		check(fallback.material_at(50,50)==Cell.SAND and fallback.revision==revision,"fallback refuses unsupported native chemistry without mutation: "+str(id))
	var world: Object = ClassDB.instantiate(&"CyberNativeCellWorld")
	check(world.diagnostic_reset({"workers":1}),"actual native authoring owner")
	for id: int in range(132,138):
		check(world.diagnostic_fill_rect(Vector2i(40+(id-132)*2,40),Vector2i.ONE,id,255 if id==136 else 0),"native authoring admits new ID")
		check(Codec.validate_metadata(metadata(id)).is_empty()==(id!=Cell.ACTIVATED_BINDER),"public selections admit; internal state is not a paint selection: "+str(id))
	var payload: PackedByteArray = bridge.export_level(world)
	var offset: int = (40*1024+48)*5
	check(payload[offset]==136 and payload[offset+1]==180 and payload[offset+2]==255,"CYSD1 carries active countdown and bound quantity")
	var encoded: Dictionary = Codec.encode(payload,metadata(137))
	check(encoded.ok,"CYSD1 encodes new catalogue")
	check(not Codec.encode(payload,metadata(Cell.ACTIVATED_BINDER)).ok,"CYSD1 refuses internal state as selected brush without removing it from cells")
	var forged: PackedByteArray = internal_selection_save(encoded)
	var refused: Dictionary = Codec.decode_binary(forged)
	check(not refused.ok and str(refused.error).contains("internal curing state"),"checksum-valid internal selection is refused semantically")
	await check_web_selection_refusal(forged)
	var decoded: Dictionary = Codec.decode_text(encoded.text)
	check(decoded.ok and decoded.world==payload and decoded.metadata.material==137,"CYSD1 retains new cells and selection")
	check(world.diagnostic_reset({"workers":1}) and bridge.import_level(world,decoded.world),"new cell state restores through native owner")
	check(bridge.export_level(world)==payload,"restored bound quantity and countdown are byte exact")
	var invalid: PackedByteArray = payload.duplicate()
	invalid[0]=138
	check(not bridge.import_level(world,invalid) and bridge.export_level(world)==payload,"unknown material import refuses transactionally")
	check(not world.diagnostic_fill_rect(Vector2i(50,50),Vector2i.ONE,138),"unknown material authoring refuses")
	print("PAIRED_MATERIAL_CATALOGUE ",JSON.stringify({"checks":checks,"failures":failures,"scope":"native descriptors, presentation, save state and fallback refusal; no material-law acceptance"}))
	quit(0 if failures==0 else 1)
