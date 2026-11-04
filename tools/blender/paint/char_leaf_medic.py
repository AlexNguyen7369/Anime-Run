# Target look (design doc section 5) for leaf_medic: big head, faceted pink hair of separate shards, modelled band and plate,
# zipped vest, block fists, split apron, tall open-toe boots. Every plane's tone is baked into a ramp, since there is no outline.
import math

from atlas import FACES, SIZE, shade
from leaf_common import begin_clip, ell, end_clip, village_mark
from style3 import big_head, finish
from style2 import Kit, Ramps

SKIN = "#f8cfa8"
SKIN_D = "#d99a72"
VEST = "#971a2f"
VEST_D = "#5e0e22"
VEST_L = "#b72a41"
DEFAULT = VEST
R = Ramps(
	hair=["#96406c", "#c4648a", "#e28caa", "#f0a8c0", "#f8cad9"],
	pink=["#a8668a", "#cc8aa6", "#e2a5bd", "#efc0d2"],
	trim=["#c9b4bd", "#ecdfe3", "#fff8f8"],
	band=["#4e0e18", "#7a1824", "#9c2430"],
	red=["#500c1c", "#7c1729", "#a02438", "#bb3249"],
	shorts=["#120c16", "#231a29", "#3a2d42"],
	boot=["#180f20", "#2f2038", "#493654", "#604a6c"],
	sole=["#120b18", "#221729", "#3a2a44"],
	glove=["#1e1226", "#3a2744", "#57405f", "#705878"],
	steel=["#6e7682", "#a4acb8", "#d8dde4"],
	zip=["#8b929c", "#c9ced6", "#f4f6f8"],
	tape=["#6a6e78", "#8c909a"],
	white=["#b9b2bd", "#e8e4ea", "#fffdfd"],
	skin=["#c98a64", "#e8b48c", "#f8cfa8", "#ffe2c4"],
)

HAIR = {"colour": "#ef9dbd", "locks": []}
PROPS = []

LIGHT = (-0.33, -0.57, 0.75)
# style3's big head with a narrow jaw and pointed chin; the art keeps z 4.0-5.3
HEAD_ROWS = [(0, 0, 3.98, 0.3, 0.62), (0, 0, 4.2, 0.6, 0.78), (0, 0, 4.48, 0.84, 0.82), (0, 0, 4.74, 0.9, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]


def _lit(n):
	"""How a plane faces the light; the far side stays readable, not black."""
	d = n.x * LIGHT[0] + n.y * LIGHT[1] + n.z * LIGHT[2]
	return d if d > 0 else d * 0.45


def _paint(o, fn):
	"""fn(polygon index, polygon, vertex position) -> (ramp, v). Overwrites whatever uv the mesh had."""
	mesh = o.data
	layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
	for poly in mesh.polygons:
		for li in poly.loop_indices:
			ramp, v = fn(poly.index, poly, mesh.vertices[mesh.loops[li].vertex_index].co)
			layer.data[li].uv = R.uv(ramp, v)


def _planes(o, ramp, base=0.55, amp=0.3, grad=0.08, mid=None):
	"""Each plane its own tone by how it faces the light, a soft fall from top to bottom over it."""
	zs = [vt.co.z for vt in o.data.vertices]
	mid = (min(zs) + max(zs)) / 2 if mid is None else mid
	span = max(max(zs) - min(zs), 0.2)

	def tone(_, poly, co):
		return ramp, base + amp * _lit(poly.normal) + grad * (co.z - mid) / span * 2

	_paint(o, tone)
	return o


def _block(k, part, name, rows, ramp, corner=0.15, nc=1, sub=0, **tone):
	return _planes(k.tube(part, name, rows, ramp, corner=corner, nc=nc, sub=sub, outline=0), ramp, **tone)


def _box(k, part, name, c, h, ramp, ch=0.03, **tone):
	"""A chamfered box: c centre, h half sizes."""
	x, y, z = c
	hx, hy, hz = h
	rows = [(x, y, z - hz, hx - ch, hy - ch), (x, y, z - hz + ch, hx, hy), (x, y, z + hz - ch, hx, hy), (x, y, z + hz, hx - ch, hy - ch)]
	return _block(k, part, name, rows, ramp, corner=ch / min(hx, hy), **tone)


def _cubes(k, part, name, cubes, ramp, **tone):
	"""Many plain boxes in one mesh: zip teeth."""
	verts, faces = [], []
	for (x, y, z), (hx, hy, hz) in cubes:
		b = len(verts)
		verts += [(x + a * hx, y + c * hy, z + d * hz) for a in (-1, 1) for c in (-1, 1) for d in (-1, 1)]
		faces += [[b + i for i in f] for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))]
	return _planes(k._mesh(name, part, verts, faces, (), 0), ramp, **tone)


# a lock's section: across, outwards. A roof with an off-centre ridge: two big planes that catch the light differently
SECTION = ((-1, -0.15), (-0.12, 1), (1, -0.15), (0.35, -0.7), (-0.35, -0.7))
HAIR_CENTRE = (0, 0.1, 5.0)
HAIR_LIGHT = (-0.58, -0.42, 0.7)


def _shard(k, name, pts, tone=0.0, part="Head", flat=0.62):
	"""One large angular lock of hair, a closed solid. pts = (x, y, z, half width), root to tip."""
	rings = []
	for i, p in enumerate(pts):
		a, b = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
		d = [b[j] - a[j] for j in range(3)]
		dl = math.sqrt(sum(c * c for c in d))
		d = [c / dl for c in d]
		out = [p[j] - HAIR_CENTRE[j] for j in range(3)]
		along = sum(out[j] * d[j] for j in range(3))
		out = [out[j] - along * d[j] for j in range(3)]
		ol = math.sqrt(sum(c * c for c in out)) or 1
		out = [c / ol for c in out]
		w = (d[1] * out[2] - d[2] * out[1], d[2] * out[0] - d[0] * out[2], d[0] * out[1] - d[1] * out[0])
		rings.append([tuple(p[j] + w[j] * p[3] * u + out[j] * p[3] * flat * h for j in range(3)) for u, h in SECTION])
	verts, faces, _ = k._loft(rings)
	o = k._mesh(name, part, verts, faces, (), 0)

	def plane_tone(_, poly, co):
		n = poly.normal
		lit = n.x * HAIR_LIGHT[0] + n.y * HAIR_LIGHT[1] + n.z * HAIR_LIGHT[2]
		return "hair", 0.42 + tone + 0.5 * (lit if lit > 0 else lit * 0.6) + 0.05 * (co.z - 5.1)

	_paint(o, plane_tone)
	return o


# locks = (tone, pts) on the +X side; the viewer's left flares a little further, as the target does
LOCKS = (
	# the curtain: from the part, arching over the forehead lobe, down outside the eye to a point by the chin
	(0.04, ((0.06, -0.84, 5.78, 0.1), (0.5, -0.96, 5.66, 0.3), (0.92, -0.98, 5.12, 0.32), (1.02, -0.97, 4.5, 0.25), (0.82, -0.93, 3.96, 0.01))),
	# the forehead lobe under the part: the darker layer showing at the hairline
	(-0.2, ((0.2, -0.88, 5.66, 0.16), (0.24, -0.91, 5.46, 0.2), (0.25, -0.9, 5.27, 0.17))),
	# the outer front mass
	(0.0, ((0.7, -0.78, 5.8, 0.2), (1.18, -0.86, 5.3, 0.38), (1.36, -0.82, 4.7, 0.3), (1.4, -0.76, 4.05, 0.01))),
	# two big flares at the side
	(0.02, ((0.95, -0.2, 5.75, 0.22), (1.42, -0.3, 5.2, 0.38), (1.72, -0.3, 4.75, 0.22), (1.95, -0.3, 4.45, 0.01))),
	(0.06, ((0.95, 0.25, 5.8, 0.22), (1.4, 0.2, 5.45, 0.36), (1.72, 0.15, 5.2, 0.2), (2.0, 0.12, 5.1, 0.01))),
	# the darker underlayer, its points below the flares
	(-0.2, ((1.1, 0.0, 4.95, 0.34), (1.38, 0.05, 4.4, 0.3), (1.42, 0.05, 3.9, 0.01))),
	# the back
	(0.0, ((0.62, 0.72, 5.58, 0.2), (1.1, 1.05, 5.05, 0.42), (1.35, 1.15, 4.45, 0.24), (1.55, 1.2, 4.05, 0.01))),
	(0.03, ((0.22, 0.82, 5.62, 0.2), (0.42, 1.22, 5.0, 0.42), (0.5, 1.28, 4.3, 0.28), (0.55, 1.3, 3.72, 0.01))),
	# over the crown
	(0.04, ((0.42, -0.2, 6.2, 0.3), (0.72, 0.25, 6.02, 0.45), (0.98, 0.7, 5.6, 0.3), (1.2, 0.95, 5.2, 0.01))),
)


def _build_hair(k):
	# the mass under the locks, in deep shadow: what shows between two locks is their crease. Its front stops at the hairline
	rows = [
		(0, 0.05, 6.24, 0.3, 0.28),
		(0, 0.03, 6.16, 0.72, 0.62),
		(0, 0.04, 5.98, 0.98, 0.82),
		(0, 0.06, 5.6, 1.1, 0.95),
		(0, 0.08, 5.32, 1.12, 0.96),
		(0, 0.3, 5.2, 1.1, 0.72),
		(0, 0.32, 4.6, 1.06, 0.72),
		(0, 0.35, 4.1, 0.96, 0.66),
		(0, 0.4, 3.9, 0.7, 0.55),
	]
	_block(k, "Head", "HairCap", rows, "hair", corner=0.6, nc=1, sub=1, base=0.1, amp=0.1, grad=0.0)
	for i, (tone, pts) in enumerate(LOCKS):
		_shard(k, f"Lock{i}L", pts, tone)
		_shard(k, f"Lock{i}R", [(-x * (1.07 if x > 1.2 else 1.0), y, z, w) for x, y, z, w in pts], tone - 0.02)
	_shard(k, "BackC", ((0, 1.05, 5.0, 0.35), (0, 1.12, 4.3, 0.3), (0, 1.14, 3.65, 0.01)), -0.2)
	_shard(k, "CrownC", ((0, -0.25, 6.3, 0.28), (0, 0.3, 6.22, 0.46), (0, 0.85, 5.85, 0.38), (0, 1.2, 5.4, 0.01)), 0.06)


def _decal_uv(fx, fy):
	"""Head_B units to atlas uv. The head's back is under the hair all round, so that art is free for the plate."""
	x, y, pw, ph, uw, uh = FACES["Head_B"]
	return ((x + fx / uw * pw) / SIZE, 1 - (y + fy / uh * ph) / SIZE)


PLATE = (0, -0.9, 5.9)
PLATE_TILT = math.radians(25)
PLATE_W, PLATE_H, PLATE_T = 0.6, 0.19, 0.18


def _build_band(k):
	b = k.band("Head", "Band", (0, 0.12, 5.47), 1.14, 0.95, 0, 360, lambda a: (-0.13, 0.13), "band", thick=0.07, e=0.75, n=36, rot=(math.radians(-28), 0, 0), outline=0)
	_planes(b, "band", base=0.55, amp=0.4, grad=0)
	# the plate: a chamfered bar bent round the head, tipped back. Its face wears the decal
	up = (0, math.sin(PLATE_TILT), math.cos(PLATE_TILT))
	out = (0, -math.cos(PLATE_TILT), math.sin(PLATE_TILT))
	ch = 0.03
	sec = [(-PLATE_H + ch, 0), (PLATE_H - ch, 0), (PLATE_H, -ch), (PLATE_H, -PLATE_T), (-PLATE_H, -PLATE_T), (-PLATE_H, -ch)]
	n = 7
	rings = []
	for i in range(n):
		x = PLATE_W * (2 * i / (n - 1) - 1)
		rings.append([(x, PLATE[1] + 0.22 * x * x + up[1] * u + out[1] * o, PLATE[2] + up[2] * u + out[2] * o) for u, o in sec])
	verts, faces, _ = k._loft(rings)
	o = k._mesh("Plate", "Head", verts, faces, (), 0)
	layer = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		face = len(poly.vertices) == 4 and all(vi % 6 < 2 for vi in poly.vertices)
		for li in poly.loop_indices:
			vi = o.data.loops[li].vertex_index
			co = o.data.vertices[vi].co
			if face:
				u = (co.x + PLATE_W) / (2 * PLATE_W)
				layer[li].uv = _decal_uv(5 + 120 * u, 5 if vi % 6 == 1 else 45)
			else:
				layer[li].uv = R.uv("steel", 0.25 + 0.3 * (poly.normal.z + 1))


def _slab(k, part, name, outer, inner, ramp_of):
	"""A cloth panel with real thickness: two grids of the same shape joined round the rim. ramp_of(column, row) -> ramp of a front face."""
	nc, nr = len(outer), len(outer[0])
	verts = [p for col in outer for p in col] + [p for col in inner for p in col]
	fi = lambda c, r: c * nr + r
	bi = lambda c, r: nc * nr + c * nr + r
	faces, tag = [], {}
	for c in range(nc - 1):
		for r in range(nr - 1):
			tag[len(faces)] = ramp_of(c, r)
			faces.append((fi(c, r), fi(c + 1, r), fi(c + 1, r + 1), fi(c, r + 1)))
	n_front = len(faces)
	for c in range(nc - 1):
		for r in range(nr - 1):
			faces.append((bi(c, r), bi(c, r + 1), bi(c + 1, r + 1), bi(c + 1, r)))
		for r in (0, nr - 1):
			tag[len(faces)] = ramp_of(c, min(r, nr - 2))
			faces.append((fi(c, r), bi(c, r), bi(c + 1, r), fi(c + 1, r)))
	for c in (0, nc - 1):
		for r in range(nr - 1):
			tag[len(faces)] = ramp_of(min(c, nc - 2), r)
			faces.append((fi(c, r), fi(c, r + 1), bi(c, r + 1), bi(c, r)))
	o = k._mesh(name, part, verts, faces, (), 0)

	def tone(pi, poly, co):
		lit = _lit(poly.normal)
		# bmesh keeps face order; tag is by that order. The panel's back is in shadow
		return (tag.get(pi, "pink"), 0.42 + 0.42 * lit + 0.12 * (co.z - 1.8) if pi in tag else 0.15)

	_paint(o, tone)
	return o


# 2.0 at most: a leg part centres at z 1 and the merge mirrors its top extent to the bottom, so higher dips below the ground
SKIRT_TOP, SKIRT_HEM, SKIRT_NOTCH = 2.0, 1.36, 1.9
SKIRT_U = (0, 0.05, 0.28, 0.5, 0.78, 0.86, 0.96, 1.0)
SKIRT_T = (0, 0.28, 0.52, 0.76, 0.92, 1.0)


def _panel(k, part, name, s, ys):
	"""One half of the split apron on one leg: a V opens at the centre below the notch, the hem flares, the edge wraps to the side."""

	def point(u, t, off):
		hem = SKIRT_HEM + 0.07 * u
		z = SKIRT_TOP + (hem - SKIRT_TOP) * t
		xw = 1.02 + (SKIRT_TOP - z) * 0.2 - off
		xi = max(0.012, (SKIRT_NOTCH - z) * 0.85)
		d = 0.565 + (SKIRT_TOP - z) * 0.17 - off
		if u <= 0.78:
			x = xi + (xw - xi) * u / 0.78
			y = d + 0.03 * math.sin(u * 19) * t
		else:
			x = xw
			y = d * (1 - 0.9 * (u - 0.78) / 0.22)
		return (s * x, ys * y, z)

	outer = [[point(u, t, 0) for t in SKIRT_T] for u in SKIRT_U]
	inner = [[point(u, t, 0.05) for t in SKIRT_T] for u in SKIRT_U]
	last_c, last_r = len(SKIRT_U) - 2, len(SKIRT_T) - 2
	return _slab(k, part, name, outer, inner, lambda c, r: "trim" if r == last_r or c == last_c or (c == 0 and r >= 1) else "pink")


def _collar_vest(k):
	rows = [(0, 0, 2.06, 1.05, 0.58), (0, 0, 3.86, 1.04, 0.58), (0, 0, 3.97, 0.92, 0.5), (0, 0, 4.02, 0.6, 0.4)]
	k.tube("UpperTorso", "Vest", rows, ("face", "Torso"), corner=0.16, nc=1, outline=0)
	_block(k, "UpperTorso", "Hem", [(0, 0, 1.96, 1.05, 0.59), (0, 0, 1.99, 1.08, 0.615), (0, 0, 2.11, 1.08, 0.615), (0, 0, 2.14, 1.05, 0.59)], "red", corner=0.15, base=0.38, amp=0.3)
	# the neck in the collar's opening
	_box(k, "UpperTorso", "Neck", (0, -0.04, 4.0), (0.5, 0.42, 0.14), "skin", base=0.28, amp=0.1, grad=0)
	c = k.band("UpperTorso", "Collar", (0, -0.02, 3.97), 0.84, 0.68, -62, 242, lambda a: (-0.03, 0.14 - 0.06 * max(0.0, 1 - abs(a + 90 if a < 90 else a - 270) / 60)), "red", thick=0.09, e=0.62, n=18, flare=0.03, outline=0)
	_planes(c, "red", base=0.56, amp=0.34, grad=0.04)
	# the shorts' crotch, filling the gap between the legs under the V
	_box(k, "UpperTorso", "Crotch", (0, 0, 1.68), (0.08, 0.45, 0.32), "shorts", ch=0.02, base=0.2, amp=0.1)
	# the zip: a dark tape, teeth either side of its centre, a slider and its pull
	y = -0.6
	_box(k, "UpperTorso", "ZipTape", (0, y, 3.02), (0.07, 0.022, 0.94), "tape", ch=0.012, base=0.5, amp=0.1)
	teeth = []
	z = 3.92
	i = 0
	while z > 2.12:
		teeth.append(((0.024 * (1 if i % 2 else -1), y - 0.024, z), (0.03, 0.012, 0.019)))
		z -= 0.06
		i += 1
	_cubes(k, "UpperTorso", "ZipTeeth", teeth, "zip", base=0.68, amp=0.25, grad=0)
	_box(k, "UpperTorso", "ZipSlider", (0, y - 0.03, 3.79), (0.06, 0.022, 0.05), "zip", ch=0.01, base=0.75, amp=0.2)
	_box(k, "UpperTorso", "ZipPull", (0, y - 0.05, 3.67), (0.032, 0.012, 0.09), "zip", ch=0.008, base=0.7, amp=0.2)


def _true_face_uv(head):
	"""The face art at its true place on the front: the narrowing jaw crops it. Fitted to each row, it shears nose and mouth."""
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


def _arm(k, s, side):
	part = f"{side}UpperArm"
	x = s * 1.5
	k.reshape(part, f"{side}Arm", [(x, 0, 4.0, 0.44, 0.44), (x, 0, 3.93, 0.5, 0.5), (x, 0, 2.07, 0.5, 0.5), (x, 0, 2.0, 0.44, 0.44)], corner=0.12, nc=1)
	# the elbow guard, chunky, a pale strip round its middle
	_block(k, part, "ElbowGuard", [(x, 0, z, hw, hw) for z, hw in ((3.1, 0.51), (3.14, 0.555), (3.42, 0.555), (3.46, 0.51))], "pink", corner=0.12, base=0.5, amp=0.34)
	_block(k, part, "ElbowStrip", [(x, 0, z, hw, hw) for z, hw in ((3.23, 0.555), (3.25, 0.575), (3.32, 0.575), (3.34, 0.555))], "pink", corner=0.12, base=0.86, amp=0.2)
	# the glove: a plain cuff and a plain hand block as wide as the arm (a hair over, so the arm's faces stay hidden). Owner: no fingers
	_block(k, part, "GloveCuff", [(x + s * 0.02, 0, z, hw, hw) for z, hw in ((2.66, 0.52), (2.7, 0.545), (2.84, 0.545), (2.88, 0.52))], "glove", corner=0.14, base=0.38, amp=0.3)
	_block(k, part, "Hand", [(x, 0, z, hw, hw) for z, hw in ((1.98, 0.44), (2.05, 0.505), (2.72, 0.505))], "glove", corner=0.12, base=0.42, amp=0.34)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	x = s * 0.5
	k.reshape(part, f"{side}Leg", [(x, 0, 2.0, 0.44, 0.47), (x, 0, 1.96, 0.47, 0.5), (x, 0, 0.04, 0.47, 0.5), (x, 0, 0.0, 0.44, 0.47)], corner=0.1, nc=1)
	# shorts with a lip at the hem
	_block(k, part, "Shorts", [(x, 0, z, hw, hd) for z, hw, hd in ((1.18, 0.48, 0.51), (1.2, 0.5, 0.53), (1.25, 0.5, 0.53), (1.27, 0.487, 0.517), (2.0, 0.487, 0.517))], "shorts", corner=0.12, base=0.45, amp=0.34)
	for y, tag in ((-1, "F"), (1, "B")):
		_panel(k, part, "Apron" + tag, s, y)
	# the tall boot: sole, foot, shaft, a folded cuff; the toes come out at the front
	bx = s * 0.52
	_block(k, part, "Sole", [(bx, -0.19, z, hw, hd) for z, hw, hd in ((0.0, 0.5, 0.68), (0.03, 0.525, 0.715), (0.13, 0.525, 0.715), (0.15, 0.5, 0.69))], "sole", corner=0.14, base=0.5, amp=0.4)
	_block(k, part, "Shaft", [(bx, 0.02, z, hw, hd) for z, hw, hd in ((0.1, 0.5, 0.53), (0.74, 0.5, 0.53), (0.76, 0.5, 0.53))], "boot", corner=0.12, base=0.42, amp=0.32)
	_block(k, part, "BootCuff", [(bx, 0.02, z, hw, hd) for z, hw, hd in ((0.74, 0.51, 0.54), (0.78, 0.54, 0.57), (0.94, 0.54, 0.57), (0.98, 0.5, 0.53))], "boot", corner=0.13, base=0.52, amp=0.34)
	_block(k, part, "Instep", [(bx, cy, z, 0.5, hd) for cy, z, hd in ((-0.16, 0.14, 0.45), (-0.16, 0.26, 0.45), (-0.1, 0.42, 0.42), (-0.05, 0.56, 0.42))], "boot", corner=0.14, base=0.5, amp=0.34)
	_box(k, part, "Foot", (bx, -0.62, 0.21), (0.44, 0.15, 0.07), "skin", ch=0.02, base=0.3, amp=0.12, grad=0)
	# four big toes in a row, gaps down to the sole: toes painted by their own planes
	for i in range(4):
		_box(k, part, f"Toe{i}", (bx + (i - 1.5) * 0.222, -0.76, 0.215), (0.103, 0.11, 0.07), "skin", ch=0.03, base=0.62, amp=0.34)


def _wrap(k):
	"""Viewer's left is -X: the bandage and holster go on the right leg."""
	part = "RightUpperLeg"
	x = -0.5
	for tag, z0, z1 in (("A", 1.28, 1.4), ("B", 1.05, 1.17)):
		_block(k, part, "Wrap" + tag, [(x, 0, z, hw, hd) for z, hw, hd in ((z0 - 0.01, 0.5, 0.52), (z0 + 0.01, 0.525, 0.545), (z1 - 0.01, 0.525, 0.545), (z1 + 0.01, 0.5, 0.52))], "white", corner=0.1, base=0.58, amp=0.34)
	# the pouch rides on the outer front of the thigh, in front of the apron's edge
	c = (-1.0, -0.56, 1.4)
	_box(k, part, "Holster", c, (0.23, 0.25, 0.3), "boot", ch=0.04, base=0.36, amp=0.36)
	_box(k, part, "HolsterFlap", (c[0], c[1] - 0.012, 1.63), (0.245, 0.262, 0.1), "boot", ch=0.035, base=0.56, amp=0.36)
	_box(k, part, "HolsterBuckle", (c[0], c[1] - 0.27, 1.56), (0.045, 0.012, 0.04), "zip", ch=0.008, base=0.65, amp=0.2)
	_box(k, part, "HolsterStrapA", (-1.02, -0.4, 1.34), (0.04, 0.2, 0.05), "shorts", ch=0.015, base=0.45, amp=0.3)
	_box(k, part, "HolsterStrapB", (-1.02, -0.4, 1.11), (0.04, 0.2, 0.05), "shorts", ch=0.015, base=0.45, amp=0.3)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_true_face_uv(parts["Head"])
	_build_hair(k)
	_build_band(k)
	_collar_vest(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	_wrap(k)
	finish()


def _stroke(f, pts, w, colour):
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


def _eye(f, cx, cy, sgn):
	"""Sharp: a narrow almond, a big green iris cut by a heavy lash line that runs past the outer corner. sgn +1 = viewer's right."""
	w, up, dn = 31, 13, 10
	i, o = cx - sgn * w / 2, cx + sgn * w / 2
	iy, oy = cy + 4.5, cy - 4
	shape = f"M{i} {iy}Q{cx - sgn * 3} {cy - up - 3} {o} {oy}Q{cx + sgn * 8} {cy + dn + 2} {i} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, "#fbf7f2")
	ix, iy2 = cx - sgn * 1, cy
	f.path(ell(ix, iy2, 9.6, 13), "#1d5a38")
	f.path(ell(ix, iy2, 8.2, 11.4), "#3f9a58")
	f.path(ell(ix, iy2 + 4.4, 6.2, 6.4), "#8ee09a")
	f.path(ell(ix, iy2 - 0.5, 3, 4.6), "#071009")
	f.path(ell(ix - sgn * 2.8, iy2 - 3.6, 1.9, 2.5), "#ffffff")
	f.path(f"M{i} {iy - 8}H{o}V{cy - 3}Q{cx} {cy - 7} {i} {iy}Z", "#20162a", opacity=0.3)
	end_clip(f)
	# the lash line: a wedge, thickest at the outer end, then its flick
	f.path(f"M{i - sgn} {iy + 0.5}Q{cx - sgn * 3} {cy - up - 6} {o + sgn * 5} {oy - 4}L{o + sgn * 2} {oy + 0.5}L{o + sgn * 4} {oy + 3.4}L{o - sgn * 1} {oy + 1.2}Q{cx - sgn * 3} {cy - up + 0.8} {i - sgn} {iy + 0.5}Z", "#1a1020")
	_stroke(f, [(cx - sgn * 5, cy + dn + 1.2), (cx + sgn * 2, cy + dn + 1.6), (cx + sgn * 9, cy + dn - 0.4), (o, oy + 3)], 0.5, "#8a4f43")


def _brow(f, cx, cy, sgn):
	"""Angled: low and thick at the inner end, up to a point at the outer."""
	ix, ox = cx - sgn * 16, cx + sgn * 18
	f.path(f"M{ix} {cy + 9}L{ix + sgn * 1} {cy + 3}Q{cx} {cy - 5} {ox} {cy - 9}Q{cx + sgn * 4} {cy + 1} {ix} {cy + 11}Z", "#d65f8c")
	f.path(f"M{ix} {cy + 11}Q{cx + sgn * 4} {cy + 1} {ox} {cy - 9}", stroke="#a33d68", sw=0.5, opacity=0.8)


def _vest_common(f):
	f.fill(VEST)
	f.soft("M-5-5H26Q18 100 26 205H-5Z", VEST_D, 0.7, 8)
	f.soft("M205-5H174Q182 100 174 205H205Z", VEST_D, 0.7, 8)
	f.soft("M-5 150Q100 180 205 150V205H-5Z", VEST_D, 0.55, 8)
	f.soft("M-5-5H205V18H-5Z", VEST_L, 0.55, 5)


def paint(a):
	R.paint(a)
	# ---- face: the lit side viewer's left, shadow from the hair above and the locks either side
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	f.soft("M-5-5H135V14Q65 8 -5 14Z", SKIN_D, 0.75, 5)
	f.soft("M-5-5H20Q8 60 18 135H-5Z", SKIN_D, 0.55, 5)
	f.soft("M135-5H110Q122 60 112 135H135Z", SKIN_D, 0.65, 5)
	f.soft("M-5 124Q65 142 135 124V140H-5Z", SKIN_D, 0.55, 3)
	for x in (20, 110):
		f.path(ell(x, 86, 14, 7), "#f39a84", opacity=0.28, blur=5)
	for s, x in ((-1, 34), (1, 96)):
		_eye(f, x, 66, s)
		_brow(f, x - s * 1, 46, s)
	# the diamond on the forehead, two planes
	f.path("M65 15L73 29L65 43L57 29Z", "#5338b0")
	f.path("M65 15L73 29L65 29Z", "#7d62dc")
	f.path("M65 29L57 29L65 43Z", "#3f2a8c")
	# nose: its side and underside in shadow
	_stroke(f, [(67, 76), (69.5, 82), (68.5, 88)], 0.9, SKIN_D)
	_stroke(f, [(61, 90), (65, 91.8), (69, 89.6)], 0.7, "#b77a5c")
	# a small smile
	_stroke(f, [(53, 104.5), (58, 107.5), (65, 108.6), (72, 107.5), (78, 103.5)], 0.9, "#7d3f3a")
	f.path(ell(65, 113.5, 6, 1.1), SKIN_D, opacity=0.6, blur=1)
	# ---- the sides under the hair
	for n in ("Head_L", "Head_R"):
		a[n].fill(SKIN_D)
	a["Head_T"].fill("#ea8fb3")
	a["Head_Bo"].fill(SKIN_D)
	# ---- the plate's face, on the free Head_B art: brushed steel, a bevel of light and shade, rivets, the swirl mark
	f = a["Head_B"]
	f.fill("#ea8fb3")
	f.path("M5 5H125V45H5Z", "#b4bbc5")
	f.soft("M5 5H125V19Q65 27 5 21Z", "#eef1f5", 0.9, 3)
	f.soft("M5 45H125V36Q65 32 5 37Z", "#737b87", 0.9, 3)
	f.path("M26 5L34 45L38 45L30 5Z", "#ffffff", opacity=0.3)
	f.path("M96 5L104 45L110 45L102 5Z", "#ffffff", opacity=0.2)
	f.path("M5 42.8H125V45H5Z", "#5d6470")
	for x in (11, 119):
		for y in (12, 38):
			f.path(ell(x, y, 1.6, 3), "#59606b")
			f.path(ell(x - 0.3, y - 0.8, 0.8, 1.4), "#eef1f5")
	village_mark(f, 65.5, 26.5, 8.5, "#2a2e38", light="#f1f4f7")
	# ---- vest: soft fold shading, a yoke seam and side panels, no outline
	f = a["Torso_F"]
	_vest_common(f)
	f.soft("M42 22Q70 18 80 44Q66 72 40 58Z", VEST_L, 0.75, 8)
	f.soft("M158 22Q130 18 120 44Q134 72 160 58Z", VEST_L, 0.6, 8)
	f.soft("M42 170Q68 120 78 74L86 80Q82 128 60 176Z", VEST_D, 0.42, 5)
	f.soft("M158 170Q132 120 122 74L114 80Q118 128 140 176Z", VEST_D, 0.42, 5)
	f.soft("M86 -5H114V205H86Z", VEST_D, 0.5, 3)
	for m in (0, 1):
		xf = (lambda x: x) if m == 0 else (lambda x: 200 - x)
		_stroke(f, [(xf(30), 14), (xf(50), 48), (xf(46), 100), (xf(40), 174)], 0.7, VEST_D)
	f = a["Torso_B"]
	_vest_common(f)
	f.soft("M50 60Q100 40 150 60Q150 120 100 150Q50 120 50 60Z", VEST_L, 0.3, 8)
	# the pale ring on the back
	f.path("M100 62a34 34 0 1 0 0.1 0Z", stroke="#f4ece6", sw=13)
	f.path("M100 62a34 34 0 1 0 0.1 0Z", stroke=VEST_D, sw=1, opacity=0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(VEST)
		f.soft("M-5 110Q50 130 105 110V205H-5Z", VEST_D, 0.6, 8)
	a["Torso_T"].fill(VEST)
	a["Torso_Bo"].fill(VEST_D)
	# ---- limbs: bare skin, shaded top to bottom and under each guard; what is under the shells is never seen
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SKIN)
			f.soft("M72 -5H105V210H78Q88 100 72 -5Z", SKIN_D, 0.65, 8)
			f.soft("M-5 90H105V118Q50 124 -5 118Z", SKIN_D, 0.5, 5)
			f.soft("M-5 142H105V170H-5Z", SKIN_D, 0.3, 8)
			f.soft("M-5 -5H105V10H-5Z", "#ffe6c8", 0.7, 5)
			f = a[f"{side}Leg_{key}"]
			f.fill(SKIN)
			f.soft("M-5 86H105V112Q50 104 -5 112Z", SKIN_D, 0.7, 5)
			f.soft("M74 -5H105V205H80Z", SKIN_D, 0.5, 5)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(shade(SKIN_D, 0.8))
		a[f"{side}Leg_Bo"].fill("#120b18")
