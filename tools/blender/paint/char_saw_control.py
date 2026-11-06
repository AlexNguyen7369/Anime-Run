# Target look for saw_control "Makina" (design doc section 5): long red-pink hair with blunt bangs, long locks framing the face and a single thick braid
# over the shoulder, calm yellow eyes of concentric red rings, a small closed smile, a white shirt tucked into black trousers, a black tie.
# +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, bake, big_head, block, crown, face_base, finish, gem, head_rest, prism, slab, stroke
from saw_common import SKIN, SKIN_D, SHIRT, back_sheets, belt, collar, paint_limbs, paint_shirt, ramps, shirt_arm, shirt_body, suit_leg, tie

DEFAULT = SHIRT
HAIR_D = "#a4282e"
R = ramps(["#8e1f2c", "#c0303c", "#dc4048", "#ec5e5e", "#f8908a"])
HAIR = {"colour": "#DC4048", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.44), (1.06, 5.66), (0.97, 5.92), (0.58, 6.12), (0.16, 6.2)])
	block(k, "Head", "Cap", 0, 0.02, 5.76, 5.3, 1.03, 0.89, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.44, b=0.44)
	# gathered at the back of the neck into the braid
	block(k, "Head", "Back", 0, 0.34, 5.5, 4.2, 1.0, 0.56, "hair", ch=0.08, corner=0.34, jit=0.02, sub=1, mids=(4.8,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.84, 5.46), (-0.84, 5.0), (-0.66, 4.4), (-0.4, 4.1), (0.2, 4.07), (0.9, 4.07), (0.9, 5.46)], s * 0.84, s * 1.04, "hair", a=0.52, b=0.34)
		# the long locks framing the face
		gem(k, "Head", f"Lock{s}", (s * 0.88, -0.62, 5.56), (s * 0.84, -0.74, 3.5), 0.27, flat=0.4, twist=0.2, across=(1, 0, 0), a=0.52)
		gem(k, "Head", f"LockIn{s}", (s * 0.72, -0.8, 5.5), (s * 0.68, -0.78, 4.2), 0.16, flat=0.4, twist=0.32, across=(1, 0, 0), a=0.56)
	# blunt bangs cut straight across, just over the eyes: one solid with a slightly uneven edge, a few strands on it
	prism(k, "Head", "Bangs", [(-0.74, 5.7), (0.74, 5.7), (0.76, 5.04), (0.46, 4.98), (0.2, 5.04), (-0.06, 4.97), (-0.32, 5.03), (-0.54, 4.98), (-0.76, 5.04)], -0.97, -0.8, "hair", a=0.54, b=0.36)
	for i, (x, r) in enumerate(((-0.42, 0.2), (0.02, 0.22), (0.42, 0.2))):
		gem(k, "Head", f"Bang{i}", (x * 0.8, -0.8, 5.8), (x, -1.0, 5.04), r, flat=0.3, twist=0.15 + 0.1 * i, a=0.56, across=(1, 0, 0))
	back_sheets(k, 4.1)
	for s in (1, -1):
		for i, (t, r) in enumerate((((s * 1.08, -0.1, 5.42), 0.3), ((s * 0.98, 0.72, 5.36), 0.3))):
			gem(k, "Head", f"Clump{s}{i}", (s * 0.08, 0.06, 5.94), t, r, flat=0.5, twist=0.3, a=0.48)


def _plait(k, name, a, b, r, lean):
	"""One fat overlapping plait of the braid: a six-sided lens from a to b, tilted by lean, blunt at both ends."""
	from mathutils import Vector

	a, b = Vector(a), Vector(b)
	d = (b - a).normalized()
	w = d.cross(Vector((0, 1, 0)))
	w = w.normalized() if w.length > 0.2 else Vector((1, 0, 0))
	h = d.cross(w).normalized()
	c = (a + b) / 2
	rings = []
	for p, q, off in ((a, 0.55, -lean), (c, 1.0, 0.0), (b, 0.55, lean)):
		rings.append([tuple(p + w * (off + r * q * math.cos(math.pi * j / 3)) + h * (r * q * 0.72 * math.sin(math.pi * j / 3))) for j in range(6)])
	verts, faces, flat = k._loft(rings)
	return bake(k._mesh(name, "Head", verts, faces, flat, outline=0), "hair", k, a=0.54, b=0.42)


def _braid(k):
	"""From the back of the neck, round the side and down the chest on the viewer's left: plaits tilting in turn, a tie and a short tuft."""
	path = [(-0.24, 0.94, 4.5), (-0.72, 0.84, 4.3), (-1.04, 0.42, 4.14), (-1.12, -0.2, 4.08), (-1.0, -0.68, 3.86), (-0.84, -0.73, 3.52), (-0.8, -0.74, 3.2), (-0.78, -0.75, 2.88), (-0.78, -0.75, 2.58)]
	for i in range(len(path) - 1):
		a, b = path[i], path[i + 1]
		for j, (t0, t1) in enumerate(((-0.1, 0.65), (0.4, 1.15))):
			p = tuple(a[n] + (b[n] - a[n]) * t0 for n in range(3))
			q = tuple(a[n] + (b[n] - a[n]) * t1 for n in range(3))
			_plait(k, f"Plait{i}{j}", p, q, 0.2, 0.08 if (2 * i + j) % 2 else -0.08)
	end = path[-1]
	block(k, "Head", "BraidTie", end[0], end[1], end[2] + 0.04, end[2] - 0.08, 0.11, 0.11, "tie", ch=0.02, corner=0.3, a=0.6, b=0.4)
	gem(k, "Head", "BraidEnd", (end[0], end[1], end[2] - 0.04), (end[0], end[1] - 0.02, end[2] - 0.4), 0.17, flat=0.7, twist=0.3, a=0.56)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_braid(k)
	shirt_body(k)
	belt(k)
	collar(k)
	tie(k, end=2.5)
	for s, side in ((1, "Left"), (-1, "Right")):
		shirt_arm(k, side, s)
		suit_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f0a090", top=26)
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 64, s, 37, 15, "#ffe83c", tilt=1.6, r=12, lid=0.28, lash="#6a1a1e", lash_t=3.2, flick=2.5, pupil=0.14, sclera="#fff6e4", crease_line=False)
		# the eye's whole point: concentric rings on a bright yellow iris
		f.path(f"M{x - 11} 64a11 11 0 1 0 22 0a11 11 0 1 0 -22 0Z", "#ffe83c")
		for r, w in ((10.4, 1.4), (6.6, 1.2), (3.2, 1.2)):
			f.path(f"M{x - r} 64a{r} {r} 0 1 0 {2 * r} 0a{r} {r} 0 1 0 {-2 * r} 0Z", stroke="#d8342c", sw=w)
		f.path(f"M{x - 19} 58Q{x} 49 {x + 19} 58L{x + 19} 55Q{x} 45 {x - 19} 55Z", "#6a1a1e")
		brow2(f, x, 45, s, 28, 2.4, -0.8, "#c43a3e", arc=-1.5)
	nose(f, SKIN, y=80, h=10)
	stroke(f, "M55 105Q65 110 75 105", "#8a3030", 2.0)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill(HAIR_D)
	paint_shirt(a)
	paint_limbs(a, SHIRT)
