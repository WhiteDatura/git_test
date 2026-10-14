# Asset provenance — 0.4

## Supplied artwork

`mist.png`, `hero_ink.png`, `enemies_ink.png`, and `cliffs_ink.png` are retained
from the user-supplied Hollow Ascent ZIP. Its credits identify them as original
images generated for this game using an image-generation tool. This pass does
not claim authorship of the supplied images or independently verify their
creation history. The existing environment prompt is preserved below.
Additional scarf strokes, blade paths, projectile silhouettes, ink flecks,
contact sparks and fragment motion are procedural Godot drawing made for this
pass; no commercial-game visual assets were imported.

## Audio and music

All shipped WAVs were regenerated for 0.4 using the included deterministic
`assets/audio/generate_audio.py`. They contain original procedural synthesis:
filtered noise, damped steel modes, string/wood contact, cloth/air envelopes,
breathy flute-like harmonics, pentatonic plucks and low percussion. There are no
external recordings, sample packs or extracted game assets. The score is an
original 32-beat phrase at 80 BPM with three phase-aligned 24-second stems.
It evokes instrument textures; it is not a recording of acoustic instruments.

Generator dependencies NumPy and SciPy are tools only and are not embedded in
the playable project. The generator and audio-editing notes are included.
Normal and perfect impacts belong to the same family, with a stronger transient
and longer resonance for perfects. No audio or melody from Where Winds Meet or
another commercial game was copied.

## Fonts

Body.ttf is DejaVu Sans; Title.ttf is DejaVu Serif, as identified in the supplied
project. These are third-party fonts, not original game assets. The accompanying
Bitstream Vera / DejaVu license and copyright notices are preserved in
`assets/fonts/LICENSE.txt`.

Environment generation prompt:

> Use case: stylized-concept. Asset type: background illustration for an original
> 2D vertical parry climbing game, The Hollow Ascent. Wide 1536x1024 landscape
> composition. Sumi-e and graphite on warm ivory fibrous paper, black ink only
> with one tiny deep crimson hanging cloth. Ancient fragmented cliffs frame the
> far left and far right edges, ghostly distant mountains and an impossibly tall
> ruined shrine fading into fog. A solitary bare wind-bent pine grows from the
> right-hand cliff. Keep the middle 65 percent very pale empty mist for readable
> gameplay. Beautiful irregular dry brush edges, charcoal strokes and delicate
> ink washes, huge negative space, handmade independent game art, no characters,
> no text, no UI, no logos. This is original environment art.
