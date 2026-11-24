# Target look for fr_staff "Ferne" (design doc section 5): long straight purple hair with a blunt fringe and long side locks, half tied up behind with a dark butterfly
# ornament; level purple eyes; a white high-necked dress under a long black coat, brown boots, a tall dark staff with a red orb in a hooked head. +X is the viewer's right. Drawn in-house.
from fr_style3 import Kit, Ramps, T, big_head, block, boot, collar, face, fill_body, finish, gem, helmet, jacket, locks, mane, open_coat, prism, rod, skirt, sleeve, turned

SKIN = "#fbe0d0"
SKIN_D = "#d8aa98"
DEFAULT = "#1e1c28"
R = Ramps(
	hair=["#3a2458", "#523678", "#6e4c98", "#8a68b4", "#ae90d2"],
	skin=["#c89c88", "#e8c4b2", "#fbe0d0", "#fff0e6"],
	coat=["#0a0a12", "#14131c", "#201e2a", "#322f40", "#4a465a"],
	trim=["#2a2836", "#3e3b4c", "#565264", "#767284"],
	white=["#9a98ae", "#c4c3d2", "#e6e5ee", "#f8f8fc", "#ffffff"],
	boot=["#2c1a12", "#48301e", "#684830", "#8a6648"],
	sole=["#100c0a", "#1c1612", "#2c241e", "#3c342c"],
	wood=["#1c1214", "#2e1e20", "#443032", "#604a4a"],
	gold=["#8a6210", "#c39028", "#e8be4c", "#fff0a8"],
	gem=["#4a0610", "#98101c", "#dc2c38", "#ff9a8c"],
	fly=["#1a2460", "#2c3c94", "#4a60c8", "#90a4f4"],
)
HAIR = {"colour": "#6E4C98", "locks": []}
PROPS = []


def _hair(k):
	helmet(k, low=4.2)
	mane(k, 1.5, mid=1.0, end=0.74, n=5)
	# blunt fringe, side to side, just over the eyes
	for i, x in enumerate((-0.84, -0.56, -0.28, 0, 0.28, 0.56, 0.84)):
		pts = [(x * 0.8 - 0.12, 5.86), (x * 0.8 + 0.12, 5.86), (x + 0.16, 5.4), (x + 0.15, 4.98 + 0.04 * (i % 2)), (x, 4.92 + 0.05 * (i % 2)), (x - 0.15, 4.98 + 0.04 * (i % 2)), (x - 0.16, 5.4)]
		prism(k, "Head", f"Bang{i}", pts, -1.0 + 0.04 * (i % 2), -0.82, "hair", a=0.54 + 0.05 * (i % 2), b=0.42)
	locks(k, "Over", (0, -0.1, 6.1), (((-0.84, -1.02, 5.1), 0.36), ((-0.44, -1.1, 5.06), 0.36), ((0, -1.1, 5.04), 0.36), ((0.44, -1.1, 5.06), 0.36), ((0.84, -1.02, 5.1), 0.36)), bend=0.24)
	for s in (1, -1):
		# hair over the ears and the long straight side locks in front of the shoulders
		block(k, "Head", f"Side{s}", s * 0.98, -0.04, 5.6, 4.1, 0.1, 0.62, "hair", ch=0.05, flare=0.05, a=0.48, b=0.46)
		gem(k, "Head", f"Long{s}", (s * 0.94, -0.66, 5.5), (s * 0.94, -0.84, 2.5), 0.3, flat=0.45, twist=0.1, a=0.54, across=(1, 0, 0))
		gem(k, "Head", f"Long2{s}", (s * 1.06, -0.3, 5.3), (s * 1.16, -0.66, 3.0), 0.3, flat=0.45, twist=0.15, a=0.46, across=(0, 1, 0))
		gem(k, "Head", f"Half{s}", (s * 0.96, 0.1, 5.5), (s * 0.12, 1.16, 5.2), 0.2, flat=0.5, a=0.56)
		# the ornament's wings, seen past the head from the sides and the back
		prism(k, "Head", f"Fly{s}", [(s * 0.04, 5.3), (s * 0.2, 5.72), (s * 0.62, 5.86), (s * 0.66, 5.5), (s * 0.42, 5.26), (s * 0.54, 4.94), (s * 0.3, 4.8), (s * 0.06, 5.1)], 1.2, 1.32, "fly", a=0.56, b=0.4)
	block(k, "Head", "FlyBody", 0, 1.3, 5.46, 4.9, 0.06, 0.06, "gold", ch=0.02, a=0.56, b=0.4)


def _dress(k):
	jacket(k, "white", seam=None)
	collar(k, "white", 4.26, 4.4, z0=3.94, rx=0.64, ry=0.6, name="Neck")
	for i, x in enumerate((-0.2, 0, 0.2)):
		block(k, T, f"Pleat{i}", x, -0.64, 3.94, 2.5, 0.025, 0.02, "white", ch=0.008, a=0.36, b=0.3)
	block(k, T, "Waist", 0, -0.02, 2.46, 2.3, 1.08, 0.62, "trim", ch=0.02, a=0.5, b=0.46)
	block(k, T, "Brooch", 0, -0.7, 4.16, 3.94, 0.11, 0.05, "gold", ch=0.03, a=0.58, b=0.4)
	skirt(k, "white", 0.86, None, flare=0.08, d=0.6)
	open_coat(k, "coat", "trim", 0.66, gap=0.5, low_gap=0.6)
	# the hood lying on the shoulders
	collar(k, "coat", 3.98, 4.34, z0=3.76, rx=1.04, ry=0.92, power=1.2, name="Hood")


def _staff(k):
	arm, x, y = "RightUpperArm", -1.62, -0.64

	def build():
		block(k, arm, "Shaft", x, y, 5.0, 0.2, 0.07, 0.07, "wood", ch=0.02, a=0.52, b=0.46)
		block(k, arm, "Butt", x, y, 0.4, 0.1, 0.1, 0.1, "gold", ch=0.03, a=0.56, b=0.44)
		block(k, arm, "Neck", x, y, 5.06, 4.8, 0.11, 0.11, "gold", ch=0.03, a=0.56, b=0.44)
		hook = [(x, y, 4.96), (x + 0.28, y, 5.12), (x + 0.4, y, 5.42), (x + 0.28, y, 5.72), (x, y, 5.86), (x - 0.28, y, 5.74), (x - 0.38, y, 5.5)]
		rod(k, arm, "Hook", hook, [0.08, 0.1, 0.11, 0.11, 0.1, 0.08, 0.04], "wood", n=5, a=0.54, b=0.46)
		rod(k, arm, "Orb", [(x, y, 5.22), (x, y, 5.3), (x, y, 5.42), (x, y, 5.54), (x, y, 5.62)], [0.06, 0.18, 0.22, 0.18, 0.06], "gem", n=8, a=0.56, b=0.5)

	turned(build, (x, y, 2.2), -4, 4, 0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_dress(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, "coat")
		block(k, f"{side}UpperArm", "WideCuff", s * 1.5, 0, 3.0, 2.46, 0.54, 0.54, "coat", ch=0.04, flare=0.08, corner=0.18, a=0.48, b=0.5)
		block(k, f"{side}UpperArm", "CuffTrim", s * 1.5, 0, 2.58, 2.44, 0.63, 0.63, "trim", ch=0.02, corner=0.18, a=0.52, b=0.46)
		leg, px = f"{side}UpperLeg", s * 0.53
		k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.46, 0.48), (s * 0.5, 0, 0.1, 0.46, 0.48)], corner=0.1, nc=1)
		boot(k, leg, px, "boot", "sole", top=0.94)
	_staff(k)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, SKIN_D, ("#4a2880", "#8a58c8", "#d0a8ff"), "#2c1c40", "#5a3c7c", "M57 106Q65 105 73 106", w=34, up=12, dn=10, inner=1.5, outer=-1.5, ir=(11, 13), lid=0.34, thick=1.5, brow_y=43, brow_t=2.8, tilt=-0.6, blush=0.26)
	fill_body(a, SKIN, SKIN_D, "#e0dfe8", "#1e1c28", "#181620", "#523678")
