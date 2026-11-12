---
name: new-boss
description: 'Design and ship a new Anime Run boss end to end: clarifying questions, canon and market research, evidence file, rules first, models, arena, 10 key frames per boss move for owner approval, digital art, Relics, Sidekick, bake and uploads, server and client with tests red first, Studio verify, rules audit, PR. Use for /new-boss, "new boss", "add a boss", "third boss", "boss event for <character>".'
argument-hint: "<boss name> [anime]"
---

# New boss

Ten gated steps. A gate is the owner's written approval (or a green test run where stated). Never start the next step before its gate. Read `handoff.md`, `CLAUDE.md`, `.claude/orchestrator.md`, design doc 4.37 and `docs/BOSS_EVENT_SPEC.md` before step 1. `references/checklist.md` holds the file list, naming, scenario names and the review-page and evidence templates: open it at every step.

Name the boss once: `<id>` is the short model id (`boss_<id>`), `<Id>` its capitalised form (`Boss<Id>Poses`). Every boss ships with its own Sidekick `side_<id>`: the boss's chest rolls it at 0.001% (0.01% in an Adapted chest), separate from the Relic roll, never in the Gem summon pool (design doc 4.37, 4.38). A boss without a Sidekick is incomplete.

## Hard rules (every step)

- Real character and series names appear only under `docs/` (evidence file, design doc, specs). Ids, display names, asset names, textures, chat lines, badges and product names carry only the tweaked title (design doc section 5; `.claude/orchestrator.md` forbidden list).
- R15 block body: likeness comes from hair, face, paint and separate props. Never slim, taper or reshape the blocky body.
- UI shows the drawn portrait PNG, never the 3D model.
- Every upload script has a `main()` guard (`if __name__ == "__main__":`). Check it before any import or run. Nothing is uploaded to Roblox without the owner's explicit upload word for that batch (the 2026-11-05 incident uploaded 26 Decals).
- Test files (`src/server/CarTest/*`, `src/client/UiTest/*`) are written only by the test-writer agent (`roster.tests_write`), red first, before the code they test.
- Every number the owner has not fixed is written `**proposed**` in the docs and listed in `docs/OWNER_QUESTIONS.md` under a dated heading.
- One review page per gate (claude.ai artifact, like the Elf Mage's), with every render on it, each image labelled, and a numbered list of the decisions the owner must make. Template in the checklist.
- Studio is shared with IVS work: check no other session is using it, one run at a time, Rojo serving the task checkout.
- Rules audit (`auditor` in `.claude/orchestrator.md`, read-only) passes before any code is written and again before the PR.
- A fresh reviewer agent, not the builder, reviews the PR.
- `stylua src` and `selene src` on every touched `.luau` file; `rojo build` before Studio.
- Server decides every number; the client only displays.

## 1. Clarifying questions

Ask the owner with AskUserQuestion, in full sentences, one batch: title and `<id>`; source character, anime and version (form, arc, film); arena (reuse a shell such as `BossColosseum` with a dressing, or new); the move list with, for each move, the dodge type (Dodge bar, rhythm circles, none), stamina cost, window length and whether it is Vulnerable; boss size (characters tall); Phase 2 (yes or not designed); miniboss; Relic stat priority; Sidekick attack; what is out of scope. Record the answers as dated owner decisions in `handoff.md`.
Done: every answer written down, no open item left for a later guess.

## 2. Canon and market research

Run the `design-roblox-anime-character` skill for the source character. Web search the attacks, the look, and the licence (Roblox License Manager; name the result). Play or read 3 or more Roblox boss games for the fight feel; note what players praise and what they skip. Write `docs/char_evidence/boss_<id>.md` (and `side_<id>.md`) with the evidence table (supported / inferred / unknown, source per row), sources that refused the client (never disguise it), owner reference images (look-only, never shipped), contradictions and the choice made, and the licence line. Template in the checklist.
Done: evidence file written; licence line present; every "inferred" row names its reference.

## 3. Rules first

Write, before any code or asset: design doc 4.37 "<Nth> boss" bullet group (look, arena, idle, moves with costs and dodge types, Fortified-style statuses, defaults, texts, key-frame rule, upload line) and a dated change-log line; `docs/BOSS_EVENT_SPEC.md` "## <Title>" section (move table, cycle, dodge, defaults, key counts, texts, reduced effects, camera, load, admin command, out of scope); `docs/RELIC_SPEC.md` "<Title>'s drops" (6 Relics, chest name, table); `docs/SIDEKICK_SPEC.md` row `side_<id>`; `docs/ORCHESTRATOR_GOALS.md` goal with deliverables and gates; `docs/BOARD.md`; `docs/OWNER_QUESTIONS.md` entry for every **proposed** value. Specs never contradict the design doc; on a conflict stop and ask. Run the rules audit on the docs diff.
Done: audit PASS; owner has read the rules back.

## 4. Models

Build `boss_<id>` in the avatar pipeline (`tools/blender/build_boss_<id>.py`, `tools/blender/avatar_chars/boss_<id>.json`, `tools/blender/paint/char_boss_<id>.py`), weapons and props as separate named parts, 3,000 tris or fewer (report the count). Build companions (miniboss, pets) the same way and `side_<id>` in `tools/blender/sidekicks/side_<id>.py` with `.views.json`. Render front, back, side, three-quarter and a lineup next to a runner into `assets/characters_avatar/boss_<id>/review/`. No upload.
Gate: review page "models"; owner approves each model. The block body rule applies.

## 5. Arena

Reuse a shell when the owner chose one: add a `Dressing` option to it (motif, colours, props; count parts against the shell's cap and report it). Otherwise `tools/blender/arena/build_<arena>.py` from `build_arena.py`. Render 4 views and one view from the runner's camera.
Gate: review page "arena"; owner approves the look. Lanes, ring and speed cap stay as the spec says.

## 6. Key frames

For every boss animation (idle, each move with its dodge and strike window counted inside its 10, statuses, entrance if new) write 10 labelled key frames (owner 2026-11-12, design doc 4.37); each Sidekick attack and the dodge dash if new get 3 to 5 in `tools/blender/boss_<id>_keyframes.py` (from `boss_mage_keyframes.py`), export `assets/characters_avatar/boss_<id>/keyframes/keys.json` and `<move>_slices.png` per move. Work one move at a time; put each move's slices on the review page with the hit time marked.
Gate: owner approves every move's keys before any in-between is drawn (design doc 4.37). Changing an approved key means a new gate.

## 7. Digital art

Draw with `tools/blender/portrait/draw_<id>_ui.py` and `draw_relics.py <id>`: Dodge bar icon, boss portrait and head, Sidekick portraits and heads, status icons, 5 Relic PNGs (Secret is universal) and the chest, the Bosses card. Assemble one contact sheet. Portrait art is what the UI shows.
Gate: review page "art sheet"; owner approves the sheet.

## 8. In-betweens, bake, uploads

Add in-betweens between the approved keys only; `tools/blender/bake_boss_<id>.py` writes `src/late/Boss<Id>Poses.luau (ServerStorage.LateData, delivered on event publish; design doc 7)` (report its size against `BossMagePoses`). Check every upload script's `main()` guard, then ask the owner for the upload word for this batch; run `tools/blender/portrait/upload_<id>_art.py` and `upload_avatar.py`; ledgers `tools/blender/avatar_assets.json`, `tools/blender/<id>_art_assets.json`; ids land in `src/shared/Boss<Id>Art.luau`.
Done: approved keys unchanged (diff `keys.json`); every uploaded id in a ledger with its hash.

## 9. Server, client, verify, PR

Order: test-writer writes `src/server/CarTest/Boss<Id>Tests.luau` and registers `boss_<id>_event`, `boss_<id>_anim`, `boss_<id>_arena` in `Scenarios.luau`; run them red. Then the server (catalog row, statuses, chest with `SidekickId`, `/boss <id>`); run green. Test-writer writes `src/client/UiTest/UiBoss<Id>.luau` (`ui_boss_<id>*`) and registers in `UiScenarios.luau` and `UiSpec.luau`; red. Then the client (arena branch, `Boss<Id>.luau`, `Boss<Id>Vfx.luau`, notices, cards); green. Existing scenarios (`boss_event`, `boss_mage_event`, `relics`, `sidekicks`, `ui_boss_cards`, `ui_boss_dodge`) stay green. Owner plays `/boss <id>` in Studio and rules on the open questions. Rules audit on the full diff. Open the PR with `merge.open` from `.claude/orchestrator.md`; a fresh reviewer reviews it; fix, then merge with the owner's word.
Done: harness `[CARTEST] END fail=0` and `[UITEST] END fail=0` on the integration branch; audit PASS; PR merged.

## 10. Bookkeeping

After every commit or push: `handoff.md` (decisions, Studio results, next step), `docs/BOARD.md` (Doing / Next / Done), then the `progress-tracker` skill for `current_progress.md`. Record what the owner approved, with the date and the review-page link.
