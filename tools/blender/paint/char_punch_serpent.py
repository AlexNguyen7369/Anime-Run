# punch_serpent "Orochy": the monster king's man shape: a broad giant, long pale horns curling over a crowned skull mask of a face, rope-like dark hair ending in serpent heads, scaled skin, a torn ruler's mantle.
from w2_kit import *  # noqa: F403

SKIN = "#a8937e"
R = Ramps(skin=["#4e4238", "#78685a", "#a8937e", "#d2c0aa"], hair=["#20160f", "#38281c", "#58412e", "#866748"], horn=["#8a7c62", "#b8a988", "#e0d4b6", "#fbf4de"], scale=["#3a1e1a", "#5c302a", "#86463a", "#b46e5a"], red=["#7c0c08", "#c01c10", "#f04a24", "#ffb060"], cloth=["#221a2c", "#3a2c48", "#584468", "#84709a"], gold=ramp("#c89a3a"), sole=ramp("#1a1410"))
DEFAULT = "#58412e"
HAIR = {"colour": "#58412E", "locks": []}
PROPS = []


def _snake(k, name, pts, r):
	"""A coil segment by segment, ending in a wedge head with lit eyes."""
	for i, (p, q) in enumerate(zip(pts, pts[1:])):
		rod(k, "Head", f"{name}{i}", p, q, r * (1 - 0.08 * i), "scale", r1=r * (0.92 - 0.08 * i), n=8)
	x, y, z = pts[-1]
	gem(k, "Head", name + "Skull", (x, y + 0.2, z + 0.06), (x, y - 0.74, z - 0.02), 0.28, "scale", flat=0.6, across=(1, 0, 0), a=0.62)
	gem(k, "Head", name + "Jaw", (x, y + 0.16, z - 0.12), (x, y - 0.56, z - 0.34), 0.2, "horn", flat=0.5, across=(1, 0, 0))
	for s in (1, -1):
		block(k, "Head", f"{name}Eye{s}", x + s * 0.17, y - 0.2, z + 0.18, z + 0.08, 0.06, 0.08, "red", ch=0.015, a=0.7)
		gem(k, "Head", f"{name}Fang{s}", (x + s * 0.07, y - 0.5, z - 0.06), (x + s * 0.07, y - 0.5, z - 0.28), 0.05, "horn")


def model(parts, kit):
	k = start(kit, parts, R)
	crown(k, [(0.98, 5.3), (1.06, 5.56), (0.96, 5.82), (0.6, 6.0), (0.2, 6.04)])
	for s in (1, -1):
		# ram-like horns
		for i, (b, t, r) in enumerate((((0.6, -0.2, 5.7), (1.26, -0.2, 6.3), 0.3), ((1.2, -0.2, 6.24), (1.6, -0.4, 6.7), 0.24))):
			rod(k, "Head", f"Horn{i}{s}", (s * b[0], b[1], b[2]), (s * t[0], t[1], t[2]), r, "horn", r1=r * 0.78, n=7)
		gem(k, "Head", f"HornTip{s}", (s * 1.58, -0.38, 6.66), (s * 1.46, -0.9, 7.3), 0.2, "horn", a=0.6)
		_snake(k, f"SnakeA{s}", [(s * 0.8, 0.4, 5.5), (s * 1.5, 0.5, 5.6), (s * 1.8, 0.2, 5.1), (s * 2.0, -0.4, 5.3)], 0.32)
		_snake(k, f"SnakeB{s}", [(s * 0.8, 0.6, 5.0), (s * 1.3, 0.7, 4.5), (s * 1.5, -0.1, 4.2), (s * 1.36, -0.8, 4.36)], 0.32)
		_snake(k, f"SnakeC{s}", [(s * 0.3, 0.5, 5.8), (s * 0.4, 0.8, 6.5), (s * 0.6, 0.4, 6.9), (s * 0.56, -0.2, 6.8)], 0.3)
		gem(k, "Head", f"Brow{s}", (s * 0.1, -0.88, 5.02), (s * 0.94, -0.96, 5.3), 0.17, "horn", flat=0.5)
		gem(k, "Head", f"Cheek{s}", (s * 0.8, -0.76, 4.5), (s * 1.1, -0.96, 4.1), 0.18, "horn")
	locks(k, "Back", [((0.5, 0.7, 5.6), (0.7, 1.1, 4.0), 0.4), ((-0.5, 0.7, 5.6), (-0.7, 1.1, 4.0), 0.4), ((0, 0.8, 5.6), (0, 1.2, 3.8), 0.46)])
	for s in (1, -1):
		prism(k, "Head", f"MaskC{s}", [(s * 0.5, 4.8), (s * 0.94, 4.96), (s * 0.94, 4.2), (s * 0.6, 4.0), (s * 0.34, 4.3)], -1.0, -0.84, "horn", a=0.5)
		for i in range(3):
			gem(k, "Head", f"MaskT{i}{s}", (s * (0.14 + 0.22 * i), -0.92, 4.46), (s * (0.14 + 0.22 * i), -1.04, 4.1), 0.12, "horn", a=0.6)
		arm = "LeftUpperArm" if s > 0 else "RightUpperArm"
		for r, z in enumerate((3.5, 3.24, 2.98)):
			for c in (-1, 0, 1):
				gem(k, arm, f"AScale{r}{c}", (s * 1.5 + c * 0.32, -0.5, z), (s * 1.5 + c * 0.34, -0.66, z - 0.4), 0.22, "scale", flat=0.4, across=(1, 0, 0))
			gem(k, arm, f"AFin{r}", (s * 2.0, 0, z), (s * 2.4, 0.2, z + 0.3), 0.2, "horn", flat=0.5, across=(0, 1, 0))
		for c in range(4):
			gem(k, T, f"ChestS{s}{c}", (s * (0.2 + 0.24 * c), -0.62, 3.86), (s * (0.24 + 0.24 * c), -0.76, 3.46), 0.2, "scale", flat=0.4, across=(1, 0, 0))
	locks(k, "Crest", [((0, -0.5, 5.7), (0, -0.8, 6.3), 0.26)], "horn")
	art_jacket(k)
	block(k, T, "Body", 0, 0, 4.0, 2.1, 1.1, 0.6, "skin", ch=0.06, corner=0.14, sub=1)
	for s in (1, -1):
		prism(k, T, f"Pec{s}", [(s * 0.04, 3.86), (s * 1.04, 3.86), (s * 1.06, 3.36), (s * 0.5, 3.1), (s * 0.04, 3.18)], -0.68, -0.56, "skin", a=0.58)
		for r, z in enumerate((3.12, 2.9, 2.68)):
			for c in range(3):
				x = s * (0.18 + 0.32 * c + 0.08 * (r % 2))
				prism(k, T, f"Scale{s}{z}{c}", [(x - 0.17, z), (x + 0.17, z), (x + 0.13, z - 0.18), (x, z - 0.3), (x - 0.13, z - 0.18)], -0.68 + 0.01 * r, -0.56, "skin", a=0.5 + 0.06 * (c % 2))
		block(k, T, f"Mantle{s}", s * 0.94, 0.1, 4.14, 3.3, 0.22, 0.7, "cloth", ch=0.06, jit=0.02)
	block(k, T, "Cape", 0, 0.72, 4.12, 1.3, 1.16, 0.08, "cloth", ch=0.03, flare=0.2, mids=(3.2, 2.2), jit=0.03)
	for i, x in enumerate((-0.8, -0.4, 0, 0.4, 0.8)):
		gem(k, T, f"CapeFold{i}", (x, 0.8, 4.0), (x * 1.5, 1.0, 1.0 + 0.2 * (i % 2)), 0.24, "cloth", flat=0.4, across=(1, 0, 0), a=0.6)
	block(k, T, "CapeYoke", 0, 0.82, 4.12, 3.8, 1.1, 0.06, "gold", ch=0.03)
	back_hair(k, low=4.1)
	block(k, T, "Belt", 0, 0, 2.4, 2.1, 1.14, 0.66, "gold", ch=0.05)
	block(k, T, "Core", 0, -0.7, 3.56, 3.3, 0.14, 0.06, "red", ch=0.03, corner=0.3, a=0.66)
	arms(k, [("Arm", 3.96, 2.5, 0.54, "skin"), ("Pad", 4.16, 3.6, 0.64, "cloth"), ("Band", 2.9, 2.5, 0.6, "scale"), ("Hand", 2.56, 1.72, 0.56, "skin")])
	for s, side in ((1, "Left"), (-1, "Right")):
		gem(k, f"{side}UpperArm", "PadSpike", (s * 1.7, 0, 4.1), (s * 2.2, 0, 4.7), 0.24, "horn")
		block(k, f"{side}UpperLeg", "Loin", s * 0.46, -0.64, 2.04, 1.0, 0.46, 0.06, "cloth", ch=0.02, flare=0.05)
	legs(k, [("Thigh", 2.02, 0.9, 0.52, "cloth"), ("Shin", 1.0, 0.3, 0.52, "scale")], shoe=(0.6, "scale", "sole"))
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, ("#7c0c08", "#f04a24", "#ffe08a"), None, white="#180606", lash="#140808", up=10, dn=7, inner=6, outer=-8, lid=0.0, mouth="grin", ir=(8, 8), pu=(1.6, 5), line="#2a120c")
	for s in (1, -1):
		f.path(f"M{65 + s * 10} 84L{65 + s * 34} 92L{65 + s * 20} 98Z", "#78685a")
	base(a, SKIN, SKIN, SKIN, "#3a2c48", hair="#38281c")
