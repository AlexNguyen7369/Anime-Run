# Character gacha: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3, 4.1, 5 and 6. Numbers are placeholders unless stated.

## Catalog

- One file per character in `src/shared/Characters/`, auto-loaded by `Shared/CharacterCatalog`.
- `Id` is a permanent save key: never rename or reuse one.
- Fields:

| Field | Meaning |
|---|---|
| `Id` | permanent key (`"kaze_ninja"`) |
| `Name` | display name, original |
| `Rarity` | Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret |
| `Chance` | 1 in N (nil for the catch-all Common) |
| `SpeedMulti` | raw cruise multi, damped by `RaceConfig.CruiseStatMulti` |
| `Stamina` | optional override, seconds (else the rarity default in `TEAM_AND_STAMINA_SPEC.md`) |
| `Archetype` | ninja, swordsman, mage, brawler, idol, mecha pilot, beast-kin, gunslinger, monk, spirit |
| `Model` | name under `ReplicatedStorage.CharacterModels`; nil shows the "?" placeholder |
| `RunStyle` | animation set: `Sprint`, `NinjaRun`, `Glide`, `Float` |

- `starter` is built in: not rollable, not in the Index.

## Rolls

- Same as IVS: free auto-roll every 3 s; rarest-first check `min(1, luck / Chance)`; else the catch-all Common.
- Turbo luck every 10th roll x10; upgrade tiers raise both.
- Bands copied from IVS car odds (1 in N):

| Rarity | Chance band | SpeedMulti band | Count at launch |
|---|---|---|---|
| Common | catch-all | 1.1 | 1 |
| Uncommon | 10 - 200 | 1.25 - 2.2 | 6 |
| Rare | 500 - 13,000 | 2 - 5.25 | 6 |
| Epic | 50,000 - 2.5M | 6 - 16.5 | 6 |
| Legendary | 1e7 - 7.8e8 | 25 - 100 | 5 |
| Mythic | 5e9 - 1e15 | 150 - 425 | 4 |
| Secret | 1.6e16 - 5e18 | 1,000 - 2,800 | 2 |

- Duplicates add `Copies` to the owned entry; no Money.
- Index: discovering a character = owning it; every 3 unique discoveries grant 1 stat point.

## Launch cast (proposed, 30 originals)

Names and looks are original working titles; the owner approves each before art.

| Rarity | Characters (archetype) |
|---|---|
| Common | Rookie Runner (brawler) |
| Uncommon | Kaze the Leaf Ninja (ninja), Hoshi Idol (idol), Tetsu Apprentice (swordsman), Pip Fox-Ear (beast-kin), Mochi Monk (monk), Rin Courier (gunslinger) |
| Rare | Akane Blade (swordsman), Volt Kid (mage), Shiro Wolf (beast-kin), Gear Girl Nami (mecha pilot), Stone Fist Goro (brawler), Lune Bard (idol) |
| Epic | Crimson Ronin (swordsman), Storm Witch Arya (mage), Iron Pilot Rei (mecha pilot), Twin Tails Momo (beast-kin), Shadow Step Ren (ninja), Sky Monk Taro (monk) |
| Legendary | Solar Empress Hikari (spirit), Thunder Ronin Raiden (swordsman), Abyss Mage Kuro (mage), Titan Frame Zero (mecha pilot), Moonfang (beast-kin) |
| Mythic | Starfall Saint (spirit), Void Ninja Yami (ninja), Dragon Heir Ryu (brawler), Chrono Idol Tokiko (idol) |
| Secret | The Last Sun (spirit), Null Blade (swordsman) |

- IP check before each model: no franchise names, hairstyles + outfits + colours that together read as a known
  character, or signature attacks.

## Art

- R15-compatible rig, anime toon shading, oversized head (chibi 1:3 proportion, placeholder) for readability at speed.
- Each rarity adds detail: Common plain; Epic+ gets an aura particle; Mythic+ a trail and unique run style.
- Pipeline: Blender (Blender MCP) -> FBX -> Studio import -> `CharacterModels`.

## Tests

- `gacha`: rarest-first odds, turbo roll, duplicate adds `Copies`, Index points.
- `catalog`: every id unique and never removed (compare to a committed id list), every field valid.
