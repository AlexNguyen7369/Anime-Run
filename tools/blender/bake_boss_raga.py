# Big Raga's in-betweens and its game model (design doc 4.37, BOSS_EVENT_SPEC "Boss and attacks"; owner 2026-11-05: very dynamic).
#   Blender -b --factory-startup --python tools/blender/bake_boss_raga.py -- --blend <boss_raga.blend> [poses] [glb] [images]
# poses   writes src/late/BossRagaPoses.luau: approved keys of keyframes/keys.json verbatim at their times, everything between
#         them generated here, then self-checked against the limits of src/server/CarTest/BossAnimTests.luau. Run stylua on it after.
# glb     writes build/avatar_glb/boss_raga.glb: the 18 parts unposed with no hierarchy, each centred on its bounding box, as
#         avatar_merge does for runners, so a part's CFrame is simply joint * Center. Upload with upload_avatar.py.
# images  writes assets/characters_avatar/boss_raga/flat/{front,side}.png, the low-graphics billboard (spec "Arena").
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
import boss_keyframes  # noqa: E402
import build_avatar  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
KEYS = os.path.join(ROOT, "assets", "characters_avatar", "boss_raga", "keyframes", "keys.json")
LUAU = os.path.join(ROOT, "src", "late", "BossRagaPoses.luau")
GLB = os.path.join(ROOT, "build", "avatar_glb", "boss_raga.glb")
FLAT = os.path.join(ROOT, "assets", "characters_avatar", "boss_raga", "flat")

SCALE = 87.1  # studs per model unit: wheel top 804 (owner value in the brief)
RATE = 120  # samples a second before thinning
MAX_GAP = 1 / 15  # s between baked keys at most
TOLERANCE, ROOT_TOLERANCE = 0.2, 0.002  # degrees and units a thinned key may be off the curve
LEGS = ("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot")
LIMIT_DEGREES, LIMIT_OFFSET, IMPACT_WINDOW = 12, 0.05, 0.05  # BossAnimTests
MAX_PART_STUDS = 2048  # a part's largest size
IDLE_SECONDS, IDLE_BEAT = 12, 2  # idle is exactly rest on every beat, so that it can hand over to a move there
# The Schedule, in order, from the moment the rise ends. Short idles, moves often: every move comes back within 40 s.
# idle = { seconds of idle from, seconds long }. The first idle's calm 4 s let the rise's dust clear.
CYCLE = (
	("idle", 0, 4),
	("attack",),
	("idle", 4, 2),
	("wheel_turn",),
	("idle", 6, 2),
	("shout",),
	("idle", 8, 4),
	("attack",),
	("idle", 2, 2),
	("wheel_turn",),
	("idle", 10, 2),
	("attack",),
	("idle", 4, 2),
	("shout",),
)


def bump(u):
	"""0 at both ends, leaving fast at u = 0 with an early peak of about 0.4: a carried overshoot, decaying."""
	return math.sin(math.pi * u) * (1 - u) ** 1.5


def ein(p):
	return lambda u: u**p


def eout(p):
	return lambda u: 1 - (1 - u) ** p


def inout(p):
	return lambda u: 0.5 * (2 * u) ** p if u < 0.5 else 1 - 0.5 * (2 * (1 - u)) ** p


# One row per segment between keys, rest at 0 and at the end included:
#   ease   how it travels; hold   seconds stopped at its start (hit stop); carry   overshoot past its first key, as a share of the
#   segment before; lift   { side, height in units, power }: the foot leaves the floor and slams back at the segment's end.
# tremble: (from, to, degrees, { part: axis }): held tension as a fast shiver. Events: one each, at the approved moment.
PLAN = {
	"attack": {
		"segments": (
			{"ease": inout(2.4)},
			{"ease": eout(3.2), "carry": 0.1},  # most of the climb early, then it strains at the top
			{"ease": ein(6), "lift": ("Right", 0.3, 3)},  # the snap: nearly all of it in the last 0.1 s
			{"ease": eout(3), "hold": 0.08, "carry": 0.0},  # hit stop on the strike, then the blade bites
			{"ease": inout(3), "hold": 0.16},  # stuck, then yanked out
			{"ease": inout(2.2), "carry": 0.14},
		),
		"tremble": ((0.95, 1.5, 1.6, {"RightUpperArm": 0, "UpperTorso": 2, "RightLowerArm": 1}),),
		"events": {"Impact": 1.75},
		"recoil": 1.75,
	},
	"shout": {
		"segments": (
			{"ease": inout(2.6)},
			{"ease": ein(3), "hold": 0.08, "lift": ("Left", 0.2, 3)},  # coils, then the stamp at 1 s
			{"ease": eout(4.5), "carry": 0.28},  # thrown open
			{"ease": ein(3.2), "carry": 0.12},  # held at the peak, then falls away
			{"ease": inout(2.2), "carry": 0.1},
		),
		"tremble": ((0.2, 0.55, 1.0, {"UpperTorso": 0}), (1.2, 2.4, 2.2, {"Head": 0, "UpperTorso": 2, "RightUpperArm": 1, "LeftUpperArm": 1})),
		"events": {"Roar": 1.05},
		"recoil": 1.0,
	},
	"wheel_turn": {
		"segments": (
			{"ease": inout(2.2)},
			{"ease": ein(2)},
			{"ease": ein(3)},
			{"ease": eout(3), "hold": 0.05},  # the click holds, then the spoke falls back into place
			{"ease": inout(2.2)},
		),
		"tremble": ((0.72, 1.0, 1.4, {"Head": 2, "UpperTorso": 1}),),
		"events": {"WheelClick": 0.7},
		"recoil": 0.7,
	},
}

# Secondary motion, all of it lag behind a driver. (part, axis, drivers, gain, omega, zeta). Drivers are channel names and weights;
# omega and zeta are the spring's: under-damped, so it overshoots and settles after the body has stopped.
FOLLOW = (
	("Tail", 0, (("tilt0", 1.0), ("rootz", 90)), 2.0, 8, 0.28),
	("Tail", 2, (("tilt2", 1.0), ("UpperTorso2", 0.6)), 2.2, 7, 0.26),
	("Tail", 1, (("tilt1", 1.0),), 1.8, 9, 0.3),
	("Wheel", 0, (("tilt0", 1.0), ("UpperTorso0", 1.0), ("Head0", 1.0)), 0.9, 10, 0.24),
	("Wheel", 2, (("tilt2", 1.0), ("UpperTorso2", 1.0), ("Head2", 1.0)), 0.7, 9, 0.24),
	("Head", 0, (("tilt0", 1.0), ("UpperTorso0", 1.0)), 0.45, 13, 0.34),
	("Head", 2, (("tilt2", 1.0), ("UpperTorso2", 1.0)), 0.4, 12, 0.34),
	("UpperTorso", 0, (("tilt0", 1.0), ("rootz", 40)), 0.25, 12, 0.4),
	("LeftLowerArm", 0, (("LeftUpperArm0", 1.0),), 0.45, 11, 0.32),
	("RightLowerArm", 0, (("RightUpperArm0", 1.0),), 0.25, 13, 0.36),
	("LeftHand", 0, (("LeftLowerArm0", 1.0),), 0.35, 14, 0.36),
)
RECOIL = (("UpperTorso", 0, 3.0, 9), ("Head", 0, 3.5, 7), ("Tail", 0, 5.0, 6), ("Wheel", 2, 3.5, 8))  # part, axis, degrees, Hz


def to_euler(q):
	return tuple(math.degrees(v) for v in q.to_euler("XYZ"))


class Bake:
	def __init__(self, keys_json, objs):
		self.json = keys_json
		self.pivots = {k: tuple(v) for k, v in keys_json["pivots"].items()}
		self.rest = {n: tuple(math.degrees(v) for v in o.rotation_euler) for n, o in objs.items()}
		self.parts = sorted(self.pivots)
		self.free = [p for p in self.parts if p not in LEGS and p not in ("LowerTorso", "Wheel")]

	def channels(self, key):
		"""A key's plain numbers. Wheel is spin and lean, not Euler, so a spin keeps going through its angle."""
		c = {}
		for i, v in enumerate(key.get("root", (0, 0, 0))):
			c["root" + "xyz"[i]] = v
		for i, v in enumerate(key.get("tilt", (0, 0, 0))):
			c["tilt%d" % i] = v
		c["spin"] = key.get("spin", 0)
		for p in self.free:
			r = key.get("parts", {}).get(p, self.rest[p])
			for i in range(3):
				c["%s%d" % (p, i)] = r[i]
		return c

	def legs(self, c, lift):
		"""Solved per sample, so the feet never slide. A straight rest leg leaves no slack: past reach, the hips drop until it fits."""
		root = [c["rootx"], c["rooty"], c["rootz"]]
		tilt = (c["tilt0"], c["tilt1"], c["tilt2"])
		pelvis = Vector(self.pivots["LowerTorso"])
		m = Euler([math.radians(d) for d in tilt]).to_matrix()
		for _ in range(200):
			fits = True
			for side, s in (("Left", 1), ("Right", -1)):
				hip_rest, knee, ankle = (Vector(self.pivots[side + p]) for p in ("UpperLeg", "LowerLeg", "Foot"))
				reach = (hip_rest - knee).length + (knee - ankle).length
				hip = pelvis + Vector(root) + m @ (hip_rest - pelvis)
				foot = Vector((s * 0.7, 0, ankle.z + lift.get(side, 0)))
				fits = fits and (foot - hip).length <= reach + 1e-6
			if fits:
				break
			root[2] -= 0.002
		rot = boss_keyframes.solve_legs({"root": root, "tilt": tilt, "lift": lift}, self.pivots)
		return rot, root

	def assemble(self, c, sec, lift):
		"""Every part's XYZ Euler degrees and the root offset from channels, secondary offsets and foot lifts."""
		legs, root = self.legs(c, lift)
		rot = dict(legs)
		rot["LowerTorso"] = (c["tilt0"], c["tilt1"], c["tilt2"])
		for p in self.free:
			rot[p] = tuple(c["%s%d" % (p, i)] + sec.get((p, i), 0) for i in range(3))
		lean = Quaternion((1, 0, 0), math.radians(self.rest["Wheel"][0]))
		spin = Quaternion((0, 1, 0), math.radians(c["spin"] + sec.get(("Wheel", 1), 0)))
		wobble = Euler((math.radians(sec.get(("Wheel", 0), 0)), 0, math.radians(sec.get(("Wheel", 2), 0)))).to_quaternion()
		rot["Wheel"] = to_euler(wobble @ lean @ spin)
		return rot, tuple(root)

	def curve(self, name):
		"""Key channels over time: [t, channels, foot lift]."""
		move = boss_keyframes.MOVES[name]
		plan = PLAN[name]
		keys = move["keys"]
		first = [] if keys[0]["t"] == 0 else [{"t": 0}]
		last = dict(keys[-1])
		tail = {"t": move["end"], "spin": keys[-1].get("spin", 0)}  # back at rest; a wheel_turn stays one spoke on, which looks the same
		stops = first + keys + [tail]
		assert len(plan["segments"]) == len(stops) - 1, name
		del last
		values = [self.channels(k) for k in stops]
		times = [k["t"] for k in stops]

		def at(t):
			i = max(0, min(len(stops) - 2, np.searchsorted(times, t, side="right") - 1))
			seg = plan["segments"][i]
			hold = seg.get("hold", 0)
			t0, t1 = times[i], times[i + 1]
			u = max(0.0, (t - t0 - hold) / (t1 - t0 - hold))
			u = min(u, 1.0)
			s = seg["ease"](u)
			c = {}
			for k in values[i]:
				c[k] = values[i][k] + (values[i + 1][k] - values[i][k]) * s
				if seg.get("carry") and i > 0:
					c[k] += seg["carry"] * (values[i][k] - values[i - 1][k]) * bump(u)
			lift = {}
			if seg.get("lift"):
				side, height, power = seg["lift"]
				p = min(max((t - t0) / (t1 - t0), 0), 1)
				lift[side] = height * math.sin(math.pi * p**power) ** 2
			return c, lift

		return at, times

	def secondary(self, name, at, times, duration):
		plan = PLAN[name]
		n = int(round(duration * RATE)) + 1
		grid = np.linspace(0, duration, n)
		samples = [at(t)[0] for t in grid]
		out = {}
		dt = duration / (n - 1)
		for part, axis, drivers, gain, omega, zeta in FOLLOW:
			d = np.array([sum(c[k] * w for k, w in drivers) for c in samples])
			x, v = d[0], 0.0
			lag = np.zeros(n)
			for i in range(n):
				for _ in range(4):  # stable well past these springs
					a = omega**2 * (d[i] - x) - 2 * zeta * omega * v
					v += a * dt / 4
					x += v * dt / 4
				lag[i] = x
			key = (part, axis)
			out[key] = out.get(key, 0) + gain * (lag - d)
		if plan.get("recoil") is not None:
			for part, axis, degrees, hz in RECOIL:
				tau = np.maximum(grid - plan["recoil"], 0)
				key = (part, axis)
				out[key] = out.get(key, 0) + degrees * np.exp(-6 * tau) * np.sin(2 * math.pi * hz * tau)
		rng = random.Random(name)
		for t0, t1, degrees, parts in plan.get("tremble", ()):
			env = np.clip((grid - t0) / 0.1, 0, 1) * np.clip((t1 - grid) / 0.1, 0, 1)
			for part, axis in parts.items():
				a, b = rng.uniform(9, 12), rng.uniform(15, 19)
				key = (part, axis)
				out[key] = out.get(key, 0) + degrees * env * (np.sin(2 * math.pi * a * grid) + 0.5 * np.sin(2 * math.pi * b * grid + 1)) / 1.5
		# The secondary must vanish at each approved key: take away a smooth curve through its values there.
		knots = sorted(set(times))
		for key, curve in out.items():
			at_knots = np.interp(knots, grid, curve)
			i = np.clip(np.searchsorted(knots, grid, side="right") - 1, 0, len(knots) - 2)
			u = (grid - np.array(knots)[i]) / (np.array(knots)[i + 1] - np.array(knots)[i])
			smooth = u * u * (3 - 2 * u)
			out[key] = curve - (at_knots[i] + (at_knots[i + 1] - at_knots[i]) * smooth)
		return grid, out

	def move(self, name):
		at, times = self.curve(name)
		duration = boss_keyframes.MOVES[name]["end"]
		grid, sec = self.secondary(name, at, times, duration)
		approved = {k["t"]: k for k in self.json["moves"][name]["keys"]}
		frames = []
		for i, t in enumerate(grid):
			c, lift = at(t)
			rot, root = self.assemble(c, {k: float(v[i]) for k, v in sec.items()}, lift)
			frames.append((float(t), rot, root))
		events = PLAN[name]["events"]
		frames = self.pin(frames, approved, name, at)
		return frames, sorted(approved), [{"Time": t, "Name": n} for n, t in events.items()], duration

	def pin(self, frames, approved, name, at):
		"""Approved keys go in verbatim, after proving that the curve runs through them."""
		out = [f for f in frames if all(abs(f[0] - t) > 1e-6 for t in approved)]
		for t, k in approved.items():
			c, lift = at(t)
			assert not lift or max(lift.values()) < 1e-6, f"{name} {t}: a lifted foot on an approved key"
			rot, root = self.assemble(c, {}, {})
			for p in self.parts:
				e = max(abs(a - b) for a, b in zip(rot[p], k["rotations"][p]))
				assert e < 0.02, f"{name} {t} {p}: the curve is {e} degrees off its approved key"
			assert max(abs(a - b) for a, b in zip(root, k["root_offset"])) < 1e-3, f"{name} {t}: root"
			out.append((float(t), {p: tuple(k["rotations"][p]) for p in self.parts}, tuple(k["root_offset"])))
		return sorted(out, key=lambda f: f[0])

	def idle(self):
		"""Heavy breaths and a restless body: rest exactly on every beat (2 s). Calm first 4 s, so the first idle reads as standing."""
		n = IDLE_SECONDS * RATE + 1
		frames = []
		rest = self.channels({})
		for i in range(n):
			t = i / RATE
			breath = math.sin(math.pi * t / IDLE_BEAT) ** 2
			c = dict(rest)
			c["UpperTorso0"] -= 1.6 * breath
			c["Head0"] += 0.8 * breath
			c["rootz"] = -0.018 * breath
			c["LeftUpperArm1"] -= 2.2 * breath
			c["RightUpperArm1"] += 2.2 * breath
			c["LeftLowerArm0"] -= 3 * breath
			c["RightLowerArm0"] -= 2 * breath
			sec = {("Tail", 2): 2.5 * math.sin(math.pi * t / IDLE_BEAT), ("Tail", 0): -2 * breath, ("Wheel", 2): 1.4 * math.sin(math.pi * t)}
			lift = {}

			def window(a, b):
				return math.sin(math.pi * (t - a) / (b - a)) ** 2 if a <= t <= b else 0.0

			# 4-6: looks to his left; 8-10: snaps to his right; 6-8 and 10-12: weight shifts, a foot stamps, the blade arm twitches
			left = window(4, 6)
			c["Head2"] += 34 * left
			c["UpperTorso2"] += 9 * left
			c["tilt2"] += 3 * left
			right = window(8, 10) ** 0.6 if 8 <= t <= 10 else 0.0
			c["Head2"] -= 38 * right
			c["Head0"] += 4 * right
			c["UpperTorso2"] -= 11 * right
			c["tilt2"] -= 3 * right
			shift = window(6, 8)
			c["rootx"] = -0.1 * shift
			c["rootz"] -= 0.05 * shift
			c["tilt1"] = 1.8 * shift
			c["UpperTorso1"] -= 2.2 * shift
			lift["Left"] = 0.14 * window(6.4, 7.6)
			twitch = window(10, 12)
			c["rootx"] += 0.08 * twitch
			c["rootz"] -= 0.04 * twitch
			c["tilt1"] -= 1.4 * twitch
			c["RightUpperArm0"] -= 9 * twitch
			c["RightUpperArm1"] += 8 * twitch
			c["RightLowerArm0"] -= 12 * twitch
			lift["Right"] = 0.1 * window(10.5, 11.5)
			sec[("Wheel", 0)] = 1.6 * math.sin(2 * math.pi * t / IDLE_BEAT)
			rot, root = self.assemble(c, sec, lift)
			frames.append((t, rot, root))
		rest_rot, _ = self.assemble(rest, {}, {})  # the solver's rest, as in keys.json: a straight leg's knee is a hair off 0
		for k in range(0, IDLE_SECONDS + 1, IDLE_BEAT):
			_, rot, root = frames[k * RATE]
			assert max(abs(root[i]) for i in range(3)) < 1e-6, f"idle {k}: root off rest"
			for p in self.parts:
				assert max(abs(a - b) for a, b in zip(rot[p], rest_rot[p])) < 0.01, f"idle {k} {p}: off rest {rot[p]}"
			frames[k * RATE] = (float(k), rest_rot, (0.0, 0.0, 0.0))
		return frames, [], [], IDLE_SECONDS


def vector(frame, parts):
	return np.array([v for p in parts for v in frame[1][p]] + [v * 1000 * TOLERANCE / (ROOT_TOLERANCE * 1000) for v in frame[2]])


def thin(frames, parts, keep):
	"""Drops samples a straight line between neighbours can stand in for. Sample lerps, so this is exactly what the game plays."""
	vs = np.array([vector(f, parts) for f in frames])
	ts = np.array([f[0] for f in frames])
	out = [0]
	i = 0
	n = len(frames)
	while i < n - 1:
		j = i + 1
		while j + 1 < n and ts[j + 1] - ts[i] <= MAX_GAP and not any(ts[i] < k <= ts[j] for k in keep):
			u = ((ts[i + 1 : j + 1] - ts[i]) / (ts[j + 1] - ts[i]))[:, None]
			if np.abs(vs[i] + (vs[j + 1] - vs[i]) * u - vs[i + 1 : j + 1]).max() > TOLERANCE:
				break
			j += 1
		out.append(j)
		i = j
	return [frames[k] for k in out]


def lerp_frame(frames, t, parts):
	ts = [f[0] for f in frames]
	i = min(max(int(np.searchsorted(ts, t, side="right")) - 1, 0), len(frames) - 2)
	a, b = frames[i], frames[i + 1]
	u = min(max((t - a[0]) / (b[0] - a[0]), 0), 1)
	return {p: np.array(a[1][p]) + (np.array(b[1][p]) - np.array(a[1][p])) * u for p in parts}, np.array(a[2]) + (np.array(b[2]) - np.array(a[2])) * u


def check(name, frames, events, duration, parts):
	"""The test's own limits, so a breach shows up here and not in Studio."""
	worst, worst_at, worst_part, worst_root = 0, 0, None, 0
	prev = lerp_frame(frames, 0, parts)
	near = [e["Time"] for e in events if e["Name"] in ("Impact", "WheelClick")]
	for k in range(1, int(duration * 60) + 1):
		t = k / 60
		cur = lerp_frame(frames, t, parts)
		if not any(abs(e - t) <= IMPACT_WINDOW for e in near):
			for p in parts:
				d = float(np.abs(cur[0][p] - prev[0][p]).max())
				if d > worst:
					worst, worst_at, worst_part = d, t, p
			worst_root = max(worst_root, float(np.abs(cur[1] - prev[1]).max()))
		prev = cur
	print(f"BAKE {name}: {len(frames)} keys, worst {worst:.2f} deg/frame at {worst_at:.2f} s on {worst_part}, root {worst_root:.4f}/frame")
	assert worst <= LIMIT_DEGREES, name
	assert worst_root <= LIMIT_OFFSET, name


def bind_data(objs):
	bind = {}
	for name, o in objs.items():
		co = np.empty(len(o.data.vertices) * 3)
		o.data.vertices.foreach_get("co", co)
		co = co.reshape(-1, 3)
		lo, hi = co.min(axis=0), co.max(axis=0)
		size = (hi - lo) * SCALE
		assert size.max() <= MAX_PART_STUDS, f"{name}: {size.max()} studs is over the part limit"
		parent = o.parent.name if o.parent and o.parent.type == "MESH" else None
		bind[name] = {"Parent": parent, "Offset": tuple(o.location), "Center": tuple((lo + hi) / 2), "Size": tuple(size[[0, 2, 1]])}  # Roblox: x, y up, z depth
		if name == "Sword":
			bind[name]["Tip"] = tuple(co[co[:, 2].argmin()])
	return bind


def world_matrix(bind, name, rot, root):
	m = Matrix.Identity(4)
	chain = []
	n = name
	while n:
		chain.append(n)
		n = bind[n]["Parent"]
	for n in reversed(chain):
		e = Euler([math.radians(d) for d in rot[n]]).to_matrix().to_4x4()
		loc = Vector(bind[n]["Offset"]) + (Vector(root) if n == "LowerTorso" else Vector())
		m = m @ Matrix.Translation(loc) @ e
	return m


def fmt(v, places=2):
	s = f"{v:.{places}f}".rstrip("0").rstrip(".")
	return "0" if s in ("-0", "") else s


def vec(values, places=2):
	return "{" + ",".join(fmt(v, places) for v in values) + "}"


FUNCTIONS = """
local Poses = {}
Poses.Moves = MOVES
Poses.Approved = APPROVED
Poses.Bind = BIND -- each part: Parent, Offset from its parent's joint, Center of its box from its own joint (units), Size (studs)
Poses.Scale = SCALE
Poses.ImpactPoint = Vector3.new(IMPACT[1], IMPACT[2], IMPACT[3]) -- model units, Blender axes: the blade tip at Impact

local PARTS = {}
for part in BIND do
	table.insert(PARTS, part)
end

-- Plain numbers to Vector3s, once. A part left out of a move's keys holds one value for the whole move.
for _, move in MOVES do
	for _, key in move.Keys do
		for part, v in key.Parts do
			key.Parts[part] = Vector3.new(v[1], v[2], v[3])
		end
		key.Root = Vector3.new(key.Root[1], key.Root[2], key.Root[3])
	end
	local held = {}
	for part, v in move.Held do
		held[part] = Vector3.new(v[1], v[2], v[3])
	end
	move.Held = held
end

-- The pose of a move at time t, clamped to the move: parts[part] is a Vector3 of XYZ Euler degrees, rootOffset a Vector3 in units.
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
	local parts = {}
	for _, part in PARTS do
		local from = a.Parts[part]
		if from then
			parts[part] = from:Lerp(b.Parts[part], u)
		else
			parts[part] = move.Held[part]
		end
	end
	return parts, a.Root:Lerp(b.Root, u)
end

local cycleLength = 0
local cycle = {}
for _, row in CYCLE do
	local length = row[1] == "idle" and row[3] or MOVES[row[1]].Duration
	table.insert(cycle, { Move = row[1], Start = cycleLength, From = row[1] == "idle" and row[2] or 0, Length = length })
	cycleLength += length
end
Poses.CycleSeconds = cycleLength

-- The move and its local time. startTime is the spawn, the start of the rise; idle until startTime + IntroSeconds. Pure: server
-- time alone decides, so every client plays the same move at the same moment.
function Poses.Schedule(startTime, now)
	local since = now - startTime - Event.IntroSeconds
	if since < 0 then
		return "idle", since % MOVES.idle.Duration
	end
	local at = since % cycleLength
	for _, row in cycle do
		if at < row.Start + row.Length then
			return row.Move, math.min(row.From + at - row.Start, MOVES[row.Move].Duration)
		end
	end
	local last = cycle[#cycle]
	return last.Move, MOVES[last.Move].Duration
end

-- 0 to 1 over the intro, t in seconds since the spawn: a violent burst off the floor, most of the height in the first second.
function Poses.RiseAt(t)
	if t <= 0 then
		return 0
	elseif t >= Event.IntroSeconds then
		return 1
	end
	return 1 - (1 - t / Event.IntroSeconds) ^ 3
end

return Poses
"""


def write_luau(bake, objs):
	bind = bind_data(objs)
	moves = {}
	for name in PLAN:
		frames, approved, events, duration = bake.move(name)
		keep = sorted(set(approved) | {e["Time"] for e in events} | {duration} | {t + PLAN[name]["segments"][i].get("hold", 0) for i, t in enumerate(([] if boss_keyframes.MOVES[name]["keys"][0]["t"] == 0 else [0]) + [k["t"] for k in boss_keyframes.MOVES[name]["keys"]])})
		moves[name] = (thin(frames, bake.parts, keep), approved, events, duration)
		check(name, moves[name][0], events, duration, bake.parts)
	frames, approved, events, duration = bake.idle()
	moves["idle"] = (thin(frames, bake.parts, [float(k) for k in range(0, IDLE_SECONDS + 1, IDLE_BEAT)]), approved, events, duration)
	check("idle", moves["idle"][0], events, duration, bake.parts)

	impact_time = PLAN["attack"]["events"]["Impact"]
	rot, root = lerp_frame(moves["attack"][0], impact_time, bake.parts)
	tip = world_matrix(bind, "Sword", rot, root) @ Vector(bind["Sword"]["Tip"])
	print(f"BAKE blade tip at Impact: {tuple(round(v, 3) for v in tip)} units")
	for t in (impact_time, 2.05):
		r, ro = lerp_frame(moves["attack"][0], t, bake.parts)
		print(f"BAKE blade tip z at {t}: {(world_matrix(bind, 'Sword', r, ro) @ Vector(bind['Sword']['Tip'])).z:.3f}")

	lines = [
		"--!nonstrict",
		"-- Generated by tools/blender/bake_boss_raga.py from assets/characters_avatar/boss_raga/keyframes/keys.json. Do not edit by hand.",
		'-- Big Raga\'s moves (design doc 4.37, docs/BOSS_EVENT_SPEC.md "Boss and attacks"), client-side visuals; the server reads Schedule and Events only. Contract:',
		"-- src/server/CarTest/BossAnimTests.luau. Approved keys are verbatim at their times; Time is seconds, Parts XYZ Euler degrees.",
		"local Event = require(game:GetService(\"ReplicatedStorage\").Shared.BossEventConfig)",
		"",
		"local SCALE = %s -- studs per model unit" % SCALE,
		"local IMPACT = %s" % vec(tip, 3),
		"-- stylua: ignore",
		"local BIND = {",
	]
	for name, b in sorted(bind.items()):
		tipping = ', Tip = %s' % vec(b["Tip"], 3) if "Tip" in b else ""
		parent = '"%s"' % b["Parent"] if b["Parent"] else "nil"
		lines.append("\t%s = { Parent = %s, Offset = %s, Center = %s, Size = %s%s }," % (name, parent, vec(b["Offset"], 4), vec(b["Center"], 4), vec(b["Size"], 2), tipping))
	lines += ["}", "-- stylua: ignore", "local MOVES = {"]
	for name in sorted(moves):
		frames, approved, events, duration = moves[name]
		pinned = set(approved)
		moved = [p for p in bake.parts if any(max(abs(a - b) for a, b in zip(f[1][p], frames[0][1][p])) > 1e-3 for f in frames)]
		held = [p for p in bake.parts if p not in moved]
		lines.append("\t%s = {" % name)
		lines.append("\t\tDuration = %s," % fmt(duration, 3))
		lines.append("\t\tApproved = {%s}," % ", ".join(fmt(t, 3) for t in approved))
		lines.append("\t\tEvents = {%s}," % ", ".join('{ Time = %s, Name = "%s" }' % (fmt(e["Time"], 3), e["Name"]) for e in events))
		lines.append("\t\tHeld = { %s }," % ", ".join("%s = %s" % (p, vec(frames[0][1][p], 3)) for p in held))
		lines.append("\t\tKeys = {")
		for f in frames:
			places = 3 if f[0] in pinned else 1
			body = ",".join("%s=%s" % (p, vec(f[1][p], places)) for p in moved)
			lines.append("\t\t\t{Time=%s,Root=%s,Parts={%s}}," % (fmt(f[0], 4), vec(f[2], 4), body))
		lines += ["\t\t},", "\t},"]
	lines += ["}", "-- stylua: ignore", "local APPROVED = {"]
	for name, m in bake.json["moves"].items():
		lines.append("\t%s = {" % name)
		for k in m["keys"]:
			body = ",".join("%s=%s" % (p, vec(k["rotations"][p], 3)) for p in bake.parts)
			lines.append("\t\t{Time=%s,RootOffset=%s,Parts={%s}}," % (fmt(k["t"], 3), vec(k["root_offset"], 4), body))
		lines.append("\t},")
	lines += ["}", "-- stylua: ignore", "local CYCLE = {"]
	for row in CYCLE:
		lines.append("\t{%s}," % ", ".join('"%s"' % v if isinstance(v, str) else str(v) for v in row))
	lines.append("}")
	text = "\n".join(lines) + "\n" + FUNCTIONS
	with open(LUAU, "w") as f:
		f.write(text)
	print(f"BAKE wrote {LUAU}: {len(text)} bytes, {sum(len(m[0]) for m in moves.values())} keys")


def write_glb(objs):
	tris = 0
	bind = bind_data(objs)
	for o in list(bpy.data.objects):
		if o.type != "MESH":
			bpy.data.objects.remove(o)
	for name, o in objs.items():
		o.parent = None
		o.location = (0, 0, 0)
		o.rotation_euler = (0, 0, 0)
		mesh = o.data
		c = Vector(bind[name]["Center"])
		for v in mesh.vertices:
			v.co -= c
		mesh.update()
		tris += len(mesh.polygons)
		assert len(mesh.polygons) <= 20000, name
	os.makedirs(os.path.dirname(GLB), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_yup=True, export_apply=True, export_animations=False)
	print(f"BAKE wrote {GLB}: {len(objs)} parts, {tris} tris, {os.path.getsize(GLB)} bytes")


def write_images(blend, objs):
	"""Flat renders on a clear ground at rest: front and side, one image each, framed to the wheel top and the floor."""
	scene = bpy.context.scene
	cam = build_avatar.setup_render(scene)
	scene.render.film_transparent = True
	os.makedirs(FLAT, exist_ok=True)
	bpy.context.view_layer.update()
	pts = np.vstack([boss_keyframes.verts(o) for o in objs.values()])
	lo, hi = pts.min(axis=0), pts.max(axis=0)
	report = {"bounds": [lo.round(3).tolist(), hi.round(3).tolist()]}
	for label, direction, axis in (("front", (0, -1, 0), 0), ("side", (-1, 0, 0), 1)):
		c = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
		cam.location = c + Vector(direction) * 40
		build_avatar.aim(cam, c)
		cam.data.type = "ORTHO"
		cam.data.clip_end = 400
		width, height = hi[axis] - lo[axis], hi[2] - lo[2]
		cam.data.ortho_scale = max(width, height) * 1.02
		scene.render.resolution_x = scene.render.resolution_y = 1024
		scene.render.filepath = os.path.join(FLAT, label + ".png")
		bpy.ops.render.render(write_still=True)
		report[label] = {"width_units": round(float(width), 3), "center": round(float((lo[axis] + hi[axis]) / 2), 3), "frame_units": round(cam.data.ortho_scale, 3)}
	print("BAKE images", json.dumps(report))


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	blend = argv[argv.index("--blend") + 1]
	wanted = [a for a in argv if a in ("poses", "glb", "images")] or ["poses"]
	# Blender's XYZ Euler is Rz * Ry * Rx: the order the client builds its CFrames in (src/client/BossRaga.luau).
	e = Euler((0.3, 0.5, 0.7)).to_matrix()
	rz, ry, rx = Matrix.Rotation(0.7, 3, "Z"), Matrix.Rotation(0.5, 3, "Y"), Matrix.Rotation(0.3, 3, "X")
	assert max(abs(a - b) for ra, rb in zip(e, rz @ ry @ rx) for a, b in zip(ra, rb)) < 1e-6
	bpy.ops.wm.open_mainfile(filepath=blend)
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	for o in objs.values():
		o.rotation_mode = "XYZ"
	if "images" in wanted:
		write_images(blend, objs)
	if "poses" in wanted:
		with open(KEYS) as f:
			write_luau(Bake(json.load(f), objs), objs)
	if "glb" in wanted:
		write_glb(objs)


main()
