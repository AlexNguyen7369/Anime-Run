# Target look for db_green: tall green figure, white turban, wide shoulder slabs and long cape, purple gi, blue sash,
# red wristbands, brown shoes, pink arm patches, pointed ears. +X is the viewer's right in the front view.
from math import cos, pi, sin

from db_common import circle
from db_style3 import arm_bands, bag, block, box, dome, sash, shell, solid, thin_leg, wedge
from leaf_common import begin_clip, end_clip
from style2 import Kit, Ramps, face
from style3 import big_head, finish

SKIN = "#6dbe45"
SKIN_D = "#478a2a"
SKIN_DD = "#2f6420"
GI = "#4b2e83"
GI_D = "#2e1b58"
WHITE = "#f2f2f2"
LINE = "#16300e"
DEFAULT = GI
R = Ramps(
	skin=["#2f6c22", "#4d9a30", SKIN, "#92d868"],
	pink=["#a84e58", "#cf6f74", "#e88a8a", "#f6b0ac"],
	gi=["#1e1040", "#2e1b58", GI, "#6a44ad", "#8a64cc"],
	white=["#8f8fa8", "#c2c2d2", WHITE, "#ffffff"],
	blue=["#1c4478", "#2a609c", "#3a7bc8", "#68a4e6"],
	red=["#7a1420", "#a4222a", "#c8333a", "#e8606a"],
	brown=["#3c2612", "#553a1c", "#6b4a2a", "#8e6a42"],
	band=["#2e1b58", "#4b2e83", "#6a44ad", "#8a64cc"],
)
HAIR = {"colour": WHITE, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.56), (0, 0, 4.14, 0.7, 0.72), (0, 0, 4.44, 0.82, 0.8), (0, 0, 5.3, 0.84, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]
_TORSO = [
	(4.05, 0.84, 0.44, (0, 0, 0, 0, 0)),
	(3.9, 1.04, 0.55, (0, 0, 0, 0, 0)),
	(3.45, 1.05, 0.56, (0.03, -0.06, 0, -0.06, 0.03)),
	(3.1, 1.02, 0.55, (0.08, -0.08, 0.04, -0.08, 0.08)),
	(2.84, 1.0, 0.54, (-0.03, 0.06, -0.04, 0.06, -0.03)),
]
_HIP = [(2.72, 1.0, 0.54, (0, 0, 0, 0, 0)), (2.4, 1.05, 0.6, (0.03, -0.05, 0.03, -0.05, 0.03)), (2.02, 1.05, 0.6, (-0.04, 0.03, 0.06, 0.03, -0.04))]


def _turban(k):
	"""A round cloth dome over the skull, its lower edge just above the brow, with the band high up."""
	rows = [(5.18, 4.14, 0.88, 0.85), (5.3, 4.46, 0.97, 0.94), (5.62, 5.1, 1.06, 1.02), (5.98, 5.78, 1.04, 1.0), (6.28, 6.2, 0.86, 0.84), (6.46, 6.42, 0.52, 0.52)]
	rings = []
	for zf, zb, sw, sd in rows:
		ring = []
		for i in range(14):
			a = 2 * pi * i / 14 + 0.11
			c, s = cos(a), sin(a)
			px, py = abs(c) ** 0.72 * (1 if c > 0 else -1), abs(s) ** 0.72 * (1 if s > 0 else -1)
			t = max(0.0, min(1.0, (py - 0.1) / 0.8))  # the rim stays up over the ears and drops only behind them
			ring.append((sw * px, sd * py, zf + (zb - zf) * t))
		rings.append(ring)
	solid(k, "Head", "Turban", rings, "white", base=0.44, amp=0.36, grad=0.1)
	# the band near the top
	rings = []
	for z, sw in ((5.88, 1.055), (5.93, 1.07), (6.05, 1.045), (6.1, 1.02)):
		rings.append([(sw * (abs(cos(2 * pi * i / 14 + 0.11)) ** 0.72) * (1 if cos(2 * pi * i / 14 + 0.11) > 0 else -1), (sw * 0.97) * (abs(sin(2 * pi * i / 14 + 0.11)) ** 0.72) * (1 if sin(2 * pi * i / 14 + 0.11) > 0 else -1), z) for i in range(14)])
	solid(k, "Head", "TurbanBand", rings, "band", base=0.42, amp=0.34, grad=0.0)


def _ears(k):
	for s, tag in ((1, "L"), (-1, "R")):
		rows = []
		for t, h, d in ((0, 0.34, 0.26), (0.4, 0.3, 0.2), (0.8, 0.12, 0.1), (1, 0.02, 0.02)):
			x, z = s * (0.78 + 0.5 * t), 4.56 + 0.52 * t
			rows.append((x, z, h, d))
		rings = [[(x, -d, z - h * 0.6), (x, -d, z + h), (x, d, z + h), (x, d, z - h * 0.6)] for x, z, h, d in rows]
		solid(k, "Head", "Ear" + tag, rings, "skin", base=0.48, amp=0.36, grad=0.1)


def _cape(k):
	"""A thick white cape off the shoulders to just above the ground, pleated, close to the body."""
	rows = [(4.14, 1.02, 0.56), (3.5, 1.5, 0.6), (2.2, 1.78, 0.66), (0.9, 1.94, 0.74), (0.34, 1.98, 0.78)]
	rings = []
	for ri, (z, hw, y) in enumerate(rows):
		amp = 0.14 * ri / 4
		front = []
		for i in range(9):
			x = -hw + 2 * hw * i / 8
			front.append((x, y + (amp if i % 2 else 0.0) - 0.1 * (abs(x) / hw) ** 2, z))
		back = [(x, yy + 0.16, zz) for x, yy, zz in reversed(front)]
		rings.append(front + back)
	solid(k, "UpperTorso", "Cape", rings, "white", base=0.42, amp=0.48, grad=0.1, light=(-0.5, 0.42, 0.74))


def _pads(k):
	"""The shoulder slabs: a yoke across the torso, a big flat slab riding on each arm."""
	box(k, "UpperTorso", "Yoke", [(3.92, -1.04, 1.04, -0.62, 0.68), (4.04, -1.06, 1.06, -0.66, 0.72), (4.16, -1.02, 1.02, -0.6, 0.68), (4.2, -0.9, 0.9, -0.5, 0.6)], "white", c=0.06, base=0.44, amp=0.36)
	for s, part in ((1, "LeftUpperArm"), (-1, "RightUpperArm")):
		x0, x1 = s * 0.98, s * 2.28
		a, b = min(x0, x1), max(x0, x1)
		box(k, part, "Pad", [(3.82, a + 0.04, b - 0.04, -0.72, 0.72), (3.92, a, b, -0.78, 0.78), (4.1, a, b, -0.76, 0.76), (4.26, a + 0.08, b - 0.1, -0.62, 0.64)], "white", c=0.08, base=0.44, amp=0.38)


def _shoe(k, part, s, top):
	cx = s * 0.6
	rows = [(0.08, -0.92, 0.5), (0.22, -0.92, 0.5), (0.36, -0.68, 0.48), (0.48, -0.46, 0.46), (top, -0.42, 0.42)]
	box(k, part, "Shoe", [(z, cx - 0.44, cx + 0.44, y0, y1) for z, y0, y1 in rows], "brown", c=0.09, base=0.42, amp=0.34, grad=0.1)
	block(k, part, "ShoeSole", cx - 0.46, cx + 0.46, -0.95, 0.53, 0.0, 0.09, "brown", c=0.03, base=0.16, amp=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	_turban(k)
	_ears(k)
	shell(k, "Gi", _TORSO, "gi")
	shell(k, "Hip", _HIP, "gi", vfn=lambda co: -0.3 * max(0.0, (co.z - 2.36) / 0.3))
	wedge(k, "skin", top=4.03, tip=3.46, half=0.42, base=0.4, amp=0.24)
	_cape(k)
	_pads(k)
	sash(k, "blue", 0.28, ((0.2, 0.14, 0.13, 0.19, 1.12, -0.74), (0.5, 0.6, 0.13, 0.2, 1.3, -0.78)))
	for s, side in ((1, "Left"), (-1, "Right")):
		ax = s * 1.5
		arm_bands(k, f"{side}UpperArm", ax, (("Upper", 3.86, 3.34, 0.52, "skin"), ("Patch", 3.34, 3.02, 0.535, "pink"), ("Fore", 3.02, 2.6, 0.52, "skin"), ("Wrist", 2.62, 2.28, 0.56, "red"), ("Hand", 2.3, 1.8, 0.515, "skin")))
		part = f"{side}UpperLeg"
		thin_leg(k, part, f"{side}Leg", s)
		bag(k, part, s, "gi", z0=0.56, w=0.7, d=0.95)
		_shoe(k, part, s, 0.62)
	finish()


def _eye(f, cx, cy, sgn):
	"""Narrow and hard: a thin white wedge, a small black pupil, the heavy lid sloping down to the nose."""
	i, o = cx - sgn * 17, cx + sgn * 16
	shape = f"M{i} {cy + 4}L{o} {cy - 9}L{o} {cy + 2}Q{cx + sgn * 6} {cy + 9} {i + sgn * 7} {cy + 8}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 1.5, cy + 0.5, 5.2, 7), "#08080c")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 6}L{o + sgn * 3} {cy - 12}L{o + sgn * 1} {cy - 5}L{i - sgn * 2} {cy + 8}Z", "#08080c")
	f.path(f"M{i + sgn * 8} {cy + 9.5}Q{cx + sgn * 6} {cy + 11} {o} {cy + 4}", stroke=SKIN_DD, sw=1.1)


def _face(f):
	face(f, SKIN, hairline=22, nose_y=88, shadow=SKIN_DD)
	f.soft("M30 40H100V100Q65 118 30 100Z", "#8fd968", 0.45, 8)
	f.soft("M-5 30H10Q8 90 22 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H120Q122 90 108 135H135Z", SKIN_D, 0.7, 5)
	for cx, sgn in ((37, -1), (93, 1)):
		# the brow ridge: a thick skin-coloured shelf under a dark edge
		i, o = cx - sgn * 22, cx + sgn * 24
		f.path(f"M{i} {52}L{o} {33}L{o - sgn * 2} {44}L{i + sgn * 3} {60}Z", SKIN_D)
		f.path(f"M{i} {52}L{o} {33}L{o - sgn * 1} {37}L{i + sgn * 1} {56}Z", SKIN_DD)
		_eye(f, cx, 67, sgn)
		# the two hard creases from nose to jaw
		f.path(f"M{cx + (-sgn) * 6} 82L{cx + sgn * 2} 108", stroke=SKIN_DD, sw=1.8)
	f.path("M49 110L84 110", stroke=LINE, sw=2.4)
	f.path("M49 110L45 106M84 110L88 106", stroke=LINE, sw=2.0)
	f.path("M74 110L77 116L80 110Z", "#ffffff")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	a["Head_T"].fill(WHITE)
	a["Head_B"].fill(SKIN_D)
	a["Head_Bo"].fill(SKIN_D)
	for n in ("Head_L", "Head_R"):
		a[n].fill(SKIN_D)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(GI)
	a["Torso_Bo"].fill(GI_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill(GI_D)
		a[f"{side}Arm_T"].fill(WHITE)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(GI)
		a[f"{side}Leg_Bo"].fill("#3c2612")
