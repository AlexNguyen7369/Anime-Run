# Painted look for mha_blast: black sleeveless suit, orange X, eye mask, grenade gauntlets (design doc 5).
import math
import random

from atlas import INK, face_base, paint_hair, shade, side_head
from mha_common import anime_eye, fingers, loft, lr, nape, torus, tube

SKIN = "#f2cfae"
SKIN_D = shade(SKIN, 0.66)
BLACK = "#201f26"
BLACK_L = "#4c4b58"
BLACK_D = "#0e0d12"
ORANGE = "#f2861a"
ORANGE_D = shade(ORANGE, 0.64)
ORANGE_L = "#ffc06a"
OLIVE = "#53613c"
HAIR_C = "#E8D585"
DEFAULT = BLACK
HAIR_COLOURS = [HAIR_C]
HAIR = {"colour": HAIR_C, "locks": []}

PROPS = [
	# neck brace
	{"part": "UpperTorso", "box": [1.34, 1.1, 0.2], "at": [0, 0.02, 3.97], "colour": "#201F26", "bevel": 0.05},
	{"part": "UpperTorso", "box": [1.4, 0.2, 0.07], "at": [0, -0.5, 3.9], "colour": "#F2861A", "bevel": 0.01},
	# belt with grenade pouches
	{"part": "LowerTorso", "box": [2.08, 1.08, 0.2], "at": [0, 0, 2.46], "colour": "#3A3A42", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.46, 0.08, 0.3], "at": [0, -0.56, 2.46], "colour": "#F2861A", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.3, 0.2, 0.34], "at": [0.62, -0.58, 2.4], "colour": "#53613C", "bevel": 0.06, "mirror": True},
	{"part": "LowerTorso", "box": [0.3, 0.2, 0.34], "at": [0.62, 0.58, 2.4], "colour": "#53613C", "bevel": 0.06, "mirror": True},
	{"part": "LowerTorso", "box": [0.3, 0.2, 0.34], "at": [0.1, 0.58, 2.4], "colour": "#53613C", "bevel": 0.06, "mirror": True},
	# mask wings flaring from the temples
	{"part": "Head", "blade": [[0.6, 4.78], [0.84, 4.98], [0.74, 4.7], [0.6, 4.58]], "y": [-0.56, -0.36], "colour": "#17161B", "mirror": True},
]
for p in (
	# knee guards: black shell with an orange bar
	dict(part="UpperLeg", box=[0.84, 0.16, 0.5], at=[0.5, -0.5, 1.02], colour="#17161B", bevel=0.06),
	dict(part="UpperLeg", box=[0.5, 0.05, 0.13], at=[0.5, -0.59, 1.02], colour="#F2861A", bevel=0.01),
	# heavy boots
	dict(part="Foot", box=[1.06, 1.34, 0.34], at=[0.5, -0.14, 0.18], colour="#17161B", bevel=0.09),
	dict(part="Foot", box=[1.1, 1.4, 0.1], at=[0.5, -0.14, 0.05], colour="#F2861A", bevel=0.03),
	dict(part="Foot", box=[0.62, 0.1, 0.18], at=[0.5, -0.8, 0.24], colour="#F2861A", bevel=0.03),
	dict(part="LowerLeg", box=[1.06, 1.06, 0.12], at=[0.5, 0, 0.74], colour="#F2861A", bevel=0.02),
):
	part = p.pop("part")
	PROPS.extend(lr(part, **p))


def gauntlet(kit, part, sgn):
	"""A grenade strapped over the forearm: fat ribbed body, bright bands, a spoon up the outside and a pin ring."""
	cx = sgn * 1.52
	loft(kit, part.name + "_NadeBody", [(cx, 0, 2.3, 0.62, 0.62), (cx, 0, 2.44, 0.76, 0.76), (cx, 0, 2.7, 0.82, 0.82), (cx, 0, 2.98, 0.76, 0.76), (cx, 0, 3.12, 0.62, 0.62)], "#53613C", part, sides=14, power=2.3)
	loft(kit, part.name + "_NadeBand", [(cx, 0, 2.56, 0.835, 0.835), (cx, 0, 2.7, 0.845, 0.845), (cx, 0, 2.84, 0.835, 0.835)], "#2B2B31", part, sides=14, power=2.3)
	loft(kit, part.name + "_NadeCuff", [(cx, 0, 2.14, 0.6, 0.6), (cx, 0, 2.2, 0.66, 0.66), (cx, 0, 2.34, 0.66, 0.66), (cx, 0, 2.38, 0.6, 0.6)], "#F2861A", part, sides=14, power=2.3)
	loft(kit, part.name + "_NadeTop", [(cx, 0, 3.08, 0.62, 0.62), (cx, 0, 3.14, 0.66, 0.66), (cx, 0, 3.24, 0.62, 0.62), (cx, 0, 3.28, 0.5, 0.5)], "#F2C230", part, sides=14, power=2.3)
	# ribs of the pineapple body
	for k in range(6):
		a = math.radians(30 + k * 60)
		x, y = cx + 0.84 * math.cos(a), 0.84 * math.sin(a)
		kit.rbox(part.name + f"_NadeRib{k}", (0.12, 0.12, 0.52), (x, y, 2.7), "#3C4730", part, bevel=0.03, rot=(0, 0, a))
	# spoon lever on the outside and the ring pin
	ox = sgn * (1.52 + 0.84)
	kit.rbox(part.name + "_NadeSpoon", (0.14, 0.34, 0.82), (ox + sgn * 0.02, 0, 2.86), "#AEB4BC", part, bevel=0.03)
	torus(kit, part.name + "_NadeRing", (ox + sgn * 0.12, 0.36, 3.12), True, 0.2, 0.035, "#D8DCE2", part)


def model(parts, kit):
	head = parts["Head"]
	loft(kit, "Head_Mass", [(0, 0.14, 4.42, 0.7, 0.52), (0, 0.1, 4.8, 0.78, 0.62), (0, 0.02, 5.15, 0.8, 0.72), (0, 0, 5.4, 0.66, 0.6), (0, 0, 5.55, 0.3, 0.3)], HAIR_C, head, sides=12, power=2.6, root=(0, 0, 5.5), tip=(0, 0, 4.4))
	r = random.Random("blast")
	n = 0

	def spike(base, d, length, rad, droop=0.0):
		nonlocal n
		n += 1
		s = [base]
		dv = [d[0], d[1], d[2]]
		m = math.sqrt(sum(c * c for c in dv))
		dv = [c / m for c in dv]
		p = list(base)
		for i in range(4):
			p = [p[0] + dv[0] * length / 4, p[1] + dv[1] * length / 4, p[2] + dv[2] * length / 4 - droop * (i / 3) * length * 0.1]
			s.append(tuple(p))
		tube(kit, f"Head_Spike{n}", s, [rad, rad * 0.86, rad * 0.56, rad * 0.26, 0.0], HAIR_C, head, flatten=0.62)

	# an explosion: long sharp spikes blown out in every direction, longest up and out, short at the nape
	for el, count, ln, rad in ((82, 3, 1.25, 0.32), (58, 8, 1.35, 0.34), (32, 11, 1.3, 0.33), (6, 11, 1.1, 0.3), (-24, 9, 0.8, 0.26)):
		for i in range(count):
			az = 2 * math.pi * (i + 0.5 * (el % 2) + r.uniform(-0.18, 0.18)) / count
			ce, se = math.cos(math.radians(el)), math.sin(math.radians(el))
			out = (math.cos(az) * ce, math.sin(az) * ce, se)
			base = (0.58 * out[0], 0.04 + 0.52 * out[1], 5.0 + 0.4 * out[2])
			if el < 30 and base[1] < -0.28:
				continue  # the face stays clear
			lift = 0.28 if el < 40 else 0.1  # even the low spikes kick upwards
			spike(base, (out[0] + r.uniform(-0.2, 0.2), out[1] + r.uniform(-0.2, 0.2), out[2] + lift), ln * r.uniform(0.85, 1.12), rad * r.uniform(0.92, 1.1))
	# jagged fringe, stabbing down over the mask
	for x, z, dx, ln in ((-0.56, 5.3, -0.22, 0.6), (-0.34, 5.34, 0.12, 0.68), (-0.1, 5.38, -0.14, 0.72), (0.14, 5.38, 0.12, 0.68), (0.38, 5.34, -0.1, 0.72), (0.58, 5.3, 0.25, 0.6)):
		spike((x, -0.5, z), (dx, -0.34, -1), ln, 0.2)
	# a second layer starts higher and hides the top of the forehead
	for x, dx in ((-0.46, -0.5), (-0.22, -0.2), (0.0, 0.1), (0.24, 0.25), (0.46, 0.5)):
		spike((x, -0.42, 5.42), (dx, -0.7, -0.45), 0.72, 0.22)
	# short spikes dropping over the nape
	for i, x in enumerate((-0.54, -0.32, -0.1, 0.12, 0.34, 0.56)):
		spike((x, 0.5, 4.62 + (i % 2) * 0.06), (x * 0.5, 0.42, -1), 0.56, 0.2)
	# side spikes kicked out above the ears
	for sgn in (1, -1):
		spike((sgn * 0.64, -0.34, 5.08), (sgn * 1, -0.35, 0.1), 0.92, 0.19)
		spike((sgn * 0.68, -0.14, 4.82), (sgn * 1, -0.1, -0.3), 0.78, 0.18)
	gauntlet(kit, parts["LeftLowerArm"], 1)
	gauntlet(kit, parts["RightLowerArm"], -1)


def black_arm_low(f, key):
	"""Forearm under the gauntlet and the black glove with orange knuckle bars."""
	f.path("M-5 112H105V210H-5Z", BLACK)
	f.path("M-5 176H105V188H-5Z", ORANGE, stroke=INK, sw=1)
	if key in "FB":
		fingers(f, 190, 205, BLACK_L)


def bare_arm(f, key):
	f.fill(SKIN)
	f.soft("M-5-5H105V10Q50 22 -5 10Z", "#fff0dc", 0.5, 3)
	# deltoid, then a hard biceps/triceps split
	f.taper(6, 34, 50, 50, 94, 34, 2.0)
	f.soft("M14 52Q50 40 86 52Q84 88 50 94Q16 88 14 52Z", "#fff0dc", 0.5, 4)
	f.soft("M70 40Q92 66 74 106H105V40Z", SKIN_D, 0.75, 2)
	f.taper(18, 50, 12, 74, 28, 98, 1.6)
	f.taper(82, 50, 88, 74, 72, 98, 1.6)
	if key in "FB":
		f.taper(50, 56, 52, 72, 48, 92, 1.1, shade(SKIN, 0.5))
	black_arm_low(f, key)
	f.edges()


def leg(f, key):
	f.fill(BLACK)
	f.folds(3, BLACK_D, BLACK_L, y0=0.02, y1=0.34, pinch=(50, 84))
	if key == "O":  # orange side stripe
		f.path("M40-5H60V66H40Z", ORANGE, stroke=INK, sw=1.2)
	f.folds(3, BLACK_D, BLACK_L, y0=0.58, y1=0.7, pinch=(50, 118))
	# boot
	f.path("M-5 126H105V205H-5Z", "#17161b")
	f.ink("M-5 126H105", 1.6)
	f.folds(2, BLACK_D, BLACK_L, y0=0.68, y1=0.86, pinch=(50, 186))
	if key == "F":
		f.path("M24 130H76L70 178H30Z", OLIVE, stroke=INK, sw=1.3)
		f.path("M34 140H66M34 152H66M36 164H64", stroke=INK, sw=2)
	if key in "OI":
		f.path("M-5 160L105 150V172L-5 182Z", ORANGE, stroke=INK, sw=1.2)
	f.edges(0.3)


def paint(a):
	paint_hair(a, ["#efdc8e"])
	# ---- face: mask over the eyes, tiny red irises, a snarl
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=42)
	# mask: black band with flared upper corners, orange border, peak on the nose
	mask = "M-5 40L14 52L34 45L65 58L96 45L116 52L135 40V74L112 88L88 82L72 82L65 92L58 82L42 82L18 88L-5 74Z"
	f.path(mask, ORANGE)
	f.path("M-5 46L14 57L34 50L65 63L96 50L116 57L135 46V70L112 83L88 77L70 77L65 86L60 77L42 77L18 83L-5 70Z", "#17161b")
	f.soft("M4 58L34 54L60 66L40 74Z", "#4c4b58", 0.4, 2)
	anime_eye(f, 37, 68, -1, "#d8281e", w=25, h=11, arch=0.9, tilt=3.4, ir=3.6, lash=3.0, pupil=0.42)
	anime_eye(f, 93, 68, 1, "#d8281e", w=25, h=11, arch=0.9, tilt=3.4, ir=3.6, lash=3.0, pupil=0.42)
	# brows: ash blond, slammed down across the mask's top
	f.path("M56 58L24 44L18 48L52 63Z", "#d8c477", stroke=INK, sw=0.8)
	f.path("M74 58L106 44L112 48L78 63Z", "#d8c477", stroke=INK, sw=0.8)
	# nose
	f.ink("M61 93Q65 96 69 93", 1.1, shade(SKIN, 0.42))
	# snarl: teeth bared, one corner dragged up
	f.path("M40 104Q65 98 92 100L90 113Q66 124 44 115Z", "#fbf8f4", stroke=INK, sw=1.8)
	f.path("M41 109Q66 110 91 106", stroke=INK, sw=1)
	for i, x in enumerate(range(47, 90, 7)):
		f.path(f"M{x} {102}L{x + 3} 110L{x + 6} 102Z", "#ffffff", stroke=INK, sw=0.6)
		f.path(f"M{x + 1} {117 - i % 2}L{x + 4} 110L{x + 7} 116Z", "#ffffff", stroke=INK, sw=0.6)
	f.taper(36, 97, 37, 106, 42, 112, 1.0, shade(SKIN, 0.5))
	f.taper(96, 92, 96, 102, 91, 110, 1.0, shade(SKIN, 0.5))
	f.taper(52, 124, 66, 127, 80, 124, 0.9, shade(SKIN, 0.55))
	# ---- torso front: orange X straps over hard muscle
	f = a["Torso_F"]
	f.fill(BLACK)
	f.soft("M20 26Q58 12 94 30Q92 66 56 72Q24 64 20 26Z", BLACK_L, 0.7, 5)
	f.soft("M180 26Q142 12 106 30Q108 66 144 72Q176 64 180 26Z", BLACK_L, 0.7, 5)
	f.taper(30, 70, 62, 82, 98, 62, 2.2)
	f.taper(170, 70, 138, 82, 102, 62, 2.2)
	for y in (92, 110, 128):
		f.path(f"M64 {y}Q82 {y - 7} 97 {y - 2}V{y + 12}Q82 {y + 8} 66 {y + 13}Z", BLACK_L, opacity=0.5)
		f.path(f"M136 {y}Q118 {y - 7} 103 {y - 2}V{y + 12}Q118 {y + 8} 134 {y + 13}Z", BLACK_L, opacity=0.5)
	f.taper(100, 60, 101, 100, 100, 146, 1.6)
	f.folds(2, BLACK_D, BLACK_L, y0=0.54, y1=0.7, pinch=(100, 140))
	# the X
	for d in ("M0 0H46L204 150V154H160L0 26Z", "M200 0H154L-4 150V154H40L200 26Z"):
		f.path(d, ORANGE, stroke=INK, sw=2)
	f.path("M4 2H40L190 142Z", ORANGE_L, opacity=0.6)
	f.path("M196 2H160L10 142Z", ORANGE_L, opacity=0.6)
	f.path("M74 54L100 72L126 54L142 72L120 88L142 108L124 126L100 104L76 126L58 108L80 88L58 72Z", ORANGE_D, opacity=0.35)
	f.path("M100 62L124 86L100 112L76 86Z", "#3a3a42", stroke=INK, sw=2)
	f.path("M100 70L116 86L100 104L84 86Z", "#5a5a66")
	f.path("M-5 160H205V205H-5Z", BLACK)
	f.folds(4, BLACK_D, BLACK_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges(0.3)
	# ---- torso back: the X crosses behind too
	f = a["Torso_B"]
	f.fill(BLACK)
	f.taper(100, 8, 101, 80, 100, 150, 1.8)
	f.soft("M20 22Q60 14 94 26Q90 70 48 66Q24 58 20 22Z", BLACK_L, 0.6, 5)
	f.soft("M180 22Q140 14 106 26Q110 70 152 66Q176 58 180 22Z", BLACK_L, 0.6, 5)
	for d in ("M0 0H34L204 150V154H170L0 20Z", "M200 0H166L-4 150V154H30L200 20Z"):
		f.path(d, ORANGE, stroke=INK, sw=2)
	f.path("M100 62L118 80L100 100L82 80Z", "#3a3a42", stroke=INK, sw=2)
	f.folds(4, BLACK_D, BLACK_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges(0.3)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(BLACK)
		f.path("M-5 20L105 8V24L-5 38Z", ORANGE, stroke=INK, sw=1.4)
		f.folds(4, BLACK_D, BLACK_L, y0=0.25, y1=0.66, pinch=(50, 136))
		f.folds(2, BLACK_D, BLACK_L, y0=0.8, y1=0.96, pinch=(50, 190))
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			bare_arm(a[f"{side}Arm_{key}"], key)
			leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(BLACK)
		a[f"{side}Leg_T"].fill(BLACK)
		a[f"{side}Leg_Bo"].fill("#17161b")
	hair = "#b8a766"
	nape(a["Head_B"], SKIN, hair, 84)
	a["Head_T"].fill(hair)
	a["Head_Bo"].fill(SKIN_D)
	side_head(a["Head_L"], SKIN, hair, 1)
	side_head(a["Head_R"], SKIN, hair, -1)
	# the mask's strap runs round the head
	for n in ("Head_L", "Head_R"):
		f = a[n]
		front_left = n == "Head_L"
		f.path("M-5 50H125V68H-5Z" if not front_left else "M-5 50H125V68H-5Z", "#17161b", stroke=ORANGE, sw=1.2)
	a["Torso_T"].fill(BLACK)
	a["Torso_Bo"].fill(BLACK)
