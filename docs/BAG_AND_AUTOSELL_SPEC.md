# Character bag and auto sell

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 3 and 4.36. Numbers are placeholders unless marked owner. Rules: `Shared/BagConfig`; state: `Server/GachaService`.

## Space

- `used` = for each `GachaData` entry, 1 + its `Copies`.
- `cap` = 80 (owner) + 100 with + Inventory (owner) + 50 per owned Inventory tier (owner), 5 tiers: 430 at most.
- Player attributes `BagUsed` and `BagCap`, display only. The server recounts from `GachaData`.

## Full bag

- `used >= cap`, auto sell off: no roll happens. The check comes before `UpgradeService.AdvanceTurbo`, so Turbo progress and `Rolls` do not move.
- `used >= cap`, auto sell on (owner 2026-11-06): the roll is drawn. Sold: it counts as usual. Rarer than N: it does not happen, `TurboCount` goes back and `Rolls` does not move.
- `BagFull` attribute is true while full. `AutoRoll` never changes and the loop keeps trying at its normal pace; rolling resumes by itself once there is space.
- Each auto-roll tick that ends with the bag full fires the `BagFullHit` remote to that player, whether its roll was blocked or sold.
- A roll tick with extras stops when the bag fills.
- Grants that are not rolls ignore the cap: starter, pass, daily, code, gift. A save over the cap loses nothing.

## Auto sell

- Saved `AutoSell` (boolean) and `AutoSellChance` (whole number). Missing = off. No `Version` change: both fields are additive.
- `Remotes.SetAutoSell(on, n)`: `n` is a whole number from 1 to 1e18, rate limited, anything else changes nothing. Attributes `AutoSell`, `AutoSellChance`.
- A roll is sold when `AutoSell` is on and its `Chance` is at most `n`, a new discovery too (owner 2026-11-06). It adds no copy and pays `BagConfig.SELL_PRICE[Rarity]`. A sold new character stays undiscovered, with no Discoveries progress.
- Copies already held never change. Characters with no `Chance` are never sold.
- A sold roll still counts for Rolls, Turbo and quests, and still plays.
- The roll remote's fifth value (old `scrapMoney`) carries the sale money; the client shows "+$X".

## Sell spares

- `Remotes.SellSpares(id, count)` (RemoteFunction): lowers that character's `Copies` by `count`, a whole number from 1 to `Copies` (nil = all), pays `count x price`, returns ok, message. Rate limited. It works whatever the auto sell setting is.
- `Remotes.SellSparesMany(ids)` (RemoteFunction): the same for all spares of each listed character, in one payment. The list has at most one row per catalog character; a repeat counts once; a character with no spares is passed over; nothing to sell is refused. Rate limited.
- Team and Dojo squad characters can be sold down to 1 copy: the last copy is what they use, so neither can lose a member.
- A sale always goes through a confirmation dialog: the Sell button picks how many, Mass sell shows the total.
- The save runs as usual; a crash before the next save loses the sale and the Money together, because both are in the same save.

## Prices

Common 5, Uncommon 10, Rare 25, Epic 100, Legendary 500, Mythic 2,500, Secret 10,000. Paid through `MoneyService.Award`, not scaled by Money multis.

## Upgrade tree

Branch `inventory`, Parent `walkspeed_1`, Origin `{ -1, 1 }`, Direction `{ -1, 0 }`, Weight 1, 5 tiers, 50 spaces per tier. All 6 directions off Start are taken, so it forks like Turbo.

## UI

- `Client/RollOptions` holds one Auto Sell popup: an on/off toggle and "1 in [ ]". Only the AUTO SELL row in Settings opens it (owner 2026-11-09: the roll view and under-roll buttons are gone).
- A sold roll has no sale UI (owner 2026-11-09): the roll animation plays with no SOLD or +1 COPY badge, the extra rolls' toast leaves it out, and only the Money counter moves.
- The Backpack's Characters tab shows `Bag used/cap`. A Sell button acts on the chosen character when it has spares. A Mass sell button enters select mode: tiles with spares toggle a check mark, tiles with none dim, and a bar offers Select all, Sell and Cancel.
- On each `BagFullHit`: red "BAG FULL" text with no background restarts, fades and is gone at 1 s (owner 2026-11-05). A dark text stroke keeps it readable (**proposed**). There is no fixed banner.
