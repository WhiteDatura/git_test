extends RefCounted
## Contact poses and large atlas fragments, kept independent of enemy scheduling.
var deaths: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
func reset() -> void:
	deaths.clear()
	sparks.clear()
func strike(at: Vector2, direction: Vector2, kind: int) -> void:
	deaths.append({"pos": at, "direction": direction, "kind": kind, "age": 0.0})
func spark(at: Vector2, perfect: bool) -> void:
	sparks.append({"pos": at, "perfect": perfect, "age": 0.0})
func tick(dt: float) -> void:
	for item in deaths: item["age"] += dt
	for item in sparks: item["age"] += dt
	deaths = deaths.filter(func(item): return item["age"] < 0.62)
	sparks = sparks.filter(func(item): return item["age"] < 0.16)
func draw_on(game: Node2D) -> void:
	for item in deaths:
		var age: float = item["age"]
		var direction: Vector2 = item["direction"]
		var at: Vector2 = game._world(item["pos"])
		var kind: int = item["kind"]
		var alpha: float = clampf((0.62 - age) / 0.40, 0.0, 1.0)
		var anchor: Vector2 = [Vector2(0.83, 0.34), Vector2(0.55, 0.36), Vector2(0.54, 0.42), Vector2(0.5, 0.96)][kind]
		var size: Vector2 = [Vector2(112, 112), Vector2(96, 106), Vector2(114, 114), Vector2(90, 114)][kind]
		if age < 0.075:
			game._atlas(game.enemy_art, 2, 2, kind, at + direction * age * 70.0, size, anchor, false, direction.x * 0.15, Color(1, 1, 1, alpha))
		else:
			var cell: Vector2 = game.enemy_art.get_size() / 2.0
			var cell_origin := Vector2(kind % 2, kind / 2) * cell
			for i in range(4):
				var quadrant := Vector2(i % 2, i / 2)
				var travel: Vector2 = direction * (age - 0.075) * 100.0 + Vector2((i % 2) * 2 - 1, (i / 2) * 2 - 1) * (age - 0.075) * 38.0
				var origin: Vector2 = at - anchor * size + quadrant * size * 0.5 + travel + Vector2(0, age * age * 85.0)
				game.draw_texture_rect_region(game.enemy_art, Rect2(origin, size * 0.5), Rect2(cell_origin + quadrant * cell * 0.5, cell * 0.5), Color(1, 1, 1, alpha))
		if age < 0.20:
			var cut: Vector2 = direction.rotated(0.6)
			game.draw_line(at - cut * 33.0, at + cut * 33.0, game.PAPER, 3.0, true)
			game.draw_line(at - cut * 24.0, at + cut * 28.0, game.CRIMSON, 1.4, true)
	for item in sparks:
		var at: Vector2 = game._world(item["pos"])
		var strength: float = 1.0 - item["age"] / 0.16
		var reach: float = 15.0 if item["perfect"] else 8.0
		for i in range(3):
			var vector: Vector2 = Vector2.from_angle(-0.8 + i * 1.7)
			game.draw_line(at + vector * 2.0, at + vector * reach * strength, Color(game.PAPER, strength), 1.5, true)
		game.draw_line(at - Vector2(2, 0), at + Vector2(3, 0), Color(game.INK, strength), 1.0, true)
