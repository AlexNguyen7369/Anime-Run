# Anime Run — Game Design Requirements

This document is the top rule for the game. Feature specs (`docs/*_SPEC.md`) must never contradict it. Values marked
**placeholder**, **proposed** or **open question** are tunable; everything else is fixed. Only the owner changes a
rule, and every change is recorded here with its date.

Created 2026-10-28 by the owner (Alex Nguyen), derived from Idle Vehicle Simulator (IVS). Research notes:
`docs/RESEARCH.md`.

## 1. Concept

An idle running simulator on Roblox. The player spins (gacha) for **anime characters based on real anime, with tweaked names** (section 5), puts up to
**3 of them on a team**, and the team auto-runs a chain of tracks against an NPC rival on every track. Each character
has **stamina** that drains while it runs; when it is empty the next character on the team takes over. The run ends
when all 3 are empty, or when the player loses a track to the NPC.

## 2. Core loop

1. Auto-spin characters (free, every `ROLL_INTERVAL` seconds) and discover them in the Index.
2. Build a team of up to 3 characters (order matters).
3. Start a run on the start pad: the team auto-runs Track 1, 2, 3 ... against each track's NPC rival.
4. Each track won adds its pad value to the run's bank (UNBANKED).
5. The run ends:
   - **Team exhausted** (all 3 at 0 stamina): the bank is cashed out into Money; the player returns to the spawn.
   - **Player stops** (Stop button, death, leave): the bank is cashed out.
   - **Loss** (NPC reaches a track's finish first): the bank is emptied; loser screen; back to the start track.
6. Each character runs at a fixed cruise speed (rarity x category, times the speed multi; 4.13). There is no Speed stat.
7. Money buys upgrades; rebirth needs and resets Money for luck, speed and a stat point (4.14). There is no player level or XP.

## 3. Rules carried over from IVS unchanged (rename only: car -> character)

| Rule | IVS source |
|---|---|
| Numbered, point-to-point track chain; each track starts on the previous finish; loops back to Track 1 after the last | `TrackBuilder`, `TrackValidator` |
| Wide checkpoint area and WinPad at each finish; pad `Cash = PayoutCurve.Cash(n)` ($100 on Track 1, then x10 / x7.5 alternating) | `PayoutCurve` |
| One NPC rival per track, client-side only, left lane; player wins if they reach the finish before the NPC's known time | `NpcRacer`, `NpcConfig` |
| Banked money in NPC mode; loss empties the bank; cash-out on stop / death / leave | `RaceService` |
| The runner holds exact cruise speed everywhere (no acceleration, no corner slowing) | `RaceService` rail |
| Auto-roll every 3 s (placeholder), turbo luck every 10th roll x10 (placeholder), rarest-first roll check `min(1, luck / Chance)` | `GachaConfig` |
| Index: discovering = owning; stat points from unique discoveries; allocations saved, points derived | `GachaService` |
| Duplicates add `Copies` and pay no Money, unless sold (owner 2026-11-04, 4.36) | IVS 2026-10-22 |
| Workshop plots (Dojos) and the Showcase of 3 characters (Dojo squad); chosen stat boost instead of passive gain (4.19) | `WorkshopService` |
| Weather events (Rain, Night Race, Gold Rush, Clear, Aurora); 3 event-only characters, not rollable for now, listed in the Index as undiscovered tiles, kept in saves that own them (owner 2026-11-03) | IVS `docs/WEATHER_EVENTS_SPEC.md` |
| Rebirth resets Money (4.14) | `RebirthService` |
| Session-locked saves through `UpdateAsync` | `PlayerData` |
| Server decides every number that matters; the client only displays | IVS "Technical and data requirements" |

## 4. What changes

### 4.1 Characters replace cars
- A character is a catalog entry with a permanent `Id`, `Name`, `Rarity`, `Chance` (1 in N), `SpeedMulti` (no cruise
  effect, 4.13), `Stamina`, `Category` (4.5), `Series` (4.8) and an archetype. Spec: `docs/CHARACTER_GACHA_SPEC.md`.
- The player runs on foot as the active character (a rigged, animated model on the race rail). There is no vehicle.
- IVS cars and car-only features are not part of Anime Run (owner 2026-10-28): the 111 IVS car entries, car models
  (the car body included), gamepass cars, the Ember Wyvern dragon and the Singularity orb are removed. Characters run
  as a placeholder anime runner rig on the race rail (4.10).

### 4.2 Team of 3
- The player equips a **team**: 3 ordered slots. The same character may not be in two slots. A team needs at least
  1 character. Spec: `docs/TEAM_AND_STAMINA_SPEC.md`.
- Slot 1 starts every run; slot 2, then slot 3, take over when the one before is empty.
- The player fills and swaps the 3 slots on foot (owner 2026-11-02): pick a character in the Backpack, then tap slot
  1, 2 or 3 to put it there (a character already on another slot swaps places; tapping its own slot takes it off).
  The single equip (Index, roll toast) puts a character on slot 1.

### 4.3 Stamina
- Every character has a stamina bar (0-100%). It drains only while that character is running.
- The drain rate depends on rarity (owner 2026-11-02): Commons tire at about 12-15 s and Secrets at 30 s. Seconds of
  running (in-between values proposed): Common 13.5, Uncommon 15.5, Rare 18, Epic 21, Legendary 24, Mythic 27, Secret 30.
- Speed matters more than stamina (owner 2026-10-30): the rarity spread in stamina is small. A team clears a few
  tracks per run and progresses track by track through checkpoints (4.15), not the whole chain in one run.
- While a runner runs, a vertical blue stamina bar is fixed to the right of its visible character (owner 2026-11-02),
  showing the active slot's stamina. Client display of the server's `Stamina<n>` / `RunSlot`.
- At 0 stamina the next non-empty slot takes over at once, at its own cruise speed. The NPC race timer keeps running.
- Stamina refills to 100% for every character at the start of every run (owner 2026-10-28). It never carries over.
- Stamina bar look (owner 2026-11-03): the bar drains smoothly, a lighter trail shows the stamina just lost, the fill
  turns from blue to amber to red as it runs low (thresholds placeholder: 50% / 25%) and pulses when low, and it
  refills with a flash when the next runner tags in. Display only.
- Team row (owner 2026-11-03): each portrait is only the character's avatar head; rarity is not shown on the row. The
  current runner gets a clear animated indicator (enlarged, glowing ring, a bobbing marker); every portrait shows its
  stamina on a thick arc, with its stamina seconds left as a number (orchestrator default); tired runners grey out with
  an animation; the tag-in plays a short pop. The team bonus (4.8), if any, shows as a small badge on the row.
- When the last character reaches 0 the run ends as a **soft end**: the bank is cashed out (owner 2026-10-28).
  Exhaustion pays per distance (owner 2026-11-01): the track being run when the team tires adds
  `PayoutCurve.Cash(n) x distance covered / track length` to the bank before the cash-out (share placeholder 1.0).
  Track lengths are unchanged; Track 1 is not shortened (owner 2026-11-01). Track 1 balance is fine as is: no retune of
  Common speed, stamina or Track 1 length (owner 2026-11-03).

### 4.4 Losing stays a speed comparison
- The NPC's track time is fixed when the track starts; if the player's team reaches the finish later, the player loses.
  A swap to a slower character mid-track can turn a win into a loss: team order is part of the strategy.

### 4.5 Runner categories (owner 2026-10-28)
- Every character has one category that trades speed against stamina (multipliers placeholder):
  - **Sprinter**: cruise x1.25, stamina x0.9 (proposed).
  - **Balanced**: x1, x1.
  - **Marathoner**: cruise x0.8 (owner 2026-10-30), stamina x1.1 (proposed).
- Rarity sets the base speed and base stamina; the category scales them. Category speed multiplies the damped
  cruise multi (after `CruiseStatMulti`), so Marathoner x0.8 is a real 20% slower (owner 2026-10-30); it counts inside `MAX_CRUISE_TOTAL_MULTI` and `MAX_CRUISE`.
- Shown to the player (owner 2026-11-03): hovering a team row portrait (tap on touch) opens an info card with the
  character's name, its category with the category's speed and stamina effect, its cruise (studs/s) and its stamina
  (seconds). The card does not show rarity.

### 4.6 Stamina stat point (owner 2026-10-28)
- Index stat points can be put into a stat **Stamina**: each point adds +5% stamina to every character (placeholder),
  additive with other points.
- Upgrade tree **Stamina** branch (owner 2026-11-03): each owned tier adds +% stamina to every character, added to the
  Stamina stat points' part: `1 + 0.05 x Alloc_Stamina + tree bonus` (placeholder +10% per tier, 5 tiers, +50% max).
  Priced like the Speed branch (weight 1, placeholder). It sits on the free hex direction off Start.

### 4.7 Stamina potions (owner 2026-10-28)
- A potion category **Stamina** (IVS `BoostConfig` pattern): a timed boost, x1.5 stamina for every run started
  while it is active, 15 minutes (placeholders). Sold in the Shop as potion packs (Robux developer products) and given
  by daily login and codes, like the IVS potions. Not a random item. Never pays Money.

### 4.8 Series and preset team bonus (owner 2026-10-28)
- Every character belongs to one **Series** (a tweaked-name take on a real anime, section 5).
- **Series bonus**: all 3 team slots from the same Series -> +20% stamina for the whole team (placeholder).
- **Preset teams**: named trios defined in the catalog (e.g. a series' main squad). A team with exactly those 3
  characters, in any order, gets the preset bonus instead of the Series bonus: +40% stamina and x1.1 cruise
  (placeholders). The cruise part counts inside the IVS total cruise cap (`MAX_CRUISE_TOTAL_MULTI`, `MAX_CRUISE`).
- Only full 3-character teams get a bonus. The best one applies; bonuses never stack with each other.

### 4.9 Map redesign: longer tracks and anime biomes (owner 2026-10-28)
- Track n is `984 x F x 1.25^(n-1)` studs, F = 3 (owner 2026-10-30; Track 1 about 2,950, Track 10 about 22,000).
  Track 1 gets a new, longer layout. NPC speeds are unchanged.
- Every track has an anime-inspired biome: one per series (Tracks 1-6, in series order) plus 4 classic anime worlds
  (Tracks 7-10). Biomes follow section 5 (evoke, never copy logos or symbols). Spec: `docs/TRACKS_AND_BIOMES_SPEC.md`.
- Biomes are researched (owner 2026-10-30): before building a track layout or biome, research public information on
  its anime (locations, layout, architecture, palette, landmarks) and match it closely in layout, assets and world
  building. Section 5 safeguards still hold: no logos, symbols, real names, show kanji, ripped assets or exact copies
  of an iconic design.
- Full biome worlds (owner 2026-10-30): each track is a full world, not props along a road. The layers are
  code-generated Terrain + water, in-house uploaded meshes, per-zone client atmosphere (sky, lighting, fog, grade,
  particles) and ambient audio. Biome sky and light changes are client-local only; the server's `Lighting` stays
  untouched. Heavy layers follow the REDUCED EFFECTS setting. Spec: `docs/BIOME_ENVIRONMENT_SPEC.md`.

### 4.11 Speed stat scale (owner 2026-10-30) - RETIRED 2026-11-01 with the Speed stat (4.13)
- Only this remains: the save store is `PlayerStats_v2`; pre-scale test saves were wiped, older stores stay untouched.

### 4.10 World redesign (owner 2026-10-28)
- Anime town plaza hub at the centre, 7 player plots (Dojos) around it, the track chain spiralling out from the hub's
  start gate through the 10 biomes. Spec: `docs/WORLD_REDESIGN_SPEC.md`.
- Player plots keep the workshop rules; the IVS Showcase becomes the Dojo squad: 3 owned characters not in the racing
  Team (their effect: 4.19). A character is in the Team or the Dojo squad, never both.

### 4.12 Track camera (owner 2026-10-31)
- While the local player's runner is racing, the camera yaw follows the runner's direction of travel along the track,
  like shift-lock. The player still pitches and zooms; turns are smoothed, never snapped.
- A Settings toggle, TRACK CAMERA, switches it. Off = the regular camera. Default ON (placeholder).
- Client-only display; no server number changes. Spec: `docs/CAMERA_SPEC.md`.

### 4.13 Fixed character speed, no Speed stat (owner 2026-11-01)
- There is no Speed stat and no speed gain. Each character has a fixed cruise speed (studs/s) set only by its rarity
  and its category (4.5). New players run slow. The character's `SpeedMulti` never enters cruise.
- Base cruise by rarity, Balanced (proposed; NPC formula, placeholder, `48 x 1.363^(n-1)`): Common 24, Uncommon 33,
  Rare 48, Epic 90, Legendary 200, Mythic 450, Secret 700. Category multiplies it: Sprinter x1.25, Balanced x1,
  Marathoner x0.8 (4.5).
- Enemy speed (owner 2026-11-05): a starter or other Common with no multis never outruns the Track 1 enemy. A Rare is
  about level with it. Later enemies scale up from there, staying below `MAX_CRUISE`.
- Speed multi = everything that scales that fixed cruise, multiplied together, capped by `MAX_CRUISE` (800 studs/s):
  - Index stat points in Speed: +% cruise per point (placeholder +2% per point, additive with the other stat points).
  - Speed potions: timed x cruise (IVS potion pattern; placeholder x1.25).
  - Upgrade tree **Speed** branch: each owned tier adds +% cruise to the character, additive with the Speed stat points
    (placeholder +10% per tier, 5 tiers, +50% max).
  - Preset team bonus x1.1 (4.8).
  - Upgrade tree **Money** branch (owner 2026-11-03): +10% Money per tier, 5 tiers.
  - Auras and trails: one aura and one trail equippable per team slot; each slot's aura and trail scale only that
    slot's character (damped, as `RaceConfig.ItemCruiseMulti`). A player may own up to 3 copies of each aura and each
    trail, each copy at the item's full price (owner 2026-11-04); one copy is worn on one team slot.
  - Rebirth: +5% cruise per rebirth level (owner 2026-11-03, placeholder; 4.14), additive with the Speed stat points
    and the upgrade tree Speed branch; its +1 stat point can also go into Speed.
  - A character's Sidekick (4.36) and Relic (4.38), when they give speed (owner 2026-11-04).
- Removed: `leaderstats.Speed`, Speed gain while running, Speed rewards and codes, the Speed leaderboard, gate signs
  showing a Speed requirement. Saved `Speed` is ignored (kept in old saves, never read).
- Saitamo's base cruise is 350 (owner 2026-11-04, 4.35), the one exception to rarity x category. The speed multi applies as usual.
- Admin test runner Kami: admin command `/kami [player]` gives and equips Kami for the session only (never saved, never
  rolled, not in the index). Kami cruises at 800 studs/s, equal to `MAX_CRUISE`.
- Admin test commands (owner 2026-11-04): `/narito [player]` adds Narito (`leaf_hero`) to the index. `/newplayer` erases
  the sender's own save and kicks them, so the next join is a brand new player (starter popup, 4.21; arrival flow, 4.24).
  It takes no target. Only pending gifts and their receipts stay, so a paid gift is not lost or paid twice. `/wipe` stays
  as it is: a live reset of progress with no starter popup.
- HUD: the speedometer and the cruise read-out (`RacerHud/Speed`) are removed. The profile's CRUISE row and the
  character cards still show cruise.

### 4.14 Rebirth (owner 2026-11-01)
- Each rebirth level gives: luck multi, +5% cruise (owner 2026-11-03; placeholder, `RebirthConfig.SPEED_PER_REBIRTH`,
  +100% at rebirth 20, capped by `MAX_CRUISE`) and +1 stat point (the "stat boost"). The Rebirth panel shows all three
  rewards, with the speed icon on the speed tile. Luck and speed show the total after the next rebirth; the stat point
  tile shows the points that rebirth gives.
- Stat points are spent in the Rebirth panel's STATS tab (owner 2026-11-05; 4.40).
- Rebirth resets Money.
- Player levels and XP are removed. Rebirth n+1 needs Money >= `BASE_MONEY` x `MONEY_GROWTH`^n: $100K for rebirth 1,
  x10 each after (placeholder; `RebirthConfig`). Old saves keep `Level` / `XP` unread. The rebirth XP multi is gone; the
  luck totals table is unchanged.

### 4.15 Sensei checkpoints (owner 2026-11-02)
- The plaza sensei opens the Tracks panel, one scrolling list of long horizontal cards, one per track (owner
  2026-11-04, replaces the card grid and detail pane). A card shows only: the track number, a screenshot of that
  track's road (no 3D render), the biome's in-game name, one brief definition of the place in its anime's story,
  the recommended speed and the enemy's name. Length, payout and times are not shown. Definitions: `TRACKS_AND_BIOMES_SPEC`
  "Track card definitions" (proposed copy, tweaked names only, section 5).
- Clicking an open card picks it as the player's **checkpoint**, the track their runs start on
  (`Remotes.SetCheckpoint`, server-validated). The current checkpoint's card is marked. A locked card stays dimmed
  with its lock, and clicking it picks nothing.
- Recommended speed is the lowest whole speed above the enemy's cruise speed (proposed; `NpcConfig.RecommendedSpeed`).
- Track 1 is always open. Track n opens once Track n-1 is beaten (`BestTrack >= n - 1`): the player can pick up to
  the track they are stuck on; every later track stays locked until they pass it.
- The pick is saved (`Checkpoint`) and clamped to what is open. A run starts on the checkpoint track; a loss sends the
  runner back to the start of the checkpoint track; after the last track the run loops back to it.
- **Checkpoint bonus**: in one run, each track won after the checkpoint track pays its pad cash x
  `min(BONUS_CAP, 1 + BONUS_PER_TRACK x k)`, k = tracks past the checkpoint track (placeholders +10% per track, cap
  x2; `CheckpointConfig`). The checkpoint track itself pays x1. k restarts when the runner goes back to the
  checkpoint (loss, loop) or the run ends (stop, team exhausted).
- A won track that paid the bonus shows a popup "CHECKPOINT BONUS x1.2 · $paid" (placeholder art and timing:
  0.25 s in, 1.5 s hold, 0.5 s out; client-only display).

### 4.16 Leaderboards removed (owner 2026-11-01)
- All leaderboards are removed from the plaza for now. Board data stores are left untouched.
- The Best Roll pedestal stays and keeps showing the server's best roll.
- Speed Doubler game passes are removed for now; nothing else in the shop changes.

### 4.17 Biome welcome popup (owner 2026-11-01)
- When the local player's runner enters a new biome, a small popup fades in with the biome's display name (e.g.
  "Shibuyo Underground") and fades out (placeholder: 0.4 s in, 2 s hold, 0.6 s out). Client-only display.

### 4.18 Loading at high speed (owner 2026-11-01)
- Biome meshes and textures must be loaded before a fast runner reaches them; sky and lighting must switch quickly at
  a biome boundary at any speed. Use the cheapest approach that keeps up at `MAX_CRUISE`. Client display only.
- Biome while racing: the server publishes `RunTrack` (the track whose finish pad is still ahead) on the runner rig; the
  client takes the biome from it and switches at once at the finish pad. The nearest centre line (`ZoneAt`) is used only
  while walking. There is no speed look-ahead.

### 4.19 Workshop stat boost (owner 2026-11-03; replaces the workshop / Dojo idle gain)
- There is no passive gain: standing in the Dojo earns nothing, there is no offline workshop credit and no extra luck
  while standing in the zone.
- The player picks **one stat** for their workshop to boost: Money, Luck, Speed or Stamina. The choice is saved
  (`WorkshopStat`, default Money) and can be changed at any time.
- The boost % comes from the combined rarity of the 3 characters on the Dojo squad (the Showcase, WORLD_REDESIGN_SPEC
  5): each character gives rarity points, Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, Mythic 6, Secret 7; the
  sum x 5% (placeholders) is the boost. 3 Commons = +15%, 3 Secrets = +105%. Empty slots give 0.
  Copies do not count (proposed).
- Workshop levels stay (bought with Money, same prices) and scale the boost: boost x (1 + 0.1 x (level - 1)) (proposed
  placeholder; level 10 = x1.9).
- The boost applies always, everywhere, runs included. It is added to the chosen stat like the upgrade tree bonus
  (proposed): Money and Luck to their `1 + points + tree` part; Speed to the speed multi's `1 + points + tree` part
  (cruise still capped at `MAX_CRUISE`); Stamina to the stamina multi's `1 + points + tree` part (4.6). Speed and
  Stamina are fixed at run start, like every other run multi.
- The `Workshop` stat point is retired: allocated Workshop points are refunded as free points.

### 4.20 UI animations across the board (owner 2026-11-03)
- Every player-facing UI animates. Display only; every animation goes through `Client/UiMotion`, so Roblox Reduced
  Motion and the in-game REDUCED EFFECTS land it at once. Timings below are proposed placeholders.
  - Panels (every PanelSwitch panel): open = scale 0.9 -> 1 with Back easing + fade in, ~0.2 s; close = scale to 0.95
    + fade out, ~0.12 s. List / grid items stagger in on open (~0.03 s apart, at most ~0.3 s total).
  - Buttons (HUD, panels, tabs): hover grows, press shrinks, release pops back (sizes stay the HUD layout rule's
    1.035 / 0.97, orchestrator default); disabled buttons do not move.
  - Tabs and selections: the active marker slides / tweens to the new tab; selected tiles pop.
  - Numbers: HUD counters (Money, Unbanked) count up / down over ~0.3 s; panel numbers update at once so no number
    is ever shown wrong (orchestrator default).
  - Toasts, popups and banners: slide + fade in, hold, fade out; badges pulse while something is claimable.
  - Gameplay feedback stays readable: no animation hides a number or blocks input for more than ~0.2 s.

### 4.21 Starter choice (owner 2026-11-03)
- A new player gets a popup and chooses one of 3 starter characters: Ruffy, Karate Kid, Sayan. The pick is their first
  Team member; they roll the next two to fill the Team. Saves that already have rolls or characters get no popup.
- Starters are not rollable and not in the Index, like the old `starter`. Stats are **proposed**: Common, cruise as the
  old starter, Balanced, no Series. Look: same model as Lufy, Narito, Gokku (mapping **proposed**: Ruffy = Lufy,
  Karate Kid = Narito, Sayan = Gokku).
- Auto-roll is off for a new player until a spotlight tutorial has them turn it on (owner 2026-11-04). After the pick's
  reveal (about 4 s, proposed) the screen dims except for one spotlit control and a short line of text: first the compact
  roll card, which opens the roll view, then its AUTO button. Nothing else takes clicks until AUTO is on, and the
  tutorial cannot be skipped. A save with 0 rolls starts with auto-roll off and gets the tutorial on each join; any save
  with a roll keeps the default of on. No new saved field.
  Look (owner 2026-11-04; sizes and timings proposed): the dim closes in on a rounded spotlight that glides from step to
  step, with a pulsing gold ring, a ripple and a bobbing arrow. A caption card shows the picked starter's drawn head,
  "STEP 1 OF 2" and the instruction. Turning AUTO on plays a gold burst and "AUTO ON!", then the dim fades away. Reduced
  Motion keeps the spotlight, ring and card and drops the movement.
- The roster in play is these 30 models plus the 3 starters that reuse them.

### 4.22 Collection cards: Index and Backpack Characters (owner 2026-11-03)
- Layout ideas from the owner's reference screenshot, no copied art. Index tiles and Backpack Characters tiles share one
  card (`Components.CardFace`): rarity-tinted background, rarity inner border (Secret rainbow), the character's upper
  body filling the card, cruise in gold above a bold name, category badge top right. Outer border: green = on the Team,
  white = picked (Backpack), dark otherwise. Sizes, colours and cell counts are **proposed** placeholders.
- Index: undiscovered cards stay a black silhouette with "?", rarity and public odds; discovered cards add name, cruise,
  category and Equip. Catalog order is unchanged.
- Backpack Characters: a Sort button (Rarity, Speed, Stamina; **proposed**) and a name search in the header. The default
  stays Rarity, least rare first (owner 2026-10-20). Top left of a card: `TEAM <slot>` on the Team, otherwise copies when
  more than 1. Display only: the server still decides every number and every Team change.

### 4.23 Ninja run for the Leaf series (owner 2026-11-03)
- A character's optional `RunStyle` replaces the universal run (4.34) (`docs/CHARACTER_GACHA_SPEC.md`). All 5 Leaf characters and
  Karate Kid, who wears Narito's model, use `NinjaRun`: torso leaning forward, both arms straight back, head looking ahead. Angles
  are **proposed** placeholders. The blocky body stays unchanged: only part positions move.
- `NinjaRun` adds a short client-side effect on the player's runner while moving: air streaks and foot dust. It is free,
  display only and has no gameplay effect. It stays short so it never competes with Market trails and auras. REDUCED
  EFFECTS removes the dust. NPCs wearing the character get the pose, not the effect.
- Characters without a `RunStyle`: 4.34.

### 4.24 First impression: arrival, plaza and Dojo look (owner 2026-11-03)
Display only; no gameplay number changes. Sizes, timings and positions are **proposed** placeholders unless stated.
Spec: `docs/WORLD_REDESIGN_SPEC.md` section 7. The plaza and Dojos are drafted in Blender first and shown to the owner
before any Studio work.
- **Loading screen**: the game's logo (`assets/logo/AnimeRunLogo.png`, owner's art) and a loading bar showing real
  progress. It does not finish until the assets a player sees first have loaded on their client (the plaza and Track 1
  world ready; plaza, Dojo, sky and HUD assets and the characters on screen preloaded; content queue empty, at most 4 s
  of grace, proposed), and it stays up at least 8 seconds. Keep the load short; far biomes and other characters load
  behind the game. Safety limit 90 s (proposed): a stuck asset never traps a player. Shown on every join (proposed).
- **Reveal**: on a player's first join, a skippable camera sweep of about 5 s over the plaza, through the torii and down
  to the spawn. Reduced Motion replaces it with a cut.
- **Starter pick**: stays a popup (4.21) with a lighter dim so the plaza shows behind it. The pick plays an in-world
  reveal: a petal burst and the chosen character's hero pose. The first auto-roll waits about 5 s (proposed) so its result card does not cover it.
- **First goal**: a petal trail leads a new player from the spawn to the gate. The Daily panel does not open by itself until their
  first run ends (its button still works). The gate plays a burst when they first cross it.
- **Legends and sky loop**: the plaza shows at most 2 Legend pedestals, next to the Race Start gate (owner 2026-11-04), and 2-3 client-only runners with
  trails lap the plaza at high speed. Client display only; these are not players or NPC rivals.
- **Exclusive pedestal** (owner 2026-11-04, 4.35): one pedestal near the spawn advertises Saitamo. It does not count toward the 2 Legends and follows Clear plaza: every Dojo stays visible from the spawn.
- **Plaza atmosphere**: falling petals and quiet forest ambience reusing Track 1's reviewed sounds. The sakura's trunk is solid.
- **Plaza lighting**: the plaza (Zone 0) gets its own golden-hour sky and lighting, client-local like every biome. The
  server's `Lighting` stays untouched.
- **Wayfinding**: the Market and the Race Start area are clearly marked, in bold, and placed so a player can always
  tell where they are and where to go. Each has a large bold sign on the landmark itself (Race Start: a banner on the
  torii; Market: a large flat sign on the Market itself, owner 2026-11-04, replacing the entrance arch). Race Start also has a floating bold label high above it, seen across the plaza; the Market's floating header follows the service row (Service headers, owner 2026-11-04).
  Labels show only on foot and hide up close (proposed for Race Start: within 20 studs, out to 260 studs).
- **Service headers** (owner 2026-11-04): Index, Shop, Potions, Market, Sensei and Race Start, plus the YOUR DOJO marker, each float a bold white italic label with a dark outline over a coloured emblem behind the word. Display only. Sizes, colours, heights and distances are proposed. Market's header matches Index and the rest of the service row: just over its roof, same size and distances (owner 2026-11-04). Race Start keeps its label high above the landmark (Wayfinding); its distances stay as there. The flat signs stay.
- **Clear plaza** (owner 2026-11-04): a player at the spawn can clearly see every Dojo; no service building stands in front of one. Shop, Potions, Market and Index stand in one straight row in the west opening of the Dojo ring; the Rebirth shrine is removed (Rebirth opens from its HUD tile); the Best Roll pedestal stands in a gap between Dojos. The Market is one in-house stall with no empty structures and no art from the fork. Repeated decoration is removed: the path is plain, with the RACE START torii, 4 stone lanterns framing its gate end and at most 2 Legend pedestals beside the gate (no banners); one Great Sakura is the only plaza tree. The sky loop stays.
- **Fresh-save checks** (dev tool, Studio only; orchestrator default): the attribute `TestSaveKey` plays a Studio session on a separate save and skips leaderboards, so first-join checks never touch a real save. It has no effect on a live server.
- **Dojos**: unowned plots show a closed dojo with a small sign, not a bare slab. An owned Dojo's look changes with its
  level at 4 tiers (proposed: levels 1, 4, 7, 10), with a short effect on level-up. Squad members play idle training
  poses, lanterns take the colour of the chosen `WorkshopStat`, and a marker shows the player's own Dojo on first join.

### 4.27 Phone and tablet HUD (owner 2026-11-03)
- Phone and tablet HUDs shrink; desktop never does (owner 2026-10-28, confirmed for Anime Run 2026-11-03). The Auto / Upgrade pair (4.40) may shrink on 4:3 tablets.
- At viewport height 400 or less (`StackMaxHeight`) the Auto / Upgrade pair stacks, and it hides while a panel is open. Desktop keeps it drawn.
- Backpack tabs may shrink on phones to fit the rail, as Market's do (minimum scale 0.1).
- Test rule: a roll that plays behind the loading screen still counts, but its animation timing is not judged, because no player sees it.

### 4.25 Track loading (owner 2026-11-03)
- The server builds Tracks 1-5 before a player can load in. Tracks 6-10 then build behind the game, nearest the players first. Spec to be written before code: a run must never reach a track that is not built yet (details **open question**).

### 4.26 Track enemies (owner 2026-11-03; replaces the 2026-10-28 rival list)
- Every track's NPC is an enemy (a villain) from the anime of that track's biome, with a tweaked name (section 5). Cast
  and sources: `docs/NPC_RIVAL_SPEC.md`. Race rules and NPC speeds are unchanged.
- The player sees one enemy at a time: the one they are racing now.
- A large indicator (the enemy's name over a down arrow) sits above the enemy's head and follows it. It has no distance
  limit and draws over the world, so it stays visible wherever the enemy is. It is fixed to the enemy while the enemy's head
  is on screen. Pixel size is a placeholder.
- When the enemy's head is off screen or behind the camera, a pointer at the screen edge shows the enemy's name and an
  arrow aimed at it (owner 2026-11-04, replaces "not clamped"). Pointer size and edge margins are placeholders.
- Delivery (owner, same day): names and indicator land first on the placeholder rig; new enemy models follow in one pass.

### 4.28 Enemy showdown moment (owner 2026-11-04)
- When a track race starts, a short banner names the enemy: "VS", its name and its portrait, with the track's name. When the
  player wins that track, a short banner says the enemy is defeated, with the same portrait. Display only: the race does not
  pause and no input is blocked. Timing and layout are placeholders; both go through `Client/UiMotion` (4.20).

### 4.29 Defeated Enemies page (owner 2026-11-04)
- The Index has a Defeated Enemies page with one tile per track enemy, in track order. A beaten enemy (`BestTrack >= n`) shows
  its portrait, name and the player's best time on that track. An unbeaten one is locked and hides its portrait and name.
  No new saved data: it reads `BestTrack` and the race best times, published read-only as player attributes `RaceBest<track>`,
  which other players can read (owner, same day). No reward (rewards are a separate owner decision).

### 4.30 Bleech series (owner 2026-11-04)
- A seventh Series, Bleech (based on Bleach; id `soul`), adds 6 rollable characters: Orihima, Rukiya, Renjy, Ichigu, Ulquiorro,
  Aizon. Preset trio: Ichigu, Rukiya, Renjy. Ulquiorro is also Track 9's enemy and shares its model. Cast and rarity are the
  owner's; `Chance`, `SpeedMulti` and `Category` are placeholders inside the existing bands. Spec: `CHARACTER_GACHA_SPEC.md`.
- Art direction, marks and likeness follow section 5. Evidence per character: `docs/char_evidence/`.
- No plaza Legend for this Series (owner 2026-11-04, relayed by `animerun-b3`): the 2 Legends stay `db_hero` and `mha_symbol` (4.24).

### 4.32 Villains are rollable (owner 2026-11-04)
- The track enemies are also rollable characters in their anime's Series, under section 5's rules and look, redesigned with the
  character design skill and reviewed by the owner before upload. New: Paine, Selle, Arlon, Akazo, Jogoh, Shigaraky, Mahitoh, Enelu.
  Freezo and Ulquiorro were already rollable. Rarity is the owner's: Epic Arlon, Jogoh; Legendary Paine, Shigaraky, Mahitoh; Mythic
  Selle, Akazo, Enelu. `Chance`, `SpeedMulti`, `Category` are placeholders inside the bands. Each shares its enemy's model.

### 4.31 Roll animation (owner 2026-11-04)
- Every roll clearly shows the character actually rolled: its own portrait or model, with the same framing and light from the cycle through the landing. Detail and placeholder timings: `docs/ROLL_ANIMATION_SPEC.md`.
- Characters cycle in one fixed centre spot and slow down, instead of sliding through a reel. A normal roll plays as a larger bare figure at top centre; an emphasized roll (rule: 4.40) plays large in the screen centre with gradient odds, an outlined name and a rarity crystal, and no visible card.
- Rolls show the character from the head to the upper torso, not the whole body (owner, same day), as its drawn portrait.
- Every character gets a drawn digital portrait as part of being added to the game, stored with its assets and used for its roll, Index and Enemies page, Backpack, starter card and the enemy showdown banner, with a head-only cut for the Team minibar, whose head still breaks out of the circle per 4.3 (owner, same day; CHARACTER_GACHA_SPEC Digital art portrait).
- Auto race is a toggle labelled "Auto"; the top-centre Auto Race button is gone (owner, same day). Its place and look are now in 4.40 (owner 2026-11-05), which replaces the top-right pill.
- The normal roll plays at the very top centre of the screen. Quests moves from the top-right row to an icon button directly above Shop (owner, same day).
- The animation fits the player's roll interval at every Roll Speed tier, so roll rate and upgrades do not change for non-emphasized Common to Epic. No new dependency; motion stays in `Client/UiMotion`.

### 4.33 UI feedback: impact, motion and sound (owner 2026-11-04)
- UI moments pair motion with sound and feel lively, with extra impact on big moments (roll landing, enemy defeated, Rebirth, claims, purchases). Detail and placeholder timings: `docs/UI_FEEDBACK_SPEC.md`.
- 5 short impact sounds live in a Folder `ServerStorage/ImpactSounds`, the one place to swap one. The server copies the folder to ReplicatedStorage at start, because clients cannot read ServerStorage. Up to 4 more free Creator Store sounds: reward chime, whoosh, coin, denied. Each id and its creator is logged in the UI sound ledger (section 5 audio rules hold).
- 4.20 still holds: motion goes through `Client/UiMotion`, display only, no animation hides a number or blocks input for more than ~0.2 s, disabled buttons do not move, panel numbers update at once. 4.28 and the roll spec's limits still hold. Reduced motion cuts the motion, not the sound; the SOUND toggle silences every cue.
- Audit fixes from the owner's UI improvement request, owner to review: panels close on outside click (Duel excluded), Upgrades has no EXIT and hides the HUD buttons while open, Quests has a claimable badge.

### 4.34 Universal run (owner 2026-11-04)
- Every character without a `RunStyle` uses one designed run, the deep speed lean, in place of the old upright swing: torso
  leaning forward, arms pumping low and opposite the legs, long leg swing, head tilted up so the eyes look ahead. Angles are
  **proposed** placeholders (`docs/WORLD_REDESIGN_SPEC.md` section 2). The blocky body stays unchanged: only part positions move.
- Standing is still upright. New characters get this run by having no `RunStyle`.
- It has the same client-side effect as `NinjaRun` (4.23): air streaks and foot dust while moving, free, display only, no gameplay
  effect. REDUCED EFFECTS removes the dust. NPCs get the pose, not the effect.

### 4.35 Gems (owner 2026-11-04)
- Gems are a currency that buys Sidekick summons (4.36). They come from exactly five sources: winning a track (the runner beats the
  NPC to the finish), daily and weekly tasks (`QuestConfig`), Robux gem packs, selling a Sidekick and defeating Fully Adapted Raga (4.37; 1,000 Gems, paid spawns included, owner 2026-11-06). Duels, exhaustion, a losing
  finish and daily login pay none.
- Gem packs are the only monetization on the Sidekick side (owner 2026-11-04). Because Gems can be bought, summons are paid random
  items under section 6. Rebirth keeps Gems. Amounts are in `docs/SIDEKICK_SPEC.md`, **placeholder**.

### 4.36 Sidekicks (owner 2026-11-04)
- A Sidekick is a small companion rolled from a gacha at a plaza vendor, Sidekicks, for Gems. It is equipped per character, follows
  that character, deals its damage in boss events (4.37) and gives that character a speed or stamina gain while racing. Speed gain
  counts as an entry in the 4.13 speed multi, inside `MAX_CRUISE`.
- The vendor unlocks at rebirth 2. A tutorial then gives one free summon (4.21 style spotlight), so a player at rebirth 2 can join events. The free summon's Sidekick is never auto-sold (**proposed**), and the tutorial's last step points the player to equip it in the Bag, since only an equipped Sidekick unlocks events. The tutorial may show during a normal track run; it waits only for a duel, a boss event, a showdown and a short transition (owner 2026-11-05).
- First three Sidekicks, for testing: based on Pochita (Chainsaw Man), Igris and Kaisel (Solo Leveling). Tweaked names follow section 5,
  **proposed**: Pochito, Igriz, Kaizel. Each model is 30-40% of a character's size and made with the character design skill.
- Luck never affects summons (owner 2026-11-04). Luck, luck potions and every luck source apply only to the character auto-roll, which is
  fully separate from Sidekicks. Summons have no luck potions or shiny pass. VIP pays 10% fewer Gems per summon, decided by the server (owner 2026-11-05, relayed by the monetization session).
- The summon page (owner's reference, layout ideas only, no copied art; redesign owner 2026-11-05): the Gem balance, rotation timer, Mythic Pity and Legendary Pity at the top; a poster with the Mythic in the centre, the Legendaries and Rares beside it, and each one's rate under its name; the cost; Auto-Sell, Summon 1x and Summon 10x; and a More Gems column of gem bundles with calculated bonus badges. Commons and the Secret appear only in Details. Results play a summon reveal (`docs/SIDEKICK_SPEC.md`). Tapping the poster or its button labelled "Details" shows the odds (section 6). This gacha look is on this page only: moving it to any other HUD or panel needs the owner's approval.
- The Bag has its own Sidekicks category, holding 50 Sidekicks (owner 2026-11-04). Each summon is its own bag entry. A summon needs room for
  everything it would add, after auto-sell (orchestrator default).
- Selling a Sidekick pays a small Gem refund, always well under a summon's cost (owner 2026-11-04). The summon page has an auto-sell filter
  by rarity. An equipped Sidekick is never sold.
- Ground Sidekicks walk beside their character. Flying Sidekicks hover around the character's shoulder and have a flapping animation (owner 2026-11-04). Kaizel flies; Pochito and Igriz walk. Every future flying Sidekick follows this rule.
- Summon pool rotation (owner 2026-11-05): the pool rotates every 30 minutes, identical on all servers. Each rotation holds 1 Mythic, 2 Legendaries, 2 Rares and all Commons, plus 1 Secret, shown in Details as a black silhouette (owner 2026-11-05; its id reaches clients, and rolls stay on the server). A Sidekick's odds do not change with the rotation. Exact numbers: `docs/SIDEKICK_SPEC.md`.
- Summon pity (owner 2026-11-05): summon 300 without a Mythic gives the rotation's Mythic; summon 100 without a Legendary gives one of the rotation's Legendaries. A Mythic resets only the Mythic count; if both land on one summon the Mythic wins. Secrets have no pity and reset nothing. Counts carry across rotations and are saved per player. Details shows the updated odds when the next summon is guaranteed (section 6).
- Sidekick index (owner 2026-11-05): a Sidekicks page in the existing Index panel.
- Click menu (owner 2026-11-05): clicking a Sidekick or Relic, in the Bag or in the Index, opens a small menu with Equip and Sell. Equip opens a picker of the player's own characters; one item per character still holds, so choosing a character that already wears one replaces it, and the old item returns to the bag. Sell asks "Are you sure?" first. This replaces the Bag's character stepper and second-press sale.
- Art in UI (owner 2026-11-05): the summon page and its results show the Sidekicks' actual 3D models. Drawn portraits are used only in the Sidekick index and for Sidekick equip in the Bag. This is an exception to the UI's portrait art rule.
- Odds, cost, buffs, sell values: `docs/SIDEKICK_SPEC.md`, **placeholder**. Sidekicks cannot be traded.
- Art rulings (owner 2026-11-04; override section 5's target look for these models): Pochito is polished and closer to its source, with smooth rounded surfaces rather than hard facets. Kaizel is a thin wyvern, not a bulky dragon, with neon blue parts. Igriz keeps its red version; Kaizel stays black and cyan. Models are still made in-house, with no ripped art.

### 4.37 Boss events (owner 2026-11-04)
- Every 30 minutes (per server), a popup gives players 3 minutes to teleport to the event, or decline. A player with no Sidekick is locked
  out. The event lasts 8 minutes in total (owner 2026-11-05), and Phase 2's start adds 2 fresh minutes (owner 2026-11-06):
  - 0:00-1:00, preparation: arrivals stand on the track with a team HUD of 3 slots. Only characters with a Sidekick can be slotted, and the HUD says so. A player with 1 or 2 such characters has a team of 1 or 2. The HUD opens on the team from the player's last event, when it is still valid, and shows the team's average stamina as a number (owner 2026-11-05). Its X closes it only with at least 1 character chosen; otherwise red text, gone in a moment, says to select a character. After closing, the team runs on the track as display only, each with its Sidekick, and an Edit Team button above the minibar reopens the HUD until the spawn (owner 2026-11-05).
  - 1:00, Big Raga rises from under the track to full height in 1.5 seconds (owner 2026-11-05, replaces 2-3 seconds), with the HP bar filling alongside (owner 2026-11-05). No team edits from here. Everyone's characters jump, turn to face Big Raga and show red exclamation marks, then the whole team starts running in a line (**proposed** 2026-11-06, replaces all but the first vanishing in smoke): the fight starts 1.5 seconds after the rise, at 3 seconds (owner 2026-11-05). It runs to 8:00. Phase 1's defeat starts Phase 2 (below).
  - 1:00-3:00, late joining: players can still teleport in; their team is their last event's, or else chosen for them, with no edits, and they start at once (owner 2026-11-05). Teleporting closes at 3:00, or at Phase 1's defeat if that comes first (**proposed** 2026-11-06).
  - Everyone returns to the spawn at the end. A player can also leave the battle at any time with a leave option; there is no other early exit (owner 2026-11-05). Exhaustion never removes a player: the team exhausted wait applies, then the team resumes.
  - A player in a duel can teleport in (owner 2026-11-05).
- When Big Raga spawns, and for each player who joins after that, a big red warning ("Big Raga has emerged, take him down!!!") flashes in and out, with no border and no background, on the screen of players in the event only (owner 2026-11-05). At the spawn, a bright red Roblox chat message ("BIG RAGA HAS SPAWNED, TAKE HIM DOWN FOR REWARDS") goes to everyone in the server (owner 2026-11-05).
- Any player with a Sidekick can pay 149 Robux to start the same event at once for their server, from the Bosses popup. It cannot be bought while an event is active.
- Bosses button (owner 2026-11-05): the button at the top left of the screen reads "Bosses" and holds no details. A press opens a popup. While an event runs it says "Big Raga is raging right now" with a Go option; with no event it offers Spawn boss, the event's details and the time until the next event. Only the tweaked name appears (section 5).
- Event roster (owner 2026-11-05): the event team and the main Team are separate. In an event the Team minibar shows the event team; the main Team is never changed and shows again afterward. A team bonus depends on the team alone, so in an event it comes from the event team (owner 2026-11-06).
- The first boss is Big Raga, based on Mahoraga (Jujutsu Kaisen). It stands huge in the middle of a separate circular sky arena: clouds,
  heaven and Olympus style. Inspired by Pokemon GO raid battles, it scales with the arena: far larger than any Legend or pedestal figure.
  It cycles idle moves. Each attack (Raga's Slice) that hits a player costs every character in that player's line 15% of a full bar in Phase 1 and 30% in Phase 2 (owner 2026-11-06); each shout that hits a player lowers that player's damage, and each wheel turn that hits a player makes the boss take 10% less damage from that player, for 15 seconds in Phase 1 and 20 seconds in Phase 2 (owner 2026-11-06). All undodged hits stack (owner 2026-11-06). An undodged hit also makes the player Vulnerable: their next Slice costs 50% more stamina (owner 2026-11-06). These show as status effects under its HP bar, and they differ from player to player (owner 2026-11-05). A later boss may use an enclosed underground arena.
- Dodge bar (owner 2026-11-05): 1 to 2 seconds before each attack, shout and wheel turn, a big bar shows at the bottom of the screen, above the roster minibar, with digital art of the boss's wheel attached to its left end and on top of it. The bar pops up and disappears with a 0.3 second animation (owner 2026-11-06). A vertical slider moves fast from left to right; a white, yellow and gold spot sits at a random place on the bar, clear of the start. White subtitles flash lightly above the bar and say how to play. The player presses Space when the slider is on the spot.
  - Dodged: the bar pops, "Nice Dodge!" pops out at the player in animated gold text with a star particle effect, the runner really moves left or right into the next lane with a side dash animation, and the move does not affect the player (owner 2026-11-06, replaces white text). The dash's 3 key frames are approved by the owner before in-betweens.
  - Otherwise the player is hit: a red header flashing at the player replaces the bar (owner 2026-11-06), "You were hit by Raga's Slice", "Raga yelled, you are intimidated" or "Raga has adapted to you", and the move's effect applies.
- Teams auto-run around the ring with real cruise and stamina, in lanes for up to 7 players, seeing each other's characters and Sidekicks.
  The full team runs in a line instead of chaining, and every character in it drains at once (owner 2026-11-06). A character out of stamina vanishes with a smoke animation and is not revived until the team timer ends. When the whole team is gone, the team exhausted timer of 8.5 seconds starts, then the full team respawns and continues (owner 2026-11-06). During the wait the whole minibar is greyed out and its stamina bars refill from bottom to top, reaching full at the wait's end (owner 2026-11-05). During the wait the camera hovers above and behind the player's runner, looking over the track at the boss (owner 2026-11-05), the screen dims slightly, and a centred countdown with a loading sign says the team is exhausted, completing at the wait's end (owner 2026-11-05). This overrides 4.3's run end inside the arena.
- A team deals one team damage: the average damage of its Sidekicks, times a gentle speed scale that adds at most +100% (owner 2026-11-05). The HUD shows it. The Sidekicks of the characters still in line take turns firing their own themed attacks at the boss (**proposed** 2026-11-06) (flame breath, slash, and so on). The server decides every
  hit and its damage; clients only draw it.
- Boss HP grows with the players in the arena until teleporting closes, then locks (owner 2026-11-05). A timer for the time left in the event shows at the top left above the HP bar (owner 2026-11-05).
- Damage numbers pop out animated and coloured red and yellow (owner 2026-11-05).
- The arena's clouds fill with small white floating particles (owner 2026-11-06).
- The player's FOV is locked for the whole event, at the wide view of the owner's 2026-11-06 screenshot (owner 2026-11-06).
- Big Raga never shows a duplicate of itself when it attacks (owner 2026-11-06).
- Auto-roll pauses only for players in the event (owner 2026-11-05) and returns to the player's own state afterward. A big boss HP bar replaces the top middle of the
  screen, popping in on spawn and filling left to right.
- Phase 2 (owner 2026-11-06): when Big Raga first reaches 0 HP, Phase 1's rewards are processed at once. It then does a bigger scream for 3 seconds straight, visibly growing 25% larger as it screams, in a small cutscene, and stays that size for the phase (owner 2026-11-06). A fully exhausted team skips exhaustion, watches the cutscene and revives when it ends, whatever its timer read (owner 2026-11-06); its HP bar fully revives at Phase 1's maximum plus 50,000, and its title becomes "Fully Adapted Raga". As the phase starts its wheel spins visibly very fast, then stops very abruptly, the stop emphasized to the player (owner 2026-11-06); it then spins for the rest of the phase, 2 fresh minutes are added to the event's timer, and the Dodge bar sweeps faster on every move. While the bar fills back up and after, the new drop rates spill into the drop list one by one, from top to bottom.
- Only a defeat pays, and only a player with at least 5% of that phase's HP in damage (owner 2026-11-06, of each phase's own HP **proposed**). Phase 1's defeat pays a Raga's Treasure chest (Phase 1 rates) and 100,000 Money. Phase 2's defeat pays an Adapted Raga's Treasure chest (higher rates, 4.38) and 1,000 Gems. A timeout in Phase 1 pays nothing; a timeout in Phase 2 leaves Phase 1's rewards only. A player who leaves after Phase 1's defeat keeps Phase 1's rewards and gets no Phase 2 rewards.
- Rewards popup (owner 2026-11-06): when the event ends with a defeat, players return to the spawn and a popup headed "Raga Defeated!" gives their total damage and a small section showing their rewards.
- Each chest holds 1 random Relic at its rates and a chance of a Big Raga Sidekick: 0.001% in Raga's Treasure (owner 2026-11-05) and 0.01% in Adapted Raga's Treasure (owner 2026-11-06), a downsized version of the boss with its own drawn portrait. It is never in the Gem summon pool, and its odds are shown with the Relic odds. This drop may overflow the Sidekick bag, for example 51/50 (owner 2026-11-05); nothing else may.
- Detail, sizes and timings not stated here: `docs/BOSS_EVENT_SPEC.md`, **placeholder**.
- Every boss move, and every Sidekick attack, is reviewed by the owner as key frames before in-betweens are made.

### 4.38 Relics (owner 2026-11-04)
- A Relic is a boss drop equipped on a character, one per character. Stats: damage, attack speed, luck, money gain, speed gain, stamina gain.
- A Relic can be sold for Money by rarity, never for Gems (owner 2026-11-05; prices **proposed** in `docs/RELIC_SPEC.md`). An equipped Relic is not sold. The Index has a Relics page, and Relics use the click menu in 4.36 (owner 2026-11-05).
- Each boss drops 6 Relics, one per rarity: Common, Rare, Epic, Legendary, Mythic, Secret. Each Relic ties to its boss's anime. Common has 1 stat,
  Rare has 1 higher stat, Epic 2, Legendary 3, Mythic 4, Secret all. Future bosses bring their own 6, with a different stat priority.
- The Secret is one universal Relic shared by every boss.
- Big Raga prioritises stamina and damage on its Epic to Mythic Relics, with lower everything else. Named Relics follow section 5: **proposed** in
  `docs/RELIC_SPEC.md`, with bonuses and odds **placeholder**. Relics cannot be traded.
- Big Raga's Epic is Raga's Wheel, replacing the Sealing Cube, drawn with the Dodge bar's wheel art (owner 2026-11-05).
- Every Relic has in-house digital art, no 3D model (owner 2026-11-06).
- Chests (owner 2026-11-06): Raga's Treasure and Adapted Raga's Treasure are drawn art only and sit in the Relics inventory for now. Opening one rolls its contents and shows them with the 1x summon animation; the chest image does not shake. Phase 2's table raises every rarity above Common, with World Core at 0.5% (`docs/RELIC_SPEC.md`). Both tables show as percentages summing to exactly 100% (section 6).
### 4.39 Gamepasses (owner 2026-11-04)
- Passes are permanent and account-bound; nothing here is random. Prices are placeholders except Saitamo's. Effects, numbers and code paths: `docs/MONETIZATION_SPEC.md`.
- VIP: a VIP title, +10% Money, +10% Luck. -10% Sidekick summon cost (owner confirmed 2026-11-05, replacing "no VIP discount"), built with the summons (`SidekickService.CostFor`).
- 2x Auto-Roll: halves the roll interval, so the 2 s floor of Roll Speed tiers (`MIN_ROLL_INTERVAL`) becomes 1 s for its owners.
- Extra Roll I and II: +1 roll each per roll tick (3 in total).
- 2x Money: doubles race payouts.
- Lucky and ULTRA Lucky: +1 and +2 Luck, added to the additive Luck part (+3 with both, **proposed**).
- Dojo Master: workshop boost x1.5. It replaces the Gold, Diamond and Void Workshop passes, which are removed.
- Deep Stamina: +25% stamina, added to the additive stamina part (4.6).
- + Inventory: +100 bag spaces (4.36).
- Saitamo (999 Robux): an exclusive runner, only from this pass, never rolled, based on a real character under section 5. No license exists. The owner knows it is a close likeness sold directly through its own pass and advertised at the spawn, and accepts the takedown risk, which can remove the whole game (owner 2026-11-05). Base cruise 350, Balanced, Mythic look and stamina (**proposed**), no Series, not in the Index (**proposed**).
- Server Luck stays unsold until it is built. Auto Restart and Bank Insurance were offered and declined.

### 4.40 HUD entries and rarer big roll popup (owner 2026-11-05)
- Stats has no HUD tile. It is a category of the Rebirth panel: the header has REBIRTH and STATS tabs. The Rebirth tile opens on REBIRTH. The free stat point badge shows on the Rebirth tile and on the STATS tab.
- Items (Backpack) takes the Stats tile in the left grid: Index, Items, Rebirth.
- A new Auto button takes the bottom slot Items left, beside Upgrade. Its icon is the owner's green play triangle inside two circling arrows, label "Auto". The top-right row is Daily, Market, Settings.
- Auto state (owner 2026-11-05, replaces the grey icon and pulsing ring): the icon is green in both states; while auto race is on, its arrows spin around the still triangle. No spin during the 1 s press lock. It only asks: the server decides (`Remotes.SetAutoRace`).
- A roll gets the big popup (emphasized view and server announcement, `GachaConfig.IsEmphasized`) only when the character is undiscovered and at least 100 times rarer (`EMPHASIS_MULTI`) than the player's 3rd-rarest discovered character (`EMPHASIS_RANK`). With fewer than 3 discovered, the bar is 100 times the starter, which counts as 1 in 1: 1 in 100. The first 3 discoveries no longer pop up automatically. This replaces the earlier rule of "rarer than the 5th-rarest; any new character below 5 discovered".

### 4.41 Character bag and auto sell (owner 2026-11-04)
- The bag holds 80 characters. + Inventory adds 100. A new upgrade tree Inventory branch adds 50 per tier (5 tiers, **proposed**). Every copy takes 1 space.
- A full bag stops rolling until there is space. Only rolling is blocked: passes, daily rewards, codes and gifts still land. A save already over the cap keeps everything and cannot roll until it is below the cap.
- Full bag warning (owner 2026-11-05, replaces the fixed banner): auto roll is never turned off by a full bag and keeps trying at its normal pace. Each blocked try shows red "BAG FULL" text on the screen, with no background, gone within 1 second.
- Auto sell: the player fills in N in "1 in N", in Settings, in the auto-roll view and from a button under the roll (owner 2026-11-06). A roll whose `Chance` is at most N is sold for Money by rarity (prices **proposed**) and takes no space, a new discovery too (owner 2026-11-06, replaces duplicates only): it stays undiscovered. Default off.
- With auto sell on, a full bag keeps rolling and selling what is at or under N, and still shows the BAG FULL text. A roll rarer than N needs a space, so at a full bag it does not happen, with Rolls and Turbo unmoved (owner 2026-11-06).
- Selling never takes a copy a player already holds down to none: the last copy stays. Auto sell only ever sells the roll itself.
- Sell spares (orchestrator proposal, owner approved the plan 2026-11-04): a Backpack card sells spare copies of that character, never the last one, so a full bag can always be emptied. The player chooses how many and confirms in a dialog (owner 2026-11-05).
- Mass sell (owner 2026-11-05): the Backpack's Characters tab has a select mode to sell all spares of several characters at once, after one confirmation. The last copy of each stays.
- Sale prices are not scaled by Money multis. Spec: `docs/BAG_AND_AUTOSELL_SPEC.md`.

## 5. Characters and intellectual property (owner 2026-10-28)

- Characters are **based on real anime characters with tweaked names** (parody look-alikes), e.g. "Narito" for a
  well-known ninja hero. Each Series is a tweaked-name take on a real anime, and its preset trio is that anime's famous
  team.
- Risk accepted by the owner: rightsholders can still file DMCA takedowns against derivative characters, which removes
  the game (`docs/RESEARCH.md` section 2).
- Safeguards (owner-approved 2026-10-28):
  - Never use an official character name, series title, logo, sound, voice line or ripped model / texture. Character
    art is made in-house. World art, VFX and audio are made in-house or taken from free Roblox Creator Store assets
    (owner 2026-10-30): free only, no anime IP in them (no fan-made character models, show symbols or ripped
    assets), every script stripped, each id and its creator logged in the biome asset ledger.
  - Real character or series names never appear in the game title, description, thumbnails, icons, badges or
    developer product names.
  - Keep one list of every parody and its source (`docs/CHARACTER_GACHA_SPEC.md`) so a takedown can be answered by
    renaming / reskinning one character fast; character `Id`s never contain the real name, so a rename never touches
    saves.
  - Series initials in `Id`s and asset display names (`mha_`, `db_`, `ds_`, `jk_`) are allowed (owner 2026-11-03).
- Signature marks (owner 2026-11-03): a character's headband plate, crest, cloak pattern or emblem is modelled in-house;
  its shape follows the Marks rule below. Official logos and ripped art stay banned (first safeguard). Each mark is
  listed in `docs/CHARACTER_ART_REFERENCES.md` and checked by the rules auditor. The owner accepts the higher takedown
  risk.
- Art style (owner 2026-11-03): characters use Roblox avatar proportions and rendering (blocky R15 body, flat face, big
  mesh hair), inspired by anime Roblox games such as Anime Adventures, with no art copied from those games. Every
  character must be distinctly recognisable as its source character.
- Art direction (owner 2026-11-03): close to the original character design, not cute: small sharp faces, drawn clothing
  and muscle lines. The owner accepts the takedown risk of the closer likeness. Models stay in-house; no ripped art.
- Target look (owner 2026-11-03; overrides the art style and art direction bullets above where they differ): chunky
  blocky Roblox-like 3D figures with no ink outline, hard facets on every mesh and soft shading painted into the
  texture. Head about 1/3 of body height (proposed), faceted angular hair, real 3D clothes (baggy trousers, boots, cuffs,
  belts), chunky blocky limbs, hands plain smooth blocks with no fingers, models downsized to 0.8 scale (0.8 proposed;
  `RunnerFactory.SCALE`, every rig). Models stay hand-built in-house; the reference image is look-only and never ships.
- Marks (owner 2026-11-03; overrides the Likeness and Unique assets bullets on this point): logos and symbols get small changes (emblems, clan marks, plate marks, glyphs, badges, symbol tattoos and earrings): same place, size and colours, a clearly different shape. The overall design stays the same. Scars, clothes, hair and faces are not marks.
- Likeness (owner 2026-11-03): designs match the source characters; only the display name differs. Models are still made
  in-house, no ripped art. The owner accepts the takedown risk: a tweaked name is not a license.
- Unique assets (owner 2026-11-03): all 30 characters get their own painted texture and their own hair, drawn as close
  to 1-1 with the original design as possible. No shared hairstyles. Drawn and modelled in-house only: no ripped models,
  textures or image files. Display names stay tweaked (first bullet of this section).

## 6. Monetization rules (fixed; Roblox paid random items policy, updated 2026-08-19)

- Free auto-spins stay the main source of characters.
- Any spin bought with Robux, or with a currency bought with Robux, shows every outcome with its odds as a percentage
  (summing to exactly 100%) before purchase, behind a button labelled "Info" or "Details" (not a bare icon).
- Paid luck boosts and any pity system show the updated odds while active. The roll view and the luck Shop cards have a "Details" button listing every outcome as a percentage at the player's current luck (owner 2026-11-04).
- Users flagged by `PolicyService:GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`) get a free earnable
  path to every paid-random item, or see fixed disclosed outcomes; such items are not tradable.

## 7. Technical and data requirements

- Rojo project, Luau, `--!nonstrict`, tabs, same layout as IVS (`src/shared`, `src/server`, `src/client`).
- Save (`PlayerData` VERSION 1): `Money`, `Speed`, `Characters` (sorted owned ids), `Copies`, `Team = { id1, id2, id3 }`,
  `Rolls`, `StatAlloc` (incl. `Stamina`), potion counts, `Rebirths`, `Showcase`, `WorkshopLevel`, `AutoSell`, `AutoSellChance`. Unknown ids are kept. Stamina is never saved. Pass ownership is never saved: Roblox owns it.
  Boss-event fields (owner 2026-11-04): `docs/BOSS_EVENT_SPEC.md`.
- The server owns stamina, swaps, the race result and every payout. Clients see attributes and remote events only.

## 8. Open questions (owner)

None open here; 4.25 marks its own open question.

## Change log
- 2026-11-06: owner: boss Phase 2 (Fully Adapted Raga), team runs in a line with no revive until an 8.5 s team timer, 7,500 HP per player, stacking statuses of 15 s and 20 s, Slice 15% and 30%, Vulnerable, 5% damage for rewards, chests, rewards popup, 100,000 Money, 1,000 Gems as a fifth Gem source, art for every Relic (4.35, 4.37, 4.38, BOSS_EVENT_SPEC, RELIC_SPEC).
- 2026-11-04: owner: Gems (4.35), Sidekicks (4.36), boss events with Big Raga (4.37), Relics (4.38); speed multi gains Sidekick and Relic entries (4.13); arena exhaustion respawns the team (overrides 4.3 inside the arena).
- 2026-11-04: owner: Gems can be bought in packs, the only Sidekick monetization; luck never affects summons; summon page reference; Sidekicks Bag category of 50; auto-sell filter; selling refunds Gems (4.35, 4.36).
- 2026-11-04: owner: Pochito smooth and closer to source, Kaizel thin with neon blue, Igriz stays red (4.36, overrides section 5's target look for these models); Big Raga's wheel sits on top of its 560-stud height; arena radius 850 kept; event camera turns inward (BOSS_EVENT_SPEC).
- 2026-11-05: owner: upload the Saitamo likeness with no license, takedown risk accepted (4.39).
- 2026-11-04: owner: first gamepass list, exclusive runner Saitamo with a spawn pedestal, Workshop tier passes removed (4.13, 4.24, 4.39, MONETIZATION_SPEC). Character bag, auto sell, upgrade tree Inventory branch; sold duplicates pay Money (3, 4.41, BAG_AND_AUTOSELL_SPEC). "Details" odds list (6).
- 2026-11-05: owner: Stats moves into the Rebirth panel as a tab, Items takes its tile, a new Auto button takes the Items slot and replaces the top-right pill; big roll popup needs 100x the 3rd-rarest discovered, or 1 in 100 before 3 discovered (4.40).
- 2026-11-04: owner: UI feedback pass: impact, motion and sound paired across the UI; ServerStorage impact folder copied to the client at start; up to 4 extra sounds (4.33, UI_FEEDBACK_SPEC).
- 2026-11-04: owner: universal run: every character without a `RunStyle` gets the deep speed lean and the ninja run's effect (4.34).
- 2026-11-04: owner: villains are rollable and redesigned to the player cast's rules (4.32).
- 2026-11-04: owner: roll animation shows the rolled model, cycles in place, larger normal roll, reference-style emphasized roll, fits the roll interval, head-and-torso framing, Auto toggle beside Daily, roll at the very top, Quests above Shop, every character and enemy preview uses a drawn portrait (4.31, ROLL_ANIMATION_SPEC).
- 2026-11-04: owner: enemy showdown banners (4.28), Defeated Enemies page (4.29), Bleech series of 6 (4.30). Enemy aura is a plan only: `docs/ENEMY_AURA_PLAN.md`.
- 2026-11-04: owner: a screen-edge pointer shows the enemy while it is off screen (4.26).
- 2026-11-03: owner: every track NPC is an enemy from its biome's anime, with an always-visible name and arrow indicator; cast replaces the 2026-10-28 rivals (4.26).
- 2026-11-03: owner: phone and tablet HUD rules: pair stacks and hides under panels at height 400 or less, tablets shrink, Backpack tabs shrink as Market's, rolls behind loading are not judged (4.27).
- 2026-10-28: document created: full stamina refill per run, exhaustion cashes out.
- 2026-10-28: section 5: real anime characters with tweaked names, Series = tweaked real anime, preset trio = its famous
  team. Parody cast, 6 preset trios, 10 NPC rivals and safeguards approved.
- 2026-10-28: Stamina stat point, Stamina potions, runner categories, Series and preset bonus (4.5-4.8).
- 2026-10-28: IVS cars and car-only features removed; every car model scrapped, placeholder runner rig, anime hub, Dojo plots, spiral layout (4.1, 4.10).
- 2026-10-28: map redesign: tracks x1.25 longer each, anime biomes (4.9). Track 1 cliff faces approved.
- 2026-10-28: weather events carry over with 3 event-only characters (Giyo, Toje, Rojer).
- 2026-10-28: preset names tweaked (Sayan Pride, Kamada Squad); real-name checks in tests store hashes only; daily login's guaranteed rare stays "rarest unowned character".
- 2026-10-29: runner rig (WORLD_REDESIGN_SPEC 2): instant start with no Teleporting phase, seat-failure checks retired, runner-rig tile and pedestal art, camera follows the runner, avatar welded in the Torso, mid-race switch as in IVS.
- 2026-10-30: smooth motion (WORLD_REDESIGN_SPEC 2): the client interpolates the anchored runner, replacing the IVS "rail never snaps" rule; rail-fall recovery retired; instant start is solo only, duels keep the countdown hold.
- 2026-10-30: tracks very long, F = 3; biomes researched from public info (4.9). Speed matters more than stamina; Marathoner cruise x0.8 (4.3, 4.5).
- 2026-10-30: full biome worlds (4.9, BIOME_ENVIRONMENT_SPEC): terrain generated by code at every server start, plaza first; agents may upload meshes, textures and sounds under the owner's account, every id in a ledger; PC-first, heavy layers hook into REDUCED EFFECTS; built in the Team Create place.
- 2026-10-30: free Creator Store assets allowed with the IP check, scripts stripped, id + creator in the ledger (section 5). Biomes built one track at a time, with screenshots after each.
- 2026-10-30: TRACKS_AND_BIOMES_SPEC: Track 1 uses the plaza torii as its gate; dressing budget grows with track length; horizon pieces about 100 studs from the road.
- 2026-10-30: BIOME_ENVIRONMENT_SPEC 3.3, 4.3, 4.4: optional terrain `Sections` and `Craters`, hero landmark `At` pin, skybox rows take one Id or 6 Faces.
- 2026-10-30: c1 rulings (TEAM_AND_STAMINA_SPEC Run end): wins bank, exhaustion cashes out, loss empties; a loss reset refills stamina and restarts at slot 1, at the checkpoint track.
- 2026-10-31: track camera (4.12).
- 2026-10-31: Tracks 5, 7, 8 redesigned (TRACKS_AND_BIOMES_SPEC, section 5 safeguards kept): every track is based on an anime, none original. Track 5 is the burning city of the Jogo vs Sukuna fight (night, fire-lit); Track 7 is the Shibuya Incident subway, an enclosed tunnel opening into a few station platforms and concourses; Track 8 is Skypeia, NPC rival Enelu [Enel].
- 2026-10-31: Track 1 gate plaque may stay blank (BIOME_ENVIRONMENT_SPEC 7).
- 2026-10-31 (later): Track 7 gets one fight scene the player passes (BIOME_ENVIRONMENT_SPEC 7): parody look-alike figures under section 5, names internal only, never displayed. Overrides the Track 7 "no character likenesses" flag for this scene only.
- 2026-11-01: no Speed stat or speed gain; fixed cruise; speed multi (4.13). Rebirth rewards (4.14). Leaderboards removed (4.16). Biome popup (4.17). Loading at speed (4.18). Base speed table proposed by the orchestrator.
- 2026-11-01: Track 7's subway feels very wide along the whole route. Orchestrator default (owner delegated): target inner width 120 studs, ceiling 26, narrowed only where a neighbouring corridor would be crossed; props line both sides along the whole tunnel.
- 2026-11-01 (later): Level / XP removed, rebirth needs Money (4.14); Kami at 800 studs/s, HUD speedometer removed, upgrade tree Speed branch, Common / Uncommon / Rare cruise 24 / 33 / 48 (4.13); per-distance exhaustion, Track 1 not shortened, no map shift (4.3); Speed Doubler passes removed, Best Roll pedestal kept, per-slot aura / trail with UI (4.16); `RunTrack` biome (4.18); hero landmark LevelOfDetail set ahead of time (BIOME_ENVIRONMENT_SPEC 4.3).
- 2026-11-02: stamina lowered for track-by-track progression, 3 swappable Team slots, vertical blue bar (4.2, 4.3); category stamina x0.9 / x1.1 proposed (4.5). Sensei checkpoints and bonus (4.15).
- 2026-11-03: workshop stat boost replaces passive gain (4.19). UI animations (4.20).
- 2026-11-03: Track 1 balance kept; category info card (4.5); team row, stamina bar look (4.3); upgrade tree Stamina branch (4.6).
- 2026-11-03: team row after the owner's reference image: stamina arc, head breaks out of a dark circle (4.3, TEAM_AND_STAMINA_SPEC HUD).
- 2026-11-03: the 30 avatar models are the only rollable cast for now; event-only characters not rollable, stay in the Index; starter popup (3, 4.21).
- 2026-11-03: section 5 art rulings: Roblox avatar look, closer likeness, unique texture and hair for all 30, target look with hard facets and 0.8 scale, series initials allowed in ids, designs match the source with only the name differing; Lufy keeps the vest. Logos and symbols get small changes, overall design stays.
- 2026-11-03: rebirth gives +5% cruise per level (4.13, 4.14). Upgrade tree Money branch +10% per tier (4.13).
- 2026-11-03: c3 rulings: finish pads may use their biome's palette colour; Track 6 keeps one street-wall row; a team that tires on a track the NPC already finished is an exhaustion (bank and per-distance share paid), not a loss: a loss is decided only at the runner's finish.
- 2026-11-03: every character that can drop has a numerical drop chance. The catch-all Common is "1 in 1" (value **proposed**): it still takes every roll the rarer characters miss, so roll results do not change.
- 2026-11-03: Index and Backpack share one collection card, Backpack gets Sort and Search (4.22). Ninja run for all 5 Leaf characters (4.23).
- 2026-11-04: owner: Market's floating header matches Index and the service row instead of floating high above the stall (4.24, WORLD_REDESIGN_SPEC 7).
- 2026-11-04: owner: Legends cut to at most 2 beside the Race Start gate; Market stall rebuilt in-house with a smaller flat sign, free to start from scratch; `soul_lord` gets no Legend (4.24, WORLD_REDESIGN_SPEC 1, 7).
- 2026-11-04: owner: clear plaza (4.24, WORLD_REDESIGN_SPEC 4, 7): straight service row in the west opening, Rebirth shrine removed (HUD tile stays), Best Roll in a Dojo gap, Market sign replaces its arch, Market reduced to one stall (empty vendor stalls and courtyard removed), path torii, strings, banners, planters, benches and small trees removed, one sky-loop leg moved clear of the Market sign, the stray checker block removed from the Aura stall meshes.
- 2026-11-04: owner: service headers (4.24, WORLD_REDESIGN_SPEC 7): Index, Shop, Potions, Market, Sensei, Race Start and YOUR DOJO float a bold white italic label over a coloured emblem; the pills and arrows go; the flat signs stay.
- 2026-11-03: first impression pass (4.24, changes BIOME_ENVIRONMENT_SPEC 2.1): loading screen waits for what a player sees first, 8 s minimum; Market and Race Start marked in bold; plaza petals, ambience, solid sakura trunks, Index icon without a car. The Sea Legend on the plaza is Lufy (`sea_captain`), not `sea_gold`.
- 2026-11-03: orchestrator defaults, owner accepted: first auto-roll waits about 5 s after a starter pick; Daily panel does not auto-open until the first run ends (4.24). Orchestrator default: Studio-only `TestSaveKey` test saves (4.24).
- 2026-11-03: track loading: Tracks 1-5 before load-in, the rest behind the game by player proximity (4.25, not built yet).
- 2026-11-03 owner: doc trimmed; superseded text removed, no live rule changed.
- 2026-11-04: owner: auras and trails can be bought more than once, up to 3 copies of each at full price; the inventory holds the copies and one copy is worn on one team slot (4.13, TEAM_AND_STAMINA_SPEC).
- 2026-11-04: owner: admin test commands `/narito` and `/newplayer` (4.13).
- 2026-11-04: owner: new players start with auto-roll off and a spotlight tutorial turns it on (4.21).
- 2026-11-05: owner: boss event gains a 1 minute preparation with a team HUD, Big Raga rises at 1:00 and the fight runs to 8:00, late joiners get an auto-chosen team until 3:00, team damage is the Sidekick average times a capped speed scale (replaces speed not changing damage), boss HP locks at 3:00, a red event header and a server-wide red chat message mark the spawn (4.37).
- 2026-11-05: owner: Sidekick summon shows actual models; portraits only in the Sidekick index and Bag equip (4.36).
- 2026-11-05: owner: Big Raga Sidekick drops from a boss defeat at 0.001%; Sidekicks page in the Index (4.36, 4.37).
- 2026-11-05: owner: auto-roll pauses only for participants; arena has a leave option; players in a duel can teleport in (4.37). Owner confirmed the 12-Sidekick pool's rates from the roster session (Legendary 1% each, Mythic 0.5% each, Secret 0.001% each; Pochito Common, Kaizel and Igriz Mythic), to be written into 4.36 with its table when its art is approved.
- 2026-11-05: owner: the Big Raga Sidekick drop may overflow the Sidekick bag (4.37). Summon screen accepted as a placeholder; its visuals follow a 30 minute rotation of the characters in the gacha pool, not yet specified.
- 2026-11-05: owner: 12-Sidekick pool (roster session's table) and a global 30 minute summon rotation with a hidden Secret (4.36).
- 2026-11-05: owner: Big Raga's spawn takes 2-3 seconds with the HP bar; each of its attacks takes 5% stamina from running characters; players get a wider FOV in the event and Sidekicks and their attacks must read clearly (4.37). Pity and banner work belong to the summon redesign session.
- 2026-11-05: owner: Big Raga's shout lowers players' damage for 5 seconds; its wheel turn gives it 10% damage reduction; both show as status effects under the HP bar (4.37).
- 2026-11-05: owner: Sidekick summon pity, Mythic at 300 and Legendary at 100 (4.36), relayed by the summon redesign session; replaces the spec's no-pity line for Sidekicks only.
- 2026-11-05: owner: pity details (Mythic resets only its own count, Mythic wins a tie, the tutorial summon counts, Secrets are independent); boss exhaustion view (4.36, 4.37).
- 2026-11-05: owner: summon page redesign from a new reference, this page only; Mythic pity at 300 carrying across rotations (replaces no pity); the Secret shows as a silhouette; rotation timer on the page (4.36).
- 2026-11-05: owner: Mythic pity 300 and Legendary pity 100 approved, with a Legendary pity bar; Details shows the live Secret's silhouette, rarity and chance, with no name column; the live Secret's id may reach clients (4.36).
- 2026-11-05: owner: Rare models join the summon poster with rates shown in it; the Secret moves to Details; a summon reveal in the style of anime tower defense games, original effects (4.36).
- 2026-11-05: owner: the spawn warning is flashing text with no border or background; Roblox chat notes each Big Raga attack, shout and wheel turn for players in the event; in the plaza the invite shows for 3 seconds, then teleporting stays open from the top-left Boss button, reading (Active), glowing and pulsing in size (4.37).
- 2026-11-05: owner: boss bar layout with a colour-coded Drop list of Relic rates and Big Raga's rate in black (4.37, `BOSS_EVENT_SPEC`).
- 2026-11-05: owner: VIP gets 10% off Sidekick summons (4.36), relayed by the monetization session, reversing the earlier no-discount line. That session creates all 5 products.
- 2026-11-05: owner: exhaustion camera hovers above the runner, replacing the front aerial view (4.37).
- 2026-11-06: owner: auto sell takes everything at or under N, new discoveries too; a full bag keeps auto selling and keeps warning (4.41).
- 2026-11-06: owner: a team bonus depends on the team alone, so an event's bonus comes from the event team (4.37); an auto sell button under the roll, with auto roll (4.41).
- 2026-11-05: owner: boss start: team saved from the last event, average stamina on the team HUD, X to close with at least 1 character, red warning, display-only team run, Edit Team button, jump and smoke cutscene with the fight at 3 s, no team edits for late joiners, 5,000 HP per player, event timer, red and yellow animated damage numbers (4.37).
- 2026-11-05: owner: playtest notes: Big Raga's rise is 1.5 s, replacing 2-3 s; Bosses button and popup; separate event roster on the minibar, greyed with a revive fill during the wait (4.37). Sidekick and Relic click menu, character picker, sale confirmation (4.36). Relics sell for Money; Index Relics page (4.38). Auto icon stays green, arrows spin when on (4.40). Red fading BAG FULL text replaces the banner; click and mass sell of spares (4.41).
- 2026-11-05: owner: enemies much faster. A Common does not outrun the Track 1 enemy and a Rare is about level with it; NPC formula `48 x 1.363^(n-1)` (placeholder), replacing `16 x 1.51^(n-1)` and the 2026-11-03 "Track 1 balance kept" (4.13).
- 2026-11-04: owner: Tracks panel is one list of long horizontal cards with a road screenshot, a brief anime-context definition, recommended speed and enemy name; a card click picks the checkpoint; no 3D render, detail pane or START HERE (4.15).
