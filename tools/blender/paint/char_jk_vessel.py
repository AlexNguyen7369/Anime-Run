# Painted look for jk_vessel. Uniform, spiral button, hood and under-eye marks close to the source design, drawn in-house (design doc 5).
import math

from atlas import INK, paint_hair, shade
from jk_common import brow2, buried, eye2, form, hair_ink, head_front, hem_line, jacket_back, jacket_front, jacket_side, loft, nose, pal, side_face, sleeve, sq, swirl_button, trouser

SKIN = "#f2cfae"
NAVY = pal("#22283b", "#0d101c", "#5a6a92", "#7488b8")
RED = "#c2262c"
RED_D = "#7c1218"
RED_L = "#ec5a58"
PINK = "#F49AA6"
DARK = "#4B383C"
HOOD = "#C22832"
DEFAULT = NAVY["base"]
HAIR_COLOURS = [PINK, DARK, HOOD]

HAIR = {
	"colour": PINK,
	"cap": {"size": [1.2, 1.12, 0.3], "at": [0, 0, 5.2], "bevel": 0.13},
	"locks": [
		# upward front row
		{"b": [0.02, -0.56, 5.1], "c": [0.04, -0.74, 5.5], "t": [-0.06, -0.76, 5.82], "r": 0.25},
		{"b": [0.3, -0.56, 5.1], "c": [0.42, -0.72, 5.44], "t": [0.56, -0.76, 5.72], "r": 0.24},
		{"b": [-0.3, -0.56, 5.1], "c": [-0.4, -0.72, 5.48], "t": [-0.52, -0.74, 5.78], "r": 0.24},
		{"b": [0.54, -0.5, 5.06], "c": [0.76, -0.6, 5.3], "t": [0.96, -0.62, 5.54], "r": 0.18},
		{"b": [-0.54, -0.5, 5.06], "c": [-0.74, -0.6, 5.28], "t": [-0.98, -0.58, 5.46], "r": 0.18},
		# fringe spikes falling over the forehead
		{"b": [0.08, -0.58, 5.34], "c": [0.15, -0.7, 5.12], "t": [0.06, -0.67, 4.9], "r": 0.13},
		{"b": [-0.14, -0.58, 5.34], "c": [-0.2, -0.7, 5.1], "t": [-0.11, -0.67, 4.86], "r": 0.14},
		{"b": [0.34, -0.58, 5.3], "c": [0.42, -0.68, 5.14], "t": [0.38, -0.66, 4.96], "r": 0.12},
		{"b": [-0.38, -0.58, 5.3], "c": [-0.46, -0.68, 5.14], "t": [-0.44, -0.66, 4.98], "r": 0.12},
		# crown
		{"b": [0.2, -0.1, 5.34], "c": [0.28, -0.22, 5.8], "t": [0.34, -0.3, 5.98], "r": 0.22},
		{"b": [-0.2, -0.1, 5.34], "c": [-0.3, -0.24, 5.82], "t": [-0.28, -0.3, 6.02], "r": 0.22},
		{"b": [0.0, 0.14, 5.36], "c": [0.02, 0.1, 5.8], "t": [0.08, 0.12, 6.04], "r": 0.24},
		{"b": [0.54, 0.0, 5.26], "c": [0.8, 0.0, 5.58], "t": [1.0, -0.04, 5.76], "r": 0.2, "mirror": True},
		{"b": [0.44, -0.2, 5.3], "c": [0.58, -0.3, 5.68], "t": [0.68, -0.42, 5.88], "r": 0.19, "mirror": True},
		{"b": [0.4, 0.2, 5.32], "c": [0.56, 0.3, 5.7], "t": [0.66, 0.36, 5.86], "r": 0.2, "mirror": True},
		# back of the head
		{"b": [0.0, 0.4, 5.3], "c": [0.0, 0.62, 5.66], "t": [0.02, 0.76, 5.86], "r": 0.22},
		{"b": [0.34, 0.42, 5.26], "c": [0.5, 0.64, 5.56], "t": [0.64, 0.82, 5.76], "r": 0.2, "mirror": True},
				{"b": [0.0, 0.52, 5.24], "c": [0.0, 0.78, 5.16], "t": [0.0, 0.84, 4.9], "r": 0.2},
		{"b": [0.32, 0.52, 5.24], "c": [0.42, 0.76, 5.16], "t": [0.44, 0.82, 4.94], "r": 0.18, "mirror": True},
		{"b": [0.58, 0.46, 5.22], "c": [0.7, 0.68, 5.14], "t": [0.74, 0.72, 4.96], "r": 0.14, "mirror": True},
		{"b": [0.6, 0.1, 5.2], "c": [0.8, 0.14, 5.12], "t": [0.86, 0.2, 4.96], "r": 0.15, "mirror": True},
		{"b": [0.6, -0.2, 5.2], "c": [0.78, -0.22, 5.14], "t": [0.84, -0.22, 4.98], "r": 0.14, "mirror": True},
		# laid over the back and sides of the crown, so no band of cap shows
		{"b": [0.0, 0.2, 5.22], "c": [0.0, 0.66, 5.42], "t": [0.0, 1.0, 5.3], "r": 0.26},
		{"b": [0.3, 0.2, 5.22], "c": [0.42, 0.62, 5.42], "t": [0.56, 0.96, 5.32], "r": 0.24, "mirror": True},
		{"b": [0.42, 0.08, 5.22], "c": [0.76, 0.3, 5.42], "t": [1.04, 0.5, 5.34], "r": 0.24, "mirror": True},
		{"b": [0.42, -0.2, 5.22], "c": [0.78, -0.2, 5.4], "t": [1.06, -0.18, 5.32], "r": 0.22, "mirror": True},
		# dark undercut, cropped: only the tufts over the temples and nape lift off the block
		{"b": [0.62, -0.28, 5.08], "c": [0.7, -0.36, 5.0], "t": [0.72, -0.46, 4.88], "r": 0.09, "colour": DARK, "mirror": True},
	],
}


buried(HAIR["locks"])


def _shoes(colour, box, at):
	out = []
	for part, sgn in (("LeftFoot", 1), ("RightFoot", -1)):
		out.append({"part": part, "box": box, "at": [sgn * at[0], at[1], at[2]], "colour": colour, "bevel": 0.05})
	return out


PROPS = [
	# sneakers: rubber toe and sole
	*_shoes("#F0ECE4", [1.0, 0.34, 0.15], (0.5, -0.6, 0.11)),
	*_shoes("#F0ECE4", [1.02, 1.34, 0.09], (0.5, -0.1, 0.045)),
]


def model(parts, kit):
	"""The bunched hood around the neck: a fat ring, lowest and thinnest under the chin, heaviest at the back."""
	grid = []
	n, m = 28, 6
	for k in range(n):
		ang = -math.pi / 2 + 2 * math.pi * k / n
		back = (1 - math.cos(ang + math.pi / 2)) / 2  # 0 at the front, 1 at the back
		wob = 0.018 * math.sin(k * 2.4)
		cx, cy = sq(ang, 0.74 + wob, 0.66 + wob, 3.2)
		rad = 0.1 + 0.15 * back
		cz = 3.99 + 0.14 * back
		ox, oy = math.cos(ang), math.sin(ang)
		row = []
		for j in range(m):
			t = 2 * math.pi * j / m
			row.append((cx + ox * rad * math.cos(t), cy + oy * rad * math.cos(t), cz + rad * 0.9 * math.sin(t)))
		grid.append(row)
	grid = [list(r) for r in zip(*grid)]
	loft(kit, parts["UpperTorso"], "Hood_Ring", "#B8242C", grid, closed_u=True, closed_v=True, smooth=True)
	# The hood itself lies down the back: a rounded bag, pointed at the bottom, with a shadowed opening at the top.
	grid = []
	for i in range(9):
		t = i / 8
		z = 4.12 - t * 1.12
		half = 0.68 * (1 - t**3) ** 0.8 * (1 - 0.15 * t) + 0.01
		bulge = 0.2 + 0.26 * math.sin(math.pi * min(1, t * 1.25)) * (1 - t * 0.5)
		grid.append([(half * math.sin(a), 0.5 + bulge * math.cos(a), z) for a in [(-1 + 2 * k / 10) * math.pi / 2 for k in range(11)]])
	loft(kit, parts["UpperTorso"], "Hood_Bag", HOOD, grid, closed_u=False, smooth=True, root=(0, 0.6, 4.1), tip=(0, 0.6, 3.0))
	grid = []
	for i in range(4):
		t = i / 3
		z = 4.1 - t * 0.34
		half = 0.44 * (1 - t**2) ** 0.7 + 0.01
		grid.append([(half * math.sin(a), 0.69 + (0.16 - 0.12 * t) * math.cos(a) + 0.02, z) for a in [(-1 + 2 * k / 8) * math.pi / 2 for k in range(9)]])
	loft(kit, parts["UpperTorso"], "Hood_Shadow", "#4E0E14", grid, closed_u=False, smooth=True)


def _shoe(f, key):
	"""Red high-top with a white toe and sole, laces in front."""
	top = 160
	f.path(f"M-5 {top}H105V206H-5Z", RED)
	f.soft(f"M12 {top + 4}H40V{top + 26}H12Z", RED_L, 0.5, 3)
	f.path(f"M-5 {top}H105V{top + 7}H-5Z", shade(RED, 0.8))
	f.ink(f"M-5 {top}H105", 1.6)
	f.path("M-5 186H105V206H-5Z", "#f0ece4")
	f.ink("M-5 186H105", 1.3)
	f.path("M-5 194H105V206H-5Z", "#c9c4ba")
	f.ink("M-5 194H105", 0.9)
	if key == "F":
		f.path(f"M34 {top + 3}H66V186H34Z", "#f0ece4", stroke=INK, sw=1)
		for y in range(top + 7, 184, 5):
			f.ink(f"M36 {y}L64 {y + 1.5}M64 {y}L36 {y + 1.5}", 0.9, "#333")
	elif key == "O":
		f.path(f"M18 {top + 12}a11 11 0 1 0 22 0a11 11 0 1 0 -22 0Z", "#f0ece4", stroke=INK, sw=1)
		f.taper(60, top + 6, 74, top + 16, 90, 184, 0.8, RED_D)
	elif key == "B":
		f.path(f"M44 {top}H56V186H44Z", "#f0ece4", stroke=INK, sw=0.9)
	f.soft(f"M86 {top}H105V206H86Z", "#000000", 0.32, 3)


def paint(a):
	paint_hair(a, [PINK, "#5a4650", "#d02c34"])
	hair_ink(a, 0, 3, PINK, gap=0.5, shine=1.25)
	hair_ink(a, 2, 3, "#d02c34", 14)
	# ---- face: big determined eyes, heavy straight brows, the slit marks under the eyes, clenched teeth
	f = a["Head_F"]
	head_front(f, SKIN, hair_shadow=30, jaw_y=88, chin_y=126, chin_w=22)
	# cropped dark hair at the temples
	f.path("M-5 -5H16L12 22L8 18L6 38L-5 44Z", DARK)
	f.path("M135 -5H114L118 22L122 18L124 38L135 44Z", DARK)
	eye2(f, 41, 62, -1, 29, 13.5, "#b5752f", tilt=2.6, r=8.6, lash_t=3)
	eye2(f, 89, 62, 1, 29, 13.5, "#b5752f", tilt=2.6, r=8.6, lash_t=3)
	brow2(f, 40, 45, -1, 31, 6.5, 3.2, "#5b3a3c")
	brow2(f, 90, 45, 1, 31, 6.5, 3.2, "#5b3a3c")
	f.taper(61, 50, 63, 54, 62, 58, 0.7, shade(SKIN, 0.5))
	f.taper(69, 50, 67, 54, 68, 58, 0.7, shade(SKIN, 0.5))
	# the slits under each eye
	for sgn, cx in ((-1, 41), (1, 89)):
		f.taper(cx - 12, 78, cx, 81, cx + 12, 78, 1.0, "#5e3128")
		f.taper(cx + sgn * 6, 75, cx + sgn * 6.5, 79, cx + sgn * 6, 84, 0.5, "#5e3128")
	nose(f, SKIN, 72, 16)
	f.path("M52 103Q65 100 79 102Q77 111 65 111.5Q54 111 52 103Z", "#3d0f12", stroke=INK, sw=1.2)
	f.path("M54 103.4Q65 101 77 102.8L75 108.5Q65 110 56 108.5Z", "#f7f3ec")
	f.ink("M55 106Q65 105 76 105.6", 0.55, "#7e7a80")
	for x in (59, 63.5, 68, 72.5):
		f.ink(f"M{x} 102V109.5", 0.45, "#7e7a80")
	f.ink("M49 102Q50 101 52 103", 1.2)
	f.ink("M83 100Q81 100 79 102", 1.2)
	f.taper(55, 118, 65, 120, 76, 118, 0.7, shade(SKIN, 0.55))
	# ---- sides: buzzed dark above the ear, pink starts high
	for name in ("Head_L", "Head_R"):
		f = a[name]
		side_face(f, SKIN, 66, 58)
		f.path("M14 -5L12 34L20 52L34 38Q56 30 80 40Q88 58 90 76L108 92L125 84V-5Z", DARK)
		for i in range(32):
			x = 16 + i * 3.4
			f.taper(x, 14, x + 1, 30, x + f.rng.uniform(-2, 2), 38 + (i % 3) * 3, 0.5, "#6a5258")
		f.soft("M90 70Q106 88 125 84V60Z", shade(SKIN, 0.7), 0.5, 2)
		f.path("M-5 -5H125V14L110 26L94 16L78 28L60 16L44 28L26 16L10 26L-5 14Z", PINK)
		f.taper(-5, 9, 60, 11, 125, 9, 2, shade(PINK, 1.2))
		f.taper(18, 24, 24, 14, 22, 2, 1, shade(PINK, 0.5))
		f.taper(66, 26, 68, 14, 70, 2, 1, shade(PINK, 0.5))
	# ---- back: buzzed nape, hair spikes painted over
	f = a["Head_B"]
	f.fill(shade(SKIN, 0.6))
	f.path("M-5 -5H135V96L118 104L104 94L88 108L70 96L52 110L36 96L20 106L-5 96Z", DARK)
	for i in range(36):
		x = 2 + i * 3.6
		f.taper(x, 30, x + 1, 60, x + f.rng.uniform(-2, 2), 84 + (i % 4) * 5, 0.5, "#6a5258")
	f.path("M-5 -5H135V30L118 44L100 28L84 48L66 30L48 48L30 28L14 44L-5 30Z", PINK)
	f.taper(-5, 14, 65, 18, 135, 14, 3, shade(PINK, 1.2))
	for x in (30, 66, 100):
		f.taper(x, 44, x + 2, 24, x, 2, 1.1, shade(PINK, 0.5))
	form(f, "#180e12", 0.35)
	a["Head_T"].fill(PINK)
	a["Head_Bo"].fill(shade(SKIN, 0.5))
	# ---- torso: hood panels, spiral button
	f = a["Torso_F"]
	jacket_front(f, NAVY, seed=1)
	hem_line(f, NAVY, 184, shade(NAVY["base"], 0.75))
	# Placket
	f.taper(101, 40, 99, 110, 101, 184, 1.5)
	f.taper(104, 44, 102, 110, 104, 184, 0.8, NAVY["lite"])
	# hood panels falling from the neck
	f.path("M26 -5Q40 34 84 56Q100 62 116 56Q160 34 174 -5Z", RED, stroke=INK, sw=2.0)
	f.path("M42 -5Q56 22 100 40Q144 22 158 -5Z", RED_D)
	f.path("M42 -5Q56 22 100 40Q144 22 158 -5Z", stroke=INK, sw=1.2)
	f.taper(30, 4, 52, 34, 84, 50, 1.2, RED_L)
	f.taper(170, 4, 148, 32, 116, 50, 1.1, RED_L)
	f.taper(50, 24, 66, 38, 90, 52, 1.0, RED_D)
	f.taper(150, 24, 134, 38, 110, 52, 1.0, RED_D)
	f.taper(60, 8, 74, 22, 92, 36, 0.8)
	f.taper(140, 8, 126, 22, 108, 36, 0.8)
	swirl_button(f, 100, 60, 11)
	# side pockets
	for x0, x1 in ((22, 66), (134, 178)):
		f.taper(x0, 142, (x0 + x1) / 2, 146, x1, 140, 1.2)
		f.taper(x0, 139.5, (x0 + x1) / 2, 143.5, x1, 137.5, 0.6, NAVY["lite"])
	form(f)
	f = a["Torso_B"]
	jacket_back(f, NAVY, seed=1)
	hem_line(f, NAVY, 184, shade(NAVY["base"], 0.75))
	f.soft("M28 0H172L118 116H82Z", "#000000", 0.5, 5)
	f.path("M36 -5Q70 24 100 26Q130 24 164 -5Z", RED, stroke=INK, sw=1.8)
	form(f)
	for name in ("Torso_L", "Torso_R"):
		f = a[name]
		jacket_side(f, NAVY, seed=1)
		hem_line(f, NAVY, 184, shade(NAVY["base"], 0.75))
		f.path("M-5 -5H105V7Q50 18 -5 7Z", RED, stroke=INK, sw=1.4)
		form(f)
	a["Torso_T"].fill(NAVY["base"])
	a["Torso_T"].soft("M0 0H200V30H0Z", NAVY["sheen"], 0.3, 5)
	a["Torso_Bo"].fill(NAVY["dark"])
	# ---- limbs
	for side in ("Left", "Right"):
		for key in "FBOI":
			sleeve(a[f"{side}Arm_{key}"], NAVY, key, seed=side, skin=SKIN)
			f = a[f"{side}Leg_{key}"]
			trouser(f, NAVY, key, seed=side, shoe_top=158)
			_shoe(f, key)
		a[f"{side}Arm_T"].fill(NAVY["base"])
		a[f"{side}Arm_Bo"].fill(SKIN)
		a[f"{side}Leg_T"].fill(NAVY["base"])
		a[f"{side}Leg_Bo"].fill("#c9c4ba")
