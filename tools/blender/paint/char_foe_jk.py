# Target look for foe_jk, Jogoh (design doc 4.26 and section 5): a volcano for a head, pale grey skin fading to brown at the
# crater, one eye in a black stitched band, big ears plugged with corks, a pale scarf and spotted yellow-green shawl over a loose black shirt
# with quarter sleeves, baggy black trousers, brown shoes with red soles. Short in his source; stays on the standard block body.
# No marks: the spots, stitches and band are clothes and face. Drawn in-house. +X is the viewer's right in the front view.
import math
import random

from atlas import shade
from jk_style3 import Kit, bake, block, collar, jitter, dress_shoe, finish, torso_core, trouser
from leaf_common import ell
from style2 import Ramps

SKIN = "#d7d1c8"
SKIN_D = "#a8a097"
BAND = "#101012"
SHAWL = "#c9c76a"
SHAWL_D = "#94923f"
SPOT = "#23241a"
SHIRT = "#1c1c22"
DEFAULT = SHIRT
R = Ramps(
	skin=["#958e85", "#bdb6ac", SKIN, "#ece7df"],
	# bottom to top of the cone, not dark to light: skin, then brown, then the scorched rim
	cone=[SKIN, "#d0c6b8", "#ad8c6e", "#7a5034", "#46291a"],
	ember=["#4a1208", "#8e2410", "#d0501a", "#f09030"],
	shawl=[SHAWL_D, "#aeac52", SHAWL, "#dedc86"],
	black=["#060608", "#101014", SHIRT, "#30303a"],
	scarf=["#a8a498", "#d4d0c2", "#efebdc", "#fbf8ec"],
	cork=["#80592f", "#a87c48", "#c8a06a", "#e0be8a"],
	shoe=["#3a2212", "#553219", "#6a4226", "#8c5c38"],
	sole=["#5a0e0e", "#8e1616", "#b82020", "#dc3a30"],
)
HAIR = {"colour": SKIN, "locks": []}
PROPS = []
# wider than the cast's head: a rotund face under the cone
HEAD_ROWS = [(0, 0, 3.98, 0.6, 0.62), (0, 0, 4.14, 0.88, 0.8), (0, 0, 4.42, 0.97, 0.85), (0, 0, 5.05, 0.97, 0.85), (0, 0, 5.2, 0.9, 0.8)]
RIM = 0.4  # anything inside this near the top is the crater's inner wall
FLOOR = 5.86


def _volcano(k):
	# the concave sweep of the mountain, up to a rim, then down inside to the crater floor
	rows = [(0, 0, 4.98, 0.975, 0.855), (0, 0, 5.2, 0.93, 0.815), (0, 0, 5.42, 0.74, 0.67), (0, 0, 5.72, 0.56, 0.52), (0, 0, 6.02, 0.46, 0.44), (0, 0, 6.12, 0.47, 0.45), (0, 0, 6.1, 0.37, 0.35), (0, 0, FLOOR, 0.22, 0.21)]
	o = k.tube("Head", "Volcano", rows, "cone", corner=0.6, nc=1, sub=1, outline=0)
	jitter(o, 0.018)
	inner = lambda co: 1.0 if co.z > FLOOR - 0.03 and max(abs(co.x), abs(co.y)) < RIM else 0.0
	# lit facets go up the ramp's pale end, so b is negative here
	bake(o, "cone", k, a=0.5, b=-0.09, g=0.95, extra=inner)
	# a dull ember only: the flames belong to his rage, not his resting state
	o = k.lathe("Head", "Ember", [(0.2, FLOOR + 0.01, 0.5), (0.01, FLOOR + 0.03, 0.5)], "ember", n=8, outline=0)
	bake(o, "ember", k, a=0.22, b=0.2)


def _cork(k, s):
	"""The ear is a wide round trough on the head; a big cork plugs it, small end in. Both lie along x."""
	for name, ramp, rows, a in (("Ear", "skin", ((0.9, 0.3), (1.02, 0.31), (1.09, 0.25)), 0.56), ("Cork", "cork", ((1.0, 0.16), (1.24, 0.2), (1.33, 0.21), (1.37, 0.17)), 0.5)):
		y, z, n = 0.02, 4.68, 8
		rings = [[(s * x, y + r * math.cos(2 * math.pi * j / n), z + r * math.sin(2 * math.pi * j / n)) for j in range(n)] for x, r in rows]
		verts, faces, flat = k._loft(rings)
		bake(k._mesh(f"{name}{s}", "Head", verts, faces, flat, outline=0), ramp, k, a=a, b=0.4)


def _head(k):
	k.reshape("Head", "Head", HEAD_ROWS, corner=0.34, nc=2, fit=True, flat_front=True)
	_volcano(k)
	for s in (1, -1):
		_cork(k, s)


def _torso(k):
	t = "UpperTorso"
	torso_core(k)
	block(k, t, "Shirt", 0, 0, 3.2, 2.02, 1.03, 0.54, "black", ch=0.03, flare=0.03, jit=0.03, mids=(2.7, 2.4), a=0.46, b=0.6, tone=0.05)
	block(k, t, "Hem", 0, 0, 2.14, 1.92, 1.075, 0.585, "black", ch=0.03, a=0.42, b=0.56)
	# the shawl wears the torso art: it carries the painted spots
	rows = [(0, 0, 4.03, 0.86, 0.48), (0, 0, 3.92, 1.09, 0.61), (0, 0, 3.4, 1.11, 0.63), (0, 0, 2.86, 1.13, 0.65)]
	k.tube(t, "Shawl", rows, ("face", "Torso"), corner=0.16, nc=1, sub=1, zig=0.05, outline=0)
	collar(k, "scarf", 4.12, 4.3, z0=3.92, rx=0.98, ry=0.9, name="Scarf", a=0.5, b=0.5)


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	# quarter sleeve: loose, ending above the elbow's line, the bare forearm hanging out of it
	block(k, arm, "Forearm", ax, 0, 3.05, 2.0, 0.47, 0.47, "skin", ch=0.04, a=0.58, b=0.32)
	block(k, arm, "Hand", ax, 0, 2.08, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)
	block(k, arm, "Sleeve", ax, 0, 3.66, 2.86, 0.55, 0.55, "black", ch=0.05, flare=0.02, corner=0.18, jit=0.025, sub=1, a=0.46, b=0.6, tone=0.04)
	rows = [(ax, 0, 4.08, 0.42, 0.42), (ax, 0, 3.98, 0.56, 0.56), (ax, 0, 3.5, 0.585, 0.585)]
	k.tube(arm, "ShawlCap", rows, ("face", side + "Arm"), corner=0.2, nc=1, sub=1, zig=0.04, outline=0)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	_head(k)
	_torso(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		leg, px = trouser(k, side, s, ramp="black", low=0.44)
		dress_shoe(k, leg, px, ramp="shoe", sole="sole", top=0.52)
	finish()


def _spots(f, x0, x1, y0, y1, step=26, r=4.6):
	"""Round spots on a jittered grid, the same each build."""
	rng = random.Random(f.name)
	y = y0
	row = 0
	while y < y1:
		x = x0 + (step / 2 if row % 2 else 0)
		while x < x1:
			rr = r * rng.uniform(0.8, 1.2)
			f.path(ell(x + rng.uniform(-5, 5), y + rng.uniform(-5, 5), rr, rr * rng.uniform(0.8, 1.1)), SPOT)
			x += step
		y += step * 0.8
		row += 1


def _shawl(f, bottom):
	"""The spotted cloth over the upper face, black shirt under it. Lower pieces of the block never show."""
	f.fill(SHIRT)
	f.path(f"M-5-5H{f.w + 5}V{bottom}H-5Z", SHAWL)
	f.soft(f"M-5 {bottom - 22}H{f.w + 5}V{bottom}H-5Z", SHAWL_D, 0.75, 5)
	f.soft(f"M-5-5H{f.w * 0.1}V{bottom}H-5Z", SHAWL_D, 0.5, 5)
	f.soft(f"M{f.w + 5}-5H{f.w * 0.88}V{bottom}H{f.w + 5}Z", SHAWL_D, 0.7, 5)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5 30H9Q5 90 26 135H-5Z", SKIN_D, 0.75, 5)
	f.soft("M135 30H121Q125 90 104 135H135Z", SKIN_D, 0.9, 5)
	f.soft("M28 124Q65 114 102 124V135H28Z", SKIN_D, 0.6, 3)
	# the band, its stitches biting into the skin above and below like a row of teeth
	f.path("M-5 46H135V78H-5Z", BAND)
	for x in range(3, 130, 11):
		f.path(f"M{x - 2.2} 47L{x + 2.2} 47L{x + 1.2} 38L{x - 1.2} 38Z", BAND)
		f.path(f"M{x - 2.2} 77L{x + 2.2} 77L{x + 1.2} 86L{x - 1.2} 86Z", BAND)
	# one round, staring eye: pale, a small dark pupil, a dark lid across the top
	f.path(ell(65, 62, 22, 21), "#f4f0e6", stroke="#020203", sw=2.4)
	f.soft("M45 52Q65 40 85 52L82 58Q65 50 48 58Z", "#6a6258", 0.75, 1)
	f.path(ell(65, 63, 6.6, 7.2), "#0a090c")
	f.path(ell(62.6, 60.4, 1.9, 1.9), "#ffffff")
	# a small hard mouth; no nose
	f.path("M50 108Q65 104 80 108", stroke="#2a211c", sw=2.2)
	f.path("M50 108L47 106M80 108L83 106", stroke="#2a211c", sw=1.6)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	for n, band in (("Head_L", "M-5 46H62V78H-5Z"), ("Head_R", "M125 46H58V78H125Z")):
		f = a[n]
		f.fill(SKIN)
		f.soft("M-5 104H125V135H-5Z", SKIN_D, 0.75, 3)
		f.path(band, BAND)
	f = a["Head_B"]
	f.fill(SKIN)
	f.soft("M-5 100H135V135H-5Z", SKIN_D, 0.8, 3)
	a["Head_T"].fill(SKIN)
	a["Head_Bo"].fill(SKIN_D)

	# shawl down to z 2.75 on every torso side
	f = a["Torso_F"]
	_shawl(f, 130)
	_spots(f, 6, 200, 12, 122)
	# the wrap crosses at the throat, shirt showing in a deep V
	f.path("M64-5L100 78L136-5Z", SHIRT)
	f.path("M64-5L100 78L136-5", stroke=SHAWL_D, sw=3.4)
	f.soft("M100 78L60 130H142Z", SHAWL_D, 0.5, 5)
	f = a["Torso_B"]
	_shawl(f, 130)
	_spots(f, 8, 200, 8, 122)
	f.soft("M40 20Q56 80 44 126M160 20Q144 80 156 126", SHAWL_D, 0.5, 3)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		_shawl(f, 130)
		_spots(f, 8, 100, 10, 122)
	f = a["Torso_T"]
	f.fill(SHAWL)
	# edge spots would smear down the chamfer, which shares the border's UVs
	_spots(f, 22, 180, 18, 84)
	a["Torso_Bo"].fill(shade(SHIRT, 0.7))

	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			_shawl(f, 60)
			_spots(f, 8, 100, 10, 54, step=24, r=4.2)
			a[f"{side}Leg_{key}"].fill(SHIRT)
		f = a[f"{side}Arm_T"]
		f.fill(SHAWL)
		_spots(f, 20, 82, 20, 82, step=24, r=4.2)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(SHIRT)
		a[f"{side}Leg_Bo"].fill(shade(SHIRT, 0.7))
