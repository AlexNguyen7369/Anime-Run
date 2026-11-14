# Gems and Sidekicks: design spec

## Summon presentation (owner 2026-11-12)

Owner update 2026-11-14: replace the galaxy environment with the approved blossom-shrine hybrid presentation. A generated clean background preserves the approved pavilion, carved stone shrine, pink crystal, cherry trees and mountains; a real local 3D stage, foreground props and character models sit in front. Petals animate only behind the characters. Keep restrained camera movement so the image and geometry stay aligned. Existing character poses, individual auras, labels, purchases, costs, odds, pity and server authority remain unchanged. Activate the hybrid only after its image asset is registered and verify it in Studio; the old presentation remains available until then.

- Full-screen galaxy stage with actual posed, bobbing character models. Igriz is the featured Mythic; existing summon costs, odds, pity, unlocks and server authority stay in place.
- Every summonable catalog Sidekick has its own collected aura composition and character palette, from Anime auras pack 18515382827. Beroo uses blue lightning, Ryuuk white spectral wisps, and Igriz crimson flame. Other templates vary source presets, accent layers, masks, rates and colors.
- Larger character framing, names centered on side models, a continuous galaxy backdrop, stronger smooth mouse panning, and softer character lighting. Closing restores camera, movement and lighting and removes the local stage.
- Native screen and stage/templates are mapped separately in default.project.json, preserving them through Rojo sync.
- The galaxy screen as built is the rule (owner 2026-11-12, "rules follow the new screen"; replaces the lines below where they differ): the stage shows three featured units (two Legendaries and the Mythic Igriz in the centre) with no Rares and no rates under them; the odds button reads "Show Chances" and opens a text dialog of the outcomes (no silhouette row, no exact-100% rounding required; the odds are still shown before any summon); the banner may show the Mythic's drawn portrait; More Gems shows two packs and a "More" dialog, no badges; the summon buttons read "Once" and "Many". Older lines on Details, the Secret silhouette, the four-pack column with "+N% More!" badges and "Summon 1x / 10x" labels are superseded for this screen.
- Tutorial on the galaxy screen (owner 2026-11-12): step 1 spotlights the tutorial card's own open button (the galaxy look stays on the summon page only, design doc 4.36), step 2 the screen's free-summon button, the result plays with the tutorial waiting, then the tutorial closes the summon screen itself and spotlights the Items tile with the equip text.
- Tutorial and tests follow the galaxy screen (owner 2026-11-12): the rebirth-2 free-summon spotlight tutorial (design doc 4.36, 4.21 style) is rewritten to point at the galaxy screen's own open button, summon button and the result, then at equipping the new Sidekick; its steps, texts and the one free summon stay as the design doc fixes them. The Sidekick UI tests check the galaxy screen's real elements.

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

The monetization session creates the 4 developer products and gives their ids (owner 2026-11-05). Prices come from the owner's reference image and stay placeholder.

## Paid random item rules (design doc section 6)
- Bought Gems make summons paid random items, so the rules apply to every summon.
- Before any summon, a button labelled **Details** shows every outcome as a percentage summing to 100%. The reference image's "Rates" label is not used, because section 6 names "Info" or "Details".
- `ArePaidRandomItemsRestricted` players cannot buy gem packs and see an error. Tracks and tasks remain their free earnable path to summons.
- Sidekicks stay untradable. No luck and no potion change the odds; only pity does, as below, and Details shows it.

## Summons
- Summon 1x costs 50 Gems; Summon 10x costs 500 and gives 10 independent rolls. VIP pays 45 and 450 (owner 2026-11-05: 10% off).
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
| `side_raga` | Mahoraga | Big Raga | Secret | 0.001% from Raga's Treasure, 0.01% from Adapted Raga's Treasure, a separate roll when a chest opens | +10% cruise, +10% stamina | 40 | 30 Gems |
| `side_mage` | Frieren | The Elf Mage | Secret | 0.001% from Elf Mage's Treasure, a separate roll when a chest opens (owner 2026-11-11) | +10% cruise, +10% stamina (**proposed**, as `side_raga`) | 40 (**proposed**) | 30 Gems (**proposed**) |
| `side_king` | Gilgamesh | The Golden King | Secret | 0.001% from Golden King's Treasure, a separate roll when a chest opens (owner 2026-11-11) | +10% cruise, +10% stamina (**proposed**, as `side_raga`) | 40 (**proposed**) | 30 Gems (**proposed**) |

Every boss drops its own downsized Sidekick this way (owner 2026-11-11, design doc 4.36 Boss Sidekicks; `SidekickConfig.BossDrops` holds all three). Evidence: `docs/char_evidence/side_raga.md`, `side_mage.md`, `side_king.md`. Their names are their bosses' titles, so only the tweaked title appears (section 5).

## Rotation (owner 2026-11-05)
- Every 30 minutes, from UTC time, every server computes the same rotation from the time slot alone: no store, no messaging. It holds 1 Mythic, 2 Legendaries, 2 Rares, all Commons and 1 Secret.
- The server rolls only against the current rotation, and judges a summon by the slot when it arrives.
- A Sidekick's odds stay as listed. Those out of rotation leave a remainder (1.001% with today's 12), split evenly across Commons (owner-approved 2026-11-05), so the shown odds sum to 100%.
- Details and the page show the rotation and a countdown (owner 2026-11-05). The Secret's row shows the rotation's Secret as a black silhouette with "Secret, 0.001%"; the reveal names it when it drops.
- The Secret's id reaches clients, for that silhouette (owner 2026-11-05).
- A Mythic, Legendary or Rare row with no uploaded model stays out of the rotation.

## Pity (owner 2026-11-05)
- Summon 300 without a Mythic gives the rotation's Mythic. Summon 100 without a Legendary gives one of the rotation's Legendaries. Counts carry across rotations, saved per player. A refused summon moves neither count.
- Owner: a Mythic resets only its own count; if both land on one summon the Mythic wins and the Legendary pays on the next; the free tutorial summon counts; Secrets have no pity and reset nothing. **Proposed:** which Legendary is random.
- Attributes `SidekickPity`, `SidekickLegendaryPity`; config `PityCount`, `LegendaryPityCount`.

## Summon altar (owner 2026-11-10, design doc 4.36)
- Replaces the Sidekicks stall. Its prompt opens this summon page; nothing else about summons changes.
- The top shows the current rotation's Mythic as its actual 3D model, turning slowly; it swaps on each 30-minute rotation. The client reads the rotation the summon page already gets. Turn speed and model size are **placeholders**.
- **Proposed**: three stone tiers about 32 studs across, a glowing ring and a halo around the model, a "SIDEKICKS" header like the economy wing's, a locked "Rebirth 2" look before the vendor unlocks. Plaza position: the showpiece ring at (57.2, 61.6), facing the spawn (`docs/WORLD_REDESIGN_SPEC.md` section 4, design doc 4.43; was the summon wing's middle (26.8, 40.6)).

## Summon page
Layout ideas from the owner's reference (redesign 2026-11-05), no copied art. Motion through `Client/UiMotion`. This look stays on this page; moving it elsewhere needs the owner's approval.
- Top: Gem balance, a timer bar counting to the next rotation, and Mythic Pity and Legendary Pity with their counts.
- Poster: one view with the Mythic's actual 3D model large in the centre, the Legendaries beside it and the Rares at the ends. Big names in front, each with its rarity and rate (owner 2026-11-05), and a FEATURED sticker that makes no odds claim. Tapping it, or its **Details** button, opens Details.
- Details also shows the Secret: only this rotation's one Secret, as a blacked-out silhouette, with "Secret" and its chance and no name column (owner 2026-11-05). Details lists rates only, no stats. `SidekickRotation` publishes the live `SecretId`; the owner accepts that clients can read it.
- Commons appear only in Details.
- Below: **Auto-Sell** (one toggle per rarity, off by default), Summon 1x and Summon 10x. The cost shows large above them.
- More Gems column: Small, Medium, Large and Huge, biggest first. A "+N% More!" badge is calculated from the listed prices against the smallest pack and rounded down.
- A blur covers the world while the page is open.
- Left out of the reference on purpose: luck potions, Shiny Hunter, rate up, extra banners.
- Drawn portraits appear only in the Sidekick index and Bag equip (owner 2026-11-05). `render_portrait.py --blend` renders them.
- Uploaded models and images are listed in the generated `src/shared/SidekickArt.luau`, never in the character registries (`CharacterModelAssets`, `CharacterPortraits`, `CharacterHeads`), so no Sidekick reaches character code.

## Summon reveal (owner 2026-11-05)
In the style common to anime tower defense games: all effects original, no copied art or sound. `Client/SidekickReveal`, above the roll view; the summon page steps aside while it plays. It plays over the game world and never covers the whole screen. Timings and sizes are **placeholders**. A click skips to the end. Reduced effects start at the end. Results show the actual models.
- Summon 1x: a vortex winds up with sparks pouring in and a growing shake, and turns the rarity's colour partway; it collapses and hits with a flash, comic burst, shock rings and sparks. The model pops in, about 56% of screen height, on turning rays with rising glints. Below it: name, a divider, rarity.
- Summon 10x: 10 cards drop in and flip one by one with rings and sparks. A Legendary, Mythic or Secret card first trembles and glows its colour. A Mythic or Secret then interrupts with the 1x showcase.
- End: "(Click anywhere to continue)". No buttons.

## Bag and equip
- Backpack gets a Sidekicks tab holding 50 entries. Each summon is one entry, saved in `Sidekicks`. This replaces the earlier copies rule.
- A summon needs free room for everything it would add, after auto-sell. Otherwise it is refused with a clear message, and no Gems are spent.
- Auto-sell applies at summon time, except to the free summon, which is always kept (**proposed**, so a player cannot lose the Sidekick that unlocks events). A hand sell lives in the click menu, in the Bag and the Index. An equipped Sidekick is never sold.
- Equip is keyed per character, in `CharacterGear`, unlike slot-keyed auras. A character wears one entry; an entry sits on one character.
- Click menu (owner 2026-11-05), `Client/ItemMenu`, shared with Relics: a tile click in the Bag or Index opens Equip and Sell, or Take off with Sell disabled when worn. Equip opens a grid of owned characters with their drawn portraits, each marked with what it wears; choosing an occupied character replaces its item. Sell shows "Are you sure you want to sell X for Y?" with Sell and Cancel. An Index tile acts on that id's first unworn entry, else its first worn one (**proposed**).

## Display
- Height is 30-40% of a character: 1.7-2.3 studs. Client-only follower attached to the visible runner. It needs a scale-aware pose, since `RunnerVisual.Pose` breaks on scaled rigs.
- A catalog field `Movement` is `Walk` or `Fly`. `Walk` stays on the ground beside the character. `Fly` hovers around the shoulder with a gentle bob and loops its flap animation. Flying models keep wings as separate named parts.
- The vendor is the summon altar on the plaza ring (section "Summon altar"; owner 2026-11-10, replacing the stall at the row end z -98.75).

| Sidekick | Follow motion (proposed) | Event attack (proposed) | Effect (proposed) |
|---|---|---|---|
| Pochito | Fast scamper, pull-cord tail bouncing | Revs its head saw and hurls a spinning saw blade | Sparks, orange saw arc, blade spin |
| Kaizel | Flying: hovers around the runner's shoulder, wings flapping | Rears back and breathes a flame burst | Flame stream, embers, heat flash at impact |
| Igriz | Armoured sprint | Sword swing launches a crimson slash wave | Crescent slash, red trail, cut flash at impact |
| The Elf Mage (`side_mage`, owner 2026-11-11) | Flying: hovers as her boss does, staff across the body | A small purple lightning bolt from the staff | Purple bolt, small spark burst at impact |
| The Golden King (`side_king`, owner 2026-11-11) | Walk: short armoured stride, arms folded when still | A small Gate volley: 2 or 3 tiny ripple portals fire weapon projectiles | Gold ripples, straight gold trails, clink flash at impact |

Owner presentation update 2026-11-14: summon controls use warm wood/burgundy gradients, cream type, gold outlines and blossom stamps. The clean backdrop and native foreground move with the viewport camera so the painted and physical floor remain screen-locked; character idle poses and subtle parallax remain independent. HybridPresentationVersion=2; HybridFloorScreenLocked=true.
