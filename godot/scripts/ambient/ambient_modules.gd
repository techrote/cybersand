extends RefCounted

# AMBIENT-001: bounded, pure value rules. Schema, editor and runtime share this
# explicit vocabulary. No live World, scene node or physics object is accepted.
const Stateful = preload("res://scripts/ambient/ambient_stateful_modules.gd")
const VERSION := 2
const MAX_SENSOR_RADIUS := 96


static func _number(value: float, minimum: float, maximum: float, unit: String = "", description: String = "") -> Dictionary:
	return {"type":"number","default":value,"min":minimum,"max":maximum,"unit":unit,"description":description}


static func _integer(value: int, minimum: int, maximum: int, unit: String = "", description: String = "") -> Dictionary:
	return {"type":"integer","default":value,"min":minimum,"max":maximum,"unit":unit,"description":description}


static func _motion(pace: float, effort: float) -> Dictionary:
	return {"pace":_number(pace,0.0,1.0,"fraction","Desired pace; physical speed depends on the rig."),
		"effort":_number(effort,0.0,1.0,"fraction","Actuator effort; no motor tuning or resource bypass.")}


static func _spec(label: String, description: String, priority: int, weight: float, requires: Array, capabilities: Array, params: Dictionary) -> Dictionary:
	return {"label":label,"description":description,"priority":priority,"weight":weight,
		"requires":requires,"capabilities":capabilities,"params":params}


static func module_specs() -> Dictionary:
	var wander := _motion(0.35,0.65)
	wander.merge({"turn_seconds":_number(3.0,0.1,60.0,"s","Mean interval between seeded heading choices."),
		"jitter":_number(0.35,0.0,0.9,"fraction","Bounded variation of heading intervals."),
		"idle_probability":_number(0.12,0.0,1.0,"probability","Idle chance at each heading choice."),
		"idle_seconds":_number(1.5,0.1,30.0,"s","Duration of intentional wander idle."),
		"turn_rate":_number(2.0,0.1,20.0,"per s","Gradual interpolation toward the next heading.")})
	var seek := _motion(0.5,0.7)
	seek.merge({"material_id":_integer(16,1,255,"ID","Native catalogue ID; Oil is 16."),
		"radius":_integer(50,1,MAX_SENSOR_RADIUS,"cells","Inclusive circle; nearest observed cell only."),
		"standoff":_number(8.0,0.0,96.0,"cells","Stop approaching inside this observed distance."),
		"hysteresis":_number(2.0,0.0,32.0,"cells","Extra distance before leaving standoff."),
		"dwell_seconds":_number(1.0,0.0,30.0,"s","Finite pause after arrival."),
		"reacquire_seconds":_number(0.5,0.0,30.0,"s","Target-loss cooldown.")})
	var avoid := _motion(0.7,0.85)
	avoid.merge({"material_id":_integer(3,1,255,"ID","Native catalogue ID; Water is 3."),
		"radius":_integer(50,1,MAX_SENSOR_RADIUS,"cells","Inclusive sampled circle, not a passability test."),
		"enter_distance":_number(36.0,0.0,96.0,"cells","Acquire at or inside this distance."),
		"exit_distance":_number(46.0,0.0,96.0,"cells","Release when observed distance exceeds this.")})
	var ledge := _motion(0.5,0.75)
	ledge.merge({"allowed_drop":_number(8.0,0.0,64.0,"cells","Largest acceptable observed drop."),
		"lookahead":_number(12.0,1.0,32.0,"cells","Support lookahead from physical hull."),
		"duration":_number(10.0,0.1,60.0,"s","One latched retreat; danger does not renew it."),
		"rearm_seconds":_number(0.5,0.0,10.0,"s","Continuous supported safe interval to rearm.")})
	var boundary := _motion(0.6,0.8)
	boundary.merge({"margin":_number(16.0,1.0,96.0,"cells","Canvas or region edge trigger distance."),
		"release_margin":_number(24.0,1.0,128.0,"cells","Safe inward margin needed to rearm."),
		"duration":_number(1.5,0.1,30.0,"s","Latched inward intent; corners combine axes.")})
	var escape := _motion(0.7,0.9)
	escape.merge({"stall_seconds":_number(1.0,0.1,20.0,"s","Requested motion stalled near an observed obstacle."),
		"min_progress":_number(1.0,0.1,20.0,"cells/s","Minimum displacement rate along requested motion."),
		"wall_distance":_number(10.0,0.0,29.0,"cells","Observed wall threshold, below the existing 30-cell no-hit sentinel."),
		"duration":_number(1.5,0.1,15.0,"s","Finite reversal before normal steering resumes."),
		"cooldown":_number(2.0,0.0,30.0,"s","Time after escape before another trigger."),
		"jump":{"type":"boolean","default":false,"description":"One supported primary jump pulse; requires jump capability."}})
	var home := _motion(0.5,0.7)
	home.merge({"radius":_number(60.0,1.0,2048.0,"cells","Acquire outside this home distance."),
		"release_radius":_number(40.0,0.0,2048.0,"cells","Release after returning inside this distance.")})
	var rest := {"active_seconds":_number(8.0,0.1,300.0,"s","Mean active interval."),
		"rest_seconds":_number(2.0,0.1,120.0,"s","Duration of each neutral rest."),
		"jitter":_number(0.25,0.0,0.9,"fraction","Seeded active-interval variation.")}
	var follow := _motion(0.4,0.6)
	follow.merge({"radius":_number(80.0,1.0,96.0,"cells","Acquire nearest observed compatible actor."),
		"separation":_number(22.0,0.0,128.0,"cells","Preferred separation."),
		"hysteresis":_number(3.0,0.0,32.0,"cells","Comfort band around separation.")})
	var crowd := _motion(0.5,0.7)
	crowd.merge({"radius":_number(20.0,1.0,96.0,"cells","Repel copied compatible neighbors inside this radius.")})
	var altitude := _motion(0.4,0.7)
	altitude.merge({"offset":_number(0.0,-1024.0,1024.0,"cells","Desired y relative to home; negative is upward."),
		"tolerance":_number(5.0,0.1,128.0,"cells","No vertical correction inside this altitude band.")})
	var catalogue: Dictionary = {
		"wander":_spec("Wander","Seeded heading choices, gradual turns and intentional idle.",10,0.6,["pose"],["horizontal"],wander),
		"seek_material":_spec("Seek material","Approach observed native material with standoff and finite dwell.",30,1.0,["materials"],["horizontal"],seek),
		"avoid_material":_spec("Avoid material","Hysteretic urgent retreat; no physical immunity.",80,1.0,["materials"],["horizontal"],avoid),
		"avoid_ledge":_spec("Avoid ledge / retreat","Grounded support loss starts one fixed-duration latched retreat.",100,1.0,["ledges","grounded"],["ground"],ledge),
		"avoid_boundary":_spec("Avoid boundary","Temporary inward steering at canvas or region boundaries.",90,1.0,["bounds"],["horizontal"],boundary),
		"escape_obstruction":_spec("Escape obstruction","Debounced reversal after actual progress stalls near contact.",85,1.0,["pose","obstacles"],["horizontal"],escape),
		"return_home":_spec("Return home","Hysteretic steering toward authored home.",40,1.0,["pose","home"],["horizontal"],home),
		"rest":_spec("Rest and resume","Periodic neutral intervals; urgent reflexes may interrupt.",60,1.0,[],[],rest),
		"follow_actor":_spec("Follow actor","Approach a copied compatible neighbor at comfortable separation.",25,0.8,["neighbors"],["horizontal"],follow),
		"avoid_crowding":_spec("Avoid crowding","Gentle separation from copied compatible neighbors.",35,1.0,["neighbors"],["horizontal"],crowd),
		"maintain_altitude":_spec("Maintain altitude","Home-relative correction for legitimate two-axis rigs.",25,0.8,["pose","home"],["vertical"],altitude),
	}
	catalogue.merge(Stateful.module_specs())
	return catalogue


static func random_unit(state: Dictionary) -> float:
	# Explicit 31-bit integer stream, independent for every authored module.
	# Max multiplication stays below signed 64-bit overflow. No global RNG.
	state.rng = (int(state.get("rng", 1)) * 1103515245 + 12345) & 0x7fffffff
	return float(state.rng) / 2147483648.0


static func _interval(state: Dictionary, mean: float, jitter: float) -> float:
	return mean * (1.0 + (random_unit(state) * 2.0 - 1.0) * jitter)


static func _inactive(reason: String) -> Dictionary:
	return {"active":false,"reason":reason,"direction":Vector2.ZERO,"pace":0.0,"effort":0.0}


static func _intent(direction: Vector2, parameters: Dictionary, reason: String, override: bool = false, strength: float = 1.0) -> Dictionary:
	return {"active":true,"reason":reason,"mode":"override" if override else "steer",
		"direction":direction.limit_length(1.0),"pace":float(parameters.get("pace",0.0)),
		"effort":float(parameters.get("effort",0.0)),"strength":clampf(strength,0.0,1.0),"primary":false}


static func _direction(value: Vector2, context: Dictionary) -> Vector2:
	if not bool(context.get("capabilities",{}).get("vertical",false)): value.y = 0.0
	return value.normalized() if value.length_squared() > 0.000001 else Vector2.ZERO


static func _heading(context: Dictionary) -> Vector2:
	var direction: Vector2 = context.get("last_direction",Vector2.RIGHT)
	return direction.normalized() if direction.length_squared() > 0.000001 else Vector2.RIGHT


static func _grounded(observation: Dictionary) -> bool:
	var ground: Dictionary = observation.get("grounded",{})
	return bool(ground.get("available",false)) and bool(ground.get("value",false))


static func _material(observation: Dictionary, parameters: Dictionary) -> Dictionary:
	var materials: Dictionary = observation.get("materials",{})
	if not bool(materials.get("available",false)): return {"available":false,"reason":"material coverage unavailable"}
	var targets: Dictionary = materials.get("targets",{})
	var target: Dictionary = targets.get(str(int(parameters.material_id)),{})
	if not bool(target.get("available",false)): return {"available":false,"reason":"requested material measurement unavailable"}
	if float(target.get("radius_cells",0.0)) < float(parameters.radius):
		return {"available":false,"reason":"sensor extent is smaller than authored radius"}
	if not bool(target.get("present",false)): return {"available":true,"present":false,"reason":"no matching cell observed in sampled circle"}
	var nearest: Variant = target.get("nearest")
	var distance: Variant = target.get("distance")
	if not nearest is Vector2 or not nearest.is_finite() or not (distance is float or distance is int) \
		or not is_finite(float(distance)) or float(distance) < 0.0:
		return {"available":false,"reason":"malformed material measurement"}
	# Recompute geometric distance from copied coordinates. A producer cannot
	# acquire an out-of-radius target by supplying a contradictory scalar.
	var actual_distance: float = observation.position.distance_to(nearest)
	if absf(actual_distance - float(distance)) > 0.01:
		return {"available":false,"reason":"material distance and position disagree"}
	if observation.position.distance_squared_to(nearest) > float(parameters.radius) * float(parameters.radius):
		return {"available":true,"present":false,"reason":"nearest observed target lies outside this module radius"}
	return {"available":true,"present":true,"nearest":nearest,"distance":actual_distance,
		"delta":nearest - observation.position,"reason":"nearest observed native material"}


static func evaluate(module: Dictionary, observation: Dictionary, state: Dictionary, now: float, delta: float, context: Dictionary) -> Dictionary:
	var parameters: Dictionary = module.params
	match str(module.type):
		"wander": return _wander(parameters,observation,state,now,delta,context)
		"seek_material": return _seek(parameters,observation,state,now,context)
		"avoid_material": return _avoid(parameters,observation,state,context)
		"avoid_ledge": return _ledge(parameters,observation,state,now,delta,context,str(module.id))
		"avoid_boundary": return _boundary(parameters,observation,state,now,context)
		"escape_obstruction": return _escape(parameters,observation,state,now,delta,context)
		"return_home": return _home(parameters,observation,state,context)
		"rest": return _rest(parameters,state,now)
		"follow_actor":
			if int(context.get("profile_version",1)) >= 2:
				return Stateful.follow_peer(parameters,observation,context)
			return _follow(parameters,observation,context)
		"avoid_crowding": return _crowding(parameters,observation,context)
		"maintain_altitude": return _altitude(parameters,observation,context)
	return Stateful.evaluate(module,observation,state,now,delta,context)


static func _wander(p: Dictionary, _o: Dictionary, s: Dictionary, now: float, delta: float, c: Dictionary) -> Dictionary:
	if not s.has("next_choice") or now >= float(s.next_choice):
		s.idle = random_unit(s) < float(p.idle_probability)
		if bool(s.idle):
			s.target = Vector2.ZERO
			s.next_choice = now + float(p.idle_seconds)
		else:
			var heading: Vector2
			if bool(c.capabilities.get("vertical",false)):
				var angle: float = random_unit(s) * TAU
				heading = Vector2(cos(angle),sin(angle))
			else:
				heading = Vector2.LEFT if random_unit(s) < 0.5 else Vector2.RIGHT
			s.target = heading
			s.next_choice = now + _interval(s,float(p.turn_seconds),float(p.jitter))
		if not s.has("heading"): s.heading = s.target
	# Intentional idle is immediate neutral, not residual inertia of the intent.
	if bool(s.idle):
		s.heading = Vector2.ZERO
	else:
		s.heading = (s.heading as Vector2).move_toward(s.target,float(p.turn_rate) * delta)
	var result := _intent(s.heading,p,"intentional wander idle" if bool(s.idle) else "seeded wandering")
	result.remaining_seconds = maxf(0.0,float(s.next_choice) - now)
	result.idle = bool(s.idle)
	return result


static func _seek(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	var target := _material(o,p)
	if not bool(target.available):
		return _inactive(str(target.reason))
	if not bool(target.present):
		if bool(s.get("acquired",false)):
			s.reacquire_at = now + float(p.reacquire_seconds)
		s.acquired = false
		s.at_standoff = false
		s.erase("dwell_until")
		return _inactive(str(target.reason))
	if now < float(s.get("reacquire_at",0.0)): return _inactive("material reacquisition cooldown")
	s.acquired = true
	var distance: float = target.distance
	if bool(s.get("at_standoff",false)) and distance > float(p.standoff) + float(p.hysteresis):
		s.at_standoff = false
		s.erase("dwell_until")
	if distance <= float(p.standoff) and not bool(s.get("at_standoff",false)):
		s.at_standoff = true
		s.dwell_until = now + float(p.dwell_seconds)
	if bool(s.get("at_standoff",false)):
		if now + 0.00000001 < float(s.get("dwell_until",now)):
			var dwell := _intent(Vector2.ZERO,p,"dwelling at observed material standoff",true)
			dwell.pace = 0.0
			dwell.remaining_seconds = float(s.dwell_until) - now
			dwell.target = target.nearest
			return dwell
		return _inactive("standoff reached; other modules may roam")
	var direction := _direction(target.delta,c)
	if direction == Vector2.ZERO: return _inactive("target has no supported movement-axis direction; no route inferred")
	var result := _intent(direction,p,"approaching nearest observed material")
	result.target = target.nearest
	result.distance = distance
	return result


static func _avoid(p: Dictionary, o: Dictionary, s: Dictionary, c: Dictionary) -> Dictionary:
	var target := _material(o,p)
	if not bool(target.available): return _inactive(str(target.reason))
	if not bool(target.present):
		s.active = false
		return _inactive(str(target.reason))
	var distance: float = target.distance
	if distance <= float(p.enter_distance): s.active = true
	elif distance > float(p.exit_distance): s.active = false
	if not bool(s.get("active",false)): return _inactive("material outside avoidance entry threshold")
	var direction := _direction(-target.delta,c)
	if direction == Vector2.ZERO:
		# Coincident material cannot supply a geometric direction. Pick once and
		# retain a deterministic compatible escape direction until release.
		if not s.has("coincident_direction"): s.coincident_direction = Vector2.LEFT if random_unit(s) < 0.5 else Vector2.RIGHT
		direction = s.coincident_direction
	else:
		s.erase("coincident_direction")
	var result := _intent(direction,p,"urgent retreat from nearest observed material",true)
	result.target = target.nearest
	result.distance = distance
	return result


static func _ledge_side(ledges: Dictionary, side: String, p: Dictionary) -> Dictionary:
	if not bool(ledges.get("available",false)): return {"available":false}
	var lookahead: Variant = ledges.get("lookahead_cells")
	if not (lookahead is int or lookahead is float) or not is_finite(float(lookahead)) \
		or absf(float(lookahead) - float(p.lookahead)) > 0.000001: return {"available":false}
	var sample: Dictionary = ledges.get(side,{})
	if not bool(sample.get("available",false)): return {"available":false}
	var drop: Variant = sample.get("drop_cells")
	var depth: Variant = sample.get("searched_drop_cells")
	if not (drop is float or drop is int) or not is_finite(float(drop)) or float(drop) < 0.0 \
		or not (depth is float or depth is int) or not is_finite(float(depth)) or float(depth) < 0.0:
		return {"available":false}
	var found: bool = bool(sample.get("support_found",false))
	# An empty ray proves only a lower bound. It cannot decide an authored drop
	# tolerance beyond the depth actually searched. The admitted ray is inclusive.
	if not found and float(depth) + 0.000001 < float(p.allowed_drop): return {"available":false}
	if found and float(drop) > float(depth) + 0.000001: return {"available":false}
	return {"available":true,"danger":not found or float(drop) > float(p.allowed_drop),"drop_cells":float(drop)}


static func _ledge(p: Dictionary, o: Dictionary, s: Dictionary, now: float, delta: float, c: Dictionary, module_id: String) -> Dictionary:
	if now + 0.00000001 < float(s.get("until",0.0)):
		var retained := _intent(s.retreat,p,"latched ledge retreat",true)
		retained.remaining_seconds = float(s.until) - now
		retained.trigger_count = int(s.get("triggers",0))
		return retained
	var samples: Dictionary = o.get("ledges",{})
	if samples.has("modules"): samples = samples.modules.get(module_id,{})
	var left := _ledge_side(samples,"left",p)
	var right := _ledge_side(samples,"right",p)
	if not bool(left.available) or not bool(right.available):
		s.safe_time = 0.0
		return _inactive("exact-lookahead physical ledge samples unavailable")
	if not _grounded(o):
		s.safe_time = 0.0
		return _inactive("ledge reflex requires actual grounded support")
	if not bool(s.get("armed",true)):
		var safe: bool = not bool(left.danger) and not bool(right.danger)
		if bool(c.get("observation_gap",false)): s.safe_time = 0.0
		if safe: s.safe_time = float(s.get("safe_time",0.0)) + float(c.get("continuity_delta",delta))
		else: s.safe_time = 0.0
		if safe and float(s.get("safe_time",0.0)) + 0.00000001 >= float(p.rearm_seconds):
			s.armed = true
		else:
			return _inactive("ledge retreat complete; waiting for supported safe rearm")
	var ahead: float = _heading(c).x
	var danger: bool = bool(right.danger) if ahead >= 0.0 else bool(left.danger)
	if not danger: return _inactive("supported lookahead has no excessive drop")
	s.retreat = Vector2.LEFT if ahead >= 0.0 else Vector2.RIGHT
	s.until = now + float(p.duration)
	s.armed = false
	s.safe_time = 0.0
	s.triggers = int(s.get("triggers",0)) + 1
	var result := _intent(s.retreat,p,"ledge triggered fixed retreat",true)
	result.remaining_seconds = float(p.duration)
	result.trigger_count = s.triggers
	return result


static func _boundary(p: Dictionary, o: Dictionary, s: Dictionary, now: float, c: Dictionary) -> Dictionary:
	if now + 0.00000001 < float(s.get("until",0.0)):
		var retained := _intent(s.retreat,p,"latched boundary retreat",true)
		retained.remaining_seconds = float(s.until) - now
		return retained
	var bounds: Dictionary = o.get("bounds",{})
	var rectangle: Variant = bounds.get("rect")
	if not bool(bounds.get("available",false)) or not rectangle is Rect2 or not rectangle.has_area():
		return _inactive("canvas or region bounds unavailable")
	var position: Vector2 = o.position
	var vertical: bool = bool(c.capabilities.get("vertical",false))
	var low: Vector2 = position - rectangle.position
	var high: Vector2 = rectangle.end - position
	var safe: bool = minf(low.x,high.x) >= float(p.release_margin) \
		and (not vertical or minf(low.y,high.y) >= float(p.release_margin))
	if not bool(s.get("armed",true)):
		if safe: s.armed = true
		else: return _inactive("boundary retreat complete; waiting for release margin")
	var direction := Vector2.ZERO
	if low.x <= float(p.margin): direction.x += 1.0
	if high.x <= float(p.margin): direction.x -= 1.0
	if vertical:
		if low.y <= float(p.margin): direction.y += 1.0
		if high.y <= float(p.margin): direction.y -= 1.0
	if direction == Vector2.ZERO:
		if low.x <= float(p.margin) and high.x <= float(p.margin): return _inactive("region narrower than two margins; no contradictory boundary command")
		return _inactive("inside boundary comfort margin")
	s.retreat = direction.normalized()
	s.until = now + float(p.duration)
	s.armed = false
	var result := _intent(s.retreat,p,"boundary triggered inward retreat",true)
	result.remaining_seconds = float(p.duration)
	return result


static func _escape(p: Dictionary, o: Dictionary, s: Dictionary, now: float, delta: float, c: Dictionary) -> Dictionary:
	var position: Vector2 = o.position
	var previous: Vector2 = s.get("previous_position",position)
	s.previous_position = position
	if now + 0.00000001 < float(s.get("until",0.0)):
		var retained := _intent(s.retreat,p,"bounded obstruction escape",true)
		retained.remaining_seconds = float(s.until) - now
		return retained
	if now < float(s.get("cooldown_until",0.0)): return _inactive("obstruction escape cooldown")
	if bool(c.get("observation_gap",false)):
		s.stalled = 0.0
		return _inactive("decision gap prevents continuous obstruction inference")
	var obstacles: Dictionary = o.get("obstacles",{})
	if not bool(obstacles.get("available",false)):
		s.stalled = 0.0
		return _inactive("local contact distances unavailable")
	var requested: Vector2 = _heading(c)
	var distance: Variant = obstacles.get("right_distance" if requested.x >= 0.0 else "left_distance")
	if not (distance is float or distance is int) or not is_finite(float(distance)) or float(distance) < 0.0:
		s.stalled = 0.0
		return _inactive("requested-side obstacle distance unavailable")
	var wants_motion: bool = float(c.get("last_pace",0.0)) > 0.05 and c.get("last_direction",Vector2.ZERO) != Vector2.ZERO
	var progress: float = maxf(0.0,(position - previous).dot(requested)) / delta if delta > 0.0 else 0.0
	var maximum_distance: float = float(obstacles.get("maximum_distance_cells",30.0))
	var observed_hit: bool = is_finite(maximum_distance) and maximum_distance > 0.0 and float(distance) < maximum_distance
	var obstructed: bool = (observed_hit and float(distance) <= float(p.wall_distance)) or bool(obstacles.get("blocked",false))
	if wants_motion and obstructed and progress < float(p.min_progress): s.stalled = float(s.get("stalled",0.0)) + delta
	else: s.stalled = 0.0
	if float(s.stalled) + 0.00000001 < float(p.stall_seconds): return _inactive("progress/contact stall has not reached debounce")
	s.retreat = -requested
	s.until = now + float(p.duration)
	s.cooldown_until = float(s.until) + float(p.cooldown)
	s.stalled = 0.0
	var result := _intent(s.retreat,p,"obstruction triggered finite escape",true)
	result.primary = bool(p.jump) and bool(c.capabilities.get("jump",false)) and _grounded(o)
	result.remaining_seconds = float(p.duration)
	return result


static func _home(p: Dictionary, o: Dictionary, s: Dictionary, c: Dictionary) -> Dictionary:
	var home: Variant = c.get("home")
	if not home is Vector2 or not home.is_finite(): return _inactive("authored home unavailable")
	var displacement: Vector2 = home - o.position
	if not bool(c.capabilities.get("vertical",false)): displacement.y = 0.0
	var distance: float = displacement.length()
	if distance >= float(p.radius): s.active = true
	elif distance <= float(p.release_radius): s.active = false
	if not bool(s.get("active",false)): return _inactive("inside home comfort region")
	return _intent(displacement.normalized(),p,"returning toward authored home")


static func _rest(p: Dictionary, s: Dictionary, now: float) -> Dictionary:
	if not s.has("next_rest"):
		s.next_rest = now + _interval(s,float(p.active_seconds),float(p.jitter))
	if now + 0.00000001 < float(s.get("until",0.0)):
		var result := _intent(Vector2.ZERO,{},"scheduled rest",true)
		result.remaining_seconds = float(s.until) - now
		return result
	if now >= float(s.next_rest):
		s.until = now + float(p.rest_seconds)
		s.next_rest = float(s.until) + _interval(s,float(p.active_seconds),float(p.jitter))
		var result := _intent(Vector2.ZERO,{},"scheduled rest began",true)
		result.remaining_seconds = float(p.rest_seconds)
		return result
	return _inactive("active interval before rest")


static func _neighbors(o: Dictionary) -> Array:
	var neighbors: Dictionary = o.get("neighbors",{})
	if not bool(neighbors.get("available",false)): return []
	var actors: Variant = neighbors.get("actors",[])
	if not actors is Array: return []
	var result: Array = []
	for index: int in mini(8,actors.size()):
		var actor: Variant = actors[index]
		if not actor is Dictionary or not bool(actor.get("compatible",false)): continue
		var position: Variant = actor.get("position")
		if not position is Vector2 or not position.is_finite(): continue
		if int(actor.get("id",-1)) == int(o.get("instance_id",-2)): continue
		result.append(actor)
	return result


static func _follow(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	if not bool(o.get("neighbors",{}).get("available",false)): return _inactive("copied neighboring actors unavailable")
	var target: Dictionary = {}
	var nearest: float = float(p.radius)
	for actor: Dictionary in _neighbors(o):
		var distance: float = o.position.distance_to(actor.position)
		if distance > float(p.radius): continue
		if target.is_empty() or distance < nearest or (is_equal_approx(distance,nearest) and int(actor.id) < int(target.get("id",2147483647))):
			nearest = distance
			target = actor
	if target.is_empty(): return _inactive("no compatible actor observed within follow radius")
	if absf(nearest - float(p.separation)) <= float(p.hysteresis): return _inactive("neighbor inside preferred separation band")
	var delta: Vector2 = target.position - o.position
	if nearest < float(p.separation): delta = -delta
	var direction := _direction(delta,c)
	if direction == Vector2.ZERO: return _inactive("neighbor has no supported movement-axis direction; no route inferred")
	var result := _intent(direction,p,"approaching comfortable neighbor separation")
	result.target_actor = int(target.id)
	result.distance = nearest
	return result


static func _crowding(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	if not bool(o.get("neighbors",{}).get("available",false)): return _inactive("copied neighboring actors unavailable")
	var sum := Vector2.ZERO
	var count: int = 0
	for actor: Dictionary in _neighbors(o):
		var away: Vector2 = o.position - actor.position
		var distance: float = away.length()
		if distance >= float(p.radius): continue
		if distance < 0.00001:
			away = Vector2.LEFT if int(o.get("instance_id",0)) < int(actor.id) else Vector2.RIGHT
		else: away /= distance
		sum += away * (1.0 - distance / float(p.radius))
		count += 1
	if count == 0: return _inactive("no copied neighbor inside crowding radius")
	var direction := _direction(sum,c)
	if direction == Vector2.ZERO: return _inactive("symmetric crowding; no arbitrary preferred side")
	return _intent(direction,p,"gentle separation from copied neighbors",false,clampf(sum.length(),0.0,1.0))


static func _altitude(p: Dictionary, o: Dictionary, c: Dictionary) -> Dictionary:
	var home: Variant = c.get("home")
	if not home is Vector2 or not home.is_finite(): return _inactive("authored home altitude unavailable")
	var error: float = float(home.y) + float(p.offset) - float(o.position.y)
	if absf(error) <= float(p.tolerance): return _inactive("inside preferred altitude band")
	return _intent(Vector2(0.0,signf(error)),p,"correcting home-relative altitude",false,clampf(absf(error) / (float(p.tolerance) * 3.0),0.0,1.0))
