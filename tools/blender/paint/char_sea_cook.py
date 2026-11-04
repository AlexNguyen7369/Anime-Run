# Target look for sea_cook (design doc section 5): swept blond fringe hiding the viewer-left eye, one sharp blue eye under a
# spiral brow, goatee, black suit with lapels over a blue shirt and black tie, block hands, dress shoes.
import math

from atlas import INK, shade
from sea_style3 import bake, block, core, eye, gem, hand, head_base, head_sides, jitter, mirror, prism
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f9d4b0"
SKIN_D = "#dfa57c"
SKIN_L = "#ffe3c8"
GOLD = "#f4cf3e"
DEFAULT = "#14141c"
R = Ramps(
	hair=["#9a6c0a", "#cf9a12", "#eebf22", "#f8d646", "#ffec80"],
	skin=["#c88c64", "#ecb48a", "#f9d4b0", "#ffe3c8"],
	suit=["#07070c", "#13131c", "#22222e", "#37374a", "#50506a"],
	shirt=["#1d447e", "#2f66ac", "#4a84ca", "#74a8e2"],
	tie=["#040408", "#0e0e14", "#1c1c26", "#30303c"],
	shoe=["#050507", "#111116", "#26262e", "#4c4c58"],
	button=["#3a3a44", "#6a6a78", "#a0a0ae", "#d6d6e0"],
)
HAIR = {"colour": GOLD, "locks": []}
PROPS = []


def _hair(k):
	bake(k, k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.5, 0.5), (0.97, 5.8, 0.5), (0.64, 6.03, 0.5), (0.16, 6.12, 0.5)], "hair", n=10, at=(0, 0.05, 0), squash=0.93, outline=0), "hair", a=0.5, b=0.36)
	nape = k.tube("Head", "Nape", [(0, 0.42, 5.3, 0.95, 0.49), (0, 0.42, 4.74, 0.96, 0.5), (0, 0.42, 4.5, 0.82, 0.42)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.02)
	bake(k, nape, "hair", a=0.46, b=0.36)
	# the fringe sweeps from a parting on the viewer's right across and down over the viewer-left eye
	sweep = (
		((0.3, -0.72, 5.72), (-0.36, -0.95, 4.34), 0.42),
		((-0.14, -0.72, 5.7), (-0.74, -0.95, 4.2), 0.42),
		((-0.5, -0.72, 5.6), (-1.0, -0.9, 4.42), 0.34),
		((0.34, -0.72, 5.72), (-0.14, -0.95, 4.62), 0.3),
	)
	for i, (b, t, r) in enumerate(sweep):
		gem(k, "Head", f"Sweep{i}", b, t, r, flat=0.42, twist=0.15 + 0.12 * i, across=(1, 0.0, 0.25))
	# the short side of the parting, clear of the visible eye
	for i, (b, t, r) in enumerate((((0.46, -0.74, 5.74), (0.74, -0.96, 5.14), 0.27), ((0.74, -0.66, 5.62), (1.03, -0.84, 4.92), 0.25))):
		gem(k, "Head", f"Short{i}", b, t, r, flat=0.48, twist=0.3, across=(1, 0, -0.2))
	# big swept planes on top, the side locks and the jagged nape
	for i, (b, t, r) in enumerate((((0.3, -0.3, 5.74), (-0.96, -0.46, 5.96), 0.36), ((0.32, 0.1, 5.8), (-1.08, 0.14, 5.76), 0.38), ((0.46, -0.16, 5.74), (1.12, -0.28, 5.62), 0.32), ((0.3, 0.46, 5.7), (-0.94, 0.84, 5.5), 0.36), ((0.42, 0.42, 5.7), (1.08, 0.76, 5.52), 0.34))):
		gem(k, "Head", f"Top{i}", b, t, r, flat=0.55, twist=0.25 + 0.14 * i, bend=0.05)
	for s in (1, -1):
		for i, (y, z, r) in enumerate(((-0.34, 4.5, 0.27), (0.04, 4.3, 0.3), (0.42, 4.22, 0.3))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.93, y, 5.56), (s * 1.0, y + 0.05, z), r, flat=0.42, twist=0.2 + 0.2 * i, across=(0, 1, 0))
	for i, x in enumerate((-0.68, -0.34, 0.0, 0.34, 0.68)):
		gem(k, "Head", f"Hem{i}", (x, 0.74, 5.0), (x * 1.08, 0.94, 4.08 + 0.06 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0))
	# the goatee stands off the chin
	gem(k, "Head", "Goatee", (0, -0.78, 4.18), (0, -0.87, 3.98), 0.08, flat=0.6, twist=0.1, across=(1, 0, 0), a=0.36)


def _suit(k):
	t = "UpperTorso"
	block(k, t, "Jacket", 0, 0, 3.99, 1.74, 1.05, 0.56, "suit", ch=0.05, flare=0.02, jit=0.015, mids=(3.3, 2.5), a=0.36, b=0.46, g=0.1, tone=0.03)
	block(k, t, "CollarBack", 0, 0.34, 4.2, 3.92, 0.72, 0.2, "suit", ch=0.04, a=0.56, b=0.5)
	# the open V: blue shirt, its collar points, the black tie
	prism(k, t, "Shirt", [(-0.5, 3.99), (0.5, 3.99), (0.02, 2.62), (-0.02, 2.62)], -0.62, -0.5, "shirt", a=0.56, b=0.26)
	for s, pts in ((1, [(0.02, 3.99), (0.42, 4.0), (0.3, 3.68), (0.12, 3.76)]), (-1, mirror([(0.02, 3.99), (0.42, 4.0), (0.3, 3.68), (0.12, 3.76)]))):
		prism(k, t, f"ShirtCollar{s}", pts, -0.66, -0.58, "shirt", a=0.82, b=0.2)
	prism(k, t, "Tie", [(-0.08, 3.86), (0.08, 3.86), (0.05, 3.74), (0.13, 3.04), (0, 2.84), (-0.13, 3.04), (-0.05, 3.74)], -0.67, -0.6, "tie", a=0.62, b=0.34)
	block(k, t, "TieKnot", 0, -0.63, 3.96, 3.76, 0.11, 0.06, "tie", ch=0.02, a=0.75, b=0.3)
	# lapels: a broad peak each side of the V
	lapel = [(0.5, 3.99), (0.82, 3.99), (0.92, 3.5), (0.68, 3.46), (0.72, 3.2), (0.03, 2.58), (0.0, 2.56)]
	prism(k, t, "LapelL", lapel, -0.64, -0.55, "suit", a=0.56, b=0.42)
	prism(k, t, "LapelR", mirror(lapel), -0.64, -0.55, "suit", a=0.56, b=0.42)
	# front closing, two buttons, pocket flaps, the back vent
	prism(k, t, "Closing", [(-0.018, 2.6), (0.018, 2.6), (0.018, 1.76), (-0.018, 1.76)], -0.61, -0.55, "tie", a=0.2, b=0.1)
	for i, z in enumerate((2.42, 2.08)):
		k.blob(t, f"Button{i}", (-0.11, -0.585, z), (0.05, 0.03, 0.05), "button", v=0.55, rings=3, n=6, outline=0)
	for s in (1, -1):
		block(k, t, f"Pocket{s}", s * 0.56, -0.585, 2.32, 2.2, 0.29, 0.03, "suit", ch=0.012, a=0.72, b=0.42)
	block(k, t, "Breast", 0.56, -0.585, 3.14, 3.08, 0.2, 0.02, "suit", ch=0.01, a=0.2, b=0.1)
	prism(k, t, "Vent", [(-0.02, 2.5), (0.02, 2.5), (0.02, 1.76), (-0.02, 1.76)], 0.55, 0.61, "tie", a=0.18, b=0.1)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.04, 2.62, 0.515, 0.515, "suit", ch=0.1, corner=0.18, sub=1, jit=0.015, mids=(3.3,), a=0.36, b=0.46, g=0.1)
	block(k, arm, "Cuff", ax, 0, 2.66, 2.5, 0.505, 0.505, "shirt", ch=0.025, corner=0.18, a=0.72, b=0.3)
	hand(k, arm, ax)


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	px = s * 0.52
	block(k, leg, "Trousers", px, 0, 1.97, 0.34, 0.47, 0.5, "suit", ch=0.03, flare=0.03, corner=0.14, jit=0.012, mids=(1.1,), a=0.36, b=0.46, g=0.1, tone=0.02)
	prism(k, leg, "Crease", [(px - 0.02, 1.9), (px + 0.02, 1.9), (px + 0.025, 0.36), (px - 0.025, 0.36)], -0.54, -0.48, "suit", a=0.58, b=0.28)
	block(k, leg, "Shoe", px, -0.14, 0.42, 0.08, 0.49, 0.66, "shoe", ch=0.1, corner=0.3, sub=1, a=0.52, b=0.5)
	block(k, leg, "Heel", px, 0.26, 0.1, 0.0, 0.47, 0.25, "shoe", ch=0.015, a=0.3, b=0.2)
	block(k, leg, "Sole", px, -0.28, 0.09, 0.0, 0.5, 0.52, "shoe", ch=0.015, a=0.28, b=0.2)
	block(k, leg, "Lace", px, -0.5, 0.39, 0.3, 0.16, 0.1, "button", ch=0.015, a=0.1, b=0.1)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def _spiral(cx, cy, rx, ry, turns=1.9, n=28, a0=0.2):
	return "".join(f"{'M' if i == 0 else 'L'}{cx + rx * (0.12 + 0.88 * i / n) * math.cos(a0 + 2 * math.pi * turns * i / n):.2f} {cy + ry * (0.12 + 0.88 * i / n) * math.sin(a0 + 2 * math.pi * turns * i / n):.2f}" for i in range(n + 1))


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=26)
	# under the fringe: hair colour, so no gap shows skin where the viewer-left eye would be
	f.path("M-5-5H60L66 62L46 118L-5 124Z", "#cf9a12")
	eye(f, 97, 66, 1, "#2a7fe0", "#0e2c66", "#8fd0ff", w=30, up=20, down=11, inner=5, outer=-6, wing=4.0, lid=5, ry=12)
	# the spiral brow: curl at the nose side, tail running outwards and up
	brow = "#8a5f0a"
	f.path(_spiral(94, 34, 8.5, 10.5), stroke=brow, sw=2.8)
	f.path("M97 23.5Q112 20 127 27L126 33Q112 26 100 29Z", brow)
	# slim nose, a dry half smile, a short bar under the lip
	f.soft("M60 76L64 66L69 76Q64 81 60 76Z", SKIN_D, 0.7, 1)
	f.path("M60 79Q64 81 68 79", stroke=shade(SKIN, 0.5), sw=1.1)
	f.path("M48 100Q66 104 86 95", stroke=INK, sw=2.2)
	f.path("M86 95L89 92", stroke=INK, sw=1.8)
	f.path("M54 108Q66 112 78 106", stroke=shade(SKIN, 0.62), sw=1.3)
	f.path("M57 120Q66 114 75 120L71 135H61Z", "#cf9a12")
	head_sides(a, SKIN, SKIN_D)
	# hair down the sides of the head: a jagged edge in front of where the ear would be
	a["Head_L"].path("M28-5L34 44L22 58L36 72L26 96L44 90L62 112L84 92L125 118V-5Z", "#cf9a12")
	a["Head_R"].path("M92-5L86 44L98 58L84 72L94 96L76 90L58 112L36 92L-5 118V-5Z", "#cf9a12")
	for n in ("Head_B", "Head_T"):
		a[n].fill("#cf9a12")
