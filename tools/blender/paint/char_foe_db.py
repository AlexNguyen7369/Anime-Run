# Target look for foe_db ("Selle"), last form. Sources and evidence: docs/char_evidence/foe_db.md.
# A two-bladed crest (green and spotted outside, black inside) over a black egg dome and a V brow, a pale face framed in gold,
# a black glossy yoke with pecs and a hanging centre lobe, big black shoulder domes, purple ribs at the waist, a purple V
# and a black dome at the hips, spotted green limbs, black boots from the knee, gold feet, two long black wings. No tail:
# this form keeps it retracted. No hair and no emblem. +X is the viewer's right in the front view.
from math import cos, pi, sin

from atlas import FACES, SIZE
from db_common import circle
from db_style3 import LIGHT, block, box, dome, dot, pipe, slab, solid
from leaf_common import begin_clip, end_clip
from style2 import Kit, Ramps, face
from style3 import big_head, finish

GREEN = "#78b838"
GREEN_D = "#4c8a26"
GREEN_L = "#98d050"
SPOT = "#16340f"
PALE = "#eee8ee"
PALE_D = "#b6a6c2"
PURPLE = "#8a4fc0"
LIP = "#54246e"
GOLD = "#f0b820"
PINK = "#d0347e"
DEFAULT = GREEN
R = Ramps(
	green=[GREEN_D, "#62a02e", GREEN, GREEN_L],
	# the gloss: mostly near black, one bright plane where it faces the key light
	black=["#040406", "#0a0b10", "#14161d", "#2a303c", "#8d99a8"],
	purple=["#44206e", "#6636a0", PURPLE, "#b284e4", "#d8bcf6"],
	gold=["#b0700c", "#d8940f", GOLD, "#ffd85a"],
	pale=["#9c8cac", PALE_D, PALE, "#ffffff"],
)
HAIR = {"colour": GREEN, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.44, 0.52), (0, 0, 4.14, 0.68, 0.7), (0, 0, 4.42, 0.84, 0.78), (0, 0, 5.3, 0.86, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]


def _gloss(d):
	# near black except the few facets turned right at the key light, which flash
	return d if d < 0.9 else 1.6


GLOSS = dict(base=0.2, amp=0.55, grad=0.06, curve=_gloss)
TILE_PX = 60  # atlas px per stud of the spot tile, close to the render's own density


def _spotted(o):
	"""Maps a green solid onto the spot tile in Head_B, which the crest hides: planar per facet, one of 3 tone bands by its light."""
	x0, y0, pw, ph = FACES["Head_B"][:4]
	bh = ph / 3
	mesh = o.data
	uv = mesh.uv_layers["UVMap"].data
	for p in mesh.polygons:
		axis = max(range(3), key=lambda i: abs(p.normal[i]))
		a, b = [i for i in range(3) if i != axis]
		cs = [mesh.vertices[mesh.loops[li].vertex_index].co for li in p.loop_indices]
		ua, ub = [c[a] for c in cs], [c[b] for c in cs]
		s = min(TILE_PX, (bh - 6) / max(max(ua) - min(ua), max(ub) - min(ub), 1e-6))
		w, h = (max(ua) - min(ua)) * s, (max(ub) - min(ub)) * s
		d = dot(p.normal, LIGHT)
		band = 2 if d > 0.3 else 1 if d > -0.25 else 0
		ou = x0 + 3 + (min(ua) * s) % max(pw - 6 - w, 1)
		ov = y0 + band * bh + 3 + (min(ub) * s) % max(bh - 6 - h, 1)
		for li, c in zip(p.loop_indices, cs):
			uv[li].uv = ((ou + (c[a] - min(ua)) * s) / SIZE, 1 - (ov + (c[b] - min(ub)) * s) / SIZE)
	return o


# the crest's lower rim, front centre round to the nape: the V of the brow, then down past the temple
_RIM = (5.0, 5.3, 5.27, 5.05, 4.8, 4.66, 4.5, 4.38, 4.3, 4.26, 4.25)
# t towards the top, half width, half depth, z the row closes on
_SHELL = ((0, 0.94, 0.91), (0.4, 0.96, 0.93), (0.75, 0.88, 0.85), (1, 0.62, 0.6), (1, 0.3, 0.3))


def _shell(k):
	dirs = [(cos(-pi / 2 + j * pi / 10), sin(-pi / 2 + j * pi / 10)) for j in range(20)]
	rings = []
	for r, (t, sw, sd) in enumerate(_SHELL):
		ring = []
		for j, (c, d) in enumerate(dirs):
			px, py = abs(c) ** 0.3 * (1 if c > 0 else -1), abs(d) ** 0.3 * (1 if d > 0 else -1)
			rim = _RIM[min(j, 20 - j)]
			ring.append((sw * px, sd * py, rim + (5.9 + 0.14 * max(0, r - 3) - rim) * t))
		rings.append(ring)
	_spotted(solid(k, "Head", "Crest", rings, "green"))


def _blade_ring(s, z, cx, cy, hu, hv):
	"""A leaf section, concave towards the middle: front tip, round the outside, back tip, back along the inside."""
	pts = ((0.95, -1), (1.1, -0.4), (0.9, 0.2), (0.3, 0.7), (-0.6, 1), (-0.45, 0.45), (-0.05, 0), (0.45, -0.5))
	return [(s * (cx + hu * u), cy + hv * v, z) for u, v in pts]


_BLADE = ((5.1, 0.74, 0.0, 0.2, 0.62), (5.6, 0.78, 0.03, 0.3, 0.66), (6.0, 0.84, 0.06, 0.28, 0.5), (6.4, 0.9, 0.08, 0.2, 0.33), (6.75, 0.95, 0.1, 0.11, 0.18), (7.02, 1.0, 0.12, 0.012, 0.015))


def _crest(k):
	_shell(k)
	for s, tag in ((1, "L"), (-1, "R")):
		_spotted(solid(k, "Head", "Blade" + tag, [_blade_ring(s, *r) for r in _BLADE], "green"))
		# the black lining, on the inner face so the green stays a rim from the front
		lining = [_blade_ring(s, z, cx - hu * 0.2, cy + hv * 0.05, hu * 0.62, hv * 0.72) for z, cx, cy, hu, hv in _BLADE[:-1]] + [_blade_ring(s, *_BLADE[-1])]
		solid(k, "Head", "Lining" + tag, lining, "black", **GLOSS)
		# the gold guard at the temple, running down to the jaw
		x0, x1 = sorted((s * 0.8, s * 0.91))
		box(k, "Head", "Cheek" + tag, [(4.42, x0, x1, -0.62, -0.42), (4.6, x0, x1, -0.72, -0.22), (4.86, x0, x1, -0.76, -0.06), (5.02, x0, x1, -0.72, 0.0)], "gold", c=0.03, base=0.5, amp=0.4)
	# the black egg between the blades, its point coming down into the V of the brow
	pipe(k, "Head", "Egg", [(0, -0.93, 5.0, 0.02), (0, -0.88, 5.2, 0.24), (0, -0.77, 5.5, 0.42), (0, -0.62, 5.8, 0.5), (0, -0.48, 6.02, 0.4), (0, -0.36, 6.18, 0.22), (0, -0.3, 6.25, 0.02)], "black", rn=12, **GLOSS)


def _body(k):
	block(k, "UpperTorso", "Neck", -0.46, 0.46, -0.42, 0.42, 3.9, 4.22, "pale", c=0.04, base=0.42, amp=0.4)
	# the black yoke, all the way round the shoulders and the upper back
	box(k, "UpperTorso", "Yoke", [(3.3, -1.02, 1.02, -0.55, 0.56), (3.38, -1.05, 1.05, -0.59, 0.59), (3.9, -1.05, 1.05, -0.59, 0.59), (4.04, -0.86, 0.86, -0.48, 0.48), (4.12, -0.5, 0.5, -0.42, 0.42)], "black", c=0.05, **GLOSS)
	for s, tag in ((1, "L"), (-1, "R")):
		rows = ((3.2, 0.24, 0.7, -0.6), (3.3, 0.08, 0.9, -0.7), (3.46, 0.03, 0.98, -0.76), (3.78, 0.03, 1.0, -0.77), (3.96, 0.14, 0.9, -0.64))
		box(k, "UpperTorso", "Pec" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y, -0.4) for z, a, b, y in rows], "black", c=0.05, **GLOSS)
		_wing(k, s, tag)
		rows = ((2.12, 0.1, 0.5), (2.32, 0.36, 0.92), (2.56, 0.74, 1.07), (2.68, 0.98, 1.07))
		slab(k, "UpperTorso", "HipV" + tag, [(min(s * a, s * b), max(s * a, s * b), -0.61, z) for z, a, b in rows], "purple", thick=0.1, base=0.5, amp=0.4)
	box(k, "UpperTorso", "Lobe", [(3.0, -0.02, 0.02, -0.68, -0.4), (3.14, -0.24, 0.24, -0.74, -0.4), (3.36, -0.38, 0.38, -0.8, -0.4), (3.62, -0.3, 0.3, -0.8, -0.4)], "black", c=0.015, **GLOSS)
	# the waist: ribs in real steps, the torso's full width
	for i, (z0, w) in enumerate(((2.72, 1.04), (2.84, 1.06), (2.96, 1.04))):
		block(k, "UpperTorso", f"Rib{i}", -w, w, -w * 0.54, w * 0.54, z0, z0 + 0.125, "purple", c=0.035, base=0.46, amp=0.42, grad=0.1)
	dome(k, "UpperTorso", "Groin", (0, -0.54, 2.24), (0.34, 0.28, 0.24), "black", up="-y", n=12, **GLOSS)


def _wing(k, s, tag):
	"""Long and leaf-shaped from the shoulder blades to below the knee. Stays inside the torso's width where the arm swings."""
	rows = ((0.82, 1.2, 1.28, 0.97, 1.02), (1.3, 0.82, 1.42, 0.91, 1.02), (2.0, 0.42, 1.38, 0.82, 0.95), (2.8, 0.18, 1.16, 0.72, 0.85), (3.5, 0.08, 0.98, 0.62, 0.76), (4.05, 0.14, 0.72, 0.54, 0.66), (4.32, 0.3, 0.56, 0.55, 0.62))
	box(k, "UpperTorso", "Wing" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y0, y1) for z, a, b, y0, y1 in rows], "black", c=0.025, **GLOSS)
	# a thin green rim round its inner face
	box(k, "UpperTorso", "WingRim" + tag, [(z - 0.04, min(s * (a - 0.03), s * (b + 0.03)), max(s * (a - 0.03), s * (b + 0.03)), y0 - 0.03, y0 + 0.03) for z, a, b, y0, y1 in rows[1:-1]], "green", c=0.012, base=0.45, amp=0.3)
	# the ridge down its back, catching the light
	ridge = ((1.1, 1.08, 1.14, 1.0), (2.0, 0.84, 0.92, 0.94), (2.9, 0.58, 0.66, 0.83), (3.8, 0.38, 0.44, 0.72))
	box(k, "UpperTorso", "WingRidge" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y, y + 0.05) for z, a, b, y in ridge], "black", c=0.012, base=0.72, amp=0.2)


def _arm(k, part, s):
	ax = s * 1.5
	block(k, part, "Collar", ax - 0.54, ax + 0.54, -0.54, 0.54, 3.38, 3.58, "purple", c=0.04, base=0.46, amp=0.42)
	pipe(k, part, "Shoulder", [(ax, 0, z, w) for z, w in ((3.48, 0.66), (3.58, 0.76), (3.9, 0.78), (4.12, 0.68), (4.28, 0.46), (4.38, 0.02))], "black", rn=12, **GLOSS)
	# the forearm bulges out of the arm all round
	rows = [(2.26, 0.5), (2.4, 0.57), (2.7, 0.6), (2.9, 0.56), (3.0, 0.5)]
	_spotted(box(k, part, "Forearm", [(z, ax - w, ax + w, -w, w) for z, w in rows], "green", c=0.11))
	dome(k, part, "Elbow", (ax, -0.5, 3.04), (0.3, 0.14, 0.14), "purple", up="-y", n=10, base=0.46, amp=0.44)
	dome(k, part, "ElbowOut", (ax + s * 0.5, 0, 3.04), (0.3, 0.14, 0.14), "purple", up="x" if s > 0 else "-x", n=10, base=0.46, amp=0.44)
	block(k, part, "Hand", ax - 0.52, ax + 0.52, -0.52, 0.52, 1.8, 2.3, "pale", c=0.04, base=0.5, amp=0.42, grad=0.08)


def _leg(k, part, s):
	x0, x1 = min(s * 0.01, s * 1.01), max(s * 0.01, s * 1.01)
	cx = (x0 + x1) / 2
	# the knee: a spotted cap on a purple collar, at the boot's top
	block(k, part, "KneeCollar", x0 + 0.02, x1 - 0.02, -0.55, 0.55, 1.16, 1.27, "purple", c=0.03, base=0.46, amp=0.42)
	_spotted(dome(k, part, "Knee", (cx, -0.5, 1.42), (0.42, 0.26, 0.2), "green", up="-y", n=12))
	rows = [(0.3, 0.0, -0.53, 0.53), (0.9, 0.0, -0.54, 0.54), (1.14, 0.03, -0.57, 0.57), (1.2, 0.03, -0.57, 0.57)]
	box(k, part, "Boot", [(z, x0 - d, x1 + d, y0, y1) for z, d, y0, y1 in rows], "black", c=0.05, **GLOSS)
	# the long highlight down the shin
	slab(k, part, "BootShine", [(cx - 0.22, cx - 0.17, -0.545, 0.44), (cx - 0.28, cx - 0.14, -0.55, 0.7), (cx - 0.3, cx - 0.16, -0.57, 1.08)], "black", thick=0.02, base=0.86, amp=0.1)
	rows = [(0.0, 0.0, -1.0, 0.57), (0.08, 0.02, -1.06, 0.6), (0.2, 0.02, -0.96, 0.6), (0.34, 0.01, -0.7, 0.58), (0.44, 0.0, -0.5, 0.56)]
	box(k, part, "Foot", [(z, x0 - d, x1 + d, y0, y1) for z, d, y0, y1 in rows], "gold", c=0.09, base=0.46, amp=0.44)
	box(k, part, "FootRidge", [(0.1, cx - 0.06, cx + 0.06, -1.07, -0.8), (0.24, cx - 0.06, cx + 0.06, -0.97, -0.72), (0.36, cx - 0.06, cx + 0.06, -0.72, -0.52)], "gold", c=0.02, base=0.3, amp=0.3)
	block(k, part, "Sole", x0 + 0.01, x1 - 0.01, -1.0, 0.57, 0.0, 0.07, "gold", c=0.02, base=0.05, amp=0.1)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	_crest(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, f"{side}UpperArm", s)
		_leg(k, f"{side}UpperLeg", s)
	finish()


# ---- paint


def _mark(f, x, y, q, fill=SPOT):
	"""One irregular dark mark, an angular blob rather than a dot, as on a reptile's hide."""
	n = f.rng.randint(5, 7)
	a0 = f.rng.uniform(0, 6.28)
	pts = []
	for i in range(n):
		a, r = a0 + i * 6.283 / n, q * f.rng.uniform(0.62, 1.15)
		pts.append(f"{x + r * cos(a):.1f} {y + r * sin(a) * f.rng.uniform(0.8, 1.2):.1f}")
	f.path("M" + "L".join(pts) + "Z", fill)


def _marks(f, n, y0=0, y1=None, x0=0, x1=None, r=(3.4, 7.2)):
	"""Blue-noise by rejection, so they read as a pattern, not a smear."""
	x1, y1 = f.w if x1 is None else x1, f.h if y1 is None else y1
	placed = []
	for _ in range(n * 40):
		if len(placed) == n:
			break
		x, y, q = f.rng.uniform(x0, x1), f.rng.uniform(y0, y1), f.rng.uniform(*r)
		if all((x - a) ** 2 + (y - b) ** 2 > (q + c + 4) ** 2 for a, b, c in placed):
			placed.append((x, y, q))
			_mark(f, x, y, q)


def _skin(f, n, muscle=None):
	"""Green with soft painted shading, drawn muscle under the marks. The marks sit on top."""
	w, h = f.w, f.h
	f.fill(GREEN)
	f.soft(f"M{w * 0.08} {h * 0.03}H{w * 0.62}V{h * 0.42}Q{w * 0.3} {h * 0.5} {w * 0.08} {h * 0.42}Z", GREEN_L, 0.55, 8)
	f.soft(f"M{w * 0.62} {h * 0.5}H{w + 5}V{h + 5}H{w * 0.2}Z", GREEN_D, 0.55, 8)
	if muscle:
		muscle(f)
	_marks(f, n)
	f.edges(0.2)


def _thigh(f):
	f.soft(f"M{f.w * 0.5} 0Q{f.w * 0.58} {f.h * 0.25} {f.w * 0.48} {f.h * 0.5}H{f.w * 0.6}Q{f.w * 0.72} {f.h * 0.25} {f.w * 0.62} 0Z", GREEN_D, 0.7, 3)


def _eye(f, cx, cy, sgn):
	"""Narrow under a black lid: pink iris and small pupil, the outer corner climbing to the temple."""
	i, o = cx - sgn * 17, cx + sgn * 18
	shape = f"M{i} {cy + 6}L{o} {cy - 11}L{o} {cy + 4}Q{cx + sgn * 5} {cy + 13} {i + sgn * 6} {cy + 12}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 1.5, cy + 1, 9.4, 11), PINK)
	f.path(circle(cx - sgn * 1.5, cy + 1, 4, 5), "#14060c")
	f.path(circle(cx, cy - 3, 1.5, 1.8), "#ffffff")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 6}L{o + sgn * 3} {cy - 10}L{o + sgn * 1.5} {cy - 4}L{i - sgn * 2} {cy + 9}Z", "#0a0a10")
	f.path(f"M{i + sgn * 6} {cy + 12}Q{cx + sgn * 5} {cy + 13} {o} {cy + 4}", stroke="#0a0a10", sw=1.2)


def _face(f):
	face(f, PALE, hairline=26, nose_y=86, shadow=PALE_D)
	f.soft("M-5 30H12Q10 80 30 135H-5Z", PALE_D, 0.6, 5)
	f.soft("M135 30H118Q120 80 100 135H135Z", PALE_D, 0.75, 5)
	for cx, sgn in ((37, -1), (93, 1)):
		ox = 65 + sgn * 70
		# the gold frame: a panel at the temple narrowing into a line along the jaw to the chin
		f.path(f"M{ox} 18L{ox - sgn * 13} 26L{ox - sgn * 12} 70L{ox - sgn * 30} 106L{65 + sgn * 9} 118V124L{ox - sgn * 33} 114L{ox} 96Z", GOLD)
		f.path(f"M{ox - sgn * 13} 26L{ox - sgn * 12} 70L{ox - sgn * 30} 106L{65 + sgn * 9} 118", stroke="#a06a10", sw=1)
		# violet shadow round the eye
		f.soft(f"M{cx - sgn * 20} 56L{cx + sgn * 22} 36L{cx + sgn * 22} 66L{cx - sgn * 20} 74Z", "#8f62b6", 0.42, 3)
		_eye(f, cx, 60, sgn)
		# two lines down each cheek
		for dx, y0, y1 in ((3, 76, 94), (12, 73, 88)):
			x = cx + sgn * dx
			f.path(f"M{x - 1.6} {y0}L{x + 1.6} {y0}L{x + sgn * 2 + 1} {y1}L{x + sgn * 2 - 1} {y1}Z", "#7d3fa6")
		# the brow is a dark shelf under the crest's V
		f.path(f"M{65 + sgn * 3} 46L{cx + sgn * 24} 28L{cx + sgn * 22} 36L{65 + sgn * 5} 52Z", "#3a2c44")
	f.path("M56 116H74L72 125H58Z", GOLD)
	# dark lips, a thin smirk
	f.path("M55 102Q66 99 76 100Q80 99 82 96Q80 105 66 105Q58 105 55 102Z", LIP)
	f.path("M55 102Q66 102 77 100Q80 99 82 96", stroke="#28103a", sw=1.2)


def _head_side(f, front_left):
	"""Pale behind the jaw, the gold guard's line, the crest covers the rest."""
	fx = (lambda x: x) if front_left else (lambda x: f.w - x)
	f.fill(PALE)
	f.soft(f"M{fx(60)} 60H{fx(125)}V135H{fx(60)}Z", PALE_D, 0.7, 5)
	f.path(f"M{fx(-5)} 60L{fx(46)} 60L{fx(26)} 135H{fx(-5)}Z", GOLD)


def _tile(f):
	"""The spot tile the 3D plates sample, 3 tone bands with the same marks in each."""
	bh = f.h / 3
	for tone, col in enumerate((GREEN_D, GREEN, GREEN_L)):
		f.path(f"M-5 {tone * bh}H135V{(tone + 1) * bh}H-5Z", col)
	r = f.rng
	dots = []
	for _ in range(600):
		x, y, q = r.uniform(3, 127), r.uniform(3, bh - 3), r.uniform(1.8, 3.4)
		if all((x - a) ** 2 + (y - b) ** 2 > (q + c + 2) ** 2 for a, b, c in dots):
			dots.append((x, y, q))
	for x, y, q in dots:
		seed = r.getstate()
		for tone in range(3):
			r.setstate(seed)
			_mark(f, x, y + tone * bh, q)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	_tile(a["Head_B"])
	a["Head_T"].fill(SPOT)
	a["Head_Bo"].fill(PALE_D)
	_head_side(a["Head_L"], True)
	_head_side(a["Head_R"], False)
	_skin(a["Torso_F"], 70)
	_skin(a["Torso_B"], 70)
	for n in ("Torso_L", "Torso_R"):
		_skin(a[n], 34)
	a["Torso_T"].fill(SPOT)
	a["Torso_Bo"].fill(SPOT)
	for side in ("Left", "Right"):
		for key in "FBOI":
			_skin(a[f"{side}Arm_{key}"], 38)
			_skin(a[f"{side}Leg_{key}"], 38, muscle=_thigh if key in "FB" else None)
		f = a[f"{side}Leg_F"]
		# purple along the crotch line, at the top of the thigh's inner edge
		f.path("M-5 -5H60L-5 36Z" if side == "Left" else "M105 -5H40L105 36Z", PURPLE)
		a[f"{side}Arm_T"].fill(SPOT)
		a[f"{side}Arm_Bo"].fill(PALE_D)
		a[f"{side}Leg_T"].fill(GREEN)
		a[f"{side}Leg_Bo"].fill(SPOT)
