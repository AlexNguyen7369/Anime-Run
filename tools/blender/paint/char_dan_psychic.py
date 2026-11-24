# Target look for dan_psychic "Momu" (design doc section 5): a dark chestnut bob with long blunt locks to the collar and loose flicks on top, sharp brown eyes,
# a black choker, long teal earrings, a roomy pink sweater with a white collar and big red bow, a navy pleated skirt, slouched white socks, brown loafers.
# Block body as everyone's. +X is the viewer's right. Drawn in-house.
from dan_style3 import SKIN, Kit, T, big_head, block, bow, brow2, crown, eye, face, finish, gem, mop, nose, pleats, prism, ramps, rest, shirt_collar, slab, sleeve, sock_leg, torso_core

PINK = "#f29cb8"
DEFAULT = PINK
R = ramps(
	["#221012", "#3a1c1e", "#58302e", "#784842", "#a87870"],
	pink=["#a84c74", "#d8769a", "#f6a4be", "#ffd0de"],
	teal=["#1c7868", "#34ac98", "#6cdcc8", "#c8fff4"],
)
HAIR = {"colour": "#6A3038", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.3), (1.06, 5.54), (1.02, 5.84), (0.72, 6.08), (0.2, 6.16)])
	# the bob: smooth sheets to the nape
	block(k, "Head", "Bob", 0, 0.34, 5.5, 4.0, 1.04, 0.62, "hair", ch=0.08, corner=0.3, sub=1, jit=0.02, mids=(5.0, 4.5), a=0.44, b=0.42)
	mop(k, "Back", [(d, z, 0.38) for d, z in ((10, 3.8), (36, 3.8), (62, 3.84), (90, 3.82), (118, 3.84), (144, 3.8), (170, 3.8))], rx=1.12, ry=1.1, zroot=5.6, bend=0.05)
	mop(k, "Over", [(d, 4.9, 0.4) for d in (0, 36, 72, 108, 144, 180)], rx=1.12, ry=1.1, zroot=5.96, root=0.55, bend=0.2, a=0.54)
	# long blunt front locks framing the face, below the jaw
	for s in (1, -1):
		slab(k, f"Lock{s}", [(-0.72, 5.2), (-0.86, 4.5), (-0.8, 3.74), (-0.5, 3.62), (-0.1, 5.2)], s * 0.86, s * 1.04, "hair", a=0.52, b=0.36)
		gem(k, "Head", f"LockIn{s}", (s * 0.6, -0.56, 5.84), (s * 0.92, -1.0, 3.5), 0.3, flat=0.5, twist=0.2, across=(1, 0, 0), a=0.54)
		gem(k, "Head", f"LockOut{s}", (s * 0.78, -0.34, 5.64), (s * 1.08, -0.72, 3.46), 0.36, flat=0.4, twist=0.2, across=(0, 1, 0), a=0.5)
	# the fringe: a centre lock over the nose bridge, the rest swept away from a high part
	part = (0.16, -0.7, 6.02)
	for i, (t, r) in enumerate((((0.06, -1.02, 4.84), 0.17), ((-0.3, -1.03, 4.98), 0.24), ((-0.66, -1.0, 4.9), 0.28), ((-0.98, -0.94, 4.7), 0.28), ((0.4, -1.03, 5.04), 0.24), ((0.72, -1.0, 4.94), 0.27), ((1.0, -0.94, 4.72), 0.28))):
		gem(k, "Head", f"Fringe{i}", part, t, r, flat=0.42, bend=0.1, twist=0.15 + 0.1 * (i % 3), across=(1, 0, 0), a=0.55)
	# the loose flicks on top
	gem(k, "Head", "FlickA", (0.1, -0.3, 6.06), (0.8, -0.6, 6.42), 0.16, flat=0.5, bend=0.35, a=0.58)
	gem(k, "Head", "FlickB", (0.0, -0.1, 6.06), (-0.56, -0.2, 6.46), 0.16, flat=0.5, bend=0.3, a=0.58)
	gem(k, "Head", "FlickC", (0.1, 0.0, 6.06), (0.3, 0.3, 6.54), 0.14, flat=0.5, bend=0.3, a=0.56)


def _earrings(k):
	for s in (1, -1):
		block(k, "Head", f"Stud{s}", s * 1.15, -0.6, 4.5, 4.34, 0.06, 0.08, "teal", ch=0.02, a=0.62, b=0.34)
		prism(k, "Head", f"Drop{s}", [(s * 1.15, 4.34), (s * 1.24, 3.94), (s * 1.15, 3.76), (s * 1.06, 3.94)], -0.66, -0.56, "teal", a=0.6, b=0.36)


def _body(k):
	torso_core(k)
	block(k, T, "Sweater", 0, 0, 3.98, 2.02, 1.07, 0.6, "pink", ch=0.07, flare=0.04, jit=0.03, sub=1, mids=(3.4, 2.9, 2.4), a=0.52, b=0.5, g=0.1, tone=0.03)
	block(k, T, "Rib", 0, 0, 2.14, 1.84, 1.08, 0.61, "pink", ch=0.04, a=0.42, b=0.46)
	prism(k, T, "Vee", [(-0.46, 4.02), (0.46, 4.02), (0, 3.36)], -0.67, -0.58, "shirt", a=0.6, b=0.3)
	shirt_collar(k)
	for s in (1, -1):
		prism(k, T, f"VeeRim{s}", [(s * 0.46, 4.02), (s * 0.6, 4.02), (s * 0.02, 3.2), (s * 0.0, 3.34)], -0.69, -0.6, "pink", a=0.42, b=0.4)
	bow(k, z=3.68, w=0.58, y=-0.8)
	pleats(k, "navy", top=1.98, hem=1.22)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_earrings(k)
	block(k, "Head", "Choker", 0, 0, 4.14, 3.97, 0.78, 0.83, "black", ch=0.02, corner=0.2, sub=1, a=0.56, b=0.44)
	_body(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		sleeve(k, side, s, ramp="pink", cuff=2.36)
		block(k, f"{side}UpperArm", "Slouch", s * 1.5, 0, 2.72, 2.5, 0.56, 0.56, "pink", ch=0.06, corner=0.18, jit=0.015, a=0.54, b=0.46)
		sock_leg(k, side, s, top=1.0, baggy=True)
	finish()


def _face(f):
	face(f)
	for s, cx in ((-1, 37), (1, 93)):
		eye(f, cx, 64, s, ("#2c1010", "#6c2c24", "#b4604a"), w=37, up=16, dn=10, inner=5, outer=-5, ir=(12, 14.5), pu=(3.8, 5.6), lash="#1c0c10", wing=7, thick=1.4, lid=0.24)
		brow2(f, cx, 42, s, 30, 3.0, 4.4, "#47202a", arc=-2)
	nose(f)
	# a cocky half-open smirk
	f.path("M54 104Q66 107 79 101Q74 113 65 113Q57 112 54 104Z", "#7a2028", stroke="#5c1820", sw=1.2)
	f.path("M57 105Q66 107.5 76 103L74 107Q66 109 59 108Z", "#fffdf6")


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	rest(a, SKIN, "#47202a", PINK, PINK, SKIN)
