# Target look kit for the kaiju_ series (design doc section 5): the shared jk_style3 and ds_style3 solids plus the defence corps' combat
# suit that four of them wear: black bodysuit, dark green chest plates, pale shoulder plates and gauntlets. Hair, faces and weapons stay
# in each char_<id>.py. bpy stays lazy: atlas.py runs this under python3.
from atlas import shade  # noqa: F401
from ds_style3 import block as rblock  # noqa: F401  takes rot
from ds_style3 import eye, gem, xf  # noqa: F401
from jk_common import brow2  # noqa: F401
from jk_style3 import bake
from jk_style3 import block, collar, crown, ears, head_rest, prism, slab, stroke  # noqa: F401
from style2 import Kit, Ramps  # noqa: F401
from style3 import big_head, finish  # noqa: F401

T = "UpperTorso"
BLACK = "#1a1c20"
SUIT = dict(
	suit=["#08080c", "#111319", "#1c1f29", "#2e323e", "#454a58"],
	green=["#0b2017", "#163828", "#215038", "#316a4b", "#4c8a6a"],
	plate=["#5c5f66", "#83868d", "#a8abb2", "#c6c9cf", "#e2e4e8"],
	line=["#060608", "#0c0d10", "#14161a", "#22252a"],
	steel=["#4a4f58", "#7c838e", "#b0b7c0", "#e4e8ee"],
	gun=["#0c0d10", "#191b20", "#2a2d34", "#444852", "#646a76"],
	edge=["#8890a0", "#b8c0ce", "#e4e8f0", "#ffffff"],
)


def suit_torso(k):
	k.reshape(T, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, T, "Suit", 0, 0, 4.0, 1.94, 1.05, 0.56, "suit", ch=0.06, jit=0.02, mids=(3.4, 2.8, 2.4), a=0.46, b=0.56, g=0.1, tone=0.03)
	collar(k, "suit", 4.12, 4.3, z0=3.84, rx=0.76, ry=0.74, a=0.56, b=0.5)
	for s in (1, -1):
		block(k, T, f"CollarStud{s}", s * 0.26, -0.75, 4.08, 3.98, 0.07, 0.025, "plate", ch=0.015, a=0.66, b=0.3)
		# the green chest plate, a big rounded shield on each side of the zip
		prism(k, T, f"Chest{s}", [(s * 0.13, 3.5), (s * 0.3, 3.66), (s * 0.86, 3.62), (s * 0.96, 3.34), (s * 0.82, 3.06), (s * 0.46, 2.94), (s * 0.18, 3.12)], -0.68, -0.54, "green", a=0.56, b=0.5, g=0.16)
		# the pale bar over the collarbone, out to the shoulder plate
		prism(k, T, f"Bar{s}", [(s * 0.12, 3.8), (s * 0.5, 3.8), (s * 1.04, 3.96), (s * 1.04, 3.78), (s * 0.56, 3.68), (s * 0.12, 3.7)], -0.66, -0.54, "plate", a=0.6, b=0.36)
		block(k, T, f"Stud{s}", s * 0.64, -0.58, 2.88, 2.8, 0.09, 0.04, "plate", ch=0.02, a=0.64, b=0.3)
		# abdomen seams, real grooves of darker strip
		for i, z in enumerate((2.72, 2.52)):
			prism(k, T, f"Seam{s}{i}", [(s * 0.1, z - 0.06), (s * 0.5, z), (s * 0.86, z + 0.1), (s * 0.86, z + 0.05), (s * 0.5, z - 0.05), (s * 0.1, z - 0.11)], -0.585, -0.55, "line", a=0.4, b=0.2)
		# belt buckles and the two hip cases
		block(k, T, f"Buckle{s}", s * 0.62, -0.6, 2.4, 2.1, 0.2, 0.06, "plate", ch=0.03, a=0.56, b=0.4)
		block(k, T, f"BeltEnd{s}", s * 1.06, 0, 2.4, 2.12, 0.05, 0.4, "plate", ch=0.02, a=0.5, b=0.4)
	block(k, T, "Zip", 0, -0.575, 4.0, 1.98, 0.035, 0.03, "steel", ch=0.01, a=0.62, b=0.34)
	block(k, T, "Belt", 0, 0, 2.36, 2.14, 1.09, 0.6, "line", ch=0.02, a=0.62, b=0.5)
	# back: the plate of the suit's unit between the shoulder blades
	prism(k, T, "BackUnit", [(-0.5, 3.84), (0.5, 3.84), (0.42, 3.0), (0, 2.72), (-0.42, 3.0)], 0.54, 0.7, "green", a=0.5, b=0.46)
	block(k, T, "BackBar", 0, 0.62, 3.96, 3.8, 0.94, 0.07, "plate", ch=0.03, a=0.54, b=0.4)
	block(k, T, "Spine", 0, 0.6, 2.8, 2.2, 0.1, 0.05, "steel", ch=0.02, a=0.5, b=0.4)


def suit_arm(k, side, s, glove="suit"):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 3.98, 2.78, 0.5, 0.5, "suit", ch=0.08, corner=0.18, jit=0.02, sub=1, mids=(3.4,), a=0.48, b=0.56)
	# the pale shoulder plate: a sloping cap that flares outwards, a second tier under it and a ragged outer skirt
	block(k, arm, "Cap", s * 1.64, 0, 4.24, 3.5, 0.5, 0.58, "plate", ch=0.1, corner=0.22, flare=0.13, a=0.56, b=0.44, g=0.14)
	block(k, arm, "CapLow", s * 1.68, 0, 3.56, 3.24, 0.54, 0.6, "plate", ch=0.05, corner=0.22, flare=0.06, a=0.44, b=0.44)
	slab(k, "Skirt", [(-0.5, 3.4), (0.5, 3.4), (0.54, 3.04), (0.3, 2.94), (0.1, 3.06), (-0.2, 2.88), (-0.54, 3.04)], *sorted((s * 2.08, s * 2.22)), "plate", part=arm, a=0.5, b=0.36)
	block(k, arm, "Rivet", s * 1.66, -0.7, 3.8, 3.68, 0.07, 0.04, "steel", ch=0.015, a=0.4, b=0.3)
	# the corps mark's place: a plain notched dark disc shape, not the corps' emblem
	slab(k, "Mark", [(-0.2, 3.56), (0, 3.78), (0.2, 3.56), (0.12, 3.4), (0, 3.52), (-0.12, 3.4)], *sorted((s * 2.2, s * 2.29)), "line", part=arm, a=0.5, b=0.1)
	block(k, arm, "Elbow", s * 1.54, 0.06, 2.96, 2.7, 0.52, 0.52, "green", ch=0.06, corner=0.2, a=0.52, b=0.46)
	block(k, arm, "Gauntlet", ax, 0, 2.76, 2.3, 0.54, 0.54, "plate", ch=0.05, corner=0.2, a=0.54, b=0.42)
	block(k, arm, "GauntletRim", ax, 0, 2.38, 2.24, 0.575, 0.575, "plate", ch=0.03, corner=0.2, a=0.58, b=0.36)
	for i, z in enumerate((2.64, 2.5)):
		prism(k, arm, f"Rib{i}", [(ax - 0.4, z + 0.04), (ax, z - 0.06), (ax + 0.4, z + 0.04), (ax + 0.4, z), (ax, z - 0.1), (ax - 0.4, z)], -0.56, -0.53, "steel", a=0.4, b=0.1)
	block(k, arm, "Hand", ax, 0, 2.3, 1.78, 0.5, 0.5, glove, ch=0.06, a=0.6, b=0.46)


def suit_leg(k, side, s):
	leg, x, px = f"{side}UpperLeg", s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.98, 0.9, 0.5, 0.55, "suit", ch=0.04, corner=0.16, jit=0.02, mids=(1.5,), a=0.46, b=0.56)
	block(k, leg, "Strap", px, 0, 1.5, 1.4, 0.52, 0.57, "plate", ch=0.02, corner=0.16, a=0.5, b=0.4)
	block(k, leg, "Case", s * 1.1, 0, 1.94, 1.24, 0.1, 0.34, "green", ch=0.04, a=0.52, b=0.44)
	block(k, leg, "CaseLid", s * 1.12, 0, 1.96, 1.8, 0.11, 0.36, "line", ch=0.03, a=0.6, b=0.4)
	block(k, leg, "Knee", px, -0.5, 1.2, 0.82, 0.36, 0.14, "green", ch=0.06, corner=0.3, a=0.56, b=0.46)
	block(k, leg, "Shaft", px, 0, 0.94, 0.14, 0.52, 0.58, "suit", ch=0.05, corner=0.18, a=0.5, b=0.56)
	prism(k, leg, "Shin", [(px - 0.4, 0.86), (px, 0.76), (px + 0.4, 0.86), (px + 0.34, 0.4), (px, 0.3), (px - 0.34, 0.4)], -0.67, -0.54, "plate", a=0.56, b=0.4)
	block(k, leg, "Ankle", px, 0.04, 0.5, 0.3, 0.55, 0.6, "plate", ch=0.03, corner=0.2, a=0.52, b=0.42)
	block(k, leg, "Foot", px, -0.34, 0.42, 0.13, 0.5, 0.44, "suit", ch=0.08, corner=0.24, a=0.56, b=0.5)
	block(k, leg, "Sole", px, -0.14, 0.15, 0.0, 0.55, 0.72, "line", ch=0.03, a=0.6)


def suit(k):
	suit_torso(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		suit_arm(k, side, s)
		suit_leg(k, side, s)


def top_layers(k, xs, z=5.3, y=-1.02, r=0.28, root=(-0.3, 6.08), bend=0.6):
	"""Broad flat locks from the crown over the dome to the fringe, so the top reads as hair and not as a cap."""
	for i, x in enumerate(xs):
		gem(k, "Head", f"Layer{i}", (x * 0.3, root[0], root[1]), (x * 0.96, y + 0.1 * abs(x), z + 0.06 * (i % 2)), r, flat=0.42, twist=0.2 + 0.12 * (i % 3), bend=bend, across=(1, 0, 0), a=0.5 + 0.05 * (i % 2))


def hair_back(k, nape=4.02, temple=True):
	"""The back of the head: a rounded backing down to the nape with two overlapping rows of locks, and a panel at each temple."""
	rows = [(0, 0.5, 5.7, 0.8, 0.42), (0, 0.48, 5.3, 0.94, 0.5), (0, 0.48, 4.7, 0.94, 0.5), (0, 0.5, nape + 0.24, 0.84, 0.42), (0, 0.5, nape + 0.1, 0.7, 0.34)]
	o = k.tube("Head", "BackShell", rows, "hair", corner=0.5, nc=2, outline=0)
	bake(o, "hair", k, a=0.46, b=0.4, tone=0.03)
	for i, x in enumerate((-0.74, -0.38, 0.0, 0.38, 0.74)):
		gem(k, "Head", f"BackTop{i}", (x * 0.7, 0.62, 5.86), (x * 1.08, 1.12 - 0.12 * abs(x), 4.66 + 0.1 * (i % 2)), 0.32, flat=0.45, twist=0.15 + 0.1 * (i % 3), bend=0.1, across=(1, 0, 0), a=0.52 + 0.04 * (i % 2))
	for i, x in enumerate((-0.62, -0.22, 0.2, 0.6)):
		gem(k, "Head", f"BackLow{i}", (x, 0.78, 5.1), (x * 1.04, 1.0, nape + 0.08 * (i % 2)), 0.3, flat=0.45, twist=0.2 + 0.1 * (i % 2), across=(1, 0, 0), a=0.46)
	if temple:
		for s in (1, -1):
			slab(k, f"Temple{s}", [(-0.7, 5.58), (0.4, 5.6), (0.4, 4.86), (-0.1, 4.92), (-0.44, 5.02), (-0.7, 5.2)], *sorted((s * 0.86, s * 0.97)), "hair", a=0.48, b=0.4)


def fist_grip(k, side, s, y=-0.62):
	"""A plain block of glove over the hilt, so the weapon is seen held; no fingers."""
	block(k, f"{side}UpperArm", "GripHand", s * 1.5, y - 0.06, 2.24, 1.9, 0.26, 0.16, "suit", ch=0.05, corner=0.2, a=0.68, b=0.46)


def skin_face(f, skin, dark, blush=0.2):
	"""Flat anime skin: a hair shadow, soft sides and jaw, a small nose. The caller draws eyes and mouth."""
	f.skin = skin
	f.fill(skin)
	f.soft("M-5-5H135V26Q65 32 -5 26Z", dark, 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.65, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.45, 3)
	for d in ("M14 80Q28 74 36 88Q26 96 14 90Z", "M116 80Q102 74 94 88Q104 96 116 90Z"):
		f.soft(d, "#f48c84", blush, 3)
	f.soft("M60 88L65 80L70 88Q65 92 60 88Z", dark, 0.5, 1)
	f.path("M61 89Q65 91 69 89", stroke=shade(dark, 0.75), sw=1.0)


def suit_paint(a, skin, hair):
	head_rest(a, shade(skin, 0.84), shade(skin, 0.62))
	# hair colour under the hair, so no gap between locks shows skin; the front edge of each side stays a cheek
	a["Head_T"].fill(hair)
	a["Head_B"].fill(hair)
	a["Head_L"].path("M-5-5H125V116H62V48H-5Z", hair)
	a["Head_R"].path("M-5-5H125V48H58V116H-5Z", hair)
	for n in list(a.faces):
		if n.startswith(("Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg")):
			a[n].fill(BLACK)
