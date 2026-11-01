extends "res://tests/support/render_copy_consumer.gd"

# Throttle only presentation admission. Main's status, input, Rapier and normal
# worker handoff continue. Ordinary publication and ACK functions stay intact.
var consumer_interval_usec: int = 0
var next_consume_usec: int = 0

func consume_render_snapshot(snapshot: CyberSimulationSnapshot) -> void:
	var now: int = Time.get_ticks_usec()
	if snapshot.render_snapshot_serial > last_uploaded_render_snapshot_serial and now < next_consume_usec:
		trace.record("consumer_delayed", {"serial": snapshot.render_snapshot_serial,
			"generation": snapshot.render_world_generation, "revision": snapshot.world_revision,
			"next_admission_usec": next_consume_usec})
		return
	var previous_serial: int = last_uploaded_render_snapshot_serial
	super.consume_render_snapshot(snapshot)
	if last_uploaded_render_snapshot_serial != previous_serial:
		next_consume_usec = now + consumer_interval_usec
		trace.record("consumer_displayed", {"serial": last_uploaded_render_snapshot_serial,
			"generation": last_uploaded_world_generation, "revision": last_uploaded_revision})
