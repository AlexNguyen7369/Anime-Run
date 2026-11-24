# Target look for fr_scales "Ora" (design doc section 5): violet-pink hair with a pointed centre fringe, low twin tails split into three braids, two long dark curving
# horns, violet eyes and a smug smile; a dark blue bodice, long dark gloves, a short white skirt with a frilled pink half cape, high dark boots, the gold scales in her left hand.
# The source's bare midriff is closed (brief: fully clothed). +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, collar, elf_ears, face, fill_body, finish, gem, helmet, horns, jacket, locks, prism, rod, skirt

SKIN = "#fae0d8"
SKIN_D = "#d4a8a0"
DEFAULT = "#262c54"
R = Ramps(
	hair=["#7c3c74", "#a25a98", "#c67cba", "#e0a0d4", "#f6cdee"],
	skin=["#c49c94", "#e6c6be", "#fae0d8", "#fff0ea"],
	horn=["#16121a", "#28222c", "#423a46", "#6c6270"],
	navy=["#0e1230", "#181e46", "#252d60", "#38447e", "#5868a8"],
	glove=["#0a0c20", "#141830", "#202644", "#323a60"],
	white=["#9c9ab0", "#c6c4d4", "#e8e6f0", "#ffffff"],
	pink=["#8a3c5c", "#b85c80", "#e084a4", "#f8b4c8"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	boot=["#0c0c1c", "#16162a", "#24243e", "#3a3a58"],
	sole=["#08080c", "#14141a", "#24242c", "#36363e"],
	gem=["#4a0a3c", "#881a6c", "#cc3ca4", "#ff9ce0"],
)
HAIR = {"colour": "#C67CBA", "locks": []}
PROPS = []


def _braid(k, tag, pts, r, n=11):
	"""One plait: a rod that swells and pinches along a smooth path, ending in a tie and a tuft."""
	line = []
	for i in range(n):
		t = i / (n - 1) * (len(pts) - 1)
		j = min(int(t), len(pts) - 2)
		line.append(tuple(pts[j][c] + (pts[j + 1][c] - pts[j][c]) * (t - j) for c in range(3)))
	rod(k, "Head", tag, line, [r * (1.0 if i % 2 else 0.62) for i in range(n)], "hair", n=6, a=0.52, b=0.48)
	x, y, z = pts[-1]
	block(k, "Head", tag + "Tie", x, y, z + 0.06, z - 0.08, r * 0.8, r * 0.8, "navy", ch=0.02, a=0.56, b=0.44)
	gem(k, "Head", tag + "Tuft", (x, y, z - 0.02), (x * 1.02, y, z - 0.5), r, flat=0.8, a=0.54)


def _hair(k):
	helmet(k, low=4.3)
	for i, (t, r) in enumerate((((-1.1, 0.0, 5.3), 0.46), ((1.1, 0.0, 5.3), 0.46), ((-0.84, 0.88, 5.0), 0.48), ((0.84, 0.88, 5.0), 0.48), ((0, 1.1, 5.0), 0.46))):
		gem(k, "Head", f"Top{i}", (0, 0.0, 5.84), t, r, flat=0.48, bend=0.13, a=0.5 + 0.05 * (i % 2))
	for i, x in enumerate((-0.6, 0, 0.6)):
		gem(k, "Head", f"Back{i}", (x, 0.84, 5.4), (x * 1.3, 1.1, 4.1), 0.4, flat=0.42, a=0.5, across=(1, 0, 0))
	# the fringe comes to one big point between the eyes
	locks(k, "Bang", None, (((-0.6, -0.72, 5.92), (-1.0, -0.92, 4.78), 0.29), ((-0.46, -0.74, 5.96), (-0.66, -1.0, 5.06), 0.28), ((-0.22, -0.76, 5.98), (-0.3, -1.04, 5.0), 0.28), ((0.22, -0.76, 5.98), (0.3, -1.04, 5.0), 0.28), ((0.46, -0.74, 5.96), (0.66, -1.0, 5.06), 0.28), ((0.6, -0.72, 5.92), (1.0, -0.92, 4.78), 0.29), ((0, -0.76, 5.98), (0, -1.1, 4.56), 0.32)))
	for s in (1, -1):
		gem(k, "Head", f"Burn{s}", (s * 0.94, -0.56, 5.4), (s * 1.0, -0.82, 4.0), 0.24, flat=0.45, a=0.54, across=(1, 0, 0))
		gem(k, "Head", f"Gather{s}", (s * 0.8, 0.6, 5.0), (s * 1.3, 0.3, 4.1), 0.34, flat=0.6, a=0.48)
		# three braids from one low knot: over the shoulder in front, at the side, behind
		_braid(k, f"BraidF{s}", [(s * 1.04, 0.1, 4.36), (s * 1.12, -0.5, 4.16), (s * 1.06, -0.82, 3.7), (s * 0.94, -0.84, 2.86)], 0.17)
		_braid(k, f"BraidS{s}", [(s * 1.06, 0.3, 4.36), (s * 1.4, 0.86, 4.05), (s * 1.6, 0.95, 3.4), (s * 1.66, 0.98, 2.6)], 0.17)
		_braid(k, f"BraidB{s}", [(s * 1.0, 0.5, 4.36), (s * 1.16, 0.92, 4.0), (s * 1.22, 1.0, 3.2), (s * 1.2, 1.02, 2.3)], 0.17)
	horns(k, [(0.62, -0.1, 5.74), (1.0, 0.0, 5.96), (1.3, 0.1, 6.26), (1.45, 0.2, 6.58), (1.5, 0.28, 6.82)], [0.28, 0.26, 0.22, 0.14, 0.02])


def _body(k):
	jacket(k, "navy", seam=None)
	prism(k, T, "Skin", [(-0.94, 4.06), (0.94, 4.06), (0.9, 3.72), (0, 3.6), (-0.9, 3.72)], -0.64, -0.5, "skin", a=0.6, b=0.34)
	collar(k, "navy", 4.16, 4.2, z0=3.94, rx=0.64, ry=0.58, name="Neck")
	prism(k, T, "Rim", [(-0.98, 3.78), (-0.9, 3.78), (0, 3.64), (0.9, 3.78), (0.98, 3.78), (0.98, 3.66), (0, 3.5), (-0.98, 3.66)], -0.68, -0.6, "gold", a=0.56, b=0.42)
	for s in (1, -1):
		block(k, T, f"Strap{s}", s * 0.82, -0.04, 4.1, 3.6, 0.1, 0.66, "navy", ch=0.02, a=0.52, b=0.48)
		prism(k, T, f"Stay{s}", [(s * 0.5, 3.56), (s * 0.58, 3.56), (s * 0.4, 2.4), (s * 0.32, 2.4)], -0.64, -0.58, "gold", a=0.54, b=0.42)
	block(k, T, "Clasp", 0, -0.66, 3.64, 3.36, 0.13, 0.05, "gem", ch=0.04, a=0.6, b=0.42)
	block(k, T, "Belt", 0, 0, 2.4, 2.22, 1.11, 0.63, "gold", ch=0.02, sub=1, a=0.54, b=0.44)
	skirt(k, "white", 1.2, None, flare=0.16)
	# the frilled pink half cape tied at the waist, behind and to the sides, its hem in points
	block(k, T, "Bow", 0, 0.76, 2.56, 2.16, 0.34, 0.1, "pink", ch=0.05, a=0.54, b=0.44)
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		block(k, leg, "FrillB", s * 0.62, 0.8, 2.1, 0.94, 0.62, 0.09, "pink", ch=0.02, flare=0.14, sub=2, jit=0.02, a=0.52, b=0.44)
		block(k, leg, "FrillS", s * 1.2, 0.36, 2.1, 1.0, 0.09, 0.5, "pink", ch=0.02, flare=0.12, sub=2, jit=0.02, a=0.5, b=0.48)
		for i in range(4):
			gem(k, leg, f"FrillP{i}", (s * (0.16 + 0.36 * i), 0.82, 1.2), (s * (0.16 + 0.38 * i), 0.88, 0.7), 0.22, "pink", flat=0.4, a=0.56, across=(1, 0, 0))
		for i in range(3):
			gem(k, leg, f"FrillQ{i}", (s * 1.24, 0.0 + 0.32 * i, 1.24), (s * 1.34, 0.0 + 0.34 * i, 0.78), 0.2, "pink", flat=0.4, a=0.54, across=(0, 1, 0))


def _arm(k, side, s):
	arm, x = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(x, 0, 3.9, 0.42, 0.42), (x, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Shoulder", x, 0, 4.02, 3.3, 0.5, 0.5, "skin", ch=0.08, corner=0.18, a=0.6, b=0.32)
	block(k, arm, "GloveTop", x, 0, 3.46, 3.28, 0.555, 0.555, "gold", ch=0.03, corner=0.18, a=0.54, b=0.44)
	block(k, arm, "Glove", x, 0, 3.36, 1.78, 0.52, 0.52, "glove", ch=0.06, corner=0.18, jit=0.012, mids=(2.6,), a=0.52, b=0.5)


def _scales(k):
	"""The balance, upright from her left fist: a post, a level beam, two hung pans."""
	arm, x, y = "LeftUpperArm", 1.66, -0.8
	block(k, arm, "Post", x, y, 3.86, 1.8, 0.07, 0.07, "gold", ch=0.02, a=0.56, b=0.44)
	block(k, arm, "Foot", x, y, 1.96, 1.74, 0.2, 0.2, "gold", ch=0.05, a=0.56, b=0.44)
	prism(k, arm, "Beam", [(x - 0.62, 3.6), (x - 0.57, 3.72), (x, 3.64), (x + 0.57, 3.72), (x + 0.62, 3.6), (x, 3.5)], y - 0.06, y + 0.06, "gold", a=0.58, b=0.42)
	rod(k, arm, "Finial", [(x, y, 3.8), (x, y, 3.9), (x, y, 4.06), (x, y, 4.22)], [0.05, 0.14, 0.12, 0.02], "gem", n=6, a=0.58, b=0.46)
	for d in (1, -1):
		px = x + d * 0.55
		for e in (1, -1):
			rod(k, arm, f"Cord{d}{e}", [(px, y, 3.62), (px + e * 0.24, y, 3.1)], 0.022, "gold", n=4, a=0.6, b=0.4)
		rod(k, arm, f"Pan{d}", [(px, y, 3.12), (px, y, 3.06), (px, y, 2.94)], [0.32, 0.31, 0.12], "gold", n=8, a=0.58, b=0.44)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	elf_ears(k, out=1.4, up=4.96)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		leg, px = f"{side}UpperLeg", s * 0.53
		k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.46, 0.48), (s * 0.5, 0, 0.1, 0.46, 0.48)], corner=0.1, nc=1)
		boot(k, leg, px, "boot", "sole", top=1.16, cuff="gold")
	_scales(k)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, SKIN_D, ("#38187c", "#7c48cc", "#d4a4ff"), "#3c1c40", "#8a4880", "M50 103Q64 112 82 102", w=35, up=11, dn=9, inner=4, outer=-5, ir=(10, 12), lid=0.28, thick=1.5, wing=6, brow_y=46, brow_t=3.4, tilt=2.6, blush=0.2)
	fill_body(a, SKIN, SKIN_D, "#252d60", "#202644", "#24243e", "#a25a98", "#141830")
