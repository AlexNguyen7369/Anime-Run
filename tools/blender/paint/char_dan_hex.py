# Target look for dan_hex "Jijo" (design doc section 5): a full crimson crop split over the brow, warm brown eyes and an open sunny grin,
# blue hoop earrings, an open bright blue school blazer over a white shirt and loose dark tie, pale grey trousers, brown shoes.
# Block body as everyone's. +X is the viewer's right. Drawn in-house.
from dan_style3 import SKIN, Kit, T, big_head, block, brow2, crown, dress_shoe, ear, eye, face, finish, gem, hairline, hoop, jacket_back, mop, nape, nose, prism, ramps, rest, scalp, shirt_collar, sleeve, stroke, torso_core, trouser

BLUE = "#2a62ae"
DEFAULT = BLUE
R = ramps(
	["#660a2c", "#981a42", "#c42e52", "#e0546e", "#f88c98"],
	blue=["#10284e", "#1c4480", "#2c66b4", "#5a94dc"],
	tie=["#0a0e1c", "#141a2e", "#222a44", "#3a4464"],
	grey=["#68748a", "#8e9ab0", "#b4bece", "#d8e0ea"],
	ring=["#0a4a9a", "#1478d0", "#2ea4f4", "#8cd8ff"],
)
HAIR = {"colour": "#CC2C44", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.3), (1.06, 5.54), (1.02, 5.84), (0.72, 6.08), (0.2, 6.16)])
	nape(k, 4.06, y0=0.06)
	# a thick layered crop: sides to the top of the ear, back to the nape
	mop(k, "Back", [(d, z, 0.36) for d, z in ((14, 4.6), (34, 4.3), (54, 4.1), (72, 3.96), (90, 3.92), (108, 3.96), (126, 4.1), (146, 4.3), (166, 4.6))], rx=1.08, ry=1.02, zroot=5.7)
	mop(k, "Side", [(-2, 4.92, 0.34), (-24, 4.86, 0.3), (182, 4.92, 0.34), (204, 4.86, 0.3)], rx=1.1, zroot=5.8)
	mop(k, "Over", [(d, 5.2, 0.4) for d in (0, 36, 72, 108, 144, 180)], rx=1.14, ry=1.1, zroot=6.0, root=0.5, bend=0.2, a=0.56, swirl=14)
	# the fringe: heavy blunt locks thrown both ways from a part just off centre
	for i, (b, t, r) in enumerate((
		((0.1, -0.7, 6.0), (-0.14, -1.0, 5.14), 0.22), ((-0.05, -0.7, 6.0), (-0.46, -1.02, 4.94), 0.27), ((-0.3, -0.7, 5.98), (-0.78, -1.0, 4.9), 0.28), ((-0.56, -0.62, 5.9), (-1.04, -0.9, 4.86), 0.3),
		((0.14, -0.7, 6.0), (0.36, -1.02, 5.06), 0.23), ((0.3, -0.7, 5.98), (0.7, -1.02, 4.92), 0.28), ((0.56, -0.62, 5.9), (1.02, -0.92, 4.86), 0.3),
	)):
		gem(k, "Head", f"Fringe{i}", b, t, r, flat=0.42, bend=0.12, twist=0.15 + 0.1 * (i % 3), across=(1, 0, 0), a=0.54)
	# big swept layers over the crown, all thrown to the viewer's right, so the top is not an even helmet
	for i, (b, t, r) in enumerate((((-0.6, -0.3, 6.0), (0.5, -0.9, 5.66), 0.36), ((-0.3, 0.1, 6.08), (1.0, -0.5, 5.84), 0.4), ((-0.2, 0.5, 6.0), (1.12, 0.4, 5.6), 0.4), ((-0.2, -0.3, 6.04), (-1.16, -0.5, 5.46), 0.36), ((-0.3, 0.4, 6.0), (-1.16, 0.5, 5.5), 0.38), ((0.2, 0.6, 6.0), (0.3, 1.2, 5.3), 0.42))):
		gem(k, "Head", f"Layer{i}", b, t, r, flat=0.5, bend=0.16, twist=0.2 + 0.12 * (i % 3), a=0.6)
	gem(k, "Head", "FringeBig", (0.2, -0.6, 6.1), (-0.66, -1.1, 4.82), 0.32, flat=0.5, bend=0.2, twist=0.3, across=(1, 0, 0), a=0.62)
	gem(k, "Head", "FringeBig2", (0.2, -0.6, 6.1), (0.9, -1.1, 4.86), 0.3, flat=0.5, bend=0.2, twist=0.3, across=(1, 0, 0), a=0.62)
	for i, (b, t) in enumerate((((0.1, -0.1, 6.0), (0.3, -0.36, 6.36)), ((-0.2, 0.1, 6.0), (-0.5, 0.1, 6.3)))):
		gem(k, "Head", f"Tuft{i}", b, t, 0.2, flat=0.6, a=0.56)


def _body(k):
	torso_core(k)
	block(k, T, "Shirt", 0, 0, 3.98, 2.1, 0.98, 0.5, "shirt", ch=0.05, a=0.56, b=0.38)
	shirt_collar(k)
	# a loose tie, knot pulled down from the open collar
	prism(k, T, "Knot", [(-0.12, 3.6), (0.12, 3.6), (0.09, 3.38), (-0.09, 3.38)], -0.68, -0.52, "tie", a=0.58, b=0.4)
	prism(k, T, "Tie", [(-0.09, 3.4), (0.09, 3.4), (0.2, 2.5), (0.04, 2.3), (-0.12, 2.5)], -0.62, -0.5, "tie", a=0.5, b=0.4)
	# the open blazer: back shell, two fronts, lapels, pocket flaps
	block(k, T, "Back", 0, 0.22, 4.02, 1.84, 1.08, 0.42, "blue", ch=0.05, a=0.48, b=0.5)
	for s in (1, -1):
		block(k, T, f"Front{s}", s * 0.76, -0.4, 4.02, 1.84, 0.33, 0.24, "blue", ch=0.05, jit=0.012, a=0.5, b=0.5)
		prism(k, T, f"Lapel{s}", [(s * 0.5, 4.04), (s * 0.92, 4.0), (s * 0.96, 3.5), (s * 0.84, 3.42), (s * 0.5, 2.86)], -0.71, -0.6, "blue", a=0.62, b=0.4)
		block(k, T, f"Pocket{s}", s * 0.78, -0.65, 2.42, 2.28, 0.22, 0.03, "blue", ch=0.02, a=0.36, b=0.4)
	jacket_back(k, "blue", hem=1.86)
	block(k, T, "Belt", 0, 0, 2.2, 2.02, 1.0, 0.53, "loafer", ch=0.02, a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ear(k)
	_hair(k)
	for s in (1, -1):
		hoop(k, "Head", f"Hoop{s}", (s * 1.0, -0.1, 4.26), 0.16, 0.055, "ring", n=10, a=0.6, b=0.36)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="blue", cuff=2.44)
		block(k, f"{side}UpperArm", "ShirtCuff", s * 1.5, 0, 2.47, 2.34, 0.515, 0.515, "shirt", ch=0.02, corner=0.18, a=0.58, b=0.34)
		leg, px = trouser(k, side, s, ramp="grey")
		dress_shoe(k, leg, px, ramp="loafer")
	finish()


def _face(f):
	face(f)
	hairline(f, "#981a42")
	for s, cx in ((-1, 37), (1, 93)):
		eye(f, cx, 66, s, ("#3a1a10", "#7a4220", "#c88048"), w=34, up=14, dn=10, inner=3, outer=-3, ir=(11.5, 14), pu=(3.6, 5.2), wing=3, thick=1.1, lid=0.18)
		brow2(f, cx, 45, s, 30, 4.6, 1.5, "#8c1a30", arc=-2.5)
	nose(f)
	# the open grin
	f.path("M42 98Q65 102 88 98Q84 118 65 119Q46 118 42 98Z", "#6a1a22", stroke="#4a1218", sw=1.6)
	f.path("M45 100Q65 104 85 100L83 106Q65 110 47 106Z", "#fffdf6")
	f.path("M54 115Q65 110 76 115Q65 119 54 115Z", "#e8707a")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#a01a34", BLUE, BLUE, "#8e9ab0")
	scalp(a, "#981a42")
