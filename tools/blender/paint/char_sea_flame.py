# Painted look for sea_flame. Marks: freckles, the back tattoo (cross, skull, moustache crescent), the crossed-through arm
# bars, hat faces, drawn in-house (design doc 5). No letters: abstract bars and a plain buckle glyph only.
import math

from atlas import INK, paint_hair, shade
from sea_common import arm_muscle, bare_back, bare_side, bead, cap, chest, circle, disc, fx, hair_back, hairline, hand, head_side, lathe, leg_muscle, lifted_zone, strand, strand_zone, tube

SKIN = "#e8b488"
SKIN_D = shade(SKIN, 0.66)
BLACK = "#1c1a22"
HAT = "#ea7a1f"
SHORT = "#23232c"
SHORT_L = "#6a6a7c"
BELT = "#a55a1c"
GOLD = "#eeb82f"
TATTOO = "#2f2a80"
DEFAULT = SKIN

HAIR_COLOURS = [BLACK, HAT]
HAIR = {
	"colour": BLACK,
	"locks": [],  # all its wavy hair is drawn by model() as s-curved strands
}
PROPS = [
	# the wide belt and its big square buckle, the pouch and dagger on the left hip
	{"part": "LowerTorso", "box": [2.07, 1.07, 0.3], "at": [0, 0, 2.2], "colour": BELT, "bevel": 0.04},
	{"part": "LowerTorso", "box": [0.46, 0.1, 0.44], "at": [0, -0.56, 2.2], "colour": GOLD, "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.3, 0.04, 0.28], "at": [0, -0.62, 2.2], "colour": shade(GOLD, 0.62), "bevel": 0.008},
	{"part": "LowerTorso", "box": [0.1, 0.03, 0.2], "at": [0, -0.64, 2.2], "colour": GOLD, "bevel": 0.006},
	{"part": "LowerTorso", "box": [0.32, 0.36, 0.34], "at": [1.04, 0.24, 2.08], "colour": "#6d4220", "bevel": 0.06},
	{"part": "LowerTorso", "box": [0.1, 0.14, 0.52], "at": [1.04, -0.24, 1.86], "colour": "#3f6a33", "bevel": 0.03},
	{"part": "LowerTorso", "box": [0.09, 0.1, 0.16], "at": [1.04, -0.24, 2.2], "colour": "#4b2c13", "bevel": 0.02},
	# orange pad on the left elbow
	{"part": "LeftLowerArm", "box": [0.42, 0.8, 0.46], "at": [1.84, 0, 3.0], "colour": HAT, "bevel": 0.08},
	# the bracelet with its glass needle on the left wrist
	{"part": "LeftHand", "box": [1.03, 1.03, 0.12], "at": [1.5, 0, 2.34], "colour": "#3a2a18", "bevel": 0.02},
	# boot toes
	{"part": "LeftFoot", "box": [0.98, 0.42, 0.3], "at": [0.5, -0.62, 0.15], "colour": "#17161c", "bevel": 0.1},
	{"part": "RightFoot", "box": [0.98, 0.42, 0.3], "at": [-0.5, -0.62, 0.15], "colour": "#17161c", "bevel": 0.1},
]


def _wave(kit, tag, head, x0, y0, z0, dx, dy, dz, amp, r, flip=1, wide=None):
	"""An s-curved clump of his loose waves: root, out, back, a flicked tip."""
	pts = [
		(x0, y0, z0),
		(x0 + dx * 0.33 + flip * amp, y0 + dy * 0.33, z0 + dz * 0.3),
		(x0 + dx * 0.66 - flip * amp, y0 + dy * 0.66, z0 + dz * 0.66),
		(x0 + dx + flip * amp * 1.4, y0 + dy, z0 + dz),
	]
	strand(kit, f"Head_{tag}", pts, r, BLACK, head, flatten=0.55, rings=6, wide=wide)


def model(parts, kit):
	head = parts["Head"]
	line = hairline([(0, 4.7), (45, 4.42), (90, 4.26), (135, 4.42), (180, 4.7), (225, 4.98), (270, 5.0), (315, 4.98)])
	cap(kit, "Head_Cap", BLACK, head, line, top=5.42)
	# fringe: loose waves to the brows, uneven, one long piece by each temple
	for i, (x, dz, r, f) in enumerate(((-0.52, -0.42, 0.2, -1), (-0.28, -0.3, 0.21, 1), (-0.04, -0.36, 0.21, -1), (0.2, -0.28, 0.21, 1), (0.46, -0.4, 0.2, 1))):
		_wave(kit, f"Fringe{i}", head, x, -0.6, 5.18, x * 0.2, -0.1, dz, 0.05, r, f, wide=(1, 0, 0))
	_wave(kit, "FringeGap", head, -0.15, -0.62, 5.1, -0.02, -0.08, -0.26, 0.03, 0.17, 1, wide=(1, 0, 0))
	# by the temples and over the ears, rolling out at the tips
	for s in (1, -1):
		_wave(kit, f"TempleF{s}", head, s * 0.64, -0.44, 5.14, s * 0.1, -0.08, -0.76, 0.05, 0.17, s)
		_wave(kit, f"TempleB{s}", head, s * 0.68, -0.14, 5.16, s * 0.22, -0.02, -0.86, 0.06, 0.2, s, wide=(0, 1, 0))
		_wave(kit, f"Ear{s}", head, s * 0.68, 0.14, 5.14, s * 0.24, 0.1, -0.92, 0.06, 0.2, s, wide=(0, 1, 0))
		_wave(kit, f"Behind{s}", head, s * 0.64, 0.42, 5.12, s * 0.2, 0.14, -0.98, 0.06, 0.2, s, wide=(0, 1, 0))
	# the back: messy layers to the nape
	for i, (x, dz, f) in enumerate(((-0.42, -0.86, -1), (-0.16, -0.98, 1), (0.1, -0.92, -1), (0.38, -0.88, 1))):
		_wave(kit, f"BackA{i}", head, x, 0.62, 5.2, x * 0.2, 0.08, dz, 0.05, 0.21, f, wide=(1, 0, 0))
	for i, (x, dz, f) in enumerate(((-0.54, -0.54, 1), (-0.28, -0.62, -1), (0.0, -0.66, 1), (0.26, -0.6, -1), (0.52, -0.52, 1))):
		_wave(kit, f"BackB{i}", head, x, 0.64, 4.82, x * 0.1, 0.06, dz, 0.04, 0.17, f, wide=(1, 0, 0))
	# the cowboy hat: dented crown, brim turned up hard at the sides
	def bend(x, y, z):
		r = (x * x + y * y) ** 0.5
		if r > 0.72:
			k = (r - 0.72) / 0.5
			z += 0.5 * (abs(x) / (r or 1)) ** 2 * k * k - 0.05 * (abs(y) / (r or 1)) ** 2 * k
		elif z > 5.55:
			z -= 0.2 * math.exp(-((x / 0.2) ** 2)) * (z - 5.55) / 0.5  # the crease along the crown
			y *= 0.84 + 0.16 * (y > 0)  # pinched front
		return x, y, z

	root = ((0, 0, 5.0), (0, 0, 6.1))
	lathe(kit, "Head_HatBrim", [(0.5, 5.24), (0.86, 5.21), (1.2, 5.22), (1.24, 5.26), (0.9, 5.26), (0.74, 5.3)], HAT, head, at=(0, -0.02, 0), seg=36, sy=0.92, deform=bend, lock=((0, 0, 4.9), (0, 0, 5.8)))
	lathe(kit, "Head_HatCrown", [(0.78, 5.27), (0.78, 5.46), (0.76, 5.76), (0.64, 5.96), (0.36, 6.05), (0, 6.07)], HAT, head, at=(0, -0.02, 0), seg=36, sy=0.94, deform=bend, lock=root)
	lathe(kit, "Head_HatUnder", [(0.5, 5.22), (0.86, 5.19), (1.18, 5.2), (1.18, 5.21), (0.5, 5.24)], shade(HAT, 0.56), head, at=(0, -0.02, 0), seg=36, sy=0.92, deform=bend)
	lathe(kit, "Head_HatBand", [(0.775, 5.3), (0.785, 5.32), (0.765, 5.45), (0.74, 5.46)], "#3c2312", head, at=(0, -0.02, 0), seg=36, sy=0.95, deform=bend)
	# the red beads on the cord across the front of the crown
	for i in range(14):
		ang = math.radians(198 + i * 12)
		bead(kit, f"Head_HatBead{i}", (0.8 * math.cos(ang), -0.02 + 0.76 * math.sin(ang), 5.37), 0.042, "#c5262c", head)
	# two faces pinned to the crown: one laughing, one sulking, drawn as discs with flat features
	for tag, x, smile in (("A", -0.2, True), ("B", 0.2, False)):
		cy = -0.76
		disc(kit, f"Head_HatFace{tag}", (x, cy, 5.62), 0.13, 0.02, "#f2d43a" if smile else "#3e7dcc", head)
		y = cy - 0.024
		for ex in (-0.055, 0.055):
			kit.flat(f"Head_HatEye{tag}{ex}", [(x + ex - 0.015, 5.64), (x + ex + 0.015, 5.64), (x + ex + 0.015, 5.68), (x + ex - 0.015, 5.68)], INK, head, y=y)
		if smile:
			kit.flat(f"Head_HatMouth{tag}", [(x - 0.075, 5.6), (x + 0.075, 5.6), (x + 0.04, 5.55), (x - 0.04, 5.55)], INK, head, y=y)
		else:
			kit.flat(f"Head_HatMouth{tag}", [(x - 0.07, 5.55), (x + 0.07, 5.55), (x + 0.04, 5.59), (x - 0.04, 5.59)], INK, head, y=y)
	# the necklace of big red beads, hanging low on the chest
	torso = parts["UpperTorso"]
	for i in range(13):
		t = i / 12
		x = -0.72 + 1.44 * t
		z = 3.56 + 0.44 * (2 * t - 1) ** 2
		bead(kit, f"UpperTorso_Neck{i}", (x, -0.53, z), 0.082, "#c5262c", torso)


def face(a):
	f = a["Head_F"]
	f.fill(SKIN)
	dark = shade(SKIN, 0.68)
	e = shade(SKIN, 0.42)
	f.path("M-5-5H135V36L116 42L98 36L82 44L65 36L50 44L32 36L14 42L-5 36Z", dark, opacity=0.95, blur=1)
	f.soft("M-5 40H11Q7 90 26 135H-5Z", dark, 0.8, 3)
	f.soft("M135 40H119Q123 90 104 135H135Z", dark, 0.95, 3)
	f.soft("M28 128Q65 116 102 128V136H28Z", dark, 0.85, 2)
	# narrow black eyes under heavy lazy lids, little white showing, straight thick brows pressed low
	for cx, s in ((40, -1), (90, 1)):
		f.path(f"M{cx - s * 12} 65Q{cx} 60 {cx + s * 15} 60Q{cx + s * 11} 69 {cx} 70Q{cx - s * 8} 70 {cx - s * 12} 65Z", "#fbf8f2")
		f.path(circle(cx + s * 1, 64, 6.6, 6.6), "#100e14")
		f.path(circle(cx + s * 3.2 - 1, 62.4, 1.2), "#ffffff")
		f.path(f"M{cx - s * 14} 67Q{cx - s * 3} 54 {cx + s * 18} 57L{cx + s * 15} 62Q{cx} 59 {cx - s * 12} 67Z", INK)
		f.ink(f"M{cx - s * 8} 70Q{cx} 72.5 {cx + s * 11} 66", 1.0)
		f.taper(cx - s * 8, 52, cx + s * 2, 50, cx + s * 16, 53, 0.5, e)
		f.path(f"M{cx - s * 15} 49Q{cx} 40 {cx + s * 18} 44L{cx + s * 18} 49Q{cx} 46 {cx - s * 13} 54Z", "#17151b")
	# the freckles: a band of dots on each cheek and over the nose
	for x, y, r in ((22, 80, 1.5), (30, 84, 1.7), (38, 80, 1.5), (46, 84, 1.4), (26, 88, 1.4), (35, 90, 1.5), (43, 88, 1.3), (108, 80, 1.5), (100, 84, 1.7), (92, 80, 1.5), (84, 84, 1.4), (104, 88, 1.4), (95, 90, 1.5), (87, 88, 1.3), (58, 80, 1.1), (72, 80, 1.1)):
		f.path(circle(x, y, r), "#94553a")
	# nose
	f.path("M64 70L60 86L69 87Z", dark, opacity=0.65)
	f.ink("M59 87Q64 90 70 87", 1.1, e)
	# an easy lopsided smirk, a sliver of top teeth, the left side higher
	f.path("M46 106Q64 109 90 99Q86 110 70 111Q54 112 46 106Z", "#fbf8f2", stroke=INK, sw=1.7)
	f.ink("M56 108Q70 111 84 104", 0.7, "#7c7c86")
	f.taper(42, 103, 44, 105, 47, 107, 0.8, INK)
	f.taper(94, 95, 92, 98, 89, 100, 0.8, INK)
	f.taper(54, 118, 65, 121, 78, 117, 0.8, e)


def back_mark(f, ink):
	"""The big back tattoo: an upright cross behind a skull with a wide crescent moustache."""
	cx, cy = 100, 88
	# the cross, its arms flaring at the ends
	f.path(f"M{cx - 10} 12H{cx + 10}L{cx + 7} {cy - 30}L{cx + 7} {cy + 50}L{cx + 13} 170H{cx - 13}L{cx - 7} {cy + 50}L{cx - 7} {cy - 30}Z", ink)
	f.path(f"M18 {cy - 12}L{cx - 30} {cy - 7}V{cy + 7}L18 {cy + 12}Z", ink)
	f.path(f"M182 {cy - 12}L{cx + 30} {cy - 7}V{cy + 7}L182 {cy + 12}Z", ink)
	# skull: a dark mass with skin showing through as the bone
	f.path(f"M{cx - 34} {cy - 6}Q{cx - 36} {cy - 44} {cx} {cy - 46}Q{cx + 36} {cy - 44} {cx + 34} {cy - 6}Q{cx + 30} {cy + 12} {cx + 22} {cy + 14}V{cy + 30}H{cx - 22}V{cy + 14}Q{cx - 30} {cy + 12} {cx - 34} {cy - 6}Z", ink)
	f.path(f"M{cx - 27} {cy - 6}Q{cx - 28} {cy - 38} {cx} {cy - 39}Q{cx + 28} {cy - 38} {cx + 27} {cy - 6}Q{cx + 24} {cy + 6} {cx + 16} {cy + 8}V{cy + 24}H{cx - 16}V{cy + 8}Q{cx - 24} {cy + 6} {cx - 27} {cy - 6}Z", SKIN)
	for s in (-1, 1):
		f.path(circle(cx + s * 12, cy - 12, 8, 9), ink)
	f.path(f"M{cx - 4} {cy + 6}L{cx} {cy - 3}L{cx + 4} {cy + 6}Z", ink)
	for x in (-9, -3, 3, 9):
		f.path(f"M{cx + x} {cy + 16}V{cy + 24}", stroke=ink, sw=1.6)
	# the crescent moustache, wide horns swept up past the skull
	f.path(f"M{cx - 62} {cy - 24}Q{cx - 50} {cy + 22} {cx} {cy + 8}Q{cx + 50} {cy + 22} {cx + 62} {cy - 24}Q{cx + 54} {cy + 40} {cx} {cy + 22}Q{cx - 54} {cy + 40} {cx - 62} {cy - 24}Z", ink)


def arm_bars(f, x, y, ink):
	"""Four stacked blocks down the arm, the second struck through: bars standing in for a word."""
	for i, w in enumerate((30, 24, 28, 26)):
		yy = y + i * 15
		f.path(f"M{x - w / 2} {yy}H{x + w / 2}V{yy + 9}H{x - w / 2}Z", ink)
	f.path(f"M{x - 24} {y + 28}L{x + 24} {y + 12}", stroke="#b5201f", sw=3.2)


def paint(a):
	paint_hair(a, [BLACK, HAT])
	lifted_zone(a, 0, 2, "#2d2b35", "#0c0b11", "#575470")
	strand_zone(a, 1, 2, HAT)
	face(a)
	# ---- torso, bare: a lean, cut chest
	f = a["Torso_F"]
	f.fill(SKIN)
	chest(f, SKIN, cx=100, w=0.92, abs_rows=3, deep=1.1)
	f.soft("M-5 164H205V175H-5Z", SKIN_D, 0.8, 2)
	f.edges(0.2)
	f = a["Torso_B"]
	bare_back(f, SKIN)
	back_mark(f, TATTOO)
	for n in ("Torso_L", "Torso_R"):
		bare_side(a[n], SKIN)
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SKIN)
			arm_muscle(f, side, key, SKIN)
			hand(f, side, key, SKIN)
			if side == "Left" and key in "OF":
				arm_bars(f, 50, 18, TATTOO)
			if side == "Left":  # the elbow pad's two straps
				f.path("M-5 88H105V94H-5ZM-5 112H105V118H-5Z", "#3a2a18", stroke=INK, sw=0.8)
			f.edges(0.22)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		# ---- legs: black knee shorts, bare shin, tall heavy boots
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(SKIN)
			leg_muscle(f, SKIN, 96, 150)
			f.path("M-5-5H105V104Q50 112 -5 104Z", SHORT)
			f.folds(6, "#0d0d13", SHORT_L, y0=0.03, y1=0.46, pinch=(50, 6))
			f.path("M-5 92Q50 100 105 92V104Q50 112 -5 104Z", "#17171f")
			f.ink("M-5 104Q50 112 105 104", 2)
			if key == "O":
				f.ink(f"M{fx(side, key, 0.3)} 12V52", 1.2, SHORT_L)
			f.path("M-5 148Q50 156 105 148V205H-5Z", "#17161c")
			f.ink("M-5 148Q50 156 105 148", 2)
			f.path("M-5 148Q50 156 105 148V158Q50 166 -5 158Z", "#35343f")
			f.taper(14, 176, 50, 184, 86, 174, 1.2, "#3e3d48")
			f.path("M-5 192H105V205H-5Z", "#08080c")
			f.edges()
		a[f"{side}Leg_T"].fill(SHORT)
		a[f"{side}Leg_Bo"].fill("#08080c")
	hair_back(a["Head_B"], "#2a2832", SKIN, nape=118)
	a["Head_T"].fill("#1c1a22")
	a["Head_Bo"].fill(SKIN_D)
	head_side(a["Head_L"], SKIN, "#2a2832", True, hair_front=0.2, low=0.7, back_low=0.9, ear=False)
	head_side(a["Head_R"], SKIN, "#2a2832", False, hair_front=0.2, low=0.7, back_low=0.9, ear=False)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(SHORT)
