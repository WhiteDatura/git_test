# 0.4 synthesis and mix notes

The Python generator is the source of every WAV. Seed: 48104; sample rate: 32 kHz.
Effects use filtered broadband contact, low wooden/body transients, irregular
steel modes with short damping, and short cloth/air/paper textures. All source
files have headroom and non-looped endpoints taper to zero.

Music is a new 24-second pentatonic phrase at 80 BPM. Calm carries sparse breath
flute/plucked strings and a quiet bowed tone. Combat adds plucked pulse and low
drum. Danger adds another restrained pulse/percussion layer. Circular reflections
wrap tails across loop boundaries. Runtime stems start together and remain
phase-aligned while volumes blend; grounded recovery returns to calm. Wind has
an explicitly matched boundary. Impact ducking acts on all music/ambience stems.

CombatAudio limits identical effects to two and total effect voices to ten.
Effects use positional stereo with small pitch and volume variation. Warning
voices receive +2 dB over ordinary effects. A master limiter ceilings the sum
at -1 dBFS. There is no imported third-party audio.

Automated verification captures 26 seconds through Godot's real mixer, changing
music state, crossing a loop and overlapping six effect families four times per
second. tests/audio_checks.py validates source peaks and loop continuity, and
can analyze the captured s16 stereo WAV. It does not replace listening on real
headphones and speakers or perceptual comparison during interactive play.
