# Shared parts of the target look for the leaf series: baked facets, spikes, locks, the steel plate, open-toe footwear.
# bpy, bmesh and mathutils are imported lazily: atlas.py runs under plain python3.
import math
import random

from atlas import FACES, INK, SIZE, shade, swirl_d
from leaf_common import begin_clip, ell, end_clip

LIGHT = (-0.35, -0.6, 0.72)
HAIR_LIGHT = (-0.72, -0.28, 0.63)
PLATE_T = 66  # art units of Head_B the plate takes; the rest stays hidden behind the nape
BADGE = (10, 10, 58, 52)  # px inside Head_T for small round art, under the hair


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
	"""Pushes every vertex a little, seeded by name, so flat sides break into big planes."""
	rng = random.Random(o.name)
	for v in o.data.vertices:
		v.co.x += rng.uniform(-amount, amount)
		v.co.y += rng.uniform(-amount, amount)
		v.co.z += rng.uniform(-amount, amount) * 0.7
	o.data.update()


def block(k, part, name, x, y, z1, z0, hw, hd, ramp, ch=0.07, flare=0.0, corner=0.14, jit=0.0, sub=0, mids=(), **bk):
	"""A chunky chamfered box from z1 down to z0; flare widens the bottom; mids add heights, more planes under jit."""
	rows = [(x, y, z1, hw - ch, hd - ch), (x, y, z1 - ch, hw, hd)]
	rows += [(x, y, m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
	rows += [(x, y, z0 + ch, hw + flare, hd + flare), (x, y, z0, hw + flare - ch, hd + flare - ch)]
	o = k.tube(part, name, rows, ramp, corner=corner, nc=1, sub=sub, outline=0)
	if jit:
		jitter(o, jit)
	return bake(k, o, ramp, **bk)


def xf(o, pivot, rx=0.0, ry=0.0, rz=0.0):
	"""Rotates a built mesh in place. ry > 0 lowers its +X end."""
	from mathutils import Euler, Vector

	m = Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix()
	p = Vector(pivot)
	for v in o.data.vertices:
		v.co = p + m @ (v.co - p)
	o.data.update()
	return o


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


SECTION = ((-1, -0.15), (-0.12, 1), (1, -0.15), (0.35, -0.7), (-0.35, -0.7))


def shard(k, name, pts, ramp="hair", part="Head", flat=0.62, a=0.46, b_=0.5, centre=(0, 0.1, 5.0)):
	"""One large angular lock, a closed solid with a ridge. pts = (x, y, z, half width), root to tip; ridge faces away from centre."""
	rings = []
	for i, p in enumerate(pts):
		s, e = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
		d = [e[j] - s[j] for j in range(3)]
		dl = math.sqrt(sum(c * c for c in d))
		d = [c / dl for c in d]
		out = [p[j] - centre[j] for j in range(3)]
		along = sum(out[j] * d[j] for j in range(3))
		out = [out[j] - along * d[j] for j in range(3)]
		ol = math.sqrt(sum(c * c for c in out)) or 1
		out = [c / ol for c in out]
		w = (d[1] * out[2] - d[2] * out[1], d[2] * out[0] - d[0] * out[2], d[0] * out[1] - d[1] * out[0])
		rings.append([tuple(p[j] + w[j] * p[3] * u + out[j] * p[3] * flat * h for j in range(3)) for u, h in SECTION])
	verts, faces, _ = k._loft(rings)
	return bake(k, k._mesh(name, part, verts, faces, (), 0), ramp, a=a, b=b_, g=0.0, light=HAIR_LIGHT)


def true_face_uv(head):
	"""The face art at its true place on the front, so a narrow jaw crops it instead of shearing it."""
	x0, y0, pw, ph = FACES["Head_F"][:4]
	mesh = head.data
	layer = mesh.uv_layers["UVMap"].data
	for poly in mesh.polygons:
		n = poly.normal
		if n.y < 0 and abs(n.y) >= abs(n.x) and abs(n.y) >= abs(n.z):
			for li in poly.loop_indices:
				co = mesh.vertices[mesh.loops[li].vertex_index].co
				u = max(0.0, min(1.0, (co.x + 0.9) / 1.8))
				t = max(0.0, min(1.0, (0.65 - co.z) / 1.3))  # the mesh is local to the head's centre, z 4.65
				layer[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + t * (ph - 4)) / SIZE)


def plate(k, hw=0.52, top=5.445, bot=5.045, y0=-0.915):
	"""The forehead plate, a shallow curve with a real bevel. Its art lives in Head_B, hidden behind the nape."""
	xs = (-1, -0.95, -0.7, -0.35, 0, 0.35, 0.7, 0.95, 1)
	rings, zs = [], (top, top - 0.04, bot + 0.04, bot)
	for x in xs:
		y = y0 + 0.035 * x * x
		lift = 0.0 if abs(x) == 1 else 0.035
		section = ((y + 0.1, zs[0]), (y, zs[0]), (y - lift, zs[1]), (y - lift, zs[2]), (y, zs[3]), (y + 0.1, zs[3]))
		rings.append([(x * hw, sy, sz) for sy, sz in section])
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Plate", "Head", verts, faces, flat, outline=0)
	x0, y0_, pw, ph = FACES["Head_B"][:4]
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			u = (co.x + hw) / (2 * hw)
			t = (top - co.z) / (top - bot)
			uv[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0_ + 1 + t * PLATE_T * ph / 130) / SIZE)
	return o


def mark(f, cx, cy, r, colour):
	"""The swirl of the plate, its tail running off along the bottom to a small triangle at lower left."""
	f.path(swirl_d(cx, cy, r, turns=2.1, a0=math.pi / 2 - 0.6), stroke=colour, sw=r * 0.24)
	f.path(f"M{cx + r * 0.1} {cy + r}L{cx - r * 1.1} {cy + r * 1.02}L{cx - r * 1.82} {cy + r * 1.02}L{cx - r * 1.12} {cy + r * 0.1}L{cx - r * 0.72} {cy + r * 0.7}", stroke=colour, sw=r * 0.24)


def paint_plate(f, skin, slash=False):
	"""Drawn in plate units, 130 x 48, then stretched down Head_B's top."""
	f.fill(skin)
	f.out.append(f'<g transform="scale(1 {PLATE_T / 48:.4f})">')
	f.path("M0 0H130V48H0Z", "#b0b6c0")
	f.soft("M0 0H130V18Q60 26 0 20Z", "#e4e8ee", 0.85, 2)
	f.soft("M92 2H128V46H104Q88 26 92 2Z", "#6f7682", 0.7, 3)
	f.path("M30 3L46 3L36 45L22 45Z", "#f6f8fa", opacity=0.7)
	f.path("M0 38H130V48H0Z", "#737a86", opacity=0.6)
	f.path("M0 0H130L125 3H5L5 45L0 48Z", "#eef1f5")
	f.path("M130 0V48H0L5 45H125V3Z", "#5a616c")
	for x in (11, 119):
		for y in (10, 38):
			f.path(ell(x, y, 3.2, 3.4), "#3c424c")
			f.path(ell(x - 0.7, y - 0.8, 2.3, 2.4), "#c8cdd4")
			f.path(ell(x - 1.1, y - 1.2, 0.9, 1), "#ffffff")
	mark(f, 70, 23, 13, "#23262e")
	if slash:
		# one deep horizontal scratch, with a lit lower lip
		f.path("M14 25L120 21L120 25L14 29Z", "#0e0f13")
		f.path("M14 29.4L120 25.4", stroke="#f4f6f8", sw=1.4)
	f.out.append("</g>")


def back_panel(k, part, top, bot, hw, y, ramp, thick=0.08, **bk):
	"""A garment's back wearing Torso_B at 1:1 scale; every other side stays the ramp."""
	o = k.tube(part, "BackPanel", [(0, y, top, hw - 0.03, thick - 0.02), (0, y, top - 0.03, hw, thick), (0, y, bot + 0.03, hw, thick), (0, y, bot, hw - 0.03, thick - 0.02)], ramp, corner=0.3, nc=1, outline=0)
	bake(k, o, ramp, **bk)
	x0, y0, pw, ph = FACES["Torso_B"][:4]
	layer = o.data.uv_layers[0].data
	for poly in o.data.polygons:
		if poly.normal.y > 0.9:
			for li in poly.loop_indices:
				co = o.data.vertices[o.data.loops[li].vertex_index].co
				u, t = (hw - co.x) / (2 * hw), (top - co.z) / (2 * hw)
				layer[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + t * (ph - 4)) / SIZE)
	return o


def rope(k, part, name, z, hw, hd, r, ramp, y=0.0, n=44, **bk):
	"""A twisted rope round the waist: a tube whose radius alternates, so the facets catch the light in turns."""
	rings = []
	for i in range(n):
		a = 2 * math.pi * i / n
		c, s = math.cos(a), math.sin(a)
		px, py = hw * math.copysign(abs(c) ** 0.45, c), hd * math.copysign(abs(s) ** 0.45, s)
		rr = r * (1.0 if i % 2 else 0.86)
		dz = 0.006 * (1 if i % 2 else -1)
		l = math.hypot(c, s) or 1
		rings.append([(px + c / l * rr * math.cos(t), y + py + s / l * rr * math.cos(t), z + dz + rr * math.sin(t)) for t in (2 * math.pi * j / 5 for j in range(5))])
	verts = [p for ring in rings for p in ring]
	faces = [(i * 5 + j, i * 5 + (j + 1) % 5, (i + 1) % n * 5 + (j + 1) % 5, (i + 1) % n * 5 + j) for i in range(n) for j in range(5)]
	return bake(k, k._mesh(name, part, verts, faces, (), 0), ramp, **bk)


def cloud_shape(c, u, up, normal, rx, rz, depth):
	"""Rings of a lobed cloud solid. u and up span the surface it sits on, normal points out of it."""
	# cusps between lobes; flatter and wider along the bottom
	cusps = (28, 92, 148, 214, 292)
	pts = []
	for i, a0 in enumerate(cusps):
		a1 = cusps[(i + 1) % len(cusps)] + (360 if i == len(cusps) - 1 else 0)
		for s in range(5):
			t = s / 5
			ang = math.radians(a0 + (a1 - a0) * t)
			bump = 0.78 + 0.3 * math.sin(math.pi * t) ** 0.7
			sin = math.sin(ang)
			pts.append((rx * bump * math.cos(ang), rz * bump * (sin if sin > 0 else sin * 0.72)))
	front = [tuple(c[j] + u[j] * x + up[j] * z + normal[j] * depth for j in range(3)) for x, z in pts]
	back = [tuple(c[j] + u[j] * x + up[j] * z - normal[j] * 0.04 for j in range(3)) for x, z in pts]
	return [back, front]


def cloud(k, part, name, c, rx=0.42, facing="front", red="red", white="white"):
	"""The cloak's emblem as real geometry: a white lobed solid, a red one on it, so both stay crisp at any size."""
	u, n = {"front": ((1, 0, 0), (0, -1, 0)), "back": ((-1, 0, 0), (0, 1, 0)), "left": ((0, -1, 0), (1, 0, 0)), "right": ((0, 1, 0), (-1, 0, 0))}[facing]
	for tag, ramp, scale, depth, a in (("W", white, 1.0, 0.012, 0.85), ("R", red, 0.8, 0.024, 0.62)):
		rings = cloud_shape(c, u, (0, 0, 1), n, rx * scale, rx * 0.72 * scale, depth)
		verts, faces, flat = k._loft(rings)
		bake(k, k._mesh(name + tag, part, verts, faces, flat, 0), ramp, a=a, b=0.2, g=0.0)


def sandal(k, part, px, ramp, sole, skin="skin", top=0.62):
	"""The series' open-toe footwear: heel shaft to `top`, strap over the instep, chunky sole, a skin forefoot and four toes."""
	s = 1 if px > 0 else -1
	block(k, part, "BootLow", px, 0.1, top, 0.14, 0.52, 0.5, ramp, ch=0.05, flare=0.015, a=0.54)
	block(k, part, "Instep", px, -0.44, min(top, 0.54), 0.26, 0.5, 0.12, ramp, ch=0.04, a=0.58)
	block(k, part, "Sole", px, -0.14, 0.17, 0.0, 0.545, 0.78, sole, ch=0.03, a=0.56)
	block(k, part, "Forefoot", px, -0.64, 0.36, 0.14, 0.47, 0.13, skin, ch=0.035, a=0.56, b=0.34)
	for i, dx in enumerate((-0.345, -0.115, 0.115, 0.345)):
		block(k, part, f"Toe{i}", px + dx, -0.78, 0.31 - 0.012 * abs(i - 1.5 + s * 1.5), 0.15, 0.105, 0.11, skin, ch=0.03, corner=0.25, a=0.58, b=0.34)


def hand(k, arm, x, ramp="skin", z1=2.54, **bk):
	"""Owner: hands stay one smooth chamfered block, the arm's 1 stud width, no fingers."""
	bk = {"a": 0.6, "b": 0.32, **bk}
	block(k, arm, "Hand", x, 0, z1, 1.78, 0.5, 0.5, ramp, ch=0.06, **bk)


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


def dark_eye(f, cx, cy, s, w=30, up=11, dn=8, tilt=7, iris=9.5, pupil="#07070c", ring="#17171f", mid="#33323e", glow="#5a5868", lid=0.3, heavy=0.0):
	"""A narrow dark anime eye. s +1 = viewer's right. tilt lifts the outer corner; heavy lowers the upper lid across the iris."""
	ix, ox = cx - s * w / 2, cx + s * w / 2
	iy, oy = cy + 4, cy - tilt
	shape = f"M{ix} {iy}Q{cx - s * 3} {cy - up - 8 + heavy} {ox} {oy}Q{cx + s * 7} {cy + dn + 3} {ix} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, "#fbf7f2")
	px, py = cx - s * 0.5, cy - 0.5
	f.path(ell(px, py, iris, iris * 1.34), ring)
	f.path(ell(px, py, iris * 0.8, iris * 1.1), mid)
	f.path(ell(px, py + iris * 0.55, iris * 0.55, iris * 0.5), glow)
	f.path(ell(px, py, iris * 0.42, iris * 0.6), pupil)
	f.path(ell(px - 2.6, py - 3.6, 2.0, 2.6), "#ffffff")
	f.path(f"M{ix} {iy - 7}H{ox}V{cy - 3}Q{cx} {cy - 7} {ix} {iy}Z", "#20162a", opacity=lid)
	end_clip(f)
	# the lash line: a wedge, thickest at the outer end, past the corner
	f.path(f"M{ix - s * 1} {iy + 1}Q{cx - s * 3} {cy - up - 12 + heavy} {ox + s * 4} {oy - 4}L{ox + s * 0.5} {oy + 2.5}Q{cx - s * 2} {cy - up - 3 + heavy} {ix - s * 1} {iy + 1}Z", INK)
	f.path(f"M{ix + s * 6} {cy + dn + 2}Q{cx + s * 4} {cy + dn + 3} {ox} {oy + 9}", stroke=shade(f.skin, 0.45), sw=1.1)


def skin_face(f, skin, dark, top=33):
	"""Skin, with soft shading under the hair, at the sides of the face and along the jaw."""
	f.skin = skin
	f.fill(skin)
	f.soft(f"M-5-5H135V{top}Q65 {top + 6} -5 {top}Z", shade(dark, 0.92), 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.5, 3)


def head_sides(a, skin, dark):
	for n in ("Head_L", "Head_R"):
		a[n].fill(dark)
		a[n].soft("M-5 90H125V135H-5Z", shade(dark, 0.86), 0.6, 3)
	a["Head_Bo"].fill(shade(dark, 0.86))
