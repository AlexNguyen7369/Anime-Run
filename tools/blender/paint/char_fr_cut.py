# Target look for fr_cut "Ubbel" (design doc section 5): dark green hair, three-part fringe, one thick side ponytail; narrow purple eyes and a thin smile; a black
# dress with a dark choker and a cropped jacket worn off the shoulders, dark tights, boots, a long dark staff with a split crescent head. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, collar, ears, face, fill_body, finish, gem, helmet, jacket, locks, prism, rod, skirt, turned, wrap

SKIN = "#f8dcc8"
SKIN_D = "#d0a28a"
DEFAULT = "#1c1a22"
R = Ramps(
	hair=["#0c1e15", "#163222", "#244e36", "#376c4a", "#5c9472"],
	skin=["#c49880", "#e6c0a8", "#f8dcc8", "#ffeee0"],
	dress=["#08080c", "#121116", "#1e1c24", "#302e3a", "#4a4656"],
	jacket=["#24282e", "#363c44", "#4c545e", "#68727e", "#8c98a4"],
	trim=["#8a8c94", "#b4b6be", "#dcdee4", "#ffffff"],
	tights=["#0e0c14", "#181420", "#241f2e", "#342e40"],
	boot=["#140e0c", "#241a16", "#382a24", "#544238"],
	sole=["#08080c", "#14141a", "#24242c", "#36363e"],
	wood=["#140e10", "#241a1c", "#3a2c2e", "#544446"],
	steel=["#5c6470", "#8a92a0", "#bcc4d0", "#f0f4f8"],
	tie=["#3a1858", "#58288a", "#7c44b4", "#a878dc"],
)
HAIR = {"colour": "#305E40", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.5)
	for i, (t, r) in enumerate((((-1.12, 0.0, 5.3), 0.46), ((1.12, 0.0, 5.3), 0.46), ((-0.9, 0.86, 5.1), 0.46), ((0.9, 0.86, 5.1), 0.46), ((0, 1.12, 5.1), 0.48))):
		gem(k, "Head", f"Top{i}", (0.2, 0.0, 5.84), t, r, flat=0.5, bend=0.14, a=0.5 + 0.05 * (i % 2))
	# three groups of bangs: centre between the eyes, one each side swept out
	locks(k, "Mid", (0.04, -0.72, 5.94), (((-0.16, -1.04, 4.98), 0.24), ((0.06, -1.08, 4.66), 0.26), ((0.24, -1.04, 5.0), 0.22)))
	for s in (1, -1):
		locks(k, f"Out{s}", (s * 0.3, -0.72, 5.94), (((s * 0.52, -1.0, 5.14), 0.27), ((s * 0.8, -0.98, 5.02), 0.29), ((s * 1.04, -0.88, 4.74), 0.3)), bend=0.08)
		gem(k, "Head", f"Burn{s}", (s * 0.94, -0.56, 5.4), (s * 1.0, -0.8, 3.94), 0.26, flat=0.45, a=0.54, across=(1, 0, 0))
		gem(k, "Head", f"Side{s}", (s * 0.94, 0.1, 5.5), (s * 1.1, 0.3, 4.5), 0.38, flat=0.4, a=0.46, across=(0, 1, 0))
	for i, x in enumerate((-0.55, 0, 0.55)):
		gem(k, "Head", f"Back{i}", (x, 0.84, 5.3), (x + 0.2, 1.1, 4.2), 0.38, flat=0.42, a=0.5, across=(1, 0, 0))
	# the thick side ponytail on her left, tied high by the ear and falling past the shoulder
	block(k, "Head", "Tie", 1.2, 0.36, 5.4, 5.1, 0.2, 0.22, "tie", ch=0.05, a=0.56, b=0.44)
	gem(k, "Head", "TailRoot", (0.8, 0.3, 5.5), (1.6, 0.4, 4.9), 0.34, flat=0.7, a=0.54)
	for i, (b, t, r) in enumerate((((1.2, 0.36, 5.3), (1.5, 0.5, 2.7), 0.42), ((1.24, 0.3, 5.1), (1.95, 0.36, 3.2), 0.36), ((1.2, 0.5, 5.1), (1.4, 0.96, 2.9), 0.36), ((1.34, 0.1, 5.0), (1.66, -0.1, 3.6), 0.26))):
		gem(k, "Head", f"Tail{i}", b, t, r, flat=0.7, bend=0.06, a=0.48 + 0.06 * (i % 2))


def _body(k):
	jacket(k, "dress", seam=None)
	# bare collarbones over a straight neckline, a choker at the neck
	prism(k, T, "Skin", [(-1.0, 4.06), (1.0, 4.06), (0.96, 3.66), (-0.96, 3.66)], -0.64, -0.5, "skin", a=0.6, b=0.34)
	prism(k, T, "Line", [(-1.0, 3.7), (1.0, 3.7), (1.0, 3.6), (0, 3.52), (-1.0, 3.6)], -0.67, -0.6, "trim", a=0.5, b=0.36)
	collar(k, "skin", 4.06, 4.06, z0=3.9, rx=0.62, ry=0.56, name="Neck")
	collar(k, "dress", 4.2, 4.2, z0=4.02, rx=0.66, ry=0.6, name="Choker")
	block(k, T, "Pendant", 0, -0.72, 4.06, 3.86, 0.09, 0.04, "tie", ch=0.03, a=0.62, b=0.4)
	for s in (1, -1):
		block(k, T, f"Strap{s}", s * 0.72, -0.6, 4.07, 3.62, 0.07, 0.06, "dress", ch=0.01, a=0.5, b=0.5)
		for i, z in enumerate((3.2, 2.9, 2.6)):
			block(k, T, f"Lace{s}{i}", s * 0.1, -0.64, z + 0.04, z - 0.04, 0.12, 0.02, "jacket", ch=0.008, a=0.6, b=0.36)
	block(k, T, "Belt", 0, 0, 2.4, 2.22, 1.11, 0.63, "jacket", ch=0.02, a=0.5, b=0.5)
	skirt(k, "dress", 1.12, "trim", flare=0.14, th=0.07)
	# the cropped jacket, off both shoulders: a low back and open fronts
	wrap(k, T, "Crop", [(3.66, 1.12, 0.72, 0.84), (3.2, 1.14, 0.74, 0.8), (2.66, 1.16, 0.76, 0.86)], "jacket", t=0.08, a=0.52, b=0.46)
	wrap(k, T, "CropTrim", [(2.74, 1.17, 0.77, 0.84), (2.62, 1.18, 0.78, 0.86)], "trim", t=0.1, a=0.5, b=0.4)


def _arm(k, side, s):
	arm, x = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(x, 0, 3.9, 0.42, 0.42), (x, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Shoulder", x, 0, 4.02, 3.4, 0.5, 0.5, "skin", ch=0.08, corner=0.18, a=0.6, b=0.32)
	block(k, arm, "Roll", x, 0, 3.66, 3.4, 0.6, 0.6, "jacket", ch=0.06, corner=0.2, a=0.56, b=0.46)
	block(k, arm, "Sleeve", x, 0, 3.44, 2.42, 0.53, 0.53, "jacket", ch=0.05, flare=0.1, corner=0.18, jit=0.02, mids=(2.9,), a=0.5, b=0.5)
	block(k, arm, "Cuff", x, 0, 2.54, 2.4, 0.645, 0.645, "trim", ch=0.02, corner=0.18, a=0.5, b=0.4)
	block(k, arm, "Hand", x, 0, 2.44, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)


def _staff(k):
	arm, x, y = "RightUpperArm", -1.62, -0.64

	def build():
		block(k, arm, "Shaft", x, y, 5.1, 0.2, 0.07, 0.07, "wood", ch=0.02, a=0.52, b=0.46)
		block(k, arm, "Butt", x, y, 0.42, 0.1, 0.1, 0.1, "steel", ch=0.03, a=0.54, b=0.44)
		block(k, arm, "Neck", x, y, 5.2, 4.9, 0.12, 0.12, "steel", ch=0.03, a=0.54, b=0.44)
		for d in (1, -1):
			prism(k, arm, f"Fork{d}", [(x + d * 0.04, 5.1), (x + d * 0.34, 5.24), (x + d * 0.44, 5.56), (x + d * 0.2, 6.02), (x + d * 0.26, 5.6), (x + d * 0.18, 5.4), (x + d * 0.04, 5.32)], y - 0.07, y + 0.07, "wood", a=0.6, b=0.46)
		rod(k, arm, "Orb", [(x, y, 5.42), (x, y, 5.5), (x, y, 5.62), (x, y, 5.7)], [0.05, 0.15, 0.15, 0.05], "tie", n=6, a=0.6, b=0.46)

	turned(build, (x, y, 2.2), -4, 4, 0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		leg, px = f"{side}UpperLeg", s * 0.53
		k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.47, 0.49), (s * 0.5, 0, 0.1, 0.47, 0.49)], corner=0.1, nc=1)
		boot(k, leg, px, "boot", "sole", top=0.8, cuff="dress")
	_staff(k)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, SKIN_D, ("#4c2484", "#8c4cc8", "#d49cff"), "#14201c", "#1e4430", "M50 103Q64 113 82 101", w=35, up=8, dn=8, inner=4, outer=-5, ir=(9.6, 10.5), pu=(2.8, 4.4), lid=0.36, thick=1.6, wing=6, brow_y=49, brow_t=3.4, tilt=2.4, blush=0.12)
	fill_body(a, SKIN, SKIN_D, "#1e1c24", "#f0d0ba", "#1e1a28", "#20442e")
