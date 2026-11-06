# Sidekick attacks' in-betweens (design doc 4.37, SIDEKICK_SPEC, BOSS_EVENT_SPEC "Boss and attacks"; owner approved the 12 attacks' keys).
#   python3 tools/blender/bake_sidekick_attacks.py     writes src/shared/SidekickAttacks.luau, then self-checks against the limits of
#                                                      src/server/CarTest/SidekickAttackTests.luau. Run stylua on it after.
#   Blender -b --factory-startup --python tools/blender/bake_sidekick_attacks.py -- rig <folder holding <id>/<id>.blend>
#                                                      writes tools/blender/sidekicks/rigs.json: what keys.json does not say.
# Approved keys of keyframes/keys.json go in verbatim at their times; everything between them is generated here.
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
RIGS = os.path.join(HERE, "sidekicks", "rigs.json")
LUAU = os.path.join(ROOT, "src", "shared", "SidekickAttacks.luau")
IDS = "side_chain side_wyvern side_knight side_pig side_crow side_reindeer side_dogs side_ant side_reaper side_fist side_curse side_fox".split()
RATE = 120  # samples a second before thinning
MAX_GAP = 1 / 15  # s between baked keys at most
TOLERANCE, ROOT_TOLERANCE = 0.2, 0.002  # degrees and units a thinned key may be off the curve
FRAME = 1 / 60
DEGREE_SLACK, OFFSET_SLACK = 1, 0.01  # SidekickAttackTests: a frame may move twice the fastest linear segment plus this
CAP = 0.85  # of that limit, for an ease's peak
# Keys that land a blow: the snap goes into them and they hold a beat. All other keys are passed through softly.
STRIKES = {"Release", "Second slash", "Third slash", "Left straight", "Both fists", "Second bite"}
EXTRA_RELEASE = {"side_dogs": ("Second bite",)}  # owner: the second dog fires at its own bite
HOLD = 0.03  # s of hit stop on a strike
SETTLE_CARRY, RECOVER_CARRY = 0.12, 0.07  # overshoot past a key, as a share of the segment before


def rig(folder):
	import bpy

	out = {}
	for cid in IDS:
		bpy.ops.wm.open_mainfile(filepath=os.path.join(folder, cid, cid + ".blend"))
		objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
		parents = {n: (o.parent.name if o.parent and o.parent.name in objs else None) for n, o in objs.items()}
		root = sorted(n for n, p in parents.items() if p is None)[0]
		o = objs[root]
		assert not any(o.rotation_euler), f"{cid}: a turned root breaks the runtime's fit of pivots to parts"
		world = [o.matrix_world @ v.co for v in o.data.vertices]
		low = [min(p[i] for p in world) for i in range(3)]
		high = [max(p[i] for p in world) for i in range(3)]
		out[cid] = {
			"Parents": parents,
			"Fit": root,
			"FitCenter": [round((a + b) / 2, 4) for a, b in zip(low, high)],
			"FitHeight": round(high[2] - low[2], 4),  # Blender's Z is Roblox's Y
		}
	with open(RIGS, "w") as f:
		json.dump(out, f, indent=1, sort_keys=True)
	print("RIGS", RIGS)


def bump(u):
	"""0 at both ends, leaving fast at u = 0 with an early peak: a carried overshoot, decaying (bake_boss_raga)."""
	return math.sin(math.pi * u) * (1 - u) ** 1.5


def ein(p):
	return lambda u: u**p


def eout(p):
	return lambda u: 1 - (1 - u) ** p


def inout(p):
	return lambda u: 0.5 * (2 * u) ** p if u < 0.5 else 1 - 0.5 * (2 * (1 - u)) ** p


class Attack:
	def __init__(self, cid, data, rigdata):
		self.cid, self.rig = cid, rigdata
		move = data["moves"]["attack"]
		self.duration = move["end"]
		self.parts = sorted(data["pivots"])
		self.pivots = data["pivots"]
		self.rest = data["rest"]
		self.keys = move["keys"]
		self.roots = sorted(n for n, p in rigdata["Parents"].items() if p is None)
		assert sorted(rigdata["Parents"]) == self.parts, cid
		for k in self.keys:
			assert sorted(k["rotations"]) == self.parts and sorted(k["root_offset"]) == self.roots, f"{cid} {k['name']}"
		self.release = [move["Release"]] + [k["t"] for k in self.keys if k["name"] in EXTRA_RELEASE.get(cid, ())]
		self.times = [0.0] + [k["t"] for k in self.keys] + [self.duration]
		rest = (self.rest, {r: (0, 0, 0) for r in self.roots})
		self.stops = [rest] + [(k["rotations"], k["root_offset"]) for k in self.keys] + [rest]
		self.names = ["Rest"] + [k["name"] for k in self.keys] + ["Rest"]
		self.plan()

	def spans(self, i):
		"""The fastest channel of segment i if linear: degrees and units a frame."""
		frames = (self.times[i + 1] - self.times[i]) / FRAME
		degrees = max(abs(a - b) for p in self.parts for a, b in zip(self.stops[i][0][p], self.stops[i + 1][0][p])) / frames
		offset = max(abs(a - b) for r in self.roots for a, b in zip(self.stops[i][1][r], self.stops[i + 1][1][r])) / frames
		return degrees, offset

	def plan(self):
		count = len(self.times) - 1
		spans = [self.spans(i) for i in range(count)]
		self.speed, self.root_speed = max(s[0] for s in spans), max(s[1] for s in spans)
		self.max_degrees = self.speed * 2 + DEGREE_SLACK
		self.max_offset = self.root_speed * 2 + OFFSET_SLACK
		self.segments = []
		for i in range(count):
			degrees, offset = spans[i]
			room = min(self.max_degrees / max(degrees, 1e-6), self.max_offset / max(offset, 1e-6)) * CAP
			before, after = self.names[i], self.names[i + 1]
			if before in STRIKES:  # hit stop, then it lets go fast and settles
				hold = HOLD
				room *= 1 - HOLD / (self.times[i + 1] - self.times[i])
				seg = {"ease": eout(min(2.6, room)), "hold": hold, "carry": SETTLE_CARRY}
			elif after in STRIKES:  # the snap
				seg = {"ease": ein(max(1.2, min(3.2, room)))}
			elif i == count - 1:
				seg = {"ease": inout(min(2.2, room)), "carry": RECOVER_CARRY}
			else:  # anticipation, or a charge held
				seg = {"ease": inout(min(2.2, room))}
			self.segments.append(seg)

	def at(self, t):
		i = 0
		while i < len(self.times) - 2 and t >= self.times[i + 1]:
			i += 1
		seg = self.segments[i]
		hold = seg.get("hold", 0)
		t0, t1 = self.times[i], self.times[i + 1]
		u = min(max((t - t0 - hold) / (t1 - t0 - hold), 0.0), 1.0)
		s = seg["ease"](u)
		carry = seg.get("carry", 0) * bump(u) if i > 0 else 0
		a, b = self.stops[i], self.stops[i + 1]
		z = self.stops[i - 1] if i > 0 else a

		def value(table, name):
			return tuple(a[table][name][k] + (b[table][name][k] - a[table][name][k]) * s + carry * (a[table][name][k] - z[table][name][k]) for k in range(3))

		return {p: value(0, p) for p in self.parts}, {r: value(1, r) for r in self.roots}

	def frames(self):
		approved = {k["t"]: k for k in self.keys}
		approved[0.0] = None
		approved[self.duration] = None
		even = (i / RATE for i in range(int(self.duration * RATE)))
		grid = sorted(set(approved) | {t for t in even if all(abs(t - k) > 1e-6 for k in approved)})
		samples = []
		for t in grid:
			if t in approved and approved[t]:
				k = approved[t]
				samples.append((t, k["rotations"], k["root_offset"]))
			elif t in approved:
				samples.append((t, self.rest, {r: (0, 0, 0) for r in self.roots}))
			else:
				samples.append((t, *self.at(t)))
		return self.thin(samples, set(approved))

	def thin(self, samples, keep):
		"""Drops samples a straight line between neighbours can stand in for. Sample lerps, so this is exactly what the game plays."""

		def off(a, b, c, u):
			bad = False
			for table, limit, names in ((1, TOLERANCE, self.parts), (2, ROOT_TOLERANCE, self.roots)):
				for n in names:
					for k in range(3):
						bad = bad or abs(a[table][n][k] + (b[table][n][k] - a[table][n][k]) * u - c[table][n][k]) > limit
			return bad

		out = [samples[0]]
		i, n = 0, len(samples)
		while i < n - 1:
			j = i + 1
			while j + 1 < n and samples[j + 1][0] - samples[i][0] <= MAX_GAP and samples[j][0] not in keep:
				a, b = samples[i], samples[j + 1]
				if any(off(a, b, samples[m], (samples[m][0] - a[0]) / (b[0] - a[0])) for m in range(i + 1, j + 1)):
					break
				j += 1
			out.append(samples[j])
			i = j
		return out

	def check(self, frames):
		"""The test's own limits, so a breach shows up here and not in Studio."""

		def lerp(t):
			i = 0
			while i < len(frames) - 2 and frames[i + 1][0] <= t:
				i += 1
			a, b = frames[i], frames[i + 1]
			u = min(max((t - a[0]) / (b[0] - a[0]), 0), 1)
			mix = lambda table, n: [a[table][n][k] + (b[table][n][k] - a[table][n][k]) * u for k in range(3)]
			return {p: mix(1, p) for p in self.parts}, {r: mix(2, r) for r in self.roots}

		worst, worst_root = 0, 0
		prev = lerp(0)
		for k in range(1, math.ceil(self.duration / FRAME) + 1):
			cur = lerp(min(k * FRAME, self.duration))
			worst = max([worst] + [abs(a - b) for p in self.parts for a, b in zip(cur[0][p], prev[0][p])])
			worst_root = max([worst_root] + [abs(a - b) for r in self.roots for a, b in zip(cur[1][r], prev[1][r])])
			prev = cur
		print(f"BAKE {self.cid}: {len(frames)} keys, speed {self.speed:.2f}, worst {worst:.2f} of {self.max_degrees:.2f} deg/frame, root {worst_root:.4f} of {self.max_offset:.4f}")
		assert worst <= self.max_degrees, self.cid
		assert worst_root <= self.max_offset, self.cid


def num(v):
	return ("%.4f" % v).rstrip("0").rstrip(".")


def lst(v, places=4):
	return "{" + ",".join(("%.*f" % (places, x)).rstrip("0").rstrip(".") for x in v) + "}"


def named(table, names, places=4):
	return "{" + ",".join(f"{n}={lst(table[n], places)}" for n in names) + "}"


def block(a, frames):
	joints = []
	placed = set()

	def place(n):
		if n in placed:
			return
		parent = a.rig["Parents"][n]
		if parent:
			place(parent)
		placed.add(n)
		joints.append(n)

	for n in a.parts:
		place(n)
	rows = [f"\t{a.cid} = {{", f"\t\tDuration = {num(a.duration)},", f"\t\tRelease = {lst(a.release)},"]
	rows.append("\t\tKeys = {")
	for t, parts, roots in frames:
		rows.append(f"\t\t\t{{Time={num(t)},Parts={named(parts, a.parts, 2)},Roots={named(roots, a.roots)}}},")
	rows.append("\t\t},")
	rows.append("\t\tApproved = {")
	for k in a.keys:
		rows.append(f"\t\t\t{{Time={num(k['t'])},Parts={named(k['rotations'], a.parts)},RootOffset={named(k['root_offset'], a.roots)}}},")
	rows.append("\t\t},")
	rows.append("\t\tRig = {")
	for n in joints:
		parent = a.rig["Parents"][n]
		rows.append(f"\t\t\t{{Name=\"{n}\",Parent={json.dumps(parent) if parent else 'nil'},Pivot={lst(a.pivots[n])}}},")
	rows.append("\t\t},")
	rows.append(f"\t\tFit = {{Part=\"{a.rig['Fit']}\",Center={lst(a.rig['FitCenter'])},Height={num(a.rig['FitHeight'])}}},")
	rows.append("\t},")
	return rows


HEADER = """--!nonstrict
-- Generated by tools/blender/bake_sidekick_attacks.py from assets/characters_avatar/<id>/keyframes/keys.json. Do not edit by hand.
-- Sidekick attacks (design doc 4.37, docs/SIDEKICK_SPEC.md, docs/BOSS_EVENT_SPEC.md "Boss and attacks"), client-side visuals only.
-- Contract: src/server/CarTest/SidekickAttackTests.luau. Approved keys are verbatim at their times; Time is seconds, Parts XYZ Euler
-- degrees, Roots model units, all with Blender's axes (front -Y, Z up). Rig is parents first; Fit ties the model's units to a real part.
local SidekickAttacks = {}

-- stylua: ignore
local ATTACKS = {
"""

FOOTER = """	-- No approved key frames (design doc 4.37): a simple shot and no poses, for the owner to rule on.
	side_raga = { Duration = 0, Release = { 0 }, Keys = {}, Approved = {}, NeedsOwnerApproval = true },
}

for _, attack in ATTACKS do
	for _, key in attack.Keys do
		for name, v in key.Parts do
			key.Parts[name] = Vector3.new(v[1], v[2], v[3])
		end
		for name, v in key.Roots do
			key.Roots[name] = Vector3.new(v[1], v[2], v[3])
		end
	end
end

SidekickAttacks.Attacks = ATTACKS

-- parts[part] and roots[root] at t s, clamped to the attack. An attack with no keys gives {}, {}.
function SidekickAttacks.Sample(id, t)
	local keys = ATTACKS[id].Keys
	local high = #keys
	if high == 0 then
		return {}, {}
	end
	local low = 1
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
	local parts, roots = {}, {}
	for name, from in a.Parts do
		parts[name] = from:Lerp(b.Parts[name], u)
	end
	for name, from in a.Roots do
		roots[name] = from:Lerp(b.Roots[name], u)
	end
	return parts, roots
end

local function joint(offset, degrees)
	return CFrame.new(offset)
		* CFrame.Angles(0, 0, math.rad(degrees.Z))
		* CFrame.Angles(0, math.rad(degrees.Y), 0)
		* CFrame.Angles(math.rad(degrees.X), 0, 0)
end

-- Each part's world frame with these rotations, with Blender's axes, in studs at `scale` studs a model unit.
function SidekickAttacks.Frames(id, parts, roots, scale)
	local frames = {}
	local rig = ATTACKS[id].Rig
	local byName = {}
	for _, row in rig do
		byName[row.Name] = row
	end
	for _, row in rig do
		local pivot = Vector3.new(row.Pivot[1], row.Pivot[2], row.Pivot[3])
		if row.Parent then
			local up = byName[row.Parent].Pivot
			local offset = pivot - Vector3.new(up[1], up[2], up[3])
			frames[row.Name] = frames[row.Parent] * joint(offset * scale, parts[row.Name])
		else
			frames[row.Name] = joint((pivot + (roots[row.Name] or Vector3.zero)) * scale, parts[row.Name])
		end
	end
	return frames
end

return SidekickAttacks
"""


def main():
	with open(RIGS) as f:
		rigs = json.load(f)
	rows = []
	for cid in IDS:
		with open(os.path.join(ROOT, "assets", "characters_avatar", cid, "keyframes", "keys.json")) as f:
			data = json.load(f)
		a = Attack(cid, data, rigs[cid])
		frames = a.frames()
		a.check(frames)
		rows += block(a, frames)
	with open(LUAU, "w") as f:
		f.write(HEADER + "\n".join(rows) + "\n" + FOOTER)
	print("WROTE", LUAU)


if __name__ == "__main__":
	if "--" in sys.argv and sys.argv[sys.argv.index("--") + 1] == "rig":
		rig(sys.argv[sys.argv.index("--") + 2])
	else:
		main()
