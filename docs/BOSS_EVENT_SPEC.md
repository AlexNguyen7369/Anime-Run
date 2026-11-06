# Boss events: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.37, 4.36, 4.38, 6 and section 5. Numbers here are **placeholders** unless a design doc rule fixes them.

## Flow
| Time | What happens |
|---|---|
| 0:00 | Popup offers Teleport. Players with no Sidekick see it locked, with a prompt to get one. It shows during duels too, and teleporting leaves the duel. Leaving a run cashes out its bank through the normal stop. |
| 0:00-3:00, plaza | The invite shows for 3 s (owner 2026-11-05), then closes. Until teleporting closes, the Bosses button at the very top left glows and pulses in size. |
| 0:00-1:00 | Preparation. Arrivals stand at their lane on the track with the team HUD and a countdown. Closing the HUD starts the display-only team run (see "Preparation run"). A player with no valid saved team who picks nothing gets the auto-chosen team at 1:00. |
| 1:00 | Big Raga rises from under the track to full height; the HP bar pops in and fills left to right. The rise is 1.5 s (`RiseSeconds`, owner 2026-11-05). The intro, the rise plus the cutscene, is 3 s (`IntroSeconds`, owner 2026-11-05), no damage either way. Red flashing warning text; red chat message to the whole server. Everyone starts running when the intro ends. If nobody is in the arena, the boss still waits for joiners. |
| 1:00-3:00 | Late joining. The team is the saved one, or else auto-chosen, with no team HUD; the run starts at once. Each joiner sees the red header. HP = 7,500 x players in the arena (owner 2026-11-06): a joiner adds 7,500 to both max and current HP. A leaver before teleporting closes removes 7,500 from both, never below 1 current HP (**proposed**). |
| 3:00 | Teleport closes and HP locks, or at Phase 1's defeat if earlier (**proposed**). If nobody came, the event ends. |
| To 8:00 | Phase 1. Its defeat starts Phase 2 (see "Phase 2"); a timeout at 8:00 pays nothing. |
| Phase 2 | Runs to the old end plus the scream plus 2 minutes (owner 2026-11-06), so at most 10:03. |
| End | Everyone returns to spawn with the rewards popup (see "Rewards"). |

- Scheduler: fixed per server, `WeatherService` shape, every 30 minutes. A due time inside an event skips to the next 30-minute mark. A purchase does not move the timer.
- Auto-roll pauses for participants only, through a per-player `BossEvent` attribute gate at `GachaService.StartAutoRoll`; `AutoRoll` itself is never changed. The roll card hides through `refreshToast`.
- `PadTouched` cannot start a race for a player in the event. A death or leave mid-event does not break the player's return. A Leave button (b7c) and a server leave remote take a player back to spawn; a leaver gets no reward (**proposed**).

## Run rules
- Real cruise and real stamina. See "Line run". At all gone: wait 8.5 s, full team refills, continue (owner 2026-11-06).
- Each Big Raga attack's `Impact` costs every character in the line 15% of a full bar in Phase 1 and 30% in Phase 2 (owner 2026-11-06), for every running player the attack hits (see Dodge bar), decided by the server from the shared move schedule. A team in the wait loses nothing (**proposed**). Shout and wheel turn cost no stamina.
- `Roar` adds a Shouted stack on each player it hits: that player deals 25% less damage (amount **proposed**). Each `WheelClick` adds an Adapted stack on each player it hits: Big Raga takes 10% less damage from that player (owner 2026-11-05). A stack lasts 15 s in Phase 1 and 20 s in Phase 2 (owner 2026-11-06), with its own timer. All undodged hits stack (owner 2026-11-06), multiplying per stack (**proposed**): 2 Shouted leave 56% damage. On the current schedule a status overlaps itself only in Phase 2, at most x2. Both are per-player server state from the shared schedule and the player's dodges, and multiply damage at hit time.
- Vulnerable (owner 2026-11-06: 50% more on the next attack): any undodged move sets it, one flag with no stacking, spent by the next undodged `Impact`, which costs 22.5% in Phase 1 and 45% in Phase 2 (**proposed** details). It shows as a status icon.
- Boss bar (owner's reference 2026-11-05, layout only, no copied art): boss name above the bar; HP numbers inside it; status icons with seconds under its left side, from the player's own server attribute, so two players can see different icons.
- Drop list hanging from the bar's bottom-right corner, its right edge on the bar's right edge, for players in the event, appearing after the spawn warning has finished flashing, the warning staying centred with no room reserved for the list (owner 2026-11-05) (rows centre aligned, heavy text with a dark stroke; owner's reference 2026-11-05, layout only): a "Drop:" heading over a shorter rule, then one row per Relic with its name and percentage, in its rarity's colour, and Big Raga 0.001% in black with a light outline to stay readable.
- Chat (owner 2026-11-05): each Big Raga attack, shout and wheel turn posts a Roblox chat message to the players in the event it hits, from the server's shared schedule; a player who dodged gets no line (**proposed**). Wording **proposed**, with the phase's numbers: "Big Raga attacks! -15% stamina", "Big Raga shouts! Damage down for 15 s", "Big Raga turns its wheel! It takes 10% less damage for 15 s".
- Event timer (owner 2026-11-05): `BossTimer`, top left above the bar, counts to the event's end.
- Damage numbers (owner 2026-11-05): pop in with an overshoot, rise with a little sideways drift, fade; text gradient yellow over red.
- Minibar during the wait (owner 2026-11-05): every slot takes the grey exhausted look, and its bar refills from its lower-left end to its full end, reaching full at `BossWaitEndsAt`. Display only; server stamina stays 0 until the refill.
- Exhaustion view (owner 2026-11-05): during the 8.5 s wait the local camera hovers above and outward of the player's own runner, tilted down toward the boss, so the player sees everything from above (owner 2026-11-05); the screen dims slightly; a small panel, centred below the bar and clear of the drop list, says "Exhausted, reviving", with a countdown and a loading sign that completes exactly at the wait's end, from a server end time. Then the camera returns and the team is revived. Client only.
- Camera: wider event FOV, 100 (**placeholder**), so surrounding players show. Sidekicks stay within their 30-40% size rule (4.36) and read through placement and a soft outline (**proposed**).
- The team hits every 1.5 s for its team damage: the average of the Sidekicks' damage of characters still in the line (**proposed**; `SIDEKICK_SPEC`), scaled by Relics, x speed scale. Speed scale (**placeholder**) = 1 + min(1, cruise / 800), from the front character's cruise, so at most +100%. Sidekicks of characters in the line take turns drawing the attack (**proposed**).

## Preparation run and cutscene (owner 2026-11-05)
- Display only: `Client/BossPrepRun` draws it from replicated attributes, on the clients of players in the event; the server's run starts at `IntroSeconds` as before.
- `Remotes.BossEventPrepRun` sets `BossPrepRun` when a player closes the HUD. `BossLane` holds the lane. From then the team runs its lane in line at 60 studs/s (**placeholder**), timed from `BossEventStart`, to reach the lane's start at the spawn. The first is the player's own held runner, re-skinned through `EquippedCar`; the others are client rigs with their Sidekicks.
- Timings after the spawn (**placeholders**): 0-0.4 s jump and turn to face the boss; 0.4-2.2 s red "!" above each head; 3 s the whole line starts running (**proposed** 2026-11-06, replaces the smoke at 2.2 s). A player who never closed the HUD joins in at the spawn. Reduced effects: no jump, fewer puffs.

## Dodge bar
Design doc 4.37 (owner 2026-11-05). Numbers are **placeholders** tuned in `Shared/BossDodge`.

| Item | Value |
|---|---|
| Bar in and out | 0.3 s pop up, just before the sweep starts; 0.3 s disappear (owner 2026-11-06) |
| Sweep | 1.5 s in Phase 1; faster in Phase 2 on every move (owner 2026-11-06), 1.1 s (**proposed**); ending at the move's moment (`Impact`, `Roar`, `WheelClick`). The shortest gap between moments is 3.95 s |
| Spot | Several pixels narrower (owner 2026-11-06): width 12.5% (**proposed**; 80 px on a 640 px bar, was 90), 0.1875 s in Phase 1 and 0.1375 s in Phase 2. Centre at 25% to 69% of the bar in Phase 1 and 25% to 62% in Phase 2, so the window ends at least 0.35 s before the moment; white core, gold edges; different per player and per move, from a seed both sides compute |
| Presses | One per move; a press off the spot counts as the try, and the player is hit at the moment |
| Result text | 1.5 s. Dodged: gold, popping out, with a star burst. Hit: red, flashing (owner 2026-11-06) |
| Lane dash | 0.35 s on every client, with the side dash pose: 3 key frames approved by the owner 2026-11-06 (`assets/characters_avatar/runner_dash/keyframes/dash_keys.jpg`) |
| Stars | 12 UI stars from the text and a burst of `ParticleEmitter` stars on the local runner; none under REDUCED EFFECTS |

- Input: Space or gamepad A, bound only while the bar shows, so it never jumps. On touch the bar itself is the button, and the subtitle says "Tap" (**proposed**; phones have no Space).
- Prompt text: "Press SPACE when the bar hits the white!" (**proposed**).
- No bar for a player in the team wait or without a run, and such a player is not hit by that move (**proposed**).
- Lane: to a free neighbouring lane, at random if both are free; if neither is, the runner shares a neighbour's lane. The lap angle is kept.
- Trust: the client sends the press's server-time stamp, because a 0.21 s window would not survive ping. The server accepts a press only if the stamp is inside the window and no more than 0.5 s old, and the press arrives by the moment. A forged stamp only skips boss effects, which a perfect player also skips (accepted risk).

## Line run (owner 2026-11-06)
- All of a player's team runs at once, in a line behind the held runner, and every character in the line drains at once. A character at 0 vanishes in smoke and stays gone until the team timer ends. The last one gone starts the 8.5 s wait, then all refill.
- The front is the first slot still in the line; the held runner wears that character, and its cruise sets the line's speed (**proposed**). `BossLine` (player attribute, slots in the line) drives the client rigs. `Client/BossLineRun` draws every member's line for everyone in the event (**proposed**), with `BossPrepRun`'s rigs, gap and smoke; fewer puffs under REDUCED EFFECTS.
- A gone slot on the minibar reads tired.

## Phase 2 (owner 2026-11-06)
- First HP 0: Phase 1's rewards are processed at once. Scream of 3 s: no damage and no moves; runs and stamina continue (**proposed**). HP = Phase 1's max + 50,000, the bar filling during the scream. Title "Fully Adapted Raga".
- The scream holds the approved `shout` pose at its Roar peak with a sustained, larger `playRoar` (**proposed**: no new key frames). The owner reviews the effects from a Studio capture.
- The move schedule restarts from its beginning when the scream ends; statuses and Vulnerable clear when the scream starts (**proposed**). Attributes: `BossEventStage`, `BossEventEndsAt`, `BossScreamEndsAt`, `BossScheduleStart`.
- The wheel spins continuously for the whole phase, on top of the baked track.
- Once the bar is full, the drop list's rates change to Phase 2's one row at a time, top to bottom.
- A leave in Phase 2 takes no HP back. Teleport is closed.

## Rewards (owner 2026-11-06)
- Share: at least 5% of the phase's own max HP, from that phase's damage alone (of each phase's own HP **proposed**).
- Phase 1's defeat: Raga's Treasure and 100,000 Money, through `MoneyService.Award`, granted at that moment. Phase 2's defeat: Adapted Raga's Treasure and 1,000 Gems, through `MoneyService.AddGems`. A player who leaves in Phase 2 keeps Phase 1's pay and gets the popup on leaving.
- `Client/BossRewardPopup`, from `RunEvent` kind `BossRewards`, after the return: "Raga Defeated!", total damage, a small reward row. Phase 2 timeout: "Fully Adapted Raga survived" with Phase 1's rewards (**proposed**). Under 5%: the damage and "Deal 5% for rewards" (**proposed**). No popup on a Phase 1 timeout (**proposed**).

## Team HUD
- Three slots, chosen from the player's characters with a Sidekick; the note reads "Only characters with Sidekicks can be equipped for bosses". Fewer than 3 such characters means fewer slots filled, and the team runs with 1 or 2.
- Saved team (owner 2026-11-05): saved `LastBossTeam` (comma ids; additive, no `Version` change) updates on each accepted pick and at the lock. A join starts from its ids still owned and wearing a Sidekick.
- X in the header closes the HUD with at least 1 pick; with none, red text "Select a character first" fades in 1 s. Edit Team, centred above the minibar, reopens it during preparation. Both go at the spawn.
- Shows the average stamina of the team, in seconds, from `BossTeamStamina<n>`.
- Shows the live team damage. This team is for the event only; the player's normal Team is not changed.
- Event roster (owner 2026-11-05): player attribute `BossTeam` (comma ids) holds the auto-chosen team from the join, then the player's pick, then the locked team, and clears on leaving. `BossTeamCruise<n>` and `BossTeamStamina<n>` are its numbers. While in the event the minibar and its hover card read these.
- Team bonus (owner 2026-11-06): in an event it depends on the event team alone: the run's stamina and cruise, and the badge through `BossTeamBonus`. The main Team has no effect on it.
- Auto-chosen team (**proposed**): the 3 characters with a Sidekick whose Sidekick deals the most damage, ties by cruise.

## Arena
| Item | Value |
|---|---|
| Ring | Inner radius 850, width 80, 7 lanes, about 5,600 studs per lap |
| Laps | 800 / 200 / 48 / 24 studs/s: 7 s / 28 s / 2 min / 4 min |
| Boss height | 0.66 x inner radius, about 560 studs to the top of the head; the wheel sits on top of that (owner 2026-11-04), 804 studs in all |
| Camera | Turns inward during the event so the boss stays in view (owner 2026-11-04); angle set from the arena renders |
| Height | y about 1,200, confirmed by a Studio read |

- The owner kept radius 850 after seeing draft renders and measurements (2026-11-04): evenly spaced players are about 4 px at 800 studs, so they mostly read when bunched. Recheck in Studio.
- Diameter exceeds streaming target 1024: arena and boss build on the client; runner rigs need persistent streaming during events.
- `ZoneAt` ignores height, so a new arena zone overrides it, reusing Track 8's cloud profile and particles.
- Low graphics (measured in Studio 2026-11-05): from the lanes, about 890 studs out, a part-built boss does not draw at quality 1 or on this machine's Automatic setting, and does at 8 and 21; at quality 1 it draws at 500. The owner kept radius 850. A flat BillboardGui boss drew at quality 1 from the lanes, so one sits behind the 3D model (**proposed**), playing pre-rendered frames. Check that the model hides it at high quality, and check on a real phone.
- Motes (owner 2026-11-06): small white floating particles in the arena's zone profile, second emitter of `BiomeEnvironment`'s `ARENA`, sharing Snow's reviewed `MoteParticle`; off under REDUCED EFFECTS. Numbers **placeholder**. World-space particles spread out as the camera outruns them, so they read thinner at top cruise.
- Closed rail: 7 lane routes built once, distance wraps with no hitch. A boss run mode separates stamina from `npcMode`.

## Boss and attacks
- Built in Blender with named parts, outside `RunnerFactory`: a separate wheel and split upper and lower limbs. Client-side pose data in a `DojoExtras` style loop, moves timed from a server start time.
- Three moves (**proposed**): attack, shout, wheel turn. 4-6 key frames each. The spawn rise comes up through the dais from under the track, reviewed from a Studio capture.
- Owner approved all three moves' key frames 2026-11-05 (`assets/characters_avatar/boss_raga/keyframes/`, data in `keys.json`) and asked for very dynamic motion and VFX that show boss urgency.
- **Owner gate (design doc 4.37):** render key frames as labelled slices, show one move at a time, and revise until approved. Only then fill and bake, leaving approved keys unchanged. Sidekick attacks follow the same gate; effects are approved from a Studio capture.
- Hits are batched from the server. Local attacks draw at full strength, others lighter. Impact is about 0.4 s after the hit. REDUCED EFFECTS keeps a simple shot. Cues go through `UiFeedback`; audio follows section 5 with ledger rows.

## Paid spawn
- Bosses popup (owner 2026-11-05): the top-left button always reads "Bosses" and toggles a popup, centred on the screen with a header and an X like the other popups (owner 2026-11-06). Teleport open: "Big Raga is raging right now" and Go, locked with the prompt for a player with no Sidekick. Teleport closed during the event: the same line, Go disabled, "Teleporting closed". No event: a short description, Details with the odds, Spawn boss, and "Next event in m:ss" from `BossEventNextAt`, a `ReplicatedStorage` attribute on the same clock as `BossEventStart`. Hidden inside the arena.
- 149 Robux developer product, outside `MonetizationConfig.Products`, like `OfflineDouble`. The owner creates it and gives the id. Disabled for the 8 minutes of an event and for a player with no Sidekick.
- A receipt commits a saved `BossCredit`, then starts the event if the server is idle. Otherwise Spawn boss reads "Spawn boss (ready)", to use once inactive. A retry or a second buyer never loses or doubles a paid start.
- The popup's **Details** section shows both chests' Relic odds as percentages, each table summing to 100%, plus each chest's separate Big Raga Sidekick chance (0.001% and 0.01%), before purchase. Roblox's page does not cover a paid boss with server-wide drops; this is the cautious reading.
- `ArePaidRandomItemsRestricted` players cannot buy and see an error. The free timed event is their earnable path.

## Saved data
`VERSION` 14 to 18 add `Gems`, `Sidekicks`, `CharacterGear`, `Relics`, `RelicGear`, `BossCredit` and the Sidekick tutorial flag, cleaned to defaults. `/wipe` resets them. Admin commands: `/gems`, `/boss`, `/relic`, `/relics` (one of every Relic, owner 2026-11-06).

## Analytics
Custom events: invite shown, teleported, defeated or timed out, spawn bought, first summon.
