# New boss checklist

`<id>` is the short boss id (`mage`, `king`), `<Id>` its capitalised form (`Mage`, `King`), `<Title>` the in-game title. The Elf Mage (`boss_mage`) is the reference implementation for every row.

## Naming

| Thing | Name |
|---|---|
| Boss model id | `boss_<id>` |
| Sidekick id | `side_<id>` |
| Pose data | `src/shared/Boss<Id>Poses.luau` |
| Art ids | `src/shared/Boss<Id>Art.luau` |
| UI art script | `tools/blender/portrait/draw_<id>_ui.py` |
| Art upload script | `tools/blender/portrait/upload_<id>_art.py` |
| Art ledger | `tools/blender/<id>_art_assets.json` |
| Chest | `relic_chest_<id>` in `src/shared/RelicConfig.luau` |
| UI art folder | `assets/ui/boss_<id>/`, chest at `assets/ui/chest_<id>.png` |
| Admin command | `/boss <id>` (`BossEventService` command parse) |
| Server scenarios | `boss_<id>_event`, `boss_<id>_anim`, `boss_<id>_arena` |
| UI scenarios | `ui_boss_<id>`, `ui_boss_<id>_dodge`, `ui_boss_<id>_vfx`, `ui_boss_<id>_rewards`, plus one per new notice or status |
| Evidence | `docs/char_evidence/boss_<id>.md`, `docs/char_evidence/side_<id>.md` |

## Files per step

Step 2, research: `docs/char_evidence/boss_<id>.md`, `side_<id>.md`.

Step 3, rules: `docs/GAME_DESIGN_REQUIREMENTS.md` (4.37 bullet group, 4.38 if the chest changes, change log), `docs/BOSS_EVENT_SPEC.md`, `docs/RELIC_SPEC.md`, `docs/SIDEKICK_SPEC.md`, `docs/ORCHESTRATOR_GOALS.md`, `docs/BOARD.md`, `docs/OWNER_QUESTIONS.md`.

Step 4, models: `tools/blender/build_boss_<id>.py`, `tools/blender/avatar_chars/boss_<id>.json`, `tools/blender/paint/char_boss_<id>.py`, `tools/blender/sidekicks/side_<id>.py` + `side_<id>.views.json` + `side_<id>.attack.json`; renders in `assets/characters_avatar/boss_<id>/review/` (`front`, `back`, `side`, `three_quarter`, `lineup`), `assets/characters_avatar/side_<id>/`.

Step 5, arena: `src/client/BossColosseum.luau` `Dressing` option (reuse) or `tools/blender/arena/build_<arena>.py` (new); `src/shared/BossArenaConfig.luau` `For[boss_<id>]`.

Step 6, key frames: `tools/blender/boss_<id>_keyframes.py`, `assets/characters_avatar/boss_<id>/keyframes/keys.json`, `<move>_slices.png` per move, `all_moves_overview.png`.

Step 7, art: `tools/blender/portrait/draw_<id>_ui.py` (dodge icon, portrait, head, status icons, Bosses card), `tools/blender/portrait/draw_relics.py` (`<id>` section: 5 Relics + chest), `tools/blender/portrait/draw_boss_cards.py`; outputs under `assets/ui/boss_<id>/`, `assets/ui/chest_<id>.png`, `assets/ui/relic_*.png`; contact sheet.

Step 8, bake and upload: `tools/blender/bake_boss_<id>.py` -> `src/shared/Boss<Id>Poses.luau`; `tools/blender/portrait/upload_<id>_art.py` -> `src/shared/Boss<Id>Art.luau`, ledger `tools/blender/<id>_art_assets.json`; `tools/blender/upload_avatar.py` -> `tools/blender/avatar_assets.json`.

Step 9, server (tests first, test-writer only):
- `src/server/CarTest/Boss<Id>Tests.luau` (sections: numbers, camera, poses, approved keys, schedule, dodge timeline, catalog, one per new status), `src/server/CarTest/Scenarios.luau` registrations.
- `src/shared/BossCatalog.luau`: row `boss_<id>` (Moves with Cost per move, Statuses, `DodgeIcon = Boss<Id>Art.<Icon>`, `Poses = "Boss<Id>Poses"`, texts, `Camera`, `WaitCamera`), `Order` += `boss_<id>`.
- `src/server/BossEventService.luau`: new status hooks (`Hooks.DamageMulti` for a boss-side cut), published attributes, Cost 0 moves skipped by `chargeMoves`, dodge refused for moves without a bar, `/boss <id>`.
- `src/shared/RelicConfig.luau`: 6 Relics, `relic_chest_<id>` with `SidekickId = "side_<id>"`, `SidekickChance` 0.00001 (0.0001 Adapted); `src/server/RelicService.luau` reads the chest's fields, no per-boss constant.
- `src/shared/SidekickConfig.luau` `BossDrops` += `side_<id>`; `src/server/SidekickService.luau` `GrantDrop` accepts any id in `BossDrops`; `src/shared/SidekickAttacks.luau`, `SidekickArt.luau`.
- Step 9, client (tests first): `src/client/UiTest/UiBoss<Id>.luau`, `UiScenarios.luau`, `UiSpec.luau` (panels, buttons, `When` lines).
- `src/client/BossArenaView.client.luau` branch; `src/client/Boss<Id>.luau` (from `BossMage.luau`); `src/client/Boss<Id>Vfx.luau` (from `BossMageVfx.luau`, pooled parts, REDUCED EFFECTS counts from the spec); `src/client/BossEventUi.client.luau` (notices, `DETAIL_ROWS` chest prefix, status icons); `src/client/BossDodgeUi.client.luau` unchanged when `DodgeIcon` carries the icon.
- Existing scenarios that must stay green: `boss_event`, `boss_arena`, `boss_anim`, `boss_mage_event`, `relics`, `sidekicks`, `ui_boss_cards`, `ui_boss_dodge`, `ui_boss_mage`.

Step 10: `handoff.md`, `docs/BOARD.md`, `current_progress.md` through the `progress-tracker` skill.

## Review-page template

One claude.ai artifact per gate. Title "<Title>: <gate> review, <date>". Every image carries a caption; every proposed value is written `**proposed**`.

1. Models: front, back, side, three-quarter, lineup next to a runner; tri count per model; the Sidekick's views.
2. Arena: 4 views plus the runner's camera view; part count against the shell's cap.
3. Per-move slices: one block per animation, in cycle order; the labelled key frames in a strip; hit time, window length and cost under the strip; the Sidekick attack last.
4. Art sheet: dodge icon, portrait, head, status icons, 5 Relics and the chest with rarity labels, Bosses card; each at the size the UI shows it.
5. Decisions for the owner (numbered): one line per open choice, the proposed answer first, what changes if the owner picks otherwise. Close with "Approve as shown, or list the numbers to change."

## Evidence-file template (`docs/char_evidence/boss_<id>.md`)

```
# boss_<id> evidence
Id `boss_<id>`, display name <Title> (owner <date>). Based on: <real name>, <anime> (<form, arc or film>).
Usage: public Roblox experience (boss event, design doc 4.37 "<Nth> boss", docs/BOSS_EVENT_SPEC.md "<Title>"). Rig: R15 block body, bespoke named parts.
Licensing: Roblox License Manager <names / does not name> a licence for <franchise> (checked <date>). <Licensed / Unlicensed> reference; upload needs the owner's word.

## Evidence table
| Attribute | Value | Status (supported / inferred / unknown) | Source |

## Sources
- one line per site read; one line listing sites that refused the client (never disguised)
Source quality: what no source gave (palette, sheet), and what the model therefore infers.

## Owner reference images (look-only, never ship)
Where they are saved, numbered, one phrase each.

## Contradictions and choices
- <source A> against <source B>: chosen <X> because <reason> (owner <date> when the owner ruled).
```
