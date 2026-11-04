# Target look for foe_jk (design doc 4.32 and section 5): a volcano for a head with a caramel rim and lava flows over a
# chocolate dome that drips onto a pale blue-white face, one wide lidded eye with a red iris, a wide mouth of black teeth,
# square ear troughs plugged with corks, a huge cream fur collar with black dashes, a coiled black cord at the throat, a
# yellow-green cape with black blotches over a short-sleeved dark tunic, balloon trousers gathered under the knee, brown
# boots with red soles and heels. On the standard block body: the source's squat stoop is not modelled. No marks: the
# blotches, drips and dashes are cloth and skin. Drawn in-house. +X is the viewer's right in the front view.
import math
import random

from atlas import shade
from jk_style3 import Kit, bake, block, finish, gem, jitter, stroke, torso_core
from leaf_common import ell
from style2 import Ramps

SKIN = "#dbe4e9"
SKIN_D = "#9fb0bb"
LINE = "#1c1a20"
CAPE = "#bccb58"
CAPE_D = "#8a9644"
CAPE_L = "#d6de74"
BLOT = "#24262b"
TUNIC = "#2a2c3a"
DEFAULT = TUNIC
R = Ramps(
	skin=["#8d9da8", "#b5c4cd", SKIN, "#f0f5f7"],
	dome=["#24100a", "#43200f", "#6a3018", "#8c4524"],
	rim=["#5e3518", "#8e5a2e", "#b27a4a", "#d29a64"],
	fur=["#a8a288", "#d2ccb0", "#f0ebd6", "#fbf8ea"],
	cork=["#4e2412", "#7a3a1c", "#a4562e", "#c67a4a"],
	tunic=["#0c0c12", "#16171f", TUNIC, "#363848"],
	navy=["#14151f", "#23253a", "#383b52", "#50546e"],
	boot=["#1c0e08", "#341a10", "#4e2a1a", "#6e4028"],
	sole=["#5a0e0e", "#8e1616", "#b82020", "#dc3a30"],
)
HAIR = {"colour": SKIN, "locks": []}
PROPS = []
# a rotund face narrowing to a small chin; art stays inside Head_F's z 4.0-5.3
HEAD_ROWS = [(0, 0, 3.98, 0.52, 0.62), (0, 0, 4.14, 0.76, 0.8), (0, 0, 4.44, 0.96, 0.84), (0, 0, 5.2, 0.98, 0.85), (0, 0, 5.32, 0.94, 0.8)]


def _rad(theta, rx, ry, e):
	"""A point on a superellipse. theta is degrees round from the front (-y) towards +x; e near 0 is square, 1 round."""
	a = math.radians(theta)
	s, c = math.sin(a), math.cos(a)
	return rx * math.copysign(abs(s) ** e, s), -ry * math.copysign(abs(c) ** e, c)


def _lerp(table, t):
	for (t0, v0), (t1, v1) in zip(table, table[1:]):
		if t <= t1:
			return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
	return table[-1][1]


# ---- the volcano

# z, hw, hd, roundness: starts square on the square head, so no corner sticks out as a hat brim, and rounds off as it rises
DOME = ((5.28, 0.985, 0.86, 0.0), (5.52, 0.97, 0.84, 0.3), (5.74, 0.88, 0.78, 0.7), (5.92, 0.66, 0.6, 1.0), (6.04, 0.43, 0.41, 1.0))
# how far each tongue of lava hangs below the dome's edge, walking round from the front
DRIPS = (0.17, 0.07, 0.13, 0.04, 0.16, 0.08, 0.2, 0.05, 0.14, 0.03, 0.17, 0.07, 0.12, 0.05, 0.18, 0.08, 0.14, 0.04, 0.16, 0.06, 0.19, 0.05, 0.13, 0.08, 0.17, 0.04, 0.12, 0.07)


def _rect(t, hw, hd):
	"""A point on a rectangle's edge, t 0..1 walking evenly round from the middle of the front towards +x."""
	per = 4 * (hw + hd)
	d = (t % 1) * per
	for dx, dy, length in ((1, 0, hw), (0, 1, 2 * hd), (-1, 0, 2 * hw), (0, -1, 2 * hd), (1, 0, hw)):
		if d <= length:
			break
		d -= length
	x, y = {(1, 0, hw): (0, -hd), (0, 1, 2 * hd): (hw, -hd), (-1, 0, 2 * hw): (hw, hd), (0, -1, 2 * hd): (-hw, hd)}.get((dx, dy, length), (-hw, -hd))
	return x + dx * d, y + dy * d


def _dome(k):
	n = 28
	rings = []
	for z, hw, hd, m in DOME:
		ring = []
		for i in range(n):
			x, y = _rect(i / n, hw, hd)
			# the same walk on an ellipse, so the two blend vertex for vertex
			rl = math.hypot(x / hw, y / hd)
			ring.append((x * (1 - m) + x / rl * m, y * (1 - m) + y / rl * m, z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Dome", "Head", verts, faces, flat, outline=0)
	jitter(o, 0.012)
	# darker towards the rim, redder at the hairline, as painted in the source
	bake(o, "dome", k, a=0.36, b=0.3, g=-0.3)
	n = len(DRIPS) * 3
	top, low = [], []
	for i in range(n):
		x, y = _rect(i / n, 0.995, 0.868)
		top.append((x, y, 5.32))
		# each tongue is a rounded wedge: its own depth at the centre, little at the shoulders
		low.append((x, y, 5.2 - DRIPS[i // 3] * (0.35, 1.0, 0.55)[i % 3]))
	verts, faces, flat = k._loft([top, low])
	bake(k._mesh("Drips", "Head", verts, faces, flat, outline=0), "dome", k, a=0.5, b=0.22, g=0.0)


def _rim(k):
	"""The pot-like mouth flared above a narrow neck, its inside falling away dark."""
	rows = [(0, 0, 5.94, 0.42, 0.4), (0, 0, 6.06, 0.41, 0.39), (0, 0, 6.2, 0.58, 0.55), (0, 0, 6.34, 0.6, 0.57), (0, 0, 6.37, 0.45, 0.42), (0, 0, 6.14, 0.33, 0.3)]
	o = k.tube("Head", "Rim", rows, "rim", corner=0.7, nc=1, sub=1, outline=0)
	jitter(o, 0.01)
	inner = lambda co: -0.75 if 6.13 < co.z < 6.34 and max(abs(co.x) / 0.45, abs(co.y) / 0.42) < 1.0 else 0.0
	bake(o, "rim", k, a=0.58, b=0.34, g=0.08, extra=inner)
	# the crater is dark at rest: it only erupts in rage
	o = k.lathe("Head", "Crater", [(0.36, 6.14, 0.5), (0.01, 6.14, 0.5)], "ink", n=8, outline=0)
	bake(o, "ink", k, a=0.5, b=0.0)


def _flow(k, name, theta, z1, w):
	"""One wide tongue following the dome from the rim to z1, round-ended: the source's lava is not a spike."""
	a = math.radians(theta)
	dx, dy = math.sin(a), -math.cos(a)
	tx, ty = -dy, dx
	rings = []
	for f, wide in ((0.0, 1.05), (0.3, 1.0), (0.62, 0.96), (0.86, 0.86), (1.0, 0.45)):
		z = 6.2 + (z1 - 6.2) * f
		hw = _lerp([(r[0], r[1]) for r in DOME], max(z, DOME[0][0]))
		hd = _lerp([(r[0], r[2]) for r in DOME], max(z, DOME[0][0]))
		neck = max(0.0, (z - 6.04) / 0.16)
		c = (dx * (hw + 0.2 * neck), dy * (hd + 0.2 * neck))
		ring = []
		for u, v in ((-1, 0), (-0.5, 1), (0.5, 1), (1, 0), (0.5, -1), (-0.5, -1)):
			ring.append((c[0] + tx * w * wide * u + dx * 0.06 * v, c[1] + ty * w * wide * u + dy * 0.06 * v, z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh(name, "Head", verts, faces, flat, outline=0), "rim", k, a=0.54, b=0.4, g=0.1)


def _flows(k):
	for i, (theta, z1, w) in enumerate(((-44, 5.64, 0.17), (-10, 5.5, 0.18), (28, 5.58, 0.17), (64, 5.68, 0.15), (106, 5.58, 0.16), (146, 5.64, 0.17), (186, 5.52, 0.18), (226, 5.62, 0.17), (272, 5.58, 0.16))):
		_flow(k, f"Flow{i}", theta, z1, w)


def _cork(k, s):
	"""The square ear trough is a pale strip flat on the head; a stubby two-tone cork leans out of it."""
	for name, ramp, rows, a, bk in (
		("Trough", "skin", ((0.97, 0.3, 0.36), (1.08, 0.29, 0.35)), 0.62, 0.3),
		("Cork", "cork", ((1.05, 0.21, 0.27), (1.22, 0.23, 0.29), (1.25, 0.24, 0.3), (1.36, 0.25, 0.3), (1.39, 0.22, 0.27)), 0.5, 0.42),
	):
		rings = []
		for x, hy, hz in rows:
			zc = 4.74 - 0.14 * (x - 1.0)
			rings.append([(s * x, hy * p, zc + hz * q) for p, q in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
		verts, faces, flat = k._loft(rings)
		bake(k._mesh(f"{name}{s}", "Head", verts, faces, flat, outline=0), ramp, k, a=a, b=bk)


def _head(k):
	k.reshape("Head", "Head", HEAD_ROWS, corner=0.12, nc=1, fit=True, flat_front=True)
	_dome(k)
	_rim(k)
	_flows(k)
	for s in (1, -1):
		_cork(k, s)


# ---- the fur collar

# how high the fur stands, by degrees from the front: a notch for the cord, up the jaw, under the corks, then a fat roll behind
FUR_TOP = ((0, 3.72), (20, 4.14), (50, 4.52), (80, 4.5), (105, 4.86), (125, 5.3), (150, 5.5), (180, 5.52))
FUR_RO = ((0, 0.8), (22, 0.96), (90, 1.04), (135, 1.04), (180, 1.06))
FUR_N = 32


def _fur_section(theta):
	"""The collar's section at theta: inner foot, outer foot, bulge, shoulder, crest, inner lip. A fat roll, not a wall."""
	t = min(theta % 360, 360 - theta % 360)
	top = _lerp(FUR_TOP, t)
	k_ = _lerp(FUR_RO, t)
	zb = 3.56
	out = lambda f, h: (*_rad(theta, 1.03 + (1.62 * k_ - 1.03) * f, 0.91 + (1.28 * k_ - 0.91) * f, 0.2 + 0.55 * f), zb + h * (top - zb))
	return [(*_rad(theta, 1.03, 0.91, 0.2), zb), out(0.92, 0.0), out(1.0, 0.38), out(0.86, 0.72), out(0.7, 0.94), out(0.34, 1.0), (*_rad(theta, 1.03, 0.91, 0.2), top - 0.1)]


def _fur(k):
	rings = [_fur_section(360 * i / FUR_N) for i in range(FUR_N)]
	rings.append(rings[0])
	verts, faces, flat = k._loft(rings, caps=(False, False))
	o = k._mesh("Fur", "UpperTorso", verts, faces, flat, outline=0)
	jitter(o, 0.03)
	bake(o, "fur", k, a=0.58, b=0.32, g=0.08, tone=0.015)
	# low tufts roughen the crest and the foot; the mass stays one plush roll
	for i in range(14):
		theta = 24 + i * (312 / 13)
		p = _fur_section(theta)
		a = math.radians(theta)
		rx, ry = math.sin(a), -math.cos(a)
		gem(k, "UpperTorso", f"Crest{i}", p[4], (p[4][0] + rx * 0.16, p[4][1] + ry * 0.16, p[4][2] + 0.06), 0.17, "fur", flat=0.55, twist=0.2 + 0.3 * (i % 3), a=0.6, b_=0.32, across=(-ry, rx, 0))
	for i in range(14):
		theta = 14 + i * (332 / 13)
		p = _fur_section(theta)
		a = math.radians(theta)
		rx, ry = math.sin(a), -math.cos(a)
		gem(k, "UpperTorso", f"Foot{i}", p[1], (p[1][0] + rx * 0.08, p[1][1] + ry * 0.08, p[1][2] - 0.1 - 0.04 * (i % 2)), 0.2, "fur", flat=0.55, twist=0.3, a=0.5, b_=0.32, across=(-ry, rx, 0))
	_dashes(k)


# theta, height up the wall (0 bulge, 1 crest), lean of the line
DASHES = ((42, 0.2, 0.5), (58, 0.7, -0.4), (72, 0.3, 0.6), (84, 0.8, 0.5), (98, 0.3, -0.5), (118, 0.2, 0.3), (126, 0.65, -0.2), (140, 0.3, 0.2), (152, 0.7, 0.3), (168, 0.25, -0.3), (176, 0.75, 0.2))


def _dashes(k):
	"""The short black fur lines of the source, each a thin bar standing just proud of the wall."""
	for i, (theta, f, lean) in enumerate(DASHES + tuple((360 - t, f, -l) for t, f, l in DASHES)):
		p = _fur_section(theta)
		c = [p[2][j] + (p[4][j] - p[2][j]) * f for j in range(3)]
		rl = math.hypot(c[0], c[1])
		nx, ny = c[0] / rl, c[1] / rl
		tx, ty = -ny, nx
		h, w, d = 0.09, 0.014, 0.035
		ring = lambda z, off: [(c[0] + nx * d * q + tx * (off + w * p_), c[1] + ny * d * q + ty * (off + w * p_), z) for p_, q in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
		verts, faces, flat = k._loft([ring(c[2] - h, -lean * h), ring(c[2] + h, lean * h)])
		bake(k._mesh(f"Dash{i}", "UpperTorso", verts, faces, flat, outline=0), "ink", k, a=0.5, b=0.0)


def _cord(k):
	"""The coiled black cord that closes the cape at the throat: tight stacked turns, widest in the middle."""
	for i, (z, hw) in enumerate(((3.97, 0.09), (3.88, 0.12), (3.79, 0.15), (3.7, 0.15), (3.61, 0.13), (3.52, 0.1))):
		block(k, "UpperTorso", f"Coil{i}", 0, -1.04 - 0.008 * i, z + 0.05, z - 0.05, hw, 0.08, "tunic", ch=0.025, corner=0.4, a=0.42 + 0.06 * (i % 2), b=0.5)


# ---- clothes


def _torso(k):
	t = "UpperTorso"
	torso_core(k)
	block(k, t, "Tunic", 0, 0, 3.3, 2.04, 1.04, 0.55, "tunic", ch=0.03, flare=0.03, jit=0.03, mids=(2.7, 2.35), a=0.46, b=0.6, tone=0.05)
	block(k, t, "Waist", 0, 0, 2.16, 1.92, 1.1, 0.6, "navy", ch=0.03, jit=0.015, a=0.42, b=0.56)
	# the cape wears the torso art, dipping to a shallow point at the front hem
	rows = [(0, 0, 4.0, 0.98, 0.62), (0, 0, 3.76, 1.09, 0.74), (0, 0, 3.2, 1.15, 0.82), (0, 0, 2.74, 1.2, 0.87)]
	o = k.tube(t, "Cape", rows, ("face", "Torso"), corner=0.16, nc=1, sub=1, outline=0)
	for v in o.data.vertices:
		if v.co.z < 2.8 and v.co.y < 0:
			v.co.z -= 0.2 * max(0.0, 1 - abs(v.co.x) / 1.2)
	o.data.update()
	_fur(k)
	_cord(k)


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 3.3, 2.46, 0.55, 0.55, "tunic", ch=0.05, flare=0.02, corner=0.18, jit=0.025, a=0.46, b=0.6, tone=0.04)
	block(k, arm, "Forearm", ax, 0, 2.56, 2.0, 0.5, 0.5, "skin", ch=0.04, a=0.44, b=0.3)
	block(k, arm, "Hand", ax, 0, 2.08, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.46, b=0.3)
	# the cape's shoulder, on the arm so it swings with it; at rest it runs on from the torso's cape
	rows = [(ax - s * 0.14, 0, 4.04, 0.34, 0.42), (ax - s * 0.04, 0, 3.86, 0.5, 0.6), (ax + s * 0.02, 0, 3.4, 0.68, 0.78), (ax + s * 0.04, 0, 2.84, 0.76, 0.86)]
	k.tube(arm, "CapeCap", rows, ("face", side + "Arm"), corner=0.18, nc=1, sub=1, zig=0.03, outline=0)


def _leg(k, side, s):
	leg, x, px = f"{side}UpperLeg", s * 0.5, s * 0.58
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# balloon trousers, widest at the knee, gathered hard to a cuff
	rows = [(px, 0, 1.97, 0.5, 0.58), (px, 0, 1.56, 0.57, 0.7), (px, 0, 1.12, 0.62, 0.78), (px, 0, 0.86, 0.6, 0.74), (px, 0, 0.68, 0.46, 0.52), (px, 0, 0.6, 0.44, 0.49)]
	o = k.tube(leg, "Balloon", rows, "navy", corner=0.25, nc=1, sub=1, outline=0)
	jitter(o, 0.03)
	bake(o, "navy", k, a=0.5, b=0.56, tone=0.05)
	bx = s * 0.52
	block(k, leg, "Shaft", bx, 0, 0.68, 0.34, 0.43, 0.47, "boot", ch=0.03, jit=0.012, a=0.56)
	block(k, leg, "Strap", bx, 0, 0.36, 0.28, 0.455, 0.495, "tunic", ch=0.02, a=0.4)
	block(k, leg, "Shoe", bx, -0.04, 0.3, 0.08, 0.47, 0.54, "boot", ch=0.05, a=0.58)
	block(k, leg, "Toe", bx, -0.48, 0.22, 0.08, 0.42, 0.28, "boot", ch=0.07, corner=0.35, a=0.66)
	block(k, leg, "Sole", bx, -0.12, 0.09, 0.0, 0.48, 0.68, "sole", ch=0.025, a=0.54)
	block(k, leg, "Heel", bx, 0.42, 0.16, 0.0, 0.36, 0.13, "sole", ch=0.02, a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	_head(k)
	_torso(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _blotch(f, cx, cy, r, sx=1.0):
	"""One irregular black patch, its edge wandering, the same each build."""
	n = 9
	pts = []
	for i in range(n):
		a = 2 * math.pi * i / n
		rr = r * f.rng.uniform(0.74, 1.18)
		pts.append((cx + rr * math.cos(a) * sx, cy + rr * math.sin(a) * 0.95))
	d = f"M{(pts[0][0] + pts[-1][0]) / 2:.1f} {(pts[0][1] + pts[-1][1]) / 2:.1f}"
	for i, p in enumerate(pts):
		q = pts[(i + 1) % n]
		d += f"Q{p[0]:.1f} {p[1]:.1f} {(p[0] + q[0]) / 2:.1f} {(p[1] + q[1]) / 2:.1f}"
	f.path(d + "Z", BLOT)


def _cape(f, bottom, spots, sx):
	"""Cape cloth to the hem with big soft folds; the block's art below it never shows."""
	f.fill(SKIN if "Arm" in f.name else TUNIC)
	f.path(f"M-5-5H{f.w + 5}V{bottom}H-5Z", CAPE)
	f.soft(f"M-5 {bottom - 26}H{f.w + 5}V{bottom}H-5Z", CAPE_D, 0.8, 5)
	f.soft(f"M-5-5H{f.w * 0.1}V{bottom}H-5Z", CAPE_D, 0.45, 5)
	f.soft(f"M{f.w + 5}-5H{f.w * 0.9}V{bottom}H{f.w + 5}Z", CAPE_D, 0.6, 5)
	f.soft(f"M{f.w * 0.2}-5H{f.w * 0.8}V{bottom * 0.2}H{f.w * 0.2}Z", CAPE_L, 0.5, 6)
	for x, y, r in spots:
		_blotch(f, x, y, r, sx)


TORSO_SPOTS = ((22, 34, 11), (150, 26, 12), (178, 66, 11), (44, 72, 13), (128, 62, 9), (70, 40, 7), (20, 108, 10), (68, 112, 17), (128, 112, 20), (170, 118, 11), (96, 128, 8), (46, 138, 8))
BACK_SPOTS = ((30, 28, 12), (90, 20, 9), (150, 34, 15), (60, 66, 16), (118, 74, 11), (176, 74, 12), (24, 96, 10), (88, 112, 19), (150, 118, 14), (40, 132, 9))
SIDE_SPOTS = ((26, 34, 11), (70, 60, 13), (30, 92, 9), (72, 114, 14))
ARM_F_SPOTS = ((20, 22, 8), (70, 30, 11), (30, 70, 13), (76, 92, 12), (36, 112, 8))
ARM_O_SPOTS = ((34, 26, 10), (74, 58, 13), (26, 86, 12), (62, 116, 9))
ARM_B_SPOTS = ((60, 20, 9), (28, 54, 13), (74, 84, 12), (30, 114, 10))
ARM_I_SPOTS = ((30, 24, 8), (70, 64, 9), (34, 104, 10))


def _face(f):
	f.fill(SKIN)
	# blue-grey shade down the cheeks and under the dome, soft inside hard planes
	f.soft("M-5 18H135V34Q65 26 -5 34Z", SKIN_D, 0.75, 3)
	f.soft("M-5 30H8Q6 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H122Q124 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M36 124Q65 116 94 124V135H36Z", SKIN_D, 0.6, 3)
	f.soft("M44 72Q65 84 86 72L80 90Q65 84 50 90Z", SKIN_D, 0.45, 3)
	# stray drops of lava under the dome's edge
	for x, y, rx, ry in ((14, 30, 5, 3.4), (116, 32, 5.5, 3.6), (30, 25, 3.6, 2.6), (100, 26, 3.4, 2.4), (8, 42, 3.2, 3), (122, 44, 3.6, 3.2)):
		f.path(ell(x, y, rx, ry), "#5a2a16")
	# the wide eye: a heavy lid fold above, a white lens, a small red iris pressed up under the lid
	f.soft(ell(65, 53, 50, 19), SKIN_D, 0.5, 3)
	f.path("M16 54Q65 22 114 54Q65 40 16 54Z", shade(SKIN_D, 0.82))
	f.path("M24 55Q65 36 106 55Q65 73 24 55Z", "#f6f2ea", stroke=LINE, sw=2.2)
	f.path("M26 54Q65 37 104 54Q65 46 26 54Z", shade(SKIN_D, 0.72), opacity=0.8)
	f.path(ell(65, 49.5, 8.5, 5.4), "#c8201c", stroke="#3a0c0c", sw=1.2)
	f.path(ell(65, 49.5, 3.4, 3.8), "#180808")
	stroke(f, "M16 54Q65 22 114 54", LINE, 2.4)
	stroke(f, "M24 55L12 52M106 55L118 52", LINE, 1.8)
	# the lower lid folds, one inside the next
	stroke(f, "M34 66Q65 80 96 66", LINE, 1.5)
	stroke(f, "M46 76Q65 84 84 76", shade(SKIN_D, 0.55), 1.4)
	# fine hatching at the temples
	for x0, s in ((9, 1), (121, -1)):
		for i, y in enumerate((62, 68, 74)):
			stroke(f, f"M{x0} {y}L{x0 + s * (8 + i * 2)} {y + 2}", shade(SKIN_D, 0.5), 1)
	# the wide grin of black teeth, its corners hooked up
	stroke(f, "M42 88Q65 94 88 88", shade(SKIN_D, 0.55), 1.3)
	f.path("M20 92Q65 104 110 92Q96 122 65 123Q34 122 20 92Z", "#101016", stroke=LINE, sw=1.6)
	f.path("M26 96Q65 106 104 96Q97 110 65 112Q33 110 26 96Z", "#2c2d36")
	for x in (36, 45, 55, 65, 75, 85, 94):
		stroke(f, f"M{x} {100 + (65 - abs(x - 65)) * 0.05:.1f}V{112 - abs(x - 65) * 0.12:.1f}", "#8a8d98", 0.9)
	stroke(f, "M28 101Q65 110 102 101", "#8a8d98", 0.9)
	stroke(f, "M14 86L20 92M116 86L110 92", LINE, 1.8)
	stroke(f, "M50 127Q65 130 80 127", shade(SKIN_D, 0.55), 1.3)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	for n in ("Head_L", "Head_R"):
		f = a[n]
		f.fill(SKIN)
		f.soft("M-5 90H125V135H-5Z", SKIN_D, 0.75, 3)
		f.soft("M-5-5H125V30H-5Z", SKIN_D, 0.7, 3)
	f = a["Head_B"]
	f.fill(shade(SKIN_D, 0.95))
	a["Head_T"].fill(SKIN)
	a["Head_Bo"].fill(SKIN_D)

	# cape art reaches z 2.5 (150) on the torso, the hem's point included
	f = a["Torso_F"]
	_cape(f, 150, TORSO_SPOTS, 1.2)
	# the seam from the cord down, a dark slit of tunic opening towards the hem; folds fall from the collar
	f.soft("M100 0L40 150H0V60Z", CAPE_D, 0.32, 5)
	f.soft("M100 0L160 150H200V60Z", CAPE_D, 0.36, 5)
	f.path("M98.5 40L101.5 40L103.5 150L96.5 150Z", TUNIC)
	f = a["Torso_B"]
	_cape(f, 150, BACK_SPOTS, 1.2)
	f.soft("M100 0L60 150H20L60 0Z", CAPE_D, 0.25, 5)
	for n in ("Torso_L", "Torso_R"):
		_cape(a[n], 150, SIDE_SPOTS, 0.62)
	a["Torso_T"].fill(CAPE)
	a["Torso_Bo"].fill(shade(TUNIC, 0.7))

	for side in ("Left", "Right"):
		for key, spots in (("F", ARM_F_SPOTS), ("B", ARM_B_SPOTS), ("O", ARM_O_SPOTS), ("I", ARM_I_SPOTS)):
			_cape(a[f"{side}Arm_{key}"], 130, spots, 0.66)
			a[f"{side}Leg_{key}"].fill("#383b52")
		a[f"{side}Arm_T"].fill(CAPE)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill("#383b52")
		a[f"{side}Leg_Bo"].fill("#23253a")
