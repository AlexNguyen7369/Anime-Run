# Shared bits of the target look for this series: faceted blocks, gem spikes, lumps, straps, and the face helpers.
# Each character keeps its own hair, face and garments in its own file. bpy is imported lazily: atlas.py runs under python3.
import math
import random

from atlas import INK, shade
from leaf_common import ell

LIGHT = (-0.35, -0.6, 0.72)
HAIR_LIGHT = (-0.72, -0.28, 0.63)


def bake(k, o, ramp, a=0.5, b=0.42, g=0.08, extra=None, light=LIGHT, tone=0.0):
	"""One light value per triangle from its normal plus a soft height gradient: hard facets, soft inside."""
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
	return bake(k, o, ramp, **bk)


def gem(k, part, name, b, t, r, ramp="hair", flat=0.8, bend=0.0, twist=0.35, a=0.5, b_=0.62, across=None):
	"""One faceted spike: 6-sided section, wide across, closed at the root. bend lifts the spine."""
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
	return bake(k, o, ramp, a=a, b=b_, g=0.0, extra=lambda co: 0.14 * ((co - b).dot(d) / span - 0.5), light=HAIR_LIGHT)


def lump(k, part, name, at, radii, ramp, a=0.5, b=0.55, jit=0.03, n=6, rings=3):
	"""A low-poly rounded clump of hair or padding."""
	o = k.blob(part, name, at, radii, ramp, rings=rings, n=n, outline=0)
	jitter(o, jit)
	return bake(k, o, ramp, a=a, b=b, g=0.06, light=HAIR_LIGHT)


def strip(k, part, name, p0, p1, w, y, d, ramp, **bk):
	"""A straight strap across a front or back: from p0 to p1 = (x, z), half width w, y to y + d. Closed solid."""
	dx, dz = p1[0] - p0[0], p1[1] - p0[1]
	ln = math.hypot(dx, dz)
	nx, nz = -dz / ln * w, dx / ln * w
	quad = [(p0[0] + nx, p0[1] + nz), (p1[0] + nx, p1[1] + nz), (p1[0] - nx, p1[1] - nz), (p0[0] - nx, p0[1] - nz)]
	verts = [(x, y, z) for x, z in quad] + [(x, y + d, z) for x, z in quad]
	faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
	return bake(k, k._mesh(name, part, verts, faces, outline=0), ramp, **bk)


def core(k):
	"""Shrinks the plain body blocks inside the clothes so they never poke through."""
	k.reshape("UpperTorso", "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	for s, side in ((1, "Left"), (-1, "Right")):
		k.reshape(f"{side}UpperArm", f"{side}Arm", [(s * 1.5, 0, 3.9, 0.42, 0.42), (s * 1.5, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
		k.reshape(f"{side}UpperLeg", f"{side}Leg", [(s * 0.5, 0, 2.0, 0.42, 0.42), (s * 0.5, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)


def hand(k, arm, x, ramp="skin", z1=2.54):
	"""Plain smooth block, the arm's width, no fingers."""
	block(k, arm, "Hand", x, 0, z1, 1.78, 0.5, 0.5, ramp, ch=0.06, a=0.6, b=0.32)


# ---- painted faces. Head_F is 130 x 130 units over 1.8 x 1.3 studs, so art is stretched 1.38 in x: draw circles narrow.


def head_faces(a, skin, skin_d, hair):
	"""Skin with soft side, jaw and hairline shading; plain sides and back, all behind the hair."""
	f = a["Head_F"]
	f.skin = skin
	f.fill(skin)
	f.soft("M-5-5H135V24Q65 32 -5 24Z", skin_d, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", skin_d, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", skin_d, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", skin_d, 0.5, 3)
	for n in ("Head_L", "Head_R"):
		a[n].fill(skin_d)
		a[n].soft("M-5 90H125V135H-5Z", shade(skin_d, 0.85), 0.6, 3)
	a["Head_Bo"].fill(shade(skin_d, 0.85))
	a["Head_T"].fill(hair)
	a["Head_B"].fill(skin_d)  # the neck under the nape hair
	return f


def nose(f, skin_d, y=76):
	f.soft(f"M60 {y}L65 {y - 6}L70 {y}Q65 {y + 5} 60 {y}Z", skin_d, 0.75, 1)
	f.path(f"M61 {y + 2}Q65 {y + 4.5} 69 {y + 2}", stroke=shade(skin_d, 0.55), sw=1.1)


def anime_eye(f, cx, cy, s, iris, w=30, up=15, dn=12, lift=6, lash=INK, lt=4.0, wing=4.0, ir=None, pupil=0.45, white="#fffdf8", low=None):
	"""White clipped by the lid shape, ringed iris, pupil, highlight, heavy upper lash with a wing. s +1 = viewer's right."""
	ix, ox = cx - s * w / 2, cx + s * w / 2
	iy, oy = cy + dn * 0.35, cy - lift
	shape = f"M{ix} {iy}Q{cx - s * w * 0.1} {cy - up * 1.5} {ox} {oy}Q{ox + s} {cy + dn * 0.7} {cx + s * w * 0.1} {cy + dn}Q{ix + s * w * 0.18} {cy + dn} {ix} {iy}Z"
	f.path(shape, white)
	f.out.append(f'<clipPath id="eye{s}{f.name}"><path d="{shape}"/></clipPath><g clip-path="url(#eye{s}{f.name})">')
	rx = ir or w * 0.3
	ry = rx * 1.42
	px, py = cx + s * 0.5, cy
	f.path(ell(px, py, rx, ry), shade(iris, 0.4))
	f.path(ell(px, py, rx * 0.86, ry * 0.87), iris)
	f.path(ell(px, py + ry * 0.38, rx * 0.55, ry * 0.45), shade(iris, 1.5))
	f.path(ell(px, py, rx * pupil, ry * pupil), "#080710")
	f.path(ell(px - rx * 0.3, py - ry * 0.34, rx * 0.26, ry * 0.26), "#ffffff")
	f.path(f"M{ix} {iy - 3}Q{cx} {cy - up * 1.5} {ox} {oy}V{cy - up * 0.5}Q{cx} {cy - up * 0.8} {ix} {iy - 3}Z", "#203058", opacity=0.28)
	f.out.append("</g>")
	f.path(f"M{ix - s * 2} {iy + 1.5}Q{cx - s * w * 0.1} {cy - up * 1.5 - lt - 1} {ox + s * wing} {oy - wing}L{ox + s * 0.6} {oy + lt * 0.7}Q{cx - s * w * 0.08} {cy - up * 1.5 + lt * 0.6} {ix - s * 2} {iy + 1.5}Z", lash)
	f.path(f"M{ix + s * w * 0.2} {cy + dn + 0.6}Q{cx + s * w * 0.12} {cy + dn + 2} {ox} {oy + dn * 0.9}", stroke=low or shade(f.skin, 0.42), sw=1.2)


def brow_block(f, s, ib, ob, yi, yo, thick, colour, line=None):
	"""A tapered brow: blunt inner end at x 65 + s*ib, thin outer end at x 65 + s*ob."""
	i, o = 65 + s * ib, 65 + s * ob
	m = 65 + s * (ib + ob) / 2
	ym = (yi + yo) / 2 - 2
	f.path(f"M{i} {yi + thick / 2}L{i + s} {yi - thick / 2}Q{m} {ym - thick / 2} {o} {yo}Q{m} {ym + thick / 2} {i} {yi + thick / 2}Z", colour, stroke=line, sw=0.8)
