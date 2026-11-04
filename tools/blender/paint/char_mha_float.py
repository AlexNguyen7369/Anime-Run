# Painted look for mha_float: black and pink suit, ring collar, chunky cuffs, round bob, blush circles (design doc 5).
from atlas import INK, face_base, paint_hair, shade, side_head
from mha_common import anime_eye, ell, loft, lr, tube

SKIN = "#f8dcc8"
SKIN_D = shade(SKIN, 0.72)
BLACK = "#22212b"
BLACK_L = "#50505f"
BLACK_D = "#101016"
PINK = "#f29ab2"
PINK_D = shade(PINK, 0.68)
PINK_L = "#ffd0dc"
BLUSH = "#ee8f90"
HAIR_C = "#6B4630"
DEFAULT = BLACK
HAIR_COLOURS = [HAIR_C]
HAIR = {"colour": HAIR_C, "locks": []}

PROPS = [
	# the thick ring collar sits round the neck
	{"part": "LowerTorso", "box": [2.06, 1.06, 0.14], "at": [0, 0, 2.44], "colour": "#F4F1EC", "bevel": 0.02},
	{"part": "LowerTorso", "box": [0.42, 0.08, 0.26], "at": [0, -0.54, 2.44], "colour": "#F29AB2", "bevel": 0.03},
]
for p in (
	# chunky ankle pads and pink-topped boots
	dict(part="LowerLeg", box=[1.12, 1.12, 0.3], at=[0.5, 0, 0.72], colour="#F29AB2", bevel=0.09),
	dict(part="LowerLeg", box=[0.98, 1.02, 0.08], at=[0.5, 0, 0.92], colour="#22212B", bevel=0.01),
	dict(part="Foot", box=[1.04, 1.3, 0.3], at=[0.5, -0.12, 0.16], colour="#22212B", bevel=0.1),
	dict(part="Foot", box=[1.08, 1.36, 0.08], at=[0.5, -0.12, 0.04], colour="#F29AB2", bevel=0.03),
	dict(part="Foot", box=[0.5, 0.1, 0.14], at=[0.5, -0.76, 0.22], colour="#F29AB2", bevel=0.03),
	# knee pads
	dict(part="UpperLeg", box=[0.76, 0.14, 0.34], at=[0.5, -0.5, 1.1], colour="#F29AB2", bevel=0.05),
):
	part = p.pop("part")
	PROPS.extend(lr(part, **p))


def model(parts, kit):
	head = parts["Head"]
	# the bob: full and rounded, swelling at the jaw, then tucked in at the nape
	loft(kit, "Head_Mass", [(0, 0.2, 4.08, 0.58, 0.46), (0, 0.14, 4.3, 0.78, 0.56), (0, 0.1, 4.62, 0.82, 0.64), (0, 0.02, 5.05, 0.8, 0.72), (0, 0, 5.32, 0.68, 0.64), (0, 0, 5.47, 0.34, 0.3)], HAIR_C, head, sides=18, power=2.4, root=(0, 0, 5.47), tip=(0, 0, 4.08))
	n = 0

	def s(pts, r, flatten=0.4):
		nonlocal n
		n += 1
		tube(kit, f"Head_Bob{n}", pts, [r * 0.75, r, r * 0.95, r * 0.7, 0], HAIR_C, head, flatten=flatten)

	# fringe: short pointed bangs in an arc, a gap above the nose
	for sgn in (1, -1):
		s([(sgn * 0.05, -0.54, 5.46), (sgn * 0.1, -0.66, 5.3), (sgn * 0.14, -0.68, 5.12), (sgn * 0.16, -0.68, 5.0), (sgn * 0.13, -0.68, 4.86)], 0.15)
		s([(sgn * 0.16, -0.52, 5.46), (sgn * 0.3, -0.66, 5.28), (sgn * 0.36, -0.68, 5.1), (sgn * 0.38, -0.68, 4.98), (sgn * 0.33, -0.68, 4.84)], 0.16)
		s([(sgn * 0.3, -0.5, 5.42), (sgn * 0.5, -0.64, 5.22), (sgn * 0.56, -0.68, 5.04), (sgn * 0.56, -0.68, 4.92), (sgn * 0.5, -0.68, 4.8)], 0.15)
		# two long front locks framing the face to the jaw, tips curling in
		s([(sgn * 0.54, -0.42, 5.32), (sgn * 0.7, -0.62, 4.9), (sgn * 0.7, -0.67, 4.46), (sgn * 0.66, -0.68, 4.22), (sgn * 0.54, -0.68, 4.02)], 0.17)
		s([(sgn * 0.66, -0.3, 5.2), (sgn * 0.84, -0.46, 4.76), (sgn * 0.84, -0.48, 4.32), (sgn * 0.82, -0.48, 4.14), (sgn * 0.74, -0.5, 3.98)], 0.17)
		# bob sides and back: wide flat shingles, tips kicking out a little at the jaw line
		for y, rr in ((-0.14, 0.2), (0.14, 0.22), (0.42, 0.2)):
			s([(sgn * 0.7, y, 5.24), (sgn * 0.88, y + 0.02, 4.82), (sgn * 0.92, y + 0.02, 4.42), (sgn * 0.96, y + 0.03, 4.22), (sgn * 1.06, y + 0.05, 4.1)], rr)
		for x, rr in ((0.14, 0.22), (0.42, 0.22), (0.66, 0.2)):
			s([(sgn * x * 0.8, 0.54, 5.3), (sgn * x, 0.78, 4.86), (sgn * x, 0.82, 4.46), (sgn * x * 1.05, 0.84, 4.24), (sgn * x * 1.16, 0.92, 4.08)], rr)
		s([(sgn * 0.1, 0.1, 5.5), (sgn * 0.42, 0.14, 5.5), (sgn * 0.7, 0.16, 5.3), (sgn * 0.82, 0.16, 5.1), (sgn * 0.88, 0.16, 4.92)], 0.24)
		s([(sgn * 0.1, -0.24, 5.5), (sgn * 0.38, -0.3, 5.48), (sgn * 0.66, -0.34, 5.3), (sgn * 0.76, -0.36, 5.14), (sgn * 0.82, -0.38, 4.96)], 0.22)
		s([(sgn * 0.08, 0.34, 5.48), (sgn * 0.28, 0.54, 5.4), (sgn * 0.42, 0.72, 5.16), (sgn * 0.46, 0.76, 5.0), (sgn * 0.48, 0.8, 4.82)], 0.22)
	# round neck ring: black with a pink lip, rests on the shoulders
	torso = parts["UpperTorso"]
	loft(kit, "UpperTorso_Ring", [(0, 0, 3.82, 0.8, 0.68), (0, 0, 3.9, 0.92, 0.76), (0, 0, 4.02, 0.9, 0.74), (0, 0, 4.1, 0.78, 0.66)], "#22212B", torso, sides=16, power=2.6)
	loft(kit, "UpperTorso_RingLip", [(0, 0, 3.78, 0.86, 0.72), (0, 0, 3.82, 0.97, 0.8), (0, 0, 3.87, 0.97, 0.8), (0, 0, 3.9, 0.86, 0.72)], "#F29AB2", torso, sides=16, power=2.6)
	# chunky rounded wrist cuffs and the pink pads of the palms
	for sgn, side in ((1, "Left"), (-1, "Right")):
		arm = parts[f"{side}LowerArm"]
		cx = sgn * 1.5
		loft(kit, arm.name + "_Cuff", [(cx, 0, 2.3, 0.56, 0.56), (cx, 0, 2.38, 0.66, 0.66), (cx, 0, 2.66, 0.66, 0.66), (cx, 0, 2.76, 0.56, 0.56)], "#F29AB2", arm, sides=14, power=3.5)
		loft(kit, arm.name + "_CuffBand", [(cx, 0, 2.46, 0.675, 0.675), (cx, 0, 2.52, 0.685, 0.685), (cx, 0, 2.58, 0.675, 0.675)], "#22212B", arm, sides=14, power=3.5)


def pad_row(f, y):
	"""The round pads on her fingertips."""
	for x in (26, 50, 74):
		f.path(ell(x, y, 8), PINK, stroke=INK, sw=1.2)
		f.path(ell(x - 1.5, y - 2, 3), PINK_L)


def arm(f, key):
	f.fill(BLACK)
	f.soft("M-5-5H105V12Q50 22 -5 12Z", BLACK_L, 0.6, 3)
	# pink shoulder cap, curved lower edge
	f.path("M-5-5H105V40Q50 62 -5 40Z", PINK)
	f.soft("M-5 26Q50 48 105 26V42Q50 64 -5 42Z", PINK_D, 0.6, 2)
	f.ink("M-5 40Q50 62 105 40", 1.6)
	f.taper(20, 10, 50, 16, 80, 10, 1.0, PINK_L)
	f.folds(3, BLACK_D, BLACK_L, y0=0.32, y1=0.6, pinch=(50, 124))
	# glove
	if key in "FB":
		pad_row(f, 184)
	f.edges()


def leg(f, key):
	f.fill(BLACK)
	# pink thigh panel with a rounded edge, black inner seam
	f.path("M-5 22Q50 12 105 22V70Q50 88 -5 70Z", PINK)
	f.soft("M-5 56Q50 74 105 56V72Q50 90 -5 72Z", PINK_D, 0.6, 2)
	f.ink("M-5 22Q50 12 105 22M-5 70Q50 88 105 70", 1.6)
	f.taper(16, 34, 50, 28, 84, 34, 1.0, PINK_L)
	f.folds(2, BLACK_D, BLACK_L, y0=0.46, y1=0.56, pinch=(50, 104))
	f.folds(2, BLACK_D, BLACK_L, y0=0.68, y1=0.78, pinch=(50, 144))
	if key == "F":
		f.path("M26 160H74L68 200H32Z", BLACK_L, stroke=INK, sw=1)
	f.edges()


def paint(a):
	paint_hair(a, ["#80573c"])
	# ---- face: large round eyes, thin high brows, a steady open grin, her round blush
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=46)
	anime_eye(f, 38, 67, -1, "#7a4526", w=28, h=23, arch=1.08, tilt=0.2, ir=9.8, lash=3.2, pupil=0.42)
	anime_eye(f, 92, 67, 1, "#7a4526", w=28, h=23, arch=1.08, tilt=0.2, ir=9.8, lash=3.2, pupil=0.42)
	# lashes flicked at the outer corners
	f.path("M24 62L19 56L26 59Z", INK)
	f.path("M106 62L111 56L104 59Z", INK)
	f.path("M50 48Q38 41 25 46Q37 44 50 50Z", "#5a3a26")
	f.path("M80 48Q92 41 105 46Q93 44 80 50Z", "#5a3a26")
	# the round blush circles with their hatch
	for cx in (22, 108):
		f.path(ell(cx, 89, 12, 8), BLUSH, opacity=0.85, blur=1)
		f.path(ell(cx, 89, 9, 5.6), "#e87c80", opacity=0.75)
		for dx in (-4, 0, 4):
			f.ink(f"M{cx + dx + 1.5} 85.5L{cx + dx - 1.5} 92.5", 0.8, "#b84a50")
	# mouth, open and upbeat, one tooth band
	f.path("M50 102Q65 106 80 102Q78 117 65 118Q52 117 50 102Z", "#6a1a20", stroke=INK, sw=1.4)
	f.path("M52 103Q65 107 78 103L77 107Q65 110 53 107Z", "#fbf8f4")
	f.path("M56 114Q65 109 74 114Q65 119 56 114Z", "#d9555c")
	f.ink("M61 90Q65 92 69 90", 0.8, shade(SKIN, 0.5))
	# ---- torso front: black suit, the pink chest panel on curved seams, pink hip panels
	f = a["Torso_F"]
	f.fill(BLACK)
	f.path("M-5-5H205V40Q194 76 150 92Q124 100 100 122Q76 100 50 92Q6 76 -5 40Z", PINK, stroke=INK, sw=2)
	f.soft("M20 54Q60 96 100 112Q140 96 180 54V72Q140 106 100 122Q60 106 20 72Z", PINK_D, 0.7, 3)
	f.soft("M10 8H190V24H10Z", PINK_L, 0.6, 4)
	f.taper(100, 30, 101, 76, 100, 116, 1.2, PINK_D)
	f.taper(24, 44, 60, 58, 90, 52, 1.1, PINK_D)
	f.taper(176, 44, 140, 58, 110, 52, 1.1, PINK_D)
	# black waist with soft folds, pink hip panels under the belt
	f.folds(4, BLACK_D, BLACK_L, y0=0.56, y1=0.74, pinch=(100, 146))
	f.path("M-5 110Q14 134 30 150H-5Z", PINK, stroke=INK, sw=1.6)
	f.path("M205 110Q186 134 170 150H205Z", PINK, stroke=INK, sw=1.6)
	f.folds(4, BLACK_D, BLACK_L, y0=0.82, y1=0.97, pinch=(100, 196))
	f.taper(100, 160, 101, 180, 100, 205, 1.4, BLACK_L)
	f.edges()
	# ---- torso back: pink yoke, black below, a padded spine strip
	f = a["Torso_B"]
	f.fill(BLACK)
	f.path("M-5-5H205V48Q150 94 100 96Q50 94 -5 48Z", PINK, stroke=INK, sw=2)
	f.soft("M10 56Q60 92 100 90Q140 92 190 56V68Q140 104 100 100Q60 104 10 68Z", PINK_D, 0.6, 3)
	f.path("M90 20H110V150H90Z", BLACK, stroke=INK, sw=1.4)
	for y in (40, 62, 84, 106, 128):
		f.ink(f"M92 {y}H108", 1.1, BLACK_L)
	f.folds(4, BLACK_D, BLACK_L, y0=0.56, y1=0.74, pinch=(100, 146))
	f.folds(4, BLACK_D, BLACK_L, y0=0.82, y1=0.97, pinch=(100, 196))
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(BLACK)
		f.path("M-5-5H105V50Q50 78 -5 50Z", PINK, stroke=INK, sw=1.6)
		f.path("M-5 110Q50 96 105 110V150H-5Z", PINK, stroke=INK, sw=1.5)
		f.soft("M-5 130Q50 118 105 130V150H-5Z", PINK_D, 0.6, 2)
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			arm(a[f"{side}Arm_{key}"], key)
			leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(PINK)
		a[f"{side}Arm_Bo"].fill(PINK)
		a[f"{side}Leg_T"].fill(BLACK)
		a[f"{side}Leg_Bo"].fill(PINK)
	hair = "#57392a"
	a["Head_B"].fill(hair)
	a["Head_T"].fill(hair)
	a["Head_Bo"].fill(SKIN_D)
	side_head(a["Head_L"], SKIN, hair, 1)
	side_head(a["Head_R"], SKIN, hair, -1)
	a["Torso_T"].fill(BLACK)
	a["Torso_Bo"].fill(BLACK)
