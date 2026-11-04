# Target look for foe_leaf (design doc section 5, 4.26): big head, wild spiky orange hair off a bare forehead, ringed lilac eyes with a blank stare,
# steel studs and bars across the nose, spike studs under the lip, a bar through each ear, ankle-long high-collared black cloak lined in red, 3-lobe clouds.
import math

from atlas import shade
from leaf_common import begin_clip, ell, end_clip
from leaf_style3 import bake, block, cloud, gem, hand, sandal, shard, skin_face, stroke, true_face_uv
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f2d8c4"
SKIN_D = "#d0a88f"
HAIR_C = "#e8791e"
HAIR_D = "#a84a0e"
DEFAULT = "#141418"
R = Ramps(
	hair=["#8a3a08", "#b9560f", "#e8791e", "#f89a3a", "#ffc272"],
	skin=["#c09880", "#e6c2aa", "#f2d8c4", "#ffecdc"],
	cloak=["#0c0c10", "#141418", "#1e1e25", "#2f2f39", "#47474f"],
	lining=["#5e0c14", "#8c141e", "#b01e28", "#cc3038"],
	red=["#8c1018", "#b01e28", "#cc2a32", "#e04048"],
	white=["#b4b4bc", "#dcdce2", "#f4f4f8", "#ffffff"],
	pants=["#121216", "#1e1e24", "#2a2a32", "#40404a"],
	sole=["#0b0a0e", "#19171d", "#2b2830", "#3d3a44"],
	steel=["#4a505c", "#7c8490", "#b4bac4", "#f0f3f6"],
)
HAIR = {"colour": HAIR_C, "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.44, 0.6), (0, 0, 4.16, 0.7, 0.78), (0, 0, 4.46, 0.88, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
# az: 0 front, 90 viewer's right, 180 back; el: degrees above level; length, half width. Uneven on purpose: this hair is wild, not a crown.
SPIKES = (
	# the top, standing up
	(20, 82, 0.62, 0.26), (130, 80, 0.7, 0.28), (250, 78, 0.56, 0.26),
	# the upper ring, thrown out and up
	(38, 50, 0.72, 0.34), (84, 42, 0.8, 0.36), (136, 40, 0.84, 0.36), (182, 46, 0.8, 0.36), (228, 36, 0.82, 0.36), (276, 46, 0.76, 0.36), (322, 52, 0.68, 0.34),
	# between them, filling the dome's shoulder
	(60, 24, 0.7, 0.32), (110, 26, 0.72, 0.34), (160, 22, 0.74, 0.34), (205, 24, 0.72, 0.34), (250, 22, 0.72, 0.34), (300, 26, 0.68, 0.32),
	# the lower ring, nearly level at the sides and falling at the back
	(70, 12, 0.56, 0.26), (112, 4, 0.62, 0.27), (152, -14, 0.64, 0.28), (208, -18, 0.62, 0.28), (248, 2, 0.6, 0.27), (292, 14, 0.54, 0.26),
)


def _spike(k, i, az, el, length, w):
	a, e = math.radians(az), math.radians(el)
	dx, dy, dz = math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)
	# the root sits inside the crown, so no gap shows at any angle
	x0, y0, z0 = 0.66 * dx, 0.03 + 0.62 * dy, 5.56 + 0.3 * dz
	pts = []
	for t, wide in ((0.0, 0.9), (0.42, 1.0), (0.72, 0.62), (1.0, 0.01)):
		pts.append((x0 + dx * length * t, y0 + dy * length * t, z0 + dz * length * t - 0.06 * t * t, w * wide))
	shard(k, f"Spike{i}", pts, a=0.46 + 0.05 * (i % 2), b_=0.5, centre=(0, 0.03, 5.3))


def _hair(k):
	crown = k.lathe("Head", "Crown", [(0.94, 5.26, 0.5), (0.96, 5.46, 0.5), (0.84, 5.7, 0.5), (0.5, 5.92, 0.5), (0.14, 6.0, 0.5)], "hair", n=10, at=(0, 0.04, 0), squash=0.97, outline=0)
	bake(k, crown, "hair", a=0.42, b=0.42)
	# the back of the head, ending above the collar; the sides stay bare in front of it
	nape = k.tube("Head", "Nape", [(0, 0.44, 5.64, 0.72, 0.42), (0, 0.46, 5.4, 0.92, 0.43), (0, 0.46, 4.8, 0.92, 0.43), (0, 0.42, 4.5, 0.78, 0.38)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	bake(k, nape, "hair", a=0.4, b=0.42)
	for i, sp in enumerate(SPIKES):
		_spike(k, i, *sp)
	for s in (1, -1):
		# the forehead stays bare: short tufts lift off the hairline and only the outer ones drop past the temple
		shard(k, f"Front{s}", ((s * 0.16, -0.78, 5.52, 0.2), (s * 0.3, -0.98, 5.44, 0.24), (s * 0.36, -1.08, 5.56, 0.16), (s * 0.42, -1.14, 5.8, 0.01)), a=0.5, b_=0.56)
		shard(k, f"Fringe{s}", ((s * 0.5, -0.78, 5.52, 0.2), (s * 0.66, -0.97, 5.4, 0.2), (s * 0.72, -0.97, 5.26, 0.13), (s * 0.76, -0.92, 5.1, 0.01)), a=0.48, b_=0.6)
		shard(k, f"Temple{s}", ((s * 0.78, -0.56, 5.46, 0.16), (s * 0.97, -0.66, 5.2, 0.17), (s * 0.99, -0.64, 5.02, 0.11), (s * 0.97, -0.56, 4.84, 0.01)), a=0.42, b_=0.6)
		# the side falls short, stopping above the ear, with a lock behind it
		shard(k, f"Side{s}", ((s * 0.86, -0.1, 5.36, 0.22), (s * 1.02, -0.1, 5.1, 0.24), (s * 1.0, -0.06, 4.94, 0.15), (s * 0.97, 0.0, 4.78, 0.01)), a=0.38, b_=0.6)
		shard(k, f"SideB{s}", ((s * 0.86, 0.3, 5.3, 0.24), (s * 1.04, 0.36, 5.0, 0.26), (s * 1.04, 0.42, 4.8, 0.17), (s * 1.02, 0.5, 4.6, 0.01)), a=0.36, b_=0.6)
		shard(k, f"Back{s}", ((s * 0.34, 0.8, 5.2, 0.28), (s * 0.44, 1.02, 4.86, 0.28), (s * 0.42, 1.04, 4.66, 0.18), (s * 0.38, 1.04, 4.58, 0.01)), a=0.36, b_=0.6)


def _piercings(k):
	# three bars across the upper nose, a stud at each end
	for i, z in enumerate((4.66, 4.58, 4.5)):
		block(k, "Head", f"NoseBar{i}", 0, -0.835, z + 0.008, z - 0.008, 0.085, 0.012, "steel", ch=0.004, corner=0.2, a=0.56, b=0.3, g=0.0)
		for s in (1, -1):
			block(k, "Head", f"NoseStud{i}{s}", s * 0.095, -0.838, z + 0.026, z - 0.026, 0.026, 0.024, "steel", ch=0.01, corner=0.3, a=0.6, b=0.38, g=0.0)
	for s in (1, -1):
		# a spike stud at each end of the lower lip
		gem(k, "Head", f"LipStud{s}", (s * 0.14, -0.76, 4.17), (s * 0.14, -0.92, 4.15), 0.038, ramp="steel", flat=1.0, a=0.6, b_=0.4)
		# the ear, in front of the hair, a bar through it
		block(k, "Head", f"Ear{s}", s * 0.92, -0.2, 4.86, 4.44, 0.06, 0.13, "skin", ch=0.025, corner=0.25, a=0.52, b=0.3, g=0.0)
		block(k, "Head", f"EarBar{s}", s * 0.97, -0.2, 4.72, 4.68, 0.022, 0.2, "steel", ch=0.006, corner=0.3, a=0.56, b=0.34, g=0.0)
		for y in (-0.41, 0.01):
			block(k, "Head", f"EarStud{s}{y}", s * 0.97, y, 4.74, 4.66, 0.04, 0.03, "steel", ch=0.012, corner=0.3, a=0.62, b=0.36, g=0.0)


def _cloak_top(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, t, "Cloak", 0, 0, 3.98, 1.88, 1.08, 0.6, "cloak", ch=0.07, flare=0.03, jit=0.025, sub=1, mids=(3.3, 2.6), a=0.4, b=0.6, g=0.14, tone=0.04)
	block(k, t, "Closure", 0, -0.63, 3.9, 1.88, 0.022, 0.02, "cloak", ch=0.006, a=0.02, b=0.04, g=0.0)

	# the high collar, red inside, open at the front round the chin
	def rise(a):
		f = max(0.0, 1 - abs((a + 90) if a < 90 else (a - 270)) / 62)
		return (-0.06, 0.62 - 0.3 * f)

	bake(k, k.band(t, "Lining", (0, 0.0, 3.94), 0.9, 0.86, -70, 250, rise, "lining", thick=0.04, e=0.58, n=20, flare=0.03, outline=0), "lining", a=0.5, b=0.3)
	bake(k, k.band(t, "Collar", (0, 0.0, 3.94), 0.95, 0.91, -70, 250, rise, "cloak", thick=0.09, e=0.58, n=20, flare=0.03, outline=0), "cloak", a=0.42, b=0.6)
	block(k, t, "Neck", 0, -0.02, 4.12, 3.9, 0.46, 0.42, "skin", ch=0.02, a=0.3, b=0.1, g=0.0)
	for s in (1, -1):
		verts = []
		for y in (-0.6, -0.66):
			verts += [(s * 0.42, y, 4.16), (s * 0.02, y, 3.5), (s * 0.3, y, 3.72), (s * 0.68, y, 4.0)]
		faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
		bake(k, k._mesh(f"Fold{s}", t, verts, faces, (), 0), "lining", a=0.56, b=0.3)
	cloud(k, t, "CloudChest", (-0.48, -0.63, 3.1), rx=0.4)
	cloud(k, t, "CloudChestB", (0.54, -0.63, 2.46), rx=0.34)
	cloud(k, t, "CloudBack", (0.36, 0.63, 2.7), rx=0.52, facing="back")
	cloud(k, t, "CloudBackB", (-0.54, 0.63, 3.4), rx=0.36, facing="back")


def _arm(k, s, side):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 4.04, 2.5, 0.53, 0.53, "cloak", ch=0.09, flare=0.05, corner=0.18, jit=0.025, sub=1, mids=(3.5, 3.0), a=0.4, b=0.62, g=0.1, tone=0.03)
	block(k, arm, "Cuff", ax, 0, 2.56, 2.42, 0.6, 0.6, "cloak", ch=0.03, corner=0.18, a=0.58, b=0.56)
	hand(k, arm, ax)
	cloud(k, arm, f"CloudArm{s}", (ax + s * 0.56, 0, 3.3), rx=0.34, facing="left" if s > 0 else "right")


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.55
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Pants", px, 0, 1.2, 0.5, 0.48, 0.52, "pants", ch=0.03, a=0.42, b=0.5)
	block(k, leg, "Skirt", px, 0, 1.95, 0.5, 0.545, 0.61, "cloak", ch=0.05, flare=0.05, corner=0.14, jit=0.03, mids=(1.45, 0.98), a=0.4, b=0.62, g=0.16, tone=0.04)
	sandal(k, leg, px, "pants", "sole", top=0.6)
	cloud(k, leg, "CloudLeg", (px - s * 0.02, -0.655, 1.1 if s > 0 else 0.86), rx=0.36 if s > 0 else 0.32)
	cloud(k, leg, "CloudLegB", (px, 0.65, 0.92 if s > 0 else 1.26), rx=0.36, facing="back")


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	true_face_uv(parts["Head"])
	_hair(k)
	_piercings(k)
	_cloak_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def _ringed_eye(f, cx, cy, s):
	"""Lilac all over, concentric dark rings, a pinpoint centre, no glint: the blank stare carries the likeness."""
	ix, ox = cx - s * 15, cx + s * 16
	iy, oy = cy + 5, cy - 5
	shape = f"M{ix} {iy}Q{cx - s * 3} {cy - 19} {ox} {oy}Q{cx + s * 7} {cy + 13} {ix} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, "#d8d0ea")
	px, py = cx - s * 0.5, cy - 0.5
	f.path(ell(px, py, 13, 15), "#9a86c6")
	for r, sw in ((12.6, 1.4), (9.4, 1.2), (6.2, 1.1), (3.2, 1.0)):
		f.path(ell(px, py, r, r * 1.14), stroke="#2c2048", sw=sw)
	f.path(ell(px, py, 1.3, 1.5), "#1c1430")
	f.path(f"M{ix} {iy - 9}H{ox}V{cy - 4}Q{cx} {cy - 8} {ix} {iy}Z", "#20162a", opacity=0.28)
	end_clip(f)
	f.path(f"M{ix - s} {iy + 1}Q{cx - s * 3} {cy - 22} {ox + s * 4} {oy - 3}L{ox + s * 0.5} {oy + 2.5}Q{cx - s * 2} {cy - 15} {ix - s} {iy + 1}Z", "#14101a")
	f.path(f"M{ix + s * 6} {cy + 9}Q{cx + s * 4} {cy + 10} {ox} {oy + 8}", stroke=shade(SKIN, 0.5), sw=1.1)


def _head_side(f, back_right):
	"""Skin in front, the hair mass behind and above; the ear mesh sits on the edge."""
	w = f.w
	fx = (lambda x: x) if back_right else (lambda x: w - x)
	f.fill(shade(SKIN, 0.9))
	f.soft(f"M{fx(-5)} 88H{fx(w + 5)}V135H{fx(-5)}Z", SKIN_D, 0.8, 3)
	f.path(f"M{fx(-5)} -5H{fx(w + 5)}V135H{fx(66)}L{fx(58)} 100L{fx(66)} 84L{fx(54)} 62L{fx(62)} 40L{fx(24)} 26L{fx(-5)} 30Z", HAIR_C)
	f.soft(f"M{fx(84)} 30L{fx(92)} 135H{fx(w + 5)}V30Z", HAIR_D, 0.7, 3)


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, top=20)
	# the hairline's shadow, broken under each fringe lock
	f.soft("M-5 -5H135V18L100 30L82 18L65 26L48 18L30 30L-5 18Z", SKIN_D, 0.75, 2)
	for s, x in ((-1, 37), (1, 93)):
		_ringed_eye(f, x, 62, s)
		ib, ob = 65 + s * 12, 65 + s * 44
		# level, thin brows: no anger, no expression
		f.path(f"M{ib} 42Q{65 + s * 28} 37 {ob} 38L{ob} 40.5Q{65 + s * 28} 40 {ib} 45Z", HAIR_D)
		f.soft(f"M{x - 16} 76Q{x} 84 {x + 16} 76L{x + 16} 80Q{x} 88 {x - 16} 80Z", SKIN_D, 0.5, 1)
	stroke(f, ((66, 82), (67, 88), (65, 90)), 0.8, "#b48c74")
	# a flat, shut mouth
	f.path("M54 104H76", stroke="#7c4f46", sw=1.3)
	f.soft("M57 108H73V111H57Z", SKIN_D, 0.5, 1)
	a["Head_B"].fill(HAIR_D)
	a["Head_T"].fill(HAIR_C)
	a["Head_Bo"].fill(SKIN_D)
	_head_side(a["Head_L"], True)
	_head_side(a["Head_R"], False)
