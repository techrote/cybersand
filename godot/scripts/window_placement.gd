class_name CyberWindowPlacement
extends RefCounted

# Godot centres a new window on the primary screen even when it does not fit,
# which can leave part of it on no monitor at all. Launch placement moves only a
# window that is not already entirely on one screen, title bar included. Godot
# hides its own window arguments from scripts, so a valid --position survives by
# this rule, while one that spans screens or leaves them is corrected.

# Returns the screen index and outer rectangle for an outer window size. Keeps the
# primary screen when the window fits there, otherwise prefers the largest screen.
static func plan(outer_size: Vector2i, usable_rects: Array[Rect2i], primary: int) -> Dictionary:
	if usable_rects.is_empty() or outer_size.x <= 0 or outer_size.y <= 0:
		return {}
	var chosen: int = primary if primary >= 0 and primary < usable_rects.size() else 0
	if not _fits(outer_size, usable_rects[chosen]):
		chosen = _largest_screen(outer_size, usable_rects)
	var usable: Rect2i = usable_rects[chosen]
	var size: Vector2i = outer_size.min(usable.size)
	return {"screen":chosen, "rect":Rect2i(usable.position + (usable.size - size) / 2, size)}


static func _fits(outer_size: Vector2i, usable: Rect2i) -> bool:
	return outer_size.x <= usable.size.x and outer_size.y <= usable.size.y


# A screen that holds the whole window beats one that would shrink it.
static func _largest_screen(outer_size: Vector2i, usable_rects: Array[Rect2i]) -> int:
	var best: int = 0
	for index: int in range(1, usable_rects.size()):
		var candidate: Rect2i = usable_rects[index]
		var current: Rect2i = usable_rects[best]
		var candidate_fits: bool = _fits(outer_size, candidate)
		if candidate_fits != _fits(outer_size, current):
			if candidate_fits:
				best = index
		elif candidate.get_area() > current.get_area():
			best = index
	return best


static func is_on_one_screen(outer_rect: Rect2i, usable_rects: Array[Rect2i]) -> bool:
	for usable: Rect2i in usable_rects:
		if usable.encloses(outer_rect):
			return true
	return false


# Applies the plan to a normal top-level desktop window. Returns whether it moved.
# Script-driven fixtures keep the geometry they asked for.
static func apply_at_launch(window: Window) -> bool:
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return false
	if window.mode != Window.MODE_WINDOWED or "--script" in OS.get_cmdline_args():
		return false
	var usable_rects: Array[Rect2i] = []
	for index: int in range(DisplayServer.get_screen_count()):
		usable_rects.append(DisplayServer.screen_get_usable_rect(index))
	var outer_position: Vector2i = window.get_position_with_decorations()
	var outer_size: Vector2i = window.get_size_with_decorations()
	if is_on_one_screen(Rect2i(outer_position, outer_size), usable_rects):
		return false
	var placement: Dictionary = plan(outer_size, usable_rects, DisplayServer.get_primary_screen())
	if placement.is_empty():
		return false
	var target: Rect2i = placement.rect
	# Window position and size address the client area inside the decorations.
	window.size = target.size - (outer_size - window.size)
	window.position = target.position + (window.position - outer_position)
	return true
