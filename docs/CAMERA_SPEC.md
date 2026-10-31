# Camera Spec

Rule source: `docs/GAME_DESIGN_REQUIREMENTS.md` section 4.12 (owner request 2026-10-31). This spec never contradicts it.

## 1. Track camera
- Owner request, verbatim: "change player camera angle to always be facing in the direction the player is moving. So
  a players camera angle is always moving aligned with the track as if it is shift locking. This is a camera
  perspective that can be changed in settings. If toggled off, camera angle is regular."
- When: the local player is racing (`AutoRacing`), the camera follows the visible runner (WORLD_REDESIGN_SPEC 2), the
  runner is moving (`RunSpeed` > 0 on a route) and the camera is the default `Custom` camera.
- What: each frame the camera yaw turns toward the runner's travel direction (the path tangent the runner faces,
  `PathDriver.PoseAt`), by an exponential lerp: `yaw += wrap(target - yaw) x (1 - exp(-RATE x dt))`. The camera
  rotates about its focus, so the player's zoom distance is kept.
- `RATE = 4` per second (placeholder). Pitch: the player's own (no forced pitch, placeholder). Distance: the player's
  own zoom (no forced distance, placeholder).
- The player may drag the yaw; it eases back to the travel direction.
- Stopped runner, held duel start, race end, respawn: nothing is forced; the regular camera carries on from where it is.
- Outside races: the regular camera (placeholder). No runner moves outside a race; the avatar walks freely.
- TOP-DOWN VIEW on: top-down wins while both are on (it owns the camera as `Scriptable`).
- Code: `Client/RunnerView` render step (before the default camera), no second camera controller.

## 2. Setting
- Settings row TRACK CAMERA, ON / OFF pill like the other rows, below TOP-DOWN VIEW; the panel grows one row.
- Stored as the LocalPlayer attribute `TrackCamera`, session-local like `TopDownView` and `ReduceEffects` (not saved).
  Unset = ON (default ON, placeholder).
