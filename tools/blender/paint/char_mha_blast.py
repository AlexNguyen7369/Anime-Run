# Target look for mha_blast: pale ash-blond spike burst, narrow red eyes in a black eye mask with orange edges, scowl, black
# high-neck top with an orange chevron strap, huge grenade gauntlets, belt with pouches, knee pads, black and orange boots.
from mha_style3 import anime_eye, bake, block, brow_block, core, gem, hand, head_faces, nose, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f8d8c0"
SKIN_D = "#e0a884"
DEFAULT = "#1c1c1c"
R = Ramps(
	hair=["#a08a50", "#c8b070", "#e6d48e", "#f4e6ac", "#fff6d4"],
	skin=["#c08860", "#e8b28c", "#f8d8c0", "#ffe8d6"],
	black=["#0a0a0c", "#17171a", "#27272c", "#3c3c44"],
	orange=["#9a4c08", "#cc6c10", "#f28c1e", "#ffae4a"],
	green=["#26381e", "#3a5230", "#4a6a3a", "#68905a"],
	yellow=["#9a7410", "#cc9c1c", "#f2c230", "#ffe070"],
	steel=["#4a4f58", "#7c828c", "#a8aeb8", "#dde0e6"],
)
HAIR = {"colour": "#F2E2A0", "locks": []}
PROPS = []


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.56, 0.5), (0.92, 5.9, 0.5), (0.5, 6.2, 0.5), (0.14, 6.28, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.96, outline=0)
	bake(k, dome, "hair", a=0.46, b=0.32)
	root = (0, 0.08, 5.55)

	def out(tip, f=0.2):
		return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))

	# the explosive silhouette: long wedges straight out and up, wider than the shoulders' top line
	burst = (((-1.62, 0.05, 5.5), 0.36), ((-1.56, 0.1, 6.14), 0.38), ((-1.14, 0.12, 6.68), 0.42), ((-0.56, 0.18, 7.06), 0.44), ((0.08, 0.2, 7.24), 0.46), ((0.66, 0.18, 7.02), 0.44), ((1.2, 0.12, 6.66), 0.42), ((1.6, 0.1, 6.1), 0.38), ((1.64, 0.05, 5.46), 0.36), ((0.0, 1.5, 6.3), 0.46), ((-0.9, 1.34, 6.16), 0.44), ((0.9, 1.34, 6.16), 0.44), ((-1.26, 1.1, 5.6), 0.38), ((1.26, 1.1, 5.6), 0.38), ((0.0, 1.46, 5.5), 0.42), ((-0.56, 1.2, 6.72), 0.4), ((0.56, 1.2, 6.72), 0.4))
	for i, (tip, r) in enumerate(burst):
		gem(k, "Head", f"Burst{i}", out(tip), tip, r, bend=0.05, twist=0.3 + 0.13 * i % 0.5)
	mid = (((-1.08, -0.42, 6.0), 0.36), ((-0.62, -0.6, 6.56), 0.4), ((0.02, -0.66, 6.72), 0.42), ((0.66, -0.6, 6.52), 0.4), ((1.1, -0.42, 5.96), 0.36))
	for i, (tip, r) in enumerate(mid):
		gem(k, "Head", f"Mid{i}", out(tip, 0.3), tip, r, bend=0.05, twist=0.5 + 0.17 * i)
	# jagged fringe, sharp and short, over the mask's top
	for i, (x, ztip, r) in enumerate(((-0.78, 4.98, 0.26), (-0.42, 5.1, 0.28), (-0.06, 4.96, 0.3), (0.3, 5.12, 0.28), (0.72, 4.98, 0.27))):
		gem(k, "Head", f"Fringe{i}", (x * 0.92, -0.62, 5.8), (x * 1.06, -0.95, ztip), r, flat=0.5, twist=0.2 + 0.3 * i % 0.6)
	for s in (1, -1):
		for i, (y, z0, r) in enumerate(((-0.48, 4.62, 0.26), (-0.1, 4.54, 0.28), (0.28, 4.6, 0.3))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.86, y, 5.5), (s * 1.08, y + 0.05, z0), r, flat=0.5, twist=0.25 + 0.2 * i, across=(0, 1, 0))
	block(k, "Head", "Nape", 0, 0.42, 5.72, 4.5, 0.98, 0.5, "hair", ch=0.08, corner=0.22, jit=0.03, sub=1, a=0.44, b=0.36)
	for i, x in enumerate((-0.66, -0.22, 0.22, 0.66)):
		gem(k, "Head", f"NapeS{i}", (x, 0.74, 5.05), (x * 1.1, 1.02, 4.24 + 0.06 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0))


def _top(k):
	t = "UpperTorso"
	block(k, t, "Body", 0, 0, 3.98, 2.0, 1.06, 0.57, "black", ch=0.08, flare=0.02, jit=0.03, mids=(3.4, 2.7), a=0.5, b=0.6, tone=0.04)
	# high collar, closed to the neck, orange rim
	block(k, t, "Collar", 0, -0.02, 4.16, 3.9, 0.72, 0.54, "black", ch=0.04, corner=0.3, a=0.52, b=0.6)
	block(k, t, "CollarRim", 0, -0.02, 3.98, 3.9, 0.76, 0.58, "orange", ch=0.015, corner=0.3, a=0.56)
	# the strap, front and back: two chevrons, noses pointing in, a gap between them
	for y, d in ((-0.635, 0.07), (0.565, 0.07)):
		for s in (1, -1):
			strip(k, t, f"XU{s}{y}", (s * 0.96, 3.86), (s * 0.28, 3.18), 0.12, y, d, "orange", a=0.56)
			strip(k, t, f"XL{s}{y}", (s * 0.28, 3.18), (s * 0.96, 2.5), 0.12, y, d, "orange", a=0.56)
	block(k, t, "Belt", 0, 0, 2.44, 2.14, 1.1, 0.62, "black", ch=0.04, a=0.62, b=0.6)
	block(k, t, "Buckle", 0, -0.64, 2.42, 2.16, 0.2, 0.03, "steel", ch=0.02, a=0.5)
	for i, x in enumerate((-0.86, -0.54, 0.54, 0.86)):
		block(k, t, f"Pouch{i}", x, -0.67, 2.46, 2.1, 0.145, 0.1, "green", ch=0.03, a=0.56)
		block(k, t, f"PouchBand{i}", x, -0.67, 2.32, 2.24, 0.15, 0.105, "yellow", ch=0.01, a=0.58)
	block(k, t, "Hips", 0, 0, 2.14, 1.88, 1.08, 0.585, "black", ch=0.02, a=0.5, b=0.6)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	# bare upper arm under a broad black shoulder piece
	block(k, arm, "Upper", ax, 0, 3.7, 3.1, 0.5, 0.5, "skin", ch=0.05, a=0.58, b=0.32)
	block(k, arm, "Shoulder", ax, 0, 4.02, 3.6, 0.53, 0.53, "black", ch=0.1, corner=0.18, jit=0.02, a=0.5, b=0.6)
	# the grenade gauntlet, wide on the outside so it clears the torso; hand inside
	gx = s * 1.68
	block(k, arm, "Shell", gx, 0, 3.2, 2.1, 0.62, 0.72, "green", ch=0.14, corner=0.3, jit=0.025, sub=1, mids=(2.85, 2.45), a=0.5, b=0.62, g=0.12)
	block(k, arm, "Cap", gx, 0, 3.32, 3.1, 0.46, 0.54, "black", ch=0.06, corner=0.3, a=0.5, b=0.55)
	for i, z in enumerate((2.92, 2.42)):
		block(k, arm, f"Bnd{i}", gx, 0, z, z - 0.14, 0.645, 0.745, "yellow", ch=0.02, corner=0.3, a=0.56)
	block(k, arm, "Muzzle", gx, 0, 2.18, 1.98, 0.5, 0.58, "black", ch=0.05, corner=0.3, a=0.5)
	# the pin: a steel lever on the outside and a ring on top
	block(k, arm, "Lever", s * 2.34, 0, 3.14, 2.28, 0.06, 0.14, "steel", ch=0.02, a=0.5)
	block(k, arm, "Pin", gx, -0.62, 3.5, 3.14, 0.05, 0.05, "steel", ch=0.01, a=0.6)
	for j, (dx, dz) in enumerate(((0.13, 0.0), (-0.13, 0.0), (0.0, 0.13), (0.0, -0.13))):
		block(k, arm, f"Ring{j}", gx + dx, -0.62, 3.62 + dz + 0.05, 3.62 + dz - 0.05, 0.05 if dx else 0.09, 0.03, "steel", ch=0.008, a=0.6)
	hand(k, arm, ax, "black", z1=2.3)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 0.9, 0.525, 0.57, "black", ch=0.04, flare=0.04, corner=0.16, jit=0.05, mids=(1.45,), a=0.5, b=0.6, tone=0.05)
	block(k, leg, "Stripe", s * 1.04, 0, 1.8, 0.96, 0.03, 0.2, "orange", ch=0.008, a=0.56)
	block(k, leg, "Knee", x, -0.36, 1.32, 0.96, 0.4, 0.28, "black", ch=0.07, corner=0.2, a=0.68, b=0.55)
	block(k, leg, "KneeRim", x, -0.61, 1.34, 1.27, 0.34, 0.035, "orange", ch=0.01, a=0.55)
	block(k, leg, "Shaft", x, 0.02, 0.98, 0.14, 0.54, 0.6, "black", ch=0.05, flare=0.015, a=0.54, b=0.55)
	block(k, leg, "BootBand", x, 0.02, 0.8, 0.62, 0.56, 0.62, "orange", ch=0.02, a=0.54)
	block(k, leg, "Toe", x, -0.28, 0.52, 0.14, 0.55, 0.52, "black", ch=0.09, corner=0.25, a=0.56, b=0.55)
	block(k, leg, "ToeCap", x, -0.68, 0.42, 0.14, 0.42, 0.14, "orange", ch=0.05, corner=0.25, a=0.56)
	block(k, leg, "Sole", x, -0.16, 0.17, 0.0, 0.57, 0.76, "black", ch=0.03, a=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _mask(f):
	"""The eye mask: a wide black band with wings sweeping up to the temples, orange edge."""
	shape = "M-5 30L24 42Q48 40 65 52Q82 40 106 42L135 30V58Q112 78 88 76Q72 76 65 66Q58 76 42 76Q18 78 -5 58Z"
	f.path(shape, "#f28c1e")
	f.out.append('<g transform="translate(65 54) scale(0.97 0.86) translate(-65 -54)">')
	f.path(shape, "#141416")
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = head_faces(a, SKIN, SKIN_D, "#F2E2A0")
	_mask(f)
	f.skin = "#141416"
	for s, x in ((-1, 37), (1, 93)):
		anime_eye(f, x, 60, s, "#d82a1c", w=32, up=7, dn=8, lift=10, lt=2.6, wing=3, ir=9, pupil=0.3, low="#141416")
		brow_block(f, s, 10, 44, 54, 36, 5, "#3a3020")
	f.skin = SKIN
	nose(f, SKIN_D, 84)
	# the scowl: teeth bared at one side, corners pulled down
	shape = "M42 106Q50 97 65 98Q80 97 88 106Q80 104 65 106Q50 104 42 106Z"
	f.path(shape, "#fbfbf6", stroke="#2a1410", sw=1.8)
	for x in (52, 59, 65, 71, 78):
		f.path(f"M{x} 98V106", stroke="#7a6a68", sw=0.7)
	for n in ("Head_L", "Head_R"):
		a[n].path("M-5 36H125V66H-5Z", "#141416")
