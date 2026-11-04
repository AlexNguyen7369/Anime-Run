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
| `Chance` | 1 in N; every rollable character has a number (owner 2026-11-03); the catch-all Common is 1 |
| `SpeedMulti` | raw cruise multi, damped by `RaceConfig.CruiseStatMulti` |
| `Stamina` | optional override of the rarity base, seconds (`TEAM_AND_STAMINA_SPEC.md`) |
| `Category` | `Sprinter`, `Balanced` or `Marathoner` (design doc 4.5) |
| `Series` | id of the character's series in `Shared/SeriesCatalog` (design doc 4.8) |
| `Archetype` | ninja, swordsman, mage, brawler, idol, mecha pilot, beast-kin, gunslinger, monk, spirit |
| `Model` | name under `ReplicatedStorage.CharacterModels`; nil shows the "?" placeholder |
| `RunStyle` | optional animation set: `Sprint`, `NinjaRun`, `Glide`, `Float`; nil = the default swing. Only `NinjaRun` is built (design doc 4.23) |
| `Event` | optional: `rain`, `night` or `gold`; the character is rollable only during that weather event (IVS `WEATHER_EVENTS_SPEC.md`) |

- `starter` is built in: not rollable, not in the Index, `Balanced`, no Series. Kept for old saves.
- Starter choice (design doc 4.21): built-in `starter_sea` (Ruffy, model `sea_captain`), `starter_leaf` (Karate Kid,
  model `leaf_hero`), `starter_db` (Sayan, model `db_hero`): same rules as `starter`, owned as a `GachaData` entry
  once picked. Player attribute `NeedsStarter` opens the popup; remote `PickStarter` (RemoteFunction, id) is accepted
  once, only from that list.

## Rolls

- Same as IVS: free auto-roll every 3 s; rarest-first check `min(1, luck / Chance)`; else the catch-all Common.
- Turbo luck every 10th roll x10; upgrade tiers raise both.
- Bands copied from IVS car odds (1 in N):

| Rarity | Chance band | SpeedMulti band | Count at launch |
|---|---|---|---|
| Common | 1 (catch-all) | 1.1 | 1 |
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

## Launch cast (owner-approved 2026-10-28, 30 characters in 6 series)

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

Track enemies are part of this parody list; their names and sources are in `docs/NPC_RIVAL_SPEC.md` (design doc section 5, 4.25).

Counts per rarity: Common 1, Uncommon 6, Rare 6, Epic 6, Legendary 5, Mythic 4, Secret 2.

Placeholder `Chance` (1 in N) and `SpeedMulti` per id (within the bands above; tunable):

| Id | Chance | SpeedMulti | Id | Chance | SpeedMulti |
|---|---|---|---|---|---|
| `sea_navigator` | 1 (catch-all) | 1.1 | `db_tyrant` | 50,000 | 6 |
| `leaf_medic` | 10 | 1.25 | `sea_flame` | 120,000 | 8 |
| `db_green` | 20 | 1.4 | `ds_sister` | 300,000 | 10 |
| `sea_cook` | 40 | 1.6 | `jk_vessel` | 700,000 | 12 |
| `ds_boar` | 70 | 1.8 | `mha_blast` | 1,500,000 | 14.5 |
| `jk_nails` | 120 | 2 | `leaf_avenger` | 2,500,000 | 16.5 |
| `mha_float` | 200 | 2.2 | `leaf_hero` | 1e7 | 25 |
| `leaf_copycat` | 500 | 2 | `db_prince` | 5e7 | 45 |
| `db_scholar` | 1,000 | 2.6 | `sea_captain` | 1e8 | 60 |
| `sea_swords` | 2,000 | 3.2 | `ds_hero` | 3e8 | 80 |
| `ds_thunder` | 4,000 | 3.9 | `mha_hero` | 7.8e8 | 100 |
| `jk_shadows` | 8,000 | 4.6 | `leaf_crow` | 5e9 | 150 |
| `mha_icefire` | 13,000 | 5.25 | `ds_flame` | 1e11 | 250 |
| | | | `jk_king` | 1e13 | 350 |
| | | | `mha_symbol` | 1e15 | 425 |
| | | | `db_hero` | 1.6e16 | 1,000 |
| | | | `jk_strongest` | 5e18 | 2,800 |

Event-only characters (owner 2026-11-03: not rollable for now, undiscovered Index tiles; owner 2026-10-28: in scope; names owner-approved 2026-10-28; odds and multis copied from
the IVS event cars). They belong to a series and count toward its Series bonus. Discovery and equipping persist after
the event.

| Id | Character | Based on | Series | Rarity | Cat. | Event | Chance | SpeedMulti |
|---|---|---|---|---|---|---|---|---|
| `ds_water` | Giyo | Giyu Tomioka | Demon Slicer | Epic | M | `rain` | 160,000 | 6 |
| `jk_night` | Toje | Toji | Jujitsu Kaisan | Legendary | S | `night` | 4.3e7 | 8 |
| `sea_gold` | Rojer | Gol D. Roger | One Peace | Legendary | B | `gold` | 6.2e8 | 10 |

Catalog total: 30 regular + 3 event-only = 33 rollable characters, plus the starter.

Preset trios (the anime's famous team):

| Series | Preset | Members |
|---|---|---|
| Narito Shippudon | Team Seven | Narito, Saske, Sakara |
| Dragon Bawl Z | Sayan Pride | Gokku, Vegata, Gohon |
| One Peace | Straw Crew | Lufy, Zoru, Sanjy |
| Demon Slicer | Kamada Squad | Tanjiru, Zenitsa, Inosuki |
| Jujitsu Kaisan | First Years | Yuuji, Megumo, Nobora |
| My Hero Akademia | Class 1-A | Deko, Bakugoo, Todoroky |

- Art follows design doc section 5 safeguards: in-house models only, no ripped assets, no official logos or audio.

## Art

- R15-compatible rig, Roblox avatar proportions and lighting (owner 2026-11-03, design doc 5): blocky body, big mesh hair;
  each character distinctly recognisable as its source. "Target look" below replaces the flat face.
- Each rarity adds detail: Common plain; Epic+ gets an aura particle; Mythic+ a trail and unique run style.
- Pipeline: Blender (Blender MCP) -> FBX -> Studio import -> `CharacterModels`.

### Avatar pipeline (owner 2026-11-03, goal `char-art` a4-a5; replaced the chibi draft pipeline)

- `tools/blender/avatar_base.py` + `build_avatar.py`, run headless:
  `Blender -b --factory-startup --python tools/blender/build_avatar.py -- [<id>...|--sheet]`.
- Body: R15 block proportions (legs 2, torso 2, head 1.3 units; proposed). Same 15 part names.
- Per-character look comes from `tools/blender/avatar_chars/<series>.json`, keyed by `Id`: part colours, eye and mouth
  presets, individually placed hair locks, flat clothing panels, marks, props.
- Budget: at most 12,000 triangles per character including the outline shell (proposed).
- Look of characters not yet redone (design doc 5): inverted-hull ink outline, cel bands painted into the palette texture, auto-drawn fold lines. "Target look" below replaces this.
- Output: `assets/characters_avatar/<id>/review/{front,side,back,three_quarter}.png` and `contact_sheet.png`; the
  `<id>.blend` files are rebuilt on demand and not committed.
- In game: `export_avatar.py` merges the parts into the 6 `RunnerFactory` parts on one palette texture
  (`build/avatar_glb/<id>.glb`); `upload_avatar.py` uploads them as Model assets under the owner's account (ids in
  `tools/blender/avatar_assets.json`, generated `Shared/CharacterModelAssets`). `Server/CharacterModelService` loads
  them into `ReplicatedStorage.CharacterModels/<id>/<part>` at start; `RunnerFactory` clones those, and falls back to
  the placeholder block rig for anything without a model (track enemies until their models land, `starter`, event-only characters).

### Target look (owner 2026-11-03; design doc 5; pilots `sea_captain`, `db_hero`, `leaf_medic`, `leaf_hero`)

- `tools/blender/paint/style3.py`: `big_head(k)` and `finish()` (no ink shell, hard facets) on the `style2.py` kit. Plain block hands.
- A mesh parented to a leg must stay at z <= 2: `avatar_merge.py` mirrors a part's top about its centre for its bounds triangles, so anything higher lands below z 0.
- In game every rig is scaled by `RunnerFactory.SCALE` (0.8, proposed); `PARTS`, `HIP_HEIGHT` and `CharacterModelService` follow it.
- Evidence and validation: `docs/CHARACTER_EVIDENCE_PILOTS.md`.

### Painted textures (owner 2026-11-03, pilot: `sea_captain`, `leaf_hero`, `db_hero`)

- `tools/blender/paint/char_<id>.py` draws each body face in stud/100 units; `python3 tools/blender/paint/atlas.py <id>`
  writes `assets/characters_avatar/<id>/atlas.{svg,png}` (1024 px, rasterised by headless Chrome).
- A character with an atlas builds as 6 plain UV-mapped blocks plus the script's `HAIR`, `PROPS`, `MARKS` and optional
  `model(parts, kit)` bespoke meshes (`tools/blender/avatar_paint.py`). Locks in a `HAIR_COLOURS` colour take painted
  strands from the atlas's Hair strip; other props use cel swatches in its bottom strip.

## Tests

- `gacha`: rarest-first odds, turbo roll, duplicate adds `Copies`, Index points.
- `catalog`: no real name in any id; the test keeps only hashes of the real names, never the names (owner 2026-10-28).
- `catalog` (cont.): every id unique and never removed (compare to a committed id list), every field valid, every Series id
  exists, every preset has 3 distinct members of its own series.
