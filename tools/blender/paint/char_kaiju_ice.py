# Target look for kaiju_ice "Rino" (design doc section 5): a pale silver mop with a straight pointed fringe and a small tuft, calm lilac-grey
# eyes, the defence corps' black suit with green chest plates and pale shoulder plates, a rifle with an ice-blue magazine and frost on
# its muzzle. +X is the viewer's right. Drawn in-house.
from ds_style3 import eye, xf
from kaiju_style3 import BLACK, SUIT, Kit, Ramps, big_head, block, brow2, crown, ears, finish, gem, rblock, skin_face, suit, suit_paint, hair_back, fist_grip, top_layers

SKIN, SKIN_D = "#f6d4ba", "#d2a284"
DEFAULT = BLACK
R = Ramps(
	hair=["#70737e", "#a2a5b0", "#cfd2da", "#eceef3", "#ffffff"],
	skin=["#c8987c", "#e8bca0", SKIN, "#ffeadb"],
	ice=["#2a7ab8", "#54b0e6", "#9ee0fa", "#e6fbff"],
	**SUIT,
)
HAIR = {"colour": "#CFD2DA", "locks": []}
PROPS = []


def _hair(k):
	hair_back(k)
	top_layers(k, (-0.8, -0.4, 0.0, 0.4, 0.8))
	crown(k, [(0.98, 5.2), (1.08, 5.48), (1.02, 5.82), (0.66, 6.08), (0.18, 6.16)], at=(0, 0.0, 0))
	block(k, "Head", "Back", 0, 0.3, 5.5, 4.56, 1.0, 0.64, "hair", ch=0.08, corner=0.3, sub=1, jit=0.02, a=0.44, b=0.42)
	# straight pointed fringe down to the eyes
	for i, (x, z, r) in enumerate(((-0.9, 4.88, 0.24), (-0.62, 4.98, 0.26), (-0.32, 4.86, 0.27), (0.0, 5.0, 0.26), (0.3, 4.9, 0.27), (0.62, 5.0, 0.26), (0.9, 4.88, 0.24))):
		gem(k, "Head", f"Fringe{i}", (x * 0.82, -0.82, 5.7), (x * 1.02, -0.97 + 0.06 * abs(x), z), r, flat=0.42, twist=0.15 + 0.12 * (i % 3), across=(1, 0, 0), a=0.54)
	for s in (1, -1):
		for i, (y, z, r) in enumerate(((-0.56, 4.5, 0.26), (-0.1, 4.66, 0.3), (0.34, 4.4, 0.32))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.84, y, 5.6), (s * 1.05, y - 0.04, z), r, flat=0.45, twist=0.2 + 0.15 * i, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Sweep{s}", (s * 0.2, 0.0, 6.0), (s * 1.16, 0.1, 5.3), 0.4, flat=0.4, twist=0.3, a=0.52)
		gem(k, "Head", f"SweepB{s}", (s * 0.24, 0.3, 5.95), (s * 0.84, 1.0, 5.2), 0.4, flat=0.4, twist=0.25, a=0.5)
	# the small tuft standing at the crown
	gem(k, "Head", "Tuft0", (0.04, 0.1, 6.02), (-0.3, 0.02, 6.4), 0.18, flat=0.6, a=0.56)
	gem(k, "Head", "Tuft1", (0.0, 0.1, 6.02), (0.3, 0.12, 6.36), 0.17, flat=0.6, a=0.56)


def _rifle(k):
	"""Held low across the front of the viewer's left fist, muzzle down and out. Built pointing down, the pistol grip in the fist, then swung."""
	arm, x, y = "RightUpperArm", -1.5, -0.72
	turn = ((x, y, 2.06), -12, 56, 0)
	b = x - 0.4  # the body's line, above the fist
	rblock(k, arm, "Pistol", x - 0.02, y, 2.22, 1.9, 0.36, 0.1, "gun", ch=0.03, rot=turn, a=0.6, b=0.5)
	rblock(k, arm, "Stock", b + 0.04, y, 3.0, 2.4, 0.2, 0.1, "gun", ch=0.05, rot=turn, a=0.54, b=0.5)
	rblock(k, arm, "Body", b, y, 2.5, 1.06, 0.22, 0.16, "gun", ch=0.05, rot=turn, a=0.54, b=0.52)
	rblock(k, arm, "Rail", b - 0.24, y, 2.3, 1.2, 0.05, 0.08, "steel", ch=0.02, rot=turn, a=0.5, b=0.4)
	rblock(k, arm, "Scope", b - 0.36, y, 2.16, 1.46, 0.1, 0.12, "gun", ch=0.04, corner=0.4, rot=turn, a=0.6, b=0.5)
	rblock(k, arm, "Mag", b + 0.4, y, 1.7, 1.3, 0.3, 0.11, "ice", ch=0.04, rot=turn, a=0.56, b=0.4)
	rblock(k, arm, "Barrel", b, y, 1.1, 0.4, 0.09, 0.09, "gun", ch=0.02, corner=0.4, rot=turn, a=0.6, b=0.46)
	rblock(k, arm, "Muzzle", b, y, 0.48, 0.2, 0.15, 0.14, "steel", ch=0.03, corner=0.4, rot=turn, a=0.54, b=0.46)
	# frost grown along the muzzle, the freezing rounds
	for i, (dx, dy, z0, tx, ty, tz, r) in enumerate(((0.1, -0.06, 0.5, 0.42, -0.2, 0.36, 0.14), (-0.1, -0.06, 0.66, -0.4, -0.24, 0.66, 0.14), (0.0, 0.0, 0.3, 0.04, 0.0, -0.3, 0.16), (-0.1, 0.0, 0.3, -0.3, -0.06, -0.1, 0.12))):
		xf(gem(k, arm, f"Frost{i}", (b + dx, y + dy, z0), (b + tx, y + ty, tz), r, "ice", a=0.6), *turn)
	fist_grip(k, "Right", -1, y)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.6)
	_hair(k)
	suit(k)
	_rifle(k)
	finish()


def paint(a):
	R.paint(a)
	suit_paint(a, SKIN, "#a2a5b0")
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, 0.14)
	for s, cx in ((-1, 36), (1, 94)):
		eye(f, cx, 66, s, ("#4e466a", "#968cb8", "#d8d2ee"), w=36, up=12, dn=10, inner=4, outer=-3, ir=(10.5, 13), pu=(3.2, 4.6), lash="#2a2630", wing=3, thick=1.0, lid=0.28)
		brow2(f, cx, 46, s, 30, 3.6, 2.2, "#8f929c", arc=-1.0)
	f.path("M55 107Q65 106 75 107", stroke="#7c3f34", sw=1.6)
