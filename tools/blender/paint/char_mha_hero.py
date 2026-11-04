# Target look for mha_hero: dark green curly clumps, big round green eyes, freckles, teal jumpsuit with dark lines, hood with
# two tips, steel mouth guard at the throat, white gloves, belt with pouches, knee pads, chunky red boots with white soles.
from leaf_common import ell
from mha_style3 import anime_eye, bake, block, brow_block, core, gem, hand, head_faces, jitter, lump, nose, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#fbd5b8"
SKIN_D = "#e6a982"
DEFAULT = "#2e7a5a"
R = Ramps(
	hair=["#061a18", "#0c2c26", "#143e32", "#1e5444", "#2f7a5a"],
	skin=["#c98a64", "#ecb48e", "#fbd5b8", "#ffe6d0"],
	suit=["#14503e", "#1f6a52", "#2e8a6a", "#46a884"],
	line=["#0c0f12", "#1a1e22", "#2c3238", "#40464e"],
	white=["#8f939c", "#d4d6dc", "#f2f2f4", "#ffffff"],
	steel=["#4e555e", "#7c848e", "#9aa3ad", "#c8ced6"],
	red=["#7c0e12", "#b0181c", "#d4262a", "#f04a44"],
	gold=["#8a5c0e", "#c08a1c", "#e0ac34", "#f6d060"],
)
HAIR = {"colour": "#1E4A3A", "locks": []}
PROPS = []


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.56, 0.5), (0.94, 5.92, 0.5), (0.52, 6.2, 0.5), (0.14, 6.28, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.96, outline=0)
	jitter(dome, 0.03)
	bake(k, dome, "hair", a=0.42, b=0.32)
	# fluffy mass: big soft lumps on top, tips curling out
	for i, (at, r) in enumerate((((-0.62, -0.25, 6.02), (0.46, 0.46, 0.4)), ((0.02, -0.34, 6.2), (0.5, 0.48, 0.42)), ((0.64, -0.22, 6.04), (0.46, 0.46, 0.4)), ((-0.42, 0.42, 6.16), (0.48, 0.48, 0.4)), ((0.42, 0.44, 6.16), (0.48, 0.48, 0.4)), ((-0.92, 0.2, 5.62), (0.36, 0.5, 0.42)), ((0.94, 0.2, 5.62), (0.36, 0.5, 0.42)), ((0.0, 0.84, 5.62), (0.62, 0.34, 0.46)))):
		lump(k, "Head", f"Puff{i}", at, r, "hair")
	root = (0, 0.1, 5.6)
	for i, (tip, r) in enumerate((((-1.16, -0.1, 6.02), 0.3), ((-0.72, -0.3, 6.62), 0.32), ((-0.1, -0.2, 6.78), 0.34), ((0.56, -0.24, 6.68), 0.32), ((1.18, -0.08, 6.06), 0.3), ((-1.28, 0.3, 5.38), 0.28), ((1.28, 0.3, 5.4), 0.28), ((-0.72, 0.84, 6.34), 0.32), ((0.1, 0.9, 6.52), 0.34), ((0.8, 0.82, 6.3), 0.32))):
		b = tuple(root[j] + (tip[j] - root[j]) * 0.45 for j in range(3))
		gem(k, "Head", f"Curl{i}", b, tip, r, twist=0.3 + 0.17 * i, flat=0.7)
	# messy fringe hanging over the forehead
	for i, (x, ztip, r) in enumerate(((-0.74, 4.98, 0.3), (-0.34, 5.08, 0.31), (0.06, 4.94, 0.32), (0.42, 5.1, 0.3), (0.78, 5.0, 0.28))):
		gem(k, "Head", f"Fringe{i}", (x * 0.9, -0.6, 5.78), (x + 0.05 * (-1) ** i, -0.92, ztip), r, flat=0.5, twist=0.2 + 0.3 * i % 0.6, bend=0.14)
	# sides and nape
	for s in (1, -1):
		for i, (y, z0, r) in enumerate(((-0.5, 4.7, 0.28), (-0.12, 4.62, 0.3), (0.28, 4.56, 0.32))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.86, y, 5.5), (s * 1.0, y - 0.03, z0), r, flat=0.5, twist=0.25 + 0.2 * i, across=(0, 1, 0))
	block(k, "Head", "Nape", 0, 0.42, 5.72, 4.5, 0.98, 0.5, "hair", ch=0.08, corner=0.22, jit=0.03, sub=1, a=0.42, b=0.4)
	for i, x in enumerate((-0.62, -0.2, 0.2, 0.62)):
		gem(k, "Head", f"NapeC{i}", (x, 0.74, 5.05), (x * 1.08, 0.94, 4.28 + 0.07 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0))


def _suit(k):
	t = "UpperTorso"
	block(k, t, "Body", 0, 0, 3.98, 2.0, 1.06, 0.57, "suit", ch=0.07, flare=0.02, jit=0.035, mids=(3.4, 2.7), a=0.42, b=0.58, g=0.1, tone=0.05)
	# dark lines: a yoke from each shoulder down to the sternum, the centre line below it
	for s in (1, -1):
		strip(k, t, f"Yoke{s}", (s * 0.98, 3.88), (s * 0.1, 3.22), 0.075, -0.625, 0.06, "line", a=0.5)
	strip(k, t, "Centre", (0, 3.26), (0, 2.42), 0.07, -0.625, 0.06, "line", a=0.5)
	for s in (1, -1):
		block(k, t, f"Flank{s}", s * 1.06, 0, 3.7, 2.42, 0.05, 0.6, "line", ch=0.015, a=0.48)
	# belt and pouches
	block(k, t, "Belt", 0, 0, 2.44, 2.14, 1.1, 0.62, "line", ch=0.04, a=0.55)
	block(k, t, "Buckle", 0, -0.63, 2.42, 2.16, 0.16, 0.03, "gold", ch=0.02, a=0.6)
	for i, x in enumerate((-0.74, -0.42, 0.42, 0.74)):
		block(k, t, f"Pouch{i}", x, -0.66, 2.46, 2.08, 0.14, 0.09, "gold", ch=0.03, a=0.5)
	block(k, t, "Hips", 0, 0, 2.14, 1.88, 1.08, 0.585, "suit", ch=0.02, a=0.42, b=0.62)
	# hood fallen behind the neck, its two tips standing up behind the shoulders
	block(k, t, "Hood", 0, 0.5, 4.3, 3.72, 0.9, 0.3, "suit", ch=0.1, corner=0.3, jit=0.03, sub=1, a=0.42, b=0.6)
	for s in (1, -1):
		gem(k, t, f"HoodTip{s}", (s * 0.5, 0.56, 4.0), (s * 1.22, 0.56, 5.02), 0.33, ramp="suit", flat=0.5, twist=0.2, a=0.5, b_=0.5)
	# collar and the steel mouth guard resting at the throat
	block(k, t, "Collar", 0, -0.02, 4.14, 3.92, 0.74, 0.56, "line", ch=0.03, corner=0.3, a=0.5)
	block(k, t, "Guard", 0, -0.52, 4.1, 3.72, 0.46, 0.12, "steel", ch=0.05, corner=0.3, jit=0.012, a=0.58, b=0.5)
	for i in range(3):
		block(k, t, f"Vent{i}", -0.22 + 0.22 * i, -0.645, 4.0, 3.82, 0.055, 0.012, "line", ch=0.006, a=0.4)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.0, 2.86, 0.52, 0.52, "suit", ch=0.09, corner=0.18, jit=0.03, sub=1, mids=(3.4,), a=0.42, b=0.58)
	block(k, arm, "Band", ax, 0, 3.32, 3.16, 0.56, 0.56, "line", ch=0.02, corner=0.18, a=0.5)
	block(k, arm, "Fore", ax, 0, 2.94, 2.46, 0.52, 0.52, "suit", ch=0.06, corner=0.18, jit=0.025, a=0.42, b=0.58)
	block(k, arm, "Cuff", ax, 0, 2.6, 2.36, 0.56, 0.56, "white", ch=0.05, corner=0.2, a=0.62, b=0.36)
	hand(k, arm, ax, "white", z1=2.42)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 1.0, 0.525, 0.57, "suit", ch=0.04, flare=0.03, corner=0.16, jit=0.05, mids=(1.5,), a=0.42, b=0.6, tone=0.06)
	block(k, leg, "Knee", x, -0.32, 1.42, 1.04, 0.42, 0.3, "line", ch=0.06, corner=0.2, a=0.55)
	block(k, leg, "Shaft", x, 0.02, 1.12, 0.46, 0.53, 0.58, "red", ch=0.06, flare=0.02, jit=0.015, a=0.52, b=0.5)
	block(k, leg, "BootTop", x, 0.02, 1.16, 1.02, 0.56, 0.61, "red", ch=0.03, a=0.62, b=0.45)
	block(k, leg, "Toe", x, -0.28, 0.52, 0.14, 0.54, 0.5, "red", ch=0.09, corner=0.25, a=0.52, b=0.5)
	block(k, leg, "Heel", x, 0.04, 0.5, 0.14, 0.53, 0.56, "red", ch=0.05, a=0.5)
	block(k, leg, "Sole", x, -0.14, 0.17, 0.0, 0.56, 0.76, "white", ch=0.03, a=0.58, b=0.4)


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
	f = head_faces(a, SKIN, SKIN_D, "#1E4A3A")
	for s, x in ((-1, 36), (1, 94)):
		anime_eye(f, x, 58, s, "#2fa868", w=37, up=18, dn=19, lift=3, lt=3.2, wing=2.5, ir=13)
		brow_block(f, s, 11, 42, 39, 33, 3.0, "#1c4c3a")
		for dx, dy in ((-7, 0), (0, 3), (7, 0)):
			f.path(ell(x + dx, 88 + dy, 1.4, 2.0), "#a8603e")
	nose(f, SKIN_D, 79)
	# small determined smile
	f.path("M52 97Q65 105 78 96Q66 100 52 97Z", "#5c2a22", stroke="#5c2a22", sw=1.1)
