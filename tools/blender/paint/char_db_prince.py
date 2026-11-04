# Target look for db_prince: one tall upward flame of black hair over a deep widow's peak, a scowl, white chest armour with
# gold shoulder and hip flaps, blue bodysuit, white gloves and boots with gold toes. +X is the viewer's right in the front view.
from db_style3 import arm_bands, block, box, hair_cap, hair_style, shell, slab, spikes
from leaf_common import begin_clip, end_clip
from db_common import circle
from style2 import H, Kit, Ramps, face
from style3 import big_head, finish

SKIN = "#f2cfae"
SKIN_D = "#d09c76"
BLUE = "#2b4fa8"
BLUE_D = "#182c6c"
WHITE = "#f4f4f0"
HAIRC = "#0a0a12"
LINE = "#3c2012"
DEFAULT = BLUE
R = Ramps(
	hair=["#040408", "#08080f", "#12122a", "#2c2c70", "#5a54c8"],
	skin=["#b5866a", "#d8a884", SKIN, "#fbe2c8"],
	blue=["#101e5a", "#1a3078", BLUE, "#3f68c8", "#5c86e0"],
	white=["#8e8ea4", "#c0c0d0", WHITE, "#ffffff"],
	gold=["#94660c", "#c48e1c", "#e8b63a", "#f8d870"],
)
HAIR = {"colour": HAIRC, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.56), (0, 0, 4.14, 0.72, 0.74), (0, 0, 4.42, 0.84, 0.8), (0, 0, 5.3, 0.84, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]
_S = dict(flat=0.66, p=1.7, q=0.85)
FLAME = [
	# the tall core, straight up
	H((0.0, 0.12, 5.7), (-0.05, 0.14, 6.9), (0.02, 0.2, 7.08), 0.8, **_S),
	# flanking masses: a flame narrowing to the top
	H((-0.42, 0.05, 5.7), (-0.62, 0.05, 6.6), (-0.46, 0.14, 6.96), 0.56, **_S),
	H((0.42, 0.05, 5.7), (0.62, 0.05, 6.6), (0.5, 0.14, 6.9), 0.56, **_S),
	H((-0.66, -0.05, 5.5), (-1.02, -0.05, 6.15), (-0.98, 0.05, 6.8), 0.46, **_S),
	H((0.66, -0.05, 5.5), (1.02, -0.05, 6.15), (1.02, 0.05, 6.74), 0.46, **_S),
	H((-0.8, 0.08, 5.2), (-1.18, 0.08, 5.6), (-1.28, 0.14, 6.26), 0.36, **_S),
	H((0.8, 0.08, 5.2), (1.18, 0.08, 5.6), (1.3, 0.14, 6.22), 0.36, **_S),
	# the front face of the flame, rising straight off the hairline
	H((-0.3, -0.5, 5.82), (-0.34, -0.55, 6.3), (-0.22, -0.36, 6.94), 0.4, **_S),
	H((0.3, -0.5, 5.82), (0.34, -0.55, 6.3), (0.24, -0.36, 6.9), 0.4, **_S),
	H((-0.68, -0.44, 5.88), (-0.76, -0.5, 6.15), (-0.7, -0.34, 6.56), 0.3, **_S),
	H((0.68, -0.44, 5.88), (0.76, -0.5, 6.15), (0.72, -0.34, 6.5), 0.3, **_S),
	# the back
	H((0.0, 0.55, 5.45), (0.0, 0.85, 6.3), (0.04, 0.72, 6.86), 0.5, **_S),
	H((-0.45, 0.5, 5.2), (-0.62, 0.82, 5.85), (-0.62, 0.72, 6.56), 0.4, **_S),
	H((0.45, 0.5, 5.2), (0.62, 0.82, 5.82), (0.64, 0.72, 6.5), 0.4, **_S),
]
_F = dict(flat=0.6, p=1.3, q=0.75)
PEAK = [
	# the point of the widow's peak: a plate on the brow, the temples left bare beside it
	H((0.0, -0.62, 5.76), (0.0, -0.9, 5.56), (0.0, -0.86, 5.0), 0.34, **_F),
	# short sideburns
	H((-0.88, -0.3, 5.4), (-0.92, -0.36, 5.12), (-0.9, -0.42, 4.84), 0.15, **_F),
	H((0.88, -0.3, 5.4), (0.92, -0.36, 5.12), (0.9, -0.42, 4.84), 0.15, **_F),
]


def _armour(k):
	# the chest plate, a hard block with a raised centre
	shell(k, "Chest", [(4.05, 0.84, 0.46, (0,) * 5), (3.88, 1.06, 0.58, (0,) * 5), (3.5, 1.08, 0.6, (0.03, -0.05, -0.02, -0.05, 0.03)), (3.1, 1.04, 0.58, (0.05, -0.02, 0.03, -0.02, 0.05)), (2.98, 1.02, 0.56, (0.03,) * 5)], "white", base=0.3, amp=0.5)
	# the gold belly ribs below it
	for i, (z1, z0) in enumerate(((3.0, 2.86), (2.88, 2.74))):
		block(k, "UpperTorso", f"Rib{i}", -1.0, 1.0, -0.56, 0.56, z0, z1, "gold", c=0.03, base=0.42, amp=0.34)
	# the blue suit at the hips, under the flaps
	block(k, "UpperTorso", "Hips", -1.02, 1.02, -0.54, 0.54, 2.02, 2.76, "blue", c=0.04, base=0.34, amp=0.36)
	block(k, "UpperTorso", "Waist", -1.05, 1.05, -0.58, 0.58, 2.62, 2.76, "white", c=0.03, base=0.44, amp=0.32)
	# hip flaps, flat gold plates off the waist: two in front, one on each side, two behind
	for name, x0, x1, yy, zbot, thick in (("FL", -1.02, -0.26, -0.62, 2.04, 0.1), ("FR", 0.26, 1.02, -0.62, 2.04, 0.1), ("BL", -1.02, -0.26, 0.54, 2.08, 0.1), ("BR", 0.26, 1.02, 0.54, 2.08, 0.1)):
		slab(k, "UpperTorso", "Flap" + name, [(x0, x1, yy, 2.68), (x0 + 0.04, x1 - 0.04, yy - 0.05 * (1 if yy < 0 else -1), 2.3), (x0 + 0.14, x1 - 0.14, yy - 0.07 * (1 if yy < 0 else -1), zbot)], "gold", thick=thick, base=0.42, amp=0.36)
	for s, tag in ((1, "L"), (-1, "R")):
		rows = [(2.68, 1.04, 1.16, -0.4, 0.4), (2.3, 1.06, 1.2, -0.36, 0.36), (2.04, 1.06, 1.18, -0.26, 0.26)]
		box(k, "UpperTorso", "FlapS" + tag, [(z, min(s * a, s * b), max(s * a, s * b), y0, y1) for z, a, b, y0, y1 in rows], "gold", c=0.03, base=0.42, amp=0.36)


def _arm(k, part, s):
	ax = s * 1.5
	arm_bands(k, part, ax, (("Sleeve", 3.92, 3.4, 0.525, "blue"), ("Arm", 3.42, 2.72, 0.515, "skin")))
	# the glove: long cuff, plain block hand
	block(k, part, "Cuff", ax - 0.56, ax + 0.56, -0.56, 0.56, 2.42, 2.76, "white", c=0.05, base=0.44, amp=0.36, grad=0.12)
	block(k, part, "Hand", ax - 0.515, ax + 0.515, -0.515, 0.515, 1.8, 2.44, "white", c=0.06, base=0.42, amp=0.34, grad=0.08)
	# the gold shoulder flap: a wide plate that juts past the arm, and a yoke strap toward the neck
	x0, x1 = s * 0.92, s * 2.14
	a, b = min(x0, x1), max(x0, x1)
	box(k, part, "Flap", [(3.84, a, b, -0.66, 0.66), (3.96, a, b, -0.68, 0.68), (4.14, a + 0.02, b - 0.02, -0.56, 0.6), (4.2, a + 0.1, b - 0.14, -0.44, 0.48)], "gold", c=0.07, base=0.44, amp=0.38)


def _leg(k, part, block_name, s):
	x0, x1 = min(s * 0.03, s * 1.03), max(s * 0.03, s * 1.03)
	k.reshape(part, block_name, [(s * 0.53, 0, 2.0, 0.44, 0.44), (s * 0.53, 0, 0.0, 0.44, 0.44)], corner=0.12, nc=1)
	box(k, part, "Thigh", [(2.0, x0, x1, -0.54, 0.54), (1.5, x0, x1, -0.54, 0.54), (1.0, x0 + 0.02, x1 - 0.02, -0.52, 0.52)], "blue", c=0.07, base=0.38, amp=0.42, grad=0.14)
	rows = [(0.08, -0.9, 0.56), (0.26, -0.9, 0.56), (0.42, -0.68, 0.54), (0.58, -0.54, 0.54), (1.02, -0.54, 0.54), (1.12, -0.56, 0.56)]
	box(k, part, "Boot", [(z, x0 - 0.01, x1 + 0.01, y0, y1) for z, y0, y1 in rows], "white", c=0.08, base=0.42, amp=0.36, grad=0.12)
	# the gold cap over the toe
	rows = [(0.1, -0.94, -0.4), (0.27, -0.94, -0.4), (0.44, -0.72, -0.4), (0.5, -0.58, -0.4)]
	box(k, part, "Toe", [(z, x0 - 0.03, x1 + 0.03, y0, y1) for z, y0, y1 in rows], "gold", c=0.06, base=0.44, amp=0.36)
	block(k, part, "Sole", x0 - 0.02, x1 + 0.02, -0.92, 0.58, 0.0, 0.09, "white", c=0.02, base=0.12, amp=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	style = hair_style()
	hair_cap(k, ((5.54, 4.42, 0.89, 0.88), (5.76, 5.0, 0.93, 0.92), (6.05, 5.85, 0.76, 0.74), (6.22, 6.18, 0.38, 0.36)), style)
	spikes(k, FLAME + PEAK, style)
	_armour(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, f"{side}UpperArm", s)
		_leg(k, f"{side}UpperLeg", f"{side}Leg", s)
	finish()


def _eye(f, cx, cy, sgn):
	"""Narrow and sharp, a small black iris close under the sloped lid."""
	i, o = cx - sgn * 17, cx + sgn * 17
	shape = f"M{i} {cy + 3}L{o} {cy - 11}L{o + sgn * 1} {cy + 2}Q{cx + sgn * 6} {cy + 11} {i + sgn * 7} {cy + 9}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 3, cy - 0.5, 6.6, 9), "#060608")
	f.path(circle(cx - sgn * 1.5, cy - 3.5, 1.8, 2.2), "#ffffff")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 6}L{o + sgn * 4} {cy - 14}L{o + sgn * 1.5} {cy - 4}L{i - sgn * 2} {cy + 8}Z", "#060608")
	f.path(f"M{i + sgn * 8} {cy + 11}Q{cx + sgn * 6} {cy + 13} {o} {cy + 4}", stroke=SKIN_D, sw=1.1)


def _face(f):
	face(f, SKIN, hairline=14, nose_y=88)
	f.soft("M30 40H100V100Q65 118 30 100Z", "#ffe8d2", 0.45, 8)
	f.soft("M-5 30H10Q8 90 22 135H-5Z", SKIN_D, 0.55, 5)
	f.soft("M135 30H120Q122 90 108 135H135Z", SKIN_D, 0.65, 5)
	for cx, sgn in ((37, -1), (93, 1)):
		_eye(f, cx, 69, sgn)
		# a heavy brow plunging to the nose, a crease between
		i, o = cx - sgn * 22, cx + sgn * 22
		f.path(f"M{i} {56}L{o} {30}L{o - sgn * 2} {41}L{i + sgn * 4} {64}Z", "#060608")
		f.path(f"M{65 + sgn * 3} 50L{65 + sgn * 2} 62", stroke=SKIN_D, sw=1.5)
	# the set scowl: flat, with one corner pulled up
	f.path("M50 107L76 107Q82 106 86 100", stroke=LINE, sw=2.4)
	f.soft("M58 112Q66 115 74 112V114Q66 118 58 115Z", SKIN_D, 0.5, 2)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	a["Head_T"].fill(HAIRC)
	a["Head_B"].fill(HAIRC)
	a["Head_Bo"].fill(SKIN_D)
	for n, d in (("Head_L", "M62 -5H125V135H74L62 60Z"), ("Head_R", "M58 -5H-5V135H46L58 60Z")):
		a[n].fill(SKIN)
		a[n].path(d, HAIRC)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(WHITE)
	a["Torso_Bo"].fill(BLUE_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill(BLUE)
		a[f"{side}Arm_T"].fill(BLUE)
		a[f"{side}Arm_Bo"].fill(WHITE)
		a[f"{side}Leg_T"].fill(BLUE)
		a[f"{side}Leg_Bo"].fill(WHITE)
