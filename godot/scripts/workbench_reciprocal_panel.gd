extends PanelContainer

# Lazy experimental dock. Generation runs in one bounded child process. Only
# Shared Workbench's acknowledged native transaction can install its output.
const Protocol = preload("res://scripts/workbench_reciprocal_protocol.gd")
const History = preload("res://scripts/workbench_paint_editor_history.gd")
const Setup = preload("res://scripts/workbench_setup.gd")
const TIMEOUT_MSEC := 30000
const LAYERS := ["Materials","Owners","Parts","Revisions","Changed cells","Joints","Clearance","Shared zone","Unresolved","Sockets / receptors","Interface band"]
const FINAL_ONLY_LAYERS := ["Revisions","Joints","Clearance","Unresolved"]
const CONTROL_SPECS := [["Complexity / variation","variation",0.5],["Branching","branching",0.5],
	["Irregularity","irregularity",0.2],["Environment affinity","environment_affinity",0.5],
	["Cohesion","cohesion",0.75],["Decoration","clutter",0.0],["Destruction","destruction",0.0]]
var bench: Control
var controls: Dictionary = {}
var gentek_controls: Dictionary = {}
var phase := "idle"
var status := "Paint approximate activation territory on the canvas, then Generate."
var activation: Array[Vector2i] = []
var protected_points: Dictionary = {}
var territory := Rect2i()
var document: Dictionary = {}
var prepared: Dictionary = {}
var proposal: Dictionary = {}
# Cancellation/control edits may clear the displayed proposal, but cannot turn
# inspected saved evidence into transaction authority. Only fresh native decode
# after a successful current-source child clears this latch.
var _historical_only := false
var last_receipt: Dictionary = {}
var completed_applies := 0
var completed_undos := 0
var completed_generations := 0
var _capture_token := 0
var _capture_action := ""
var _capture: Dictionary = {}
var _source_fence: Dictionary = {}
var _source_history := ""
var _thread: Thread
var _thread_kind := ""
var _thread_cancelled := false
var _pid := -1
var _child_exit_code := -1
var _started := 0
var _serial := 0
var _job_dir := ""
var _runtime: Dictionary = {}
var _pending_patch: Dictionary = {}
var _pending_setup: Dictionary = {}
var _pending_before_edits: Array = []
var _pending_action := ""
var _undo: Dictionary = {}
var _accepted: Dictionary = {}
var _accepted_path := ""
var _dragging := false
var _points: Array[Vector2i] = []
var _mask_key: Array = []
var _mask_preview: Dictionary = {}
var _status := Label.new()
var _preview := TextureRect.new()
var _inspector := TextEdit.new()
var _round := OptionButton.new()
var _layer := OptionButton.new()
var _tool := OptionButton.new()
var _paint := CheckButton.new()
var _generate: Button
var _apply: Button
var _undo_button: Button
var _overlay: Control

func mount(workbench: Control) -> void:
	bench = workbench
	name = "ReciprocalAssembly"
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	add_child(margin)
	var column := VBoxContainer.new();margin.add_child(column)
	var title := HBoxContainer.new();column.add_child(title)
	_label(title,"Experimental · FRAMEWEAVER × MOSAIC · Draft/HOLD").size_flags_horizontal = SIZE_EXPAND_FILL
	_button(title,"Inspect saved evidence",inspect_saved_evidence)
	_button(title,"Close",close_panel)
	var body := HBoxContainer.new();column.add_child(body)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(490,300)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	var fields := VBoxContainer.new();fields.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(fields)
	var row := _row(fields)
	_label(row,"Expression")
	var profile := OptionButton.new()
	for text: String in ["Industrial","Viaduct-like","Irregular megastructure"]: profile.add_item(text)
	row.add_child(profile);controls.profile=profile
	profile.item_selected.connect(_select_expression)
	row = _row(fields)
	_spin(row,"Seed","seed",0,2147483647,1,605)
	_spin(row,"Rounds","rounds",0,4,1,2)
	row = _row(fields)
	_spin(row,"Width","width",64,256,8,192)
	_spin(row,"Height","height",64,128,8,112)
	_spin(row,"Interface reach","shared_extent",0,13,1,13)
	row = _row(fields)
	_label(row,"Ownership")
	var layout:=OptionButton.new()
	for text: String in ["FRAME left / MOSAIC right","FRAME top / MOSAIC bottom","FRAME centre / MOSAIC surround"]: layout.add_item(text)
	row.add_child(layout);controls.layout=layout
	layout.item_selected.connect(func(_index: int) -> void: invalidate("Ownership layout changed."))
	_spin(row,"Clear border","border",0,16,1,4)
	row = _row(fields)
	_label(row,"Orientation")
	var orientation := OptionButton.new()
	for text: String in ["Balanced","Horizontal","Vertical"]: orientation.add_item(text)
	row.add_child(orientation);controls.orientation=orientation
	orientation.item_selected.connect(func(_index: int) -> void: invalidate("Orientation preference changed."))
	var optional := CheckButton.new();optional.text="Optional negotiation";optional.button_pressed=true
	row.add_child(optional);controls.optional=optional
	optional.toggled.connect(func(_value: bool) -> void: invalidate("Optional negotiation changed."))
	row=_row(fields)
	var sharing:=CheckButton.new();sharing.text="Allow negotiated territory sharing";sharing.button_pressed=false
	row.add_child(sharing);controls.shared_ownership=sharing
	sharing.toggled.connect(func(_value: bool) -> void: invalidate("Territory sharing changed; interface hints retain their exact width."))
	row=_row(fields)
	var compact:=CheckButton.new();compact.text="Source-feasible terminal parts (SWARM-005)";compact.button_pressed=false
	compact.tooltip_text="Opt-in genuine source-time welded parts; cannot discharge existing foreign-required sockets."
	row.add_child(compact);controls.compact_native_termination=compact
	compact.toggled.connect(func(_value: bool) -> void: invalidate("SWARM-005 source-time feasibility changed; regenerate before Apply."))
	row=_row(fields)
	var supported:=CheckButton.new();supported.text="Source-bound MOSAIC receptors (SWARM-005)";supported.button_pressed=false
	supported.tooltip_text="Opt-in real backed native masonry receptors; final foreign joint and material path are still mandatory."
	row.add_child(supported);controls.supported_native_receptors=supported
	supported.toggled.connect(func(_value: bool) -> void: invalidate("SWARM-005 native receptor negotiation changed; regenerate before Apply."))
	row=_row(fields)
	var recovery:=CheckButton.new();recovery.text="Bounded reciprocal recovery (SWARM-006)";recovery.button_pressed=false
	recovery.tooltip_text="Search finite native structural and receiver alternatives. Bids and reservations require genuine material-path proof before Apply."
	row.add_child(recovery);controls.negotiated_recovery=recovery
	recovery.toggled.connect(func(_value: bool) -> void: invalidate("SWARM-006 recovery changed; regenerate before Apply."))
	for spec: Array in CONTROL_SPECS:
		row=_row(fields);_spin(row,spec[0],spec[1],0,1,0.05,spec[2])
	for key: String in Protocol.EXPRESSION_DEFAULTS[0]: controls[key].set_value_no_signal(Protocol.EXPRESSION_DEFAULTS[0][key])
	_mount_gentek_controls(fields,"frame","FRAMEWEAVER")
	_mount_gentek_controls(fields,"mosaic","MOSAIC")
	row=_row(fields)
	_paint.text="Paint territory";_paint.button_pressed=true;row.add_child(_paint)
	for text: String in ["Activation stroke","Protect passage"]: _tool.add_item(text)
	row.add_child(_tool)
	_button(row,"Clear marks",clear_marks)
	var right := VBoxContainer.new();right.size_flags_horizontal=SIZE_EXPAND_FILL;body.add_child(right)
	row=_row(right)
	_generate=_button(row,"Generate",generate)
	_button(row,"New seed",func() -> void: controls.seed.value=int(controls.seed.value)+1;generate())
	_apply=_button(row,"Apply construction",apply_construction)
	_undo_button=_button(row,"Undo construction",undo_construction)
	_button(row,"Cancel",cancel)
	row=_row(right);_label(row,"Inspect")
	for text: String in LAYERS: _layer.add_item(text)
	row.add_child(_layer);_layer.item_selected.connect(func(_index: int) -> void: _render())
	row.add_child(_round)
	_round.item_selected.connect(func(_index: int) -> void: _render())
	_preview.custom_minimum_size=Vector2(384,176);_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_preview.texture_filter=TEXTURE_FILTER_NEAREST
	_preview.size_flags_horizontal=SIZE_EXPAND_FILL;_preview.size_flags_vertical=SIZE_EXPAND_FILL
	_preview.mouse_filter=MOUSE_FILTER_STOP;_preview.gui_input.connect(_inspect_cell);right.add_child(_preview)
	_inspector.editable=false;_inspector.custom_minimum_size=Vector2(0,76);_inspector.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	_inspector.text="Native cells, ownership, revisions and physical path witnesses appear after generation."
	right.add_child(_inspector)
	_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(_status)
	_overlay=preload("res://scripts/workbench_reciprocal_overlay.gd").new();_overlay.panel=self
	bench.host.world_view.add_child(_overlay)
	visibility_changed.connect(func() -> void:
		if not visible: cancel("Panel closed; provisional work cancelled."))
	_reset_preview()
	_refresh()

func _row(parent: Control) -> HFlowContainer:
	var value:=HFlowContainer.new();value.add_theme_constant_override("h_separation",6);parent.add_child(value);return value

func _label(parent: Control, text: String) -> Label:
	var value:=Label.new();value.text=text;parent.add_child(value);return value

func _button(parent: Control, text: String, action: Callable) -> Button:
	var value:=Button.new();value.text=text;value.focus_mode=FOCUS_NONE
	value.pressed.connect(func() -> void:
		bench._commit_field(get_viewport())
		action.call())
	parent.add_child(value);return value

func _spin(parent: Control, text: String, key: String, low: float, high: float, step: float, value: float) -> void:
	_label(parent,text)
	var spin:=SpinBox.new();spin.min_value=low;spin.max_value=high;spin.step=step;spin.value=value
	spin.custom_minimum_size.x=80;parent.add_child(spin);controls[key]=spin
	spin.value_changed.connect(func(_number: float) -> void: invalidate("Recipe changed."))
	spin.get_line_edit().text_changed.connect(func(_text: String) -> void: invalidate("Recipe text changed; Generate to use the edited value."))

func _mount_gentek_controls(parent: Control, gentek: String, title: String) -> void:
	var enabled:=CheckButton.new();enabled.text="Independent "+title+" controls";parent.add_child(enabled)
	var fields:=VBoxContainer.new();fields.hide();parent.add_child(fields)
	var values: Dictionary={}
	for spec: Array in CONTROL_SPECS:
		var row:=_row(fields);_label(row,spec[0])
		var spin:=SpinBox.new();spin.min_value=0;spin.max_value=1;spin.step=0.05;spin.value=controls[spec[1]].value
		spin.custom_minimum_size.x=80;row.add_child(spin);values[spec[1]]=spin
		spin.value_changed.connect(func(_value: float) -> void: invalidate(title+" controls changed."))
		spin.get_line_edit().text_changed.connect(func(_text: String) -> void: invalidate(title+" control text changed; regenerate before Apply."))
	gentek_controls[gentek]={"enabled":enabled,"fields":fields,"values":values,"initialized":false}
	enabled.toggled.connect(func(active: bool) -> void:
		if active and not gentek_controls[gentek].initialized:
			for key: String in Protocol.PARAMETERS: values[key].set_value_no_signal(controls[key].value)
			gentek_controls[gentek].initialized=true
		fields.visible=active
		invalidate(title+(" uses independent controls." if active else " follows the shared controls.")))

func busy() -> bool:
	return phase in ["capture","preparing","running","decoding","installing","acknowledging","cancelling"]

func _select_expression(index: int) -> void:
	for key: String in Protocol.EXPRESSION_DEFAULTS[index]: controls[key].set_value_no_signal(Protocol.EXPRESSION_DEFAULTS[index][key])
	invalidate("Expression changed; structural controls follow its authored preset.")

func _fence() -> Dictionary:
	var state: Dictionary=bench.host.simulation_worker.paint_state()
	return {"generation":int(state.get("generation",-1)),"revision":int(state.get("revision",-1)),
		"tick":int(state.get("tick",-1)),"authoring_generation":int(state.get("authoring_generation",-1))}

func _history() -> String:
	return JSON.stringify(bench.applied.edits).sha256_text()

func _say(message: String) -> bool:
	status=message;_refresh();return false

func _refresh() -> void:
	if _apply==null: return
	_status.text=status
	_apply.disabled=_read_only_evidence() or phase!="ready" or not document.get("can_apply",false)
	_generate.disabled=busy()
	_undo_button.disabled=_read_only_evidence() or busy() or _undo.is_empty()
	if _overlay!=null: _overlay.queue_redraw()

func _read_only_evidence() -> bool:
	return _historical_only or proposal.get("historical_only",false)

func open_panel() -> void:
	show();_paint.button_pressed=true;_refresh()

func inspect_saved_evidence() -> void:
	if busy() or bench.busy(): _say("Wait for the active native transaction.");return
	invalidate("Loading bounded evidence from the named saved map…")
	var path:=Setup._path(bench._name.text)
	if path.is_empty(): _say("Choose the saved map name first.");return
	_historical_only=true
	_thread=Thread.new();_thread_kind="load_saved";_started=Time.get_ticks_msec()
	var error:=_thread.start(func()->Dictionary:return Protocol.load_saved(path))
	if error!=OK: _thread=null;phase="idle";_say("Could not read the saved evidence.");return
	phase="decoding";_refresh()

func close_panel() -> void:
	cancel("Panel closed; provisional work cancelled.");hide()

func clear_marks() -> void:
	activation.clear();protected_points.clear();territory=Rect2i();invalidate("Activation and protected-passage marks cleared.")

func invalidate(reason: String = "Preview changed.") -> void:
	if phase in ["installing","acknowledging"]: return
	cancel(reason)
	_reset_preview()
	_update_territory();_refresh()

func _reset_preview() -> void:
	# Replace references: a retiring decoder may still own its captured request.
	proposal={};document={};prepared={};_preview.texture=null
	_round.clear();_round.add_item("Final composition");_round.select(0);_round.disabled=true
	_layer.select(0);_layer.disabled=true
	for layer: String in FINAL_ONLY_LAYERS: _layer.set_item_disabled(LAYERS.find(layer),false)
	_inspector.text="Generate or inspect saved evidence to see native cells, ownership, revisions and physical path witnesses."

func _update_territory() -> void:
	if activation.is_empty() or bench.applied.is_empty(): return
	var centre:=Vector2.ZERO
	for point: Vector2i in activation: centre+=Vector2(point)
	centre/=activation.size()
	var size:=Vector2i(int(controls.width.value),int(controls.height.value))
	var extent:=Setup.extent_of(bench.applied)
	territory=Rect2i((Vector2i(centre)-size/2).clamp(Vector2i.ZERO,extent-size),size)

func world_input(event: InputEvent) -> bool:
	if not visible or not _paint.button_pressed: return false
	if busy():
		# Territory input remains owned by this dock while capture/generation
		# runs. Falling through would paint the live World with PAINT instead.
		return (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) \
			or (event is InputEventMouseMotion and (event.button_mask&MOUSE_BUTTON_MASK_LEFT)!=0)
	if event is InputEventMouseButton:
		if event.button_index!=MOUSE_BUTTON_LEFT: return false
		if event.pressed:
			# Retire the proposal before the first mutable activation/protected
			# mark, including a gesture later released outside the canvas.
			invalidate("Territory marks changed; regenerate before Apply.")
			_dragging=true
			_points.clear();bench.cancel_stroke()
		else:
			_finish_gesture()
			return true
	elif not event is InputEventMouseMotion or not _dragging: return false
	var local: Vector2i=bench.host.view_pixel_from_local_point(event.position)
	if local.x<0: return true
	var point:=Vector2i(bench.host.camera_origin.floor())+local
	if _tool.selected==0:
		if _points.size()<1024 and (_points.is_empty() or _points.back().distance_squared_to(point)>=4): _points.append(point)
	else:
		for y: int in range(point.y-3,point.y+4):
			for x: int in range(point.x-3,point.x+4):
				if protected_points.size()<32768: protected_points[Vector2i(x,y)]=true
	_overlay.queue_redraw()
	return true

func _finish_gesture() -> void:
	if not _dragging: return
	_dragging=false
	if _tool.selected==0 and not _points.is_empty():
		activation.clear()
		for i: int in mini(16,_points.size()):
			activation.append(_points[int(float(i)*(_points.size()-1)/maxi(1,mini(16,_points.size())-1))])
	_points.clear()
	invalidate("Territory marks changed; Generate to inspect native proposals.")

func _input(event: InputEvent) -> void:
	# A canvas gesture owns its release even when the pointer leaves that
	# Control. Do not consume the event; the clicked UI keeps ordinary routing.
	if not _dragging: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		cancel("Territory gesture cancelled; regenerate before Apply.")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_gesture()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and _dragging:
		cancel("Territory gesture cancelled when the application lost focus.")

func _recipe() -> Dictionary:
	_update_territory()
	var points: Array[Vector2i]=[]
	for point: Vector2i in activation: points.append((point-territory.position).clamp(Vector2i.ZERO,territory.size-Vector2i.ONE))
	var parameters: Dictionary={}
	for key: String in Protocol.PARAMETERS: parameters[key]=float(controls[key].value)
	var recipe: Dictionary={"origin":territory.position,"size":territory.size,"seed":int(controls.seed.value),
		"rounds":int(controls.rounds.value),"shared_extent":int(controls.shared_extent.value),
		"orientation":controls.orientation.selected-1,"profile":Protocol.PROFILES[controls.profile.selected],
		"layout":Protocol.LAYOUTS[controls.layout.selected],"border":int(controls.border.value),
		"optional":controls.optional.button_pressed,"shared_ownership":controls.shared_ownership.button_pressed,
		"compact_native_termination":controls.compact_native_termination.button_pressed,
		"supported_native_receptors":controls.supported_native_receptors.button_pressed,
		"negotiated_recovery":controls.negotiated_recovery.button_pressed,
		"parameters":parameters,"activation":points,
		"protected":protected_points.duplicate()}
	var profiles: Dictionary={}
	for gentek: String in ["frame","mosaic"]:
		if not gentek_controls[gentek].enabled.button_pressed: continue
		var values: Dictionary={}
		for key: String in Protocol.PARAMETERS: values[key]=float(gentek_controls[gentek].values[key].value)
		profiles[gentek]=values
	if not profiles.is_empty(): recipe["gentek_parameters"]=profiles
	return recipe

func ownership_preview() -> Dictionary:
	var key: Array=[territory.size,controls.layout.selected,int(controls.border.value),int(controls.shared_extent.value),controls.shared_ownership.button_pressed]
	if key==_mask_key: return _mask_preview
	_mask_key=key
	_mask_preview=Protocol.ownership_masks(territory.size,Protocol.LAYOUTS[key[1]],key[2],key[3])
	var runs: Array[Rect2i]=[]
	if _mask_preview.ok:
		for y: int in territory.size.y:
			var x:=0
			while x<territory.size.x:
				if not _mask_preview.shared[y*territory.size.x+x]: x+=1;continue
				var begin:=x
				while x<territory.size.x and _mask_preview.shared[y*territory.size.x+x]: x+=1
				runs.append(Rect2i(begin,y,x-begin,1))
	_mask_preview["interface_runs"]=runs
	_mask_preview["shared_runs"]=runs if key[4] else []
	return _mask_preview

func _runtime_info() -> Dictionary:
	var path:=OS.get_environment("CYBERSAND_SWARM004_CLI")
	if not path.is_empty():
		return _checked_runtime(path,{"source":OS.get_environment("CYBERSAND_SWARM004_SOURCE"),
			"sha256":OS.get_environment("CYBERSAND_SWARM004_SHA256")},OS.get_name())
	return _packaged_runtime_info("res://tools",OS.get_name())

static func _packaged_runtime_info(directory: String, platform: String) -> Dictionary:
	var path:=ProjectSettings.globalize_path(directory.path_join("gentek_reciprocal"+(".exe" if platform=="Windows" else "")))
	var manifest_path:=directory.path_join("swarm004-runtime.%s.json" % platform.to_lower())
	# A present but stale/malformed platform binding must fail closed. Only
	# older packages without that binding may use the original manifest.
	if not FileAccess.file_exists(manifest_path): manifest_path=directory.path_join("swarm004-runtime.json")
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) if FileAccess.file_exists(manifest_path) else null
	return _checked_runtime(path,manifest,platform)

static func _checked_runtime(path: String, manifest: Variant, platform: String) -> Dictionary:
	if not manifest is Dictionary or str(manifest.get("source","")).is_empty() \
		or str(manifest.get("sha256","")).length()!=64 or not FileAccess.file_exists(path):
		return Protocol.fail("The source-matched native reciprocal executable and manifest are not installed.")
	if manifest.has("platform") and manifest.platform!=platform.to_lower():
		return Protocol.fail("Native reciprocal manifest belongs to a different platform.")
	if manifest.has("native_definition_sha256") and manifest.native_definition_sha256!=Protocol.NATIVE_DEFINITION:
		return Protocol.fail("Native reciprocal manifest belongs to a different qualified definition.")
	if FileAccess.get_sha256(path)!=manifest.sha256:
		return Protocol.fail("Native reciprocal executable differs from its packaged source manifest.")
	return {"ok":true,"path":path,"source":str(manifest.source),"sha256":str(manifest.sha256)}

func generate() -> bool:
	bench._commit_field(get_viewport())
	if busy() or bench.busy(): return _say("Wait for the active native transaction.")
	if activation.is_empty(): return _say("Paint an activation stroke on the native canvas first.")
	invalidate("Checking the native generator source…")
	_runtime=_runtime_info()
	if not _runtime.ok: return _say(_runtime.error)
	return _request_capture("generate")

func _request_capture(action: String) -> bool:
	if bench.applied.is_empty() or not bench.host.paused: return _say("Pause the native World before generating or undoing construction.")
	var reason: String = bench.authored_world_change_block_reason()
	if not reason.is_empty(): return _say(reason)
	var state: Dictionary=bench.host.simulation_worker.paint_state()
	for key: String in ["busy","art_busy","legacy_busy","transition_busy","flatten_busy"]:
		if state.get(key,false): return _say("Wait for all native edits and acknowledgements.")
	if bench.paint_editor.recovery_required(): return _say("Resolve the partial paint edit before construction.")
	if bench._stream.button_pressed: return _say("Stop the powder stream before construction.")
	_source_fence=_fence();_source_history=_history()
	var admitted: Dictionary=bench.host.simulation_worker.material_capture_request(int(state.generation),2048*2048*2)
	if not admitted.get("ok",false): return _say(str(admitted.get("reason","Native capture refused.")))
	_capture_token=int(admitted.token);_capture_action=action;_started=Time.get_ticks_msec();phase="capture"
	status="Capturing paused native materials for "+action+"…";_refresh();return true

func _poll_capture() -> void:
	var value: Dictionary=bench.host.simulation_worker.material_capture_poll(_capture_token)
	if value.is_empty(): return
	var token:=_capture_token;_capture_token=0
	var released: Dictionary=bench.host.simulation_worker.material_capture_finish(token,false)
	if not value.get("ok",false) or not released.get("ok",false) or _fence()!=_source_fence or _history()!=_source_history:
		phase="idle";_say("Native source changed during capture; regenerate.");return
	_capture=value
	if _capture_action=="undo": _submit_inverse();return
	_thread=Thread.new();_thread_kind="prepare";_thread_cancelled=false
	var recipe:=_recipe()
	var error:=_thread.start(func() -> Dictionary: return Protocol.prepare(recipe,value))
	if error!=OK: _thread=null;phase="idle";_say("Could not start bounded request preparation.");return
	phase="preparing";_refresh()

func _launch(preparation: Dictionary) -> void:
	if not preparation.ok: phase="idle";_say(preparation.error);return
	prepared=preparation
	_serial+=1
	_job_dir=ProjectSettings.globalize_path("user://swarm004/job-%d-%d" % [OS.get_process_id(),_serial])
	if DirAccess.dir_exists_absolute(_job_dir):
		_job_dir="";phase="idle";_say("A previous job folder exists; Generate again to use a fresh request identity.");return
	if DirAccess.make_dir_recursive_absolute(_job_dir)!=OK: phase="idle";_say("Could not create bounded native request files.");return
	var input:=FileAccess.open(_job_dir+"/request.txt",FileAccess.WRITE)
	if input==null: phase="idle";_say("Could not write native request.");return
	input.store_string(prepared.text);input.close()
	_pid=OS.create_process(_runtime.path,PackedStringArray(["request",_job_dir+"/request.txt",_job_dir+"/result.json",_runtime.source]),false)
	if _pid<=0: phase="idle";_say("Native reciprocal process could not start.");_cleanup_job();return
	phase="running";status="Native FRAMEWEAVER × MOSAIC proposals running · finite rounds and budgets…";_refresh()

func _poll_process() -> void:
	if OS.is_process_running(_pid): return
	var exit_code:=OS.get_process_exit_code(_pid);_pid=-1;_child_exit_code=exit_code
	if not FileAccess.file_exists(_job_dir+"/result.json"):
		phase="idle";_say("Native request ended without completed evidence (exit %d)." % exit_code);_cleanup_job();return
	_thread=Thread.new();_thread_kind="decode";_thread_cancelled=false
	var path:=_job_dir+"/result.json";var request:=prepared;var source:String=_runtime.source
	var error:=_thread.start(func() -> Dictionary: return Protocol.decode(path,request,source))
	if error!=OK: _thread=null;phase="idle";_say("Could not start bounded evidence validation.");return
	phase="decoding";status="Validating native cells, ownership and proposal rounds…";_refresh()

func _poll_thread() -> void:
	if _thread==null or _thread.is_alive(): return
	var result: Dictionary=_thread.wait_to_finish();_thread=null
	if _thread_cancelled:
		_thread_cancelled=false;phase="idle";_cleanup_job();_refresh();return
	if _thread_kind=="prepare": _launch(result);return
	if not result.ok:
		phase="idle";_reset_preview()
		if result.get("diagnostic_refusal",false) and _thread_kind=="decode" and not _job_dir.is_empty():
			# Keep the exact rejected request and response as evidence. No proposal,
			# material preview, acceptance receipt or native World action is created.
			var retained:=_job_dir
			_job_dir=""
			_inspector.text=result.error+"\nRaw native request/response: "+retained+"\nResponse SHA-256: "+str(result.response_sha256)
			_say(result.error+" Evidence retained: "+retained)
		else:
			_say(result.error);_cleanup_job()
		return
	if _thread_kind=="load_saved":
		if not result.get("historical_only",false):
			phase="idle";_reset_preview();_say("Saved evidence has no read-only inspection authority.");return
		proposal=result;document=result.result;prepared=result.prepared;phase="historical"
		_runtime={"source":result.receipt.native_source,"sha256":result.receipt.cli_sha256}
		_populate_rounds();_render();status="Saved construction evidence · historical receipt · Apply requires a fresh native generation.";_refresh();return
	if result.get("historical_only",false):
		phase="idle";_reset_preview();_say("Historical inspection cannot replace fresh native generation.");_cleanup_job();return
	if _fence()!=_source_fence or _history()!=_source_history:
		phase="idle";_reset_preview();_say("Native source changed while generating; the preview is retired.");_cleanup_job();return
	if _child_exit_code!=0 and result.result.get("can_apply",false):
		phase="idle";_reset_preview();_say("Failed native execution cannot authorize an Apply.");_cleanup_job();return
	if _child_exit_code==0: _historical_only=false
	proposal=result;document=result.result;phase="ready";completed_generations+=1
	_populate_rounds()
	_render()
	status=("Native proposal accepted for Apply" if document.can_apply else "Native proposal blocked · "+str(document.reason))
	status+=" · %d material cells · %d joint witnesses · %s" % [proposal.cells.size()/3,document.joints.size(),document.stop_reason]
	_refresh()

func _populate_rounds() -> void:
	# OptionButton uses -1 to request an automatic ID. Use the selected INDEX
	# instead: index 0 is the final composition, indices 1..N are proposals.
	_round.clear();_round.add_item("Final composition")
	for i: int in document.rounds.size(): _round.add_item("Proposal round %d" % int(document.rounds[i].number))
	_round.select(0)
	_round.disabled=false;_layer.disabled=false

func _selected_proposal_round_index() -> int:
	# Native raster/inspector use -1 for final; provisional round zero is UI item one.
	return _round.selected - 1

func _render() -> void:
	if document.is_empty() or prepared.is_empty(): return
	var round_index:=_selected_proposal_round_index()
	for layer: String in FINAL_ONLY_LAYERS: _layer.set_item_disabled(LAYERS.find(layer),round_index>=0)
	if _layer.is_item_disabled(_layer.selected): _layer.select(0)
	var bytes:=Protocol.raster(document,prepared,round_index,LAYERS[_layer.selected])
	var size:Vector2i=prepared.recipe.size
	_preview.texture=ImageTexture.create_from_image(Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,bytes))
	var rows:=PackedStringArray(["Native status: %s · %s" % [document.status,document.reason],
		"Source %s · proposal SHA-256 %s" % [_runtime.get("source",""),proposal.get("proposal_sha256","")]])
	if _layer.selected==LAYERS.find("Sockets / receptors"):
		rows.append("Red: required · gold: optional · cyan: locally terminable. Short white marks show facing. These are native offers/contracts, not additional joint certificates.")
	if not prepared.recipe.get("shared_ownership",true):
		rows.append("Fixed ownership: interface hints remain active; neither Gentek may claim the other's territory. Shared zone is empty.")
	if round_index>=0:
		var shown: Dictionary=document.rounds[round_index]
		rows.append("Raw native proposal · accepted FRAME %s / MOSAIC %s · magenta ownership means competing claims." % [shown.frame_accepted,shown.mosaic_accepted])
		rows.append("Accepted revision history, clearances, joint paths and unresolved obligations belong to Final composition.")
	for record: Dictionary in document.rounds:
		rows.append("Round %d · footprint FRAME %d / MOSAIC %d · material IDs %d / %d · work %d / %d · %s" % [
			record.number,record.get("frame_footprint_changed",0),record.get("mosaic_footprint_changed",0),
			record.frame_changed,record.mosaic_changed,record.frame_work,record.mosaic_work,record.reason])
	var damage: Variant=document.get("damage_derivative")
	if damage is Dictionary:
		rows.append("Separate destruction phase · footprint FRAME %d / MOSAIC %d · material IDs %d / %d · work %d · %s" % [
			damage.get("frame_footprint_changed",0),damage.get("mosaic_footprint_changed",0),damage.get("frame_changed",0),
			damage.get("mosaic_changed",0),damage.get("work",0),damage.get("reason","")])
	if 13.0 in document.cells or 13 in document.cells:
		rows.append("Stone keeps its native powder behavior. Solver acceptance does not certify physical stability.")
	if prepared.recipe.get("negotiated_recovery",false):
		rows.append("SWARM-006 recovery · %s · Apply %s. Offers and reservations require qualified native foreign joints." % [document.stop_reason,"authorized" if document.can_apply else "blocked"])
		var metrics: Dictionary=document.get("metrics",{})
		rows.append("Charged native work · FRAME %s / MOSAIC %s / categorical %s / coordinator %s" % [
			metrics.get("frame_work",0),metrics.get("mosaic_work",0),metrics.get("solver_work",0),metrics.get("shared_work",0)])
		var detail_count:=0
		for record: Dictionary in document.rounds:
			var attempts: Array=record.get("recovery_attempts",[])
			rows.append("Round %s recovery · %d candidate attempts · %d native receptor receipts · frontier exhausted %s" % [
				record.number,attempts.size(),record.get("mosaic_recovery_receipts",[]).size(),record.get("recovery_frontier_exhausted",false)])
			for attempt: Dictionary in attempts:
				if detail_count>=128: break
				rows.append("Native alternative · "+JSON.stringify(attempt).left(1200));detail_count+=1
		if detail_count>=128: rows.append("Additional alternative receipts remain in the retained native evidence.")
	for obligation: Dictionary in document.obligations:
		if obligation.get("state")=="STILL_REQUIRED": rows.append("Required socket %s · %s" % [obligation.connector,obligation.reason])
	_inspector.text="\n".join(rows)

func _inspect_cell(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed \
		or document.is_empty() or prepared.is_empty() or _preview.texture==null: return
	var size:Vector2i=prepared.recipe.size
	var scale:=minf(_preview.size.x/size.x,_preview.size.y/size.y)
	if scale<=0: return
	var local:Vector2=(event.position-(_preview.size-Vector2(size)*scale)/2)/scale
	# Integer conversion truncates negative fractions to zero. Reject the
	# letterbox before conversion so it cannot select a neighboring edge cell.
	if not Rect2(Vector2.ZERO,Vector2(size)).has_point(local): return
	var point:=Vector2i(local.floor())
	var at:=point.y*size.x+point.x
	var round_index:=_selected_proposal_round_index()
	if round_index>=0:
		var record: Dictionary=document.rounds[round_index]
		var frame: Dictionary=record.proposed_frame;var mosaic: Dictionary=record.proposed_mosaic
		_inspector.text="Provisional cell %s · round %d\nFRAME native material %d / part %d / accepted %s\nMOSAIC native material %d / part %d / accepted %s\nThese are independent native proposals; only Final composition can authorize Apply." % [
			point+prepared.recipe.origin,record.number,int(frame.cells[at]) if at<frame.cells.size() else 0,
			int(frame.provenance[at]) if at<frame.provenance.size() else 0,record.frame_accepted,
			int(mosaic.cells[at]) if at<mosaic.cells.size() else 0,int(mosaic.provenance[at]) if at<mosaic.provenance.size() else 0,record.mosaic_accepted]
		_inspector.text+="\n"+"\n".join(Protocol.inspect_sockets(document,round_index,point))
		return
	if document.cells.is_empty(): _inspector.text="No accepted final material architecture. "+str(document.reason);return
	var record:Array=document.ledger[at]
	var rule:String=document.rules[int(record[2])] if int(record[2])<document.rules.size() else "none"
	_inspector.text="Cell %s · native material ID %d\nOwner %s · structural part %d · rule %s\nFirst round %d · last round %d · accepted revision mask %d\n%s" % [
		point+prepared.recipe.origin,document.cells[at],document.owner_names[int(record[0])],record[1],rule,
		record[3],record[4],record[5],document.reason]
	_inspector.text+="\n"+"\n".join(Protocol.inspect_sockets(document,round_index,point))

func apply_construction() -> bool:
	bench._commit_field(get_viewport())
	if _read_only_evidence(): return _say("Saved evidence is read-only; Generate a fresh native proposal before Apply.")
	if phase!="ready" or not document.get("can_apply",false): return _say("Apply requires an accepted native composition with all mandatory obligations resolved.")
	if _fence()!=_source_fence or _history()!=_source_history: invalidate("Source changed; regenerate before Apply.");return false
	var staged:=History.prepare(bench.applied,proposal.cells,bench._generated_active,bench._material_baseline)
	if not staged.accepted: return _say(staged.error)
	_pending_before_edits=bench.applied.edits.duplicate(true)
	return _submit(staged.setup,_patch("build",proposal.cells,proposal.before),"build")

func _patch(operation: String, cells: PackedInt32Array, before: PackedInt32Array) -> Dictionary:
	return {"schema":1,"operation":operation,"native_generation":int(_capture.native_generation),
		"revision":int(_capture.revision),"tick":int(_capture.tick),"extent":_capture.extent,
		"cells":cells,"before":before,"protected":_undo.guards if operation=="remove" else prepared.guards,
		"proposal_sha256":_undo.proposal_sha256 if operation=="remove" else proposal.proposal_sha256}

func _submit(candidate: Dictionary, patch: Dictionary, action: String) -> bool:
	if _read_only_evidence(): return _say("Saved evidence cannot submit a native transaction; Generate first.")
	var reason: String = bench.authored_world_change_block_reason()
	if not reason.is_empty(): return _say(reason)
	# Controller cleanup must not clear a caller-owned staged history/patch.
	_pending_setup=candidate.duplicate(true);_pending_patch=patch.duplicate(true);_pending_action=action;phase="submitting"
	if not bench.apply(candidate,true,0,false,false,{},{},false,{},patch):
		phase="ready";_pending_patch.clear();_pending_setup.clear();return _say(bench.message)
	phase="installing";status="Preparing atomic native "+action+"; authored history awaits acknowledgement…";_refresh();return true

func attests(candidate: Dictionary, patch: Dictionary) -> bool:
	return not _read_only_evidence() and phase=="submitting" and candidate==_pending_setup and patch==_pending_patch

func native_installed(_candidate: Dictionary) -> void:
	if phase=="installing": phase="acknowledging"
	else:
		cancel("Native World replaced; previous preview and construction Undo retired.")
		_undo.clear();_accepted.clear();_reset_preview();_refresh()

func _acknowledge() -> void:
	if not bench.host.pending_microscenario_apply.is_empty(): return
	var receipt: Dictionary=bench.host.tower_context.get("liquid_construction_receipt",{}).get("workbench_authoring_patch",{})
	if receipt.get("proposal_sha256")!=_pending_patch.proposal_sha256 or receipt.get("operation")!=_pending_action \
		or int(receipt.get("changed_cells",-1))!=_pending_patch.before.size():
		phase="idle";_undo.clear();_say("Installed native acknowledgement does not match the proposed patch; inspect the owner receipt.");return
	last_receipt=receipt.duplicate(true)
	if _pending_action=="build":
		_undo={"cells":proposal.cells.duplicate(),"before_edits":_pending_before_edits.duplicate(true),
			"after_history":_history(),"fence":_fence(),"proposal_sha256":proposal.proposal_sha256,"guards":prepared.guards.duplicate()}
		_accepted={"schema":1,"proposal_sha256":proposal.proposal_sha256,"request_sha256":prepared.request_sha256,
			"native_source":_runtime.source,"cli_sha256":_runtime.sha256,"native_receipt":last_receipt.duplicate(true),
			"authoring_territory":{"layout":prepared.recipe.get("layout","left_right"),"border":prepared.recipe.get("border",0)},
			"status":"accepted_native_material_architecture","cell_count":proposal.cells.size()/3,"accepted_history_sha256":_history()}
		if not _accepted_path.is_empty(): DirAccess.remove_absolute(_accepted_path)
		_accepted_path=ProjectSettings.globalize_path("user://swarm004/accepted-%d.json" % OS.get_process_id())
		DirAccess.rename_absolute(_job_dir+"/result.json",_accepted_path)
		completed_applies+=1;status="Installed %d native cells atomically · Save start preserves this construction." % receipt.changed_cells
	else:
		_undo.clear();_accepted.clear();completed_undos+=1;status="Construction undone atomically; previous authored history restored."
		if not _accepted_path.is_empty(): DirAccess.remove_absolute(_accepted_path);_accepted_path=""
	_pending_patch.clear();_pending_setup.clear();_pending_before_edits.clear();_cleanup_job();phase="installed";_refresh()

func undo_construction() -> bool:
	if _read_only_evidence(): return _say("Saved evidence is read-only; it cannot authorize construction Undo.")
	if _undo.is_empty() or busy() or bench.busy(): return _say("There is no settled construction to undo.")
	if _fence()!=_undo.fence or _history()!=_undo.after_history:
		_undo.clear();return _say("Native simulation or authoring changed after Apply; construction Undo is retired.")
	return _request_capture("undo")

func _submit_inverse() -> void:
	if _undo.is_empty() or _history()!=_undo.after_history: phase="idle";_say("Construction Undo is stale.");return
	var cells:=PackedInt32Array();var before:=PackedInt32Array()
	for at: int in range(0,_undo.cells.size(),3):
		cells.append_array(PackedInt32Array([_undo.cells[at],_undo.cells[at+1],0]));before.append(_undo.cells[at+2])
	var candidate:Dictionary=bench.applied.duplicate(true);candidate.edits=_undo.before_edits.duplicate(true)
	_submit(candidate,_patch("remove",cells,before),"remove")

func save_evidence(label: String) -> String:
	if _accepted.is_empty(): return ""
	if _accepted.get("accepted_history_sha256")!=_history():
		return "Saved map is complete; its authoring history changed after construction, so the older construction receipt was not attached."
	var map_path:=Setup._path(label)
	if map_path.is_empty() or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(_accepted_path):
		return "Construction provenance could not be attached to the saved map."
	var evidence_path:=map_path+".swarm004-evidence.json"
	var error:=DirAccess.copy_absolute(_accepted_path,ProjectSettings.globalize_path(evidence_path+".partial"))
	if error!=OK: return "Saved map is complete; copying optional construction evidence failed."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(evidence_path+".partial"),ProjectSettings.globalize_path(evidence_path))!=OK:
		return "Saved map is complete; optional evidence publication failed."
	var record:=_accepted.duplicate(true);record["map_sha256"]=FileAccess.get_sha256(map_path)
	record["evidence_sha256"]=FileAccess.get_sha256(evidence_path);record["evidence_file"]=evidence_path.get_file()
	record["authority"]="Evidence only; the ordinary saved starting map owns native reconstruction."
	var file:=FileAccess.open(map_path+".swarm004.json.partial",FileAccess.WRITE)
	if file==null: return "Saved map is complete; optional provenance receipt could not be written."
	file.store_string(JSON.stringify(record,"\t"));file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(map_path+".swarm004.json.partial"),ProjectSettings.globalize_path(map_path+".swarm004.json"))!=OK:
		return "Saved map is complete; optional provenance receipt publication failed."
	return ""

func cancel(reason: String = "Provisional construction cancelled; native World unchanged.") -> void:
	_dragging=false
	_points.clear()
	if phase in ["installing","acknowledging"]:
		status="Native transaction already submitted; wait for acknowledgement, then Undo construction.";_refresh();return
	if _capture_token>0 and bench!=null:
		bench.host.simulation_worker.material_capture_cancel(_capture_token);_capture_token=0
	_terminate_child()
	if _thread!=null or _pid>0:
		_thread_cancelled=true;phase="cancelling"
	else:
		phase="idle";_cleanup_job()
	status=reason;_refresh()

func _poll_cancel() -> void:
	if not _terminate_child(): return
	if _thread!=null:
		if _thread.is_alive(): return
		_thread.wait_to_finish();_thread=null
	_thread_cancelled=false;phase="idle";_cleanup_job();_refresh()

func _terminate_child() -> bool:
	if _pid<=0: return true
	if OS.is_process_running(_pid):
		# Pinned Godot's Unix kill waits/reaps; Windows kill terminates and
		# closes its process/thread handles. Never poll that retired handle.
		if OS.kill(_pid)!=OK: return false
	else:
		OS.get_process_exit_code(_pid)
	_pid=-1
	return true

func _cleanup_job() -> void:
	if _job_dir.is_empty(): return
	for name_value: String in ["request.txt","result.json","result.json.partial"]:
		DirAccess.remove_absolute(_job_dir+"/"+name_value)
	DirAccess.remove_absolute(_job_dir);_job_dir=""

func _process(_delta: float) -> void:
	if bench==null: return
	if busy() and phase not in ["installing","acknowledging","cancelling"] and Time.get_ticks_msec()-_started>TIMEOUT_MSEC:
		cancel("Native generation exceeded the 30-second limit and was cancelled.")
	match phase:
		"capture": _poll_capture()
		"preparing","decoding": _poll_thread()
		"cancelling": _poll_cancel()
		"running": _poll_process()
		"acknowledging": _acknowledge()
		"installing":
			if bench.host.pending_microscenario_apply.is_empty():
				phase="ready";_pending_patch.clear();_pending_setup.clear();_say("Native installation refused · "+bench.host.microscenario_error)
		"ready":
			if _fence()!=_source_fence or _history()!=_source_history: invalidate("Source changed; regenerate the provisional composition.")
	if _overlay!=null and visible: _overlay.queue_redraw()

func _exit_tree() -> void:
	cancel("Workbench exited; provisional generation cancelled.")
	if not _terminate_child(): push_error("The native construction child could not be terminated during Workbench shutdown.")
	if _thread!=null: _thread.wait_to_finish();_thread=null
	_cleanup_job()
	if not _accepted_path.is_empty(): DirAccess.remove_absolute(_accepted_path)
	if is_instance_valid(_overlay): _overlay.queue_free()
