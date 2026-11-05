#!/usr/bin/env python3
"""Pacing model for docs/SPEED_BALANCE_SPEC.md: an auto-running player from a fresh save to Track 10.

Numbers mirror src/shared (RaceConfig, NpcConfig, RebirthConfig, StaminaConfig, PayoutCurve, Characters/*).
shortcut: buffs unlock on a schedule by best track and money is never spent, upgrade when real play data exists.

Usage: python3 tools/balance/speed_model.py [players]
"""
import math
import random
import statistics
import sys

TRACK_LENGTH = [984 * 3 * 1.25**i for i in range(10)]
PAYOUT = [100.0]
for i in range(9):
    PAYOUT.append(PAYOUT[-1] * (10 if i % 2 == 0 else 7.5))

ENEMY_SPEED = [1e3, 1e5, 1e7, 3e9, 3e12, 3e15, 3e18, 1e22, 1e27, 5e29]
ENEMY_T1_CRUISE, ENEMY_T10_CRUISE = 45.5, 653
ENEMY_GROWTH = (ENEMY_T10_CRUISE / ENEMY_T1_CRUISE) ** (1 / 9)
ENEMY_CRUISE = [ENEMY_T1_CRUISE * ENEMY_GROWTH**i for i in range(10)]

BASE_SPEED = {"Common": 100, "Uncommon": 300, "Rare": 1200, "Epic": 2e4, "Legendary": 5e6, "Mythic": 5e10, "Secret": 5e13}
STAMINA = {"Common": 13.5, "Uncommon": 15.5, "Rare": 18, "Epic": 21, "Legendary": 24, "Mythic": 27, "Secret": 30}
RARITY_DESC = ["Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon"]
CHANCES = {
    "Uncommon": [10, 20, 40, 70, 120, 150, 200],
    "Rare": [500, 1000, 2000, 3000, 4000, 8000, 13000],
    "Epic": [5e4, 1.2e5, 3e5, 7e5, 9e5, 1e6, 1.2e6, 1.5e6, 2.5e6],
    "Legendary": [1e7, 3e7, 5e7, 1e8, 1.5e8, 2e8, 3e8, 5e8, 7.8e8],
    "Mythic": [5e9, 1e10, 3e10, 1e11, 3e12, 1e13, 1e14, 3e14, 1e15],
    "Secret": [1.6e16, 5e18],
}

# (Speed, studs/s), ascending. Above the last anchor the runner holds that cruise.
CURVE = [(10, 10), (100, 24), (300, 33), (1e3, ENEMY_T1_CRUISE), (1200, 48)] + [(ENEMY_SPEED[i], ENEMY_CRUISE[i]) for i in range(1, 10)] + [(7e31, 800)]

REBIRTH_SPEED = [1, 5, 12, 25, 50, 100, 250, 600, 1500, 4000, 1e4, 1.6e5, 2.5e6, 4e7, 6.5e8, 1e10, 1.6e11, 2.5e12, 4e13, 6.5e14, 1e16]
REBIRTH_LUCK = [1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11]
REBIRTH_COST = [5e3, 12e3, 25e3, 50e3, 1e5, 3e5, 8e5, 2e6, 5e6, 1.2e7, 2e7, 4e8, 2e9, 1e10, 4e10, 1.2e11, 2.5e11, 3e11, 3.5e11, 5e11]

OVERHEAD_SECONDS = 12  # back on the pad between runs
MAX_HOURS = 400


def cruise(speed):
    if speed <= CURVE[0][0]:
        return CURVE[0][1]
    for (a, va), (b, vb) in zip(CURVE, CURVE[1:]):
        if speed <= b:
            t = (math.log(speed) - math.log(a)) / (math.log(b) - math.log(a))
            return va * (vb / va) ** t
    return CURVE[-1][1]


def buffs(best, points):
    """Speed multi, stamina multi, money multi for a player whose best track is `best`."""
    tree = 0.1 if best == 0 else min(0.5, 0.1 * (best + 1))
    items = 1 if best == 0 else min(15, 1 + best * 1.6)
    speed = (1 + tree + 0.02 * min(points, 10)) * items
    stamina = (1 + tree + 0.05 * min(points // 2, 2 if best == 0 else 8)) * (1 if best == 0 else 1.2)
    money = 1 + min(0.5, 0.1 * best) + 0.1 * min(points, 10)
    return speed, stamina, money


def run(team, cruises, stamina_multi, start):
    """One run from track index `start`: (cash, seconds, track index reached). A loss keeps the won tracks."""
    cash, seconds, slot, past = 0.0, 0.0, 0, 0
    left = STAMINA[team[0]] * stamina_multi
    track = start
    while track < 10:
        remaining, taken, s, s_left = TRACK_LENGTH[track], 0.0, slot, left
        while remaining > 0 and s < 3:
            step = min(remaining, s_left * cruises[s])
            remaining -= step
            dt = step / cruises[s]
            taken += dt
            s_left -= dt
            if s_left <= 1e-9:
                s += 1
                if s < 3:
                    s_left = STAMINA[team[s]] * stamina_multi
        seconds += taken
        if remaining > 1e-6:  # exhausted: per-distance share
            cash += PAYOUT[track] * (TRACK_LENGTH[track] - remaining) / TRACK_LENGTH[track]
            break
        if taken >= TRACK_LENGTH[track] / ENEMY_CRUISE[track]:  # loss, strict like RaceService
            break
        cash += PAYOUT[track] * min(2, 1 + 0.1 * past)
        slot, left, past, track = s, s_left, past + 1, track + 1
    return cash, seconds, track


def player(seed):
    rng = random.Random(seed)
    owned = {r: set() for r in CHANCES}
    t, money, rebirth, best, next_roll = 0.0, 0.0, 0, 0, 0.0
    tracks, rebirths, first = {}, {}, {}
    while t < MAX_HOURS * 3600 and best < 10:
        team = [r for r in RARITY_DESC for _ in owned[r]]
        team = (team + ["Common"] * 3)[:3]
        points = sum(len(v) for v in owned.values()) // 3 + rebirth
        speed_m, stamina_m, money_m = buffs(best, points)
        cruises = [cruise(BASE_SPEED[r] * REBIRTH_SPEED[rebirth] * speed_m) for r in team]
        # the player picks the checkpoint that earns most per second
        picks = [run(team, cruises, stamina_m, c) for c in range(min(best + 1, 10))]
        cash, seconds, reached = max(picks, key=lambda p: p[0] / (p[1] + OVERHEAD_SECONDS))
        money += cash * money_m
        reached = max(p[2] for p in picks)
        for n in range(best + 1, reached + 1):
            tracks.setdefault(n, (t, rebirth, team))
        best = max(best, reached)
        t += seconds + OVERHEAD_SECONDS
        while next_roll < t:
            next_roll += 3 if best < 2 else 2.2
            luck = (1 + min(2.5, 0.5 * best) + 0.05 * min(points, 5)) * REBIRTH_LUCK[rebirth] * 2
            for rarity in RARITY_DESC:
                hit = next((i for i, c in enumerate(CHANCES[rarity]) if rng.random() < min(1, luck / c)), None)
                if hit is not None:
                    owned[rarity].add(hit)
                    first.setdefault(rarity, next_roll)
                    break
        if rebirth < 20 and money >= REBIRTH_COST[rebirth]:
            money, rebirth = 0.0, rebirth + 1
            rebirths[rebirth] = t
    return tracks, rebirths, first


def hours(values):
    return round(statistics.median(values) / 3600, 1)


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    results = [player(seed) for seed in range(n)]
    previous = 0
    for track in range(1, 11):
        rows = [r[0][track] for r in results if track in r[0]]
        if not rows:
            print(f"Track {track}: not reached")
            continue
        h = hours([row[0] for row in rows])
        rebirth = statistics.median(row[1] for row in rows)
        print(f"Track {track:2}: {h:6} h  gap {h - previous:5.1f} h  rebirth {rebirth:4}  reached {len(rows)}/{n}")
        previous = h
    print("Rebirths (h):", [(k, hours([r[1][k] for r in results if k in r[1]])) for k in range(1, 21) if any(k in r[1] for r in results)])
    print("First (h):", {k: hours([r[2][k] for r in results if k in r[2]]) for k in RARITY_DESC if any(k in r[2] for r in results)})
    # the pacing target the owner set on 2026-11-05
    t10 = [r[0][10][0] for r in results if 10 in r[0]]
    assert t10 and 60 <= hours(t10) <= 100, f"Track 10 outside 60-100 h: {hours(t10) if t10 else 'not reached'}"
    assert all(a[0] < b[0] for a, b in zip(CURVE, CURVE[1:])) and all(a[1] < b[1] for a, b in zip(CURVE, CURVE[1:]))


if __name__ == "__main__":
    main()
