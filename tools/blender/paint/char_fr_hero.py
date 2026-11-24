# Target look for fr_hero "Himmal" (design doc section 5): light blue hair in a soft bowl with a swept fringe, light blue eyes, a mole under his left eye, a calm
# smile; a long off-white cloak with gold trim over a blue tunic, white trousers, dark boots, the hero's sword held low. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, cape, collar, face, fill_body, finish, gem, helmet, jacket, locks, prism, skirt, sleeve, trouser, turned, wrap

SKIN = "#fbdcc4"
SKIN_D = "#d6a688"
DEFAULT = "#3c68b4"
R = Ramps(
	hair=["#4a7cb4", "#6a9ed0", "#8cbce8", "#b0d6f8", "#d8eeff"],
	skin=["#c89878", "#e8c0a4", "#fbdcc4", "#fff0e0"],
	blue=["#16305c", "#244884", "#3864ac", "#5484cc", "#84b0ec"],
	cloak=["#a09884", "#c8c0aa", "#e6e0ce", "#f6f2e6", "#ffffff"],
	lining=["#1c3868", "#2c5090", "#4470b4", "#6890d0"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	white=["#9aa0b0", "#c4cad6", "#e6eaf0", "#ffffff"],
	belt=["#2e1c10", "#4c301c", "#6c4a2c", "#8e6a44"],
	boot=["#0e0e14", "#1a1a22", "#2a2a34", "#40404c"],
	sole=["#08080c", "#14141a", "#24242c", "#36363e"],
	steel=["#7c8694", "#a8b2c0", "#d4dce6", "#ffffff"],
)
HAIR = {"colour": "#8CBCE8", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.3)
	# the bowl: layers falling from the crown to just under the ears, flicked at the ends
	for i, (t, r) in enumerate((((-1.16, -0.1, 5.3), 0.46), ((1.16, -0.1, 5.3), 0.46), ((-1.06, 0.66, 5.2), 0.46), ((1.06, 0.66, 5.2), 0.46), ((-0.4, 1.12, 5.2), 0.46), ((0.4, 1.12, 5.2), 0.46))):
		gem(k, "Head", f"Top{i}", (0, 0.1, 5.84), t, r, flat=0.5, bend=0.14, twist=0.2, a=0.52 + 0.04 * (i % 2))
	for s in (1, -1):
		for i, (y, tz, r) in enumerate(((-0.7, 4.54, 0.26), (-0.4, 4.36, 0.34), (-0.02, 4.5, 0.38), (0.36, 4.34, 0.38), (0.72, 4.16, 0.36))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.94, y * 0.9, 5.6), (s * (1.14 + 0.06 * (i % 2)), y * 1.15, tz), r, flat=0.42, twist=0.2, a=0.46 + 0.07 * (i % 2), across=(0, 1, 0))
	for s in (1, -1):
		prism(k, "Head", f"Under{s}", [(s * 0.5, 5.6), (s * 1.02, 5.6), (s * 1.04, 4.7), (s * 0.9, 4.78), (s * 0.5, 5.2)], -0.92, -0.6, "hair", a=0.5, b=0.42)
	for i, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
		gem(k, "Head", f"Back{i}", (x, 0.84, 5.4), (x * 1.15, 1.18, 4.04 + 0.1 * (i % 2)), 0.36, flat=0.42, twist=0.2, a=0.48 + 0.06 * (i % 2), across=(1, 0, 0))
	# fringe swept from a part on the viewer's left, long over the far brow
	p = (-0.34, -0.74, 5.96)
	locks(k, "Bang", p, (((-1.02, -0.92, 4.86), 0.3), ((-0.72, -0.98, 5.06), 0.28), ((-0.36, -1.02, 5.12), 0.28), ((0.0, -1.04, 5.0), 0.3), ((0.36, -1.02, 4.92), 0.31), ((0.7, -0.98, 4.86), 0.31), ((1.0, -0.9, 4.76), 0.3)), bend=0.08)
	gem(k, "Head", "Flick", (0.1, 0.1, 6.0), (0.5, 0.0, 6.38), 0.18, flat=0.6, bend=0.12, a=0.56)


def _body(k):
	jacket(k, "blue", seam=None)
	collar(k, "blue", 4.22, 4.32, z0=3.92, rx=0.64, ry=0.6, name="Neck")
	collar(k, "gold", 4.28, 4.38, z0=4.18, rx=0.655, ry=0.615, name="NeckTrim")
	block(k, T, "Placket", 0, -0.63, 3.94, 2.5, 0.13, 0.025, "gold", ch=0.01, a=0.56, b=0.42)
	block(k, T, "Placket2", 0, -0.65, 3.94, 2.5, 0.07, 0.02, "blue", ch=0.01, a=0.5, b=0.5)
	block(k, T, "Belt", 0, 0, 2.48, 2.24, 1.11, 0.63, "belt", ch=0.03, sub=1, a=0.52, b=0.48)
	block(k, T, "Buckle", 0, -0.66, 2.52, 2.2, 0.17, 0.03, "gold", ch=0.015, a=0.58, b=0.42)
	skirt(k, "blue", 1.34, "gold", flare=0.07, th=0.1)
	# the cloak: round the shoulders, open in front, held by a gold clasp and chain
	wrap(k, T, "Mantle", [(4.22, 0.86, 0.66, 0.2), (4.04, 1.14, 0.76, 0.36), (3.3, 1.2, 0.86, 0.62)], "cloak", t=0.07, a=0.54, b=0.44, g=0.1)
	collar(k, "cloak", 4.02, 4.42, z0=3.8, rx=0.9, ry=0.8, power=1.2, name="CloakCollar")
	for s in (1, -1):
		block(k, T, f"Clasp{s}", s * 0.5, -0.8, 4.08, 3.82, 0.13, 0.05, "gold", ch=0.04, a=0.6, b=0.4)
	block(k, T, "Chain", 0, -0.82, 3.97, 3.91, 0.42, 0.025, "gold", ch=0.01, a=0.58, b=0.42)
	cape(k, "cloak", "lining", 0.36, "gold")


def _sword(k):
	arm, x, y = "RightUpperArm", -1.5, -0.3

	def build():
		block(k, arm, "Grip", x, y, 2.66, 1.76, 0.08, 0.08, "belt", ch=0.015, a=0.56, b=0.46)
		block(k, arm, "Pommel", x, y, 2.86, 2.62, 0.14, 0.12, "gold", ch=0.04, a=0.56, b=0.46)
		prism(k, arm, "Guard", [(x - 0.5, 1.84), (x - 0.12, 1.74), (x + 0.12, 1.74), (x + 0.5, 1.84), (x + 0.5, 1.62), (x + 0.16, 1.48), (x - 0.16, 1.48), (x - 0.5, 1.62)], y - 0.1, y + 0.1, "gold", a=0.56, b=0.44)
		block(k, arm, "Gem", x, y - 0.1, 1.72, 1.54, 0.09, 0.04, "blue", ch=0.03, a=0.66, b=0.4)
		for d in (1, -1):
			prism(k, arm, f"Blade{d}", [(x, 1.5), (x + d * 0.19, 1.5), (x + d * 0.17, -0.5), (x, -0.96)], y - 0.05, y + 0.05, "steel", a=0.6 + d * 0.12, b=0.4)

	turned(build, (x, y, 2.14), -55, 0, -30)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, "blue")
		arm = f"{side}UpperArm"
		block(k, arm, "Mantle", s * 1.58, 0.06, 4.14, 3.34, 0.58, 0.7, "cloak", ch=0.1, flare=0.06, corner=0.3, a=0.54, b=0.44)
		block(k, arm, "MantleTrim", s * 1.58, 0.06, 3.44, 3.3, 0.655, 0.775, "gold", ch=0.02, corner=0.3, a=0.56, b=0.42)
		block(k, arm, "Bracer", s * 1.5, 0, 2.86, 2.44, 0.55, 0.55, "belt", ch=0.04, corner=0.18, a=0.52, b=0.48)
		leg, px = trouser(k, side, s, "white", low=1.0)
		boot(k, leg, px, "boot", "sole", top=1.02, cuff="boot")
	_sword(k)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, SKIN_D, ("#2c68a8", "#6cb4e8", "#d0f0ff"), "#24385c", "#4a78a8", "M53 105Q65 111 77 105", w=33, up=11, dn=9, inner=2.5, outer=-2.5, ir=(9.6, 11.5), lid=0.26, brow_y=46, brow_t=3.8, tilt=0.6, blush=0.14)
	f.path("M100 84a2.6 2.8 0 1 0 5.2 0a2.6 2.8 0 1 0 -5.2 0Z", "#5a3428")
	fill_body(a, SKIN, SKIN_D, "#3864ac", "#3864ac", "#c4cad6", "#6a9ed0")
