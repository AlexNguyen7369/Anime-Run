# Painted look for jk_shadows. Uniform and spiral buttons close to the source design, drawn in-house (design doc 5).
from atlas import INK, paint_hair, shade
from jk_common import brow2, buried, collar, eye2, flipped, form, hair_ink, head_front, hem_line, jacket_back, jacket_front, jacket_side, nose, pal, side_face, sleeve, swirl_button, trouser

SKIN = "#f0d6c2"
UNI = pal("#1c2030", "#0a0c15", "#4e5c82", "#6b7ca8")
HAIR_DARK = "#1A1C28"  # the near-black mass
HAIR_BLUE = "#262B40"  # blue sheen tufts
DEFAULT = UNI["base"]
HAIR_COLOURS = [HAIR_DARK, HAIR_BLUE]


def _urchin():
	"""The sea-urchin mop: spikes in every direction, a layered jagged fringe, no bald spot from any side."""
	blue = {"colour": HAIR_BLUE}
	return [
		# fringe: long uneven shards hanging into the eyes
		{"b": [0.0, -0.6, 5.28], "c": [0.04, -0.72, 5.0], "t": [-0.02, -0.68, 4.74], "r": 0.16},
		{"b": [-0.2, -0.6, 5.26], "c": [-0.28, -0.72, 5.0], "t": [-0.2, -0.68, 4.78], "r": 0.15, **blue},
		{"b": [0.2, -0.6, 5.26], "c": [0.3, -0.72, 5.02], "t": [0.24, -0.68, 4.8], "r": 0.15, **blue},
		{"b": [-0.42, -0.58, 5.24], "c": [-0.52, -0.7, 5.02], "t": [-0.5, -0.67, 4.82], "r": 0.14},
		{"b": [0.42, -0.58, 5.24], "c": [0.52, -0.7, 5.02], "t": [0.48, -0.67, 4.84], "r": 0.14},
		{"b": [-0.6, -0.5, 5.2], "c": [-0.72, -0.6, 4.96], "t": [-0.68, -0.6, 4.7], "r": 0.11, **blue},
		{"b": [0.6, -0.5, 5.2], "c": [0.72, -0.6, 4.96], "t": [0.7, -0.6, 4.72], "r": 0.11, **blue},
		# front face of the mop, forward and up
		{"b": [0.0, -0.5, 5.2], "c": [0.02, -0.92, 5.62], "t": [-0.06, -1.1, 6.02], "r": 0.26},
		{"b": [0.34, -0.5, 5.2], "c": [0.52, -0.9, 5.56], "t": [0.76, -1.06, 5.92], "r": 0.25, **blue},
		{"b": [-0.34, -0.5, 5.2], "c": [-0.5, -0.88, 5.6], "t": [-0.72, -1.04, 6.0], "r": 0.25},
		{"b": [0.58, -0.44, 5.14], "c": [0.92, -0.72, 5.26], "t": [1.28, -0.82, 5.44], "r": 0.22},
		{"b": [-0.58, -0.44, 5.14], "c": [-0.94, -0.7, 5.3], "t": [-1.3, -0.8, 5.5], "r": 0.22, **blue},
		# top: tall ones
		{"b": [0.0, -0.16, 5.3], "c": [0.04, -0.3, 5.96], "t": [-0.04, -0.34, 6.58], "r": 0.3},
		{"b": [0.3, -0.14, 5.3], "c": [0.48, -0.26, 5.9], "t": [0.66, -0.3, 6.44], "r": 0.28, **blue},
		{"b": [-0.3, -0.14, 5.3], "c": [-0.46, -0.26, 5.92], "t": [-0.58, -0.3, 6.5], "r": 0.28},
		{"b": [0.16, 0.2, 5.3], "c": [0.24, 0.26, 5.96], "t": [0.26, 0.3, 6.5], "r": 0.28},
		{"b": [-0.18, 0.2, 5.3], "c": [-0.26, 0.26, 5.94], "t": [-0.32, 0.3, 6.46], "r": 0.28, **blue},
		{"b": [0.52, 0.06, 5.26], "c": [0.86, 0.06, 5.82], "t": [1.08, 0.04, 6.24], "r": 0.26},
		{"b": [-0.52, 0.06, 5.26], "c": [-0.86, 0.06, 5.84], "t": [-1.02, 0.04, 6.28], "r": 0.26, **blue},
		# sides: straight out at temple height
		{"b": [0.58, -0.1, 5.1], "c": [1.04, -0.16, 5.34], "t": [1.54, -0.18, 5.68], "r": 0.26, **blue},
		{"b": [-0.58, -0.1, 5.1], "c": [-1.04, -0.16, 5.36], "t": [-1.5, -0.18, 5.76], "r": 0.26},
		{"b": [0.6, 0.18, 5.0], "c": [1.1, 0.22, 5.04], "t": [1.58, 0.24, 5.2], "r": 0.25},
		{"b": [-0.6, 0.18, 5.0], "c": [-1.08, 0.22, 5.02], "t": [-1.56, 0.26, 5.14], "r": 0.25, **blue},
		{"b": [0.62, -0.26, 4.9], "c": [1.0, -0.3, 4.78], "t": [1.32, -0.3, 4.76], "r": 0.2},
		{"b": [-0.62, -0.26, 4.9], "c": [-1.0, -0.3, 4.78], "t": [-1.34, -0.3, 4.7], "r": 0.2, **blue},
		{"b": [0.62, 0.22, 4.72], "c": [0.94, 0.28, 4.56], "t": [1.2, 0.3, 4.46], "r": 0.2, **blue},
		{"b": [-0.62, 0.22, 4.72], "c": [-0.94, 0.28, 4.56], "t": [-1.2, 0.3, 4.44], "r": 0.2},
		{"b": [0.6, -0.1, 4.7], "c": [0.8, -0.12, 4.56], "t": [0.96, -0.12, 4.36], "r": 0.14},
		{"b": [-0.6, -0.1, 4.7], "c": [-0.8, -0.12, 4.56], "t": [-0.96, -0.12, 4.36], "r": 0.14},
		# back: out and up, then down over the nape
		{"b": [0.0, 0.48, 5.26], "c": [0.0, 0.92, 5.72], "t": [0.04, 1.16, 6.14], "r": 0.3, **blue},
		{"b": [0.38, 0.46, 5.24], "c": [0.62, 0.86, 5.66], "t": [0.88, 1.08, 6.0], "r": 0.28},
		{"b": [-0.38, 0.46, 5.24], "c": [-0.62, 0.86, 5.66], "t": [-0.84, 1.1, 6.04], "r": 0.28, **blue},
		{"b": [0.0, 0.56, 4.98], "c": [0.1, 1.0, 5.14], "t": [0.26, 1.34, 5.46], "r": 0.3},
		{"b": [0.42, 0.56, 4.96], "c": [0.72, 0.98, 5.0], "t": [1.0, 1.28, 5.1], "r": 0.27, **blue},
		{"b": [-0.42, 0.56, 4.96], "c": [-0.72, 0.98, 5.0], "t": [-1.0, 1.28, 5.12], "r": 0.27},
		{"b": [0.16, 0.58, 4.68], "c": [0.22, 0.96, 4.56], "t": [0.26, 1.24, 4.5], "r": 0.26, **blue},
		{"b": [-0.2, 0.58, 4.66], "c": [-0.28, 0.94, 4.54], "t": [-0.32, 1.2, 4.46], "r": 0.26},
		{"b": [0.46, 0.56, 4.64], "c": [0.66, 0.84, 4.5], "t": [0.82, 1.02, 4.4], "r": 0.2},
		{"b": [-0.46, 0.56, 4.64], "c": [-0.66, 0.84, 4.5], "t": [-0.82, 1.02, 4.38], "r": 0.2, **blue},
		{"b": [0.0, 0.58, 4.4], "c": [0.0, 0.8, 4.28], "t": [0.0, 0.92, 4.16], "r": 0.22},
	]


def _shortened(locks, k=0.84):
	"""Trims every spike towards its root (fringe excluded, its tips sit where the eyes need them)."""
	for l in locks:
		if l["t"][2] > l["b"][2] - 0.1 or l["t"][1] > 0.7:
			l["c"] = [l["b"][i] + (l["c"][i] - l["b"][i]) * k for i in range(3)]
			l["t"] = [l["b"][i] + (l["t"][i] - l["b"][i]) * k for i in range(3)]
	return locks


HAIR = {"colour": HAIR_DARK, "cap": {"size": [1.24, 1.16, 0.34], "at": [0, 0, 5.18], "bevel": 0.14}, "locks": buried(_shortened(_urchin()))}


def _feet(colour, box, at, bevel=0.05):
	return [{"part": part, "box": box, "at": [sgn * at[0], at[1], at[2]], "colour": colour, "bevel": bevel} for part, sgn in (("LeftFoot", 1), ("RightFoot", -1))]


PROPS = [
	*_feet("#20222A", [1.0, 0.36, 0.2], (0.5, -0.6, 0.12)),
	*_feet("#C8C4BC", [1.02, 1.34, 0.08], (0.5, -0.1, 0.04)),
]


def model(parts, kit):
	"""The tall stand-up collar, closing right under the chin."""
	collar(kit, parts["UpperTorso"], "Collar", "#1F2436", 0.72, 0.66, 3.96, lambda t: 0.13 + 0.2 * t ** 0.7, thick=0.06, gap=0.05, lean=0.03)


def _shoe(f, key):
	"""Plain black work shoe: sole, stitched toe seam."""
	top = 168
	f.path(f"M-5 {top}H105V206H-5Z", "#1d1f26")
	f.soft(f"M14 {top + 2}H42V{top + 22}H14Z", "#6a7080", 0.5, 3)
	f.ink(f"M-5 {top}H105", 1.6)
	f.path("M-5 192H105V206H-5Z", "#c8c4bc")
	f.ink("M-5 192H105", 1.2)
	if key == "F":
		for y in range(top + 3, 190, 5):
			f.ink(f"M42 {y}H58", 0.9, "#8a8e98")
		f.ink(f"M36 {top}V192M64 {top}V192", 0.8)
	elif key == "O":
		f.taper(10, top + 14, 50, top + 8, 90, 188, 0.7, "#6a7080")


def _hair_side(f):
	"""Black shards to the jaw with a blue sheen, an ear just showing."""
	side_face(f, SKIN, 70, 66)
	f.path("M-5 -5H125V110L108 100L104 114L88 92L82 72Q70 50 60 58Q56 70 58 88L46 72L40 88L30 58L22 72L14 46L6 62L-5 40Z", HAIR_DARK)
	f.soft("M4 8Q40 2 76 8Q72 30 40 38Q10 30 4 8Z", "#46527e", 0.5, 5)
	for x0, y0, x1, y1 in ((18, 2, 22, 56), (42, 2, 42, 66), (66, 2, 56, 46), (88, 2, 96, 84), (110, 2, 110, 92)):
		f.taper(x0, y0, (x0 + x1) / 2 + 3, (y0 + y1) / 2, x1, y1, 1.2, "#05060c")
		f.taper(x0 + 3, y0 + 4, (x0 + x1) / 2 + 6, (y0 + y1) / 2 - 8, x1 + 2, y1 - 22, 0.9, "#3e4c78")


def paint(a):
	paint_hair(a, ["#20222e", "#2c3350"])
	hair_ink(a, 0, 2, "#262935", gap=0.2, shine=1.9)
	hair_ink(a, 1, 2, "#303855", gap=0.25, shine=1.7)
	# ---- face: long narrow eyes half shut, thin level brows, a small flat mouth. Unimpressed and cold.
	f = a["Head_F"]
	head_front(f, SKIN, hair_shadow=44, jaw_y=84, chin_y=125, chin_w=17)
	f.soft("M-5 30H22Q24 48 14 74H-5Z", "#3a3548", 0.28, 3)
	f.soft("M135 30H108Q106 48 116 74H135Z", "#3a3548", 0.28, 3)
	eye2(f, 42, 66, -1, 28, 8.5, "#256a78", tilt=2.2, r=7.4, lid=0.55, lash_t=2.6, flick=3, look=1.2, crease_line=False)
	eye2(f, 88, 66, 1, 28, 8.5, "#256a78", tilt=2.2, r=7.4, lid=0.55, lash_t=2.6, flick=3, look=-1.2, crease_line=False)
	brow2(f, 41, 54, -1, 26, 3, 2.0, "#15161f", arc=-0.5)
	brow2(f, 89, 54, 1, 26, 3, 2.0, "#15161f", arc=-0.5)
	f.taper(35, 74, 44, 76, 53, 74, 0.5, shade(SKIN, 0.62))
	f.taper(95, 74, 86, 76, 77, 74, 0.5, shade(SKIN, 0.62))
	nose(f, SKIN, 76, 14)
	f.taper(56, 106, 66, 105, 74, 107, 1.1)
	f.taper(60, 110.5, 65, 111.5, 70, 110.5, 0.5, shade(SKIN, 0.55))
	# ---- sides and back
	for name in ("Head_L", "Head_R"):
		f = a[name]
		if name == "Head_R":
			with flipped(f):
				_hair_side(f)
		else:
			_hair_side(f)
	f = a["Head_B"]
	f.fill(HAIR_DARK)
	f.soft("M10 8Q60 0 118 10Q110 48 66 56Q20 48 10 8Z", "#46527e", 0.4, 8)
	for i in range(16):
		x = 4 + i * 8.2
		f.taper(x, 2, x + f.rng.uniform(-3, 3), 60, x + f.rng.uniform(-6, 6), 120 + f.rng.uniform(-14, 6), 1.2, "#05060c")
		if i % 2:
			f.taper(x + 3, 12, x + 3, 40, x + 4, 72, 0.8, "#3e4c78")
	f.path("M-5 135V124L10 116L22 126L40 112L54 128L72 114L88 128L104 114L120 124L135 116V135Z", shade(SKIN, 0.5))
	form(f, "#04050b", 0.4)
	a["Head_T"].fill(HAIR_DARK)
	a["Head_Bo"].fill(shade(SKIN, 0.5))
	# ---- torso: a straight closed jacket, three spiral buttons down a real placket
	base2 = shade(UNI["base"], 0.75)
	f = a["Torso_F"]
	jacket_front(f, UNI, seed=2, hem=178)
	hem_line(f, UNI, 178, base2)
	f.path("M90 -5H110L111 178H89Z", shade(UNI["base"], 1.12))
	f.taper(89, -5, 88, 90, 89, 178, 1.4)
	f.taper(111, -5, 112, 90, 111, 178, 1.4)
	f.taper(92, -5, 91, 90, 92, 178, 0.6, UNI["lite"])
	f.soft("M-5 -5H205V14Q100 26 -5 14Z", "#000000", 0.5, 3)
	for y in (24, 72, 122):
		swirl_button(f, 100, y, 8.5)
	form(f)
	f = a["Torso_B"]
	jacket_back(f, UNI, seed=2, hem=178)
	hem_line(f, UNI, 178, base2)
	form(f)
	for name in ("Torso_L", "Torso_R"):
		f = a[name]
		jacket_side(f, UNI, seed=2, hem=178)
		hem_line(f, UNI, 178, base2)
		form(f)
	a["Torso_T"].fill(UNI["base"])
	a["Torso_T"].soft("M0 0H200V30H0Z", UNI["sheen"], 0.3, 5)
	a["Torso_Bo"].fill(UNI["dark"])
	# ---- limbs: narrow plain sleeves, straight trousers
	for side in ("Left", "Right"):
		for key in "FBOI":
			sleeve(a[f"{side}Arm_{key}"], UNI, key, seed=side + "s", skin=SKIN, cuff=156, hand_top=168)
			f = a[f"{side}Leg_{key}"]
			trouser(f, UNI, key, seed=side + "s", shoe_top=168)
			_shoe(f, key)
		a[f"{side}Arm_T"].fill(UNI["base"])
		a[f"{side}Arm_Bo"].fill(SKIN)
		a[f"{side}Leg_T"].fill(UNI["base"])
		a[f"{side}Leg_Bo"].fill("#c8c4bc")
