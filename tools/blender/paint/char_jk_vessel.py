# Target look for jk_vessel (design doc section 5): big head, salmon spikes over a dark undercut, dark high-collar uniform with
# a red hood at the neck and back, gold spiral buttons, baggy trousers, red high-tops. Bare block hands. Drawn in-house.
from atlas import INK, shade
from jk_common import brow2, eye2
from jk_style3 import GOLD, NAVY, Kit, big_head, block, button, collar, crown, ears, face_base, finish, gem, head_rest, jacket, prism, sleeve, slab, sneaker, spray, stroke, swirl_art, trouser
from style2 import Ramps

SKIN = "#f4d0ae"
SKIN_D = "#d4a07c"
DEFAULT = "#1e2233"
R = Ramps(
	hair=["#a24c60", "#d67488", "#f3a0aa", "#ffbcc2", "#ffd8da"],
	under=["#1e1212", "#302020", "#443030", "#5a4242"],
	skin=["#b98762", "#e0b08c", "#f4d0ae", "#ffe2c8"],
	navy=NAVY,
	red=["#6a0e12", "#a01c20", "#c82c2c", "#e84e48"],
	white=["#8e8e98", "#d4d4da", "#f2f2f4", "#ffffff"],
	gold=GOLD,
	sole=["#08080c", "#14151c", "#262832", "#3a3c48"],
)
HAIR = {"colour": "#F3A3A8", "locks": []}
PROPS = []


def _hair(k):
	# the dark undercut: sides and back only, set back from the face plane
	slab(k, "Undercut", [(-0.4, 5.42), (-0.3, 5.0), (-0.16, 4.76), (0.2, 4.52), (0.62, 4.34), (0.84, 4.54), (0.84, 5.42)], -0.925, 0.925, "under", a=0.52, b=0.36)
	block(k, "Head", "Cap", 0, 0.02, 5.74, 5.24, 0.965, 0.88, "hair", ch=0.08, corner=0.3, jit=0.015, sub=1, a=0.48, b=0.42)
	for i, x in enumerate((-0.66, -0.33, 0.0, 0.33, 0.66)):
		gem(k, "Head", f"UnderTip{i}", (x, 0.72, 4.72), (x, 0.88, 4.22 + 0.05 * (i % 2)), 0.25, "under", flat=0.45, across=(1, 0, 0), a=0.5, b_=0.4)
	crown(k, [(0.94, 5.26), (1.0, 5.5), (0.92, 5.82), (0.5, 6.1), (0.12, 6.16)])
	root = (0, 0.04, 5.46)
	spray(k, "Back", root, (((-1.14, 0.2, 5.84), 0.34), ((-0.94, 0.26, 6.3), 0.38), ((-0.46, 0.34, 6.6), 0.4), ((0.1, 0.36, 6.74), 0.42), ((0.62, 0.32, 6.56), 0.4), ((1.0, 0.26, 6.24), 0.38), ((1.18, 0.2, 5.78), 0.34), ((0.0, 1.04, 6.1), 0.42), ((-0.66, 0.98, 5.88), 0.38), ((0.66, 0.98, 5.88), 0.38), ((-0.36, 1.06, 5.56), 0.34), ((0.36, 1.06, 5.56), 0.34)))
	spray(k, "Mid", root, (((-1.02, -0.4, 5.96), 0.34), ((-0.52, -0.46, 6.36), 0.38), ((0.02, -0.5, 6.48), 0.38), ((0.56, -0.46, 6.34), 0.38), ((1.04, -0.4, 5.92), 0.34)))
	# the front: rising spikes, and two short clumps falling over the forehead either side of the centre
	for i, (tip, r) in enumerate((((-0.86, -0.82, 5.82), 0.3), ((-0.42, -0.9, 6.02), 0.32), ((0.1, -0.92, 6.06), 0.34), ((0.58, -0.88, 5.98), 0.32), ((0.9, -0.8, 5.76), 0.3))):
		gem(k, "Head", f"Front{i}", (tip[0] * 0.8, -0.56, 5.38), tip, r, flat=0.55, twist=0.2 + 0.3 * i % 0.6)
	for i, (b, t, r) in enumerate((((-0.34, -0.62, 5.62), (-0.1, -0.93, 5.02), 0.25), ((0.3, -0.62, 5.62), (0.13, -0.93, 5.06), 0.25), ((-0.68, -0.6, 5.54), (-0.56, -0.92, 5.12), 0.22), ((0.68, -0.6, 5.54), (0.6, -0.92, 5.14), 0.22))):
		gem(k, "Head", f"Bang{i}", b, t, r, flat=0.5, twist=0.25, across=(1, 0, 0), a=0.56)


def _hood(k):
	t = "UpperTorso"
	# the red hood lies on the back and rolls round the neck, showing at the throat
	collar(k, "red", 4.1, 4.28, z0=3.84, rx=0.92, ry=0.88, name="HoodRoll", a=0.5, b=0.56)
	block(k, t, "HoodBack", 0, 0.66, 4.14, 3.32, 0.68, 0.14, "red", ch=0.06, flare=-0.08, corner=0.3, jit=0.025, sub=1, mids=(3.7,), a=0.46, b=0.5, g=0.14)
	prism(k, t, "HoodLip", [(-0.62, 4.1), (0.62, 4.1), (0.4, 3.86), (-0.4, 3.86)], 0.78, 0.84, "red", a=0.62)
	# the dark jacket collar folds down each side of a red V at the throat
	prism(k, t, "Throat", [(-0.3, 3.98), (0.3, 3.98), (0, 3.58)], -0.61, -0.585, "red", a=0.66)
	for s, n in ((1, "L"), (-1, "R")):
		prism(k, t, f"Lapel{n}", [(s * 0.94, 3.99), (s * 0.3, 3.99), (s * 0.015, 3.56), (s * 0.34, 3.5)], -0.635, -0.585, "navy", a=0.62, b=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k)
	_hair(k)
	jacket(k)
	_hood(k)
	for i, z in enumerate((3.26, 2.78, 2.3)):
		button(k, "UpperTorso", f"Button{i}", 0, -0.6, z, r=0.13)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s)
		leg, px = trouser(k, side, s, low=0.46)
		sneaker(k, leg, px)
	finish()


def paint(a):
	R.paint(a)
	swirl_art(a, "#f3a0aa")
	f = a["Head_F"]
	face_base(f, SKIN, SKIN_D)
	# wide-open warm eyes, thick level brows
	eye2(f, 39, 58, -1, 35, 18, "#b5702e", tilt=1.2, r=12, lash_t=3.8, flick=2.5, sclera="#fffdf8", crease_line=False)
	eye2(f, 91, 58, 1, 35, 18, "#b5702e", tilt=1.2, r=12, lash_t=3.8, flick=2.5, sclera="#fffdf8", crease_line=False)
	brow2(f, 38, 32, -1, 33, 6, 2.6, "#7a3d48", arc=-1.5)
	brow2(f, 92, 32, 1, 33, 6, 2.6, "#7a3d48", arc=-1.5)
	# the two short lines under the eyes
	for s, x in ((-1, 40), (1, 90)):
		stroke(f, f"M{x - 10} 80Q{x + s * 2} 85 {x + 12} 80", shade(SKIN, 0.42), 1.6)
	f.soft("M59 79L65 73L71 79Q65 85 59 79Z", SKIN_D, 0.7, 1)
	stroke(f, "M60 83Q65 85 70 83", shade(SKIN, 0.5), 1.1)
	# a big open friendly grin
	shape = "M44 94Q65 99 86 94Q84 110 65 112Q46 110 44 94Z"
	f.path(shape, "#4a1416", stroke="#3a1014", sw=1.2)
	f.path("M46 95Q65 100 84 95L82 101Q65 105 48 101Z", "#fbfaf4")
	f.soft("M54 107Q65 103 76 107Q65 112 54 107Z", "#d0585a", 0.9, 1)
	stroke(f, "M42 93L44.5 94.5", INK, 1.2)
	stroke(f, "M88 93L85.5 94.5", INK, 1.2)
	head_rest(a, SKIN_D, "#b98762")
