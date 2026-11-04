# Current Progress

## Completed
1. 2026-10-28 — Alex Nguyen — Wrote the Anime Run design doc and specs (team of 3, stamina, character gacha, NPC rivals, research notes).
2. 2026-10-28 — Alex Nguyen — Added owner decisions to the specs: Stamina stat point, Stamina potions, Sprinter/Balanced/Marathoner categories, Series and preset team bonus.
3. 2026-10-28 — Alex Nguyen — Switched the cast to tweaked-name real anime characters (6 series, preset trios = famous teams, parody NPC rivals) with IP safeguards.
4. 2026-10-28 — Alex Nguyen — Set up the orchestrator (goal fork-ivs) and copied the Idle Vehicle Simulator code into AnimeRun (f1).
5. 2026-10-28 — Alex Nguyen — Renamed cars to characters and added the 33 placeholder characters with neutral ids (f2); harness data/spawn_area green, audit PASS.
6. 2026-10-28 — Alex Nguyen — Full harness green in the Anime Run private experience (f3): `[CARTEST] END pass=49 fail=0`, audit PASS, IVS leftover visuals removed from the place.
7. 2026-10-28 — Alex Nguyen — Merged goal fork-ivs (f1-f3) into main via PR #1 after a fresh merge review approved it; goal closed.
8. 2026-10-30 — Alex Nguyen — Rescaled the Speed stat x1e15/3e5 (design doc 4.11, save and Speed leaderboard stores v2) and wrote the owner track-length and stamina updates into the docs; harness fixes re-run green.
9. 2026-10-30 — Alex Nguyen — Landed anime-world w1: placeholder runner rig replaces the car body, car physics scrapped, log-scaled Speed board; full harness `[CARTEST] END pass=45 fail=0`, audit PASS.
10. 2026-10-30 — Alex Nguyen — Landed anime-world w2: anime town plaza hub at the world origin, 7 Dojo plots and the Dojo squad rule, track chain moved to (-118, TRACK_LIFT, 80); full harness `[CARTEST] END pass=47 fail=0`.
11. 2026-10-30 — Alex Nguyen — Committed anime-world w3 work in progress on orch/anime-world/w3 (spiral layouts for Tracks 1-10, TARGET_LENGTH check, wide bends on Tracks 7-10, faster overlap tests), not yet verified in Studio; added the dashboard tool and /dashboard command.
12. 2026-10-30 — Alex Nguyen — Landed anime-world w3 (spiral track layouts 1-10 at target lengths, wide bends on Tracks 7-10) and w4 (anime biome themes 1-10, IVS mesh assets removed); environment pass=450 fail=0.
13. 2026-10-30 — Alex Nguyen — Landed biomes b0: BIOME_ENVIRONMENT_SPEC approved with owner rulings (free Creator Store assets as Lane D, biomes built one track at a time); core c1 paused for biomes.
14. 2026-10-30 — Alex Nguyen — Landed biomes b1: environment framework (code-generated terrain and water, per-zone client atmosphere and audio, reviewed-only asset registry); its 4 scenarios pass in Studio.
15. 2026-10-31 — Alex Nguyen — Landed biomes b2 Track 1 Leafwind Village (owner approved from screenshots) and its rules-auditor close-up IP sign-off.
16. 2026-10-31 — Alex Nguyen — Landed biomes b2 Track 2 Tournament Wasteland (mesa, craters, arid atmosphere, auditor-signed ledger).
17. 2026-10-31 — Alex Nguyen — Landed biomes b2 Track 3 Pirate Harbor Isle (owner approved visuals) with framework fixes (natural-height pads under pinned landmarks and houses, prop slide/delete at the zone midline, 2-hero floor), Track 2 sand road and Rock colour 8A6E52; scenarios pass=3 fail=0.
18. 2026-10-31 — Alex Nguyen — Landed biomes Tracks 4 (Wisteria Night Mountain) and 6 (Hero Academy City) plus framework fixes for floating houses and pads, with a reusable offline biome harness.
19. 2026-10-31 — Alex Nguyen — Added the owner's track camera setting (camera yaw follows the runner while racing, TRACK CAMERA toggle).
20. 2026-10-31 — Alex Nguyen — Rebuilt Track 5 as Burning Cursed City and Track 8 as Skypeia after the owner's redesign, both auditor-signed with Studio checks passing.
21. 2026-11-01 — Alex Nguyen — Landed Track 9 Spirit Realm Desert and Track 7 Shibuyo Underground (wide subway tunnel framework, fight scene), Studio checks passing.
22. 2026-11-01 — Alex Nguyen — Landed Track 10 Green Alien Planet and the Track 4 twilight neon update without scenario runs (owner test pause); all 10 biomes landed.
23. 2026-11-01 — Alex Nguyen — Wrote the owner's urgent rulings into the design doc (fixed character speed, rebirth, info-only sensei, leaderboards removed, biome popup, high-speed loading).
24. 2026-11-01 — Alex Nguyen — Landed u3: biome meshes, textures and skies preload for the current and next track, with stream-ahead at high speed (no Studio check yet).
25. 2026-11-01 — Alex Nguyen — Hero landmarks now get their far-view SLIM detail ahead of time from a Rojo-built template; recorded the owner's ruling that workshop idle gain gives Money.
26. 2026-11-01 — Alex Nguyen — Landed u2: removed the plaza leaderboards, added the biome welcome popup and made the biome sky switch fast at high speed (no Studio check yet).
27. 2026-11-01 — Alex Nguyen — Landed u1 (fixed cruise per rarity and category, Speed stat removed, rebirth luck/XP/stat point, info-only sensei, workshop pays Money) and checked the biome welcome popup in Studio, fixing a sky crash and moving the popup under AUTO RACE.
28. 2026-11-01 — Alex Nguyen — Raised Common / Uncommon / Rare cruise to 24 / 33 / 48 and recorded the owner's rule that exhaustion pays a per-distance share of the current track's cash (Track 1 length kept).
29. 2026-11-01 — Alex Nguyen — Recorded the owner's rulings (Speed Doubler passes removed, Best Roll pedestal kept, upgrade tree Speed branch gives +% cruise) and pushed feature/alex/anime-world with all urgent fixes.
30. 2026-11-01 — Alex Nguyen — Landed u4: one aura and one trail per team slot with slot-picker UI, Speed Doubler passes removed, Best Roll pedestal fed again, and the upgrade tree Speed branch adding cruise %, checked in Studio.
31. 2026-11-01 — Alex Nguyen — Added the admin-only, session-only /kami test runner at 800 studs/s (equal to MAX_CRUISE) and removed the HUD speedometer and cruise read-out; rojo studio worktree moved to the commit.
32. 2026-11-01 — Alex Nguyen — Removed player levels and XP so rebirth now needs Money ($100K, x10 each), and fixed the biome showing the neighbouring track at high speed by taking it from the server's RunTrack while racing (no Studio check yet).
33. 2026-11-02 — Alex Nguyen — Brought back sensei checkpoints (tracks lock until the one before is beaten, loss restarts at the checkpoint), added a bonus with a placeholder popup for tracks won past the checkpoint in one run, and made the Tracks panel more detailed with accurate biome previews (no Studio check yet).
34. 2026-11-02 — Alex Nguyen — Implemented stamina and the team of 3 (Backpack slot picker, per-run drain with swaps, exhaustion share and cash-out, run bank restored, vertical blue stamina bar beside the runner, Commons ~13.5 s to Secrets 30 s), fixed a track-preview crash, and smoke-checked it in Studio.
35. 2026-11-02 — Alex Nguyen — Replaced the retired Level bar with a team row of 3 circle portraits (slot 1-3 left to right, current runner enlarged with a gold ring, exhausted runners greyed out), checked in Studio and synced to the Rojo studio worktree.
36. 2026-11-03 — Alex Nguyen — Landed c2 and c4: Stamina stat point, upgrade tree Stamina branch, Stamina potions and Series / preset team bonus; head-only team row with category info card and animated runner marker; animated stamina bar; workshop now boosts one chosen stat by the Dojo squad's rarity (passive gain, offline credit and the Workshop stat point retired); run cruise and stamina fixed at run start (audit PASS, Studio smoke OK).
37. 2026-11-03 — Alex Nguyen — Landed UI animations across the board (design doc 4.20): panels scale in with a staggered list, every button gets hover / press feedback, tab markers tween, toasts and popups slide and fade, claimable badges pulse, all respecting Reduced Motion (audit PASS; panel close motion pending a harness change).
38. 2026-11-03 — Alex Nguyen — Drafted 30 launch-character models from a shared headless Blender chibi base with an art reference sheet and contact sheet (rules audit PASS; push to origin failing, merge local).
39. 2026-11-03 — Alex Nguyen — Replaced the chibi drafts with 30 Roblox-avatar character models (inked outlines, cel shading, close to the source designs), uploaded and drawn in game, added the new-player starter choice popup and made the 3 event characters non-rollable Index tiles.
40. 2026-11-03 — Alex Nguyen — Added the owner's rebirth speed reward (+5% cruise per level, placeholder) with a speed tile on the Rebirth panel, and fixed the stamina bar trail and team row info card, checked in Studio on desktop.
41. 2026-11-03 — Alex Nguyen — Rebuilt the team row after the owner's reference image (real character heads in dark circles, curved stamina arc, seconds left, per-frame easing, fixed slots), checked in Studio on desktop.
42. 2026-11-03 — Alex Nguyen — Rebuilt Index and Backpack Characters around one rarity card with Backpack sort and search, fixed Index cards showing placeholder rigs, and gave the catch-all Common a numerical drop chance (Chance 1, roll results unchanged), checked in Studio on desktop; harness not run.
43. 2026-11-03 — Alex Nguyen — Added the ninja run for Narito and Karate Kid (per-character `RunStyle` pose plus client-side air streaks and foot dust, design doc 4.23), with angles still placeholders and not yet seen in a live run.

## What's next
**Check the ninja run in Studio with Narito on the team (Rojo must serve this checkout), then, once the owner approves, add `RunStyle = "NinjaRun"` to `leaf_copycat`, `leaf_medic`, `leaf_crow` and `leaf_avenger`.**

**Why this is next:** the owner made the rollout to all Leaf characters depend on approving this run, and the pose and effect values can only be tuned from a live look; the c3 compatibility check that gates the PR into main stays open after it.
