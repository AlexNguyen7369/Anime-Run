# Orchestrator goals

Owner's end goals for `/orchestrate` (config `.claude/orchestrator.md`). Only the owner adds, changes or closes a goal.
Game rules stay in `docs/GAME_DESIGN_REQUIREMENTS.md` and the specs.

## Global
- Definition of done (every deliverable): its harness scenarios green, the full harness `[CARTEST] END fail=0`, rules
  audit PASS (owner 2026-10-28).
- Owner 2026-10-30 (replaces the per-deliverable full harness): during development each deliverable needs only its
  own targeted scenarios green plus `stylua` / `selene`; tests are a development tool, not a gate that delays work.
  One full compatibility check (full harness `[CARTEST] END fail=0` + rules audit) runs once all features are built.

## anime-world: World redesign, every car model scrapped (replaces anime-maps)
Status: active (owner 2026-10-28)
Owner-confirmed: 2026-10-28 (scope); deliverables w1-w5 confirmed by owner 2026-10-28
Branch: feature/alex/anime-world (created on the first task)
Spec: docs/WORLD_REDESIGN_SPEC.md, docs/TRACKS_AND_BIOMES_SPEC.md
Deliverables:
- w1 | Placeholder anime runner on the rail replaces the car body; car physics and car-physics scenarios retired | `runner` + `scrap` scenarios green; full harness `[CARTEST] END fail=0`
- w2 | World layout + anime town plaza hub + 7 Dojo plots (Dojo squad rule) | `world_layout` + `dojo` + `spawn_area` green
- w3 | Track tests for Tracks 1-10, then layouts 1-10 at 984 x F x 1.25^(n-1) (F = 3) along the spiral, each researched from its anime (spec References) | every track test + chain green
- w4 | Biome themes 1-10, researched from public info on each anime and matched closely within section 5 | `environment` + clearance green; IP check PASS
- w5 | Rules audit PASS on the integration branch | `RULES AUDIT: PASS`
Out of scope: final character art, Robux products, merging into `main`.

## core: Core Anime Run gameplay from the design docs
Status: active, priority 2 (after `biomes`, owner 2026-10-30)
Owner-confirmed: 2026-10-30 ("develop core features explained in design docs")
Branch: feature/alex/anime-world (same integration branch)
Spec: docs/TEAM_AND_STAMINA_SPEC.md, docs/CHARACTER_GACHA_SPEC.md, docs/NPC_RIVAL_SPEC.md
Deliverables:
- c1 | Team of 3 + stamina + swap + run end by exhaustion + HUD (TEAM_AND_STAMINA_SPEC Team, Stamina, Swap, Run end, HUD) | its spec tests green
- c2 | Runner categories, Stamina stat point, Stamina potion, team bonus (series / preset) (TEAM_AND_STAMINA_SPEC, CHARACTER_GACHA_SPEC Series and preset teams) | its spec tests green
- c4 | Workshop stat boost (owner 2026-11-03, design doc 4.19, WORLD_REDESIGN_SPEC 5): chosen stat, squad rarity %, level scale, passive gain removed | stylua / selene clean, lune check of Workshop.Boost, Studio smoke when a Studio is connected (tests paused, owner 2026-11-01)
- c5 | Track enemies and indicator (owner 2026-11-03, design doc 4.26, NPC_RIVAL_SPEC): names and indicator first, then 9 new enemy models | stylua / selene clean, `npc` + `ui_billboards` checks green, Studio screenshot of the indicator, models in game
- c6 | Enemy showdown banners (owner 2026-11-04, design doc 4.28) | `ui_showdown` green, screenshot of both banners
- c7 | Defeated Enemies page in the Index (owner 2026-11-04, design doc 4.29) | `ui_defeated` green, screenshot
- c3 | Full compatibility check: owner 2026-10-30, the owner runs it manually when they approve; not an orchestrator task; (owner 2026-11-04) includes animated runs with aura and trails: no frame glitches or mesh bugs (`ui_run_visual`, captures reviewed)
Out of scope: final character art, Robux products, merging into `main`.

## biomes: Full anime biome worlds for all 10 tracks (priority 1)
Status: active, priority 1 (owner 2026-10-30)
Owner-confirmed: 2026-10-30 ("re-engineer the full biomes and environments of all tracks ... end to end")
Branch: feature/alex/anime-world
Spec: docs/BIOME_ENVIRONMENT_SPEC.md (to be written first), docs/TRACKS_AND_BIOMES_SPEC.md
Target: each track is a full world, not props along a road: shaped Terrain + water, custom in-house 3D meshes (Blender /
Studio generation) and free Creator Store assets (owner 2026-10-30), per-zone client atmosphere (sky, lighting, fog, colour grade, particles), ambient audio. Inspiration
from public anime Roblox games (general style only, nothing copied); section 5 safeguards hold.
Deliverables:
- b0 | BIOME_ENVIRONMENT_SPEC written (layers, budgets, pipeline, per-biome art direction) | owner reads it (DONE 2026-10-30, approved, merge 19ad0bf)
- b1 | Environment framework: terrain + water builder, zone atmosphere client, ambient audio, mesh asset pipeline | its targeted scenarios green
- b2 | Biomes 1-10 built end to end on the framework, one track at a time (owner 2026-10-30) | `environment` green; screenshots per track; owner visual review in Studio (owner 2026-10-31: Tracks 4-10 without per-track approval, reviewed together at the end)
Out of scope: gameplay changes, track layout changes (w3 layouts stay).

## char-art: Draft models for the 30 launch characters
Status: active (owner 2026-11-03)
Owner-confirmed: 2026-11-03 (a1-a3 chibi drafts retired by a4)
Branch: feature/alex/anime-world
Spec: docs/CHARACTER_GACHA_SPEC.md, design doc section 5
Deliverables:
- a4 | Avatar-style pilot (owner 2026-11-03, replaces chibi): Team Seven trio `leaf_hero`, `leaf_avenger`, `leaf_medic` in `assets/characters_avatar/` | 4 renders each; owner approves the look
- a5 | Other 27 characters in the approved avatar style | every id has 4 renders; rules-auditor sign-off; owner visual review
- a6 | The 30 models in game (owner 2026-11-03): uploaded, drawn by RunnerFactory; event-only not rollable; starter choice popup (design doc 4.21) | Studio check of a run, preview and popup
- a7 | Painted, unique look for all 30 (owner 2026-11-03): `tools/blender/paint/char_<id>.py` with its own hair for every id; re-export and re-upload | 4 renders each, contact sheet, owner visual review
Out of scope: R15 skeleton rigging and authored animation (runners use the procedural 6-part swing), models for the 3 event characters.

## first-impression: The first 30 seconds wow a new player (design doc 4.24)
Status: active (owner 2026-11-03: "continue these deliverables")
Owner-confirmed: 2026-11-03
Branch: feature/alex/anime-world
Spec: design doc 4.24, WORLD_REDESIGN_SPEC 7, BIOME_ENVIRONMENT_SPEC 2.1
Deliverables:
- fi1 | Plaza and Dojo meshes, golden-hour zone 0, sky loop, logo loading screen that waits for client assets | `world_layout`, `spawn_area`, `dojo`, `workshop` green; Studio check; rules audit PASS
- fi2 | Wayfinding: Market and Race Start clearly marked in bold (owner) | Studio shots from spawn; targeted scenarios above green
- fi3 | First join: camera reveal, lighter starter dim + in-world reveal, petal trail to the gate, Daily held until the first run ends, gate burst | Studio check on a fresh save; stylua / selene
- fi4 | Dojo extras: level-up effect, squad idle poses, stat-coloured lanterns, YOUR DOJO marker | `dojo`, `workshop` green; Studio check
- fi5 | Plaza petals and audio, sakura trunk collision, Index HUD icon without a car | Studio check; `scrap` still green
- fi6 | Emblem floating headers over Index, Shop, Potions, Market, Sensei, Race Start, YOUR DOJO (owner 2026-11-04) | Studio shots; `spawn_area`, `ui_billboards` green; stylua / selene; rules audit PASS
Out of scope: Market rebuild, phone performance testing (owner's device), c3 (owner's word).

## soul: Bleech series (owner 2026-11-04, design doc 4.30)
Status: active
Owner-confirmed: 2026-11-04
Branch: feature/alex/anime-world
Spec: docs/CHARACTER_GACHA_SPEC.md
Deliverables:
- s1 | 5 new models (Orihima, Rukiya, Renjy, Ichigu, Aizon) in the avatar pipeline, one evidence file each | exports under budget, renders reviewed, uploaded
- s2 | Catalog, Series, preset and Ulquiorro as `soul_hollow` on `foe_soul`, tests | `catalog` + `gacha` scenarios green, rules audit PASS
Out of scope: Bleech biome changes, rematch rewards, public release licensing.
## declutter: Clear spawn plaza (owner 2026-11-04)
Status: done
Owner-confirmed: 2026-11-04 ("declutter spawnlocation"; layout, Market sign, sky loop kept and trim level chosen by the owner; d1 draft and deliverables approved by the owner 2026-11-04)
Branch: feature/alex/anime-world
Spec: design doc 4.24 Clear plaza, WORLD_REDESIGN_SPEC 4 and 7
Deliverables:
- d1 | Rules written; Blender draft of the cleared plaza | renders from spawn and above; owner approves
- d2 | Approved draft in game | Studio shots from spawn show every Dojo; `world_layout`, `spawn_area`, `dojo`, `workshop` green; all prompts open; stylua / selene; rules audit PASS
- d3 | In-house Market stall replaces the fork's Aura stall; Legends cut to at most 2 beside the gate (owner 2026-11-04) | owner sees the render; Studio shots; `spawn_area`, `world_layout` green; Market prompt opens; stylua / selene; rules audit PASS
Out of scope: Market panel, Dojo meshes, gameplay numbers; sky loop kept (one leg moved, owner).

## villains: Villains redesigned and rollable (owner 2026-11-04, design doc 4.32)
Status: active
Owner-confirmed: 2026-11-04
Branch: feature/alex/anime-world
Spec: docs/CHARACTER_GACHA_SPEC.md, docs/NPC_RIVAL_SPEC.md
Deliverables:
- v1 | 9 `foe_*` models rebuilt with the character design skill, one evidence file each | exports under budget; owner approves renders; uploaded
- v2 | 8 new catalog characters sharing those models | `catalog` + `gacha` green, rules audit PASS
Out of scope: Freezo and Aizon models, new enemies.
## roll-anim: Every roll clearly shows the character rolled (owner 2026-11-04)
Status: active
Owner-confirmed: 2026-11-04 (layout, cycle in place, fit to interval, no new runtime dependency all chosen by the owner)
Branch: feature/alex/anime-world
Spec: design doc 4.31, docs/ROLL_ANIMATION_SPEC.md
Deliverables:
- r1 | Rules written in the design doc and the roll spec | rules audit PASS
- r2 | Result shows the real model, same framing and light from cycle to landing, in-place cycling, larger normal roll | `ui_roll_anim`, `ui_roll_emphasized` and the server roll scenario green; stylua / selene clean; rules audit PASS
- r3 | Emphasized look: big figure, gradient odds, outlined name, rarity crystal (our own art) | Studio captures of each phase look right; owner visual review
- r4 | Drawn portraits for every character (owner 2026-11-04, CHARACTER_GACHA_SPEC Digital art portrait), in the roll, Index and Enemies page, Backpack, starter card and showdown banner, with head-only art for the Team minibar | every rollable id in `CharacterPortraits` and `CharacterHeads`; roll and Index scenarios green; Studio capture; rules audit PASS
Out of scope: odds, economy, new dependencies.

## boss-event: Boss events, Relics, Gems and Sidekicks (owner 2026-11-04)
Status: active
Owner-confirmed: 2026-11-04 (plan approved)
Branch: feature/alex/boss-event (from aaf4b80, because it needs the unmerged universal run)
Spec: design doc 4.35-4.38, docs/BOSS_EVENT_SPEC.md, docs/SIDEKICK_SPEC.md, docs/RELIC_SPEC.md
Deliverables:
- b0 | Rules and research written | owner reads back and confirms
- b1 | Contact sheet: Big Raga and 3 miniature Sidekicks, no upload | owner approves designs
- b2 | Gems, quest rewards, save fields, HUD, admin | `gems` green: win and quests pay, duel and exhaustion do not
- b3 | Sidekick roll, summon page, gem packs, Bag of 50, auto-sell, equip, followers | `sidekicks`, `ui_sidekicks` green: luck cannot change odds, odds sum to 100%, full bag refuses without spending, equipped never sold
- b4 | Arena blockout, lanes, closed rail | owner reviews a size screenshot
- b5 | Event server: scheduler, teleport, prep and late join, team damage, boss run, HP, end, chat message | `boss_event` covers the full loop with 7 fake players
- b6 | Sky arena dressing | owner look, asset ledger signed
- b7a | Boss key frames: 3 moves, sliced renders | owner approves each move
- b7b | In-betweens, bake, in-game idle cycle | approved keys unchanged, owner look in Studio
- b7c | Team HUD, red header, spawn rise, HP bar, popups, VFX, SFX | `ui_boss` green, owner look
- b7d | Sidekick attacks: key frames, in-betweens, effects | owner approves each attack; `ui_sidekick_attack` green with 7 players
- b8 | Relics: data, drops, equip, UI, icons | `relics` green, odds sum to 100%
- b9 | Paid spawn | receipt test green: retry, active event, two buyers
- b10 | Sidekick tutorial | `ui_sidekick_tutorial` green
- b11 | Compatibility check | full harness and rules audit results reported
Out of scope: Relic or Sidekick trading, a second boss, an underground arena, pity, luck on summons, summon potions, VIP, shiny pass, extra banners.

## boss-phase2: Fully Adapted Raga, line run, chests and rewards popup (owner 2026-11-06)
Status: done 2026-11-06 (PR #5 merged, d2450c6)
Owner-confirmed: 2026-11-06 (plan approved: `~/.claude/plans/squishy-wishing-cook.md`)
Branch: feature/alex/boss-phase2 (from e87b19d, because `main` lacks the boss event and PR #4 is still open)
Spec: design doc 4.35, 4.37, 4.38, docs/BOSS_EVENT_SPEC.md, docs/RELIC_SPEC.md
Deliverables:
- p0 | Rules written | design doc and specs updated with the date
- p1 | Art for 5 Relics and 2 chests, uploaded | owner approves the contact sheet before upload
- p2 | Server: phases, stacks, Vulnerable, rewards, chests | `boss_event`, `relics` green
- p3 | Line run, 8.5 s wait, smoke | `boss_event`, `ui_boss` green
- p4 | Phase 2 presentation: title, wheel, scream, drop spill, faster bar | `ui_boss` green, owner look at a Studio capture
- p5 | Rewards popup, chest opening | `ui_relics`, `ui_boss_rewards` green
- p6 | Compatibility check | full harness and rules audit results reported, then a PR with a fresh review
Out of scope: 3D chests, new Raga key frames, moves faster than today's schedule, a chest screen outside the Relics inventory.

## ui-juice: The UI feels lively, consistent and smooth, with sound on every moment (owner 2026-11-04)
Status: done on the owner's word 2026-11-04 (u5 gaps accepted: last full server run 49/1, see handoff)
Owner-confirmed: 2026-11-04 (plan approved; ServerStorage folder plus copy, up to 4 extra sounds)
Branch: feature/alex/anime-world
Spec: design doc 4.33, docs/UI_FEEDBACK_SPEC.md
Deliverables:
- u0 | Live UI audit and SFX audit, rules written | `docs/UI_AUDIT.md` with captures reviewed; rules audit PASS
- u1 | 5 impacts in `ServerStorage/ImpactSounds`, up to 4 extras, `UiFeedback` cue table, `UiMotion` presets | every cue resolves to a loaded sound; `ui_motion`, `ui_reduced_motion` fail=0
- u2 | Consistency: one source for tokens, tint removed, kit bypasses closed | `ui_buttons`, `ui_hud` fail=0; stylua / selene clean
- u3 | Big moments: roll, showdown, defeat, Rebirth, money | `ui_roll_anim`, `ui_roll_emphasized`, `ui_showdown` fail=0; Studio captures
- u4 | Panels and small moments: open, tab, purchase, claim, denied, toggles, bars | targeted UI scenarios fail=0; new `ui_feedback` fail=0
- u5 | Compatibility check, owner 2026-11-04 "ensure ui and sfx are completely green, run compat check after the plan is fully finished": merge `orch/core/c3t`, full UI and server harness | `[UITEST] END fail=0`, `[CARTEST] END fail=0`, rules audit PASS; owner listens and looks. Status 2026-11-04: not met, stopped on the owner's word: UI pass=44 fail=0; server pass=49 fail=1 (`data`, fix not run), final server run skipped; audit FAIL, not re-audited
Out of scope: camera shake, per-category volume, music, gameplay and economy.

## sensei-cards: Sensei Tracks panel as one list of road-screenshot cards (owner 2026-11-04, design doc 4.15)
Status: active
Owner-confirmed: 2026-11-04 (owner's request, reference image of a numbered horizontal card list)
Branch: feature/alex/anime-world
Deliverables:
- s1 | Tracks panel: long horizontal clickable cards with road screenshot, definition, recommended speed, enemy name | `ui_checkpoints` and the checkpoint_* clicks green; stylua / selene; rules audit PASS
Out of scope: checkpoint rules, bonus, server code.

## trim: Context and repo bloat removed (owner 2026-11-03)
Status: active
Owner-confirmed: 2026-11-03 ("delete old rules that don't matter anymore and unnecessary text; files, folders, assets unused by current gameplay")
Branch: feature/alex/anime-world
Deliverables:
- t1 | Stale docs shortened, unused assets and files removed | `rojo build`, `stylua --check src`, `selene src` clean; rules audit finds no live rule lost
Out of scope: gameplay, tests, git history rewrite.

## roster: New characters, tiers above Secret and the 12-Sidekick pool (owner 2026-11-05)
Status: paused for characters until `feature/alex/speed-balance` lands and `speed_probe` has run; Sidekick rows are with the boss-event session
Owner-confirmed: 2026-11-05
Branch: orch/roster/art1 (art committed, bca9b6e)
Deliverables:
- art1: models, portraits, evidence for 12 Chainsaw Mann and Solo Levelin characters, 9 Sidekicks, Void Saitamo; done: owner approved all 22 on 2026-11-05.
- side1: 12-Sidekick pool live; done when boss-event merges the art and applies the table, and each Sidekick is seen following a runner in Studio.
- tier1: Eternal tier (base Speed 5e16, proposed, owner OK 2026-11-05) and a curve anchor Speed 7e37 = 1000 studs/s, once `speed_probe` supports `MAX_CRUISE` 1000; done when `catalog`, `gacha` and the stamina and workshop scenarios are green.
- char1: 12 characters uploaded and rollable, rules in the design doc first; done when `catalog` and `gacha` are green and an Eternal roll and run are seen in Studio.
- void1: Void tier (base Speed 5e19) with Overspeed passives; Void Saitamo (`punch_void`) ships with the Void characters in a later update, after the monetization branch is merged.
Out of scope: backlog characters and Attack animation before key-frame approval.
