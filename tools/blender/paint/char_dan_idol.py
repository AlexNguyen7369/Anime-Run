# Target look for dan_idol "Airah" (design doc section 5): soft rose-pink hair with a side part, a long sweep across the brow, one ear clear and a
# long lock on the other side, dark magenta eyes, a closed navy school blazer, white collar and red bow, striped white cuffs, a pleated skirt,
# white knee socks, brown loafers. Block body as everyone's. +X is the viewer's right. Drawn in-house.
from dan_style3 import SKIN, Kit, T, big_head, block, bow, brow2, crown, ear, eye, face, finish, gem, hairline, jacket, jacket_back, mop, nape, nose, pleats, prism, ramps, rest, scalp, shirt_collar, sleeve, sock_leg, stroke

NAVY = "#222a48"
DEFAULT = NAVY
R = ramps(
	["#8e3462", "#c4568c", "#ee82b2", "#fbaacc", "#ffd8e8"],
	navy=["#161e3c", "#222c54", "#323f6e", "#4a5888"],
)
HAIR = {"colour": "#EE82B2", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.3), (1.06, 5.54), (1.03, 5.84), (0.74, 6.1), (0.22, 6.2)])
	nape(k, 3.98)
	mop(k, "Back", [(d, z, 0.38) for d, z in ((14, 4.2), (40, 3.98), (66, 3.9), (90, 3.86), (114, 3.9), (140, 4.1), (166, 4.5))], rx=1.1, ry=1.06, zroot=5.7)
	mop(k, "Over", [(d, 4.9, 0.42) for d in (10, 45, 80, 115, 150)], rx=1.14, ry=1.12, zroot=5.96, root=0.55, bend=0.2, a=0.56)
	# the ends flick outward at the nape
	for i, (b, t) in enumerate((((0.9, 0.6, 4.5), (1.4, 0.72, 4.02)), ((0.5, 0.96, 4.4), (0.74, 1.4, 3.86)), ((-0.4, 0.96, 4.4), (-0.7, 1.4, 3.9)), ((-0.86, 0.7, 4.6), (-1.3, 0.9, 4.2)))):
		gem(k, "Head", f"Flick{i}", b, t, 0.24, flat=0.5, a=0.54)
	# tucked behind the ear on the viewer's left
	for i, (b, t, r) in enumerate((((-0.8, -0.5, 5.84), (-1.1, 0.3, 4.7), 0.3), ((-0.8, -0.6, 5.8), (-1.08, -0.2, 4.84), 0.32), ((-0.84, -0.64, 5.7), (-1.04, -0.84, 4.7), 0.22))):
		gem(k, "Head", f"Tuck{i}", b, t, r, flat=0.4, twist=0.2, across=(0, 1, 0), a=0.52)
	# the fringe from a part on the viewer's left, sweeping to the right, down past the eye's outer edge
	part = (-0.5, -0.66, 6.02)
	for i, (t, r) in enumerate((((-0.96, -0.94, 5.1), 0.26), ((-0.62, -1.0, 5.2), 0.2), ((-0.1, -1.02, 5.06), 0.25), ((0.26, -1.04, 4.76), 0.29), ((0.62, -1.04, 4.84), 0.32), ((0.98, -0.96, 4.5), 0.36))):
		gem(k, "Head", f"Fringe{i}", part, t, r, flat=0.42, bend=0.1, twist=0.15 + 0.1 * (i % 3), across=(1, 0, 0), a=0.54)
	gem(k, "Head", "Sweep", (0.1, -0.5, 6.14), (1.12, -0.7, 5.0), 0.42, flat=0.45, bend=0.14, twist=0.3, across=(0, 1, 0), a=0.56)
	gem(k, "Head", "TempleR", (0.78, -0.56, 5.8), (1.0, -0.86, 3.96), 0.28, flat=0.5, twist=0.2, across=(0.5, 1, 0), a=0.54)
	# the long side lock on the viewer's right, over the collar
	gem(k, "Head", "LockA", (0.84, -0.4, 5.8), (1.16, -0.86, 3.6), 0.34, flat=0.45, twist=0.2, across=(0, 1, 0), a=0.54)
	gem(k, "Head", "LockB", (0.88, -0.1, 5.8), (1.3, -0.26, 3.82), 0.36, flat=0.42, twist=0.3, across=(0, 1, 0), a=0.5)
	# two loose strands standing at the part
	gem(k, "Head", "AhogeA", (-0.3, -0.2, 6.1), (0.36, -0.5, 6.6), 0.12, flat=0.5, bend=0.3, a=0.58)
	gem(k, "Head", "AhogeB", (-0.2, 0.0, 6.1), (0.1, 0.5, 6.56), 0.12, flat=0.5, bend=0.3, a=0.58)


def _body(k):
	jacket(k, "navy", hem=1.94)
	prism(k, T, "ShirtV", [(-0.6, 4.0), (0.6, 4.0), (0, 3.2)], -0.62, -0.56, "shirt", a=0.6, b=0.3)
	shirt_collar(k)
	for s in (1, -1):
		prism(k, T, f"Lapel{s}", [(s * 0.56, 4.02), (s * 0.94, 3.98), (s * 0.94, 3.5), (s * 0.78, 3.46), (s * 0.02, 2.98), (s * 0.02, 3.16)], -0.67, -0.58, "navy", a=0.66, b=0.46)
		block(k, T, f"Pocket{s}", s * 0.66, -0.63, 2.5, 2.38, 0.24, 0.025, "navy", ch=0.015, a=0.3, b=0.4)
	for i, z in enumerate((2.86, 2.54, 2.22)):
		block(k, T, f"Button{i}", 0, -0.64, z + 0.07, z - 0.07, 0.07, 0.03, "black", ch=0.02, a=0.6)
	jacket_back(k, "navy", hem=1.96, y=0.62)
	bow(k, w=0.46)
	pleats(k, "navy", top=2.1, hem=0.98)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ear(k)
	_hair(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="navy", cuff=2.48)
		arm = f"{side}UpperArm"
		block(k, arm, "ShirtCuff", s * 1.5, 0, 2.52, 2.26, 0.525, 0.525, "shirt", ch=0.02, corner=0.18, a=0.58, b=0.34)
		for i, z in enumerate((2.44, 2.35)):
			block(k, arm, f"CuffLine{i}", s * 1.5, 0, z + 0.02, z - 0.02, 0.535, 0.535, "red", ch=0.008, corner=0.18, a=0.5, b=0.4)
		sock_leg(k, side, s, top=0.86)
	finish()


def _face(f):
	face(f, blush="#f48ca0")
	hairline(f, "#c4568c")
	for s, cx in ((-1, 37), (1, 93)):
		eye(f, cx, 66, s, ("#4a1030", "#9c2c62", "#e87cac"), w=37, up=17, dn=11, inner=4, outer=-4, ir=(12, 15), pu=(3.6, 5.4), lash="#2a0c1c", wing=6, thick=1.4, lid=0.22)
		brow2(f, cx, 43, s, 28, 2.8, 2.4, "#a84478", arc=-2)
	nose(f)
	# a small proud smile, higher on one side
	f.path("M55 106Q66 111 77 104Q67 114 55 106Z", "#d8606e")
	f.path("M54 106Q66 109 78 103", stroke="#7c2c3a", sw=1.4)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#c4568c", NAVY, NAVY, SKIN)
	scalp(a, "#c4568c")
