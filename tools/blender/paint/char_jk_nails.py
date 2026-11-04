# Target look for jk_nails (design doc section 5): an orange chin-length bob in big planes with parted bangs, amber eyes, a closed
# dark high-collar jacket with gold pinwheel buttons, brown belt, knee-length pleated skirt over black tights, brown loafers, a claw
# hammer hanging from one hand and long nails held in the other, a small straw doll at the belt. Drawn in-house.
import math

from atlas import shade
from jk_common import brow2, eye2
from jk_style3 import GOLD, NAVY, SOLE, Kit, bake, big_head, block, button, collar, crown, dress_shoe, face_base, finish, gem, head_rest, jacket, sleeve, slab, stroke, swirl_art
from style2 import Ramps

SKIN = "#f6dacb"
SKIN_D = "#d4ac98"
DEFAULT = "#1e2233"
R = Ramps(
	hair=["#8c3f18", "#bc5e28", "#d9773a", "#ef9456", "#fab27a"],
	skin=["#b68e78", "#e4bca6", "#f6dacb", "#ffeade"],
	navy=NAVY,
	tights=["#050506", "#0e0e10", "#1c1c20", "#2e2e34"],
	belt=["#351d0e", "#5a3419", "#7a4a26", "#9c683a"],
	shoe=["#2c1a10", "#4a2e1c", "#6a452c", "#8a6040"],
	sole=SOLE,
	gold=GOLD,
	wood=["#50321a", "#7a5026", "#9c6c38", "#bc8c52"],
	steel=["#4a4f58", "#7c858f", "#aeb6c0", "#e4e8ee"],
	straw=["#7a5e2c", "#a88a4a", "#c9a86a", "#e6cc92"],
)
HAIR = {"colour": "#D9773A", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.5), (1.06, 5.62), (0.96, 5.86), (0.54, 6.14), (0.14, 6.2)])
	block(k, "Head", "Cap", 0, 0.02, 5.78, 5.34, 1.07, 0.9, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.48, b=0.44)
	# the bob: one mass round the back, flat curtains down each cheek, a clean jagged hem at the chin
	block(k, "Head", "Back", 0, 0.28, 5.46, 4.18, 1.05, 0.68, "hair", ch=0.06, flare=0.05, corner=0.3, jit=0.03, sub=1, mids=(5.0, 4.6), a=0.46, b=0.42, tone=0.03)
	for s in (1, -1):
		# the sides are one with the back: a slab from the temple to the chin, its front edge running down the cheek
		slab(k, f"Side{s}", [(-0.84, 5.42), (-0.84, 4.9), (-0.74, 4.34), (-0.62, 4.14), (0.3, 4.14), (0.3, 5.42)], s * 0.86, s * 1.07, "hair", a=0.5, b=0.46)
		# big locks lying over it, down to a jagged hem at the jaw
		for i, (y, z0, r) in enumerate(((-0.62, 4.02, 0.26), (-0.26, 3.98, 0.3), (0.1, 4.02, 0.3))):
			gem(k, "Head", f"Lock{s}{i}", (s * 1.02, y + 0.02, 5.46), (s * 1.09, y - 0.02, z0), r, flat=0.32, twist=0.2 + 0.2 * i, across=(0, 1, 0), a=0.52)
		gem(k, "Head", f"Temple{s}", (s * 0.8, -0.86, 5.46), (s * 0.84, -0.96, 4.8), 0.18, flat=0.5, twist=0.25, across=(1, 0, 0), a=0.56)
		gem(k, "Head", f"Chin{s}", (s * 0.9, -0.74, 4.8), (s * 0.82, -0.88, 4.1), 0.17, flat=0.6, twist=0.3, across=(1, 0, 0), a=0.56)
	for i, x in enumerate((-0.84, -0.5, -0.17, 0.17, 0.5, 0.84)):
		gem(k, "Head", f"Hem{i}", (x, 0.92, 5.56), (x * 1.04, 1.03, 3.98 + 0.08 * (i % 2)), 0.27, flat=0.32, twist=0.3, across=(1, 0, 0), a=0.48)
	# parted bangs: a slight side part, the long side sweeping down the temple, the short side across
	part = (0.2, -0.9, 5.66)
	for i, (t, r) in enumerate((((-0.86, -0.94, 4.98), 0.34), ((-0.42, -0.95, 5.3), 0.3), ((0.84, -0.94, 5.04), 0.3), ((0.54, -0.95, 5.36), 0.24))):
		gem(k, "Head", f"Bang{i}", part, t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.56, across=(0, 0, 1))
	# a few big clumps over the crown so the top breaks into planes
	for i, (b, t, r) in enumerate((((-0.1, 0.1, 5.86), (-1.1, -0.1, 5.42), 0.3), ((0.1, 0.1, 5.86), (1.1, -0.1, 5.42), 0.3), ((0, 0.2, 5.86), (0, 1.02, 5.3), 0.34), ((-0.3, 0.1, 5.84), (-0.9, 0.9, 5.34), 0.3), ((0.3, 0.1, 5.84), (0.9, 0.9, 5.34), 0.3))):
		gem(k, "Head", f"Clump{i}", b, t, r, flat=0.5, twist=0.3, a=0.5)


def _skirt(k):
	"""Closed pleated solid hung from the belt, ending above the knee: a zigzag ring going round a rounded rectangle."""
	n = 40
	rows = ((2.42, 1.02, 0.54, 0.0), (2.32, 1.06, 0.58, 0.02), (1.8, 1.14, 0.66, 0.075), (1.26, 1.2, 0.72, 0.1), (1.2, 1.15, 0.67, 0.07))
	rings = []
	for z, hw, hd, amp in rows:
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, s = math.cos(a), math.sin(a)
			p = 1 + (amp if j % 2 else -amp)
			ring.append((hw * p * math.copysign(abs(c) ** 0.45, c), hd * p * math.copysign(abs(s) ** 0.45, s), z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Skirt", "UpperTorso", verts, faces, flat, outline=0), "navy", k, a=0.5, b=0.68, g=0.14)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.52
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Tights", px, 0, 1.97, 0.3, 0.48, 0.5, "tights", ch=0.04, corner=0.14, mids=(1.1,), a=0.56, b=0.5)
	dress_shoe(k, leg, px, top=0.34)
	block(k, leg, "Strap", px, -0.47, 0.34, 0.27, 0.47, 0.27, "belt", ch=0.02, corner=0.3, a=0.46)


def _hammer(k):
	"""A claw hammer hanging straight down from the viewer's left hand, close to the leg."""
	arm = "RightUpperArm"
	block(k, arm, "Shaft", -1.5, -0.1, 2.2, 0.86, 0.06, 0.07, "wood", ch=0.015, corner=0.3, a=0.56)
	block(k, arm, "HammerHead", -1.5, -0.14, 1.04, 0.72, 0.16, 0.32, "steel", ch=0.03, corner=0.3, a=0.56)
	block(k, arm, "Face", -1.5, -0.5, 1.0, 0.76, 0.18, 0.06, "steel", ch=0.02, corner=0.3, a=0.7)
	gem(k, arm, "Claw", (-1.5, 0.14, 0.94), (-1.5, 0.56, 0.68), 0.14, "steel", flat=0.7, a=0.56)


def _nails(k):
	"""Long nails held in the viewer's right hand, points down."""
	arm = "LeftUpperArm"
	for i, x in enumerate((1.32, 1.5, 1.68)):
		block(k, arm, f"Nail{i}", x, -0.54, 2.08, 1.36, 0.022, 0.022, "steel", ch=0.004, corner=0.3, a=0.62)
		gem(k, arm, f"Point{i}", (x, -0.54, 1.38), (x, -0.54, 1.22), 0.024, "steel", flat=1.0, a=0.6)
		block(k, arm, f"NailHead{i}", x, -0.54, 2.12, 2.07, 0.05, 0.05, "steel", ch=0.01, corner=0.3, a=0.8)


def _doll(k):
	"""The small straw doll tied at the belt, on the front of the skirt."""
	t = "UpperTorso"
	x, y = 0.66, -0.74
	block(k, t, "DollHead", x, y, 2.3, 2.1, 0.11, 0.08, "straw", ch=0.03, corner=0.4, a=0.64)
	block(k, t, "DollBody", x, y, 2.12, 1.9, 0.09, 0.06, "straw", ch=0.02, corner=0.4, a=0.56)
	block(k, t, "DollArms", x, y, 2.06, 1.99, 0.16, 0.04, "straw", ch=0.012, corner=0.4, a=0.6)
	for i, dx in enumerate((-0.05, 0.05)):
		block(k, t, f"DollLeg{i}", x + dx, y, 1.92, 1.76, 0.04, 0.04, "straw", ch=0.01, corner=0.4, a=0.56)
	block(k, t, "DollCord", x, y + 0.08, 2.46, 2.3, 0.012, 0.012, "belt", ch=0.003, a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	jacket(k, hem=2.38)
	collar(k, "navy", 4.14, 4.32, z0=3.84, rx=0.9, ry=0.87, a=0.56)
	t = "UpperTorso"
	_skirt(k)
	block(k, t, "Belt", 0, 0, 2.54, 2.32, 1.125, 0.625, "belt", ch=0.03, a=0.48)
	block(k, t, "Buckle", 0, -0.635, 2.56, 2.3, 0.13, 0.02, "gold", ch=0.015, a=0.66)
	for i, z in enumerate((3.72, 3.3, 2.88)):
		button(k, t, f"Button{i}", 0, -0.6, z, r=0.11)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s)
		_leg(k, side, s)
	_hammer(k)
	_nails(k)
	_doll(k)
	finish()


def paint(a):
	R.paint(a)
	swirl_art(a, "#d9773a")
	f = a["Head_F"]
	face_base(f, SKIN, SKIN_D, blush="#f4a088", top=20)
	# large sharp amber eyes with a heavy lash and a flick, thin high arched brows, a sure closed smile
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 60, s, 36, 19, "#a8622e", tilt=2.4, r=12, lash_t=4.6, flick=5.5, sclera="#fffdf8", crease_line=False)
		brow2(f, x, 34, s, 34, 3.4, 2.6, "#8a4a26", arc=-2.6)
	f.soft("M61 82L65 77L69 82Q65 86 61 82Z", SKIN_D, 0.65, 1)
	stroke(f, "M50 96Q66 103 84 94", "#7a3030", 2)
	stroke(f, "M84 94Q86 93 87 90", "#7a3030", 1.5)
	f.soft("M58 104Q66 107 74 104Q66 109 58 104Z", "#e88c80", 0.6, 1)
	head_rest(a, shade(SKIN, 0.78), shade(SKIN, 0.6))
