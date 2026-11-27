extends SceneTree
## Clipboard routes use synthetic injected values; an explicitly isolated displayed
## CI desktop can additionally compare ordinary clipboard edits to native TextEdit.
const Editor = preload("res://scripts/art_conversation_editor.gd")
const ClipboardEditor = preload("res://scripts/art_conversation_text_edit.gd")
class ClipboardFixture extends "res://scripts/art_conversation_text_edit.gd":
	var clipboard := ""
	var primary := ""
	var primary_position := Vector2i.ZERO
	func _read_clipboard(is_primary: bool = false) -> String:
		return primary if is_primary else clipboard
	func _write_clipboard(value: String) -> void:
		clipboard = value
	func _supports_primary_clipboard() -> bool:
		return true
	func _primary_caret_position() -> Vector2i:
		return primary_position

var checks := 0
var failures: Array[String] = []
var largest_visible_text := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func reset_editor(editor: Editor, value: String) -> void:
	editor.content.remove_secondary_carets()
	editor.content._copied_line = ""
	editor.open_history([{"role":"user","content":value}])

func caret_offset(content: TextEdit, caret: int = 0) -> int:
	var offset := content.get_caret_column(caret)
	for line: int in range(content.get_caret_line(caret)):
		offset += content.get_line(line).length()+1
	return offset

func run() -> void:
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	if OS.get_cmdline_user_args().has("--native-clipboard-only"):
		var available := OS.get_environment("CYBERSAND_TEST_OWNED_CLIPBOARD") == "1" and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
		if available:
			compare_native_clipboard()
		else:
			check(false,"native clipboard diagnostic requires an explicitly owned displayed desktop")
		await process_frame
		print("ART_NATIVE_CLIPBOARD_ONLY_RESULT ",JSON.stringify({"checks":checks,"failures":failures,
			"native_clipboard_differential":available,"display":DisplayServer.get_name(),
			"qualification":"Only ordinary native TextEdit/production clipboard operations; no oversized paste or Workbench activity"}))
		quit(0 if failures.is_empty() else 1)
		return
	var editor := Editor.new()
	editor.content.free()
	var content := ClipboardFixture.new()
	editor.content = content
	root.add_child(editor)
	await process_frame
	reset_editor(editor,"ab\nselected\ncd")
	content.select(1,0,1,8)
	content.clipboard = "λ\r\n日本"
	content.paste()
	check(content.text=="ab\nλ\n日本\ncd","ordinary Paste replaces the forward selection and normalizes CRLF")
	check(content.get_caret_line()==2 and content.get_caret_column()==2,"ordinary Paste puts the caret after the inserted Unicode text")
	content.undo()
	check(content.text=="ab\nselected\ncd" and content.get_selected_text()=="selected","one Undo restores the original text and selection")
	content.redo()
	check(content.text=="ab\nλ\n日本\ncd","one Redo restores the complete ordinary paste")
	reset_editor(editor,"ab\nselected\ncd")
	content.select(1,8,1,0)
	content.clipboard = "replacement"
	content.get_menu().id_pressed.emit(TextEdit.MENU_PASTE)
	check(content.text=="ab\nreplacement\ncd","native context-menu Paste binding reaches the override and replaces a backward selection")
	content.select(1,0,1,11)
	content.clipboard = ""
	content.paste()
	check(content.text=="ab\nreplacement\ncd" and content.has_selection(),"an empty clipboard preserves both selection and text")
	content.copy()
	check(content.clipboard=="replacement","ordinary Copy retains exactly the selected text")
	content.cut()
	check(content.text=="ab\n\ncd" and content.clipboard=="replacement","ordinary Cut copies and removes the selection")
	content.undo()
	check(content.text=="ab\nreplacement\ncd","native Undo restores an ordinary Cut")
	reset_editor(editor,"one\ntwo\nthree")
	content.set_caret_line(1)
	content.set_caret_column(1)
	content.copy()
	check(content.clipboard=="two\n","Copy without a selection retains the native whole-line convention")
	content.set_caret_line(2)
	content.set_caret_column(2)
	content.paste()
	check(content.text=="one\ntwo\ntwo\nthree" and content.get_caret_line()==3 and content.get_caret_column()==2,"matching whole-line Paste inserts before the destination line and preserves its caret column")
	content.undo()
	check(content.text=="one\ntwo\nthree","one Undo removes a whole-line Paste")
	content.clipboard = "changed externally"
	content.paste()
	check(content.text=="one\ntwo\nthchanged externallyree","a changed clipboard uses ordinary caret insertion instead of stale whole-line mode")
	reset_editor(editor,"one\ntwo\nthree")
	content.set_caret_line(1)
	content.set_caret_column(1)
	content.cut()
	check(content.text=="one\nthree" and content.clipboard=="two\n","Cut without a selection removes and copies the full line")
	content.paste()
	check(content.text=="one\ntwo\nthree","whole-line Cut followed by Paste preserves the original lines")
	content.undo()
	content.undo()
	check(content.text=="one\ntwo\nthree","native Undo separately restores whole-line Paste and Cut")
	reset_editor(editor,"a\nb")
	content.set_caret_column(1)
	content.add_caret(1,1)
	content.clipboard = "x\ny"
	content.paste()
	check(content.text=="ax\nby" and content.get_caret_count()==2,"multicaret Paste distributes one clipboard line per caret")
	content.undo()
	check(content.text=="a\nb" and content.get_caret_count()==2,"one Undo restores a multicaret Paste")
	content.clipboard = "z"
	content.paste()
	check(content.text=="az\nbz","other clipboard text is inserted completely at every caret")
	reset_editor(editor,"one\ntwo\nthree\nfour")
	content.set_caret_line(1)
	content.set_caret_column(1)
	content.add_caret(3,2)
	content.cut()
	check(content.text=="one\nthree" and content.clipboard=="two\nfour\n","whole-line multicaret Cut handles shifted ranges including the final document line")
	content.undo()
	check(content.text=="one\ntwo\nthree\nfour" and content.get_caret_count()==2,"one Undo restores whole-line multicaret Cut and both carets")
	reset_editor(editor,"read only")
	content.select_all()
	content.editable = false
	content.cut()
	check(content.text=="read only" and content.clipboard=="read only","read-only Cut copies without changing the message")
	content.clipboard = "cannot insert"
	content.paste()
	check(content.text=="read only","read-only Paste cannot modify content")
	reset_editor(editor,"key ")
	content.set_caret_column(4)
	content.clipboard = "route"
	content.grab_focus()
	await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.ctrl_pressed = true
	key.pressed = true
	editor.push_input(key,true)
	await process_frame
	check(content.text=="key route","simulated native ui_paste key input reaches the clipboard override")
	# Near-cap input enters through paste(), never through an enormous .text
	# assignment. Every emitted widget state remains bounded to a single part.
	reset_editor(editor,"prefix TARGET suffix")
	content.select(0,7,0,13)
	var clipboard := ("large clipboard line λ 日本語 🐈\r\n".repeat(620000)).left(16*1024*1024-8192)+"\nLAST"
	var normalized := clipboard.replace("\r","")
	content.clipboard = clipboard
	content.text_changed.connect(func() -> void: largest_visible_text = maxi(largest_visible_text,content.text.length()))
	content.text_set.connect(func() -> void: largest_visible_text = maxi(largest_visible_text,content.text.length()))
	var began := Time.get_ticks_usec()
	content.paste()
	var paste_usec := Time.get_ticks_usec()-began
	await process_frame
	var expected := "prefix "+normalized+" suffix"
	check(editor._pages.size()>200 and content.text.length()<=Editor.PAGE_CHARACTERS,"near-cap Paste creates bounded parts before visible insertion")
	check(largest_visible_text>0 and largest_visible_text<=Editor.PAGE_CHARACTERS,"no observed TextEdit update contains the complete oversized paste")
	check("".join(editor._pages)==expected,"large selection replacement retains the exact normalized Unicode clipboard and both surrounding fragments")
	check(editor._page_index*Editor.PAGE_CHARACTERS+caret_offset(content)==7+normalized.length(),"large Paste places the visible caret at the exact insertion endpoint")
	check(paste_usec<2000000,"near-cap Paste remains below the unchanged two-second callback gate")
	var jump_began := Time.get_ticks_usec()
	editor.page_jump.text_submitted.emit("2")
	var unicode_jump_usec := Time.get_ticks_usec()-jump_began
	check(content.text.length()==Editor.PAGE_CHARACTERS and unicode_jump_usec<2000000,"jumping to a full Unicode part remains below the unchanged two-second callback gate")
	editor.flush_message()
	check(editor.draft[0].content==expected and editor.baseline[0].content=="prefix TARGET suffix","Apply projection retains the complete paste while baseline remains unchanged")
	editor.hide()
	editor.open_history(editor.baseline)
	check(editor.content.text=="prefix TARGET suffix" and editor.draft[0].content=="prefix TARGET suffix","Cancel and reopen discard every part of a large paste")
	reset_editor(editor,"head\nTAIL")
	content.set_caret_column(4)
	content.clipboard = "menu pasted row\n".repeat(5000)
	var menu_expected := "head"+content.clipboard+"\nTAIL"
	content.get_menu().id_pressed.emit(TextEdit.MENU_PASTE)
	check("".join(editor._pages)==menu_expected and content.text.length()<=Editor.PAGE_CHARACTERS,"context-menu Paste also pages oversized clipboard input before shaping")
	reset_editor(editor,"first\nsecond")
	content.select(1,0,1,6)
	content.primary_position = Vector2i(2,0)
	content.primary = "primary row\n".repeat(6000)
	content.paste_primary_clipboard()
	check("".join(editor._pages)=="fi"+content.primary+"rst\nsecond","primary clipboard Paste uses the mouse position and preserves the former selection text")
	check(content.text.length()<=Editor.PAGE_CHARACTERS,"primary clipboard Paste also keeps visible text bounded")
	reset_editor(editor,"a\nb")
	content.set_caret_column(1)
	content.add_caret(1,1)
	content.clipboard = "large row\n".repeat(8000)
	content.paste()
	check("".join(editor._pages)=="a"+content.clipboard+"\nb"+content.clipboard,"oversized multicaret Paste retains every insertion across parts")
	var prior := "prior row\n".repeat(Editor.PAGE_CHARACTERS/10+1).left(Editor.PAGE_CHARACTERS)
	var following := "following row\n".repeat(Editor.PAGE_CHARACTERS/14+1)+"TAIL"
	var surrounding := prior+"prefix TARGET suffix\n"+following
	reset_editor(editor,surrounding)
	editor._show_page(1)
	content.select(0,7,0,13)
	content.clipboard = "middle pasted row\n".repeat(5000)
	content.paste()
	var surrounding_expected := prior+"prefix "+content.clipboard+" suffix\n"+following
	check("".join(editor._pages)==surrounding_expected,"large Paste preserves every untouched preceding and following part")
	editor.page_jump.text_submitted.emit("1")
	check(editor._page_index==0 and content.text==prior,"part-number jump reaches the first part directly")
	content.text = "EDIT!"+content.text.substr(5)
	editor.page_jump.text_submitted.emit(str(editor._pages.size()))
	check(editor._page_index==editor._pages.size()-1 and content.text.ends_with("TAIL"),"part-number jump reaches the final part directly")
	check("".join(editor._pages)=="EDIT!"+surrounding_expected.substr(5),"jumping retains the current part edit and every intervening part")
	var last_part := editor._page_index
	editor.page_jump.text_submitted.emit("invalid")
	check(editor._page_index==last_part and editor.page_jump.text==str(last_part+1),"invalid part numbers preserve the current content and restore the displayed part number")
	var apply_signals := [0]
	editor.confirmed.connect(func() -> void: apply_signals[0] += 1)
	editor.page_jump.text = "1"
	editor.page_jump.grab_focus()
	await process_frame
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	editor.push_input(enter,true)
	await process_frame
	check(editor._page_index==0 and apply_signals[0]==0,"Enter in the part-number field navigates without applying the conversation draft")
	for scale: float in [1.0,1.25,1.5]:
		editor.content_scale_factor = scale
		editor._sync_minimum()
		editor.size = Vector2i((Vector2(480,280)*scale).ceil())
		for frame: int in 3: await process_frame
		var logical_bounds := Rect2(Vector2.ZERO,Vector2(editor.size)/scale)
		for control: Control in [editor.previous_page,editor.page_jump,editor.next_page,editor.get_ok_button(),editor.get_cancel_button()]:
			check(logical_bounds.encloses(control.get_global_rect()),"paged navigation and Apply/Cancel stay within the minimum dialog at scale %.2f: %s" % [scale,control.get_class()])
	var native_clipboard := OS.get_environment("CYBERSAND_TEST_OWNED_CLIPBOARD") == "1" and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	if native_clipboard:
		compare_native_clipboard()
	else:
		print("ART_NATIVE_CLIPBOARD_DIFFERENTIAL_UNQUALIFIED requires CYBERSAND_TEST_OWNED_CLIPBOARD=1 on an isolated displayed desktop")
	editor.queue_free()
	await process_frame
	print("ART_CONVERSATION_CLIPBOARD_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"clipboard_characters":clipboard.length(),"paste_usec":paste_usec,
		"largest_visible_text":largest_visible_text,"unicode_jump_usec":unicode_jump_usec,"native_clipboard_differential":native_clipboard,
		"qualification":"Godot injected-clipboard key/menu/primary binding regression; physical owner clipboard and mouse hit-testing are not asserted"}))
	quit(0 if failures.is_empty() else 1)

func edit_snapshot(content: TextEdit) -> Dictionary:
	var carets: Array[Dictionary] = []
	for index: int in range(content.get_caret_count()):
		var caret := {"line":content.get_caret_line(index),"column":content.get_caret_column(index),
			"has_selection":content.has_selection(index)}
		if content.has_selection(index):
			caret.merge({"selected_text":content.get_selected_text(index),
				"selection_origin_line":content.get_selection_origin_line(index),
				"selection_origin_column":content.get_selection_origin_column(index),
				"selection_from_line":content.get_selection_from_line(index),
				"selection_from_column":content.get_selection_from_column(index),
				"selection_to_line":content.get_selection_to_line(index),
				"selection_to_column":content.get_selection_to_column(index)})
		carets.append(caret)
	return {"text":content.text,"carets":carets}

func same_edit(native: TextEdit, owned: TextEdit) -> bool:
	return edit_snapshot(native) == edit_snapshot(owned)

func compare_native_clipboard() -> void:
	var native := TextEdit.new()
	# Both controls must cross the same real OS clipboard boundary. In Godot
	# 4.7 Windows, DisplayServer converts LF to CRLF on clipboard_set; the
	# injected fixture above deliberately bypasses that platform conversion.
	# Compare raw round-tripped bytes, without normalizing differences away.
	var owned := ClipboardEditor.new()
	root.add_child(native)
	root.add_child(owned)
	for backward: bool in [false,true]:
		for target: TextEdit in [native,owned]:
			target.text = "first\nselected\nlast"
			target.clear_undo_history()
			target.select(1,8 if backward else 0,1,0 if backward else 8)
		DisplayServer.clipboard_set("λ\r\n日本")
		native.paste()
		owned.paste()
		check(same_edit(native,owned),"ordinary selection Paste matches native TextEdit, backward=%s" % backward)
		native.undo()
		owned.undo()
		check(same_edit(native,owned),"ordinary selection Undo matches native TextEdit, backward=%s" % backward)
	for cutting: bool in [false,true]:
		var clipboard_results: Array[String] = []
		for target: TextEdit in [native,owned]:
			target.text = "one\ntwo\nthree"
			target.clear_undo_history()
			target.set_caret_line(1)
			target.set_caret_column(1)
			if cutting: target.cut()
			else: target.copy()
			clipboard_results.append(DisplayServer.clipboard_get())
		print("ART_NATIVE_CLIPBOARD_WHOLE_LINE ",JSON.stringify({"cutting":cutting,
			"display":DisplayServer.get_name(),"native_clipboard":clipboard_results[0],
			"owned_clipboard":clipboard_results[1],"native_clipboard_utf8":clipboard_results[0].to_utf8_buffer().hex_encode(),
			"owned_clipboard_utf8":clipboard_results[1].to_utf8_buffer().hex_encode(),
			"native_edit":edit_snapshot(native),"owned_edit":edit_snapshot(owned)}))
		check(clipboard_results[0]==clipboard_results[1],"whole-line raw OS clipboard matches native TextEdit, cutting=%s" % cutting)
		check(same_edit(native,owned),"whole-line text, carets and selections match native TextEdit, cutting=%s" % cutting)
		for target: TextEdit in [native,owned]:
			target.set_caret_line(target.get_line_count()-1)
			target.set_caret_column(2)
			target.paste()
		check(same_edit(native,owned),"whole-line Paste matches native TextEdit, cutting=%s" % cutting)
		native.undo()
		owned.undo()
		check(same_edit(native,owned),"whole-line Paste Undo matches native TextEdit, cutting=%s" % cutting)
	for target: TextEdit in [native,owned]:
		target.text = "a\nb"
		target.clear_undo_history()
		target.set_caret_column(1)
		target.add_caret(1,1)
	DisplayServer.clipboard_set("x\ny")
	native.paste()
	owned.paste()
	check(same_edit(native,owned),"multicaret line-distributed Paste matches native TextEdit")
	native.undo()
	owned.undo()
	check(same_edit(native,owned),"multicaret Paste Undo matches native TextEdit")
	DisplayServer.clipboard_set("")
	native.queue_free()
	owned.queue_free()
