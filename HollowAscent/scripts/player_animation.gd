extends RefCounted
const T = preload("res://scripts/tuning.gd")
## Procedural poses supplement the supplied four-frame ink atlas.
static func sample(age: float, direction: Vector2, lunge, rebound: float, grounded: bool, velocity: Vector2) -> Dictionary:
	var face: float = signf(direction.x)
	var result := {"frame": 0 if grounded else 3, "face": 0.0, "offset": Vector2.ZERO, "tilt": clampf(velocity.x * 0.0002, -0.05, 0.05), "blade_angle": direction.angle(), "sweep_sign": 1.0}
	if age < 0.38:
		# Rising cuts travel low-to-high; falling cuts travel high-to-low.
		var sweep: float = -1.0 if direction.y < -0.25 else 1.0
		var progress: float = clampf(age / T.PARRY_WINDOW, 0.0, 1.0)
		result["frame"] = 1 if age < 0.020 or age > T.PARRY_WINDOW else 2
		result["face"] = face
		result["offset"] = direction * sin(progress * PI) * 7.0 + Vector2(0, 3.0 if age < 0.020 else direction.y * 3.0)
		result["tilt"] = direction.y * 0.13 + face * sin(progress * PI) * 0.10
		result["blade_angle"] = direction.angle() + sweep * lerpf(-T.CUT_HALF_ANGLE, T.CUT_HALF_ANGLE, progress)
		result["sweep_sign"] = sweep
	if lunge.active() or lunge.cooldown > 0.0:
		result["frame"] = 1 if lunge.active() and lunge.age() < lunge.ANTICIPATION else 2
		result["face"] = signf(lunge.direction.x)
		result["offset"] = lunge.direction * (6.0 if lunge.active() else 2.0)
		result["tilt"] = clampf(lunge.direction.y * 0.35 + lunge.direction.x * 0.15, -0.4, 0.4)
		result["blade_angle"] = lunge.direction.angle()
	if rebound > 0.0:
		result["frame"] = 3
		result["offset"] = Vector2(0, -5)
		result["tilt"] = -face * 0.12
	return result
