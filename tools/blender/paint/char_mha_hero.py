# Painted look for mha_hero: the green hero suit, hood ears at the neck, red boots, freckles, curly hair (design doc 5).
import math
import random

from atlas import INK, face_base, paint_hair, shade, side_head
from mha_common import anime_eye, ell, fingers, loft, lr, nape, tuft

SKIN = "#f3cfae"
SKIN_D = shade(SKIN, 0.66)
GREEN = "#2a8064"
GREEN_D = shade(GREEN, 0.58)
GREEN_L = "#62bd97"
PANEL = "#17473a"
WHITE = "#eef0ea"
WHITE_D = "#b4bcc0"
RED = "#d3262b"
RED_D = shade(RED, 0.62)
RED_L = "#f46a5e"
STEEL = "#8e98a2"
HAIR_DARK = "#1B4436"
HAIR_LIT = "#245A47"
DEFAULT = GREEN
HAIR_COLOURS = [HAIR_DARK, HAIR_LIT]
HAIR = {"colour": HAIR_DARK, "locks": []}

PROPS = [
	# belt with a buckle and pouches
	{"part": "LowerTorso", "box": [2.08, 1.08, 0.2], "at": [0, 0, 2.5], "colour": "#26262C", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.42, 0.08, 0.28], "at": [0, -0.55, 2.5], "colour": "#E8B63A", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.3, 0.16, 0.3], "at": [0.62, -0.56, 2.46], "colour": "#EEF0EA", "bevel": 0.04, "mirror": True},
	{"part": "LowerTorso", "box": [0.3, 0.16, 0.3], "at": [0.42, 0.56, 2.46], "colour": "#EEF0EA", "bevel": 0.04, "mirror": True},
	# steel mouth guard hanging under the chin
	{"part": "UpperTorso", "box": [0.86, 0.14, 0.3], "at": [0, -0.56, 3.84], "colour": "#8E98A2", "bevel": 0.05},
	{"part": "UpperTorso", "box": [0.14, 0.03, 0.15], "at": [0.26, -0.635, 3.83], "colour": "#23262C", "bevel": 0.005, "mirror": True},
	{"part": "UpperTorso", "box": [0.14, 0.03, 0.15], "at": [0, -0.635, 3.83], "colour": "#23262C", "bevel": 0.005},
	{"part": "UpperTorso", "box": [1.24, 0.1, 0.09], "at": [0, -0.53, 3.97], "colour": "#23262C", "bevel": 0.01},
	# fallen hood behind the neck with its two ears
	{"part": "UpperTorso", "box": [1.5, 0.5, 0.42], "at": [0, 0.42, 3.86], "colour": "#17473A", "bevel": 0.12},
	{"part": "UpperTorso", "blade": [[0.56, 3.92], [1.0, 3.92], [1.14, 4.66], [0.72, 4.3]], "y": [0.12, 0.42], "colour": "#2A8064", "mirror": True},
]
# knee pads, elbow pads, glove cuffs, boots
for p in (
	dict(part="UpperLeg", box=[0.8, 0.14, 0.44], at=[0.5, -0.5, 1.06], colour="#33373F", bevel=0.05),
	dict(part="UpperLeg", box=[0.4, 0.05, 0.14], at=[0.5, -0.585, 1.08], colour="#8E98A2", bevel=0.01),
		dict(part="LowerArm", box=[1.08, 1.08, 0.2], at=[1.5, 0, 2.5], colour="#EEF0EA", bevel=0.04),
	dict(part="LowerArm", box=[1.1, 0.5, 0.08], at=[1.5, 0, 2.54], colour="#2A8064", bevel=0.01),
	dict(part="Foot", box=[1.04, 1.34, 0.32], at=[0.5, -0.13, 0.17], colour="#D3262B", bevel=0.09),
	dict(part="Foot", box=[1.08, 1.4, 0.1], at=[0.5, -0.13, 0.05], colour="#EEF0EA", bevel=0.03),
	dict(part="Foot", box=[0.56, 0.1, 0.16], at=[0.5, -0.78, 0.22], colour="#EEF0EA", bevel=0.03),
	dict(part="LowerLeg", box=[1.06, 1.06, 0.1], at=[0.5, 0, 0.82], colour="#EEF0EA", bevel=0.02),
):
	part = p.pop("part")
	PROPS.extend(lr(part, **p))


def model(parts, kit):
	head = parts["Head"]
	# rounded skull under the curls, behind the face plane
	loft(kit, "Head_Mass", [(0, 0.14, 4.3, 0.68, 0.52), (0, 0.1, 4.75, 0.78, 0.62), (0, 0.02, 5.15, 0.8, 0.72), (0, 0, 5.42, 0.62, 0.56), (0, 0, 5.54, 0.3, 0.26)], HAIR_DARK, head, sides=12, power=2.6, root=(0, 0, 5.5), tip=(0, 0, 4.3))
	r = random.Random("curls")
	n = 0

	def curl(base, d, length, rad, bend, lit=False):
		nonlocal n
		n += 1
		tuft(kit, f"Head_Curl{n}", base, d, length, rad, bend, HAIR_LIT if lit else HAIR_DARK, head)

	# rows round the head, top to nape: each lock leans out, then rolls over into a pointed hook
	for el, count, ln, rad in ((70, 6, 0.95, 0.25), (40, 10, 1.0, 0.25), (12, 10, 0.9, 0.24), (-24, 8, 0.72, 0.22)):
		for i in range(count):
			az = 2 * math.pi * (i + r.uniform(0.1, 0.5) + el * 0.01) / count
			ce, se = math.cos(math.radians(el)), math.sin(math.radians(el))
			out = (math.cos(az) * ce, math.sin(az) * ce, se)
			base = (0.6 * out[0], 0.04 + 0.54 * out[1], 5.0 + 0.42 * out[2])
			if el < 30 and base[1] < -0.2:
				continue  # the face stays clear
			swirl = 1 if i % 2 else -1
			bend = (-out[1] * swirl * 2.6, out[0] * swirl * 2.6, -1.6 - r.uniform(0, 1.0))
			curl(base, (out[0], out[1], out[2] * 0.7 + 0.25), ln * r.uniform(0.9, 1.1), rad * r.uniform(0.9, 1.1), bend, lit=i % 3 == 0)
	# fringe: hooked bangs falling on the forehead, none past the brows
	for i, (x, tx, z, b) in enumerate(((-0.58, -0.3, 5.26, 2.2), (-0.36, -0.2, 5.34, -2.0), (-0.12, -0.1, 5.38, 2.0), (0.12, 0.1, 5.38, -2.0), (0.36, 0.2, 5.34, 2.0), (0.58, 0.3, 5.26, -2.2))):
		curl((x, -0.48, z), (tx, -0.5, -0.1), 0.72, 0.22, (b, 0.1, -2.6), lit=i % 2 == 1)
	# sideburn curls at the temples
	for sgn in (1, -1):
		curl((sgn * 0.62, -0.42, 5.02), (sgn * 0.5, -0.2, -0.4), 0.6, 0.17, (-sgn * 1.6, -0.3, -1.2))
		curl((sgn * 0.68, -0.2, 4.72), (sgn * 0.6, -0.1, -0.5), 0.55, 0.17, (-sgn * 1.4, 0.4, -1.2), lit=True)


def freckles(f, cx, cy):
	for dx, dy in ((-6, -2), (0, -5), (6, -2), (0, 2)):
		f.path(ell(cx + dx, cy + dy, 1.5, 1.3), "#a3603f")


def arm(f, key):
	f.fill(GREEN)
	f.soft("M-5-5H105V18Q50 26 -5 18Z", GREEN_L, 0.45, 3)
	f.taper(10, 34, 50, 44, 90, 34, 1.4, PANEL)
	f.folds(4, GREEN_D, GREEN_L, y0=0.02, y1=0.4, pinch=(50, 96))
	f.folds(4, GREEN_D, GREEN_L, y0=0.52, y1=0.72, pinch=(50, 100))
	if key == "O":  # white line down the outer sleeve
		f.path("M44-5H56V146H44Z", WHITE, stroke=INK, sw=1.2)
	if key == "B":  # elbow pad
		f.path("M22 78H78V112H22Z", "#33373f", stroke=INK, sw=1.3)
		f.path("M36 88H64V102H36Z", STEEL)
	# glove
	f.path("M-5 150H105V210H-5Z", WHITE)
	f.soft("M-5 166H105V210H-5Z", WHITE_D, 0.55, 3)
	f.ink("M-5 150H105", 1.5)
	if key in "FB":
		f.path("M12 168H88V184H12Z", "#c9ced2", stroke=INK, sw=1)
		fingers(f, 188, 205, "#5a6068")
	f.edges()


def leg(f, key):
	f.fill(GREEN)
	f.folds(3, GREEN_D, GREEN_L, y0=0.02, y1=0.34, pinch=(50, 84))
	f.folds(2, GREEN_D, GREEN_L, y0=0.58, y1=0.66, pinch=(50, 112))
	if key in "FB":  # white piping at the thigh
		f.path("M10-5H22L34 74H24Z", WHITE, stroke=INK, sw=1)
		f.path("M90-5H78L66 74H76Z", WHITE, stroke=INK, sw=1)
	if key == "O":
		f.path("M44-5H56V118H44Z", WHITE, stroke=INK, sw=1.1)
	# high red boot
	f.path("M-5 118H105V205H-5Z", RED)
	f.folds(3, RED_D, RED_L, y0=0.62, y1=0.86, pinch=(50, 186))
	f.ink("M-5 118H105", 1.6)
	if key == "F":
		f.path("M28 128H72L66 178H34Z", WHITE, stroke=INK, sw=1.2)
		for y in (136, 148, 160, 172):
			f.ink(f"M32 {y}L68 {y - 3}", 1.6, "#26262c")
	if key == "B":
		f.path("M38 124H62V190H38Z", WHITE, stroke=INK, sw=1.2)
	if key in "OI":
		f.ink("M-5 158Q50 150 105 170", 1.4)
		f.path("M-5 160Q50 152 105 172V180Q50 162 -5 168Z", RED_D, opacity=0.8)
	f.edges()


def paint(a):
	paint_hair(a, ["#163c30", "#245e4b"])
	# ---- face: huge round eyes, set jaw, freckles
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=46)
	anime_eye(f, 38, 66, -1, "#27a067", w=27, h=21, arch=1.05, tilt=0.5, ir=9.6, lash=3.4, pupil=0.36)
	anime_eye(f, 92, 66, 1, "#27a067", w=27, h=21, arch=1.05, tilt=0.5, ir=9.6, lash=3.4, pupil=0.36)
	# short, fine brows pulled together
	f.path("M49 51Q38 44 25 46Q37 46 47 55Z", HAIR_DARK)
	f.path("M81 51Q92 44 105 46Q93 46 83 55Z", HAIR_DARK)
	freckles(f, 25, 88)
	freckles(f, 105, 88)
	# clenched mouth, teeth showing
	f.path("M45 104Q65 100 85 104Q84 115 65 116Q46 115 45 104Z", "#fbf8f4", stroke=INK, sw=1.6)
	f.ink("M46 109H84", 0.8, "#6a5a5a")
	for x in (53, 60, 67, 74):
		f.ink(f"M{x} 104V115", 0.7, "#6a5a5a")
	f.taper(40, 100, 42, 106, 46, 110, 0.8, shade(SKIN, 0.5))
	f.taper(90, 100, 88, 106, 84, 110, 0.8, shade(SKIN, 0.5))
	f.taper(50, 123, 65, 126, 80, 123, 0.8, shade(SKIN, 0.55))
	# ---- torso front
	f = a["Torso_F"]
	f.fill(GREEN)
	f.path("M-5-5H36L60 150H-5Z", PANEL, opacity=0.55)
	f.path("M205-5H164L140 150H205Z", PANEL, opacity=0.55)
	f.soft("M40 30Q70 18 94 34Q92 58 66 66Q44 58 40 30Z", GREEN_L, 0.5, 5)
	f.soft("M160 30Q130 18 106 34Q108 58 134 66Q156 58 160 30Z", GREEN_L, 0.5, 5)
	f.taper(38, 62, 68, 74, 98, 60, 2)
	f.taper(162, 62, 132, 74, 102, 60, 2)
	f.taper(100, 40, 101, 80, 100, 138, 1.3)
	for y in (82, 102, 122):
		f.taper(76, y, 88, y + 3, 98, y - 1, 1.1)
		f.taper(124, y, 112, y + 3, 102, y - 1, 1.1)
	f.folds(4, GREEN_D, GREEN_L, y0=0.36, y1=0.66, pinch=(100, 136))
	# white V piping from the shoulders down to the belt
	f.path("M28-5H46L108 104V140H92V110Z", WHITE, stroke=INK, sw=1.4)
	f.path("M172-5H154L92 104V140H108V110Z", WHITE, stroke=INK, sw=1.4)
	f.path("M92 104L100 92L108 104V140H92Z", PANEL, stroke=INK, sw=1.2)
	f.path("M-5 160H205V205H-5Z", GREEN)
	f.folds(4, GREEN_D, GREEN_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges()
	# ---- torso back: same piping, a dark yoke
	f = a["Torso_B"]
	f.fill(GREEN)
	f.path("M-5-5H205V50Q100 80 -5 50Z", PANEL)
	f.ink("M-5 50Q100 80 205 50", 1.8)
	f.path("M28 50L100 110L172 50L172 72L100 134L28 72Z", WHITE, stroke=INK, sw=1.4)
	f.taper(100, 134, 101, 148, 100, 160, 1.4)
	f.taper(40, 30, 70, 40, 95, 30, 1.6, "#0d2b23")
	f.taper(160, 30, 130, 40, 105, 30, 1.6, "#0d2b23")
	f.folds(4, GREEN_D, GREEN_L, y0=0.46, y1=0.66, pinch=(100, 136))
	f.folds(4, GREEN_D, GREEN_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(PANEL)
		f.path("M30-5H70L66 205H34Z", GREEN)
		f.path("M44-5H56L54 140H46Z", WHITE, stroke=INK, sw=1.2)
		f.folds(4, GREEN_D, GREEN_L, y0=0.2, y1=0.66, pinch=(50, 136))
		f.folds(2, GREEN_D, GREEN_L, y0=0.8, y1=0.96, pinch=(50, 190))
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			arm(a[f"{side}Arm_{key}"], key)
			leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(GREEN)
		a[f"{side}Arm_Bo"].fill(WHITE)
		a[f"{side}Leg_T"].fill(GREEN)
		a[f"{side}Leg_Bo"].fill("#eef0ea")
	nape(a["Head_B"], SKIN, "#17382d", 96)
	a["Head_T"].fill("#17382d")
	a["Head_Bo"].fill(SKIN_D)
	side_head(a["Head_L"], SKIN, "#17382d", 1)
	side_head(a["Head_R"], SKIN, "#17382d", -1)
	a["Torso_T"].fill(PANEL)
	a["Torso_Bo"].fill(GREEN_D)
