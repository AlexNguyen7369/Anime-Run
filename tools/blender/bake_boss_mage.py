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
	("golem",),
	("idle", 0, 3),
)
EVENTS = {"lightning": "Lightning", "golem": "Slam", "barrage": "Barrage"}
ease, eout, ein = raga.inout, raga.eout, raga.ein
# One row per segment between stops (approved keys, then the hover at the move's end). ease, hold (s stopped at its start),
# carry (overshoot past its first key, a share of the segment before), anticipate (a pull the wrong way first, a share of it).
PLAN = {
	"lightning": (
		{"ease": ease(2.0)},  # the coil climbs into the charge
		{"ease": ein(2.4), "hold": 0.05},  # the orb builds, then the thrust
		{"ease": eout(2.5), "carry": 0.15},  # thrown into the strike
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
		events = [{"Time": k["t"], "Name": k["event"]} for k in keys if "event" in k]
		return self.pin(frames, keys, name), [k["t"] for k in keys], events, move["end"], sorted(set(times + holds))

	def lead(self, name):
		length = LEAD[name]
		values = [self.channels(self.idle0), self.channels(self.data["moves"][name]["keys"][0])]
		frames = self.sample(name + "_in", [0, length], values, LEAD_PLAN, length, [0, length])
		frames[0], frames[-1] = self.frame(0, values[0]), self.frame(length, values[1])
		return frames, [], [], length, [0, length]

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


def golem_track(data, gbind, verts):
	move = data["moves"]["golem"]
	keys = [k for k in move["keys"] if k.get("golem")]
	parts = sorted(gbind)

	def values(g, root_z, scale):
		c = {"root": float(root_z), "scale": float(scale)}
		for p in parts:
			for i in range(3):
				c["%s:r%d" % (p, i)] = float(g[p]["rot"][i])
				c["%s:l%d" % (p, i)] = float(g[p]["loc"][i])
		return c

	def pose(g):
		return {p: g[p]["rot"] for p in parts}, {p: g[p]["loc"] for p in parts}

	scatter, crumble = keys[0]["golem"], keys[-1]["golem"]
	rise = golem_top(gbind, verts, *pose(scatter)) + GOLEM_SINK
	fall = golem_top(gbind, verts, *pose(crumble)) + GOLEM_SINK
	rng = random.Random("golem")
	start = values(scatter, -rise, 0)
	for p in parts:
		for i in range(3):
			start["%s:r%d" % (p, i)] += rng.uniform(-GOLEM_TUMBLE, GOLEM_TUMBLE)
	end = values(crumble, -fall, 0)
	times = [0] + [k["t"] for k in keys] + [move["end"]]
	stops = [start] + [values(k["golem"], k.get("golem_root_z", 0), 1) for k in keys] + [end]
	segments = (
		{"ease": eout(2.2)},  # rubble rises out of the floor, tumbling, and grows
		{"ease": eout(2.6)},  # flies together and locks
		{"ease": ease(2.0), "carry": 0.08},
		{"ease": ein(3.0), "hold": 2.0},  # wind-up held to 4.0 s, then the slam
		{"ease": ein(1.5), "hold": 0.08},  # stuck on the slam, then it falls apart
		{"ease": ease(2.0)},  # the rubble sinks back into the floor
	)
	assert [k["t"] for k in keys] == [0.7, 1.4, 2.0, 4.2, 4.8] and keys[2].get("hold_until") == 4.0
	at = track(times, stops, segments)
	grid = np.linspace(0, move["end"], int(round(move["end"] * RATE)) + 1)
	samples = [at(t) for t in grid]
	sec = secondary(grid, samples, (), [TREMBLE["golem_track"]], times, "golem_track")
	frames = []
	for i, t in enumerate(grid):
		c = dict(samples[i])
		for channel, curve in sec.items():
			c[channel] += float(curve[i])
		frames.append(c)
	for k, v in zip(times, stops):  # the keys.json values verbatim at their times
		i = int(round(k * RATE))
		assert abs(grid[i] - k) < 1e-9 and max(abs(frames[i][c] - v[c]) for c in v) < 1e-6, f"golem track off its key at {k}"
		frames[i] = dict(v)
	# thinned as raga frames: (t, {pseudo part: 3 numbers}, (scale, 0, root)); locations x100, so its 0.2 tolerance is 0.002 units
	packed, by_time = [], {}
	for t, c in zip(grid, frames):
		body = {}
		for p in parts:
			body[p] = tuple(c["%s:r%d" % (p, i)] for i in range(3))
			body[p + "@"] = tuple(c["%s:l%d" % (p, i)] * 100 for i in range(3))
		packed.append((float(t), body, (c["scale"], 0.0, c["root"])))
		by_time[float(t)] = c
	keep = sorted(set(times + [keys[2]["hold_until"], 4.2 + segments[4]["hold"]]))
	return [(f[0], by_time[f[0]]) for f in raga.thin(packed, sorted(packed[0][1]), keep)], times


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
	gaps = [b - a for a, b in zip(hits, hits[1:] + [hits[0] + at])]
	print(f"BAKE cycle {at:.2f} s, hit events at {[round(h, 2) for h in hits]}, shortest gap {min(gaps):.2f} s")
	assert min(gaps) >= MIN_HIT_GAP, f"two hit events {min(gaps)} s apart"
	assert {r[0] for r in CYCLE} == set(moves), "a move missing from the cycle"
	for i, row in enumerate(CYCLE):
		if row[0].endswith("_in"):
			assert CYCLE[i + 1][0] == row[0][:-3], "a lead not right before its move"
		elif row[0] != "idle":
			assert CYCLE[i - 1][0] == row[0] + "_in", "an attack not led into"


def check_bind(mage, bind):
	"""The joint chain the client builds reproduces the approved key poses of boss_mage_keyframes.solve exactly."""
	for name, move in mk.MOVES.items():
		for key, approved in zip(move["keys"], mage.data["moves"][name]["keys"]):
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
	grips = {tuple(round(v, 3) + 0 for v in k["staff_grip_offset"]) for m in data["moves"].values() for k in m["keys"]}
	assert len(grips) == 1, grips
	for m in data["moves"].values():
		for k in m["keys"]:
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

local golemKeys = MOVES.golem.Golem
for _, key in golemKeys do
	for part, v in key.Parts do
		key.Parts[part] = Vector3.new(v[1], v[2], v[3])
	end
	for part, v in key.Locs do
		key.Locs[part] = Vector3.new(v[1], v[2], v[3])
	end
	key.Root = Vector3.new(key.Root[1], key.Root[2], key.Root[3])
end

-- The golem at golem-move time t, clamped: scale (0 = absent: hide it; else each block's size times it, about its own centre),
-- parts[part] (XYZ Euler degrees) and locs[part] (golem units from its parent's joint) for joint = CFrame.new(loc) * rotation, and
-- the root offset in golem units. Outside the golem move there is no golem.
function Poses.SampleGolem(t)
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
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}}," % (fmt(f[0], 4), vec([v * root_studs for v in f[2]], 4), body))
		lines.append("\t\t},")
		if name == "golem":
			lines.append("\t\tGolem = {")
			for t, c in golem["frames"]:
				places = 3 if t in golem["pinned"] else 1
				rot = ",".join("%s=%s" % (p, vec([c["%s:r%d" % (p, i)] for i in range(3)], places)) for p in sorted(golem["bind"]))
				loc = ",".join("%s=%s" % (p, vec([c["%s:l%d" % (p, i)] for i in range(3)], 3)) for p in sorted(golem["bind"]))
				lines.append("\t\t\t{Time=%s,Scale=%s,Root={0,0,%s},Parts={%s},Locs={%s}}," % (fmt(t, 4), fmt(c["scale"], 3), fmt(c["root"], 3), rot, loc))
			lines.append("\t\t},")
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name, m in mage.data["moves"].items():
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
	print(f"BAKE wrote {LUAU}: {len(text)} bytes, {sum(len(m[0]) for m in moves.values())} keys, golem {len(golem['frames'])} keys")


def check_verbatim(mage, moves):
	"""Every approved key of keys.json sits in its move's baked keys unchanged, at its time."""
	for name, m in mage.data["moves"].items():
		frames = {f[0]: f for f in moves[name][0]}
		assert moves[name][1] == [k["t"] for k in m["keys"]], name
		for k in m["keys"]:
			f = frames[k["t"]]
			assert all(list(f[1][p]) == k["rotations"][p] for p in mage.parts) and list(f[2]) == k["root_offset"], f"{name} {k['t']} not verbatim"
		if name in EVENTS:
			assert [e["Name"] for e in moves[name][2]] == [EVENTS[name]], name


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	wanted = [a for a in argv if a in ("poses", "glb")] or ["poses", "glb"]
	with open(KEYS) as f:
		data = json.load(f)
	mage = Mage(data)
	height = SIZE * mk.CHAR_H
	scale = height / data["scale"]["model_height_units"]
	root_studs = data["scale"]["studs_per_model_unit_at_4x"]
	assert abs(root_studs - 4 * mk.CHAR_H / data["scale"]["model_height_units"]) < 1e-3

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_mage"])
	bind, objs = mage_bind(data, scale)
	check_bind(mage, bind)
	if "glb" in wanted:
		for p, o in objs.items():
			o.name = o.data.name = p
		raga.write_glb(objs, GLB["boss_mage"])

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_golem"])
	gbind, gobjs, gverts, golem_h, golem_low, golem_scale = golem_bind(lambda h: mk.GOLEM_RATIO * height / h)
	g_frames, g_times = golem_track(data, gbind, gverts)
	if "glb" in wanted:
		raga.write_glb(gobjs, GLB["boss_golem"])

	if "poses" in wanted:
		gkeys = data["moves"]["golem"]["keys"]
		slam = next(k["t"] for k in gkeys if k.get("event") == "Slam")
		slam_from = next(k["hold_until"] for k in gkeys if "hold_until" in k)
		moves = {"idle": mage.idle()}
		for name in PLAN:
			moves[name] = mage.attack(name)
			moves[name + "_in"] = mage.lead(name)
		for name, (frames, approved, events, duration, keep) in list(moves.items()):
			thinned = raga.thin(frames, mage.parts, keep)
			snaps = [(slam_from, slam + SNAP)] if name == "golem" else []  # the slam, from the end of the held wind-up to the hit
			check(name, thinned, mage.parts, [e["Time"] for e in events], duration, snaps)
			moves[name] = (thinned, approved, events, duration, keep)
		check_verbatim(mage, moves)
		check_cycle(moves)
		gparts = sorted(gbind)
		check("golem track", golem_rotations(g_frames, gparts), gparts, [slam], data["moves"]["golem"]["end"], [(slam_from, slam + SNAP)], root=False)
		g_pinned = set(g_times)
		gk = dict(g_frames)
		for k in data["moves"]["golem"]["keys"]:
			if k.get("golem"):
				c = gk[k["t"]]
				for p in gparts:
					assert [c["%s:r%d" % (p, i)] for i in range(3)] == k["golem"][p]["rot"], (k["t"], p)
					assert [c["%s:l%d" % (p, i)] for i in range(3)] == k["golem"][p]["loc"], (k["t"], p)
				assert c["scale"] == 1 and c["root"] == k.get("golem_root_z", 0), k["t"]
		assert gk[0]["scale"] == 0 and gk[data["moves"]["golem"]["end"]]["scale"] == 0, "the golem shows outside its move"
		assert all(len([c for c in f if c.endswith(":r0")]) == 15 for _, f in g_frames), "a golem block without keys"
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
		}
		print(f"BAKE scale {scale:.4f} studs/unit, golem {golem_h:.3f} units x {golem_scale:.4f} = {golem_h * golem_scale:.1f} studs, anchor {anchor}")
		write_luau(mage, bind, moves, {"bind": gbind, "frames": g_frames, "pinned": g_pinned}, consts)
		print("BAKE self-check passed")


if __name__ == "__main__":
	main()
