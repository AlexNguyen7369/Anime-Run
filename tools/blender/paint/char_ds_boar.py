# Target look for ds_boar (design doc section 5): a full boar-head mask in grey-blue fur with a pink snout, tusks and hollow eyes,
# a plain bare block torso with no anatomy drawn on it, a tan fur belt, wide dark trousers, black and white diamond wraps, bare feet,
# and a saw-edged blade below each hand.
from ds_style3 import art_uv, bake, block, core_leg, gem, hand, rect_d, spread, studs, xf
from leaf_common import ell
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f6d6bc"
SKIN_D = "#e2b596"
FUR = "#6e7f92"
DEFAULT = SKIN
R = Ramps(
	fur=["#2c3644", "#465668", "#667a8e", "#8ca0b4"],
	dark=["#14161e", "#20242e", "#2e323e"],
	snout=["#b07e80", "#d49ca0", "#ecbcbc", "#f8d8d6"],
	ivory=["#b4ac96", "#dcd6c2", "#f4f0e2", "#ffffff"],
	inner=["#a06a78", "#c88c98", "#e0aab2"],
	skin=["#c98a64", "#eab48c", "#f6d6bc", "#ffe8d2"],
	uni=["#141a26", "#222c3c", "#334054", "#47566c"],
	pelt=["#46321e", "#6c5030", "#937448", "#b89a66"],
	cord=["#2c3644", "#465668", "#667a8e"],
	blade=["#4e5e70", "#7a8a9c", "#a4b2c0", "#d4dce4"],
	grip=["#1a2230", "#2c3a50", "#40526c"],
)
HAIR = {"colour": FUR, "locks": []}
PROPS = []
DIAMONDS = (-0.6, 0.6, 1.2, 2.2)  # the leg-wrap swatch, in a leg face hidden under the trousers
HEAD_ROWS = [(0, 0, 3.98, 0.72, 0.66), (0, 0, 4.14, 0.94, 0.82), (0, 0, 4.42, 0.98, 0.86), (0, 0, 5.3, 0.98, 0.86), (0, 0, 5.56, 0.86, 0.76), (0, 0, 5.68, 0.6, 0.56)]


def _mask(k):
	h = "Head"
	# the snout: a tapered block out of the face, a pink end with two nostrils
	sp = (0, -0.72, 4.56)
	block(k, h, "Snout", 0, sp[1], sp[2] + 0.72, sp[2], 0.42, 0.26, "fur", ch=0.06, flare=0.1, rot=(sp, 90, 0, 0), a=0.5, b=0.56)
	np_ = (0, -1.4, 4.56)
	block(k, h, "Nose", 0, np_[1], np_[2] + 0.14, np_[2], 0.42, 0.28, "snout", ch=0.05, corner=0.35, rot=(np_, 90, 0, 0), a=0.6, b=0.44)
	for s in (1, -1):
		block(k, h, f"Nostril{s}", s * 0.17, -1.54, 4.64, 4.46, 0.075, 0.016, "dark", ch=0.005, corner=0.6, a=0.5)
	# the mouth under it and the jaw, the tusks curling up past the snout
	block(k, h, "Mouth", 0, -1.02, 4.3, 4.08, 0.46, 0.2, "dark", ch=0.02, a=0.5)
	block(k, h, "Jaw", 0, -0.96, 4.1, 3.94, 0.5, 0.26, "fur", ch=0.05, a=0.44, b=0.5)
	for s in (1, -1):
		gem(k, h, f"Tusk{s}", (s * 0.42, -1.12, 4.14), (s * 0.68, -1.3, 4.7), 0.11, ramp="ivory", flat=0.9, twist=0.2, a=0.6, b_=0.4, across=(1, 0, 0))
		# heavy brow ridge above the painted hollow eye
		block(k, h, f"Brow{s}", s * 0.48, -0.88, 5.12, 4.98, 0.4, 0.08, "fur", ch=0.03, rot=((s * 0.48, -0.88, 5.05), 0, s * -18, 0), a=0.42, b=0.5)
		# ears: a broad fur spike with a pink inner plane
		gem(k, h, f"Ear{s}", (s * 0.66, 0.0, 5.5), (s * 1.24, -0.04, 6.2), 0.38, ramp="fur", flat=0.5, twist=0.2, across=(0, 1, 0))
		gem(k, h, f"EarIn{s}", (s * 0.8, -0.1, 5.66), (s * 1.1, -0.17, 6.02), 0.17, ramp="inner", flat=0.4, twist=0.2, a=0.6, b_=0.3, across=(0, 1, 0))
	# the mane: big clumps round the crown, along the cheeks and off the back
	root = (0, 0.05, 5.1)
	crown = (((-0.34, -0.5, 6.22), 0.42), ((0.34, -0.5, 6.22), 0.42), ((0.0, -0.1, 6.44), 0.46), ((-0.62, 0.2, 6.3), 0.46), ((0.62, 0.2, 6.3), 0.46), ((0.0, 0.62, 6.42), 0.48), ((-0.72, 0.84, 6.0), 0.46), ((0.72, 0.84, 6.0), 0.46), ((0.0, 1.26, 5.86), 0.48), ((-0.94, 1.12, 5.36), 0.46), ((0.94, 1.12, 5.36), 0.46), ((-0.4, 1.4, 5.3), 0.46), ((0.4, 1.4, 5.3), 0.46))
	for i, (t, r) in enumerate(crown):
		gem(k, h, f"Mane{i}", spread(root, t, 0.34), t, r, ramp="fur", flat=0.72, bend=0.04, twist=0.3 + 0.13 * i % 0.5)
	for s in (1, -1):
		for i, (y, z) in enumerate(((-0.46, 4.44), (-0.02, 4.34), (0.42, 4.34))):
			gem(k, h, f"Cheek{s}{i}", (s * 0.72, y, 5.0), (s * 1.28, y + 0.02, z), 0.32, ramp="fur", flat=0.5, twist=0.25 + 0.2 * i, across=(0, 1, 0))
	# the ragged hem over the neck and shoulders
	for i, x in enumerate((-0.78, -0.39, 0.0, 0.39, 0.78)):
		gem(k, h, f"HemB{i}", (x, 0.6, 4.7), (x * 1.08, 0.84, 3.76 + 0.08 * (i % 2)), 0.32, ramp="fur", flat=0.5, twist=0.3, across=(1, 0, 0))
		gem(k, h, f"HemF{i}", (x, -0.56, 4.3), (x * 1.08, -0.72, 3.74 + 0.08 * ((i + 1) % 2)), 0.26, ramp="fur", flat=0.5, twist=0.3, across=(1, 0, 0))


def _belt(k):
	t = "UpperTorso"
	block(k, t, "BeltPelt", 0, 0, 2.34, 2.0, 1.05, 0.56, "pelt", ch=0.05, jit=0.03, sub=1, a=0.46, b=0.56)
	block(k, t, "BeltCord", 0, 0, 2.3, 2.2, 1.075, 0.585, "cord", ch=0.02, a=0.52, b=0.4)
	n = 9
	for i in range(n):
		x = -0.92 + 1.84 * i / (n - 1)
		for tag, y, yt in (("F", -0.5, -0.64), ("B", 0.5, 0.64)):
			gem(k, t, f"Tuft{tag}{i}", (x, y, 2.28), (x * 1.08, yt, 1.58 + 0.13 * (i % 2)), 0.2, ramp="pelt", flat=0.5, twist=0.2 + 0.1 * i % 0.4, across=(1, 0, 0))
	for s in (1, -1):
		for i, y in enumerate((-0.28, 0.0, 0.28)):
			gem(k, t, f"TuftS{s}{i}", (s * 0.95, y, 2.28), (s * 1.1, y, 1.62 + 0.1 * (i % 2)), 0.17, ramp="pelt", flat=0.5, twist=0.2, across=(0, 1, 0))


def _blade(k, arm, s):
	"""Saw-edged, teeth to the outside, straight down under the hand so it stays close to the body."""
	x, y = s * 1.5, 0.0
	block(k, arm, "Grip", x, y, 2.1, 1.66, 0.09, 0.08, "grip", ch=0.02, a=0.5)
	block(k, arm, "BladeGuard", x, y, 1.7, 1.62, 0.16, 0.13, "grip", ch=0.015, corner=0.4, a=0.56)
	# the outline in the x-z plane, thickened along y
	z0, z1, n = 0.3, 1.62, 7
	inner = s * -0.14
	outline = [(inner, z1), (s * 0.17, z1)]
	for i in range(n):
		zb = z1 - (z1 - z0) * (i + 0.72) / n
		outline += [(s * 0.3, zb + 0.02), (s * 0.17, zb)]
	outline += [(0, z0 - 0.08), (inner, z0 + 0.08)]
	rings = [[(x + ox, yy, oz) for ox, oz in outline] for yy in (-0.024, 0.024)]
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Blade", arm, verts, faces, flat, outline=0)
	bake(k, o, "blade", a=0.6, b=0.36, g=0.12)
	xf(o, (x, y, 1.62), ry=-s * 6)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	px = s * 0.53
	core_leg(k, side, s * 0.5)
	block(k, leg, "Pants", px, 0, 1.98, 1.02, 0.52, 0.56, "uni", ch=0.04, flare=0.09, corner=0.16, jit=0.035, mids=(1.5,), a=0.46, b=0.62, g=0.1, tone=0.06)
	art_uv(block(k, leg, "Wrap", px, 0, 1.1, 0.34, 0.5, 0.5, "uni", ch=0.03), "LeftLeg_F", DIAMONDS, dx=-px, dz=1.0)
	# bare feet: a plain block, a forefoot and four toes
	block(k, leg, "Foot", px, -0.06, 0.38, 0.0, 0.48, 0.54, "skin", ch=0.05, a=0.56, b=0.36)
	block(k, leg, "Forefoot", px, -0.5, 0.24, 0.0, 0.47, 0.2, "skin", ch=0.04, a=0.56, b=0.36)
	for i, dx in enumerate((-0.345, -0.115, 0.115, 0.345)):
		block(k, leg, f"Toe{i}", px + dx, -0.72, 0.2, 0.0, 0.105, 0.09, "skin", ch=0.03, corner=0.25, a=0.58, b=0.34)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_mask(k)
	k.reshape("UpperTorso", "Torso", [(0, 0, 4.0, 0.95, 0.46), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.04, 1.0, 0.5), (0, 0, 2.0, 0.95, 0.46)], corner=0.1, nc=1)
	_belt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm, ax = f"{side}UpperArm", s * 1.5
		k.reshape(arm, f"{side}Arm", [(ax, 0, 4.0, 0.44, 0.44), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 2.04, 0.5, 0.5), (ax, 0, 2.0, 0.44, 0.44)], corner=0.12, nc=1)
		hand(k, arm, ax)
		_blade(k, arm, s)
		_leg(k, side, s)
	finish()


def _diamonds(f):
	"""White with rows of black diamonds, the source's leg-wrap pattern."""
	studs(f, DIAMONDS)
	f.path(rect_d(-2, 0, 2, 5), "#f2f0ea")
	c, h = 0.34, 0.26
	for j in range(0, 8):
		for i in range(-3, 4):
			x, z = i * c, 1.2 + j * h
			f.path(f"M{x:.3f} {z - h * 0.42:.3f}L{x + c * 0.4:.3f} {z:.3f}L{x:.3f} {z + h * 0.42:.3f}L{x - c * 0.4:.3f} {z:.3f}Z", "#16161c")
	f.out.append("</g>")


def _plain(f, colour, shadow):
	"""A bare block: flat skin, one very soft shadow, nothing drawn on it."""
	f.fill(colour)
	f.soft(f"M-5 {f.h * 0.82}H{f.w + 5}V{f.h + 5}H-5Z", shadow, 0.35, 5)


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.fill(FUR)
	f.soft("M-5 90H135V135H-5Z", "#4a5a6c", 0.6, 5)
	f.soft("M-5-5H135V18H-5Z", "#8ca0b4", 0.5, 3)
	# short fur strokes for the mask's front, then the hollow eyes under the brow ridge
	for x, y in ((14, 24), (34, 16), (65, 20), (96, 16), (116, 24), (10, 70), (120, 70), (20, 96), (110, 96)):
		f.path(f"M{x} {y}L{x + 4} {y + 12}L{x - 4} {y + 12}Z", "#556678")
	for s, x in ((-1, 34), (1, 96)):
		f.path(ell(x, 46, 20, 15), "#101218")
		f.path(ell(x - s * 2, 49, 6.5, 6.5), "#d6dce4")
		f.path(ell(x - s * 2, 49, 3, 3.4), "#101218")
	for n in ("Head_L", "Head_R", "Head_T", "Head_B", "Head_Bo"):
		a[n].fill(FUR)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T", "Torso_Bo"):
		_plain(a[n], SKIN, SKIN_D)
	_diamonds(a["LeftLeg_F"])
	for side in ("Left", "Right"):
		for fc in ("F", "B", "O", "I", "T", "Bo"):
			_plain(a[f"{side}Arm_{fc}"], SKIN, SKIN_D)
