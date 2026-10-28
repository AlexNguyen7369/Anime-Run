# Team and stamina: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 4.2, 4.3, 4.4 and 7. Numbers are placeholders unless stated.

## Team

- `Team` is an ordered list of up to 3 owned character ids, saved in `PlayerData` (`Team = { id1, id2, id3 }`).
- New players start with `Team = { "starter" }`.
- Remote `SetTeam(ids)` (client -> server). The server rejects it unless:
  - `ids` is a table of 1-3 strings;
  - every id is owned by the player;
  - no id appears twice;
  - the player is on foot (no run active).
  Rate limit: 1 call per 0.5 s.
- Player attribute `Team` (comma-joined ids) is the replicated truth for the UI.
- On load, ids the player no longer owns are removed; an empty team falls back to `{ "starter" }`.

## Stamina

- `Stamina` (seconds of running from 100% to 0%) comes from the character's rarity, unless the catalog entry sets its
  own value:

| Rarity | Stamina (s, placeholder) |
|---|---|
| Common | 30 |
| Uncommon | 40 |
| Rare | 55 |
| Epic | 75 |
| Legendary | 100 |
| Mythic | 130 |
| Secret | 180 |

- Drain per second while running = `100 / Stamina` percent.
- Drain pauses while the run is not moving: loser screen, swap animation (if any), teleports.
- At run start every slot is set to 100%. Stamina is never saved.
- Server state per run: `run.Slot` (1-3), `run.Stamina[slot]` (0-100). Replicated as player attributes
  `RunSlot` and `Stamina1..3` (rounded to 0.1, updated at most 10 times a second).

## Swap

- When `run.Stamina[run.Slot]` reaches 0, the server moves to the next slot that holds a character.
- The new runner's cruise speed applies at once (the race rail sets speed instantly; no acceleration).
- The race position, track and NPC timer do not change.
- Remote `RunEvent` to the owner: `{ Kind = "Swap", From = id, To = id, Slot = n }`. The client plays a swap VFX and a
  HUD toast ("<Name> TAG IN!").
- The runner model is swapped in place (old model removed, new model at the same CFrame).

## Run end by exhaustion

- When the last slot reaches 0: `run:CashOut()` pays the bank, then the player is sent to the walk spawn.
- `RunEvent { Kind = "Exhausted", Banked = n }` to the owner; the client shows a short "TEAM EXHAUSTED" result with the
  amount banked.
- Exhaustion is not a loss: the bank is paid, and no loser screen shows.
- If the NPC finish time and exhaustion happen in the same tick, the NPC result is decided first (loss wins).

## Speed

- Cruise speed of the active runner = `RaceConfig.SpeedFor(stat, character.SpeedMulti, aura, trail)` (IVS formula).
- Speed-stat gain uses the actual speed, as in IVS. Gain multipliers never come from the character (IVS rule).

## Balance check (placeholders)

Track lengths copied from IVS World 1 (studs) and NPC speeds `16 x 1.51^(n-1)` give NPC times:

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Length | 984 | 1371 | 320 | 1277 | 977 | 1652 | 1807 | 1875 | 1868 | 1890 |
| NPC time (s) | 61 | 57 | 9 | 23 | 12 | 13 | 10 | 7 | 4 | 3 |

- The whole chain at NPC pace takes about 199 s. A player who just beats each NPC needs about that much stamina.
- 3 Commons (90 s) reach mid Track 2. 3 Rares (165 s) reach about Track 4. 3 Legendaries (300 s) clear the chain.
- So stamina gates how far a run goes, and speed gates whether each track is won. Both rise with rarity.
- Owner must confirm or retune after a playtest; numbers live in `Shared/StaminaConfig`.

## HUD

- 3 portrait cards beside the Speed number (bottom centre), in slot order. Each card: portrait, rarity border, stamina
  bar. Active card is larger and outlined; empty cards are greyed out.
- Team editor: in the Index / Backpack panel, drag or tap a character into slot 1-3. Disabled during a run.

## Tests (to write first)

- `team`: `SetTeam` validation (unowned, duplicate, 4 ids, mid-run), save round-trip, fallback to starter.
- `stamina`: drain rate per rarity within 1%; swap at 0 to the next slot; empty slots skipped; exhaustion cashes out
  once; loss in the same tick empties the bank; stamina is 100% on every run start.
