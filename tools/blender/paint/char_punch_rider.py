# punch_rider "Mumon Rider": rounded cycling helmet, big round-cornered goggles, open honest face, tan padded vest and guards over a dark suit.
from w2_kit import *  # noqa: F403

SKIN = "#f2c9a4"
R = Ramps(skin=ramp(SKIN), hair=ramp("#4a3020"), helm=ramp("#3f6b4c"), vent=ramp("#1d2a22"), lens=["#b8d8e0", "#d4ecf2", "#eaf8fc", "#ffffff"], rim=ramp("#20242a"), suit=ramp("#2c2c32"), pad=ramp("#a98552"), strap=ramp("#5a432a"), sole=ramp("#1a1a1e"))
DEFAULT = "#2c2c32"
HAIR = {"colour": "#4A3020", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R)
	h = "Head"
	crown(k, [(1.08, 5.2), (1.14, 5.5), (1.04, 5.86), (0.7, 6.12), (0.2, 6.2)], "helm")
	block(k, h, "Brim", 0, -0.02, 5.34, 5.16, 1.1, 1.04, "helm", ch=0.04, corner=0.3, a=0.42)
	for x in (-0.46, 0, 0.46):
		block(k, h, f"Vent{x}", x, -0.5, 6.12 - abs(x) * 0.3, 5.56, 0.1, 0.5, "vent", ch=0.04, a=0.5)
	for s in (1, -1):
		block(k, h, f"Strap{s}", s * 0.94, -0.16, 5.2, 4.16, 0.05, 0.08, "strap", ch=0.02)
		block(k, h, f"GogRim{s}", s * 0.45, -0.86, 5.02, 4.5, 0.39, 0.07, "rim", ch=0.04, corner=0.3)
		block(k, h, f"GogStrap{s}", s * 0.94, -0.2, 4.88, 4.66, 0.06, 0.62, "rim", ch=0.02)
		gem(k, h, f"Side{s}", (s * 0.9, -0.3, 5.2), (s * 1.0, -0.5, 4.4), 0.2, "hair", flat=0.5, across=(0, 1, 0))
	block(k, h, "Nape", 0, 0.66, 5.2, 4.4, 0.8, 0.26, "hair", ch=0.06, corner=0.2)
	# the lens shows the painted eyes, so only a rim bridge and a pale glint are solid
	block(k, h, "Bridge", 0, -0.9, 4.84, 4.7, 0.1, 0.05, "rim", ch=0.02)
	for s in (1, -1):
		block(k, h, f"Lens{s}", s * 0.45, -0.95, 4.95, 4.57, 0.32, 0.02, "lens", ch=0.01, corner=0.3, a=0.6, b=0.1)
		block(k, h, f"Pupil{s}", s * 0.4, -0.98, 4.86, 4.64, 0.07, 0.015, "rim", ch=0.005, a=0.3, b=0.0)
		prism(k, h, f"Brow{s}", [(s * 0.22, 5.1), (s * 0.7, 5.12), (s * 0.7, 5.04), (s * 0.22, 5.03)], -0.95, -0.85, "hair")
	art_jacket(k)
	block(k, T, "Vest", 0, 0, 3.96, 2.6, 1.1, 0.64, "pad", ch=0.06, corner=0.16, sub=1)
	block(k, T, "VestLow", 0, -0.02, 2.96, 2.5, 1.0, 0.66, "strap", ch=0.04, corner=0.16)
	for s in (1, -1):
		block(k, T, f"Plate{s}", s * 0.5, -0.63, 3.78, 3.04, 0.42, 0.07, "pad", ch=0.04, corner=0.2, a=0.6)
	collar(k, "suit", 4.12, 4.3, z0=3.86, rx=0.7, ry=0.66)
	block(k, T, "Belt", 0, 0, 2.4, 2.16, 1.11, 0.64, "strap", ch=0.03)
	arms(k, [("Sleeve", 3.94, 2.4, 0.5, "suit"), ("Pad", 4.06, 3.5, 0.58, "pad"), ("Elbow", 3.1, 2.8, 0.55, "pad"), ("Glove", 2.5, 1.78, 0.53, "strap")])
	legs(k, [("Thigh", 2.0, 0.8, 0.5, "suit")], shoe=(0.8, "strap", "sole"))
	for s, side in ((1, "Left"), (-1, "Right")):
		block(k, f"{side}UpperLeg", "Knee", s * 0.535, -0.54, 1.36, 0.9, 0.34, 0.1, "pad", ch=0.05, corner=0.3)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, ("#2e1c12", "#5a3c26", "#8a6444"), None, mouth="flat")
	base(a, SKIN, "#2c2c32", "#2c2c32", "#2c2c32")
