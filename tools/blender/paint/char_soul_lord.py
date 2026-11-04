# Target look for soul_lord "Aizon" (design doc sections 4.30 and 5): brown hair slicked straight back with one loose strand down the
# middle of the face, no glasses, narrow calm brown eyes and a small closed smile; a long white coat with a tall flared collar open at
# the front over a black inner robe, a black sash, white hakama, dark shoes and a sheathed sword at his left hip. +X is the viewer's
# right in the front view. Drawn in-house. Evidence: docs/char_evidence/soul_lord.md.
import math

from atlas import shade
from db_style3 import pipe
from jk_common import eye2, form, nose
from jk_style3 import Kit, bake, big_head, block, dress_shoe, ears, face_base, finish, gem, head_rest, prism, sleeve, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#f1d3b8"
SKIN_D = "#c89f83"
COAT = "#eceae4"
COAT_D = "#a8a7ad"
INNER = "#14141a"
BROWN = "#3a2415"
DEFAULT = COAT
R = Ramps(
	hair=["#23140c", "#38210f", "#54331c", "#724a2b", "#936a45"],
	skin=["#b08d74", "#d8b79d", "#f1d3b8", "#fbe6d2"],
	coat=["#7d7e88", "#a9a9b0", "#cfced0", "#e8e6e1", "#f8f7f3"],
	hakama=["#74757f", "#9e9ea6", "#c3c2c6", "#dddcd9", "#efeeea"],
	black=["#060608", "#0f0f14", "#1d1d25", "#34343f"],
	shoe=["#08080b", "#121218", "#20212a", "#343642"],
	sole=["#040406", "#0b0b10", "#17171e", "#26262f"],
	sheath=["#0b0a10", "#17151f", "#2a2734", "#45414f"],
	wrap=["#12403f", "#1e6562", "#36908b", "#67bdb6"],
	guard=["#4a3a18", "#7e6529", "#b39546", "#e0c777"],
)
HAIR = {"colour": "#4A2E1C", "locks": []}
PROPS = []


def _mass(k):
	"""The slicked solid, lofted front to back with a ridged section, so the comb lines run the whole way as hard planes."""
	# y, half width, top, bottom
	rows = [(-0.88, 0.86, 5.7, 5.3), (-0.66, 0.96, 6.06, 5.28), (-0.2, 1.0, 6.24, 5.2), (0.4, 1.0, 6.16, 5.0), (0.84, 0.96, 5.84, 4.92), (0.98, 0.72, 5.38, 5.0)]
	# the hairline: x along the front's bottom edge, how far it dips; only the first two rows carry it
	dips = ((0.62, 0.0), (0.26, -0.03), (0.05, -0.12), (-0.05, -0.12), (-0.26, -0.03), (-0.62, 0.0))
	n = 12
	rings = []
	for r, (y, w, top, bot) in enumerate(rows):
		ring = []
		for j in range(n + 1):
			ang = math.pi * (1 - j / n)
			c, sn = math.cos(ang), abs(math.sin(ang))
			bump = 0.05 if j % 2 else 0.0
			ring.append((w * (1 + bump) * math.copysign(abs(c) ** 0.6, c), y, bot + (top - bot + bump) * sn**0.6))
		ring += [(w * x, y, bot + (dz if r < 2 else 0)) for x, dz in dips]
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Mass", "Head", verts, faces, flat, outline=0), "hair", k, a=0.36, b=0.42, g=0.06)


def _hair(k):
	_mass(k)
	block(k, "Head", "Nape", 0, 0.46, 5.2, 4.5, 0.72, 0.4, "hair", ch=0.05, corner=0.2, jit=0.015, a=0.34, b=0.34)
	for s in (1, -1):
		# the side plane: cut back round the ear, then in to the nape, inside the collar
		slab(k, f"Side{s}", [(-0.82, 5.5), (-0.8, 5.0), (-0.42, 5.1), (-0.14, 4.94), (0.2, 4.94), (0.24, 4.62), (0.66, 4.56), (0.86, 5.0), (0.9, 5.5)], s * 0.86, s * 0.98, "hair", a=0.36, b=0.4)
	# the back: overlapping lobes lying on the surface and hanging down, never pointing at the viewer behind him
	for i, (x, r) in enumerate(((-0.62, 0.27), (-0.2, 0.29), (0.22, 0.29), (0.62, 0.27))):
		gem(k, "Head", f"Upper{i}", (x * 0.94, 0.68, 5.96 - 0.16 * abs(x)), (x * 1.06, 0.98, 5.42 - 0.1 * abs(x)), r, flat=0.5, twist=0.1 + 0.05 * i, a=0.4, b_=0.44, across=(1, 0, 0))
	for i, (x, z, r) in enumerate(((-0.78, 5.12, 0.25), (-0.4, 5.06, 0.28), (0.0, 5.08, 0.29), (0.4, 5.06, 0.28), (0.78, 5.14, 0.25))):
		gem(k, "Head", f"Fall{i}", (x * 0.96, 0.92, 5.52), (x * 1.02, 1.0, z), r, flat=0.5, twist=0.2 + 0.05 * i, a=0.34, b_=0.42, across=(1, 0, 0))
	# two swept points leaving the sides behind the ears
	for s in (1, -1):
		gem(k, "Head", f"Wing{s}", (s * 0.84, 0.3, 5.74), (s * 1.1, 1.02, 5.3), 0.24, flat=0.5, twist=0.2, a=0.4, b_=0.44, across=(0, 0, 1))
	# the one loose strand: root at the hairline, a small S down to the bridge of the nose
	gem(k, "Head", "StrandRoot", (-0.02, -0.86, 5.3), (0.09, -0.97, 4.94), 0.1, flat=0.5, across=(1, 0, 0), a=0.4, b_=0.44)
	gem(k, "Head", "StrandTip", (0.08, -0.95, 5.02), (-0.03, -0.97, 4.5), 0.085, flat=0.5, across=(1, 0, 0), a=0.4, b_=0.44)


def _collar(k):
	"""Tall, open at the front and flaring away from the head: low at the front corners, its highest point behind the head."""
	rings = []
	n = 16
	for j in range(n + 1):
		ang = math.radians(-90 + 40 + (360 - 80) * j / n)
		c, sn = math.cos(ang), math.sin(ang)
		px, py = math.copysign(abs(c) ** 0.35, c), math.copysign(abs(sn) ** 0.35, sn)
		top = 4.42 + 0.6 * ((sn + 1) / 2) ** 0.8
		out = lambda r: (r * px, r * 0.96 * py)
		rows = [(0.9 * px, 0.54 * py, 3.92), (*out(1.0), 4.16), (*out(1.14), top), (*out(1.08), top), (*out(0.96), 4.16), (0.86 * px, 0.5 * py, 3.92)]
		rings.append(rows)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Collar", "UpperTorso", verts, faces, flat, outline=0), "coat", k, a=0.54, b=0.44)


def _coat(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	_collar(k)
	# the raised lapels of the V, meeting above the sash
	for s in (1, -1):
		prism(k, t, f"Edge{s}", [(s * 0.66, 3.98), (s * 0.86, 3.98), (s * 0.08, 2.66), (0, 2.72)], -0.615, -0.56, "coat", a=0.6, b=0.36)
	block(k, t, "Sash", 0, 0, 2.5, 2.16, 1.09, 0.61, "black", ch=0.03, corner=0.14, sub=1, a=0.48, b=0.34)


def _sword(k):
	"""Sheathed through the sash at his left hip, the hilt forward, the tip behind."""
	t = "UpperTorso"
	a, tip = (0.84, -0.96, 2.66), (0.96, 1.24, 2.06)  # the tip stays above z 2 so the running skirt never meets it
	lerp = lambda u: tuple(a[i] + (tip[i] - a[i]) * u for i in range(3))
	pipe(k, t, "Sheath", [lerp(0.08) + (0.095,), lerp(0.6) + (0.105,), lerp(0.97) + (0.095,), lerp(1.0) + (0.05,)], "sheath", rn=6, base=0.46, amp=0.42, grad=0.0)
	pipe(k, t, "Guard", [lerp(0.05) + (0.18,), lerp(0.08) + (0.18,)], "guard", rn=6, base=0.5, amp=0.4, grad=0.0)
	pipe(k, t, "Hilt", [(0.8, -1.42, 2.92, 0.08), lerp(0.1) + (0.085,)], "wrap", rn=6, base=0.5, amp=0.4, grad=0.0)


def _skirt(k, leg, s):
	"""One half of the long coat skirt: opens at the front, wraps round the outside, meets its twin at a slit behind so the legs can run."""
	cols = [(0.46, -0.66, 0.52), (1.04, -0.66, 0.46), (1.13, -0.58, 0.44), (1.13, 0.58, 0.38), (1.04, 0.66, 0.36), (0.54, 0.67, 0.34), (0.03, 0.67, 0.34)]
	rings = []
	for r in (0.0, 0.35, 0.7, 1.0):
		flare = 1 + 0.07 * r
		outer, inner = [], []
		for i, (x, y, hem) in enumerate(cols):
			z = 2.0 + (hem - 2.0) * r
			fx = x if x < 0.1 else x * flare
			fold = 0.018 * math.sin(i * 2.1 + r * 4) * (0 < r < 1)
			outer.append((s * fx, y * flare + fold, z))
			inner.append((s * (fx - 0.05 if x > 0.1 else fx), (y - 0.05 * (1 if y > 0 else -1)) * flare + fold, z))
		rings.append(outer + inner[::-1])
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Skirt", leg, verts, faces, flat, outline=0), "coat", k, a=0.52, b=0.5, g=0.1)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.49, 0.55, "hakama", ch=0.04, flare=0.02, corner=0.16, jit=0.025, mids=(1.55,), a=0.46, b=0.56, tone=0.04)
	block(k, leg, "Shin", px, 0, 1.18, 0.3, 0.5, 0.56, "hakama", ch=0.04, flare=0.03, corner=0.16, jit=0.025, mids=(0.72,), a=0.46, b=0.56, tone=0.04)
	_skirt(k, leg, s)
	dress_shoe(k, leg, px, top=0.4)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.74)
	_hair(k)
	_coat(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="coat", cuff=2.3)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=7):
	"""A cloth fold on white: a soft cool shadow and no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=COAT_D, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(COAT)
	# the V: a black inner robe, closing on a small wedge of bare neck
	f.path("M36 -5H164L100 124Z", INNER)
	f.path("M66 -5H134L100 58Z", SKIN)
	f.soft("M66 -5H134V16H66Z", SKIN_D, 0.8, 3)
	f.path("M64 -5L100 62L136 -5L132 -5L100 54L68 -5Z", "#2d2d38")
	_fold(f, 16, 40, 42, 84, 80, 120)
	_fold(f, 184, 42, 158, 86, 120, 122)
	_fold(f, 26, 120, 40, 140, 30, 156, 0.4, 6)
	_fold(f, 174, 122, 160, 142, 170, 156, 0.4, 6)
	f.path("M100 180L88 205H112Z", COAT_D, opacity=0.9)
	form(f, COAT_D, 0.5)
	f = a["Torso_B"]
	f.fill(COAT)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	_fold(f, 40, 128, 48, 150, 38, 172, 0.45, 6)
	_fold(f, 160, 128, 152, 150, 162, 172, 0.45, 6)
	stroke(f, "M100 178V205", COAT_D, 2.2, 0.9)
	form(f, COAT_D, 0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(COAT)
		_fold(f, 20, 40, 34, 90, 26, 150, 0.4, 6)
		form(f, COAT_D, 0.5)
	a["Torso_T"].fill(COAT)
	a["Torso_Bo"].fill(COAT_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(COAT)
			a[f"{side}Leg_{key}"].fill(shade(COAT, 0.92))
		a[f"{side}Arm_T"].fill(COAT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(COAT)
		a[f"{side}Leg_Bo"].fill(COAT_D)


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#e8b090", top=8)
	# the strand drops a soft shadow down the bare forehead
	f.soft("M60 -5Q70 20 66 58L72 58Q78 20 70 -5Z", SKIN_D, 0.55, 2)
	for cx, s in ((38, -1), (92, 1)):
		eye2(f, cx, 62, s, 32, 11, "#6e4324", tilt=-1.6, r=8, lid=0.42, lash="#22140d", lash_t=2.6, flick=2.5, pupil=0.4, crease_line=True)
		# long level brows: no anger in them
		f.path(f"M{cx - s * 15} 43Q{cx} 40 {cx + s * 17} 39.5L{cx + s * 17} 41.5Q{cx} 42.8 {cx - s * 15} 45.5Z", BROWN)
	nose(f, SKIN, y=70, h=15)
	# a small closed smile: thin, lifting at both corners
	stroke(f, "M50 102Q65 109 80 102", "#6a3a2a", 1.8)
	stroke(f, "M49 103Q48 101 48 99", "#6a3a2a", 1.2)
	stroke(f, "M81 103Q82 101 82 99", "#6a3a2a", 1.2)
	f.soft("M58 110Q65 113 72 110Q65 115 58 110Z", SKIN_D, 0.5, 1)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.86), shade(SKIN, 0.78))
	a["Head_T"].fill("#38210f")
	_torso(a)
	_limbs(a)
