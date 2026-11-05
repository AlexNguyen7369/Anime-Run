# NPC rival: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3 and 4.4. Same rules as the IVS NPC racer
(`IVS docs/NPC_RACER_SPEC.md`), with anime runners instead of cars.

- One enemy per track, from the anime of that track's biome (design doc 4.26, section 5): `Shared/NpcConfig.Tracks[n]`, its own name (`Label`), colour and `Model`.
- Speed (placeholder): `NpcConfig.Tracks[n].Speed`, 1k on Track 1 to 500oc on Track 10, shown as a number; real movement is
  45.5 to 653 studs/s, always below `RaceConfig.MAX_CRUISE` (`docs/SPEED_BALANCE_SPEC.md`).
- NPC rivals have no stamina: they run the whole track at their speed.
- Runs the LEFT lane; the player's runner keeps the right lane.
- Pure maths (`NpcRacer.LanePath`, `Profile`, `PoseAt`): its track time is known when the track starts.
- A race starts every time the player starts a track. The player wins if their runner reaches the finish before the
  NPC's time. A loss plays out to the finish, then the loser screen shows for `LOSE_SCREEN_SECONDS` (3) and the player
  goes back to the start track; the tracks already won that run are cashed out and the lost track pays nothing (owner 2026-11-05).
- Per player: the NPC exists only in the owner's client; race events go only to the owner. Players pass through each
  other; NPC parts never collide.
- Indicator (owner 2026-11-03, design doc 4.26): above the enemy's head, the name over a down arrow, in the client's
  `NpcIndicator` ScreenGui (`Client/NpcRacerView`), moved to the head each frame, so it has no distance limit and shows
  through walls and fog. Fixed pixel size (340 x 96, placeholder). Only the enemy of the current race exists, so only one
  indicator shows.
- Edge pointer (owner 2026-11-04, design doc 4.26): while the head is off screen or behind the camera, the indicator hides
  and the `Pointer` frame in `NpcIndicator` shows the name and an arrow aimed at the enemy, on a rectangle inside the screen
  edge that clears the HUD (150 x 84, margins 175 sides, 60 top, 175 bottom; placeholders; pops in on the swap, design doc 4.20). Under the HUD, like the indicator.
- Enemies (owner-approved 2026-11-03, replaces the 2026-10-28 list; tweaked names; source in brackets, internal only;
  this is part of the parody list of design doc section 5):

| Track | Biome | Enemy | Model |
|---|---|---|---|
| 1 | Leafwind Village | Paine [Pain] | `foe_leaf` |
| 2 | Tournament Wasteland | Selle [Cell] | `foe_db` |
| 3 | Pirate Harbor Isle | Arlon [Arlong] | `foe_sea` |
| 4 | Wisteria Night Mountain | Akazo [Akaza] | `foe_ds` |
| 5 | Burning Cursed City | Jogoh [Jogo] | `foe_jk` |
| 6 | Hero Academy City | Shigaraky [Shigaraki] | `foe_mha` |
| 7 | Shibuyo Underground | Mahitoh [Mahito] | `foe_jk2` |
| 8 | Skypeia | Enelu [Enel] | `foe_sea2` |
| 9 | Spirit Realm Desert | Ulquiorro [Ulquiorra] | `foe_soul` |
| 10 | Green Alien Planet | Freezo [Frieza] | `db_tyrant` |

Enemy models are in-house and built in the avatar pipeline (`CHARACTER_GACHA_SPEC.md`). `foe_` ids are model names; rollable catalog characters share them (owner 2026-11-04, design doc 4.32).

Showdown banners and the Defeated Enemies page: design doc 4.28, 4.29. Both use the enemy's `Label` and the drawn portrait of the
character wearing its `Model` (CHARACTER_GACHA_SPEC "Digital art portrait"), or the live model with none; a client display only.

## Tests

- `npc`: rival time = path length / speed; loss empties the bank; the NPC exists on one client only; its rig has no label.
- `ui_billboards`: the indicator has the enemy's name and an arrow and tracks its head; off screen the pointer shows instead,
  stays on screen and aims at the enemy.
