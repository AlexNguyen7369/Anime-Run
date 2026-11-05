# Speed balance: design spec

Relies on `docs/GAME_DESIGN_REQUIREMENTS.md` 4.3, 4.4, 4.5, 4.13, 4.14 and 4.15 (owner 2026-11-05). Every number here is
**proposed** and tunable. Pacing model: `tools/balance/speed_model.py`. Research: `docs/RESEARCH.md` section 5.

## Two numbers

- **Speed** is the game's number: whole, uncapped, shown everywhere. `RaceConfig.Speed(spec, multi)`.
- **Cruise** is real movement in studs/s, used only by the race rail, the camera, streaming and effects. Never shown.
  `RaceConfig.Cruise(spec, multi)` is `RaceConfig.CruiseOf(Speed)`.
- Speed = rarity base x category x speed multi x rebirth multi (4.13, 4.14). The speed multi's parts are in 4.13.
- Cruise interpolates log-log over `RaceConfig.SPEED_CURVE` and holds the last anchor's value above it, capped at
  `MAX_CRUISE`. The curve only rises, so higher Speed always finishes sooner.
- The race is still real finish times: `playerTime < race.NpcTime` (4.4). An equal time loses.

## Enemies

`NpcConfig.Tracks[n].Speed`. Cruise is `RaceConfig.CruiseOf(Speed)`.

| Track | Enemy Speed | Cruise, studs/s (was) | Enemy time, s |
|---|---|---|---|
| 1 | 1k | 45.5 (16) | 64.9 |
| 2 | 100k | 61.2 (24.2) | 60.3 |
| 3 | 10m | 82.2 (36.5) | 56.1 |
| 4 | 3b | 110.6 (55.1) | 52.1 |
| 5 | 3t | 148.7 (83.2) | 48.5 |
| 6 | 3qd | 199.9 (125.6) | 45.1 |
| 7 | 3qt | 268.7 (189.7) | 41.9 |
| 8 | 10sx | 361.3 (286.4) | 39.0 |
| 9 | 1oc | 485.7 (432.4) | 36.2 |
| 10 | 500oc | 653 (653) | 33.7 |

Recommended speed on a track card: enemy Speed x 1.01, rounded up. `floor + 1` does nothing at 1e27 (double precision).

## Rarity base

| Rarity (Balanced) | Speed | Cruise with no multis, studs/s (was) | Stamina, s |
|---|---|---|---|
| Common | 100 | 24 (24) | 13.5 |
| Uncommon | 300 | 33 (33) | 15.5 |
| Rare | 1,200 | 48 (48) | 18 |
| Epic | 20k | 56 (90) | 21 |
| Legendary | 5m | 79 (200) | 24 |
| Mythic | 50b | 125 (450) | 27 |
| Secret | 50t | 168 (700) | 30 |

Curve anchors, in order: (10, 10), Common, Uncommon, Track 1's enemy, Rare, the enemies of Tracks 2-10, then Speed 7e31 = 800 studs/s.
The best current kit (Secret, rebirth 20, every buff at its best, all stat points in Speed) is about 6.8e31 Speed, so the 47 characters
top out at about 800. The range from 800 to `MAX_CRUISE` is for future characters; its anchor comes from the cap test.

## Cap test (result pending)

Run `speed_probe` and read `highest_green_contiguous`. The owner wants at least 1000 studs/s. The recorded rule is the
highest contiguous green speed minus 10%, without the old 700-800 ceiling: 1250 green gives 1125, while 1000 green gives
900 and goes back to the owner. Until then `MAX_CRUISE` stays 800.

## Track 1 gate

Modelled at Balanced, no Market items, no rebirth:

| Team | No buffs | +20% stamina | x1.5 stamina | x2 stamina, x2 Speed |
|---|---|---|---|---|
| 3 Common | exhausts, $33 | $40 | $49 | $81 |
| 3 Uncommon | $52 | $62 | $78 | loses |
| 2 Rare + Uncommon | $76 | $91 | loses (tie) | wins |
| 3 Rare | $88 | wins | wins | wins |
| Epic + Rare + Common | $80 | $96 | wins | wins |
| 3 Epic | wins | wins | wins | wins |

Known bypasses: heavy paid stacking, and rebirth x5 on an Uncommon team that also has about x1.4 stamina.

## Rebirth

`RebirthConfig.SPEED_TOTALS` and `RebirthConfig.COSTS`. Totals, not per-step. Luck totals and +1 stat point are unchanged.

| Rebirth | Speed multi | Cost | Rebirth | Speed multi | Cost |
|---|---|---|---|---|---|
| 1 | x5 | $5K | 11 | x160k | $20M |
| 2 | x12 | $12K | 12 | x2.5m | $400M |
| 3 | x25 | $25K | 13 | x40m | $2B |
| 4 | x50 | $50K | 14 | x650m | $10B |
| 5 | x100 | $100K | 15 | x10b | $40B |
| 6 | x250 | $300K | 16 | x160b | $120B |
| 7 | x600 | $800K | 17 | x2.5t | $250B |
| 8 | x1.5k | $2M | 18 | x40t | $300B |
| 9 | x4k | $5M | 19 | x650t | $350B |
| 10 | x10k | $12M | 20 | x10qd | $500B |

## Pacing target

An auto-running player first beats Track 10 in 60-100 hours (owner 2026-11-05). `speed_model.py`, median of 30 players:

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Hours | 0.3 | 1.4 | 2.6 | 14 | 16.6 | 30 | 34.5 | 40.9 | 67 | 78.9 |
| Rebirth | 0 | 3 | 6 | 11 | 11 | 13 | 14 | 15 | 20 | 20 |

First Epic 1.8 h, Legendary 16.6 h, Mythic 34.5 h, Secret 78.9 h. Largest gaps: Track 8 to 9 (26 h), Track 5 to 6 (13 h),
Track 9 to 10 (12 h), Track 3 to 4 (11 h). The model is an estimate: buffs unlock on a schedule and money is never spent
on them. Retune after real play.

## Effects of the curve

- x1000 Speed is about x1.35 movement, so a number that decides a race moves the runner only a little.
- Category multiplies Speed (4.5): Marathoner has the distance edge, Sprinter the threshold edge.
- Market auras and trails apply their full multi. The old log damp protected the physical cap, which the curve now does.
- Duels compare real finish times, so they inherit the small movement gaps.
