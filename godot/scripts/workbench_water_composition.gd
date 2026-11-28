extends RefCounted

# Value-only proof for the explicit Water actor composition layer. This is not
# permission to skip a native turn or to treat retained Water as empty space.
# Its two native joins deliberately distinguish an input consumed by the last
# completed physical step from a later closure sampled at that current step.
const VERSION: String = "workbench-water-composition-v2"


static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: freeze(child)
		value.make_read_only()


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


# A live completed pose and an uploaded material image have separate clocks.
# This authority joins the actual last applied native response to the current
# completed pose; it never claims that an older visible image supplied it.
static func completed_dependency(context: Dictionary, member: Dictionary,
		observation: Dictionary, consumed: Dictionary) -> Dictionary:
	for key: String in ["bridge","session","epoch","world","step","native_tick","sample","revision","rid"]:
		if not context.get(key) is int or consumed.get(key) != context[key]: return {}
	for key: String in ["instance_id","generation"]:
		if not member.get(key) is int or int(member[key]) <= 0 \
				or not consumed.get(key) is int or not observation.get(key) is int: return {}
	if not observation.get("step") is int or context.session <= 0 or context.epoch <= 0: return {}
	if context.bridge == 0 or context.rid == 0 or context.step <= 0 \
			or context.world < 0 or context.native_tick < 0 or context.sample < 0 or context.revision < 0:
		return {}
	if not consumed.get("native_response_applied") is bool or not consumed.native_response_applied: return {}
	if not context.get("rectangles") is Array or context.rectangles.is_empty(): return {}
	if consumed.get("instance_id") != member.get("instance_id") \
			or consumed.get("generation") != member.get("generation") \
			or observation.get("instance_id") != member.get("instance_id") \
			or observation.get("generation") != member.get("generation") \
			or observation.get("step") != context.step \
			or consumed.get("rectangles") != context.get("rectangles"):
		return {}
	if not observation.get("pose") is Transform2D or not Transform2D(observation.pose).is_finite() \
			or not consumed.get("input_pose") is Transform2D or not Transform2D(consumed.input_pose).is_finite() \
			or consumed.get("output_pose") != observation.pose:
		return {}
	var completed: Variant = observation.get("completed_usec")
	var native_completed: Variant = context.get("native_completed_usec")
	if not completed is int or int(completed) <= 0 or consumed.get("completed_usec") != completed \
			or context.get("completed_usec") != completed or not native_completed is int \
			or int(native_completed) <= 0 or int(native_completed) > int(completed) \
			or consumed.get("native_completed_usec") != native_completed:
		return {}
	var response: Variant = context.get("coupling_response_usec",-1)
	if not response is int or not consumed.get("coupling_response_usec",-1) is int \
			or response != consumed.get("coupling_response_usec",-1) or (response <= 0 and response != -1): return {}
	if response > 0:
		var material_sample: Variant = context.get("material_tick_body_sample")
		if not material_sample is int or not consumed.get("material_tick_body_sample") is int \
				or material_sample < 0 or material_sample >= context.sample or material_sample != consumed.material_tick_body_sample \
				or response < native_completed or response > completed: return {}
	return {"schema":VERSION,"kind":"current_completed_native_dependency","consumed_by_step":true,
		"coupling_response_usec":response,"material_tick_body_sample":context.get("material_tick_body_sample",-1),
		"physical_completion_claim":true,"step":context.step,"sample":context.sample,
		"native_tick":context.native_tick,"native_revision":context.revision,
		"native_completed_usec":native_completed,"completed_usec":completed,
		"instance_id":member.instance_id,"generation":member.generation}


# Initial paused authoring is a real owner state, not a completed Rapier step.
# Keep that distinction explicit even when its exact native closure and material
# coverage permit the initialized actor to appear under Water.
static func initialized_closure(context: Dictionary, member: Dictionary, entry: Dictionary,
		observation: Dictionary, sampled: Dictionary) -> Dictionary:
	for key: String in ["session","epoch","world","revision","native_tick","sample"]:
		if not context.get(key) is int or int(context[key]) < 0: return {}
	for key: String in ["instance_id","generation"]:
		if not member.get(key) is int or int(member[key]) <= 0 or not observation.get(key) is int: return {}
	for key: String in ["step","manual_steps","completed_usec"]:
		if not context.get(key) is int: return {}
	for key: String in ["step","completed_usec"]:
		if not observation.get(key) is int: return {}
	for key: String in ["serial","step","session","epoch","completed_usec"]:
		if not sampled.get(key) is int: return {}
	if context.session <= 0 or context.epoch <= 0 \
			or not entry.get("sample") is int or not entry.get("generation") is int: return {}
	if not context.get("bridge") is int or int(context.bridge)==0 \
			or not context.get("rid") is int or int(context.rid)==0 \
			or context.get("step") != 0 or context.get("manual_steps") != 0 \
			or not context.get("initialized") is bool or not context.initialized \
			or context.get("completed_usec") != 0 or observation.get("completed_usec") != 0:
		return {}
	if observation.get("step") != 0 or observation.get("instance_id") != member.get("instance_id") \
			or observation.get("generation") != member.get("generation") \
			or entry.get("generation") != member.get("generation") \
			or entry.get("sample") != context.sample or not entry.get("pose") is Transform2D \
			or not Transform2D(entry.pose).is_finite() or entry.pose != observation.get("pose") \
			or entry.pose != context.get("initialized_pose"):
		return {}
	if sampled.get("serial") != context.sample or sampled.get("step") != 0 \
			or sampled.get("session") != context.session or sampled.get("epoch") != context.epoch \
			or sampled.get("pose") != entry.pose or sampled.get("completed_usec") != 0:
		return {}
	return {"schema":VERSION,"kind":"initialized_authoring_closure","consumed_by_step":false,
		"physical_completion_claim":false,"completed_usec":0,"step":0,"sample":context.sample,
		"native_tick":context.native_tick,"instance_id":member.instance_id,"generation":member.generation}
