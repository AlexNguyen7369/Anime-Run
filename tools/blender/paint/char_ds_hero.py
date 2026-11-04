# Target look for ds_hero (design doc section 5): big head, dark red faceted spikes with bright tips, hanging card earrings,
# forehead scar, green and black check coat over a black uniform with a white belt, white leg wraps, sandals, sword at the hip.
from atlas import FACES, SIZE
from leaf_common import ell
from ds_style3 import block, cap, checks, coat, eye, gem, katana, sandal, skin_head, spread, stroke, uniform, wrapped_leg
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f7cfa9"
SKIN_D = "#dfa27a"
DEFAULT = "#1b1b27"
R = Ramps(
	hair=["#22070a", "#3c0d10", "#5c1416", "#7e1e1e"],
	tip=["#74191a", "#a4281f", "#c83a28", "#e4553a"],
	skin=["#c98a64", "#eab48c", "#f7cfa9", "#ffe2c6"],
	uni=["#0c0c14", "#191924", "#2a2a38", "#3e3e50"],
	white=["#9b9aa6", "#d4d4dc", "#f0f0f4", "#ffffff"],
	belt=["#a8a6b0", "#dcdce2", "#f6f6f8", "#ffffff"],
	wrapline=["#55555f", "#73737d", "#8f8f99"],
	gold=["#8c6a14", "#c6a02c", "#ecd060", "#fff0a0"],
	sole=["#5e3d22", "#855a34", "#a87a4c", "#c79a68"],
	strap=["#14141a", "#25252e", "#3b3b46"],
	red=["#6a0f0f", "#a51c1a", "#cc2c24", "#e6463a"],
	steel=["#2a2a32", "#40404c", "#5c5c6a"],
	card=["#c8c4b8", "#ece8dc", "#fbf8ee", "#ffffff"],
)
HAIR = {"colour": "#4f1014", "locks": []}
PROPS = []
CARD = (4, 4, 24, 62)  # px inside Head_T for the earring art, under the hair


def _hair(k):
	cap(k, side_z=4.62, back_y=-0.02)
	root = (0, 0.1, 5.5)
	# the crown: short thick wedges, standing up and out, big enough to overlap
	top = (((-1.34, -0.05, 5.74), 0.44), ((-1.06, -0.16, 6.2), 0.48), ((-0.5, -0.26, 6.56), 0.5), ((0.1, -0.24, 6.7), 0.52), ((0.66, -0.24, 6.5), 0.5), ((1.1, -0.16, 6.16), 0.48), ((1.38, -0.05, 5.7), 0.44), ((-0.78, 0.58, 6.32), 0.5), ((0.1, 0.7, 6.48), 0.52), ((0.88, 0.58, 6.28), 0.5), ((-1.28, 0.66, 5.66), 0.44), ((1.3, 0.66, 5.64), 0.44), ((-1.1, 1.1, 5.3), 0.42), ((1.12, 1.1, 5.28), 0.42))
	for i, (t, r) in enumerate(top):
		gem(k, "Head", f"Top{i}", spread(root, t), t, r, tip="tip", bend=0.05, twist=0.3 + 0.13 * i % 0.5)
	# the back: broad wedges lying down the head in two rows, so the tips read as an edge, not as dots
	for i, x in enumerate((-0.72, -0.24, 0.24, 0.72)):
		gem(k, "Head", f"BackU{i}", (x * 0.8, 0.62, 6.1), (x * 1.16, 1.2, 5.28 + 0.1 * (i % 2)), 0.48, tip="tip", split=0.8, flat=0.5, twist=0.25, across=(1, 0, 0))
	# nape: a row of broad downward wedges
	for i, x in enumerate((-0.68, -0.23, 0.23, 0.68)):
		gem(k, "Head", f"NapeS{i}", (x, 0.66, 5.0), (x * 1.08, 0.98, 4.16 + 0.07 * (i % 2)), 0.38, tip="tip", flat=0.5, twist=0.3, across=(1, 0, 0))
	# the fringe: broad wedges falling on the forehead, lifted on the viewer's right where the scar shows
	fringe = (((-0.84, -0.9, 4.86), 0.34), ((-0.42, -0.94, 4.8), 0.38), ((0.0, -0.96, 4.88), 0.36), ((0.34, -0.95, 5.2), 0.3), ((0.84, -0.9, 5.0), 0.28))
	for i, (t, r) in enumerate(fringe):
		gem(k, "Head", f"Fringe{i}", (t[0] * 0.86, -0.62, 6.12 + 0.05 * (i % 2)), t, r, tip="tip", split=0.8, flat=0.5, twist=0.2 + 0.25 * i % 0.5, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"Burn{s}", (s * 0.86, -0.56, 5.3), (s * 0.94, -0.66, 4.56), 0.2, tip="tip", flat=0.6, twist=0.2, across=(0, 1, 0))
		gem(k, "Head", f"Side{s}", (s * 0.9, 0.2, 5.3), (s * 1.08, 0.22, 4.44), 0.34, tip="tip", flat=0.45, twist=0.3, across=(0, 1, 0))


def _earrings(k):
	x0, y0, pw, ph = FACES["Head_T"][:4]
	cx, cy, cw, chh = CARD
	for s in (1, -1):
		block(k, "Head", f"Ring{s}", s * 0.96, -0.1, 4.62, 4.48, 0.03, 0.03, "gold", ch=0.008, a=0.6)
		o = block(k, "Head", f"Card{s}", s * 0.96, -0.1, 4.5, 4.02, 0.1, 0.035, "card", ch=0.008, a=0.7, b=0.3)
		layer = o.data.uv_layers[0].data
		for poly in o.data.polygons:
			if abs(poly.normal.y) > 0.9:
				for li in poly.loop_indices:
					co = o.data.vertices[o.data.loops[li].vertex_index].co
					u = (co.x - s * 0.96 + 0.1) / 0.2
					t = (4.5 - co.z) / 0.48
					layer[li].uv = ((x0 + cx + u * cw) / SIZE, 1 - (y0 + cy + t * chh) / SIZE)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_earrings(k)
	uniform(k)
	coat(k, "Torso_F", hem=1.16, lapel="uni")
	for s, side in ((1, "Left"), (-1, "Right")):
		wrapped_leg(k, side, s)
		sandal(k, f"{side}UpperLeg", s * 0.53, strap="strap")
	katana(k, "uni", "uni", "steel")
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	f.soft("M-5-5H135V24Q65 30 -5 24Z", "#cf8d66", 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.45, 3)
	f.soft("M12 76Q26 70 34 84Q24 96 12 88Z", "#ffb08c", 0.4, 3)
	f.soft("M118 76Q104 70 96 84Q106 96 118 88Z", "#ffb08c", 0.4, 3)
	for s, x in ((-1, 37), (1, 93)):
		eye(f, x, 64, s, ("#4a0d12", "#8f1f22", "#d05a48"), w=33, up=16, dn=14, inner=7, outer=-3, ir=(12, 16.5), pu=(3.8, 5.6), wing=3.2)
		ib, ob = 65 + s * 11, 65 + s * 46
		f.path(f"M{ib} 46L{ib + s * 1} 40Q{65 + s * 26} 33 {ob} 37L{ob - s * 2} 42Q{65 + s * 26} 40 {ib} 48Z", "#5e1416")
	# the scar on the forehead, a dark red flame shape on the viewer's right
	f.path("M84 34Q80 26 88 18Q88 24 94 20Q92 24 100 22Q98 30 92 36Q88 38 84 34Z", "#a23a30", stroke="#7a2520", sw=0.6)
	f.soft("M59 80L65 74L71 80Q65 86 59 80Z", SKIN_D, 0.7, 1)
	f.path("M60 83Q65 85.5 70 83", stroke="#b0745a", sw=1.1)
	# a small firm smile
	stroke(f, [(50, 102), (58, 105), (66, 106), (74, 105), (82, 101)], 1.3, "#6e2a26")
	skin_head(a, SKIN, "#cf8d66")
	checks(a["Torso_F"], 0.4, "#1f9a66", "#101016")
	# the earring: white card, red sun, rays below; lives in Head_T under the hair
	f = a["Head_T"]
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	cx, cy, cw, chh = CARD
	X0, Y0, W, H = cx * sx, cy * sy, cw * sx, chh * sy
	f.path(f"M{X0} {Y0}H{X0 + W}V{Y0 + H}H{X0}Z", "#fbf8ee")
	f.path(ell(X0 + W / 2, Y0 + H * 0.3, W * 0.32, H * 0.13), "#d6281e")
	for i in range(-2, 3):
		d = i * W * 0.17
		f.path(f"M{X0 + W / 2 + d} {Y0 + H * 0.48}L{X0 + W / 2 + d * 1.6} {Y0 + H * 0.94}", stroke="#d6281e", sw=W * 0.09)
