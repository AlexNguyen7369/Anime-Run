# Target look for foe_jk2 "Mahitoh" (design doc section 5): long grey-blue hair split into three big sections tied near the ends, one at
# the back and two over the chest; one grey and one dark blue eye; a sewn-together patchwork of pale skin with stitched seams on the
# face, chest and arms; a long short-sleeved dark grid tunic with its left sleeve torn into three strips, baggy matching trousers, white
# shoes. +X is the viewer's right in the front view. Drawn in-house.
import math

from atlas import FACES, SIZE, shade
from jk_common import crease, eye2, form
from jk_style3 import Kit, bake, big_head, block, crown, finish, gem, head_rest, prism, slab, stroke, torso_core
from style2 import Ramps

SKIN = "#ece1d8"
SKIN_D = "#c4b6b0"
PATCH = "#d9cbc8"  # a sewn-on piece of slightly different skin
SEAM = "#3a2a36"
CLOTH = "#1a1e2c"
GRID = "#8f99ad"
DEFAULT = CLOTH
CP = {"dark": "#0c0e16", "lite": "#39415a"}
R = Ramps(
	hair=["#42505c", "#62727f", "#8a9aa6", "#aab9c3", "#cbd6dc"],
	skin=["#b0a29c", "#d8ccc4", "#ece1d8", "#fff4ec"],
	cloth=["#090b12", "#141823", "#232838", "#3a4258"],
	tie=["#120f16", "#231e28", "#3a3340", "#544c5c"],
	shoe=["#8c8e90", "#c8c9c6", "#e8e8e4", "#ffffff"],
	sole=["#3c3e44", "#62646a", "#8a8c92", "#b4b6ba"],
)
HAIR = {"colour": "#9DB4C0", "locks": []}
PROPS = []


def _shell(k, part, name, rows, block_name, top, bottom, zig=0.0):
	"""A cloth shell wearing a block's art. Its height is squeezed into the block's for the UVs, then let out, so a long hem keeps its grid."""
	art_top, art_bottom = (4.0, 2.0) if "Leg" not in block_name else (2.0, 0.0)
	scale = (art_top - art_bottom) / (top - bottom)
	o = k.tube(part, name, [(x, y, art_top - (top - z) * scale, hw, hd) for x, y, z, hw, hd in rows], ("face", block_name), corner=0.14, nc=1, sub=1, zig=zig, outline=0)
	for v in o.data.vertices:
		v.co.z = top - (art_top - v.co.z) / scale
	o.data.update()
	return o


def _bundle(k, name, rows, tie_at, tips):
	"""One tied section of hair: a tapered faceted mass, a dark tie, a burst of spikes under it."""
	o = k.tube("Head", name, rows, "hair", corner=0.3, nc=1, sub=1, outline=0)
	bake(o, "hair", k, a=0.5, b=0.5, g=0.1, tone=0.04)
	x, y, z = tie_at
	block(k, "Head", f"{name}Tie", x, y, z + 0.1, z - 0.1, rows[-1][3] + 0.015, rows[-1][4] + 0.015, "tie", ch=0.03, corner=0.3, a=0.5)
	for i, (tip, r) in enumerate(tips):
		gem(k, "Head", f"{name}Tip{i}", (x, y, z - 0.02), tip, r, flat=0.6, twist=0.3 + 0.12 * i, a=0.54)


def _hair(k):
	crown(k, [(0.98, 5.4), (1.03, 5.62), (0.98, 5.88), (0.6, 6.18), (0.18, 6.28)])
	block(k, "Head", "Cap", 0, 0.02, 5.72, 5.34, 1.0, 0.88, "hair", ch=0.09, corner=0.4, jit=0.015, sub=1, a=0.48, b=0.44)
	block(k, "Head", "Back", 0, 0.32, 5.46, 4.12, 1.03, 0.64, "hair", ch=0.06, corner=0.3, jit=0.03, sub=1, mids=(5.0, 4.6), a=0.46, b=0.42, tone=0.03)
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.5, 5.42), (-0.46, 4.7), (-0.34, 4.2), (0.3, 4.2), (0.3, 5.42)], s * 0.86, s * 1.04, "hair", a=0.5, b=0.46)
		# the two front sections: over the crown from the part, round the jaw, down over the chest, tied near the ends
		_bundle(
			k,
			f"Front{s}",
			[(s * 0.56, -0.42, 6.02, 0.26, 0.34), (s * 0.92, -0.44, 5.5, 0.26, 0.36), (s * 1.05, -0.46, 4.85, 0.27, 0.32), (s * 1.02, -0.64, 4.2, 0.29, 0.26), (s * 0.86, -0.8, 3.7, 0.27, 0.2), (s * 0.8, -0.82, 3.34, 0.18, 0.14)],
			(s * 0.8, -0.82, 3.28),
			(((s * 0.94, -0.86, 2.7), 0.16), ((s * 0.78, -0.9, 2.58), 0.18), ((s * 0.62, -0.86, 2.78), 0.14)),
		)
		# loose strands over the sides of the back mass
		for i, (y, z) in enumerate(((-0.05, 4.1), (0.32, 4.0))):
			gem(k, "Head", f"Strand{s}{i}", (s * 0.96, y, 5.7), (s * 1.09, y + 0.04, z), 0.28, flat=0.32, twist=0.2 + 0.2 * i, across=(0, 1, 0), a=0.5)
	# the third section, down the back
	_bundle(
		k,
		"BackTail",
		[(0, 0.66, 4.7, 0.62, 0.3), (0, 0.84, 4.1, 0.56, 0.28), (0, 0.86, 3.4, 0.42, 0.24), (0, 0.86, 2.82, 0.22, 0.16)],
		(0, 0.86, 2.76),
		(((-0.22, 0.92, 2.14), 0.19), ((0.02, 0.96, 2.02), 0.21), ((0.24, 0.92, 2.16), 0.19)),
	)
	# ragged bangs falling from a centre part, each from its own root so they lie side by side; the eyes stay clear
	for i, (x, t, r) in enumerate(((-0.62, (-0.86, -0.96, 4.72), 0.22), (-0.42, (-0.62, -0.96, 5.02), 0.25), (-0.16, (-0.3, -0.95, 5.2), 0.22), (0.16, (0.32, -0.95, 5.22), 0.22), (0.42, (0.62, -0.96, 5.0), 0.25), (0.62, (0.86, -0.96, 4.7), 0.22))):
		gem(k, "Head", f"Bang{i}", (x, -0.8, 5.84), t, r, flat=0.42, twist=0.2 + 0.15 * i, a=0.56, across=(0, 0, 1))
	for i, (b, t, r) in enumerate((((-0.1, 0.1, 6.0), (-1.12, 0.1, 5.3), 0.3), ((0.1, 0.1, 6.0), (1.12, 0.1, 5.3), 0.3))):
		gem(k, "Head", f"Clump{i}", b, t, r, flat=0.5, twist=0.3, a=0.5)
	# long locks lying down the back of the mass, either side of the tail
	for i, (x, z) in enumerate(((-0.8, 4.2), (-0.42, 4.02), (0.0, 4.4), (0.42, 4.06), (0.8, 4.16))):
		gem(k, "Head", f"BackLock{i}", (x * 0.8, 0.86, 5.82), (x, 1.04, z), 0.3, flat=0.32, twist=0.3, across=(1, 0, 0), a=0.5)


def _tunic(k):
	t = "UpperTorso"
	torso_core(k)
	_shell(k, t, "Tunic", [(0, 0, 4.0, 0.98, 0.5), (0, 0, 3.92, 1.06, 0.57), (0, 0, 3.4, 1.06, 0.57), (0, 0, 2.6, 1.04, 0.56), (0, 0, 2.05, 1.08, 0.62), (0, 0, 1.72, 1.17, 0.68)], "Torso", 4.0, 1.72)
	# the raised edge of the deep V neck, over the skin painted on the tunic
	for s in (1, -1):
		prism(k, t, f"Neck{s}", [(s * 0.26, 3.98), (s * 0.46, 3.98), (s * 0.13, 2.94), (0, 2.82), (0, 3.0)], -0.6, -0.56, "cloth", a=0.56, b=0.42)
	block(k, t, "HemBand", 0, 0, 1.8, 1.68, 1.19, 0.7, "cloth", ch=0.03, corner=0.14, a=0.42, b=0.5)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.9, 0.49, 0.49), (ax, 0, 2.3, 0.49, 0.49)], corner=0.12, nc=1)
	bottom = 3.34 if s > 0 else 3.08  # the torn sleeve ends higher, its strips hang below
	_shell(k, arm, "Sleeve", [(ax, 0, 4.04, 0.46, 0.46), (ax, 0, 3.94, 0.55, 0.55), (ax, 0, 3.5, 0.57, 0.57), (ax, 0, bottom, 0.59, 0.59)], f"{side}Arm", 4.0, 2.0, zig=0.05 if s > 0 else 0.0)
	block(k, arm, "Hand", ax, 0, 2.42, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.56, b=0.3)


def _strip(k, name, a0, a1, flat0, flat1, z_tip, axis):
	"""One torn strip of sleeve, its top hidden under the hem, ragged to a point; it wears the sleeve's cloth from the arm's art.
	axis "y": on the front, a0..a1 across x. axis "x": on the outside, a0..a1 across y."""
	top, w = 3.48, a1 - a0
	pts = [(a0, top), (a1, top), (a1 - w * 0.08, top - (top - z_tip) * 0.6), (a0 + w * 0.6, z_tip), (a0 + w * 0.24, top - (top - z_tip) * 0.74)]
	if axis == "y":
		verts, faces, flat = k._loft([[(a, flat0, z) for a, z in pts], [(a, flat1, z) for a, z in pts]])
		lo, face = 1.0, "LeftArm_F"
	else:
		verts, faces, flat = k._loft([[(flat0, a, z) for a, z in pts], [(flat1, a, z) for a, z in pts]])
		lo, face = -0.5, "LeftArm_O"
	o = k._mesh(name, "LeftUpperArm", verts, faces, flat, outline=0)
	x0, y0, pw, ph = FACES[face][:4]
	uv = o.data.uv_layers.new(name="UVMap").data
	for poly in o.data.polygons:
		for li in poly.loop_indices:
			c = o.data.vertices[o.data.loops[li].vertex_index].co
			along = c.x if axis == "y" else c.y
			uv[li].uv = ((x0 + 4 + min(1, max(0, (along - lo) / 1.0)) * (pw - 8)) / SIZE, 1 - (y0 + 4 + (top - c.z) / (top - z_tip) * (ph * 0.4)) / SIZE)
	return o


def _torn_sleeve(k):
	"""The left sleeve ripped into three: two strips on the front, one on the outside. The back keeps only the ragged hem."""
	_strip(k, "TornA", 1.02, 1.5, -0.585, -0.53, 2.66, "y")
	_strip(k, "TornB", 1.5, 2.04, -0.585, -0.53, 2.46, "y")
	_strip(k, "TornC", -0.3, 0.32, 2.03, 2.085, 2.56, "x")


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x, px = s * 0.5, s * 0.58
	k.reshape(leg, f"{side}Leg", [(x, 0, 2.0, 0.42, 0.42), (x, 0, 0.1, 0.42, 0.42)], corner=0.1, nc=1)
	_shell(k, leg, "Baggy", [(px, 0, 1.98, 0.5, 0.58), (px, 0, 1.3, 0.54, 0.64), (px, 0, 0.74, 0.56, 0.68), (px, 0, 0.54, 0.54, 0.66), (px, 0, 0.42, 0.42, 0.52)], f"{side}Leg", 1.98, 0.42)
	block(k, leg, "Shoe", px, -0.05, 0.48, 0.12, 0.47, 0.56, "shoe", ch=0.05, a=0.6, b=0.3)
	block(k, leg, "Toe", px, -0.5, 0.34, 0.12, 0.44, 0.24, "shoe", ch=0.07, corner=0.3, a=0.64, b=0.3)
	block(k, leg, "Sole", px, -0.13, 0.14, 0.0, 0.5, 0.67, "sole", ch=0.03, a=0.54)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_tunic(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	_torn_sleeve(k)
	finish()


# ---- paint


def stitches(f, x0, y0, cx, cy, x1, y1, n=7, tick=4.5, w=1.2, colour=SEAM):
	"""A sewn seam along a curve: the cut, and short thread crossings at right angles to it."""
	stroke(f, f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", colour, w)
	for i in range(n):
		t = (i + 0.5) / n
		x = (1 - t) ** 2 * x0 + 2 * t * (1 - t) * cx + t**2 * x1
		y = (1 - t) ** 2 * y0 + 2 * t * (1 - t) * cy + t**2 * y1
		dx, dy = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx), 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
		d = math.hypot(dx, dy) or 1
		nx, ny = -dy / d * tick, dx / d * tick
		stroke(f, f"M{x - nx:.1f} {y - ny:.1f}L{x + nx:.1f} {y + ny:.1f}", colour, w)


def grid(f, dark=0.5, step=25):
	"""The tunic's cloth: dark with thin pale lines both ways, soft shading over it."""
	f.fill(CLOTH)
	for x in range(step // 2, int(f.w) + 1, step):
		stroke(f, f"M{x} -5V{f.h + 5}", GRID, 1.5, 0.55)
	for y in range(step // 2, int(f.h) + 1, step):
		stroke(f, f"M-5 {y}H{f.w + 5}", GRID, 1.5, 0.55)
	form(f, op=dark)


def _torso(a):
	f = a["Torso_F"]
	grid(f)
	for ln in ((6, 28, 34, 40, 74, 82, 9), (194, 30, 166, 42, 126, 84, 9), (56, 104, 50, 138, 58, 180, 7), (144, 106, 150, 140, 142, 180, 7), (6, 128, 30, 124, 50, 134, 5), (194, 132, 170, 126, 150, 136, 5)):
		crease(f, *ln[:6], CP, ln[6], 1.0)
	# the deep V neck, bare stitched chest
	v = "M72 -5H128L100 96Z"
	f.path(v, SKIN)
	f.soft("M72 -5H90L100 60L100 96Z", SKIN_D, 0.7, 2)
	f.soft("M72 -5H128V10H72Z", SKIN_D, 0.8, 3)
	stitches(f, 76, 26, 100, 40, 124, 22, n=6, tick=3.6, w=1.1)
	stitches(f, 100, 40, 102, 62, 99, 86, n=4, tick=3.2, w=1.1)
	f = a["Torso_B"]
	grid(f)
	for ln in ((6, 54, 36, 72, 84, 110, 8), (194, 56, 164, 74, 116, 112, 8), (30, 120, 40, 150, 28, 186, 6), (170, 122, 160, 152, 172, 186, 6)):
		crease(f, *ln[:6], CP, ln[6], 1.0)
	for n in ("Torso_L", "Torso_R"):
		grid(a[n])
	a["Torso_T"].fill(shade(CLOTH, 1.3))
	a["Torso_Bo"].fill("#0a0c12")


def _limbs(a):
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(SKIN)
			f.soft("M-5 -5H18V215H-5Z", SKIN_D, 0.5, 3)
			f.soft("M105 -5H82V215H105Z", SKIN_D, 0.6, 3)
			f.soft("M-5 92H105V110H-5Z", SKIN_D, 0.5, 3)
			# the wrist seam goes all the way round, a long one down the outside and the front
			stitches(f, -4, 158, 50, 154, 104, 158, n=7, tick=4.2, w=1.3)
			if key in "OF":
				stitches(f, 30 if key == "O" else 64, 104, 58, 128, 44 if key == "O" else 42, 154, n=5, tick=4.2, w=1.3)
			# the sleeve's cloth is the top of this face
			f.out.append('<clipPath id="k%s"><rect x="-5" y="-5" width="110" height="%d"/></clipPath><g clip-path="url(#k%s)">' % (f.name, 96, f.name))
			grid(f, 0.35)
			f.out.append("</g>")
			g = a[f"{side}Leg_{key}"]
			grid(g, 0.5)
			for ln in ((96, 8, 74, 26, 46, 34, 7), (4, 70, 24, 86, 44, 100, 7), (96, 76, 76, 90, 56, 104, 7), (6, 150, 30, 138, 60, 146, 6), (94, 170, 66, 158, 36, 168, 5)):
				crease(g, *ln[:6], CP, ln[6], 1.0)
		a[f"{side}Arm_T"].fill(shade(CLOTH, 1.3))
		a[f"{side}Arm_Bo"].fill("#0a0c12")  # the sleeve's underside; the arm's own is hidden by the hand
		a[f"{side}Leg_T"].fill(CLOTH)
		a[f"{side}Leg_Bo"].fill("#0a0c12")


def _face(f):
	f.fill(SKIN)
	# sewn-on patches: under the seam on the viewer's right, and the jaw on the viewer's left
	f.path("M84 -5L135 -5V135H96Q78 110 90 80Q98 60 84 -5Z", PATCH)
	f.path("M-5 86Q24 94 44 114L34 135H-5Z", PATCH)
	f.soft("M-5-5H135V24Q65 32 -5 24Z", SKIN_D, 0.8, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", SKIN_D, 0.6, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", SKIN_D, 0.75, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", SKIN_D, 0.5, 3)
	# sly half-lidded eyes: grey on his right, dark blue on his left
	eye2(f, 38, 58, -1, 37, 18, "#8f9aa3", tilt=3.2, r=12, lid=0.22, lash="#1a1620", lash_t=3.2, flick=4, sclera="#fbf8f2", crease_line=False)
	eye2(f, 92, 58, 1, 37, 18, "#27467e", tilt=3.2, r=12, lid=0.22, lash="#1a1620", lash_t=3.2, flick=4, sclera="#fbf8f2", crease_line=False)
	for x, s in ((38, -1), (92, 1)):
		f.path(f"M{x - s * 15} 42Q{x} 34 {x + s * 16} 38Q{x} 38 {x - s * 15} 44Z", "#6e8494")
	# a small straight nose
	f.path("M63 66L68 82L61 84Q64 76 63 66Z", SKIN_D, opacity=0.9)
	# the wide sneering grin, teeth showing
	mouth = "M42 92Q66 100 92 86Q86 108 66 110Q48 108 42 92Z"
	f.path(mouth, "#2a1218")
	f.path("M46 95Q66 101 89 90Q86 98 82 100Q66 106 52 102Q48 100 46 95Z", "#f6f2ea")
	for x in (54, 61, 68, 75, 82):
		stroke(f, f"M{x} {96 + (x % 4)}V{103 - (x % 3)}", "#a89c94", 0.6)
	stroke(f, "M42 92Q66 100 92 86", SEAM, 1.1)
	stroke(f, "M92 86Q95 84 96 80", SEAM, 1.3)
	stroke(f, "M42 92Q39 91 38 88", SEAM, 1.3)
	# the seams: across the bridge of the nose and both cheeks, down through the eye on his left, the jaw patch on his right
	stitches(f, -4, 76, 40, 82, 80, 74, n=8)
	stitches(f, 80, 74, 92, 70, 134, 58, n=5)
	stitches(f, 84, 22, 88, 44, 86, 50, n=2)
	stitches(f, 90, 76, 82, 100, 96, 130, n=5)
	stitches(f, -4, 88, 22, 94, 42, 112, n=4)


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.78), shade(SKIN, 0.6))
	a["Head_T"].fill("#8a9aa6")
	_torso(a)
	_limbs(a)
