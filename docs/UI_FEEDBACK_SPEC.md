# UI feedback spec (design doc 4.33)

Owner rule, 2026-11-04. Every timing, volume, pitch and cue pairing below is a **placeholder**. The cue pairing per moment
lives in `docs/UI_AUDIT.md` (SFX audit) and in the `UiFeedback` table, which must agree.

## 1. Sounds
- `ServerStorage/ImpactSounds`: 5 `Sound`s, slots Tap, Thunk, Crack, Boom, Slash. They ship as Rojo models under
  `assets/sfx/ImpactSounds`, so nothing depends on saving the place. The owner swaps one by editing its id there.
- A server script copies the folder to `ReplicatedStorage/ImpactSounds` at start. Clients only read that copy.
- Extras, at most 4: Chime, Whoosh, Coin, Denied. Same folder and same copy.
- Every sound is free on the Creator Store, about 2 s at most (proposed; Chime is 2.1 s), with no official show audio (design doc 5). The UI sound
  ledger is the `Assets` table in `src/shared/UiSounds.luau`: slot, id, creator, name.
- Measured 2026-11-04 (`PlaybackLoudness` peak, which ignores `Sound.Volume`): Crack 826, Slash 499, Boom 467, Tap 341, Thunk 333, Whoosh 98, Coin 81, Denied 58, Chime 11. Cue volumes make up for it: Crack x0.6, Whoosh x2, Coin and Denied x3, Chime x5, from the audit's first values. Nobody has heard them yet.
- `HudPressSound` stays as it is (`RacerMotion`, harness pin): the base tick on every button.

## 2. Cues
- `Client/UiFeedback`: one table, cue name to motion and sound. Call sites use `UiFeedback.Play(cue, gui)`. A moment never
  plays a sound or an impact preset any other way.
- One `Sound` per cue, under `SoundService` in SoundGroup `UiSfx`. Volume is set once at creation, because the SOUND toggle
  zeroes `Sound.Volume` and restores what it read. Pitch may change per play.
- Each cue plays at most once per 0.05 s (proposed). No hover sound.
- Reduced motion: motion lands at once, sound still plays. SOUND off: every cue is silent.

## 3. Motion presets (in `Client/UiMotion`, design doc 4.20)
- `Slam`: from scale 1.5 to 1 with Back easing, under 0.2 s (proposed).
- `Impact`: Pop, Shake, one flash and one ring from the gui. A roll land leaves out the Shake: Legendary and Mythic shake once, on the figure.
- `Burst`: radial shards and anime speed lines from a point. Never in the roll (ROLL_ANIMATION_SPEC bans speed streaks), nor over a running roll or open panels (DEFEATED skips it then).
- `Fly`: coin pieces travel to the counter for a gain and from it for a spend; whatever they reach then pops. The counter is
  Money, or the Unbanked read-out for pay not banked yet (checkpoint bonus). The number itself counts as in 4.20.
- `Fill`: a bar tween, 0.2 s (proposed). The text beside it updates at once.
- Overlay pieces live in one pooled ScreenGui `UiFx`: never `Active`, at most 24 pieces (proposed), Frames with UICorner and
  UIGradient, no new art. Nothing is left behind after a preset ends.
- Under reduced motion these presets show nothing extra and end at rest.

## 4. Limits carried over
Design doc 4.20, 4.27, 4.28; ROLL_ANIMATION_SPEC. Harness values stay: hover 1.035, press 0.97, no hover strokes.
