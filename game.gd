extends Node2D

const INK = Color("060a12")
const PANEL = Color("0a161e")
const GRID = Color("10262b")
const CYAN = Color("38efea")
const PINK = Color("ff48ae")
const GREEN = Color("beff59")
const WHITE = Color("e0f2d6")
const MUTED = Color("648c8f")
const DARK_GREEN = Color("41643e")
const MODE_COLORS = [Color("beff59"),Color("c879ff"),Color("ff505a")]
enum Mode { READY, PLAYING, LOST }

var reactor = Reactor.new()
var p: PixelCanvas
var mode = Mode.READY
var clock = 0.0
var pulse = 0.0
var irritated = 0.0
var death_age = 0.0
var shown_charge = 0.48
var dragging = false
var muted = false
var reduced = false
var paused = false
var start = Vector2.ZERO
var finger = Vector2.ZERO
var pointer_id = -1
var best = 0
var mode_bests = [0, 0, 0]
var remark = "PLEASE PET THE FISSILE FELINE."
var speaker: AudioStreamPlayer
var tones: Dictionary = {}
var capture_mode = ""
var capture_frames = 0
const MAX_COINS = 999999
const SHOP_NAMES = ["FEDORA", "PIKACHU TAIL", "NECKTIE", "PIXEL SWORD", "PIXEL SHIELD", "MATRIX CODE", "PEG LEG", "CAST", "CAMERA", "SUNGLASSES", "EYEGLASSES", "SILVER CHAIN", "GOLD CHAIN", "EYEPATCH", "ARMY HELMET", "TOP HAT", "SNOW", "PROPELLER BEANIE", "TRAFFIC CONE", "LASER EYES", "HEADPHONES", "PIZZA SLICE", "MICROPHONE", "LEFT ROLLER SKATE", "RIGHT ROLLER SKATE", "DEVIL TAIL", "CONCERT STAGE", "RED PHASE SWORD", "BLUE PHASE SWORD", "SPACE HELMET", "SODA BOTTLE", "MILKSHAKE", "NIGHT VISION", "GUITAR NECK", "PAINT BRUSH", "PAINT PALETTE", "GAME CONTROLLER", "RADIOACTIVE", "PACO", "PEACE", "USA FLAG", "ITS LOGO", "JOLLY ROGER", "DORITO", "DOMINO", "EMBER", "Y2K PURSE", "CARDBOARD BOX", "SPIKY COLLAR", "UNDERWATER", "SPACE", "JIMOTHY"]
const SLOT_NAMES = ["HEAD", "EYES", "NECK", "LEFT ARM", "RIGHT ARM", "LEFT FOOT", "RIGHT FOOT", "TAIL", "BACKGROUND", "SYMBOL", "PET", "SPECIAL SKIN"]
const ITEM_SLOTS = [0,7,2,4,3,8,5,6,2,1,1,2,2,1,0,0,8,0,0,1,2,3,4,5,6,7,8,4,3,0,4,3,1,7,4,3,4,8,10,9,9,9,9,11,11,11,3,0,2,8,8,10]
const ITEM_MASK = (1 << 52) - 1
const SHOP_PRICES = [3,5,3,5,5,20,3,3,10,3,3,3,3,5,5,3,10,5,5,10,5,3,5,5,5,5,15,10,10,5,3,3,5,5,3,3,3,20,10,3,3,3,3,20,20,20,5,3,3,15,15,10]
const DEV_COINS_ENABLED = false # Public builds never expose the testing coin grant.
var wallets = [0, 0, 0]
var owned = [0, 0, 0]
var equipped = [0, 0, 0]
var shop_open = false
var shop_item = 0
var shop_page = 0
var shop_slot = 0
var shop_preview = true
var settings_path = "user://settings.cfg"
var shop_notice = "SELECT A COSMETIC TO PREVIEW"
var earned_coins = 0
var pattern_test = OS.has_feature("normal_pattern_test")

static func coin_reward(purrs: int) -> int:
	if purrs >= 50:
		return 3
	if purrs >= 35:
		return 2
	if purrs >= 15:
		return 1
	return 0

func wearing(item: int) -> bool:
	if shop_open and shop_preview and shop_item >= 0 and ITEM_SLOTS[item] == ITEM_SLOTS[shop_item]:
		return shop_item == item
	return (equipped[reactor.difficulty_mode] & (1 << item)) != 0

func slot_mask(slot: int) -> int:
	var mask = 0
	for i in range(SHOP_NAMES.size()):
		if ITEM_SLOTS[i] == slot:
			mask |= 1 << i
	return mask

func equip_item(item: int) -> void:
	var level = reactor.difficulty_mode
	equipped[level] = (equipped[level] & ~slot_mask(ITEM_SLOTS[item])) | (1 << item)

func slot_items() -> Array:
	var items = []
	for i in range(SHOP_NAMES.size()):
		if ITEM_SLOTS[i] == shop_slot:
			items.append(i)
	return items

func normalize_equipment(bits: int) -> int:
	var result = 0
	for slot in range(SLOT_NAMES.size()):
		for i in range(SHOP_NAMES.size()):
			if ITEM_SLOTS[i] == slot and (bits & (1 << i)):
				result |= 1 << i
				break
	return result


func _ready() -> void:
	p = PixelCanvas.new(self)
	RenderingServer.set_default_clear_color(INK)
	speaker = AudioStreamPlayer.new()
	add_child(speaker)
	tones["purr"] = tone(0.48,150,52,0.17)
	tones["grump"] = tone(0.16,220,105,0.09)
	tones["boom"] = blast_sound()
	var config = ConfigFile.new()
	if config.load(settings_path) == OK:
		mode_bests[0] = int(config.get_value("game","best_easy",config.get_value("game","best",0)))
		mode_bests[1] = int(config.get_value("game","best_normal",0))
		mode_bests[2] = int(config.get_value("game","best_hard",0))
		reactor.difficulty_mode = clampi(int(config.get_value("game","difficulty",0)),0,2)
		best = mode_bests[reactor.difficulty_mode]
		for i in range(3):
			wallets[i] = clampi(int(config.get_value("shop", "coins_"+str(i), 0)), 0, MAX_COINS)
			owned[i] = int(config.get_value("shop", "owned_"+str(i), 0)) & ITEM_MASK
			equipped[i] = normalize_equipment(int(config.get_value("shop", "equipped_"+str(i), 0)) & owned[i])
		muted = bool(config.get_value("game","muted",false))
		reduced = bool(config.get_value("game","reduced",false))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_mode = arg.trim_prefix("--capture=")
			muted = true
			if capture_mode.begins_with("normal_"):
				reactor.difficulty_mode=Reactor.Difficulty.NORMAL
			elif capture_mode.begins_with("hard_"):
				reactor.difficulty_mode=Reactor.Difficulty.HARD
			if capture_mode.begins_with("select_"):
				reactor.difficulty_mode = Reactor.DIFFICULTY_NAMES.find(capture_mode.trim_prefix("select_").to_upper())
				best = mode_bests[reactor.difficulty_mode]
			if capture_mode != "ready" and not capture_mode.begins_with("select_"):
				begin()
			if capture_mode == "safe":
				reactor.charge = 0.77
				shown_charge = 0.77
			if capture_mode in ["normal_peak", "hard_peak"]:
				reactor.score=55
				reactor.age=80.0
				reactor.drift_phase=0.3
				reactor.charge=reactor.safe_center()
				shown_charge=reactor.charge
			if capture_mode in ["drift_a", "drift_b"]:
				reactor.score = 20
				reactor.age = 2.0 if capture_mode == "drift_a" else 6.0
				reactor.drift_phase = reactor.age * reactor.drift_speed()
				reactor.charge = reactor.safe_center()
				shown_charge = reactor.charge
			if capture_mode == "purr":
				reactor.charge = 0.77
				apply_pet()
			if capture_mode in ["lost", "blast", "blast_low", "blast_early", "normal_blast", "hard_blast"]:
				reactor.tick(10)
				fail()
				death_age = 3.0 if capture_mode == "lost" else (0.55 if capture_mode == "blast_early" else 1.55)
				reduced = capture_mode == "blast_low"
				shown_charge = 0.32
	if capture_mode in ["new_ocean", "new_space"]:
		equipped = [0,0,0]
		for item in [46,47,48,49 if capture_mode == "new_ocean" else 50]:
			equip_item(item)
		shop_open = true
		shop_slot = 8
		shop_item = 49 if capture_mode == "new_ocean" else 50
		shop_page = 0
		shop_preview = true
	if capture_mode.begins_with("skin_"):
		equipped = [0,0,0]
		shop_open = true
		shop_slot = 11
		shop_item = 43+int(capture_mode.trim_prefix("skin_"))
		shop_preview = true
	if capture_mode.begins_with("symbol_"):
		shop_open = true
		shop_slot = 9
		shop_item = 39+int(capture_mode.trim_prefix("symbol_"))
		shop_preview = true
	if capture_mode == "shop_jimothy":
		equipped = [0,0,0]
		shop_open = true
		shop_slot = 10
		shop_item = 51
		clock = 1.0
	if capture_mode == "shop_paco":
		shop_open = true
		shop_slot = 10
		shop_item = 38
		clock = 1.0
	if capture_mode in ["shop", "outfit", "shop_neck", "shop_eyes", "snow_outfit"]:
		reactor.difficulty_mode = 0
		mode = Mode.READY
		wallets = [123, 0, 0]
		equipped[0] = 63
		owned[0] = 63
		shop_open = capture_mode.begins_with("shop")
		if capture_mode in ["shop_neck", "shop_eyes", "snow_outfit"]:
			owned[0] = ITEM_MASK
			equipped[0] = (1<<6)|(1<<7)|(1<<8)|(1<<10)|(1<<15)|(1<<16)
			shop_slot = 1 if capture_mode == "shop_eyes" else 2
			shop_item = 10 if shop_slot == 1 else 8
		clock = 2.5
	if capture_mode in ["concert_outfit", "shop_head_new"]:
		reactor.difficulty_mode = 0
		mode = Mode.READY
		owned[0] = ITEM_MASK
		equipped[0] = 0
		for item in [17,19,20,21,22,23,24,25,26]:
			equip_item(item)
		shop_open = capture_mode == "shop_head_new"
		shop_slot = 0
		shop_item = 18
		clock = 2.0
	if capture_mode in ["phase_outfit", "shop_arm_new", "paint_outfit", "snack_outfit"]:
		reactor.difficulty_mode = 0
		mode = Mode.READY
		owned[0] = ITEM_MASK
		equipped[0] = 0
		for item in [27,28,29,32,33,37]:
			equip_item(item)
		if capture_mode == "paint_outfit":
			equip_item(34)
			equip_item(35)
		if capture_mode == "snack_outfit":
			equip_item(30)
			equip_item(31)
		shop_open = capture_mode == "shop_arm_new"
		shop_slot = 4
		shop_item = 36
		clock = 2.0
	queue_redraw()

func tone(duration: float, from: float, to: float, volume: float) -> AudioStreamWAV:
	var data = PackedByteArray()
	var count = int(duration*22050)
	data.resize(count*2)
	var phase = 0.0
	for i in range(count):
		var t = float(i)/count
		phase += lerpf(from,to,t)/22050.0*TAU
		var sample = (sin(phase)+0.22*sin(phase*2.01))*sin(t*PI)*volume
		data.encode_s16(i*2,int(sample*32767))
	var clip = AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	clip.data = data
	return clip

func blast_sound() -> AudioStreamWAV:
	var data = PackedByteArray()
	var count = 22050*2
	data.resize(count*2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1986
	var rumble = 0.0
	var phase = 0.0
	for i in range(count):
		var t = i/22050.0
		rumble = lerpf(rumble,rng.randf_range(-1,1),0.065)
		phase += lerpf(90,24,minf(t,1.0))/22050.0*TAU
		var envelope = minf(t*70,1.0)*exp(-t*2.3)
		var sample = (rumble*0.7+sin(phase)*0.25)*envelope
		data.encode_s16(i*2,int(clampf(sample,-0.8,0.8)*32767))
	var clip = AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	clip.data = data
	return clip

func sound(key: String) -> void:
	if not muted:
		speaker.stream = tones[key]
		speaker.play()

func save_settings() -> void:
	if capture_mode != "" or pattern_test:
		return
	var config = ConfigFile.new()
	config.set_value("game","best",mode_bests[0])
	for i in range(3):
		config.set_value("game","best_"+Reactor.DIFFICULTY_NAMES[i].to_lower(),mode_bests[i])
	for i in range(3):
		config.set_value("shop", "coins_"+str(i), wallets[i])
		config.set_value("shop", "owned_"+str(i), owned[i])
		config.set_value("shop", "equipped_"+str(i), equipped[i])
	config.set_value("game","difficulty",reactor.difficulty_mode)
	config.set_value("game","muted",muted)
	config.set_value("game","reduced",reduced)
	config.save(settings_path)

func begin() -> void:
	shop_open = false
	earned_coins = 0
	reactor.reset()
	if pattern_test and reactor.difficulty_mode != Reactor.Difficulty.EASY:
		reactor.score = 55
		reactor.drift_phase = PI/2
	mode = Mode.PLAYING
	paused = false
	pulse = 0.0
	irritated = 0.0
	death_age = 0.0
	dragging = false
	shown_charge = 0.22
	remark = ["WAIT FOR THE GREEN RING.","VIOLET SHIFT. STAY FOCUSED.","RED SHIFT. HE KNOWS NO MERCY."][reactor.difficulty_mode]
	sound("purr")

func fail() -> void:
	if mode != Mode.PLAYING:
		return
	earned_coins = 0 if pattern_test else coin_reward(reactor.score)
	wallets[reactor.difficulty_mode] = mini(MAX_COINS, wallets[reactor.difficulty_mode] + earned_coins)
	mode = Mode.LOST
	death_age = 0.0
	dragging = false
	sound("boom")
	if reactor.score > best:
		best = reactor.score
		mode_bests[reactor.difficulty_mode] = best
	save_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if mode == Mode.PLAYING:
			paused = true
			dragging = false
			pointer_id = -1
			if is_instance_valid(speaker):
				speaker.stop()

func _process(delta: float) -> void:
	if capture_mode != "":
		capture_frames += 1
		if capture_frames == 4:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://captures")
			get_viewport().get_texture().get_image().save_png("res://captures/"+capture_mode+".png")
			get_tree().quit()
		return
	var dt = minf(delta,0.05)
	clock += dt
	if not paused:
		pulse = maxf(0.0,pulse-dt)
		irritated = maxf(0.0,irritated-dt)
		if mode == Mode.LOST:
			death_age += dt
		if mode == Mode.PLAYING:
			reactor.tick(dt)
			if reactor.lost:
				fail()
		var target = 0.48 if mode == Mode.READY else (0.32 if mode == Mode.LOST else reactor.charge)
		shown_charge = lerpf(shown_charge,target,1.0-exp(-dt*13))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and shop_open:
		shop_open = false
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and mode == Mode.PLAYING:
		paused = not paused
		dragging = false
	if event is InputEventScreenTouch:
		if event.pressed and pointer_id == -1:
			pointer_id = event.index
			down(event.position)
		elif not event.pressed and event.index == pointer_id:
			if not event.canceled:
				up(event.position)
			dragging = false
			pointer_id = -1
	elif event is InputEventScreenDrag and event.index == pointer_id:
		finger = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and pointer_id == -1:
		if event.pressed:
			down(event.position)
		else:
			up(event.position)
	elif event is InputEventMouseMotion and pointer_id == -1:
		finger = event.position

func down(pos: Vector2) -> void:
	if not Rect2(0,0,360,640).has_point(pos):
		return
	if shop_open:
		shop_down(pos)
		return
	if pos.y >= 589:
		if pos.x < 100:
			muted = not muted
			if muted:
				speaker.stop()
		elif pos.x >= 270:
			reduced = not reduced
		elif pos.x >= 190 and mode != Mode.PLAYING:
			shop_open = true
			shop_notice = "SELECT A COSMETIC TO PREVIEW"
			shop_preview = true
		elif mode == Mode.PLAYING:
			paused = not paused
		else:
			mode = Mode.READY
			reactor.reset()
		save_settings()
		dragging = false
		return
	if paused:
		paused = false
		dragging = false
		return
	if mode == Mode.READY:
		for i in range(3):
			if Rect2(20+i*108,496,104,44).has_point(pos):
				reactor.difficulty_mode = i
				best = mode_bests[i]
				save_settings()
				return
		begin()
		return
	if mode == Mode.LOST:
		if death_age > 0.65:
			begin()
		return
	if pos.y >= 145 and pos.y <= 560:
		start = pos
		finger = pos
		dragging = true

func up(pos: Vector2) -> void:
	var valid = dragging and not paused and mode == Mode.PLAYING and start.distance_to(pos) >= 32
	dragging = false
	if valid:
		apply_pet()

func apply_pet() -> void:
	var result = reactor.pet()
	if result == 1:
		pulse = 0.8
		sound("purr")
		remark = ["EXCELLENT. CONTINUE.","YOU WORK FOR THE CAT NOW.","VERY GOOD PETTING, HUMAN.","PURR OUTPUT: UNREASONABLE."][(reactor.score-1)%4]
		if reactor.difficulty_mode == Reactor.Difficulty.NORMAL:
			remark = ["THE VOID APPROVES.","PURRPLE HAZE. EXCELLENT WORK.","CAT HAS TRANSCENDED CONTAINMENT."][reactor.score%3]
		elif reactor.difficulty_mode == Reactor.Difficulty.HARD:
			remark = ["HE CONSIDERS THIS A WARMUP.","YOUR FEAR IMPROVES THE PETTING.","HELL HATH NO FURRY LIKE THIS."][reactor.score%3]
		if reactor.difficulty_mode != Reactor.Difficulty.EASY and reactor.score in [12,24,32]:
			remark = "CONTAINMENT SHIFT // HOLD STEADY" if reactor.difficulty_mode == Reactor.Difficulty.NORMAL else "ERRATIC CORE // TRUST NOTHING"
	elif result < 0:
		irritated = 0.75
		sound("grump")
		remark = "TOO SOON. CAT DEMANDS PATIENCE." if result == -1 else "TOO LATE. A VERY SPICY CAT."
	if reactor.lost and mode == Mode.PLAYING:
		fail()

func _draw() -> void:
	if p == null:
		return
	p.palette = theme_palette()
	p.rect(0,0,360,640,INK)
	p.rect(16,19,5,5,GREEN)
	p.text("OBESECAT / REACTOR DIVISION",29,18,MUTED)
	p.text(Reactor.DIFFICULTY_NAMES[reactor.difficulty_mode],340-6*Reactor.DIFFICULTY_NAMES[reactor.difficulty_mode].length(),18,CYAN)
	p.text("OBESECAT",20,39,WHITE,3)
	p.text("MELTDOWN",20,65,GREEN,3)
	p.rect(20,99,320,1,GRID)
	p.text("CONTROLLED PURRS",20,111,MUTED)
	p.text("%02d" % reactor.score,20,126,CYAN,3)
	p.text("COINS " + str(wallets[reactor.difficulty_mode]),128,141,Color("ffdc71"))
	p.text("PERSONAL BEST",220,111,MUTED)
	p.text("%02d" % best,302,128,WHITE,2)
	p.rect(16,164,328,314,PANEL)
	for x in range(28,340,24):
		p.rect(x,165,1,312,GRID)
	for y in range(180,475,24):
		p.rect(17,y,326,1,GRID)
	draw_background(17,190,326,260)
	corners(16,164,328,314,CYAN)
	p.text("LIVE / CONTAINMENT CAM",27,176,MUTED)
	p.rect(326,176,5,5,PINK if mode == Mode.LOST else GREEN)
	var safe = reactor.safe() and mode == Mode.PLAYING
	var ring_color = GREEN if safe else (PINK if mode == Mode.PLAYING and reactor.charge > reactor.safe_max() else CYAN)
	p.ring(180,322,121,GRID,7)
	p.ring(180,322,119,ring_color,2)
	p.ring(180,322,124,DARK_GREEN,2,0.24)
	for i in range(32):
		var a = i*PI/16
		p.rect(180+cos(a)*130,322+sin(a)*130,2,2,MUTED)
	p.rect(43,321,16,2,ring_color)
	p.rect(303,321,16,2,ring_color)
	p.rect(179,194,2,4,ring_color)
	p.rect(179,446,2,9,ring_color)
	if pulse > 0 and not reduced:
		var r = 70+(1-pulse/0.8)*165
		p.ring(180,322,r,DARK_GREEN,7)
		p.ring(180,322,r-5,GREEN,2)
	var shake = sin(clock*65)*3 if not reduced and irritated > 0 else 0.0
	if mode != Mode.LOST or death_age >= MeltdownExplosion.DURATION:
		draw_cat(180+shake,365 if mode == Mode.LOST else 326,shown_charge)
	if mode == Mode.PLAYING and reactor.charge > 0.88 and not reduced:
		for i in range(8):
			var a = clock*1.1+i*0.79
			var x = 180+cos(a)*108
			var y = 322+sin(a)*112
			p.rect(x,y,3,7,PINK)
			p.rect(x-2,y+2,7,2,GREEN)
		if sin(clock*16) > 0.82:
			p.rect(148,315,64,3,CYAN)
			for i in range(4):
				p.box(156,321+i*9,48-i*5,6,CYAN)
	if dragging:
		for i in range(12):
			var v = start.lerp(finger,i/11.0)
			p.rect(v.x-2,v.y-2,4,4,WHITE)
		p.box(finger.x-7,finger.y-7,14,14,CYAN)
	var status = "SUBJECT 01 / EXTREMELY PETTABLE"
	if mode == Mode.LOST:
		status = "SUBJECT 01 / STILL PETTABLE"
	elif mode == Mode.PLAYING:
		status = "SAFE WINDOW // SWIPE NOW" if safe else ("CRITICAL // WINDOW MISSED" if reactor.charge > reactor.safe_max() else "CHARGING // WATCH THE SAFE ZONE")
		if reactor.unsettled > 0.0:
			status = "IRRITATED // LET HIM SETTLE"
	p.rect(23,455,314,15,PANEL)
	p.text(status,180,459,GREEN if safe else MUTED,1,true)
	if mode == Mode.PLAYING:
		draw_bottom(safe)
	if pulse > 0.25 and mode == Mode.PLAYING:
		p.text("PURR",182,213,DARK_GREEN,5,true)
		p.text("PURR",180,210,GREEN,5,true)
	if irritated > 0 and mode == Mode.PLAYING:
		p.text("MRRP!",180,225,PINK,3,true)
	if mode == Mode.READY:
		p.rect(22,481,316,103,INK)
		p.text("RING LIGHTS UP? SWIPE THE CAT.",180,482,WHITE,1,true)
		var active_palette = p.palette
		p.palette = {}
		for i in range(3):
			var selected = reactor.difficulty_mode == i
			var color: Color = MODE_COLORS[i]
			p.rect(20+i*108,496,104,44,color if selected else PANEL)
			p.box(20+i*108,496,104,44,color,2 if selected else 1)
			p.text(Reactor.DIFFICULTY_NAMES[i],72+i*108,512,INK if selected else color,2,true)
		p.palette = active_palette
		button("TAP TO CLOCK IN",550,GREEN)
	if mode == Mode.LOST:
		draw_lost()
	if paused:
		p.rect(34,260,292,111,INK)
		p.box(34,260,292,111,CYAN)
		p.text("SHIFT PAUSED",180,283,CYAN,2,true)
		p.text("TAP TO RESUME",180,331,WHITE,1,true)
	p.rect(16,589,328,1,GRID)
	p.text("SOUND OFF" if muted else "SOUND ON",24,607,MUTED)
	p.text(("RESUME" if paused else "PAUSE") if mode == Mode.PLAYING else "MODES",145,607,MUTED,1,true)
	if mode != Mode.PLAYING:
		p.text("STORE",230,607,Color("ffdc71"),1,true)
	p.text("FX LOW" if reduced else "FX FULL",278,607,MUTED)
	p.text("TEST BUILD / NON-EASY STARTS AT 55" if pattern_test else "NO CATS WERE INCONVENIENCED.",180,629,DARK_GREEN,1,true)
	if shop_open:
		draw_shop()
	for y in range(0,640,3):
		p.rect(0,y,360,1,Color(0,0,0,0.04 if reduced else 0.13))

func draw_bottom(safe: bool) -> void:
	p.text("CORE PRESSURE",20,491,MUTED)
	p.text(str(roundi(reactor.charge*100))+"%",306,491,GREEN if safe else CYAN)
	p.rect(20,507,320,14,GRID)
	p.rect(20+320*reactor.safe_min(),507,320*reactor.safe_width(),14,DARK_GREEN)
	p.rect(20,511,320*reactor.charge,6,GREEN if safe else (PINK if reactor.charge>reactor.safe_max() else CYAN))
	p.box(20+320*reactor.safe_min(),505,320*reactor.safe_width(),18,GREEN)
	p.rect(20+minf(318,320*reactor.charge),504,2,20,WHITE)
	var instruction = "PET NOW" if safe else ("GIVE HIM A MOMENT" if reactor.unsettled > 0.0 else "LET HIM COOK")
	p.text(instruction,180,539,GREEN if safe else WHITE,2,true)
	p.text(remark,180,566,PINK if irritated>0 else MUTED,1,true)

func draw_cat(cx: float, cy: float, charge: float) -> void:
	var skin = active_skin()
	var fur = [GREEN,Color("ef9d35"),Color("242631"),Color("30282a")][skin]
	var shade = [DARK_GREEN,Color("a95727"),Color("11151e"),Color("17191e")][skin]
	var belly = [WHITE,Color("fff1cf"),Color("f0eadb"),Color("634032")][skin]
	var paw = belly if skin in [1,2] else fur
	var rx = 57+int(charge*64)
	var ry = 48+int(charge*53)
	cy += sin(pulse*12)*4 if pulse>0 else sin(clock*2)*2
	p.ellipse(cx+3,414,rx-10,9,INK)
	if wearing(33):
		var tx = cx+rx+5
		p.rect(tx-4,cy-43,10,78,Color("825039"))
		p.rect(tx-7,cy-57,16,20,Color("bc8f54"))
		for fret in range(9):
			p.rect(tx-4,cy-38+fret*8,10,1,Color("d9c4a0"))
		for string in range(3):
			p.rect(tx-2+string*3,cy-53,1,83,Color("e3d9bb"))
		for peg in range(3):
			p.rect(tx-11,cy-55+peg*6,5,3,Color("a0b5c1"))
			p.rect(tx+9,cy-55+peg*6,5,3,Color("a0b5c1"))
	elif wearing(25):
		var red = Color("d84664")
		for step in range(12):
			p.rect(cx+rx-8+sin(step*0.17)*20,cy+28-step*4,7,7,red)
		for step in range(6):
			p.rect(cx+rx+7-step*2,cy-30+step*3,5+step*4,3,red)
	elif wearing(1):
		var gold = Color("ffe047")
		p.rect(cx+rx-4,cy+15,12,29,Color("ad743c"))
		p.rect(cx+rx,cy+6,21,16,gold)
		p.rect(cx+rx+10,cy-9,13,21,gold)
		p.rect(cx+rx+4,cy-22,24,16,gold)
		p.rect(cx+rx+14,cy-40,17,21,gold)
	elif skin > 0:
		draw_mascot_tail(cx+rx-8,cy,skin,fur,belly)
	else:
		p.box(cx+rx-10,cy+17,28,36,PINK,9)
		p.rect(cx+rx+9,cy+7,9,25,fur)
	p.ellipse(cx+4,cy+5,rx+5,ry+5,PINK)
	p.ellipse(cx-3,cy-3,rx+3,ry+3,CYAN)
	p.ellipse(cx,cy,rx,ry,shade)
	p.ellipse(cx-3,cy-9,rx-3,ry-7,fur)
	p.ellipse(cx,cy+10,maxi(30,rx-25),maxi(25,ry-16),belly)
	if skin > 0:
		draw_coat_marks(cx,cy,rx,ry,skin)
	var hy = cy-ry+1
	p.rect(cx-40,hy-27,80,57,INK)
	p.rect(cx-35,hy-31,20,17,INK)
	p.rect(cx+15,hy-31,20,17,INK)
	p.rect(cx-35,hy-25,17,27,fur)
	p.rect(cx+18,hy-25,17,27,fur)
	p.rect(cx-29,hy-18,8,14,PINK)
	p.rect(cx+22,hy-18,8,14,PINK)
	p.rect(cx-35,hy-4,70,31,fur)
	p.rect(cx-30,hy+25,60,7,fur)
	if skin > 0:
		draw_mascot_face_marks(cx,hy,skin,belly)
	var pleased = pulse>0 or mode!=Mode.PLAYING
	p.rect(cx-23,hy+7,12,4,INK)
	p.rect(cx+11,hy+7,12,4,INK)
	if not pleased:
		p.rect(cx-19,hy+7,4,9,INK)
		p.rect(cx+15,hy+7,4,9,INK)
		if reactor.difficulty_mode == Reactor.Difficulty.HARD:
			p.rect(cx-25,hy+1,7,3,INK)
			p.rect(cx-18,hy+4,7,3,INK)
			p.rect(cx+11,hy+4,7,3,INK)
			p.rect(cx+18,hy+1,7,3,INK)
		elif reactor.difficulty_mode == Reactor.Difficulty.NORMAL:
			p.rect(cx-24,hy+1,14,2,INK)
	else:
		p.rect(cx-25,hy+10,4,3,INK)
		p.rect(cx+21,hy+10,4,3,INK)
	p.rect(cx-3,hy+15,6,4,PINK)
	p.rect(cx-1,hy+19,2,5,INK)
	p.rect(cx-7,hy+23,6,2,INK)
	p.rect(cx+1,hy+23,6,2,INK)
	if skin > 0:
		# Bright, alert eyes fit the existing eyewear anchors.
		for side in [-1,1]:
			var ex = cx+side*17
			p.rect(ex-7,hy+4,14,13,Color("fff1b8"))
			p.rect(ex-2,hy+6,4,9,Color("20202a"))
			p.rect(ex-4,hy+5,2,3,Color("ffffff"))
			if pulse > 0:
				p.rect(ex-7,hy+4,14,7,fur)
		if skin == 1:
			p.rect(cx-5,hy+24,10,6,Color("dc8190"))
		if not has_neck_cosmetic() and skin in [2,3]:
			p.rect(cx-27,hy+31,54,6,Color("e7658e") if skin == 2 else Color("6dc9eb"))
			p.box(cx+9,hy+30,9,8,Color("f6cb58"),2)
			if skin == 3:
				p.ellipse(cx,hy+43,5,5,Color("f6cb58"))
	p.rect(cx-48,hy+15,17,2,CYAN)
	p.rect(cx+32,hy+15,17,2,CYAN)
	p.rect(cx-44,hy+22,13,2,CYAN)
	p.rect(cx+32,hy+22,13,2,CYAN)
	p.ellipse(cx-rx+24,cy+10,12,9,shade)
	p.ellipse(cx+rx-24,cy+10,12,9,shade)
	if wearing(24):
		draw_skate(cx-21,cy+ry)
	elif wearing(7): # Right foot: viewer's left.
		p.rect(cx-34,cy+ry-9,27,17,Color("eff2e5"))
		for line in range(3):
			p.rect(cx-32,cy+ry-6+line*5,23,1,Color("a7b7ba"))
		p.rect(cx-34,cy+ry+4,9,4,Color("d283a3"))
	else:
		p.rect(cx-32,cy+ry-5,23,10,paw)
	if wearing(23):
		draw_skate(cx+21,cy+ry)
	elif wearing(6): # Left foot: viewer's right.
		p.rect(cx+12,cy+ry-7,17,6,Color("bcc6cd"))
		p.rect(cx+17,cy+ry-1,8,14,Color("9c6745"))
		p.rect(cx+19,cy+ry,2,12,Color("d8a06a"))
		p.rect(cx+15,cy+ry+12,12,3,Color("493729"))
	else:
		p.rect(cx+9,cy+ry-5,23,10,paw)
	if wearing(38):
		draw_paco(cx+112,cy+ry+5)
	elif wearing(51):
		draw_jimothy(cx+112,cy+ry+5)
	draw_chest_symbol(cx,cy+18)
	p.rect(cx-36,cy-12,5,5,Color("f7ffea"))
	if wearing(0):
		p.rect(cx-29,hy-40,58,22,Color("815841"))
		p.rect(cx-23,hy-45,46,9,Color("a47b51"))
		p.rect(cx-29,hy-25,58,7,Color("342c38"))
		p.rect(cx-43,hy-18,86,7,Color("ba9264"))
	if wearing(2):
		p.rect(cx-24,hy+30,48,4,Color("4b263c"))
		p.rect(cx-5,hy+32,10,9,Color("ff6587"))
		p.rect(cx-4,hy+42,8,21,Color("c13264"))
		p.rect(cx-7,hy+57,14,9,Color("ff6587"))
	if wearing(3): # Cat's right hand is on the viewer's left.
		var hand = cx-rx+24
		p.rect(hand-5,cy-40,10,45,Color("789cb6"))
		p.rect(hand-2,cy-44,5,47,Color("dcffff"))
		p.rect(hand-13,cy+2,26,5,Color("ffdc71"))
		p.rect(hand-3,cy+7,6,17,Color("916345"))
		p.ellipse(hand,cy+11,6,5,fur)
	if wearing(4):
		var hand = cx+rx-24
		p.rect(hand-18,cy-7,36,32,Color("6e879c"))
		p.rect(hand-12,cy+25,24,7,Color("6e879c"))
		p.rect(hand-6,cy+32,12,5,Color("6e879c"))
		p.rect(hand-13,cy-2,26,23,Color("283e61"))
		p.rect(hand-2,cy,4,27,Color("ffdc71"))
		p.rect(hand-10,cy+8,20,4,Color("ffdc71"))

	if wearing(14):
		p.ellipse(cx,hy-20,37,24,Color("526143"))
		p.rect(cx-39,hy-20,78,10,Color("344531"))
		p.rect(cx-27,hy-36,14,6,Color("78845b"))
		p.rect(cx+10,hy-31,18,7,Color("303e32"))
		p.rect(cx-4,hy-33,8,9,Color("b4b88a"))
	if wearing(15):
		p.rect(cx-27,hy-54,54,38,Color("171e30"))
		p.rect(cx-23,hy-50,6,26,Color("43506b"))
		p.rect(cx-27,hy-24,54,8,Color("c44769"))
		p.rect(cx-40,hy-16,80,7,Color("28334b"))
	if wearing(8):
		# Strap descends from both shoulders to the camera body.
		for step in range(15):
			p.rect(cx-25+step,hy+30+step,4,4,Color("353448"))
			p.rect(cx+21-step,hy+30+step,4,4,Color("353448"))
		p.rect(cx-19,hy+44,38,23,Color("353d50"))
		p.rect(cx-15,hy+40,11,5,Color("96a6b8"))
		p.rect(cx+10,hy+47,6,4,Color("fff0b4"))
		p.ellipse(cx,hy+55,9,9,Color("a9bbc6"))
		p.ellipse(cx,hy+55,6,6,Color("162c44"))
		p.rect(cx-3,hy+51,4,4,Color("76d7e9"))
	if wearing(11) or wearing(12):
		var metal = Color("f1c957") if wearing(12) else Color("c5d4e0")
		for link in range(11):
			var lx = cx-25+link*5
			var ly = hy+32+sin(link*PI/10)*13
			p.box(lx-3,ly,7,6,metal,2)
		p.rect(cx-3,hy+49,7,9,metal)
	if wearing(9):
		p.rect(cx-29,hy+4,24,12,Color("141b2c"))
		p.rect(cx+5,hy+4,24,12,Color("141b2c"))
		p.rect(cx-5,hy+6,10,3,Color("141b2c"))
		p.rect(cx-25,hy+6,10,2,Color("5c819b"))
		p.rect(cx+9,hy+6,10,2,Color("5c819b"))
	if wearing(10):
		p.box(cx-29,hy+2,24,17,Color("445165"),3)
		p.box(cx+5,hy+2,24,17,Color("445165"),3)
		p.rect(cx-5,hy+7,10,3,Color("445165"))
		p.rect(cx-25,hy+5,6,2,Color("e2faff"))
		p.rect(cx+9,hy+5,6,2,Color("e2faff"))
	if wearing(13): # Cat's right eye: viewer's left.
		for step in range(18):
			p.rect(cx-35+step*4,hy+19-step,5,3,Color("262334"))
		p.rect(cx-29,hy+3,23,14,Color("191b28"))
		p.rect(cx-25,hy+17,15,4,Color("191b28"))

	if wearing(17):
		p.ellipse(cx,hy-20,35,19,Color("467cb7"))
		p.rect(cx-35,hy-22,70,9,Color("efbd4c"))
		p.rect(cx-10,hy-37,20,15,Color("e76069"))
		p.rect(cx-2,hy-47,4,11,Color("b8d7d8"))
		var rotor = 28.0 if reduced else 9.0+19.0*absf(cos(clock*9))
		p.rect(cx-rotor,hy-48,rotor,4,Color("66d8c2"))
		p.rect(cx,hy-48,rotor,4,Color("f28b65"))
	if wearing(18):
		for row in range(14):
			var width = 5+row*3
			p.rect(cx-width/2.0,hy-58+row*3,width,3,Color("f7eee0") if row in [5,6,10,11] else Color("f78835"))
		p.rect(cx-31,hy-16,62,7,Color("d45e29"))
	if wearing(19):
		var power = 0.65 if reduced else 0.65+0.2*sin(clock*3)
		for side in [-1,1]:
			var eye = cx+side*17
			p.ellipse(eye,hy+10,13,10,Color(1,0.05,0.13,0.16*power))
			p.rect(eye-7,hy+7,14,6,Color("ec244a"))
			p.rect(eye-5,hy+9,10,2,Color("ffe0d8"))
			p.rect(eye+(-28 if side<0 else 7),hy+9,21,2,Color(1,0.12,0.2,0.45*power))
	if wearing(20):
		p.box(cx-29,hy+26,58,30,Color("283449"),6)
		p.rect(cx-32,hy+26,16,26,Color("1c2333"))
		p.rect(cx+16,hy+26,16,26,Color("1c2333"))
		p.rect(cx-29,hy+30,9,17,Color("ba71d5"))
		p.rect(cx+20,hy+30,9,17,Color("ba71d5"))
	if wearing(21):
		var hand = cx+rx-24
		for row in range(13):
			p.rect(hand-18+row,cy-22+row*3,36-row*2,3,Color("f3c955"))
		p.rect(hand-20,cy-25,40,7,Color("c98544"))
		for spot in [Vector2(-9,-10),Vector2(8,-8),Vector2(0,5)]:
			p.ellipse(hand+spot.x,cy+spot.y,4,4,Color("c44b42"))
		p.ellipse(hand,cy+17,6,4,fur)
	if wearing(22):
		var hand = cx-rx+24
		p.rect(hand-4,cy-12,8,34,Color("344154"))
		p.ellipse(hand,cy-19,10,13,Color("a5bcc4"))
		for row in range(4):
			p.rect(hand-7,cy-27+row*5,14,2,Color("4c6471"))
		p.rect(hand-2,cy-3,4,4,Color("de677e"))
		p.ellipse(hand,cy+12,6,5,fur)

	if wearing(27):
		draw_phase_sword(cx-rx+24,cy,Color("fa4564"))
	if wearing(28):
		draw_phase_sword(cx+rx-24,cy,Color("4bafff"))
	if wearing(29):
		p.ellipse(cx,hy-3,49,45,Color(0.42,0.74,0.86,0.10))
		for segment in range(100):
			var angle = segment*TAU/100
			p.rect(cx+cos(angle)*48,hy-3+sin(angle)*44,3,3,Color("9aafc2"))
		p.rect(cx-36,hy+29,72,9,Color("71899e"))
		p.rect(cx-31,hy+30,62,3,Color("cfe4e4"))
		p.rect(cx-44,hy-9,8,20,Color("53687b"))
		p.rect(cx+37,hy-9,8,20,Color("53687b"))
		p.rect(cx-31,hy-28,3,13,Color("d5f5f7"))
		p.rect(cx-27,hy-33,12,3,Color("d5f5f7"))
	if wearing(30):
		var hand = cx-rx+24
		p.rect(hand-5,cy-34,10,9,Color("e7676a"))
		p.rect(hand-4,cy-25,8,8,Color("a1c3c0"))
		p.rect(hand-9,cy-17,18,35,Color("513339"))
		p.rect(hand-9,cy-6,18,13,Color("d75560"))
		p.text("POP",hand,cy-3,Color("fff1dc"),1,true)
		p.rect(hand-6,cy-15,2,8,Color("9c7871"))
		p.ellipse(hand,cy+15,6,4,fur)
	if wearing(31):
		var hand = cx+rx-24
		for row in range(10):
			p.rect(hand-13+row/3.0,cy-8+row*3,26-row*0.66,3,Color("e6a8bf"))
		p.rect(hand+5,cy-35,3,23,Color("e16c84"))
		p.rect(hand+5,cy-35,10,3,Color("e16c84"))
		p.ellipse(hand,cy-10,15,7,Color("f9ead8"))
		p.ellipse(hand-2,cy-16,10,7,Color("f9ead8"))
		p.ellipse(hand,cy-21,3,3,Color("d24e69"))
		p.rect(hand-5,cy+1,3,13,Color("fff0e2"))
		p.ellipse(hand,cy+18,6,4,fur)
	if wearing(32):
		p.rect(cx-35,hy+2,70,7,Color("34473d"))
		for side in [-1,1]:
			var eye = cx+side*17
			p.rect(eye-13,hy,26,20,Color("263d38"))
			p.box(eye-10,hy+3,20,14,Color("719d70"),2)
			p.rect(eye-7,hy+5,14,10,Color("97e788"))
			p.rect(eye-4,hy+6,3,7,Color("d5ffd3"))
	if wearing(34):
		var hand = cx-rx+24
		p.rect(hand-3,cy-12,6,34,Color("b98955"))
		p.rect(hand-7,cy-20,14,11,Color("91a6b6"))
		p.rect(hand-6,cy-34,12,15,Color("c79a69"))
		p.rect(hand-6,cy-34,12,6,Color("bf6ede"))
		p.rect(hand-4,cy-38,8,5,Color("bf6ede"))
		p.ellipse(hand,cy+12,6,5,fur)
	if wearing(35):
		var hand = cx+rx-24
		p.ellipse(hand,cy+1,23,18,Color("cda16a"))
		p.ellipse(hand+11,cy+6,5,6,Color("554631"))
		var paints = [Color("e45a69"),Color("f1d267"),Color("74b875"),Color("5d9edb"),Color("b477c9")]
		for dab in range(5):
			var angle = PI+dab*PI/4
			p.ellipse(hand+cos(angle)*15,cy+sin(angle)*11,4,4,paints[dab])
		p.ellipse(hand+11,cy+8,4,4,fur)
	if wearing(36):
		var hand = cx-rx+24
		p.rect(hand-19,cy-10,38,19,Color("8793b0"))
		p.ellipse(hand-15,cy+7,8,11,Color("8793b0"))
		p.ellipse(hand+15,cy+7,8,11,Color("8793b0"))
		p.rect(hand-15,cy-4,12,4,Color("263347"))
		p.rect(hand-11,cy-8,4,12,Color("263347"))
		p.rect(hand+8,cy-6,4,4,Color("db5f80"))
		p.rect(hand+14,cy,4,4,Color("63d9c1"))
		p.rect(hand-2,cy,4,2,Color("263347"))
		p.ellipse(hand,cy+12,6,4,fur)
	if wearing(46):
		var hand = cx+rx-24
		p.box(hand-13,cy-8,27,25,Color("d6d9ee"),3)
		p.rect(hand-20,cy+8,40,27,Color("ba6fbc"))
		p.rect(hand-16,cy+10,32,20,Color("f0a7df"))
		p.rect(hand-16,cy+10,32,6,Color("9c64bd"))
		p.box(hand-4,cy+14,9,7,Color("efe4ab"),2)
		p.rect(hand+12,cy+22,2,9,Color("f9eaff"))
		p.rect(hand+9,cy+25,8,2,Color("f9eaff"))
		p.ellipse(hand,cy+9,5,4,paw)
	if wearing(47):
		p.rect(cx-40,hy-40,80,29,Color("8f603b"))
		p.rect(cx-36,hy-37,72,22,Color("c99559"))
		p.rect(cx-4,hy-37,9,22,Color("e5c58a"))
		p.rect(cx-45,hy-14,40,7,Color("ddb47a"))
		p.rect(cx+5,hy-14,40,7,Color("b9844e"))
		p.text("UP",cx-26,hy-30,Color("70472e"))
		p.rect(cx+22,hy-30,2,11,Color("70472e"))
		p.rect(cx+19,hy-30,8,2,Color("70472e"))
	if wearing(48):
		p.rect(cx-29,hy+30,58,9,Color("24232e"))
		p.rect(cx-28,hy+32,56,2,Color("675065"))
		for spike in range(7):
			var sx = cx-25+spike*8
			p.rect(sx,hy+35,6,4,Color("acb9c9"))
			p.rect(sx+1,hy+39,4,3,Color("e1e9ef"))
			p.rect(sx+2,hy+42,2,3,Color("e1e9ef"))

func draw_lost() -> void:
	if death_age < MeltdownExplosion.DURATION:
		MeltdownExplosion.draw(p,death_age,reduced)
		return
	p.rect(29,205,302,76,INK)
	p.box(29,205,302,76,PINK)
	p.text("FACILITY: LOST",180,219,PINK,2,true)
	p.text("CAT: FINE",180,250,GREEN,2,true)
	p.rect(22,481,316,103,INK)
	p.text("EXCELLENT PETTING. SAME TIME TOMORROW?",180,487,WHITE,1,true)
	p.text(str(reactor.score)+" PURRS / "+str(floori(reactor.age))+" SECONDS",180,510,CYAN,1,true)
	var coin_fade = clampf((death_age - MeltdownExplosion.DURATION) * 3.0, 0.0, 1.0)
	var coin_color = Color(1.0, 0.862, 0.443, coin_fade)
	p.text("COINS EARNED",180,522,coin_color,1,true)
	p.text("+%d  /  %s WALLET" % [earned_coins, Reactor.DIFFICULTY_NAMES[reactor.difficulty_mode]],180,536,coin_color,1,true)
	button("TAP TO REBUILD",550,GREEN)

func button(label: String, y: int, color: Color) -> void:
	p.rect(43,y,274,34,color)
	p.text(label,180,y+11,INK,2,true)

func theme_palette() -> Dictionary:
	if reactor.difficulty_mode == Reactor.Difficulty.EASY:
		return {}
	var hard = reactor.difficulty_mode == Reactor.Difficulty.HARD
	return {
		GREEN: MODE_COLORS[reactor.difficulty_mode],
		DARK_GREEN: Color("87313e") if hard else Color("643b89"),
		Color("365c4d"): Color("612530") if hard else Color("462861"),
		Color("f5ffd5"): Color("ffe5d9") if hard else Color("f6dcff"),
		Color("f7ffea"): Color("ffe8df") if hard else Color("f8eaff"),
		WHITE: Color("ffe5e5") if hard else Color("ede2ff")
	}

func corners(x: int,y: int,w: int,h: int,color: Color) -> void:
	for corner in [Vector2(x,y),Vector2(x+w-16,y),Vector2(x,y+h-2),Vector2(x+w-16,y+h-2)]:
		p.rect(corner.x,corner.y,16,2,color)
	for corner in [Vector2(x,y),Vector2(x+w-2,y),Vector2(x,y+h-16),Vector2(x+w-2,y+h-16)]:
		p.rect(corner.x,corner.y,2,16,color)

func draw_code(x: int, y: int, w: int, h: int) -> void:
	for column in range(w / 14):
		for row in range(10):
			var offset = 0.0 if reduced else clock * (18 + column % 4 * 7)
			var py = y + fposmod(row * 23 + column * 31 + offset, h - 8)
			p.text(str((column * 7 + row * 3) % 10), x + column * 14, py, Color("63d18c") if row == 0 else Color("173c2a"))

func shop_down(pos: Vector2) -> void:
	if Rect2(26,97,76,28).has_point(pos):
		equipped[reactor.difficulty_mode] = 0
		shop_preview = false
		shop_notice = "DEFAULT RESTORED / THIS MODE"
		save_settings()
		return
	if Rect2(20,586,320,40).has_point(pos):
		shop_open = false
		return
	for slot in range(SLOT_NAMES.size()):
		if Rect2(20+(slot%3)*108,270+(slot/3)*24,104,22).has_point(pos):
			shop_page = 0
			shop_slot = slot
			var choices = slot_items()
			shop_item = choices[0] if not choices.is_empty() else -1
			shop_preview = true
			shop_notice = "ONE ITEM PER SLOT / " + SLOT_NAMES[slot]
			return
	var items = slot_items()
	if items.size() > 6 and Rect2(20,470,320,22).has_point(pos):
		var pages = ceili(items.size()/6.0)
		shop_page = posmod(shop_page + (-1 if pos.x < 180 else 1),pages)
		return
	for index in range(mini(6,items.size()-shop_page*6)):
		if Rect2(20+(index%2)*164,374+(index/2)*32,156,30).has_point(pos):
			shop_item = items[index+shop_page*6]
			shop_preview = true
			shop_notice = "PREVIEW / " + SHOP_NAMES[shop_item]
			return
	if shop_item < 0:
		return
	var level = reactor.difficulty_mode
	var bit = 1 << shop_item
	if Rect2(20,494,320,42).has_point(pos):
		if (owned[level] & bit) != 0:
			shop_preview = false
			if equipped[level] & bit:
				equipped[level] &= ~bit
			else:
				equip_item(shop_item)
			shop_notice = "EQUIPPED" if (equipped[level] & bit) else "UNEQUIPPED"
		elif wallets[level] >= SHOP_PRICES[shop_item]:
			shop_preview = false
			wallets[level] -= SHOP_PRICES[shop_item]
			owned[level] |= bit
			equip_item(shop_item)
			shop_notice = "PURCHASED / EQUIPPED"
		else:
			shop_notice = "NEED %d MORE COINS" % (SHOP_PRICES[shop_item] - wallets[level])
		save_settings()
	if DEV_COINS_ENABLED and Rect2(20,542,320,36).has_point(pos):
		wallets[level] = MAX_COINS
		shop_notice = "DEV / CURRENT WALLET MAXED"
		save_settings()

func draw_shop() -> void:
	var level = reactor.difficulty_mode
	var gold = Color("ffdc71")
	p.rect(0,0,360,640,INK)
	p.text("REACTOR SUPPLY",20,20,gold,3)
	p.text("%s ONLY / %d COINS" % [Reactor.DIFFICULTY_NAMES[level], wallets[level]],20,51,WHITE)
	p.text("EARN 1 AT 15 / 2 AT 35 / 3 AT 50 PURRS",20,70,MUTED)
	p.rect(20,91,320,154,PANEL)
	draw_background(21,92,318,153)
	p.box(20,91,320,154,GRID)
	# Render the actual equipped cat plus the selected preview at half scale.
	draw_set_transform(Vector2(90,83),0,Vector2(0.5,0.5))
	draw_cat(180,190,0.48)
	draw_set_transform(Vector2.ZERO)
	p.rect(26,97,76,28,PANEL)
	p.box(26,97,76,28,CYAN)
	p.text("DEFAULT",64,107,CYAN,1,true)
	p.text(("PREVIEW / " + SHOP_NAMES[shop_item]) if shop_item >= 0 and shop_preview else ("DEFAULT / RADIATION" if equipped[level] == 0 else "CURRENT OUTFIT"),180,231,gold,1,true)
	p.text(shop_notice,180,253,CYAN,1,true)
	for slot in range(SLOT_NAMES.size()):
		var x = 20+(slot%3)*108
		var y = 270+(slot/3)*24
		p.rect(x,y,104,22,gold if slot == shop_slot else PANEL)
		p.box(x,y,104,22,gold if slot == shop_slot else GRID)
		p.text(SLOT_NAMES[slot],x+52,y+7,INK if slot == shop_slot else MUTED,1,true)
	var items = slot_items()
	for index in range(mini(6,items.size()-shop_page*6)):
		var i: int = items[index+shop_page*6]
		var x = 20+(index%2)*164
		var y = 374+(index/2)*32
		var active = (equipped[level] & (1 << i)) != 0
		p.rect(x,y,156,30,PANEL)
		p.box(x,y,156,30,gold if shop_item == i else GRID,2)
		p.text(SHOP_NAMES[i],x+8,y+6,WHITE)
		p.text("ON" if active else ("OWNED" if (owned[level] & (1 << i)) else str(SHOP_PRICES[i])+" COINS"),x+8,y+20,CYAN if active else gold)
	if items.size() > 6:
		p.box(20,470,156,22,CYAN)
		p.box(184,470,156,22,CYAN)
		p.text("< PREV",98,478,CYAN,1,true)
		p.text("NEXT >  %d/%d" % [shop_page+1,ceili(items.size()/6.0)],262,478,CYAN,1,true)
	if shop_item < 0:
		p.text("RADIATION / DEFAULT" if shop_slot == 9 else "SPECIAL SKINS / COMING SOON",180,409,gold,1,true)
		p.text("YOUR ORIGINAL CHEST EMBLEM" if shop_slot == 9 else "THREE CATS. THREE NEW LOOKS.",180,434,MUTED,1,true)
		p.box(20,586,320,40,CYAN)
		p.text("BACK TO CAT",180,600,CYAN,2,true)
		return
	var has_item = (owned[level] & (1 << shop_item)) != 0
	var active = (equipped[level] & (1 << shop_item)) != 0
	p.rect(20,494,320,42,gold)
	p.text(("UNEQUIP" if active else "EQUIP") if has_item else "BUY / %d COINS" % SHOP_PRICES[shop_item],180,508,INK,2,true)
	if DEV_COINS_ENABLED:
		p.box(20,542,320,36,MUTED)
		p.text("DEV / MAX COINS (THIS MODE)",180,556,MUTED,1,true)
	p.box(20,586,320,40,CYAN)
	p.text("BACK TO CAT",180,600,CYAN,2,true)

func draw_background(x: int, y: int, w: int, h: int) -> void:
	if wearing(49):
		var time = 0.0 if reduced else clock
		p.rect(x,y,w,h,Color("092330"))
		for band in range(6):
			p.rect(x,y+band*h/6.0,w,h/6.0,Color(0.03,0.26-band*0.025,0.34-band*0.025))
		for plant in range(9):
			for leaf in range(8):
				p.rect(x+12+plant*(w-30)/9.0+sin(time*1.2+leaf*0.5+plant)*4,y+h-6-leaf*4,4,5,Color("23645d"))
		for bubble in range(18):
			var bx = x+8+fposmod(bubble*47+sin(time+bubble)*4,w-18)
			var by = y+8+fposmod(bubble*31-time*(8+bubble%3*4),h-18)
			p.ring(bx,by,2+bubble%3,Color("538993"),1)
		for fish in range(4):
			var fx = x+10+fposmod(fish*83+time*(6+fish),w-30)
			var fy = y+25+fish*(h-50)/4.0
			p.ellipse(fx,fy,6,3,Color("b69369"))
			p.rect(fx-9,fy-3,3,6,Color("b69369"))
	elif wearing(50):
		var time = 0.0 if reduced else clock
		p.rect(x,y,w,h,Color("0b1027"))
		for star in range(65):
			var sx = x+3+fposmod(star*73+time*(1+star%3),w-8)
			var sy = y+3+fposmod(star*47,h-8)
			var glow = 0.5+0.25*sin(time*1.5+star)
			p.rect(sx,sy,2,2,Color(0.7,0.77,1.0,glow))
		p.ellipse(x+w-43,y+36,22,20,Color("655182"))
		p.ellipse(x+w-46,y+32,16,15,Color("91769b"))
		for ring in range(40):
			var angle = ring*TAU/40
			p.rect(x+w-43+cos(angle)*31,y+36+sin(angle)*8,3,2,Color("ba9fa6"))
	elif wearing(5):
		draw_code(x,y,w,h)
	elif wearing(37):
		var time = 0.0 if reduced else clock
		for stripe in range(w/20):
			p.rect(x+stripe*20,y,10,4,Color("6a6633"))
			p.rect(x+stripe*20,y+h-4,10,4,Color("6a6633"))
		# Slow radioactive trefoils and rising particles stay behind the cat.
		for sign in range(3):
			var sx = x+35+sign*(w-70)/2.0
			var sy = y+35+(sign%2)*(h-80)
			for blade in range(3):
				for step in range(10):
					var angle = time*0.25+blade*TAU/3+step*0.09
					for radius in range(10,23,3):
						p.rect(sx+cos(angle)*radius,sy+sin(angle)*radius,3,3,Color("344a25"))
			p.ellipse(sx,sy,5,5,Color("73894a"))
		for mote in range(24):
			var px = x+fposmod(mote*47+sin(time+mote)*4,w-3)
			var py = y+fposmod(mote*31-time*(7+mote%4*3),h-5)
			p.rect(px,py,2,3,Color("618b3d"))
	elif wearing(26):
		var time = 0.0 if reduced else clock
		for lamp in range(4):
			var lx = x+30+lamp*(w-60)/3.0
			var aim = clampf(lx+sin(time*0.7+lamp*1.9)*w*0.28,x+20,x+w-20)
			var tint = [Color("9856bd"),Color("428dba"),Color("b9567c"),Color("c49e52")][lamp]
			for row in range(0,h-25,4):
				var fraction = float(row)/h
				p.rect(lerpf(lx,aim,fraction)-fraction*22,y+row,3+fraction*44,4,Color(tint,0.13))
			p.rect(lx-6,y,12,6,tint)
		for fan in range(w/16):
			var fx = x+8+fan*16
			var bounce = 0.0 if reduced else sin(time*1.8+fan)*2
			var fy = y+h-13+bounce+fan%3*2
			p.ellipse(fx,fy-7,5,6,Color("131a2a"))
			p.rect(fx-6,fy,12,y+h-fy,Color("131a2a"))
			if fan%3 == 0:
				p.rect(fx-10,fy-15,3,20,Color("131a2a"))
	elif wearing(16):
		var time = 0.0 if reduced else clock
		for flake in range(44):
			var speed = 9 + flake % 4 * 6
			var px = x + fposmod(flake*47 + sin(time*0.6+flake)*8, w-5)
			var py = y + fposmod(flake*31 + time*speed, h-5)
			var tint = Color("7e9daa") if flake%3 else Color("d3edf3")
			p.rect(px,py,2,2,tint)
			if flake%4 == 0:
				p.rect(px-1,py+1,4,1,tint)
				p.rect(px+1,py-1,1,4,tint)

func draw_skate(cx: float, cy: float) -> void:
	p.rect(cx-10,cy-10,18,13,Color("eee1cd"))
	p.rect(cx-15,cy,29,7,Color("c777b0"))
	p.rect(cx-16,cy+7,32,3,Color("667f96"))
	for wheel in [-9,9]:
		p.ellipse(cx+wheel,cy+13,5,5,Color("eab14f"))
		p.rect(cx+wheel-1,cy+12,3,3,Color("564061"))
	for lace in range(3):
		p.rect(cx-6,cy-7+lace*4,10,1,Color("5c6882"))

func draw_phase_sword(hand: float, cy: float, tint: Color) -> void:
	var time = 0.0 if reduced else clock
	var glow = 0.16+0.04*sin(time*5)
	p.rect(hand-9,cy-67,18,65,Color(tint,glow))
	p.rect(hand-5,cy-65,10,62,tint)
	p.rect(hand-2,cy-64,4,61,Color("f2faff"))
	p.rect(hand-4,cy-3,8,23,Color("8f9fac"))
	for band in range(4):
		p.rect(hand-4,cy+band*5,8,2,Color("384858"))
	p.rect(hand-2,cy+2,3,3,tint)
	p.ellipse(hand,cy+14,6,4,GREEN)

func draw_paco(cx: float, ground: float) -> void:
	var time = 0.0 if reduced else clock
	var bob = 0.0 if reduced else sin(time*3.0)*1.0
	var y = ground-19+bob
	var fur = Color("bd8758")
	var cream = Color("f3d4a1")
	p.ellipse(cx,ground+2,20,3,INK)
	# Tiny curled, wagging tail, oversized ears, and a cream muzzle.
	var wag = sin(time*9.0)*3.0
	p.rect(cx+14,y-3,5,13,fur)
	p.rect(cx+17,y-7+wag,6,5,fur)
	p.ellipse(cx,y+7,16,11,fur)
	p.rect(cx-12,ground-5,6,7,cream)
	p.rect(cx+7,ground-5,6,7,cream)
	p.rect(cx-15,y-25,8,23,fur)
	p.rect(cx+6,y-25,8,23,fur)
	p.rect(cx-13,y-21,4,13,Color("d89791"))
	p.rect(cx+8,y-21,4,13,Color("d89791"))
	p.ellipse(cx-1,y-5,16,13,fur)
	p.ellipse(cx-1,y+1,10,7,cream)
	var blink = not reduced and fposmod(time,4.2)>4.02
	p.rect(cx-10,y-9,4,1 if blink else 5,INK)
	p.rect(cx+5,y-9,4,1 if blink else 5,INK)
	p.rect(cx-3,y-2,5,3,INK)
	p.rect(cx-1,y+3,3,4,Color("e892a1"))
	p.rect(cx-11,y+9,21,3,Color("db4856"))
	p.rect(cx-2,y+11,4,4,Color("ffdc71"))

func draw_chest_symbol(cx: float, cy: float) -> void:
	if wearing(39):
		p.ring(cx,cy,13,DARK_GREEN,2)
		p.rect(cx,cy-12,2,25,DARK_GREEN)
		for step in range(10):
			p.rect(cx-step,cy+step,2,2,DARK_GREEN)
			p.rect(cx+step,cy+step,2,2,DARK_GREEN)
	elif wearing(40):
		p.rect(cx-19,cy-13,38,26,Color("faf3e5"))
		for stripe in range(7):
			p.rect(cx-19,cy-13+stripe*4,38,2,Color("bd3549"))
		p.rect(cx-19,cy-13,16,14,Color("254779"))
		for row in range(5):
			for star in range(5):
				p.rect(cx-18+star*3+(row%2),cy-12+row*2,1,1,Color("faf3e5"))
	elif wearing(41):
		# Pixel adaptation of the portfolio's cyan ITS monogram badge.
		p.rect(cx-16,cy-15,32,30,Color("0ccbe7"))
		var mark = Color("f4f4f2")
		p.rect(cx-12,cy-8,3,18,mark)
		p.rect(cx-6,cy-8,13,3,mark)
		p.rect(cx-2,cy-5,3,15,mark)
		for step in range(5):
			p.rect(cx+10-step*2,cy-6+step*2,4,3,mark)
			p.rect(cx+2+step*2,cy+2+step*2,4,3,mark)
		p.rect(cx+2,cy+10,10,3,mark)
	elif wearing(42):
		var bone = Color("f4edd9")
		p.rect(cx-18,cy-15,36,30,Color("171d27"))
		for step in range(10):
			p.rect(cx-12+step*2,cy+4+step,4,2,bone)
			p.rect(cx+9-step*2,cy+4+step,4,2,bone)
		p.rect(cx-8,cy-11,16,12,bone)
		p.rect(cx-5,cy+1,10,4,bone)
		p.rect(cx-6,cy-7,4,4,INK)
		p.rect(cx+2,cy-7,4,4,INK)
		p.rect(cx-1,cy-2,2,3,INK)
	else:
		p.ring(cx,cy,12,DARK_GREEN,2)
		p.rect(cx-2,cy-2,5,5,DARK_GREEN)
		p.rect(cx-10,cy-9,6,6,DARK_GREEN)
		p.rect(cx+6,cy-9,6,6,DARK_GREEN)
		p.rect(cx-3,cy+6,7,5,DARK_GREEN)

func active_skin() -> int:
	for item in range(43,46):
		if wearing(item):
			return item-42
	return 0

func has_neck_cosmetic() -> bool:
	for item in range(SHOP_NAMES.size()):
		if ITEM_SLOTS[item] == 2 and wearing(item):
			return true
	return false

func draw_mascot_tail(x: float, y: float, skin: int, fur: Color, cream: Color) -> void:
	for step in range(17):
		var tx = x+sin(step*0.13)*26
		var ty = y+35-step*4
		var tint = fur
		if skin == 1:
			tint = cream if step > 13 else (Color("ad5728") if step%5 < 2 else fur)
		elif skin == 3 and step%6 < 3:
			tint = Color("d88c36")
		p.rect(tx-2,ty-2,13,10,Color("11151e"))
		p.rect(tx,ty,9,6,tint)

func draw_coat_marks(cx: float, cy: float, rx: float, ry: float, skin: int) -> void:
	if skin == 1:
		for side in [-1,1]:
			for stripe in range(4):
				var y = cy-ry*0.5+stripe*ry*0.27
				var x = cx+side*(rx-15-stripe%2*5)
				p.rect(x-8,y,16,5,Color("b65f29"))
				p.rect(x-5-side*5,y+5,10,4,Color("b65f29"))
	elif skin == 2:
		# Tuxedo shoulders frame a narrow white bib and broad white belly.
		p.rect(cx-17,cy-ry+19,34,26,Color("f0eadb"))
		p.rect(cx-11,cy-ry+10,22,15,Color("f0eadb"))
	else:
		# Fixed asymmetrical tortoiseshell patches stretch with inflation.
		for patch in [Vector3(-0.67,-0.35,1),Vector3(0.55,-0.48,0),Vector3(-0.72,0.20,0),Vector3(0.68,0.29,1),Vector3(-0.30,0.63,1),Vector3(0.26,0.55,0)]:
			var x = cx+patch.x*rx
			var y = cy+patch.y*ry
			var tint = Color("d68b36") if patch.z == 1 else Color("a85d2e")
			p.rect(x-9,y-8,18,16,tint)
			p.rect(x-5,y-13,13,25,tint)
		p.rect(cx-11,cy-ry+17,13,17,Color("d68b36"))

func draw_mascot_face_marks(cx: float, hy: float, skin: int, cream: Color) -> void:
	if skin == 1:
		# White blaze, cream muzzle, and the tabby forehead M.
		p.rect(cx-5,hy-4,10,21,cream)
		p.rect(cx-25,hy+16,50,12,cream)
		for side in [-1,1]:
			p.rect(cx+side*14-2,hy-4,4,8,Color("a95727"))
			p.rect(cx+side*22-2,hy-3,4,5,Color("a95727"))
	elif skin == 2:
		p.rect(cx-3,hy-4,7,9,cream)
		p.rect(cx-6,hy+5,12,10,cream)
		p.rect(cx-22,hy+15,44,14,cream)
		p.rect(cx-12,hy+27,24,4,cream)
	else:
		p.rect(cx-33,hy-3,22,8,Color("d68b36"))
		p.rect(cx-31,hy+4,15,18,Color("d68b36"))
		p.rect(cx+8,hy-4,11,13,Color("b26c31"))
		p.rect(cx+19,hy+17,15,11,Color("d68b36"))
		p.rect(cx-5,hy+17,10,8,Color("9e7045"))

func draw_jimothy(cx: float, ground: float) -> void:
	var time = 0.0 if reduced else clock
	var shuffle = sin(time*2.0)*2.0
	var bob = absf(sin(time*4.0))
	var x = cx+shuffle
	var y = ground-20-bob
	var fur = Color("8c8b80")
	var light = Color("cfccbb")
	var mask = Color("30343b")
	p.ellipse(cx,ground+2,23,3,INK)
	# A short ringed tail and tiny feet under a compact, high-backed body.
	for band in range(6):
		p.rect(x+13+band*2,ground-13-band,5,8,fur if band%2 == 0 else mask)
	p.rect(x-14,ground-5,8,6,mask)
	p.rect(x+7,ground-5,8,6,mask)
	p.ellipse(x+2,y,19,20,mask)
	p.ellipse(x+1,y-2,17,18,fur)
	p.ellipse(x+3,y-8,12,9,Color("a5a292"))
	# Face sits low against his shoulders, without a separate long neck.
	p.rect(x-16,y-17,8,9,light)
	p.rect(x+7,y-17,8,9,light)
	p.rect(x-14,y-15,4,5,mask)
	p.rect(x+9,y-15,4,5,mask)
	p.ellipse(x-2,y+1,17,12,light)
	p.rect(x-16,y-3,12,8,mask)
	p.rect(x+1,y-3,12,8,mask)
	var blink = not reduced and fposmod(time,4.7)>4.5
	p.rect(x-11,y-1,3,1 if blink else 3,Color("f7f2da"))
	p.rect(x+5,y-1,3,1 if blink else 3,Color("f7f2da"))
	p.rect(x-6,y+4,9,6,Color("e2dfcd"))
	p.rect(x-4,y+3,5,3,mask)
	p.rect(x-2,y+8,2,2,mask)
