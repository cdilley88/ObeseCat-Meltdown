class_name MeltdownExplosion
extends RefCounted

const INK = Color("060a12")
const CYAN = Color("38efea")
const PINK = Color("ff48ae")
const GREEN = Color("beff59")
const HOT = Color("f5ffd5")
const SHADE = Color("365c4d")
const DURATION = 2.8

static func draw(p: PixelCanvas, age: float, reduced: bool) -> void:
	var t = maxf(0.0, age - 0.18)
	p.rect(17,195,326,279,INK)
	if age < 0.18:
		p.text("MRRP?",180,228,PINK,3,true)
		p.ellipse(180,345,20+age*200,24+age*200,HOT)
		return
	var grow = smoothstep(0.0,1.15,t)
	var rise = smoothstep(0.0,1.45,t)
	var cx = 180.0 if reduced else 180.0 + sin(t*45)*3*(1-grow)
	var top = 356.0 - rise*107
	var radius = 22.0 + grow*100
	# Expanding ground-pressure wave, followed by a rolling dust skirt.
	if not reduced:
		p.ellipse(cx,430, minf(159,t*235),maxf(3,15-t*5),CYAN)
		p.ellipse(cx,427, minf(152,t*230),maxf(2,10-t*4),INK)
	for i in range(7):
		var x = cx+(i-3)*(15+grow*18)
		p.ellipse(x,428-abs(i-3)*2,18+grow*12,9+grow*7,SHADE)
		p.ellipse(x-3,423-abs(i-3)*2,15+grow*10,6+grow*6,GREEN)
	# Roiling, tapered stem: overlapping stepped lobes, hot interior.
	for i in range(12):
		var f = i/11.0
		var y = lerpf(422,top+16,f)
		var w = (19+grow*12) + sin(f*PI)*9
		var sway = sin(i*1.9+t*3)*4*grow
		p.ellipse(cx+sway+5,y,w+6,13,PINK)
		p.ellipse(cx+sway-3,y-3,w+3,13,CYAN)
		p.ellipse(cx+sway,y-3,w,11,GREEN)
		p.ellipse(cx+sway-3,y-4,w*0.48,8,HOT)
	# Broad mushroom crown with scalloped boiling edges and a dark underside.
	p.ellipse(cx+5,top+14,radius+5,25+grow*17,PINK)
	p.ellipse(cx-4,top+5,radius+3,30+grow*19,CYAN)
	p.ellipse(cx,top+3,radius,29+grow*17,SHADE)
	for i in range(7):
		var f = (i-3)/3.0
		var x = cx+f*radius*0.72
		var y = top-12-(1-absf(f))*23*grow
		var r = 15+grow*(21-absf(f)*4)
		p.ellipse(x+3,y+5,r+4,22+grow*9,PINK)
		p.ellipse(x-3,y-2,r+2,22+grow*8,GREEN)
		p.ellipse(x-5,y-7,r*0.75,14+grow*7,HOT)
	# Pixel embers and dark convection seams give the cloud volume.
	for i in range(28):
		var x = cx+sin(i*17.3)*radius*0.83
		var y = top-12+sin(i*8.1)*21
		p.rect(x,y,5+(i%3)*3,3,GREEN if i%3 else SHADE)
	if not reduced:
		for i in range(22):
			var a = i*2.399
			var travel = minf(1.0,t/1.2)
			var x = cx+cos(a)*travel*153
			var y = 352+sin(a)*travel*112+t*t*13
			if y>197 and y<446:
				p.rect(x,y,3+i%3,3,HOT if i%2 else PINK)
		# One bounded signal tear, not a repeating full-screen strobe.
		if t<0.3:
			p.rect(19,290+t*230,320,4,CYAN)
			p.rect(29,298+t*230,300,2,PINK)
	# Collapse to static before the surviving cat is revealed.
	if age>2.2:
		var fade = clampf((age-2.2)/0.6,0.0,1.0)
		p.rect(17,195,326,259,Color(0.024,0.039,0.071,fade))
		if not reduced:
			for i in range(18):
				p.rect(25+(i*71)%270,209+(i*37)%230,12+(i%4)*9,2,Color(0.22,0.94,0.92,(1-fade)*0.6))
	p.rect(24,451,312,19,INK)
	p.text("CONTAINMENT: ABSOLUTELY NOT",180,457,PINK,1,true)
	p.text("NUCLEAR PURR DETECTED",180,493,GREEN,2,true)
	if age>0.65:
		p.text("TAP TO REBUILD",180,550,CYAN,1,true)
