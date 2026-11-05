# Relics: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.38, 4.13, 6 and section 5. Stat counts and priorities are the owner's; names, odds and bonuses are **placeholders**.

## Big Raga's drops
| Rarity | Odds | Name (proposed) | Bonuses |
|---|---|---|---|
| Common | 55% | Cursed Talisman | +3% Stamina |
| Rare | 28% | Nobora's Nail | +6% Damage |
| Epic | 12% | Sealing Cube | +10% Stamina, +10% Damage |
| Legendary | 4% | Sukana's Finger | +15% Stamina, +15% Damage, +4% Attack Speed |
| Mythic | 0.9% | Gojio's Sixfold Eyes | +22% Stamina, +22% Damage, +6% Attack Speed, +6% Luck |
| Secret | 0.1% | World Core (universal) | +15% in all 6 stats |

Odds sum to 100%. Luck, potions and pity do not change them. Duplicates stack as copies; one copy on one character.

## Stat rules
- Speed and Stamina apply to the wearing character; Speed stays inside `MAX_CRUISE`.
- Damage and Attack Speed apply to that character's Sidekick.
- Money and Luck count while the character is on the Team, added like the upgrade tree bonus.

## Names and art
Names use existing tweaked forms (section 5), never the official names. Icons are made in-house. Saved as `Relics` and `CharacterGear` (`BOSS_EVENT_SPEC`). Not tradable.
