# Painted look for jk_nails. Uniform, spiral buttons, hammer and nails close to the source design, drawn in-house (design doc 5).
import math
import random

from atlas import INK, paint_hair, shade
from jk_common import brow2, collar, eye2, flipped, form, hair_ink, head_front, jacket_back, jacket_front, jacket_side, loft, nose, pal, side_face, sleeve, sq, swirl_button

SKIN = "#f7dcc8"
UNI = pal("#23283c", "#0e111d", "#5d6c94", "#7d8dbb")
AUBURN = "#D9743A"
SKIRT = "#2A3048"
BROWN = "#6a3e22"
DEFAULT = UNI["base"]
HAIR_COLOURS = [AUBURN, SKIRT]


def _bob_locks():
	out = [
		# fringe: parted over the right eye, the long side swept across the forehead, its tip past the left eye
		{"b": [-0.26, -0.34, 5.22], "c": [0.1, -0.86, 5.16], "t": [0.56, -0.76, 4.84], "r": 0.22, "flatten": 0.36},
		{"b": [-0.2, -0.34, 5.2], "c": [0.0, -0.86, 5.1], "t": [0.26, -0.76, 4.88], "r": 0.18, "flatten": 0.36},
		{"b": [-0.08, -0.34, 5.22], "c": [0.26, -0.88, 5.2], "t": [0.68, -0.78, 4.98], "r": 0.2, "flatten": 0.36},
		# the short side
		{"b": [-0.3, -0.34, 5.2], "c": [-0.46, -0.86, 5.14], "t": [-0.48, -0.76, 4.88], "r": 0.18, "flatten": 0.36},
		{"b": [-0.42, -0.34, 5.18], "c": [-0.58, -0.84, 5.1], "t": [-0.6, -0.74, 4.82], "r": 0.16, "flatten": 0.36},
		# front locks framing the jaw, ends curled in
		{"b": [0.5, -0.3, 5.06], "c": [0.7, -0.92, 4.62], "t": [0.5, -0.74, 4.18], "r": 0.22, "flatten": 0.36},
		{"b": [-0.5, -0.3, 5.06], "c": [-0.7, -0.92, 4.62], "t": [-0.5, -0.74, 4.18], "r": 0.22, "flatten": 0.36},
	]
	return out


HAIR = {"colour": AUBURN, "locks": _bob_locks()}


PROPS = [
	# belt
	{"part": "LowerTorso", "box": [2.06, 1.06, 0.13], "at": [0, 0, 2.56], "colour": "#6A3E22", "bevel": 0.02},
	{"part": "LowerTorso", "box": [0.2, 0.05, 0.17], "at": [0, -0.545, 2.56], "colour": "#C9A24A", "bevel": 0.01},
	# nail pouch on the belt
	{"part": "LowerTorso", "box": [0.36, 0.2, 0.4], "at": [-0.78, -0.62, 2.34], "colour": "#5A3A28", "bevel": 0.04},
	{"part": "LowerTorso", "box": [0.38, 0.22, 0.13], "at": [-0.78, -0.62, 2.53], "colour": "#6A3E22", "bevel": 0.03},
	# straw doll tied to the belt, with a nail through it
	{"part": "LowerTorso", "lock": [[0.74, -0.62, 2.5], [0.74, -0.66, 2.2], [0.74, -0.62, 1.82]], "r": 0.11, "colour": "#D8C592", "flatten": 0.7},
	{"part": "LowerTorso", "lock": [[0.74, -0.65, 2.24], [0.98, -0.66, 2.2], [1.04, -0.64, 2.02]], "r": 0.05, "colour": "#D8C592", "flatten": 0.8},
	{"part": "LowerTorso", "lock": [[0.74, -0.65, 2.24], [0.5, -0.66, 2.2], [0.44, -0.64, 2.02]], "r": 0.05, "colour": "#D8C592", "flatten": 0.8},
	{"part": "LowerTorso", "box": [0.17, 0.16, 0.17], "at": [0.74, -0.64, 2.42], "colour": "#D8C592", "bevel": 0.05},
	{"part": "LowerTorso", "lock": [[0.74, -0.74, 2.3], [0.74, -0.84, 2.3], [0.76, -1.0, 2.34]], "r": 0.035, "colour": "#CCD2DA", "flatten": 1.0},
	# hammer: handle through the right fist, head low
	{"part": "RightHand", "box": [0.14, 0.14, 1.4], "at": [-1.5, -0.2, 1.72], "colour": "#8A5A2E", "bevel": 0.03},
	{"part": "RightHand", "box": [0.66, 0.3, 0.3], "at": [-1.52, -0.2, 1.02], "colour": "#7C858F", "bevel": 0.05},
	{"part": "RightHand", "box": [0.14, 0.36, 0.36], "at": [-1.18, -0.2, 1.02], "colour": "#A4ADB8", "bevel": 0.03},
	{"part": "RightHand", "lock": [[-1.82, -0.2, 1.08], [-2.08, -0.2, 1.08], [-2.16, -0.2, 0.82]], "r": 0.14, "colour": "#7C858F", "flatten": 0.7},
	# nails between the left fingers
	{"part": "LeftHand", "lock": [[1.22, -0.42, 2.2], [1.2, -0.46, 1.86], [1.16, -0.48, 1.42]], "r": 0.055, "colour": "#CCD2DA", "flatten": 1.0},
	{"part": "LeftHand", "lock": [[1.5, -0.42, 2.2], [1.5, -0.46, 1.8], [1.5, -0.48, 1.34]], "r": 0.055, "colour": "#CCD2DA", "flatten": 1.0},
	{"part": "LeftHand", "lock": [[1.78, -0.42, 2.2], [1.8, -0.46, 1.86], [1.84, -0.48, 1.42]], "r": 0.055, "colour": "#CCD2DA", "flatten": 1.0},
	{"part": "LeftHand", "box": [0.15, 0.15, 0.04], "at": [1.22, -0.42, 2.2], "colour": "#CCD2DA", "bevel": 0.008},
	{"part": "LeftHand", "box": [0.15, 0.15, 0.04], "at": [1.5, -0.42, 2.2], "colour": "#CCD2DA", "bevel": 0.008},
	{"part": "LeftHand", "box": [0.15, 0.15, 0.04], "at": [1.78, -0.42, 2.2], "colour": "#CCD2DA", "bevel": 0.008},
	# shoes
	{"part": "LeftFoot", "box": [1.0, 0.36, 0.22], "at": [0.5, -0.6, 0.12], "colour": "#6A4630", "bevel": 0.06},
	{"part": "RightFoot", "box": [1.0, 0.36, 0.22], "at": [-0.5, -0.6, 0.12], "colour": "#6A4630", "bevel": 0.06},
	{"part": "LeftFoot", "box": [1.02, 1.34, 0.07], "at": [0.5, -0.1, 0.035], "colour": "#2A1C14", "bevel": 0.02},
	{"part": "RightFoot", "box": [1.02, 1.34, 0.07], "at": [-0.5, -0.1, 0.035], "colour": "#2A1C14", "bevel": 0.02},
]


def model(parts, kit):
	head = parts["Head"]
	# The bob: one faceted shell from the crown to the chin, opening round the face below the forehead. The facets run
	# top to bottom and deepen downwards, so the planes of hair catch the light; the hem breaks into pointed ends.
	levels = ((5.5, 0.01, 0.01, 0.0, 0.0), (5.47, 0.34, 0.3, 0.0, 0.005), (5.41, 0.56, 0.52, 0.0, 0.01), (5.3, 0.7, 0.66, 0.0, 0.02), (5.18, 0.75, 0.71, 0.0, 0.03), (5.04, 0.76, 0.72, 0.0, 0.05), (4.92, 0.78, 0.74, 0.42, 0.07), (4.6, 0.8, 0.76, 0.42, 0.1), (4.34, 0.79, 0.75, 0.42, 0.11), (4.14, 0.71, 0.67, 0.42, 0.09))
	n = 48
	grid = []
	r = random.Random("jk_nails_bob")
	drops = [r.uniform(0.0, 0.14) if k % 3 == 1 else 0.14 + r.uniform(0.0, 0.05) for k in range(n + 1)]
	for row_i, (z, ax, by, gap, ridge) in enumerate(levels):
		row = []
		for k in range(n + 1):
			ang = -math.pi / 2 + gap + k / n * (2 * math.pi - 2 * gap)
			wave = abs(((k % 6) / 6) * 2 - 1)  # ridge per lock of hair
			x, y = sq(ang, ax + ridge * wave, by + ridge * wave)
			last = row_i == len(levels) - 1
			row.append((x, y, z + (drops[k] - 0.14 if last else 0)))
		grid.append(row)
	loft(kit, head, "Bob_Shell", AUBURN, grid, closed_u=False, root=(0, 0, 5.5), tip=(0, 0, 4.1))
	# Drawn on top of the shell: long ink lines following the hair's fall.
	for k in range(10):
		ang = -math.pi / 2 + 0.56 + (k + 0.5) / 10 * (2 * math.pi - 1.12)
		a0, b0 = sq(ang, 0.76, 0.72)
		a1, b1 = sq(ang, 0.95, 0.91)
		a2, b2 = sq(ang, 0.9, 0.86)
		kit.lock(f"Bob_Line{k}", (a0, b0, 5.2), (a1, b1, 4.74), (a2, b2, 4.28 + r.uniform(-0.04, 0.16)), 0.024, "#6E2F12", head, flatten=0.6)
	# The short pleated skirt: 14 knife pleats, each its own wedge, so the ink outline draws the pleat lines.
	pleats = 14
	rows = ((2.54, 1.03, 0.53, 0.02), (2.2, 1.06, 0.57, 0.05), (1.84, 1.12, 0.64, 0.08), (1.56, 1.17, 0.7, 0.1))
	for p in range(pleats):
		grid = []
		for z, ax, by, amp in rows:
			a0 = 2 * math.pi * p / pleats
			a1 = 2 * math.pi * (p + 1.08) / pleats
			out0 = sq(a0, ax + amp, by + amp, 5)
			inn1 = sq(a1, ax, by, 5)
			inn0 = sq(a0, ax - amp, by - amp, 5)
			grid.append([(*out0, z), (*inn1, z), (*inn0, z)])
		loft(kit, parts["LowerTorso"], f"Pleat{p}", SKIRT, grid, closed_u=True, root=(0, 0, 2.54), tip=(0, 0, 1.56))
	collar(kit, parts["UpperTorso"], "Collar", "#262C42", 0.72, 0.66, 3.96, lambda t: 0.13 + 0.14 * t ** 0.7, thick=0.06, gap=0.1, lean=0.03)


def _leg(f, key):
	"""Black tights over the skin, lifted at the knee and shin; brown loafers."""
	base = "#1a1b22"
	f.fill(base)
	sx = {"F": 34, "B": 64, "O": 38, "I": 62}[key]
	f.soft(f"M{sx - 16} 4L{sx + 16} 4L{sx + 12} 88L{sx - 12} 88Z", "#6c5c60", 0.5, 5)
	f.soft(f"M{sx - 12} 94a12 9 0 1 0 24 0a12 9 0 1 0 -24 0Z", "#7c6a6c", 0.34, 5)
	f.soft(f"M{sx - 10} 112L{sx + 10} 112L{sx + 6} 158L{sx - 6} 158Z", "#6c5c60", 0.45, 3)
	f.taper(22, 106, 50, 112, 78, 106, 0.8, "#000000")
	if key == "B":
		f.taper(50, 98, 50, 128, 50, 160, 0.7, "#000000")
		f.taper(22, 100, 50, 104, 78, 100, 0.8, "#000000")
	form(f, "#000000", 0.45)
	top = 166
	f.path(f"M-5 {top}H105V206H-5Z", "#6a4630")
	f.soft(f"M14 {top + 2}H42V{top + 20}H14Z", "#b98a5e", 0.6, 3)
	f.ink(f"M-5 {top}H105", 1.6)
	f.path("M-5 194H105V206H-5Z", "#2a1c14")
	f.ink("M-5 194H105", 1.2)
	if key == "F":
		f.path(f"M26 {top + 2}H74V{top + 14}H26Z", "#54351f", stroke=INK, sw=1)
		f.path(f"M38 {top + 6}H62V{top + 10}H38Z", "#2a1c14")
	elif key in "OI":
		f.ink(f"M4 {top + 6}Q50 {top + 16} 96 {top + 6}", 0.8, "#2a1c14")


def _bob_side(f):
	"""Hair down the whole side, ends to the jaw."""
	side_face(f, SKIN, 60, 70)
	f.path("M-5 -5H125V135H10L14 110L6 116L8 90L-5 92Z", AUBURN)
	f.soft("M10 8Q50 0 96 10Q90 38 52 44Q18 36 10 8Z", "#ffc08a", 0.65, 5)
	for x0, x1, y1 in ((16, 14, 118), (34, 30, 130), (52, 50, 134), (72, 68, 134), (92, 90, 134), (110, 112, 132)):
		f.taper(x0, 2, (x0 + x1) / 2 + 3, 64, x1, y1, 1.3, shade(AUBURN, 0.42))
		f.taper(x0 + 4, 8, (x0 + x1) / 2 + 7, 46, x1 + 4, y1 - 40, 0.8, "#ffc08a")


def paint(a):
	paint_hair(a, [AUBURN, "#343a54"])
	hair_ink(a, 0, 2, AUBURN, count=34, gap=0.38, shine=1.4)
	hair_ink(a, 1, 2, "#343a54", count=42, gap=0.18, shine=1.9)
	a["Hair"].soft("M0 70H512V80H0Z", "#ffc896", 0.75, 2)  # the band of shine round the crown, which is near the root end
	# ---- face: long lashes, arched thin brows, a bold one-sided smirk
	f = a["Head_F"]
	head_front(f, SKIN, hair_shadow=36, jaw_y=88, chin_y=122, chin_w=14)
	eye2(f, 42, 66, -1, 28, 11, "#b2652a", tilt=4.2, r=7.8, lid=0.12, lash_t=3.2, flick=4.5, lash="#1b0f12")
	eye2(f, 88, 66, 1, 28, 11, "#b2652a", tilt=4.2, r=7.8, lid=0.12, lash_t=3.2, flick=4.5, lash="#1b0f12")
	for sgn, cx in ((-1, 42), (1, 88)):  # outer lashes
		f.taper(cx + sgn * 14, 62, cx + sgn * 18, 60, cx + sgn * 20, 56, 0.8, "#1b0f12")
		f.taper(cx + sgn * 12, 58, cx + sgn * 15, 55, cx + sgn * 17, 51, 0.7, "#1b0f12")
	brow2(f, 42, 50, -1, 27, 3.4, 3.4, "#7c3f20", arc=-2.5)
	brow2(f, 88, 47, 1, 27, 3.4, 2.4, "#7c3f20", arc=-3)
	nose(f, SKIN, 80, 11)
	# a hard one-sided smirk with a little teeth
	f.path("M54 104Q68 106 84 100Q81 108 68 109.5Q58 109 54 104Z", "#5c1c1e", stroke=INK, sw=1.1)
	f.path("M57 104.6Q68 106 81 101.4L79.5 104.4Q68 107.2 59 106Z", "#f7f3ec")
	f.ink("M84 100Q86 99 87.5 96.5", 1.2)
	f.taper(60, 114.5, 67, 116, 75, 114, 0.6, shade(SKIN, 0.55))
	# ---- sides, back
	_bob_side(a["Head_L"])
	with flipped(a["Head_R"]):
		_bob_side(a["Head_R"])
	f = a["Head_B"]
	f.fill(AUBURN)
	for k in range(10):
		f.taper(8 + k * 13, 2, 10 + k * 13, 60, 8 + k * 13, 130, 1.3, shade(AUBURN, 0.42))
	a["Head_T"].fill(AUBURN)
	a["Head_Bo"].fill(shade(AUBURN, 0.5))
	# ---- jacket: short, belted, two spiral buttons
	belt_y = 150
	f = a["Torso_F"]
	jacket_front(f, UNI, seed=4, hem=belt_y)
	f.soft("M28 52Q58 40 90 56Q86 82 58 88Q28 80 28 52Z", UNI["sheen"], 0.22, 5)
	f.soft("M172 52Q142 40 110 56Q114 82 142 88Q172 80 172 52Z", UNI["sheen"], 0.14, 5)
	f.taper(28, 82, 60, 94, 92, 80, 1.1)  # under the chest
	f.taper(172, 82, 140, 94, 108, 80, 1.1)
	f.path(f"M92 -5H108L109 {belt_y}H91Z", shade(UNI["base"], 1.1))
	f.taper(91, -5, 90, 80, 91, belt_y, 1.3)
	f.taper(109, -5, 110, 80, 109, belt_y, 1.3)
	f.taper(94, -5, 93, 80, 94, belt_y, 0.6, UNI["lite"])
	f.soft("M-5 -5H205V14Q100 26 -5 14Z", "#000000", 0.5, 3)
	for y in (24, 92):
		swirl_button(f, 100, y, 9)
	f.path(f"M-5 {belt_y}H205V210H-5Z", shade(UNI["base"], 0.7))
	form(f)
	f = a["Torso_B"]
	jacket_back(f, UNI, seed=4, hem=belt_y)
	f.path(f"M-5 {belt_y}H205V210H-5Z", shade(UNI["base"], 0.7))
	form(f)
	for name in ("Torso_L", "Torso_R"):
		f = a[name]
		jacket_side(f, UNI, seed=4, hem=belt_y)
		f.path(f"M-5 {belt_y}H105V210H-5Z", shade(UNI["base"], 0.7))
		form(f)
	a["Torso_T"].fill(UNI["base"])
	a["Torso_T"].soft("M0 0H200V30H0Z", UNI["sheen"], 0.3, 5)
	a["Torso_Bo"].fill(UNI["dark"])
	for side in ("Left", "Right"):
		for key in "FBOI":
			sleeve(a[f"{side}Arm_{key}"], UNI, key, seed=side + "n", skin=SKIN, cuff=156, hand_top=168)
			_leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(UNI["base"])
		a[f"{side}Arm_Bo"].fill(SKIN)
		a[f"{side}Leg_T"].fill("#1a1b22")
		a[f"{side}Leg_Bo"].fill("#2a1c14")
