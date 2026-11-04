# Target look for leaf_crow (design doc section 5): big head, long black centre-parted bangs and a low ponytail, slashed plate, two lines
# under the eyes, ankle-long high-collared black cloak lined in red, lobed red clouds edged in white, open-toe sandals.
from leaf_style3 import bake, block, cloud, dark_eye, gem, hand, head_sides, jitter, paint_plate, plate, sandal, shard, skin_face, stroke, true_face_uv
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f5dccb"
SKIN_D = "#d4ac94"
DEFAULT = "#141414"
R = Ramps(
	hair=["#08080c", "#14141c", "#23232f", "#3a3a4c", "#5c5c74"],
	skin=["#c49a84", "#e8c2ac", "#f5dccb", "#ffeee0"],
	cloak=["#0c0c10", "#141418", "#1e1e25", "#2f2f39", "#47474f"],
	lining=["#5e0c14", "#8c141e", "#b01e28", "#cc3038"],
	red=["#8c1018", "#b01e28", "#cc2a32", "#e04048"],
	white=["#b4b4bc", "#dcdce2", "#f4f4f8", "#ffffff"],
	band=["#0a0a10", "#16161e", "#262630"],
	pants=["#121216", "#1e1e24", "#2a2a32", "#40404a"],
	sole=["#0b0a0e", "#19171d", "#2b2830", "#3d3a44"],
	steel=["#59606c", "#8f96a2", "#c2c8d0", "#eef1f4"],
)
HAIR = {"colour": "#1A1A22", "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.4, 0.6), (0, 0, 4.16, 0.68, 0.78), (0, 0, 4.46, 0.86, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
# the hair lies flat against the head and collects at the nape
TIE = (0, 0.86, 4.46)


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.9, 5.3, 0.5), (0.98, 5.54, 0.5), (0.92, 5.86, 0.5), (0.54, 6.1, 0.5), (0.14, 6.16, 0.5)], "hair", n=10, at=(0, 0.05, 0), squash=0.97, outline=0)
	bake(k, dome, "hair", a=0.42, b=0.42)
	nape = k.tube("Head", "Nape", [(0, 0.38, 5.66, 0.9, 0.52), (0, 0.38, 5.34, 0.97, 0.56), (0, 0.38, 4.8, 0.96, 0.54), (0, 0.42, 4.3, 0.9, 0.48)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.02)
	bake(k, nape, "hair", a=0.38, b=0.4)
	# a cap of hair over the head's upper corners, down to the band's top edge
	block(k, "Head", "Cap", 0, 0, 5.74, 5.42, 0.935, 0.87, "hair", ch=0.05, corner=0.2, jit=0.015, a=0.36, b=0.4)
	for s in (1, -1):
		# the parting: broad flat locks running from the crown out and down, each a clear plane
		shard(k, f"TopF{s}", ((s * 0.04, -0.72, 6.02, 0.2), (s * 0.42, -0.9, 5.84, 0.34), (s * 0.8, -0.86, 5.46, 0.3), (s * 0.94, -0.82, 5.14, 0.01)), a=0.46, b_=0.66)
		shard(k, f"TopM{s}", ((s * 0.04, -0.2, 6.14, 0.26), (s * 0.46, -0.24, 6.02, 0.36), (s * 0.84, -0.2, 5.56, 0.3), (s * 0.98, -0.18, 5.0, 0.01)), a=0.42, b_=0.66)
		shard(k, f"TopB{s}", ((s * 0.04, 0.4, 6.1, 0.26), (s * 0.44, 0.5, 5.94, 0.34), (s * 0.76, 0.66, 5.4, 0.3), (s * 0.3, 0.92, 4.5, 0.01)), a=0.38, b_=0.66)
		shard(k, f"Back{s}", ((s * 0.1, 0.76, 5.9, 0.28), (s * 0.34, 1.0, 5.4, 0.34), (s * 0.24, 1.0, 4.9, 0.26), (s * 0.04, 0.92, 4.46, 0.01)), a=0.36, b_=0.66)
		# the long bangs: outside the plate, past the cheek, to a point at the jaw; a shorter lock behind
		shard(k, f"Bang{s}", ((s * 0.3, -0.92, 5.8, 0.14), (s * 0.68, -1.02, 5.46, 0.25), (s * 0.82, -1.03, 4.9, 0.24), (s * 0.84, -0.99, 4.3, 0.17), (s * 0.76, -0.95, 3.84, 0.01)), a=0.48, b_=0.68)
		shard(k, f"Side{s}", ((s * 0.8, -0.46, 5.5, 0.24), (s * 0.94, -0.5, 5.0, 0.24), (s * 0.95, -0.46, 4.56, 0.18), (s * 0.9, -0.42, 4.14, 0.01)), a=0.34, b_=0.64)
		shard(k, f"SideB{s}", ((s * 0.82, 0.0, 5.44, 0.26), (s * 0.96, 0.04, 5.0, 0.28), (s * 0.96, 0.08, 4.62, 0.2), (s * 0.9, 0.12, 4.34, 0.01)), a=0.32, b_=0.64)
	# the low ponytail, a single long clump down the back, its tie a dark ring
	block(k, "Head", "Tie", TIE[0], TIE[1] + 0.04, TIE[2] + 0.1, TIE[2] - 0.06, 0.2, 0.17, "band", ch=0.03, corner=0.3, sub=1, a=0.6, b=0.5)
	shard(k, "Tail", ((0, TIE[1] + 0.06, TIE[2], 0.2), (0.0, TIE[1] + 0.2, 4.1, 0.27), (0.03, TIE[1] + 0.24, 3.6, 0.24), (0.0, TIE[1] + 0.2, 3.12, 0.01)), a=0.44, b_=0.7, flat=0.7, centre=(0, 0, 3.8))


def _band(k):
	block(k, "Head", "Band", 0, 0, 5.46, 5.04, 0.955, 0.885, "band", ch=0.03, corner=0.24, a=0.5, b=0.36)
	plate(k, hw=0.56)


def _cloak_top(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, t, "Cloak", 0, 0, 3.98, 1.88, 1.08, 0.6, "cloak", ch=0.07, flare=0.03, jit=0.025, sub=1, mids=(3.3, 2.6), a=0.4, b=0.6, g=0.14, tone=0.04)
	# the closure down the front
	block(k, t, "Closure", 0, -0.63, 3.9, 1.88, 0.022, 0.02, "cloak", ch=0.006, a=0.02, b=0.04, g=0.0)
	# the high collar, red inside, open at the front round the chin
	def rise(a):
		f = max(0.0, 1 - abs((a + 90) if a < 90 else (a - 270)) / 62)
		return (-0.06, 0.58 - 0.3 * f)

	inner = k.band(t, "Lining", (0, 0.0, 3.94), 0.9, 0.86, -70, 250, rise, "lining", thick=0.04, e=0.58, n=20, flare=0.03, outline=0)
	bake(k, inner, "lining", a=0.5, b=0.3)
	outer = k.band(t, "Collar", (0, 0.0, 3.94), 0.95, 0.91, -70, 250, rise, "cloak", thick=0.09, e=0.58, n=20, flare=0.03, outline=0)
	bake(k, outer, "cloak", a=0.42, b=0.6)
	# the neck in the opening
	block(k, t, "Neck", 0, -0.02, 4.12, 3.9, 0.46, 0.42, "skin", ch=0.02, a=0.3, b=0.1, g=0.0)
	# the red lining folds out at the opening
	for s in (1, -1):
		verts = []
		for y in (-0.6, -0.66):
			verts += [(s * 0.42, y, 4.16), (s * 0.02, y, 3.5), (s * 0.3, y, 3.72), (s * 0.68, y, 4.0)]
		faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
		bake(k, k._mesh(f"Fold{s}", t, verts, faces, (), 0), "lining", a=0.56, b=0.3)
	# the clouds: one high on the chest, one large on the back with two smaller
	cloud(k, t, "CloudChest", (0.46, -0.63, 3.14), rx=0.4)
	cloud(k, t, "CloudBack", (-0.42, 0.63, 2.66), rx=0.5, facing="back")
	cloud(k, t, "CloudBackB", (0.56, 0.63, 3.42), rx=0.36, facing="back")


def _arm(k, s, side):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 4.04, 2.5, 0.53, 0.53, "cloak", ch=0.09, flare=0.05, corner=0.18, jit=0.025, sub=1, mids=(3.5, 3.0), a=0.4, b=0.62, g=0.1, tone=0.03)
	block(k, arm, "Cuff", ax, 0, 2.56, 2.42, 0.6, 0.6, "cloak", ch=0.03, corner=0.18, a=0.58, b=0.56)
	hand(k, arm, ax)
	cloud(k, arm, f"CloudArm{s}", (ax + s * 0.56, 0, 3.3), rx=0.34, facing="left" if s > 0 else "right")
	if s < 0:
		cloud(k, arm, "CloudArmF", (ax, -0.565, 3.5), rx=0.3)


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	x = s * 0.5
	px = s * 0.55
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	# the dark trouser under the hem
	block(k, leg, "Pants", px, 0, 1.2, 0.5, 0.48, 0.52, "pants", ch=0.03, a=0.42, b=0.5)
	# each half of the skirt follows its leg, with a split between them
	block(k, leg, "Skirt", px, 0, 1.95, 0.5, 0.545, 0.61, "cloak", ch=0.05, flare=0.05, corner=0.14, jit=0.03, mids=(1.45, 0.98), a=0.4, b=0.62, g=0.16, tone=0.04)
	sandal(k, leg, px, "pants", "sole", top=0.6)
	if s > 0:
		cloud(k, leg, "CloudLeg", (px + 0.04, -0.655, 1.02), rx=0.36)
		cloud(k, leg, "CloudLegB", (px, 0.65, 1.3), rx=0.36, facing="back")
	else:
		cloud(k, leg, "CloudLeg", (px - 0.04, 0.65, 0.92), rx=0.32, facing="back")


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	true_face_uv(parts["Head"])
	_hair(k)
	_band(k)
	_cloak_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, top=35)
	for s, x in ((-1, 38), (1, 92)):
		dark_eye(f, x, 62, s, w=30, up=10, dn=7, tilt=5, iris=9.5, heavy=3, lid=0.36)
		# calm level brows
		ib, ob = 65 + s * 11, 65 + s * 41
		f.path(f"M{ib} 46Q{65 + s * 26} 41 {ob} 42L{ob} 44.5Q{65 + s * 26} 44 {ib} 48.5Z", "#1c1c24")
		# the two long lines from the inner eye down the cheek, the likeness's anchor
		stroke(f, ((x - s * 9, 70), (x - s * 8.5, 80), (x - s * 7, 92)), 1.25, "#6a4a4a")
	stroke(f, ((66, 78), (67, 88), (65, 91)), 0.8, "#c49a84")
	f.path("M57 108Q65 106.5 73 108", stroke="#7c4f46", sw=1.4)
	paint_plate(a["Head_B"], SKIN, slash=True)
	head_sides(a, SKIN, SKIN_D)
