# Target look for foe_soul "Ulquiorro" (design doc section 5): messy black hair, a broken bone half-mask with one horn on his left side,
# chalk skin, green slit eyes with a teal line running down from each, thin black lips; a white jacket with a tall open collar, a V at
# the chest over a hole through the sternum and a dark mark on his left chest, a black sash, long split coat tails, white hakama, black
# shoes and a dark green sheathed sword at his left hip. +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import shade
from db_style3 import pipe
from jk_common import eye2, form
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, finish, gem, head_rest, prism, sleeve, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#f3f2ee"
SKIN_D = "#c5c5cc"
COAT = "#dfe2ea"
COAT_D = "#9aa2b6"
HOLLOW = "#07070c"
TEAL = "#1f8f88"
DEFAULT = COAT
R = Ramps(
	hair=["#040509", "#0a0c13", "#141822", "#272d3d", "#46506a"],
	skin=["#a9a9b4", "#c9c9cf", "#e6e5e2", "#f4f3f0"],
	coat=["#6f7a93", "#98a1b6", "#c2c7d4", "#dce0e8", "#eef0f5"],
	hakama=["#646f88", "#8d96ab", "#b6bccb", "#d0d4df", "#e4e7ee"],
	bone=["#8b8875", "#c2bfa8", "#e6e3d2", "#f8f6ea", "#ffffff"],
	crack=["#27251f", "#3d3a31", "#57534a", "#6f6b5e"],
	black=["#050507", "#0d0d12", "#1b1b23", "#32323f"],
	shoe=["#07070b", "#101117", "#1f2029", "#343643"],
	sole=["#040406", "#0b0b10", "#17171e", "#26262f"],
	green=["#07241a", "#0f3f2b", "#1b6143", "#37946b"],
	wrap=["#0b1f18", "#123326", "#1f523c", "#3b7d5e"],
	guard=["#25302a", "#3e4d44", "#66776c", "#96a89c"],
)
HAIR = {"colour": "#0B0D14", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.46), (1.05, 5.66), (0.95, 5.9), (0.56, 6.14), (0.16, 6.22)])
	block(k, "Head", "Cap", 0, 0.02, 5.76, 5.3, 1.03, 0.89, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.44, b=0.44)
	block(k, "Head", "Back", 0, 0.28, 5.46, 4.7, 0.92, 0.6, "hair", ch=0.06, corner=0.3, jit=0.03, sub=1, mids=(5.1, 4.9), a=0.4, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.5, 5.42), (-0.48, 4.86), (-0.32, 4.5), (0.46, 4.5), (0.86, 4.86), (0.86, 5.42)], s * 0.8, s * 0.96, "hair", a=0.42, b=0.46)
		# uneven strands down the side of the face, shorter on the masked side
		for i, (y, z, r) in enumerate(((-0.56, 4.3 if s < 0 else 4.46, 0.2), (-0.26, 4.2 if s < 0 else 4.3, 0.24), (0.06, 4.24, 0.24), (0.34, 4.34, 0.22))):
			gem(k, "Head", f"Strand{s}{i}", (s * 0.9, y, 5.4), (s * 0.9, y + 0.02 * i, z), r, flat=0.22, twist=0.2 + 0.2 * i, across=(0, 1, 0), a=0.42)
	# the nape: ragged points tucked inside the collar's height
	for i, (x, z, r) in enumerate(((-0.72, 4.36, 0.26), (-0.36, 4.24, 0.3), (0.02, 4.3, 0.3), (0.38, 4.22, 0.3), (0.74, 4.38, 0.26))):
		gem(k, "Head", f"Nape{i}", (x * 0.9, 0.78, 5.3), (x, 0.82, z), r, flat=0.2, twist=0.2 + 0.15 * i, a=0.42)
	# messy bangs falling over the brow; one thin lock drops between the eyes
	root = (0, -0.8, 5.76)
	for i, (t, r) in enumerate((((-0.88, -0.92, 4.86), 0.24), ((-0.62, -0.94, 5.02), 0.25), ((-0.36, -0.95, 5.0), 0.22), ((-0.12, -0.95, 4.66), 0.13), ((0.12, -0.95, 5.02), 0.2), ((0.36, -0.95, 5.0), 0.22))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.46, across=(0, 0, 1))
	# clumps breaking the top of the head, away from the mask
	for i, (b, t, r) in enumerate((((-0.1, 0.1, 5.9), (-1.12, -0.18, 5.56), 0.3), ((-0.1, 0.1, 5.96), (-0.72, 0.06, 6.34), 0.28), ((-0.1, 0.2, 5.9), (-0.92, 0.82, 5.46), 0.3), ((0, 0.2, 5.9), (-0.06, 1.04, 5.44), 0.34), ((0.2, 0.2, 5.86), (0.86, 0.9, 5.4), 0.3), ((-0.1, -0.1, 5.96), (-0.26, -0.5, 6.32), 0.26))):
		gem(k, "Head", f"Clump{i}", b, t, r, flat=0.5, twist=0.3, a=0.46)


def _mask(k):
	"""The broken half-mask: a bone cap on the upper side of his left, a jagged rim, and one horn."""
	rows = [(0.66, -0.06, 5.22, 0.36, 0.76), (0.66, -0.06, 5.36, 0.42, 0.86), (0.66, -0.05, 5.74, 0.43, 0.87), (0.6, -0.04, 6.0, 0.37, 0.72), (0.5, -0.03, 6.2, 0.26, 0.46), (0.44, -0.02, 6.27, 0.1, 0.16)]
	bake(k.tube("Head", "MaskCap", rows, "bone", corner=0.3, nc=1, sub=1, outline=0), "bone", k, a=0.5, b=0.46)
	# the jagged rim over the brow and down the temple, and shards at the broken edge
	prism(k, "Head", "MaskBrow", [(0.16, 5.72), (1.09, 5.72), (1.09, 5.1), (0.97, 5.3), (0.82, 5.08), (0.64, 5.28), (0.48, 5.14), (0.32, 5.36), (0.2, 5.3)], -0.97, -0.9, "bone", a=0.56, b=0.34)
	slab(k, "MaskSide", [(-0.93, 5.72), (0.68, 5.72), (0.68, 5.3), (0.42, 5.46), (0.14, 5.22), (-0.2, 5.4), (-0.56, 5.04), (-0.93, 5.1)], 1.03, 1.09, "bone", a=0.52, b=0.4)
	for i, (b, t, r) in enumerate((((0.34, -0.5, 5.86), (0.06, -0.8, 5.98), 0.18), ((0.3, 0.12, 6.08), (-0.02, 0.08, 6.22), 0.18), ((0.36, 0.56, 5.88), (0.1, 0.84, 5.8), 0.18))):
		gem(k, "Head", f"Shard{i}", b, t, r, "bone", flat=0.45, twist=0.2, a=0.56, b_=0.36)
	gem(k, "Head", "Horn", (0.78, -0.1, 5.96), (1.04, -0.36, 7.0), 0.22, "bone", flat=0.8, bend=0.05, twist=0.25, a=0.58, b_=0.38)


def _collar(k):
	"""Tall and open at the front: an open horseshoe rising to the back, a white outside and a black lining."""
	t = "UpperTorso"
	for name, ramp, r0, r1, bk in (("Collar", "coat", 1.08, 1.02, dict(a=0.52, b=0.46)), ("CollarLining", "black", 1.02, 0.98, dict(a=0.5, b=0.3))):
		rings = []
		n = 14
		for j in range(n + 1):
			ang = math.radians(-90 + 34 + (360 - 68) * j / n)
			c, sn = math.cos(ang), math.sin(ang)
			px, py = math.copysign(abs(c) ** 0.3, c), math.copysign(abs(sn) ** 0.3, sn)
			top = 4.46 + 0.4 * ((sn + 1) / 2) ** 0.7
			if name == "CollarLining":
				top -= 0.02
			# narrow where it grows from the jacket, opening out by the knee so hair and jaw stay inside
			d0, d1 = 0.93 * r0 * py, 0.93 * r1 * py
			rings.append([(0.9 * px, 0.54 * py, 3.92), (r0 * px, d0, 4.14), (r0 * px, d0, top), (r1 * px, d1, top), (r1 * px, d1, 4.14), (0.86 * px, 0.5 * py, 3.92)])
		verts, faces, flat = k._loft(rings)
		bake(k._mesh(name, t, verts, faces, flat, outline=0), ramp, k, **bk)


def _coat(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	_collar(k)
	# the raised edges of the V, the fastening below it, the black sash
	for s in (1, -1):
		prism(k, t, f"Edge{s}", [(s * 0.7, 3.98), (s * 0.88, 3.98), (s * 0.09, 2.78), (0, 2.84)], -0.615, -0.56, "coat", a=0.6, b=0.36)
	block(k, t, "Fastening", 0, -0.585, 2.86, 2.4, 0.022, 0.03, "black", ch=0.008, a=0.4)
	block(k, t, "Sash", 0, 0, 2.48, 2.2, 1.09, 0.61, "black", ch=0.03, corner=0.14, sub=1, a=0.48, b=0.34)


def _sword(k):
	"""Sheathed through the sash at his left hip, the hilt forward, the tip behind."""
	t = "UpperTorso"
	a, tip = (0.8, -1.0, 2.7), (0.9, 1.22, 1.72)
	lerp = lambda u: tuple(a[i] + (tip[i] - a[i]) * u for i in range(3))
	pipe(k, t, "Sheath", [lerp(0.08) + (0.1,), lerp(0.6) + (0.11,), lerp(0.97) + (0.1,), lerp(1.0) + (0.05,)], "green", rn=6, base=0.46, amp=0.42, grad=0.0)
	pipe(k, t, "Guard", [lerp(0.05) + (0.17,), lerp(0.08) + (0.17,)], "guard", rn=6, base=0.5, amp=0.4, grad=0.0)
	pipe(k, t, "Hilt", [(0.76, -1.44, 2.89, 0.08), lerp(0.1) + (0.085,)], "wrap", rn=6, base=0.5, amp=0.4, grad=0.0)


def _tail(k, leg, s):
	"""One half of the split coat tail: wraps from the front of the hip round the outside to the slit at the back, flaring as it falls."""
	# plan outline, +x side: (x, y, hem z of this column)
	cols = [(0.72, -0.64, 1.1), (1.04, -0.64, 0.9), (1.12, -0.56, 0.8), (1.12, 0.56, 0.44), (1.04, 0.64, 0.4), (0.54, 0.65, 0.34), (0.03, 0.65, 0.32)]
	rings = []
	for r in (0.0, 0.35, 0.7, 1.0):
		flare = 1 + 0.1 * r
		outer, inner = [], []
		for i, (x, y, hem) in enumerate(cols):
			z = 2.0 + (hem - 2.0) * r
			# the slit and the front edge stay in line, only the outside swings out
			fx = x if x < 0.1 else x * flare
			jag = 0.02 * math.sin(i * 2.3 + r * 5) * (0 < r < 1)
			outer.append((s * fx, y * flare + jag, z))
			inner.append((s * (fx - 0.05 if x > 0.1 else fx), (y - 0.05 * (1 if y > 0 else -1)) * flare + jag, z))
		rings.append(outer + inner[::-1])
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Tail", leg, verts, faces, flat, outline=0), "coat", k, a=0.5, b=0.56, g=0.1)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# wide hakama, falling straight over the shoe
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.49, 0.55, "hakama", ch=0.04, flare=0.02, corner=0.16, jit=0.03, mids=(1.55,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Shin", px, 0, 1.18, 0.28, 0.5, 0.56, "hakama", ch=0.04, flare=0.03, corner=0.16, jit=0.03, mids=(0.72,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Pleat", px - s * 0.14, -0.585, 1.9, 0.34, 0.016, 0.014, "hakama", ch=0.005, a=0.24, b=0.1)
	_tail(k, leg, s)
	dress_shoe(k, leg, px, top=0.4)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_mask(k)
	_coat(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="coat", cuff=2.36)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.5, sw=7):
	"""A cloth fold on white: a soft cool shadow and no ink line."""
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=COAT_D, sw=sw, opacity=op, blur=2)


def _mark(f, cx, cy):
	"""Number tattoo, changed: a black stem with two chevrons, where the numeral would sit."""
	for dy in (-11, -3):
		f.path(f"M{cx - 7} {cy + dy}L{cx} {cy + dy + 6}L{cx + 7} {cy + dy}V{cy + dy + 4}L{cx} {cy + dy + 10}L{cx - 7} {cy + dy + 4}Z", HOLLOW)
	f.path(f"M{cx - 1.5} {cy - 5}H{cx + 1.5}V{cy + 12}H{cx - 1.5}Z", HOLLOW)


def _torso(a):
	f = a["Torso_F"]
	f.fill(COAT)
	# the V opening: bare chalk skin, the hole through the sternum and the mark on his left chest
	f.path("M34 -5H166L100 116Z", SKIN)
	f.soft("M34 -5H166V14H34Z", SKIN_D, 0.85, 3)
	f.soft("M34 -5L100 116V96L52 -5Z", SKIN_D, 0.5, 2)
	f.soft("M166 -5L100 116V96L148 -5Z", SKIN_D, 0.6, 2)
	f.path("M100 40a22 23 0 1 0 0.01 0Z", shade(SKIN_D, 0.72))
	f.path("M100 43a19.5 20.5 0 1 0 0.01 0Z", HOLLOW)
	f.path("M83.5 66Q100 86 116.5 66Q100 76 83.5 66Z", "#2c3042")
	_mark(f, 133, 24)
	# the coat below the V, under the sash and the split at the fork
	_fold(f, 16, 40, 40, 80, 78, 112)
	_fold(f, 184, 42, 160, 82, 122, 114)
	_fold(f, 26, 120, 40, 140, 30, 164, 0.45, 6)
	_fold(f, 174, 122, 160, 142, 170, 164, 0.45, 6)
	f.path("M100 176L92 205H108Z", COAT_D, opacity=0.9)
	stroke(f, "M100 118V124", COAT_D, 1.2, 0.8)
	form(f, COAT_D, 0.55)
	f = a["Torso_B"]
	f.fill(COAT)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	_fold(f, 40, 128, 48, 150, 38, 172, 0.45, 6)
	_fold(f, 160, 128, 152, 150, 162, 172, 0.45, 6)
	stroke(f, "M100 178V205", COAT_D, 2.2, 0.9)
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
	f.soft("M-5-5H135V34Q65 42 -5 34Z", SKIN_D, 0.85, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	for cx, s in ((39, -1), (91, 1)):
		# the teal line, widest under the eye, running down to the jaw
		f.path(f"M{cx + s * 2 - 3.2} 70L{cx + s * 2 + 3.2} 70L{cx + s * 3 + 1.2} 124L{cx + s * 3 - 1.2} 124Z", TEAL)
		eye2(f, cx, 62, s, 34, 14, "#46b566", tilt=-1.2, r=9.5, lid=0.32, lash="#0d0e14", lash_t=2.8, flick=2, pupil=0.42, sclera="#f6f7f2", crease_line=False, slit=True)
		# thin level brows, no anger in them
		f.path(f"M{cx - s * 15} 43Q{cx} 40 {cx + s * 15} 42L{cx + s * 15} 44Q{cx} 42.5 {cx - s * 15} 45.5Z", "#14161f")
	f.path("M63 72L67 86L61 87Q64 80 63 72Z", SKIN_D, opacity=0.9)
	# small black lips, set flat
	f.path("M54 103Q65 100 76 103Q65 108 54 103Z", "#101117")
	stroke(f, "M52 103H78", "#101117", 0.8)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_T"].fill("#141822")
	_torso(a)
	_limbs(a)
