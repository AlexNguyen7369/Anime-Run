# Target look for kaiju_axe "Kikuru" (design doc section 5): yellow twin tails high on the head in big black ribbons, a parted fringe with
# one zigzag lock and two long thin strands by the cheeks, sharp green eyes and a proud smile, the corps' combat suit, a huge slab axe.
# +X is the viewer's right. Drawn in-house.
from ds_style3 import eye, xf
from kaiju_style3 import BLACK, SUIT, Kit, Ramps, big_head, block, brow2, crown, ears, finish, gem, prism, rblock, skin_face, suit, suit_paint, top_layers

SKIN, SKIN_D = "#fbdcc2", "#d8a88a"
DEFAULT = BLACK
R = Ramps(
	hair=["#a8780e", "#d8ab22", "#f4d040", "#fde57a", "#fff6c0"],
	skin=["#c8987c", "#e8bca0", SKIN, "#ffeadb"],
	**SUIT,
)
HAIR = {"colour": "#F4D040", "locks": []}
PROPS = []


def _hair(k):
	top_layers(k, (-0.8, -0.4, 0.0, 0.4, 0.8))
	crown(k, [(0.96, 5.2), (1.06, 5.46), (1.02, 5.8), (0.68, 6.1), (0.2, 6.2)], at=(0, 0.0, 0))
	block(k, "Head", "Back", 0, 0.34, 5.5, 4.5, 0.98, 0.58, "hair", ch=0.08, corner=0.3, sub=1, jit=0.02, a=0.44, b=0.42)
	# the fringe: parted in the middle, a heavy centre pair and a zigzag lock at each temple
	for i, (bx, tx, z, r) in enumerate(((-0.2, -0.16, 4.82, 0.24), (0.16, 0.2, 4.94, 0.24), (-0.44, -0.46, 5.02, 0.26), (0.46, 0.5, 5.0, 0.26), (-0.72, -0.78, 5.1, 0.24), (0.74, 0.8, 5.08, 0.24))):
		gem(k, "Head", f"Fringe{i}", (bx * 0.95, -0.8, 5.7), (tx, -0.97, z), r, flat=0.42, twist=0.15 + 0.1 * i, across=(1, 0, 0), a=0.55)
	for s in (1, -1):
		# long thin strands in front of the ears, to the collar
		gem(k, "Head", f"Strand{s}", (s * 0.86, -0.66, 5.5), (s * 0.9, -0.86, 3.72), 0.17, flat=0.6, twist=0.3, across=(1, 0, 0), a=0.54)
		gem(k, "Head", f"Zig{s}a", (s * 0.8, -0.74, 5.6), (s * 1.06, -0.84, 5.12), 0.17, flat=0.5, a=0.58)
		gem(k, "Head", f"Zig{s}b", (s * 1.06, -0.82, 5.28), (s * 0.88, -0.92, 4.86), 0.14, flat=0.5, a=0.5)
		gem(k, "Head", f"Pull{s}", (s * -0.1, 0.0, 6.02), (s * 1.02, 0.1, 5.9), 0.42, flat=0.4, twist=0.2, a=0.54)
		gem(k, "Head", f"PullB{s}", (s * 0.1, 0.6, 5.6), (s * 1.02, 0.3, 5.9), 0.44, flat=0.4, twist=0.2, a=0.48)
		# black ribbon: two upright leaves and a band round the tail's root
		block(k, "Head", f"Band{s}", s * 1.02, 0.2, 6.06, 5.66, 0.2, 0.26, "line", ch=0.05, corner=0.3, a=0.6, b=0.5)
		gem(k, "Head", f"RibA{s}", (s * 1.0, 0.16, 5.86), (s * 0.82, -0.06, 6.74), 0.36, "line", flat=0.3, twist=0.2, across=(1, 0, 0), a=0.66, b_=0.6)
		gem(k, "Head", f"RibC{s}", (s * 1.04, 0.2, 5.86), (s * 1.42, 0.1, 6.6), 0.32, "line", flat=0.3, twist=0.2, across=(1, 0, 0), a=0.66, b_=0.6)
		gem(k, "Head", f"RibB{s}", (s * 1.06, 0.1, 5.84), (s * 1.16, -0.2, 5.06), 0.28, "line", flat=0.3, twist=0.2, across=(1, 0, 0), a=0.66, b_=0.6)
		# the tail: a kick out at the root, then a long fall behind the shoulder with a hooked end
		gem(k, "Head", f"Kick{s}", (s * 1.14, 0.34, 5.8), (s * 1.76, 0.4, 6.16), 0.24, flat=0.6, twist=0.3, a=0.56)
		gem(k, "Head", f"TailA{s}", (s * 1.08, 0.4, 5.78), (s * 1.84, 0.7, 4.2), 0.46, flat=0.62, bend=0.24, twist=0.3, a=0.54)
		gem(k, "Head", f"TailB{s}", (s * 1.36, 0.5, 5.5), (s * 1.86, 0.84, 3.5), 0.42, flat=0.62, bend=0.14, twist=0.25, a=0.48)
		gem(k, "Head", f"TailC{s}", (s * 1.2, 0.5, 5.5), (s * 1.42, 0.86, 3.7), 0.38, flat=0.6, bend=0.1, twist=0.3, a=0.46)
		gem(k, "Head", f"Hook{s}", (s * 1.8, 0.78, 3.95), (s * 2.14, 0.78, 4.06), 0.17, flat=0.6, bend=-0.3, a=0.56)


def _axe(k):
	"""Held low in the viewer's left hand, the huge slab head forward and out. Built pointing down, swung from the fist."""
	arm, x, y = "RightUpperArm", -1.5, -0.34
	turn = ((x, y, 2.1), -50, 0, -16)
	rblock(k, arm, "Haft", x, y, 3.2, -0.1, 0.09, 0.09, "gun", ch=0.02, corner=0.4, rot=turn, a=0.58, b=0.5)
	rblock(k, arm, "HaftCap", x, y, 3.34, 3.06, 0.14, 0.14, "plate", ch=0.04, corner=0.4, rot=turn, a=0.56, b=0.4)
	rblock(k, arm, "Ring", x, y, 0.86, 0.62, 0.15, 0.15, "steel", ch=0.03, corner=0.4, rot=turn, a=0.56, b=0.4)
	# the head: a broad dark slab with a pale cutting edge on the outside, a blunt pale hammer on the inside
	xf(prism(k, arm, "Head", [(x + 0.2, 0.8), (x - 0.6, 1.04), (x - 1.04, 0.6), (x - 1.04, -0.6), (x - 0.6, -1.04), (x + 0.2, -0.72)], y - 0.2, y + 0.2, "gun", a=0.56, b=0.5), *turn)
	xf(prism(k, arm, "Edge", [(x - 0.96, 0.8), (x - 1.4, 1.2), (x - 1.56, 0.0), (x - 1.4, -1.2), (x - 0.96, -0.8)], y - 0.11, y + 0.11, "edge", a=0.58, b=0.4), *turn)
	xf(prism(k, arm, "Hammer", [(x + 0.2, 0.5), (x + 0.6, 0.4), (x + 0.6, -0.34), (x + 0.2, -0.44)], y - 0.26, y + 0.26, "plate", a=0.56, b=0.42), *turn)
	for d in (1, -1):
		xf(prism(k, arm, f"Core{d}", [(x - 0.12, 0.48), (x - 0.67, 0.6), (x - 0.77, 0.0), (x - 0.67, -0.6), (x - 0.12, -0.4)], y + d * 0.22 - 0.04, y + d * 0.22 + 0.04, "green", a=0.6, b=0.4), *turn)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.6)
	_hair(k)
	suit(k)
	_axe(k)
	finish()


def paint(a):
	R.paint(a)
	suit_paint(a, SKIN, "#d8ab22")
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D)
	for s, cx in ((-1, 36), (1, 94)):
		eye(f, cx, 66, s, ("#0c5a3c", "#26a46a", "#92e8b4"), w=38, up=15, dn=12, inner=5, outer=-5, ir=(11.5, 14.5), pu=(3.4, 5.0), lash="#241a14", wing=6, thick=1.3, lid=0.2)
		brow2(f, cx, 44, s, 31, 3.0, 3.2, "#b8861a", arc=-1.0)
	f.path("M50 105Q66 112 82 102", stroke="#8a3c34", sw=1.9)
