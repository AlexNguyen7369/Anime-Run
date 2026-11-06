# Target look for solo_monarch "Jinwu" (design doc section 5; owner revisions 2026-11-05): his casual everyday self with the two daggers he holds in the show. Short-to-medium black
# hair falling forward from a crown whorl: a long split fringe with one lock between the eyes, ears showing, a tapered nape. An open black knit cardigan as real panels over a white tee,
# loose dark jeans, sneakers. Right hand: the black and red flame-toothed dagger with a gold guard; left hand: the dark dagger with a white edge and a bone hilt. +X is the viewer's right. Modelled in-house.
import math
import random

from atlas import shade
from ds_style3 import eye, xf
from jk_common import brow2, form, nose
from jk_style3 import bake, crown, sneaker
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, ears, finish, gem, head_rest, prism, rblock, sleeve, slab, trouser

SKIN = "#efc6a4"
SKIN_D = "#c08f72"
TEE = "#eceaf0"
TEE_D = "#a8a6b4"
CARD = "#1a1b22"
VIOLET = "#6d4cff"
DEFAULT = CARD
R = Ramps(
	hair=["#050505", "#0a0909", "#121111", "#1b1a1a", "#2b2a29"],  # barely warm on purpose: the portrait grade lifts darks and adds blue, this lands on neutral black
	skin=["#b98a6a", "#dcae8c", "#efc6a4", "#fbdfc4"],
	card=["#08080c", "#101116", "#1a1b22", "#2a2b34", "#42444f"],
	rib=["#1c1d24", "#2c2e37", "#3e404c", "#565866"],
	button=["#6a6e7c", "#9a9eac", "#c8ccd6", "#f0f2f6"],
	jean=["#0c0e18", "#161a28", "#232839", "#343b52", "#4c5470"],	shoe=["#040406", "#0c0c10", "#1a1a20", "#30303a"],
	sole=["#a6a8ae", "#d4d6da", "#eeeff2", "#ffffff"],
	rear=["#14120f", "#24211d", "#38342f", "#4e4a44", "#6a655e"],  # back locks only: the back is unlit, this keeps them readable on black
	kk=["#0a0204", "#160408", "#26060c", "#3c0a12"],
	flame=["#8a1408", "#c8280e", "#ee4a14", "#ff8428"],
	gold=["#7a5208", "#b8841c", "#e0ac34", "#ffdc78"],
	cord=["#2c241e", "#463a30", "#62544a", "#807266"],
	dark=["#08060e", "#120e1a", "#1e1828", "#30283e"],
	edge=["#a8b0c0", "#d4dae4", "#f0f3f8", "#ffffff"],
	bone=["#7c6650", "#a68c70", "#c8b294", "#e6d6bc"],
	copper=["#4a1c10", "#74301a", "#9a4826", "#bc6c3c"],
)
HAIR = {"colour": "#1E1E36", "locks": []}
PROPS = []


def _lock(k, name, b, t, r, bend=0.06, flat=0.42, a=0.5, ramp="hair"):
	"""One chunky faceted lock, flat across the surface it lies on, with its own tone so the layers separate."""
	dx, dy = t[0] - b[0], t[1] - b[1]
	gem(k, "Head", name, b, t, r, ramp=ramp, flat=flat, bend=bend, twist=0.12, a=a, b_=0.5, across=(-dy, dx, 0) if abs(dx) + abs(dy) > 0.2 else (1, 0, 0))


def _hair(k):
	"""Every lock flows from a whorl on the crown: forward to the fringe, down the temples, down the back to a tapered nape. Ears and the cheek in front of them stay bare, as in the show."""
	whorl = (0.0, 0.14, 6.2)
	crown(k, [(0.94, 5.3), (1.01, 5.52), (0.99, 5.8), (0.8, 6.04), (0.46, 6.18), (0.1, 6.22)])
	# the skull cap above the ears, and behind the ears a shell down to the nape, narrowing with the jaw
	block(k, "Head", "Cap", 0, 0.1, 5.66, 5.0, 0.97, 0.86, "hair", ch=0.05, corner=0.2, sub=1, a=0.42, b=0.3)
	bake(k.tube("Head", "Back", [(0, 0.5, 5.1, 0.97, 0.4), (0, 0.5, 4.46, 0.96, 0.4), (0, 0.5, 4.14, 0.84, 0.38), (0, 0.5, 4.04, 0.72, 0.32)], "hair", corner=0.2, nc=1, sub=1, outline=0), "hair", k, a=0.4, b=0.3)
	# over the top: broad locks from the whorl to the hairline and round the crown
	for i, (t, r) in enumerate((((-0.74, -0.92, 5.42), 0.44), ((-0.28, -0.96, 5.4), 0.44), ((0.2, -0.96, 5.42), 0.44), ((0.7, -0.92, 5.44), 0.44))):
		_lock(k, f"Over{i}", whorl, t, r, bend=0.2, a=0.46 + 0.05 * (i % 2))
	# the fringe: split locks over the forehead with skin between them; the longest drops between the eyes, a little off centre
	for i, (bx, t, r) in enumerate(
		(
			(-0.56, (-0.96, -0.9, 4.66), 0.24),
			(-0.42, (-0.64, -0.96, 4.8), 0.26),
			(-0.16, (-0.3, -0.98, 4.98), 0.27),
			(0.0, (0.05, -1.0, 4.5), 0.25),
			(0.2, (0.32, -0.98, 4.94), 0.27),
			(0.44, (0.62, -0.96, 4.82), 0.26),
			(0.58, (0.96, -0.9, 4.62), 0.24),
		)
	):
		_lock(k, f"Bang{i}", (bx, -0.8, 5.66), t, r, bend=0.02, flat=0.34, a=0.44 + 0.04 * (i % 3))
	# the temples: stepped points down to the ear, ending a little out from the head
	for s in (1, -1):
		for i, (y, z, tz, r) in enumerate(((-0.42, 5.72, 5.02, 0.32), (-0.1, 5.76, 5.12, 0.34), (0.2, 5.74, 4.98, 0.34), (0.5, 5.7, 4.86, 0.34))):
			_lock(k, f"Temple{s}_{i}", (s * 0.82, y, z), (s * 1.16, y * 1.1, tz), r, bend=0.05, a=0.45 + 0.07 * (i % 2))
		# the fringe's outer lock, closing the gap to the temple
		_lock(k, f"FrontSide{s}", (s * 0.8, -0.66, 5.66), (s * 1.0, -0.86, 4.86), 0.24, bend=0.0, flat=0.36, a=0.5)
		# the sideburn in front of the ear, and behind it a strand to the neck
		_lock(k, f"Burn{s}", (s * 0.9, -0.34, 5.24), (s * 0.98, -0.36, 4.62), 0.17, bend=0.0, flat=0.5, a=0.46)
		_lock(k, f"Neck{s}", (s * 0.88, 0.42, 4.9), (s * 0.94, 0.5, 4.02), 0.22, bend=0.0, flat=0.55, a=0.52)
	# one flick each side at different heights, the show's uneven outline; one cowlick behind the crown
	_lock(k, "FlickL", (-0.84, -0.1, 5.8), (-1.36, -0.16, 5.62), 0.2, bend=0.06, a=0.52)
	_lock(k, "FlickR", (0.92, 0.0, 5.24), (1.38, -0.04, 4.86), 0.2, bend=-0.04, a=0.52)
	_lock(k, "Cowlick", (0.06, 0.2, 6.14), (0.34, 0.5, 6.44), 0.17, bend=0.1, a=0.56)
	# the back: three tiers of long locks shingled flat on the shell, tips just off it at uneven heights, alternating tone so they read on black
	for tier, (n, tz, rr, wide) in enumerate(((7, 5.26, 0.36, 1.04), (8, 4.7, 0.33, 1.02), (7, 4.14, 0.28, 0.9))):
		for i in range(n):
			ang = math.radians(18 + 144 * i / (n - 1))
			# squared-off arc: the shell is a box, a round arc would bury the corner locks
			c, sn = math.copysign(abs(math.cos(ang)) ** 0.5, math.cos(ang)), math.sin(ang) ** 0.5
			z = tz + 0.16 * ((i + tier) % 2)
			# the top tier's roots gather under the dome, the others tuck under the tier above
			root = (c * 0.34, 0.14 + sn * 0.34, 6.12) if tier == 0 else (c * wide * 0.8, 0.1 + sn * 0.72, z + 0.8)
			lit = (i + tier) % 2 and 0 < i < n - 1  # the end locks show from the front and in the portrait: those stay black
			_lock(k, f"Rear{tier}_{i}", root, (c * wide, 0.1 + sn * 0.92, z), rr, bend=0.12 if tier == 0 else 0.0, flat=0.34, a=0.8 if lit else 0.5, ramp="rear" if lit else "hair")


def _ribs(k, part, tag, x0, x1, y, z1, z0, n=5):
	"""Raised knit ribs on a band: thin bars, so the hem still reads as knit at distance."""
	for i in range(n):
		x = x0 + (x1 - x0) * (i + 0.5) / n
		block(k, part, f"{tag}{i}", x, y, z1, z0, 0.018, 0.012, "card", ch=0.005, a=0.6, b=0.3)


def _cardigan(k):
	t = "UpperTorso"
	art_jacket(k)  # the white tee, its art in Torso_F
	# the back and sides of the knit, standing clear of the tee
	block(k, t, "CardBody", 0, 0.23, 4.06, 1.94, 1.11, 0.44, "card", ch=0.05, corner=0.14, sub=1, jit=0.015, a=0.5, b=0.26, g=0.1)
	block(k, t, "CollarBack", 0, 0.44, 4.28, 3.94, 0.8, 0.16, "rib", ch=0.04, corner=0.2, a=0.62, b=0.3)
	for s, side in ((1, "Left"), (-1, "Right")):
		# the open front: a panel each side, its inner edge drifting out as it falls, with a knit band along that edge up to the neck
		prism(k, t, f"Panel{s}", [(s * 0.46, 4.06), (s * 1.11, 4.06), (s * 1.11, 1.94), (s * 0.6, 1.94), (s * 0.54, 3.2)], -0.66, -0.2, "card", a=0.48, b=0.56)
		prism(k, t, f"Band{s}", [(s * 0.3, 4.06), (s * 0.46, 4.06), (s * 0.54, 3.2), (s * 0.6, 1.94), (s * 0.44, 1.94), (s * 0.38, 3.2)], -0.69, -0.6, "rib", a=0.52, b=0.48)
		leg = f"{side}UpperLeg"
		# below the waist the panels ride the legs and stay at z <= 2, ending in a ribbed hem
		prism(k, leg, "PanelLow", [(s * 0.6, 2.0), (s * 1.11, 2.0), (s * 1.11, 1.3), (s * 0.6, 1.3)], -0.68, -0.6, "card", a=0.46, b=0.56)
		prism(k, leg, "BandLow", [(s * 0.44, 2.0), (s * 0.6, 2.0), (s * 0.6, 1.3), (s * 0.44, 1.3)], -0.71, -0.6, "rib", a=0.52, b=0.48)
		block(k, leg, "CardS", s * 1.12, 0, 2.0, 1.3, 0.05, 0.68, "card", ch=0.02, a=0.46, b=0.56)
		block(k, leg, "CardB", s * 0.56, 0.66, 2.0, 1.3, 0.62, 0.06, "card", ch=0.02, a=0.48, b=0.26)
		block(k, leg, "HemS", s * 1.13, 0, 1.46, 1.28, 0.06, 0.69, "rib", ch=0.02, a=0.5, b=0.48)
		block(k, leg, "HemB", s * 0.56, 0.67, 1.46, 1.28, 0.63, 0.07, "rib", ch=0.02, a=0.6, b=0.26)
		prism(k, leg, "HemF", [(s * 0.6, 1.46), (s * 1.12, 1.46), (s * 1.12, 1.28), (s * 0.6, 1.28)], -0.7, -0.6, "rib", a=0.5, b=0.48)
		_ribs(k, leg, "HemRib", s * 0.62, s * 1.1, -0.705, 1.45, 1.3)
		# a patch pocket on each low panel
		prism(k, leg, "Pocket", [(s * 0.66, 1.84), (s * 1.06, 1.84), (s * 1.06, 1.5), (s * 0.66, 1.5)], -0.71, -0.66, "card", a=0.6, b=0.5)
	# the back stays readable on black: a lighter yoke seam, a shoulder band and hem ribs
	block(k, t, "Yoke", 0, 0.68, 3.62, 3.54, 1.08, 0.015, "rib", ch=0.005, a=0.5, b=0.24)
	for dx in (-0.46, 0.46):
		block(k, t, f"BackFold{dx}", dx, 0.68, 3.5, 2.1, 0.03, 0.012, "rib", ch=0.005, a=0.42, b=0.24)
	for s, side in ((1, "Left"), (-1, "Right")):
		_ribs(k, f"{side}UpperLeg", "HemRibB", s * 0.1, s * 1.08, 0.745, 1.45, 1.3, n=7)
	# buttons down the band on one side only, as a real cardigan has
	for i, z in enumerate((3.6, 3.05, 2.5, 1.95)):
		part = "LeftUpperLeg" if z < 2 else t
		block(k, part, f"Button{i}", 0.48 + 0.04 * (3.6 - z) / 1.65, -0.7, z + 0.06, z - 0.06, 0.06, 0.02, "button", ch=0.01, a=0.6, b=0.36)


def _plate(k, arm, name, pts, y, half, ramp, turn, **bk):
	"""A dagger layer: a flat solid at the dagger's plane, turned with the dagger."""
	xf(prism(k, arm, name, pts, y - half, y + half, ramp, **bk), *turn)


def _knight_blade(k):
	"""The right hand's dagger: long black and crimson blade, red-orange teeth stepping down its outer edge, broad gold guard, corded grip, a gold hooked pommel."""
	arm = "RightUpperArm"
	ax, y, s = -1.5, -0.56, -1
	turn = ((ax, y, 2.2), 8, s * 4, 0)
	P = lambda *pts: [(ax + s * d, z) for d, z in pts]
	rblock(k, arm, "Grip", ax, y, 2.56, 1.8, 0.09, 0.09, "cord", ch=0.02, rot=turn, a=0.52, b=0.46)
	_plate(k, arm, "Pommel", P((-0.11, 1.84), (0.11, 1.84), (0.2, 1.66), (0.42, 1.44), (0.14, 1.5), (-0.06, 1.62)), y, 0.07, "gold", turn, a=0.56, b=0.46)
	_plate(k, arm, "Guard", P((-0.5, 2.44), (-0.3, 2.56), (0.3, 2.56), (0.52, 2.46), (0.46, 2.72), (0.24, 2.8), (-0.24, 2.8), (-0.44, 2.7)), y, 0.1, "gold", turn, a=0.56, b=0.46)
	_plate(k, arm, "Teeth", P((0.04, 2.78), (0.3, 2.78), (0.46, 3.06), (0.26, 3.1), (0.5, 3.46), (0.28, 3.5), (0.46, 3.86), (0.24, 3.88), (0.34, 4.26), (0.14, 4.34), (0.06, 4.9), (0.0, 4.3)), y, 0.045, "flame", turn, a=0.56, b=0.42)
	_plate(k, arm, "Rim", P((-0.3, 2.78), (-0.36, 3.36), (-0.32, 3.86), (-0.14, 4.4), (0.06, 4.9), (-0.06, 4.4), (-0.22, 3.86), (-0.24, 3.36), (-0.2, 2.78)), y, 0.04, "flame", turn, a=0.6, b=0.4)
	_plate(k, arm, "Core", P((-0.24, 2.78), (-0.28, 3.36), (-0.24, 3.86), (-0.08, 4.4), (0.05, 4.74), (0.08, 4.3), (0.16, 3.8), (0.22, 3.42), (0.22, 3.04), (0.2, 2.78)), y, 0.075, "kk", turn, a=0.5, b=0.5)


def _fang_blade(k):
	"""The left hand's dagger: a dark blade with a white edge on its outer curve and a back spur, a copper guard with two prongs, a ringed bone hilt."""
	arm = "LeftUpperArm"
	ax, y, s = 1.5, -0.56, 1
	turn = ((ax, y, 2.2), 8, s * 4, 0)
	P = lambda *pts: [(ax + s * d, z) for d, z in pts]
	rblock(k, arm, "Hilt", ax, y, 2.56, 1.76, 0.085, 0.085, "bone", ch=0.02, rot=turn, a=0.56, b=0.42)
	for i, z in enumerate((1.74, 2.54)):
		rblock(k, arm, f"HiltRing{i}", ax, y, z + 0.07, z - 0.05, 0.12, 0.12, "copper", ch=0.025, rot=turn, a=0.54, b=0.44)
	_plate(k, arm, "Guard", P((-0.38, 2.54), (-0.14, 2.6), (0.14, 2.6), (0.38, 2.5), (0.3, 2.74), (0.14, 2.8), (-0.14, 2.8), (-0.3, 2.78)), y, 0.1, "copper", turn, a=0.56, b=0.46)
	_plate(k, arm, "Spur", P((-0.14, 2.86), (-0.42, 3.16), (-0.5, 3.42), (-0.28, 3.26), (-0.14, 3.16)), y, 0.05, "edge", turn, a=0.6, b=0.34)
	_plate(k, arm, "Edge", P((0.1, 2.78), (0.3, 2.78), (0.42, 3.24), (0.42, 3.72), (0.3, 4.16), (0.2, 4.84), (0.08, 4.2), (0.14, 3.72), (0.18, 3.24)), y, 0.04, "edge", turn, a=0.64, b=0.3)
	_plate(k, arm, "Core", P((-0.16, 2.78), (-0.24, 3.24), (-0.24, 3.72), (-0.12, 4.2), (0.2, 4.84), (0.16, 4.2), (0.24, 3.72), (0.26, 3.24), (0.18, 2.78)), y, 0.07, "dark", turn, a=0.54, b=0.5)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="card", cuff=2.5)
	# the ribbed cuff, pushed tight against the wrist
	block(k, f"{side}UpperArm", "RibCuff", s * 1.5, 0, 2.72, 2.48, 0.54, 0.54, "rib", ch=0.03, corner=0.18, a=0.5, b=0.48)


def _leg(k, side, s):
	leg, px = trouser(k, side, s, "jean", low=0.46)
	sneaker(k, leg, px, red="shoe", white="sole")


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.7)
	_hair(k)
	_cardigan(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_knight_blade(k)
	_fang_blade(k)
	finish()


# ---- paint


def _torso(a):
	f = a["Torso_F"]
	f.fill(TEE)
	# the crew neck and a few soft folds in the tee
	f.path("M66 -5Q100 34 134 -5Z", SKIN)
	f.path("M60 -5Q100 44 140 -5", stroke=TEE_D, sw=5)
	f.soft("M70 70Q100 96 130 74L126 90Q100 108 74 86Z", TEE_D, 0.3, 3)
	f.soft("M72 130Q100 146 128 128L126 146Q100 160 74 148Z", TEE_D, 0.32, 3)
	form(f, "#6a6878", 0.35)
	for n in ("Torso_B", "Torso_L", "Torso_R"):
		a[n].fill(TEE)
	a["Torso_T"].fill(TEE)
	a["Torso_Bo"].fill(TEE_D)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V40Q65 46 -5 40Z", SKIN_D, 0.75, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	for s, cx in ((-1, 39), (1, 91)):
		# the glow first, so it bleeds past the lids
		f.soft(f"M{cx - 24} 66Q{cx} 44 {cx + 24} 66Q{cx} 90 {cx - 24} 66Z", VIOLET, 0.55, 5)
		eye(f, cx, 67, s, ("#2412a0", "#6a5cff", "#c8d4ff"), w=36, up=9, dn=8, inner=4, outer=-5, ir=(10.5, 11.5), pu=(3.2, 5.0), lash="#0a0a14", wing=6, thick=1.4, white="#dcdcff", lid=0.42)
		brow2(f, cx, 49, s, 36, 6.2, 4.4, "#14141f")
	nose(f, SKIN, y=78, h=12)
	# a small level mouth, one corner a little up
	f.path("M53 108Q66 110 79 105", stroke="#5a2c26", sw=2.0)
	f.path("M58 115Q65 117 72 115", stroke=SKIN_D, sw=1.1, opacity=0.9)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_T"].fill("#0d0c0a")
	a["Head_B"].fill("#0d0c0a")  # the shell covers this; dark too, so no skin can peek between locks
	_torso(a)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(CARD)
			a[f"{side}Leg_{key}"].fill("#0e1018")
		a[f"{side}Arm_T"].fill(CARD)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill("#0e1018")
		a[f"{side}Leg_Bo"].fill("#06070d")
