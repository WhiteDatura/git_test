extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.sound_on = true
	game._sound("parry")
	await create_timer(.2).timeout
	print("SHUTDOWN_OK music and effect retirement requested")
	game._quit_cleanly()
