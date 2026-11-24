# punch_psychic "Tatsumako": emerald hair curling up and out at the ends, big green eyes and a cross frown, a plain black high-collar long dress with long sleeves and split panels.
from w2_kit import *  # noqa: F403

SKIN = "#f9dcc6"
R = Ramps(skin=ramp(SKIN), hair=["#0c4a34", "#167250", "#26a070", "#62d6a0"], dress=["#16161f", "#262632", "#3a3a4a", "#5e5e74"], edge=["#5a5a70", "#7a7a92", "#a0a0b8", "#d0d0e0"], glow=["#1c9a5a", "#34cc7c", "#7cf0ac", "#d0ffe0"], shoe=ramp("#1c1c26"), sole=ramp("#0c0c12"))
DEFAULT = "#14141c"
HAIR = {"colour": "#26A070", "locks": []}
PROPS = []


def model(parts, kit):
	k = start(kit, parts, R, ear=False)
	crown(k, [(1.0, 5.1), (1.1, 5.5), (1.0, 5.82), (0.64, 6.04), (0.2, 6.1)])
	block(k, "Head", "Bob", 0, 0.26, 5.5, 4.5, 1.08, 0.72, "hair", ch=0.08, corner=0.3, flare=0.1, mids=(5.0,))
	# split fringe
	locks(k, "Fringe", [((0.1, -0.6, 5.9), (-0.36, -0.98, 5.08), 0.3), ((0.1, -0.6, 5.9), (0.24, -1.0, 5.14), 0.26), ((-0.3, -0.6, 5.82), (-0.86, -0.96, 5.0), 0.32), ((0.4, -0.6, 5.82), (0.86, -0.96, 5.0), 0.32)])
	# the signature: long side sweeps, each ending in an outward upturned curl
	for s in (1, -1):
		for i, (y, z0, x1, z1, r) in enumerate(((-0.56, 5.3, 1.24, 4.3, 0.32), (-0.1, 5.3, 1.44, 4.36, 0.38), (0.4, 5.2, 1.4, 4.2, 0.38), (0.8, 5.1, 0.9, 4.1, 0.38))):
			gem(k, "Head", f"Sweep{i}{s}", (s * 0.94, y * 0.8, z0), (s * x1, y, z1), r, "hair", flat=0.5, across=(0, 1, 0))
			gem(k, "Head", f"Curl{i}{s}", (s * (x1 - 0.2), y, z1 + 0.16), (s * (x1 + 0.6), y * 1.2, z1 + 0.5 - 0.1 * i), r * 0.86, "hair", flat=0.6, bend=-0.22, across=(0, 1, 0))
	for x in (-0.3, 0.3):
		gem(k, "Head", f"BackCurl{x}", (x, 0.86, 4.6), (x * 2, 1.6, 4.56), 0.36, "hair", flat=0.6, bend=-0.2, across=(1, 0, 0))
	locks(k, "Top", [((0, 0.1, 5.96), (0.3, 0.3, 6.4), 0.3), ((-0.4, 0, 5.9), (-0.8, 0, 6.12), 0.32), ((0.44, 0, 5.9), (0.9, 0, 6.14), 0.32)])
	art_jacket(k)
	block(k, T, "Dress", 0, 0, 3.98, 1.94, 1.06, 0.58, "dress", ch=0.06, corner=0.14, sub=1, mids=(2.9,))
	collar(k, "dress", 4.36, 4.44, z0=3.8, rx=0.78, ry=0.72, a=0.6)
	arms(k, [("Sleeve", 3.98, 2.5, 0.51, "dress"), ("Cuff", 2.62, 2.34, 0.56, "dress"), ("Hand", 2.4, 1.78, 0.49, "skin")])
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		# long skirt in front and back panels, open at the thigh sides
		block(k, leg, "SkirtF", s * 0.5, -0.62, 2.04, 0.4, 0.5, 0.07, "dress", ch=0.02, flare=0.08)
		block(k, leg, "HemF", s * 0.5, -0.64, 0.48, 0.4, 0.59, 0.1, "edge", ch=0.02)
		block(k, leg, "SkirtS", s * 1.06, 0.2, 2.04, 0.5, 0.06, 0.48, "dress", ch=0.02, flare=0.06)
		block(k, leg, "SkirtB", s * 0.5, 0.62, 2.04, 0.54, 0.5, 0.07, "dress", ch=0.02, flare=0.12)
	legs(k, [("Leg", 2.0, 0.4, 0.47, "skin"), ("Short", 2.02, 1.3, 0.5, "dress")], shoe=(0.4, "shoe", "sole"))
	block(k, T, "Seam", 0, -0.6, 3.9, 2.0, 0.03, 0.02, "edge", ch=0.01)
	for s in (1, -1):
		prism(k, T, f"Fold{s}", [(s * 0.2, 3.6), (s * 0.9, 3.7), (s * 0.7, 3.1), (s * 0.36, 2.2)], -0.63, -0.56, "dress", a=0.66)
		block(k, T, f"Hip{s}", s * 0.5, -0.02, 2.5, 1.98, 0.52, 0.64, "dress", ch=0.05, a=0.56)
	back_panel(k, "dress")
	back_hair(k, low=4.4)
	# the green psychic light orbits well clear of the arms
	for i, (x, y, z) in enumerate(((2.6, -0.3, 4.9), (-2.6, -0.3, 5.2), (2.5, 0.2, 2.6), (-2.5, 0.1, 2.9))):
		gem(k, T, f"Shard{i}", (x, y, z - 0.3), (x, y, z + 0.4), 0.2, "glow", flat=0.8, a=0.64)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, ("#0c6a40", "#22b070", "#90f8c0"), "#167250", up=16, dn=11, inner=4, outer=-5, lid=0.15, tilt=6, thick=3, mouth="frown", ir=(11, 14), by=43)
	base(a, SKIN, "#262632", "#262632", SKIN, SKIN, hair="#167250")
