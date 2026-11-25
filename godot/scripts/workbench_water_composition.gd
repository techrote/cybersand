extends RefCounted

# Value-only proof for the explicit Water actor composition layer. This is not
# permission to skip a native turn or to treat retained Water as empty space.
# Its two native joins deliberately distinguish an input consumed by the last
# completed physical step from a later closure sampled at that current step.
const VERSION: String = "workbench-water-composition-v1"


static func dependency(context: Dictionary, member: Dictionary, entry: Dictionary,
		observation: Dictionary, sampled: Dictionary, consumed: Dictionary) -> Dictionary:
	for key: String in ["session", "epoch", "world", "revision", "step", "native_tick", "sample"]:
		if not context.get(key) is int or int(context[key]) < 0: return {}
	if not context.get("bridge") is int or int(context.bridge) == 0 or int(context.step) == 0: return {}
	if not context.get("native_completed_usec") is int or int(context.native_completed_usec) <= 0: return {}
	if not observation.get("pose") is Transform2D or not Transform2D(observation.pose).is_finite(): return {}
	if observation.get("step", -1) != context.step \
			or observation.get("instance_id", -1) != member.get("instance_id", -2) \
			or observation.get("generation", -1) != member.get("generation", -2) \
			or not observation.get("completed_usec") is int or int(observation.completed_usec) <= 0:
		return {}
	if entry.get("generation", -1) != member.get("generation", -2) \
			or entry.get("sample", -1) != context.sample or not entry.get("pose") is Transform2D:
		return {}
	# A new closure can legitimately be produced after the last physical step.
	# It is not retroactively a dependency consumed by that completed step.
	if sampled.get("serial", -1) == context.sample and sampled.get("step", -1) == context.step \
			and sampled.get("session", -1) == context.session and sampled.get("epoch", -1) == context.epoch \
			and sampled.get("pose") == entry.pose and entry.pose == observation.pose:
		return {"schema":VERSION,"kind":"current_step_sampled_closure", "consumed_by_step":false,
			"step":context.step,"sample":context.sample,"native_tick":context.native_tick,
			"instance_id":member.instance_id,"generation":member.generation}
	for key: String in ["bridge", "session", "epoch", "world", "step", "native_tick", "sample"]:
		if consumed.get(key, -1) != context[key]: return {}
	if consumed.get("instance_id", -1) != member.get("instance_id", -2) \
			or consumed.get("generation", -1) != member.get("generation", -2) \
			or consumed.get("input_pose") != entry.pose or consumed.get("output_pose") != observation.pose \
			or consumed.get("completed_usec", -1) != observation.completed_usec \
			or consumed.get("native_completed_usec", -1) != context.get("native_completed_usec", -2) \
			or not consumed.get("native_response_applied") is bool or not consumed.native_response_applied:
		return {}
	return {"schema":VERSION,"kind":"consumed_native_dependency", "consumed_by_step":true,
		"step":context.step,"sample":context.sample,"native_tick":context.native_tick,
		"instance_id":member.instance_id,"generation":member.generation}
