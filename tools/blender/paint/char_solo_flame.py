# solo_flame "Barran": the demon king: a pale stern face under a tall horned crown helm, long white hair, black and gold plate with a great fur-edged crimson cape, white fire at both fists.
from w2_kit import *  # noqa: F403

SKIN = "#c9b2b8"
R = Ramps(skin=ramp(SKIN), hair=["#8c8494", "#b8b0c0", "#e0dae6", "#ffffff"], plate=["#1c1624", "#322a3e", "#4e4460", "#807490"], gold=["#7c5210", "#b4822a", "#e2b650", "#fff0a8"], horn=["#1c1216", "#33222a", "#523a42", "#7c5e66"], cape=["#34080e", "#5c1018", "#8a1c24", "#b63a3a"], fur=["#7c7680", "#aaa4b0", "#d8d4de", "#ffffff"], fire=["#a8b8f0", "#ccd8fc", "#ecf2ff", "#ffffff"], sole=ramp("#100c14"))
DEFAULT = "#1f1a26"
HAIR = {"colour": "#E0DAE6", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R)
	h = "Head"
	crown(k, [(1.02, 5.2), (1.08, 5.5), (1.0, 5.8), (0.66, 6.0), (0.2, 6.06)], "plate")
	block(k, h, "Circlet", 0, -0.02, 5.46, 5.2, 1.08, 1.02, "gold", ch=0.04, corner=0.3)
	prism(k, h, "Crest", [(-0.24, 5.2), (0.24, 5.2), (0.32, 5.7), (0, 6.5), (-0.32, 5.7)], -1.08, -0.94, "gold", a=0.6)
	for s in (1, -1):
		# two pairs of horns
		rod(k, h, f"HornA{s}", (s * 0.8, 0, 5.7), (s * 1.5, 0.1, 6.0), 0.28, "horn", r1=0.24)
		rod(k, h, f"HornB{s}", (s * 1.46, 0.1, 5.96), (s * 1.8, 0, 6.6), 0.24, "horn", r1=0.18)
		gem(k, h, f"HornC{s}", (s * 1.8, 0, 6.54), (s * 1.56, -0.3, 7.5), 0.19, "horn")
		gem(k, h, f"HornS{s}", (s * 0.5, -0.3, 5.86), (s * 0.7, -0.5, 6.8), 0.2, "horn")
		prism(k, h, f"Cheek{s}", [(s * 0.72, 5.24), (s * 1.04, 5.24), (s * 1.0, 4.3), (s * 0.78, 4.5)], -0.96, -0.2, "plate")
		gem(k, h, f"Lock{s}", (s * 0.96, -0.2, 4.9), (s * 1.16, -0.4, 3.3), 0.3, "hair", flat=0.5, across=(0, 1, 0))
		gem(k, h, f"LockB{s}", (s * 0.7, 0.7, 5.2), (s * 0.9, 1.1, 2.9), 0.42, "hair", flat=0.5, across=(1, 0, 0))
	gem(k, h, "LockC", (0, 0.8, 5.2), (0, 1.2, 2.7), 0.46, "hair", flat=0.5, across=(1, 0, 0))
	art_jacket(k)
	block(k, T, "Plate", 0, 0, 3.98, 2.6, 1.1, 0.64, "plate", ch=0.08, corner=0.16, sub=1)
	for s in (1, -1):
		prism(k, T, f"Breast{s}", [(s * 0.06, 3.8), (s * 1.0, 3.9), (s * 1.04, 3.2), (s * 0.5, 2.9), (s * 0.06, 3.1)], -0.74, -0.62, "plate", a=0.62)
		prism(k, T, f"Trim{s}", [(s * 0.04, 3.16), (s * 0.5, 2.94), (s * 1.06, 3.24), (s * 1.06, 3.12), (s * 0.5, 2.8), (s * 0.04, 3.02)], -0.77, -0.64, "gold")
	for z in (2.86, 2.6):
		block(k, T, f"Ab{z}", 0, -0.02, z, z - 0.22, 0.9, 0.68, "plate", ch=0.05, a=0.44)
	block(k, T, "Belt", 0, 0, 2.34, 2.08, 1.14, 0.68, "gold", ch=0.05)
	prism(k, T, "Buckle", [(0, 2.44), (0.26, 2.2), (0, 1.86), (-0.26, 2.2)], -0.78, -0.66, "cape")
	collar(k, "fur", 3.98, 4.6, z0=3.6, rx=1.24, ry=0.9, name="Fur", a=0.6)
	block(k, T, "Cape", 0, 0.78, 4.1, 0.5, 1.3, 0.09, "cape", ch=0.03, flare=0.34, mids=(3.2, 2.2, 1.2), jit=0.04)
	for i, x in enumerate((-0.9, -0.45, 0, 0.45, 0.9)):
		gem(k, T, f"CapeFold{i}", (x, 0.86, 4.0), (x * 1.5, 1.04, 0.4 + 0.2 * (i % 2)), 0.26, "cape", flat=0.4, across=(1, 0, 0), a=0.62)
	for s in (1, -1):
		gem(k, "Head", f"Scowl{s}", (s * 0.1, -0.94, 4.86), (s * 0.84, -1.0, 5.16), 0.12, "hair", flat=0.5)
		gem(k, "Head", f"Fang{s}", (s * 0.2, -0.86, 4.24), (s * 0.2, -0.92, 4.06), 0.06, "hair")
		block(k, "Head", f"Temple{s}", s * 0.94, -0.3, 5.3, 4.3, 0.06, 0.5, "plate", ch=0.02)
	back_hair(k, low=3.8)
	arms(k, [("Arm", 3.94, 2.6, 0.48, "plate"), ("Pad", 4.26, 3.5, 0.66, "plate"), ("PadRim", 3.62, 3.46, 0.68, "gold"), ("Vam", 3.0, 2.4, 0.58, "plate"), ("VamRim", 2.5, 2.36, 0.6, "gold"), ("Hand", 2.44, 1.74, 0.54, "plate")])
	for s, side in ((1, "Left"), (-1, "Right")):
		arm, leg, x = f"{side}UpperArm", f"{side}UpperLeg", s * 1.5
		for i, (dx, dy, z) in enumerate(((0.1, 0, 5.1), (0.5, 0.1, 4.7))):
			gem(k, arm, f"PadSpike{i}", (x + s * dx, dy, 4.1), (x + s * (dx + 0.4), dy, z), 0.22, "gold")
		# clawed gauntlet flares lit white at the knuckles, flames licking up the outside of the arm
		block(k, arm, "Knuckle", x, -0.5, 2.14, 1.9, 0.5, 0.1, "fire", ch=0.04, a=0.66)
		for i, (dz, r, t) in enumerate(((2.0, 0.3, 2.9), (2.3, 0.26, 3.3), (2.6, 0.2, 3.6))):
			gem(k, arm, f"Fire{i}", (x + s * 0.44, -0.2 + 0.2 * i, dz), (x + s * 0.86, -0.1 + 0.2 * i, t), r, "fire", flat=0.5, bend=-0.1, across=(0, 1, 0), a=0.66)
		block(k, leg, "Tasset", s * 0.56, -0.62, 2.04, 1.2, 0.46, 0.08, "plate", ch=0.03, flare=0.05)
		block(k, leg, "TassetG", s * 0.56, -0.66, 1.3, 1.16, 0.5, 0.06, "gold", ch=0.02)
		block(k, leg, "Knee", s * 0.54, -0.56, 1.16, 0.74, 0.34, 0.14, "gold", ch=0.05, corner=0.3)
	legs(k, [("Leg", 2.02, 0.9, 0.5, "plate")], shoe=(0.98, "plate", "sole"))
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, ("#8a1410", "#f03c20", "#ffc080"), "#5a5264", up=9, dn=6, inner=6, outer=-7, lid=0.3, tilt=6, thick=6, mouth="grin", white="#1a0c10", ir=(8, 8), pu=(1.6, 4))
	base(a, SKIN, "#322a3e", "#322a3e", "#322a3e", hair="#b8b0c0")
