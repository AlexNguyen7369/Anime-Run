# Target look for saw_fox "Akki" (design doc section 5): near-black hair pulled back into a neat high topknot, loose locks framing the
# face, calm blue eyes, a red stud in the ear, a black suit, white shirt and black tie. +X is the viewer's right in the front
# view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, bake, big_head, block, ears, face_base, finish, gem, head_rest, jitter, slab
from saw_common import SKIN, SKIN_D, SUIT, collar, jacket, jacket_arm, paint_jacket, paint_limbs, ramps, suit_leg, tie

DEFAULT = SUIT
# The portrait step lifts darks and adds its own blue (render_portrait grade), so the ramp stays almost neutral.
HAIR_D = "#0d0d0f"
HAIR_MID = "#191a1c"
R = ramps(["#0c0c0e", "#131315", "#191a1c", "#1f2024", "#24252b"], band=["#22232a", "#33343c", "#484a54", "#60626e"], stud=["#7c1414", "#b82222", "#e23c3c", "#ff7a70"])
HAIR = {"colour": "#191A1C", "locks": []}
PROPS = []


def _hair(k):
	"""Close to the skull, nothing wider than it needs to be: a thin shell, a back pulled tight to the nape, a side hairline that leaves the ear out."""
	shell = k.tube("Head", "Shell", [(0, 0.02, 5.2, 0.955, 0.875), (0, 0.02, 5.62, 0.965, 0.885), (0, 0.03, 5.84, 0.84, 0.77), (0, 0.06, 5.98, 0.54, 0.5), (0, 0.1, 6.04, 0.2, 0.2)], "hair", corner=0.2, nc=1, sub=1, outline=0)
	jitter(shell, 0.008)
	bake(shell, "hair", k, a=0.42, b=0.32)
	slab(k, "Back", [(-0.1, 5.3), (-0.1, 4.96), (0.14, 4.72), (0.5, 4.5), (0.885, 4.56), (0.885, 5.3)], -0.955, 0.955, "hair", a=0.42, b=0.36)
	_topknot(k)
	# loose locks framing the face: two long ones outside the eyes, a few short ones breaking up the forehead
	locks = (
		((-0.42, -0.88, 5.6), (-0.84, -0.93, 4.36), 0.21),
		((0.44, -0.88, 5.6), (0.84, -0.93, 4.4), 0.21),
		((-0.2, -0.89, 5.64), (-0.62, -0.94, 5.0), 0.17),
		((0.28, -0.89, 5.64), (0.62, -0.94, 5.02), 0.17),
		((0.02, -0.89, 5.66), (-0.2, -0.94, 5.06), 0.13),
		((0.1, -0.89, 5.66), (0.3, -0.94, 5.14), 0.11),
	)
	for i, (root, tip, r) in enumerate(locks):
		gem(k, "Head", f"Lock{i}", root, tip, r, flat=0.36, twist=0.18 + 0.1 * i, across=(1, 0, 0), a=0.54, b_=0.5)
	for s in (1, -1):
		gem(k, "Head", f"Temple{s}", (s * 0.7, -0.87, 5.5), (s * 0.93, -0.9, 4.72), 0.17, flat=0.36, twist=0.25, across=(1, 0, 0), a=0.5, b_=0.4)
		gem(k, "Head", f"Burn{s}", (s * 0.93, -0.24, 5.26), (s * 0.97, -0.26, 4.62), 0.14, flat=0.4, twist=0.2, across=(0, 1, 0), a=0.5, b_=0.5)


def _topknot(k):
	"""High and neat: pinched at the tie, a short compact tail that leans back a little and closes to a blunt point."""
	block(k, "Head", "KnotBase", 0, 0.14, 6.1, 5.94, 0.25, 0.24, "hair", ch=0.05, corner=0.3, a=0.46, b=0.4)
	block(k, "Head", "KnotTie", 0, 0.15, 6.22, 6.08, 0.19, 0.19, "band", ch=0.02, corner=0.3, a=0.6, b=0.36)
	tail = k.tube("Head", "KnotTail", [(0, 0.15, 6.18, 0.13, 0.13), (0, 0.16, 6.3, 0.17, 0.16), (0, 0.19, 6.56, 0.21, 0.18), (0, 0.21, 6.68, 0.13, 0.12)], "hair", corner=0.3, nc=1, sub=1, outline=0)
	jitter(tail, 0.01)
	bake(tail, "hair", k, a=0.44, b=0.3)
	# the cut end: a short brush of tips, so it reads as hair and not a bulb
	for i, (x, y, z, r) in enumerate(((-0.17, 0.27, 6.9, 0.11), (0.0, 0.2, 7.04, 0.12), (0.16, 0.28, 6.92, 0.11), (0.02, 0.36, 6.88, 0.1))):
		gem(k, "Head", f"KnotTip{i}", (x * 0.4, 0.19, 6.5), (x, y, z), r, flat=0.75, twist=0.25 + 0.1 * i, a=0.44, b_=0.36)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	ears(k, z=4.74)
	block(k, "Head", "Stud", 0.99, 0.02, 4.64, 4.54, 0.035, 0.05, "stud", ch=0.01, a=0.62, b=0.3)
	_hair(k)
	jacket(k)
	collar(k)
	tie(k, end=2.96)
	for s, side in ((1, "Left"), (-1, "Right")):
		jacket_arm(k, side, s)
		suit_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#e8b8a4", top=26)
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 66, s, 35, 12, "#3f7fc4", tilt=1.8, r=10, lid=0.22, lash="#0c0d10", lash_t=3.2, flick=2.2, pupil=0.44, sclera="#f6f4ee", crease_line=False)
		brow2(f, x, 49, s, 31, 3.2, 1.2, "#101114", arc=-1.0)
		f.path(f"M{x - 13} 82Q{x} 86 {x + 13} 82", stroke=SKIN_D, sw=1.0, opacity=0.5)
	nose(f, SKIN, y=76, h=13)
	f.path("M52 106Q65 104 78 106", stroke="#4a221c", sw=2.2)
	f.path("M58 113Q65 114 72 113", stroke=SKIN_D, sw=1.1, opacity=0.9)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_T"].fill(HAIR_D)
	paint_jacket(a)
	paint_limbs(a)
