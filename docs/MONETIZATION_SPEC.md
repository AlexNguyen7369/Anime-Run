# Monetization

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.35, 4.36 and section 6. Numbers are placeholders unless marked owner.
Replaces `GAMEPASS_SHOP_SPEC` and `SHOP_PURCHASES_SPEC`, which code cited but which were never in this repo.

## Passes

Catalogue: `Shared/MonetizationConfig.Gamepasses`. `GamepassId` 0 keeps a pass visible as "Coming soon". `Id` values are permanent.

| Id | Name | R$ | Effect | Where |
|---|---|---|---|---|
| `vip` | VIP | 499 | Title (hidden while `AutoRacing` or `BossEvent`), +0.10 Money, +0.10 Luck (owner) | `GachaService` bonuses; `Client/VipTitle` |
| `auto_roll_2x` | 2x Auto-Roll | 199 | Interval / 2 | `GachaService.RollInterval` |
| `extra_roll_1` | Extra Roll I | 299 | +1 roll per tick | `GachaService.StartAutoRoll` |
| `extra_roll_2` | Extra Roll II | 599 | +1 more roll per tick | `GachaService.StartAutoRoll` |
| `money_2x` | 2x Money | 249 | x2, multiplied | `GachaService.MoneyMulti` |
| `luck_1` | Lucky | 149 | +1 Luck, added | `GachaService` bonuses |
| `luck_2` | ULTRA Lucky | 299 | +2 Luck, added | `GachaService` bonuses |
| `dojo_master` | Dojo Master | 299 | Workshop boost x1.5 | `GachaService.WorkshopBoost` |
| `deep_stamina` | Deep Stamina | 199 | +0.25 stamina, added | `GachaService` bonuses |
| `inventory` | + Inventory | 199 | +100 bag spaces (owner) | `Shared/BagConfig` |
| `exclusive_runner` | Saitamo | 999 (owner) | Grants `punch_hero` | `PassService` |

## Ownership

- `Server/PassService` asks Roblox at join, retrying a failed lookup, and sets player attribute `Pass_<id>` = true. It listens to `PromptGamePassPurchaseFinished`, so a purchase applies at once.
- A failed lookup never removes a pass and never grants one. It is retried in the background.
- Ownership is never saved. A pass refunded by Roblox ends at the next join.
- The client reads `Pass_<id>` for display only.

## Roll interval

`max(tree interval, MIN_ROLL_INTERVAL) / 2` with 2x Auto-Roll: 1.5 s at no tiers, 1 s at the fastest.

## Extra rolls

- One tick makes 1 + owned extras rolls, stopping early if the bag fills. Each counts for Rolls, Turbo and quests.
- The rarest of the tick plays the roll animation. The others show as a small toast (proposed).
- Every emphasized roll in a tick is still announced to the server.

## Odds disclosure (design doc 6)

- `GachaConfig.Odds(luck)` walks `CharacterCatalog.Rollable()` in the same order as `GachaConfig.Roll`: `P(i) = min(1, luck / Chance) x (1 - P(hit) of every earlier one)`; the catch-all takes the rest.
- A "Details" button on the roll view and the luck Shop cards lists every outcome as a percentage at the player's current luck, and the turbo roll's odds. Percentages are rounded for display so they sum to exactly 100%, with a note saying so.
- The "1 in N" text on Index tiles stays. It is not the exact chance, because the checks run in sequence.

## Restricted players

- `Server/PassService` reads `PolicyService:GetPolicyInfoForPlayerAsync` at join and sets `PaidRandomRestricted`. A failed read counts as restricted until a retry succeeds.
- Restricted players cannot buy Lucky, ULTRA Lucky or luck potions: the button shows a message and never prompts. VIP's Luck part is off for them. Their free rolls are unchanged.
- Server Luck stays unsold until it is built.

## Saitamo

- Catalog id `punch_hero`, display name Saitamo. The real name appears in no display name, id, pass name, icon or asset name (design doc 5). Parody row: `CHARACTER_GACHA_SPEC`.
- `Rollable = false`, built in like the starters, not from `Shared/Characters`. `BaseCruise = 350` (owner), Balanced, Rarity Mythic (proposed).
- Owned as a `GachaData` entry from the first grant. The grant ignores the bag cap. The entry takes 1 space. A refunded pass ends its effects at the next join; the runner stays in the save (shortcut, see `GachaService.GrantExclusive`).
- Pedestal near the spawn, client-only, with a prompt that opens the pass. Drafted in Blender and shown to the owner first (design doc 4.24).

## Going live

- `tools/monetization/create_products.py` creates what is missing, off sale, and records ids in `product_ids.json`. Roblox has no delete for these. Its key needs `developer-product:write` and `game-pass:write`.
- The same script with `--on-sale` puts everything in the ledger on sale. Run it only after the branch is merged and published: an on-sale pass shows on the game's Store page.
- The ledger also holds `boss_spawn` and the 4 `gems_*` products (owner 2026-11-05); their ids go in `MonetizationConfig` on `feature/alex/boss-event`.
- Pass ids go in `MonetizationConfig`. Icons are in-house art only. Saitamo goes on sale only once its model is in.
