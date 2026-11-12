# Owner questions

## oq5: fw3 rule refinements, orchestrator default (2026-10-31, owner delegated)
- A pinned (At) hero whose footprint reaches a road corridor is pushed outward 4 studs per try (max 24) instead of
  warning; measured pushes 4-8 studs (Landmark_259, _263, _315, _49).
- A padded prop (house) whose footprint reaches a corridor sits at the corridor's lowest ground under it (CorridorLow)
  so it never floats; pads never overlap (9 Docks houses removed by that rule).
- Chosen as the recommended fix (houses gap 0, TileRing gap 0, 0 warnings in the Lune harness). Spec 3.2 Pad details.
  Review in the morning; revert = commit on orch/biomes/fw3.

## Morning review list (overnight run, 2026-10-31)
- Track camera: session-only setting (TrackCamera attribute), not saved across sessions, like the other toggles.
- fw4 (orchestrator default): halls in narrow gaps sit at road level (Track 4: 22 of 35) instead of being dropped; 7 fewer padded props kept overall.
- Track 6: billboards show abstract shapes, not made-up text (spec 7 wording; avoids the generator writing real words).
  ToppledRobot hero ~31 x 25 x 31 placed (under the placeholder 60-220 hero height; the mesh generator caps short sides
  at ~16 studs). AcademyTower stretched 2.6x vertically to ~200 placed.
- NPC rival names (spec: label RIVAL over <Name>) are not implemented in code: NpcConfig has no Name field (label shows track08_NPC). Enelu [Enel] is in the spec only; implementing rival names/models is a separate task (not in biome scope).
- Track 7: heroes sized to fit under the 20-40 stud tunnel ceilings (~23-33 tall), below the placeholder 60-220 hero height; the stalled train stands on a bay platform (framework builds bays as platforms).
- fw6: on tunnel tracks a pinned hero that cannot fit in its bay is not built (warns) - the 'never deleted' rule cannot place it in the earth.
- Track 7: plain tunnel stretches between bays carry no dressing props (Prune keeps props 8 studs from the road, leaving <1 stud to the wall); only tiles, stripe and light strips. Kept as is (orchestrator default).
- Track 8: GiantBeanstalk and CloudTown heroes are part-built (generator caps ~2:1; CloudTown try read as a face). Bell toll is ProSoundEffects 9113804175 (Studio cannot upload audio). 0.82-1.0 Inner is now cloud mounds so the bell is visible.
- Track 4: MoonPeak horizon backdrop reads as a flat pale box (T4_Landmark). Track 10: hard near/far water edge in the aerial; dome-house doors face away from the road.

## 2026-11-03 uipolish: active runner animation (rules audit)
Design doc 4.20 says every animation goes through `Client/UiMotion`. The team row's active glow and marker bob are a RenderStepped loop in `TeamHud.client.luau`, not a UiMotion preset; they do stop under reduced motion, and `CheckpointUi` uses the same pattern. Question: does that gate satisfy 4.20, or must the loop move into UiMotion? Blocks nothing.
- Track 5: BrokenStorefront has a weak face reading (see T5_Storefront.jpg). SlicedTower top floats above the cut; viaduct deck stays level.
- 2026-10-31: the Track 8 builder killed and restarted the IVS dashboard (`server.py --port 8765`). Check it runs with your usual flags.
- Max Players: Edit-mode Players.MaxPlayers still read 60 (`WorkshopConfig` needs 7); check in a live server.

## 2026-11-03 trim: doc and code disagree (left as written, owner to rule)
- `MAX_CRUISE_TOTAL_MULTI`, `CruiseStatMulti`: design doc 4.5, 4.8, TEAM_AND_STAMINA_SPEC and CHARACTER_GACHA_SPEC cite them; `MAX_CRUISE_TOTAL_MULTI` is not in `src/`, `CruiseStatMulti` only in tests as retired (`Scenarios.luau:2876,2911`).
- Rock colour: TRACKS References Track 1 says #9C8F7E, BIOME 3.4 and `TerrainBuilder` say #8A6E52; both tagged owner 2026-10-31.
- Track 7 heroes: BIOME 7 lists three; `Desert.luau:115` also builds a collapsed escalator.
- Design doc 3 loops back to Track 1; 4.15 and `RaceService` loop to the checkpoint.
- Design doc 7 save list says VERSION 1 and `Speed`; code has VERSION 13, no `Speed`, plus `RebirthLevel`.
- Design doc 4.13 lists the Money branch under speed multi. Design doc 4.4 omits the c3 exhaustion ruling (it is in the change log and spec).
- Design doc 4.7 Stamina potion x1.5, 15 min; code has tiers StaminaI-III.
- TRACKS "never change global Lighting" (tests cite it) vs client-local Lighting in BIOME 1 and design doc 4.10. TRACKS "stat speed" wording vs the retired Speed stat (4.13).
- CHARACTER_GACHA_SPEC `SpeedMulti` row and TEAM_AND_STAMINA_SPEC `CruiseStatMulti` vs the retired Speed stat (design doc 4.13). CHARACTER_GACHA_SPEC "33 rollable" vs event-only characters not rollable.
- WORLD_REDESIGN_SPEC leaderboard text vs design doc 4.16. NPC_RIVAL_SPEC "start track" vs design doc 4.15.
- WORLD_REDESIGN_SPEC scrap list names `CarFactory`, `CarConfig`, `rusty_hatchback`; they are still in `src/` or `tools/`.

## 2026-11-03 trim: proposed rule
Add to CLAUDE.md: `handoff.md` holds current state only; replace stale lines, never append history. It grew to 53 KB by appending.

## 2026-11-04 ui-juice: flow rulings from the UI audit (docs/UI_AUDIT.md); nothing is blocked
- A1 Rebirth: one tap wipes the player's money with no confirm. Add a second step? Motion pass adds the celebration either way.
- A3 Emphasized roll closes Index, Stats, Settings and Rebirth mid-use (seen once, inferred from code). Hold the emphasized view until the panel closes, or use the compact roll?
- A19 Auto turns off with no message when the team is exhausted (`RaceService.luau:632`), so an idle game needs a tap per run. Intended? If yes, the exhausted toast gains "Auto stopped".
- `docs/HUD_LAYOUT_SPEC.md` is cited by code and harness but is absent from the repo. Panel open scale: 4.20 says 0.9, `UiSpec.luau:1261` says 0.92.
- Sounds: Coin and Denied are community uploads with unknown origin, not ProSoundEffects; listen and swap if needed.
- 2026-11-04: to review: panels close on outside click (Duel excluded), Upgrades has no EXIT and hides the HUD buttons while open, Quests has a claimable badge (design doc 4.33).
- 2026-11-04: Index Equip on Team slots 2 and 3 stays active per design doc 4.2 (single equip moves to slot 1, the server swaps), although audit A14 suggested "IN TEAM" on all 3. Only slot 1 is disabled.

## 2026-11-04 ui-juice u5: rulings from the rules audit; nothing is blocked
- RULED 2026-11-04 (owner): Burst may play over the moment's own panel; UI_FEEDBACK_SPEC 3 amended. Was: Burst over open panels: Daily, Quest and Rebirth claim inside their own open panel. `docs/UI_AUDIT.md` rows pair them with Burst; UI_FEEDBACK_SPEC 3 bans Burst over open panels. Kept as the audit table says until ruled. A running roll now always skips Burst.
- One Sound per cue (UI_FEEDBACK_SPEC 2) against RollSecret's Boom + Chime (`docs/UI_AUDIT.md`). Kept both. Chime now plays at 4.5 (spec x5), Boom at 0.9.
- Audit fixes not listed in design doc 4.33, each changing pins or behaviour: Backpack opens on Characters (`UiContracts.luau:841`), race map moved (`UiResponsive.luau:84`), track name changed (A17), "NEXT REBIRTH" label (A25), grey BUY (A18). Add them to 4.33?
- Coin and Denied are community uploads of unknown origin and no sound has been heard, so design doc 5's "no anime IP" rests on asset details only.
- `ui_run_visual` `mesh_loaded`: a mesh whose fetch ends up to 5 s after the drawn copy first appears passes. A real player sees that model pop in on its first run; no preload of worn models exists. Accept, or preload the Team's models?

## 2026-11-06 boss-polish: exhaustion view crop in Phase 2
The zoomed exhaustion view (120 studs out, 80 up, 4 deg down) shows all of Big Raga in Phase 1. At Phase 2's 1.25x the wheel top is cropped on every lane (about 53 to 56 deg against the 50 deg limit). `BOSS_EVENT_SPEC` also says the player "sees everything from above". Answered by the owner 2026-11-06: the crop is fine, keep the zoom.

## 2026-11-10 boss audit: camera angles and the flat boss (for approval before commit)
Uncommitted in the main checkout. Screenshots are in the session report.
1. Camera while running: yaw 75 deg inward, pitch 26 deg up, eye at least 6 studs over the deck (were 55, 12, 2). FOV 100 and the 40 stud zoom unchanged. Result: the whole boss, wheel included, sits under the HP bar from every lane at the Phase 2 size, and the damage numbers over its chest land mid-screen instead of behind the bar. Approve, or give other angles.
2. The flat low-graphics boss image is deleted: it was the "second Raga" (a still image peeking out beside the posed model while it idles), and at quality 1 the real model now draws from the lanes on the 550 ring. Not checked on a real phone. Approve the deletion?
3. Owner 2026-11-10, from the screenshots: "still should see mahoraga a bit more, can downscale overall size of boss if needed". From the ring the camera alone cannot shrink the boss, so it is drawn at 0.75 x (`BossArenaConfig.BossScale`, proposed): 421 studs to the head top, 603 to the wheel top, 754 in Phase 2 (was 561 / 804 / 1005). The scream's close camera scales with it. Approve 0.75, or give another factor?
4. Seen while screenshotting the scale (not changed): the exhaustion view's eye (placeholders 120 studs out, 80 up, spec "Exhaustion view") can sit behind an outer arch post, which then hides the boss for the whole 8.5 s wait (screenshot 8). A higher eye (about 160 up) or a shorter reach (about 60 out) would clear the posts. Want it changed, and which way?
Answered by the owner 2026-11-10: items 1-3 approved and committed (angles 75 / 26 / 6, flat boss deleted, 0.75 x). Item 4: owner 2026-11-10 chose the higher eye, 160 up.

## 2026-11-11 boss-mage: rules still open for The Elf Mage
None of these block the renders and key frames. All of them block the server work (m10).
1. Interval: you answered "random, either or every 60 minutes". Is it one random boss every 30 minutes (today's timer), or every 60 minutes?
2. HP, time limit and late join: the same as Big Raga (7,500 HP per player, 8 minutes)?
3. Rewards: her own chest and 6 Relics (4.38 says every boss brings 6), a boss-drop Sidekick, Money amount. Until ruled, should she pay Big Raga's Phase 1 rewards, or nothing?
4. Vulnerable (next hit costs 50% more after an undodged move): does it apply to her moves?
5. Golem slam's 20% damage cut: 15 seconds and stacking, like Shouted?
6. Rhythm circles: 4 circles in 2 seconds, +/- 0.18 s, any miss counts as hit. On phones, is the same count fair, or fewer circles?
7. Spawn texts: "The Elf Mage has awakened, take her down!!!" and the chat line.
8. Upload: no license was found for the source; uploading her model, golem and art needs your word, as for Saitamo (4.35).
Answered by the owner 2026-11-11: use Big Raga's rules as proposed defaults for items 2-7 (4 circles on every device), one random boss every 30 minutes, upload allowed. Size 8x; all renders and key frames approved.

## 2026-11-11 boss-mage: build defaults taken while you were away (all proposed, change any)
1. Wall moved out to radius 164 (was 132 in the approved draft): the event camera sits 40 studs behind and outside the runner, which put it behind the wall on lanes 4 to 7. The room is 328 studs across; the look is unchanged.
2. Small ring lap feel: a lap is 465 to 767 studs, under 1 second at 800 studs/s. No speed cap was added, because 4.37 says real cruise. Look in Studio and say if a cap or a larger ring is wanted. Answered by the owner 2026-11-11: cap the run speed in her arena so the background does not spin. Cap 100 studs/s is proposed.
3. Vulnerable applies to all three of her moves (your Raga-defaults answer): after one undodged move every later hit costs 30 / 45 / 22.5%. Three undodged barrages empty a team.
4. Rhythm circles: the first circle appears 1.35 s into the golem move, 0.65 s before the 2 s wind-up, so that 4 beats with a 1 s ring fit before the slam.
5. A dodged slam dashes to the next lane like a Dodge bar dodge.
6. She enters by lowering from the broken dome in 1.5 s (Big Raga rises from below).
7. The Bosses popup's idle text names Big Raga and the sky arena today. Proposed for both bosses: "Every 30 minutes a boss awakens. Defeat it for a treasure chest!"
8. During her event the drop list still shows Raga's Treasure with "Big Raga 0.001%" (her rewards are Raga's until her own exist).
9. Also taken as proposed: camera pitch 14 in her arena; arena centre (0, 1200, -7000); the server judges the click times only, not where the click landed (same trust as the Dodge bar); status name "Crushed"; hit texts "You were struck by her lightning", "You were blasted by her barrage", "The golem crushed you"; "The Elf Mage is casting right now"; the move chat lines, invite title and hint, "The Elf Mage Defeated!" and the caption "Golem Slam! Hit every circle!" (all in BOSS_EVENT_SPEC "The Elf Mage").
10. Load at join: her pose data (269 KB) loads at join, like Big Raga's today, against section 7 "Join size". The fix rides on the unmerged lazy-data branch. Merge that next, or accept for now?
11. Gamepad players cannot press the rhythm circles (click or tap only), so they always take the golem slam. Add a gamepad path?


## 2026-11-11 boss-mage-2: defaults taken for the Stone Golem miniboss and the cards (all proposed, change any)
1. Golem HP is a flat 1,000, not per player. Her HP is 7,500 per player, so the golem falls in a few seconds with a full arena. Flat, or 1,000 per player?
2. The golem attacks every 5 s, slam then sweep.
3. The event's 8 minute timer keeps running while the golem stands, and a timeout with it standing pays nothing.
4. Vulnerable applies to golem hits, as on her moves.
5. Her HP bar dims while she is immune; the golem's bar is about 60% of her bar's size.
6. Rhythm: 3 circles, +/- 0.28 s, circle 14.5% of the screen height (19% on phones), all 3 needed.
7. Lightning and barrage keep their 10 strikes (4 under REDUCED EFFECTS), now spread over the 2 s window. More strikes?
8. Bosses cards: the server picks the next boss when it schedules the event, so one dimmed card can show "Next event in m:ss". Without that, no card can name the next boss.
9. Her Relics favour attack speed and luck. Names: Dwarf's Helmet, Hero's Bracelet, Elf Staff, Priest's Flask, Master's Grimoire. Odds as Big Raga's Phase 1 table. Her chest has no Sidekick roll.
Answered by the owner 2026-11-11: "approved, go with draft B" on the review page (cards B, all new key frames, Relics and chest). Items 1-9 stay as proposed values. Not answered one by one: golem HP flat or per player (built flat), strike rate (built as today's 10 per move), a boss portrait for Big Raga (not drawn). Upload of the new art: asked before g6's upload step.

## 2026-11-11 boss-mage-2: found while building (all proposed, change any)
1. Her pose data grew from 269 KB to 511 KB with the golem's own moves, and it still loads at join (section 7 "Join size"). Fix by merging the lazy-data branch, or by storing golem block positions only when they change. Which, and when?
2. Golem damage shows in a player's total but does not count toward the 5% share that earns rewards.
3. A paid spawn picks a fresh random boss; the announced next boss is unchanged.
4. The approved golem crumble inside the old slam move (4.8 s) is no longer played; the new approved `golem_fall` is the crumble.
5. Lightning's cost moved from 1.6 s to 2.0 s into the move, the start of the 2 s window.
Answered by the owner 2026-11-12: golem HP is 1,000 per player; the rhythm is slower (3 s window, 0.9 s apart, 1.5 s rings, +/- 0.35 s). Still open: pose data join size (recommendation given: lazy per-boss load), the Bosses button edit found in Studio.
Answered by the owner 2026-11-12: boss data loads per boss on announcement (the lazy-load recommendation); the Bosses button moves up next to Roblox's headphone icon. The Studio-only edit hiding the button while the Sidekicks panel is open was not committed: the new position should clear the panel headers; check after the move.
