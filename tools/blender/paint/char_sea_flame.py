# Target look for sea_flame (design doc section 5): orange cowboy hat with a bead band and two small faces, wavy black hair,
# freckles, an easy grin, bare chest with a red bead necklace, the large back mark, crossed bars on the left arm, wide belt with
# a gold buckle, black knee shorts, dark boots, an orange elbow guard, a wrist compass and a dagger at the hip.
import math

from atlas import FACES, INK, shade
from leaf_common import ell
from sea_style3 import bake, bare_arm, block, decal, eye, gem, head_base, head_sides, jitter, leg, paint_arm, prism, rod
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f4c89e"
SKIN_D = "#d59a6c"
SKIN_L = "#fcdcb8"
FRECK = "#a8603c"
INKBLUE = "#2c2452"
HAT_FACES = (6, 8, 66, 28)  # px inside Head_T for the two hat faces: first half, second half
DEFAULT = "#101014"
R = Ramps(
	hair=["#050507", "#101016", "#1e1e28", "#34344a", "#50506e"],
	skin=["#b67e52", "#dca878", "#f4c89e", "#fcdcb8"],
	hat=["#8e3c06", "#c85c0a", "#f07c14", "#fa9a34", "#ffbe68"],
	bead=["#660a10", "#a0141c", "#d82c30", "#f46a60"],
	short=["#050507", "#111116", "#20202a", "#383844"],
	belt=["#2a1a0e", "#4e3320", "#745030", "#9c7248"],
	gold=["#94600a", "#d09e18", "#f4cc3c", "#fff09a"],
	boot=["#1a120a", "#2e2014", "#4a3422", "#6c4e36"],
	pad=["#923a04", "#c85c0a", "#f07c14", "#fca040"],
	ball=["#8e9aa8", "#ccd4dc", "#eef2f6", "#ffffff"],
	glass=["#1f5f9e", "#4596d6", "#92d0f4", "#e0f4ff"],
	sheath=["#123026", "#205044", "#347264", "#54968a"],
	steel=["#4a4e58", "#868c98", "#bcc2cc", "#eef0f4"],
)
HAIR = {"colour": "#101014", "locks": []}
PROPS = []


def _hair(k):
	bake(k, k.lathe("Head", "Crown", [(0.9, 5.3, 0.5), (0.95, 5.44, 0.5), (0.8, 5.6, 0.5), (0.4, 5.7, 0.5)], "hair", n=10, at=(0, 0.04, 0), squash=0.9, outline=0), "hair", a=0.5, b=0.4)
	nape = k.tube("Head", "Nape", [(0, 0.42, 5.3, 0.95, 0.49), (0, 0.42, 4.72, 0.97, 0.5), (0, 0.42, 4.5, 0.84, 0.42)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.022)
	bake(k, nape, "hair", a=0.42, b=0.42)
	# a loose wavy fringe to the brows: broad clumps, tips curling out to both sides
	for i, (x0, x1, z, r) in enumerate(((-0.74, -1.02, 4.86, 0.34), (-0.42, -0.54, 4.98, 0.36), (-0.08, -0.02, 4.92, 0.36), (0.3, 0.42, 5.0, 0.36), (0.66, 0.98, 4.84, 0.34))):
		gem(k, "Head", f"Fringe{i}", (x0, -0.72, 5.56), (x1, -0.96, z), r, flat=0.45, twist=0.15 + 0.2 * i, across=(1, 0, 0))
	# waves round the sides and back: each clump bellies out, then tips away
	for s in (1, -1):
		for i, (y0, y1, z, x1, r) in enumerate(((-0.34, -0.42, 4.42, 1.12, 0.3), (-0.04, 0.02, 4.28, 1.2, 0.33), (0.3, 0.4, 4.3, 1.16, 0.33))):
			gem(k, "Head", f"Wave{s}{i}", (s * 0.86, y0, 5.32), (s * x1, y1, z), r, flat=0.45, twist=0.22 + 0.2 * i, across=(0, 1, 0.3))
	for i, (x, x1, z) in enumerate(((-0.66, -0.86, 4.14), (-0.28, -0.3, 4.02), (0.12, 0.2, 4.08), (0.5, 0.72, 4.04), (0.76, 0.98, 4.26))):
		gem(k, "Head", f"Hem{i}", (x, 0.74, 5.04), (x1, 0.98, z), 0.32, flat=0.48, twist=0.3 + 0.1 * i, across=(1, 0, 0))


def _hat(k):
	pivot, tilt, at = (0, 0, 5.5), 7, (0, 0.04, 0)

	def curl(a, ri):
		# the wide brim rolls up at the sides and dips front and back
		return (0.42 * abs(math.cos(a)) ** 2 - 0.08 * abs(math.sin(a)) ** 2) * (max(ri - 1, 0) / 3) ** 1.6

	rows = [(0.96, 5.46, 0.5), (1.04, 5.44, 0.5), (1.3, 5.4, 0.5), (1.62, 5.4, 0.5), (1.86, 5.46, 0.5), (1.9, 5.5, 0.5), (1.58, 5.48, 0.5), (1.05, 5.52, 0.5)]
	o = k.lathe("Head", "Brim", rows, "hat", n=20, at=at, wob=lambda a, ri: curl(a, min(ri, 8 - ri)), outline=0)
	k.tip(o, tilt, pivot)
	bake(k, o, "hat", a=0.52, b=0.5)
	crown = [(1.14, 5.46, 0.5), (1.14, 5.72, 0.5), (1.06, 6.2, 0.5), (0.88, 6.5, 0.5), (0.54, 6.62, 0.5), (0.16, 6.54, 0.5)]
	o = k.lathe("Head", "Crown2", crown, "hat", n=14, at=at, squash=0.96, outline=0)
	k.tip(o, tilt, pivot)
	bake(k, o, "hat", a=0.54, b=0.5, g=0.06)
	# the band of red beads and the two faces on the front of the crown, on the crown's tipped surface
	tilt_r = math.radians(-tilt)

	def on_hat(x, y, z):
		dy, dz = y - pivot[1], z - pivot[2]
		return (x, pivot[1] + dy * math.cos(tilt_r) - dz * math.sin(tilt_r), pivot[2] + dy * math.sin(tilt_r) + dz * math.cos(tilt_r))

	for i in range(16):
		a = 2 * math.pi * i / 16
		k.blob("Head", f"HatBead{i}", on_hat(1.14 * math.cos(a), 0.04 + 1.09 * math.sin(a), 5.72), (0.1, 0.1, 0.1), "bead", v=0.55, rings=3, n=6, outline=0)
	for i, x in enumerate((-0.23, 0.23)):
		bx, by, bw, bh = HAT_FACES
		decal(k, "Head", f"HatFace{i}", on_hat(x, -1.04, 6.0), 0.18, "Head_T", (bx + i * bw / 2, by, bw / 2, bh), "gold")
	# the chin cord
	for s in (1, -1):
		rod(k, "Head", f"Cord{s}", on_hat(s * 0.94, -0.3, 5.42), (0, -0.74, 3.86), 0.03, "bead", n=4, a=0.5, b=0.3)


def _body(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 4.02, 0.92, 0.42), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.2, 1.0, 0.5), (0, 0, 1.94, 0.98, 0.48)], corner=0.1, nc=1)
	# a string of large red beads on the collar line
	for i in range(9):
		# the front: a deep U down the chest, resting on the skin
		u = i / 8 * 2 - 1
		k.blob(t, f"Bead{i}", (0.74 * u, -0.56, 3.5 + 0.46 * u**2), (0.12, 0.09, 0.12), "bead", v=0.5, rings=4, n=8, outline=0)
	for i in range(5):
		# over the shoulders and round the back of the neck
		u = i / 4 * 2 - 1
		k.blob(t, f"BeadB{i}", (0.74 * u, 0.5, 4.0), (0.12, 0.1, 0.1), "bead", v=0.55, rings=4, n=8, outline=0)
	for s in (1, -1):
		k.blob(t, f"BeadS{s}", (s * 0.76, 0.0, 4.02), (0.11, 0.14, 0.1), "bead", v=0.55, rings=4, n=8, outline=0)
	# the wide belt, shorts' seat under it, the buckle, a pouch and a dagger on the viewer's right hip
	block(k, t, "Hips", 0, 0, 2.2, 1.88, 1.03, 0.54, "short", ch=0.02, a=0.46, b=0.56)
	block(k, t, "Belt", 0, 0, 2.4, 2.1, 1.08, 0.6, "belt", ch=0.03, a=0.52, b=0.56)
	block(k, t, "Buckle", 0, -0.61, 2.47, 2.04, 0.24, 0.04, "gold", ch=0.03, a=0.62, b=0.32)
	for pts, nm in (([(-0.1, 2.12), (-0.04, 2.12), (0.03, 2.4), (-0.03, 2.4)], "A0"), ([(0.04, 2.12), (0.1, 2.12), (0.03, 2.4), (-0.03, 2.4)], "A1"), ([(-0.06, 2.2), (0.06, 2.2), (0.06, 2.25), (-0.06, 2.25)], "A2")):
		prism(k, t, nm, pts, -0.67, -0.62, "gold", a=0.22, b=0.12)
	block(k, t, "Pouch", -0.76, -0.6, 2.32, 1.96, 0.22, 0.1, "belt", ch=0.03, a=0.4, b=0.46)
	rod(k, t, "Sheath", (0.88, -0.66, 2.38), (0.8, -0.72, 1.56), 0.09, "sheath", n=6, r1=0.06, a=0.54, b=0.5)
	rod(k, t, "Grip", (0.9, -0.64, 2.68), (0.88, -0.66, 2.4), 0.06, "belt", n=6, a=0.58, b=0.46)
	rod(k, t, "Guard", (0.82, -0.66, 2.41), (0.97, -0.66, 2.39), 0.04, "steel", n=6, a=0.66, b=0.36)


def _left_gear(k):
	"""The orange elbow guard and the wrist compass, both on the character's left."""
	arm = "LeftUpperArm"
	block(k, arm, "ElbowPad", 1.5, 0, 3.16, 2.78, 0.545, 0.545, "pad", ch=0.04, corner=0.18, sub=1, a=0.54, b=0.5)
	block(k, arm, "PadCap", 1.5, 0.48, 3.08, 2.86, 0.3, 0.09, "pad", ch=0.03, a=0.68, b=0.44)
	block(k, arm, "Bracelet", 1.5, 0, 2.5, 2.38, 0.535, 0.535, "ball", ch=0.025, corner=0.2, a=0.56, b=0.36)
	block(k, arm, "CompassBase", 1.5, -0.56, 2.52, 2.36, 0.13, 0.05, "ball", ch=0.02, a=0.5, b=0.3)
	k.blob(arm, "CompassDome", (1.5, -0.62, 2.44), (0.1, 0.07, 0.1), "glass", v=0.62, rings=3, n=8, outline=0)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	px = s * 0.52
	leg(k, side, s)
	block(k, part, "Shorts", px, 0, 1.97, 1.02, 0.49, 0.52, "short", ch=0.03, flare=0.05, corner=0.14, jit=0.022, mids=(1.5,), a=0.46, b=0.56, g=0.1, tone=0.03)
	block(k, part, "ShortsCuff", px, 0, 1.08, 0.88, 0.56, 0.59, "short", ch=0.03, corner=0.14, a=0.56, b=0.56)
	block(k, part, "Shin", px, 0, 0.94, 0.7, 0.45, 0.45, "skin", ch=0.02, corner=0.12, a=0.6, b=0.3)
	block(k, part, "BootTop", px, 0.02, 0.76, 0.28, 0.5, 0.55, "boot", ch=0.05, flare=0.015, corner=0.14, a=0.5, b=0.56)
	block(k, part, "BootCuff", px, 0.02, 0.8, 0.66, 0.52, 0.57, "boot", ch=0.02, a=0.72, b=0.44)
	block(k, part, "Foot", px, -0.14, 0.36, 0.1, 0.51, 0.66, "boot", ch=0.07, corner=0.24, a=0.56, b=0.5)
	block(k, part, "Sole", px, -0.14, 0.12, 0.0, 0.54, 0.72, "short", ch=0.02, a=0.36, b=0.28)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	for s in (1, -1):
		k.blob("Head", f"Ear{s}", (s * 0.93, 0.02, 4.62), (0.09, 0.17, 0.2), "skin", v=0.55, rings=3, n=6, outline=0)
	_hair(k)
	_hat(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		bare_arm(k, side, s)
		_leg(k, s, side)
	_left_gear(k)
	finish()


def _hat_faces(a):
	f = a["Head_T"]
	f.fill("#101014")
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	bx, by, bw, bh = HAT_FACES
	for i, happy in ((0, False), (1, True)):
		cx, cy = (bx + (i + 0.5) * bw / 2) * sx, (by + bh / 2) * sy
		rx, ry = bw / 4 * sx, bh / 2 * sy
		f.path(ell(cx, cy, rx + 1, ry + 1), "#7a4c0a")
		f.path(ell(cx, cy, rx * 0.92, ry * 0.92), "#3a74c8" if happy else "#d03a34")
		f.path(ell(cx - rx * 0.35, cy - ry * 0.25, rx * 0.13, ry * 0.16), "#ffffff")
		f.path(ell(cx + rx * 0.35, cy - ry * 0.25, rx * 0.13, ry * 0.16), "#ffffff")
		bend = 0.75 if happy else 0.15
		y0 = cy + ry * (0.32 if happy else 0.55)
		f.path(f"M{cx - rx * 0.45} {y0}Q{cx} {cy + ry * bend} {cx + rx * 0.45} {y0}", stroke="#ffffff", sw=1.8)


def _back_mark(f, cx, cy, s):
	"""The large back mark: a broad cross behind a round skull, a wide crescent moustache across it."""
	c = INKBLUE
	for rot in (38, -38):
		f.out.append(f'<g transform="translate({cx} {cy}) rotate({rot})">')
		f.path(f"M{-9 * s} {-72 * s}H{9 * s}V{-58 * s}H{15 * s}V{58 * s}H{9 * s}V{72 * s}H{-9 * s}V{58 * s}H{-15 * s}V{-58 * s}H{-9 * s}Z", c)
		f.out.append("</g>")
	f.path(ell(cx, cy - 4 * s, 34 * s, 33 * s), c)
	f.path(f"M{cx - 19 * s} {cy + 20 * s}H{cx + 19 * s}V{cy + 38 * s}H{cx - 19 * s}Z", c)
	f.path(ell(cx - 13 * s, cy - 10 * s, 9 * s, 11 * s), SKIN)
	f.path(ell(cx + 13 * s, cy - 10 * s, 9 * s, 11 * s), SKIN)
	f.path(f"M{cx} {cy + 1 * s}L{cx - 4 * s} {cy + 10 * s}H{cx + 4 * s}Z", SKIN)
	for x in (-10, 0, 10):
		f.path(f"M{cx + x * s} {cy + 25 * s}V{cy + 37 * s}", stroke=SKIN, sw=2.2)
	f.path(f"M{cx - 62 * s} {cy - 2 * s}Q{cx - 30 * s} {cy + 24 * s} {cx} {cy + 13 * s}Q{cx + 30 * s} {cy + 24 * s} {cx + 62 * s} {cy - 2 * s}Q{cx + 34 * s} {cy + 38 * s} {cx} {cy + 22 * s}Q{cx - 34 * s} {cy + 38 * s} {cx - 62 * s} {cy - 2 * s}Z", c, stroke=SKIN, sw=1.6)


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=28)
	for s, x in ((-1, 38), (1, 92)):
		eye(f, x, 63, s, "#2c221c", "#0a0706", "#6c5848", w=30, up=19, down=11, inner=5, outer=-5, wing=3.5, lid=5.5, ry=12.5)
		# gentle arched brows, freckles across the cheeks
		ib, ob = 65 + s * 11, 65 + s * 44
		f.path(f"M{ib} 42Q{65 + s * 27} 32 {ob} 38L{ob} 41Q{65 + s * 27} 36 {ib} 46Z", "#141014")
		for dx, y, r in ((30, 83, 1.5), (39, 80, 1.6), (47, 85, 1.5), (35, 90, 1.5)):
			f.path(ell(65 + s * dx, y, r * 0.8, r), FRECK)
	f.soft("M60 80L65 74L70 80Q65 85 60 80Z", SKIN_D, 0.75, 1)
	f.path("M60 84Q65 86.5 70 84", stroke=shade(SKIN, 0.5), sw=1.1)
	# an easy open grin
	f.path("M40 98Q65 104 90 96Q87 114 65 116Q45 114 40 98Z", "#3a1414", stroke="#3a1414", sw=1.3)
	f.path("M42 99.5Q65 105 88 97.5L86 105Q65 111 44 106.5Z", "#fbfbf6")
	f.path("M40 98Q37.5 96 36.5 93.5", stroke=INK, sw=1.4)
	f.path("M90 96Q92.5 94 93.5 91", stroke=INK, sw=1.4)
	head_sides(a, SKIN, SKIN_D)
	a["Head_B"].fill("#101014")
	_hat_faces(a)
	# the chest: soft, plain shading
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M20 20H180L170 170H30Z", SKIN_L, 0.4, 8)
	f.soft("M-5-5H205V18Q100 34 -5 18Z", SKIN_D, 0.7, 5)
	f.soft("M-5-5H14L20 205H-5Z", SKIN_D, 0.6, 5)
	f.soft("M205-5H186L180 205H205Z", SKIN_D, 0.7, 5)
	crease = shade(SKIN, 0.74)
	f.path("M58 80Q78 90 96 84", stroke=crease, sw=2.6, opacity=0.8, blur=1)
	f.path("M142 80Q122 90 104 84", stroke=crease, sw=2.6, opacity=0.8, blur=1)
	f.path("M100 86V150", stroke=crease, sw=1.8, opacity=0.8, blur=1)
	f.soft("M-5 160H205V205H-5Z", SKIN_D, 0.5, 3)
	f = a["Torso_B"]
	f.fill(SKIN)
	f.soft("M-5-5H205V16H-5Z", SKIN_D, 0.6, 4)
	f.soft("M-5 160H205V205H-5Z", SKIN_D, 0.45, 4)
	_back_mark(f, 100, 92, 1.25)
	for n in ("Torso_L", "Torso_R"):
		a[n].fill(SKIN)
		a[n].soft("M-5 160H105V205H-5Z", SKIN_D, 0.5, 4)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(shade(SKIN, 0.8))
	for side, s in (("Left", 1), ("Right", -1)):
		for key, dark in (("F", 0.0), ("O", 0.2), ("I", 0.45), ("B", 0.35)):
			paint_arm(a[f"{side}Arm_{key}"], SKIN, SKIN_D, SKIN_L, dark)
		for key in ("Arm_T", "Arm_Bo"):
			a[f"{side}{key}"].fill(SKIN)
	# the crossed bars on the character's left upper arm, turned to the viewer
	f = a["LeftArm_F"]
	for x in (28, 42, 56, 70):
		f.path(f"M{x} 34V68", stroke=INKBLUE, sw=7)
	f.path("M38 74L58 26", stroke="#c8202c", sw=4.5)
