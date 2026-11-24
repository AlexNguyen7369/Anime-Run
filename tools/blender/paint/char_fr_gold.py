# Target look for fr_gold "Machto" (design doc section 5): long crimson-magenta hair slicked back off a high forehead, two dark horns, pointed ears, narrow blue eyes, calm; a
# dark military coat with a gold cord from the left shoulder across the chest, red gloves, a great blue coat over the left shoulder, boots, a golden greatsword. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, collar, elf_ears, face, fill_body, finish, gem, helmet, horns, jacket, mane, pleat, prism, rblock, rod, skirt, sleeve, trouser, turned

SKIN = "#f2d6c6"
SKIN_D = "#c69a86"
DEFAULT = "#262630"
R = Ramps(
	hair=["#4a1024", "#6e1c38", "#962e50", "#b84c6e", "#da7c98"],
	skin=["#b88e7a", "#dcb8a4", "#f2d6c6", "#ffeadc"],
	horn=["#1a1418", "#2e262a", "#4a4044", "#766a6c"],
	uni=["#0c0c12", "#18181f", "#26262f", "#3a3a46", "#545462"],
	blue=["#101e48", "#1a2f6a", "#28458e", "#4062b0", "#6c8cd4"],
	lining=["#4c0e14", "#74181e", "#9c282c", "#c24840"],
	red=["#5c0c12", "#8c161c", "#b8282a", "#dc5048"],
	gold=["#8a5c08", "#cc9418", "#f2c43a", "#fff4a0"],
	white=["#9a98a8", "#c4c2d0", "#e8e6ee", "#ffffff"],
	boot=["#08080c", "#141418", "#222228", "#36363e"],
	sole=["#08080c", "#14141a", "#24242c", "#36363e"],
)
HAIR = {"colour": "#962E50", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.2, brow=5.24)
	mane(k, 2.0, mid=1.0, end=0.72, n=5)
	# long locks swept up off a centre peak, over the crown and back, at uneven heights: no flat top
	for i, (x, up) in enumerate(((-0.8, 0.2), (-0.5, 0.34), (-0.18, 0.44), (0.18, 0.4), (0.5, 0.36), (0.8, 0.2))):
		gem(k, "Head", f"Slick{i}", (x * 0.7, -0.84, 5.46), (x * 1.0, 1.2, 5.3), 0.34, flat=0.7, bend=up, twist=0.15, a=0.46 + 0.08 * (i % 2), across=(1, 0, 0))
	for s in (1, -1):
		# the hairline: from the peak each lock sweeps out over the temple and falls back past the ear
		for i, (bx, bz, t, r) in enumerate(((0.06, 5.56, (0.62, -1.0, 5.1), 0.3), (0.16, 5.66, (0.98, -0.96, 4.86), 0.32), (0.34, 5.7, (1.16, -0.6, 4.6), 0.34), (0.5, 5.7, (1.24, 0.1, 4.84), 0.34))):
			gem(k, "Head", f"Sweep{s}{i}", (s * bx, -0.74, bz), tuple((s * t[0], t[1], t[2])), r, flat=0.45, bend=0.12, twist=0.15, a=0.48 + 0.07 * (i % 2), across=(s * 0.6, 0, 0.8))
		block(k, "Head", f"Temple{s}", s * 0.94, 0.14, 5.6, 4.94, 0.1, 0.74, "hair", ch=0.05, a=0.46, b=0.44)
		gem(k, "Head", f"Strand{s}", (s * 0.9, -0.62, 5.4), (s * 1.06, -0.8, 3.5), 0.22, flat=0.5, twist=0.1, a=0.56, across=(1, 0, 0))
		gem(k, "Head", f"Back{s}", (s * 0.8, 0.6, 5.3), (s * 1.16, 0.98, 3.4), 0.34, flat=0.5, a=0.5, across=(1, 0, 0))
	horns(k, [(0.62, -0.46, 5.66), (0.9, -0.46, 5.94), (1.12, -0.36, 6.28), (1.24, -0.24, 6.58), (1.28, -0.14, 6.82)], [0.22, 0.21, 0.17, 0.11, 0.02])


def _body(k):
	jacket(k, "uni", seam=None)
	collar(k, "uni", 4.24, 4.36, z0=3.92, rx=0.66, ry=0.6)
	collar(k, "gold", 4.3, 4.42, z0=4.2, rx=0.675, ry=0.615, name="CollarTrim")
	block(k, T, "Placket", 0, -0.64, 3.96, 2.0, 0.045, 0.02, "gold", ch=0.01, a=0.56, b=0.42)
	for i, z in enumerate((3.6, 3.16, 2.72)):
		for s in (1, -1):
			block(k, T, f"Button{i}{s}", s * 0.3, -0.64, z + 0.07, z - 0.07, 0.07, 0.035, "gold", ch=0.02, a=0.62, b=0.38)
	# the gold cord: from his left shoulder across the chest in two loops, with a tassel
	for j, (lo, end) in enumerate(((3.24, -0.52), (2.96, -0.6))):
		rod(k, T, f"Cord{j}", [(0.86, -0.72, 4.04), (0.5, -0.74, 3.5 - 0.12 * j), (0.1, -0.75, lo - 0.02), (-0.3, -0.73, lo + 0.06), (end, -0.68, 3.64)], 0.055, "gold", n=5, a=0.6, b=0.4)
	for d in (0, 0.14):
		gem(k, T, f"Tassel{d}", (-0.54 - d, -0.7, 3.66), (-0.54 - d, -0.74, 3.06), 0.08, "gold", flat=0.8, a=0.58)
	block(k, T, "Sash", 0, 0, 2.52, 2.24, 1.11, 0.63, "red", ch=0.03, sub=1, a=0.52, b=0.46)
	block(k, T, "Buckle", 0, -0.66, 2.54, 2.22, 0.15, 0.03, "gold", ch=0.015, a=0.58, b=0.42)
	skirt(k, "uni", 1.28, "gold", flare=0.06, th=0.07)
	# the great blue coat hung over the left shoulder: across the back and down that side to the calf
	pleat(k, T, "CoatBack", [(4.16, 0.3, 0.82, 0.9), (3.2, 0.3, 0.84, 0.98), (1.96, 0.3, 0.86, 1.06)], "blue", n=5, depth=0.08, th=0.12)
	pleat(k, T, "CoatFront", [(4.16, 0.86, -0.74, 0.3), (3.2, 0.9, -0.78, 0.28), (1.96, 0.98, -0.82, 0.3)], "blue", n=3, depth=0.06, d=-1, th=0.12)
	prism(k, T, "CoatEdge", [(0.46, 4.16), (0.58, 4.16), (0.64, 3.2), (0.72, 1.96), (0.6, 1.96), (0.52, 3.2)], -0.88, -0.66, "gold", a=0.56, b=0.42)
	collar(k, "blue", 3.94, 4.5, z0=3.8, rx=0.94, ry=0.82, power=1.1, name="CoatCollar")
	leg = "LeftUpperLeg"
	pleat(k, leg, "CoatLF", [(2.04, 0.99, -0.82, 0.31), (1.3, 1.02, -0.87, 0.36), (0.5, 1.06, -0.92, 0.42)], "blue", n=3, depth=0.07, d=-1, th=0.14)
	prism(k, leg, "CoatLEdge", [(0.6, 2.04), (0.72, 2.04), (0.68, 1.3), (0.7, 0.48), (0.56, 0.48), (0.58, 1.3)], -0.98, -0.78, "gold", a=0.56, b=0.42)
	block(k, leg, "CoatLS", 1.28, 0.0, 2.02, 0.5, 0.08, 0.82, "blue", ch=0.02, flare=0.08, a=0.5, b=0.48)
	pleat(k, leg, "CoatLB", [(2.04, 0.68, 0.86, 0.68), (0.5, 0.72, 0.96, 0.78)], "blue", n=3, depth=0.08, th=0.14)
	block(k, leg, "CoatLHem", 1.3, 0.0, 0.64, 0.46, 0.17, 1.06, "gold", ch=0.02, a=0.56, b=0.42)
	block(k, leg, "CoatBHem", 0.7, 0.92, 0.64, 0.46, 0.84, 0.16, "gold", ch=0.02, a=0.56, b=0.42)
	pleat(k, "RightUpperLeg", "CoatRB", [(2.04, -0.36, 0.86, 0.4), (0.5, -0.4, 0.96, 0.46)], "blue", n=2, depth=0.08, th=0.14)
	block(k, "RightUpperLeg", "CoatRHem", -0.4, 0.92, 0.64, 0.46, 0.5, 0.16, "gold", ch=0.02, a=0.56, b=0.42)


def _coat_arm(k):
	"""The coat's empty sleeve side covers his whole left arm as a hanging drape."""
	arm = "LeftUpperArm"
	block(k, arm, "Drape", 1.62, 0.04, 4.2, 2.56, 0.62, 0.72, "blue", ch=0.1, flare=0.1, corner=0.26, sub=1, jit=0.02, mids=(3.4,), a=0.52, b=0.48)
	block(k, arm, "DrapeHem", 1.62, 0.04, 2.7, 2.52, 0.735, 0.835, "gold", ch=0.03, corner=0.26, a=0.56, b=0.42)
	block(k, arm, "Epaulet", 1.6, 0, 4.3, 4.12, 0.5, 0.6, "gold", ch=0.05, corner=0.26, a=0.56, b=0.42)


def _sword(k):
	arm, x, y = "RightUpperArm", -1.5, -0.3

	def build():
		block(k, arm, "Grip", x, y, 2.8, 1.7, 0.09, 0.09, "gold", ch=0.02, a=0.44, b=0.4)
		block(k, arm, "Pommel", x, y, 3.0, 2.74, 0.16, 0.14, "gold", ch=0.05, a=0.58, b=0.42)
		prism(k, arm, "Guard", [(x - 0.66, 1.9), (x - 0.2, 1.74), (x + 0.2, 1.74), (x + 0.66, 1.9), (x + 0.56, 1.56), (x, 1.42), (x - 0.56, 1.56)], y - 0.12, y + 0.12, "gold", a=0.52, b=0.44)
		for d in (1, -1):
			prism(k, arm, f"Blade{d}", [(x, 1.48), (x + d * 0.3, 1.48), (x + d * 0.26, 0.6), (x + d * 0.32, -0.7), (x, -1.4)], y - 0.07, y + 0.07, "gold", a=0.62 + d * 0.12, b=0.36)

	turned(build, (x, y, 2.14), -52, 0, -30)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	elf_ears(k, out=1.42, up=4.98)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, "uni", hand="red")
		block(k, f"{side}UpperArm", "GloveCuff", s * 1.5, 0, 2.74, 2.44, 0.56, 0.56, "red", ch=0.04, corner=0.18, a=0.54, b=0.46)
		leg, px = trouser(k, side, s, "uni", low=1.06)
		boot(k, leg, px, "boot", "sole", top=1.1, cuff="gold")
	_coat_arm(k)
	_sword(k)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, SKIN_D, ("#143c80", "#3c84cc", "#b0e0ff"), "#2c1018", "#5c1830", "M53 109Q65 105 77 109", w=35, up=5, dn=6, inner=4, outer=-4.5, ir=(8, 8.5), pu=(2.4, 3.6), lid=0.5, thick=1.9, wing=6, brow_y=53, brow_w=34, brow_t=7.0, tilt=4.0, blush=0)
	# hollow cheeks, a hard jaw line, a longer nose, the frown between the brows
	f.path("M-5 84L12 92L28 118L40 135H-5Z", SKIN_D, opacity=0.6)
	f.path("M135 84L118 92L102 118L90 135H135Z", SKIN_D, opacity=0.75)
	f.path("M66 62L71 86L63 87Z", SKIN_D, opacity=0.6)
	f.path("M60 50L62 58M70 50L68 58", stroke="#9c6c5c", sw=1.2)
	f.path("M58 118L72 118", stroke=SKIN_D, sw=1.4)
	fill_body(a, SKIN, SKIN_D, "#26262f", "#26262f", "#26262f", "#6e1c38", "#8c161c")
