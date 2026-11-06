# Target look for saw_bomb "Rezi" (design doc section 5): a short purple-black bob with a long bang over one eye and a small knot behind the ear,
# green eyes, a wide black choker with a small ring, a white blouse with sleeves rolled to the elbow and a thin black ribbon, a dark waist apron over
# a dark skirt, flat shoes. +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, face_base, finish, gem, head_rest, prism, slab, stroke
from saw_common import SKIN, SKIN_D, SHIRT, collar, paint_limbs, paint_shirt, ramps, rolled_arm, shirt_body

DEFAULT = SHIRT
HAIR_D = "#150f1e"
R = ramps(["#0e0a14", "#1a1424", "#281e36", "#3e3054", "#645480"], apron=["#06060a", "#101018", "#1c1c28", "#30303e"], skirt=["#0e0a18", "#191428", "#272038", "#3a3250"])
HAIR = {"colour": "#281E36", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.4), (1.06, 5.64), (0.97, 5.9), (0.58, 6.1), (0.16, 6.16)])
	block(k, "Head", "Cap", 0, 0.02, 5.72, 5.28, 1.03, 0.89, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.44, b=0.44)
	# the bob: a single heavy curtain cut straight at the jaw, curving in at its ends
	block(k, "Head", "Bob", 0, 0.34, 5.5, 4.2, 1.06, 0.6, "hair", ch=0.09, corner=0.34, jit=0.02, sub=1, mids=(4.8,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.74, 5.46), (-0.74, 4.76), (-0.62, 4.24), (0.0, 4.14), (0.84, 4.16), (0.84, 5.46)], s * 0.84, s * 1.07, "hair", a=0.52, b=0.34)
		for i, (y, z) in enumerate(((-0.56, 4.06), (-0.14, 4.0), (0.3, 4.0), (0.72, 4.04))):
			gem(k, "Head", f"Cut{s}{i}", (s * 0.97, y, 4.7), (s * 0.95, y, z), 0.24, flat=0.5, twist=0.2 + 0.1 * i, across=(0, 1, 0), a=0.44)
	for i, x in enumerate((-0.68, -0.22, 0.24, 0.7)):
		gem(k, "Head", f"Nape{i}", (x, 0.86, 4.8), (x, 0.92, 4.02), 0.28, flat=0.4, twist=0.2 + 0.1 * i, across=(1, 0, 0), a=0.42)
	# the bangs: short on the viewer's left, and a long sweep that hides most of the eye on the right
	root = (-0.26, -0.76, 5.82)
	for i, (t, r) in enumerate((((-0.86, -0.94, 4.92), 0.26), ((-0.58, -0.95, 5.1), 0.24), ((-0.28, -0.96, 5.2), 0.2))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.12 * i, a=0.5, across=(0, 0, 1))
	for i, (t, r) in enumerate((((0.12, -0.97, 5.0), 0.2), ((0.42, -0.98, 4.62), 0.26), ((0.82, -0.96, 4.26), 0.3))):
		gem(k, "Head", f"Sweep{i}", root, t, r, flat=0.42, twist=0.25 + 0.1 * i, a=0.54, across=(0, 0, 1))
	gem(k, "Head", "SweepTop", (0.5, -0.82, 5.68), (0.96, -0.94, 4.9), 0.32, flat=0.42, twist=0.3, a=0.5, across=(0, 0, 1))
	# the small knot tucked behind the ear
	block(k, "Head", "Knot", -0.96, 0.62, 4.74, 4.36, 0.2, 0.2, "hair", ch=0.07, corner=0.3, jit=0.012, a=0.46, b=0.5)


def _neck(k):
	"""The choker: wide and black, standing clear under the chin, with a small steel ring at the front."""
	block(k, "Head", "Choker", 0, 0, 4.12, 3.95, 0.74, 0.8, "tie", ch=0.02, corner=0.2, sub=1, a=0.56, b=0.44)
	block(k, "Head", "ChokerRing", 0, -0.82, 4.08, 3.97, 0.06, 0.02, "steel", ch=0.012, a=0.62, b=0.3)


def _ribbon(k):
	t = "UpperTorso"
	for s in (1, -1):
		prism(k, t, f"Wing{s}", [(s * 0.03, 3.78), (s * 0.34, 3.92), (s * 0.38, 3.62), (s * 0.03, 3.68)], -0.73, -0.64, "tie", a=0.54, b=0.5)
		prism(k, t, f"Tail{s}", [(s * 0.02, 3.68), (s * 0.2, 3.1), (s * 0.08, 3.06), (0, 3.5)], -0.7, -0.63, "tie", a=0.5, b=0.5)
	block(k, t, "RibbonKnot", 0, -0.75, 3.8, 3.64, 0.06, 0.03, "tie", ch=0.012, a=0.62, b=0.4)


def _skirt(k):
	"""The skirt to the knee as a closed pleated solid, and the waist apron tied over its front."""
	n = 28
	rows = ((2.34, 1.04, 0.58, 0.0), (2.26, 1.07, 0.61, 0.015), (1.72, 1.13, 0.67, 0.05), (1.04, 1.18, 0.72, 0.07), (0.98, 1.13, 0.68, 0.05))
	rings = []
	for z, hw, hd, amp in rows:
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			p = 1 + (amp if j % 2 else -amp)
			ring.append((hw * p * math.copysign(abs(c) ** 0.45, c), hd * p * math.copysign(abs(sn) ** 0.45, sn), z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Skirt", "UpperTorso", verts, faces, flat, outline=0), "skirt", k, a=0.5, b=0.6, g=0.14)
	t = "UpperTorso"
	prism(k, t, "Apron", [(-0.82, 2.3), (0.82, 2.3), (0.98, 1.2), (-0.98, 1.2)], -0.82, -0.7, "apron", a=0.5, b=0.5)
	block(k, t, "ApronBand", 0, 0, 2.42, 2.24, 1.09, 0.625, "apron", ch=0.02, corner=0.14, a=0.5, b=0.5)
	block(k, t, "ApronKnot", 0, 0.66, 2.46, 2.2, 0.14, 0.05, "apron", ch=0.02, a=0.5, b=0.5)
	for s in (1, -1):
		prism(k, t, f"ApronTie{s}", [(s * 0.03, 2.34), (s * 0.34, 2.14), (s * 0.3, 1.66), (s * 0.12, 1.7)], 0.66, 0.72, "apron", a=0.5, b=0.5)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.52
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Bare", px, 0, 1.97, 0.4, 0.48, 0.5, "skin", ch=0.04, corner=0.14, mids=(1.2,), a=0.58, b=0.34)
	dress_shoe(k, leg, px, top=0.4)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_neck(k)
	shirt_body(k)
	collar(k)
	_ribbon(k)
	_skirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		rolled_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f49a94", top=22)
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 58, s, 36, 15, "#58b43a", tilt=1.4, r=11.5, lash="#150f1e", lash_t=3.6, flick=3, pupil=0.36, sclera="#fffdf8", crease_line=False)
		brow2(f, x, 38, s, 28, 2.6, -1.0, "#281E36", arc=-2.0)
	f.soft("M18 72Q30 66 44 78Q30 88 18 80Z", "#f49a94", 0.3, 3)
	f.soft("M112 72Q100 66 86 78Q100 88 112 80Z", "#f49a94", 0.3, 3)
	nose(f, SKIN, y=72, h=10)
	# a small closed smile
	stroke(f, "M56 96Q65 101 74 96", "#7a2a2a", 2.2)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill(HAIR_D)
	paint_shirt(a, buttons=True)
	paint_limbs(a, SKIN)
