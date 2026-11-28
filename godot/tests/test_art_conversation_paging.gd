extends SceneTree
## Bounded text-widget loading with complete draft/Cancel preservation.
const Editor = preload("res://scripts/art_conversation_editor.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.gui_embed_subwindows = true
	var editor := Editor.new()
	root.add_child(editor)
	await process_frame
	var original := "FIRST original line\n"+"A line of synthetic text for a large conversation.\n".repeat(350000)
	original = original.left(16*1024*1024-8192)+"\nUnicode tail: λ 日本語 🐈\nLAST"
	var live: Array = [{"role":"assistant","content":original,"image_offset":42,"image_log_path":"retained-session-fixture"},
		{"role":"user","content":"ordinary small note"}]
	var began := Time.get_ticks_usec()
	editor.open_history(live)
	var open_usec := Time.get_ticks_usec()-began
	check(editor.visible and editor.page_controls.visible,"large message opens with visible part navigation")
	check(editor.content.text.length() <= Editor.PAGE_CHARACTERS,"visible TextEdit receives at most one bounded part")
	check(editor._pages.size() > 200,"near-limit message is represented completely across parts")
	check("".join(editor._pages)==original,"all Unicode text and final tail survive page construction")
	editor.flush_message()
	check(editor.draft==live and editor.baseline==live,"opening and no-op Apply preserve the exact complete draft")
	check(open_usec < 2000000,"near-limit selection stays below the unchanged two-second gate")
	var first := editor.content.text
	editor.content.text = "EDIT!"+first.substr(5)
	editor._content_changed()
	editor.next_page.pressed.emit()
	check(editor._page_index==1,"Next binding navigates while retaining the first-part edit")
	check(editor.messages.get_item_text(0).contains("EDIT!"),"later parts do not replace the first-line caption")
	editor.previous_page.pressed.emit()
	check(editor.content.text.begins_with("EDIT!"),"Previous binding restores an uncommitted part edit")
	editor._show_page(editor._pages.size()-1)
	editor.content.text += "\nEdited tail"
	editor.flush_message()
	var expected := "EDIT!"+original.substr(5)+"\nEdited tail"
	check(editor.draft[0].content==expected,"Apply projection joins first and last edits with every middle part intact")
	check(editor.draft[0].image_offset==42 and editor.draft[0].image_log_path=="retained-session-fixture","paging retains original image-reference metadata")
	check(live[0].content==original and editor.baseline==live,"draft editing does not mutate live content or immutable baseline")
	editor._select_message(1)
	check(not editor.page_controls.visible and editor.content.text=="ordinary small note","ordinary small notes retain the single editor")
	editor._select_message(0)
	check(editor.content.text.begins_with("EDIT!"),"reselecting the draft uses its complete edited content")
	# A bounded pasted fragment can grow a part. Re-split it without losing the
	# existing suffix or touching the source baseline.
	var pasted := "pasted\n".repeat(15000)
	var before_paste: String = editor.draft[0].content
	var before_pages := editor._pages.size()
	var first_before_paste := editor.content.text
	editor.content.text = first_before_paste+pasted
	editor._content_changed()
	check(editor._pages.size()>before_pages and editor.content.text.length()<=Editor.PAGE_CHARACTERS,"growing a part redistributes its text into bounded visible parts")
	editor.flush_message()
	check(editor.draft[0].content==first_before_paste+pasted+before_paste.substr(first_before_paste.length()),"redistribution preserves the exact inserted text and all following content")
	editor.hide()
	editor.open_history(live)
	check(editor.draft==live and "".join(editor._pages)==original,"Cancel/reopen drops all draft page edits and retains live content")
	editor.content.text = ""
	editor._content_changed()
	var next_beginning := original.substr(Editor.PAGE_CHARACTERS,70).replace("\n"," ").replace("\r"," ")
	check(editor.messages.get_item_text(0).ends_with(next_beginning),"empty first part uses the remaining message's actual beginning for its caption")
	editor.flush_message()
	check(editor.draft[0].content==original.substr(Editor.PAGE_CHARACTERS),"deleting a whole part preserves every following part")
	editor._select_message(1)
	editor.content.text = ""
	editor.flush_message()
	check(editor.draft[1].content=="" and live[1].content=="ordinary small note","empty-note edits remain reversible and preserve live content")
	editor.queue_free()
	await process_frame
	print("ART_CONVERSATION_PAGING_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"characters":original.length(),"open_usec":open_usec,
		"qualification":"Godot dialog/data regression; not a physical clipboard paste acceptance test"}))
	quit(0 if failures.is_empty() else 1)
