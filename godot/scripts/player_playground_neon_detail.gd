class_name CyberPlayerPlaygroundNeonDetail
extends RefCounted

const D = preload("res://scripts/player_playground_districts.gd")
const VIEW := Rect2i(0,0,1024,768)
# Fifteen row-major bits per glyph. Signs are authored native cells, not a
# texture, shader or new gameplay object. Space has the same four-column pitch.
const FONT: Dictionary = {
	" ":"000000000000000", "A":"010101111101101", "B":"110101110101110",
	"C":"011100100100011", "D":"110101101101110", "E":"111100110100111",
	"F":"111100110100100", "G":"011100101101011", "H":"101101111101101",
	"I":"111010010010111", "J":"001001001101010", "K":"101101110101101",
	"L":"100100100100111", "M":"101111111101101", "N":"101111111111101",
	"O":"010101101101010", "P":"110101110100100", "Q":"010101101011001",
	"R":"110101110101101", "S":"011100010001110", "T":"111010010010010",
	"U":"101101101101111", "V":"101101101101010", "W":"101101111111101",
	"X":"101101010101101", "Y":"101101010010010", "Z":"111001010100111",
	"0":"111101101101111", "1":"010110010010111", "2":"110001010100111",
	"3":"110001010001110", "4":"101101111001001", "5":"111100110001110",
	"6":"011100110101010", "7":"111001010010010", "8":"010101010101010",
	"9":"010101011001110", "-":"000000111000000", "+":"000010111010000",
	"/":"001001010100100", ".":"000000000000010", ":":"000010000010000",
	"?":"110001010000010", "<":"001010100010001", ">":"100010001010100",
	"[":"110100100100110", "]":"011001001001011", "_":"000000000000111"
}


static func edge(out: Array) -> void:
	D.rect(out,0,0,1024,6,1)
	D.rect(out,0,0,6,768,1)
	D.rect(out,1018,0,6,768,1)
	D.rect(out,0,762,1024,6,1)


static func road_y(profile: Array, x: int) -> int:
	assert(profile.size() >= 2)
	for i: int in range(1,profile.size()):
		var a: Vector2i = profile[i-1]
		var b: Vector2i = profile[i]
		assert(b.x > a.x)
		if x < b.x:
			var step: int = maxi(0,(x-a.x)/4)*4
			if b.y < a.y:
				return a.y-maxi(1,roundi(float(step+4)*(a.y-b.y)/(b.x-a.x)))
			return a.y+roundi(float(step)*(b.y-a.y)/(b.x-a.x))
	return int(profile[-1].y)


static func road(out: Array, profile: Array, material: int = 58) -> void:
	assert(profile.size() >= 2)
	for i: int in range(1,profile.size()):
		var a: Vector2i = profile[i-1]
		var b: Vector2i = profile[i]
		assert(b.x > a.x)
		if a.y == b.y:
			D.rect(out,a.x,a.y,b.x-a.x,12,material)
			D.rect(out,a.x,a.y,b.x-a.x,1,61 if material in [38,41] else 59)
		elif b.y < a.y:
			D.ramp(out,a.x,a.y,b.x-a.x,a.y-b.y,material)
		else:
			D.ramp_down(out,a.x,a.y,b.x-a.x,b.y-a.y,material)


static func sign(out: Array, x: int, y: int, text: String, ink: int = 77, scale: int = 2) -> void:
	var label: String = text.to_upper()
	assert(scale >= 1 and scale <= 3 and label.length() >= 1 and label.length() <= 24)
	var pad: int = scale+1
	var width: int = (label.length()*4-1)*scale+pad*2
	var height: int = 5*scale+pad*2
	assert(VIEW.encloses(Rect2i(x,y,width,height)))
	D.rect(out,x,y,width,height,62)
	D.rect(out,x+1,y+1,width-2,height-2,72)
	D.rect(out,x+1,y+1,width-2,1,50)
	D.rect(out,x+1,y+height-2,width-2,1,ink)
	for index: int in range(label.length()):
		var letter: String = label.substr(index,1)
		assert(FONT.has(letter),"Unsupported neon sign glyph: "+letter)
		var glyph: String = FONT[letter]
		for row: int in range(5):
			for column: int in range(3):
				if glyph.substr(row*3+column,1) == "1":
					D.rect(out,x+pad+(index*4+column)*scale,y+pad+row*scale,scale,scale,ink)
