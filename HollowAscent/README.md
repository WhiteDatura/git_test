# The Hollow Ascent — 0.4 directional edition

An editable, original ink-painted Godot game: climb by parrying attacks, spend Edge
on committed sword lunges, and rebound off enemies. There is no ordinary jump.
This continues the supplied 0.3 project and retains its art and five authored
sections (150 rows), saves, recovery ledges, menus, and accessibility options.

## Import and play

Use **Godot 4.4.1 Standard or newer** with GL Compatibility. Import
`HollowAscent/project.godot`, wait for assets to import, then press F5.
All playable assets are included; Python is only needed for tools and tests.
The distribution ZIP has explicit directory records for Godot Project Manager.

## Controls

| Action | Mouse / keyboard | Controller |
| --- | --- | --- |
| Horizontal movement | A/D or Left/Right | Left stick / D-pad |
| Directional parry | Point toward the attack, then left-click | Right stick + A |
| Facing parry | Space | A with neutral right stick |
| Directional lunge (2 Edge) | Right-click toward cursor | Right stick + X; neutral uses facing |
| Pause / resume | Escape | Start |
| Restart | R | Pause menu: Restart ascent |
| Fullscreen | F11 | — |

**Point toward the attack. Click to parry.** Activation happens on the press.
Aim is captured for that swing; moving the cursor afterwards does not redirect it.
The small blade-tip cue indicates the selected aim. A/D still controls movement.

## Combat and opening

The forward sword sector has **150° coverage, 72 px reach, a 230 ms active window,
and 300 ms between swings**. Rear and out-of-arc attacks remain dangerous.
Perfect parries require the central **55 ms timing interval** and a narrower
**110° direction sector**. Normal parries give 1 Edge; perfects give 2. One swing
rewards Edge once even when it catches several shots. Edge caps at 6.

A lunge spends 2 Edge. A kill refunds 1 and launches an upward rebound. Misses
receive no refund and leave a visible recovery with gradual horizontal control.
Lunges do not protect against projectiles. Swept weapon collision and integrated
acceleration keep lunge travel consistent at 30/60/120/240 Hz.

The first archer fires one slow arrow after a long windup. The second attacks
from the opposite side. The third, a paper spirit, changes sides between repeated
straight attacks. Only the current tutorial attacker is active. These opening
parries give more lift, so their slower timing remains useful for climbing.
Repeated singles precede a delayed windup, fans, short bursts, tracking paper,
and finally multiple windups. Harder authored sections remain.

Health is 3 HP; ordinary hits take one and give 0.7 seconds of hit invulnerability.
Zero HP ends the run. Restart restores HP and clears Edge; deaths persist for the
application session. Falling itself costs progress, not HP. Only the five authored
recovery ledges bind checkpoints. Archer and duelist platforms accept descending
landings, have no underside collision, can be walked off, and persist after kills.

## Presentation and sound

Directional unsheathing includes short compression, rising/falling blade paths,
a visible katana, brush follow-through, local contact sparks, and quiet sheathing.
Lunges lead with the blade; kills freeze briefly, show an ink cut and four large
fragments, then rebound with a downward scarf response. Existing ink illustrations
retain their texture, with restrained pale edging. Projectile families have
separate silhouettes, crimson motion strokes, pale backing, and close flybys.

The replaced audio is **original procedural sound design**, not recorded acoustic
instruments: damped steel contact, scrape, cloth/air cuts, bow release, paper,
heavy blade, damage, kill and rebound. Three synchronized 24-second original
pentatonic music layers add breath-flute, plucked strings, low percussion and
bowed tones over wind. Calm/combat/danger blend without restarting. Recovery
reduces density; strong impacts duck the music. Pitch/level variation, voice caps
and a final limiter control repetition and overlap. See ASSET_CREDITS.md.

## Tests and editable systems

From this directory:

```sh
python tests/run_checks.py /path/to/godot
python tests/run_checks.py /path/to/godot --full
# Requires a graphical display (Xvfb is suitable for automated rendering):
godot --path . --script res://tests/visual.gd
# Captures a real 26-second stereo mix including overlap and a loop:
godot --path . --fixed-fps 12 --write-movie /tmp/hollow-mix.avi --script res://tests/audio_mix.gd
```

Tests isolate player save/config paths. The normal suite imports, checks combat
and platform behavior, traverses five sampled encounters, and validates WAVs and
loop boundaries. The optional full bot is parry-only, not a human or a lunge
planner. See `tests/TEST_REPORT.md` for actual outcomes and limitations.
Rendered pose fixtures are in `screenshots/`; they are not proof of traversal.

- `scripts/tuning.gd`: timing, arcs, reach, gravity, launch, opening lift, audio/music thresholds.
- `scripts/parry.gd`: swept forward-sector contact and perfect timing/direction.
- `scripts/attack_schedule.gd`: enemy warning, speed, fan and burst progression.
- `scripts/health.gd`, `edge.gd`, `lunge.gd`: resources and lunge motion/recovery.
- `scripts/player_animation.gd`, `enemy_response.gd`: procedural poses and contact/death response.
- `scripts/combat_audio.gd`: voices, panning, music mixing and ducking.
- `scripts/level.gd`: authored lanes, attack families and sections.
- `scripts/game.gd`: input, deterministic simulation, camera, UI and integration.

Audio can be regenerated with `python assets/audio/generate_audio.py`
(requires NumPy and SciPy). Regeneration is unnecessary for playtesting.

## Known limitations

Subjective sword weight, animation transitions, tutorial difficulty, controller
hardware feel and the mix on headphones/ordinary speakers need human playtesting.
This is a procedural pose pass over the existing four-frame art, not new bespoke
frame-by-frame character animation. Audio is synthesized and may still need
recorded foley in a later art/audio pass. The final parry-only full-run bot dies at row 39 in section II; complete
ascent balance and summit arrival are unverified. See the validation report.
No new regions, bosses, upgrades or other major systems are added.
