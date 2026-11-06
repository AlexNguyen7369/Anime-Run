# Target look for solo_beast "Yunho" (design doc section 5): rust-orange hair swept straight back in sharp blades off a bare heavy brow, glowing amber
# eyes under a deep scowl, one fang showing; a sharp black suit, white shirt and black tie, and heavy gold claws that jut from each plain block fist.
# +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, form, nose
from jk_style3 import crown
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, dress_shoe, ears, finish, gem, head_rest, slab, sleeve, stroke, suit_front, trouser

SKIN = "#eebf9a"
SKIN_D = "#b98660"
SUIT = "#1c1d26"
SUIT_D = "#0b0b12"
SUIT_L = "#3c3e50"
DEFAULT = SUIT
R = Ramps(
	hair=["#44120a", "#6e2010", "#963218", "#b84c26", "#d8784a"],
	skin=["#a97a58", "#d6a47e", "#eebf9a", "#fad8b8"],
	suit=["#07070c", "#10111a", "#1c1d26", "#2c2e3c", "#46485a"],
	lapel=["#040408", "#0b0b12", "#16161f", "#2a2a36"],
	shirt=["#a4a6ac", "#d2d4d8", "#eeeff2", "#ffffff"],
	tie=["#040406", "#0c0c10", "#1a1a20", "#30303a"],
	gold=["#7a5208", "#b8841c", "#e8b436", "#ffe07a"],
	shoe=["#07070b", "#12121a", "#22222c", "#40404c"],
	sole=["#040406", "#0c0c10", "#16161c", "#24242c"],
)
HAIR = {"colour": "#963218", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.97, 5.34), (1.05, 5.58), (1.0, 5.84), (0.66, 6.08), (0.2, 6.16)])
	block(k, "Head", "Back", 0, 0.3, 5.46, 4.4, 0.96, 0.6, "hair", ch=0.06, corner=0.3, jit=0.02, sub=1, mids=(4.9,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.3, 5.46), (-0.18, 5.0), (0.2, 4.82), (0.9, 4.62), (0.9, 5.46)], s * 0.84, s * 0.98, "hair", a=0.44, b=0.46)
		# blades flying back off the temples: the mane, wider than the head
		gem(k, "Head", f"Temple{s}", (s * 0.84, -0.3, 5.38), (s * 1.52, 0.5, 5.04), 0.32, flat=0.42, twist=0.2, a=0.52)
		gem(k, "Head", f"Temple2{s}", (s * 0.84, -0.1, 5.66), (s * 1.6, 0.66, 5.52), 0.34, flat=0.42, twist=0.3, a=0.52)
		gem(k, "Head", f"Temple3{s}", (s * 0.7, 0.0, 5.9), (s * 1.42, 0.82, 6.0), 0.34, flat=0.42, twist=0.2, a=0.52)
		gem(k, "Head", f"Nape{s}", (s * 0.8, 0.6, 5.0), (s * 1.3, 1.1, 4.46), 0.34, flat=0.42, twist=0.25, a=0.48)
	# the top: long blades rising from a bare hairline and sweeping straight back
	for i, (b, t, r) in enumerate(
		(
			((-0.62, -0.72, 5.52), (-0.84, -0.46, 6.46), 0.34),
			((-0.22, -0.76, 5.52), (-0.3, -0.42, 6.62), 0.36),
			((0.22, -0.76, 5.52), (0.3, -0.42, 6.64), 0.36),
			((0.62, -0.72, 5.52), (0.84, -0.46, 6.48), 0.34),
			((-0.42, -0.1, 6.0), (-0.58, 0.76, 6.72), 0.36),
			((0.04, -0.1, 6.04), (0.04, 0.84, 6.84), 0.38),
			((0.44, -0.1, 6.0), (0.6, 0.76, 6.7), 0.36),
			((-0.3, 0.46, 5.9), (-0.42, 1.34, 6.12), 0.36),
			((0.3, 0.46, 5.9), (0.44, 1.34, 6.1), 0.36),
			((0, 0.66, 5.4), (0, 1.5, 5.32), 0.38),
			((-0.5, 0.7, 5.3), (-0.8, 1.32, 4.96), 0.34),
			((0.5, 0.7, 5.3), (0.82, 1.32, 4.94), 0.34),
		)
	):
		gem(k, "Head", f"Blade{i}", b, t, r, flat=0.4, twist=0.25, a=0.52)
	# two stray locks over the brow
	gem(k, "Head", "Stray0", (-0.32, -0.82, 5.56), (-0.46, -0.94, 5.12), 0.16, flat=0.4, twist=0.2, a=0.52, across=(0, 0, 1))
	gem(k, "Head", "Stray1", (0.5, -0.82, 5.56), (0.62, -0.94, 5.2), 0.15, flat=0.4, twist=0.2, a=0.52, across=(0, 0, 1))


def _suit(k):
	t = "UpperTorso"
	art_jacket(k)
	suit_front(k, "shirt", "tie", "lapel", wide=0.62, low=3.0)
	block(k, t, "Belt", 0, 0, 2.26, 2.06, 1.07, 0.59, "tie", ch=0.02, corner=0.14, sub=1, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.6, 2.28, 2.04, 0.1, 0.02, "gold", ch=0.015, a=0.58, b=0.44)
	# the jacket's skirt, split at the front
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		block(k, leg, "JacketF", s * 0.56, -0.61, 2.0, 1.6, 0.44, 0.05, "suit", ch=0.02, a=0.46, b=0.56)
		block(k, leg, "JacketB", s * 0.56, 0.61, 2.0, 1.6, 0.56, 0.05, "suit", ch=0.02, a=0.44, b=0.56)
		block(k, leg, "JacketS", s * 1.08, 0, 2.0, 1.6, 0.05, 0.64, "suit", ch=0.02, a=0.46, b=0.56)


def _claws(k, side, s):
	"""Three heavy gold claws on a band round the plain fist, curving down and forward. The hand stays one smooth block."""
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "ClawBand", ax, 0, 2.3, 2.02, 0.54, 0.54, "gold", ch=0.04, a=0.54, b=0.48)
	for i, dx in enumerate((-0.32, 0, 0.32)):
		x = ax + dx
		gem(k, arm, f"Claw{i}", (x, -0.42, 1.92), (x + s * 0.02, -0.76, 1.08), 0.15, ramp="gold", flat=0.7, bend=-0.08, twist=0.2, a=0.56, b_=0.5)
		gem(k, arm, f"ClawRoot{i}", (x, -0.3, 2.14), (x, -0.5, 1.76), 0.16, ramp="gold", flat=0.7, twist=0.2, a=0.52, b_=0.5)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="suit", cuff=2.48)
	block(k, f"{side}UpperArm", "ShirtCuff", s * 1.5, 0, 2.54, 2.42, 0.54, 0.54, "shirt", ch=0.02, corner=0.18, a=0.6, b=0.32)
	_claws(k, side, s)


def _leg(k, side, s):
	leg, px = trouser(k, side, s, "suit", low=0.42)
	dress_shoe(k, leg, px, top=0.46)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=6):
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=SUIT_L, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(SUIT)
	f.path("M100 112V205", stroke=SUIT_D, sw=3)
	_fold(f, 16, 60, 40, 92, 74, 124)
	_fold(f, 184, 60, 160, 92, 126, 124)
	for y in (132,):
		f.path(f"M{100 - 3.5} {y}a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0Z", "#0a0a10")
	# the breast pocket
	f.path("M136 66h34v5h-34Z", "#0a0a10")
	form(f, "#030306", 0.55)
	for n in ("Torso_B", "Torso_L", "Torso_R"):
		a[n].fill(SUIT)
		form(a[n], "#030306", 0.5)
	a["Torso_B"].path("M100 120V205", stroke=SUIT_D, sw=3)
	a["Torso_T"].fill(SUIT)
	a["Torso_Bo"].fill(SUIT_D)


def _face(f):
	f.fill(SKIN)
	# the hairline stays high: a bare brow, a heavy shadow under the ridge
	f.path("M-5-5H135V6L112 14L92 8L66 18L44 9L20 15L-5 7Z", "#963218")
	f.soft("M-5 6L44 14L92 13L135 6V20Q65 26 -5 20Z", SKIN_D, 0.75, 2)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.8, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.95, 5)
	f.soft("M28 122Q65 112 102 122V135H28Z", SKIN_D, 0.6, 3)
	# creases of the scowl across the forehead
	for y, d in ((26, 0), (33, 3)):
		f.path(f"M{44 + d} {y}Q65 {y + 3} {86 - d} {y}", stroke=SKIN_D, sw=1.3, opacity=0.9)
	f.soft("M12 46Q38 40 58 58L56 66Q36 54 14 58Z", SKIN_D, 0.7, 2)
	f.soft("M118 46Q92 40 72 58L74 66Q94 54 116 58Z", SKIN_D, 0.7, 2)
	for s, cx in ((-1, 38), (1, 92)):
		f.soft(f"M{cx - 20} 66Q{cx} 50 {cx + 20} 64Q{cx} 80 {cx - 20} 66Z", "#ffb020", 0.55, 3)
		eye2(f, cx, 66, s, 34, 10, "#f0a018", tilt=5.0, r=8.0, lid=0.32, lash="#160a06", lash_t=3.4, flick=2.4, pupil=0.32, sclera="#fff0c8", crease_line=False, slit=True)
		# the heavy brow pulled hard down
		brow2(f, cx, 50, s, 40, 8.4, 6.8, "#7a240a")
	stroke(f, "M60 46L63 56", SKIN_D, 1.6, 0.95)
	stroke(f, "M70 46L67 56", SKIN_D, 1.6, 0.95)
	nose(f, SKIN, y=76, h=15)
	f.path("M56 92Q65 96 74 92", stroke=SKIN_D, sw=1.4, opacity=0.9)
	# a hard mouth, showing teeth and one fang
	f.path("M42 106Q65 100 88 106Q84 118 65 118Q46 118 42 106Z", "#3a120e", stroke="#1e0806", sw=1.6)
	f.path("M45 107Q65 102 85 107L83 112Q65 108 47 112Z", "#fbf6ec")
	f.path("M50 106L54 115L58 105Z", "#ffffff", stroke="#7a6a5a", sw=0.5)
	f.path("M72 105L76 115L80 106Z", "#ffffff", stroke="#7a6a5a", sw=0.5)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.6))
	a["Head_T"].fill("#6e2010")
	_torso(a)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SUIT)
			a[f"{side}Leg_{key}"].fill(SUIT_D)
		a[f"{side}Arm_T"].fill(SUIT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(SUIT)
		a[f"{side}Leg_Bo"].fill(SUIT_D)
