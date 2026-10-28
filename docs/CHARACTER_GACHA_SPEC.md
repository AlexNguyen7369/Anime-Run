# Character gacha: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3, 4.1, 4.5, 4.8, 5 and 6. Numbers are placeholders unless stated.

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
| `Stamina` | optional override of the rarity base, seconds (`TEAM_AND_STAMINA_SPEC.md`) |
| `Category` | `Sprinter`, `Balanced` or `Marathoner` (design doc 4.5) |
| `Series` | id of the character's original series in `Shared/SeriesCatalog` (design doc 4.8) |
| `Archetype` | ninja, swordsman, mage, brawler, idol, mecha pilot, beast-kin, gunslinger, monk, spirit |
| `Model` | name under `ReplicatedStorage.CharacterModels`; nil shows the "?" placeholder |
| `RunStyle` | animation set: `Sprint`, `NinjaRun`, `Glide`, `Float` |

- `starter` is built in: not rollable, not in the Index, `Balanced`, no Series.

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

## Series and preset teams

`Shared/SeriesCatalog`: one entry per series, `{ Id, Name, Preset = { Name, Members = { id, id, id } } }`. Ids are
permanent save-safe keys like character ids. Every series has 5 characters spread over the rarities so a Series
bonus is reachable early; each has one preset trio.

## Launch cast (proposed, 30 originals in 6 original series)

Names, series and looks are original working titles; the owner approves each before art.
Category: S = Sprinter, B = Balanced, M = Marathoner.

| Series | Characters (rarity, category) | Preset trio |
|---|---|---|
| Leafwind Chronicles (ninja village) | Kaze the Leaf Ninja (Uncommon, S), Pip Fox-Ear (Uncommon, B), Shadow Step Ren (Epic, S), Moonfang (Legendary, M), Void Ninja Yami (Mythic, S) | Leafwind Squad: Kaze, Pip, Ren |
| Blade of Dawn (swordsmen) | Tetsu Apprentice (Uncommon, B), Akane Blade (Rare, S), Crimson Ronin (Epic, B), Thunder Ronin Raiden (Legendary, S), Null Blade (Secret, S) | Dawn Swords: Tetsu, Akane, Crimson Ronin |
| Arcana Academy (mages, idols) | Hoshi Idol (Uncommon, M), Volt Kid (Rare, S), Lune Bard (Rare, M), Storm Witch Arya (Epic, B), Abyss Mage Kuro (Legendary, M) | Academy Trio: Hoshi, Volt Kid, Lune |
| Steel Horizon (mecha pilots) | Rin Courier (Uncommon, S), Gear Girl Nami (Rare, B), Iron Pilot Rei (Epic, S), Titan Frame Zero (Legendary, M), Chrono Idol Tokiko (Mythic, B) | Horizon Crew: Rin, Nami, Rei |
| Fist of the Mountain (brawlers, monks) | Rookie Runner (Common, B), Mochi Monk (Uncommon, M), Stone Fist Goro (Rare, M), Sky Monk Taro (Epic, M), Dragon Heir Ryu (Mythic, S) | Mountain Dojo: Rookie, Mochi, Goro |
| Celestial Requiem (spirits, beast-kin) | Shiro Wolf (Rare, S), Twin Tails Momo (Epic, B), Solar Empress Hikari (Legendary, B), Starfall Saint (Mythic, M), The Last Sun (Secret, B) | Celestial Court: Hikari, Starfall Saint, The Last Sun |

Counts per rarity: Common 1, Uncommon 6, Rare 6, Epic 6, Legendary 5, Mythic 4, Secret 2.

- IP check before each model and series: no franchise names, hairstyles + outfits + colours that together read as a
  known character, signature attacks, or a series premise copied from a real anime.

## Art

- R15-compatible rig, anime toon shading, oversized head (chibi 1:3 proportion, placeholder) for readability at speed.
- Each rarity adds detail: Common plain; Epic+ gets an aura particle; Mythic+ a trail and unique run style.
- Pipeline: Blender (Blender MCP) -> FBX -> Studio import -> `CharacterModels`.

## Tests

- `gacha`: rarest-first odds, turbo roll, duplicate adds `Copies`, Index points.
- `catalog`: every id unique and never removed (compare to a committed id list), every field valid, every Series id
  exists, every preset has 3 distinct members of its own series.
