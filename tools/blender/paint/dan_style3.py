# Target look kit for the dan_ series (design doc section 5): the shared solids plus layered hair, the school uniform, hoops and
# bare block limbs. Hair shapes and faces stay in each char_<id>.py. bpy stays out of this file: atlas.py runs under python3.
import math

from atlas import shade
from ds_style3 import eye, xf  # noqa: F401
from jk_common import brow2, form  # noqa: F401
from jk_style3 import bake, crown, jacket, sneaker, torso_core  # noqa: F401
from saw_common import collar as shirt_collar  # noqa: F401
from solo_style3 import Kit, Ramps, art_jacket, big_head, block, boot, collar, dress_shoe, ears, finish, gem, head_rest, prism, rblock, sleeve, slab, stroke, trouser  # noqa: F401

T = "UpperTorso"
SKIN = "#f8d6bc"
SKIN_D = "#d4a386"
BROW_LASH = "#1c1018"


def ramps(hair, **extra):
	base = dict(
		hair=hair,
		skin=["#c8987c", "#e8bca0", "#f8d6bc", "#ffeadb"],
		shirt=["#a4abbb", "#ccd1dc", "#eceef2", "#ffffff"],
		navy=["#10162c", "#1e2746", "#2e3960", "#46527e"],
		red=["#6e0a10", "#a8141c", "#d8262c", "#f4605c"],
		loafer=["#24100a", "#422016", "#643424", "#8a5440"],
		sole=["#08080c", "#14141a", "#24242c", "#36363e"],
		black=["#060608", "#0e0e14", "#1a1a22", "#30303c"],
		gold=["#8a6210", "#c8962a", "#eec24a", "#fff0a8"],
	)
	base.update(extra)
	return Ramps(**base)


def _sq(deg, rx, ry, p=0.42):
	c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	return rx * math.copysign(abs(c) ** p, c), ry * math.copysign(abs(s) ** p, s)


def mop(k, tag, spec, zroot=5.82, root=0.82, rx=1.06, ry=0.98, ramp="hair", flat=0.4, bend=0.1, a=0.5, swirl=0):
	"""Locks falling from the crown over the head: spec = (angle deg, tip z, radius). Angle -90 is the front; swirl turns the roots."""
	for i, (deg, z, r) in enumerate(spec):
		tx, ty = _sq(deg, rx, ry)
		bx, by = _sq(deg + swirl, rx * root, ry * root)
		t = math.radians(deg)
		gem(k, "Head", f"{tag}{i}", (bx, by, zroot), (tx, ty, z), r, ramp, flat=flat, bend=bend, twist=0.15 + 0.1 * (i % 3), across=(-math.sin(t), math.cos(t), 0), a=a)


def hoop(k, part, name, c, R, r, ramp, n=14, squash=1.0, **bk):
	"""A ring facing the front, square section."""
	rings = []
	for i in range(n):
		a = 2 * math.pi * i / n
		rings.append([(c[0] + (R + q * r) * math.cos(a), c[1] + y * r, c[2] + (R + q * r) * squash * math.sin(a)) for q, y in ((1, 1), (-1, 1), (-1, -1), (1, -1))])
	verts = [p for ring in rings for p in ring]
	faces = [(i * 4 + j, i * 4 + (j + 1) % 4, ((i + 1) % n) * 4 + (j + 1) % 4, ((i + 1) % n) * 4 + j) for i in range(n) for j in range(4)]
	return bake(k._mesh(name, part, verts, faces, outline=0), ramp, k, **bk)


def bow(k, ramp="red", z=3.72, w=0.5, y=-0.74):
	for s in (1, -1):
		prism(k, T, f"BowWing{s}", [(s * 0.04, z + 0.07), (s * w, z + 0.24), (s * (w + 0.04), z - 0.2), (s * 0.04, z - 0.07)], y, y + 0.12, ramp, a=0.54, b=0.46)
		prism(k, T, f"BowTail{s}", [(s * 0.02, z - 0.06), (s * 0.16, z - 0.08), (s * 0.32, z - 0.52), (s * 0.1, z - 0.46)], y + 0.02, y + 0.12, ramp, a=0.46, b=0.46)
	block(k, T, "BowKnot", 0, y - 0.01, z + 0.11, z - 0.11, 0.11, 0.07, ramp, ch=0.03, a=0.6, b=0.4)


def pleats(k, ramp="navy", top=2.3, hem=1.2):
	"""A knee-length pleated skirt, one closed solid on the torso."""
	n = 28
	rings = []
	for z, hw, hd, amp in ((top, 1.04, 0.58, 0.0), (top - 0.08, 1.07, 0.61, 0.015), ((top + hem) / 2, 1.14, 0.68, 0.05), (hem + 0.06, 1.2, 0.75, 0.07), (hem, 1.15, 0.7, 0.05)):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			p = 1 + (amp if j % 2 else -amp)
			ring.append((hw * p * math.copysign(abs(c) ** 0.45, c), hd * p * math.copysign(abs(sn) ** 0.45, sn), z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Skirt", T, verts, faces, flat, outline=0), ramp, k, a=0.5, b=0.6, g=0.14)


def core_leg(k, side, s):
	leg, x = f"{side}UpperLeg", s * 0.5
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	return leg, s * 0.52


def sock_leg(k, side, s, top=1.0, baggy=False, skin="skin"):
	"""A bare block leg, a white sock (baggy: three slouched rolls) and a loafer."""
	leg, px = core_leg(k, side, s)
	block(k, leg, "Bare", px, 0, 1.97, 0.4, 0.46, 0.49, skin, ch=0.04, corner=0.14, mids=(1.2,), a=0.58, b=0.34)
	if baggy:
		h = (top - 0.36) / 3
		for i in range(3):
			block(k, leg, f"Sock{i}", px, 0, top - i * h + 0.03, top - (i + 1) * h, 0.5 + 0.02 * i, 0.53 + 0.025 * i, "shirt", ch=0.07, corner=0.18, jit=0.015, a=0.56, b=0.4)
	else:
		block(k, leg, "Sock", px, 0, top, 0.38, 0.49, 0.52, "shirt", ch=0.03, corner=0.16, a=0.56, b=0.38)
		block(k, leg, "SockTop", px, 0, top + 0.03, top - 0.12, 0.5, 0.535, "shirt", ch=0.03, corner=0.16, a=0.62, b=0.34)
	dress_shoe(k, leg, px, ramp="loafer", top=0.42)
	block(k, leg, "Strap", px, -0.44, 0.39, 0.3, 0.4, 0.2, "loafer", ch=0.03, a=0.72, b=0.3)


def bare_foot(k, leg, px, ramp="skin", top=0.9):
	block(k, leg, "Shin", px, 0, top, 0.2, 0.46, 0.48, ramp, ch=0.04, corner=0.16, a=0.52, b=0.42)
	block(k, leg, "Foot", px, -0.2, 0.3, 0.0, 0.48, 0.68, ramp, ch=0.07, corner=0.2, a=0.54, b=0.42)


# ---- paint


def face(f, skin=SKIN, dark=SKIN_D, blush="#f48c84"):
	f.fill(skin)
	f.soft("M-5-5H135V28Q65 34 -5 28Z", dark, 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.65, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.45, 3)
	if blush:
		f.soft("M14 82Q28 76 36 90Q26 98 14 92Z", blush, 0.22, 3)
		f.soft("M116 82Q102 76 94 90Q104 98 116 92Z", blush, 0.22, 3)


def nose(f, dark=SKIN_D, line="#b47e66"):
	f.soft("M60 88L65 80L70 88Q65 92 60 88Z", dark, 0.5, 1)
	f.path("M61 89Q65 91 69 89", stroke=line, sw=1.2)


def rest(a, skin, top, torso, arm, leg):
	"""Everything under the solids: only seams could show."""
	head_rest(a, shade(skin, 0.84), shade(skin, 0.62))
	a["Head_T"].fill(top)
	for key in "FBLR":
		a[f"Torso_{key}"].fill(torso)
	a["Torso_T"].fill(torso)
	a["Torso_Bo"].fill(shade(torso, 0.6))
	for side in ("Left", "Right"):
		for key in ("F", "B", "O", "I", "T", "Bo"):
			a[f"{side}Arm_{key}"].fill(arm)
			a[f"{side}Leg_{key}"].fill(leg)
