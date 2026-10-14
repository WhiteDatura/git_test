extends SceneTree
## Run rendered with --write-movie to capture the actual Godot mix, including limiter.
var mixer
var time: float = 0.0
var last_beat: int = -1
func _initialize() -> void:
	mixer = load("res://scripts/combat_audio.gd").new()
	root.add_child.call_deferred(mixer)
func _process(dt: float) -> bool:
	if not is_instance_valid(mixer) or not mixer.is_inside_tree(): return false
	time += dt
	var shots: int = 0 if time < 6 or time > 24 else (2 if time < 14 else 6)
	mixer.update_mix(dt,"play",1 if time>14 else 3,shots,shots==0,true)
	var beat: int = int(time*4)
	if beat != last_beat and shots>0:
		last_beat = beat
		for name in ["warning","arrow","draw","perfect" if beat%3==0 else "parry","enemy_hit","rebound"]:
			mixer.play_effect(name,180 if beat%2==0 else 900,true)
		if beat%3==0: mixer.duck(.18)
	if time > 26:
		print("AUDIO_MIX_OK 26s calm/combat/danger/recovery, loop boundary, overlapping effects")
		for voice in mixer.stems: voice.stop()
		quit()
	return false
