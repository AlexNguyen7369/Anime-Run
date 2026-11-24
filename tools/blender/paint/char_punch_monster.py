# punch_monster "Garoo": half-monster hunter: white hair in two tall swept-back horns of spikes stained red on one side, one red eye, dark carapace creeping over an arm and half the chest, torn black clothes.
from w2_kit import *  # noqa: F403

SKIN = "#e8bf9c"
R = Ramps(skin=ramp(SKIN), hair=["#8c8c9c", "#bcbcc8", "#e6e6ee", "#ffffff"], red=["#5a0c12", "#8e161c", "#c42a2c", "#ec5a50"], black=["#1a1a22", "#2a2a34", "#3e3e4a", "#62626e"], shell=["#2c1a3c", "#4a2f60", "#6e4a86", "#a07cb8"], spike=["#5a4866", "#86749a", "#b4a4c4", "#e0d6ea"], sole=ramp("#101016"))
DEFAULT = "#17171f"
HAIR = {"colour": "#E6E6EE", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R)
	crown(k, [(0.96, 5.3), (1.02, 5.56), (0.92, 5.8), (0.56, 5.98), (0.2, 6.02)])
	# two tall horns of hair, the viewer's right one stained
	for s, c in ((1, "red"), (-1, "hair")):
		for i, (b, t, r) in enumerate((((0.5, -0.2, 5.7), (1.06, 0.1, 7.2), 0.44), ((0.7, 0.0, 5.6), (1.5, 0.3, 6.8), 0.38), ((0.3, 0.2, 5.8), (0.6, 0.6, 7.0), 0.4), ((0.6, -0.5, 5.6), (0.86, -0.6, 6.5), 0.28), ((0.86, 0.1, 5.4), (1.56, 0.4, 6.0), 0.32), ((0.6, 0.6, 5.5), (1.0, 1.2, 5.8), 0.36), ((0.5, 0.7, 5.1), (0.7, 1.16, 4.7), 0.34))):
			gem(k, "Head", f"Horn{i}{s}", (s * b[0], b[1], b[2]), (s * t[0], t[1], t[2]), r, "hair", tip=c if c == "red" else None, split=0.3, flat=0.7)
		gem(k, "Head", f"Fore{s}", (s * 0.4, -0.7, 5.6), (s * 0.28, -0.98, 5.2), 0.2, c if c == "red" else "hair")
		gem(k, "Head", f"Temple{s}", (s * 0.92, -0.4, 5.4), (s * 1.02, -0.6, 4.8), 0.22, c if c == "red" else "hair", across=(0, 1, 0))
	back_hair(k)
	locks(k, "Swept", [((0.6, 0.7, 5.6), (0.9, 1.5, 5.9), 0.36), ((0, 0.8, 5.6), (0, 1.7, 5.9), 0.4), ((-0.6, 0.7, 5.6), (-0.9, 1.5, 5.9), 0.36)])
	for i, z in enumerate((4.86, 4.62, 4.38)):
		block(k, "Head", f"JawP{i}", 0.86, -0.42 + 0.06 * i, z, z - 0.28, 0.06, 0.3, "shell", ch=0.04, a=0.56)
	art_jacket(k)
	block(k, T, "Skin", 0, 0, 3.98, 2.1, 1.04, 0.56, "skin", ch=0.06, corner=0.14, sub=1)
	for s in (1, -1):
		prism(k, T, f"Pec{s}", [(s * 0.04, 3.84), (s * 0.98, 3.84), (s * 1.0, 3.36), (s * 0.5, 3.14), (s * 0.04, 3.2)], -0.64, -0.54, "shell" if s > 0 else "skin", a=0.58)
		for z in (3.02, 2.74):
			block(k, T, f"Ab{s}{z}", s * 0.3, -0.58, z, z - 0.24, 0.26, 0.06, "skin", ch=0.03, a=0.56)
		block(k, T, f"Vest{s}", s * 0.86, 0, 3.9, 2.3, 0.22, 0.64, "black", ch=0.04, jit=0.02)
	block(k, T, "Back", 0, 0.58, 3.96, 2.2, 1.06, 0.06, "black", ch=0.02)
	prism(k, T, "Creep", [(0.2, 3.3), (1.06, 3.4), (1.06, 2.4), (0.8, 2.7), (0.6, 2.36), (0.46, 2.86), (0.24, 2.8)], -0.66, -0.56, "shell", a=0.54)
	back_panel(k, "black")
	block(k, T, "ShellBack", 0.6, 0.66, 4.0, 2.5, 0.5, 0.1, "shell", ch=0.05, jit=0.03, mids=(3.5, 3.0), a=0.58)
	for i, z in enumerate((3.8, 3.3, 2.8)):
		gem(k, T, f"Spine{i}", (0.7, 0.7, z), (0.9, 1.2, z + 0.3), 0.16, "spike")
		block(k, T, f"Rib{i}", 0.64, -0.64, z - 0.5, z - 0.8, 0.42 - 0.06 * i, 0.07, "shell", ch=0.04, a=0.62)
	block(k, T, "Neck", 0.3, 0, 4.24, 3.9, 0.5, 0.6, "shell", ch=0.06)
	block(k, T, "Belt", 0, 0, 2.36, 2.12, 1.1, 0.62, "black", ch=0.03)
	arms(k, [("Arm", 3.96, 2.4, 0.49, "skin"), ("Sleeve", 4.02, 3.4, 0.54, "black"), ("Hand", 2.5, 1.76, 0.51, "skin")], sides=((-1, "Right"),))
	arms(k, [("Shell", 4.14, 3.3, 0.6, "shell"), ("Mid", 3.4, 2.7, 0.52, "shell"), ("Fore", 2.86, 2.2, 0.59, "shell"), ("Hand", 2.3, 1.72, 0.55, "shell")], sides=((1, "Left"),))
	la = "LeftUpperArm"
	for i, (b, t) in enumerate((((1.7, 0, 4.0), (2.3, 0.1, 4.7)), ((1.95, 0, 3.6), (2.6, 0.1, 3.86)), ((1.9, 0.1, 2.8), (2.5, 0.3, 3.1)))):
		gem(k, la, f"Spike{i}", b, t, 0.2, "spike")
	for i in range(3):
		gem(k, la, f"Claw{i}", (1.2 + 0.3 * i, -0.4, 1.9), (1.2 + 0.3 * i, -0.62, 1.4), 0.12, "spike")
	for i, z in enumerate((3.9, 3.5, 3.1, 2.7)):
		block(k, la, f"Plate{i}", 1.56, 0, z, z - 0.2, 0.66 - 0.02 * i, 0.64, "spike" if i == 0 else "shell", ch=0.06, a=0.64)
	legs(k, [("Thigh", 2.02, 0.6, 0.52, "black"), ("Tear", 0.8, 0.5, 0.5, "black")], shoe=(0.5, "black", "sole"))
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, ("#6a4a08", "#d8a418", "#fff08a"), "#b8b8c4", up=10, dn=7, inner=6, outer=-7, lid=0.2, tilt=7, thick=4, mouth="grin", ir=(7, 8), pu=(2, 3))
	eye(f, 93, 67, 1, ("#5a0808", "#e02018", "#ff8a6a"), w=32, up=10, dn=7, inner=6, outer=-7, lid=0.2, white="#2a0608", ir=(7, 8), pu=(2, 3))
	f.path("M93 80L90 100L95 124", stroke="#c42a2c", sw=2.2)
	f.path("M104 78L110 98", stroke="#c42a2c", sw=1.8)
	base(a, SKIN, "#2a2a34", SKIN, "#2a2a34", hair="#bcbcc8")
