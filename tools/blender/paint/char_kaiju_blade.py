# Target look for kaiju_blade "Hoshena" (design doc section 5): a glossy dark violet bowl cut with a straight fringe, eyes smiled shut, a
# grin with one small fang, the corps' combat suit, twin short black blades held low. +X is the viewer's right. Drawn in-house.
from ds_style3 import xf
from jk_style3 import bake
from kaiju_style3 import BLACK, SUIT, Kit, Ramps, big_head, block, brow2, ears, finish, gem, prism, rblock, skin_face, stroke, suit, suit_paint

SKIN, SKIN_D = "#f6d4ba", "#d2a284"
DEFAULT = BLACK
R = Ramps(
	hair=["#120c1e", "#251a3c", "#3c2c5e", "#5c4788", "#8c74b8"],
	skin=["#c8987c", "#e8bca0", SKIN, "#ffeadb"],
	blade=["#0c0d12", "#191b22", "#2c2f3a", "#4a4f5e"],
	**SUIT,
)
HAIR = {"colour": "#3C2C5E", "locks": []}
PROPS = []


def _hair(k):
	# the bowl: one smooth cap, cut level above the eyes in front and at the ears behind
	cap = [(0, 0.06, 6.24, 0.36, 0.34), (0, 0.05, 6.12, 0.72, 0.66), (0, 0.04, 5.82, 1.0, 0.92), (0, 0.03, 5.4, 1.1, 1.02), (0, 0.03, 5.06, 1.12, 1.03), (0, 0.03, 5.02, 1.06, 0.98)]
	bake(k.tube("Head", "Bowl", cap, "hair", corner=0.42, nc=3, sub=1, outline=0), "hair", k, a=0.5, b=0.5, g=0.1)
	block(k, "Head", "Back", 0, 0.42, 5.2, 4.68, 1.1, 0.64, "hair", ch=0.05, corner=0.36, sub=1, a=0.44, b=0.46)
	block(k, "Head", "Nape", 0, 0.56, 4.8, 4.3, 0.8, 0.36, "hair", ch=0.08, corner=0.3, flare=-0.06, a=0.4, b=0.4)
	# the fringe's edge: short blades in one straight line
	for i, x in enumerate((-0.9, -0.6, -0.3, 0.0, 0.3, 0.6, 0.9)):
		gem(k, "Head", f"Fringe{i}", (x * 0.94, -0.87 + 0.06 * abs(x), 5.78), (x * 1.02, -1.04 + 0.08 * abs(x), 4.84 + 0.06 * (i % 2)), 0.27, flat=0.5, twist=0.1, across=(1, 0, 0), a=0.5)
	for s in (1, -1):
		for i, (y, z) in enumerate(((-0.7, 4.6), (-0.4, 4.66), (-0.1, 4.62))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.95, y, 5.7), (s * 1.12, y, z), 0.27, flat=0.5, twist=0.1, across=(0, 1, 0), a=0.48)


def _blade(k, side, s):
	arm, x, y = f"{side}UpperArm", s * 1.5, -0.34
	turn = ((x, y, 2.1), -58, 0, s * 34)
	rblock(k, arm, "Grip", x, y, 2.66, 1.76, 0.09, 0.11, "gun", ch=0.02, rot=turn, a=0.56, b=0.46)
	rblock(k, arm, "Pommel", x, y, 2.78, 2.6, 0.12, 0.14, "plate", ch=0.03, rot=turn, a=0.56, b=0.4)
	rblock(k, arm, "Guard", x, y, 1.74, 1.56, 0.2, 0.16, "green", ch=0.03, rot=turn, a=0.56, b=0.46)
	# single edged: pale edge on the outside, the tip cut straight across like a chisel
	o = s
	xf(prism(k, arm, "Blade", [(x - o * 0.15, 1.6), (x + o * 0.11, 1.6), (x + o * 0.11, -0.66), (x - o * 0.15, -0.34)], y - 0.05, y + 0.05, "blade", a=0.56, b=0.5), *turn)
	xf(prism(k, arm, "Edge", [(x + o * 0.1, 1.5), (x + o * 0.2, 1.4), (x + o * 0.2, -0.86), (x - o * 0.15, -0.46), (x - o * 0.15, -0.32), (x + o * 0.1, -0.64)], y - 0.025, y + 0.025, "edge", a=0.64, b=0.34), *turn)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.5)
	_hair(k)
	suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_blade(k, side, s)
		# the two empty sheaths crossed at the hips
		turn = ((s * 0.9, 0.62, 2.3), -64, 0, s * 12)
		rblock(k, "UpperTorso", f"Sheath{s}", s * 0.9, 0.66, 2.42, 1.2, 0.1, 0.14, "green", ch=0.03, rot=turn, a=0.52, b=0.46)
	finish()


def paint(a):
	R.paint(a)
	suit_paint(a, SKIN, "#251a3c")
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, 0.18)
	for s, cx in ((-1, 36), (1, 94)):
		# smiled shut: a heavy arch with a flick at the outer end
		f.path(f"M{cx - s * 18} 70Q{cx - s * 2} 52 {cx + s * 20} 65L{cx + s * 22} 70Q{cx - s * 1} 59 {cx - s * 18} 70Z", "#1c1424")
		stroke(f, f"M{cx + s * 12} 72L{cx + s * 20} 72", "#b47e66", 1.0)
		brow2(f, cx, 47, s, 29, 3.4, 0.6, "#2a1e42", arc=-3.0)
	# the open grin, one fang
	f.path("M44 98Q65 104 88 97Q84 116 66 117Q48 116 44 98Z", "#6e1e22", stroke="#3a1014", sw=1.4)
	f.path("M46 99Q65 105 86 98L84 103Q65 109 48 104Z", "#ffffff")
	f.path("M76 102L83 101L79 111Z", "#ffffff")
