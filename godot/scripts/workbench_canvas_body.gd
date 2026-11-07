extends RefCounted

# Passive exact geometry for authored starts and admitted freed-object shapes.
# Native tuple custody remains in World; this representation is not a flyer.
const MODEL := "canvas_body"
const MAX_RECTANGLES: int = 64 # Shared native proxy budget, not 64 per scene slot.

static func error(value: Variant) -> String:
	if not value is Dictionary or value.size()!=(3 if value.has("appearance") else 2) or not value.has_all(["name","rectangles"]):
		return "Invalid canvas body fields."
	if value.has("appearance"):
		var a: Variant=value.appearance
		if not a is Dictionary or a.size()!=2 or not a.has_all(["material","origin"]) or not (a.material is int or a.material is float) or a.material!=43:
			return "Invalid carried RedBrick appearance."
		if not a.origin is Array or a.origin.size()!=2: return "Invalid appearance origin."
		for word: Variant in a.origin:
			if not (word is int or word is float) or not is_finite(float(word)) or word!=floor(float(word)) or word<0 or word>2047:
				return "Invalid appearance origin."
	if not value.name is String or value.name.is_empty() or value.name.length()>48:
		return "Invalid canvas body name."
	if not value.rectangles is Array or value.rectangles.is_empty() or value.rectangles.size()>MAX_RECTANGLES:
		return "Canvas bodies require one to 64 rectangles within the shared 64-proxy budget."
	var rectangles: Array[Rect2]=[]
	var area: float=0.0
	for r: Variant in value.rectangles:
		if not r is Array or r.size()!=4:return "Invalid canvas rectangle."
		for word: Variant in r:
			if not (word is int or word is float) or not is_finite(float(word)) or word!=floor(float(word)) or word<0 or word>128:
				return "Canvas rectangles require bounded integer cells."
		if r[2]<1 or r[3]<1 or r[0]+r[2]>128 or r[1]+r[3]>128:return "Canvas rectangle outside 128-cell authoring bounds."
		if value.has("appearance") and (value.appearance.origin[0]+r[0]+r[2]>2048 or value.appearance.origin[1]+r[1]+r[3]>2048): return "Appearance outside source canvas."
		var rect:=Rect2(r[0],r[1],r[2],r[3])
		for old: Rect2 in rectangles:
			if rect.intersects(old):return "Canvas rectangles overlap."
		rectangles.append(rect);area+=rect.get_area()
	if area>4096:return "Canvas body exceeds 4096 unit cells."
	return ""

static func digest(value: Dictionary) -> String:
	var canonical: Array=[]
	for r: Array in value.rectangles:canonical.append(Array(PackedInt32Array(r)))
	var record: Dictionary={"name":value.name,"rectangles":canonical}
	if value.has("appearance"):
		record["appearance"]={"material":43,"origin":Array(PackedInt32Array(value.appearance.origin))}
	return JSON.stringify(record,"",true,true).sha256_text()

# One small immutable material image per body, never per collider/frame.
# The exact union supplies holes; source coordinates keep the brick pattern.
static func visual(value: Dictionary) -> Dictionary:
	if not value.has("appearance") or not error(value).is_empty(): return {}
	var bounds:=Rect2i()
	var first: bool=true
	for r: Array in value.rectangles:
		var box:=Rect2i(r[0],r[1],r[2],r[3])
		bounds=box if first else bounds.merge(box);first=false
	var padded: Rect2i=bounds.grow(1)
	var image:=Image.create(padded.size.x,padded.size.y,false,Image.FORMAT_RG8)
	image.fill(Color(0,0,0,1))
	for r: Array in value.rectangles:
		image.fill_rect(Rect2i(Vector2i(r[0],r[1])-padded.position,Vector2i(r[2],r[3])),Color(43.0/255.0,0,0,1))
	return {"texture":ImageTexture.create_from_image(image),"offset":Vector2(padded.position)+definition(value).bounds.position-Vector2(bounds.position),
		"source":Vector2(value.appearance.origin[0],value.appearance.origin[1])+Vector2(padded.position),"size":Vector2(padded.size)}

static func definition(value: Dictionary) -> Dictionary:
	if not error(value).is_empty():return {}
	var mass: float=0.0
	var cx: float=0.0
	var cy: float=0.0
	for r: Array in value.rectangles:
		var area: float=float(r[2])*float(r[3]);mass+=area
		cx+=area*(float(r[0])+float(r[2])*0.5);cy+=area*(float(r[1])+float(r[3])*0.5)
	cx/=mass;cy/=mass
	var center:=Vector2(cx,cy)
	var inertia: float=0.0
	var rects: Array=[]
	var bounds:=Rect2()
	for r: Array in value.rectangles:
		var size:=Vector2(r[2],r[3]);var local:=Vector2(r[0],r[1])+size*0.5-center
		var dx: float=float(r[0])+float(r[2])*0.5-cx;var dy: float=float(r[1])+float(r[3])*0.5-cy
		inertia+=float(r[2])*float(r[3])*((float(r[2])*float(r[2])+float(r[3])*float(r[3]))/12.0+dx*dx+dy*dy)
		rects.append({"center":local,"size":size})
		var box:=Rect2(local-size*0.5,size);bounds=box if rects.size()==1 else bounds.merge(box)
	return {"id":MODEL,"name":value.name,"equipment_preparation":"none",
		"parts":[{"id":"body","shape":"rectangle_union","offset":Vector2.ZERO,"size":bounds.size,
			"mass":mass,"inertia":inertia,"angle":0.0,"collision_rects":rects,"friction":0.78,"bounce":0.0,"color":Color("c99972")}],
		"joints":[],"mounts":[],"script":{},"profile":{"gravity":92.12,"air_drag":0.04,"angular_drag":0.04},
		"bounds":bounds,"body_size":bounds.size}
