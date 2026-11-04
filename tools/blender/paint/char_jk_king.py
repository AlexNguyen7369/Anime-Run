# Target look for jk_king (design doc section 5): the same uniform as jk_vessel worn open over a dark red hoodie, darker pink
# hair raked back off a bare forehead over a dark undercut, red slit eyes with a smaller pair under them, black face lines,
# sleeves pushed up to show two black wrist bands. No bare chest (references doc: jacket open). Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2
from jk_style3 import GOLD, NAVY, Kit, big_head, block, collar, crown, ears, face_base, finish, gem, head_rest, prism, sleeve, slab, sneaker, stroke, swirl_art, torso_core, trouser
from style2 import Ramps

SKIN = "#f1d2b8"
SKIN_D = "#cf9f7e"
TAT = "#16121a"
DEFAULT = "#1e2233"
R = Ramps(
	hair=["#8e3c50", "#bc5a70", "#e58b92", "#f6a8ac", "#ffc4c4"],
	under=["#1c1212", "#2e1e1e", "#443030", "#5a4242"],
	skin=["#b08462", "#dcae8e", "#f1d2b8", "#ffe4ce"],
	navy=NAVY,
	hood=["#3e0a0e", "#6a1216", "#8e1e1e", "#b03232"],
	red=["#6a0e12", "#a01c20", "#c82c2c", "#e84e48"],
	white=["#8e8e98", "#d4d4da", "#f2f2f4", "#ffffff"],
	gold=GOLD,
)
HAIR = {"colour": "#E58B92", "locks": []}
PROPS = []


def _hair(k):
	slab(k, "Undercut", [(-0.34, 5.42), (-0.2, 5.02), (-0.08, 4.76), (0.24, 4.5), (0.62, 4.32), (0.84, 4.52), (0.84, 5.42)], -0.925, 0.925, "under", a=0.52, b=0.36)
	block(k, "Head", "Cap", 0, 0.06, 5.7, 5.3, 0.96, 0.86, "hair", ch=0.08, corner=0.3, jit=0.015, sub=1, a=0.48, b=0.42)
	for i, x in enumerate((-0.6, -0.2, 0.2, 0.6)):
		gem(k, "Head", f"UnderTip{i}", (x, 0.72, 4.6), (x, 0.88, 4.14 + 0.05 * (i % 2)), 0.27, "under", flat=0.45, across=(1, 0, 0), a=0.5, b_=0.4)
	crown(k, [(0.92, 5.3), (0.99, 5.46), (0.92, 5.74), (0.52, 6.0), (0.14, 6.06)], at=(0, 0.08, 0))
	# no fringe: broad wedges rise off the hairline and rake straight back, longest at the crown
	for i, (bx, tip, r) in enumerate(((-0.72, (-0.98, 0.34, 6.12), 0.36), (-0.38, (-0.52, 0.42, 6.42), 0.4), (0.0, (0.02, 0.5, 6.56), 0.42), (0.38, (0.54, 0.42, 6.44), 0.4), (0.72, (1.0, 0.34, 6.1), 0.36))):
		gem(k, "Head", f"Rake{i}", (bx, -0.68, 5.4), tip, r, flat=0.5, bend=0.1, twist=0.2 + 0.3 * i % 0.6, a=0.52)
	# the second layer, higher on the crown, runs out past the back of the head
	for i, (bx, tip, r) in enumerate(((-0.56, (-0.86, 1.12, 5.98), 0.34), (-0.2, (-0.28, 1.28, 6.2), 0.38), (0.2, (0.3, 1.28, 6.18), 0.38), (0.56, (0.88, 1.1, 5.96), 0.34))):
		gem(k, "Head", f"Crown{i}", (bx, -0.02, 5.82), tip, r, flat=0.55, bend=0.06, twist=0.4 + 0.2 * i)
	for s in (1, -1):
		# temple blades flat to the head, raked to the rear
		for i, (y, tip, r) in enumerate(((-0.42, (s * 1.08, 0.5, 5.64), 0.22), (-0.06, (s * 1.08, 0.92, 5.48), 0.22))):
			gem(k, "Head", f"Blade{s}{i}", (s * 0.84, y, 5.44), tip, r, flat=0.5, twist=0.3, across=(0, 0, 1))
	for i, x in enumerate((-0.42, 0.0, 0.42)):
		gem(k, "Head", f"Low{i}", (x, 0.62, 5.42), (x * 1.1, 1.12, 5.16), 0.28, flat=0.55, twist=0.3)


def _open_jacket(k):
	t = "UpperTorso"
	torso_core(k)
	hem = 1.92
	# the hoodie under: its pouch and hem show between the panels
	block(k, t, "Back", 0, 0, 3.98, hem + 0.1, 1.09, 0.56, "navy", ch=0.06, jit=0.03, sub=1, mids=(3.4, 2.9, 2.4), a=0.48, b=0.58, tone=0.04)
	prism(k, t, "Hoodie", [(-0.62, 3.98), (0.62, 3.98), (0.62, 1.98), (-0.62, 1.98)], -0.59, -0.55, "hood", a=0.46, b=0.6)
	prism(k, t, "Pouch", [(-0.3, 2.72), (0.3, 2.72), (0.42, 2.26), (-0.42, 2.26)], -0.615, -0.58, "hood", a=0.56, b=0.56)
	for s, n in ((1, "L"), (-1, "R")):
		# the front panels hang open, the gap widening to the hem; a folded lapel at the top of each
		prism(k, t, f"Panel{n}", [(s * 1.09, 3.98), (s * 0.3, 3.98), (s * 0.44, 3.0), (s * 0.5, hem), (s * 1.11, hem)], -0.64, -0.55, "navy", a=0.44, b=0.6, g=0.12, tone=0.03)
		prism(k, t, f"Lapel{n}", [(s * 0.95, 3.99), (s * 0.3, 3.99), (s * 0.39, 3.36), (s * 0.66, 3.5)], -0.665, -0.63, "navy", a=0.62, b=0.5)
	block(k, t, "Hem", 0, 0.1, hem + 0.16, hem, 1.12, 0.47, "navy", ch=0.03, a=0.42, b=0.56)
	collar(k, "hood", 4.08, 4.28, z0=3.84, rx=0.92, ry=0.88, name="HoodRoll", a=0.5, b=0.56)
	block(k, t, "HoodBack", 0, 0.66, 4.14, 3.3, 0.68, 0.14, "hood", ch=0.06, flare=-0.08, corner=0.3, jit=0.025, sub=1, mids=(3.7,), a=0.46, b=0.5, g=0.14)
	prism(k, t, "HoodLip", [(-0.62, 4.1), (0.62, 4.1), (0.4, 3.84), (-0.4, 3.84)], 0.78, 0.84, "hood", a=0.62)


def _wrist(k, side, s):
	arm = f"{side}UpperArm"
	for i, z in enumerate((2.52, 2.32)):
		block(k, arm, f"Band{i}", s * 1.5, 0, z + 0.05, z - 0.05, 0.51, 0.51, "ink", ch=0.008, corner=0.14, a=0.5, b=0.1)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k)
	_hair(k)
	_open_jacket(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, cuff=2.74)
		_wrist(k, side, s)
		leg, px = trouser(k, side, s, low=0.46)
		sneaker(k, leg, px)
	finish()


def _bar(f, pts):
	f.path("M" + "L".join(f"{x} {y}" for x, y in pts) + "Z", TAT)


def paint(a):
	R.paint(a)
	swirl_art(a, "#e58b92")
	f = a["Head_F"]
	face_base(f, SKIN, SKIN_D, blush="#d08a70", top=8)
	# savage narrow eyes with slit pupils, a smaller open pair directly under them
	for s, x in ((-1, 38), (1, 92)):
		eye2(f, x, 52, s, 36, 12, "#d11f24", tilt=5.5, r=8.2, lid=0.15, lash_t=3.8, flick=5, slit=True, pupil=0.34, sclera="#f8ecdf", crease_line=False)
		eye2(f, x + s * 2, 70, s, 21, 6, "#d11f24", tilt=2.4, r=4.4, lash_t=2, flick=2, slit=True, pupil=0.36, sclera="#f8ecdf", crease_line=False)
		brow2(f, x + s, 36, s, 34, 6, 7, "#3c2228", arc=-1)
		c = lambda d: 65 + s * d
		# forehead: two bars angled in to the centre
		_bar(f, [(c(6), 24), (c(32), 12), (c(34), 15), (c(8), 28)])
		_bar(f, [(c(8), 14), (c(26), 4), (c(28), 7), (c(10), 18)])
		# the cheek bar under the second eye runs to the edge of the face
		_bar(f, [(c(68), 82), (c(40), 84), (c(14), 80), (c(32), 88), (c(52), 91), (c(68), 90)])
		# jaw: one short bar each side of the chin
		_bar(f, [(c(52), 104), (c(38), 112), (c(42), 113), (c(56), 107)])
	# the bar over the nose
	_bar(f, [(55, 68), (75, 68), (73, 72), (57, 72)])
	f.soft("M60 80L65 75L70 80Q65 85 60 80Z", SKIN_D, 0.7, 1)
	# the grin: wide, pulled up hard on one side, full of pointed teeth
	f.path("M38 95Q64 102 92 90Q90 112 66 114Q44 112 38 95Z", "#37080c", stroke=TAT, sw=1.4)
	f.path("M40 95.6Q64 102.4 90 91L88 97Q76 98 66 103Q50 101 42 100Z", "#f6f0e4")
	for x, y in ((47, 98), (54, 100), (61, 102), (69, 102), (76, 100), (83, 97)):
		f.path(f"M{x - 3} {y - 2}L{x + 3} {y - 2}L{x} {y + 4.4}Z", "#f6f0e4")
	for x, y in ((50, 111), (59, 113), (68, 113), (77, 110)):
		f.path(f"M{x - 3} {y}L{x + 3} {y}L{x} {y - 5.5}Z", "#f6f0e4")
	stroke(f, "M34 91L38 95", TAT, 1.3)
	stroke(f, "M96 85L92 90", TAT, 1.3)
	# the chin bar
	_bar(f, [(55, 120), (75, 120), (73, 124), (57, 124)])
	head_rest(a, SKIN_D, shade(SKIN, 0.6))
