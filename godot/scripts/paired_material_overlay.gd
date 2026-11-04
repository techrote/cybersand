extends "res://scripts/player_playground_overlay.gd"

func _draw() -> void:
	super._draw()
	for item: Array in [[Vector2(80,382),"A  ALL LOOSE"],[Vector2(320,382),"B  INTACT SHELL"],[Vector2(560,382),"C  OPEN SHELL"],[Vector2(790,414),"FINITE CURING TRAY"]]:
		draw_string(ThemeDB.fallback_font,_point(item[0]),item[1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("dcebd8"))
