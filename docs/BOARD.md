# Board

## Doing
- roll-anim r4: upload 36 drawn portraits, show them in the roll, Index, Backpack, Team minibar and starter card
- c3 full compatibility check: paused by the owner 2026-11-04 until NPC additions land; then rerun full server + UI harness to fail=0, rules audit

## Next
- Make the remaining track villains rollable characters (owner)
- PR feature/alex/anime-world -> main with a fresh reviewer (owner approved)
- Design doc 4.25 track loading: Tracks 1-5 first, the rest by proximity

## Done
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
