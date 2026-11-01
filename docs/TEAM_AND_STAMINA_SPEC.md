# Team and stamina: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 4.2-4.8 and 7. Numbers are placeholders unless stated.

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

- Base stamina (seconds of running from 100% to 0%) comes from the character's rarity, unless the catalog entry sets
  its own `Stamina`:

| Rarity | Stamina (s, placeholder) |
|---|---|
| Common | 20 |
| Uncommon | 22 |
| Rare | 24 |
| Epic | 27 |
| Legendary | 30 |
| Mythic | 36 (owner 2026-10-30) |
| Secret | 43 (owner 2026-10-30) |

- Effective stamina, fixed for the whole run when it starts (all multipliers placeholders, in `Shared/StaminaConfig`):

```
Stamina = Base(rarity or override)
        x Category      (Sprinter 0.8, Balanced 1, Marathoner 2.0)
        x (1 + 0.05 x Alloc_Stamina)
        x Potion        (1.5 if a Stamina potion is active at run start, else 1)
        x TeamBonus     (preset 1.4, else Series 1.2, else 1)
```

- Drain per second while running = `100 / Stamina` percent.
- Drain pauses while the run is not moving: loser screen, swap animation (if any), teleports.
- At run start every slot is set to 100%. Stamina is never saved.
- Server state per run: `run.Slot` (1-3), `run.Stamina[slot]` (0-100). Replicated as player attributes
  `RunSlot` and `Stamina1..3` (rounded to 0.1, updated at most 10 times a second).

## Runner categories

- Cruise multi = `CruiseStatMulti(SpeedMulti) x CategorySpeed` (Sprinter 1.25, Balanced 1, Marathoner 0.8): the
  category applies after the IVS damping (owner 2026-10-30), then aura / trail and the total caps
  (`MAX_CRUISE_TOTAL_MULTI`, `MAX_CRUISE`).
- Category is fixed per character (catalog `Category`). The HUD card shows its icon.

## Stamina stat point

- `GachaConfig.STATS` gains `"Stamina"`; `PER_POINT.Stamina = 0.05` (placeholder). Same `AllocateStat` remote,
  validation and save (`StatAlloc.Stamina`) as the other stats.

## Stamina potion

- `BoostConfig` category `Stamina`, item `stamina_potion`: Multiplier 1.5, Duration 900 s (placeholders).
- Active = `BoostUntil_stamina_potion > server time` when a run starts. A potion that expires mid-run does not change
  that run.
- Sources: Shop potion packs (developer products, `ProcessReceipt` idempotent, IVS pattern), daily login, codes.
  The potion status HUD shows it like the other potions.

## Team bonus

- `Shared/SeriesCatalog` lists series and their preset trio (`CHARACTER_GACHA_SPEC.md`).
- Bonus is decided once at run start from the full team:
  - the 3 ids equal a series' `Preset.Members` (any order) -> **Preset**: stamina x1.4, cruise x1.1;
  - else all 3 share one `Series` -> **Series**: stamina x1.2;
  - else none. Teams of 1 or 2 never get a bonus.
- The preset cruise x1.1 multiplies the total cruise multi before `MAX_CRUISE_TOTAL_MULTI` and `MAX_CRUISE` apply.
- Player attribute `TeamBonus` (`"Preset:<seriesId>"`, `"Series:<seriesId>"` or `""`); the team editor shows the
  bonus live while the player builds the team.

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

## Speed (owner 2026-11-01, design doc 4.13; replaces the Speed-stat formula)

- Cruise of the active runner = `RarityBase x CategorySpeed x SpeedMulti`, capped at `MAX_CRUISE` (800).
  RarityBase (proposed): Common 20, Uncommon 30, Rare 45, Epic 90, Legendary 200, Mythic 450, Secret 700.
- SpeedMulti = (1 + 0.02 x Alloc_Speed) x SpeedPotion x Preset(1.1) x slot aura x slot trail (damped
  `ItemCruiseMulti`). Each team slot has its own aura and trail; they scale only that slot.
- Fixed for the whole run at run start (like stamina); no Speed stat, no gain.

## Balance check (placeholders, owner 2026-11-01)

NPC speeds unchanged (`16 x 1.51^(n-1)`: 16, 24, 37, 55, 83, 126, 190, 287, 433, 653). With no multis a Balanced
runner wins up to: Common Track 1, Uncommon Track 2, Rare Track 3, Epic Track 5, Legendary Track 7 (200 > 190),
Mythic Track 9, Secret Track 10 (700 > 653). Sprinters reach about one band further; multis push teams the rest of
the way. Stamina numbers unchanged. Owner retunes after a playtest.

## HUD

- 3 portrait cards beside the Speed number (bottom centre), in slot order. Each card: portrait, rarity border,
  category icon, stamina bar. A Series / Preset badge sits above the cards when a bonus is active. Active card is larger and outlined; empty cards are greyed out.
- Team editor: in the Index / Backpack panel, drag or tap a character into slot 1-3. Disabled during a run.

## Tests (to write first)

- `team_bonus`: preset in any order beats Series; 2-member teams get nothing; preset cruise stays under the cap.
- `team`: `SetTeam` validation (unowned, duplicate, 4 ids, mid-run), save round-trip, fallback to starter.
- `stamina`: drain rate per rarity within 1%; category, stat point, potion and team-bonus multipliers each applied
  once (and a potion expiring mid-run changes nothing); swap at 0 to the next slot; empty slots skipped; exhaustion cashes out
  once; loss in the same tick empties the bank; stamina is 100% on every run start.
