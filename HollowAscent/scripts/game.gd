extends Node2D
## A single deterministic simulation, also used by the headless traversal tests.
const T = preload("res://scripts/tuning.gd")
const L = preload("res://scripts/level.gd")
const INK = Color("202321")
const PAPER = Color("eee9dc")
const CRIMSON = Color("983b42")
const MUTED = Color("797b73")
const SAVE_PATH = "user://hollow_ascent.cfg"
const TITLE_FONT = preload("res://assets/fonts/Title.ttf")
const BODY_FONT = preload("res://assets/fonts/Body.ttf")

const Health = preload("res://scripts/health.gd")
const Edge = preload("res://scripts/edge.gd")
const Parry = preload("res://scripts/parry.gd")
const Attacks = preload("res://scripts/attack_schedule.gd")
const CombatAudio = preload("res://scripts/combat_audio.gd")
const EnemyResponse = preload("res://scripts/enemy_response.gd")
var soundscape
var enemy_response = EnemyResponse.new()
var rebound_pose: float = 0.0
var aim_preview: Vector2 = Vector2.RIGHT
var controller_axes: Dictionary = {}
var last_controller: int = 0
const Lunge = preload("res://scripts/lunge.gd")
var health = Health.new()
var edge = Edge.new()
var lunge = Lunge.new()
var deaths: int = 0
var kills: int = 0
var state: String = "title"
var gates: Array[Dictionary] = []
var player: Vector2 = Vector2(540, -24)
var velocity: Vector2 = Vector2.ZERO
var camera_y: float = -230.0
var clock: float = 0.0
var elapsed: float = 0.0
var gate_index: int = 0
var checkpoint: int = 0
var grounded: bool = true
var chain: int = 0
var best_chain: int = 0
var falls: int = 0
var perfect_count: int = 0
var normal_count: int = 0
var momentum: float = 0.0
var parry_age: float = 99.0
var cooldown: float = 0.0
var input_buffer: float = 0.0
var immunity: float = 0.0
var hit_stop: float = 0.0
var slowmo: float = 0.0
var flash: float = 0.0
var shake: float = 0.0
var landing_squash: float = 0.0
var facing: float = 1.0
var falling_marked: bool = false
var warn_age: float = -1.0
var attack_delay: float = 0.45
var repeat_delay: float = 0.0
var projectiles: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var buttons: Array[Dictionary] = []
var selected: int = 0
var last_mouse: Vector2 = Vector2.ZERO
var notification: String = ""
var notification_time: float = 0.0
var section_time: float = 0.0
var current_section: int = 0
var best_time: float = 0.0
var reduced_shake: bool = false
var contrast: bool = false
var sound_on: bool = true
var assist: bool = false
var run_assisted: bool = false
var bg: Texture2D
var hero_art: Texture2D
var enemy_art: Texture2D
var rock_art: Texture2D
var buffered_direction: Vector2 = Vector2.RIGHT
var slash_direction: Vector2 = Vector2.RIGHT
var slash_visual_age: float = 99.0
var swing_connected: bool = false
var contact_direction: Vector2 = Vector2.RIGHT
var sheath_played: bool = true
var enemy_states: Array[Dictionary] = []
var next_impact_time: float = 0.0
var total_deflections: int = 0
var rng = RandomNumberGenerator.new()
var auto_mode: bool = false
var auto_normal: bool = false
var auto_failure: bool = false
var test_steps: int = 0
var test_failed_once: bool = false
var test_recovered: bool = false
var test_seen_checkpoint: int = 0
var test_seen_pause: bool = false
var test_seen_buffer: bool = false
var screenshot_path: String = ""
var screenshot_done: bool = false
var test_start_row: int = 0
var trace_test: bool = false
var test_section: bool = false

func _ready() -> void:
	rng.seed = 93017
	gates = L.build()
	get_window().focus_exited.connect(_focus_lost)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_quit_cleanly)
	_load_save()
	if ResourceLoader.exists("res://assets/mist.png"):
		bg = load("res://assets/mist.png")
	if ResourceLoader.exists("res://assets/hero_ink.png"): hero_art = load("res://assets/hero_ink.png")
	if ResourceLoader.exists("res://assets/enemies_ink.png"): enemy_art = load("res://assets/enemies_ink.png")
	if ResourceLoader.exists("res://assets/cliffs_ink.png"): rock_art = load("res://assets/cliffs_ink.png")
	soundscape = CombatAudio.new()
	add_child(soundscape)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	auto_mode = "--autoplay" in args
	auto_normal = "--normal-only" in args
	auto_failure = "--failure-test" in args
	trace_test = "--trace" in args
	test_section = "--section-test" in args
	for arg in args:
		if arg.begins_with("--test-row="): test_start_row = int(arg.trim_prefix("--test-row="))
		if arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
	if auto_mode:
		assist = false
		sound_on = false
		_test_gesture()
		_start()
		if test_start_row > 0:
			checkpoint = test_start_row
			_respawn()
			falls = 0
	queue_redraw()

func _quit_cleanly() -> void:
	state = "closing"
	if soundscape: soundscape.stop_all()
	# Let the audio thread retire looping WAV playback before freeing resources.
	await get_tree().create_timer(0.08).timeout
	get_tree().quit()

func _load_save() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_time = cfg.get_value("record", "draw_best_time", 0.0)
		reduced_shake = cfg.get_value("options", "reduced_shake", false)
		contrast = cfg.get_value("options", "contrast", false)
		sound_on = cfg.get_value("options", "sound", true)
		assist = cfg.get_value("options", "assist", false)

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _save() -> void:
	if auto_mode:
		return
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("record", "draw_best_time", best_time)
	cfg.set_value("options", "reduced_shake", reduced_shake)
	cfg.set_value("options", "contrast", contrast)
	cfg.set_value("options", "sound", sound_on)
	cfg.set_value("options", "assist", assist)
	var error: Error = cfg.save(SAVE_PATH)
	if error != OK:
		notification = "Could not save locally. Your run is still complete."
		notification_time = 8.0

func _sound(name: String, pitch: float = 1.0, at: Vector2 = player) -> void:
	if soundscape: soundscape.play_effect(name, at.x, sound_on, pitch)

func _start() -> void:
	state = "play"
	health.reset()
	edge.reset()
	lunge.reset()
	kills = 0
	selected = 0
	player = Vector2(540, -T.PLAYER_FOOT)
	velocity = Vector2.ZERO
	camera_y = -230.0
	elapsed = 0.0
	gate_index = 0
	checkpoint = 0
	chain = 0
	best_chain = 0
	falls = 0
	perfect_count = 0
	normal_count = 0
	momentum = 0.0
	parry_age = 99.0
	cooldown = 0.0
	input_buffer = 0.0
	immunity = 0.0
	hit_stop = 0.0
	slowmo = 0.0
	flash = 0.0
	shake = 0.0
	warn_age = -1.0
	attack_delay = 2.2
	repeat_delay = 0.0
	grounded = true
	falling_marked = false
	projectiles.clear()
	particles.clear()
	trails.clear()
	current_section = 0
	section_time = 5.0
	notification_time = 0.0
	run_assisted = assist
	_cancel_draw()
	slash_visual_age = 99.0
	swing_connected = false
	total_deflections = 0
	next_impact_time = 0.0
	enemy_states.clear()
	enemy_response.reset()
	rebound_pose = 0.0
	for gate in gates:
		enemy_states.append({"warn": -1.0, "reload": 0.0, "aim": gate["pos"], "fired": 0, "alive": true, "burst": 0, "burst_timer": 0.0, "side": float(gate["side"]), "next_side": float(gate["side"])})

func _cancel_draw() -> void:
	input_buffer = 0.0

func _controller_aim(device: int = 0) -> Vector2:
	var stick: Vector2 = controller_axes.get(device, Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)))
	return stick.normalized() if stick.length() > 0.22 else Vector2(facing, 0)

func _focus_lost() -> void:
	if state == "play" and not auto_mode:
		_cancel_draw()
		state = "pause"
		selected = 0

func _inside_cut(contact: Vector2) -> bool:
	return Parry.contains(contact - player, slash_direction)

func _click_parry(direction: Vector2 = Vector2.ZERO) -> void:
	if state != "play" or lunge.active(): return
	buffered_direction = direction.normalized() if direction.length() > 0.1 else Vector2(facing, 0)
	input_buffer = T.INPUT_BUFFER
	if cooldown <= 0.0: _activate_parry()

func _activate_parry() -> void:
	parry_age = 0.0
	cooldown = T.PARRY_COOLDOWN
	input_buffer = 0.0
	slash_direction = buffered_direction
	slash_visual_age = 0.0
	swing_connected = false
	sheath_played = false
	_sound("draw")

func _test_gesture() -> void:
	_start()
	_click_parry(Vector2.LEFT)
	assert(parry_age == 0.0, "Click activates on the input event")
	assert(_inside_cut(player + Vector2(-40, 0)))
	assert(not _inside_cut(player + Vector2(40, 0)), "Rear remains dangerous")
	assert(not _inside_cut(player + Vector2(0, -40)), "Outside 150 degree arc")
	_cancel_draw()
	assert(input_buffer == 0.0)
	print("CLICK_OK immediate directional parry / rear unsafe / cancellation")

func _try_lunge(direction: Vector2) -> void:
	if state != "play" or lunge.cooldown > 0.0 or direction.length() < 0.1: return
	if not edge.spend(Lunge.COST):
		notification = "Lunge needs 2 Edge — parry to earn it."
		notification_time = 1.3
		return
	_cancel_draw()
	parry_age = 99.0
	lunge.start(direction)
	grounded = false
	momentum = 0.0
	_sound("lunge", 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		last_controller = event.device
		var axes: Vector2 = controller_axes.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_RIGHT_X: axes.x = event.axis_value
		else: axes.y = event.axis_value
		controller_axes[event.device] = axes
		aim_preview = _controller_aim(event.device)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_lunge(get_local_mouse_position() - _world(player))
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and event.pressed:
		_try_lunge(_controller_aim(event.device))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and state == "play": _click_parry()
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event.keycode == KEY_ESCAPE:
			_cancel_draw()
			if state == "play":
				state = "pause"
				selected = 0
			elif state == "pause": state = "play"
			elif state == "options":
				state = "title"
				selected = 0
			return
		if event.physical_keycode == KEY_R and state in ["play", "pause", "complete", "dead"]:
			_start()
			return
		if state != "play":
			if event.keycode in [KEY_DOWN, KEY_S]: selected = (selected + 1) % maxi(1, buttons.size())
			if event.keycode in [KEY_UP, KEY_W]: selected = posmod(selected - 1, maxi(1, buttons.size()))
			if event.keycode in [KEY_ENTER, KEY_SPACE] and selected < buttons.size(): _activate(buttons[selected]["action"])
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if state == "play":
			if event.pressed: _click_parry(get_local_mouse_position() - _world(player))
		elif event.pressed:
			for button in buttons:
				if button["rect"].has_point(get_local_mouse_position()):
					_activate(button["action"])
					break
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_A:
			if state == "play":
				if event.pressed: _click_parry(_controller_aim(event.device))
			elif event.pressed and selected < buttons.size(): _activate(buttons[selected]["action"])
		if event.pressed:
			if event.button_index == JOY_BUTTON_START:
				_cancel_draw()
				if state == "play": state = "pause"
				elif state == "pause": state = "play"
			if event.button_index == JOY_BUTTON_DPAD_DOWN: selected = (selected + 1) % maxi(1, buttons.size())
			if event.button_index == JOY_BUTTON_DPAD_UP: selected = posmod(selected - 1, maxi(1, buttons.size()))
	queue_redraw()

func _activate(action: String) -> void:
	match action:
		"play", "restart": _start()
		"resume": state = "play"
		"options": state = "options"
		"title": state = "title"
		"quit": _quit_cleanly()
		"shake": reduced_shake = not reduced_shake
		"contrast": contrast = not contrast
		"sound": sound_on = not sound_on
		"assist": assist = not assist
	if action in ["shake", "contrast", "sound", "assist"]:
		_save()
	else:
		selected = 0

func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var fit: float = minf(viewport_size.x / 1080.0, viewport_size.y / 720.0)
	scale = Vector2.ONE * fit
	position = (viewport_size - Vector2(1080, 720) * fit) * 0.5
	clock += delta
	if soundscape:
		soundscape.update_mix(delta, state, health.current, projectiles.size(), grounded, sound_on)
	if not auto_mode:
		var mouse: Vector2 = get_local_mouse_position()
		if mouse.distance_to(last_mouse) > 2.0:
			for i in range(buttons.size()):
				if buttons[i]["rect"].has_point(mouse):
					selected = i
		if mouse.distance_to(last_mouse) > 2.0: aim_preview = (mouse - _world(player)).normalized()
		last_mouse = mouse
		var stick_aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick_aim.length() > 0.22: aim_preview = stick_aim.normalized()
	queue_redraw()
	if not screenshot_path.is_empty() and not screenshot_done and clock > 0.10:
		screenshot_done = true
		_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	if not auto_mode:
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if auto_mode:
		_test_driver(delta)
		return
	_step(delta)

func _step(delta: float) -> void:
	if state != "play":
		return
	elapsed += delta
	flash = maxf(0.0, flash - delta * 3.0)
	shake = maxf(0.0, shake - delta * 17.0)
	notification_time = maxf(0.0, notification_time - delta)
	section_time = maxf(0.0, section_time - delta)
	if hit_stop > 0.0:
		hit_stop -= delta
		return
	var dt: float = delta
	if slowmo > 0.0:
		slowmo -= delta
		dt *= 0.65
	health.tick(dt)
	var was_lunging: bool = lunge.active()
	var lunge_distance: float = lunge.travel(dt) if was_lunging else 0.0
	lunge.tick(dt)
	rebound_pose = maxf(0.0, rebound_pose - dt)
	enemy_response.tick(dt)
	parry_age += dt
	slash_visual_age += dt
	if slash_visual_age > 0.38 and not sheath_played:
		_sound("sheath")
		sheath_played = true
	cooldown = maxf(0.0, cooldown - dt)
	input_buffer = maxf(0.0, input_buffer - dt)
	immunity = maxf(0.0, immunity - dt)
	landing_squash = maxf(0.0, landing_squash - dt * 4.0)
	if input_buffer > 0.0 and cooldown <= 0.0:
		_activate_parry()
	var horizontal: float = _horizontal()
	if absf(horizontal) > 0.1:
		facing = signf(horizontal)
	var speed: float = T.GROUND_SPEED if grounded else T.AIR_SPEED
	velocity.x = move_toward(velocity.x, horizontal * speed, T.HORIZONTAL_ACCEL * dt * lunge.control_weight())
	if current_section == 2 and not grounded:
		velocity.x += sin(player.y * 0.004) * T.WIND_FORCE * dt
	var previous_y: float = player.y
	if was_lunging:
		var previous: Vector2 = player
		velocity = lunge.direction * lunge.speed()
		player += lunge.direction * lunge_distance
		for i in range(enemy_states.size()):
			if not enemy_states[i]["alive"]: continue
			var source: Vector2 = _source(gates[i])
			if _closest_segment(previous + lunge.direction * 18.0, player + lunge.direction * Lunge.REACH, source).distance_to(source) < 28.0:
				enemy_states[i]["alive"] = false
				enemy_states[i]["warn"] = -1.0
				enemy_states[i]["burst"] = 0
				kills += 1
				edge.add(1)
				lunge.remaining = 0.0
				momentum = T.MOMENTUM_DURATION
				velocity = Vector2(lunge.direction.x * 120.0, -T.REBOUND_SPEED)
				hit_stop = T.KILL_HITSTOP
				shake = T.CAMERA_SHAKE
				rebound_pose = 0.32
				enemy_response.strike(source, lunge.direction, int(gates[i]["type"]))
				falling_marked = false
				_sound("enemy_hit", 1.0, source)
				_sound("rebound")
				if soundscape: soundscape.duck(0.20)
				_burst(source, 9, false)
				break
	elif not grounded:
		momentum = maxf(0.0, momentum - dt)
		if momentum <= 0.0:
			velocity.y = maxf(velocity.y, 50.0)
			_break_chain()
		velocity.y = minf(T.MAX_FALL_SPEED, velocity.y + (T.GRAVITY if momentum > 0.0 else T.FALL_GRAVITY) * dt)
		player += velocity * dt
	else:
		player.x += velocity.x * dt
	player.x = clampf(player.x, 130, 950)
	_collide_ledges(previous_y)
	if not grounded and velocity.y > 70.0 and momentum <= 0.0 and not falling_marked:
		_mark_fall()
	if player.y > _ledge_y(checkpoint) + T.FALL_RESET_DISTANCE:
		_respawn()
	_update_attacks(dt)
	_update_projectiles(dt)
	_update_particles(dt)
	camera_y = lerpf(camera_y, player.y - 110.0, 1.0 - exp(-dt * 5.5))
	if not grounded and int(elapsed * 60.0) % 3 == 0:
		trails.append({"pos": player + Vector2(0, 12), "life": 0.22, "width": 1.2})
	if gate_index >= gates.size() and grounded and player.y < _summit_y() + 10.0:
		_complete()

func _horizontal() -> float:
	if auto_mode and gate_index < gates.size():
		var gap: float = gates[gate_index]["pos"].x - player.x
		return clampf(gap / 38.0, -1.0, 1.0)
	var axis: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): axis -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): axis += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): axis -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): axis += 1.0
	var stick: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	if absf(stick) > 0.18: axis += stick
	return clampf(axis, -1.0, 1.0)

func _enemy_platform(gate: Dictionary) -> Vector2:
	var source: Vector2 = _source(gate)
	var face: float = -1.0 if source.x > 540.0 else 1.0
	return source + Vector2(-face * 27.0, 70.0 if gate["type"] == 0 else 62.0)

func _ledge_y(index: int) -> float:
	return -float(index) * T.ROW_HEIGHT

func _summit_y() -> float:
	return -float(gates.size()) * T.ROW_HEIGHT + 70.0

func _collide_ledges(previous_y: float) -> void:
	var on_ledge: bool = false
	var ledges: Array[int] = T.CHECKPOINT_ROWS.duplicate()
	ledges.append(gates.size())
	for row in ledges:
		var y: float = _summit_y() if row == gates.size() else _ledge_y(row)
		var half_width: float = 200.0 if row == 0 or row == gates.size() else 115.0
		if absf(player.x - 540.0) > half_width:
			continue
		if velocity.y >= 0.0 and previous_y + T.PLAYER_FOOT <= y + 3.0 and player.y + T.PLAYER_FOOT >= y:
			player.y = y - T.PLAYER_FOOT
			velocity.y = 0.0
			on_ledge = true
			if not grounded:
				_sound("land")
				_burst(player + Vector2(0, 22), 12, false)
				landing_squash = 1.0
				if row >= checkpoint and row < gates.size():
					checkpoint = row
					if falling_marked or row > gate_index:
						_reset_encounter(row)
				if row == 0 and gate_index > 0:
					_reset_encounter(0)
			falling_marked = false
			break
	if not on_ledge:
		for gate in gates:
			if gate["type"] not in [0, 2]: continue
			var platform: Vector2 = _enemy_platform(gate)
			if absf(player.x - platform.x) <= 59.0 and velocity.y >= 0.0 and previous_y + T.PLAYER_FOOT <= platform.y + 3.0 and player.y + T.PLAYER_FOOT >= platform.y:
				player.y = platform.y - T.PLAYER_FOOT
				velocity.y = 0.0
				on_ledge = true
				if not grounded:
					_sound("land")
					landing_squash = 1.0
				falling_marked = false
				break
	grounded = on_ledge
	# Passing a recovery ledge on ascent binds it immediately; no mandatory landing.
	for row in T.CHECKPOINT_ROWS:
		if row > checkpoint and gate_index >= row and player.y + T.PLAYER_FOOT < _ledge_y(row) and absf(player.x - 540.0) < 115.0:
			checkpoint = row
			notification = "A place to breathe.  /  Recovery ledge reached"
			notification_time = 3.0

func _reset_encounter(row: int) -> void:
	gate_index = row
	projectiles.clear()
	warn_age = -1.0
	attack_delay = 0.65
	repeat_delay = 0.0
	current_section = mini(4, row / 30)
	next_impact_time = elapsed
	_cancel_draw()
	enemy_response.reset()
	for e in enemy_states:
		e["warn"] = -1.0
		e["reload"] = 0.0
		e["alive"] = true
		e["burst"] = 0
	lunge.reset()
	momentum = 0.0
	chain = 0

func _mark_fall() -> void:
	falling_marked = true
	falls += 1
	_sound("fall")

func _break_chain() -> void:
	chain = 0

func _respawn() -> void:
	if not falling_marked:
		_mark_fall()
	player = Vector2(540, _ledge_y(checkpoint) - T.PLAYER_FOOT)
	velocity = Vector2.ZERO
	grounded = true
	falling_marked = false
	immunity = 0.6
	_reset_encounter(checkpoint)
	trails.clear()
	camera_y = player.y - 110.0

func _update_attacks(dt: float) -> void:
	if player.y + T.PLAYER_FOOT < _summit_y():
		gate_index = gates.size()
		return
	var row: int = maxi(checkpoint, clampi(int(maxf(0.0, -player.y - 25) / T.ROW_HEIGHT), 0, gates.size() - 1))
	gate_index = maxi(gate_index, row)
	var section: int = mini(4, row / 30)
	if section != current_section:
		current_section = section
		section_time = 4.0
	if attack_delay > 0.0:
		attack_delay -= dt
		return
	# Every enemy aims at the live player. More simultaneous windups unlock uphill.
	var max_windups: int = [1, 2, 2, 3, 3][section]
	var max_shots: int = [1, 4, 5, 6, 7][section]
	if row < 3:
		for index in range(enemy_states.size()):
			if index != row: enemy_states[index]["warn"] = -1.0
	var active_windups: int = 0
	for e in enemy_states:
		e["reload"] = maxf(0.0, e["reload"] - dt)
		if e["warn"] >= 0.0: active_windups += 1
	for index in range(maxi(0, row - 1), mini(gates.size(), row + 3)):
		if row < 3 and index != row: continue
		if grounded and row in T.CHECKPOINT_ROWS and index > row: continue
		var gate: Dictionary = gates[index]
		var e: Dictionary = enemy_states[index]
		if not e["alive"]: continue
		if index == 2 and e["warn"] < 0.0 and projectiles.is_empty():
			e["side"] = move_toward(e["side"], e["next_side"], dt * 1.5)
			if absf(e["side"] - e["next_side"]) > 0.01: continue
		var source: Vector2 = _source(gate)
		var vertical_distance: float = absf(source.y - player.y)
		var screen_source: Vector2 = _world(source)
		if vertical_distance > 640.0 or source.y > player.y + 300.0 or screen_source.y < 96.0 or screen_source.y > 695.0:
			e["warn"] = -1.0
			continue
		if e["burst"] > 0:
			e["burst_timer"] -= dt
			if e["burst_timer"] <= 0.0:
				_fire_aimed(gate, e, index)
				e["burst"] -= 1
				e["burst_timer"] = 0.42
			continue
		var duelist: bool = gate["type"] == 2
		if duelist and (source.distance_to(player) > 180.0):
			e["warn"] = -1.0
			continue
		if e["warn"] < 0.0:
			if active_windups >= max_windups or projectiles.size() >= max_shots or e["reload"] > 0.0 or (row < 3 and not projectiles.is_empty()): continue
			e["warn"] = 0.0
			active_windups += 1
			_sound(["warning", "spirit", "sweep", "blade"][gate["type"]])
		var duration: float = Attacks.warning(index, int(gate["type"]))
		if e["warn"] < duration - 0.12:
			var flight: float = clampf(source.distance_to(player) / T.PROJECTILE_SPEED, 0.30, 0.72)
			e["aim"] = _predict_player(flight, 0.72 + section * 0.055)
		e["warn"] += dt
		if e["warn"] >= duration:
			if not _fire_aimed(gate, e, index):
				e["warn"] = duration - 0.001
				continue
			e["warn"] = -1.0
			e["reload"] = T.ENEMY_RELOAD + (index % 4) * 0.13
			e["fired"] += 1
			if index == 2: e["next_side"] = -e["next_side"]
			if Attacks.burst(index, int(gate["type"])) > 0:
				e["burst"] = Attacks.burst(index, int(gate["type"]))
				e["burst_timer"] = 0.42
			active_windups -= 1
	# Windups leaving the active window cannot become invisible attacks.
	for index in range(enemy_states.size()):
		if index < row - 1 or index > row + 2: enemy_states[index]["warn"] = -1.0

func _predict_player(time: float, lead: float = 1.0) -> Vector2:
	if grounded: return player + Vector2(velocity.x * time * lead, 0)
	# Follow the same momentum expiry and falling integration as the live player.
	var predicted: Vector2 = player
	var motion: Vector2 = velocity
	var lift: float = momentum
	var remaining: float = time
	while remaining > 0.00001:
		var dt: float = minf(1.0 / 60.0, remaining)
		lift = maxf(0.0, lift - dt)
		if lift <= 0.0: motion.y = maxf(motion.y, 50.0)
		motion.y = minf(T.MAX_FALL_SPEED, motion.y + (T.GRAVITY if lift > 0.0 else T.FALL_GRAVITY) * dt)
		predicted += Vector2(motion.x * lead, motion.y) * dt
		remaining -= dt
	return predicted

func _fire_aimed(gate: Dictionary, enemy: Dictionary, index: int) -> bool:
	var origin: Vector2 = _source(gate)
	var kind: int = gate["type"]
	if origin.distance_to(player) < T.PLAYER_HIT_RADIUS + 18.0: return false
	var flight: float = clampf(origin.distance_to(player) / Attacks.speed(index, kind), 0.38, 1.25)
	# Reserve a readable rhythm across different attackers. Fans share one impact beat.
	flight = maxf(flight, next_impact_time - elapsed)
	next_impact_time = elapsed + flight + T.MIN_IMPACT_GAP
	var aim: Vector2 = _predict_player(flight, 0.72 + current_section * 0.055)
	# Last 120 ms of the visible windup lock horizontal aim; a change of direction can dodge.
	aim.x = lerpf(aim.x, enemy["aim"].x, 0.38)
	aim.x = clampf(aim.x, 240, 840)
	var count: int = Attacks.spread(index, kind, current_section)
	_sound(["arrow", "paper_release", "sweep", "blade"][kind], 1.0, origin)
	if trace_test: print("FIRE i=%d t=%.2f player=%s aim=%s flight=%.2f" % [index,elapsed,player,aim,flight])
	var base_velocity: Vector2 = (aim - origin) / flight
	for pellet in range(count):
		var spread: float = (float(pellet) - float(count - 1) * 0.5) * (0.115 if kind == 0 else 0.10)
		var motion: Vector2 = base_velocity.rotated(spread)
		projectiles.append({"pos": origin, "prev": origin, "origin": origin, "target": aim, "velocity": motion, "age": 0.0, "kind": kind, "life": flight + 0.9, "enemy": index})

	return true

func _source(gate: Dictionary) -> Vector2:
	var target: Vector2 = gate["pos"]
	var side: float = float(gate["side"])
	if int(gate["index"]) == 2 and enemy_states.size() > 2: side = float(enemy_states[2]["side"])
	match int(gate["type"]):
		0: return Vector2(clampf(target.x + side * T.PROJECTILE_SPEED * T.PROJECTILE_FLIGHT_TIME, 190.0, 890.0), target.y - 8.0)
		1: return target + Vector2(side * 180, -90)
		2: return target + Vector2(side * 78, 0)
		_: return target + Vector2(0, -T.PROJECTILE_SPEED * T.PROJECTILE_FLIGHT_TIME)

func _closest_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var fraction: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return a + ab * fraction

func _update_projectiles(dt: float) -> void:
	var duration: float = T.PARRY_WINDOW + (0.09 if run_assisted else 0.0)
	for i in range(projectiles.size() - 1, -1, -1):
		if i >= projectiles.size(): continue
		var shot: Dictionary = projectiles[i]
		shot["age"] += dt
		shot["life"] -= dt
		shot["prev"] = shot["pos"]
		if shot["kind"] == 1 and int(shot["enemy"]) >= 16 and shot["age"] < 0.75:
			var desired: Vector2 = (_predict_player(0.12) - shot["pos"]).normalized() * T.HOMING_SPEED
			shot["velocity"] = shot["velocity"].lerp(desired, minf(dt * T.HOMING_TURN, 1.0))
		shot["pos"] += shot["velocity"] * dt
		if not shot.get("flyby", false) and shot["pos"].distance_to(player) < 180.0:
			shot["flyby"] = true
			_sound("flyby", 1.0, shot["pos"])
		var contact: Vector2 = _closest_segment(shot["prev"], shot["pos"], player)
		var distance: float = contact.distance_to(player)
		var radius: float = 9.0 if shot["kind"] == 1 else 7.0
		var blade_contact: Dictionary = Parry.contact(shot["prev"], shot["pos"], player, slash_direction)
		if parry_age <= duration and not blade_contact.is_empty():
			contact = blade_contact["point"]
			projectiles.remove_at(i)
			total_deflections += 1
			if not swing_connected:
				var perfect: bool = Parry.perfect(parry_age, contact - player, slash_direction, duration)
				_success(perfect, contact)
			else:
				_burst(contact, 2, false)
			continue
		if distance <= T.PLAYER_HIT_RADIUS + radius and immunity <= 0.0 and shot["age"] >= 0.10:
			_hit()
			return
		if shot["life"] <= 0.0 or shot["pos"].distance_to(player) > 1200.0:
			projectiles.remove_at(i)

func _success(perfect: bool, point: Vector2) -> void:
	# Only the directional sword sector destroys attacks; other threats remain live.
	if trace_test: print("PARRY t=%.2f row=%d player=%s" % [elapsed,gate_index,player])
	swing_connected = true
	contact_direction = (point - player).normalized()
	edge.add(2 if perfect else 1)
	chain += 1
	best_chain = maxi(best_chain, chain)
	if perfect: perfect_count += 1
	else: normal_count += 1
	grounded = false
	falling_marked = false
	momentum = T.MOMENTUM_DURATION
	var launch: float = T.OPENING_LAUNCH if gate_index < 3 else T.LAUNCH_SPEED
	if gate_index < 3: momentum = T.OPENING_MOMENTUM
	velocity.y = -launch - (T.PERFECT_LAUNCH_BONUS if perfect else 0.0)
	velocity.x += _horizontal() * T.LAUNCH_STEER
	hit_stop = T.PERFECT_HITSTOP if perfect else T.NORMAL_HITSTOP
	slowmo = T.PERFECT_SLOWMO if perfect else 0.0
	shake = T.CAMERA_SHAKE * (1.0 if perfect else 0.55)
	flash = 0.0
	_sound("perfect" if perfect else "parry", 1.0, point)
	if perfect and soundscape: soundscape.duck(0.18)
	enemy_response.spark(point, perfect)
	_burst(point, 7 if perfect else 4, false)
	notification = "PERFECT" if perfect else ""
	notification_time = 0.45 if perfect else 0.0

func _hit() -> void:
	if not health.damage(): return
	lunge.remaining = 0.0
	if health.current == 0:
		deaths += 1
		state = "dead"
		selected = 0
	if trace_test:
		print("HIT gate=%d pos=%s vel=%s parry=%.2f dir=%s shots=%s" % [gate_index,player,velocity,parry_age,slash_direction,projectiles])
	velocity.x = -facing * 190.0
	momentum = 0.0
	velocity.y = 240.0
	grounded = false
	parry_age = 99.0
	chain = 0
	immunity = 0.7
	shake = T.CAMERA_SHAKE
	flash = 0.0
	_cancel_draw()
	warn_age = -1.0
	repeat_delay = 1.0
	_sound("miss")
	_burst(player, 5, false)
	if not falling_marked: _mark_fall()

func _complete() -> void:
	state = "complete"
	projectiles.clear()
	selected = 0
	_sound("summit")
	if not run_assisted and (best_time <= 0.0 or elapsed < best_time):
		best_time = elapsed
	_save()
	if auto_mode:
		if auto_failure:
			assert(test_failed_once and test_recovered and test_seen_pause and test_seen_buffer, "Recovery, pause or buffer test was not exercised")
			assert(falls >= 1 and perfect_count > 0, "Failure/perfect traversal did not exercise both branches")
		print("TRAVERSAL_OK time=%.2f falls=%d best_chain=%d normal=%d perfect=%d checkpoint=%d" % [elapsed, falls, best_chain, normal_count, perfect_count, checkpoint])
		get_tree().quit(0)

func _burst(at: Vector2, amount: int, red: bool) -> void:
	for i in range(amount):
		var direction: Vector2 = Vector2.from_angle(rng.randf() * TAU)
		particles.append({"pos": at, "velocity": direction * rng.randf_range(40, 125), "life": rng.randf_range(0.12, 0.32), "size": rng.randf_range(0.6, 1.8), "red": red and i % 3 == 0})

func _update_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i]["life"] -= dt
		particles[i]["pos"] += particles[i]["velocity"] * dt
		particles[i]["velocity"].y += 180.0 * dt
		if particles[i]["life"] <= 0.0: particles.remove_at(i)
	for i in range(trails.size() - 1, -1, -1):
		trails[i]["life"] -= dt
		if trails[i]["life"] <= 0.0: trails.remove_at(i)

func _test_driver(dt: float) -> void:
	# Each frame runs exact 60 Hz simulation ticks. No collision/physics shortcuts.
	for unused in range(24):
		if state == "complete": return
		if state == "dead":
			print("TEST_DEATH row=%d time=%.2f" % [gate_index, elapsed])
			get_tree().quit(1)
			return
		if test_section and gate_index >= test_start_row + 5:
			print("ENCOUNTER_OK rows=%d..%d HP=%d cuts=%d" % [test_start_row, gate_index, health.current, normal_count + perfect_count])
			get_tree().quit(0)
			return
		test_steps += 1
		if auto_failure and falls > 0 and not test_failed_once:
			test_failed_once = true
		if auto_failure and test_failed_once and grounded and checkpoint == 30:
			test_recovered = true
		if auto_failure and not test_seen_pause and gate_index > 3:
			var before: Vector2 = player
			var time_before: float = elapsed
			state = "pause"
			_step(dt)
			assert(player == before and elapsed == time_before, "Pause changed simulation")
			state = "play"
			test_seen_pause = true
		if auto_failure and not test_seen_buffer and gate_index > 5 and hit_stop <= 0.0 and slowmo <= 0.0 and projectiles.is_empty():
			cooldown = 0.035
			input_buffer = T.INPUT_BUFFER
			_step(dt)
			_step(dt)
			_step(dt)
			assert(parry_age < 0.05, "Buffered parry did not activate")
			test_seen_buffer = true
		var suppress_parry: bool = auto_failure and ((gate_index == 36 and not test_failed_once) or (test_failed_once and not test_recovered))
		if cooldown <= 0.0 and hit_stop <= 0.0 and not suppress_parry:
			for shot in projectiles:
				var future: float = 0.10 if not auto_normal else 0.016
				var point: Vector2 = shot["pos"] + shot["velocity"] * future
				var expected: Vector2 = _predict_player(future)
				if point.distance_to(expected) < T.PARRY_RADIUS:
					_click_parry((shot["pos"] - player).normalized())
					break
		_step(dt)
		if gate_index / 30 > test_seen_checkpoint:
			test_seen_checkpoint = gate_index / 30
			print("SECTION %d at %.2f sec / height %.0f" % [test_seen_checkpoint, elapsed, -player.y])
		if test_steps > 60 * (20 if trace_test else 600):
			push_error("TRAVERSAL_TIMEOUT gate=%d y=%.1f falls=%d checkpoint=%d cuts=%d" % [gate_index, player.y, falls, checkpoint, normal_count+perfect_count])
			get_tree().quit(1)
			return

func _world(at: Vector2) -> Vector2:
	var offset: Vector2 = Vector2.ZERO
	if not reduced_shake and state == "play":
		offset = Vector2(sin(clock * 107.0), cos(clock * 91.0)) * shake
	return at - Vector2(0, camera_y) + Vector2(0, 360) + offset

func _text(at: Vector2, value: String, size: int = 16, color: Color = INK, title: bool = false) -> void:
	draw_string(TITLE_FONT if title else BODY_FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(y: float, value: String, size: int = 16, color: Color = INK, title: bool = false) -> void:
	var font: Font = TITLE_FONT if title else BODY_FONT
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(540 - width * 0.5, y), value, size, color, title)

func _button(rect: Rect2, label: String, action: String) -> void:
	var focused: bool = buttons.size() == selected
	buttons.append({"rect": rect, "action": action})
	if focused:
		draw_rect(rect, INK)
		draw_rect(Rect2(rect.position + Vector2(-5, 5), Vector2(3, rect.size.y - 10)), CRIMSON)
	else:
		draw_rect(rect, Color(0.92, 0.90, 0.85, 0.65))
		draw_line(rect.position + Vector2(0, rect.size.y), rect.end, Color(INK, 0.25), 1.0)
	var width: float = BODY_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_text(rect.position + Vector2((rect.size.x - width) * 0.5, rect.size.y * 0.5 + 6), label, 16, PAPER if focused else INK)

func _draw() -> void:
	buttons.clear()
	_background()
	if state == "closing":
		_center(360, "The wind rests.", 24, INK, true)
		return
	if state in ["title", "options"]:
		_title_scene()
		return
	_environment()
	for trail in trails:
		var at: Vector2 = _world(trail["pos"])
		draw_line(at, at + Vector2(-velocity.x * 0.03, 18), Color(INK, trail["life"] * 0.20), trail["width"], true)
	var visible_row: int = clampi(int(maxf(0, -player.y - 25) / T.ROW_HEIGHT), 0, gates.size() - 1)
	for i in range(maxi(0, visible_row - 2), mini(gates.size(), visible_row + 4)):
		if gates[i]["type"] in [0, 2]:
			var platform: Vector2 = _world(_enemy_platform(gates[i]))
			_draw_cliff(platform, 122, 74, i + 19)
			draw_line(platform - Vector2(59, 0), platform + Vector2(59, 0), INK, 3, true)
		if enemy_states[i]["alive"] and (visible_row >= 3 or i <= visible_row): _draw_enemy_ink(gates[i], enemy_states[i], i)
	for shot in projectiles:
		_draw_projectile(shot)
	for particle in particles:
		draw_circle(_world(particle["pos"]), particle["size"] * minf(1.0, particle["life"] * 3.0), Color(CRIMSON if particle["red"] else INK, minf(1.0, particle["life"] * 3.0)))
	enemy_response.draw_on(self)
	_draw_player(_world(player), 1.0)
	_hud()
	if state == "pause":
		draw_rect(Rect2(0, 0, 1080, 720), Color(PAPER, 0.91))
		_center(225, "A held breath.", 44, INK, true)
		_center(265, "The mountain can wait.", 16, MUTED)
		_button(Rect2(390, 305, 300, 47), "Resume", "resume")
		_button(Rect2(390, 367, 300, 47), "Restart ascent", "restart")
		_button(Rect2(390, 429, 300, 47), "Return to title", "title")
		_center(535, "ESC  resume    /    R  restart", 13, MUTED)
	if state == "dead":
		draw_rect(Rect2(0, 0, 1080, 720), Color(PAPER, 0.91))
		_center(255, "The thread breaks.", 42, INK, true)
		_center(303, "%d deaths / %d kills / %d cuts" % [deaths, kills, normal_count + perfect_count], 16, MUTED)
		_button(Rect2(390, 355, 300, 47), "Rise again", "restart")
		_center(445, "R to restart", 13, MUTED)
	if state == "complete":
		_completion_screen()

func _background() -> void:
	draw_rect(Rect2(0, 0, 1080, 720), PAPER)
	if bg:
		draw_texture_rect(bg, Rect2(0, -12, 1080, 744), false, Color(1, 1, 1, 0.68))
	# Fine deterministic fibres, deliberately subtle beneath the illustration.
	for i in range(145):
		var x: float = fposmod(i * 79.731, 1080)
		var y: float = fposmod(i * 173.921, 720)
		draw_line(Vector2(x, y), Vector2(x + 2 + i % 6, y - 1), Color(INK, 0.025), 1)
	for i in range(16):
		var y: float = fposmod(i * 71.3 + clock * (8 + i % 4), 780) - 30
		var x: float = fposmod(i * 167.8 + clock * (13 + i % 3), 1160) - 40
		draw_line(Vector2(x, y), Vector2(x + 22, y - 3), Color(INK, 0.11), 1, true)
	draw_line(Vector2(28, 28), Vector2(80, 28), Color(INK, 0.45), 1)
	draw_line(Vector2(28, 28), Vector2(28, 80), Color(INK, 0.45), 1)
	draw_line(Vector2(1052, 640), Vector2(1052, 692), Color(INK, 0.45), 1)
	draw_line(Vector2(1000, 692), Vector2(1052, 692), Color(INK, 0.45), 1)

func _title_scene() -> void:
	# Readable ink wash under typography; original figure at the right edge.
	draw_rect(Rect2(70, 75, 630, 570), Color(PAPER, 0.80))
	_text(Vector2(105, 122), "THE DIRECTIONAL EDITION  /  0.4", 12, MUTED)
	_text(Vector2(100, 220), "The Hollow", 62, INK, true)
	_text(Vector2(100, 291), "Ascent", 77, INK, true)
	draw_line(Vector2(108, 324), Vector2(240, 324), CRIMSON, 3.0, true)
	_text(Vector2(108, 362), "Point toward the attack. Click to parry.", 19, INK)
	_text(Vector2(108, 392), "Read the steel. Find your next foothold.", 16, MUTED)
	_draw_cliff(Vector2(817, 529), 180, 160, 7)
	_draw_player(Vector2(825, 466), 2.5)
	if state == "title":
		_button(Rect2(108, 434, 255, 48), "Begin ascent", "play")
		_button(Rect2(108, 495, 255, 44), "Accessibility & sound", "options")
		_button(Rect2(108, 552, 255, 40), "Quit", "quit")
		if best_time > 0.0: _text(Vector2(398, 465), "BEST  " + _time(best_time), 14, CRIMSON)
		_text(Vector2(108, 642), "A / D  move    CLICK / SPACE  parry    ESC  pause", 12, MUTED)
	else:
		draw_rect(Rect2(75, 325, 615, 340), Color(PAPER, 0.98))
		_button(Rect2(108, 348, 445, 42), "Reduced shake  /  " + ("ON" if reduced_shake else "OFF"), "shake")
		_button(Rect2(108, 401, 445, 42), "High-contrast warnings  /  " + ("ON" if contrast else "OFF"), "contrast")
		_button(Rect2(108, 454, 445, 42), "Sound  /  " + ("ON" if sound_on else "OFF"), "sound")
		_button(Rect2(108, 507, 445, 42), "Wider timing window  /  " + ("ON" if assist else "OFF"), "assist")
		_button(Rect2(108, 570, 255, 42), "Back", "title")
		_text(Vector2(108, 641), "Assisted runs keep statistics but do not replace your best time.", 12, MUTED)
	_text(Vector2(788, 666), "THE SWORD LEAVES ITS SHEATH.", 10, MUTED)

func _environment() -> void:
	var first: int = int(floor((camera_y - 650) / 430.0))
	for i in range(first, first + 5):
		var y: float = i * 430.0
		var left: bool = posmod(i, 2) == 0
		var x: float = 192.0 if left else 888.0
		_draw_cliff(_world(Vector2(x, y)), 210 + posmod(i, 3) * 17, 200, i)
		if posmod(i, 3) == 0:
			_pine(_world(Vector2(x, y - 5)), -1.0 if left else 1.0, 0.72)
		if current_section >= 3:
			var top: Vector2 = _world(Vector2(x, y - 120))
			draw_line(top, top + Vector2(0, 120), Color(INK, 0.40), 7)
			draw_line(top + Vector2(-55, -10), top + Vector2(55, 2), Color(INK, 0.40), 9)
	for row in T.CHECKPOINT_ROWS:
		var y: float = _ledge_y(row)
		var screen: Vector2 = _world(Vector2(540, y))
		if screen.y > -150 and screen.y < 880:
			_draw_cliff(screen, 400 if row == 0 else 230, 140, row + 101)
			if row > 0:
				draw_line(screen + Vector2(-88, 0), screen + Vector2(-88, -59), INK, 3)
				draw_colored_polygon(PackedVector2Array([screen + Vector2(-88, -58), screen + Vector2(-50, -53), screen + Vector2(-62, -37), screen + Vector2(-88, -40)]), CRIMSON)
				_text(screen + Vector2(-82, 37), "REST", 10, PAPER)
	var summit: Vector2 = _world(Vector2(540, _summit_y()))
	if summit.y > -500 and summit.y < 900:
		_draw_cliff(summit, 400, 300, 705)
		_pine(summit + Vector2(130, -3), -1, 1.5)
		draw_arc(summit + Vector2(0, -190), 48, 0, TAU, 48, Color(INK, 0.20), 1.3, true)

func _atlas(texture: Texture2D, columns: int, rows: int, frame: int, at: Vector2, dimensions: Vector2, anchor: Vector2 = Vector2(0.5, 0.5), mirrored: bool = false, angle: float = 0.0, tint: Color = Color.WHITE) -> void:
	if texture == null: return
	var cell: Vector2 = texture.get_size() / Vector2(columns, rows)
	var region: Rect2 = Rect2(Vector2(frame % columns, frame / columns) * cell, cell)
	draw_set_transform(at, angle, Vector2(-1, 1) if mirrored else Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(-anchor * dimensions, dimensions), region, tint, false, true)
	draw_set_transform(Vector2.ZERO)

func _draw_cliff(at: Vector2, width: float, depth: float, seed_value: int) -> void:
	var tile: int = 3 if seed_value == 705 else posmod(seed_value, 3)
	var top: float = [0.225, 0.235, 0.31, 0.305][tile]
	var coverage: float = [0.91, 0.92, 0.61, 0.9][tile]
	_atlas(rock_art, 2, 2, tile, at, Vector2(width / coverage, depth / (0.98 - top)), Vector2(0.5, top))

func _pine(_at: Vector2, _direction: float, _amount: float) -> void:
	# Painted trees are part of the background and the summit terrain tile.
	pass

func _outlined_atlas(texture: Texture2D, frame: int, at: Vector2, size: Vector2, anchor: Vector2, mirrored: bool, angle: float, opacity: float = 1.0) -> void:
	for offset in [Vector2(-1, -1), Vector2(1, 1)]:
		_atlas(texture, 2, 2, frame, at + offset, size, anchor, mirrored, angle, Color(PAPER, opacity))
	_atlas(texture, 2, 2, frame, at, size * 1.015, anchor, mirrored, angle, Color(0.10, 0.11, 0.10, opacity))
	_atlas(texture, 2, 2, frame, at, size, anchor, mirrored, angle, Color(1, 1, 1, opacity))

func _draw_player(at: Vector2, amount: float) -> void:
	var animation = preload("res://scripts/player_animation.gd")
	var pose: Dictionary = animation.sample(slash_visual_age, slash_direction, lunge, rebound_pose, grounded, velocity)
	var face: float = float(pose["face"]) if pose["face"] != 0.0 else facing
	var offset: Vector2 = pose["offset"]
	offset.y += sin(clock * 2.1) * 0.7 + landing_squash * 3.0
	var opacity: float = 0.55 if health.invulnerability > 0.0 and int(clock * 18) % 2 == 0 else 1.0
	_outlined_atlas(hero_art, pose["frame"], at + offset * amount, Vector2(116, 116) * amount, Vector2(0.65, 0.72), face < 0, pose["tilt"], opacity)
	# The long scarf lags the body and snaps downward during rebound.
	if state in ["play", "pause"]:
		var scarf := PackedVector2Array()
		for i in range(8):
			var fraction: float = float(i) / 7.0
			var tail := Vector2(-face * fraction * 60.0, sin(clock * 9.0 - fraction * 4.0) * 7.0 * fraction)
			if lunge.active(): tail = -lunge.direction * fraction * 85.0 + lunge.direction.orthogonal() * sin(fraction * 6.0 - clock * 10.0) * 4.0
			if rebound_pose > 0.0: tail = Vector2(-face * fraction * 24.0 + sin(fraction * PI) * 13.0, fraction * 65.0)
			scarf.append(at + (Vector2(0, -25) + tail) * amount)
		for i in range(scarf.size()-1):
			draw_line(scarf[i], scarf[i+1], Color(CRIMSON, 0.80), (5.5 - i * 0.6) * amount, true)
	var blade_visible: bool = slash_visual_age < 0.38 or lunge.active() or lunge.cooldown > 0.0 or rebound_pose > 0.0
	if blade_visible and state in ["play", "pause"]:
		if swing_connected and hit_stop > 0.0 and not lunge.active(): pose["blade_angle"] = contact_direction.angle()
		var direction: Vector2 = Vector2.from_angle(pose["blade_angle"])
		var reach: float = Lunge.REACH if lunge.active() or lunge.cooldown > 0.0 else T.PARRY_RADIUS
		var hilt: Vector2 = at + direction * 12.0
		var tip: Vector2 = at + direction * reach
		draw_line(hilt, tip, INK, 5.0, true)
		draw_line(hilt, tip, PAPER, 2.2, true)
		draw_line(hilt - direction.orthogonal() * 5.0, hilt + direction.orthogonal() * 5.0, INK, 3.0, true)
		if slash_visual_age <= T.PARRY_WINDOW and not lunge.active():
			for stroke in range(3):
				var points := PackedVector2Array()
				for j in range(10):
					var angle: float = float(pose["blade_angle"]) - float(pose["sweep_sign"]) * j * 0.060
					points.append(at + Vector2.from_angle(angle) * (reach - stroke * 2.2 + sin(j * 3) * 0.7))
				draw_polyline(points, Color(INK, 0.65 - stroke * 0.16), 3.2 - stroke * 0.8, true)
		if lunge.active():
			for i in range(3):
				var start: Vector2 = at - lunge.direction * (18.0 + i * 5.0)
				draw_line(start, start - lunge.direction * 55.0 + lunge.direction.orthogonal() * (i - 1) * 3.0, Color(INK, 0.28), 2.0 - i * 0.5, true)
			if lunge.age() < Lunge.ANTICIPATION: draw_line(at + Vector2(-15, 24), at + Vector2(17, 24), INK, 2.0, true)
	if state == "play" and slash_visual_age > 0.38 and not lunge.active():
		# Small blade-tip cue makes the selected direction readable without a UI ring.
		var direction: Vector2 = aim_preview if aim_preview.length() > 0.1 else Vector2(facing, 0)
		draw_line(at + direction * 36, at + direction * 46, Color(INK, 0.35), 1.5, true)
	if contrast and parry_age <= T.PARRY_WINDOW:
		draw_arc(at, T.PARRY_RADIUS, slash_direction.angle() - T.CUT_HALF_ANGLE, slash_direction.angle() + T.CUT_HALF_ANGLE, 24, Color(CRIMSON, 0.65), 1.2, true)

func _draw_enemy_ink(gate: Dictionary, enemy: Dictionary, index: int) -> void:
	var source: Vector2 = _world(_source(gate))
	if source.y < -170 or source.y > 890: return
	var kind: int = gate["type"]
	var active: bool = enemy["warn"] >= 0.0
	var progress: float = clampf(enemy["warn"] / Attacks.warning(index, kind), 0.0, 1.0)
	var aim: Vector2 = _world(enemy["aim"])
	var face: float = -1.0 if player.x < _source(gate).x else 1.0
	var anchor: Vector2 = [Vector2(0.83, 0.34), Vector2(0.55, 0.36), Vector2(0.54, 0.42), Vector2(0.5, 0.96)][kind]
	var size: Vector2 = [Vector2(112, 112), Vector2(96, 106), Vector2(114, 114), Vector2(90, 114)][kind]
	var angle: float = sin(clock * 2.0 + index) * 0.016
	if active: angle -= progress * 0.065 * face
	var offset: Vector2 = Vector2(0, sin(clock * 2.3 + index) * 4) if kind == 1 else Vector2.ZERO
	if kind == 3:
		draw_line(source - Vector2(0, 104), source - Vector2(0, 240), Color(INK, 0.50), 1, true)
	_outlined_atlas(enemy_art, kind, source + offset, size, anchor, face < 0 and kind != 3, angle)
	if active:
		var line: Vector2 = (aim - source).normalized()
		# The weapon edge darkens before release; aim is readable without neon rings.
		draw_line(source - line * 10, source + line * (9 + progress * 12), Color(CRIMSON, 0.4 + progress * 0.5), 1.4, true)
		if progress > 0.55:
			draw_line(source + line * 23, source + line * 64, Color(INK, 0.09 + progress * 0.07), 0.7, true)
		if contrast:
			draw_dashed_line(source, aim, Color(CRIMSON, 0.6), 1.4, 7, true)
			draw_arc(source, 17, -PI / 2, -PI / 2 + progress * TAU, 32, CRIMSON, 1.5, true)
	if gate_index < 2 and index == 0:
		_text(source + Vector2(-90, -57), "POINT TOWARD THE ATTACK. CLICK TO PARRY.", 9, MUTED)

func _draw_projectile(shot: Dictionary) -> void:
	var at: Vector2 = _world(shot["pos"])
	var direction: Vector2 = shot["velocity"].normalized()
	var side: Vector2 = direction.orthogonal()
	var kind: int = shot["kind"]
	draw_line(at - direction * 40, at, Color(PAPER, 0.95), 9, true)
	draw_line(at - direction * 36, at, CRIMSON, 4.5, true)
	draw_circle(at, 6.5, PAPER)
	draw_circle(at, 4.5, CRIMSON)
	if kind == 1:
		_atlas(enemy_art, 2, 2, 1, at, Vector2(26, 29), Vector2(0.55, 0.48), false, direction.angle() + PI / 2)
	elif kind == 2:
		var blade := PackedVector2Array([at+direction*9,at-direction*19+side*7,at-direction*23+side*3,at-direction*5-side*4])
		draw_colored_polygon(blade, INK)
		draw_line(at-direction*18+side*5, at+direction*8, PAPER, 1.3, true)
		draw_line(at-direction*8, at+direction*5, CRIMSON, 2.0, true)
	elif kind == 3:
		var blade := PackedVector2Array([at+direction*13,at-direction*13+side*8,at-direction*21+side*7,at-direction*21-side*7,at-direction*13-side*8])
		draw_colored_polygon(blade, INK)
		draw_line(at-direction*18+side*6, at+direction*10, PAPER, 1.6, true)
		draw_line(at-direction*18, at-direction*5, CRIMSON, 2.0, true)
	else:
		var length: float = 30.0 if kind == 0 else 22.0
		draw_line(at - direction * length, at, INK, 1.8 if kind == 0 else 3.0, true)
		draw_line(at - direction * (length - 2) + side, at - direction * 3 + side, Color(PAPER, 0.90), 0.8, true)
		draw_colored_polygon(PackedVector2Array([at + direction * 7, at - direction * 6 + side * 4, at - direction * 3 - side * 3]), INK)
		if kind == 0:
			draw_line(at - direction * 25, at - direction * 31 + side * 5, INK, 1.1, true)
			draw_line(at - direction * 25, at - direction * 31 - side * 5, INK, 1.1, true)
		draw_line(at - direction * 5, at + direction * 4, CRIMSON, 1.6, true)
	if contrast:
		draw_circle(at, 10, CRIMSON, false, 1.4, true)

func _hud() -> void:
	draw_rect(Rect2(344, 30, 442, 54), Color(PAPER, 0.92))
	_text(Vector2(360, 53), "HP  " + " / ".join([str(health.current), str(Health.MAX_HP)]), 14, CRIMSON)
	_text(Vector2(480, 53), "EDGE  %d / %d" % [edge.current, Edge.CAP], 14, INK)
	_text(Vector2(650, 53), "RMB lunge · 2 Edge", 12, MUTED)
	_text(Vector2(360, 76), "%d kills   /   %d deaths" % [kills, deaths], 11, MUTED)
	draw_rect(Rect2(38, 34, 265, 54), Color(PAPER, 0.88))
	draw_rect(Rect2(910, 25, 88, 65), Color(PAPER, 0.88))
	draw_rect(Rect2(38, 660, 315, 30), Color(PAPER, 0.88))
	draw_rect(Rect2(783, 660, 217, 30), Color(PAPER, 0.88))
	_text(Vector2(51, 57), "THE HOLLOW ASCENT", 12, INK)
	_text(Vector2(51, 77), _time(elapsed) + "   /   " + str(falls) + (" fall" if falls == 1 else " falls"), 12, MUTED)
	_text(Vector2(923, 55), str(chain) + " cuts", 16, INK if chain > 0 else MUTED, true)
	_text(Vector2(924, 76), "UNBROKEN", 8, MUTED)
	var progress: float = clampf(float(gate_index) / float(gates.size()), 0, 1)
	draw_line(Vector2(1025, 130), Vector2(1025, 581), Color(INK, 0.20), 1)
	draw_line(Vector2(1025, 581), Vector2(1025, 581 - 451 * progress), INK, 2)
	for i in range(6):
		draw_line(Vector2(1020, 581 - i * 90.2), Vector2(1030, 581 - i * 90.2), INK, 1)
	draw_circle(Vector2(1025, 581 - 451 * progress), 4, CRIMSON)
	if section_time > 0.0 and gate_index > 3:
		_center(126, L.SECTIONS[current_section], 20, Color(INK, minf(section_time, 1)), true)
		_center(151, L.SUBTITLES[current_section], 12, Color(MUTED, minf(section_time, 1)))
	if gate_index < 3:
		draw_rect(Rect2(269, 104, 542, 82), Color(PAPER, 0.92))
		_center(130, "THE FIRST BREATH", 16, INK, true)
		_center(154, "Point toward the attack. Click to parry.", 14)
		_center(175, "A / D move · SPACE facing parry · RMB lunge: 2 Edge", 11, MUTED)
	if gate_index == 1:
		_center(233, "The next attack comes from the other side.", 14, CRIMSON)
	if gate_index == 2:
		_center(233, "Precise direction and timing create a perfect parry.", 13, MUTED)
	if notification_time > 0.0:
		if notification == "PERFECT":
			var at: Vector2 = _world(player)
			_text(at + Vector2(-32, -65), "PERFECT", 11, CRIMSON)
		else:
			_center(650, notification, 13, INK)
	if gate_index >= gates.size() and state == "play":
		_center(150, "The last step is silence.", 24, INK, true)
	_text(Vector2(49, 681), "CLICK / SPACE  parry     A / D  move", 11, MUTED)
	_text(Vector2(796, 681), "R  restart     ESC  pause", 11, MUTED)
	if run_assisted: _text(Vector2(49, 106), "WIDER WINDOW", 9, CRIMSON)

func _time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]

func _completion_screen() -> void:
	draw_rect(Rect2(218, 122, 644, 509), Color(PAPER, 0.96))
	_center(174, "VI   /   STILL WATER ABOVE THE CLOUDS", 11, MUTED)
	_center(241, "Nothing left to climb.", 40, INK, true)
	_center(279, "For a moment, even the wind is quiet.", 15, MUTED)
	draw_line(Vector2(495, 303), Vector2(585, 303), CRIMSON, 2)
	_center(354, _time(elapsed), 41, INK, true)
	_center(387, "%d falls    /    %d best chain    /    %d perfect parries" % [falls, best_chain, perfect_count], 14)
	_center(420, "Assisted ascent" if run_assisted else "PERSONAL BEST  " + _time(best_time), 11, CRIMSON)
	_button(Rect2(382, 465, 316, 46), "Climb again", "restart")
	_button(Rect2(382, 525, 316, 42), "Return to title", "title")
