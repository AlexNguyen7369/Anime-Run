# Target look for foe_sea (design doc section 5, 4.26), display name Arlon: a huge light-blue saw-nosed sea man. Long serrated
# snout, jagged grin, gill slits, wild black hair to the shoulders, a small flat straw hat, open flower shirt over a bare chest
# with the altered sun mark on the character's left, orange sash, brown knee shorts, bare shins, sandals.
# +X is the viewer's right and the character's left.
import math

from atlas import INK, shade
from leaf_common import begin_clip, end_clip
from sea_common import arm_muscle, chest, circle, leg_muscle
from sea_style3 import bake, block, eye, gem, head_base, head_sides, jitter, prism
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#7fbcdc"
SKIN_D = "#4d86ad"
SKIN_L = "#aad8ee"
BLACK = "#14141c"
SHIRT = "#e6c23c"
RED = "#c81e2a"
DEFAULT = SHIRT
R = Ramps(
	hair=["#08080e", "#14141e", "#22222e", "#363648", "#54546e"],
	skin=["#4078a0", "#5f9cc2", "#7fbcdc", "#aad8ee"],
	collar=["#7a5a10", "#a8821c", "#c8a02c", "#e6c23c"],
	sash=["#8a3206", "#c4520e", "#ec7a1c", "#f8a044"],
	pant=["#2c1a0e", "#4a2e18", "#6a4426", "#8a5e38"],
	sandal=["#1e1208", "#3a2412", "#5a3a1e", "#7c5430"],
	straw=["#8c6c2c", "#b8964a", "#dcc070", "#f2dc98"],
	band=["#4a0a10", "#801420", "#b0242c", "#d84a48"],
	tooth=["#a8b4bc", "#d8dee2", "#f4f6f8", "#ffffff"],
)
HAIR = {"colour": BLACK, "locks": []}
PROPS = []
# the shirt's open edge, (x, z): the chest art ends exactly here so the panels sample flowers and the V samples skin
EDGE = [(0.62, 4.0), (0.78, 3.4), (0.74, 2.08)]


def _snout(k):
	"""The saw: a diamond section along y whose width and height alternate, so teeth jut out on both edges. Tilts up a little."""
	rings = []
	n = 19
	for i in range(n):
		t = i / (n - 1)
		y = -0.76 - 1.3 * t
		z = 4.56 + 0.22 * t
		base = 0.19 * (1 - t) + 0.05 * t
		tooth = i % 2 == 1 and i < n - 1
		w = base + (0.13 * (1 - t * 0.45) if tooth else 0.0)
		h = (0.13 * (1 - t) + 0.035 * t) * (1.25 if tooth else 1.0)
		# each tooth leans back towards the face
		yy = y + (0.035 if tooth else 0.0)
		rings.append([(w, yy, z), (0, yy, z + h), (-w, yy, z), (0, yy, z - h)])
	verts, faces, flat = k._loft(rings)
	bake(k, k._mesh("Snout", "Head", verts, faces, flat, outline=0), "skin", a=0.56, b=0.46, g=0.04)


def _hair(k):
	bake(k, k.lathe("Head", "Crown", [(0.92, 5.3, 0.5), (1.0, 5.5, 0.5), (0.98, 5.76, 0.5), (0.66, 5.98, 0.5), (0.16, 6.06, 0.5)], "hair", n=10, at=(0, 0.04, 0), squash=0.95, outline=0), "hair", a=0.42, b=0.4)
	back = k.tube("Head", "Mass", [(0, 0.46, 5.3, 0.98, 0.46), (0, 0.5, 4.5, 1.0, 0.44), (0, 0.6, 4.15, 0.92, 0.3)], "hair", corner=0.3, nc=1, sub=1, outline=0)
	jitter(back, 0.03)
	bake(k, back, "hair", a=0.36, b=0.42, g=0.1)
	# the widow's peak, sharp over the snout
	gem(k, "Head", "Peak", (0, -0.74, 5.72), (0, -0.92, 5.04), 0.3, flat=0.45, twist=0.3, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"Brow{s}", (s * 0.3, -0.74, 5.74), (s * 0.82, -0.92, 5.2), 0.3, flat=0.45, twist=0.2, across=(1, 0, 0.3))
		gem(k, "Head", f"Temple{s}", (s * 0.84, -0.56, 5.6), (s * 1.18, -0.72, 4.92), 0.26, flat=0.45, twist=0.4, across=(0, 1, 0))
		# wild side spikes flung outwards, shoulder length
		for i, (y0, z0, x1, y1, z1, r) in enumerate(((-0.2, 5.62, 1.5, -0.24, 5.52, 0.34), (0.2, 5.58, 1.56, 0.2, 5.14, 0.36), (0.1, 5.2, 1.5, 0.12, 4.58, 0.34), (0.42, 5.1, 1.42, 0.56, 4.28, 0.36), (0.2, 4.8, 1.2, 0.3, 4.16, 0.3))):
			gem(k, "Head", f"Side{s}{i}", (s * 0.8, y0, z0), (s * x1, y1, z1), r, flat=0.5, twist=0.2 + 0.17 * i, across=(0, 1, 0))
	for i, (x, dx, z0, z1, r) in enumerate(((-0.62, -0.28, 5.5, 3.96, 0.42), (0.0, 0.1, 5.6, 3.82, 0.44), (0.62, 0.28, 5.5, 3.96, 0.42), (-0.32, -0.1, 5.0, 3.62, 0.36), (0.32, 0.1, 5.0, 3.62, 0.36))):
		gem(k, "Head", f"Back{i}", (x, 0.84, z0), (x + dx, 1.08, z1), r, flat=0.42, twist=0.2 + 0.13 * i, across=(1, 0, 0))
	for i, (x0, y0, x1, y1, z1) in enumerate(((-0.5, -0.3, -1.24, -0.46, 6.04), (0.5, -0.3, 1.24, -0.46, 6.04), (-0.46, 0.32, -1.2, 0.62, 5.98), (0.46, 0.32, 1.2, 0.62, 5.98))):
		gem(k, "Head", f"Top{i}", (x0, y0, 5.82), (x1, y1, z1), 0.38, flat=0.55, twist=0.25 + 0.14 * i)
	# a small flat hat sits on the crown
	bake(k, k.lathe("Head", "Hat", [(0.5, 6.0, 0.4), (0.74, 6.04, 0.5), (0.74, 6.09, 0.6), (0.5, 6.11, 0.6), (0.46, 6.32, 0.7), (0.4, 6.36, 0.8), (0.02, 6.36, 0.8)], "straw", n=10, at=(0, 0.04, 0), squash=0.92, outline=0), "straw", a=0.56, b=0.42)
	bake(k, k.lathe("Head", "HatBand", [(0.5, 6.1, 0.5), (0.51, 6.2, 0.5), (0.46, 6.2, 0.5)], "band", n=10, at=(0, 0.04, 0), squash=0.92, outline=0), "band", a=0.5, b=0.42)


def _panel(k, name, pts, y0, y1):
	"""A shirt panel wearing the torso art at its true place, so the flowers run on from the body."""
	n = len(pts)
	verts = [(x, y0, z) for x, z in pts] + [(x, y1, z) for x, z in pts]
	faces = [(j, (j + 1) % n, n + (j + 1) % n, n + j) for j in range(n)] + [list(range(n)), list(range(2 * n - 1, n - 1, -1))]
	o = k._mesh(name, "UpperTorso", verts, faces, outline=0)
	k._face_uv(o, "Torso", [(v[0], v[1] * 0.8) for v in verts])


def _torso(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.98, 1.0, 0.5), (0, 0, 2.02, 1.0, 0.5)], corner=0.1, nc=1)
	# the back and sides of the shirt; its front wall hides inside the body
	k.tube(t, "ShirtBack", [(0, 0.18, 4.0, 1.06, 0.38), (0, 0.18, 2.08, 1.09, 0.4)], ("face", "Torso"), corner=0.1, nc=1, outline=0)
	for s in (1, -1):
		pts = [(s * EDGE[0][0], EDGE[0][1]), (s * 1.06, 4.0), (s * 1.09, 2.08), (s * EDGE[2][0], EDGE[2][1]), (s * EDGE[1][0], EDGE[1][1])]
		_panel(k, f"Panel{s}", pts, -0.6, -0.14)
		# a strip down the open edge, and the lapel folded back at the neck
		prism(k, t, f"Placket{s}", [(s * 0.58, 4.0), (s * 0.68, 4.0), (s * 0.82, 3.4), (s * 0.78, 2.08), (s * 0.7, 2.08), (s * 0.74, 3.4)], -0.63, -0.56, "collar", a=0.56, b=0.5, g=0.1)
		prism(k, t, f"Lapel{s}", [(s * 0.5, 4.04), (s * 1.0, 4.04), (s * 0.96, 3.62), (s * 0.72, 3.42)], -0.68, -0.62, "collar", a=0.6, b=0.5)
	block(k, t, "Hips", 0, 0, 2.2, 1.88, 1.02, 0.53, "pant", ch=0.02, a=0.46, b=0.5)
	block(k, t, "Sash", 0, 0, 2.52, 2.14, 1.02, 0.55, "sash", ch=0.04, corner=0.2, sub=2, jit=0.024, a=0.52, b=0.56, tone=0.05)
	block(k, t, "SashKnot", 0.34, -0.58, 2.5, 2.2, 0.17, 0.08, "sash", ch=0.03, jit=0.016, a=0.62, b=0.5)
	prism(k, t, "SashTail", [(0.2, 2.26), (0.5, 2.26), (0.54, 2.0), (0.18, 2.0)], -0.66, -0.58, "sash", a=0.56, b=0.5, g=0.1)
	prism(k, "LeftUpperLeg", "SashTail2", [(0.18, 2.0), (0.54, 2.0), (0.58, 1.3), (0.4, 1.42), (0.2, 1.28)], -0.66, -0.58, "sash", a=0.52, b=0.5, g=0.12)


def _arm(k, s, side):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 4.03, 0.42, 0.42), (ax, 0, 3.94, 0.48, 0.48), (ax, 0, 2.3, 0.48, 0.48), (ax, 0, 2.24, 0.44, 0.44)], corner=0.14, nc=1)
	k.tube(arm, "Sleeve", [(ax, 0, 4.05, 0.46, 0.46), (ax, 0, 3.96, 0.54, 0.54), (ax, 0, 3.12, 0.56, 0.56)], ("face", f"{side}Arm"), corner=0.16, nc=1, outline=0)
	block(k, arm, "Cuff", ax, 0, 3.18, 3.06, 0.58, 0.58, "collar", ch=0.025, corner=0.16, a=0.56, b=0.46)
	block(k, arm, "Hand", ax, 0, 2.32, 1.8, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)


def _leg(k, s, side):
	part = f"{side}UpperLeg"
	px = s * 0.52
	k.reshape(part, f"{side}Leg", [(s * 0.5, 0, 1.98, 0.47, 0.47), (s * 0.5, 0, 0.1, 0.47, 0.47)], corner=0.1, nc=1)
	block(k, part, "Shorts", px, 0, 1.97, 0.98, 0.49, 0.52, "pant", ch=0.03, flare=0.04, corner=0.14, jit=0.016, mids=(1.4,), a=0.46, b=0.54, g=0.1, tone=0.03)
	block(k, part, "Hem", px, 0, 1.04, 0.92, 0.54, 0.57, "pant", ch=0.02, corner=0.14, a=0.62, b=0.44)
	# a bare foot on a flat sandal, one broad strap
	block(k, part, "Foot", px, -0.14, 0.32, 0.1, 0.49, 0.62, "skin", ch=0.06, corner=0.2, a=0.6, b=0.32)
	block(k, part, "Strap", px, -0.26, 0.28, 0.16, 0.51, 0.16, "sandal", ch=0.02, a=0.56, b=0.46)
	block(k, part, "Sole", px, -0.14, 0.1, 0.0, 0.52, 0.66, "sandal", ch=0.02, a=0.42, b=0.3)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_snout(k)
	_hair(k)
	_torso(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


# ---- paint


def _flowers(f, step=44):
	"""Big loud blooms and leaves on the shirt ground, offset every other row."""
	f.fill(SHIRT)
	r = f.rng
	y, row = -6, 0
	while y < f.h + 10:
		x = -8 + (step / 2 if row % 2 else 0)
		while x < f.w + 10:
			cx, cy = x + r.uniform(-5, 5), y + r.uniform(-5, 5)
			for a, b in ((-13, -9), (12, 11), (-11, 12)):
				f.path(f"M{cx} {cy}Q{cx + a * 0.3} {cy + b} {cx + a} {cy + b}Q{cx + a} {cy + b * 0.3} {cx} {cy}Z", "#2e8a4a")
			col = r.choice((RED, RED, "#e0407a", "#f07028"))
			for dx, dy in ((0, -8), (7.6, -2.5), (4.7, 6.5), (-4.7, 6.5), (-7.6, -2.5)):
				f.path(circle(cx + dx, cy + dy, 5.6), col)
				f.path(circle(cx + dx * 1.1, cy + dy * 1.1, 2.2), shade(col, 1.35), opacity=0.7)
			f.path(circle(cx, cy, 3.4), "#fff0a0")
			x += step
		y += step * 0.72
		row += 1
	f.soft(f"M-5-5H{f.w + 5}V8H-5Z", "#7a5a10", 0.3, 3)


def _sun_mark(f, cx, cy, r):
	"""Altered mark: same place, size and red as the source's sun, but straight spikes and a hollow ring with a crescent."""
	pts = []
	for i in range(16):
		q = r if i % 2 == 0 else r * 0.58
		a = math.pi * i / 8 - math.pi / 2
		pts.append(f"{cx + q * math.cos(a):.1f} {cy + q * math.sin(a):.1f}")
	f.path("M" + "L".join(pts) + "Z", RED)
	f.path(circle(cx, cy, r * 0.46), SKIN)
	f.path(circle(cx, cy, r * 0.32), RED)
	f.path(circle(cx + r * 0.1, cy - r * 0.08, r * 0.25), SKIN)


def _gills(f, x, y, s, n=3, step=14, length=26):
	"""Gill slits: long dark curved cuts, a lit lip under each. s is the way they bow."""
	for i in range(n):
		xx = x + i * step
		f.path(f"M{xx} {y}Q{xx + s * 6} {y + length / 2} {xx} {y + length}", stroke="#1c3c58", sw=3.2)
		f.path(f"M{xx + 2.4} {y + 2}Q{xx + 2.4 + s * 6} {y + length / 2} {xx + 2.4} {y + length - 2}", stroke=SKIN_L, sw=1.1, opacity=0.8)


def _face(a):
	f = a["Head_F"]
	head_base(f, SKIN, SKIN_D, SKIN_L, hair_shadow=24)
	# the hairline dives to a sharp point between the brows
	f.path("M-5-5H135V24L110 18L92 26L72 22L65 42L58 22L38 26L20 18L-5 24Z", BLACK)
	# hard narrow eyes, small irises, heavy angry lids
	for cx, s in ((37, -1), (93, 1)):
		eye(f, cx, 60, s, "#c89a1e", "#3a2808", "#ecd070", w=33, up=11, down=8, inner=7, outer=-7, wing=3.5, lid=5, ry=7.5)
		ib, ob = 65 + s * 7, 65 + s * 50
		f.path(f"M{ib} 58L{ib + s * 2} 46L{ob} 32L{ob - s * 1} 44L{ib + s * 2} 60Z", BLACK)
	# the root of the snout: a shadow where it leaves the face
	f.soft("M47 62H83L90 84Q65 96 40 84Z", SKIN_D, 0.8, 2)
	# the jagged grin, ear to ear: white teeth, a zigzag where they meet
	mouth = "M9 92Q65 104 121 92Q118 112 100 120Q65 130 30 120Q12 112 9 92Z"
	begin_clip(f, mouth)
	f.path(mouth, "#fbfaf4")
	zig = "M5 104"
	for i in range(12):
		x = 14 + i * 9.4
		zig += f"L{x} {96 if i % 2 else 118}"
	f.path(zig + "L125 104", stroke="#12101a", sw=2.4)
	end_clip(f)
	f.path(mouth, stroke=INK, sw=2.4)
	head_sides(a, SKIN, SKIN_D, hair=BLACK, hair_y=46)
	_gills(a["Head_L"], 34, 76, 1, step=12, length=30)
	_gills(a["Head_R"], 60, 76, -1, step=12, length=30)
	for n in ("Head_B", "Head_T"):
		a[n].fill(BLACK)


def _chest(f):
	_flowers(f)
	(x0, y0), (x1, y1), (x2, _) = [(100 * x, (4 - z) * 100) for x, z in EDGE]
	bare = f"M{100 - x0} -5H{100 + x0}L{100 + x1} {y1}L{100 + x2} 210H{100 - x2}L{100 - x1} {y1}Z"
	begin_clip(f, bare)
	f.fill(SKIN)
	chest(f, SKIN, w=0.92)
	# gill slits low on the ribs, either side, just inside the open shirt
	_gills(f, 34, 104, -1, step=11, length=30)
	_gills(f, 144, 104, 1, step=11, length=30)
	_sun_mark(f, 146, 56, 24)
	end_clip(f)


def paint(a):
	R.paint(a)
	_face(a)
	_chest(a["Torso_F"])
	for n in ("Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		_flowers(a[n])
	a["Torso_Bo"].fill(shade("#6a4426", 0.7))
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			arm_muscle(f, side, key, SKIN, y0=0, wrist=176)
			f.path("M-5 176H105V210H-5Z", SKIN)
			# the sleeve's art goes on last: the muscle shading would bleed over it
			begin_clip(f, "M-5-5H105V92H-5Z")
			_flowers(f, step=36)
			end_clip(f)
			f = a[f"{side}Leg_{key}"]
			f.fill("#4a2e18")
			leg_muscle(f, SKIN, 90, 200)
		_flowers(a[f"{side}Arm_T"], step=36)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill("#4a2e18")
		a[f"{side}Leg_Bo"].fill(SKIN_D)
