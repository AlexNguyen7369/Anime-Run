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

The game is the same concept as IVS, with cars replaced by characters and the single equipped car replaced by a
3-character team with stamina.

## 2. Core loop

1. Auto-spin characters (free, every `ROLL_INTERVAL` seconds) and discover them in the Index.
2. Build a team of up to 3 characters (order matters).
3. Start a run on the start pad: the team auto-runs Track 1, 2, 3 ... against each track's NPC rival.
4. Each track won adds its pad value to the run's bank (UNBANKED).
5. The run ends:
   - **Team exhausted** (all 3 at 0 stamina): the bank is cashed out into Money; the player returns to the spawn.
   - **Player stops** (Stop button, death, leave): the bank is cashed out.
   - **Loss** (NPC reaches a track's finish first): the bank is emptied; loser screen; back to the start track.
6. Each character runs at a fixed cruise speed (rarity x category, times the speed multi; 4.13). There is no Speed stat (owner 2026-11-01).
7. Money buys upgrades; rebirth needs and resets Money for luck, speed and a stat point (4.14). There is no player level or XP.

## 3. Rules carried over from IVS unchanged (rename only: car -> character)

| Rule | IVS source |
|---|---|
| Numbered, point-to-point track chain; each track starts on the previous finish; loops back to Track 1 after the last | `TrackBuilder`, `TrackValidator` |
| Wide checkpoint area and WinPad at each finish; pad `Cash = PayoutCurve.Cash(n)` ($100 on Track 1, then x10 / x7.5 alternating) | `PayoutCurve` |
| One NPC rival per track, client-side only, left lane; player wins if they reach the finish before the NPC's known time | `NpcRacer`, `NpcConfig` |
| Banked money in NPC mode; loss empties the bank; cash-out on stop / death / leave | `RaceService` |
| RETIRED 2026-11-01 (4.13): Speed stat (`leaderstats.Speed`) grows with actual speed while running; cruise = log curve of the stat, capped at `MAX_CRUISE` | `RaceConfig` |
| The runner holds exact cruise speed everywhere (no acceleration, no corner slowing) | `RaceService` rail |
| Auto-roll every 3 s (placeholder), turbo luck every 10th roll x10 (placeholder), rarest-first roll check `min(1, luck / Chance)` | `GachaConfig` |
| Index: discovering = owning; stat points from unique discoveries; allocations saved, points derived | `GachaService` |
| Duplicates add `Copies` and pay no Money | IVS 2026-10-22 |
| Workshop plots (Dojos) and the Showcase of 3 characters (Dojo squad); passive gain replaced by a chosen stat boost (4.19, owner 2026-11-03) | `WorkshopService` |
| Weather events (Rain, Night Race, Gold Rush, Clear, Aurora) ; 3 event-only characters, not rollable for now, listed in the Index as undiscovered tiles, kept in saves that own them (owner 2026-11-03, replaces rollable during their event) | IVS `docs/WEATHER_EVENTS_SPEC.md` |
| Rebirth resets Money (Speed retired 2026-11-01, 4.14) | `RebirthService` |
| Session-locked saves through `UpdateAsync` | `PlayerData` |
| Server decides every number that matters; the client only displays | IVS "Technical and data requirements" |

## 4. What changes

### 4.1 Characters replace cars
- A character is a catalog entry with a permanent `Id`, `Name`, `Rarity`, `Chance` (1 in N), `SpeedMulti`, `Stamina`,
  `Category` (4.5), `Series` (4.8) and an archetype. Spec: `docs/CHARACTER_GACHA_SPEC.md`.
- Character `SpeedMulti` scales cruise speed (damped, like the IVS car cruise multi). It never scales Speed-stat gain.
  RETIRED 2026-11-01: cruise is fixed by rarity x category (4.13).
- The player runs on foot as the active character (a rigged, animated model on the race rail). There is no vehicle.

- IVS cars and car-only features are not part of Anime Run (owner 2026-10-28): the 111 IVS car entries, car models,
  gamepass cars, the Ember Wyvern dragon and the Singularity orb are removed. Every car model, the car body included,
  is scrapped; characters run as a placeholder anime runner rig on the race rail (owner 2026-10-28, section 4.10;
  replaces the same day's "keep the car body" decision).

### 4.2 Team of 3
- The player equips a **team**: 3 ordered slots. The same character may not be in two slots. A team needs at least
  1 character. Spec: `docs/TEAM_AND_STAMINA_SPEC.md`.
- Slot 1 starts every run; slot 2, then slot 3, take over when the one before is empty.
- The player fills and swaps the 3 slots on foot (owner 2026-11-02): pick a character in the Backpack, then tap slot
  1, 2 or 3 to put it there (a character already on another slot swaps places; tapping its own slot takes it off).
  The single equip (Index, roll toast) puts a character on slot 1.

### 4.3 Stamina
- Every character has a stamina bar (0-100%). It drains only while that character is running.
- The drain rate depends on rarity (owner 2026-11-02, track-by-track progression; replaces the 2026-10-30 values
  Common 20 .. Secret 43): Commons tire at about 12-15 s and Secrets at 30 s. Seconds of running (in-between values
  proposed): Common 13.5, Uncommon 15.5, Rare 18, Epic 21, Legendary 24, Mythic 27, Secret 30.
- Speed matters more than stamina (owner 2026-10-30): the rarity spread in stamina is small. A team clears a few
  tracks per run and progresses track by track through checkpoints (4.15), not the whole chain in one run.
- While a runner runs, a vertical blue stamina bar is fixed to the right of its visible character (owner 2026-11-02),
  showing the active slot's stamina. Client display of the server's `Stamina<n>` / `RunSlot`.
- At 0 stamina the next non-empty slot takes over at once, at its own cruise speed. The NPC race timer keeps running.
- Stamina refills to 100% for every character at the start of every run (owner 2026-10-28). It never carries over.
- Stamina bar look (owner 2026-11-03): the bar drains smoothly, a lighter trail shows the stamina just lost, the fill
  turns from blue to amber to red as it runs low (thresholds placeholder: 50% / 25%) and pulses when low, and it
  refills with a flash when the next runner tags in. Display only.
- Team row (owner 2026-11-03, replaces the rarity-colour ring of 2026-11-02): each portrait is only the character's
  avatar head; rarity is not shown on the row. The current runner gets a clear animated indicator (enlarged, glowing
  ring, a bobbing marker, and every portrait shows its stamina on a thick arc, owner 2026-11-03 later the same day, replaces the liquid level,
  with its stamina seconds left as a number, orchestrator default); tired runners grey out with an animation; the tag-in
  plays a short pop. The team bonus (4.8), if any, shows as a small badge on the row.
- When the last character reaches 0 the run ends as a **soft end**: the bank is cashed out (owner 2026-10-28).
  Exhaustion pays per distance (owner 2026-11-01): the track being run when the team tires adds
  `PayoutCurve.Cash(n) x distance covered / track length` to the bank before the cash-out (share placeholder 1.0).
  Track lengths are unchanged; Track 1 is not shortened (owner 2026-11-01). Owner 2026-11-03: Track 1 balance is fine
  as is (no retune of Common speed, stamina or Track 1 length).

### 4.4 Losing stays a speed comparison
- Losing a track is unchanged: the NPC's track time is fixed when the track starts; if the player's team reaches the
  finish later, the player loses. A swap to a slower character mid-track can turn a win into a loss: team order is
  part of the strategy.

### 4.5 Runner categories (owner 2026-10-28)
- Every character has one category that trades speed against stamina (multipliers placeholder):
  - **Sprinter**: cruise SpeedMulti x1.25, stamina x0.9 (proposed 2026-11-02, was x0.8, so Commons stay in 12-15 s).
  - **Balanced**: x1, x1.
  - **Marathoner**: cruise SpeedMulti x0.8 (owner 2026-10-30, was x0.85), stamina x1.1 (proposed 2026-11-02, was x2.0).
- Rarity still sets the base speed and base stamina; the category scales them. The category speed multiplies the
  damped cruise multi (after `CruiseStatMulti`), so Marathoner x0.8 is a real 20% slower (owner 2026-10-30); it
  counts inside `MAX_CRUISE_TOTAL_MULTI` and `MAX_CRUISE`.
- Shown to the player (owner 2026-11-03): hovering a team row portrait (tap on touch) opens an info card with the
  character's name, its category with the category's speed and stamina effect, its cruise (studs/s) and its stamina
  (seconds). The card does not show rarity.

### 4.6 Stamina stat point (owner 2026-10-28)
- Index stat points can be put into a new stat **Stamina**: each point adds +5% stamina to every character
  (placeholder), additive with other points like the IVS stats.
- Upgrade tree **Stamina** branch (owner 2026-11-03): each owned tier adds +% stamina to every character, added to the
  Stamina stat points' part: `1 + 0.05 x Alloc_Stamina + tree bonus` (placeholder +10% per tier, 5 tiers, +50% max).
  Priced like the Speed branch (weight 1, placeholder). It sits on the free hex direction off Start.

### 4.7 Stamina potions (owner 2026-10-28)
- A new potion category **Stamina** (IVS `BoostConfig` pattern): a timed boost, x1.5 stamina for every run started
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
- Tracks are very long and get longer (owner 2026-10-30): every track is the old length times a base factor, growth
  per track stays x1.25. Track n is `984 x F x 1.25^(n-1)` studs, F = 3 (owner confirmed 2026-10-30; Track 1 about 2,950, Track 10
  about 22,000). Track 1 gets a new, longer layout. NPC speeds are unchanged; stamina is retuned (4.3, owner
  2026-10-30).
- Every track has an anime-inspired biome: one per series (Tracks 1-6, in series order) plus 4 classic anime worlds
  (Tracks 7-10). Biomes follow section 5 (evoke, never copy logos or symbols). Spec: `docs/TRACKS_AND_BIOMES_SPEC.md`.
- Biomes are researched (owner 2026-10-30): before building a track layout or biome, research public information on
  its anime (locations, layout, architecture, palette, landmarks) and match it closely in layout, assets and world
  building. Section 5 safeguards still hold: no logos, symbols, real names, show kanji, ripped assets or exact copies
  of an iconic design.
- Full biome worlds (owner 2026-10-30, goal `biomes`): each track is a full world, not props along a road. The layers
  are code-generated Terrain + water, in-house uploaded meshes, per-zone client atmosphere (sky, lighting, fog, grade,
  particles) and ambient audio. Biome sky and light changes are client-local only; the server's `Lighting` stays
  untouched. Heavy layers follow the REDUCED EFFECTS setting. Spec: `docs/BIOME_ENVIRONMENT_SPEC.md`.

### 4.11 Speed stat scale (owner 2026-10-30) - RETIRED 2026-11-01 with the Speed stat (4.13)
- The Speed stat shows bigger numbers with the same gameplay: every Speed stat amount is the old amount x
  `STAT_SCALE = 1e15 / 3e5` (about 3.33e9), so 1 Qd new = 300K old (about where a Legendary trio clears all 10 tracks).
- Scaled together so cruise speed and time to reach it are unchanged: `RaceConfig.HALF_STAT`, `GAIN_PER_SECOND`,
  `MAX_STAT` (test reference), `WorkshopConfig.BASE_RATE`, and every other flat Speed amount (rewards, codes, tests).
  Multipliers (rebirth, stat points, potions) do not change. `BASE_SPEED`, `MAX_SPEED` and `MAX_CRUISE` are studs/s
  and do not change.
- Old saves (owner 2026-10-30): pre-scale test saves are wiped, not rescaled. The save store is `PlayerStats_v2` and
  the Speed board store `LB_Speed_v3` (v2 held raw scores before the log-scaled score); older stores stay untouched.
- `PlayerData.MAX_ADD` (most one AddSpeed call adds) is a flat Speed amount and scales: `1e18 x STAT_SCALE`.
- HUD (owner 2026-10-30): Speed keeps suffixes from `SPEED_SUFFIX_FROM = 1e6` (placeholder); the threshold does not scale.
- Speed board (owner 2026-10-30): the Speed board stores a log-scaled integer score, so any finite Speed ranks
  (no tie at the int64 cap); the board shows the real Speed decoded from it. Encoding (proposed):
  `score = floor(log10(1 + whole Speed) x 1e15)` (whole Speed = floored, as the board always used),
  `Speed = 10^(score / 1e15) - 1`. Other boards are unchanged.
- Test precision (owner 2026-10-30): above the new `MAX_STAT` a double cannot keep decimals, so
  `admin_addspeed_past_max_stat_not_clamped` proves only "past MAX_STAT, not clamped" (its decimal part rounds away).

### 4.10 World redesign (owner 2026-10-28)
- The whole map is redesigned after f2: anime town plaza hub at the centre, 7 player plots (Dojos) around it, the
  track chain spiralling out from the hub's start gate through the 10 biomes. Spec: `docs/WORLD_REDESIGN_SPEC.md`.
- Player plots keep the workshop rules; the IVS Showcase becomes the Dojo squad: 3 owned characters not in the
  racing Team train there and multiply idle Speed gain. A character is in the Team or the Dojo squad, never both.

### 4.12 Track camera (owner 2026-10-31)
- While the local player's runner is racing, the camera yaw follows the runner's direction of travel along the track,
  like shift-lock. The player still pitches and zooms; turns are smoothed, never snapped.
- A Settings toggle, TRACK CAMERA, switches it. Off = the regular camera, as before. Default ON (placeholder).
- Client-only display; no server number changes. Spec: `docs/CAMERA_SPEC.md`.

### 4.13 Fixed character speed, no Speed stat (owner 2026-11-01)
Replaces the Speed stat growth (sections 2.6, 3 "Speed stat" row, 4.11) and the per-character `SpeedMulti`.
- There is no Speed stat and no speed gain. Each character has a fixed cruise speed (studs/s) set only by its rarity
  and its category (4.5). New players run slow.
- Base cruise by rarity, Balanced (proposed 2026-11-01, tuned so each rarity tops out about one NPC band; NPC formula
  unchanged, `16 x 1.51^(n-1)`): Common 24, Uncommon 33, Rare 48, Epic 90 (low rarities raised slightly, owner 2026-11-01; was 20 / 30 / 45), Legendary 200, Mythic 450, Secret 700.
  Category multiplies it: Sprinter x1.25, Balanced x1, Marathoner x0.8 (4.5).
- Speed multi = everything that scales that fixed cruise, multiplied together, capped by `MAX_CRUISE` (800 studs/s):
  - Index stat points in Speed: +% cruise per point (placeholder +2% per point, additive with the other stat points).
  - Speed potions: timed x cruise (IVS potion pattern; placeholder x1.25).
  - Upgrade tree **Speed** branch (replaces "Speed Gain", owner 2026-11-01): each owned tier adds +% cruise to the
    character, additive with the Speed stat points (placeholder +10% per tier, 5 tiers, +50% max).
  - Preset team bonus x1.1 (4.8).
  - Upgrade tree **Money** branch (owner 2026-11-03, replaces the IVS +50%): +10% Money per tier, 5 tiers.
  - Auras and trails: one aura and one trail equippable per team slot; each slot's aura and trail scale only that
    slot's character (damped, as `RaceConfig.ItemCruiseMulti`).
  - Rebirth: +5% cruise per rebirth level (owner 2026-11-03, placeholder; 4.14), additive with the Speed stat points
    and the upgrade tree Speed branch; its +1 stat point can also go into Speed.
- Removed: `leaderstats.Speed`, Speed gain while running, Speed rewards and codes, the Speed leaderboard, gate signs
  showing a Speed requirement. Saved `Speed` is ignored (kept in old saves, never read).
- Workshop / Dojo idle gain gives Money instead of Speed, for now (owner 2026-11-01); the Dojo squad and the
  `Workshop` stat point still multiply it. Rate is a placeholder. RETIRED 2026-11-03: no passive gain (4.19).
- Admin test runner Kami (owner 2026-11-01): admin command `/kami [player]` gives and equips Kami for the session
  only (never saved, never rolled, not in the index). Kami cruises at 800 studs/s, equal to `MAX_CRUISE`
  (owner 2026-11-01, was 1 Sp).
- HUD (owner 2026-11-01): the speedometer and the cruise read-out (`RacerHud/Speed`) are removed. The profile's
  CRUISE row and the character cards still show cruise.

### 4.14 Rebirth (owner 2026-11-01)
- Each rebirth level gives: luck multi, +5% cruise (owner 2026-11-03, replaces "no speed gain"; placeholder,
  `RebirthConfig.SPEED_PER_REBIRTH`, +100% at rebirth 20, capped by `MAX_CRUISE`) and +1 stat point (the "stat boost").
  The Rebirth panel shows all three rewards, with the speed icon on the speed tile. Luck and speed show the total after the
  next rebirth; the stat point tile shows the points that rebirth gives.
- Rebirth resets Money (there is no Speed to reset).
- Player levels and XP are removed (owner 2026-11-01, later). Rebirth n+1 needs Money >= `BASE_MONEY` x
  `MONEY_GROWTH`^n: $100K for rebirth 1, x10 each after (placeholder; `RebirthConfig`). Old saves keep `Level` / `XP`
  unread. The rebirth XP multi is gone; the luck totals table is unchanged.

### 4.15 Sensei checkpoints (owner 2026-11-02; replaces the informational sensei of 2026-11-01)
- The plaza sensei opens the Tracks panel: an overview of each track (name, biome, length, NPC rival, payout) where
  the player also picks a **checkpoint**, the track their runs start on (`Remotes.SetCheckpoint`, server-validated).
- Track 1 is always open. Track n opens once Track n-1 is beaten (`BestTrack >= n - 1`): the player can pick up to
  the track they are stuck on; every later track stays locked until they pass it.
- The pick is saved (`Checkpoint`) and clamped to what is open. A run starts on the checkpoint track; a loss sends the
  runner back to the start of the checkpoint track; after the last track the run loops back to it.
- **Checkpoint bonus**: in one run, each track won after the checkpoint track pays its pad cash x
  `min(BONUS_CAP, 1 + BONUS_PER_TRACK x k)`, k = tracks past the checkpoint track (placeholders +10% per track, cap
  x2; `CheckpointConfig`). The checkpoint track itself pays x1. k restarts when the runner goes back to the
  checkpoint (loss, loop) or the run ends (stop, team exhausted).
- A won track that paid the bonus shows a popup "CHECKPOINT BONUS x1.2 · $paid" (placeholder art and timing:
  0.25 s in, 1.5 s hold, 0.5 s out; client-only display, owner 2026-11-02).

### 4.16 Leaderboards removed (owner 2026-11-01)
- All leaderboards are removed from the plaza for now (clutter at the spawn). Board data stores are left untouched.
- The Best Roll pedestal stays and keeps showing the server's best roll (owner 2026-11-01).
- Speed Doubler game passes are removed for now (owner 2026-11-01); nothing else in the shop changes.

### 4.17 Biome welcome popup (owner 2026-11-01)
- When the local player's runner enters a new biome, a small popup fades in with the biome's display name (e.g.
  "Shibuyo Underground") and fades out (placeholder: 0.4 s in, 2 s hold, 0.6 s out). Client-only display.

### 4.18 Loading at high speed (owner 2026-11-01)
- Biome meshes and textures must be loaded before a fast runner reaches them; sky and lighting must switch quickly at
  a biome boundary at any speed. Audit mesh / texture loading and pick the cheapest approach that keeps up at
  `MAX_CRUISE`. Client display only.
- Biome while racing (owner 2026-11-01, later): the server publishes `RunTrack` (the track whose finish pad is still
  ahead) on the runner rig; the client takes the biome from it and switches at once at the finish pad. The nearest
  centre line (`ZoneAt`) is used only while walking. The speed look-ahead is removed (it switched ~280 studs early at
  800 studs/s and could pick a neighbouring track).

### 4.19 Workshop stat boost (owner 2026-11-03; replaces the workshop / Dojo idle gain)
- There is no passive gain: standing in the Dojo earns nothing, there is no offline workshop credit and no extra luck
  while standing in the zone.
- The player picks **one stat** for their workshop to boost: Money, Luck, Speed or Stamina (owner 2026-11-03). The
  choice is saved (`WorkshopStat`, default Money) and can be changed at any time.
- The boost % comes from the combined rarity of the 3 characters on the Dojo squad (the Showcase, WORLD_REDESIGN_SPEC
  5): each character gives rarity points, Common 1, Uncommon 2, Rare 3, Epic 4, Legendary 5, Mythic 6, Secret 7; the
  sum x 5% (placeholders, owner 2026-11-03) is the boost. 3 Commons = +15%, 3 Secrets = +105%. Empty slots give 0.
  Copies no longer count (proposed 2026-11-03).
- Workshop levels stay (bought with Money, same prices) and scale the boost (owner 2026-11-03): boost x
  (1 + 0.1 x (level - 1)) (proposed placeholder; level 10 = x1.9).
- The boost applies always, everywhere, runs included (owner 2026-11-03). It is added to the chosen stat like the
  upgrade tree bonus (proposed): Money and Luck to their `1 + points + tree` part; Speed to the speed multi's
  `1 + points + tree` part (cruise still capped at `MAX_CRUISE`); Stamina to the stamina multi's `1 + points + tree`
  part (4.6). Speed and Stamina are fixed at run start, like every other run multi.
- The `Workshop` stat point is retired (owner 2026-11-03): allocated Workshop points are refunded as free points.

### 4.20 UI animations across the board (owner 2026-11-03)
- Every player-facing UI animates (owner 2026-11-03). Display only; every animation goes through `Client/UiMotion`, so
  Roblox Reduced Motion and the in-game REDUCED EFFECTS land it at once. Timings below are proposed placeholders.
  - Panels (every PanelSwitch panel): open = scale 0.9 -> 1 with Back easing + fade in, ~0.2 s; close = scale to 0.95
    + fade out, ~0.12 s. List / grid items stagger in on open (~0.03 s apart, at most ~0.3 s total).
  - Buttons (HUD, panels, tabs): hover grows, press shrinks, release pops back (sizes stay the HUD layout rule's
    1.035 / 0.97, orchestrator default 2026-11-03); disabled buttons do not move.
  - Tabs and selections: the active marker slides / tweens to the new tab; selected tiles pop.
  - Numbers: HUD counters (Money, Unbanked) count up / down over ~0.3 s; panel numbers update at once so no number
    is ever shown wrong (orchestrator default 2026-11-03).
  - Toasts, popups and banners: slide + fade in, hold, fade out; badges pulse while something is claimable.
  - Gameplay feedback stays readable: no animation hides a number or blocks input for more than ~0.2 s.

### 4.21 Starter choice (owner 2026-11-03)

- A new player gets a popup and chooses one of 3 starter characters: Ruffy, Karate Kid, Sayan. The pick is their first
  Team member; they roll the next two to fill the Team. Saves that already have rolls or characters get no popup.
- Starters are not rollable and not in the Index, like the old `starter`. Stats are **proposed**: Common, cruise as the
  old starter, Balanced, no Series. Look: same model as Lufy, Narito, Gokku (mapping **proposed**: Ruffy = Lufy,
  Karate Kid = Narito, Sayan = Gokku).
- Auto-roll waits until the player has picked. The roster in play is these 30 models plus the 3 starters that reuse them.

### 4.22 Collection cards: Index and Backpack Characters (owner 2026-11-03)

- Inspired by the owner's reference screenshot of a collection screen; layout ideas only, no copied art. Index tiles and
  Backpack Characters tiles share one card (`Components.CardFace`): rarity-tinted background, rarity inner border (Secret
  rainbow), the character's upper body filling the card, cruise in gold above a bold name, category badge top right.
  Outer border: green = on the Team, white = picked (Backpack), dark otherwise. Sizes, colours and cell counts are
  **proposed** placeholders.
- Index: undiscovered cards stay a black silhouette with "?", rarity and public odds; discovered cards add name, cruise,
  category and Equip. Catalog order is unchanged.
- Backpack Characters: a Sort button (Rarity, Speed, Stamina; **proposed**) and a name search in the header. The default
  stays Rarity, least rare first (owner 2026-10-20). Top left of a card: `TEAM <slot>` on the Team, otherwise copies when
  more than 1. Display only: the server still decides every number and every Team change.

## 5. Characters and intellectual property (owner 2026-10-28, replaces "original only")

- Characters are **based on real anime characters with tweaked names** (parody look-alikes, owner 2026-10-28), e.g.
  "Narito" for a well-known ninja hero. Each Series is a tweaked-name take on a real anime, and its preset trio is
  that anime's famous team.
- Risk accepted by the owner: rightsholders can still file DMCA takedowns against derivative characters, which removes
  the game (`docs/RESEARCH.md` section 2).
- Safeguards (owner-approved 2026-10-28):
  - Never use an official character name, series title, logo, sound, voice line or ripped model / texture. Character
    art is made in-house. World art, VFX and audio are made in-house or taken from free Roblox Creator Store assets
    (owner 2026-10-30): free only, no anime IP in them (no fan-made character models, show symbols or ripped
    assets), every script stripped, each id and its creator logged in the biome asset ledger.
  - Real character or series names never appear in the game title, description, thumbnails, icons, badges or
    developer product names.
  - Signature marks (owner 2026-11-03, later the same day; replaces "clearly altered"): a character's headband plate,
    crest, cloak pattern or emblem may closely resemble the original, modelled in-house. Official logos and ripped
    art stay banned (first safeguard). Each mark is listed in `docs/CHARACTER_ART_REFERENCES.md` and checked by the
    rules auditor. The owner accepts the higher takedown risk.
- Art style (owner 2026-11-03, replaces the shared chibi base): characters use Roblox avatar proportions and rendering
  (blocky R15 body, flat face, big mesh hair), inspired by anime Roblox games such as Anime Adventures, with no art
  copied from those games. Every character must be distinctly recognisable as its source character.
- Art direction (owner 2026-11-03, later, from reference screenshots of anime Roblox games): close to the original
  character design, not cute: small sharp faces, inked outlines, painted cel shading, drawn clothing and muscle lines.
  The owner accepts the takedown risk of the closer likeness. Models stay in-house; no ripped art.
- Target look (owner 2026-11-03, latest, from a reference image of the 4 pilots; overrides the art style and art direction
  bullets above where they differ): chunky blocky Roblox-like 3D figures with no ink outline, hard facets on every mesh and soft shading painted into the texture (owner, same day). Head about
  1/3 of body height (proposed), faceted angular hair, real 3D clothes (baggy trousers, boots, cuffs, belts), chunky
  blocky limbs, hands plain smooth blocks with no fingers (owner, same day), models downsized to 0.8 scale (owner asked for smaller, 0.8 proposed; `RunnerFactory.SCALE`, every rig). Models stay hand-built in-house; the reference image is look-only and never ships.
- Likeness (owner 2026-11-03, latest): designs match the source characters; only the display name differs. Models are still made
  in-house, no ripped art. The owner accepts the takedown risk: a tweaked name is not a license.
- Unique assets (owner 2026-11-03, later; overrides the signature-mark rule above where they differ): all 30 characters
  get their own painted texture and their own hair, drawn as close to 1-1 with the original design as possible,
  marks included. No shared hairstyles. Drawn and modelled in-house only: no ripped models, textures or image files.
  Display names stay tweaked (first bullet of this section).
  - Keep one list of every parody and its source (`docs/CHARACTER_GACHA_SPEC.md`) so a takedown can be answered by
    renaming / reskinning one character fast; character `Id`s never contain the real name, so a rename never touches
    saves.
  - Series initials in `Id`s and asset display names (`mha_`, `db_`, `ds_`, `jk_`) are allowed (owner 2026-11-03).

## 6. Monetization rules (fixed; Roblox paid random items policy, updated 2026-08-19)

- Free auto-spins stay the main source of characters.
- Any spin bought with Robux, or with a currency bought with Robux, shows every outcome with its odds as a percentage
  (summing to exactly 100%) before purchase, behind a button labelled "Info" or "Details" (not a bare icon).
- Paid luck boosts and any pity system show the updated odds while active.
- Users flagged by `PolicyService:GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`) get a free earnable
  path to every paid-random item, or see fixed disclosed outcomes; such items are not tradable.

## 7. Technical and data requirements

- Rojo project, Luau, `--!nonstrict`, tabs, same layout as IVS (`src/shared`, `src/server`, `src/client`).
- Save (`PlayerData` VERSION 1): `Money`, `Speed`, `Characters` (sorted owned ids), `Copies`, `Team = { id1, id2, id3 }`,
  `Rolls`, `StatAlloc` (incl. `Stamina`), potion counts, `Rebirths`, `Showcase`, `WorkshopLevel`. Unknown ids are kept. Stamina is never saved.
- The server owns stamina, swaps, the race result and every payout. Clients see attributes and remote events only.

## 8. Open questions (owner)

None open. Workshop gain answered 2026-11-01 (4.13: Money, for now).
 The Speed-scale save question of 2026-10-30 was answered the same day (4.11: wipe).

The four questions of 2026-10-28 were answered the same day (sections 4.5-4.8).

## Change log
- 2026-11-03: owner: every character that can drop has a numerical drop chance. The catch-all Common is "1 in 1" (value
  **proposed**): it still takes every roll the rarer characters miss, so roll results do not change.
- 2026-11-03: owner: Index and Backpack Characters use one collection card; Backpack gets Sort and Search (4.22).
- 2026-11-03: owner: team row rebuilt after the owner's reference image: stamina arc replaces the liquid level, head
  breaks out of a dark circle (4.3, TEAM_AND_STAMINA_SPEC HUD).
- 2026-11-03: owner: rebirth gives real speed again: +5% cruise per rebirth level (placeholder), shown with a speed
  icon on the Rebirth panel (4.13, 4.14).
- 2026-11-03: owner (c3 rulings): finish pads may use their biome's palette colour (not always yellow); Track 6 keeps
  one street-wall row; a team that tires on a track the NPC already finished is an exhaustion (bank and per-distance
  share paid), not a loss: a loss is decided only at the runner's finish.
- 2026-11-03: owner: upgrade tree Money branch is +10% per tier (code since u4; IVS had +50%).
- 2026-11-03: owner: hard facets on every character mesh; series initials allowed in ids; 0.8 model downsize (section 5).
- 2026-11-03: owner: designs match the source characters, only the name differs; Lufy keeps the vest (section 5).
- 2026-11-03: owner: target look from a reference image: no ink outlines, soft 3D shading, big head, faceted hair, 3D clothes on blocky limbs, plain smooth block hands (section 5).
- 2026-11-03: owner: unique painted texture and hair for all 30, close to 1-1 with the originals (section 5).
- 2026-11-03: owner: art direction closer to the original designs (section 5), from reference screenshots.
- 2026-11-03: owner: the 30 avatar models are the only rollable cast for now and go in the game; the 3 event-only
  characters stop being rollable but stay in the Index as undiscovered tiles; new players pick a starter in a popup
  (4.21).
- 2026-11-03: owner: character art style changed: chibi retired, Roblox avatar proportions and rendering, distinct
  resemblance to the source character; signature marks may closely resemble the original (section 5). Pilot of 3
  (Team Seven) first, then the other 27 after owner approval.
- 2026-11-03: owner: character art drafting starts (goal `char-art`): 30 regular-cast draft models in Blender
  from one shared chibi base, renders only, no Studio import yet; signature marks use clearly altered versions (section 5).
- 2026-11-03: owner: UI animations across the board (4.20): panels, buttons, tabs, numbers, toasts, badges.
- 2026-11-03: owner: workshop passive gain removed; the player picks one stat (Money, Luck, Speed, Stamina) and the
  Dojo squad's combined rarity (points x 5%, scaled by workshop level) boosts it everywhere; Workshop stat point
  retired and refunded; in-zone luck and offline workshop credit removed (4.19).
- 2026-11-03: owner: Track 1 balance kept as is; runner categories shown on a hover info card of the team row (4.5);
  team row shows only avatar heads, no rarity, with an animated current-runner indicator (4.3); upgrade tree gets a
  Stamina branch (4.6, new); stamina bar drain / low / refill animation (4.3); stamina features (4.6-4.8) built.
- 2026-11-02: owner: stamina implemented (c1 ported onto the fixed-speed code). Stamina lowered for track-by-track
  progression (Commons about 12-15 s, Secrets 30 s; 4.3), 3 swappable Team slots in the Backpack (4.2), a vertical blue
  stamina bar right of the running character (4.3). Category stamina retuned to x0.9 / x1.1 (proposed, 4.5).
- 2026-10-30: owner c1 rulings (TEAM_AND_STAMINA_SPEC Run end, recorded here 2026-11-02): run bank restored (wins
  bank, exhaustion cashes out, loss empties); a loss reset refills stamina and restarts at slot 1 (at the checkpoint
  track since 2026-11-02, 4.15).
- 2026-11-02: owner: the sensei picks checkpoints again; tracks lock until the one before is beaten (BestTrack + 1
  open); a loss restarts at the checkpoint; tracks won past the checkpoint in the same run pay a bonus (+10% per
  track, cap x2, placeholders) (4.15, replaces the 2026-11-01 informational sensei).
- 2026-11-01 (later): owner: biome while racing comes from the server's `RunTrack`, look-ahead removed (4.18).
- 2026-11-01 (later): owner: player Level / XP removed; rebirth needs Money ($100K, x10 each, placeholder), no XP
  multi (4.14).
- 2026-11-01 (later): owner: Kami cruise lowered from 1 Sp to 800 studs/s (equal to `MAX_CRUISE`) (4.13).
- 2026-11-01 (later): owner: admin-only Kami runner at 1 Sp studs/s, the one `MAX_CRUISE` exception; HUD
  speedometer and cruise read-out removed (4.13).
- 2026-11-01 (later): owner: upgrade tree "Speed Gain" branch becomes "Speed": +% cruise per tier (4.13).
- 2026-11-01 (later): owner: Speed Doubler passes removed; Best Roll pedestal kept and fed; u4 per-slot aura/trail with UI.
- 2026-11-01 (later): owner: exhaustion pays a per-distance share of the current track's pad cash (4.3); Track 1
  not shortened, no map shift; Common / Uncommon / Rare base cruise 24 / 33 / 48 (4.13).
- 2026-11-01 (later): owner: workshop idle gain gives Money for now (4.13); hero landmark LevelOfDetail is set ahead of
  time, not at runtime (BIOME_ENVIRONMENT_SPEC 4.3).
- 2026-11-01: owner: no Speed stat or speed gain; fixed cruise per rarity x category; speed multi from stat points,
  Speed potions, preset bonus, per-slot auras / trails (4.13). Rebirth = luck, XP multi, +1 stat point (4.14).
  Sensei informational only, no checkpoints (4.15; replaced 2026-11-02). Leaderboards removed (4.16). Biome welcome popup (4.17). Faster
  mesh / texture / sky loading at high speed (4.18). Base speed table proposed by the orchestrator.
- 2026-11-01: owner: Track 7's subway must feel very wide along the whole route, not cramped, with assets placed
  throughout (not only in bays). Orchestrator default (owner delegated): target inner width 120 studs and ceiling 26,
  narrowed only where a neighbouring track's corridor would be crossed; props line both sides along the whole tunnel.
- 2026-10-31 (later): owner: Track 7 gets one fight scene the player passes: Gojio [Gojo] mid domain expansion against
  Joggo [Jogo], Hanamy [Hanami], Mahitto [Mahito] and Chosu [Choso] (Shibuya Incident, station platform). Parody
  look-alike figures (section 5: tweaked names, in-house art, no official names, logos or ripped assets; names are
  internal only, never displayed). Overrides the Track 7 "no character likenesses" scenery flag for this scene only.
  Researched from public information; scene spec in BIOME_ENVIRONMENT_SPEC section 7 Track 7.
- 2026-10-31: owner redesign of three tracks (tweaked names, section 5 safeguards kept):
  Track 5 becomes the burning city of the Jogo vs Sukuna fight (Jujutsu Kaisen), night, fire-lit: smoky sky lit orange,
  embers, craters, scorched streets, fire everywhere. Track 7 becomes the Shibuya Incident subway (Jujutsu Kaisen):
  the whole route is an enclosed tunnel (tiled walls, ceiling, rails, lights) opening into a few station platforms and
  concourses; replaces the original "Blossom Shrine Path" (owner: every track is based on an anime, none original).
  Track 8 becomes Skypeia from One Piece (tweaked); its NPC rival is Enelu [Enel], replacing Kizaro. Research first;
  references go in TRACKS_AND_BIOMES_SPEC.
- 2026-10-31: owner request: track camera, yaw aligned with the runner's travel while racing, Settings toggle
  TRACK CAMERA, off = regular camera (4.12, `docs/CAMERA_SPEC.md`).
- 2026-10-31: owner: Track 1 gate plaque may stay blank (BIOME_ENVIRONMENT_SPEC 7).
- 2026-10-30: owner: skybox ledger rows take one Id or 6 Faces; optional terrain `Craters` profile field (Track 2) (BIOME_ENVIRONMENT_SPEC 3.3, 4.4).
- 2026-10-30: owner: optional terrain `Sections` field (per-stretch ridge / water / material) and hero landmark `At` pin
  (BIOME_ENVIRONMENT_SPEC 3.3, 4.3).
- 2026-10-30: owner: free Roblox Creator Store assets allowed for world art, VFX and audio (section 5), with the IP
  check, scripts stripped and the id + creator in the ledger. Biomes are built one track at a time, with screenshots
  after each track. b0 spec approved.
- 2026-10-30: owner: full biome worlds (4.9, `docs/BIOME_ENVIRONMENT_SPEC.md`). Terrain is generated by code at every
  server start (plaza first). Agents may upload meshes, textures and sounds under the owner's account; every id goes
  in a ledger. PC-first: heavy layers hook into REDUCED EFFECTS. Per-zone sky and lighting are client-local only.
  The build is shown in the Team Create place.
- 2026-10-30: owner w4 rulings (TRACKS_AND_BIOMES_SPEC Biomes): Track 7 renamed Blossom Shrine Path; Track 1 uses
  the plaza torii as its gate; dressing budget grows with track length; horizon pieces about 100 studs from the road.

- 2026-10-30: owner on the Speed scale (4.11): wipe pre-scale test saves (v2 stores), HUD suffix threshold stays 1e6,
  Speed board stores a log-scaled score, weaker admin decimal check accepted; MAX_ADD scales.
- 2026-10-30: owner confirmed the smooth-motion ruling of 2026-10-28 (WORLD_REDESIGN_SPEC section 2): the client
  interpolates the anchored runner; it replaces the IVS "rail never snaps" rule (`rail_never_snaps`,
  `PhysicsTargets.race.MaxRailSnaps` retired). Rail-fall recovery retired with the car. Instant start is solo only;
  duels keep the countdown hold.
- 2026-10-30: owner: category speed applies after damping (4.5); F = 3 confirmed (4.9); Speed stat x(1e15 / 3e5) so
  1 Qd = 300K old, same gameplay (4.11).
- 2026-10-30: owner: speed matters more than stamina. Base stamina flattened (Legendary 30, Mythic 36, Secret 43);
  Legendary trio clears all 10 tracks in about 90 s; Marathoner cruise x0.8; big stamina only for Marathoners (4.3, 4.5).
- 2026-10-30: owner: tracks very long (bigger base, same x1.25 growth; F proposed 3) and biomes researched from
  public info on each anime and matched closely, section 5 safeguards kept (4.9).
- 2026-10-29: owner ruled on the runner rig (WORLD_REDESIGN_SPEC section 2): instant start with no Teleporting phase,
  seat-failure checks retired, runner-rig tile and pedestal art, camera follows the runner, avatar welded in the
  Torso, mid-race switch as in IVS, leaderboard title "RAREST CHARACTER".
- 2026-10-28: owner asked for a full world redesign before other work (after f2): scrap every car model incl. the
  car body (placeholder runner rig instead), anime hub, Dojo plots with the Dojo squad, spiral layout (4.10).
- 2026-10-28: owner: preset names tweaked (Sayan Pride, Kamada Squad); real-name checks in tests store hashes only;
  daily login's guaranteed rare stays "rarest unowned character" (IVS behaviour kept).
- 2026-10-28: owner approved the event-only names (Giyo, Toje, Rojer), the anime-maps deliverables and the Track 1 cliff faces.
- 2026-10-28: owner asked for the map redesign: tracks x1.25 longer each (Track 1 = reference), anime biomes (4.9).
- 2026-10-28: owner put event-only characters in scope (weather events carry over, 3 event-only characters).
- 2026-10-28: owner removed the IVS cars and car-only features; characters keep the car body as a placeholder (4.1).
- 2026-10-28: owner approved the parody cast, the 6 preset trios, the 10 NPC rivals and the section 5 safeguards.
- 2026-10-28: owner changed section 5: characters are based on real anime characters with tweaked names (was
  original only); Series = tweaked real anime, preset trio = its famous team.
- 2026-10-28: owner answered the open questions: Stamina stat point, Stamina potions, runner categories
  (Sprinter / Balanced / Marathoner), Series and preset team bonus (sections 4.5-4.8).
- 2026-10-28: document created (owner decisions: new repo, original characters, full stamina refill per run,
  exhaustion cashes out).
