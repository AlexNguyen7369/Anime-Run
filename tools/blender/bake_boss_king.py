# The Golden King's in-betweens and game model on his jointed rig (design doc 4.37 "Third boss" and "Animation rework",
# BOSS_EVENT_SPEC "The Golden King" and "Animation rework").
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py -- jointed   (boss_king_jointed.blend, git-ignored)
#   Blender -b --factory-startup --python tools/blender/bake_boss_king.py -- [poses] [glb]
# poses   writes src/late/BossKingPoses.luau from keyframes/rework/keys.json, 10 keys a move: enuma (owner approved 2026-11-12),
#         idle, gates (its 2 s window inside) and shields (pre-approved 2026-11-12 night). fortified_idle (rework keys too) is not
#         baked: the server never schedules it (his Fortified status plays idle; the shield ring is BossKingVfx's). Keys verbatim at their times; everything between them generated here: quaternion interpolation per
#         part with asymmetric easing, written as Euler keys (each in-between the Euler nearest the frame before it); springs on Ea,
#         the forearms, the head and the Key; torso and head 1 and 2 frames behind; Big Raga's RECOIL after each hit. Then
#         self-checked (asserts, the boss_king_anim continuity check with its hit snap included). Run stylua after.
# glb     writes build/avatar_glb/boss_king_jointed.glb: the 15 jointed parts (Torso, Head, upper and lower arms and legs, Key,
#         Ea = the grip, Ea_Drum1-3), unposed, no hierarchy, each centred on its box (bake_boss_raga.write_glb). Upload it as
#         boss_king_jointed (upload_avatar.py, sidekick_art.py): SidekickArt.boss_king_jointed.BossModel. Nothing here uploads.
# Body (his hip turn, 180 degrees at the Enuma Elish hit) is no part: it is folded into Torso's and the thighs' rotations, and the hip
# joints it carries round go out as Keys' Locs (model units), as does Ea's grip on the forearm (it leaves the hand at idle key 0).
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_boss_mage as bm  # noqa: E402  (guarded main: secondary, local_verts, bind_lines)
import bake_boss_raga as raga  # noqa: E402  (guarded main: easing, thinning, RECOIL, number format, write_glb)
import boss_king_keyframes as kk  # noqa: E402  (guarded main: the key pose solvers and the stage constants)

ease, eout, ein = raga.inout, raga.eout, raga.ein

ROOT = os.path.dirname(os.path.dirname(HERE))
KEYDIR = os.path.join(ROOT, "assets", "characters_avatar", "boss_king", "keyframes")
REWORK = os.path.join(KEYDIR, "rework", "keys.json")
BLEND = os.path.join(ROOT, "assets", "characters_avatar", "boss_king", "boss_king_jointed.blend")
GLB = os.path.join(ROOT, "build", "avatar_glb", "boss_king_jointed.glb")
LUAU = os.path.join(ROOT, "src", "late", "BossKingPoses.luau")

SIZE = 8  # his height in runner heights (spec, proposed)
RATE = bm.RATE
LIMIT_DEGREES, LIMIT_ROOT, SNAP = 12, 0.05, 0.05  # boss_king_anim "continuous": per 60 Hz frame, the hit snap's tail
LEAD = 0.75  # fixed (the stub's): idle key 0 into each move's first key
IDLE_ROW = 4.0  # s of the idle loop a cycle row plays: its whole period, so it never pops
CYCLE_SECONDS = 38.85  # fixed (spec "Animation rework": CycleSeconds does not change)
# Fixed order. Rows as BossMagePoses: { "idle", from, seconds } or { move }.
CYCLE = (
	("idle", 0, IDLE_ROW),
	("gates_in",),
	("gates",),
	("idle", 0, IDLE_ROW),
	("idle", 0, IDLE_ROW),
	("enuma_in",),
	("enuma",),
	("idle", 0, IDLE_ROW),
	("idle", 0, IDLE_ROW),
	("shields_in",),
	("shields",),
	("idle", 0, IDLE_ROW),
)
# keys.json event -> the schedule event the server charges or sets at; every Dodge bar move also opens with "<move>_start" at 0
EVENTS = {"gates": ("gates", "gates"), "enuma": ("Beam", "enuma"), "shields": ("shields", "shields")}
WINDOW = {"gates": (1.6, 3.6), "enuma": (3.0, 5.0)}  # fixed: the volleys, the beam sweep; the cost event is the window's start
HITS = {"gates": 1.6, "enuma": 3.0}  # RECOIL starts here (shields' event is a status, not a hit)
# One row per segment between stops (keys, then idle key 0 at the move's end when the last key is earlier). Proposed.
PLAN = {
	"gates": (
		{"ease": ease(2.0)},  # 0 -> 0.4 anticipation: the arms unfold
		{"ease": ease(2.0)},  # 0.4 -> 0.8 the hand lifts, portals open
		{"ease": ease(2.2)},  # 0.8 -> 1.2 slow wind-up
		{"ease": ein(2.4)},  # 1.2 -> 1.6 fast into the volleys (the hit snap)
		{"ease": eout(1.8), "hold": 0.04},  # 1.6 -> 1.85 hard stop, then the thrust carries through
		{"ease": ease(1.8), "carry": 0.06},  # 1.85 -> 2.5 the burst: commanding the volleys
		{"ease": ease(1.8)},  # 2.5 -> 3.1
		{"ease": ease(2.0)},  # 3.1 -> 3.6 the last volley
		{"ease": ease(2.2), "carry": 0.05},  # 3.6 -> 4.4 slow recovery into idle key 0
	),
	"enuma": (
		{"ease": ease(1.8)},  # 0 -> 0.45 anticipation: unfolds and curls down
		{"ease": eout(1.8)},  # 0.45 -> 0.95 Ea flung up fast, slowing into the overshoot
		{"ease": ease(2.0), "carry": 0.08},  # 0.95 -> 1.45 settles back upright, the fling carried a little past the top
		{"ease": ease(1.8)},  # 1.45 -> 2.1 the charge strains
		{"ease": ease(2.2)},  # 2.1 -> 2.75 slow wind-up
		{"ease": ein(2.6)},  # 2.75 -> 3.0 the swing: fast into the hit (the hit snap)
		{"ease": eout(1.6), "hold": 0.05},  # 3.0 -> 3.9 hard stop on the hit, then the beam drive
		{"ease": ease(1.8)},  # 3.9 -> 4.85 the sweep to the far side
		{"ease": ease(2.2), "carry": 0.05},  # 4.85 -> 5.6 slow recovery into idle key 0
	),
	"shields": (
		{"ease": ease(2.0)},  # 0 -> 0.3 anticipation
		{"ease": ease(2.0)},
		{"ease": ease(2.0)},
		{"ease": ease(2.0), "carry": 0.05},
		{"ease": ease(2.0)},
		{"ease": ease(1.5)},  # 1.5 -> 1.8 the left arm's big sweep: a softer ease keeps it under 12 degrees a frame
		{"ease": ein(2.0)},  # 1.8 -> 2.2 into the Fortified gesture
		{"ease": eout(1.8), "hold": 0.03},  # 2.2 -> 2.4 held, then settles
		{"ease": ease(2.0)},  # 2.4 -> 2.6 into idle key 0
	),
}
IDLE_PLAN = {"ease": ease(2.0)}  # between the breathing keys and back to key 0
LEAD_PLAN = bm.LEAD_PLAN
LAG = {"Torso": 1 / 60, "Head": 2 / 60}  # s behind the limbs mid-segment, back on time at every key
# Springs (part:axis, drivers {channel: weight}, gain, omega, zeta) as the mage's FOLLOW. Channels: "<part>:<axis>" the part's own
# turn in degrees (its rotation vector summed frame to frame, so no Euler wrap), "rootx/y/z" model units.
FOLLOW = (
	("Key:0", {"Torso:0": 1, "Body:0": 1, "rooty": -40}, 0.5, 9, 0.3),
	("Head:0", {"Torso:0": 1}, 0.45, 13, 0.34),
	("Head:2", {"Torso:2": 1, "Body:2": 1}, 0.4, 12, 0.34),
	("LeftLowerArm:0", {"LeftUpperArm:0": 1}, 0.45, 11, 0.32),
	("RightLowerArm:0", {"RightUpperArm:0": 1}, 0.25, 13, 0.36),
	("Ea:0", {"RightUpperArm:0": 1, "RightLowerArm:0": 1}, 0.3, 12, 0.35),
	("Ea:2", {"RightUpperArm:2": 1}, 0.25, 12, 0.35),
)
TREMBLE = {"enuma": (1.45, 2.75, 0.8, {"Torso:0": 1, "Head:0": 0.7, "LeftUpperArm:0": 0.6, "RightUpperArm:0": 0.6})}  # the charge
RECOIL = tuple((("Torso" if p == "UpperTorso" else p), axis, deg, hz) for p, axis, deg, hz in raga.RECOIL if p in ("UpperTorso", "Head"))
DRUMS = ("Ea_Drum1", "Ea_Drum2", "Ea_Drum3")
DRUM_SIGN = {"Ea_Drum1": 1, "Ea_Drum2": -1, "Ea_Drum3": 1}
PARTS = kk.JPARTS + ("Key", "Ea") + DRUMS  # the 15 bind parts
KEYED = kk.JPARTS + ("Key", "Ea")  # the drums come from Spin
FOLDED = ("Torso", "LeftUpperLeg", "RightUpperLeg")  # Body folds into these
THIGHS = ("LeftUpperLeg", "RightUpperLeg")
LOCS = THIGHS + ("Ea",)  # joints that move on their parent: the hips round Body's turn, Ea's grip on the forearm
MESH = {**{p: p + "_merged" for p in kk.JPARTS}, "Key": "Key", "Ea": "Ea_Grip", **{d: d for d in DRUMS}}
GRIP0 = tuple(kk.HAND["RightArm"] - kk.EA_PIVOT)  # Ea's grip in the right fist (keys.json's in-hand ea_grip_offset)


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
	"""Degrees between two XYZ Euler rotations (degrees), as boss_king_anim's rotationApart."""
	return math.degrees(2 * math.asin(min(1.0, np.linalg.norm(matrix64(a) - matrix64(b)) / (2 * math.sqrt(2)))))


# ---- a key as plain state ----


def state(key):
	"""rot: local quaternion per keyed part and Body; euler: the key's own numbers (verbatim); root, grip (Ea's grip offset in the
	right forearm's space) and spin as the key holds them."""
	rot = key["rotations"]
	euler = {p: [float(v) for v in rot.get(p, (0, 0, 0))] for p in ("Body",) + KEYED}  # Ea absent while it is hidden: 0
	return {
		"t": float(key["t"]),
		"euler": euler,
		"rot": {p: quat(v) for p, v in euler.items()},
		"root": Vector(key["root_offset"]),
		"root_offset": tuple(float(v) for v in key["root_offset"]),  # verbatim (Vector is float32)
		"grip": Vector(key.get("ea_grip_offset") or GRIP0),
		"spin": float(key.get("ea_drum_spin", 0)),
	}


def track(stops, segments):
	"""The pose at t through every stop: slerp per part on the segment's easing (hold, carry and anticipate as bake_boss_mage.track),
	Torso and Head on a lagged clock that is back on time at both ends of the segment."""
	times = [s["t"] for s in stops]
	assert len(segments) == len(stops) - 1
	for t0, t1 in zip(times, times[1:]):
		assert max(LAG.values()) * math.pi / (t1 - t0) < 1, "a lag that would run the clock backwards"

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
			s, c = weights(i, t - LAG.get(p, 0) * math.sin(math.pi * frac))
			q = a["rot"][p] @ power(delta(a["rot"][p], b["rot"][p]), s)
			if c:
				q = q @ power(delta(stops[i - 1]["rot"][p], a["rot"][p]), c)
			rot[p] = q
		s, c = weights(i, t)
		out = {"rot": rot, "spin": float(np.interp(t, times, [x["spin"] for x in stops]))}  # the drums turn at a steady rate
		for k in ("root", "grip"):
			out[k] = a[k].lerp(b[k], s) + ((a[k] - stops[i - 1][k]) * c if c else Vector())
		return out

	return at


def pinned(grid, curve, knots):
	"""curve less a smooth curve through its values at the knots: 0 at every key, as bake_boss_mage.secondary's."""
	knots = np.array(sorted(set(knots)))
	i = np.clip(np.searchsorted(knots, grid, side="right") - 1, 0, len(knots) - 2)
	u = (grid - knots[i]) / (knots[i + 1] - knots[i])
	at = np.interp(knots, grid, curve)
	return curve - (at[i] + (at[i + 1] - at[i]) * u * u * (3 - 2 * u))


# ---- the bind from the model ----


def king_bind(data, scale):
	"""His parts as the client wants them: a part's joint is its rework keys.json pivot; Ea's (the grip, with its drums) sits in the
	right fist, pivot + the in-hand grip. The Ea empty carries its meshes, so their rest origin is the empty's place."""
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	assert sorted(objs) == sorted(MESH.values()), sorted(objs)
	pivots = {p: Vector(v) for p, v in data["pivots"].items()}
	for d in DRUMS:
		pivots[d] = pivots["Ea"]
	grips = {tuple(round(v, 3) + 0 for v in k["ea_grip_offset"]) for k in data["moves"]["enuma"]["keys"]}
	assert tuple(round(v, 3) + 0 for v in GRIP0) in grips, grips
	parents = {p: data["parents"][p] for p in PARTS}
	parents.update({p: None for p in FOLDED})
	joint = {p: pivots[p] + (Vector(GRIP0) if p in ("Ea",) + DRUMS else Vector()) for p in PARTS}
	bind = {}
	for p in PARTS:
		o = objs[MESH[p]]
		co = bm.local_verts(o)
		lo, hi = co.min(axis=0), co.max(axis=0)
		mesh_origin = Vector(o.matrix_world.translation) - pivots[p]  # a vertex sits at pivot + this + co before posing
		parent = parents[p]
		bind[p] = {
			"Parent": parent,
			"Offset": tuple(joint[p] - (joint[parent] if parent else Vector())),
			"Center": tuple(mesh_origin + Vector((lo + hi) / 2)),
			"Size": tuple(((hi - lo) * scale)[[0, 2, 1]]),
		}
		if p == "Ea_Drum3":  # the pillar's chisel tip, from the grip joint: where the beam leaves
			bind["Ea"]["Tip"] = tuple(mesh_origin + Vector(co[co[:, 2] > co[:, 2].max() - 0.3].mean(axis=0)))
	return bind, objs, pivots


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


# ---- frames ----


class King:
	def __init__(self, rework, bind, pivots):
		self.moves, self.bind, self.pivots = rework["moves"], bind, pivots
		self.idle0 = state(self.moves["idle"]["keys"][0])
		self.verbatim = {"shifted": 0, "rewritten": []}  # key components moved by whole turns, keys written on another Euler branch

	def pose(self, st):
		"""Body folded in: quaternion per keyed part, the LOCS joints (model units from their parent's joint)."""
		rb = st["rot"]["Body"]
		rot = {p: st["rot"][p] for p in KEYED}
		for p in FOLDED:
			rot[p] = rb @ st["rot"][p]
		hip = Vector(kk.HIP)
		locs = {p: hip + rb @ (self.pivots[p] - hip) for p in THIGHS}
		locs["Ea"] = self.pivots["Ea"] + st["grip"] - self.pivots["RightLowerArm"]
		return rot, locs

	def frame(self, t, st, prev, key=None):
		"""(t, body, root): body has XYZ Euler degrees per bind part, each the Euler nearest prev's, and "<loc>@" the LOCS joints off
		the bind (units x 100, for thinning). A key's own parts keep its numbers (moved by whole turns to sit next to prev)."""
		rot, locs = self.pose(st)
		body = {}
		for p in KEYED:
			e = rot[p].to_euler("XYZ", Euler([math.radians(v) for v in prev[p]])) if prev else rot[p].to_euler("XYZ")
			e = [math.degrees(v) for v in e]
			if key is not None:
				if p in FOLDED:
					e = [round(v, 3) + 0 for v in e]
				else:
					v = list(key["euler"][p])
					if prev:
						v = [a + 360 * round((b - a) / 360) for a, b in zip(v, e)]
						self.verbatim["shifted"] += sum(a != b for a, b in zip(v, key["euler"][p]))
					if prev is None or max(abs(a - b) for a, b in zip(v, e)) < 1.0:
						e = v
					else:  # the curve arrives on the other Euler branch: the key's rotation, written as the curve has it
						e = [round(x, 3) + 0 for x in e]
						self.verbatim["rewritten"].append((key["t"], p))
					assert apart(e, key["euler"][p]) < 1e-3, f"{key['t']} {p}: off its key"
			body[p] = tuple(e)
		for d in DRUMS:
			body[d] = (0.0, 0.0, DRUM_SIGN[d] * st["spin"])
		for p in LOCS:
			body[p + "@"] = tuple((a - b) * 100 for a, b in zip(locs[p], self.bind[p]["Offset"]))
		return (float(t), body, key["root_offset"] if key is not None else tuple(st["root"]))

	def bake(self, name, stops, segments, duration, knots, approved=()):
		"""Sampled at RATE, springs, trembles and recoil added (each back to 0 at every knot), then written as Euler frames."""
		at = track(stops, segments)
		grid = np.linspace(0, duration, int(round(duration * RATE)) + 1)
		for k in knots:  # key times exactly on the grid
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
			c.update({"root" + "xyz"[j]: float(s["root"][j]) for j in range(3)})
			channels.append(c)
		sec = bm.secondary(grid, channels, FOLLOW, [TREMBLE[name]] if name in TREMBLE else [], knots, name)
		if name in HITS:
			for p, axis, degrees, hz in RECOIL:
				tau = np.maximum(grid - HITS[name], 0)
				ch = "%s:%d" % (p, axis)
				sec[ch] = sec.get(ch, 0) + pinned(grid, degrees * np.exp(-6 * tau) * np.sin(2 * math.pi * hz * tau), knots)
		keys = {s["t"]: s for s in stops if s["t"] in approved}
		frames, prev = [], None
		for i, t in enumerate(grid):
			s = samples[i]
			for p in KEYED:
				v = [float(sec["%s:%d" % (p, j)][i]) if "%s:%d" % (p, j) in sec else 0.0 for j in range(3)]
				s["rot"][p] = s["rot"][p] @ turn(v)
			f = self.frame(t, s, prev, keys.get(float(t)))
			frames.append(f)
			prev = f[1]
		return frames

	def attack(self, name):
		move = self.moves[name]
		stops = [state(k) for k in move["keys"]]
		assert stops[0]["t"] == 0
		if stops[-1]["t"] < move["end"]:  # back to idle key 0; the drums never unwind (Ea is hidden at the move's end)
			stops.append(dict(self.idle0, t=float(move["end"]), spin=stops[-1]["spin"]))
		approved = [k["t"] for k in move["keys"]]
		knots = [s["t"] for s in stops]
		frames = self.bake(name, stops, PLAN[name], move["end"], knots, approved)
		raw, at = EVENTS[name]
		hit = next(k["t"] for k in move["keys"] if k.get("event") == raw)
		events = ([{"Time": 0, "Name": at + "_start"}] if name in WINDOW else []) + [{"Time": hit, "Name": at}]
		if name in WINDOW:
			assert hit == WINDOW[name][0], f"{name}: the cost event is not the window's start"
		keep = knots + [t + seg.get("hold", 0) for t, seg in zip(knots, PLAN[name])]
		return frames, approved, events, move["end"], keep

	def lead(self, name, a, b, length):
		stops = [dict(a, t=0.0), dict(b, t=float(length))]
		frames = self.bake(name, stops, LEAD_PLAN, length, [0, length], [0, length])
		return frames, [], [], length, [0, length]

	def idle(self):
		"""The breathing loop: eased through its 3 keys and back to key 0 at the period's end, so it loops without a pop."""
		move = self.moves["idle"]
		keys, period = move["keys"], move["end"]
		assert move["loop"] and keys[0]["t"] == 0 and period == IDLE_ROW and keys[-1]["t"] == period
		assert keys[-1]["rotations"] == keys[0]["rotations"] and keys[-1]["root_offset"] == keys[0]["root_offset"], "idle: last key not the first"
		stops = [state(k) for k in keys]
		knots = [s["t"] for s in stops]
		frames = self.bake("idle", stops, (IDLE_PLAN,) * (len(keys) - 1), period, knots, knots)
		bad = {p: (frames[0][1][p], frames[-1][1][p]) for p in frames[0][1] if max(abs(a - b) for a, b in zip(frames[0][1][p], frames[-1][1][p])) > 1e-3}
		assert not bad, f"idle: the loop's end is not its first key {bad}"
		frames[-1] = (float(period),) + frames[0][1:]  # float32 noise in the hip locs aside, the same frame: written once
		return frames, knots, [], period, knots


# ---- checks ----


def check_bind(king, rework, bind):
	"""The joint chain the client builds reproduces jsolve's key poses for every rework key (and keys.json is still what jsolve makes)."""
	for name, move in rework["moves"].items():
		jkeys = kk.JMOVES[name]["keys"]
		assert [k["t"] for k in jkeys] == [k["t"] for k in move["keys"]], name
		for jkey, approved in zip(jkeys, move["keys"]):
			m, record, grip, _ = kk.jsolve(jkey)
			for p, v in record.items():
				assert apart(v, approved["rotations"][p]) < 1e-3, f"rework keys.json {name} {jkey['t']} {p} is not jsolve's"
			assert (grip is None) == ("ea_grip_offset" not in approved), f"{name} {jkey['t']}: Ea drawn in one and not the other"
			assert grip is None or max(abs(a - b) for a, b in zip(grip, approved["ea_grip_offset"])) < 1e-3
			_, body, root = king.frame(jkey["t"], state(approved), None)
			world = joints(bind, body, root)
			for p in PARTS:
				if p in ("Ea",) + DRUMS:
					if grip is None:  # Ea hidden: jsolve does not place it
						continue
					want = m["Ea"] @ Matrix.Translation(king.pivots["Ea"])
					if p in DRUMS:
						want = want @ Matrix.Rotation(math.radians(DRUM_SIGN[p] * jkey.get("spin", 0)), 4, "Z")
				else:
					want = m[MESH[p]] @ Matrix.Translation(king.pivots[p])
				assert max(abs(a - b) for ra, rb in zip(want, world[p]) for a, b in zip(ra, rb)) < 1e-3, f"bind {p} at rework {name} {jkey['t']}"


def check_continuity(name, frames, events, approved, duration):
	"""boss_king_anim "continuous" in Python: Sample's lerp at 60 Hz, at most LIMIT_DEGREES per part and LIMIT_ROOT root (units) a
	frame, outside the hit snap (the key segment that ends on an event, to SNAP s after it). Also the thinning's largest gap."""
	key_times = list(approved) or [f[0] for f in frames]
	snaps = []
	for e in events:
		before = [k for k in key_times if k < e["Time"] - 1e-6]
		snaps.append((max(before) if before else e["Time"], e["Time"] + SNAP))
	parts = list(PARTS)
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
	assert worst_root <= LIMIT_ROOT, f"{name}: root {worst_root} in a frame"
	assert gaps <= raga.MAX_GAP + 1e-9, f"{name}: a key gap of {gaps} s"
	assert frames[0][0] == 0 and abs(frames[-1][0] - duration) < 1e-9, name


def check_cycle(moves):
	at, hits = 0.0, []
	for row in CYCLE:
		_, _, events, duration, _ = moves[row[0]]
		hits += [at + e["Time"] for e in events if not e["Name"].endswith("_start")]
		at += row[2] if row[0] == "idle" else duration
	gaps = [b - a for a, b in zip(hits, hits[1:] + [hits[0] + at])]
	print(f"BAKE cycle {at:.2f} s, events at {[round(h, 2) for h in hits]}, shortest gap {min(gaps):.2f} s")
	assert min(gaps) >= bm.MIN_HIT_GAP, f"two events {min(gaps)} s apart"
	assert abs(at - CYCLE_SECONDS) < 1e-9, f"cycle {at} s, not {CYCLE_SECONDS}"
	assert {r[0] for r in CYCLE} == set(moves), "a move missing from the cycle"
	for i, row in enumerate(CYCLE):
		if row[0].endswith("_in"):
			assert CYCLE[i + 1][0] == row[0][:-3], "a lead not right before its move"
		elif row[0] != "idle":
			assert CYCLE[i - 1][0] == row[0] + "_in", "an attack not led into"
	return at


def check_verbatim(king, moves):
	"""Every approved key at its time, on the thinned frames, is its keys.json pose (Body folded in for Torso and the thighs)."""
	for name in ("idle", "gates", "enuma", "shields"):
		move = king.moves[name]
		frames = {f[0]: f for f in moves[name][0]}
		assert moves[name][1] == [k["t"] for k in move["keys"]], name
		for k in move["keys"]:
			st = state(k)
			f = frames[float(k["t"])]
			rot, locs = king.pose(st)
			for p in KEYED:
				want = [math.degrees(v) for v in rot[p].to_euler("XYZ")]
				assert apart(f[1][p], want) < 1e-3, f"{name} {k['t']} {p}: off its approved key"
			for d in DRUMS:
				assert f[1][d] == (0.0, 0.0, DRUM_SIGN[d] * st["spin"]), f"{name} {k['t']} {d}"
			for p in LOCS:
				assert max(abs(a - b) for a, b in zip(f[1][p + "@"], (locs[p] - Vector(king.bind[p]["Offset"])) * 100)) < 1e-3, f"{name} {k['t']} {p}: loc"
			assert tuple(f[2]) == tuple(float(v) for v in k["root_offset"]), f"{name} {k['t']}: root"


def check_rig(bind, frames):
	"""ui_boss_king_rig's sanity check on the jointed rig, in Python: at 1.7 s (charge) Ea upright and the right forearm above the upper
	arm, at 3.05 s (the swing) Ea within 30 degrees of level and the forearm below. Ea's axis: Ea_Drum1's centre to Ea_Drum3's."""
	for t, upright in ((1.7, True), (3.05, False)):
		rot, root = raga.lerp_frame(frames, t, list(PARTS) + [p + "@" for p in LOCS])
		world = joints(bind, {p: tuple(v) for p, v in rot.items()}, Vector(root))
		at = {p: world[p] @ Vector(bind[p]["Center"]) for p in ("Ea_Drum1", "Ea_Drum3", "RightUpperArm", "RightLowerArm")}
		ea = (at["Ea_Drum3"] - at["Ea_Drum1"]).normalized().z
		arm = at["RightLowerArm"].z - at["RightUpperArm"].z
		print(f"BAKE rig at {t} s: Ea axis up {ea:.2f}, forearm minus upper arm height {arm:.2f} units")
		assert (ea >= 0.8 and arm > 0) if upright else (abs(ea) <= 0.5 and arm < 0), f"rig at {t} s"


# ---- the Luau file ----

FUNCTIONS = """
local Poses = {}
Poses.Moves = MOVES
Poses.Approved = APPROVED
Poses.Bind = BIND -- each part: Parent, Offset from its parent's joint, Center of its box from its own joint (units), Size (studs)
Poses.Scale = SCALE
Poses.RootStuds = ROOT_STUDS -- studs per keys.json root_offset unit: Keys' Root is already studs
Poses.EaTip = Vector3.new(BIND.Ea.Tip[1], BIND.Ea.Tip[2], BIND.Ea.Tip[3]) -- units from the Ea joint, Blender axes: the pillar's tip

-- The drums are not keyed: Sample turns them by the key's Spin (Ea_Drum1 and Ea_Drum3 +spin, Ea_Drum2 -spin about Ea's z).
local PARTS, OFFSETS = {}, {}
for part, row in BIND do
	if string.sub(part, 1, 7) ~= "Ea_Drum" then
		table.insert(PARTS, part)
	end
	OFFSETS[part] = Vector3.new(row.Offset[1], row.Offset[2], row.Offset[3])
end
-- Joints that move on their parent: the hips round his body's turn, Ea's grip on the forearm (out of the hand at idle key 0).
local LOCS = { "LeftUpperLeg", "RightUpperLeg", "Ea" }

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
	local spin = (a.Spin or 0) + ((b.Spin or 0) - (a.Spin or 0)) * u
	parts.Ea_Drum1 = Vector3.new(0, 0, spin)
	parts.Ea_Drum2 = Vector3.new(0, 0, -spin)
	parts.Ea_Drum3 = parts.Ea_Drum1
	return parts, a.Root:Lerp(b.Root, u), locs
end

-- Whether Ea (the grip and its drums) is drawn at time t of a move: only inside a move's EaShown window; hidden otherwise.
function Poses.EaShown(name, t)
	local shown = MOVES[name].EaShown
	return shown ~= nil and t >= shown[1] and t < shown[2]
end

-- The drums' spin at time t of a move, degrees about Ea's axis (Ea_Drum2 turns the other way).
function Poses.EaSpin(name, t)
	local parts = Poses.Sample(name, t)
	return parts.Ea_Drum1.Z
end
"""


def write_luau(king, bind, moves, scale):
	fmt, vec = raga.fmt, raga.vec
	lines = [
		"--!nonstrict",
		"-- Generated by tools/blender/bake_boss_king.py from assets/characters_avatar/boss_king/keyframes/rework/keys.json. Do not",
		"-- edit by hand. The Golden King's moves on his jointed rig (design doc 4.37",
		'-- "Third boss" and "Animation rework", docs/BOSS_EVENT_SPEC.md "The Golden King"), client-side visuals; the server reads',
		"-- Schedule and Events only. Same shape as BossMagePoses, plus Sample's locs, Keys' Spin, EaShown and EaSpin. Approved keys are",
		"-- at their times (10 a move: enuma owner approved 2026-11-12, idle, gates and shields pre-approved 2026-11-12 night),",
		"-- with Body (his hip turn) folded into Torso and the thighs. Time is seconds, Parts XYZ Euler degrees, Root STUDS, Locs model",
		"-- units. Proposed: every in-between.",
		'local Event = require(game:GetService("ReplicatedStorage").Shared.BossEventConfig)',
		"",
		"local SCALE = %s -- studs per model unit: %s x a %s-stud character, %s studs tall" % (fmt(scale, 4), SIZE, fmt(kk.CHAR_H), fmt(SIZE * kk.CHAR_H, 1)),
		"local ROOT_STUDS = SCALE",
		"-- stylua: ignore",
		"local BIND = {",
		*bm.bind_lines(bind, ("Tip",)),
		"}",
		"-- stylua: ignore",
		"local MOVES = {",
	]
	keyed = [p for p in PARTS if p not in DRUMS]
	for name in sorted(moves):
		frames, approved, events, duration, _ = moves[name]
		pinned_t = set(approved) | {0.0, float(duration)}
		moved = [p for p in keyed if any(max(abs(a - b) for a, b in zip(f[1][p], frames[0][1][p])) > 1e-3 for f in frames)]
		held = [p for p in keyed if p not in moved]
		shown = name == "enuma"
		locs = [p for p in LOCS if any(abs(v) > 1e-6 for f in frames for v in f[1][p + "@"])]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in approved))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		if name in WINDOW:
			lines.append("\t\tWindow = { %s }," % ", ".join(fmt(v, 3) for v in WINDOW[name]))
		if shown:
			lines.append("\t\tEaShown = { 0, %s }," % fmt(duration, 3))
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned_t else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			extra = ",Spin=%s" % fmt(f[1]["Ea_Drum1"][2], 2) if shown else ""
			if locs:
				extra += ",Locs={%s}" % ",".join("%s=%s" % (p, vec([a + b / 100 for a, b in zip(bind[p]["Offset"], f[1][p + "@"])], 4)) for p in locs)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}%s}," % (fmt(f[0], 4), vec([v * scale for v in f[2]], 4), body, extra))
		lines += ["\t\t},", "\t},"]
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name in ("idle", "gates", "enuma", "shields"):
		move = king.moves[name]
		frames = {f[0]: f for f in moves[name][0]}
		lines.append("\t%s = {" % name)
		for k in move["keys"]:
			f = frames[float(k["t"])]
			assert all(float(fmt(v, 4)) == v for v in k["root_offset"]), f"{name} {k['t']}: a root would not print verbatim"
			body = ",".join("%s=%s" % (p, vec(f[1][p], 3)) for p in PARTS)
			lines.append("\t\t{Time=%s,RootOffset=%s,Parts={%s}}," % (fmt(k["t"], 3), vec(k["root_offset"], 4), body))
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local CYCLE = {"]
	for row in CYCLE:
		lines.append("\t{%s}," % ", ".join('"%s"' % v if isinstance(v, str) else fmt(v) for v in row))
	lines.append("}")
	tail = raga.FUNCTIONS[raga.FUNCTIONS.index("local cycleLength = 0") :]  # Schedule, RiseAt, return: as the raga's and the mage's
	text = "\n".join(lines) + "\n" + FUNCTIONS + "\n" + tail
	with open(LUAU, "w") as f:
		f.write(text)
	print(f"BAKE wrote {LUAU}: {len(text)} bytes ({len(text) / 1024:.1f} KB, was 104 KB), {sum(len(m[0]) for m in moves.values())} keys, " + ", ".join(f"{n} {len(moves[n][0])}" for n in sorted(moves)))


def fold_materials(objs):
	"""One material a mesh: the Ea ribbons (slot 1, Ea_Glow) are already painted red in the atlas; only the render's glow is lost."""
	for o in objs.values():
		if len(o.data.materials) > 1:
			o.data.polygons.foreach_set("material_index", [0] * len(o.data.polygons))
			while len(o.data.materials) > 1:
				o.data.materials.pop(index=len(o.data.materials) - 1)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	wanted = [a for a in argv if a in ("poses", "glb")] or ["poses", "glb"]
	with open(REWORK) as f:
		rework = json.load(f)
	scale = SIZE * kk.CHAR_H / rework["scale"]["model_height_units"]
	assert abs(scale - rework["scale"]["studs_per_model_unit_at_8x"]) < 1e-3
	assert [k["t"] for k in rework["moves"]["enuma"]["keys"]] == [0, 0.45, 0.95, 1.45, 2.1, 2.75, 3.0, 3.9, 4.85, 5.6]
	assert rework["moves"]["enuma"]["end"] == 5.6 and all(k["ea_shown"] for k in rework["moves"]["enuma"]["keys"])
	for name in ("idle", "gates", "shields"):
		assert not any(k["ea_shown"] for k in rework["moves"][name]["keys"]), name
	assert rework["moves"]["gates"]["strike_window"] == list(WINDOW["gates"])

	bpy.ops.wm.open_mainfile(filepath=BLEND)
	bind, objs, pivots = king_bind(rework, scale)
	king = King(rework, bind, pivots)
	check_bind(king, rework, bind)
	print(f"BAKE bind: the client chain reproduces jsolve for every rework key ({', '.join(rework['moves'])})")
	if "glb" in wanted:
		fold_materials(objs)
		for o in list(bpy.data.objects):
			if o.type != "MESH":
				bpy.data.objects.remove(o)  # the Ea empty first: the grip mesh takes its name
		parts = {p: objs[MESH[p]] for p in PARTS}
		for p, o in parts.items():
			o.name = o.data.name = p
		raga.write_glb(parts, GLB)

	if "poses" in wanted:
		moves = {"idle": king.idle()}
		for name in PLAN:
			moves[name] = king.attack(name)
			moves[name + "_in"] = king.lead(name + "_in", king.idle0, state(rework["moves"][name]["keys"][0]), LEAD)
		thin_parts = list(PARTS) + [p + "@" for p in LOCS]
		for name, (frames, approved, events, duration, keep) in list(moves.items()):
			thinned = raga.thin(frames, thin_parts, keep)
			check_continuity(name, thinned, events, approved, duration)
			assert all(0 <= e["Time"] < duration for e in events), name
			moves[name] = (thinned, approved, events, duration, keep)
		check_verbatim(king, moves)
		check_rig(bind, moves["enuma"][0])
		print(f"BAKE verbatim: {king.verbatim['shifted']} key Euler components moved by whole turns, other-branch keys {king.verbatim['rewritten']}")
		cycle_s = check_cycle(moves)
		for name, (frames, *_rest) in moves.items():
			assert all(set(f[1]) == set(thin_parts) for f in frames), f"{name}: a part without keys"
		assert [e["Name"] for e in moves["gates"][2]] == ["gates_start", "gates"] and moves["gates"][2][1]["Time"] == 1.6
		assert [e["Name"] for e in moves["enuma"][2]] == ["enuma_start", "enuma"] and moves["enuma"][2][1]["Time"] == 3.0
		assert [(e["Name"], e["Time"]) for e in moves["shields"][2]] == [("shields", 2.2)]
		assert [len(moves[n][1]) for n in ("idle", "gates", "enuma", "shields")] == [10, 10, 10, 10]
		assert [moves[n][3] for n in ("idle", "gates", "enuma", "shields")] == [4.0, 4.4, 5.6, 2.6]
		print(f"BAKE scale {scale:.4f} studs/unit, cycle {cycle_s:.3f} s")
		write_luau(king, bind, moves, scale)
		print("BAKE self-check passed")


if __name__ == "__main__":
	main()
