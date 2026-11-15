extends RefCounted

# Value-only observations for presentation. This journal never owns a RID,
# applies a force, changes a sample, or extends the bridge's wrench fence.
# Completed physical steps, not native ticks or render callbacks, index it.
const CAPACITY: int = 128
const MAX_ACTORS: int = 8 # PhysicalActorSession admission limit; do not grow on invalid slots.
const RECOVERY_ATTEMPTS: int = 3
const MAX_HOLD_USEC: int = 100000
var _actors: Dictionary = {}


func clear() -> void:
	_actors.clear()


func observe(slot: int, instance_id: int, generation: int, step: int,
		pose: Transform2D, velocity: Vector2, angular_velocity: float,
		completed_usec: int, sample_serial: int = -1, sampled_usec: int = 0) -> Dictionary:
	if slot < 0 or slot >= MAX_ACTORS or step < 0 or not pose.is_finite() or not velocity.is_finite() \
			or not is_finite(angular_velocity) or completed_usec < 0:
		return {}
	var actor: Dictionary = _actors.get(slot,{})
	if actor.get("instance_id",-1) != instance_id or actor.get("generation",-1) != generation:
		var rows: Array[Dictionary] = []
		rows.resize(CAPACITY)
		actor = {"instance_id":instance_id,"generation":generation,"latest_step":-1,"rows":rows}
		_actors[slot] = actor
	if step < int(actor.latest_step): return {}
	var old: Dictionary = actor.rows[step % CAPACITY]
	# A render callback observing an already completed step cannot make that
	# observation younger. Publishing a sample may add its serial afterwards.
	var same: bool = old.get("step",-1) == step and old.get("pose") == pose
	var serial: int = sample_serial
	if serial < 0 and same: serial = int(old.sample_serial)
	if same and serial == int(old.sample_serial) and old.velocity == velocity \
			and float(old.angular_velocity) == angular_velocity:
		return old
	var observed_usec: int = sampled_usec if sampled_usec > 0 else Time.get_ticks_usec()
	var observation: Dictionary = {"instance_id":instance_id,"generation":generation,
		"step":step,"pose":pose,"velocity":velocity,"angular_velocity":angular_velocity,
		"completed_usec":int(old.completed_usec) if same else completed_usec,
		"sampled_usec":int(old.sampled_usec) if same else observed_usec,"sample_serial":serial}
	observation.make_read_only()
	actor.rows[step % CAPACITY] = observation
	actor.latest_step = step
	return observation


func observation(slot: int, step: int) -> Dictionary:
	var actor: Dictionary = _actors.get(slot,{})
	if actor.is_empty() or step < 0: return {}
	var row: Dictionary = actor.rows[step % CAPACITY]
	return row if row.get("step",-1) == step else {}


func newest_after_through(slot: int, after_step: int, through_step: int) -> Dictionary:
	var actor: Dictionary = _actors.get(slot,{})
	if actor.is_empty(): return {}
	var latest: int = int(actor.latest_step)
	var first: int = mini(through_step,latest)
	var last: int = maxi(after_step+1,latest-CAPACITY+1)
	for step: int in range(first,last-1,-1):
		var row: Dictionary = observation(slot,step)
		if not row.is_empty(): return row
	return {}


func recovery_candidates(slot: int, after_step: int, before_step: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actor: Dictionary = _actors.get(slot,{})
	if actor.is_empty(): return result
	var latest: int = int(actor.latest_step)
	var first: int = maxi(after_step+1,latest-CAPACITY+1)
	var last: int = mini(before_step-1,latest)
	# At most128 cheap slot checks, followed by at most3 geometry queries in
	# Main's original shared deadline. No expanding search or guessed poses.
	for step: int in range(first,last+1):
		var row: Dictionary = observation(slot,step)
		if row.is_empty(): continue
		result.append(row)
		if result.size() == RECOVERY_ATTEMPTS: break
	return result


func retained_observations() -> int:
	var total: int = 0
	for actor: Dictionary in _actors.values():
		for row: Dictionary in actor.rows:
			if not row.is_empty(): total += 1
	return total
