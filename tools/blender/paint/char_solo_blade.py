# Target look for solo_blade "Cha Hain" (design doc section 5): a blonde shoulder-length bob with a side-swept fringe, calm grey eyes, a black high-collar
# undersuit under crimson and gold knight plate: pauldrons, a cuirass, a plated skirt, greaves; a long dark blade with a silver grip held point-up
# in her right hand. Same block body as everyone: no slimming, the likeness is hair, face, paint and garments. +X is the viewer's right. Drawn in-house.
from atlas import shade
from ds_style3 import eye, xf
from jk_common import brow2, form
from jk_style3 import crown
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, boot, collar, ears, finish, gem, head_rest, prism, rblock

SKIN = "#f8d6bc"
SKIN_D = "#d4a386"
BLACK = "#1a1a24"
BLACK_D = "#0a0a10"
CRIM = "#b0242a"
GOLD = "#e6b84a"
DEFAULT = BLACK
R = Ramps(
	hair=["#a07c3a", "#c8a258", "#e6c67e", "#f4dea4", "#fdf2d0"],
	skin=["#c8987c", "#e8bca0", "#f8d6bc", "#ffeadb"],
	under=["#08080e", "#12121a", "#1e1e2a", "#32323f", "#4a4a5c"],
	crim=["#3e0c10", "#621216", "#8a1c22", "#a82e30", "#c8504c"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	steel=["#5c6470", "#8f97a4", "#c2c8d2", "#f2f5f8"],
	blade=["#0e0e16", "#1c1c28", "#30303e", "#4c4c60"],
	edge=["#8890a0", "#b8c0ce", "#e4e8f0", "#ffffff"],
	sole=["#08080c", "#14141a", "#24242c", "#36363e"],
)
HAIR = {"colour": "#E6C67E", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.34), (1.06, 5.56), (1.02, 5.8), (0.7, 6.0), (0.22, 6.08)])
	# the bob: a solid helmet of hair to the jaw on the sides and back, cut straight
	block(k, "Head", "Bob", 0, 0.24, 5.5, 4.0, 1.08, 0.72, "hair", ch=0.08, corner=0.3, sub=1, flare=0.1, jit=0.02, mids=(5.0, 4.5), a=0.46, b=0.42)
	# locks falling past the jaw round the face, the blunt tips of the cut
	for s in (1, -1):
		gem(k, "Head", f"Front{s}", (s * 0.84, -0.66, 5.4), (s * 1.02, -0.86, 4.0), 0.3, flat=0.4, twist=0.15, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Cheek{s}", (s * 1.0, -0.3, 5.3), (s * 1.28, -0.44, 3.84), 0.36, flat=0.4, twist=0.25, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Mid{s}", (s * 1.06, 0.2, 5.3), (s * 1.42, 0.24, 3.86), 0.42, flat=0.4, twist=0.3, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Rear{s}", (s * 0.86, 0.68, 5.3), (s * 1.2, 0.98, 3.86), 0.42, flat=0.4, twist=0.25, across=(1, 0, 0), a=0.48)
	gem(k, "Head", "RearC", (0, 0.8, 5.3), (0, 1.14, 3.82), 0.46, flat=0.4, twist=0.25, across=(1, 0, 0), a=0.48)
	# the side-swept fringe: from a part on the viewer's right across the brow, not over the eyes
	part = (0.42, -0.74, 5.92)
	for i, (t, r) in enumerate((((-1.04, -0.92, 5.08), 0.3), ((-0.78, -0.96, 5.14), 0.28), ((-0.46, -0.97, 5.2), 0.27), ((-0.14, -0.97, 5.22), 0.26), ((0.16, -0.97, 5.16), 0.24))):
		gem(k, "Head", f"Fringe{i}", part, t, r, flat=0.36, twist=0.15 + 0.06 * i, a=0.54, across=(1, 0, 0))
	for i, (t, r) in enumerate((((0.6, -0.97, 5.1), 0.24), ((0.92, -0.92, 5.04), 0.26))):
		gem(k, "Head", f"FringeR{i}", part, t, r, flat=0.36, twist=0.2, a=0.54, across=(1, 0, 0))
	# the volume on top: smooth flat layers, no spikes up
	for i, (b, t, r) in enumerate(
		(
			((-0.4, -0.1, 5.82), (-1.1, -0.14, 5.5), 0.38),
			((0.4, -0.1, 5.82), (1.1, -0.14, 5.5), 0.38),
			((0, 0.2, 5.86), (0, 0.98, 5.5), 0.42),
			((-0.36, 0.3, 5.76), (-1.0, 0.72, 5.3), 0.38),
			((0.36, 0.3, 5.76), (1.0, 0.72, 5.3), 0.38),
		)
	):
		gem(k, "Head", f"Top{i}", b, t, r, flat=0.42, twist=0.25, a=0.52)


def _plate(k):
	t = "UpperTorso"
	art_jacket(k)
	# the black standing collar, the look's top line
	collar(k, "under", 4.2, 4.5, z0=3.9, rx=0.74, ry=0.7, power=1.3, a=0.5, b=0.6)
	block(k, t, "CollarGold", 0, -0.71, 4.18, 4.1, 0.34, 0.02, "gold", ch=0.015, a=0.6, b=0.4)
	# the crimson cuirass: pointed down the middle, with gold rims
	prism(k, t, "Cuirass", [(-1.04, 3.8), (-0.42, 3.92), (0, 3.68), (0.42, 3.92), (1.04, 3.8), (1.06, 2.86), (0.34, 2.56), (0, 2.42), (-0.34, 2.56), (-1.06, 2.86)], -0.66, -0.58, "crim", a=0.54, b=0.5)
	# gold rim round the neck and down the middle, no emblem
	prism(k, t, "RimL", [(-0.5, 3.92), (-0.42, 3.92), (0, 3.68), (0, 3.56)], -0.69, -0.65, "gold", a=0.58, b=0.44)
	prism(k, t, "RimR", [(0.5, 3.92), (0.42, 3.92), (0, 3.68), (0, 3.56)], -0.69, -0.65, "gold", a=0.58, b=0.44)
	prism(k, t, "Rib", [(-0.07, 3.56), (0.07, 3.56), (0.07, 2.6), (0, 2.46), (-0.07, 2.6)], -0.69, -0.65, "gold", a=0.58, b=0.44)
	for s in (1, -1):
		prism(k, t, f"Curve{s}", [(s * 1.04, 3.2), (s * 0.34, 2.72), (s * 0.34, 2.6), (s * 1.04, 3.06)], -0.69, -0.65, "gold", a=0.54, b=0.44)
	block(k, t, "BackPlate", 0, 0.6, 3.82, 2.8, 0.96, 0.05, "crim", ch=0.03, corner=0.18, a=0.5, b=0.46)
	block(k, t, "Belt", 0, 0, 2.48, 2.26, 1.09, 0.61, "gold", ch=0.025, corner=0.14, sub=1, a=0.54, b=0.5)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Upper", ax, 0, 3.8, 2.96, 0.5, 0.5, "under", ch=0.04, corner=0.18, a=0.5, b=0.5)
	# layered pauldron, gold on crimson
	block(k, arm, "Pauldron", s * 1.54, 0, 4.2, 3.72, 0.62, 0.64, "crim", ch=0.13, corner=0.24, sub=1, a=0.54, b=0.5)
	block(k, arm, "PauldronRim", s * 1.55, 0, 3.8, 3.62, 0.64, 0.66, "gold", ch=0.05, corner=0.24, sub=1, a=0.56, b=0.46)
	block(k, arm, "PauldronLow", s * 1.56, 0, 3.66, 3.36, 0.58, 0.6, "crim", ch=0.06, corner=0.24, sub=1, a=0.5, b=0.48)
	block(k, arm, "Vambrace", ax, 0, 3.0, 2.46, 0.54, 0.54, "crim", ch=0.05, corner=0.18, flare=0.02, a=0.52, b=0.48)
	block(k, arm, "VambraceRim", ax, 0, 2.54, 2.42, 0.565, 0.565, "gold", ch=0.03, corner=0.18, a=0.56, b=0.44)
	block(k, arm, "Hand", ax, 0, 2.46, 1.78, 0.5, 0.5, "under", ch=0.06, a=0.56, b=0.42)


def _sword(k):
	"""Long and straight, dark with a pale edge, held low, tip forward and out, the source's ready stance. Built pointing down, then swung from the fist."""
	arm = "RightUpperArm"
	ax, y, grip = -1.5, -0.3, 2.14
	turn = ((ax, y, grip), -55, 0, -30)
	rblock(k, arm, "Grip", ax, y, 2.62, 1.76, 0.08, 0.08, "steel", ch=0.015, rot=turn, a=0.56, b=0.46)
	rblock(k, arm, "Pommel", ax, y, 2.78, 2.6, 0.12, 0.12, "gold", ch=0.03, rot=turn, a=0.56, b=0.46)
	rblock(k, arm, "Guard", ax, y, 1.72, 1.6, 0.42, 0.1, "gold", ch=0.03, corner=0.3, rot=turn, a=0.56, b=0.46)
	w, tip = 0.14, -1.2
	body = [(ax - w, 1.62), (ax + w, 1.62), (ax + w, tip + 0.46), (ax, tip), (ax - w, tip + 0.46)]
	xf(prism(k, arm, "Blade", body, y - 0.04, y + 0.04, "blade", a=0.52, b=0.5), *turn)
	for d in (1, -1):
		edge = [(ax + d * w, 1.62), (ax + d * (w + 0.06), 1.62), (ax + d * (w + 0.06), tip + 0.5), (ax, tip - 0.08), (ax + d * w, tip + 0.46)]
		xf(prism(k, arm, f"Edge{d}", edge, y - 0.02, y + 0.02, "edge", a=0.62, b=0.34), *turn)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.98, 1.1, 0.49, 0.54, "under", ch=0.04, corner=0.16, a=0.46, b=0.56)
	# the plated skirt: real panels, front and back of each leg, gold-edged
	block(k, leg, "SkirtF", px + s * 0.06, -0.58, 2.0, 1.24, 0.5, 0.05, "crim", ch=0.02, flare=0.03, a=0.52, b=0.5)
	block(k, leg, "SkirtFG", px + s * 0.06, -0.62, 1.32, 1.18, 0.54, 0.035, "gold", ch=0.012, a=0.56, b=0.44)
	block(k, leg, "SkirtS", s * 1.09, 0, 2.0, 1.32, 0.05, 0.56, "crim", ch=0.02, flare=0.03, a=0.5, b=0.5)
	block(k, leg, "SkirtB", px + s * 0.06, 0.58, 2.0, 1.24, 0.5, 0.05, "crim", ch=0.02, flare=0.03, a=0.5, b=0.5)
	boot(k, leg, px, "crim", "sole", top=1.0, cuff="gold")
	block(k, leg, "Knee", px, -0.52, 1.14, 0.74, 0.26, 0.09, "gold", ch=0.04, corner=0.3, a=0.56, b=0.46)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_plate(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_sword(k)
	finish()


# ---- paint


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V28Q65 34 -5 28Z", SKIN_D, 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.65, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.45, 3)
	f.soft("M14 80Q28 74 36 88Q26 96 14 90Z", "#f48c84", 0.22, 3)
	f.soft("M116 80Q102 74 94 88Q104 96 116 90Z", "#f48c84", 0.22, 3)
	for s, cx in ((-1, 37), (1, 93)):
		# large, level grey eyes with heavy lashes and a calm lid
		eye(f, cx, 66, s, ("#4a5260", "#8892a4", "#ccd6e4"), w=36, up=15, dn=11, inner=3, outer=-3, ir=(11, 14), pu=(3.2, 4.8), lash="#2a1c10", wing=5, thick=1.25, lid=0.22)
		brow2(f, cx, 44, s, 30, 3.2, 1.0, "#b98c2c", arc=-1.5)
	f.soft("M60 88L65 80L70 88Q65 92 60 88Z", SKIN_D, 0.5, 1)
	f.path("M61 89Q65 91 69 89", stroke="#b47e66", sw=1.0)
	# small closed lips, faint colour
	f.path("M56 107Q65 110 74 107Q65 113 56 107Z", "#d0605c")
	f.path("M55 107Q65 108 75 107", stroke="#7c3030", sw=1.3)


def _torso(a):
	f = a["Torso_F"]
	f.fill(BLACK)
	form(f, "#030306", 0.55)
	for n in ("Torso_B", "Torso_L", "Torso_R"):
		a[n].fill(BLACK)
		form(a[n], "#030306", 0.5)
	a["Torso_T"].fill(BLACK)
	a["Torso_Bo"].fill(BLACK_D)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.62))
	a["Head_T"].fill("#c8a258")
	_torso(a)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(BLACK)
			a[f"{side}Leg_{key}"].fill(BLACK)
		a[f"{side}Arm_T"].fill(BLACK)
		a[f"{side}Arm_Bo"].fill(BLACK_D)
		a[f"{side}Leg_T"].fill(BLACK)
		a[f"{side}Leg_Bo"].fill(BLACK_D)
