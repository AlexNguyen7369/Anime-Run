"""World 2 Track 7: Ant Island (Solo Levelup). Round 2 rebuild 2026-11-23, following the source 1-1: the island raid
against the ant colony (refs and landmark list: docs/world2_refs/AntIsland.md):
- Island: our own ground, an elongated oval with a ragged coast, a sand band, dark forest and scorched patches, ringed by
  dark basalt column cliffs (Cliff) and a ring of blockade ships (Ship) on the sea.
- Hallasan (hero, infield): a broad low shield volcano, dark forested slopes, a pale jagged rocky summit round a rough
  crater with its lake, many small parasitic cones and ant tunnels dug into the slopes.
- Nest (hero, ahead of the runner): the colony, a low wide sandy cratered mound with rings of dark tunnel mouths, bulky
  pale ants climbing out and a pack at its foot, on scorched ground.
- Chamber (hero, beside the road): the queen's chamber opened up, a dark green cave over tightly packed rounded blue eggs
  under webbing, with one big hatched egg.
- Camp: the hunters' raid camp (helicopter on a pad, tents, floodlights, sandbag rings), one framed by the 33% run shot.
- Choga / Ruin / Batdam / Brush: abandoned thatched stone houses with stone gate posts and a stone grandfather statue, a
  ruined concrete hotel, black lava-stone field walls, broadleaf trees and camellia bushes.
- Mound: burning ant mounds with smoke columns: the war zone. Bank: basalt embankment under the raised road.
Overcast dusk sky. Everything in-house, parts only; generic ant shapes; no crest or text (design doc 5). Proposed look;
the owner approves the render set (design doc 4.46)."""

import math

import bpy
from mathutils import Matrix, Vector

BASALT, BASALT2, BASALT3 = "2E2E32", "3E3E44", "222226"
SOIL, SOIL2, SOIL3 = "7A5E40", "634A32", "8E7250"
HOLE, LIP = "0C0A0C", "54402C"
GRASS, GRASS2, GRASS3 = "4A6A34", "3A5A2C", "6A7A44"
PINE, PINE2, CAMEL, BLOOM = "24402A", "2E5232", "1E3A22", "C42A3A"
THATCH, THATCH2, ROPE = "B49A64", "9A8050", "5A4A32"
ANT, ANT2, EYE = "E4E4EA", "B8B8C4", "E02030"
EGG, EGG2, CAVE, CAVE2 = "4AB8FF", "9ADCFF", "1E2E2A", "2C3E36"
CONC, CONC2, WIN = "8A8679", "6E6A60", "22262C"
OLIVE, OLIVE2, CRATE, STEEL = "4E5A3A", "3E4A2E", "7A6440", "6A7078"
HULL, HULL2 = "6E767E", "4E565E"
OCEAN, SUPPORT, LAMP = "1C4260", "3A2E24", "FFF0D0"


def _row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True, skip=()):
	"""Props on the ground beside the road (-Z facing it unless face_road is off), skipping any spot within `clear` of
	another part of the looping road and any span in `skip`."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			dd = d + k.rng.uniform(-jitter, jitter)
			if any(a <= dd <= b for a, b in skip):
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(dd, o)
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def _road_dist(k, x, z):
	step = max(1, len(k.wps) // 600)
	return min(math.hypot(w.x - x, w.z - z) for w in k.wps[::step])


def _rotm(rx, ry, rz):
	"""kit.prop's rotation (degrees, Roblox axes) as a Blender-space matrix."""
	return Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(-rz), 3, "Y")


def _turn(m, off):
	"""Roblox offset `off` turned by Blender matrix `m`, back in Roblox axes."""
	v = m @ Vector((off[0], -off[2], off[1]))
	return (v.x, v.z, -v.y)


def _hole(p, pos, r, ang, tilt=-12):
	"""A tunnel mouth on a slope facing outward at azimuth `ang` (radians): raised soil lip, black opening."""
	x, y, z = pos
	yaw = -math.degrees(ang)
	p.append(("cyl", (r * 2.6, 1.6, r * 2.0), (x, y, z), LIP, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))
	p.append(("cyl", (r * 1.8, 1.0, r * 1.3), (x + math.sin(ang) * 0.6, y, z - math.cos(ang) * 0.6), HOLE, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))


def _bank(k, color):
	"""A basalt embankment under raised road, from the ground up to the road edge, so the climb reads as built."""
	k.prop("Bank", [("box", (1, 1, 1), (0, 0.5, 0), color), ("box", (1.04, 0.06, 1), (0, 0.97, 0), BASALT2)])
	step, d = 16.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			ob = k.place("Bank", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width + 10, step + 0.5, p.y + 0.6)
		d += step


def _ant(p, pos, yaw=0.0, s=1.0, tilt=0.0):
	"""A generic giant ant, bulky: pale thorax and big abdomen, back spikes, big mandibles, red eyes, jointed legs.
	Faces -Z at yaw 0; `tilt` pitches it (climbing)."""
	m = _rotm(tilt, yaw, 0)

	def at(x, y, z):
		q = _turn(m, (x * s, y * s, z * s))
		return (pos[0] + q[0], pos[1] + q[1], pos[2] + q[2])

	def sz(a, b, c):
		return (a * s, b * s, c * s)

	def o(extra=None, r=(0, 0, 0)):
		d = {"rot": (tilt + r[0], yaw + r[1], r[2])}
		d.update(extra or {})
		return d

	p.append(("ball", sz(10, 8, 13), at(0, 7, 9), ANT2, o({"subdiv": 1, "smooth": True}, (-10, 0, 0))))
	p.append(("ball", sz(3.4, 3.4, 3.4), at(0, 7, 2), ANT2, o({"subdiv": 1})))
	p.append(("ball", sz(7, 7, 10), at(0, 8, -3.5), ANT, o({"subdiv": 1, "smooth": True})))
	p.append(("ball", sz(7.6, 6.4, 7), at(0, 9, -10.5), ANT, o({"subdiv": 1, "smooth": True})))
	for i, zz in enumerate((-6.5, -3.5, -0.5)):
		p.append(("cone", sz(1.8, 5 - i, 1.8), at(0, 12.5, zz), ANT2, o({"seg": 4}, (-25, 0, 0))))
	for sx in (-1, 1):
		p.append(("ball", sz(2, 2, 2), at(sx * 2.8, 10, -13.4), EYE, o({"emit": 6, "subdiv": 1})))
		p.append(("box", sz(1.8, 1.8, 8), at(sx * 2.6, 6.8, -16.5), ANT2, o(None, (0, -sx * 22, 0))))
		p.append(("cone", sz(1.8, 4, 1.8), at(sx * 0.9, 6.8, -20.4), ANT2, o({"seg": 4}, (-90, -sx * 50, 0))))
		p.append(("box", sz(0.5, 0.5, 9), at(sx * 2.2, 13.6, -14), ANT2, o(None, (-35, -sx * 18, 0))))
		for lz in (-6, -3.5, -1):
			p.append(("box", sz(8, 1.6, 1.6), at(sx * 6.5, 10, lz * 1.3), ANT2, o(None, (0, sx * lz * 4, sx * 28))))
			p.append(("box", sz(1.6, 11, 1.6), at(sx * 11, 5.2, lz * 1.6), ANT2, o(None, (0, 0, sx * 14))))


def _hgt(r):
	"""Hallasan's surface height at radius r (studs, before instance scale)."""
	pts = ((760, 0), (600, 46), (440, 104), (300, 160), (180, 210), (120, 236))
	if r >= 760:
		return 0.0
	for (r0, h0), (r1, h1) in zip(pts, pts[1:]):
		if r >= r1:
			return h0 + (h1 - h0) * (r0 - r) / (r0 - r1)
	return 236.0


def _hallasan(k):
	p = []
	pts = ((760, 0), (600, 46), (440, 104), (300, 160), (180, 210), (120, 236))
	cols = ("2A4224", "2E4826", "34502C", "5A6040", "8A8670")
	for i, ((r0, h0), (r1, h1)) in enumerate(zip(pts, pts[1:])):
		p.append(("cone", (r0 * 2, h1 - h0, r0 * 2), (0, (h0 + h1) / 2, 0), cols[i], {"seg": 24, "taper": r1 / r0}))
	# pale jagged summit rocks round a rough crater rim, the crater lake inside
	for i in range(22):
		a = i * math.tau / 22 + (i % 3) * 0.05
		rr = 108 + (i * 13 % 5) * 5
		h = 18 + (i * 7 % 6) * 6
		p.append(("cone", (34 + i % 4 * 6, h, 26), (math.sin(a) * rr, 232 + h / 2, -math.cos(a) * rr), ("C4BCAA", "B0A894", "9C9480")[i % 3], {"seg": 5, "taper": 0.2 + (i % 3) * 0.1, "rot": ((i * 11 % 17) - 8, -math.degrees(a) + i * 7, (i * 5 % 13) - 6)}))
	p.append(("cyl", (200, 6, 200), (0, 230, 0), "6E6A5C", {"seg": 14}))
	p.append(("cyl", (150, 2, 150), (0, 234, 0), "3E7A88", {"seg": 14, "rough": 0.2}))
	# parasitic cones (small green craters) on the flanks
	for i in range(16):
		a = i * 2.39 + 0.2
		rr = 420 + (i * 97) % 420
		w = 80 + (i * 37) % 90
		h = w * 0.42
		x, z = math.sin(a) * rr, -math.cos(a) * rr
		by = _hgt(rr) - 4
		p.append(("cone", (w, h, w), (x, by + h / 2, z), ("2E4826", "3A5630", "34502C")[i % 3], {"seg": 12, "taper": 0.45}))
		p.append(("cyl", (w * 0.36, 2, w * 0.36), (x, by + h + 0.4, z), "24361E", {"seg": 10}))
	# dark forest clumps on the slopes
	for i in range(36):
		a = i * 2.17 + 1.1
		rr = 260 + (i * 61) % 470
		w = 46 + (i * 23) % 40
		p.append(("ball", (w, w * 0.5, w), (math.sin(a) * rr, _hgt(rr) + w * 0.12, -math.cos(a) * rr), ("1E3418", "24401E", "2A4622")[i % 3], {"subdiv": 1}))
	# ant tunnels dug into the slopes
	for i in range(14):
		a = i * 2.4 + 0.3
		rr = 470 + (i * 53) % 220
		_hole(p, (math.sin(a) * rr, _hgt(rr) + 4, -math.cos(a) * rr), 9 + i % 3 * 3, a, -25)
	k.prop("Hallasan", p)


def _nest(k):
	"""Low, wide sandy colony mound: cratered top, tunnel mouths all round, ants climbing out, scorched ground."""
	p = [("cyl", (640, 0.4, 560), (0, 0.2, 0), "2C2620", {"seg": 16})]
	tiers = ((200, 0), (165, 30), (120, 58), (80, 80), (50, 92))
	for i, ((r0, h0), (r1, h1)) in enumerate(zip(tiers, tiers[1:])):
		p.append(("cone", (r0 * 2, h1 - h0, r0 * 2 * 0.9), (0, (h0 + h1) / 2, 0), ("A88A5E", "B49468", "9A7E54", "C0A272")[i], {"seg": 16, "taper": r1 / r0}))
	for i in range(18):  # lumps
		a = i * math.tau / 18 + 0.15
		rr = 120 + (i % 3) * 30
		y = 22 - (rr - 120) * 0.5 + (i % 2) * 8
		p.append(("ball", (56, 30 + i % 3 * 8, 44), (math.sin(a) * rr, max(6, y), -math.cos(a) * rr * 0.9), ("9A7E54", "A88A5E", "8A6E48")[i % 3], {"subdiv": 1, "rot": (0, -math.degrees(a), 0)}))
	for x, z, r in ((0, 0, 30), (34, -18, 14), (-30, 14, 12), (-12, -34, 10)):  # craters on top
		y = 92 - 0.25 * math.hypot(x, z)
		p.append(("cyl", (r * 2.4, 5, r * 2.4), (x, y + 2, z), "7A6040", {"seg": 12}))
		p.append(("cyl", (r * 1.7, 1, r * 1.7), (x, y + 4.7, z), HOLE, {"seg": 12}))
	holes = []
	for ring, (rr, y, n, hr) in enumerate(((176, 14, 12, 12), (140, 42, 10, 10), (100, 68, 8, 8))):
		for i in range(n):
			a = i * math.tau / n + ring * 0.3
			hp = (math.sin(a) * rr, y, -math.cos(a) * rr * 0.9)
			_hole(p, hp, hr, a, -30)
			holes.append((hp, a))
	for x, z in ((40, 30), (-50, -10)):  # two small chimneys, secondary
		p.append(("cone", (16, 40, 16), (x, 80, z), "C0A272", {"seg": 8, "taper": 0.25}))
	# ants climbing out of tunnel mouths and a pack at the foot facing out
	for j, (hp, a) in enumerate(holes[::3]):
		yaw = -math.degrees(a) + 180
		_ant(p, (hp[0] + math.sin(a) * 10, hp[1] - 6, hp[2] - math.cos(a) * 10), yaw, 1.6, -22)
	for j in range(6):
		a = -0.6 + j * 0.24
		r = 230 + (j % 2) * 26
		_ant(p, (math.sin(a) * r, 0, -math.cos(a) * r), -math.degrees(a) + 180 + (j % 3 - 1) * 15, 1.8)
	k.prop("Nest", p)


def _chamber(k):
	"""The queen's chamber opened up: a cave mouth facing -Z (the road) over a floor of tightly packed glowing eggs."""
	p = [
		("box", (150, 6, 110), (0, 3, 10), CAVE),
		("box", (120, 60, 6), (0, 30, 58), HOLE),
		("ball", (70, 90, 90), (-70, 40, 20), CAVE2, {"subdiv": 2}),
		("ball", (70, 90, 90), (70, 40, 20), CAVE2, {"subdiv": 2}),
		("ball", (200, 60, 110), (0, 92, 20), CAVE, {"subdiv": 2}),
		("ball", (120, 40, 80), (20, 118, 30), "34483E", {"subdiv": 2}),
		("ball", (50, 34, 40), (-80, 8, -30), CAVE2, {"subdiv": 1}),
		("ball", (40, 26, 30), (84, 6, -28), CAVE2, {"subdiv": 1}),
	]
	for i in range(14):
		x = -54 + i * 8.3
		h = 10 + (i * 7 % 5) * 5
		p.append(("cone", (5, h, 5), (x, 66 - h / 2, -30 + (i % 3) * 8), CAVE2, {"seg": 6, "rot": (180, 0, 0)}))
	for i in range(6):
		p.append(("box", (4, 30, 1), (-50 + i * 20, 52, -34 + (i % 2) * 2), "3E6A3A", {"rot": (0, 0, (i - 2.5) * 4)}))
	eggs = []
	for gx in range(15):
		for gz in range(9):
			x = -52 + gx * 7.4 + (gz % 2) * 3.7
			z = -30 + gz * 7.2
			if math.hypot(x, z - 2) < 16:
				continue  # room for the hatched egg
			s = 6.4 + ((gx + gz * 2) % 3) * 0.6
			p.append(("ball", (s, s * 1.35, s), (x, 6 + s * 0.6, z), ("2E8AB0", "3AA6C0", "2A7AA0")[(gx + gz) % 3], {"emit": 0.7, "subdiv": 1, "smooth": True, "rough": 0.25}))
			eggs.append((x, 6 + s * 1.1, z))
	for i in range(0, len(eggs) - 9, 9):  # webbing strung over the clutch
		a, b = eggs[i], eggs[i + 9]
		mx, mz = (a[0] + b[0]) / 2, (a[2] + b[2]) / 2
		ang = math.degrees(math.atan2(b[0] - a[0], b[2] - a[2]))
		p.append(("box", (0.4, 0.3, math.hypot(b[0] - a[0], b[2] - a[2]) + 4), (mx, a[1] + 0.6, mz), "E8F4FF", {"alpha": 0.45, "rot": (0, ang, 0)}))
	p.append(("cyl", (26, 18, 26), (0, 15, 2), "8ACCD8", {"seg": 12, "taper": 1.2, "emit": 0.5, "smooth": True}))
	for i in range(7):
		a = i * math.tau / 7
		p.append(("cone", (8, 12 + i % 3 * 3, 3), (math.sin(a) * 14, 29, -math.cos(a) * 14 + 2), "8ACCD8", {"seg": 3, "emit": 0.5, "rot": (0, -math.degrees(a), 0)}))
	p.append(("cyl", (22, 1, 22), (0, 24.5, 2), "0E1A22", {"seg": 12}))
	_ant(p, (42, 6, -10), -30, 1.4)
	k.prop("Chamber", p)


def _village(k):
	# Choga: stone-walled thatched house, rope-tied roof, olle yard wall, stone gate posts, a stone grandfather statue
	p = [("box", (28, 1, 18), (0, 0.5, 4), "5A5040")]
	for i in range(20):  # lumpy basalt walls
		side = i % 4
		t = (i // 4) / 5
		if side < 2:
			x, z, w, d = -13 + t * 26 + 2.6, (-5 if side == 0 else 13), 5.4, 2.4
		else:
			x, z, w, d = (-13 if side == 2 else 13), -5 + t * 18 + 1.8, 2.4, 3.8
		if side == 0 and 2 <= i // 4 <= 3:
			continue  # doorway
		p.append(("box", (w, 9 + (i % 3) * 0.8, d), (x, 5, z), (BASALT, BASALT2, BASALT3)[i % 3], {"rot": (0, (i % 5) - 2, 0)}))
	p.append(("box", (6, 8, 0.6), (-1, 4.5, -5.2), "4A3A28"))
	p.append(("box", (30, 3, 21), (0, 10.5, 4), THATCH2))
	p.append(("ball", (30, 10, 21), (0, 12, 4), THATCH, {"subdiv": 2, "smooth": True}))
	for j in range(5):  # rope grid laid over the roof
		x = -11 + j * 5.5
		h = 4.9 * math.sqrt(max(0.0, 1 - (x / 15) ** 2))
		p.append(("box", (0.5, 0.5, 21.4 * math.sqrt(max(0.1, 1 - (x / 15) ** 2))), (x, 12 + h, 4), ROPE))
	for j in range(4):
		z = -3 + j * 4.6
		h = 4.9 * math.sqrt(max(0.0, 1 - ((z - 4) / 10.5) ** 2))
		p.append(("box", (30.4 * math.sqrt(max(0.1, 1 - ((z - 4) / 10.5) ** 2)), 0.5, 0.5), (0, 12 + h, z), ROPE))
	p.append(("box", (7, 1.2, 7), (8, 15.6, 2), HOLE, {"rot": (8, 20, 4)}))  # a collapsed patch of roof
	for i in range(9):  # olle yard wall
		x = -22 + i * 5.5
		if 3 <= i <= 4:
			continue
		p.append(("box", (5, 4 + (i % 3), 2.4), (x, 2.2, -18), (BASALT2, BASALT, BASALT3)[i % 3], {"rot": (0, (i % 3) * 3 - 3, 0)}))
	for x in (-6, 2):  # jeongnang gate: stone posts and wooden bars
		p.append(("box", (1.8, 7, 1.8), (x, 3.5, -18), BASALT2))
	for y in (2.4, 4.0, 5.6):
		p.append(("cyl", (0.7, 9, 0.7), (-2, y, -18.3), "6A5036", {"seg": 6, "rot": (0, 0, 90)}))
	sx = -9.5  # stone grandfather statue beside the gate
	p += [
		("box", (3.2, 1, 3.2), (sx, 0.5, -20), BASALT2),
		("cyl", (3, 7, 2.6), (sx, 4.5, -20), BASALT, {"seg": 8}),
		("ball", (3, 3.6, 3), (sx, 9.6, -20), BASALT, {"subdiv": 1}),
		("cyl", (3.8, 0.5, 3.8), (sx, 11.2, -20), BASALT2, {"seg": 8}),
		("ball", (2.6, 2.2, 2.6), (sx, 12, -20), BASALT2, {"subdiv": 1}),
		("ball", (0.9, 0.9, 0.6), (sx - 0.7, 10, -21.4), BASALT3, {"subdiv": 1}),
		("ball", (0.9, 0.9, 0.6), (sx + 0.7, 10, -21.4), BASALT3, {"subdiv": 1}),
		("box", (3.2, 0.7, 0.6), (sx, 6, -21.4), BASALT3),
	]
	for bx, bz in ((16, -10), (-18, 10), (18, 14)):
		p.append(("ball", (7, 6, 7), (bx, 3, bz), CAMEL, {"subdiv": 1}))
		p.append(("ball", (1, 1, 1), (bx + 2, 5, bz - 3), BLOOM, {"subdiv": 1}))
	k.prop("Choga", p)
	# Ruin: abandoned concrete coast hotel, window grid, collapsed corner, rebar, vines, an ant hole in front
	p = [
		("box", (44, 40, 22), (0, 20, 0), CONC),
		("box", (20, 10, 22), (-12, 45, 0), CONC),
		("box", (46, 1.2, 24), (0, 40, 0), CONC2),
		("box", (20, 3, 14), (16, 2, -14), CONC2, {"rot": (20, 15, 8)}),
		("box", (14, 2, 10), (20, 9, -10), CONC2, {"rot": (0, 0, 40)}),
	]
	for f in range(4):
		p.append(("box", (45, 1, 23), (0, 10 * f + 0.5, 0), CONC2))
		for c in range(6):
			x = -18.5 + c * 7.4
			if f >= 2 and c >= 4:
				continue  # collapsed corner
			p.append(("box", (4.4, 5.5, 0.6), (x, 10 * f + 5.5, -11.1), WIN))
	p.append(("box", (16, 20, 22.4), (14, 30, 0), HOLE))
	for i in range(4):
		p.append(("box", (0.5, 10 + i * 2, 0.5), (8 + i * 3, 42 + i, -6 + i * 3), "6A4A3A", {"rot": (0, 0, -15 + i * 10)}))
	for i in range(5):  # vines
		p.append(("box", (3, 14 + i * 4, 0.8), (-20 + i * 7, 40 - (14 + i * 4) / 2, -11.6), "3E6A34"))
	_hole(p, (-6, 1, -22), 6, 0, -70)
	k.prop("Ruin", p)
	# Batdam: black lava-stone field wall with gaps
	p = []
	for i in range(18):
		x = -18 + i * 2.1
		h = 2.4 + (i * 7 % 4) * 0.6
		p.append(("box", (2.4, h, 2.2), (x, h / 2, (i % 2) * 0.4), (BASALT, BASALT2, BASALT3)[i % 3], {"rot": (i * 11 % 15, i * 23 % 40, i * 7 % 12)}))
		if i % 3 != 1:
			p.append(("box", (2.0, 1.8, 2.0), (x + 0.9, h + 0.9, 0), (BASALT2, BASALT3, BASALT)[i % 3], {"rot": (i * 13 % 20, i * 31 % 45, i * 5 % 15)}))
	k.prop("Batdam", p)


def _camp(k):
	"""The hunters' raid camp, laid out to face -Z (the road): helicopter on a pad, tents, floodlights, sandbag rings."""
	p = [("box", (80, 0.4, 60), (0, 0.2, 4), "6A5E48")]
	for x, z, w, d in ((-26, 14, 14, 18), (-8, 16, 14, 18), (16, 18, 24, 24)):  # tents with gable roofs
		p.append(("box", (w, 5, d), (x, 2.5, z), OLIVE))
		p.append(("wedge", (w / 2, 4, d), (x - w / 4, 7, z), OLIVE2, {"rot": (0, 90, 0)}))
		p.append(("wedge", (w / 2, 4, d), (x + w / 4, 7, z), OLIVE2, {"rot": (0, -90, 0)}))
		p.append(("box", (3, 4, 0.3), (x, 2, z - d / 2 - 0.1), "1A1E14"))
	# helicopter on a pad, nose toward the road, doors open
	hx, hz = -14, -10
	p += [
		("cyl", (24, 0.3, 24), (hx, 0.4, hz), "4A4A44", {"seg": 12}),
		("cyl", (14, 0.32, 14), (hx, 0.45, hz), "C8B040", {"seg": 12}),
		("cyl", (12, 0.36, 12), (hx, 0.5, hz), "4A4A44", {"seg": 12}),
		("ball", (8, 7, 17), (hx, 5.6, hz), "3E4636", {"subdiv": 2, "smooth": True}),
		("ball", (6, 3.6, 6), (hx, 6.6, hz - 6.6), "7A9AA8", {"subdiv": 1, "rough": 0.2}),
		("cyl", (2, 18, 2), (hx, 6.6, hz + 15), "3E4636", {"seg": 6, "rot": (90, 0, 0)}),
		("box", (0.5, 6, 4), (hx, 9, hz + 23.6), "3E4636"),
		("box", (6, 0.4, 2), (hx, 7, hz + 23), "3E4636"),
		("box", (4, 3.6, 7), (hx, 9.6, hz + 1), "3E4636"),
		("cyl", (0.8, 2, 0.8), (hx, 12, hz), STEEL, {"seg": 6}),
		("box", (36, 0.3, 1.4), (hx, 13.1, hz), "202020", {"rot": (0, 30, 0)}),
		("box", (36, 0.3, 1.4), (hx, 13.1, hz), "202020", {"rot": (0, -60, 0)}),
		("box", (0.6, 0.6, 16), (hx - 4, 1, hz), STEEL),
		("box", (0.6, 0.6, 16), (hx + 4, 1, hz), STEEL),
		("box", (0.3, 4, 5), (hx - 4.05, 5, hz), "1A1E14"),
	]
	for lx, lz in ((-36, -22), (34, -22), (0, 30)):  # floodlight masts
		p += [
			("cyl", (0.9, 24, 0.9), (lx, 12, lz), STEEL, {"seg": 6}),
			("box", (7, 3, 2), (lx, 24.5, lz - 0.6), STEEL),
			("box", (6, 2.4, 0.4), (lx, 24.5, lz - 1.7), LAMP, {"emit": 8}),
		]
	for i in range(8):  # supply crates
		p.append(("box", (3.6, 3.2, 3.6), (14 + (i % 4) * 4, 1.6 + (i // 4) * 3.2, -10), CRATE, {"rot": (0, (i * 13) % 20, 0)}))
	for cx, cz, r, n in ((hx, hz, 15, 16), (22, -20, 7, 9)):  # sandbag rings: round the pad and a gun nest
		for i in range(n):
			if cx == hx and 4 <= i <= 6:
				continue  # opening toward the road
			a = i * math.tau / n
			p.append(("cyl", (4.6, 1.6, 2.4), (cx + math.cos(a) * r, 0.9, cz + math.sin(a) * r), "8A7A58", {"seg": 6, "rot": (0, 90 - math.degrees(a), 90), "smooth": True}))
			p.append(("cyl", (4.2, 1.4, 2.2), (cx + math.cos(a + 0.2) * r, 2.3, cz + math.sin(a + 0.2) * r), "7A6A4A", {"seg": 6, "rot": (0, 90 - math.degrees(a), 90), "smooth": True}))
	p += [("box", (0.8, 0.8, 7), (22, 3.2, -24), "2A2A2A"), ("box", (9, 5, 5), (32, 3.2, 6), OLIVE2), ("box", (4, 3, 5), (37.5, 2.6, 6), OLIVE)]
	k.prop("Camp", p)
	# Ship of the blockade: grey hull with a raked bow, bridge, mast, a gun turret
	k.prop(
		"Ship",
		[
			("box", (18, 10, 90), (0, 3, 0), HULL2),
			("cone", (18, 10, 24), (0, 3, -56), HULL2, {"seg": 4, "taper": 0.0, "rot": (-90, 45, 0)}),
			("box", (18.4, 1, 90), (0, 8.5, 0), HULL),
			("box", (12, 10, 22), (0, 14, 8), HULL),
			("box", (10, 5, 12), (0, 21.5, 4), HULL),
			("box", (10.2, 1.4, 0.4), (0, 22, -2.2), "1A2028"),
			("cyl", (1, 22, 1), (0, 32, 8), STEEL, {"seg": 6}),
			("box", (8, 0.6, 0.6), (0, 38, 8), STEEL),
			("cyl", (6, 3, 6), (0, 10.5, -24), HULL, {"seg": 10}),
			("cyl", (0.8, 9, 0.8), (0, 11.5, -29), HULL2, {"seg": 6, "rot": (90, 0, 0)}),
			("box", (6, 6, 8), (0, 12, 26), HULL),
		],
	)



def _nature(k):
	# Mound: a burning ant mound, scorched ground, tunnel mouths, an ant, and a smoke column rising from it
	p = [
		("cyl", (90, 0.3, 80), (0, 0.15, 0), "2C2620", {"seg": 10}),
		("cone", (60, 22, 56), (0, 11, 0), "A88A5E", {"seg": 10, "taper": 0.35}),
		("cone", (24, 14, 24), (12, 8, 10), "9A7E54", {"seg": 8, "taper": 0.3}),
	]
	for i in range(4):
		a = i * math.tau / 4 + 0.4
		_hole(p, (math.sin(a) * 20, 7, -math.cos(a) * 18), 4.5, a, -30)
	for x, z, s in ((8, -6, 3.0), (-10, 4, 2.4), (2, 10, 2.0)):
		p.append(("cone", (5 * s, 9 * s, 5 * s), (x, 18 + 4 * s, z), "FF6A1A", {"seg": 5, "emit": 5}))
		p.append(("cone", (2.6 * s, 6 * s, 2.6 * s), (x, 17 + 3 * s, z), "FFC060", {"seg": 5, "emit": 8}))
	for i in range(8):  # smoke column drifting with the wind, thinning as it rises
		w = 26 + i * 12
		p.append(("ball", (w, w * 0.9, w * 0.8), (i * i * 1.6 - 4 + (i % 2) * 6, 34 + i * 30, i * 2 - (i % 3) * 5), ("1E1E22", "26262A", "2E2E34", "3A3A40")[min(3, i // 2)], {"subdiv": 2, "smooth": True, "rough": 1.0, "alpha": 0.85 - i * 0.06}))
	_ant(p, (-18, 0, -30), 30, 1.2)
	k.prop("Mound", p)
	# Cliff: dark basalt column shore cliff stepping down to the sea on its -Z side
	p = [
		("cone", (90, 30, 76), (0, 13, 8), BASALT3, {"seg": 7, "taper": 0.45}),
		("cone", (50, 22, 44), (-18, 24, 14), "34402C", {"seg": 6, "taper": 0.4}),
	]
	for i in range(20):
		a = i * 2.4
		r = 4 + (i % 6) * 4.6
		x, z = math.cos(a) * r, -abs(math.sin(a)) * r - 10
		h = 26 + z * 0.5 + (i % 3) * 3
		p.append(("cyl", (6, h, 6), (x, h / 2, z), (BASALT, BASALT2, BASALT3)[i % 3], {"seg": 6, "rough": 0.6}))
	k.prop("Cliff", p)
	# Brush: a broadleaf tree, camellia bushes with red blooms, low shrubs
	p = [
		("cyl", (2, 12, 2), (0, 6, 0), "4A3A2A", {"seg": 6, "rot": (0, 0, 5)}),
		("ball", (16, 11, 15), (1, 15, 0), "2E4A26", {"subdiv": 1}),
		("ball", (11, 9, 11), (-5, 13, 3), "264020", {"subdiv": 1}),
		("ball", (10, 8, 10), (6, 17, -2), "34522C", {"subdiv": 1}),
		("ball", (10, 8, 9), (9, 4, 5), CAMEL, {"subdiv": 1}),
		("ball", (8, 7, 8), (-8, 3.5, 6), CAMEL, {"subdiv": 1}),
		("ball", (7, 4, 7), (-2, 2, -8), "3A5A2C", {"subdiv": 1}),
	]
	for bx, by, bz in ((7, 6.5, 1), (11, 6, 3), (-9, 5.5, 3), (-6, 6, 8), (8, 4, 8)):
		p.append(("ball", (1.3, 1.3, 1.3), (bx, by, bz), BLOOM, {"subdiv": 1}))
	k.prop("Brush", p)


def _coast(cx, cz, a, b, th):
	"""Ragged coastline: island radius factor at angle th."""
	return 1.0 + 0.05 * math.sin(5 * th + 1.0) + 0.03 * math.sin(11 * th + 2.0) + 0.018 * math.sin(23 * th + 0.5)


def _island(k, cx, cz, a, b, scorch):
	"""Our own ground: an elongated oval island with a ragged coast, a sand band, darker forest and scorched patches.
	Terrain, not a prop. Returns the coast point function."""
	import bmesh

	from kit import rb

	nr, ns = 26, 220
	bm = bmesh.new()
	cols = {"grass": "435E30", "forest": "2E4626", "scrub": "5A6440", "dirt": "6A5A40", "burnt": "2C2620", "sand": "B8A878", "wet": "7A6E58"}
	names = list(cols)
	mats = [k.mat(cols[n], 1.0) for n in names]
	grid = []
	for i in range(nr + 1):
		rho = (i / nr) ** 0.7 * 1.02
		row = []
		for j in range(ns):
			th = j * math.tau / ns
			f = _coast(cx, cz, a, b, th)
			x, z = cx + math.cos(th) * a * f * rho, cz + math.sin(th) * b * f * rho
			y = -1.0 if rho <= 0.95 else -1.0 - (rho - 0.95) / 0.07 * 3.4
			row.append(bm.verts.new(rb(x, y, z)))
		grid.append(row)
	for i in range(nr):
		for j in range(ns):
			v = (grid[i][j], grid[i][(j + 1) % ns], grid[i + 1][(j + 1) % ns], grid[i + 1][j])
			if i == 0 and v[0] is v[1]:
				continue
			face = bm.faces.new(v)
			rho = ((i + 0.5) / nr) ** 0.7 * 1.02
			th = (j + 0.5) * math.tau / ns
			x, z = cx + math.cos(th) * a * rho, cz + math.sin(th) * b * rho
			n = math.sin(x * 0.004 + 1.3) * math.cos(z * 0.005 - 0.4) + 0.5 * math.sin(x * 0.011 + z * 0.009)
			if rho > 0.985:
				kind = "wet"
			elif rho > 0.93:
				kind = "sand"
			elif any(math.hypot(x - sx, z - sz) < r for sx, sz, r in scorch):
				kind = "burnt"
			elif n > 0.75:
				kind = "forest"
			elif n < -0.9:
				kind = "dirt"
			elif n < -0.5:
				kind = "scrub"
			else:
				kind = "grass"
			face.material_index = names.index(kind)
	bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
	me = bpy.data.meshes.new("W2_AntIsland_Island")
	bm.to_mesh(me)
	bm.free()
	for m in mats:
		me.materials.append(m)
	ob = bpy.data.objects.new(me.name, me)
	k.col.objects.link(ob)


def build(k):
	_hallasan(k)
	_nest(k)
	_chamber(k)
	_village(k)
	_camp(k)
	_nature(k)

	lo, hi = k.lo, k.hi
	cx, cz = (lo.x + hi.x) / 2, (lo.z + hi.z) / 2
	a, b = 1.85 * ((hi.x - lo.x) / 2 + 320), 1.38 * ((hi.z - lo.z) / 2 + 320)
	k.ground(OCEAN, margin=4200, rough=0.75, y=-4.0)
	_bank(k, SUPPORT)
	L = k.length
	# Hero placements first so the scatter keeps clear of them
	best, bd = None, 0.0
	for i in range(31):
		for j in range(31):
			x = lo.x + (hi.x - lo.x) * i / 30
			z = lo.z + (hi.z - lo.z) * j / 30
			dd = _road_dist(k, x, z)
			if dd > bd:
				best, bd = (x, z), dd
	hs = max(0.4, min(1.25, (bd - 60) / 760))
	k.place("Hallasan", (best[0], -1.0, best[1]), 0.4, hs)
	print("HALLASAN at", (round(best[0]), round(best[1])), "clear", round(bd), "scale", round(hs, 2))
	keep = [(best[0], best[1], 760 * hs + 20)]
	nest = None
	for f in (0.33, 0.62, 0.9):
		p, right, t = k.at(L * f)
		for D in range(260, 1300, 20):
			x, z = p.x + right.x * 10 + t.x * D, p.z + right.z * 10 + t.z * D
			if _road_dist(k, x, z) >= 270 and all(math.hypot(x - a_, z - b_) > r + 260 for a_, b_, r in keep):
				if nest is None or D < nest[0]:
					nest = (D, x, z, f)
				break
	scorch = []
	if nest:
		k.place("Nest", (nest[1], -1.0, nest[2]), k.rng.uniform(0, math.tau), 1.0)
		keep.append((nest[1], nest[2], 300))
		scorch.append((nest[1], nest[2], 520))
		print("NEST at", (round(nest[1]), round(nest[2])), "ahead of shot", nest[3], "by", nest[0])
	cd = L * 0.06 + 110
	chamber = None
	for side in (-1, 1):
		(x, _, z), yaw = k.beside(cd, side * 100)
		if k.clear_of_road(x, z, 95) and all(math.hypot(x - a_, z - b_) > r + 80 for a_, b_, r in keep):
			k.place("Chamber", (x, -1.0, z), yaw + (math.pi / 2 if side > 0 else -math.pi / 2))
			keep.append((x, z, 110))
			chamber = (x, z)
			print("CHAMBER at", (round(x), round(z)), "side", side)
			break
	# Raid camps: one framed by the 33% run shot, then one every 900 studs
	camps = []
	spots = [L * 0.33 + 14 + 120] + [L * 0.06 + 600 + 900 * i for i in range(14)]
	for d in spots:
		if d > L - 200 or any(abs(d - c) < 400 for c in camps):
			continue
		for side in (1, -1):
			(x, _, z), yaw = k.beside(d, side * 72)
			if k.clear_of_road(x, z, 62) and all(math.hypot(x - a_, z - b_) > r + 50 for a_, b_, r in keep):
				k.place("Camp", (x, -1.0, z), yaw + (math.pi / 2 if side > 0 else -math.pi / 2), 1.25)
				keep.append((x, z, 60))
				camps.append(d)
				break
	print("CAMPS at", [round(c / L, 2) for c in camps])
	skip = tuple((c - (170 if i == 0 else 55), c + 55) for i, c in enumerate(camps)) + ((cd - 80, cd + 80),)  # the first camp is framed by a run shot
	# Road edge: lava-stone field walls and brush; then villages, ruins and burning mounds; then the island scatter
	_row(k, 40, (-32, 32), ["Batdam"], 30, jitter=2, skip=skip)
	_row(k, 34, (-46, 46), ["Brush"], 40, jitter=4, face_road=False, scale=(0.9, 1.2), skip=skip)
	_row(k, 150, (-70, 70), ["Choga", "Choga", "Ruin"], 60, jitter=20, skip=skip)
	_row(k, 320, (-120, 120), ["Mound", "Ruin", "Choga", "Ruin"], 95, jitter=30, skip=skip)
	k.field(320, ["Brush"], clearance=60, margin=330, scale=(1.0, 2.4))
	k.field(12, ["Mound"], clearance=120, margin=300, scale=(1.2, 2.0))
	k.field(50, ["Choga", "Ruin", "Batdam"], clearance=100, margin=300, scale=(1.0, 1.4))
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("Brush", "Mound", "Choga", "Ruin", "Batdam"):
			lx, lz = ob.location.x, -ob.location.y
			out = math.hypot((lx - cx) / a, (lz - cz) / b) > 0.9
			if out or any(math.hypot(lx - a_, lz - b_) < r for a_, b_, r in keep):
				bpy.data.objects.remove(ob)
				k.instances -= 1
	for ob in list(k.col.objects):  # burnt ground round the burning mounds
		if ob.type == "MESH" and ob.data.name.endswith("_Mound"):
			scorch.append((ob.location.x, -ob.location.y, 90 * ob.scale.x))
	_island(k, cx, cz, a, b, scorch)
	# Basalt column cliffs along the coast, facing the sea; blockade ships ring the island
	n = 170
	for i in range(n):
		th = i * math.tau / n
		f = _coast(cx, cz, a, b, th) * 0.975
		x, z = cx + math.cos(th) * a * f, cz + math.sin(th) * b * f
		out = math.atan2(-(x - cx), -(z - cz))
		k.place("Cliff", (x, -4.0, z), out + k.rng.uniform(-0.4, 0.4), k.rng.uniform(1.0, 1.7))
	for i in range(22):
		th = i * math.tau / 22 + k.rng.uniform(-0.05, 0.05)
		x, z = cx + math.cos(th) * (a + 700), cz + math.sin(th) * (b + 700)
		k.place("Ship", (x, -4.0, z), -th + k.rng.uniform(-0.3, 0.3), k.rng.uniform(1.4, 2.0))
	# Overcast dusk over a war zone; cool lamps along the road, floodlit camps, blue glow in the chamber
	k.sky([(0.0, "D8946A"), (0.04, "A07A70"), (0.12, "6E6670"), (0.35, "4A4C5A"), (1.0, "2A2C38")], strength=0.9, sun=(2.4, "FFB070", 12, 230))
	d = 40
	while d < L:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, LAMP, energy=30000, radius=8)
		d += 220
	if chamber:
		k.light((chamber[0], 30, chamber[1]), "4AB8FF", energy=80000, radius=20)
	counts = {}
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.data.name.startswith("W2_"):
			key = ob.data.name.split("_")[-1]
			counts[key] = counts.get(key, 0) + 1
	print("PERPROP", counts)
