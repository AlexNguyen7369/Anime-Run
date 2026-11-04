# Painted look for leaf_avenger: open white shirt, rope belt, hip cloth, straight sword (design doc 5).
from atlas import INK, paint_hair, shade
from leaf_common import ani_brow, ani_eye, face_shade, fan, hair_model, hand, lk, nose, pecs, relief, sandal, side_hair, spike, strands, wrap

SKIN = "#f4dcc8"
SKIN_D = shade(SKIN, 0.72)
SHIRT = "#e8e9f0"
SHIRT_D = "#a4a8bc"
SHIRT_L = "#ffffff"
NAVY = "#2b2f4c"
NAVY_D = "#191b30"
NAVY_L = "#4c5278"
PANT = "#23243a"
PANT_D = "#12121f"
PANT_L = "#42445f"
ROPE = "#7d4cc0"
ROPE_D = "#3f2268"
ROPE_L = "#a67ae0"
HAIR_D = "#141828"
HAIR_T = "#2e3858"
DEFAULT = SHIRT
HAIR_COLOURS = ["#1E2333"]

# The tail of back-swept spikes that stands off the crown, long bangs hanging both sides of the face to the jaw.
_back = [
	(180, 26, 1.42, 0.46, 0.14),
	(152, 30, 1.34, 0.44, 0.14),
	(208, 30, 1.34, 0.44, 0.14),
	(166, 54, 1.14, 0.42, 0.08),
	(194, 54, 1.14, 0.42, 0.08),
	(124, 30, 1.06, 0.38, 0.1),
	(236, 30, 1.06, 0.38, 0.1),
	(180, 2, 1.28, 0.44, 0.12),
	(150, 2, 1.2, 0.42, 0.1),
	(210, 2, 1.2, 0.42, 0.1),
	(120, 4, 0.92, 0.38, 0.06),
	(240, 4, 0.92, 0.38, 0.06),
	(166, -24, 0.94, 0.4, 0.02),
	(194, -24, 0.94, 0.4, 0.02),
	(134, -26, 0.8, 0.36, 0),
	(226, -26, 0.8, 0.36, 0),
	(90, 62, 0.6, 0.34, 0.02),
	(270, 62, 0.6, 0.34, 0.02),
	(35, 74, 0.54, 0.34, -0.02),
	(325, 74, 0.54, 0.34, -0.02),
]
_B = dict(rings=4, taper=0.65)
SHARDS = [spike(az, el, ln, r, bend, reach=0.6, flatten=0.8) for az, el, ln, r, bend in _back] + [
	# long side bangs
	lk((0.42, -0.42, 5.46), (0.82, -0.74, 5.0), (0.66, -0.72, 4.08), 0.32, mirror=True) | _B,
	lk((0.56, -0.2, 5.3), (0.84, -0.34, 4.8), (0.8, -0.3, 4.14), 0.3, mirror=True) | _B,
	lk((0.28, -0.5, 5.44), (0.52, -0.74, 5.1), (0.46, -0.72, 4.46), 0.26, mirror=True) | _B,
	# forehead strands crossing from the parting
	lk((0.02, -0.48, 5.5), (0.1, -0.74, 5.2), (0.2, -0.72, 4.86), 0.26),
	lk((-0.08, -0.48, 5.5), (-0.1, -0.74, 5.2), (-0.26, -0.72, 4.9), 0.26),
	lk((0.12, -0.48, 5.52), (0.04, -0.76, 5.3), (-0.04, -0.74, 4.98), 0.22),
	lk((0.7, 0.2, 5.1), (0.86, 0.3, 4.7), (0.8, 0.42, 4.3), 0.28, mirror=True),
]
HAIR = {"colour": "#141828", "cap": {"size": [1.42, 1.34, 0.56], "at": [0, 0.04, 5.2], "bevel": 0.2}, "locks": []}

PROPS = [
	{"part": "LeftFoot", "box": [1.02, 1.1, 0.1], "at": [0.5, -0.03, 0.05], "colour": "#12121A", "bevel": 0.02},
	{"part": "RightFoot", "box": [1.02, 1.1, 0.1], "at": [-0.5, -0.03, 0.05], "colour": "#12121A", "bevel": 0.02},
	# standing shirt collar, open at the throat
	{"part": "UpperTorso", "box": [1.5, 0.1, 0.36], "at": [0, 0.5, 4.14], "colour": "#E8E9F0", "bevel": 0.03},
	{"part": "UpperTorso", "box": [0.1, 0.56, 0.26], "at": [0.72, 0.24, 4.08], "colour": "#E8E9F0", "bevel": 0.03, "mirror": True},
	# rope bow at the back
	{"part": "LowerTorso", "lock": [[0, 0.56, 2.38], [0.5, 0.92, 2.66], [0.62, 0.66, 2.3]], "r": 0.17, "colour": "#6D3FA8", "flatten": 0.7, "mirror": True},
	{"part": "LowerTorso", "lock": [[0.04, 0.58, 2.34], [0.2, 0.78, 2.0], [0.26, 0.7, 1.5]], "r": 0.12, "colour": "#6D3FA8", "flatten": 0.7, "mirror": True},
	{"part": "LowerTorso", "box": [0.24, 0.2, 0.24], "at": [0, 0.62, 2.38], "colour": "#3F2268", "bevel": 0.05},
	# straight sword thrust through the rope behind the back: scabbard, hilt, cap
	{"part": "LowerTorso", "box": [2.3, 0.1, 0.17], "at": [0.28, 0.72, 2.24], "colour": "#26262E", "bevel": 0.02, "rot": [0, 0.5, 0]},
	{"part": "LowerTorso", "box": [0.1, 0.18, 0.28], "at": [-0.74, 0.72, 2.8], "colour": "#3A3A44", "bevel": 0.015, "rot": [0, 0.5, 0]},
	{"part": "LowerTorso", "box": [0.66, 0.12, 0.17], "at": [-1.08, 0.72, 2.98], "colour": "#101018", "bevel": 0.02, "rot": [0, 0.5, 0]},
]


def model(parts, kit):
	hair_model(kit, parts, SHARDS, HAIR_COLOURS[0])
	relief(kit, parts, "UpperTorso", "Rope", "Torso", (2.12, 1.12, 0.26), (0, 0, 2.4), bevel=0.05)
	for s, side in ((1, "Left"), (-1, "Right")):
		relief(kit, parts, f"{side}UpperArm", "Sleeve", f"{side}Arm", (1.06, 1.06, 0.14), (s * 1.5, 0, 3.26))
		relief(kit, parts, f"{side}LowerArm", "Guard", f"{side}Arm", (1.03, 1.03, 0.72), (s * 1.5, 0, 2.66))
	# hip cloth: front and back panels, sides open over the trousers
	for y, tag in ((-0.53, "F"), (0.53, "B")):
		wrap(kit.rbox(f"LowerTorso_Cloth{tag}", (2.1, 0.08, 0.86), (0, y, 1.86), "#808080", parts["LowerTorso"], bevel=0.02), "Torso_Bo")


def rope(f, y0, y1):
	f.path(f"M-5 {y0}H{f.w + 5}V{y1}H-5Z", ROPE)
	for x in range(-5, f.w + 5, 9):
		f.path(f"M{x} {y1}Q{x + 6} {(y0 + y1) / 2} {x + 8} {y0}L{x + 12} {y0}Q{x + 10} {(y0 + y1) / 2} {x + 4} {y1}Z", ROPE_D)
		f.taper(x + 2, y1 - 3, x + 6, (y0 + y1) / 2, x + 9, y0 + 3, 0.8, ROPE_L)
	f.ink(f"M-5 {y0}H{f.w + 5}M-5 {y1}H{f.w + 5}", 1.6)


def paint(a):
	paint_hair(a, [HAIR_T])
	# ---- face: narrow black eyes with a flat cold lid, straight brows, a shut mouth
	f = a["Head_F"]
	face_shade(f, SKIN, top=38, cast=shade(SKIN, 0.62))
	ani_eye(f, 37, 72, -1, "#23232e", w=29, h=11, tilt=5, lid=3.6, ir=7.4, pupil=0.5, flick=4, look=1.5, lower=0.7)
	ani_eye(f, 93, 72, 1, "#23232e", w=29, h=11, tilt=5, lid=3.6, ir=7.4, pupil=0.5, flick=4, look=-1.5, lower=0.7)
	ani_brow(f, 36, 58, -1, HAIR_D, w=27, angry=5, thick=3.2, arch=0.5)
	ani_brow(f, 94, 58, 1, HAIR_D, w=27, angry=5, thick=3.2, arch=0.5)
	f.taper(48, 62, 51, 66, 49, 70, 0.6, shade(SKIN, 0.6))
	f.taper(82, 62, 79, 66, 81, 70, 0.6, shade(SKIN, 0.6))
	nose(f, SKIN, x=65, y=91, size=0.8)
	f.taper(51, 110.5, 65, 109.5, 79, 110.5, 1.0)
	f.taper(58, 117, 65, 119, 73, 117, 0.6, shade(SKIN, 0.55))
	f.path("M14 96Q20 116 34 135H-5V96Z", SKIN_D, opacity=0.4)
	strands(f, 5, 0, 130, -4, 34, HAIR_D)
	# ---- torso front: a deep V of bare chest
	f = a["Torso_F"]
	f.fill(SHIRT)
	f.folds(6, SHIRT_D, SHIRT_L, y0=0.14, y1=0.72, pinch=(100, 150))
	v = "M58-5H142L104 152H96Z"
	f.path(v, SKIN)
	f.path("M58-5H142L132 22Q100 40 68 22Z", SKIN_D, opacity=0.8)
	pecs(f, SKIN, 62, 138, 10, 150)
	f.path("M112 90L104 152H100L104 90Z", SKIN_D, opacity=0.4)
	f.path("M52-5L60-5L100 152L92 152Z", SHIRT_L, stroke=INK, sw=1.7)
	f.path("M148-5L140-5L100 152L108 152Z", SHIRT_D, stroke=INK, sw=1.7)
	rope(f, 146, 174)
	f.path("M-5 172H205V205H-5Z", NAVY)
	f.path("M-5 172H205V178H-5Z", NAVY_D)
	f.edges()
	# ---- torso back: the clan fan high on the back
	f = a["Torso_B"]
	f.fill(SHIRT)
	f.folds(6, SHIRT_D, SHIRT_L, y0=0.45, y1=0.72, pinch=(100, 150))
	f.path("M60-5Q100 12 140-5Z", SHIRT_D)
	fan(f, 100, 50, 34)
	rope(f, 146, 174)
	f.path("M-5 172H205V205H-5Z", NAVY)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SHIRT)
		f.folds(5, SHIRT_D, SHIRT_L, y0=0.1, y1=0.72, pinch=(50, 150))
		rope(f, 146, 174)
		f.path("M-5 172H105V205H-5Z", NAVY)
		f.edges(0.4)
	a["Torso_T"].fill(SHIRT)
	# hip cloth art, worn by the two 3D panels
	f = a["Torso_Bo"]
	f.fill(NAVY)
	f.path("M-5 -5H205V10H-5Z", NAVY_D)
	for i, x in enumerate(range(20, 200, 34)):
		f.path(f"M{x} 6Q{x + 8} 50 {x - 4} 105L{x + 12} 105Q{x + 16} 50 {x + 10} 6Z", NAVY_D, opacity=0.8)
		f.taper(x + 14, 10, x + 20, 50, x + 18, 100, 1.2, NAVY_L)
	f.path("M-5 88Q100 94 205 88V105H-5Z", NAVY_D, opacity=0.8)
	for side, sgn in (("Left", 1), ("Right", -1)):
		# ---- arms: short white sleeve, bare elbow, long dark guard
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SHIRT)
			f.folds(4, SHIRT_D, SHIRT_L, y0=0.02, y1=0.28, pinch=(50, 68))
			f.path("M-5 72H105V92H-5Z", SKIN)
			f.path("M-5 72H105V78H-5Z", SKIN_D)
			f.taper(36, 86, 50, 89, 64, 86, 0.8, shade(SKIN, 0.5))
			f.path("M-5 62H105V72H-5Z", SHIRT_L)
			f.ink("M-5 62H105M-5 72H105", 1.5)
			f.path("M-5 92H105V176H-5Z", NAVY)
			f.path("M-5 92H105V96H-5Z", NAVY_L)
			f.path("M70 92Q84 130 76 176H105V92Z", NAVY_D, opacity=0.7)
			f.taper(20, 100, 15, 136, 24, 170, 1.3, NAVY_L)
			for y in (110, 150):
				f.path(f"M-5 {y}H105V{y + 5}H-5Z", NAVY_D, stroke=INK, sw=0.8)
			hand(f, key, side, SKIN, y0=172)
			f.edges()
		a[f"{side}Arm_T"].fill(SHIRT)
		a[f"{side}Arm_Bo"].fill(SKIN)
		# ---- legs: dark trousers, wrapped ankle, sandals
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(PANT)
			f.folds(6, PANT_D, PANT_L, y0=0.1, y1=0.66, pinch=(50, 110))
			f.path("M70 -5Q84 70 74 150H105V-5Z", PANT_D, opacity=0.6)
			f.path("M-5 134H105V158H-5Z", "#d9d6cc")
			for y in (140, 146, 152):
				f.ink(f"M-5 {y}L105 {y + 3}", 1.0, "#7f7a70")
			f.ink("M-5 134H105", 1.3)
			sandal(f, key, side, "#1b1c2c", SKIN, y0=158)
			f.edges()
		a[f"{side}Leg_T"].fill(PANT)
		a[f"{side}Leg_Bo"].fill("#12121a")
	# ---- head back and sides
	f = a["Head_B"]
	f.fill(HAIR_D)
	strands(f, 9, 0, 130, 10, 128, HAIR_T, lean=2)
	f.path("M-5 112L22 126L46 114L70 128L94 114L120 126L135 112V135H-5Z", SKIN_D)
	side_hair(a["Head_L"], SKIN, HAIR_D, "#0c0e1a", True, edge=50, nape=120, top=28)
	side_hair(a["Head_R"], SKIN, HAIR_D, "#0c0e1a", False, edge=50, nape=120, top=28)
	a["Head_T"].fill(HAIR_D)
	a["Head_Bo"].fill(SKIN_D)
