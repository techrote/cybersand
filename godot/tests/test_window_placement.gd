extends SceneTree

# Pure launch-placement calculation. Real display state is not read here.
const SIZE := Vector2i(1922, 1112)

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("WINDOW_PLACEMENT FAILED: ", message)


func _contained(placement: Dictionary, usable_rects: Array[Rect2i]) -> bool:
	var usable: Rect2i = usable_rects[placement.screen]
	return usable.encloses(placement.rect)


func _run() -> void:
	# Reported desktop: portrait primary at the origin, offset landscape secondary.
	var portrait_primary: Array[Rect2i] = [Rect2i(1200, 566, 2560, 1440), Rect2i(0, 0, 1200, 1731)]
	var moved: Dictionary = CyberWindowPlacement.plan(SIZE, portrait_primary, 1)
	_expect(moved.screen == 0, "oversized primary must yield to the screen that fits")
	_expect(moved.rect == Rect2i(1519, 730, 1922, 1112), "window must centre on the chosen screen")
	_expect(_contained(moved, portrait_primary), "window must lie entirely on one screen")

	var fits_primary: Array[Rect2i] = [Rect2i(0, 0, 3840, 2160), Rect2i(-1920, 0, 1920, 1080)]
	var stays: Dictionary = CyberWindowPlacement.plan(Vector2i(1000, 600), fits_primary, 1)
	_expect(stays.screen == 1, "primary is kept when the window fits there")
	_expect(stays.rect == Rect2i(-1460, 240, 1000, 600), "negative screen origins must be respected")

	var nothing_fits: Array[Rect2i] = [Rect2i(0, 0, 1280, 720), Rect2i(1280, 40, 1366, 728)]
	var shrunk: Dictionary = CyberWindowPlacement.plan(SIZE, nothing_fits, 0)
	_expect(shrunk.screen == 1, "largest screen is used when none fits")
	_expect(shrunk.rect == Rect2i(1280, 40, 1366, 728), "window must clamp to the usable area")

	var one_axis: Array[Rect2i] = [Rect2i(0, 0, 2000, 1000), Rect2i(2000, 0, 1930, 1120)]
	_expect(CyberWindowPlacement.plan(SIZE, one_axis, 0).screen == 1,
		"a smaller screen that holds the window beats a larger one that does not")

	_expect(CyberWindowPlacement.plan(SIZE, [] as Array[Rect2i], 0).is_empty(), "no screens yields no plan")
	_expect(CyberWindowPlacement.plan(Vector2i.ZERO, portrait_primary, 1).is_empty(), "an empty window yields no plan")
	var bad_primary: Dictionary = CyberWindowPlacement.plan(Vector2i(100, 100), fits_primary, 7)
	_expect(bad_primary.screen == 0, "an invalid primary index must not fail")

	_expect(not CyberWindowPlacement.is_on_one_screen(Rect2i(0, 325, 1922, 1112), portrait_primary),
		"the reported spawn spans screens and must be corrected")
	_expect(CyberWindowPlacement.is_on_one_screen(Rect2i(1300, 600, 1922, 1112), portrait_primary),
		"a valid position on one screen must be left alone")
	_expect(CyberWindowPlacement.is_on_one_screen(Rect2i(-500, 10, 100, 100), fits_primary),
		"a window on a negative-origin screen is valid")

	if _failures == 0:
		print("WINDOW_PLACEMENT: PASS")
	quit(1 if _failures > 0 else 0)
