# Target look for foe_ds, Akazo (design doc section 5, 4.26): short spiky pink hair, pale bare skin ringed in thick blue lines,
# gold eyes on blue whites with an invented glyph in each iris, a cropped open sleeveless light purple coat, white baggy trousers
# rolled below the knee, a blue sash with red tassels, bare feet with blue toes and bead ankle strings, blue-ended block hands.
# +X is the viewer's right in the front view.
from ds_style3 import art_uv, bake, block, cap, eye, gem, jitter, rect_d, skin_head, spread, studs
from jk_style3 import prism
from leaf_common import ell
from style2 import Kit, Ramps, face
from style3 import big_head, finish

SKIN = "#f7e4d8"
SKIN_D = "#d9b6aa"
BLUE = "#2358c8"
VEST = "#b468bc"
VEST_D = "#7d3f8c"
DEFAULT = SKIN
R = Ramps(
	hair=["#9c2f5c", "#c94a7e", "#ee78a3", "#f99cc0", "#ffc8dc"],
	skin=["#c9a294", "#e8cabc", "#f7e4d8", "#fff4ec"],
	vest=["#57286a", "#8a4496", "#b468bc", "#d48fd6"],
	trim=["#3e1c50", "#5f2c72", "#7d3f8c", "#9c58a8"],
	white=["#8f93a4", "#c9ccd8", "#eceef4", "#ffffff"],
	sash=["#12306e", "#1d4698", "#2358c8", "#4a80e4"],
	red=["#6e0e14", "#a81a20", "#d42c2c", "#f05a4e"],
	bead=["#7a1438", "#b0225a", "#dc3c78", "#f47aa4"],
	blue=["#12306e", "#1d4698", "#2c62d0", "#5a8ee8"],
)
HAIR = {"colour": "#EE78A3", "locks": []}
PROPS = []
BACK = (-1.1, 1.1, 2.5, 4.1)  # the coat's back swatch, in the torso back face that the coat hides
HEM = 2.52


def _hair(k):
	cap(k, band_z=5.22, side_z=4.72, back_y=-0.1)
	root = (0, 0.1, 5.5)
	up = (((-1.26, -0.1, 5.76), 0.42), ((-1.0, -0.26, 6.24), 0.46), ((-0.46, -0.32, 6.5), 0.48), ((0.1, -0.3, 6.58), 0.48), ((0.62, -0.26, 6.42), 0.46), ((1.1, -0.14, 6.1), 0.44), ((1.3, 0.0, 5.64), 0.4), ((-1.0, 0.56, 6.2), 0.48), ((-0.3, 0.76, 6.5), 0.5), ((0.4, 0.76, 6.46), 0.5), ((1.02, 0.56, 6.14), 0.48), ((-1.3, 0.6, 5.54), 0.44), ((1.32, 0.6, 5.5), 0.44), ((-0.7, 1.22, 5.84), 0.46), ((0.7, 1.22, 5.84), 0.46), ((0.08, 1.24, 5.34), 0.46))
	for i, (t, r) in enumerate(up):
		gem(k, "Head", f"Up{i}", spread(root, t, 0.25), t, r, flat=0.72, bend=0.06, twist=0.3 + 0.13 * i % 0.5)
	# heavy chunks falling off the crown over the hairline, so no band or dome shows from the front
	for i, (x, tx, z, r) in enumerate(((-0.72, -1.02, 5.3, 0.36), (-0.34, -0.5, 5.32, 0.36), (0.02, 0.04, 5.46, 0.34), (0.38, 0.54, 5.3, 0.36), (0.74, 1.04, 5.28, 0.36))):
		gem(k, "Head", f"Fall{i}", (x * 0.6, -0.1, 6.22), (tx, -0.98, z), r, flat=0.6, bend=0.14, twist=0.2 + 0.11 * i, across=(1, 0, 0))
	for i, (x, tz, r) in enumerate(((-0.6, 6.02, 0.3), (-0.2, 6.26, 0.32), (0.26, 6.2, 0.32), (0.66, 5.98, 0.3))):
		gem(k, "Head", f"Rise{i}", (x * 0.8, -0.55, 5.62), (x * 1.12, -0.8, tz), r, flat=0.55, twist=0.25, across=(1, 0, 0))
	# jagged forelocks to the brow, parted so the centre line shows
	for i, (x, z, r) in enumerate(((-0.72, 4.84, 0.28), (-0.38, 4.98, 0.27), (-0.14, 5.1, 0.17), (0.14, 5.12, 0.17), (0.4, 4.96, 0.27), (0.72, 4.86, 0.28))):
		gem(k, "Head", f"Bang{i}", (x * 0.92, -0.66, 5.68), (x * 1.04, -0.97, z), r, flat=0.5, twist=0.22, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"Burn{s}", (s * 0.9, -0.5, 5.3), (s * 1.0, -0.62, 4.56), 0.2, flat=0.55, twist=0.2, across=(0, 1, 0))
		gem(k, "Head", f"Side{s}", (s * 0.92, 0.12, 5.3), (s * 1.22, 0.2, 4.46), 0.34, flat=0.42, twist=0.3, across=(0, 1, 0))
	for i, x in enumerate((-0.68, -0.23, 0.23, 0.68)):
		gem(k, "Head", f"Back{i}", (x, 0.72, 5.1), (x * 1.14, 1.08, 4.14 + 0.12 * (i % 2)), 0.4, flat=0.5, twist=0.3, across=(1, 0, 0))


def _top(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 4.0, 0.95, 0.46), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.04, 1.0, 0.5), (0, 0, 2.0, 0.95, 0.46)], corner=0.1, nc=1)
	block(k, t, "Coat", 0, 0.2, 4.05, HEM, 1.05, 0.42, "vest", ch=0.05, jit=0.012, a=0.46, b=0.56, g=0.1)
	art_uv(block(k, t, "CoatBack", 0, 0.63, 3.98, HEM + 0.05, 1.0, 0.03, "vest", ch=0.012), "Torso_B", BACK)
	for s, n in ((1, "L"), (-1, "R")):
		prism(k, t, f"Panel{n}", [(s * 1.05, 4.05), (s * 0.34, 4.05), (s * 0.62, HEM), (s * 1.05, HEM)], -0.61, -0.1, "vest", a=0.46, b=0.56, g=0.1)
		prism(k, t, f"Lapel{n}", [(s * 0.5, 4.06), (s * 0.3, 4.06), (s * 0.58, HEM), (s * 0.76, HEM)], -0.645, -0.59, "trim", a=0.56, b=0.5)
		prism(k, t, f"Fold{n}", [(s * 0.76, 4.06), (s * 0.34, 4.06), (s * 0.34, 3.98), (s * 0.76, 3.98)], -0.645, 0.2, "trim", a=0.56, b=0.5)
	block(k, t, "PantsTop", 0, 0, 2.46, 1.94, 1.04, 0.55, "white", ch=0.04, a=0.38, b=0.4, g=0.1)
	block(k, t, "Sash", 0, 0, HEM - 0.02, 2.24, 1.075, 0.585, "sash", ch=0.03, a=0.5, b=0.5)
	block(k, t, "Knot", 0.34, -0.63, 2.48, 2.22, 0.16, 0.06, "sash", ch=0.03, a=0.58, b=0.42)
	for i, (x, z) in enumerate(((0.26, 1.72), (0.46, 1.82))):
		gem(k, t, f"Tie{i}", (0.34, -0.63, 2.34), (x, -0.66, z), 0.08, "sash", flat=0.5, twist=0.2, a=0.54, b_=0.4, across=(1, 0, 0))
		gem(k, t, f"Tassel{i}", (x, -0.66, z + 0.1), (x, -0.68, z - 0.38), 0.11, "red", flat=0.7, twist=0.25, a=0.56, b_=0.4, across=(1, 0, 0))


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 4.0, 0.44, 0.44), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 2.04, 0.5, 0.5), (ax, 0, 2.0, 0.44, 0.44)], corner=0.12, nc=1)
	block(k, arm, "Hand", ax, 0, 2.5, 2.04, 0.5, 0.5, "skin", ch=0.05, a=0.6, b=0.32)
	block(k, arm, "HandEnd", ax, 0, 2.1, 1.78, 0.5, 0.5, "blue", ch=0.05, a=0.56, b=0.36)


def _leg(k, side, s):
	leg, px, cx = f"{side}UpperLeg", s * 0.53, s * 0.58
	k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.46, 0.46), (s * 0.5, 0, 1.94, 0.5, 0.5), (s * 0.5, 0, 0.1, 0.5, 0.5)], corner=0.1, nc=1)
	# baggy to the knee, gathered into a rolled cuff just under it
	o = k.tube(leg, "Pants", [(cx, 0, 1.96, 0.5, 0.52), (cx, 0, 1.9, 0.54, 0.56), (cx, 0, 1.4, 0.6, 0.64), (cx, 0, 1.12, 0.61, 0.66), (cx, 0, 0.96, 0.56, 0.61)], "white", corner=0.16, nc=1, sub=1, outline=0)
	jitter(o, 0.03)
	bake(k, o, "white", a=0.38, b=0.4, g=0.12, tone=0.06)
	block(k, leg, "Cuff", px, 0, 1.0, 0.82, 0.54, 0.57, "white", ch=0.04, a=0.44, b=0.38)
	block(k, leg, "Foot", px, -0.06, 0.38, 0.0, 0.48, 0.54, "skin", ch=0.05, a=0.56, b=0.36)
	block(k, leg, "Forefoot", px, -0.5, 0.24, 0.0, 0.47, 0.2, "skin", ch=0.04, a=0.56, b=0.36)
	for i, dx in enumerate((-0.345, -0.115, 0.115, 0.345)):
		block(k, leg, f"Toe{i}", px + dx, -0.72, 0.2, 0.0, 0.105, 0.09, "blue", ch=0.03, corner=0.25, a=0.58, b=0.34)
	# the ankle string, half sunk in the shin's skin
	x, r, z = s * 0.5, 0.5, 0.5
	ring = [(x - r + 2 * r * i / 4, -r) for i in range(4)] + [(x + r, -r + 2 * r * i / 4) for i in range(4)] + [(x + r - 2 * r * i / 4, r) for i in range(4)] + [(x - r, r - 2 * r * i / 4) for i in range(4)]
	for i, (bx, by) in enumerate(ring):
		bake(k, k.blob(leg, f"Bead{i}", (bx, by, z), (0.12, 0.12, 0.12), "bead", rings=3, n=8, outline=0), "bead", a=0.56, b=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _line(f, d, sw=5):
	f.path(d, stroke=BLUE, sw=sw)


def _glyph(f, x, y, s):
	"""Invented, not a real character: a kite with a tail in one iris, two stacked hooks in the other. Same place and colour as the source's iris writing."""
	if s < 0:
		f.path(f"M{x - 5} {y - 6}L{x} {y - 2}L{x + 5} {y - 6}L{x + 3} {y + 2}L{x} {y + 8}L{x - 3} {y + 2}Z", "none", stroke="#1c0a30", sw=1.5)
	else:
		f.path(f"M{x - 6} {y - 7}L{x + 5} {y - 7}L{x + 1} {y - 1}M{x - 6} {y}L{x + 5} {y}L{x + 1} {y + 6}M{x - 4} {y + 8}L{x + 3} {y + 8}", "none", stroke="#1c0a30", sw=1.5)


def _face(f):
	face(f, SKIN, hairline=20, nose_y=88, shadow=SKIN_D)
	f.path("M-5-5H135V18L110 22L88 16L65 22L42 16L20 22L-5 18Z", "#c94a7e")
	f.soft("M-5 30H10Q8 90 24 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H120Q122 90 106 135H135Z", SKIN_D, 0.75, 5)
	# the forehead line, running down to the bridge of the nose
	f.path("M61 -2H69L66.5 66H63.5Z", BLUE)
	for s, x in ((-1, 37), (1, 93)):
		c = lambda d: 65 + s * d
		# three curved lines each side, sweeping out from the eye to the edge of the face
		_line(f, f"M{c(16)} 46Q{c(42)} 38 {c(70)} 42", 4.2)
		_line(f, f"M{c(42)} 62Q{c(56)} 58 {c(70)} 62", 4.2)
		_line(f, f"M{c(14)} 82Q{c(42)} 92 {c(70)} 80", 4.2)
		eye(f, x, 64, s, ("#a87a0a", "#f2c81e", "#ffe96a"), w=34, up=13, dn=11, inner=4, outer=-5, ir=(10.5, 13), pu=(0.1, 0.1), lash="#d64a86", wing=4, thick=0.8, white="#8fc0ee", lid=0.2)
		_glyph(f, x - s, 64, s)
		# thin pink brow, angled down to the nose
		f.path(f"M{c(8)} 47L{c(44)} 36L{c(44)} 39L{c(10)} 50Z", "#d64a86")
	# a closed smirk with one fang showing
	f.path("M48 105Q66 112 84 102", "none", stroke="#6a3030", sw=1.8)
	f.path("M72 107L77 106L74.5 113Z", "#fbf7f2", stroke="#6a3030", sw=0.7)


def _rings(f, ys, dip=7, sw=5):
	"""Every limb face takes the same heights, so each line closes round the limb; each dips to a point mid face."""
	for y in ys:
		_line(f, f"M-5 {y}Q28 {y + dip * 0.2} 50 {y + dip}Q72 {y + dip * 0.2} 105 {y}", sw)


def _back(f):
	"""Rows of lozenges on the coat's back: the source's squares reshaped, same place and colours."""
	studs(f, BACK)
	f.path(rect_d(-2, 2, 2, 5), VEST)
	cw, ch = 0.3, 0.3
	for j in range(0, 7):
		for i in range(-4, 5):
			x, z = i * cw * 1.25 + (cw * 0.62 if j % 2 else 0), 2.72 + j * ch * 0.78
			f.path(f"M{x:.3f} {z - ch * 0.34:.3f}L{x + cw * 0.46:.3f} {z:.3f}L{x:.3f} {z + ch * 0.34:.3f}L{x - cw * 0.46:.3f} {z:.3f}Z", VEST_D)
	f.out.append("</g>")
	f.soft("M-5 170H205V205H-5Z", "#3e1c50", 0.35, 5)
	f.edges(0.22)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	skin_head(a, SKIN, SKIN_D)
	# the side of the head: the face lines run on past the corner, then a plain ear
	for n, x0, x1, ex in (("Head_L", -5, 40, 64), ("Head_R", 125, 80, 56)):
		f = a[n]
		for y in (62, 80):
			_line(f, f"M{x0} {y}Q{(x0 + x1) / 2} {y + 2} {x1} {y - 4}", 4.2)
		f.path(ell(ex, 76, 9, 13), SKIN, stroke=SKIN_D, sw=1.6)
		f.path(ell(ex, 76, 4, 7), SKIN_D)
	f = a["Torso_F"]
	f.fill(SKIN)
	f.soft("M-5 150H205V205H-5Z", SKIN_D, 0.45, 5)
	_line(f, "M100 2V150", 5.5)
	for y, drop in ((24, 18), (52, 22), (82, 14), (108, 10), (132, 6)):
		_line(f, f"M100 {y + drop}Q62 {y + drop * 0.4} 20 {y}M100 {y + drop}Q138 {y + drop * 0.4} 180 {y}", 5.5)
	for n in ("Torso_L", "Torso_R", "Torso_Bo"):
		a[n].fill(SKIN)
	a["Torso_T"].fill(VEST)
	_back(a["Torso_B"])
	for side in ("Left", "Right"):
		for fc in "FBOI":
			f = a[f"{side}Arm_{fc}"]
			f.fill(SKIN)
			f.soft("M-5 130H105V210H-5Z", SKIN_D, 0.35, 5)
			_rings(f, (14, 32, 78, 96, 114, 134))
			f = a[f"{side}Leg_{fc}"]
			f.fill(SKIN)
			f.soft("M-5 150H105V205H-5Z", SKIN_D, 0.4, 3)
			_rings(f, (112, 126), 4, 4.2)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(SKIN)
		a[f"{side}Leg_Bo"].fill(SKIN_D)
