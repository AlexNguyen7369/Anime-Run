# Board

## Doing
- u5 / c3 compatibility check: stopped on the owner's word 2026-11-04, not fully verified. UI `[UITEST] END pass=44 fail=0`; server `[CARTEST] END pass=49 fail=1` (`data`, fix 0fa4d06 not run), final server run skipped; audit FAIL, 5 of 6 addressed, not re-audited

- boss-event b5: event server

## Next
- hud-team t4: Team icon N3 uploaded and wired (2026-11-12); `ui_team`, `ui_hud` to run inside m12
- boss-mage-2: owner plays `/elfboss` (slow rhythm, golem 1,000 HP per player) and looks at the Team panel against draft A
- boss-mage m12: owner plays `/boss mage` and rules on `docs/OWNER_QUESTIONS.md` (2026-11-11), then full harness and PR into main
- boss-event: Sidekick portraits await owner's upload word; b6 onward: `docs/ORCHESTRATOR_GOALS.md`
- Design doc 4.25 track loading: Tracks 1-5 first, the rest by proximity

## Done
- 2026-11-12 boss-mage-2 follow-ups and hud-team (1b6c59a): golem HP per player, slower rhythm, golem every 6 s, per-boss late data with removal after the event (lazy-data merged), Bosses and Team buttons in a second column, Team panel A, world dim on every panel: `late_data` 90, `boss_mage_event` 291, `boss_mage_anim` 288, `ui_boss` 485, `ui_team` 42, `ui_panels` 1162 and the other targeted boss and HUD scenarios fail=0; rules audit PASS round 2
- 2026-11-12 boss-mage-2 g0-g6: Elf Mage spam strikes over 2 s, Stone Golem miniboss, 3-circle rhythm, Bosses cards draft B, her Relics and chest, drop list hidden (3c843fa): `boss_mage_event` 281, `boss_mage_anim` 286, `relics` 674, `ui_boss_mage_vfx` 55, `ui_boss_cards` 45, `ui_boss_golem` 16, `ui_boss` 468, `ui_boss_phase2` 91 and the other targeted boss scenarios fail=0; rules audit PASS
- 2026-11-11 boss-mage m0-m11: The Elf Mage second boss built and pushed on `feature/alex/boss-mage`; targeted boss scenarios green in Studio
- 2026-11-11 powerups p1 Track power-ups (752cf76): Speed x1.5 for 3 s and Stamina +5 s rings on the path, H2 badge, overfill seconds; `powerups` 22, `stamina` 33, `race` 52, `track_loading` 82 fail=0; rules audit PASS round 2; shots https://claude.ai/artifact/JEqy1rJqA7gCLrfZ4gdy1d
- 2026-11-11 dojo-removal r4 Spawn showpiece C in game (2c70abd): terrace, ring of radius 84, pedestal on the middle step; `world_layout`, `spawn_area`, `environment` pass=3 fail=0, `ui_billboards` pass; rules audit PASS round 2; Studio shots https://claude.ai/artifact/3Cw9qTVqJwKKpB71S84xDS
- 2026-11-10 hud-tech h1 gold frame tiles, L2 left block, Tile and Boss icons (c722398, 0a2ef57): ui_buttons 14/0, ui_hud 16/0, ui_layout 838/95 (pre-h1 reds), audit PASS; exhaustion eye 160 up, 13 deg (74eb084, boss_event not run)
- 2026-11-10 boss audit: flat boss image removed, running camera 75 / 26 / 6, boss mesh preload, BossScale 0.75; owner approved from Studio screenshots; no harness run (owner: targeted tests only); exhaustion-view arch post (OWNER_QUESTIONS item 4) open
- 2026-11-06 boss-polish Phase 2 scream 6 s and zoomed, dim and blood red tone, red title, ring radius 550, lower dais, bigger auras and trails, zoomed exhaustion view, 40-stud event camera: `[CARTEST]` 55 of 55, `[UITEST]` pass=50 fail=6 (reds in handoff, re-run stopped on the owner's word), audit PASS round 3
- 2026-11-06 boss-phase2 Phase 2, line run, chests, rewards popup, Relic art, phone load fixes: `[CARTEST] END pass=64 fail=1` (fixed, `scrap` pass after), `[UITEST] END pass=54 fail=2` (exempted, those pass alone); rules audit 3 rounds, findings fixed, not re-audited after the last
- 2026-11-05 boss-event b4 arena blockout: boss_arena 154, race 52, npc 117 checks pass; owner approved size; rules audit deferred to b11
- 2026-11-05 boss-event b3 Sidekicks (a661c4f): `[CARTEST]` pass=7 fail=0, sidekicks 212 checks; ui_layout 962 checks, ui_backpack_characters 24, ui_buttons 9, all pass; rules audit deferred to b11
- 2026-11-05 boss-event b2 Gems: `[CARTEST]` pass=6 fail=0; b1 models owner-approved (5ec6ae0), not uploaded
- 2026-11-04 sensei-cards s1 Tracks panel as road-screenshot cards: `ui_checkpoints` 369 fail=0; `checkpoint_selected_no_remote`, `checkpoint_locked_no_remote`, `checkpoint_select_track` 390 each fail=0; `checkpoint_close`, `checkpoint_switch_to_index` 19 each fail=0; `checkpoint_escape` MANUAL; rules audit PASS round 2
- 2026-11-04 market copies Up to 3 copies of each aura and trail (6184cc9): slot_items 21, vehicle_effects 130 fail=0; ui_market 100 checks fail=0 at 0, 1, 3 copies; real BUY and slot clicks on desktop; rules audit not run
- 2026-11-04 roll-anim r4 Drawn portraits and head art: 44 + 44 uploaded; `roll_anim`, `hud`, `gacha`, `scrap`, `catalog` pass=5 fail=0; `ui_layout` 962 checks fail=0; `ui_roll_anim`, `ui_roll_emphasized`, `ui_index`, `ui_backpack_characters`, `ui_starter_pick`, `ui_showdown`, `ui_defeated` fail=0; rules audit PASS
- 2026-11-04 declutter d3 In-house Market stall, 2 gate Legends (d553ec1): spawn_area, world_layout, dojo, workshop pass=4 fail=0, rules audit PASS
- 2026-11-04 villains v1 + v2 (ad8f9cb): 9 redesigned models, 8 rollable: catalog 21, gacha 318 fail=0, audit PASS
- 2026-11-04 roll-anim r1-r3 Roll animation (147f02d): `roll_anim`, `hud`, `gacha`, `scrap` pass=4 fail=0; `ui_roll_anim`, `ui_roll_emphasized`, `ui_toast`, `ui_hitboxes`, `ui_buttons`, `ui_hud`, `ui_reduced_motion` fail=0; `ui_layout` 962 checks fail=2 (Index EnemiesTab, BUGS); rules audit PASS
- 2026-11-04 c6, c7, s1, s2 (c91c1d4): enemy banners, Defeated Enemies page, Bleech series: ui_showdown 10, ui_defeated 5, catalog 20, gacha 278 all fail=0, audit PASS
- 2026-11-04 declutter d1, d2 Clear spawn plaza (68e565a): spawn_area, world_layout, dojo, workshop pass=4 fail=0, rules audit PASS
- 2026-11-04 c5 Screen-edge pointer for the track enemy (8691b0e): `ui_billboards` 21 checks fail=0, rules audit PASS
Older entries: `current_progress.md`.
- 2026-11-04 c5 Track enemies: biome-matched cast, always-visible indicator, 9 new models (8dea3f3): `npc` 117 checks fail=0, `ui_billboards` 12 checks fail=0, rules audit PASS
- 2026-11-03 first-impression fi5: plaza petals and audio, trunks, Index icon: pass=8 fail=0, rules audit findings fixed
- 2026-11-03 first-impression fi3, fi4, load optimization: fresh server 40-44 s (was 65-77), pass=4 fail=0, rules audit PASS round 4; gate burst, real fresh save, phone, Reduced Motion not seen
- 2026-11-03 first-impression fi1 + fi2 (5759bae): plaza and Dojo meshes, loading screen, Market and Race Start landmarks: world_layout, spawn_area, dojo, workshop pass=4 fail=0; rules audit PASS round 2
- 2026-11-03 trim t1: stale docs and unused assets removed
