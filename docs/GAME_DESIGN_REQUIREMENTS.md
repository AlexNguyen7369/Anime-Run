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
6. While running, the Speed stat grows. A higher Speed stat makes every character faster.
7. Money buys upgrades; rebirth resets Money and Speed for a permanent multiplier.

## 3. Rules carried over from IVS unchanged (rename only: car -> character)

| Rule | IVS source |
|---|---|
| Numbered, point-to-point track chain; each track starts on the previous finish; loops back to Track 1 after the last | `TrackBuilder`, `TrackValidator` |
| Wide checkpoint area and WinPad at each finish; pad `Cash = PayoutCurve.Cash(n)` ($100 on Track 1, then x10 / x7.5 alternating) | `PayoutCurve` |
| One NPC rival per track, client-side only, left lane; player wins if they reach the finish before the NPC's known time | `NpcRacer`, `NpcConfig` |
| Banked money in NPC mode; loss empties the bank; cash-out on stop / death / leave | `RaceService` |
| Speed stat (`leaderstats.Speed`) grows with actual speed while running; cruise = log curve of the stat, capped at `MAX_CRUISE` | `RaceConfig` |
| The runner holds exact cruise speed everywhere (no acceleration, no corner slowing) | `RaceService` rail |
| Auto-roll every 3 s (placeholder), turbo luck every 10th roll x10 (placeholder), rarest-first roll check `min(1, luck / Chance)` | `GachaConfig` |
| Index: discovering = owning; stat points from unique discoveries; allocations saved, points derived | `GachaService` |
| Duplicates add `Copies` and pay no Money | IVS 2026-10-22 |
| Workshop plots, idle Speed while standing in the workshop; Showcase of 3 characters multiplies workshop gain | `WorkshopService` |
| Weather events (Rain, Night Race, Gold Rush, Clear, Aurora) and event-only rolls: 3 event-only characters, rollable only during their event, kept after it ends (owner 2026-10-28) | IVS `docs/WEATHER_EVENTS_SPEC.md` |
| Rebirth resets Money AND Speed | `RebirthService` |
| Session-locked saves through `UpdateAsync` | `PlayerData` |
| Server decides every number that matters; the client only displays | IVS "Technical and data requirements" |

## 4. What changes

### 4.1 Characters replace cars
- A character is a catalog entry with a permanent `Id`, `Name`, `Rarity`, `Chance` (1 in N), `SpeedMulti`, `Stamina`,
  `Category` (4.5), `Series` (4.8) and an archetype. Spec: `docs/CHARACTER_GACHA_SPEC.md`.
- Character `SpeedMulti` scales cruise speed (damped, like the IVS car cruise multi). It never scales Speed-stat gain.
- The player runs on foot as the active character (a rigged, animated model on the race rail). There is no vehicle.

- IVS cars and car-only features are not part of Anime Run (owner 2026-10-28): the 111 IVS car entries, car models,
  gamepass cars, the Ember Wyvern dragon and the Singularity orb are removed. Every car model, the car body included,
  is scrapped; characters run as a placeholder anime runner rig on the race rail (owner 2026-10-28, section 4.10;
  replaces the same day's "keep the car body" decision).

### 4.2 Team of 3
- The player equips a **team**: 3 ordered slots. The same character may not be in two slots. A team needs at least
  1 character. Spec: `docs/TEAM_AND_STAMINA_SPEC.md`.
- Slot 1 starts every run; slot 2, then slot 3, take over when the one before is empty.

### 4.3 Stamina
- Every character has a stamina bar (0-100%). It drains only while that character is running.
- The drain rate depends on rarity: rarer characters last a little longer (seconds of running: Common 20,
  Uncommon 22, Rare 24, Epic 27, Legendary 30 (placeholders); Mythic 36, Secret 43 (owner 2026-10-30)).
- Speed matters more than stamina (owner 2026-10-30): the rarity spread in stamina is small; only Marathoners get a
  big stamina boost. A trio of Legendaries clears all 10 tracks with about 90 s of running, using about all their
  stamina; Mythic and Secret trios clear all 10 tracks with stamina to spare.
- At 0 stamina the next non-empty slot takes over at once, at its own cruise speed. The NPC race timer keeps running.
- Stamina refills to 100% for every character at the start of every run (owner 2026-10-28). It never carries over.
- When the last character reaches 0 the run ends as a **soft end**: the bank is cashed out (owner 2026-10-28).

### 4.4 Losing stays a speed comparison
- Losing a track is unchanged: the NPC's track time is fixed when the track starts; if the player's team reaches the
  finish later, the player loses. A swap to a slower character mid-track can turn a win into a loss: team order is
  part of the strategy.

### 4.5 Runner categories (owner 2026-10-28)
- Every character has one category that trades speed against stamina (multipliers placeholder):
  - **Sprinter**: cruise SpeedMulti x1.25, stamina x0.8 (proposed 2026-10-30, was x0.7).
  - **Balanced**: x1, x1.
  - **Marathoner**: cruise SpeedMulti x0.8 (owner 2026-10-30, was x0.85), stamina x2.0 (proposed 2026-10-30, was x1.4).
- Rarity still sets the base speed and base stamina; the category scales them. The category speed multiplies the
  damped cruise multi (after `CruiseStatMulti`), so Marathoner x0.8 is a real 20% slower (owner 2026-10-30); it
  counts inside `MAX_CRUISE_TOTAL_MULTI` and `MAX_CRUISE`.

### 4.6 Stamina stat point (owner 2026-10-28)
- Index stat points can be put into a new stat **Stamina**: each point adds +5% stamina to every character
  (placeholder), additive with other points like the IVS stats.

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

### 4.11 Speed stat scale (owner 2026-10-30)
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
  `score = floor(log10(1 + Speed) x 1e15)`, `Speed = 10^(score / 1e15) - 1`. Other boards are unchanged.
- Test precision (owner 2026-10-30): above the new `MAX_STAT` a double cannot keep decimals, so
  `admin_addspeed_past_max_stat_not_clamped` checks only "past MAX_STAT, not clamped".

### 4.10 World redesign (owner 2026-10-28)
- The whole map is redesigned after f2: anime town plaza hub at the centre, 7 player plots (Dojos) around it, the
  track chain spiralling out from the hub's start gate through the 10 biomes. Spec: `docs/WORLD_REDESIGN_SPEC.md`.
- Player plots keep the workshop rules; the IVS Showcase becomes the Dojo squad: 3 owned characters not in the
  racing Team train there and multiply idle Speed gain. A character is in the Team or the Dojo squad, never both.

## 5. Characters and intellectual property (owner 2026-10-28, replaces "original only")

- Characters are **based on real anime characters with tweaked names** (parody look-alikes, owner 2026-10-28), e.g.
  "Narito" for a well-known ninja hero. Each Series is a tweaked-name take on a real anime, and its preset trio is
  that anime's famous team.
- Risk accepted by the owner: rightsholders can still file DMCA takedowns against derivative characters, which removes
  the game (`docs/RESEARCH.md` section 2).
- Safeguards (owner-approved 2026-10-28):
  - Never use an official character name, series title, logo, sound, voice line or ripped model / texture. All art,
    VFX and audio are made in-house.
  - Real character or series names never appear in the game title, description, thumbnails, icons, badges or
    developer product names.
  - Keep one list of every parody and its source (`docs/CHARACTER_GACHA_SPEC.md`) so a takedown can be answered by
    renaming / reskinning one character fast; character `Id`s never contain the real name, so a rename never touches
    saves.

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

None open. The Speed-scale save question of 2026-10-30 was answered the same day (4.11: wipe).

The four questions of 2026-10-28 were answered the same day (sections 4.5-4.8).

## Change log

- 2026-10-30: owner on the Speed scale (4.11): wipe pre-scale test saves (v2 stores), HUD suffix threshold stays 1e6,
  Speed board stores a log-scaled score, weaker admin decimal check accepted; MAX_ADD scales.
- 2026-10-30: owner: category speed applies after damping (4.5); F = 3 confirmed (4.9); Speed stat x(1e15 / 3e5) so
  1 Qd = 300K old, same gameplay (4.11).
- 2026-10-30: owner: speed matters more than stamina. Base stamina flattened (Legendary 30, Mythic 36, Secret 43);
  Legendary trio clears all 10 tracks in about 90 s; Marathoner cruise x0.8; big stamina only for Marathoners (4.3, 4.5).
- 2026-10-30: owner: tracks very long (bigger base, same x1.25 growth; F proposed 3) and biomes researched from
  public info on each anime and matched closely, section 5 safeguards kept (4.9).
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
