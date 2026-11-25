"""Blender DRAFTS of a redrawn plaza world gate (design doc 4.47, WORLD2_SPEC "Gate"). Renders only: no export, no game data.

Three concepts against the current gate (SpawnArea.WorldGate), each standing at the gate's own place in the real plaza draft
(build_plaza, plaza_w2; imported, never edited): locked = the violet World 2 gate in World 1's golden hour, open = the cyan
World 1 return gate in World 2's dusk Rift Shrine. Local axes: x right, -y front (toward the spawn), z up, floor top = 0.
  A  Rift Cairn:     a halo of floating boulders between two broken stone spires (the evolution of the current gate).
  B  Shrine Gate:    a tiled shrine gatehouse with an arched doorway and two-fold lattice doors (was Moon Gate).
  C  Split Monolith: one giant standing stone; locked it is banded shut, open its halves have slid apart on the rift.
Footprint kept inside the current gate's 35.7 wide x 30 deep; heights are proposed.
Owner option: -- --big renders the same gates enlarged 1.3x (<concept>_big_*.jpg, compare_big_*); -- --clear prints the gaps to
the neighbours for both sizes.
Headless: blender -b --factory-startup --python tools/blender/plaza/draft_gate.py -- [A B C current] [locked open w1open]
          [front 34 close spawn back] [--fast] [--out DIR]   |   -- --stats   (numbers only, no render)
Renders to assets/plaza_draft2/gate/<concept>_<state>_<view>.jpg, plus compare_*.jpg (A, B / C, current).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "world2"))
sys.path.insert(0, HERE)

import build_plaza as bp  # noqa: E402
import build_track  # noqa: E402  (bloom)
import plaza_w2 as pw  # noqa: E402

OUT = os.path.join(bp.ROOT, "assets", "plaza_draft2", "gate")
CY, R = 14, 11  # portal centre height and ring radius of the current gate
DAIS = 1.2
LIMIT_X, LIMIT_Y = 35.7, 30.0  # the current gate's width (leaning monoliths) and depth (dais), as the footprint limit
MAT = bp.place(pw.GATE[0], pw.GATE[1], bp.TOP, pw.GATE_FACE)
SPAWN_D = math.hypot(*pw.GATE)

PAL = {
	"k1": "#5A5474", "k2": "#474161", "k3": "#837BA0", "k4": "#332F48",  # rift stone, dark violet grey
	"p1": "#A89F90", "p2": "#978E80", "p3": "#BDB4A3", "p4": "#7E766A",  # pale dais stone
	"lq1": "#3A2A4A", "lq2": "#2E2140", "lq3": "#4B3860",  # dark lacquer
	"wd1": "#5A3826", "wd2": "#6E4630", "wd3": "#452A1D",
	"pl1": "#CFC0A0", "pl2": "#BFAF8E",
	"tl1": "#35476E", "tl2": "#2B3A5C",
	"ir1": "#77747E", "ir2": "#5B5862", "ir3": "#96939C",
	"gd1": "#D69A2C", "gd2": "#B8842A", "gd3": "#E8BC55", "hole": "#15121A",
}
# The portal colours: g1 bright edge, g2 mid, g3 deep, g4 core; v = World 2 violet, c = World 1 cyan (SpawnArea swirl colours)
COLOURS = {
	"violet": {"g1": ("#C98BFF", 1.15), "g2": ("#9646FF", 1.1), "g3": ("#5A1EC8", 1.0), "g4": ("#F0DCFF", 1.7), "gdim1": ("#4A2290", 0.8), "gdim2": ("#341566", 0.7), "gvoid": ("#1A0838", 0.6)},
	"cyan": {"g1": ("#7FE4FF", 1.0), "g2": ("#22A8EE", 0.95), "g3": ("#1A5CC4", 0.9), "g4": ("#EAFBFF", 1.2), "gdim1": ("#1C5A90", 0.8), "gdim2": ("#123F6E", 0.7), "gvoid": ("#071A3C", 0.6)},
}


# --- mesh helpers (on build_plaza.M: hard facets, one flat colour per face) ---
def mix(rng, shades):
	return rng.choice(shades) if isinstance(shades, (tuple, list)) else shades


def emit_bm(m, bm, fn):
	bm.normal_update()
	for f in bm.faces:
		m.face([v.co.copy() for v in f.verts], fn(f.normal, f.calc_area()))
	bm.free()


def cbox(m, size, c, side, top=None, rot=None, ch=0.25, edge=None):
	"""A chamfered box: the up faces take the lighter colour, the chamfers the edge colour."""
	if max(size) < 2.5 and ch <= 0.15:  # too small for a chamfer to show
		m.box(size, c, side, rot)
		return
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1)
	for v in bm.verts:
		v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
	bmesh.ops.bevel(bm, geom=bm.edges[:], offset=min(ch, min(size) * 0.45), segments=1, profile=0.5, affect="EDGES")
	r = (rot or Matrix.Identity(3)).to_4x4()
	bm.transform(Matrix.Translation(Vector(c)) @ r)

	def col(n, _):
		n0 = (rot.transposed() @ n) if rot else n
		flat = max(abs(n0.x), abs(n0.y), abs(n0.z)) > 0.99
		if not flat:
			return edge or top or side
		return top if top and n.z > 0.7 else side

	emit_bm(m, bm, col)


def rock(m, size, c, rng, shades, rot=None, sub=1, jit=0.16, flat=0.8):
	"""A hewn boulder: an icosphere squared off (flat) and jittered, then convex, so it reads as cut stone and not a ball."""
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=sub + 1, radius=1)
	for v in bm.verts:
		p = v.co
		q = Vector([math.copysign(min(abs(k) ** 0.6, flat), k) for k in p]) / flat
		q *= 1 + rng.uniform(-jit, jit)
		v.co = Vector((q.x * size[0] / 2, q.y * size[1] / 2, q.z * size[2] / 2))
	hull = bmesh.ops.convex_hull(bm, input=bm.verts[:])
	bmesh.ops.delete(bm, geom=[g for g in hull["geom_interior"] if isinstance(g, bmesh.types.BMVert)], context="VERTS")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(14), verts=bm.verts[:], edges=bm.edges[:])
	bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
	bm.transform(Matrix.Translation(Vector(c)) @ (rot or Matrix.Identity(3)).to_4x4())
	emit_bm(m, bm, lambda n, _: shades[2] if n.z > 0.55 else shades[3] if n.z < -0.5 else mix(rng, shades[:2]))


def offset2(poly, d):
	"""Mitred inset of a counter-clockwise 2D polygon by d."""
	out, n = [], len(poly)
	for i in range(n):
		a, b, c = Vector(poly[i - 1]), Vector(poly[i]), Vector(poly[(i + 1) % n])
		u, v = (b - a).normalized(), (c - b).normalized()
		nu, nv = Vector((-u.y, u.x)), Vector((-v.y, v.x))
		k = nu + nv
		k = k / max(k.length_squared, 0.35) * 2
		out.append(tuple(b + k * d * 0.5 * 2 / 2))
	return out


def prism(m, poly, y0, y1, front, side, bev=0.5, edge=None, back=None, xf=None, relief=0.0):
	"""A CCW (x, z) outline extruded from y0 (front) to y1, with a bevelled rim on both faces. May be concave."""
	xf = xf or Matrix.Identity(4)
	P = lambda p, y: xf @ Vector((p[0], y, p[1]))
	inner = offset2(poly, bev)
	n = len(poly)

	def cap(pts, y, colour, flip):
		bm = bmesh.new()
		vs = [bm.verts.new(P(p, y)) for p in pts]
		f = bm.faces.new(vs)
		bmesh.ops.triangulate(bm, faces=[f])
		if relief:  # hewn facets: the big triangles are split and their inner corners pushed in and out
			rim = {v for v in bm.verts}
			bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if not e.is_boundary], cuts=1, use_grid_fill=True)
			bmesh.ops.triangulate(bm, faces=bm.faces[:])
			bmesh.ops.poke(bm, faces=[t for t in bm.faces if t.calc_area() > 5])
			for v in bm.verts:
				if v not in rim and not v.is_boundary:
					v.co += (xf.to_3x3() @ Vector((0, 1, 0))) * RNG.uniform(-relief, relief * 0.6) * (-1 if flip else 1)
		want = (xf.to_3x3() @ Vector((0, 1 if flip else -1, 0)))
		bm.normal_update()
		for t in bm.faces:
			q = [v.co.copy() for v in t.verts]
			if t.normal.dot(want) < 0:
				q.reverse()
			m.face(q, mix(RNG, colour))
		bm.free()

	cap(inner, y0, front, False)
	cap(inner, y1, back or front, True)
	for i in range(n):
		j = (i + 1) % n
		m.face([P(inner[i], y0), P(poly[i], y0 + bev), P(poly[j], y0 + bev), P(inner[j], y0)], edge or side)
		sh = mix(RNG, side)
		m.face([P(poly[i], y0 + bev), P(poly[i], y1 - bev), P(poly[j], y1 - bev), P(poly[j], y0 + bev)], sh)
		m.face([P(inner[i], y1), P(inner[j], y1), P(poly[j], y1 - bev), P(poly[i], y1 - bev)], edge or side)


RNG = random.Random(3)


def tube(m, pts, r, material, sides=6, closed=False):
	pts = [Vector(p) for p in pts]
	n = len(pts)
	rings = []
	up = None
	for i, p in enumerate(pts):
		a = pts[i - 1] if (closed or i > 0) else p
		b = pts[(i + 1) % n] if (closed or i < n - 1) else p
		t = (b - a).normalized()
		if up is None:
			up = t.orthogonal().normalized()
		up = (up - t * up.dot(t)).normalized()
		w = t.cross(up)
		rings.append([p + (up * math.cos(k / sides * math.tau) + w * math.sin(k / sides * math.tau)) * r for k in range(sides)])
	for i in range(n if closed else n - 1):
		A, B = rings[i], rings[(i + 1) % n]
		if closed and i == n - 1:  # the seam: match the twist
			s = min(range(sides), key=lambda q: (B[q] - A[0]).length)
			B = B[s:] + B[:s]
		for k in range(sides):
			m.face([A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]], material)
	if not closed:
		m.face(rings[0][::-1], material)
		m.face(rings[-1], material)


def chain(m, a, b, link=2.3, r=0.3, sag=0.0, cols=("ir1", "ir2")):
	"""Real links, each turned a quarter from the last."""
	a, b = Vector(a), Vector(b)
	L = (b - a).length
	n = max(2, round(L / (link * 0.72)))
	for i in range(n):
		f = (i + 0.5) / n
		c = a.lerp(b, f) + Vector((0, 0, -sag * 4 * f * (1 - f)))
		t = ((b - a) / L + Vector((0, 0, -sag * 4 * (1 - 2 * f) / L))).normalized()
		u = Vector((0, 1, 0)).cross(t).normalized() if i % 2 else Vector((0, 1, 0))
		hl, hw = link / 2, link * 0.3
		shape = [(-hl, 0), (-hl * 0.7, hw), (hl * 0.7, hw), (hl, 0), (hl * 0.7, -hw), (-hl * 0.7, -hw)]
		tube(m, [c + t * x + u * y for x, y in shape], r, cols[i % len(cols)], 4, True)


def arc(cx, cz, r, a0, a1, n):
	return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def padlock(m, c, s=1.0, back=False):
	"""A proper padlock: rounded bevelled body, raised plate, keyhole, U shackle. Faces -y (or +y)."""
	xf = Matrix.Translation(Vector(c)) @ (Matrix.Rotation(math.pi, 4, "Z") if back else Matrix.Identity(4)) @ Matrix.Scale(s, 4)
	w, h = 2.9, 2.6
	body = [(-w, -h + 1.2), (-w + 1.2, -h), (w - 1.2, -h), (w, -h + 1.2), (w, h - 0.7), (w - 0.7, h), (-w + 0.7, h), (-w, h - 0.7)]
	prism(m, body, -1.1, 1.1, "gd1", "gd2", 0.35, "gd3", xf=xf)
	plate = [(x * 0.72, z * 0.72) for x, z in body]
	prism(m, plate, -1.45, -1.0, "gd3", "gd2", 0.18, "gd1", xf=xf)
	for x, z in ((-2.35, 1.95), (2.35, 1.95), (-2.1, -1.95), (2.1, -1.95)):
		prism(m, [(x + 0.28 * math.cos(k / 6 * math.tau), z + 0.28 * math.sin(k / 6 * math.tau)) for k in range(6)], -1.35, -1.0, "gd3", "gd2", 0.08, xf=xf)
	prism(m, [(0.62 * math.cos(k / 8 * math.tau), 0.45 + 0.62 * math.sin(k / 8 * math.tau)) for k in range(8)], -1.55, -1.2, "hole", "hole", 0.04, xf=xf)
	prism(m, [(-0.5, -1.3), (0.5, -1.3), (0.22, 0.3), (-0.22, 0.3)], -1.54, -1.2, "hole", "hole", 0.04, xf=xf)
	sh = [(-1.75, 2.2)] + arc(0, 3.6, 1.75, 180, 0, 8) + [(1.75, 2.2)]
	tube(m, [xf @ Vector((x, 0, z)) for x, z in sh], 0.55 * s, "ir3", 8)


def rift_sheet(m, outline, cz, y, locked, seeds=34, focus=(0.3, 0.26), bright=False):
	"""The portal: a broken pane. Irregular shards (Voronoi cells), small round an off-centre dark hollow and long toward the
	rim, with light in the cracks; no arms, rings or lit core. outline(angle) -> radius; both faces."""
	rng = random.Random(41)
	rmax = max(outline(k / 48 * math.tau) for k in range(48))
	rad = lambda q: outline(math.atan2(q.y, q.x) % math.tau)
	fx = Vector((focus[0] * outline(0), focus[1] * outline(math.pi / 2)))
	pts = []
	while len(pts) < seeds:
		t = rng.random() ** 1.5
		a = rng.uniform(0, math.tau)
		q = fx + Vector((math.cos(a), math.sin(a))) * (0.05 + 1.45 * t) * rmax
		if q.length < rad(q) * 0.98 and all((q - o).length > 1.3 + 1.4 * (q - fx).length / rmax for o in pts):
			pts.append(q)
		elif rng.random() < 0.002:
			seeds -= 1
	cells = []
	for i, c in enumerate(pts):
		poly = [Vector((sx, sz)) * rmax * 1.3 for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
		for o in pts:
			if o is c:
				continue
			mid, n = (c + o) / 2, o - c
			n = Vector((n.x * 3.2 - n.y * 1.5, n.y * 1.1 - n.x * 1.5))  # a sheared metric: splinters along one diagonal
			out = []
			for u, v in zip(poly, poly[1:] + poly[:1]):
				du, dv = (u - mid).dot(n), (v - mid).dot(n)
				if du <= 0:
					out.append(u)
				if (du < 0) != (dv < 0) and abs(du - dv) > 1e-9:
					out.append(u + (v - u) * (du / (du - dv)))
			poly = out
		fine = []
		for u, v in zip(poly, poly[1:] + poly[:1]):
			steps = max(1, round((v - u).length / 3.2)) if max(u.length - rad(u), v.length - rad(v)) > 0 else 1
			fine += [u.lerp(v, k / steps) for k in range(steps)]
		fine = [q * min(1, 0.955 * rad(q) / max(q.length, 1e-6)) for q in fine]
		g = sum(fine, Vector((0, 0))) / len(fine)
		d = (g - fx).length / rmax
		if locked and not bright:
			cols = rng.choice((("gdim1", "gdim2"), ("gdim2", "gdim2"), ("gdim1", "gdim1")))
		elif d < 0.26:
			cols = ("gvoid", "gdim2")
		else:
			cols = rng.choice((("g2", "g3"), ("g3", "g3"), ("g2", "g2"), ("g3", "gdim1"), ("g1", "g2")))
		cells.append(([g + (q - g) * (0.985 - 0.1 * rng.random() ** 2) for q in fine], g, cols, rng.uniform(0.1, 0.6)))
	crack = "g2" if locked and not bright else "g1"
	for face in (-1, 1):
		P = lambda q, dy: Vector((q.x, y + face * dy, cz + q.y))

		def tri(x, z, w, colour):
			m.face([x, z, w] if ((z - x).cross(w - x)).y * face > 0 else [x, w, z], colour)

		n = 72
		for k in range(n):
			e = [Vector((math.cos(t), math.sin(t))) * outline(t % math.tau) for t in (k / n * math.tau, (k + 1) / n * math.tau)]
			tri(P(Vector((0, 0)), 0.1), P(e[0], 0.1), P(e[1], 0.1), crack)
		for poly, g, cols, dy in cells:
			for k, (u, v) in enumerate(zip(poly, poly[1:] + poly[:1])):
				if (u - v).length > 0.02:
					tri(P(g, 0.2 + dy), P(u, 0.2), P(v, 0.2), cols[k * 2 // len(poly) % 2])


def octo(d, rot=math.pi / 8):
	r = d / 2 / math.cos(math.pi / 8)
	return [(r * math.cos(rot + k * math.pi / 4), r * math.sin(rot + k * math.pi / 4)) for k in range(8)]


def dais(m, locked, shades=("p1", "p2", "p3", "p4"), inlay=True):
	"""The same 30-stud octagon and 1.2 top as now (walkable), with a chamfered rim, paving wedges and a lit inlay ring."""
	o0, o1, o2, o3 = octo(29.6), octo(28.6), octo(26.8), octo(17)
	Z = lambda p, z: Vector((p[0], p[1], z))
	for k in range(8):
		j = (k + 1) % 8
		m.face([Z(o0[k], 0), Z(o0[j], 0), Z(o0[j], 0.45), Z(o0[k], 0.45)], shades[3])
		m.face([Z(o0[k], 0.45), Z(o0[j], 0.45), Z(o1[j], 0.6), Z(o1[k], 0.6)], shades[2])
		m.face([Z(o1[k], 0.6), Z(o1[j], 0.6), Z(o1[j], 1.0), Z(o1[k], 1.0)], shades[1])
		m.face([Z(o1[k], 1.0), Z(o1[j], 1.0), Z(o2[j], DAIS), Z(o2[k], DAIS)], shades[2])
		for s in range(3):  # paving wedges
			a, b = s / 3, (s + 1) / 3
			L = lambda o, f: Z(Vector(o[k]).lerp(Vector(o[j]), f), DAIS)
			m.face([L(o2, a), L(o2, b), L(o3, b), L(o3, a)], RNG.choice(shades[:2]))
		if inlay:
			i0, i1 = octo(16.6), octo(15.4)
			m.face([Z(o3[k], DAIS), Z(o3[j], DAIS), Z(i0[j], DAIS - 0.05), Z(i0[k], DAIS - 0.05)], shades[3])
			m.face([Z(i0[k], DAIS - 0.05), Z(i0[j], DAIS - 0.05), Z(i1[j], DAIS - 0.05), Z(i1[k], DAIS - 0.05)], "gdim1" if locked else "g2")
			m.face([Z(i1[k], DAIS), Z(i1[j], DAIS), Z((0, 0), DAIS)], shades[k % 2])


def shard(m, c, size, rng, shades, tilt=0.5):
	rock(m, size, c, rng, shades, Matrix.Rotation(rng.uniform(-tilt, tilt), 3, "X") @ Matrix.Rotation(rng.uniform(-tilt, tilt), 3, "Y") @ Matrix.Rotation(rng.uniform(0, 3), 3, "Z"), sub=0)


def crystal(m, c, h, w, lean=(0, 0), mat1="g1", mat2="g2"):
	"""A hexagonal crystal with a pointed tip."""
	c = Vector(c)
	ax = Vector((lean[0], lean[1], 1)).normalized()
	u = ax.orthogonal().normalized()
	v = ax.cross(u)
	ring = lambda z, r: [c + ax * z + (u * math.cos(k / 6 * math.tau) + v * math.sin(k / 6 * math.tau)) * r for k in range(6)]
	a, b = ring(0, w * 0.4), ring(h * 0.68, w * 0.5)
	tip = c + ax * h
	for k in range(6):
		j = (k + 1) % 6
		m.face([a[k], a[j], b[j], b[k]], mat1 if k % 2 else mat2)
		m.face([b[k], b[j], tip], mat2 if k % 2 else mat1)


# --- the concepts: fn(m, locked) ---
K = ("k1", "k2", "k3", "k4")


def concept_a(m, locked):
	rng = random.Random(11)
	dais(m, locked)
	n = 13
	for i in range(n):  # the halo: boulders, alternately set forward and back; open they drift apart
		a = (i + 0.5) / n * math.tau + math.pi / 2
		rr = R + (0.0 if locked else 0.55 + 0.35 * math.sin(i * 2.1))
		big = 1.0 + 0.18 * math.sin(i * 1.7)
		y = (0.55 if i % 2 else -0.55) * (1.0 if locked else 1.5)
		rot = Matrix.Rotation(-(a - math.pi / 2) + rng.uniform(-0.12, 0.12), 3, "Y")
		rock(m, (5.0 * big * (1.12 if locked else 0.92), 4.6, 4.0 * big), (rr * math.cos(a), y, CY + 0.4 + rr * math.sin(a)), rng, K, rot)
	for i in range(26):  # the lit lip
		a0, a1 = i / 26 * math.tau, (i + (1 if locked else 0.8)) / 26 * math.tau
		for yy in (-0.9, 0.9):
			m.beam((9.35 * math.cos(a0), yy, CY + 0.4 + 9.35 * math.sin(a0)), (9.35 * math.cos(a1), yy, CY + 0.4 + 9.35 * math.sin(a1)), 0.5, "g2" if locked else "g1")
	rift_sheet(m, lambda t: 9.4, CY + 0.4, 0, locked)
	for s in (-1, 1):  # the broken spires: stacked hewn blocks with lit seams, leaning in, the caps afloat
		x, z = 15.4, 0.0
		for i, (w, d, h) in enumerate(((4.2, 6.4, 8.4), (3.8, 5.4, 7.6), (3.3, 4.6, 6.6), (2.6, 3.6, 5.6))):
			gap = 0.35 if i < 3 else 1.5
			lean = 0.045 * (z + h / 2)
			rock(m, (w, d, h), (s * (x - lean), 0, z + h / 2), rng, K, Matrix.Rotation(-s * 0.06, 3, "Y"), jit=0.09, flat=0.7)
			for sy in (-1, 1):  # a lit seam cut down each face
				if i < 3:
					cbox(m, (0.45, 0.4, h * 0.5), (s * (x - lean), sy * (d * 0.5 + 0.12), z + h * 0.5), "g2", ch=0.08)
			if i < 3:
				cbox(m, (w * 0.66, d * 0.62, 0.9), (s * (x - 0.045 * (z + h)), 0, z + h + gap / 2), "g2", ch=0.1)
			z += h + gap if i < 2 else h + 1.5
		cbox(m, (4.4, 7.4, 1.6), (s * 15.2, 0, 0.8), "p1", "p3", ch=0.4)
		if not locked:  # the broken chain ends hang
			chain(m, (s * 13.6, -2.6, 22), (s * 13.0, -2.9, 14.5), 1.9, 0.26)
	for i in range(9):
		a = math.pi * ((0.1 + 0.07 * i) if i < 4 else 0.9 - 0.07 * (i - 4))
		rr = 14.4 + rng.uniform(-0.6, 0.6)
		sc = rng.uniform(0.7, 1.5)
		shard(m, (rr * math.cos(a) * 0.8, rng.uniform(-2, 2), CY + rr * math.sin(a) * 0.95), (sc, sc, sc * 1.3), rng, K)
	for i in range(8):  # rubble at the foot of the halo
		x = rng.choice((-1, 1)) * rng.uniform(3, 11)
		shard(m, (x, rng.choice((-1, 1)) * rng.uniform(1.5, 3.4), DAIS + 0.4), (rng.uniform(1, 2.2),) * 3, rng, K)
	if locked:
		for sy in (-1, 1):
			for s in (-1, 1):
				for z1, z0 in ((24, 17.6), (5.5, 10.6)):
					chain(m, (s * 13.8, sy * 2.9, z1), (s * 2.2, sy * 3.1, z0), 2.5, 0.36)
			cbox(m, (1.6, 1.6, 3), (0, sy * 2.6, CY + 3.0), "ir2", ch=0.2)
		padlock(m, (0, -3.7, CY - 0.8), 1.2)
		padlock(m, (0, 3.7, CY - 0.8), 1.2, True)


AR, SPRING, SILL = 8.6, 15.6, 1.9  # B's doorway: half width and arch radius, springline, threshold top


def panel(m, xf, s, u0, u1):
	"""One fold of a door, u measured from the jamb toward the middle: lacquer base, open lattice over it, arched head. Built
	in the round, so both faces are finished. xf places the hinge line (u = u0) at the origin; +x runs along the fold."""
	top = lambda u: SPRING + math.sqrt(max(AR * AR - (AR - u) ** 2, 0)) - 0.25
	X = lambda u, y, z: xf @ Vector((s * -(u - u0), y, z))
	rot = xf.to_3x3()
	w, mid = u1 - u0, (u0 + u1) / 2
	for u, in ((u0 + 0.4,), (u1 - 0.4,)):  # stiles
		h = top(u) - SILL - 0.1
		cbox(m, (0.62, 0.95, h), X(u, 0, SILL + 0.1 + h / 2), "lq3", "lq1", rot, 0.16)
	m.box((w - 0.8, 0.5, 4.6), X(mid, 0, SILL + 2.6), "lq1", rot)
	for y in (-0.36, 0.36):  # raised field and gold corner mount on the base
		cbox(m, (w - 1.9, 0.3, 3.2), X(mid, y, SILL + 2.6), "lq3", "lq1", rot, 0.14)
		m.box((0.9, 0.34, 0.9), X(mid, y * 1.25, SILL + 2.6), "gd1", rot @ Matrix.Rotation(math.pi / 4, 3, "Y"))
	for z in (SILL + 0.4, SILL + 5.1, 12.6):
		cbox(m, (w - 0.6, 0.8, 0.8), X(mid, 0, z), "lq3", "lq1", rot, 0.16)
	n = 3
	pts = [X(u0 + 0.1 + (w - 0.2) * k / n, 0, top(u0 + 0.1 + (w - 0.2) * k / n)) for k in range(n + 1)]
	tube(m, pts, 0.5, "gd2", 5)
	for k in (1,):  # lattice bar
		u = u0 + 0.4 + (w - 0.8) * k / 2
		m.box((0.36, 0.4, top(u) - SILL - 5.1), X(u, 0, (top(u) + SILL + 5.1) / 2), "lq2", rot)
	for z in (9.0, 18.4):
		if z < top(mid) - 0.6:
			m.box((w - 0.8, 0.4, 0.36), X(mid, 0, z), "lq2", rot)


def leaf(m, s, locked):
	"""A two-fold door on one jamb: the first fold hinges on the jamb, the second on the first. Open, the first lies back
	along the wall and the second folds in front of it, clear of the doorway."""
	y0, w = -2.5, AR / 2
	a1, a2 = (0, 0) if locked else (math.radians(170), math.radians(-170))
	j = Matrix.Translation(Vector((s * AR, y0, 0)))
	f1 = j @ Matrix.Rotation(s * a1, 4, "Z")
	f2 = f1 @ Matrix.Translation(Vector((-s * w, 0.55, 0))) @ Matrix.Rotation(s * a2, 4, "Z") @ Matrix.Translation(Vector((0, -0.55, 0)))
	panel(m, f1, s, 0.0, w - 0.06)
	panel(m, f2, s, w, AR - 0.08)
	for z in (4.0, 9.0, 14.2):  # hinge barrels, and the plates that hold them to the jamb
		m.cyl(0.48, 1.7, (s * AR, y0, z - 0.85), "gd2", n=8)
		m.box((1.5, 0.5, 1.2), (s * (AR + 0.7), y0 + 0.25, z), "gd1")
		k = f1 @ Vector((-s * w, 0.55, z))
		m.cyl(0.42, 1.5, (k.x, k.y, z - 0.75), "gd2", n=8)
	for y in (-0.55, 0.55):  # a pull plate on the meeting stile, both faces
		m.box((0.5, 0.3, 2.2), f2 @ Vector((-s * (w - 0.5), y, 10.8)), "gd1", f2.to_3x3())


def concept_b(m, locked):
	dais(m, locked)
	hw, z1, d, n = 13.2, 26.2, 1.5, 10
	arc_ = [Vector((AR * math.cos(k / n * math.pi), 0, SPRING + AR * math.sin(k / n * math.pi))) for k in range(n + 1)]  # right to left
	for f in (-1, 1):
		Y = Vector((0, f * d, 0))

		def quad(q, colour):
			m.face([p + Y for p in (q if f < 0 else q[::-1])], colour)

		for s in (-1, 1):
			q = [Vector((s * AR, 0, DAIS)), Vector((s * hw, 0, DAIS)), Vector((s * hw, 0, SPRING)), Vector((s * AR, 0, SPRING))]
			quad(q if s > 0 else q[::-1], "pl1")
		for p, q in zip(arc_, arc_[1:]):
			quad([p, Vector((p.x, 0, z1)), Vector((q.x, 0, z1)), q], "pl1")
		for s in (-1, 1):
			q = [Vector((s * AR, 0, SPRING)), Vector((s * hw, 0, SPRING)), Vector((s * hw, 0, z1)), Vector((s * AR, 0, z1))]
			quad(q if s > 0 else q[::-1], "pl2")
	# stone frame: jamb blocks and arch blocks, proud on both faces; a lit lip inside
	for s in (-1, 1):
		for k in range(5):
			h = (SPRING - DAIS) / 5
			w = 1.7 if k % 2 else 1.4
			cbox(m, (w, 4.0 if k % 2 else 3.8, h - 0.06), (s * (AR + 0.05 + w / 2), 0, DAIS + (k + 0.5) * h), "k1" if k % 2 else "k2", "k3", ch=0.2)
		m.box((0.2, 1.2, SPRING - DAIS), (s * (AR - 0.02), 0.9, (SPRING + DAIS) / 2), "g2" if locked else "g1")
	for k in range(n + 1):
		a = (k + 0.5) / (n + 1) * math.pi
		w = 1.9 if k == n // 2 else 1.5
		r = AR + 0.05 + w / 2
		cbox(m, (2.75, 4.6 if k == n // 2 else 4.0 if k % 2 else 3.8, w), (r * math.cos(a), 0, SPRING + r * math.sin(a)), "k1" if k % 2 else "k2", "k3", Matrix.Rotation(math.pi / 2 - a, 3, "Y"), 0.2)
		rr = AR - 0.02
		m.box((2.5, 1.2, 0.2), (rr * math.cos(a), 0.9, SPRING + rr * math.sin(a)), "g2" if locked else "g1", Matrix.Rotation(math.pi / 2 - a, 3, "Y"))
	cz = 12.6

	def outline(t):  # the doorway as a radius round (0, cz)
		c, s_ = math.cos(t), math.sin(t)
		best = 1e9
		if abs(c) > 1e-6:
			best = min(best, (AR - 0.1) / abs(c))
		if s_ < -1e-6:
			best = min(best, (cz - DAIS) / -s_)
		if s_ > 0:
			e = SPRING - cz
			disc = (e * s_) ** 2 - e * e + (AR - 0.1) ** 2
			if disc > 0 and best * s_ > e:
				best = min(best, e * s_ + math.sqrt(disc))
		return best

	rift_sheet(m, outline, cz, 0.9, locked, seeds=40, focus=(0.28, 0.1), bright=True)
	cbox(m, (26.4, 4.6, 1.5), (0, 0, DAIS - 0.05), "p2", "p3", ch=0.25)  # threshold
	for s in (-1, 1):
		leaf(m, s, locked)
		for y in (-3.2, 3.2):  # pillars front and back on stone feet
			m.cyl(1.25, 25.5, (s * 14.9, y, DAIS), "wd2", n=10, r2=1.1)
			m.cyl(1.9, 1.4, (s * 14.9, y, 0.6), "p2", n=8, r2=1.6)
			m.cyl(1.4, 0.7, (s * 14.9, y, 5), "gd2", n=10)
		for z in (4.4, 20.8):  # tie rails
			cbox(m, (1.0, 7.4, 1.2), (s * 14.9, 0, z), "wd3", "wd1")
		cbox(m, (1.4, 2.6, 25), (s * 13.4, 0, DAIS + 12.5), "wd3", "wd1")
		m.box((2.8, 0.5, 4.2), (s * 11.6, -1.7, DAIS + 2.6), "wd3")  # front: a boarded dado with a cap rail
		cbox(m, (2.9, 0.9, 0.6), (s * 11.6, -1.75, DAIS + 5.0), "wd1", "wd2", ch=0.16)
		y = 1.75  # the back wall's timber frame: post, rails, a brace and a latticed vent
		cbox(m, (0.9, 0.7, 24.4), (s * 11.3, y, 13.6), "wd1", "wd2", ch=0.16)
		for z in (7.0, 13.0, 19.4):
			cbox(m, (3.6, 0.6, 0.8), (s * 11.6, y + 0.05, z), "wd1", "wd2", ch=0.16)
		m.beam((s * 10.6, y, 19.6), (s * 13.0, y, 25.0), 0.7, "wd1")
		for x in (10.4, 11.1, 11.8, 12.5):
			m.box((0.3, 0.5, 5.0), (s * x, y, 10), "wd3")
		cbox(m, (2.8, 1.2, 0.5), (s * 11.8, 2.2, 24.8), "gd2", "gd1", ch=0.15)
		for y in (-3.2, 3.2):  # rift lanterns under the eaves
			m.beam((s * 16.6, y, 25.2), (s * 16.6, y, 24), 0.2, "black")
			m.cyl(0.6, 0.35, (s * 16.6, y, 23.7), "wd3", n=8)
			m.cyl(0.8, 1.0, (s * 16.6, y, 22.7), "g1", n=8, r2=0.6)
			m.cyl(0.6, 1.0, (s * 16.6, y, 21.7), "g1", n=8, r2=0.8)
			m.cyl(0.6, 0.3, (s * 16.6, y, 21.4), "wd3", n=8)
	cbox(m, (26.0, 0.7, 0.9), (0, -1.75, 25.1), "wd1", "wd2", ch=0.16)
	for y in (-3.2, 3.2):  # head beams, bracket blocks
		cbox(m, (34.2, 1.6, 1.8), (0, y, 26.6), "wd2", "wd1", ch=0.3)
		for k in range(5):
			x = -13.6 + k * 6.8
			cbox(m, (2.0, 2.4, 0.9), (x, y * 1.15, 27.8), "wd1", "wd2", ch=0.16)
	cbox(m, (33.6, 5.2, 1.0), (0, 0, 28.6), "wd3", "wd1")
	for y in (-4.9, 4.9):  # purlins and rafters carry the eaves: what a player sees from below
		cbox(m, (34.0, 0.8, 0.8), (0, y, 28.1), "wd2", "wd1", ch=0.16)
	for k in range(15):
		x = -16.1 + k * 2.3
		m.box((0.7, 13.2, 0.55), (x, 0, 28.7), "wd2")
		for y in (-6.65, 6.65):
			m.box((0.8, 0.15, 0.65), (x, y, 28.7), "gd1")
	m.roof(0, 0, 29.4, 35.2, 14, 5.2, "tileb", ridge=0.62, lift=1.5, trim="tl2")
	for k in range(13):  # tile ribs down both slopes
		x = -10.2 + k * 1.7
		for s in (-1, 1):
			m.beam((x * 1.45, s * 6.5, 29.7), (x * 1.15, s * 2.8, 31.3), 0.4, "tl1")
	for s in (-1, 1):  # gold ridge ends
		cbox(m, (1.4, 1.8, 2.2), (s * 11.1, 0, 35.4), "gd2", "gd1", ch=0.4)
	if locked:
		for s in (-1, 1):  # one chain from jamb to jamb through the lock
			chain(m, (s * 11.6, -3.0, 23.6), (s * 2.2, -3.9, 19.4), 2.4, 0.36, sag=0.5)
			cbox(m, (1.6, 1.4, 1.6), (s * 11.8, -2.2, 23.8), "ir2", "ir3", ch=0.2)
		padlock(m, (0, -4.2, 18.3), 1.05)  # its body spans z 15.4 to 21.4: over the Index roof from the spawn
		for x in (-6.4, -3.2, 0, 3.2, 6.4):  # an iron grille shuts the back
			hh = SPRING + math.sqrt(AR**2 - x * x)
			m.beam((x, 1.95, DAIS), (x, 1.95, hh), 0.7, "ir2", 6)
		for z in (6.5, 13, 19):
			hh = AR if z < SPRING else math.sqrt(AR**2 - (z - SPRING) ** 2)
			m.box((hh * 2, 0.5, 0.9), (0, 2.1, z), "ir1")
		padlock(m, (0, 3.6, 13), 0.8, True)


CRACK = [(0.5, 0.8), (-0.9, 5.2), (1.1, 9.6), (-0.6, 13.4), (1.4, 17.8), (-1.0, 22.4), (0.8, 26.4), (-0.3, 30.6)]  # x, z of the crack, bottom up


def half_stone(s):
	outer = [(9.4, 0.8), (10.0, 5.5), (9.2, 12.0), (9.5, 18.0), (8.2, 24.0), (6.0, 29.5), (2.6, 33.2)] if s > 0 else [(9.8, 0.8), (9.2, 6.5), (9.7, 13.5), (8.6, 19.5), (7.8, 25.0), (4.6, 28.6), (2.2, 31.0)]
	if s > 0:
		return outer + CRACK[::-1]
	return CRACK + [(-x, z) for x, z in outer[::-1]]


def concept_c(m, locked):
	rng = random.Random(5)
	dais(m, locked)
	slide = 0.8 if locked else 6.4
	tilt = 0.0 if locked else math.radians(2.0)
	side_xf = {s: Matrix.Translation(Vector((s * slide, 0, 0))) @ Matrix.Rotation(s * tilt, 4, "Y") for s in (-1, 1)}
	# cracks run out from where the lock sits, different on each half and each face: (x, z) polylines in the half's own axes
	veins = {
		(1, -1): (((2.4, 19.2), (3.0, 20.2), (3.6, 22.8), (5.4, 24.6), (5.6, 27.0)), ((3.0, 20.2), (5.8, 20.6), (8.2, 22.2)), ((2.2, 10.9), (3.2, 10.4), (4.4, 7.0), (7.6, 5.2)), ((4.4, 7.0), (4.0, 3.6))),
		(-1, -1): (((-2.2, 23.0), (-2.8, 24.0), (-3.2, 27.6)), ((-1.9, 15.7), (-3.4, 16.4), (-5.2, 14.8), (-8.0, 16.0)), ((-5.2, 14.8), (-6.2, 12.2), (-5.6, 9.0)), ((-2.6, 4.9), (-3.0, 4.6), (-5.0, 5.6))),
		(1, 1): (((2.4, 8.4), (3.4, 8.0), (5.0, 9.4), (8.4, 8.2)), ((2.6, 21.6), (3.2, 22.4), (3.4, 26.0))),
		(-1, 1): (((-2.2, 11.8), (-3.6, 11.0), (-4.4, 7.4)), ((-3.6, 11.0), (-7.4, 12.0)), ((-2.6, 22.4), (-3.8, 21.6), (-6.4, 22.4))),
	}
	for s in (-1, 1):
		xf = side_xf[s]
		prism(m, half_stone(s), -3.4, 3.4, ("k1", "k1", "k2"), ("k2", "k4"), 1.0, "k3", ("k1", "k2"), xf, relief=0.4)
		T = lambda x, y, z: xf @ Vector((x, y, z))
		for (xa, za), (xb, zb) in zip(CRACK, CRACK[1:]):  # the lit face of the break, with darker banding
			for y0, y1, colour in ((-2.4, -1.0, "g2"), (-1.0, 1.0, "g1"), (1.0, 2.4, "g2")):
				q = [T(xa - s * 0.08, y0, za), T(xb - s * 0.08, y0, zb), T(xb - s * 0.08, y1, zb), T(xa - s * 0.08, y1, za)]
				m.face(q, colour)
				m.face(q[::-1], colour)
		for f in (-1, 1):
			for line in veins[(s, f)]:
				for i, ((x0, z0), (x1, z1)) in enumerate(zip(line, line[1:])):
					m.beam(T(x0, f * 3.3, z0), T(x1, f * 3.3, z1), 1.0 - 0.14 * i, "g1" if i == 0 else "g2")
		for k in range(5):  # spalls up the outer side, so it is no flat wall
			rock(m, (2.2, rng.uniform(4, 6.4), rng.uniform(3, 5)), T(s * (8.9 - 0.15 * k), rng.uniform(-1.0, 1.0), 2.5 + k * 4.4), rng, K, sub=0)
		for bx, by in ((6.0, -4.5), (3.4, 4.7), (8.0, 4.2)):  # foot boulders
			rock(m, (4.2, 2.6, 3.2), T(s * bx, by, 1.6), rng, K)
		for cx, cy_, h, w, lx, ly in ((9.6, -5.0, 6.4, 1.9, 0.35, -0.25), (11.2, -3.4, 4.2, 1.4, 0.6, -0.1), (8.0, -6.0, 3.4, 1.2, 0.1, -0.5), (9.4, 5.2, 5.4, 1.7, 0.3, 0.3), (11.0, 3.8, 3.6, 1.2, 0.6, 0.1)):
			crystal(m, (s * min(cx + slide * 0.3, 12.4), cy_, 0.8), h, w, (s * lx, ly))
		for gy in (-9.6, 9.6):  # small guardian stones on the dais diagonals
			rock(m, (2.6, 2.2, 5.6), (s * 9.2, gy, DAIS + 2.2), rng, K, Matrix.Rotation(s * 0.06, 3, "Y"), flat=0.7, jit=0.08)
			cbox(m, (0.5, 0.3, 2.6), (s * 9.2, gy + math.copysign(1.12, gy), DAIS + 2.4), "g2", ch=0.08)
	# the sheet of rift light between the halves: their own broken outline
	left = [side_xf[-1] @ Vector((x, 0, z)) for x, z in CRACK]
	right = [side_xf[1] @ Vector((x, 0, z)) for x, z in CRACK]
	if locked:
		for i in range(len(CRACK) - 1):
			q = [left[i], right[i], right[i + 1], left[i + 1]]
			m.face(q, "g2")
			m.face(q[::-1], "g2")
		for z in (9.2, 23.2):  # iron bands round the whole stone
			w = 10.6 if z < 12 else 9.3
			for y in (-3.8, 3.8):
				cbox(m, (w * 2 + 0.9, 0.7, 1.6), (0, y, z), "ir2", "ir3", ch=0.15)
				for k in range(6):
					cbox(m, (0.8, 0.5, 0.8), (-w + 1.4 + k * (2 * w - 2.8) / 5, y * 1.09, z), "gd1", "gd3", ch=0.2)
			for s in (-1, 1):
				cbox(m, (0.7, 8.2, 1.6), (s * (w + 0.2), 0, z), "ir2", "ir3", ch=0.15)
		for y in (-1, 1):
			for s in (-1, 1):  # chains from the dais edge and the bands' corners to the lock
				chain(m, (s * 11.6, y * 8.6, 1.5), (s * 2.0, y * 5.2, CY + 1.6), 2.3, 0.32)
				chain(m, (s * 8.8, y * 4.4, 23.0), (s * 2.0, y * 4.9, CY + 6.2), 2.1, 0.3, sag=0.6)
				cbox(m, (1.6, 1.6, 1.0), (s * 11.6, y * 8.8, 1.5), "ir2", "ir3", ch=0.2)
		padlock(m, (0, -5.4, CY + 4.2), 1.2)  # high: the Index roof hides the gate below about z 16 from the spawn
		padlock(m, (0, 5.4, CY + 4.2), 1.0, True)
	else:
		c0 = Vector((0, 15))
		poly = [Vector((0, 1.3))] + [Vector((p.x + 0.1, p.z)) for p in right[1:-1]] + [Vector((0.6, 29.4))] + [Vector((p.x - 0.1, p.z)) for p in left[1:-1]][::-1]

		def outline(t):
			d = Vector((math.cos(t), math.sin(t)))
			best = 1.0
			for a, b in zip(poly, poly[1:] + poly[:1]):
				e = b - a
				den = d.x * e.y - d.y * e.x
				if abs(den) < 1e-9:
					continue
				w = a - c0
				u, v = (w.x * e.y - w.y * e.x) / den, (w.x * d.y - w.y * d.x) / den
				if u > 0 and -1e-6 <= v <= 1 + 1e-6:
					best = max(best, u)
			return best

		rift_sheet(m, outline, c0.y, 0, False, seeds=40)
		for i in range(10):
			z = 5 + i * 2.5
			sc = rng.uniform(0.7, 1.6)
			shard(m, (rng.choice((-1, 1)) * rng.uniform(3.4, 5.6), rng.choice((-1, 1)) * rng.uniform(1.6, 3.0), z), (sc, sc, sc * 1.5), rng, K)
		for s in (-1, 1):  # the burst bands' stubs stay on the halves, a chain end hangs from each
			for z in (9.2, 23.2):
				for y in (-3.75, 3.75):
					cbox(m, (3.6, 0.7, 1.6), side_xf[s] @ Vector((s * 7.0, y, z)), "ir2", "ir3", Matrix.Rotation(s * tilt, 3, "Y"), 0.15)
					m.box((0.8, 0.6, 0.8), side_xf[s] @ Vector((s * 7.0, y * 1.09, z)), "gd1")
			chain(m, side_xf[s] @ Vector((s * 6.6, -4.4, 22.4)), side_xf[s] @ Vector((s * 6.6, -4.4, 16.4)), 2.0, 0.28)


def concept_current(m, locked):
	src = pw.world_gate()
	m.v, m.f, m.fm, m.mats = src.v, src.f, src.fm, src.mats
	if locked:
		m.mats = ["gdim1" if n == "gswirl" else n for n in m.mats]
		# the lip stays bright, the disc is dim (build_gate): the lip faces come first, the last two faces are the disc
		bright = len(m.mats)
		m.mats.append("g2")
		for i in range(len(m.f) - 2):
			if m.mats[m.fm[i]] == "gdim1":
				m.fm[i] = bright
		for t in (40, -40):
			m.box((R * 2.1, 1.4, 1.4), (0, -1.2, CY), "ir3", Matrix.Rotation(math.radians(t), 3, "Y"))
		m.box((5, 1.8, 5.6), (0, -2.2, CY - 0.8), "gd1")
		m.box((3.2, 1, 3), (0, -2.2, CY + 3), "ir3")


CONCEPTS = {"A": concept_a, "B": concept_b, "C": concept_c, "current": concept_current}


BIG = 1.3  # the owner option: the same gate enlarged about its own position


def gate(key, locked, scale=1.0):
	global RNG
	RNG = random.Random(3)
	m = bp.M("Gate_" + key, MAT)
	CONCEPTS[key](m, locked)
	if scale != 1:
		m.v = [p * scale for p in m.v]
	return m


def figure(name, matrix):
	"""A plain blocky 5.5-stud figure for scale."""
	m = bp.M(name, matrix)
	s = 5.5 / 5.6
	for q in (-1, 1):
		m.box((0.95 * s, 1 * s, 2 * s), (q * 0.5 * s, 0, 1 * s), "blue")
		m.box((0.9 * s, 0.9 * s, 2 * s), (q * 1.48 * s, 0, 3 * s), "skin")
	m.box((2 * s, 1.1 * s, 2 * s), (0, 0, 3 * s), "red")
	m.box((1.4 * s, 1.4 * s, 1.4 * s), (0, 0, 4.7 * s), "skin")
	m.box((1.5 * s, 1.5 * s, 0.45 * s), (0, 0, 5.375 * s), "black")
	return m


# --- scenes ---
def scene_for(world, fast, context=True):
	v = pw.VARIANTS["B"] if world == 2 else {"pal": {}, "glow": {}}
	pw.reset(v)
	bp.PAL.update(PAL)
	bp.GLOW.update(COLOURS["cyan" if world == 2 else "violet"])
	if world == 1:
		bp.GLOW["gswirl"] = ("#9646FF", 2.5)  # the current gate leads to World 2 here: violet (SpawnArea swirl)
	scene = bpy.context.scene
	cam = bp.setup_world(scene)
	scene.render.resolution_x, scene.render.resolution_y = (640, 360) if fast else (1280, 720)
	scene.render.threads_mode, scene.render.threads = "FIXED", 2
	scene.eevee.taa_render_samples = 8 if fast else 24
	build_track.bloom(scene)
	if world == 2:
		pw.sky(scene, v)
	bp.build(scene)
	col = bpy.data.collections.new("Gate")
	scene.collection.children.link(col)
	if world == 2:
		for m in pw.accents() + [pw.rift(v)] + pw.islands():
			m.build(col)
		rx, rz = bp.along(bp.AXIS_LEN + 80)
		pw.point(col, (rx, 70, rz), "#7A7CFF", 80000, 20)
	figure("Scale_Gate_Big", MAT @ Matrix.Translation(Vector((-17.5, -17, 0)))).build(col).hide_render = True
	figure("Scale_Gate", MAT @ Matrix.Translation(Vector((-14, -12.6, 0)))).build(col)
	figure("Scale_Spawn", MAT @ Matrix.Translation(Vector((0, -SPAWN_D, bp.SPAWN_TOP - bp.TOP))) @ Matrix.Rotation(math.pi, 4, "Z")).build(col)
	lo = bpy.data.objects.new("GateLight", bpy.data.lights.new("GateLight", "POINT"))
	lo.data.energy, lo.data.shadow_soft_size = 2500 if world == 1 else 5000, 4
	lo.data.color = bp.rgb("#9646FF" if world == 1 else "#46D2FF")[:3]
	lo.location = MAT @ Vector((0, -7, CY))
	col.objects.link(lo)
	return cam, col


VIEWS = {  # local eye, local look, vertical fov
	"front": ((0, -35.5, 8), (0, 0, 15.6), 68),
	"34": ((-33, -36, 13), (0, 0, 15.2), 58),
	"close": ((-7, -17.5, 6.5), (1, 0, 14), 60),
	"spawn": ((0, -SPAWN_D - 12, bp.SPAWN_TOP - bp.TOP + 7.5), (0, 0, 10), 70),
	"back": ((-30, 37, 15), (0, 0, 15.2), 58),
}


def shoot(cam, eye, look, fov, path):
	e, l = MAT @ Vector(eye), MAT @ Vector(look)
	cam.location = e
	cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(fov)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("SHOT", path, flush=True)


def stats(m, label):
	tris = sum(len(f) - 2 for f in m.f)
	xs, ys, zs = zip(*[tuple(p) for p in m.v])
	w, d, h = max(xs) - min(xs), max(ys) - min(ys), max(zs)
	body = [p for p in m.v if abs(p.x) < 5 and p.z > 26]
	print("STATS %s tris %d size x %.1f y %.1f top %.1f floor %.2f | max |x| %.1f max |y| %.1f | top in label strip (|x|<5) %.1f | footprint %s" % (label, tris, w, d, h, min(zs), max(map(abs, xs)), max(map(abs, ys)), max([p.z for p in body], default=0), "ok" if max(map(abs, xs)) <= LIMIT_X / 2 + 0.01 and max(map(abs, ys)) <= LIMIT_Y / 2 + 0.6 else "OVER"), flush=True)


def sheet(out, name, files, crop=None):
	"""A 2 x 2 comparison of finished renders (A, B / C, current), optionally cropped to a centre window (w, h, cx, cy in px)."""
	import numpy as np

	cells = []
	for f in files:
		img = bpy.data.images.load(os.path.join(out, f))
		w, h = img.size
		if crop:
			px = np.empty(w * h * 4, np.float32)
			img.pixels.foreach_get(px)
			cw, ch, cx, cy = crop
			y0 = h - cy - ch // 2
			px = px.reshape(h, w, 4)[y0 : y0 + ch, cx - cw // 2 : cx + cw // 2]
			px = px.repeat(640 // cw, 0).repeat(640 // cw, 1)
		else:
			img.scale(640, 360)
			px = np.empty(640 * 360 * 4, np.float32)
			img.pixels.foreach_get(px)
			px = px.reshape(360, 640, 4)
		cells.append(px)
	full = np.concatenate([np.concatenate(cells[2:], 1), np.concatenate(cells[:2], 1)], 0)  # image rows run bottom up
	o = bpy.data.images.new(name, full.shape[1], full.shape[0])
	o.pixels.foreach_set(full.astype(np.float32).ravel())
	o.filepath_raw, o.file_format = os.path.join(out, name + ".jpg"), "JPEG"
	o.save()
	print("SHEET", name, flush=True)


def hull2(pts):
	pts = sorted({(round(p[0], 3), round(p[1], 3)) for p in pts})
	cr = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
	out = []
	for seq in (pts, pts[::-1]):
		h = []
		for p in seq:
			while len(h) >= 2 and cr(h[-2], h[-1], p) <= 0:
				h.pop()
			h.append(p)
		out += h[:-1]
	return [Vector(p) for p in out]


def poly_gap(A, B):
	"""Distance between two convex polygons (0 = touching or overlapping)."""
	for P, Q in ((A, B), (B, A)):
		for a, b in zip(P, P[1:] + P[:1]):
			n = Vector(((b - a).y, -(b - a).x)).normalized()
			if min((q - a).dot(n) for q in Q) > 0:
				break
		else:
			continue
		break
	else:
		return 0.0

	def seg(p, a, b):
		t = max(0, min(1, (p - a).dot(b - a) / max((b - a).length_squared, 1e-9)))
		return (p - a - (b - a) * t).length

	return min(min(seg(p, a, b) for p in P for a, b in zip(Q, Q[1:] + Q[:1])) for P, Q in ((A, B), (B, A)))


def clearances():
	"""Plan-view gaps from each gate's convex outline to its neighbours, from the plaza draft's own meshes. x, y in Blender."""
	pw.reset({"pal": {}, "glow": {}})
	bp.PAL.update(PAL)
	bp.GLOW.update(COLOURS["violet"])
	bp.setup_world(bpy.context.scene)
	bp.build(bpy.context.scene)
	spots = {"Index": bp.INDEX, "Market": bp.MARKET_STALL}
	near = {}
	for ob in bpy.data.objects:
		if ob.type != "MESH" or ob.name.startswith(("Ctx_Ground", "Ctx_Backdrop", "Ctx_Petals", "PlazaFloor", "Trails", "Ctx_Trail")):
			continue
		W = [ob.matrix_world @ v.co for v in ob.data.vertices]
		groups = {}
		# whole-plaza meshes are split into loose parts, so a leg is its own footprint
		parent = list(range(len(W)))

		def find(i):
			while parent[i] != i:
				parent[i] = parent[parent[i]]
				i = parent[i]
			return i

		if any(k in ob.name for k in ("SkyLoop", "Ctx_Roads", "Ctx_Kept")):
			seen = {}
			for i, p in enumerate(W):  # faces do not share vertices in the kit: weld by position
				parent[i] = seen.setdefault(tuple(round(c, 2) for c in p), i)
			for poly in ob.data.polygons:
				for i in poly.vertices:
					parent[find(i)] = find(poly.vertices[0])
			for i, p in enumerate(W):
				groups.setdefault(find(i), []).append(p)
		else:
			groups[0] = W
		for g in groups.values():
			near.setdefault(ob.name, []).append((hull2([(p.x, p.y) for p in g]), min(p.z for p in g), max(p.z for p in g)))
	floor_lim = (94, 110)
	for k in ("A", "B", "C", "current"):
		for sc in (1.0, BIG):
			best = {}
			for locked in (True, False):
				m = gate(k, locked, sc)
				W = [MAT @ p for p in m.v]
				top = max(p.z for p in W)
				H = hull2([(p.x, p.y) for p in W])
				over = max(max(p.x for p in W) - floor_lim[0], max(p.y for p in W) - floor_lim[1], 0)
				for name, parts in near.items():
					gap = min((poly_gap(H, h) for h, lo, hi in parts if lo < top), default=1e9)
					best[name] = min(best.get(name, 1e9), gap)
				best["_over"] = max(best.get("_over", 0), over)
			nb = sorted((v, n) for n, v in best.items() if not n.startswith("_"))[:6]
			print("CLEAR %s x%.1f floor overhang %.1f | %s" % (k, sc, best["_over"], ", ".join("%s %.1f" % (n, v) for v, n in nb)), flush=True)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	out = argv[argv.index("--out") + 1] if "--out" in argv else OUT
	fast = "--fast" in argv
	if "--clear" in argv:
		clearances()
		return
	big = "--big" in argv
	sc = BIG if big else 1.0
	keys = [a for a in argv if a in CONCEPTS] or list(CONCEPTS)
	states = [a for a in argv if a in ("locked", "open", "w1open")] or (["locked", "open"] if big else ["locked", "open", "w1open"])
	views = [a for a in argv if a in VIEWS]
	for k in keys:
		for locked in (True, False):
			stats(gate(k, locked, sc), k + ("_big" if big else "") + (" locked" if locked else " open"))
	if "--stats" in argv:
		return
	os.makedirs(out, exist_ok=True)
	for world in (1, 2):
		todo = [s for s in states if (s == "open") == (world == 2)]
		if not todo:
			continue
		cam, col = scene_for(world, fast)
		if big:
			bpy.data.objects["Scale_Gate"].hide_render, bpy.data.objects["Scale_Gate_Big"].hide_render = True, False
		for state in todo:
			for k in keys:
				ob = gate(k, state == "locked", sc).build(col)
				for vname in views or VIEWS:
					if state == "w1open" and vname != "front" :
						continue
					eye, look, fov = VIEWS[vname]
					if big and vname == "front":
						look, fov = (0, 0, 20), 82
					elif big and vname != "spawn":
						eye, look = tuple(c * (BIG if vname != "close" else 1.2) for c in eye), (0, 0, look[2] * BIG)
						fov = fov + 4
					shoot(cam, eye, look, fov, os.path.join(out, "%s_%s_%s.jpg" % (k + ("_big" if big else ""), state, vname)))
				bpy.data.objects.remove(ob)
	if not views and keys == list(CONCEPTS) and not fast:  # comparisons, only after a full render
		tag = "_big" if big else ""
		row = lambda st, v: ["%s_%s_%s.jpg" % (k + tag, st, v) for k in keys]
		for st in states:
			sheet(out, "compare%s_%s_front" % (tag, st), row(st, "front"))
			if st != "w1open":
				sheet(out, "compare%s_%s_34" % (tag, st), row(st, "34"))
				sheet(out, "compare%s_%s_back" % (tag, st), row(st, "back"))
				sheet(out, "compare%s_%s_spawn_zoom" % (tag, st), row(st, "spawn"), (320, 180, 640, 310))


if __name__ == "__main__":
	main()
