extends SceneTree

# New external authored-input observer. It drives mounted ordinary Workbench
# controls and reads actual native/Rapier state; it never writes either state.
const Fixture = preload("res://tests/support/object_shard_m4_workbench_fixture.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const EXPECTED_SOURCE := "5f0722ae231d955a98a83b0fbb9a0e7517ef2d8a"
const EXPECTED_TREE := "51ff1e6a0949dff3b2b17cdca7a40d4943b05f78"
const SCHEMA := "objectshard-m4-ordinary-sand-lodging-v1"
const LABEL := "m4-recovery-sand-pocket"
const WOOD := 7
const SAND := 2
const WALL := 1
const CARGO_ROLE := 3 # frozen native enum: Empty, Structural, Product, Cargo
var f: RefCounted
var output := ""
var nonce := ""
var evidence: Dictionary = {"mounted_actions":[],"mounted_strokes":[]}
var owner := 0
var intake: Dictionary = {}

func _initialize() -> void:
    for arg: String in OS.get_cmdline_user_args():
        if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
        elif arg.begins_with("--nonce="): nonce=arg.trim_prefix("--nonce=")
    _run.call_deferred()

func _buttons(node: Node, caption: String, found: Array[Button]) -> void:
    if node is Button and node.text==caption: found.append(node)
    for child: Node in node.get_children(): _buttons(child,caption,found)

func _press(caption: String) -> bool:
    var found: Array[Button] = []
    _buttons(f.host,caption,found)
    if not f.expect(found.size()==1 and not found[0].disabled,"one enabled mounted control: "+caption): return false
    found[0].pressed.emit()
    evidence.mounted_actions.append({"caption":caption,"node_path":str(found[0].get_path()),
        "native_tick":f.tick(),"paused":f.host.paused})
    return true

func _play() -> bool:
    if f.host.paused and not _press("Play / Pause [P]"): return false
    return f.expect(not f.host.paused,"mounted Play resumes the actual owner")

func _pause() -> bool:
    if not f.host.paused and not _press("Play / Pause [P]"): return false
    return await f.pause()

func _shard(frame: Dictionary) -> Dictionary:
    for item: Dictionary in frame.get("shards",[]):
        if item.get("owns_inventory",false) and (owner==0 or int(item.id)==owner): return item
    return {}

func _native(frame: Dictionary) -> Dictionary:
    # One immutable frame reference supplies both tick and all cell identities.
    var shard: Dictionary = _shard(frame)
    if shard.is_empty(): return {}
    var value: Dictionary = {"frame_tick":int(frame.get("tick",-1)),
        "publication_sequence":int(frame.get("publication_sequence",-1)),
        "world_generation":frame.get("world_generation"),"world_revision":frame.get("world_revision"),
        "sand_ingested":int(frame.get("metrics",{}).get("sand_ingested",0)),
        "sand_cells":[],"wood_cells":0,"cargo_cells":0}
    for key: String in ["id","generation","body_generation","geometry_revision","applied_physics_revision",
        "geometry_pending","material_revision","width","height","mass","com_x","com_y","inertia",
        "position_x","position_y","rotation"]:
        value[key]=shard.get(key)
    for cell: int in range(shard.materials.size()):
        if int(shard.materials[cell])==WOOD: value.wood_cells+=1
        if int(shard.roles[cell])==CARGO_ROLE: value.cargo_cells+=1
        if int(shard.materials[cell])==SAND:
            value.sand_cells.append({"cell":cell,"role":int(shard.roles[cell]),
                "incarnation":int(shard.incarnations[cell]),"state_a":int(shard.states_a[cell]),
                "state_b":int(shard.states_b[cell]),"temperature":int(shard.temperature[cell])})
    return value

func _physics() -> Dictionary:
    if owner==0 or not f.runtime().bridge.bodies.has(owner): return {}
    var body: Dictionary = f.runtime().bridge.bodies[owner]
    var rid: RID = body.rid
    var pose: Transform2D = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_TRANSFORM)
    var velocity: Vector2 = PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
    var com: Vector2 = PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_CENTER_OF_MASS)
    return {"owner":owner,"generation":int(body.generation),"body_generation":int(body.body_generation),
        "rid":rid.get_id(),"physical_step":int(f.runtime().physical_steps),"bridge_step":int(f.runtime().bridge.steps),
        "geometry_revision":int(body.geometry_revision),"last_geometry_step":int(body.last_geometry_step),
        "native_tick":f.tick(),"x":pose.origin.x,"y":pose.origin.y,"rotation":pose.get_rotation(),
        "vx":velocity.x,"vy":velocity.y,
        "angular_velocity":float(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)),
        "sleeping":bool(PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_SLEEPING)),
        "mass":float(PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_MASS)),
        "com_x":com.x,"com_y":com.y,
        "inertia":float(PhysicsServer2D.body_get_param(rid,PhysicsServer2D.BODY_PARAM_INERTIA)),
        "shape_count":PhysicsServer2D.body_get_shape_count(rid),"paused":f.host.paused}

func _local(point: Vector2i) -> Vector2:
    var area: Rect2 = f.host.view_content_rect()
    return area.position+(Vector2(point)-Vector2(f.host.camera_origin.floor())+Vector2(0.5,0.5))*area.size/Vector2(f.host.current_view_size)

func _button_event(point: Vector2i, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position=_local(point)
    event.button_index=MOUSE_BUTTON_LEFT
    event.pressed=pressed
    f.host.world_view.gui_input.emit(event)

func _stroke(points: Array[Vector2i], erasing: bool, label: String) -> bool:
    if not f.expect(f.host.paused and not points.is_empty() and not f.bench.busy(),
        "mounted precise brush begins at an ordinary paused authoring boundary"): return false
    f.bench._tool.select(0)
    f.bench._tool.item_selected.emit(0)
    var selected: int = 1 if erasing else 0
    f.bench.paint_editor.tools.select(selected)
    f.bench.paint_editor.tools.item_selected.emit(selected)
    f.bench._brush.value=0
    if not erasing:
        var material_index := -1
        for index: int in range(f.bench._material.item_count):
            if f.bench._material.get_item_id(index)==SAND: material_index=index
        if not f.expect(material_index>=0,"ordinary material picker contains native Sand"): return false
        f.bench._material.select(material_index)
        f.bench._material.item_selected.emit(material_index)
    if not f.expect(f.bench.paint_editor.radius()==0 and f.bench.paint_editor.tool_name()==("Eraser" if erasing else "Brush"),
        "mounted tools select a true one-cell-radius-zero stroke"): return false
    var previous_operation: int = int(f.bench.paint_editor.last_receipt.get("operation_id",-1))
    var before_tick: int = f.tick()
    var before_steps: int = int(f.runtime().physical_steps)
    _button_event(points[0],true)
    for index: int in range(1,points.size()):
        var event := InputEventMouseMotion.new()
        event.position=_local(points[index])
        event.button_mask=MOUSE_BUTTON_MASK_LEFT
        f.host.world_view.gui_input.emit(event)
    _button_event(points.back(),false)
    if not await f.until(func(): return not f.bench.busy() and int(f.bench.paint_editor.last_receipt.get("operation_id",-1))!=previous_operation,
        "actual native paint receipt returns for "+label,60000): return false
    var receipt: Dictionary = f.bench.paint_editor.last_receipt.duplicate(true)
    evidence.mounted_strokes.append({"label":label,"tool":"Eraser" if erasing else "Brush","radius":0,
        "material":0 if erasing else SAND,"points":points.duplicate(),"before_tick":before_tick,
        "before_physical_steps":before_steps,"receipt":receipt,"after_tick":f.tick(),
        "after_physical_steps":int(f.runtime().physical_steps)})
    if not f.expect(receipt.get("status")=="completed" and int(receipt.get("applied",-1))==points.size(),
        "ordinary paused edit applies exactly the authored cells for "+label): return false
    if not await _pause(): return false
    return f.expect(f.tick()==before_tick and int(f.runtime().physical_steps)==before_steps,
        "paused brush changes materials without advancing native or physical time")

func _pocket() -> Dictionary:
    var shard: Dictionary = _shard(f.runtime().publication)
    if shard.is_empty(): return {}
    var width: int = int(shard.width)
    var height: int = int(shard.height)
    # Observe the exact documented three-cell upward-open pocket in the owned
    # source lattice. This is a readback precondition, never a native mutation.
    for y: int in range(1,height-1):
        for left: int in range(1,width-4):
            var right: int = left+3
            if int(shard.roles[y*width+left-1])!=1 or int(shard.roles[y*width+right])!=1: continue
            var valid := true
            for x: int in range(left,right):
                if int(shard.roles[(y+1)*width+x])!=1: valid=false
                for above: int in range(y+1):
                    if int(shard.materials[above*width+x])!=0: valid=false
            if not valid: continue
            var pose := Transform2D(float(shard.rotation),Vector2(float(shard.position_x),float(shard.position_y)))
            var local_center := Vector2(float(left)+1.5,float(y)+0.5)
            var world_center: Vector2 = pose*local_center
            var drop := Vector2i(floori(world_center.x),floori(world_center.y)-6)
            var source_cell: int = y*width+left+1
            return {"owner":int(shard.id),"generation":int(shard.generation),"body_generation":int(shard.body_generation),
                "width":width,"height":height,"left":left,"right":right,"row":y,"cell":source_cell,
                "local_center":[local_center.x,local_center.y],"world_center":[world_center.x,world_center.y],
                "drop":[drop.x,drop.y],"geometry_revision":int(shard.geometry_revision),
                "empty_incarnations":[int(shard.incarnations[y*width+left]),int(shard.incarnations[y*width+left+1]),
                    int(shard.incarnations[y*width+left+2])]}
    return {}

func _intake_ready() -> bool:
    var captured: Dictionary = f.frame()
    var value: Dictionary = _native(captured)
    if value.is_empty() or int(value.sand_ingested)<=int(evidence.native_before.sand_ingested) or value.sand_cells.is_empty(): return false
    intake=value.duplicate(true)
    return true

func _identity() -> bool:
    var path: String = OS.get_environment("CYBERSAND_PACKAGE_MANIFEST")
    if not f.expect(not path.is_empty() and FileAccess.file_exists(path),"exact packaged manifest is provided"): return false
    var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not f.expect(manifest is Dictionary and manifest.get("source_commit")==EXPECTED_SOURCE and manifest.get("source_tree")==EXPECTED_TREE,
        "package retains the exact qualified application and tree"): return false
    var root_path: String = path.get_base_dir()
    var native: Dictionary = manifest.native
    var rapier: Dictionary = manifest.rapier
    var engine_path: String = OS.get_executable_path()
    var script_path: String = get_script().resource_path
    evidence.identity={"manifest_path":path,"manifest_sha256":FileAccess.get_sha256(path),
        "source_commit":manifest.source_commit,"source_tree":manifest.source_tree,"engine_path":engine_path,
        "engine_sha256":FileAccess.get_sha256(engine_path),"native_sha256":FileAccess.get_sha256(root_path.path_join(native.path)),
        "rapier_sha256":FileAccess.get_sha256(root_path.path_join(rapier.path)),
        "observer_path":script_path,"observer_sha256":FileAccess.get_sha256(script_path),
        "platform":OS.get_name(),"display_driver":DisplayServer.get_name(),"process_id":OS.get_process_id()}
    return f.expect(evidence.identity.native_sha256==native.sha256 and evidence.identity.rapier_sha256==rapier.sha256 \
        and evidence.identity.engine_sha256==manifest.files_sha256.get(engine_path.get_file(),"") \
        and str(evidence.identity.observer_sha256).length()==64,"actual packaged engine/native/Rapier and external observer identities are retained")

func _run() -> void:
    f=Fixture.new(self)
    if not f.expect(nonce.length()>=16 and not output.is_empty() and not OS.get_environment("CYBERSAND_TEST_ARTIFACT_DIR").is_empty(),
        "external witness has unique nonce, original receipt and raw output directory") or not f.expect(OS.get_environment("CYBERSAND_SOURCE_REVISION")==EXPECTED_SOURCE,
        "execution names the frozen candidate") or not _identity():
        await _finish(); return
    process_frame.connect(f._observe_callback)
    set_meta("cybersand_feature","shared_workbench")
    f.host=load("res://main.tscn").instantiate()
    root.add_child(f.host)
    if not await f.until(f.installed,"ordinary Workbench installed",60000): await _finish(); return
    f.bench=f.host.shared_workbench
    var recipe: Dictionary = Setup.fresh(PackedInt32Array(f.bench.applied.liquid_policy),Vector2i(512,512))
    recipe.brush=2
    recipe.edits=[[0,464,512,48,WALL],[0,0,3,512,WALL],[509,0,3,512,WALL],
        [240,440,3,6,WOOD],[246,440,3,6,WOOD],[240,446,9,3,WOOD],[243,449,3,15,WALL]]
    var error: String = Setup.write_named(LABEL,recipe)
    if not f.expect(error.is_empty(),"bounded external authored input uses the ordinary validated named-file format: "+error):
        await _finish(); return
    evidence.authored_input={"label":LABEL,"path":ProjectSettings.globalize_path(Setup._path(LABEL)),
        "sha256":FileAccess.get_sha256(Setup._path(LABEL)),"setup":recipe.duplicate(true),
        "scope":"external authored starting fixture; mounted Load commits it through the ordinary World owner"}
    var old_generation: int = int(f.host.latest_snapshot.render_world_generation)
    f.bench._name.text=LABEL
    if not _press("Load start") or not await f.until(func(): return f.installed() and int(f.host.latest_snapshot.render_world_generation)>old_generation \
        and Setup.extent_of(f.bench.applied)==Vector2i(512,512),"mounted Load installs the authored native pocket",60000):
        await _finish(); return
    if not f.expect(f.bench.applied==Setup.read_named(LABEL).get("setup",{}),"ordinary Load retains every authored starting field"):
        await _finish(); return
    f.bench._camera.select(2)
    f.bench._camera.item_selected.emit(2)
    if not _play() or not await f.until(func(): return f.runtime()!=null and f.diagnostics().get("attached",false),
        "actual native World and ordinary shared Rapier attach",60000) or not await _pause():
        await _finish(); return
    if not await f.until(func(): return f.whole_canvas_coherent(),"overview uploads the whole supported pocket",60000):
        await _finish(); return
    evidence.supported_inventory=await f.validate_quantity_ledger()
    if not f.expect(f.body_count()==0 and int(evidence.supported_inventory.total_material_counts[WOOD])==63 \
        and int(evidence.supported_inventory.total_material_counts[SAND])==0,
        "the63Wood U remains boundary-supported with no material body or Sand"):
        await _finish(); return
    var erase: Array[Vector2i] = []
    for y: int in range(449,464):
        for x: int in range(243,246): erase.append(Vector2i(x,y))
    if not await _stroke(erase,true,"remove45pedestalWallcells") or not _play():
        await _finish(); return
    if not await f.until(func(): return f.body_count()==1,"support removal naturally detaches exactly one actual body",60000):
        await _finish(); return
    owner=int(_shard(f.frame()).get("id",0))
    evidence.detached=_physics()
    if not f.expect(owner>0 and not evidence.detached.is_empty(),"detached native owner has an actual Rapier RID"):
        await _finish(); return
    if not await f.until(func():
        var actual: Dictionary = _physics()
        return not actual.is_empty() and bool(actual.sleeping) and not bool(actual.paused) \
            and f.tick()>=int(evidence.detached.native_tick)+8 and float(actual.y)>float(evidence.detached.y)+1.0 \
            and Vector2(float(actual.vx),float(actual.vy)).length()<0.05 \
            and absf(float(actual.angular_velocity))<0.01 and absf(float(actual.rotation))<0.05,
        "unforced actual Rapier fall reaches a naturally sleeping upright pocket",180000):
        await _finish(); return
    evidence.natural_rest=_physics()
    if not await _pause(): await _finish(); return
    evidence.before_inventory=await f.validate_quantity_ledger()
    evidence.native_before=_native(f.frame())
    evidence.physical_before=_physics()
    evidence.pocket=_pocket()
    if not f.expect(not evidence.pocket.is_empty() and int(evidence.native_before.wood_cells)==63 \
        and int(evidence.native_before.cargo_cells)==0 and int(evidence.native_before.sand_ingested)==0 \
        and absf(float(evidence.physical_before.mass)-63.0)<0.001,
        "naturally resting actual body contains63structuralWood and the documented open three-cell aperture"):
        await _finish(); return
    var drop := Vector2i(int(evidence.pocket.drop[0]),int(evidence.pocket.drop[1]))
    var pixels: PackedByteArray = f.host.image.get_data()
    if not f.expect(Rect2i(Vector2i.ZERO,Vector2i(512,512)).has_point(drop) \
        and int(pixels[(drop.y*512+drop.x)*2])==0 and f.runtime().visible_target(drop).is_empty(),
        "ordinary Sand click is in actual empty World six cells above the observed pocket"):
        await _finish(); return
    var sand: Array[Vector2i] = [drop]
    if not await _stroke(sand,false,"paintoneSandcell"):
        await _finish(); return
    evidence.painted_inventory=await f.validate_quantity_ledger()
    evidence.native_painted=_native(f.frame())
    evidence.physical_painted=_physics()
    if not f.expect(int(evidence.painted_inventory.raw_world_material_counts[SAND])==1 \
        and int(evidence.painted_inventory.total_material_counts[SAND])==1 \
        and evidence.native_painted.sand_cells.is_empty() \
        and evidence.native_painted.frame_tick==evidence.native_before.frame_tick,
        "one mounted Sand click credits exactly one static grain without clock or owned-inventory change"):
        await _finish(); return
    if not _play() or not await f.until(_intake_ready,"ordinary falling Sand enters native cargo through its real aperture",60000):
        await _finish(); return
    evidence.intake_native=intake
    if not await _pause(): await _finish(); return
    evidence.after_inventory=await f.validate_quantity_ledger()
    evidence.native_after=_native(f.frame())
    evidence.physical_after=_physics()
    var after: Dictionary = evidence.native_after
    var body: Dictionary = evidence.physical_after
    f.expect(after.id==evidence.native_before.id and after.generation==evidence.native_before.generation \
        and after.body_generation==evidence.native_before.body_generation \
        and body.rid==evidence.physical_before.rid and body.owner==owner,
        "Sand transfer preserves the exact native owner/incarnation and actual physical RID")
    f.expect(int(after.sand_ingested)-int(evidence.native_before.sand_ingested)==1 \
        and after.sand_cells.size()==1 and int(after.sand_cells[0].role)==CARGO_ROLE \
        and int(after.cargo_cells)==1 and int(after.wood_cells)==63,
        "the exact native ingress counter and actual Cargo state prove one lodged grain")
    f.expect(int(evidence.after_inventory.raw_world_material_counts[SAND])==0 \
        and int(evidence.after_inventory.total_material_counts[SAND])==1,
        "World debit and owned Sand credit close without duplication or disappearance")
    f.expect(int(after.geometry_revision)>int(evidence.native_before.geometry_revision) \
        and int(after.geometry_revision)==int(after.applied_physics_revision) \
        and int(after.geometry_revision)==int(body.geometry_revision) and not after.geometry_pending \
        and absf(float(after.mass)-64.0)<0.001 and absf(float(body.mass)-64.0)<0.001,
        "real geometry acknowledgement installs native and actual Rapier mass63plusoneCargo")
    var mismatches: Array = []
    for material: int in range(1,256):
        var original: int = int(evidence.supported_inventory.total_material_counts[material])
        var before: int = int(evidence.before_inventory.total_material_counts[material])
        var painted: int = int(evidence.painted_inventory.total_material_counts[material])
        var final: int = int(evidence.after_inventory.total_material_counts[material])
        if before!=original-(45 if material==WALL else 0) or painted!=before+(1 if material==SAND else 0) or final!=painted:
            mismatches.append({"material":material,"supported":original,"before":before,"painted":painted,"after":final})
    evidence.census_mismatches=mismatches
    f.expect(mismatches.is_empty(),"all255nonempty materials reconcile only45authoredWall erasures and oneSand credit")
    f.validate_physics()
    await _finish()

func _finish() -> void:
    if f!=null:
        f.validate_display()
        evidence.display_coherence=f.display_witness()
        evidence.inventory_witnesses=f.inventory_witnesses
        if f.runtime()!=null and not f.frame().is_empty():
            evidence.final_native=_native(f.frame())
            evidence.final_diagnostics=f.diagnostics()
        await f.close()
    var file: FileAccess = FileAccess.open(output,FileAccess.WRITE) if not output.is_empty() else null
    if f!=null: f.expect(file!=null,"original external Sand receipt can be retained")
    var result: Dictionary = {"schema":SCHEMA,"nonce":nonce,"source_commit":OS.get_environment("CYBERSAND_SOURCE_REVISION"),
        "checks":f.checks,"failures":f.failures,"evidence":evidence,
        "scope":"NEW ordinary mounted authored-load/erase/Sand-draw witness with actual unforced Rapier rest, native cargo transfer, real geometry mass credit and raw all-material census; physical owner presentation remains HOLD"}
    var text: String = JSON.stringify(result)
    if file!=null:
        file.store_string(text+"\n")
        file.close()
    print(text)
    quit(0 if f.failures.is_empty() else 1)
