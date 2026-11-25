"""Blender DRAFTS of the plaza boss gate (WORLD_REDESIGN_SPEC 4.2, design doc change log 2026-11-25). Renders only: no export.

The approved gate draft A (draft_gate.concept_a: a hewn stone ring between two spires) redrawn as the boss gate, closed and
open, at three proposed spots in the plaza as it will look: world gate B, markets B and the altar (B in World 1, A in World 2)
stand in as context from their own draft scripts, imported and never edited. Local axes: x right, -y front, z up, floor = 0.
Headless: blender -b --factory-startup -t 2 --python tools/blender/plaza/draft_boss_gate.py -- [S1 S2 S3] [w1 w2]
          [closed open] [front 34 close spawn arrival back top] [--fast] [--out DIR]   |   -- --layouts (before, min, full) | --report (numbers)
Renders to assets/plaza_draft2/boss_gate/<spot>_<w1|w2>_<state>_<view>.jpg (top: <spot>_w1_top.jpg).
"""

import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "world2"))

import draft_gate as dg  # noqa: E402
import build_plaza as bp  # noqa: E402

_before = dict(bp.PAL), dict(bp.GLOW)
sys.dont_write_bytecode = True
if os.environ.get("ALTAR_DIR"):  # a newer draft_altar.py than this branch's (the renders used branch w2-altar-b, 0540a3ac)
	sys.path.insert(0, os.environ["ALTAR_DIR"])
import draft_altar as da  # noqa: E402  (its import adds its palette)
import draft_markets as dm  # noqa: E402

ALTAR_PAL, ALTAR_GLOW = dict(bp.PAL), dict(bp.GLOW)
OUT = os.path.join(bp.ROOT, "assets", "plaza_draft2", "boss_gate")
cbox, rock, prism, chain, tube = dg.cbox, dg.rock, dg.prism, dg.chain, dg.tube

PAL = {
	"r1": "#8A3A32", "r2": "#74302B", "r3": "#BE6E5C", "r4": "#4A211F",  # oxblood ring stone
	"c1": "#605052", "c2": "#524346", "c3": "#A8918A", "c4": "#2E2527",  # charcoal spires
	"iv1": "#E9DCC0", "iv2": "#CDBB98", "iv3": "#F6EEDC",  # ivory horns
	"d1": "#2E2829", "d2": "#383132", "d3": "#554A49",  # the shut doors
	"s1": "#7D6C68", "s2": "#70605D", "s3": "#A39088", "s4": "#52443F",  # dais and steps
	"ash": "#5C4340", "ink": "#17100F",
}
GLOW = {
	"e1": ("#FFD35A", 1.15), "e2": ("#FF7A1E", 1.1), "e3": ("#DE2A16", 1.0), "e4": ("#8C1210", 0.9), "evoid": ("#2A0606", 0.6),
}
C, RI = 13.4, 8.8  # portal centre height and opening radius
SILL = 4.4


def spot(deg, r):
	a = math.radians(deg)
	return round(r * math.cos(a), 1), round(r * math.sin(a), 1)


# Boss gate spots beside the Summon altar (owner 2026-11-25), as (angle in the Roblox (x, z) plane from +x, radius). The altar
# stands at 47.1, the Team altar at 92.1, the path to RACE START at 137.1, Best Roll at 2.1.
SPOTS = {"S1": spot(79.6, 96.6), "S2": spot(1.8, 78.6), "S3": spot(110.5, 96.0), "S4": spot(88.5, 94.8)}
SCALE = {"S1": 0.8}  # the full size does not fit between the altar and the Team altar
NOTES = {"S1": "left of the altar, between it and the Team altar, at 0.8 size", "S2": "right of the altar, on Best Roll's slot (Best Roll moves)", "S3": "left, one past the Team altar, toward the path", "S4": "left of the altar at full size (fuller layout: the Team altar moves)"}
OLD_STATUE, NEW_STATUE = bp.PEDESTAL[:2], spot(165, 17.05)
OLD_INDEX, NEW_INDEX = bp.INDEX, spot(336, 84)
OLD_POSTS = (45, 100, 200, 250, 315)
# what each layout places where: statue, index, best roll, sky-loop post angles, the boss gate spots it allows
TEAM = bp.ring_spot(7)[0]
FREE = spot(114.6, 84)  # the one ring gap in view on join, between the Team altar and the path
LAYOUTS = {
	"before": {"statue": OLD_STATUE, "index": OLD_INDEX, "best": bp.BEST_ROLL, "team": TEAM, "posts": OLD_POSTS, "spot": "S1"},
	"min": {"statue": NEW_STATUE, "index": NEW_INDEX, "best": bp.BEST_ROLL, "team": TEAM, "posts": OLD_POSTS, "spot": "S1"},
	"s2": {"statue": NEW_STATUE, "index": NEW_INDEX, "best": FREE, "team": TEAM, "posts": OLD_POSTS, "spot": "S2"},
	"full": {"statue": NEW_STATUE, "index": NEW_INDEX, "best": bp.BEST_ROLL, "team": FREE, "posts": (19, 75, 200, 250, 322), "spot": "S4"},
}
SPOT_LAYOUT = {"S1": "min", "S2": "s2", "S3": "min", "S4": "full"}


# --- the gate ---
def circle(r, n, z=C):
	return [(r * math.cos(k / n * math.tau), z + r * math.sin(k / n * math.tau)) for k in range(n)]


def annulus(m, r0, r1, y0, y1, face, inner, n=36):
	A, B = circle(r0, n), circle(r1, n)
	for k in range(n):
		j = (k + 1) % n
		P = lambda p, y: Vector((p[0], y, p[1]))
		m.face([P(A[k], y0), P(B[k], y0), P(B[j], y0), P(A[j], y0)], face)
		m.face([P(A[k], y1), P(A[j], y1), P(B[j], y1), P(B[k], y1)], face)
		m.face([P(A[k], y1), P(A[k], y0), P(A[j], y0), P(A[j], y1)], inner)
		m.face([P(B[k], y0), P(B[k], y1), P(B[j], y1), P(B[j], y0)], face)


def horn(m, s, x, z, h, r):
	"""A six-sided tusk that leans out, then curls in over the ring."""
	prev = None
	for i in range(7):
		f = i / 6
		c = Vector((s * (x + 0.8 * math.sin(f * 2.6) - 2.6 * f * f), -0.4 * f, z + h * f))
		rr = r * (1 - f) ** 0.75
		ring = [c + Vector((rr * math.cos(k / 6 * math.tau), rr * 1.15 * math.sin(k / 6 * math.tau), 0)) for k in range(6)]
		if prev:
			for k in range(6):
				j = (k + 1) % 6
				q = [prev[k], prev[j], ring[j], ring[k]] if rr > 0 else [prev[k], prev[j], c]
				m.face(q, "iv2" if k in (0, 3) else "iv3" if k % 2 and i > 3 else "iv1")
		else:
			m.face(ring[::-1], "iv2")
		prev = ring


def fire(m, lit):
	"""The open portal: flat tongues of fire rising in front of a dark opening, three layers, both faces."""
	R = RI - 0.02
	for side in (-1, 1):
		def put(q, colour):
			v = [Vector((x, y, z)) for x, y, z in q]
			m.face(v if ((v[1] - v[0]).cross(v[2] - v[0])).y * side > 0 else v[::-1], colour)

		ring = circle(R, 36)
		for k in range(36):
			a, b = ring[k], ring[(k + 1) % 36]
			put([(0, 0.2, C), (a[0], 0.2, a[1]), (b[0], 0.2, b[1])], "evoid")
		rng = random.Random(9)
		for li, (colour, base, amp, wide) in enumerate((("e4", 13.6, 5.6, 2.9), ("e3", 9.2, 6.2, 2.5), ("e2", 5.4, 5.6, 2.1), ("e1", 2.4, 3.8, 1.7))):
			y = 0.2 + side * 0.22 * (li + 1)
			x = -R + 0.1
			while x < R - 0.1:
				w = min(wide * rng.uniform(0.8, 1.25), R - 0.1 - x)
				xm = x + w * rng.uniform(0.3, 0.7)
				arch = 1 - 0.45 * (xm / R) ** 2
				zt = C - R + (base + rng.uniform(0.35, 1) * amp) * arch
				zv = C - R + base * 0.72 * arch
				pts = [(x, zv), (x + (xm - x) * 0.6, zv + (zt - zv) * 0.45), (xm, zt), (xm + (x + w - xm) * 0.45, zv + (zt - zv) * 0.4), (x + w, zv)]
				for (xa, za), (xb, zb) in zip(pts, pts[1:]):
					lim = lambda t: math.sqrt(max(R * R - t * t, 0))
					ta, tb = min(za, C + lim(xa)), min(zb, C + lim(xb))
					ba, bb = C - lim(xa), C - lim(xb)
					ta, tb = max(ta, ba), max(tb, bb)
					put([(xa, y, ba), (xb, y, bb), (xb, y, tb), (xa, y, ta)], colour)
				x += w


def leaf(m, s, open_):
	"""Half of the round door, hinged on the ring's back; open it stands straight back, clear of the way through."""
	hinge = Matrix.Translation(Vector((s * (RI + 0.1), 2.9, 0)))
	xf = hinge @ Matrix.Rotation(s * math.radians(-98 if open_ else 0), 4, "Z") @ Matrix.Translation(Vector((-s * (RI + 0.1), -2.9, 0)))
	arc = [(RI - 0.05) * math.cos(t / 12 * math.pi - math.pi / 2) for t in range(13)]
	poly = [(s * x, C + (RI - 0.05) * math.sin(t / 12 * math.pi - math.pi / 2)) for t, x in enumerate(arc)]
	if s < 0:
		poly = poly[::-1]
	dg.RNG = random.Random(3)
	prism(m, poly, 1.5, 2.8, "d1", "d2", 0.25, "d3", xf=xf)
	rot = xf.to_3x3()
	for y in (1.35, 2.95):
		for z, w in ((C + 5.0, 6.6), (C - 5.0, 6.6), (C, 8.2)):  # iron straps with studs
			cbox(m, (w, 0.4, 1.1), xf @ Vector((s * (w / 2 + 0.25), y, z)), "ir2", "ir1", rot, 0.12)
			for k in range(3):
				m.box((0.55, 0.65, 0.55), xf @ Vector((s * (1.4 + k * (w - 2) / 2.2), y, z)), "gd2", rot)
		for x, h in ((0.5, 16.4), (4.6, 13.4)):
			m.box((0.7, 0.5, h), xf @ Vector((s * x, y, C)), "d3", rot)
	for z in (C - 1.6, C + 1.6):  # hinge barrels
		m.cyl(0.6, 1.4, (s * (RI + 0.1), 2.9, z - 0.7), "ir1", n=8)
	if open_:  # its half of the broken seal
		half = [(s * p[0], C + p[1]) for p in ((0.1, -3.0), (1.9, -2.6), (3.0, -1.2), (3.0, 1.2), (1.9, 2.6), (0.1, 3.0), (0.7, 1.0), (0.2, -0.8))]
		prism(m, half if s > 0 else half[::-1], 0.7, 1.4, "gd2", "ir2", 0.15, "gd1", xf=xf)


def spire(m, s, open_, rng):
	X = 14.7
	z = 0.0
	cbox(m, (5.6, 9.0, 2.2), (s * 14.8, 0, 1.1), "s1", "s3", ch=0.4)
	z = 2.2
	for i, (w, d, h) in enumerate(((4.4, 7.0, 7.6), (4.0, 6.0, 7.0), (3.6, 5.0, 6.0))):
		cz = z + h / 2
		rock(m, (w + 0.3, d + 0.3, h + 0.4), (s * X, 0, cz), rng, ("c1", "c2", "c3", "c4"), jit=0.06, flat=0.74)
		for sy in (-1, 1):  # corner piers: straight edges so it reads as built, lit on their chamfers
			for sx in (-1, 1):
				cbox(m, (0.9, 0.9, h), (s * X + sx * (w / 2 - 0.25), sy * (d / 2 - 0.25), cz), "c2", "c3", ch=0.18, edge="c3")
		# outer face: a stepped buttress with a carved slot; front and back: a slot
		slot = "e2" if open_ else "ink"
		cbox(m, (1.0, d * 0.5, h * 0.82), (s * (X + w / 2 + 0.15), 0, cz - h * 0.05), "r2", "r3", ch=0.3, edge="r3")
		cbox(m, (0.3, 0.7, h * 0.5), (s * (X + w / 2 + 0.6), 0, cz), slot, ch=0.05)
		for sy in (-1, 1):
			cbox(m, (w * 0.5, 0.7, h * 0.74), (s * X, sy * (d / 2 + 0.05), cz), "r2", "r3", ch=0.25, edge="r3")
			cbox(m, (0.6, 0.3, h * 0.5), (s * X, sy * (d / 2 + 0.42), cz), slot, ch=0.05)
		z += h
		cbox(m, (w + 0.7, d + 0.7, 0.9), (s * X, 0, z + 0.1), "ir2", "ir1", ch=0.2)  # iron band, studded
		for sy in (-1, 1):
			for k in (-1, 1):
				m.box((0.6, 0.4, 0.6), (s * X + k * w * 0.36, sy * (d / 2 + 0.4), z + 0.1), "gd1")
		for k in (-1, 0, 1):
			m.box((0.4, 0.6, 0.6), (s * (X + w / 2 + 0.4), k * d * 0.34, z + 0.1), "gd1")
		z += 0.55
	lift = 2.4 if open_ else 0.15  # the caps: seated and cold, or risen over a lit core
	if open_:
		for k in range(5):
			a = k / 5 * math.tau
			dg.crystal(m, (s * X + 0.9 * math.cos(a), 0.9 * math.sin(a), z), 2.1 + 0.4 * (k % 2), 1.1, (0.15 * math.cos(a), 0.15 * math.sin(a)), "e1", "e2")
	cbox(m, (3.6, 4.4, 1.5), (s * X, 0, z + lift + 0.75), "c1", "c3", ch=0.4, edge="c3")
	cbox(m, (2.9, 3.4, 0.7), (s * X, 0, z + lift + 1.7), "gd2", "gd1", ch=0.2)
	horn(m, s, X, z + lift + 1.9, 8.2, 1.45)


def brazier(m, x, y, open_):
	m.cyl(1.5, 0.8, (x, y, 1.0), "s4", n=8, r2=1.2)
	m.cyl(0.7, 2.4, (x, y, 1.8), "c1", n=8, r2=0.6)
	m.cyl(0.7, 1.2, (x, y, 4.2), "ir2", n=8, r2=1.7)
	m.cyl(1.75, 0.35, (x, y, 5.4), "gd2", n=8)
	m.cyl(1.4, 0.1, (x, y, 5.72), "e2" if open_ else "ink", n=8)
	if open_:
		for k, (h, c1, c2) in enumerate(((3.4, "e2", "e3"), (2.2, "e1", "e2"), (1.9, "e2", "e3"), (2.0, "e1", "e2"))):
			a = k * 2.1
			rr = 0.0 if k == 0 else 0.75
			dg.crystal(m, (x + rr * math.cos(a), y + rr * math.sin(a), 5.6), h, 1.5 if k == 0 else 0.9, (0.1 * math.cos(a), 0.1), c1, c2)


def gate(closed, matrix, scale=1.0, name="BossGate"):
	open_ = not closed
	dg.RNG = random.Random(3)
	rng = random.Random(11)
	m = bp.M(name, matrix)
	dg.dais(m, closed, ("s1", "s2", "s3", "s4"))
	m.mats = [{"gdim1": "ash", "g2": "e2"}.get(n, n) for n in m.mats]
	# the ring: a solid core so no light gets between the stones, hewn voussoirs proud of both faces
	annulus(m, RI, 11.9, -2.0, 1.9, "r4", "r4")
	if open_:
		annulus(m, RI - 0.35, RI + 0.05, -2.3, -1.5, "e2", "e1")
		annulus(m, RI - 0.35, RI + 0.05, 2.0, 2.6, "e2", "e1")
	n = 13
	for i in range(n):
		a = (i + 0.5) / n * math.tau + math.pi / 2
		big = 1.0 + 0.08 * math.sin(i * 1.7)
		rot = Matrix.Rotation(-(a - math.pi / 2) + rng.uniform(-0.05, 0.05), 3, "Y")
		rock(m, (5.5 * big, 5.4 + 0.4 * (i % 2), 4.0 * big), (11.0 * math.cos(a), 0, C + 11.0 * math.sin(a)), rng, ("r1", "r2", "r3", "r4"), rot, jit=0.07, flat=0.74)
	for k, deg in enumerate((38, 58, 90, 122, 142)):  # crown of thorns of stone
		a = math.radians(deg)
		d = Vector((math.cos(a), 0, math.sin(a)))
		L = 4.6 if deg == 90 else 3.2
		dg.crystal(m, Vector((0, 0, C)) + d * 12.2, L, 2.2 if deg == 90 else 1.7, (0, 0) if deg == 90 else (d.x / d.z, 0), "c1", "c2")
	for sy in (-1, 1):  # keystone with an eye-slot jewel
		key = [(-1.7, C + 9.1), (1.7, C + 9.1), (2.4, C + 13.0), (-2.4, C + 13.0)]
		y = sorted((sy * 2.4, sy * 3.6))
		prism(m, key, y[0], y[1], "c1", "c2", 0.3, "c3")
		gem = [(0, C + 9.8), (1.0, C + 11.2), (0, C + 12.4), (-1.0, C + 11.2)]
		y = sorted((sy * 3.5, sy * 3.95))
		prism(m, gem, y[0], y[1], "e1" if open_ else "ink", "gd2", 0.15, "e2" if open_ else "ash")
	for s in (-1, 1):  # the cradle: courses of stone that carry the ring and tie it to the spires
		for x, w, z0, z1, d in ((12.0, 6.4, 0.9, 4.2, 9.2), (12.7, 5.0, 4.2, 6.6, 8.2), (13.2, 3.8, 6.6, 8.6, 7.2)):
			cbox(m, (w, d, z1 - z0), (s * (x - 0.6), 0, (z0 + z1) / 2), "s1", "s3", ch=0.35, edge="s3")
		cbox(m, (2.6, 4.6, 1.8), (s * 12.6, 0, C + 8.2), "c2", "c3", ch=0.3)  # upper tie stones
		spire(m, s, open_, rng)
		brazier(m, s * 9.6, -8.6, open_)
		leaf(m, s, open_)
	for sy, y0 in ((-1, 2.4), (1, 3.0)):  # steps to the sill, front and back
		for k in range(4):
			top = 1.2 + (SILL - 1.2) * (4 - k) / 4
			cbox(m, (10.0 + k * 0.9, 1.5, top - 0.9), (0, sy * (y0 + 0.75 + k * 1.3), (top + 0.9) / 2), "s2" if k % 2 else "s1", "s3", ch=0.14)
	cbox(m, (9.6, 5.6, 1.6), (0, 0.2, SILL - 0.8), "s1", "s3", ch=0.2)
	if open_:
		fire(m, True)
	for s in (-1, 1):
		cbox(m, (1.4, 1.4, 1.4), (s * 13.2, -3.8, 22.4), "ir2", "ir3", ch=0.2)
		cbox(m, (1.4, 1.4, 1.4), (s * 13.0, -4.4, 6.0), "ir2", "ir3", ch=0.2)
		if closed:
			chain(m, (s * 13.0, -4.0, 22.2), (s * 2.4, -4.2, C + 1.8), 2.7, 0.42, sag=0.3)
			chain(m, (s * 12.8, -4.6, 6.2), (s * 2.4, -4.2, C - 1.8), 2.7, 0.42, sag=0.3)
			chain(m, (s * 12.8, 4.2, 20.2), (s * 2.0, 3.6, C + 1.4), 2.7, 0.42)
			chain(m, (s * 12.4, 4.2, 7.8), (s * 2.0, 3.6, C - 1.4), 2.7, 0.42)
		else:
			chain(m, (s * 13.1, -4.6, 22.2), (s * 13.0, -4.8, 15.6), 2.3, 0.36)
	if closed:  # the seal: a spiked iron boss where the chains meet (no padlock: that is the world gate's)
		for y0, y1, R, fr, ed in ((-4.9, -3.6, 4.2, "ir2", "ir3"), (-5.4, -4.8, 3.1, "gd2", "gd1"), (3.1, 4.1, 3.4, "ir2", "ir3")):
			prism(m, [(x * R / 1.0, C + z * R) for x, z in ((math.cos(k / 8 * math.tau + math.pi / 8), math.sin(k / 8 * math.tau + math.pi / 8)) for k in range(8))], y0, y1, fr, fr, 0.2, ed)
		for k in range(8):
			a = k / 8 * math.tau
			m.box((0.7, 0.6, 0.7), (3.6 * math.cos(a), -5.0, C + 3.6 * math.sin(a)), "gd1")
		for k in range(4):
			a, b = k / 4 * math.tau, (k + 1) / 4 * math.tau
			P = lambda t: (1.9 * math.cos(t), -5.4, C + 1.9 * math.sin(t))
			m.face([P(a), P(b), (0, -7.4, C)][::-1], "ir3" if k in (0, 1) else "ir2")
	m.v = [p * scale for p in m.v]
	return m


def embers(m):
	rng = random.Random(4)
	for _ in range(26):
		p = Vector((rng.uniform(-12, 12), rng.uniform(-7, -3), rng.uniform(6, 32)))
		s = rng.uniform(0.12, 0.3)
		m.box((s, s, s), p, rng.choice(("e1", "e2")), Matrix.Rotation(rng.uniform(0, 3), 3, "Y"))


# --- scene ---
def namespaced(m, tag, pal, glow):
	"""Another draft's mesh with its own palette, so shared colour names never mix."""
	for i, n in enumerate(m.mats):
		new = tag + n
		if n in glow:
			bp.GLOW[new] = glow[n]
		else:
			bp.PAL[new] = pal[n]
		m.mats[i] = new
	return m


def standin(name, x, z, y, height):
	"""A plain figure the size of the rig the game stands there (the models are not in this worktree)."""
	m = dg.figure(name, bp.place(x, z, y, bp.to_spawn(x, z)))
	m.v = [p * (height / 5.5) for p in m.v]
	return m


def scene_for(world, fast, layout="min"):
	L = LAYOUTS[layout]
	cam, col = dg.scene_for(world, fast)
	bp.PAL.update(PAL)
	bp.GLOW.update(GLOW)
	for n in ("Scale_Gate", "Scale_Gate_Big", "Scale_Spawn", "SHOPStall", "POTIONSStall", "MarketStall", "MarketSign", "IndexBoard", "Sensei_Dais", "Ctx_Kept", "SkyLoop", "LegendPedestal", "RunnerTrails", "Sign_SHOP", "Sign_POTIONS", "Sign_Index", "Sign_Market"):
		ob = bpy.data.objects.get(n)
		if ob:
			bpy.data.objects.remove(ob)
	w = dg.gate("B", world == 1)
	w.name = "N_WorldGate"
	w.build(col)
	base_p, base_g = dict(bp.PAL), dict(bp.GLOW)
	mp, mg = {**base_p, **dm.PAL}, {**base_g, **dm.GLOW}
	for name, (pos, face, fa, fb, top) in dm.PIECES.items():
		for i, m in enumerate(list(fb())[:1]):  # the stall, not the draft's own merchant (the owner wants roster models)
			m.name = "N_" + name
			if name == "Index":
				m.matrix = bp.place(*L["index"], bp.TOP, bp.to_spawn(*L["index"]))
			namespaced(m, "mk_", mp, mg).build(col)
	ap, ag = {**base_p, **ALTAR_PAL}, {**base_g, **ALTAR_GLOW}
	parts = da.CONCEPTS["B" if world == 1 else "A"](False)[0]
	for m in parts:
		if m.f:
			m.name = "N_Altar_" + m.name
			namespaced(m, "al_", ap, ag).build(col)
	k = bp.M("N_BestRoll", bp.place(*L["best"], bp.TOP, bp.to_spawn(*L["best"])))
	for r, z0, h, mt in ((9, 0, 0.8, "slab"), (8.8, 0.8, 0.4, "gold"), (9, 1.2, 0.8, "stone")):
		k.cyl(r, h, (0, 0, z0), mt, n=24)
	k.build(col)
	standin("N_BestRollFigure", *L["best"], bp.TOP + 2, 19.2).build(col)  # the game's character stands at 3.5 scale
	x, z = L["statue"]
	face = bp.to_spawn(x, z)
	ped = bp.pedestal(x, z, bp.PEDESTAL[2], "so", face)
	ped.name = "N_StatuePedestal"
	ped.build(col)
	standin("N_StatueFigure", x, z, bp.PEDESTAL[2] + 2.6, bp.LEGEND_H).build(col)
	loop = bp.sky_loop()
	wood = {i for f, fm in zip(loop.f, loop.fm) if loop.mats[fm] in ("verm", "verm2", "black") for i in f}
	for old, new in zip(OLD_POSTS, L["posts"]):
		c = bp.rb(62 * math.cos(math.radians(old)), 0, 62 * math.sin(math.radians(old)))
		turn = Matrix.Rotation(math.radians(old - new), 4, "Z")
		loop.v = [turn @ v if i in wood and math.hypot(v.x - c.x, v.y - c.y) < 2.75 else v for i, v in enumerate(loop.v)]
	loop.build(col)
	t = bp.M("N_TeamAltar", bp.place(*L["team"], bp.TOP, bp.to_spawn(*L["team"])))
	t.cyl(6 / math.cos(math.pi / 8), 1.6, (0, 0, 0), "dark", n=8)
	t.cyl(5.8, 0.1, (0, 0, 1.6), "bloom2", n=8)
	t.build(col)
	p = bp.M("N_StartPad")
	p.box((16, 16, 0.4), tuple(bp.rb(bp.PAD[0], bp.TOP + 0.2, bp.PAD[1])), "pad")
	p.build(col)
	lo = bpy.data.objects["GateLight"]
	lo.name = "WorldGateLight"
	return cam, col


def place_gate(key, closed, col):
	x, z = SPOTS[key]
	mat = bp.place(x, z, bp.TOP, bp.to_spawn(x, z))
	D = math.hypot(x, z)
	sc = SCALE.get(key, 1.0)
	obs = [gate(closed, mat, sc).build(col)]
	if not closed:
		e = bp.M("FX_Embers", mat)
		embers(e)
		e.v = [p * sc for p in e.v]
		obs.append(e.build(col))
		for y, en in ((-8, 4200), (8, 1500)):
			lo = bpy.data.objects.new("BossLight", bpy.data.lights.new("BossLight", "POINT"))
			lo.data.energy, lo.data.shadow_soft_size, lo.data.color = en, 4, bp.rgb("#FF6A22")[:3]
			lo.location = mat @ (Vector((0, y, C - 2)) * sc)
			col.objects.link(lo)
			obs.append(lo)
	obs.append(dg.figure("Scale_Gate", mat @ Matrix.Translation(Vector((-13.4, -14.6, 0)))).build(col))
	obs.append(dg.figure("Scale_Spawn", mat @ Matrix.Translation(Vector((0, -D, bp.SPAWN_TOP - bp.TOP))) @ Matrix.Rotation(math.pi, 4, "Z")).build(col))
	return mat, D, obs


def aim(cam, e, l, fov):
	cam.location = e
	cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
	cam.data.type = "PERSP"
	cam.data.angle_y = math.radians(fov)


def views(mat, D):
	V = lambda *p: mat @ Vector(p)
	return {
		"front": (V(0, -38, 8), V(0, 0, 16.5), 66),
		"34": (V(-30, -33, 12), V(0, 0, 15.6), 62),
		"close": (V(-7, -19, 7), V(1, 0, 14), 64),
		"back": (V(27, 33, 13), V(0, 0, 15.6), 62),
		"spawn": (V(0, -D - 12, bp.SPAWN_TOP - bp.TOP + 7.5), V(0, 0, 10), 70),
		"arrival": (bp.rb(8.8, 8.5, -8.2), bp.rb(-84, 15, 78), 70),  # ArrivalFlow FINAL_POS / FINAL_FOCUS: the HUD camera on join
	}


def render(path):
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("SHOT", path, flush=True)


# --- numbers ---
def loose(ob):
	W = [ob.matrix_world @ v.co for v in ob.data.vertices]
	if not any(k in ob.name for k in ("SkyLoop", "HeroTorii")):
		return [W]
	parent, seen = list(range(len(W))), {}

	def find(i):
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i

	for i, p in enumerate(W):
		parent[find(i)] = find(seen.setdefault(tuple(round(c, 2) for c in p), i))
	for poly in ob.data.polygons:
		for i in poly.vertices:
			parent[find(i)] = find(poly.vertices[0])
	g = {}
	for i, p in enumerate(W):
		g.setdefault(find(i), []).append(p)
	return list(g.values())


SLICES = ((-1, 2.5), (2.5, 8), (8, 16), (16, 27), (27, 90))


def sliced(W):
	"""Plan hulls of one object at several heights above the floor, so a wide roof does not count against a low neighbour."""
	out = []
	for lo, hi in SLICES:
		q = [(p.x, p.y) for p in W if lo <= p.z - bp.TOP <= hi]
		out.append(dg.hull2(q) if len(set(q)) > 2 else None)
	return out


def gap(A, B):
	g = [dg.poly_gap(a, b) for a, b in zip(A, B) if a and b and len(a) > 2 and len(b) > 2]
	return round(min(g), 1) if g else None


def target(name, W_gate):
	"""The world gate, altar... as object name prefixes, and the point the spawn camera turns to."""
	return {
		"world gate": ("N_WorldGate",), "altar": ("N_Altar_A_Body", "N_Altar_B_Body", "N_Altar_B_Petals"), "boss gate": ("BossGate",),
		"Index": ("N_Index",), "statue": ("N_StatueFigure",), "Best Roll": ("N_BestRollFigure",), "Shop": ("N_Shop",), "Potions": ("N_Potions",),
		"Market": ("N_Market",), "Team altar": ("N_TeamAltar",), "RACE START": ("HeroTorii",), "Sensei": ("N_Sensei",),
	}[name]


TARGETS = ("world gate", "altar", "boss gate", "Index", "statue", "Best Roll", "Shop", "Potions", "Market", "Team altar", "RACE START", "Sensei")


def spawn_eye(x, z):
	fx, fz = bp.to_spawn(x, z)
	return bp.rb(fx * 12, bp.SPAWN_TOP + 7.5, fz * 12)


def sight(obs, eye):
	"""Percent of the target's faces turned to the eye that a straight line reaches, and what blocks the rest."""
	dep = bpy.context.evaluated_depsgraph_get()
	pts = [(o.matrix_world @ p.center, o.matrix_world.to_3x3() @ p.normal, p.area) for o in obs for p in o.data.polygons]
	for o in obs:
		o.hide_viewport = True
	bpy.context.view_layer.update()
	dep = bpy.context.evaluated_depsgraph_get()
	tot, hit, by = 0.0, 0.0, {}
	for q, n, area in pts:
		d = q - eye
		w = -n.dot(d) * area / d.length ** 3  # projected size on screen
		if w <= 0:
			continue
		tot += w
		ok, _, _, _, o, _ = bpy.context.scene.ray_cast(dep, eye, d.normalized(), distance=d.length - 0.3)
		if ok:
			hit += w
			by[o.name] = by.get(o.name, 0) + w
	for o in obs:
		o.hide_viewport = False
	return round(100 * (1 - hit / tot), 1), {k: round(100 * v / tot, 1) for k, v in sorted(by.items(), key=lambda t: -t[1]) if v / tot > 0.005}


def report():
	res = {"positions": {"spots": {k: {"pos": v, "face": bp.to_spawn(*v), "note": NOTES[k], "from_altar": round(math.dist(v, bp.SIDEKICK_ALTAR), 1), "from_spawn": round(math.hypot(*v), 1)} for k, v in SPOTS.items()},
		"statue": {"old": OLD_STATUE, "new": NEW_STATUE, "face": bp.to_spawn(*NEW_STATUE)}, "index": {"old": OLD_INDEX, "new": NEW_INDEX, "face": bp.to_spawn(*NEW_INDEX)},
		"free_slot (S2: Best Roll, S4: Team altar)": FREE, "posts": {"old": OLD_POSTS, "full": LAYOUTS["full"]["posts"]}}, "layouts": {}}
	cases = [("before", None), ("before", "S1"), ("min", "S1"), ("min", "S3"), ("s2", "S2"), ("full", "S4")]
	for world in (1, 2):
		for layout, sp in cases:
			cam, col = scene_for(world, True, layout)
			for o in [o for o in bpy.data.objects if o.name.startswith(("Ctx_Petals", "W2_Island"))]:
				bpy.data.objects.remove(o)
			if sp:
				x, z = SPOTS[sp]
				mat = bp.place(x, z, bp.TOP, bp.to_spawn(x, z))
				gate(True, mat, SCALE.get(sp, 1.0)).build(col)
			bpy.context.view_layer.update()
			r = res["layouts"].setdefault("%s%s_w%d" % (layout, "_" + sp if sp else "", world), {})
			mesh = [o for o in bpy.data.objects if o.type == "MESH"]
			pos = {"world gate": dg.pw.GATE, "altar": bp.SIDEKICK_ALTAR, "boss gate": SPOTS.get(sp), "Index": LAYOUTS[layout]["index"], "statue": LAYOUTS[layout]["statue"], "Best Roll": LAYOUTS[layout]["best"], "Shop": bp.SHOP, "Potions": bp.POTIONS, "Market": bp.MARKET_STALL, "Team altar": LAYOUTS[layout]["team"], "RACE START": bp.PAD, "Sensei": bp.SENSEI}
			for t in TARGETS:
				obs = [o for o in mesh if o.name.startswith(target(t, None))]
				if not obs or not pos[t]:
					continue
				s_, by = sight(obs, spawn_eye(*pos[t]))
				e = r.setdefault(t, {"spawn_visible_pct": s_, "blocked_by": by, "walk_from_spawn": round(math.hypot(*pos[t]), 1)})
				# in the join camera (ArrivalFlow FINAL_POS to FINAL_FOCUS, vertical fov 70, 16:9): where its sides fall
				eye, look = bp.rb(8.8, 8.5, -8.2), bp.rb(-84, 15, 78)
				yaw = lambda v: math.degrees(math.atan2(v.x, v.y))
				ang = [(yaw(o.matrix_world @ v.co - eye) - yaw(look - eye) + 180) % 360 - 180 for o in obs for v in o.data.vertices]
				half = math.degrees(math.atan(math.tan(math.radians(35)) * 16 / 9))
				e["join_yaw"] = [round(min(ang), 1), round(max(ang), 1)]
				e["join_in_view_pct"] = round(100 * max(0, min(max(ang), half) - max(min(ang), -half)) / (max(ang) - min(ang))) if max(ang) - min(ang) < 180 else 0
				e["join_unblocked_pct"] = sight(obs, eye)[0] if e["join_in_view_pct"] else 0
			# clearances of everything new or moved
			parts = {}
			for o in mesh:
				if o.name.startswith(("Ctx_", "PlazaFloor", "W2_", "Scale")):
					continue
				for g in loose(o):
					parts.setdefault(o.name, []).append(sliced(g))
			for who in ("BossGate", "N_Index", "N_StatuePedestal", "N_BestRoll", "N_TeamAltar"):
				if who in parts:
					gs = {n: min([g for a in parts[who] for b in pb if (g := gap(a, b)) is not None], default=None) for n, pb in parts.items() if n != who and not (who + "Figure" == n)}
					r["clear_" + who] = dict(sorted([(n, g) for n, g in gs.items() if g is not None and g < 45], key=lambda t: t[1])[:6])
					W = [o.matrix_world @ v.co for o in mesh if o.name == who for v in o.data.vertices]
					r["clear_" + who]["floor_x"], r["clear_" + who]["floor_z"] = round(94 - max(abs(p.x) for p in W), 1), round(110 - max(abs(p.y) for p in W), 1)
	for c in (True, False):
		m = gate(c, Matrix.Identity(4))
		xs, ys, zs = zip(*[tuple(p) for p in m.v])
		res["closed" if c else "open"] = {"tris": sum(len(f) - 2 for f in m.f), "size_xyz": [round(max(a) - min(a), 1) for a in (xs, ys, zs)], "top": round(max(zs), 1), "glow_parts": sorted({m.mats[i] for i in m.fm if m.mats[i] in GLOW})}
	print("REPORT")
	json.dump(res, open(os.path.join(OUT, "report.json"), "w"), indent=1)


def label_top(col, layout, sp):
	"""Top view only: plain dots and leader names above the pieces, and the spawn sightlines to the three landmarks."""
	L = LAYOUTS[layout]
	bp.GLOW.update(lab=("#FFFFFF", 1.0), line=("#FF2A2A", 1.0), line2=("#2A6BFF", 1.0))
	names = {"SPAWN": (0, 0), "WORLD GATE": dg.pw.GATE, "ALTAR": bp.SIDEKICK_ALTAR, "BOSS " + sp: SPOTS[sp], "INDEX": L["index"], "STATUE": L["statue"], "BEST ROLL": L["best"], "SHOP": bp.SHOP, "POTIONS": bp.POTIONS, "MARKET": bp.MARKET_STALL, "TEAM": L["team"], "RACE START": bp.PAD, "SENSEI": bp.SENSEI, "SAKURA": bp.GREAT_SAKURA}
	out = []
	for t, (x, z) in names.items():
		cu = bpy.data.curves.new("TOP_" + t, "FONT")
		cu.body, cu.size, cu.align_x, cu.align_y = t, 5, "CENTER", "CENTER"
		cu.materials.append(bp.mat("lab"))
		ob = bpy.data.objects.new("TOP_" + t, cu)
		ob.location = bp.rb(x, 150, z)
		col.objects.link(ob)
		out.append(ob)
		plate = bp.M("TOP_plate_" + t)
		plate.box((len(t) * 3.5 + 2, 6.4, 0.2), tuple(bp.rb(x, 149, z)), "ink")
		out.append(plate.build(col))
	m = bp.M("TOP_lines")
	for t, (x, z) in names.items():
		if t in ("WORLD GATE", "ALTAR") or t.startswith("BOSS"):
			m.beam(bp.rb(0, 120, 0), bp.rb(x, 120, z), 0.9, "line" if t.startswith("BOSS") else "line2")
	for a in L["posts"]:
		p = bp.rb(62 * math.cos(math.radians(a)), 120, 62 * math.sin(math.radians(a)))
		m.cyl(2.2, 0.5, tuple(p), "line", n=12)
	out.append(m.build(col))
	return out


def spawn_shot(cam, col, path, at):
	x, z = at
	mat = bp.place(x, z, bp.TOP, bp.to_spawn(x, z))
	f = dg.figure("Scale_Spawn2", mat @ Matrix.Translation(Vector((0, -math.hypot(x, z), bp.SPAWN_TOP - bp.TOP))) @ Matrix.Rotation(math.pi, 4, "Z")).build(col)
	aim(cam, spawn_eye(x, z), mat @ Vector((0, 0, 12)), 70)
	render(path)
	bpy.data.objects.remove(f)


def top_shot(cam, col, path, layout, sp):
	extra = label_top(col, layout, sp)
	cam.location, cam.rotation_euler = (0, -4, 400), (0, 0, 0)
	cam.data.type, cam.data.ortho_scale = "ORTHO", 250
	hide = [o for o in bpy.data.objects if o.name.startswith(("Ctx_Petals", "W2_Island"))]
	for o in hide:
		o.hide_render = True
	render(path)
	for o in hide:
		o.hide_render = False
	for o in extra:
		bpy.data.objects.remove(o)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	out = argv[argv.index("--out") + 1] if "--out" in argv else OUT
	os.makedirs(out, exist_ok=True)
	fast = "--fast" in argv
	if "--report" in argv:
		report()
		return
	keys = [a for a in argv if a in SPOTS] or list(SPOTS)
	worlds = [w for w in (1, 2) if "w%d" % w in argv] or [1, 2]
	states = [a for a in argv if a in ("closed", "open")] or ["closed", "open"]
	names = ("front", "34", "close", "back", "spawn", "arrival", "top")
	want = [a for a in argv if a in names] or list(names)
	if "--layouts" not in argv:
		for world in worlds:
			for key in keys:
				layout = SPOT_LAYOUT[key]
				cam, col = scene_for(world, fast, layout)
				for st in states:
					mat, D, obs = place_gate(key, st == "closed", col)
					vs = views(mat, D)
					for v in want:
						if v == "top":
							if world == 1 and st == states[-1]:
								top_shot(cam, col, os.path.join(out, "%s_w1_top.jpg" % key), layout, key)
							continue
						aim(cam, *vs[v])
						render(os.path.join(out, "%s_w%d_%s_%s.jpg" % (key, world, st, v)))
					for o in obs:
						bpy.data.objects.remove(o)
	for world in worlds if "--layouts" in argv else ():
		for layout, L in LAYOUTS.items():  # spawn views: before = today's statue and Index with the same new pieces
			cam, col = scene_for(world, fast, layout)
			_, _, obs = place_gate(L["spot"], False, col)
			bpy.data.objects.remove(next(o for o in obs if o.name.startswith("Scale_Spawn")))
			for t, at in (("worldgate", dg.pw.GATE), ("altar", bp.SIDEKICK_ALTAR), ("bossgate", SPOTS[L["spot"]]), ("index", L["index"])):
				spawn_shot(cam, col, os.path.join(out, "layout_%s_w%d_spawn_%s.jpg" % (layout, world, t)), at)
			aim(cam, *views(Matrix.Identity(4), 0)["arrival"])
			render(os.path.join(out, "layout_%s_w%d_arrival.jpg" % (layout, world)))
			if world == 1:
				top_shot(cam, col, os.path.join(out, "layout_%s_w1_top.jpg" % layout), layout, L["spot"])


if __name__ == "__main__":
	main()
