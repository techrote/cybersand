extends RefCounted

# Lab-only popup policy. All methods and layout changes run on Main.
# Separate rendering cannot safely transfer the one GL context to a native
# child window on the supported desktop backends. Keep those Labs embedded;
# compensate their own content scale without changing the World/camera canvas.
const BINDING_NAME: String = "WorkbenchLabWindowPolicy"

class Binding extends Node:
	var popup: Window
	var parent_window: Window
	var preferred_physical := Vector2i(900,730)
	var minimum_physical := Vector2i(740,520)
	var embedded_policy: bool = false
	var parent_scale: float = 1.0
	var base_title_font: int = 16
	var base_constants: Dictionary = {}
	var admitted: bool = false

	func _ready() -> void:
		if not embedded_policy: return
		# The ordinary game root already embeds subwindows. Do not change the
		# policy of sibling popups if a caller supplies a different parent.
		if not parent_window.gui_embed_subwindows:
			push_error("Lab popup requires an embedding parent with Separate rendering.")
			return
		base_title_font = popup.get_theme_font_size("title_font_size")
		for key: String in ["title_height", "close_h_offset", "close_v_offset", "resize_margin"]:
			base_constants[key] = popup.get_theme_constant(key)
		parent_window.size_changed.connect(_parent_resized,CONNECT_DEFERRED)
		fit()

	func _exit_tree() -> void:
		if is_instance_valid(parent_window) and parent_window.size_changed.is_connected(_parent_resized):
			parent_window.size_changed.disconnect(_parent_resized)

	func _parent_resized() -> void:
		if is_instance_valid(popup) and popup.visible: fit()

	func fit(requested_physical: Vector2i = Vector2i.ZERO) -> void:
		if not embedded_policy or not is_instance_valid(popup): return
		admitted = false
		if requested_physical != Vector2i.ZERO: preferred_physical = requested_physical
		var stretch: Vector2 = parent_window.get_stretch_transform().get_scale()
		parent_scale = maxf(minf(absf(stretch.x), absf(stretch.y)), 0.001)
		var available: Vector2 = parent_window.get_visible_rect().size * parent_scale
		# Leave physical room for the title bar and borders, even at a small root.
		var maximum: Vector2 = (available - Vector2(24,60)).max(Vector2(1,1))
		var placement := {"admitted":false,"parent_scale":parent_scale,
			"available_physical":available,"maximum_physical":maximum,
			"preferred_physical":preferred_physical,"minimum_physical":minimum_physical}
		popup.set_meta("lab_window_placement",placement)
		if not parent_window.gui_embed_subwindows or maximum.x < minimum_physical.x \
				or maximum.y < minimum_physical.y:
			popup.hide()
			return
		var minimum: Vector2 = Vector2(minimum_physical)
		var chosen: Vector2 = Vector2(preferred_physical).min(maximum).max(minimum)
		popup.min_size = Vector2i.ZERO
		popup.max_size = Vector2i.ZERO
		popup.content_scale_factor = 1.0 / parent_scale
		popup.min_size = Vector2i((minimum / parent_scale).floor()).max(Vector2i.ONE)
		popup.max_size = Vector2i((maximum / parent_scale).floor()).max(Vector2i.ONE)
		popup.size = Vector2i((chosen / parent_scale).floor()).max(Vector2i.ONE)
		var centered: Vector2 = (parent_window.get_visible_rect().size - Vector2(popup.size)) * 0.5
		centered.y += float(base_constants.get("title_height",36)) / (2.0 * parent_scale)
		popup.position = Vector2i(centered)
		popup.add_theme_font_size_override("title_font_size", maxi(1,roundi(base_title_font / parent_scale)))
		for key: String in base_constants:
			popup.add_theme_constant_override(key, maxi(1,roundi(float(base_constants[key]) / parent_scale)))
		admitted = true
		placement.admitted = true
		placement["content_scale_factor"] = popup.content_scale_factor
		placement["logical_size"] = popup.size
		placement["logical_position"] = popup.position
		popup.set_meta("lab_window_placement",placement)

	func open() -> bool:
		if embedded_policy:
			fit()
			# force_native=false alone is insufficient if no ancestor embeds.
			if not parent_window.gui_embed_subwindows:
				push_error("Lab popup requires an embedding parent with Separate rendering.")
				return false
			if not admitted: return false
			popup.popup(Rect2i(popup.position,popup.size))
		else:
			popup.popup_centered_clamped(preferred_physical,0.95)
		return true


static func uses_separate_rendering() -> bool:
	return not RenderingServer.is_on_render_thread()


static func configure(popup: Window, parent_window: Window,
		preferred_physical: Vector2i, minimum_physical: Vector2i) -> void:
	assert(not popup.visible, "Configure a Lab before showing it.")
	assert(popup.get_node_or_null(BINDING_NAME) == null, "A Lab owns one bounded popup binding.")
	var binding := Binding.new()
	binding.name = BINDING_NAME
	binding.popup = popup
	binding.parent_window = parent_window
	binding.preferred_physical = preferred_physical
	binding.minimum_physical = minimum_physical
	binding.embedded_policy = uses_separate_rendering()
	popup.force_native = not binding.embedded_policy and not OS.has_feature("web") \
		and DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS)
	popup.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	popup.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	configure_popup_font(popup)
	popup.min_size = minimum_physical
	popup.size = preferred_physical
	popup.add_child(binding)


static func open(popup: Window) -> bool:
	var binding: Binding = popup.get_node(BINDING_NAME)
	return binding.open()


static func fit_embedded(popup: Window, requested_physical: Vector2i = Vector2i.ZERO) -> void:
	var binding: Binding = popup.get_node(BINDING_NAME)
	binding.fit(requested_physical)


static func configure_popup_font(popup: Window) -> void:
	if uses_separate_rendering():
		# These compensated embedded popups render at one physical pixel per
		# UI unit. Window otherwise forces the ancestor's fractional font
		# oversampling, producing a smaller atlas enlarged back to 1x pixels.
		# Keep the correction local; Safe/native and the World are unchanged.
		popup.set_use_oversampling(false)


static func request_vsync(mode: int) -> void:
	# Only this bound native method runs on the render owner. No GDScript or
	# scene state crosses threads. DisplayServer outlives the drained server.
	# In Separate mode this is asynchronous; read back after a later frame.
	RenderingServer.call_on_render_thread(Callable(DisplayServer,"window_set_vsync_mode").bind(mode))
