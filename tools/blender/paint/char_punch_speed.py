# punch_speed "Speedo Sonik": black hair in a high topknot with face-framing strands, purple marks under slit eyes, a violet-grey scarf, dark plated suit, a sword on the back.
from w2_kit import *  # noqa: F403

SKIN = "#f3d8c2"
R = Ramps(skin=ramp(SKIN), hair=["#0c0a16", "#1a1728", "#2c283e", "#4c465e"], scarf=["#463a5e", "#665682", "#8a7aa6", "#b4a6cc"], suit=["#1a1b28", "#2c2e40", "#43465c", "#686c86"], saya=["#7a1c2c", "#a42c3c", "#cc4a54", "#f08080"], plate=["#4a4c5a", "#70737f", "#9a9da8", "#c8cad2"], purple=ramp("#6a3f9a"), steel=["#8890a0", "#b8c0ce", "#e4e8f0", "#ffffff"], sole=ramp("#101016"))
DEFAULT = "#1c1c28"
HAIR = {"colour": "#2C283E", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R)
	crown(k, [(0.98, 5.2), (1.04, 5.5), (0.94, 5.78), (0.6, 5.96), (0.2, 6.02)])
	block(k, "Head", "Tie", 0, 0.36, 6.2, 5.92, 0.22, 0.22, "purple", ch=0.04, corner=0.3)
	# topknot: a fan of spikes off the tie
	locks(k, "Knot", [((0, 0.36, 6.1), (0, 0.5, 7.1), 0.34), ((0, 0.4, 6.1), (0.66, 0.6, 6.94), 0.3), ((0, 0.4, 6.1), (-0.66, 0.6, 6.94), 0.3), ((0, 0.5, 6.1), (0.36, 1.3, 6.7), 0.32), ((0, 0.5, 6.1), (-0.36, 1.3, 6.7), 0.32), ((0, 0.5, 6.06), (0, 1.5, 6.2), 0.32)])
	locks(k, "Fringe", [((0.02, -0.5, 5.86), (-0.5, -0.98, 5.02), 0.26), ((0.06, -0.5, 5.86), (0.5, -0.98, 5.02), 0.26), ((0, -0.5, 5.86), (0.06, -1.0, 4.94), 0.22), ((-0.4, -0.5, 5.8), (-0.9, -0.94, 4.9), 0.28), ((0.4, -0.5, 5.8), (0.9, -0.94, 4.9), 0.28)])
	locks(k, "Frame", [((0.84, -0.5, 5.5), (0.94, -0.8, 4.0), 0.22), ((0.9, -0.1, 5.6), (1.0, -0.14, 4.3), 0.28), ((0.8, 0.5, 5.5), (1.0, 0.84, 4.5), 0.36)], mirror=True)
	locks(k, "Rear", [((0, 0.7, 5.5), (0, 1.02, 4.5), 0.44)])
	back_hair(k)
	art_jacket(k)
	block(k, T, "Suit", 0, 0, 3.98, 2.1, 1.06, 0.58, "suit", ch=0.06, corner=0.14, sub=1)
	for s in (1, -1):
		prism(k, T, f"Chest{s}", [(s * 0.08, 3.5), (s * 0.94, 3.6), (s * 0.96, 3.06), (s * 0.4, 2.84), (s * 0.08, 2.9)], -0.66, -0.56, "suit", a=0.66)
		block(k, T, f"Strap{s}", s * 0.5, -0.63, 3.5, 2.4, 0.07, 0.03, "plate", ch=0.015)
	block(k, T, "Belt", 0, 0, 2.5, 2.26, 1.1, 0.62, "plate", ch=0.03)
	collar(k, "scarf", 4.3, 4.36, z0=3.74, rx=1.0, ry=0.82, name="Scarf", a=0.54)
	block(k, T, "ScarfRoll", 0, -0.1, 4.04, 3.7, 0.98, 0.74, "scarf", ch=0.12, corner=0.26, jit=0.02)
	for i, s in enumerate((1, -1)):  # two tails blown back
		gem(k, T, f"Tail{s}", (s * 0.3, 0.7, 3.96), (s * 1.0, 2.1, 3.1 - 0.4 * i), 0.36, "scarf", flat=0.3, bend=0.12, across=(0, 0, 1))
	rod(k, T, "Sheath", (-0.9, 0.78, 4.5), (0.8, 0.82, 2.0), 0.16, "saya")
	rod(k, T, "Hilt", (-1.24, 0.77, 5.0), (-0.92, 0.78, 4.54), 0.13, "purple")
	block(k, T, "Guard", -0.91, 0.78, 4.6, 4.48, 0.26, 0.22, "steel", ch=0.03)
	back_panel(k, "suit", "plate")
	arms(k, [("Sleeve", 3.94, 2.6, 0.5, "suit"), ("Pauldron", 4.12, 3.62, 0.58, "plate"), ("Guard", 2.96, 2.4, 0.56, "plate"), ("Hand", 2.5, 1.78, 0.51, "suit")])
	legs(k, [("Thigh", 2.02, 0.9, 0.5, "suit"), ("ThighBand", 1.6, 1.4, 0.5, "plate")], shoe=(0.96, "suit", "sole"))
	for s, side in ((1, "Left"), (-1, "Right")):
		block(k, f"{side}UpperLeg", "Shin", s * 0.535, -0.54, 1.1, 0.5, 0.32, 0.12, "plate", ch=0.05, corner=0.3)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face(f, SKIN, ("#4c4660", "#7a7492", "#b8b4cc"), "#1a1728", up=9, dn=6, inner=5, outer=-7, lid=0.35, tilt=5, thick=3, mouth="smirk", ir=(8, 9), pu=(1.6, 4.5))
	for s in (1, -1):
		x = 65 + s * 28
		f.path(f"M{x - 9} 79L{x + 9} 79L{x + s * 4} 98Z", "#6a3f9a")
	base(a, SKIN, "#2c2e40", "#2c2e40", "#2c2e40", hair="#1a1728")
