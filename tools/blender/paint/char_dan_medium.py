# Target look for dan_medium "Seika" (design doc section 5): silver hair combed back into a tall tower tied with a red band and a burst of ends on top,
# red half-rim glasses, big gold hoops, a blue varsity jacket with white striped sleeves over a buttoned yellow vest and crossed navy straps on a dark
# high top, dark shorts, wooden sandals, a metal bat held low. Block body as everyone's. +X is the viewer's right. Drawn in-house.
import math

from dan_style3 import SKIN, SKIN_D, Kit, T, bake, big_head, block, brow2, core_leg, crown, ear, eye, face, finish, gem, hairline, hoop, mop, nose, prism, ramps, rblock, rest, scalp, sleeve, stroke, torso_core

BLUE = "#285a90"
DEFAULT = BLUE
R = ramps(
	["#80849e", "#a8acc6", "#d0d2e4", "#e8e8f4", "#ffffff"],
	blue=["#10263e", "#1c4268", "#2a6296", "#5690c4"],
	yellow=["#8c6e1c", "#c4a032", "#ead05a", "#fff0a0"],
	plum=["#141226", "#1e1c3a", "#2c2a52", "#44427a"],
	steel=["#5c6470", "#8f97a4", "#c2c8d2", "#f6f8fb"],
	wood=["#5c3c1c", "#8c6030", "#b88848", "#e0b878"],
)
HAIR = {"colour": "#D0D2E4", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.96, 5.2), (1.03, 5.46), (0.98, 5.78), (0.74, 6.04), (0.5, 6.2)])
	block(k, "Head", "Cap", 0, 0.02, 5.62, 5.12, 1.0, 0.9, "hair", ch=0.08, corner=0.22, jit=0.015, sub=1, a=0.5, b=0.42)
	block(k, "Head", "Nape", 0, 0.5, 5.3, 4.24, 0.98, 0.42, "hair", ch=0.08, corner=0.25, jit=0.02, sub=1, mids=(4.8,), a=0.46, b=0.42)
	# everything combed up off the neck to the tower
	for i, d in enumerate((20, 55, 90, 125, 160)):
		c, s = math.cos(math.radians(d)), math.sin(math.radians(d))
		gem(k, "Head", f"Up{i}", (0.7 * c, 0.6 * s, 4.6), (0.4 * c, 0.1 + 0.36 * s, 6.34), 0.46, flat=0.34, bend=0.0, twist=0.15, across=(-s, c, 0), a=0.5)
	# combed sheets over the back, pointed at the nape
	for i, (x, tx) in enumerate(((-0.7, -0.8), (-0.24, -0.3), (0.24, 0.2), (0.7, 0.76))):
		gem(k, "Head", f"Sheet{i}", (x * 0.5, 0.74, 5.9), (tx, 0.98, 4.1), 0.36, flat=0.34, bend=0.04, twist=0.15 + 0.1 * i, across=(1, 0, 0), a=0.54)
	for s in (1, -1):
		gem(k, "Head", f"Temple{s}", (s * 0.96, -0.3, 4.96), (s * 0.4, 0.1, 6.3), 0.42, flat=0.34, twist=0.2, across=(0, 1, 0), a=0.52)
		gem(k, "Head", f"Wisp{s}", (s * 0.96, -0.6, 5.2), (s * 0.99, -0.72, 4.56), 0.1, flat=0.6, across=(0, 1, 0), a=0.5)
	# the front: a smooth sweep from a side part, high off the brow
	for i, (b, t, r) in enumerate((
		((0.62, -0.74, 5.42), (-0.1, -0.2, 6.3), 0.36), ((0.14, -0.78, 5.42), (-0.1, -0.2, 6.3), 0.36), ((-0.36, -0.78, 5.42), (0.0, -0.2, 6.3), 0.36), ((-0.8, -0.68, 5.4), (0.1, -0.1, 6.3), 0.34),
	)):
		gem(k, "Head", f"Front{i}", b, t, r, flat=0.4, bend=0.16, twist=0.2, across=(1, 0, 0), a=0.56)
	gem(k, "Head", "Sweep", (0.56, -0.84, 5.52), (-1.04, -0.9, 4.98), 0.34, flat=0.45, bend=0.1, twist=0.3, across=(0, 0, 1), a=0.58)
	gem(k, "Head", "Sweep2", (0.5, -0.84, 5.5), (1.04, -0.84, 4.98), 0.28, flat=0.45, bend=0.1, twist=0.2, across=(0, 0, 1), a=0.56)
	# the tower in three faceted tiers, the red band, the burst of ends
	o = k.lathe("Head", "Tower", [(0.64, 5.9, 0.5), (0.66, 6.04, 0.5), (0.54, 6.2, 0.5), (0.5, 6.24, 0.5), (0.54, 6.38, 0.5), (0.42, 6.54, 0.5), (0.36, 6.6, 0.5)], "hair", n=9, at=(0, 0.1, 0), outline=0)
	bake(o, "hair", k, a=0.52, b=0.4, tone=0.05)
	o = k.lathe("Head", "Band", [(0.4, 6.52, 0.5), (0.44, 6.55, 0.5), (0.44, 6.65, 0.5), (0.4, 6.68, 0.5)], "red", n=9, at=(0, 0.1, 0), outline=0)
	bake(o, "red", k, a=0.56, b=0.4)
	for i in range(9):
		a = 2 * math.pi * i / 9 + 0.2
		gem(k, "Head", f"Burst{i}", (0.2 * math.cos(a), 0.1 + 0.2 * math.sin(a), 6.64), (0.72 * math.cos(a), 0.1 + 0.72 * math.sin(a), 6.98 - 0.14 * (i % 2)), 0.17, flat=0.6, bend=0.3, a=0.58)
	gem(k, "Head", "BurstTop", (0, 0.1, 6.62), (0.06, 0.1, 7.12), 0.2, flat=0.8, a=0.6)


def _glasses(k):
	"""Half-rim: the frame runs under each eye only."""
	y = -0.9
	for s in (1, -1):
		prism(k, "Head", f"Rim{s}", [(s * 0.1, 4.7), (s * 0.17, 4.7), (s * 0.22, 4.48), (s * 0.58, 4.46), (s * 0.7, 4.7), (s * 0.8, 4.74), (s * 0.64, 4.37), (s * 0.16, 4.39)], y - 0.04, y + 0.03, "red", a=0.6, b=0.36)
		block(k, "Head", f"Temple{s}G", s * 0.93, -0.44, 4.76, 4.68, 0.035, 0.46, "red", ch=0.015, a=0.56, b=0.36)
		block(k, "Head", f"Hinge{s}", s * 0.85, y + 0.02, 4.77, 4.67, 0.1, 0.04, "red", ch=0.015, a=0.6, b=0.36)
	block(k, "Head", "Bridge", 0, y, 4.68, 4.61, 0.13, 0.035, "red", ch=0.012, a=0.6, b=0.36)


def _body(k):
	torso_core(k)
	# a dark high top closes the neck, crossed straps over it
	block(k, T, "Top", 0, 0, 3.98, 2.6, 0.98, 0.5, "plum", ch=0.05, a=0.5, b=0.46)
	block(k, T, "Neck", 0, 0, 4.1, 3.9, 0.64, 0.58, "plum", ch=0.04, corner=0.3, a=0.5, b=0.46)
	for s in (1, -1):
		prism(k, T, f"Strap{s}", [(s * 0.5, 4.04), (s * 0.28, 4.04), (s * -0.3, 3.4), (s * -0.08, 3.4)], -0.58, -0.48, "blue", a=0.5, b=0.4)
	# the yellow vest and its big buttons
	prism(k, T, "Vest", [(-0.6, 3.6), (-0.3, 3.62), (0, 3.4), (0.3, 3.62), (0.6, 3.6), (0.62, 2.1), (0.14, 1.94), (-0.14, 1.94), (-0.62, 2.1)], -0.64, -0.5, "yellow", a=0.54, b=0.44)
	block(k, T, "VestBack", 0, 0, 3.3, 2.1, 0.99, 0.52, "yellow", ch=0.03, a=0.5, b=0.44)
	# the vest is cut in panels: raised side panels, a button placket, trim at the top, points at the hem
	for s in (1, -1):
		prism(k, T, f"Panel{s}", [(s * 0.17, 3.42), (s * 0.3, 3.58), (s * 0.56, 3.54), (s * 0.5, 2.96), (s * 0.58, 2.2), (s * 0.18, 2.0)], -0.69, -0.6, "yellow", a=0.62, b=0.44)
		prism(k, T, f"VestTrim{s}", [(0, 3.46), (s * 0.3, 3.68), (s * 0.6, 3.66), (s * 0.6, 3.56), (s * 0.3, 3.56), (0, 3.34)], -0.72, -0.6, "gold", a=0.5, b=0.4)
		prism(k, T, f"VestTuck{s}", [(s * 0.3, 2.9), (s * 0.34, 2.9), (s * 0.4, 2.2), (s * 0.34, 2.2)], -0.71, -0.66, "gold", a=0.3, b=0.3)
		prism(k, T, f"VestPoint{s}", [(s * 0.02, 2.06), (s * 0.4, 2.1), (s * 0.2, 1.78)], -0.68, -0.58, "yellow", a=0.52, b=0.4)
	for i, z in enumerate((3.1, 2.72, 2.34)):
		block(k, T, f"Button{i}", 0, -0.67, z + 0.1, z - 0.1, 0.1, 0.05, "yellow", ch=0.03, corner=0.5, a=0.72, b=0.3)
	# the open jacket: white raglan shoulders, blue body, striped hem band
	block(k, T, "JBack", 0, 0.22, 4.02, 2.02, 1.08, 0.42, "blue", ch=0.05, a=0.5, b=0.5)
	block(k, T, "JCollar", 0, 0.2, 4.2, 3.94, 0.86, 0.5, "blue", ch=0.05, corner=0.25, a=0.56, b=0.46)
	block(k, T, "JCollarLine", 0, 0.2, 4.13, 4.07, 0.875, 0.515, "shirt", ch=0.015, corner=0.25, a=0.6, b=0.36)
	block(k, T, "JHemB", 0, 0.23, 2.12, 1.84, 1.1, 0.43, "blue", ch=0.03, a=0.42, b=0.5)
	block(k, T, "JHemLB", 0, 0.23, 2.02, 1.95, 1.115, 0.445, "shirt", ch=0.015, a=0.6, b=0.36)
	for s in (1, -1):
		block(k, T, f"JFront{s}", s * 0.8, -0.4, 4.02, 2.02, 0.29, 0.24, "blue", ch=0.05, jit=0.012, a=0.52, b=0.5)
		block(k, T, f"JHem{s}", s * 0.8, -0.41, 2.12, 1.84, 0.31, 0.25, "blue", ch=0.03, a=0.44, b=0.5)
		block(k, T, f"JHemL{s}", s * 0.8, -0.42, 2.02, 1.95, 0.32, 0.26, "shirt", ch=0.015, a=0.6, b=0.36)
		for i, z in enumerate((3.4, 2.9, 2.4)):
			block(k, T, f"Snap{s}{i}", s * 0.6, -0.65, z + 0.06, z - 0.06, 0.06, 0.025, "gold", ch=0.02, corner=0.5, a=0.66, b=0.3)
	block(k, T, "Shorts", 0, 0, 2.14, 1.86, 1.0, 0.52, "plum", ch=0.03, a=0.46)


def _bat(k):
	"""A metal bat held low from the fist, forward and out, so it never hides the face in the portrait."""
	arm = "RightUpperArm"
	ax, y, grip = -1.5, -0.3, 2.14
	turn = ((ax, y, grip), -50, 0, -34)
	rblock(k, arm, "Knob", ax, y, 2.82, 2.7, 0.16, 0.16, "black", ch=0.03, corner=0.5, rot=turn, a=0.56)
	rblock(k, arm, "Grip", ax, y, 2.72, 1.5, 0.1, 0.1, "red", ch=0.02, corner=0.5, flare=0.01, rot=turn, a=0.54, b=0.42)
	rblock(k, arm, "Barrel", ax, y, 1.52, 0.5, 0.11, 0.11, "steel", ch=0.02, corner=0.5, flare=0.12, rot=turn, a=0.54, b=0.5)
	rblock(k, arm, "BarrelEnd", ax, y, 0.52, -0.5, 0.24, 0.24, "steel", ch=0.08, corner=0.5, rot=turn, a=0.56, b=0.5)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="shirt", cuff=2.46)
	arm, ax = f"{side}UpperArm", s * 1.5
	for i, z in enumerate((3.22, 2.96)):
		block(k, arm, f"Stripe{i}", ax, 0, z + 0.09, z - 0.07, 0.535, 0.535, "blue", ch=0.02, corner=0.18, a=0.5, b=0.48)
	block(k, arm, "JCuff", ax, 0, 2.68, 2.42, 0.545, 0.545, "blue", ch=0.04, corner=0.18, a=0.48, b=0.5)
	block(k, arm, "JCuffLine", ax, 0, 2.59, 2.52, 0.555, 0.555, "shirt", ch=0.015, corner=0.18, a=0.6, b=0.36)


def _leg(k, side, s):
	leg, px = core_leg(k, side, s)
	block(k, leg, "ShortLeg", px, 0, 1.98, 1.14, 0.5, 0.55, "plum", ch=0.04, flare=0.03, corner=0.16, jit=0.02, a=0.46, b=0.56)
	block(k, leg, "Bare", px, 0, 1.2, 0.2, 0.46, 0.49, "skin", ch=0.04, corner=0.14, a=0.58, b=0.34)
	block(k, leg, "Foot", px, -0.24, 0.36, 0.14, 0.46, 0.52, "skin", ch=0.06, corner=0.2, a=0.58, b=0.34)
	block(k, leg, "Sole", px, -0.14, 0.16, 0.0, 0.54, 0.7, "wood", ch=0.03, corner=0.2, a=0.54)
	block(k, leg, "Strap", px, -0.3, 0.42, 0.24, 0.5, 0.2, "yellow", ch=0.04, corner=0.2, a=0.6, b=0.36)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ear(k)
	_hair(k)
	_glasses(k)
	for s in (1, -1):
		hoop(k, "Head", f"Hoop{s}", (s * 1.02, -0.1, 4.15), 0.25, 0.045, "gold", a=0.6, b=0.4)
	_body(k)
	_bat(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _face(f):
	face(f, blush=None)
	hairline(f, "#a8acc6")
	for s, cx in ((-1, 37), (1, 93)):
		eye(f, cx, 60, s, ("#3a1810", "#7a3a22", "#b86a44"), w=37, up=14, dn=9, inner=5, outer=-6, ir=(11, 13), pu=(3.4, 5.0), wing=7, thick=1.5, lid=0.34)
		brow2(f, cx, 40, s, 30, 3.6, 5.0, "#8a8ea8", arc=-3)
	nose(f)
	f.path("M55 107Q60 104 65 106Q70 104 75 107Q65 113 55 107Z", "#c8505a")
	f.path("M53 107Q65 109 78 105", stroke="#6c2430", sw=1.6)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#a8acc6", BLUE, "#eceef2", SKIN)
	scalp(a, "#a8acc6")
