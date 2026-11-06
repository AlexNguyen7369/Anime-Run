# Gems and Sidekicks: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.35, 4.36, 4.13, 6 and section 5. Numbers here are **placeholders** unless a design doc rule fixes them.

## Gems
- Track n pays n Gems per win, plus 10 x n on first clear, judged by `BestTrack`. Paid in `RaceService`'s `if win then` branch, next to `rewardTrackWin`.
- Each daily task pays 5 Gems and each weekly task 25, as a field on `QuestConfig` rows, paid by `QuestService`.
- Shown on the HUD as a new element; `RacerHud` is generated.

| Gem pack | Robux |
|---|---|
| 1,000 | 199 |
| 2,500 | 449 |
| 10,000 | 1,499 |
| 30,000 | 3,999 |

The owner creates the 4 developer products and gives their ids. Prices come from the owner's reference image and stay placeholder.

## Paid random item rules (design doc section 6)
- Bought Gems make summons paid random items, so the rules apply to every summon.
- Before any summon, a button labelled **Details** shows every outcome as a percentage summing to 100%. The reference image's "Rates" label is not used, because section 6 names "Info" or "Details".
- `ArePaidRandomItemsRestricted` players cannot buy gem packs and see an error. Tracks and tasks remain their free earnable path to summons.
- Sidekicks stay untradable. No luck and no potion change the odds; only pity does, as below, and Details shows it.

## Summons
- Summon 1x costs 50 Gems; Summon 10x costs 500 and gives 10 independent rolls.
- A new pure roll takes a passed list. `GachaService.Roll` and `GachaService.Luck` are not used, so roll counters, turbo and every luck source stay out.
- Rebirth 2 unlocks the vendor. A saved flag marks the tutorial's one free summon as used. Saves already past rebirth 2 get it too.

| Id | Based on | Name | Rarity | Listed odds | Movement | Run gain | Hit every 1.5 s | Sells for |
|---|---|---|---|---|---|---|---|---|
| `side_chain` | Pochita | Pochito | Common | 24.166% | Walk | +5% stamina | 6 | 2 Gems |
| `side_pig` | Hawk | Hawke | Common | 24.166% | Walk | +5% stamina | 6 | 2 Gems |
| `side_crow` | Kasugai crows | Kasugay | Common | 24.166% | Fly | +5% stamina | 6 | 2 Gems |
| `side_dogs` | Divine Dogs | Gyokan | Rare | 12% | Walk | +12% stamina | 10 | 5 Gems |
| `side_reindeer` | Chopper | Choppa | Rare | 12% | Walk | +12% stamina | 10 | 5 Gems |
| `side_ant` | Beru | Beroo | Legendary | 1% | Walk | +10% cruise, +5% stamina | 22 | 20 Gems |
| `side_reaper` | Ryuk | Ryuuk | Legendary | 1% | Fly | +10% cruise, +5% stamina | 22 | 20 Gems |
| `side_fist` | Star Platinum | Purple Platina | Mythic | 0.5% | Fly | +15% cruise, +10% stamina | 35 | 25 Gems |
| `side_knight` | Igris | Igriz | Mythic | 0.5% | Walk | +15% cruise, +10% stamina | 35 | 25 Gems |
| `side_wyvern` | Kaisel | Kaizel | Mythic | 0.5% | Fly | +15% cruise, +10% stamina | 35 | 25 Gems |
| `side_curse` | Rika | Rikka | Secret | 0.001% | Fly | +20% cruise, +20% stamina | 55 | 30 Gems |
| `side_fox` | Kurama | Kurami | Secret | 0.001% | Walk | +20% cruise, +20% stamina | 55 | 30 Gems |

Owner-confirmed (2026-11-05): the Legendary, Mythic and Secret odds, and the name Purple Platina. Every other name and number in this table is **proposed**.

Boss drop only, never summoned (owner 2026-11-05; rarity, gain, hit and sell values **proposed**):

| Id | Based on | Name | Rarity | Odds | Run gain | Hit every 1.5 s | Sells for |
|---|---|---|---|---|---|---|---|
| `side_raga` | Mahoraga | Big Raga | Secret | 0.001% per eligible player on a defeat | +10% cruise, +10% stamina | 40 | 500 Gems |

## Rotation (owner 2026-11-05)
- Every 30 minutes, from UTC time, every server computes the same rotation from the time slot alone: no store, no messaging. It holds 1 Mythic, 2 Legendaries, 2 Rares, all Commons and 1 hidden Secret.
- The server rolls only against the current rotation, and judges a summon by the slot when it arrives.
- A Sidekick's odds stay as listed. Those out of rotation leave a remainder (1.001% with today's 12), split evenly across Commons (owner-approved 2026-11-05), so the shown odds sum to 100%.
- Details and the page show the rotation and a countdown (**proposed**). The Secret's row reads "Secret: one of Rikka, Kurami, 0.001%": which one is hidden, but each possible outcome is still disclosed, since bought Gems make summons paid random items (section 6). The reveal shows it when it drops.
- A Mythic, Legendary or Rare row with no uploaded model stays out of the rotation.

## Pity (owner 2026-11-05)
- Summon 300 without a Mythic gives the rotation's Mythic. Summon 100 without a Legendary gives one of the rotation's Legendaries. Counts carry across rotations, saved per player. A refused summon moves neither count.
- Owner: a Mythic resets only its own count; if both land on one summon the Mythic wins and the Legendary pays on the next; the free tutorial summon counts; Secrets have no pity and reset nothing. **Proposed:** which Legendary is random.
- Attributes `SidekickPity`, `SidekickLegendaryPity`; config `PityCount`, `LegendaryPityCount`.

## Summon page
Layout ideas from the owner's reference, no copied art. Motion through `Client/UiMotion`.
- Left: 4 gem pack tiles, then **Details** and **Settings** buttons. Settings holds the auto-sell filter: one toggle per rarity, off by default.
- Right: one banner with the Sidekicks' actual 3D models (owner 2026-11-05), names and rarities; Gem balance; Summon 1x and Summon 10x. Summon results show the models too.
- Left out of the reference on purpose: luck potions, VIP, Shiny Hunter, pity bars, extra banners.
- Drawn portraits appear only in the Sidekick index and Bag equip (owner 2026-11-05). `render_portrait.py --blend` renders them.
- Uploaded models and images are listed in the generated `src/shared/SidekickArt.luau`, never in the character registries (`CharacterModelAssets`, `CharacterPortraits`, `CharacterHeads`), so no Sidekick reaches character code.

## Bag and equip
- Backpack gets a Sidekicks tab holding 50 entries. Each summon is one entry, saved in `Sidekicks`. This replaces the earlier copies rule.
- A summon needs free room for everything it would add, after auto-sell. Otherwise it is refused with a clear message, and no Gems are spent.
- Auto-sell applies at summon time. A hand sell lives in the Bag. An equipped Sidekick is never sold.
- Equip is keyed per character, in `CharacterGear`, unlike slot-keyed auras. A character wears one entry; an entry sits on one character.

## Display
- Height is 30-40% of a character: 1.7-2.3 studs. Client-only follower attached to the visible runner. It needs a scale-aware pose, since `RunnerVisual.Pose` breaks on scaled rigs.
- A catalog field `Movement` is `Walk` or `Fly`. `Walk` stays on the ground beside the character. `Fly` hovers around the shoulder with a gentle bob and loops its flap animation. Flying models keep wings as separate named parts.
- The vendor is the sixth service, at the row end z -98.75, about 6 studs in front of Plot 1 (**proposed**, screenshot before committing).

| Sidekick | Follow motion (proposed) | Event attack (proposed) | Effect (proposed) |
|---|---|---|---|
| Pochito | Fast scamper, pull-cord tail bouncing | Revs its head saw and hurls a spinning saw blade | Sparks, orange saw arc, blade spin |
| Kaizel | Flying: hovers around the runner's shoulder, wings flapping | Rears back and breathes a flame burst | Flame stream, embers, heat flash at impact |
| Igriz | Armoured sprint | Sword swing launches a crimson slash wave | Crescent slash, red trail, cut flash at impact |
