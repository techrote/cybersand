class_name CyberTransportProfilePanel
extends Control

var host: Variant
var draft: Dictionary = CyberTransportProfiles.preset(0)
var editor: TextEdit
var source: OptionButton
var target: OptionButton
var scope: OptionButton
var field: OptionButton
var value: SpinBox
var effective_text: Label
var status: Label

func button(parent: Node, text: String, action: Callable) -> void:
	var b: Button = Button.new();b.text=text;b.pressed.connect(action);parent.add_child(b)

func setup(controller: Control) -> void:
	host=controller
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index=100
	var dim: ColorRect=ColorRect.new();dim.color=Color(0.005,0.01,0.02,0.9);add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer=CenterContainer.new();add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer=PanelContainer.new();centre.add_child(panel)
	var style: StyleBoxFlat=StyleBoxFlat.new();style.bg_color=Color(0.035,0.048,0.063,1)
	style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=18;style.content_margin_bottom=18
	panel.add_theme_stylebox_override("panel",style)
	var box: VBoxContainer=VBoxContainer.new();panel.add_child(box)
	var title: Label=Label.new();title.text="TRANSPORT PROFILES / version 1 / explicit restart";box.add_child(title)
	var row: HBoxContainer=HBoxContainer.new();box.add_child(row)
	for i: int in range(3):
		button(row,CyberTransportProfiles.PRESETS[i],func() -> void: draft=CyberTransportProfiles.preset(i);refresh())
	source=OptionButton.new();target=OptionButton.new()
	for id: int in range(81):
		if id==10: continue
		source.add_item("%d %s" % [id,host.material_name(id)],id)
		target.add_item("%d %s" % [id,host.material_name(id)],id)
	source.select(source.get_item_index(3));target.select(target.get_item_index(2))
	source.item_selected.connect(func(_i: int) -> void: refresh_effective())
	target.item_selected.connect(func(_i: int) -> void: refresh_effective())
	var pair_row: HBoxContainer=HBoxContainer.new();box.add_child(pair_row)
	pair_row.add_child(source)
	var arrow: Label=Label.new();arrow.text="→";pair_row.add_child(arrow);pair_row.add_child(target)
	scope=OptionButton.new()
	for text: String in ["Family default","Material adjustment","Directed pair","Symmetric pair"]: scope.add_item(text)
	scope.select(1);pair_row.add_child(scope)
	var edit_row: HBoxContainer=HBoxContainer.new();box.add_child(edit_row)
	field=OptionButton.new()
	for name_text: String in CyberTransportProfiles.FIELDS: field.add_item(name_text)
	field.item_selected.connect(func(_i: int) -> void: refresh_effective())
	edit_row.add_child(field)
	value=SpinBox.new();value.step=1;edit_row.add_child(value)
	button(edit_row,"Set on user copy",edit_value)
	effective_text=Label.new();effective_text.add_theme_font_size_override("font_size",14);box.add_child(effective_text)
	editor=TextEdit.new();editor.custom_minimum_size=Vector2(890,175);editor.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;box.add_child(editor)
	var actions: HBoxContainer=HBoxContainer.new();box.add_child(actions)
	button(actions,"Validate JSON",validate_editor)
	button(actions,"Save user copy",save_copy)
	button(actions,"Load user copy",load_copy)
	button(actions,"Copy JSON",func() -> void:
		if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD): DisplayServer.clipboard_set(editor.text)
	)
	var apply_row: HBoxContainer=HBoxContainer.new();box.add_child(apply_row)
	button(apply_row,"Apply and restart experiment",apply)
	button(apply_row,"Cancel / keep running profile",hide)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(status)
	refresh()
	hide()

func popup_centered() -> void:
	show()

func refresh() -> void:
	editor.text=JSON.stringify(draft,"  ")
	refresh_effective()
	status.text="Protected presets are templates. Editing creates a user copy. JSON profiles are separate from level saves."

func refresh_effective() -> void:
	var data: Dictionary=CyberTransportProfiles.effective(draft,source.get_selected_id(),target.get_selected_id())
	var lines: PackedStringArray=[]
	for i: int in range(8): lines.append("%s = %d   [%s]" % [CyberTransportProfiles.FIELDS[i],int(data["values"][i]),str(data.origins[i])])
	effective_text.text="Effective %s → %s\n%s\n%s" % [host.material_name(source.get_selected_id()),host.material_name(target.get_selected_id()),"\n".join(lines),CyberTransportProfiles.UNITS[field.selected]]
	value.min_value=CyberTransportProfiles.MINIMUM[field.selected]
	value.max_value=CyberTransportProfiles.MAXIMUM[field.selected]
	value.value=int(data["values"][field.selected])

func edit_value() -> void:
	var key: String=CyberTransportProfiles.FIELDS[field.selected]
	var s: int=source.get_selected_id();var t: int=target.get_selected_id()
	var id: int=t if key in ["pickup","packing"] else s
	if key=="permeability" and s in CyberTransportProfiles.POWDERS and t in CyberTransportProfiles.LIQUIDS: id=t
	var candidate: Dictionary=draft.duplicate(true);candidate.name="User copy"
	if scope.selected==0:
		var fam: String=CyberTransportProfiles.family(id)
		if not candidate.families.has(fam): candidate.families[fam]={}
		candidate.families[fam][key]=int(value.value)
	elif scope.selected==1:
		if not candidate.materials.has(str(id)): candidate.materials[str(id)]={}
		candidate.materials[str(id)][key]=int(value.value)
	else:
		var direction: String="symmetric" if scope.selected==3 else "directed"
		var found: bool=false
		for pair: Dictionary in candidate.pairs:
			if int(pair.source)==s and int(pair.target)==t and str(pair.direction)==direction:
				pair["values"][key]=int(value.value);found=true;break
		if not found: candidate.pairs.append({"source":s,"target":t,"direction":direction,"values":{key:int(value.value)}})
	var result: Dictionary=CyberTransportProfiles.resolve(candidate)
	if not result.ok: status.text=str(result.error);return
	draft=candidate;refresh()

func validate_editor() -> void:
	var result: Dictionary=CyberTransportProfiles.parse(editor.text)
	if not result.ok: status.text=str(result.error);return
	draft=result.profile
	refresh_effective()
	status.text="Valid / resolved v1 SHA-256 "+str(result.hash)+" / not yet applied"

func save_copy() -> void:
	var result: Dictionary=CyberTransportProfiles.parse(editor.text)
	if not result.ok: status.text=str(result.error);return
	draft=result.profile;draft.name="User copy"
	var file: FileAccess=FileAccess.open(CyberTransportProfiles.LOCAL_PATH,FileAccess.WRITE)
	if file==null: status.text="Profile save failed; running profile unchanged";return
	file.store_string(JSON.stringify(draft,"  "));refresh();status.text="User copy saved to "+CyberTransportProfiles.LOCAL_PATH

func load_copy() -> void:
	if not FileAccess.file_exists(CyberTransportProfiles.LOCAL_PATH): status.text="No saved user copy";return
	var result: Dictionary=CyberTransportProfiles.parse(FileAccess.get_file_as_string(CyberTransportProfiles.LOCAL_PATH))
	if not result.ok: status.text=str(result.error);return
	draft=result.profile;refresh()

func apply() -> void:
	var result: Dictionary=CyberTransportProfiles.parse(editor.text)
	if not result.ok: status.text=str(result.error);return
	host.tower_apply_profile(result)
	hide()
