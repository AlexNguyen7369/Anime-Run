# Target look for sea_captain (design doc section 5, "Target look"): big square head, faceted hair, chunky straw hat, thick
# open red vest with 3 big gold buttons, faceted yellow sash, blue shorts, puffy fur rings, block hands, sandals. No ink shell.
# +X is the viewer's right in the front view. Everything is drawn and modelled by hand here.
import math
import random

from atlas import FACES, INK, SIZE, shade
from style2 import H, Kit, Ramps, _smooth
from style3 import big_head, finish

SKIN = "#f7c99e"
SKIN_D = "#d9976a"
SKIN_L = "#fddcb8"
RED = "#ac1c26"
RED_D = "#74101a"
RED_L = "#d8383c"
DENIM = "#2c4cb0"
DENIM_D = "#182a78"
DENIM_L = "#4a70d4"
YEL = "#f8d32c"
YEL_D = "#d9960f"
YEL_L = "#ffe96e"
HAIRCOL = "#0c0c12"
SCAR = "#ad6660"
LINE = "#2a1612"
DEFAULT = RED
R = Ramps(
	hair=["#050508", "#101018", "#20202c", "#3a3a4c"],
	straw=["#8a5410", "#c98c1c", "#eab030", "#f6c84a", "#fbdc78"],
	band=["#7e0e14", "#b81c24", "#d8343a", "#ec5454"],
	red=["#52080e", "#74101a", "#8e141e"],
	gold=["#a86c08", "#e0a818", "#f8d040", "#fff09a"],
	fur=["#766da6", "#aea5d4", "#dcd6f2", "#ffffff"],
	skin=["#b87a4e", "#dd9e70", "#f4c496", "#fbd6ae"],
	sole=["#7a4e24", "#a87840", "#d0a264", "#e0b87c"],
	strap=["#08080c", "#14141a", "#2a2a34"],
	sash=["#b87508", "#de9c12", "#f8d32c", "#ffe96e"],
	denim=["#101e5c", "#1c3086"],
)
HAIR = {"colour": HAIRCOL, "locks": []}
PROPS = []
# square jaw: the face plane runs almost to the chin
HEAD_ROWS = [(0, 0, 3.98, 0.7, 0.62), (0, 0, 4.08, 0.86, 0.78), (0, 0, 4.22, 0.9, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
# vest, shoulder to hem: z, front edge x, half width, half depth
VEST = [(4.03, 0.3, 0.98, 0.5), (3.94, 0.33, 1.05, 0.565), (3.5, 0.42, 1.05, 0.565), (3.0, 0.52, 1.05, 0.565), (2.5, 0.62, 1.05, 0.565), (2.0, 0.7, 1.05, 0.565), (1.93, 0.7, 1.03, 0.545)]
BUTTON_Z = (3.45, 2.98, 2.55)
COLS = (3, 3, 12)  # columns on a front panel, a side, the back
NCOL = 2 * COLS[0] + 2 * COLS[1] + COLS[2] + 4


def _edge(z):
	"""The vest's front edge x at height z."""
	for (z0, x0, *_), (z1, x1, *_) in zip(VEST, VEST[1:]):
		if z1 <= z <= z0:
			return x0 + (x1 - x0) * (z0 - z) / (z0 - z1)
	return VEST[-1][1]


def _art(face_name, u, t):
	x, y, pw, ph = FACES[face_name][:4]
	u, t = max(0.0, min(1.0, u)), max(0.0, min(1.0, t))
	return ((x + 2 + u * (pw - 4)) / SIZE, 1 - (y + 2 + t * (ph - 4)) / SIZE)


def _section(xe, hw, hd, cols=COLS, c=0.07):
	"""An open C round the body, seen from above: starts at the +X front edge, runs counter-clockwise, ends at the -X one."""
	xe = min(xe, hw - c - 0.03)
	anchors = [(xe, -hd), (hw - c, -hd), (hw, c - hd), (hw, hd - c), (hw - c, hd), (c - hw, hd), (-hw, hd - c), (-hw, c - hd), (c - hw, -hd), (-xe, -hd)]
	counts = (cols[0], 1, cols[1], 1, cols[2], 1, cols[1], 1, cols[0])
	pts = []
	for (a, b), m in zip(zip(anchors, anchors[1:]), counts):
		pts += [(a[0] + (b[0] - a[0]) * i / m, a[1] + (b[1] - a[1]) * i / m) for i in range(m)]
	return pts + [anchors[-1]]


def _cloth(k, part, name, paths, thick, outer_uv, lining=("red", 0.5)):
	"""A cloth sheet with real thickness. paths = rows of open polylines (x, y, z) running counter-clockwise, so the lining
	is on their left. outer_uv(row, column, position) -> atlas uv; the lining and the raw edges take one dark ramp tone."""
	ns = len(paths[0])
	n = 2 * ns
	rings = []
	for path in paths:
		inner = []
		for j, p in enumerate(path):
			a, b = path[max(j - 1, 0)], path[min(j + 1, ns - 1)]
			tx, ty = b[0] - a[0], b[1] - a[1]
			ln = math.hypot(tx, ty) or 1.0
			inner.append((p[0] - ty / ln * thick, p[1] + tx / ln * thick, p[2]))
		rings.append(list(path) + inner[::-1])
	verts, faces, _ = k._loft(rings, caps=(False, False))
	for r in (0, len(rings) - 1):
		faces += [(r * n + j, r * n + j + 1, r * n + n - 2 - j, r * n + n - 1 - j) for j in range(ns - 1)]
	o = k._mesh(name, part, verts, faces)
	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	for poly in mesh.polygons:
		outer = all(vi % n < ns for vi in poly.vertices)
		for li in poly.loop_indices:
			vi = mesh.loops[li].vertex_index
			uv[li].uv = outer_uv(vi // n, vi % n, verts[vi]) if outer else k.R.uv(lining[0], lining[1])
	return o


def _block(k, part, name, cx, cy, z0, z1, hw, hd, skin, ch=0.05, v=(0.35, 0.95)):
	"""A chamfered box."""
	rows = [(cx, cy, z0, hw - ch, hd - ch), (cx, cy, z0 + ch, hw, hd), (cx, cy, z1 - ch, hw, hd), (cx, cy, z1, hw - ch, hd - ch)]
	return k.tube(part, name, rows, skin, corner=0.3, nc=1, v=v)


def _strap(k, part, name, pts, out, w=0.075, h=0.03):
	"""A flat band along a polyline, its face turned to out: fixed axes, so it cannot twist round the foot."""
	from mathutils import Vector

	vs = [Vector(q) for q in pts]
	rings = []
	for i, q in enumerate(vs):
		d = (vs[min(i + 1, len(vs) - 1)] - vs[max(i - 1, 0)]).normalized()
		a = d.cross(Vector(out)).normalized()
		n = a.cross(d).normalized()
		rings.append([tuple(q + a * sa * w + n * sn * h) for sa, sn in ((1, 1), (-1, 1), (-1, -1), (1, -1))])
	verts, faces, flat = k._loft(rings)
	o = k._mesh(name, part, verts, faces, flat)
	k._ramp_uv(o, "strap", lambda vi, co: 0.2 + 0.7 * (vi % 4 < 2))


def _ring_rows(rings, lip=0.035, v=(0.45, 0.85)):
	"""Lathe rows for stacked straw rings, one (r, z) per ring start, from the rim inwards: each ring is a rounded course."""
	rows = []
	for i, (r, z) in enumerate(rings[:-1]):
		r1, z1 = rings[i + 1]
		tone = v[0] + (v[1] - v[0]) * i / max(len(rings) - 2, 1)
		rows += [(r, z, tone - 0.14), (r + (r1 - r) * 0.28 + lip * 0.4, z + (z1 - z) * 0.4 + lip, tone + 0.12), (r + (r1 - r) * 0.8, z + (z1 - z) * 0.8 + lip * 0.7, tone)]
	return rows


def _weave(o, n, per_ring=3, start=0):
	"""Every other straw course turns half a segment: the courses interlock in diamonds instead of lining up."""
	for vt in o.data.vertices:
		ri = vt.index // n - start
		if ri >= 0 and (ri // per_ring) % 2:
			a = math.pi / n
			c, s = math.cos(a), math.sin(a)
			vt.co.x, vt.co.y = vt.co.x * c - vt.co.y * s, vt.co.x * s + vt.co.y * c


def _hat(k):
	n_brim, n_crown = 44, 24
	pivot, tilt, at = (0, 0, 5.4), 8, (0, 0.05, 0)
	# the brim, rim first: underside, thick frayed rim, five courses climbing to the crown
	courses = [(1.86 - 0.19 * i, 5.14 + 0.125 * i) for i in range(5)]
	top = _ring_rows(courses, lip=0.05, v=(0.5, 0.82))
	under = [(0.92, 5.36, 0.04), (1.84, 5.1, 0.12), (1.88, 5.13, 0.3)]
	o = k.lathe("Head", "Brim", under + top, "straw", n=n_brim, at=at, waves=11)
	_weave(o, n_brim, start=len(under))
	rng = random.Random(7)
	jag = [rng.uniform(-0.04, 0.04) + (0.075 if j % 2 else -0.065) for j in range(n_brim)]
	dip = [rng.uniform(-0.025, 0.025) for _ in range(n_brim)]
	for vt in o.data.vertices:  # frayed rim, a slow wave round the brim
		ri, j = vt.index // n_brim, vt.index % n_brim
		a = 2 * math.pi * j / n_brim
		if ri in (1, 2, 3, 4):
			w = 1.0 if ri in (2, 3) else 0.6
			vt.co.x += math.cos(a) * jag[j] * w
			vt.co.y += math.sin(a) * jag[j] * w
			vt.co.z += dip[j] * w
		vt.co.z += 0.03 * math.sin(4 * a + 1) * min(1.0, max(0.0, (math.hypot(vt.co.x, vt.co.y) - 1) / 0.8))
	k.tip(o, tilt, pivot)
	# the crown: a squared dome of straw courses
	z0, height, r0 = 5.56, 1.02, 1.17

	def dome(z):
		return r0 * max(0.0, 1 - ((z - z0) / height) ** 2.6) ** 0.5

	zs = [z0 + height * t for t in (0, 0.38, 0.56, 0.72, 0.85, 0.95)]
	rows = _ring_rows([(dome(z), z) for z in zs] + [(0.02, z0 + height + 0.015)], lip=0.03, v=(0.55, 0.9))
	o = k.lathe("Head", "Crown", rows, "straw", n=n_crown, at=at, waves=6)
	_weave(o, n_crown)
	k.tip(o, tilt, pivot)
	# the thick red band, standing proud of the crown with a chamfered top and bottom
	band = [(1.17, 5.58, 0.2), (1.225, 5.62, 0.45), (1.205, 5.74, 0.62), (1.185, 5.9, 0.82), (1.13, 5.95, 1.0), (1.05, 5.96, 0.7)]
	k.tip(k.lathe("Head", "HatBand", band, "band", n=n_crown, at=at), tilt, pivot)


# faceted locks: (root x, tip x, tip z, radius)
FRINGE = [(-0.7, -1.06, 4.7, 0.42), (-0.36, -0.5, 4.8, 0.42), (0.0, -0.02, 4.76, 0.42), (0.36, 0.5, 4.8, 0.42), (0.7, 1.06, 4.7, 0.42)]
# round the sides and back: (azimuth from the front, tip z, reach, radius)
TUFTS = [(74, 4.5, 1.3, 0.3), (92, 4.84, 1.5, 0.32), (108, 4.34, 1.34, 0.33), (128, 4.62, 1.42, 0.33), (150, 4.16, 1.24, 0.36), (180, 4.08, 1.18, 0.4), (210, 4.16, 1.24, 0.36), (232, 4.62, 1.42, 0.33), (252, 4.34, 1.34, 0.33), (268, 4.84, 1.5, 0.32), (286, 4.5, 1.3, 0.3)]


def _hair(k):
	# the cap under the hat, and the block of hair behind the ears
	_block(k, "Head", "HairCap", 0, 0.01, 4.98, 5.5, 0.945, 0.86, "hair", ch=0.05, v=(0.2, 0.5))
	back = [(0, 0.6, 4.14, 0.78, 0.26), (0, 0.56, 4.3, 0.91, 0.31), (0, 0.46, 5.02, 0.94, 0.42)]
	k.tube("Head", "HairBack", back, "hair", corner=0.2, nc=1, v=(0.15, 0.45))
	for i, (x0, x1, z, r) in enumerate(FRINGE):
		k.lock("Head", f"Fringe{i}", H((x0, -0.72, 5.34), ((x0 + x1) / 2, -0.98, 5.14), (x1, -0.92, z), r, flat=0.62, p=2.2, q=0.9), "hair", v=(0.4, 1.0), rn=3, sn=4)
	for i, (az, z, reach, r) in enumerate(TUFTS):
		a = math.radians(az)
		dx, dy = math.sin(a), -math.cos(a)
		k.lock("Head", f"Tuft{i}", H((0.72 * dx, 0.66 * dy, 5.34), (1.0 * dx, 0.92 * dy, 5.14), (reach * dx, 0.9 * reach * dy, z), r, flat=0.62, p=1.6, q=1.0), "hair", v=(0.4, 1.0), rn=3, sn=4)


def _vest(k):
	paths = []
	for ri, (z, xe, hw, hd) in enumerate(VEST):
		# viewer-left panel hangs longer than the viewer-right one
		paths.append([(x, y, z + (0.09 if x > 0 and ri >= len(VEST) - 2 else 0.0)) for x, y in _section(xe, hw, hd)])
	z_top, z_low = VEST[0][0], VEST[-1][0]
	_cloth(k, "UpperTorso", "Vest", paths, 0.075, lambda r, j, p: _art("Torso_B", j / NCOL, (z_top - VEST[r][0]) / (z_top - z_low)))
	for i, z in enumerate(BUTTON_Z):
		k.blob("UpperTorso", f"Button{i}", (-_edge(z) - 0.2, -0.575, z), (0.13, 0.06, 0.13), "gold", v=0.55, rings=5, n=16)


def _sash(k):
	"""A faceted wrap: over the viewer-right panel and the back, under the viewer-left panel."""
	n = 48
	rows = [(2.19, 0.0, 1.0), (2.22, 0.028, 0.86), (2.31, 0.012, 0.66), (2.41, 0.034, 0.42), (2.5, 0.014, 0.28), (2.6, 0.03, 0.08), (2.64, 0.0, 0.0)]
	rings = []
	for ri, (z, amp, _) in enumerate(rows):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, s = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.2, c), math.copysign(abs(s) ** 0.2, s)
			out = max(_smooth(-0.6, 0.3, px), _smooth(-0.1, 0.4, py))
			hw, hd = 1.0 + 0.09 * out, 0.525 + 0.095 * out
			fold = amp * (1 + 0.6 * math.sin(j * 0.9 + ri * 1.7))
			ring.append((px * hw + c * fold, py * hd + s * fold, z + 0.012 * math.sin(j * 1.3 + ri)))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Sash", "UpperTorso", verts, faces, flat)
	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	for li, loop in enumerate(mesh.loops):
		ri, j = loop.vertex_index // n, loop.vertex_index % n
		# the front runs viewer-left to viewer-right over the whole face, the back mirrors it: no seam, twice the pixels
		a = 2 * j / n
		uv[li].uv = _art("Torso_R", a - 1 if a >= 1 else 1 - a, rows[ri][2])


def _tail(k):
	"""The wide tail at the viewer-right hip: a fat cloth with faceted folds; past the hip it hangs on the leg."""
	span = (2.62, 1.2)
	cols = 6

	def sheet(part, name, rows, slant=0.0, first=0):
		paths = []
		for ri, (cx, y, z, hw, d) in enumerate(rows):
			end = ri == len(rows) - 1
			paths.append([(cx + hw * (2 * j / cols - 1), y + d * math.sin(2 * math.pi * (2.5 * j / cols + 0.17 * (ri + first))), z + (slant * (j / cols - 0.5) if end else 0)) for j in range(cols + 1)])
		uvf = lambda r, j, p: _art("Torso_L", j / cols, (span[0] - rows[r][2]) / (span[0] - span[1]))
		return _cloth(k, part, name, paths, 0.07, uvf, lining=("sash", 0.15))

	sheet("UpperTorso", "SashTailTop", [(0.74, -0.7, 2.6, 0.22, 0.012), (0.75, -0.7, 2.3, 0.24, 0.02), (0.76, -0.68, 2.0, 0.27, 0.024)])
	sheet("LeftUpperLeg", "SashTail", [(0.76, -0.68, 2.0, 0.27, 0.024), (0.77, -0.67, 1.7, 0.32, 0.028), (0.78, -0.67, 1.42, 0.36, 0.03), (0.78, -0.68, 1.22, 0.39, 0.026)], slant=0.16, first=2)  # first: the fold phase carries on across the join
	_block(k, "UpperTorso", "SashWrap", 0.74, -0.68, 2.36, 2.66, 0.28, 0.06, "sash", ch=0.025, v=(0.35, 1.0))


def _arm(k, s, side):
	part = f"{side}UpperArm"
	ax = s * 1.5
	# shoulder chamfer, a slight elbow crease, a chamfered block hand: full width down to the end, no wrist (owner: smooth block hands)
	rows = [(ax, 0, 4.03, 0.42, 0.42), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 3.1, 0.5, 0.5), (ax, 0, 3.03, 0.485, 0.485), (ax, 0, 2.96, 0.5, 0.5), (ax, 0, 1.87, 0.5, 0.5), (ax, 0, 1.8, 0.43, 0.43)]
	k.reshape(part, f"{side}Arm", rows, corner=0.14, nc=1)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	lx = s * 0.52
	k.reshape(part, f"{side}Leg", [(lx, 0, 0.3, 0.46, 0.46), (lx, 0, 1.3, 0.46, 0.46)], corner=0.14, nc=1)
	# shorts: a boxy flare down to the knee. Keep every leg mesh at z <= 2: merge mirrors the extent round z 1 for its bounds triangle, so higher means below z 0
	sx0, sx1 = s * 0.5, s * 0.58
	shorts = [(sx0, 0, 2.0, 0.49, 0.52), (s * 0.54, 0, 1.6, 0.53, 0.55), (sx1, 0, 1.24, 0.565, 0.58), (sx1, 0, 1.18, 0.53, 0.54)]
	k.tube(part, "Shorts", shorts, ("face", f"{side}Leg"), corner=0.12, nc=1)
	# the fur ring: fat, puffy, lumps round it
	fur = [(0.7, 0.46, 0.49, 0.02, 0.04), (0.75, 0.57, 0.61, 0.04, 0.2), (0.85, 0.63, 0.67, 0.05, 0.46), (0.98, 0.645, 0.685, 0.05, 0.7), (1.11, 0.62, 0.66, 0.04, 0.86), (1.19, 0.54, 0.57, 0.025, 0.72), (1.22, 0.42, 0.45, 0.0, 0.42)]
	n, waves, cx = 40, 9, s * 0.58
	rings = []
	for ri, (z, hw, hd, amp, _) in enumerate(fur):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			lump = math.cos(waves * a + ri * 0.5)
			ring.append((cx + math.copysign(abs(c) ** 0.45, c) * (hw + amp * lump), math.copysign(abs(sn) ** 0.45, sn) * (hd + amp * lump), z + 0.012 * lump))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	o = k._mesh("FurCuff", part, verts, faces, flat)
	k._ramp_uv(o, "fur", lambda vi, co: fur[vi // n][4] + 0.2 * math.cos(waves * 2 * math.pi * (vi % n) / n + (vi // n) * 0.5))
	# the foot: chunky, ramps from ankle to a forward toe; toes as blocks with notches; a thick sole; a black V strap
	foot = [(lx, -0.17, 0.08, 0.47, 0.63), (lx, -0.17, 0.18, 0.47, 0.63), (lx, -0.12, 0.28, 0.47, 0.58), (lx, -0.03, 0.42, 0.46, 0.47)]
	k.tube(part, "Foot", foot, "skin", corner=0.16, nc=1, v=(0.3, 0.72))
	_block(k, part, "Sole", lx, -0.2, 0.0, 0.1, 0.53, 0.75, "sole", ch=0.03, v=(0.2, 0.95))
	for i in range(4):
		x = lx + (-0.33 + 0.22 * i)
		_block(k, part, f"Toe{i}", x, -0.8, 0.08, 0.26, 0.095, 0.1, "skin", ch=0.03, v=(0.5, 0.95))
	# the V: from between the toes up over the foot, then back down its sides to the sole
	apex = (lx - s * 0.11, -0.8, 0.24)
	for t, sg in (("I", -s), ("O", s)):
		ex = lx + sg * 0.45
		_strap(k, part, "Strap" + t, [apex, ((apex[0] + ex) / 2, -0.72, 0.31), (ex, -0.55, 0.41)], (0, -0.6, 0.8))
		_strap(k, part, "StrapSide" + t, [(ex + sg * 0.03, -0.53, 0.41), (ex + sg * 0.035, -0.34, 0.27), (ex + sg * 0.035, -0.14, 0.1)], (sg, 0, 0), w=0.06)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	for s in (1, -1):
		k.blob("Head", f"Ear{s}", (s * 0.93, 0.02, 4.6), (0.09, 0.17, 0.2), "skin", v=0.55, rings=3, n=6)
	_hair(k)
	_hat(k)
	_vest(k)
	_block(k, "UpperTorso", "Waist", 0, 0, 1.72, 2.25, 1.0, 0.525, "denim", ch=0.04, v=(0.2, 0.9))
	_sash(k)
	_tail(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def _soft_line(f, d, colour, sw, opacity=0.8, blur=1):
	f.path(d, stroke=colour, sw=sw, opacity=opacity, blur=blur)


def _eye(f, cx, cy, rx, ry, look, sgn):
	"""A very large round white eye, black pupil with a glint, cut across the top by an angry brow. sgn +1 = viewer's right."""
	oval = lambda x, y, a, b: f"M{x - a} {y}a{a} {b} 0 1 0 {2 * a} 0a{a} {b} 0 1 0 {-2 * a} 0Z"
	f.path(oval(cx, cy, rx, ry), INK, stroke=INK, sw=3.0)
	f.path(oval(cx, cy, rx - 0.5, ry - 0.5), "#fefdf8")
	f.soft(oval(cx, cy - ry * 0.5, rx, ry * 0.5), "#a8a4c0", 0.45, 2)
	f.path(oval(cx + look, cy + 2, rx * 0.46, ry * 0.46), "#050408")
	f.path(oval(cx + look - rx * 0.16, cy + 2 - ry * 0.18, rx * 0.13, ry * 0.13), "#ffffff")
	# the skin above the brow's lower edge covers the eye's top, then the brow itself: low at the nose, high outside
	ix, ox = cx - sgn * (rx + 3), cx + sgn * (rx + 7)
	iy, oy = cy - ry * 0.32, cy - ry * 0.86
	f.path(f"M{ix} {iy - 2}L{ox} {oy - 2}V{oy - 24}H{ix}Z", SKIN)
	f.path(f"M{ix - sgn * 1} {iy + 2}L{ox} {oy + 1}L{ox + sgn * 2} {oy - 12}L{ix} {iy - 15}Z", INK)


def _grin(f):
	mouth = "M31 98Q65 103 99 98Q101 110 88 117Q65 123 42 117Q29 110 31 98Z"
	f.path(mouth, "#fffef8", stroke=INK, sw=2.6)
	f.ink("M33 107Q65 113 97 107", 1.6, "#4a444c")
	for x, top, bot in ((41, 100, 115), (50, 100.8, 118), (59, 101, 119.5), (68, 101, 119.5), (77, 100.8, 118), (86, 100, 115.5)):
		f.ink(f"M{x} {top}L{x} {bot}", 1.5, "#4a444c")
	f.ink("M31 98Q65 103 99 98", 2.6)
	# cheeks pushed up by the grin
	f.ink("M26 93Q24 99 29 103", 1.6, shade(SKIN, 0.55))
	f.ink("M104 93Q106 99 101 103", 1.6, shade(SKIN, 0.55))


def paint(a):
	R.paint(a)
	# chunky dark stitches between straw blocks, and short straw ends at the top of the zone (the rim)
	f = a["Hair"]
	zone = f.w / len(R.names)
	x0 = R.names.index("straw") * zone
	for j in range(4):
		x = x0 + 0.06 * zone + 0.88 * zone * (j + 0.5) / 4
		f.path(f"M{x:.1f} -5V96", stroke="#6e430e", sw=2.2, opacity=0.5)
	for j in range(14):
		x = x0 + 3 + (zone - 6) * j / 14
		f.path(f"M{x:.1f} {2 + j % 3}V{13 + (j * 7) % 8}", stroke="#5e3c10", sw=1.2, opacity=0.6)
	# ---- face: 130 units = 1.8 studs across but 1.3 down, so a round eye has ry = 1.38 rx
	f = a["Head_F"]
	f.fill(SKIN)
	f.soft("M-5 20H135V120Q65 86 -5 120Z", SKIN_L, 0.45, 8)
	f.soft("M-5-5H10Q5 70 14 135H-5Z", SKIN_D, 0.75, 5)
	f.soft("M135-5H120Q125 70 116 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M-5 122Q65 132 135 122V135H-5Z", SKIN_D, 0.6, 2)
	f.soft("M58 88Q65 95 72 88L70 80H60Z", SKIN_D, 0.35, 2)
	f.ink("M60 91Q65 94 70 91", 1.4, shade(SKIN, 0.5))
	_eye(f, 34, 65, 17, 23.5, 2.0, -1)
	_eye(f, 96, 65, 17, 23.5, -2.0, 1)
	f.soft("M-5-5H135V34Q65 26 -5 34Z", shade(SKIN, 0.55), 0.7, 3)
	_grin(f)
	# the stitched scar under the viewer-right eye
	f.ink("M100 92Q109 93.5 118 90", 2.2, LINE)
	f.ink("M104 87.5L103.5 97M110 88L110 97.5M115.5 87L116 96", 1.9, LINE)
	# ---- bare chest between the panels: soft shadow from the head and the vest, thin X scar, pecs, abs
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M-5-5H205V22Q100 42 -5 22Z", SKIN_D, 0.75, 5)
	f.soft("M-5-5H72L48 205H-5Z", SKIN_D, 0.75, 5)
	f.soft("M205-5H128L152 205H205Z", SKIN_D, 0.75, 5)
	crease = shade(SKIN, 0.68)
	_soft_line(f, "M58 84Q78 96 97 88", crease, 3.4)
	_soft_line(f, "M142 84Q122 96 103 88", crease, 3.4)
	_soft_line(f, "M100 90Q99 125 100 165", crease, 2.4)
	for y, half in ((106, 21), (124, 20), (142, 18)):
		_soft_line(f, f"M{100 - half} {y - 2}Q{100 - half / 2} {y + 3} 98 {y}", crease, 2.4)
		_soft_line(f, f"M{100 + half} {y - 2}Q{100 + half / 2} {y + 3} 102 {y}", crease, 2.4)
	f.soft("M86 94Q80 110 88 120Q96 110 94 96Z", SKIN_L, 0.5, 2)
	f.soft("M114 94Q120 110 112 120Q104 110 106 96Z", SKIN_L, 0.5, 2)
	# the thin X, torn edges by two passes
	for d in ("M72 30L128 78", "M128 30L72 78"):
		f.path(d, stroke=shade(SCAR, 0.72), sw=4.2)
		f.path(d, stroke=SCAR, sw=2.4)
	for x, y in ((80, 37), (88, 44), (112, 44), (120, 37), (112, 64), (120, 71), (80, 71), (88, 64)):
		f.path(f"M{x - 3} {y - 3}L{x + 3} {y + 3}M{x + 3} {y - 3}L{x - 3} {y + 3}", stroke=shade(SCAR, 0.8), sw=1.2)
	f.soft("M-5 180H205V205H-5Z", SKIN_D, 0.5, 2)
	# ---- the vest, Torso_B: u runs viewer-right front edge -> round the back -> viewer-left front edge. Column positions:
	f = a["Torso_B"]
	front_r = 200 * COLS[0] / NCOL
	side_r = 200 * (COLS[0] + 1 + COLS[1]) / NCOL
	side_l = 200 * (NCOL - COLS[0] - 1 - COLS[1]) / NCOL
	front_l = 200 * (NCOL - COLS[0]) / NCOL
	f.fill(RED)
	f.soft("M-5-5H205V22H-5Z", RED_L, 0.55, 3)
	f.soft("M-5 150H205V205H-5Z", RED_D, 0.55, 5)
	# the sides fall away from the light
	f.soft(f"M{front_r + 2}-5H{side_r + 2}V205H{front_r + 2}Z", RED_D, 0.5, 2)
	f.soft(f"M{side_l - 2}-5H{front_l - 2}V205H{side_l - 2}Z", RED_D, 0.55, 2)
	f.soft(f"M{side_r + 2}-5H{side_l - 2}V205H{side_r + 2}Z", RED_D, 0.22, 3)
	# lit middle of each front panel, fold creases, a dark piped front edge
	for x in (front_r * 0.5, 200 - front_r * 0.5):
		f.soft(f"M{x - 6} 16H{x + 6}L{x + 7} 170H{x - 7}Z", RED_L, 0.55, 3)
	f.path("M-5-5H2.6V205H-5Z", RED_D, opacity=0.95)
	f.path("M205-5H197.4V205H205Z", RED_D, opacity=0.95)
	for x, y0, y1 in ((front_r * 0.72, 60, 150), (200 - front_r * 0.72, 60, 150), (front_r * 0.3, 110, 190), (200 - front_r * 0.3, 110, 190), (70, 40, 170), (100, 60, 190), (130, 40, 170)):
		_soft_line(f, f"M{x} {y0}Q{x + 2} {(y0 + y1) / 2} {x - 1.5} {y1}", RED_D, 2.6, 0.9)
	# ---- the sash, Torso_R: x runs viewer-left to viewer-right across the front, y top to bottom; on the model x is 50
	# units a stud and y 444, so creases are drawn tall and they pull towards the tail
	f = a["Torso_R"]
	f.fill(YEL)
	f.soft("M-5-5H105V36H-5Z", YEL_L, 0.9, 5)
	f.soft("M-5 160H105V205H-5Z", YEL_D, 0.75, 5)
	for x0, y0, y1, x1, y2, y3 in ((6, 30, 66, 84, 96, 134), (22, 112, 150, 88, 120, 170), (34, 8, 40, 70, 48, 84), (10, 136, 166, 40, 178, 200)):
		f.path(f"M{x0} {y0}Q{(x0 + x1) / 2} {(y0 + y2) / 2 - 8} {x1} {y2}L{x1} {y3}Q{(x0 + x1) / 2} {(y1 + y3) / 2 - 8} {x0} {y1}Z", YEL_D, opacity=0.8, blur=1)
		f.path(f"M{x0} {y0 - 12}Q{(x0 + x1) / 2} {(y0 + y2) / 2 - 20} {x1} {y2 - 12}L{x1} {y2 - 2}Q{(x0 + x1) / 2} {(y0 + y2) / 2 - 10} {x0} {y0 - 2}Z", YEL_L, opacity=0.8, blur=1)
	# ---- the tail, Torso_L: bright, two fold shadows, an orange shadow down its far side
	f = a["Torso_L"]
	f.fill(YEL)
	f.soft("M84 -5H105V205H80Z", YEL_D, 0.65, 3)
	f.soft("M-5 -5H6V205H-5Z", YEL_D, 0.35, 3)
	f.soft("M14 20Q24 100 20 190H34Q38 90 28 20Z", YEL_L, 0.85, 3)
	for x, y0, y1, bend in ((46, 12, 190, -5), (72, 40, 200, 5)):
		f.path(f"M{x} {y0}Q{x + bend} {(y0 + y1) / 2} {x + bend * 0.3 + 7} {y1}L{x + bend * 0.3 - 3} {y1}Q{x + bend - 3} {(y0 + y1) / 2} {x} {y0}Z", YEL_D, opacity=0.8)
	f.soft("M-5 188H105V205H-5Z", YEL_D, 0.5, 3)
	a["Torso_T"].fill(RED)
	a["Torso_Bo"].fill(DENIM_D)
	# ---- leg faces: shorts on top (z above 1.1), shin below; arm faces: bare skin, soft falloff at the edges and the wrist
	tones = {"F": 0.0, "O": 0.28, "I": 0.5, "B": 0.42}
	for side, s in (("Left", 1), ("Right", -1)):
		for key, dark in tones.items():
			f = a[f"{side}Leg_{key}"]
			f.fill(SKIN)
			f.soft("M-5 120H12L16 205H-5Z", SKIN_D, 0.5, 3)
			f.soft("M88 120H105V205H84Z", SKIN_D, 0.7, 3)
			f.soft("M-5 110H105V146Q50 138 -5 146Z", SKIN_D, 0.75, 3)
			if dark:
				f.soft("M-5 110H105V205H-5Z", SKIN_D, dark, 2)
			f.path("M-5-5H105V116H-5Z", DENIM)
			f.soft("M-5 70H105V116H-5Z", DENIM_D, 0.6, 5)
			f.soft("M-5-5H105V30H-5Z", DENIM_D, 0.55, 4)
			f.soft("M78-5H105V116H82Z", DENIM_D, 0.6, 3)
			f.soft("M-5-5H10V116H-5Z", DENIM_D, 0.35, 3)
			if dark:
				f.soft("M-5-5H105V116H-5Z", DENIM_D, dark, 2)
			_soft_line(f, "M16 66Q44 74 84 60", DENIM_D, 2.0)
			_soft_line(f, "M24 86Q50 92 88 80", DENIM_D, 2.0)
			f = a[f"{side}Arm_{key}"]
			f.fill(SKIN)
			f.soft("M18 14H82L78 96H22Z", SKIN_L, 0.6, 8)
			f.soft("M-5-5H10L12 210H-5Z", SKIN_D, 0.45, 5)
			f.soft("M105-5H88L84 210H105Z", SKIN_D, 0.75, 5)
			f.soft("M-5 96H105V112H-5Z", SKIN_D, 0.5, 3)
			f.soft("M-5 150H105V210H-5Z", SKIN_D, 0.55, 8)
			if dark:
				f.path("M-5-5H105V210H-5Z", SKIN_D, opacity=dark)
		f = a[f"{side}Leg_F"]
		f.soft("M26 30Q46 26 50 60Q34 76 22 62Z", DENIM_L, 0.65, 4)
		ix, ox = (2, 100) if s > 0 else (98, 0)
		f.ink(f"M{ix} 0L{ix} 42", 2.4, DENIM_D)
		f.ink(f"M{ox - s * 36} 4Q{ox - s * 24} 24 {ox - s * 3} 28", 1.8, DENIM_D)
		for key in ("Leg_T", "Arm_T"):
			a[f"{side}{key}"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(shade(SKIN, 0.85))
		a[f"{side}Leg_Bo"].fill(shade(SKIN, 0.85))
	for n in ("Head_B", "Head_T"):
		a[n].fill(HAIRCOL)
	# head sides: bare cheek, falling off towards the back and the jaw
	for n, back in (("Head_L", 1), ("Head_R", -1)):
		f = a[n]
		f.fill(SKIN)
		xb = 120 if back > 0 else 0
		f.soft(f"M{xb - back * 70} -5H{xb + back * 5}V135H{xb - back * 70}Z", SKIN_D, 0.55, 8)
		f.soft("M-5 118H125V135H-5Z", SKIN_D, 0.6, 3)
		f.soft("M-5-5H125V40H-5Z", shade(SKIN, 0.55), 0.6, 3)
	a["Head_Bo"].fill(SKIN_D)
