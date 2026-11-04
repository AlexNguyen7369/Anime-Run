# Target look for mha_symbol: two tall blond bang spikes in a V, short spikes behind, eyes in deep shadow, huge grin, heavy jaw,
# blue suit with a padded chest, red V band edged white, broad shoulders, yellow gloves, red boots, short red cape.
from atlas import shade
from leaf_common import ell
from mha_style3 import bake, block, core, gem, hand, head_faces, nose, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f6d3b6"
SKIN_D = "#d89a74"
DEFAULT = "#2e4fa0"
R = Ramps(
	hair=["#a87808", "#d4a014", "#f4d23a", "#fce668", "#fff4a0"],
	skin=["#b87c58", "#e0a884", "#f6d3b6", "#ffe4cc"],
	blue=["#14286a", "#203c88", "#2e4fa0", "#4870c8"],
	red=["#72100f", "#a81a1c", "#d8262a", "#f04c44"],
	white=["#8f939c", "#d2d4da", "#f2f2f4", "#ffffff"],
	yellow=["#a87808", "#d49c14", "#f2c230", "#ffe070"],
	cape=["#5c0e10", "#8a1a1c", "#c42a2a", "#e04c44"],
)
HAIR = {"colour": "#F4D23A", "locks": []}
PROPS = []
# heavy square jaw
HEAD_ROWS = [(0, 0, 3.98, 0.8, 0.66), (0, 0, 4.06, 0.9, 0.8), (0, 0, 4.2, 0.92, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.56, 0.5), (0.9, 5.88, 0.5), (0.46, 6.14, 0.5), (0.12, 6.2, 0.5)], "hair", n=10, at=(0, 0.08, 0), squash=0.96, outline=0)
	bake(k, dome, "hair", a=0.48, b=0.34)
	# the two great bangs: rise from the middle of the forehead and sweep up and out in a V
	for s in (1, -1):
		gem(k, "Head", f"Bang{s}", (s * 0.26, -0.64, 5.26), (s * 0.98, -0.7, 7.16), 0.52, flat=0.46, twist=0.1, bend=0.0, a=0.54, b_=0.6, across=(1, 0, 0))
		gem(k, "Head", f"BangB{s}", (s * 0.34, -0.3, 5.5), (s * 0.84, -0.44, 6.78), 0.44, flat=0.6, twist=0.25, a=0.44)
		# a lock at the centre of the forehead, between the bangs
		gem(k, "Head", f"Parted{s}", (s * 0.14, -0.62, 5.5), (s * 0.34, -0.92, 5.06), 0.17, flat=0.55, twist=0.2)
		gem(k, "Head", f"Temple{s}", (s * 0.72, -0.56, 5.56), (s * 1.02, -0.84, 5.02), 0.26, flat=0.55, twist=0.25)
		for i, (y, z0, r) in enumerate(((-0.42, 4.84, 0.24), (-0.04, 4.76, 0.26), (0.32, 4.72, 0.28))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.86, y, 5.5), (s * 1.02, y + 0.02, z0), r, flat=0.5, twist=0.2 * i + 0.25, across=(0, 1, 0))
	root = (0, 0.1, 5.6)
	for i, (tip, r) in enumerate((((-1.16, 0.36, 5.9), 0.36), ((1.16, 0.36, 5.9), 0.36), ((-0.74, 0.86, 6.24), 0.4), ((0.74, 0.86, 6.24), 0.4), ((0.0, 1.06, 6.32), 0.42), ((-0.96, 0.92, 5.42), 0.34), ((0.96, 0.92, 5.42), 0.34), ((0.0, 1.2, 5.54), 0.38))):
		b = tuple(root[j] + (tip[j] - root[j]) * 0.25 for j in range(3))
		gem(k, "Head", f"Back{i}", b, tip, r, twist=0.3 + 0.13 * i % 0.5)
	block(k, "Head", "Nape", 0, 0.42, 5.72, 4.6, 0.98, 0.5, "hair", ch=0.08, corner=0.22, jit=0.02, a=0.44, b=0.36)
	for i, x in enumerate((-0.66, -0.22, 0.22, 0.66)):
		gem(k, "Head", f"NapeS{i}", (x, 0.74, 5.1), (x * 1.08, 0.98, 4.34 + 0.06 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0))


def _suit(k):
	t = "UpperTorso"
	block(k, t, "Body", 0, 0, 3.98, 2.0, 1.1, 0.6, "blue", ch=0.08, flare=-0.03, jit=0.03, mids=(3.4, 2.7), a=0.46, b=0.6, tone=0.04)
	# the broad padded chest in big plates; the suit stays on, no muscle lines
	for s in (1, -1):
		block(k, t, f"Chest{s}", s * 0.54, -0.6, 3.74, 3.0, 0.5, 0.12, "blue", ch=0.06, corner=0.2, jit=0.01, a=0.52, b=0.58)
	# the V band: white under red
	for s in (1, -1):
		strip(k, t, f"VWhite{s}", (s * 0.98, 3.84), (0, 2.6), 0.2, -0.73, 0.08, "white", a=0.58, b=0.4)
		strip(k, t, f"VRed{s}", (s * 0.98, 3.84), (0, 2.6), 0.13, -0.75, 0.08, "red", a=0.54, b=0.5)
	block(k, t, "Belt", 0, 0, 2.42, 2.16, 1.08, 0.61, "yellow", ch=0.04, a=0.54)
	block(k, t, "Hips", 0, 0, 2.16, 1.88, 1.06, 0.585, "blue", ch=0.02, a=0.42, b=0.6)
	# high collar and the short cape, close to the back, hem cut in points
	block(k, t, "Collar", 0, -0.02, 4.14, 3.9, 0.78, 0.58, "red", ch=0.05, corner=0.3, a=0.54, b=0.5)
	block(k, t, "Cape", 0, 0.68, 4.02, 2.1, 1.12, 0.09, "cape", ch=0.04, flare=0.03, jit=0.04, mids=(3.4, 2.7), a=0.46, b=0.5, tone=0.05)
	for i, x in enumerate((-0.76, 0.0, 0.76)):
		gem(k, t, f"CapeTip{i}", (x, 0.68, 2.2), (x, 0.7, 1.72), 0.38, ramp="cape", flat=0.22, twist=0.0, a=0.44, b_=0.45, across=(1, 0, 0))


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.56
	block(k, arm, "Shoulder", ax, 0, 4.1, 3.3, 0.62, 0.62, "blue", ch=0.14, corner=0.2, jit=0.03, sub=1, mids=(3.7,), a=0.5, b=0.6)
	block(k, arm, "ShoulderBand", ax, 0, 3.48, 3.28, 0.67, 0.67, "white", ch=0.03, corner=0.2, a=0.56, b=0.4)
	block(k, arm, "Sleeve", ax, 0, 3.36, 2.62, 0.56, 0.56, "blue", ch=0.07, corner=0.18, jit=0.03, a=0.46, b=0.6)
	block(k, arm, "Glove", ax, 0, 2.78, 2.36, 0.6, 0.6, "yellow", ch=0.08, corner=0.22, a=0.54, b=0.5)
	hand(k, arm, s * 1.5, "yellow", z1=2.42)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.55
	block(k, leg, "Pants", x, 0, 1.95, 0.94, 0.55, 0.6, "blue", ch=0.04, flare=0.03, corner=0.16, jit=0.03, mids=(1.45,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Shaft", x, 0.02, 1.08, 0.14, 0.58, 0.63, "red", ch=0.06, flare=0.015, a=0.52, b=0.5)
	block(k, leg, "BootTop", x, 0.02, 1.12, 0.96, 0.63, 0.68, "white", ch=0.03, a=0.58, b=0.4)
	block(k, leg, "Toe", x, -0.28, 0.5, 0.14, 0.58, 0.54, "red", ch=0.09, corner=0.25, a=0.54, b=0.5)
	block(k, leg, "Sole", x, -0.16, 0.17, 0.0, 0.6, 0.78, "yellow", ch=0.03, a=0.42, b=0.4)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	core(k)
	_hair(k)
	_suit(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def paint(a):
	R.paint(a)
	f = head_faces(a, SKIN, SKIN_D, "#F4D23A")
	# the deep shadow over the eyes, a dark mass from the brow down to the cheekbone
	f.soft("M-5-5H135V36Q65 40 -5 36Z", "#6a4a54", 0.8, 3)
	for s, x in ((-1, 36), (1, 94)):
		# each eye sinks into its own socket under a heavy brow; the nose bridge stays lit
		f.path(f"M{x - s * 22} 44L{x + s * 26} 24L{x + s * 32} 52Q{x + s * 20} 72 {x - s * 6} 68Q{x - s * 20} 62 {x - s * 22} 44Z", "#232848", blur=3)
	for s, x in ((-1, 36), (1, 94)):
		f.path(ell(x, 54, 6.2, 8), "#4ec4ff")
		f.path(ell(x, 54, 3, 4.2), "#e8faff")
		# strong cheek lines
		f.path(f"M{65 + s * 36} 80Q{65 + s * 44} 92 {65 + s * 46} 108", stroke=shade(SKIN, 0.58), sw=1.6)
	f.path("M65 52L60 80L66 84Q72 84 70 78Z", SKIN_D, opacity=0.7)
	# the huge grin, wider than the eyes, every tooth showing
	shape = "M16 90Q65 100 114 90Q112 112 92 118Q65 124 38 118Q18 112 16 90Z"
	f.path(shape, "#3a1414", stroke="#3a1414", sw=1.6)
	f.out.append(f'<clipPath id="grin"><path d="{shape}"/></clipPath><g clip-path="url(#grin)">')
	f.path("M10 88H120V124H10Z", "#fdfdf8")
	f.path("M10 106Q65 110 120 106", stroke="#7a5a58", sw=1.2)
	for x in range(22, 112, 9):
		f.path(f"M{x} 88V124", stroke="#9a9090", sw=0.9)
	f.out.append("</g>")
