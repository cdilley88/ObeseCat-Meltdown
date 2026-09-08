class_name PixelCanvas
extends RefCounted

var target: Node2D
var glyphs: Dictionary
var palette: Dictionary = {}

func _init(node: Node2D) -> void:
	target = node
	glyphs = JSON.parse_string(FileAccess.get_file_as_string("res://glyphs.json"))

func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	target.draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), palette.get(c,c))

func box(x: float, y: float, w: float, h: float, c: Color, t: int = 1) -> void:
	rect(x,y,w,t,c)
	rect(x,y+h-t,w,t,c)
	rect(x,y,t,h,c)
	rect(x+w-t,y,t,h,c)

func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(-int(ry), int(ry)+1, 3):
		var span = roundf(rx * sqrt(maxf(0.0, 1.0 - float(y*y)/(ry*ry))) / 3.0) * 3.0
		rect(cx-span,cy+y,span*2,3,c)

func ring(cx: float, cy: float, radius: float, c: Color, thick: int = 2, end: float = 1.0) -> void:
	var n = maxi(1, ceili(radius*3))
	for i in range(int(n*end)):
		var a = float(i)/n * TAU - PI/2
		rect(cx+cos(a)*radius,cy+sin(a)*radius,thick,thick,c)

func text(value: String, x: float, y: float, c: Color, size: int = 1, center: bool = false) -> void:
	if center:
		x -= (value.length()*6-1)*size/2.0
	for ch in value.to_upper():
		if glyphs.has(ch):
			var glyph: String = glyphs[ch]
			for i in range(35):
				if glyph[i] == "1":
					rect(x+(i%5)*size,y+floori(i/5.0)*size,size,size,c)
		x += 6*size
