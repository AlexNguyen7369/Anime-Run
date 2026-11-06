# Target look kit for the saw_ series (design doc section 5): the shared office uniform (white shirt, dark tie, dark suit) and the
# jagged-tooth mouth. Hair and faces stay in each char_<id>.py. bpy stays out of this file: atlas.py runs under python3.
from jk_common import form
from jk_style3 import block, dress_shoe, gem, prism, sleeve, stroke, torso_core, trouser
from style2 import Ramps

SKIN = "#f7d8c0"
SKIN_D = "#d8a88a"
SHIRT = "#f2f3f5"
SHIRT_D = "#b3b9c6"
SUIT = "#1b1d27"
SUIT_D = "#08080e"
SUIT_L = "#40445a"


def ramps(hair, **extra):
	return Ramps(
		hair=hair,
		skin=["#c49a7e", "#e8c2a8", "#f7d8c0", "#ffeadb"],
		shirt=["#a4abbb", "#ccd1dc", "#eceef2", "#ffffff"],
		suit=["#07070c", "#0e0f16", "#191b25", "#282a38", "#40435a"],
		tie=["#050508", "#0c0c12", "#181922", "#2c2d3a"],
		shoe=["#0a0a0f", "#15151c", "#26262f", "#4a4a58"],
		sole=["#050508", "#0c0c10", "#16161c", "#22222a"],
		steel=["#5c6470", "#8f97a4", "#c2c8d2", "#f2f5f8"],
		**extra,
	)


# ---- 3D


def side_strands(k, z1, ys=(-0.3, 0.12, 0.54), top=5.5, x=1.03):
	"""Loose sheets over the flat side of the hair, a little uneven at the ends, so it never reads as a slab."""
	for s in (1, -1):
		for i, y in enumerate(ys):
			gem(k, "Head", f"Strand{s}{i}", (s * x * 0.96, y, top), (s * x, y + 0.03, z1 - 0.1 * (i % 2)), 0.26, flat=0.35, twist=0.2 + 0.1 * i, across=(0, 1, 0), a=0.6)


def back_sheets(k, z1, xs=(-0.66, -0.22, 0.22, 0.66), y=0.9, top=5.4):
	for i, x in enumerate(xs):
		gem(k, "Head", f"Sheet{i}", (x, y, top), (x, y + 0.04, z1 - 0.1 * (i % 2)), 0.32, flat=0.35, twist=0.18 + 0.1 * i, across=(1, 0, 0), a=0.58)


def shirt_body(k, hem=2.24):
	"""A shirt block with its folds in the atlas; hem above 2.2 means tucked in, so call belt() too."""
	torso_core(k, hem=2.0)
	k.tube("UpperTorso", "Shirt", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.0, 1.05, 0.57), (0, 0, hem, 1.05, 0.57)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)


def belt(k):
	t = "UpperTorso"
	block(k, t, "Hip", 0, 0, 2.26, 1.88, 1.05, 0.56, "suit", ch=0.03, corner=0.12, a=0.46, b=0.56)
	block(k, t, "Belt", 0, 0, 2.34, 2.16, 1.075, 0.595, "sole", ch=0.02, corner=0.14, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.605, 2.33, 2.17, 0.12, 0.02, "steel", ch=0.012, a=0.56, b=0.4)


def collar(k, ramp="shirt"):
	t = "UpperTorso"
	block(k, t, "CollarBack", 0, 0.06, 4.1, 3.94, 0.8, 0.54, ramp, ch=0.03, corner=0.2, a=0.56, b=0.36)
	for s in (1, -1):
		prism(k, t, f"Collar{s}", [(s * 0.06, 4.0), (s * 0.78, 4.04), (s * 0.66, 3.58), (s * 0.24, 3.66)], -0.64, -0.56, ramp, a=0.6, b=0.36)


def tie(k, end=2.5, dx=0.0, top=3.86):
	"""Knot at the collar, blade down the shirt; dx pulls the end sideways for a loose tie."""
	t = "UpperTorso"
	prism(k, t, "TieKnot", [(-0.13, top), (0.13, top), (0.09, top - 0.26), (-0.09, top - 0.26)], -0.72, -0.62, "tie", a=0.52, b=0.5)
	z = top - 0.22
	prism(k, t, "TieBlade", [(-0.08, z), (0.08, z), (dx + 0.18, end + 0.24), (dx, end), (dx - 0.18, end + 0.24)], -0.67, -0.6, "tie", a=0.5, b=0.5)


def jacket(k, hem=1.84, apex=3.0):
	"""A closed-front suit jacket with real lapels: the shirt's V is painted (paint_jacket), the collar and tie sit on it."""
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.07, 0.58), (0, 0, 3.0, 1.06, 0.58), (0, 0, 2.2, 1.07, 0.59), (0, 0, hem, 1.1, 0.61)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	block(k, t, "JacketCollar", 0, 0.32, 4.12, 3.92, 0.82, 0.26, "suit", ch=0.04, a=0.54, b=0.5)
	for s in (1, -1):
		prism(k, t, f"Lapel{s}", [(s * 0.72, 4.02), (s * 1.0, 3.96), (s * 0.82, 3.4), (s * 0.08, apex - 0.06), (s * 0.02, apex + 0.04)], -0.63, -0.57, "suit", a=0.58, b=0.5)
	block(k, t, "JacketButton", 0.05, -0.61, 2.72, 2.6, 0.06, 0.02, "steel", ch=0.01, a=0.42, b=0.3)


def jacket_arm(k, side, s, cuff=2.36):
	sleeve(k, side, s, ramp="suit", cuff=cuff)
	block(k, f"{side}UpperArm", "ShirtCuff", s * 1.5, 0, cuff + 0.03, cuff - 0.1, 0.515, 0.515, "shirt", ch=0.02, corner=0.18, a=0.58, b=0.34)


def shirt_arm(k, side, s, cuff=2.36):
	sleeve(k, side, s, ramp="shirt", cuff=cuff)


def rolled_arm(k, side, s, roll=2.98):
	"""A shirt sleeve rolled to the elbow: a thick band, a bare forearm as wide as the block hand."""
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Bare", ax, 0, roll + 0.1, 2.2, 0.5, 0.5, "skin", ch=0.04, corner=0.18, a=0.58, b=0.34)
	block(k, arm, "Hand", ax, 0, 2.26, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)
	block(k, arm, "Sleeve", ax, 0, 4.03, roll, 0.52, 0.52, "shirt", ch=0.1, corner=0.18, jit=0.025, sub=1, mids=(3.5,), a=0.54, b=0.42)
	block(k, arm, "Roll", ax, 0, roll + 0.08, roll - 0.14, 0.55, 0.55, "shirt", ch=0.04, corner=0.18, jit=0.012, a=0.58, b=0.36)


def suit_leg(k, side, s):
	leg, px = trouser(k, side, s, ramp="suit")
	block(k, leg, "Crease", px, -0.585, 1.9, 0.5, 0.016, 0.012, "tie", ch=0.004, a=0.2, b=0.1)
	dress_shoe(k, leg, px)


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, colour, op=0.5, sw=6):
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=colour, sw=sw, opacity=op, blur=2)


def paint_shirt(a, buttons=True):
	f = a["Torso_F"]
	f.fill(SHIRT)
	f.path("M80 -5H120L100 30Z", SKIN_D)
	if buttons:
		stroke(f, "M100 34V190", SHIRT_D, 1.6, 0.9)
		for y in (66, 96, 126, 156):
			f.path(f"M96.5 {y}a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0Z", "#ffffff", stroke=SHIRT_D, sw=0.9)
	_fold(f, 10, 54, 36, 92, 76, 128, SHIRT_D)
	_fold(f, 190, 54, 164, 92, 124, 128, SHIRT_D)
	_fold(f, 18, 128, 44, 146, 42, 176, SHIRT_D, 0.4)
	_fold(f, 182, 128, 156, 146, 158, 176, SHIRT_D, 0.4)
	form(f, SHIRT_D, 0.5)
	f = a["Torso_B"]
	f.fill(SHIRT)
	stroke(f, "M-5 38H205", SHIRT_D, 1.4, 0.8)
	_fold(f, 14, 60, 44, 88, 86, 122, SHIRT_D)
	_fold(f, 186, 60, 156, 88, 114, 122, SHIRT_D)
	form(f, SHIRT_D, 0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SHIRT)
		_fold(f, 20, 40, 34, 90, 26, 150, SHIRT_D, 0.4)
		form(f, SHIRT_D, 0.5)
	a["Torso_T"].fill(SHIRT)
	a["Torso_Bo"].fill(SHIRT_D)


def paint_jacket(a, apex=100):
	f = a["Torso_F"]
	f.fill(SUIT)
	f.path(f"M36 -5H164L100 {apex + 6}Z", SHIRT)
	f.soft(f"M36 -5L100 {apex + 6}V{apex - 14}L56 -5Z", SHIRT_D, 0.6, 2)
	f.soft(f"M164 -5L100 {apex + 6}V{apex - 14}L144 -5Z", SHIRT_D, 0.7, 2)
	f.path("M84 -5H116L100 22Z", SKIN_D)
	stroke(f, f"M100 {apex + 6}L96 205", SUIT_D, 2.4, 0.9)
	_fold(f, 12, 50, 36, 92, 72, 128, SUIT_L)
	_fold(f, 188, 50, 164, 92, 128, 128, SUIT_L)
	_fold(f, 20, 140, 38, 160, 30, 190, SUIT_L, 0.4, 5)
	_fold(f, 180, 140, 162, 160, 170, 190, SUIT_L, 0.4, 5)
	for x in (30, 170):
		stroke(f, f"M{x - 16} 156H{x + 16}", SUIT_D, 2.4, 0.9)  # pocket flaps
	form(f, "#030306", 0.55)
	f = a["Torso_B"]
	f.fill(SUIT)
	stroke(f, "M100 20V205", SUIT_D, 2.4, 0.9)
	_fold(f, 14, 56, 44, 78, 88, 112, SUIT_L)
	_fold(f, 186, 58, 156, 80, 112, 114, SUIT_L)
	form(f, "#030306", 0.55)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SUIT)
		_fold(f, 20, 40, 34, 90, 26, 150, SUIT_L, 0.4, 5)
		form(f, "#030306", 0.55)
	a["Torso_T"].fill(SUIT)
	a["Torso_Bo"].fill(SUIT_D)


def paint_limbs(a, arm=SUIT):
	"""Under the real sleeves and trousers; only seams could show."""
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(arm)
			a[f"{side}Leg_{key}"].fill(SUIT)
		a[f"{side}Arm_T"].fill(arm)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(SUIT)
		a[f"{side}Leg_Bo"].fill(SUIT_D)


def jagged_mouth(f, x0, x1, top, h, teeth=6, lip="#3a1216", gum="#6e1a22", tooth="#fffdf6"):
	"""An open grin of triangular teeth, top row and bottom row meshing: the mouth has to read as a saw at thumbnail size."""
	w, cx = x1 - x0, (x0 + x1) / 2
	shape = f"M{x0} {top}Q{cx} {top + h * 0.12} {x1} {top}Q{x1 - w * 0.1} {top + h} {cx} {top + h}Q{x0 + w * 0.1} {top + h} {x0} {top}Z"
	f.path(shape, gum, stroke=lip, sw=1.6)
	mid = top + h * 0.5
	for row, (base, point) in enumerate(((top + h * 0.06, mid + h * 0.1), (top + h * 0.94, mid - h * 0.1))):
		dx = w * 0.86 / teeth
		start = x0 + w * 0.07 + (dx / 2 if row else 0)
		count = teeth - 1 if row else teeth
		for i in range(count):
			x = start + i * dx
			f.path(f"M{x:.1f} {base:.1f}L{x + dx:.1f} {base:.1f}L{x + dx / 2:.1f} {point:.1f}Z", tooth, stroke=lip, sw=0.5)
