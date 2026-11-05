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
- Sidekicks stay untradable. Nothing changes the displayed odds: no luck, no potion, no pity.

## Summons
- Summon 1x costs 50 Gems; Summon 10x costs 500 and gives 10 independent rolls.
- A new pure roll takes a passed list. `GachaService.Roll` and `GachaService.Luck` are not used, so roll counters, turbo and every luck source stay out.
- Rebirth 2 unlocks the vendor. A saved flag marks the tutorial's one free summon as used. Saves already past rebirth 2 get it too.

| Id | Based on | Proposed name | Rarity (proposed) | Odds | Run gain | Hit every 1.5 s | Sells for |
|---|---|---|---|---|---|---|---|
| `side_chain` | Pochita | Pochito | Rare | 60% | +12% stamina | 10 | 5 Gems |
| `side_wyvern` | Kaisel | Kaizel | Epic | 30% | +8% cruise | 14 | 10 Gems |
| `side_knight` | Igris | Igriz | Legendary | 10% | +3% cruise, +3% stamina | 22 | 20 Gems |

## Summon page
Layout ideas from the owner's reference, no copied art. Motion through `Client/UiMotion`.
- Left: 4 gem pack tiles, then **Details** and **Settings** buttons. Settings holds the auto-sell filter: one toggle per rarity, off by default.
- Right: one banner with the Sidekicks' drawn art, names and rarities; Gem balance; Summon 1x and Summon 10x.
- Left out of the reference on purpose: luck potions, VIP, Shiny Hunter, pity bars, extra banners, banner timer.
- Sidekicks need drawn portraits (owner's UI rule). `render_portrait.py` needs a `Head` mesh, so the non-humanoids need checking.

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
