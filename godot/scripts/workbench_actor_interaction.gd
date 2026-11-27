extends RefCounted

# Input and value-only previews for the ordinary Shared Workbench. The physical
# session owns grabbing; prepared-owner adoption owns authored relocation.
const Manipulator = preload("res://scripts/workbench_actor_manipulator.gd")
const Capacity = preload("res://scripts/workbench_sandbox_capacity.gd")
const DEFAULT_SETTINGS := {"stiffness":160.0,"damping":24.0,"max_force":24000.0,
	"snap_enabled":false,"grid_size":8.0,"rotation_step":15.0,"fine_step":1.0}
const GRAB_TOOL := 5
const PLACE_TOOL := 6
var bench: Control
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var placement: Dictionary = {}
var _source: Dictionary = {}
var _offset := Vector2.ZERO
var _overlay: Control
var _bound_run := ""

func mount(workbench: Control) -> void:
	bench = workbench
	_overlay = preload("res://scripts/workbench_actor_interaction_overlay.gd").new()
	_overlay.interaction = self
	bench.host.world_view.add_child(_overlay)

func mode() -> String:
	match bench._tool.selected:
		0: return "paint"
		GRAB_TOOL: return "grab"
		PLACE_TOOL: return "place"
	return "inspect"

func set_mode(value: String) -> void:
	if value not in ["paint","grab","place"]: return
	var tool: int = {"paint":0,"grab":GRAB_TOOL,"place":PLACE_TOOL}[value]
	if bench._tool.is_item_disabled(tool):
		bench.refuse(bench._tool.get_item_tooltip(tool))
		return
	bench._cancel()
	bench._tool.select(tool)
	bench.message = {"paint":"Paint · Brush and Eraser work during Play; precise tools require Pause.",
		"grab":"Live grab · Play, then drag a physical part. Release anywhere or Escape to let go.",
		"place":"Place / rotate · Pause, drag an actor, Q/E rotate, arrows nudge, Shift for fine adjustment, Escape cancels."}[value]

func configure(value: Dictionary) -> bool:
	if value.size() != DEFAULT_SETTINGS.size() or not value.has_all(DEFAULT_SETTINGS.keys()):
		return bench.refuse("Incomplete manipulation settings.")
	var physical := Manipulator.new()
	if not physical.configure_settings({"stiffness":value.stiffness,"damping":value.damping,"max_force":value.max_force}):
		return bench.refuse("Grab settings must be finite and inside the displayed force limits.")
	if not value.snap_enabled is bool: return bench.refuse("Grid snapping must be on or off.")
	for key: String in ["grid_size","rotation_step","fine_step"]:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])):
			return bench.refuse("Placement settings must be finite numbers.")
	if float(value.grid_size) < 0.25 or float(value.grid_size) > 256.0 \
		or float(value.rotation_step) < 0.25 or float(value.rotation_step) > 180.0 \
		or float(value.fine_step) < 0.01 or float(value.fine_step) > 16.0:
		return bench.refuse("Placement setting is outside its supported range.")
	settings = value.duplicate()
	var current = manipulator()
	if current != null: current.configure_settings(physical.settings())
	bench.message = "Manipulation settings applied for this session. Grab is temporary; committed placement changes the saved start."
	return true

func manipulator() -> RefCounted:
	if bench == null or bench.host == null: return null
	var session = bench.host.physical_actor_session
	if session == null or not is_instance_valid(session): return null
	var result: RefCounted = session.manipulator()
	if session.run_id != _bound_run:
		_bound_run = session.run_id
		result.configure_settings({"stiffness":settings.stiffness,"damping":settings.damping,"max_force":settings.max_force})
	return result

func grab_state() -> Dictionary:
	var current = manipulator()
	return current.state() if current != null else {"active":false,"reason":"No physical session"}

func cancel(reason: String = "input_cancelled") -> void:
	var current = manipulator()
	if current != null: current.end_grab(reason)
	placement.clear()
	_source.clear()
	if is_instance_valid(_overlay): _overlay.queue_redraw()

func actively_manipulating() -> bool:
	return not placement.is_empty() or bool(grab_state().get("active",false))


func blocks_human_input() -> bool:
	# Choosing Grab/Place is not itself an active gesture. Idle tools must not
	# permanently disable keyboard controls for the explicit human pilot.
	return actively_manipulating() or (is_instance_valid(bench._actor_panel) and bench._actor_panel.visible)

func poll() -> void:
	if bench == null or bench.host == null: return
	var current = manipulator()
	if current != null and current.active() and (bench.host.paused or bench.busy() or mode() != "grab" \
		or not bench.host._actor_window_has_focus() or (is_instance_valid(bench._actor_panel) and bench._actor_panel.visible)):
		cancel("pause_focus_or_owner_transition")
	if not placement.is_empty():
		var session = bench.host.physical_actor_session
		if session == null or not bench.host.paused or bench.busy() or mode() != "place" \
			or not bench.host._actor_window_has_focus() or (is_instance_valid(bench._actor_panel) and bench._actor_panel.visible) \
			or session.run_id != str(_source.get("run_id","")) or session.epoch != int(_source.get("epoch",-1)):
			cancel("placement_source_changed")
	if is_instance_valid(_overlay): _overlay.queue_redraw()

func _point(local: Vector2, allow_outside: bool = false) -> Vector2:
	var host: Control = bench.host
	var content: Rect2 = host.view_content_rect()
	if not content.has_area() or (not allow_outside and not content.has_point(local)):
		return Vector2(INF,INF)
	return Vector2(host.camera_origin).floor() + (local-content.position)/content.size*Vector2(host.current_view_size)

func _global_local(event: InputEventMouse) -> Vector2:
	return bench.host.world_view.get_global_transform_with_canvas().affine_inverse() * event.position

func global_input(event: InputEvent) -> bool:
	# Capture an active gesture's release before GUI routing, including a release
	# outside the canvas or over a control. It must not also click that control.
	var active_grab: bool = bool(grab_state().get("active",false))
	if event is InputEventMouse and (active_grab or not placement.is_empty()):
		var point := _point(_global_local(event),active_grab)
		if event is InputEventMouseMotion:
			if active_grab:
				if point.is_finite(): manipulator().update_target(point)
			elif point.is_finite(): update_placement(point,event.shift_pressed)
			return true
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				cancel("cancelled")
				bench.message = "Manipulation cancelled; authored placement unchanged."
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				if active_grab:
					manipulator().end_grab("released")
					bench.message = "Released physical part; its previous controller can resume."
				elif not point.is_finite():
					cancel("released_outside_canvas")
					bench.message = "Placement cancelled outside canvas."
				else:
					update_placement(point,event.shift_pressed)
					commit_placement()
			return true
	if not event is InputEventKey or not event.pressed or event.echo: return false
	var focus := bench.get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	if event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
		bench._commit_field()
		bench.save_setup()
		return true
	if event.keycode == KEY_ESCAPE and (active_grab or not placement.is_empty()):
		cancel("cancelled")
		bench.message = "Manipulation cancelled; authored placement unchanged."
		return true
	if placement.is_empty(): return false
	var angle: float = float(placement.rotation)
	var position: Vector2 = placement.position
	var step: float = float(settings.fine_step) if event.shift_pressed else float(settings.grid_size if settings.snap_enabled else 4.0)
	match event.keycode:
		KEY_Q: angle -= deg_to_rad(1.0 if event.shift_pressed else float(settings.rotation_step))
		KEY_E: angle += deg_to_rad(1.0 if event.shift_pressed else float(settings.rotation_step))
		KEY_LEFT: position.x -= step
		KEY_RIGHT: position.x += step
		KEY_UP: position.y -= step
		KEY_DOWN: position.y += step
		KEY_ENTER,KEY_KP_ENTER:
			commit_placement()
			return true
		_: return false
	_refresh_preview(position,angle)
	# Pointer release must preserve a nudge, even without a following motion.
	var mouse := _point(bench.host.world_view.get_local_mouse_position())
	if mouse.is_finite(): _offset = position-mouse
	return true

func world_input(event: InputEvent) -> bool:
	if mode() not in ["grab","place"] or not event is InputEventMouse: return false
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_MIDDLE]:
		return false
	# Active manipulation captures its motion in global_input. An idle middle
	# drag still belongs to the existing camera, including its motion events.
	if event is InputEventMouseMotion and bench._pan: return false
	if not event is InputEventMouseButton or not event.pressed: return true
	if event.button_index != MOUSE_BUTTON_LEFT: return true
	if bench.busy() or bench.applied.is_empty(): return true
	var point := _point(event.position)
	if not point.is_finite(): return true
	var current = manipulator()
	if current == null:
		bench.refuse("Place an actor in this canvas first.")
		return true
	var picked: Dictionary = current.hit_test(point)
	if picked.is_empty():
		bench.refuse("No physical actor part under the pointer.")
		return true
	if mode() == "grab":
		if bench.host.paused:
			bench.refuse("Press Play to physically grab a part; use Place / rotate for paused arrangement.")
			return true
		bench.select_instance(int(picked.instance_id))
		var started: Dictionary = current.begin_grab(point)
		if started.is_empty(): bench.refuse("The selected physical body is unavailable.")
		else: bench.message = "Grabbing #%d · %s with physical forces; other actors continue." % [int(started.instance_id),str(started.part_id)]
	else:
		begin_placement(int(picked.instance_id),point)
	return true

func begin_placement(instance_id: int, pointer: Vector2) -> bool:
	if not bench.host.paused: return bench.refuse("Pause before placing an entire actor.")
	if bench.busy(): return bench.refuse("Wait for the current owner transaction.")
	bench.select_instance(instance_id)
	var current = manipulator()
	if current == null: return bench.refuse("Physical owner unavailable.")
	_source = current.capture_actor(instance_id)
	if _source.is_empty(): return bench.refuse("Actor pose is unavailable.")
	_offset = Vector2(_source.position)-pointer
	_refresh_preview(_source.position,float(_source.rotation))
	return true

func update_placement(pointer: Vector2, fine: bool = false) -> void:
	if placement.is_empty() or not pointer.is_finite(): return
	var position := pointer+_offset
	if settings.snap_enabled and not fine:
		position = position.snapped(Vector2.ONE*float(settings.grid_size))
	_refresh_preview(position,float(placement.rotation))

func _refresh_preview(position: Vector2, rotation: float) -> void:
	placement = Manipulator.placement_preview(_source,position,rotation)
	if placement.is_empty():
		bench.refuse("Could not construct the placement preview.")
		return
	placement["active"] = true
	placement["rotation_degrees"] = rad_to_deg(float(placement.rotation))
	bench.message = "Placement preview #%d · (%.2f, %.2f) · %.1f° · %s" % [int(_source.instance_id),position.x,position.y,
		placement.rotation_degrees,"release to prepare / Esc cancels" if placement.valid else str(placement.reason)]

func place_exact(instance_id: int, position: Vector2, rotation_degrees: float) -> bool:
	if not position.is_finite() or not is_finite(rotation_degrees): return bench.refuse("Placement must be finite.")
	if not begin_placement(instance_id,position): return false
	_refresh_preview(position,deg_to_rad(rotation_degrees))
	return commit_placement()

func commit_placement() -> bool:
	if placement.is_empty(): return false
	var source := _source.duplicate(true)
	var proposed := placement.duplicate(true)
	# Clear preview before apply cancels input. No live transform was changed.
	placement.clear()
	_source.clear()
	if not bool(proposed.get("valid",false)): return bench.refuse(str(proposed.get("reason","Invalid placement.")))
	return bench.commit_actor_placement(source,proposed)

func state() -> Dictionary:
	var capacity := Capacity.summary(bench.applied.get("actors",[]),bench.applied.get("sandbox_capacity",Capacity.defaults()))
	var session = bench.host.physical_actor_session
	var runtime := {"actors":0,"bodies":0,"joints":0,"native_tick":-1,"rapier_tick":-1,
		"published_native_bodies":0,"published_native_proxies":0}
	if session != null:
		runtime.actors = session._rigs.size()
		runtime.bodies = session.bodies().size()
		runtime.rapier_tick = session.tick
		for rig in session._rigs: runtime.joints += rig.physical_joint_count()
	if bench.host.latest_snapshot != null:
		runtime.native_tick = bench.host.latest_snapshot.tick_index
		var native: Dictionary = bench.host.latest_snapshot.lab_context.get("workbench_gcr",{})
		runtime.published_native_bodies = int(native.get("active_bodies",0))
		runtime.published_native_proxies = int(native.get("active_proxies",0))
	return {"mode":mode(),"settings":settings.duplicate(),"capacity":capacity,
		"runtime":runtime,
		"manipulation":grab_state(),"placement":placement.duplicate(true),"preparing":not bench.host.pending_microscenario_apply.is_empty()}
