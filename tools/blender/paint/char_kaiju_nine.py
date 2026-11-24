# Target look for kaiju_nine "Kaijo No. 9" (design doc section 5), its first form: no face but a lipless grin of square teeth round a pale
# column, two flat stacked discs above it, a bone-beige body of ridged muscle, brown spots in hollows on the chest and shoulders, two dark
# red spikes on each shoulder. Same chunky block body as everyone. +X is the viewer's right. Drawn in-house.
import math

from jk_style3 import bake, jitter
from kaiju_style3 import Kit, Ramps, big_head, block, finish, gem, prism, slab, stroke

PALE, PALE_D = "#cdc6b6", "#93897a"
DEFAULT = PALE
R = Ramps(
	bone=["#544c42", "#7c7466", "#a49c8c", "#c2bbac", "#dcd6ca"],
	deep=["#4a4238", "#665d50", "#847a6a", "#a0968a"],
	spot=["#24120c", "#3c2018", "#583226", "#74483a"],
	spike=["#3c120c", "#662318", "#8e3a2a", "#c06a54"],
	tooth=["#8c8676", "#c8c2b0", "#eeeade", "#ffffff"],
	ink=["#080605", "#14100e"],
)
HAIR = {"colour": PALE, "locks": []}
PROPS = []
T = "UpperTorso"
HEAD_ROWS = [(0, 0, 3.98, 0.56, 0.56), (0, 0, 4.12, 0.78, 0.74), (0, 0, 4.4, 0.84, 0.8), (0, 0, 4.8, 0.8, 0.76), (0, 0, 5.0, 0.7, 0.66), (0, 0, 5.4, 0.66, 0.62)]


def _disc(k, name, z, r, th, tilt):
	"""A flat cap with a ragged thick rim, dished on top."""
	n = 18
	wob = lambda ang, i: 0.04 * math.sin(3 * ang + i)
	rows = [(r * 0.42, -th * 1.5, 0.4), (r * 0.9, -th * 0.6, 0.4), (r, -th * 0.2, 0.5), (r * 1.01, th * 0.3, 0.6), (r * 0.95, th * 0.55, 0.7), (r * 0.5, th * 0.4, 0.6)]
	o = k.lathe("Head", name, rows, "bone", n=n, at=(0, 0.02, z), squash=0.94, wob=wob, outline=0)
	k.tip(o, tilt, (0, 0, z))
	return bake(o, "bone", k, a=0.56, b=0.44, tone=0.03)


def _head(k):
	h = "Head"
	k.tip(block(k, h, "Neck", 0, 0, 6.06, 5.2, 0.46, 0.44, "bone", ch=0.04, corner=0.3, sub=1, a=0.44, b=0.4), 4, (0, 0, 5.5))
	_disc(k, "DiscLow", 5.4, 1.12, 0.16, 5)
	_disc(k, "DiscTop", 6.06, 1.6, 0.2, 7)
	# the grin: gums, then square teeth in two rows round the front and sides
	# the grin: a dark curved mouth across the front, then big square teeth, the corners rising into the cheeks
	up = lambda x: 0.16 * (abs(x) / 0.8) ** 2
	xs = [-0.82 + 0.164 * i for i in range(11)]
	prism(k, h, "Mouth", [(x, 4.72 + up(x)) for x in xs] + [(x, 4.2 + up(x)) for x in reversed(xs)], -0.845, -0.7, "ink", a=0.5, b=0.1)
	for i in range(7):
		x = (i - 3) * 0.226
		for row, (z1, z0) in enumerate(((4.7, 4.49), (4.44, 4.24))):
			c = up(x)
			prism(k, h, f"T{row}{i}", [(x - 0.1, z1 + c), (x + 0.1, z1 + c), (x + 0.105, z0 + c + 0.05), (x + 0.06, z0 + c), (x - 0.06, z0 + c), (x - 0.105, z0 + c + 0.05)] if row == 0 else [(x - 0.06, z1 + c), (x + 0.06, z1 + c), (x + 0.105, z1 + c - 0.05), (x + 0.1, z0 + c), (x - 0.1, z0 + c), (x - 0.105, z1 + c - 0.05)], -0.92, -0.82, "tooth", a=0.62, b=0.3)
	for s in (1, -1):
		slab(k, f"MouthS{s}", [(-0.8, 4.88), (-0.1, 4.82), (0.1, 4.7), (-0.1, 4.52), (-0.8, 4.36)], *sorted((s * 0.7, s * 0.855)), "ink", a=0.5, b=0.1)
		for i, y in enumerate((-0.68, -0.45, -0.22)):
			for row, (z1, z0) in enumerate(((4.84, 4.65), (4.6, 4.42))):
				slab(k, f"ST{row}{s}{i}", [(y - 0.1, z1 - 0.02 * i), (y + 0.1, z1 - 0.02 * i), (y + 0.09, z0 + 0.03 * i), (y - 0.09, z0 + 0.03 * i)], *sorted((s * 0.82, s * 0.9)), "tooth", a=0.6, b=0.3)
	# the lip above, bent to the same curve
	prism(k, h, "Lip", [(x, 4.82 + up(x)) for x in xs] + [(x, 4.71 + up(x)) for x in reversed(xs)], -0.9, -0.7, "bone", a=0.6, b=0.4)
	prism(k, h, "LipLow", [(x, 4.24 + up(x)) for x in xs] + [(x, 4.14 + up(x)) for x in reversed(xs)], -0.9, -0.7, "bone", a=0.5, b=0.4)
	block(k, h, "Jaw", 0, -0.02, 4.2, 3.94, 0.8, 0.8, "bone", ch=0.06, corner=0.2, a=0.5, b=0.44)
	for s in (1, -1):
		# the cheek hinge juts at the jaw's corner
		block(k, h, f"Hinge{s}", s * 0.86, 0.36, 4.62, 4.14, 0.1, 0.26, "bone", ch=0.06, corner=0.3, a=0.52, b=0.44)
		# folds down the column
		gem(k, h, f"Fold{s}", (s * 0.6, -0.62, 4.84), (s * 0.42, -0.5, 5.4), 0.12, "bone", flat=0.6, a=0.5)


def _spots(k, part, pts, y, ramp="spot"):
	for i, (x, z, r) in enumerate(pts):
		poly = [(x + r * math.cos(math.pi * j / 3 + i) * (0.85 + 0.15 * (j % 2)), z + r * math.sin(math.pi * j / 3 + i)) for j in range(6)]
		prism(k, part, f"Spot{i}", poly, y - 0.04, y + 0.06, ramp, a=0.46, b=0.2)


def _body(k):
	k.reshape(T, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, T, "Trunk", 0, 0, 4.02, 1.94, 1.03, 0.55, "deep", ch=0.08, jit=0.02, mids=(3.4, 2.8), a=0.56, b=0.5)
	block(k, T, "Neck", 0, 0, 4.2, 3.86, 0.62, 0.56, "bone", ch=0.05, corner=0.3, a=0.44, b=0.4)
	for s in (1, -1):
		prism(k, T, f"Pec{s}", [(s * 0.04, 3.82), (s * 0.5, 3.98), (s * 1.05, 3.94), (s * 1.07, 3.4), (s * 0.72, 3.16), (s * 0.04, 3.24)], -0.74, -0.5, "bone", a=0.54, b=0.46, g=0.2)
		prism(k, T, f"Clav{s}", [(s * 0.1, 3.86), (s * 0.56, 4.04), (s * 1.02, 4.08), (s * 0.56, 3.94)], -0.82, -0.66, "bone", a=0.62, b=0.4)
		for i, z in enumerate((3.1, 2.92, 2.74)):
			prism(k, T, f"Rib{s}{i}", [(s * 0.48, z - 0.02), (s * 1.04, z + 0.14), (s * 1.06, z + 0.02), (s * 0.5, z - 0.14)], -0.66, -0.5, "bone", a=0.54, b=0.46)
			block(k, T, f"RibS{s}{i}", s * 1.02, 0, z + 0.12, z - 0.02, 0.06, 0.5, "bone", ch=0.03, a=0.5, b=0.44)
		for i, z in enumerate((3.08, 2.76, 2.44)):
			block(k, T, f"Ab{s}{i}", s * 0.24, -0.58, z, z - 0.28, 0.21, 0.1, "bone", ch=0.05, corner=0.3, a=0.54, b=0.46)
		block(k, T, f"Hip{s}", s * 0.72, -0.1, 2.56, 1.98, 0.36, 0.54, "bone", ch=0.08, jit=0.015, a=0.5, b=0.46)
		prism(k, T, f"Back{s}", [(s * 0.06, 3.96), (s * 1.04, 3.96), (s * 1.04, 3.1), (s * 0.5, 2.6), (s * 0.06, 2.6)], 0.5, 0.68, "bone", a=0.48, b=0.46, g=0.2)
	# hollows of brown spots down the breastbone
	_spots(k, T, ((-0.2, 3.66, 0.11), (-0.34, 3.48, 0.1), (-0.16, 3.44, 0.09), (-0.28, 3.32, 0.08), (0.22, 3.6, 0.11), (0.38, 3.46, 0.09), (0.2, 3.4, 0.1), (0.52, 3.62, 0.07), (-0.5, 3.64, 0.07)), -0.75)


def _arm(k, side, s):
	arm, ax = f"{side}UpperArm", s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Core", ax, 0, 3.9, 2.0, 0.46, 0.46, "deep", ch=0.04, corner=0.2, a=0.5, b=0.5)
	block(k, arm, "Delt", s * 1.54, 0, 4.16, 3.5, 0.6, 0.6, "bone", ch=0.16, corner=0.26, sub=1, jit=0.03, a=0.5, b=0.48)
	block(k, arm, "Up", ax, 0, 3.46, 2.96, 0.52, 0.53, "bone", ch=0.08, jit=0.025, sub=1, a=0.5, b=0.48)
	block(k, arm, "Fore", ax, 0, 2.82, 2.3, 0.54, 0.54, "bone", ch=0.08, jit=0.025, sub=1, a=0.5, b=0.48)
	block(k, arm, "Hand", ax, 0, 2.26, 1.78, 0.52, 0.52, "bone", ch=0.06, a=0.56, b=0.4)
	# the two red-brown spikes on the shoulder, hooked inward, and the spots round them
	gem(k, arm, "SpikeA", (s * 1.6, -0.12, 4.02), (s * 1.62, -0.16, 4.46), 0.2, "spike", flat=0.9, a=0.54)
	gem(k, arm, "SpikeB", (s * 1.96, 0.04, 3.98), (s * 2.12, 0.02, 4.44), 0.2, "spike", flat=0.9, a=0.54)
	_spots(k, arm, ((s * 1.3, 3.96, 0.1), (s * 1.46, 3.84, 0.08), (s * 1.28, 3.74, 0.09), (s * 1.62, 3.96, 0.08), (s * 1.8, 3.82, 0.09)), -0.62)


def _leg(k, side, s):
	leg, x, px = f"{side}UpperLeg", s * 0.5, s * 0.535
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Core", px, 0, 1.94, 0.2, 0.46, 0.5, "deep", ch=0.04, a=0.5, b=0.5)
	for dx, tag in ((-0.26, "A"), (0.26, "B")):
		block(k, leg, f"Thigh{tag}", px + dx, -0.02, 1.98, 1.14, 0.25, 0.56, "bone", ch=0.06, jit=0.02, a=0.5, b=0.48)
	block(k, leg, "Knee", px, -0.46, 1.22, 0.9, 0.32, 0.16, "bone", ch=0.06, corner=0.3, a=0.58, b=0.44)
	block(k, leg, "Shin", px, 0, 1.0, 0.36, 0.5, 0.54, "bone", ch=0.08, jit=0.02, sub=1, a=0.5, b=0.48)
	block(k, leg, "ShinRidge", px, -0.54, 0.92, 0.4, 0.14, 0.07, "bone", ch=0.04, a=0.6, b=0.4)
	block(k, leg, "Foot", px, -0.2, 0.42, 0.0, 0.52, 0.66, "bone", ch=0.1, corner=0.22, a=0.52, b=0.46)
	for i, dx in enumerate((-0.34, 0, 0.34)):
		block(k, leg, f"Toe{i}", px + dx, -0.88, 0.22, 0.0, 0.15, 0.16, "bone", ch=0.05, a=0.56, b=0.42)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_head(k)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def paint(a):
	R.paint(a)
	for n in list(a.faces):
		if n != "Hair":
			a[n].fill(PALE)
	f = a["Head_F"]
	for x in (38, 52, 65, 78, 92):
		stroke(f, f"M{x} -5Q{x + (65 - x) * 0.1} 20 {x} 48", PALE_D, 1.6, 0.7)
