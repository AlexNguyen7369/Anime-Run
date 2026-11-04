# Shared faceted solids for this series' target look (design doc section 5): each facet takes one ramp tone from its normal,
# so hard planes read even in flat light. Ramps come from the Kit, so every character brings its own colours.
from collections import Counter
from math import cos, pi, radians, sin

from atlas import FACES, SIZE
from style2 import _chunk_rings

LIGHT = (-0.42, -0.56, 0.71)
HAIR_LIGHT = (-0.25, -0.18, 0.95)  # mostly up, so the planes catch it from the back too


def dot(n, l):
	return n[0] * l[0] + n[1] * l[1] + n[2] * l[2]


def solid(k, part, name, rings, ramp, base=0.5, amp=0.42, grad=0.12, light=LIGHT, vfn=None, curve=None, art=None):
	"""Closed solid lofted through equal-length rings, quads split into triangles so bent rings show planes.
	art = block face name: planar art instead of a ramp."""
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
			uv[li].uv = k.R.uv(ramp, tone + g + (vfn(co) if vfn else 0))
	return o


def rect(z, x0, x1, y0, y1, c=0.07):
	"""A chamfered box section."""
	return [(x1 - c, y0, z), (x1, y0 + c, z), (x1, y1 - c, z), (x1 - c, y1, z), (x0 + c, y1, z), (x0, y1 - c, z), (x0, y0 + c, z), (x0 + c, y0, z)]


def box(k, part, name, rows, ramp, c=0.07, **kw):
	"""rows = (z, x0, x1, y0, y1): a chamfered block."""
	return solid(k, part, name, [rect(*r, c=c) for r in rows], ramp, **kw)


def block(k, part, name, x0, x1, y0, y1, z0, z1, ramp, c=0.05, **kw):
	"""A plain block with chamfers all round."""
	rows = [(z0, x0 + c, x1 - c, y0 + c, y1 - c), (z0 + c, x0, x1, y0, y1), (z1 - c, x0, x1, y0, y1), (z1, x0 + c, x1 - c, y0 + c, y1 - c)]
	return box(k, part, name, rows, ramp, c=c, **kw)


def slab(k, part, name, spine, ramp, thick=0.06, **kw):
	"""A thick strap running down the body: spine = (x0, x1, y, z), rows with their front at y."""
	return solid(k, part, name, [[(x0, y, z), (x1, y, z), (x1, y + thick, z), (x0, y + thick, z)] for x0, x1, y, z in spine], ramp, **kw)


def pipe(k, part, name, pts, ramp, rn=8, **kw):
	"""A faceted tube through pts = (x, y, z, radius)."""
	from mathutils import Vector

	pos = [Vector(p[:3]) for p in pts]
	rings = []
	for i, (p, q) in enumerate(zip(pos, pts)):
		d = (pos[min(i + 1, len(pos) - 1)] - pos[max(i - 1, 0)]).normalized()
		a = d.cross(Vector((0.13, 0.27, 0.95))).normalized()
		b = d.cross(a).normalized()
		rings.append([tuple(p + (a * cos(2 * pi * j / rn) + b * sin(2 * pi * j / rn)) * max(q[3], 0.01)) for j in range(rn)])
	return solid(k, part, name, rings, ramp, **kw)


def dome(k, part, name, c, radii, ramp, up="z", n=12, rows=4, **kw):
	"""A faceted half ellipsoid: radii = (across, across, height), standing on c towards up (z, x, -x or -y)."""
	rings = []
	for i in range(rows + 1):
		ph = (pi / 2) * i / rows
		ring = []
		for j in range(n):
			a = 2 * pi * j / n
			u, v, h = radii[0] * cos(ph) * cos(a), radii[1] * cos(ph) * sin(a), radii[2] * sin(ph)
			if up == "z":
				p = (u, v, h)
			elif up == "-y":
				p = (u, -h, v)
			else:
				p = ((h if up == "x" else -h), u, v)
			ring.append((c[0] + p[0], c[1] + p[1], c[2] + p[2]))
		rings.append(ring)
	return solid(k, part, name, rings, ramp, **kw)


# ---- hair


def hair_curve(d):
	# only planes turned up to the key light take the violet sheen; the rest stays near black
	return max(0.0, d - 0.16) * 2.0


def hair_style(**over):
	return dict(dict(ramp="hair", base=0.14, amp=0.42, grad=0.0, light=HAIR_LIGHT, curve=hair_curve), **over)


def hair_cap(k, rows, style, name="HairCap"):
	"""The skull cap: rows = (front rim z, back rim z, half width, half depth). The rim drops from the hairline to the nape."""
	cap = []
	for z_front, z_back, sw, sd in rows:
		ring = []
		for i in range(10):
			ang = i * 0.6283 + 0.16
			c, s = cos(ang), sin(ang)
			px, py = abs(c) ** 0.6 * (1 if c > 0 else -1), abs(s) ** 0.6 * (1 if s > 0 else -1)
			t = max(0.0, min(1.0, (py + 0.7) / 1.0))
			ring.append((sw * px, sd * py, z_front + (z_back - z_front) * t))
		cap.append(ring)
	return solid(k, "Head", name, cap, **style)


def spikes(k, chunks, style, tag="Spike", part="Head", rn=5, sn=5):
	for i, ch in enumerate(chunks):
		rings, _ = _chunk_rings(ch, rn, sn)
		solid(k, part, f"{tag}{i}", rings, **style)


# ---- the body


def shell(k, name, table, ramp, base=0.36, amp=0.46, **kw):
	"""A torso shell: table = (z, half width, half depth, y offsets of the front at 5 points across)."""
	rings = []
	for z, hw, hd, ys in table:
		xs = [q * (hw - 0.12) / 0.92 for q in (-0.92, -0.46, 0, 0.46, 0.92)]
		ring = [(x, -hd + y, z) for x, y in zip(xs, ys)]
		ring += [(hw, -hd + 0.12, z), (hw, hd - 0.12, z), (hw - 0.12, hd, z), (hw * 0.45, hd + 0.015, z), (0, hd, z), (-hw * 0.45, hd + 0.015, z), (-hw + 0.12, hd, z), (-hw, hd - 0.12, z), (-hw, -hd + 0.12, z)]
		rings.append(ring)
	return solid(k, "UpperTorso", name, rings, ramp, base=base, amp=amp, **kw)


def lapels(k, ramp, bottom=(3.08, 3.0), top=4.04, neck=0.56, wid=0.34, **kw):
	"""The crossover: viewer's left lapel over the right one, each a raised plane."""
	for tag, s, zbot, over, yy in (("R", 1, bottom[0], 0.08, -0.72), ("L", -1, bottom[1], 0.18, -0.76)):
		rows = []
		for t, w, dy in ((0, wid, 0), (0.45, wid + 0.02, -0.02), (1, wid - 0.04, 0.01)):
			xin = s * (neck + (-over - neck) * t)
			rows.append((min(xin, xin + s * w), max(xin, xin + s * w), yy + dy, top + (zbot - top) * t))
		slab(k, "UpperTorso", "Lapel" + tag, rows, ramp, thick=0.2, **dict(dict(base=0.46, amp=0.34), **kw))


def wedge(k, ramp, top=4.03, tip=3.3, half=0.56, y=-0.66, **kw):
	"""The V at the neck, a chunky wedge just under the lapels."""
	rows = [(-half, half, y, top), (-half * 0.6, half * 0.6, y + 0.02, top - (top - tip) * 0.4), (-0.015, 0.015, y + 0.02, tip)]
	slab(k, "UpperTorso", "Wedge", rows, ramp, thick=0.16, **dict(dict(base=0.42, amp=0.26), **kw))


def sash(k, ramp, kx, tails, z0=2.64, z1=2.9):
	"""Belt, a chunky knot at x = kx, and tails = (x0, x1, half width top, half width end, end z, y). Past the hip they hand
	over to the leg on the knot's side, so they swing with it."""
	kw = dict(base=0.42, amp=0.36)
	block(k, "UpperTorso", "Sash", -1.08, 1.08, -0.63, 0.63, z0, z1, ramp, c=0.04, grad=0.2, **kw)
	for tag, s in (("L", -1), ("R", 1)):
		rows = [(z1 + 0.08, kx + s * 0.14, kx + s * 0.36, -0.73, -0.6), (z1 - 0.1, kx + s * 0.14, kx + s * 0.56, -0.76, -0.6), (z0 - 0.06, kx + s * 0.14, kx + s * 0.44, -0.72, -0.6)]
		box(k, "UpperTorso", "KnotLoop" + tag, [(z, min(a, b), max(a, b), y0, y1) for z, a, b, y0, y1 in rows], ramp, c=0.04, **kw)
	block(k, "UpperTorso", "Knot", kx - 0.18, kx + 0.18, -0.82, -0.58, z0 - 0.1, z1 + 0.06, ramp, c=0.05, base=0.5, amp=0.4)
	leg = "LeftUpperLeg" if kx > 0 else "RightUpperLeg"
	for i, (x0, x1, w0, w1, zend, y) in enumerate(tails):

		def row(z, dy):
			t = (z0 - 0.04 - z) / (z0 - 0.04 - zend)
			cx, w = x0 + (x1 - x0) * t, w0 + (w1 - w0) * t
			return (cx - w, cx + w, y + dy, z)

		slab(k, "UpperTorso", f"TailTop{i}", [row(z0 - 0.04, 0), row(2.3, -0.02), row(1.98, -0.06)], ramp, thick=0.07, **kw)
		t = slab(k, leg, f"Tail{i}", [row(2.0, -0.06), row((2 + zend) / 2, -0.12), row(zend, -0.14)], ramp, thick=0.07, **kw)
		for vt in t.data.vertices:
			if vt.co.z < zend + 0.01:
				vt.co.z += (vt.co.x - x1) * 0.3


# The trouser bag, +x leg: z, inner x, outer x, half depth, then 10 radial pushes.
_BAG = [
	(2.0, 0.03, 1.02, 0.6, (0,) * 10),
	(1.8, 0.1, 1.18, 0.7, (0, 0, 0, 0, 0, 0, -0.03, 0.04, -0.04, 0.03)),
	(1.56, 0.18, 1.3, 0.78, (0.03, 0, -0.02, 0, 0.02, 0, 0.05, -0.05, 0.05, -0.05)),
	(1.32, 0.24, 1.36, 0.8, (-0.03, 0.02, 0, 0.02, 0, 0.02, -0.05, 0.05, -0.04, 0.05)),
	(1.14, 0.26, 1.3, 0.76, (0.02, 0, 0, 0, 0, 0, 0.03, -0.03, 0.03, -0.02)),
	(1.02, 0.28, 1.14, 0.62, (0,) * 10),
	(0.96, 0.3, 0.98, 0.52, (0,) * 10),
]
# Fold plates, +x leg: rows of (inner x, outer x, depth, z) and a tone: lit thigh, dark diagonal, lit lower bulge.
_FOLDS = [
	(((0.3, 1.0, 0.72, 1.92), (0.36, 1.1, 0.8, 1.62), (0.76, 1.16, 0.82, 1.4)), 0.66),
	(((0.98, 1.2, 0.8, 1.52), (0.46, 1.22, 0.84, 1.28), (0.44, 0.92, 0.8, 1.12)), 0.12),
	(((0.28, 0.5, 0.84, 1.24), (0.3, 0.72, 0.83, 1.1), (0.46, 0.72, 0.68, 1.01)), 0.6),
]


def bag(k, part, s, ramp, z0=0.96, w=1.0, d=1.0):
	"""Baggy trousers from the hip to z0. w and d scale how far the bag swells out and forward."""
	zmap = lambda z: z0 + (z - 0.96) * (2.0 - z0) / 1.04
	xmap = lambda x: x if x < 0.98 else 0.98 + (x - 0.98) * w
	rings = []
	for z, x0, x1, hd, push in _BAG:
		cx, hw = (x0 + xmap(x1)) / 2, (xmap(x1) - x0) / 2
		ring = []
		for i in range(10):
			a = radians(i * 36 + 9)
			c, dd = cos(a), sin(a)
			px, py = abs(c) ** 0.55 * (1 if c > 0 else -1), abs(dd) ** 0.55 * (1 if dd > 0 else -1)
			m = 1 + push[i]
			ring.append((s * (cx + hw * px * m), hd * d * py * m, zmap(z)))
		rings.append(ring)
	solid(k, part, "Bag", rings, ramp, base=0.33, amp=0.56, grad=0.1, vfn=lambda co: -0.32 * max(0.0, (zmap(1.3) - co.z) / 0.3))
	for i, (rows, base) in enumerate(_FOLDS):
		for tag, side in (("F", -1), ("B", 1)):
			r = [(min(s * a, s * xmap(b)), max(s * a, s * xmap(b)), side * dep * d, zmap(z)) for a, b, dep, z in rows]
			slab(k, part, f"Fold{tag}{i}", r, ramp, thick=-side * 0.14, base=base - (0.06 if side > 0 else 0), amp=0.2, grad=0.1)


def thin_leg(k, part, block_name, s):
	"""The leg block stays inside the bag; narrowed so the real gap between the feet shows."""
	k.reshape(part, block_name, [(s * 0.62, 0, 2.0, 0.36, 0.36), (s * 0.62, 0, 0.0, 0.36, 0.36)], corner=0.12, nc=1)


def arm_bands(k, part, ax, segs):
	"""The arm as stacked chunky blocks: segs = (name, z top, z bottom, half width, ramp)."""
	for name, z1, z0, w, ramp in segs:
		block(k, part, name, ax - w, ax + w, -w, w, z0, z1, ramp, c=0.06, base=0.44, amp=0.36, grad=0.12)
