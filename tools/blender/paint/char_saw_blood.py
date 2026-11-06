# Target look for saw_blood "Powah" (design doc section 5): long pale strawberry-blonde hair to the mid back, a lock across the face, two short red
# horns, red eyes with a cross for a pupil, a wide grin of jagged teeth, a white shirt worn untucked, a loose black tie and dark trousers.
# +X is the viewer's right in the front view. Drawn in-house.
from atlas import shade
from jk_common import brow2, eye2, nose
from jk_style3 import Kit, big_head, block, crown, face_base, finish, gem, head_rest, jitter, bake, slab
from saw_common import SKIN, SKIN_D, SHIRT, back_sheets, collar, jagged_mouth, paint_limbs, paint_shirt, ramps, shirt_arm, shirt_body, side_strands, suit_leg, tie

DEFAULT = SHIRT
HAIR_D = "#b58a5c"
R = ramps(["#a67c54", "#cfa374", "#ebc78f", "#f6dcae", "#fff0d0"], horn=["#6e0d10", "#a81a1a", "#dc2c26", "#ff6a52"])
HAIR = {"colour": "#EBC78F", "locks": []}
PROPS = []


def _hair(k):
	crown(k, [(1.0, 5.44), (1.06, 5.66), (0.97, 5.92), (0.58, 6.12), (0.16, 6.2)])
	mass = k.tube("Head", "Mass", [(0, 0.2, 5.72, 0.92, 0.8), (0, 0.36, 5.42, 1.06, 0.72), (0, 0.5, 4.6, 1.06, 0.58), (0, 0.56, 4.2, 1.0, 0.5)], "hair", corner=0.3, nc=1, sub=1, outline=0)
	jitter(mass, 0.015)
	bake(mass, "hair", k, a=0.44, b=0.42)
	block(k, "Head", "Fall", 0, 0.8, 4.3, 2.9, 0.96, 0.25, "hair", ch=0.05, corner=0.3, jit=0.02, sub=1, mids=(3.5,), a=0.42, b=0.42, g=0.14)
	for i, (x, z1) in enumerate(((-0.74, 2.62), (-0.36, 2.46), (0.0, 2.4), (0.36, 2.48), (0.74, 2.64))):
		gem(k, "Head", f"End{i}", (x, 0.82, 3.3), (x, 0.88, z1), 0.26, flat=0.5, twist=0.2 + 0.1 * i, across=(1, 0, 0), a=0.42)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.84, 5.46), (-0.84, 5.0), (-0.66, 4.4), (-0.4, 4.1), (0.2, 4.07), (0.9, 4.07), (0.9, 5.46)], s * 0.84, s * 1.04, "hair", a=0.52, b=0.34)
		# the locks down the front, breaking over the collar
		gem(k, "Head", f"Lock{s}", (s * 0.88, -0.6, 5.5), (s * 0.98, -0.72, 3.3), 0.3, flat=0.42, twist=0.2, across=(1, 0, 0), a=0.52)
		gem(k, "Head", f"BangOut{s}", (s * 0.46, -0.84, 5.6), (s * 0.94, -0.94, 4.76), 0.3, flat=0.42, twist=0.3, a=0.5, across=(0, 0, 1))
	side_strands(k, 3.98, ys=(-0.2, 0.26, 0.66))
	back_sheets(k, 2.84, y=1.0)
	# the bangs part on the viewer's left and one long lock falls between the eyes
	root = (-0.12, -0.76, 5.84)
	for i, (t, r) in enumerate((((-0.62, -0.95, 5.06), 0.24), ((-0.34, -0.96, 5.18), 0.2), ((0.48, -0.95, 5.1), 0.26), ((0.72, -0.95, 4.96), 0.24))):
		gem(k, "Head", f"Bang{i}", root, t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.52, across=(0, 0, 1))
	gem(k, "Head", "FaceLock", root, (0.16, -1.0, 4.56), 0.2, flat=0.4, twist=0.25, a=0.56, across=(0, 0, 1))
	for s in (1, -1):
		for i, (t, r) in enumerate((((s * 1.1, -0.1, 5.42), 0.3), ((s * 1.0, 0.72, 5.36), 0.3))):
			gem(k, "Head", f"Clump{s}{i}", (s * 0.08, 0.06, 5.94), t, r, flat=0.5, twist=0.3, a=0.5)


def _horns(k):
	"""Two short straight horns out of the hair, a little apart and leaning out."""
	for s in (1, -1):
		gem(k, "Head", f"Horn{s}", (s * 0.42, -0.3, 5.95), (s * 0.6, -0.38, 6.56), 0.23, ramp="horn", flat=0.95, twist=0.2, a=0.56)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_horns(k)
	shirt_body(k, hem=1.86)
	collar(k)
	tie(k, end=2.58, dx=0.1)
	for s, side in ((1, "Left"), (-1, "Right")):
		shirt_arm(k, side, s)
		suit_leg(k, side, s)
	finish()


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#f09088", top=22)
	for s, x in ((-1, 39), (1, 91)):
		eye2(f, x, 62, s, 37, 16, "#e0301e", tilt=3.2, r=12, lash="#3c1a12", lash_t=3.4, flick=3, pupil=0.2, sclera="#fff6e8", crease_line=False)
		# the cross pupil, and the bright ring inside the iris
		f.path(f"M{x - 8} 62a8 8.6 0 1 0 16 0a8 8.6 0 1 0 -16 0Z", stroke="#ffb042", sw=1.8)
		f.path(f"M{x - 6} 62H{x + 6}M{x} 55.5V68.5", stroke="#2a0606", sw=2.4)
		brow2(f, x, 42, s, 30, 3.0, 3.2, "#c49a68", arc=-1.5)
		f.path(f"M{x - 13} 84Q{x} 88 {x + 13} 84", stroke=SKIN_D, sw=1.0, opacity=0.5)
	nose(f, SKIN, y=78, h=9)
	jagged_mouth(f, 40, 92, 96, 22, teeth=7)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.62))
	a["Head_Bo"].fill(SKIN_D)
	a["Head_T"].fill(HAIR_D)
	paint_shirt(a)
	paint_limbs(a, SHIRT)
