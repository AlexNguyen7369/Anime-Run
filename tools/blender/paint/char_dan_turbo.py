# Target look for dan_turbo "Okaron" (design doc section 5): tall wavy white hair streaked red, ash-grey skin, round thin glasses over glaring red eyes,
# a black mask over the lower face with a huge row of bared teeth, a torn black high-collar school coat with gold buttons and red spiked ends,
# rolled trousers and bare grey feet. Block body as everyone's. +X is the viewer's right. Drawn in-house.
import math

from dan_style3 import Kit, T, bare_foot, big_head, block, core_leg, crown, ears, eye, finish, gem, hoop, jacket, mop, prism, ramps, rest, shade, sleeve, stroke, trouser

SKIN = "#bdb6b4"
SKIN_D = "#7c7478"
BLACK = "#1a1a22"
DEFAULT = BLACK
R = ramps(
	["#8a8890", "#b8b6be", "#e0dfe4", "#f4f3f6", "#ffffff"],
	skin=["#6c666a", "#948e90", "#bdb6b4", "#dcd8d4"],
	streak=["#7a0a12", "#b4141e", "#e02a30", "#ff6a60"],
	coat=["#060609", "#101016", "#1c1c25", "#343442"],
	tooth=["#a8a494", "#d8d4c6", "#f6f4ea", "#ffffff"],
	roll=["#1c2230", "#2c3446", "#424c62", "#5c6880"],
	frame=["#22303a", "#3c5260", "#6a8490", "#a8c0c8"],
)
HAIR = {"colour": "#E0DFE4", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.22), (1.08, 5.5), (1.08, 5.9), (0.9, 6.3), (0.4, 6.56)])
	mop(k, "Back", [(d, z, 0.36) for d, z in ((14, 4.6), (40, 4.3), (66, 4.14), (90, 4.1), (114, 4.14), (140, 4.3), (166, 4.6))], rx=1.12, ry=1.06, zroot=5.7)
	mop(k, "Mid", [(d, 5.1, 0.4) for d in (0, 30, 60, 90, 120, 150, 180)], rx=1.2, ry=1.14, zroot=6.2, root=0.7, bend=0.2, a=0.54)
	# the crest: thick waves blown straight up and a little back
	for i, (x, y, tx, ty, z, r) in enumerate((
		(0, -0.5, 0.14, -0.3, 6.92, 0.4), (-0.44, -0.4, -0.5, -0.2, 6.84, 0.38), (0.48, -0.4, 0.66, -0.16, 6.94, 0.38), (-0.84, -0.2, -1.12, 0.0, 6.7, 0.36), (0.86, -0.2, 1.2, 0.0, 6.6, 0.36),
		(0, 0.2, -0.1, 0.5, 7.0, 0.44), (-0.5, 0.4, -0.7, 0.8, 6.96, 0.42), (0.5, 0.4, 0.72, 0.8, 6.9, 0.42), (0, 0.7, 0.1, 1.2, 6.7, 0.42),
		(-1.0, 0.1, -1.46, 0.2, 6.1, 0.32), (1.0, 0.1, 1.46, 0.2, 6.06, 0.32), (-0.8, 0.7, -1.2, 1.1, 6.2, 0.34), (0.8, 0.7, 1.2, 1.1, 6.16, 0.34),
	)):
		gem(k, "Head", f"Crest{i}", (x, y, 5.9), (tx, ty, z), r, flat=0.75, bend=0.04, twist=0.3 + 0.1 * (i % 3), a=0.54)
	# waves falling on the brow
	for i, (b, t, r) in enumerate((
		((-0.1, -0.74, 6.2), (-0.3, -1.06, 5.04), 0.22), ((-0.4, -0.7, 6.14), (-0.7, -1.04, 4.98), 0.27), ((-0.74, -0.6, 6.0), (-1.08, -0.94, 4.84), 0.28),
		((0.14, -0.74, 6.2), (0.2, -1.06, 5.12), 0.2), ((0.36, -0.7, 6.14), (0.58, -1.04, 4.98), 0.26), ((0.74, -0.6, 6.0), (1.06, -0.94, 4.84), 0.28),
	)):
		gem(k, "Head", f"Brow{i}", b, t, r, flat=0.45, bend=0.14, twist=0.15 + 0.1 * (i % 3), across=(1, 0, 0), a=0.56)
	# the red streaks, riding on the white from brow to crest
	for i, pts in enumerate((((-0.42, -0.96, 5.5), (-0.36, -0.62, 6.86)), ((0.28, -1.0, 5.5), (0.3, -0.66, 6.9)), ((0.82, -0.92, 5.36), (1.02, -0.46, 6.5)), ((-0.92, -0.86, 5.3), (-1.04, -0.4, 6.5)), ((0.0, -0.86, 6.0), (-0.06, -0.5, 7.0)), ((1.16, 0.2, 5.0), (1.2, 0.2, 6.2)), ((-1.16, 0.2, 5.0), (-1.2, 0.2, 6.2)), ((0.3, 1.1, 4.8), (0.36, 1.0, 6.2)), ((-0.4, 1.1, 4.8), (-0.44, 1.0, 6.2)))):
		side = abs(pts[0][0]) > 1.1
		# two spikes from one middle: thick in the middle, pointed at both ends
		mid = tuple((u + v) / 2 + (0.06 if j == 2 else 0) for j, (u, v) in enumerate(zip(*pts)))
		for j, end in enumerate(pts):
			gem(k, "Head", f"Streak{i}{j}", mid, end, 0.13, "streak", flat=1.5, twist=0.1, across=(0, 1, 0) if side else (1, 0, 0), a=0.6)


def _mask(k):
	"""The black half mask, wide as the jaw, and the long grin of separate teeth."""
	block(k, "Head", "Mask", 0, 0, 4.5, 3.9, 0.94, 0.88, "coat", ch=0.06, corner=0.16, sub=1, a=0.5, b=0.46)
	prism(k, "Head", "Maw", [(-0.86, 4.56), (-0.4, 4.36), (0.4, 4.36), (0.86, 4.56), (0.8, 4.22), (0.42, 3.94), (-0.42, 3.94), (-0.8, 4.22)], -0.93, -0.86, "black", a=0.1, b=0.05)
	n = 11
	for i in range(n):
		x = -0.72 + 1.44 * i / (n - 1)
		u = abs(x) / 0.72
		top, mid, low = 4.36 + 0.15 * u * u, 4.17 + 0.17 * u * u, 3.97 + 0.22 * u * u
		w = 0.062
		prism(k, "Head", f"Up{i}", [(x - w, top), (x + w, top), (x + w, mid + 0.05), (x, mid - 0.02), (x - w, mid + 0.05)], -0.98, -0.9, "tooth", a=0.7, b=0.2)
		prism(k, "Head", f"Dn{i}", [(x - w, low), (x + w, low), (x + w, mid - 0.04), (x, mid + 0.0), (x - w, mid - 0.04)], -0.97, -0.9, "tooth", a=0.6, b=0.2)


def _coat(k):
	jacket(k, "coat", hem=1.9, seam="black")
	for i, z in enumerate((3.5, 3.06, 2.62, 2.18)):
		block(k, T, f"Button{i}", 0.0, -0.64, z + 0.09, z - 0.09, 0.09, 0.035, "gold", ch=0.03, corner=0.5, a=0.62, b=0.36)
	# the collar stands open in torn points with red ends
	for i, (deg, h, out) in enumerate(((-58, 4.5, 1.3), (-20, 4.8, 1.75), (10, 5.5, 2.0), (45, 5.8, 1.8), (75, 5.5, 1.6), (105, 5.5, 1.6), (135, 5.8, 1.8), (170, 5.5, 2.0), (200, 4.8, 1.75), (238, 4.5, 1.3))):
		a = math.radians(deg)
		c, s = math.cos(a), math.sin(a)
		gem(k, T, f"Collar{i}", (0.82 * c, 0.62 * s, 3.8), (out * c * 0.92, out * s * 0.86, h), 0.4, "coat", tip="streak", split=0.7, flat=0.3, across=(-s, c, 0), a=0.5)
	# torn tails from the waist, red at the ends; each rides a leg and starts at z 2
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		for i, (b, t, r, ac) in enumerate((
			((s * 0.9, -0.5, 1.96), (s * 1.3, -0.8, 0.7), 0.3, (1, 0, 0)), ((s * 1.06, 0.1, 1.96), (s * 1.72, 0.3, 0.7), 0.42, (0, 1, 0)),
			((s * 0.8, 0.54, 1.96), (s * 1.2, 1.2, 0.5), 0.42, (1, 0, 0)), ((s * 0.3, 0.58, 1.96), (s * 0.3, 1.16, 0.7), 0.36, (1, 0, 0)),
		)):
			gem(k, leg, f"Tail{i}", b, t, r, "coat", tip="streak", split=0.72, flat=0.3, twist=0.15, across=ac, a=0.46)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.74)
	_hair(k)
	_mask(k)
	for s in (1, -1):
		hoop(k, "Head", f"Glass{s}", (s * 0.4, -0.92, 4.76), 0.29, 0.03, "frame", squash=0.82, a=0.6, b=0.36)
	block(k, "Head", "Bridge", 0, -0.92, 4.8, 4.75, 0.11, 0.03, "frame", ch=0.01, a=0.6, b=0.36)
	_coat(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="coat", cuff=2.5)
		for i in range(2):
			block(k, f"{side}UpperArm", f"Stud{i}", s * 1.5 + 0.12 - 0.24 * i, -0.55, 2.66, 2.56, 0.05, 0.02, "gold", ch=0.015, a=0.62)
		leg, px = trouser(k, side, s, ramp="coat", low=0.84)
		block(k, leg, "Roll", px, 0, 0.98, 0.74, 0.54, 0.6, "roll", ch=0.05, corner=0.18, jit=0.012, a=0.52, b=0.5)
		bare_foot(k, leg, px, top=0.8)
	finish()


def _face(f):
	f.fill(SKIN)
	f.soft("M-5-5H135V34Q65 40 -5 34Z", SKIN_D, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.7, 5)
	for s, cx in ((-1, 36), (1, 94)):
		# sunken sockets, hard red eyes
		f.soft(f"M{cx - 24} 56Q{cx} 36 {cx + 24} 56Q{cx} 80 {cx - 24} 56Z", "#4c1a24", 0.7, 3)
		eye(f, cx, 56, s, ("#5c0608", "#c81818", "#ff7a4a"), w=36, up=11, dn=8, inner=7, outer=-6, ir=(8, 9), pu=(2.6, 3.8), lash="#0c060a", wing=6, thick=1.5, lid=0.2, white="#f4ecd8")
		f.path(f"M{cx - s * 22} 48L{cx + s * 20} 36L{cx + s * 22} 41L{cx - s * 20} 55Z", "#241a20")
		stroke(f, f"M{cx - s * 12} 72Q{cx} 78 {cx + s * 16} 70", "#8c2a30", 1.8)
		stroke(f, f"M{cx - s * 6} 77Q{cx + s * 4} 82 {cx + s * 18} 75", "#8c2a30", 1.4)
	stroke(f, "M60 50L63 60M70 50L67 60", "#4a4044", 1.6)
	f.soft("M-5 80H135V135H-5Z", "#1a1620", 0.9, 2)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#b8b6be", BLACK, BLACK, BLACK)
