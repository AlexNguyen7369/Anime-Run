"""World 2 Track 5: Kaiju Base (Kaiju No. 8). Rebuilt 2026-11-23 for a closer 1-1 read of the source (owner: "more detail
and closer reference to source material"; round 2 after the reference review). Landmarks and their references:
docs/world2_refs/KaijuBase.md.
First half: a kaiju-wrecked Tokyo district under a clear blue sky with cumulus clouds: a street grid of wrecked low-rise
blocks with craters, balconied apartment blocks and office towers with collapsed corners and scorch marks (some
leaning), smoke columns, varied rubble and wrecked cars. A giant kaiju corpse lies across the blocks and the Monster
Sweeper crews clean it up (white hooded suits on ropes, a stake-and-rope line along its back, ropes hanging from teal
lattice gantries, a craggy rock-ridge back; white vans with roof racks and crews sitting on top). Second half:
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
FLESH, FLESH2, FLESH3, PLATE, BONE, BONE2 = "8A4A3A", "6E3A2E", "9C5A44", "5A4A4A", "E6DCC4", "C8BCA0"
HIDE, HIDE2 = "C0644E", "9C4C3C"  # salmon-red kaiju hide and its darker patches
SUIT, TEAL, ROPE_Y, ROPE_B = "F4F4F0", "2F7F7A", "E8C840", "2E6FD0"
BASE, BASE2, STRIPE, NAVY, OLIVE = "ECECE6", "A8AEB4", "FF8A1E", "2E3E58", "4A5240"
ASPHALT, WALK = "3A3A3E", "A8A49C"

CLEAR_EXEMPT = {"Pier"}  # supports under the raised road
MODEL_SHOTS = ["KaijuCorpse", "Railgun", "DefenseHQ", "SweeperVan"]  # hero models rendered close up for review

def bx(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def seg(p, a, b, col, thick=0.5, wide=None):
	"""A straight member (cable, rope) from point a to point b, as a thin box along its length."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rz = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
	ry = math.degrees(math.atan2(-dz, dx))
	bx(p, (ln, thick, wide or thick), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), col, rot=(0, ry, rz))


def worker(p, x, y, z, s=1.0, sit=False, lean=0):
	"""A Monster Sweeper in a white parka suit, facing -Z: open hood round a plain face, respirator block with one disc
	filter, harness straps and belt, a tall green pack, arms, legs, gloves, boots. No helmet, no visor."""
	p.append(("cyl", (1.9 * s, 2.6 * s, 1.5 * s), (x, y + 2.7 * s, z), SUIT, {"seg": 8, "rot": (lean, 0, 0), "taper": 0.85}))
	p.append(("ball", (2.3 * s, 2.4 * s, 2.1 * s), (x, y + 4.75 * s, z + 0.15 * s), SUIT, {"subdiv": 2}))  # hood
	p.append(("cyl", (1.7 * s, 0.3 * s, 1.7 * s), (x, y + 4.65 * s, z - 0.9 * s), "DCDCD6", {"rot": (90, 0, 0), "seg": 12}))  # hood rim
	bx(p, (1.1 * s, 1.25 * s, 0.3 * s), (x, y + 4.7 * s, z - 1.05 * s), "D9A882")  # face
	bx(p, (1.2 * s, 0.38 * s, 0.25 * s), (x, y + 5.0 * s, z - 1.22 * s), "16181C")  # dark goggles band
	bx(p, (0.9 * s, 0.6 * s, 0.5 * s), (x, y + 4.3 * s, z - 1.3 * s), "EDEDE8")  # white respirator
	p.append(("cyl", (0.75 * s, 0.3 * s, 0.75 * s), (x + 0.6 * s, y + 4.3 * s, z - 1.3 * s), "C8CCD0", {"rot": (0, 0, 90), "seg": 10}))  # round side filter
	for side in (-1, 1):
		bx(p, (0.3 * s, 2.5 * s, 0.15 * s), (x + side * 0.5 * s, y + 2.9 * s, z - 0.8 * s), "2A2A2E")  # harness straps
	bx(p, (2.0 * s, 0.35 * s, 1.6 * s), (x, y + 1.75 * s, z), "2A2A2E")  # belt
	bx(p, (1.7 * s, 3.6 * s, 1.1 * s), (x, y + 3.4 * s, z + 1.3 * s), "5A6A44")  # tall green pack
	bx(p, (1.5 * s, 0.5 * s, 1.0 * s), (x, y + 5.3 * s, z + 1.3 * s), "4A5838")
	for side in (-1, 1):
		bx(p, (0.55 * s, 2.3 * s, 0.6 * s), (x + side * 1.2 * s, y + 2.6 * s, z - 0.2 * s), SUIT, rot=(-25, 0, side * 10))
		bx(p, (0.6 * s, 0.6 * s, 0.6 * s), (x + side * 1.25 * s, y + 1.6 * s, z - 0.7 * s), "8A9098")  # gloves
		if sit:
			bx(p, (0.7 * s, 0.8 * s, 2.4 * s), (x + side * 0.45 * s, y + 1.0 * s, z - 1.2 * s), SUIT)
		else:
			bx(p, (0.75 * s, 2.3 * s, 0.9 * s), (x + side * 0.45 * s, y + 0.55 * s, z), SUIT)
			bx(p, (0.8 * s, 0.5 * s, 1.2 * s), (x + side * 0.45 * s, y - 0.4 * s, z - 0.15 * s), "4A4E56")  # boots


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
	if not k.clear_of_road(pos[0], pos[2], abs(off) - 1 if clear is None else clear):  # no other lap of road nearer
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
	for x, y, w, h in ((4, fh * 7, 6, 10), (12, fh * 5, 8, 6), (-14, fh * 2, 4, 5), (-4, fh * 4, 10, 8)):
		bx(ap, (w, h, 0.3), (x, y, -AD / 2 - 4.0), SCORCH)
	for x, y in ((-12, fh * 6 + 2), (10, fh * 3 + 2)):  # missing wall chunks: dark holes with jagged edges
		bx(ap, (7, 5, 0.4), (x, y, -AD / 2 - 4.1), "141210")
		for q in range(4):
			bx(ap, (2, 1.4, 0.6), (x - 3 + q * 2, y + 2.6 * (1 if q % 2 else -1), -AD / 2 - 4.1), CONC, rot=(0, 0, rnd.uniform(-30, 30)))
	for x, w, h in ((4, 22, 10), (16, 16, 8), (-14, 12, 6)):  # rubble cones at the foot of the break
		ap.append(("cone", (w, h, w * 0.7), (x, h / 2 - 1, -AD / 2 - 7), (ROCK, CONC2, DUST)[int(x) % 3], {"seg": 7}))
	ap.append(("wedge", (AW - 14, 7, AD), (-7, fh * full + 2.5, 0), "D9D0BC", {"rot": (0, 90, 0)}))  # sheared top: slopes down to the break
	for q in range(6):  # bent rebar along the sheared edge
		bx(ap, (0.4, 5, 0.4), (-18 + q * 4, fh * full + 4, -AD / 2 + 2), RUST, metal=0.5, rot=(rnd.uniform(-30, 30), 0, rnd.uniform(-30, 30)))
	for x, w in ((-16, 8), (2, 6)):  # soot climbing the facade above the holes
		bx(ap, (w, fh * 3, 0.3), (x, fh * 7.5, -AD / 2 - 4.05), SCORCH)
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
	for x, y, w, h in ((2, oh * 12, 6, 14), (12, oh * 8, 8, 8), (-12, oh * 4, 6, 6), (-6, oh * 9, 8, 10)):
		bx(of, (w, h, 0.3), (x, y, -OD / 2 - 0.6), SCORCH)
	for x, y in ((-10, oh * 7), (8, oh * 4)):  # blown-out wall chunks
		bx(of, (8, 6, 0.4), (x, y, -OD / 2 - 0.65), "141210")
		for q in range(4):
			bx(of, (2.4, 1.4, 0.6), (x - 3.6 + q * 2.4, y + 3 * (1 if q % 2 else -1), -OD / 2 - 0.7), CONC, rot=(0, 0, rnd.uniform(-30, 30)))
	for x, w, h in ((8, 24, 11), (-6, 14, 7), (14, 12, 6)):  # rubble cones at the foot of the collapse
		of.append(("cone", (w, h, w * 0.7), (x, h / 2 - 1, -OD / 2 - 8), (ROCK, CONC2, DUST)[int(x) % 3], {"seg": 7}))
	of.append(("wedge", (21, 8, OD), (-6.5, oh * hi_f + 3, 0), "AEB6BE", {"rot": (0, -90, 0)}))  # sheared top
	for x, w in ((-12, 7), (-2, 5)):  # scorched facade above the blown-out chunks
		bx(of, (w, oh * 4, 0.3), (x, oh * 9.5, -OD / 2 - 0.62), SCORCH)
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

	# --- Kaiju corpse (hero): a Kaiju No. 8-style giant beast lying dead on its belly across the blocks, about 750
	# long and 165 tall. A long armoured torso of overlapping rounded hull masses, reddish-brown rocky hide covered in
	# big crag plates with dark folds between them, a pale belly band, a row of dorsal armour plates; a thick neck and a
	# big horned head resting on the ground (brow ridges, eye sockets, tapered snout, open jaw with a row of teeth);
	# a splayed clawed foreleg and a folded hind leg toward the road; a long tapering tail. Monster Sweeper cleanup: two teal lattice gantries straddle it with long blue and yellow
	# ropes, a stake line with sagging rope runs along the spine, about ten white-suited sweepers on the ropes, the back
	# and the ground, skip bins. No wounds. Local +X head to tail is reversed: the head is at -X; -Z (its flank) faces
	# the road. ---
	kc = []
	hull = [(-150, 150, 128), (-90, 186, 136), (-30, 204, 140), (30, 200, 138), (90, 180, 130), (150, 148, 120)]
	for x, sy, sz in hull:  # torso: overlapping angular masses (x, height, depth), tall for the length; bottoms on the ground
		kc.append(("ball", (132, sy, sz), (x, sy * 0.42, 0), HIDE, {"subdiv": 1}))  # hard facets, one cliff

	def flank_z(x, y):
		"""Road-side (-Z) surface of the torso at (x, y), from the nearest hull mass."""
		hx, sy, sz = min(hull, key=lambda h: abs(h[0] - x))
		u = max(0.0, 1 - ((y - sy * 0.42) / (sy / 2)) ** 2)
		return -sz / 2 * math.sqrt(u)

	top_y = lambda x: min(hull, key=lambda h: abs(h[0] - x))[1] * 0.92
	for x, sy, sz in hull:  # pale exposed band at the foot of the flank
		kc.append(("ball", (130, sy * 0.2, sz * 1.03), (x, sy * 0.1, -1.5), "D8B49A", {"subdiv": 2}))
	ROCKS = ("8E4A38", "844434", "96503C", "7E4232")
	for row_ in range(7):  # a rocky cliff: stacked angular plates and ledges, each with a hard dark shadow facet under it
		for i in range(11):
			x = -195 + i * 38 + rnd.uniform(-8, 8) + (19 if row_ % 2 else 0)
			y = 36 + row_ * 24 + rnd.uniform(-5, 5)
			if y > top_y(x) - 6:
				continue
			z = flank_z(x, y)
			if z > -12:
				continue
			hx, sy, sz = min(hull, key=lambda h: abs(h[0] - x))
			lean = -math.degrees(math.asin(max(-0.95, min(0.95, (y - sy * 0.42) / (sy / 2))))) * 0.85
			w = rnd.uniform(30, 46)
			h = w * rnd.uniform(0.55, 0.8)
			tilt = rnd.uniform(-20, 20)
			bx(kc, (w, h, 5), (x, y, z + 0.5), rnd.choice(ROCKS), rot=(lean, rnd.uniform(-6, 6), tilt))  # broad angular rock facet
			bx(kc, (w * 0.8, 2.0, 4), (x, y - h / 2 + 0.4, z + 1.6), "2A1410", rot=(lean, 0, tilt))  # hard shadow under its lip
			if rnd.random() < 0.3:  # crack
				bx(kc, (1.4, h * 1.4, 2), (x + w / 2, y, z - 1), "1E0E0A", rot=(lean, 0, rnd.uniform(-35, 35)))
	for i in range(18):  # angular rock plates along the ridge (no spikes)
		x = -175 + i * 20 + rnd.uniform(-5, 5)
		w, h = rnd.uniform(18, 30), rnd.uniform(8, 16)
		bx(kc, (w, h, rnd.uniform(16, 26)), (x, top_y(x) - h * 0.15, rnd.uniform(-6, 8)), rnd.choice(ROCKS), rot=(rnd.uniform(-15, 15), rnd.uniform(-20, 20), rnd.uniform(-18, 18)))
	# neck and head, resting on the ground
	kc.append(("ball", (100, 120, 110), (-215, 56, -8), HIDE, {"subdiv": 1}))  # neck
	kc.append(("ball", (92, 90, 90), (-275, 44, -12), HIDE, {"subdiv": 1}))
	bx(kc, (64, 50, 66), (-305, 40, -14), HIDE, rot=(0, 0, -6))  # heavy angular cranium
	bx(kc, (74, 24, 50), (-362, 36, -16), "7A3E30", rot=(0, 0, -12))  # upper jaw, lifted open
	kc.append(("wedge", (74, 10, 50), (-362, 50, -16), HIDE, {"rot": (0, 90, -12)}))  # snout ridge
	bx(kc, (84, 9, 50), (-356, 3.5, -16), "5E2A20")  # lower jaw resting on the ground
	bx(kc, (70, 2, 40), (-356, 8.2, -16), "3A1410")  # mouth
	for i in range(10):
		x = -330 - i * 7
		top = 24 + (-330 - x) * 0.21  # underside of the lifted upper jaw
		kc.append(("cone", (4.4, 12, 4.4), (x, top - 5, -39), BONE, {"seg": 6, "rot": (180, 0, 0)}))
		kc.append(("cone", (3.8, 10, 3.8), (x - 3, 12.5, -38), BONE, {"seg": 6}))
	for s_ in (-1, 1):
		bx(kc, (16, 10, 6), (-310, 52, -14 + s_ * 30), "1A0C08")  # eye socket
		bx(kc, (46, 12, 20), (-306, 66, -14 + s_ * 26), "6A342A", rot=(0, s_ * 10, -14))  # brow crest
		bx(kc, (24, 8, 14), (-286, 74, -14 + s_ * 26), "7A3E30", rot=(s_ * 12, 0, 22))
		kc.append(("cone", (14, 44, 14), (-262, 80, -14 + s_ * 30), BONE2, {"rot": (s_ * 14, 0, 64), "seg": 6}))  # horn
	for i in range(8):  # rock plates over the skull
		bx(kc, (rnd.uniform(14, 24), rnd.uniform(5, 9), rnd.uniform(14, 24)), (-330 + i * 9 + rnd.uniform(-3, 3), 64 - i * 0.5 + rnd.uniform(0, 4), -14 + rnd.uniform(-18, 18)), rnd.choice(ROCKS), rot=(rnd.uniform(-15, 15), rnd.uniform(0, 60), rnd.uniform(-20, 10)))
	# foreleg splayed toward the road with four claws; folded hind leg
	seg(kc, (-130, 70, -55), (-175, 24, -110), HIDE, thick=34, wide=30)
	seg(kc, (-175, 24, -110), (-220, 10, -128), HIDE, thick=26, wide=24)
	kc.append(("ball", (44, 20, 40), (-232, 8, -132), HIDE, {"subdiv": 1}))
	for c in (-15, -5, 5, 15):
		kc.append(("cone", (7, 24, 7), (-254, 6, -132 + c), BONE2, {"rot": (0, 0, 80), "seg": 6}))
	kc.append(("ball", (96, 88, 70), (110, 44, -58), HIDE, {"subdiv": 1}))
	seg(kc, (110, 30, -80), (60, 8, -118), HIDE, thick=26, wide=24)
	kc.append(("ball", (40, 16, 34), (48, 6, -124), HIDE, {"subdiv": 1}))
	for c in (-10, 0, 10):
		kc.append(("cone", (6, 20, 6), (28, 5, -124 + c), BONE2, {"rot": (0, 0, 80), "seg": 6}))
	# long tail curving away from the road: one continuous tapering tail to a point (overlapping cut cones on the
	# ground) with rock crags on top
	pts = [(195 + i * 28, 8 + 50 * math.sin(i * 0.16), 70 - i * 5.2) for i in range(13)]
	for i in range(12):
		x, z, r = pts[i]
		x1, z1, r1 = pts[i + 1]
		ln, ry = math.hypot(x1 - x, z1 - z), math.degrees(math.atan2(-(z1 - z), x1 - x))
		kc.append(("cyl", (r * 0.85, ln * 1.3, r), ((x + x1) / 2, r * 0.3, (z + z1) / 2), HIDE, {"seg": 9, "rot": (0, ry, -90), "taper": r1 / r}))
	x, z, r = pts[12]
	kc.append(("cone", (r * 0.85, 30, r), (x + 13, r * 0.3, z), HIDE, {"seg": 9, "rot": (0, 0, -90)}))
	# stake-and-rope lines (as in the source): A-frame stakes every 9 studs with a rope sagging between them, one line
	# along the back and one along the flank
	lines = [[(x, top_y(x) - 2, -12) for x in range(-180, 181, 9)]]
	lines.append([(x, top_y(x) * 0.62, flank_z(x, top_y(x) * 0.62) - 3) for x in range(-180, 181, 9)])
	for line in lines:
		for x, y, z in line:
			for lx in (-2.2, 2.2):  # A-frame: two legs meeting at the top
				seg(kc, (x + lx, y, z), (x, y + 13, z - 1.5), "8A8E94", thick=1.0)
			bx(kc, (1.8, 1.2, 1.4), (x, y + 13, z - 1.5), "5A5E64")
		for (x0, y0, z0), (x1, y1, z1) in zip(line, line[1:]):
			mid = ((x0 + x1) / 2, (y0 + y1) / 2 + 9, (z0 + z1) / 2 - 1.5)
			seg(kc, (x0, y0 + 12.5, z0 - 1.5), mid, "D8CFAE", thick=0.8)
			seg(kc, mid, (x1, y1 + 12.5, z1 - 1.5), "D8CFAE", thick=0.8)
	# two teal lattice gantries straddling the body, long ropes from their tops onto the flank and to the ground
	GH, GS = 220.0, 104.0
	for gx in (-80, 100):
		for z in (-GS, GS):
			for x in (-10, 10):
				bx(kc, (3, GH, 3), (gx + x, GH / 2 - 1, z), TEAL, metal=0.4)
			for y in range(0, int(GH) - 10, 20):
				bx(kc, (20, 1.4, 1.4), (gx, y + 10, z), TEAL, metal=0.4)
				bx(kc, (1.1, 28, 1.1), (gx, y + 10, z), "286A66", rot=(0, 0, 45))
			bx(kc, (28, 2, 9), (gx, 0, z), "3A3E46")
		for y in (GH, GH - 10):
			for x in (-7, 7):
				bx(kc, (2.6, 2.6, GS * 2 + 8), (gx + x, y, 0), TEAL, metal=0.4)
		for i in range(12):
			z = -GS + (i + 0.5) * GS * 2 / 12
			bx(kc, (1.1, 14, 1.1), (gx + 7, GH - 5, z), "286A66", rot=(45 if i % 2 else -45, 0, 0))
		bx(kc, (18, 8, 12), (gx, GH - 6, -40), "E8C840")
		for j, z in enumerate((-80, -70, -60, -50)):
			end = (gx + (j - 1.5) * 4, 1, -66 - j * 3) if j % 2 else (gx + (j - 1.5) * 4, top_y(gx) * 0.5, flank_z(gx, top_y(gx) * 0.5) - 3)
			seg(kc, (gx + (j - 1.5) * 4, GH - 11, z), end, (ROPE_B, ROPE_Y)[j % 2], thick=1.0)
	for (x, y, z, sc, lean) in ((-86, 120, -72, 5.6, -10), (-74, 60, -70, 5.0, 8), (96, 110, -70, 5.4, 6), (106, 40, -72, 4.8, -12)):
		worker(kc, x, y, z, sc, lean=lean)
	for x, sc in ((-40, 4.6), (50, 5.0)):
		worker(kc, x, top_y(x) - 2, -8, sc)
	for x, z, sc in ((-20, -96, 5.2), (20, -92, 4.4), (150, -84, 5.6), (-140, -150, 5.0)):
		worker(kc, x, -1, z, sc)
	for x, z in ((-40, -112), (80, -104)):
		bx(kc, (14, 6, 8), (x, 2, z), "2F5FA8")
		bx(kc, (14.4, 0.6, 8.4), (x, 5.2, z), "244A84")
	kc.append(("cyl", (760, 1, 260), (20, -0.9, 0), "4A4642", {"seg": 24}))
	for i in range(16):
		s_ = rnd.uniform(5, 12)
		bx(kc, (s_, s_ * 0.6, s_), (rnd.uniform(-380, 420), s_ * 0.3 - 1, rnd.choice((-1, 1)) * rnd.uniform(110, 128)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("KaijuCorpse", kc)

	# --- Sweeper van set (mid): one-box van with a sloped nose and raked windscreen, side windows, wheel arches, a plain
	# red band, a raised roof rack with crew sitting on top, cones and a light tower. Nose to -Z. ---
	va = []
	VW = "F4F4F2"
	bx(va, (6.6, 2.6, 15.4), (0, 1.9, 0), VW)  # lower body
	bx(va, (6.4, 3.4, 13.0), (0, 4.9, 1.1), VW)  # upper body behind the raked screen
	va.append(("wedge", (6.4, 3.4, 2.4), (0, 4.9, -6.6), VW))  # screen slope (rises toward +Z)
	bx(va, (5.8, 3.0, 0.3), (0, 4.8, -6.75), "34404E", rough=0.1, rot=(-35, 0, 0))  # raked windscreen
	bx(va, (4.2, 0.9, 0.2), (0, 2.5, -7.75), "2A2E34")  # grille
	for x in (-2.55, 2.55):
		bx(va, (1.2, 0.8, 0.2), (x, 2.5, -7.75), "F0F0D8", emit=0.6)  # headlamps
		bx(va, (0.5, 0.7, 0.8), (x * 1.42, 4.4, -5.6), "2A2E34")  # door mirrors
	bx(va, (6.8, 0.8, 0.6), (0, 0.9, -7.8), "5A5E64")  # bumper
	bx(va, (1.8, 0.8, 0.15), (0, 1.0, -8.15), "E8E8E0")  # blank plate
	for s_ in (-1, 1):
		bx(va, (0.2, 2.2, 2.6), (s_ * 3.25, 5.0, -4.4), "34404E", rough=0.1)  # cab door window
		for z in (-0.6, 2.8, 6.0):
			bx(va, (0.2, 2.2, 2.8), (s_ * 3.25, 5.0, z), "34404E", rough=0.1)
		bx(va, (0.2, 0.7, 15.4), (s_ * 3.35, 2.9, 0), "C82828")  # plain red band
		for z in (-5.2, 5.0):
			bx(va, (0.2, 1.8, 3.2), (s_ * 3.33, 0.9, z), "2A2A2A")  # wheel arch
			va.append(("cyl", (2.3, 0.9, 2.3), (s_ * 3.05, 0.15, z), "1A1A1A", {"rot": (0, 0, 90), "seg": 10}))  # small wheels
	for z in (-2.6, 1.6):  # sliding-door seams on the kerb side, with the door rail
		bx(va, (0.25, 5.4, 0.2), (3.36, 3.6, z), "8A8E94")
	bx(va, (0.25, 0.25, 4.4), (3.36, 3.9, -0.5), "8A8E94")
	bx(va, (5.0, 2.0, 0.2), (0, 5.0, 7.7), "34404E", rough=0.1)  # rear window
	for x in (-2.9, 2.9):
		bx(va, (0.6, 1.4, 0.2), (x, 2.6, 7.75), "C82828", emit=0.4)
	for z in (-3.5, 1.5, 6.5):  # long roof rack
		for x in (-3.0, 3.0):
			bx(va, (0.5, 0.6, 0.5), (x, 6.9, z), "9AA0A6", metal=0.6)
		bx(va, (6.4, 0.35, 0.5), (0, 7.3, z), "9AA0A6", metal=0.6)
	for x in (-3.0, 3.0):
		bx(va, (0.4, 0.4, 11.5), (x, 7.5, 1.5), "9AA0A6", metal=0.6)
	for x, z in ((-1.5, -2.0), (1.5, 3.0)):
		worker(va, x, 7.4, z, 1.0, sit=True)
	worker(va, 8, -1, -4)
	worker(va, 9.5, -1, 4)
	for i in range(4):
		va.append(("cone", (1.6, 3, 1.6), (-8, 0.5, -10 + i * 6), STRIPE, {"seg": 8}))
	va.append(("cyl", (0.6, 11, 0.6), (10, 4.5, 20), "6A6E74", {"seg": 6}))  # light tower, clear of the roof crew
	bx(va, (2.4, 1.4, 1.2), (10, 10.5, 20), "E8ECF0", emit=1.0)
	bx(va, (5, 3, 5), (10, 0.5, 20), "E8C840")
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
		bx(hq, (30, HH + 16, HD + 4), (px, (HH + 16) / 2 - 1, -2), "E4E4DE")
		bx(hq, (31, 1.6, HD + 5), (px, HH + 15.6, -2), BASE2)
		for f in range(NF + 1):
			bx(hq, (30.6, 1.0, 1.0), (px, f * FH + 1.4, -HD / 2 - 4.4), "B4B4AE")
		bx(hq, (0.6, 24, 0.6), (px + s * 6, HH + 27, 0), "8A9096")
		bx(hq, (6, 0.4, 0.4), (px + s * 6, HH + 32, 0), "8A9096")
		bx(hq, (4, 0.4, 0.4), (px + s * 6, HH + 36, 0), "8A9096")
	for f in range(NF):
		y = f * FH + 4
		for c in range(26):
			x = -HW / 2 + 5 + c * 8.8
			if abs(x) < 17:
				continue
			pav = abs(x) > HW / 2 - 30
			bx(hq, (5.6, 4.0, 0.4), (x, y, -HD / 2 - (4.1 if pav else 0.1)), WINDOW, rough=0.2)
		bx(hq, (HW - 60, 1.0, 1.0), (0, f * FH + 1.4, -HD / 2 - 0.5), "B4B4AE")
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
	bx(hq, (HW + 20, 0.6, 104), (0, -0.7, -HD / 2 - 60), "4A4C50")
	bx(hq, (8, 0.62, 104), (0, -0.68, -HD / 2 - 60), "6E7074")
	for c in range(30):  # front row of white cars along the lot edge
		x = -HW / 2 + 6 + c * 7.8
		if abs(x) > 6:
			car(hq, x, -HD / 2 - 104, ("F4F4F4", "E8E8E8", "D8DCE0")[c % 3], yaw=90)
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
		bx(hq, (2.2, 118, 2.2), (ox + math.cos(a) * 7.4, 60, oz + math.sin(a) * 7.4), "BCC2C8")
	hq.append(("cyl", (30, 2, 30), (ox, 120, oz), BASE2, {"seg": 20}))
	hq.append(("cyl", (26, 1.6, 26), (ox, 110, oz), BASE2, {"seg": 20}))  # second balcony ring under the cab
	for i in range(12):
		a = i / 12 * math.tau
		bx(hq, (0.5, 3, 0.5), (ox + math.cos(a) * 12.6, 112.4, oz + math.sin(a) * 12.6), "D8D8D8")
	hq.append(("cyl", (25.6, 0.5, 25.6), (ox, 113.8, oz), "D8D8D8", {"seg": 20}))
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
			bx(hg, (4.6, 0.9, 0.5), (s * 2.0, 10 + i * 1.8, -31.2), "D87A2A", rot=(0, 0, s * 25))
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
	bx(bw, (28, 0.4, 10), (0, -0.8, 7), "5E7A44")  # grass verge inside the base
	for x in (-8, 4):
		bw.append(("ball", (7, 5, 6), (x, 1.5, 8), "3E6A3A", {"subdiv": 1}))
	k.prop("BaseWall", bw)

	# --- Rail cannon (hero): the anti-kaiju rail gun on its long rail bed: ballast, two rails and sleepers, a heavy
	# carriage, a massive barrel raised 10 degrees running through two rail gantries, a dense coil stack at the breech,
	# a riveted square muzzle, tall striped capacitor tanks on both sides, dozens of drooping cable bundles. Barrel to +X.
	rg = []
	bx(rg, (250, 1.2, 34), (10, -0.6, 0), "6A645C")
	for z in (-8, 8):
		bx(rg, (250, 1.4, 1.8), (10, 0.7, z), "8A8E94", metal=0.7)
	for x in range(-112, 134, 7):
		bx(rg, (2.4, 0.7, 22), (x, 0.1, 0), "4A4038")
	bx(rg, (64, 14, 30), (-30, 7.6, 0), "4E545C", metal=0.4)
	bx(rg, (44, 10, 26), (-30, 19.6, 0), "5A6068", metal=0.4)
	for x in (-56, -4):
		for z in (-10, 10):
			rg.append(("cyl", (6, 3, 6), (x, 3, z), "2A2A2A", {"rot": (90, 0, 0), "seg": 10}))
	el = 10.0
	ax, ay = -50.0, 30.0
	ce, se_ = math.cos(math.radians(el)), math.sin(math.radians(el))

	def along(t, up=0.0):
		return (ax + ce * t - se_ * up, ay + se_ * t + ce * up, 0.0)

	rg.append(("cyl", (30, 166, 30), along(83), "4A5058", {"rot": (0, 0, el - 90), "seg": 18, "metal": 0.6, "rough": 0.35}))
	rg.append(("cyl", (44, 56, 44), along(28), "4A5058", {"rot": (0, 0, el - 90), "seg": 20, "metal": 0.6}))  # coil sleeve
	for i in range(8):  # thick radial coil discs stacked at the breech, each with radial fins round its rim
		t = 4 + i * 7
		rg.append(("cyl", (60, 4.6, 60), along(t), ("8A9098", "6A727A")[i % 2], {"rot": (0, 0, el - 90), "seg": 20, "metal": 0.6}))
		for f in range(16):
			a = f * math.tau / 16
			c = along(t, 27 * math.cos(a))
			rg.append(("box", (5.4, 6, 1.6), (c[0], c[1], 27 * math.sin(a)), "4E565E", {"rot": (math.degrees(a), 0, el)}))
	for i in range(5):
		rg.append(("cyl", (34, 2.4, 34), along(66 + i * 20), "5E666E", {"rot": (0, 0, el - 90), "seg": 18, "metal": 0.6}))
	mx, my, _ = along(168)
	for dy, dz, w, h in ((17, 0, 40, 7), (-17, 0, 40, 7), (0, 17, 7, 27), (0, -17, 7, 27)):
		rg.append(("box", (12, h, w), (mx - se_ * dy, my + ce * dy, dz), "2E3238", {"rot": (0, 0, el)}))
	bx(rg, (1.0, 27, 27), along(174.4), "08080A", rot=(0, 0, el))  # square bore, black
	for dy in (-17, 17):
		for dz in (-15, -7.5, 0, 7.5, 15):
			rg.append(("box", (1.4, 1.4, 1.4), (mx - 6.4 - se_ * dy, my + ce * dy, dz), "9AA0A6", {"rot": (0, 0, el)}))
	for gt in (70.0, 125.0):  # rail gantries straddling the barrel, with cables hanging onto it
		gx_, gy_, _ = along(gt)
		for z in (-24, 24):
			bx(rg, (3, gy_ + 26, 3), (gx_, (gy_ + 26) / 2 - 1, z), "3E4650", metal=0.4)
		bx(rg, (4, 3, 52), (gx_, gy_ + 25, 0), "3E4650", metal=0.4)
		for q in range(5):
			zq = -16 + q * 8
			mid = (gx_ + 3, gy_ + 14 - abs(zq) * 0.1, zq)
			seg(rg, (gx_, gy_ + 24, zq), mid, "1E1E1E", thick=1.1)
			seg(rg, mid, (gx_ + 6, gy_ + 15, zq * 0.6), "1E1E1E", thick=1.1)
	for s in (-1, 1):  # ribbed grey capacitor tanks: dark ring bands and vertical ribs
		for j, x in enumerate((-46, -28, -10, 8)):  # either side of the breech coils
			tz = s * (35 + (j % 2) * 5)
			rg.append(("cyl", (11, 48, 11), (x, 23, tz), "8E969E", {"seg": 12, "metal": 0.5, "rough": 0.4}))
			for q in range(8):
				rg.append(("cyl", (12.4, 1.8, 12.4), (x, 2 + q * 6, tz), ("3E444A", STRIPE)[q == 4], {"seg": 12, "metal": 0.5}))
			for a_ in range(4):
				ang = a_ * math.pi / 2 + math.pi / 4
				bx(rg, (1.0, 46, 1.0), (x + math.cos(ang) * 5.8, 23, tz + math.sin(ang) * 5.8), "5A6268")
			rg.append(("cyl", (8, 2.4, 8), (x, 48, tz), "5E666E", {"seg": 12}))
	cols = ("1E1E1E", "2A2A2A", "3A2A1A", "202830")
	for i in range(14):  # 84 cables hanging off the coil stack in drooping arcs to the ground and the rail bed on both sides
		cx_, cy_, _ = along(2 + i * 3.9)
		for q, side in enumerate((-1, 1, -1, 1, -1, 1)):
			p0 = (cx_, cy_ - 6 - q * 2.2, side * 26)
			p3 = (cx_ + rnd.uniform(-6, 6), 0.8, side * (rnd.uniform(38, 50) if q < 4 else rnd.uniform(9, 16)))  # last pair ends on the rail bed
			p1 = (cx_, p0[1] * 0.45, side * 36)
			p2 = ((cx_ + p3[0]) / 2, 3.0, side * (p3[2] * side - 1.5))
			for a_, b_ in ((p0, p1), (p1, p2), (p2, p3)):
				seg(rg, a_, b_, cols[(i + q) % 4], thick=1.8)
	for x in range(-110, 132, 3):  # rack-tooth centre rail
		bx(rg, (1.4, 1.0, 2.6), (x, 1.6, 0), "6E7278", metal=0.6)
	bx(rg, (250, 1.0, 3.0), (10, 0.8, 0), "5A5E64", metal=0.6)
	for s in (-1, 1):  # grated side walkways with posts and handrails
		bx(rg, (250, 0.6, 5), (10, 6, s * 22), "5A6068", metal=0.4)
		for x in range(-110, 135, 16):
			bx(rg, (0.8, 6, 0.8), (x, 3, s * 22), "4A5058")
			bx(rg, (0.5, 5, 0.5), (x, 8.8, s * 24.2), "C8CCD0")
		bx(rg, (250, 0.5, 0.5), (10, 11, s * 24.2), "C8CCD0")
	car(rg, -20, -36, OLIVE)
	bx(rg, (7.2, 5, 9), (-20, 3, -32), "3E4636")
	k.prop("Railgun", rg)

	# --- City block (mid): a 160-stud tile of the street grid. Half-width streets and sidewalks on all four edges, so
	# tiles turned by any quarter still join up; low-rise blocks (some collapsed, scorched), a crater with a rubble rim,
	# a small park with trees, wrecked cars, poles. Tiles are laid with random quarter turns for variety. ---
	cb = []
	T = 160.0
	bx(cb, (T, 0.3, T), (0, -0.85, 0), "9C968A")
	for a in range(4):
		ca, sa = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)

		def rot2(x, z):
			return (x * ca - z * sa, x * sa + z * ca)

		x, z = rot2(0, -T / 2 + 3.5)
		bx(cb, (T if a % 2 == 0 else 7, 0.4, 7 if a % 2 == 0 else T), (x, -0.75, z), ASPHALT)
		x, z = rot2(0, -T / 2 + 8.5)
		bx(cb, (T - 14 if a % 2 == 0 else 3, 0.8, 3 if a % 2 == 0 else T - 14), (x, -0.5, z), WALK)
		for i in range(7):
			x, z = rot2(-T / 2 + 16 + i * 21, -T / 2 + 0.6)
			bx(cb, (8 if a % 2 == 0 else 0.6, 0.42, 0.6 if a % 2 == 0 else 8), (x, -0.74, z), "D8D8D0")
		x, z = rot2(-50, -T / 2 + 10.5)
		cb.append(("cyl", (1.0, 26, 1.0), (x, 12, z), "9A9A96", {"seg": 6}))
	lows = [(-40, -40, 30, 3, "C8C0B0"), (10, -42, 34, 2, "B8B4AC"), (52, -40, 26, 4, "D4CCB8"), (-44, 22, 28, 2, "B0A898")]
	for i, (x, z, w, nf, col) in enumerate(lows):
		h = nf * 7
		broken = i in (1, 3)
		hh = h * (0.55 if broken else 1)
		bx(cb, (w, hh, 22), (x, hh / 2 - 1, z), col)
		for f in range(nf if not broken else 1):
			bx(cb, (w - 3, 2.4, 0.3), (x, f * 7 + 3.5, z - 11.1), WINDOW)
		if broken:
			cb.append(("wedge", (w, h * 0.6, 12), (x, hh + h * 0.3 - 1, z + 5), col))
			bx(cb, (w * 0.8, hh * 0.7, 0.3), (x, hh * 0.4, z - 11.2), SCORCH)
			cb.append(("cone", (w * 0.7, 6, 9), (x, 2, z - 15), ROCK, {"seg": 7}))  # rubble cone at the base
		else:
			bx(cb, (w + 0.6, 0.8, 22.6), (x, h - 0.6, z), "8E8A82")
	bx(cb, (44, 0.4, 40), (44, -0.6, 36), "5E7A44")  # park
	for x, z in ((32, 24), (52, 26), (40, 46), (60, 48), (28, 50)):
		cb.append(("cyl", (1.2, 6, 1.2), (x, 2, z), "4A3A2A", {"seg": 5}))
		cb.append(("ball", (9, 8, 9), (x, 8, z), ("3E6A3A", "4A7A40")[x % 2], {"subdiv": 1}))
	cb.append(("cyl", (30, 0.6, 30), (-4, -0.6, 30), "26221E", {"seg": 12}))  # crater
	cb.append(("cyl", (20, 0.8, 20), (-4, -0.5, 30), "1A1816", {"seg": 10}))
	for i in range(8):
		a = i / 8 * math.tau
		s_ = rnd.uniform(3, 6)
		bx(cb, (s_, s_ * 0.6, s_), (-4 + math.cos(a) * 16, s_ * 0.3 - 1, 30 + math.sin(a) * 16), (ROCK, CONC2, DUST)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	car(cb, -30, -T / 2 + 3, "2F6FD8", yaw=90)
	car(cb, 40, -T / 2 + 4, "E8E8E8", yaw=60, state=1)
	car(cb, -T / 2 + 3, 40, "D8302F", yaw=5, state=2)
	k.prop("CityBlock", cb)

	# --- Smoke column (mid): scorched base with embers, four columns of faceted puffs that widen, lighten and drift as they rise ---
	sm = [("cyl", (40, 0.4, 40), (0, -0.8, 0), SCORCH, {"seg": 10})]
	for i in range(3):
		s = rnd.uniform(3, 6)
		sm.append(("ball", (s, s * 0.6, s), (rnd.uniform(-10, 10), 0.5, rnd.uniform(-10, 10)), "FF7A2A", {"subdiv": 1, "emit": 3.0}))
	cols = ("26221F", "3A3633", "514D49", "68645F", "807C77", "98948F")
	for ox, oz, sc_, n in ((0, 0, 1.0, 6), (18, 12, 0.8, 5), (-15, 9, 0.7, 5)):  # three columns of faceted puffs (2.9k tris cap)
		x, y, r = ox, 8.0, 12 * sc_
		for i in range(n):  # each level: a pair of puffs, wider and lighter as it rises, drifting downwind
			for j in range(2):
				a = j * math.pi + rnd.uniform(-0.6, 0.6) + i
				pr = r * rnd.uniform(0.85, 1.15)
				sm.append(("ball", (pr * 2, pr * 1.6, pr * 2), (x + math.cos(a) * r * 0.45, y + rnd.uniform(-r, r) * 0.2, oz + math.sin(a) * r * 0.45), cols[i], {"subdiv": 2}))
			x, y, r = x + r * 0.4, y + r * 1.25, r * 1.22
	k.prop("Smoke", sm)

	# --- layout ---
	k.ground(DUST, margin=500)
	supports(k, "3A3E46")
	city_end, base0 = 3900.0, 4050.0
	corpses = [(800.0, -190.0, 1.0), (2750.0, -200.0, 1.0)]  # heads ahead of run shots 1 and 2; measured with clearance.py
	skip = [(d - 460, d + 460) for d, _, _ in corpses]
	side = skip + [(3300.0, 3540.0)]  # right side clear under the side review camera (build_track 05_side)
	gun = skip + [(3300.0, 3660.0)]  # open ground round the rail cannon
	# rubble 50 out (measured): even turned, its widest reach (about 16) stays 24+ from the centre line
	row(k, 40, city_end, 30, (-50, 50), ["Rubble"], jitter=3, turn=math.pi, chance=0.6, scale=(0.8, 1.1))
	row(k, 40, city_end, 46, (-64,), ["Apartment", "Apartment", "Office"], jitter=4, skip=gun, turn=0.25, lean=0.2)
	row(k, 40, city_end, 46, (64,), ["Apartment", "Apartment", "Office"], jitter=4, skip=side, turn=0.25, lean=0.2)
	row(k, 60, city_end, 62, (-110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=gun, turn=0.3, lean=0.25)
	row(k, 60, city_end, 62, (110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=side, turn=0.3, lean=0.25)
	for d, off, s in corpses:
		ob = put(k, "KaijuCorpse", d, off, s, clear=60)
		if ob and off > 0:
			ob.scale[0] = -ob.scale[0]  # on the right, mirrored so the head lies ahead of the runner, as on the left
	vans = [(470, -40), (515, -40), (560, -40), (640, -40), (2520, -40), (2565, -40), (2610, -40), (2660, -40)]
	for d, off in vans:  # parked by the corpses, in run shots 1 and 2
		put(k, "SweeperVan", d, off, 1.15, turn=k.rng.uniform(-0.3, 0.3))
	put(k, "Railgun", 3480, -80, clear=50)
	# Base: low perimeter wall, hangars (kept out of the HQ view), a second rail cannon (muzzle to run shot 4)
	row(k, base0, k.length - 80, 28, (-31, 31), ["BaseWall"])
	row(k, base0 + 60, k.length - 100, 110, (-92,), ["Hangar"], skip=[(4250, 4950), (6400, 6960)])  # clear for the cannon
	row(k, base0 + 60, k.length - 100, 110, (92,), ["Hangar"], skip=[(4250, 4950), (6400, 6960)])  # clear for the cannon
	row(k, base0 + 100, k.length - 100, 140, (150, -150), ["Hangar", "Apartment"], jitter=10, skip=[(4250, 4950), (6500, 7000)])
	# the start straight runs parallel about 150 to the right of the last straight, so the cannon goes on the left
	for d, off in ((6740, -110), (6780, -120)):  # measured: the left side is 260+ from every other lap
		ob = put(k, "Railgun", d, off)  # on the left, local +X (the muzzle) points back at run shot 4
		if ob:
			gun2 = (d, off)
			print("KAIJUBASE gun2 at", tuple(round(v) for v in ob.location), "road", tuple(round(v) for v in k.at(d)[0]))
			break
	else:
		gun2 = (6800, -120)
	print("KAIJUBASE gun2", gun2)
	# HQ (with its tower) square-on to run shot 3, ahead-left of the camera
	eye, t, right = shot_eye(k, 0.62)
	a = math.radians(-16)
	fwd = t * math.cos(a) + right * math.sin(a)
	hqc = eye + fwd * 430
	look = eye - hqc
	k.place("DefenseHQ", (hqc.x, -1.0, hqc.z), math.atan2(-look.x, -look.z))
	print("KAIJUBASE HQ clear", round(min((Vector((w.x, 0, w.z)) - Vector((hqc.x, 0, hqc.z))).length for w in k.wps)))
	behind = hqc + fwd * 420  # nothing tall behind the HQ, so its roofline stays clean in shot 3
	tall_avoid = [(hqc.x, hqc.z, 260), (behind.x, behind.z, 460)]
	avoid = [(hqc.x, hqc.z, 260)]
	for d, off, s in corpses + [(3480, -80, 1.0), (gun2[0], gun2[1], 1.0)]:
		x, z, _ = local(k, d, off, 0, 0)
		avoid.append((x, z, 210))
	# Street grid tiles (random quarter turns) over the city and the infield, a few towers on them
	towers = []
	gx = k.lo.x - 400
	while gx < k.hi.x + 400:
		gz = k.lo.z - 400
		while gz < k.hi.z + 400:
			if k.clear_of_road(gx, gz, 190) and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in avoid):
				k.place("CityBlock", (gx, -1.0, gz), k.rng.choice((0, 1, 2, 3)) * math.pi / 2)
				if k.rng.random() < 0.14 and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in tall_avoid):
					k.place(k.rng.choice(["Office", "Apartment"]), (gx, -1.0, gz), k.rng.choice((0, math.pi / 2, math.pi)), k.rng.uniform(1.0, 1.8))
					towers.append((gx, gz, 60))
			gz += 160
		gx += 160
	placed, tries = 0, 0  # smoke columns, clear of the road rows, towers and landmarks
	while placed < 9 and tries < 800:
		tries += 1
		x = k.rng.uniform(k.lo.x - 200, k.hi.x + 200)
		z = k.rng.uniform(k.lo.z - 200, k.hi.z + 200)
		if k.clear_of_road(x, z, 220) and all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid + towers + tall_avoid):
			ob = k.place("Smoke", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.2, 1.8))
			ob.visible_shadow = False  # smoke casts no hard shadow
			placed += 1
	placed, tries = 0, 0  # far skyline
	while placed < 70 and tries < 3000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 480, k.hi.x + 480)
		z = k.rng.uniform(k.lo.z - 480, k.hi.z + 480)
		if k.clear_of_road(x, z, 420) and all(math.hypot(x - ax, z - az) > r for ax, az, r in tall_avoid):
			k.place(k.rng.choice(["Office", "Apartment", "Office"]), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.2, 2.4))
			placed += 1
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
