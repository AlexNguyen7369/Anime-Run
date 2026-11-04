# Target look for jk_strongest (design doc section 5): a tall white flame of spikes pushed up by a wide black blindfold, short
# white tufts under it, pale face with a thin smirk, tall zipped collar, long dark jacket, dark shoes. Drawn in-house.
from atlas import shade
from jk_style3 import NAVY, SOLE, Kit, big_head, block, collar, crown, dress_shoe, face_base, finish, gem, head_rest, jacket, sleeve, spray, stroke, trouser
from style2 import Ramps

SKIN = "#f6e2d6"
SKIN_D = "#d3b4a2"
DEFAULT = "#161925"
R = Ramps(
	hair=["#8197bd", "#b6c9e2", "#dfe7f3", "#f6f8fc", "#ffffff"],
	skin=["#bb9a88", "#e6c8b6", "#f6e2d6", "#fff0e8"],
	navy=[shade(c, 0.86) for c in NAVY],
	band=["#050507", "#0e0e12", "#1d1d24", "#31313c"],
	steel=["#59606c", "#8f96a2", "#c2c8d0", "#eef1f4"],
	shoe=["#08080c", "#14151c", "#23242e", "#363846"],
	sole=SOLE,
)
HAIR = {"colour": "#F4F6FA", "locks": []}
PROPS = []


def _hair(k):
	block(k, "Head", "Cap", 0, 0, 5.72, 5.04, 0.95, 0.87, "hair", ch=0.08, corner=0.2, jit=0.015, a=0.46, b=0.44)
	crown(k, [(0.92, 5.5), (0.98, 5.7), (0.92, 5.86), (0.56, 6.1), (0.16, 6.2)])
	root = (0, 0.04, 5.2)
	# the flame: broad spikes pushed straight up and out, tallest at the middle
	spray(k, "Top", root, (((-0.34, -0.1, 6.9), 0.44), ((0.3, -0.02, 7.0), 0.46), ((-0.02, 0.44, 6.92), 0.46), ((0.68, 0.32, 6.78), 0.42), ((-0.72, 0.3, 6.76), 0.42)), f=0.32, bend=0.03)
	spray(k, "Fan", root, (((-1.14, -0.08, 6.42), 0.4), ((-0.78, -0.34, 6.62), 0.42), ((-0.24, -0.46, 6.72), 0.42), ((0.3, -0.46, 6.74), 0.42), ((0.82, -0.34, 6.6), 0.42), ((1.18, -0.08, 6.4), 0.4), ((-1.08, 0.5, 6.36), 0.4), ((1.1, 0.5, 6.34), 0.4), ((-0.44, 0.9, 6.56), 0.42), ((0.46, 0.9, 6.54), 0.42)), f=0.28, bend=0.03)
	spray(k, "Low", root, (((-1.34, -0.1, 6.0), 0.34), ((1.36, -0.1, 6.0), 0.34), ((-1.26, 0.44, 5.92), 0.36), ((1.28, 0.44, 5.9), 0.36), ((-0.56, 1.12, 6.04), 0.38), ((0.58, 1.12, 6.02), 0.38), ((0.0, 1.24, 6.2), 0.4)), f=0.3)
	# the front row stands up from the top edge of the band
	for i, (x, z, r) in enumerate(((-0.74, 6.02, 0.3), (-0.34, 6.28, 0.33), (0.08, 6.38, 0.34), (0.5, 6.26, 0.33), (0.82, 6.0, 0.3))):
		gem(k, "Head", f"Front{i}", (x * 0.95, -0.8, 5.1), (x * 1.06, -1.02, z), r, flat=0.45, twist=0.2 + 0.3 * i % 0.6)
	for i, (x, z, r) in enumerate(((-0.7, 5.96, 0.3), (-0.26, 6.14, 0.33), (0.26, 6.12, 0.33), (0.72, 5.94, 0.3))):
		gem(k, "Head", f"Rear{i}", (x * 0.95, 0.8, 5.1), (x * 1.06, 1.02, z), r, flat=0.45, twist=0.3 + 0.2 * i)
	# under the band: short tufts at the ears and the nape
	block(k, "Head", "Nape", 0, 0.38, 4.7, 4.26, 0.93, 0.47, "hair", ch=0.05, corner=0.22, jit=0.015, a=0.44, b=0.34)
	for s in (1, -1):
		for i, y in enumerate((-0.28, 0.08)):
			gem(k, "Head", f"Tuft{s}{i}", (s * 0.88, y, 4.72), (s * 0.95, y, 4.34), 0.17, flat=0.45, across=(0, 1, 0), a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	# the blindfold: a wide wrap, proud of the head on every side
	block(k, "Head", "Blindfold", 0, 0, 5.08, 4.64, 0.945, 0.865, "band", ch=0.03, corner=0.2, sub=1, jit=0.006, a=0.5, b=0.4)
	block(k, "Head", "FoldA", -0.2, -0.855, 4.92, 4.88, 0.5, 0.014, "band", ch=0.008, a=0.86, b=0.2)
	block(k, "Head", "FoldB", 0.32, -0.855, 4.76, 4.72, 0.42, 0.014, "band", ch=0.008, a=0.8, b=0.2)
	jacket(k, hem=1.78, seam=None)
	t = "UpperTorso"
	# a tall collar right up under the mouth, and a zip from its top to the hem
	collar(k, "navy", 4.24, 4.46, z0=3.84, rx=0.93, ry=0.9, a=0.54)
	block(k, t, "ZipStrip", 0, -0.585, 3.98, 1.8, 0.05, 0.022, "sole", ch=0.008, a=0.4)
	block(k, t, "ZipCollar", 0, -0.95, 4.23, 3.94, 0.05, 0.022, "sole", ch=0.008, a=0.4)
	block(k, t, "ZipRail", 0, -0.61, 3.96, 1.84, 0.016, 0.008, "steel", ch=0.003, a=0.6)
	block(k, t, "ZipPull", 0, -0.975, 4.2, 4.1, 0.03, 0.012, "steel", ch=0.006, a=0.8)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s)
		leg, px = trouser(k, side, s, low=0.46)
		dress_shoe(k, leg, px)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	face_base(f, SKIN, SKIN_D, blush="#f0b0a0", top=0)
	# the band shades the face just under it; a long straight nose and a thin amused smirk
	f.soft("M-5 66H135V78H-5Z", "#7a5a50", 0.55, 2)
	f.path("M63 66L69 83L61 85Q64 76 63 66Z", shade(SKIN, 0.74), opacity=0.9)
	stroke(f, "M60 85Q65 87 70 84", shade(SKIN, 0.48), 1.1)
	stroke(f, "M50 95Q66 98 82 92", "#5a3a36", 1.7)
	stroke(f, "M82 92Q84.5 91 86 88", "#5a3a36", 1.5)
	f.soft("M58 100Q66 103 74 100Q66 105 58 100Z", SKIN_D, 0.5, 1)
	head_rest(a, shade(SKIN, 0.78), shade(SKIN, 0.6))
	a["Head_T"].fill("#f4f6fa")
