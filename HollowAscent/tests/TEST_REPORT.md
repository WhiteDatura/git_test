# 0.4 directional edition — validation report

Engine: Godot 4.4.1 stable (official 49a5bc7b6), Linux GL Compatibility.
The official Linux binary's SHA-512 was checked against the release checksum
file. The provided Godot 4.6.3 also ran development/component/render/audio checks;
the final reported suite and fresh extraction use 4.4.1.

## Passed

- Clean editor import: scripts, textures, font and audio resources load without errors.
- **139 combat assertions**: mouse press direction, immediate activation, Space
  facing, injected controller right-stick/A/X events, neutral facing fallback,
  input buffering, forward/rear/outside/normal/perfect geometry, swept contact,
  single reward for multiple deflections, cap/cost/refund, kill/rebound/miss,
  lunge damage vulnerability, HP/invulnerability/death/restart, and pause.
- Lunge travel integral agrees within 0.01 px at 30/60/120/240 Hz.
- Archer/duelist platforms: above-only landings at the drawn top, no underside
  collision, persistence after enemy death, walk-off, and no checkpoint binding.
  Every authored enemy platform intersects the player's horizontal movement bounds.
- Spawn safety: no attack inside the player; no damage on a new projectile's first frame.
- Five **normal-parry-only** traversals: rows 0–5, 30–35, 60–65, 90–95,
  120–125. All finish with 3 HP. The opening includes the first three directional
  encounters; the samples cover all four enemy families and later combined patterns.
- Audio source validation: 16-bit PCM, peaks with headroom, three equal 24-second
  music stems, continuous loop endpoints. Music combat/danger/recovery/duck state,
  repeated-effect cap, total voice cap and warning mix paths exercised.
- Clean menu/window shutdown retires active music/effect playback before exit.
- Rendered 26-second Godot stereo mix: calm/combat/danger/recovery, simultaneous
  effects and a music-loop crossing; no clipped samples. See audio_validation.txt
  for the measured peak and source statistics.
- 17 staged screenshots rendered at 1080×720 and visually reviewed: idle, opening,
  left/right/rising/falling parry, normal/perfect contact, lunge startup/movement/
  miss, enemy contact/death, rebound, platform landing, projectile/HUD readability,
  and title. A separate gameplay.png is captured from the running directional bot.
  Final render logs contain no script, polygon or asset errors. Software OpenGL
  reports an unsupported V-Sync-setting warning; rendering still completes.
- ZIP packaging uses one HollowAscent root, all explicit directories before file
  records, CRC validation, and extraction that never creates missing file parents.
  Fresh extraction is imported and the full standard suite is rerun by
  tools/package_project.py. See the distribution's adjacent fresh-checks transcript.

## Full ascent: FAILED / not verified

The final parry-only bot reaches section II and dies at row 39 at 188.25 simulated
seconds. Earlier iterations timed out around rows 36–39. This is **not** a passing
150-row traversal. The bot has directional aim but no lunge planning, platform
routing or high-level recovery strategy. Its failure does not establish either
that the ascent is impossible or that later encounters are balanced. The summit
and full-run completion flow remain unverified in this pass.

## Human playtesting still required

- Opening comprehension, learning curve and entire ascent difficulty.
- Real mouse/controller hardware response and stereo positioning in play.
- Animation transitions, katana weight and distinguishing contact feedback.
- Listening on headphones and ordinary speakers. The measured mix has headroom,
  but synthesis and numerical checks cannot certify realistic timbre or musical taste.
- Long-session fatigue, saves/options across real application restarts, and export
  builds on Windows/macOS. No standalone export is included.

The supplied art uses four poses. This pass supplements it procedurally; it does
not supply a new hand-animated character atlas or recorded acoustic foley.
