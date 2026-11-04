# Target look for db_hero (design doc section 5): chunky faceted solids over the R15 blocks, no ink outline. Every solid's
# shading is baked per facet into a ramp of the atlas's Hair strip, so hard planes read even in flat light.
import re
from math import cos, pi, radians, sin
from collections import Counter

from atlas import FACES, SIZE, shade
from db_common import circle
from leaf_common import begin_clip, end_clip
from style2 import H, Kit, Ramps, _chunk_rings, face
from style3 import big_head, finish

SKIN = "#f4bb8a"
SKIN_D = "#cf8e62"
GI = "#f47a14"
GI_D = "#c2560c"
HAIRC = "#08080e"
BLUE = "#2233b4"
LINE = "#4a2010"
DEFAULT = GI
R = Ramps(
	hair=["#040408", "#08080f", "#12122a", "#2e2c88", "#6058ec"],
	skin=["#b87a50", "#dfa070", SKIN, "#fbd0a4"],
	gi=["#a2440a", "#cc5c0c", GI, "#ff9a2c", "#ffbc62"],
	blue=["#121c70", "#1c2a9c", BLUE, "#3448d8", "#5468ee"],
	yellow=["#b88a10", "#e8b81c", "#ffd83a", "#ffec80"],
	red=["#7a0f1a", "#b81c28", "#e03440", "#f46a6a"],
)
HAIR = {"colour": HAIRC, "locks": []}
PROPS = []
LIGHT = (-0.42, -0.56, 0.71)
HAIR_LIGHT = (-0.25, -0.18, 0.95)  # mostly up, so the planes catch it from the back too


def dot(n, l):
	return n[0] * l[0] + n[1] * l[1] + n[2] * l[2]


def solid(k, part, name, rings, ramp="gi", base=0.5, amp=0.42, grad=0.12, light=LIGHT, vfn=None, curve=None, art=None):
	"""Closed solid lofted through equal-length rings, quads split into triangles so bent rings show planes. Each facet
	takes one ramp tone from its normal plus a soft gradient over height. art = block face name: planar art instead."""
	n = len(rings[0])
	verts = [p for r in rings for p in r]
	faces = []
	for i in range(len(rings) - 1):
		for j in range(n):
			a, b, c, d = i * n + j, i * n + (j + 1) % n, (i + 1) * n + (j + 1) % n, (i + 1) * n + j
			faces += [(a, b, c), (a, c, d)]
	faces.append(list(range(n)))
	faces.append([(len(rings) - 1) * n + j for j in range(n)])
	o = k._mesh(name, part, verts, faces)
	mesh = o.data
	assert set(Counter(e for p in mesh.polygons for e in p.edge_keys).values()) == {2}, name + " is not closed"
	uv = mesh.uv_layers.new(name="UVMap").data
	zs = [v[2] for v in verts]
	lo, hi = min(zs), max(zs)
	for p in mesh.polygons:
		d = dot(p.normal, light)
		tone = base + amp * (curve(d) if curve else d)
		for li in p.loop_indices:
			co = mesh.vertices[mesh.loops[li].vertex_index].co
			if art:
				x0, y0, pw, ph = FACES[art][:4]
				u = (1 + co.x) / 2 if art.endswith("_F") else (1 - co.x) / 2
				uv[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + (4 - co.z) / 2 * (ph - 4)) / SIZE)
				continue
			g = grad * ((co.z - lo) / max(hi - lo, 1e-6) - 0.5)
			uv[li].uv = R.uv(ramp, tone + g + (vfn(co) if vfn else 0))
	return o


def rect(z, x0, x1, y0, y1, c=0.07):
	"""A chamfered box section."""
	return [(x1 - c, y0, z), (x1, y0 + c, z), (x1, y1 - c, z), (x1 - c, y1, z), (x0 + c, y1, z), (x0, y1 - c, z), (x0, y0 + c, z), (x0 + c, y0, z)]


def box(k, part, name, rows, ramp="gi", c=0.07, **kw):
	"""rows = (z, x0, x1, y0, y1): a chamfered block."""
	return solid(k, part, name, [rect(*r, c=c) for r in rows], ramp, **kw)


def block(k, part, name, x0, x1, y0, y1, z0, z1, ramp="gi", c=0.05, **kw):
	"""A plain block with chamfers all round."""
	rows = [(z0, x0 + c, x1 - c, y0 + c, y1 - c), (z0 + c, x0, x1, y0, y1), (z1 - c, x0, x1, y0, y1), (z1, x0 + c, x1 - c, y0 + c, y1 - c)]
	return box(k, part, name, rows, ramp, c=c, **kw)


def slab(k, part, name, spine, ramp="gi", thick=0.06, **kw):
	"""A thick strap running down the body: spine = (x0, x1, y, z), rows with their front at y."""
	return solid(k, part, name, [[(x0, y, z), (x1, y, z), (x1, y + thick, z), (x0, y + thick, z)] for x0, x1, y, z in spine], ramp, **kw)


def rope(k, part, name, pts, r=0.05, ramp="red", **kw):
	"""A chunky low-poly rope through pts, square-section."""
	from mathutils import Vector

	pts = [Vector(p) for p in pts]
	rings = []
	for i, p in enumerate(pts):
		d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
		a = d.cross(Vector((0.13, 0.27, 0.95))).normalized()
		b = d.cross(a).normalized()
		rings.append([tuple(p + (a * sa + b * sb) * r) for sa, sb in ((1, 0), (0, 1), (-1, 0), (0, -1))])
	return solid(k, part, name, rings, ramp, **kw)


# ---- hair. +x is the viewer's right, front is -y. Lopsided on purpose, as in the target. q under 1: fat, then a sharp point.
_S = dict(flat=0.62, p=1.6, q=0.85)
SPIKES = [
	# two tall masses swept up and back
	H((-0.1, 0.25, 5.7), (-0.05, 0.25, 6.6), (-0.55, 0.35, 7.18), 0.85, **_S),
	H((0.45, 0.3, 5.7), (0.5, 0.45, 6.45), (0.95, 0.6, 6.9), 0.56, **_S),
	# crown masses above the fringe
	H((-0.35, -0.3, 5.75), (-0.35, -0.4, 6.35), (-0.98, -0.25, 6.6), 0.6, **_S),
	H((0.35, -0.3, 5.75), (0.55, -0.4, 6.25), (1.0, -0.25, 6.4), 0.55, **_S),
	# three wide to the viewer's left, each curling up at the tip
	H((-0.55, 0.2, 5.7), (-1.5, 0.3, 6.0), (-2.35, 0.35, 6.7), 0.7, **_S),
	H((-0.7, 0.15, 5.3), (-1.6, 0.15, 5.15), (-2.7, 0.2, 5.55), 0.66, **_S),
	H((-0.7, 0.2, 4.95), (-1.4, 0.2, 4.5), (-2.1, 0.25, 4.55), 0.5, **_S),
	# three to the viewer's right
	H((0.6, 0.2, 5.7), (1.4, 0.25, 5.85), (2.1, 0.3, 6.35), 0.58, **_S),
	H((0.7, 0.15, 5.3), (1.6, 0.15, 5.1), (2.6, 0.2, 5.45), 0.6, **_S),
	H((0.7, 0.2, 4.95), (1.35, 0.2, 4.5), (2.0, 0.25, 4.5), 0.46, **_S),
	# three off the back
	H((0.0, 0.5, 5.5), (0.05, 1.25, 5.6), (0.15, 1.6, 6.2), 0.6, **_S),
	H((-0.45, 0.55, 4.95), (-0.6, 1.15, 4.85), (-0.95, 1.5, 5.2), 0.5, **_S),
	H((0.45, 0.55, 4.95), (0.6, 1.15, 4.8), (0.9, 1.5, 5.1), 0.5, **_S),
]
_F = dict(flat=0.55, p=1.3, q=0.75)
FRINGE = [
	# chunky forehead locks, tips pointing down and out from a parting left of centre
	H((-0.66, -0.6, 5.8), (-0.86, -0.9, 5.5), (-0.84, -0.88, 5.02), 0.34, **_F),
	H((-0.3, -0.62, 5.85), (-0.52, -0.96, 5.5), (-0.44, -0.94, 4.96), 0.38, **_F),
	H((0.06, -0.64, 5.85), (0.02, -1.0, 5.5), (-0.06, -0.96, 5.1), 0.36, **_F),
	H((0.42, -0.62, 5.85), (0.44, -0.98, 5.5), (0.44, -0.94, 4.98), 0.38, **_F),
	H((0.72, -0.56, 5.78), (0.86, -0.88, 5.45), (0.84, -0.88, 5.05), 0.32, **_F),
	# the sideburns
	H((-0.88, -0.3, 5.45), (-0.93, -0.36, 5.05), (-0.9, -0.42, 4.68), 0.2, **_F),
	H((0.88, -0.3, 5.45), (0.93, -0.36, 5.05), (0.9, -0.42, 4.68), 0.2, **_F),
]


def _hair_curve(d):
	# only planes turned up to the key light go blue-violet; the rest stays near black
	return max(0.0, d - 0.16) * 2.0


def _hair(k):
	head = (0, 0, 5.0)

	def far(co):
		return 0.07 * min(2.0, ((co.x - head[0]) ** 2 + (co.y - head[1]) ** 2 + (co.z - head[2]) ** 2) ** 0.5) - 0.07

	shard = dict(ramp="hair", base=0.14, amp=0.42, grad=0.0, light=HAIR_LIGHT, curve=_hair_curve, vfn=far)
	# the skull cap: its rim drops from the hairline at the front to the nape at the back
	cap = []
	for z_front, z_back, sw, sd in ((5.4, 4.26, 0.89, 0.88), (5.72, 5.0, 0.93, 0.92), (6.05, 5.85, 0.76, 0.74), (6.22, 6.18, 0.38, 0.36)):
		ring = []
		for i in range(10):
			ang = i * 0.6283 + 0.16
			c, s = cos(ang), sin(ang)
			px, py = abs(c) ** 0.6 * (1 if c > 0 else -1), abs(s) ** 0.6 * (1 if s > 0 else -1)
			t = max(0.0, min(1.0, (py + 0.7) / 1.0))  # the rim is down at the nape from just behind the ear
			ring.append((sw * px, sd * py, z_front + (z_back - z_front) * t))
		cap.append(ring)
	solid(k, "Head", "HairCap", cap, **shard)
	for i, ch in enumerate(SPIKES + FRINGE):
		rings, _ = _chunk_rings(ch, 5, 5)
		solid(k, "Head", f"Spike{i}", rings, **shard)


# ---- the body


# y offsets of the gi front at x = -0.92, -0.46, 0, 0.46, 0.92: the big fold planes pulled down to the belt
_GI = [
	(4.05, 0.82, 0.42, (0, 0, 0, 0, 0)),
	(3.9, 1.04, 0.54, (0, 0, 0, 0, 0)),
	(3.5, 1.06, 0.56, (0.04, -0.08, 0, -0.08, 0.04)),
	(3.12, 1.04, 0.56, (0.1, -0.1, 0.05, -0.1, 0.1)),
	(2.84, 1.0, 0.54, (-0.04, 0.08, -0.05, 0.08, -0.04)),
]
_HIP = [
	(2.72, 1.0, 0.54, (0, 0, 0, 0, 0)),
	(2.4, 1.06, 0.6, (0.03, -0.05, 0.03, -0.05, 0.03)),
	(2.02, 1.06, 0.6, (-0.04, 0.03, 0.06, 0.03, -0.04)),
]


def _shell(k, name, table, **kw):
	rings = []
	for z, hw, hd, ys in table:
		xs = [q * (hw - 0.12) / 0.92 for q in (-0.92, -0.46, 0, 0.46, 0.92)]
		ring = [(x, -hd + y, z) for x, y in zip(xs, ys)]
		ring += [(hw, -hd + 0.12, z), (hw, hd - 0.12, z), (hw - 0.12, hd, z), (hw * 0.45, hd + 0.015, z), (0, hd, z), (-hw * 0.45, hd + 0.015, z), (-hw + 0.12, hd, z), (-hw, hd - 0.12, z), (-hw, -hd + 0.12, z)]
		rings.append(ring)
	return solid(k, "UpperTorso", name, rings, "gi", base=0.36, amp=0.46, **kw)


KX = 0.22  # the knot sits right of centre


def _torso(k):
	_shell(k, "GiShell", _GI)
	_shell(k, "Hip", _HIP, vfn=lambda co: -0.3 * max(0.0, (co.z - 2.36) / 0.3))
	# the undershirt in the V, a chunky wedge just under the lapels
	y = -0.66
	rows = [(-0.56, 0.56, y, 4.03), (-0.34, 0.34, y + 0.02, 3.74), (-0.1, 0.1, y + 0.02, 3.42), (-0.015, 0.015, y + 0.02, 3.26)]
	slab(k, "UpperTorso", "Undershirt", rows, "blue", thick=0.16, base=0.42, amp=0.26, vfn=lambda co: -0.4 * max(0.0, (co.z - 3.68) / 0.36))
	# the crossover: viewer's left lapel over the right one, each a raised plane
	for tag, s, zbot, over, yy in (("R", 1, 3.08, 0.08, -0.72), ("L", -1, 3.0, 0.18, -0.76)):
		rows = []
		for t, wid, dy in ((0, 0.34, 0), (0.45, 0.36, -0.02), (1, 0.3, 0.01)):
			xin = s * (0.56 + (-over - 0.56) * t)
			rows.append((min(xin, xin + s * wid), max(xin, xin + s * wid), yy + dy, 4.04 + (zbot - 4.04) * t))
		slab(k, "UpperTorso", "Lapel" + tag, rows, "gi", thick=0.2, base=0.46, amp=0.34)
	# the belt and its wrap
	block(k, "UpperTorso", "Belt", -1.08, 1.08, -0.63, 0.63, 2.64, 2.9, "blue", c=0.04, base=0.42, amp=0.34, grad=0.2)
	# the knot: two folded loops either side of a chunky wrap
	for tag, s in (("L", -1), ("R", 1)):
		rows = [(2.98, KX + s * 0.14, KX + s * 0.36, -0.73, -0.6), (2.8, KX + s * 0.14, KX + s * 0.56, -0.76, -0.6), (2.58, KX + s * 0.14, KX + s * 0.44, -0.72, -0.6)]
		box(k, "UpperTorso", "KnotLoop" + tag, [(z, min(a, b), max(a, b), y0, y1) for z, a, b, y0, y1 in rows], "blue", c=0.04, base=0.42, amp=0.4)
	block(k, "UpperTorso", "Knot", KX - 0.18, KX + 0.18, -0.82, -0.58, 2.54, 2.96, "blue", c=0.05, base=0.5, amp=0.4)
	# two wide tails on the viewer-right leg: past the hip they hand over to it, so they swing with it
	zs = 1.98
	for tag, x0, x1, ww0, ww1, z1, y in (("A", KX - 0.14, KX - 0.08, 0.13, 0.18, 1.42, -0.74), ("B", KX + 0.14, KX + 0.24, 0.13, 0.2, 1.26, -0.78)):

		def row(z, dy):
			t = (2.6 - z) / (2.6 - z1)
			cx, w = x0 + (x1 - x0) * t, ww0 + (ww1 - ww0) * t
			return (cx - w, cx + w, y + dy, z)

		slab(k, "UpperTorso", "TailTop" + tag, [row(2.6, 0), row(2.3, -0.02), row(zs, -0.06)], "blue", thick=0.07, base=0.44, amp=0.36)
		tail = slab(k, "LeftUpperLeg", "Tail" + tag, [row(zs + 0.02, -0.06), row(1.75, -0.12), row(1.5, -0.16), row(z1, -0.16)], "blue", thick=0.07, base=0.44, amp=0.36)
		for vt in tail.data.vertices:
			if vt.co.z < z1 + 0.01:
				vt.co.z += (vt.co.x - x1) * 0.35


# The trouser bag, +x leg: z, inner x, outer x, half depth, then 10 radial pushes (0 = outer, 3 = back-inner side, 7-8 = front).
_BAG = [
	(2.0, 0.03, 1.02, 0.6, (0,) * 10),
	(1.8, 0.1, 1.18, 0.7, (0, 0, 0, 0, 0, 0, -0.03, 0.04, -0.04, 0.03)),
	(1.56, 0.18, 1.3, 0.78, (0.03, 0, -0.02, 0, 0.02, 0, 0.05, -0.05, 0.05, -0.05)),
	(1.32, 0.24, 1.36, 0.8, (-0.03, 0.02, 0, 0.02, 0, 0.02, -0.05, 0.05, -0.04, 0.05)),
	(1.14, 0.26, 1.3, 0.76, (0.02, 0, 0, 0, 0, 0, 0.03, -0.03, 0.03, -0.02)),
	(1.02, 0.28, 1.14, 0.62, (0,) * 10),
	(0.96, 0.3, 0.98, 0.52, (0,) * 10),
]
# Big fold plates on the bag, +x leg: rows of (inner x, outer x, depth, z) and a tone: lit thigh, dark diagonal, lit lower bulge.
_FOLDS = [
	(((0.3, 1.0, 0.72, 1.92), (0.36, 1.1, 0.8, 1.62), (0.76, 1.16, 0.82, 1.4)), 0.66),
	(((0.98, 1.2, 0.8, 1.52), (0.46, 1.22, 0.84, 1.28), (0.44, 0.92, 0.8, 1.12)), 0.12),
	(((0.28, 0.5, 0.84, 1.24), (0.3, 0.72, 0.83, 1.1), (0.46, 0.72, 0.68, 1.01)), 0.6),
]


def _bag(k, part, s):
	rings = []
	for z, x0, x1, hd, push in _BAG:
		cx, hw = (x0 + x1) / 2, (x1 - x0) / 2
		ring = []
		for i in range(10):
			a = radians(i * 36 + 9)
			c, d = cos(a), sin(a)
			px, py = abs(c) ** 0.55 * (1 if c > 0 else -1), abs(d) ** 0.55 * (1 if d > 0 else -1)
			m = 1 + push[i]
			ring.append((s * (cx + hw * px * m), hd * py * m, z))
		rings.append(ring)
	solid(k, part, "Bag", rings, "gi", base=0.33, amp=0.56, grad=0.1, vfn=lambda co: -0.32 * max(0.0, (1.3 - co.z) / 0.3))
	for i, (rows, base) in enumerate(_FOLDS):
		for tag, side in (("F", -1), ("B", 1)):
			r = [(min(s * a, s * b), max(s * a, s * b), side * d, z) for a, b, d, z in rows]
			slab(k, part, f"Fold{tag}{i}", r, "gi", thick=-side * 0.14, base=base - (0.06 if side > 0 else 0), amp=0.2, grad=0.1)


def _boot(k, part, s):
	cx = s * 0.55
	# foot and shaft one block: the toe runs forward, the shaft stands on the heel
	rows = [(0.06, -0.86, 0.54), (0.24, -0.86, 0.54), (0.4, -0.72, 0.52), (0.54, -0.52, 0.5), (1.0, -0.5, 0.5)]
	box(k, part, "Boot", [(z, cx - 0.5, cx + 0.5, y0, y1) for z, y0, y1 in rows], "blue", c=0.09, base=0.34, amp=0.3, grad=0.0, vfn=lambda co: -0.22 * max(0.0, (co.z - 0.7) / 0.2))
	block(k, part, "BootSole", cx - 0.53, cx + 0.53, -0.89, 0.57, 0.0, 0.1, "yellow", c=0.025, base=0.42, amp=0.3)
	block(k, part, "BootCuff", cx - 0.54, cx + 0.54, -0.54, 0.54, 0.86, 1.02, "yellow", c=0.03, base=0.42, amp=0.3)
	# one yellow seam down the outer front to the toe, one down the heel
	x = cx + s * 0.34
	rows = [(0.88, -0.525), (0.54, -0.545), (0.4, -0.745), (0.24, -0.885), (0.1, -0.885)]
	slab(k, part, "Seam", [(x - 0.06, x + 0.06, y, z) for z, y in rows], "yellow", thick=0.05, base=0.44, amp=0.3)
	block(k, part, "Heel", cx - 0.06, cx + 0.06, 0.48, 0.56, 0.1, 0.88, "yellow", c=0.015, base=0.42, amp=0.3)
	# the rope: tied round the ankle, the bow on the outer front
	z = 0.62
	hw, y0, y1 = 0.51, -0.555, 0.535
	rope_kw = dict(base=0.34, amp=0.42, grad=0.0)
	rope(k, part, "Rope", [(cx + hw, y0, z), (cx + hw, y1, z), (cx - hw, y1, z), (cx - hw, y0, z), (cx, y0 - 0.01, z), (cx + hw, y0, z)], r=0.05, **rope_kw)
	bx, by = cx, y0 - 0.06
	for tag, d in (("A", 1), ("B", -1)):
		rope(k, part, "Bow" + tag, [(bx, by, z), (bx + d * 0.16, by - 0.05, z + 0.13), (bx + d * 0.37, by - 0.04, z + 0.13), (bx + d * 0.37, by - 0.03, z - 0.07), (bx + d * 0.16, by - 0.04, z - 0.07), (bx, by, z)], r=0.04, **rope_kw)
		rope(k, part, "BowEnd" + tag, [(bx, by, z), (bx + d * 0.08, by - 0.03, z - 0.16), (bx + d * 0.2, by - 0.03, z - 0.3)], r=0.04, **rope_kw)
	block(k, part, "BowKnot", bx - 0.06, bx + 0.06, by - 0.1, by + 0.04, z - 0.06, z + 0.06, "red", c=0.02, base=0.4, amp=0.42)


def _arm(k, part, s):
	ax = s * 1.5
	# the orange shoulder, then a short blue sleeve band: the arm below reads skin
	rows = [(4.08, 0.46, 0.46), (3.96, 0.55, 0.55), (3.74, 0.55, 0.55), (3.7, 0.5, 0.5)]
	box(k, part, "Shoulder", [(z, ax - w, ax + w, -d, d) for z, w, d in rows], "gi", c=0.09, base=0.42, amp=0.36)
	block(k, part, "Sleeve", ax - 0.535, ax + 0.535, -0.535, 0.535, 3.48, 3.76, "blue", c=0.05, base=0.42, amp=0.4, grad=0.14)
	# the chunky skin forearm
	rows = [(3.52, 0.515, 0.515), (3.0, 0.525, 0.525), (2.56, 0.515, 0.515)]
	box(k, part, "Forearm", [(z, ax - w, ax + w, -d, d) for z, w, d in rows], "skin", c=0.07, base=0.44, amp=0.34, grad=0.1)
	# the wristband
	block(k, part, "Wrist", ax - 0.55, ax + 0.55, -0.55, 0.55, 2.3, 2.6, "blue", c=0.05, base=0.44, amp=0.42, grad=0.16)
	_hand(k, part, ax)


def _hand(k, part, ax):
	"""A smooth Roblox hand: one plain chamfered block, as wide as the forearm's end."""
	block(k, part, "Hand", ax - 0.515, ax + 0.515, -0.515, 0.515, 1.8, 2.32, "skin", c=0.07, base=0.46, amp=0.34, grad=0.08)


def _chest_mark(k):
	"""The disc on the viewer-right chest, its art planar from the Torso_F face."""
	rings = [[(0.64 + 0.24 * cos(2 * pi * i / 16), y, 3.3 + 0.24 * sin(2 * pi * i / 16)) for i in range(16)] for y in (-0.5, -0.71)]
	solid(k, "UpperTorso", "ChestMark", rings, art="Torso_F")


def _back_mark(k):
	"""The disc on the gi's back, its art planar from the Torso_B face."""
	rings = [[(0.44 * cos(2 * pi * i / 16), y, 3.45 + 0.44 * sin(2 * pi * i / 16)) for i in range(16)] for y in (0.5, 0.585)]
	solid(k, "UpperTorso", "BackMark", rings, art="Torso_B")


# style3's jaw, a touch narrower: the target's head is about 0.8 of the torso's width
HEAD_ROWS = [(0, 0, 3.98, 0.52, 0.56), (0, 0, 4.16, 0.74, 0.74), (0, 0, 4.44, 0.84, 0.8), (0, 0, 5.3, 0.84, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	_hair(k)
	_torso(k)
	_chest_mark(k)
	_back_mark(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, f"{side}UpperArm", s)
		part = f"{side}UpperLeg"
		# the leg block stays inside the bag and boot; narrowed so the real gap between the boots shows
		k.reshape(part, f"{side}Leg", [(s * 0.62, 0, 2.0, 0.36, 0.36), (s * 0.62, 0, 0.0, 0.36, 0.36)], corner=0.12, nc=1)
		_bag(k, part, s)
		_boot(k, part, s)
	finish()


# ---- the atlas


def glyph_front(f, cx, cy, s, colour="#14141c"):
	"""The chest mark, strokes on a 40-box."""
	for d, w in (
		(("M-16 -15H16M-11 -4H11"), 2.8),  # two bars
		(("M0 -15V-4"), 2.5),
		(("M-3 -4L-16 18M3 -4Q5 13 18 16"), 2.8),  # two legs
	):
		f.path(_at(d, cx, cy, s), stroke=colour, sw=w * s)


def glyph_back(f, cx, cy, s, colour="#14141c"):
	"""The large back mark, strokes on a 44-box."""
	for d, w in (
		(("M0 -22L18 -8L0 6L-18 -8Z"), 2.6),  # a diamond
		(("M0 6V22M-13 13H13"), 2.8),
		(("M-9 22H9"), 2.8),
	):
		f.path(_at(d, cx, cy, s), stroke=colour, sw=w * s)


def _at(d, cx, cy, s):
	"""Scales and places an absolute-coordinate stroke path (M, L, H, V, Q, Z only)."""
	out, cmd, xs = [], None, []

	def flush():
		nonlocal xs
		if cmd in "ML":
			out.append(f"{cmd}{cx + xs[0] * s:.1f} {cy + xs[1] * s:.1f}")
		elif cmd == "H":
			out.append(f"H{cx + xs[0] * s:.1f}")
		elif cmd == "V":
			out.append(f"V{cy + xs[0] * s:.1f}")
		elif cmd == "Q":
			out.append(f"Q{cx + xs[0] * s:.1f} {cy + xs[1] * s:.1f} {cx + xs[2] * s:.1f} {cy + xs[3] * s:.1f}")
		xs = []

	for tok in re.findall(r"[MLHVQZ]|-?[\d.]+", d):
		if tok in "MLHVQZ":
			if cmd and xs:
				flush()
			if tok == "Z":
				out.append("Z")
				cmd = None
			else:
				cmd = tok
		else:
			xs.append(float(tok))
	if cmd and xs:
		flush()
	return "".join(out)


def _eye(f, cx, cy, sgn):
	"""Sharp black-and-white eye: a tall wedge whose top slopes down to the nose, a big black iris against the lid."""
	i, o = cx - sgn * 17, cx + sgn * 17
	shape = f"M{i} {cy + 3}L{o} {cy - 13}L{o + sgn * 1} {cy + 3}Q{cx + sgn * 6} {cy + 15} {i + sgn * 7} {cy + 13}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 2.5, cy, 8.6, 13), "#060608")
	f.path(circle(cx - sgn * 0.5, cy - 4, 2.4, 3), "#ffffff")
	end_clip(f)
	# the heavy upper lid, thickest at the outer end
	f.path(f"M{i - sgn * 2} {cy + 6}L{o + sgn * 4} {cy - 16}L{o + sgn * 1.5} {cy - 6}L{i - sgn * 2} {cy + 8}Z", "#060608")
	f.path(f"M{i + sgn * 8} {cy + 14.5}Q{cx + sgn * 6} {cy + 16} {o} {cy + 5}", stroke=shade(SKIN, 0.55), sw=1.1)


def _brow(f, cx, cy, sgn):
	"""A thick wedge that plunges to the nose."""
	i, o = cx - sgn * 21, cx + sgn * 22
	f.path(f"M{i} {cy + 11}L{o} {cy - 12}L{o - sgn * 2} {cy - 2}L{i + sgn * 4} {cy + 22}Z", "#060608")


def _face(f):
	face(f, SKIN, hairline=30, nose_y=88)
	f.soft("M30 40H100V100Q65 118 30 100Z", "#ffdcb8", 0.5, 8)
	f.soft("M-5 30H10Q8 90 22 135H-5Z", SKIN_D, 0.5, 5)
	f.soft("M135 30H120Q122 90 108 135H135Z", SKIN_D, 0.6, 5)
	_eye(f, 37, 68, -1)
	_eye(f, 93, 68, 1)
	_brow(f, 37, 42, -1)
	_brow(f, 93, 42, 1)
	# the small smirk, its right corner tucked up
	f.path("M52 103Q66 110 82 100", stroke=LINE, sw=2.2)
	f.path("M82 100Q85 98 85 96", stroke=LINE, sw=1.6)
	f.soft("M58 108Q66 113 76 107V110Q66 117 58 112Z", SKIN_D, 0.5, 2)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	for n in ("Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(GI)
	f = a["Torso_F"]
	f.fill(GI)  # the block's corners can show through the shell's fold dents
	f.path(circle(164, 70, 27), "#fbf8f0")
	glyph_front(f, 164, 70, 0.8)
	a["Torso_Bo"].fill(GI_D)
	f = a["Torso_B"]
	f.fill("#fbf8f0")
	f.path(circle(100, 55, 42), "#fbf8f0", stroke="#c8c0a8", sw=2.0)
	glyph_back(f, 100, 55, 1.42)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill(GI_D)
		a[f"{side}Arm_T"].fill(BLUE)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(GI)
		a[f"{side}Leg_Bo"].fill("#121c70")
	f = a["Head_B"]
	f.fill(HAIRC)
	a["Head_T"].fill(HAIRC)
	for n, d in (("Head_L", "M62 -5H125V135H74L62 60Z"), ("Head_R", "M58 -5H-5V135H46L58 60Z")):
		f = a[n]
		f.fill(SKIN)
		f.path(d, HAIRC)
	a["Head_Bo"].fill(SKIN_D)
