extends SceneTree
## Deterministic rendered pose review. These are staged fixtures, not traversal proof.
var game
func _initialize() -> void: call_deferred("run")
func reset() -> void:
	game._start()
	game.sound_on = false
	game.camera_y = game.player.y - 110.0
	game.clock = 1.0
func capture(name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	assert(image.save_png("res://screenshots/"+name+".png")==OK)
	print("RENDER_OK " + name)
func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	reset()
	await capture("opening")
	game.section_time = 0.0
	game.gate_index = 5
	await capture("idle")
	for item in [["parry_left",Vector2.LEFT],["parry_right",Vector2.RIGHT],["parry_up",Vector2(0.5,-1).normalized()],["parry_down",Vector2(0.5,1).normalized()]]:
		reset()
		game.gate_index = 5
		game._click_parry(item[1])
		game.slash_visual_age = .115
		game.parry_age = .115
		await capture(item[0])
	for perfect in [false,true]:
		reset()
		game.gate_index = 5
		game._click_parry(Vector2.LEFT)
		game.parry_age = .115 if perfect else .04
		game.slash_visual_age = game.parry_age
		game.projectiles.append({"pos":game.player+Vector2(-90,0),"prev":game.player+Vector2(-90,0),"velocity":Vector2(1800,0),"age":.2,"kind":0,"life":1.0,"enemy":0})
		game._update_projectiles(.02)
		await capture("perfect_contact" if perfect else "normal_contact")
	for item in [["lunge_start",.012],["lunge_move",.10],["lunge_miss",.25]]:
		reset()
		game.gate_index = 5
		game.edge.add(2)
		game._try_lunge(Vector2(1,-.25))
		game.lunge.tick(item[1])
		await capture(item[0])
	for item in [["enemy_hit",0.0],["enemy_death",.18],["rebound",.08]]:
		reset()
		game.gate_index = 5
		game.edge.add(2)
		var source: Vector2 = game._source(game.gates[0])
		game.player = source+Vector2(92,0)
		game._try_lunge(Vector2.LEFT)
		for i in range(8): game._step(1.0/60)
		game.enemy_response.tick(item[1])
		game.camera_y = game.player.y-110
		await capture(item[0])
	reset()
	var platform: Vector2 = game._enemy_platform(game.gates[0])
	game.player = platform-Vector2(0,game.T.PLAYER_FOOT-2)
	game.velocity = Vector2(0,100)
	game.grounded = false
	game._collide_ledges(game.player.y-6)
	game.camera_y = game.player.y-110
	await capture("platform_landing")
	reset()
	game.gate_index = 5
	game.edge.add(4)
	for i in range(8):
		var pos := Vector2(220+i*90, game.player.y-110-(i%3)*70)
		game.projectiles.append({"pos":pos,"velocity":Vector2(200,80).rotated(i*.4),"kind":i%4})
	await capture("projectile_readability")
	game.state="title"
	await capture("title")
	for voice in game.soundscape.stems: voice.stop()
	await create_timer(.1).timeout
	game.queue_free()
	await process_frame
	await create_timer(.1).timeout
	quit()
