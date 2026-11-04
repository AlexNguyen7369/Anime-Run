# Target look for soul_fang "Renjy" (design doc section 5): a tall red ponytail bursting into spikes, the forehead bare under white-strapped
# goggles with one dark visor and an orange stripe, forked dark tattoo lines from the brow up the forehead, tattoo wedges at the top of the chest (the block figure has no neck); a black robe over a white undershirt, a thin white cord,
# wide black hakama, white split-toe socks and straw sandals, a plain sword at his left hip. +X is the viewer's right in the front view.
# Drawn in-house. The tattoos are a body pattern, not symbol marks (owner 2026-11-04): they follow the source layout and shape.
import math

from atlas import shade
from db_style3 import pipe
from jk_common import eye2, form
from jk_style3 import Kit, bake, big_head, block, crown, dress_shoe, ears, finish, gem, head_rest, prism, sleeve, slab, torso_core
from style2 import Ramps

SKIN = "#f0c49a"
SKIN_D = "#c08a62"
INK = "#14131f"  # the tattoos: near black with a little indigo
COAT = "#1c1e27"
COAT_L = "#3a3e4e"
WHITE = "#eef0f4"
RED_D = "#7c141a"
DEFAULT = COAT
R = Ramps(
	hair=["#5a0d12", "#971820", "#c92a2a", "#e8483a", "#ff7a5c"],
	skin=["#a87450", "#d4a078", "#f0c49a", "#fad8b4"],
	coat=["#0b0c11", "#15161e", "#23252f", "#363947", "#505464"],
	hakama=["#090a0f", "#12131a", "#1e2029", "#2f323e", "#474a58"],
	white=["#8f94a4", "#c6cad4", "#e6e8ee", "#f6f7fa", "#ffffff"],
	lens=["#07080c", "#10141b", "#1c2630", "#34485a"],
	stripe=["#9c4d17", "#cf7224", "#ee9238", "#ffb561"],
	strap=["#8a8d9a", "#bcc0ca", "#dfe1e7", "#f8f9fb"],
	tie=["#0b0b0f", "#17171d", "#2a2a33", "#42424e"],
	straw=["#6d5428", "#957740", "#bb9c5e", "#dcc186"],
	sheath=["#2c070a", "#4e0e12", "#74161c", "#9c2a2c"],
	wrap=["#14060a", "#2a0b10", "#4a1218", "#6e2026"],
	guard=["#26262c", "#44444c", "#6c6c76", "#9a9aa4"],
)
HAIR = {"colour": "#C92A2A", "locks": []}
PROPS = []


def _hair(k):
	# everything is dragged back off the forehead to one tie high on the crown
	crown(k, [(0.98, 5.36), (1.03, 5.6), (0.94, 5.88), (0.58, 6.12), (0.18, 6.2)])
	block(k, "Head", "Back", 0, 0.36, 5.46, 4.6, 0.92, 0.5, "hair", ch=0.06, corner=0.3, jit=0.03, sub=1, mids=(5.0,), a=0.42, b=0.44)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.3, 5.42), (-0.18, 5.08), (0.1, 4.96), (0.4, 4.7), (0.86, 4.7), (0.86, 5.42)], s * 0.8, s * 0.95, "hair", a=0.42, b=0.46)
		gem(k, "Head", f"Burn{s}", (s * 0.9, -0.2, 5.4), (s * 0.93, -0.24, 4.84), 0.14, flat=0.3, twist=0.3, across=(0, 1, 0), a=0.46)
	# planes combed from the hairline up to the tie, standing proud of the dome so it never reads as a cap
	for i, (x0, z0, x1) in enumerate(((-0.74, 5.56, -0.16), (-0.38, 5.62, -0.08), (0.0, 5.64, 0.0), (0.38, 5.62, 0.08), (0.74, 5.56, 0.16))):
		gem(k, "Head", f"Comb{i}", (x0, -0.74, z0), (x1, 0.42, 6.34), 0.36, flat=0.42, twist=0.15 + 0.1 * i, a=0.52, b_=0.62)
	for s in (1, -1):
		for i, (y, z, ty, tz) in enumerate(((-0.42, 5.62, 0.5, 6.0), (0.02, 5.56, 0.92, 5.84), (0.46, 5.54, 1.14, 5.44))):
			gem(k, "Head", f"Swept{s}{i}", (s * 0.92, y, z), (s * (0.74 - 0.08 * i), ty, tz), 0.3, flat=0.4, twist=0.2 + 0.1 * i, across=(0, 0, 1), a=0.5, b_=0.6)
	# the hair at the nape, a few points past the head
	for i, (x, z, r) in enumerate(((-0.66, 4.44, 0.26), (-0.22, 4.34, 0.3), (0.24, 4.34, 0.3), (0.68, 4.44, 0.26))):
		gem(k, "Head", f"Nape{i}", (x * 0.9, 0.72, 5.1), (x, 0.92, z), r, flat=0.3, twist=0.2 + 0.15 * i, a=0.42)
	# the tie and the stem it gathers
	block(k, "Head", "Stem", 0, 0.34, 6.5, 6.02, 0.27, 0.27, "hair", ch=0.05, corner=0.3, a=0.46, b=0.44)
	block(k, "Head", "Tie", 0, 0.34, 6.36, 6.22, 0.3, 0.3, "tie", ch=0.03, corner=0.3, a=0.5, b=0.4)
	# the burst: tall spikes up top, longer ones falling behind to between the shoulders
	root = (0, 0.34, 6.42)
	tips = (
		((0.06, 0.2, 7.24), 0.34),
		((-0.46, 0.22, 7.14), 0.32),
		((0.5, 0.24, 7.1), 0.32),
		((-0.88, 0.5, 6.84), 0.3),
		((0.92, 0.5, 6.8), 0.3),
		((-0.4, 0.84, 7.1), 0.32),
		((0.42, 0.84, 7.08), 0.32),
		((-1.06, 0.86, 6.36), 0.28),
		((1.08, 0.86, 6.34), 0.28),
		((0, 1.3, 6.84), 0.34),
		((-0.66, 1.34, 6.3), 0.3),
		((0.66, 1.34, 6.28), 0.3),
		((-0.3, 1.66, 5.8), 0.32),
		((0.32, 1.66, 5.78), 0.32),
		((-0.62, 1.5, 5.2), 0.28),
		((0.62, 1.5, 5.18), 0.28),
		((-0.26, 1.46, 4.62), 0.3),
		((0.26, 1.46, 4.58), 0.3),
		((0, 1.34, 4.16), 0.3),
	)
	for i, (t, r) in enumerate(tips):
		gem(k, "Head", f"Burst{i}", root, t, r, flat=0.55, bend=0.12 if t[2] < 6.6 else 0.03, twist=0.2 + 0.13 * i, a=0.48, b_=0.6)


def _goggles(k):
	"""Pushed up where the hair starts: a white strap round the head, one dark visor in a white frame, an orange stripe across it."""
	rings = []
	n = 16
	for x_y, z in ((1.0, 5.34), (1.05, 5.36), (1.05, 5.5), (1.0, 5.52)):
		ring = []
		for j in range(n):
			a = 2 * math.pi * j / n
			c, sn = math.cos(a), math.sin(a)
			ring.append((1.02 * x_y * math.copysign(abs(c) ** 0.55, c), 0.04 + 0.97 * x_y * math.copysign(abs(sn) ** 0.55, sn), z))
		rings.append(ring)
	verts, faces, flat = k._loft(rings)
	bake(k._mesh("Strap", "Head", verts, faces, flat, outline=0), "strap", k, a=0.52, b=0.4)
	block(k, "Head", "Frame", 0, -0.98, 5.78, 5.34, 1.0, 0.1, "white", ch=0.04, corner=0.25, a=0.56, b=0.4)
	block(k, "Head", "Visor", 0, -1.085, 5.71, 5.37, 0.92, 0.015, "lens", ch=0.008, corner=0.2, a=0.46, b=0.5, g=0.3)
	block(k, "Head", "Stripe", 0, -1.105, 5.61, 5.55, 0.84, 0.008, "stripe", ch=0.004, a=0.56, b=0.3)


def _robe(k):
	t = "UpperTorso"
	torso_core(k, hem=2.0)
	k.tube(t, "Jacket", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.05, 0.57), (0, 0, 2.05, 1.08, 0.6), (0, 0, 1.86, 1.1, 0.62)], ("face", "Torso"), corner=0.14, nc=1, sub=1, outline=0)
	# the crossing front: raised black edges, the wearer's left lying over the right
	prism(k, t, "LapelR", [(-1.0, 3.98), (-0.74, 3.98), (0.04, 2.84), (-0.1, 2.62)], -0.61, -0.555, "coat", a=0.58, b=0.5)
	prism(k, t, "LapelL", [(0.74, 3.98), (1.0, 3.98), (-0.12, 2.46), (-0.12, 2.8)], -0.635, -0.56, "coat", a=0.62, b=0.5)
	# the thin white cord and its small knot
	block(k, t, "Cord", 0, 0, 2.42, 2.28, 1.09, 0.61, "white", ch=0.03, corner=0.14, sub=1, a=0.5, b=0.36)
	block(k, t, "CordKnot", -0.5, -0.63, 2.46, 2.24, 0.12, 0.05, "white", ch=0.03, a=0.56, b=0.34)


def _sword(k):
	"""Sheathed through the cord at his left hip, the hilt forward, the tip behind."""
	t = "UpperTorso"
	a, tip = (0.8, -1.0, 2.72), (0.9, 1.26, 1.72)
	lerp = lambda u: tuple(a[i] + (tip[i] - a[i]) * u for i in range(3))
	pipe(k, t, "Sheath", [lerp(0.08) + (0.1,), lerp(0.6) + (0.11,), lerp(0.97) + (0.1,), lerp(1.0) + (0.05,)], "sheath", rn=6, base=0.46, amp=0.42, grad=0.0)
	pipe(k, t, "Guard", [lerp(0.05) + (0.18,), lerp(0.08) + (0.18,)], "guard", rn=6, base=0.5, amp=0.4, grad=0.0)
	pipe(k, t, "Hilt", [(0.76, -1.5, 2.94, 0.08), lerp(0.1) + (0.085,)], "wrap", rn=6, base=0.5, amp=0.4, grad=0.0)


def _sleeve(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	sleeve(k, side, s, ramp="coat", cuff=2.4)
	# a wide mouth, the white undersleeve just showing at the wrist
	block(k, arm, "Mouth", ax, 0, 2.72, 2.36, 0.55, 0.55, "coat", ch=0.04, flare=0.04, corner=0.18, a=0.5, b=0.58)
	block(k, arm, "Under", ax, 0, 2.38, 2.24, 0.51, 0.51, "white", ch=0.02, corner=0.16, a=0.56, b=0.36)


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.53
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# wide hakama, falling straight over the sock, with a pleat or two for the eye
	block(k, leg, "Thigh", px, 0, 1.97, 1.12, 0.49, 0.56, "hakama", ch=0.04, flare=0.02, corner=0.16, jit=0.03, mids=(1.55,), a=0.46, b=0.6, tone=0.05)
	block(k, leg, "Shin", px, 0, 1.18, 0.36, 0.51, 0.58, "hakama", ch=0.04, flare=0.04, corner=0.16, jit=0.03, mids=(0.72,), a=0.46, b=0.6, tone=0.05)
	for i, dx in enumerate((-0.2, 0.18)):
		block(k, leg, f"Pleat{i}", px + s * dx, -0.61, 1.9, 0.42, 0.018, 0.016, "tie", ch=0.005, a=0.5, b=0.1)
	dress_shoe(k, leg, px, ramp="white", sole="straw", top=0.42)
	# the sandal's thong over the sock
	block(k, leg, "Thong", px, -0.5, 0.3, 0.14, 0.05, 0.27, "tie", ch=0.01, a=0.5, b=0.3)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.72)
	_hair(k)
	_goggles(k)
	_robe(k)
	_sword(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_sleeve(k, side, s)
		_leg(k, side, s)
	finish()


# ---- paint


def _fold(f, x0, y0, cx, cy, x1, y1, op=0.55, sw=6):
	f.path(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", stroke=COAT_L, sw=sw, opacity=op, blur=2)


def _torso(a):
	f = a["Torso_F"]
	f.fill(COAT)
	# the V: a white undershirt edge round bare skin
	f.path("M22 -5H178L100 136Z", WHITE)
	f.path("M44 -5H156L100 104Z", SKIN)
	f.soft("M44 -5H156V16H44Z", SKIN_D, 0.85, 3)
	f.soft("M44 -5L100 104V84L60 -5Z", SKIN_D, 0.5, 2)
	f.soft("M156 -5L100 104V84L140 -5Z", SKIN_D, 0.6, 2)
	# the neck tattoos, moved to the top of the chest: stacked wedges rooted at the collar, tips running in and down
	for s in (1, -1):
		c = lambda u: 100 + s * u
		f.path(f"M{c(56)} -2L{c(49)} 12L{c(38)} 13L{c(16)} 27L{c(30)} 7L{c(42)} 4Z", INK)
		f.path(f"M{c(47)} 15L{c(40)} 29L{c(31)} 30L{c(13)} 47L{c(23)} 25L{c(35)} 19Z", INK)
		f.path(f"M{c(37)} 33L{c(32)} 44L{c(26)} 46L{c(14)} 62L{c(18)} 43L{c(27)} 36Z", INK)
	_fold(f, 16, 70, 40, 110, 80, 140)
	_fold(f, 184, 72, 160, 112, 120, 142)
	_fold(f, 30, 160, 40, 175, 28, 196, 0.5, 5)
	_fold(f, 170, 160, 160, 175, 172, 196, 0.5, 5)
	f.path("M100 176L93 205H107Z", "#0a0b10")
	form(f, "#000000", 0.5)
	f = a["Torso_B"]
	f.fill(COAT)
	_fold(f, 14, 56, 44, 78, 88, 112)
	_fold(f, 186, 58, 156, 80, 112, 114)
	_fold(f, 40, 165, 48, 178, 38, 198, 0.5, 5)
	_fold(f, 160, 165, 152, 178, 162, 198, 0.5, 5)
	form(f, "#000000", 0.5)
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		f.fill(COAT)
		_fold(f, 20, 40, 34, 90, 26, 150, 0.45, 5)
		form(f, "#000000", 0.5)
	a["Torso_T"].fill(COAT)
	a["Torso_Bo"].fill("#0a0b10")


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(COAT)
			a[f"{side}Leg_{key}"].fill(shade(COAT, 0.9))
		a[f"{side}Arm_T"].fill(COAT)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(COAT)
		a[f"{side}Leg_Bo"].fill("#0a0b10")


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V8Q65 12 -5 8Z", SKIN_D, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.7, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.85, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	for cx, s in ((39, -1), (91, 1)):
		eye2(f, cx, 66, s, 36, 15, "#6e2a1c", tilt=3.6, r=9.5, lid=0.22, lash="#17121a", lash_t=3.2, flick=3, pupil=0.42, sclera="#f6f2ea", crease_line=False)
		# the tattoo: a brow line, pointed and low at the nose, thick as it climbs out to the temple
		c = lambda u: 65 + s * u
		f.path(f"M{c(6)} 57Q{c(20)} 48 {c(33)} 37L{c(47)} 18L{c(44)} 36Q{c(32)} 49 {c(20)} 53Q{c(12)} 56 {c(6)} 57Z", INK)
		# forks rising off it to the hairline
		f.path(f"M{c(13)} 50L{c(16)} 22L{c(25)} 43Z", INK)
		f.path(f"M{c(25)} 44L{c(32)} 12L{c(36)} 36Z", INK)
		# the upper line along the hairline, ending in a zigzag at the temple
		f.path(f"M{c(39)} 26L{c(50)} 14L{c(64)} 16L{c(56)} 28L{c(66)} 40L{c(52)} 34L{c(55)} 25L{c(49)} 21Z", INK)
	# nose, a hard grin on one side with one fang
	f.path("M63 76L67 90L60 91Q64 84 63 76Z", SKIN_D, opacity=0.9)
	f.path("M46 104Q66 111 88 98", stroke="#2c1612", sw=2.6)
	f.path("M77 102L80 109L83 100Z", "#fffdf8", stroke="#2c1612", sw=0.8)
	f.path("M56 115Q66 118 76 114", stroke=shade(SKIN, 0.68), sw=1.3)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.86), shade(SKIN, 0.66))
	a["Head_T"].fill("#971820")
	a["Head_B"].fill("#7c141a")
	_torso(a)
	_limbs(a)
