# Painted look for sea_swords, post-timeskip. Marks: scar through the closed left eye, the long chest scar from his left
# shoulder to his right hip, three ear drops, the arm tie and three swords. Drawn in-house (design doc 5).
import math

from atlas import INK, paint_hair, shade
from sea_common import cap, chest, circle, hair_back, hairline, hand, head_side, lathe, skirt, strand, strand_zone, tube

SKIN = "#dca97c"
SKIN_D = shade(SKIN, 0.66)
GREEN = "#4f9c47"
COAT = "#32573a"
COAT_D = shade(COAT, 0.55)
COAT_L = "#6f9c6c"
RED = "#b81f28"
RED_D = shade(RED, 0.6)
PANT = "#23232b"
PANT_L = "#4b4b58"
BOOT = "#15141a"
SCAR = "#8c4a3c"
SCAR_L = "#d99c84"
DEFAULT = COAT

HAIR_COLOURS = [GREEN, COAT]


def _bristles():
	"""Short stiff hair: a low jagged crest off the forehead, the crown fanning from its whorl, buzzed sides and back."""
	out = []
	# forehead crest: rooted on the hairline, it stands up and slightly forward, uneven heights
	for x, h, lean in ((-0.56, 0.2, -0.16), (-0.34, 0.38, -0.12), (-0.14, 0.24, 0.0), (0.04, 0.42, -0.04), (0.24, 0.26, 0.04), (0.42, 0.36, 0.14), (0.58, 0.18, 0.18)):
		out.append({"b": [x, -0.6, 5.12], "c": [x + lean * 0.3, -0.72, 5.26 + h * 0.2], "t": [x + lean, -0.7, 5.22 + h], "r": 0.15, "flatten": 0.55})
	# crown: small tufts breaking the silhouette, leaning away from the whorl at the back of the top
	for x, y, h in ((-0.42, -0.26, 0.2), (-0.14, -0.3, 0.26), (0.16, -0.28, 0.24), (0.44, -0.24, 0.18), (-0.5, 0.06, 0.16), (-0.2, 0.0, 0.22), (0.1, 0.02, 0.2), (0.42, 0.06, 0.15), (-0.34, 0.32, 0.14), (0.0, 0.3, 0.16), (0.32, 0.34, 0.13)):
		out.append({"b": [x, y, 5.36], "c": [x * 1.1, y - 0.03, 5.44 + h * 0.3], "t": [x * 1.25, y - 0.1, 5.42 + h], "r": 0.14, "flatten": 0.7})
	return out


HAIR = {"colour": GREEN, "locks": _bristles()}
PROPS = [
	# red sash wound twice round the waist
	{"part": "LowerTorso", "box": [2.08, 1.08, 0.3], "at": [0, 0, 2.5], "colour": RED, "bevel": 0.05},
	{"part": "LowerTorso", "box": [2.06, 1.06, 0.16], "at": [0, 0, 2.3], "colour": shade(RED, 0.8), "bevel": 0.04},
	{"part": "LowerTorso", "lock": [[0.86, -0.54, 2.44], [1.0, -0.66, 2.1], [0.98, -0.62, 1.42]], "r": 0.17, "colour": RED, "flatten": 0.3},
	{"part": "LowerTorso", "lock": [[0.86, -0.54, 2.44], [0.74, -0.66, 2.1], [0.76, -0.62, 1.6]], "r": 0.14, "colour": shade(RED, 0.8), "flatten": 0.3},
	{"part": "LowerTorso", "box": [0.3, 0.14, 0.3], "at": [0.86, -0.55, 2.42], "colour": shade(RED, 0.86), "bevel": 0.05},
	# boot toes
	{"part": "LeftFoot", "box": [0.98, 0.42, 0.3], "at": [0.5, -0.62, 0.15], "colour": BOOT, "bevel": 0.1},
	{"part": "RightFoot", "box": [0.98, 0.42, 0.3], "at": [-0.5, -0.62, 0.15], "colour": BOOT, "bevel": 0.1},
	# the black tie on the left upper arm, knot and tails
	{"part": "LeftUpperArm", "box": [1.05, 1.05, 0.2], "at": [1.5, 0, 3.42], "colour": "#1a1a20", "bevel": 0.03},
	{"part": "LeftUpperArm", "lock": [[2.02, 0.2, 3.42], [2.2, 0.36, 3.3], [2.16, 0.52, 2.92]], "r": 0.1, "colour": "#1a1a20", "flatten": 0.3},
	{"part": "LeftUpperArm", "lock": [[2.02, 0.2, 3.42], [2.16, 0.14, 3.28], [2.14, 0.16, 3.0]], "r": 0.1, "colour": "#1a1a20", "flatten": 0.3},
]


def _sword(kit, tag, parts, x, z, grip, sheath, guard, wrap=None):
	"""Worn edge-up through the sash on the left hip: hilt forward and high, sheath running back and low."""
	torso = parts["LowerTorso"]
	front = (x, -1.2, z + 0.42)
	mouth = (x, -0.66, z + 0.2)
	end = (x + 0.04, 1.42, z - 0.62)
	tube(kit, f"LowerTorso_{tag}Grip", [front, mouth], 0.058, grip, torso, sides=6)
	tube(kit, f"LowerTorso_{tag}Sheath", [mouth, end], 0.056, sheath, torso, sides=6)
	# guard, a flat oval across the blade
	ang = math.atan2(mouth[2] - front[2], mouth[1] - front[1])
	lathe(kit, f"LowerTorso_{tag}Guard", [(0, -0.018), (0.13, -0.018), (0.13, 0.018), (0, 0.018)], guard, torso, at=mouth, seg=10, sy=0.88, rot=(math.pi / 2 - ang, 0, 0))
	if wrap:  # diamonds of the grip wrap: short bands
		for i in range(3):
			t = 0.2 + i * 0.28
			c = tuple(front[a] + (mouth[a] - front[a]) * t for a in range(3))
			lathe(kit, f"LowerTorso_{tag}Wrap{i}", [(0, -0.02), (0.066, -0.02), (0.066, 0.02), (0, 0.02)], wrap, torso, at=c, seg=6, rot=(math.pi / 2 - ang, 0, 0))


def model(parts, kit):
	head = parts["Head"]
	line = hairline([(0, 4.8), (45, 4.54), (90, 4.46), (135, 4.54), (180, 4.8), (225, 5.08), (270, 5.12), (315, 5.08)])
	cap(kit, "Head_Cap", GREEN, head, line, top=5.44, n=3.8)
	# buzzed sides lying back along the skull; the broad clumps at the back lie down to a clean nape
	for sd in (1, -1):
		for y, z, ln in ((-0.34, 5.12, 0.26), (-0.06, 5.14, 0.3), (0.22, 5.1, 0.34), (0.46, 5.02, 0.3)):
			strand(kit, f"Head_Side{sd}{y}", [(sd * 0.66, y, z + 0.06), (sd * 0.74, y + 0.04, z - ln * 0.4), (sd * 0.72, y + 0.14, z - ln)], 0.14, GREEN, head, flatten=0.4, rings=4, wide=(0, 1, 0.2))
	for x, z, r, ln in ((-0.46, 5.24, 0.21, 0.42), (-0.16, 5.28, 0.21, 0.48), (0.14, 5.28, 0.21, 0.44), (0.44, 5.24, 0.21, 0.46), (-0.3, 4.92, 0.2, 0.4), (0.0, 4.9, 0.21, 0.42), (0.3, 4.92, 0.2, 0.38), (-0.56, 4.92, 0.14, 0.32), (0.56, 4.92, 0.14, 0.3)):
		strand(kit, f"Head_Back{x}{z}", [(x, 0.58, z), (x * 1.04, 0.72, z - ln * 0.45), (x * 1.06, 0.68, z - ln)], r, GREEN, head, flatten=0.4, rings=4, wide=(1, 0, 0))
	# three gold drops on the left ear: stacked, the lowest is longest
	for i, y in enumerate((-0.08, 0.0, 0.08)):
		z = 4.5
		lathe(kit, f"Head_EarDrop{i}", [(0, z - 0.2), (0.022, z - 0.15), (0.028, z - 0.08), (0.012, z - 0.02), (0, z + 0.01)], "#f4c63a", head, at=(0.68, y, 0), seg=6)
	torso = parts["LowerTorso"]
	# the long coat falls open from the sash to the knee: two front panels, a vented back
	skirt(kit, "LowerTorso_CoatF", COAT, torso, [[(0.16, -0.56), (0.58, -0.58), (1.02, -0.54), (1.08, -0.15)], [(-1.08, -0.15), (-1.02, -0.54), (-0.58, -0.58), (-0.16, -0.56)]], 2.28, 0.72, flare=0.12)
	skirt(kit, "LowerTorso_CoatB", COAT, torso, [[(1.08, -0.15), (1.08, 0.3), (0.98, 0.56), (0.5, 0.58), (0.05, 0.56)], [(-0.05, 0.56), (-0.5, 0.58), (-0.98, 0.56), (-1.08, 0.3), (-1.08, -0.15)]], 2.28, 0.72, flare=0.12)
	# white hilt and sheath, black hilt and sheath with a gold guard, red hilt and sheath
	_sword(kit, "SwordA", parts, 1.12, 1.92, "#eeece4", "#f2f0e8", "#d8b032", wrap="#a8a79e")
	_sword(kit, "SwordB", parts, 1.22, 1.72, "#1c1b22", "#17161c", "#c02830", wrap="#c02830")
	_sword(kit, "SwordC", parts, 1.32, 1.52, "#8a1f26", "#a2242c", "#26252c", wrap="#22212a")


def face(a):
	f = a["Head_F"]
	f.fill(SKIN)
	dark = shade(SKIN, 0.68)
	e = shade(SKIN, 0.4)
	# short hair shadow, hollow cheeks, a hard square jaw
	f.path("M-5-5H135V24L112 28L96 22L80 28L65 22L50 28L34 22L18 28L-5 24Z", dark, opacity=0.95, blur=1)
	f.soft("M-5 30H12Q10 80 30 135H-5Z", dark, 0.85, 3)
	f.soft("M135 30H118Q120 80 100 135H135Z", dark, 1.0, 3)
	f.soft("M26 128Q65 118 104 128V136H26Z", dark, 0.9, 2)
	f.soft("M18 84Q28 100 42 114L34 118Q20 104 14 88Z", dark, 0.8, 2)
	f.soft("M112 84Q102 100 88 114L96 118Q110 104 116 88Z", dark, 0.8, 2)
	f.taper(25, 104, 34, 116, 46, 124, 1.0, e)
	f.taper(105, 104, 96, 116, 84, 124, 1.0, e)
	# his right eye, open: narrow, flat, a small dark iris under a heavy lid
	f.path("M26 60Q40 54 52 66Q40 72 30 68Z", "#fbf8f2")
	f.path(circle(41, 62.5, 6, 7), "#141418")
	f.path(circle(42.5, 60, 1.5), "#ffffff")
	f.path("M23 58Q36 52 55 66L52 70Q38 60 25 63Z", INK)
	f.ink("M31 69Q42 73 51 67", 1.0)
	f.taper(30, 74, 40, 77, 50, 73, 0.6, e)
	# heavy angry brows, dark green
	f.path("M16 38Q36 36 56 52L53 60Q34 50 15 48Z", "#1d3a1a")
	f.path("M114 38Q94 36 74 52L77 60Q96 50 115 48Z", "#1d3a1a")
	f.taper(54, 50, 58, 54, 56, 62, 0.8, e)
	f.taper(76, 50, 72, 54, 74, 62, 0.8, e)
	# his left eye, shut: one hard lid line, the socket modelled
	f.soft("M76 56Q90 50 106 58V66Q90 60 76 66Z", dark, 0.8, 1)
	f.path("M76 64Q92 71 108 62L108 65Q92 75 76 67Z", INK)
	# the scar: brow to cheek, straight through the shut eye
	f.path("M90 28L92 94", stroke=SCAR, sw=3)
	f.path("M90 28L92 94", stroke=SCAR_L, sw=1.0)
	# nose, long and straight
	f.taper(64, 66, 62, 78, 62, 86, 0.8, dark)
	f.path("M63 76L59 88L69 89Z", dark, opacity=0.65)
	f.ink("M58 89Q64 92 71 89", 1.2, e)
	# set mouth, one corner pulled up in a hard half grin
	f.path("M42 106Q60 108 88 100", stroke=INK, sw=2.2)
	f.ink("M40 103Q41 105 43 106", 1.3)
	f.ink("M88 100Q91 99 92 96", 1.3)
	f.taper(52, 113, 65, 116, 78, 112, 0.9, e)
	f.soft("M50 114H80V120H50Z", dark, 0.6, 1)


def coat_arm(f, side, key):
	"""Long loose sleeve, wide cuff near the wrist."""
	f.fill(COAT)
	f.folds(5, COAT_D, COAT_L, y0=0.04, y1=0.72, pinch=(50, 104))
	f.taper(10, 96, 40, 112, 88, 100, 1.5, COAT_D)
	f.path("M-5 148H105V172H-5Z", shade(COAT, 0.8))
	f.ink("M-5 148H105", 1.6)
	f.ink("M-5 172H105", 2.2)
	f.taper(10, 158, 50, 164, 90, 156, 0.9, COAT_L)


def paint(a):
	paint_hair(a, [GREEN, COAT])
	strand_zone(a, 0, 2, GREEN, lines=40)
	strand_zone(a, 1, 2, COAT)
	face(a)
	# ---- torso front: coat open in a deep V to the sash, the scar across the bare chest
	f = a["Torso_F"]
	f.fill(SKIN)
	chest(f, SKIN, cx=100, w=0.86, abs_rows=2, deep=1.1)
	d = "M158 8Q112 66 58 160"
	f.path(d, stroke=SCAR, sw=6)
	f.path(d, stroke=SCAR_L, sw=2.6)
	for n, (x, y) in enumerate(((132, 41), (98, 88), (72, 132))):
		f.ink(f"M{x - 5} {y - 3}L{x + 5} {y + 3}", 1.0, SCAR)
	f.path("M-5-5H36L92 150H-5Z", COAT)
	f.path("M205-5H164L108 150H205Z", COAT)
	f.path("M-5 150H205V205H-5Z", COAT)
	# lapels, turned back with a lit edge
	f.path("M36-5L92 150L78 150L18-5Z", shade(COAT, 1.25))
	f.path("M164-5L108 150L122 150L182-5Z", shade(COAT, 1.25))
	f.ink("M36-5L92 150", 2.4)
	f.ink("M164-5L108 150", 2.4)
	f.ink("M18-5L78 150", 1.4)
	f.ink("M182-5L122 150", 1.4)
	f.folds(6, COAT_D, COAT_L, y0=0.08, y1=0.68, pinch=(100, 146))
	f.path("M36-5L92 150L78 150L18-5ZM164-5L108 150L122 150L182-5Z", shade(COAT, 1.25), opacity=0.5)
	f.edges()
	# ---- torso back
	f = a["Torso_B"]
	f.fill(COAT)
	f.path("M56-5Q100 16 144-5V8Q100 28 56 8Z", COAT_D)
	f.ink("M56 8Q100 28 144 8", 1.5)
	f.ink("M100 22V200", 1.2, COAT_D)
	f.folds(8, COAT_D, COAT_L, y0=0.1, y1=0.76, pinch=(100, 154))
	f.taper(16, 36, 60, 60, 82, 44, 1.2, COAT_D)
	f.taper(184, 36, 140, 60, 118, 44, 1.2, COAT_D)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(COAT)
		f.folds(5, COAT_D, COAT_L, y0=0.06, y1=0.7, pinch=(50, 156))
		f.ink("M50-5V205", 1.2, COAT_D)
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			coat_arm(f, side, key)
			hand(f, side, key, SKIN)
			f.edges()
		a[f"{side}Arm_T"].fill(COAT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		# ---- legs: black trousers bunched into tall boots
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(PANT)
			f.folds(6, "#0e0e14", PANT_L, y0=0.05, y1=0.58, pinch=(50, 120))
			f.path("M-5 112Q50 122 105 112V205H-5Z", BOOT)
			f.ink("M-5 112Q50 122 105 112", 2)
			f.path("M-5 112Q50 122 105 112V122Q50 132 -5 122Z", "#2b2a33")
			f.taper(20, 134, 50, 142, 80, 134, 1.1, "#3e3d48")
			f.taper(16, 170, 50, 176, 84, 168, 1.2, "#3e3d48")
			f.path("M-5 192H105V205H-5Z", "#08080c")
			if key == "F":
				f.path("M30 148H70V160H30Z", "#2b2a33", stroke=INK, sw=1)
				f.path(circle(50, 154, 3), "#8a8a92")
			f.edges()
		a[f"{side}Leg_T"].fill(PANT)
		a[f"{side}Leg_Bo"].fill("#08080c")
	hair_back(a["Head_B"], GREEN, SKIN, nape=88, jag=10)
	a["Head_T"].fill(GREEN)
	a["Head_Bo"].fill(SKIN_D)
	head_side(a["Head_L"], SKIN, GREEN, True, hair_front=0.34, low=0.34, back_low=0.62)
	head_side(a["Head_R"], SKIN, GREEN, False, hair_front=0.34, low=0.34, back_low=0.62)
	a["Torso_T"].fill(COAT)
	a["Torso_Bo"].fill(COAT)
