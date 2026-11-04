# Target look for leaf_copycat (design doc section 5): big head, tall silver spikes leaning to one side, plate slanted over one eye,
# dark mask to the nose, half-lidded eye, green flak vest with chest pouches, red spirals on sleeves and vest back, shin wraps, sandals.
import math

from atlas import FACES, SIZE
from leaf_style3 import BADGE, mark, back_panel, bake, block, dark_eye, gem, hand, head_sides, jitter, paint_plate, plate, sandal, shard, skin_face, stroke, true_face_uv, xf
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#f7dcc6"
SKIN_D = "#d8ac90"
DEFAULT = "#1f2a3a"
R = Ramps(
	hair=["#676b76", "#92959f", "#b9bbc5", "#d8d8dc", "#f0f1f4"],
	skin=["#c79c80", "#eac3a8", "#f7dcc6", "#fff0e2"],
	navy=["#0c121c", "#172130", "#232f42", "#374860"],
	vest=["#333d22", "#4a5732", "#5e6b47", "#77865a", "#94a374"],
	pouch=["#2d3620", "#434e2e", "#566241", "#6f7c54"],
	band=["#0e1420", "#192335", "#2a384e"],
	white=["#8f909c", "#d0d1d8", "#ececf0", "#ffffff"],
	steel=["#59606c", "#8f96a2", "#c2c8d0", "#eef1f4"],
	sole=["#0b0e14", "#161b24", "#262c38", "#3a4150"],
	black=["#0f0e13", "#201e27", "#35323f", "#4c4858"],
)
HAIR = {"colour": "#D8D8DC", "locks": []}
PROPS = []
HEAD_ROWS = [(0, 0, 3.98, 0.5, 0.6), (0, 0, 4.16, 0.78, 0.78), (0, 0, 4.44, 0.9, 0.82), (0, 0, 5.3, 0.9, 0.82), (0, 0, 5.56, 0.78, 0.72), (0, 0, 5.62, 0.6, 0.56)]
SLANT = 23  # degrees the band falls towards the viewer's right, over the covered eye
BAND_Z = 5.02


def _hair(k):
	dome = k.lathe("Head", "Crown", [(0.9, 5.3, 0.5), (1.0, 5.54, 0.5), (0.95, 5.9, 0.5), (0.55, 6.24, 0.5), (0.16, 6.32, 0.5)], "hair", n=10, at=(0.05, 0.05, 0), squash=0.95, outline=0)
	bake(k, dome, "hair", a=0.44, b=0.34)
	# a cap of hair over the head's upper corners, all round above the band
	block(k, "Head", "Cap", 0, 0.05, 5.72, 5.4, 0.93, 0.8, "hair", ch=0.05, corner=0.2, jit=0.015, a=0.38, b=0.4)
	# the tall mass: broad wedges leaning to the viewer's right, largest in the middle
	root = (0.1, 0.05, 5.6)

	def from_root(tip, f=0.25):
		return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))

	sil = (((-1.34, 0.1, 5.86), 0.4), ((-1.04, 0.1, 6.5), 0.5), ((-0.46, 0.1, 7.06), 0.54), ((0.26, 0.1, 7.34), 0.56), ((0.98, 0.1, 7.12), 0.54), ((1.54, 0.1, 6.6), 0.48), ((1.82, 0.1, 5.98), 0.4))
	for i, (tip, r) in enumerate(sil):
		gem(k, "Head", f"Sil{i}", from_root(tip), tip, r, bend=0.04, twist=0.3 + 0.13 * i % 0.5, a=0.44, b_=0.58)
	back = (((-0.72, 1.0, 6.4), 0.5), ((0.26, 1.16, 6.74), 0.54), ((1.14, 0.98, 6.34), 0.48), ((-0.96, 0.96, 5.62), 0.42), ((1.34, 0.86, 5.6), 0.42), ((0.12, 1.3, 5.72), 0.48))
	for i, (tip, r) in enumerate(back):
		gem(k, "Head", f"Back{i}", from_root(tip), tip, r, bend=0.05, twist=0.5 + 0.17 * i, a=0.4, b_=0.58)
	# the front row stands up from behind the band, one plane brighter than the wedges behind
	# their roots sit on the band's slanted top edge, in front of the hair behind it
	slope = math.tan(math.radians(SLANT))
	front = (((-1.0, -0.66, 6.02), 0.34), ((-0.6, -0.8, 6.42), 0.42), ((-0.06, -0.86, 6.78), 0.46), ((0.52, -0.84, 6.7), 0.46), ((1.06, -0.72, 6.24), 0.42), ((1.34, -0.6, 5.62), 0.32))
	for i, (tip, r) in enumerate(front):
		rx = tip[0] * 0.66 - 0.06
		gem(k, "Head", f"Front{i}", (rx, -0.8, BAND_Z + 0.3 - rx * slope), tip, r, flat=0.5, twist=0.2 + 0.3 * i % 0.6, a=0.5 + 0.03 * (i % 2), b_=0.62)
	# nape and the jagged hem
	nape = k.tube("Head", "Nape", [(0, 0.4, 5.66, 0.9, 0.5), (0, 0.4, 5.3, 0.96, 0.52), (0, 0.4, 4.7, 0.95, 0.5), (0, 0.42, 4.38, 0.86, 0.46)], "hair", corner=0.22, nc=1, sub=1, outline=0)
	jitter(nape, 0.02)
	bake(k, nape, "hair", a=0.42, b=0.36)
	for i, x in enumerate((-0.62, -0.2, 0.2, 0.62)):
		gem(k, "Head", f"NapeS{i}", (x, 0.72, 4.9), (x * 1.06, 0.92, 4.14 + 0.06 * (i % 2)), 0.3, flat=0.5, twist=0.3, across=(1, 0, 0), a=0.44, b_=0.5)
	# broad locks lying over the nape, so the back breaks into planes
	for i, x in enumerate((-0.66, -0.22, 0.24, 0.68)):
		gem(k, "Head", f"BackLow{i}", (x * 0.9, 0.72, 5.72), (x * 1.08, 1.0, 4.72 + 0.1 * (i % 2)), 0.36, flat=0.5, twist=0.25 + 0.2 * i, across=(1, 0, 0), a=0.46, b_=0.62)
	# a side lock each side, in front of the ear; the viewer's left one falls past the band
	for s, (y0, z0) in ((-1, (-0.42, 4.6)), (1, (-0.2, 4.46))):
		shard(k, f"Burn{s}", ((s * 0.84, y0, 5.46, 0.2), (s * 1.0, y0, 5.1, 0.26), (s * 0.98, y0, z0, 0.01)), a=0.46, b_=0.5)
	# wisps over the band on the viewer's left, the side the band sits high
	shard(k, "Wisp0", ((-0.76, -0.68, 5.74, 0.14), (-0.86, -0.97, 5.34, 0.2), (-0.8, -0.98, 4.96, 0.01)), a=0.54, b_=0.5)


def _band(k):
	"""Everything slanted as one ring: the cloth, its knot, the plate falling across the viewer's right eye."""
	piv = (0, 0, BAND_Z)
	# the hair falls to the band's top edge, no forehead above it; both end inside the nape, the back of the head stays hair
	cap = block(k, "Head", "Fore", 0, -0.6, BAND_Z + 0.66, BAND_Z, 0.9, 0.25, "hair", ch=0.03, jit=0.02, a=0.38, b=0.4)
	xf(cap, piv, ry=SLANT)
	cloth = block(k, "Head", "Band", 0, -0.33, BAND_Z + 0.25, BAND_Z - 0.25, 0.965, 0.555, "band", ch=0.03, corner=0.14, a=0.5, b=0.36)
	xf(cloth, piv, ry=SLANT)
	pl = plate(k, hw=0.6, top=BAND_Z + 0.24, bot=BAND_Z - 0.24)
	xf(pl, piv, ry=SLANT)


def _mask(k):
	"""The mask as a real shell over the lower face, its top edge straight across at the nose, gathered into the neck below."""
	rows = [(0, 0, 3.92, 0.62, 0.66), (0, 0, 4.14, 0.84, 0.82), (0, 0, 4.42, 0.925, 0.85), (0, 0, 4.6, 0.925, 0.85), (0, 0, 4.63, 0.89, 0.815)]
	o = k.tube("Head", "Mask", rows, "navy", corner=0.14, nc=1, outline=0)
	# its top edge climbs towards the ear and on under the hair
	for v in o.data.vertices:
		if v.co.z > 4.5:
			v.co.z += 0.5 * max(0.0, v.co.y + 0.5)
	o.data.update()
	bake(k, o, "navy", a=0.5, b=0.46, g=0.12)
	# the nose under the cloth: a low wedge at the top edge, with a soft fold each side of it
	gem(k, "Head", "MaskNose", (0, -0.86, 4.6), (0, -0.92, 4.38), 0.1, ramp="navy", flat=0.6, across=(1, 0, 0), a=0.6, b_=0.4)
	for s in (1, -1):
		o = block(k, "Head", f"MaskFold{s}", s * 0.36, -0.85, 4.32, 4.22, 0.28, 0.02, "navy", ch=0.008, a=0.42, b=0.3)
		xf(o, (s * 0.36, -0.85, 4.27), ry=s * 18)


def _vest(k):
	t = "UpperTorso"
	k.reshape(t, "Torso", [(0, 0, 3.9, 0.95, 0.45), (0, 0, 2.1, 0.95, 0.45)], corner=0.1, nc=1)
	# the dark shirt shows at the waist; the hips belong to the torso (a leg mesh stays at z <= 2)
	block(k, t, "Shirt", 0, 0, 3.0, 1.88, 1.05, 0.55, "navy", ch=0.03, a=0.46, b=0.56, g=0.1)
	block(k, t, "Vest", 0, 0, 3.98, 2.3, 1.08, 0.61, "vest", ch=0.07, flare=0.02, jit=0.03, sub=1, mids=(3.1,), a=0.5, b=0.56, g=0.14, tone=0.05)
	back_panel(k, t, 3.92, 2.42, 1.02, 0.62, "vest", a=0.5, b=0.5)
	# the seam down the middle
	block(k, t, "Seam", 0, -0.62, 3.9, 2.3, 0.03, 0.014, "pouch", ch=0.006, a=0.2, b=0.1)
	# two long scroll pouches each side of the seam, a flap on each
	for s in (1, -1):
		for i, x in enumerate((0.3, 0.74)):
			px = s * x
			block(k, t, f"Pouch{s}{i}", px, -0.67, 3.3, 2.46, 0.2, 0.09, "pouch", ch=0.03, corner=0.3, sub=1, a=0.5, b=0.64)
			block(k, t, f"Flap{s}{i}", px, -0.685, 3.36, 3.08, 0.215, 0.1, "pouch", ch=0.03, corner=0.2, a=0.6, b=0.6)
	# the thick high collar stands round the neck, open at the very front
	c = k.band(t, "Collar", (0, 0.02, 3.92), 0.9, 0.78, -68, 248, lambda a: (-0.04, 0.3 - 0.12 * max(0.0, 1 - abs((a + 90) if a < 90 else (a - 270)) / 50)), "vest", thick=0.13, e=0.62, n=18, flare=0.05, outline=0)
	bake(k, c, "vest", a=0.5, b=0.5)
	# the neck cloth of the mask, in the collar's opening
	block(k, t, "NeckCloth", 0, -0.02, 4.1, 3.9, 0.56, 0.5, "navy", ch=0.03, a=0.38, b=0.2, g=0.0)


def _spiral(k, arm, s, ax):
	"""The red spiral on the outside of the sleeve: a thin square patch wearing the art in Head_T."""
	x0, y0, pw, ph = FACES["Head_T"][:4]
	bx, by, bw, bh = BADGE
	o = block(k, arm, "Spiral", ax + s * 0.525, 0, 3.86, 3.34, 0.02, 0.26, "navy", ch=0.006, a=0.42, b=0.4)
	uv = o.data.uv_layers[0].data
	for poly in o.data.polygons:
		if abs(poly.normal.x) > 0.9:
			for li in poly.loop_indices:
				co = o.data.vertices[o.data.loops[li].vertex_index].co
				u, t = (co.y * -s + 0.26) / 0.52, (3.86 - co.z) / 0.52
				uv[li].uv = ((x0 + bx + u * bw) / SIZE, 1 - (y0 + by + t * bh) / SIZE)


def _arm(k, s, side):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.42, 0.42), (ax, 0, 2.05, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, arm, "Shoulder", ax, 0, 4.04, 3.0, 0.515, 0.515, "navy", ch=0.1, corner=0.18, jit=0.025, sub=1, mids=(3.5,), a=0.52, b=0.58)
	block(k, arm, "Forearm", ax, 0, 3.06, 2.46, 0.515, 0.515, "navy", ch=0.08, corner=0.18, jit=0.025, sub=1, a=0.5, b=0.58)
	# the fingerless glove: dark hand block, a steel plate on the cuff above it
	block(k, arm, "Cuff", ax, 0, 2.5, 2.24, 0.535, 0.535, "black", ch=0.03, corner=0.16, a=0.5, b=0.5)
	block(k, arm, "CuffPlate", ax, -0.54, 2.45, 2.29, 0.24, 0.02, "steel", ch=0.008, a=0.42, b=0.4)
	hand(k, arm, ax, z1=2.3)
	_spiral(k, arm, s, ax)


def _leg(k, s, side):
	leg = f"{side}UpperLeg"
	x = s * 0.5
	px = s * 0.54
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	block(k, leg, "Pants", px, 0, 1.95, 0.98, 0.51, 0.56, "navy", ch=0.04, flare=0.03, corner=0.16, jit=0.05, mids=(1.5,), a=0.46, b=0.62, g=0.1, tone=0.07)
	# the white wraps round the shin, turn on turn
	for i in range(4):
		z = 1.06 - i * 0.135
		o = block(k, leg, f"Wrap{i}", px, 0.02, z + 0.075, z - 0.075, 0.525, 0.565, "white", ch=0.018, corner=0.16, a=0.62, b=0.34, g=0.0)
		xf(o, (px, 0.02, z), ry=4 if i % 2 else -4)
	sandal(k, leg, px, "band", "sole", top=0.56)


def _holster(k):
	"""Viewer's left thigh: one white bandage turn, the pouch strapped on the outer side."""
	leg = "RightUpperLeg"
	block(k, leg, "Bandage", -0.56, 0, 1.56, 1.36, 0.56, 0.61, "white", ch=0.02, corner=0.16, a=0.6, b=0.36)
	block(k, leg, "Pouch", -1.16, -0.16, 1.62, 1.0, 0.18, 0.34, "band", ch=0.04, a=0.56)
	block(k, leg, "PouchFlap", -1.18, -0.18, 1.66, 1.34, 0.18, 0.35, "band", ch=0.035, a=0.7)
	block(k, leg, "PouchSnap", -1.18, -0.54, 1.46, 1.38, 0.05, 0.02, "steel", ch=0.008, a=0.6)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k, HEAD_ROWS)
	true_face_uv(parts["Head"])
	_hair(k)
	_mask(k)
	_band(k)
	_vest(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, s, side)
		_leg(k, s, side)
	_holster(k)
	finish()


def paint(a):
	R.paint(a)
	f = a["Head_F"]
	skin_face(f, SKIN, SKIN_D, top=30)
	# the one visible eye, on the viewer's left: half-lidded, dark, a lid crease above it
	x, y = 38, 54
	dark_eye(f, x, y, -1, w=33, up=11, dn=8, tilt=2, iris=10, ring="#141418", mid="#2b2b2b", glow="#44444a", heavy=6, lid=0.4)
	f.path(f"M{x + 17} {y - 8}Q{x} {y - 17} {x - 18} {y - 10}", stroke="#a87c64", sw=1.1)
	# a soft silver brow, lifted and lazy
	f.path(f"M{x + 18} {y - 18}Q{x} {y - 27} {x - 21} {y - 20}L{x - 20} {y - 17}Q{x} {y - 23} {x + 18} {y - 15}Z", "#7f818c")
	stroke(f, ((x - 6, y + 11), (x + 2, y + 13), (x + 12, y + 11)), 0.5, "#c9a08a")
	paint_plate(a["Head_B"], SKIN)
	# the vest's back: the large red mark on the green
	f = a["Torso_B"]
	f.fill("#5e6b47")
	f.soft("M-5-5H205V40Q100 56 -5 40Z", "#77865a", 0.6, 5)
	f.soft("M-5 96Q100 110 205 96V205H-5Z", "#3f4a2c", 0.7, 5)
	mark(f, 96, 68, 40, "#c9222a")
	head_sides(a, SKIN, SKIN_D)
	# the sleeve spiral lives in Head_T, hidden under the hair
	f = a["Head_T"]
	f.fill("#232f42")
	sx, sy = f.w / FACES["Head_T"][2], f.h / FACES["Head_T"][3]
	bx, by, bw, bh = BADGE
	cx, cy, rx, ry = (bx + bw / 2) * sx, (by + bh / 2) * sy, bw / 2 * sx, bh / 2 * sy
	f.path(f"M{cx - rx - 8} {cy - ry - 8}H{cx + rx + 8}V{cy + ry + 8}H{cx - rx - 8}Z", "#232f42")
	f.out.append(f'<g transform="translate({cx} {cy}) scale({rx / 40} {ry / 40})">')
	mark(f, -3, 4, 28, "#d0262e")
	f.out.append("</g>")
