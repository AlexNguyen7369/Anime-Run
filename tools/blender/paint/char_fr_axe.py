# Target look for fr_axe "Stork" (design doc section 5): tomato-red spiky hair, dark underneath, a cowlick on the crown; sharp orange eyes, a scar down the
# left side of the forehead; a red coat with a cream fur lining over a black undershirt, brown belts, dark trousers, brown boots and a big battle axe. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, collar, ears, face, fill_body, finish, gem, helmet, jacket, locks, prism, rblock, skirt, sleeve, trouser, turned

SKIN = "#f6ceb0"
SKIN_D = "#cc9674"
DEFAULT = "#b02c2c"
R = Ramps(
	hair=["#8a1a16", "#b4261e", "#d8382c", "#ee5440", "#ff8466"],
	under=["#140c0e", "#1e1214", "#2c1a1c", "#3e282a"],
	skin=["#c48c6c", "#e4b494", "#f6ceb0", "#ffe6cc"],
	coat=["#5c1014", "#84181c", "#aa2428", "#c43a38", "#dc5c50"],
	fur=["#a89478", "#cfbfa0", "#ece0c6", "#fff8e8"],
	black=["#0a0a0e", "#16161c", "#24242c", "#383842"],
	belt=["#3a2212", "#5c381e", "#80522e", "#a47444"],
	gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	boot=["#2e1c12", "#4a2e1c", "#6a442a", "#8c6040"],
	steel=["#5c6470", "#8a92a0", "#bcc4d0", "#f0f4f8"],
	sole=["#100c0a", "#1c1612", "#2c241e", "#3c342c"],
)
HAIR = {"colour": "#D0342C", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.36, scalp="under")
	# the dark undercut round the ears and nape
	for s in (1, -1):
		for i, (y, z) in enumerate(((0.3, 4.36), (0.62, 4.14))):
			gem(k, "Head", f"Under{s}{i}", (s * 0.9, y, 5.2), (s * 1.12, y * 1.2, z), 0.3, "under", flat=0.45, across=(0, 1, 0))
	for i, x in enumerate((-0.6, 0, 0.6)):
		gem(k, "Head", f"UnderB{i}", (x, 0.8, 5.0), (x * 1.1, 1.14, 4.02), 0.34, "under", flat=0.45, across=(1, 0, 0))
	# red mass: a shaggy bowl of spikes out and down from the crown
	c = (0, 0.08, 6.0)
	for i, (t, r) in enumerate((((-1.02, -0.84, 5.5), 0.44), ((-0.36, -1.02, 5.56), 0.46), ((0.36, -1.02, 5.56), 0.46), ((1.02, -0.84, 5.5), 0.44), ((-1.3, -0.2, 5.46), 0.46), ((1.3, -0.2, 5.46), 0.46), ((-1.24, 0.5, 5.3), 0.46), ((1.24, 0.5, 5.3), 0.46), ((-0.7, 1.16, 5.3), 0.48), ((0.7, 1.16, 5.3), 0.48), ((0, 1.26, 5.36), 0.48))):
		gem(k, "Head", f"Mass{i}", c, t, r, flat=0.6, bend=0.16, twist=0.25, a=0.5 + 0.05 * (i % 2))
	for s in (1, -1):
		gem(k, "Head", f"Wing{s}", (s * 0.8, 0.1, 5.7), (s * 1.5, 0.1, 5.02), 0.34, flat=0.5, bend=0.1, a=0.54)
		gem(k, "Head", f"Wing2{s}", (s * 0.7, 0.5, 5.7), (s * 1.42, 0.7, 4.78), 0.34, flat=0.5, bend=0.08, a=0.46)
		gem(k, "Head", f"Burn{s}", (s * 0.94, -0.56, 5.46), (s * 1.04, -0.66, 4.62), 0.22, flat=0.45, across=(0, 1, 0))
	locks(k, "Bang", None, (((-0.72, -0.78, 5.72), (-1.0, -0.98, 4.94), 0.28), ((-0.44, -0.8, 5.74), (-0.62, -1.04, 5.02), 0.28), ((-0.14, -0.82, 5.76), (-0.22, -1.06, 4.96), 0.28), ((0.14, -0.82, 5.76), (0.16, -1.05, 5.12), 0.26), ((0.42, -0.8, 5.74), (0.7, -1.03, 5.16), 0.27), ((0.7, -0.78, 5.72), (1.02, -0.98, 4.98), 0.28)))
	# the cowlick, forked like a stem
	gem(k, "Head", "Stem", (0.0, 0.1, 6.02), (0.3, 0.05, 6.66), 0.2, flat=0.6, bend=0.1, a=0.56)
	gem(k, "Head", "Stem2", (0.0, 0.14, 6.02), (-0.3, 0.2, 6.48), 0.17, flat=0.6, bend=0.1, a=0.56)


def _coat(k):
	jacket(k, "coat", seam=None)
	prism(k, T, "Shirt", [(-0.36, 4.06), (0.36, 4.06), (0.1, 3.0), (-0.1, 3.0)], -0.63, -0.5, "black", a=0.5, b=0.5)
	collar(k, "black", 4.2, 4.3, z0=3.9, rx=0.62, ry=0.58, name="Neck")
	# the fur-lined collar, broad round the back and turned out down the front
	collar(k, "fur", 4.06, 4.34, z0=3.86, rx=0.98, ry=0.84, power=1.4)
	for s in (1, -1):
		prism(k, T, f"Fur{s}", [(s * 0.36, 4.12), (s * 0.82, 4.12), (s * 0.78, 3.66), (s * 0.28, 2.92), (s * 0.08, 2.92)], -0.72, -0.56, "fur", a=0.54, b=0.44)
		prism(k, T, f"Edge{s}", [(s * 0.03, 2.92), (s * 0.14, 2.92), (s * 0.14, 2.0), (s * 0.03, 2.0)], -0.64, -0.58, "fur", a=0.54, b=0.44)
	# two belts, the lower one slung
	block(k, T, "Belt", 0, 0, 2.6, 2.4, 1.11, 0.63, "belt", ch=0.03, sub=1, a=0.52, b=0.48)
	rblock(k, T, "Belt2", 0, 0, 2.34, 2.18, 1.13, 0.65, "belt", ch=0.03, rot=((0, 0, 2.26), 0, 5, 0), a=0.48, b=0.48)
	block(k, T, "Buckle", 0.1, -0.66, 2.64, 2.36, 0.17, 0.03, "gold", ch=0.02, a=0.56, b=0.44)
	prism(k, T, "Strap", [(1.06, 3.96), (0.86, 4.04), (-1.06, 2.76), (-1.06, 2.56)], -0.75, -0.6, "belt", a=0.5, b=0.48)
	skirt(k, "coat", 1.26, "under", flare=0.08, th=0.12)
	for s in (1, -1):
		prism(k, f"{'Left' if s > 0 else 'Right'}UpperLeg", "Slit", [(s * 0.0, 2.0), (s * 0.1, 2.0), (s * 0.26, 1.24), (s * 0.0, 1.24)], -0.78, -0.6, "black", a=0.4, b=0.4)


def _axe(k):
	arm, x, y = "RightUpperArm", -1.62, -0.62

	def build():
		block(k, arm, "Haft", x, y, 5.5, 0.9, 0.085, 0.085, "belt", ch=0.02, a=0.5, b=0.46)
		for z in (1.0, 2.5, 3.5):
			block(k, arm, "Ring", x, y, z + 0.09, z - 0.09, 0.12, 0.12, "steel", ch=0.02, a=0.54, b=0.46)
		block(k, arm, "Socket", x, y, 5.3, 4.5, 0.15, 0.13, "gold", ch=0.03, a=0.54, b=0.44)
		blade = [(x - 0.1, 5.16), (x - 0.36, 5.3), (x - 0.66, 5.78), (x - 0.86, 5.4), (x - 0.92, 4.9), (x - 0.86, 4.4), (x - 0.66, 4.02), (x - 0.36, 4.5), (x - 0.1, 4.64)]
		prism(k, arm, "Axe", blade, y - 0.08, y + 0.08, "steel", a=0.46, b=0.4)
		prism(k, arm, "AxeEdge", [(x - 0.6, 5.84), (x - 0.9, 5.46), (x - 1.0, 4.9), (x - 0.9, 4.34), (x - 0.6, 3.96), (x - 0.78, 4.42), (x - 0.84, 4.9), (x - 0.78, 5.38)], y - 0.05, y + 0.05, "steel", a=0.78, b=0.24)
		prism(k, arm, "Spike", [(x + 0.1, 5.1), (x + 0.44, 4.9), (x + 0.1, 4.7)], y - 0.06, y + 0.06, "steel", a=0.5, b=0.42)

	turned(build, (x, y, 2.2), -4, 4, 0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_coat(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, "coat")
		block(k, f"{side}UpperArm", "Cuff2", s * 1.5, 0, 2.72, 2.48, 0.56, 0.56, "under", ch=0.04, corner=0.18, a=0.54, b=0.44)
		block(k, f"{side}UpperArm", "Glove", s * 1.5, 0, 2.54, 2.0, 0.51, 0.51, "black", ch=0.03, a=0.5, b=0.5)
		leg, px = trouser(k, side, s, "black", low=0.94)
		boot(k, leg, px, "boot", "sole", top=0.96, cuff="belt")
	_axe(k)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, SKIN_D, ("#7a3a08", "#d8781c", "#ffc050"), "#2c1210", "#7a1c18", "M54 109Q65 105 76 109", w=33, up=10, dn=9, inner=4, outer=-5, ir=(8.6, 10), pu=(2.8, 4), lid=0.3, thick=1.4, brow_y=46, brow_t=6.0, tilt=3.4, blush=0.1)
	# the scar: from the hairline down over his left brow
	f.path("M100 22L96 36L99 46L94 60L91 46L92 36Z", "#b0604c")
	f.path("M98 26L95 38L97 46L94 56", stroke="#e8a890", sw=1.2)
	fill_body(a, SKIN, SKIN_D, "#9c2224", "#9c2224", "#1e1e26", "#2c1a1c", "#24242c")
