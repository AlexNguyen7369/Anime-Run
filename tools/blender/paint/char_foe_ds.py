# Target look for foe_ds, Akazo (design doc section 5, 4.26): a short puff of chunky rose hair, pale green-white skin under thick
# navy lines, gold eyes on blue whites with an invented glyph in each iris, a wide grin; a cropped open sleeveless plum coat, baggy
# white trousers gathered below the knee, a teal cord with a rose knot and red tassels, bare feet with navy toes, red bead anklets.
# Evidence: docs/char_evidence/foe_ds.md. +X is the viewer's right in the front view.
import math

from ds_style3 import art_uv, bake, block, cap, eye, gem, jitter, stroke, studs
from jk_style3 import prism
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#e4e8d6"
SKIN_D = "#aebba8"
SKIN_L = "#f6f8e8"
MUSCLE = "#98a894"
NAVY = "#222f78"
VEST = "#aa5a8e"
VEST_D = "#6e2f5e"
CLOTH = "#eef0f8"
CLOTH_D = "#adb0d2"
DEFAULT = SKIN
R = Ramps(
	hair=["#6a1238", "#96204f", "#c23468", "#dc4e84", "#ee70a0"],
	tip=["#a02860", "#c84478", "#e4608e", "#f48aae"],
	skin=["#a2af9e", "#cbd3bf", "#e4e8d6", "#f6f8e8"],
	vest=["#54224a", "#84407a", "#aa5a8e", "#c67aaa"],
	trim=["#2e1230", "#4a1c44", "#6e2f5e", "#8a4476"],
	white=["#8e91b4", "#c6c8e0", "#eef0f8", "#ffffff"],
	sash=["#0e5a5c", "#16878a", "#25b0ae", "#62d8d0"],
	knot=["#7a1c48", "#b02c64", "#d84a84", "#f27aa8"],
	red=["#6e0e14", "#a81a20", "#d42c2c", "#f05a4e"],
	bead=["#6a0a14", "#a81422", "#d6242e", "#ff7a70"],
	blue=["#121a4c", "#1a2564", "#222f78", "#3c4c9c"],
	nail=["#9c3a08", "#d85c10", "#f47a1c", "#ff9c48"],
)
HAIR = {"colour": "#DE5C90", "locks": []}
PROPS = []
HEM = 2.46
COAT = (-1.1, 1.1, 2.4, 4.1)  # the coat's painted cloth lives in Torso_L, its back in Torso_B: the coat hides both faces
TROUSER = (-0.75, 0.75, 0, 2)  # stud rectangle of the trouser art inside a leg's front face
WAIST = (-1.1, 1.1, 1.9, 2.5)  # the trouser top's cloth lives in Torso_Bo, which nothing shows


def _tufts(k, tag, n, phase, rad, z, r, f=0.38, gap=0.0):
	"""A ring of short fat clumps; lengths and heights step unevenly so the outline stays tousled. gap leaves the face's arc open."""
	root = (0, 0.08, 5.55)
	for i in range(n):
		a = phase + 2 * math.pi * i / n
		if gap and abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < gap:
			continue
		d = rad + ((i * 5) % 3 - 1) * 0.07
		fall = max(0.0, -math.sin(a))  # clumps over the face fall forward and down instead of pointing at the viewer
		t = (math.cos(a) * d, 0.08 + math.sin(a) * d * (0.96 - 0.26 * fall), z + ((i * 7) % 3 - 1) * 0.09 - 0.3 * fall)
		b = tuple(root[j] + (t[j] - root[j]) * f for j in range(3))
		gem(k, "Head", f"{tag}{i}", b, t, r, tip="tip", split=0.74, flat=0.72, bend=0.08, twist=0.3 + 0.13 * i % 0.5, b_=0.74)


def _hair(k):
	cap(k, band_z=5.24, side_z=4.92, back_y=0.16)
	_tufts(k, "Crown", 5, 0.4, 0.44, 6.62, 0.42, f=0.45)
	_tufts(k, "Upper", 10, 0.15, 1.0, 6.3, 0.42)
	_tufts(k, "Mid", 13, 0.0, 1.44, 5.88, 0.4)
	_tufts(k, "Low", 11, 0.3, 1.4, 5.34, 0.38, gap=0.72)
	# short forelocks on the hairline, parted a little at the centre so the forehead lines show
	for i, (x, z, r) in enumerate(((-0.8, 5.2, 0.28), (-0.48, 5.14, 0.3), (-0.17, 5.26, 0.24), (0.13, 5.28, 0.24), (0.44, 5.14, 0.3), (0.78, 5.18, 0.28))):
		gem(k, "Head", f"Fore{i}", (x * 0.86, -0.56, 5.84), (x * 1.05, -1.0, z), r, tip="tip", split=0.72, flat=0.58, twist=0.22, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"Burn{s}", (s * 0.88, -0.46, 5.42), (s * 1.0, -0.58, 4.86), 0.2, tip="tip", flat=0.6, twist=0.2, across=(0, 1, 0))
		for i, (y, z) in enumerate(((-0.3, 4.94), (0.02, 4.84), (0.38, 4.72))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.94, y, 5.46), (s * 1.12, y + 0.04, z), 0.27, tip="tip", flat=0.5, twist=0.3, across=(0, 1, 0))
	# a short nape: the hair stops above the neck
	for i, x in enumerate((-0.72, -0.36, 0.0, 0.36, 0.72)):
		gem(k, "Head", f"Nape{i}", (x * 0.9, 0.7, 5.3), (x * 1.08, 1.04, 4.46 + 0.09 * (i % 2)), 0.34, tip="tip", flat=0.55, twist=0.3, across=(1, 0, 0))


def _top(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 4.0, 0.95, 0.46), (0, 0, 3.94, 1.0, 0.5), (0, 0, 2.04, 1.0, 0.5), (0, 0, 2.0, 0.95, 0.46)], corner=0.1, nc=1)
	art_uv(block(k, t, "CoatBody", 0, 0.2, 4.06, HEM, 1.06, 0.42, "vest", ch=0.05, jit=0.012), "Torso_L", COAT)
	art_uv(block(k, t, "CoatBack", 0, 0.63, 3.98, HEM + 0.05, 1.0, 0.03, "vest", ch=0.012), "Torso_B", COAT)
	block(k, t, "Yoke", 0, 0.2, 4.13, 3.96, 1.0, 0.45, "trim", ch=0.04, a=0.5, b=0.5)
	for s, n in ((1, "L"), (-1, "R")):
		art_uv(prism(k, t, f"Panel{n}", [(s * 1.06, 4.06), (s * 0.56, 4.06), (s * 0.78, HEM - 0.12), (s * 1.06, HEM)], -0.6, -0.1, "vest"), "Torso_L", COAT)
		# the turned-back front edge, showing the dark lining
		prism(k, t, f"Lapel{n}", [(s * 0.74, 4.08), (s * 0.54, 4.08), (s * 0.76, HEM - 0.13), (s * 0.94, HEM - 0.05)], -0.64, -0.59, "trim", a=0.5, b=0.5)
		# the sleeveless armhole's edge sits over the top of the arm
		art_uv(block(k, t, f"Armhole{n}", s * 1.08, 0.02, 4.12, 3.56, 0.13, 0.56, "vest", ch=0.04, jit=0.01), "Torso_L", COAT)
	art_uv(block(k, t, "PantsTop", 0, 0, 2.42, 1.94, 1.05, 0.56, "white", ch=0.04), "Torso_Bo", WAIST)
	block(k, t, "Cord", 0, 0, 2.42, 2.28, 1.075, 0.585, "sash", ch=0.03, a=0.5, b=0.5)
	block(k, t, "Knot", 0.1, -0.63, 2.46, 2.24, 0.16, 0.08, "knot", ch=0.05, corner=0.5, a=0.56, b=0.46)
	for i, x in enumerate((-0.16, 0.34)):
		block(k, t, f"Tie{i}", x, -0.625, 2.3, 1.92, 0.035, 0.03, "sash", ch=0.01, a=0.5, b=0.5)
		block(k, t, f"TieKnot{i}", x, -0.625, 1.98, 1.86, 0.075, 0.06, "sash", ch=0.025, corner=0.4, a=0.56, b=0.42)
		for j, dx in enumerate((-0.07, 0.07, 0.0)):
			gem(k, t, f"Tassel{i}{j}", (x, -0.63, 1.9), (x + dx, -0.66, 1.44 - 0.05 * j), 0.075, "red", flat=0.7, twist=0.25, a=0.56, b_=0.4, across=(1, 0, 0))


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 4.0, 0.44, 0.44), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 2.04, 0.5, 0.5), (ax, 0, 2.0, 0.44, 0.44)], corner=0.12, nc=1)
	# plain blocks, no fingers: only the colours of the source's hand, navy with orange nail marks
	block(k, arm, "Hand", ax, 0, 2.28, 2.0, 0.5, 0.5, "skin", ch=0.05, a=0.6, b=0.32)
	block(k, arm, "HandEnd", ax, 0, 2.06, 1.78, 0.5, 0.5, "blue", ch=0.05, a=0.56, b=0.36)
	for i, dx in enumerate((-0.33, -0.11, 0.11, 0.33)):
		block(k, arm, f"Nail{i}", ax + dx, -0.505, 1.92, 1.82, 0.07, 0.012, "nail", ch=0.004, a=0.6, b=0.3)


def _leg(k, side, s):
	leg, px, cx = f"{side}UpperLeg", s * 0.53, s * 0.58
	k.reshape(leg, f"{side}Leg", [(s * 0.5, 0, 2.0, 0.46, 0.46), (s * 0.5, 0, 1.94, 0.5, 0.5), (s * 0.5, 0, 0.1, 0.5, 0.5)], corner=0.1, nc=1)
	# baggy to the knee, gathered into a rolled cuff just under it; folds are painted in the leg's front face
	o = k.tube(leg, "Pants", [(cx, 0, 1.96, 0.5, 0.52), (cx, 0, 1.9, 0.54, 0.56), (cx, 0, 1.46, 0.62, 0.66), (cx, 0, 1.14, 0.64, 0.68), (cx, 0, 0.94, 0.56, 0.6)], "white", corner=0.18, nc=1, sub=1, outline=0)
	jitter(o, 0.03)
	art_uv(o, f"{side}Leg_F", TROUSER, dx=-cx)
	block(k, leg, "Cuff", px, 0, 0.98, 0.78, 0.55, 0.58, "white", ch=0.05, a=0.46, b=0.4)
	block(k, leg, "Foot", px, -0.06, 0.34, 0.0, 0.48, 0.54, "skin", ch=0.05, a=0.56, b=0.36)
	block(k, leg, "Forefoot", px, -0.5, 0.24, 0.0, 0.47, 0.2, "skin", ch=0.04, a=0.56, b=0.36)
	for i, dx in enumerate((-0.36, -0.18, 0.0, 0.18, 0.36)):
		block(k, leg, f"Toe{i}", px + dx, -0.74, 0.18, 0.0, 0.08, 0.09, "blue", ch=0.03, corner=0.25, a=0.56, b=0.36)
		block(k, leg, f"ToeNail{i}", px + dx, -0.78, 0.195, 0.175, 0.055, 0.045, "nail", ch=0.004, a=0.6, b=0.3)
	# the anklet: big round beads spaced round the shin block, half sunk in it
	x, r, z = s * 0.5, 0.5, 0.5
	ring = [(x + d, -r) for d in (-0.33, 0, 0.33)] + [(x + r, d) for d in (-0.33, 0, 0.33)] + [(x + d, r) for d in (-0.33, 0, 0.33)] + [(x - r, d) for d in (-0.33, 0, 0.33)]
	for i, (bx, by) in enumerate(ring):
		bake(k, k.blob(leg, f"Bead{i}", (bx, by, z), (0.15, 0.15, 0.15), "bead", rings=4, n=8, outline=0), "bead", a=0.5, b=0.55)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	for s in (1, -1):
		block(k, "Head", f"Ear{s}", s * 0.94, 0.02, 4.72, 4.42, 0.05, 0.12, "skin", ch=0.02, a=0.42, b=0.3)
	_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _glyph(f, x, y, s):
	"""Invented, not a real character: a kite with a tail in one iris, two stacked hooks in the other. Same place and colour as the source's iris writing."""
	if s < 0:
		f.path(f"M{x - 6} {y - 7}L{x} {y - 3}L{x + 6} {y - 7}L{x + 3.5} {y + 2}L{x} {y + 9}L{x - 3.5} {y + 2}Z", "none", stroke="#1a0a2c", sw=1.9)
	else:
		f.path(f"M{x - 7} {y - 8}L{x + 6} {y - 8}L{x + 1} {y - 1}M{x - 7} {y}L{x + 6} {y}L{x + 1} {y + 7}M{x - 5} {y + 9}L{x + 4} {y + 9}", "none", stroke="#1a0a2c", sw=1.9)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V26Q65 32 -5 26Z", SKIN_D, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.55, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.55, 3)
	# the lines: one straight from the crown to the nose bridge, three each side nesting from the hairline through the eye out to the cheek
	stroke(f, [(65, -8), (65, 16), (65, 40), (65, 62), (65, 76)], 6.5, NAVY)
	for s in (1, -1):
		c = lambda d: 65 + s * d
		stroke(f, [(c(13), -8), (c(15), 22), (c(17), 50), (c(21), 76), (c(30), 90), (c(46), 98), (c(70), 92)], 6.5, NAVY)
		stroke(f, [(c(28), -8), (c(30), 22), (c(32), 50), (c(38), 72), (c(50), 80), (c(70), 77)], 6, NAVY)
		stroke(f, [(c(43), -8), (c(46), 20), (c(49), 42), (c(54), 56), (c(62), 62), (c(72), 62)], 5.5, NAVY)
	for s, x in ((-1, 37), (1, 93)):
		c = lambda d: 65 + s * d
		eye(f, x, 64, s, ("#c8385e", "#f2c21e", "#ffe96a"), w=38, up=18, dn=14, inner=5, outer=-6, ir=(14, 17), pu=(0.1, 0.1), lash="#d63f80", wing=4, thick=0.9, white="#7ab0e6", lid=0.2)
		_glyph(f, x - s, 64, s)
		# a thin pink brow, angled down to the nose
		f.path(f"M{c(8)} 48L{c(46)} 35L{c(46)} 38.5L{c(10)} 51.5Z", "#d63f80")
	f.soft("M60 88L65 82L70 88Q65 92 60 88Z", SKIN_D, 0.8, 1)
	# the wide grin: bared teeth with two fangs over a dark mouth
	f.path("M34 96Q65 104 96 96Q93 116 73 120Q65 121 57 120Q37 116 34 96Z", "#3e0f1c", stroke="#2a0c14", sw=1.6)
	f.path("M36 97Q65 105 94 97L92 104Q65 112 38 104Z", "#fbfaf2")
	for x in (46, 84):
		f.path(f"M{x - 5} 101L{x + 5} 102L{x} 113Z", "#fbfaf2")
	f.path("M34 96Q32 93 30 90", stroke="#2a0c14", sw=1.4)
	f.path("M96 96Q98 93 100 90", stroke="#2a0c14", sw=1.4)


def _head_rest(a):
	# the side of the head: the three face lines run on past the corner and end in points
	for n, x0, sign in (("Head_L", -6, 1), ("Head_R", 126, -1)):
		f = a[n]
		f.fill(SKIN)
		f.soft("M-5 90H125V135H-5Z", SKIN_D, 0.6, 3)
		for y, w in ((62, 5.5), (77, 6), (92, 6.5)):
			stroke(f, [(x0, y), (x0 + sign * 16, y), (x0 + sign * 34, y - 1), (x0 + sign * 52, y - 4)], w, NAVY)
	f = a["Head_B"]
	f.fill(SKIN)
	f.soft("M-5 80H135V135H-5Z", SKIN_D, 0.55, 3)
	for y in (108, 122):
		f.path(f"M-5 {y}Q65 {y + 5} 135 {y}", stroke=NAVY, sw=7)
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill(SKIN_D)


def _chest(f):
	"""Lean muscle in soft paint, the body block stays square; the source's line layout on top."""
	f.fill(SKIN)
	f.soft("M-5 2H205V14Q100 26 -5 14Z", SKIN_D, 0.5, 3)
	for s in (1, -1):
		c = lambda d: 100 + s * d
		# chest plate lit from above with a hard shadow under it, then three rows of stomach
		f.soft(f"M{c(4)} 22Q{c(50)} 14 {c(84)} 32Q{c(74)} 60 {c(44)} 64Q{c(16)} 64 {c(4)} 54Z", SKIN_L, 0.75, 5)
		f.soft(f"M{c(2)} 60Q{c(44)} 74 {c(86)} 44L{c(90)} 56Q{c(46)} 86 {c(2)} 70Z", MUSCLE, 0.85, 3)
		for y in (88, 110, 132):
			f.soft(f"M{c(5)} {y}Q{c(22)} {y - 6} {c(40)} {y - 3}L{c(38)} {y + 6}Q{c(22)} {y + 3} {c(5)} {y + 7}Z", MUSCLE, 0.8, 2)
		f.soft(f"M{c(58)} 70Q{c(46)} 110 {c(62)} 160H{c(105)}V70Z", SKIN_D, 0.6, 5)
	f.soft("M97 22H103V140H97Z", SKIN_D, 0.4, 2)
	f.soft("M-5 148H205V205H-5Z", SKIN_D, 0.55, 5)
	# two lines round the neck, the centre line to mid stomach, two branches to the flanks, rungs between, three round the waist
	for y, w in ((-2, 9), (15, 9)):
		f.path(f"M30 {y}Q100 {y + 34} 170 {y}", stroke=NAVY, sw=w)
	f.path("M100 26V122", stroke=NAVY, sw=14)
	for s in (1, -1):
		c = lambda d: 100 + s * d
		f.path(f"M{c(0)} 40Q{c(36)} 44 {c(90)} 88", stroke=NAVY, sw=13)
		for y0, y1, x0, x1 in ((80, 88, 22, 52), (102, 110, 22, 58)):
			f.path(f"M{c(x0)} {y0}L{c(x1)} {y1}", stroke=NAVY, sw=11)
	for y in (130, 148):
		f.path(f"M-5 {y}Q100 {y + 16} 205 {y}", stroke=NAVY, sw=11)


def _coat_cloth(f):
	f.fill(VEST)
	f.soft("M-5-5H105V40H-5Z", "#c67aaa", 0.7, 5)
	for x0, y0, x1, y1 in ((12, 30, 34, 130), (88, 40, 70, 150), (46, 24, 54, 90)):
		f.path(f"M{x0} {y0}Q{(x0 + x1) / 2 + 8} {(y0 + y1) / 2} {x1} {y1}", stroke=VEST_D, sw=9, opacity=0.5, blur=3)
	f.soft("M-5 130H105V205H-5Z", VEST_D, 0.55, 5)
	f.path("M-5 183H105V205H-5Z", "#4a1c44")


def _coat_back(f):
	"""Rows of lozenges on the coat's back: the source's squares reshaped, same place and colours."""
	f.fill(VEST)
	studs(f, COAT)
	for j in range(7):
		for i in range(-4, 5):
			x, z = i * 0.34 + (0.17 if j % 2 else 0), 2.72 + j * 0.2
			f.path(f"M{x:.3f} {z - 0.08:.3f}L{x + 0.12:.3f} {z:.3f}L{x:.3f} {z + 0.08:.3f}L{x - 0.12:.3f} {z:.3f}Z", VEST_D)
	f.out.append("</g>")
	f.soft("M-5 160H205V205H-5Z", VEST_D, 0.45, 5)
	f.path("M-5 186H205V205H-5Z", "#4a1c44")


def _cloth(f, top):
	"""Soft-shaded baggy cloth down to y = top: folds fall from the waist and bunch at the knee."""
	f.path(f"M-5-5H105V{top}H-5Z", CLOTH)
	f.soft(f"M-5 {top - 28}H105V{top}H-5Z", CLOTH_D, 0.6, 3)
	f.soft("M-5-5H105V14H-5Z", CLOTH_D, 0.75, 3)
	for x0, y0, x1, y1 in ((14, 18, 36, 104), (84, 14, 64, 100), (48, 28, 42, 88), (6, 62, 42, 112), (96, 56, 60, 112)):
		f.path(f"M{x0} {y0}Q{(x0 + x1) / 2 - 6} {(y0 + y1) / 2} {x1} {y1}", stroke=CLOTH_D, sw=5, opacity=0.5, blur=2)
	f.soft("M-5 0H12V150H-5ZM88 0H105V150H88Z", CLOTH_D, 0.45, 3)


def _limb(f, h):
	f.fill(SKIN)
	f.soft(f"M-5 {h - 50}H105V{h + 5}H-5Z", SKIN_D, 0.45, 5)
	f.soft(f"M78 -5H105V{h + 5}H78Z", SKIN_D, 0.5, 5)
	f.soft("M20 40Q46 30 66 44Q60 80 40 88Q22 78 20 40Z", SKIN_L, 0.7, 5)
	f.soft("M-5 74Q50 96 105 74V88Q50 110 -5 88Z", MUSCLE, 0.35, 5)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	_head_rest(a)
	_chest(a["Torso_F"])
	_coat_cloth(a["Torso_L"])
	_coat_back(a["Torso_B"])
	a["Torso_R"].fill(SKIN)
	f = a["Torso_T"]
	f.fill(SKIN)
	for r in (24, 40):
		f.path(f"M{100 - r * 2} 50a{r * 2} {r} 0 1 0 {r * 4} 0a{r * 2} {r} 0 1 0 {-r * 4} 0Z", "none", stroke=NAVY, sw=8)
	f = a["Torso_Bo"]
	f.fill(CLOTH)
	for x in (40, 80, 120, 160):
		f.path(f"M{x} -5Q{x + 8} 50 {x - 6} 105", stroke=CLOTH_D, sw=6, opacity=0.5, blur=2)
	f.soft("M-5-5H205V22H-5Z", CLOTH_D, 0.7, 3)
	for side in ("Left", "Right"):
		for fc in "FBOI":
			f = a[f"{side}Arm_{fc}"]
			_limb(f, 205)
			# thick bands closing round the arm: two on the shoulder, two round the biceps, two on the forearm
			for y in (24, 50, 104, 130, 172):
				f.path(f"M-5 {y}Q28 {y + 3} 50 {y + 16}Q72 {y + 3} 105 {y}", stroke=NAVY, sw=13)
			f = a[f"{side}Leg_{fc}"]
			_limb(f, 200)
			_cloth(f, 124)
		a[f"{side}Arm_T"].fill(SKIN)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(CLOTH)
		a[f"{side}Leg_Bo"].fill(SKIN_D)
