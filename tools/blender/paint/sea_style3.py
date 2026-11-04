# Shared hand-built pieces for the target look of this series (design doc section 5): baked-facet blocks, spikes, flat
# prisms, rods and decals on the style3 kit, plus the anime eye. +X is the viewer's right and the character's left.
import math
import random

from atlas import FACES, INK, SIZE, shade
from leaf_common import ell

LIGHT = (-0.35, -0.6, 0.72)


def bake(k, o, ramp, a=0.5, b=0.42, g=0.08, extra=None, light=LIGHT, tone=0.0):
	"""Triangulates, then one light value per triangle from its normal: hard facets, a soft gradient by height."""
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


def block(k, part, name, x, y, z1, z0, hw, hd, ramp, ch=0.05, flare=0.0, corner=0.14, jit=0.0, sub=0, shear=0.0, mids=(), **bk):
	"""A chunky chamfered box from z1 down to z0; flare widens the bottom."""
	rows = [(x, y, z1, hw - ch, hd - ch), (x, y, z1 - ch, hw, hd)]
	rows += [(x, y, m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
	rows += [(x, y, z0 + ch, hw + flare, hd + flare), (x, y, z0, hw + flare - ch, hd + flare - ch)]
	o = k.tube(part, name, rows, ramp, corner=corner, nc=1, sub=sub, outline=0)
	if jit:
		jitter(o, jit)
	if shear:
		for v in o.data.vertices:
			v.co.z += shear * (v.co.x - x)
		o.data.update()
	return bake(k, o, ramp, **bk)


def gem(k, part, name, b, t, r, ramp="hair", flat=0.8, bend=0.0, twist=0.35, a=0.5, b_=0.62, across=None):
	"""One faceted hair clump: 6-sided section, wide at the root, closed at both ends. bend lifts the spine."""
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
	return bake(k, o, ramp, a=a, b=b_, g=0.0, extra=lambda co: 0.14 * ((co - b).dot(d) / span - 0.5), light=(-0.72, -0.28, 0.63))


def prism(k, part, name, pts, y0, y1, ramp, **bk):
	"""A flat solid: polygon pts (x, z) in the front plane, from y0 (front) back to y1."""
	n = len(pts)
	verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
	faces = [(j, (j + 1) % n, n + (j + 1) % n, n + j) for j in range(n)] + [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
	return bake(k, k._mesh(name, part, verts, faces, outline=0), ramp, **bk)


def mirror(pts):
	return [(-x, z) for x, z in pts][::-1]


def rod(k, part, name, p0, p1, r, ramp, n=6, r1=None, **bk):
	"""A faceted cylinder from p0 to p1, closed; r1 tapers the far end."""
	from mathutils import Vector

	a, b = Vector(p0), Vector(p1)
	d = (b - a).normalized()
	u = d.cross(Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).normalized()
	w = d.cross(u)
	rings = []
	for c, rad in ((a, r), (b, r if r1 is None else r1)):
		rings.append([tuple(c + u * rad * math.cos(2 * math.pi * j / n) + w * rad * math.sin(2 * math.pi * j / n)) for j in range(n)])
	verts, faces, flat = k._loft(rings)
	return bake(k, k._mesh(name, part, verts, faces, flat, outline=0), ramp, **bk)


def decal(k, part, name, c, r, art_face, rect, rim, n=16, depth=0.05):
	"""A round disc facing the viewer, its front showing rect (px x, y, w, h) inside atlas face art_face."""
	cx, cy, cz = c
	rings = [[(cx + q * r * math.cos(2 * math.pi * j / n), cy + y, cz + q * r * math.sin(2 * math.pi * j / n)) for j in range(n)] for y, q in ((depth, 0.92), (0.0, 1.0), (-0.02, 0.92))]
	verts, faces, flat = k._loft(rings)
	o = k._mesh(name, part, verts, faces, flat, outline=0)
	x0, y0 = FACES[art_face][:2]
	bx, by, bw, bh = rect
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			if poly.normal.y < -0.9:
				uv[li].uv = ((x0 + bx + (co.x - cx + r) / (2 * r) * bw) / SIZE, 1 - (y0 + by + (cz + r - co.z) / (2 * r) * bh) / SIZE)
			else:
				uv[li].uv = k.R.uv(rim, 0.5 + 0.35 * poly.normal.z)
	return o


def hand(k, arm, x):
	"""Owner: hands stay one smooth chamfered block, the arm's full width, no fingers."""
	block(k, arm, "Hand", x, 0, 2.54, 1.8, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)


def core(k):
	"""Shrinks the torso, arm and leg blocks inside garments that cover them."""
	k.reshape("UpperTorso", "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	for side, s in (("Left", 1), ("Right", -1)):
		k.reshape(f"{side}UpperArm", f"{side}Arm", [(s * 1.5, 0, 3.9, 0.42, 0.42), (s * 1.5, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
		leg(k, side, s)


def leg(k, side, s):
	k.reshape(f"{side}UpperLeg", f"{side}Leg", [(s * 0.5, 0, 1.98, 0.42, 0.42), (s * 0.5, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)


def bare_arm(k, side, s):
	"""A true 1-stud arm wearing its own painted faces, hand included."""
	ax = s * 1.5
	rows = [(ax, 0, 4.03, 0.42, 0.42), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 1.87, 0.5, 0.5), (ax, 0, 1.8, 0.43, 0.43)]
	k.reshape(f"{side}UpperArm", f"{side}Arm", rows, corner=0.14, nc=1)


def paint_arm(f, skin, skin_d, skin_l, dark=0.0):
	"""Bare skin, soft falloff at the edges and the hand."""
	f.fill(skin)
	f.soft("M18 14H82L78 96H22Z", skin_l, 0.55, 8)
	f.soft("M-5-5H10L12 210H-5Z", skin_d, 0.45, 5)
	f.soft("M105-5H88L84 210H105Z", skin_d, 0.7, 5)
	f.soft("M-5 160H105V210H-5Z", skin_d, 0.4, 8)
	if dark:
		f.path("M-5-5H105V210H-5Z", skin_d, opacity=dark)


def eye(f, cx, cy, s, iris, deep, glow, w=31, up=24, down=13, inner=5, outer=-8, wing=4.5, lid=6.0, look=0.5, lash=INK, ry=13.5):
	"""A big anime eye, narrowed in x because Head_F stretches across the wide head. s +1 is the eye on the viewer's right."""
	ix, ox = cx - s * w / 2, cx + s * w / 2
	iy, oy = cy + inner, cy + outer
	shape = f"M{ix} {iy}Q{cx - s * 3} {cy - up} {ox} {oy}Q{ox + s} {cy + down * 0.7} {cx + s * 3} {cy + down}Q{ix + s * 5} {cy + down} {ix} {iy}Z"
	f.path(shape, "#fffdf8")
	f.out.append(f'<clipPath id="eye{s}"><path d="{shape}"/></clipPath><g clip-path="url(#eye{s})">')
	px, py = cx + s * look, cy - 0.5
	f.path(ell(px, py, ry * 0.7, ry), deep)
	f.path(ell(px, py, ry * 0.6, ry * 0.87), iris)
	f.path(ell(px, py + ry * 0.37, ry * 0.37, ry * 0.44), glow)
	f.path(ell(px, py, ry * 0.28, ry * 0.41), "#080710")
	f.path(ell(px - 2.6, py - ry * 0.33, 2.3, 3.2), "#ffffff")
	f.path(f"M{ix} {iy - 3}Q{cx} {cy - up} {ox} {oy}V{cy - 7}Q{cx} {cy - up * 0.54} {ix} {iy - 3}Z", "#203058", opacity=0.3)
	f.out.append("</g>")
	f.path(f"M{ix - s * 2} {iy + 1.5}Q{cx - s * 3} {cy - up - lid + 1} {ox + s * wing} {oy - wing - 1}L{ox + s * 0.6} {oy + 3}Q{cx - s * 2} {cy - up + lid} {ix - s * 2} {iy + 1.5}Z", lash)
	f.path(f"M{ix + s * 6} {cy + down + 0.6}Q{cx + s * 4} {cy + down + 2} {ox} {oy + 10}", stroke=shade(f.skin, 0.42), sw=1.2)


def head_base(f, skin, dark, light=None, hair_shadow=33):
	"""Skin, a soft shadow under the hair, shaded face sides and jaw."""
	f.skin = skin
	f.fill(skin)
	if light:
		f.soft("M-5 30H135V116Q65 92 -5 116Z", light, 0.4, 8)
	f.soft(f"M-5-5H135V{hair_shadow}Q65 {hair_shadow + 6} -5 {hair_shadow}Z", shade(skin, 0.68), 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.5, 3)


def head_sides(a, skin, dark, hair=None, hair_y=44):
	"""Head_L and Head_R: cheek at the front, darker towards the back; an optional band of hair colour above."""
	for n, back in (("Head_L", 1), ("Head_R", -1)):
		f = a[n]
		f.fill(skin)
		xb = 120 if back > 0 else 0
		f.soft(f"M{xb - back * 70} -5H{xb + back * 5}V135H{xb - back * 70}Z", dark, 0.55, 8)
		f.soft("M-5 118H125V135H-5Z", dark, 0.6, 3)
		if hair:
			f.path(f"M-5-5H125V{hair_y}H-5Z", hair)
	a["Head_Bo"].fill(dark)
