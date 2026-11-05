# Target look for solo_mage "Jongen" (design doc section 5): dark red curtain hair parted over one eye, black rectangular glasses over glowing red
# eyes, a thin smile; a dark wine pinstripe three-piece suit with a black tie, and a long crimson coat worn open like a cape, cuffs and a gold chain.
# +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, form, nose
from jk_style3 import crown
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, dress_shoe, ears, finish, gem, head_rest, long_coat, slab, sleeve, suit_front, trouser

SKIN = "#f2cfb4"
SKIN_D = "#c4957c"
WINE = "#33202c"
WINE_D = "#180e16"
STRIPE = "#6d4556"
FRAME = "#0c0c10"
RED = "#a81c24"
DEFAULT = WINE
R = Ramps(
	hair=["#1e0408", "#3a080e", "#5a1018", "#7a1c24", "#a43438"],
	skin=["#b98a6e", "#dcae94", "#f2cfb4", "#fde6d4"],
	suit=["#120a10", "#22141c", "#33202c", "#472e3e", "#624256"],
	lapel=["#0c060a", "#180e16", "#28182a", "#3c2638"],
	coat=["#3e070c", "#5e0c12", "#841620", "#a0242c", "#c04446"],
	lining=["#1c0a0e", "#2c1218", "#3e1a22", "#54262e"],
	shirt=["#a4a0a4", "#d2ced0", "#ece8ea", "#ffffff"],
	tie=["#040406", "#0c0c10", "#1a1a20", "#30303a"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	shoe=["#0a0a0e", "#16161c", "#26262e", "#44444e"],
	sole=["#040406", "#0c0c10", "#16161c", "#24242c"],
)
HAIR = {"colour": "#5A1018", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.96, 5.34), (1.03, 5.58), (0.98, 5.84), (0.66, 6.06), (0.2, 6.14)])
	block(k, "Head", "Back", 0, 0.3, 5.46, 4.3, 0.95, 0.6, "hair", ch=0.06, corner=0.3, jit=0.015, sub=1, mids=(4.8,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.76, 5.42), (-0.74, 5.04), (-0.4, 4.76), (0.2, 4.62), (0.9, 4.46), (0.9, 5.42)], s * 0.84, s * 0.97, "hair", a=0.44, b=0.46)
	# the curtain: from a part high on the viewer's left, a heavy sheet falls across the forehead, down past the viewer's right eye's outer edge
	part = (-0.3, -0.72, 5.98)
	for i, (t, r) in enumerate((((-0.86, -0.92, 4.96), 0.3), ((-0.58, -0.96, 5.2), 0.26))):
		gem(k, "Head", f"CurtainA{i}", part, t, r, flat=0.36, twist=0.15, a=0.52, across=(1, 0, 0))
	for i, (t, r) in enumerate((((-0.04, -0.97, 5.0), 0.3), ((0.24, -0.97, 4.82), 0.3), ((0.52, -0.96, 4.74), 0.3), ((0.8, -0.95, 4.72), 0.28), ((1.02, -0.86, 4.8), 0.26))):
		gem(k, "Head", f"CurtainB{i}", part, t, r, flat=0.36, twist=0.15 + 0.08 * i, a=0.5, across=(1, 0, 0))
	# low sharp layers round the crown; no flame, the hair lies down
	for i, (b, t, r) in enumerate(
		(
			((-0.5, -0.5, 5.86), (-1.12, -0.5, 5.86), 0.32),
			((0.5, -0.5, 5.86), (1.14, -0.5, 5.8), 0.32),
			((-0.7, 0.1, 5.76), (-1.26, 0.14, 5.38), 0.33),
			((0.7, 0.1, 5.76), (1.26, 0.14, 5.34), 0.33),
			((-0.6, 0.5, 5.7), (-1.1, 0.8, 5.14), 0.33),
			((0.6, 0.5, 5.7), (1.1, 0.8, 5.14), 0.33),
			((0, 0.5, 5.9), (0, 1.06, 5.5), 0.36),
			((-0.3, -0.1, 6.02), (-0.72, 0.5, 6.24), 0.36),
			((0.26, -0.1, 6.02), (0.72, 0.46, 6.2), 0.36),
			((-0.6, 0.72, 5.0), (-0.86, 1.06, 4.34), 0.32),
			((0, 0.76, 5.0), (0.02, 1.12, 4.22), 0.34),
			((0.6, 0.72, 5.0), (0.88, 1.06, 4.36), 0.32),
		)
	):
		gem(k, "Head", f"Layer{i}", b, t, r, flat=0.42, twist=0.3, a=0.5)


def _suit(k):
	t = "UpperTorso"
	art_jacket(k)
	suit_front(k, "shirt", "tie", "lapel", wide=0.62, low=3.1)
	# the waistcoat line and a gold watch chain
	block(k, t, "Belt", 0, 0, 2.3, 2.1, 1.07, 0.59, "tie", ch=0.02, corner=0.14, sub=1, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.6, 2.32, 2.08, 0.1, 0.02, "gold", ch=0.015, a=0.58, b=0.44)
	# the crimson coat over the shoulders: open at the front, a broad back, wide shoulders, the lining at its edge
	for s in (1, -1):
		block(k, t, f"CoatOpen{s}", s * 0.94, -0.46, 4.04, 1.86, 0.16, 0.18, "coat", ch=0.03, a=0.5, b=0.5)
		block(k, t, f"CoatFace{s}", s * 0.76, -0.62, 4.04, 1.86, 0.03, 0.05, "lining", ch=0.01, a=0.5, b=0.4)
	block(k, t, "CoatBack", 0, 0.28, 4.05, 1.86, 1.14, 0.38, "coat", ch=0.04, corner=0.14, sub=1, a=0.48, b=0.52, g=0.12)
	block(k, t, "CoatCollar", 0, 0.4, 4.42, 3.92, 0.92, 0.26, "coat", ch=0.06, corner=0.2, sub=1, flare=-0.06, a=0.52, b=0.52)
	long_coat(k, "coat", "lining", hem=0.5, gap=0.42)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="coat", cuff=2.48)
	block(k, f"{side}UpperArm", "ShirtCuff", s * 1.5, 0, 2.56, 2.44, 0.545, 0.545, "shirt", ch=0.02, corner=0.18, a=0.6, b=0.32)
	block(k, f"{side}UpperArm", "CuffFold", s * 1.5, 0, 2.84, 2.56, 0.555, 0.555, "lining", ch=0.03, corner=0.18, a=0.5, b=0.4)
	# gold rings as thin bands on the plain block hand, the source's eight rings reduced to one band each
	block(k, f"{side}UpperArm", "Ring", s * 1.5, 0, 2.08, 1.98, 0.51, 0.51, "gold", ch=0.015, a=0.62, b=0.34)


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


def _stripes(f, x0, x1, step=14):
	x = x0
	while x <= x1:
		f.path(f"M{x} -5V{f.h + 5}", stroke=STRIPE, sw=1.4, opacity=0.85)
		x += step


def _torso(a):
	f = a["Torso_F"]
	f.fill(WINE)
	_stripes(f, 4, 196)
	f.path("M100 112V205", stroke=WINE_D, sw=3)
	f.soft("M20 40Q60 90 92 118L84 124Q44 94 14 54Z", WINE_D, 0.5, 2)
	f.soft("M180 40Q140 90 108 118L116 124Q156 94 186 54Z", WINE_D, 0.5, 2)
	for y in (122, 146):
		f.path(f"M{100 - 3} {y}a3 3 0 1 0 6 0a3 3 0 1 0 -6 0Z", "#0c0c10")
	form(f, "#0a0408", 0.55)
	for n in ("Torso_B", "Torso_L", "Torso_R"):
		a[n].fill(WINE)
		form(a[n], "#0a0408", 0.5)
	a["Torso_T"].fill(WINE)
	a["Torso_Bo"].fill(WINE_D)


def _glasses(f):
	"""Black rectangles: painted on the face block so they stay crisp at thumbnail size."""
	for cx in (38, 92):
		f.path(f"M{cx - 25} 54H{cx + 25}L{cx + 22} 80H{cx - 22}Z", "none", stroke=FRAME, sw=4.2)
	f.path("M63 62Q65 60 67 62", stroke=FRAME, sw=3.4)
	f.path("M-5 58H13", stroke=FRAME, sw=3.6)
	f.path("M117 58H135", stroke=FRAME, sw=3.6)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V38Q65 44 -5 38Z", SKIN_D, 0.75, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.9, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	for s, cx in ((-1, 38), (1, 92)):
		f.soft(f"M{cx - 18} 67Q{cx} 54 {cx + 18} 67Q{cx} 80 {cx - 18} 67Z", "#ff3a3a", 0.4, 3)
		eye2(f, cx, 67, s, 31, 10, "#e03030", tilt=3.0, r=8.0, lid=0.25, lash="#120a0e", lash_t=2.8, flick=2.4, pupil=0.3, sclera="#ffe8e0", crease_line=False)
		brow2(f, cx, 47, s, 33, 5.0, 3.2, "#3a080e")
	_glasses(f)
	nose(f, SKIN, y=82, h=12)
	# a thin knowing smile
	f.path("M49 107Q66 113 83 103", stroke="#5a2a28", sw=2.1)
	f.path("M81 100Q84 103 84 106", stroke="#5a2a28", sw=1.4)


def _head_rest(a):
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.62))
	# the glasses' temple arm runs back to the ear
	for n in ("Head_L", "Head_R"):
		a[n].path("M-5 58H125", stroke=FRAME, sw=3.2)
	a["Head_T"].fill("#3a080e")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	_head_rest(a)
	_torso(a)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(RED)
			a[f"{side}Leg_{key}"].fill(WINE)
		a[f"{side}Arm_T"].fill(RED)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(WINE)
		a[f"{side}Leg_Bo"].fill(WINE_D)
