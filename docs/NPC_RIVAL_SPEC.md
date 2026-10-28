# NPC rival: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3 and 4.4. Same rules as the IVS NPC racer
(`IVS docs/NPC_RACER_SPEC.md`), with anime runners instead of cars.

- One NPC rival per track: a tweaked-name real anime character (design doc section 5; `Shared/NpcConfig.Tracks[n].Model`), its own name and colour.
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
- Label `RIVAL` over `<Name> · Track n`, `MaxDistance` 200 studs.
- Proposed rivals (tweaked names; source in brackets, internal only): Track 1 Rock Lea [Rock Lee], 2 Krilen [Krillin],
  3 Usopu [Usopp], 4 Akazo [Akaza], 5 Todoh [Todo], 6 Shigaraky [Shigaraki], 7 Majin Buu-u [Majin Buu],
  8 Kizaro [Kizaru], 9 Madera [Madara], 10 Beeros [Beerus].

## Tests

- `npc`: rival time = path length / speed; loss empties the bank; the NPC exists on one client only.
