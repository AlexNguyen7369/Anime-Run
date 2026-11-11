# The Elf Mage's in-betweens, her golem's track and both game models (design doc 4.37 "Second boss", BOSS_EVENT_SPEC "The Elf Mage").
#   Blender -b --factory-startup --python tools/blender/bake_boss_mage.py -- [poses] [glb]
# poses   writes src/shared/BossMagePoses.luau: the owner-approved keys of keyframes/keys.json verbatim at their times (2026-11-11),
#         everything between them generated here, then self-checked (asserts). Same public shape as BossRagaPoses. Run stylua after.
# glb     writes build/avatar_glb/boss_mage.glb (9 parts) and boss_golem.glb (15 blocks): unposed, no hierarchy, each centred on its
#         bounding box (bake_boss_raga.write_glb), so a part's CFrame is joint * Center. Upload with upload_avatar.py.
# Euler channels interpolate literally, like the raga bake: a Staff key pair 281 degrees apart on X reads as a twirl.
import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_boss_raga as raga  # noqa: E402  (guarded main: easing, thinning, sampling, number format, GLB export)
import boss_mage_keyframes as mk  # noqa: E402  (guarded main: the key pose solver and the stage constants)

ease, eout, ein = raga.inout, raga.eout, raga.ein

ROOT = os.path.dirname(os.path.dirname(HERE))
KEYS = os.path.join(ROOT, "assets", "characters_avatar", "boss_mage", "keyframes", "keys.json")
BLEND = {cid: os.path.join(ROOT, "assets", "characters_avatar", cid, cid + ".blend") for cid in ("boss_mage", "boss_golem")}
GLB = {cid: os.path.join(ROOT, "build", "avatar_glb", cid + ".glb") for cid in BLEND}
LUAU = os.path.join(ROOT, "src", "shared", "BossMagePoses.luau")
# The golem's feet in game, studs in her frame (Blender axes). Not keys.json's GOLEM_SPOT x the size: at 8x that put it on lanes
# 1-2 (83 studs out), where runners passed through it. 42 out keeps its ~27-stud half width inside the kerb (70) and clear of
# her ~12-stud half width (proposed, Studio verify 2026-11-11).
GAME_GOLEM_SPOT = (-40.0, 12.0)

SIZE = 8  # her height in runner heights (owner 2026-11-11)
RATE = 120  # samples a second before thinning
LIMIT_DEGREES, LIMIT_OFFSET, SNAP = 12, 0.05, 0.05  # deg and model units a 60 Hz frame, outside SNAP s of a hit event (BossAnimTests)
MIN_HIT_GAP = 3.95  # s between two hit events at least: the Dodge bar needs it (spec "Dodge bar")
# Proposed: the lead from the hover into each attack's approved first key (that key is not the hover pose), seconds.
LEAD = {"lightning": 0.75, "golem": 0.75, "barrage": 0.45}
# Proposed. Rows as BossRagaPoses: { "idle", from, seconds } or { move }. A "<move>_in" lead runs just before its move.
CYCLE = (
	("idle", 0, 3),
	("lightning_in",),
	("lightning",),
	("idle", 0, 3),
	("idle", 0, 3),
	("barrage_in",),
	("barrage",),
	("idle", 0, 3),
	("idle", 0, 3),
	("golem_in",),
	("golem_fall",),  # the golem's slot is the end of golem_in: her clock stops there until it falls (GOLEM_SLOT_AT)
	("idle", 0, 3),
)
WINDOW_PLAN = (  # proposed: the 2 s sustain window, 2.0 -> 2.5 -> 3.25 -> 4.0
	{"ease": ease(1.8), "carry": 0.05},
	{"ease": ease(1.8), "carry": 0.05},
	{"ease": ease(1.8), "carry": 0.05},
)
GOLEM_EVERY = 5  # proposed: s between two golem hits on its own clock (BossMinionStart)
OSU_OPEN = 2.94  # BossOsu.OpenSeconds: a hit's circles open this long before it
WATCH_LEAD = 0.75  # proposed: watch_in, idle key 0 -> watch key 0
EVENTS = {"lightning": "Lightning", "golem": "Slam", "barrage": "Barrage"}
# One row per segment between stops (approved keys, then the hover at the move's end). ease, hold (s stopped at its start),
# carry (overshoot past its first key, a share of the segment before), anticipate (a pull the wrong way first, a share of it).
PLAN = {
	"lightning": (
		{"ease": ease(2.0)},  # the coil climbs into the charge
		{"ease": ein(2.4), "hold": 0.05},  # the orb builds, then the thrust
		{"ease": eout(2.5), "carry": 0.15},  # thrown into the strike
		*WINDOW_PLAN,
		{"ease": ease(1.7), "carry": 0.08},
		{"ease": ease(2.0)},
	),
	"golem": (
		{"ease": ease(2.0)},
		{"ease": eout(2.2), "carry": 0.1},
		{"ease": ease(2.0)},
		{"ease": ein(3.0), "hold": 2.0},  # wind-up held to 4.0 s (keys.json hold_until), then the slam
		{"ease": ease(1.35), "carry": 0.06},
		{"ease": ease(2.0)},
	),
	"barrage": (
		{"ease": ease(2.2)},
		{"ease": ease(2.2), "carry": 0.08},
		{"ease": ein(2.5)},
		*WINDOW_PLAN,
		{"ease": eout(2.5), "hold": 0.12, "carry": 0.12},  # beams fire and hold, then she is pushed back
		{"ease": ease(2.0)},
	),
}
LEAD_PLAN = ({"ease": ease(1.5), "anticipate": 0.12},)
# Follow-through springs (part axis, drivers {channel: weight}, gain, omega, zeta), under-damped, as the raga bake's FOLLOW.
TAILS = (
	("TailL0", {"Head0": 1, "Torso0": 1, "rootz": -50}, 1.2, 8, 0.3),
	("TailR0", {"Head0": 1, "Torso0": 1, "rootz": -50}, 1.2, 8, 0.3),
	("TailL1", {"rootz": -40}, 1.0, 7, 0.3),
	("TailR1", {"rootz": 40}, 1.0, 7, 0.3),
	("TailL2", {"Head2": 1, "Torso2": 1}, 1.0, 8, 0.3),
	("TailR2", {"Head2": 1, "Torso2": 1}, 1.0, 8, 0.3),
)
STAFF = (("Staff0", {"RightArm0": 1}, 0.3, 12, 0.35), ("Staff2", {"RightArm2": 1}, 0.25, 12, 0.35))
FOLLOW = {"lightning": TAILS + STAFF, "golem": TAILS + STAFF, "barrage": TAILS}  # barrage holds the staff in both hands
# Held tension as a slow shiver: (from, to, degrees, {channel: weight}). Golem channels are "<part>:r<axis>".
TREMBLE = {
	"golem": (2.0, 4.0, 1.2, {"Torso0": 1, "Head0": 0.7, "Staff0": 1}),
	"golem_track": (2.0, 4.0, 1.5, {"Torso:r0": 1, "Head:r0": 1, "ShoulderL:r1": 1, "ShoulderR:r1": -1, "Hip:r0": 0.5}),
}
GOLEM_TUMBLE = 50  # degrees: rubble spin as it rises out of the floor, 0 to 0.7 s
GOLEM_SINK = 0.2  # golem units below the floor past its highest block, at its start and end


def track(times, values, segments):
	"""Channels over time through every stop."""

	def at(t):
		i = int(max(0, min(len(times) - 2, np.searchsorted(times, t, side="right") - 1)))
		seg = segments[i]
		hold = seg.get("hold", 0)
		t0, t1 = times[i], times[i + 1]
		u = min(max((t - t0 - hold) / (t1 - t0 - hold), 0.0), 1.0)
		s, b = seg["ease"](u), raga.bump(u)
		out = {}
		for k, a in values[i].items():
			d = values[i + 1][k] - a
			v = a + d * s - seg.get("anticipate", 0) * d * b
			if seg.get("carry") and i > 0:
				v += seg["carry"] * (a - values[i - 1][k]) * b
			out[k] = v
		return out

	assert len(segments) == len(times) - 1
	return at


def secondary(grid, samples, follow, trembles, knots, seed):
	"""Spring lag and tremble per channel, taken back to 0 at every knot (approved keys and the move's ends)."""
	out = {}
	dt = grid[1] - grid[0]
	for channel, drivers, gain, omega, zeta in follow:
		d = np.array([sum(c[k] * w for k, w in drivers.items()) for c in samples])
		x, v, lag = d[0], 0.0, np.zeros(len(grid))
		for i in range(len(grid)):
			for _ in range(4):
				v += (omega**2 * (d[i] - x) - 2 * zeta * omega * v) * dt / 4
				x += v * dt / 4
			lag[i] = x
		out[channel] = out.get(channel, 0) + gain * (lag - d)
	rng = random.Random(seed)
	for t0, t1, degrees, channels in trembles:
		env = np.sin(np.pi * np.clip((grid - t0) / (t1 - t0), 0, 1)) ** 2
		for channel, w in channels.items():
			a, b = rng.uniform(3, 4.5), rng.uniform(5.5, 7)
			wave = (np.sin(2 * np.pi * a * grid) + 0.5 * np.sin(2 * np.pi * b * grid + 1)) / 1.5
			out[channel] = out.get(channel, 0) + w * degrees * env * wave
	knots = np.array(sorted(set(knots)))
	i = np.clip(np.searchsorted(knots, grid, side="right") - 1, 0, len(knots) - 2)
	u = (grid - knots[i]) / (knots[i + 1] - knots[i])
	smooth = u * u * (3 - 2 * u)
	for channel, curve in out.items():
		at = np.interp(knots, grid, curve)
		out[channel] = curve - (at[i] + (at[i + 1] - at[i]) * smooth)
	return out


def merged(data):
	"""A *_window move folded into its parent: the parent's keys to after_key_t, the window keys, then the parent's later keys
	2.0 s later (the owner's rule, 2026-11-11: only the recover key's time moves, never a pose)."""
	moves = {n: m for n, m in data["moves"].items() if "extends" not in m}
	for name, w in data["moves"].items():
		if "extends" in w:
			parent, shift = data["moves"][w["extends"]], w["window"][1] - w["window"][0]
			keys = [k for k in parent["keys"] if k["t"] <= w["after_key_t"]] + w["keys"]
			keys += [dict(k, t=round(k["t"] + shift, 6)) for k in parent["keys"] if k["t"] > w["after_key_t"]]
			assert [k["t"] for k in keys] == sorted({k["t"] for k in keys}), name
			moves[w["extends"]] = dict(parent, keys=keys, end=w["end"], Window=list(w["window"]))
	return dict(data, moves=moves)


def her(data):
	"""Her rig's moves (the golem-only ones have no rotations)."""
	return [n for n, m in data["moves"].items() if "rotations" in m["keys"][0]]


def loop2(keys, period):
	"""A 2-key loop: a cosine from key 0 to key 1 (at half the period) and back, so it meets both keys exactly."""
	assert len(keys) == 2 and keys[0]["t"] == 0 and abs(keys[1]["t"] - period / 2) < 1e-9

	def at(t, a, b):
		w = (1 - math.cos(2 * math.pi * t / period)) / 2
		return {k: a[k] + (b[k] - a[k]) * w for k in a}

	return at


class Mage:
	def __init__(self, data):
		self.data = data
		self.parts = sorted(p for p in data["pivots"] if p != "Body")  # Body never turns (asserted): its children carry the root
		self.idle0 = data["moves"]["idle"]["keys"][0]

	def channels(self, key):
		c = {"root" + "xyz"[i]: float(v) for i, v in enumerate(key["root_offset"])}
		for p in self.parts:
			for i in range(3):
				c["%s%d" % (p, i)] = float(key["rotations"][p][i])
		return c

	def frame(self, t, c):
		return (float(t), {p: tuple(c["%s%d" % (p, i)] for i in range(3)) for p in self.parts}, (c["rootx"], c["rooty"], c["rootz"]))

	def sample(self, name, times, values, segments, duration, knots):
		at = track(times, values, segments)
		grid = np.linspace(0, duration, int(round(duration * RATE)) + 1)
		samples = [at(t) for t in grid]
		trembles = [TREMBLE[name]] if name in TREMBLE else []
		sec = secondary(grid, samples, FOLLOW.get(name, ()), trembles, knots, name)
		frames = []
		for i, t in enumerate(grid):
			c = dict(samples[i])
			for channel, curve in sec.items():
				c[channel] += float(curve[i])
			frames.append(self.frame(t, c))
		return frames

	def pin(self, frames, keys, name):
		"""Approved keys go in verbatim, after proving the curve runs through them."""
		out = [f for f in frames if all(abs(f[0] - k["t"]) > 1e-6 for k in keys)]
		for k in keys:
			f = min(frames, key=lambda f: abs(f[0] - k["t"]))
			assert abs(f[0] - k["t"]) < 1e-9, f"{name} {k['t']}: not on the sample grid"
			for p in self.parts:
				e = max(abs(a - b) for a, b in zip(f[1][p], k["rotations"][p]))
				assert e < 0.02, f"{name} {k['t']} {p}: the curve is {e} degrees off its approved key"
			assert max(abs(a - b) for a, b in zip(f[2], k["root_offset"])) < 1e-6, f"{name} {k['t']}: root off its approved key"
			out.append((float(k["t"]), {p: tuple(float(v) for v in k["rotations"][p]) for p in self.parts}, tuple(float(v) for v in k["root_offset"])))
		return sorted(out, key=lambda f: f[0])

	def attack(self, name):
		move = self.data["moves"][name]
		keys = move["keys"]
		assert keys[0]["t"] == 0
		times = [k["t"] for k in keys] + [move["end"]]
		values = [self.channels(k) for k in keys] + [self.channels(self.idle0)]  # it ends in the hover's first key
		frames = self.sample(name, times, values, PLAN[name], move["end"], times)
		holds = [t + PLAN[name][i].get("hold", 0) for i, t in enumerate(times[:-1])]
		at = move["Window"][0] if "Window" in move else None  # a windowed move charges at the window's start
		events = [{"Time": at if at is not None else k["t"], "Name": k["event"]} for k in keys if "event" in k]
		return self.pin(frames, keys, name), [k["t"] for k in keys], events, move["end"], sorted(set(times + holds))

	def lead(self, name, a, b, length, plan=LEAD_PLAN):
		"""From key a to key b over length s (a <move>_in lead, watch_in, her part of golem_fall)."""
		values = [self.channels(a), self.channels(b)]
		frames = self.sample(name, [0, length], values, plan, length, [0, length])
		frames[0], frames[-1] = self.frame(0, values[0]), self.frame(length, values[1])
		return frames, [], [], length, [0, length]

	def watch(self):
		"""Her loop while the golem stands: a cosine between its 2 approved keys."""
		move = self.data["moves"]["watch"]
		keys, period = move["keys"], move["end"]
		assert move["loop"]
		a, b = self.channels(keys[0]), self.channels(keys[1])
		at = loop2(keys, period)
		frames = [self.frame(s / RATE, at(s / RATE, a, b)) for s in range(int(round(period * RATE)) + 1)]
		frames = self.pin(frames[:-1], keys, "watch") + [self.frame(period, a)]
		return frames, [k["t"] for k in keys], [], period, [k["t"] for k in keys] + [period]

	def idle(self):
		"""The hover loop: a periodic Catmull-Rom through the 4 keys; the bob is a cosine, which meets the keys exactly."""
		move = self.data["moves"]["idle"]
		keys, period = move["keys"], move["end"]
		assert move["loop"] and [k["t"] for k in keys] == [0, 0.75, 1.5, 2.25]
		values = [self.channels(k) for k in keys]
		bob = keys[2]["root_offset"][2] / 2
		for k in keys:
			assert abs(k["root_offset"][2] - bob * (1 - math.cos(2 * math.pi * k["t"] / period))) < 1e-9 and k["root_offset"][:2] == [0, 0]
		n, step = len(keys), period / len(keys)
		frames = []
		for s in range(int(round(period * RATE)) + 1):
			t = s / RATE
			i, u = int(t // step) % n, (t % step) / step
			p0, p1, p2, p3 = (values[(i + j) % n] for j in (-1, 0, 1, 2))
			c = {k: 0.5 * (2 * p1[k] + (p2[k] - p0[k]) * u + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * u**2 + (3 * p1[k] - p0[k] - 3 * p2[k] + p3[k]) * u**3) for k in p1}
			c["rootz"] = bob * (1 - math.cos(2 * math.pi * t / period))
			frames.append(self.frame(t, c))
		frames = self.pin(frames[:-1], keys, "idle") + [self.frame(period, values[0])]  # the loop's end is its first key
		return frames, [k["t"] for k in keys], [], period, [k["t"] for k in keys] + [period]


# ---- the golem's own track, inside the golem move ----


def golem_world(gbind, rot, loc, root_z=0.0):
	"""Every block's matrix in golem units, from the golem's root (its feet on the floor at rest)."""
	out = {}

	def m(n):
		if n not in out:
			b = gbind[n]
			parent = m(b["Parent"]) if b["Parent"] else Matrix.Translation((0, 0, root_z))
			out[n] = parent @ Matrix.Translation(loc[n]) @ Euler([math.radians(v) for v in rot[n]]).to_matrix().to_4x4()
		return out[n]

	for n in gbind:
		m(n)
	return out


def golem_top(gbind, verts, rot, loc):
	world = golem_world(gbind, rot, loc)
	return max(float((np.array(world[n])[:3, :3] @ verts[n].T).T[:, 2].max() + np.array(world[n])[2, 3]) for n in gbind)


def golem_values(gbind, g, root_z, scale):
	c = {"root": float(root_z), "scale": float(scale)}
	for p in sorted(gbind):
		for i in range(3):
			c["%s:r%d" % (p, i)] = float(g[p]["rot"][i])
			c["%s:l%d" % (p, i)] = float(g[p]["loc"][i])
	return c


def golem_pose(gbind, g):
	return {p: g[p]["rot"] for p in gbind}, {p: g[p]["loc"] for p in gbind}


def golem_key(gbind, k):
	return golem_values(gbind, k["golem"], k.get("golem_root_z", 0), 1)


def golem_idle_at(data, gbind):
	"""The golem's breathing loop: a cosine between golem_idle's 2 approved keys."""
	move = data["moves"]["golem_idle"]
	assert move["loop"]
	a, b = (golem_key(gbind, k) for k in move["keys"])
	at = loop2(move["keys"], move["end"])
	return lambda t: at(t % move["end"], a, b)


def golem_track(gbind, name, duration, stops, segments, keep=(), trembles=()):
	"""One golem track through its stops [(t, channels)]. The stops (approved keys among them) come out verbatim at their times."""
	stops = [(round(t, 6), v) for t, v in stops]  # 0.6 + 3.2 is not 3.8: the stop must land on its grid sample
	keep = [round(t, 6) for t in keep]
	times = [t for t, _ in stops]
	values = [v for _, v in stops]
	at = track(times, values, segments)
	grid = np.linspace(0, duration, int(round(duration * RATE)) + 1)
	samples = [at(t) for t in grid]
	sec = secondary(grid, samples, (), list(trembles), times, name)
	frames = []
	for i, t in enumerate(grid):
		c = dict(samples[i])
		for channel, curve in sec.items():
			c[channel] += float(curve[i])
		frames.append(c)
	for k, v in stops:
		i = int(round(k * RATE))
		assert abs(grid[i] - k) < 1e-9 and max(abs(frames[i][c] - v[c]) for c in v) < 1e-6, f"{name} off its stop at {k}"
		frames[i] = dict(v)
	return thin_golem(gbind, grid, frames, sorted(set(times) | set(keep))), times


def thin_golem(gbind, grid, frames, keep):
	# thinned as raga frames: (t, {pseudo part: 3 numbers}, (scale, 0, root)); locations x100, so its 0.2 tolerance is 0.002 units
	packed, by_time = [], {}
	for t, c in zip(grid, frames):
		body = {}
		for p in sorted(gbind):
			body[p] = tuple(c["%s:r%d" % (p, i)] for i in range(3))
			body[p + "@"] = tuple(c["%s:l%d" % (p, i)] * 100 for i in range(3))
		packed.append((float(t), body, (c["scale"], 0.0, c["root"])))
		by_time[float(t)] = c
	return [(f[0], by_time[f[0]]) for f in raga.thin(packed, sorted(packed[0][1]), keep)]


def golem_tracks(data, gbind, verts):
	"""Every golem track: name -> (frames, approved stop times, events, duration, snaps). golem and golem_fall play beside her
	moves of those names; golem_idle, golem_slam and golem_sweep are GolemMoves, on the golem's own clock."""
	moves = data["moves"]
	g = [k for k in moves["golem"]["keys"] if k.get("golem")]
	sw, fall = moves["golem_sweep"]["keys"], moves["golem_fall"]["keys"]
	assert [k["t"] for k in g] == [0.7, 1.4, 2.0, 4.2, 4.8] and g[2].get("hold_until") == 4.0 and g[3].get("event") == "Slam"
	assert [k["t"] for k in sw] == [0, 0.6, 2.0, 2.4, 3.2] and sw[1].get("hold_until") == 1.8 and sw[2].get("event") == "Sweep"
	assert [k["t"] for k in fall] == [0, 0.6, 1.4]
	idle_at = golem_idle_at(data, gbind)
	idle0 = golem_key(gbind, moves["golem_idle"]["keys"][0])
	first, hold_slam = g[3]["t"], 0.08
	out = {}

	# golem: rises, stands, the first slam (hit 1), then into golem_idle key 0 at its end. The 4.8 crumble key is golem_fall's now.
	scatter = g[0]["golem"]
	start = golem_values(gbind, scatter, -(golem_top(gbind, verts, *golem_pose(gbind, scatter)) + GOLEM_SINK), 0)
	rng = random.Random("golem")
	for p in sorted(gbind):
		for i in range(3):
			start["%s:r%d" % (p, i)] += rng.uniform(-GOLEM_TUMBLE, GOLEM_TUMBLE)
	end = moves["golem"]["end"]
	frames, times = golem_track(
		gbind,
		"golem_track",
		end,
		[(0, start)] + [(k["t"], golem_key(gbind, k)) for k in g[:4]] + [(end, idle0)],
		(
			{"ease": eout(2.2)},  # rubble rises out of the floor, tumbling, and grows
			{"ease": eout(2.6)},  # flies together and locks
			{"ease": ease(2.0), "carry": 0.08},
			{"ease": ein(3.0), "hold": 2.0},  # wind-up held to 4.0 s, then the slam
			{"ease": ease(2.0), "hold": hold_slam},  # stuck on the slam, then back to its breathing stance
		),
		(g[2]["hold_until"], first + hold_slam),
		[TREMBLE["golem_track"]],
	)
	out["golem"] = (frames, times[1:-1], [{"Time": first, "Name": "Slam"}], end, [(g[2]["hold_until"], first + SNAP)], times)

	# The attack tracks after hit 1. Each starts from golem_idle at the phase the schedule reaches it with (so no pop), leads
	# into the approved keys, and recovers to golem_idle key 0, where the next idle phase starts.
	lead, recover = 0.6, 0.8
	slam_hit = round(lead + (first - g[2]["t"]), 6)  # 2.8: the slam's wind-up key at the lead's end, its hit 2.2 s later as approved
	slam_len = round(slam_hit + recover, 6)
	sweep_hit, sweep_len = round(lead + sw[2]["t"], 6), round(lead + sw[-1]["t"] + 0.4, 6)
	lengths = {"golem_slam": (slam_len, slam_hit), "golem_sweep": (sweep_len, sweep_hit)}
	phase = {}
	for k in range(2, 14):
		name, s, _ = golem_window(k, first, end, lengths)
		_, _, prev_end = golem_window(k - 1, first, end, lengths)
		ph = (s - prev_end) % moves["golem_idle"]["end"]
		assert abs(phase.setdefault(name, ph) - ph) < 1e-9, f"{name}: the idle phase it starts from changes with k"

	shift = slam_hit - first
	frames, times = golem_track(
		gbind,
		"golem_slam",
		slam_len,
		[(0, idle_at(phase["golem_slam"])), (lead, golem_key(gbind, g[2])), (slam_hit, golem_key(gbind, g[3])), (slam_len, idle0)],
		(
			{"ease": ease(2.0)},
			{"ease": ein(3.0), "hold": g[2]["hold_until"] - g[2]["t"]},  # wind-up held, then the slam
			{"ease": ease(2.0), "hold": hold_slam},
		),
		(g[2]["hold_until"] + shift, slam_hit + hold_slam),
		[tuple([a + shift for a in TREMBLE["golem_track"][:2]]) + TREMBLE["golem_track"][2:]],
	)
	out["golem_slam"] = (frames, times[1:3], [{"Time": slam_hit, "Name": "Slam"}], slam_len, [(g[2]["hold_until"] + shift, slam_hit + SNAP)], times)

	sweep_hold = round(sw[1]["hold_until"] + lead, 6)
	frames, times = golem_track(
		gbind,
		"golem_sweep",
		sweep_len,
		[(0, idle_at(phase["golem_sweep"]))] + [(lead + k["t"], golem_key(gbind, k)) for k in sw] + [(sweep_len, idle0)],
		(
			{"ease": ease(2.0)},
			{"ease": ease(2.0)},  # into the wind-up
			{"ease": ein(3.0), "hold": sw[1]["hold_until"] - sw[1]["t"]},  # wind-up held, then the sweep
			{"ease": eout(2.0), "carry": 0.1},  # the arm carries through
			{"ease": ease(2.0)},
			{"ease": ease(2.0)},  # its stance, into golem_idle key 0
		),
		(sweep_hold,),
		[(lead + sw[1]["t"], sweep_hold, 1.5, TREMBLE["golem_track"][3])],
	)
	out["golem_sweep"] = (frames, times[1:-1], [{"Time": sweep_hit, "Name": "Sweep"}], sweep_len, [(sweep_hold, sweep_hit + SNAP)], times)

	# golem_idle: 2 approved keys, cosine between them
	period = moves["golem_idle"]["end"]
	grid = np.linspace(0, period, int(round(period * RATE)) + 1)
	gk = [golem_key(gbind, k) for k in moves["golem_idle"]["keys"]]
	frames = [idle_at(t) for t in grid[:-1]] + [dict(gk[0])]
	for k, v in zip(moves["golem_idle"]["keys"], gk):
		frames[int(round(k["t"] * RATE))] = dict(v)
	out["golem_idle"] = (thin_golem(gbind, grid, frames, [k["t"] for k in moves["golem_idle"]["keys"]] + [period]), [0, period / 2], [], period, [], [0, period / 2, period])

	# golem_fall: the approved fall keys, then its rubble shrinks and sinks into the floor (scale 0) by 2.0 s
	heap = fall[-1]["golem"]
	sunk = golem_values(gbind, heap, -(golem_top(gbind, verts, *golem_pose(gbind, heap)) + GOLEM_SINK), 0)
	fall_end = moves["golem_fall"]["end"]
	frames, times = golem_track(
		gbind,
		"golem_fall",
		fall_end,
		[(k["t"], golem_key(gbind, k)) for k in fall] + [(fall_end, sunk)],
		({"ease": ease(2.0)}, {"ease": ease(2.0)}, {"ease": ein(2.0)}),
	)
	out["golem_fall"] = (frames, times[:-1], [], fall_end, [], times)
	return out, lengths


def golem_window(k, first, summon_end, lengths):
	"""Golem hit k's track: (name, start, end) on the golem clock. Hit 1 is the golem move's slam, inside the summon."""
	if k < 2:
		return "golem", 0.0, summon_end
	name = "golem_slam" if k % 2 == 1 else "golem_sweep"
	duration, event = lengths[name]
	start = first + GOLEM_EVERY * (k - 1) - event
	return name, start, start + duration


def golem_rotations(track, parts):
	"""The golem track as raga frames of rotations alone, for check()."""
	return [(t, {p: np.array([c["%s:r%d" % (p, i)] for i in range(3)]) for p in parts}, (0.0, 0.0, 0.0)) for t, c in track]


# ---- checks ----


def check(name, frames, parts, events, duration, snaps=(), root=True):
	"""The raga test's limits, a 60 Hz frame at a time, except within SNAP of a hit event or inside a snap window."""
	free = [(e - SNAP, e + SNAP) for e in events] + list(snaps)
	worst, worst_at, worst_part, worst_root = 0, 0, None, 0
	prev = raga.lerp_frame(frames, 0, parts)
	for k in range(1, int(duration * 60 + 1e-6) + 1):
		t = k / 60
		cur = raga.lerp_frame(frames, t, parts)
		if not any(a <= t <= b for a, b in free):
			for p in parts:
				d = float(np.abs(cur[0][p] - prev[0][p]).max())
				if d > worst:
					worst, worst_at, worst_part = d, t, p
			worst_root = max(worst_root, float(np.abs(cur[1] - prev[1]).max()))
		prev = cur
	gaps = max(b[0] - a[0] for a, b in zip(frames, frames[1:]))
	print(f"BAKE {name}: {len(frames)} keys, largest gap {gaps:.4f} s, worst {worst:.2f} deg/frame at {worst_at:.2f} s on {worst_part}, root {worst_root:.4f}/frame")
	assert worst <= LIMIT_DEGREES, f"{name}: {worst} degrees in a frame"
	assert worst_root <= LIMIT_OFFSET or not root, f"{name}: root {worst_root} in a frame"
	assert gaps <= raga.MAX_GAP + 1e-9, f"{name}: a key gap of {gaps} s"
	assert frames[0][0] == 0 and abs(frames[-1][0] - duration) < 1e-9, name
	assert all(0 < e < duration for e in events), f"{name}: an event outside the move"


def check_cycle(moves):
	"""The shortest gap between two hit events, the cycle repeating, and every move covered."""
	at, hits = 0.0, []
	for row in CYCLE:
		_, _, events, duration, _ = moves[row[0]]
		hits += [at + e["Time"] for e in events]
		at += row[2] if row[0] == "idle" else duration
		if row[0] == "golem_in":
			slot = at  # the golem stands here: her clock stops until it falls
	gaps = [b - a for a, b in zip(hits, hits[1:] + [hits[0] + at])]
	print(f"BAKE cycle {at:.2f} s, hit events at {[round(h, 2) for h in hits]}, shortest gap {min(gaps):.2f} s, golem slot {slot:.2f} s")
	assert min(gaps) >= MIN_HIT_GAP, f"two hit events {min(gaps)} s apart"
	assert min(slot - h for h in hits if h < slot) >= MIN_HIT_GAP, "a Dodge bar would still be open at the golem slot"
	assert {r[0] for r in CYCLE} | {"golem", "watch", "watch_in"} == set(moves), "a move missing from the cycle"
	led = {"lightning_in": "lightning", "barrage_in": "barrage", "golem_in": "golem_fall"}
	for i, row in enumerate(CYCLE):
		if row[0] in led:
			assert CYCLE[i + 1][0] == led[row[0]], "a lead not right before its move"
		elif row[0] != "idle":
			assert led.get(CYCLE[i - 1][0]) == row[0], "an attack not led into"
	return slot, at


def golem_at(tau, tracks, lengths, first):
	"""Poses.GolemAt in Python (the Luau mirrors it): her move and time, the golem's move and time, tau s after BossMinionStart."""
	summon, lead_in = tracks["golem"][3], WATCH_LEAD
	if tau < summon:
		return "golem", tau, "golem", tau
	h = ("watch_in", tau - summon) if tau < summon + lead_in else ("watch", (tau - summon - lead_in) % 3.0)
	k = int((tau - first) // GOLEM_EVERY) + 1
	name, start, _ = golem_window(k + 1, first, summon, lengths)
	if tau >= start:
		return h + (name, tau - start)
	name, start, finish = golem_window(k, first, summon, lengths)
	if tau < finish:
		return h + (name, tau - start)
	return h + ("golem_idle", (tau - finish) % tracks["golem_idle"][3])


def check_golem(tracks, lengths, first, parts):
	"""The golem clock: tracks never overlap, every hit's circles open after the track before it ends, Slam and Sweep take turns,
	and the golem's joints stay inside the frame limit across track seams, 0 to 60 s."""
	summon = tracks["golem"][3]
	for k in range(1, 14):
		name, start, finish = golem_window(k, first, summon, lengths)
		hit = first + GOLEM_EVERY * (k - 1)
		assert abs(start + (tracks[name][2][0]["Time"]) - hit) < 1e-9, k
		assert tracks[name][2][0]["Name"] == ("Slam" if k % 2 == 1 else "Sweep"), k
		if k > 1:
			_, _, prev_end = golem_window(k - 1, first, summon, lengths)
			assert prev_end <= start + 1e-9, f"golem tracks {k - 1} and {k} overlap"
			assert hit - prev_end >= OSU_OPEN + 0.3 - 1e-9, f"hit {k}: circles open before track {k - 1} ends"
	rot = {n: golem_rotations(t[0], parts) for n, t in tracks.items()}
	free = []
	for k in range(1, 14):
		name, start, _ = golem_window(k, first, summon, lengths)
		free += [(start + a, start + b) for a, b in tracks[name][4]]
	worst, prev = 0, None
	for i in range(0, 60 * 60 + 1):
		tau = i / 60
		_, _, name, t = golem_at(tau, tracks, lengths, first)
		cur = raga.lerp_frame(rot[name], t, parts)[0]
		if prev is not None and not any(a <= tau <= b + 1e-9 for a, b in free) and tau > 1 / 60 + 1e-9:
			worst = max(worst, max(float(np.abs(cur[p] - prev[p]).max()) for p in parts))
		prev = cur
	print(f"BAKE golem clock: hits every {GOLEM_EVERY} s from {first}, worst {worst:.2f} deg/frame over 60 s")
	assert worst <= LIMIT_DEGREES, f"golem clock: {worst} degrees in a frame"


def check_bind(mage, raw, bind):
	"""The joint chain the client builds reproduces the approved key poses of boss_mage_keyframes.solve exactly."""
	for name in her(raw):
		move = mk.MOVES[name]
		assert len(move["keys"]) == len(raw["moves"][name]["keys"]), name
		for key, approved in zip(move["keys"], raw["moves"][name]["keys"]):
			m, record, grip = mk.solve(key)
			for p, v in record.items():  # keys.json is still what the approved solver makes
				assert max(abs(a - b) for a, b in zip(v, approved["rotations"][p])) < 1e-3, f"keys.json {name} {key['t']} {p} is not the solver's"
			assert max(abs(a - b) for a, b in zip(grip, approved["staff_grip_offset"])) < 1e-3
			rot = {p: approved["rotations"][p] for p in mage.parts}
			world = joints(bind, rot, approved["root_offset"])
			for p in mage.parts:
				mesh = "Staff" if p == "Staff" else p if p.startswith("Tail") else p + "_merged"
				want = m[mesh] @ Matrix.Translation(mage.data["pivots"][p])
				got = world[p]  # a vertex then sits at joint * (Center + its offset from the box centre)
				assert max(abs(a - b) for ra, rb in zip(want, got) for a, b in zip(ra, rb)) < 1e-3, f"bind {p} at {name} {key['t']}"


def joints(bind, rot, root):
	out = {}

	def m(n):
		if n not in out:
			b = bind[n]
			base = m(b["Parent"]) if b["Parent"] else Matrix.Translation(root)
			out[n] = base @ Matrix.Translation(b["Offset"]) @ Euler([math.radians(v) for v in rot[n]]).to_matrix().to_4x4()
		return out[n]

	for n in bind:
		m(n)
	return out


# ---- binds from the models ----


def local_verts(o):
	co = np.empty(len(o.data.vertices) * 3)
	o.data.vertices.foreach_get("co", co)
	return co.reshape(-1, 3)


def mage_bind(data, scale):
	"""Her parts as the client wants them. A part's joint is its keys.json pivot (the staff's sits on the fist: pivot + grip)."""
	objs = {o.name.replace("_merged", ""): o for o in bpy.data.objects if o.type == "MESH"}
	assert sorted(objs) == sorted(p for p in data["pivots"] if p != "Body"), sorted(objs)
	grips = {tuple(round(v, 3) + 0 for v in k["staff_grip_offset"]) for n in her(data) for k in data["moves"][n]["keys"]}
	assert len(grips) == 1, grips
	for n in her(data):
		for k in data["moves"][n]["keys"]:
			assert k["rotations"]["Body"] == [0, 0, 0], "Body turns: the bind would need it"
	parents = {p: (q if q != "Body" else None) for p, q in data["parents"].items() if p != "Body"}
	joint = {p: Vector(data["pivots"][p]) + (Vector(next(iter(grips))) if p == "Staff" else Vector()) for p in objs}
	bind = {}
	for p, o in objs.items():
		assert o.parent and o.parent.type == "EMPTY" and o.parent.matrix_world == Matrix.Identity(4) and o.matrix_basis.to_3x3() == Matrix.Identity(3)
		co = local_verts(o)
		lo, hi = co.min(axis=0), co.max(axis=0)
		mesh_origin = Vector(o.location) - Vector(data["pivots"][p])  # a vertex sits at pivot + this + co before posing
		parent = parents[p]
		bind[p] = {
			"Parent": parent,
			"Offset": tuple(joint[p] - (joint[parent] if parent else Vector())),
			"Center": tuple(mesh_origin + Vector((lo + hi) / 2)),
			"Size": tuple(((hi - lo) * scale)[[0, 2, 1]]),
			"Joint": tuple(joint[p]),
		}
		if p == "Staff":  # the gem at its head, from the joint: where the lightning leaves
			bind[p]["Tip"] = tuple(mesh_origin + Vector(co[co[:, 2] > co[:, 2].max() - 0.9].mean(axis=0)))
	return bind, objs


def golem_bind(scale_for):
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	assert len(objs) == 15, sorted(objs)
	root = next(o for o in bpy.data.objects if o.type == "EMPTY" and o.parent is None)
	assert root.matrix_world == Matrix.Identity(4)
	verts = {n: local_verts(o) for n, o in objs.items()}
	pts = np.vstack([(np.array(o.matrix_world)[:3, :3] @ verts[n].T).T + np.array(o.matrix_world)[:3, 3] for n, o in objs.items()])
	height = float(pts[:, 2].max() - pts[:, 2].min())
	scale = scale_for(height)
	bind = {}
	for n, o in objs.items():
		lo, hi = verts[n].min(axis=0), verts[n].max(axis=0)
		parent = o.parent.name if o.parent.type == "MESH" else None
		bind[n] = {
			"Parent": parent,
			"Offset": tuple(o.location),
			"Rest": tuple(math.degrees(v) for v in o.rotation_euler),
			"Center": tuple((lo + hi) / 2),
			"Size": tuple(((hi - lo) * scale)[[0, 2, 1]]),
		}
	rest = golem_world(bind, {n: b["Rest"] for n, b in bind.items()}, {n: b["Offset"] for n, b in bind.items()})
	for n, o in objs.items():  # parent inverses are identity: the keys.json loc/rot chain is the model
		assert max(abs(a - b) for ra, rb in zip(rest[n], o.matrix_world) for a, b in zip(ra, rb)) < 1e-4, n
	return bind, objs, verts, height, float(pts[:, 2].min()), scale


# ---- the Luau file ----

EXTRA = """
Poses.RootStuds = ROOT_STUDS -- studs per keys.json root_offset unit (the 4x size it was approved at): Keys' Root is already studs
Poses.HoverStuds = HOVER -- her rest feet above the arena floor
Poses.GolemBind = GOLEM_BIND -- as Bind, in golem units, Size in studs at GolemScale; Rest is its rest rotation (XYZ degrees)
Poses.GolemScale = GOLEM_SCALE -- studs per golem unit
-- The golem's root (its rest feet) from her anchor (her rest feet), studs, Blender axes, and its turn about Z (up) from her facing.
Poses.GolemAnchor = Vector3.new(GOLEM_ANCHOR[1], GOLEM_ANCHOR[2], GOLEM_ANCHOR[3])
Poses.GolemYaw = GOLEM_YAW

Poses.GolemMoves = GOLEM_MOVES -- the golem's own tracks on its clock (BossMinionStart): Duration, Events, Golem frames
Poses.GolemSlotAt = GOLEM_SLOT_AT -- her cycle time where the golem stands (the end of golem_in): her clock stops there
Poses.GolemFirstHit = GOLEM_FIRST_HIT -- golem hit 1, s after BossMinionStart: the golem move's Slam
Poses.GolemEvery = GOLEM_EVERY -- s between two golem hits

local function golemVectors(keys)
	for _, key in keys do
		for part, v in key.Parts do
			key.Parts[part] = Vector3.new(v[1], v[2], v[3])
		end
		for part, v in key.Locs do
			key.Locs[part] = Vector3.new(v[1], v[2], v[3])
		end
		key.Root = Vector3.new(key.Root[1], key.Root[2], key.Root[3])
	end
end
for _, move in MOVES do
	if move.Golem then
		golemVectors(move.Golem)
	end
end
for _, move in GOLEM_MOVES do
	golemVectors(move.Golem)
end

-- The golem at time t of a move (golem or golem_fall in Moves, or any GolemMoves track), clamped: scale (0 = absent: hide it;
-- else each block's size times it, about its own centre), parts[part] (XYZ Euler degrees) and locs[part] (golem units from its
-- parent's joint) for joint = CFrame.new(loc) * rotation, and the root offset in golem units. A move without golem frames: scale 0.
function Poses.SampleGolem(name, t)
	local move = MOVES[name] or GOLEM_MOVES[name]
	local golemKeys = move and move.Golem
	if not golemKeys then
		return 0, {}, {}, Vector3.zero
	end
	local low, high = 1, #golemKeys
	if t <= golemKeys[1].Time then
		high = 1
	elseif t >= golemKeys[high].Time then
		low = high
	end
	while high - low > 1 do
		local middle = (low + high) // 2
		if golemKeys[middle].Time <= t then
			low = middle
		else
			high = middle
		end
	end
	local a, b = golemKeys[low], golemKeys[high]
	local u = low == high and 0 or (t - a.Time) / (b.Time - a.Time)
	local parts, locs = {}, {}
	for part in GOLEM_BIND do
		parts[part] = a.Parts[part]:Lerp(b.Parts[part], u)
		locs[part] = a.Locs[part]:Lerp(b.Locs[part], u)
	end
	return a.Scale + (b.Scale - a.Scale) * u, parts, locs, a.Root:Lerp(b.Root, u)
end

-- Golem hit k (1, 2, ...): its time, s after BossMinionStart, and its name (Slam on odd k, Sweep on even k).
function Poses.GolemHit(k)
	return GOLEM_FIRST_HIT + GOLEM_EVERY * (k - 1), k % 2 == 1 and "Slam" or "Sweep"
end

-- Hit k's track (k >= 2): its name, start and end on the golem clock.
local function golemTrack(k)
	local name = k % 2 == 1 and "golem_slam" or "golem_sweep"
	local move = GOLEM_MOVES[name]
	local start = Poses.GolemHit(k) - move.Events[1].Time
	return name, start, start + move.Duration
end

-- While the golem stands, tau s after BossMinionStart: her move and time, the golem's move and time (SampleGolem's arguments).
-- Pure, like Schedule: every client shows the same pose at the same moment.
function Poses.GolemAt(tau)
	local summon, lead = MOVES.golem.Duration, MOVES.watch_in.Duration
	if tau < summon then
		return "golem", tau, "golem", tau
	end
	local herMove, herTime = "watch", (tau - summon - lead) % MOVES.watch.Duration
	if tau < summon + lead then
		herMove, herTime = "watch_in", tau - summon
	end
	local k = (tau - GOLEM_FIRST_HIT) // GOLEM_EVERY + 1
	local name, start = golemTrack(k + 1)
	if tau >= start then
		return herMove, herTime, name, tau - start
	end
	local last = summon
	if k >= 2 then
		local finish
		name, start, finish = golemTrack(k)
		if tau < finish then
			return herMove, herTime, name, tau - start
		end
		last = finish
	end
	return herMove, herTime, "golem_idle", (tau - last) % GOLEM_MOVES.golem_idle.Duration
end

return Poses
"""


def functions():
	text = raga.FUNCTIONS
	impact = "Poses.ImpactPoint = Vector3.new(IMPACT[1], IMPACT[2], IMPACT[3]) -- model units, Blender axes: the blade tip at Impact\n"
	units = "rootOffset a Vector3 in units."
	assert text.count(impact) == 1 and text.count(units) == 1 and text.endswith("\nreturn Poses\n")
	text = text.replace(impact, "").replace(units, "rootOffset a Vector3 in studs.")
	return text[: -len("\nreturn Poses\n")] + "\n" + EXTRA


def bind_lines(bind, extra=()):
	out = []
	for name, b in sorted(bind.items()):
		more = "".join(", %s = %s" % (k, raga.vec(b[k], 3)) for k in extra if k in b)
		parent = '"%s"' % b["Parent"] if b["Parent"] else "nil"
		out.append("\t%s = { Parent = %s, Offset = %s, Center = %s, Size = %s%s }," % (name, parent, raga.vec(b["Offset"], 4), raga.vec(b["Center"], 4), raga.vec(b["Size"], 2), more))
	return out


def golem_lines(gbind, frames, pinned):
	out = ["\t\tGolem = {"]
	for t, c in frames:
		places = 3 if any(abs(t - p) < 1e-9 for p in pinned) else 1
		rot = ",".join("%s=%s" % (p, raga.vec([c["%s:r%d" % (p, i)] for i in range(3)], places)) for p in sorted(gbind))
		loc = ",".join("%s=%s" % (p, raga.vec([c["%s:l%d" % (p, i)] for i in range(3)], 3)) for p in sorted(gbind))
		out.append("\t\t\t{Time=%s,Scale=%s,Root={0,0,%s},Parts={%s},Locs={%s}}," % (raga.fmt(t, 4), raga.fmt(c["scale"], 3), raga.fmt(c["root"], 3), rot, loc))
	out.append("\t\t},")
	return out


def write_luau(mage, bind, moves, golem, consts):
	fmt, vec = raga.fmt, raga.vec
	root_studs = consts["root_studs"]
	lines = [
		"--!nonstrict",
		"-- Generated by tools/blender/bake_boss_mage.py from assets/characters_avatar/boss_mage/keyframes/keys.json. Do not edit by hand.",
		'-- The Elf Mage\'s moves and her golem (design doc 4.37 "Second boss", docs/BOSS_EVENT_SPEC.md "The Elf Mage"), client-side visuals;',
		"-- the server reads Schedule and Events only. Same shape as BossRagaPoses. Owner-approved keys (2026-11-11) are verbatim at their",
		"-- times; Time is seconds, Parts XYZ Euler degrees, Root STUDS (not model units: the hover bob is 1.5 studs at any size).",
		"-- Proposed: the 8x Scale's hover %s studs, the leads (<move>_in, %s s), CYCLE, the golem's spot and every in-between."
		% (fmt(consts["hover"]), "/".join(fmt(LEAD[m]) for m in ("lightning", "golem", "barrage"))),
		"-- Body never turns, so it is not a part: Torso and the legs are roots, at Offset + Root.",
		"local Event = require(script.Parent.BossEventConfig)",
		"",
		"local SCALE = %s -- studs per model unit: %s x a %s-stud character, %s studs tall" % (fmt(consts["scale"], 4), SIZE, fmt(mk.CHAR_H), fmt(consts["height"], 1)),
		"local ROOT_STUDS = %s" % fmt(root_studs, 4),
		"local HOVER = %s" % fmt(consts["hover"]),
		"local GOLEM_SCALE = %s -- %s x her height" % (fmt(consts["golem_scale"], 4), mk.GOLEM_RATIO),
		"local GOLEM_ANCHOR = %s" % vec(consts["golem_anchor"], 3),
		"local GOLEM_YAW = %s" % fmt(consts["golem_yaw"], 3),
		"local GOLEM_SLOT_AT = %s" % fmt(consts["slot_at"], 3),
		"local GOLEM_FIRST_HIT = %s" % fmt(consts["first_hit"], 3),
		"local GOLEM_EVERY = %s" % fmt(GOLEM_EVERY, 3),
		"-- stylua: ignore",
		"local BIND = {",
		*bind_lines(bind, ("Tip",)),
		"}",
		"-- stylua: ignore",
		"local GOLEM_BIND = {",
		*bind_lines(golem["bind"], ("Rest",)),
		"}",
		"-- stylua: ignore",
		"local MOVES = {",
	]
	for name in sorted(moves):
		frames, approved, events, duration, _ = moves[name]
		pinned = set(approved)
		moved = [p for p in mage.parts if any(max(abs(a - b) for a, b in zip(f[1][p], frames[0][1][p])) > 1e-3 for f in frames)]
		held = [p for p in mage.parts if p not in moved]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in approved))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		if "Window" in mage.data["moves"].get(name, {}):
			lines.append("\t\tWindow = { %s }," % ", ".join(fmt(v, 3) for v in mage.data["moves"][name]["Window"]))
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}}," % (fmt(f[0], 4), vec([v * root_studs for v in f[2]], 4), body))
		lines.append("\t\t},")
		if name in ("golem", "golem_fall"):
			lines += golem_lines(golem["bind"], golem["tracks"][name][0], golem["tracks"][name][5])
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local GOLEM_MOVES = {"]
	for name in ("golem_idle", "golem_slam", "golem_sweep"):
		frames, _, events, duration, _, stops = golem["tracks"][name]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		lines += golem_lines(golem["bind"], frames, stops)
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name in her(mage.data):
		m = mage.data["moves"][name]
		lines.append("\t%s = {" % name)
		for k in m["keys"]:
			assert all(float(fmt(v, 4)) == v for v in k["root_offset"]), f"{name} {k['t']}: a root would not print verbatim"
			assert all(float(fmt(v, 3)) == v for p in mage.parts for v in k["rotations"][p]), f"{name} {k['t']}: a rotation would not print verbatim"
			body = ",".join("%s=%s" % (p, vec(k["rotations"][p], 3)) for p in mage.parts)
			lines.append("\t\t{Time=%s,RootOffset=%s,Parts={%s}}," % (fmt(k["t"], 3), vec(k["root_offset"], 4), body))
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local CYCLE = {"]
	for row in CYCLE:
		lines.append("\t{%s}," % ", ".join('"%s"' % v if isinstance(v, str) else str(v) for v in row))
	lines.append("}")
	text = "\n".join(lines) + "\n" + functions()
	with open(LUAU, "w") as f:
		f.write(text)
	print(f"BAKE wrote {LUAU}: {len(text)} bytes, {sum(len(m[0]) for m in moves.values())} keys, golem {sum(len(t[0]) for t in golem['tracks'].values())} keys")


def check_verbatim(mage, moves):
	"""Every approved key of keys.json sits in its move's baked keys unchanged, at its time."""
	for name in her(mage.data):
		m = mage.data["moves"][name]
		frames = {f[0]: f for f in moves[name][0]}
		assert moves[name][1] == [k["t"] for k in m["keys"]], name
		for k in m["keys"]:
			f = frames[k["t"]]
			assert all(list(f[1][p]) == k["rotations"][p] for p in mage.parts) and list(f[2]) == k["root_offset"], f"{name} {k['t']} not verbatim"
		if name in EVENTS:
			assert [e["Name"] for e in moves[name][2]] == [EVENTS[name]], name
			if "Window" in m:  # a windowed move charges at the window's start
				assert [e["Time"] for e in moves[name][2]] == [m["Window"][0]], name


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	wanted = [a for a in argv if a in ("poses", "glb")] or ["poses", "glb"]
	with open(KEYS) as f:
		raw = json.load(f)
	data = merged(raw)
	mage = Mage(data)
	height = SIZE * mk.CHAR_H
	scale = height / data["scale"]["model_height_units"]
	root_studs = data["scale"]["studs_per_model_unit_at_4x"]
	assert abs(root_studs - 4 * mk.CHAR_H / data["scale"]["model_height_units"]) < 1e-3
	assert data["moves"]["watch"]["end"] == 3.0  # golem_at's watch period

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_mage"])
	bind, objs = mage_bind(data, scale)
	check_bind(mage, raw, bind)
	if "glb" in wanted:
		for p, o in objs.items():
			o.name = o.data.name = p
		raga.write_glb(objs, GLB["boss_mage"])

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_golem"])
	gbind, gobjs, gverts, golem_h, golem_low, golem_scale = golem_bind(lambda h: mk.GOLEM_RATIO * height / h)
	tracks, lengths = golem_tracks(data, gbind, gverts)
	if "glb" in wanted:
		raga.write_glb(gobjs, GLB["boss_golem"])

	if "poses" in wanted:
		gkeys = data["moves"]["golem"]["keys"]
		slam = next(k["t"] for k in gkeys if k.get("event") == "Slam")
		slam_from = next(k["hold_until"] for k in gkeys if "hold_until" in k)
		idle0, watch0 = mage.idle0, data["moves"]["watch"]["keys"][0]
		moves = {"idle": mage.idle(), "watch": mage.watch()}
		for name in PLAN:
			moves[name] = mage.attack(name)
			moves[name + "_in"] = mage.lead(name + "_in", idle0, data["moves"][name]["keys"][0], LEAD[name])
		moves["watch_in"] = mage.lead("watch_in", idle0, watch0, WATCH_LEAD)
		moves["golem_fall"] = mage.lead("golem_fall", watch0, idle0, data["moves"]["golem_fall"]["end"], ({"ease": ease(2.0)},))
		for name, (frames, approved, events, duration, keep) in list(moves.items()):
			thinned = raga.thin(frames, mage.parts, keep)
			snaps = [(slam_from, slam + SNAP)] if name == "golem" else []  # the slam, from the end of the held wind-up to the hit
			check(name, thinned, mage.parts, [e["Time"] for e in events], duration, snaps)
			moves[name] = (thinned, approved, events, duration, keep)
		check_verbatim(mage, moves)
		slot_at, cycle_s = check_cycle(moves)
		gparts = sorted(gbind)
		for name, (frames, _, events, duration, snaps, _) in tracks.items():
			check(name + " (golem)", golem_rotations(frames, gparts), gparts, [e["Time"] for e in events], duration, snaps, root=False)
			assert all(len([c for c in f if c.endswith(":r0")]) == 15 for _, f in frames), f"{name}: a golem block without keys"
		check_golem(tracks, lengths, slam, gparts)
		# every approved golem key verbatim at its (track) time
		m = data["moves"]
		g = [k for k in gkeys if k.get("golem")]
		placed = {
			"golem": [(k["t"], k) for k in g[:4]],
			"golem_slam": [(0.6, g[2]), (2.8, g[3])],
			"golem_sweep": [(0.6 + k["t"], k) for k in m["golem_sweep"]["keys"]],
			"golem_fall": [(k["t"], k) for k in m["golem_fall"]["keys"]],
			"golem_idle": [(k["t"], k) for k in m["golem_idle"]["keys"]],
		}
		for name, keyed in placed.items():
			gk = {round(t, 6): c for t, c in tracks[name][0]}
			for t, k in keyed:
				c = gk[round(t, 6)]
				for p in gparts:
					assert [c["%s:r%d" % (p, i)] for i in range(3)] == k["golem"][p]["rot"], (name, t, p)
					assert [c["%s:l%d" % (p, i)] for i in range(3)] == k["golem"][p]["loc"], (name, t, p)
				assert c["scale"] == 1 and c["root"] == k.get("golem_root_z", 0), (name, t)
		first = lambda n: tracks[n][0][0][1]["scale"]  # noqa: E731
		last = lambda n: tracks[n][0][-1][1]["scale"]  # noqa: E731
		assert first("golem") == 0 and last("golem") == 1 and first("golem_fall") == 1 and last("golem_fall") == 0, "golem scale ends"
		assert tracks["golem_slam"][3] == 3.6 and tracks["golem_sweep"][3] == 4.2 and tracks["golem_idle"][3] == 2.4
		for name, (frames, *_rest) in moves.items():
			assert all(set(f[1]) == set(bind) for f in frames), f"{name}: a part without keys"
		# her floor offset: her lowest point sits on the arena floor plus the hover; the golem stands on that floor beside her
		yaw = -25.0  # boss_mage_keyframes.load_scene: turned a little toward the arena centre
		anchor = (GAME_GOLEM_SPOT[0], GAME_GOLEM_SPOT[1], -mk.HOVER - golem_low * golem_scale)
		consts = {
			"scale": scale,
			"height": height,
			"root_studs": root_studs,
			"hover": mk.HOVER,
			"golem_scale": golem_scale,
			"golem_anchor": anchor,
			"golem_yaw": yaw,
			"slot_at": slot_at,
			"first_hit": slam,
		}
		print(f"BAKE scale {scale:.4f} studs/unit, golem {golem_h:.3f} units x {golem_scale:.4f} = {golem_h * golem_scale:.1f} studs, anchor {anchor}")
		print(f"BAKE cycle {cycle_s:.3f} s, golem slot {slot_at:.3f} s")
		write_luau(mage, bind, moves, {"bind": gbind, "tracks": tracks}, consts)
		print("BAKE self-check passed")


if __name__ == "__main__":
	main()
