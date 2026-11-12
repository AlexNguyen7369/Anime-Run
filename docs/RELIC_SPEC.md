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

The table above is Raga's Treasure, Phase 1's chest. Adapted Raga's Treasure, Phase 2's chest (owner 2026-11-06: World Core 0.5%, Big Raga Sidekick 0.01%; the rest **proposed**):

| Rarity | Phase 1 | Phase 2 |
|---|---|---|
| Common | 55% | 38.5% |
| Rare | 28% | 30% |
| Epic | 12% | 20% |
| Legendary | 4% | 8% |
| Mythic | 0.9% | 3% |
| Secret | 0.1% | 0.5% |
| Big Raga Sidekick (separate roll) | 0.001% | 0.01% |

Each table sums to 100%. Luck, potions and pity do not change them. Duplicates stack as copies; one copy on one character.

## The Elf Mage's drops (owner 2026-11-11: names and art approved from `assets/ui/relic_mage_art_sheet.png`; bonuses and odds **placeholder** as Big Raga's)
Priority: attack speed and luck. Chest "Elf Mage's Treasure", id `relic_chest_mage`, paid at her defeat; it also rolls her Sidekick `side_mage` at 0.001% separately (owner 2026-11-11; replaces "no Sidekick roll").

| Rarity | Odds | Id | Name (proposed) | Bonuses |
|---|---|---|---|---|
| Common | 55% | `relic_helmet` | Dwarf's Helmet | +3% Attack Speed |
| Rare | 28% | `relic_bracelet` | Hero's Bracelet | +6% Luck |
| Epic | 12% | `relic_staff` | Elf Staff (the Dodge bar's staff art) | +10% Attack Speed, +10% Luck |
| Legendary | 4% | `relic_flask` | Priest's Flask | +15% Attack Speed, +15% Luck, +4% Damage |
| Mythic | 0.9% | `relic_grimoire` | Master's Grimoire | +22% Attack Speed, +22% Luck, +6% Damage, +6% Money |
| Secret | 0.1% | `relic_world_core` | World Core (universal) | +15% in all 6 stats |

## The Golden King's drops (owner 2026-11-11: names and stat priority from the approved plan; ids, bonuses and odds **placeholder** as Big Raga's; art approved 2026-11-11, ids live)
Priority: damage and money gain. Chest "Golden King's Treasure" (name **proposed**), id `relic_chest_king`, paid at his defeat; Big Raga's Phase 1 table; it also rolls his Sidekick `side_king` at 0.001% separately. Design doc 4.38 and `docs/char_evidence/boss_king.md`.

| Rarity | Odds | Id | Name (proposed) | Bonuses |
|---|---|---|---|---|
| Common | 55% | `relic_coin` | Gold Coin | +3% Damage |
| Rare | 28% | `relic_goblet` | Royal Goblet | +6% Money |
| Epic | 12% | `relic_chain` | Chain of Heaven | +10% Damage, +10% Money |
| Legendary | 4% | `relic_armor` | Golden Armor | +15% Damage, +15% Money, +4% Attack Speed |
| Mythic | 0.9% | `relic_key` | Key of Babylon (the Dodge bar's key art, like Raga's Wheel) | +22% Damage, +22% Money, +6% Attack Speed, +6% Luck |
| Secret | 0.1% | `relic_world_core` | World Core (universal) | +15% in all 6 stats |
| The Golden King Sidekick `side_king` (separate roll) | 0.001% | | | |

## Chests (owner 2026-11-06)
Saved as rows of `Relics`, ids `relic_chest_raga`, `relic_chest_adapted`, `relic_chest_mage` (owner 2026-11-11) and `relic_chest_king` (owner 2026-11-11), in `RelicConfig.Chests`, apart from `Bosses`. A chest is a sealed spin: `Remotes.RelicOpenChest(entry)` removes it and rolls 1 Relic at its table and, separately, its own boss's Sidekick at its chance on the server (owner 2026-11-11, every boss: `relic_chest_raga` -> `side_raga` 0.001%, `relic_chest_adapted` -> `side_raga` 0.01%, `relic_chest_mage` -> `side_mage` 0.001%, `relic_chest_king` -> `side_king` 0.001%; replaces "`relic_chest_mage` has no Sidekick chance"). In code `RelicConfig.Chests[*].SidekickId` and `SidekickChance` replace `RagaSidekickChance` (k7). The Sidekick may overflow the bag, as before.

In the Relics tab a chest shows its art and quantity; its menu offers Open and its odds. No equip, sale or Index tile (**proposed**). Opening uses the 1x summon reveal (`Client/SidekickReveal`), with the chest image still (no shake) and the Relic's drawn art as the result.

## Selling (owner 2026-11-05)
`Remotes.RelicSell(entry)` (RemoteFunction, rate limited) removes the entry and pays Money by rarity through `MoneyService.Award`, not scaled by Money multis, using `BagConfig.SELL_PRICE`: Common 5, Rare 25, Epic 100, Legendary 500, Mythic 2,500, Secret 10,000 (**proposed**). A worn entry is refused. Relics use the Sidekick click menu (`SIDEKICK_SPEC`). The Index has a Relics page (owner 2026-11-05): a tile counts as owned while an entry of that id is in the bag.

## Stat rules
- Speed and Stamina apply to the wearing character; Speed stays inside `MAX_CRUISE`.
- Damage and Attack Speed apply to that character's Sidekick.
- Money and Luck count while the character is on the Team, added like the upgrade tree bonus.

## Names and art
Names use existing tweaked forms (section 5), never the official names. Every Relic and chest has in-house digital art (owner 2026-11-06), from `tools/blender/portrait/draw_relics.py`, shown only after the owner approves it. Saved as `Relics` and `RelicGear` (`BOSS_EVENT_SPEC`). Not tradable.

Raga's Wheel keeps the saved id `relic_cube`, so a Sealing Cube already in a bag becomes Raga's Wheel. Its tile in the Backpack's Relics tab shows the Dodge bar's art, `assets/ui/raga_wheel.png`, drawn by `tools/blender/portrait/draw_raga_wheel.py`.