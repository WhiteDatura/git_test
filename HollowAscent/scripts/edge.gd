extends RefCounted
const CAP: int = 6
var current: int = 0
func reset() -> void:
	current = 0
func add(amount: int) -> void:
	current = clampi(current + amount, 0, CAP)
func spend(amount: int) -> bool:
	if current < amount: return false
	current -= amount
	return true
