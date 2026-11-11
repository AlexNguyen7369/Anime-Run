# Target look for boss_mage "The Elf Mage" (design doc section 5): long white-silver hair parted in the middle with two high twin
# tails past the waist, large pointed elf ears, green eyes under thick short brows, a calm flat mouth, red drop earrings; a white
# capelet with gold bands and a high collar closed by a red gem, a black-and-white striped shirt, a dark belt, a white tunic with wide
# gold-banded cuffs and a flared skirt with a gold hem, black tights, brown boots with a folded top. The staff (dark red shaft, gold
# crescent round a red gem, red ribbon wrap) and the two tails are built here but kept out of the merge by tools/blender/build_boss_mage.py,
# which animates them on their own. +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from jk_common import brow2, eye2, form
from jk_style3 import Kit, bake, big_head, block, collar, crown, face_base, finish, gem, head_rest, prism, slab, torso_core
from style2 import Ramps

SKIN = "#fde8dc"
SKIN_D = "#dcb6a4"
WHITE = "#f4f3f6"
WHITE_D = "#b9bccb"
STRIPE = "#16161e"
GOLD = "#d6a838"
DEFAULT = WHITE
R = Ramps(
	hair=["#8c88a2", "#b2aec6", "#d4d2e4", "#ecebf5", "#ffffff"],
	parting=["#6e6a86", "#7e7a96", "#8e8aa6", "#9e9ab6"],
	skin=["#c49c88", "#e8c6b4", "#fde8dc", "#fff4ec"],
	white=["#9c9fb2", "#c6c9d6", "#e6e7ee", "#f8f8fb", "#ffffff"],
	gold=["#8a6210", "#c39028", "#e8be4c", "#fff0a8"],
	red=["#5c0a10", "#9a161e", "#cc2a2c", "#f05a50"],
	gem=["#3c0408", "#8a0e16", "#d42228", "#ff8a7a"],
	shaft=["#2a080a", "#461014", "#64181c", "#82282a"],
	belt=["#0e0f16", "#1a1c26", "#2a2d3a", "#40445a"],
	buckle=["#4a4e5c", "#7c8090", "#aeb2c0", "#e2e4ea"],
	tights=["#0a0b12", "#141622", "#202336", "#30344c"],
	boot=["#3a2416", "#5e3c24", "#7e5634", "#9c7048"],
	cuff=["#6a4a30", "#92704c", "#b89068", "#d4ae84"],
)
HAIR = {"colour": "#D4D2E4", "locks": []}
PROPS = []
# the staff is drawn upright at the origin, then moved so its grip (2.2 above the butt) sits in the right hand, a little in front
STAFF_AT = (-1.5, -0.62, 2.05 - 2.2)


def rod(k, part, name, pts, r, ramp, n=6, **bk):
	"""A round loft along a polyline: the staff's shaft pieces, crescent and rings. r = radius, scalar or one per point."""
	from mathutils import Vector

	pts = [Vector(p) for p in pts]
	rs = r if isinstance(r, (list, tuple)) else [r] * len(pts)
	rings = []
	for i, p in enumerate(pts):
		t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
		a = t.cross(Vector((0, 1, 0)))
		a = (a if a.length > 0.1 else t.cross(Vector((1, 0, 0)))).normalized()
		b = t.cross(a)
		rings.append([tuple(p + (a * math.cos(2 * math.pi * j / n) + b * math.sin(2 * math.pi * j / n)) * rs[i]) for j in range(n)])
	verts, faces, flat = k._loft(rings)
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **bk)


def wrap(k, part, name, rows, ramp, t=0.05, n=12, **bk):
	"""A cloth shell round the body, open at the front. rows = (z, half width, half depth, half gap at the front), top first."""
	grid = []
	for z, hw, hd, gx in rows:
		d0 = math.asin(min(1.0, (gx / hw) ** 2))
		ring = []
		for j in range(n + 1):
			a = -math.pi / 2 + d0 + (2 * math.pi - 2 * d0) * j / n
			c, sn = math.cos(a), math.sin(a)
			x, y = hw * math.copysign(abs(c) ** 0.5, c), hd * math.copysign(abs(sn) ** 0.5, sn)
			ring.append(((x, y, z), (x * (hw - t) / hw, y * (hd - t) / hd, z)))
		grid.append(ring)
	h, w = len(grid), n + 1
	verts = [q[0] for r in grid for q in r] + [q[1] for r in grid for q in r]
	o = lambda r, c: r * w + c
	i = lambda r, c: h * w + r * w + c
	faces = []
	for r in range(h - 1):
		for c in range(w - 1):
			faces += [(o(r, c), o(r, c + 1), o(r + 1, c + 1), o(r + 1, c)), (i(r, c), i(r + 1, c), i(r + 1, c + 1), i(r, c + 1))]
		for c in (0, w - 1):
			faces.append((o(r, c), o(r + 1, c), i(r + 1, c), i(r, c)))
	for r in (0, h - 1):
		for c in range(w - 1):
			faces.append((o(r, c), i(r, c), i(r, c + 1), o(r, c + 1)))
	return bake(k._mesh(name, part, verts, faces, outline=0), ramp, k, **bk)


def _hair(k):
	crown(k, [(1.0, 5.46), (1.06, 5.66), (0.96, 5.92), (0.58, 6.14), (0.16, 6.22)])
	block(k, "Head", "Cap", 0, 0.02, 5.76, 5.3, 1.03, 0.89, "hair", ch=0.09, corner=0.4, jit=0.015, a=0.46, b=0.44)
	# the back of the head: four chunky vertical clumps to the nape, split down the middle
	for i, (x, r, end) in enumerate(((-0.66, 0.34, 3.98), (-0.22, 0.32, 3.86), (0.22, 0.32, 3.9), (0.66, 0.34, 4.0))):
		gem(k, "Head", f"Back{i}", (x * 0.9, 0.86, 6.0), (x * 1.04, 1.0, end), r, flat=0.6, twist=0.0, a=0.5 - 0.05 * (i % 2), across=(1, 0, 0))
	# the centre part line, front to nape, over the crown
	part = [(-0.9, 5.96), (-0.56, 6.17), (-0.16, 6.25), (0.2, 6.25), (0.6, 6.16), (0.92, 5.9), (1.0, 5.5), (0.96, 5.0)]
	slab(k, "Part", part + [(y - 0.06 * (1 if y > 0 else -1), z - 0.04) for y, z in reversed(part)], -0.025, 0.025, "parting", a=0.5, b=0.2)
	for s in (1, -1):
		# the sides stop above the ear root so the ears stand clear
		slab(k, f"Side{s}", [(-0.8, 5.46), (-0.8, 5.0), (-0.5, 4.9), (0.2, 4.9), (0.9, 4.6), (0.9, 5.46)], s * 0.84, s * 1.02, "hair", a=0.44, b=0.46)
		# long locks framing the face, in front of the ears, to the jaw
		gem(k, "Head", f"Lock{s}", (s * 0.84, -0.66, 5.5), (s * 0.86, -0.78, 3.92), 0.26, flat=0.42, twist=0.2, across=(1, 0, 0), a=0.52)
		# straight blunt bangs to the brow, parted in the middle, the eyes left clear
		fringe = [(0.03, 5.92), (0.62, 5.78), (0.96, 5.5), (0.96, 4.96), (0.74, 4.9), (0.7, 5.0), (0.46, 4.94), (0.42, 5.04), (0.18, 4.98), (0.03, 5.1)]
		prism(k, "Head", f"Fringe{s}", [(s * x, z) for x, z in fringe], -0.99, -0.84, "hair", a=0.56, b=0.4)


def _tails(k):
	"""Two high twin tails, chunky clumps splayed out past the arms and down past the waist. Named Tail*: kept out of the merge."""
	for s, tag in ((1, "L"), (-1, "R")):
		root = (s * 0.86, 0.36, 5.86)
		tie = [(s * (0.86 + 0.13 * math.cos(math.pi * j / 4)), 5.86 + 0.13 * math.sin(math.pi * j / 4)) for j in range(8)]
		prism(k, "Head", f"Tail{tag}Tie", tie, 0.2, 0.52, "red", a=0.54, b=0.4)
		gem(k, "Head", f"Tail{tag}0", root, (s * 1.65, 0.74, 4.5), 0.38, flat=0.62, twist=0.25, a=0.52)
		gem(k, "Head", f"Tail{tag}1", (s * 1.45, 0.72, 4.95), (s * 2.85, 1.0, 1.6), 0.42, flat=0.55, twist=0.35, a=0.5)
		gem(k, "Head", f"Tail{tag}2", (s * 1.3, 0.64, 5.2), (s * 2.4, 1.08, 2.0), 0.3, flat=0.6, twist=0.6, a=0.44)
		gem(k, "Head", f"Tail{tag}3", (s * 1.55, 0.84, 4.6), (s * 3.05, 0.9, 2.35), 0.27, flat=0.6, twist=0.1, a=0.56)


def _ears(k):
	for s, tag in ((1, "L"), (-1, "R")):
		# long and pointed, out and a little up, wide top to bottom
		gem(k, "Head", f"Ear{tag}", (s * 0.84, 0.0, 4.74), (s * 1.78, 0.14, 5.22), 0.22, ramp="skin", flat=0.3, twist=0.0, a=0.6, across=(0, 0, 1))
		# the red drop hangs from the lobe, outside the face-framing lock
		prism(k, "Head", f"Earring{tag}", [(s * 1.2, 4.7), (s * 1.27, 4.52), (s * 1.2, 4.3), (s * 1.13, 4.52)], -0.05, 0.05, "red", a=0.62, b=0.3)


def _top(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	# the capelet over shoulders and upper arms, closed at the collar, opening down the front onto the striped shirt
	# the middle of the capelet; the parts over the arms ride the arms (_arm), so a raised arm lifts its side
	wrap(k, t, "Cape", [(4.2, 0.82, 0.62, 0.02), (4.06, 1.12, 0.72, 0.12), (3.38, 1.18, 0.82, 0.42)], "white", t=0.06, a=0.56, b=0.42, g=0.1)
	wrap(k, t, "CapeHem", [(3.52, 1.2, 0.84, 0.36), (3.34, 1.21, 0.86, 0.38)], "gold", t=0.09, n=10, a=0.56, b=0.4)
	collar(k, "white", 4.22, 4.38, z0=3.98, rx=0.64, ry=0.6, n=12)
	block(k, t, "CollarBand", 0, 0, 4.29, 4.2, 0.7, 0.66, "gold", ch=0.02, corner=0.4, a=0.58, b=0.4)
	block(k, t, "Clasp", 0, -0.72, 4.2, 3.92, 0.11, 0.05, "gem", ch=0.03, a=0.62, b=0.4)
	block(k, t, "Belt", 0, 0, 2.5, 2.3, 1.08, 0.6, "belt", ch=0.02, corner=0.14, a=0.5, b=0.5)
	block(k, t, "Buckle", 0, -0.62, 2.53, 2.27, 0.15, 0.025, "buckle", ch=0.015, a=0.56, b=0.4)


def _skirt_ring(z, hw, hd, n=16):
	return [(hw * math.copysign(abs(math.cos(a)) ** 0.5, math.cos(a)), hd * math.copysign(abs(math.sin(a)) ** 0.5, math.sin(a)), z) for a in (2 * math.pi * j / n for j in range(n))]


def _skirt(k):
	"""The tunic's flared skirt from the belt to above the knee, and its gold hem."""
	rows = ((2.32, 1.07, 0.6), (1.94, 1.22, 0.72), (1.5, 1.38, 0.85))
	verts, faces, flat = k._loft([_skirt_ring(*r) for r in rows])
	bake(k._mesh("Skirt", "UpperTorso", verts, faces, flat, outline=0), "white", k, a=0.52, b=0.5, g=0.12)
	hem = ((1.64, 1.355, 0.835), (1.47, 1.41, 0.875))
	verts, faces, flat = k._loft([_skirt_ring(*r) for r in hem])
	bake(k._mesh("SkirtHem", "UpperTorso", verts, faces, flat, outline=0), "gold", k, a=0.56, b=0.4)


def _arm(k, side, s):
	"""White sleeve widening to a broad gold-hemmed cuff, and the plain block hand."""
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Mantle", s * 1.62, 0.04, 4.12, 3.4, 0.6, 0.74, "white", ch=0.08, flare=0.06, corner=0.3, a=0.56, b=0.42)
	block(k, arm, "MantleHem", s * 1.62, 0.04, 3.52, 3.34, 0.68, 0.84, "gold", ch=0.03, corner=0.3, a=0.56, b=0.4)
	block(k, arm, "Sleeve", ax, 0, 4.03, 2.36, 0.515, 0.515, "white", ch=0.08, flare=0.12, corner=0.18, jit=0.02, mids=(3.1,), a=0.54, b=0.44)
	block(k, arm, "CuffHem", ax, 0, 2.5, 2.3, 0.655, 0.655, "gold", ch=0.03, corner=0.18, a=0.56, b=0.4)
	block(k, arm, "Hand", ax, 0, 2.32, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.52
	# the tights are the leg block itself, full width
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.48, 0.5), (x, 0, 0.1, 0.48, 0.5)], corner=0.1, nc=1)
	block(k, leg, "Shaft", px, 0, 0.8, 0.0, 0.53, 0.59, "boot", ch=0.05, corner=0.18, jit=0.012, a=0.5, b=0.56)
	block(k, leg, "Toe", px, -0.36, 0.42, 0.0, 0.5, 0.44, "boot", ch=0.08, corner=0.24, a=0.54, b=0.56)
	# the folded-down top
	block(k, leg, "BootCuff", px, 0, 0.96, 0.7, 0.57, 0.63, "cuff", ch=0.04, corner=0.18, a=0.52, b=0.5)


def _staff(k):
	"""Upright in the right hand, grip at the hand's centre. Named Staff*: build_boss_mage.py joins these into one object;
	the portrait keeps it merged in the right arm, beside her."""
	import bpy
	from mathutils import Vector

	p = "RightHand"
	before = set(bpy.data.objects)
	block(k, p, "StaffButt", 0, 0, 0.42, 0.0, 0.1, 0.1, "gold", ch=0.04, a=0.56, b=0.44)
	block(k, p, "StaffShaft", 0, 0, 5.3, 0.38, 0.07, 0.07, "shaft", ch=0.02, a=0.5, b=0.4)
	block(k, p, "StaffWrap", 0, 0, 5.0, 4.58, 0.095, 0.095, "red", ch=0.02, a=0.52, b=0.44)
	prism(k, p, "StaffRibbon", [(0.04, 4.84), (0.16, 4.8), (0.3, 4.04), (0.2, 3.98), (0.17, 4.12)], -0.025, 0.025, "red", a=0.5, b=0.4)
	block(k, p, "StaffCollar", 0, 0, 5.62, 5.24, 0.11, 0.11, "gold", ch=0.04, flare=-0.03, a=0.56, b=0.44)
	c = (0.0, 0.0, 5.86)
	# the gem in its gold ring
	rod(k, p, "StaffRing", [(c[0] + 0.25 * math.cos(2 * math.pi * j / 8), 0, c[2] + 0.25 * math.sin(2 * math.pi * j / 8)) for j in range(9)], 0.065, "gold", n=4, a=0.58, b=0.4)
	rod(k, p, "StaffGem", [(c[0], 0.06, c[2]), (c[0], -0.04, c[2]), (c[0], -0.09, c[2])], [0.2, 0.2, 0.11], "gem", n=8, a=0.56, b=0.5)
	# the crescent: from under the ring round the viewer's right and over the top, curling in to a blunt end
	arc = []
	for j in range(10):
		a = math.radians(-80 + 220 * j / 9)
		rad = 0.5 - 0.06 * max(0, j - 6)
		arc.append((c[0] + rad * math.cos(a), 0, c[2] + rad * math.sin(a)))
	rod(k, p, "StaffMoon", arc, [0.06, 0.09, 0.11, 0.12, 0.12, 0.11, 0.1, 0.09, 0.09, 0.1], "gold", n=4, a=0.56, b=0.44)
	for o in set(bpy.data.objects) - before:
		for v in o.data.vertices:
			v.co += Vector(STAFF_AT)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_tails(k)
	_ears(k)
	_top(k)
	_skirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_staff(k)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=6):
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=WHITE_D, sw=sw, opacity=op, blur=2)


def _torso(a):
	"""White tunic open down the front over the black-and-white striped shirt, gold trim along the opening."""
	f = a["Torso_F"]
	f.fill(WHITE)
	opening = "M86 -5H114L140 205H60Z"
	f.path(opening, "#ffffff")
	for y in range(4, 205, 16):
		f.path(f"M40 {y}H160V{y + 8}H40Z", STRIPE)
	f.path("M-5 -5H86L60 205H-5Z", WHITE)
	f.path("M114 -5H205V205H140Z", WHITE)
	f.path("M86 -5L60 205", stroke=GOLD, sw=5)
	f.path("M114 -5L140 205", stroke=GOLD, sw=5)
	_fold(f, 14, 120, 30, 150, 48, 190, 0.45)
	_fold(f, 186, 120, 170, 150, 152, 190, 0.45)
	form(f, WHITE_D, 0.45)
	f = a["Torso_B"]
	f.fill(WHITE)
	_fold(f, 30, 60, 60, 90, 90, 120, 0.4)
	_fold(f, 170, 60, 140, 90, 110, 120, 0.4)
	form(f, WHITE_D, 0.45)
	for n in ("Torso_L", "Torso_R"):
		a[n].fill(WHITE)
		form(a[n], WHITE_D, 0.45)
	a["Torso_T"].fill(WHITE)
	a["Torso_Bo"].fill(WHITE_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(WHITE)
			a[f"{side}Leg_{key}"].fill("#202336")
		a[f"{side}Arm_T"].fill(WHITE)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill("#202336")
		a[f"{side}Leg_Bo"].fill("#141622")


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f4b0a0", top=22)
	# calm green eyes, the upper lids a little low; short thick pale brows; a small flat mouth
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 64, s, 34, 14, "#3e9a74", tilt=1.0, r=11, lid=0.22, lash="#5a5470", lash_t=3.2, flick=2.2, pupil=0.34, sclera="#fffdf8", crease_line=False)
		brow2(f, x + s * 2, 40, s, 19, 6.8, 0.0, "#a29cb8", arc=-1.0)
	f.soft("M61 86L65 81L69 86Q65 90 61 86Z", SKIN_D, 0.6, 1)
	f.path("M58 104Q65 106 72 104", stroke="#9a5a5a", sw=2.2)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.64))
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill("#d4d2e4")
	_torso(a)
	_limbs(a)
