# Character bag and auto sell

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 3 and 4.36. Numbers are placeholders unless marked owner. Rules: `Shared/BagConfig`; state: `Server/GachaService`.

## Space

- `used` = for each `GachaData` entry, 1 + its `Copies`.
- `cap` = 80 (owner) + 100 with + Inventory (owner) + 50 per owned Inventory tier (owner), 5 tiers: 430 at most.
- Player attributes `BagUsed` and `BagCap`, display only. The server recounts from `GachaData`.

## Full bag

- `used >= cap`: no roll happens. The check comes before `UpgradeService.AdvanceTurbo`, so Turbo progress and `Rolls` do not move.
- `BagFull` attribute is true while full. Rolling resumes by itself once there is space.
- A roll tick with extras stops when the bag fills.
- Grants that are not rolls ignore the cap: starter, pass, daily, code, gift. A save over the cap loses nothing.

## Auto sell

- Saved `AutoSell` (boolean) and `AutoSellChance` (whole number). Missing = off. No `Version` change: both fields are additive.
- `Remotes.SetAutoSell(on, n)`: `n` is a whole number from 1 to 1e18, rate limited, anything else changes nothing. Attributes `AutoSell`, `AutoSellChance`.
- A rolled duplicate is sold when `AutoSell` is on and its `Chance` is at most `n`. It adds no copy and pays `BagConfig.SELL_PRICE[Rarity]`.
- A new discovery is always kept. Characters with no `Chance` are never sold.
- A sold roll still counts for Rolls, Turbo and quests, and still plays.
- The roll remote's fifth value (old `scrapMoney`) carries the sale money; the client shows "+$X".

## Sell spares

- `Remotes.SellSpares(id)` (RemoteFunction): sets that character's `Copies` to 0, pays `Copies x price`, returns ok, message. Rate limited. It works whatever the auto sell setting is.
- Team and Dojo squad characters can be sold down to 1 copy: the last copy is what they use, so neither can lose a member.
- The Backpack card asks for a second tap before selling.
- The save runs as usual; a crash before the next save loses the sale and the Money together, because both are in the same save.

## Prices

Common 5, Uncommon 10, Rare 25, Epic 100, Legendary 500, Mythic 2,500, Secret 10,000. Paid through `MoneyService.Award`, not scaled by Money multis.

## Upgrade tree

Branch `inventory`, Parent `walkspeed_1`, Origin `{ -1, 1 }`, Direction `{ -1, 0 }`, Weight 1, 5 tiers, 50 spaces per tier. All 6 directions off Start are taken, so it forks like Turbo.

## UI

- `Client/RollOptions` holds one Auto Sell popup: an on/off toggle and "1 in [ ]". An AUTO SELL row in Settings and an AUTO SELL button beside AUTO in the roll view open it.
- The Backpack's Characters tab shows `Bag used/cap`. A Sell spares button acts on the chosen character when it has spares.
- While `BagFull` is true: a banner, "BAG FULL: rolling stopped", with SELL SPARES (opens the Backpack) and AUTO SELL (opens the popup).
