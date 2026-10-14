extends RefCounted
const T = preload("res://scripts/tuning.gd")
static func warning(index: int, kind: int) -> float:
	if index < 2: return T.OPENING_WARNING
	if index == 2: return 0.90
	return T.WARNING_DURATION + (0.32 if index % 5 == 4 else 0.0) + (0.14 if kind == 3 else 0.0)

static func speed(index: int, kind: int) -> float:
	if index < 3: return T.OPENING_SPEED + (25.0 if index == 2 else 0.0)
	return T.HOMING_SPEED if kind == 1 else T.PROJECTILE_SPEED

static func spread(index: int, kind: int, section: int) -> int:
	# Repeats -> delay (row 4) -> small fan (row 8) -> burst (row 12)
	# -> tracking spirit (row 16) -> simultaneous attackers (section II).
	if kind == 0 and ((index >= 8 and index % 5 == 3) or section >= 1): return 2 if section < 3 else 3
	if kind == 3 and section >= 3: return 3
	return 1

static func burst(index: int, kind: int) -> int:
	return 2 if index >= 12 and index % 5 == 2 and kind in [0, 2] else 0
