# Target look for ds_thunder (design doc section 5): shaggy gold bowl of hair with orange tips, frightened round eyes and a
# wobbly open mouth, yellow-to-orange coat with white triangle scales over a black uniform, white wraps, sandals, yellow-hilted sword.
from ds_style3 import RECT, cap, coat, eye, gem, katana, rect_d, sandal, skin_head, spread, studs, uniform, wrapped_leg
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#fbd8b4"
SKIN_D = "#e6ab82"
DEFAULT = "#1b1b27"
R = Ramps(
	hair=["#b07608", "#dc9e0c", "#f6c60e", "#ffe034", "#fff27a"],
	tip=["#a84a0a", "#d86a12", "#ee8418", "#f8a03a"],
	skin=["#c98a64", "#eab48c", "#fbd8b4", "#ffe6ca"],
	uni=["#0c0c14", "#191924", "#2a2a38", "#3e3e50"],
	white=["#9b9aa6", "#d4d4dc", "#f0f0f4", "#ffffff"],
	belt=["#a8a6b0", "#dcdce2", "#f6f6f8", "#ffffff"],
	wrapline=["#55555f", "#73737d", "#8f8f99"],
	gold=["#8c6a14", "#c6a02c", "#ecd060", "#fff0a0"],
	sole=["#5e3d22", "#855a34", "#a87a4c", "#c79a68"],
	strap=["#6a0f14", "#92181c", "#b42a28"],
	handle=["#a4780c", "#d6a818", "#f4cc30", "#ffe66a"],
	steel=["#3a3a42", "#5c5c68", "#83838f"],
)
HAIR = {"colour": "#f6c60e", "locks": []}
PROPS = []


def _hair(k):
	cap(k, side_z=4.4, back_y=-0.12)
	root = (0, 0.1, 5.6)
	# a low rounded mass: short tufts over the top, nothing tall
	top = (((-1.24, -0.2, 5.82), 0.46), ((-0.86, -0.3, 6.2), 0.5), ((-0.28, -0.34, 6.42), 0.5), ((0.34, -0.34, 6.46), 0.5), ((0.9, -0.3, 6.18), 0.5), ((1.26, -0.2, 5.8), 0.46), ((-0.76, 0.5, 6.22), 0.52), ((0.02, 0.6, 6.36), 0.54), ((0.78, 0.5, 6.2), 0.52), ((-1.24, 0.5, 5.6), 0.46), ((1.24, 0.5, 5.58), 0.46), ((-0.5, 1.12, 5.8), 0.52), ((0.5, 1.12, 5.78), 0.52))
	for i, (t, r) in enumerate(top):
		gem(k, "Head", f"Top{i}", spread(root, t), t, r, flat=0.75, bend=0.04, twist=0.3 + 0.17 * i % 0.5)
	# the uneven fringe, down to the brows, tips going orange
	fringe = (((-0.8, -0.92, 4.96), 0.32), ((-0.42, -0.95, 4.84), 0.36), ((-0.04, -0.96, 4.98), 0.34), ((0.34, -0.95, 4.82), 0.36), ((0.76, -0.92, 4.94), 0.32))
	for i, (t, r) in enumerate(fringe):
		gem(k, "Head", f"Fringe{i}", (t[0] * 0.86, -0.62, 6.12 + 0.05 * (i % 2)), t, r, tip="tip", split=0.68, flat=0.5, twist=0.15 + 0.2 * i % 0.4, across=(1, 0, 0))
	# sides to the jaw and a shaggy back, a band of orange at the ends
	for s in (1, -1):
		gem(k, "Head", f"BurnF{s}", (s * 0.86, -0.62, 5.26), (s * 0.96, -0.72, 4.3), 0.22, tip="tip", split=0.55, flat=0.6, twist=0.2, across=(0, 1, 0))
		for i, (y, z) in enumerate(((-0.28, 4.12), (0.12, 4.02), (0.5, 4.1))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.9, y, 5.26), (s * 1.08, y, z), 0.32, tip="tip", split=0.55, flat=0.42, twist=0.25 + 0.2 * i, across=(0, 1, 0))
	for i, x in enumerate((-0.74, -0.37, 0.0, 0.37, 0.74)):
		gem(k, "Head", f"Back{i}", (x, 0.72, 5.3), (x * 1.08, 1.04, 3.98 + 0.08 * (i % 2)), 0.36, tip="tip", split=0.55, flat=0.5, twist=0.3, across=(1, 0, 0))


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	uniform(k)
	coat(k, "Torso_F", hem=1.2, lapel="uni")
	for s, side in ((1, "Left"), (-1, "Right")):
		wrapped_leg(k, side, s)
		sandal(k, f"{side}UpperLeg", s * 0.53)
	katana(k, "handle", "uni", "steel")
	finish()


def _coat_art(f):
	"""Yellow fading to orange at the hem, rows of white triangles."""
	studs(f, RECT)
	stops = ((4.4, "#ffd21e"), (3.4, "#fcc81c"), (2.8, "#f9b81c"), (2.3, "#f6a41c"), (1.8, "#f28c1c"), (1.4, "#ec7418"))
	for i, (z, col) in enumerate(stops):
		f.path(rect_d(-2, stops[i + 1][0] if i + 1 < len(stops) else 0, 2, z), col)
	c, h = 0.48, 0.42
	for j in range(int(0.9 / h), int(4.4 / h) + 1):
		off = c / 2 if j % 2 else 0
		for i in range(-4, 5):
			x = i * c + off
			f.path(f"M{x - c / 2 + 0.05:.3f} {j * h + 0.05:.3f}L{x + c / 2 - 0.05:.3f} {j * h + 0.05:.3f}L{x:.3f} {(j + 1) * h - 0.05:.3f}Z", "#fffdf4")
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	f.soft("M-5-5H135V24Q65 30 -5 24Z", "#d8a07a", 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.45, 3)
	f.soft("M14 80Q28 74 36 88Q26 100 14 92Z", "#ff9e8a", 0.5, 3)
	f.soft("M116 80Q102 74 94 88Q104 100 116 92Z", "#ff9e8a", 0.5, 3)
	for s, x in ((-1, 38), (1, 92)):
		# wide scared eyes: tall white, a small amber iris, thin lash
		eye(f, x, 64, s, ("#8a5208", "#d59a1c", "#ffdf70"), w=31, up=17, dn=15, inner=4, outer=2, ir=(7.5, 9.5), pu=(2.4, 3), wing=1.2, thick=0.7, lid=0.15)
		# worried brows: inner end high, thick and orange-gold
		ib, ob = 65 + s * 12, 65 + s * 44
		f.path(f"M{ib} 34L{ib + s * 1} 41Q{65 + s * 26} 44 {ob} 49L{ob + s * 1} 44Q{65 + s * 26} 37 {ib} 34Z", "#e29414", stroke="#a86a0c", sw=0.7)
		# a tear at the eye's lower corner
		tx = x + s * 7
		f.path(f"M{tx} 80Q{tx - 4} 88 {tx} 92Q{tx + 4} 88 {tx} 80Z", "#a8e0ff", stroke="#5ea8d8", sw=0.6)
	f.soft("M59 80L65 76L71 80Q65 85 59 80Z", SKIN_D, 0.6, 1)
	# the wobbling, wailing mouth
	shape = "M44 98Q50 93 56 98Q62 102 68 97Q75 92 86 98Q88 112 76 118Q62 122 52 118Q42 112 44 98Z"
	f.path(shape, "#5c1518", stroke="#2a0c10", sw=1.5)
	f.path("M46 99Q50 95 56 100Q62 103 68 99Q75 95 84 99L83 103Q74 100 68 103Q61 107 55 104Q50 101 46 103Z", "#fbf8f0")
	f.path("M54 116Q65 108 76 116Q65 121 54 116Z", "#c9434a")
	skin_head(a, SKIN, "#d8a07a")
	_coat_art(a["Torso_F"])
