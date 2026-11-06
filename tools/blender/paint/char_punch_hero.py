# Target look for punch_hero "Saitamo": bald round head, blank deadpan face, plain yellow zipped suit, black belt, red gloves
# and boots, white cape held by two round clasps. Blocky R15 body (design doc 5). +X is the viewer's right in the front view.
from db_common import circle
from db_style3 import arm_bands, block, box, dome, shell, solid, thin_leg
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f2c9a0"
SKIN_D = "#d4a47c"
SKIN_DD = "#a97b58"
SUIT = "#f5c518"
SUIT_D = "#c79608"
WHITE = "#f4f4f2"
RED = "#d3222a"
LINE = "#2a1c14"
DEFAULT = SUIT
R = Ramps(
	skin=["#a97b58", "#d4a47c", SKIN, "#ffe2c4"],
	suit=["#8f6a04", "#c79608", SUIT, "#ffe05a"],
	zip=["#6e5204", "#8f6a04", "#b08408", "#c79608"],
	white=["#8f90a4", "#c4c6d2", WHITE, "#ffffff"],
	red=["#7c0f16", "#a81820", RED, "#f0525a"],
	black=["#08080c", "#14141a", "#22222a", "#3a3a44"],
)
HAIR = {"colour": SKIN, "locks": []}
PROPS = []
# no hair: the skull itself is the silhouette, so it closes round at the top
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.56), (0, 0, 4.14, 0.72, 0.72), (0, 0, 4.44, 0.84, 0.8), (0, 0, 5.2, 0.88, 0.84), (0, 0, 5.56, 0.8, 0.76), (0, 0, 5.8, 0.6, 0.57), (0, 0, 5.92, 0.3, 0.28)]
_TORSO = [
	(4.05, 0.84, 0.44, (0, 0, 0, 0, 0)),
	(3.9, 1.04, 0.55, (0, 0, 0, 0, 0)),
	(3.45, 1.05, 0.56, (0.02, -0.03, 0, -0.03, 0.02)),
	(3.1, 1.02, 0.55, (0.03, -0.03, 0.02, -0.03, 0.03)),
	(2.84, 1.0, 0.54, (0, 0, 0, 0, 0)),
]
_HIP = [(2.72, 1.0, 0.54, (0, 0, 0, 0, 0)), (2.4, 1.05, 0.6, (0.02, -0.03, 0.02, -0.03, 0.02)), (2.02, 1.05, 0.6, (0, 0, 0.03, 0, 0))]


def _ears(k):
	for s, tag in ((1, "L"), (-1, "R")):
		block(k, "Head", "Ear" + tag, min(s * 0.84, s * 1.0), max(s * 0.84, s * 1.0), -0.14, 0.14, 4.5, 4.92, "skin", c=0.04, base=0.5, amp=0.34)


def _cape(k):
	"""Off the shoulders to the calves, a few big folds, close to the body."""
	rows = [(4.14, 1.02, 0.56), (3.5, 1.4, 0.6), (2.4, 1.62, 0.66), (1.4, 1.74, 0.72), (0.86, 1.78, 0.76)]
	rings = []
	for ri, (z, hw, y) in enumerate(rows):
		amp = 0.12 * ri / 4
		front = []
		for i in range(9):
			x = -hw + 2 * hw * i / 8
			front.append((x, y + (amp if i % 2 else 0.0) - 0.1 * (abs(x) / hw) ** 2, z))
		back = [(x, yy + 0.14, zz) for x, yy, zz in reversed(front)]
		rings.append(front + back)
	solid(k, "UpperTorso", "Cape", rings, "white", base=0.42, amp=0.48, grad=0.1, light=(-0.5, 0.42, 0.74))


def _yoke(k):
	"""The cape's band across the shoulders and chest, with its two round clasps."""
	box(k, "UpperTorso", "CapeBand", [(3.76, -0.98, 0.98, -0.6, 0.62), (3.92, -1.06, 1.06, -0.62, 0.64), (4.08, -0.98, 0.98, -0.56, 0.62), (4.16, -0.72, 0.72, -0.44, 0.54)], "white", c=0.05, base=0.44, amp=0.36)
	block(k, "UpperTorso", "CapeGap", -0.2, 0.2, -0.66, -0.56, 3.76, 4.17, "suit", c=0.02, base=0.5, amp=0.3)
	for s, tag in ((1, "L"), (-1, "R")):
		dome(k, "UpperTorso", "Clasp" + tag, (s * 0.46, -0.62, 3.9), (0.15, 0.15, 0.08), "white", up="-y", n=10, rows=2, base=0.56, amp=0.34)


def _boot(k, part, s):
	cx = s * 0.6
	rows = [(0.08, -0.82, 0.5), (0.22, -0.82, 0.5), (0.4, -0.6, 0.48), (0.56, -0.46, 0.46), (1.14, -0.46, 0.46), (1.22, -0.5, 0.5)]
	box(k, part, "Boot", [(z, cx - 0.46, cx + 0.46, y0, y1) for z, y0, y1 in rows], "red", c=0.07, base=0.44, amp=0.36, grad=0.1)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	_ears(k)
	shell(k, "Suit", _TORSO, "suit")
	shell(k, "Hip", _HIP, "suit")
	t = "UpperTorso"
	block(k, t, "Zip", -0.035, 0.035, -0.6, -0.5, 2.84, 3.8, "zip", c=0.01, base=0.5, amp=0.2)
	block(k, t, "ZipPull", -0.06, 0.06, -0.63, -0.56, 3.5, 3.62, "black", c=0.015, base=0.5, amp=0.3)
	block(k, t, "Belt", -1.06, 1.06, -0.6, 0.6, 2.58, 2.84, "black", c=0.03, base=0.44, amp=0.36)
	block(k, t, "Buckle", -0.17, 0.17, -0.64, -0.56, 2.6, 2.82, "zip", c=0.02, base=0.56, amp=0.36)
	_cape(k)
	_yoke(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		ax = s * 1.5
		arm_bands(k, f"{side}UpperArm", ax, (("Upper", 3.86, 3.2, 0.53, "suit"), ("Fore", 3.22, 2.68, 0.52, "suit"), ("Cuff", 2.7, 2.36, 0.56, "red"), ("Hand", 2.38, 1.8, 0.53, "red")))
		part = f"{side}UpperLeg"
		thin_leg(k, part, f"{side}Leg", s)
		cx = s * 0.6
		box(k, part, "Trouser", [(z, cx - hw, cx + hw, -hw, hw) for z, hw in ((1.1, 0.42), (1.6, 0.46), (2.06, 0.48))], "suit", c=0.05, base=0.44, amp=0.36, grad=0.1)
		_boot(k, part, s)
	finish()


def _eye(f, cx, cy):
	"""The blank stare: a wide plain oval with a tiny pupil, and one thin line for the upper lid. No brows."""
	f.path(circle(cx, cy, 13, 9), "#ffffff")
	f.path(circle(cx, cy + 0.5, 2.6, 2.6), "#08080c")
	f.path(f"M{cx - 14} {cy - 4}Q{cx} {cy - 12} {cx + 14} {cy - 4}", stroke=LINE, sw=2.2)
	f.path(f"M{cx - 11} {cy + 8}Q{cx} {cy + 11} {cx + 11} {cy + 8}", stroke=SKIN_DD, sw=1.0)


def _face(f):
	f.fill(SKIN)
	f.soft("M-5 30H9Q5 90 26 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 104 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	f.soft("M34 8Q65 -2 96 8Q90 22 65 24Q40 22 34 8Z", "#ffe2c4", 0.55, 5)
	_eye(f, 40, 68)
	_eye(f, 90, 68)
	f.path("M63 84L66 90L69 89", stroke=SKIN_DD, sw=1.3)
	f.path("M55 106L75 106", stroke=LINE, sw=2.0)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	for n in ("Head_T", "Head_B", "Head_L", "Head_R"):
		a[n].fill(SKIN)
	a["Head_Bo"].fill(SKIN_D)
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(SUIT)
	a["Torso_Bo"].fill(SUIT_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SUIT)
			a[f"{side}Leg_{key}"].fill(SUIT_D)
		a[f"{side}Arm_T"].fill(SUIT)
		a[f"{side}Arm_Bo"].fill(RED)
		a[f"{side}Leg_T"].fill(SUIT)
		a[f"{side}Leg_Bo"].fill(RED)
