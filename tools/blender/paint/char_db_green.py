# Painted look for db_green: green-skinned, pointed ears, white turban, weighted pauldrons and a long cape over a purple gi,
# pink muscle patches on the arms.
from atlas import INK, shade
from db_common import lit, sculpted_head, bare_arm, cuff, dome, fist, head_faces, limb_faces, loft, mirrored, shard, sharp_eye, toe
import math

SKIN = "#6dbc42"
SKIN_D = "#3d7f26"
SKIN_DD = "#265418"
SKIN_L = "#a4dc6e"
PINK = "#d9796e"
PINK_D = "#a64a44"
GI = "#4d2d8e"
GI_D = "#2a1558"
GI_L = "#8a66d4"
SASH = "#3478c8"
SASH_D = "#1c4a8a"
SASH_L = "#7cb4ee"
RED = "#c8302f"
SHOE = "#7c4f24"
SHOE_D = "#4a2c10"
CLOTH = "#f4f3ee"
CLOTH_D = "#b7b7c4"
CAPE_FOLD = "#dfdfe8"
DEFAULT = GI
HAIR_COLOURS = []
HAIR = {"colour": CLOTH, "locks": []}
PROPS = []
# z, half width, front depth, back depth: the jaw as this character has it
HEAD = ((3.98, 0.2, 0.44, 0.1), (4.06, 0.32, 0.54, 0.26), (4.2, 0.46, 0.6, 0.44), (4.42, 0.58, 0.6, 0.56), (4.66, 0.64, 0.6, 0.6), (5.0, 0.65, 0.6, 0.6), (5.22, 0.62, 0.58, 0.58), (5.3, 0.5, 0.46, 0.46))


def _cape(kit, part):
	"""Heavy cape hung from the shoulders, built as long pleat panels in two whites: each ridge throws its own inked edge."""
	n = 12
	rows = ((4.06, 0.52, 1.94, 0.0), (3.4, 0.62, 2.04, 0.5), (2.6, 0.72, 2.12, 0.8), (1.8, 0.84, 2.18, 1.0), (1.0, 0.96, 2.22, 1.0), (0.42, 1.04, 2.24, 1.1))
	amp = lambda i, k: 0.13 * k * (1 if i % 2 else -1)
	for i in range(n):
		rings = []
		for z, y, hw, k in rows:
			t0, t1 = i / n, (i + 1) / n
			wrap = lambda t: 0.22 * k * abs(2 * t - 1) ** 2  # the hems come forward lower down
			x0, x1 = -hw + 2 * hw * t0, -hw + 2 * hw * t1
			y0, y1 = y + amp(i, k) - wrap(t0), y + amp(i + 1, k) - wrap(t1)
			rings.append([(x0, y0, z), (x1, y1, z), (x1, y1 + 0.05, z), (x0, y0 + 0.05, z)])
		lit(loft(kit, f"UpperTorso_Cape{i}", rings, CLOTH if i % 2 else CAPE_FOLD, part), 0.1, 4.2)


def _turban(kit, head):
	"""A band over the brow under a fat crown wound in twisted bulging folds that meet at the top."""
	band = ((4.97, 0.69, 0.65), (5.03, 0.74, 0.71), (5.14, 0.75, 0.72), (5.22, 0.71, 0.68))
	rings = [[(rx * math.cos(i * math.pi / 8), 0.01 + ry * math.sin(i * math.pi / 8), z) for i in range(16)] for z, rx, ry in band]
	lit(loft(kit, "Head_TurbanBand", rings, CAPE_FOLD, head, smooth=True), 3.9, 5.8)
	levels = ((5.14, 0.74), (5.26, 0.84), (5.42, 0.9), (5.58, 0.82), (5.72, 0.6), (5.82, 0.3), (5.86, 0.06))
	n = 9
	for s in range(n):
		a0 = 2 * math.pi * s / n
		rings = []
		for z, r in levels:
			twist = (z - 5.14) * 1.5
			a, b, m = a0 + twist, a0 + 2 * math.pi / n + twist, a0 + math.pi / n + twist
			pt = lambda ang, k: (r * k * math.cos(ang), 0.01 + 0.95 * r * k * math.sin(ang), z)
			rings.append([(0, 0.01, z), pt(a, 0.94), pt(m, 1.03), pt(b, 0.94)])
		lit(loft(kit, f"Head_TurbanFold{s}", rings, CLOTH if s % 2 else CAPE_FOLD, head, smooth=True), 3.9, 5.8)


def model(parts, kit):
	head, t = parts["Head"], parts["UpperTorso"]
	sculpted_head(kit, parts, HEAD, SKIN_D, n=5)
	_turban(kit, head)
	# pointed ears: long, swept up and back
	for sgn, side in ((1, "L"), (-1, "R")):
		shard(kit, f"Head_Ear{side}", (sgn * 0.62, 0.05, 4.62), (sgn * 0.9, 0.12, 4.74), (sgn * 1.12, 0.26, 5.08), 0.2, SKIN, head, flatten=0.3, facing=(0, -1, 0), belly=0.35)
	# pauldrons: wide flat slabs that sit on the shoulders
	for sgn, side in ((1, "Left"), (-1, "Right")):
		kit.rbox(f"UpperTorso_Pauldron{side}", (1.6, 1.36, 0.32), (sgn * 1.3, 0.06, 4.18), CLOTH, t, bevel=0.07, segments=2, rot=(0, sgn * 0.12, 0))
		kit.rbox(f"UpperTorso_PauldronUnder{side}", (1.42, 1.2, 0.08), (sgn * 1.28, 0.06, 4.0), CLOTH_D, t, bevel=0.02, rot=(0, sgn * 0.12, 0))
	kit.rbox("UpperTorso_Collar", (1.12, 0.3, 0.42), (0, 0.46, 4.28), CLOTH, t, bevel=0.08, segments=2)
	_cape(kit, t)
	kit.rbox("UpperTorso_Knot", (0.32, 0.14, 0.26), (0.0, -0.56, 2.38), SASH, t, bevel=0.05)
	shard(kit, "UpperTorso_TailA", (0.0, -0.58, 2.34), (0.16, -0.66, 2.0), (0.1, -0.6, 1.62), 0.17, SASH, t, flatten=0.3, facing=(0, -1, 0))
	shard(kit, "UpperTorso_TailB", (0.0, -0.58, 2.34), (-0.16, -0.66, 2.0), (-0.1, -0.6, 1.7), 0.17, SASH, t, flatten=0.3, facing=(0, -1, 0))
	for sgn, side in ((1, "Left"), (-1, "Right")):
		cuff(kit, parts[side + "Hand"], side + "Hand_Band", sgn * 1.5, 2.44, 0.26, RED, w=1.08)
		x = sgn * 0.5
		cuff(kit, parts[side + "UpperLeg"], side + "Leg_Bloom", x, 0.72, 0.14, GI, w=1.05, bevel=0.05)
		foot = parts[side + "Foot"]
		toe(kit, foot, side + "Foot_Toe", x, SHOE, SHOE, reach=0.32, h=0.34)
		# the curled point of the shoe
		shard(kit, side + "Foot_Curl", (x, -0.74, 0.14), (x, -1.02, 0.14), (x, -1.0, 0.5), 0.15, SHOE, foot, flatten=0.8, facing=(0, 0, 1))


def paint_face(f):
	f.fill(SKIN)
	f.path("M135 70H118Q112 98 98 114Q82 124 65 128V135H135Z", SKIN_D, opacity=0.8)
	f.path("M-5 92H8Q18 108 32 118Q48 126 65 128V135H-5Z", SKIN_D, opacity=0.5)
	# shadow of the turban, hard
	f.path("M-5-5H135V38Q65 50 -5 38Z", SKIN_DD, opacity=0.9)
	f.path("M63 56Q66 76 60 92L69 92Q72 74 67 56Z", SKIN_D, opacity=0.6)
	# no hair brows: a heavy ridge of skin over deep sockets
	for sgn, cx in ((-1, 34), (1, 96)):
		f.path(f"M{cx - sgn * 20} 72Q{cx} 56 {cx + sgn * 21} 50V74Q{cx} 80 {cx - sgn * 20} 76Z", SKIN_D, opacity=0.85)
		f.path(f"M{cx - sgn * 22} 66L{cx - sgn * 20} 52Q{cx} 44 {cx + sgn * 24} 42L{cx + sgn * 21} 50Q{cx} 56 {cx - sgn * 22} 66Z", shade(SKIN, 1.15), stroke=SKIN_DD, sw=1.4)
	sharp_eye(f, 35, 68, -1, w=26, h=10.5, slant=8, pupil=3, look=2.5, lid=2.8, top_arc=0, shine=False)
	sharp_eye(f, 95, 68, 1, w=26, h=10.5, slant=8, pupil=3, look=-2.5, lid=2.8, top_arc=0, shine=False)
	f.taper(60, 52, 63, 58, 61, 66, 0.9, SKIN_DD)
	f.taper(70, 52, 67, 58, 69, 66, 0.9, SKIN_DD)
	# grooves under the eyes and down the cheeks
	f.taper(26, 80, 28, 96, 38, 112, 1, SKIN_DD)
	f.taper(104, 80, 102, 96, 92, 112, 1, SKIN_DD)
	f.taper(18, 80, 18, 92, 24, 102, 0.8, SKIN_DD)
	f.taper(112, 80, 112, 92, 106, 102, 0.8, SKIN_DD)
	# long narrow nose
	f.path("M65 80L59 96L70 97Z", SKIN_D)
	f.ink("M58 97Q64 100 71 97", 1.3, SKIN_DD)
	# dark lips, a snarl with one fang up
	f.path("M45 108Q56 104 65 106Q74 104 86 108Q78 116 65 117Q52 116 45 108Z", "#2a1a30", stroke=INK, sw=1.4)
	f.path("M50 108Q65 104 81 108L80 110Q65 107 51 110Z", "#f8f5ee")
	f.path("M53 112L56 104L59 112Z", "#f8f5ee", stroke=INK, sw=0.5)
	f.path("M72 112L75 104L78 112Z", "#f8f5ee", stroke=INK, sw=0.5)
	f.taper(40, 104, 42, 107, 46, 109, 1, INK)
	f.taper(91, 104, 89, 107, 85, 109, 1, INK)
	f.taper(54, 122, 65, 125, 76, 122, 0.8, SKIN_DD)


def gi_front(f):
	f.fill(GI)
	# open V, green chest
	f.path("M60-5H140L107 88H93Z", SKIN)
	f.path("M60-5H140L128 30Q100 44 72 30Z", SKIN_D, opacity=0.7)
	f.taper(100, 28, 101, 56, 100, 84, 1, SKIN_DD)
	f.taper(76, 36, 90, 52, 100, 50, 1, SKIN_DD)
	f.taper(124, 36, 110, 52, 100, 50, 1, SKIN_DD)
	f.path("M140-5L107 88L92 112L90 96L124-5Z", shade(GI, 1.25), stroke=INK, sw=2)
	f.path("M60-5L93 88L107 88L76-5Z", shade(GI, 1.12), stroke=INK, sw=2)
	f.path("M12 66Q40 86 76 72Q60 94 30 92Q14 86 12 66Z", GI_D, opacity=0.65)
	f.path("M188 66Q166 86 124 72Q140 94 170 92Q186 86 188 66Z", GI_D, opacity=0.65)
	f.taper(10, 68, 40, 88, 78, 72, 1.5)
	f.taper(190, 68, 162, 88, 122, 72, 1.5)
	f.folds(4, GI_D, GI_L, y0=0.46, y1=0.72, pinch=(100, 150), width=1.6)
	f.path("M-5 150H205V178H-5Z", SASH)
	f.path("M-5 150H205V156H-5Z", SASH_L, opacity=0.8)
	f.path("M-5 170H205V178H-5Z", SASH_D, opacity=0.9)
	for x in (24, 60, 124, 164):
		f.taper(x, 152, x + 12, 162, x + 6, 176, 0.9, SASH_D)
	f.ink("M-5 150H205M-5 178H205", 2)
	f.path("M100 180V200", stroke=INK, sw=1.8)
	f.taper(40, 180, 76, 192, 98, 197, 1.3)
	f.taper(160, 180, 124, 192, 102, 197, 1.3)
	f.edges(0.26)


def gi_back(f):
	f.fill(GI)
	f.taper(22, 34, 42, 84, 74, 118, 1.5)
	f.taper(178, 34, 158, 84, 126, 118, 1.5)
	f.folds(4, GI_D, GI_L, y0=0.5, y1=0.72, pinch=(100, 150))
	f.path("M-5 150H205V178H-5Z", SASH)
	f.path("M-5 170H205V178H-5Z", SASH_D, opacity=0.9)
	f.ink("M-5 150H205M-5 178H205", 2)
	f.edges(0.3)


def gi_side(f):
	f.fill(GI)
	f.path("M-5-5H105V30Q50 48 -5 30Z", GI_D, opacity=0.75)
	f.taper(50, 0, 56, 70, 48, 150, 1.4)
	f.path("M52 8Q58 70 50 150H105V8Z", GI_D, opacity=0.5)
	f.folds(3, GI_D, GI_L, y0=0.25, y1=0.72, pinch=(50, 150))
	f.path("M-5 150H105V178H-5Z", SASH)
	f.path("M-5 150H105V156H-5Z", SASH_L, opacity=0.8)
	f.path("M-5 170H105V178H-5Z", SASH_D, opacity=0.9)
	f.ink("M-5 150H105M-5 178H105", 2)
	f.edges(0.3)


def paint_arm(f, key):
	bare_arm(f, key, SKIN, top=0, wrist=172, d=SKIN_D, line=SKIN_DD)
	# the pink muscle patches: long, following the biceps and the forearm, cut by hard green
	if key in "FO":
		f.path("M30 30Q42 18 58 22Q78 34 74 60Q66 84 50 90Q34 84 28 60Q26 42 30 30Z", PINK, stroke=SKIN_DD, sw=1.3)
		f.path("M60 24Q78 34 74 60Q66 84 50 90Q66 66 60 24Z", PINK_D, opacity=0.9)
		f.path("M36 106Q46 98 58 102Q70 114 66 132Q60 150 50 156Q38 148 34 132Q32 116 36 106Z", PINK, stroke=SKIN_DD, sw=1.2)
		f.path("M58 102Q70 114 66 132Q60 150 50 156Q62 130 58 102Z", PINK_D, opacity=0.9)
		f.taper(38, 44, 42, 62, 50, 78, 0.7, PINK_D)
	elif key == "B":
		f.path("M36 28Q50 20 64 28Q68 52 50 72Q34 52 36 28Z", PINK, stroke=SKIN_DD, sw=1.2)
		f.path("M40 108Q50 102 60 108Q64 128 50 150Q36 128 40 108Z", PINK, stroke=SKIN_DD, sw=1.2)
	fist(f, key, SKIN, y=172, nails="#2a3a20")


def paint_leg(f, key):
	f.fill(GI)
	f.path("M74 0Q92 50 82 140H105V0Z", GI_D, opacity=0.6)
	f.folds(7, GI_D, GI_L, y0=0.02, y1=0.6, pinch=(50, 130), width=1.8)
	if key == "F":
		f.taper(14, 12, 40, 30, 62, 50, 1.2)
	# brown shoe, with a pointed tongue up the shin
	f.path("M-5 150L50 134L105 150V205H-5Z", SHOE, stroke=INK, sw=1.8)
	f.path("M72 150L105 150V182H78Z", SHOE_D, opacity=0.7)
	f.taper(14, 172, 50, 178, 86, 172, 1.2, SHOE_D)
	f.path("M-5 190H105V205H-5Z", SHOE_D)
	f.ink("M-5 190H105", 1.6)


def paint(a):
	paint_face(a["Head_F"])
	gi_front(a["Torso_F"])
	gi_back(a["Torso_B"])
	for f, mir in head_faces(a, "Torso"):
		with mirrored(f, mir):
			gi_side(f)
	for _, key, f, mir in limb_faces(a, "Arm"):
		with mirrored(f, mir):
			paint_arm(f, key)
		f.edges(0.22)
	for _, key, f, mir in limb_faces(a, "Leg"):
		with mirrored(f, mir):
			paint_leg(f, key)
		f.edges(0.26)
	for f, mir in head_faces(a):
		with mirrored(f, mir):
			f.fill(SKIN)
			f.path("M-5-5H125V42H-5Z", CLOTH_D)
			f.path("M-5 110Q60 124 125 110V135H-5Z", SKIN_DD, opacity=0.8)
			f.path("M-5 42Q20 60 14 100L-5 100Z", SKIN_D, opacity=0.8)
			f.path("M90 42Q84 80 100 112L125 110V42Z", SKIN_D, opacity=0.7)
			f.taper(14, 74, 34, 90, 46, 106, 1, SKIN_DD)
		f.edges(0.22)
	f = a["Head_B"]
	f.fill(SKIN)
	f.path("M-5-5H135V44H-5Z", CLOTH_D)
	f.path("M-5 44H135V70Q65 90 -5 70Z", SKIN_D, opacity=0.75)
	f.taper(30, 90, 65, 104, 100, 90, 1.2, SKIN_DD)
	f.taper(40, 56, 65, 66, 90, 56, 1, SKIN_DD)
	a["Head_T"].fill(CLOTH)
	a["Head_Bo"].fill(SKIN_DD)
	a["Torso_T"].fill(CLOTH)
	a["Torso_Bo"].fill(GI_D)
	for side in ("Left", "Right"):
		a[f"{side}Arm_T"].fill(SKIN_D)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(GI)
		a[f"{side}Leg_Bo"].fill(SHOE_D)
