# Target look for ds_flame (design doc section 5): tall gold flame hair with red tips, huge staring gold eyes ringed red, forked
# brows, big grin; white coat with a flame hem on body and sleeves over a black uniform, white wraps, red-strapped sandals, sword.
from ds_style3 import RECT, cap, coat, eye, gem, katana, rect_d, sandal, skin_head, spread, studs, uniform, wrapped_leg
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f8cda8"
SKIN_D = "#dea078"
DEFAULT = "#1b1b27"
R = Ramps(
	hair=["#a86a06", "#dc9a0a", "#f8b812", "#ffd028", "#ffe670"],
	tip=["#7a0e0a", "#b81e12", "#de3418", "#f25a2a"],
	skin=["#c98a64", "#eab48c", "#f8cda8", "#ffe0c2"],
	uni=["#0c0c14", "#191924", "#2a2a38", "#3e3e50"],
	white=["#9b9aa6", "#d4d4dc", "#f0f0f4", "#ffffff"],
	belt=["#a8a6b0", "#dcdce2", "#f6f6f8", "#ffffff"],
	wrapline=["#55555f", "#73737d", "#8f8f99"],
	gold=["#8c6a14", "#c6a02c", "#ecd060", "#fff0a0"],
	sole=["#5e3d22", "#855a34", "#a87a4c", "#c79a68"],
	strap=["#7a0e0a", "#b81e12", "#d8301c"],
	handle=["#7a0e0a", "#b81e12", "#de3418", "#f25a2a"],
	guard=["#a86a06", "#dc9a0a", "#f8b812", "#ffd028"],
	sheath=["#14141c", "#24242e", "#3a3a46"],
)
HAIR = {"colour": "#f8b812", "locks": []}
PROPS = []


def _hair(k):
	cap(k, band_z=5.26, side_z=4.5, back_y=-0.1)
	root = (0, 0.15, 5.4)
	# the flame: long tongues up and out, red at the ends; the centre ones lean forward
	up = (((-1.72, 0.02, 5.7), 0.46), ((-1.52, -0.1, 6.28), 0.52), ((-1.0, -0.16, 6.8), 0.56), ((-0.34, -0.2, 6.92), 0.58), ((0.34, -0.2, 6.96), 0.58), ((1.02, -0.16, 6.8), 0.56), ((1.54, -0.1, 6.26), 0.52), ((1.74, 0.02, 5.68), 0.46), ((-1.1, 0.72, 6.5), 0.56), ((0.0, 0.84, 6.86), 0.6), ((1.12, 0.72, 6.48), 0.56), ((-1.56, 0.7, 5.72), 0.5), ((1.58, 0.7, 5.7), 0.5), ((-0.74, 1.48, 5.98), 0.54), ((0.76, 1.48, 5.96), 0.54), ((-1.28, 1.2, 5.1), 0.46), ((1.3, 1.2, 5.08), 0.46))
	for i, (t, r) in enumerate(up):
		gem(k, "Head", f"Up{i}", spread(root, t, 0.2), t, r, tip="tip", split=0.62, flat=0.72, bend=0.08, twist=0.3 + 0.13 * i % 0.5)
	# the front's swept-up hairline, then the long forked bangs falling to the brows
	for i, x in enumerate((-0.76, -0.4, 0.4, 0.76)):
		gem(k, "Head", f"Rise{i}", (x * 0.9, -0.66, 5.2), (x * 1.3, -0.82, 6.24 - 0.14 * (abs(i - 1.5) > 1)), 0.34, tip="tip", split=0.66, flat=0.6, twist=0.25, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"Bang{s}", (s * 0.08, -0.72, 5.76), (s * 0.42, -0.98, 5.04), 0.24, tip="tip", split=0.72, flat=0.5, twist=0.2, bend=-0.02, across=(1, 0, 0))
		gem(k, "Head", f"Burn{s}", (s * 0.88, -0.56, 5.3), (s * 0.98, -0.62, 4.5), 0.22, tip="tip", split=0.6, flat=0.55, twist=0.2, across=(0, 1, 0))
		gem(k, "Head", f"Side{s}", (s * 0.9, 0.12, 5.3), (s * 1.3, 0.2, 4.34), 0.36, tip="tip", split=0.62, flat=0.42, twist=0.3, across=(0, 1, 0))
	for i, x in enumerate((-0.68, -0.23, 0.23, 0.68)):
		gem(k, "Head", f"Back{i}", (x, 0.72, 5.1), (x * 1.16, 1.14, 3.98 + 0.1 * (i % 2)), 0.42, tip="tip", split=0.62, flat=0.5, twist=0.3, across=(1, 0, 0))


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	uniform(k)
	# the sleeve hem lands on the same flames as the coat hem
	coat(k, "Torso_F", hem=1.0, sleeve_dz=-1.56, lapel="sheath")
	for s, side in ((1, "Left"), (-1, "Right")):
		wrapped_leg(k, side, s, hem=0.86)
		sandal(k, f"{side}UpperLeg", s * 0.53)
	katana(k, "handle", "sheath", "guard")
	finish()


def _coat_art(f):
	"""White above, tongues of red, orange and yellow licking up from the hem at z 1.0."""
	studs(f, RECT)
	f.path(rect_d(-2, 0, 2, 5), "#f6f2e8")
	for col, base, tall, narrow in (("#d92c1a", 1.42, 0.46, 1.0), ("#f47e16", 1.28, 0.36, 0.72), ("#fbc92a", 1.14, 0.22, 0.42)):
		w = 0.3
		d = f"M-2 0L-2 {base}"
		x = -2.0
		i = 0
		while x < 2:
			h = tall * (1 if i % 2 else 0.72)
			d += f"Q{x + w * 0.25 * narrow:.3f} {base + h * 0.2:.3f} {x + w * 0.62:.3f} {base + h:.3f}Q{x + w * 0.62:.3f} {base + h * 0.3:.3f} {x + w:.3f} {base:.3f}"
			x += w
			i += 1
		f.path(d + "L2 0Z", col)
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	f.soft("M-5-5H135V20Q65 26 -5 20Z", "#cf8d66", 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.45, 3)
	for s, x in ((-1, 37), (1, 93)):
		# huge round stare: gold iris, a red ring, a tiny pupil
		eye(f, x, 64, s, ("#c8281a", "#f4b416", "#ffe874"), w=36, up=20, dn=18, inner=3, outer=-1, ir=(15, 19), pu=(2.2, 2.8), wing=3, thick=0.7, lid=0.12)
		# forked brow: a gold lower bar and a dark red upper fork, parting at the outer end
		ib, ob = 65 + s * 8, 65 + s * 48
		f.path(f"M{ib} 46L{ib} 34Q{65 + s * 28} 24 {ob} 22L{65 + s * 34} 32L{ob + s * 1} 38Q{65 + s * 26} 40 {ib} 46Z", "#c8281a", stroke="#7a1810", sw=0.7)
		f.path(f"M{ib + s * 1} 45L{ib + s * 1} 38Q{65 + s * 22} 34 {65 + s * 32} 36Q{65 + s * 22} 40 {ib + s * 1} 45Z", "#f6b814")
	f.soft("M59 82L65 76L71 82Q65 88 59 82Z", SKIN_D, 0.7, 1)
	f.path("M60 85Q65 87.5 70 85", stroke="#b0745a", sw=1.1)
	# the wide open grin with a top row of teeth
	f.path("M36 98Q65 104 94 98Q92 118 72 122Q65 123 58 122Q38 118 36 98Z", "#5c1518", stroke="#2a0c10", sw=1.5)
	f.path("M37.5 99Q65 105 92.5 99L91 106Q65 112 39 106Z", "#fbf8f0")
	f.path("M50 119Q65 110 80 119Q65 124 50 119Z", "#c9434a")
	f.path("M36 98Q34 96 33 93", stroke="#2a0c10", sw=1.3)
	f.path("M94 98Q96 96 97 93", stroke="#2a0c10", sw=1.3)
	skin_head(a, SKIN, "#cf8d66")
	_coat_art(a["Torso_F"])
