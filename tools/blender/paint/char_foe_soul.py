# Target look for foe_soul "Ulquiorro" (design doc sections 4.32 and 5): straight unkempt black hair to the jaw with thin flying points,
# a broken bone helm on the upper side of his left head with a tall horn, an arched brow rim and ribbed lobes behind the ear; chalk skin,
# sad green slit eyes with a thin teal line running down from each; a closed white jacket with a raised black-lined collar, a small V at
# the throat over the hole in his sternum, a black zip line, a wide black sash, two long coat tails lined in black, white hakama, black
# socks, white shoes and a green sheathed sword at his left hip. +X is the viewer's right in the front view. Drawn in-house.
# Evidence: docs/char_evidence/foe_soul.md.
import math

from atlas import shade
from db_style3 import pipe
from jk_common import eye2, form, nose
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, finish, gem, head_rest, prism, sleeve, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#f2f1e8"
SKIN_D = "#bfc0bb"
COAT = "#eceef0"
COAT_D = "#a2a7b6"
HOLE = "#06060b"
TEAL = "#1d8a80"
DEFAULT = COAT
R = Ramps(
	hair=["#030305", "#090a10", "#13141c", "#22242f", "#3a3d4c"],
	skin=["#a5a6a0", "#cfd0c8", "#efefe6", "#fbfbf4"],
	coat=["#7b8092", "#a6abb9", "#cfd2d9", "#e9ebee", "#fafbfb"],
	hakama=["#6e7386", "#999eaf", "#c1c5d0", "#dcdfe5", "#eff1f4"],
	bone=["#6d6677", "#a59ca7", "#d6cfc9", "#f0ebdd", "#fffdf3"],
	black=["#050507", "#0d0d12", "#1b1b24", "#333441"],
	shoe=["#8f93a3", "#c3c6cf", "#e6e8ec", "#fbfbfc"],
	sole=["#55586a", "#7d8090", "#a6a9b6", "#c8cad3"],
	green=["#07241a", "#0f3f2b", "#1b6143", "#37946b"],
	wrap=["#0b1f18", "#123326", "#1f523c", "#3b7d5e"],
	guard=["#1b211d", "#2f3a33", "#4e5d53", "#7c8c81"],
)
HAIR = {"colour": "#0B0D14", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.3), (1.04, 5.6), (0.96, 5.88), (0.58, 6.12), (0.16, 6.2)])
	block(k, "Head", "Back", 0, 0.28, 5.46, 4.46, 0.92, 0.6, "hair", ch=0.06, corner=0.3, jit=0.03, sub=1, mids=(5.0,), a=0.42, b=0.44)
	slab(k, "SideR", [(-0.72, 5.46), (-0.7, 4.82), (-0.34, 4.5), (0.46, 4.44), (0.86, 4.7), (0.86, 5.46)], -0.8, -0.97, "hair", a=0.42, b=0.46)
	slab(k, "SideL", [(-0.3, 5.3), (-0.26, 4.8), (0.1, 4.54), (0.5, 4.44), (0.86, 4.7), (0.86, 5.3)], 0.8, 0.95, "hair", a=0.42, b=0.46)
	# his right: long straight locks to the jaw and collar, the outer ones flying out in thin points
	for i, (b, t, r) in enumerate(
		(
			((-0.9, -0.62, 5.5), (-0.98, -0.76, 4.2), 0.22),
			((-0.95, -0.3, 5.5), (-1.08, -0.42, 4.06), 0.25),
			((-0.95, 0.05, 5.5), (-1.14, -0.02, 4.1), 0.25),
			((-0.92, 0.4, 5.5), (-1.08, 0.42, 4.14), 0.24),
			((-0.95, -0.1, 5.3), (-1.56, -0.28, 4.5), 0.17),
			((-0.92, 0.32, 5.4), (-1.62, 0.5, 4.86), 0.16),
			((-0.98, -0.5, 5.0), (-1.38, -0.62, 4.28), 0.13),
		)
	):
		gem(k, "Head", f"RightLock{i}", b, t, r, flat=0.42, twist=0.2 + 0.12 * i, a=0.42, b_=0.5)
	# his left: what shows below the helm's lobes
	for i, (b, t, r) in enumerate((((0.88, -0.5, 5.0), (0.98, -0.66, 4.24), 0.17), ((0.9, -0.14, 5.0), (1.04, -0.2, 4.14), 0.2), ((0.9, 0.22, 4.9), (1.34, 0.34, 4.36), 0.14))):
		gem(k, "Head", f"LeftLock{i}", b, t, r, flat=0.42, twist=0.25 + 0.1 * i, a=0.42, b_=0.5)
	# the back: straight locks lying on the surface, falling to the collar; on his left they start below the helm
	for i, (x, top, z, r) in enumerate(((-0.78, 5.84, 4.84, 0.26), (-0.46, 5.96, 4.72, 0.29), (-0.24, 5.9, 4.8, 0.24), (0.2, 5.44, 4.68, 0.26), (0.5, 5.44, 4.8, 0.26), (0.82, 5.44, 4.74, 0.23))):
		gem(k, "Head", f"Back{i}", (x * 0.92, 0.78, top), (x * 1.04, 1.02, z), r, flat=0.4, twist=0.12 + 0.05 * i, a=0.4, b_=0.46, across=(1, 0, 0))
	# the fringe: heavy over his right brow, one long lock falling between the eyes
	root = (-0.28, -0.82, 5.74)
	for i, (t, r) in enumerate((((-0.86, -0.92, 4.74), 0.22), ((-0.62, -0.95, 4.96), 0.24), ((-0.34, -0.96, 4.98), 0.22), ((-0.12, -0.97, 4.84), 0.2), ((0.05, -0.98, 4.5), 0.13))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.14 * i, a=0.46, b_=0.5, across=(0, 0, 1))
	# two thin locks slipping out from under the brow rim
	gem(k, "Head", "UnderRim0", (0.2, -0.92, 5.2), (0.17, -0.97, 4.72), 0.08, flat=0.4, a=0.44, across=(1, 0, 0))
	gem(k, "Head", "UnderRim1", (0.72, -0.92, 5.1), (0.76, -0.96, 4.72), 0.09, flat=0.4, a=0.44, across=(1, 0, 0))


def _helm(k):
	"""The broken bone helm on the upper side of his left: a dome, a brow rim arched over the eye, a broken edge along the middle, a tall horn, ribbed lobes."""
	rows = [(0.42, 0.0, 5.24, 0.64, 0.9), (0.42, 0.0, 5.5, 0.66, 0.95), (0.42, 0.0, 5.84, 0.64, 0.94), (0.4, 0.0, 6.1, 0.54, 0.76), (0.36, -0.02, 6.3, 0.36, 0.42), (0.34, -0.02, 6.38, 0.14, 0.16)]
	bake(k.tube("Head", "HelmDome", rows, "bone", corner=0.45, nc=1, sub=1, outline=0), "bone", k, a=0.5, b=0.44, g=0.06)
	# the brow rim: a tooth down by the nose, arched over the eye, then a long point down the temple
	rim = [(0.0, 5.4), (0.3, 5.46), (1.06, 5.42), (1.08, 5.0), (1.0, 4.56), (0.84, 5.04), (0.66, 5.14), (0.45, 5.18), (0.24, 5.12), (0.06, 4.82), (-0.03, 5.08)]
	prism(k, "Head", "BrowRim", rim, -0.96, -0.84, "bone", a=0.56, b=0.32)
	# a raised ridge following the arch
	ridge = [(0.02, 5.34), (0.4, 5.44), (0.8, 5.38), (1.06, 5.2), (1.06, 5.05), (0.82, 5.2), (0.44, 5.3), (0.1, 5.2)]
	prism(k, "Head", "BrowRidge", ridge, -0.98, -0.96, "bone", a=0.7, b=0.26)
	# the side: comes down by the ear, its edge a line of steps, a ridge running back from the brow
	slab(k, "HelmSide", [(-0.9, 5.5), (-0.6, 5.7), (0.5, 5.7), (0.84, 5.4), (0.82, 5.1), (0.36, 5.14), (0.0, 4.98), (-0.34, 5.02), (-0.62, 4.7), (-0.9, 4.62)], 0.98, 1.06, "bone", a=0.5, b=0.38)
	slab(k, "HelmSideRidge", [(-0.86, 5.3), (-0.4, 5.46), (0.3, 5.46), (0.7, 5.2), (0.66, 5.12), (0.25, 5.28), (-0.38, 5.28), (-0.86, 5.08)], 1.06, 1.1, "bone", a=0.68, b=0.28)
	# the broken edge along the middle of the head: flat shards lying on the hair
	for i, (b, t, r) in enumerate((((-0.14, -0.58, 5.8), (-0.42, -0.68, 5.92), 0.17), ((-0.14, -0.12, 6.0), (-0.44, -0.16, 6.14), 0.19), ((-0.12, 0.36, 5.96), (-0.4, 0.46, 6.04), 0.18))):
		gem(k, "Head", f"Shard{i}", b, t, r, "bone", flat=0.35, twist=0.2, a=0.54, b_=0.38)
	# the tall horn: out from the side, then up
	gem(k, "Head", "Horn", (0.74, -0.14, 5.86), (1.52, -0.24, 7.2), 0.38, "bone", flat=0.72, bend=-0.17, twist=0.2, a=0.56, b_=0.4)
	# the ribbed lobes behind the ear, stepping down the side of the head
	for i, (z, r) in enumerate(((5.2, 0.2), (4.97, 0.19), (4.74, 0.17), (4.52, 0.14))):
		gem(k, "Head", f"Lobe{i}", (0.92, 0.28 - 0.1 * i, z + 0.02), (1.32 - 0.07 * i, 0.76 - 0.03 * i, z - 0.1), r, "bone", flat=0.55, twist=0.15, a=0.5, b_=0.42, across=(0, 0, 1))


def _collar(k):
	"""Raised and open at the throat, highest behind the head: white outside, black inside."""
	t = "UpperTorso"
	for name, ramp, r0, r1, drop, bk in (("Collar", "coat", 1.1, 1.05, 0.0, dict(a=0.52, b=0.44)), ("CollarLining", "black", 1.05, 1.01, 0.03, dict(a=0.5, b=0.3))):
		rings = []
		n = 14
		for j in range(n + 1):
			ang = math.radians(-90 + 30 + (360 - 60) * j / n)
			c, sn = math.cos(ang), math.sin(ang)
			px, py = math.copysign(abs(c) ** 0.32, c), math.copysign(abs(sn) ** 0.32, sn)
			top = 4.4 + 0.36 * ((sn + 1) / 2) ** 0.75 - drop
			d0, d1 = 0.93 * r0 * py, 0.93 * r1 * py
			rings.append([(0.9 * px, 0.54 * py, 3.92), (r0 * px, d0, 4.14), (r0 * px, d0, top), (r1 * px, d1, top), (r1 * px, d1, 4.14), (0.86 * px, 0.5 * py, 3.92)])
		verts, faces, flat = k._loft(rings)
		bake(k._mesh(name, t, verts, faces, flat, outline=0), ramp, k, **bk)


def _coat(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	_collar(k)
	# the small V: raised white fronts, a black edge, the zip line running on down to the sash
	for s in (1, -1):
		prism(k, t, f"Front{s}", [(s * 0.58, 3.98), (s * 0.92, 3.98), (s * 0.05, 3.1), (0, 3.28)], -0.615, -0.56, "coat", a=0.6, b=0.34)
		prism(k, t, f"Edge{s}", [(s * 0.5, 3.98), (s * 0.58, 3.98), (s * 0.03, 3.28), (0, 3.36)], -0.635, -0.59, "black", a=0.5, b=0.3)
	block(k, t, "Zip", 0, -0.61, 3.34, 2.52, 0.028, 0.03, "black", ch=0.008, a=0.5, b=0.3)
	# the wide black sash
	block(k, t, "Sash", 0, 0, 2.58, 2.12, 1.1, 0.625, "black", ch=0.03, corner=0.14, sub=1, a=0.5, b=0.36)


def _sword(k):
	"""Sheathed through the sash at his left hip, the hilt forward, the tip behind."""
	t = "UpperTorso"
	a, tip = (0.84, -0.98, 2.68), (0.96, 1.24, 2.06)  # the tip stays above z 2 so the running tail never meets it
	lerp = lambda u: tuple(a[i] + (tip[i] - a[i]) * u for i in range(3))
	pipe(k, t, "Sheath", [lerp(0.08) + (0.095,), lerp(0.6) + (0.105,), lerp(0.97) + (0.095,), lerp(1.0) + (0.05,)], "green", rn=6, base=0.46, amp=0.42, grad=0.0)
	pipe(k, t, "Guard", [lerp(0.05) + (0.17,), lerp(0.08) + (0.17,)], "guard", rn=6, base=0.5, amp=0.4, grad=0.0)
	pipe(k, t, "Hilt", [(0.8, -1.44, 2.94, 0.08), lerp(0.1) + (0.085,)], "wrap", rn=6, base=0.5, amp=0.4, grad=0.0)


# One tail's plan: its front edge swings out as it falls, it wraps the outside and meets its twin at a slit behind. (x, y, hem z)
_TAIL = [(None, -0.66, 0.6), (1.04, -0.66, 0.58), (1.13, -0.58, 0.56), (1.13, 0.58, 0.48), (1.04, 0.66, 0.46), (0.6, 0.67, 0.44), (0.16, 0.67, 0.44)]


def _front_x(r):
	return 0.3 + 0.44 * r


def _tail(k, leg, s):
	"""One long coat tail, white outside, a black lining inside, black trim down the front edge and round the hem."""
	rows = (0.0, 0.35, 0.7, 1.0)

	def col(i, x, y, hem, r):
		flare = 1 + 0.07 * r
		fx = _front_x(r) if x is None else (x if x < 0.1 else x * flare)
		fold = 0.018 * math.sin(i * 2.1 + r * 4) * (0 < r < 1)
		return fx, y * flare + fold, 2.0 + (hem - 2.0) * r

	shell, lining = [], []
	for r in rows:
		outer, inner, lo, li = [], [], [], []
		for i, (x, y, hem) in enumerate(_TAIL):
			fx, fy, z = col(i, x, y, hem, r)
			wrap = lambda d: ((fx if x is None or x < 0.1 else fx - d), fy - d * (1 if y > 0 else -1))
			outer.append((s * fx, fy, z))
			ix, iy = wrap(0.03)
			inner.append((s * ix, iy, z))
			ix, iy = wrap(0.035)
			lo.append((s * ix, iy, z))
			ix, iy = wrap(0.06)
			li.append((s * ix, iy, z))
		shell.append(outer + inner[::-1])
		lining.append(lo + li[::-1])
	verts, faces, flat = k._loft(shell)
	bake(k._mesh("Tail", leg, verts, faces, flat, outline=0), "coat", k, a=0.52, b=0.5, g=0.1)
	verts, faces, flat = k._loft(lining)
	bake(k._mesh("TailLining", leg, verts, faces, flat, outline=0), "black", k, a=0.5, b=0.3)
	# the trim: down the front and back edges, then round the hem
	for name, i in (("TrimFront", 0), ("TrimBack", len(_TAIL) - 1)):
		out = 1 if _TAIL[i][1] > 0 else -1
		edge = []
		for r in rows:
			fx, fy, z = col(i, *_TAIL[i], r)
			edge.append([(s * (fx - 0.01), fy + 0.022 * out, z), (s * (fx + 0.075), fy + 0.022 * out, z), (s * (fx + 0.075), fy - 0.012 * out, z), (s * (fx - 0.01), fy - 0.012 * out, z)])
		verts, faces, flat = k._loft(edge)
		bake(k._mesh(name, leg, verts, faces, flat, outline=0), "black", k, a=0.5, b=0.3)
	hem = []
	for i, (x, y, h) in enumerate(_TAIL):
		fx, fy, z = col(i, x, y, h, 1.0)
		hem.append([(s * fx * 1.014, fy * 1.02, z + 0.085), (s * fx * 1.014, fy * 1.02, z - 0.01), (s * fx * 0.97, fy * 0.96, z - 0.01), (s * fx * 0.97, fy * 0.96, z + 0.085)])
	verts, faces, flat = k._loft(hem)
	bake(k._mesh("TrimHem", leg, verts, faces, flat, outline=0), "black", k, a=0.5, b=0.3)


def _arm(k, side, s):
	sleeve(k, side, s, ramp="coat", cuff=2.3)
	arm = f"{side}UpperArm"
	block(k, arm, "Mouth", s * 1.5, 0.02, 2.66, 2.3, 0.54, 0.6, "coat", ch=0.04, corner=0.18, a=0.48, b=0.5)
	block(k, arm, "CuffTrim", s * 1.5, 0.02, 2.37, 2.28, 0.555, 0.615, "black", ch=0.02, corner=0.18, a=0.5, b=0.3)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.49, 0.55, "hakama", ch=0.04, flare=0.02, corner=0.16, jit=0.025, mids=(1.55,), a=0.46, b=0.56, tone=0.04)
	block(k, leg, "Shin", px, 0, 1.18, 0.52, 0.5, 0.56, "hakama", ch=0.04, flare=0.03, corner=0.16, jit=0.025, mids=(0.8,), a=0.46, b=0.56, tone=0.04)
	# pressed pleats down the front
	for i, dx in enumerate((-0.2, 0.14)):
		block(k, leg, f"Pleat{i}", px + s * dx, -0.57, 1.9, 0.6, 0.016, 0.016, "hakama", ch=0.005, a=0.2, b=0.1)
	# black sock, white shoe
	block(k, leg, "Sock", px, -0.02, 0.6, 0.26, 0.42, 0.44, "black", ch=0.02, a=0.5, b=0.3)
	dress_shoe(k, leg, px, top=0.34)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_helm(k)
	_coat(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
		_tail(k, f"{side}UpperLeg", s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=7):
	"""A cloth fold on white: a soft cool shadow and no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=COAT_D, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(COAT)
	# the V at the throat: chalk skin, the collar's shadow, the small hole on the sternum
	f.path("M46 -5H154L100 74Z", SKIN)
	f.soft("M46 -5H154V14H46Z", SKIN_D, 0.9, 3)
	f.soft("M46 -5L100 74V56L62 -5Z", SKIN_D, 0.55, 2)
	f.soft("M154 -5L100 74V56L138 -5Z", SKIN_D, 0.65, 2)
	f.path("M70 13Q84 20 95 18", stroke=SKIN_D, sw=1.6, opacity=0.8)
	f.path("M130 13Q116 20 105 18", stroke=SKIN_D, sw=1.6, opacity=0.8)
	f.path("M100 19a15 18.5 0 1 0 0.01 0Z", shade(SKIN_D, 0.78))
	f.path("M100 21a13 16.5 0 1 0 0.01 0Z", HOLE)
	f.path("M90 46Q100 57 110 46Q100 52 90 46Z", "#2a2d3e")
	# pull folds off the shoulders and towards the sash
	_fold(f, 14, 42, 40, 82, 76, 122)
	_fold(f, 186, 44, 160, 84, 124, 124)
	_fold(f, 34, 70, 48, 100, 44, 138, 0.35, 6)
	_fold(f, 166, 72, 152, 102, 156, 138, 0.35, 6)
	# below the sash: the hakama between the coat's tails
	f.path("M72 156H128L150 205H50Z", "#d8dbe2")
	f.path("M100 170L92 205H108Z", COAT_D, opacity=0.9)
	form(f, COAT_D, 0.55)
	f = a["Torso_B"]
	f.fill(COAT)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	_fold(f, 40, 120, 56, 134, 44, 148, 0.4, 6)
	_fold(f, 160, 120, 144, 134, 156, 148, 0.4, 6)
	stroke(f, "M100 4V150", COAT_D, 2, 0.75)
	stroke(f, "M100 160V205", COAT_D, 2.2, 0.9)
	form(f, COAT_D, 0.55)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(COAT)
		_fold(f, 20, 40, 34, 90, 26, 150, 0.4, 6)
		form(f, COAT_D, 0.55)
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
	f.fill(SKIN)
	# hair and helm throw their shadow on the brow; soft shading down the cheeks and jaw
	f.soft("M-5-5H135V34Q65 44 -5 34Z", SKIN_D, 0.9, 3)
	f.soft("M-5 30H10Q6 90 30 135H-5Z", SKIN_D, 0.75, 5)
	f.soft("M135 30H120Q124 90 100 135H135Z", SKIN_D, 0.9, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.55, 3)
	# the helm's brow rim shades the left eye's socket
	f.soft("M66 -5H135V62H126L119 36Q104 22 88 22Q72 24 69 48Z", SKIN_D, 0.85, 2)
	for cx, s in ((39, -1), (91, 1)):
		# the teal line from the lower lid to the jaw, widest near the eye
		f.path(f"M{cx + s * 3 - 2.1} 72L{cx + s * 3 + 2.1} 72L{cx + s * 7 + 1.2} 124L{cx + s * 7 - 1.2} 124Z", TEAL)
		f.soft(f"M{cx + s * 3 - 5} 72L{cx + s * 3 + 5} 72L{cx + s * 7 + 3} 124L{cx + s * 7 - 3} 124Z", TEAL, 0.18, 1)
		# large, cold, sad: the outer corners sit low and the lid hangs over a slit pupil
		eye2(f, cx, 62, s, 37, 15, "#3fae6c", tilt=-2.4, r=11, lid=0.28, lash="#07080d", lash_t=3.4, flick=2.6, pupil=0.36, sclera="#f8f9f3", crease_line=False, slit=True)
		# thin brows lifted towards the nose
		f.path(f"M{cx - s * 16} 41Q{cx} 41 {cx + s * 17} 48L{cx + s * 17} 49.6Q{cx} 44 {cx - s * 16} 43.6Z", "#14161f")
	nose(f, SKIN, y=74, h=14)
	# a small flat mouth, the upper lip black
	f.path("M55 104Q65 101.5 75 104Q65 106.5 55 104Z", "#11121a")
	stroke(f, "M53 104H77", "#11121a", 0.8)
	f.soft("M58 110Q65 113 72 110Q65 115 58 110Z", SKIN_D, 0.55, 1)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_T"].fill("#171b28")
	_torso(a)
	_limbs(a)
