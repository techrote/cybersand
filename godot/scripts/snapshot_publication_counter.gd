extends RefCounted

# The owner's serial increases once per immutable publication across resets.
# Gaps count publications superseded before this consumer saw them, not native
# ticks, rendered frames, dropped input, or rejected render-patch payloads.
var last_serial: int = 0
var consumed: int = 0
var coalesced: int = 0
var rejected: int = 0


func observe(serial: int) -> bool:
	if serial <= last_serial:
		rejected += 1
		return false
	coalesced += serial - last_serial - 1
	consumed += 1
	last_serial = serial
	return true
