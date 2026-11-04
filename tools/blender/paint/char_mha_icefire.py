# Painted look for mha_icefire: split hair, burn scar on his left, navy suit with a white harness (design doc 5).
from atlas import INK, face_base, paint_hair, shade
from mha_common import anime_eye, fingers, loft, lr, tube, tuft

SKIN = "#f4d8c2"
SKIN_D = shade(SKIN, 0.68)
NAVY = "#27396f"
NAVY_D = shade(NAVY, 0.58)
NAVY_L = "#5a70b4"
WHITE = "#e8ebf0"
WHITE_D = "#9fa8b6"
SILVER = "#b9c0ca"
WHITE_H = "#E4E6EC"
RED_H = "#BE2329"
ICE = "#BDE8FA"
ICE_D = "#7FC4E6"
SCAR = "#a8413c"
DEFAULT = NAVY
HAIR_COLOURS = [WHITE_H, RED_H]
HAIR = {"colour": WHITE_H, "locks": []}

PROPS = [
	# harness: chest strap and shoulder straps stand proud of the suit
	{"part": "UpperTorso", "box": [2.08, 1.08, 0.16], "at": [0, 0, 3.32], "colour": "#E8EBF0", "bevel": 0.02},
	{"part": "UpperTorso", "box": [0.32, 0.1, 0.34], "at": [0, -0.56, 3.32], "colour": "#B9C0CA", "bevel": 0.03},
	{"part": "UpperTorso", "box": [0.2, 1.08, 0.7], "at": [0.56, 0, 3.62], "colour": "#E8EBF0", "bevel": 0.02, "mirror": True},
	# belt with capsules
	{"part": "LowerTorso", "box": [2.08, 1.08, 0.2], "at": [0, 0, 2.46], "colour": "#E8EBF0", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.42, 0.08, 0.28], "at": [0, -0.56, 2.46], "colour": "#B9C0CA", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.2, 0.16, 0.34], "at": [0.42, -0.56, 2.42], "colour": "#9FA8B6", "bevel": 0.06, "mirror": True},
	{"part": "LowerTorso", "box": [0.2, 0.16, 0.34], "at": [0.72, -0.56, 2.42], "colour": "#9FA8B6", "bevel": 0.06, "mirror": True},
	{"part": "LowerTorso", "box": [0.2, 0.16, 0.34], "at": [0.3, 0.56, 2.42], "colour": "#9FA8B6", "bevel": 0.06, "mirror": True},
	{"part": "LowerTorso", "box": [0.2, 0.16, 0.34], "at": [0.7, 0.56, 2.42], "colour": "#9FA8B6", "bevel": 0.06, "mirror": True},
	# high zip collar
	{"part": "UpperTorso", "box": [1.34, 1.12, 0.2], "at": [0, 0, 3.97], "colour": "#27396F", "bevel": 0.05},
]
for p in (
	dict(part="Foot", box=[1.04, 1.28, 0.3], at=[0.5, -0.11, 0.16], colour="#2C2430", bevel=0.09),
	dict(part="Foot", box=[1.08, 1.34, 0.08], at=[0.5, -0.11, 0.04], colour="#17141C", bevel=0.02),
	dict(part="UpperLeg", box=[1.06, 1.06, 0.12], at=[0.5, 0, 1.56], colour="#E8EBF0", bevel=0.02),
	dict(part="UpperLeg", box=[0.22, 0.2, 0.32], at=[0.92, -0.2, 1.42], colour="#9FA8B6", bevel=0.05),
	dict(part="LowerArm", box=[1.06, 1.06, 0.12], at=[1.5, 0, 2.56], colour="#E8EBF0", bevel=0.02),
):
	part = p.pop("part")
	PROPS.extend(lr(part, **p))

# Ice crusts his right side and flame licks off his left, the same sides as the hair: see model().

def model(parts, kit):
	head = parts["Head"]
	# ice along his right shoulder and forearm
	up, low = parts["RightUpperArm"], parts["RightLowerArm"]
	for i, (b, t, r) in enumerate((((-1.3, 0, 3.9), (-1.2, -0.1, 4.68), 0.26), ((-1.7, -0.2, 3.9), (-1.82, -0.3, 4.72), 0.3), ((-1.86, 0.22, 3.9), (-2.28, 0.34, 4.46), 0.26), ((-1.46, 0.3, 3.9), (-1.42, 0.5, 4.34), 0.22), ((-1.96, 0, 3.7), (-2.52, -0.08, 4.04), 0.2))):
		shard(kit, f"RightUpperArm_Ice{i}", b, t, r, ICE, up)
	for i, (b, t, r) in enumerate((((-1.96, -0.2, 2.9), (-2.6, -0.3, 3.1), 0.2), ((-1.96, 0.22, 2.7), (-2.64, 0.34, 2.72), 0.22), ((-1.96, -0.1, 2.46), (-2.5, -0.2, 2.26), 0.18))):
		shard(kit, f"RightLowerArm_Ice{i}", b, t, r, ICE_D if i % 2 else ICE, low)
	# flame rising off his left forearm
	hand = parts["LeftLowerArm"]
	for i, (b, d, ln, r, bx, col) in enumerate((
		((1.98, 0.3, 2.2), (0.55, 0.1, 1), 0.82, 0.2, -1.2, "#FF7A18"),
		((1.98, 0, 2.14), (0.7, 0, 1), 1.3, 0.26, -1.5, "#FF7A18"),
		((1.98, -0.3, 2.2), (0.6, -0.1, 1), 0.95, 0.2, -1.3, "#FF7A18"),
		((1.98, 0.16, 2.5), (0.9, 0.1, 1), 0.72, 0.15, -2.0, "#FF7A18"),
		((1.98, -0.16, 2.56), (0.9, -0.1, 1), 0.7, 0.15, -2.0, "#FF7A18"),
		((2.1, 0.0, 2.16), (0.5, -0.5, 1), 0.74, 0.16, -1.3, "#FFD24A"),
		((2.04, -0.3, 2.2), (0.5, -0.3, 1), 0.5, 0.11, -1.3, "#FFD24A"),
		((2.04, 0.3, 2.2), (0.5, -0.1, 1), 0.46, 0.11, -1.3, "#FFD24A"),
	)):
		tuft(kit, f"LeftLowerArm_Flame{i}", b, d, ln, r, (bx * 0.25, 0, 1.0), col, hand, flatten=0.8).pop("lock", None)
	# the parted crown is two halves, so the colours split exactly on the centre line
	for sgn, col in ((1, RED_H), (-1, WHITE_H)):
		cx = sgn * 0.37
		loft(kit, f"Head_Mass{sgn}", [(cx, 0.14, 4.1, 0.37, 0.5), (cx, 0.1, 4.6, 0.39, 0.62), (cx, 0.04, 5.05, 0.39, 0.68), (cx, 0.02, 5.32, 0.36, 0.62), (cx * 0.92, 0.02, 5.47, 0.26, 0.44)], col, head, sides=12, power=3, root=(sgn * 0.2, 0, 5.47), tip=(sgn * 0.5, 0, 4.1))

	def strand(base, mid, end, rad, col, flatten=0.42, name=[0]):
		name[0] += 1
		pts = [base, ((base[0] + mid[0]) / 2, (base[1] + mid[1]) / 2, (base[2] + mid[2]) / 2 + 0.03), mid, ((mid[0] + end[0]) / 2, (mid[1] + end[1]) / 2, (mid[2] + end[2]) / 2), end]
		tube(kit, f"Head_Strand{name[0]}", pts, [rad, rad * 1.05, rad * 0.85, rad * 0.48, 0], col, head, flatten=flatten)

	for sgn, col in ((1, RED_H), (-1, WHITE_H)):
		# fringe from the part: flat shaggy bangs swept out across the forehead, tips at the brows
		strand((sgn * 0.04, -0.46, 5.42), (sgn * 0.14, -0.66, 5.14), (sgn * 0.1, -0.68, 4.82), 0.18, col)
		strand((sgn * 0.08, -0.44, 5.42), (sgn * 0.34, -0.66, 5.14), (sgn * 0.36, -0.68, 4.78), 0.2, col)
		strand((sgn * 0.16, -0.42, 5.42), (sgn * 0.54, -0.66, 5.1), (sgn * 0.62, -0.68, 4.72), 0.2, col)
		# side curtains over the ears, ending at the jaw in pointed flicks
		strand((sgn * 0.5, -0.36, 5.32), (sgn * 0.76, -0.5, 4.9), (sgn * 0.74, -0.56, 4.36), 0.2, col)
		strand((sgn * 0.6, -0.14, 5.3), (sgn * 0.82, -0.22, 4.8), (sgn * 0.82, -0.22, 4.24), 0.24, col)
		strand((sgn * 0.6, 0.14, 5.3), (sgn * 0.84, 0.1, 4.78), (sgn * 0.86, 0.1, 4.2), 0.24, col)
		strand((sgn * 0.56, 0.4, 5.3), (sgn * 0.8, 0.42, 4.78), (sgn * 0.86, 0.46, 4.12), 0.24, col)
		# crown: flat shingles lying from the part out and back
		strand((sgn * 0.03, -0.16, 5.5), (sgn * 0.46, -0.3, 5.48), (sgn * 0.84, -0.36, 5.1), 0.22, col)
		strand((sgn * 0.03, 0.14, 5.5), (sgn * 0.48, 0.1, 5.5), (sgn * 0.9, 0.16, 5.08), 0.24, col)
		strand((sgn * 0.03, 0.36, 5.46), (sgn * 0.3, 0.6, 5.3), (sgn * 0.62, 0.76, 4.86), 0.22, col)
		# back of the head: long layered strands to the nape, tips flicking out
		strand((sgn * 0.12, 0.4, 5.42), (sgn * 0.14, 0.78, 4.94), (sgn * 0.12, 0.8, 4.2), 0.24, col)
		strand((sgn * 0.34, 0.4, 5.38), (sgn * 0.42, 0.76, 4.9), (sgn * 0.44, 0.78, 4.12), 0.24, col)
		strand((sgn * 0.54, 0.34, 5.3), (sgn * 0.66, 0.68, 4.8), (sgn * 0.74, 0.7, 4.14), 0.22, col)
		strand((sgn * 0.1, 0.5, 5.0), (sgn * 0.22, 0.84, 4.6), (sgn * 0.22, 0.82, 4.0), 0.2, col)
		strand((sgn * 0.42, 0.5, 4.96), (sgn * 0.56, 0.8, 4.5), (sgn * 0.6, 0.82, 4.02), 0.2, col)


def shard(kit, name, base, tip, r, colour, parent, sides=4):
	"""A faceted crystal or a flame tongue, widest a third of the way along."""
	m = [tuple(base[i] + (tip[i] - base[i]) * t for i in range(3)) for t in (0, 0.33, 0.66, 1)]
	tube(kit, name, m, [r * 0.7, r, r * 0.6, 0], colour, parent, flatten=1.0, sides=sides, strands=False)


def frost(f):
	"""Ice bloom on his right sleeve."""
	f.path("M-5 60L20 40L34 66L60 30L72 62L105 44V210H-5Z", "#cfe9f6", opacity=0.3)
	for x, y in ((18, 80), (60, 96), (36, 128), (78, 134), (20, 150), (56, 158)):
		f.ink(f"M{x - 7} {y}H{x + 7}M{x} {y - 7}V{y + 7}M{x - 5} {y - 5}L{x + 5} {y + 5}M{x + 5} {y - 5}L{x - 5} {y + 5}", 1.0, "#e8f7ff")


def ember(f):
	"""Heat scorch on his left sleeve."""
	f.soft("M-5 120Q50 90 105 120V210H-5Z", "#ff6a1a", 0.55, 8)
	f.soft("M10 158Q50 134 90 158V210H10Z", "#ffc24a", 0.6, 5)
	for x, y in ((22, 128), (70, 118), (44, 104)):
		f.path(f"M{x} {y}q4 -8 2 -14q7 7 3 14Z", "#ffb03a")


def arm(f, key, side):
	f.fill(NAVY)
	f.soft("M-5-5H105V14Q50 24 -5 14Z", NAVY_L, 0.45, 3)
	f.folds(4, NAVY_D, NAVY_L, y0=0.03, y1=0.3, pinch=(50, 70))
	f.folds(4, NAVY_D, NAVY_L, y0=0.42, y1=0.66, pinch=(50, 96))
	if key == "O":
		f.path("M44-5H56V150H44Z", SILVER, stroke=INK, sw=1)
	(frost if side == "Right" else ember)(f)
	# glove
	f.path("M-5 164H105V210H-5Z", "#1d2138")
	f.ink("M-5 164H105", 1.4)
	if key in "FB":
		fingers(f, 186, 205, NAVY_L)
	f.edges()


def leg(f, key):
	f.fill(NAVY)
	f.folds(3, NAVY_D, NAVY_L, y0=0.02, y1=0.3, pinch=(50, 66))
	f.folds(3, NAVY_D, NAVY_L, y0=0.46, y1=0.68, pinch=(50, 110))
	if key == "O":
		f.path("M44-5H56V150H44Z", SILVER, stroke=INK, sw=1)
	if key == "F":  # knee seams
		f.taper(18, 86, 50, 100, 82, 86, 1.6)
		f.taper(20, 112, 50, 100, 80, 112, 1.2, NAVY_D)
	# boot
	f.path("M-5 150H105V205H-5Z", "#2c2430")
	f.ink("M-5 150H105", 1.6)
	f.folds(2, "#17141c", "#5a5060", y0=0.76, y1=0.9, pinch=(50, 190))
	f.edges()


def paint(a):
	paint_hair(a, ["#f2f3f7", "#c8262c"])
	# ---- face: flat calm stare, burn scar round his left eye
	f = a["Head_F"]
	face_base(f, SKIN, shadow_top=42)
	# the scar: an uneven burn from the hairline over the eye to the cheek
	f.path("M72 30L132 26L135 92L122 104L108 92L96 96L88 80L74 72L80 56Z", SCAR)
	f.path("M78 40L126 34L128 84L118 94L106 84L98 86L92 74L82 66L86 54Z", "#c05a50", opacity=0.75)
	for d in ("M84 50Q98 44 112 48", "M116 40Q124 62 118 84", "M92 80Q104 74 114 82"):
		f.ink(d, 0.9, "#7a2622")
	f.ink("M72 30L80 56L74 72L88 80L96 96L108 92L122 104", 1.0, "#6a1e1a")
	# narrow level eyes
	anime_eye(f, 38, 68, -1, "#8a919c", w=25, h=13, arch=0.78, tilt=0.8, ir=6.4, lash=2.4, pupil=0.4)
	anime_eye(f, 92, 68, 1, "#22b6c6", w=25, h=13, arch=0.78, tilt=0.8, ir=6.4, lash=2.4, pupil=0.4)
	# thin level brows, each its hair's colour
	f.path("M52 55L25 50L24 53L52 58Z", "#c9ccd6", stroke=INK, sw=0.5)
	f.path("M78 55L105 50L106 53L78 58Z", "#8c1c20", stroke=INK, sw=0.5)
	# straight little mouth, no expression
	f.path("M55 106Q65 107 76 105L76 107Q65 109 55 108Z", "#6a3a3a")
	f.ink("M60 113Q65 114 70 113", 0.7, shade(SKIN, 0.6))
	f.ink("M62 90Q65 91 68 90", 0.8, shade(SKIN, 0.5))
	# ---- torso front: zip, chest, harness painted under the proud straps
	f = a["Torso_F"]
	f.fill(NAVY)
	f.soft("M26 24Q60 12 94 28Q92 54 58 60Q30 54 26 24Z", NAVY_L, 0.5, 5)
	f.soft("M174 24Q140 12 106 28Q108 54 142 60Q170 54 174 24Z", NAVY_L, 0.5, 5)
	f.folds(4, NAVY_D, NAVY_L, y0=0.08, y1=0.58, pinch=(100, 146))
	f.folds(4, NAVY_D, NAVY_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.path("M94 0H106V146H94Z", "#cfd4dc")
	f.ink("M94 0V146M106 0V146", 1.1)
	for y in range(6, 146, 8):
		f.ink(f"M96 {y}H104", 0.8, "#5a6070")
	f.path("M92 16H108V30H92Z", SILVER, stroke=INK, sw=1.2)
	# straps cross into the chest strap
	f.path("M36-5H60L60 62H36Z", WHITE, stroke=INK, sw=1.4)
	f.path("M164-5H140L140 62H164Z", WHITE, stroke=INK, sw=1.4)
	f.path("M60 96H84V146H60ZM116 96H140V146H116Z", NAVY_D, opacity=0.55)
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges()
	# ---- torso back: straps cross between the shoulders
	f = a["Torso_B"]
	f.fill(NAVY)
	f.folds(4, NAVY_D, NAVY_L, y0=0.1, y1=0.3, pinch=(100, 66))
	f.folds(4, NAVY_D, NAVY_L, y0=0.46, y1=0.68, pinch=(100, 146))
	f.folds(4, NAVY_D, NAVY_L, y0=0.8, y1=0.97, pinch=(100, 196))
	f.path("M36-5H62L164 62H138Z", WHITE, stroke=INK, sw=1.4)
	f.path("M164-5H138L36 62H62Z", WHITE, stroke=INK, sw=1.4)
	f.path("M84 16H116V48H84Z", SILVER, stroke=INK, sw=1.6)
	f.taper(100, 76, 101, 110, 100, 146, 1.5)
	f.taper(100, 160, 101, 180, 100, 205, 1.6)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(NAVY)
		f.folds(4, NAVY_D, NAVY_L, y0=0.08, y1=0.66, pinch=(50, 146))
		f.folds(2, NAVY_D, NAVY_L, y0=0.8, y1=0.96, pinch=(50, 190))
		f.path("M44-5H56L54 146H46Z", NAVY_D, stroke=INK, sw=1.1)
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			arm(a[f"{side}Arm_{key}"], key, side)
			leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(NAVY)
		a[f"{side}Arm_Bo"].fill("#1d2138")
		a[f"{side}Leg_T"].fill(NAVY)
		a[f"{side}Leg_Bo"].fill("#17141c")
	# ---- head sides and back, each half its colour; the curtains cover most of this
	a["Head_B"].fill("#6a4d66")
	a["Head_B"].path("M65-5H135V135H65Z", "#a92025")
	a["Head_B"].path("M-5-5H65V135H-5Z", "#d6d8e0")
	a["Head_T"].fill("#a92025")
	a["Head_T"].path("M-5-5H65V125H-5Z", "#d6d8e0")
	a["Head_Bo"].fill(SKIN_D)
	a["Head_L"].fill("#a92025")
	a["Head_L"].path("M-5 70H34Q44 100 60 135H-5Z", SKIN)
	a["Head_R"].fill("#d6d8e0")
	a["Head_R"].path("M125 70H86Q76 100 60 135H125Z", SKIN)
	a["Torso_T"].fill(NAVY)
	a["Torso_Bo"].fill(NAVY_D)
