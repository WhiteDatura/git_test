extends RefCounted
const COST: int = 2
const SPEED: float = 1450.0
const DURATION: float = 0.23
const RECOVERY: float = 0.22
const REACH: float = 48.0
const ANTICIPATION: float = 0.025
var remaining: float = 0.0
var cooldown: float = 0.0
var direction: Vector2 = Vector2.RIGHT
func reset() -> void:
	remaining = 0.0
	cooldown = 0.0
func start(aim: Vector2) -> void:
	direction = aim.normalized()
	remaining = DURATION
	cooldown = DURATION + RECOVERY
func tick(dt: float) -> void:
	remaining = maxf(0.0, remaining - dt)
	cooldown = maxf(0.0, cooldown - dt)
func active() -> bool:
	return remaining > 0.0
func age() -> float:
	return DURATION - remaining
func speed() -> float:
	return SPEED * clampf((age() - ANTICIPATION) / 0.035, 0.0, 1.0)
func control_weight() -> float:
	if active(): return 0.0
	return 1.0 - clampf(cooldown / RECOVERY, 0.0, 1.0) * 0.85

func travel(dt: float) -> float:
	# Exact integral of anticipation + 35 ms acceleration; independent of frame rate.
	var start_age: float = age()
	var end_age: float = minf(DURATION, start_age + dt)
	return SPEED * (_integral(end_age) - _integral(start_age))
func _integral(t: float) -> float:
	var ramp: float = clampf(t - ANTICIPATION, 0.0, 0.035)
	return ramp * ramp / 0.070 + maxf(0.0, t - ANTICIPATION - 0.035)
