# Target look for mha_float: rounded brown bob with two long front locks, big round brown eyes, pink cheek circles, open smile,
# loose black suit with pink panels, thick ring collar, chunky pink cuffs, white belt, black boots with pink tops and soles.
from leaf_common import ell
from mha_style3 import anime_eye, bake, block, brow_block, core, gem, hand, head_faces, jitter, lump, nose, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#fbe0cf"
SKIN_D = "#e8b49a"
DEFAULT = "#1c1c24"
R = Ramps(
	hair=["#2e1a10", "#4c2e1c", "#6e4a32", "#8a6244", "#a88060"],
	skin=["#c8987c", "#ecbaa0", "#fbe0cf", "#fff0e4"],
	black=["#0c0c12", "#1c1c24", "#2e2e3a", "#464654"],
	pink=["#b05c74", "#d87e98", "#f4a6b8", "#ffcad6"],
	white=["#8f8f98", "#d2d2d8", "#f0f0f2", "#ffffff"],
)
HAIR = {"colour": "#6E4A32", "locks": []}
PROPS = []


def _hair(k):
	# the rounded cap: low lumps, no spikes above
	dome = k.lathe("Head", "Crown", [(0.96, 5.2, 0.5), (1.04, 5.5, 0.5), (0.98, 5.86, 0.5), (0.62, 6.14, 0.5), (0.18, 6.24, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.98, outline=0)
	jitter(dome, 0.02)
	bake(k, dome, "hair", a=0.48, b=0.46)
	for i, (at, r) in enumerate((((-0.52, -0.3, 5.86), (0.5, 0.5, 0.34)), ((0.52, -0.3, 5.86), (0.5, 0.5, 0.34)), ((-0.46, 0.44, 5.94), (0.54, 0.52, 0.34)), ((0.46, 0.44, 5.94), (0.54, 0.52, 0.34)))):
		lump(k, "Head", f"Cap{i}", at, r, "hair", a=0.5, b=0.5, jit=0.02)
	# the bob: a wide rounded back and sides, its hem curling in at the jaw
	block(k, "Head", "Back", 0, 0.44, 5.7, 4.22, 1.06, 0.56, "hair", ch=0.16, corner=0.34, jit=0.03, sub=1, mids=(5.0, 4.5), a=0.46, b=0.5, g=0.1)
	for s in (1, -1):
		block(k, "Head", f"Wing{s}", s * 0.93, 0.04, 5.5, 4.26, 0.18, 0.5, "hair", ch=0.09, corner=0.34, jit=0.025, sub=1, mids=(4.8,), a=0.46, b=0.5, g=0.1)
		# the two long locks in front of the ears
		gem(k, "Head", f"Lock{s}", (s * 0.76, -0.66, 5.3), (s * 0.82, -0.88, 4.0), 0.24, flat=0.5, twist=0.15, bend=-0.03, across=(1, 0, 0))
	# the fringe: rounded, parted a little off centre, ending above the brows
	for i, (x, ztip, r) in enumerate(((-0.62, 5.0, 0.32), (-0.24, 5.08, 0.34), (0.18, 5.04, 0.34), (0.6, 5.0, 0.32))):
		gem(k, "Head", f"Fringe{i}", (x * 0.86, -0.56, 5.84), (x, -0.95, ztip), r, flat=0.55, twist=0.2 + 0.3 * i % 0.6, bend=0.16)
	for i, x in enumerate((-0.66, 0.0, 0.66)):
		gem(k, "Head", f"Fold{i}", (x, 0.92, 5.6), (x * 1.08, 1.06, 4.5), 0.38, flat=0.4, twist=0.2, across=(1, 0, 0))
	for i, x in enumerate((-0.74, -0.25, 0.25, 0.74)):
		lump(k, "Head", f"Hem{i}", (x, 0.56, 4.28), (0.34, 0.4, 0.17), "hair", a=0.4, b=0.4, jit=0.015)


def _suit(k):
	t = "UpperTorso"
	# boxy and loose, a plain straight front
	block(k, t, "Body", 0, 0, 3.98, 2.0, 1.07, 0.58, "black", ch=0.08, flare=0.02, jit=0.012, mids=(3.4, 2.7), a=0.5, b=0.6, tone=0.04)
	# pink panels over the shoulders and down the chest
	block(k, t, "Yoke", 0, 0, 3.98, 3.14, 0.74, 0.62, "pink", ch=0.06, a=0.5, b=0.5)
	for s in (1, -1):
		strip(k, t, f"Side{s}", (s * 0.62, 3.1), (s * 0.62, 2.46), 0.1, -0.625, 0.05, "pink", a=0.5, b=0.5)
		strip(k, t, f"Back{s}", (s * 0.62, 3.1), (s * 0.62, 2.46), 0.1, 0.575, 0.05, "pink", a=0.42, b=0.5)
	# the thick ring collar
	block(k, t, "Ring", 0, -0.02, 4.12, 3.8, 0.96, 0.7, "white", ch=0.08, corner=0.45, sub=1, a=0.58, b=0.4)
	block(k, t, "RingKey", 0, -0.73, 4.08, 3.82, 0.2, 0.05, "pink", ch=0.03, corner=0.3, a=0.52, b=0.5)
	block(k, t, "Belt", 0, 0, 2.42, 2.16, 1.1, 0.62, "white", ch=0.04, a=0.58, b=0.4)
	block(k, t, "Buckle", 0, -0.635, 2.4, 2.18, 0.17, 0.03, "pink", ch=0.02, a=0.5)
	block(k, t, "Hips", 0, 0, 2.16, 1.88, 1.08, 0.585, "black", ch=0.02, a=0.5, b=0.6)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.0, 2.86, 0.51, 0.51, "black", ch=0.1, corner=0.2, jit=0.012, sub=1, mids=(3.4,), a=0.5, b=0.6)
	block(k, arm, "Panel", ax, 0, 4.02, 3.46, 0.56, 0.56, "pink", ch=0.1, corner=0.2, a=0.5, b=0.5)
	block(k, arm, "Fore", ax, 0, 2.94, 2.6, 0.52, 0.52, "black", ch=0.05, corner=0.18, a=0.5, b=0.6)
	block(k, arm, "Cuff", ax, 0, 2.76, 2.28, 0.6, 0.6, "pink", ch=0.1, corner=0.3, sub=1, a=0.52, b=0.5)
	hand(k, arm, ax, "black", z1=2.34)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 1.0, 0.525, 0.57, "black", ch=0.04, flare=0.03, corner=0.16, jit=0.02, mids=(1.5,), a=0.5, b=0.6, tone=0.04)
	block(k, leg, "Thigh", x, -0.5, 1.76, 1.3, 0.36, 0.12, "pink", ch=0.04, corner=0.2, a=0.5, b=0.5)
	block(k, leg, "Ankle", x, 0.0, 1.18, 0.78, 0.62, 0.66, "pink", ch=0.1, corner=0.3, sub=1, a=0.52, b=0.5)
	block(k, leg, "Shaft", x, 0.02, 0.84, 0.14, 0.53, 0.58, "black", ch=0.04, a=0.54, b=0.55)
	block(k, leg, "Toe", x, -0.28, 0.5, 0.14, 0.55, 0.52, "black", ch=0.09, corner=0.28, a=0.56, b=0.55)
	block(k, leg, "Sole", x, -0.16, 0.17, 0.0, 0.57, 0.76, "pink", ch=0.03, a=0.48, b=0.4)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def paint(a):
	R.paint(a)
	f = head_faces(a, SKIN, SKIN_D, "#6E4A32")
	for s, x in ((-1, 37), (1, 93)):
		anime_eye(f, x, 58, s, "#7a4a2a", w=36, up=18, dn=19, lift=2, lt=3.2, wing=2.5, ir=13, lash="#2a1a14")
		brow_block(f, s, 12, 40, 40, 36, 2.4, "#6e4a32")
		# the round cheek circles
		f.soft(ell(x + s * 3, 90, 12, 8), "#ee7f88", 0.75, 1)
	nose(f, SKIN_D, 82)
	# open happy mouth
	shape = "M50 96Q65 100 80 96Q78 112 65 113Q52 112 50 96Z"
	f.path(shape, "#7a2a2c")
	f.path("M55 106Q65 100 75 106Q70 113 65 113Q60 113 55 106Z", "#e2777c")
	f.path("M51 96Q65 100 79 96L78 99Q65 103 52 99Z", "#fbfbf6")
