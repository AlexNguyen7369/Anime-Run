# Target look for db_scholar: short upright spiked hair with one long lock on the forehead, soft round black eyes, purple
# gi, red sash, red wristbands, brown shoes. No cape. +X is the viewer's right in the front view.
from db_common import circle
from db_style3 import arm_bands, bag, block, box, hair_cap, hair_style, lapels, sash, shell, spikes, thin_leg, wedge
from leaf_common import begin_clip, end_clip
from style2 import H, Kit, Ramps, face
from style3 import big_head, finish

SKIN = "#f6d2b0"
SKIN_D = "#d8a47c"
GI = "#4b2e83"
GI_D = "#2e1b58"
HAIRC = "#0a0a12"
LINE = "#4a2a18"
DEFAULT = GI
R = Ramps(
	hair=["#040408", "#08080f", "#12122a", "#2e2c6a", "#5a54c0"],
	skin=["#b98a64", "#dcae86", SKIN, "#fde4ca"],
	gi=["#1e1040", "#2e1b58", GI, "#6a44ad", "#8a64cc"],
	red=["#7a1420", "#a4222a", "#c8333a", "#e8606a"],
	brown=["#3c2612", "#553a1c", "#6b4a2a", "#8e6a42"],
)
HAIR = {"colour": HAIRC, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.52, 0.56), (0, 0, 4.16, 0.74, 0.74), (0, 0, 4.44, 0.84, 0.8), (0, 0, 5.3, 0.84, 0.8), (0, 0, 5.56, 0.74, 0.7), (0, 0, 5.62, 0.58, 0.54)]
_S = dict(flat=0.62, p=1.6, q=0.85)
SPIKES = [
	# short, upright, a little back: the crown
	H((0.0, 0.1, 5.8), (0.02, 0.1, 6.35), (0.06, 0.2, 6.92), 0.5, **_S),
	H((-0.42, -0.12, 5.75), (-0.5, -0.15, 6.3), (-0.72, -0.05, 6.78), 0.42, **_S),
	H((0.42, -0.12, 5.75), (0.52, -0.15, 6.3), (0.76, -0.05, 6.72), 0.42, **_S),
	H((-0.05, -0.42, 5.75), (-0.08, -0.5, 6.2), (-0.14, -0.42, 6.58), 0.4, **_S),
	# out at the sides, up at the tips
	H((-0.66, 0.05, 5.6), (-1.05, 0.05, 5.95), (-1.32, 0.1, 6.34), 0.38, **_S),
	H((0.66, 0.05, 5.6), (1.05, 0.05, 5.92), (1.36, 0.1, 6.28), 0.38, **_S),
	H((-0.72, 0.1, 5.15), (-1.08, 0.1, 5.3), (-1.32, 0.15, 5.62), 0.32, **_S),
	H((0.72, 0.1, 5.15), (1.08, 0.1, 5.28), (1.3, 0.15, 5.58), 0.32, **_S),
	# the back
	H((-0.3, 0.45, 5.6), (-0.38, 0.8, 5.95), (-0.5, 1.02, 6.3), 0.4, **_S),
	H((0.3, 0.45, 5.6), (0.38, 0.8, 5.92), (0.5, 1.02, 6.26), 0.4, **_S),
	H((0.0, 0.55, 5.1), (0.0, 0.95, 5.2), (0.02, 1.18, 5.55), 0.36, **_S),
]
_F = dict(flat=0.55, p=1.3, q=0.75)
FRINGE = [
	# the hairline stays up, leaving a clean forehead
	H((-0.62, -0.58, 5.8), (-0.8, -0.86, 5.62), (-0.84, -0.86, 5.26), 0.26, **_F),
	H((0.64, -0.58, 5.8), (0.8, -0.86, 5.62), (0.84, -0.86, 5.26), 0.26, **_F),
	# the one long lock, down to the brow
	H((0.08, -0.62, 5.85), (0.1, -0.98, 5.55), (0.02, -0.92, 4.86), 0.27, **_F),
	# the sideburns
	H((-0.88, -0.3, 5.42), (-0.92, -0.36, 5.08), (-0.9, -0.42, 4.8), 0.17, **_F),
	H((0.88, -0.3, 5.42), (0.92, -0.36, 5.08), (0.9, -0.42, 4.8), 0.17, **_F),
]
_TORSO = [
	(4.05, 0.84, 0.44, (0, 0, 0, 0, 0)),
	(3.9, 1.04, 0.55, (0, 0, 0, 0, 0)),
	(3.45, 1.05, 0.56, (0.04, -0.07, 0, -0.07, 0.04)),
	(3.1, 1.03, 0.55, (0.09, -0.09, 0.05, -0.09, 0.09)),
	(2.84, 1.0, 0.54, (-0.04, 0.07, -0.05, 0.07, -0.04)),
]
_HIP = [(2.72, 1.0, 0.54, (0, 0, 0, 0, 0)), (2.4, 1.05, 0.6, (0.03, -0.05, 0.03, -0.05, 0.03)), (2.02, 1.05, 0.6, (-0.04, 0.03, 0.06, 0.03, -0.04))]


def _shoe(k, part, s, top):
	cx = s * 0.58
	rows = [(0.08, -0.82, 0.52), (0.26, -0.82, 0.52), (0.42, -0.62, 0.5), (0.56, -0.48, 0.48), (top, -0.45, 0.45)]
	box(k, part, "Shoe", [(z, cx - 0.46, cx + 0.46, y0, y1) for z, y0, y1 in rows], "brown", c=0.09, base=0.42, amp=0.34, grad=0.1)
	block(k, part, "ShoeSole", cx - 0.48, cx + 0.48, -0.85, 0.55, 0.0, 0.09, "brown", c=0.03, base=0.16, amp=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R)
	big_head(k, HEAD_ROWS)
	style = hair_style()
	hair_cap(k, ((5.5, 4.32, 0.89, 0.88), (5.76, 5.0, 0.93, 0.92), (6.05, 5.85, 0.76, 0.74), (6.22, 6.18, 0.38, 0.36)), style)
	spikes(k, SPIKES + FRINGE, style)
	shell(k, "Gi", _TORSO, "gi")
	shell(k, "Hip", _HIP, "gi", vfn=lambda co: -0.3 * max(0.0, (co.z - 2.36) / 0.3))
	wedge(k, "skin", top=4.03, tip=3.6, half=0.4, base=0.4, amp=0.24)
	lapels(k, "gi", bottom=(3.0, 2.94), neck=0.46, wid=0.32)
	sash(k, "red", -0.24, ((-0.3, -0.26, 0.13, 0.19, 1.24, -0.74), (-0.06, 0.0, 0.13, 0.17, 1.42, -0.78)))
	for s, side in ((1, "Left"), (-1, "Right")):
		ax = s * 1.5
		arm_bands(k, f"{side}UpperArm", ax, (("Sleeve", 4.06, 3.34, 0.55, "gi"), ("Arm", 3.36, 2.6, 0.52, "skin"), ("Wrist", 2.62, 2.28, 0.56, "red"), ("Hand", 2.3, 1.8, 0.515, "skin")))
		part = f"{side}UpperLeg"
		thin_leg(k, part, f"{side}Leg", s)
		bag(k, part, s, "gi", z0=0.62, w=0.75, d=0.95)
		_shoe(k, part, s, 0.68)
	finish()


def _eye(f, cx, cy, sgn):
	"""Large and round: a young, open eye with a big black iris and a single highlight; the lid slopes only a little."""
	i, o = cx - sgn * 16, cx + sgn * 16
	shape = f"M{i} {cy + 4}Q{cx - sgn * 2} {cy - 15} {o} {cy - 8}L{o + sgn * 1} {cy + 4}Q{cx + sgn * 6} {cy + 16} {i + sgn * 6} {cy + 13}Z"
	begin_clip(f, shape)
	f.path(shape, "#ffffff")
	f.path(circle(cx - sgn * 1.0, cy + 0.5, 9.5, 13), "#08080e")
	f.path(circle(cx + sgn * 1.5, cy - 4.5, 2.8, 3.4), "#ffffff")
	end_clip(f)
	f.path(f"M{i - sgn * 2} {cy + 5}Q{cx - sgn * 2} {cy - 17} {o + sgn * 4} {cy - 11}L{o + sgn * 1} {cy - 6}Q{cx - sgn * 2} {cy - 12} {i - sgn * 2} {cy + 7}Z", "#08080e")
	f.path(f"M{i + sgn * 8} {cy + 15}Q{cx + sgn * 6} {cy + 17} {o} {cy + 6}", stroke=SKIN_D, sw=1.1)


def _face(f):
	face(f, SKIN, hairline=16, nose_y=90)
	f.soft("M30 40H100V100Q65 118 30 100Z", "#ffe8d0", 0.5, 8)
	f.soft("M-5 30H10Q8 90 22 135H-5Z", SKIN_D, 0.5, 5)
	f.soft("M135 30H120Q122 90 108 135H135Z", SKIN_D, 0.6, 5)
	for cx, sgn in ((37, -1), (93, 1)):
		_eye(f, cx, 68, sgn)
		# a straight, thin, determined brow
		i, o = cx - sgn * 18, cx + sgn * 20
		f.path(f"M{i} {46}L{o} {39}L{o - sgn * 1} {44}L{i + sgn * 1} {52}Z", "#08080e")
	f.path("M54 106Q66 110 78 105", stroke=LINE, sw=2.2)
	f.soft("M58 110Q66 114 74 110V112Q66 117 58 113Z", SKIN_D, 0.5, 2)


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
		a[n].fill(GI)
	a["Torso_Bo"].fill(GI_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(SKIN)
			a[f"{side}Leg_{key}"].fill(GI_D)
		a[f"{side}Arm_T"].fill(GI)
		a[f"{side}Arm_Bo"].fill(SKIN_D)
		a[f"{side}Leg_T"].fill(GI)
		a[f"{side}Leg_Bo"].fill("#3c2612")
