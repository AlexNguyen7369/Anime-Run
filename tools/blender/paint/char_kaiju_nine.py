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


def _cap(k):
	"""One organic growth: the column flares into a thick lower shelf, pinches, and flares again into the broad top, like a spool of flesh."""
	n = 20
	wob = lambda ang, i: (0.05 * math.sin(3 * ang + i) + 0.03 * math.sin(7 * ang)) if i in (3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16) else 0.0
	rows = [(0.66, 4.9), (0.68, 5.0), (0.8, 5.12), (1.06, 5.24), (1.2, 5.36), (1.2, 5.48), (1.04, 5.56), (0.8, 5.6), (0.62, 5.66), (0.56, 5.74), (0.62, 5.84), (0.94, 5.96), (1.36, 6.06), (1.62, 6.18), (1.64, 6.34), (1.5, 6.44), (1.0, 6.5), (0.4, 6.46)]
	o = k.lathe("Head", "Cap", [(r, z, 0.5) for r, z in rows], "bone", n=n, at=(0, 0.02, 0), squash=0.94, wob=wob, outline=0)
	# the top leans back a little more than the shelf, without a break between them
	for v in o.data.vertices:
		f = max(0.0, v.co.z - 5.0)
		v.co.z -= v.co.y * 0.09 * min(1.0, f)
		v.co.y += 0.06 * f
	jitter(o, 0.02)
	bake(o, "bone", k, a=0.54, b=0.46, tone=0.04)
	# deep folds of flesh run up the pinch and out under the top
	for i in range(8):
		ang = math.pi * 2 * (i + 0.5) / 8
		c, d = math.cos(ang), math.sin(ang)
		gem(k, "Head", f"Gill{i}", (c * 0.5, d * 0.46 + 0.02, 5.62), (c * 1.16, d * 1.08 + 0.06, 6.06 - d * 0.1), 0.13, "bone", flat=0.8, bend=-0.14, a=0.44)


def _head(k):
	h = "Head"
	_cap(k)
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


def _spots(k, part, pts, y):
	"""Pits in the flesh: a raised uneven lip with a dark hollow sunk inside it."""
	for i, (x, z, r) in enumerate(pts):
		ring = lambda q, yy: [(x + r * q * (0.8 + 0.2 * ((j + i) % 2)) * math.cos(math.pi * j / 3 + i), yy, z + r * q * (1.15 - 0.2 * ((j + i) % 3 == 0)) * math.sin(math.pi * j / 3 + i)) for j in range(6)]
		verts, faces, flat = k._loft([ring(1.9, y + 0.06), ring(1.5, y - 0.03), ring(1.1, y - 0.035), ring(0.9, y + 0.03)])
		bake(k._mesh(f"Lip{i}", part, verts, faces, flat, outline=0), "bone", k, a=0.5, b=0.5)
		verts, faces, flat = k._loft([ring(0.98, y + 0.05), ring(0.9, y + 0.005)])
		bake(k._mesh(f"Pit{i}", part, verts, faces, flat, outline=0), "spot", k, a=0.4, b=0.2)


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
		# the back: shoulder blades, stepped ribs wrapping from the spine, lumbar blocks
		prism(k, T, f"BackTop{s}", [(s * 0.14, 3.98), (s * 1.0, 4.0), (s * 1.06, 3.6), (s * 0.7, 3.3), (s * 0.14, 3.5)], 0.5, 0.74, "bone", a=0.54, b=0.46, g=0.2)
		prism(k, T, f"Blade{s}", [(s * 0.34, 3.86), (s * 0.84, 3.8), (s * 0.66, 3.4)], 0.7, 0.82, "bone", a=0.6, b=0.46)
		for i, z in enumerate((3.2, 2.98, 2.76)):
			prism(k, T, f"BackRib{s}{i}", [(s * 0.16, z + 0.12), (s * 0.6, z + 0.06), (s * 1.04, z - 0.1), (s * 1.04, z - 0.2), (s * 0.6, z - 0.08), (s * 0.16, z - 0.02)], 0.48, 0.66, "bone", a=0.54, b=0.46)
		block(k, T, f"Lumbar{s}", s * 0.36, 0.5, 2.6, 2.0, 0.28, 0.14, "bone", ch=0.06, corner=0.3, jit=0.015, a=0.52, b=0.46)
	for i in range(7):
		block(k, T, f"Vert{i}", 0, 0.62, 3.96 - 0.28 * i, 3.76 - 0.28 * i, 0.1, 0.1, "bone", ch=0.04, corner=0.3, a=0.56, b=0.46)
	# hollows of brown spots down the breastbone
	_spots(k, T, ((-0.2, 3.68, 0.1), (-0.36, 3.5, 0.08), (-0.16, 3.4, 0.09), (0.2, 3.62, 0.1), (0.4, 3.5, 0.08), (0.2, 3.36, 0.08), (0.5, 3.74, 0.06)), -0.75)


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
	_spots(k, arm, ((s * 1.3, 3.94, 0.09), (s * 1.5, 3.8, 0.07), (s * 1.74, 3.9, 0.08)), -0.67)


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
