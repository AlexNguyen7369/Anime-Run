# Target look for foe_sea2 "Enelu" (design doc 4.26 and section 5): pale, muscular, bare to the waist, snug white headcloth tied at
# the nape, black brows, half-lidded pale eyes, earlobes hanging to the chest with gold pendants, a grey ring on the shoulder blades
# holding four drums round the head, gold armlets, blue sash tied at the right hip with one end almost to the ground, a back
# wrap, baggy orange trousers with black spiked bands, bare feet with gold rings, a gold staff. +X is the viewer's right.
import math

from atlas import FACES, INK, SIZE, shade
from sea_common import arm_muscle, bare_back, bare_side, chest, circle
from sea_style3 import LIGHT, bake, bare_arm, block, eye, gem, head_base, head_sides, jitter, paint_arm, prism, rod
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f6dcc4"
SKIN_D = "#d8ab8c"
SKIN_L = "#ffeedd"
ORANGE = "#f08a1c"
ORANGE_D = "#b85c0c"
ORANGE_L = "#ffae4a"
CREAM = "#f4f0e6"
DEFAULT = "#14141c"
DRUM_ART = (4, 3, 66, 66)  # px inside Head_T, which the headcloth hides
R = Ramps(
	skin=["#b98a6c", "#e2b898", "#f6dcc4", "#ffeedd"],
	cloth=["#9a9488", "#cfc9bb", "#f4f0e6", "#ffffff"],
	sash=["#123a78", "#1d58a8", "#2f7cd0", "#6aaeee"],
	orange=["#8e4406", "#c8680e", "#f08a1c", "#ffae4a"],
	gold=["#8c5a08", "#cf9a14", "#f4cc38", "#fff09a"],
	ring=["#4a4e58", "#7a808c", "#a4aab4", "#d6dae0"],
	drum=["#4c220a", "#7e4014", "#ab6222", "#d48c44"],
	gem=["#620810", "#a8141e", "#e03038", "#ff8a84"],
)
HAIR = {"colour": CREAM, "locks": []}
PROPS = []
# a narrower jaw than the cast's default, the front stays one flat plane
HEAD_ROWS = [(0, 0, 3.98, 0.46, 0.56), (0, 0, 4.14, 0.72, 0.76), (0, 0, 4.42, 0.86, 0.82), (0, 0, 5.3, 0.88, 0.82), (0, 0, 5.56, 0.76, 0.72), (0, 0, 5.62, 0.58, 0.56)]
RING_C = (0.0, 0.78, 5.0)
RING_R = 1.75


def _cloth(k):
	cap = [(0, 0, 5.14, 0.93, 0.86), (0, 0, 5.2, 0.95, 0.88), (0, 0, 5.46, 0.93, 0.86), (0, 0, 5.68, 0.8, 0.74), (0, 0, 5.84, 0.54, 0.5), (0, 0, 5.9, 0.22, 0.2)]
	o = k.tube("Head", "Cap", cap, "cloth", corner=0.3, nc=1, sub=1, outline=0)
	jitter(o, 0.012)
	bake(k, o, "cloth", a=0.56, b=0.34)
	# the cloth falls behind the ears to the nape, its hem cut straight
	o = k.tube("Head", "Drape", [(0, 0.4, 5.2, 0.93, 0.48), (0, 0.42, 4.7, 0.93, 0.47), (0, 0.42, 4.34, 0.8, 0.4), (0, 0.4, 4.26, 0.74, 0.36)], "cloth", corner=0.25, nc=1, sub=1, outline=0)
	jitter(o, 0.012)
	bake(k, o, "cloth", a=0.54, b=0.36)
	# the knot at the nape and its two short ends
	block(k, "Head", "Knot", 0, 0.9, 5.0, 4.76, 0.16, 0.08, "cloth", ch=0.03, a=0.64, b=0.34)
	for s in (1, -1):
		prism(k, "Head", f"KnotEnd{s}", [(s * 0.05, 4.82), (s * 0.24, 4.84), (s * 0.4, 4.2), (s * 0.24, 4.26), (s * 0.12, 4.16)], 0.88, 0.94, "cloth", a=0.58, b=0.34)


def _ears(k):
	for s in (1, -1):
		rows = [(s * 0.9, 0.0, 5.12, 0.06, 0.12), (s * 0.95, 0.0, 4.96, 0.09, 0.2), (s * 0.96, -0.02, 4.7, 0.09, 0.17), (s * 0.95, -0.1, 4.42, 0.09, 0.12), (s * 0.92, -0.4, 4.2, 0.1, 0.11), (s * 0.84, -0.62, 3.98, 0.11, 0.1), (s * 0.8, -0.66, 3.74, 0.13, 0.1)]
		bake(k, k.tube("Head", f"Ear{s}", rows, "skin", corner=0.4, nc=1, outline=0), "skin", a=0.6, b=0.32)
		# the pendant: a flat-topped six-sided gold plate on a short link, a round red stone in it
		cx, cz, r = s * 0.8, 3.48, 0.17
		rod(k, "Head", f"Link{s}", (cx, -0.66, 3.78), (cx, -0.7, 3.62), 0.025, "gold", n=5, a=0.6, b=0.4)
		pts = [(cx + r * math.cos(math.radians(a)), cz + r * math.sin(math.radians(a))) for a in range(0, 360, 60)]
		prism(k, "Head", f"Pendant{s}", pts, -0.74, -0.68, "gold", a=0.62, b=0.4)
		k.blob("Head", f"Stone{s}", (cx, -0.75, cz), (0.075, 0.03, 0.075), "gem", v=0.55, rings=3, n=8, outline=0)


def _torus(k, part, name, c, big, small, ramp, seg=28, sides=6):
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
	return bake(k, k._mesh(name, part, verts, faces, flat, outline=0), ramp, a=0.56, b=0.4, g=0.0)


def _drum(k, part, name, c, r, d):
	"""A short barrel drum on the y axis: both heads wear the art at DRUM_ART, a stud row round each rim."""
	cx, cy, cz = c
	n = 12
	head = 0.84
	rows = [(-d, head), (-d + 0.03, 0.98), (-d * 0.35, 1.1), (d * 0.35, 1.1), (d - 0.03, 0.98), (d, head)]
	rings = [[(cx + q * r * math.cos(2 * math.pi * j / n), cy + y, cz + q * r * math.sin(2 * math.pi * j / n)) for j in range(n)] for y, q in rows]
	verts, faces, flat = k._loft(rings)
	o = k._mesh(name, part, verts, faces, flat, outline=0)
	x0, y0 = FACES["Head_T"][:2]
	bx, by, bw, bh = DRUM_ART
	rad = head * r
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		front = poly.normal.y < -0.95
		back = poly.normal.y > 0.95
		for li in poly.loop_indices:
			co = o.data.vertices[o.data.loops[li].vertex_index].co
			if front or back:
				u = (co.x - cx + rad) / (2 * rad)
				uv[li].uv = ((x0 + bx + (1 - u if back else u) * bw) / SIZE, 1 - (y0 + by + (cz + rad - co.z) / (2 * rad) * bh) / SIZE)
			else:
				uv[li].uv = k.R.uv("drum", 0.5 + 0.4 * (poly.normal.x * LIGHT[0] + poly.normal.y * LIGHT[1] + poly.normal.z * LIGHT[2]))
	for y in (-d + 0.03, d - 0.03):
		for j in range(8):
			a = 2 * math.pi * (j + 0.5) / 8
			k.blob(part, f"{name}Stud{int(y > 0)}{j}", (cx + 1.0 * r * math.cos(a), cy + y * 0.9, cz + 1.0 * r * math.sin(a)), (0.035, 0.035, 0.035), "gold", v=0.6, rings=2, n=5, outline=0)


def _drums(k):
	t = "UpperTorso"
	_torus(k, t, "Ring", RING_C, RING_R, 0.075, "ring")
	# the ring is set into the shoulder blades
	for s in (1, -1):
		block(k, t, f"Socket{s}", s * 0.42, 0.53, 3.58, 3.18, 0.17, 0.06, "ring", ch=0.03, a=0.5, b=0.42)
		rod(k, t, f"Strut{s}", (s * 0.42, 0.52, 3.38), (s * 0.42, RING_C[1] + 0.02, RING_C[2] - math.sqrt(RING_R**2 - 0.42**2)), 0.06, "ring", n=6, a=0.54, b=0.42)
	off = RING_R * math.cos(math.radians(45))
	for i, (sx, sz) in enumerate(((1, 1), (-1, 1), (1, -1), (-1, -1))):
		_drum(k, t, f"Drum{i}", (RING_C[0] + sx * off, RING_C[1], RING_C[2] + sz * off), 0.44, 0.2)


def _waist(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 4.02, 0.92, 0.42), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.2, 1.0, 0.5), (0, 0, 1.94, 0.98, 0.48)], corner=0.1, nc=1)
	block(k, t, "Hips", 0, 0, 2.2, 1.88, 1.02, 0.54, "orange", ch=0.02, a=0.5, b=0.42)
	# the wrap sits under the sash at the back of the hips
	block(k, t, "WrapTop", 0, 0.27, 2.12, 1.86, 1.03, 0.3, "cloth", ch=0.02, a=0.5, b=0.4)
	o = k.tube(t, "Sash", [(0, 0, 2.42, 1.03, 0.55), (0, 0, 2.38, 1.06, 0.58), (0, 0, 2.14, 1.07, 0.59), (0, 0, 2.08, 1.03, 0.55)], "sash", corner=0.14, nc=1, sub=1, outline=0)
	jitter(o, 0.008)
	bake(k, o, "sash", a=0.54, b=0.42)
	# the knot on the right hip and the end that starts down from it
	block(k, t, "SashKnot", -0.74, -0.64, 2.34, 2.08, 0.17, 0.07, "sash", ch=0.04, a=0.66, b=0.36)
	o = k.tube(t, "SashStub", [(-0.78, -0.68, 2.14, 0.13, 0.035), (-0.8, -0.71, 1.92, 0.15, 0.035)], "sash", corner=0.3, nc=1, outline=0)
	bake(k, o, "sash", a=0.56, b=0.36)
	prism(k, t, "SashShort", [(-0.7, 2.14), (-0.56, 2.14), (-0.5, 1.72), (-0.62, 1.78), (-0.7, 1.68)], -0.72, -0.68, "sash", a=0.6, b=0.34)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	bare_arm(k, side, s)
	block(k, arm, "Armlet", ax, 0, 3.3, 3.12, 0.54, 0.54, "gold", ch=0.03, corner=0.16, a=0.6, b=0.38)
	for i, z in enumerate((2.84, 2.68, 2.52)):
		block(k, arm, f"Bangle{i}", ax, 0, z, z - 0.11, 0.535, 0.535, "gold", ch=0.025, corner=0.16, a=0.6, b=0.38)


def _staff(k):
	"""Runs through the outer edge of the right hand, leaning out, a small leaf blade at the top."""
	arm = "RightUpperArm"
	b, t = (-1.72, -0.02, 0.2), (-2.46, -0.02, 5.8)
	rod(k, arm, "Staff", b, t, 0.075, "gold", n=6, a=0.58, b=0.44)
	lean = (t[0] - b[0]) / (t[2] - b[2])
	at = lambda z: (b[0] + lean * (z - b[2]), -0.02, z)
	for i, (z, r) in enumerate(((0.3, 0.11), (2.95, 0.11), (5.4, 0.12), (5.68, 0.14))):
		rod(k, arm, f"Collar{i}", at(z - 0.05), at(z + 0.05), r, "gold", n=6, a=0.66, b=0.4)
	x = at(5.8)[0]
	prism(k, arm, "Blade", [(x - 0.13, 5.84), (x + 0.1, 5.84), (x + 0.03, 6.42), (x - 0.11, 6.44)], -0.05, 0.01, "gold", a=0.72, b=0.32)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	px = s * 0.54
	rows = [(s * 0.5, 0, 2.0, 0.49, 0.52), (s * 0.52, 0, 1.76, 0.5, 0.56), (px + s * 0.03, -0.02, 1.0, 0.56, 0.62), (px + s * 0.03, -0.02, 0.58, 0.54, 0.6), (px, -0.01, 0.42, 0.42, 0.46), (px, 0, 0.34, 0.34, 0.36)]
	k.reshape(part, f"{side}Leg", rows, corner=0.16, nc=1)
	# the wrap's back panel: one on each leg so it swings with the stride
	prism(k, part, "WrapBack", [(s * 0.02, 2.0), (s * 1.04, 2.0), (s * 1.1, 1.3), (s * 0.64, 1.1), (s * 0.06, 1.32)], 0.62, 0.68, "cloth", a=0.56, b=0.32)
	# the bare foot
	block(k, part, "Ankle", px, 0, 0.42, 0.14, 0.36, 0.36, "skin", ch=0.02, a=0.6, b=0.3)
	block(k, part, "Anklet", px, 0, 0.3, 0.2, 0.39, 0.39, "gold", ch=0.02, a=0.62, b=0.38)
	block(k, part, "Foot", px, -0.16, 0.26, 0.0, 0.47, 0.62, "skin", ch=0.07, corner=0.22, a=0.6, b=0.34)
	block(k, part, "FootBand", px, -0.32, 0.24, 0.17, 0.48, 0.07, "gold", ch=0.012, a=0.6, b=0.36)
	for i, dx in enumerate((-0.24, -0.08, 0.08, 0.24)):
		block(k, part, f"Toe{i}", px + dx, -0.78, 0.14, 0.01, 0.006, 0.006, "skin", ch=0.002, a=0.06, b=0.04)
	block(k, part, "ToeRing", px + s * 0.31, -0.68, 0.12, 0.07, 0.1, 0.1, "gold", ch=0.008, a=0.64, b=0.34)
	if side == "Right":
		# the sash's long end, nearly to the ground
		o = k.tube(part, "SashTail", [(-0.8, -0.71, 1.92, 0.15, 0.035), (-0.84, -0.72, 1.3, 0.17, 0.035), (-0.8, -0.71, 0.66, 0.18, 0.035), (-0.84, -0.7, 0.32, 0.14, 0.03)], "sash", corner=0.3, nc=1, outline=0)
		bake(k, o, "sash", a=0.58, b=0.36)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_cloth(k)
	_ears(k)
	# the strong nose stands off the flat face
	gem(k, "Head", "Nose", (0, -0.8, 4.84), (0, -0.97, 4.5), 0.11, ramp="skin", flat=0.9, twist=0.0, across=(1, 0, 0), a=0.6, b_=0.34)
	_drums(k)
	_waist(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	_staff(k)
	finish()


def _drum_art(a):
	"""The drum head: a cream disc with a thin dark rim; four straight-edged swept blades round a small hub."""
	f = a["Head_T"]
	f.fill(CREAM)
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	bx, by, bw, bh = DRUM_ART
	cx, cy = (bx + bw / 2) * sx, (by + bh / 2) * sy
	rx, ry = bw / 2 * sx * 0.92, bh / 2 * sy * 0.92
	f.path(circle(cx, cy, rx, ry), "none", stroke="#2a2438", sw=2.4)
	for i in range(4):
		t = math.pi / 2 * i
		pts = []
		for ang, q in ((0.0, 0.14), (0.0, 0.86), (0.62, 0.84), (0.34, 0.3)):
			pts.append(f"{cx + rx * q * math.cos(t + ang):.1f} {cy + ry * q * math.sin(t + ang):.1f}")
		f.path("M" + "L".join(pts) + "Z", "#2a2438")
	f.path(circle(cx, cy, rx * 0.12, ry * 0.12), "#2a2438")


def _face(f):
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=20)
	for s, x in ((-1, 38), (1, 92)):
		eye(f, x, 66, s, "#a9c8d6", "#57788a", "#e4f2f6", w=30, up=17, down=10, inner=4, outer=-3, wing=2.5, lid=5, ry=10.5)
		# the half-closed lid drawn across the top of the eye, heavy lines under it
		ix, ox = x - s * 16, x + s * 16
		f.path(f"M{ix} 66Q{x} 48 {ox} 58L{ox} 63Q{x} 62 {ix} 69Z", shade(SKIN, 0.9))
		f.path(f"M{ix - s} 69Q{x} 61.5 {ox + s * 2} 62L{ox + s * 2} 58.5Q{x} 57.5 {ix - s} 66Z", INK)
		f.path(f"M{x - s * 12} 81Q{x} 85 {ox} 74", stroke=INK, sw=1.8)
		for dx in (-6, 0, 6, 11):
			f.path(f"M{x + s * dx} {81.5 + (2 if dx < 5 else -1)}L{x + s * (dx + 1)} {86 + (2 if dx < 5 else -1)}", stroke=INK, sw=1.0)
		# short black brows, raised and lazy
		ib, ob = 65 + s * 13, 65 + s * 42
		f.path(f"M{ib} 38Q{65 + s * 26} 26 {ob} 34L{ob} 37Q{65 + s * 26} 33 {ib} 44Z", "#0c0a10")
	f.soft("M58 78L65 58L72 78Q65 86 58 78Z", SKIN_D, 0.6, 2)
	f.path("M58 86Q65 90 72 86", stroke=shade(SKIN, 0.48), sw=1.2)
	# the smirk: a wide thin line lifting on one side, a dent at the corner, a short lip shadow
	f.path("M42 104Q62 109 80 103Q90 100 95 92", stroke=INK, sw=2.1)
	f.path("M95 92L98 88", stroke=INK, sw=1.6)
	f.path("M52 113Q66 117 78 112", stroke=shade(SKIN, 0.6), sw=1.3)


def _trouser_band(f, y):
	"""One black band across the leg with thin spikes up and down."""
	f.path(f"M-5 {y - 2.5}H105V{y + 2.5}H-5Z", INK)
	for i, x in enumerate(range(-4, 106, 11)):
		h = f.rng.uniform(9, 17)
		f.path(f"M{x - 2.2} {y}L{x + f.rng.uniform(-1, 2)} {y - h}L{x + 2.2} {y}Z", INK)
		h = f.rng.uniform(9, 17)
		f.path(f"M{x + 3.3} {y}L{x + 5.5 + f.rng.uniform(-1, 1)} {y + h}L{x + 7.7} {y}Z", INK)


def _trousers(f, dark):
	f.fill(ORANGE)
	f.soft("M26 10H74L80 120H20Z", ORANGE_L, 0.5, 8)
	f.soft("M-5-5H12L6 205H-5Z", ORANGE_D, 0.6, 5)
	f.soft("M105-5H88L94 205H105Z", ORANGE_D, 0.7, 5)
	f.soft("M-5 148H105V205H-5Z", ORANGE_D, 0.5, 8)
	if dark:
		f.path("M-5-5H105V205H-5Z", ORANGE_D, opacity=dark)
	f.folds(4, ORANGE_D, ORANGE_L, y0=0.08, y1=0.8, pinch=(50, 186), width=1.2)
	for y in (34, 86, 138):
		_trouser_band(f, y)


def paint(a):
	R.paint(a)
	_drum_art(a)
	_face(a["Head_F"])
	head_sides(a, SKIN, SKIN_D)
	a["Head_B"].fill(SKIN)
	# the bare, muscled trunk
	f = a["Torso_F"]
	f.fill(SKIN)
	chest(f, SKIN, cx=100, w=1.0, abs_rows=3, deep=0.85)
	f.soft("M-5-5H14L20 205H-5Z", SKIN_D, 0.55, 5)
	f.soft("M205-5H186L180 205H205Z", SKIN_D, 0.65, 5)
	bare_back(a["Torso_B"], SKIN, deep=0.85)
	for n in ("Torso_L", "Torso_R"):
		bare_side(a[n], SKIN)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(shade(SKIN, 0.8))
	for side in ("Left", "Right"):
		for key, dark in (("F", 0.0), ("O", 0.15), ("I", 0.4), ("B", 0.3)):
			f = a[f"{side}Arm_{key}"]
			paint_arm(f, SKIN, SKIN_D, SKIN_L, dark)
			arm_muscle(f, side, key, SKIN, y0=0, wrist=172)
			f.path("M-5 172H105V210H-5Z", SKIN)
			f.soft("M-5 182H105V210H-5Z", SKIN_D, 0.4, 3)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		for key, dark in (("F", 0.0), ("O", 0.12), ("I", 0.35), ("B", 0.28)):
			_trousers(a[f"{side}Leg_{key}"], dark)
		a[f"{side}Leg_T"].fill(ORANGE)
		a[f"{side}Leg_Bo"].fill(ORANGE_D)
