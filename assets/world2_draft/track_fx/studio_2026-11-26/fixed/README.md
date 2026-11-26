# Track effects after the fixes (2026-11-26, Studio, LIVE forced in the test session only, restored)

- T5_effects_without_streamed_start.jpg: Track 5 with its `Start` part not streamed in: 8 emitters built (RubbleSmoke 4,
  SmokeColumn 3, Steam 1), none over a road. Before the fix: 0.
- Track 4: 6 GroundHaze built, 0 over a road (before: 7 of 7 over it; one now cannot clear and is not built).
- T4_eel_side_70_studs.jpg: the eel from its side at 70 studs, segments 40 long with a 10-stud tail wave: one body, no
  gaps. Taken with a test-session-only bypass of `TrackFxPlan.FitLoop` (restored), because on today's routes the eel's
  loop does not fit over Track 4's own ground and is not built. On the C layout it fits at 62%.
- Frame time: not measurable in this Studio window (throttled to about 15 fps, 66.7 ms with and without the effects).
