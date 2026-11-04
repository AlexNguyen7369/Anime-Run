# Painted look for leaf_copycat: slanted band over one eye, face mask, padded vest (design doc 5).
from atlas import INK, paint_hair, shade, swirl_d
from leaf_common import ani_brow, ani_eye, begin_clip, end_clip, face_shade, hair_model, hand, lk, relief, sandal, side_hair, spike, steel_plate, strands

SKIN = "#f4d6bc"
SKIN_D = shade(SKIN, 0.7)
NAVY = "#1f2a3c"
NAVY_D = "#111824"
NAVY_L = "#44566e"
VEST = "#66754a"
VEST_D = "#3e4a2c"
VEST_L = "#93a46a"
RED = "#cc2a20"
SILVER = "#c8ccd6"
SILVER_D = "#9096a4"
BAND = "#1b2331"
DEFAULT = NAVY
HAIR_COLOURS = ["#DFE2E8"]
SLANT = 26.6  # degrees the band drops towards the covered eye

# Tall broad spikes all pushed up and over to the character's left: the mass stands on the head at an angle.
_up = [
	(0, 78, 1.0, 0.56, 0.36),
	(32, 72, 1.12, 0.56, 0.48),
	(70, 62, 1.2, 0.56, 0.58),
	(102, 58, 1.14, 0.56, 0.52),
	(330, 76, 0.96, 0.56, 0.36),
	(292, 70, 0.86, 0.54, 0.38),
	(258, 60, 0.76, 0.5, 0.28),
	(132, 56, 1.04, 0.56, 0.36),
	(165, 62, 1.0, 0.58, 0.3),
	(200, 62, 0.92, 0.58, 0.24),
	(235, 56, 0.8, 0.54, 0.16),
	(90, 26, 0.94, 0.5, 0.36),
	(60, 30, 0.8, 0.48, 0.38),
	(125, 22, 0.86, 0.52, 0.2),
	(160, 26, 0.84, 0.56, 0.12),
	(195, 24, 0.8, 0.56, 0.05),
	(235, 18, 0.7, 0.5, 0.03),
	(270, 22, 0.66, 0.44, 0.08),
	(180, -10, 0.72, 0.56, 0.0),
	(142, -12, 0.7, 0.5, 0.03),
	(218, -12, 0.7, 0.5, -0.02),
	(180, -36, 0.72, 0.54, 0.0),
	(145, -38, 0.66, 0.46, 0.0),
	(215, -38, 0.66, 0.46, 0.0),
	(112, -28, 0.62, 0.4, 0.0),
	(248, -28, 0.62, 0.4, 0.0),
]
SHARDS = [spike(az, el, ln, r, 0.04, reach=0.6, flatten=0.9, side=s, z=5.0) for az, el, ln, r, s in _up] + [
	# low front locks over the band
	lk((-0.18, -0.46, 5.38), (-0.24, -0.74, 5.3), (-0.42, -0.72, 5.08), 0.22),
	lk((0.08, -0.46, 5.4), (0.2, -0.74, 5.36), (0.3, -0.74, 5.14), 0.22),
	lk((0.36, -0.46, 5.34), (0.54, -0.72, 5.28), (0.72, -0.72, 5.02), 0.22),
	lk((-0.46, -0.44, 5.3), (-0.62, -0.68, 5.18), (-0.72, -0.66, 4.94), 0.2),
]
HAIR = {"colour": "#B4B9C4", "cap": {"size": [1.42, 1.3, 0.5], "at": [0, 0.0, 5.26], "bevel": 0.2}, "locks": []}

PROPS = [
	{"part": "LeftFoot", "box": [1.02, 1.1, 0.1], "at": [0.5, -0.03, 0.05], "colour": "#101622", "bevel": 0.02},
	{"part": "RightFoot", "box": [1.02, 1.1, 0.1], "at": [-0.5, -0.03, 0.05], "colour": "#101622", "bevel": 0.02},
	# fat padded vest collar and the mask running into it
	{"part": "UpperTorso", "box": [1.56, 1.22, 0.22], "at": [0, 0, 4.08], "colour": "#66754A", "bevel": 0.09},
	# band tails, thigh holster over its tape, rear pouch
	{"part": "Head", "lock": [[0.04, 0.64, 4.82], [0.34, 1.0, 4.6], [0.46, 1.2, 3.92]], "r": 0.13, "colour": "#1B2331", "flatten": 0.3},
	{"part": "Head", "lock": [[-0.04, 0.64, 4.86], [-0.22, 0.98, 4.62], [-0.2, 1.1, 3.86]], "r": 0.13, "colour": "#1B2331", "flatten": 0.3},
	{"part": "RightUpperLeg", "box": [0.22, 0.6, 0.46], "at": [-1.1, -0.04, 1.42], "colour": "#2A3444", "bevel": 0.04},
	{"part": "LowerTorso", "box": [0.6, 0.2, 0.34], "at": [0.46, 0.58, 2.2], "colour": "#2A3444", "bevel": 0.04},
]


def model(parts, kit):
	hair_model(kit, parts, SHARDS, HAIR_COLOURS[0])
	rot = (0, 0.4636, 0)
	relief(kit, parts, "Head", "BandRing", "Head", (1.36, 1.26, 0.32), (0, 0, 4.835), bevel=0.02, rot=rot)
	relief(kit, parts, "Head", "Plate", "Head", (0.84, 0.09, 0.4), (0.1, -0.645, 4.785), key="F", bevel=0.015, rot=rot)
	relief(kit, parts, "UpperTorso", "Vest", "Torso", (2.12, 1.12, 1.56), (0, 0, 3.22), bevel=0.05)
	for x in (-0.6, 0.6):
		relief(kit, parts, "UpperTorso", f"Pouch{x}", "Torso", (0.62, 0.1, 0.72), (x, -0.59, 3.3), key="F", bevel=0.03)
	for s, side in ((1, "Left"), (-1, "Right")):
		relief(kit, parts, f"{side}LowerArm", "Glove", f"{side}Arm", (1.03, 1.03, 0.38), (s * 1.5, 0, 2.3))
		relief(kit, parts, f"{side}LowerLeg", "Tape", f"{side}Leg", (1.03, 1.03, 0.36), (s * 0.5, 0, 0.56))


def vest_pouch(f, x0, x1, y0=36, y1=112):
	f.path(f"M{x0} {y0}H{x1}V{y1}H{x0}Z", VEST, stroke=INK, sw=1.8)
	f.path(f"M{x0} {y0}H{x1}V{y0 + 5}H{x0}Z", VEST_L)
	f.path(f"M{x1 - 9} {y0}H{x1}V{y1}H{x1 - 9}Z", VEST_D, opacity=0.8)
	f.path(f"M{x0 + 3} {y0 + 2}H{x1 - 3}V{y0 + 20}Q{(x0 + x1) / 2} {y0 + 30} {x0 + 3} {y0 + 20}Z", shade(VEST, 1.12), stroke=INK, sw=1.2)
	f.path(ell2((x0 + x1) / 2, y0 + 20, 2.6), "#2a2f20")
	f.taper(x0 + 8, y0 + 40, (x0 + x1) / 2, y0 + 46, x1 - 8, y0 + 40, 1, VEST_D)
	f.ink(f"M{(x0 + x1) / 2 - 18} {y1 - 4}H{(x0 + x1) / 2 + 18}", 0.8, VEST_D)


def ell2(cx, cy, r):
	return f"M{cx - r} {cy}a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z"


def vest_base(f, y1=156):
	w = f.w
	f.path(f"M-5-5H{w + 5}V{y1}H-5Z", VEST)
	f.path(f"M-5-5H{w + 5}V6H-5Z", VEST_L, opacity=0.7)
	f.path(f"M-5 {y1 - 10}H{w + 5}V{y1}H-5Z", VEST_D)
	f.ink(f"M-5 {y1}H{w + 5}", 2)
	for x in range(10, w, 26):
		f.taper(x, y1 - 26, x + 3, y1 - 16, x, y1 - 10, 0.9, VEST_D)


def lower_shirt(f):
	f.fill(NAVY)
	f.folds(4, NAVY_D, NAVY_L, y0=0.78, y1=0.97, pinch=(f.w / 2, 186))


def spiral(f, cx, cy, r, sw):
	d = swirl_d(cx, cy, r, turns=2.1, a0=1.2)
	f.path(d, stroke="#5e0f0a", sw=sw * 1.45)
	f.path(d, stroke=RED, sw=sw)


def paint(a):
	paint_hair(a, [SILVER])
	# ---- face: one heavy-lidded bored eye, the slanted band over the other, mask from the nose down
	f = a["Head_F"]
	face_shade(f, SKIN, top=None)
	f.path("M-5-5H135V52L100 44L60 52L20 46L-5 54Z", shade(SKIN, 0.64))
	ani_eye(f, 34, 73, -1, "#1d1d24", w=31, h=13, tilt=-0.5, lid=4.2, ir=7.6, pupil=0.55, flick=1.5, look=1, lower=0.6, peak=-0.02)
	f.taper(18, 60, 34, 56, 50, 61, 0.7, shade(SKIN, 0.5))
	ani_brow(f, 34, 52, -1, "#70747e", w=30, angry=1.4, thick=3.6, arch=2)
	f.taper(20, 84, 32, 86, 48, 83, 0.7, shade(SKIN, 0.55))
	# mask: rises to the nose bridge, modelled by the nose beneath it
	m = "M-5 88L30 86Q52 84 60 78L65 74L70 78Q78 84 100 86L135 88V135H-5Z"
	f.path(m, NAVY)
	begin_clip(f, m)
	f.path("M65 74L72 100L70 104H100Q86 100 74 78Z", NAVY_D, opacity=0.9)
	f.path("M65 74Q60 92 60 104L68 102Z", NAVY_L, opacity=0.8)
	f.path("M100 86L135 88V135H96Q110 110 100 86Z", NAVY_D, opacity=0.9)
	f.path("M-5 88H12Q8 112 26 135H-5Z", NAVY_D, opacity=0.5)
	f.taper(50, 116, 66, 119, 84, 116, 1.0, NAVY_D)
	f.taper(30, 104, 26, 118, 36, 130, 1.0, NAVY_L)
	f.taper(40, 124, 62, 130, 90, 126, 1.0, NAVY_D)
	end_clip(f)
	f.ink(m, 1.7)
	# the scar's lower end shows under the band
	f.taper(92, 72, 94, 80, 90, 88, 1.2, "#a84a40")
	# slanted band and plate, worn by the 3D ring and plate
	f.path("M-5 -6.5L135 63.5V99.5L-5 29.5Z", BAND)
	f.path("M-5 -6.5L135 63.5V67.5L-5 -2.5Z", "#4a566a")
	f.path("M-5 29.5L135 99.5V104.5L-5 34.5Z", shade(SKIN, 0.55), opacity=0.7)
	f.out.append(f'<g transform="rotate({SLANT} 75 51.5)">')
	steel_plate(f, 33, 31.5, 117, 71.5)
	f.out.append("</g>")
	# ---- torso front: padded vest, four scroll pouches reduced to the chest pair, centre zip
	f = a["Torso_F"]
	lower_shirt(f)
	vest_base(f)
	vest_pouch(f, 8, 92)
	vest_pouch(f, 108, 192)
	f.path("M95-5H105V156H95Z", "#3a4228")
	f.ink("M95-5V156M105-5V156", 1.2)
	for y in range(2, 156, 7):
		f.ink(f"M97 {y}H103", 0.8, "#8a8f78")
	f.path("M92 10H108V24H92Z", "#9aa0a6", stroke=INK, sw=1)
	f.path("M60-5Q100 30 140-5Z", VEST_D, opacity=0.5)
	f.path("M-5 170H205V186H-5Z", NAVY_D)
	f.path("M-5 170H205V173H-5Z", NAVY_L)
	f.edges()
	# ---- torso back: red whirl in its white-edged disc, quilted bars
	f = a["Torso_B"]
	lower_shirt(f)
	vest_base(f)
	for y in (28, 124):
		f.taper(-5, y, 100, y + 5, 205, y, 1.2, VEST_D)
	f.path("M100 34a42 42 0 1 0 0.1 0Z", shade(VEST, 0.8), stroke=INK, sw=1.6)
	spiral(f, 100, 76, 34, 6)
	f.path("M-5 170H205V186H-5Z", NAVY_D)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		lower_shirt(f)
		vest_base(f)
		f.ink("M50-5V156", 1.6)
		for x in (28, 72):
			f.taper(x, 10, x + 4, 66, x, 140, 0.9, VEST_D)
		f.path("M-5 170H105V186H-5Z", NAVY_D)
		f.edges(0.42)
	a["Torso_T"].fill(VEST)
	a["Torso_Bo"].fill(NAVY)
	for side, sgn in (("Left", 1), ("Right", -1)):
		# ---- arms: long navy sleeve, red whirl on the shoulder, fingerless glove with its steel plate
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(NAVY)
			f.folds(5, NAVY_D, NAVY_L, y0=0.1, y1=0.76, pinch=(50, 104))
			f.path("M-5-5H105V18Q50 26 -5 18Z", NAVY_L, opacity=0.35)
			if key == "O":
				spiral(f, 50, 44, 24, 5)
			f.path("M-5 148H105V178H-5Z", "#15151c")
			f.path("M-5 148H105V152H-5Z", "#3c3c48")
			f.ink("M-5 148H105", 1.3)
			hand(f, key, side, SKIN, y0=176, glove="#15151c")
			if key in ("F", "O"):
				f.path("M20 150H80V176H20Z", "#a8aeb6", stroke=INK, sw=1.3)
				f.path("M20 150H80V157H20Z", "#dde1e6")
				for x in (28, 72):
					f.path(ell2(x, 169, 1.6), "#50565e")
			f.edges()
		a[f"{side}Arm_T"].fill(NAVY)
		a[f"{side}Arm_Bo"].fill("#15151c")
		# ---- legs: navy trousers, taped shins, sandals
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(NAVY)
			f.folds(6, NAVY_D, NAVY_L, y0=0.06, y1=0.62, pinch=(50, 106))
			if side == "Right":
				f.path("M-5 30H105V56H-5Z", "#e8e4da")
				f.ink("M-5 40L105 44M-5 48L105 50", 1.0, "#8b857a")
				f.ink("M-5 30H105M-5 56H105", 1.2)
			f.path("M-5 126H105V162H-5Z", "#e8e4da")
			for y in (133, 141, 149, 156):
				f.ink(f"M-5 {y}L105 {y + 3}", 1.0, "#8b857a")
			f.ink("M-5 126H105", 1.3)
			sandal(f, key, side, "#182232", SKIN, y0=162)
			f.edges()
		a[f"{side}Leg_T"].fill(NAVY)
		a[f"{side}Leg_Bo"].fill("#101622")
	# ---- head back and sides: a tilted ring: low on the covered side, high on the other
	f = a["Head_B"]
	f.fill(SILVER_D)
	strands(f, 9, 0, 130, 0, 130, "#5e6470", lean=-3)
	f.path("M-5 99.5L135 29.5V-6.5L-5 63.5Z", BAND)
	f.path("M-5 67.5L135 -2.5V-6.5L-5 63.5Z", "#4a566a")
	f.path("M-5 110H135V135H-5Z", NAVY)
	f = a["Head_L"]
	side_hair(f, SKIN, SILVER_D, "#6e7482", True, edge=44, nape=112, top=30, ear=False)
	f.path("M-5 88H70L125 112V135H-5Z", NAVY)
	f.path("M-5 112H60L125 128V135H-5Z", NAVY_D, opacity=0.8)
	f.path("M-5 61H125V97H-5Z", BAND)
	f.path("M-5 61H125V64H-5Z", "#4a566a")
	f = a["Head_R"]
	side_hair(f, SKIN, SILVER_D, "#6e7482", False, edge=44, nape=112, top=30)
	f.path("M125 88H50L-5 112V135H125Z", NAVY)
	f.path("M125 112H60L-5 128V135H125Z", NAVY_D, opacity=0.8)
	f.path("M-5 -4H125V32H-5Z", BAND)
	f.path("M-5 -4H125V-1H-5Z", "#4a566a")
	a["Head_T"].fill(SILVER_D)
	a["Head_Bo"].fill(NAVY_D)
