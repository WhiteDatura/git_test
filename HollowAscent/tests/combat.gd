extends SceneTree
var game
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1
	checks += 1
func shot(offset: Vector2, motion: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"pos": game.player + offset, "prev": game.player + offset, "velocity": motion, "age": 0.2, "kind": 0, "life": 2.0, "enemy": 0}
func reset() -> void:
	game._start()
	game.sound_on = false
func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	reset()
	game._test_gesture()
	var P = game.Parry
	check(P.contains(Vector2(70, 0), Vector2.RIGHT), "Forward sword reach")
	check(not P.contains(Vector2(74, 0), Vector2.RIGHT), "Outside sword reach")
	check(P.contains(Vector2.RIGHT.rotated(deg_to_rad(74))*60, Vector2.RIGHT), "Generous 150 degree normal sector")
	check(not P.contains(Vector2.RIGHT.rotated(deg_to_rad(76))*60, Vector2.RIGHT), "Outside sector")
	check(P.perfect(.115, Vector2.RIGHT.rotated(deg_to_rad(54))*60, Vector2.RIGHT), "Perfect 110 degree sector")
	check(not P.perfect(.115, Vector2.RIGHT.rotated(deg_to_rad(56))*60, Vector2.RIGHT), "Perfect direction must be precise")
	check(not P.perfect(.02, Vector2(60,0), Vector2.RIGHT), "Perfect timing must be central")
	check(not P.contact(Vector2(120,0), Vector2(-120,0), Vector2.ZERO, Vector2.RIGHT).is_empty(), "Swept shot cannot tunnel through sword")
	check(P.contact(Vector2(-120,-10), Vector2(-20,-10), Vector2.ZERO, Vector2.RIGHT).is_empty(), "Rear path is unsafe")
	# Actual event handlers, without a drag or release event.
	reset()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var mouse_direction: Vector2 = (game.get_local_mouse_position() - game._world(game.player)).normalized()
	game._unhandled_input(click)
	check(game.parry_age == 0.0 and game.slash_direction.dot(mouse_direction) > .999, "Mouse press immediately aims toward cursor")
	reset()
	game.facing = -1.0
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	check(game.slash_direction == Vector2.LEFT, "Space uses facing")
	reset()
	Input.use_accumulated_input = false
	var axis := InputEventJoypadMotion.new()
	axis.device = 0
	axis.axis = JOY_AXIS_RIGHT_Y
	axis.axis_value = -1.0
	game._unhandled_input(axis.duplicate())
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	game._unhandled_input(button)
	check(game.slash_direction == Vector2.UP, "Controller A uses right stick")
	reset()
	axis.axis_value = 0.0
	game._unhandled_input(axis.duplicate())
	game.facing = -1.0
	game._unhandled_input(button)
	check(game.slash_direction == Vector2.LEFT, "Neutral stick uses facing")
	reset()
	game.edge.add(2)
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 1.0
	game._unhandled_input(axis.duplicate())
	var lunge_button := InputEventJoypadButton.new()
	lunge_button.button_index = JOY_BUTTON_X
	lunge_button.pressed = true
	game._unhandled_input(lunge_button)
	check(game.lunge.active() and game.lunge.direction==Vector2.RIGHT, "Controller X lunges along right stick")
	axis.axis_value = 0.0
	game._unhandled_input(axis.duplicate())
	reset()
	game.cooldown = .035
	game._click_parry(Vector2.UP)
	for i in range(3): game._step(1.0/60)
	check(game.parry_age < .02 and game.slash_direction == Vector2.UP, "Buffered direction survives recovery")
	reset()
	game._click_parry(Vector2.LEFT)
	game.projectiles.append(shot(Vector2(30,0),Vector2(-1000,0)))
	game._update_projectiles(.02)
	check(game.health.current == 2 and game.edge.current == 0, "Rear attack damages during active parry")
	reset()
	game._click_parry(Vector2.RIGHT)
	game.projectiles.append(shot(Vector2(90,0),Vector2(-1800,0)))
	game.projectiles.append(shot(Vector2(95,0),Vector2(-1800,0)))
	game._update_projectiles(.02)
	check(game.projectiles.is_empty() and game.total_deflections == 2, "Swing catches multiple forward shots")
	check(game.edge.current == 1 and game.velocity.y < 0, "Single normal reward and upward launch per swing")
	reset()
	game._click_parry(Vector2.RIGHT)
	game.parry_age = .115
	game.projectiles.append(shot(Vector2(90,0),Vector2(-1800,0)))
	game._update_projectiles(.02)
	check(game.edge.current == 2 and game.perfect_count == 1, "Perfect rewards two Edge")
	game.edge.add(100)
	check(game.edge.current == 6, "Edge cap")
	reset()
	game._try_lunge(Vector2.RIGHT)
	check(not game.lunge.active(), "Lunge cannot start without Edge")
	game.edge.add(2)
	var source: Vector2 = game._source(game.gates[0])
	game.player = source + Vector2(120, 0)
	game._try_lunge(Vector2.LEFT)
	check(game.edge.current == 0 and game.lunge.active(), "Lunge costs two Edge")
	for i in range(10): game._step(1.0 / 60.0)
	check(game.kills == 1 and not game.enemy_states[0]["alive"], "Swept lunge kills enemy")
	check(game.edge.current == 1 and game.velocity.y < 0 and game.rebound_pose > 0, "Kill refunds one and rebounds")
	check(not game.enemy_response.deaths.is_empty(), "Enemy reaction persists after kill")
	# Exact integrated distance across realistic frame rates, not speed*frame shortcuts.
	var distances: Array[float] = []
	for hz in [30,60,120,240]:
		var l = game.Lunge.new()
		l.start(Vector2.RIGHT)
		var distance: float = 0.0
		while l.active():
			distance += l.travel(1.0/hz)
			l.tick(1.0/hz)
		distances.append(distance)
	check(distances.max()-distances.min() < .01, "Lunge distance consistent at 30/60/120/240Hz")
	reset()
	game.edge.add(2)
	game._try_lunge(Vector2.UP)
	for i in range(35): game._step(1.0 / 60.0)
	check(game.edge.current == 0 and not game.lunge.active() and game.velocity.y > 0, "Miss spends Edge and falls")
	reset()
	game.edge.add(2)
	game._try_lunge(Vector2.RIGHT)
	game.projectiles.append(shot(Vector2.ZERO))
	game._update_projectiles(.01)
	check(game.health.current == 2 and not game.lunge.active() and game.projectiles.size()==1, "Lunge remains vulnerable; projectiles stay live")
	reset()
	game._hit()
	game._hit()
	check(game.health.current == 2, "Overlapping hits respect invulnerability")
	game.health.tick(.71)
	game._hit()
	game.health.tick(.71)
	game._hit()
	check(game.health.current == 0 and game.state == "dead" and game.deaths == 1, "Three HP and death state")
	game._start()
	check(game.health.current == 3 and game.edge.current == 0 and game.deaths == 1, "Restart restores resources; session deaths persist")
	for kind in [0,2]:
		reset()
		var gate: Dictionary = game.gates[0].duplicate()
		gate["type"] = kind
		game.gates[0] = gate
		var platform: Vector2 = game._enemy_platform(gate)
		game.player = platform - Vector2(0, game.T.PLAYER_FOOT - 2)
		game.velocity = Vector2(0,100)
		game.grounded = false
		game._collide_ledges(game.player.y - 6)
		check(game.grounded and absf(game.player.y+game.T.PLAYER_FOOT-platform.y)<.1, "Visible platform top equals landing collision")
		check(game.checkpoint == 0, "Enemy platform does not bind checkpoint")
		game.enemy_states[0]["alive"] = false
		game._collide_ledges(game.player.y)
		check(game.grounded, "Dead enemy platform persists")
		game.player.x = platform.x+70
		game._collide_ledges(game.player.y)
		check(not game.grounded, "Walk off naturally")
		game.player = platform+Vector2(0,20)
		game.velocity.y = -100
		game._collide_ledges(game.player.y+10)
		check(not game.grounded, "No underside collision")
	reset()
	var close_gate: Dictionary = game.gates[18]
	var close_enemy: Dictionary = game.enemy_states[18]
	game.player = game._source(close_gate)
	check(not game._fire_aimed(close_gate,close_enemy,18) and game.projectiles.is_empty(), "Never spawn inside player")
	game.player += Vector2(100,0)
	check(game._fire_aimed(close_gate,close_enemy,18), "Safely spaced enemy can release")
	game.projectiles[0]["pos"] = game.player
	game.projectiles[0]["velocity"] = Vector2.ZERO
	game._update_projectiles(.016)
	check(game.health.current==3, "New projectile cannot damage on spawn frame")
	# Restore authored gates after platform fixture mutations.
	game.gates = game.L.build()
	reset()
	for index in range(3):
		check(game.Attacks.spread(index,0,0)==1 and game.Attacks.burst(index,0)==0 and game.Attacks.warning(index,0)>=.9, "Opening single readable shots")
	check(game.Attacks.spread(8,0,0)==2 and game.Attacks.burst(12,0)==2, "Later fan and burst progression")
	for gate in game.gates:
		if int(gate["type"]) in [0,2]:
			var top: Vector2 = game._enemy_platform(gate)
			check(top.x-59.0 <= 950.0 and top.x+59.0 >= 130.0, "Every enemy platform is inside horizontal movement bounds")
	var before: Vector2 = game.player
	game.state = "pause"
	game._step(.2)
	check(game.player==before, "Pause stops simulation")
	# Audio state/voice caps execute the real manager, even with a dummy device.
	game.soundscape.update_mix(1.0,"play",3,1,false,true)
	check(game.soundscape.mix_state=="combat", "Combat music state")
	game.soundscape.update_mix(1.0,"play",1,4,false,true)
	check(game.soundscape.mix_state=="danger", "Danger music state")
	game.soundscape.update_mix(1.0,"play",1,4,true,true)
	check(game.soundscape.mix_state=="calm", "Recovery music breath")
	game.soundscape.duck(.2)
	check(game.soundscape.duck_time>=.2, "Impact music ducking")
	for i in range(12): game.soundscape.play_effect("parry",540,true)
	check(game.soundscape.voices.size()==2, "Identical effect voice cap")
	for name in ["draw","perfect","miss","land","lunge","arrow","sweep","blade","spirit","rebound","enemy_hit"]: game.soundscape.play_effect(name,540,true)
	check(game.soundscape.voices.size()==game.T.AUDIO_MAX_VOICES, "Global audio voice cap")
	print("COMBAT_OK %d checks: directional input, swept sectors, rewards, lunge, health, platforms, pacing, audio" % checks)
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
