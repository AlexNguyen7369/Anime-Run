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
- Max Players: Edit-mode Players.MaxPlayers still read 60 (`WorkshopConfig` needs 7); check in a live server. Resolved 2026-11-11: the plots are gone; 7 is still needed by the boss lanes (4.37).

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
9. Her Relics favour attack speed and luck. Names: Dwarf's Helmet, Hero's Bracelet, Elf Staff, Priest's Flask, Master's Grimoire. Odds as Big Raga's Phase 1 table. Her chest has no Sidekick roll (superseded 2026-11-11: every boss chest rolls its own Sidekick, design doc 4.37; see boss-king item 11).
Answered by the owner 2026-11-11: "approved, go with draft B" on the review page (cards B, all new key frames, Relics and chest). Items 1-9 stay as proposed values. Not answered one by one: golem HP flat or per player (built flat), strike rate (built as today's 10 per move), a boss portrait for Big Raga (not drawn). Upload of the new art: asked before g6's upload step.

## 2026-11-11 boss-mage-2: found while building (all proposed, change any)
1. Her pose data grew from 269 KB to 511 KB with the golem's own moves, and it still loads at join (section 7 "Join size"). Fix by merging the lazy-data branch, or by storing golem block positions only when they change. Which, and when?
2. Golem damage shows in a player's total but does not count toward the 5% share that earns rewards.
3. A paid spawn picks a fresh random boss; the announced next boss is unchanged.
4. The approved golem crumble inside the old slam move (4.8 s) is no longer played; the new approved `golem_fall` is the crumble.
5. Lightning's cost moved from 1.6 s to 2.0 s into the move, the start of the 2 s window.
Answered by the owner 2026-11-12: golem HP is 1,000 per player; the rhythm is slower (3 s window, 0.9 s apart, 1.5 s rings, +/- 0.35 s). Still open: pose data join size (recommendation given: lazy per-boss load), the Bosses button edit found in Studio.
Answered by the owner 2026-11-12: boss data loads per boss on announcement (the lazy-load recommendation); the Bosses button moves up next to Roblox's headphone icon. The Studio-only edit hiding the button while the Sidekicks panel is open was not committed: the new position should clear the panel headers; check after the move.
Superseded 2026-11-12, same day: the Bosses button is not next to Roblox's headphone icon; it sits in a second left column with the Team button (design doc 4.40). Boss data is sent 2 minutes before a boss's event, not at the announcement, and removed after the event (section 7).
Answered by the owner 2026-11-12: Team icon N3, upload allowed (image 89758623094700, ledger `tools/blender/hud_icon_assets.json`).


## 2026-11-11 boss-king: proposed values for The Golden King (all proposed, change any)
1. Size: 8 x a character (about 44 studs), standing on a gold mound, arms folded, no hover.
2. Arena dressing on the colosseum shell: sandstone pointed arches, 8 pillars, treasure mounds, urns, swords and spears stuck in gold, red drapes, warm gold light. Ring, wall, camera and the 100 studs/s cap unchanged. Answered, owner 2026-11-11: vault pass 2 approved, his reference look (grey-brown stone brick, round arches on short columns, torches, banners, gold doors, chests in the bays, gold mounds, stepped dais with a gold heap); counts stay proposed (22 bays, 12 torches, 10 banners, 6 mounds).
3. Entrance: he rises from the floor with his mound over `RiseSeconds`, like Big Raga (open question in BOSS_EVENT_SPEC; the other option is standing there already).
4. Gates of Babylon: 12 to 20 portals; 2.0 s of volleys, one every 0.15 s, 7 to 10 projectiles or beams each, across the arena; one Dodge bar before; hit 20% of a full bar, once per move.
5. Enuma Elish: 3 s red charge as the Dodge window, then a 2 s red-black beam over the whole arena; hit 40% of a full bar, once per move.
6. Shield Gates: 5 to 7 shields; no Dodge bar, no cost; boss-side `Fortified`, 40% less damage from everyone until his next move starts; the shields shatter then.
7. Fortified notice "The Golden King has fortified his defenses" in the red header style; chat "The Golden King raises his shields! He takes 40% less damage until his next move"; status icon with no seconds.
8. Defaults as Big Raga: HP per player, 8 minutes, late join, Vulnerable on Gates and Enuma Elish, Phase 1 Money, no Phase 2, no miniboss, uniform random pick over the 3 bosses; the move order Gates, Enuma Elish, Shield Gates with idles between, repeating.
9. Texts (the two move chat lines and "Enuma Elish tore through you" are fixed by the plan; the rest proposed): warning "The Golden King has arrived, take him down!!!"; chat "THE GOLDEN KING HAS ARRIVED, TAKE HIM DOWN FOR REWARDS"; move chat "The Golden King opens his vault! -20% stamina", "The Golden King unleashes Enuma Elish! -40% stamina"; hit texts "The King's treasures struck you" (Gates; my wording, not in the plan) and "Enuma Elish tore through you"; invite "THE GOLDEN KING EVENT" and hint "Teleport to fight The Golden King before the timer ends"; rewards "The Golden King Defeated!"; Bosses card "The Golden King is judging you right now".
10. Relics, priority damage and money gain: Common Gold Coin, Rare Royal Goblet, Epic Chain of Heaven, Legendary Golden Armor, Mythic Key of Babylon (the Dodge bar's key art), Secret World Core; bonuses follow Big Raga's pattern with Damage and Money first, then Attack Speed and Luck; ids `relic_coin`, `relic_goblet`, `relic_chain`, `relic_armor`, `relic_key`; odds Big Raga's Phase 1 table.
11. Chest "Golden King's Treasure", id `relic_chest_king`, with a separate 0.001% roll of `side_king`.
12. Sidekicks `side_king` and `side_mage`: Secret, +10% cruise +10% stamina, hit 40 every 1.5 s, sell 30 Gems (all as `side_raga`); `side_king` walks and fires a small Gate volley, `side_mage` flies and fires a small lightning bolt.
13. Key frames: `idle` 3, `gates` 5, `gates_window` 3, `enuma_charge` 4, `enuma_beam` 4, `shields` 5, `fortified_idle` 3; REDUCED EFFECTS 3 per volley, shields kept, sky tint dropped. Answered, owner 2026-11-11: key frames pre-approved for this boss ("finish end to end"); slices still rendered and shown, in-betweens may start without a second approval. Counts and REDUCED EFFECTS values stay proposed. (Superseded 2026-11-12: 10 key frames per move, see 2026-11-12 item 8.)
14. Please drop the 10 reference images (vault x3, Gilgamesh x2, Gates x3, Ea raised x1, key x1) into `../AnimeRun-orch/art-backup/anime_refs/boss_king/` before k2; they were pasted in chat only and are not saved.
15. Baked timings (k6, `src/late/BossKingPoses.luau`) as proposed defaults, 2026-11-11: lead-ins `gates_in`, `enuma_in`, `shields_in` 0.75 s each; `idle` 4.0 s; `gates` 4.4 s (Dodge window 0 to 1.6 s, volleys 1.6 to 3.6 s, cost at 1.6 s); `enuma` 5.6 s (charge = Dodge window 0 to 3.0 s, beam 3.0 to 5.0 s, Ea shown 0 to 5.6 s); `shields` 2.6 s (`Fortified` at 2.2 s); cycle idle, gates_in, gates, idle, idle, enuma_in, enuma, idle, idle, shields_in, shields, idle = 38.85 s. Answered, owner 2026-11-11 (relayed): baked timings stand as proposed defaults.
16. The key-frame pre-approval (design doc 4.37 Third boss, "his key frames") was applied to both Sidekick attacks (`side_king` and `side_mage`): confirm, or the `side_mage` attack goes back to a key-frame review. (Asked 2026-11-11; the orchestrator is asking the owner directly as well.) Answered, owner 2026-11-11 (relayed): the pre-approval covers both Sidekick attacks.
17. Vault atmosphere (`src/shared/BiomeEnvironment.luau` `VAULT` profile, **proposed**, 2026-11-11): ClockTime 0, Ambient 7A6A5A, OutdoorAmbient 5E5044, warm colour grade, no sun; torches range 70 / brightness 3.5; warm glow on the gold heap. The first pass was too dark and was replaced. Proposed default taken in the Studio verify; change any. (Superseded 2026-11-12 by item 10: the vault is retired.)
18. He does not hover (`BossArenaConfig` vault `HoverY` 0, `BobStuds` 0; **proposed**, 2026-11-11). Proposed default taken in the Studio verify; change any. (Superseded 2026-11-12 by item 10: he hovers.)
19. Gates projectiles (**proposed**, 2026-11-11): weapon shapes (sword, spear, cleaver, 13 to 19 studs long, spinning, gold trail) with thinner gold beams; shot flight 0.3 s (was 0.22). Proposed default taken in the Studio verify; change any.
20. Fortified notice (**proposed**, 2026-11-11): a red `FortifiedNotice` label under the boss bar, in the Warning's place, for 4 s. Proposed default taken in the Studio verify; change any.
21. Dodge openers (**proposed**, 2026-11-11): the `gates_start` / `enuma_start` schedule events are not Dodge moments; the bar opens only at `gates` / `enuma` (none for `shields`). Proposed default taken in the Studio verify; change any.
22. For information, measured in the 2026-11-11 Studio verify: vault PartCount 1,135 of the 1,150 cap; frame time in a volley median 16.6 ms, p90 17.5 ms, worst 19.3 ms (Studio). (The vault is retired 2026-11-12, item 10.)
23. Dodge bar hide (**proposed**, 2026-11-11 Studio verify): when a player drops out of the fight (exhausted, waiting) mid-prompt the bar hides at once, as it does while the golem stands, instead of playing the 0.3 s close (design doc 4.37 Dodge bar). Shared with Big Raga and the Elf Mage. Keep the snap, or play the close in both places?
Answered by the owner 2026-11-11 on the review page (https://claude.ai/artifact/6r7jJr5ykcdaAD574PHVH5): items 2 and 13 as marked above; models `boss_king` (2,872 tris, Ea massive, angular armor), `side_king` (2,422 tris) and `side_mage` (3,148 tris) approved; all the digital art (key Dodge icon, `Fortified` icon, portraits and heads, 5 Relics and chest, Bosses card) approved; upload allowed for the three models and all the Golden King art. Items 1, 3-12 and 14 stay open.

## 2026-11-11 power-ups: proposed defaults (design doc 4.44, POWERUP_SPEC)
- Rules-audit question, answered with the recommended option on the owner's standing word ("auto approve by recommended", 2026-11-11), change it if wrong: the Speed boost is also the exception to the 4.18 loading budget (budget stays at `MAX_CRUISE`; `RunHold` still catches a boosted runner because holds are not distance look-ahead; a late biome switch during the 2 s is accepted). Alternative: raise the 4.18 budget to 1.2 x `MAX_CRUISE`.
- Display constants, proposed: pickup pop 1.4x over 0.25 s, rim 16 pieces, glow light range 14, HUD badge 26 px. Stamina ring colour is the stamina bar's Full blue (60, 150, 255), the same as the HUD's blue number.
- Known: `SpeedLeft` pauses during a `RunHold` but `PowerSpeedUntil` does not, so the badge can empty while the server boost is still owed after the hold (code `shortcut:` in RaceService).
- Regular track runs only: none in boss arenas or duels.
- Rolled per player at each track start, fresh every run (a loss reset rerolls).
- Spots between 10% and 90% of the track, at least 300 studs apart; type 50/50 Speed / Stamina.
- A second Speed during a boost resets the timer to 2 s (no stacking); the boost carries across a tag-in.
- Risk (recomputed 2026-11-12 for x1.2 / 2 s): a Secret at 800 boosted to 960 studs/s covers 1,920 studs in 2 s; check the `RunHold` on Tracks 6-10 (4.25) still catches it.
- Ring size 12 studs, 6 over the rail; turn speed one turn per 4 s and glow breath 1.6 s (owner 2026-11-11 picked turning and glowing, no ground ring).

## 2026-11-12 boss-anim-rework: open items (design doc 4.37 "Animation rework")
1. Pilot move: Enuma Elish **proposed** (it shows the rig, the charge, the hit and the beam in one move). Another move first?
2. Uploads: the jointed `boss_king` and `boss_mage` meshes need the upload word per batch. Drawn impact frames (2 to 3 images per signature hit) are optional and need their own word.
3. Vault part cap: the king's elbows and knees add 4 parts to a room at 1,135 of about 1,150. Reported after the build; over the cap needs a ruling (raise the cap, or merge vault dressing). (Superseded 2026-11-12 by item 10: his own arena has its own part budget.)
4. The clips show the king's Enuma Elish shirtless with red markings and his Gates cast with hands in his pockets, in a jacket. The model stays in full golden armor (evidence file, 2026-11-11 choice) unless the owner asks otherwise; only the staging is taken.
5. The clips show a honeycomb barrier and tentacle attacks. Neither is one of her moves; not built.
6. Pose data will grow with the extra joints (`BossMagePoses` is 511 KB). Sizes reported at each bake; no cap is written.
7. PR #13 (hotfix `BossVfx.Start`) is open and not in main; this branch starts from main without it. Merge it first, or this branch merges main again after it lands.
8. Owner 2026-11-12: 10 key frames per move before in-betweens; the whole arena flashes or shakes on boss hits; runners' auras and trails are decreased during events. Recorded in 4.37 and the spec. Proposed amounts, change any: aura particles 0.25 x, trails 0.35 x opacity, and the 2026-11-06 event boost (2.5 x aura scale, trails 1.5 x longer) removed. If the boost should stay and only brightness drop, say so.
9. Arena-wide flashes are capped at 3 full flashes per second and are off under REDUCED EFFECTS (photosensitive players). Proposed.
10. Owner 2026-11-12: the Golden King gets his own arena from the concept image (open-air sunset stadium, glazed gate, winged lion statues, treasure mound), larger than the colosseum; he keeps his size, hovers and gets stronger effects. Recorded in 4.37 and the spec. Proposed, change any: ring inner radius 110 and wall 250 (about 1.5 x the colosseum; a lap grows from about 620 to about 870 studs, so laps take longer at the same cap); hover 12 studs over the mound, bob 1.5 studs; part target about 1,200. This retires the vault the owner approved on 2026-11-11 and its lighting item 17, and replaces item 18 ("he does not hover").
11. The banner emblem and the statues are drawn in-house from the concept's idea (a gold winged emblem; winged lions with crowned heads). The concept image itself is look-only and is not shipped.
12. A longer lap changes how often a runner passes the same spot but not stamina or damage rules. If lap time should stay as in the colosseum, the cap would rise with the radius instead: say so.
13. Rules audit 2026-11-12, needs the owner: does a move's 2 s strike window count inside that move's 10 key frames (as written now, **proposed**), or does each window get its own 10? It matters for `lightning`, `barrage` and `gates`; the pilot move (Enuma Elish) is not affected.
14. Rules audit 2026-11-12, needs the owner: is 10 key frames per move the rule for future bosses too? The `/new-boss` skill still says 3 to 5; today the 10 is written only for the Elf Mage, the Stone Golem and the Golden King.
15. A field-of-view punch on hits was dropped from the rework: the event's FOV is locked (owner 2026-11-06). Say so if a short FOV kick on boss hits is wanted as an exception.
16. Owner 2026-11-12 on the Enuma Elish key frames: the Gates portals a bit bigger and better looking than plain yellow glowing circles; Ea's white wind lines swirl and spin. Recorded in the spec ("Animation rework"). Proposed: portals 1.25 x. Portal design drafts are shown before any upload. The owner has not yet said whether the 10 key poses and the jointed model themselves are approved.
Answered by the owner 2026-11-12 on the review page (https://claude.ai/artifact/5ZJxJCKo8XGcDMzXdqbJ7Z), "everything looks good, go for sun wheel for Babylon circles and inside for 8th decision": model, Enuma Elish keys, wind swirl, arena look and camera approved; FOV 60 in his arena taken as approved with the camera (read by the orchestrator from "everything looks good"; say so if the FOV should stay 100); laps longer at the same cap (item 12); portal C; item 13: windows count inside the 10. Still open: item 14 (10 keys for future bosses), item 15 (an FOV kick on hits: none).
17. The jointed Elf Mage is 4,148 triangles against the 3,000 budget (**proposed**); the shipped 6-part model was already 3,352. Most of the rise is her tails cut into 3 segments each (about 260 each); 2 segments would save about 270. Built and keyed as is under the night's pre-approval; the budget, or a trim, is the owner's call.
18. His arena in game (a8): the top arcade's round arches are chamfered stand-ins (round needs a mesh upload), and engine materials stand in for the draft's stone, glazed brick and paving textures (needs image uploads). In-game captures look flatter and more orange than the Blender renders. At the Enuma Elish raise, Ea reaches through the HP bar from the lane camera. Say which of these to fix and give the upload word for the textures and arch mesh.
19. Enuma Elish beam sweep (a5c): the beam now turns with his baked hip turn (spec "Pose-tied effects"). From the approved keys the hip yaw runs 180 at 3.0 s, -70 at 3.9 s, 72 at 4.85 s, 0 at 5.6 s, so the beam covers about 250 degrees of the ring (estimate from the keys, not measured), while design doc 4.37 says the beam and cyclone "sweeps the whole arena". Gameplay is unchanged (the server hits everyone). Choose: re-key the beam keys so his hips turn a full circle, add the old even turn on top of his hips, or accept the hip turn.
Answered by the owner 2026-11-12, morning ("approved all but one"): items 13, 17, 18, 19 and the overnight review: approved as built (read by the orchestrator as: mage budget accepted at 4,148, beam keeps his hip turn, hover and arena stay as built, uploads allowed for the jointed king and mage meshes and portal C). The one change: barrage circles spawn slower, one by one, all before the beams fire, a bit bigger. Still open: item 14 (10 keys for future bosses), item 15 (FOV kick on hits), arena textures (none drawn as image files yet; the arena keeps engine materials, `arena_ids_listed` stays red until a texture is made and uploaded).
Answered by the owner 2026-11-12 ("questions: your recommendation"): item 14, yes, 10 key frames per move for every future boss (design doc 4.37, `/new-boss` skill updated); item 15, no FOV kick on hits, the event FOV lock stays.
20. Owner 2026-11-12: boss effects have no reduced version; the Effects toggle and Roblox Reduced Motion wipe boss VFX completely. Taken by the orchestrator: gameplay telegraphs (strike marks, Dodge bar, rhythm circles, HP bars, status icons) stay visible in both modes, because hiding them would hide what to dodge. Say if those should go too.

## 2026-11-13 boss-vfx-360
21. Owner rule "Blender renders are the final look": the 2026-11-13 changes (Zoltraak lasers with black mist, the 360 degree portal wall, the 360 degree Enuma sweep) were approved from schematic mock-ups (https://claude.ai/artifact/6LT1q5EMEAPvXo63p3QQP7), not Blender renders. Built in game first; the barrage, gates and enuma Blender sheets are not re-rendered. Choose: re-render those sheets to match, or let the game captures stand as the new target. Item 19 (hip-only sweep) is superseded by design doc 4.37 "Boss effects after playing".
Answered by the owner 2026-11-13 (later): item 21, re-render the barrage, gates and enuma sheets in Blender and approve them before the game is changed (design doc 4.37 "Boss effects after playing").

## 2026-11-19 team-dojo: Team Select night-dojo drafts (review https://claude.ai/artifact/HxHn7rXzL3VSMb7hyADaCJ)
Blocks: d3 (rules and build). Summon is preserved (owner 2026-11-19).
1. Pick draft A (reference 1:1), B (reference + brief: carousel, paper plates, rule altars) or C (A + carousel, gear section, swap preview, rarity chips); plate main or alt and fixes (lantern orange, bluer windows, hall detail).
2. Altars: the reference's dark-wood, gold two-tier altars replace 4.45's pink top / cyan rim / sakura emblem?
3. Relic and Sidekick icons: reference squares or 4.45's diamond and circle?
4. "Team 1" dropdown and pencil: 4.45 says one team, no rename. Decoration, add renaming, or drop?
5. Lv. and Power: no such stats; drafts show cruise. Keep cruise, or a level system as its own feature?
6. Team Bonus: only 4.8's series/preset stamina and cruise. The brief's damage, HP, drop-rate, pity bonuses would be new economy rules.
7. Carousel (picked member rotates to the centre) or fixed order as in the reference?
Answered by the owner 2026-11-20 (approved the Studio captures https://claude.ai/artifact/16AdtJyLjWfV8AUwD2mo4D): item 1, the reference layout (draft A, Makimono) with the Summon parchment scroll look; item 2, the reference's dark lacquer two-tier altars with gold trim and gold-orange rings; item 3, square relic and Sidekick icons as drawn; item 7, the approved captures show the reference's fixed order (slot 1 centre); what the ‹ › arrows do stays open. Items 4, 5 and 6 stay open (design doc 4.45 "Team Select night dojo"); the plaza Team altar's look is a new open question.

## 2026-11-23 w2-cast: World 2 cast drafts
Answered by the owner 2026-11-23 ("approved", from the contact sheets): items 1, 3 and 4 as shown. Still open: names and rarities, 2 (publishing) and 5.
1. Approve, change or drop each of the 42 drafts (sheets `assets/characters_avatar/review/world2_*.png`, list `docs/WORLD2_CAST.md`).
2. Licensing: every draft is an unlicensed reference. Two subagents declined to draw recognisable characters (One Punch; Saw Man and Solo); the orchestrator drew those 14 as private drafts. Publishing waits on your decision; section 5 records that you accept the takedown risk.
3. `dan_hex` Jijo: human form (built) or the Evil Eye form?
4. Are Sidekicks exempt from the block-body rule (`side_acrobat` has slim limbs), and are foot claws allowed on `solo_ant`?
5. `Model.block` in `tools/blender/build_boss_event.py` can turn a block inside out (false mauve shading in portraits). Fix it in the shared file? That would change already approved Sidekicks. New Sidekicks use `tools/blender/sidekick_solid.py` or their own box instead.

## 2026-11-24 w2-cast in game: rules audit of 7c12537 (FAIL), merge blocked on these
Answered by the owner in session 2026-11-24: 1 approved; 2 exactly 9e18 allowed ("at most"); 3 and 4 approved; 5 names and ids final; 6 uploads were meant; 7 use the fixed versions (uploaded, 2 models and 4 images); 8 poses approved. Open: 9 (measure odds resolution).
1. Draft rule, not in the design doc: "A server loads only its own world's character and Sidekick models at start, plus those every world shows; another world's model loads when a player in the server owns it or a rig wears it." Approve as a 4.47 rule?
2. Conflict: 4.47 says "Eternal odds stay under 9e18"; WORLD2_SPEC, CHARACTER_GACHA_SPEC and the code give `punch_void` exactly 9e18. Which holds?
3. Eternal is missing from BAG_AND_AUTOSELL_SPEC Prices (25,000 proposed), the TEAM_AND_STAMINA_SPEC rarity tables (32 s proposed) and the CHARACTER_GACHA_SPEC Rarity row. Approve the numbers?
4. Structural rules not in your words: full cruise for World 2 characters in World 1; starters exempt from x0.1; no Secrets in World 2; shared pity; per-world Index; Daily Day 7 cap at Legendary in World 2 (nothing once all are owned). Approve or change?
5. Names: Yunho, Bange, Ferne, Airah, Solara, Katanah, One Punch, S-Class, Ajin Guild, presets. Ids: `kaiju_`, `punch_`, `solo_`, `saw_katana`, `solo_goliath` are title or character words; ids are permanent after the first real save.
6. Were the 127 uploads what you meant? Their only basis is "until everything is ingame ... I preapprive all decisions".
7. `side_lucky` and `side_acrobat`: use the fixed normals (f822beb)? Needs 2 models and 4 images uploaded.
8. Sidekick attack slices: approve?
9. SUSPECTED, not measured: odds near 1 in 9e18 (and World 1's 5e18) may be finer than Random:NextNumber resolves. A chained-draw fix is on local branch orch/world2/rare-odds-proposal (e64e6b2), not on the merge branch. Measure in Studio first, then decide, World 1 included.

## 2026-11-24 world2-awakening-rewards: review of f25567c and 743d6d8 (open, proposed defaults in place)
Nothing here is decided; the game runs the proposed default named in each item until the owner answers.
1. World 2 Money step: x2 per track (placeholder in place) or x1? Simulation from zero Money, no boosts, at World 2
   Track 1: all 39 World 1 upgrades in 2 wins; rebirth 6 in 1 win, 8 in 7, 10 in 102, 12 in 1,619. At World 2 Track
   10: rebirth 12 in 4 wins, 15 in 203.
2. Awakening stars give no cruise past the 800 cap (the stars join the speed multi before `MAX_CRUISE`; an Eternal at
   rebirth 5 is already past 800, so 31 Copies buy it stamina only; the Backpack says "cruise at max"). Keep, or let
   stars pass the cap?
3. Stars raise boss damage through cruise (boss damage reads the team's cruise). Keep, or leave boss damage out?
4. Upgrade gates read World 2's own `BestTrack`, so tier 3+ upgrade tiles relock in World 2 until its tracks are
   beaten. Keep, or gate on the best of both worlds?
5. Slot 4 has no aura or trail: `MarketConfig.SLOTS` = 3 in the shared save. Add a fourth slot in World 2, or keep 3?
6. `LastBossTeam` is shared; a World 2 team of 4 saved there loses its fourth member in World 1. Keep, or save it per
   world?
7. 11 World 2 hero landmarks fit nowhere on their own ground at the approved scale (largest fitting scale in
   brackets): HQ 0.75, ChainTower 0.20, HeroHQ none, Crater 0.40, School 0.60, OldWoodHouse 0.60, GiantCorpse 0.50,
   DefenseHQ 0.90, Town 0.60, RuinedCastle 0.90, IslandVolcano 0.30. Shrink them, drop them, or widen the junction
   gaps (5,000-stud gaps clear all but push the farthest road out to 27,144 studs)?
8. Confirm the 7 hero moves in `tools/blender/world2/hero_moves.json` (Railgun 2,410 and LairTower 5,620 studs are
   large).

## 2026-11-24 World 2 test coverage gaps (open work, none of it is done)
In the World 2 place the server harness reports these as SKIP with a reason, counted apart from pass and fail
(`TestConfig.World1Only`, `TestConfig.World1TrackTests`). A SKIP is missing coverage, not a pass. Goal `w2-game` says
"the track tests and environment scenarios are green in the World 2 mode": that is not met while these stand.
1. Track tests: `ServerTest/TrackTests` holds the briefs of World 1's ten tracks only. World 2's ten tracks have no
   briefs. A brief states the owner's limits per track (length, width, radius, grade), so they need the owner's numbers
   or approval of numbers taken from `docs/WORLD2_SPEC.md`. Covered today: `runner` runs all ten World 2 tracks,
   `world_layout` places them.
2. `environment`: every check names one of World 1's ten biomes. World 2's biomes are checked offline only
   (`tools/lune/biome_harness.luau`, WORLD=2); there is no Studio scenario for them.
3. `roll_anim`: no longer skipped (e9d7cfad, 2026-11-24): the scenario follows the place's cast. Offline only so far
   (World 1 77/77, World 2 77/77); its Studio run in both places is still owed.
4. Narrowed to World 1 inside scenarios that still run in World 2: `npc` holds enemy names to World 1's cast (World 2's
   enemies are still proposed); `weather` expects event-only characters in World 1 only (World 2 has none specified).

## 2026-11-24 roll_anim in World 2: emphasized roll across worlds (open; the game runs the rule as written)
1. Design doc 4.40 says a roll gets the big popup when it is undiscovered and at least 100 times rarer than the
   "3rd-rarest discovered character", with no world named, and 4.47 keeps discoveries shared. So
   `GachaConfig.IsEmphasized` counts World 1 discoveries in World 2: a player who owns three World 1 Secrets (1 in
   1.6e16 and rarer) has a bar of at least 1 in 1.6e18 there, and only Eternals can get the big popup in World 2. Keep,
   or count only the current world's discoveries in each world? Blocks nothing; the tests hold the rule as written.
2. In the World 2 report the checks `service_roll_new_secret_emphasized` and the auto-roll pause run on the place's
   rarest character, an Eternal (hold 5 s, 4.47), under their old names. Rename them, or leave?

## 2026-11-25 Track 1 and 6 swap, dead kaiju rework (open; nothing merged, exported to the ledger or uploaded)
1. Elven RuinedCastle on Track 1: no legal spot at the approved scale 1.5 so far; it fits at 0.52. Default: not built at
   1.5's rule. Keep it at 0.52, or leave it out? (Audit of cb6d716e: 0.52 without a ruling is a FAIL.)
2. Elven hill Town: no legal spot on Track 1 either (it had none on Track 6). Accept?
3. Devil Hunter HQ on Track 6 fits at scale 1.0 but its box overlaps 11 other-track props. Part of the overlap question.
4. Kaiju site fill: 169 of 185 added props overlap other tracks' draft props (counted before the swap); the kaiju's own
   box overlaps 19 and 25. Cut to the clear ones (about 16, apron bare again) or keep them?
   Answered by the owner 2026-11-25: cut to the clear props; round 5 of the kaiju approved.
5. Kaiju references: `build/world2/refs/KaijuBase` is only on the Mac, the linked wiki refuses automated access; no
   image comparison is done.
6. Kaiju rework, rules audit of 55f74eed (NEEDS OWNER): all 8 frozen SweeperVans moved along the road to stand by the new
   sites. Are the vans part of the reopened site, and do the new spots stand? (Approved round 5 shows them moved, but the
   move was not pointed out to the owner.)
7. The kaiju's own box overlaps 17 and 24 other-track props (against cb6d716e), most of them Track 6's. Leave them, or
   reopen those layouts to remove them?
8. Swap round 2 (39311940), rules audit: "approved turn" is not defined for a re-laid layout. Default: the old draft's turn
   rules. Do more statues (3, was 2) and army Ranks (7, was 4) on Track 1 stand? Two HQs on Track 6 overlap 9 and 3
   other-track props (item 3's "11" is replaced): both, the second only, or neither?
9. Kaiju vans (item 6): 5 of 8 can return to their frozen spots (bb93b6c4 scratch test); 3 would stand inside the kaiju.
   Kaiju overlaps with exempt props counted: 21 and 28 (item 7's 17 and 24 left them out).
10. Swap round 3 (c45275d7): close-up model counts on Track 6's longer road (2.95 times Track 1's): Mansion 95 (48), Apaato
    60 (35), Konbini 65 (16), Retro 2 (1). Accept? Second HQ is now out; the one HQ overlaps 9 other-track props (item 8).
    Track 1 options rendered, not exported: castle at 0.52; statues and Ranks turned to the runner (6 Ranks).
    FarWood and RoofTile are not built on either track. Review page: https://claude.ai/artifact/Ng3id1ML1KNxWoYP1xoZ4E
11. Swap round 4 (2d0d07a9; scores T1 7, T6 7; rules audit: no violations): the four Ranks overlap 6, 1, 1 and 2 (agent-1's
    count; the audit's table lists 1 for the last) other-track props. The finish Rank at (364, 399) stands about 13 studs
    from Track 2's RuinB and nearer Track 2's road than Track 1's. Keep it, or leave it out (the finish goes emptier)?
    Item 8's Rank and statue counts are back to the old 4 and 2; its second HQ is out.
12. Scenery overlap across tracks (the open overlap question, now seen in renders with all ten tracks drawn, 5747dda6
    track01_ElvenPlains/context and track06_DevilTokyo/context): other tracks' scenery fills Track 1's views, and the
    old layouts intersected too. agent-1's mesh test, props of ours touching another track's: old slot 1 154 of 338,
    old slot 6 240 of 652; round 5 Track 1 21 of 255, Track 6 95 of 746 (Track 6 lost 88 props for it). The finish Rank of
    item 11 was inside Track 2's RuinB and is removed. A rule for which track owns which ground is needed first.
    Ruled by the owner 2026-11-25: nearest road owns the ground (WORLD2_SPEC "Ground ownership"); full count first.
13. Ground ownership, details the ruling does not give: the plaza's ground; centre or whole footprint of a prop; heroes
    that fit no spot under the rule (leave out, shrink or move far). Asked with the full count.
14. Swap round 5 (5747dda6) scored T1 6, T6 6 (bar 7) on its own scenery; round 6 waits for the ownership count.
15. Audit of round 5 (NEEDS OWNER, no hard violation): Mound 4 to 0, LowBlock 3 to 1 and item 10's counts are stale (now 63, 49, 57); moved props keep their old turn; the 5% / 15% overlap limits are in no doc. Harness exit 1 on the 10 known unplaced heroes only (ROAD 47/10, TRANSFORM 10684/0, PIN 11/0, 154 warnings), run twice independently.
16. Ground count (docs/proposals/world2_ground_count): (a) base centre moves 12% of props and leaves 107 touching pairs; (b) any footprint point 17% and 0 pairs, but T1 would lose 40 to 65% of its own views. Recommend (a), props touching a neighbour fixed one by one. Which?
17. T6 HQ, T5 Railgun, T7 Nest, T8 LairTower stand on another track's ground and have no legal spot under the rule (all approved heroes). Keep them as exceptions, or leave them out? T4 Hospital would move 1987 studs. Until ruled, round 6 leaves HQ where it is.
18. Kaiju fill after the swap (docs/proposals/kaiju_dry_run): the re-cut keeps 12 props, 9 of them round 5 candidates the swap frees; only 3 of the committed 10 survive. Do freed props come back (12), or may the fill only shrink (3)? The 8 committed site renders match neither. Kaiju overlaps now 25 and 28.

## 2026-11-25 Spawn drafts: world gate, Summon altar, markets and merchants (renders only; nothing in game)
1. Gate: blind re-score B 7.8 (recommended), A 7.0, C 6.8, current 4.3 (bar 7). Pick one? Any pick moves the floating label, B and C need a non-disc touch part, and each needs a locked and an open mesh.
2. Gate spawn view: the Index board and a sky-loop post cover about the right half of every gate, today's included. Move one, or accept? The 1.3x option touches no neighbour but overhangs the floor corner by 6 to 7.4 studs and does not fix it.
3. The approved Rift Shrine rift is a spiral disc; the gate drafts dropped a spiral for design doc section 5. Keep the rift as is?
4. Altar (blind scores A 7.6, B 6.4, C 6.1): all three read poorly from the spawn because the Saitamo pedestal (11.6, 12.5) and a sky-loop post stand on the sightline. Move the pedestal, or accept? A is in a revision round.
5. A reviewer says the orange and black runner model used as a scale dummy (repo model, not the altar) has a red swirl on its back close to a known ninja series emblem. Check it against design doc section 5.
6. Markets and merchants (blind scores A dojo 7.3, B rift shrine 7.5, today's 3.5): which direction, and in which world? WORLD2_SPEC says World 2's services are unchanged from World 1, so B there needs a rule. Merchants at the stalls are new figures and need a design doc line before code. Likeness fixes from the review are in a revision round.
7. Stalls are small from the spawn at today's sizes. Allow bigger ones? The sky-loop leg also hides the Index's middle.
8. Altar A after its revision (f76bf1b5): blind 7.3, spawn view 5 (6.5 with the statue moved 8 studs, rendered as an option). Pick A, and move the statue?
9. Two altar reviewers flag the models in the renders, not the altar: the Mythic in the pictures (side_general) has a moderate likeness to a known ninja series armoured giant, and the dummy runner a red spiral. Check both against design doc section 5.
10. Drafts final state: gate B 7.8, altar A 7.3, markets B 7.25 and A 6.9 blind (A before its last fix pass). On adoption: the stall neon lines, wall screens and the SIDEKICKS header must be re-placed. The altar renders show a World 2 Mythic in a World 1 plaza as a display stand-in. The leaf_hero red swirl is its documented changed mark (CHARACTER_ART_REFERENCES.md:9); the modelled shape was not checked against it. Renders: assets/plaza_draft2/{gate,altar,markets}.
11. Answered by the owner 2026-11-25: gate B, gate A as the boss gate, altar B in World 1 and A in World 2, markets B in both, roster models as merchants. Still open: where the boss gate stands and whether entering it joins the event (proposed: the Bosses panel's Go); which character at which stall; moving the statue or the Index board (items 2, 4, 8).
