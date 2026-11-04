# Target look for foe_sea (design doc section 5, 4.32), display name Arlon: a huge periwinkle-blue sea man with a long flat saw
# nose jutting forward, a jagged grin, a brown cap with a thick cream fur band, a black mane falling from under it behind the
# neck, an open yellow short-sleeved shirt with black spiky splats, a purple sash, olive knee shorts, fibre anklets, sandals,
# a gold rope bangle on the character's left wrist. Evidence: docs/char_evidence/foe_sea.md.
# +X is the viewer's right and the character's left. Everything is drawn and modelled by hand here.
import math

from atlas import FACES, SIZE, shade
from leaf_common import begin_clip, end_clip
from sea_common import arm_muscle, chest, circle, leg_muscle
from sea_style3 import bake, block, eye, gem, head_base, head_sides, jitter, prism
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#8fa2e6"
SKIN_D = "#5c6abc"
SKIN_L = "#b8c6f8"
BLACK = "#0e0e16"
SHIRT = "#f4bc20"
SHIRT_D = "#c67c10"
SHIRT_L = "#ffdc60"
SPLAT = "#14141c"
OLIVE = "#626e2c"
OLIVE_D = "#39431a"
OLIVE_L = "#828f40"
RED = "#c81e2a"
DEFAULT = SHIRT
R = Ramps(
	hair=["#08080e", "#181824", "#2c2c40", "#4a4a68", "#74749c"],
	skin=["#4a56a4", "#6878c8", "#8fa2e6", "#b8c6f8"],
	cap=["#2c1a10", "#4e3020", "#6e4830", "#8e6444", "#b08a66"],
	fur=["#8a8268", "#bdb492", "#e4dcbc", "#fffbe6"],
	buckle=["#5e4a24", "#8e7438", "#bca25a", "#e2cc88"],
	shirt=["#a4640c", "#d08c14", "#f4bc20", "#ffdc60"],
	lining=["#4e5418", "#747c26", "#98a23a", "#b8c256"],
	sash=["#221a54", "#3a2f84", "#5a4cb2", "#7c6ed2", "#a698ea"],
	pant=["#242c10", "#39431a", "#626e2c", "#828f40"],
	fibre=["#8c7c4c", "#bcaa70", "#e0d09a", "#f6eac2"],
	gold=["#8e5e0c", "#c89a1c", "#f2cc40", "#fff09a"],
	sandal=["#2c180c", "#4c2c16", "#744a26", "#986c40"],
)
HAIR = {"colour": BLACK, "locks": []}
PROPS = []
# square heavy jaw: the face plane runs almost to the chin
HEAD_ROWS = [(0, 0, 3.98, 0.7, 0.62), (0, 0, 4.08, 0.86, 0.78), (0, 0, 4.22, 0.9, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
# shirt, shoulder to hem: z, front edge x, half width, half depth. Loose: it widens to the hem and hangs over the sash.
SHIRT_ROWS = [(4.05, 0.46, 0.99, 0.5), (3.96, 0.5, 1.06, 0.58), (3.45, 0.62, 1.07, 0.59), (2.9, 0.68, 1.09, 0.6), (2.3, 0.72, 1.12, 0.62), (1.76, 0.74, 1.15, 0.64), (1.7, 0.74, 1.13, 0.62)]
COLS = (2, 3, 8)  # columns on a front panel, a side, the back
# u = 0..100 on Torso_L and Torso_R runs from s = S0 (front, past the corner) to s = S0 + SPAN (the back corner)
S0, SPAN = -0.62, 1.92


def _art(face, u, t):
	x, y, pw, ph = FACES[face][:4]
	u, t = max(0.0, min(1.0, u)), max(0.0, min(1.0, t))
	return ((x + 2 + u * (pw - 4)) / SIZE, 1 - (y + 2 + t * (ph - 4)) / SIZE)


def _section(xe, hw, hd, c=0.07):
	"""An open C round the body seen from above: from the +X front edge round the back to the -X front edge."""
	anchors = [(xe, -hd), (hw - c, -hd), (hw, c - hd), (hw, hd - c), (hw - c, hd), (c - hw, hd), (-hw, hd - c), (-hw, c - hd), (c - hw, -hd), (-xe, -hd)]
	counts = (COLS[0], 1, COLS[1], 1, COLS[2], 1, COLS[1], 1, COLS[0])
	pts = []
	for (a, b), m in zip(zip(anchors, anchors[1:]), counts):
		pts += [(a[0] + (b[0] - a[0]) * i / m, a[1] + (b[1] - a[1]) * i / m) for i in range(m)]
	return pts + [anchors[-1]]


def _shirt(k):
	"""A real cloth shell with thickness: back on Torso_B, each side and front panel on Torso_L or Torso_R, lining from a ramp."""
	thick = 0.07
	paths = [[(x, y, z) for x, y in _section(xe, hw, hd)] for z, xe, hw, hd in SHIRT_ROWS]
	ns = len(paths[0])
	n = 2 * ns
	rings = []
	for path in paths:
		inner = []
		for j, p in enumerate(path):
			a, b = path[max(j - 1, 0)], path[min(j + 1, ns - 1)]
			tx, ty = b[0] - a[0], b[1] - a[1]
			ln = math.hypot(tx, ty) or 1.0
			inner.append((p[0] - ty / ln * thick, p[1] + tx / ln * thick, p[2]))
		rings.append(list(path) + inner[::-1])
	verts, faces, _ = k._loft(rings, caps=(False, False))
	for r in (0, len(rings) - 1):
		faces += [(r * n + j, r * n + j + 1, r * n + n - 2 - j, r * n + n - 1 - j) for j in range(ns - 1)]
	o = k._mesh("Shirt", "UpperTorso", verts, faces, outline=0)
	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	ztop, zlow = SHIRT_ROWS[0][0], SHIRT_ROWS[-1][0]
	for poly in mesh.polygons:
		outer = all(vi % n < ns for vi in poly.vertices)
		cx = sum(verts[vi][0] for vi in poly.vertices) / len(poly.vertices)
		for li in poly.loop_indices:
			vi = mesh.loops[li].vertex_index
			if not outer:
				uv[li].uv = k.R.uv("lining", 0.3 + 0.4 * (verts[vi][2] - zlow) / (ztop - zlow))
				continue
			x, y, z = verts[vi]
			row = SHIRT_ROWS[vi // n]
			t = (ztop - z) / (ztop - zlow)
			if poly.normal.y > 0.7:
				uv[li].uv = _art("Torso_B", (1.18 - x) / 2.36, t)
			else:
				s = abs(x) - row[2] if poly.normal.y < -0.7 else y + row[3]
				uv[li].uv = _art("Torso_L" if cx > 0 else "Torso_R", (s - S0) / SPAN, t)
	# the lapels folded back at the neck
	for s in (1, -1):
		pts = [(s * 0.44, 4.08), (s * 1.0, 4.06), (s * 1.03, 3.68), (s * 0.68, 3.34), (s * 0.54, 3.72)]
		prism(k, "UpperTorso", f"Lapel{s}", pts if s > 0 else pts[::-1], -0.66, -0.59, "shirt", a=0.6, b=0.44, g=0.14)


def _nose(k):
	"""The saw: a flat blade from between the eyes, rising forward; alternate rings jut out as teeth on both edges and underneath."""
	rings = []
	n = 21
	for i in range(n):
		t = i / (n - 1)
		y = -0.76 - 1.34 * t
		z = 4.64 + 0.62 * t
		tooth = i % 2 == 1 and i < n - 1
		w = 0.26 * (1 - t) ** 0.85 + 0.02 + (0.1 * (1 - 0.5 * t) if tooth else 0.0)
		h = 0.15 * (1 - t) + 0.025
		under = h * 1.1 + (0.05 if tooth else 0.0)
		yy = y + (0.04 if tooth else 0.0)  # each tooth leans back towards the face
		rings.append([(w, yy, z), (0, yy, z + h), (-w, yy, z), (0, yy, z - under)])
	verts, faces, flat = k._loft(rings)
	bake(k, k._mesh("Nose", "Head", verts, faces, flat, outline=0), "skin", a=0.62, b=0.42, g=0.05)


def _cap(k):
	# a low brown dome, then a fat lumpy fur band pulled down to the brow
	dome = [(0.98, 5.16, 0.3), (1.0, 5.44, 0.4), (0.97, 5.72, 0.5), (0.8, 5.95, 0.7), (0.44, 6.08, 0.85), (0.02, 6.11, 1.0)]
	bake(k, k.lathe("Head", "Cap", dome, "cap", n=14, at=(0, 0.02, 0), squash=0.93, outline=0), "cap", a=0.46, b=0.42)
	fur = [(5.06, 0.84, 0.76, 0.02, 0.2), (5.1, 0.97, 0.9, 0.035, 0.38), (5.2, 1.04, 0.97, 0.045, 0.56), (5.33, 1.06, 0.99, 0.05, 0.76), (5.46, 1.03, 0.96, 0.04, 0.92), (5.53, 0.95, 0.89, 0.02, 0.76), (5.56, 0.82, 0.76, 0.0, 0.5)]
	n, waves = 44, 11
	rings = []
	for ri, (z, hw, hd, amp, _) in enumerate(fur):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			lump = math.cos(waves * a + ri * 0.5)
			ring.append((math.copysign(abs(c) ** 0.5, c) * (hw + amp * lump), 0.02 + math.copysign(abs(sn) ** 0.5, sn) * (hd + amp * lump), z + 0.015 * lump))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	o = k._mesh("Fur", "Head", verts, faces, flat, outline=0)
	k._ramp_uv(o, "fur", lambda vi, co: fur[vi // n][4] + 0.16 * math.cos(waves * 2 * math.pi * (vi % n) / n + (vi // n) * 0.5))
	# the buckle on the fur, towards the character's left
	block(k, "Head", "Buckle", 0.56, -0.98, 5.42, 5.14, 0.14, 0.05, "buckle", ch=0.02, a=0.5, b=0.5)
	block(k, "Head", "BuckleStud", 0.56, -1.02, 5.33, 5.23, 0.055, 0.03, "cap", ch=0.012, a=0.42, b=0.4)


def _hair(k):
	"""No fringe: the mane starts under the fur and falls behind the neck, fanning past the jaw in stacked spiky clumps."""
	o = k.tube("Head", "Mane", [(0, 0.46, 5.2, 0.94, 0.42), (0, 0.5, 4.5, 1.02, 0.46), (0, 0.62, 3.9, 0.96, 0.36), (0, 0.66, 3.6, 0.6, 0.2)], "hair", corner=0.3, nc=1, sub=1, outline=0)
	jitter(o, 0.03)
	bake(k, o, "hair", a=0.36, b=0.42, g=0.1)
	# (azimuth from the back, root z, tip z, reach, radius); side clumps stay above the shoulders or behind the arms
	tiers = (
		[(0, 5.16, 4.34, 1.24, 0.5), (26, 5.14, 4.36, 1.3, 0.48), (52, 5.14, 4.46, 1.44, 0.46), (76, 5.14, 4.62, 1.56, 0.42), (98, 5.1, 4.92, 1.58, 0.36)],
		[(12, 4.8, 3.84, 1.3, 0.5), (38, 4.8, 3.92, 1.38, 0.48), (64, 4.82, 4.14, 1.52, 0.44), (88, 4.76, 4.36, 1.58, 0.38)],
		[(0, 4.42, 3.38, 1.3, 0.5), (24, 4.42, 3.42, 1.36, 0.5), (48, 4.46, 3.6, 1.42, 0.46), (72, 4.5, 4.08, 1.46, 0.36)],
		[(12, 4.02, 3.04, 1.24, 0.44), (36, 4.04, 3.14, 1.3, 0.42), (58, 4.1, 3.4, 1.3, 0.34)],
	)
	i = 0
	for tier in tiers:
		for az, z0, z1, reach, r in tier:
			a = math.radians(az)
			for s in (1, -1) if az else (1,):
				dx, dy = s * math.sin(a), math.cos(a)
				gem(k, "Head", f"Mane{i}", (0.72 * dx, 0.3 + 0.3 * dy, z0), (reach * dx, 0.3 + 0.62 * reach * dy, z1), r, flat=0.5, twist=0.2 + 0.13 * i, across=(dy, -dx, 0), a=0.42, b_=0.62)
				i += 1


def _waist(k):
	t = "UpperTorso"
	block(k, t, "Hips", 0, 0, 2.24, 1.72, 1.02, 0.54, "pant", ch=0.03, a=0.46, b=0.5)
	block(k, t, "Sash", 0, 0, 2.66, 2.2, 1.03, 0.57, "sash", ch=0.05, corner=0.2, sub=2, jit=0.028, mids=(2.44,), a=0.36, b=0.46, tone=0.06)
	block(k, t, "SashKnot", 0.56, -0.6, 2.6, 2.28, 0.18, 0.06, "sash", ch=0.03, jit=0.016, a=0.46, b=0.5)
	prism(k, t, "SashTail", [(0.4, 2.3), (0.72, 2.3), (0.72, 2.0), (0.42, 2.0)], -0.66, -0.59, "sash", a=0.38, b=0.44, g=0.1)
	prism(k, "LeftUpperLeg", "SashTail2", [(0.42, 2.0), (0.72, 2.0), (0.74, 1.3), (0.58, 1.14), (0.44, 1.3)], -0.66, -0.59, "sash", a=0.36, b=0.44, g=0.12)


def _arm(k, s, side):
	part, ax = f"{side}UpperArm", s * 1.5
	# a plain chamfered block with its hand: full width, no fingers (owner)
	k.reshape(part, f"{side}Arm", [(ax, 0, 4.03, 0.42, 0.42), (ax, 0, 3.94, 0.5, 0.5), (ax, 0, 1.87, 0.5, 0.5), (ax, 0, 1.8, 0.43, 0.43)], corner=0.14, nc=1)
	k.tube(part, "Sleeve", [(ax, 0, 4.06, 0.46, 0.46), (ax, 0, 3.97, 0.56, 0.56), (ax, 0, 3.06, 0.59, 0.59), (ax, 0, 3.0, 0.56, 0.56)], ("face", f"{side}Arm"), corner=0.15, nc=1, outline=0)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	lx = s * 0.52
	k.reshape(part, f"{side}Leg", [(lx, 0, 0.3, 0.46, 0.46), (lx, 0, 1.3, 0.46, 0.46)], corner=0.14, nc=1)
	# baggy shorts to the knee; keep every leg mesh at z <= 2
	shorts = [(s * 0.5, 0, 2.0, 0.49, 0.52), (s * 0.54, 0, 1.5, 0.54, 0.57), (s * 0.58, 0, 1.0, 0.59, 0.62), (s * 0.58, 0, 0.95, 0.56, 0.59)]
	k.tube(part, "Shorts", shorts, ("face", f"{side}Leg"), corner=0.12, nc=1, outline=0)
	# the fibre anklet: a tied cord, a frayed skirt hanging from it
	fringe = k.tube(part, "Fringe", [(lx, 0, 0.7, 0.5, 0.5), (lx, 0, 0.54, 0.55, 0.55), (lx, 0, 0.42, 0.57, 0.57)], "fibre", corner=0.3, nc=1, sub=4, zig=0.05, outline=0)
	bake(k, fringe, "fibre", a=0.58, b=0.4, g=0.1, tone=0.06)
	block(k, part, "Cord", lx, 0, 0.72, 0.62, 0.525, 0.525, "gold", ch=0.02, corner=0.25, a=0.52, b=0.46)
	# the foot on a thick sandal: toes as blocks, one broad strap over the instep
	block(k, part, "Foot", lx, -0.14, 0.42, 0.08, 0.47, 0.6, "skin", ch=0.07, corner=0.18, a=0.6, b=0.32)
	for i in range(4):
		block(k, part, f"Toe{i}", lx - 0.33 + 0.22 * i, -0.76, 0.26, 0.08, 0.095, 0.1, "skin", ch=0.03, a=0.64, b=0.3)
	block(k, part, "Strap", lx, -0.42, 0.33, 0.08, 0.5, 0.17, "sandal", ch=0.02, a=0.56, b=0.46)
	block(k, part, "Sole", lx, -0.17, 0.1, 0.0, 0.53, 0.72, "sandal", ch=0.025, a=0.42, b=0.32)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_nose(k)
	_cap(k)
	_hair(k)
	k.reshape("UpperTorso", "Torso", [(0, 0, 3.98, 1.0, 0.5), (0, 0, 2.02, 1.0, 0.5)], corner=0.1, nc=1)
	_shirt(k)
	_waist(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	# the gold rope bangle, two chunky turns on the character's left wrist
	for i, z in enumerate((2.5, 2.34)):
		block(k, "LeftUpperArm", f"Bangle{i}", 1.5, 0, z, z - 0.15, 0.55, 0.55, "gold", ch=0.04, corner=0.25, sub=3, jit=0.014, a=0.5, b=0.5, tone=0.12)
	finish()


# ---- paint


def _splat(f, cx, cy, rx, ry, n=9):
	"""The shirt's spiky black burst: uneven long and short points. Clothing pattern, follows the source."""
	r = f.rng
	pts = []
	for i in range(2 * n):
		q = r.uniform(0.74, 1.2) if i % 2 == 0 else r.uniform(0.44, 0.58)
		a = math.pi * i / n + r.uniform(-0.05, 0.05)
		pts.append(f"{cx + rx * q * math.cos(a):.1f} {cy + ry * q * math.sin(a):.1f}")
	f.path("M" + "L".join(pts) + "Z", SPLAT)


def _cloth(f):
	"""Yellow ground: light on the shoulders, orange in the low folds."""
	f.fill(SHIRT)
	f.soft(f"M-5-5H{f.w + 5}V22H-5Z", SHIRT_L, 0.55, 3)
	f.soft(f"M-5 {f.h - 40}H{f.w + 5}V{f.h + 5}H-5Z", SHIRT_D, 0.6, 5)


def _fold(f, x, y0, y1, bend=3, sw=2.8):
	f.path(f"M{x} {y0}Q{x + bend} {(y0 + y1) / 2} {x - bend / 2} {y1}", stroke=SHIRT_D, sw=sw, opacity=0.85, blur=1)


def _shirt_back(f):
	_cloth(f)
	for x, y0, y1 in ((36, 50, 180), (92, 90, 195), (150, 60, 185)):
		_fold(f, x, y0, y1)
	for cx, cy, r in ((38, 92, 30), (106, 72, 30), (168, 100, 30), (74, 150, 32), (140, 168, 30), (14, 172, 20), (190, 170, 18), (100, 14, 16)):
		_splat(f, cx, cy, r, r)
	f.soft("M-5-5H10V205H-5Z", SHIRT_D, 0.5, 3)
	f.soft("M205-5H190V205H205Z", SHIRT_D, 0.6, 3)


def _shirt_side(f):
	"""x 0..100 spans the front panel to the back corner at 52 units a stud, y 85 units a stud: splats are drawn narrow to read round."""
	_cloth(f)
	corner = -S0 / SPAN * 100
	# the side wall falls away from the light; a lit strip down the front panel
	f.soft(f"M{corner}-5H105V205H{corner}Z", SHIRT_D, 0.42, 3)
	f.soft(f"M{corner - 22} 10H{corner - 8}L{corner - 8} 180H{corner - 22}Z", SHIRT_L, 0.55, 3)
	_fold(f, corner + 20, 30, 190)
	_fold(f, corner + 44, 50, 195)
	_fold(f, corner - 16, 110, 195, sw=2.2)
	for cx, cy, rx, ry in ((corner - 12, 66, 14, 24), (corner - 11, 150, 14, 24), (corner + 18, 42, 15, 26), (corner + 40, 112, 16, 28), (corner + 14, 172, 14, 24), (corner + 58, 44, 13, 22)):
		_splat(f, cx, cy, rx, ry)
	f.path(f"M-5-5H{corner - 30}V205H-5Z", SHIRT_D, opacity=0.8)


def _sun_mark(f, cx, cy, r):
	"""Altered mark: same place and red as the source's sun, but straight spikes (8 long, 8 short) and a hollow ring with a crescent."""
	pts = []
	for i in range(16):
		q = r if i % 2 == 0 else r * 0.58
		a = math.pi * i / 8 - math.pi / 2
		pts.append(f"{cx + q * math.cos(a):.1f} {cy + q * math.sin(a):.1f}")
	f.path("M" + "L".join(pts) + "Z", RED)
	f.path(circle(cx, cy, r * 0.46), SKIN)
	f.path(circle(cx, cy, r * 0.32), RED)
	f.path(circle(cx + r * 0.1, cy - r * 0.08, r * 0.25), SKIN)


def _arm_mark(f, dx):
	"""Altered mark on the character's left forearm: same place and red as the source's crew tattoo, but straight-edged: three stacked
	chevrons on a tall lozenge, no flames, hooks or round forms. dx shifts it round the arm's corner so front and outer faces join."""
	cx = 100 + dx
	f.path(f"M{cx} 106L{cx + 15} 132L{cx} 160L{cx - 15} 132Z", RED)
	f.path(f"M{cx} 120L{cx + 6} 132L{cx} 145L{cx - 6} 132Z", shade(RED, 0.5))
	for y in (116, 136):
		for q in (1, -1):
			f.path(f"M{cx + q * 19} {y}L{cx + q * 33} {y + 4}L{cx + q * 25} {y + 12}L{cx + q * 33} {y + 21}L{cx + q * 19} {y + 17}L{cx + q * 22} {y + 9}Z", RED)


def _face(a):
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=26)
	# the fur's deep shadow on the brow
	f.soft("M-5-5H135V20Q65 30 -5 20Z", shade(SKIN, 0.42), 0.95, 3)
	# sunk sockets, small hard eyes, a heavy ridge driving down to the nose
	for cx, s in ((35, -1), (95, 1)):
		f.soft(f"M{cx - 22} 34H{cx + 22}L{cx + 20} 60Q{cx} 66 {cx - 20} 60Z", shade(SKIN, 0.6), 0.7, 2)
		eye(f, cx, 47, s, "#d8ac20", "#3a2808", "#f0d470", w=31, up=9, down=7, inner=5, outer=-6, wing=3, lid=4.5, ry=8, look=-0.5)
		ib, ob = 65 + s * 12, 65 + s * 52
		f.path(f"M{ib} 46L{ib + s * 2} 35L{ob} 25L{ob - s} 33L{ib + s * 2} 47Z", "#1a1e4c")
		f.path(f"M{ob - s * 6} 56Q{ob - s * 2} 66 {ob - s * 10} 74", stroke=shade(SKIN, 0.55), sw=1.4)
	# the nose root's shadow on the face
	f.soft("M46 56H84L92 78Q65 86 38 78Z", SKIN_D, 0.85, 2)
	# the huge jagged grin, cheek to cheek: interlocking rows of triangles on a dark mouth
	mouth = "M9 74Q65 88 121 74Q124 102 104 118Q65 130 26 118Q6 102 9 74Z"
	f.soft("M4 70Q65 84 126 70L128 86Q65 96 2 86Z", SKIN_D, 0.5, 2)
	begin_clip(f, mouth)
	f.path(mouth, "#20081a")
	for i in range(10):
		x = 4 + i * 12.2
		f.path(f"M{x} 66L{x + 12.2} 66L{x + 6.1} 106Z", "#f8f6ec")
		f.path(f"M{x + 6.1} 66L{x + 12.2} 66L{x + 6.1} 106Z", "#c8c8d8", opacity=0.55)
	for i in range(10):
		x = 10 + i * 12.2 - 6
		f.path(f"M{x} 130L{x + 12.2} 130L{x + 6.1} 94Z", "#fbfaf2")
		f.path(f"M{x + 6.1} 130L{x + 12.2} 130L{x + 6.1} 94Z", "#c8c8d8", opacity=0.55)
	end_clip(f)
	f.path(mouth, stroke=shade(SKIN, 0.36), sw=2.4)
	# cheeks pushed up by the grin, a heavy chin
	f.path("M6 68Q2 78 8 88", stroke=shade(SKIN, 0.5), sw=1.8)
	f.path("M124 68Q128 78 122 88", stroke=shade(SKIN, 0.5), sw=1.8)
	f.soft("M30 122Q65 132 100 122L104 135H26Z", SKIN_D, 0.75, 2)
	head_sides(a, SKIN, SKIN_D)
	# the mane behind the ear and the fur's shadow; Head_L's back is on its right, Head_R's on its left
	a["Head_L"].path("M64 -5H125V135H88L78 74Z", BLACK)
	a["Head_R"].path("M56 -5H-5V135H32L42 74Z", BLACK)
	for n in ("Head_L", "Head_R"):
		a[n].soft("M-5-5H125V20H-5Z", shade(SKIN, 0.42), 0.9, 3)
	for n in ("Head_B", "Head_T"):
		a[n].fill(BLACK)


def _chest(f):
	f.fill(SKIN)
	chest(f, SKIN, w=0.92, deep=1.25)
	# cast shadows: the jaw, and the shirt's open edges
	f.soft("M-5-5H205V18Q100 36 -5 18Z", SKIN_D, 0.8, 5)
	f.soft("M-5-5H62L44 205H-5Z", SKIN_D, 0.75, 5)
	f.soft("M205-5H138L156 205H205Z", SKIN_D, 0.75, 5)
	_sun_mark(f, 132, 58, 27)


def _arm_paint(f, side, key):
	arm_muscle(f, side, key, SKIN, y0=0, wrist=176)
	f.path("M-5 176H105V210H-5Z", SKIN)
	f.soft("M-5 172H105V182H-5Z", SKIN_D, 0.5, 2)
	f.soft("M-5 196H105V210H-5Z", SKIN_D, 0.55, 3)
	f.soft("M-5 104H105V120H-5Z", SKIN_D, 0.75, 3)
	if key in "BI":
		f.path("M-5-5H105V210H-5Z", SKIN_D, opacity=0.28)
	if side == "Left" and key == "F":
		_arm_mark(f, -32)
	if side == "Left" and key == "O":
		_arm_mark(f, -132)
	# the sleeve's art goes on last: the muscle shading would bleed over it
	begin_clip(f, "M-5-5H105V104H-5Z")
	_cloth(f)
	f.soft("M-5 78H105V110H-5Z", SHIRT_D, 0.7, 4)
	f.soft("M80-5H105V110H80Z", SHIRT_D, 0.5, 3)
	_fold(f, 30, 30, 96, sw=2.2)
	_fold(f, 72, 40, 100, sw=2.2)
	spots = {"F": ((32, 62, 18), (78, 28, 15)), "O": ((50, 36, 20), (20, 84, 14), (84, 84, 14)), "B": ((30, 30, 17), (72, 72, 18)), "I": ((50, 56, 18),)}
	for cx, cy, r in spots[key]:
		_splat(f, cx, cy, r, r)
	f.path("M-5 101H105V110H-5Z", SHIRT_D)
	if key in "BI":
		f.path("M-5-5H105V110H-5Z", SHIRT_D, opacity=0.22)
	end_clip(f)


def _leg_paint(f, s, key):
	f.fill(OLIVE)
	f.soft("M-5-5H105V18H-5Z", OLIVE_D, 0.55, 4)
	f.soft("M-5 70H105V104H-5Z", OLIVE_D, 0.6, 5)
	f.soft("M78-5H105V104H82Z", OLIVE_D, 0.6, 3)
	f.soft("M-5-5H10V104H-5Z", OLIVE_D, 0.35, 3)
	f.soft("M24 22Q44 18 50 56Q34 70 20 58Z", OLIVE_L, 0.3, 5)
	for d in ("M14 58Q44 66 86 52", "M22 80Q50 88 90 74"):
		f.path(d, stroke=OLIVE_D, sw=2.2, opacity=0.85, blur=1)
	f.path("M-5 97H105V104H-5Z", OLIVE_D)
	leg_muscle(f, SKIN, 104, 200)
	f.soft("M-5 104H105V124H-5Z", SKIN_D, 0.75, 3)
	if key in "BI":
		f.path("M-5-5H105V205H-5Z", SKIN_D, opacity=0.25)


def paint(a):
	R.paint(a)
	_face(a)
	_chest(a["Torso_F"])
	_shirt_back(a["Torso_B"])
	_shirt_side(a["Torso_L"])
	_shirt_side(a["Torso_R"])
	a["Torso_T"].fill(SHIRT)
	a["Torso_Bo"].fill(OLIVE_D)
	for side, s in (("Left", 1), ("Right", -1)):
		for key in "FBOI":
			_arm_paint(a[f"{side}Arm_{key}"], side, key)
			_leg_paint(a[f"{side}Leg_{key}"], s, key)
		a[f"{side}Arm_T"].fill(SHIRT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(OLIVE_D)
		a[f"{side}Leg_Bo"].fill(SKIN_D)
