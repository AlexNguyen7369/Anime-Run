# Painted look for leaf_crow: black storm-cloud cloak with a red-lined collar, slashed plate, low tail (design doc 5).
from atlas import INK, paint_hair, shade
from leaf_common import ani_brow, ani_eye, cloud, face_shade, hair_model, hand, lk, nose, relief, sandal, side_hair, steel_plate, strands

SKIN = "#f2d8c6"
SKIN_D = shade(SKIN, 0.7)
CLOAK = "#1c1c24"
CLOAK_D = "#08080c"
CLOAK_L = "#4c4c60"
RED = "#b81e28"
NAIL = "#6a3f96"
HAIR_D = "#101016"
HAIR_T = "#4a4a5a"
BAND = "#20202a"
DEFAULT = CLOAK
HAIR_COLOURS = ["#1A1A22"]

HAIR = {"colour": "#131319", "cap": {"size": [1.4, 1.26, 0.4], "at": [0, 0.05, 5.26], "bevel": 0.19}, "locks": []}
_F = dict(flatten=0.22, rings=5, taper=0.7)
SHARDS = [
	# centre-parted bangs falling past the cheeks to the jaw, the long iconic pair
	lk((0.06, -0.54, 5.5), (0.7, -0.92, 5.2), (0.62, -0.88, 4.08), 0.32, mirror=True) | _F,
	lk((0.42, -0.44, 5.46), (0.8, -0.86, 5.0), (0.78, -0.84, 4.06), 0.32, mirror=True) | _F,
	lk((0.46, -0.14, 5.52), (0.84, -0.2, 4.9), (0.8, -0.18, 4.3), 0.3, mirror=True) | _F,
	# hair combed from the crown down to the nape tie
	lk((0.44, 0.2, 5.46), (0.84, 0.5, 4.9), (0.22, 0.72, 4.34), 0.36, mirror=True) | _F,
	lk((0.44, 0.34, 5.54), (0.8, 0.78, 5.0), (0.14, 0.74, 4.32), 0.42, mirror=True) | _F,
	lk((0.16, 0.36, 5.58), (0.4, 0.92, 5.06), (0.05, 0.76, 4.32), 0.42, mirror=True) | _F,
	lk((0.42, 0.0, 5.54), (0.84, 0.14, 5.0), (0.72, 0.42, 4.42), 0.32, mirror=True) | _F,
	# crown strands sweeping from the parting
	lk((0.02, -0.5, 5.6), (0.46, -0.66, 5.66), (0.72, -0.62, 4.94), 0.34, mirror=True) | _F,
	lk((0.02, -0.2, 5.64), (0.52, -0.3, 5.7), (0.76, -0.26, 4.9), 0.36, mirror=True) | _F,
	lk((0.02, 0.1, 5.64), (0.52, 0.06, 5.72), (0.76, 0.02, 4.9), 0.36, mirror=True) | _F,
	lk((0.02, 0.36, 5.62), (0.52, 0.42, 5.64), (0.76, 0.34, 4.86), 0.36, mirror=True) | _F,
	# low long tail
	lk((0, 0.74, 4.36), (0.04, 1.08, 3.9), (0.02, 1.0, 3.04), 0.27, flatten=0.5, colour="#1A1A22"),
	lk((0.1, 0.72, 4.34), (0.2, 1.02, 3.92), (0.16, 0.92, 3.26), 0.2, flatten=0.5),
	lk((-0.1, 0.72, 4.34), (-0.18, 1.02, 3.92), (-0.16, 0.94, 3.2), 0.2, flatten=0.5),
]

PROPS = [
	{"part": "LeftFoot", "box": [1.02, 1.1, 0.1], "at": [0.5, -0.03, 0.05], "colour": "#0E0E14", "bevel": 0.02},
	{"part": "RightFoot", "box": [1.02, 1.1, 0.1], "at": [-0.5, -0.03, 0.05], "colour": "#0E0E14", "bevel": 0.02},
	{"part": "Head", "box": [0.2, 0.1, 0.12], "at": [0, 0.76, 4.36], "colour": "#A01A24", "bevel": 0.02},
	# band tails under the hair
	{"part": "Head", "lock": [[0.3, 0.62, 5.02], [0.5, 0.9, 4.8], [0.56, 1.0, 4.3]], "r": 0.11, "colour": "#20202A", "flatten": 0.3, "mirror": True},
	# the standing collar: black outside, red showing inside the back and the sides
	{"part": "UpperTorso", "box": [1.5, 0.1, 0.5], "at": [0, 0.68, 4.2], "colour": "#B81E28", "bevel": 0.03},
	{"part": "UpperTorso", "box": [1.58, 0.1, 0.54], "at": [0, 0.76, 4.2], "colour": "#1C1C24", "bevel": 0.03},
	{"part": "UpperTorso", "box": [0.1, 1.28, 0.58], "at": [0.72, 0.02, 4.2], "colour": "#B81E28", "bevel": 0.03, "mirror": True},
	{"part": "UpperTorso", "box": [0.1, 1.36, 0.62], "at": [0.8, 0.02, 4.2], "colour": "#1C1C24", "bevel": 0.03, "mirror": True},
	# front flaps: red lining turned out, black over it, a V at the throat
	{"part": "UpperTorso", "blade": [(0.0, 3.82), (0.8, 3.9), (0.82, 4.24), (0.3, 4.34)], "y": [-0.62, -0.76], "colour": "#B81E28", "mirror": True},
	{"part": "UpperTorso", "blade": [(0.13, 3.82), (0.84, 3.9), (0.86, 4.26), (0.4, 4.34)], "y": [-0.68, -0.8], "colour": "#1C1C24", "mirror": True},
	# a red ring on the right hand
	{"part": "RightHand", "box": [0.24, 0.05, 0.06], "at": [-1.62, -0.52, 2.1], "colour": "#D03040", "bevel": 0.01},
]


def model(parts, kit):
	hair_model(kit, parts, SHARDS, HAIR_COLOURS[0])
	relief(kit, parts, "Head", "BandRing", "Head", (1.34, 1.24, 0.22), (0, 0, 5.04), bevel=0.02)
	relief(kit, parts, "Head", "Plate", "Head", (0.78, 0.08, 0.3), (0, -0.64, 5.04), key="F", bevel=0.015)
	for s, side in ((1, "Left"), (-1, "Right")):
		relief(kit, parts, f"{side}LowerArm", "Cuff", f"{side}Arm", (1.14, 1.14, 0.44), (s * 1.5, 0, 2.52))
		relief(kit, parts, f"{side}LowerLeg", "Hem", f"{side}Leg", (1.1, 1.1, 0.46), (s * 0.5, 0, 0.74))


def cloak_face(f, n, pinch=None, y0=0.05, y1=0.9):
	f.fill(CLOAK)
	f.folds(n, CLOAK_D, CLOAK_L, y0=y0, y1=y1, pinch=pinch or (f.w / 2, f.h * 0.72))


def paint(a):
	paint_hair(a, [HAIR_T])
	# ---- face: long lean face, red three-comma eyes, the deep tear troughs, a flat mouth
	f = a["Head_F"]
	face_shade(f, SKIN, top=None)
	f.path("M-5-5H135V46L112 54L96 46L74 52L56 46L34 54L18 46L-5 54Z", shade(SKIN, 0.62))
	ani_eye(f, 36, 74, -1, RED, w=25, h=11, tilt=3.5, lid=3, ir=7.6, flick=2.6, style="red", sclera="#ece4da", look=0.5)
	ani_eye(f, 94, 74, 1, RED, w=25, h=11, tilt=3.5, lid=3, ir=7.6, flick=2.6, style="red", sclera="#ece4da", look=-0.5)
	ani_brow(f, 36, 60, -1, HAIR_D, w=26, angry=2.4, thick=2.6, arch=1.2)
	ani_brow(f, 94, 60, 1, HAIR_D, w=26, angry=2.4, thick=2.6, arch=1.2)
	# tear troughs: long creases dropping from the inner corner
	for s in (-1, 1):
		f.taper(65 + s * 20, 78, 65 + s * 27, 88, 65 + s * 30, 100, 1.2, "#5a3430")
		f.taper(65 + s * 13, 78, 65 + s * 18, 86, 65 + s * 21, 96, 0.9, "#5a3430")
	nose(f, SKIN, x=65, y=93, size=0.8)
	f.taper(52, 110, 65, 111, 78, 110, 0.9)
	f.taper(59, 115, 65, 116.5, 71, 115, 0.5, shade(SKIN, 0.55))
	f.path("M12 96Q24 120 40 135H-5V96Z", SKIN_D, opacity=0.6)
	f.path("M118 96Q106 120 90 135H135V96Z", SKIN_D, opacity=0.7)
	# band and the slashed plate
	f.path("M-5 13H135V35H-5Z", BAND)
	f.path("M-5 13H135V16H-5Z", "#50505e")
	f.path("M-5 35H135V40H-5Z", shade(SKIN, 0.5), opacity=0.7)
	steel_plate(f, 26, 9, 104, 39, slash=True)
	# ---- torso front: closed cloak, two clouds
	f = a["Torso_F"]
	cloak_face(f, 6, pinch=(100, 150), y0=0.14)
	f.path("M60-5H140L104 40H96Z", RED)
	f.path("M96 40H104V205H96Z", CLOAK_D)
	f.ink("M100 24V205", 2)
	f.taper(112, 44, 116, 120, 110, 200, 1, CLOAK_L)
	for y in (56, 96, 136):
		f.path(f"M100 {y - 3}a3 3 0 1 0 0.1 0Z", "#26262e", stroke="#6a6a7c", sw=0.8)
	cloud(f, 50, 92, 28)
	cloud(f, 152, 134, 26)
	cloud(f, 160, 44, 18)
	f.edges(0.18)
	# ---- torso back: three clouds
	f = a["Torso_B"]
	cloak_face(f, 6, pinch=(100, 170), y0=0.1)
	cloud(f, 100, 78, 38)
	cloud(f, 42, 152, 26)
	cloud(f, 160, 150, 26)
	f.edges(0.18)
	f = a["Torso_L"]
	cloak_face(f, 4, pinch=(50, 160))
	cloud(f, 54, 110, 25)
	f.edges(0.2)
	f = a["Torso_R"]
	cloak_face(f, 4, pinch=(50, 160))
	cloud(f, 46, 72, 25)
	f.edges(0.2)
	a["Torso_T"].fill(CLOAK)
	a["Torso_Bo"].fill(CLOAK_D)
	spots = {"F": (48, 76, 24), "B": (54, 96, 24), "O": (50, 58, 30), "I": (50, 110, 18)}
	leg_spots = {"F": (46, 66, 24), "B": (52, 80, 28), "O": (50, 44, 26), "I": (50, 90, 18)}
	for side, sgn in (("Left", 1), ("Right", -1)):
		# ---- arms: wide sleeve with the red lining at the cuff, purple nails
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			cloak_face(f, 5, pinch=(50, 120), y0=0.1, y1=0.7)
			x, y, s = spots[key]
			cloud(f, x, y, s)
			f.path("M-5 148H105V162H-5Z", CLOAK)
			f.path("M-5 150H105V153H-5Z", CLOAK_L)
			f.ink("M-5 148H105", 1.4)
			f.path("M-5 162H105V172H-5Z", RED)
			f.ink("M-5 162H105M-5 172H105", 1.4)
			hand(f, key, side, SKIN, y0=172, nails=NAIL)
			f.edges(0.2)
		a[f"{side}Arm_T"].fill(CLOAK)
		a[f"{side}Arm_Bo"].fill(RED)
		# ---- legs: the cloak's long skirt, red hem, dark trousers, sandals with purple toenails
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			cloak_face(f, 5, pinch=(50, 130), y0=0.05, y1=0.66)
			x, y, s = leg_spots[key]
			if not (key == "F" and side == "Right"):
				cloud(f, x, y, s)
			else:
				cloud(f, 54, 76, 22)
			f.path("M-5 110H105V136H-5Z", CLOAK)
			f.path("M-5 112H105V115H-5Z", CLOAK_L)
			f.ink("M-5 110H105", 1.4)
			f.path("M-5 136H105V142H-5Z", RED)
			f.ink("M-5 136H105M-5 142H105", 1.4)
			f.path("M-5 142H105V164H-5Z", "#2a2c3a")
			f.taper(14, 146, 50, 152, 88, 146, 1, "#101018")
			sandal(f, key, side, "#16161e", SKIN, y0=162, nails=NAIL)
			f.edges(0.2)
		a[f"{side}Leg_T"].fill(CLOAK)
		a[f"{side}Leg_Bo"].fill("#0e0e14")
	# ---- head back and sides
	f = a["Head_B"]
	f.fill(HAIR_D)
	strands(f, 10, 0, 130, 0, 125, HAIR_T)
	f = a["Head_L"]
	side_hair(f, SKIN, HAIR_D, "#08080c", True, edge=40, nape=118, top=30, ear=False)
	f.path("M-5 13H125V35H-5Z", BAND)
	f = a["Head_R"]
	side_hair(f, SKIN, HAIR_D, "#08080c", False, edge=40, nape=118, top=30, ear=False)
	f.path("M-5 13H125V35H-5Z", BAND)
	a["Head_T"].fill(HAIR_D)
	a["Head_Bo"].fill(SKIN_D)
