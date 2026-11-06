# Target look for saw_nervous "Kobene" (design doc section 5): dark brown hair with side-swept bangs and one long lock down the face, two red
# hair clips, two small tails at the nape, wide worried eyes with moles beside one of them, a black suit, white shirt and black tie.
# +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, big_head, block, crown, ears, face_base, finish, gem, head_rest, prism, slab, stroke
from saw_common import SKIN, SKIN_D, SUIT, back_sheets, collar, jacket, jacket_arm, paint_jacket, paint_limbs, ramps, side_strands, suit_leg, tie

DEFAULT = SUIT
HAIR_D = "#2a1812"
HAIR_MID = "#3a2219"
R = ramps(["#170c08", "#27160f", "#3a2219", "#553428", "#785040"], clip=["#7c1414", "#b82222", "#e23c3c", "#ff7a70"])
HAIR = {"colour": "#3A2219", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(0.98, 5.4), (1.04, 5.62), (0.96, 5.88), (0.6, 6.06), (0.16, 6.12)])
	block(k, "Head", "Back", 0, 0.3, 5.5, 4.32, 0.96, 0.58, "hair", ch=0.06, corner=0.3, jit=0.02, sub=1, mids=(4.9,), a=0.42, b=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.8, 5.42), (-0.8, 5.0), (-0.5, 4.5), (0.1, 4.34), (0.86, 4.34), (0.86, 5.42)], s * 0.84, s * 1.0, "hair", a=0.52, b=0.34)
		# the small tails, low behind the ears
		gem(k, "Head", f"Tail{s}", (s * 0.72, 0.62, 4.62), (s * 1.28, 0.82, 3.98), 0.24, flat=0.6, twist=0.25, a=0.46)
		block(k, "Head", f"Tie{s}", s * 0.8, 0.66, 4.62, 4.46, 0.11, 0.11, "clip", ch=0.02, a=0.5, b=0.4)
	side_strands(k, 4.3, ys=(0.14, 0.54))
	back_sheets(k, 4.26)
	# the bangs sweep from a part on the viewer's right across to the left, and one long lock runs on past the jaw
	root = (0.42, -0.76, 5.82)
	for i, (t, r) in enumerate((((-0.86, -0.94, 4.86), 0.27), ((-0.52, -0.96, 4.98), 0.25), ((-0.18, -0.97, 5.06), 0.23), ((0.12, -0.96, 5.08), 0.2))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.12 * i, a=0.5, across=(0, 0, 1))
	gem(k, "Head", "BangRight", root, (0.92, -0.92, 4.72), 0.27, flat=0.42, twist=0.3, a=0.5, across=(0, 0, 1))
	gem(k, "Head", "LongLock", (-0.82, -0.7, 5.42), (-0.9, -0.78, 3.72), 0.23, flat=0.4, twist=0.2, across=(1, 0, 0), a=0.5)
	for i, (t, r) in enumerate((((-1.02, 0.1, 5.3), 0.3), ((-0.8, 0.74, 5.36), 0.3), ((0.86, 0.74, 5.36), 0.3), ((1.04, 0.1, 5.34), 0.3))):
		gem(k, "Head", f"Clump{i}", (0.2, 0.06, 5.92), t, r, flat=0.5, twist=0.3, a=0.46)


def _clips(k):
	"""Two straight red hair clips, side by side above the temple."""
	for i, x in enumerate((0.42, 0.68)):
		pts = [(x - 0.05, 5.6), (x + 0.07, 5.6), (x + 0.18, 5.14), (x + 0.06, 5.14)]
		prism(k, "Head", f"Clip{i}", pts, -1.08, -1.0, "clip", a=0.62, b=0.34)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.7)
	_hair(k)
	_clips(k)
	jacket(k)
	collar(k)
	tie(k, end=2.96)
	for s, side in ((1, "Left"), (-1, "Right")):
		jacket_arm(k, side, s)
		suit_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f09088", top=24)
	# round wet eyes with too much white, brows climbing at the inner end
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 66, s, 34, 16, "#54342a", tilt=-1.6, r=10.5, lash="#1c100c", lash_t=2.8, flick=1.5, pupil=0.45, sclera="#fffdf8", crease_line=False)
		brow2(f, x, 42, s, 28, 3.2, -4.6, "#3a2219", arc=-1.0)
	# the moles under one eye and by the mouth
	for x, y in ((107, 83), (112, 87), (88, 107)):
		f.path(f"M{x - 1.2} {y}a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0Z", "#2a1610")
	nose(f, SKIN, y=78, h=11)
	# a small wavering mouth
	stroke(f, "M52 107Q58 102 64 106T78 104", "#4a1e1a", 2.2)
	# one bead of sweat
	f.path("M118 44Q124 54 118 58Q112 54 118 44Z", "#b8e2f6", stroke="#6aa8cc", sw=0.7)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	for n in ("Head_L", "Head_R"):
		a[n].path("M-5-5H125V32H-5Z", HAIR_MID)
	a["Head_T"].fill(HAIR_D)
	paint_jacket(a)
	paint_limbs(a)
