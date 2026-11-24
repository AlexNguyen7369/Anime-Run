# Target look for dan_granny "Turbo Grammy" (design doc section 5): a huge mane of shaggy white hair down to the waist, parted over a small, ash-pale, deeply lined
# old face, yellow eyes staring out to the sides, a grey neck wrap, a dark red patterned jacket with wide sleeves, dark loose trousers, bare feet.
# Block body as everyone's. +X is the viewer's right. Drawn in-house.
import math

from dan_style3 import Kit, T, art_jacket, bake, bare_foot, big_head, block, collar, core_leg, crown, finish, form, gem, mop, prism, ramps, rest, scalp, stroke, torso_core, trouser
from leaf_common import begin_clip, ell, end_clip

SKIN = "#c9bfae"
SKIN_D = "#867c70"
RED = "#6e1e1c"
DEFAULT = RED
R = ramps(
	["#8c9488", "#b8beb2", "#dee0d8", "#f2f3ee", "#ffffff"],
	skin=["#867c70", "#a89e90", "#c9bfae", "#e6decf"],
	red=["#2c0a0c", "#4a1414", "#701f1e", "#944036"],
	wrap=["#343834", "#4c524c", "#6a716a", "#8c948c"],
	trim=["#1a0808", "#2c1010", "#421a18", "#5c2c28"],
	dark=["#14100e", "#221c1a", "#342c2a", "#4c423e"],
)
HAIR = {"colour": "#DEE0D8", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.06, 5.2), (1.18, 5.5), (1.14, 5.9), (0.84, 6.24), (0.26, 6.42)])
	# the mane behind and over the shoulders, in three overlapping shaggy layers
	mop(k, "Low", [(d, 2.3 - 0.16 * (i % 2), 0.46) for i, d in enumerate((20, 42, 66, 90, 114, 138, 160))], rx=1.34, ry=1.3, zroot=4.9, root=0.86, bend=0.04, a=0.48)
	mop(k, "Mid", [(d, 3.3 + 0.18 * (i % 2), 0.46) for i, d in enumerate((0, 22, 45, 68, 90, 112, 135, 158, 180))], rx=1.44, ry=1.36, zroot=5.3, root=0.78, bend=0.1, a=0.52)
	mop(k, "Top", [(d, 4.4 + 0.2 * (i % 2), 0.46) for i, d in enumerate((-18, 8, 36, 64, 90, 116, 144, 172, 198))], rx=1.44, ry=1.36, zroot=5.9, root=0.62, bend=0.2, a=0.56)
	# the front curtains: they open like a tent from the brow and fall past the chest
	for s in (1, -1):
		for i, (b, t, r) in enumerate((
			((s * 0.1, -0.7, 6.3), (s * 0.5, -1.16, 4.92), 0.28), ((s * 0.3, -0.7, 6.26), (s * 0.8, -1.14, 4.44), 0.3), ((s * 0.56, -0.7, 6.1), (s * 0.98, -1.1, 3.84), 0.32),
			((s * 0.8, -0.8, 5.6), (s * 1.0, -1.16, 2.9), 0.34), ((s * 1.0, -0.7, 5.5), (s * 1.4, -1.04, 2.7), 0.38), ((s * 1.06, -0.4, 5.6), (s * 1.62, -0.8, 3.0), 0.4), ((s * 1.06, 0.0, 5.6), (s * 1.74, -0.3, 3.3), 0.42),
		)):
			gem(k, "Head", f"Curtain{s}{i}", b, t, r, flat=0.45, bend=0.06, twist=0.15 + 0.12 * (i % 3), across=(1, 0, 0) if i < 5 else (0, 1, 0), a=0.55)
		gem(k, "Head", f"Spray{s}", (s * 0.4, 0.0, 6.2), (s * 0.94, 0.2, 6.66), 0.3, flat=0.6, a=0.56)
	for i, (x, z) in enumerate(((-0.22, 6.86), (0.04, 7.0), (0.3, 6.8))):
		gem(k, "Head", f"Top{i}B", (x * 0.5, -0.1, 6.2), (x, 0.0, z), 0.24, flat=0.6, a=0.58)


def _wrinkles(k):
	"""Raised folds so the old face has real relief: brow ridges, cheek folds, a long nose, a puckered mouth."""
	y = -0.87
	for s in (1, -1):
		prism(k, "Head", f"Brow{s}", [(s * 0.1, 4.92), (s * 0.62, 4.98), (s * 0.66, 4.88), (s * 0.12, 4.78)], y - 0.06, y + 0.06, "skin", a=0.66, b=0.4)
		prism(k, "Head", f"Cheek{s}", [(s * 0.3, 4.56), (s * 0.68, 4.52), (s * 0.6, 4.32), (s * 0.42, 4.34)], y - 0.04, y + 0.06, "skin", a=0.6, b=0.4)
		prism(k, "Head", f"Jowl{s}", [(s * 0.42, 4.34), (s * 0.58, 4.3), (s * 0.52, 4.06), (s * 0.4, 4.08)], y - 0.03, y + 0.06, "skin", a=0.54, b=0.4)
	prism(k, "Head", "Nose", [(-0.05, 4.86), (0.05, 4.86), (0.1, 4.56), (0, 4.44), (-0.1, 4.56)], y - 0.16, y + 0.04, "skin", a=0.6, b=0.46)

	# the mouth: one thin downturned line
	prism(k, "Head", "Mouth", [(-0.34, 4.2), (-0.1, 4.28), (0.1, 4.28), (0.34, 4.2), (0.1, 4.25), (-0.1, 4.25)], y - 0.06, y, "dark", a=0.0, b=0.05)


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	k.tube(arm, "Sleeve", [(ax, 0, 4.03, 0.44, 0.44), (ax, 0, 3.96, 0.53, 0.53), (ax, 0, 3.0, 0.54, 0.55), (ax, 0, 2.36, 0.62, 0.64), (ax, 0, 2.32, 0.58, 0.6)], ("face", f"{side}Arm"), corner=0.18, nc=1, sub=1, outline=0)
	block(k, arm, "Cuff", ax, 0, 2.46, 2.28, 0.64, 0.66, "trim", ch=0.04, corner=0.18, a=0.5, b=0.5)
	block(k, arm, "Hand", ax, 0, 2.34, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.52, b=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_wrinkles(k)
	art_jacket(k, hem=1.84)
	collar(k, "wrap", 4.0, 4.4, z0=3.86, rx=0.8, ry=0.78, a=0.5, b=0.5)
	prism(k, T, "Wrap", [(-0.44, 4.04), (0.44, 4.04), (0.34, 2.9), (0, 2.7), (-0.34, 2.9)], -0.7, -0.58, "wrap", a=0.5, b=0.46)
	for s in (1, -1):
		prism(k, T, f"Edge{s}", [(s * 0.42, 4.04), (s * 0.64, 4.04), (s * 0.5, 2.96), (s * 0.08, 1.86), (s * -0.08, 1.86), (s * 0.04, 2.6), (s * 0.34, 2.96)], -0.73, -0.6, "trim", a=0.52, b=0.46)
	block(k, T, "Sash", 0, 0, 2.5, 2.26, 1.1, 0.62, "dark", ch=0.03, corner=0.14, a=0.5, b=0.5)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		leg, px = trouser(k, side, s, ramp="dark", low=0.7)
		block(k, leg, "Hem", px, 0, 0.84, 0.64, 0.52, 0.58, "trim", ch=0.04, corner=0.18, a=0.46)
		bare_foot(k, leg, px, top=0.7)
	finish()


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V24Q65 30 -5 24Z", SKIN_D, 0.8, 3)
	f.soft("M-5 20H14Q12 90 36 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 20H116Q118 90 94 135H135Z", SKIN_D, 0.8, 5)
	for s, cx in ((-1, 40), (1, 90)):
		f.soft(f"M{cx - 22} 56Q{cx} 40 {cx + 22} 56Q{cx} 78 {cx - 22} 56Z", "#5a5048", 0.8, 2)
		# bulging yellow eyes, pupils rolled outward
		shape = ell(cx, 57, 15, 12)
		begin_clip(f, shape)
		f.path(shape, "#f2c02c")
		f.path(ell(cx, 62, 12, 6), "#ffe680")
		f.path(ell(cx + s * 9, 57, 4.6, 6), "#180a04")
		f.path(ell(cx + s * 7.4, 54.5, 1.6, 2), "#ffffff")
		f.path(f"M{cx - 18} 44H{cx + 18}V50Q{cx} 46 {cx - 18} 51Z", "#5a5048", opacity=0.6)
		end_clip(f)
		f.path(shape, stroke="#160a06", sw=2.4)
		for i in range(3):
			stroke(f, f"M{cx - s * 14} {73 + i * 5}Q{cx + s * 4} {80 + i * 5} {cx + s * 20} {70 + i * 6}", "#7a6e62", 1.5)
		stroke(f, f"M{cx - s * 10} 88Q{cx + s * 2} 102 {cx - s * 6} 122", "#7a6e62", 1.6)
	for i, y in enumerate((30, 36, 42)):
		stroke(f, f"M38 {y}Q65 {y - 5 + i * 2} 92 {y}", "#7a6e62", 1.4)
	# a small sunken mouth, lips drawn tight over vertical creases
	f.path("M48 113Q65 106 82 113", stroke="#5a4e44", sw=1.6)
	for x in (52, 58, 64, 70, 76):
		stroke(f, f"M{x} 102L{x + 0.5} 108M{x} 117L{x + 0.5} 124", "#7a6e62", 1.2)


def _cloth(f, seed):
	f.fill(RED)
	r = f.rng
	for i in range(int(f.w * f.h / 900)):
		x, y, q = r.uniform(0, f.w), r.uniform(0, f.h), r.uniform(6, 11)
		f.path(f"M{x:.1f} {y:.1f}q{q:.1f} {-q:.1f} {2 * q:.1f} 0q{-q:.1f} {q * 1.2:.1f} {-2 * q:.1f} 0Z", "#8c3a30" if i % 2 else "#4a1212", opacity=0.75)
	form(f, "#1e0606", 0.5)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#b8beb2", RED, RED, "#342c2a")
	scalp(a, "#b8beb2", sides=30)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R"):
		_cloth(a[n], n)
	for side in ("Left", "Right"):
		for key in "FBOI":
			_cloth(a[f"{side}Arm_{key}"], key)
