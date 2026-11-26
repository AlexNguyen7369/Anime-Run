# World 2 track effects in Studio (2026-11-26, agent-2)

For the owner's review. `TrackFxConfig.LIVE` was set to true only in the Studio test session, by editing the module's source in
Edit; it was restored to false afterwards and never committed. World 2 place, Rojo on aadb7cf8 (src as 12befdf8). Studio
quality level 21. Test keys set for the run and cleared.

| Track | Live on the track (near the camera) | Over a road | Picture |
|---|---|---|---|
| 2 DemonCastle | 10 emitters (RubbleSmoke 3, Chimney 4, Embers 3), 2 drakes | 0 of 10 | T2_run_camera, T2_smoke |
| 4 HauntedTunnel | 7 GroundHaze, the eel (15 segments, ~240 studs up) | **7 of 7** | T4_run_camera, T4_eel |
| 5 KaijuBase | 0 until the track's Start was streamed in, then 8 (RubbleSmoke 4, SmokeColumn 3, Steam 1) | 0 of 8 | T5_no_effects_start_not_streamed, T5_rubble_smoke |
| 7 AntIsland | 5 (RubbleSmoke 1, Chimney 4), 1 drake (~350 studs up) | 0 of 5 | T7_thatch |
| 10 HellGate | 1 GroundHaze | 0 of 1 | T10_run_camera |

"Over a road": a vertical ray from the emitter's centre or one of 4 points at its spread radius hits a road part.

## Flags
1. **Broken: effects do not build on most of a long track.** `TrackFx.setup` returns until the track's `Start` part exists
   on the client. With StreamingEnabled, `Start` is out of range away from the track's beginning (Track 5's was 1,989
   studs from the camera), so setup retries forever and the track shows nothing. Streaming `Start` in made Track 5's 8
   emitters appear at once. Proposed fix (layout-proof): compute the origin on the client from the chain
   (`TrackBuilder.CHAIN_ORIGIN`, `Layout`, `EndCFrame`, as Main.server does), or have the server set the origin as an
   attribute on the track model, which always replicates.
2. **Haze over the road on Track 4.** All 7 GroundHaze emitters (Cedar and Portal anchors, 35-stud spread) reach over the
   road. Not seen as a problem in the night picture (the haze is faint), but it is ground mist on the racing line.
3. **Eel reads as beads.** Up close the 15 translucent segments read as separate rings rather than one body (T4_eel).
4. **Drake paths are wide.** Track 2's drakes were seen ~1,000+ studs from Track 2's road (one at 950, 373, -858), over
   other tracks' ground. Layout-dependent: judge again after the re-lay.
5. Not measured: frame time. The Studio window is throttled to about 15 fps (66.7 ms a frame) with effects on and with
   REDUCED EFFECTS on alike, so the effects' cost is below what this window shows. Needs a phone or an unthrottled
   client. Track 10's sky doors and arms (prop motion) were not measured: no SkyDoor within 300 studs of the camera.
