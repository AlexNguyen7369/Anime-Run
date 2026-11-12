# The Elf Mage's in-betweens on her jointed rig, her golem's tracks and both game models (design doc 4.37 "Second boss" and
# "Animation rework", BOSS_EVENT_SPEC "The Elf Mage" and "Animation rework").
#   Blender -b --factory-startup --python tools/blender/build_boss_mage.py -- jointed   (boss_mage_jointed.blend, git-ignored)
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- build boss_golem   (boss_golem.blend, git-ignored)
#   Blender -b --factory-startup --python tools/blender/bake_boss_mage.py -- [poses] [glb]
# poses   writes src/late/BossMagePoses.luau from the 10 rework keys per move of keyframes/rework/keys.json (owner pre-approved
#         2026-11-12): her idle, watch, lightning, barrage and golem, the golem's golem_idle, golem_slam, golem_sweep and golem_fall,
#         and its part of golem. Keys verbatim at their times; everything between them generated here: quaternion interpolation per
#         part with asymmetric easing, written as Euler keys (each in-between the Euler nearest the frame before it); springs on the
#         tails, the staff, the lower arms and the head (her) and the head and forearms (golem); torso and head 1 and 2 frames
#         behind; Big Raga's RECOIL after each hit; the golem's lowest block kept on the floor between grounded keys (its foot
#         solve: the root, not the knees). Then self-checked (asserts, the boss_mage_anim continuity check with its hit snap
#         included). Run stylua after.
# glb     writes build/avatar_glb/boss_mage_jointed.glb (17 parts) and boss_golem.glb (15 blocks): unposed, no hierarchy, each centred
#         on its box (bake_boss_raga.write_glb). Upload the first as boss_mage_jointed (upload_avatar.py, sidekick_art.py):
#         SidekickArt.boss_mage_jointed.BossModel. Nothing here uploads.
# Body (her hip turn) is no part: it is folded into Torso's and the thighs' rotations, and the hips it carries round go out as Keys'
# Locs (model units). bake_boss_king.py imports secondary, local_verts, bind_lines, RATE, LEAD_PLAN and MIN_HIT_GAP from here.
import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_boss_raga as raga  # noqa: E402  (guarded main: easing, thinning, sampling, RECOIL, number format, GLB export)
import boss_mage_keyframes as mk  # noqa: E402  (guarded main: the key pose solvers and the stage constants)

ease, eout, ein = raga.inout, raga.eout, raga.ein


def lin(u):
	return u


ROOT = os.path.dirname(os.path.dirname(HERE))
REWORK = os.path.join(ROOT, "assets", "characters_avatar", "boss_mage", "keyframes", "rework", "keys.json")
BLEND = {
	"boss_mage": os.path.join(ROOT, "assets", "characters_avatar", "boss_mage", "boss_mage_jointed.blend"),
	"boss_golem": os.path.join(ROOT, "assets", "characters_avatar", "boss_golem", "boss_golem.blend"),
}
GLB = {"boss_mage": os.path.join(ROOT, "build", "avatar_glb", "boss_mage_jointed.glb"), "boss_golem": os.path.join(ROOT, "build", "avatar_glb", "boss_golem.glb")}
LUAU = os.path.join(ROOT, "src", "late", "BossMagePoses.luau")
# The golem's feet in game, studs in her frame (Blender axes). Not keys.json's GOLEM_SPOT x the size: at 8x that put it on lanes
# 1-2 (83 studs out), where runners passed through it. 42 out keeps its ~27-stud half width inside the kerb (70) and clear of
# her ~12-stud half width (proposed, Studio verify 2026-11-11).
GAME_GOLEM_SPOT = (-40.0, 12.0)

SIZE = 8  # her height in runner heights (owner 2026-11-11)
RATE = 120  # samples a second before thinning
LIMIT_DEGREES, LIMIT_OFFSET, SNAP = 12, 0.05, 0.05  # boss_mage_anim "continuous": per 60 Hz frame, the hit snap's tail
MIN_HIT_GAP = 3.95  # s between two hit events at least: the Dodge bar needs it (spec "Dodge bar")
# Fixed (spec "Animation rework": lead-in lengths do not change): the lead from the hover into each attack's first key, seconds.
LEAD = {"lightning": 0.75, "golem": 0.75, "barrage": 0.45}
# Fixed order. Rows as BossRagaPoses: { "idle", from, seconds } or { move }. A "<move>_in" lead runs just before its move.
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
CYCLE_SECONDS, SLOT_AT = 32.55, 27.55  # fixed
GOLEM_EVERY = 6  # fixed: s between two golem hits on its own clock (BossMinionStart)
OSU_OPEN = 4.2  # BossOsu.OpenSeconds: a hit's circles open this long before it
WATCH_LEAD = 0.75  # fixed: watch_in, idle key 0 -> watch key 0
GOLEM_SINK = 0.2  # golem units below the floor past its highest block, before it rises
# The rework's key times (fixed: owner 2026-11-12) and their events.
KEY_TIMES = {
	"lightning": [0, 0.45, 0.95, 1.4, 1.8, 2.0, 2.6, 3.35, 4.0, 5.2],
	"idle": [0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 2.7],
	"watch": [0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 2.7],
	"barrage": [0, 0.5, 1.0, 1.45, 1.85, 2.0, 2.6, 3.35, 4.0, 5.4],
	"golem": [0, 0.4, 0.8, 1.3, 1.9, 2.5, 3.0, 3.6, 4.2, 5.0],
	"golem_idle": [0, 0.24, 0.48, 0.72, 0.96, 1.2, 1.44, 1.68, 1.92, 2.16],
	"golem_slam": [0, 0.4, 0.9, 1.5, 2.25, 2.6, 2.8, 3.0, 3.3, 3.6],
	"golem_sweep": [0, 0.4, 1.0, 1.6, 2.2, 2.6, 2.85, 3.2, 3.7, 4.2],
	"golem_fall": [0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.45, 1.7, 2.0],
}
ENDS = {"lightning": 5.2, "idle": 3.0, "watch": 3.0, "barrage": 5.4, "golem": 5.0, "golem_idle": 2.4, "golem_slam": 3.6, "golem_sweep": 4.2, "golem_fall": 2.0}
EVENTS = {"lightning": ("Lightning", 2.0), "barrage": ("Barrage", 2.0), "golem": ("Slam", 4.2), "golem_slam": ("Slam", 2.8), "golem_sweep": ("Sweep", 2.6)}
WINDOW = {"lightning": (2.0, 4.0), "barrage": (2.0, 4.0)}  # fixed: the strike windows; the cost event is the window's start
HERS = ("idle", "watch", "lightning", "barrage", "golem")
# One row per segment between keys. ease, hold (s stopped at its start), carry (overshoot past its first key, a share of the segment
# before), anticipate (a pull the wrong way first, a share of it). Proposed. Root moves cap the ease's peak speed (0.05 units a frame).
PLAN = {
	"lightning": (
		{"ease": ease(1.6)},  # 0 -> 0.45 anticipation: the coil
		{"ease": eout(1.5)},  # 0.45 -> 0.95 cast raise, fast off the coil, slowing into the overshoot
		{"ease": ease(1.8), "carry": 0.06},  # 0.95 -> 1.4 settles, the raise carried a little past
		{"ease": ease(1.8)},  # 1.4 -> 1.8 the brace (Dodge bar ends)
		{"ease": ein(2.4)},  # 1.8 -> 2.0 fast into the first strike (the hit snap)
		{"ease": eout(1.5), "hold": 0.05},  # 2.0 -> 2.6 hard stop on the strike, then the storm drives
		{"ease": ease(1.6)},  # 2.6 -> 3.35
		{"ease": ease(1.6)},  # 3.35 -> 4.0 the release
		{"ease": ease(2.0), "carry": 0.05},  # 4.0 -> 5.2 slow recovery into idle key 0
	),
	"barrage": (
		{"ease": ease(1.6)},  # 0 -> 0.5 anticipation
		{"ease": eout(1.5)},  # 0.5 -> 1.0 the swing through, slowing into the overshoot
		{"ease": ease(1.8), "carry": 0.06},  # 1.0 -> 1.45 settle, circles opening
		{"ease": ease(1.8)},  # 1.45 -> 1.85 brace
		{"ease": ein(2.4)},  # 1.85 -> 2.0 into the first strike (the hit snap)
		{"ease": eout(1.5), "hold": 0.05},  # 2.0 -> 2.6 kicked back, then she drives the staff across
		{"ease": ease(1.6)},  # 2.6 -> 3.35
		{"ease": ease(1.6)},  # 3.35 -> 4.0 the release
		{"ease": ease(2.0), "carry": 0.05},  # 4.0 -> 5.4 slow recovery
	),
	"golem": (
		{"ease": ease(1.6)},  # 0 -> 0.4 anticipation, staff raised
		{"ease": ein(1.8)},  # 0.4 -> 0.8 driven down at the floor
		{"ease": eout(1.6), "hold": 0.04},  # 0.8 -> 1.3 stuck on the rune, then settles
		{"ease": ease(1.6)},  # 1.3 -> 1.9 the lift
		{"ease": ease(1.6)},  # 1.9 -> 2.5 hands high
		{"ease": ease(1.6)},  # 2.5 -> 3.0 points at it
		{"ease": ease(1.8)},  # 3.0 -> 3.6 command
		{"ease": ein(2.2)},  # 3.6 -> 4.2 cut down into the slam (the hit snap)
		{"ease": eout(1.5), "hold": 0.05},  # 4.2 -> 5.0 hard stop, then back to idle key 0
	),
}
LOOP_PLAN = {"ease": lin}  # idle and watch: 10 keys sampled from a smooth loop, so no stop on every key
LEAD_PLAN = ({"ease": ease(1.5), "anticipate": 0.12},)
LAG = {"Torso": 1 / 60, "Head": 2 / 60}  # s behind the limbs mid-segment, back on time at every key
# Springs (channel, drivers {channel: weight}, gain, omega, zeta), under-damped. Channels: "<part>:<axis>" the part's own turn in
# degrees (its rotation vector summed frame to frame, so no Euler wrap), "rootx/y/z" model units. Proposed.
TAILS = tuple(
	row
	for s, t in ((1, "TailL"), (-1, "TailR"))
	for row in (
		(t + "1:0", {"Head:0": 1, "Torso:0": 1, "rootz": -40}, 0.6, 8, 0.3),
		(t + "1:2", {"Head:2": 1, "Torso:2": 1, "Body:2": 1}, 0.5, 8, 0.3),
		(t + "2:0", {t + "1:0": 1}, 0.4, 9, 0.3),
		(t + "3:0", {t + "2:0": 1}, 0.4, 10, 0.3),
	)
)
HEAD = (("Head:0", {"Torso:0": 1}, 0.45, 13, 0.34), ("Head:2", {"Torso:2": 1, "Body:2": 1}, 0.4, 12, 0.34))
ARMS = (
	("LeftLowerArm:0", {"LeftUpperArm:0": 1}, 0.3, 11, 0.32),
	("RightLowerArm:0", {"RightUpperArm:0": 1}, 0.2, 13, 0.36),
)
STAFF = (("Staff:0", {"RightUpperArm:0": 1, "RightLowerArm:0": 1}, 0.25, 12, 0.35), ("Staff:2", {"RightUpperArm:2": 1}, 0.2, 12, 0.35))
# The lower arms and the staff spring only where she casts one-handed: in a two-handed hold (idle, watch, the leads, barrage) a spring
# would pull the left fist off the shaft.
FOLLOW = {"lightning": TAILS + HEAD + ARMS + STAFF, "golem": TAILS + HEAD + ARMS + STAFF}
GOLEM_FOLLOW = (
	("Head:0", {"Torso:0": 1}, 0.4, 12, 0.34),
	("ForearmL:0", {"UpperArmL:0": 1}, 0.3, 11, 0.32),
	("ForearmR:0", {"UpperArmR:0": 1}, 0.3, 11, 0.32),
)
_RAGA = {"UpperTorso": ("Torso",), "Head": ("Head",), "Tail": ("TailL1", "TailR1")}
RECOIL = tuple((q, axis, deg, hz) for p, axis, deg, hz in raga.RECOIL if p in _RAGA for q in _RAGA[p])
GOLEM_RECOIL = tuple(r for r in RECOIL if r[0] in ("Torso", "Head"))
PARTS = ("Torso", "Head", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "TailL1", "TailL2", "TailL3", "TailR1", "TailR2", "TailR3", "Staff")
FOLDED = ("Torso", "LeftUpperLeg", "RightUpperLeg")  # Body folds into these
THIGHS = ("LeftUpperLeg", "RightUpperLeg")
LOCS = THIGHS  # joints that move on their parent: the hips round Body's turn
MESH = {p: (p if p == "Staff" or p.startswith("Tail") else p + "_merged") for p in PARTS}
# shortcut: the 6-part model uploaded 2026-11-11 (SidekickArt.boss_mage.BossModel) keeps its old bind, copied from BossMagePoses before
# the rework and keyed by the jointed upper segment each old part stands in for (Mesh: its name in the upload). Server
# CharacterModelService loads it on this bind and Client/BossMage poses it from the jointed data until boss_mage_jointed.glb is
# uploaded. Delete with that upload.
BIND6 = """\
	Head = { Parent = "Torso", Offset = {0,0,2.5}, Center = {0,0,0.5}, Size = {25.03,17.58,15.06} },
	LeftUpperArm = { Mesh = "LeftArm", Parent = "Torso", Offset = {1.5,0,1.8}, Center = {-0.1,0,-0.8}, Size = {12.66,17.16,12.37} },
	LeftUpperLeg = { Mesh = "LeftLeg", Parent = nil, Offset = {0.5,0,2}, Center = {0,0,-1}, Size = {8.3,14.09,11.25} },
	RightUpperArm = { Mesh = "RightArm", Parent = "Torso", Offset = {-1.5,0,1.8}, Center = {0.1,0,-0.8}, Size = {12.66,17.16,12.37} },
	RightUpperLeg = { Mesh = "RightLeg", Parent = nil, Offset = {-0.5,0,2}, Center = {0,0,-1}, Size = {8.3,14.18,11.25} },
	Staff = { Parent = "RightUpperArm", Offset = {0,0,-1.75}, Center = {0.1423,0,1.0078}, Size = {6.66,45.11,1.69}, Tip = {0.068,-0.005,3.678} },
	TailL1 = { Mesh = "TailL", Parent = "Head", Offset = {0.86,0.36,1.36}, Center = {0.9307,0.2608,-2.0346}, Size = {17.71,31.29,6.46} },
	TailR1 = { Mesh = "TailR", Parent = "Head", Offset = {-0.86,0.36,1.36}, Center = {-0.9307,0.2608,-2.0346}, Size = {17.71,31.29,6.46} },
	Torso = { Parent = nil, Offset = {0,0,2}, Center = {0,0,1}, Size = {19.83,21.51,12.3} },"""


# ---- quaternions ----


def quat(d):
	return Euler([math.radians(v) for v in d]).to_quaternion()


def delta(a, b):
	"""The shortest turn from a to b, in a's frame."""
	d = (a.inverted() @ b).normalized()
	return d if d.w >= 0 else Quaternion((-d.w, -d.x, -d.y, -d.z))


def power(q, s):
	axis, angle = q.to_axis_angle()
	return Quaternion(axis, angle * s)


def turn(degrees):
	"""A small rotation vector (degrees, the part's own axes) as a quaternion."""
	v = Vector(degrees)
	return Quaternion(v.normalized(), math.radians(v.length)) if v.length > 1e-9 else Quaternion()


def matrix64(v):
	"""XYZ Euler degrees as the client poses them (Z, then Y, then X), in doubles: mathutils is float32."""
	x, y, z = (math.radians(a) for a in v)
	rx = np.array(((1, 0, 0), (0, math.cos(x), -math.sin(x)), (0, math.sin(x), math.cos(x))))
	ry = np.array(((math.cos(y), 0, math.sin(y)), (0, 1, 0), (-math.sin(y), 0, math.cos(y))))
	rz = np.array(((math.cos(z), -math.sin(z), 0), (math.sin(z), math.cos(z), 0), (0, 0, 1)))
	return rz @ ry @ rx


def apart(a, b):
	"""Degrees between two XYZ Euler rotations (degrees), as boss_mage_anim's rotationApart."""
	return math.degrees(2 * math.asin(min(1.0, np.linalg.norm(matrix64(a) - matrix64(b)) / (2 * math.sqrt(2)))))


def euler_near(q, prev):
	"""q as XYZ Euler degrees, the branch nearest prev (degrees) when given."""
	e = q.to_euler("XYZ", Euler([math.radians(v) for v in prev])) if prev is not None else q.to_euler("XYZ")
	return [math.degrees(v) for v in e]


def keep_key(numbers, curve, prev, verbatim, where):
	"""A key's own numbers, moved by whole turns to sit next to the curve; on the other Euler branch, the curve's numbers (the same
	rotation, asserted). verbatim counts both."""
	v = list(numbers)
	if prev is not None:
		v = [a + 360 * round((b - a) / 360) for a, b in zip(v, curve)]
		verbatim["shifted"] += sum(a != b for a, b in zip(v, numbers))
	if prev is None or max(abs(a - b) for a, b in zip(v, curve)) < 1.0:
		e = v
	else:
		e = [round(x, 3) + 0 for x in curve]
		verbatim["rewritten"].append(where)
	assert apart(e, numbers) < 1e-3, f"{where}: off its key"
	return e


# ---- interpolation ----


def track(stops, segments, lag=None):
	"""The pose at t through every stop: slerp per part on the segment's easing (hold, carry and anticipate as above), Torso and
	Head on a lagged clock that is back on time at both ends of the segment; every "vec" value (Vectors, numbers) lerped."""
	lag = LAG if lag is None else lag
	times = [s["t"] for s in stops]
	assert len(segments) == len(stops) - 1
	for t0, t1 in zip(times, times[1:]):
		assert max(lag.values(), default=0) * math.pi / (t1 - t0) < 1, "a lag that would run the clock backwards"

	def weights(i, t):
		seg = segments[i]
		hold = seg.get("hold", 0)
		t0, t1 = times[i], times[i + 1]
		u = min(max((t - t0 - hold) / (t1 - t0 - hold), 0.0), 1.0)
		s, b = seg["ease"](u), raga.bump(u)
		return s - seg.get("anticipate", 0) * b, (seg.get("carry", 0) * b if i > 0 else 0.0)

	def at(t):
		i = int(max(0, min(len(times) - 2, np.searchsorted(times, t, side="right") - 1)))
		a, b = stops[i], stops[i + 1]
		frac = min(max((t - times[i]) / (times[i + 1] - times[i]), 0.0), 1.0)
		rot = {}
		for p in a["rot"]:
			s, c = weights(i, t - lag.get(p, 0) * math.sin(math.pi * frac))
			q = a["rot"][p] @ power(delta(a["rot"][p], b["rot"][p]), s)
			if c:
				q = q @ power(delta(stops[i - 1]["rot"][p], a["rot"][p]), c)
			rot[p] = q
		s, c = weights(i, t)
		vec = {}
		for k, v in a["vec"].items():
			v = v + (b["vec"][k] - v) * s
			if c:
				v = v + (a["vec"][k] - stops[i - 1]["vec"][k]) * c
			vec[k] = v
		return {"rot": rot, "vec": vec}

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
	for channel, curve in out.items():
		out[channel] = pinned(grid, curve, knots)
	return out


def pinned(grid, curve, knots):
	"""curve less a smooth curve through its values at the knots: 0 at every knot."""
	knots = np.array(sorted(set(knots)))
	i = np.clip(np.searchsorted(knots, grid, side="right") - 1, 0, len(knots) - 2)
	u = (grid - knots[i]) / (knots[i + 1] - knots[i])
	at = np.interp(knots, grid, curve)
	return curve - (at[i] + (at[i + 1] - at[i]) * u * u * (3 - 2 * u))


def sample(name, stops, segments, duration, follow, recoil, hit, lag=None):
	"""The track at RATE, springs and recoil added (each back to 0 at every stop). Returns the grid and the sampled states."""
	at = track(stops, segments, lag)
	knots = [s["t"] for s in stops]
	rate = next(r for r in (RATE, 150, 200, 300, 600) if all(abs(k * r - round(k * r)) < 1e-6 for k in knots))  # golem_idle's 0.24 s
	grid = np.linspace(0, duration, int(round(duration * rate)) + 1)
	for k in knots:  # stop times exactly on the grid
		i = int(np.argmin(np.abs(grid - k)))
		assert abs(grid[i] - k) < 1e-6, f"{name} {k}: not on the sample grid"
		grid[i] = k
	samples = [at(float(t)) for t in grid]
	turned = {p: np.zeros(3) for p in samples[0]["rot"]}
	channels = []
	for i, s in enumerate(samples):
		if i:
			for p, q in s["rot"].items():
				axis, angle = delta(samples[i - 1]["rot"][p], q).to_axis_angle()
				turned[p] = turned[p] + np.array(axis) * math.degrees(angle)
		c = {"%s:%d" % (p, j): float(v[j]) for p, v in turned.items() for j in range(3)}
		root = s["vec"]["root"]
		c.update({"root" + "xyz"[j]: float(root[j]) for j in range(3)} if isinstance(root, Vector) else {"rootz": float(root)})
		channels.append(c)
	sec = secondary(grid, channels, follow, [], knots, name)
	if hit is not None:
		for p, axis, degrees, hz in recoil:
			tau = np.maximum(grid - hit, 0)
			ch = "%s:%d" % (p, axis)
			sec[ch] = sec.get(ch, 0) + pinned(grid, degrees * np.exp(-6 * tau) * np.sin(2 * math.pi * hz * tau), knots)
	for i, s in enumerate(samples):
		for p in s["rot"]:
			v = [float(sec["%s:%d" % (p, j)][i]) if "%s:%d" % (p, j) in sec else 0.0 for j in range(3)]
			s["rot"][p] = s["rot"][p] @ turn(v)
	return grid, samples


# ---- her ----


def state(key, t=None):
	"""A key of hers as plain state: rot (local quaternion per part and Body), euler (the key's own numbers, verbatim), root."""
	euler = {p: [float(v) for v in key["rotations"][p]] for p in ("Body",) + PARTS}
	return {
		"t": float(key["t"] if t is None else t),
		"euler": euler,
		"rot": {p: quat(v) for p, v in euler.items()},
		"vec": {"root": Vector(key["root_offset"])},
		"root_offset": tuple(float(v) for v in key["root_offset"]),  # verbatim (Vector is float32)
	}


def joints(bind, body, root):
	"""The client's chain (BossRaga:Pose): joint = parent * CFrame(offset or loc) * rotation; the root adds to parentless parts."""
	out = {}

	def m(n):
		if n not in out:
			b = bind[n]
			base = m(b["Parent"]) if b["Parent"] else Matrix.Translation(root)
			offset = Vector(b["Offset"]) + Vector(body[n + "@"]) / 100 if n in LOCS else Vector(b["Offset"])
			out[n] = base @ Matrix.Translation(offset) @ Euler([math.radians(v) for v in body[n]]).to_matrix().to_4x4()
		return out[n]

	for n in bind:
		m(n)
	return out


class Mage:
	def __init__(self, data, bind):
		self.data, self.bind = data, bind
		self.pivots = {p: Vector(v) for p, v in data["pivots"].items()}
		self.idle0 = state(data["moves"]["idle"]["keys"][0])
		self.watch0 = state(data["moves"]["watch"]["keys"][0])
		self.verbatim = {"shifted": 0, "rewritten": []}

	def pose(self, st):
		"""Body folded in: quaternion per part, the hips' joints (model units, parentless)."""
		rb = st["rot"]["Body"]
		rot = {p: st["rot"][p] for p in PARTS}
		for p in FOLDED:
			rot[p] = rb @ st["rot"][p]
		hip = Vector(mk.HIP)
		return rot, {p: hip + rb @ (self.pivots[p] - hip) for p in THIGHS}

	def frame(self, t, st, prev, key=None):
		"""(t, body, root): body has XYZ Euler degrees per part, each the Euler nearest prev's, and "<loc>@" the hips off the bind
		(units x 100, for thinning). A key's own parts keep its numbers (moved by whole turns to sit next to prev)."""
		rot, locs = self.pose(st)
		body = {}
		for p in PARTS:
			e = euler_near(rot[p], prev[p] if prev else None)
			if key is not None:
				if p in FOLDED:
					e = [round(v, 3) + 0 for v in e]
				else:
					e = keep_key(key["euler"][p], e, prev, self.verbatim, (key["t"], p))
			body[p] = tuple(e)
		for p in LOCS:
			body[p + "@"] = tuple((a - b) * 100 for a, b in zip(locs[p], self.bind[p]["Offset"]))
		return (float(t), body, key["root_offset"] if key is not None else tuple(st["vec"]["root"]))

	def bake(self, name, stops, segments, duration, pinned_t, hit=None):
		grid, samples = sample(name, stops, segments, duration, FOLLOW.get(name, TAILS + HEAD), RECOIL, hit)
		keys = {s["t"]: s for s in stops if s["t"] in pinned_t}
		frames, prev = [], None
		for i, t in enumerate(grid):
			f = self.frame(t, samples[i], prev, keys.get(float(t)))
			frames.append(f)
			prev = f[1]
		return frames

	def attack(self, name):
		move = self.data["moves"][name]
		stops = [state(k) for k in move["keys"]]
		assert stops[0]["t"] == 0 and stops[-1]["t"] == move["end"], name
		knots = [s["t"] for s in stops]
		event, at = EVENTS[name]
		assert [k["t"] for k in move["keys"] if k.get("event") == event] == [at], name
		frames = self.bake(name, stops, PLAN[name], move["end"], knots, at)
		events = [{"Time": at, "Name": event}]
		keep = knots + [t + seg.get("hold", 0) for t, seg in zip(knots, PLAN[name])]
		return frames, knots, events, move["end"], keep

	def loop(self, name):
		"""idle or watch: through its 10 keys and back to key 0 at the period's end, so it loops without a pop."""
		move = self.data["moves"][name]
		keys, period = move["keys"], move["end"]
		assert move["loop"] and keys[0]["t"] == 0
		stops = [state(k) for k in keys] + [state(keys[0], period)]
		knots = [s["t"] for s in stops]
		frames = self.bake(name, stops, (LOOP_PLAN,) * len(keys), period, knots)
		a, b = frames[0], frames[-1]
		bad = [p for p in a[1] if max(abs(x - y) for x, y in zip(a[1][p], b[1][p])) > 1e-3]
		assert not bad and a[2] == b[2], f"{name}: the loop's end is not its first key {bad}"
		frames[-1] = (float(period),) + frames[0][1:]
		return frames, [k["t"] for k in keys], [], period, knots

	def lead(self, name, a, b, length, approved=(), plan=LEAD_PLAN):
		"""From state a to state b over length s (a <move>_in lead, watch_in, her part of golem_fall)."""
		stops = [dict(a, t=0.0), dict(b, t=float(length))]
		frames = self.bake(name, stops, plan, length, [0.0, float(length)])
		return frames, list(approved), [], length, [0, length]


# ---- the golem ----


def golem_world(gbind, rot, loc, root_z=0.0):
	"""Every block's matrix in golem units, from the golem's root (its feet on the floor at rest). rot: quaternions or Eulers (deg)."""
	out = {}

	def m(n):
		if n not in out:
			b = gbind[n]
			parent = m(b["Parent"]) if b["Parent"] else Matrix.Translation((0, 0, root_z))
			r = rot[n] if isinstance(rot[n], Quaternion) else Euler([math.radians(v) for v in rot[n]])
			out[n] = parent @ Matrix.Translation(loc[n]) @ r.to_matrix().to_4x4()
		return out[n]

	for n in gbind:
		m(n)
	return out


def golem_span(gbind, verts, rot, loc, root_z=0.0):
	"""The lowest and highest point of its blocks, golem units."""
	world = golem_world(gbind, rot, loc, root_z)
	zs = [(np.array(world[n])[:3, :3] @ verts[n].T).T[:, 2] + np.array(world[n])[2, 3] for n in gbind]
	return float(min(z.min() for z in zs)), float(max(z.max() for z in zs))


def gstate(gbind, k, t=None, scale=1.0, root=None):
	"""A golem key as plain state: rot per block, euler (its own numbers), vec: each block's loc ("<block>@"), root, scale."""
	g = k["golem"]
	euler = {p: [float(v) for v in g[p]["rot"]] for p in gbind}
	vec = {p + "@": Vector(g[p]["loc"]) for p in gbind}
	vec.update({"root": float(k.get("golem_root_z", 0) if root is None else root), "scale": float(scale)})
	return {"t": float(k["t"] if t is None else t), "euler": euler, "rot": {p: quat(v) for p, v in euler.items()}, "vec": vec, "loc": {p: list(map(float, g[p]["loc"])) for p in gbind}}


class Golem:
	def __init__(self, data, gbind, verts):
		self.data, self.gbind, self.verts = data, gbind, verts
		self.verbatim = {"shifted": 0, "rewritten": []}
		# its lowest point standing on the floor, golem units from its root: golem_idle key 0's (the key tool grounds the mesh it
		# renders, a little below these blocks' lowest vertex)
		self.floor = self.span(gstate(gbind, data["moves"]["golem_idle"]["keys"][0]))[0]

	def span(self, st, root=None):
		loc = {p: st["vec"][p + "@"] for p in self.gbind}
		return golem_span(self.gbind, self.verts, st["rot"], loc, st["vec"]["root"] if root is None else root)

	def grounded(self, st):
		"""Whole (every block at its bind offset: not rising, breaking or crumbled), full size, its lowest point on the floor."""
		whole = all(max(abs(a - b) for a, b in zip(st["vec"][p + "@"], self.gbind[p]["Offset"])) < 1e-3 for p in self.gbind)
		return whole and st["vec"]["scale"] == 1 and abs(self.span(st)[0] - self.floor) < 3e-3

	def bake(self, name, stops, segments, duration, hit=None, lag=None):
		"""Sampled, springs and recoil added; between two grounded stops the root keeps its lowest block on the floor (pinned back to
		the keys' own roots at every stop); written as channel frames, every stop verbatim."""
		grid, samples = sample(name, stops, segments, duration, GOLEM_FOLLOW, GOLEM_RECOIL, hit, lag)
		times = [s["t"] for s in stops]
		ground = [self.grounded(s) for s in stops]
		lift = np.zeros(len(grid))
		for i, (t, s) in enumerate(zip(grid, samples)):
			j = int(max(0, min(len(times) - 2, np.searchsorted(times, t, side="right") - 1)))
			if ground[j] and ground[j + 1]:
				lift[i] = self.floor - self.span(s)[0]
		lift = pinned(grid, lift, times)
		stop_at = {s["t"]: s for s in stops}
		frames, prev = [], None
		for i, t in enumerate(grid):
			s, key = samples[i], stop_at.get(float(t))
			c = {}
			for p in sorted(self.gbind):
				e = euler_near(s["rot"][p], prev and [prev["%s:r%d" % (p, j)] for j in range(3)])
				if key is not None:
					e = keep_key(key["euler"][p], e, prev, self.verbatim, (name, key["t"], p))
				loc = key["loc"][p] if key is not None else s["vec"][p + "@"]
				for j in range(3):
					c["%s:r%d" % (p, j)] = float(e[j])
					c["%s:l%d" % (p, j)] = float(loc[j])
			c["root"] = key["vec"]["root"] if key is not None else float(s["vec"]["root"] + lift[i])
			c["scale"] = key["vec"]["scale"] if key is not None else float(min(max(s["vec"]["scale"], 0.0), 1.0))
			frames.append(c)
			prev = c
		holds = [t + seg.get("hold", 0) for t, seg in zip(times, segments)]
		print(f"BAKE golem {name}: grounded stops {[t for t, g in zip(times, ground) if g]}, lowest {[round(self.span(s)[0], 3) for s in stops]}")
		return thin_golem(self.gbind, grid, frames, sorted(set(times + holds)))

	def tracks(self):
		"""Every golem track: name -> {frames, approved, events, duration, stops}. golem and golem_fall play beside her moves of those
		names; golem_idle, golem_slam and golem_sweep are GolemMoves, on the golem's own clock."""
		moves, out = self.data["moves"], {}
		for name in ("golem_slam", "golem_sweep", "golem_idle", "golem_fall"):
			move = moves[name]
			keys = move["keys"]
			stops = [gstate(self.gbind, k) for k in keys]
			if name == "golem_idle":
				stops.append(gstate(self.gbind, keys[0], t=move["end"]))
			if name == "golem_fall":  # its rubble heap shrinks away over the last segment: scale 0 at its end, the pose as keyed
				stops[-1] = gstate(self.gbind, keys[-1], scale=0.0)
			event = EVENTS.get(name)
			out[name] = {
				# golem_fall: no torso and head lag, it is a collapse (a lagged head turned past 12 degrees a frame as the blocks fell)
				"frames": self.bake(name, stops, GOLEM_PLAN[name], move["end"], event and event[1], {} if name == "golem_fall" else None),
				"approved": [k["t"] for k in keys],
				"events": [{"Time": event[1], "Name": event[0]}] if event else [],
				"duration": move["end"],
				"stops": [s["t"] for s in stops],
			}
		# golem: hidden and sunk (its first keyed pose, the slabs, below the floor) until her strike at 0.8 s, rises by 1.3 s, then its keys
		move = moves["golem"]
		keys = [k for k in move["keys"] if k.get("golem")]
		first = gstate(self.gbind, keys[0])
		sunk = first["vec"]["root"] - (self.span(first)[1] + GOLEM_SINK)
		hidden = [gstate(self.gbind, keys[0], t=t, scale=0.0, root=sunk) for t in (0.0, GOLEM_RISE)]
		# its last key (5.0 s, pushing up off the floor) is not golem_idle key 0: it runs on GOLEM_SETTLE s past her move into it
		settle = gstate(self.gbind, moves["golem_idle"]["keys"][0], t=move["end"] + GOLEM_SETTLE)
		stops = hidden + [gstate(self.gbind, k) for k in keys] + [settle]
		out["golem"] = {
			"frames": self.bake("golem", stops, GOLEM_PLAN["golem"], settle["t"], EVENTS["golem"][1]),
			"approved": [k["t"] for k in keys],
			"events": [{"Time": EVENTS["golem"][1], "Name": "Slam"}],
			"duration": settle["t"],
			"stops": [s["t"] for s in stops],
		}
		return out


GOLEM_RISE = 0.8  # proposed: her strike on the rune; the slabs push up through the floor from here to her 1.3 s key
GOLEM_SETTLE = 0.6  # proposed: the golem's part of golem past her 5.0 s, from its last key into golem_idle key 0 (GolemAt plays it)
GOLEM_PLAN = {
	"golem": (
		{"ease": lin},  # hidden
		{"ease": eout(1.6)},  # 0.8 -> 1.3 the slabs push up through the floor and grow
		{"ease": ease(1.6)},  # 1.3 -> 1.9 the blocks fly in
		{"ease": ease(1.6)},  # 1.9 -> 2.5
		{"ease": ease(1.6)},  # 2.5 -> 3.0 the head block lands
		{"ease": ease(1.8)},  # 3.0 -> 3.6 fists up
		{"ease": ein(2.2)},  # 3.6 -> 4.2 into the slam (the hit snap)
		{"ease": eout(1.6), "hold": 0.06},  # 4.2 -> 5.0 stuck on the slam, then pushes up
		{"ease": ease(1.8)},  # 5.0 -> 5.6 settles into golem_idle key 0
	),
	"golem_slam": (
		{"ease": ease(1.8)},  # 0 -> 0.4 anticipation
		{"ease": ease(1.8)},  # 0.4 -> 0.9 arms swing up
		{"ease": ease(2.0)},  # 0.9 -> 1.5 wind-up
		{"ease": ease(2.0)},  # 1.5 -> 2.25 coils deeper, held through the rhythm dodge
		{"ease": ein(1.8)},  # 2.25 -> 2.6 the fall starts
		{"ease": ein(2.2)},  # 2.6 -> 2.8 into the hit (the hit snap)
		{"ease": eout(1.6), "hold": 0.06},  # 2.8 -> 3.0 stuck, then sinks into the impact
		{"ease": ease(1.8)},  # 3.0 -> 3.3 pushes off
		{"ease": ease(2.0)},  # 3.3 -> 3.6 into idle key 0
	),
	"golem_sweep": (
		{"ease": ease(1.8)},  # 0 -> 0.4 anticipation
		{"ease": ease(1.8)},  # 0.4 -> 1.0 coils
		{"ease": ease(2.0)},  # 1.0 -> 1.6 held through the rhythm dodge
		{"ease": ein(1.6)},  # 1.6 -> 2.2 the hips lead
		{"ease": ein(2.0)},  # 2.2 -> 2.6 the arm into the hit (the hit snap)
		{"ease": eout(1.6), "hold": 0.03},  # 2.6 -> 2.85 follow-through
		{"ease": ease(1.8), "carry": 0.06},  # 2.85 -> 3.2 overshoot
		{"ease": ease(1.8)},  # 3.2 -> 3.7 recovers
		{"ease": ease(2.0)},  # 3.7 -> 4.2 into idle key 0
	),
	"golem_idle": (LOOP_PLAN,) * 10,
	"golem_fall": (
		{"ease": ease(1.5)},  # 0 -> 0.2
		{"ease": ease(1.5)},  # 0.2 -> 0.4
		{"ease": ease(1.4)},  # 0.4 -> 0.6 drops to its knees (root 0.38 units in 0.2 s)
		{"ease": ease(1.5)},  # 0.6 -> 0.8
		{"ease": ease(1.5)},  # 0.8 -> 1.0
		{"ease": ease(1.5)},  # 1.0 -> 1.2
		{"ease": ease(1.5)},  # 1.2 -> 1.45
		{"ease": lin},  # 1.45 -> 1.7 the blocks tumble down: up to 180 degrees in 15 frames, so no easing (was ease(1.5): 19 deg/frame)
		{"ease": lin},  # 1.7 -> 2.0 the heap shrinks away (scale 1 -> 0); no easing, as above (ein(2.0): 19 deg/frame at its end)
	),
}


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


def golem_rotations(frames, parts):
	"""A golem track as raga frames: rotations and (0, 0, root), as SampleGolem gives them."""
	return [(t, {p: [c["%s:r%d" % (p, i)] for i in range(3)] for p in parts}, (0.0, 0.0, c["root"])) for t, c in frames]


def golem_window(k, first, summon_end, lengths):
	"""Golem hit k's track: (name, start, end) on the golem clock. Hit 1 is the golem move's slam, inside the summon."""
	if k < 2:
		return "golem", 0.0, summon_end
	name = "golem_slam" if k % 2 == 1 else "golem_sweep"
	duration, event = lengths[name]
	start = first + GOLEM_EVERY * (k - 1) - event
	return name, start, start + duration


def golem_at(tau, tracks, lengths, first):
	"""Poses.GolemAt in Python (the Luau mirrors it): her move and time, the golem's move and time, tau s after BossMinionStart.
	The golem's part of golem runs GOLEM_SETTLE s past hers. Between two tracks golem_idle plays a whole number of its loops (at
	least one), stretched to the gap: it leaves the last track's end and meets the next track's start on key 0, so no pop."""
	summon, risen = ENDS["golem"], tracks["golem"]["duration"]
	if tau < summon:
		return "golem", tau, "golem", tau
	h = ("watch_in", tau - summon) if tau < summon + WATCH_LEAD else ("watch", (tau - summon - WATCH_LEAD) % 3.0)
	if tau < risen:
		return h + ("golem", tau)
	k = int((tau - first) // GOLEM_EVERY) + 1
	name, start, _ = golem_window(k + 1, first, risen, lengths)
	if tau >= start:
		return h + (name, tau - start)
	last = risen
	if k >= 2:
		prev, prev_start, finish = golem_window(k, first, risen, lengths)
		if tau < finish:
			return h + (prev, tau - prev_start)
		last = finish
	period = tracks["golem_idle"]["duration"]
	gap = start - last
	loops = max(1, math.floor(gap / period + 0.5))
	return h + ("golem_idle", ((tau - last) / gap * loops * period) % period)


# ---- checks ----


def snaps_of(events, key_times):
	"""boss_mage_anim's hit snap: the key segment that ends on each event, to SNAP s after it."""
	out = []
	for e in events:
		before = [k for k in key_times if k < e["Time"] - 1e-6]
		out.append((max(before) if before else e["Time"], e["Time"] + SNAP))
	return out


def check_continuity(name, frames, parts, events, key_times, duration, root=True):
	"""boss_mage_anim "continuous" in Python: Sample's lerp at 60 Hz, at most LIMIT_DEGREES per part and LIMIT_OFFSET root (units) a
	frame, outside the hit snap. Also the thinning's largest gap."""
	snaps = snaps_of(events, list(key_times) or [f[0] for f in frames])
	prev = raga.lerp_frame(frames, 0, parts)
	worst, worst_at, worst_part, worst_root = 0.0, 0.0, None, 0.0
	for k in range(1, int(math.floor(duration * 60 + 1e-9)) + 1):
		t = k / 60
		cur = raga.lerp_frame(frames, t, parts)
		if not any(a < t <= b for a, b in snaps):
			for p in parts:
				d = apart(prev[0][p], cur[0][p])
				if d > worst:
					worst, worst_at, worst_part = d, t, p
			worst_root = max(worst_root, float(np.abs(cur[1] - prev[1]).max()))
		prev = cur
	gaps = max(b[0] - a[0] for a, b in zip(frames, frames[1:]))
	print(f"BAKE {name}: {len(frames)} keys, largest gap {gaps:.4f} s, worst {worst:.2f} deg/frame at {worst_at:.3f} s on {worst_part}, root {worst_root:.4f}/frame")
	assert worst <= LIMIT_DEGREES, f"{name}: {worst:.2f} degrees in a frame at {worst_at:.3f} s on {worst_part}"
	assert worst_root <= LIMIT_OFFSET or not root, f"{name}: root {worst_root} in a frame"
	assert gaps <= raga.MAX_GAP + 1e-9, f"{name}: a key gap of {gaps} s"
	assert frames[0][0] == 0 and abs(frames[-1][0] - duration) < 1e-9, name
	assert all(0 < e["Time"] < duration for e in events), f"{name}: an event outside the move"


def check_cycle(moves):
	"""The shortest gap between two hit events, the cycle repeating, the golem slot, and every move covered."""
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
	assert abs(at - CYCLE_SECONDS) < 1e-9 and abs(slot - SLOT_AT) < 1e-9, (at, slot)
	assert {r[0] for r in CYCLE} | {"golem", "watch", "watch_in"} == set(moves), "a move missing from the cycle"
	led = {"lightning_in": "lightning", "barrage_in": "barrage", "golem_in": "golem_fall"}
	for i, row in enumerate(CYCLE):
		if row[0] in led:
			assert CYCLE[i + 1][0] == led[row[0]], "a lead not right before its move"
		elif row[0] != "idle":
			assert led.get(CYCLE[i - 1][0]) == row[0], "an attack not led into"
	return slot, at


def check_golem(tracks, lengths, first, parts):
	"""The golem clock: tracks never overlap, every hit's circles open after the track before it ends, Slam and Sweep take turns,
	and the golem's blocks and root stay inside the frame limits across track seams, 0 to 60 s."""
	summon = tracks["golem"]["duration"]
	for k in range(1, 14):
		name, start, _ = golem_window(k, first, summon, lengths)
		hit = first + GOLEM_EVERY * (k - 1)
		assert abs(start + tracks[name]["events"][0]["Time"] - hit) < 1e-9, k
		assert tracks[name]["events"][0]["Name"] == ("Slam" if k % 2 == 1 else "Sweep"), k
		if k > 1:
			_, _, prev_end = golem_window(k - 1, first, summon, lengths)
			assert prev_end <= start + 1e-9, f"golem tracks {k - 1} and {k} overlap"
			assert hit - prev_end >= OSU_OPEN - 1e-9, f"hit {k}: circles open before track {k - 1} ends"
	rot = {n: golem_rotations(t["frames"], parts) for n, t in tracks.items()}
	free = []
	for k in range(1, 14):
		name, start, _ = golem_window(k, first, summon, lengths)
		free += [(start + a, start + b) for a, b in snaps_of(tracks[name]["events"], tracks[name]["approved"])]
	worst, worst_at, worst_root, prev, prev_name = 0.0, None, 0.0, None, None
	for i in range(int(1.3 * 60), 60 * 60 + 1):  # from the risen golem's first key
		tau = i / 60
		_, _, name, t = golem_at(tau, tracks, lengths, first)
		cur = raga.lerp_frame(rot[name], t, parts)
		if prev is not None and not any(a < tau <= b + 1e-9 for a, b in free):
			d = max(apart(cur[0][p], prev[0][p]) for p in parts)
			if d > worst:
				worst, worst_at = d, (round(tau, 3), name, round(t, 3), prev_name)
			worst_root = max(worst_root, float(np.abs(cur[1] - prev[1]).max()))
		prev, prev_name = cur, name
	print(f"BAKE golem clock: hits every {GOLEM_EVERY} s from {first}, worst {worst:.2f} deg/frame at {worst_at}, root {worst_root:.4f}/frame over 60 s")
	assert worst <= LIMIT_DEGREES, f"golem clock: {worst} degrees in a frame"
	assert worst_root <= LIMIT_OFFSET, f"golem clock: root {worst_root} in a frame"


def check_bind(mage, data, bind):
	"""The joint chain the client builds reproduces jsolve's key poses, and keys.json is still what jsolve makes."""
	for name in HERS:
		jkeys = mk.JMOVES[name]["keys"]
		move = data["moves"][name]
		assert [k["t"] for k in jkeys] == [k["t"] for k in move["keys"]], name
		for jkey, approved in zip(jkeys, move["keys"]):
			m, record, grip, _ = mk.jsolve(jkey)
			for p, v in record.items():
				assert apart(v, approved["rotations"][p]) < 1e-3, f"rework keys.json {name} {jkey['t']} {p} is not jsolve's"
			assert max(abs(a - b) for a, b in zip(grip, approved["staff_grip_offset"])) < 1e-3
			_, body, root = mage.frame(jkey["t"], state(approved), None)
			world = joints(bind, body, root)
			for p in PARTS:
				want = m[MESH[p]] @ Matrix.Translation(mage.pivots[p])
				assert max(abs(a - b) for ra, rb in zip(want, world[p]) for a, b in zip(ra, rb)) < 1e-3, f"bind {p} at {name} {jkey['t']}"


def check_verbatim(mage, moves):
	"""Every key at its time, on the thinned frames, is its keys.json pose (Body folded in for Torso and the thighs)."""
	for name in HERS:
		move = mage.data["moves"][name]
		frames = {f[0]: f for f in moves[name][0]}
		assert moves[name][1] == [k["t"] for k in move["keys"]] == KEY_TIMES[name], name
		for k in move["keys"]:
			st = state(k)
			f = frames[float(k["t"])]
			rot, locs = mage.pose(st)
			for p in PARTS:
				assert apart(f[1][p], [math.degrees(v) for v in rot[p].to_euler("XYZ")]) < 1e-3, f"{name} {k['t']} {p}: off its key"
			for p in LOCS:
				assert max(abs(a - b) for a, b in zip(f[1][p + "@"], (locs[p] - Vector(mage.bind[p]["Offset"])) * 100)) < 1e-3, f"{name} {k['t']} {p}: loc"
			assert tuple(f[2]) == tuple(float(v) for v in k["root_offset"]), f"{name} {k['t']}: root"


def check_golem_verbatim(data, tracks, gparts):
	"""Every golem key at its track time: its rotations (as rotations), locs, root; scale 1 (golem_fall's last: 0)."""
	for name, track in tracks.items():
		keys = [k for k in data["moves"][name]["keys"] if k.get("golem")]
		assert track["approved"] == [k["t"] for k in keys], name
		frames = {round(t, 6): c for t, c in track["frames"]}
		for k in keys:
			c = frames[round(k["t"], 6)]
			for p in gparts:
				assert apart([c["%s:r%d" % (p, i)] for i in range(3)], k["golem"][p]["rot"]) < 1e-3, (name, k["t"], p)
				assert [c["%s:l%d" % (p, i)] for i in range(3)] == k["golem"][p]["loc"], (name, k["t"], p)
			assert c["root"] == k.get("golem_root_z", 0), (name, k["t"])
			last = name == "golem_fall" and k is keys[-1]
			assert c["scale"] == (0 if last else 1), (name, k["t"])


def check_rig(bind, dims, frames):
	"""ui_boss_mage_rig's sanity check in Python: lightning at 1.0 s, the staff upright with its upper end above her head's box; at
	2.05 s, the staff near level. The staff's axis is its box's longest side."""
	for t, upright in ((1.0, True), (2.05, False)):
		rot, root = raga.lerp_frame(frames, t, list(PARTS) + [p + "@" for p in LOCS])
		world = joints(bind, {p: tuple(v) for p, v in rot.items()}, Vector(root))
		i = int(np.argmax(dims["Staff"]))
		m = world["Staff"]
		axis = (m.to_3x3() @ Vector([1.0 if j == i else 0.0 for j in range(3)])).normalized()
		top = (m @ Vector(bind["Staff"]["Center"])).z + abs(axis.z) * dims["Staff"][i] / 2
		h = world["Head"]
		head = max((h @ (Vector(bind["Head"]["Center"]) + Vector([sx * dims["Head"][0], sy * dims["Head"][1], sz * dims["Head"][2]]) / 2)).z for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1))
		print(f"BAKE rig at {t} s: staff axis up {axis.z:.2f}, staff top over head top {top - head:.2f} units")
		assert (abs(axis.z) >= 0.8 and top > head) if upright else abs(axis.z) <= 0.5, f"rig at {t} s"


# ---- binds from the models ----


def local_verts(o):
	co = np.empty(len(o.data.vertices) * 3)
	o.data.vertices.foreach_get("co", co)
	return co.reshape(-1, 3)


def mage_bind(data, scale):
	"""Her 17 parts as the client wants them. A part's joint is its keys.json pivot (the staff's sits in the fist: pivot + grip)."""
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	assert sorted(objs) == sorted(MESH.values()), sorted(objs)
	assert sorted(p for p in data["pivots"] if p != "Body") == sorted(PARTS)
	grips = {tuple(round(v, 3) + 0 for v in k["staff_grip_offset"]) for n in HERS for k in data["moves"][n]["keys"]}
	assert len(grips) == 1, grips
	parents = {p: data["parents"][p] for p in PARTS}
	parents.update({p: None for p in FOLDED})
	joint = {p: Vector(data["pivots"][p]) + (Vector(next(iter(grips))) if p == "Staff" else Vector()) for p in PARTS}
	bind, dims = {}, {}
	for p in PARTS:
		o = objs[MESH[p]]
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
		}
		dims[p] = hi - lo
		if p == "Staff":  # the gem at its head, from the joint: where the lightning leaves
			bind[p]["Tip"] = tuple(mesh_origin + Vector(co[co[:, 2] > co[:, 2].max() - 0.9].mean(axis=0)))
	for n in ("TailL1", "TailL2", "TailL3", "TailR1", "TailR2", "TailR3"):  # jsolve's tail pivots, as the key tool reads them
		mk.TPIV[n] = objs[n].matrix_world.translation.copy()
	return bind, objs, dims


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

FUNCTIONS = """
local Poses = {}
Poses.Moves = MOVES
Poses.Approved = APPROVED
Poses.Bind = BIND -- each part: Parent, Offset from its parent's joint, Center of its box from its own joint (units), Size (studs)
Poses.Bind6 = BIND6 -- the uploaded 6-part model's bind: Client/BossMage's fallback until the jointed model is uploaded
Poses.Scale = SCALE
Poses.RootStuds = ROOT_STUDS -- studs per keys.json root_offset unit: Keys' Root is already studs

local PARTS, OFFSETS = {}, {}
for part, row in BIND do
	table.insert(PARTS, part)
	OFFSETS[part] = Vector3.new(row.Offset[1], row.Offset[2], row.Offset[3])
end
-- Joints that move on their parent: the hips round her body's turn.
local LOCS = { "LeftUpperLeg", "RightUpperLeg" }

-- Plain numbers to Vector3s, once. A part left out of a move's keys holds one value for the whole move.
for _, move in MOVES do
	for _, key in move.Keys do
		for part, v in key.Parts do
			key.Parts[part] = Vector3.new(v[1], v[2], v[3])
		end
		key.Root = Vector3.new(key.Root[1], key.Root[2], key.Root[3])
		if key.Locs then
			for part, v in key.Locs do
				key.Locs[part] = Vector3.new(v[1], v[2], v[3])
			end
		end
	end
	local held = {}
	for part, v in move.Held do
		held[part] = Vector3.new(v[1], v[2], v[3])
	end
	move.Held = held
end

-- The pose of a move at time t, clamped to the move: parts[part] a Vector3 of XYZ Euler degrees, rootOffset a Vector3 in studs,
-- locs[part] each joint's offset from its parent's joint in model units: pass them to BossRaga:Pose as its locs.
function Poses.Sample(name, t)
	local move = MOVES[name]
	local keys = move.Keys
	local low, high = 1, #keys
	if t <= keys[1].Time then
		high = 1
	elseif t >= keys[high].Time then
		low = high
	end
	while high - low > 1 do
		local middle = (low + high) // 2
		if keys[middle].Time <= t then
			low = middle
		else
			high = middle
		end
	end
	local a, b = keys[low], keys[high]
	local u = low == high and 0 or (t - a.Time) / (b.Time - a.Time)
	local parts, locs = {}, table.clone(OFFSETS)
	for _, part in PARTS do
		local from = a.Parts[part]
		if from then
			parts[part] = from:Lerp(b.Parts[part], u)
		else
			parts[part] = move.Held[part]
		end
	end
	for _, part in LOCS do
		local from, to = a.Locs and a.Locs[part], b.Locs and b.Locs[part]
		if from or to then
			locs[part] = (from or OFFSETS[part]):Lerp(to or OFFSETS[part], u)
		end
	end
	return parts, a.Root:Lerp(b.Root, u), locs
end
"""

EXTRA = """
Poses.HoverStuds = HOVER -- her rest feet above the arena floor
Poses.GolemBind = GOLEM_BIND -- as Bind, in golem units, Size in studs at GolemScale; Rest is its rest rotation (XYZ degrees)
Poses.GolemScale = GOLEM_SCALE -- studs per golem unit
-- The golem's root (its rest feet) from her anchor (her rest feet), studs, Blender axes, and its turn about Z (up) from her facing.
Poses.GolemAnchor = Vector3.new(GOLEM_ANCHOR[1], GOLEM_ANCHOR[2], GOLEM_ANCHOR[3])
Poses.GolemYaw = GOLEM_YAW

Poses.GolemMoves = GOLEM_MOVES -- the golem's own tracks on its clock (BossMinionStart): Duration, Approved, Events, Golem frames
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

-- A golem key's Locs hold only the blocks off their bind Offset (rising, breaking apart, crumbled).
local GOLEM_OFFSETS = {}
for part, row in GOLEM_BIND do
	GOLEM_OFFSETS[part] = Vector3.new(row.Offset[1], row.Offset[2], row.Offset[3])
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
		locs[part] = (a.Locs[part] or GOLEM_OFFSETS[part]):Lerp(b.Locs[part] or GOLEM_OFFSETS[part], u)
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
-- Pure, like Schedule: every client shows the same pose at the same moment. The golem's part of golem runs past hers into
-- golem_idle key 0. Between two tracks golem_idle plays a whole number of
-- its loops (at least one) stretched to the gap, so it leaves one track and meets the next on its key 0.
function Poses.GolemAt(tau)
	local summon, lead = MOVES.golem.Duration, MOVES.watch_in.Duration
	if tau < summon then
		return "golem", tau, "golem", tau
	end
	local herMove, herTime = "watch", (tau - summon - lead) % MOVES.watch.Duration
	if tau < summon + lead then
		herMove, herTime = "watch_in", tau - summon
	end
	-- the golem's part of golem runs on past hers, from its last key into golem_idle key 0
	local risen = MOVES.golem.Golem[#MOVES.golem.Golem].Time
	if tau < risen then
		return herMove, herTime, "golem", tau
	end
	local k = (tau - GOLEM_FIRST_HIT) // GOLEM_EVERY + 1
	local name, start = golemTrack(k + 1)
	if tau >= start then
		return herMove, herTime, name, tau - start
	end
	local last = risen
	if k >= 2 then
		local previous, previousStart, finish = golemTrack(k)
		if tau < finish then
			return herMove, herTime, previous, tau - previousStart
		end
		last = finish
	end
	local period = GOLEM_MOVES.golem_idle.Duration
	local gap = start - last
	local loops = math.max(1, math.floor(gap / period + 0.5))
	return herMove, herTime, "golem_idle", ((tau - last) / gap * loops * period) % period
end

return Poses
"""


def bind_lines(bind, extra=()):
	out = []
	for name, b in sorted(bind.items()):
		more = "".join(", %s = %s" % (k, raga.vec(b[k], 3)) for k in extra if k in b)
		parent = '"%s"' % b["Parent"] if b["Parent"] else "nil"
		out.append("\t%s = { Parent = %s, Offset = %s, Center = %s, Size = %s%s }," % (name, parent, raga.vec(b["Offset"], 4), raga.vec(b["Center"], 4), raga.vec(b["Size"], 2), more))
	return out


def golem_lines(gbind, frames, pinned_t):
	out = ["\t\tGolem = {"]
	for t, c in frames:
		places = 3 if any(abs(t - p) < 1e-9 for p in pinned_t) else 1
		rot = ",".join("%s=%s" % (p, raga.vec([c["%s:r%d" % (p, i)] for i in range(3)], places)) for p in sorted(gbind))
		# a block at its bind offset (the golem whole) is left out: SampleGolem takes the bind's (size: 248 KB of 913 KB were these)
		loc = ",".join("%s=%s" % (p, raga.vec([c["%s:l%d" % (p, i)] for i in range(3)], 3)) for p in sorted(gbind) if max(abs(c["%s:l%d" % (p, i)] - gbind[p]["Offset"][i]) for i in range(3)) >= 1e-3)
		out.append("\t\t\t{Time=%s,Scale=%s,Root={0,0,%s},Parts={%s},Locs={%s}}," % (raga.fmt(t, 4), raga.fmt(c["scale"], 3), raga.fmt(c["root"], 3), rot, loc))
	out.append("\t\t},")
	return out


def write_luau(mage, bind, moves, golem, consts):
	fmt, vec = raga.fmt, raga.vec
	scale = consts["scale"]
	lines = [
		"--!nonstrict",
		"-- Generated by tools/blender/bake_boss_mage.py from assets/characters_avatar/boss_mage/keyframes/rework/keys.json. Do not edit",
		'-- by hand. The Elf Mage\'s moves on her jointed rig and her golem (design doc 4.37 "Second boss" and "Animation rework",',
		'-- docs/BOSS_EVENT_SPEC.md "The Elf Mage"), client-side visuals; the server reads Schedule and Events only. Same shape as',
		"-- BossRagaPoses, plus Sample's locs. The 10 rework keys of every move (owner 2026-11-12) are at their times, with Body (her hip",
		"-- turn) folded into Torso and the thighs. Time is seconds, Parts XYZ Euler degrees, Root STUDS, Locs model units; the hover bob",
		"-- is Client/BossMage's. Proposed: the hover %s studs, the golem's spot, its rise and every in-between." % fmt(consts["hover"]),
		'local Event = require(game:GetService("ReplicatedStorage").Shared.BossEventConfig)',
		"",
		"local SCALE = %s -- studs per model unit: %s x a %s-stud character, %s studs tall" % (fmt(scale, 4), SIZE, fmt(mk.CHAR_H), fmt(consts["height"], 1)),
		"local ROOT_STUDS = SCALE",
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
		"-- shortcut: the 6-part model uploaded 2026-11-11 (SidekickArt.boss_mage.BossModel), its parts named after the jointed upper",
		"-- segments they stand in for (Mesh: the uploaded name); delete when boss_mage_jointed is uploaded.",
		"-- stylua: ignore",
		"local BIND6 = {",
		BIND6,
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
		pinned_t = set(approved) | {0.0, float(duration)}
		moved = [p for p in PARTS if any(max(abs(a - b) for a, b in zip(f[1][p], frames[0][1][p])) > 1e-3 for f in frames)]
		held = [p for p in PARTS if p not in moved]
		locs = [p for p in LOCS if any(abs(v) > 1e-6 for f in frames for v in f[1][p + "@"])]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in approved))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		if name in WINDOW:
			lines.append("\t\tWindow = { %s }," % ", ".join(fmt(v, 3) for v in WINDOW[name]))
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned_t else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			extra = ""
			if locs:
				extra = ",Locs={%s}" % ",".join("%s=%s" % (p, vec([a + b / 100 for a, b in zip(bind[p]["Offset"], f[1][p + "@"])], 4)) for p in locs)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}%s}," % (fmt(f[0], 4), vec([v * scale for v in f[2]], 4), body, extra))
		lines.append("\t\t},")
		if name in golem["tracks"]:
			lines += golem_lines(golem["bind"], golem["tracks"][name]["frames"], golem["tracks"][name]["stops"])
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local GOLEM_MOVES = {"]
	for name in ("golem_idle", "golem_slam", "golem_sweep"):
		track = golem["tracks"][name]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(track["duration"], 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in track["approved"]))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in track["events"]))
		lines += golem_lines(golem["bind"], track["frames"], track["stops"])
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name in HERS:
		frames = {f[0]: f for f in moves[name][0]}
		lines.append("\t%s = {" % name)
		for k in mage.data["moves"][name]["keys"]:
			f = frames[float(k["t"])]
			root = [fmt(v, 4) if float(fmt(v, 4)) == v else repr(float(v)) for v in k["root_offset"]]  # verbatim: the idle sway's are long
			assert [float(v) for v in root] == [float(v) for v in k["root_offset"]], f"{name} {k['t']}: a root would not print verbatim"
			body = ",".join("%s=%s" % (p, vec(f[1][p], 3)) for p in PARTS)
			lines.append("\t\t{Time=%s,RootOffset={%s},Parts={%s}}," % (fmt(k["t"], 3), ",".join(root), body))
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local CYCLE = {"]
	for row in CYCLE:
		lines.append("\t{%s}," % ", ".join('"%s"' % v if isinstance(v, str) else str(v) for v in row))
	lines.append("}")
	tail = raga.FUNCTIONS[raga.FUNCTIONS.index("local cycleLength = 0") :]  # Schedule, RiseAt: as the raga's and the king's
	assert tail.endswith("\nreturn Poses\n")
	text = "\n".join(lines) + "\n" + FUNCTIONS + "\n" + tail[: -len("return Poses\n")] + EXTRA
	with open(LUAU, "w") as f:
		f.write(text)
	print(f"BAKE wrote {LUAU}: {len(text)} bytes ({len(text) / 1024:.1f} KB, was 511 KB), {sum(len(m[0]) for m in moves.values())} keys, golem {sum(len(t['frames']) for t in golem['tracks'].values())} keys")
	return len(text)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	wanted = [a for a in argv if a in ("poses", "glb")] or ["poses", "glb"]
	with open(REWORK) as f:
		data = json.load(f)
	for name, times in KEY_TIMES.items():
		move = data["moves"][name]
		assert [k["t"] for k in move["keys"]] == times and move["end"] == ENDS[name], name
		if name in EVENTS:
			assert [(k["event"], k["t"]) for k in move["keys"] if "event" in k] == [EVENTS[name]], name
	height = SIZE * mk.CHAR_H
	scale = height / data["scale"]["model_height_units"]
	assert abs(scale - data["scale"]["studs_per_model_unit_at_8x"]) < 1e-3

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_mage"])
	bind, objs, dims = mage_bind(data, scale)
	mage = Mage(data, bind)
	check_bind(mage, data, bind)
	print("BAKE bind: the client chain reproduces jsolve at all 50 of her rework keys")
	if "glb" in wanted:
		for o in list(bpy.data.objects):
			if o.type != "MESH":
				bpy.data.objects.remove(o)
		parts = {p: objs[MESH[p]] for p in PARTS}
		for p, o in parts.items():
			o.name = o.data.name = p
		raga.write_glb(parts, GLB["boss_mage"])

	bpy.ops.wm.open_mainfile(filepath=BLEND["boss_golem"])
	gbind, gobjs, gverts, golem_h, golem_low, golem_scale = golem_bind(lambda h: mk.GOLEM_RATIO * height / h)
	if "glb" in wanted:
		raga.write_glb(gobjs, GLB["boss_golem"])

	if "poses" in wanted:
		golem = Golem(data, gbind, gverts)
		tracks = golem.tracks()
		moves = {"idle": mage.loop("idle"), "watch": mage.loop("watch")}
		for name in PLAN:
			moves[name] = mage.attack(name)
			moves[name + "_in"] = mage.lead(name + "_in", mage.idle0, state(data["moves"][name]["keys"][0]), LEAD[name])
		moves["watch_in"] = mage.lead("watch_in", mage.idle0, mage.watch0, WATCH_LEAD)
		moves["golem_fall"] = mage.lead("golem_fall", mage.watch0, mage.idle0, ENDS["golem_fall"], KEY_TIMES["golem_fall"], ({"ease": ease(2.0)},))
		thin_parts = list(PARTS) + [p + "@" for p in LOCS]
		for name, (frames, approved, events, duration, keep) in list(moves.items()):
			thinned = raga.thin(frames, thin_parts, keep)
			check_continuity(name, thinned, thin_parts[: len(PARTS)], events, KEY_TIMES.get(name, approved), duration)
			moves[name] = (thinned, approved, events, duration, keep)
			assert all(set(f[1]) == set(thin_parts) for f in thinned), f"{name}: a part without keys"
		check_verbatim(mage, moves)
		check_rig(bind, dims, moves["lightning"][0])
		print(f"BAKE verbatim (her): {mage.verbatim['shifted']} key Euler components moved by whole turns, other-branch keys {mage.verbatim['rewritten']}")
		slot_at, cycle_s = check_cycle(moves)
		gparts = sorted(gbind)
		for name, track in tracks.items():
			# the golem move's rise is no keyed motion (its root climbs out of the floor): rotations only, as before the rework
			check_continuity(name + " (golem)", golem_rotations(track["frames"], gparts), gparts, track["events"], KEY_TIMES[name], track["duration"], root=name != "golem")
			assert all(len([c for c in f if c.endswith(":r0")]) == 15 for _, f in track["frames"]), f"{name}: a golem block without keys"
		check_golem_verbatim(data, tracks, gparts)
		print(f"BAKE verbatim (golem): {golem.verbatim['shifted']} key Euler components moved by whole turns, other-branch keys {golem.verbatim['rewritten']}")
		lengths = {n: (tracks[n]["duration"], tracks[n]["events"][0]["Time"]) for n in ("golem_slam", "golem_sweep")}
		first = EVENTS["golem"][1]
		check_golem(tracks, lengths, first, gparts)
		frames = tracks["golem"]["frames"]
		assert frames[0][1]["scale"] == 0 and frames[-1][1]["scale"] == 1, "golem scale ends"
		assert tracks["golem_fall"]["frames"][0][1]["scale"] == 1 and tracks["golem_fall"]["frames"][-1][1]["scale"] == 0, "golem_fall scale ends"
		at = raga.lerp_frame([(t, {"s": (c["scale"], 0, 0)}, (0, 0, 0)) for t, c in frames], 1.26, ["s"])[0]["s"][0]
		assert at > 0, f"golem hidden at 1.26 s: scale {at}"
		yaw = -25.0  # boss_mage_keyframes.load_scene: turned a little toward the arena centre
		anchor = (GAME_GOLEM_SPOT[0], GAME_GOLEM_SPOT[1], -mk.HOVER - golem_low * golem_scale)
		consts = {"scale": scale, "height": height, "hover": mk.HOVER, "golem_scale": golem_scale, "golem_anchor": anchor, "golem_yaw": yaw, "slot_at": slot_at, "first_hit": first}
		print(f"BAKE scale {scale:.4f} studs/unit, golem {golem_h:.3f} units x {golem_scale:.4f} = {golem_h * golem_scale:.1f} studs, anchor {anchor}")
		print(f"BAKE cycle {cycle_s:.3f} s, golem slot {slot_at:.3f} s")
		size = write_luau(mage, bind, moves, {"bind": gbind, "tracks": tracks}, consts)
		if size > 700 * 1024:  # the orchestrator's line (2026-11-12): report it; thinning is already the king's (bake_boss_raga.thin)
			print(f"BAKE SIZE WARNING: BossMagePoses {size / 1024:.0f} KB, past 700 KB (511 KB before the rework)")
		print("BAKE self-check passed")


if __name__ == "__main__":
	main()
