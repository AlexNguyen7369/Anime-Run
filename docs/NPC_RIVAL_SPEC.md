# NPC rival: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3 and 4.4. Same rules as the IVS NPC racer
(`IVS docs/NPC_RACER_SPEC.md`), with anime runners instead of cars.

- One enemy per track, from the anime of that track's biome (design doc 4.25, section 5): `Shared/NpcConfig.Tracks[n]`, its own name (`Label`), colour and `Model`.
- Speed (placeholder): Track 1 = 16 studs/s, x1.51 per later track (Track 10 = 653 studs/s), always below
  `RaceConfig.MAX_CRUISE`.
- NPC rivals have no stamina: they run the whole track at their speed.
- Runs the LEFT lane; the player's runner keeps the right lane.
- Pure maths (`NpcRacer.LanePath`, `Profile`, `PoseAt`): its track time is known when the track starts.
- A race starts every time the player starts a track. The player wins if their runner reaches the finish before the
  NPC's time. A loss plays out to the finish, then the loser screen shows for `LOSE_SCREEN_SECONDS` (3) and the player
  goes back to the start track; the bank is emptied.
- Per player: the NPC exists only in the owner's client; race events go only to the owner. Players pass through each
  other; NPC parts never collide.
- Indicator (owner 2026-11-03, design doc 4.25): `NpcLabel` BillboardGui above the enemy's head, the name over a down
  arrow. No `MaxDistance`, `AlwaysOnTop`, fixed pixel size (340 x 96, placeholder), adorned to the enemy so it follows it;
  never clamped to the screen edge. Only the enemy of the current race exists, so only one indicator shows.
- Enemies (owner-approved 2026-11-03, replaces the 2026-10-28 list; tweaked names; source in brackets, internal only;
  this is part of the parody list of design doc section 5):

| Track | Biome | Enemy | Model |
|---|---|---|---|
| 1 | Leafwind Village | Paine [Pain] | new, to build |
| 2 | Tournament Wasteland | Selle [Cell] | new, to build |
| 3 | Pirate Harbor Isle | Arlon [Arlong] | new, to build |
| 4 | Wisteria Night Mountain | Akazo [Akaza] | new, to build |
| 5 | Burning Cursed City | Jogoh [Jogo] | new, to build |
| 6 | Hero Academy City | Shigaraky [Shigaraki] | new, to build |
| 7 | Shibuyo Underground | Mahitoh [Mahito] | new, to build |
| 8 | Skypeia | Enelu [Enel] | new, to build |
| 9 | Spirit Realm Desert | Ulquiorro [Ulquiorra] | new, to build |
| 10 | Green Alien Planet | Freezo [Frieza] | `db_tyrant` |

## Tests

- `npc`: rival time = path length / speed; loss empties the bank; the NPC exists on one client only; indicator has the
  enemy's name, an arrow, no distance limit and `AlwaysOnTop`.
