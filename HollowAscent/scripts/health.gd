extends RefCounted
const MAX_HP: int = 3
const INVULNERABILITY: float = 0.70
var current: int = MAX_HP
var invulnerability: float = 0.0
func reset() -> void:
	current = MAX_HP
	invulnerability = 0.0
func tick(dt: float) -> void:
	invulnerability = maxf(0.0, invulnerability - dt)
func damage() -> bool:
	if current == 0 or invulnerability > 0.0: return false
	current -= 1
	invulnerability = INVULNERABILITY
	return true
