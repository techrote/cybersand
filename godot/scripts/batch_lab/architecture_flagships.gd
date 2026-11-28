extends RefCounted
## Original orthographic compositions. Every returned operation belongs to a
## finite <=512-square stage and still requires native preview and approval.
const Compiler = preload("res://scripts/batch_lab/architecture_stage_plan.gd")
const Campaign = preload("res://scripts/batch_lab/architecture_campaign.gd")
const TITLES := {"orbital-fabrication":"Orbital fabrication hall","terraced-arcology":"Terraced service arcology",
	"monumental-viaduct":"Monumental transfer viaduct","biomechanical-vault":"Biomechanical excavated vault"}
const SIZES := {"orbital-fabrication":[1024,1024],"terraced-arcology":[1024,1024],"monumental-viaduct":[1536,768],"biomechanical-vault":[1024,768]}
const PHASES := ["structure","services","detail"]
const EXECUTORS := ["authored-macro-composition","deterministic-service-layout","curated-module-and-context-detail"]

static func families() -> Array:
	return TITLES.keys()

static func extent(family: String) -> Vector2i:
	var size: Array=SIZES.get(family,[1024,1024])
	return Vector2i(int(size[0]),int(size[1]))

static func _box(layer: Array,x: int,y: int,w: int,h: int,material:=58) -> void:
	if w>0 and h>0: layer.append({"shape":"rectangle","x0":x,"y0":y,"x1":x+w-1,"y1":y+h-1,"material":material})

static func _stroke(layer: Array,a: Vector2i,b: Vector2i,width:=3,material:=28) -> void:
	# Face-connected staircase, with exact integer clipping later. No faux tops.
	var distance:=maxi(absi(b.x-a.x),absi(b.y-a.y))
	for step: int in distance+1:
		var point:=Vector2i(roundi(lerpf(a.x,b.x,float(step)/maxi(1,distance))),roundi(lerpf(a.y,b.y,float(step)/maxi(1,distance))))
		_box(layer,point.x,point.y,width,width,material)

static func _frame(layer: Array,x: int,y: int,w: int,h: int,thickness:=4,material:=58) -> void:
	_box(layer,x,y,w,thickness,material); _box(layer,x,y+h-thickness,w,thickness,material)
	_box(layer,x,y+thickness,thickness,h-thickness*2,material); _box(layer,x+w-thickness,y+thickness,thickness,h-thickness*2,material)

static func _truss(layer: Array,x: int,y: int,w: int,h: int,bays: int) -> void:
	_box(layer,x,y,w,6); _box(layer,x,y+h-6,w,6)
	var pitch:=w/bays
	for bay: int in bays:
		var left:=x+bay*pitch
		_box(layer,left,y+6,3,h-12,28)
		_stroke(layer,Vector2i(left,y+6 if bay%2==0 else y+h-9),Vector2i(left+pitch-4,y+h-9 if bay%2==0 else y+6),3,28)
	_box(layer,x+w-3,y+6,3,h-12,28)

static func _windows(layer: Array,x: int,y: int,count: int,w: int,h: int,gap:=14) -> void:
	for index: int in count:
		_frame(layer,x+index*(w+gap),y,w,h,3,28)
		_box(layer,x+index*(w+gap)+3,y+h/2,w-6,2,28)

static func _part(parts: Array,id: String,x: int,y: int,identity: String,transform:="identity",phase:=2) -> void:
	parts.append({"module_id":id,"instance_id":identity,"placement":{"origin":[x,y],"transform":transform},"phase":phase})

static func _hangar(layers: Array,parts: Array,bindings: Array) -> void:
	var s: Array=layers[0]; var p: Array=layers[1]; var d: Array=layers[2]
	_box(s,16,984,992,32); _box(s,32,64,28,920); _box(s,964,64,28,920)
	_truss(s,60,56,904,96,8)
	_box(s,64,310,280,14); _box(s,64,490,280,14); _box(s,64,700,248,14); _box(s,64,836,264,12)
	_box(s,744,232,220,14); _box(s,712,432,252,14); _box(s,768,620,196,14); _box(s,744,836,220,14)
	_box(s,80,152,12,832); _box(s,932,152,12,832)
	_stroke(s,Vector2i(92,570),Vector2i(308,700),8,58)
	_stroke(s,Vector2i(932,704),Vector2i(750,836),8,58)
	_truss(s,344,600,368,72,4)
	_box(s,344,672,368,8,28); _box(s,352,680,352,4,28)
	_box(s,624,684,4,116,28); _box(s,604,800,44,4,28)
	_box(s,604,800,4,22,28); _box(s,644,800,4,22,28)
	_box(s,276,152,4,156,28); _box(s,744,152,4,80,28)
	_frame(s,744,864,188,120,8,58)
	_box(s,768,920,140,4,28); _box(s,812,872,4,104,28)
	_box(p,952,172,4,792,28); _box(p,720,176,236,4,28)
	_box(p,720,176,4,220,28); _box(p,720,392,128,4,28)
	_box(p,104,168,4,620,28); _box(p,104,784,188,4,28)
	_box(p,96,520,196,4,28); _box(p,288,520,4,56,28)
	for y: int in [194,386,572,752]: _frame(p,948,y,16,20,3,28)
	_windows(d,112,178,3,40,36,20); _windows(d,112,354,3,40,40,20)
	_windows(d,772,304,3,42,56,12); _windows(d,792,696,2,44,56,24)
	for x: int in [368,424,480,536,592,648]: _box(d,x,586,28,4,28); _box(d,x+12,590,4,10,28)
	for x: int in range(768,916,24): _box(d,x,942,8,34,28)
	_part(parts,"stepped-foundation",208,968,"hangar-footing", "identity",0)
	_part(parts,"tapered-pier",220,904,"hangar-pier-lower","identity",0)
	_part(parts,"tapered-pier",220,840,"hangar-pier-upper","identity",0)
	bindings.append({"a":{"instance":"hangar-pier-lower","connector":"foot"},"b":{"instance":"hangar-footing","connector":"bearing"}})
	bindings.append({"a":{"instance":"hangar-pier-upper","connector":"foot"},"b":{"instance":"hangar-pier-lower","connector":"head"}})
	_part(parts,"tall-blast-door",128,230,"hangar-door")
	_part(parts,"paired-window-facade",208,246,"hangar-window")
	_part(parts,"machine-housing",128,458,"hangar-machine-west")
	_part(parts,"valve-chamber",800,192,"hangar-valve-east")
	_part(parts,"louvered-shutter-bay",864,384,"hangar-shutter-east")
	_part(parts,"offset-manifold",128,652,"hangar-manifold")
	_part(parts,"ceiling-service-tray",816,816,"hangar-service-tray")
	_part(parts,"framed-vent-grille",848,892,"hangar-vent-bank")
	# Roof-supported gantry, service mezzanines and attached inhabited bays.
	# The two major central voids remain clear; supports sit beside them.
	_box(s,344,152,8,448); _box(s,704,152,8,448)
	_stroke(s,Vector2i(352,152),Vector2i(376,184),7,58)
	_stroke(s,Vector2i(704,152),Vector2i(680,184),7,58)
	_frame(s,580,580,88,20,4,58)
	_box(s,288,232,448,8); _truss(s,288,240,448,28,8)
	_box(s,316,164,8,146); _box(s,316,334,8,156)
	_box(s,108,172,172,6,28); _box(s,108,214,172,4,28); _box(s,108,178,4,36,28)
	_box(s,108,348,172,6,28); _box(s,108,394,172,4,28); _box(s,108,354,4,40,28)
	_box(s,108,398,6,92); _box(s,274,398,6,92)
	_box(s,720,246,8,186); _box(s,756,268,188,8)
	_box(s,104,718,212,8); _box(s,308,726,8,110)
	_box(s,112,28,64,28); _box(s,816,32,96,24)
	_frame(s,296,928,64,56,6,58)
	for y: int in [304,484,694,830]:
		_box(s,28,y,40,8,58); _box(s,956,y,40,8,58)
	for y: int in range(272,420,16): _box(p,916,y,16,3,28)
	_box(p,916,264,3,168,28); _box(p,928,264,3,168,28)
	for x: int in range(296,728,32): _box(p,x,212,3,20,28)
	_box(p,288,210,448,3,28)
	_frame(d,118,32,52,18,2,28); _frame(d,824,36,80,16,2,28)
	for x: int in range(120,168,8): _box(d,x,36,2,10,28)
	_box(d,194,458,110,6,28); _box(d,198,464,4,26,28); _box(d,298,464,4,26,28)
	for x: int in range(204,288,20): _frame(d,x,438,14,20,2,28)
	_frame(d,300,938,52,36,3,28)
	for y: int in range(944,970,6): _box(d,305,y,42,2,28)
	_part(parts,"instrument-rack",864,564,"hangar-maintenance-rack")
	_part(parts,"ceiling-service-tray",752,600,"hangar-upper-tray")
	# Equipment feet meet observed body faces and their actual floor/service bar.
	# Module Empty margins remain transparent; these are explicit composition
	# supports, not modifications to the reusable source part's own geometry.
	_box(s,152,696,4,4,28)
	for x: int in [812,833]: _box(s,x,224,3,8,28)
	for x: int in [848,893]: _box(s,x,916,3,4,28)
	for x: int in [772,826,880]: _box(s,x,276,3,28,28)
	_box(s,792,634,3,62,28)

static func _arcology(layers: Array,parts: Array,_bindings: Array) -> void:
	var s: Array=layers[0]; var p: Array=layers[1]; var d: Array=layers[2]
	_box(s,16,1000,992,24)
	_box(s,64,184,16,816); _box(s,272,184,16,816)
	for y: int in [280,440,600,760,920]: _box(s,64,y,224,12)
	_box(s,64,184,224,12); _truss(s,80,196,192,52,4)
	_box(s,384,96,16,904); _box(s,688,184,16,816)
	for y: int in [248,408,568,728,888]:
		_box(s,384,y,128,12); _box(s,560,y,144,12)
	_box(s,384,96,128,12); _box(s,560,184,144,12)
	_box(s,496,96,16,792); _box(s,560,184,12,704)
	_box(s,736,356,16,644); _box(s,944,276,16,724)
	for y: int in [356,512,668,824,980]: _box(s,736,y,224,12)
	_box(s,816,276,144,12); _box(s,816,276,12,80)
	_box(s,288,424,96,10); _box(s,288,744,96,10)
	_box(s,704,496,112,10); _box(s,704,808,48,10)
	_truss(s,288,754,96,32,3); _truss(s,704,506,112,38,4)
	_box(s,80,144,96,10); _box(s,80,154,12,30)
	_box(s,400,56,96,8); _box(s,408,64,6,32); _box(s,480,64,6,32)
	for x: int in [416,448,480]: _box(s,x,24,3,32,28)
	_box(p,296,208,4,500,28); _box(p,296,208,64,4,28); _box(p,356,208,4,224,28)
	_box(p,720,392,4,404,28); _box(p,704,392,164,4,28)
	_box(p,614,212,4,636,28)
	_box(p,96,936,160,3,28)
	for y: int in [304,464,624,784]:
		_windows(d,96,y,3,40,52,14)
		if y!=784: _box(d,80,y+68,192,4,28)
		else: _box(d,80,y+68,96,4,28); _box(d,224,y+68,48,4,28)
	for y: int in [132,292,452,612,772]: _windows(d,416,y,2,28,48,16)
	for y: int in [220,380,540,700]: _windows(d,608,y,2,28,52,16)
	for y: int in [560,716,872]: _windows(d,768,y,3,40,52,16)
	for y: int in [328,488,648,808]:
		_box(d,248,y,40,4,28); _stroke(d,Vector2i(272,y+24),Vector2i(250,y+4),3,28)
	for y: int in [344,504,664,824]: _frame(d,508,y,8,16,2,28); _frame(d,556,y,8,16,2,28)
	_part(parts,"paired-window-facade",96,536,"arcology-west-window")
	_part(parts,"tall-blast-door",176,840,"arcology-west-entry")
	_part(parts,"narrow-pressure-bulkhead",424,824,"arcology-central-entry")
	_part(parts,"louvered-shutter-bay",864,464,"arcology-east-shutter")
	_part(parts,"machine-housing",848,792,"arcology-pump")
	_part(parts,"offset-half-landing",304,712,"arcology-offset-landing")
	_part(parts,"ceiling-service-tray",832,336,"arcology-tray")
	_part(parts,"valve-chamber",592,848,"arcology-valve")
	# Unlike bridge landings cut real openings in the wall silhouettes. These
	# are authored geometry, not a claim of a functional elevator or staircase.
	for opening: Array in [[272,376,16,48],[384,376,16,48],[272,696,16,48],[384,696,16,48],
		[688,448,16,48],[736,448,16,48],[688,760,16,48],[736,760,16,48]]:
		_box(s,opening[0],opening[1],opening[2],opening[3],0)
	_box(s,80,440,192,12,0) # A double-height west assembly room.
	_box(s,288,280,96,8); _box(s,272,224,16,56,0); _box(s,384,216,16,64,0)
	for index: int in 8:
		_box(s,296+index*10,276-index*4,14,4)
	for index: int in 12:
		_box(s,296+index*6,600-index*12,10,4)
	_stroke(s,Vector2i(294,608),Vector2i(370,458),5,58)
	_box(s,288,600,96,10); _box(s,272,552,16,48,0); _box(s,384,552,16,48,0)
	_box(s,808,308,8,48); _box(s,752,308,64,8)
	_box(s,752,316,8,40); _box(s,800,848,144,8)
	_box(s,800,856,8,124)
	for y: int in [248,408,568,728,888]:
		_box(s,496,y-6,24,6); _box(s,552,y-6,20,6)
		_box(s,496,y-54,16,48,0); _box(s,560,y-54,12,48,0)
	# The authored doorway cuts interrupted both original central piers. This
	# narrow internal service column bypasses them beside the window edges and
	# outside the protected central shaft, carrying the roof and four landings.
	_box(s,488,96,8,792,58)
	for y: int in [280,600,760]:
		if y==600: _box(p,80,y-18,16,3,28); _box(p,160,y-18,112,3,28)
		else: _box(p,80,y-18,192,3,28)
		for x: int in range(88,268,28):
			if y!=600 or x<96 or x>=160: _box(p,x,y-15,2,15,28)
	for y: int in range(516,800,20): _box(p,708,y,20,3,28)
	_box(p,708,512,3,296,28); _box(p,726,512,3,296,28)
	for y: int in [328,488,648,808]:
		_box(p,284,y,4,36,28); _box(p,288,y+32,36,4,28)
	_box(p,96,126,72,3,28)
	for x: int in [100,124,148,164]: _box(p,x,129,2,15,28)
	# Attached equipment and wall panels give each neighborhood a different use.
	_frame(d,96,400,96,80,4,28); _box(d,100,436,88,3,28)
	_box(d,96,480,6,120,28); _box(d,186,480,6,120,28)
	for x: int in range(104,180,12): _box(d,x,408,3,24,28)
	_frame(d,600,288,64,64,3,28); _frame(d,600,608,64,48,3,28)
	_box(d,768,636,112,6,28); _box(d,772,642,4,26,28); _box(d,874,642,4,26,28)
	_frame(d,816,912,104,48,3,28)
	for y: int in range(920,956,8): _box(d,824,y,88,2,28)

static func _viaduct(layers: Array,parts: Array,_bindings: Array) -> void:
	var s: Array=layers[0]; var p: Array=layers[1]; var d: Array=layers[2]
	_box(s,0,744,1536,24)
	_box(s,16,192,1504,24); _box(s,16,180,1504,4,28)
	for x: int in range(24,1512,48): _box(s,x,184,3,8,28)
	var abutments:=[16,320,704,1088,1496]
	for index: int in abutments.size():
		var x: int=abutments[index]
		_box(s,x,216,24,480); _box(s,maxi(0,x-12),696,48,24); _box(s,maxi(0,x-24),720,72,24)
	for span: int in 4:
		var left: int=abutments[span]+24; var right: int=abutments[span+1]
		var middle:=float(left+right-1)*0.5; var half:=float(right-left)*0.5
		for x: int in range(left,right):
			var t:=absf(float(x)-middle)/half
			var underside:=240+roundi(224.0*t*t)
			_box(s,x,216,1,underside-216,58)
			_box(s,x,underside,1,10,28)
		for x: int in range(left+24,right-24,48):
			var t:=absf(float(x)-middle)/half
			var bottom:=226+roundi(190.0*t*t)
			_box(d,x,224,3,maxi(4,bottom-224),28)
	_box(s,344,692,360,12); _box(s,728,596,360,12)
	_truss(s,344,704,360,32,9); _truss(s,728,608,360,48,9)
	_box(s,40,540,240,12); _box(s,1152,560,344,12)
	_stroke(s,Vector2i(40,616),Vector2i(272,552),6,58)
	_stroke(s,Vector2i(1488,640),Vector2i(1160,572),6,58)
	_box(p,48,492,1432,4,28); _box(p,48,492,4,40,28); _box(p,1476,492,4,60,28)
	for x: int in [308,692,1076]: _box(p,x,256,4,236,28); _frame(p,x-4,468,12,16,3,28)
	_box(p,744,552,304,4,28); _box(p,744,552,4,36,28)
	for x: int in range(56,1500,72): _box(d,x,164,4,16,28)
	for x: int in [92,244,420,596,812,980,1180,1360]: _frame(d,x,200,32,8,2,28)
	_box(s,64,180,64,12); _box(s,192,180,80,12); _box(s,1176,180,64,12)
	_part(parts,"tall-blast-door",72,100,"viaduct-west-entry")
	_part(parts,"paired-window-facade",200,116,"viaduct-west-station")
	_part(parts,"louvered-shutter-bay",1184,132,"viaduct-east-station")
	_part(parts,"valve-chamber",784,556,"viaduct-underworks-valve")
	_part(parts,"machine-housing",912,564,"viaduct-underworks-machine")
	_part(parts,"pipe-tee",1200,528,"viaduct-service-junction")
	_part(parts,"service-doorway",240,492,"viaduct-underworks-door")
	parts[-1].placement["palette"]={"structure":28}
	_part(parts,"ceiling-service-tray",1280,540,"viaduct-underworks-tray")
	# Station envelopes, a bearing rhythm, and a continuous service gallery
	# establish why this viaduct has unlike ends and occupied underworks.
	_frame(s,56,76,240,104,6,58); _box(s,72,100,48,80,0)
	_frame(s,1168,104,248,76,6,58); _box(s,1184,132,48,48,0)
	_box(s,400,132,224,48); _box(s,408,140,208,32,0)
	_box(s,864,140,152,40); _box(s,872,148,136,24,0)
	_box(s,40,504,200,8,58); _box(s,272,504,1224,8,58)
	# Explicit route clearance below this gallery is retained independently.
	for x: int in [304,688,1072]: _box(s,x,512,8,28,58)
	_box(s,424,380,232,8); _box(s,424,288,4,92,28); _box(s,652,288,4,92,28)
	for index: int in 12: _box(s,1160+index*8,552-index*4,12,4)
	for index: int in 16: _box(s,744+index*7,588-index*5,12,4)
	for x: int in [16,320,704,1088,1496]:
		_box(d,x+4,280,16,6,28); _box(d,x+4,400,16,6,28); _box(d,x+4,668,16,6,28)
	_box(p,40,476,1456,3,28)
	for x: int in range(56,1496,40):
		if x<240 or x>=272: _box(p,x,479,2,25,28)
	_box(p,424,360,232,3,28)
	for x: int in range(432,656,32): _box(p,x,363,2,17,28)
	_windows(d,136,100,1,40,48); _windows(d,1280,124,2,40,40,12)
	for x: int in range(416,616,28): _box(d,x,140,4,32,28)
	for x: int in range(880,1008,24): _box(d,x,148,3,24,28)
	_box(s,136,82,3,18,28) # Window suspension from the station's actual lintel.
	_box(s,744,592,12,4,58) # Lower stair tread joins its service-gallery floor.
	var arch_supports:=[16,320,704,1088,1496]
	for span: int in 4:
		var left: int=arch_supports[span]+24; var right: int=arch_supports[span+1]
		var middle:=float(left+right-1)*0.5; var half:=float(right-left)*0.5
		for x: int in range(left+4,right-4,4):
			var t:=absf(float(x)-middle)/half
			var y:=218+roundi(224.0*t*t)
			_box(d,x,y,4,3,28)

static func _biomechanical(layers: Array,parts: Array,_bindings: Array) -> void:
	var s: Array=layers[0]; var p: Array=layers[1]; var d: Array=layers[2]
	for x: int in range(0,1024,4):
		var ceiling:=48+roundi(22.0*(1.0+sin(float(x)*0.021)))+roundi(12.0*sin(float(x)*0.057))
		var floor_y:=704+roundi(12.0*sin(float(x)*0.017))
		_box(s,x,0,4,maxi(24,ceiling),58); _box(s,x,floor_y,4,768-floor_y,58)
	for y: int in range(64,720,4):
		var left:=32+roundi(10.0*(1.0+sin(float(y)*0.031)))
		var right:=968-roundi(12.0*(1.0+sin(float(y)*0.027)))
		_box(s,0,y,left,4,58); _box(s,right,y,1024-right,4,58)
	_box(s,64,664,896,12); _box(s,64,676,12,44); _box(s,936,676,12,44)
	for x: int in [192,824]: _box(s,x,600,16,64)
	for x: int in range(192,840,2):
		var t:=absf(float(x)-515.0)/323.0
		var y:=180+roundi(420.0*t*t)
		_box(s,x,y,3,9,28)
	for rib: int in 5:
		var x:=240+rib*136
		var t:=absf(float(x)-515.0)/323.0
		var top:=180+roundi(420.0*t*t)
		_stroke(s,Vector2i(x,top),Vector2i(x-28 if x<512 else x+28,top+64),5,58)
	_frame(s,80,432,224,12,4,58); _box(s,80,444,12,220)
	_box(s,80,520,224,8); _box(s,80,600,224,12)
	_box(s,736,400,208,12); _box(s,736,560,208,12); _box(s,928,412,12,252)
	_stroke(s,Vector2i(928,600),Vector2i(744,564),6,58)
	_box(p,96,128,4,284,28); _box(p,96,128,180,4,28)
	_box(p,904,116,4,264,28); _box(p,744,116,164,4,28)
	_box(p,744,116,4,56,28)
	for side: int in [0,1]:
		var root_x:=120 if side==0 else 872
		for branch: int in 5:
			var y:=208+branch*42
			_stroke(d,Vector2i(root_x,y+56),Vector2i(root_x+64 if side==0 else root_x-64,y),4,7)
			_stroke(d,Vector2i(root_x+32 if side==0 else root_x-32,y+28),Vector2i(root_x+76 if side==0 else root_x-76,y+20),3,7)
	for x: int in [336,432,528,624]: _frame(d,x,640,40,24,3,28)
	for x: int in [80,904]: _frame(d,x,456,24,48,4,28)
	_part(parts,"offset-manifold",144,472,"biomech-manifold")
	_part(parts,"valve-chamber",864,360,"biomech-valve")
	_part(parts,"machine-housing",848,528,"biomech-machine")
	_part(parts,"tall-blast-door",128,520,"biomech-west-entrance")
	_part(parts,"louvered-shutter-bay",224,552,"biomech-shutter")
	_part(parts,"narrow-pressure-bulkhead",744,496,"biomech-east-bulkhead")
	_part(parts,"ceiling-service-tray",848,644,"biomech-service-tray")
	# A second connected rib, wall-grown branches and inhabited rock brackets
	# make the skeleton and services visibly attached, while retaining the void.
	_box(s,116,252,8,180,7); _box(s,872,252,7,108,7); _box(s,872,356,18,4,7); _box(s,872,412,8,24,7)
	_stroke(s,Vector2i(80,476),Vector2i(40,500),8,58)
	_stroke(s,Vector2i(932,456),Vector2i(970,480),8,58)
	_box(s,292,444,12,76); _box(s,736,412,12,84)
	_box(s,92,444,212,8); _box(s,748,412,180,8)
	for x: int in range(192,840,2):
		var t:=absf(float(x)-515.0)/323.0
		var y:=244+roundi(420.0*t*t)
		_box(s,x,y,3,5,58)
	for x: int in range(208,824,56):
		var t:=absf(float(x)-515.0)/323.0
		var y:=188+roundi(420.0*t*t)
		_box(s,x,y,4,56,58)
	# Attached side alcoves vary geological and constructed scale.
	_box(s,44,164,84,12); _box(s,32,316,68,16)
	_box(s,912,188,64,16); _box(s,908,492,68,12)
	_box(s,92,608,64,56); _box(s,100,616,48,40,0)
	_box(s,856,584,72,48); _box(s,864,592,56,32,0)
	for x: int in [876,897]: _box(s,x,392,3,8,28)
	_box(s,168,516,4,4,28)
	_box(p,96,452,180,4,28); _box(p,272,132,4,320,28)
	_box(p,744,172,164,4,28); _box(p,748,172,4,168,28)
	_box(p,748,344,52,4,28)
	for y: int in [192,240,288,336,384]:
		_frame(d,88,y,20,16,3,28)
	for y: int in [208,256,304]: _frame(d,896,y,20,16,3,28)
	_frame(d,212,460,64,48,3,28)
	for x: int in range(220,272,16): _box(d,x,463,3,42,28)
	_frame(d,776,448,128,32,3,28); _box(d,904,448,24,3,28)
	for x: int in range(784,900,20): _box(d,x,451,3,26,28)

static func clearances(family: String) -> Array:
	match family:
		"orbital-fabrication": return [[384,888,320,96],[376,336,232,240]]
		"terraced-arcology": return [[408,912,272,88],[520,128,32,752]]
		"monumental-viaduct": return [[384,624,320,68]]
		"biomechanical-vault": return [[384,576,320,64]]
	return []

static func witness(family: String) -> Dictionary:
	var values:={
		"orbital-fabrication":{"spawn":[400,928],"goal":[680,928],"corridor":[384,888,320,96],"landing_pad":[648,984,64,16]},
		"terraced-arcology":{"spawn":[424,952],"goal":[656,952],"corridor":[408,912,272,88],"landing_pad":[624,1000,64,16]},
		"monumental-viaduct":{"spawn":[400,652],"goal":[680,652],"corridor":[384,624,320,68],"landing_pad":[648,692,56,12]},
		"biomechanical-vault":{"spawn":[400,600],"goal":[680,600],"corridor":[384,576,320,64],"landing_pad":[648,664,64,12]}}
	var answer: Dictionary=values.get(family,{}).duplicate(true)
	answer.merge({"family":family,"model":"midge","saved_start":"m67-"+family,"tick_budget":2400,
		"scope":"Authored trial targets only. Actor admission, controlled movement and contact require a separately recorded actual Workbench trial."})
	return answer

static func build(family: String,library: RefCounted,seed:=37901) -> Dictionary:
	if family not in TITLES or library==null: return {"ok":false,"reason":"Choose a named flagship and load its versioned module library."}
	var layers: Array=[[],[],[]]; var parts: Array=[]; var bindings: Array=[]
	match family:
		"orbital-fabrication": _hangar(layers,parts,bindings)
		"terraced-arcology": _arcology(layers,parts,bindings)
		"monumental-viaduct": _viaduct(layers,parts,bindings)
		"biomechanical-vault": _biomechanical(layers,parts,bindings)
	var size:=extent(family)
	var regions: Array[Rect2i]=[]
	for y: int in range(0,size.y,512):
		for x: int in range(0,size.x,512): regions.append(Rect2i(x,y,mini(512,size.x-x),mini(512,size.y-y)))
	var placed_ids: Array=[]
	var last_by_region: Dictionary={}
	var nodes: Array=[]; var stages: Array=[]; var module_count:=0; var native_limit:=0; var raster_limit:=0
	for phase: int in 3:
		nodes.append({"id":family+"-"+PHASES[phase],"parent_id":"","title":["Primary spatial structure","Services and circulation","Parts and architectural detail"][phase],
			"kind":"group","region":[0,0,size.x,size.y],"depends_on":[]})
		for index: int in regions.size():
			var region: Rect2i=regions[index]
			var identity: String=family+"-"+PHASES[phase]+"-"+str(index+1)
			var stage:=Compiler.stage_defaults(identity,region)
			stage["title"]=PHASES[phase].capitalize()+" · district "+str(index+1)
			stage.intent=TITLES[family]+": "+str(PHASES[phase])+" within an exact native district."
			stage.materials=[0,7,28,58]
			stage.budget.max_checked_cells=region.get_area() if phase==0 else maxi(1,region.get_area()/3)
			stage.expected_effects="Finite orthographic "+PHASES[phase]+" geometry with preserved macro voids and route clearances. Host projection supplies actual cost."
			stage["executor_kind"]=EXECUTORS[phase]
			if last_by_region.has(index): stage.depends_on=[last_by_region[index]]
			var scan:=0
			for operation: Dictionary in layers[phase]:
				var original:=Rect2i(int(operation.x0),int(operation.y0),int(operation.x1)-int(operation.x0)+1,int(operation.y1)-int(operation.y0)+1)
				var clipped:=region.intersection(original)
				if clipped.get_area()<1: continue
				_box(stage.operations,clipped.position.x,clipped.position.y,clipped.size.x,clipped.size.y,int(operation.material))
				scan+=clipped.get_area()
			for clearance: Array in clearances(family):
				var clipped:=region.intersection(Compiler.rect(clearance))
				if clipped.get_area()>0: stage.clearances.append(Compiler.rect_array(clipped))
			var instances: Array=[]
			for selection: Dictionary in parts:
				if int(selection.phase)!=phase: continue
				var module: Dictionary=library.get_module(selection.module_id)
				if module.is_empty(): return {"ok":false,"reason":"Flagship requires curated module: "+str(selection.module_id)}
				var box:=Rect2i(int(selection.placement.origin[0]),int(selection.placement.origin[1]),int(module.extent[0]),int(module.extent[1]))
				if not region.encloses(box): continue
				stage.modules.append({"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":selection.instance_id,"placement":selection.placement.duplicate(true)})
				instances.append(selection.instance_id); placed_ids.append(selection.instance_id); module_count+=1
				scan+=box.get_area()*3
			stage["module_bindings"]=[]
			for binding: Dictionary in bindings:
				if binding.a.instance in instances and binding.b.instance in instances: stage.module_bindings.append(binding.duplicate(true))
			if stage.operations.is_empty() and stage.modules.is_empty(): continue
			last_by_region[index]=identity
			# The input envelope and raster ceiling are host-validated again; this
			# conservative authored ceiling grants no additional material authority.
			var ceiling:=mini(Compiler.MAX_RASTER_CANDIDATES,maxi(1,scan+4096))
			native_limit+=int(stage.budget.max_checked_cells); raster_limit+=ceiling
			stages.append(stage)
			nodes.append({"id":identity,"parent_id":family+"-"+PHASES[phase],"title":stage.title,"kind":PHASES[phase],
				"region":stage.region,"depends_on":[],"executor":EXECUTORS[phase],"raster_candidates_limit":ceiling,"stage":stage,
				"scopes":{"write":[stage.region],"clearances":stage.clearances.duplicate(true),"guards":[],"connectors":[]}})
	var transitions: Array=parts.filter(func(value: Dictionary)->bool: return value.instance_id not in placed_ids)
	if not transitions.is_empty():
		nodes.append({"id":family+"-transitions","parent_id":"","title":"Parts across district boundaries","kind":"group","region":[0,0,size.x,size.y],"depends_on":[]})
	for selection: Dictionary in transitions:
		var module: Dictionary=library.get_module(selection.module_id)
		var origin:=Vector2i(int(selection.placement.origin[0]),int(selection.placement.origin[1]))
		var bounds:=Rect2i(origin,Vector2i(int(module.extent[0]),int(module.extent[1])))
		var region:=bounds.grow(8).intersection(Rect2i(Vector2i.ZERO,size))
		var identity:=family+"-transition-"+str(transitions.find(selection)+1)
		var stage:=Compiler.stage_defaults(identity,region)
		stage["title"]="Boundary assembly · "+str(module.name)
		stage.intent="Place one complete architectural part across the adjacent construction districts."
		stage.materials=[0,7,28,58]; stage.budget.max_checked_cells=region.get_area()
		stage.modules=[{"module_id":module.id,"module_sha256":module.content_sha256,"instance_id":selection.instance_id,"placement":selection.placement.duplicate(true)}]
		for index: int in regions.size():
			if region.intersects(regions[index]) and last_by_region.has(index): stage.depends_on.append(last_by_region[index])
		for raw: Array in clearances(family):
			var clipped:=region.intersection(Compiler.rect(raw))
			if clipped.get_area()>0: stage.clearances.append(Compiler.rect_array(clipped))
		var ceiling:=mini(Compiler.MAX_RASTER_CANDIDATES,bounds.get_area()*3+4096)
		native_limit+=region.get_area(); raster_limit+=ceiling; module_count+=1
		nodes.append({"id":identity,"parent_id":family+"-transitions","title":stage.title,"kind":"modules","region":stage.region,"depends_on":[],
			"executor":"curated-district-transition","raster_candidates_limit":ceiling,"stage":stage,"scopes":{"write":[stage.region],"guards":[],"clearances":stage.clearances.duplicate(true),"connectors":[]}})
		stages.append(stage)

	var graph:={"format":Campaign.FORMAT,"id":"flagship-"+family+"-"+str(seed),"title":TITLES[family],
		"intent":"Construct an original large side-elevation environment through finite native structure, service and detail tasks, preserving explicit play-space.",
		"region":[0,0,size.x,size.y],"budget":{"native_checks":native_limit,"raster_candidates":raster_limit,"max_retries_per_job":2},"nodes":nodes,
		"provenance":{"kind":"original-hand-authored-hierarchical-composition","seed":seed,"real_model_calls":0,"module_count":module_count,
			"source_status":"Unexecuted recipe until exact native receipts and current readback are retained.","rendering":"True orthographic material-grid side elevation; no perspective surfaces."}}
	var checked:=Campaign.validate(graph)
	if not checked.ok: return checked
	return {"ok":true,"campaign":graph,"plan":checked.native_plan,"module_count":module_count,"witness":witness(family),"clearances":clearances(family)}
