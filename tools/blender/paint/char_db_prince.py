# Painted look for db_prince: battle armour over a blue bodysuit, the flame of hair with the deep widow's peak, a scowl.
from atlas import INK, paint_hair, shade
from db_common import sculpted_head, bare_arm, cuff, dome, fist, head_faces, limb_faces, loft, mirrored, shards, sharp_eye, slab_brow, toe

SKIN = "#efbf94"
SKIN_D = shade(SKIN, 0.64)
SUIT = "#21409f"
SUIT_D = "#122466"
SUIT_L = "#5474d6"
WHITE = "#ffffff"
WHITE_D = "#bcc0cf"
GOLD = "#e6b32f"
GOLD_D = "#a06f12"
GOLD_L = "#ffe38a"
HAIRC = "#101116"
HAIR_INK = "#22242e"
DEFAULT = SUIT
HAIR_COLOURS = [HAIRC]
HAIR = {"colour": HAIRC, "locks": []}
PROPS = []
# z, half width, front depth, back depth: the jaw as this character has it
HEAD = ((4.0, 0.22, 0.42, 0.12), (4.08, 0.36, 0.53, 0.3), (4.22, 0.5, 0.58, 0.46), (4.42, 0.6, 0.6, 0.56), (4.62, 0.64, 0.6, 0.6), (5.0, 0.65, 0.6, 0.6), (5.22, 0.62, 0.58, 0.58), (5.3, 0.5, 0.46, 0.46))

# Everything rises: one narrowing flame, jagged at its edges, no fringe at all.
SPIKES = [
	# front wall of the flame
	((0.0, -0.5, 5.0), (0.0, -0.4, 6.0), (0.03, -0.1, 7.0), 0.46),
	((-0.28, -0.52, 5.12), (-0.33, -0.42, 5.9), (-0.24, -0.14, 6.6), 0.4),
	((0.28, -0.52, 5.12), (0.33, -0.42, 5.9), (0.26, -0.14, 6.66), 0.4),
	((-0.54, -0.48, 5.08), (-0.72, -0.32, 5.68), (-0.6, -0.08, 6.22), 0.34),
	((0.54, -0.48, 5.08), (0.72, -0.32, 5.68), (0.64, -0.08, 6.28), 0.34),
	((-0.68, -0.14, 4.98), (-0.94, -0.06, 5.38), (-0.92, 0.05, 5.84), 0.28),
	((0.68, -0.14, 4.98), (0.94, -0.06, 5.4), (0.97, 0.05, 5.9), 0.28),
	# middle
	((-0.12, 0.08, 5.35), (-0.16, 0.1, 6.1), (-0.12, 0.26, 6.86), 0.4),
	((0.18, 0.08, 5.35), (0.2, 0.1, 6.0), (0.16, 0.26, 6.74), 0.38),
	((-0.42, 0.1, 5.3), (-0.54, 0.14, 5.95), (-0.44, 0.26, 6.42), 0.34),
	((0.42, 0.1, 5.3), (0.54, 0.14, 5.95), (0.46, 0.26, 6.48), 0.34),
	((-0.66, 0.16, 5.06), (-0.88, 0.22, 5.46), (-0.84, 0.32, 5.98), 0.28),
	((0.66, 0.16, 5.06), (0.88, 0.22, 5.46), (0.88, 0.32, 6.02), 0.28),
	# the back of the flame, nape to crown
	((0.0, 0.42, 5.2), (0.0, 0.52, 6.0), (0.0, 0.66, 6.68), 0.42),
	((-0.34, 0.44, 5.14), (-0.44, 0.52, 5.8), (-0.36, 0.66, 6.26), 0.36),
	((0.34, 0.44, 5.14), (0.44, 0.52, 5.8), (0.38, 0.66, 6.3), 0.36),
	((-0.62, 0.4, 4.92), (-0.8, 0.48, 5.3), (-0.76, 0.62, 5.72), 0.28),
	((0.62, 0.4, 4.92), (0.8, 0.48, 5.3), (0.78, 0.62, 5.76), 0.28),
	((0.0, 0.6, 4.86), (0.02, 0.76, 5.32), (-0.02, 0.92, 5.92), 0.36),
	((-0.34, 0.6, 4.72), (-0.42, 0.76, 5.12), (-0.42, 0.9, 5.56), 0.3),
	((0.34, 0.6, 4.72), (0.42, 0.76, 5.12), (0.44, 0.9, 5.6), 0.3),
	((-0.56, 0.54, 4.56), (-0.7, 0.68, 4.86), (-0.74, 0.8, 5.18), 0.22),
	((0.56, 0.54, 4.56), (0.7, 0.68, 4.86), (0.76, 0.8, 5.2), 0.22),
	((0.0, 0.62, 4.5), (0.0, 0.76, 4.8), (0.0, 0.88, 5.2), 0.28),
]


def _flap(kit, part, name, sgn):
	"""Shoulder flap: flat on the shoulder, bent down past the arm's outer edge."""
	col = GOLD
	row = lambda x, z: [(sgn * x, -0.46, z), (sgn * x, 0.46, z), (sgn * x, 0.46, z + 0.1), (sgn * x, -0.46, z + 0.1)]
	return loft(kit, name, [row(0.95, 4.04), row(1.5, 4.08), row(1.95, 4.04), row(2.14, 3.86), row(2.2, 3.56)], col, part)


def _hipflap(kit, part, name, sgn, y):
	rows = [
		[(sgn * 0.42, y, 2.42), (sgn * 1.0, y, 2.42), (sgn * 1.0, y + (0.05 if y > 0 else -0.05), 2.42), (sgn * 0.42, y + (0.05 if y > 0 else -0.05), 2.42)],
		[(sgn * 0.46, y * 1.1, 1.86), (sgn * 1.05, y * 1.1, 1.86), (sgn * 1.05, y * 1.1 + (0.05 if y > 0 else -0.05), 1.86), (sgn * 0.46, y * 1.1 + (0.05 if y > 0 else -0.05), 1.86)],
	]
	return loft(kit, name, rows, GOLD, part)


def model(parts, kit):
	sculpted_head(kit, parts, HEAD, SKIN_D, n=5)
	for sgn in (1, -1):
		dome(kit, f"Head_Ear{sgn}", (sgn * 0.65, 0.04, 4.66), (0.08, 0.13, 0.17), SKIN, parts["Head"], full=True, nu=8, nv=3)
	head = parts["Head"]
	# the hair mass and its M-shaped hairline, seen in front; the peak drops to the brow line
	dome(kit, "Head_Skull", (0, 0.2, 4.9), (0.67, 0.62, 0.52), HAIRC, head).__setitem__("lock", ((0, 0, 4.9), (0, 0, 5.42)))
	line = [(-0.66, 4.86), (-0.58, 5.02), (-0.42, 5.16), (-0.22, 5.12), (0.0, 4.86), (0.22, 5.12), (0.42, 5.16), (0.58, 5.02), (0.66, 4.86), (0.62, 5.3), (0.0, 5.36), (-0.62, 5.3)]
	kit.blade("Head_Hairline", line, (-0.63, -0.2), HAIRC, head, (0, -0.64, 4.9), (0, -0.4, 5.4))
	shards(kit, parts, HAIRC, SPIKES)
	t = parts["UpperTorso"]
	for sgn, side in ((1, "Left"), (-1, "Right")):
		arm, foot = parts[side + "UpperArm"], parts[side + "Foot"]
		_flap(kit, arm, side + "UpperArm_Flap", sgn)
		cuff(kit, arm, side + "UpperArm_Sleeve", sgn * 1.5, 3.44, 0.1, SUIT, w=1.06)
		cuff(kit, arm, side + "Hand_GloveTop", sgn * 1.5, 2.86, 0.14, WHITE, w=1.08)
		_hipflap(kit, t, f"UpperTorso_HipF{side}", sgn, -0.56)
		_hipflap(kit, t, f"UpperTorso_HipB{side}", sgn, 0.56)
		cuff(kit, foot, side + "Foot_Top", sgn * 0.5, 1.02, 0.14, GOLD, w=1.08)
		toe(kit, foot, side + "Foot_Toe", sgn * 0.5, GOLD, GOLD, reach=0.36, h=0.42)
	# armour neck ring
	kit.rbox("UpperTorso_Collar", (1.06, 0.72, 0.14), (0, 0, 4.02), SUIT, t, bevel=0.04)


def paint_face(f):
	f.fill(SKIN)
	f.path("M135 70H119Q114 96 100 112Q84 122 65 125V135H135Z", SKIN_D, opacity=0.8)
	f.path("M-5 92H9Q18 106 32 116Q48 123 65 125V135H-5Z", SKIN_D, opacity=0.5)
	# widow's peak painted under the blade so no block corner shows skin
	f.path("M-5-5H135V30L120 20L104 8L84 12L65 44L46 12L26 8L10 20L-5 30Z", HAIRC)
	f.path("M65 44L52 22L46 12L38 30L50 46Z", SKIN_D, opacity=0.8)
	f.path("M65 44L78 22L84 12L92 30L80 46Z", SKIN_D, opacity=0.8)
	f.path("M4 20Q10 50 8 70L-5 70V20Z", SKIN_D, opacity=0.7)
	f.path("M126 20Q120 50 122 70L135 70V20Z", SKIN_D, opacity=0.85)
	f.path("M64 62Q67 76 62 90L69 90Q72 74 67 62Z", SKIN_D, opacity=0.5)
	# the scowl: brows that nearly meet, crushed down
	slab_brow(f, 40, 60, -1, HAIRC, w=36, thick=9, angry=14)
	slab_brow(f, 90, 60, 1, HAIRC, w=36, thick=9, angry=14)
	sharp_eye(f, 37, 72, -1, w=29, h=11, slant=8, pupil=4.2, look=2, lid=2.8, top_arc=-0.5, shine=False)
	sharp_eye(f, 93, 72, 1, w=29, h=11, slant=8, pupil=4.2, look=-2, lid=2.8, top_arc=-0.5, shine=False)
	# furrows
	line = shade(SKIN, 0.42)
	f.taper(61, 46, 64, 54, 61, 62, 0.9, line)
	f.taper(69, 46, 66, 54, 69, 62, 0.9, line)
	f.taper(56, 42, 60, 50, 57, 60, 0.6, line)
	f.taper(74, 42, 70, 50, 73, 60, 0.6, line)
	# nose, cheek lines, a flat down-turned mouth
	f.path("M66 84L60 96L69 97Z", shade(SKIN, 0.7))
	f.ink("M59 97Q64 99 69 97", 1.2, shade(SKIN, 0.35))
	f.path("M44 113Q58 104 66 107Q74 104 88 113Q74 110 65 111Q56 110 44 113Z", INK)
	f.taper(44, 113, 43, 117, 46, 120, 0.9, INK)
	f.taper(88, 113, 89, 117, 86, 120, 0.9, INK)
	f.taper(56, 119, 65, 122, 74, 119, 0.8, line)


def armour_front(f):
	f.fill(SUIT)
	# suit at the neck
	f.path("M60-5H140V10Q100 28 60 10Z", SUIT_D)
	# chest plate: two hard shells, a centre ridge, rolled top edge
	chest = "M6 14Q60 8 72 14Q100 30 128 14Q140 8 194 14Q200 60 194 96Q150 112 100 106Q50 112 6 96Q0 60 6 14Z"
	f.path(chest, WHITE, stroke=INK, sw=2.4)
	f.path("M6 68Q40 92 92 78L96 104Q50 112 6 96Z", WHITE_D, opacity=0.7)
	f.path("M194 60Q160 92 108 78L104 104Q150 112 194 96Z", WHITE_D, opacity=0.9)
	f.path("M12 18Q60 12 72 20Q100 36 128 20Q140 12 188 18L186 24Q140 20 128 26Q100 42 72 26Q60 20 14 24Z", "#ffffff")
	f.taper(100, 32, 102, 70, 100, 106, 1.6)
	f.taper(10, 66, 54, 92, 94, 76, 1.8)
	f.taper(190, 66, 146, 92, 106, 76, 1.8)
	f.taper(30, 28, 40, 50, 28, 62, 0.8, WHITE_D)
	f.taper(170, 28, 160, 50, 172, 62, 0.8, WHITE_D)
	# gold belly plate with ribs
	f.path("M14 100Q100 116 186 100L176 156Q100 168 24 156Z", GOLD, stroke=INK, sw=2.2)
	f.path("M150 106L186 100L176 156L140 162Z", GOLD_D, opacity=0.65)
	f.path("M16 104Q100 120 184 104L183 110Q100 126 17 110Z", GOLD_L, opacity=0.8)
	f.taper(100, 112, 102, 136, 100, 164, 1.4)
	for y in (122, 138):
		f.taper(22, y, 62, y + 8, 98, y + 6, 1.2, GOLD_D)
		f.taper(178, y, 138, y + 8, 102, y + 6, 1.2, GOLD_D)
	# suit below the plate
	f.path("M100 170V200", stroke=INK, sw=2)
	f.path("M30 176Q70 190 98 198L60 200H10Z", SUIT_D, opacity=0.7)
	f.path("M170 176Q130 190 102 198L140 200H190Z", SUIT_D, opacity=0.85)
	f.edges(0.2)


def armour_back(f):
	f.fill(SUIT)
	f.path("M60-5H140V8Q100 22 60 8Z", SUIT_D)
	f.path("M6 12Q100 28 194 12Q200 60 196 100Q100 116 4 100Q0 60 6 12Z", WHITE, stroke=INK, sw=2.4)
	f.path("M4 80Q50 100 90 86L96 110Q50 110 4 100Z", WHITE_D, opacity=0.7)
	f.path("M196 70Q150 100 110 86L104 110Q150 110 196 100Z", WHITE_D, opacity=0.9)
	f.taper(100, 22, 102, 60, 100, 108, 1.5)
	f.taper(18, 30, 46, 66, 86, 82, 1.5)
	f.taper(182, 30, 154, 66, 114, 82, 1.5)
	f.path("M14 100Q100 116 186 100L176 156Q100 168 24 156Z", GOLD, stroke=INK, sw=2.2)
	f.path("M150 106L186 100L176 156L140 162Z", GOLD_D, opacity=0.65)
	for y in (122, 138):
		f.taper(22, y, 100, y + 10, 178, y, 1.2, GOLD_D)
	f.path("M100 170V200", stroke=INK, sw=2)
	f.edges(0.2)


def armour_side(f):
	f.fill(SUIT)
	f.path("M-5 10Q50 16 105 10V96Q50 108 -5 96Z", WHITE, stroke=INK, sw=2)
	f.path("M60 10Q70 60 56 102L105 96V10Z", WHITE_D, opacity=0.7)
	f.path("M-5 100Q50 112 105 100L100 156Q50 166 0 156Z", GOLD, stroke=INK, sw=2)
	f.path("M60 106L105 100L100 156L60 162Z", GOLD_D, opacity=0.6)
	for y in (122, 138):
		f.taper(2, y, 50, y + 8, 98, y, 1.2, GOLD_D)
	# the strap that holds front and back shells together
	f.path("M38 18H62V96H38Z", "#2a2a33", stroke=INK, sw=1.2)
	f.edges(0.26)


def paint_arm(f, key):
	bare_arm(f, key, SKIN, top=0, wrist=172)
	# short suit sleeve
	f.path("M-5-5H105V60H-5Z", SUIT)
	f.path("M72-5Q84 26 76 60H105V-5Z", SUIT_D, opacity=0.65)
	f.taper(10, 18, 34, 34, 46, 46, 1.2, SUIT_D)
	f.taper(90, 20, 68, 34, 56, 48, 1.2, SUIT_D)
	# long glove, wrinkled at the wrist; closed fist in white
	white = WHITE
	f.path("M-5 112H105V210H-5Z", white)
	f.path("M74 112Q86 150 76 172L105 170V112Z", WHITE_D, opacity=0.8)
	f.taper(8, 148, 30, 156, 50, 150, 1.2, WHITE_D)
	f.taper(92, 138, 70, 146, 54, 140, 1.2, WHITE_D)
	f.taper(12, 164, 50, 170, 90, 164, 1.3, "#6f7382")
	fist(f, key, white, y=174, line="#5b5f6e")


def paint_leg(f, key):
	f.fill(SUIT)
	f.path("M74 0Q90 40 78 92H105V0Z", SUIT_D, opacity=0.65)
	f.folds(4, SUIT_D, SUIT_L, y0=0.04, y1=0.36, pinch=(50, 80), width=1.4)
	f.taper(30, 66, 50, 80, 72, 66, 1.3, SUIT_D)  # knee
	# tall white boot with a gold shin and foot
	f.path("M-5 90H105V205H-5Z", WHITE)
	f.path("M72 90Q88 150 78 184H105V90Z", WHITE_D, opacity=0.8)
	f.taper(10, 124, 50, 132, 90, 124, 1.1, WHITE_D)
	f.taper(16, 152, 50, 160, 84, 152, 1.1, WHITE_D)
	f.path("M-5 176H105V205H-5Z", GOLD)
	f.path("M60 176H105V205H60Z", GOLD_D, opacity=0.5)
	f.ink("M-5 176H105", 1.8)
	f.path("M-5 196H105V205H-5Z", shade(GOLD_D, 0.7))


def paint(a):
	paint_hair(a, [HAIR_INK])
	paint_face(a["Head_F"])
	armour_front(a["Torso_F"])
	armour_back(a["Torso_B"])
	for f, mir in head_faces(a, "Torso"):
		with mirrored(f, mir):
			armour_side(f)
	for _, key, f, mir in limb_faces(a, "Arm"):
		with mirrored(f, mir):
			paint_arm(f, key)
		f.edges(0.2)
	for _, key, f, mir in limb_faces(a, "Leg"):
		with mirrored(f, mir):
			paint_leg(f, key)
		f.edges(0.22)
	for f, mir in head_faces(a):
		with mirrored(f, mir):
			f.fill(SKIN)
			f.path("M-5 104Q60 120 125 104V135H-5Z", SKIN_D, opacity=0.9)
			f.path("M26-5H125V110Q96 102 82 72L74 40L60 56L50 28L34 22Z", HAIRC)
			f.path("M-5-5H26L34 22L6 10Z", HAIRC)
			f.path("M50 62Q60 52 72 62Q74 78 62 92Q52 94 50 82Z", SKIN, stroke=INK, sw=2)
			f.ink("M56 66Q62 60 66 68Q66 76 62 82", 1.4, shade(SKIN, 0.45))
			f.taper(90, 6, 96, 50, 100, 92, 1.6, "#3a3d4a")
		f.edges(0.22)
	f = a["Head_B"]
	f.fill(SKIN_D)
	# hair down to the nape in rising points
	f.path("M-5-5H135V88L120 104L104 84L90 110L72 88L58 114L40 86L26 106L10 86L-5 96Z", HAIRC)
	for x in (20, 46, 72, 98, 118):
		f.taper(x, 0, x + 3, 40, x - 2, 80, 1.6, "#343745")
	a["Head_T"].fill(HAIRC)
	a["Head_Bo"].fill(SKIN_D)
	a["Torso_T"].fill(WHITE)
	a["Torso_Bo"].fill(SUIT_D)
	for side in ("Left", "Right"):
		a[f"{side}Arm_T"].fill(SUIT)
		a[f"{side}Arm_Bo"].fill("#8f93a2")
		a[f"{side}Leg_T"].fill(SUIT)
		a[f"{side}Leg_Bo"].fill(GOLD_D)
