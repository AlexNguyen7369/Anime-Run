# Boss events: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.37, 4.36, 4.38, 6 and section 5. Numbers here are **placeholders** unless a design doc rule fixes them.

## Flow
| Time | What happens |
|---|---|
| 0:00 | Popup offers Teleport. Players with no Sidekick see it locked, with a prompt to get one. Hidden during duels. |
| 0:00-3:00 | Arrivals run warm-up laps with no damage and see a countdown (orchestrator default). Leaving a run cashes out its bank through the normal stop. |
| 3:00 | Teleport closes. If nobody came, the event ends. Big Raga spawns, and the HP bar pops in and fills left to right. Intro is 20 s, inside the 5 minutes. HP locks: 4,000 x players in the arena. |
| To 8:00 | Fight. Defeat ends it early; timeout at 8:00 pays nothing. |
| End | On a defeat, each player with at least 1% of boss HP in damage gets 1 Relic. Everyone returns to spawn. |

- Scheduler: fixed per server, `WeatherService` shape, every 30 minutes. A due time inside an event skips to the next 30-minute mark. A purchase does not move the timer.
- Auto-roll pauses through a `BossEvent` attribute gate at `GachaService.StartAutoRoll`; `AutoRoll` itself is never changed. The roll card hides through `refreshToast`.
- `PadTouched` cannot start a race during an event. A death or leave mid-event does not break the player's return.

## Run rules
- Real cruise and real stamina. At all empty: wait 5 s, full team refills, continue.
- Only the running character's Sidekick hits, every 1.5 s, for its damage (`SIDEKICK_SPEC`), scaled by Relics. Speed does not change damage.

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
- Closed rail: 7 lane routes built once, distance wraps with no hitch. A boss run mode separates stamina from `npcMode`.

## Boss and attacks
- Built in Blender with named parts, outside `RunnerFactory`: a separate wheel and split upper and lower limbs. Client-side pose data in a `DojoExtras` style loop, moves timed from a server start time.
- Three moves (**proposed**): attack, shout, wheel turn. 4-6 key frames each.
- **Owner gate (design doc 4.37):** render key frames as labelled slices, show one move at a time, and revise until approved. Only then fill and bake, leaving approved keys unchanged. Sidekick attacks follow the same gate; effects are approved from a Studio capture.
- Hits are batched from the server. Local attacks draw at full strength, others lighter. Impact is about 0.4 s after the hit. REDUCED EFFECTS keeps a simple shot. Cues go through `UiFeedback`; audio follows section 5 with ledger rows.

## Paid spawn
- 149 Robux developer product, outside `MonetizationConfig.Products`, like `OfflineDouble`. The owner creates it and gives the id. Disabled for the 8 minutes of an event and for a player with no Sidekick.
- A receipt commits a saved `BossCredit`, then starts the event if the server is idle. Otherwise the button reads "Boss ready", to use once inactive. A retry or a second buyer never loses or doubles a paid start.
- A **Details** button shows Relic odds as percentages summing to 100% before purchase. Roblox's page does not cover a paid boss with server-wide drops; this is the cautious reading.
- `ArePaidRandomItemsRestricted` players cannot buy and see an error. The free timed event is their earnable path.

## Saved data
`VERSION` 14 adds `Gems`, `Sidekicks`, `Relics`, `CharacterGear`, `BossCredit` and the Sidekick tutorial flag, cleaned to defaults. `/wipe` resets them. Admin commands: `/gems`, `/boss`, `/relic`.

## Analytics
Custom events: invite shown, teleported, defeated or timed out, spawn bought, first summon.
