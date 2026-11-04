# Painted look for jk_king. Face, chest and arm marks close to the source design, drawn in-house (design doc 5).
from atlas import INK, paint_hair, shade
from jk_common import brow2, buried, eye2, flipped, form, hair_ink, hand, head_front, pal, side_face, trouser

SKIN = "#efc9a8"
SKIN_D = shade(SKIN, 0.68)
SKIN_L = "#ffe8d0"
TAT = "#121014"
PINK = "#D97C8A"
DARK = "#42302F"
UNI = pal("#22283b", "#0d101c", "#5a6a92", "#7488b8")
RED = "#8e1e24"
DEFAULT = SKIN
HAIR_COLOURS = [PINK, DARK]


def _back_swept():
	"""No fringe: spikes rise off a bare forehead and rake backwards, longest at the crown."""
	out = []
	for x, zb, zt, yt, sp, r in (
		(0.0, 5.16, 5.88, -0.28, 0.0, 0.24),
		(0.24, 5.16, 5.92, -0.2, 0.08, 0.24),
		(-0.24, 5.16, 5.9, -0.2, -0.08, 0.24),
		(0.48, 5.14, 5.76, -0.22, 0.26, 0.21),
		(-0.48, 5.14, 5.78, -0.22, -0.26, 0.21),
	):
		out.append({"b": [x, -0.56, zb], "c": [x + sp * 0.3, -0.62, (zb + zt) / 2 + 0.06], "t": [x + sp, yt, zt], "r": r})
	# the middle of the hairline: a low wide lock so no root shows
	out.append({"b": [0.02, -0.5, 5.1], "c": [0.02, -0.72, 5.42], "t": [-0.04, -0.46, 5.74], "r": 0.27})
	# crown rows rake back
	for y, z, zt, yt in ((-0.2, 5.28, 6.02, 0.34), (0.14, 5.28, 5.96, 0.76), (0.42, 5.2, 5.74, 1.12)):
		for x, sp in ((0.0, 0.0), (0.28, 0.14), (-0.28, -0.14), (0.54, 0.34), (-0.54, -0.34)):
			out.append({"b": [x, y, z - 0.04 * abs(x)], "c": [x + sp * 0.3, y + 0.14, (z + zt) / 2 + 0.1], "t": [x + sp, yt, zt - 0.5 * abs(x)], "r": 0.24 - 0.05 * abs(x)})
	# temple blades, flat against the head and raked to the rear
	for sgn in (1, -1):
		out.append({"b": [sgn * 0.62, -0.42, 5.14], "c": [sgn * 0.76, -0.16, 5.3], "t": [sgn * 1.0, 0.36, 5.5], "r": 0.17})
		out.append({"b": [sgn * 0.62, -0.08, 5.14], "c": [sgn * 0.78, 0.22, 5.24], "t": [sgn * 1.02, 0.72, 5.34], "r": 0.17})
		out.append({"b": [sgn * 0.56, 0.3, 5.14], "c": [sgn * 0.72, 0.6, 5.16], "t": [sgn * 0.9, 1.02, 5.18], "r": 0.16})
	# back: down and out
	for x in (0.0, 0.32, -0.32):
		out.append({"b": [x, 0.54, 5.14], "c": [x * 1.1, 0.86, 5.1], "t": [x * 1.2, 1.1, 4.94], "r": 0.2})
	return out


HAIR = {"colour": PINK, "cap": {"size": [1.22, 1.14, 0.28], "at": [0, 0, 5.2], "bevel": 0.12}, "locks": buried(_back_swept())}


def _feet(colour, box, at, bevel=0.05):
	return [{"part": part, "box": box, "at": [sgn * at[0], at[1], at[2]], "colour": colour, "bevel": bevel} for part, sgn in (("LeftFoot", 1), ("RightFoot", -1))]


PROPS = [
	*_feet("#E2DCD2", [1.0, 0.34, 0.15], (0.5, -0.6, 0.11)),
	*_feet("#E2DCD2", [1.02, 1.34, 0.09], (0.5, -0.1, 0.045)),
]


def bar(f, x0, y0, x1, y1, t=2.6, colour=TAT):
	"""A tattoo stroke: blunt in the middle, pointed at both ends."""
	f.taper(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2, x1, y1, t, colour)


def _arm(f, key):
	"""A bare fighting arm with the marks wrapped round: shoulder, upper arm, and the two wrist bands."""
	f.fill(SKIN)
	sx = {"F": 28, "B": 66, "O": 34, "I": 64}[key]
	f.soft(f"M{sx - 18} 10Q{sx} 2 {sx + 18} 10L{sx + 16} 36Q{sx} 44 {sx - 16} 36Z", SKIN_L, 0.75, 5)
	f.soft(f"M{sx - 14} 54L{sx + 14} 54L{sx + 12} 92L{sx - 12} 92Z", SKIN_L, 0.55, 5)
	f.soft(f"M{sx - 10} 112L{sx + 10} 112L{sx + 8} 150L{sx - 8} 150Z", SKIN_L, 0.45, 3)
	f.taper(10, 44, 50, 54, 92, 42, 1.5, shade(SKIN, 0.42))  # deltoid
	f.taper(16, 56, 12, 78, 22, 98, 1.4, shade(SKIN, 0.42))  # biceps
	f.taper(84, 56, 88, 78, 76, 98, 1.4, shade(SKIN, 0.42))
	f.taper(34, 104, 50, 108, 66, 104, 1.1, shade(SKIN, 0.42))  # elbow
	f.taper(20, 116, 16, 136, 24, 152, 1.2, shade(SKIN, 0.45))  # forearm
	f.taper(80, 116, 84, 136, 76, 152, 1.2, shade(SKIN, 0.45))
	f.soft("M-5 96H105V112H-5Z", SKIN_D, 0.5, 3)
	form(f, "#5a2c1c", 0.55)
	# wrapped marks: the same bands on all four sides
	f.path("M-5 22L50 28L105 22V29L50 35L-5 29Z", TAT)
	f.path("M-5 70L50 76L105 70V77L50 83L-5 77Z", TAT)
	f.path("M-5 124L50 128L105 124V129L50 133L-5 129Z", TAT)
	f.path("M-5 150H105V157H-5Z", TAT)
	f.path("M-5 161H105V168H-5Z", TAT)
	if key == "O":  # the long outer stroke joining the bands
		bar(f, 50, 34, 50, 70, 2.4)
		bar(f, 50, 84, 50, 122, 2.2)
	hand(f, SKIN, key, 172)


def _shoe(f, key):
	top = 164
	f.path(f"M-5 {top}H105V206H-5Z", RED)
	f.soft(f"M12 {top + 4}H38V{top + 22}H12Z", "#cf4b4c", 0.5, 3)
	f.ink(f"M-5 {top}H105", 1.6)
	f.path("M-5 186H105V206H-5Z", "#e2dcd2")
	f.ink("M-5 186H105", 1.3)
	f.path("M-5 194H105V206H-5Z", "#bdb6aa")
	if key == "F":
		f.path(f"M34 {top + 3}H66V186H34Z", "#e2dcd2", stroke=INK, sw=1)
		for y in range(top + 7, 184, 5):
			f.ink(f"M36 {y}L64 {y + 1.5}M64 {y}L36 {y + 1.5}", 0.9, "#333")


def _head_side(f):
	side_face(f, SKIN, 66, 62)
	f.path("M16 -5L14 30L22 44L36 34Q56 28 80 38Q90 58 92 80L110 94L125 84V-5Z", DARK)
	for i in range(30):
		x = 18 + i * 3.6
		f.taper(x, 12, x + 1, 30, x + f.rng.uniform(-2, 2), 36 + (i % 3) * 4, 0.5, "#6a5250")
	f.path("M-5 -5H125V10L104 20L82 12L60 20L38 12L16 20L-5 10Z", PINK)
	f.taper(-5, 5, 60, 7, 125, 5, 2, shade(PINK, 1.2))
	# the cheek bar's tail just rounds the corner of the face
	f.path("M-5 88L14 91L-5 95Z", TAT)


def paint(a):
	paint_hair(a, [PINK, "#5c4644"])
	hair_ink(a, 0, 2, PINK, gap=0.42, shine=1.25)
	# ---- face: the second pair of eyes under the first, the bars and the grin
	f = a["Head_F"]
	head_front(f, SKIN, hair_shadow=14, jaw_y=86, chin_y=126, chin_w=17)
	f.path("M-5 -5H16L10 24L8 42L-5 46Z", DARK)
	f.path("M135 -5H114L120 24L122 42L135 46Z", DARK)
	# main eyes: narrowed, savage slant, small slit pupils
	eye2(f, 42, 58, -1, 27, 9.5, "#d11f24", tilt=5.2, r=6.6, lid=0.25, lash_t=3, flick=4, slit=True, pupil=0.32, sclera="#f6e9dd", crease_line=False)
	eye2(f, 88, 58, 1, 27, 9.5, "#d11f24", tilt=5.2, r=6.6, lid=0.25, lash_t=3, flick=4, slit=True, pupil=0.32, sclera="#f6e9dd", crease_line=False)
	brow2(f, 41, 42, -1, 29, 5.2, 6.4, "#53353b", arc=-1)
	brow2(f, 89, 42, 1, 29, 5.2, 6.4, "#53353b", arc=-1)
	f.taper(60, 48, 62, 54, 61, 60, 0.9, shade(SKIN, 0.45))
	f.taper(70, 48, 68, 54, 69, 60, 0.9, shade(SKIN, 0.45))
	# second eyes: small open slits directly under the first
	eye2(f, 40, 77, -1, 16, 5, "#d11f24", tilt=2.2, r=3.6, lash_t=1.6, flick=1.5, slit=True, pupil=0.34, sclera="#f6e9dd", crease_line=False)
	eye2(f, 90, 77, 1, 16, 5, "#d11f24", tilt=2.2, r=3.6, lash_t=1.6, flick=1.5, slit=True, pupil=0.34, sclera="#f6e9dd", crease_line=False)
	# cheek bars under the second eyes, running to the edge of the face
	f.path("M-5 86L20 88L52 84L32 92L10 95L-5 94Z", TAT)
	f.path("M135 86L110 88L78 84L98 92L120 95L135 94Z", TAT)
	# forehead: two bars each side, angled in to the centre
	bar(f, 62, 34, 36, 21, 2.4)
	bar(f, 68, 34, 94, 21, 2.4)
	bar(f, 58, 25, 40, 13, 1.8)
	bar(f, 72, 25, 90, 13, 1.8)
	# bar over the nose
	f.path("M56 73H74L72 77H58Z", TAT)
	f.path("M66 79L69.5 92L62 94Q65 87 66 79Z", shade(SKIN, 0.62), opacity=0.9)
	# the grin: wide, pulled up hard on one side, full of pointed teeth
	f.path("M36 101Q64 109 96 96Q94 117 66 119Q42 117 36 101Z", "#37080c", stroke=INK, sw=1.5)
	f.path("M38 101.6Q64 109.4 94 97L92 103Q78 104 66 110Q50 107 40 106Z", "#f4eee2")
	for x, y in ((45, 104), (52, 106), (59, 108), (67, 109), (75, 106.6), (83, 104), (90, 100)):
		f.path(f"M{x - 3} {y - 2}L{x + 3} {y - 2}L{x} {y + 4.2}Z", "#f4eee2", stroke="#7a7076", sw=0.3)
	for x, y in ((46, 116), (56, 118), (66, 118.4), (76, 117), (86, 113)):
		f.path(f"M{x - 3} {y}L{x + 3} {y}L{x} {y - 5.5}Z", "#f4eee2", stroke="#7a7076", sw=0.3)
	f.ink("M30 96Q33 98 36 101", 1.4)
	f.ink("M100 90Q98 93 96 96", 1.4)
	f.taper(25, 92, 28, 100, 32, 106, 0.7, shade(SKIN, 0.5))
	# chin bars
	f.path("M56 120.6H74L72 123H58Z", TAT)
	# ---- sides and back
	_head_side(a["Head_L"])
	with flipped(a["Head_R"]):
		_head_side(a["Head_R"])
	f = a["Head_B"]
	f.fill(shade(SKIN, 0.6))
	f.path("M-5 -5H135V90L118 100L104 90L88 104L70 92L52 106L36 92L20 102L-5 90Z", DARK)
	for i in range(36):
		x = 2 + i * 3.6
		f.taper(x, 26, x + 1, 52, x + f.rng.uniform(-2, 2), 78 + (i % 4) * 5, 0.5, "#6a5250")
	f.path("M-5 -5H135V26L118 38L100 24L84 42L66 26L48 42L30 24L14 38L-5 26Z", PINK)
	form(f, "#180e12", 0.35)
	a["Head_T"].fill(PINK)
	a["Head_Bo"].fill(shade(SKIN, 0.5))
	# ---- bare torso: pecs, abs, and the marks: pec chevrons, centre line, rib stripes
	line = shade(SKIN, 0.42)
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M22 14Q56 4 94 18Q94 56 56 66Q22 58 22 14Z", SKIN_L, 0.65, 8)
	f.soft("M178 14Q144 4 106 18Q106 54 144 64Q178 56 178 14Z", SKIN_L, 0.45, 8)
	for y in (84, 108, 132):
		f.soft(f"M70 {y}L96 {y}L96 {y + 18}L72 {y + 18}Z", SKIN_L, 0.55, 3)
		f.soft(f"M104 {y}L130 {y}L128 {y + 18}L104 {y + 18}Z", SKIN_L, 0.35, 3)
	f.soft("M-5 70Q24 112 44 172H-5Z", SKIN_D, 0.75, 5)
	f.soft("M205 70Q176 112 156 172H205Z", SKIN_D, 0.85, 5)
	f.soft("M16 62Q60 84 98 64L98 72Q60 92 18 72Z", SKIN_D, 0.75, 3)
	f.soft("M184 62Q140 84 102 64L102 72Q140 92 182 72Z", SKIN_D, 0.85, 3)
	f.taper(14, 66, 56, 84, 99, 62, 2, line)  # pec underside
	f.taper(186, 66, 144, 84, 101, 62, 2, line)
	f.taper(100, 8, 100, 90, 100, 172, 1.4, line)  # centre line
	for y in (84, 108, 132, 154):
		f.taper(68, y, 84, y + 3, 98, y, 1.2, line)
		f.taper(132, y, 116, y + 3, 102, y, 1.2, line)
	f.taper(66, 82, 62, 118, 68, 170, 1.4, line)
	f.taper(134, 82, 138, 118, 132, 170, 1.4, line)
	f.taper(60, 8, 80, 14, 96, 8, 1.2, line)  # clavicles
	f.taper(140, 8, 120, 14, 104, 8, 1.2, line)
	for sgn in (-1, 1):
		x = lambda d: 100 + sgn * d
		# pec chevrons
		f.path(f"M{x(90)} 28L{x(38)} 44L{x(8)} 30L{x(8)} 38L{x(38)} 53L{x(90)} 37Z", TAT)
		f.path(f"M{x(92)} 10L{x(52)} 22L{x(24)} 14L{x(26)} 20L{x(52)} 29L{x(92)} 18Z", TAT)
		# rib stripes
		for y, d0, d1 in ((88, 94, 46), (108, 94, 50), (128, 92, 52), (148, 90, 50)):
			f.path(f"M{x(d0)} {y - 4}L{x(d1)} {y + 3}L{x(d0)} {y + 5}Z", TAT)
	f.path("M100 56L106 72L100 88L94 72Z", TAT)  # sternum diamond
	# waistband of the trousers
	f.path("M-5 174H205V210H-5Z", UNI["base"])
	f.soft("M-5 178H205V210H-5Z", UNI["sheen"], 0.18, 3)
	f.ink("M-5 174Q100 178 205 174", 1.8)
	f.path("M-5 174H205V182H-5Z", "#16181f")
	f.ink("M-5 182H205", 1)
	for x in (40, 160):
		f.path(f"M{x - 4} 172H{x + 4}V186H{x - 4}Z", "#20232c", stroke=INK, sw=0.8)
	f.taper(100, 182, 99, 196, 100, 210, 1.2)
	form(f, "#5a2c1c", 0.5)
	f = a["Torso_B"]
	f.fill(SKIN)
	f.soft("M14 16Q60 2 94 26Q86 66 48 74Q14 62 14 16Z", SKIN_L, 0.6, 8)
	f.soft("M186 16Q140 2 106 26Q114 66 152 74Q186 62 186 16Z", SKIN_L, 0.42, 8)
	f.soft("M95 -5L105 -5L104 172L96 172Z", SKIN_D, 0.5, 3)
	f.taper(100, 8, 100, 90, 100, 172, 1.4, line)
	f.taper(10, 26, 44, 70, 92, 58, 1.4, line)
	f.taper(190, 26, 156, 70, 108, 58, 1.4, line)
	f.taper(20, 120, 50, 96, 90, 96, 1.2, line)
	f.taper(180, 120, 150, 96, 110, 96, 1.2, line)
	for sgn in (-1, 1):
		x = lambda d: 100 + sgn * d
		f.path(f"M{x(92)} 18L{x(20)} 34L{x(10)} 26L{x(12)} 34L{x(20)} 42L{x(92)} 28Z", TAT)
		for y, d0, d1 in ((74, 94, 26), (98, 94, 36), (122, 92, 40), (146, 90, 40)):
			f.path(f"M{x(d0)} {y - 4}L{x(d1)} {y + 3}L{x(d0)} {y + 5}Z", TAT)
	f.path("M-5 174H205V210H-5Z", UNI["base"])
	f.path("M-5 174H205V182H-5Z", "#16181f")
	f.ink("M-5 174Q100 178 205 174", 1.8)
	f.ink("M-5 182H205", 1)
	form(f, "#5a2c1c", 0.5)
	for name in ("Torso_L", "Torso_R"):
		f = a[name]
		f.fill(SKIN)
		f.soft("M14 10Q50 0 88 12L84 60L18 58Z", SKIN_L, 0.55, 5)
		f.taper(50, 6, 56, 80, 50, 172, 1.0, shade(SKIN, 0.55))
		for y, up in ((88, 0), (108, 0), (128, 0), (148, 0)):
			f.path(f"M-5 {y - 4}L60 {y}L-5 {y + 5}Z", TAT)
			f.path(f"M105 {y - 4}L60 {y}L105 {y + 5}Z", TAT)
		f.path("M-5 174H105V210H-5Z", UNI["base"])
		f.path("M-5 174H105V182H-5Z", "#16181f")
		f.ink("M-5 174H105M-5 182H105", 1.4)
		form(f, "#5a2c1c", 0.55)
	a["Torso_T"].fill(SKIN)
	a["Torso_Bo"].fill(UNI["dark"])
	for side in ("Left", "Right"):
		for key in "FBOI":
			_arm(a[f"{side}Arm_{key}"], key)
			f = a[f"{side}Leg_{key}"]
			trouser(f, UNI, key, seed=side + "k", shoe_top=164)
			_shoe(f, key)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN)
		a[f"{side}Leg_T"].fill(UNI["base"])
		a[f"{side}Leg_Bo"].fill("#bdb6aa")
