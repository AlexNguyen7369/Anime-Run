# Target look for sea_navigator (design doc section 5): long wavy orange hair to the waist, big brown eyes, side-swept fringe,
# a fully covering green top with white trim (modest-clothing rule), blue jeans, brown belt, red heeled sandals, a wrist compass,
# the pinwheel-and-tangerine tattoo on the left upper arm, and a three-section blue staff slung across the back.
from atlas import INK, shade
from leaf_common import ell
from sea_style3 import bake, bare_arm, block, eye, gem, head_base, head_sides, jitter, leg, paint_arm, prism, rod
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#fcd8ba"
SKIN_D = "#e6ab86"
SKIN_L = "#ffe8d2"
ORANGE = "#f08a2a"
TATTOO = "#2e6cc0"
DEFAULT = "#3aa65a"
R = Ramps(
	hair=["#8e3c06", "#c8600e", "#ee8420", "#f8a03c", "#ffc46c"],
	skin=["#cc8e68", "#eeb48e", "#fcd8ba", "#ffe8d2"],
	top=["#14602e", "#208244", "#32a65a", "#54c678", "#86e0a0"],
	white=["#8e9aa2", "#d4dce0", "#f4f6f8", "#ffffff"],
	jean=["#142f58", "#234c84", "#3a6eac", "#5a92cc", "#86b6e4"],
	belt=["#2c1a0c", "#553420", "#7c5230", "#a47648"],
	gold=["#94600a", "#d09e18", "#f4cc3c", "#fff09a"],
	sandal=["#680e16", "#a01c24", "#cc3238", "#e8585a"],
	staff=["#123a6c", "#2064a4", "#4490cc", "#78b8e8"],
	ball=["#8e9aa8", "#ccd4dc", "#eef2f6", "#ffffff"],
	glass=["#1f5f9e", "#4596d6", "#92d0f4", "#e0f4ff"],
)
HAIR = {"colour": ORANGE, "locks": []}
PROPS = []


def _hair(k):
	bake(k, k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.02, 5.5, 0.5), (1.0, 5.8, 0.5), (0.66, 6.06, 0.5), (0.16, 6.14, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.95, outline=0), "hair", a=0.52, b=0.36)
	# the long mass falls behind the shoulders, between the arms, to the waist
	back = k.tube("Head", "Mass", [(0, 0.44, 5.3, 0.98, 0.5), (0, 0.5, 4.5, 1.0, 0.46), (0, 0.6, 3.5, 0.96, 0.38), (0, 0.62, 2.9, 0.9, 0.32), (0, 0.62, 2.62, 0.78, 0.26)], "hair", corner=0.3, nc=1, sub=2, outline=0)
	jitter(back, 0.035)
	bake(k, back, "hair", a=0.42, b=0.42, g=0.12)
	# wide wavy clumps over the back: each one swings the other way
	for i, (x, dx, z0, z1, r) in enumerate(((-0.62, -0.2, 5.4, 3.6, 0.42), (0.0, 0.16, 5.5, 3.4, 0.44), (0.62, 0.2, 5.4, 3.6, 0.42), (-0.66, 0.16, 3.92, 2.42, 0.4), (-0.22, -0.16, 3.8, 2.28, 0.42), (0.24, 0.18, 3.8, 2.3, 0.42), (0.68, -0.14, 3.92, 2.44, 0.4))):
		gem(k, "Head", f"Wave{i}", (x, 0.88, z0), (x + dx, 1.0, z1), r, flat=0.42, twist=0.2 + 0.13 * i, across=(1, 0, 0))
	# the top: big swept planes from a parting on the viewer's right
	for i, (b, t, r) in enumerate((((0.3, -0.34, 5.76), (-0.98, -0.5, 5.9), 0.38), ((0.32, 0.12, 5.82), (-1.1, 0.14, 5.62), 0.42), ((0.42, -0.2, 5.76), (1.14, -0.32, 5.52), 0.36), ((0.36, 0.5, 5.72), (1.1, 0.76, 5.28), 0.4), ((0.26, 0.5, 5.72), (-1.04, 0.8, 5.28), 0.4))):
		gem(k, "Head", f"Top{i}", b, t, r, flat=0.55, twist=0.25 + 0.14 * i, bend=0.05)
	# side-swept fringe: leaves both eyes clear, its long point runs to the viewer's left
	for i, (b, t, r) in enumerate((((0.34, -0.72, 5.74), (-0.42, -0.96, 5.1), 0.32), ((0.12, -0.72, 5.72), (-0.94, -0.94, 4.9), 0.34), ((0.36, -0.72, 5.72), (0.86, -0.96, 5.0), 0.28), ((0.42, -0.72, 5.74), (0.26, -0.95, 5.12), 0.24))):
		gem(k, "Head", f"Fringe{i}", b, t, r, flat=0.45, twist=0.16 + 0.12 * i, across=(1, 0, 0.2))
	# locks framing the face, a wave in each: upper falls in, lower swings out over the collarbone
	for s in (1, -1):
		gem(k, "Head", f"FrameU{s}", (s * 0.92, -0.46, 5.5), (s * 0.98, -0.62, 4.2), 0.3, flat=0.5, twist=0.18, across=(1, 0, 0))
		gem(k, "Head", f"FrameL{s}", (s * 1.0, -0.56, 4.8), (s * 0.78, -0.68, 3.14), 0.36, flat=0.42, twist=0.34, across=(1, 0, 0))
		gem(k, "Head", f"FrameB{s}", (s * 0.98, -0.3, 4.5), (s * 1.04, -0.62, 3.3), 0.3, flat=0.42, twist=0.5, across=(1, 0, 0))
		gem(k, "Head", f"Side{s}", (s * 0.98, -0.06, 5.34), (s * 1.0, 0.02, 3.98), 0.3, flat=0.42, twist=0.26, across=(0, 1, 0))
		gem(k, "Head", f"SideL{s}", (s * 0.98, 0.26, 5.0), (s * 0.96, 0.54, 3.5), 0.3, flat=0.42, twist=0.4, across=(0, 1, 0))
	# small gold earrings
	for s in (1, -1):
		k.blob("Head", f"Earring{s}", (s * 0.96, -0.28, 4.42), (0.05, 0.05, 0.08), "gold", v=0.6, rings=3, n=6, outline=0)


def _top(k):
	t = "UpperTorso"
	block(k, t, "Top", 0, 0, 3.99, 2.2, 1.05, 0.56, "top", ch=0.05, flare=0.01, jit=0.012, mids=(3.2,), a=0.5, b=0.48, g=0.12, tone=0.025)
	# white trim: a closed round neck, the hem
	block(k, t, "Neck", 0, 0, 4.09, 3.93, 0.74, 0.58, "white", ch=0.03, corner=0.2, a=0.6, b=0.38)
	block(k, t, "Hem", 0, 0, 2.3, 2.16, 1.08, 0.59, "white", ch=0.025, a=0.6, b=0.38)
	block(k, t, "Hips", 0, 0, 2.2, 1.88, 1.05, 0.55, "jean", ch=0.02, a=0.46, b=0.5)
	block(k, t, "Belt", 0, 0, 2.17, 1.96, 1.09, 0.6, "belt", ch=0.025, a=0.52, b=0.5)
	block(k, t, "Buckle", 0, -0.61, 2.2, 1.93, 0.17, 0.035, "gold", ch=0.02, a=0.62, b=0.32)


def _staff(k):
	"""Three linked blue sections with white ball ends, diagonal over the hair, close to the back."""
	t = "UpperTorso"
	a, b = (-1.72, 1.08, 1.0), (1.56, 1.08, 4.36)
	for i in range(3):
		p0 = tuple(a[j] + (b[j] - a[j]) * (i + 0.04) / 3 for j in range(3))
		p1 = tuple(a[j] + (b[j] - a[j]) * (i + 0.96) / 3 for j in range(3))
		rod(k, t, f"Staff{i}", p0, p1, 0.07, "staff", n=6, a=0.56, b=0.42)
	for i in (1, 2):
		c = tuple(a[j] + (b[j] - a[j]) * i / 3 for j in range(3))
		k.blob(t, f"Link{i}", c, (0.09, 0.09, 0.09), "ball", v=0.55, rings=3, n=6, outline=0)
	for i, c in enumerate((a, b)):
		k.blob(t, f"Ball{i}", c, (0.14, 0.14, 0.14), "ball", v=0.55, rings=4, n=8, outline=0)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	bare_arm(k, side, s)
	block(k, arm, "Sleeve", ax, 0, 4.04, 3.62, 0.525, 0.525, "top", ch=0.1, corner=0.18, sub=1, a=0.5, b=0.48, g=0.12)
	block(k, arm, "SleeveTrim", ax, 0, 3.66, 3.54, 0.54, 0.54, "white", ch=0.025, corner=0.18, a=0.6, b=0.38)


def _compass(k):
	"""The wrist compass on the character's left: a band and a small glass dome."""
	arm = "LeftUpperArm"
	block(k, arm, "Bracelet", 1.5, 0, 2.66, 2.52, 0.54, 0.54, "ball", ch=0.025, corner=0.2, a=0.56, b=0.36)
	block(k, arm, "CompassBase", 1.5, -0.56, 2.68, 2.5, 0.13, 0.05, "ball", ch=0.02, a=0.5, b=0.3)
	k.blob(arm, "CompassDome", (1.5, -0.62, 2.59), (0.1, 0.07, 0.1), "glass", v=0.62, rings=3, n=8, outline=0)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	px = s * 0.52
	leg(k, side, s)
	block(k, part, "Jeans", px, 0, 1.97, 0.44, 0.47, 0.5, "jean", ch=0.03, flare=0.05, corner=0.14, jit=0.015, mids=(1.16,), a=0.46, b=0.5, g=0.12, tone=0.025)
	# pocket seam, side seam, a rolled hem
	prism(k, part, "Pocket", [(s * 0.2, 1.9), (s * 0.84, 1.9), (s * 0.84, 1.52)], -0.545, -0.48, "jean", a=0.72, b=0.26)
	block(k, part, "JeansHem", px, 0, 0.52, 0.36, 0.53, 0.56, "jean", ch=0.025, corner=0.14, a=0.6, b=0.44)
	# the foot on a red heeled sandal: skin instep and toes, straps over them, a low sole and a block heel
	block(k, part, "Foot", px, -0.2, 0.34, 0.12, 0.46, 0.5, "skin", ch=0.06, corner=0.2, a=0.6, b=0.32)
	for i, dx in enumerate((-0.33, -0.11, 0.11, 0.33)):
		block(k, part, f"Toe{i}", px + dx, -0.72, 0.25, 0.1, 0.095, 0.1, "skin", ch=0.03, corner=0.25, a=0.52, b=0.32)
	block(k, part, "Strap", px, -0.42, 0.36, 0.24, 0.48, 0.09, "sandal", ch=0.02, a=0.56, b=0.5)
	block(k, part, "Ankle", px, 0.06, 0.38, 0.28, 0.48, 0.42, "sandal", ch=0.02, a=0.56, b=0.5)
	block(k, part, "Sole", px, -0.22, 0.11, 0.0, 0.5, 0.66, "sandal", ch=0.02, a=0.46, b=0.42)
	block(k, part, "Heel", px, 0.24, 0.26, 0.0, 0.4, 0.2, "sandal", ch=0.02, a=0.42, b=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	for s in (1, -1):
		k.blob("Head", f"Ear{s}", (s * 0.93, 0.02, 4.62), (0.09, 0.17, 0.2), "skin", v=0.55, rings=3, n=6, outline=0)
	k.reshape("UpperTorso", "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	_hair(k)
	_top(k)
	_staff(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	_compass(k)
	finish()


def _tattoo(f, cx, cy):
	"""A three-bladed fan and a pointed fruit beside it, in blue."""
	for i in range(3):
		f.out.append(f'<g transform="translate({cx} {cy}) rotate({i * 120})">')
		f.path("M0 0Q-9 -9 -3 -18Q9 -17 10 -7Q4 -6 0 0Z", TATTOO)
		f.out.append("</g>")
	f.path(ell(cx, cy, 2.4), "#f4f8ff")
	f.path("M" + f"{cx} {cy}L{cx} {cy + 22}", stroke=TATTOO, sw=2.4)
	tx, ty = cx + 26, cy + 14
	# pointed at both ends, cut by one seam, two small leaves on top
	f.path(f"M{tx} {ty - 13}Q{tx + 15} {ty} {tx} {ty + 13}Q{tx - 15} {ty} {tx} {ty - 13}Z", TATTOO)
	f.path(f"M{tx} {ty - 8}Q{tx + 9.5} {ty} {tx} {ty + 8}Q{tx - 9.5} {ty} {tx} {ty - 8}Z", "#f7d0b0")
	f.path(f"M{tx} {ty - 9}V{ty + 9}", stroke=TATTOO, sw=2)
	for e in (-1, 1):
		f.path(f"M{tx} {ty - 12}L{tx + e * 11} {ty - 19}L{tx + e * 8} {ty - 11}Z", TATTOO)


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=24)
	f.path("M-5-5H38L16 34L-5 52Z", "#c8600e")
	f.path("M135-5H92L114 34L135 52Z", "#c8600e")
	f.soft("M14 72Q28 66 36 80Q26 92 14 84Z", "#ffb090", 0.5, 3)
	f.soft("M116 72Q102 66 94 80Q104 92 116 84Z", "#ffb090", 0.5, 3)
	for s, x in ((-1, 36), (1, 94)):
		eye(f, x, 62, s, "#a0662c", "#42240c", "#e0b478", w=33, up=27, down=16, inner=6, outer=-9, wing=5.5, lid=7, ry=16, lash="#1c1016")
		# lashes at the outer corner; thin arched brows
		ox = 65 + s * 45
		f.path(f"M{ox} 50L{ox + s * 7} 45L{ox + s * 2} 54Z", "#1c1016")
		f.path(f"M{ox - s * 2} 55L{ox + s * 7} 53L{ox + s * 1} 59Z", "#1c1016")
		ib, ob = 65 + s * 12, 65 + s * 46
		f.path(f"M{ib} 34Q{65 + s * 28} 25 {ob} 32Q{65 + s * 28} 29 {ib} 37Z", "#b05c14")
	f.soft("M60 80L65 74L70 80Q65 84 60 80Z", SKIN_D, 0.7, 1)
	f.path("M61 84Q65 86 69 84", stroke=shade(SKIN, 0.5), sw=1)
	# a bright small smile with a line of teeth
	f.path("M49 100Q65 104 81 100Q78 113 65 114Q52 113 49 100Z", "#5a1a1e", stroke="#5a1a1e", sw=1)
	f.path("M51 101Q65 104.5 79 101L77.5 106Q65 108.5 52.5 106Z", "#fffdf8")
	f.path("M49 100Q47 98.5 46 97", stroke=INK, sw=1.3)
	f.path("M81 100Q83 98.5 84 97", stroke=INK, sw=1.3)
	head_sides(a, SKIN, SKIN_D)
	for n in ("Head_B", "Head_T"):
		a[n].fill("#c8600e")
	for side, s in (("Left", 1), ("Right", -1)):
		for key, dark in (("F", 0.0), ("O", 0.2), ("I", 0.45), ("B", 0.35)):
			paint_arm(a[f"{side}Arm_{key}"], SKIN, SKIN_D, SKIN_L, dark)
		for key in ("Arm_T", "Arm_Bo"):
			a[f"{side}{key}"].fill(SKIN)
		# the leg block's heel shows between sandal straps
		for key in ("F", "B", "O", "I", "Bo"):
			a[f"{side}Leg_{key}"].fill(SKIN_D)
	# the tattoo on the character's left upper arm, turned to the viewer
	_tattoo(a["LeftArm_F"], 38, 62)
