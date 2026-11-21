extends "res://oil_impinge_replay_base.gd"

# Copy the earlier workbench-ramp-replay.gd to res://oil_impinge_replay_base.gd
# in a scratch copy of the Windows player. Its normal named-load path installs
# the supplied bytes in private user data under the temporary alias water-ramp.
func replay() -> void:
	bench._set_view(Vector2(15, 0), Vector2i(245, 172))
	var control := OS.get_environment("CYBERSAND_IMPINGE_CONTROL") == "1"
	report.pulse_at_1500 = not control
	if not bool(report.profile.enabled) or not bool(report.profile.spill.enabled) or not bool(report.profile.spill.parcels) or int(report.profile.spill.fall) != 3:
		report.failures.append("Expected the Water gameplay profile with spill, parcels and fall 3.")
		return
	var settle := [0, 60, 180, 360, 600, 900, 1200, 1500]
	var pulse := [1501, 1508, 1516, 1532, 1560, 1620, 1800, 2100]
	if control:
		settle = [1500]
	elif DisplayServer.get_name() != "headless":
		settle = [1500]
		pulse = [1532]
	for step in settle:
		if not await advance(step) or not await checkpoint("settle-%04d" % step):
			return
	# Introduce a small second impact from open air near the left side.
	bench._brush.value = 9
	if not control and not await paint(75, 68, 3):
		return
	for step in pulse:
		if not await advance(step) or not await checkpoint("pulse-%04d" % step):
			return
