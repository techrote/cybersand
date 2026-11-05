extends RefCounted

# Copied-value helpers, called by the fixture's exclusive main-thread owner.
static func desired() -> String:
	return OS.get_environment("SOL_NORMAL_POLICY")

static func matches(packet: Dictionary, mode: String, policy: String) -> bool:
	if packet.get("response")!=mode or packet.get("normal_policy")!=policy: return false
	if not packet.get("normal_policy_locked",false): return false
	var rows: Variant = packet.get("rows",null)
	if not rows is Array: return false
	for row: Variant in rows:
		if not row is Dictionary or row.get("normal_policy")!=policy: return false
	return true

static func configure(world: Variant, mode: String) -> bool:
	var policy: String = desired()
	if policy not in ["original","active-normal-001"]: return false
	if mode=="LA-SELECTIVE":
		if not world.diagnostic_set_workbench_normal_policy(policy): return false
	elif policy!="original": return false
	return matches(world.workbench_coupling_results(),mode,policy)

static func result(world: Variant, mode: String) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var packet: Dictionary = world.workbench_coupling_results()
	packet["getter_us"]=Time.get_ticks_usec()-start
	if not matches(packet,mode,desired()):
		packet["valid"]=false
		packet["policy_refusal"]="native normal policy mismatch"
	return packet
