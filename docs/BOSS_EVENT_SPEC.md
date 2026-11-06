# Boss events: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.37, 4.36, 4.38, 6 and section 5. Numbers here are **placeholders** unless a design doc rule fixes them.

## Flow
| Time | What happens |
|---|---|
| 0:00 | Popup offers Teleport. Players with no Sidekick see it locked, with a prompt to get one. It shows during duels too, and teleporting leaves the duel. Leaving a run cashes out its bank through the normal stop. |
| 0:00-3:00, plaza | The invite shows for 3 s (owner 2026-11-05), then closes. Until teleporting closes, the Boss button at the very top left reads "Boss (Active)", glows and pulses in size, and teleports on press. |
| 0:00-1:00 | Preparation. Arrivals stand at their lane on the track (**proposed**: no warm-up laps) with the team HUD and a countdown. A player who picks nothing gets the auto-chosen team at 1:00. |
| 1:00 | Big Raga rises from under the track to full height; the HP bar pops in and fills left to right. Rise and intro are 3 s (owner: 2-3 s), no damage either way. Red event header; red chat message to the whole server. Everyone starts running when the intro ends. If nobody is in the arena, the boss still waits for joiners. |
| 1:00-3:00 | Late joining. Teams are auto-chosen, with no team HUD choice. Each joiner sees the red header. HP = 4,000 x players in the arena: a joiner adds 4,000 to both max and current HP. |
| 3:00 | Teleport closes and HP locks. If nobody came, the event ends. |
| To 8:00 | Fight. Defeat ends it early; timeout at 8:00 pays nothing. |
| End | On a defeat, each player with at least 1% of boss HP in damage gets 1 Relic and an independent 0.001% roll for the Big Raga Sidekick (`side_raga`). Everyone returns to spawn. |

- Scheduler: fixed per server, `WeatherService` shape, every 30 minutes. A due time inside an event skips to the next 30-minute mark. A purchase does not move the timer.
- Auto-roll pauses for participants only, through a per-player `BossEvent` attribute gate at `GachaService.StartAutoRoll`; `AutoRoll` itself is never changed. The roll card hides through `refreshToast`.
- `PadTouched` cannot start a race for a player in the event. A death or leave mid-event does not break the player's return. A Leave button (b7c) and a server leave remote take a player back to spawn; a leaver gets no reward (**proposed**).

## Run rules
- Real cruise and real stamina. At all empty: wait 5 s, full team refills, continue.
- Each Big Raga attack's `Impact` costs the running character 5% of a full bar, for every running player, decided by the server from the shared move schedule. A character in the 5 s wait loses nothing (**proposed**). Shout and wheel turn cost no stamina.
- `Roar` starts Shouted: players deal 25% less damage for 5 s (amount **proposed**; the owner set the 5 s). Each `WheelClick` step in a wheel turn starts or refreshes Adapted: Big Raga takes 10% less damage for 5 s (owner 2026-11-05; no stacking is **proposed**). Both are server state from the shared schedule and multiply damage at hit time.
- Boss bar (owner's reference 2026-11-05, layout only, no copied art): boss name above the bar; HP numbers inside it; status icons with seconds under its left side, from a server attribute.
- Drop list under the bar's right side, for players in the event: a "Drop:" heading over a rule, then one row per Relic with its name and percentage, in its rarity's colour, and Big Raga 0.001% in black with a light outline to stay readable.
- Chat (owner 2026-11-05): each Big Raga attack, shout and wheel turn posts a Roblox chat message to players in the event only, from the server's shared schedule. Wording **proposed**: "Big Raga attacks! -5% stamina", "Big Raga shouts! Damage down for 5 s", "Big Raga turns its wheel! It takes 10% less damage for 5 s".
- Exhaustion view (owner 2026-11-05): during the 5 s wait the local camera sits at a front aerial view of the whole ring and boss; the screen dims slightly; a centred panel says the team is exhausted, with a countdown and a loading sign that completes exactly at 5 s, from a server end time. Then the camera returns and the team is revived. Client only.
- Camera: wider event FOV, 100 (**placeholder**), so surrounding players show. Sidekicks stay within their 30-40% size rule (4.36) and read through placement and a soft outline (**proposed**).
- The team hits every 1.5 s for its team damage: the average of its Sidekicks' damage (`SIDEKICK_SPEC`), scaled by Relics, x speed scale. Speed scale (**placeholder**) = 1 + min(1, cruise / 800), from the running character's cruise, so at most +100%. Only the running character's Sidekick draws the attack.

## Team HUD
- Three slots, chosen from the player's characters with a Sidekick; the note reads "Only characters with Sidekicks can be equipped for bosses". Fewer than 3 such characters means fewer slots filled, and the team runs with 1 or 2.
- Shows the live team damage. This team is for the event only; the player's normal Team is not changed.
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
- Closed rail: 7 lane routes built once, distance wraps with no hitch. A boss run mode separates stamina from `npcMode`.

## Boss and attacks
- Built in Blender with named parts, outside `RunnerFactory`: a separate wheel and split upper and lower limbs. Client-side pose data in a `DojoExtras` style loop, moves timed from a server start time.
- Three moves (**proposed**): attack, shout, wheel turn. 4-6 key frames each. The spawn rise comes up through the dais from under the track, reviewed from a Studio capture.
- Owner approved all three moves' key frames 2026-11-05 (`assets/characters_avatar/boss_raga/keyframes/`, data in `keys.json`) and asked for very dynamic motion and VFX that show boss urgency.
- **Owner gate (design doc 4.37):** render key frames as labelled slices, show one move at a time, and revise until approved. Only then fill and bake, leaving approved keys unchanged. Sidekick attacks follow the same gate; effects are approved from a Studio capture.
- Hits are batched from the server. Local attacks draw at full strength, others lighter. Impact is about 0.4 s after the hit. REDUCED EFFECTS keeps a simple shot. Cues go through `UiFeedback`; audio follows section 5 with ledger rows.

## Paid spawn
- 149 Robux developer product, outside `MonetizationConfig.Products`, like `OfflineDouble`. The owner creates it and gives the id. Disabled for the 8 minutes of an event and for a player with no Sidekick.
- A receipt commits a saved `BossCredit`, then starts the event if the server is idle. Otherwise the button reads "Boss ready", to use once inactive. A retry or a second buyer never loses or doubles a paid start.
- A **Details** button shows Relic odds as percentages summing to 100%, plus the separate 0.001% Big Raga Sidekick chance, before purchase. Roblox's page does not cover a paid boss with server-wide drops; this is the cautious reading.
- `ArePaidRandomItemsRestricted` players cannot buy and see an error. The free timed event is their earnable path.

## Saved data
`VERSION` 14 to 16 add `Gems`, `Sidekicks`, `CharacterGear`, `Relics`, `RelicGear`, `BossCredit` and the Sidekick tutorial flag, cleaned to defaults. `/wipe` resets them. Admin commands: `/gems`, `/boss`, `/relic`.

## Analytics
Custom events: invite shown, teleported, defeated or timed out, spawn bought, first summon.
