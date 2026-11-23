"""World 2 Track 5: Kaiju Base (Kaiju No. 8). Rebuilt 2026-11-23 for a closer 1-1 read of the source (owner: "more detail
and closer reference to source material"; round 2 after the reference review). Landmarks and their references:
docs/world2_refs/KaijuBase.md.
First half: a kaiju-wrecked Tokyo district under a clear blue sky with cumulus clouds: a street grid of wrecked low-rise
blocks with craters, balconied apartment blocks and office towers with collapsed corners and scorch marks (some
leaning), smoke columns, varied rubble and wrecked cars. A giant kaiju corpse lies across the blocks and the Monster
Sweeper crews clean it up (white hooded suits on ropes, a stake-and-rope line along its back, ropes hanging from teal
lattice gantries, part of it stripped to the ribs; white vans with roof racks and crews sitting on top). Second half:
the Defense Force's Tachikawa base (low perimeter wall, the wide symmetric white HQ with its central glass tower, end
pavilions and parking lot, the observation tower beside it, hangars with armoured vehicles, the anti-kaiju rail cannon
lying low on its long rail bed).
Rules (design doc 5, WORLD2_SPEC): in-house primitives only; no text and no real insignia (the base badge is an
invented orange diamond, the sweeper vans carry a plain red band); the corpse is intact or bare bone, no wounds.
Props 24+ studs from the centre line. Budget: 12 unique meshes (road pieces excluded). Clouds are sky dressing (the
game's Sky), not prop assets.
Frames: a viewer in front of a prop (looking +Z) sees local +X on the left.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import kit

DUST, ASH, CONC, CONC2, RUST = "8C877C", "4A4A4C", "C8C2B6", "8A9098", "8A5A3A"
ROCK, WINDOW, GLASS, SCORCH = "5C5650", "2A3440", "6E8EAA", "2A2624"
FLESH, FLESH2, FLESH3, PLATE, BONE, BONE2 = "9A4636", "7A3428", "B05A44", "5A4A4A", "E6DCC4", "C8BCA0"
SUIT, TEAL, ROPE_Y, ROPE_B = "F4F4F0", "2F7F7A", "E8C840", "2E6FD0"
BASE, BASE2, STRIPE, NAVY, OLIVE = "ECECE6", "A8AEB4", "FF8A1E", "2E3E58", "4A5240"
ASPHALT, WALK = "3A3A3E", "A8A49C"


def bx(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def seg(p, a, b, col, thick=0.5, wide=None):
	"""A straight member (cable, rope) from point a to point b, as a thin box along its length."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rz = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
	ry = math.degrees(math.atan2(-dz, dx))
	bx(p, (ln, thick, wide or thick), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), col, rot=(0, ry, rz))


def worker(p, x, y, z, s=1.0, sit=False):
	"""A Monster Sweeper in a white hooded suit (no face): body, hood, visor, green pack, legs."""
	bx(p, (1.8 * s, 2.6 * s, 1.2 * s), (x, y + 2.6 * s, z), SUIT)
	p.append(("ball", (1.6 * s, 1.7 * s, 1.6 * s), (x, y + 4.6 * s, z), SUIT, {"subdiv": 1}))
	bx(p, (1.1 * s, 0.8 * s, 0.2 * s), (x, y + 4.5 * s, z - 0.8 * s), "3A4048")
	bx(p, (1.4 * s, 1.8 * s, 0.8 * s), (x, y + 2.8 * s, z + 0.9 * s), "5A6A44")
	if sit:
		bx(p, (1.6 * s, 0.9 * s, 2.4 * s), (x, y + 1.0 * s, z - 1.4 * s), SUIT)
	else:
		bx(p, (1.6 * s, 2.4 * s, 1.0 * s), (x, y + 0.6 * s, z), SUIT)


def car(p, x, z, col, yaw=0, state=0):
	"""state 0 parked, 1 crushed flat, 2 flipped onto its side."""
	if state == 2:
		bx(p, (2.6, 7, 14), (x, 2.5, z), col, rot=(0, yaw, 0))
		bx(p, (2.2, 6.2, 7.5), (x - 2.3, 2.5, z + 0.5), "34404E", rot=(0, yaw, 0))
		bx(p, (0.8, 7.2, 14.2), (x + 1.6, 2.5, z), "1A1A1A", rot=(0, yaw, 0))
		return
	h = 0.5 if state == 1 else 1.0
	bx(p, (7, 2.4 * h, 14), (x, 1.4 * h - 1, z), col, rot=(0, yaw, 0))
	bx(p, (6.2, 2.2 * h, 7.5), (x, 3.6 * h - 1, z + 0.5), "34404E", rot=(0, yaw, 0), rough=0.2)
	bx(p, (7.2, 0.8, 14.2), (x, 0.0, z), "1A1A1A", rot=(0, yaw, 0))


def supports(k, color):
	"""Concrete piers under raised road (the climbs), so it never floats."""
	k.prop("Pier", [("box", (10, 1, 10), (0, -0.5, 0), color), ("box", (12, 0.4, 12), (0, -0.2, 0), "4A4E56")])
	d = 0.0
	while d < k.length:
		p, _, _ = k.at(d)
		if p.y > 3:
			pos, yaw = k.beside(d, 0)
			ob = k.place("Pier", (pos[0], p.y - 0.5, pos[2]), yaw)
			ob.scale = (1, 1, p.y + 0.5)
		d += 24


def put(k, name, d, off, scale=1.0, clear=None, turn=0.0):
	"""One prop on the ground at distance d, `off` studs right (negative left) of the centre line, -Z to the road."""
	pos, yaw = k.beside(d, off)
	if not k.clear_of_road(pos[0], pos[2], min(abs(off) - 1, 24) if clear is None else clear):
		return None
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	return k.place(name, (pos[0], -1.0, pos[2]), yaw + turn, scale)


def row(k, a, b, every, offsets, names, jitter=0.0, scale=(1.0, 1.0), skip=(), turn=0.0, chance=1.0, lean=0.0):
	"""Props along the road. turn: random extra yaw up to +-turn; chance: share of spots filled; lean: share tilted."""
	d = a
	while d < b:
		if not any(s0 <= d <= s1 for s0, s1 in skip):
			for off in offsets:
				if k.rng.random() > chance:
					continue
				o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
				ob = put(k, k.rng.choice(names), d + k.rng.uniform(-jitter, jitter), o, k.rng.uniform(*scale), turn=k.rng.uniform(-turn, turn))
				if ob and k.rng.random() < lean:
					ob.rotation_euler[0] = math.radians(k.rng.choice((-1, 1)) * k.rng.uniform(3, 6))
					ob.location.z -= 2.0
		d += every


def local(k, d, off, lx, lz):
	"""World (x, z) of a point (lx, lz) in the frame of a prop placed by put(k, _, d, off)."""
	pos, yaw = k.beside(d, off)
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	v = Matrix.Rotation(yaw, 3, "Z") @ Vector((lx, -lz, 0))  # Blender frame: Roblox z is Blender -y
	return pos[0] + v.x, pos[2] - v.y, yaw


def shot_eye(k, f):
	"""Eye, forward and right of build_track's runner shot at fraction f (same maths as build_track.shots)."""
	p, right, t = k.at(k.length * f)
	return p + right * 10 - t * 14, t, right


def build(k):
	rnd = random.Random(808)

	# --- Apartment block (mid): "mansion" with balcony slabs, rails, dividers, sliding doors, AC units; the top right
	# corner has collapsed: the floors step down, broken floor plates stick out of the break face, a slab rests from
	# the break down onto the lower roof, rubble on that roof, scorch marks round the break. ---
	ap = []
	AW, AD, fh = 40.0, 20.0, 6.0
	full, low = 9, 6
	bx(ap, (AW - 14, fh * full, AD), (-7, fh * full / 2 - 1, 0), "D9D0BC")
	bx(ap, (14, fh * low, AD), (13, fh * low / 2 - 1, 0), "D9D0BC")
	for f in range(full):
		y = f * fh + 1
		w, x = (AW, 0) if f < low else (AW - 14, -7)
		bx(ap, (w, 0.8, 4), (x, y + fh - 1.4, -AD / 2 - 2), "E6E0D2")
		bx(ap, (w, 2.2, 0.3), (x, y + fh - 3.2, -AD / 2 - 3.9), "B8C0C6", metal=0.4)
		n = int(w / 8)
		for c in range(n):
			cx = x - w / 2 + (c + 0.5) * w / n
			bx(ap, (5.6, 3.6, 0.3), (cx, y + 2.0, -AD / 2 - 0.1), WINDOW, rough=0.2)
			bx(ap, (0.3, fh - 1.4, 4), (cx + w / n / 2, y + 2.3, -AD / 2 - 2), "D0C8B4")
			if (c + f) % 3 == 0:
				bx(ap, (2.4, 1.6, 1.2), (cx + 2, y + 0.9, -AD / 2 - 1), "E8E8E8")
	for f in range(low, full):  # broken floor plates sticking out of the break face (attached to the wall)
		bx(ap, (rnd.uniform(2, 5), 0.8, AD - rnd.uniform(2, 8)), (6 + 1.5, f * fh - 0.6, rnd.uniform(-2, 2)), CONC)
		bx(ap, (0.6, fh * 0.7, 2), (6.3, f * fh + 2, rnd.uniform(-8, 8)), RUST, metal=0.5)
	seg(ap, (6, fh * full - 4, -2), (19, fh * low - 0.5, -3), CONC2, thick=1.6, wide=16)  # slab: break to roof
	for i in range(5):
		s = rnd.uniform(2.5, 5)
		bx(ap, (s, s * 0.7, s), (rnd.uniform(8, 19), fh * low - 1 + s * 0.3, rnd.uniform(-8, 8)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-15, 15)))
	for x, y, w, h in ((4, fh * 7, 6, 10), (12, fh * 5, 8, 6), (-14, fh * 2, 4, 5)):
		bx(ap, (w, h, 0.3), (x, y, -AD / 2 - 0.35), SCORCH)
	ap.append(("cyl", (6, 5, 6), (-12, fh * full + 1.5, 2), "C8CCD0", {"seg": 10}))
	for i in range(7):
		s = rnd.uniform(3, 7)
		bx(ap, (s, s * 0.6, s), (rnd.uniform(-18, 22), s * 0.3 - 1, rnd.uniform(-20, -13)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-15, 15)))
	k.prop("Apartment", ap)

	# --- Office tower (mid): curtain-wall window bands and fins; the right part has collapsed four floors below the
	# left, its floor plates jut from the break, a slab leans from the break onto the lower roof, scorch marks. ---
	of = []
	OW, OD, oh = 34.0, 30.0, 6.0
	hi_f, lo_f = 14, 10
	parts = ((-6.5, 21.0, hi_f), (10.5, 13.0, lo_f))
	for x, w, nf in parts:
		bx(of, (w, oh * nf, OD), (x, oh * nf / 2 - 1, 0), "AEB6BE")
		for f in range(nf):
			bx(of, (w + 0.2, 3.2, 0.3), (x, f * oh + 2.4, -OD / 2 - 0.1), GLASS, rough=0.1, metal=0.4)
		bx(of, (w + 0.6, 1.0, OD + 0.6), (x, oh * nf - 0.5, 0), "8E969E")
	for f in range(hi_f):
		bx(of, (0.3, 3.2, OD + 0.2), (-OW / 2 - 0.1, f * oh + 2.4, 0), GLASS, rough=0.1, metal=0.4)
	for x in range(-15, 16, 6):
		nf = hi_f if x < 4 else lo_f
		bx(of, (0.8, oh * nf, 1.2), (x, oh * nf / 2 - 1, -OD / 2 - 0.5), "C8CED4")
	for f in range(lo_f, hi_f):
		bx(of, (rnd.uniform(2, 6), 0.8, OD - rnd.uniform(2, 10)), (4 + 1.8, f * oh - 0.6, rnd.uniform(-3, 3)), CONC)
		bx(of, (0.6, oh * 0.8, 1.2), (4.3, f * oh + 2, rnd.uniform(-10, 10)), RUST, metal=0.5)
	of.append(("box", (16, 1.6, 20), (11, oh * lo_f + 5.5, 0), CONC2, {"rot": (0, 0, -34)}))  # slab: break to roof
	for i in range(4):
		s = rnd.uniform(3, 6)
		bx(of, (s, s * 0.7, s), (rnd.uniform(8, 16), oh * lo_f - 1 + s * 0.3, rnd.uniform(-10, 10)), (ROCK, CONC2)[i % 2], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), 0))
	for x, y, w, h in ((2, oh * 12, 6, 14), (12, oh * 8, 8, 8), (-12, oh * 4, 6, 6)):
		bx(of, (w, h, 0.3), (x, y, -OD / 2 - 0.35), SCORCH)
	of.append(("cyl", (6, 5, 6), (-10, oh * hi_f + 1.5, 4), "C8CCD0", {"seg": 10}))
	bx(of, (OW + 8, 1.2, OD + 8), (0, -0.4, 0), "6A6A68")
	for i in range(6):
		s = rnd.uniform(3, 8)
		bx(of, (s, s * 0.6, s), (rnd.uniform(-20, 20), s * 0.3, rnd.uniform(-22, -16)), (ROCK, CONC2)[i % 2], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("Office", of)

	# --- Rubble (mid): concrete chunks of mixed size, a crushed car, a car flipped on its side, a toppled utility pole,
	# bent rebar, a cracked road slab, a scorch patch ---
	ru = []
	for i in range(11):
		s = rnd.uniform(1.5, 7)
		bx(ru, (s, s * rnd.uniform(0.4, 0.9), s * rnd.uniform(0.6, 1.2)), (rnd.uniform(-12, 12), s * 0.3 - 1, rnd.uniform(-5, 9)), (ROCK, CONC2, CONC, DUST, ASH)[i % 5], rot=(rnd.uniform(-25, 25), rnd.uniform(0, 90), rnd.uniform(-25, 25)))
	car(ru, 12, -2, "D8302F", yaw=24, state=1)
	car(ru, -14, 6, "E8E8E8", yaw=-60, state=2)
	ru.append(("cyl", (1.0, 26, 1.0), (-4, 2, -2), "9A9A96", {"seg": 8, "rot": (0, 30, 80)}))
	for i in range(5):
		bx(ru, (0.3, 6, 0.3), (-2 + i, 3, 2), RUST, metal=0.6, rot=(rnd.uniform(-35, 35), 0, rnd.uniform(-35, 35)))
	bx(ru, (14, 1.2, 10), (2, 0.6, 8), "4E4E50", rot=(8, 15, -6))
	bx(ru, (18, 0.2, 12), (0, -0.85, 2), SCORCH)
	k.prop("Rubble", ru)

	# --- Kaiju corpse (hero) with its two gantries: a huge reddish-brown beast lying on its belly, faceted rough hide
	# covered in rocky ridged plates, a horned head with a toothed snout on the ground, a clawed forelimb toward the
	# road, the rear stripped to bleached ribs, a stake-and-rope line along the back, teal lattice gantries with blue and
	# yellow ropes hanging onto it, white-suited sweepers on the ropes and the ground, skip bins.
	# Local +X head to tail, -Z (its flank) to the road. ---
	kc = []
	body = [(-50, 30, 0, 92, 60, 72), (0, 34, 0, 96, 66, 76), (48, 30, 0, 84, 56, 68)]
	for x, y, z, sx, sy, sz in body:
		kc.append(("ball", (sx, sy, sz), (x, y, z), FLESH, {"subdiv": 2}))
	kc.append(("ball", (44, 32, 40), (-98, 20, -6), FLESH2, {"subdiv": 2}))
	kc.append(("cyl", (26, 42, 22), (-130, 14, -8), FLESH2, {"rot": (0, 0, -90), "taper": 0.55, "seg": 8}))
	bx(kc, (40, 5, 20), (-128, 2.5, -8), "6A2E24", rot=(0, 0, -4))
	for i in range(7):
		for zz in (-17, 1):
			kc.append(("cone", (2.4, 4.5, 2.4), (-145 + i * 4.5, 6.5, zz), BONE, {"seg": 5}))
	for s in (-1, 1):
		bx(kc, (16, 4, 5), (-110, 30, -6 + s * 13), PLATE, rot=(0, s * 10, -14))
		kc.append(("cone", (6, 30, 6), (-88, 40, -6 + s * 12), BONE2, {"rot": (s * 18, 0, 55), "seg": 8}))
	bx(kc, (5, 1.4, 1), (-112, 25, -26.5), "2A2020")
	# rocky ridged plates over the back and the road flank (faceted chunks in three tones)
	for i in range(56):
		x = rnd.uniform(-90, 80)
		bi = min(body, key=lambda b: abs(b[0] - x))
		a = rnd.uniform(-1.3, 0.25) * math.pi / 2  # mostly the road flank (-Z) and the top
		ry, rzz = bi[4] / 2, bi[5] / 2
		px = x
		py = bi[1] + math.cos(a) * ry * 0.92
		pz = math.sin(a) * rzz * 0.92
		s = rnd.uniform(6, 14)
		bx(kc, (s, s * 0.35, s * rnd.uniform(0.6, 1.1)), (px, py, pz), (FLESH2, FLESH3, PLATE, "8A3E30")[i % 4], rot=(math.degrees(a) + rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-20, 20)))
	for i in range(9):  # dorsal ridge plates
		x = -80 + i * 17
		h = 22 - abs(i - 3) * 2.2
		kc.append(("cone", (12, h, 6), (x, 60 - abs(x) * 0.12 + h / 2 - 4, 0), PLATE, {"seg": 4, "rot": (0, 45, -12)}))
	kc.append(("cyl", (16, 46, 16), (-62, 12, -40), FLESH2, {"rot": (60, 0, 0), "seg": 8}))
	kc.append(("ball", (26, 12, 22), (-62, 4, -60), FLESH2, {"subdiv": 2}))
	for c in (-8, 0, 8):
		kc.append(("cone", (4, 12, 4), (-62 + c, 3, -72), BONE2, {"rot": (-80, 0, 0), "seg": 6}))
	kc.append(("ball", (40, 30, 36), (70, 14, -30), FLESH2, {"subdiv": 2}))
	for i in range(7):
		x = 92 + i * 11
		bx(kc, (8, 7, 8), (x, 34 - i * 2.4, 0), BONE, rot=(0, 0, 8))
		r = 30 - i * 2.6
		for s in (-1, 1):
			bx(kc, (3, r, 3), (x, 30 - i * 2.4 - r * 0.2, s * r * 0.45), BONE, rot=(s * 58, 0, 0))
			bx(kc, (3, r * 0.8, 3), (x, 16 - i * 1.8 - r * 0.2, s * r * 0.92), BONE2, rot=(-s * 10, 0, 0))
	for i in range(8):
		a = i * 0.22
		kc.append(("ball", (22 - i * 2, 16 - i * 1.5, 22 - i * 2), (172 + i * 15, 6 - i * 0.5, 30 * math.sin(a)), FLESH2 if i < 3 else BONE2, {"subdiv": 1}))
	# stake-and-rope line along the back (tall bright stakes, thick white lines, orange flags)
	stakes = [(x, 60 - abs(x) * 0.12 + 1) for x in range(-75, 86, 12)]
	for x, y in stakes:
		kc.append(("cyl", (1.2, 10, 1.2), (x, y + 3, -10), "C8CED4", {"seg": 6, "metal": 0.6}))
		bx(kc, (2.2, 1.4, 0.2), (x + 1.2, y + 7.4, -10), STRIPE)
	for (x0, y0), (x1, y1) in zip(stakes, stakes[1:]):
		seg(kc, (x0, y0 + 6, -10), (x1, y1 + 6, -10), "F2F2EE", thick=0.7)
		seg(kc, (x0, y0 + 2, -10), (x1, y1 + 2, -10), "F2F2EE", thick=0.7)
	# gantries at x = -40 and 80, legs at z = +-82; ropes from the top girders down onto the corpse
	GH, GS = 96.0, 82.0
	for gx in (-40, 80):
		for z in (-GS, GS):
			for x in (-8, 8):
				bx(kc, (2.2, GH, 2.2), (gx + x, GH / 2 - 1, z), TEAL, metal=0.4)
			for y in range(0, int(GH) - 8, 14):
				bx(kc, (16, 1, 1), (gx, y + 7, z), TEAL, metal=0.4)
				bx(kc, (0.8, 21, 0.8), (gx, y + 7, z), "286A66", rot=(0, 0, 50))
			bx(kc, (22, 2, 6), (gx, 0, z), "3A3E46")
		for y in (GH, GH - 8):
			for x in (-6, 6):
				bx(kc, (2, 2, GS * 2 + 6), (gx + x, y, 0), TEAL, metal=0.4)
		for i in range(8):
			z = -GS + (i + 0.5) * GS * 2 / 8
			bx(kc, (0.8, 11, 0.8), (gx + 6, GH - 4, z), "286A66", rot=(45 if i % 2 else -45, 0, 0))
		bx(kc, (16, 6, 10), (gx, GH - 4, -22), "E8C840")
		for i, z in enumerate(range(-70, 1, 10)):  # 8 ropes per gantry, landing on the back and the road flank
			bottom = 66 if z > -30 else 66 + (z + 30) * 1.1
			bottom = max(bottom, 6)
			seg(kc, (gx + (i % 3 - 1) * 3, GH - 9, z), (gx + (i % 3 - 1) * 5, bottom, z + 2), (ROPE_B, ROPE_Y)[i % 2], thick=0.5)
	# sweepers: on the flank ropes (large, readable), on the back line, and on the ground
	for x, y, z in ((-58, 36, -36), (-36, 22, -40), (-12, 44, -32), (14, 28, -40), (40, 40, -32), (64, 20, -36)):
		worker(kc, x, y, z, 1.7)
	for x in (-50, -10, 30, 70):
		worker(kc, x, 60 - abs(x) * 0.12, -4, 1.6)
	for x, z in ((-30, -70), (-20, -74), (30, -66), (90, -62), (110, -54), (0, -80)):
		worker(kc, x, -1, z, 1.6)
	for x, z in ((-10, -88), (60, -80)):
		bx(kc, (14, 6, 8), (x, 2, z), "2F5FA8")
		bx(kc, (14.4, 0.6, 8.4), (x, 5.2, z), "244A84")
	kc.append(("cyl", (320, 1, 150), (20, -0.9, -6), "4A4642", {"seg": 18}))
	for i in range(14):
		s = rnd.uniform(5, 12)
		bx(kc, (s, s * 0.6, s), (rnd.uniform(-150, 200), s * 0.3 - 1, rnd.choice((-1, 1)) * rnd.uniform(50, 70)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("KaijuCorpse", kc)

	# --- Sweeper van set (mid): one-box van with a sloped nose and raked windscreen, side windows, wheel arches, a plain
	# red band, a raised roof rack with crew sitting on top, cones and a light tower. Nose to -Z. ---
	va = []
	bx(va, (8, 6.6, 15), (0, 3.6, 1.5), "F4F4F2")
	va.append(("wedge", (8, 3.0, 4.4), (0, 2.0, -8.2), "F4F4F2"))  # sloped bonnet
	bx(va, (8, 1.6, 4.4), (0, 0.1, -8.2), "F4F4F2")
	bx(va, (7.4, 3.6, 0.3), (0, 5.1, -6.0), "34404E", rough=0.1, rot=(-28, 0, 0))  # raked windscreen
	for s in (-1, 1):
		for z in (-3.6, 1.0, 5.6):
			bx(va, (0.2, 2.4, 3.8), (s * 4.05, 5.2, z), "34404E", rough=0.1)
		bx(va, (0.25, 0.9, 15), (s * 4.05, 2.6, 1.5), "C82828")
		for z in (-5.5, 6.0):
			bx(va, (0.3, 1.6, 4.4), (s * 4.0, 1.2, z), "2A2A2A")
			va.append(("cyl", (2.8, 1, 2.8), (s * 3.6, 0.4, z), "1A1A1A", {"rot": (0, 0, 90), "seg": 8}))
	for z in (-4, 2, 8):
		bx(va, (0.6, 0.8, 0.6), (-3.4, 7.3, z), "9AA0A6", metal=0.6)
		bx(va, (0.6, 0.8, 0.6), (3.4, 7.3, z), "9AA0A6", metal=0.6)
		bx(va, (7.6, 0.4, 0.5), (0, 7.8, z), "9AA0A6", metal=0.6)
	for x in (-3.4, 3.4):
		bx(va, (0.4, 0.4, 13), (x, 8.0, 2), "9AA0A6", metal=0.6)
	for x, z in ((-1.8, -1.5), (1.8, 3.5)):
		worker(va, x, 7.6, z, 1.0, sit=True)
	worker(va, 8, -1, -4)
	worker(va, 9.5, -1, 4)
	for i in range(4):
		va.append(("cone", (1.6, 3, 1.6), (-8, 0.5, -10 + i * 6), STRIPE, {"seg": 8}))
	va.append(("cyl", (0.6, 18, 0.6), (-10, 8, 14), "6A6E74", {"seg": 6}))
	bx(va, (6, 3, 1), (-10, 17, 14), "E8ECF0", emit=1.2)
	bx(va, (5, 3, 5), (-10, 0.5, 14), "E8C840")
	k.prop("SweeperVan", va)

	# --- Defense Force HQ (hero) with the observation tower beside it: one wide symmetric white 8-floor block, end
	# pavilions with roof masts, a central tower with a tall glass strip, pilasters and portico, a regular window grid,
	# the parking lot with white cars and a tree row in front; the tower on the viewer's left (+X): ribbed shaft,
	# glazed ring cab, radar domes, lattice mast. Badge: an invented orange diamond (not the real insignia). ---
	hq = []
	HW, HD, FH, NF = 230.0, 36.0, 8.0, 8
	HH = FH * NF
	bx(hq, (HW, HH, HD), (0, HH / 2 - 1, 0), BASE)
	for s in (-1, 1):
		px = s * (HW / 2 - 15)
		bx(hq, (30, HH + 6, HD + 4), (px, (HH + 6) / 2 - 1, -2), "E4E4DE")
		bx(hq, (31, 1.6, HD + 5), (px, HH + 5.6, -2), BASE2)
		bx(hq, (0.6, 24, 0.6), (px + s * 6, HH + 17, 0), "8A9096")
		bx(hq, (6, 0.4, 0.4), (px + s * 6, HH + 22, 0), "8A9096")
		bx(hq, (4, 0.4, 0.4), (px + s * 6, HH + 26, 0), "8A9096")
	for f in range(NF):
		y = f * FH + 4
		for c in range(26):
			x = -HW / 2 + 5 + c * 8.8
			if abs(x) < 17:
				continue
			pav = abs(x) > HW / 2 - 30
			bx(hq, (5.6, 4.0, 0.4), (x, y, -HD / 2 - (4.1 if pav else 0.1)), WINDOW, rough=0.2)
		bx(hq, (HW - 60, 0.5, 0.5), (0, f * FH + 1.4, -HD / 2 - 0.3), "D4D4CE")
	bx(hq, (32, HH + 14, HD + 10), (0, (HH + 14) / 2 - 1, -2), "F2F2EE")
	bx(hq, (10, HH + 4, 0.6), (0, (HH + 4) / 2 + 6, -HD / 2 - 7.2), "3E5670", rough=0.1, metal=0.4)
	for q in range(3):
		bx(hq, (0.6, HH + 4, 0.8), (-3.3 + q * 3.3, (HH + 4) / 2 + 6, -HD / 2 - 7.5), "E8E8E8")
	for f in range(NF):
		bx(hq, (10.4, 0.6, 0.9), (0, f * FH + 8, -HD / 2 - 7.5), "E8E8E8")
	for s in (-1, 1):
		bx(hq, (5, HH + 14, 1.2), (s * 13.5, (HH + 14) / 2 - 1, -HD / 2 - 7.4), "FAFAF6")
		for f in range(NF):
			bx(hq, (5, 3.4, 0.4), (s * 8.5, f * FH + 4, -HD / 2 - 7.2), WINDOW)
	bx(hq, (34, 1.6, HD + 12), (0, HH + 13.6, -2), BASE2)
	bx(hq, (5, 5, 0.6), (0, HH + 9, -HD / 2 - 7.6), STRIPE, emit=0.4, rot=(0, 0, 45))
	bx(hq, (2.6, 2.6, 0.4), (0, HH + 9, -HD / 2 - 7.9), "FFFFFF", rot=(0, 0, 45))
	bx(hq, (26, 1.4, 12), (0, 8.5, -HD / 2 - 13), "F2F2EE")
	for x in (-12, 12):
		bx(hq, (1.4, 9, 1.4), (x, 3.5, -HD / 2 - 18), "D8D8D4")
	bx(hq, (14, 7, 0.4), (0, 2.5, -HD / 2 - 7.4), "2E4256", rough=0.1)
	bx(hq, (0.5, 22, 0.5), (0, HH + 24, -2), "8A9096")
	bx(hq, (HW + 20, 0.6, 80), (0, -0.7, -HD / 2 - 48), "5A5C60")
	bx(hq, (8, 0.62, 80), (0, -0.68, -HD / 2 - 48), "6E7074")
	for z in (-HD / 2 - 40, -HD / 2 - 72):
		for s in (-1, 1):
			for c in range(9):
				x = s * (12 + c * 11)
				bx(hq, (0.5, 0.62, 14), (x + 5.5 * s, -0.68, z), "E8E8E8")
				if (c * 5 + s + int(z)) % 4 != 0:
					car(hq, x + 2.7 * s, z, ("F2F2F2", "C8CCD0", "E8E8E8", "9AA0A8")[c % 4])
	for c in range(16):
		x = -HW / 2 + 8 + c * 14.5
		if abs(x) < 20:
			continue
		hq.append(("ball", (10, 8, 8), (x, 3, -HD / 2 - 26), "3E6A3A", {"subdiv": 1}))
	ox, oz = HW / 2 + 40, 6.0  # observation tower
	bx(hq, (40, 16, 30), (ox, 7, oz), BASE)
	for y in (3, 9):
		for x in range(-16, 17, 6):
			bx(hq, (4, 3, 0.4), (ox + x, y, oz - 15.2), WINDOW)
	hq.append(("cyl", (14, 120, 14), (ox, 60, oz), "E8E8E2", {"seg": 16}))
	for i in range(8):
		a = i / 8 * math.tau
		bx(hq, (1.6, 120, 1.6), (ox + math.cos(a) * 7, 60, oz + math.sin(a) * 7), "C8CCD0")
	hq.append(("cyl", (30, 2, 30), (ox, 120, oz), BASE2, {"seg": 20}))
	hq.append(("cyl", (26, 10, 26), (ox, 126, oz), "6A90B0", {"seg": 20, "rough": 0.1, "metal": 0.3, "emit": 0.2}))
	for i in range(10):
		a = i / 10 * math.tau
		bx(hq, (0.6, 10, 0.6), (ox + math.cos(a) * 13.1, 126, oz + math.sin(a) * 13.1), "F2F2EE")
	hq.append(("cyl", (32, 2, 32), (ox, 132, oz), "F2F2EE", {"seg": 20}))
	hq.append(("cyl", (32.4, 2.4, 32.4), (ox, 122.5, oz), "F2F2EE", {"seg": 20}))
	hq.append(("cyl", (18, 6, 18), (ox, 136, oz), BASE, {"seg": 16}))
	for s in (-1, 1):
		hq.append(("cyl", (1.4, 4, 1.4), (ox + s * 6, 141, oz), BASE2, {"seg": 6}))
		hq.append(("ball", (8, 8, 8), (ox + s * 6, 146, oz), "FFFFFF", {"subdiv": 2, "smooth": True}))
	for j in range(5):
		y = 140 + j * 7
		w = 4 - j * 0.5
		for sx in (-1, 1):
			for sz in (-1, 1):
				bx(hq, (0.5, 7, 0.5), (ox + sx * w / 2, y + 3.5, oz + sz * w / 2), "D8D8D8")
		bx(hq, (w + 3, 0.4, 0.4), (ox, y + 7, oz), "D8D8D8")
		bx(hq, (0.4, 0.4, w + 3), (ox, y + 7, oz), "D8D8D8")
	hq.append(("ball", (1.6, 1.6, 1.6), (ox, 176, oz), "FF2B2B", {"emit": 8}))
	k.prop("DefenseHQ", hq)

	# --- Hangar (mid): arched roof, big sliding doors with seams, abstract orange chevrons on the doors, door-base
	# hazard stripe, side office annex, front apron, an armoured Defense Force vehicle with a mounted cannon ---
	hg = []
	hg.append(("cyl", (56, 64, 40), (0, 0, 2), "8C949C", {"rot": (90, 0, 0), "seg": 16, "metal": 0.4, "rough": 0.5}))
	bx(hg, (58, 2, 66), (0, -1, 2), "5A5E66")
	bx(hg, (44, 18, 1), (0, 8, -30.4), "4A525C", metal=0.3)
	for x in (-16.5, -5.5, 5.5, 16.5):
		bx(hg, (0.5, 18, 1.4), (x, 8, -30.8), "2E343C")
	bx(hg, (46, 1.2, 1.6), (0, 17.4, -30.8), "2E343C")
	for i in range(3):
		for s in (-1, 1):
			bx(hg, (8, 1.4, 0.6), (s * 3.2, 9 + i * 2.6, -31.2), STRIPE, emit=0.3, rot=(0, 0, s * 25))
	for x in range(-22, 23, 4):
		bx(hg, (2, 1.2, 0.4), (x, 0.2, -31.1), ("E8C840", "1A1A1A")[(x // 4) % 2])
	bx(hg, (20, 12, 40), (38, 5, 0), BASE)
	for z in range(-14, 15, 7):
		bx(hg, (0.4, 3, 4), (48.1, 7, z), WINDOW)
	for x in (31, 37, 43):
		bx(hg, (4, 3, 0.4), (x, 7, -20.1), WINDOW)
	bx(hg, (21, 1, 41), (38, 11.5, 0), BASE2)
	bx(hg, (60, 0.5, 30), (0, -0.8, -46), "6A6C70")
	for x in (-12, 12):
		bx(hg, (1, 0.52, 30), (x, -0.78, -46), "E8C840")
	vz = -46
	bx(hg, (10, 5, 26), (0, 4, vz), OLIVE)
	bx(hg, (9, 4, 7), (0, 7, vz - 8), "3E4636")
	bx(hg, (8, 1.2, 2.4), (0, 8, vz - 11.8), "26303A", rough=0.1, rot=(-25, 0, 0))
	for z in (-9, -3, 3, 9):
		for x in (-5.4, 5.4):
			hg.append(("cyl", (4, 1.6, 4), (x, 1.2, vz + z), "1C1C1C", {"rot": (0, 0, 90), "seg": 10}))
	hg.append(("cyl", (7, 3, 7), (0, 8, vz + 5), "3E4636", {"seg": 10}))
	hg.append(("cyl", (1.4, 20, 1.4), (0, 10, vz - 4), "2A2E26", {"rot": (80, 0, 0), "seg": 8}))
	k.prop("Hangar", hg)

	# --- Base wall (mid): a low white wall (5 tall, so the runner sees over it) with navy band and orange stripe,
	# sparse fence posts with two wires, a pillar with a lamp ---
	bw = []
	bx(bw, (28, 5, 2.4), (0, 1.5, 0), BASE)
	bx(bw, (28.2, 1.0, 2.6), (0, 2.4, 0), NAVY)
	bx(bw, (28.2, 0.5, 2.6), (0, 3.3, 0), STRIPE, emit=0.3)
	bx(bw, (28.4, 0.6, 3.0), (0, 4.3, 0), BASE2)
	for x in range(-12, 13, 8):
		bx(bw, (0.3, 4, 0.3), (x, 6.6, 0), "7A8086", metal=0.5)
	for y in (6.0, 8.2):
		bx(bw, (28, 0.2, 0.2), (0, y, 0), "7A8086", metal=0.5)
	bx(bw, (2.6, 8, 3), (14, 3, 0), BASE2)
	bx(bw, (0.5, 6, 0.5), (14, 10, 0), "6A7078")
	bx(bw, (3, 0.8, 1.2), (13, 13.3, -0.6), "FFF2D0", emit=3.0)
	k.prop("BaseWall", bw)

	# --- Rail cannon (hero): the anti-kaiju rail gun lying low along a long rail bed: ballast, two rails and sleepers,
	# a heavy carriage, a massive barrel at 6 degrees, a dense stack of ring coils at the breech, a riveted square
	# muzzle, tall striped capacitor tanks on both sides, dozens of drooping cable bundles. Barrel to +X. ---
	rg = []
	bx(rg, (250, 1.2, 30), (10, -0.6, 0), "6A645C")
	for z in (-7, 7):
		bx(rg, (250, 1.2, 1.6), (10, 0.6, z), "8A8E94", metal=0.7)
	for x in range(-112, 134, 7):
		bx(rg, (2.2, 0.7, 20), (x, 0.1, 0), "4A4038")
	bx(rg, (60, 12, 26), (-30, 6.6, 0), "4E545C", metal=0.4)
	bx(rg, (40, 8, 22), (-30, 16.6, 0), "5A6068", metal=0.4)
	for x in (-55, -5):
		for z in (-9, 9):
			rg.append(("cyl", (5, 3, 5), (x, 2.6, z), "2A2A2A", {"rot": (90, 0, 0), "seg": 10}))
	el = 6.0
	ax, ay = -46.0, 26.0
	ce, se_ = math.cos(math.radians(el)), math.sin(math.radians(el))

	def along(t):
		return (ax + ce * t, ay + se_ * t, 0.0)

	rg.append(("cyl", (20, 160, 20), along(80), "3A3E44", {"rot": (0, 0, el - 90), "seg": 16, "metal": 0.6, "rough": 0.35}))
	for i in range(12):  # coil stack at the breech
		rg.append(("cyl", (40 - (i % 2) * 4, 3.2, 40 - (i % 2) * 4), along(2 + i * 3.6), ("8A9098", "5E666E")[i % 2], {"rot": (0, 0, el - 90), "seg": 18, "metal": 0.6}))
	for i in range(5):  # a few bands down the barrel
		rg.append(("cyl", (23, 2, 23), along(60 + i * 18), "5E666E", {"rot": (0, 0, el - 90), "seg": 16, "metal": 0.6}))
	mx, my, _ = along(162)
	for dy, dz, w, h in ((12, 0, 30, 6), (-12, 0, 30, 6), (0, 12, 6, 18), (0, -12, 6, 18)):
		rg.append(("box", (10, h, w), (mx, my + dy, dz), "2E3238", {"rot": (0, 0, el)}))
	for dy in (-12, 12):
		for dz in (-11, -5.5, 0, 5.5, 11):
			rg.append(("box", (1.2, 1.2, 1.2), (mx - 5.4, my + dy, dz), "8A9098", {"rot": (0, 0, el)}))
	tanks = []
	for s in (-1, 1):
		for j, x in enumerate((-80, -62, -44, -26)):
			tz = s * (26 + (j % 2) * 4)
			rg.append(("cyl", (10, 40, 10), (x, 19, tz), "C8CCD0", {"seg": 12, "metal": 0.3}))
			rg.append(("cyl", (10.4, 2, 10.4), (x, 30, tz), STRIPE, {"seg": 12}))
			rg.append(("cyl", (7, 2, 7), (x, 40, tz), "8A9098", {"seg": 12}))
			tanks.append((x, 40, tz))
	for i, (tx, ty, tz) in enumerate(tanks):  # 3 cables per tank, each sagging between the tank top and a coil
		for q in range(3):
			cx_, cy_, _ = along(4 + ((i * 3 + q) % 12) * 3.6)
			cz = math.copysign(18, tz)
			mid = ((tx + cx_) / 2, min(ty, cy_ + 18) - 9 - q * 2, (tz + cz) / 2 + q)
			seg(rg, (tx, ty, tz + q - 1), mid, ("1E1E1E", "2A2A2A", "3A2A1A")[q], thick=0.9)
			seg(rg, mid, (cx_, cy_ + 10, cz), ("1E1E1E", "2A2A2A", "3A2A1A")[q], thick=0.9)
	car(rg, -20, -30, OLIVE)
	bx(rg, (7.2, 5, 9), (-20, 3, -26), "3E4636")
	k.prop("Railgun", rg)

	# --- City block (mid): a 160-stud tile of the street grid: asphalt streets on two edges with centre dashes,
	# raised sidewalks, low-rise blocks (some collapsed, scorched), a crater with a rubble rim, wrecked cars, poles ---
	cb = []
	T = 160.0
	bx(cb, (T, 0.4, 14), (0, -0.75, -T / 2 + 7), ASPHALT)
	bx(cb, (14, 0.4, T), (-T / 2 + 7, -0.75, 0), ASPHALT)
	for i in range(8):
		bx(cb, (8, 0.42, 0.6), (-T / 2 + 18 + i * 19, -0.74, -T / 2 + 7), "D8D8D0")
		bx(cb, (0.6, 0.42, 8), (-T / 2 + 7, -0.74, -T / 2 + 18 + i * 19), "D8D8D0")
	bx(cb, (T - 14, 0.8, 3), (7, -0.5, -T / 2 + 15.5), WALK)
	bx(cb, (3, 0.8, T - 14), (-T / 2 + 15.5, -0.5, 7), WALK)
	bx(cb, (T - 17, 0.3, T - 17), (8.5, -0.8, 8.5), "9C968A")
	lows = [(-40, -40, 30, 3, "C8C0B0"), (10, -42, 34, 2, "B8B4AC"), (52, -40, 26, 4, "D4CCB8"), (-44, 20, 28, 2, "B0A898"), (50, 30, 30, 3, "C0BCB4")]
	for i, (x, z, w, nf, col) in enumerate(lows):
		h = nf * 7
		broken = i in (1, 3)
		bx(cb, (w, h * (0.55 if broken else 1), 22), (x, h * (0.55 if broken else 1) / 2 - 1, z), col)
		for f in range(nf if not broken else 1):
			bx(cb, (w - 3, 2.4, 0.3), (x, f * 7 + 3.5, z - 11.1), WINDOW)
		if broken:
			cb.append(("wedge", (w, h * 0.6, 12), (x, h * 0.55 + h * 0.3 - 1, z + 5), col))
			bx(cb, (w * 0.6, 1, 14), (x + 3, h * 0.55, z - 6), CONC, rot=(18, 10, -8))
			bx(cb, (w * 0.8, h * 0.4, 0.3), (x, h * 0.3, z - 11.2), SCORCH)
		else:
			bx(cb, (w + 0.6, 0.8, 22.6), (x, h - 0.6, z), "8E8A82")
	cb.append(("cyl", (34, 0.6, 34), (8, -0.6, 20), "26221E", {"seg": 12}))  # crater
	cb.append(("cyl", (22, 0.8, 22), (8, -0.5, 20), "1A1816", {"seg": 10}))
	for i in range(9):
		a = i / 9 * math.tau
		s = rnd.uniform(3, 6)
		bx(cb, (s, s * 0.6, s), (8 + math.cos(a) * 18, s * 0.3 - 1, 20 + math.sin(a) * 18), (ROCK, CONC2, DUST)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	car(cb, -30, -T / 2 + 4, "2F6FD8", yaw=8)
	car(cb, 40, -T / 2 + 10, "E8E8E8", yaw=-30, state=1)
	car(cb, -T / 2 + 5, 40, "D8302F", yaw=95, state=2)
	for x in (-50, 0, 50):
		cb.append(("cyl", (1.0, 26, 1.0), (x, 12, -T / 2 + 16.5), "9A9A96", {"seg": 6}))
		bx(cb, (7, 0.5, 0.5), (x, 24, -T / 2 + 16.5), "6A6A66")
	k.prop("CityBlock", cb)

	# --- Smoke column (mid): scorched base with embers, a column of grey puffs widening as it rises ---
	sm = [("cyl", (40, 0.4, 40), (0, -0.8, 0), SCORCH, {"seg": 10})]
	for i in range(5):
		s = rnd.uniform(3, 6)
		sm.append(("ball", (s, s * 0.6, s), (rnd.uniform(-10, 10), 0.5, rnd.uniform(-10, 10)), "FF7A2A", {"subdiv": 1, "emit": 3.0}))
	y = 8.0
	for i in range(9):  # each layer: three overlapping puffs, drifting and widening with height
		s = 20 + i * 8
		for j in range(3):
			sm.append(("ball", (s * rnd.uniform(0.7, 1.0), s * rnd.uniform(0.6, 0.8), s * rnd.uniform(0.7, 1.0)), (i * i * 0.6 + rnd.uniform(-s, s) * 0.35, y + rnd.uniform(-s, s) * 0.2, rnd.uniform(-s, s) * 0.35), ("3A3836", "4A4644", "5E5A56", "767270", "8E8A86")[min(4, i // 2)], {"subdiv": 2, "smooth": True}))
		y += s * 0.6
	k.prop("Smoke", sm)

	# --- layout ---
	k.ground(DUST, margin=500)
	supports(k, "3A3E46")
	city_end, base0 = 3900.0, 4050.0
	corpses = [(700.0, -150.0, 0.8), (2530.0, 150.0, 1.0)]
	skip = [(d - 300, d + 300) for d, _, _ in corpses]
	side = skip + [(3300.0, 3540.0)]  # right side clear under the side review camera (build_track 05_side)
	gun = skip + [(3300.0, 3660.0)]  # open ground round the rail cannon
	row(k, 40, city_end, 30, (-28, 28), ["Rubble", "Rubble", "SweeperVan"], jitter=5, turn=math.pi, chance=0.7, scale=(0.8, 1.3))
	row(k, 40, city_end, 46, (-58,), ["Apartment", "Apartment", "Office"], jitter=4, skip=gun, turn=0.25, lean=0.2)
	row(k, 40, city_end, 46, (58,), ["Apartment", "Apartment", "Office"], jitter=4, skip=side, turn=0.25, lean=0.2)
	row(k, 60, city_end, 62, (-110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=gun, turn=0.3, lean=0.25)
	row(k, 60, city_end, 62, (110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=side, turn=0.3, lean=0.25)
	for d, off, s in corpses:
		put(k, "KaijuCorpse", d, off, s, clear=60)
		for dd in (-60, 0, 60, 120):
			put(k, "SweeperVan", d + dd, 32 if off > 0 else -32, turn=k.rng.uniform(-0.4, 0.4))
	put(k, "Railgun", 3480, -80, clear=50)
	# Base: low perimeter wall, hangars (kept out of the HQ view), a second rail cannon by the last straight
	row(k, base0, k.length - 80, 28, (-31, 31), ["BaseWall"])
	row(k, base0 + 60, k.length - 100, 110, (75, -75), ["Hangar"], skip=[(4250, 4950)])
	row(k, base0 + 100, k.length - 100, 140, (150, -150), ["Hangar", "Apartment"], jitter=10, skip=[(4250, 4950)])
	put(k, "Railgun", 6620, 90, clear=60)
	# HQ (with its tower) square-on to run shot 3, ahead-left of the camera
	eye, t, right = shot_eye(k, 0.62)
	a = math.radians(-16)
	fwd = t * math.cos(a) + right * math.sin(a)
	hqc = eye + fwd * 430
	look = eye - hqc
	k.place("DefenseHQ", (hqc.x, -1.0, hqc.z), math.atan2(-look.x, -look.z))
	print("KAIJUBASE HQ clear", round(min((Vector((w.x, 0, w.z)) - Vector((hqc.x, 0, hqc.z))).length for w in k.wps)))
	# Street grid tiles over the city and the infield, then smoke and the far skyline
	avoid = [(hqc.x, hqc.z, 260)]
	for d, off, s in corpses + [(3480, -80, 1.0), (6620, 90, 1.0)]:
		x, z, _ = local(k, d, off, 0, 0)
		avoid.append((x, z, 200))
	x0, z0 = k.lo.x - 400, k.lo.z - 400
	gx = x0
	while gx < k.hi.x + 400:
		gz = z0
		while gz < k.hi.z + 400:
			if k.clear_of_road(gx, gz, 190) and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in avoid):
				k.place("CityBlock", (gx, -1.0, gz), 0.0)
				if k.rng.random() < 0.18:
					k.place(k.rng.choice(["Office", "Apartment"]), (gx + 10, -1.0, gz + 10), k.rng.choice((0, math.pi / 2, math.pi)), k.rng.uniform(1.0, 1.8))
			gz += 160
		gx += 160
	placed, tries = 0, 0
	while placed < 9 and tries < 400:
		tries += 1
		x = k.rng.uniform(k.lo.x - 200, k.hi.x + 200)
		z = k.rng.uniform(k.lo.z - 200, k.hi.z + 200)
		if k.clear_of_road(x, z, 120) and all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid[:1]):
			k.place("Smoke", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(0.8, 1.4))
			placed += 1
	k.field(70, ["Office", "Apartment", "Office"], clearance=420, margin=480, scale=(1.2, 2.4))
	# Clear day with big cumulus clouds (sky dressing, the game's Sky clouds; not prop assets)
	k.sky(
		[(0.0, "DDEAF2"), (0.04, "B8D4EC"), (0.18, "78AEE0"), (0.5, "3F7CC8"), (1.0, "2A5CA8")],
		strength=1.0,
		sun=(4.0, "FFF0D8", 38, 220),
	)
	bm = bmesh.new()
	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	for i in range(22):
		ang = i / 22 * math.tau + rnd.uniform(-0.1, 0.1)
		dist = span * rnd.uniform(1.1, 1.6)
		cx, cz, cy = c.x + math.cos(ang) * dist, c.z + math.sin(ang) * dist, rnd.uniform(380, 650)
		for j in range(rnd.randint(5, 8)):
			r = rnd.uniform(60, 130) * (1.2 if j == 0 else 1.0)
			geom = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
			loc = kit.rb(cx + rnd.uniform(-160, 160), cy + rnd.uniform(-10, 60) + (r * 0.3 if j < 2 else 0), cz + rnd.uniform(-90, 90))
			bmesh.ops.transform(bm, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((r * 1.3, r, r * 0.75, 1)), verts=geom["verts"])
	cl = bpy.data.objects.new("SkyClouds", bpy.data.meshes.new("SkyClouds"))
	bm.to_mesh(cl.data)
	bm.free()
	for poly in cl.data.polygons:
		poly.use_smooth = True
	cl.data.materials.append(k.mat("FFFFFF", rough=1.0, emit=0.35))
	k.col.objects.link(cl)
