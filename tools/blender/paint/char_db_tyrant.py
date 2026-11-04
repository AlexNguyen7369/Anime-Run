# Painted look for db_tyrant, last form: all smooth white body, glossy purple domes on crown, shoulders, chest, forearms and
# shins, a long tail, red eyes, purple lips and the marks round the eyes.
from atlas import INK, shade
from db_common import bare_arm, dome, fist, head_faces, limb_faces, mirrored, sculpted_head, shard, sharp_eye, tube
import math

WHITE = "#ffffff"
SHADOW = "#d4cce8"
SHADOW_D = "#a79cc8"
PURPLE = "#7a35b4"
PURPLE_L = "#b77ee8"
PURPLE_D = "#40186e"
LINE = "#3a3250"
DEFAULT = WHITE
HAIR_COLOURS = []
HAIR = {"colour": WHITE, "locks": []}
PROPS = []
PI = math.pi
# z, half width, front depth, back depth
HEAD = ((4.0, 0.24, 0.36, 0.12), (4.08, 0.38, 0.48, 0.3), (4.22, 0.52, 0.56, 0.46), (4.42, 0.62, 0.6, 0.58), (4.66, 0.66, 0.62, 0.62), (4.96, 0.66, 0.64, 0.64), (5.16, 0.62, 0.62, 0.62), (5.3, 0.5, 0.52, 0.52), (5.38, 0.3, 0.32, 0.32), (5.41, 0.08, 0.08, 0.08))


def glossy(kit, name, centre, radii, part, rot=(0, 0, 0)):
	"""A dome with a flat light patch on it: the painted gloss of the source design."""
	from mathutils import Euler, Vector

	dome(kit, name, centre, radii, PURPLE, part, rot=rot)
	m = Euler(rot, "XYZ").to_matrix()
	off = m @ Vector((-radii[0] * 0.3, -radii[1] * 0.1, radii[2] * 0.72))
	dome(kit, name + "_Gloss", tuple(Vector(centre) + off), (radii[0] * 0.26, radii[1] * 0.3, radii[2] * 0.3), PURPLE_L, part, rot=rot, nu=8, nv=2)["flat"] = True


def model(parts, kit):
	head, t = parts["Head"], parts["UpperTorso"]
	# a smooth egg of a skull, narrow chin
	sculpted_head(kit, parts, HEAD, SHADOW, n=2.6)
	glossy(kit, "Head_Crown", (0, 0.03, 5.3), (0.47, 0.56, 0.26), head)
	# small ridged ears
	for sgn, side in ((1, "L"), (-1, "R")):
		dome(kit, f"Head_Ear{side}", (sgn * 0.7, 0.05, 4.72), (0.09, 0.14, 0.2), WHITE, head, full=True, nu=8, nv=3)
		dome(kit, f"Head_EarHole{side}", (sgn * 0.77, 0.05, 4.72), (0.03, 0.06, 0.1), SHADOW_D, head, full=True, nu=6, nv=2)["flat"] = True
	glossy(kit, "UpperTorso_Chest", (0, -0.48, 3.42), (0.5, 0.36, 0.2), t, rot=(PI / 2, 0, 0))
	for sgn, side in ((1, "Left"), (-1, "Right")):
		arm, leg = parts[side + "UpperArm"], parts[side + "LowerLeg"]
		glossy(kit, side + "UpperArm_Shoulder", (sgn * 1.5, 0, 3.96), (0.58, 0.56, 0.36), arm)
		# forearm: one dome on the front and one on the outside
		glossy(kit, side + "LowerArm_ForeF", (sgn * 1.5, -0.49, 2.76), (0.34, 0.42, 0.1), arm, rot=(PI / 2, 0, 0))
		glossy(kit, side + "LowerArm_ForeO", (sgn * 1.99, 0.0, 2.76), (0.34, 0.42, 0.1), arm, rot=(0, sgn * PI / 2, 0))
		glossy(kit, side + "LowerLeg_Shin", (sgn * 0.5, -0.48, 0.66), (0.34, 0.46, 0.2), leg, rot=(PI / 2, 0, 0))
		# three clawed toes
		foot = parts[side + "Foot"]
		for i, dx in enumerate((-0.3, 0.0, 0.3)):
			x = sgn * 0.5 + dx
			shard(kit, f"{side}Foot_Toe{i}", (x, -0.42, 0.14), (x, -0.72, 0.16), (x, -0.86, 0.06), 0.17, WHITE, foot, flatten=0.8, facing=(0, 0, 1), power=0.5, belly=0.1)
			shard(kit, f"{side}Foot_Nail{i}", (x, -0.74, 0.1), (x, -0.84, 0.1), (x, -0.98, 0.02), 0.07, "#2c2238", foot, flatten=0.7, facing=(0, 0, 1))
	# the long tail: thick at the root, whips round the wearer's left and up past the shoulder
	spine = [(0, 0.46, 2.42), (0, 0.9, 2.18), (0.1, 1.4, 1.84), (0.5, 1.84, 1.5), (1.1, 2.04, 1.44), (1.75, 1.94, 1.72), (2.3, 1.56, 2.3), (2.5, 1.14, 3.0), (2.5, 0.84, 3.64)]
	radii = [0.34, 0.32, 0.29, 0.26, 0.23, 0.2, 0.16, 0.1, 0.01]
	tube(kit, "LowerTorso_Tail", spine, radii, WHITE, t, sides=8)


def paint_face(f):
	f.fill(WHITE)
	# soft narrow jaw, skull shading
	f.path("M135 62H116Q112 96 96 114Q82 124 65 126V135H135Z", SHADOW, opacity=0.8)
	f.path("M-5 92H10Q20 106 34 116Q50 124 65 126V135H-5Z", SHADOW, opacity=0.45)
	# the ridge lines from brow up the forehead
	f.taper(50, 30, 56, 44, 60, 56, 0.9, LINE)
	f.taper(80, 30, 74, 44, 70, 56, 0.9, LINE)
	# the purple marks: a thin stripe under each eye out to the temple, a shorter one above
	for sgn, cx in ((-1, 36), (1, 94)):
		f.path(f"M{cx - sgn * 13} 78Q{cx + sgn * 2} 86 {cx + sgn * 18} 72L{cx + sgn * 29} 58Q{cx + sgn * 25} 78 {cx + sgn * 12} 88Q{cx - sgn * 4} 92 {cx - sgn * 13} 78Z", PURPLE, stroke=PURPLE_D, sw=0.6)
		f.path(f"M{cx - sgn * 4} 50Q{cx + sgn * 12} 44 {cx + sgn * 27} 42L{cx + sgn * 29} 50Q{cx + sgn * 12} 50 {cx - sgn * 4} 50Z", PURPLE, stroke=PURPLE_D, sw=0.6)
	# long, arched, cruel eyes: black rims, big red iris
	sharp_eye(f, 37, 66, -1, w=30, h=16, slant=8, pupil=3, iris="#cc1038", look=1.5, lid=3.4, top_arc=2, shine=True)
	sharp_eye(f, 93, 66, 1, w=30, h=16, slant=8, pupil=3, iris="#cc1038", look=-1.5, lid=3.4, top_arc=2, shine=True)
	f.taper(50, 80, 42, 84, 32, 82, 0.7, INK)
	f.taper(80, 80, 88, 84, 98, 82, 0.7, INK)
	# small nose, two slits
	f.taper(60, 90, 62, 94, 64, 96, 0.5, LINE)
	f.taper(70, 90, 68, 94, 66, 96, 0.5, LINE)
	# black-purple lips drawn in a thin smirk
	f.path("M46 112Q56 106 66 108Q74 106 86 106Q78 116 66 118Q54 118 46 112Z", "#3a1560", stroke=INK, sw=1.1)
	f.path("M47 112Q66 110 85 106Q70 113 66 113Q56 114 47 112Z", INK)
	f.path("M60 108Q66 106 72 107Q66 110 60 108Z", PURPLE_L, opacity=0.8)
	f.taper(88, 103, 87, 105, 85, 107, 0.8, INK)


def body_front(f):
	f.fill(WHITE)
	f.path("M174 -5Q190 70 172 118Q196 150 178 205H205V-5Z", SHADOW, opacity=0.8)
	f.path("M26 -5Q12 70 28 118Q6 150 20 205H-5V-5Z", SHADOW, opacity=0.45)
	# neck, collarbones
	f.path("M64-5H136V6Q100 22 64 6Z", SHADOW, opacity=0.8)
	f.taper(40, 26, 64, 34, 90, 26, 1, LINE)
	f.taper(160, 26, 136, 34, 110, 26, 1, LINE)
	# pecs: hard shadow under each
	f.path("M16 62Q50 92 92 74L96 80Q50 104 18 80Z", SHADOW, opacity=0.95)
	f.path("M184 62Q150 92 108 74L104 80Q150 104 182 80Z", SHADOW, opacity=0.95)
	f.taper(14, 62, 50, 92, 94, 74, 1.7, LINE)
	f.taper(186, 62, 150, 92, 106, 74, 1.7, LINE)
	# abs
	f.taper(100, 76, 102, 120, 100, 168, 1.5, LINE)
	for y, w in ((98, 34), (118, 32), (138, 28)):
		f.taper(100 - w, y, 80, y + 5, 98, y + 2, 1.1, LINE)
		f.taper(100 + w, y, 120, y + 5, 102, y + 2, 1.1, LINE)
		f.path(f"M{100 - w} {y}Q80 {y + 5} 98 {y + 2}L96 {y + 8}Q80 {y + 11} {100 - w + 2} {y + 6}Z", SHADOW, opacity=0.7)
		f.path(f"M{100 + w} {y}Q120 {y + 5} 102 {y + 2}L104 {y + 8}Q120 {y + 11} {100 + w - 2} {y + 6}Z", SHADOW, opacity=0.7)
	f.taper(40, 60, 34, 118, 50, 166, 1.1, LINE)
	f.taper(160, 60, 166, 118, 150, 166, 1.1, LINE)
	# hips
	f.taper(28, 172, 66, 188, 96, 200, 1.5, LINE)
	f.taper(172, 172, 134, 188, 104, 200, 1.5, LINE)
	f.edges(0.14)


def body_back(f):
	f.fill(WHITE)
	f.path("M174 -5Q190 70 172 118Q196 150 178 205H205V-5Z", SHADOW, opacity=0.8)
	f.path("M64-5H136V10Q100 24 64 10Z", SHADOW, opacity=0.8)
	f.taper(100, 18, 102, 90, 100, 150, 1.5, LINE)
	f.taper(28, 34, 46, 80, 84, 96, 1.6, LINE)
	f.taper(172, 34, 154, 80, 116, 96, 1.6, LINE)
	f.path("M28 34Q46 80 84 96L60 120Q30 90 22 60Z", SHADOW, opacity=0.6)
	f.path("M172 34Q154 80 116 96L140 120Q170 90 178 60Z", SHADOW, opacity=0.7)
	f.taper(40, 128, 70, 150, 92, 158, 1.1, LINE)
	f.taper(160, 128, 130, 150, 108, 158, 1.1, LINE)
	# tail root
	f.path("M60 200Q100 150 140 200Z", SHADOW, opacity=0.8)
	f.edges(0.14)


def body_side(f):
	f.fill(WHITE)
	f.path("M60 -5Q78 90 60 205H105V-5Z", SHADOW, opacity=0.75)
	f.path("M-5-5H105V24Q50 40 -5 24Z", SHADOW, opacity=0.5)
	for y in (70, 90, 110, 130):
		f.taper(16, y, 34, y + 8, 50, y + 4, 0.9, LINE)
	f.taper(60, 30, 72, 100, 58, 180, 1.2, LINE)
	f.edges(0.14)


def paint_arm(f, key):
	bare_arm(f, key, WHITE, top=0, wrist=176, d=SHADOW, line=LINE)
	fist(f, key, WHITE, y=176, line=LINE, nails="#6a5a8c" if key == "I" else None)


def paint_leg(f, key):
	f.fill(WHITE)
	f.path("M70 -5Q88 50 74 100Q90 150 78 205H105V-5Z", SHADOW, opacity=0.85)
	line = LINE
	if key == "F":
		f.taper(14, 8, 34, 44, 26, 88, 1.3, line)
		f.taper(86, 8, 66, 44, 74, 88, 1.3, line)
		f.path("M26 82Q50 72 74 82Q78 104 50 112Q22 104 26 82Z", SHADOW, opacity=0.4)  # kneecap
		f.taper(26, 82, 50, 72, 74, 82, 1.1, line)
		f.taper(26, 92, 50, 116, 74, 92, 1.3, line)
	elif key == "O":
		f.taper(10, 16, 50, 50, 70, 84, 1.3, line)
		f.taper(30, 112, 60, 150, 60, 186, 1.2, line)
	elif key == "B":
		f.taper(50, 6, 52, 40, 50, 84, 1.3, line)
		f.taper(14, 92, 50, 104, 86, 92, 1.2, line)
		f.path("M24 108Q50 96 76 108Q78 150 50 164Q22 150 24 108Z", SHADOW, opacity=0.55)
		f.taper(24, 108, 26, 150, 50, 164, 1.1, line)
		f.taper(76, 108, 74, 150, 50, 164, 1.1, line)
	else:
		f.taper(12, 20, 40, 60, 60, 92, 1.1, line)
		f.taper(30, 110, 44, 150, 40, 188, 1.1, line)
	f.path("M-5 192H105V205H-5Z", SHADOW, opacity=0.8)
	f.taper(10, 190, 50, 196, 90, 190, 1.1, line)


def paint(a):
	paint_face(a["Head_F"])
	body_front(a["Torso_F"])
	body_back(a["Torso_B"])
	for f, mir in head_faces(a, "Torso"):
		with mirrored(f, mir):
			body_side(f)
	for _, key, f, mir in limb_faces(a, "Arm"):
		with mirrored(f, mir):
			paint_arm(f, key)
		f.edges(0.12)
	for _, key, f, mir in limb_faces(a, "Leg"):
		with mirrored(f, mir):
			paint_leg(f, key)
		f.edges(0.12)
	for f, mir in head_faces(a):
		with mirrored(f, mir):
			f.fill(WHITE)
			f.path("M-5 104Q60 122 125 104V135H-5Z", SHADOW, opacity=0.9)
			f.path("M70 -5Q90 60 74 110H125V-5Z", SHADOW, opacity=0.65)
			# the purple mark wraps a little round the temple
			f.path("M-5 44Q14 50 22 62Q14 82 -5 92Z", PURPLE)
			f.taper(30, 96, 44, 110, 58, 118, 0.9, LINE)
		f.edges(0.12)
	f = a["Head_B"]
	f.fill(WHITE)
	f.path("M-5 84Q65 112 135 84V135H-5Z", SHADOW, opacity=0.9)
	f.path("M100 -5Q116 50 104 94L135 88V-5Z", SHADOW, opacity=0.5)
	f.taper(30, 28, 65, 16, 100, 28, 1, LINE)
	f.taper(65, 30, 67, 60, 65, 92, 0.9, LINE)
	a["Head_T"].fill(WHITE)
	a["Head_Bo"].fill(SHADOW_D)
	a["Torso_T"].fill(WHITE)
	a["Torso_Bo"].fill(SHADOW)
	for side in ("Left", "Right"):
		a[f"{side}Arm_T"].fill(WHITE)
		a[f"{side}Arm_Bo"].fill(SHADOW)
		a[f"{side}Leg_T"].fill(WHITE)
		a[f"{side}Leg_Bo"].fill(SHADOW)
