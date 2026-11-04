# Target look kit for this series (design doc section 5): baked-facet solids from the approved pilots plus the school uniform
# the five characters share. Hair and faces stay in each char_<id>.py. bpy is imported lazily: atlas.py runs under python3.
import math
import random

from atlas import FACES, SIZE, swirl_d
from leaf_common import ell
from style2 import Kit  # noqa: F401
from style3 import big_head, finish  # noqa: F401

LIGHT = (-0.35, -0.6, 0.72)
SWIRL_ART = (10, 10, 58, 52)  # px inside Head_T for the button art, always under the hair
NAVY = ["#08090f", "#12151f", "#1e2233", "#2f3549"]
GOLD = ["#8a6210", "#c8962a", "#eec24a", "#fff0a8"]
SOLE = ["#08080c", "#14151c", "#262832", "#3a3c48"]


def bake(o, ramp, k, a=0.5, b=0.42, g=0.08, extra=None, light=LIGHT, tone=0.0):
	"""Triangulates, then one light value per triangle from its normal plus a soft height gradient: hard facets, soft inside."""
	import bmesh
	from mathutils import Vector

	bm = bmesh.new()
	bm.from_mesh(o.data)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(o.data)
	bm.free()
	mesh = o.data
	mesh.update()
	layer = mesh.uv_layers[0] if mesh.uv_layers else mesh.uv_layers.new(name="UVMap")
	L = Vector(light).normalized()
	zs = [v.co.z for v in mesh.vertices]
	lo, hi = min(zs), max(zs)
	rng = random.Random(o.name)
	for poly in mesh.polygons:
		base = a + b * poly.normal.dot(L) + rng.uniform(-tone, tone)
		for li in poly.loop_indices:
			co = mesh.vertices[mesh.loops[li].vertex_index].co
			v = base + g * ((co.z - lo) / max(hi - lo, 1e-6) - 0.5)
			if extra:
				v += extra(co)
			layer.data[li].uv = k.R.uv(ramp, v)
	return o


def jitter(o, amount):
	"""Pushes every vertex a little, seeded by name, so flat sides break into big planes."""
	rng = random.Random(o.name)
	for v in o.data.vertices:
		v.co.x += rng.uniform(-amount, amount)
		v.co.y += rng.uniform(-amount, amount)
		v.co.z += rng.uniform(-amount, amount) * 0.7
	o.data.update()


def block(k, part, name, x, y, z1, z0, hw, hd, ramp, ch=0.07, flare=0.0, corner=0.14, jit=0.0, sub=0, mids=(), **bk):
	"""A chunky chamfered box from z1 down to z0; flare widens the bottom. mids = extra heights, more big planes under jit."""
	rows = [(x, y, z1, hw - ch, hd - ch), (x, y, z1 - ch, hw, hd)]
	rows += [(x, y, m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
	rows += [(x, y, z0 + ch, hw + flare, hd + flare), (x, y, z0, hw + flare - ch, hd + flare - ch)]
	o = k.tube(part, name, rows, ramp, corner=corner, nc=1, sub=sub, outline=0)
	if jit:
		jitter(o, jit)
	return bake(o, ramp, k, **bk)


def prism(k, part, name, pts, y0, y1, ramp, **bk):
	"""A flat closed solid: polygon pts = (x, z) extruded from y0 to y1. Lapels, panels, plates."""
	verts, faces, flat = k._loft([[(x, y0, z) for x, z in pts], [(x, y1, z) for x, z in pts]])
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **bk)


def slab(k, name, pts, x0, x1, ramp, part="Head", **bk):
	"""The same across x: polygon pts = (y, z) extruded from x0 to x1. Hair that hugs the side of the head."""
	verts, faces, flat = k._loft([[(x0, y, z) for y, z in pts], [(x1, y, z) for y, z in pts]])
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **bk)


def gem(k, part, name, b, t, r, ramp="hair", flat=0.8, bend=0.0, twist=0.35, a=0.5, b_=0.62, across=None):
	"""One faceted spike: 6-sided section, wide across, a ridge along it, closed at the root. bend lifts the spine."""
	from mathutils import Vector

	b, t = Vector(b), Vector(t)
	d = (t - b).normalized()
	w = d.cross(Vector((0, 1, 0))) if across is None else Vector(across) - d * d.dot(Vector(across))
	w = w.normalized() if w.length > 0.15 else Vector((1, 0, 0))
	depth = d.cross(w).normalized()
	c = (b + t) / 2 + Vector((0, 0, bend * (t - b).length))
	verts, faces = [], []
	for s, rad, tw in ((0.0, 1.0, 0.0), (0.42, 0.86, twist), (0.75, 0.42, twist * 2)):
		p = b * (1 - s) ** 2 + c * 2 * s * (1 - s) + t * s**2
		for j in range(6):
			ang = math.pi * j / 3 + tw
			verts.append(tuple(p + w * r * rad * math.cos(ang) + depth * r * rad * flat * math.sin(ang)))
	verts.append(tuple(t))
	apex = len(verts) - 1
	for i in range(2):
		for j in range(6):
			j1 = (j + 1) % 6
			faces.append((i * 6 + j, i * 6 + j1, (i + 1) * 6 + j1, (i + 1) * 6 + j))
	for j in range(6):
		faces.append((12 + j, 12 + (j + 1) % 6, apex))
	faces.append(list(range(6)))
	o = k._mesh(name, part, verts, faces, outline=0)
	span = (t - b).length
	return bake(o, ramp, k, a=a, b=b_, g=0.0, extra=lambda co: 0.14 * ((co - b).dot(d) / span - 0.5), light=(-0.72, -0.28, 0.63))


def spray(k, tag, root, tips, ramp="hair", f=0.22, bend=0.06, flat=0.8):
	"""A row of spikes fanning out from one root point: tips = ((x, y, z), radius)."""
	for i, (tip, r) in enumerate(tips):
		gem(k, "Head", f"{tag}{i}", tuple(root[j] + (tip[j] - root[j]) * f for j in range(3)), tip, r, ramp, flat=flat, bend=bend, twist=0.3 + 0.13 * i % 0.5)


def crown(k, rows, ramp="hair", at=(0, 0.04, 0), squash=0.95):
	"""The faceted dome under the spikes. rows = (radius, z)."""
	o = k.lathe("Head", "Crown", [(r, z, 0.5) for r, z in rows], ramp, n=10, at=at, squash=squash, outline=0)
	return bake(o, ramp, k, a=0.48, b=0.34)


def ears(k, ramp="skin", z=4.72):
	for s, n in ((1, "L"), (-1, "R")):
		block(k, "Head", f"Ear{n}", s * 0.93, 0.02, z + 0.18, z - 0.18, 0.06, 0.13, ramp, ch=0.03, a=0.56, b=0.32)


def collar(k, ramp, front, back, z0=3.84, rx=0.9, ry=0.86, part="UpperTorso", name="Collar", n=20, power=1.0, **bk):
	"""A solid standing collar round the neck, its top sloping from front height up to back height."""
	rings = []
	for kind, scale in ((z0, 1.0), (z0 + 0.06, 1.05), (None, 1.04), (None, 0.96)):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, s = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.6, c), math.copysign(abs(s) ** 0.6, s)
			top = front + (back - front) * ((s + 1) / 2) ** power
			ring.append((rx * scale * px, ry * scale * py, kind if kind is not None else (top if scale > 1 else top + 0.03)))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **dict(dict(a=0.5, b=0.5, g=0.1), **bk))


def torso_core(k, hem=2.1):
	k.reshape("UpperTorso", "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, hem, 0.95, 0.45)], corner=0.1, nc=1)


def jacket(k, ramp="navy", hem=1.92, hw=1.06, hd=0.57, seam="sole"):
	"""The closed uniform jacket: a yoke, a body in big planes, a hem band and a dark front seam."""
	t = "UpperTorso"
	torso_core(k)
	block(k, t, "Yoke", 0, 0, 3.98, 3.36, hw + 0.03, hd + 0.02, ramp, ch=0.08, jit=0.02, sub=1, a=0.5, b=0.58)
	block(k, t, "Body", 0, 0, 3.42, hem + 0.1, hw, hd, ramp, ch=0.03, flare=0.02, jit=0.035, mids=(2.9, 2.4), a=0.46, b=0.6, g=0.1, tone=0.05)
	block(k, t, "Hem", 0, 0, hem + 0.16, hem, hw + 0.035, hd + 0.035, ramp, ch=0.03, a=0.42, b=0.56)
	if seam:
		block(k, t, "Seam", 0, -hd - 0.012, 3.98, hem + 0.02, 0.018, 0.018, seam, ch=0.005, a=0.4)


def sleeve(k, side, s, ramp="navy", cuff=2.48, hand="skin"):
	"""Block sleeve over a thin core, one stud wide with a cuff band, and the plain smooth hand under it."""
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Shoulder", ax, 0, 4.03, 3.0, 0.515, 0.515, ramp, ch=0.1, corner=0.18, jit=0.025, sub=1, mids=(3.5,), a=0.5, b=0.6)
	block(k, arm, "Forearm", ax, 0, 3.06, cuff + 0.14, 0.515, 0.515, ramp, ch=0.06, corner=0.18, jit=0.025, sub=1, a=0.5, b=0.6)
	block(k, arm, "Cuff", ax, 0, cuff + 0.2, cuff, 0.53, 0.53, ramp, ch=0.04, corner=0.18, a=0.44, b=0.56)
	block(k, arm, "Hand", ax, 0, cuff + 0.04, 1.78, 0.5, 0.5, hand, ch=0.06, a=0.6, b=0.32)


def trouser(k, side, s, ramp="navy", low=0.42):
	"""A straight slightly baggy trouser leg in big planes, broken over the shoe."""
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.5, 0.56, ramp, ch=0.04, flare=0.02, corner=0.16, jit=0.035, mids=(1.55,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Shin", px, 0, 1.18, low, 0.51, 0.575, ramp, ch=0.04, flare=0.015, corner=0.16, jit=0.035, mids=(0.8,), a=0.46, b=0.6, tone=0.05)
	return leg, px


def dress_shoe(k, leg, px, ramp="shoe", sole="sole", top=0.48):
	block(k, leg, "Shoe", px, -0.04, top, 0.12, 0.49, 0.54, ramp, ch=0.05, a=0.58)
	block(k, leg, "Toe", px, -0.46, 0.34, 0.12, 0.46, 0.26, ramp, ch=0.07, corner=0.3, a=0.64)
	block(k, leg, "Sole", px, -0.12, 0.14, 0.0, 0.52, 0.68, sole, ch=0.03, a=0.52)


def sneaker(k, leg, px, red="red", white="white"):
	"""High-top: coloured upper, white toe cap and sole, laces up the front."""
	block(k, leg, "Upper", px, 0, 0.56, 0.14, 0.515, 0.58, red, ch=0.05, a=0.56, jit=0.012)
	block(k, leg, "Vamp", px, -0.5, 0.34, 0.14, 0.47, 0.24, red, ch=0.06, corner=0.25, a=0.58)
	block(k, leg, "ToeCap", px, -0.62, 0.25, 0.14, 0.44, 0.14, white, ch=0.05, corner=0.3, a=0.66, b=0.3)
	block(k, leg, "Sole", px, -0.12, 0.16, 0.0, 0.525, 0.7, white, ch=0.03, a=0.58, b=0.3)
	block(k, leg, "Heel", px, 0.52, 0.34, 0.14, 0.3, 0.06, white, ch=0.02, a=0.6, b=0.3)
	for i, z in enumerate((0.5, 0.42, 0.34)):
		block(k, leg, f"Lace{i}", px, -0.585 if i < 2 else -0.7, z, z - 0.04, 0.2, 0.014, white, ch=0.006, a=0.72, b=0.2)


def button(k, part, name, cx, y, cz, r=0.11, rim="gold"):
	"""A round button with the swirl art from Head_T on its face. y is its back."""
	n = 12
	rings = [[(cx + rr * math.cos(2 * math.pi * j / n), y + dy, cz + rr * math.sin(2 * math.pi * j / n)) for j in range(n)] for dy, rr in ((0.02, r * 0.9), (-0.03, r), (-0.05, r * 0.9))]
	verts, faces, flat = k._loft(rings)
	o = k._mesh(name, part, verts, faces, flat, outline=0)
	x0, y0 = FACES["Head_T"][:2]
	uv = o.data.uv_layers.new(name="UVMap").data
	bx, by, bw, bh = SWIRL_ART
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			if poly.normal.y < -0.9:
				uv[li].uv = ((x0 + bx + (co.x - cx + r) / (2 * r) * bw) / SIZE, 1 - (y0 + by + (cz + r - co.z) / (2 * r) * bh) / SIZE)
			else:
				uv[li].uv = k.R.uv(rim, 0.3 + 0.4 * max(poly.normal.z, 0))
	return o


# ---- painted helpers


def stroke(f, d, colour, sw, opacity=None):
	"""Any line, vertical ones too: Face.taper draws nothing for those."""
	return f.path(d, stroke=colour, sw=sw, opacity=opacity)


def swirl_art(a, under):
	"""Button art, hidden in Head_T under the hair."""
	f = a["Head_T"]
	f.fill(under)
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	bx, by, bw, bh = SWIRL_ART
	cx, cy, rx, ry = (bx + bw / 2) * sx, (by + bh / 2) * sy, bw / 2 * sx, bh / 2 * sy
	f.path(ell(cx, cy, rx + 1, ry + 1), "#7a5610")
	f.path(ell(cx, cy, rx * 0.92, ry * 0.92), "#e4b442")
	f.path(ell(cx - rx * 0.2, cy - ry * 0.3, rx * 0.5, ry * 0.4), "#fff0a8", opacity=0.55)
	f.out.append(f'<g transform="translate({cx} {cy}) scale({rx / 40} {ry / 40})">')
	f.path(swirl_d(0, 0, 30, turns=2.2, a0=0.5), stroke="#4a2f08", sw=6)
	f.out.append("</g>")


def face_base(f, skin, dark, blush="#f0a080", top=26):
	"""Skin with soft shading under the hair, down the sides of the face and along the jaw."""
	f.skin = skin
	f.fill(skin)
	f.soft(f"M-5-5H135V{top}Q65 {top + 6} -5 {top}Z", dark, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.5, 3)
	f.soft("M14 74Q28 68 36 82Q26 92 14 86Z", blush, 0.3, 3)
	f.soft("M116 74Q102 68 94 82Q104 92 116 86Z", blush, 0.3, 3)


def head_rest(a, side, under, swirl=True):
	"""Sides, back and underside of the head block."""
	for n in ("Head_L", "Head_R"):
		a[n].fill(side)
		a[n].soft("M-5 90H125V135H-5Z", under, 0.6, 3)
	a["Head_B"].fill(side)
	a["Head_Bo"].fill(under)
