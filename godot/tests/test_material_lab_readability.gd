extends SceneTree

var checks: int = 0
var failures: int = 0

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func pointer(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)

func run() -> void:
	root.size = Vector2i(1000,650) if "--compact" in OS.get_cmdline_user_args() else Vector2i(1280,720)
	var scene: Control = load("res://materials_lab.tscn").instantiate()
	root.add_child(scene)
	for frame: int in range(4): await process_frame
	var panel: Variant = scene.find_child("MaterialsLabPanel",true,false)
	var tree: Tree = panel._property_tree
	expect(panel._tabs.get_tab_title(1) == "Edit copy" and panel._tabs.get_tab_title(3) == "Try originals" and panel._tabs.get_tab_title(4) == "Compare edits","Tabs describe the task")
	expect(tree.get_column_title(2) == "Value used" and tree.get_column_title(3) == "What uses it","Property headings explain their purpose")
	expect(not panel._inspector_notes.visible,"Raw technical details are available without dominating the first view")
	for column: int in range(6):
		# Move the table until the divider is visible, then deliver real viewport
		# mouse events rather than invoking the resize implementation directly.
		tree.scroll_to_item(tree.get_root().get_first_child())
		var scroll: HScrollBar
		for child: Node in tree.get_children(true):
			if child is HScrollBar: scroll = child
		if scroll == null:
			expect(false,"Table exposes its horizontal scrolling control")
			quit(1)
			return
		var edge: float = 0
		for prior: int in range(column+1): edge += tree.get_column_width(prior)
		scroll.value = clampf(edge - tree.size.x / 2.0,0,scroll.max_value)
		for frame: int in range(3): await process_frame
		var handle: Control = tree._handles[column]
		expect(handle.visible,"Divider %d is reachable by horizontal scrolling" % column)
		var before: int = tree.get_column_width(column)
		var point: Vector2 = handle.get_global_rect().get_center()
		pointer(point,true)
		var move := InputEventMouseMotion.new()
		move.position = point + Vector2(35,0)
		move.global_position = move.position
		move.relative = Vector2(35,0)
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(move)
		pointer(move.position,false)
		await process_frame
		expect(tree.get_column_width(column) == before+35,"Dragging divider %d changes the displayed column width" % column)
		panel.select_material(2 if column % 2 == 0 else 3)
		expect(tree.get_column_width(column) == before+35,"Material selection preserves the user's column width")
	print("MATERIAL_LAB_READABILITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
