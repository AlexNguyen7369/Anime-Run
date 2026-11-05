# Target look for saw_hero "Denjy" (design doc section 5), the plain human form and never the sawblade one: messy short orange-blond hair in loose
# shaggy clumps, tired yellow-brown eyes with dark bags, a wide grin of jagged teeth, a white shirt with sleeves rolled to the elbow, worn
# untucked, a black tie pulled loose, black trousers. A small pull cord hangs from the chest. +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, big_head, block, crown, face_base, finish, gem, head_rest, prism, slab
from saw_common import SKIN, SKIN_D, SHIRT, collar, jagged_mouth, paint_limbs, paint_shirt, ramps, rolled_arm, shirt_body, suit_leg, tie

DEFAULT = SHIRT
HAIR_D = "#bd6f14"
R = ramps(["#a4560a", "#d07a12", "#ea9424", "#f6b040", "#ffd078"], cord=["#2a2a30", "#44444c", "#6a6a74", "#9a9aa4"])
HAIR = {"colour": "#EA9424", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.4), (1.05, 5.62), (0.97, 5.86), (0.6, 6.06), (0.16, 6.12)])
	block(k, "Head", "Back", 0, 0.3, 5.46, 4.46, 0.95, 0.58, "hair", ch=0.06, corner=0.3, jit=0.025, sub=1, mids=(5.0,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.8, 5.42), (-0.8, 5.06), (-0.3, 4.9), (0.86, 4.62), (0.86, 5.42)], s * 0.84, s * 0.98, "hair", a=0.52, b=0.34)
	# shaggy fringe: uneven, crossing, hanging to the eyes
	root = (0.04, -0.78, 5.78)
	for i, (t, r) in enumerate((((-0.96, -0.9, 4.84), 0.26), ((-0.66, -0.95, 5.0), 0.25), ((-0.36, -0.96, 4.92), 0.24), ((-0.08, -0.97, 5.08), 0.22), ((0.24, -0.97, 4.9), 0.24), ((0.54, -0.96, 5.02), 0.25), ((0.84, -0.93, 4.82), 0.26))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.13 * i, a=0.54, across=(0, 0, 1))
	# clumps that droop and flick: messy, not tall spikes
	clumps = (
		((-0.5, -0.5, 5.9), (-1.2, -0.62, 5.5), 0.3),
		((0.5, -0.5, 5.9), (1.22, -0.6, 5.56), 0.3),
		((-0.7, 0.0, 5.8), (-1.36, 0.02, 5.28), 0.32),
		((0.7, 0.0, 5.8), (1.36, 0.0, 5.2), 0.32),
		((-0.66, 0.4, 5.74), (-1.28, 0.66, 5.02), 0.32),
		((0.66, 0.4, 5.74), (1.28, 0.66, 4.96), 0.32),
		((-0.3, 0.66, 5.7), (-0.64, 1.16, 4.82), 0.32),
		((0.3, 0.66, 5.7), (0.62, 1.14, 4.72), 0.32),
		((0, 0.76, 5.6), (0.02, 1.2, 4.5), 0.32),
		((-0.3, -0.2, 6.02), (-0.8, -0.5, 6.32), 0.34),
		((0.14, -0.3, 6.02), (0.3, -0.66, 6.38), 0.34),
		((0.5, -0.05, 5.98), (1.04, -0.16, 6.22), 0.34),
		((-0.46, 0.3, 5.98), (-1.0, 0.42, 6.16), 0.34),
		((0.3, 0.4, 6.0), (0.56, 0.8, 6.2), 0.34),
		((-0.1, 0.34, 6.04), (-0.28, 0.74, 6.3), 0.34),
	)
	for i, (b, t, r) in enumerate(clumps):
		gem(k, "Head", f"Clump{i}", b, t, r, flat=0.55, twist=0.3, a=0.52)


def _cord(k):
	"""The pull cord: a short line out of the shirt front, ending in a ring handle. Not a logo; his one mark of what he is."""
	t = "UpperTorso"
	prism(k, t, "Cord", [(-0.03, 3.3), (0.03, 3.3), (0.03, 2.96), (-0.03, 2.96)], -0.61, -0.585, "cord", a=0.5, b=0.4)
	ring = [(-0.13, 2.97), (0.13, 2.97), (0.09, 2.78), (-0.09, 2.78)]
	hole = [(-0.05, 2.92), (0.05, 2.92), (0.04, 2.83), (-0.04, 2.83)]
	prism(k, t, "Handle", ring, -0.63, -0.585, "cord", a=0.5, b=0.5)
	prism(k, t, "HandleHole", hole, -0.637, -0.625, "shirt", a=0.5, b=0.2)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	shirt_body(k, hem=1.9)
	collar(k)
	tie(k, end=3.0, dx=0.16, top=3.74)
	_cord(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		rolled_arm(k, side, s)
		suit_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f0a080", top=24)
	# half-lidded, cocky, with bags under them
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 64, s, 34, 13, "#b47e2a", tilt=1.6, r=10.5, lid=0.34, lash="#3a2410", lash_t=3.0, flick=2, pupil=0.38, sclera="#fbf6ea", crease_line=False)
		brow2(f, x, 50, s, 30, 3.4, -0.6, "#b86c14", arc=-1.5)
		f.path(f"M{x - 15} 80Q{x} 86 {x + 15} 80", stroke="#b98a70", sw=1.5, opacity=0.65)
	nose(f, SKIN, y=78, h=9)
	jagged_mouth(f, 36, 96, 95, 23, teeth=8)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_T"].fill(HAIR_D)
	paint_shirt(a)
	paint_limbs(a, SKIN)
