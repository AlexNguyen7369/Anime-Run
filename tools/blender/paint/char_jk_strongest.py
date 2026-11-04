# Painted look for jk_strongest. Blindfold and high-collar uniform close to the source design, drawn in-house (design doc 5).
import random

from atlas import INK, paint_hair, shade
from jk_common import buried, collar, flipped, form, hair_ink, head_front, hem_line, jacket_back, jacket_front, jacket_side, nose, pal, side_face, sleeve, trouser

SKIN = "#f6ddcc"
UNI = pal("#1b1f2e", "#090b12", "#56617f", "#7382aa")
WHITE = "#F2F5FA"
BLUE_W = "#BFD2EA"  # cool shadow tufts
BAND = "#0E0E14"
DEFAULT = UNI["base"]
HAIR_COLOURS = [WHITE, BLUE_W]


def _tall():
	"""Pushed straight up by the blindfold: a dense flame of thin spikes fanning out, nape cropped short."""
	r = random.Random("jk_strongest")
	out = []
	# (root y, root z, length, half-spread at the head edge, fan lean, count, thickness)
	for y, z, ln, spread, lean, n, th in ((-0.56, 4.98, 0.9, 0.6, 0.42, 8, 0.27), (-0.3, 5.26, 1.14, 0.56, 0.5, 7, 0.3), (0.04, 5.3, 1.36, 0.54, 0.52, 7, 0.32), (0.34, 5.24, 1.16, 0.56, 0.5, 7, 0.3), (0.56, 5.0, 0.96, 0.56, 0.46, 7, 0.27)):
		for k in range(n):
			x = (2 * k / (n - 1) - 1) * spread + r.uniform(-0.03, 0.03)
			out_x = x * lean * 1.9
			l = ln * r.uniform(0.84, 1.08) * (1 - 0.3 * abs(x))
			dy = {-0.56: -0.1, -0.3: -0.08, 0.04: 0.0, 0.34: 0.12, 0.56: 0.4}[y]
			tip = [x + out_x + r.uniform(-0.05, 0.05), y + dy, z + l]
			ctrl = [x + out_x * 0.35, y + dy * 0.4, z + l * 0.55]
			col = BLUE_W if k % 3 == 1 else WHITE
			out.append({"b": [x, y, z], "c": ctrl, "t": tip, "r": th * r.uniform(0.92, 1.1), "flatten": 0.6, "colour": col})
	# Sides: closes the wall of hair above the temples.
	for sgn in (1, -1):
		for y, l in ((-0.34, 0.86), (-0.08, 0.94), (0.18, 0.92), (0.42, 0.84)):
			b = [sgn * 0.6, y, 4.98]
			out.append({"b": b, "c": [sgn * 0.84, y, 5.42], "t": [sgn * (0.96 + r.uniform(-0.06, 0.08)), y + r.uniform(-0.04, 0.04), 4.98 + l], "r": 0.25, "flatten": 0.6, "colour": BLUE_W if y > 0 else WHITE})
	# Below the band: short tufts at the ears and nape.
	for b, t, rad, col in (
		([0.6, 0.0, 4.6], [0.74, 0.02, 4.3], 0.13, WHITE),
		([-0.6, 0.0, 4.6], [-0.74, 0.02, 4.3], 0.13, WHITE),
		([0.6, 0.34, 4.6], [0.74, 0.42, 4.26], 0.14, BLUE_W),
		([-0.6, 0.34, 4.6], [-0.74, 0.42, 4.26], 0.14, BLUE_W),
		([0.0, 0.58, 4.6], [0.0, 0.74, 4.2], 0.2, WHITE),
		([0.3, 0.58, 4.6], [0.36, 0.74, 4.24], 0.18, BLUE_W),
		([-0.3, 0.58, 4.6], [-0.36, 0.74, 4.24], 0.18, BLUE_W),
		([0.54, 0.58, 4.58], [0.6, 0.72, 4.3], 0.14, WHITE),
		([-0.54, 0.58, 4.58], [-0.6, 0.72, 4.3], 0.14, WHITE),
	):
		out.append({"b": b, "c": [(b[0] + t[0]) / 2, (b[1] + t[1]) / 2 + 0.02, (b[2] + t[2]) / 2 + 0.03], "t": t, "r": rad, "colour": col})
	return out


HAIR = {"colour": WHITE, "cap": {"size": [1.26, 1.18, 0.42], "at": [0, 0, 5.14], "bevel": 0.14}, "locks": buried(_tall())}


def _feet(colour, box, at, bevel=0.05):
	return [{"part": part, "box": box, "at": [sgn * at[0], at[1], at[2]], "colour": colour, "bevel": bevel} for part, sgn in (("LeftFoot", 1), ("RightFoot", -1))]


PROPS = [
	# The blindfold: a wide wrap, lifted off the block so the hair clearly erupts over it.
	{"part": "Head", "box": [1.34, 1.24, 0.32], "at": [0, 0, 4.76], "colour": BAND, "bevel": 0.03},
	{"part": "Head", "lock": [[0.08, 0.63, 4.8], [0.26, 0.9, 4.72], [0.34, 1.02, 4.42]], "r": 0.1, "colour": BAND, "flatten": 0.35},
	{"part": "Head", "lock": [[-0.08, 0.63, 4.8], [-0.2, 0.86, 4.7], [-0.26, 0.94, 4.36]], "r": 0.1, "colour": BAND, "flatten": 0.35},
	# wrinkles caught in the wrap
	{"part": "Head", "poly": [[-0.62, 4.84], [-0.1, 4.86], [0.36, 4.82], [-0.1, 4.88]], "y": -0.625, "colour": "#3A3C48"},
	{"part": "Head", "poly": [[0.62, 4.72], [0.2, 4.76], [-0.3, 4.72], [0.2, 4.78]], "y": -0.625, "colour": "#2E3038"},
	{"part": "Head", "poly": [[-0.6, 4.68], [-0.3, 4.7], [-0.04, 4.66], [-0.3, 4.72]], "y": -0.625, "colour": "#2E3038"},
	{"part": "Head", "poly": [[0.1, 4.88], [0.4, 4.9], [0.62, 4.86], [0.4, 4.92]], "y": -0.625, "colour": "#2E3038"},
	*_feet("#14151C", [1.0, 0.36, 0.2], (0.5, -0.6, 0.12)),
	*_feet("#101116", [1.02, 1.34, 0.08], (0.5, -0.1, 0.04)),
]


def model(parts, kit):
	"""The very tall collar, nearly to the mouth, the top opening at the throat."""
	collar(kit, parts["UpperTorso"], "Collar", "#181C2A", 0.72, 0.66, 3.96, lambda t: 0.17 + 0.16 * t ** 0.7, thick=0.06, gap=0.04, lean=0.04)


def _shoe(f, key):
	top = 170
	f.path(f"M-5 {top}H105V206H-5Z", "#17181f")
	f.soft(f"M16 {top + 2}H44V{top + 20}H16Z", "#7a8094", 0.4, 3)
	f.ink(f"M-5 {top}H105", 1.6)
	f.path("M-5 194H105V206H-5Z", "#0c0d12")
	f.ink("M-5 194H105", 1)


def _side(f):
	side_face(f, SKIN, 68, 72)
	# white hair above and behind the band, cropped behind the ear
	f.path("M-5 -5H125V96L112 104L104 88L96 100L88 72Q82 60 68 58L-5 58Z", WHITE)
	f.path("M70 60L78 82L88 72Z", BLUE_W)
	for x0, y1 in ((94, 96), (108, 100)):
		f.taper(x0, 60, x0 + 2, 80, x0 + 1, y1, 1, "#8fa6c6")
	# Band on the side: lit by a long streak
	f.path("M-5 36H125V68H-5Z", BAND)


def paint(a):
	paint_hair(a, ["#f7f9fd", "#c8d8ee"])
	hair_ink(a, 0, 2, "#f9fbff", gap=0.74, shine=1.0, root="#c6d6ec")
	hair_ink(a, 1, 2, "#dbe6f6", gap=0.68, shine=1.05, root="#a9bfdd")
	# ---- face: smooth and pale, a long straight nose, a thin amused smirk. The band hides the eyes.
	f = a["Head_F"]
	head_front(f, SKIN, hair_shadow=24, jaw_y=86, chin_y=125, chin_w=18)
	f.path("M-5 36H135V68H-5Z", BAND)
	f.soft("M-5 68H135V78H-5Z", "#3c3448", 0.5, 2)
	# long straight nose
	f.path("M64 69L70 88L60 91Q64 82 64 69Z", shade(SKIN, 0.68), opacity=0.9)
	f.taper(59, 91, 65, 93, 71, 89, 0.9, shade(SKIN, 0.35))
	# thin amused smirk, one corner up
	f.taper(50, 107.5, 66, 108.5, 82, 104.5, 1.2)
	f.ink("M82 104.5Q84.5 103.5 86 100.5", 1.2)
	f.taper(60, 115, 66, 116.5, 74, 115, 0.6, shade(SKIN, 0.55))
	# ---- sides and back
	_side(a["Head_L"])
	with flipped(a["Head_R"]):
		_side(a["Head_R"])
	f = a["Head_B"]
	f.fill(WHITE)
	for i in range(14):
		x = 4 + i * 9.4
		f.taper(x, 72, x + 2, 94, x + f.rng.uniform(-3, 3), 112 + f.rng.uniform(-8, 6), 1.1, "#8fa6c6")
	f.soft("M-5 72H135V90H-5Z", "#7f96ba", 0.6, 3)
	f.path("M-5 36H135V68H-5Z", BAND)
	f.path("M-5 135V116L16 106L28 118L46 104L62 122L80 104L96 120L114 106L135 116V135Z", shade(SKIN, 0.5))
	a["Head_T"].fill(WHITE)
	a["Head_Bo"].fill(shade(SKIN, 0.5))
	# ---- torso: all black, long jacket, no visible buttons, a hidden fly and a long drape to the hem
	base2 = shade(UNI["base"], 0.72)
	f = a["Torso_F"]
	jacket_front(f, UNI, seed=3, hem=192, extra=[(40, 40, 30, 110, 44, 176, 7), (160, 40, 170, 110, 156, 176, 7)])
	hem_line(f, UNI, 192, base2)
	f.path("M96 -5H104V192H96Z", shade(UNI["base"], 0.62))
	for y in range(0, 190, 5):
		f.ink(f"M97.5 {y}H102.5", 1.3, "#8c93a6")
	f.ink("M96 -5V192M104 -5V192", 1.3)
	f.path("M97 6H103V20H97Z", "#b4bac8", stroke=INK, sw=1)
	f.soft("M-5 -5H205V8Q100 18 -5 8Z", "#000000", 0.45, 3)
	form(f, op=0.34)
	f = a["Torso_B"]
	jacket_back(f, UNI, seed=3, hem=192)
	hem_line(f, UNI, 192, base2)
	form(f, op=0.34)
	for name in ("Torso_L", "Torso_R"):
		f = a[name]
		jacket_side(f, UNI, seed=3, hem=192)
		hem_line(f, UNI, 192, base2)
		form(f, op=0.34)
	a["Torso_T"].fill(UNI["base"])
	a["Torso_T"].soft("M0 0H200V30H0Z", UNI["sheen"], 0.3, 5)
	a["Torso_Bo"].fill(UNI["dark"])
	for side in ("Left", "Right"):
		for key in "FBOI":
			sleeve(a[f"{side}Arm_{key}"], UNI, key, seed=side + "g", skin=SKIN, cuff=158, hand_top=170)
			f = a[f"{side}Leg_{key}"]
			trouser(f, UNI, key, seed=side + "g", shoe_top=170)
			_shoe(f, key)
		a[f"{side}Arm_T"].fill(UNI["base"])
		a[f"{side}Arm_Bo"].fill(SKIN)
		a[f"{side}Leg_T"].fill(UNI["base"])
		a[f"{side}Leg_Bo"].fill("#0c0d12")
