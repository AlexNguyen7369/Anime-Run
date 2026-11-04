# Target look for ds_sister (design doc section 5): a child character, fully covered. Long black hair with orange ends down the back,
# a blunt fringe, a pink bow, big soft pink eyes, a green bamboo bar with red ties, pink patterned kimono to the shins with a high
# collar, checked obi with a green cord, a dark checked coat, white wraps and red-strapped sandals.
import math

from ds_style3 import RECT, art_uv, bake, block, cap, checks, coat, core_leg, eye, gem, rect_d, sandal, skin_head, studs
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#fce0cc"
SKIN_D = "#e8b49a"
DEFAULT = "#f2a4bc"
R = Ramps(
	hair=["#08070c", "#141219", "#24212c", "#3c3848"],
	tip=["#a03a12", "#cf5a1c", "#e8762a", "#f49848"],
	skin=["#cf9270", "#efbc9c", "#fce0cc", "#fff0e2"],
	white=["#a6a4ae", "#dcdce2", "#f4f4f6", "#ffffff"],
	wrapline=["#6e6e78", "#8c8c96", "#a8a8b2"],
	pink=["#b8607e", "#dc8aa4", "#f4a8c0", "#ffc8d8"],
	bow=["#b84c78", "#e0709c", "#f690b6", "#ffb6d0"],
	green=["#3f6a26", "#5e8c36", "#7cac4c", "#9cc86a"],
	node=["#3c5e22", "#567e30", "#6e9a40"],
	cord=["#7a0e14", "#a81a1c", "#cc2c28"],
	sole=["#5e3d22", "#855a34", "#a87a4c", "#c79a68"],
	strap=["#7a0e14", "#a81a1c", "#cc2c28"],
	uni=["#1c0e0c", "#30180f", "#4a2318"],
)
HAIR = {"colour": "#141219", "locks": []}
PROPS = []
OBI = (-1.2, 1.2, 2.0, 3.0)
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.58), (0, 0, 4.14, 0.78, 0.76), (0, 0, 4.42, 0.88, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]


def _hair(k):
	cap(k, band_z=5.18, side_z=4.32, back_y=-0.18)
	# a smooth round top: long wedges lying back, no spikes standing up
	root = (0, 0.1, 5.7)
	for i, (t, r) in enumerate((((-0.9, -0.3, 6.1), 0.52), ((-0.34, -0.34, 6.34), 0.54), ((0.34, -0.34, 6.34), 0.54), ((0.9, -0.3, 6.1), 0.52), ((-0.76, 0.46, 6.18), 0.56), ((0.0, 0.56, 6.32), 0.58), ((0.76, 0.46, 6.18), 0.56), ((-1.12, 0.3, 5.72), 0.5), ((1.12, 0.3, 5.72), 0.5))):
		gem(k, "Head", f"Top{i}", (root[0] + t[0] * 0.2, root[1] + t[1] * 0.2, root[2]), t, r, flat=0.72, bend=0.04, twist=0.3 + 0.17 * i % 0.5)
	# the fringe: broad flat wedges from the crown, parted a little off centre, ending just above the eyes
	for i, (x, z, r) in enumerate(((-0.74, 5.0, 0.3), (-0.34, 4.94, 0.34), (0.08, 5.02, 0.32), (0.46, 4.96, 0.32), (0.8, 5.04, 0.26))):
		gem(k, "Head", f"Fringe{i}", (x * 0.86, -0.62, 6.1), (x, -0.96, z), r, flat=0.45, twist=0.15 + 0.1 * i % 0.3, a=0.54, across=(1, 0, 0))
	# side locks framing the face to the chin, orange at the ends
	for s in (1, -1):
		block(k, "Head", f"Lock{s}", s * 0.9, -0.54, 5.3, 4.5, 0.11, 0.26, "hair", ch=0.03, a=0.46, b=0.4)
		gem(k, "Head", f"LockTip{s}", (s * 0.9, -0.54, 4.56), (s * 0.94, -0.56, 3.9), 0.25, ramp="hair", tip="tip", split=0.3, flat=0.45, twist=0.2, across=(0, 1, 0))
	# the long fall down the back to the thighs: one solid mass, orange through its bottom, then a row of wedges
	k_rows = [(0, 0.76, 5.3, 0.86, 0.2), (0, 0.8, 4.2, 0.86, 0.22), (0, 0.84, 2.6, 0.86, 0.22)]
	bake(k, k.tube("Head", "Fall", k_rows, "hair", corner=0.3, nc=1, sub=1, outline=0), "hair", a=0.46, b=0.5, g=0.1)
	bake(k, k.tube("Head", "FallEnd", [(0, 0.84, 2.6, 0.86, 0.22), (0, 0.84, 2.0, 0.86, 0.22)], "tip", corner=0.3, nc=1, sub=1, outline=0), "tip", a=0.48, b=0.5)
	# orange licking up into the black, lying flat on the fall
	for i, (x, z) in enumerate(((-0.62, 3.05), (-0.2, 3.3), (0.22, 3.0), (0.64, 3.25))):
		gem(k, "Head", f"Lick{i}", (x, 1.03, 2.5), (x, 1.05, z), 0.24, ramp="tip", flat=0.2, twist=0.1, across=(1, 0, 0))
	for i, x in enumerate((-0.66, -0.22, 0.22, 0.66)):
		gem(k, "Head", f"End{i}", (x, 0.84, 2.1), (x * 1.04, 0.86, 1.26 + 0.1 * (i % 2)), 0.28, ramp="tip", flat=0.55, twist=0.25, across=(1, 0, 0))
	for s in (1, -1):
		gem(k, "Head", f"BackSide{s}", (s * 0.8, 0.5, 5.1), (s * 0.94, 0.76, 3.8), 0.3, flat=0.6, twist=0.25, across=(0, 1, 0))


def _bow(k):
	"""The pink ribbon tied at the back of the head, viewer's right: two wide loops pinching in to a knot, two short ends."""
	c = (0.56, 1.02, 5.5)
	for i, (ox, oz) in enumerate(((0.56, 0.2), (-0.56, 0.14))):
		gem(k, "Head", f"Bow{i}", (c[0] + ox, c[1], c[2] + oz), c, 0.27, ramp="bow", flat=0.3, twist=0.05, a=0.58, b_=0.4, across=(0, 0, 1))
	for i, ox in enumerate((0.2, -0.16)):
		gem(k, "Head", f"BowEnd{i}", (c[0], c[1] + 0.02, c[2]), (c[0] + ox, c[1] + 0.04, c[2] - 0.46), 0.1, ramp="bow", flat=0.35, twist=0.1, a=0.5, b_=0.4, across=(1, 0, 0))
	block(k, "Head", "BowKnot", c[0], c[1] + 0.03, c[2] + 0.11, c[2] - 0.11, 0.11, 0.09, "bow", ch=0.03, corner=0.4, a=0.44, b=0.46)


def _bamboo(k):
	"""The bar across the mouth: an octagonal rod with raised nodes and red ties going round behind the head."""
	p = (0, -0.92, 4.32)
	for name, hw, z1, z0, ramp, a in (("Rod", 0.12, 0.92, -0.92, "green", 0.5), ("Node0", 0.14, 0.5, 0.42, "node", 0.55), ("Node1", 0.14, -0.42, -0.5, "node", 0.55), ("EndA", 0.125, 0.96, 0.9, "node", 0.6), ("EndB", 0.125, -0.9, -0.96, "node", 0.6)):
		block(k, "Head", name, p[0], p[1], p[2] + z1, p[2] + z0, hw, hw, ramp, ch=0.02, corner=0.42, rot=(p, 0, 90, 0), a=a, b=0.5)
	block(k, "Head", "Tie", 0, -0.02, 4.37, 4.29, 0.93, 0.87, "cord", ch=0.015, corner=0.3, a=0.56)
	for s in (1, -1):
		block(k, "Head", f"TieWrap{s}", s * 0.72, -0.94, 4.45, 4.19, 0.05, 0.145, "cord", ch=0.015, corner=0.4, a=0.6)


def _clothes(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.9, 0.42), (0, 0, 2.1, 0.9, 0.42)], corner=0.1, nc=1)
	art_uv(block(k, t, "Kimono", 0, 0, 3.98, 1.94, 1.0, 0.52, "pink", ch=0.04), "Torso_B")
	block(k, t, "Under", 0, 0, 4.16, 3.84, 0.62, 0.58, "white", ch=0.05, corner=0.3, a=0.6, b=0.36)
	# the crossed collar, closing high under the chin
	for s in (1, -1):
		block(k, t, f"Collar{s}", 0, -0.55, 4.14, 3.12, 0.09, 0.04, "white" if s > 0 else "pink", ch=0.015, rot=((0, -0.55, 3.12), 0, s * 24, 0), a=0.72, b=0.36)
	art_uv(block(k, t, "Obi", 0, 0, 2.84, 2.18, 1.03, 0.56, "pink", ch=0.03), "Torso_L", OBI)
	block(k, t, "ObiCord", 0, 0, 2.54, 2.46, 1.05, 0.58, "green", ch=0.015, a=0.6, b=0.4)
	block(k, t, "ObiKnot", 0, -0.6, 2.6, 2.4, 0.14, 0.05, "green", ch=0.02, corner=0.35, a=0.66, b=0.4)
	coat(k, "Torso_F", hem=1.36, cuff="pink")
	for s, side in ((1, "Left"), (-1, "Right")):
		leg, px = f"{side}UpperLeg", s * 0.53
		core_leg(k, side, s * 0.5)
		art_uv(block(k, leg, "KimonoL", px, 0, 1.98, 0.74, 0.51, 0.54, "pink", ch=0.03, flare=0.015), "Torso_B", dz=0.5)
		block(k, leg, "Wrap", px, 0, 0.8, 0.42, 0.48, 0.48, "white", ch=0.04, a=0.58, b=0.36)
		block(k, leg, "Tie", px, 0, 0.62, 0.56, 0.495, 0.495, "wrapline", ch=0.01, a=0.5)
		sandal(k, leg, px)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	_hair(k)
	_bow(k)
	_bamboo(k)
	_clothes(k)
	finish()


def _hemp_leaf(f):
	"""Pink with six-pointed leaf stars in a darker line."""
	studs(f, RECT)
	f.path(rect_d(-2, 0, 2, 5), "#f4a6be")
	r = 0.21
	dx, dz = r * math.sqrt(3), r * 1.5
	for j in range(0, 22):
		for i in range(-8, 9):
			cx, cz = i * dx + (dx / 2 if j % 2 else 0), j * dz + 0.8
			for n in range(6):
				an = math.pi / 6 + n * math.pi / 3
				f.path(f"M{cx:.3f} {cz:.3f}L{cx + r * math.cos(an):.3f} {cz + r * math.sin(an):.3f}", stroke="#d8688e", sw=0.014)
				bn = n * math.pi / 3
				f.path(f"M{cx:.3f} {cz:.3f}L{cx + r * 0.866 * math.cos(bn):.3f} {cz + r * 0.866 * math.sin(bn):.3f}", stroke="#e88aa8", sw=0.01)
			f.path("M" + "L".join(f"{cx + r * math.cos(math.pi / 6 + n * math.pi / 3):.3f} {cz + r * math.sin(math.pi / 6 + n * math.pi / 3):.3f}" for n in range(6)) + "Z", stroke="#d8688e", sw=0.014)
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	f.skin = SKIN
	f.fill(SKIN)
	f.soft("M-5-5H135V26Q65 32 -5 26Z", "#d8a486", 0.7, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.65, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.4, 3)
	for s, x in ((-1, 38), (1, 92)):
		# big, round, gentle: a tall pink iris, soft lashes
		eye(f, x, 62, s, ("#8f1f54", "#e0569a", "#ffb0d8"), w=33, up=17, dn=15, inner=7, outer=0, ir=(12.5, 16.5), pu=(3.4, 5), lash="#2a1420", wing=2.4, lid=0.22)
		# a soft thin brow
		ib, ob = 65 + s * 14, 65 + s * 42
		f.path(f"M{ib} 38Q{65 + s * 26} 34 {ob} 38Q{65 + s * 26} 37 {ib} 40Z", "#3a2a30")
	f.soft("M60 84L65 79L70 84Q65 88 60 84Z", SKIN_D, 0.55, 1)
	skin_head(a, SKIN, "#d8a486")
	checks(a["Torso_F"], 0.4, "#2e1512", "#8a3424")
	_hemp_leaf(a["Torso_B"])
	checks(a["Torso_L"], 0.2, "#e0782c", "#5a1f14", OBI)
