# The Golden King's in-betweens and game model (design doc 4.37 "Third boss", BOSS_EVENT_SPEC "The Golden King").
#   Blender -b --factory-startup --python tools/blender/bake_boss_king.py -- [poses] [glb]
# poses   writes src/late/BossKingPoses.luau: the owner-approved keys of keyframes/keys.json (pre-approved 2026-11-11) at their
#         times, everything between them generated here, then self-checked (asserts). Same public shape as BossMagePoses, plus
#         Sample's third value (locs), Keys' Spin, Moves' EaShown and Poses.EaShown / Poses.EaSpin. Run stylua after.
# glb     writes build/avatar_glb/boss_king.glb: 11 parts (Torso, Head, arms, legs, Key, Ea = the grip, Ea_Drum1-3), unposed, no
#         hierarchy, each centred on its bounding box (bake_boss_raga.write_glb), so a part's CFrame is joint * Center. The Ea glow
#         ribbons' second material is folded into the palette material (one material a mesh). Upload with upload_avatar.py.
# Body (his hip turn, up to 144 degrees in the beam sweep) is no part: it is folded into Torso's and the legs' rotations, and the
# leg joints it carries round the hip go out as Keys' Locs (model units), which Sample returns as its third value for BossRaga:Pose.
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_boss_mage as bm  # noqa: E402  (guarded main: track, secondary, check, local_verts, bind_lines)
import bake_boss_raga as raga  # noqa: E402  (guarded main: easing, thinning, number format, write_glb)
import boss_king_keyframes as kk  # noqa: E402  (guarded main: the key pose solver and the stage constants)
import boss_mage_keyframes as mk  # noqa: E402  (guarded main: eul / degs, the Euler convention of keys.json)

ease, eout, ein = raga.inout, raga.eout, raga.ein

ROOT = os.path.dirname(os.path.dirname(HERE))
KEYS = os.path.join(ROOT, "assets", "characters_avatar", "boss_king", "keyframes", "keys.json")
BLEND = os.path.join(ROOT, "assets", "characters_avatar", "boss_king", "boss_king.blend")
GLB = os.path.join(ROOT, "build", "avatar_glb", "boss_king.glb")
LUAU = os.path.join(ROOT, "src", "late", "BossKingPoses.luau")

SIZE = 8  # his height in runner heights (spec, proposed)
RATE, SNAP = bm.RATE, bm.SNAP
LEAD = 0.75  # proposed (the stub's): idle key 0 into each move's first key
IDLE_ROW = 4.0  # s of the idle loop a cycle row plays: its whole period, so it never pops
# Proposed. Rows as BossMagePoses: { "idle", from, seconds } or { move }. The server's expectations (BossEventService, BossCatalog):
# the events gates_start / gates, enuma_start / enuma, shields and the lead-ins before each move.
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
EVENTS = {"gates": ("Volleys", "gates"), "enuma": ("Beam", "enuma"), "shields": ("Fortified", "shields")}
WINDOW = {"gates": (1.6, 3.6), "enuma": (3.0, 5.0)}  # the volleys, the beam sweep: the cost event is the window's start
# One row per segment between stops (approved keys, then idle key 0 at the move's end); as bake_boss_mage.PLAN.
PLAN = {
	"gates": (
		{"ease": ease(2.0)},  # the hand lifts, first ripples
		{"ease": ein(2.2)},  # portals open, then the thrust lands on the Fire key
		{"ease": ease(1.8), "carry": 0.08},  # the volley burst: torso sways with the arm
		{"ease": ease(1.8), "carry": 0.05},
		{"ease": ease(2.0), "carry": 0.06},  # recover
		{"ease": ease(2.0)},
	),
	"enuma": (
		{"ease": ease(2.0)},  # Ea drawn, raised to the sky
		{"ease": ease(1.8)},  # the charge builds
		{"ease": ease(1.8)},
		{"ease": ein(1.6)},  # the swing: Ea comes down, the beam leaves at 3.0
		{"ease": ease(1.6)},  # the sweep across the lanes
		{"ease": ease(1.6)},  # the far side of the ring
		{"ease": ease(2.0), "carry": 0.06},  # Ea lowered
		{"ease": ease(2.0)},
	),
	"shields": (
		{"ease": ease(2.0)},
		{"ease": ease(2.0), "carry": 0.06},
		{"ease": ease(2.0), "carry": 0.06},
		{"ease": ease(2.0)},
	),
}
IDLE_PLAN = {"ease": ease(2.0)}  # between the breathing keys and back to key 0
# The Key swings at his belt behind the torso's pitch and his lunges (part axis, drivers, gain, omega, zeta), as the mage's FOLLOW.
FOLLOW = (("Key:0", {"Torso:0": 1, "rooty": -40}, 0.5, 9, 0.3),)
TREMBLE = {"enuma": (1.8, 3.0, 0.8, {"Torso:0": 1, "Head:0": 0.7, "LeftArm:0": 0.6, "RightArm:0": 0.6})}  # the held charge
DRUMS = ("Ea_Drum1", "Ea_Drum2", "Ea_Drum3")
DRUM_SIGN = {"Ea_Drum1": 1, "Ea_Drum2": -1, "Ea_Drum3": 1}
LEGS = ("LeftLeg", "RightLeg")
MESH = {"Torso": "Torso_merged", "Head": "Head_merged", "LeftArm": "LeftArm_merged", "RightArm": "RightArm_merged", "LeftLeg": "LeftLeg_merged", "RightLeg": "RightLeg_merged", "Key": "Key", "Ea": "Ea_Grip"}


def merged(data):
	"""gates_window folded into gates (its keys sit on the gates clock, its 1.6 and 3.6 keys are gates' own); enuma_beam continues
	enuma_charge on one clock. Merged moves are named gates and enuma, as the server knows them."""
	# fortified_idle (approved) is not baked: the shield ring it shows is BossKingVfx's from BossFortified, its breathing is idle's.
	moves = {n: m for n, m in data["moves"].items() if "extends" not in m and n != "fortified_idle"}
	for name, w in data["moves"].items():
		if "extends" not in w:
			continue
		parent = moves.pop(w["extends"])
		keys = {k["t"]: k for k in parent["keys"]}
		for k in w["keys"]:
			if k["t"] in keys:  # the parent's own key (its event stays)
				assert keys[k["t"]]["rotations"] == k["rotations"] and keys[k["t"]]["root_offset"] == k["root_offset"], f"{name} {k['t']}: not its parent's key"
			else:
				keys[k["t"]] = k
		out = "gates" if w["extends"] == "gates" else "enuma"
		moves[out] = dict(parent, keys=[keys[t] for t in sorted(keys)], end=w["end"], Window=list(WINDOW[out]))
	return dict(data, moves=moves)


def fold(rot):
	"""Body's hip turn folded away: Torso and the legs turn by Body's rotation then their own; the leg joints move round the hip.
	Returns rotations per part (no Body, degrees) and the legs' joints (model units from the root)."""
	rb = mk.eul(rot["Body"])
	hip = Vector(kk.HIP)
	out = {p: list(rot[p]) for p in rot if p != "Body"}
	for p in ("Torso",) + LEGS:
		out[p] = [math.degrees(v) for v in (rb @ mk.eul(rot[p])).to_euler("XYZ")]
	locs = {leg: list(hip + rb.to_3x3() @ (Vector(kk.LEG[leg]) - hip)) for leg in LEGS}
	return out, locs


class King:
	def __init__(self, data):
		self.data = data
		self.pivots = dict(data["pivots"])
		for d in DRUMS:
			self.pivots[d] = self.pivots["Ea"]  # the drums turn about the grip's axis
		self.parts = sorted(p for p in self.pivots if p != "Body")  # the 11 bind parts
		self.channels_of = sorted(set(self.pivots) - set(DRUMS))  # Body folds away, the drums come from Spin
		self.idle0 = data["moves"]["idle"]["keys"][0]

	def channels(self, key):
		c = {"root" + "xyz"[i]: float(v) for i, v in enumerate(key["root_offset"])}
		for p in self.channels_of:
			r = key["rotations"].get(p, [0, 0, 0])  # Ea absent while he fights bare-handed: upright in the fist
			for i in range(3):
				c["%s:%d" % (p, i)] = float(r[i])
		c["spin"] = float(key.get("ea_drum_spin", 0))
		return c

	def frame(self, t, c):
		rot = {p: [c["%s:%d" % (p, i)] for i in range(3)] for p in self.channels_of}
		folded, locs = fold(rot)
		for d in DRUMS:
			folded[d] = [0.0, 0.0, DRUM_SIGN[d] * c["spin"]]
		body = {p: tuple(folded[p]) for p in self.parts}
		for leg in LEGS:
			body[leg + "@"] = tuple((a - b) * 100 for a, b in zip(locs[leg], kk.LEG[leg]))  # thinned to 0.002 units, as the golem's
		return (float(t), body, (c["rootx"], c["rooty"], c["rootz"]))

	def key_frame(self, key):
		"""An approved key as the client sees it: Body folded in, 3 decimals (as printed); the drums from its spin."""
		f = self.frame(key["t"], self.channels(key))
		body = {p: tuple(round(v, 3) + 0 for v in f[1][p]) for p in self.parts}
		for leg in LEGS:
			body[leg + "@"] = tuple(round(v, 2) + 0 for v in f[1][leg + "@"])
		return (float(key["t"]), body, tuple(float(v) for v in key["root_offset"]))

	def sample(self, name, times, values, segments, duration, knots, trembles=()):
		at = bm.track(times, values, segments)
		grid = np.linspace(0, duration, int(round(duration * RATE)) + 1)
		samples = [at(t) for t in grid]
		sec = bm.secondary(grid, samples, FOLLOW, list(trembles), knots, name)
		spin = np.interp(grid, times, [v["spin"] for v in values])  # the drums turn at a steady rate between keys
		frames = []
		for i, t in enumerate(grid):
			c = dict(samples[i])
			for channel, curve in sec.items():
				c[channel] += float(curve[i])
			c["spin"] = float(spin[i])
			frames.append(self.frame(t, c))
		return frames

	def pin(self, frames, keys, name):
		"""Approved keys go in verbatim (folded), after proving the curve runs through them."""
		out = [f for f in frames if all(abs(f[0] - k["t"]) > 1e-6 for k in keys)]
		for k in keys:
			f = min(frames, key=lambda f: abs(f[0] - k["t"]))
			kf = self.key_frame(k)
			assert abs(f[0] - k["t"]) < 1e-9, f"{name} {k['t']}: not on the sample grid"
			for p in f[1]:
				e = max(abs(a - b) for a, b in zip(f[1][p], kf[1][p]))
				assert e < 0.02, f"{name} {k['t']} {p}: the curve is {e} off its approved key"
			assert max(abs(a - b) for a, b in zip(f[2], kf[2])) < 1e-6, f"{name} {k['t']}: root off its approved key"
			out.append(kf)
		return sorted(out, key=lambda f: f[0])

	def attack(self, name):
		move = self.data["moves"][name]
		keys = move["keys"]
		assert keys[0]["t"] == 0
		times = [k["t"] for k in keys] + [move["end"]]
		end = self.channels(self.idle0)
		end["spin"] = self.channels(keys[-1])["spin"]  # the drums never unwind: Ea is hidden at the move's end
		values = [self.channels(k) for k in keys] + [end]
		frames = self.sample(name, times, values, PLAN[name], move["end"], times, [TREMBLE[name]] if name in TREMBLE else ())
		raw, at = EVENTS[name]
		hit = next(k["t"] for k in keys if k.get("event") == raw)
		events = ([{"Time": 0, "Name": at + "_start"}] if "Window" in move else []) + [{"Time": hit, "Name": at}]
		if "Window" in move:
			assert hit == move["Window"][0], f"{name}: the cost event is not the window's start"
		return self.pin(frames, keys, name), [k["t"] for k in keys], events, move["end"], times

	def lead(self, name, a, b, length):
		values = [self.channels(a), self.channels(b)]
		frames = self.sample(name, [0, length], values, bm.LEAD_PLAN, length, [0, length])
		frames[0], frames[-1] = self.frame(0, values[0]), self.frame(length, values[1])
		return frames, [], [], length, [0, length]

	def idle(self):
		"""The breathing loop: eased through its 3 keys and back to key 0 at the period's end, so it loops without a pop."""
		move = self.data["moves"]["idle"]
		keys, period = move["keys"], move["end"]
		assert move["loop"] and keys[0]["t"] == 0 and period == IDLE_ROW
		times = [k["t"] for k in keys] + [period]
		values = [self.channels(k) for k in keys] + [self.channels(keys[0])]
		frames = self.sample("idle", times, values, (IDLE_PLAN,) * len(keys), period, times)
		frames = self.pin(frames[:-1], keys, "idle") + [(period,) + self.key_frame(keys[0])[1:]]  # the loop's end is its first key
		return frames, [k["t"] for k in keys], [], period, times


# ---- the bind from the model ----


def king_bind(king, data, scale):
	"""His parts as the client wants them: a part's joint is its keys.json pivot; Ea's (the grip, with its drums) sits on the fist,
	pivot + ea_grip_offset. The Ea empty carries its meshes, so their rest origin is the empty's place."""
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	assert sorted(objs) == sorted(MESH.get(p, p) for p in king.parts), sorted(objs)
	grips = {tuple(round(v, 3) + 0 for v in k["ea_grip_offset"]) for m in data["moves"].values() for k in m["keys"] if "ea_grip_offset" in k}
	assert len(grips) == 1, grips
	grip = Vector(next(iter(grips)))
	parents = {p: (q if q != "Body" else None) for p, q in data["parents"].items() if p != "Body"}
	joint = {p: Vector(king.pivots[p]) + (grip if p in ("Ea",) + DRUMS else Vector()) for p in king.parts}
	assert max(abs(a - b) for a, b in zip(joint["Ea"], kk.HAND["RightArm"])) < 1e-3, "Ea's joint is not the right fist"
	bind = {}
	for p in king.parts:
		o = objs[MESH.get(p, p)]
		co = bm.local_verts(o)
		lo, hi = co.min(axis=0), co.max(axis=0)
		mesh_origin = Vector(o.matrix_world.translation) - Vector(king.pivots[p])  # a vertex sits at pivot + this + co before posing
		parent = parents[p]
		bind[p] = {
			"Parent": parent,
			"Offset": tuple(joint[p] - (joint[parent] if parent else Vector())),
			"Center": tuple(mesh_origin + Vector((lo + hi) / 2)),
			"Size": tuple(((hi - lo) * scale)[[0, 2, 1]]),
			"Joint": tuple(joint[p]),
		}
		if p == "Ea_Drum3":  # the pillar's chisel tip, from the grip joint: where the beam leaves
			bind["Ea"]["Tip"] = tuple(mesh_origin + Vector(co[co[:, 2] > co[:, 2].max() - 0.3].mean(axis=0)))
	return bind, objs


def joints(bind, body, root):
	"""The client's chain: joint = parent * CFrame(offset) * rotation, the legs' offsets from their Locs."""
	out = {}

	def m(n):
		if n not in out:
			b = bind[n]
			base = m(b["Parent"]) if b["Parent"] else Matrix.Translation(root)
			offset = Vector(kk.LEG[n]) + Vector(body[n + "@"]) / 100 if n in LEGS else Vector(b["Offset"])
			out[n] = base @ Matrix.Translation(offset) @ Euler([math.radians(v) for v in body[n]]).to_matrix().to_4x4()
		return out[n]

	for n in bind:
		m(n)
	return out


def check_bind(king, raw, bind):
	"""The joint chain the client builds (Body folded in) reproduces the approved key poses of boss_king_keyframes.solve exactly."""
	for name, move in raw["moves"].items():
		assert len(kk.MOVES[name]["keys"]) == len(move["keys"]), name
		for key, approved in zip(kk.MOVES[name]["keys"], move["keys"]):
			m, record, grip = kk.solve(key)
			for p, v in record.items():  # keys.json is still what the approved solver makes
				assert max(abs(a - b) for a, b in zip(v, approved["rotations"][p])) < 1e-3, f"keys.json {name} {key['t']} {p} is not the solver's"
			assert ("ea" in key) == approved["ea_shown"] and (grip is None or max(abs(a - b) for a, b in zip(grip, approved["ea_grip_offset"])) < 1e-3)
			_, body, root = king.frame(key["t"], king.channels(approved))
			world = joints(bind, body, root)
			for p in king.parts:
				if p in ("Ea",) + DRUMS:
					if "ea" not in key:
						continue
					want = m["Ea"] @ Matrix.Translation(king.pivots["Ea"])
					if p in DRUMS:
						want = want @ Matrix.Rotation(math.radians(DRUM_SIGN[p] * key.get("spin", 0)), 4, "Z")
				else:
					want = m[MESH[p]] @ Matrix.Translation(king.pivots[p])
				assert max(abs(a - b) for ra, rb in zip(want, world[p]) for a, b in zip(ra, rb)) < 1e-3, f"bind {p} at {name} {key['t']}"


def check_cycle(moves):
	at, hits = 0.0, []
	for row in CYCLE:
		_, _, events, duration, _ = moves[row[0]]
		hits += [at + e["Time"] for e in events if not e["Name"].endswith("_start")]
		at += row[2] if row[0] == "idle" else duration
	gaps = [b - a for a, b in zip(hits, hits[1:] + [hits[0] + at])]
	print(f"BAKE cycle {at:.2f} s, events at {[round(h, 2) for h in hits]}, shortest gap {min(gaps):.2f} s")
	assert min(gaps) >= bm.MIN_HIT_GAP, f"two events {min(gaps)} s apart"
	assert {r[0] for r in CYCLE} == set(moves), "a move missing from the cycle"
	for i, row in enumerate(CYCLE):
		if row[0].endswith("_in"):
			assert CYCLE[i + 1][0] == row[0][:-3], "a lead not right before its move"
		elif row[0] != "idle":
			assert CYCLE[i - 1][0] == row[0] + "_in", "an attack not led into"
	return at


def check_verbatim(king, moves):
	for name, m in king.data["moves"].items():
		frames = {f[0]: f for f in moves[name][0]}
		assert moves[name][1] == [k["t"] for k in m["keys"]], name
		for k in m["keys"]:
			kf = king.key_frame(k)
			assert frames[k["t"]][1] == kf[1] and tuple(frames[k["t"]][2]) == kf[2], f"{name} {k['t']} not verbatim"


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
local LEGS = { "LeftLeg", "RightLeg" }

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
-- locs[part] each joint's offset from its parent's joint in model units (the legs move round the hip when his body turns): pass
-- them to BossRaga:Pose as its locs.
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
	if a.Locs or b.Locs then
		for _, leg in LEGS do
			locs[leg] = (a.Locs and a.Locs[leg] or OFFSETS[leg]):Lerp(b.Locs and b.Locs[leg] or OFFSETS[leg], u)
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
		"-- Generated by tools/blender/bake_boss_king.py from assets/characters_avatar/boss_king/keyframes/keys.json. Do not edit by hand.",
		'-- The Golden King\'s moves (design doc 4.37 "Third boss", docs/BOSS_EVENT_SPEC.md "The Golden King"), client-side visuals; the',
		"-- server reads Schedule and Events only. Same shape as BossMagePoses, plus Sample's locs, Keys' Spin, EaShown and EaSpin.",
		"-- Owner-approved keys (2026-11-11) are verbatim at their times with Body (his hip turn) folded into Torso and the legs, as the",
		"-- client poses them; Time is seconds, Parts XYZ Euler degrees, Root STUDS, Locs model units. gates holds gates_window's keys,",
		"-- enuma is enuma_charge then enuma_beam. Proposed: the %s s leads (<move>_in), CYCLE and every in-between." % fmt(LEAD),
		"local Event = require(script.Parent.BossEventConfig)",
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
	for name in sorted(moves):
		frames, approved, events, duration, _ = moves[name]
		pinned = set(approved)
		keyed = [p for p in king.parts if p not in DRUMS]
		moved = [p for p in keyed if any(max(abs(a - b) for a, b in zip(f[1][p], frames[0][1][p])) > 1e-3 for f in frames)]
		held = [p for p in keyed if p not in moved]
		shown = [k for k in king.data["moves"].get(name, {}).get("keys", []) if k.get("ea_shown")]
		turning = any(any(abs(v) > 1e-6 for leg in LEGS for v in f[1][leg + "@"]) for f in frames)
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in approved))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		if "Window" in king.data["moves"].get(name, {}):
			lines.append("\t\tWindow = { %s }," % ", ".join(fmt(v, 3) for v in king.data["moves"][name]["Window"]))
		if shown:
			assert all(k.get("ea_shown") for k in king.data["moves"][name]["keys"]), f"{name}: Ea shown for part of the move"
			lines.append("\t\tEaShown = { 0, %s }," % fmt(duration, 3))
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			extra = ",Spin=%s" % fmt(f[1]["Ea_Drum1"][2], 2) if shown else ""
			if turning:
				extra += ",Locs={%s}" % ",".join("%s=%s" % (leg, vec([a + b / 100 for a, b in zip(kk.LEG[leg], f[1][leg + "@"])], 4)) for leg in LEGS)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}%s}," % (fmt(f[0], 4), vec([v * scale for v in f[2]], 4), body, extra))
		lines += ["\t\t},", "\t},"]
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name, m in king.data["moves"].items():
		lines.append("\t%s = {" % name)
		for k in m["keys"]:
			kf = king.key_frame(k)
			assert all(float(fmt(v, 4)) == v for v in k["root_offset"]), f"{name} {k['t']}: a root would not print verbatim"
			body = ",".join("%s=%s" % (p, vec(kf[1][p], 3)) for p in king.parts)
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
	print(f"BAKE wrote {LUAU}: {len(text)} bytes, {sum(len(m[0]) for m in moves.values())} keys, " + ", ".join(f"{n} {len(moves[n][0])}" for n in sorted(moves)))


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
	with open(KEYS) as f:
		raw = json.load(f)
	data = merged(raw)
	king = King(data)
	scale = SIZE * kk.CHAR_H / data["scale"]["model_height_units"]
	assert abs(scale - data["scale"]["studs_per_model_unit_at_8x"]) < 1e-3

	bpy.ops.wm.open_mainfile(filepath=BLEND)
	bind, objs = king_bind(king, raw, scale)
	check_bind(king, raw, bind)
	if "glb" in wanted:
		fold_materials(objs)
		for o in list(bpy.data.objects):
			if o.type != "MESH":
				bpy.data.objects.remove(o)  # the Ea empty first: the grip mesh takes its name
		parts = {p: objs[MESH.get(p, p)] for p in king.parts}
		for p, o in parts.items():
			o.name = o.data.name = p
		raga.write_glb(parts, GLB)

	if "poses" in wanted:
		moves = {"idle": king.idle()}
		for name in PLAN:
			moves[name] = king.attack(name)
			moves[name + "_in"] = king.lead(name + "_in", king.idle0, data["moves"][name]["keys"][0], LEAD)
		thin_parts = king.parts + [leg + "@" for leg in LEGS]
		for name, (frames, approved, events, duration, keep) in list(moves.items()):
			thinned = raga.thin(frames, thin_parts, keep)
			hits = [e["Time"] for e in events if not e["Name"].endswith("_start")]
			bm.check(name, thinned, king.parts, hits, duration)
			assert all(0 <= e["Time"] < duration for e in events), name
			moves[name] = (thinned, approved, events, duration, keep)
		check_verbatim(king, moves)
		cycle_s = check_cycle(moves)
		for name, (frames, *_rest) in moves.items():
			assert all(set(f[1]) == set(thin_parts) for f in frames), f"{name}: a part without keys"
		assert [e["Name"] for e in moves["gates"][2]] == ["gates_start", "gates"] and moves["gates"][2][1]["Time"] == 1.6
		assert [e["Name"] for e in moves["enuma"][2]] == ["enuma_start", "enuma"] and moves["enuma"][2][1]["Time"] == 3.0
		assert [(e["Name"], e["Time"]) for e in moves["shields"][2]] == [("shields", 2.2)]
		assert [len(data["moves"][n]["keys"]) for n in ("idle", "gates", "enuma", "shields")] == [3, 6, 8, 4]
		print(f"BAKE scale {scale:.4f} studs/unit, cycle {cycle_s:.3f} s")
		write_luau(king, bind, moves, scale)
		print("BAKE self-check passed")


if __name__ == "__main__":
	main()
