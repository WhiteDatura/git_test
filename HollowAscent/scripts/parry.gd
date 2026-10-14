extends RefCounted
## Swept projectile/sector intersection. Shared by play, bots and component tests.
const T = preload("res://scripts/tuning.gd")

static func contains(offset: Vector2, direction: Vector2, perfect: bool = false, radius: float = T.PARRY_RADIUS) -> bool:
	if offset.length_squared() > radius * radius: return false
	if offset.length_squared() < 0.001: return true
	var half_angle: float = T.PERFECT_HALF_ANGLE if perfect else T.CUT_HALF_ANGLE
	return offset.normalized().dot(direction.normalized()) >= cos(half_angle)

static func contact(a: Vector2, b: Vector2, center: Vector2, direction: Vector2, radius: float = T.PARRY_RADIUS) -> Dictionary:
	var start: Vector2 = a - center
	var motion: Vector2 = b - a
	var candidates: Array[float] = [0.0, 1.0]
	var aa: float = motion.length_squared()
	if aa > 0.00001:
		var bb: float = 2.0 * start.dot(motion)
		var cc: float = start.length_squared() - radius * radius
		var discriminant: float = bb * bb - 4.0 * aa * cc
		if discriminant >= 0.0:
			candidates.append((-bb - sqrt(discriminant)) / (2.0 * aa))
			candidates.append((-bb + sqrt(discriminant)) / (2.0 * aa))
		for angle in [-T.CUT_HALF_ANGLE, T.CUT_HALF_ANGLE]:
			var edge: Vector2 = direction.rotated(angle)
			var denominator: float = motion.cross(edge)
			if absf(denominator) > 0.00001: candidates.append(-start.cross(edge) / denominator)
	candidates.sort()
	for fraction in candidates:
		if fraction < 0.0 or fraction > 1.0: continue
		var point: Vector2 = start + motion * fraction
		# Tiny tolerance only for roundoff at exact sector boundaries.
		if contains(point, direction, false, radius + 0.01): return {"point": center + point, "fraction": fraction}
	return {}

static func perfect(age: float, offset: Vector2, direction: Vector2, duration: float = T.PARRY_WINDOW) -> bool:
	return absf(age - duration * 0.5) <= T.PERFECT_WINDOW * 0.5 and contains(offset, direction, true)
