# Target look for boss_king "The Golden King" (design doc 4.37 Third boss, section 5; docs/char_evidence/boss_king.md): short spiky
# blonde hair brushed up and back off a bare brow, sharp red eyes under thin pale brows, a thin smirk, square gold drop earrings;
# full golden plate over a dark navy underlayer: a breastplate, a navy gorget, big round pauldrons, gold vambraces and gauntlets,
# a belt, split skirt plates with navy wedge marks at their points and a red cloth behind, gold greaves. Ea (three stacked dark
# cylinders on a gold guard, fine red lines) and the Key (a flat gold key, round barrel head) are built here as Ea* and Key* pieces
# and kept out of the merge by tools/blender/build_boss_king.py, which animates them on their own. The blocky R15 body is never
# slimmed: likeness is hair, face and paint. +X is the viewer's right in the front view. Drawn in-house from the owner's references.
import math

from atlas import shade
from char_boss_mage import rod
from jk_common import brow2, eye2, form
from jk_style3 import Kit, bake, big_head, block, collar, crown, face_base, finish, gem, head_rest, prism, slab, torso_core
from style2 import Ramps

SKIN = "#f6dcc8"
SKIN_D = "#d4a88e"
NAVY = "#141a2e"
NAVY_D = "#0a0d18"
GOLD = "#d9a83a"
DEFAULT = NAVY
SMALL = False  # set by the Sidekick build (side_king): drops detail that falls under 2 px at Sidekick size
R = Ramps(
	hair=["#b09040", "#d8bc60", "#eed884", "#f8ecb0", "#fffae0"],
	skin=["#c09072", "#e6c0a6", "#f6dcc8", "#fff0e4"],
	gold=["#5e3c06", "#9c6a14", "#cf9a2c", "#eec050", "#ffe08a"],
	navy=["#07090f", "#101424", "#1c2238", "#303a58"],
	red=["#4a0a0e", "#8a1418", "#c02a28", "#e85848"],
	ea=["#1a0c10", "#3a1a1e", "#5a2a2c", "#7a3e3c"],
	glow=["#6a0a0a", "#b01818", "#e03a2a", "#ff7a5a"],
)
HAIR = {"colour": "#E8C250", "locks": []}
PROPS = []
# Ea is drawn upright at the origin, then moved so its grip (0.35 above the pommel) sits in the right hand, a little in front
EA_AT = (-1.5, -0.62, 2.05 - 0.35)
KEY_AT = (0.95, -0.74, 2.35)  # the key hangs flat over the left front skirt plate, pivot at the belt


def _hair(k):
	crown(k, [(0.94, 5.3), (1.0, 5.5), (0.9, 5.8), (0.5, 6.04), (0.14, 6.1)], at=(0, 0.06, 0))
	block(k, "Head", "Cap", 0, 0.06, 5.72, 5.3, 0.97, 0.88, "hair", ch=0.08, corner=0.3, jit=0.015, a=0.5, b=0.42)
	# the brow stays bare: short wedges rise off the hairline, brushed up and a little back, the middle ones tallest
	for i, (bx, tip, r) in enumerate(((-0.74, (-0.98, -0.2, 6.2), 0.3), (-0.4, (-0.52, -0.12, 6.52), 0.34), (0.0, (0.04, -0.04, 6.62), 0.36), (0.4, (0.56, -0.12, 6.5), 0.34), (0.74, (1.0, -0.2, 6.18), 0.3))):
		gem(k, "Head", f"Rake{i}", (bx, -0.62, 5.42), tip, r, flat=0.5, bend=0.04, twist=0.2 + 0.3 * i % 0.6, a=0.54)
	# the crown row leans back; the nape row short
	for i, (bx, tip, r) in enumerate(((-0.56, (-0.84, 0.74, 6.12), 0.3), (-0.2, (-0.26, 0.86, 6.3), 0.34), (0.2, (0.28, 0.86, 6.28), 0.34), (0.56, (0.86, 0.74, 6.1), 0.3))):
		gem(k, "Head", f"Crown{i}", (bx, 0.02, 5.84), tip, r, flat=0.55, bend=0.05, twist=0.4 + 0.2 * i)
	for s in (1, -1):
		# temple blades raked up and back, a short sideburn to the jaw
		gem(k, "Head", f"Blade{s}", (s * 0.84, -0.3, 5.44), (s * 1.1, 0.4, 5.9), 0.22, flat=0.5, twist=0.3, across=(0, 0, 1))
		slab(k, f"Burn{s}", [(-0.62, 5.42), (-0.62, 4.62), (-0.42, 4.7), (-0.3, 5.42)], s * 0.86, s * 0.99, "hair", a=0.48, b=0.4)


def _ears(k):
	w = 0.09 if SMALL else 0.05
	for s in (1, -1):
		block(k, "Head", f"Ear{s}", s * 0.93, 0.02, 4.9, 4.56, 0.06, 0.13, "skin", ch=0.03, a=0.56, b=0.32)
		# a square gold drop hangs below the lobe
		prism(k, "Head", f"Earring{s}", [(s * 1.04, 4.56), (s * 1.18, 4.56), (s * 1.18, 4.34), (s * 1.04, 4.34)], -w, w, "gold", a=0.62, b=0.34)


def _top(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	# the breastplate over the navy gorget, a raised centre ridge, the belt with its buckle
	block(k, t, "Plate", 0, 0, 3.86, 2.6, 1.03, 0.57, "gold", ch=0.09, corner=0.22, jit=0.012, mids=(3.2,), a=0.56, b=0.46, g=0.1)
	# the navy V and keyhole line down the chest plate
	prism(k, t, "ChestV", [(-0.36, 3.76), (-0.26, 3.76), (0.0, 3.34), (0.26, 3.76), (0.36, 3.76), (0.0, 3.16)], -0.59, -0.565, "navy", a=0.44, b=0.3)
	prism(k, t, "ChestLine", [(-0.035, 3.22), (0.035, 3.22), (0.035, 2.72), (-0.035, 2.72)], -0.59, -0.565, "navy", a=0.44, b=0.3)
	collar(k, "navy", 4.1, 4.24, z0=3.88, rx=0.64, ry=0.6, n=12, a=0.44, b=0.5)
	block(k, t, "Belt", 0, 0, 2.6, 2.34, 1.07, 0.61, "navy", ch=0.02, corner=0.14, a=0.46, b=0.5)
	block(k, t, "Buckle", 0, -0.63, 2.62, 2.32, 0.17, 0.03, "gold", ch=0.015, a=0.6, b=0.4)


def _skirt(k):
	"""Split skirt plates from the belt to above the knee: two front plates parted at the centre, two back, a side plate each
	side; navy wedge marks at the front points; red cloth behind. Sidekick: the side plates go."""
	t = "UpperTorso"
	for s in (1, -1):
		front = [(s * 0.1, 2.36), (s * 1.12, 2.36), (s * 1.14, 1.5), (s * 0.62, 1.2), (s * 0.12, 1.42)]
		prism(k, t, f"Fauld{s}", front, -0.7, -0.6, "gold", a=0.56, b=0.46, g=0.1)
		prism(k, t, f"Wedge{s}", [(s * 0.36, 1.62), (s * 0.88, 1.62), (s * 0.62, 1.26)], -0.712, -0.698, "navy", a=0.46, b=0.3)
		back = [(s * 0.1, 2.36), (s * 1.12, 2.36), (s * 1.12, 1.46), (s * 0.6, 1.24), (s * 0.1, 1.44)]
		prism(k, t, f"Back{s}", back, 0.6, 0.7, "gold", a=0.52, b=0.46, g=0.1)
		if not SMALL:
			slab(k, f"Tasset{s}", [(-0.5, 2.36), (0.5, 2.36), (0.5, 1.5), (0.0, 1.34), (-0.5, 1.5)], s * 1.1, s * 1.2, "gold", part=t, a=0.54, b=0.46)
	prism(k, t, "Cloth", [(-0.56, 2.34), (0.56, 2.34), (0.8, 0.7), (0.0, 0.84), (-0.8, 0.7)], 0.7, 0.75, "red", a=0.48, b=0.4, g=0.14)


def _arm(k, side, s):
	"""The navy sleeve is the painted block; a round layered pauldron, a gold vambrace and gauntlet over it."""
	arm, ax = f"{side}UpperArm", s * 1.5
	# the pauldron dome caps the shoulder, its rim a little past the arm; a second lip under it reads as the layered plates
	rows = [(0.22, 0.66, 0.9), (0.58, 0.56, 0.8), (0.82, 0.3, 0.6), (0.88, 0.02, 0.5), (0.8, -0.2, 0.4), (0.62, -0.34, 0.3)]
	o = k.lathe(arm, "Pauldron", rows, "gold", n=10, at=(ax + s * 0.06, 0.0, 3.96), squash=0.94, outline=0)
	bake(o, "gold", k, a=0.58, b=0.44, g=0.1)
	if not SMALL:
		o = k.lathe(arm, "PauldronLip", [(0.62, 0.1, 0.5), (0.76, -0.08, 0.5), (0.68, -0.26, 0.4)], "gold", n=10, at=(ax + s * 0.1, 0.0, 3.6), squash=0.9, outline=0)
		bake(o, "gold", k, a=0.52, b=0.44)
	block(k, arm, "Vambrace", ax, 0, 3.0, 2.3, 0.56, 0.56, "gold", ch=0.06, flare=0.03, corner=0.18, jit=0.012, a=0.56, b=0.46, g=0.08)
	block(k, arm, "Gauntlet", ax, 0, 2.34, 1.9, 0.6, 0.6, "gold", ch=0.08, corner=0.2, a=0.58, b=0.44)
	block(k, arm, "Knuckle", ax, -0.5, 2.14, 1.96, 0.42, 0.14, "gold", ch=0.03, a=0.64, b=0.4)


def _leg(k, side, s):
	leg, px = f"{side}UpperLeg", s * 0.5
	# the pointed knee guard over the greave
	prism(k, leg, "Knee", [(px - 0.54, 1.6), (px + 0.54, 1.6), (px + 0.54, 1.3), (px, 1.06), (px - 0.54, 1.3)], -0.64, -0.5, "gold", a=0.6, b=0.42)
	block(k, leg, "Greave", px, 0, 1.24, 0.0, 0.56, 0.58, "gold", ch=0.06, corner=0.18, jit=0.012, mids=(0.6,), a=0.54, b=0.46, g=0.1)
	block(k, leg, "Toe", px, -0.38, 0.4, 0.0, 0.5, 0.42, "gold", ch=0.08, corner=0.24, a=0.56, b=0.46)


def _ea(k):
	"""Ea upright in the right hand, grip at the hand's centre. Named Ea*: build_boss_king.py joins these into one object.
	A gold pommel and guard, a navy grip, then three stacked dark cylinders round a gold core, fine red lines on each;
	the Sidekick gets one cylinder."""
	import bpy
	from mathutils import Vector

	p = "RightHand"
	before = set(bpy.data.objects)
	block(k, p, "EaPommel", 0, 0, 0.1, -0.08, 0.13, 0.13, "gold", ch=0.04, a=0.58, b=0.44)
	rod(k, p, "EaGrip", [(0, 0, 0.1), (0, 0, 0.72)], 0.085, "navy", n=6, a=0.46, b=0.4)
	block(k, p, "EaGuard", 0, 0, 0.96, 0.72, 0.3, 0.16, "gold", ch=0.05, flare=-0.08, a=0.6, b=0.44)
	segs = ((1.0, 1.86, 0.22),) if SMALL else ((1.0, 1.78, 0.22), (1.9, 2.66, 0.2), (2.78, 3.5, 0.18))
	top = segs[-1][1]
	rod(k, p, "EaCore", [(0, 0, 0.96), (0, 0, top + 0.34)], [0.08, 0.05], "gold", n=6, a=0.6, b=0.4)
	for i, (z0, z1, r) in enumerate(segs):
		rod(k, p, f"EaSeg{i}", [(0, 0, z0), (0, 0, z1)], r, "ea", n=8, a=0.5, b=0.46, g=0.06)
		if not SMALL:
			for j, (x0, x1) in enumerate(((-0.09, -0.065), (0.035, 0.06))):
				prism(k, p, f"EaLine{i}{j}", [(x0, z0 + 0.12), (x1, z0 + 0.12), (x1, z1 - 0.12), (x0, z1 - 0.12)], -r - 0.012, -r + 0.01, "glow", a=0.7, b=0.1)
	for o in set(bpy.data.objects) - before:
		for v in o.data.vertices:
			v.co += Vector(EA_AT)


def _key(k):
	"""The Key of Babylon flat at the left hip, pivot at the belt. Named Key*: joined into one object by build_boss_king.py.
	A round barrel head, a flat shaft, blocky teeth; the Sidekick gets the shaft and head as one plate."""
	import bpy
	from mathutils import Vector

	t = "UpperTorso"
	before = set(bpy.data.objects)
	head = [(0.3 * math.cos(2 * math.pi * j / 10), -0.32 + 0.3 * math.sin(2 * math.pi * j / 10)) for j in range(10)]
	if SMALL:
		prism(k, t, "KeyBody", [(-0.3, -0.32), (-0.1, -0.04), (0.1, -0.04), (0.3, -0.32), (0.1, -0.6), (0.1, -1.4), (-0.1, -1.4), (-0.1, -0.6)], -0.06, 0.06, "gold", a=0.6, b=0.4)
	else:
		prism(k, t, "KeyHead", head, -0.08, 0.08, "gold", a=0.6, b=0.4)
		prism(k, t, "KeyShaft", [(-0.08, -0.56), (0.08, -0.56), (0.08, -1.46), (-0.08, -1.46)], -0.05, 0.05, "gold", a=0.58, b=0.4)
		for i, (z, w) in enumerate(((-0.84, 0.2), (-1.06, 0.16), (-1.32, 0.22))):
			prism(k, t, f"KeyTooth{i}", [(0.08, z + 0.06), (0.08 + w, z + 0.06), (0.08 + w, z - 0.06), (0.08, z - 0.06)], -0.05, 0.05, "gold", a=0.56, b=0.4)
	for o in set(bpy.data.objects) - before:
		for v in o.data.vertices:
			v.co += Vector(KEY_AT)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_ears(k)
	_top(k)
	_skirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_ea(k)
	_key(k)
	finish()


# ---- paint


def _torso(a):
	"""Navy underlayer with a gold centre line; the plate blocks cover most of it."""
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(NAVY)
		form(a[n], NAVY_D, 0.5)
	a["Torso_F"].path("M96 -5H104V205H96Z", GOLD, opacity=0.8)
	a["Torso_Bo"].fill(NAVY_D)


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(NAVY)
			form(a[f"{side}Arm_{key}"], NAVY_D, 0.5)
			a[f"{side}Leg_{key}"].fill(NAVY)
			form(a[f"{side}Leg_{key}"], NAVY_D, 0.5)
		a[f"{side}Arm_T"].fill(NAVY)
		a[f"{side}Arm_Bo"].fill(shade(GOLD, 0.7))
		a[f"{side}Leg_T"].fill(NAVY)
		a[f"{side}Leg_Bo"].fill(shade(GOLD, 0.6))


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f0b0a0", top=20)
	# narrow sharp red eyes, a sure look; thin pale brows set low at the inner end; a thin smirk lifted to the viewer's right
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 64, s, 32, 11, "#c81c22", tilt=2.0, r=9, lid=0.18, lash="#3a2418", lash_t=3.0, flick=3.0, pupil=0.4, sclera="#fffaf4", crease_line=False)
		brow2(f, x + s * 1, 44, s, 20, 4.6, 3.0, "#b8903a", arc=-1.0)
	f.soft("M61 84L65 79L69 84Q65 88 61 84Z", SKIN_D, 0.6, 1)
	f.path("M55 104Q66 108 78 100", stroke="#9a5a52", sw=2.4)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.84), shade(SKIN, 0.64))
	# the back of the head is hair to the nape; the sides are hair above the ear line
	a["Head_B"].fill("#e6cc70")
	a["Head_B"].soft("M-5 96Q65 104 135 96V135H-5Z", "#b09040", 0.7, 3)
	for n in ("Head_L", "Head_R"):
		a[n].path("M-5 -5H125V58Q60 66 -5 58Z", "#e6cc70")
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill("#e6cc70")
	_torso(a)
	_limbs(a)
