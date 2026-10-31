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

## What's next
**Biomes b1: environment framework (code-generated terrain and water, per-zone client atmosphere, ambient audio, asset registry) on orch/biomes/b1.**

**Why this is next:** every b2 biome (Track 1 first, then 2-10) is built on this framework, and the owner's per-track screenshots depend on it.
