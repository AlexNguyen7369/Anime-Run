# Target look for leaf_hero (design doc section 5): big head, faceted yellow spikes, steel plate band, chunky black jacket
# with ribbed collar and block sleeves, orange panel and trousers, thigh wraps, holster, open-toe boots, no ink outline.
# Colours live in ramps; every garment is a closed solid whose facets take a baked light from _bake. Only the face, the
# plate and the badge disc use painted art.
import math
import random

from atlas import FACES, INK, SIZE, shade
from leaf_style3 import mark
from leaf_common import ell
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#ffd2ae"
SKIN_D = "#e8a980"
DEFAULT = "#f27a14"
R = Ramps(
	hair=["#9c6004", "#d08c08", "#efb80e", "#fcd316", "#ffe628"],
	skin=["#c98560", "#eeb48a", "#ffd2ae", "#ffe2c8"],
	black=["#0d0c12", "#201e27", "#35323f", "#4c4858"],
	orange=["#923a04", "#c9590a", "#e87410", "#f88a1e"],
	white=["#8f909c", "#d8d9e0", "#f4f4f8", "#ffffff"],
	steel=["#59606c", "#8f96a2", "#c2c8d0", "#eef1f4"],
	brown=["#452610", "#6f431e", "#946233", "#b5844e"],
	boot=["#141118", "#29242f", "#3f3849", "#575063"],
	sole=["#0b0a0e", "#19171d", "#2b2830", "#3d3a44"],
	pouch=["#17161b", "#2c2b33", "#44434e", "#5e5d6a"],
)
HAIR = {"colour": "#FFE324", "locks": []}
PROPS = []
LIGHT = (-0.35, -0.6, 0.72)  # the bake's light, matches the key light of the look: upper left, in front
PLATE_T = 66  # art units of Head_B the plate takes; the rest stays neck skin, hidden behind the nape
PLATE_HW, PLATE_TOP, PLATE_BOT = 0.52, 5.445, 5.045
BADGE = (10, 10, 58, 52)  # px inside Head_T for the disc art, under the hair


def _bake(o, ramp, a=0.5, b=0.42, g=0.08, extra=None, light=LIGHT, tone=0.0):
	"""Triangulates, then gives each triangle one light value from its normal, plus a soft gradient by height: hard facets, soft inside."""
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
			layer.data[li].uv = R.uv(ramp, v)
	return o


def _jitter(o, amount):
	"""Pushes every vertex a little, seeded by name, so flat sides break into big planes."""
	rng = random.Random(o.name)
	for v in o.data.vertices:
		v.co.x += rng.uniform(-amount, amount)
		v.co.y += rng.uniform(-amount, amount)
		v.co.z += rng.uniform(-amount, amount) * 0.7
	o.data.update()


def _block(k, part, name, x, y, z1, z0, hw, hd, ramp, ch=0.07, flare=0.0, corner=0.14, jit=0.0, sub=0, shear=0.0, mids=(), **bk):
	"""A chunky chamfered box from z1 down to z0; flare widens the bottom. mids = extra heights, more big planes under jit."""
	rows = [(x, y, z1, hw - ch, hd - ch), (x, y, z1 - ch, hw, hd)]
	rows += [(x, y, m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
	rows += [(x, y, z0 + ch, hw + flare, hd + flare), (x, y, z0, hw + flare - ch, hd + flare - ch)]
	o = k.tube(part, name, rows, ramp, corner=corner, nc=1, sub=sub, outline=0)
	if jit:
		_jitter(o, jit)
	if shear:
		for v in o.data.vertices:
			v.co.z += shear * (v.co.x - x)
		o.data.update()
	return _bake(o, ramp, **bk)


def _gem(k, part, name, b, t, r, ramp="hair", flat=0.8, bend=0.0, twist=0.35, a=0.5, b_=0.62, across=None):
	"""One faceted spike: 6-sided section, wide across, a ridge along it, closed at the root. bend lifts the spine."""
	from mathutils import Vector

	b, t = Vector(b), Vector(t)
	d = (t - b).normalized()
	w = d.cross(Vector((0, 1, 0))) if across is None else Vector(across) - d * d.dot(Vector(across))
	w = w.normalized() if w.length > 0.15 else Vector((1, 0, 0))
	depth = d.cross(w).normalized()
	c = (b + t) / 2 + Vector((0, 0, bend * (t - b).length))
	verts, faces = [], []
	profile = ((0.0, 1.0, 0.0), (0.42, 0.86, twist), (0.75, 0.42, twist * 2))
	for s, rad, tw in profile:
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
	return _bake(o, ramp, a=a, b=b_, g=0.0, extra=lambda co: 0.14 * ((co - b).dot(d) / span - 0.5), light=(-0.72, -0.28, 0.63))


def _xf(o, pivot, rx=0.0, ry=0.0, rz=0.0):
	from mathutils import Euler, Vector

	m = Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix()
	p = Vector(pivot)
	for v in o.data.vertices:
		v.co = p + m @ (v.co - p)
	o.data.update()
	return o


def _plate(k):
	"""The forehead plate, a shallow curve with a real bevel. Its art lives in Head_B, hidden behind the nape."""
	xs = (-1, -0.95, -0.7, -0.35, 0, 0.35, 0.7, 0.95, 1)
	rings, zs = [], (PLATE_TOP, PLATE_TOP - 0.04, PLATE_BOT + 0.04, PLATE_BOT)
	for x in xs:
		y = -0.915 + 0.035 * x * x
		lift = 0.0 if abs(x) == 1 else 0.035
		section = ((y + 0.1, zs[0]), (y, zs[0]), (y - lift, zs[1]), (y - lift, zs[2]), (y, zs[3]), (y + 0.1, zs[3]))
		rings.append([(x * PLATE_HW, sy, sz) for sy, sz in section])
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Plate", "Head", verts, faces, flat, outline=0)
	x0, y0, pw, ph = FACES["Head_B"][:4]
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			u = (co.x + PLATE_HW) / (2 * PLATE_HW)
			t = (PLATE_TOP - co.z) / (PLATE_TOP - PLATE_BOT)
			uv[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 1 + t * PLATE_T * ph / 130) / SIZE)
	return o


def _hair(k):
	# the dome under the spikes
	dome = k.lathe("Head", "Crown", [(0.9, 5.36, 0.5), (1.0, 5.56, 0.5), (0.92, 5.94, 0.5), (0.5, 6.26, 0.5), (0.14, 6.34, 0.5)], "hair", n=10, at=(0, 0.05, 0), squash=0.95, outline=0)
	_bake(dome, "hair", a=0.48, b=0.34)
	root = (0, 0.1, 5.5)

	def out_from(tip, f=0.22):
		return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))

	# the silhouette: broad wedges, going round from lower left to lower right, then behind
	back = (((-1.36, 0.1, 5.48), 0.4), ((-1.22, 0.25, 6.02), 0.42), ((-0.82, 0.32, 6.42), 0.44), ((-0.28, 0.4, 6.72), 0.44), ((0.3, 0.4, 6.76), 0.44), ((0.84, 0.32, 6.4), 0.44), ((1.24, 0.25, 6.04), 0.42), ((1.38, 0.1, 5.56), 0.4), ((0.0, 1.16, 6.26), 0.46), ((-0.72, 1.1, 6.0), 0.44), ((0.72, 1.1, 6.0), 0.44), ((-1.06, 0.96, 5.46), 0.38), ((1.06, 0.96, 5.46), 0.38), ((0.0, 1.28, 5.56), 0.42))
	for i, (tip, r) in enumerate(back):
		_gem(k, "Head", f"Back{i}", out_from(tip), tip, r, bend=0.06, twist=0.3 + 0.13 * i % 0.5)
	mid = (((-1.14, -0.3, 5.68), 0.36), ((-0.62, -0.36, 6.28), 0.42), ((-0.04, -0.4, 6.5), 0.44), ((0.56, -0.36, 6.3), 0.42), ((1.1, -0.3, 5.76), 0.36))
	for i, (tip, r) in enumerate(mid):
		_gem(k, "Head", f"Mid{i}", out_from(tip), tip, r, bend=0.05, twist=0.5 + 0.17 * i)
	# low side spikes angled out beside the band
	for i, (tip, r) in enumerate((((-1.26, -0.34, 5.14), 0.26), ((1.24, -0.34, 5.16), 0.26))):
		_gem(k, "Head", f"Low{i}", (tip[0] * 0.6, tip[1] * 0.9, 5.42), tip, r, twist=0.4)
	# the front row stands up from behind the band, broad wedges with a ridge
	front = (((-0.98, -0.78, 5.96), 0.34), ((-0.48, -0.9, 6.2), 0.36), ((0.04, -0.94, 6.08), 0.36), ((0.52, -0.9, 6.22), 0.36), ((0.98, -0.78, 5.98), 0.34))
	for i, (tip, r) in enumerate(front):
		_gem(k, "Head", f"Front{i}", (tip[0] * 0.82, -0.62, 5.36), tip, r, flat=0.55, twist=0.2 + 0.3 * i % 0.6)
	# nape and its jagged hem
	nape = k.tube("Head", "Nape", [(0, 0.42, 5.16, 0.93, 0.47), (0, 0.42, 4.7, 0.94, 0.48), (0, 0.42, 4.5, 0.8, 0.42)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	_jitter(nape, 0.02)
	_bake(nape, "hair", a=0.46, b=0.36)
	for i, x in enumerate((-0.68, -0.34, 0.0, 0.34, 0.68)):
		_gem(k, "Head", f"NapeS{i}", (x, 0.72, 5.0), (x * 1.06, 0.92, 4.26 + 0.05 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0))
	# sideburns: one broad lock framing the face from the front, a row of locks wide along the head's side
	for s in (1, -1):
		_gem(k, "Head", f"BurnF{s}", (s * 0.8, -0.72, 5.08), (s * 0.85, -0.8, 4.4), 0.17, flat=0.8, twist=0.2, across=(1, 0, 0))
		for i, (y, z0, r) in enumerate(((-0.52, 4.36, 0.26), (-0.2, 4.44, 0.26), (0.12, 4.42, 0.28))):
			_gem(k, "Head", f"Burn{s}{i}", (s * 0.86, y, 5.08), (s * 0.9, y - 0.03, z0), r, flat=0.45, twist=0.25 + 0.2 * i, across=(0, 1, 0))


def _tails(k):
	"""Two cloth strips from a knot at the back of the band, flying to the viewer's right and back; short enough for a rig."""
	_block(k, "Head", "Knot", 0.3, 0.92, 5.38, 5.1, 0.2, 0.08, "black", ch=0.03)
	spines = (((0.3, 0.92, 5.3), (0.9, 1.02, 5.36), (1.3, 1.18, 5.56), (1.82, 1.36, 5.64)), ((0.3, 0.92, 5.18), (0.84, 1.02, 5.08), (1.3, 1.2, 4.92), (1.72, 1.4, 4.74)))
	for i, spine in enumerate(spines):
		from mathutils import Vector

		rings = []
		for j, p in enumerate(spine):
			p = Vector(p)
			hw = (0.11, 0.17, 0.19, 0.2)[j]
			skew = (0, 0.05, -0.04, 0.06)[j]
			# cloth lies roughly vertical, a kink at each joint; thick enough to read as a solid strip
			rings.append([tuple(p + Vector((skew, -0.05, hw))), tuple(p + Vector((skew, 0.05, hw))), tuple(p + Vector((-skew, 0.05, -hw))), tuple(p + Vector((-skew, -0.05, -hw)))])
		verts, faces, flat = k._loft(rings)
		o = k._mesh(f"Tail{i}", "Head", verts, faces, flat, outline=0)
		_bake(o, "black", a=0.5, b=0.38, g=0.04)


def _collar(k):
	"""A thick ribbed roll neck: a solid loft with a rib at every other vertex, low at the front so the chin shows."""
	n, rx, ry = 36, 0.92, 0.88
	rings, rib_of = [], {}
	rows = ((3.82, 1.0, 0), (3.9, 1.09, 0), (None, 1.07, -0.05), (None, 0.95, 0))
	for z, scale, dz in rows:
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, s = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.6, c), math.copysign(abs(s) ** 0.6, s)
			rib = 1.0 if j % 2 else 0.93
			top = 4.13 + 0.2 * (s + 1) / 2 + dz
			ring.append((rx * scale * rib * px, ry * scale * rib * py, z if z is not None else top))
			rib_of[(round(ring[-1][0], 3), round(ring[-1][1], 3))] = 0.14 if j % 2 else -0.2
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	_bake(k._mesh("Collar", "UpperTorso", verts, faces, flat, outline=0), "black", a=0.5, b=0.5, g=0.12, extra=lambda co: rib_of.get((round(co.x, 3), round(co.y, 3)), 0))


def _backplate(k):
	"""The jacket's black back with the large red swirl: art from Torso_B, at 1:1 scale; every other side is plain black."""
	top, bot, hw = 3.94, 2.68, 1.05
	o = k.tube("UpperTorso", "BackPlate", [(0, 0.58, top, hw - 0.03, 0.06), (0, 0.58, top - 0.03, hw, 0.08), (0, 0.58, bot + 0.03, hw, 0.08), (0, 0.58, bot, hw - 0.03, 0.06)], "black", corner=0.3, nc=1, outline=0)
	_bake(o, "black", a=0.5, b=0.42)
	x0, y0, pw, ph = FACES["Torso_B"][:4]
	layer = o.data.uv_layers[0].data
	for poly in o.data.polygons:
		if poly.normal.y > 0.9:
			for li in poly.loop_indices:
				co = o.data.vertices[o.data.loops[li].vertex_index].co
				u, t = (hw - co.x) / (2 * hw), (top - co.z) / (2 * hw)
				layer[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + t * (ph - 4)) / SIZE)


def _jacket(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	_block(k, t, "Yoke", 0, 0, 3.98, 3.4, 1.1, 0.6, "black", ch=0.08, jit=0.02, sub=1, a=0.48, b=0.6)
	_block(k, t, "Panel", 0, 0, 3.46, 2.3, 1.05, 0.55, "orange", ch=0.03, flare=0.03, jit=0.05, mids=(2.95,), a=0.42, b=0.62, g=0.1, tone=0.07)
	_block(k, t, "Waist", 0, 0, 2.34, 2.06, 1.08, 0.58, "black", ch=0.05, a=0.48)
	# the hips belong to the torso: avatar_merge pads a leg group symmetrically round z 1, so a leg vertex above z 2 puts a corner below z 0
	_block(k, t, "Hips", 0, 0, 2.1, 1.88, 1.09, 0.585, "orange", ch=0.02, a=0.42, b=0.66)
	_backplate(k)
	# the zip: black strip, silver rails, alternating teeth
	_block(k, t, "ZipStrip", 0, -0.55, 4.0, 2.26, 0.12, 0.08, "black", ch=0.02, a=0.42)
	_block(k, t, "ZipRail", 0, -0.625, 3.98, 2.3, 0.045, 0.012, "steel", ch=0.004, a=0.5)
	for i in range(22):
		z = 2.36 + i * 0.075
		_block(k, t, f"Tooth{i}", 0.04 if i % 2 else -0.04, -0.635, z + 0.024, z - 0.024, 0.04, 0.014, "white", ch=0.006, a=0.7)
	_block(k, t, "ZipPull", 0, -0.65, 3.98, 3.78, 0.06, 0.02, "steel", ch=0.01, a=0.75)


def _hand(k, arm, x):
	"""Owner: Roblox hands stay one smooth chamfered block, the arm's 1 stud width, no fingers."""
	_block(k, arm, "Hand", x, 0, 2.54, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)


def _sleeve(k, arm, s):
	ax = s * 1.5
	k.reshape(arm, "LeftArm" if s > 0 else "RightArm", [(s * 1.5, 0, 3.9, 0.42, 0.42), (s * 1.5, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	_block(k, arm, "Shoulder", ax, 0, 4.04, 3.0, 0.515, 0.515, "black", ch=0.1, corner=0.18, jit=0.03, sub=1, mids=(3.5,), a=0.5, b=0.62)
	_block(k, arm, "Forearm", ax, 0, 3.08, 2.46, 0.515, 0.515, "black", ch=0.09, corner=0.18, jit=0.03, sub=1, a=0.5, b=0.62)


def _badge(k):
	"""The scroll badge on the viewer's right shoulder: brown strap, round disc with the white swirl."""
	arm = "LeftUpperArm"
	strap = _block(k, arm, "Strap", 1.22, -0.585, 3.76, 3.48, 0.42, 0.06, "brown", ch=0.025, corner=0.3, a=0.6)
	_xf(strap, (1.22, -0.585, 3.62), ry=-22)
	n = 20
	cx, cy, cz, r = 1.42, -0.62, 3.76, 0.27
	rings = []
	for ry, rr in ((0.14, r * 0.92), (0.05, r), (-0.04, r), (-0.06, r * 0.92)):
		rings.append([(cx + rr * math.cos(2 * math.pi * j / n), cy + ry, cz + rr * math.sin(2 * math.pi * j / n)) for j in range(n)])
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Disc", arm, verts, faces, flat, outline=0)
	x0, y0, pw, ph = FACES["Head_T"][:4]
	uv = o.data.uv_layers.new(name="UVMap").data
	bx, by, bw, bh = BADGE
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			if poly.normal.y < -0.9:
				u, t = (co.x - cx + r) / (2 * r), (cz + r - co.z) / (2 * r)
				uv[li].uv = ((x0 + bx + u * bw) / SIZE, 1 - (y0 + by + t * bh) / SIZE)
			else:
				uv[li].uv = R.uv("brown", 0.45 + 0.4 * poly.normal.z)
	_xf(o, (cx, cy, cz), rx=-12)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.5
	px = s * 0.565
	# shrink the plain block inside the trousers so the two legs can stand a hair apart
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	_block(k, leg, "Pants", px, 0, 1.95, 1.14, 0.525, 0.58, "orange", ch=0.04, flare=0.05, corner=0.16, jit=0.06, mids=(1.58,), a=0.42, b=0.66, g=0.1, tone=0.1)
	_block(k, leg, "PantsCuff", px + s * 0.015, 0, 1.24, 0.98, 0.58, 0.64, "orange", ch=0.05, corner=0.16, jit=0.045, a=0.44, b=0.66, tone=0.1)
	# boot: a tall shaft, a heel block, a strap over the instep, a chunky sole past the toes
	_block(k, leg, "BootTop", px, 0.02, 1.12, 0.56, 0.5, 0.56, "boot", ch=0.05, flare=0.025, a=0.58)
	_block(k, leg, "BootLow", px, 0.1, 0.62, 0.14, 0.52, 0.5, "boot", ch=0.05, flare=0.015, a=0.54)
	_block(k, leg, "Instep", px, -0.44, 0.54, 0.26, 0.5, 0.12, "boot", ch=0.04, a=0.58)
	_block(k, leg, "Sole", px, -0.14, 0.17, 0.0, 0.545, 0.78, "sole", ch=0.03, a=0.56)
	# the open front: a skin forefoot and four toes on the sole
	_block(k, leg, "Forefoot", px, -0.64, 0.36, 0.14, 0.47, 0.13, "skin", ch=0.035, a=0.56, b=0.34)
	for i, dx in enumerate((-0.345, -0.115, 0.115, 0.345)):
		_block(k, leg, f"Toe{i}", px + dx, -0.78, 0.31 - 0.012 * abs(i - 1.5 + s * 1.5), 0.15, 0.105, 0.11, "skin", ch=0.03, corner=0.25, a=0.58, b=0.34)


def _thigh(k):
	"""Viewer's left thigh: two white wraps with dark gaps, the pouch strapped on the outer side."""
	leg = "RightUpperLeg"
	px = -0.58
	for i, (z1, z0, ramp, grow) in enumerate(((1.68, 1.5, "white", 0.03), (1.52, 1.42, "black", 0.015), (1.44, 1.26, "white", 0.035), (1.28, 1.18, "black", 0.015))):
		_block(k, leg, f"Wrap{i}", px - 0.03, 0, z1, z0, 0.55 + grow + 0.03, 0.64 + grow + 0.03, ramp, ch=0.02, corner=0.16, shear=0.04, a=0.56 if ramp == "white" else 0.5, b=0.36)
	_block(k, leg, "Pouch", -1.24, -0.2, 1.68, 0.98, 0.2, 0.36, "pouch", ch=0.04, a=0.56)
	_block(k, leg, "PouchFlap", -1.27, -0.22, 1.72, 1.36, 0.2, 0.37, "pouch", ch=0.035, a=0.68)
	_block(k, leg, "PouchStrap", -1.24, -0.2, 1.22, 1.1, 0.21, 0.37, "black", ch=0.01, a=0.4)
	_block(k, leg, "PouchSnap", -1.24, -0.6, 1.5, 1.42, 0.05, 0.02, "steel", ch=0.008, a=0.6)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_block(k, "Head", "Band", 0, 0, 5.48, 5.02, 0.955, 0.885, "black", ch=0.03, corner=0.24, a=0.5, b=0.36)
	_plate(k)
	_tails(k)
	_collar(k)
	_jacket(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm = f"{side}UpperArm"
		_sleeve(k, arm, s)
		_hand(k, arm, s * 1.5)
		_leg(k, side, s)
	_badge(k)
	_thigh(k)
	finish()


# ---- painted parts: the face, the plate, the disc


def _eye(f, cx, cy, s):
	"""Big anime eye, narrowed in x because Head_F stretches across the wide head. s +1 is the eye on the viewer's right."""
	w = 31
	ix, ox = cx - s * w / 2, cx + s * w / 2
	iy, oy = cy + 5, cy - 8
	shape = f"M{ix} {iy}Q{cx - s * 3} {cy - 24} {ox} {oy}Q{ox + s * 1} {cy + 9} {cx + s * 3} {cy + 13}Q{ix + s * 5} {cy + 13} {ix} {iy}Z"
	f.path(shape, "#fffdf8")
	f.out.append(f'<clipPath id="eye{s}"><path d="{shape}"/></clipPath><g clip-path="url(#eye{s})">')
	px, py = cx + s * 0.5, cy - 0.5
	f.path(ell(px, py, 9.4, 13.5), "#10306a")
	f.path(ell(px, py, 8, 11.8), "#2c88ee")
	f.path(ell(px, py + 5, 5, 6), "#8fd4ff")
	f.path(ell(px, py, 3.8, 5.6), "#080710")
	f.path(ell(px - 2.6, py - 4.4, 2.3, 3.2), "#ffffff")
	f.path(f"M{ix} {iy - 3}Q{cx} {cy - 24} {ox} {oy}V{cy - 7}Q{cx} {cy - 13} {ix} {iy - 3}Z", "#203058", opacity=0.3)
	f.out.append("</g>")
	# heavy angled lash line with a wing, thin lower line
	f.path(f"M{ix - s * 2} {iy + 1.5}Q{cx - s * 3} {cy - 29} {ox + s * 4.5} {oy - 5.5}L{ox + s * 0.6} {oy + 3}Q{cx - s * 2} {cy - 18} {ix - s * 2} {iy + 1.5}Z", INK)
	f.path(f"M{ix + s * 6} {cy + 13.6}Q{cx + s * 4} {cy + 15} {ox} {oy + 10}", stroke=shade(SKIN, 0.42), sw=1.2)


def _mouth(f):
	"""The wide toothy grin: dark rim, a band of teeth with a line between the rows."""
	f.out.append('<g transform="translate(65 94) scale(0.8 0.86) translate(-65 -94)">')
	shape = "M36 84Q65 88 94 84Q93 98 81 102Q65 106 49 102Q37 98 36 84Z"
	f.path(shape, "#3a1414", stroke="#3a1414", sw=1.5)
	f.out.append(f'<clipPath id="grin"><path d="{shape}"/></clipPath><g clip-path="url(#grin)">')
	f.path("M32 82H98V110H32Z", "#fbfbf6")
	f.path("M32 94Q65 97 98 94", stroke="#6a4a48", sw=1.1)
	for x in range(40, 94, 8):
		f.path(f"M{x} 82V110", stroke="#a59c9c", sw=0.8)
	f.path("M32 82Q65 88 98 82V85Q65 91 32 85Z", "#b8b3b4", opacity=0.5)
	f.out.append("</g>")
	f.path("M36 84Q34.5 83 33.5 81.5", stroke="#3a1414", sw=1.3)
	f.path("M94 84Q95.5 83 96.5 81.5", stroke="#3a1414", sw=1.3)
	f.soft("M49 106Q65 110 81 106Q65 115 49 106Z", SKIN_D, 0.8, 1)
	f.out.append("</g>")


def _paint_plate(f):
	"""Drawn in plate units, 130 x 48, then stretched down Head_B's top."""
	f.fill(SKIN)
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
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	# soft shading: under the band, the sides of the face, the jaw
	f.soft("M-5-5H135V33Q65 39 -5 33Z", "#d08a60", 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	f.soft("M14 72Q28 66 36 80Q26 92 14 84Z", "#ffb48c", 0.45, 3)
	f.soft("M116 72Q102 66 94 80Q104 92 116 84Z", "#ffb48c", 0.45, 3)
	for s, x in ((-1, 37), (1, 93)):
		_eye(f, x, 58, s)
		# angled yellow brows, inner end low and thick, outer end high under the band
		ib, ob = 65 + s * 9, 65 + s * 46
		f.path(f"M{ib} 45L{ib + s * 2} 38Q{65 + s * 26} 33 {ob} 29L{ob - s * 1.5} 35Q{65 + s * 24} 39 {ib + s * 1} 47Z", "#f8ca24", stroke="#a87410", sw=0.9)
		# three whisker lines on the cheek
		for y0, x1, y1 in ((76, 40, 80), (84, 42, 86), (92, 40, 92)):
			f.path(f"M{65 + s * 56} {y0}Q{65 + s * (56 + x1) / 2} {(y0 + y1) / 2 + 0.6} {65 + s * x1} {y1}", stroke="#5c3a28", sw=1.25)
	# small nose
	f.soft("M59 74L65 68L71 74Q65 80 59 74Z", SKIN_D, 0.75, 1)
	f.path("M60 77Q65 79.5 70 77", stroke=shade(SKIN, 0.5), sw=1.1)
	_mouth(f)
	_paint_plate(a["Head_B"])
	# the back's art: plate height is 120 of these 200 units, the swirl centred in it
	f = a["Torso_B"]
	f.fill("#35323f")
	f.soft("M-5-5H205V40Q100 56 -5 40Z", "#4c4858", 0.7, 5)
	f.soft("M-5 96Q100 110 205 96V205H-5Z", "#201e27", 0.7, 5)
	mark(f, 96, 64, 44, "#f0261a")
	for n in ("Head_L", "Head_R"):
		a[n].fill(SKIN_D)
		a[n].soft("M-5 90H125V135H-5Z", "#cf8d66", 0.6, 3)
	a["Head_Bo"].fill("#cf8d66")
	# the disc art lives in Head_T, hidden under the hair
	f = a["Head_T"]
	f.fill("#ffe324")
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	bx, by, bw, bh = BADGE
	cx, cy, rx, ry = (bx + bw / 2) * sx, (by + bh / 2) * sy, bw / 2 * sx, bh / 2 * sy
	f.path(ell(cx, cy, rx + 1, ry + 1), "#5a361a")
	f.path(ell(cx, cy, rx * 0.93, ry * 0.93), "#f6f4ee")
	f.out.append(f'<g transform="translate({cx} {cy}) scale({rx / 40} {ry / 40})">')
	mark(f, -2, 3, 28, "#26222a")
	f.out.append("</g>")
