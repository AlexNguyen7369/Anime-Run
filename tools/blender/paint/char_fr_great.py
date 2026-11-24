# Target look for fr_great "Serye" (design doc section 5): floor-length golden hair with a full fringe and gold-tied side locks, long elf ears with gold earrings, stern golden
# eyes; a white gown and flowing white mantle with gold bands, gold pendant chain, bangles and anklets, bare feet. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, cape, collar, elf_ears, face, fill_body, finish, gem, helmet, jacket, locks, mane, prism, rod, skirt, wrap

SKIN = "#fde4d2"
SKIN_D = "#dcb098"
DEFAULT = "#ece8e0"
R = Ramps(
	hair=["#a8782a", "#cc9c42", "#eac468", "#f8de92", "#fff4c8"],
	skin=["#c8a088", "#e8c8b2", "#fde4d2", "#fff2e8"],
	white=["#a49c94", "#cac4bc", "#e8e4de", "#f8f6f2", "#ffffff"],
	gold=["#8a5a08", "#c48c1c", "#eab83a", "#ffe890"],
	lining=["#7c5a2c", "#a88444", "#d0ae6a", "#f0d69a"],
	green=["#0c4a38", "#187454", "#2ca878", "#88e8bc"],
)
HAIR = {"colour": "#EAC468", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.2)
	mane(k, 0.4, mid=1.28, end=1.16, y=1.0, n=7)
	for s in (1, -1):
		# the mass spreads past the body on both sides to the ankles
		for i, (b, t, r) in enumerate((((0.9, 0.6, 5.4), (1.52, 1.02, 2.6), 0.42), ((1.1, 0.8, 4.0), (1.76, 1.16, 0.5), 0.46), ((0.9, 0.88, 3.2), (1.2, 1.3, 0.3), 0.46))):
			gem(k, "Head", f"Veil{s}{i}", (s * b[0], b[1], b[2]), (s * t[0], t[1], t[2]), r, flat=0.45, twist=0.2, a=0.46 + 0.07 * (i % 2), across=(1, 0, 0))
		gem(k, "Head", f"Top{s}", (0, 0.0, 5.84), (s * 1.1, 0.0, 5.3), 0.44, flat=0.45, bend=0.12, a=0.54)
		gem(k, "Head", f"TopB{s}", (0, 0.1, 5.84), (s * 0.8, 0.9, 5.1), 0.46, flat=0.45, bend=0.12, a=0.5)
		# side locks tied with gold, hanging in front of the shoulders
		gem(k, "Head", f"Lock{s}", (s * 0.94, -0.6, 5.5), (s * 0.98, -0.9, 2.6), 0.3, flat=0.5, twist=0.1, a=0.54, across=(1, 0, 0))
		gem(k, "Head", f"Lock2{s}", (s * 1.08, -0.3, 5.3), (s * 1.24, -0.6, 4.0), 0.3, flat=0.45, twist=0.15, a=0.46, across=(0, 1, 0))
		block(k, "Head", f"LockTie{s}", s * 0.96, -0.76, 4.12, 3.9, 0.27, 0.17, "gold", ch=0.03, a=0.58, b=0.42)
	locks(k, "Bang", None, (((-0.64, -0.72, 5.92), (-1.0, -0.94, 4.84), 0.29), ((-0.42, -0.74, 5.96), (-0.64, -1.02, 4.96), 0.28), ((-0.16, -0.76, 5.98), (-0.26, -1.06, 5.0), 0.27), ((0.04, -0.76, 5.98), (0.06, -1.07, 4.82), 0.26), ((0.2, -0.76, 5.98), (0.36, -1.05, 5.0), 0.27), ((0.44, -0.74, 5.96), (0.7, -1.02, 4.96), 0.28), ((0.66, -0.72, 5.92), (1.02, -0.94, 4.84), 0.29)))


def _body(k):
	jacket(k, "white", seam=None)
	# the open neckline with its gold chain and green drop
	prism(k, T, "Skin", [(-0.62, 4.06), (0.62, 4.06), (0.46, 3.72), (-0.46, 3.72)], -0.64, -0.5, "skin", a=0.62, b=0.32)
	collar(k, "skin", 4.06, 4.1, z0=3.9, rx=0.6, ry=0.54, name="Neck")
	prism(k, T, "Neckline", [(-0.72, 4.06), (-0.6, 4.06), (-0.44, 3.72), (0.44, 3.72), (0.6, 4.06), (0.72, 4.06), (0.52, 3.6), (-0.52, 3.6)], -0.67, -0.6, "gold", a=0.56, b=0.42)
	rod(k, T, "Chain", [(-0.5, -0.68, 4.06), (-0.26, -0.71, 3.8), (0, -0.72, 3.7), (0.26, -0.71, 3.8), (0.5, -0.68, 4.06)], 0.035, "gold", n=4, a=0.6, b=0.4)
	prism(k, T, "Drop", [(0, 3.74), (0.11, 3.56), (0, 3.3), (-0.11, 3.56)], -0.75, -0.66, "green", a=0.6, b=0.4)
	block(k, T, "Waist", 0, 0, 2.56, 2.3, 1.1, 0.62, "gold", ch=0.03, sub=1, a=0.56, b=0.42)
	prism(k, T, "Sash", [(-0.16, 2.34), (0.16, 2.34), (0.2, 2.04), (-0.2, 2.04)], -0.7, -0.6, "gold", a=0.54, b=0.42)
	skirt(k, "white", 0.62, "gold", flare=0.16)
	for s, side in ((1, "Left"), (-1, "Right")):
		block(k, f"{side}UpperLeg", "SashL", s * 0.1, -0.74, 2.02, 1.0, 0.1, 0.04, "gold", ch=0.01, flare=0.03, a=0.54, b=0.42)
	# the mantle: white over the shoulders, gold edge, flowing behind
	wrap(k, T, "Mantle", [(4.2, 0.88, 0.66, 0.66), (4.04, 1.14, 0.76, 0.72), (3.36, 1.2, 0.86, 0.9)], "white", t=0.07, a=0.54, b=0.44, g=0.1)
	cape(k, "white", "lining", 0.3, "gold", w=0.8)


def _arm(k, side, s):
	arm, x = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(x, 0, 3.9, 0.42, 0.42), (x, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Mantle", s * 1.58, 0.04, 4.14, 3.3, 0.6, 0.7, "white", ch=0.1, flare=0.08, corner=0.3, a=0.54, b=0.44)
	block(k, arm, "MantleTrim", s * 1.58, 0.04, 3.42, 3.26, 0.7, 0.8, "gold", ch=0.02, corner=0.3, a=0.56, b=0.42)
	block(k, arm, "Arm", x, 0, 3.4, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)
	for i, z in enumerate((2.66, 2.42)):
		block(k, arm, f"Bangle{i}", x, 0, z + 0.07, z - 0.07, 0.56, 0.56, "gold", ch=0.03, corner=0.2, a=0.58, b=0.42)


def _leg(k, side, s):
	leg, px = f"{side}UpperLeg", s * 0.52
	k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.46, 0.46), (s * 0.5, 0, 0.1, 0.46, 0.46)], corner=0.1, nc=1)
	block(k, leg, "Ankle", px, 0.04, 0.8, 0.0, 0.48, 0.48, "skin", ch=0.05, a=0.6, b=0.32)
	block(k, leg, "Foot", px, -0.34, 0.34, 0.0, 0.47, 0.4, "skin", ch=0.08, corner=0.24, a=0.6, b=0.32)
	block(k, leg, "Anklet", px, 0.04, 0.5, 0.38, 0.53, 0.53, "gold", ch=0.03, a=0.58, b=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	elf_ears(k, out=1.8, up=5.14)
	for s in (1, -1):
		rod(k, "Head", f"Earring{s}", [(s * 1.2, -0.1, 4.66), (s * 1.2, -0.12, 4.52), (s * 1.2, -0.12, 4.38), (s * 1.2, -0.1, 4.22)], [0.03, 0.1, 0.1, 0.03], "gold", n=5, a=0.58, b=0.42)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, SKIN_D, ("#8a5608", "#e0a424", "#fff08c"), "#4c3010", "#a87c30", "M56 106Q65 103 74 106", w=35, up=11, dn=9, inner=4, outer=-4.5, ir=(10.5, 12), lid=0.32, thick=1.5, wing=5.5, brow_y=46, brow_t=4.0, tilt=3.0, blush=0.12)
	fill_body(a, SKIN, SKIN_D, "#e8e4de", "#f4d8c4", "#f0d4c0", "#cc9c42")
