# World 2 cast and Sidekicks

Owner 2026-11-23: design, draw and render every World 2 character and a new Sidekick set; the list is pre-approved
for drafting. Every name, rarity and id is **proposed** until the owner approves the drafts. Rules: design doc 4.47 and
section 5. "Based on" names stay in docs and never ship. Drafts only: no upload, no catalog row, no game code.
Agreed with the World 2 track session 2026-11-23 (enemies as in `WORLD2_SPEC.md` "Tracks", still proposed).

## Already drafted (reuse, no new build)
Saw Man: `saw_hero`, `saw_blood`, `saw_fox`, `saw_nervous`, `saw_bomb`, `saw_control` (also the Track 10 enemy Makina).
Solo Levelup: `solo_monarch`, `solo_blade`, `solo_beast`, `solo_mage`, `solo_goliath`, `solo_vice`.
One Punch: `punch_void` (Eternal).

## New heroes (21)
| Id | Name | Based on | Series | Rarity |
|---|---|---|---|---|
| `punch_rider` | Mumon Rider | Mumen Rider | One Punch | Common |
| `punch_cyborg` | Genus | Genos | One Punch | Rare |
| `punch_speed` | Speedo Sonik | Speed-o'-Sound Sonic | One Punch | Epic |
| `punch_psychic` | Tatsumako | Tatsumaki | One Punch | Legendary |
| `punch_fist` | Bange | Bang | One Punch | Mythic |
| `dan_hex` | Jijo | Jiji | Dandadan | Uncommon |
| `dan_idol` | Airah | Aira | Dandadan | Rare |
| `dan_medium` | Seika | Seiko | Dandadan | Epic |
| `dan_psychic` | Momu | Momo | Dandadan | Legendary |
| `dan_turbo` | Okaron | Okarun, transformed | Dandadan | Mythic |
| `kaiju_ice` | Rino | Reno | Kaiju No. 8 | Uncommon |
| `kaiju_axe` | Kikuru | Kikoru | Kaiju No. 8 | Rare |
| `kaiju_blade` | Hoshena | Hoshina | Kaiju No. 8 | Epic |
| `kaiju_captain` | Mena Ashiru | Mina Ashiro | Kaiju No. 8 | Legendary |
| `kaiju_hero` | Kafko | Kafka, kaiju form | Kaiju No. 8 | Mythic |
| `fr_axe` | Stork | Stark | Frieren | Uncommon |
| `fr_staff` | Ferne | Fern | Frieren | Rare |
| `fr_hero` | Himmal | Himmel | Frieren | Epic |
| `fr_cut` | Ubbel | Übel | Frieren | Legendary |
| `fr_mage` | Frierin | Frieren | Frieren | Mythic |
| `fr_great` | Serye | Serie | Frieren | Eternal |

## New villains (9)
| Id | Name | Based on | World 2 Track |
|---|---|---|---|
| `saw_katana` | Katanah Man | Katana Man, hybrid form | 1 |
| `solo_flame` | Barran | Baran, Demon King | 2 |
| `punch_monster` | Garoo | Garou, half-monster | 3 |
| `dan_granny` | Turbo Grammy | Turbo Granny | 4 |
| `kaiju_nine` | Kaijo No. 9 | Kaiju No. 9 | 5 |
| `fr_scales` | Ora | Aura the Guillotine | 6 |
| `solo_ant` | Berru | Beru, Ant King | 7 |
| `punch_serpent` | Orochy | Orochi | 8 |
| `fr_gold` | Makto | Macht of El Dorado | 9 |

## New Sidekicks (12), pre-approved by the owner's word 2026-11-23, distinct from World 1's set
Same rarity counts as World 1 (3 Common, 2 Rare, 2 Legendary, 3 Mythic, 2 Secret). Numbers follow World 1's row of the same
rarity when they are added to the game (**proposed**).
| Id | Name | Based on | Series | Rarity | Movement |
|---|---|---|---|---|---|
| `side_box` | Mimik | the Mimic chest | Frieren | Common | Walk |
| `side_cat` | Meowee | Meowy, Power's cat | Saw Man | Common | Walk |
| `side_lucky` | Turbo Nyan | Turbo Granny in the lucky cat doll | Dandadan | Common | Walk |
| `side_tiger` | Bakku | Bakko, Mina's white tiger | Kaiju No. 8 | Rare | Walk |
| `side_bird` | Stilla | Stille, the fast bird | Frieren | Rare | Fly |
| `side_hound` | Rovar | Overgrown Rover | One Punch | Legendary | Walk |
| `side_shaman` | Toskar | Tusk, orc shaman shadow | Solo Levelup | Legendary | Walk |
| `side_acrobat` | Acro Silka | Acrobatic Silky | Dandadan | Mythic | Walk |
| `side_brawler` | Kaijo No. 10 | Kaiju No. 10 | Kaiju No. 8 | Mythic | Walk |
| `side_general` | Belleon | Bellion, Grand Marshal | Solo Levelup | Mythic | Walk |
| `side_dragon` | Solara Dragon | Solar Dragon | Frieren | Secret | Fly |
| `side_dark` | Darknez Devill | Darkness Devil | Saw Man | Secret | Fly |

## Draft state: looks APPROVED by the owner 2026-11-23
The owner approved all 42 looks from the contact sheets, the five at 6 included, as shown (so Jijo is the human form, Acro Silka keeps slim limbs and Berru keeps foot claws). Looks are frozen: no edits without the owner's word. Names, rarities, uploads and publishing were not part of this approval.
All 42 new ids have a model, 4 review views, portrait, head and evidence file. Sheets: `assets/characters_avatar/review/world2_{heroes_1,heroes_2,villains,sidekicks,reused}.png`.
Independent review (bar 7/10): 37 pass. Five stalled at 6 and are shown as-is:
- `punch_psychic`: hair curls read as fins, plain dress.
- `punch_serpent`: flat bone jaw covers part of an eye in the portrait, bare lower limbs.
- `saw_katana`: boxy head, head blade thin from the front.
- `kaiju_nine`: blank back of the head, plain limbs (the two discs match the source).
- `side_dark`: repeated skull shape, stick arms.
Faults seen on several: black outline blobs in portraits (a portrait tool behaviour), dark back views.
