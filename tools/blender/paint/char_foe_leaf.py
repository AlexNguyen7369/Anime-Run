# Target look for foe_leaf (design doc section 5, 4.26). Evidence: docs/char_evidence/foe_leaf.md.
# Big head, big orange spikes above a dark band and steel plate, long jagged locks behind the ears, ringed lilac eyes,
# six dark studs down the nose, two spikes under the lip, studded ears, ankle-long black cloak lined in red, clouds.
from atlas import shade
from leaf_common import begin_clip, ell, end_clip
from leaf_style3 import PLATE_T, bake, block, cloud, gem, hand, head_sides, jitter, plate, sandal, shard, skin_face, stroke, true_face_uv
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f4dcc8"
SKIN_D = "#d2aa90"
HAIR_D = "#a84a0e"
STUD = "#23232c"
DEFAULT = "#141418"
R = Ramps(
	hair=["#8c3606", "#bf5508", "#e8731a", "#f78b24", "#ffae4c"],
	skin=["#c49c84", "#e8c4ac", "#f4dcc8", "#ffeee0"],
	cloak=["#0c0c10", "#141418", "#1e1e25", "#2f2f39", "#47474f"],
	lining=["#5e0c14", "#8c141e", "#b01e28", "#cc3038"],
	red=["#8c1018", "#b01e28", "#cc2a32", "#e04048"],
	white=["#b4b4bc", "#dcdce2", "#f4f4f8", "#ffffff"],
	band=["#0a0a10", "#16161e", "#262630"],
	stud=["#0e0e14", "#1e1e28", "#34343f", "#62626f"],
	pants=["#121216", "#1e1e24", "#2a2a32", "#40404a"],
	sole=["#0b0a0e", "#19171d", "#2b2830", "#3d3a44"],
)
HAIR = {"colour": "#E8731A", "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.42, 0.6), (0, 0, 4.16, 0.68, 0.78), (0, 0, 4.46, 0.86, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
ROOT = (0, 0.05, 5.55)
BAND_TOP, BAND_BOT = 5.5, 5.0
# Tip, radius. Wider and flatter than a crown: the side spikes throw out past the shoulders' line of sight and droop a little.
UPPER = (
	((-1.72, 0.02, 5.5), 0.36),
	((-1.56, 0.12, 6.02), 0.42),
	((-1.1, 0.22, 6.46), 0.46),
	((-0.42, 0.3, 6.84), 0.48),
	((0.3, 0.3, 6.72), 0.46),
	((0.98, 0.24, 6.56), 0.46),
	((1.5, 0.14, 6.1), 0.42),
	((1.76, 0.04, 5.58), 0.36),
)
BEHIND = (((-1.32, 0.92, 5.72), 0.42), ((-0.66, 1.26, 6.2), 0.46), ((0.1, 1.38, 5.94), 0.48), ((0.76, 1.24, 6.28), 0.46), ((1.36, 0.92, 5.66), 0.42))
MIDDLE = (((-1.28, -0.34, 5.86), 0.38), ((-0.72, -0.42, 6.42), 0.44), ((-0.02, -0.48, 6.56), 0.46), ((0.68, -0.42, 6.4), 0.44), ((1.3, -0.34, 5.9), 0.38))
FRONT = (((-1.02, -0.8, 5.84), 0.34), ((-0.56, -0.94, 6.1), 0.36), ((-0.04, -1.0, 5.94), 0.36), ((0.5, -0.94, 6.16), 0.36), ((1.0, -0.8, 5.88), 0.34))


def _spray(k, tag, spikes, f=0.24, bend=0.05):
	for i, (tip, r) in enumerate(spikes):
		base = tuple(ROOT[j] + (tip[j] - ROOT[j]) * f for j in range(3))
		gem(k, "Head", f"{tag}{i}", base, tip, r, bend=bend, twist=0.28 + 0.17 * i % 0.6)


def _hair(k):
	crown = k.lathe("Head", "Crown", [(0.92, BAND_TOP - 0.04, 0.5), (1.0, 5.62, 0.5), (0.94, 5.94, 0.5), (0.52, 6.24, 0.5), (0.14, 6.32, 0.5)], "hair", n=10, at=(0, 0.05, 0), squash=0.96, outline=0)
	bake(k, crown, "hair", a=0.46, b=0.36)
	nape = k.tube("Head", "Nape", [(0, 0.46, 5.72, 0.9, 0.46), (0, 0.46, 5.3, 0.98, 0.5), (0, 0.46, 4.7, 0.98, 0.5), (0, 0.5, 4.42, 0.84, 0.44)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.02)
	bake(k, nape, "hair", a=0.42, b=0.36)
	_spray(k, "Upper", UPPER)
	_spray(k, "Behind", BEHIND)
	_spray(k, "Middle", MIDDLE)
	# the front row rises from behind the band
	for i, (tip, r) in enumerate(FRONT):
		gem(k, "Head", f"Front{i}", (tip[0] * 0.8, -0.62, 5.4), tip, r, flat=0.55, twist=0.2 + 0.3 * i % 0.6)
	# thin strands drop over the band and the plate's top edge, uneven on purpose
	for name, x, drop, w in (("BangA", -0.36, 5.3, 0.1), ("BangB", 0.22, 5.38, 0.08), ("BangC", 0.5, 5.26, 0.1)):
		shard(k, name, ((x, -0.9, 5.76, w), (x + 0.03, -1.02, 5.58, w * 1.2), (x + 0.05, -1.03, drop, 0.01)), a=0.5, b_=0.56)
	for s in (1, -1):
		# over the band's ends, then the long jagged locks that fall behind the ear to the jaw and below it
		shard(k, f"Temple{s}", ((s * 0.72, -0.82, 5.62, 0.17), (s * 0.88, -0.93, 5.3, 0.19), (s * 0.92, -0.9, 5.06, 0.12), (s * 0.92, -0.86, 4.84, 0.01)), a=0.48, b_=0.6)
		shard(k, f"LockA{s}", ((s * 0.82, 0.24, 5.3, 0.25), (s * 1.02, 0.26, 4.8, 0.27), (s * 1.08, 0.28, 4.36, 0.17), (s * 1.08, 0.3, 3.98, 0.01)), a=0.42, b_=0.6)
		shard(k, f"LockB{s}", ((s * 0.84, 0.6, 5.3, 0.26), (s * 1.06, 0.64, 4.74, 0.28), (s * 1.14, 0.68, 4.26, 0.19), (s * 1.16, 0.72, 3.86, 0.01)), a=0.38, b_=0.6)
		shard(k, f"LockC{s}", ((s * 0.98, 0.26, 5.36, 0.2), (s * 1.24, 0.3, 5.04, 0.22), (s * 1.32, 0.34, 4.72, 0.14), (s * 1.34, 0.38, 4.42, 0.01)), a=0.44, b_=0.6)
	# the back of the head: a broad row lying down over the nape, its tips above the jagged hem
	for i, x in enumerate((-0.74, -0.38, 0.02, 0.4, 0.76)):
		gem(k, "Head", f"Drape{i}", (x * 0.8, 0.74, 5.86), (x * 1.08, 1.06, 4.72 + 0.14 * (i % 2)), 0.36, flat=0.5, twist=0.25, across=(1, 0, 0))
	for i, x in enumerate((-0.68, -0.34, 0.0, 0.34, 0.68)):
		gem(k, "Head", f"NapeS{i}", (x, 0.76, 5.0), (x * 1.06, 1.02, 4.02 + 0.09 * (i % 2)), 0.32, flat=0.5, twist=0.3, across=(1, 0, 0))


def _band(k):
	block(k, "Head", "Band", 0, 0, BAND_TOP, BAND_BOT, 0.955, 0.885, "band", ch=0.03, corner=0.24, a=0.5, b=0.36)
	# wider at the foot than at the top, as on the source
	o = plate(k, hw=0.6, top=BAND_TOP - 0.02, bot=BAND_BOT + 0.01)
	span = BAND_TOP - BAND_BOT
	for v in o.data.vertices:
		v.co.x *= 1 - 0.13 * (v.co.z - BAND_BOT) / span
	o.data.update()


def _studs(k):
	"""Face piercings: not marks, so they follow the source. Oversized a little, to read at game distance."""
	for i, z in enumerate((4.6, 4.49, 4.38)):
		for s in (1, -1):
			block(k, "Head", f"NoseStud{i}{s}", s * 0.095, -0.835, z + 0.034, z - 0.034, 0.036, 0.02, "stud", ch=0.012, corner=0.3, a=0.56, b=0.4, g=0.0)
	for s in (1, -1):
		gem(k, "Head", f"LipSpike{s}", (s * 0.15, -0.83, 4.18), (s * 0.16, -0.87, 4.07), 0.04, ramp="stud", flat=1.0, a=0.56, b_=0.42)


def _ear(k, s):
	"""The ear stands in front of the hair. Its hardware keeps place, size and colour with a changed shape: square studs, a hooked bar."""
	y = -0.14
	block(k, "Head", f"Ear{s}", s * 0.93, y, 4.96, 4.46, 0.07, 0.15, "skin", ch=0.03, corner=0.25, a=0.52, b=0.3, g=0.0)
	for i, z in enumerate((4.88, 4.76, 4.64)):
		block(k, "Head", f"EarStud{s}{i}", s * 1.0, y, z + 0.035, z - 0.035, 0.03, 0.05, "stud", ch=0.008, corner=0.12, a=0.6, b=0.4, g=0.0)
	block(k, "Head", f"EarBar{s}", s * 1.0, y, 4.56, 4.51, 0.026, 0.22, "stud", ch=0.006, corner=0.2, a=0.62, b=0.4, g=0.0)
	block(k, "Head", f"EarHook{s}", s * 1.0, y - 0.2, 4.56, 4.42, 0.026, 0.026, "stud", ch=0.006, corner=0.2, a=0.62, b=0.4, g=0.0)


def _cloak_top(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	block(k, t, "Cloak", 0, 0, 3.98, 1.88, 1.08, 0.6, "cloak", ch=0.07, flare=0.03, jit=0.025, sub=1, mids=(3.3, 2.6), a=0.4, b=0.6, g=0.14, tone=0.04)
	block(k, t, "Closure", 0, -0.63, 3.9, 1.88, 0.022, 0.02, "cloak", ch=0.006, a=0.02, b=0.04, g=0.0)

	# the high collar, chin high at the sides and back, red inside, open at the front
	def rise(a):
		f = max(0.0, 1 - abs((a + 90) if a < 90 else (a - 270)) / 62)
		return (-0.06, 0.52 - 0.3 * f)

	bake(k, k.band(t, "Lining", (0, 0.0, 3.94), 0.9, 0.86, -70, 250, rise, "lining", thick=0.04, e=0.58, n=20, flare=0.03, outline=0), "lining", a=0.5, b=0.3)
	bake(k, k.band(t, "Collar", (0, 0.0, 3.94), 0.95, 0.91, -70, 250, rise, "cloak", thick=0.09, e=0.58, n=20, flare=0.03, outline=0), "cloak", a=0.42, b=0.6)
	block(k, t, "Neck", 0, -0.02, 4.12, 3.9, 0.46, 0.42, "skin", ch=0.02, a=0.3, b=0.1, g=0.0)
	for s in (1, -1):
		verts = []
		for y in (-0.6, -0.66):
			verts += [(s * 0.42, y, 4.16), (s * 0.02, y, 3.5), (s * 0.3, y, 3.72), (s * 0.68, y, 4.0)]
		faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
		bake(k, k._mesh(f"Fold{s}", t, verts, faces, (), 0), "lining", a=0.56, b=0.3)
	# the big cloud low in the middle of the front, a small one high on the chest; the largest on the back
	cloud(k, t, "CloudBelly", (0.0, -0.665, 2.62), rx=0.54)
	cloud(k, t, "CloudChest", (-0.58, -0.635, 3.42), rx=0.32)
	cloud(k, t, "CloudBack", (0.2, 0.635, 2.86), rx=0.6, facing="back")
	cloud(k, t, "CloudBackB", (-0.6, 0.635, 3.56), rx=0.3, facing="back")


def _arm(k, s, side):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Sleeve", ax, 0, 4.04, 2.5, 0.53, 0.53, "cloak", ch=0.09, flare=0.05, corner=0.18, jit=0.025, sub=1, mids=(3.5, 3.0), a=0.4, b=0.62, g=0.1, tone=0.03)
	block(k, arm, "Cuff", ax, 0, 2.56, 2.44, 0.6, 0.6, "cloak", ch=0.03, corner=0.18, a=0.58, b=0.56)
	block(k, arm, "CuffRed", ax, 0, 2.46, 2.38, 0.565, 0.565, "lining", ch=0.02, corner=0.18, a=0.58, b=0.34)
	hand(k, arm, ax)
	cloud(k, arm, f"CloudArm{s}", (ax + s * 0.56, 0, 3.24), rx=0.36, facing="left" if s > 0 else "right")
	cloud(k, arm, f"CloudArmF{s}", (ax, -0.59, 3.56 if s > 0 else 3.3), rx=0.28)


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.55
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Pants", px, 0, 1.2, 0.5, 0.48, 0.52, "pants", ch=0.03, a=0.42, b=0.5)
	block(k, leg, "Skirt", px, 0, 1.95, 0.5, 0.545, 0.61, "cloak", ch=0.05, flare=0.05, corner=0.14, jit=0.03, mids=(1.45, 0.98), a=0.4, b=0.62, g=0.16, tone=0.04)
	# the lining shows at the hem
	block(k, leg, "HemRed", px, 0, 0.56, 0.44, 0.56, 0.625, "lining", ch=0.02, corner=0.14, a=0.56, b=0.34)
	sandal(k, leg, px, "pants", "sole", top=0.6)
	cloud(k, leg, "CloudLeg", (px, -0.665, 1.2 if s > 0 else 0.92), rx=0.34)
	cloud(k, leg, "CloudLegB", (px, 0.665, 0.98 if s > 0 else 1.3), rx=0.38, facing="back")


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	true_face_uv(parts["Head"])
	_hair(k)
	_band(k)
	_studs(k)
	_cloak_top(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_ear(k, s)
		_arm(k, s, side)
		_leg(k, s, side)
	finish()


def _ringed_eye(f, cx, cy, s):
	"""Lilac over the whole eye, concentric rings, a pinpoint centre, a heavy winged lash: the stare carries the likeness."""
	ix, ox = cx - s * 16, cx + s * 17
	iy, oy = cy + 6, cy - 6
	shape = f"M{ix} {iy}Q{cx - s * 3} {cy - 22} {ox} {oy}Q{cx + s * 8} {cy + 16} {ix} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, "#cfc4e8")
	px, py = cx - s * 0.5, cy - 0.5
	f.path(ell(px, py, 13.5, 15), "#a692d2")
	for r, sw in ((13, 1.7), (9.6, 1.5), (6.3, 1.4), (3.2, 1.2)):
		f.path(ell(px, py, r, r * 1.12), stroke="#35265c", sw=sw)
	f.path(ell(px, py, 1.5, 1.7), "#1c1430")
	f.path(ell(px - 3.4, py - 5, 1.5, 1.7), "#ffffff", opacity=0.85)
	f.path(f"M{ix} {iy - 12}H{ox}V{cy - 5}Q{cx} {cy - 9} {ix} {iy}Z", "#20162a", opacity=0.3)
	end_clip(f)
	f.path(f"M{ix - s} {iy + 1}Q{cx - s * 3} {cy - 26} {ox + s * 6} {oy - 5}L{ox + s * 1} {oy + 3}Q{cx - s * 2} {cy - 18} {ix - s} {iy + 1}Z", "#100c16")
	f.path(f"M{ix + s * 5} {cy + 13}Q{cx + s * 4} {cy + 14} {ox} {oy + 12}", stroke=shade(SKIN, 0.5), sw=1.1)


def _paint_plate(f):
	"""Drawn in plate units, 130 x 48, stretched down Head_B's top (leaf_style3.plate maps it there)."""
	f.fill(SKIN)
	f.out.append(f'<g transform="scale(1 {PLATE_T / 48:.4f})">')
	f.path("M0 0H130V48H0Z", "#aab0ba")
	f.soft("M0 0H130V17Q60 25 0 19Z", "#e2e6ec", 0.85, 2)
	f.soft("M94 2H128V46H106Q90 26 94 2Z", "#6a717d", 0.7, 3)
	f.path("M26 3L42 3L32 45L18 45Z", "#f6f8fa", opacity=0.55)
	f.path("M0 38H130V48H0Z", "#6f7682", opacity=0.6)
	f.path("M0 0H130L125 3H5L5 45L0 48Z", "#eef1f5")
	f.path("M130 0V48H0L5 45H125V3Z", "#565d68")
	for x in (11, 119):
		for y in (10, 38):
			f.path(ell(x, y, 3, 3.2), "#3c424c")
			f.path(ell(x - 0.6, y - 0.7, 2.1, 2.2), "#c4c9d0")
	# the changed mark, three leaning teardrops in the source's place and colour, with the scratch across it
	for x in (43, 65, 87):
		f.path(f"M{x + 6} 8Q{x + 12} 26 {x + 1} 37Q{x - 10} 40 {x - 8} 28Q{x - 4} 18 {x + 6} 8Z", "#1e2028")
	f.path("M16 25L114 22L114 26L16 29Z", "#0e0f13")
	f.path("M16 29.5L114 26.5", stroke="#f0f2f6", sw=1.3)
	f.out.append("</g>")


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, top=40)
	for s, x in ((-1, 37), (1, 93)):
		_ringed_eye(f, x, 62, s)
		ib, ob = 65 + s * 13, 65 + s * 45
		# thin brows angled in, close under the band
		f.path(f"M{ib} 50Q{65 + s * 28} 42 {ob} 41L{ob} 44Q{65 + s * 28} 46 {ib} 53.5Z", HAIR_D)
	# the nose: one long side line and a small tip, between the stud columns
	stroke(f, ((66, 74), (67, 88), (65, 94)), 0.7, "#b48c74")
	f.path("M61 96Q65 98 70 96", stroke="#b48c74", sw=0.9)
	# a flat, shut mouth, the lower lip a short soft line
	f.path("M54 106Q65 104 76 106", stroke="#6e443c", sw=1.5)
	f.soft("M58 110H72V113H58Z", SKIN_D, 0.5, 1)
	for s in (1, -1):
		f.soft(f"M{65 + s * 10} 112L{65 + s * 16} 112L{65 + s * 14} 122Z", SKIN_D, 0.4, 1)
	_paint_plate(a["Head_B"])
	head_sides(a, SKIN, SKIN_D)
