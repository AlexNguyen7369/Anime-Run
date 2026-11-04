# Target look for foe_db ("Selle"): light green spotted body, black plates on chest, shoulders, groin and ankles, black
# folded wings on the back, pale face, neck and hands, a green spotted crown with two upward horns on black balls,
# two purple lines on each cheek, a yellow line across ears and chin, pink eyes. No tail: this form keeps it retracted.
# +X is the viewer's right in the front view.
from atlas import FACES
from db_common import circle
from db_style3 import LIGHT, block, box, dome, dot, hair_cap, pipe, solid
from leaf_common import begin_clip, end_clip
from style2 import Kit, Ramps, face
from style3 import big_head, finish

GREEN = "#b4d86a"
GREEN_D = "#7fa648"
SPOT = "#12170f"
BLACK = "#14171d"
PALE = "#efe6dc"
PALE_D = "#c3b4b0"
PURPLE = "#7a2f9c"
YELLOW = "#f2cf3a"
PINK = "#e0449a"
DEFAULT = GREEN
R = Ramps(
	green=["#6a8f3c", "#8fb552", GREEN, "#d2ec8e"],
	black=["#050608", "#0e1015", BLACK, "#39424f", "#71808f"],
	pale=["#a99a98", "#cfc2bc", PALE, "#fff8ee"],
)
HAIR = {"colour": GREEN, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.56), (0, 0, 4.14, 0.72, 0.74), (0, 0, 4.42, 0.84, 0.8), (0, 0, 5.3, 0.84, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]
GLOSS = dict(base=0.42, amp=0.5, grad=0.08)


def _spotted(o, px=60):
	"""Maps a green plate onto the spot tile in Head_B, which the crown hides: planar per facet, one of 3 tone bands by its light."""
	x0, y0, pw, ph = FACES["Head_B"][:4]
	bh = ph / 3
	mesh = o.data
	uv = mesh.uv_layers["UVMap"].data
	for p in mesh.polygons:
		axis = max(range(3), key=lambda i: abs(p.normal[i]))
		a, b = [i for i in range(3) if i != axis]
		cs = [mesh.vertices[mesh.loops[li].vertex_index].co for li in p.loop_indices]
		ua, ub = [c[a] for c in cs], [c[b] for c in cs]
		s = min(px, (bh - 6) / max(max(ua) - min(ua), max(ub) - min(ub), 1e-6))
		w, h = (max(ua) - min(ua)) * s, (max(ub) - min(ub)) * s
		d = dot(p.normal, LIGHT)
		band = 2 if d > 0.35 else 1 if d > -0.2 else 0
		ou = x0 + 3 + (min(ua) * s) % max(pw - 6 - w, 1)
		ov = y0 + band * bh + 3 + (min(ub) * s) % max(bh - 6 - h, 1)
		for li, c in zip(p.loop_indices, cs):
			uv[li].uv = ((ou + (c[a] - min(ua)) * s) / 1024, 1 - (ov + (c[b] - min(ub)) * s) / 1024)
	return o


def _crown(k):
	"""A helmet from the brow to the nape, leaving the face and the jaw sides bare, two horns and a keel on top."""
	o = hair_cap(k, [(5.2, 4.18, 0.9, 0.86), (5.36, 4.7, 0.93, 0.88), (5.62, 5.36, 0.92, 0.86), (5.86, 5.82, 0.74, 0.68), (6.0, 5.98, 0.42, 0.4)], dict(ramp="green"), name="Crown")
	_spotted(o)
	_spotted(box(k, "Head", "Brow", [(5.0, -0.03, 0.03, -0.92, -0.62), (5.2, -0.34, 0.34, -0.94, -0.62), (5.34, -0.62, 0.62, -0.96, -0.62), (5.5, -0.7, 0.7, -0.9, -0.5)], "green", c=0.02))
	_spotted(box(k, "Head", "Keel", [(5.86, -0.09, 0.09, -0.66, 0.5), (6.14, -0.06, 0.06, -0.42, 0.42), (6.3, -0.02, 0.02, -0.14, 0.2)], "green", c=0.02))
	for s, tag in ((1, "L"), (-1, "R")):
		_spotted(pipe(k, "Head", "Horn" + tag, [(s * 0.78, 0.06, 5.46, 0.27), (s * 1.02, 0.08, 5.84, 0.27), (s * 1.12, 0.1, 6.28, 0.22), (s * 1.08, 0.13, 6.56, 0.13), (s * 0.98, 0.16, 6.88, 0.02)], "green"))
		dome(k, "Head", "Ball" + tag, (s * 0.84, 0.06, 5.34), (0.3, 0.3, 0.3), "black", up="x" if s > 0 else "-x", n=10, **GLOSS)


def _body(k):
	block(k, "UpperTorso", "Neck", -0.44, 0.44, -0.4, 0.4, 3.9, 4.2, "pale", c=0.04)
	for s, tag in ((1, "L"), (-1, "R")):
		# the chest plate, a hard slab on each side of the breastbone
		box(k, "UpperTorso", "Pec" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y, -0.4) for z, a, b, y in ((3.18, 0.1, 0.8, -0.53), (3.32, 0.05, 0.94, -0.6), (3.84, 0.05, 0.96, -0.6), (3.98, 0.24, 0.86, -0.53))], "black", c=0.05, **GLOSS)
		# the folded wing, root above the shoulder line, tip out at the hip, clear of the arm's swing
		rows = ((4.36, 0.66, 0.84, 0.66, 0.72), (3.94, 0.1, 0.98, 0.54, 0.8), (3.0, 0.05, 0.98, 0.54, 0.84), (2.36, 0.2, 0.96, 0.54, 0.78), (2.02, 0.62, 0.86, 0.56, 0.66))
		box(k, "UpperTorso", "Wing" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y0, y1) for z, a, b, y0, y1 in rows], "black", c=0.02, **GLOSS)
		rib = ((3.94, 0.44, 0.52), (3.0, 0.5, 0.58), (2.4, 0.66, 0.72))
		box(k, "UpperTorso", "WingRib" + tag, [(z, min(s * a, s * b), max(s * a, s * b), 0.78, 0.87) for z, a, b in rib], "black", c=0.015, base=0.8, amp=0.3)
	box(k, "UpperTorso", "Groin", [(2.02, -0.08, 0.08, -0.57, -0.4), (2.26, -0.34, 0.34, -0.59, -0.4), (2.5, -0.6, 0.6, -0.58, -0.4)], "black", c=0.03, **GLOSS)


def _arm(k, part, s):
	ax = s * 1.5
	rows = [(3.56, 0.5), (3.66, 0.58), (3.96, 0.61), (4.14, 0.54), (4.26, 0.36), (4.3, 0.18)]
	box(k, part, "Shoulder", [(z, ax - w, ax + w, -w, w) for z, w in rows], "black", c=0.13, **GLOSS)
	block(k, part, "Hand", ax - 0.52, ax + 0.52, -0.52, 0.52, 1.8, 2.36, "pale", c=0.03, base=0.6, amp=0.32, grad=0.06)


def _leg(k, part, s):
	x0, x1 = min(s * 0.01, s * 1.01), max(s * 0.01, s * 1.01)
	block(k, part, "Ankle", x0, x1, -0.53, 0.53, 0.54, 0.84, "black", c=0.04, **GLOSS)
	# the foot is shoe-like, no toes
	rows = [(0.08, -0.96, 0.56), (0.24, -0.98, 0.58), (0.4, -0.82, 0.56), (0.56, -0.54, 0.53)]
	_spotted(box(k, part, "Foot", [(z, x0, x1, y0, y1) for z, y0, y1 in rows], "green", c=0.08))
	block(k, part, "Sole", x0 + 0.01, x1 - 0.01, -0.98, 0.58, 0.0, 0.09, "black", c=0.03, base=0.2, amp=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	_crown(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, f"{side}UpperArm", s)
		_leg(k, f"{side}UpperLeg", s)
	finish()


def _spots(f, n, y0=0, y1=None, x0=0, x1=None, r=(3.2, 6.4)):
	"""The scattered black spots: blue-noise by rejection, so they read as a pattern, not a smear."""
	x1, y1 = f.w if x1 is None else x1, f.h if y1 is None else y1
	placed = []
	for _ in range(n * 30):
		if len(placed) == n:
			break
		x, y, q = f.rng.uniform(x0, x1), f.rng.uniform(y0, y1), f.rng.uniform(*r)
		if all((x - a) ** 2 + (y - b) ** 2 > (q + c + 5) ** 2 for a, b, c in placed):
			placed.append((x, y, q))
			f.path(circle(x, y, q, q * f.rng.uniform(0.8, 1.1)), SPOT)


def _skin(f, n, vein=True):
	f.fill(GREEN)
	f.soft(f"M{f.w * 0.1} {f.h * 0.04}H{f.w * 0.6}V{f.h * 0.4}H{f.w * 0.1}Z", "#d9f09a", 0.5, 8)
	_spots(f, n)
	if vein:
		# thin purple veins, only a few: they read as cracks when crowded
		x = f.w * f.rng.uniform(0.3, 0.7)
		f.path(f"M{x:.1f} {f.h * 0.3:.1f}Q{x + 7:.1f} {f.h * 0.42:.1f} {x - 3:.1f} {f.h * 0.56:.1f}T{x + 5:.1f} {f.h * 0.72:.1f}", stroke=PURPLE, sw=1.3, opacity=0.8)
	f.edges(0.22)


def _eye(f, cx, cy, sgn):
	"""Long and narrow under a black lid: pink iris, small black pupil."""
	i, o = cx - sgn * 18, cx + sgn * 18
	shape = f"M{i} {cy + 6}L{o} {cy - 11}L{o} {cy + 3}Q{cx + sgn * 6} {cy + 12} {i + sgn * 7} {cy + 11}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 1.5, cy + 0.5, 8.6, 10), PINK)
	f.path(circle(cx - sgn * 1.5, cy + 0.5, 4, 5), "#14060c")
	f.path(circle(cx, cy - 3.5, 1.5, 1.8), "#ffffff")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 6}L{o + sgn * 3} {cy - 12}L{o + sgn * 1.5} {cy - 6}L{i - sgn * 2} {cy + 9}Z", "#0a0a10")
	f.path(f"M{i + sgn * 7} {cy + 11}Q{cx + sgn * 6} {cy + 12} {o} {cy + 3}", stroke="#0a0a10", sw=1.2)


def _face(f):
	face(f, PALE, hairline=8, nose_y=88, shadow=PALE_D)
	for cx, sgn in ((37, -1), (93, 1)):
		ox = 65 + sgn * 70
		# the black cheek panel framing the face, its lower edge carrying the yellow line to the chin
		f.path(f"M{ox} 20L{ox - sgn * 15} 22L{ox - sgn * 12} 70L{ox - sgn * 30} 112L{ox} 106Z", BLACK)
		f.path(f"M{ox} 104L{ox - sgn * 31} 111L{65 + sgn * 6} 117L{65 + sgn * 6} 122L{ox - sgn * 33} 117L{ox} 110Z", YELLOW)
		_eye(f, cx, 62, sgn)
		# two purple lines down each cheek
		for dx, y0, y1 in ((4, 82, 100), (13, 80, 95)):
			x = cx + sgn * dx
			f.path(f"M{x - 1.7} {y0}L{x + 1.7} {y0}L{x + sgn * 2 + 1.1} {y1}L{x + sgn * 2 - 1.1} {y1}Z", PURPLE)
		# the brow ridge, a dark shelf instead of hair
		f.path(f"M{cx - sgn * 17} {46}L{cx + sgn * 19} {32}L{cx + sgn * 17} {39}L{cx - sgn * 14} {50}Z", "#54484e")
	f.path("M58 117H72V122H58Z", YELLOW)
	# dark purple lips, a thin smirk
	f.path("M52 104Q66 99 79 101Q85 100 87 96Q84 109 66 110Q56 110 52 104Z", "#5b2b7a")
	f.path("M52 104Q66 104 81 102Q85 101 87 96", stroke="#2a1040", sw=1.3)


def _head_side(f, front_left):
	"""Spotted helmet behind, the black cheek at the front, the yellow line running from the ear to the jaw."""
	w = f.w
	fx = (lambda x: x) if front_left else (lambda x: w - x)
	f.fill(GREEN)
	_spots(f, 10, x0=0, r=(3, 5))
	f.path(f"M{fx(-5)} 20L{fx(62)} 20L{fx(72)} 66L{fx(52)} 135L{fx(-5)} 135Z", BLACK)
	f.path(f"M{fx(52)} 68L{fx(62)} 72L{fx(30)} 135L{fx(18)} 135Z", YELLOW)


def _tile(f):
	"""The spot tile that 3D plates sample, 3 tone bands with the same dots in each."""
	bh = f.h / 3
	dots = []
	for tone, col in enumerate(("#7fa648", GREEN, "#d2ec8e")):
		f.path(f"M-5 {tone * bh}H135V{(tone + 1) * bh}H-5Z", col)
	r = f.rng
	for _ in range(16):
		x, y, q = r.uniform(4, 126), r.uniform(4, bh - 4), r.uniform(2.4, 3.4)
		if all((x - a) ** 2 + (y - b) ** 2 > 225 for a, b in dots):
			dots.append((x, y))
			for tone in range(3):
				f.path(circle(x, y + tone * bh, q, q), SPOT)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	_tile(a["Head_B"])
	a["Head_T"].fill(GREEN)
	a["Head_Bo"].fill(PALE_D)
	_head_side(a["Head_L"], True)
	_head_side(a["Head_R"], False)
	_skin(a["Torso_F"], 40)
	_skin(a["Torso_B"], 40, vein=False)
	for n in ("Torso_L", "Torso_R"):
		_skin(a[n], 24)
	a["Torso_T"].fill(BLACK)
	a["Torso_Bo"].fill(BLACK)
	for side in ("Left", "Right"):
		for key in "FBOI":
			_skin(a[f"{side}Arm_{key}"], 22)
			_skin(a[f"{side}Leg_{key}"], 22)
		a[f"{side}Arm_T"].fill(BLACK)
		a[f"{side}Arm_Bo"].fill(PALE_D)
		a[f"{side}Leg_T"].fill(GREEN)
		a[f"{side}Leg_Bo"].fill(BLACK)
