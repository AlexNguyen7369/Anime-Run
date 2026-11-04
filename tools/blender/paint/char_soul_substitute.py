# Target look for soul_substitute "Ichigu" (design doc section 5): tall spiky orange hair, a hard scowl and brown eyes, a black robe crossed at
# the chest over a white under-robe, a white waist sash, wide black trousers-skirt, white split socks and straw sandals. A thin red strap
# runs from his right shoulder to his left hip and carries a plate badge; a cleaver as tall as he is sits on his back, no guard, its tang
# wrapped in white cloth with one loose end. +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, form, nose
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, ears, finish, gem, head_rest, prism, slab, sleeve, stroke, torso_core
from style2 import Ramps

SKIN = "#f0c49c"
SKIN_D = "#c98f66"
BLACK = "#20222e"
BLACK_D = "#08080e"
BLACK_L = "#42465a"
WHITE = "#eef0f2"
HAIR_D = "#b94f0c"
HAIR_MID = "#e56b12"
DEFAULT = BLACK
R = Ramps(
	hair=["#a33f06", "#d9600d", "#f57f18", "#ff9e36", "#ffc36e"],
	skin=["#b67e52", "#dca878", "#f0c49c", "#fbdcbc"],
	robe=["#06060a", "#0d0e15", "#171822", "#242633", "#3a3d50"],
	hakama=["#05050a", "#0b0c12", "#14151e", "#20222e", "#343748"],
	white=["#9ea4b0", "#ccd0d8", "#eceef2", "#ffffff"],
	cloth=["#a7a59a", "#d2d0c4", "#efeee6", "#ffffff"],
	red=["#54090f", "#8d141a", "#c02a2a", "#e4524a"],
	spine=["#06060a", "#101118", "#20222d", "#3a3d4c"],
	steel=["#5c6470", "#8f97a4", "#c2c8d2", "#f2f5f8"],
	tang=["#14141a", "#24242c", "#3a3a44", "#55555f"],
	wood=["#3a2312", "#5b3a1f", "#80552e", "#a67a48"],
	woodl=["#8c6a3e", "#b48f58", "#d6b67c", "#f0d8a4"],
	straw=["#6e5228", "#9a7a40", "#c4a35e", "#e2c888"],
	shoe=["#a4a8b4", "#ced2da", "#eceef2", "#ffffff"],
	sole=["#6e5228", "#9a7a40", "#c4a35e", "#e2c888"],
)
HAIR = {"colour": "#E56B12", "locks": []}
PROPS = []

# The cleaver's frame: u runs from the tang's end to the tip, v across the blade (+v is the cutting edge), d through its thickness.
TOP = (-1.45, 5.5)
TIP = (1.15, 0.75)
_LEN = ((TIP[0] - TOP[0]) ** 2 + (TIP[1] - TOP[1]) ** 2) ** 0.5
_DIR = ((TIP[0] - TOP[0]) / _LEN, (TIP[1] - TOP[1]) / _LEN)
_ACROSS = (-_DIR[1], _DIR[0])


def _sw(u, v, d=0.0):
	x = TOP[0] + _DIR[0] * u + _ACROSS[0] * v
	z = TOP[1] + _DIR[1] * u + _ACROSS[1] * v
	# the blade leans away from the back as it rises, to clear the head and hair
	return (x, 0.66 + 0.084 * (z - 1.0) + d, z)


def _loft_mesh(k, part, name, rings, ramp, **bk):
	verts, faces, flat = k._loft(rings)
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **bk)


def _hair(k):
	crown(k, [(0.96, 5.34), (1.04, 5.6), (0.98, 5.85), (0.6, 6.12), (0.18, 6.2)])
	block(k, "Head", "Back", 0, 0.28, 5.46, 4.52, 0.92, 0.6, "hair", ch=0.06, corner=0.3, jit=0.02, sub=1, mids=(5.1,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.8, 5.42), (-0.8, 5.0), (-0.3, 4.88), (0.4, 4.84), (0.86, 4.9), (0.86, 5.42)], s * 0.82, s * 0.96, "hair", a=0.44, b=0.46)
		gem(k, "Head", f"Burn{s}", (s * 0.86, -0.56, 5.3), (s * 0.93, -0.62, 4.52), 0.17, flat=0.3, twist=0.25, across=(0, 1, 0), a=0.5)
		gem(k, "Head", f"Temple{s}", (s * 0.86, -0.2, 5.42), (s * 1.34, -0.3, 5.5), 0.26, flat=0.5, twist=0.3, a=0.52)
	# the nape: short points, tucked inside the blade's plane
	for i, (x, z, r) in enumerate(((-0.66, 4.38, 0.24), (-0.26, 4.28, 0.28), (0.18, 4.3, 0.28), (0.62, 4.36, 0.24))):
		gem(k, "Head", f"Nape{i}", (x * 0.9, 0.76, 5.0), (x, 0.87, z), r, flat=0.25, twist=0.2 + 0.15 * i, a=0.46)
	# the bangs: a jagged fringe over the brow, the middle lock longest and pushed off centre
	root = (0, -0.8, 5.74)
	gem(k, "Head", "BangOuter1", (0.62, -0.84, 5.56), (0.96, -0.9, 5.08), 0.22, flat=0.4, twist=0.2, a=0.5, across=(0, 0, 1))
	gem(k, "Head", "BangOuter-1", (-0.62, -0.84, 5.56), (-0.98, -0.9, 5.14), 0.22, flat=0.4, twist=0.3, a=0.5, across=(0, 0, 1))
	for i, (t, r) in enumerate((((-0.74, -0.94, 5.04), 0.25), ((-0.42, -0.95, 4.98), 0.25), ((-0.06, -0.97, 4.86), 0.2), ((0.3, -0.95, 5.0), 0.25), ((0.68, -0.94, 5.06), 0.25))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.52, across=(0, 0, 1))
	# big spikes: up and out from the crown, the outline of the character
	for i, (b, t, r) in enumerate(
		(
			((-0.56, -0.72, 5.56), (-0.82, -0.92, 6.46), 0.32),
			((-0.04, -0.74, 5.6), (-0.1, -0.96, 6.64), 0.34),
			((0.52, -0.72, 5.56), (0.72, -0.9, 6.34), 0.32),
			((-0.34, 0, 6.05), (-0.6, -0.1, 6.98), 0.32),
			((0.3, 0, 6.05), (0.42, -0.1, 6.78), 0.32),
			((0, 0.3, 6.05), (0.02, 0.34, 6.92), 0.32),
			((-0.7, -0.1, 5.75), (-1.44, -0.2, 6.3), 0.34),
			((0.7, -0.1, 5.75), (1.32, -0.16, 6.52), 0.34),
			((-0.7, 0.35, 5.7), (-1.34, 0.45, 6.2), 0.32),
			((0.7, 0.35, 5.7), (1.34, 0.42, 6.22), 0.32),
			((-0.4, 0.6, 5.75), (-0.64, 1.1, 6.38), 0.32),
			((0.4, 0.6, 5.75), (0.66, 1.08, 6.34), 0.32),
			((0, 0.7, 5.6), (0.02, 1.18, 6.06), 0.34),
			((-0.6, 0.7, 5.4), (-0.92, 1.1, 5.52), 0.3),
			((0.6, 0.7, 5.4), (0.94, 1.1, 5.48), 0.3),
		)
	):
		gem(k, "Head", f"Spike{i}", b, t, r, flat=0.55, twist=0.3, a=0.52)


def _robe(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	# the crossed collar: white under-robe inside, black robe outside, his left side over his right
	for s in (1, -1):
		apex = -0.14 if s > 0 else 0.0
		prism(k, t, f"Under{s}", [(s * 0.56, 4.0), (s * 0.74, 4.0), (apex + s * 0.12, 2.86), (apex, 2.98)], -0.6, -0.56, "white", a=0.6, b=0.3)
		prism(k, t, f"Lapel{s}", [(s * 0.74, 4.0), (s * 0.94, 4.0), (apex + s * 0.2, 2.76), (apex + s * 0.12, 2.86)], -0.615, -0.56, "robe", a=0.56, b=0.42)
	block(k, t, "CollarBack", 0, 0.36, 4.18, 3.92, 0.78, 0.2, "robe", ch=0.04, a=0.54, b=0.5)
	block(k, t, "CollarWhite", 0, 0.24, 4.2, 4.0, 0.62, 0.06, "white", ch=0.02, a=0.62, b=0.3)
	# the white sash, knotted at the front on his left
	block(k, t, "Sash", 0, 0, 2.52, 2.24, 1.1, 0.625, "white", ch=0.03, corner=0.14, sub=1, a=0.56, b=0.34)
	block(k, t, "Knot", 0.34, -0.66, 2.56, 2.2, 0.17, 0.06, "white", ch=0.03, a=0.64, b=0.34)


def _strap(k):
	"""The thin red strap: over his right shoulder, down across the chest to his left hip, back up behind to the blade's holder."""
	t = "UpperTorso"
	w = 0.1
	sx, sz, hx, hz = -0.86, 3.98, 1.1, 2.56
	band = [(sx - w, sz), (sx + w, sz), (hx + w * 0.3, hz + w), (hx - w * 0.3, hz - w)]
	prism(k, t, "StrapFront", band, -0.665, -0.625, "red", a=0.5, b=0.4)
	prism(k, t, "StrapBack", band, 0.58, 0.62, "red", a=0.5, b=0.4)
	block(k, t, "StrapTop", sx, -0.02, 4.05, 3.97, w, 0.66, "red", ch=0.015, a=0.56, b=0.4)
	block(k, t, "StrapHip", hx + 0.01, -0.02, hz + 0.11, hz - 0.11, 0.04, 0.665, "red", ch=0.01, a=0.5, b=0.4)
	block(k, t, "Holder", 0, 0.7, 3.48, 3.22, 0.12, 0.13, "red", ch=0.02, a=0.46, b=0.4)
	_badge(k, 0.42, -0.665, 3.0)


def _badge(k, cx, y, cz):
	"""The badge, changed: an upright diamond plate carrying a crescent, where the source's plaque and skull would sit."""
	t = "UpperTorso"
	prism(k, t, "BadgeTie", [(cx - 0.025, cz + 0.2), (cx + 0.025, cz + 0.2), (cx + 0.025, cz + 0.14), (cx - 0.025, cz + 0.14)], y - 0.02, y + 0.02, "red", a=0.5)
	prism(k, t, "Badge", [(cx, cz + 0.2), (cx + 0.17, cz), (cx, cz - 0.21), (cx - 0.17, cz)], y - 0.045, y, "wood", a=0.5, b=0.4)
	crescent = [(cx + 0.03, cz + 0.11), (cx - 0.075, cz + 0.04), (cx - 0.075, cz - 0.05), (cx + 0.03, cz - 0.12), (cx - 0.015, cz - 0.04), (cx - 0.015, cz + 0.03)]
	prism(k, t, "BadgeMoon", crescent, y - 0.062, y - 0.045, "woodl", a=0.62, b=0.3)


def _blade(k):
	t = "UpperTorso"
	th = 0.058
	heel = 1.05
	# spine and body in black, the bevelled edge in steel; the end slopes to a point on the edge side like a cleaver
	rows = ((heel, heel, heel), (4.3, 4.85, 5.415))
	spine = [[_sw(u0, -0.62, -th), _sw(u1, 0.12, -th), _sw(u1, 0.12, th), _sw(u0, -0.62, th)] for u0, u1, _ in rows]
	_loft_mesh(k, t, "BladeBody", spine, "spine", a=0.46, b=0.5)
	edge = [[_sw(u1, 0.12, -th), _sw(u2, 0.62, 0), _sw(u1, 0.12, th)] for _, u1, u2 in rows]
	_loft_mesh(k, t, "BladeEdge", edge, "steel", a=0.56, b=0.42)


def _tang(k):
	t = "UpperTorso"
	v0, hw = -0.05, 0.13
	sec = lambda u, g=0.0: [_sw(u, v0 - hw - g, -0.05 - g), _sw(u, v0 + hw + g, -0.05 - g), _sw(u, v0 + hw + g, 0.05 + g), _sw(u, v0 - hw - g, 0.05 + g)]
	_loft_mesh(k, t, "Tang", [sec(0.02), sec(1.1)], "tang", a=0.5, b=0.4)
	# the cloth wrap: overlapping slanted turns, so it reads as bandage at distance
	for i in range(7):
		u = 0.06 + i * 0.15
		wrap = [[_sw(u + du + 0.05 * sv, v0 + sv * (hw + 0.03), sd * (0.05 + 0.03)) for sv, sd in ((-1, -1), (1, -1), (1, 1), (-1, 1))] for du in (0.0, 0.14)]
		_loft_mesh(k, t, f"Wrap{i}", wrap, "cloth", a=0.58 + 0.04 * (i % 2), b=0.34)
	# the loose end: falls from the tang's top behind his right arm
	path = [(-1.42, 1.06, 5.42), (-1.62, 1.12, 5.2), (-1.82, 1.16, 4.82), (-1.8, 1.2, 4.36), (-1.94, 1.22, 3.92)]
	rings = []
	for i, (x, y, z) in enumerate(path):
		w = 0.105 - 0.012 * i
		rings.append([(x - w, y - 0.018, z), (x + w, y - 0.018, z + 0.03), (x + w, y + 0.018, z + 0.03), (x - w, y + 0.018, z)])
	_loft_mesh(k, t, "WrapTail", rings, "cloth", a=0.56, b=0.36)
	# one turn round the blade just below the heel, the wrap's other end
	band = [[_sw(1.14 + du + 0.03 * v, v, -0.09 if s else 0.09) for v, s in ((-0.65, 0), (0.65, 0), (0.65, 1), (-0.65, 1))] for du in (0.0, 0.16)]
	_loft_mesh(k, t, "BladeBand", band, "cloth", a=0.6, b=0.34)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="robe", cuff=2.3)
	# the wide mouth of the robe sleeve
	block(k, f"{side}UpperArm", "Mouth", s * 1.5, 0.03, 2.62, 2.28, 0.535, 0.64, "robe", ch=0.04, corner=0.18, a=0.46, b=0.56)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.49, 0.56, "hakama", ch=0.04, flare=0.02, corner=0.16, jit=0.03, mids=(1.55,), a=0.5, b=0.62, tone=0.05)
	block(k, leg, "Shin", px, 0, 1.18, 0.38, 0.51, 0.59, "hakama", ch=0.04, flare=0.015, corner=0.16, jit=0.03, mids=(0.74,), a=0.5, b=0.62, tone=0.05)
	# pressed pleats down the front
	for i, dx in enumerate((-0.2, 0.12)):
		block(k, leg, f"Pleat{i}", px + s * dx, -0.6, 1.92, 0.5, 0.018, 0.016, "spine", ch=0.005, a=0.34, b=0.2)
	# white split sock and straw sandal: no boot, the sock shows above the sole
	dress_shoe(k, leg, px, top=0.42)
	block(k, leg, "Thong", px, -0.56, 0.3, 0.13, 0.04, 0.2, "wood", ch=0.01, a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.66)
	_hair(k)
	_robe(k)
	_strap(k)
	_blade(k)
	_tang(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=6):
	"""A cloth fold on black: a soft lit ridge, no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=BLACK_L, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(BLACK)
	# the open V: skin, the shadow its collars throw; the white under-robe and the black lapels are real meshes over it
	f.path("M34 -5H166L100 112Z", SKIN)
	f.soft("M34 -5H166V12H34Z", SKIN_D, 0.85, 3)
	f.soft("M34 -5L100 112V92L54 -5Z", SKIN_D, 0.5, 2)
	f.soft("M166 -5L100 112V92L146 -5Z", SKIN_D, 0.6, 2)
	# collar bones and the top of the chest
	f.path("M62 18Q80 26 96 24", stroke=SKIN_D, sw=1.8, opacity=0.8)
	f.path("M138 18Q120 26 104 24", stroke=SKIN_D, sw=1.8, opacity=0.8)
	# the robe's overlap running on down towards the sash
	stroke(f, "M92 118L78 134", BLACK_D, 2.4, 0.9)
	_fold(f, 16, 44, 40, 82, 70, 118)
	_fold(f, 184, 46, 160, 84, 126, 120)
	_fold(f, 26, 118, 34, 128, 26, 138, 0.4, 5)
	_fold(f, 174, 120, 164, 130, 172, 140, 0.4, 5)
	# below the sash: the skirt's pleats begin here
	for x in (36, 66, 134, 164):
		stroke(f, f"M{x} 160V205", BLACK_D, 2.6, 0.9)
	f.path("M100 170L90 205H110Z", BLACK_D, opacity=0.9)
	form(f, "#030306", 0.55)
	f = a["Torso_B"]
	f.fill(BLACK)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	for x in (40, 72, 128, 160):
		stroke(f, f"M{x} 158V205", BLACK_D, 2.6, 0.9)
	form(f, "#030306", 0.55)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(BLACK)
		_fold(f, 20, 40, 34, 90, 26, 130, 0.4, 5)
		form(f, "#030306", 0.55)
	a["Torso_T"].fill(BLACK)
	a["Torso_Bo"].fill(BLACK_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(BLACK)
			a[f"{side}Leg_{key}"].fill(shade(BLACK, 0.9))
		a[f"{side}Arm_T"].fill(BLACK)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(BLACK)
		a[f"{side}Leg_Bo"].fill(BLACK_D)


def _face(f):
	f.fill(SKIN)
	f.path("M-5-5H135V27L116 21L100 30L84 23L66 33L46 23L30 30L14 21L-5 27Z", HAIR_MID)
	f.soft("M-5 22L30 34L66 38L100 34L135 22V36Q65 46 -5 36Z", SKIN_D, 0.7, 2)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	for cx, s in ((39, -1), (91, 1)):
		eye2(f, cx, 64, s, 35, 15, "#6a3d1c", tilt=2.6, r=9.8, lid=0.28, lash="#1c1210", lash_t=3.2, flick=2, pupil=0.42, sclera="#f6f2ea", crease_line=False)
		# the scowl: heavy brows pulled down hard towards the nose
		brow2(f, cx, 47, s, 36, 7.4, 5.6, "#c4560e")
	# the crease the scowl leaves between the brows
	stroke(f, "M61 44L63 53", SKIN_D, 1.5, 0.95)
	stroke(f, "M69 44L67 53", SKIN_D, 1.5, 0.95)
	nose(f, SKIN, y=74, h=13)
	# a flat hard mouth, turned down at the corners
	f.path("M50 106Q65 101 80 106", stroke="#3a1a14", sw=2.2)
	f.path("M56 113Q65 115 74 113", stroke=SKIN_D, sw=1.2, opacity=0.9)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	for n in ("Head_L", "Head_R"):
		a[n].path("M-5-5H125V32H-5Z", HAIR_MID)
	a["Head_T"].fill(HAIR_D)
	_torso(a)
	_limbs(a)
