"""World 2 Track 7: Ant Island (Solo Levelup). Round 2 rebuild 2026-11-23, following the source 1-1: the island raid
against the ant colony (refs and landmark list: docs/world2_refs/AntIsland.md):
- Island: our own ground, an elongated oval with a ragged coast, a sand band, dark forest and scorched patches, ringed by
  dark basalt column cliffs (Cliff) and a ring of blockade ships (Ship) on the sea.
- Hallasan (hero, infield): a broad low shield volcano, dark forested slopes, pale rock spread wide and low round a rough
  crater with its lake, many small parasitic cones and ant tunnels dug into the slopes.
- Nest (hero, ahead of the runner): the colony, a low wide dark-earth cratered mound with rings of dark tunnel mouths, bulky
  pale ants climbing out and a pack at its foot, on scorched ground.
- Chamber (hero, beside the road): the queen's chamber opened up, a dark green cave over tightly packed rounded blue eggs
  under webbing, with one big hatched egg.
- Camp: the hunters' raid camp (helicopter on a pad, tents, floodlights, sandbag rings), one framed by the 33% run shot.
- Ant (hero): one giant ant; the nest's ants are instances of it.
- Choga / Ruin / Brush: abandoned thatched stone houses with stone gate posts and a stone grandfather statue, a ruined
  concrete hotel, broadleaf trees and camellia bushes behind black lava-stone field walls.
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
ANT, ANT2, EYE = "868AA0", "4E5266", "FF2A30"  # slate chitin with dark plates, as the refs (not near-white)
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


def _frame(ux, uy, uz):
	"""kit.prop rot (degrees) that turns a part's local X, Y, Z onto the Roblox unit vectors ux, uy, uz."""
	m = Matrix(((ux[0], -ux[2], ux[1]), (-uz[0], uz[2], -uz[1]), (uy[0], -uy[2], uy[1]))).transposed()
	e = m.to_euler("YXZ")
	return (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y))


def _seg(p, a, b, t, col, opts=None, shape="box", t2=None):
	"""A limb, horn or strand from Roblox point a to b: box (t square), cyl, or cone pointing at b (taper t2/t)."""
	a, b = Vector(a), Vector(b)
	d = b - a
	if d.length < 1e-4:
		return
	uy = d.normalized()
	ref = Vector((0, 0, 1)) if abs(uy.y) > 0.9 else Vector((0, 1, 0))
	ux = ref.cross(uy).normalized()
	uz = ux.cross(uy)
	o = dict(opts or {}, rot=_frame(ux, uy, uz))
	if shape != "box":
		o.setdefault("seg", 6)
		if t2 is not None:
			o["taper"] = t2 / t
	c = (a + b) / 2
	p.append((shape, (t, d.length, t), (c.x, c.y, c.z), col, o))


def _hole(p, pos, r, ang, tilt=-12):
	"""A tunnel mouth on a slope facing outward at azimuth `ang` (radians): raised soil lip, black opening."""
	x, y, z = pos
	yaw = -math.degrees(ang)
	p.append(("cyl", (r * 2.6, 1.6, r * 2.0), (x, y, z), LIP, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))
	p.append(("cyl", (r * 1.8, 1.0, r * 1.3), (x + math.sin(ang) * 0.6, y, z - math.cos(ang) * 0.6), HOLE, {"seg": 10, "rot": (90 + tilt, yaw, 0)}))


# Review shots filled in by build() / read by build_track.py
EXTRA_SHOTS = []
MODEL_SHOTS = ["Ant", "Nest", "Chamber", "Hallasan", "Camp"]
CLEAR_EXEMPT = {"Island", "Bank"}  # the island ground under the road, and the embankment under the raised road


def _clearance(k, skip=("Road", "Wall", "Dash", "Apron", "WinPad", "Ground", "Bank", "Island", "Hallasan", "Nest", "Ship", "Cliff")):
	"""Print, per prop, the least distance from any corner of an instance's bounding box to the road centre line (a
	conservative check of the 24-stud rule)."""
	step = max(1, len(k.wps) // 1500)
	pts = [(w.x, w.z) for w in k.wps[::step]]
	out = {}
	for ob in k.col.objects:
		if ob.type != "MESH" or not ob.data.name.startswith("W2_"):
			continue
		name = ob.data.name.split("_")[-1]
		if name in skip:
			continue
		best = out.get(name, 1e9)
		for c in ob.bound_box:
			v = ob.matrix_basis @ Vector(c)  # matrix_world is stale until the depsgraph updates
			best = min(best, min(math.hypot(v.x - a, -v.y - b) for a, b in pts))
		out[name] = round(best, 1)
	print("CLEARANCE", out)


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


def _ant(p, pos, yaw=0.0, s=1.0, tilt=0.0, out=None):
	"""A generic giant ant as the source draws them: slate chitin with dark plates, a large banded abdomen with plate
	ridges and spikes, spikes down the back, an angular shield-like head with a spiked crown, two big almond and two small
	red eyes, long curved sickle mandibles, elbowed antennae, and long thin spidery legs with high knees. Faces -Z at yaw 0; `tilt` pitches it (climbing). `out` collects its centre."""
	m = _rotm(tilt, yaw, 0)
	BAND, JOINT = "3E4254", "343848"

	def at(x, y, z):
		q = _turn(m, (x * s, y * s, z * s))
		return (pos[0] + q[0], pos[1] + q[1], pos[2] + q[2])

	def sz(a, b, c):
		return (a * s, b * s, c * s)

	def o(extra=None, r=(0, 0, 0)):
		d = {"rot": (tilt + r[0], yaw + r[1], r[2])}
		d.update(extra or {})
		return d

	def seg(a, b, t, col, shape="cyl", t2=None, opts=None):
		_seg(p, at(*a), at(*b), t * s, col, opts or {"emit": 0.15}, shape, None if t2 is None else t2 * s)

	if out is not None:
		out.append(at(0, 0, 0))
	sm = {"subdiv": 2, "smooth": True, "rough": 0.5, "emit": 0.15}
	p.append(("ball", sz(18, 15, 26), at(0, 11, 17), ANT, o(sm, (-12, 0, 0))))  # a large banded abdomen
	for i, zz in enumerate((8, 11.5, 15, 18.5, 22, 25.5)):
		f = math.sqrt(max(0.12, 1 - ((zz - 17) / 13) ** 2))
		p.append(("cyl", sz(18.4 * f, 1.2, 15.4 * f), at(0, 11 + (17 - zz) * 0.21, zz), BAND, o({"seg": 14}, (78, 0, 0))))
	for zz in (9, 13, 17, 21):  # plate ridges and spikes along the top
		yy = 18 + (17 - zz) * 0.2 - abs(zz - 15) * 0.15
		p.append(("box", sz(9, 1.4, 3), at(0, yy - 0.6, zz), ANT2, o(None, (-12, 0, 0))))
		seg((0, yy, zz), (0, yy + 5, zz + 3), 2.6, ANT, "cone", 0.1)
	p.append(("ball", sz(4, 4, 5), at(0, 9.5, 4.5), JOINT, o({"subdiv": 1})))
	p.append(("ball", sz(8, 8, 12), at(0, 10.5, -2), ANT, o(sm)))
	for i, zz in enumerate((-6, -2.5, 1)):
		seg((0, 13.5, zz), (0, 19 - i, zz + 3), 2.2, ANT, "cone", 0.1)
		for sx in (-1, 1):
			seg((sx * 3, 12.5, zz), (sx * 7, 15, zz + 2), 1.4, ANT, "cone", 0.1)
	# an angular, shield-like head: flat top plate, an angled face, cheek plates, a spiked crown
	p.append(("box", sz(12, 3, 12), at(0, 14, -11), ANT, o(None, (-12, 0, 0))))
	p.append(("box", sz(11, 9, 2.4), at(0, 10.6, -17.2), ANT, o(None, (24, 0, 0))))
	p.append(("box", sz(8, 3, 7), at(0, 7.4, -14), ANT2, o(None, (8, 0, 0))))
	for sx in (-1, 1):
		p.append(("box", sz(2.6, 8, 10), at(sx * 5.6, 11, -12.5), ANT2, o(None, (0, sx * 14, sx * -12))))
	for i, (sx_, up) in enumerate(((-1, 0.7), (-0.5, 1.1), (0, 1.3), (0.5, 1.1), (1, 0.7))):  # spiked crown
		seg((sx_ * 4, 15, -10), (sx_ * 7.5, 15 + 7 * up, -5 + abs(sx_) * 2), 2.2, ANT, "cone", 0.1)
	for sx in (-1, 1):
		p.append(("ball", sz(3.6, 2.2, 1.4), at(sx * 3.2, 11.8, -18.4), EYE, o({"emit": 5, "subdiv": 2}, (24, sx * 12, sx * -24))))  # big almond eyes
		p.append(("ball", sz(1.4, 1.4, 1), at(sx * 1.5, 14.6, -17.4), EYE, o({"emit": 5, "subdiv": 1}, (24, 0, 0))))
		seg((sx * 3.6, 7.6, -17), (sx * 8, 7.2, -24), 2.6, ANT2, "cyl", 2.2)  # long curved sickle mandible
		seg((sx * 8, 7.2, -24), (sx * 8.6, 7, -32), 2.2, ANT2, "cyl", 1.8)
		seg((sx * 8.6, 7, -32), (sx * 5.6, 7, -38.5), 1.8, ANT2, "cyl", 1.3)
		seg((sx * 5.6, 7, -38.5), (sx * 1.2, 7, -40.5), 1.3, "D8D0C0", "cone", 0.1)
		seg((sx * 1.6, 15.4, -16), (sx * 4.4, 23, -19), 0.6, ANT2)  # elbowed antenna
		seg((sx * 4.4, 23, -19), (sx * 10, 24, -28), 0.5, ANT2)
		for zz, kz, fz in ((-5, -12, -24), (-2, -3, -4), (1, 8, 20)):  # long legs, knees high
			hip, knee, ank, foot = (sx * 4, 9, zz), (sx * 12.5, 19, kz * 0.8), (sx * 19, 4.5, fz * 0.8), (sx * 21, 0, fz * 0.85)
			seg(hip, knee, 2.2, ANT)
			p.append(("ball", sz(2.8, 2.8, 2.8), at(*knee), JOINT, o({"subdiv": 1})))
			seg(knee, ank, 1.9, ANT, "cyl", 1.2)
			seg(ank, foot, 1.2, ANT2, "cone", 0.2)
			seg(((knee[0] + ank[0]) / 2, (knee[1] + ank[1]) / 2, (knee[2] + ank[2]) / 2), ((knee[0] + ank[0]) / 2 + sx * 3, (knee[1] + ank[1]) / 2 + 1, (knee[2] + ank[2]) / 2), 0.9, ANT, "cone", 0.1)


def _hgt(r):
	"""Hallasan's surface height at radius r (studs, before instance scale)."""
	pts = HALLA
	if r >= pts[0][0]:
		return 0.0
	for (r0, h0), (r1, h1) in zip(pts, pts[1:]):
		if r >= r1:
			return h0 + (h1 - h0) * (r0 - r) / (r0 - r1)
	return pts[-1][1]


HALLA = ((760, 0), (600, 34), (440, 80), (300, 128), (190, 172), (140, 190))  # a broad, low shield


def _hallasan(k):
	p = []
	pts = HALLA
	cols = ("2A4224", "2E4826", "34502C", "4E5A3A", "8A8670")
	for i, ((r0, h0), (r1, h1)) in enumerate(zip(pts, pts[1:])):
		p.append(("cone", (r0 * 2, h1 - h0, r0 * 2), (0, (h0 + h1) / 2, 0), cols[i], {"seg": 24, "taper": r1 / r0}))
	top = pts[-1][1]
	# pale jagged summit rocks round a rough crater rim, well above the tree line, the crater lake inside
	for i in range(28):  # pale rock spread wide and low round the crater: an inner broken rim and outer outcrops
		a = i * math.tau / 28 + (i % 3) * 0.06
		rr = (120 + (i * 13 % 5) * 6) if i % 2 else (190 + (i * 17 % 5) * 14)
		h = 12 + (i * 7 % 5) * 5
		w = 60 + (i * 5 % 4) * 12
		p.append(("cone", (w, h, w * 0.7), (math.sin(a) * rr, _hgt(rr) - 6 + h / 2, -math.cos(a) * rr), ("D8D0C0", "C4BCAA", "B0A894")[i % 3], {"seg": 6, "taper": 0.45 + (i % 3) * 0.08, "rot": ((i * 11 % 17) - 8, -math.degrees(a) + i * 7, (i * 5 % 13) - 6)}))
	p.append(("ball", (130, 50, 140), (-120, top, 10), "CCC4B2", {"subdiv": 2, "rough": 1.0}))  # the pale lava dome on the west rim
	for i in range(6):
		p.append(("box", (30 + i * 4, 3, 50), (-150 + i * 6, top - 10 - i * 14, 10 + (i - 3) * 14), "B8B09C", {"rot": (0, i * 17, 28 + i * 3)}))
	for i in range(10):  # pale scree streaks down the upper cone
		a = i * math.tau / 10 + 0.3
		p.append(("box", (22, 2, 110), (math.sin(a) * 240, _hgt(240) + 2, -math.cos(a) * 240), "A8A090", {"rot": (-18, -math.degrees(a), 0)}))
	p.append(("cyl", (190, 6, 190), (0, top - 4, 0), "6E6A5C", {"seg": 14}))
	p.append(("cyl", (140, 2, 140), (0, top, 0), "3E7A88", {"seg": 14, "rough": 0.2}))
	for i in range(16):
		a = i * 2.39 + 0.2
		rr = 420 + (i * 97) % 420
		w = 80 + (i * 37) % 90
		h = w * 0.42
		x, z = math.sin(a) * rr, -math.cos(a) * rr
		by = _hgt(rr) - 4
		p.append(("cone", (w, h, w), (x, by + h / 2, z), ("2E4826", "3A5630", "34502C")[i % 3], {"seg": 12, "taper": 0.45}))
		p.append(("cyl", (w * 0.36, 2, w * 0.36), (x, by + h + 0.4, z), "24361E", {"seg": 10}))
	for i in range(36):  # dark forest clumps, kept below the summit rocks
		a = i * 2.17 + 1.1
		rr = 330 + (i * 61) % 400
		w = 46 + (i * 23) % 40
		p.append(("ball", (w, w * 0.5, w), (math.sin(a) * rr, _hgt(rr) + w * 0.12, -math.cos(a) * rr), ("1E3418", "24401E", "2A4622")[i % 3], {"subdiv": 1}))
	for i in range(14):
		a = i * 2.4 + 0.3
		rr = 470 + (i * 53) % 220
		_hole(p, (math.sin(a) * rr, _hgt(rr) + 4, -math.cos(a) * rr), 9 + i % 3 * 3, a, -25)
	k.prop("Hallasan", p)


NEST_ANTS = []  # footprint centres of the nest's ants (local), for the clearance check


def _nest(k):
	"""Low, wide sandy colony mound: lumpy cratered surface, dark-rimmed tunnel mouths all round, ants climbing out and
	a scattered pack at its foot, on scorched ground."""
	p = []  # the scorched ground round it is painted on the island
	tiers = ((200, 0), (165, 30), (120, 58), (80, 80), (50, 92))
	for i, ((r0, h0), (r1, h1)) in enumerate(zip(tiers, tiers[1:])):
		p.append(("cone", (r0 * 2, h1 - h0, r0 * 2 * 0.9), (0, (h0 + h1) / 2, 0), ("5E4A38", "6A543E", "554232", "72604A")[i], {"seg": 16, "taper": r1 / r0}))

	def surf(r):
		for (r0, h0), (r1, h1) in zip(tiers, tiers[1:]):
			if r >= r1:
				return h0 + (h1 - h0) * (r0 - r) / (r0 - r1)
		return 92

	for i in range(44):  # lumps all over the surface
		a = i * 2.39 + 0.15
		rr = 20 + (i * 47) % 175
		w = 24 + (i * 17) % 30
		p.append(("ball", (w, w * 0.55, w * 0.85), (math.sin(a) * rr, surf(rr) - 2, -math.cos(a) * rr * 0.9), ("554232", "5E4A38", "4A3A2C", "6A543E")[i % 4], {"subdiv": 1, "rot": (0, -math.degrees(a), 0)}))
	for x, z, r in ((0, 0, 30), (34, -18, 14), (-30, 14, 12), (-12, -34, 10), (60, 30, 12), (-64, -30, 11), (20, 66, 10), (-40, 60, 9)):
		y = surf(math.hypot(x, z / 0.9)) - 1
		p.append(("cyl", (r * 2.6, 6, r * 2.6), (x, y + 2, z), "6A5034", {"seg": 12, "taper": 0.8}))
		p.append(("cyl", (r * 1.7, 1, r * 1.7), (x, y + 5.2, z), HOLE, {"seg": 12}))
	holes = []
	for ring, (rr, y, n, hr) in enumerate(((176, 14, 12, 12), (140, 42, 10, 10), (100, 68, 8, 8))):
		for i in range(n):
			a = i * math.tau / n + ring * 0.3
			hp = (math.sin(a) * rr, y, -math.cos(a) * rr * 0.9)
			_hole(p, hp, hr, a, -30)
			holes.append((hp, a))
	for x, z in ((40, 30), (-50, -10)):
		p.append(("cone", (16, 40, 16), (x, 80, z), "72604A", {"seg": 8, "taper": 0.25}))
	NEST_ANTS.clear()  # (local pos, yaw deg, scale, tilt deg): placed as Ant instances by build()
	for j, (hp, a) in enumerate(holes[::3]):  # climbing out of tunnel mouths, each at its own angle
		yaw = -math.degrees(a) + 180 + (j % 3 - 1) * 25
		at = (hp[0] + math.sin(a) * 10, hp[1] - 6, hp[2] - math.cos(a) * 10)
		if j % 4 == 0:  # a few are part of the mesh so the close-up shows them
			_ant(p, at, yaw, 1.5, -18 - (j % 4) * 6)
		else:
			NEST_ANTS.append((at, yaw, 1.5 + (j % 3) * 0.15, -18 - (j % 4) * 6))
	for j, (a, r, turn, s) in enumerate(((-0.7, 212, 30, 1.7), (-0.42, 236, -50, 1.9), (-0.25, 205, 10, 1.6), (0.02, 228, 75, 1.8), (0.3, 214, -20, 2.0), (0.52, 240, 140, 1.7), (0.1, 262, -100, 1.5), (-0.55, 255, 160, 1.6))):
		NEST_ANTS.append(((math.sin(a) * r, 0, -math.cos(a) * r), -math.degrees(a) + 180 + turn, s, 0))
	k.prop("Nest", p)
	p = []
	_ant(p, (0, 0, 0))
	k.prop("Ant", p)


def _chamber(k):
	"""The queen's chamber opened up: a cave mouth facing -Z (the road) over a raised, tiered carpet of rounded blue
	eggs under pale web strands, with one big hatched egg."""
	p = [
		("box", (150, 10, 110), (0, 5, 10), CAVE),
		("box", (120, 70, 6), (0, 35, 58), HOLE),
		("ball", (70, 100, 90), (-70, 44, 20), CAVE2, {"subdiv": 2}),
		("ball", (70, 100, 90), (70, 44, 20), CAVE2, {"subdiv": 2}),
		("ball", (200, 60, 110), (0, 100, 20), CAVE, {"subdiv": 2}),
		("ball", (120, 40, 80), (20, 126, 30), "34483E", {"subdiv": 2}),
		("ball", (50, 34, 40), (-80, 8, -30), CAVE2, {"subdiv": 1}),
		("ball", (40, 26, 30), (84, 6, -28), CAVE2, {"subdiv": 1}),
	]
	for i in range(14):
		x = -54 + i * 8.3
		h = 10 + (i * 7 % 5) * 5
		p.append(("cone", (5, h, 5), (x, 74 - h / 2, -30 + (i % 3) * 8), CAVE2, {"seg": 6, "rot": (180, 0, 0)}))
	for i in range(8):  # moss hanging down the side walls
		sx = (-1, 1)[i % 2]
		p.append(("box", (1, 26 + i % 3 * 6, 6), (sx * (58 - (i // 2) * 2), 50, -22 + (i // 2) * 14), "3E6A3A", {"rot": (0, 0, sx * 6)}))
	for gz in range(5):  # terraces rising toward the back so every row shows over the road wall
		p.append(("box", (118, 4 + gz * 4, 12), (0, 10 + gz * 2, -26 + gz * 11), CAVE2))
	eggs = []
	for gz in range(5):
		for gx in range(14):
			x = -52 + gx * 8 + (gz % 2) * 4 + ((gx * 7 + gz) % 3 - 1)
			z = -26 + gz * 11 + ((gx * 5) % 3 - 1) * 1.5
			if math.hypot(x, z - 2) < 24:
				continue
			s = 6.6 + ((gx + gz * 2) % 3) * 0.8
			y = 12 + gz * 4 + s * 0.7
			o = {"emit": 0.35, "subdiv": 2 if gz < 2 else 1, "smooth": True, "rough": 0.25}
			col = ("2E8AB0", "3AA6C0", "2A7AA0")[(gx + gz) % 3]
			p.append(("ball", (s, s * 1.2, s), (x, y, z), col, o))  # a teardrop egg: rounded base, pointed top
			p.append(("cone", (s * 0.86, s * 0.9, s * 0.86), (x, y + s * 0.82, z), col, {"seg": 8, "emit": 0.35, "smooth": True, "rough": 0.25}))
			eggs.append((x, y + s * 0.5, z))
	for i in range(0, len(eggs) - 15, 4):  # pale web strands over the clutch, at varied heights
		a, b = eggs[i], eggs[i + 15 if i % 8 else i + 1]
		mx, my, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2 + 2, (a[2] + b[2]) / 2
		ln = math.hypot(b[0] - a[0], b[2] - a[2]) + 3
		ang = math.degrees(math.atan2(b[0] - a[0], b[2] - a[2]))
		p.append(("box", (0.35, 0.35, ln), (mx, my, mz), "EEF6FF", {"alpha": 0.6, "emit": 0.3, "rot": (0, ang, 0)}))
	for gz in range(4):  # translucent web sheets draped over the rows
		for part_ in range(3):
			x0 = -40 + part_ * 40 + (gz % 2) * 8
			p.append(("box", (34, 0.3, 14), (x0, 24 + gz * 4.4, -20 + gz * 11), "E8F0FF", {"alpha": 0.3, "emit": 0.4, "rot": ((gz % 2) * 8 - 4, (part_ - 1) * 6, (part_ - 1) * 5)}))
	for i in range(6):  # strands hanging at the back wall
		p.append(("box", (0.3, 30 + i % 3 * 8, 0.3), (-40 + i * 16, 58 - i % 3 * 4, 32 + (i % 2) * 4), "EEF6FF", {"alpha": 0.5, "emit": 0.3}))
	# one big glowing egg, its top broken open
	p.append(("ball", (40, 46, 40), (0, 34, 2), "7AE6FF", {"subdiv": 2, "emit": 2.2, "smooth": True, "rough": 0.2}))
	p.append(("ball", (24, 26, 24), (0, 38, 2), "D8FAFF", {"subdiv": 2, "emit": 5, "alpha": 0.6}))
	for i in range(8):
		a = i * math.tau / 8
		p.append(("cone", (11, 12 + i % 3 * 4, 3), (math.sin(a) * 16, 58, -math.cos(a) * 16 + 2), "7AE6FF", {"seg": 3, "emit": 2.2, "rot": (0, -math.degrees(a), (i % 2) * 14 - 7)}))
	p.append(("cyl", (26, 1, 26), (0, 55.5, 2), "0E1A22", {"seg": 12}))
	_ant(p, (40, 30, 20), -20, 1.3)  # on the back terrace, over the clutch
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
	for rot, w, z in ((90, 22, -22.1), (-90, 22, -22.1), (180, 44, -11.1)):  # windows round the sides and back
		m = _rotm(0, rot, 0)
		for f in range(4):
			for c in range(int(w // 7.4)):
				q = _turn(m, (-w / 2 + 3.7 + c * 7.4, 10 * f + 5.5, z))
				p.append(("box", (4.4, 5.5, 0.6), q, WIN, {"rot": (0, rot, 0)}))
	for i in range(10):  # rubble from the collapsed corner
		a = i * 2.3
		p.append(("box", (3 + i % 3 * 2, 2 + i % 2 * 1.5, 3 + i % 4), (18 + math.cos(a) * 6, 1, -16 + math.sin(a) * 4), (CONC, CONC2, "5A564C")[i % 3], {"rot": (i * 13, i * 29, i * 7)}))
	_hole(p, (-6, 1, -22), 6, 0, -70)
	k.prop("Ruin", p)


def _camp(k):
	"""The hunters' raid camp, laid out to face -Z (the road): helicopter on a pad, tents, floodlights, sandbag rings."""
	p = [("box", (80, 0.4, 60), (0, 0.2, 4), "6A5E48")]
	for x, z, w, d in ((-26, 14, 14, 18), (-8, 16, 14, 18), (16, 18, 24, 24)):  # tents with gable roofs
		p.append(("box", (w, 5, d), (x, 2.5, z), OLIVE))
		p.append(("wedge", (w / 2, 4, d), (x - w / 4, 7, z), OLIVE2, {"rot": (0, 90, 0)}))
		p.append(("wedge", (w / 2, 4, d), (x + w / 4, 7, z), OLIVE2, {"rot": (0, -90, 0)}))
		p.append(("box", (3, 4, 0.3), (x, 2, z - d / 2 - 0.1), "1A1E14"))
	# helicopter on a big marked pad, nose toward the road, side door open, four-blade rotor
	hx, hz = -14, -12
	H = 1.5
	p += [
		("cyl", (32, 0.3, 32), (hx, 0.4, hz), "4A4A44", {"seg": 14}),
		("cyl", (20, 0.32, 20), (hx, 0.45, hz), "C8B040", {"seg": 14}),
		("cyl", (17, 0.36, 17), (hx, 0.5, hz), "4A4A44", {"seg": 14}),
		("cyl", (6, 0.4, 6), (hx, 0.6, hz), "C8B040", {"seg": 10}),  # a plain centre dot, no letter
		("ball", (8 * H, 7 * H, 17 * H), (hx, 5.6 * H, hz), "3E4636", {"subdiv": 2, "smooth": True}),
		("ball", (6 * H, 3.6 * H, 6 * H), (hx, 6.6 * H, hz - 6.6 * H), "7A9AA8", {"subdiv": 1, "rough": 0.2}),
		("cyl", (2 * H, 18 * H, 2 * H), (hx, 6.6 * H, hz + 15 * H), "3E4636", {"seg": 6, "rot": (90, 0, 0)}),
		("box", (0.6, 6 * H, 4 * H), (hx, 9 * H, hz + 23.6 * H), "3E4636"),
		("box", (6 * H, 0.4, 2 * H), (hx, 7 * H, hz + 23 * H), "3E4636"),
		("box", (4 * H, 3.6 * H, 7 * H), (hx, 9.6 * H, hz + H), "3E4636"),
		("cyl", (0.8 * H, 2 * H, 0.8 * H), (hx, 12 * H, hz), STEEL, {"seg": 6}),
		("box", (50, 0.4, 3), (hx, 13.1 * H, hz), "2A2A2A", {"rot": (0, 20, 0)}),
		("box", (50, 0.4, 3), (hx, 13.1 * H, hz), "2A2A2A", {"rot": (0, 110, 0)}),
		("box", (0.8, 0.8, 16 * H), (hx - 4 * H, 1, hz), STEEL),
		("box", (0.8, 0.8, 16 * H), (hx + 4 * H, 1, hz), STEEL),
		("box", (0.3, 4 * H, 5 * H), (hx - 4.05 * H, 5 * H, hz), "1A1E14"),
	]
	for lx, lz in ((-36, -22), (34, -22), (0, 30)):  # floodlight masts
		p += [
			("cyl", (0.9, 24, 0.9), (lx, 12, lz), STEEL, {"seg": 6}),
			("box", (7, 3, 2), (lx, 24.5, lz - 0.6), STEEL),
			("box", (6, 2.4, 0.4), (lx, 24.5, lz - 1.7), LAMP, {"emit": 8}),
		]
	for i in range(8):  # supply crates
		p.append(("box", (3.6, 3.2, 3.6), (14 + (i % 4) * 4, 1.6 + (i // 4) * 3.2, -10), CRATE, {"rot": (0, (i * 13) % 20, 0)}))
	for cx, cz, r, n in ((hx, hz, 19, 20), (22, -20, 7, 9)):  # sandbag rings: round the pad and a gun nest
		for i in range(n):
			if cx == hx and 13 <= i <= 17:
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
		w = 24 + i * 8
		p.append(("ball", (w, w * 0.9, w * 0.8), (i * i * 0.8 - 4 + (i % 2) * 6, 34 + i * 30, i * 2 - (i % 3) * 5), ("1E1E22", "26262A", "2E2E34", "3A3A40")[min(3, i // 2)], {"subdiv": 2, "smooth": True, "rough": 1.0, "alpha": 0.85 - i * 0.06}))
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
	for i in range(9):  # a black lava-stone field wall (batdam) behind it, stones stacked with gaps
		x = -9 + i * 2.2
		h = 2.4 + (i * 7 % 4) * 0.6
		p.append(("box", (2.4, h, 2.2), (x, h / 2, 12 + (i % 2) * 0.4), (BASALT, BASALT2, BASALT3)[i % 3], {"rot": (i * 11 % 15, i * 23 % 40, i * 7 % 12)}))
		if i % 3 != 1:
			p.append(("box", (2.0, 1.8, 2.0), (x + 0.9, h + 0.9, 12), (BASALT2, BASALT3, BASALT)[i % 3], {"rot": (i * 13 % 20, i * 31 % 45, i * 5 % 15)}))
	k.prop("Brush", p)


def _coast(cx, cz, a, b, th):
	"""Ragged coastline: island radius factor at angle th."""
	return 1.0 + 0.05 * math.sin(5 * th + 1.0) + 0.03 * math.sin(11 * th + 2.0) + 0.018 * math.sin(23 * th + 0.5)


def _ell(cx, cz, a, b, th, phi):
	"""Point at angle th on an ellipse with semi-axes a, b, turned phi radians, centred on (cx, cz)."""
	lx, lz = math.cos(th) * a, math.sin(th) * b
	return cx + lx * math.cos(phi) - lz * math.sin(phi), cz + lx * math.sin(phi) + lz * math.cos(phi)


def _rho(cx, cz, a, b, phi, x, z):
	"""Normalised ellipse radius of a point (1 = on the unragged outline)."""
	dx, dz = x - cx, z - cz
	u, v = dx * math.cos(phi) + dz * math.sin(phi), -dx * math.sin(phi) + dz * math.cos(phi)
	return math.hypot(u / a, v / b)


def _island(k, cx, cz, a, b, scorch, phi=0.0):
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
			x, z = _ell(cx, cz, a * f * rho, b * f * rho, th, phi)
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
			x, z = _ell(cx, cz, a * rho, b * rho, th, phi)
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
	# An elongated diagonal oval (2.2 : 1) just big enough that the track and a 300-stud margin sit inside 80% of it
	phi, ratio = math.radians(35), 2.2
	need = [(lo.x - 300, lo.z - 300), (hi.x + 300, lo.z - 300), (lo.x - 300, hi.z + 300), (hi.x + 300, hi.z + 300)] + [(w.x, w.z) for w in k.wps[::8]]
	b = max(_rho(cx, cz, ratio, 1.0, phi, x, z) for x, z in need) / 0.8
	a = b * ratio
	print("ISLAND semi-axes", round(a), round(b))
	k.ground(OCEAN, margin=9000, rough=0.75, y=-4.0)
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
			if _road_dist(k, x, z) >= 340 and all(math.hypot(x - a_, z - b_) > r + 260 for a_, b_, r in keep):
				if nest is None or D < nest[0]:
					nest = (D, x, z, f)
				break
	scorch = []
	if nest:
		nest_yaw = k.rng.uniform(0, math.tau)
		k.place("Nest", (nest[1], -1.0, nest[2]), nest_yaw, 1.0)
		th = nest_yaw  # Blender turn theta maps local (x, z) to (x cos + z sin, -x sin + z cos)
		nest_ants = []
		for (x, y, z), yaw, sc, tilt in NEST_ANTS:
			wx, wz = nest[1] + x * math.cos(th) + z * math.sin(th), nest[2] - x * math.sin(th) + z * math.cos(th)
			ob = k.place("Ant", (wx, y - 1.0, wz), 0.0, sc)
			ob.rotation_euler = (math.radians(tilt), 0, math.radians(yaw) + th)
			nest_ants.append((wx, wz))
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
	spots = [L * 0.33 + 14 + 90] + [L * 0.06 + 600 + 900 * i for i in range(14)]
	for d in spots:
		if d > L - 200 or any(abs(d - c) < 400 for c in camps):
			continue
		for side in (1, -1):
			(x, _, z), yaw = k.beside(d, side * 72)
			if k.clear_of_road(x, z, 62) and all(math.hypot(x - a_, z - b_) > r + 50 for a_, b_, r in keep):
				k.place("Camp", (x, -1.0, z), yaw + (math.pi / 2 if side > 0 else -math.pi / 2), 1.2)
				keep.append((x, z, 60))
				camps.append(d)
				break
	print("CAMPS at", [round(c / L, 2) for c in camps])
	# Village set pieces framed by the 6% run shot (right side, the chamber is left) and the side shot
	homes = []
	for d, off, name in ((L * 0.06 + 60, 66, "Choga"), (L * 0.06 + 150, 70, "Choga"), (L * 0.48 - 40, 70, "Choga"), (L * 0.48 + 30, 72, "Choga"), (L * 0.48 - 5, 110, "Ruin")):
		(x, _, z), yaw = k.beside(d, off)
		if k.clear_of_road(x, z, off - 4) and all(math.hypot(x - a_, z - b_) > r + 30 for a_, b_, r in keep):
			k.place(name, (x, -1.0, z), yaw + math.pi / 2)
			keep.append((x, z, 34))
			homes.append(d)
	skip = tuple((c - (150 if i == 0 else 55), c + 55) for i, c in enumerate(camps)) + ((cd - 80, cd + 80),) + tuple((h - 30, h + 30) for h in homes)  # the first camp is framed by a run shot
	# Road edge: lava-stone field walls and brush; then villages, ruins and burning mounds; then the island scatter
	_row(k, 34, (-52, 52), ["Brush"], 46, jitter=4, face_road=False, scale=(0.9, 1.2), skip=skip)
	_row(k, 150, (-70, 70), ["Choga", "Choga", "Ruin"], 60, jitter=20, skip=skip)
	_row(k, 320, (-120, 120), ["Mound", "Ruin", "Choga", "Ruin"], 95, jitter=30, skip=skip)
	k.field(320, ["Brush"], clearance=75, margin=330, scale=(1.0, 2.4))
	k.field(12, ["Mound"], clearance=180, margin=300, scale=(1.2, 2.0))
	k.field(50, ["Choga", "Ruin", "Brush"], clearance=100, margin=300, scale=(1.0, 1.4))
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("Brush", "Mound", "Choga", "Ruin"):
			lx, lz = ob.location.x, -ob.location.y
			out = _rho(cx, cz, a, b, phi, lx, lz) > 0.86
			if out or any(math.hypot(lx - a_, lz - b_) < r for a_, b_, r in keep):
				bpy.data.objects.remove(ob)
				k.instances -= 1
	for ob in list(k.col.objects):  # burnt ground round the burning mounds
		if ob.type == "MESH" and ob.data.name.endswith("_Mound"):
			scorch.append((ob.location.x, -ob.location.y, 90 * ob.scale.x))
	_island(k, cx, cz, a, b, scorch, phi)
	# Basalt column cliffs along the coast, facing the sea; blockade ships ring the island
	n = 170
	for i in range(n):
		th = i * math.tau / n
		f = _coast(cx, cz, a, b, th) * 0.975
		x, z = _ell(cx, cz, a * f, b * f, th, phi)
		out = math.atan2(-(x - cx), -(z - cz))
		k.place("Cliff", (x, -4.0, z), out + k.rng.uniform(-0.4, 0.4), k.rng.uniform(1.0, 1.7))
	for i in range(48):  # a dense, even blockade ring just off the coast
		th = i * math.tau / 48
		x, z = _ell(cx, cz, a + 260, b + 260, th, phi)
		k.place("Ship", (x, -4.0, z), -th + k.rng.uniform(-0.15, 0.15), k.rng.uniform(3.0, 3.6))
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
	_clearance(k)
	if nest:  # the nest's ants, measured one by one
		print("NEST ANTS min road distance", round(min(_road_dist(k, x, z) for x, z in nest_ants), 1))
	# Review shot of Hallasan from the runner's lane where the road heads most straight at it
	global EXTRA_SHOTS
	hx, hz = keep[0][0], keep[0][1]
	pick = None
	d = 60.0
	while d < L - 60:
		p, right, t = k.at(d)
		vx, vz = hx - p.x, hz - p.z
		ang = math.degrees(math.acos(max(-1.0, min(1.0, (vx * t.x + vz * t.z) / math.hypot(vx, vz)))))
		if pick is None or ang < pick[0]:
			pick = (ang, d)
		d += 20
	p, right, t = k.at(pick[1])
	eye = p + right * 10 - t * 14
	EXTRA_SHOTS = [("06_hallasan", (eye.x, p.y + 8.5, eye.z), (hx, 110.0, hz))]
	print("EXTRA 06_hallasan at", round(pick[1] / L, 2), round(pick[0]), "deg off heading")
