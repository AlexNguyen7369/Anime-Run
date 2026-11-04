# Painted look for db_scholar: the teenage fighter in the purple gi at the height of his power. Short upward spikes, one
# lock over the forehead, a torn sleeve from the fight.
from atlas import INK, paint_hair, shade
from db_common import sculpted_head, bare_arm, cuff, dome, fist, head_faces, limb_faces, mirrored, shards, sharp_eye, slab_brow, toe

SKIN = "#f5cda6"
SKIN_D = shade(SKIN, 0.68)
GI = "#5a35a4"
GI_D = "#33196e"
GI_L = "#9a78e0"
RED = "#c52a2a"
RED_D = "#7c1212"
RED_L = "#f06a5a"
BOOT = "#7a4a22"
BOOT_D = "#472710"
HAIRC = "#131318"
HAIR_INK = "#24262f"
DEFAULT = GI
HAIR_COLOURS = [HAIRC]
HAIR = {"colour": HAIRC, "locks": []}
PROPS = []
# z, half width, front depth, back depth: the jaw as this character has it
HEAD = ((4.02, 0.3, 0.42, 0.2), (4.1, 0.44, 0.52, 0.36), (4.24, 0.56, 0.58, 0.5), (4.42, 0.63, 0.6, 0.58), (4.6, 0.65, 0.6, 0.6), (5.0, 0.65, 0.6, 0.6), (5.22, 0.62, 0.58, 0.58), (5.3, 0.5, 0.46, 0.46))

SPIKES = [
	# front row stands up off the hairline, low and tight
	((0.0, -0.42, 5.2), (0.0, -0.38, 5.6), (0.04, -0.2, 6.14), 0.34),
	((-0.3, -0.42, 5.2), (-0.36, -0.38, 5.56), (-0.36, -0.2, 5.98), 0.3),
	((0.3, -0.42, 5.2), (0.38, -0.38, 5.56), (0.42, -0.2, 6.02), 0.3),
	((-0.56, -0.34, 5.12), (-0.76, -0.28, 5.4), (-0.86, -0.12, 5.7), 0.26),
	((0.56, -0.34, 5.12), (0.76, -0.28, 5.4), (0.9, -0.12, 5.76), 0.26),
	((-0.66, -0.2, 4.94), (-0.92, -0.14, 5.08), (-1.14, -0.04, 5.28), 0.22),
	((0.66, -0.2, 4.94), (0.92, -0.14, 5.08), (1.16, -0.04, 5.32), 0.22),
	((-0.66, -0.26, 4.74), (-0.82, -0.2, 4.72), (-0.96, -0.1, 4.86), 0.14),
	((0.66, -0.26, 4.74), (0.82, -0.2, 4.72), (0.98, -0.1, 4.88), 0.14),
	# crown
	((-0.16, 0.05, 5.32), (-0.2, 0.08, 5.74), (-0.14, 0.2, 6.2), 0.34),
	((0.2, 0.05, 5.32), (0.26, 0.08, 5.72), (0.24, 0.2, 6.16), 0.34),
	((-0.5, 0.1, 5.18), (-0.72, 0.14, 5.5), (-0.82, 0.24, 5.84), 0.28),
	((0.5, 0.1, 5.18), (0.72, 0.14, 5.5), (0.86, 0.24, 5.88), 0.28),
	((-0.64, 0.18, 4.98), (-0.92, 0.24, 5.08), (-1.12, 0.34, 5.26), 0.22),
	((0.64, 0.18, 4.98), (0.92, 0.24, 5.08), (1.14, 0.34, 5.3), 0.22),
	# back, spreading out and down to the nape
	((0.0, 0.42, 5.2), (0.0, 0.62, 5.56), (0.02, 0.84, 5.94), 0.34),
	((-0.32, 0.44, 5.12), (-0.48, 0.66, 5.36), (-0.58, 0.86, 5.62), 0.28),
	((0.32, 0.44, 5.12), (0.48, 0.66, 5.36), (0.6, 0.86, 5.66), 0.28),
	((0.0, 0.56, 4.96), (0.0, 0.84, 5.04), (0.0, 1.14, 5.22), 0.3),
	((-0.42, 0.54, 4.86), (-0.62, 0.78, 4.9), (-0.84, 0.96, 5.0), 0.24),
	((0.42, 0.54, 4.86), (0.62, 0.78, 4.9), (0.86, 0.96, 5.02), 0.24),
	((-0.2, 0.58, 4.66), (-0.28, 0.78, 4.54), (-0.34, 0.92, 4.5), 0.22),
	((0.2, 0.58, 4.66), (0.28, 0.78, 4.54), (0.36, 0.92, 4.5), 0.22),
	((-0.56, 0.42, 4.62), (-0.68, 0.56, 4.52), (-0.78, 0.68, 4.48), 0.15),
	((0.56, 0.42, 4.62), (0.68, 0.56, 4.52), (0.8, 0.68, 4.5), 0.15),
	# the one lock falling over the forehead, between the eyes
	((0.1, -0.58, 5.14), (0.14, -0.72, 4.92), (-0.02, -0.67, 4.68), 0.15, 0.3),
]


def model(parts, kit):
	sculpted_head(kit, parts, HEAD, SKIN_D, n=5)
	for sgn in (1, -1):
		dome(kit, f"Head_Ear{sgn}", (sgn * 0.65, 0.04, 4.66), (0.08, 0.13, 0.17), SKIN, parts["Head"], full=True, nu=8, nv=3)
	dome(kit, "Head_Skull", (0, 0.04, 4.92), (0.73, 0.71, 0.5), HAIRC, parts["Head"]).__setitem__("lock", ((0, 0, 4.92), (0, 0, 5.42)))
	shards(kit, parts, HAIRC, SPIKES)
	t = parts["UpperTorso"]
	for sgn, side in ((1, "Left"), (-1, "Right")):
		arm, foot = parts[side + "Hand"], parts[side + "Foot"]
		cuff(kit, arm, side + "Hand_Band", sgn * 1.5, 2.44, 0.24, RED, w=1.08)
		x = sgn * 0.5
		cuff(kit, parts[side + "UpperLeg"], side + "Leg_Bloom", x, 0.82, 0.16, GI, w=1.05, bevel=0.05)
		toe(kit, foot, side + "Foot_Toe", x, BOOT, BOOT, reach=0.26, h=0.3)
	# sash knot on the front, two tails
	from db_common import shard

	kit.rbox("UpperTorso_Knot", (0.26, 0.14, 0.24), (-0.22, -0.56, 2.38), RED, t, bevel=0.05, rot=(0, -0.4, 0))
	shard(kit, "UpperTorso_TailA", (-0.22, -0.58, 2.34), (-0.34, -0.66, 2.05), (-0.26, -0.6, 1.72), 0.16, RED, t, flatten=0.3, facing=(0, -1, 0))
	shard(kit, "UpperTorso_TailB", (-0.22, -0.58, 2.34), (-0.1, -0.64, 2.08), (0.02, -0.6, 1.82), 0.14, RED, t, flatten=0.3, facing=(0, -1, 0))


def paint_face(f):
	f.fill(SKIN)
	f.path("M135 70H119Q114 96 100 112Q84 122 65 125V135H135Z", SKIN_D, opacity=0.8)
	f.path("M-5 92H9Q18 106 32 116Q48 123 65 125V135H-5Z", SKIN_D, opacity=0.5)
	f.path("M-5-5H135V40L118 46L100 34L82 48L65 40L46 48L30 34L12 46L-5 40Z", SKIN_D, opacity=0.9)
	# hairline: spikes starting up, block corners hidden
	f.path("M-5-5H135V38L124 42L114 22L100 26L90 14L65 18L40 14L30 26L16 22L6 42L-5 38Z", HAIRC)
	f.path("M12 82Q22 94 30 106Q20 102 15 92Z", SKIN_D, opacity=0.45)
	f.path("M118 82Q108 94 100 106Q110 102 115 92Z", SKIN_D, opacity=0.55)
	# thin, tense brows, larger clear eyes than the rest of the cast: he's young
	slab_brow(f, 38, 49, -1, "#121218", w=31, thick=6.5, angry=11)
	slab_brow(f, 92, 49, 1, "#121218", w=31, thick=6.5, angry=11)
	sharp_eye(f, 38, 66, -1, w=28, h=17, slant=7, pupil=4.4, iris="#2a2a3a", look=0.5, lid=2.6, top_arc=2)
	sharp_eye(f, 92, 66, 1, w=28, h=17, slant=7, pupil=4.4, iris="#2a2a3a", look=-0.5, lid=2.6, top_arc=2)
	line = shade(SKIN, 0.45)
	f.taper(61, 48, 63, 54, 62, 58, 0.5, line)
	f.taper(69, 48, 67, 54, 68, 58, 0.5, line)
	f.path("M66 86L62 94L68 95Z", shade(SKIN, 0.74))
	f.ink("M61 95Q65 97 68 95", 0.9, shade(SKIN, 0.38))
	# jaw set, teeth clenched: a level slit
	f.path("M51 111Q65 105 79 111Q65 109 51 111Z", INK)
	f.taper(51, 111, 50, 113, 52, 115, 0.7, INK)
	f.taper(79, 111, 80, 113, 78, 115, 0.7, INK)
	f.taper(58, 120, 65, 122, 72, 120, 0.5, line)


def gi_front(f):
	f.fill(GI)
	# open V, bare chest
	f.path("M64-5H136L106 96H94Z", SKIN)
	f.path("M72-5H128L104 70H96Z", SKIN_D, opacity=0.4)
	f.taper(100, 22, 101, 50, 100, 90, 0.8, shade(SKIN, 0.45))
	f.taper(78, 30, 90, 46, 100, 44, 0.8, shade(SKIN, 0.45))
	f.taper(122, 30, 110, 46, 100, 44, 0.8, shade(SKIN, 0.45))
	# lapels
	f.path("M136-5L106 96L90 122L88 104L120-5Z", shade(GI, 1.25), stroke=INK, sw=2)
	f.path("M64-5L94 96L106 96L80-5Z", shade(GI, 1.12), stroke=INK, sw=2)
	# chest through the cloth
	f.path("M12 66Q40 86 76 72Q60 94 30 92Q14 86 12 66Z", GI_D, opacity=0.65)
	f.path("M188 66Q166 86 124 72Q140 94 170 92Q186 86 188 66Z", GI_D, opacity=0.65)
	f.taper(10, 68, 40, 88, 78, 72, 1.5)
	f.taper(190, 68, 162, 88, 122, 72, 1.5)
	f.folds(4, GI_D, GI_L, y0=0.46, y1=0.72, pinch=(100, 150), width=1.6)
	f.path("M-5 150Q10 110 22 96L4 86L-5 96Z", GI_D, opacity=0.7)
	f.path("M205 150Q190 110 178 96L196 86L205 96Z", GI_D, opacity=0.85)
	# sash
	f.path("M-5 150H205V176H-5Z", RED)
	f.path("M-5 150H205V156H-5Z", RED_L, opacity=0.8)
	f.path("M-5 168H205V176H-5Z", RED_D, opacity=0.9)
	for x in (20, 90, 130, 170):
		f.taper(x, 152, x + 14, 162, x + 8, 174, 0.9, RED_D)
	f.ink("M-5 150H205M-5 176H205", 2)
	f.path("M100 178V200", stroke=INK, sw=1.8)
	f.taper(40, 178, 76, 192, 98, 196, 1.3)
	f.taper(160, 178, 124, 192, 102, 196, 1.3)
	f.edges(0.26)


def gi_back(f):
	f.fill(GI)
	f.path("M62-5Q100 22 138-5Z", SKIN)
	f.path("M54-5Q100 30 146-5L138-5Q100 22 62-5Z", shade(GI, 1.25), stroke=INK, sw=1.6)
	f.taper(22, 34, 42, 84, 74, 118, 1.5)
	f.taper(178, 34, 158, 84, 126, 118, 1.5)
	f.path("M22 34Q42 84 74 118L14 104Z", GI_D, opacity=0.6)
	f.path("M178 34Q158 84 126 118L186 104Z", GI_D, opacity=0.75)
	f.taper(100, 30, 102, 80, 100, 146, 1.1)
	f.folds(4, GI_D, GI_L, y0=0.5, y1=0.72, pinch=(100, 150))
	f.path("M-5 150H205V176H-5Z", RED)
	f.path("M-5 150H205V156H-5Z", RED_L, opacity=0.8)
	f.path("M-5 168H205V176H-5Z", RED_D, opacity=0.9)
	f.ink("M-5 150H205M-5 176H205", 2)
	f.path("M100 178V200", stroke=INK, sw=1.8)
	f.edges(0.28)


def gi_side(f):
	f.fill(GI)
	f.path("M-5-5H105V24Q50 44 -5 24Z", GI_D, opacity=0.7)
	f.taper(50, 0, 56, 70, 48, 150, 1.4)
	f.path("M52 8Q58 70 50 150H105V8Z", GI_D, opacity=0.5)
	f.folds(3, GI_D, GI_L, y0=0.25, y1=0.72, pinch=(50, 150))
	f.path("M-5 150H105V176H-5Z", RED)
	f.path("M-5 150H105V156H-5Z", RED_L, opacity=0.8)
	f.path("M-5 168H105V176H-5Z", RED_D, opacity=0.9)
	f.ink("M-5 150H105M-5 176H105", 2)
	f.edges(0.3)


def paint_arm(f, key, side):
	bare_arm(f, key, SKIN, top=0, wrist=172)
	fist(f, key, SKIN, y=172)
	# short sleeve; his left one torn away by the fight
	if side == "Left":
		f.path("M-5-5H105V22L92 34L80 20L66 36L54 18L38 32L26 18L10 32L-5 20Z", GI)
		f.ink("M-5 20L10 32L26 18L38 32L54 18L66 36L80 20L92 34L105 22", 1.5)
	else:
		f.path("M-5-5H105V46H-5Z", GI)
		f.ink("M-5 46H105", 1.8)
		f.taper(10, 14, 30, 26, 44, 36, 1.2, GI_D)
		f.taper(90, 16, 70, 26, 58, 38, 1.2, GI_D)
	f.path("M72-5Q84 16 76 28H105V-5Z", GI_D, opacity=0.65)


def paint_leg(f, key, side):
	f.fill(GI)
	f.path("M74 0Q92 50 80 120H105V0Z", GI_D, opacity=0.6)
	f.folds(6, GI_D, GI_L, y0=0.02, y1=0.5, pinch=(50, 110), width=1.7)
	if key == "F":
		f.taper(14, 12, 40, 30, 62, 50, 1.2)
	# short brown boot
	f.path("M-5 118H105V205H-5Z", BOOT)
	f.path("M72 118Q86 150 78 182H105V118Z", BOOT_D, opacity=0.7)
	f.taper(14, 146, 50, 154, 86, 146, 1.2, BOOT_D)
	if key == "F":
		f.path("M38 122H62V170H38Z", shade(BOOT, 1.25), stroke=INK, sw=1.2)
		for y in (132, 144, 156):
			f.ink(f"M40 {y}H60", 1, BOOT_D)
	f.path("M-5 184H105V205H-5Z", BOOT_D)
	f.ink("M-5 184H105", 1.6)


def paint(a):
	paint_hair(a, [HAIR_INK])
	paint_face(a["Head_F"])
	gi_front(a["Torso_F"])
	gi_back(a["Torso_B"])
	for f, mir in head_faces(a, "Torso"):
		with mirrored(f, mir):
			gi_side(f)
	for side, key, f, mir in limb_faces(a, "Arm"):
		with mirrored(f, mir):
			paint_arm(f, key, side)
		f.edges(0.22)
	for side, key, f, mir in limb_faces(a, "Leg"):
		with mirrored(f, mir):
			paint_leg(f, key, side)
		f.edges(0.26)
	for f, mir in head_faces(a):
		with mirrored(f, mir):
			f.fill(SKIN)
			f.path("M-5 100Q60 118 125 100V135H-5Z", SKIN_D, opacity=0.9)
			f.path("M-5-5H125V96Q94 90 80 64L68 40L54 62L46 30L-5 36Z", HAIRC)
			f.path("M46 60Q58 48 70 60Q72 78 60 90Q50 92 48 80Z", SKIN, stroke=INK, sw=2)
			f.ink("M54 64Q60 58 64 66Q64 74 60 80", 1.4, shade(SKIN, 0.45))
			f.taper(96, 16, 104, 56, 100, 88, 1.5, "#3a3d4a")
		f.edges(0.25)
	f = a["Head_B"]
	f.fill(HAIRC)
	for x in (20, 46, 72, 98, 118):
		f.taper(x, 0, x + 6, 60, x - 2, 126, 1.6, "#343745")
	a["Head_T"].fill(HAIRC)
	a["Head_Bo"].fill(SKIN_D)
	a["Torso_T"].fill(GI)
	a["Torso_Bo"].fill(GI_D)
	for side in ("Left", "Right"):
		a[f"{side}Arm_T"].fill(GI)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(GI)
		a[f"{side}Leg_Bo"].fill(BOOT_D)
