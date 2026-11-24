# punch_psychic "Tatsumako": emerald hair curling up and out at the ends, big green eyes and a cross frown, a plain black high-collar long dress with long sleeves and split panels.
from w2_kit import *  # noqa: F403

SKIN = "#f9dcc6"
R = Ramps(skin=ramp(SKIN), hair=["#0c4a34", "#167250", "#26a070", "#62d6a0"], dress=["#08080e", "#14141c", "#22222c", "#3c3c4a"], glow=["#1c9a5a", "#34cc7c", "#7cf0ac", "#d0ffe0"], shoe=ramp("#1c1c26"), sole=ramp("#0c0c12"))
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
		block(k, leg, "SkirtF", s * 0.5, -0.62, 2.04, 0.62, 0.48, 0.07, "dress", ch=0.02, flare=0.1)
		block(k, leg, "SkirtB", s * 0.5, 0.62, 2.04, 0.54, 0.5, 0.07, "dress", ch=0.02, flare=0.12)
		gem(k, leg, "Point", (s * 1.0, -0.6, 0.94), (s * 1.3, -0.74, 0.3), 0.26, "dress", flat=0.3)
	legs(k, [("Leg", 2.0, 0.4, 0.47, "skin"), ("Short", 2.02, 1.3, 0.5, "dress")], shoe=(0.4, "shoe", "sole"))
	# the green psychic glow: floating shards
	for i, (x, y, z) in enumerate(((1.95, -0.5, 4.3), (-1.95, -0.5, 4.7), (2.1, 0.2, 3.5), (-2.1, 0.2, 3.2))):
		gem(k, T, f"Shard{i}", (x, y, z), (x + 0.04, y, z + 0.5), 0.13, "glow", flat=0.8, a=0.64)
	finish()


def paint(a):
	R.paint(a)
	face(a["Head_F"], SKIN, ("#0c6a40", "#22b070", "#90f8c0"), "#167250", up=16, dn=11, inner=4, outer=-5, lid=0.15, tilt=6, thick=3, mouth="frown", ir=(11, 14), by=43)
	base(a, SKIN, "#14141c", "#14141c", SKIN, SKIN)
