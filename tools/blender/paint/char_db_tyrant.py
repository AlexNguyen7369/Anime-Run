# Target look for db_tyrant, last form: smooth white body, glossy purple domes on crown, shoulders, chest, forearms and shins,
# a long tail held close and curling round to the front, red eyes, dark purple lips, marks round the eyes.
# +X is the viewer's right in the front view.
from db_common import circle
from db_style3 import block, box, dome, pipe, shell
from leaf_common import begin_clip, end_clip
from style2 import Kit, Ramps, face
from style3 import big_head, finish

WHITE = "#f4f2f8"
SHADOW = "#c8c0dc"
SHADOW_D = "#958ab4"
PURPLE = "#8e3fc2"
PURPLE_D = "#40186e"
LIP = "#5b2b7a"
MARK = "#7a3fa0"
RED = "#c0142b"
DEFAULT = WHITE
R = Ramps(
	white=["#958ab4", "#c8c0dc", WHITE, "#ffffff"],
	# the gloss: a dark foot, a saturated body and one bright plane on top
	purple=["#3a1566", "#5c2490", PURPLE, "#b070ea", "#e8c8ff"],
)
HAIR = {"colour": WHITE, "locks": []}
PROPS = []
# a rounder, narrower skull than the rest of the cast, tapering to a small chin
HEAD_ROWS = [(0, 0, 3.98, 0.42, 0.5), (0, 0, 4.14, 0.62, 0.66), (0, 0, 4.42, 0.78, 0.76), (0, 0, 5.3, 0.82, 0.78), (0, 0, 5.56, 0.72, 0.68), (0, 0, 5.72, 0.5, 0.48)]
GLOSS = dict(base=0.46, amp=0.5, grad=0.08)


def _body(k):
	shell(k, "Torso", [(4.05, 0.82, 0.44, (0,) * 5), (3.88, 1.03, 0.54, (0,) * 5), (3.4, 1.04, 0.55, (0.02, -0.04, 0, -0.04, 0.02)), (2.9, 1.0, 0.54, (0.04, 0, 0.03, 0, 0.04)), (2.5, 1.02, 0.54, (0,) * 5), (2.02, 1.04, 0.56, (0,) * 5)], "white", base=0.3, amp=0.5)
	dome(k, "UpperTorso", "ChestDome", (0, -0.5, 3.36), (0.74, 0.5, 0.26), "purple", up="-y", n=12, **GLOSS)
	# the tail: from the small of the back, down behind the legs, round the viewer's right, tip turned up at the foot
	pts = [(0.0, 0.42, 2.5, 0.3), (0.0, 0.72, 2.28, 0.31), (0.06, 0.92, 1.74, 0.3), (0.14, 1.0, 1.16, 0.28), (0.34, 1.0, 0.62, 0.25), (0.84, 0.94, 0.32, 0.21), (1.34, 0.56, 0.24, 0.17), (1.58, 0.06, 0.28, 0.13), (1.62, -0.34, 0.54, 0.09), (1.62, -0.46, 1.06, 0.015)]
	pipe(k, "UpperTorso", "Tail", pts, "white", base=0.44, amp=0.42, grad=0.04)


def _arm(k, part, s):
	ax = s * 1.5
	block(k, part, "Arm", ax - 0.525, ax + 0.525, -0.525, 0.525, 3.08, 3.96, "white", c=0.03, base=0.34, amp=0.48)
	# the shoulder cap covers the block's whole top, its planes stepping in to a dome
	rows = [(3.66, 0.5), (3.72, 0.56), (3.94, 0.59), (4.1, 0.52), (4.22, 0.36), (4.27, 0.18)]
	box(k, part, "ShoulderDome", [(z, ax - w, ax + w, -w, w) for z, w in rows], "purple", c=0.14, **GLOSS)
	# the forearm: a fat glossy plate bulging out of the arm all round
	rows = [(3.1, 0.5), (2.98, 0.57), (2.7, 0.6), (2.46, 0.56), (2.36, 0.5)]
	box(k, part, "Forearm", [(z, ax - w, ax + w, -w, w) for z, w in rows], "purple", c=0.12, **GLOSS)
	block(k, part, "Hand", ax - 0.52, ax + 0.52, -0.52, 0.52, 1.8, 2.38, "white", c=0.03, base=0.42, amp=0.4, grad=0.08)


def _leg(k, part, block_name, s):
	x0, x1 = min(s * 0.03, s * 1.03), max(s * 0.03, s * 1.03)
	k.reshape(part, block_name, [(s * 0.53, 0, 2.0, 0.46, 0.46), (s * 0.53, 0, 0.0, 0.46, 0.46)], corner=0.12, nc=1)
	box(k, part, "Thigh", [(2.0, x0, x1, -0.53, 0.53), (1.3, x0, x1, -0.53, 0.53), (0.32, x0 + 0.02, x1 - 0.02, -0.52, 0.52)], "white", c=0.08, base=0.34, amp=0.48, grad=0.08)
	cx = (x0 + x1) / 2
	dome(k, part, "ShinDome", (cx, -0.48, 0.98), (0.42, 0.56, 0.2), "purple", up="-y", n=10, **GLOSS)
	# the foot, long and bare
	rows = [(0.0, -0.92, 0.56), (0.1, -0.96, 0.58), (0.26, -0.92, 0.58), (0.44, -0.66, 0.56), (0.56, -0.54, 0.54)]
	box(k, part, "Foot", [(z, x0 - 0.01, x1 + 0.01, y0, y1) for z, y0, y1 in rows], "white", c=0.08, base=0.42, amp=0.4, grad=0.08)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	# the crown dome sits flush on the skull, leaving a white forehead
	rows = [(5.38, 0.8, 0.76), (5.42, 0.815, 0.775), (5.56, 0.75, 0.71), (5.72, 0.6, 0.56), (5.86, 0.36, 0.34), (5.92, 0.18, 0.18)]
	box(k, "Head", "CrownDome", [(z, -w, w, -d, d) for z, w, d in rows], "purple", c=0.16, **GLOSS)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, f"{side}UpperArm", s)
		_leg(k, f"{side}UpperLeg", f"{side}Leg", s)
	finish()


def _eye(f, cx, cy, sgn):
	"""Long and cat-like: red iris on white under a black lid, a thin dark rim."""
	i, o = cx - sgn * 20, cx + sgn * 19
	shape = f"M{i} {cy + 7}L{o} {cy - 15}L{o + sgn * 1} {cy + 3}Q{cx + sgn * 6} {cy + 14} {i + sgn * 7} {cy + 12}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 1.5, cy, 9.4, 11), RED)
	f.path(circle(cx - sgn * 1.5, cy, 4.6, 5.8), "#14060c")
	f.path(circle(cx, cy - 4.5, 1.6, 2), "#ffffff")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 7}L{o + sgn * 3} {cy - 15}L{o + sgn * 1.5} {cy - 7}L{i - sgn * 2} {cy + 9}Z", "#14101c")
	f.path(f"M{i + sgn * 7} {cy + 12}Q{cx + sgn * 6} {cy + 14} {o + sgn} {cy + 3}", stroke="#14101c", sw=1.3)


def _face(f):
	face(f, WHITE, hairline=-40, nose_y=90, shadow=SHADOW)
	f.soft("M-5 30H10Q8 90 22 135H-5Z", SHADOW, 0.7, 5)
	f.soft("M135 30H120Q122 90 108 135H135Z", SHADOW, 0.85, 5)
	for cx, sgn in ((37, -1), (93, 1)):
		# the purple streak under the eye, running out and up towards the temple
		i, o = cx - sgn * 10, cx + sgn * 27
		f.path(f"M{i} {90}L{o} {66}L{o} {71}L{i + sgn * 7} {92}Z", MARK)
		_eye(f, cx, 68, sgn)
		# a thin mark above the eye, in place of a brow
		f.path(f"M{cx - sgn * 17} {49}L{cx + sgn * 20} {32}L{cx + sgn * 19} {36}L{cx - sgn * 15} {52}Z", MARK)
	# small dark lips, a thin smirk
	f.path("M52 108Q66 103 80 105Q86 104 88 100Q84 112 66 113Q56 113 52 108Z", LIP)
	f.path("M52 108Q66 108 82 106Q86 105 88 100", stroke="#2a1040", sw=1.3)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	a["Head_T"].fill(PURPLE)
	a["Head_B"].fill(WHITE)
	a["Head_Bo"].fill(SHADOW)
	for n, cx in (("Head_L", 52), ("Head_R", 68)):
		f = a[n]
		f.fill(WHITE)
		# the ear: a bare hole on a smooth head
		f.path(circle(cx, 72, 8, 11), SHADOW_D)
		f.path(circle(cx, 72, 4, 7), "#3a3250")
	for n in ("Torso_F", "Torso_B", "Torso_L", "Torso_R", "Torso_T"):
		a[n].fill(WHITE)
	a["Torso_Bo"].fill(SHADOW)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(WHITE)
			a[f"{side}Leg_{key}"].fill(WHITE)
		a[f"{side}Arm_T"].fill(PURPLE)
		a[f"{side}Arm_Bo"].fill(SHADOW)
		a[f"{side}Leg_T"].fill(WHITE)
		a[f"{side}Leg_Bo"].fill(SHADOW)
