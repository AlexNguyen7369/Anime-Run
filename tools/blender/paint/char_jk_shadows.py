# Target look for jk_shadows (design doc section 5): a big black urchin of spikes with a blue sheen, messy fringe, narrow calm
# teal eyes, plain dark high-collar uniform with gold pinwheel buttons, dark shoes. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2
from jk_style3 import GOLD, NAVY, SOLE, Kit, big_head, block, button, collar, crown, dress_shoe, face_base, finish, gem, head_rest, jacket, sleeve, spray, stroke, swirl_art, trouser
from style2 import Ramps

SKIN = "#f2d8c8"
SKIN_D = "#cfa892"
DEFAULT = "#1a1e2e"
R = Ramps(
	hair=["#030408", "#0a0c12", "#141722", "#1f2638", "#333f66"],
	skin=["#b48c74", "#e0b8a2", "#f2d8c8", "#ffe8dc"],
	navy=NAVY,
	shoe=["#08080c", "#14151c", "#23242e", "#363846"],
	sole=SOLE,
	gold=GOLD,
)
HAIR = {"colour": "#15171F", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.96, 5.2), (1.04, 5.46), (0.96, 5.84), (0.54, 6.14), (0.14, 6.22)])
	block(k, "Head", "Cap", 0, 0, 5.68, 5.24, 0.965, 0.88, "hair", ch=0.08, corner=0.3, jit=0.015, sub=1, a=0.46, b=0.4)
	root = (0, 0.06, 5.42)
	# the urchin: long spikes going out in every direction, top ring, then lower rings, then behind
	spray(k, "Top", root, (((-0.5, -0.04, 6.86), 0.42), ((0.12, 0.1, 7.02), 0.44), ((0.66, 0.0, 6.82), 0.42), ((-0.16, 0.56, 6.82), 0.42), ((0.44, 0.6, 6.72), 0.4)), f=0.3)
	spray(k, "Upper", root, (((-1.14, 0.0, 6.42), 0.42), ((-0.82, -0.42, 6.56), 0.42), ((-0.2, -0.58, 6.62), 0.42), ((0.4, -0.58, 6.6), 0.42), ((0.96, -0.42, 6.5), 0.42), ((1.26, 0.04, 6.34), 0.42), ((-0.86, 0.62, 6.42), 0.42), ((0.9, 0.62, 6.38), 0.42), ((0.04, 1.12, 6.48), 0.44)), f=0.25)
	spray(k, "Mid", root, (((-1.5, -0.08, 5.84), 0.38), ((-1.32, -0.42, 5.46), 0.34), ((1.52, -0.04, 5.88), 0.38), ((1.34, -0.42, 5.42), 0.34), ((-1.28, 0.56, 5.88), 0.4), ((1.3, 0.56, 5.86), 0.4), ((-0.66, 1.22, 6.0), 0.42), ((0.7, 1.22, 5.98), 0.42), ((0.0, 1.44, 5.8), 0.44), ((-1.1, 0.96, 5.5), 0.38), ((1.12, 0.96, 5.46), 0.38)), f=0.25)
	spray(k, "Low", root, (((-1.32, 0.34, 5.02), 0.32), ((1.32, 0.34, 4.98), 0.32), ((-0.82, 1.14, 5.04), 0.36), ((0.84, 1.14, 5.02), 0.36), ((-0.32, 1.26, 4.98), 0.38), ((0.34, 1.26, 4.96), 0.38)), f=0.3)
	block(k, "Head", "Nape", 0, 0.4, 5.3, 4.36, 0.95, 0.5, "hair", ch=0.06, corner=0.22, jit=0.02, a=0.46, b=0.36)
	for i, x in enumerate((-0.66, -0.33, 0.0, 0.33, 0.66)):
		gem(k, "Head", f"NapeTip{i}", (x, 0.66, 4.86), (x * 1.1, 0.92, 4.2 + 0.07 * (i % 2)), 0.28, flat=0.5, twist=0.3, across=(1, 0, 0))
	# side locks down past the ears
	for s in (1, -1):
		for i, (y, z0, r) in enumerate(((-0.46, 4.56, 0.24), (-0.14, 4.46, 0.26), (0.16, 4.46, 0.26))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.86, y, 5.2), (s * 0.97, y - 0.02, z0), r, flat=0.45, twist=0.25 + 0.2 * i, across=(0, 1, 0))
	# messy fringe: uneven wedges falling across the forehead, one past the brow
	for i, (bx, tx, tz, r) in enumerate(((-0.7, -0.84, 5.0, 0.24), (-0.38, -0.46, 4.98, 0.25), (-0.06, -0.14, 4.92, 0.25), (0.24, 0.3, 5.06, 0.24), (0.56, 0.66, 4.98, 0.24), (0.8, 0.88, 5.1, 0.2))):
		gem(k, "Head", f"Fringe{i}", (bx, -0.56, 5.66), (tx, -0.93, tz), r, flat=0.5, twist=0.2 + 0.25 * i % 0.6, across=(1, 0, 0), a=0.52)
	for i, (x, z, r) in enumerate(((-0.56, 6.14, 0.3), (-0.12, 6.28, 0.32), (0.34, 6.2, 0.32), (0.76, 6.06, 0.3))):
		gem(k, "Head", f"Front{i}", (x * 0.8, -0.56, 5.46), (x, -1.0, z), r, flat=0.6, twist=0.35)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	jacket(k)
	collar(k, "navy", 4.18, 4.36, z0=3.84, rx=0.9, ry=0.87, a=0.56)
	for i, z in enumerate((3.7, 3.28, 2.86, 2.44)):
		button(k, "UpperTorso", f"Button{i}", 0, -0.6, z, r=0.12)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s)
		leg, px = trouser(k, side, s, low=0.46)
		dress_shoe(k, leg, px)
	finish()


def paint(a):
	R.paint(a)
	swirl_art(a, "#15171f")
	f = a["Head_F"]
	face_base(f, SKIN, SKIN_D, top=36)
	# narrow, half-lidded, cool eyes under low straight brows
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 62, s, 35, 12.5, "#2a6a78", tilt=3, r=8.8, lid=0.34, lash_t=3.4, flick=4, sclera="#fbf9f6", crease_line=False)
		brow2(f, x, 44, s, 34, 4.2, 3.2, "#14161e", arc=-0.4)
	f.soft("M60 80L65 74L70 80Q65 86 60 80Z", SKIN_D, 0.7, 1)
	stroke(f, "M61 84Q65 85.5 69 84", shade(SKIN, 0.5), 1.1)
	# a small flat unimpressed mouth
	stroke(f, "M55 99Q65 101 75 98", "#6a3a34", 2)
	f.soft("M58 104Q65 106 72 104Q65 108 58 104Z", SKIN_D, 0.5, 1)
	head_rest(a, shade(SKIN, 0.78), shade(SKIN, 0.6))
