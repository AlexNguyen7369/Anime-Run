# Target look for solo_vice "Jinhu" (design doc section 5): a young hunter with short light brown hair swept to one side over shaved sides, an
# earnest worried face and grey eyes, buried in shiny heavy white and orange plate: huge pauldrons, a stacked chest plate, tassets, greaves,
# sabatons. +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, form, nose
from jk_style3 import crown
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, boot, collar, ears, finish, gem, head_rest, prism

SKIN = "#f4cdac"
SKIN_D = "#cf9c78"
WHITE = "#eceef2"
WHITE_D = "#aab0bc"
ORANGE = "#ee7a1c"
ORANGE_D = "#a94c0c"
HAIR_C = "#b48a58"
DEFAULT = WHITE
R = Ramps(
	hair=["#5e4220", "#8a6636", "#b48a58", "#d6ae7c", "#f2d2a4"],
	buzz=["#7a5c34", "#94744a", "#ab8a5e", "#c4a478"],
	skin=["#bb8a64", "#e0b08c", "#f4cdac", "#ffe4ca"],
	plate=["#8a92a4", "#b8c0ce", "#e4e8ee", "#ffffff"],
	orange=["#8c3e08", "#c85f10", "#ee7a1c", "#ffa44c"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	under=["#16161e", "#262832", "#3a3c48", "#54566a"],
	sole=["#20222a", "#32343e", "#484a56", "#62646e"],
)
HAIR = {"colour": "#B48A58", "locks": []}
PROPS = []


def _hair(k):
	# short sides: a thin cap the shape of the skull, the shaved look
	block(k, "Head", "Buzz", 0, 0.12, 5.42, 4.72, 0.95, 0.78, "buzz", ch=0.06, corner=0.24, sub=1, a=0.46, b=0.34)
	crown(k, [(0.92, 5.36), (0.98, 5.56), (0.9, 5.74), (0.56, 5.88), (0.18, 5.92)])
	# the top: long flat locks all swept across to the viewer's right, rising at the front
	for i, (b, t, r) in enumerate(
		(
			((-0.72, -0.66, 5.5), (0.1, -1.08, 6.2), 0.34),
			((-0.32, -0.7, 5.56), (0.62, -1.04, 6.2), 0.34),
			((0.1, -0.7, 5.56), (1.08, -0.96, 6.02), 0.32),
			((-0.74, -0.28, 5.7), (0.18, -0.54, 6.34), 0.36),
			((-0.3, -0.26, 5.76), (0.84, -0.54, 6.24), 0.36),
			((0.1, -0.2, 5.76), (1.26, -0.44, 5.94), 0.34),
			((-0.7, 0.16, 5.72), (0.3, 0.02, 6.3), 0.36),
			((-0.24, 0.2, 5.78), (1.0, 0.06, 6.12), 0.36),
			((0.18, 0.2, 5.72), (1.28, 0.14, 5.78), 0.32),
			((-0.6, 0.58, 5.62), (0.22, 0.66, 6.0), 0.34),
			((-0.12, 0.6, 5.62), (0.92, 0.72, 5.84), 0.34),
			((-0.02, 0.76, 5.4), (0.02, 1.0, 5.0), 0.3),
		)
	):
		gem(k, "Head", f"Top{i}", b, t, r, flat=0.38, twist=0.2 + 0.1 * (i % 3), a=0.5, across=(0, 1, 0.25))
	# a short fringe on the side the hair leaves from
	gem(k, "Head", "Fringe0", (-0.56, -0.8, 5.58), (-0.82, -0.92, 5.2), 0.2, flat=0.4, twist=0.25, a=0.5, across=(0, 0, 1))
	gem(k, "Head", "Fringe1", (-0.2, -0.82, 5.62), (-0.34, -0.94, 5.24), 0.2, flat=0.4, twist=0.25, a=0.5, across=(0, 0, 1))
	for s in (1, -1):
		block(k, "Head", f"Burn{s}", s * 0.92, -0.5, 5.32, 4.86, 0.035, 0.12, "buzz", ch=0.01, a=0.5, b=0.3)


def _plate_body(k):
	t = "UpperTorso"
	art_jacket(k, hw=1.1, hd=0.62)
	collar(k, "plate", 4.02, 4.4, z0=3.88, rx=0.86, ry=0.82, power=1.6, a=0.56, b=0.42)
	# the stacked chest: a raised white breastplate with an orange centre rib and gold rim
	block(k, t, "Breast", 0, -0.04, 3.98, 2.66, 1.14, 0.66, "plate", ch=0.14, corner=0.2, sub=1, flare=-0.08, a=0.6, b=0.42)
	prism(k, t, "Rib", [(-0.62, 3.84), (0.62, 3.84), (0.56, 3.3), (0, 2.76), (-0.56, 3.3)], -0.74, -0.66, "orange", a=0.56, b=0.42)
	prism(k, t, "RibGold", [(-0.3, 3.68), (0.3, 3.68), (0.28, 3.34), (0, 3.04), (-0.28, 3.34)], -0.77, -0.72, "gold", a=0.6, b=0.4)
	for s in (1, -1):
		prism(k, t, f"Trim{s}", [(s * 0.3, 3.92), (s * 1.02, 3.92), (s * 1.02, 3.74), (s * 0.34, 3.74)], -0.72, -0.66, "orange", a=0.52, b=0.42)
	# the fauld: overlapping bands at the waist
	block(k, t, "Waist", 0, 0, 2.7, 2.44, 1.06, 0.62, "under", ch=0.03, corner=0.14, sub=1, a=0.5, b=0.5)
	block(k, t, "Belt", 0, 0, 2.54, 2.24, 1.16, 0.68, "orange", ch=0.04, corner=0.16, sub=1, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.69, 2.58, 2.2, 0.24, 0.03, "gold", ch=0.015, a=0.58, b=0.44)
	block(k, t, "BackPlate", 0, 0.62, 3.9, 2.9, 0.84, 0.08, "plate", ch=0.04, corner=0.2, a=0.52, b=0.4)
	block(k, t, "BackRib", 0, 0.7, 3.8, 3.0, 0.26, 0.04, "orange", ch=0.015, a=0.5, b=0.4)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Upper", ax, 0, 3.6, 3.0, 0.5, 0.5, "under", ch=0.04, corner=0.18, a=0.5, b=0.5)
	# the huge pauldron: three stacked lames, far wider than the arm
	block(k, arm, "Pauldron", s * 1.56, 0, 4.2, 3.72, 0.72, 0.76, "plate", ch=0.16, corner=0.24, sub=1, a=0.58, b=0.44)
	block(k, arm, "PauldronBand", s * 1.57, 0, 3.78, 3.58, 0.74, 0.78, "orange", ch=0.05, corner=0.24, sub=1, a=0.5, b=0.48)
	block(k, arm, "PauldronLow", s * 1.58, 0, 3.62, 3.3, 0.7, 0.74, "plate", ch=0.08, corner=0.24, sub=1, a=0.54, b=0.44)
	block(k, arm, "PauldronRim", s * 1.57, 0, 4.25, 4.16, 0.44, 0.48, "gold", ch=0.03, corner=0.24, a=0.58, b=0.4)
	# the vambrace and a plain block gauntlet, no fingers
	block(k, arm, "Vambrace", ax, 0, 3.04, 2.42, 0.56, 0.56, "plate", ch=0.06, corner=0.18, flare=0.03, a=0.56, b=0.44)
	block(k, arm, "VambraceBand", ax, 0, 2.5, 2.3, 0.6, 0.6, "orange", ch=0.04, corner=0.18, a=0.5, b=0.46)
	block(k, arm, "Gauntlet", ax, 0, 2.34, 1.78, 0.52, 0.52, "plate", ch=0.07, a=0.6, b=0.38)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.98, 1.1, 0.49, 0.54, "under", ch=0.04, corner=0.16, a=0.46, b=0.56)
	# tassets over the thigh, the plated knee, a heavy greave and sabaton
	block(k, leg, "Tasset", px + s * 0.06, -0.03, 2.0, 1.4, 0.54, 0.62, "plate", ch=0.08, corner=0.18, flare=0.04, a=0.56, b=0.44)
	block(k, leg, "TassetBand", px + s * 0.06, -0.03, 1.46, 1.32, 0.58, 0.66, "orange", ch=0.03, corner=0.18, a=0.5, b=0.46)
	block(k, leg, "Knee", px, -0.2, 1.2, 0.86, 0.4, 0.44, "orange", ch=0.09, corner=0.28, a=0.56, b=0.44)
	boot(k, leg, px, "plate", "sole", top=1.02)
	block(k, leg, "GreaveRib", px, -0.6, 0.86, 0.46, 0.14, 0.03, "orange", ch=0.01, a=0.52, b=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_plate_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _face(f):
	f.fill(SKIN)
	f.path("M-5-5H135V12L108 20L90 14L60 24L40 16L18 24L-5 18Z", HAIR_C)
	f.soft("M-5 16L40 24L90 22L135 16V30Q65 38 -5 30Z", SKIN_D, 0.65, 2)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.8, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	f.soft("M14 80Q28 74 36 88Q26 96 14 90Z", "#f09080", 0.16, 3)
	f.soft("M116 80Q102 74 94 88Q104 96 116 90Z", "#f09080", 0.16, 3)
	for s, cx in ((-1, 39), (1, 91)):
		# big round grey eyes, wide open
		eye2(f, cx, 64, s, 36, 19, "#6e7786", tilt=-0.4, r=12.5, lid=0.0, lash="#2a1a10", lash_t=2.6, flick=1.5, pupil=0.44, sclera="#fbf8f2", crease_line=True)
		# worried brows: the inner ends lifted
		brow2(f, cx, 45, s, 32, 5.2, -3.4, "#7c5a30", arc=-1.0)
	nose(f, SKIN, y=76, h=12)
	# a small open worried mouth
	f.path("M55 106Q65 101 75 106Q72 114 65 114Q58 114 55 106Z", "#6a2a26", stroke="#3a1612", sw=1.3)
	f.path("M57 106Q65 103 73 106L72 108Q65 106 58 108Z", "#f8f4ec")


def _sides(a):
	for n in ("Head_L", "Head_R"):
		f = a[n]
		f.path("M-5-5H125V40H-5Z", "#ab8a5e")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.86), shade(SKIN, 0.62))
	_sides(a)
	a["Head_B"].path("M-5-5H135V60H-5Z", "#ab8a5e")
	a["Head_T"].fill("#ab8a5e")
	f = a["Torso_F"]
	f.fill("#3a3c48")
	form(f, "#14141c", 0.5)
	for n in ("Torso_B", "Torso_L", "Torso_R"):
		a[n].fill("#c8ccd6")
		form(a[n], "#6a7080", 0.45)
	a["Torso_T"].fill(WHITE)
	a["Torso_Bo"].fill(WHITE_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(WHITE)
			a[f"{side}Leg_{key}"].fill("#3a3c48")
		a[f"{side}Arm_T"].fill(WHITE)
		a[f"{side}Arm_Bo"].fill(WHITE_D)
		a[f"{side}Leg_T"].fill("#3a3c48")
		a[f"{side}Leg_Bo"].fill("#20222a")
