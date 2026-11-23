"""World 2 Track 5: Kaiju Base (Kaiju No. 8). Rebuilt 2026-11-23 for a closer 1-1 read of the source (owner: "more detail
and closer reference to source material"); landmarks and their references: docs/world2_refs/KaijuBase.md.
First half: a kaiju-wrecked Tokyo district under a clear blue sky (balconied apartment blocks and office towers with
torn tops, crushed cars, rubble) where a giant kaiju corpse lies across the blocks and the Monster Sweeper crews clean
it up (white hooded suits on ropes, stakes and lines along its back, part of it already stripped to the ribs, teal
lattice gantry cranes over it, white vans with roof racks, cones and light towers). Second half: the Defense Force's
Tachikawa base (perimeter wall, the wide white HQ with its central entrance tower and parking lot, the slender
observation tower with radar domes and lattice mast, hangars with armoured vehicles, the anti-kaiju rail cannon).
Rules (design doc 5, WORLD2_SPEC): in-house primitives only; no text and no real insignia (the base badge is an
invented orange diamond, the sweeper vans carry a plain red band); the corpse is intact or bare bone, no wounds.
Props 24+ studs from the centre line. Budget: 12 unique meshes (road pieces excluded).
Proposed look; the owner approves the render set (design doc 4.46)."""

import math
import random

from mathutils import Matrix, Vector

DUST, ASH, CONC, CONC2, RUST = "6E6A62", "4A4A4C", "C8C2B6", "8A9098", "8A5A3A"
ROCK, WINDOW, GLASS = "5C5650", "2A3440", "6E8EAA"
FLESH, FLESH2, PLATE, BONE, BONE2 = "A0503E", "7E3A2E", "4E4A52", "E6DCC4", "C8BCA0"
SUIT, TEAL, ROPE_Y, ROPE_T = "F2F2EE", "2F7F7A", "E8C840", "3AA8B8"
BASE, BASE2, STRIPE, NAVY, OLIVE = "ECECE6", "A8AEB4", "FF8A1E", "2E3E58", "4A5240"


def bx(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def worker(p, x, y, z, lean=0):
	"""A Monster Sweeper in a white hooded suit (no face): body, hood, backpack, legs."""
	bx(p, (1.8, 2.6, 1.2), (x, y + 2.6, z), SUIT, rot=(lean, 0, 0))
	p.append(("ball", (1.5, 1.6, 1.5), (x, y + 4.5, z), SUIT, {"subdiv": 1}))
	bx(p, (1.0, 0.7, 0.2), (x, y + 4.4, z - 0.7), "3A4048")  # visor
	bx(p, (1.4, 1.8, 0.8), (x, y + 2.8, z + 0.9), "5A6A44")  # pack
	bx(p, (1.6, 2.4, 1.0), (x, y + 0.6, z), SUIT)


def car(p, x, z, col, yaw=0, crushed=False):
	h = 0.6 if crushed else 1.0
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


def row(k, a, b, every, offsets, names, jitter=0.0, scale=(1.0, 1.0), skip=()):
	d = a
	while d < b:
		if not any(s0 <= d <= s1 for s0, s1 in skip):
			for off in offsets:
				o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
				put(k, k.rng.choice(names), d + k.rng.uniform(-jitter, jitter), o, k.rng.uniform(*scale))
		d += every


def local(k, d, off, lx, lz):
	"""World (x, z) of a point (lx, lz) in the frame of a prop placed by put(k, _, d, off)."""
	pos, yaw = k.beside(d, off)
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	v = Matrix.Rotation(yaw, 3, "Z") @ Vector((lx, -lz, 0))  # Blender frame: Roblox z is Blender -y
	return pos[0] + v.x, pos[2] - v.y, yaw


def build(k):
	rnd = random.Random(808)

	# --- Apartment block (mid): Japanese "mansion" with balcony slabs, rails, dividers, sliding doors, AC units,
	# rooftop tank; one top corner bitten away by the kaiju, slabs hanging, rubble at its foot. ---
	ap = []
	AW, AD, F = 40.0, 20.0, 9
	fh = 6.0
	bx(ap, (AW, fh * 6, AD), (0, fh * 3 - 1, 0), "D9D0BC")
	bx(ap, (AW - 14, fh * 3, AD), (-7, fh * 7.5 - 1, 0), "D9D0BC")  # the intact upper left; right corner gone
	for f in range(F):
		y = f * fh + 1
		w = AW if f < 6 else AW - 14
		x = 0 if f < 6 else -7
		bx(ap, (w, 0.8, 4), (x, y + fh - 1.4, -AD / 2 - 2), "E6E0D2")  # balcony slab
		bx(ap, (w, 2.2, 0.3), (x, y + fh - 3.2, -AD / 2 - 3.9), "B8C0C6", metal=0.4)  # rail panel
		n = int(w / 8)
		for c in range(n):
			cx = x - w / 2 + (c + 0.5) * w / n
			bx(ap, (5.6, 3.6, 0.3), (cx, y + 2.0, -AD / 2 - 0.1), WINDOW, rough=0.2)
			bx(ap, (0.3, fh - 1.4, 4), (cx + w / n / 2, y + 2.3, -AD / 2 - 2), "D0C8B4")  # divider
			if (c + f) % 3 == 0:
				bx(ap, (2.4, 1.6, 1.2), (cx + 2, y + 0.9, -AD / 2 - 1), "E8E8E8")  # AC unit
	ap.append(("cyl", (6, 5, 6), (-12, fh * 9 + 1.5, 2), "C8CCD0", {"seg": 10}))
	bx(ap, (12, 2, 22), (12, fh * 6 + 1, -2), CONC2, rot=(0, 0, -24))  # slab hanging from the bite
	bx(ap, (14, 1.6, 6), (10, fh * 5, -AD / 2 - 6), "E6E0D2", rot=(30, 0, -18))
	bx(ap, (8, 5, 7), (14, fh * 6 + 2, 4), ROCK, rot=(10, 30, 14))
	for i in range(7):
		s = rnd.uniform(3, 7)
		bx(ap, (s, s * 0.6, s), (rnd.uniform(-18, 22), s * 0.3 - 1, rnd.uniform(-20, -13)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-15, 15)))
	k.prop("Apartment", ap)

	# --- Office tower (mid): curtain-wall window bands, vertical fins, torn top with exposed floors, blank roof board ---
	of = []
	OW, OD, OF = 34.0, 30.0, 14
	oh = 6.0
	bx(of, (OW, oh * 11, OD), (0, oh * 5.5 - 1, 0), "AEB6BE")
	for f in range(11):
		bx(of, (OW + 0.2, 3.2, 0.3), (0, f * oh + 2.4, -OD / 2 - 0.1), GLASS, rough=0.1, metal=0.4)
		bx(of, (0.3, 3.2, OD + 0.2), (OW / 2 + 0.1, f * oh + 2.4, 0), GLASS, rough=0.1, metal=0.4)
	for x in range(-15, 16, 6):
		bx(of, (0.8, oh * 11, 1.2), (x, oh * 5.5 - 1, -OD / 2 - 0.5), "C8CED4")
	for f, w, xo in ((11, 26, -4), (12, 18, -8), (13, 10, -12)):  # broken upper floors: stepped slabs and columns
		bx(of, (w, 0.8, OD - 4), (xo, f * oh, 0), CONC)
		for x in (xo - w / 2 + 1, xo + w / 2 - 1):
			bx(of, (1.2, oh, 1.2), (x, f * oh - oh / 2, -OD / 2 + 3), CONC2)
	bx(of, (10, 1, 20), (10, oh * 11 + 2, 0), CONC2, rot=(0, 0, 30))
	of.append(("cyl", (6, 5, 6), (-12, oh * 13 + 2.9, 4), "C8CCD0", {"seg": 10}))  # roof tank on the last slab
	bx(of, (OW + 8, 1.2, OD + 8), (0, -0.4, 0), "6A6A68")
	for i in range(6):
		s = rnd.uniform(3, 8)
		bx(of, (s, s * 0.6, s), (rnd.uniform(-20, 20), s * 0.3, rnd.uniform(-22, -16)), (ROCK, CONC2)[i % 2], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("Office", of)

	# --- Rubble (mid): concrete chunks, a crushed car, a toppled utility pole, rebar, a tilted road slab ---
	ru = []
	for i in range(8):
		s = rnd.uniform(2.5, 6)
		bx(ru, (s, s * 0.7, s * 0.9), (rnd.uniform(-8, 8), s * 0.3 - 1, rnd.uniform(-4, 6)), (ROCK, CONC2, CONC, DUST)[i % 4], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), rnd.uniform(-20, 20)))
	car(ru, 10, -2, ("D8302F", "E8E8E8", "2F6FD8")[0], yaw=20, crushed=True)
	ru.append(("cyl", (1.0, 26, 1.0), (-6, 2, 4), "9A9A96", {"seg": 8, "rot": (0, 30, 80)}))
	for i in range(4):
		bx(ru, (0.3, 6, 0.3), (-2 + i, 3, 0), RUST, metal=0.6, rot=(rnd.uniform(-30, 30), 0, rnd.uniform(-30, 30)))
	bx(ru, (14, 1.2, 10), (-4, 0.6, 8), "4E4E50", rot=(8, 15, -6))
	k.prop("Rubble", ru)

	# --- Kaiju corpse (hero): a huge reddish-brown beast lying on its belly across the blocks; grey dorsal armour
	# plates, a horned head on the ground, a forelimb with claws toward the road, the rear third already stripped to
	# bleached ribs; the sweepers' stakes and lines along its back, ropes down its flank with white-suited workers.
	# Local +X head to tail, -Z (its flank) to the road. ---
	kc = []
	body = [(-50, 30, 0, 92, 60, 72), (0, 34, 0, 96, 66, 76), (48, 30, 0, 84, 56, 68)]
	for x, y, z, sx, sy, sz in body:
		kc.append(("ball", (sx, sy, sz), (x, y, z), FLESH, {"subdiv": 3, "smooth": True}))
	# head resting on the ground: skull dome, long tapered snout, flat lower jaw with a row of teeth, brow ridges,
	# swept-back horns
	kc.append(("ball", (44, 32, 40), (-98, 20, -6), FLESH2, {"subdiv": 2, "smooth": True}))
	kc.append(("cyl", (26, 42, 22), (-130, 14, -8), FLESH2, {"rot": (0, 0, -90), "taper": 0.55, "seg": 10, "smooth": True}))
	kc.append(("box", (40, 5, 20), (-128, 2.5, -8), "6A2E24", {"rot": (0, 0, -4)}))
	for i in range(7):
		for zz in (-17, 1):
			kc.append(("cone", (2.4, 4.5, 2.4), (-145 + i * 4.5, 6.5, zz), BONE, {"seg": 5}))
	for s in (-1, 1):
		kc.append(("box", (16, 4, 5), (-110, 30, -6 + s * 13), PLATE, {"rot": (0, s * 10, -14)}))
		kc.append(("cone", (6, 30, 6), (-88, 40, -6 + s * 12), BONE2, {"rot": (s * 18, 0, 55), "seg": 8}))
	kc.append(("box", (5, 1.4, 1), (-112, 25, -26.5), "2A2020"))  # closed eye slit
	for i in range(9):  # dorsal armour plates down the spine
		x = -80 + i * 17
		h = 22 - abs(i - 3) * 2.2
		kc.append(("cone", (12, h, 6), (x, 60 - abs(x) * 0.12 + h / 2 - 4, 0), PLATE, {"seg": 4, "rot": (0, 45, -12)}))
	for x, y, z, sx in ((-30, 20, -30, 28), (20, 22, -32, 30), (60, 18, -28, 24), (-60, 22, 30, 26), (10, 24, 32, 30)):
		kc.append(("ball", (sx, 6, sx * 0.8), (x, y, z), PLATE, {"subdiv": 1, "rot": (0, 0, 10)}))  # flank plates
	# forelimb toward the road with three claws
	kc.append(("cyl", (16, 46, 16), (-62, 12, -40), FLESH2, {"rot": (60, 0, 0), "seg": 10, "smooth": True}))
	kc.append(("ball", (26, 12, 22), (-62, 4, -60), FLESH2, {"subdiv": 2, "smooth": True}))
	for c in (-8, 0, 8):
		kc.append(("cone", (4, 12, 4), (-62 + c, 3, -72), BONE2, {"rot": (-80, 0, 0), "seg": 6}))
	kc.append(("ball", (40, 30, 36), (70, 14, -30), FLESH2, {"subdiv": 2, "smooth": True}))  # folded hind leg
	# stripped rear: spine and bleached ribs
	for i in range(7):
		x = 92 + i * 11
		kc.append(("box", (8, 7, 8), (x, 34 - i * 2.4, 0), BONE, {"rot": (0, 0, 8)}))
		r = 30 - i * 2.6
		for s in (-1, 1):
			kc.append(("box", (3, r, 3), (x, 30 - i * 2.4 - r * 0.2, s * r * 0.45), BONE, {"rot": (s * 58, 0, 0)}))
			kc.append(("box", (3, r * 0.8, 3), (x, 16 - i * 1.8 - r * 0.2, s * r * 0.92), BONE2, {"rot": (-s * 10, 0, 0)}))
	for i in range(8):  # tail along the ground, curling back
		a = i * 0.22
		kc.append(("ball", (22 - i * 2, 16 - i * 1.5, 22 - i * 2), (172 + i * 15, 6 - i * 0.5, 30 * math.sin(a)), FLESH2 if i < 3 else BONE2, {"subdiv": 1, "smooth": True}))
	# sweepers' stakes and lines along the back, ropes down the road flank, workers on them and on the ground
	stakes = [(x, 60 - abs(x) * 0.12 + 1) for x in range(-70, 81, 15)]
	for x, y in stakes:
		for s in (-1, 1):
			kc.append(("cyl", (0.6, 5, 0.6), (x, y + 1, s * 12 - 4), "9AA0A6", {"seg": 6, "metal": 0.6}))
	for (x0, y0), (x1, y1) in zip(stakes, stakes[1:]):
		ln = math.hypot(x1 - x0, y1 - y0)
		ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
		for s in (-1, 1):
			kc.append(("box", (ln, 0.3, 0.3), ((x0 + x1) / 2, (y0 + y1) / 2 + 3, s * 12 - 4), "D8D8D0", {"rot": (0, 0, ang)}))
	for i, x in enumerate(range(-60, 81, 20)):
		ang = 32
		kc.append(("box", (0.35, 62, 0.35), (x, 30, -30), (ROPE_Y, ROPE_T)[i % 2], {"rot": (ang, 0, 0)}))
		if i % 2 == 0:
			worker(kc, x + 1.5, 20 + (i % 3) * 8, -44 + (i % 3) * 5, lean=-30)
	for x, z in ((-30, -66), (-20, -70), (30, -62), (90, -58), (110, -50)):
		worker(kc, x, -1, z)
	for x, z in ((-10, -76), (60, -72)):  # skip bins for the cut pieces
		bx(kc, (14, 6, 8), (x, 2, z), "2F5FA8")
		bx(kc, (14.4, 0.6, 8.4), (x, 5.2, z), "244A84")
	kc.append(("cyl", (320, 1, 150), (20, -0.9, -6), "4A4642", {"seg": 18}))  # flattened ground under it
	for i in range(14):
		s = rnd.uniform(5, 12)
		bx(kc, (s, s * 0.6, s), (rnd.uniform(-150, 200), s * 0.3 - 1, rnd.choice((-1, 1)) * rnd.uniform(50, 70)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("KaijuCorpse", kc)

	# --- Gantry (mid): teal lattice gantry crane straddling the corpse, hoist trolley and hanging lines ---
	ga = []
	GH, GS = 96.0, 82.0  # height, half span (legs at z = +-GS)
	for z in (-GS, GS):
		for x in (-8, 8):
			bx(ga, (2.2, GH, 2.2), (x, GH / 2 - 1, z), TEAL, metal=0.4)
		for y in range(0, int(GH) - 8, 14):
			bx(ga, (16, 1, 1), (0, y + 7, z), TEAL, metal=0.4)
			bx(ga, (0.8, 21, 0.8), (0, y + 7, z), "286A66", rot=(0, 0, 50))
		bx(ga, (22, 2, 6), (0, 0, z), "3A3E46")
	for y in (GH, GH - 8):
		for x in (-6, 6):
			bx(ga, (2, 2, GS * 2 + 6), (x, y, 0), TEAL, metal=0.4)
	for i in range(12):
		z = -GS + (i + 0.5) * GS * 2 / 12
		bx(ga, (0.8, 10.5, 0.8), (6, GH - 4, z), "286A66", rot=(40 if i % 2 else -40, 0, 0))
		bx(ga, (0.8, 10.5, 0.8), (-6, GH - 4, z), "286A66", rot=(40 if i % 2 else -40, 0, 0))
	bx(ga, (16, 6, 10), (0, GH - 4, -20), "E8C840")  # trolley
	for x in (-3, 3):
		ga.append(("cyl", (0.4, 30, 0.4), (x, GH - 22, -20), "202020", {"seg": 4}))
	bx(ga, (6, 3, 4), (0, GH - 38, -20), "E8C840")
	k.prop("Gantry", ga)

	# --- Sweeper van set (mid): white van with roof rack and a plain red band, workers, cones, a light tower ---
	va = []
	bx(va, (8, 7.5, 18), (0, 3.4, 0), "F4F4F2")
	bx(va, (7.6, 3.4, 4), (0, 2.2, -10.5), "F4F4F2")
	bx(va, (7.2, 3.0, 0.3), (0, 5.4, -9.0), "3A4654", rough=0.1, rot=(-20, 0, 0))
	bx(va, (8.1, 3, 10), (0, 5.2, 2), "3A4654", rough=0.1)
	bx(va, (8.2, 0.8, 18.2), (0, 2.6, 0), "C82828")
	for z in (-6, 0, 6):
		bx(va, (8.4, 0.4, 0.4), (0, 7.6, z), "9AA0A6", metal=0.6)
	for x in (-4, 4):
		bx(va, (0.4, 0.4, 16), (x, 7.8, 0), "9AA0A6", metal=0.6)
	for x in (-4, 4):
		for z in (-8, 7):
			va.append(("cyl", (2.6, 1, 2.6), (x, 0.3, z), "1A1A1A", {"rot": (0, 0, 90), "seg": 8}))
	for x, z in ((8, -4), (10, 3), (7, 8)):
		worker(va, x, -1, z)
	for i in range(4):
		va.append(("cone", (1.6, 3, 1.6), (-8, 0.5, -10 + i * 6), STRIPE, {"seg": 8}))
	va.append(("cyl", (0.6, 18, 0.6), (-10, 8, 12), "6A6E74", {"seg": 6}))
	bx(va, (6, 3, 1), (-10, 17, 12), "E8ECF0", emit=1.2)
	bx(va, (5, 3, 5), (-10, 0.5, 12), "E8C840")
	k.prop("SweeperVan", va)

	# --- Defense Force HQ (hero): wide white 8-floor block, central entrance tower with a tall glass strip and portico,
	# end pavilions with roof masts, regular window grid; parking lot with white cars and a hedge row. Badge: an
	# invented orange diamond (not the real insignia). ---
	hq = []
	HW, HD, FH, NF = 230.0, 36.0, 8.0, 8
	HH = FH * NF
	bx(hq, (HW, HH, HD), (0, HH / 2 - 1, 0), BASE)
	for s in (-1, 1):
		bx(hq, (30, HH + 6, HD + 4), (s * (HW / 2 - 15), (HH + 6) / 2 - 1, 0), "E4E4DE")  # end pavilions
		bx(hq, (31, 1.6, HD + 5), (s * (HW / 2 - 15), HH + 5.6, 0), BASE2)
		bx(hq, (0.6, 22, 0.6), (s * (HW / 2 - 10), HH + 16, 0), "8A9096")
		bx(hq, (6, 0.4, 0.4), (s * (HW / 2 - 10), HH + 20, 0), "8A9096")
	for f in range(NF):
		y = f * FH + 4
		for c in range(26):
			x = -HW / 2 + 5 + c * 8.8
			if abs(x) < 17:
				continue
			bx(hq, (5.6, 4.0, 0.4), (x, y, -HD / 2 - (2.1 if abs(x) > HW / 2 - 30 else 0.1)), WINDOW, rough=0.2)
		bx(hq, (HW, 0.5, 0.5), (0, f * FH + 1.4, -HD / 2 - 0.3), "D4D4CE")
	# central tower
	bx(hq, (32, HH + 14, HD + 10), (0, (HH + 14) / 2 - 1, -2), "F2F2EE")
	bx(hq, (10, HH + 4, 0.6), (0, (HH + 4) / 2 + 6, -HD / 2 - 7.2), "3E5670", rough=0.1, metal=0.4)
	for q in range(3):
		bx(hq, (0.6, HH + 4, 0.8), (-3.3 + q * 3.3, (HH + 4) / 2 + 6, -HD / 2 - 7.5), "E8E8E8")
	for s in (-1, 1):
		bx(hq, (5, HH + 14, 1.2), (s * 13.5, (HH + 14) / 2 - 1, -HD / 2 - 7.4), "FAFAF6")
		for f in range(NF):
			bx(hq, (5, 3.4, 0.4), (s * 8.5, f * FH + 4, -HD / 2 - 7.2), WINDOW)
	bx(hq, (34, 1.6, HD + 12), (0, HH + 13.6, -2), BASE2)
	bx(hq, (5, 5, 0.6), (0, HH + 9, -HD / 2 - 7.6), STRIPE, emit=0.4, rot=(0, 0, 45))  # invented badge
	bx(hq, (2.6, 2.6, 0.4), (0, HH + 9, -HD / 2 - 7.9), "FFFFFF", rot=(0, 0, 45))
	bx(hq, (24, 1.4, 12), (0, 8.5, -HD / 2 - 13), "F2F2EE")  # portico
	for x in (-11, 11):
		bx(hq, (1.4, 9, 1.4), (x, 3.5, -HD / 2 - 18), "D8D8D4")
	bx(hq, (14, 7, 0.4), (0, 2.5, -HD / 2 - 7.4), "2E4256", rough=0.1)
	bx(hq, (0.5, 22, 0.5), (0, HH + 24, -2), "8A9096")
	# parking lot, lines, cars, hedge row
	bx(hq, (HW + 20, 0.6, 70), (0, -0.7, -HD / 2 - 44), "5A5C60")
	bx(hq, (2, 0.62, 70), (0, -0.68, -HD / 2 - 44), "E8E8E8")
	for s in (-1, 1):
		for c in range(8):
			x = s * (16 + c * 11)
			bx(hq, (0.5, 0.62, 16), (x + 5.5 * s, -0.68, -HD / 2 - 58), "E8E8E8")
			if (c * 3 + s) % 4 != 0:
				car(hq, x + 2.7 * s, -HD / 2 - 58, ("F2F2F2", "C8CCD0", "E8E8E8", "9AA0A8")[c % 4])
	for c in range(16):
		x = -HW / 2 + 8 + c * 14.5
		if abs(x) < 20:
			continue
		hq.append(("ball", (10, 8, 8), (x, 3, -HD / 2 - 24), "3E6A3A", {"subdiv": 1}))
	k.prop("DefenseHQ", hq)

	# --- Observation tower (hero): slender ribbed shaft, glazed observation ring with a balcony, a deck with two white
	# radar domes and a lattice antenna mast on top; a low base block at the foot. ---
	ot = []
	bx(ot, (40, 16, 30), (0, 7, 0), BASE)
	windows_y = (3, 9)
	for y in windows_y:
		for x in range(-16, 17, 6):
			bx(ot, (4, 3, 0.4), (x, y, -15.2), WINDOW)
	ot.append(("cyl", (14, 120, 14), (0, 60, 0), "E8E8E2", {"seg": 16}))
	for i in range(8):
		a = i / 8 * math.tau
		bx(ot, (1.6, 120, 1.6), (math.cos(a) * 7, 60, math.sin(a) * 7), "C8CCD0")
	ot.append(("cyl", (30, 2, 30), (0, 120, 0), BASE2, {"seg": 20}))
	ot.append(("cyl", (26, 10, 26), (0, 126, 0), "6A90B0", {"seg": 20, "rough": 0.1, "metal": 0.3, "emit": 0.2}))
	for i in range(10):
		a = i / 10 * math.tau
		bx(ot, (0.6, 10, 0.6), (math.cos(a) * 13.1, 126, math.sin(a) * 13.1), "F2F2EE")
	ot.append(("cyl", (32, 2, 32), (0, 132, 0), "F2F2EE", {"seg": 20}))
	ot.append(("cyl", (32.4, 2.4, 32.4), (0, 122.5, 0), "F2F2EE", {"seg": 20, "taper": 1.0}))
	ot.append(("cyl", (18, 6, 18), (0, 136, 0), BASE, {"seg": 16}))
	for s in (-1, 1):
		ot.append(("cyl", (1.4, 4, 1.4), (s * 6, 141, 0), BASE2, {"seg": 6}))
		ot.append(("ball", (8, 8, 8), (s * 6, 146, 0), "FFFFFF", {"subdiv": 2, "smooth": True}))
	for j in range(5):
		y = 140 + j * 7
		w = 4 - j * 0.5
		for sx in (-1, 1):
			for sz in (-1, 1):
				bx(ot, (0.5, 7, 0.5), (sx * w / 2, y + 3.5, sz * w / 2), "D8D8D8")
		bx(ot, (w + 3, 0.4, 0.4), (0, y + 7, 0), "D8D8D8")
		bx(ot, (0.4, 0.4, w + 3), (0, y + 7, 0), "D8D8D8")
	ot.append(("ball", (1.6, 1.6, 1.6), (0, 176, 0), "FF2B2B", {"emit": 8}))
	k.prop("ObsTower", ot)

	# --- Hangar (mid): arched roof, big sliding doors with seams, abstract orange chevron and stripe markings, side
	# office annex, front apron, an armoured Defense Force vehicle with a mounted cannon. ---
	hg = []
	hg.append(("cyl", (56, 64, 40), (0, 0, 2), "8C949C", {"rot": (90, 0, 0), "seg": 16, "metal": 0.4, "rough": 0.5}))
	bx(hg, (58, 2, 66), (0, -1, 2), "5A5E66")
	bx(hg, (44, 18, 1), (0, 8, -30.4), "4A525C", metal=0.3)
	for x in (-16.5, -5.5, 5.5, 16.5):
		bx(hg, (0.5, 18, 1.4), (x, 8, -30.8), "2E343C")
	bx(hg, (46, 1.2, 1.6), (0, 17.4, -30.8), "2E343C")
	for i in range(3):  # chevrons over the door
		for s in (-1, 1):
			bx(hg, (8, 1.4, 0.6), (s * 3.2, 9 + i * 2.6, -31.2), STRIPE, emit=0.3, rot=(0, 0, s * 25))
	for x in range(-22, 23, 4):  # yellow-black door base stripe
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
	# armoured vehicle: 8 wheels, cab, hull, turret with a long cannon
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

	# --- Base wall (mid): white wall with navy band and orange stripe, mesh fence on top, pillar with a lamp ---
	bw = []
	bx(bw, (28, 9, 2.4), (0, 3.5, 0), BASE)
	bx(bw, (28.2, 1.6, 2.6), (0, 5.5, 0), NAVY)
	bx(bw, (28.2, 0.6, 2.6), (0, 7.0, 0), STRIPE, emit=0.3)
	bx(bw, (28.4, 0.8, 3.0), (0, 8.4, 0), BASE2)
	for x in range(-12, 13, 6):
		bx(bw, (0.3, 5, 0.3), (x, 11, 0), "7A8086", metal=0.5)
	for y in (10, 13):
		bx(bw, (28, 0.25, 0.25), (0, y, 0), "7A8086", metal=0.5)
	bx(bw, (28, 4.6, 0.1), (0, 11.2, 0.1), "9AA0A6", alpha=0.35)
	bx(bw, (3, 12, 3.4), (14, 5, 0), BASE2)
	bx(bw, (0.6, 7, 0.6), (14, 14, 0), "6A7078")
	bx(bw, (3, 0.8, 1.2), (13, 17.5, -0.6), "FFF2D0", emit=3.0)
	k.prop("BaseWall", bw)

	# --- Rail cannon (hero): the anti-kaiju rail gun on its track: rails and sleepers, turntable base, long barrel
	# raised away from the road with ring coils, cable bundles, square muzzle, capacitor tanks, a support truck. ---
	rg = []
	for x in (-7, 7):
		bx(rg, (1.4, 1, 120), (x, 0, 10), "7A7E84", metal=0.7)
	for z in range(-48, 70, 6):
		bx(rg, (20, 0.6, 2), (0, -0.6, z), "4A4440")
	bx(rg, (30, 8, 34), (0, 4, 10), "5A6068", metal=0.4)
	rg.append(("cyl", (26, 4, 26), (0, 10, 10), "6A7078", {"seg": 16, "metal": 0.5}))
	bx(rg, (16, 14, 20), (0, 18, 14), "4E545C", metal=0.4)
	el = 28.0
	ax, ay, az = 0.0, 22.0, 6.0
	dirv = (0.0, math.sin(math.radians(el)), math.cos(math.radians(el)))  # barrel points +Z (away from the road), up

	def along(t):
		return (ax, ay + dirv[1] * t, az + dirv[2] * t)

	rg.append(("cyl", (8, 110, 8), along(48), "3A3E44", {"rot": (90 - el, 0, 0), "seg": 16, "metal": 0.6, "rough": 0.35}))
	for i in range(7):
		rg.append(("cyl", (15 - i * 0.6, 4, 15 - i * 0.6), along(2 + i * 6.5), ("8A9098", "6A7078")[i % 2], {"rot": (90 - el, 0, 0), "seg": 16, "metal": 0.6}))
	mx, my, mz = along(104)
	for dx, dy, w, h in ((0, 5, 12, 2), (0, -5, 12, 2), (5, 0, 2, 8), (-5, 0, 2, 8)):
		rg.append(("box", (w, h, 8), (mx + dx, my + dy * math.cos(math.radians(el)), mz - dy * math.sin(math.radians(el))), "2E3238", {"rot": (-el, 0, 0)}))
	for s in (-1, 1):
		for j in range(2):
			rg.append(("cyl", (5, 16, 5), (s * 20, 7, 0 + j * 12), "C8CCD0", {"seg": 12, "metal": 0.3}))
			rg.append(("cyl", (5.4, 1, 5.4), (s * 20, 15.5, j * 12), STRIPE, {"seg": 12}))
		for q in range(3):  # cable bundles from the tanks up to the coils
			rg.append(("cyl", (0.8, 26, 0.8), (s * (12 + q), 16, 8 + q * 2), "1E1E1E", {"rot": (0, 0, s * 55), "seg": 5}))
	car(rg, 26, -26, OLIVE)
	bx(rg, (7.2, 5, 9), (26, 3, -22), "3E4636")
	k.prop("Railgun", rg)

	# --- layout ---
	k.ground(DUST, margin=500)
	supports(k, "3A3E46")
	city_end, base0 = 3900.0, 4050.0
	corpses = [(700.0, -150.0, 0.8), (2530.0, 150.0, 1.0)]
	skip = [(d - 300, d + 300) for d, _, _ in corpses]
	# City: rubble and crushed cars by the road, balconied blocks and offices behind, then a deeper ring of towers
	row(k, 40, city_end, 38, (-28, 28), ["Rubble", "Rubble", "SweeperVan"], jitter=3)
	side = skip + [(3300.0, 3540.0)]  # keep the right side clear under the side review camera (build_track 05_side)
	gun = skip + [(3360.0, 3600.0)]  # open ground in front of the rail cannon
	row(k, 40, city_end, 46, (-58,), ["Apartment", "Apartment", "Office"], jitter=4, skip=gun)
	row(k, 40, city_end, 46, (58,), ["Apartment", "Apartment", "Office"], jitter=4, skip=side)
	row(k, 60, city_end, 62, (-110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=gun)
	row(k, 60, city_end, 62, (110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=side)
	# Corpses with their gantries and sweeper vans
	for d, off, s in corpses:
		put(k, "KaijuCorpse", d, off, s, clear=60)
		for lx in (-40, 80):
			x, z, yaw = local(k, d, off, lx * s, 0)
			k.place("Gantry", (x, -1.0, z), yaw, s)
		for dd in (-60, 0, 60, 120):
			put(k, "SweeperVan", d + dd, 32 if off > 0 else -32)
	put(k, "Railgun", 3480, -80, clear=50)
	# Base: perimeter wall both sides, hangars and the HQ group, a second rail cannon by the last straight
	row(k, base0, k.length - 80, 28, (-31, 31), ["BaseWall"])
	row(k, base0 + 60, k.length - 100, 110, (75, -75), ["Hangar"], skip=[(4450, 4800)])
	row(k, base0 + 100, k.length - 100, 140, (150, -150), ["Hangar", "Apartment"], jitter=10, skip=[(4400, 4900)])
	put(k, "DefenseHQ", 4640, -150, clear=80)
	put(k, "ObsTower", 4540, -75, clear=50)
	put(k, "Railgun", 6620, 90, clear=60)
	# Far Tokyo skyline all round
	k.field(110, ["Office", "Apartment", "Office"], clearance=200, margin=480, scale=(1.2, 2.4))
	# Clear day, warm sun (the source's daytime scenes), light haze at the horizon
	k.sky(
		[(0.0, "DDEAF2"), (0.04, "B8D4EC"), (0.18, "78AEE0"), (0.5, "3F7CC8"), (1.0, "2A5CA8")],
		strength=1.0,
		sun=(4.0, "FFF0D8", 38, 220),
	)
