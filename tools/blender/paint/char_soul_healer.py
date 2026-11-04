# Target look for soul_healer "Orihima" (design doc section 5): straight burnt-orange hair to the waist with short parted bangs and long
# locks down the front, a pair of pale blue star pins on the bangs (the mark, changed in shape), brown eyes, a white short-sleeved shirt,
# a red bow with a gold clasp, a pleated grey skirt, short white socks and dark loafers. +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from jk_common import brow2, eye2, form
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, face_base, finish, gem, head_rest, jitter, prism, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#fbe2d2"
SKIN_D = "#dcb29c"
SHIRT = "#f3f4f6"
SHIRT_D = "#b4bac8"
DEFAULT = SHIRT
R = Ramps(
	hair=["#8a3410", "#c0521a", "#e06d24", "#f28a3a", "#fbae68"],
	skin=["#c09880", "#e6c2ac", "#fbe2d2", "#fff0e6"],
	shirt=["#a4abbb", "#ccd1dc", "#eceef2", "#ffffff"],
	grey=["#3a3e4a", "#565b69", "#737987", "#9197a4", "#b0b5c0"],
	band=["#23262f", "#343843", "#484d5a", "#5e6370"],
	red=["#6e0e14", "#a01a20", "#c82a2a", "#e44a46"],
	gold=["#94600a", "#d09e18", "#f4cc3c", "#fff09a"],
	pin=["#2f6fb0", "#5a9ad6", "#9ccaef", "#dff1ff"],
	sock=["#a9aeba", "#d4d8e0", "#f2f3f6", "#ffffff"],
	shoe=["#0c0c12", "#191a22", "#2b2c37", "#42434f"],
	sole=["#08080c", "#121218", "#1f1f27", "#2e2e38"],
)
HAIR = {"colour": "#E06D24", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.46), (1.06, 5.66), (0.96, 5.92), (0.58, 6.14), (0.16, 6.22)])
	block(k, "Head", "Cap", 0, 0.02, 5.76, 5.3, 1.03, 0.89, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.44, b=0.44)
	# the long straight mass, behind the shoulders and between the arms, to the waist
	mass = k.tube("Head", "Mass", [(0, 0.2, 5.72, 0.9, 0.8), (0, 0.36, 5.42, 1.05, 0.72), (0, 0.5, 4.6, 1.05, 0.58), (0, 0.56, 4.2, 0.98, 0.5)], "hair", corner=0.3, nc=1, sub=1, outline=0)
	jitter(mass, 0.015)
	bake(mass, "hair", k, a=0.42, b=0.42)
	block(k, "Head", "Fall", 0, 0.8, 4.3, 2.84, 0.94, 0.25, "hair", ch=0.05, corner=0.3, jit=0.02, sub=1, mids=(3.5,), a=0.4, b=0.42, g=0.14)
	# straight sheets over the back, ending in a row of points at the waist
	for i, (x, z0, z1, r) in enumerate(((-0.7, 5.3, 2.9, 0.34), (-0.24, 5.5, 2.8, 0.38), (0.24, 5.5, 2.84, 0.38), (0.7, 5.3, 2.94, 0.34))):
		gem(k, "Head", f"Sheet{i}", (x, 0.96, z0), (x, 1.08, z1), r, flat=0.32, twist=0.18 + 0.1 * i, across=(1, 0, 0), a=0.46)
	for i, (x, z1) in enumerate(((-0.72, 2.56), (-0.36, 2.42), (0.0, 2.36), (0.36, 2.44), (0.72, 2.58))):
		gem(k, "Head", f"End{i}", (x, 0.82, 3.2), (x, 0.86, z1), 0.25, flat=0.5, twist=0.2 + 0.1 * i, across=(1, 0, 0), a=0.4)
	for s in (1, -1):
		# the sides, covering the ears and the head block
		slab(k, f"Side{s}", [(-0.84, 5.46), (-0.84, 5.0), (-0.66, 4.4), (-0.4, 4.1), (0.2, 4.07), (0.9, 4.07), (0.9, 5.46)], s * 0.84, s * 1.04, "hair", a=0.42, b=0.46)
		# the long locks down the front, past the jaw to the chest
		gem(k, "Head", f"Lock{s}", (s * 0.86, -0.6, 5.5), (s * 0.84, -0.72, 3.0), 0.3, flat=0.42, twist=0.2, across=(1, 0, 0), a=0.5)
		gem(k, "Head", f"LockIn{s}", (s * 0.72, -0.8, 5.3), (s * 0.68, -0.76, 3.66), 0.17, flat=0.4, twist=0.32, across=(1, 0, 0), a=0.54)
		# short bangs parted in the middle, leaving the eyes clear
		root = (s * 0.06, -0.76, 5.8)
		for i, (t, r) in enumerate((((s * 0.26, -0.95, 5.08), 0.2), ((s * 0.54, -0.95, 5.06), 0.22), ((s * 0.8, -0.95, 4.84), 0.22))):
			gem(k, "Head", f"Bang{s}{i}", root, t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.5, across=(0, 0, 1))
		# the outer bangs cover the forehead's corner; the sweep breaks the crown's rim
		gem(k, "Head", f"BangOut{s}", (s * 0.46, -0.84, 5.56), (s * 0.94, -0.94, 4.96), 0.3, flat=0.42, twist=0.3, a=0.48, across=(0, 0, 1))
		gem(k, "Head", f"Sweep{s}", (s * 0.14, -0.66, 5.76), (s * 1.0, -0.92, 5.3), 0.26, flat=0.42, twist=0.25, a=0.52, across=(0, 0, 1))
	# clumps over the crown falling away from the parting
	for s in (1, -1):
		for i, (t, r) in enumerate((((s * 1.08, -0.1, 5.42), 0.3), ((s * 0.98, 0.72, 5.36), 0.3))):
			gem(k, "Head", f"Clump{s}{i}", (s * 0.08, 0.06, 5.92), t, r, flat=0.5, twist=0.3, a=0.48)


def _pin(k, s):
	"""The mark, changed: where the pin sits on the bangs, a four-pointed star instead of a six-petal flower."""
	cx, cz, r, w = s * 0.58, 5.2, 0.19, 0.06
	star = [(cx, cz + r), (cx + w, cz + w), (cx + r, cz), (cx + w, cz - w), (cx, cz - r), (cx - w, cz - w), (cx - r, cz), (cx - w, cz + w)]
	prism(k, "Head", f"Pin{s}", star, -1.08, -0.98, "pin", a=0.56, b=0.42)
	block(k, "Head", f"PinCentre{s}", cx, -1.1, cz + 0.035, cz - 0.035, 0.035, 0.012, "pin", ch=0.008, a=0.9, b=0.2)


def _shirt(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Shirt", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.0, 1.05, 0.57), (0, 0, 2.2, 1.05, 0.57)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	block(k, t, "CollarBack", 0, 0.06, 4.08, 3.94, 0.8, 0.54, "shirt", ch=0.03, corner=0.2, a=0.56, b=0.36)
	for s in (1, -1):
		prism(k, t, f"Collar{s}", [(s * 0.05, 4.0), (s * 0.78, 4.0), (s * 0.64, 3.58), (s * 0.2, 3.7)], -0.63, -0.56, "shirt", a=0.6, b=0.36)
		# the bow: one wing each way from the clasp and one tail hanging down
		prism(k, t, f"Wing{s}", [(s * 0.05, 3.72), (s * 0.48, 3.92), (s * 0.56, 3.58), (s * 0.05, 3.5)], -0.73, -0.62, "red", a=0.54, b=0.5)
		prism(k, t, f"Tail{s}", [(s * 0.03, 3.54), (s * 0.36, 3.02), (s * 0.14, 2.96), (s * 0.0, 3.34)], -0.68, -0.6, "red", a=0.46, b=0.5)
	block(k, t, "Clasp", 0, -0.76, 3.72, 3.5, 0.075, 0.03, "gold", ch=0.012, a=0.66, b=0.3)


def _skirt(k):
	"""Closed pleated solid hung from the waistband to above the knee: a zigzag ring going round a rounded rectangle."""
	n = 36
	rows = ((2.36, 1.04, 0.58, 0.0), (2.26, 1.08, 0.61, 0.02), (1.76, 1.15, 0.68, 0.07), (1.24, 1.21, 0.74, 0.09), (1.18, 1.16, 0.69, 0.06))
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
	bake(k._mesh("Skirt", "UpperTorso", verts, faces, flat, outline=0), "grey", k, a=0.5, b=0.62, g=0.14)
	block(k, "UpperTorso", "Waistband", 0, 0, 2.46, 2.26, 1.09, 0.62, "band", ch=0.03, corner=0.14, a=0.5, b=0.5)


def _arm(k, side, s):
	"""Short white sleeve with a cuff band, a bare arm as wide as the hand, and the plain block hand."""
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Bare", ax, 0, 3.3, 2.24, 0.5, 0.5, "skin", ch=0.04, corner=0.18, a=0.58, b=0.34)
	block(k, arm, "Hand", ax, 0, 2.28, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.32)
	block(k, arm, "Sleeve", ax, 0, 4.03, 3.2, 0.525, 0.525, "shirt", ch=0.1, corner=0.18, jit=0.02, sub=1, mids=(3.6,), a=0.56, b=0.4)
	block(k, arm, "Cuff", ax, 0, 3.26, 3.12, 0.54, 0.54, "shirt", ch=0.03, corner=0.18, a=0.52, b=0.38)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.52
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Bare", px, 0, 1.97, 0.7, 0.48, 0.5, "skin", ch=0.04, corner=0.14, mids=(1.2,), a=0.58, b=0.34)
	block(k, leg, "Sock", px, 0, 0.78, 0.32, 0.49, 0.51, "sock", ch=0.03, corner=0.14, a=0.56, b=0.36)
	dress_shoe(k, leg, px, top=0.38)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_shirt(k)
	_skirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_pin(k, s)
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=6):
	"""A cloth fold on white: a soft cool shadow and no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=SHIRT_D, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(SHIRT)
	# the neck opening above the bow
	f.path("M78 -5H122L100 34Z", SKIN)
	# the button line and the folds running to the waist
	stroke(f, "M100 46V170", SHIRT_D, 1.6, 0.9)
	for y in (92, 122, 152):
		f.path(f"M96.5 {y}a3.5 3.5 0 1 0 7 0a3.5 3.5 0 1 0 -7 0Z", "#ffffff", stroke=SHIRT_D, sw=0.9)
	_fold(f, 10, 100, 34, 124, 72, 150)
	_fold(f, 190, 100, 166, 124, 128, 150)
	_fold(f, 26, 140, 44, 156, 40, 172, 0.4)
	_fold(f, 174, 140, 156, 156, 160, 172, 0.4)
	form(f, SHIRT_D, 0.5)
	f = a["Torso_B"]
	f.fill(SHIRT)
	_fold(f, 14, 60, 44, 84, 86, 116)
	_fold(f, 186, 60, 156, 84, 114, 116)
	form(f, SHIRT_D, 0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(SHIRT)
		_fold(f, 20, 40, 34, 90, 26, 150, 0.4)
		form(f, SHIRT_D, 0.5)
	a["Torso_T"].fill(SHIRT)
	a["Torso_Bo"].fill(SHIRT_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill(SKIN)
		a[f"{side}Arm_T"].fill(SHIRT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(SKIN)
		a[f"{side}Leg_Bo"].fill(SKIN_D)


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f4a08c", top=24)
	# large warm brown eyes, soft thin brows, a small open smile
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 62, s, 36, 15, "#b4743c", tilt=1.4, r=13, lash="#4a1e0c", lash_t=3.6, flick=3, pupil=0.36, sclera="#fffdf8", crease_line=False)
		brow2(f, x, 38, s, 30, 2.6, -1.4, "#b8642e", arc=-2.2)
	f.soft("M61 86L65 81L69 86Q65 90 61 86Z", SKIN_D, 0.65, 1)
	f.path("M53 100Q65 104 77 100Q72 113 65 113Q58 113 53 100Z", "#a84848")
	f.path("M56 102Q65 105 74 102L72 105Q65 107 58 105Z", "#ffffff")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill("#c0521a")
	_torso(a)
	_limbs(a)
