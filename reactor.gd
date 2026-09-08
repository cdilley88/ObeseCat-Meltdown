class_name Reactor
extends RefCounted

const SAFE_MIN = 0.66
const SAFE_MAX = 0.90
enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_NAMES = ["EASY", "NORMAL", "HARD"]
var difficulty_mode: int = Difficulty.EASY
var charge: float = 0.22
var score: int = 0
var lost: bool = false
var age: float = 0.0
var cooldown: float = 0.0
var unsettled: float = 0.0
var drift_phase: float = 0.0
# Each late Normal attempt gets one continuous, bounded movement profile.
var normal_pattern = -1
var normal_pattern_age = 0.0
var normal_direction = 1.0
var normal_offset = 0.0
var pattern_rng = RandomNumberGenerator.new()

func _init() -> void:
	pattern_rng.randomize()

func choose_normal_pattern() -> void:
	var next = pattern_rng.randi_range(0,3)
	if next == normal_pattern:
		next = (next + pattern_rng.randi_range(1,3)) % 4
	normal_pattern = next
	normal_pattern_age = 0.0
	normal_direction = -1.0 if pattern_rng.randf() < 0.5 else 1.0
	normal_offset = pattern_rng.randf_range(-0.45,0.45)
	drift_phase = PI/2 + normal_offset

func normal_motion() -> float:
	var t = normal_pattern_age
	match normal_pattern:
		0: return 0.78 # Measured sweep.
		1: return 0.78 + 0.22*cos(t*2.6) # Quick departure, gentle middle.
		2: return 0.78 - 0.22*cos(t*2.6) # Gentle departure, quick middle.
		_: return 0.80 + 0.20*sin(t*3.5) # Two smooth changes of pace.


func rate() -> float:
	return minf(0.205 + score * 0.006, 0.34)

func window_difficulty() -> float:
	if difficulty_mode != Difficulty.EASY:
		return staged_ramp()
	return 0.0 if score < 5 else minf(0.12 + (score - 5) * 0.035, 1.0)

func staged_ramp() -> float:
	if score < 3:
		return 0.0
	if score < 5:
		return lerpf(0.04,0.10,(score-3)/1.0)
	if score < 12:
		return lerpf(0.10,0.23,(score-5)/6.0)
	if score < 24:
		return lerpf(0.36,0.50,(score-12)/11.0)
	if score < 32:
		return lerpf(0.63,0.73,(score-24)/7.0)
	if score <= 50:
		return lerpf(0.84,0.96,(score-32)/18.0)
	return lerpf(0.96,1.0,clampf((score-50)/5.0,0.0,1.0))

func turbulence() -> float:
	if difficulty_mode != Difficulty.HARD or score < 12:
		return 0.0
	return 0.18 if score < 24 else (0.36 if score < 32 else 0.55)

func safe_width() -> float:
	var difficulty = window_difficulty()
	# Width breathes continuously; each mode has its own late-game floor.
	var shrink: float = [0.07, 0.12, 0.155][difficulty_mode]
	return (SAFE_MAX - SAFE_MIN) - difficulty * (shrink + 0.01 * sin(age * 0.95))

func drift_speed() -> float:
	if difficulty_mode != Difficulty.EASY and score < 3:
		return 0.0
	if difficulty_mode != Difficulty.EASY:
		return lerpf(0.72,3.6 if difficulty_mode == Difficulty.NORMAL else 4.2,staged_ramp())
	# Second ramp: 25% faster at 25 purrs, double speed at 45.
	var mode_boost: float = [0.0, 0.65, 1.35][difficulty_mode]
	return 0.72 * (1.0 if score < 25 else minf(1.25 + (score - 25) * 0.0375, 2.0)) * (1.0 + mode_boost * window_difficulty())

func safe_center() -> float:
	if difficulty_mode != Difficulty.EASY:
		var ramp = staged_ramp()
		var sweep = (sin(drift_phase)+1.0)*0.5
		var width = safe_width()
		var left = lerpf(0.78,0.10+width*0.5,ramp)
		var right = lerpf(0.78,1.0-width*0.5,ramp)
		return lerpf(left,right,sweep)
	# Integrated phase avoids position jumps when movement speed changes.
	var distance: float = [0.045, 0.08, 0.115][difficulty_mode]
	var shift: float = [0.0, 0.02, 0.04][difficulty_mode]
	return 0.78 + window_difficulty() * (distance * sin(drift_phase) + 0.018 * sin(score * 1.7) - shift)

func safe_min() -> float:
	return safe_center() - safe_width() * 0.5

func safe_max() -> float:
	return safe_center() + safe_width() * 0.5

func safe() -> bool:
	return not lost and unsettled <= 0.0 and charge >= safe_min() and charge <= safe_max()

func reset() -> void:
	charge = 0.22
	score = 0
	lost = false
	age = 0.0
	cooldown = 0.0
	unsettled = 0.0
	drift_phase = 0.0
	normal_pattern = -1
	normal_pattern_age = 0.0
	normal_direction = 1.0
	normal_offset = 0.0

func tick(dt: float) -> void:
	if lost:
		return
	dt = maxf(0.0, dt)
	age += dt
	# Hard's spikes add irregular braking and eventually reversals. Bound the
	# fastest bursts so the narrow target never skips across the bar in a frame.
	var motion = clampf(1.0 + turbulence()*3.0*sin(age*4.7+0.4*sin(age*1.3)),-0.65,1.05)
	if difficulty_mode != Difficulty.EASY and score > 55 and normal_pattern >= 0:
		normal_pattern_age += dt
		# Late profiles replace the memorisable sweep, while Hard keeps a
		# smaller turbulence contribution layered over the same bounded profile.
		var profile_motion = normal_direction * normal_motion() * 0.85
		motion = profile_motion + (turbulence() * 0.18 * sin(age * 4.7) if difficulty_mode == Difficulty.HARD else 0.0)
	drift_phase = fposmod(drift_phase + drift_speed() * motion * dt, TAU)
	cooldown = maxf(0.0, cooldown - dt)
	unsettled = maxf(0.0, unsettled - dt)
	charge += rate() * dt
	if charge >= 1.0:
		charge = 1.0
		lost = true

# 0 ignored, 1 purr, -1 early, -2 late. One completed gesture = one pet.
func pet() -> int:
	if lost or cooldown > 0.0:
		return 0
	cooldown = 0.36
	if safe():
		score += 1
		charge = 0.22
		if difficulty_mode != Difficulty.EASY and score >= 5:
			# Start the next sweep ahead of the reset pressure, so its only safe
			# crossing cannot disappear behind the player during pet cooldown.
			drift_phase = PI/2
		if difficulty_mode != Difficulty.EASY and score > 55:
			choose_normal_pattern()
		return 1
	var result = -1 if charge < safe_min() else -2
	if unsettled > 0.0:
		result = -1
	unsettled = 0.9
	charge = minf(1.0, charge + 0.16)
	lost = charge >= 1.0
	return result
