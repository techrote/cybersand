extends RefCounted

# Runs against the mounted Workbench and a freshly decoded native document.
# Expected materials come directly from native cells, never Protocol.raster.
const Palette=preload("res://scripts/material_appearance_lut.gd")
const FINAL_LAYERS=["Revisions","Joints","Clearance","Unresolved"]

static func _check(result:Dictionary,key:String,ok:bool,check:Callable,label:String)->void:
	result[key]=bool(result.get(key,true)) and ok
	check.call(ok,label)

static func select_round(panel:Control,index:int)->void:
	panel._round.select(index)
	panel._round.item_selected.emit(index)

static func select_layer(panel:Control,name_value:String)->void:
	var index:int=panel.LAYERS.find(name_value)
	panel._layer.select(index)
	panel._layer.item_selected.emit(index)

static func reset(panel:Control,check:Callable,label:String)->void:
	check.call(panel.document.is_empty() and panel.prepared.is_empty() and panel.proposal.is_empty()
		and panel._preview.texture==null and panel._apply.disabled,label+" retires the complete preview and Apply authority")
	check.call(panel._round.item_count==1 and panel._round.selected==0
		and panel._round.get_item_text(0)=="Final composition" and panel._round.disabled
		and panel._layer.selected==0 and panel._layer.disabled,label+" resets the real inspector controls to final")
	for name_value:String in FINAL_LAYERS:
		check.call(not panel._layer.is_item_disabled(panel.LAYERS.find(name_value)),label+" clears stale "+name_value+" restrictions")
	check.call(panel._inspector.text.begins_with("Generate or inspect saved evidence"),label+" removes stale native cell details")

static func _materials(document:Dictionary,native_round:int)->Array:
	if native_round<0:
		return document.cells if not document.cells.is_empty() else document.input.frame.context
	var proposal:Dictionary=document.rounds[native_round]
	var values:Array=document.input.frame.context.duplicate()
	for owner:String in ["proposed_frame","proposed_mosaic"]:
		var native:Array=proposal[owner].cells
		if native.size()!=values.size():continue
		for at:int in native.size():
			if int(native[at])!=0:values[at]=int(native[at])
	return values

static func _pixels(values:Array)->PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(values.size()*4)
	for at:int in values.size():
		var color:int=Palette.BASE_RGBA8[int(values[at])]
		for channel:int in 3:bytes[at*4+channel]=(color>>(24-channel*8))&255
		bytes[at*4+3]=255 # The material inspector is an opaque cell-ID view.
	return bytes

static func _pick(panel:Control,local:Vector2,button:int=MOUSE_BUTTON_LEFT)->void:
	var size:Vector2=Vector2(panel.prepared.recipe.size)
	var scale:float=minf(panel._preview.size.x/size.x,panel._preview.size.y/size.y)
	var event:=InputEventMouseButton.new();event.pressed=true;event.button_index=button
	event.position=(panel._preview.size-size*scale)/2+local*scale
	panel._preview.gui_input.emit(event)

static func _pick_matches(panel:Control,native_round:int,values:Array)->bool:
	var at:=0
	for index:int in values.size():
		if int(values[index])!=0:at=index;break
	var size:Vector2i=panel.prepared.recipe.size
	var point:=Vector2i(at%size.x,at/size.x)
	_pick(panel,Vector2(point)+Vector2(0.5,0.5))
	var location:Vector2i=point+panel.prepared.recipe.origin
	if native_round>=0:
		var record:Dictionary=panel.document.rounds[native_round]
		var frame:Dictionary=record.proposed_frame;var mosaic:Dictionary=record.proposed_mosaic
		return panel._inspector.text.begins_with("Provisional cell %s · round %d\nFRAME native material %d / part %d / accepted %s\nMOSAIC native material %d / part %d / accepted %s\n" % [
			location,record.number,int(frame.cells[at]) if at<frame.cells.size() else 0,
			int(frame.provenance[at]) if at<frame.provenance.size() else 0,record.frame_accepted,
			int(mosaic.cells[at]) if at<mosaic.cells.size() else 0,int(mosaic.provenance[at]) if at<mosaic.provenance.size() else 0,record.mosaic_accepted])
	if panel.document.cells.is_empty():
		return panel._inspector.text=="No accepted final material architecture. "+str(panel.document.reason)
	var record:Array=panel.document.ledger[at]
	var rule:String=panel.document.rules[int(record[2])] if int(record[2])<panel.document.rules.size() else "none"
	return panel._inspector.text.begins_with("Cell %s · native material ID %d\nOwner %s · structural part %d · rule %s\nFirst round %d · last round %d · accepted revision mask %d\n" % [
		location,panel.document.cells[at],panel.document.owner_names[int(record[0])],record[1],rule,record[3],record[4],record[5]])

static func _native_markers_match(panel:Control,name_value:String)->bool:
	if panel._preview.texture==null:return false
	var points:Array=[]
	if name_value=="Joints":
		for joint:Dictionary in panel.document.joints:points.append_array(joint.get("path",[]))
	else:
		for obligation:Dictionary in panel.document.obligations:
			if obligation.get("state")=="STILL_REQUIRED":points.append(obligation.original)
	var bytes:PackedByteArray=panel._preview.texture.get_image().get_data()
	var rgb:Array=[114,255,140] if name_value=="Joints" else [255,51,76]
	for point:Array in points:
		var offset:int=(int(point[1])*int(panel.prepared.recipe.size.x)+int(point[0]))*4
		for channel:int in 3:
			if bytes[offset+channel]!=rgb[channel]:return false
	return true

static func verify(panel:Control,check:Callable,label:String)->Dictionary:
	var result:Dictionary={"schema":1,"source":panel.document.source,"round_count":panel.document.rounds.size(),"round_indices":[]}
	_check(result,"default_final",panel._round.selected==0 and panel._selected_proposal_round_index()==-1
		and panel._round.item_count==panel.document.rounds.size()+1 and not panel._round.disabled
		and not panel._layer.disabled,check,label+" opens the actual final native composition")
	# Real OptionButton IDs are intentionally unrelated to native round indices.
	for index:int in panel._round.item_count:panel._round.set_item_id(index,100+index*7)
	var selections:Array[int]=[0]
	for index:int in range(1,panel._round.item_count):selections.append(index)
	selections.append(0)
	for selection:int in selections:
		select_round(panel,selection)
		var native_round:=selection-1
		result.round_indices.append(native_round)
		_check(result,"native_cell_picks",panel._selected_proposal_round_index()==native_round,check,
			label+" maps actual dropdown item %d to native round %d" % [selection,native_round])
		for name_value:String in FINAL_LAYERS:
			var index:int=panel.LAYERS.find(name_value)
			_check(result,"final_only_layers",panel._layer.is_item_disabled(index)==(native_round>=0),check,
				label+" keeps "+name_value+" scoped to final evidence at round %d" % native_round)
			if native_round<0:
				select_layer(panel,name_value)
				_check(result,"final_only_layers",panel._layer.selected==index and panel._preview.texture!=null,check,
					label+" selects and renders final "+name_value)
				if name_value in ["Joints","Unresolved"]:
					_check(result,"final_only_layers",_native_markers_match(panel,name_value),check,
						label+" renders the native "+name_value+" evidence at its exact cell positions")
		select_layer(panel,"Materials")
		var values:=_materials(panel.document,native_round)
		_check(result,"native_pixels",panel._preview.texture!=null
			and panel._preview.texture.get_image().get_data()==_pixels(values),check,
			label+" renders every material pixel from native round %d" % native_round)
		_check(result,"native_cell_picks",_pick_matches(panel,native_round,values),check,
			label+" cell pick reports native round %d materials and part provenance" % native_round)
	_check(result,"restored_final",panel._round.selected==0 and panel._selected_proposal_round_index()==-1,check,
		label+" returns the inspector to final composition")
	var prior:String=panel._inspector.text
	var size:Vector2i=panel.prepared.recipe.size
	for outside:Vector2 in [Vector2(-0.25,size.y/2.0),Vector2(size.x/2.0,-0.25),Vector2(size.x+0.25,size.y/2.0),Vector2(size.x/2.0,size.y+0.25)]:
		_pick(panel,outside)
		_check(result,"letterbox_refusal",panel._inspector.text==prior,check,label+" rejects out-of-image cell pick "+str(outside))
	_pick(panel,Vector2(0.5,0.5),MOUSE_BUTTON_RIGHT)
	_check(result,"letterbox_refusal",panel._inspector.text==prior,check,label+" ignores non-primary inspector clicks")
	return result
