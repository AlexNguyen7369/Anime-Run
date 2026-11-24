# punch_cyborg "Genus": short swept blond spikes, black eyes with gold irises, seams down the cheeks, black sleeveless top, big dark metal arms with lit cores.
from w2_kit import *  # noqa: F403

SKIN = "#f0cfae"
R = Ramps(skin=ramp(SKIN), hair=["#a8782a", "#dcae48", "#f6d878", "#fff0b0"], top=ramp("#24252b"), metal=["#121318", "#23252d", "#3c3f4b", "#6d7280"], plate=["#3a3d48", "#5c606e", "#878c9a", "#b9bec9"], core=["#c04a08", "#f08418", "#ffb638", "#fff0a0"], pant=ramp("#3a3f58"), sole=ramp("#15151a"))
DEFAULT = "#24252b"
HAIR = {"colour": "#F6D878", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R, ear=False)
	for s in (1, -1):
		block(k, "Head", f"Port{s}", s * 0.94, 0.02, 4.96, 4.56, 0.07, 0.2, "metal", ch=0.03)
		block(k, "Head", f"Stud{s}", s * 1.02, 0.02, 4.84, 4.68, 0.03, 0.08, "plate", ch=0.01)
	crown(k, [(0.98, 5.26), (1.04, 5.5), (0.96, 5.78), (0.6, 5.98), (0.2, 6.04)])
	# swept up and toward the viewer's right
	locks(k, "Top", [((-0.6, -0.3, 5.7), (-0.5, -0.66, 6.36), 0.36), ((-0.1, -0.4, 5.76), (0.34, -0.7, 6.52), 0.4), ((0.4, -0.3, 5.7), (1.12, -0.56, 6.3), 0.38), ((-0.5, 0.2, 5.8), (-0.56, 0.3, 6.5), 0.38), ((0.2, 0.2, 5.86), (0.5, 0.24, 6.62), 0.4), ((0.7, 0.2, 5.6), (1.36, 0.2, 6.0), 0.36), ((-0.8, 0, 5.6), (-1.34, 0, 5.86), 0.34), ((0, 0.7, 5.6), (0.1, 1.24, 5.9), 0.4)])
	locks(k, "Back", [((0.4, 0.72, 5.3), (0.6, 1.1, 4.6), 0.38), ((0, 0.78, 5.3), (0, 1.16, 4.5), 0.4), ((-0.4, 0.72, 5.3), (-0.6, 1.1, 4.6), 0.38)])
	locks(k, "Fringe", [((-0.7, -0.6, 5.64), (-0.96, -0.92, 5.06), 0.26), ((-0.3, -0.7, 5.7), (-0.5, -0.98, 5.1), 0.27), ((0.1, -0.7, 5.7), (0.06, -1.0, 5.16), 0.25), ((0.5, -0.68, 5.66), (0.62, -0.96, 5.12), 0.26), ((0.85, -0.5, 5.6), (1.02, -0.86, 5.0), 0.25)])
	locks(k, "Side", [((0.96, -0.1, 5.4), (1.12, -0.2, 4.84), 0.26), ((0.94, 0.4, 5.4), (1.14, 0.5, 4.7), 0.3)], mirror=True)
	art_jacket(k)
	collar(k, "top", 4.1, 4.24, z0=3.86, rx=0.72, ry=0.66)
	block(k, T, "Top", 0, 0, 3.98, 2.2, 1.07, 0.6, "top", ch=0.06, corner=0.16, sub=1)
	for s in (1, -1):
		prism(k, T, f"Pec{s}", [(s * 0.06, 3.8), (s * 0.98, 3.8), (s * 1.0, 3.3), (s * 0.5, 3.06), (s * 0.06, 3.14)], -0.64, -0.56, "top", a=0.62)
	block(k, T, "Belt", 0, 0, 2.42, 2.2, 1.1, 0.63, "metal", ch=0.03)
	arms(k, [("Shoulder", 4.14, 3.5, 0.62, "metal"), ("Upper", 3.6, 3.0, 0.48, "plate"), ("Elbow", 3.12, 2.86, 0.56, "metal"), ("Fore", 2.94, 2.2, 0.58, "metal"), ("Hand", 2.28, 1.76, 0.53, "metal")])
	for s, side in ((1, "Left"), (-1, "Right")):
		arm, x = f"{side}UpperArm", s * 1.5
		block(k, arm, "Cap", x + s * 0.06, 0, 4.2, 3.86, 0.5, 0.5, "plate", ch=0.1)
		block(k, arm, "CoreS", x, -0.63, 3.9, 3.66, 0.16, 0.04, "core", ch=0.02, a=0.7)
		block(k, arm, "CoreF", x, -0.59, 2.78, 2.42, 0.12, 0.04, "core", ch=0.02, a=0.7)
		for dx in (-0.34, 0.34):
			block(k, arm, f"Rail{dx}", x + dx, -0.56, 2.9, 2.26, 0.09, 0.08, "plate", ch=0.02)
		block(k, arm, "Band", x, 0, 2.34, 2.2, 0.61, 0.61, "plate", ch=0.03)
		block(k, arm, "Palm", x, -0.54, 2.06, 1.9, 0.12, 0.03, "core", ch=0.02, a=0.7)
	legs(k, [("Thigh", 2.02, 0.5, 0.5, "pant"), ("Hem", 0.6, 0.4, 0.5, "pant")], shoe=(0.44, "sole", "metal"))
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, ("#a86a08", "#f0b428", "#fff0a0"), "#c89838", white="#101014", lash="#0a0a0e", up=12, dn=9, lid=0.0, mouth="flat", ir=(8, 9.5), tilt=3.5)
	for s in (1, -1):
		x = 65 + s * 50
		f.path(f"M{x - s * 14} 80L{x - s * 8} 96L{x - s * 12} 124", stroke="#5a5048", sw=1.5)
	base(a, SKIN, "#24252b", "#24252b", "#3a3f58")
