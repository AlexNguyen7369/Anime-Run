# Agent handoff

History: `current_progress.md`, `git log`.

## State (2026-11-03)
- Integration branch `feature/alex/anime-world`. `main` has only fork-ivs; merging needs an open PR and a fresh reviewer (owner approved it after c3).
- Built and landed: all 10 biome tracks, team of 3 + stamina + team bonus, workshop stat boost, all 30 character models, first impression fi1-fi5.
- c3 UI work is on `orch/first-impression/c3ui`, not merged. Last complete run `[UITEST] END pass=40 fail=0` (40 scenarios, 3238 checks). A confirmation run stopped after 18 of 40 with no failures, paused by the owner for track enemies.
- Last server run on 8e30668: `[CARTEST] END pass=49 fail=1` (`vehicle-effects-drive-intermittent`, BUGS; passes 6 of 6 alone).
- Track enemies (owner, before c3): `orch/core/enemy`, `../AnimeRun-orch/enemy`, and a peer session's uncommitted work in the main checkout.

## Next
1. Finish track enemies. 2. Merge c3ui, final full server + UI harness, rules audit. 3. PR to main with a fresh reviewer. 4. Design doc 4.25: Tracks 1-5 load first, the rest by proximity (spec + code, after the PR).

## Open
- Owner review of c3ui check changes: HudPair lists (844x390 stacks, Upgrade rect without Speed, tablet_4x3 out of Desktop), `text_clear_of_buttons` (UIScale on text, full-screen exemption), Market Detail left out on phones, rolls behind the loading screen not judged.
- The IVS HUD spec says persistent entries stay drawn while a panel is open and the pair never stacks (2026-10-29). Anime Run has no HUD spec and keeps stacking.
- Phone results come from the solver's model, never a real phone-size view. A second real account has not been tested. Client GPU and low-end performance not measured.
- Not seen in a live run: ninja run (`RunStyle = "NinjaRun"`, all Leaf characters, design doc 4.23). Animation clipping of capes, tails and panels untested. Orbit, ring and box effect radii do not follow RunnerFactory.SCALE (cosmetic).
- Character load check after the marks pass: Play, `CharacterModels` Ready with 30 folders and 6 meshes each.
- Stamina placeholders: Stamina bottle and stat/tree icons reuse Speed art. A Common cannot finish Track 1 (owner kept this balance).
- Known shortcuts: terrain edge `shortcut:` in TerrainBuilder; a duel counts as the first run for the Daily hold; `HudChrome` Level bar hidden, not deleted (positions Items / Upgrade).
- Owner-accepted art: weak spots db_green arm bands, db_tyrant head corners, similar jk_ uniforms; departures sea_cook, sea_navigator, leaf_avenger, mha_blast, jk_king covered or no cigarette; sea_swords red sash; leaf_crow dark eyes.
- Owner may restore their Studio save version 11-01 20:01 (PlayerStats_v2, Player_232682736; Money 3.68b, 10 cars, BestTrack 9), reset by pre-u1 code.
- Unconfirmed: a $0 first run may repeat the new-player flow on rejoin. LB_RarestCar_v1 may have been overwritten then restored by the real session.
- OWNER MUST SAVE THE PLACE after Edit-mode deletions (IVS leftovers, default SpawnLocation). IVS textures are still uploaded on Roblox (owner may delete). Track 5 live floats: LavaCrack patch 6.5, debris 2.2.
- Owner decides on: `docs/OWNER_QUESTIONS.md`.

## Studio and Rojo
- Anime Run: placeId 102957063656302, universe 10773557968. Name the Anime Run studio id on every MCP call, never Racer RNG; the id changes per launch (last c2a3f28c).
- Rojo `34873` serves the main checkout (IVS keeps 34872). After a Rojo restart the owner clicks Connect. Sync can land after Play starts: check Source in Edit before Play. Play must restart to pick up synced code.
- One test run at a time; Studio is shared with IVS work. Restart Play only 120 s after Stop, or the save lock gives DataFailed and a blank session.
- Harness: attributes on ReplicatedStorage. `CarTestOnly` filters scenarios; the run starts when `CarTestRun` changes to true. UI harness: `UiTestRun`. Poll in <=112 s `execute_luau` calls (longer waits time out). First scenario `runner` takes about 18 min. Results: `[CARTEST] END`, `[UITEST] END`.
- Team Create can stop Play on a Wi-Fi drop (disconnect 276); a stopped run with no result means rerun, not failure.
- Saves: test runs bank money into the owner's Studio save. `TestSaveKey` attribute (Studio only, PlayerData.KeyFor) gives a fresh save; clear it in Edit after. `LeaderboardService.Write` skips test saves. Owner's save last checked: $67,449,565, best track 9, Team intact.
- Screenshots in Play: on Client set `settings().Rendering.QualityLevel = Level21`, anchor the character at the shot, RenderStep "Shot" forcing Scriptable camera + ScreenGuis off, `screen_capture` with no camera args.
- Quirks: `AlwaysOnTop` billboards do not draw (stamina bar, plaza labels). `Workspace.StreamingTargetRadius` / `MinRadius` are not valid members in this Studio. `RacerRebirth.luau` is generated (spec in `~/Documents/RobloxGames/ui`) and hand-edited: regenerating may undo the speed tile. The place's saved StarterGui RacerRebirth has stale text.

## Art pipeline
- Build: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/blender/build_avatar.py -- <id>...` (headless). Spec: CHARACTER_GACHA_SPEC. Uploads go under the owner's account; delete a row in `tools/blender/avatar_assets.json` to re-upload; earlier uploads stay orphaned on the account.
- Plaza: `tools/blender/plaza/build_plaza.py -- --export`, then `upload_plaza.py` (only changed hashes re-upload). `build/` and `assets/plaza_draft/` are generated.
- `assets/characters_avatar/*/atlas.svg` is rewritten by `tools/blender/paint/atlas.py`.
- Reference images stay outside the repo: `../AnimeRun-orch/art-backup/anime_refs` (look-only, `owner_target.png`); older model passes in `art-backup/`. Anima setup for the owner to run: `art-backup/anima/`.
- `git push` of many binaries failed once with "inflate returned -5"; a retry later worked.
