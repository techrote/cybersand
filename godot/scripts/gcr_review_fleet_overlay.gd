extends "res://scripts/player_playground_overlay.gd"

var fleet_index: int = 0

func _draw() -> void:
	super._draw()
	# Instrument markings/light are decorative; the rectangular outline remains
	# the actual collider. No extra collision-less solid-looking hull is drawn.
	for part: Dictionary in _parts:
		var pose: Transform2D = part.transform
		var half: Vector2 = Vector2(part.size)*.5
		if fleet_index == 3:
			for side: float in [-.65,.65]:
				var a: Vector2 = _point(pose*Vector2(half.x*side,-half.y))
				var b: Vector2 = _point(pose*Vector2(half.x*side,half.y))
				draw_line(a,b,Color("6ffff0"),3.)
			draw_line(_point(pose*Vector2(-half.x*.9,0)),_point(pose*Vector2(half.x*.9,0)),Color("f7f1c7"),1.)
		elif fleet_index >= 4:
			var radius: float = minf(half.x,half.y)*.65
			draw_arc(_point(pose.origin),radius*size.x/_view_size.x,0.,TAU,20,Color("223848"),2.)
			draw_line(_point(pose*Vector2(-radius,0)),_point(pose*Vector2(radius,0)),Color("8af6ec"),1.)
			for side: float in [-.75,.75]:
				draw_line(_point(pose*Vector2(half.x*side,-half.y*.7)),_point(pose*Vector2(half.x*side,half.y*.7)),Color("526471"),2.)
		else:
			draw_line(_point(pose*Vector2(0,-half.y*.75)),_point(pose*Vector2(0,half.y*.55)),Color("213448"),2.)
