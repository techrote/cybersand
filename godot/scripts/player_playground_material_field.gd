class_name CyberPlayerPlaygroundMaterialField
extends RefCounted

# A composite of the existing radius-32 native fields. Outer calls cancel
# their own authored loft and their pull at the player anchor; they therefore
# recover nearby parcels without applying five upward hover impulses to the
# same central cloud. Ordinary gravity is countered by the central call once.
const RADIUS: int = 60
const NATIVE_RADIUS: int = 32
const OFFSETS: Array[Vector2i] = [Vector2i.ZERO,Vector2i(-28,0),Vector2i(28,0),Vector2i(0,-28),Vector2i(0,28)]


static func apply(world: Object, centre: Vector2, direction: Vector2, material: int, mode: int, tick: int) -> Dictionary:
	if world == null or not centre.is_finite() or not direction.is_finite() \
		or direction.length_squared() > 1.000001 or material not in [2,3] \
		or mode < 0 or mode > 3 or tick < 0 or tick > 2147483647 \
		or centre.x < 0 or centre.x >= 1024 or centre.y < 0 or centre.y >= 1024:
		return {"accepted":false,"reason":"invalid_command"}
	var anchor := Vector2i(centre.round()).clamp(Vector2i.ZERO,Vector2i(1023,1023))
	var idle: bool = direction.length_squared() < 0.001
	var phase: float = float(tick)*(0.061 if material == 2 else 0.043)
	var fields: Array[Dictionary] = []
	var result: Dictionary = {"accepted":true,"reason":"applied","observed_cells":0,
		"controlled_cells":0,"moved_cells":0,"scanned_cells":0,"movement_steps":0,
		"blocked_steps":0,"storage_refusals":0,"quantity":0,"truncated":false,
		"centroid":centre,"radius":RADIUS,"native_calls":0,"idle_pattern":idle,
		"anchor":centre,"quantity_is_sample_sum":true}
	var weighted := Vector2.ZERO
	var quantity: float = 0.0
	for index: int in range(OFFSETS.size()):
		var field_centre: Vector2i = (anchor+OFFSETS[index]).clamp(Vector2i.ZERO,Vector2i(1023,1023))
		var flow: Vector2 = direction
		var field_mode: int = mode
		if index == 0:
			if idle:
				# Motion changes within the cloud; the caller never moves the anchor
				# in response to this deliberately local circulation.
				flow = Vector2(cos(phase)*0.26,sin(phase*0.73)*0.14)
		else:
			# Native surge mode is used for recovery because its 2.6-cell drive
			# can cancel both the fixed -1 loft and the <=1.2 radial pull. A normal
			# mode's 1.35 drive cannot cancel the upper satellite's two terms.
			field_mode = 1
			var offset := Vector2(field_centre-anchor)
			var distance: float = offset.length()
			var core: float = 4.0 if material == 3 else 8.0
			var pull: float = clampf((distance-core)*(0.12 if material == 3 else 0.09),-0.25,1.2)
			var native_pull: Vector2 = offset.normalized()*pull
			flow = (Vector2.DOWN-native_pull)/2.6 + direction*0.62
			# Native surge treats a <0.1 vector as an explicit upward launch.
			# Avoid that fallback while retaining a balanced, local sideways ripple.
			if flow.length_squared() < 0.011:
				flow.x = 0.11 if tick%80 < 40 else -0.11
			flow = flow.limit_length(1.0)
		var receipt: Dictionary = world.apply_player_material_field(field_centre,flow,material,field_mode,tick)
		if not bool(receipt.get("accepted",false)): return receipt
		fields.append(receipt.duplicate(true))
		for key: String in ["observed_cells","controlled_cells","moved_cells","scanned_cells",
			"movement_steps","blocked_steps","storage_refusals","quantity"]:
			result[key] += int(receipt.get(key,0))
		result.truncated = result.truncated or bool(receipt.get("truncated",false))
		var weight: float = float(receipt.get("quantity",0))
		weighted += Vector2(receipt.get("centroid",centre))*weight
		quantity += weight
	result.centroid = weighted/quantity if quantity > 0 else centre
	result.native_fields = fields
	result.native_calls = fields.size()
	return result
