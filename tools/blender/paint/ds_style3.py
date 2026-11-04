# Target-look helpers for the ds_ series (design doc section 5): baked solids, faceted hair spikes, a patterned coat over a
# uniform, wrapped legs and sandals. Patterns are painted in stud coordinates into one atlas face and sampled by position,
# so every sleeve, panel and hem shares a single swatch. bpy stays lazy: atlas.py runs this under python3.
import math
import random

from atlas import FACES, SIZE
from leaf_common import begin_clip, ell, end_clip

LIGHT = (-0.35, -0.6, 0.72)
RECT = (-1.2, 1.2, 0.9, 4.3)  # the world rectangle a pattern swatch holds: x0, x1, z0, z1


def xf(o, pivot, rx=0.0, ry=0.0, rz=0.0):
	from mathutils import Euler, Vector

	m = Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix()
	p = Vector(pivot)
	for v in o.data.vertices:
		v.co = p + m @ (v.co - p)
	o.data.update()
	return o


def bake(k, o, ramp, a=0.5, b=0.42, g=0.08, extra=None, light=LIGHT, tone=0.0):
	"""Triangulates, then gives each triangle one light value from its normal plus a soft gradient by height."""
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
	rng = random.Random(o.name)
	for v in o.data.vertices:
		v.co.x += rng.uniform(-amount, amount)
		v.co.y += rng.uniform(-amount, amount)
		v.co.z += rng.uniform(-amount, amount) * 0.7
	o.data.update()


def block(k, part, name, x, y, z1, z0, hw, hd, ramp, ch=0.05, flare=0.0, corner=0.14, jit=0.0, sub=0, mids=(), rot=None, **bk):
	"""A chunky chamfered box from z1 down to z0; flare widens the bottom. rot = (pivot, rx, ry, rz), applied before the bake."""
	rows = [(x, y, z1, hw - ch, hd - ch), (x, y, z1 - ch, hw, hd)]
	rows += [(x, y, m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
	rows += [(x, y, z0 + ch, hw + flare, hd + flare), (x, y, z0, hw + flare - ch, hd + flare - ch)]
	o = k.tube(part, name, rows, ramp, corner=corner, nc=1, sub=sub, outline=0)
	if jit:
		jitter(o, jit)
	if rot:
		xf(o, *rot)
	return bake(k, o, ramp, **bk)


def gem(k, part, name, b, t, r, ramp="hair", tip=None, split=0.7, flat=0.8, bend=0.0, twist=0.35, a=0.5, b_=0.62, across=None):
	"""One faceted spike: 6-sided section with a ridge, closed at the root. tip = a second ramp for facets past split along it (a hard colour change)."""
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
	along = lambda co: (co - b).dot(d) / span
	bake(k, o, ramp, a=a, b=b_, g=0.0, extra=lambda co: 0.14 * (along(co) - 0.5), light=(-0.72, -0.28, 0.63))
	if tip:
		# the outer facets take the tip's ramp, each triangle by its own centre
		layer = o.data.uv_layers[0].data
		L = Vector((-0.72, -0.28, 0.63)).normalized()
		for poly in o.data.polygons:
			if along(poly.center) > split:
				v = a + b_ * poly.normal.dot(L)
				for li in poly.loop_indices:
					layer[li].uv = k.R.uv(tip, v)
	return o


def cap(k, ramp="hair", band_z=5.2, side_z=4.56, back_y=0.0):
	"""Everything under the spikes: the dome, a band all round the top of the head, and a solid block over the head's sides and back."""
	dome = k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.56, 0.5), (0.92, 5.94, 0.5), (0.5, 6.2, 0.5), (0.14, 6.28, 0.5)], ramp, n=10, at=(0, 0.05, 0), squash=0.95, outline=0)
	bake(k, dome, ramp, a=0.46, b=0.34)
	bake(k, k.tube("Head", "HairBand", [(0, 0, 5.64, 0.9, 0.82), (0, 0, 5.56, 0.97, 0.88), (0, 0, band_z, 0.97, 0.88), (0, 0, band_z - 0.04, 0.93, 0.84)], ramp, corner=0.2, nc=1, outline=0), ramp, a=0.46, b=0.36)
	cy = (0.9 + back_y) / 2
	hd = (0.9 - back_y) / 2
	bake(k, k.tube("Head", "HairBack", [(0, cy, 5.3, 0.97, hd), (0, cy, side_z, 0.97, hd), (0, cy, side_z - 0.12, 0.86, hd * 0.86)], ramp, corner=0.2, nc=1, outline=0), ramp, a=0.44, b=0.34)


def spread(root, tip, f=0.22):
	return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))


def art_uv(o, face, rect=RECT, dx=0.0, dz=0.0, facing=None):
	"""Maps a solid onto a painted face by world position: x (or y on its sides) and z inside rect. facing = only polygons whose normal.y is below it."""
	x0, y0, pw, ph = FACES[face][:4]
	a0, a1, z0, z1 = rect
	layer = o.data.uv_layers[0].data
	for poly in o.data.polygons:
		if facing is not None and poly.normal.y > facing:
			continue
		side = abs(poly.normal.x) > max(abs(poly.normal.y), abs(poly.normal.z))
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			u = ((co.y if side else co.x + dx) - a0) / (a1 - a0)
			t = (z1 - co.z - dz) / (z1 - z0)
			u, t = max(0.0, min(1.0, u)), max(0.0, min(1.0, t))
			layer[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + t * (ph - 4)) / SIZE)
	return o


def studs(f, rect=RECT):
	"""Opens a group where paths are in studs, z up, inside rect. Close it with f.out.append('</g>'). No blur inside."""
	a0, a1, z0, z1 = rect
	f.out.append(f'<g transform="scale({f.w / (a1 - a0):.4f} {-f.h / (z1 - z0):.4f}) translate({-a0} {-z1})">')


def rect_d(x0, z0, x1, z1):
	return f"M{x0:.3f} {z0:.3f}L{x1:.3f} {z0:.3f}L{x1:.3f} {z1:.3f}L{x0:.3f} {z1:.3f}Z"


def checks(f, c, a, b, rect=RECT):
	"""A checkerboard of cell c studs, a square meeting b at x 0."""
	studs(f, rect)
	f.path(rect_d(rect[0] - 1, rect[2] - 1, rect[1] + 1, rect[3] + 1), a)
	for i in range(int(rect[0] / c) - 2, int(rect[1] / c) + 2):
		for j in range(int(rect[2] / c) - 2, int(rect[3] / c) + 2):
			if (i + j) % 2:
				f.path(rect_d(i * c, j * c, (i + 1) * c, (j + 1) * c), b)
	f.out.append("</g>")


def stroke(f, pts, w, colour):
	"""A hand stroke of any direction: pts = (x, y), thickest in the middle, pointed at both ends."""
	n = len(pts)
	left, right = [], []
	for i, (x, y) in enumerate(pts):
		ax, ay = pts[max(i - 1, 0)]
		bx, by = pts[min(i + 1, n - 1)]
		dx, dy = bx - ax, by - ay
		dl = math.hypot(dx, dy) or 1
		t = w * math.sin(math.pi * i / (n - 1))
		left.append((x - dy / dl * t, y + dx / dl * t))
		right.append((x + dy / dl * t, y - dx / dl * t))
	f.path("M" + "L".join(f"{x:.1f} {y:.1f}" for x, y in left + right[::-1]) + "Z", colour)


def eye(f, cx, cy, s, iris, w=31, up=13, dn=10, inner=4.5, outer=-4.0, ir=(9.6, 13), pu=(3.0, 4.6), lash="#1a1020", wing=5.0, thick=1.0, white="#fbf7f2", lid=0.3):
	"""One anime eye, narrowed in x because Head_F stretches across the wide head. iris = (rim, mid, glow). s +1 = viewer's right."""
	i, o = cx - s * w / 2, cx + s * w / 2
	iy, oy = cy + inner, cy + outer
	shape = f"M{i} {iy}Q{cx - s * 3} {cy - up - 3} {o} {oy}Q{cx + s * 8} {cy + dn + 2} {i} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, white)
	ix = cx - s * 1
	f.path(ell(ix, cy, ir[0], ir[1]), iris[0])
	f.path(ell(ix, cy, ir[0] * 0.85, ir[1] * 0.88), iris[1])
	f.path(ell(ix, cy + ir[1] * 0.36, ir[0] * 0.62, ir[1] * 0.46), iris[2])
	f.path(ell(ix, cy - 0.5, pu[0], pu[1]), "#0a0810")
	f.path(ell(ix - s * ir[0] * 0.3, cy - ir[1] * 0.3, 2.0, 2.6), "#ffffff")
	f.path(f"M{i} {iy - 8}H{o}V{cy - 3}Q{cx} {cy - 7} {i} {iy}Z", "#20162a", opacity=lid)
	end_clip(f)
	f.path(f"M{i - s} {iy + 0.5}Q{cx - s * 3} {cy - up - 3 - 3 * thick} {o + s * wing} {oy - wing * 0.8}L{o + s * wing * 0.3} {oy + 1}Q{cx - s * 3} {cy - up + 0.8 + 0.6 * (thick - 1)} {i - s} {iy + 0.5}Z", lash)
	stroke(f, [(cx - s * 5, cy + dn + 1.2), (cx + s * 2, cy + dn + 1.6), (cx + s * 9, cy + dn - 0.4), (o, oy + 3)], 0.5, "#8a4f43")


def skin_head(a, skin, shadow):
	for n in ("Head_L", "Head_R"):
		a[n].fill(skin)
		a[n].soft("M-5 90H125V135H-5Z", shadow, 0.5, 3)
	a["Head_Bo"].fill(shadow)
	a["Head_T"].fill(shadow)
	a["Head_B"].fill(skin)


def hand(k, arm, x, ramp="skin"):
	"""Owner: a plain smooth block, the arm's 1 stud width, no fingers."""
	return block(k, arm, "Hand", x, 0, 2.54, 1.78, 0.5, 0.5, ramp, ch=0.06, a=0.6, b=0.32)


def core_leg(k, side, x):
	k.reshape(f"{side}UpperLeg", f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)


def core_arm(k, side, x):
	k.reshape(f"{side}UpperArm", f"{side}Arm", [(x, 0, 3.9, 0.42, 0.42), (x, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)


def sandal(k, leg, px, strap="strap", sock="white"):
	"""A wide flat sole, a covered foot, a V strap from the toe post."""
	block(k, leg, "Sole", px, -0.1, 0.13, 0.0, 0.52, 0.72, "sole", ch=0.03, a=0.56)
	block(k, leg, "Heel", px, 0.1, 0.5, 0.12, 0.47, 0.46, sock, ch=0.06, a=0.56, b=0.36)
	block(k, leg, "Foot", px, -0.32, 0.34, 0.12, 0.46, 0.42, sock, ch=0.06, a=0.56, b=0.36)
	for d in (1, -1):
		block(k, leg, f"Strap{d}", px + d * 0.24, -0.42, 0.41, 0.29, 0.31, 0.06, strap, ch=0.02, rot=((px + d * 0.24, -0.42, 0.35), 0, 0, -d * 38), a=0.62, b=0.3)


def wrapped_leg(k, side, s, hem=0.94, wrap="white", band="wrapline", cuff=0.0):
	"""Wide trousers to hem, a white wrap below with two tie lines, then the sandal's foot. Everything stays under z 2."""
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	core_leg(k, side, x)
	block(k, leg, "Pants", px, 0, 1.98, hem, 0.52, 0.56, "uni", ch=0.04, flare=0.04 + cuff, corner=0.16, jit=0.035, mids=(1.5,), a=0.46, b=0.6, g=0.1, tone=0.05)
	block(k, leg, "Wrap", px, 0, hem + 0.08, 0.42, 0.5, 0.5, wrap, ch=0.04, a=0.58, b=0.36)
	for i, z in enumerate((hem - 0.16, hem - 0.34)):
		block(k, leg, f"Tie{i}", px, 0, z + 0.03, z - 0.03, 0.515, 0.515, band, ch=0.01, a=0.5)


def uniform(k, belt="belt", gold="gold"):
	"""The closed black uniform on the torso: high collar, buttons, a belt. The coat goes over it."""
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.9, 0.42), (0, 0, 2.1, 0.9, 0.42)], corner=0.1, nc=1)
	block(k, t, "Uni", 0, 0, 3.98, 1.94, 1.0, 0.52, "uni", ch=0.04, a=0.46, b=0.56, g=0.12)
	block(k, t, "Collar", 0, 0, 4.2, 3.86, 0.66, 0.6, "uni", ch=0.05, corner=0.3, a=0.48, b=0.6)
	block(k, t, "Belt", 0, 0, 2.36, 2.14, 1.02, 0.55, belt, ch=0.02, a=0.6, b=0.34)
	for i, z in enumerate((3.62, 3.1, 2.62)):
		block(k, t, f"Button{i}", 0, -0.53, z + 0.06, z - 0.06, 0.06, 0.03, gold, ch=0.015, a=0.6)


def coat(k, swatch, hem=1.14, sleeve_dz=0.0, lapel=None, cuff="uni"):
	"""An open coat in one pattern swatch: back and side shell, two front panels, wide sleeves, and per-leg panels below the waist."""
	t = "UpperTorso"
	art_uv(block(k, t, "CoatBody", 0, 0.23, 4.06, 1.94, 1.08, 0.43, "uni", ch=0.05), swatch)
	for s in (1, -1):
		art_uv(block(k, t, f"CoatFront{s}", s * 0.74, -0.42, 4.06, 1.94, 0.34, 0.24, "uni", ch=0.04), swatch)
		if lapel:
			block(k, t, f"Lapel{s}", s * 0.46, -0.66, 4.08, 1.94, 0.08, 0.04, lapel, ch=0.015, a=0.5, b=0.5)
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		art_uv(block(k, leg, "CoatLF", s * 0.74, -0.66, 2.0, hem, 0.34, 0.06, "uni", ch=0.02), swatch)
		art_uv(block(k, leg, "CoatLS", s * 1.12, 0.0, 2.0, hem, 0.06, 0.72, "uni", ch=0.02), swatch)
		art_uv(block(k, leg, "CoatLB", s * 0.56, 0.66, 2.0, hem, 0.62, 0.07, "uni", ch=0.02), swatch)
		if lapel:
			block(k, leg, "LapelL", s * 0.46, -0.7, 2.0, hem, 0.08, 0.04, lapel, ch=0.015, a=0.5, b=0.5)
		arm, ax = f"{side}UpperArm", s * 1.5
		core_arm(k, side, ax)
		art_uv(block(k, arm, "Sleeve", ax, 0, 4.06, 2.6, 0.55, 0.58, "uni", ch=0.06, flare=0.02), swatch, dx=-ax, dz=sleeve_dz)
		block(k, arm, "Cuff", ax, 0, 2.7, 2.46, 0.51, 0.51, cuff, ch=0.03, a=0.46, b=0.5)
		hand(k, arm, ax)


def katana(k, handle, sheath, guard, x=0.92):
	"""A sheathed sword at the viewer's right hip, nearly level, handle forward: fits between torso and arm."""
	t = "UpperTorso"
	p = (x, -0.72, 2.32)
	rx = 60
	block(k, t, "Sheath", x, p[1], p[2], p[2] - 2.1, 0.085, 0.06, sheath, ch=0.02, corner=0.3, rot=(p, rx, 0, 0), a=0.5, b=0.5)
	block(k, t, "Guard", x, p[1], p[2] + 0.03, p[2] - 0.03, 0.15, 0.14, guard, ch=0.02, corner=0.5, rot=(p, rx, 0, 0), a=0.6, b=0.4)
	block(k, t, "Handle", x, p[1], p[2] + 0.6, p[2], 0.08, 0.055, handle, ch=0.015, corner=0.3, rot=(p, rx, 0, 0), a=0.55, b=0.45)
