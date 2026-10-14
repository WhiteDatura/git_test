extends Node
const T = preload("res://scripts/tuning.gd")
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var stems: Array[AudioStreamPlayer] = []
var duck_time: float = 0.0
var rng := RandomNumberGenerator.new()
var mix_state: String = "calm"
func _ready() -> void:
	rng.seed = 17431
	# Limit the final summed mix, rather than relying on individual WAV peaks.
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db = -4.0
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, limiter)
	for name in ["parry", "perfect", "warning", "spirit", "blade", "sweep", "draw", "sheath", "miss", "fall", "land", "summit", "lunge", "enemy_hit", "rebound", "arrow", "paper_release", "flyby"]:
		streams[name] = load("res://assets/audio/" + name + ".wav")
	for name in ["music_calm", "music_combat", "music_danger", "wind"]:
		var voice := AudioStreamPlayer.new()
		var stream: AudioStreamWAV = load("res://assets/audio/" + name + ".wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		voice.stream = stream
		voice.volume_db = -80.0
		add_child(voice)
		stems.append(voice)
		if DisplayServer.get_name() != "headless" and "--autoplay" not in OS.get_cmdline_user_args() and not _capturing(): voice.play()
func play_effect(name: String, x: float, enabled: bool, pitch: float = 1.0) -> void:
	if not enabled or not streams.has(name): return
	voices = voices.filter(func(voice): return is_instance_valid(voice))
	var identical: int = 0
	for voice in voices:
		if voice.get_meta("sound") == name: identical += 1
	if identical >= 2 or voices.size() >= T.AUDIO_MAX_VOICES: return
	var voice := AudioStreamPlayer2D.new()
	voice.stream = streams[name]
	voice.set_meta("sound", name)
	voice.pitch_scale = pitch * rng.randf_range(0.975, 1.025)
	voice.volume_db = T.AUDIO_VOICE_DB + rng.randf_range(-1.2, 0.0) + (2.0 if name in ["warning", "spirit", "blade", "sweep"] else 0.0)
	voice.position = Vector2(clampf(x, 80.0, 1000.0), 360.0)
	voice.max_distance = 1800.0
	voice.panning_strength = 0.55
	add_child(voice)
	voices.append(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
func duck(duration: float) -> void:
	duck_time = maxf(duck_time, duration)
func update_mix(dt: float, state: String, hp: int, shots: int, grounded: bool, enabled: bool) -> void:
	duck_time = maxf(0.0, duck_time - dt)
	mix_state = "calm"
	if state == "play" and not grounded and shots > 0: mix_state = "combat"
	if state == "play" and not grounded and (hp == 1 or shots >= T.MUSIC_DANGER_SHOTS): mix_state = "danger"
	var targets: Array[float] = [T.MUSIC_CALM_DB, T.MUSIC_COMBAT_DB if mix_state != "calm" else -65.0, T.MUSIC_DANGER_DB if mix_state == "danger" else -65.0, -32.0]
	for i in range(stems.size()):
		var target: float = targets[i] - (T.MUSIC_DUCK_DB if duck_time > 0.0 else 0.0)
		if not enabled: target = -80.0
		if state == "pause": target -= 9.0
		stems[i].volume_db = lerpf(stems[i].volume_db, target, 1.0 - exp(-dt * (30.0 if duck_time > 0.0 else 2.5)))
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
	stems.clear()
	voices.clear()
	streams.clear()

func _capturing() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): return true
	return false
func stop_all() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D: child.stop()
