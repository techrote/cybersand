extends RefCounted

# Value-only observations for presentation. This journal never owns a RID,
# applies a force, changes a sample, or extends the bridge's wrench fence.
# Completed physical steps, not native ticks or render callbacks, index it.
const CAPACITY: int = 128
const MAX_ACTORS: int = 8 # Legacy unbound history. A prepared roster supplies the actual member limit.
const MAX_MEMBERS: int = preload("res://scripts/rigid_body_coupling.gd").MAX_BODIES
const RECOVERY_ATTEMPTS: int = 3
const MAX_HOLD_USEC: int = 100000
var _actors: Dictionary = {}
var _bound_owner: Array = []
var _bound_members: Array = []
var _member_limit: int = MAX_ACTORS


func clear() -> void:
	_actors.clear()
	_bound_owner = []
	_bound_members = []
	_member_limit = MAX_ACTORS


# Actual Workbench observations index physical members, not authored actors.
# Keep the old unbound eight-slot API and require an explicit real-owner/member
# closure before accepting a multipart index. This never expands native admission.
func bind_members(owner: Array, members: Array) -> bool:
	if owner.size()!=3 or not owner[0] is int or int(owner[0])==0 \
			or not owner[1] is int or int(owner[1])<=0 or not owner[2] is int or int(owner[2])<=0 \
			or members.is_empty() or members.size()>MAX_MEMBERS: return false
	var identities: Array = []
	var seen: Dictionary = {}
	for member: Variant in members:
		if not member is Dictionary or not member.get("instance_id") is int \
				or int(member.instance_id)<=0 or not member.get("generation") is int \
				or int(member.generation)<=0 or seen.has(member.instance_id): return false
		seen[member.instance_id] = true
		var identity: Array = [member.instance_id,member.generation]
		identity.make_read_only()
		identities.append(identity)
	if _bound_owner==owner and _bound_members==identities: return true
	_actors.clear()
	_bound_owner = owner.duplicate()
	_bound_owner.make_read_only()
	_bound_members = identities
	_bound_members.make_read_only()
	_member_limit = members.size()
	return true


func bound_to(owner: Array) -> bool:
	return not _bound_owner.is_empty() and _bound_owner==owner


func member_matches(slot: int, instance_id: int, generation: int) -> bool:
	return slot>=0 and slot<_bound_members.size() and _bound_members[slot]==[instance_id,generation]


func observe(slot: int, instance_id: int, generation: int, step: int,
		pose: Transform2D, velocity: Vector2, angular_velocity: float,
		completed_usec: int, sample_serial: int = -1, sampled_usec: int = 0) -> Dictionary:
	if slot < 0 or slot >= _member_limit or step < 0 or not pose.is_finite() or not velocity.is_finite() \
			or not is_finite(angular_velocity) or completed_usec < 0:
		return {}
	if not _bound_members.is_empty() and not member_matches(slot,instance_id,generation): return {}
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
