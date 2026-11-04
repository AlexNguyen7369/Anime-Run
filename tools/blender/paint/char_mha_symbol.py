# Painted look for mha_symbol: two tall hair horns, shadowed eyes, huge grin, broad blue, red and white suit (design doc 5).
# The fixed blocks are too narrow for this build, so model() wraps each one in a shaped shell painted with the same art.
from atlas import INK, paint_hair, shade
from mha_common import ell, fingers, loft, lr, nape, shell, tube

SKIN = "#f2cfae"
SKIN_D = shade(SKIN, 0.62)
BLUE = "#2b50a8"
BLUE_D = shade(BLUE, 0.55)
BLUE_L = "#6a92e0"
RED = "#cf2329"
RED_D = shade(RED, 0.62)
RED_L = "#f46a5e"
WHITE = "#f2f1ec"
GOLD = "#f0c02e"
GOLD_D = "#b98a18"
SHADOW = "#120f1c"
HAIR_C = "#F2CF34"
DEFAULT = BLUE
HAIR_COLOURS = [HAIR_C]
HAIR = {"colour": HAIR_C, "locks": []}

PROPS = []
for p in (
	# boot toes: a shell cannot make a foot
	dict(part="Foot", box=[1.24, 1.56, 0.3], at=[0.58, -0.16, 0.16], colour="#CF2329", bevel=0.1),
	dict(part="Foot", box=[1.28, 1.62, 0.09], at=[0.58, -0.16, 0.05], colour="#8E1418", bevel=0.03),
	dict(part="Foot", box=[0.74, 0.1, 0.16], at=[0.58, -0.96, 0.22], colour="#F0C02E", bevel=0.03),
):
	part = p.pop("part")
	PROPS.extend(lr(part, **p))


def model(parts, kit):
	head = parts["Head"]
	# a V-tapered trunk and heavy limbs; every ring stays outside the fixed block, so it never pokes through
	shell(kit, "UpperTorso_Build", "Torso", parts["UpperTorso"], [(4.02, -1.36, 1.36, -0.72, 0.68), (3.5, -1.48, 1.48, -0.82, 0.76), (3.0, -1.22, 1.22, -0.7, 0.66), (2.5, -1.04, 1.04, -0.58, 0.56), (1.98, -1.12, 1.12, -0.6, 0.58)])
	for sgn, side in ((1, "Left"), (-1, "Right")):
		x = lambda a, b: (a, b) if sgn > 0 else (-b, -a)
		xa, xb = x(1.06, 2.52)
		x2a, x2b = x(1.04, 2.62)
		x3a, x3b = x(1.08, 2.42)
		x4a, x4b = x(1.0, 2.3)
		x5a, x5b = x(0.98, 2.44)
		shell(kit, f"{side}UpperArm_Build", f"{side}Arm", parts[f"{side}UpperArm"], [(4.26, xa, xb, -0.62, 0.62), (3.74, x2a, x2b, -0.78, 0.76), (3.14, x3a, x3b, -0.72, 0.66), (2.74, x4a, x4b, -0.62, 0.6), (2.3, x5a, x5b, -0.7, 0.68), (1.92, x4a, x4b, -0.66, 0.62)])
		la, lb = x(-0.02, 1.2)
		l2a, l2b = x(-0.02, 1.26)
		l3a, l3b = x(-0.01, 1.08)
		shell(kit, f"{side}UpperLeg_Build", f"{side}Leg", parts[f"{side}UpperLeg"], [(2.04, la, lb, -0.68, 0.62), (1.5, l2a, l2b, -0.72, 0.68), (1.02, l3a, l3b, -0.58, 0.58), (0.62, la, lb, -0.68, 0.68), (0.06, l2a, l2b, -0.62, 0.62)])

	# skull: short hair swept back
	loft(kit, "Head_Mass", [(0, 0.2, 4.42, 0.66, 0.46), (0, 0.14, 4.82, 0.76, 0.56), (0, 0.04, 5.15, 0.76, 0.68), (0, 0, 5.38, 0.62, 0.58), (0, 0.02, 5.5, 0.3, 0.3)], HAIR_C, head, sides=12, power=2.6, root=(0, -0.2, 5.5), tip=(0, 0.4, 4.42))
	n = 0

	def s(pts, r, flatten=0.55):
		nonlocal n
		n += 1
		tube(kit, f"Head_Lock{n}", pts, [r * 0.8, r, r * 0.86, r * 0.56, 0.0], HAIR_C, head, flatten=flatten)

	for sgn in (1, -1):
		# the two horns: thick at the hairline, rising out and up, sharp at the top
		s([(sgn * 0.1, -0.5, 5.2), (sgn * 0.28, -0.6, 5.62), (sgn * 0.5, -0.6, 5.98), (sgn * 0.72, -0.56, 6.28), (sgn * 0.9, -0.5, 6.62)], 0.34, 0.55)
		s([(sgn * 0.3, -0.36, 5.3), (sgn * 0.44, -0.44, 5.6), (sgn * 0.6, -0.44, 5.86), (sgn * 0.74, -0.4, 6.06), (sgn * 0.84, -0.34, 6.28)], 0.26, 0.6)
		# a loose strand hanging from each horn's root over the forehead
		s([(sgn * 0.14, -0.6, 5.26), (sgn * 0.2, -0.68, 5.08), (sgn * 0.26, -0.68, 4.96), (sgn * 0.3, -0.68, 4.86), (sgn * 0.36, -0.68, 4.76)], 0.09)
		# hairline: a short fringe closing the head's top corners
		s([(sgn * 0.32, -0.54, 5.42), (sgn * 0.5, -0.66, 5.32), (sgn * 0.62, -0.68, 5.2), (sgn * 0.68, -0.68, 5.12), (sgn * 0.74, -0.68, 5.0)], 0.22)
		# temple spikes, swept back over the ear
		s([(sgn * 0.6, -0.42, 5.14), (sgn * 0.84, -0.34, 5.14), (sgn * 0.98, -0.1, 5.1), (sgn * 1.04, 0.14, 5.14), (sgn * 1.04, 0.48, 5.3)], 0.27)
		s([(sgn * 0.62, -0.36, 4.86), (sgn * 0.82, -0.2, 4.82), (sgn * 0.92, 0.06, 4.78), (sgn * 0.98, 0.3, 4.82), (sgn * 1.0, 0.62, 4.96)], 0.24)
		# the back of the head: spikes fan out, so from behind they read as a star, not as points aimed at the eye
		for x, z, dx, dy, dz, r in ((0.14, 5.38, 0.06, 0.6, 0.72, 0.22), (0.42, 5.34, 0.34, 0.5, 0.66, 0.22), (0.62, 5.12, 0.62, 0.4, 0.34, 0.2), (0.18, 4.98, 0.14, 0.72, 0.18, 0.2), (0.5, 4.86, 0.54, 0.46, -0.12, 0.2), (0.14, 4.6, 0.08, 0.5, -0.5, 0.2), (0.44, 4.54, 0.32, 0.42, -0.5, 0.2)):
			b0 = (sgn * x, 0.3, z)
			s([(b0[0] + sgn * dx * t, b0[1] + dy * t, b0[2] + dz * t) for t in (0, 0.28, 0.55, 0.78, 1)], r)
	# flat shingles down the back of the skull, crown to nape, so no bare mass shows
	for i, (x, z0, z1, r) in enumerate(((0.0, 5.44, 4.74, 0.24), (0.3, 5.42, 4.72, 0.24), (-0.3, 5.42, 4.72, 0.24), (0.56, 5.3, 4.64, 0.22), (-0.56, 5.3, 4.64, 0.22), (0.14, 4.96, 4.3, 0.22), (-0.14, 4.96, 4.3, 0.22), (0.42, 4.92, 4.3, 0.22), (-0.42, 4.92, 4.3, 0.22))):
		zm = (z0 + z1) / 2
		s([(x * 0.9, 0.5, z0), (x, 0.7, z0 - 0.14), (x * 1.02, 0.78, zm), (x * 1.04, 0.8, (zm + z1) / 2), (x * 1.08, 0.86, z1)], r, 0.42)
	# neck: the head stands on a thick column of muscle
	loft(kit, "UpperTorso_Neck", [(0, 0, 3.96, 0.74, 0.62), (0, 0, 4.1, 0.66, 0.58)], "#D8AE8C", parts["UpperTorso"], sides=12, power=3)


def arm(f, key, side):
	f.fill(BLUE)
	# deltoid: a white cap split by the red stripe that runs on from the chest
	f.path("M-5-5H105V40Q50 58 -5 40Z", WHITE)
	f.path("M36-5H64L64 48H36Z", RED, stroke=INK, sw=1.2)
	f.soft("M-5 26Q50 44 105 26V42Q50 60 -5 42Z", "#9aa2b4", 0.6, 2)
	f.ink("M-5 40Q50 58 105 40", 2.0)
	# bulging biceps and triceps
	f.soft("M12 62Q50 50 88 62Q88 98 50 104Q14 98 12 62Z", BLUE_L, 0.8, 4)
	f.soft("M72 56Q92 80 78 114H105V56Z", BLUE_D, 0.9, 2)
	f.soft("M-5 56Q8 80 -2 114H-5Z", BLUE_D, 0.8, 2)
	f.taper(14, 62, 8, 86, 24, 108, 2.0)
	f.taper(86, 62, 92, 86, 76, 108, 2.0)
	f.taper(22, 112, 50, 122, 78, 112, 1.8)
	# forearm muscle lines
	f.taper(30, 124, 24, 136, 32, 148, 1.3, BLUE_D)
	f.taper(70, 124, 76, 136, 68, 148, 1.3, BLUE_D)
	# big gold gauntlet with a red band, heavy fingers
	f.path("M-5 146H105V210H-5Z", GOLD)
	f.path("M-5 146H105V158H-5Z", RED, stroke=INK, sw=1.4)
	f.soft("M-5 176H105V210H-5Z", GOLD_D, 0.7, 2)
	if key in "FB":
		f.path("M10 168H90V180H10Z", GOLD_D, stroke=INK, sw=1)
		fingers(f, 184, 205, "#6a4a10")
	f.edges(0.3)


def leg(f, key):
	f.fill(BLUE)
	# quads
	f.soft("M12 14Q50 2 88 14Q86 62 50 74Q14 62 12 14Z", BLUE_L, 0.75, 4)
	f.soft("M72 8Q92 34 76 72H105V8Z", BLUE_D, 0.85, 2)
	f.taper(50, 8, 52, 40, 46, 70, 1.7)
	f.taper(16, 12, 10, 40, 26, 70, 1.8)
	f.taper(84, 12, 90, 40, 74, 70, 1.8)
	if key == "O":
		f.path("M38-5H62V96H38Z", WHITE, stroke=INK, sw=1.3)
		f.path("M45-5H55V96H45Z", RED)
	# knee
	f.taper(20, 82, 50, 92, 80, 82, 1.7)
	f.taper(22, 92, 50, 84, 78, 92, 1.1, BLUE_D)
	# red boot, gold-topped, calf inked
	f.path("M-5 100H105V205H-5Z", RED)
	f.path("M-5 100H105V112H-5Z", GOLD, stroke=INK, sw=1.5)
	f.soft("M12 122Q50 112 88 122Q84 158 50 166Q18 158 12 122Z", RED_L, 0.55, 4)
	f.taper(18, 124, 12, 146, 30, 164, 1.6, RED_D)
	f.taper(82, 124, 88, 146, 70, 164, 1.6, RED_D)
	f.folds(2, RED_D, RED_L, y0=0.84, y1=0.94, pinch=(50, 192))
	f.edges(0.3)


def paint(a):
	paint_hair(a, ["#f8da42"])
	# ---- face: sockets gone to black, a white-hot stare, the enormous grin, a slab of a jaw
	f = a["Head_F"]
	f.fill(SKIN)
	f.soft("M-5-5H135V46H-5Z", shade(SKIN, 0.5), 0.85, 5)
	# cheekbones and hollows
	f.soft("M-5 70L30 86L38 124H-5Z", SKIN_D, 0.75, 2)
	f.soft("M135 70L100 86L92 124H135Z", SKIN_D, 0.75, 2)
	# the black brow mass that swallows both eyes, cut in a hard V to the nose
	f.soft("M-5 26H135V50H-5Z", SHADOW, 0.8, 5)
	f.path("M-5 38L28 42L58 54L60 72L46 80Q24 84 8 72L-5 60Z", SHADOW)
	f.path("M135 38L102 42L72 54L70 72L84 80Q106 84 122 72L135 60Z", SHADOW)
	# hatching where the shadow breaks on the cheek
	for i in range(7):
		x = 8 + i * 7
		f.taper(x, 72 + (i % 2) * 3, x - 3, 82, x - 6, 90 - abs(i - 3) * 2, 0.9, SHADOW)
		f.taper(130 - x, 72 + (i % 2) * 3, 133 - x, 82, 136 - x, 90 - abs(i - 3) * 2, 0.9, SHADOW)
	f.path("M60 44L70 44L68 60H62Z", "#3a2e44", opacity=0.9)
	# small burning blue eyes
	for cx, sgn in ((34, -1), (96, 1)):
		f.path(f"M{cx - 11} {62 + sgn * 0 + 1}Q{cx} {54} {cx + 11} {62}Q{cx} {68} {cx - 11} {63}Z", "#eaf6ff")
		f.path(ell(cx, 61, 4.4, 4.6), "#2f8ae0")
		f.path(ell(cx, 61, 1.8, 2.0), "#06122a")
		f.path(ell(cx + 1.2, 59.4, 0.9), "#ffffff")
	# long straight nose: lit ridge, inked wedge
	f.path("M62 58L68 58L72 86L58 86Z", SKIN)
	f.soft("M68 60L74 86H68Z", SKIN_D, 0.9, 1)
	f.path("M56 86Q65 94 74 86L72 90Q65 95 58 90Z", INK)
	# the grin runs near cheek to cheek, a full fence of teeth
	f.path("M16 94Q65 110 114 94Q112 124 65 128Q18 124 16 94Z", "#fbf8f4", stroke=INK, sw=2.2)
	f.path("M18 110Q65 120 112 110", stroke=INK, sw=1.2)
	for x in range(25, 112, 11):
		f.ink(f"M{x} {100 if 40 < x < 92 else 98}L{x + (65 - x) * 0.08} {125 if 40 < x < 92 else 118}", 1.1, "#3a3036")
	# deep creases bracketing it, cleft and chin
	f.taper(10, 82, 6, 100, 18, 118, 1.5)
	f.taper(120, 82, 124, 100, 112, 118, 1.5)
	f.taper(20, 76, 26, 84, 40, 88, 1.2, SKIN_D)
	f.taper(110, 76, 104, 84, 90, 88, 1.2, SKIN_D)
	# ---- torso front: blue trunk; the red V, white-edged, runs shoulder to sternum
	f = a["Torso_F"]
	f.fill(BLUE)
	# white upper chest under the V
	f.path("M-5-5H205V28L140 94L100 136L60 94L-5 28Z", WHITE, stroke=INK, sw=2)
	f.path("M62-5H138L108 44L100 56L92 44Z", BLUE, stroke=INK, sw=1.8)
	f.path("M-5 6L100 112L205 6V44L100 150L-5 44Z", RED, stroke=INK, sw=2.2)
	f.path("M-5 14L100 120L205 14V20L100 126L-5 20Z", RED_L, opacity=0.7)
	f.path("M-5 44L100 150L205 44V52L100 158L-5 52Z", GOLD, stroke=INK, sw=1.4)
	# pecs inked through the suit
	f.soft("M22 28Q60 14 94 44Q84 66 56 56Q28 48 22 28Z", "#ffffff", 0.35, 4)
	f.soft("M178 28Q140 14 106 44Q116 66 144 56Q172 48 178 28Z", "#ffffff", 0.35, 4)
	f.taper(24, 62, 62, 90, 97, 72, 2.4)
	f.taper(176, 62, 138, 90, 103, 72, 2.4)
	# abdomen cut into blocks
	f.path("M64 134Q82 128 97 136V150Q80 146 66 150ZM136 134Q118 128 103 136V150Q120 146 134 150Z", BLUE_L, opacity=0.5)
	# gold belt, red trunks
	f.path("M-5 150H205V170H-5Z", GOLD, stroke=INK, sw=2)
	f.path("M-5 150H205V156H-5Z", "#ffe48a")
	f.path("M84 146H116L110 176H90Z", RED, stroke=INK, sw=1.6)
	f.path("M-5 170H205V205H-5Z", RED)
	f.path("M-5 205L40 170H160L205 205Z", RED_D, opacity=0.6)
	f.taper(100, 176, 101, 192, 100, 205, 1.6)
	f.edges(0.26)
	# ---- torso back: the V repeats over a huge muscled back
	f = a["Torso_B"]
	f.fill(BLUE)
	f.path("M-5-5H205V10L100 92L-5 10Z", BLUE, stroke=INK, sw=2)
	f.soft("M20 0Q60 4 92 50Q70 64 44 42Q24 24 20 0Z", BLUE_L, 0.7, 4)
	f.soft("M180 0Q140 4 108 50Q130 64 156 42Q176 24 180 0Z", BLUE_L, 0.7, 4)
	f.taper(100, 0, 101, 40, 100, 80, 1.6)
	f.path("M-5 6L100 90L205 6V34L100 118L-5 34Z", RED, stroke=INK, sw=2.2)
	f.path("M-5 34L100 118L205 34V42L100 126L-5 42Z", GOLD, stroke=INK, sw=1.4)
	f.soft("M12 56Q50 62 90 124Q60 136 28 126Q10 96 12 56Z", BLUE_L, 0.7, 4)
	f.soft("M188 56Q150 62 110 124Q140 136 172 126Q190 96 188 56Z", BLUE_L, 0.7, 4)
	f.taper(100, 118, 102, 134, 100, 150, 2.0)
	f.taper(26, 100, 50, 128, 86, 138, 1.8, BLUE_D)
	f.taper(174, 100, 150, 128, 114, 138, 1.8, BLUE_D)
	f.path("M-5 150H205V170H-5Z", GOLD, stroke=INK, sw=2)
	f.path("M-5 170H205V205H-5Z", RED)
	f.taper(100, 176, 101, 192, 100, 205, 1.6)
	f.edges(0.26)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(BLUE)
		f.path("M-5-5H105V28Q50 44 -5 28Z", WHITE, stroke=INK, sw=1.6)
		f.path("M-5 10H105V34H-5Z", RED, stroke=INK, sw=1.6)
		f.soft("M16 50Q50 40 84 50Q78 100 50 140Q22 100 16 50Z", BLUE_L, 0.7, 4)
		for y in (66, 86, 106):
			f.taper(14, y, 40, y + 8, 60, y + 2, 1.5, BLUE_D)
		f.path("M-5 150H105V170H-5Z", GOLD, stroke=INK, sw=1.8)
		f.path("M-5 170H105V205H-5Z", RED)
		f.edges(0.34)
	for side in ("Left", "Right"):
		for key in "FBOI":
			arm(a[f"{side}Arm_{key}"], key, side)
			leg(a[f"{side}Leg_{key}"], key)
		a[f"{side}Arm_T"].fill(WHITE)
		a[f"{side}Arm_T"].path("M36-5H64V105H36Z", RED)
		a[f"{side}Arm_Bo"].fill(GOLD_D)
		a[f"{side}Leg_T"].fill(RED)
		a[f"{side}Leg_Bo"].fill(RED_D)
	hair = "#c9a724"
	nape(a["Head_B"], SKIN, hair, 76)
	a["Head_T"].fill(hair)
	a["Head_Bo"].fill(SKIN_D)
	for n, ear_x in (("Head_L", 56), ("Head_R", 64)):
		f = a[n]
		f.fill(SKIN)
		f.path("M-5-5H125V34H-5Z", hair)
		f.path(f"M{ear_x - 9} 54q9 -11 18 0q2 11 -6 22q-5 4 -8 -2q-5 -10 -4 -20Z", SKIN, stroke=INK, sw=1.4)
		f.soft("M-5 96H125V135H-5Z", SKIN_D, 0.85, 2)
	f = a["Torso_T"]
	f.fill(WHITE)
	f.path("M-5-5H205V8H-5Z", RED)
	f.path("M60 20H140V80H60Z", BLUE)
	a["Torso_Bo"].fill(RED_D)
