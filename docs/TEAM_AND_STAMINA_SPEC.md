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
| Common | 13.5 (owner 2026-11-02: about 12-15 s) |
| Uncommon | 15.5 |
| Rare | 18 |
| Epic | 21 |
| Legendary | 24 |
| Mythic | 27 |
| Secret | 30 (owner 2026-11-02) |

- Effective stamina, fixed for the whole run when it starts (all multipliers placeholders, in `Shared/StaminaConfig`):

```
Stamina = Base(rarity or override)
        x Category      (Sprinter 0.9, Balanced 1, Marathoner 1.1; proposed 2026-11-02)
        x (1 + 0.05 x Alloc_Stamina + upgrade tree Stamina bonus)   (tree: +0.10 per tier, owner 2026-11-03)
        x Potion        (the active Stamina potion tier's multi at run start, else 1)
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

## Upgrade tree Stamina branch (owner 2026-11-03)

- `UpgradeConfig.Branches` entry `stamina` (tile ids `stamina_1..5`, permanent save keys), Effect `Stamina`, Weight 1,
  Parent `start`, Direction `{ 1, 0 }` (the free hex), Bonus `0.10` per tier (placeholders). `UpgradeTree.Bonuses`
  returns `Stamina`; it is added inside the stat point part of the formula above.

## Stamina potion

- Orchestrator default 2026-11-03 (owner may change): the Stamina potion follows the other potions' tier pattern
  instead of the single `stamina_potion` below: `BoostConfig` category `Stamina`, items `StaminaI/II/III` (x1.25 /
  x1.5 / x2, 60 s, Money prices like the other potions; ids are save keys). Robux pack `potion_stamina_pack`
  (x5 Stamina Potion III, ProductId 0 until the owner creates it) and the potion bundle include it; daily login day 3
  gives a Stamina potion; code RELEASE adds StaminaII x2. Bottle icon: the Speed bottle until new art exists.
- Original placeholder: `BoostConfig` category `Stamina`, item `stamina_potion`: Multiplier 1.5, Duration 900 s.
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

- When the last slot reaches 0: the per-distance share is paid straight into Money, then the player is sent to the
  walk spawn (owner 2026-11-10: no run bank, pay at each checkpoint).
- `RunEvent { Kind = "Exhausted", Banked = n }` to the owner, `n` the share just paid; the client shows a short "TEAM
  EXHAUSTED" result with that amount (owner 2026-11-10: no run bank, pay at each checkpoint).
- Exhaustion is not a loss: the share is paid, earlier checkpoint payouts stay, and no loser screen shows (owner 2026-11-10: no run bank, pay at each checkpoint).
- Per-distance share (owner 2026-11-01): `PayoutCurve.Cash(n) x covered / length` of the track being run (share
  placeholder 1.0; `covered` clamped 0..length), paid straight into Money with the "Cashed out +$X" notice (owner 2026-11-10: no run bank, pay at each checkpoint).
- If the NPC finish time and exhaustion happen in the same tick, the NPC result is decided first (loss wins).
- Owner 2026-11-03: a loss is decided only when the runner reaches the finish. A team that tires partway down a track
  the NPC has already finished ends by exhaustion (per-distance share paid), not a loss (owner 2026-11-10: no run bank, pay at each checkpoint).
- Each track win pays its payout (x the checkpoint bonus, design doc 4.15) straight into Money as the team crosses
  that track's finish, with `RunEvent { Kind = "CashOut", Amount = n, Track = t }` to the owner for the "Cashed out
  +$X" notice; a loss keeps earlier payouts; Stop, death and leaving pay nothing more (owner 2026-11-10: no run bank, pay at each checkpoint). Replaces the owner
  2026-10-30 run bank (unbanked pot, loss empties it, Stop cashes it out).
- Owner 2026-10-30: a loss reset starts a new run: stamina refills to 100% and the team restarts at slot 1 (on the
  checkpoint track, design doc 4.15).

## Speed (owner 2026-11-01, design doc 4.13)

- Cruise of the active runner = `RarityBase x CategorySpeed x SpeedMulti`, capped at `MAX_CRUISE` (800).
  RarityBase (proposed): Common 24, Uncommon 33, Rare 48, Epic 90, Legendary 200, Mythic 450, Secret 700.
- SpeedMulti = (1 + 0.02 x Alloc_Speed + upgrade tree Speed bonus) x SpeedPotion x Preset(1.1) x slot aura x slot
  trail (damped `ItemCruiseMulti`). Each team slot has its own aura and trail; they scale only that slot.
- Fixed for the whole run at run start (like stamina); no Speed stat, no gain.
- Orchestrator defaults 2026-11-01 (gaps the rules do not cover; owner may change):
  - Speed potion factor = the active potion tier's own multi (BoostConfig: I x1.25, II x1.5, III x2), like the other
    potions; no tier = x1.
  - The runner is the active slot's character (RunSlot); it wears that slot's aura / trail.
    Preset factor wired as `RaceConfig.PRESET_CRUISE`.
  - The Speed Doubler game passes are removed (design doc 4.16). The upgrade tree's `speed` branch is "Speed"
    (owner 2026-11-01): each owned tier adds +10% cruise (placeholder, 5 tiers), added to the stat points' part.
  - No XP (player levels removed owner 2026-11-01, design doc 4.14).
  - Offline Speed credit and its Robux double are off (nothing to credit); the product stays unsold (ProductId 0).
  - The Speed board is removed from the plaza (4.13); its store `LB_Speed_v3` is untouched.
  - The HUD shows the player attribute `Cruise` (studs/s): the run's fixed cruise while racing, else the equipped
    character's cruise now.
- Per-slot aura / trail. Orchestrator defaults 2026-11-01 (gaps the rules do not cover; owner may change):
  - Save `SlotItems = { [1] = { Aura = id?, Trail = id? }, [2] = ..., [3] = ... }` (no store or VERSION bump). A
    save without `SlotItems` moves its old `EquippedAura` / `EquippedTrail` to slot 1; the old keys are kept in the
    record, never read again.
  - Owner 2026-11-04: up to 3 copies of each aura / trail (`MarketConfig.MAX_COPIES`), each at full price. Saved
    `OwnedAuras` / `OwnedTrails` repeat an id once per copy; an old save's single entry is 1 copy. An id sits on as many
    slots as it has copies: equipping it with every copy worn moves it from the lowest other slot wearing it.
  - Cruise and the runner's aura / trail effect use the active slot's items (slot 1 on foot).
  - UI: an owned aura / trail shows three slot buttons (each with that slot's aura / trail); tapping a slot equips the
    item there, tapping the slot that already has it takes it off (Market detail pane and Backpack). The Market keeps
    BUY below 3 copies, and the Market and Backpack show the copy count. On desktop, BUY replaces the description while
    both BUY and the slot buttons show.

## Balance check (placeholders, owner 2026-11-01)

NPC speeds (owner 2026-11-05, `48 x 1.363^(n-1)`: 48, 65, 89, 122, 166, 226, 308, 420, 572, 779). On speed alone, with no
multis, a Balanced runner reaches: Common and Uncommon no track, Rare level with Track 1, Epic Track 3 (90 > 89), Legendary
Track 5, Mythic Track 8, Secret Track 9. Sprinters reach about one band further; multis push teams the rest of
the way. Stamina numbers unchanged. Owner retunes after a playtest.

## HUD

- Team row (owner 2026-11-02): 3 circle portraits in the retired
  Level bar's place (above the TURBO LUCK bar), slot 1-3 left to right, so the team tires left to right. Owner
  2026-11-03: avatar head only, no rarity colour (neutral ring); while running each
  portrait shows its `Stamina<n>` on a thick curved arc along the lower right of the circle (bar colours; the head
  breaks out of the top of a dark circle). Orchestrator default 2026-11-03: a slanted number at the lower left shows that runner's stamina seconds
  left (the run's fixed `RunSeconds<n>` while running, `TeamStamina<n>` on foot); the arc eases per frame and the slots do not shift. Active runner (`RunSlot`): enlarged, pulsing
  gold glow ring and a bobbing gold marker above it; exhausted slot fades to grey with a shrink; tag-in
  pops; Series / Preset badge above the row ("TEAM SEVEN +40% STAMINA"); hover / tap a portrait opens the info card
  (name, category + its speed / stamina effect, cruise studs/s, stamina s; no rarity). On foot all three show normally; an empty slot is a dim empty circle. Display only.
- Team editor (owner 2026-11-02): Backpack Characters tab: tap a character, then a slot button (SlotPicker, the
  aura / trail slot row) to put it on slot 1-3; a character on another slot swaps; its own slot takes it off; gaps
  close up. The single equip (Index, roll toast, /kami) puts a character on slot 1. Disabled during a run.
- Runner stamina bar (owner 2026-11-02): a vertical blue bar fixed to the right of every visible running character
  (BillboardGui, camera-relative offset), filled to the owner's `Stamina<RunSlot>`. Shown only while running.
  Owner 2026-11-03: the fill tweens between server updates (no steps), a pale "just lost" trail follows it down
  after a short delay, colour blue > 50% > amber > 25% > red (placeholders), pulses below 25%, refills with a white
  flash on a tag-in. Orchestrator default 2026-11-03: a
  minimum on-screen size so it stays readable from far away; low pulse, active pulse and marker bob stop under reduced
  motion (design doc 4.20); the bonus badge sits on a dark pill and the info card stays on screen.
- Toasts: "<Name> TAG IN!" on a swap, "TEAM EXHAUSTED +$X" on exhaustion (plain text placeholder).

## Tests (to write first)

- `team_bonus`: preset in any order beats Series; 2-member teams get nothing; preset cruise stays under the cap.
- `team`: `SetTeam` validation (unowned, duplicate, 4 ids, mid-run), save round-trip, fallback to starter.
- `stamina`: drain rate per rarity within 1%; category, stat point, potion and team-bonus multipliers each applied
  once (and a potion expiring mid-run changes nothing); swap at 0 to the next slot; empty slots skipped; exhaustion pays the
  per-distance share once; loss in the same tick pays nothing and keeps earlier payouts (owner 2026-11-10: no run bank, pay at each checkpoint); Money rises at each won
  track's finish by that track's payout; a stop pays nothing; stamina is 100% on every run start.
