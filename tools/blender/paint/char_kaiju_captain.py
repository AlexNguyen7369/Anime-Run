# Target look for kaiju_captain "Mena Ashiru" (design doc section 5): long black hair in one high tail, a pointed fringe, long side locks with a
# pale three-cornered clip at each temple, level red-brown eyes, the corps' combat suit, a giant cannon at the hip. +X is the viewer's
# right. Drawn in-house.
from ds_style3 import eye
from kaiju_style3 import BLACK, SUIT, Kit, Ramps, big_head, block, brow2, crown, ears, finish, gem, prism, rblock, skin_face, suit, suit_paint, hair_back, top_layers

SKIN, SKIN_D = "#f8dac2", "#d4a488"
DEFAULT = BLACK
R = Ramps(
	hair=["#08090e", "#12151e", "#1e222e", "#323846", "#5c6474"],
	skin=["#c8987c", "#e8bca0", SKIN, "#ffeadb"],
	**SUIT,
)
HAIR = {"colour": "#1C1E29", "locks": []}
PROPS = []


def _hair(k):
	hair_back(k)
	top_layers(k, (-0.8, -0.4, 0.0, 0.4, 0.8))
	crown(k, [(0.96, 5.2), (1.06, 5.46), (1.02, 5.8), (0.66, 6.06), (0.2, 6.14)], at=(0, 0.0, 0))
	block(k, "Head", "Back", 0, 0.32, 5.5, 4.5, 0.98, 0.6, "hair", ch=0.08, corner=0.3, sub=1, jit=0.02, a=0.42, b=0.46)
	for i, (bx, tx, z, r) in enumerate(((-0.1, -0.1, 4.84, 0.24), (0.18, 0.22, 4.98, 0.22), (-0.38, -0.42, 4.98, 0.25), (0.46, 0.5, 4.9, 0.25), (-0.66, -0.7, 4.9, 0.24), (0.7, 0.76, 5.0, 0.22))):
		gem(k, "Head", f"Fringe{i}", (bx * 0.95, -0.8, 5.7), (tx, -0.97, z), r, flat=0.42, twist=0.15 + 0.1 * i, across=(1, 0, 0), a=0.52)
	for s in (1, -1):
		# the long side lock, flat to the cheek, down to the chest
		gem(k, "Head", f"Lock{s}", (s * 0.84, -0.6, 5.6), (s * 0.92, -0.86, 3.56), 0.25, flat=0.45, twist=0.15, across=(1, 0, 0), a=0.5)
		gem(k, "Head", f"LockB{s}", (s * 0.94, -0.4, 5.5), (s * 1.08, -0.6, 3.9), 0.24, flat=0.45, twist=0.25, across=(0, 1, 0), a=0.46)
		# the pale clip at the temple, a small three-cornered plate with a dark dot
		prism(k, "Head", f"Clip{s}", [(s * 0.66, 5.36), (s * 1.0, 5.28), (s * 0.82, 5.02)], -1.05, -0.96, "plate", a=0.7, b=0.2)
		prism(k, "Head", f"ClipDot{s}", [(s * 0.79, 5.26), (s * 0.87, 5.24), (s * 0.83, 5.16)], -1.07, -1.04, "line", a=0.4, b=0.1)
		gem(k, "Head", f"Pull{s}", (s * 0.62, -0.4, 5.66), (s * 0.1, 0.62, 6.16), 0.42, flat=0.4, twist=0.2, a=0.52)
		gem(k, "Head", f"PullB{s}", (s * 0.8, 0.3, 5.1), (s * 0.1, 0.7, 6.1), 0.44, flat=0.4, twist=0.2, a=0.46)
	# the high tail: gathered by the tie at the crown, arching up and falling straight down the back
	block(k, "Head", "Tie", 0, 0.42, 6.34, 6.06, 0.28, 0.28, "steel", ch=0.04, corner=0.3, a=0.5, b=0.4)
	gem(k, "Head", "Rise", (0, 0.36, 6.2), (0, 0.98, 6.94), 0.36, flat=0.8, twist=0.3, a=0.56)
	for i, (bx, tx, ty, tz, r, bend) in enumerate(((0.0, 0.0, 1.5, 3.72, 0.5, 0.2), (-0.16, -0.36, 1.4, 4.0, 0.4, 0.22), (0.16, 0.34, 1.42, 4.06, 0.4, 0.22), (-0.06, -0.14, 1.62, 4.5, 0.36, 0.26), (0.1, 0.16, 1.6, 4.6, 0.34, 0.26))):
		gem(k, "Head", f"Tail{i}", (bx, 0.5, 6.42), (tx, ty, tz), r, flat=0.7, bend=bend, twist=0.2 + 0.15 * i, across=(1, 0, 0), a=0.48 + 0.04 * (i % 3))


def _cannon(k):
	"""A huge long gun at the hip in the viewer's left hand, muzzle forward and out. Built pointing down, swung from the fist."""
	arm, x, y = "RightUpperArm", -1.5, -0.3
	turn = ((x, y, 2.1), -60, 0, -26)
	rblock(k, arm, "Breech", x, y, 3.1, 1.66, 0.44, 0.48, "gun", ch=0.12, rot=turn, a=0.54, b=0.52)
	rblock(k, arm, "BreechPlate", x, y - 0.06, 2.86, 2.04, 0.5, 0.48, "plate", ch=0.06, rot=turn, a=0.5, b=0.44)
	rblock(k, arm, "Grip", x, y, 2.0, 1.72, 0.5, 0.52, "green", ch=0.05, rot=turn, a=0.56, b=0.46)
	rblock(k, arm, "Frame", x, y, 1.78, 0.5, 0.38, 0.42, "gun", ch=0.06, rot=turn, a=0.56, b=0.52)
	for d in (1, -1):
		rblock(k, arm, f"Rail{d}", x + d * 0.4, y, 1.7, -0.56, 0.09, 0.28, "plate", ch=0.04, rot=turn, a=0.5, b=0.44)
		rblock(k, arm, f"RailEnd{d}", x + d * 0.42, y, -0.3, -0.62, 0.11, 0.32, "green", ch=0.04, rot=turn, a=0.54, b=0.44)
	for i, z in enumerate((1.4, 1.1, 0.8)):
		rblock(k, arm, f"Vent{i}", x, y - 0.44, z, z - 0.16, 0.26, 0.05, "line", ch=0.02, rot=turn, a=0.5, b=0.3)
	rblock(k, arm, "Scope", x, y - 0.6, 2.4, 1.6, 0.14, 0.14, "gun", ch=0.04, corner=0.4, rot=turn, a=0.6, b=0.5)
	rblock(k, arm, "Barrel", x, y, 0.6, -0.9, 0.26, 0.28, "gun", ch=0.04, corner=0.4, rot=turn, a=0.58, b=0.5)
	rblock(k, arm, "Brake", x, y, -0.8, -1.2, 0.36, 0.36, "steel", ch=0.06, corner=0.3, rot=turn, a=0.5, b=0.48)
	rblock(k, arm, "Bore", x, y, -1.18, -1.24, 0.2, 0.2, "line", ch=0.02, corner=0.4, rot=turn, a=0.4, b=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.6)
	_hair(k)
	suit(k)
	_cannon(k)
	finish()


def paint(a):
	R.paint(a)
	suit_paint(a, SKIN, "#1c2434")
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, 0.14)
	for s, cx in ((-1, 36), (1, 94)):
		eye(f, cx, 66, s, ("#4a0f0c", "#b0402c", "#f09068"), w=37, up=13, dn=11, inner=4, outer=-4, ir=(11, 13.5), pu=(3.2, 4.8), lash="#120c10", wing=6, thick=1.3, lid=0.26)
		brow2(f, cx, 46, s, 30, 2.6, 2.2, "#16161e", arc=-1.0)
	f.path("M57 107Q65 105 74 107", stroke="#8a4440", sw=1.6)
