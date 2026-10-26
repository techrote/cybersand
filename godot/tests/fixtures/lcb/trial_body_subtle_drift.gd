extends "res://scripts/prepared_trial_body_session.gd"

func _capture_frozen_pose() -> bool:
	# Actual Rapier motion differs by one float32 ULP at vx7.25. The previous
	# generic relative tolerance accepted this different body input silently.
	var rid: RID=_bodies[0].get_rid()
	var velocity: Vector2=PhysicsServer2D.body_get_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
	PhysicsServer2D.body_set_state(rid,PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,velocity+Vector2(0.000000476837158203125,0))
	return super._capture_frozen_pose()
