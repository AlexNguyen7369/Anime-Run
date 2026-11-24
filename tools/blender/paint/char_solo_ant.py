# solo_ant "Berru": the living ant king, not the violet shadow Sidekick: dark blue-black plated insect man, pale segmented chest, wide mandibles and long antennae, translucent wings, clawed forearms.
from w2_kit import *  # noqa: F403

SKIN = "#222a3c"
R = Ramps(skin=ramp(SKIN), shell=["#080b14", "#141b2c", "#26324c", "#4c5e80"], plate=["#1c2a3a", "#30475c", "#4c6c84", "#86aabe"], bone=["#6c6254", "#988c78", "#c8bca2", "#f0e8d2"], eye=["#8a0c10", "#c81c1c", "#f04a34", "#ffb090"], wing=["#5c7a84", "#86a8b0", "#b4d2d6", "#e4f6f6"], claw=["#16161c", "#2c2c36", "#50505e", "#8c8c9c"], sole=ramp("#10131c"))
DEFAULT = "#141b2c"
HAIR = {"colour": "#26324C", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R, ear=False)
	h = "Head"
	crown(k, [(1.0, 5.16), (1.1, 5.5), (1.0, 5.84), (0.66, 6.1), (0.2, 6.24)], "shell")
	block(k, h, "Face", 0, -0.12, 5.2, 4.1, 0.92, 0.82, "shell", ch=0.12, corner=0.26)
	prism(k, h, "Ridge", [(-0.14, 5.3), (0.14, 5.3), (0.22, 4.9), (0, 4.56), (-0.22, 4.9)], -1.04, -0.9, "plate", a=0.6)
	for s in (1, -1):
		prism(k, h, f"Eye{s}", [(s * 0.28, 4.8), (s * 0.5, 5.12), (s * 0.98, 5.24), (s * 0.92, 4.92)], -1.02, -0.9, "eye", a=0.66)
		gem(k, h, f"Brow{s}", (s * 0.18, -0.94, 5.14), (s * 1.16, -0.8, 5.56), 0.2, "shell", flat=0.6)
		gem(k, h, f"Mand{s}", (s * 0.66, -0.76, 4.4), (s * 0.5, -1.36, 4.06), 0.24, "bone")
		gem(k, h, f"MandTip{s}", (s * 0.56, -1.26, 4.12), (s * 0.06, -1.5, 3.9), 0.14, "bone")
		rod(k, h, f"AntA{s}", (s * 0.36, -0.6, 5.9), (s * 0.7, -0.9, 6.7), 0.1, "shell", r1=0.08)
		gem(k, h, f"AntB{s}", (s * 0.68, -0.88, 6.64), (s * 1.6, -0.8, 7.1), 0.1, "shell")
		gem(k, h, f"Crest{s}", (s * 0.6, 0.2, 5.8), (s * 1.0, 1.1, 6.3), 0.34, "shell", flat=0.6)
		for i in range(2):
			gem(k, h, f"Teeth{i}{s}", (s * (0.14 + 0.2 * i), -0.92, 4.4), (s * (0.14 + 0.2 * i), -0.98, 4.12), 0.08, "bone")
	for s in (1, -1):
		prism(k, h, f"CheekP{s}", [(s * 0.5, 4.8), (s * 1.02, 4.96), (s * 1.06, 4.4), (s * 0.7, 4.16), (s * 0.44, 4.4)], -1.0, -0.7, "plate", a=0.56)
		gem(k, h, f"JawS{s}", (s * 0.9, -0.2, 4.7), (s * 1.3, -0.5, 4.1), 0.24, "plate", flat=0.6, across=(0, 1, 0))
		gem(k, h, f"Swept{s}", (s * 0.3, 0.4, 5.9), (s * 0.5, 1.8, 6.0), 0.4, "shell", flat=0.6, across=(1, 0, 0))
		gem(k, h, f"SweptL{s}", (s * 0.6, 0.5, 5.3), (s * 0.9, 1.5, 5.0), 0.4, "plate", flat=0.6, across=(1, 0, 0))
	block(k, h, "FaceP", 0, -0.9, 4.66, 4.46, 0.3, 0.1, "bone", ch=0.04)
	gem(k, h, "CrestC", (0, 0.1, 6.0), (0, 1.2, 6.7), 0.4, "shell", flat=0.6)
	art_jacket(k)
	block(k, T, "Thorax", 0, 0, 4.0, 2.8, 1.12, 0.64, "shell", ch=0.1, corner=0.18, sub=1)
	for s in (1, -1):
		prism(k, T, f"Chest{s}", [(s * 0.04, 3.84), (s * 1.0, 3.92), (s * 1.06, 3.4), (s * 0.5, 3.04), (s * 0.04, 3.2)], -0.76, -0.62, "plate", a=0.6)
	for i, z in enumerate((3.1, 2.9, 2.7, 2.5, 2.3)):
		block(k, T, f"Seg{i}", 0, -0.02, z, z - 0.18, 0.8 - 0.06 * i, 0.66 - 0.02 * i, "bone", ch=0.06, corner=0.2, a=0.5)
	block(k, T, "Waist", 0, 0, 2.4, 1.94, 1.06, 0.58, "shell", ch=0.06)
	for i, (y, z, r) in enumerate(((0.86, 2.3, 0.5), (1.3, 2.0, 0.62), (1.76, 1.6, 0.5))):
		block(k, T, f"Gaster{i}", 0, y, z + r * 0.8, z - r * 0.8, r, 0.34, "plate" if i % 2 else "shell", ch=0.14, corner=0.3)
	for s in (1, -1):
		for i, (tx, tz, r) in enumerate(((3.3, 5.6, 0.7), (3.1, 2.2, 0.6), (3.5, 4.0, 0.5))):
			gem(k, T, f"Wing{i}{s}", (s * 0.4, 0.66, 3.6 - 0.3 * i), (s * tx, 1.3, tz), r, "wing", flat=0.12, across=(0, 0, 1), a=0.6)
	arms(k, [("Arm", 3.94, 2.9, 0.46, "shell"), ("Pad", 4.26, 3.5, 0.64, "plate"), ("Fore", 3.06, 2.2, 0.56, "shell"), ("Hand", 2.3, 1.72, 0.53, "plate")])
	for s, side in ((1, "Left"), (-1, "Right")):
		arm, leg, x = f"{side}UpperArm", f"{side}UpperLeg", s * 1.5
		gem(k, arm, "PadSpike", (x + s * 0.3, 0, 4.0), (x + s * 1.0, 0.1, 4.7), 0.26, "plate")
		gem(k, arm, "Elbow", (x + s * 0.3, 0.3, 3.0), (x + s * 0.8, 0.8, 3.4), 0.2, "shell")
		for i in range(3):
			gem(k, arm, f"Blade{i}", (x + s * 0.5, -0.1 + 0.2 * i, 2.9 - 0.2 * i), (x + s * 1.0, 0.1 + 0.2 * i, 2.1 - 0.3 * i), 0.18, "claw", flat=0.5, across=(0, 1, 0))
			block(k, arm, f"Ring{i}", x, 0, 3.4 - 0.2 * i, 3.26 - 0.2 * i, 0.5, 0.5, "plate", ch=0.05, jit=0.02)
		block(k, leg, "Knee", s * 0.54, -0.54, 1.3, 0.86, 0.36, 0.16, "plate", ch=0.06, corner=0.3)
		gem(k, leg, "Calf", (s * 0.8, 0.3, 0.9), (s * 1.2, 0.7, 1.4), 0.2, "shell")
		for i in (-1, 1):
			gem(k, leg, f"Toe{i}", (s * 0.54 + i * 0.26, -0.6, 0.2), (s * 0.54 + i * 0.3, -1.2, 0.04), 0.16, "claw")
	legs(k, [("Thigh", 2.02, 0.9, 0.52, "shell"), ("Shin", 1.0, 0.3, 0.52, "shell")], shoe=(0.5, "plate", "sole"))
	finish()


def paint(a):
	R.paint(a)
	a["Head_F"].fill("#141b2c")
	base(a, SKIN, "#141b2c", "#141b2c", "#141b2c")
