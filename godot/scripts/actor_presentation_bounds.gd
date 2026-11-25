extends RefCounted

## Bounded read-only geometry for visual assistance. Inputs are the exact
## already-published data consumed by the actor overlays, never native queries.
const MAX_ACTORS := 8
const MAX_RENDER_PARTS := 64
const STATE_STRIDE := 16
const RIG_STRIDE := 40
const LEGACY_SIZE := Vector2(8.0, 14.0)


static func physical(parts: Array, limit: int = MAX_ACTORS) -> Array[Rect2]:
	var merged := {}
	for index: int in mini(parts.size(), MAX_RENDER_PARTS):
		var part: Variant = parts[index]
		if not part is Dictionary or not part.get("transform") is Transform2D \
				or not part.get("size") is Vector2 or not part.get("actor_id") is int: continue
		var actor: int = part.actor_id
		if actor < 0: continue
		# Published instance identities may increase after removal/replacement.
		# Bound the number of active identities, never their numeric values.
		if not merged.has(actor) and merged.size() >= MAX_ACTORS: continue
		var bounds := rectangle(part.transform, part.size)
		if not bounds.has_area(): continue
		merged[actor] = merged[actor].merge(bounds) if merged.has(actor) else bounds
	var result: Array[Rect2] = []
	var identities: Array = merged.keys()
	identities.sort()
	for actor: int in identities:
		if result.size() >= clampi(limit, 0, MAX_ACTORS): break
		result.append(merged[actor])
	return result


static func prototype(states: PackedFloat32Array, rigs: PackedFloat32Array,
		limit: int = MAX_ACTORS) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index: int in mini(states.size() / STATE_STRIDE, clampi(limit, 0, MAX_ACTORS)):
		var extended := rigs.size() >= (index + 1) * RIG_STRIDE
		var offset := index * (RIG_STRIDE if extended else STATE_STRIDE)
		var data := rigs if extended else states
		var dimensions := Vector2(data[offset+35], data[offset+36]) if extended else LEGACY_SIZE
		var position := Vector2(data[offset], data[offset+1])
		var angle := float(data[offset+16]) if extended else 0.0
		if not position.is_finite() or not is_finite(angle): continue
		var bounds := rectangle(Transform2D(angle, position+dimensions*0.5), dimensions)
		if bounds.has_area(): result.append(bounds)
	return result


static func rectangle(pose: Transform2D, dimensions: Vector2) -> Rect2:
	if not dimensions.is_finite() or dimensions.x <= 0.0 or dimensions.y <= 0.0 \
			or not pose.x.is_finite() or not pose.y.is_finite() or not pose.origin.is_finite(): return Rect2()
	var half := dimensions * 0.5
	var extent := Vector2(absf(pose.x.x)*half.x+absf(pose.y.x)*half.y,
		absf(pose.x.y)*half.x+absf(pose.y.y)*half.y)
	# Conservative AABB also covers rotated circles/compound parts. It conveys
	# no physical collision or picking authority and does not move actor poses.
	return Rect2(pose.origin-extent, extent*2.0)
