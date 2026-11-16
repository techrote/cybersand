extends SceneTree
# Independent rendering/engine review probe. Commands are queued in 17/43-item
# batches without readback or an engine draw boundary between publications.
# Only the final two temporal states at each boundary are synchronously checked;
# this is exact history/lifetime evidence, never a performance measurement.
const Context=preload("res://tests/palette_qualification_context.gd")
const Hybrid=preload("res://scripts/material_upload_hybrid.gd")
const SIZE=Vector2i(513,513)
var failures=[]
var checks=0
var modes={}
var rng=RandomNumberGenerator.new()
var output="user://render-upload-577-queued-history.json"
var source_before={}
func source_hashes()->Dictionary:
	var result={}
	for path in ["res://scripts/material_upload_hybrid.gd","res://shaders/material_upload_copy.gdshader",get_script().resource_path]:
		result[path]=FileAccess.get_sha256(path)
	return result
func _init():
	call_deferred("run")
func expect(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label)
func bytes(image:Image)->PackedByteArray:
	var copy:Image=image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	source_before=source_hashes()
	expect(DisplayServer.get_name()!="headless","actual graphical backend required")
	if not failures.is_empty():
		finish()
		return
	rng.seed=57720261116
	await process_frame
	for channels in [1,2]:
		var fmt=Image.FORMAT_R8 if channels==1 else Image.FORMAT_RG8
		var source=Image.create(SIZE.x,SIZE.y,false,fmt)
		source.fill(Color8(14,83,0,255))
		var h=Hybrid.new()
		expect(h.initialize(source,0,1),"init "+str(channels))
		if not h.initialized: continue
		var serial=0
		var generation=1
		var previous=source.duplicate()
		for batch in range(30):
			var count=43 if batch%7==0 else 17
			for step in range(count):
				previous=source.duplicate()
				serial+=1
				var rect:Rect2i
				var full=false
				if batch%5==4 and step==0:
					generation+=1
					rect=Rect2i(Vector2i.ZERO,SIZE)
					full=true
				elif batch%5==3 and step%5==0:
					rect=Rect2i(0,0,SIZE.x,400)
				elif batch%5==2 and step%3==0:
					rect=Rect2i(0,rng.randi_range(0,SIZE.y-1),SIZE.x,1)
				else:
					var side=rng.randi_range(1,9)
					rect=Rect2i(rng.randi_range(0,SIZE.x-side),rng.randi_range(0,SIZE.y-side),side,side)
				source.fill_rect(rect,Color8(rng.randi_range(0,255),rng.randi_range(0,255),0,255))
				var metadata=PackedInt32Array([rect.position.x,rect.position.y,rect.size.x,rect.size.y,0,rect.size.x*channels])
				var receipt=h.publish(source,metadata,serial,generation,full)
				expect(receipt.accepted,"accepted "+str(channels)+":"+str(serial))
				if receipt.accepted:
					modes[receipt.metrics.mode]=modes.get(receipt.metrics.mode,0)+1
				# Deliberately no readback or await within this batch. These commands
				# must preserve history without relying on a synchronous oracle.
				expect(h._pending_staging_bytes<=h.MAX_PENDING_STAGING_BYTES,"pending bytes bound")
				expect(h._staging_batches.size()<=h.MAX_PENDING_BATCHES,"pending count bound")
			expect(bytes(h.current.get_image())==bytes(source),"queued current "+str(channels)+":"+str(batch))
			expect(bytes(h.previous.get_image())==bytes(previous),"queued previous "+str(channels)+":"+str(batch))
			await process_frame
			expect(h._pooled_bytes<=h.MAX_POOLED_STAGING_BYTES,"pool bytes bound")
			expect(h._source_pool.size()<=h.MAX_POOLED_STAGING_TEXTURES,"pool count bound")
		h.close()
	expect(source_hashes()==source_before,"source bytes unchanged during test")
	finish()
func finish():
	var receipt={"schema":"render-upload-577-independent-queued-history-v1","ok":failures.is_empty(),"checks":checks,"failures":failures,"modes":modes,"context":Context.identity(get_script().resource_path),"source_files_sha256":source_before,"seed":57720261116,"dimensions":[SIZE.x,SIZE.y],"scope":"Independent queued GPU current/previous history; no readback or await within each batch; not performance evidence"}
	var file=FileAccess.open(output,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(receipt,"  ")+"\n")
		file.close()
	else:
		expect(false,"receipt path writable")
	print("RENDER_UPLOAD_577_QUEUED_HISTORY ",JSON.stringify(receipt))
	quit(0 if failures.is_empty() else 1)
