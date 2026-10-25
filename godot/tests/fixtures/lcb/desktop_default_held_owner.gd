extends "res://scripts/prepared_reference_body_session.gd"
var permit_ready: bool = false
func ready() -> bool: return permit_ready and super.ready()
