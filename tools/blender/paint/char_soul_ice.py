# Target look for soul_ice "Rukiya" (design doc section 5): a rounded black bob with a small peak at the crown and thin wisps flicking
# out at the jaw, one wedge of hair falling between the eyes, big dark violet eyes, pale skin; black wrapped robes over a white under-robe,
# a white sash, wide black trousers, white split-toe socks and straw sandals, and the all-white released sword in her right hand with
# its hollow ring guard and long ribbon. Small in her source; stays on the standard block body. No marks: nothing here is a logo or symbol.
# +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from db_style3 import pipe
from jk_common import eye2, form
from jk_style3 import Kit, bake, big_head, block, crown, finish, gem, head_rest, jitter, prism, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#f7e6d8"
SKIN_D = "#d9b8a6"
ROBE = "#17171e"
ROBE_D = "#07070b"
FOLD = "#3b3c4c"
DEFAULT = ROBE
R = Ramps(
	hair=["#040509", "#0a0c13", "#141822", "#272d3d", "#465070"],
	skin=["#c79f8a", "#e6c6b2", SKIN, "#fff4ea"],
	robe=["#060609", "#0d0d12", "#17171e", "#23242e", "#34353f"],
	white=["#8f96a8", "#c3c8d4", "#e8ebf0", "#fbfcfe"],
	tabi=["#9da3b2", "#cdd1da", "#ecedf1", "#fbfbfd"],
	straw=["#8a6d3a", "#b4924f", "#d1b26c", "#e6cd8e"],
	dark=["#020203", "#060608", "#0b0b10"],
	ice=["#a9bbd2", "#d0dceb", "#ebf2f8", "#f8fbfd", "#ffffff"],
)
HAIR = {"colour": "#0B0D14", "locks": []}
PROPS = []
GRIP = (-1.5, 0.0, 2.04)  # her right hand; the sword runs through it, low and forward
AXIS = (0.0, -1.0, -0.42)


def _hair(k):
	crown(k, [(1.0, 5.44), (1.03, 5.66), (0.95, 5.92), (0.64, 6.14), (0.2, 6.24)])
	block(k, "Head", "Cap", 0, 0.02, 5.8, 5.42, 1.0, 0.87, "hair", ch=0.1, corner=0.4, jit=0.01, sub=1, a=0.44, b=0.44)
	# the bob: one rounded shell behind the ears, its cut at the jaw
	rows = [(0, 0.22, 5.86, 0.8, 0.56), (0, 0.24, 5.68, 1.0, 0.66), (0, 0.26, 5.4, 1.06, 0.68), (0, 0.28, 4.62, 1.06, 0.7), (0, 0.28, 4.22, 0.96, 0.66), (0, 0.26, 4.12, 0.9, 0.62), (0, 0.26, 3.99, 0.8, 0.56)]
	o = k.tube("Head", "Bob", rows, "hair", corner=0.42, nc=1, sub=1, outline=0)
	jitter(o, 0.014)
	bake(o, "hair", k, a=0.4, b=0.42)
	# the small peak at the crown
	gem(k, "Head", "Peak", (0, 0.1, 6.04), (0.02, 0.14, 6.44), 0.26, flat=0.7, twist=0.2, a=0.46)
	for s in (1, -1):
		# the curtain down each side of the face, coming forward past the cheek to the jaw
		slab(k, f"Side{s}", [(-0.86, 5.52), (-0.9, 5.3), (-0.9, 4.86), (-0.84, 4.46), (-0.66, 4.22), (0.2, 4.2), (0.3, 5.56)], s * 0.76, s * 1.06, "hair", a=0.42, b=0.46)
		# its inner edge slants down the cheek, so the sides never read as two boxes
		gem(k, "Head", f"Curtain{s}", (s * 0.46, -0.86, 5.68), (s * 0.8, -0.95, 4.34), 0.27, flat=0.3, twist=0.0, a=0.44, across=(1, 0, 0))
		# big locks lying down the flat of the side, so it breaks into planes
		for i, (y, z1, z0, r) in enumerate(((-0.42, 5.4, 4.3, 0.24), (0.04, 5.46, 4.2, 0.27), (0.5, 5.36, 4.3, 0.24))):
			gem(k, "Head", f"SideLock{s}{i}", (s * 1.05, y, z1), (s * 1.08, y + 0.04, z0), r, flat=0.16, twist=0.0, a=0.5, b_=0.5, across=(0, 1, 0))
		# thin wisps below the cut, flicking outward over the shoulder
		for i, (y, tx, tz, r) in enumerate(((-0.72, 0.92, 4.06, 0.13), (-0.44, 1.2, 4.1, 0.17), (-0.06, 1.3, 4.12, 0.19), (0.34, 1.24, 4.12, 0.18))):
			gem(k, "Head", f"Wisp{s}{i}", (s * 0.88, y, 4.62), (s * tx, y + 0.02 * i, tz), r, flat=0.32, bend=-0.03, twist=0.15 + 0.12 * i, across=(0, 1, 0), a=0.44)
		# the fringe, leaving the brow open either side of the wedge
		for i, (x, z, r) in enumerate(((0.28, 5.46, 0.2), (0.54, 5.14, 0.24), (0.8, 4.9, 0.24))):
			gem(k, "Head", f"Fringe{s}{i}", (s * 0.12, -0.74, 5.88), (s * x, -0.95, z), r, flat=0.4, twist=0.15, a=0.46, across=(1, 0, 0))
		# one broad plane lying back along the dome
		gem(k, "Head", f"Plane{s}", (s * 0.34, 0.0, 5.92), (s * 0.98, 0.12, 5.42), 0.28, flat=0.46, twist=0.25, a=0.46)
	# the nape, flicking out under the back of the bob
	for i, (x, z, r) in enumerate(((-0.86, 4.02, 0.22), (-0.44, 3.96, 0.26), (0.04, 3.98, 0.27), (0.48, 3.96, 0.26), (0.88, 4.02, 0.22))):
		gem(k, "Head", f"Nape{i}", (x * 0.85, 0.84, 4.46), (x, 1.1, z), r, flat=0.28, twist=0.14 + 0.1 * i, across=(1, 0, 0), a=0.42)
	# the one thing that must read: a wedge from the hairline down between the eyes
	gem(k, "Head", "Wedge", (0.0, -0.8, 5.86), (0.03, -0.96, 4.56), 0.19, flat=0.3, twist=0.0, a=0.44, across=(1, 0, 0))


def _robe(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Robe", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	# white under-robe, then the black lapels; the one on her left crosses over and runs down into the sash
	for s, low in ((-1, 3.5), (1, 3.5)):
		prism(k, t, f"Under{s}", [(s * 0.46, 3.99), (s * 0.28, 3.99), (s * -0.02, low), (s * 0.12, low - 0.2)], -0.59, -0.56, "white", a=0.62, b=0.3)
	prism(k, t, "LapelR", [(-0.72, 3.99), (-0.46, 3.99), (0.02, 3.2), (-0.2, 3.1)], -0.6, -0.56, "robe", a=0.6, b=0.5)
	prism(k, t, "LapelL", [(0.72, 3.99), (0.46, 3.99), (-0.48, 2.44), (-0.74, 2.44)], -0.615, -0.56, "robe", a=0.62, b=0.5)
	block(k, t, "Sash", 0, 0, 2.5, 2.27, 1.1, 0.625, "white", ch=0.03, corner=0.14, sub=1, a=0.56, b=0.3)


def _sleeve(k, side, s):
	"""Wide robe sleeve: one stud across the arm, deepening towards a hanging opening at the wrist."""
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	rows = [(ax, 0, 4.03, 0.42, 0.42), (ax, 0, 3.96, 0.52, 0.52), (ax, 0, 3.4, 0.53, 0.56), (ax, 0.02, 2.8, 0.54, 0.68), (ax, 0.04, 2.36, 0.545, 0.74), (ax, 0.04, 2.32, 0.5, 0.7)]
	o = k.tube(arm, "Sleeve", rows, "robe", corner=0.16, nc=1, sub=1, outline=0)
	jitter(o, 0.018)
	bake(o, "robe", k, a=0.46, b=0.5)
	block(k, arm, "Opening", ax, 0.04, 2.34, 2.3, 0.5, 0.69, "dark", ch=0.008, a=0.4)
	block(k, arm, "Hand", ax, 0, 2.34, 1.78, 0.48, 0.48, "skin", ch=0.06, a=0.6, b=0.32)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# wide trousers, falling straight to the ankle
	block(k, leg, "Thigh", px, 0, 1.97, 1.1, 0.49, 0.56, "robe", ch=0.04, flare=0.01, corner=0.16, jit=0.025, mids=(1.55,), a=0.44, b=0.5)
	block(k, leg, "Shin", px, 0, 1.16, 0.46, 0.5, 0.58, "robe", ch=0.04, flare=0.015, corner=0.16, jit=0.025, mids=(0.8,), a=0.44, b=0.5)
	for i, ox in enumerate((-0.2, 0.14)):
		block(k, leg, f"Pleat{i}", px + s * ox, -0.6, 1.9, 0.5, 0.018, 0.016, "robe", ch=0.005, a=0.86, b=0.08)
	block(k, leg, "PleatBack", px, 0.6, 1.9, 0.5, 0.018, 0.016, "robe", ch=0.005, a=0.86, b=0.08)
	# white split-toe sock on a straw sandal
	block(k, leg, "Sock", px, -0.04, 0.5, 0.13, 0.44, 0.48, "tabi", ch=0.05, a=0.62, b=0.3)
	block(k, leg, "SockToe", px, -0.44, 0.31, 0.13, 0.41, 0.2, "tabi", ch=0.06, corner=0.3, a=0.66, b=0.3)
	block(k, leg, "ToeSplit", px - s * 0.2, -0.64, 0.29, 0.14, 0.014, 0.012, "white", ch=0.004, a=0.0, b=0.12)
	block(k, leg, "Sandal", px, -0.12, 0.13, 0.0, 0.5, 0.66, "straw", ch=0.03, a=0.54, b=0.34)
	for i, y in enumerate((-0.42, 0.16)):
		block(k, leg, f"Strap{i}", px, y, 0.3 - 0.06 * (1 - i), 0.13, 0.455, 0.05, "straw", ch=0.012, a=0.6, b=0.3)


def _along(t):
	return tuple(GRIP[i] + AXIS[i] * t for i in range(3))


def _guard(k, arm):
	"""The hollow round guard, with short ice points standing off its rim: a flat ring square to the blade."""
	n = 10
	cx, cy, cz = _along(0.62)
	ax = math.hypot(*AXIS)
	dy, dz = AXIS[1] / ax, AXIS[2] / ax
	ux, uy, uz = 1, 0, 0
	vx, vy, vz = 0, -dz, dy  # square to the blade, in the sagittal plane
	verts, faces = [], []
	r0, r1, th = 0.19, 0.31, 0.035
	for j in range(n):
		a = 2 * math.pi * j / n
		c, sn = math.cos(a), math.sin(a)
		for r, off in ((r1, -th), (r0, -th), (r0, th), (r1, th)):
			verts.append((cx + (ux * c + vx * sn) * r, cy + (uy * c + vy * sn) * r + dy * off, cz + (uz * c + vz * sn) * r + dz * off))
	for j in range(n):
		j1 = (j + 1) % n
		for q in range(4):
			q1 = (q + 1) % 4
			faces.append((j * 4 + q, j * 4 + q1, j1 * 4 + q1, j1 * 4 + q))
	bake(k._mesh("Guard", arm, verts, faces, outline=0), "ice", k, a=0.6, b=0.36)
	for j in range(0, n, 2):
		a = 2 * math.pi * (j + 0.5) / n
		c, sn = math.cos(a), math.sin(a)
		b = (cx + c * r1 * 0.92, cy + vy * sn * r1 * 0.92, cz + vz * sn * r1 * 0.92)
		t = (cx + c * r1 * 1.42, cy + vy * sn * r1 * 1.42, cz + vz * sn * r1 * 1.42)
		gem(k, arm, f"GuardPoint{j}", b, t, 0.05, "ice", flat=0.5, twist=0.1, a=0.62, b_=0.34)


def _sword(k):
	arm = "RightUpperArm"
	# the blade: long, thin, turned a little to the viewer so it keeps its width from the front
	ax = math.hypot(*AXIS)
	dy, dz = AXIS[1] / ax, AXIS[2] / ax
	cos35, sin35 = math.cos(math.radians(35)), math.sin(math.radians(35))
	wide = (sin35, -dz * cos35, dy * cos35)
	thin = (cos35, dz * sin35, -dy * sin35)
	rings = []
	for t, w, off in ((0.64, 0.125, 0.0), (1.2, 0.125, 0.0), (2.2, 0.12, 0.0), (2.62, 0.115, 0.0), (2.9, 0.012, 0.09)):
		p = _along(t)
		rings.append([tuple(p[i] + wide[i] * (w * a0 + off) + thin[i] * 0.022 * b0 for i in range(3)) for a0, b0 in ((1, 0), (0.4, 1), (-0.4, 1), (-1, 0), (-0.4, -1), (0.4, -1))])
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Blade", arm, verts, faces, flat, outline=0), "ice", k, a=0.68, b=0.3, g=0.0)
	_guard(k, arm)
	pipe(k, arm, "Hilt", [_along(-0.7) + (0.07,), _along(0.62) + (0.075,)], "ice", rn=6, base=0.58, amp=0.34, grad=0.0)
	pipe(k, arm, "Pommel", [_along(-0.78) + (0.05,), _along(-0.7) + (0.095,), _along(-0.64) + (0.08,)], "ice", rn=6, base=0.6, amp=0.32, grad=0.0)
	# the ribbon from the pommel, trailing back and down in one long fold
	path = [_along(-0.72), (-1.5, 0.92, 2.2), (-1.56, 1.24, 1.82), (-1.52, 1.44, 1.42), (-1.6, 1.74, 1.06), (-1.56, 2.02, 0.76)]
	ring = []
	for i, p in enumerate(path):
		tw = 0.5 + 0.62 * i
		w = (0.06 if i == 0 else 0.17) if i < len(path) - 1 else 0.07
		cx, cz = math.cos(tw) * w, math.sin(tw) * w
		ring.append([(p[0] + cx, p[1], p[2] + cz), (p[0] + cx * 0.92 - sin35 * 0.012, p[1] + 0.024, p[2] + cz * 0.92), (p[0] - cx, p[1], p[2] - cz), (p[0] - cx * 0.92 + sin35 * 0.012, p[1] - 0.024, p[2] - cz * 0.92)])
	verts, faces, flat = k._loft(ring)
	bake(k._mesh("Ribbon", arm, verts, faces, flat, outline=0), "ice", k, a=0.5, b=0.36, g=0.0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_robe(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_sleeve(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.55, sw=6):
	"""A cloth fold on black: a soft cool light and no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=FOLD, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(ROBE)
	# the skin at the throat, between the white under-robe
	f.path("M70 -5H130L100 50Z", SKIN)
	f.soft("M70 -5H130V12H70Z", SKIN_D, 0.9, 3)
	f.soft("M12 26Q40 16 72 40Q60 76 22 70Z", FOLD, 0.45, 8)
	f.soft("M188 28Q160 18 128 42Q140 76 180 68Z", FOLD, 0.3, 8)
	_fold(f, 12, 62, 36, 90, 62, 118)
	_fold(f, 188, 64, 164, 90, 136, 116)
	_fold(f, 150, 84, 134, 100, 112, 118, 0.4, 5)
	_fold(f, 26, 120, 40, 132, 30, 146, 0.4, 5)
	_fold(f, 174, 122, 160, 134, 170, 146, 0.4, 5)
	_fold(f, 40, 164, 46, 178, 40, 196, 0.5, 5)
	_fold(f, 160, 164, 154, 178, 160, 196, 0.5, 5)
	stroke(f, "M100 164V205", ROBE_D, 2.4, 0.9)
	form(f, ROBE_D, 0.5)
	f = a["Torso_B"]
	f.fill(ROBE)
	f.soft("M12 16Q60 2 92 18Q88 66 56 76Q18 66 12 16Z", FOLD, 0.34, 8)
	f.soft("M188 16Q140 2 108 18Q112 66 144 76Q182 66 188 16Z", FOLD, 0.26, 8)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	_fold(f, 40, 166, 48, 180, 38, 196, 0.5, 5)
	_fold(f, 160, 166, 152, 180, 162, 196, 0.5, 5)
	form(f, ROBE_D, 0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(ROBE)
		_fold(f, 20, 40, 34, 80, 26, 120, 0.45, 6)
		_fold(f, 70, 150, 60, 170, 70, 196, 0.45, 5)
		form(f, ROBE_D, 0.5)
	a["Torso_T"].fill(ROBE)
	a["Torso_Bo"].fill(ROBE_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(ROBE)
			a[f"{side}Leg_{key}"].fill(ROBE)
		a[f"{side}Arm_T"].fill(ROBE)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(ROBE)
		a[f"{side}Leg_Bo"].fill(ROBE_D)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V30Q65 38 -5 30Z", SKIN_D, 0.75, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.45, 3)
	for cx, s in ((37, -1), (93, 1)):
		# big and dark violet under a heavy lash
		eye2(f, cx, 68, s, 40, 32, "#6b4cc0", tilt=0.6, r=14, lid=0.05, lash="#0a0a10", lash_t=5, flick=3.4, pupil=0.46, sclera="#f6f3f2", crease_line=True)
		# thin brows, a little lifted at the outer end
		f.path(f"M{cx - s * 15} 43Q{cx} 36 {cx + s * 17} 38L{cx + s * 17} 39.5Q{cx} 38.5 {cx - s * 15} 45Z", "#14161f")
	f.path("M63 88L66 95L61 96Q64 92 63 88Z", SKIN_D, opacity=0.95)
	# a small mouth, set level
	f.path("M57 111Q65 109 73 111Q65 114 57 111Z", "#a06a5e")
	stroke(f, "M56 110.6H74", "#6a3f38", 0.8)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.76))
	a["Head_T"].fill("#141822")
	_torso(a)
	_limbs(a)
