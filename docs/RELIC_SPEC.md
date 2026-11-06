# Relics: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.38, 4.13, 6 and section 5. Stat counts and priorities are the owner's; names, odds and bonuses are **placeholders**.

## Big Raga's drops
| Rarity | Odds | Name (proposed) | Bonuses |
|---|---|---|---|
| Common | 55% | Cursed Talisman | +3% Stamina |
| Rare | 28% | Nobora's Nail | +6% Damage |
| Epic | 12% | Raga's Wheel (owner 2026-11-05) | +10% Stamina, +10% Damage |
| Legendary | 4% | Sukana's Finger | +15% Stamina, +15% Damage, +4% Attack Speed |
| Mythic | 0.9% | Gojio's Sixfold Eyes | +22% Stamina, +22% Damage, +6% Attack Speed, +6% Luck |
| Secret | 0.1% | World Core (universal) | +15% in all 6 stats |

Odds sum to 100%. Luck, potions and pity do not change them. Duplicates stack as copies; one copy on one character.

## Selling (owner 2026-11-05)
`Remotes.RelicSell(entry)` (RemoteFunction, rate limited) removes the entry and pays Money by rarity through `MoneyService.Award`, not scaled by Money multis, using `BagConfig.SELL_PRICE`: Common 5, Rare 25, Epic 100, Legendary 500, Mythic 2,500, Secret 10,000 (**proposed**). A worn entry is refused. Relics use the Sidekick click menu (`SIDEKICK_SPEC`). The Index has a Relics page (owner 2026-11-05): a tile counts as owned while an entry of that id is in the bag.

## Stat rules
- Speed and Stamina apply to the wearing character; Speed stays inside `MAX_CRUISE`.
- Damage and Attack Speed apply to that character's Sidekick.
- Money and Luck count while the character is on the Team, added like the upgrade tree bonus.

## Names and art
Names use existing tweaked forms (section 5), never the official names. Icons are made in-house. Saved as `Relics` and `RelicGear` (`BOSS_EVENT_SPEC`). Not tradable.

Raga's Wheel keeps the saved id `relic_cube`, so a Sealing Cube already in a bag becomes Raga's Wheel. Its tile in the Backpack's Relics tab shows the Dodge bar's art, `assets/ui/raga_wheel.png`, drawn by `tools/blender/portrait/draw_raga_wheel.py`. The Index has no Relic page; the Backpack tab is where Relics are drawn.
