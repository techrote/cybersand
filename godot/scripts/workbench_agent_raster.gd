extends RefCounted
## Exact bounded raster grammar. No World access or mutation.
static func refused(reason: String) -> Dictionary:
 return {"status":"refused","reason":reason}

static func integers(values: Variant, length: int) -> bool:
 if not values is Array or values.size() != length: return false
 for value: Variant in values:
  if typeof(value) != TYPE_INT: return false
 return true

static func valid_envelope(op: Dictionary) -> bool:
 if typeof(op.get("material")) != TYPE_INT: return false
 if op.get("shape") == "pixels":
  if op.size() != 3 or not op.get("points") is Array or op.points.is_empty() or op.points.size() > 32: return false
  for pair: Variant in op.points:
   if not integers(pair,2): return false
  return true
 if op.get("shape") != "scanlines" or op.size() != 8: return false
 for key: String in ["x","y","width","height","scale","material"]:
  if typeof(op.get(key)) != TYPE_INT: return false
 if op.width < 1 or op.width > 256 or op.height < 1 or op.height > 256 or op.scale < 1 or op.scale > 16: return false
 if op.width*op.height*op.scale*op.scale > 65536: return false
 if not op.get("rows") is Array or op.rows.is_empty() or op.rows.size() > 256: return false
 var spans := 0
 for group: Variant in op.rows:
  if not group is Dictionary or group.size() != 2 or typeof(group.get("repeat")) != TYPE_INT or not group.get("spans") is Array or group.spans.size() > 256: return false
  spans += group.spans.size()
  if spans > 2048: return false
  for span: Variant in group.spans:
   if not integers(span,2): return false
 return true

static func compile(op: Dictionary, extent: Vector2i, scope: Rect2i, protection: Array, allowed: Array, cell_limit: int) -> Dictionary:
 if typeof(op.get("material")) != TYPE_INT or op.material not in allowed: return refused("replacement_material_not_allowed")
 var points: Array[Vector2i] = []
 if op.get("shape") == "pixels":
  if op.size() != 3 or not op.get("points") is Array or op.points.is_empty() or op.points.size() > 32: return refused("pixels_count_1_to_32_required")
  var seen := {}
  for pair: Variant in op.points:
   if not integers(pair,2): return refused("invalid_pixel_coordinate")
   if pair[0] < 0 or pair[1] < 0 or pair[0] >= extent.x or pair[1] >= extent.y: return refused("outside_authorized_scope")
   var point := Vector2i(pair[0],pair[1])
   if seen.has(point): return refused("duplicate_pixel_coordinate")
   seen[point] = true
   points.append(point)
 elif op.get("shape") == "scanlines":
  if op.size() != 8: return refused("invalid_stamp_fields")
  for key: String in ["x","y","width","height","scale","material"]:
   if typeof(op.get(key)) != TYPE_INT: return refused("invalid_stamp_integer")
  var x: int = op.x
  var y: int = op.y
  var w: int = op.width
  var h: int = op.height
  var scale: int = op.scale
  if w < 1 or w > 256 or h < 1 or h > 256 or scale < 1 or scale > 16: return refused("invalid_stamp_dimensions")
  if w*h*scale*scale > cell_limit: return refused("stamp_exceeds_cell_budget")
  if x < 0 or y < 0 or x > extent.x-w*scale or y > extent.y-h*scale: return refused("outside_authorized_scope")
  if not scope.encloses(Rect2i(x,y,w*scale,h*scale)): return refused("outside_authorized_scope")
  if not op.get("rows") is Array or op.rows.is_empty() or op.rows.size() > 256: return refused("invalid_scanline_rows")
  var row := 0
  var span_count := 0
  for group: Variant in op.rows:
   if not group is Dictionary or group.size() != 2 or typeof(group.get("repeat")) != TYPE_INT or not group.get("spans") is Array: return refused("invalid_scanline_repeat")
   var repeats: int = group.repeat
   if repeats < 1 or repeats > h-row: return refused("invalid_scanline_repeat")
   if group.spans.size() > 256: return refused("invalid_scanline_spans")
   span_count += group.spans.size()
   if span_count > 2048: return refused("scanline_span_capacity")
   var end := 0
   for span: Variant in group.spans:
    if not integers(span,2): return refused("invalid_scanline_span")
    var start: int = span[0]
    var length: int = span[1]
    if start < end or start < 0 or start > w or length < 1 or length > w-start: return refused("overlapping_or_outside_scanline_span")
    end = start+length
    for yy: int in range(row*scale,(row+repeats)*scale):
     for xx: int in range(start*scale,end*scale): points.append(Vector2i(x+xx,y+yy))
   row += repeats
  if row != h: return refused("scanline_height_mismatch")
 else: return refused("unsupported_shape")
 if points.size() > cell_limit: return refused("distinct_cell_budget_exceeded")
 for point: Vector2i in points:
  if not scope.has_point(point): return refused("outside_authorized_scope")
  for guard: Rect2i in protection:
   if guard.has_point(point): return refused("protected_region")
 return {"status":"validated_geometry","cells":points}
