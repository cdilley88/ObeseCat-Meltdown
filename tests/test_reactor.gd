extends SceneTree

var failures = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check_difficulties()
	check_warmup()
	check_normal_patterns()
	var r = Reactor.new()
	r.tick((0.75-r.charge)/r.rate())
	check(r.safe(),"Safe window missing")
	check(r.pet()==1 and r.score==1 and r.charge==0.22,"Scoring pet failed")
	check(r.pet()==0 and r.score==1,"Cooldown failed")
	r.reset()
	check(r.pet()==-1 and r.charge>0.22,"Early penalty missing")
	r.tick(8)
	check(r.lost and r.pet()==0,"Meltdown must be terminal")
	r.reset()
	check(not r.lost and r.score==0 and r.age==0,"Retry failed")
	for i in range(150):
		while not r.safe() and not r.lost:
			r.tick(1.0/120.0)
		check(r.pet()==1,"Repeat purr failed at %d" % i)
	check(r.rate()<=0.34 and r.safe_width()>=0.1599,"Difficulty caps failed")
	r.score=24
	check(is_equal_approx(r.drift_speed(),0.72),"Movement sped up before 25 purrs")
	r.score=25
	var speed_at_25=r.drift_speed()
	check(speed_at_25>0.72,"Second ramp missing at 25 purrs")
	r.score=45
	check(r.drift_speed()>speed_at_25 and is_equal_approx(r.drift_speed(),1.44),"Second ramp cap failed")
	r.drift_phase=1.1
	r.charge=0.22
	var phase_before=r.drift_phase
	r.tick(0.1)
	check(is_equal_approx(r.drift_phase-phase_before,0.144),"Movement phase did not advance at the new speed")
	for points in [0,4,5,10,20,24,25,26,31,45,100]:
		r.reset()
		r.score=points
		var narrowest=1.0
		var widest=0.0
		var leftmost=1.0
		var rightmost=0.0
		for frame in range(1200):
			r.age=frame/30.0
			r.drift_phase=r.age*r.drift_speed()
			narrowest=minf(narrowest,r.safe_width())
			widest=maxf(widest,r.safe_width())
			leftmost=minf(leftmost,r.safe_center())
			rightmost=maxf(rightmost,r.safe_center())
			check(r.safe_min()>0.55 and r.safe_max()<0.94,"Window left safe pressure bounds")
		if points<5:
			check(is_equal_approx(narrowest,0.24) and is_equal_approx(leftmost,rightmost),"First five purrs changed")
		else:
			check(widest<0.24 and widest>narrowest and rightmost>leftmost,"Window must shrink, breathe and drift after fifth purr")
		# Sample actual moving-window dwell times, including the fastest late game.
		for phase in range(12):
			r.reset()
			r.score=points
			r.age=phase*2.0
			r.drift_phase=phase*TAU/12.0
			var safe_seconds=0.0
			while not r.lost:
				r.tick(1.0/240.0)
				if r.safe():
					safe_seconds+=1.0/240.0
			check(safe_seconds>0.38,"Moving window became too brief")
	r.reset()
	check(is_equal_approx(r.safe_min(),Reactor.SAFE_MIN) and is_equal_approx(r.safe_max(),Reactor.SAFE_MAX),"Retry did not reset window")
	check(r.drift_phase==0.0 and is_equal_approx(r.drift_speed(),0.72),"Retry did not reset drift speed and phase")
	r.reset()
	for i in range(100):
		if r.lost:
			break
		r.tick(0.37)
		r.pet()
	check(r.lost and r.score==0,"Spam trivialized game")
	r.reset()
	r.charge = 0.91
	check(r.pet()==-2 and r.lost,"Late pet must cause meltdown")
	for bound in [Reactor.SAFE_MIN,Reactor.SAFE_MAX]:
		r.reset()
		r.charge = bound
		check(r.pet()==1,"Safe boundary must be inclusive")
	var game = load("res://game.gd").new()
	game.settings_path = "user://shop-test-settings.cfg"
	root.add_child(game)
	game.muted = true
	game.set_process(false)
	# Selection and score isolation without writing the player's preferences.
	game.capture_mode="test"
	game.mode_bests=[7,3,1]
	for level in range(3):
		game.mode=game.Mode.READY
		game.down(Vector2(72+level*108,518))
		check(game.mode==game.Mode.READY and game.reactor.difficulty_mode==level,"Selector started a run or chose wrong mode")
		check(game.best==game.mode_bests[level],"Best score leaked between modes")
		game.down(Vector2(180,565))
		check(game.mode==game.Mode.PLAYING and game.reactor.difficulty_mode==level,"Start lost selected mode")
		game.reactor.score=10+level
		game.fail()
		check(game.mode_bests[level]==10+level,"Mode best not saved")
		game.down(Vector2(180,607))
		check(game.mode==game.Mode.READY and game.reactor.score==0,"Modes button did not return to selector")
	game.capture_mode="test"
	game.reactor.difficulty_mode=Reactor.Difficulty.EASY
	game.best=game.mode_bests[0]
	game.begin()
	game.reactor.charge = 0.75
	game.down(Vector2(150,320))
	game.up(Vector2(160,320))
	check(game.reactor.score==0,"Tap should not score")
	game.down(Vector2(150,320))
	game.up(Vector2(205,320))
	check(game.reactor.score==1,"Completed pointer swipe did not score")
	game.up(Vector2(270,320))
	check(game.reactor.score==1,"One gesture scored twice")
	game.begin()
	game.reactor.charge = 0.75
	var touch = InputEventScreenTouch.new()
	touch.index=0
	touch.pressed=true
	touch.position=Vector2(150,320)
	game._input(touch)
	var second = InputEventScreenTouch.new()
	second.index=1
	second.pressed=true
	second.position=Vector2(150,320)
	game._input(second)
	second.pressed=false
	second.position=Vector2(240,320)
	game._input(second)
	check(game.reactor.score==0,"Second finger interfered")
	touch.pressed=false
	touch.position=Vector2(220,320)
	game._input(touch)
	check(game.reactor.score==1,"Touch swipe did not score")
	game.begin()
	game.reactor.charge=0.75
	touch.pressed=true
	game._input(touch)
	touch.pressed=false
	touch.canceled=true
	touch.position=Vector2(290,320)
	game._input(touch)
	check(game.reactor.score==0 and not game.dragging,"Canceled touch scored")
	game.paused=true
	game.reactor.score=45
	var before=game.reactor.charge
	var window_before=Vector2(game.reactor.safe_min(),game.reactor.safe_max())
	game._process(0.5)
	check(game.reactor.charge==before,"Pause advanced reactor")
	check(window_before==Vector2(game.reactor.safe_min(),game.reactor.safe_max()),"Pause moved the safe window")
	game.paused=false
	game.reactor.tick(10)
	game.fail()
	game.death_age=0.7
	game.down(Vector2(180,550))
	check(game.mode==game.Mode.PLAYING and game.reactor.score==0 and not game.reactor.lost,"Instant retry failed")
	check_shop(game)
	check_game_loop(game)
	game.queue_free()
	print("OBESECAT: ","ALL RULE AND INPUT CHECKS PASSED" if failures==0 else str(failures)+" FAILURES")
	quit(0 if failures==0 else 1)

func check_game_loop(game) -> void:
	# Exercise the real frame loop; capture fixtures deliberately bypass it.
	game.capture_mode = ""
	game.pattern_test = true # Suppress persistence during simulated losses.
	for level in range(3):
		game.reactor.difficulty_mode = level
		game.begin()
		game.reactor.score = 0
		var initial_charge = game.reactor.charge
		for frame in range(30):
			game._process(1.0/60.0)
		check(game.reactor.charge > initial_charge and game.reactor.age > 0.0, "Gameplay frame loop did not advance pressure")
		check(game.shown_charge > initial_charge, "Displayed pressure did not advance")
		game.paused = true
		var paused_charge = game.reactor.charge
		var paused_display = game.shown_charge
		game._process(0.05)
		check(game.reactor.charge == paused_charge and game.shown_charge == paused_display, "Paused frame loop advanced pressure")
		game.paused = false
		for frame in range(600):
			game._process(1.0/60.0)
			if game.mode == game.Mode.LOST:
				break
		check(game.mode == game.Mode.LOST, "Frame loop did not trigger meltdown")
		for frame in range(180):
			game._process(1.0/60.0)
		check(game.death_age > 2.9, "Loss animation and coin notification timer did not advance")
		game.down(Vector2(180,550))
		check(game.mode == game.Mode.PLAYING and game.death_age == 0.0, "Frame-loop loss could not restart")
	game.capture_mode = "test"

func check_difficulties() -> void:
	var easy=Reactor.new()
	for level in range(3):
		var r=Reactor.new()
		r.difficulty_mode=level
		for points in range(5):
			r.score=points
			easy.score=points
			r.age=points*2.5
			easy.age=r.age
			r.drift_phase=1.7
			easy.drift_phase=r.drift_phase
			if points < 3:
				check(is_equal_approx(r.safe_width(),easy.safe_width()) and is_equal_approx(r.safe_center(),easy.safe_center()) and is_equal_approx(r.rate(),easy.rate()),"Opening warmup differs between modes")
		var minimum_window=10.0
		for points in [5,11,12,23,24,31,32,50,55,100]:
			r.score=points
			easy.score=points
			if level>0:
				check(r.drift_speed()>0.72,"Post-practice movement failed to accelerate")
			for phase in range(48):
				r.reset()
				r.score=points
				r.age=phase*0.71
				r.drift_phase=phase*TAU/48.0
				var longest=0.0
				var current=0.0
				while not r.lost:
					r.tick(1.0/240.0)
					check(r.safe_min()>=0.0999 and r.safe_max()<=1.0001,"Safe zone escaped playable bar")
					if r.safe():
						current+=1.0/240.0
						longest=maxf(longest,current)
					else:
						current=0.0
				minimum_window=minf(minimum_window,longest)
				check(longest>[0.38,0.04,0.025][level],"No usable contiguous safe window in mode %d at score %d phase %d: %f" % [level,points,phase,longest])
		print("Mode ",level," shortest sampled longest opening: ",minimum_window)
		r.reset()
		for points in range(100):
			while (not r.safe() or r.cooldown>0.0) and not r.lost:
				r.tick(1.0/240.0)
			check(r.pet()==1,"Sustained scoring failed in mode %d" % level)
		check(r.difficulty_mode==level,"Retry reset selected difficulty")
		if level>0:
			for milestone in [12,24,32]:
				r.score=milestone-1
				var prior=r.staged_ramp()
				r.score=milestone
				check(r.staged_ramp()-prior>0.10,"Milestone spike missing")
			r.score=55
			var capped=r.drift_speed()
			r.score=100
			check(is_equal_approx(capped,r.drift_speed()),"Speed did not cap at 55")
			r.difficulty_mode=Reactor.Difficulty.NORMAL
			r.drift_phase=-PI/2
			check(is_equal_approx(r.safe_min(),0.10),"Left reach is not 90% across the bar")
			r.drift_phase=PI/2
			check(is_equal_approx(r.safe_max(),1.0),"Window does not reach right edge")

func check_shop(game) -> void:
	for pair in [[0,0],[14,0],[15,1],[34,1],[35,2],[49,2],[50,3],[59,3],[100,3],[1000,3]]:
		check(game.coin_reward(pair[0]) == pair[1], "Coin payout boundary: " + str(pair[0]))
	game.wallets = [0,0,0]
	game.owned = [0,0,0]
	game.equipped = [0,0,0]
	game.reactor.difficulty_mode = 1
	game.begin()
	game.reactor.score = 60
	game.fail()
	game.fail()
	check(game.wallets == [0,3,0], "Payout duplicated or crossed difficulties")
	game.down(Vector2(230,607))
	check(game.shop_open and not game.dragging, "Store footer did not open")
	select_shop_item(game, 0)
	game.down(Vector2(180,510))
	check(game.wallets == [0,0,0] and game.owned == [0,1,0] and game.equipped == [0,1,0], "Purchase isolation or equip failed")
	game.down(Vector2(180,510))
	check(game.wallets[1] == 0 and game.equipped[1] == 0 and not game.wearing(0), "Unequip charged coins or left cosmetic visible")
	game.down(Vector2(180,510))
	check(game.wallets[1] == 0 and game.equipped[1] == 1, "Re-equip charged coins")
	game.reactor.difficulty_mode = 2
	select_shop_item(game, 5)
	game.down(Vector2(180,510))
	check(game.wallets[2] == 0 and game.owned[2] == 0, "Insufficient funds allowed purchase")
	game.down(Vector2(180,556))
	check(game.wallets == [0,0,0], "Public build exposed developer coin grant")
	game.wallets[2] = 999999 # Test fixture, never a public input path.
	for i in range(6):
		select_shop_item(game, i)
		check(game.shop_item == i, "Wrong shop card hit target")
		game.down(Vector2(180,510))
	check(game.wallets[2] == 999958 and game.owned[2] == 63 and game.equipped[2] == 63, "Six-item purchase total failed")
	for i in range(6,game.SHOP_NAMES.size()):
		select_shop_item(game, i)
		var before = game.equipped[2]
		for other in range(game.SHOP_NAMES.size()):
			if other != i and game.ITEM_SLOTS[other] == game.ITEM_SLOTS[i]:
				check(not game.wearing(other), "Preview stacked cosmetics in one slot")
		check(game.equipped[2] == before, "Preview changed saved equipment")
		game.down(Vector2(180,510))
		check(game.wearing(i), "Purchased item not equipped")
		for slot in range(game.SLOT_NAMES.size()):
			var bits = game.equipped[2] & game.slot_mask(slot)
			check(bits == 0 or (bits & (bits-1)) == 0, "Multiple items equipped in one slot")
	check(game.owned[2] == game.ITEM_MASK and game.wallets[2] == 999641, "New catalog prices or ownership incorrect")
	select_shop_item(game, 2)
	game.down(Vector2(180,510))
	check(game.wearing(2) and not game.wearing(12) and game.wallets[2] == 999641, "Owned slot swap charged coins or retained gold chain")
	check(game.normalize_equipment(63) == 63, "Legacy equipment changed during migration")
	var purchases = game.owned.duplicate()
	var balances = game.wallets.duplicate()
	var other_outfits = game.equipped.duplicate()
	select_shop_item(game,41)
	game.down(Vector2(55,110))
	check(game.equipped[2] == 0 and not game.shop_preview, "Default did not clear outfit and preview")
	check(game.owned == purchases and game.wallets == balances, "Default removed purchases or coins")
	check(game.equipped[0] == other_outfits[0] and game.equipped[1] == other_outfits[1], "Default changed another difficulty")
	for item in range(game.SHOP_NAMES.size()):
		check(not game.wearing(item), "Default retained a cosmetic")
	game.capture_mode = ""
	game.save_settings()
	var restored = load("res://game.gd").new()
	restored.settings_path = game.settings_path
	root.add_child(restored)
	restored.set_process(false)
	check(restored.wallets == game.wallets and restored.owned == game.owned and restored.equipped == game.equipped, "Shop save reload lost progression")
	restored.queue_free()
	DirAccess.remove_absolute(game.settings_path)
	game.capture_mode = "test"
	game.down(Vector2(180,606))
	check(not game.shop_open and game.mode == game.Mode.LOST, "Shop back started a run")

func select_shop_item(game, item: int) -> void:
	var slot: int = game.ITEM_SLOTS[item]
	game.down(Vector2(25+(slot%3)*108,275+(slot/3)*24))
	check(game.shop_slot == slot, "Category hit target failed")
	var index: int = game.slot_items().find(item)
	for page in range(index/6):
		game.down(Vector2(260,475))
	game.down(Vector2(25+(index%2)*164,379+((index%6)/2)*32))
	check(game.shop_item == item, "Category item hit target failed")

func check_normal_patterns() -> void:
	var first_times = []
	var opening_counts = {}
	for seed_value in range(400):
		var r = Reactor.new()
		r.difficulty_mode = Reactor.Difficulty.NORMAL
		r.pattern_rng.seed = seed_value
		r.age = seed_value * 1.31
		r.score = 55
		r.charge = r.safe_center()
		check(r.pet() == 1 and r.normal_pattern >= 0, "Late patterns did not begin after cap")
		var initial_pattern = r.normal_pattern
		var first = -1.0
		var dwell = 0.0
		var first_dwell = 0.0
		var openings = 0
		var was_safe = false
		var time = 0.0
		while not r.lost:
			var before = r.safe_center()
			r.tick(1.0/240)
			time += 1.0/240
			check(absf(r.normal_motion()) <= 1.0001, "Pattern exceeded existing speed cap")
			check(absf(r.safe_center()-before) < 0.01, "Safe area jumped mid-attempt")
			var usable = r.safe() and r.cooldown <= 0.0
			if usable:
				if not was_safe:
					openings += 1
				if first < 0:
					first = time
				if openings == 1:
					dwell += 1.0/240
			elif was_safe and openings == 1:
				first_dwell = dwell
			was_safe = usable
		check(first >= 0.36 and first_dwell >= 0.075, "Late pattern lacks a fair first opening: " + str(seed_value) + " / " + str(first_dwell))
		first_times.append(first)
		opening_counts[openings] = true
		r.choose_normal_pattern()
		check(r.normal_pattern != initial_pattern, "Pattern repeated immediately")
	first_times.sort()
	check(first_times[-1]-first_times[0] > 0.15, "Late opening timing remains predictable")
	check(opening_counts.size() > 1, "Second opening remains guaranteed")
	print("Late Normal first opening range: ",first_times[0]," - ",first_times[-1],"; opening counts: ",opening_counts.keys())
	for difficulty in [Reactor.Difficulty.NORMAL, Reactor.Difficulty.HARD]:
		var hard = Reactor.new()
		hard.difficulty_mode = difficulty
		hard.score = 55
		hard.charge = hard.safe_center()
		check(hard.pet() == 1 and hard.normal_pattern >= 0, "Late profile did not activate for difficulty " + str(difficulty))
		var initial = hard.normal_pattern
		hard.choose_normal_pattern()
		check(hard.normal_pattern != initial, "Late profile repeated for difficulty " + str(difficulty))

func check_warmup() -> void:
	for difficulty in [Reactor.Difficulty.NORMAL, Reactor.Difficulty.HARD]:
		var r = Reactor.new()
		r.difficulty_mode = difficulty
		for purrs in range(4):
			r.score = purrs
			r.age = 10.0
			r.drift_phase = 1.2
			check(r.drift_speed() == 0.0 if purrs < 3 else r.drift_speed() > 0.0, "Warmup speed changed at purr " + str(purrs))
			if purrs < 3:
				check(is_equal_approx(r.safe_center(), 0.78), "Warmup safe zone moved at purr " + str(purrs))
				check(is_equal_approx(r.safe_width(), 0.24), "Warmup safe zone narrowed at purr " + str(purrs))
	var ramp = Reactor.new()
	ramp.difficulty_mode = Reactor.Difficulty.NORMAL
	ramp.score = 2
	check(ramp.staged_ramp() == 0.0, "Movement began before the third purr")
	ramp.score = 3
	check(ramp.staged_ramp() > 0.0 and ramp.safe_center() != 0.78, "Movement did not begin after the third purr")
