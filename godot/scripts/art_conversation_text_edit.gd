extends TextEdit
# Clipboard rules adapted from Godot Engine TextEdit at the pinned 4.7 runtime:
# https://github.com/godotengine/godot/blob/5b4e0cb0f/scene/gui/text_edit.cpp
# Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
## Clipboard-only override: the editor can page a large insertion before TextEdit
## shapes it. Godot 4.7's virtual _paste has no callable native fallback, so these
## clipboard operations preserve its selection, whole-line and grouped-Undo rules
## using public native edit methods. Keyboard and context-menu routing stay native.
var intercept_paste: Callable
var _copied_line := ""

func _valid_caret(index: int) -> bool:
	return index >= -1 and index < get_caret_count()

func _read_clipboard(primary: bool = false) -> String:
	return DisplayServer.clipboard_get_primary() if primary else DisplayServer.clipboard_get()

func _write_clipboard(value: String) -> void:
	DisplayServer.clipboard_set(value)

func _supports_primary_clipboard() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD_PRIMARY)

func _primary_caret_position() -> Vector2i:
	return get_line_column_at_pos(get_local_mouse_pos())

func _copy(caret_index: int) -> void:
	if not _valid_caret(caret_index): return
	if has_selection(caret_index):
		_write_clipboard(get_selected_text(caret_index))
		_copied_line = ""
		return
	if not empty_selection_clipboard_enabled: return
	var ranges: Array[Vector2i] = get_line_ranges_from_carets(false,true) if caret_index == -1 else [Vector2i(get_caret_line(caret_index),get_caret_line(caret_index))]
	var lines := PackedStringArray()
	for span: Vector2i in ranges:
		for line: int in range(span.x,span.y+1):
			lines.append(get_line(line)+"\n")
	var value := "".join(lines)
	_write_clipboard(value)
	_copied_line = value if get_caret_count() == 1 else ""

func _cut(caret_index: int) -> void:
	if not _valid_caret(caret_index): return
	_copy(caret_index)
	if not editable: return
	if has_selection(caret_index):
		delete_selection(caret_index)
		return
	if not empty_selection_clipboard_enabled: return
	begin_complex_operation()
	begin_multicaret_edit()
	var ranges: Array[Vector2i] = get_line_ranges_from_carets() if caret_index == -1 else [Vector2i(get_caret_line(caret_index),get_caret_line(caret_index))]
	var line_offset := 0
	for span: Vector2i in ranges:
		remove_line_at(span.y+line_offset)
		if span.x != span.y:
			remove_text(span.x+line_offset,0,span.y+line_offset,0)
		line_offset += span.x-span.y-1
	end_multicaret_edit()
	end_complex_operation()

func _paste(caret_index: int) -> void:
	if not editable or not _valid_caret(caret_index): return
	var value := _read_clipboard()
	if value.is_empty(): return
	var whole_line := get_caret_count() == 1 and not has_selection(0) and not _copied_line.is_empty() and _copied_line == value.replace("\r","")
	# Count first: splitting millions of clipboard lines is unnecessary unless
	# native Paste would distribute exactly one line to each of several carets.
	var one_line_each := caret_index == -1 and get_caret_count() > 1 and value.count("\n")+1 == get_caret_count()
	if intercept_paste.is_valid() and intercept_paste.call(value,caret_index,whole_line,one_line_each): return
	if whole_line:
		insert_text(value,get_caret_line(),0)
		adjust_viewport_to_caret(0)
		return
	var lines := value.split("\n") if one_line_each else PackedStringArray()
	begin_complex_operation()
	begin_multicaret_edit()
	var carets := get_sorted_carets()
	for position: int in range(carets.size()):
		var index := carets[position]
		if caret_index != -1 and caret_index != index: continue
		if has_selection(index): delete_selection(index)
		insert_text_at_caret(lines[position] if one_line_each else value,index)
	end_multicaret_edit()
	end_complex_operation()

func _paste_primary_clipboard(caret_index: int) -> void:
	if not editable or not _valid_caret(caret_index) or not _supports_primary_clipboard(): return
	# Capture before deselection: on Linux selection changes can update the
	# primary clipboard. Middle-click follows the native mouse-position rule.
	var value := _read_clipboard(true)
	if get_caret_count() == 1:
		var position := _primary_caret_position()
		deselect()
		set_caret_line(position.y,true,false,-1)
		set_caret_column(position.x)
	if not value.is_empty():
		if not intercept_paste.is_valid() or not intercept_paste.call(value,-1,false,false):
			insert_text_at_caret(value)
	grab_focus()
