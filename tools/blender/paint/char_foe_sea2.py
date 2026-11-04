# Target look for foe_sea2 "Enelu" (design doc 4.32 and section 5): snug white skullcap with short blond hair under it, thick black
# brows, half-lidded pale eyes, a wide open grin, earlobes hanging to the belly with gold pendants, a blue-grey ring behind the
# head holding four barrel drums, bare muscled trunk, stacked forearm rings (gold and bronze), navy sash with one long end, a blue
# draped wrap, balloon trousers (orange petal panels, dark band, orange dots), blue cuffs, gold anklets, bare feet, a gold
# three-pronged staff. +X is the viewer's right.
import math

from atlas import FACES, INK, SIZE, shade
from leaf_common import ell
from sea_common import arm_muscle, bare_back, bare_side, chest
from sea_style3 import LIGHT, bake, bare_arm, block, gem, head_base, head_sides, jitter, paint_arm, prism, rod
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f6d6b8"
SKIN_D = "#d6a482"
SKIN_L = "#ffeada"
ORANGE = "#f08a1c"
ORANGE_D = "#b0500c"
ORANGE_L = "#ffb65c"
DARK = "#20202e"
DARK_L = "#34344a"
BLOND = "#efca58"
CREAM = "#f3eddc"
DEFAULT = "#14141c"
DRUM_ART = (2, 2, 140, 140)  # px inside Head_B, which the nape hair hides
R = Ramps(
	skin=["#b98a6c", "#e0b090", "#f6d6b8", "#ffeada"],
	cap=["#8f8ca0", "#c6c4d4", "#eeedf4", "#ffffff"],
	hair=["#8e6418", "#c99a2c", "#efca58", "#fbe68c"],
	sash=["#0c1844", "#182a70", "#28459c", "#4c6cc4"],
	wrap=["#0f3048", "#205a78", "#3a809c", "#74b0c2"],
	cuff=["#1c4a78", "#2c70a8", "#4a9ad0", "#90c8ea"],
	gold=["#8c5a08", "#cf9a14", "#f4cc38", "#fff09a"],
	bronze=["#20140e", "#442a1c", "#6a4630", "#94704e"],
	ring=["#465064", "#6e7c94", "#9aa8bc", "#ccd6e2"],
	drum=["#3a1a08", "#6a3612", "#94561e", "#c0803c"],
	rim=["#8a8066", "#c4b998", "#f3eddc", "#ffffff"],
	stud=["#0c0c10", "#1e1e26", "#3a3a48", "#6a6a7c"],
)
HAIR = {"colour": BLOND, "locks": []}
PROPS = []
# the cast's square head with a narrower chin: a long face, the front stays one flat plane
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.58), (0, 0, 4.14, 0.76, 0.76), (0, 0, 4.42, 0.88, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
RING_C = (0.0, 1.12, 5.0)
RING_R = 1.85
DRUM_R = 0.58
DRUM_D = 0.25
TROUSER_X = 0.56


def _cap(k):
	rows = [(0, 0.01, 5.18, 0.93, 0.85), (0, 0.01, 5.5, 0.95, 0.87), (0, 0.02, 5.76, 0.88, 0.8), (0, 0.03, 5.96, 0.68, 0.62), (0, 0.04, 6.08, 0.36, 0.33)]
	o = k.tube("Head", "Cap", rows, "cap", corner=0.42, nc=2, sub=0, outline=0)
	jitter(o, 0.018)
	bake(k, o, "cap", a=0.6, b=0.34, g=0.06)
	# the rolled edge across the forehead, standing proud of the dome
	rows = [(0, 0.01, 5.12, 0.93, 0.85), (0, 0.01, 5.15, 0.955, 0.875), (0, 0.01, 5.3, 0.965, 0.885), (0, 0.01, 5.36, 0.94, 0.86)]
	o = k.tube("Head", "CapEdge", rows, "cap", corner=0.3, nc=1, sub=1, outline=0)
	jitter(o, 0.008)
	bake(k, o, "cap", a=0.46, b=0.42)
	# two loose folds running back over the dome
	for s in (1, -1):
		gem(k, "Head", f"CapFold{s}", (s * 0.56, -0.5, 5.86), (s * 0.3, 0.42, 6.02), 0.13, ramp="cap", flat=0.4, twist=0.1, across=(1, 0, 0), a=0.62, b_=0.34)


def _hair(k):
	"""Short blond hair showing below the cap: at the temples, behind the ears, across the nape."""
	nape = k.tube("Head", "Nape", [(0, 0.42, 5.2, 0.95, 0.46), (0, 0.42, 4.5, 0.95, 0.46), (0, 0.42, 4.08, 0.8, 0.42)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.02)
	bake(k, nape, "hair", a=0.42, b=0.42)
	for s in (1, -1):
		# the temple lock in front of the ear
		gem(k, "Head", f"Temple{s}", (s * 0.8, -0.46, 5.22), (s * 0.99, -0.66, 4.62), 0.27, flat=0.55, twist=0.2, across=(0, 1, 0))
		for i, (y0, y1, z, x1, r) in enumerate(((0.28, 0.34, 4.44, 1.06, 0.26), (0.6, 0.72, 4.34, 1.02, 0.26))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.86, y0, 5.22), (s * x1, y1, z), r, flat=0.45, twist=0.25 + 0.2 * i, across=(0, 1, 0.3))
	for i, (x, x1, z) in enumerate(((-0.62, -0.78, 4.2), (-0.26, -0.3, 4.08), (0.1, 0.16, 4.14), (0.46, 0.62, 4.1), (0.76, 0.9, 4.28))):
		gem(k, "Head", f"Hem{i}", (x, 0.76, 5.16), (x1, 0.98, z), 0.3, flat=0.46, twist=0.3 + 0.1 * i, across=(1, 0, 0))


def _ears(k):
	"""The ear and its lobe: a long flat strap past the jaw and down the chest, a gold cap, a link, the pendant."""
	for s in (1, -1):
		rows = [(s * 0.93, 0.02, 5.0, 0.05, 0.11), (s * 0.97, 0.02, 4.8, 0.08, 0.17), (s * 0.97, -0.02, 4.5, 0.085, 0.14), (s * 0.96, -0.24, 4.24, 0.07, 0.1), (s * 0.88, -0.52, 4.0, 0.07, 0.09), (s * 0.77, -0.6, 3.7, 0.07, 0.07), (s * 0.72, -0.59, 3.3, 0.068, 0.06), (s * 0.7, -0.58, 2.96, 0.062, 0.055)]
		bake(k, k.tube("Head", f"Lobe{s}", rows, "skin", corner=0.4, nc=1, outline=0), "skin", a=0.58, b=0.36)
		block(k, "Head", f"LobeCap{s}", s * 0.7, -0.59, 3.0, 2.9, 0.08, 0.07, "gold", ch=0.02, a=0.62, b=0.38)
		rod(k, "Head", f"Link{s}", (s * 0.7, -0.6, 2.9), (s * 0.7, -0.62, 2.82), 0.025, "gold", n=5, a=0.6, b=0.4)
		cx, cz, r = s * 0.7, 2.69, 0.14
		pts = [(cx + r * math.cos(math.radians(a)), cz + r * math.sin(math.radians(a))) for a in range(0, 360, 60)]
		prism(k, "Head", f"Pendant{s}", pts, -0.68, -0.62, "gold", a=0.62, b=0.4)
		k.blob("Head", f"Stone{s}", (cx, -0.69, cz), (0.07, 0.025, 0.07), "bronze", v=0.5, rings=3, n=8, outline=0)


def _torus(k, part, name, c, big, small, ramp, seg=32, sides=6):
	"""A ring facing the viewer, closed round on itself."""
	rings = []
	for i in range(seg + 1):
		t = 2 * math.pi * (i % seg) / seg
		rows = []
		for j in range(sides):
			p = 2 * math.pi * j / sides
			q = big + small * math.cos(p)
			rows.append((c[0] + q * math.cos(t), c[1] + small * math.sin(p), c[2] + q * math.sin(t)))
		rings.append(rows)
	verts, faces, flat = k._loft(rings, caps=(False, False))
	return bake(k, k._mesh(name, part, verts, faces, flat, outline=0), ramp, a=0.56, b=0.42, g=0.0)


def _drum(k, part, name, c):
	"""A bulged barrel on the y axis: both heads wear the art at DRUM_ART, a pale rim and a stud row round each."""
	cx, cy, cz = c
	n, r, d, head = 14, DRUM_R, DRUM_D, 0.82
	rows = [(-d, head), (-d + 0.02, 1.0), (-d + 0.1, 1.0), (-d * 0.4, 1.13), (d * 0.4, 1.13), (d - 0.1, 1.0), (d - 0.02, 1.0), (d, head)]
	rings = [[(cx + q * r * math.cos(2 * math.pi * j / n), cy + y, cz + q * r * math.sin(2 * math.pi * j / n)) for j in range(n)] for y, q in rows]
	verts, faces, flat = k._loft(rings)
	o = k._mesh(name, part, verts, faces, flat, outline=0)
	x0, y0 = FACES["Head_B"][:2]
	bx, by, bw, bh = DRUM_ART
	rad = head * r
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		lit = poly.normal.x * LIGHT[0] + poly.normal.y * LIGHT[1] + poly.normal.z * LIGHT[2]
		ys = [o.data.vertices[i].co.y - cy for i in poly.vertices]
		cap = len(poly.vertices) > 4
		front, back = cap and poly.normal.y < 0, cap and poly.normal.y > 0
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			if front or back:
				u = (co.x - cx + rad) / (2 * rad)
				uv[li].uv = ((x0 + bx + (1 - u if back else u) * bw) / SIZE, 1 - (y0 + by + (cz + rad - co.z) / (2 * rad) * bh) / SIZE)
			elif min(abs(y) for y in ys) > d - 0.11:
				uv[li].uv = k.R.uv("rim", 0.58 + 0.34 * lit)
			else:
				uv[li].uv = k.R.uv("drum", 0.5 + 0.42 * lit)
	for y, tag in ((-d + 0.06, 0), (d - 0.06, 1)):
		for j in range(10):
			a = 2 * math.pi * (j + 0.5) / 10
			at = (cx + 0.98 * r * math.cos(a), cy + y, cz + 0.98 * r * math.sin(a))
			k.blob(part, f"{name}Stud{tag}{j}", at, (0.05, 0.05, 0.05), "stud", v=0.55, rings=3, n=6, outline=0)


def _drums(k):
	t = "UpperTorso"
	cx, cy, cz = RING_C
	_torus(k, t, "Ring", RING_C, RING_R, 0.095, "ring")
	# the ring is set into the shoulder blades
	low = cz - math.sqrt(RING_R**2 - 0.42**2)
	for s in (1, -1):
		block(k, t, f"Socket{s}", s * 0.42, 0.54, 3.62, 3.14, 0.19, 0.07, "ring", ch=0.03, a=0.5, b=0.42)
		rod(k, t, f"Strut{s}", (s * 0.42, 0.56, 3.38), (s * 0.42, cy, low), 0.08, "ring", n=6, a=0.54, b=0.42)
	for i, (s, deg) in enumerate(((1, 42), (-1, 42), (1, -20), (-1, -20))):
		a = math.radians(deg)
		_drum(k, t, f"Drum{i}", (cx + s * RING_R * math.cos(a), cy, cz + RING_R * math.sin(a)))


def _sash(k):
	"""A thick navy wrap with loose folds: a superellipse section, each row pushed in and out."""
	t = "UpperTorso"
	n = 28
	rows = [(2.1, 0.0), (2.14, 0.03), (2.25, 0.012), (2.36, 0.034), (2.46, 0.016), (2.5, 0.0)]
	rings = []
	for ri, (z, amp) in enumerate(rows):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, s = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.22, c), math.copysign(abs(s) ** 0.22, s)
			fold = amp * (1 + 0.7 * math.sin(j * 0.9 + ri * 1.7))
			ring.append((px * (1.05 + fold), py * (0.57 + fold), z + 0.014 * math.sin(j * 1.3 + ri)))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k, k._mesh("Sash", t, verts, faces, flat, outline=0), "sash", a=0.5, b=0.44, g=0.1)
	# the knot on the viewer-left hip and the start of the long end
	k.blob(t, "SashKnot", (-0.8, -0.64, 2.27), (0.2, 0.09, 0.17), "sash", v=0.62, rings=3, n=7, outline=0)
	o = k.tube(t, "SashStub", [(-0.84, -0.66, 2.24, 0.14, 0.04), (-0.92, -0.72, 2.0, 0.17, 0.04)], "sash", corner=0.3, nc=1, outline=0)
	bake(k, o, "sash", a=0.54, b=0.4)


def _wrap_top(k):
	"""The wrap's waist, under the sash; the panels that fall from it hang on the legs."""
	o = k.tube("UpperTorso", "WrapTop", [(0, 0, 2.16, 1.06, 0.6), (0, 0, 2.02, 1.12, 0.67), (0, 0, 1.92, 1.1, 0.65)], "wrap", corner=0.2, nc=1, sub=1, outline=0)
	jitter(o, 0.012)
	bake(k, o, "wrap", a=0.5, b=0.42)


def _drape(k, part, s):
	"""One leg's panel of the wrap: short over the thigh in front, long at the outside and the back; big folds."""
	n, cx = 18, s * TROUSER_X
	rings = []
	for t in (0.0, 0.3, 0.65, 1.0):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			px, py = math.copysign(abs(c) ** 0.55, c), math.copysign(abs(sn) ** 0.55, sn)
			outer, back = s * c, sn
			hem = 1.66 - 0.5 * max(outer, 0.0) ** 0.7 - 0.62 * max(0.0, min(1.0, (back + 0.15) / 0.3)) + 0.04 * math.sin(5 * a)
			fold = 0.07 * t * math.sin(3 * a + s)
			ring.append((cx + px * (0.6 + 0.12 * t + fold), py * (0.7 + 0.16 * t + fold), 2.0 + (hem - 2.0) * t))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k, k._mesh("Drape", part, verts, faces, flat, outline=0), "wrap", a=0.5, b=0.5, g=0.14)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	bare_arm(k, side, s)
	# stacked forearm rings: gold on the viewer's left, dark bronze on the viewer's right
	ramp = "gold" if s < 0 else "bronze"
	for i, z in enumerate((3.0, 2.87, 2.74, 2.61)):
		block(k, arm, f"Bangle{i}", ax, 0, z, z - 0.115, 0.545, 0.545, ramp, ch=0.03, corner=0.16, a=0.58, b=0.4)


def _staff(k):
	"""Leans out past the viewer-left hand's outer edge; three prongs and a ring at the top."""
	arm = "RightUpperArm"
	b, t = (-1.86, 0.0, 0.2), (-2.38, 0.0, 6.48)
	rod(k, arm, "Staff", b, t, 0.07, "gold", n=6, a=0.58, b=0.44)
	lean = (t[0] - b[0]) / (t[2] - b[2])
	at = lambda z: (b[0] + lean * (z - b[2]), 0.0, z)
	rod(k, arm, "Foot", at(0.2), at(0.12), 0.11, "gold", n=6, r1=0.05, a=0.6, b=0.4)
	for i, (z, r) in enumerate(((1.62, 0.1), (3.0, 0.1), (5.6, 0.11), (5.86, 0.13))):
		rod(k, arm, f"Collar{i}", at(z - 0.05), at(z + 0.05), r, "gold", n=6, a=0.66, b=0.4)
	_torus(k, arm, "StaffRing", at(5.82), 0.3, 0.03, "gold", seg=14, sides=4)
	x = at(6.48)[0]
	prism(k, arm, "Blade", [(x, 6.41), (x + 0.11, 6.58), (x + 0.02, 6.94), (x - 0.11, 6.58)], -0.04, 0.04, "gold", a=0.7, b=0.34)
	for g in (1, -1):
		x0 = at(5.91)[0]
		prism(k, arm, f"Prong{g}", [(x0 + g * 0.03, 5.86), (x0 + g * 0.38, 6.02), (x0 + g * 0.42, 6.78), (x0 + g * 0.3, 6.36), (x0 + g * 0.05, 6.06)], -0.035, 0.035, "gold", a=0.64, b=0.36)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	lx, px = s * 0.5, s * TROUSER_X
	k.reshape(part, f"{side}Leg", [(lx, 0, 0.26, 0.46, 0.46), (lx, 0, 1.4, 0.46, 0.46)], corner=0.14, nc=1)
	# balloon trousers wearing the leg's painted art: z 2.0 is art y 0, z 0.5 is art y 150
	rows = [(px, 0, 1.97, 0.5, 0.54), (px, 0, 1.76, 0.57, 0.66), (px, -0.01, 1.36, 0.68, 0.8), (px, -0.01, 0.96, 0.72, 0.84), (px, 0, 0.72, 0.66, 0.78), (px, 0, 0.56, 0.52, 0.58), (px, 0, 0.5, 0.47, 0.5)]
	o = k.tube(part, "Trousers", rows, ("face", f"{side}Leg"), corner=0.24, nc=1, sub=1, outline=0)
	jitter(o, 0.012)
	_drape(k, part, s)
	block(k, part, "Cuff", lx, 0, 0.56, 0.47, 0.5, 0.52, "cuff", ch=0.015, corner=0.16, a=0.58, b=0.38)
	for i, z in enumerate((0.45, 0.375, 0.3)):
		block(k, part, f"Anklet{i}", lx, 0, z, z - 0.07, 0.49, 0.49, "gold", ch=0.015, corner=0.16, a=0.6, b=0.4)
	# the bare foot: a chunky ramp from the ankle to a forward toe row
	foot = [(lx, -0.17, 0.0, 0.47, 0.62), (lx, -0.17, 0.14, 0.47, 0.62), (lx, -0.12, 0.24, 0.47, 0.56), (lx, -0.03, 0.34, 0.46, 0.47)]
	bake(k, k.tube(part, "Foot", foot, "skin", corner=0.16, nc=1, outline=0), "skin", a=0.6, b=0.34)
	for i in range(4):
		block(k, part, f"Toe{i}", lx - 0.33 + 0.22 * i, -0.8, 0.17, 0.0, 0.095, 0.1, "skin", ch=0.03, a=0.62, b=0.32)
	if side == "Right":
		# the sash's long end, nearly to the ground
		tail = [(-0.92, -0.72, 2.0, 0.17, 0.04), (-1.06, -0.82, 1.62, 0.17, 0.04), (-1.12, -0.86, 1.1, 0.18, 0.04), (-1.12, -0.82, 0.72, 0.18, 0.035)]
		o = k.tube(part, "SashTail", tail, "sash", corner=0.3, nc=1, outline=0)
		bake(k, o, "sash", a=0.46, b=0.42)
		prism(k, part, "SashTip", [(-1.3, 0.72), (-0.94, 0.72), (-0.98, 0.44), (-1.12, 0.56), (-1.26, 0.4)], -0.85, -0.79, "sash", a=0.42, b=0.38)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_hair(k)
	_cap(k)
	_ears(k)
	gem(k, "Head", "Nose", (0, -0.82, 4.88), (0, -0.92, 4.48), 0.075, ramp="skin", flat=0.9, twist=0.0, across=(1, 0, 0), a=0.6, b_=0.3)
	_drums(k)
	k.reshape("UpperTorso", "Torso", [(0, 0, 4.02, 0.92, 0.42), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.2, 1.0, 0.5), (0, 0, 1.94, 0.98, 0.48)], corner=0.1, nc=1)
	block(k, "UpperTorso", "Hips", 0, 0, 2.2, 1.88, 1.02, 0.54, "sash", ch=0.02, a=0.42, b=0.42)
	_wrap_top(k)
	_sash(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	_staff(k)
	finish()


def _drum_art(a):
	"""The drum head: a cream disc, a thin dark ring, four straight-edged swept blades round a hub."""
	f = a["Head_B"]
	f.fill(shade(BLOND, 0.7))
	sx, sy = f.w / FACES["Head_B"][2], f.h / FACES["Head_B"][3]
	bx, by, bw, bh = DRUM_ART
	cx, cy = (bx + bw / 2) * sx, (by + bh / 2) * sy
	rx, ry = bw / 2 * sx, bh / 2 * sy
	f.path(ell(cx, cy, rx, ry), CREAM)
	f.soft(ell(cx + rx * 0.1, cy + ry * 0.12, rx * 0.86, ry * 0.86), "#fffdf4", 0.7, 5)
	f.soft(f"M{cx - rx} {cy + ry * 0.6}Q{cx} {cy + ry * 1.3} {cx + rx} {cy + ry * 0.6}V{cy + ry}H{cx - rx}Z", "#a89c80", 0.5, 5)
	f.path(ell(cx, cy, rx * 0.95, ry * 0.95), stroke="#2a2438", sw=2.0)
	for i in range(4):
		t = math.pi / 2 * i + 0.4
		pts = []
		for ang, q in ((0.0, 0.16), (0.32, 0.86), (1.02, 0.78), (0.56, 0.4)):
			pts.append(f"{cx + rx * q * math.cos(t + ang):.1f} {cy + ry * q * math.sin(t + ang):.1f}")
		f.path("M" + "L".join(pts) + "Z", "#17141f")
	f.path(ell(cx, cy, rx * 0.12, ry * 0.12), "#17141f")


def _eye(f, cx, s):
	"""A half-lidded eye: pale iris, small pupil, the lid cut low and level, a heavy lash line, ticks below. s +1 = viewer's right."""
	ix, ox = cx - s * 19, cx + s * 19
	cy = 62
	shape = f"M{ix} {cy + 3}Q{cx} {cy - 13} {ox} {cy - 3}Q{cx + s * 6} {cy + 12} {ix} {cy + 3}Z"
	f.path(shape, "#fbf8f0")
	f.out.append(f'<clipPath id="lid{s}"><path d="{shape}"/></clipPath><g clip-path="url(#lid{s})">')
	f.path(ell(cx + s * 1, cy + 1, 9.5, 13), "#6f8a9c")
	f.path(ell(cx + s * 1, cy + 1, 8, 11), "#a6c0ce")
	f.path(ell(cx + s * 1, cy + 5, 5, 5), "#d8e8ee")
	f.path(ell(cx + s * 1, cy + 1, 3.6, 5), "#0a0a12")
	f.path(ell(cx + s * 1 - 2.8, cy - 2, 1.6, 2), "#ffffff")
	# the lid: skin over the eye's top, level and heavy
	f.path(f"M{ix - s * 2} {cy - 16}H{ox + s * 2}V{cy - 4}Q{cx} {cy - 4.5} {ix - s * 2} {cy + 0.5}Z", shade(SKIN, 0.86))
	f.out.append("</g>")
	f.path(f"M{ix - s * 2.5} {cy + 3}Q{cx} {cy - 6.5} {ox + s * 3.5} {cy - 5.5}L{ox + s * 1} {cy - 1.5}Q{cx} {cy - 2} {ix - s * 2.5} {cy + 3}Z", INK)
	# the lid fold above, the heavy lower line and its ticks
	f.path(f"M{ix + s * 4} {cy - 9}Q{cx} {cy - 16} {ox} {cy - 11}", stroke=shade(SKIN, 0.58), sw=1.4)
	f.path(f"M{ix + s * 3} {cy + 8}Q{cx + s * 4} {cy + 15} {ox} {cy + 3}", stroke=INK, sw=2.0)
	for dx in (-9, -3, 3, 9, 14):
		y = cy + 11 - abs(dx - 2) * 0.28
		f.path(f"M{cx + s * dx} {y}L{cx + s * (dx + 1)} {y + 5.5}", stroke=INK, sw=1.2)
	# the thick black brow, flat near the nose and lifting out
	bi, bo = 65 + s * 11, 65 + s * 54
	f.path(f"M{bi} 42Q{65 + s * 30} 32 {bo} 30L{bo} 34Q{65 + s * 30} 41 {bi} 50Z", "#0e0c12")


def _face(f):
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=20)
	_eye(f, 35, -1)
	_eye(f, 95, 1)
	# the long thin nose: a shadow down one side of the bridge, one line, a small flat base
	f.soft("M60 46L66 46L71 78Q65 84 58 78Z", SKIN_D, 0.55, 2)
	f.path("M62 48Q61 64 59 77", stroke=shade(SKIN, 0.6), sw=1.3)
	f.path("M58 80Q65 85 72 79", stroke=shade(SKIN, 0.45), sw=1.5)
	# the wide open grin, cheek lines beside it
	f.path("M28 88Q65 100 102 86Q98 110 66 113Q36 112 28 88Z", "#2c0c10", stroke=INK, sw=1.8)
	f.path("M32 90Q65 100 98 88.5L95 96.5Q65 105 35 98Z", "#fdfbf4")
	f.path("M47 95L47.5 100.5M58 96.5L58.5 102M72 96.5L71.5 102M83 94.5L82.5 100", stroke="#7a7482", sw=0.9)
	f.path("M44 108Q65 101 88 107Q66 114 44 108Z", "#a02c34")
	f.path("M28 88Q24 84 23 79", stroke=INK, sw=1.6)
	f.path("M102 86Q106 82 107 77", stroke=INK, sw=1.6)
	f.path("M20 68Q14 84 24 102", stroke=shade(SKIN, 0.68), sw=1.6, opacity=0.8, blur=1)
	f.path("M110 68Q116 84 106 102", stroke=shade(SKIN, 0.68), sw=1.6, opacity=0.8, blur=1)
	# the chin
	f.path("M54 119Q65 122 76 119", stroke=shade(SKIN, 0.55), sw=1.2)


def _petals(f, y0, y1, up, count=5):
	"""A panel of orange petals across the leg from y0 to y1. up False: scalloped lower edge; True: scalloped upper edge."""
	w = 110 / count
	edge, flat = (y0, y1) if up else (y1, y0)
	d = f"M-5 {flat}V{edge}"
	for i in range(count):
		x0 = -5 + i * w
		d += f"Q{x0 + w / 2} {edge + (-1 if up else 1) * w * 0.85} {x0 + w} {edge}"
	d += f"V{flat}Z"
	f.path(d, ORANGE, stroke=ORANGE_D, sw=1.6)
	mid = (y0 + y1) / 2
	f.soft(f"M-5 {y0}H105V{mid}H-5Z" if not up else f"M-5 {mid}H105V{y1}H-5Z", ORANGE_D, 0.4, 5)
	f.soft(f"M16 {y0 + 4}H84V{y1 - 4}H16Z", ORANGE_L, 0.55, 8)
	for i in range(count):
		x = -5 + (i + 0.5) * w
		tip = edge + (-1 if up else 1) * w * 0.2
		f.path(f"M{x} {tip}L{50 + (x - 50) * 0.42} {flat}", stroke=ORANGE_D, sw=1.3, opacity=0.85)
		f.path(f"M{x + 3} {tip}L{50 + (x + 3 - 50) * 0.42} {flat}", stroke=ORANGE_L, sw=0.9, opacity=0.55)
	for i in range(1, count):
		x = -5 + i * w
		f.path(f"M{x} {edge}L{50 + (x - 50) * 0.42} {flat}", stroke=ORANGE_D, sw=2.2, opacity=0.9)


def _trousers(f, dark, s, key):
	f.fill(DARK)
	f.soft("M-5 86H105V126H-5Z", DARK_L, 0.8, 5)
	_petals(f, -5, 72, False)
	_petals(f, 124, 155, True, count=5)
	# the dark band's dots, each with a small light
	for x in (14, 38, 62, 86):
		y = 104 + (3 if x in (38, 62) else 0)
		f.path(ell(x, y, 6.4, 7.6), ORANGE, stroke=ORANGE_D, sw=1.0)
		f.path(ell(x - 1.4, y - 2, 2.2, 2.6), ORANGE_L)
	f.soft("M-5-5H10L6 160H-5Z", DARK, 0.5, 5)
	f.soft("M105-5H90L94 160H105Z", DARK, 0.65, 5)
	if dark:
		f.path("M-5-5H105V158H-5Z", "#1a0c10", opacity=dark)
	# skin under the cuff: the bare ankle
	f.path("M-5 152H105V205H-5Z", SKIN)
	f.soft("M-5 152H105V170H-5Z", SKIN_D, 0.75, 3)


def paint(a):
	R.paint(a)
	_drum_art(a)
	_face(a["Head_F"])
	head_sides(a, SKIN, SKIN_D, hair=BLOND, hair_y=30)
	# the bare, muscled trunk
	f = a["Torso_F"]
	f.fill(SKIN)
	chest(f, SKIN, cx=100, w=1.0, abs_rows=3, deep=1.05)
	f.soft("M-5-5H14L20 205H-5Z", SKIN_D, 0.55, 5)
	f.soft("M205-5H186L180 205H205Z", SKIN_D, 0.65, 5)
	f.soft("M-5-5H205V10Q100 28 -5 10Z", SKIN_D, 0.75, 4)
	# the lobes' shadows on the chest
	for x in (100 - 66, 100 + 80):
		f.soft(f"M{x - 6} 16H{x + 7}L{x + 6} 130H{x - 5}Z", SKIN_D, 0.75, 2)
	bare_back(a["Torso_B"], SKIN, deep=0.4)
	for n in ("Torso_L", "Torso_R"):
		bare_side(a[n], SKIN)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(shade(SKIN, 0.8))
	for side, s in (("Left", 1), ("Right", -1)):
		for key, dark in (("F", 0.0), ("O", 0.15), ("I", 0.4), ("B", 0.3)):
			f = a[f"{side}Arm_{key}"]
			paint_arm(f, SKIN, SKIN_D, SKIN_L, dark)
			arm_muscle(f, side, key, SKIN, y0=0, wrist=172)
			f.path("M-5 172H105V210H-5Z", SKIN)
			f.soft("M-5 182H105V210H-5Z", SKIN_D, 0.4, 3)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		for key, dark in (("F", 0.0), ("O", 0.14), ("I", 0.38), ("B", 0.3)):
			_trousers(a[f"{side}Leg_{key}"], dark, s, key)
		a[f"{side}Leg_T"].fill(DARK)
		a[f"{side}Leg_Bo"].fill(SKIN_D)
