# Character gacha: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` sections 3, 4.1, 4.5, 4.8, 5 and 6. Numbers are placeholders unless stated.

## Catalog

- One file per character in `src/shared/Characters/`, auto-loaded by `Shared/CharacterCatalog`.
- `Id` is a permanent save key: never rename or reuse one.
- Fields:

| Field | Meaning |
|---|---|
| `Id` | permanent key (`"kaze_ninja"`) |
| `Name` | display name, tweaked from the source character (design doc section 5) |
| `Rarity` | Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret |
| `Chance` | 1 in N (nil for the catch-all Common) |
| `SpeedMulti` | raw cruise multi, damped by `RaceConfig.CruiseStatMulti` |
| `Stamina` | optional override of the rarity base, seconds (`TEAM_AND_STAMINA_SPEC.md`) |
| `Category` | `Sprinter`, `Balanced` or `Marathoner` (design doc 4.5) |
| `Series` | id of the character's series in `Shared/SeriesCatalog` (design doc 4.8) |
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
permanent save-safe keys like character ids and never contain a real name. Every series has 5 characters spread
over the rarities so a Series bonus is reachable early; each has one preset trio, its anime's famous team.

## Launch cast (proposed, 30 characters in 6 series)

Tweaked names of real anime characters (design doc section 5). Ids never contain the real name. The "Based on" column
is the internal source list; it never ships in the game. Category: S = Sprinter, B = Balanced, M = Marathoner.

| Series (based on) | Character | Based on | Rarity | Cat. | Id |
|---|---|---|---|---|---|
| Narito Shippudon (Naruto) | Sakara | Sakura | Uncommon | B | `leaf_medic` |
| | Kakashe | Kakashi | Rare | B | `leaf_copycat` |
| | Saske | Sasuke | Epic | S | `leaf_avenger` |
| | Narito | Naruto | Legendary | M | `leaf_hero` |
| | Itachy | Itachi | Mythic | S | `leaf_crow` |
| Dragon Bawl Z (Dragon Ball) | Pikolo | Piccolo | Uncommon | M | `db_green` |
| | Gohon | Gohan | Rare | B | `db_scholar` |
| | Freezo | Frieza | Epic | S | `db_tyrant` |
| | Vegata | Vegeta | Legendary | S | `db_prince` |
| | Gokku | Goku | Secret | B | `db_hero` |
| One Peace (One Piece) | Nammi | Nami | Common | B | `sea_navigator` |
| | Sanjy | Sanji | Uncommon | S | `sea_cook` |
| | Zoru | Zoro | Rare | M | `sea_swords` |
| | Aice | Ace | Epic | S | `sea_flame` |
| | Lufy | Luffy | Legendary | M | `sea_captain` |
| Demon Slicer (Demon Slayer) | Inosuki | Inosuke | Uncommon | M | `ds_boar` |
| | Zenitsa | Zenitsu | Rare | S | `ds_thunder` |
| | Nezuka | Nezuko | Epic | B | `ds_sister` |
| | Tanjiru | Tanjiro | Legendary | B | `ds_hero` |
| | Rengoko | Rengoku | Mythic | S | `ds_flame` |
| Jujitsu Kaisan (Jujutsu Kaisen) | Nobora | Nobara | Uncommon | B | `jk_nails` |
| | Megumo | Megumi | Rare | M | `jk_shadows` |
| | Yuuji | Yuji | Epic | S | `jk_vessel` |
| | Sukana | Sukuna | Mythic | S | `jk_king` |
| | Gojio | Gojo | Secret | B | `jk_strongest` |
| My Hero Akademia (My Hero Academia) | Ochaku | Ochaco | Uncommon | M | `mha_float` |
| | Todoroky | Todoroki | Rare | B | `mha_icefire` |
| | Bakugoo | Bakugo | Epic | S | `mha_blast` |
| | Deko | Deku | Legendary | B | `mha_hero` |
| | All Mighty | All Might | Mythic | M | `mha_symbol` |

Counts per rarity: Common 1, Uncommon 6, Rare 6, Epic 6, Legendary 5, Mythic 4, Secret 2.

Preset trios (the anime's famous team):

| Series | Preset | Members |
|---|---|---|
| Narito Shippudon | Team Seven | Narito, Saske, Sakara |
| Dragon Bawl Z | Saiyan Pride | Gokku, Vegata, Gohon |
| One Peace | Straw Crew | Lufy, Zoru, Sanjy |
| Demon Slicer | Kamado Squad | Tanjiru, Zenitsa, Inosuki |
| Jujitsu Kaisan | First Years | Yuuji, Megumo, Nobora |
| My Hero Akademia | Class 1-A | Deko, Bakugoo, Todoroky |

- Art follows design doc section 5 safeguards: in-house models only, no ripped assets, no official logos or audio.

## Art

- R15-compatible rig, anime toon shading, oversized head (chibi 1:3 proportion, placeholder) for readability at speed.
- Each rarity adds detail: Common plain; Epic+ gets an aura particle; Mythic+ a trail and unique run style.
- Pipeline: Blender (Blender MCP) -> FBX -> Studio import -> `CharacterModels`.

## Tests

- `gacha`: rarest-first odds, turbo roll, duplicate adds `Copies`, Index points.
- `catalog`: every id unique and never removed (compare to a committed id list), every field valid, every Series id
  exists, every preset has 3 distinct members of its own series.
