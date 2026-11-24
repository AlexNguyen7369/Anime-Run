# Target look for fr_mage "Frierin" (design doc section 5): long white-silver hair, middle part, two high twin tails kept close behind the arms; large elf ears, red drop
# earrings, calm green eyes under thick short brows; the white and gold capelet, striped shirt, tunic, black tights and brown boots; a red staff with a gold crescent.
# The outfit's blocks, ramps and torso art come from char_boss_mage.py, the same source at boss scale; hair, face, skirt and staff are this hero's own. Drawn in-house.
import math

import char_boss_mage as base
from fr_style3 import Kit, big_head, block, collar, elf_ears, face, finish, gem, head_rest, helmet, locks, mane, prism, rod, scalp, shade, skirt, slab, turned

SKIN, SKIN_D, DEFAULT, R = base.SKIN, base.SKIN_D, base.DEFAULT, base.R
HAIR = {"colour": "#D4D2E4", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.3)
	for i, (t, r) in enumerate((((-1.08, 0.0, 5.34), 0.44), ((1.08, 0.0, 5.34), 0.44), ((-0.8, 0.9, 5.1), 0.46), ((0.8, 0.9, 5.1), 0.46))):
		gem(k, "Head", f"Top{i}", (0, 0.0, 5.84), t, r, flat=0.45, bend=0.12, a=0.52)
	for i, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
		gem(k, "Head", f"Back{i}", (x * 0.9, 0.84, 5.7), (x * 1.04, 1.06, 3.96 + 0.08 * (i % 2)), 0.34, flat=0.5, twist=0.1, a=0.48 + 0.06 * (i % 2), across=(1, 0, 0))
	part = [(-0.96, 5.5), (-0.84, 5.92), (-0.4, 6.16), (0.1, 6.2), (0.1, 6.1), (-0.4, 5.84), (-0.78, 5.84), (-0.9, 5.5)]
	slab(k, "Part", part, -0.03, 0.03, "parting", a=0.5, b=0.2)
	for s in (1, -1):
		prism(k, "Head", f"Under{s}", [(s * 0.4, 5.6), (s * 1.0, 5.6), (s * 1.0, 4.94), (s * 0.84, 5.0), (s * 0.4, 5.26)], -0.92, -0.7, "hair", a=0.5, b=0.4)
		# centre-parted fringe: locks to the brow, longer towards the temples
		locks(k, f"Bang{s}", (s * 0.06, -0.72, 5.98), (((s * 0.2, -1.02, 5.14), 0.22), ((s * 0.46, -1.02, 5.02), 0.26), ((s * 0.74, -0.98, 4.96), 0.28), ((s * 0.98, -0.9, 4.8), 0.28)), bend=0.04)
		gem(k, "Head", f"Lock{s}", (s * 0.92, -0.64, 5.5), (s * 0.94, -0.86, 3.4), 0.25, flat=0.45, twist=0.15, a=0.54, across=(1, 0, 0))
		block(k, "Head", f"Temple{s}", s * 0.94, -0.06, 5.5, 4.98, 0.08, 0.5, "hair", ch=0.05, a=0.48, b=0.46)
		gem(k, "Head", f"TempleTip{s}", (s * 0.98, -0.4, 5.3), (s * 1.0, -0.5, 4.5), 0.24, flat=0.4, a=0.5, across=(0, 1, 0))
		# the twin tails: high red ties, then long clumps down behind the arms
		block(k, "Head", f"Tie{s}", s * 0.98, 0.36, 5.96, 5.62, 0.14, 0.17, "red", ch=0.04, a=0.56, b=0.4)
		for i, (b, t, r) in enumerate((((0.96, 0.4, 5.8), (1.5, 0.78, 3.9), 0.42), ((1.2, 0.62, 5.0), (1.62, 1.02, 1.5), 0.44), ((1.0, 0.8, 4.9), (1.24, 1.16, 1.9), 0.4), ((1.36, 0.62, 4.6), (1.96, 0.96, 2.3), 0.3))):
			gem(k, "Head", f"Tail{s}{i}", (s * b[0], b[1], b[2]), (s * t[0], t[1], t[2]), r, flat=0.62, twist=0.25, bend=0.04, a=0.46 + 0.06 * (i % 2))
		w = 0.06
		prism(k, "Head", f"Earring{s}", [(s * 1.2, 4.68), (s * 1.28, 4.48), (s * 1.2, 4.24), (s * 1.12, 4.48)], -0.12 - w, -0.12 + w, "red", a=0.62, b=0.3)


def _staff(k):
	arm, x, y = "RightUpperArm", -1.62, -0.66

	def build():
		block(k, arm, "Butt", x, y, 0.5, 0.1, 0.11, 0.11, "gold", ch=0.04, a=0.56, b=0.44)
		block(k, arm, "Shaft", x, y, 5.0, 0.4, 0.075, 0.075, "shaft", ch=0.02, a=0.54, b=0.44)
		block(k, arm, "Wrap", x, y, 4.8, 4.4, 0.1, 0.1, "red", ch=0.02, a=0.52, b=0.44)
		block(k, arm, "Neck", x, y, 5.22, 4.9, 0.12, 0.12, "gold", ch=0.04, a=0.56, b=0.44)
		rod(k, arm, "Gem", [(x, y - 0.14, 5.44), (x, y - 0.08, 5.44), (x, y + 0.08, 5.44)], [0.1, 0.2, 0.2], "gem", n=8, a=0.58, b=0.5)
		arc = [(x + 0.42 * math.cos(math.radians(d)), y, 5.48 + 0.42 * math.sin(math.radians(d))) for d in range(-80, 161, 24)]
		rod(k, arm, "Moon", arc, [0.06, 0.1, 0.12, 0.13, 0.13, 0.12, 0.11, 0.1, 0.09, 0.07, 0.04], "gold", n=4, a=0.58, b=0.44)

	turned(build, (x, y, 2.2), -4, 4, 0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	elf_ears(k)
	base._top(k)
	skirt(k, "white", 1.3, "gold", flare=0.14)
	for s, side in ((1, "Left"), (-1, "Right")):
		base._arm(k, side, s)
		base._leg(k, side, s)
	_staff(k)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, SKIN_D, ("#1e6c50", "#40a880", "#a4ecc8"), "#5a5470", "#a29cb8", "M58 105Q65 107 72 105", w=34, up=12, dn=10, inner=1.5, outer=-1.5, ir=(11, 12.5), lid=0.3, thick=1.2, brow_y=43, brow_w=22, brow_t=6.4, tilt=0.2, blush=0.24)
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.64))
	scalp(a, "#d4d2e4")
	base._torso(a)
	base._limbs(a)
