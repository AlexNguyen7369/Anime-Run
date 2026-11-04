# Target look for foe_jk2 "Mahitoh" (design doc section 5). Pale ice-blue hair: a domed crown, long parted bangs, three big hanks tied
# near the ends, two over the chest and one down the back. One grey and one dark blue eye, a wide open grin. Pale skin sewn together:
# thin seams with paired stitches on the face, neck and both arms. A boxy navy tunic with a pale raised grid: on the viewer's left a
# huge loose sleeve with a long tail, on the viewer's right no sleeve, only three torn strips round the bare arm. Slim-cut navy
# trousers kept to the block width, rolled at the ankle; white slip-on shoes with a black centre stripe.
# +X is the viewer's right in the front view. Hand-built and drawn in-house.
import math
import random

from atlas import shade
from jk_common import eye2, form
from jk_style3 import Kit, bake, big_head, block, face_base, finish, gem, head_rest, jitter, prism, slab, stroke, torso_core, trouser
from style2 import Ramps

SKIN = "#f3e2d2"
SKIN_D = "#cfb5a6"
PATCH = "#ecd8c8"  # the sewn-on pieces are a shade off
SEAM = "#6b4436"
THREAD = "#1e1820"
CLOTH = "#232a4e"
CLOTH_D = "#10142c"
GRID = "#7f8abc"
DEFAULT = CLOTH
R = Ramps(
	hair=["#4d6478", "#6e8b9f", "#92adbd", "#adc6d1", "#cde0e6"],
	tie=["#08080e", "#12121c", "#20202e", "#343446"],
	skin=["#b9a090", "#dcc6b6", "#f3e2d2", "#fff4e8"],
	cloth=["#0e1228", "#1a2040", "#2a3360", "#3f4a80"],
	navy=["#080a18", "#10142a", "#1a1f3e", "#2a3158"],
	shoe=["#9498a2", "#cfd2d8", "#eef0f2", "#ffffff"],
	stripe=["#08080c", "#111116", "#1e1e26", "#30303a"],
	sole=["#0a0a10", "#16161e", "#262630", "#3a3a46"],
)
HAIR = {"colour": "#A9C8D6", "locks": []}
PROPS = []


def _shell(k, part, name, rows, block_name, top, bottom, art=(4.0, 2.0), zig=0.0, jit=0.0, sub=1):
	"""A cloth shell wearing a block's art: its height is squeezed into art for the UVs, then let out, so a long hem keeps its grid."""
	scale = (art[0] - art[1]) / (top - bottom)
	o = k.tube(part, name, [(x, y, art[0] - (top - z) * scale, hw, hd) for x, y, z, hw, hd in rows], ("face", block_name), corner=0.14, nc=1, sub=sub, zig=zig, outline=0)
	for v in o.data.vertices:
		v.co.z = top - (art[0] - v.co.z) / scale
	o.data.update()
	if jit:
		jitter(o, jit)
	return o


def _hank(k, name, rows, tie_at, tips):
	"""One tied section: a lumpy faceted mass, a two-wrap dark tie, a burst of spikes under it."""
	o = k.tube("Head", name, rows, "hair", corner=0.32, nc=1, sub=1, outline=0)
	jitter(o, 0.02)
	bake(o, "hair", k, a=0.48, b=0.4, g=0.1, tone=0.04)
	x, y, z = tie_at
	last = rows[-1]
	for i, dz in enumerate((0.06, -0.08)):
		block(k, "Head", f"{name}Tie{i}", x, y, z + dz + 0.05, z + dz - 0.05, last[3] + 0.02, last[4] + 0.02, "tie", ch=0.02, corner=0.32, a=0.5)
	for i, (tip, r) in enumerate(tips):
		gem(k, "Head", f"{name}Tip{i}", (x, y, z - 0.04), tip, r, flat=0.62, twist=0.25 + 0.14 * i, a=0.5, b_=0.46)


def _hair(k):
	# one rounded dome, wider than the head's corners, so no ledge shows between it and the hanging hair
	dome = k.tube("Head", "Dome", [(0, 0.06, 5.32, 1.0, 0.9), (0, 0.06, 5.62, 1.02, 0.92), (0, 0.06, 5.84, 0.88, 0.78), (0, 0.06, 6.02, 0.6, 0.54), (0, 0.06, 6.1, 0.18, 0.16)], "hair", corner=0.5, nc=2, sub=1, outline=0)
	jitter(dome, 0.012)
	bake(dome, "hair", k, a=0.5, b=0.38)
	block(k, "Head", "Back", 0, 0.32, 5.4, 4.03, 1.0, 0.62, "hair", ch=0.06, corner=0.45, jit=0.03, sub=1, mids=(5.0, 4.6), a=0.46, b=0.42, tone=0.03)
	# the crown: two rings of broad flat strands laid on the dome, running down from the parting, a shallow step between each
	for i in range(8):
		a = 2 * math.pi * (i + 0.5) / 8
		c, n = math.cos(a), math.sin(a)
		gem(k, "Head", f"Top{i}", (0.14 * c, 0.02 + 0.12 * n, 6.08), (0.96 * c, 0.02 + 0.88 * n, 5.7), 0.42, flat=0.24, twist=0.06, across=(-n, c, 0), a=0.5, b_=0.42)
	for i in range(11):
		a = 2 * math.pi * i / 11 - math.pi / 2
		c, n = math.cos(a), math.sin(a)
		gem(k, "Head", f"Rim{i}", (0.78 * c, 0.02 + 0.72 * n, 5.9), (1.09 * c, 0.02 + 1.0 * n, 5.32 + 0.06 * (i % 2)), 0.34, flat=0.24, twist=0.06, across=(-n, c, 0), a=0.48, b_=0.42)
	# the bangs, parted at the centre: long at the middle and the temples, short over the brows so the eyes stay clear
	for i, (x, t, r) in enumerate(
		(
			(-0.05, (-0.03, -0.97, 4.6), 0.17),
			(-0.22, (-0.27, -0.97, 5.1), 0.22),
			(0.22, (0.28, -0.97, 5.12), 0.22),
			(-0.44, (-0.54, -0.98, 5.04), 0.24),
			(0.44, (0.56, -0.98, 5.06), 0.24),
			(-0.66, (-0.84, -0.97, 4.72), 0.23),
			(0.66, (0.86, -0.97, 4.68), 0.23),
			(-0.84, (-1.0, -0.86, 4.42), 0.24),
			(0.84, (1.0, -0.86, 4.38), 0.24),
		)
	):
		gem(k, "Head", f"Bang{i}", (x * 0.8, -0.78, 5.92), t, r, flat=0.38, twist=0.2 + 0.13 * i, a=0.52, b_=0.46, across=(1, 0, 0))
	for s in (1, -1):
		slab(k, f"Side{s}", [(-0.5, 5.36), (-0.46, 4.8), (-0.32, 4.14), (0.68, 4.03), (0.68, 5.36)], s * 0.86, s * 1.03, "hair", a=0.48, b=0.4)
		for i, (y, z) in enumerate(((-0.34, 4.3), (-0.04, 4.14), (0.26, 4.22), (0.56, 4.3))):
			gem(k, "Head", f"Curtain{s}{i}", (s * 0.84, y, 5.6), (s * 1.12, y + 0.04, z), 0.27, flat=0.34, twist=0.2 + 0.2 * i, across=(0, 1, 0), a=0.48, b_=0.4)
		# loose ends fanning out behind the shoulder
		gem(k, "Head", f"Fly{s}0", (s * 0.95, 0.34, 4.8), (s * 1.6, 0.4, 4.34), 0.2, flat=0.5, twist=0.3, a=0.5, b_=0.42)
		gem(k, "Head", f"Fly{s}1", (s * 0.95, 0.55, 4.6), (s * 1.4, 0.62, 4.14), 0.2, flat=0.5, twist=0.5, a=0.46, b_=0.42)
		# the two chest sections: from behind the ear, round the jaw, over the chest
		_hank(
			k,
			f"Hank{s}",
			[(s * 0.92, -0.2, 5.1, 0.24, 0.3), (s * 1.02, -0.44, 4.55, 0.3, 0.34), (s * 0.98, -0.64, 4.05, 0.31, 0.28), (s * 0.86, -0.76, 3.68, 0.29, 0.22), (s * 0.76, -0.82, 3.42, 0.19, 0.14)],
			(s * 0.76, -0.82, 3.34),
			(((s * 0.92, -0.86, 2.86), 0.16), ((s * 0.74, -0.92, 2.72), 0.18), ((s * 0.56, -0.88, 2.9), 0.15)),
		)
	# the third section, down the back
	_hank(
		k,
		"BackTail",
		[(0, 0.7, 4.7, 0.62, 0.3), (0, 0.86, 4.1, 0.58, 0.28), (0, 0.9, 3.45, 0.46, 0.25), (0, 0.9, 2.92, 0.24, 0.16)],
		(0, 0.9, 2.84),
		(((-0.26, 0.96, 2.24), 0.2), ((0.02, 1.0, 2.08), 0.22), ((0.28, 0.96, 2.26), 0.2)),
	)
	for i, (x, z) in enumerate(((-0.82, 4.26), (-0.46, 4.1), (0.0, 4.5), (0.46, 4.12), (0.82, 4.22))):
		gem(k, "Head", f"BackLock{i}", (x * 0.8, 0.8, 5.56), (x, 1.04, z), 0.3, flat=0.32, twist=0.3, across=(1, 0, 0), a=0.5)


def _tunic(k):
	t = "UpperTorso"
	torso_core(k)
	_shell(k, t, "Tunic", [(0, 0, 4.0, 0.96, 0.5), (0, 0, 3.93, 1.07, 0.58), (0, 0, 3.3, 1.08, 0.59), (0, 0, 2.5, 1.11, 0.61), (0, 0, 1.72, 1.2, 0.68)], "Torso", 4.0, 1.72, zig=0.045, jit=0.018, sub=2)
	# a raised round neck
	outer, inner = [], []
	for i in range(9):
		a = math.pi * i / 8
		outer.append((0.54 * math.cos(a), 4.0 - 0.4 * math.sin(a)))
		inner.append((0.44 * math.cos(a), 4.0 - 0.3 * math.sin(a)))
	prism(k, t, "NeckRim", outer + inner[::-1], -0.625, -0.57, "cloth", a=0.6, b=0.4)


def _bare_arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	k.reshape(arm, f"{side}Arm", [(ax, 0, 3.98, 0.42, 0.42), (ax, 0, 3.9, 0.5, 0.5), (ax, 0, 2.3, 0.5, 0.5)], corner=0.12, nc=1)
	block(k, arm, "Hand", ax, 0, 2.38, 1.78, 0.5, 0.5, "skin", ch=0.06, a=0.6, b=0.3)
	return arm, ax


def _torn_sleeve(k):
	"""His left sleeve, ripped into three: a strap left over the shoulder and two strips wound round the bare arm."""
	arm, ax = _bare_arm(k, "Left", 1)
	block(k, arm, "Strap", 1.16, 0, 4.08, 3.7, 0.22, 0.56, "cloth", ch=0.04, corner=0.16, jit=0.012, a=0.5, b=0.56)
	for i, (z, h, tilt, off) in enumerate(((3.42, 0.14, 0.09, 0.0), (3.1, 0.12, -0.07, 0.015))):
		o = block(k, arm, f"Strip{i}", ax, 0, z + h, z - h, 0.57 + off, 0.57 + off, "cloth", ch=0.03, corner=0.2, sub=1, jit=0.012, a=0.48, b=0.58)
		for v in o.data.vertices:
			v.co.z += (v.co.x - ax) * tilt
		o.data.update()
	# the torn ends hang off the strips, on the outside and the front
	gem(k, arm, "EndA", (ax + 0.5, -0.22, 3.36), (ax + 0.62, -0.3, 2.84), 0.17, "cloth", flat=0.3, across=(0, 1, 0), a=0.46, b_=0.5)
	gem(k, arm, "EndB", (ax + 0.1, -0.56, 3.04), (ax + 0.22, -0.62, 2.68), 0.15, "cloth", flat=0.3, across=(1, 0, 0), a=0.46, b_=0.5)


def _big_sleeve(k):
	"""His right sleeve hangs huge and loose, wider than the arm, a long ragged tail falling behind it."""
	arm, ax = _bare_arm(k, "Right", -1)
	top, hem = 4.06, 2.5
	o = _shell(k, arm, "Sleeve", [(ax + 0.04, 0, top, 0.5, 0.5), (ax, 0, 3.96, 0.62, 0.6), (ax - 0.1, 0, 3.4, 0.78, 0.68), (ax - 0.18, 0, 2.95, 0.88, 0.74), (ax - 0.24, 0, hem, 0.96, 0.78)], "RightArm", top, hem, art=(4.0, 2.54), zig=0.05, jit=0.016, sub=2)
	# the back of the hem falls far lower, into a long tail
	for v in o.data.vertices:
		v.co.z -= ((top - v.co.z) / (top - hem)) ** 2 * max(0.0, v.co.y + 0.2) * 0.62
	o.data.update()


def _shoe(k, leg, px):
	block(k, leg, "Shoe", px, -0.04, 0.42, 0.12, 0.5, 0.58, "shoe", ch=0.05, a=0.6, b=0.3, jit=0.008)
	block(k, leg, "Toe", px, -0.5, 0.3, 0.12, 0.46, 0.26, "shoe", ch=0.08, corner=0.32, a=0.66, b=0.3)
	block(k, leg, "Sole", px, -0.12, 0.13, 0.0, 0.53, 0.7, "sole", ch=0.03, a=0.5)
	# the black stripe up the vamp and the tab at the heel
	block(k, leg, "StripeTop", px, -0.3, 0.435, 0.415, 0.06, 0.24, "stripe", ch=0.008, a=0.5)
	block(k, leg, "StripeFront", px, -0.6, 0.325, 0.3, 0.055, 0.17, "stripe", ch=0.006, a=0.5)
	block(k, leg, "HeelTab", px, 0.54, 0.42, 0.14, 0.13, 0.045, "stripe", ch=0.01, a=0.5)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	_hair(k)
	_tunic(k)
	_torn_sleeve(k)
	_big_sleeve(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		leg, px = trouser(k, side, s, low=0.48)
		block(k, leg, "Cuff", px, 0, 0.6, 0.36, 0.56, 0.62, "navy", ch=0.04, corner=0.18, jit=0.012, sub=1, a=0.5, b=0.56)
		_shoe(k, leg, px)
	finish()


# ---- paint


def seam(f, x0, y0, cx, cy, x1, y1, knots, line=1.1, tick=4.4, w=1.6, gap=3.0, colour=SEAM):
	"""A sewn seam along a curve: a thin cut, then at each t in knots a pair of thread crossings at right angles to it."""
	stroke(f, f"M{x0} {y0}Q{cx} {cy} {x1} {y1}", colour, line)
	for t in knots:
		x = (1 - t) ** 2 * x0 + 2 * t * (1 - t) * cx + t**2 * x1
		y = (1 - t) ** 2 * y0 + 2 * t * (1 - t) * cy + t**2 * y1
		dx, dy = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx), 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
		d = math.hypot(dx, dy) or 1
		ax, ay = dx / d, dy / d
		for g in (-gap, gap):
			px, py = x + ax * g, y + ay * g
			stroke(f, f"M{px - ay * tick:.1f} {py + ax * tick:.1f}L{px + ay * tick:.1f} {py - ax * tick:.1f}", THREAD, w)


def grid(f, step=40, dark=0.5):
	"""The tunic's cloth: navy, each cell a soft pillow, a dark groove and a pale raised line both ways, a little off true as on hand-sewn cloth."""
	f.fill(CLOTH)
	rng = random.Random(f.name)
	xs = [step * (i + 0.5) for i in range(int(f.w // step) + 1)]
	ys = [step * (i + 0.5) for i in range(int(f.h // step) + 1)]
	for x in xs:
		for y in ys:
			f.soft(f"M{x + 6} {y + 6}h{step - 12}v{step - 14}h{-(step - 12)}Z", "#47528a", 0.3 + rng.uniform(0, 0.16), 3)
	jx = {x: rng.uniform(-3, 3) for x in xs}
	jy = {y: rng.uniform(-3, 3) for y in ys}
	for x in xs:
		x0, x1 = x + jx[x], x - jx[x] * 0.6
		stroke(f, f"M{x0 + 1.6} -5L{x1 + 1.6} {f.h + 5}", CLOTH_D, 3.2)
		stroke(f, f"M{x0} -5L{x1} {f.h + 5}", GRID, 1.4)
	for y in ys:
		y0, y1 = y + jy[y], y - jy[y] * 0.6
		stroke(f, f"M-5 {y0 + 1.6}L{f.w + 5} {y1 + 1.6}", CLOTH_D, 3.2)
		stroke(f, f"M-5 {y0}L{f.w + 5} {y1}", GRID, 1.4)
	form(f, op=dark)


def fold(f, x0, y0, cx, cy, x1, y1):
	"""A soft shadow where the cloth pulls: painted light, so the grid stays on top of the read."""
	f.soft(f"M{x0} {y0}Q{cx} {cy} {x1} {y1}Q{cx} {cy + 12} {x0} {y0 + 5}Z", CLOTH_D, 0.5, 2)


def _torso(a):
	f = a["Torso_F"]
	grid(f)
	fold(f, 6, 30, 40, 44, 74, 84)
	fold(f, 194, 32, 160, 46, 126, 86)
	fold(f, 40, 112, 32, 150, 44, 190)
	fold(f, 160, 114, 168, 150, 156, 190)
	# the round neck: skin, the neck seam drawn across it
	v = "M60 -5H140V2Q138 28 100 32Q62 28 60 2Z"
	f.path(v, SKIN)
	f.soft("M58 -5H142V7Q100 15 58 7Z", SKIN_D, 0.85, 2)
	f.soft("M60 8Q66 30 100 32Q70 22 66 8Z", SKIN_D, 0.5, 1)
	seam(f, 64, 14, 100, 26, 136, 12, (0.2, 0.55, 0.85), line=1.2, tick=3.6, w=1.5, gap=2.6)
	f = a["Torso_B"]
	grid(f)
	fold(f, 6, 54, 40, 74, 84, 110)
	fold(f, 194, 56, 160, 76, 116, 112)
	for n in ("Torso_L", "Torso_R"):
		grid(a[n])
	a["Torso_T"].fill(shade(CLOTH, 1.2))
	a["Torso_Bo"].fill(CLOTH_D)


def _skin_face(f):
	f.fill(SKIN)
	f.soft("M-5 -5H16V215H-5Z", SKIN_D, 0.55, 3)
	f.soft("M105 -5H82V215H105Z", SKIN_D, 0.7, 3)
	f.soft("M-5 96H105V112H-5Z", SKIN_D, 0.35, 3)


def _limbs(a):
	# his left, all skin: rings at the elbow, forearm and wrist, a long diagonal up the outside and the front
	for key in "FBOI":
		f = a[f"LeftArm_{key}"]
		_skin_face(f)
		seam(f, -4, 62, 50, 58, 104, 62, (0.2, 0.75), line=1.6, tick=5.5, w=2.2, gap=4)
		seam(f, -4, 112, 50, 118, 104, 112, (0.3, 0.8), line=1.6, tick=5.5, w=2.2, gap=4)
		seam(f, -4, 158, 50, 152, 104, 158, (0.25, 0.7), line=1.6, tick=5.5, w=2.2, gap=4)
		if key in "FO":
			seam(f, 24, 2, 58, 22, 70, 50, (0.45,), line=1.6, tick=5.5, w=2.2, gap=4)
			seam(f, 70, 118, 54, 134, 30, 154, (0.5,), line=1.6, tick=5.5, w=2.2, gap=4)
	a["LeftArm_T"].fill(SKIN)
	a["LeftArm_Bo"].fill(SKIN_D)
	# his right: the big sleeve's cloth over the top of the face, the bare wrist under it
	for key in "FBOI":
		f = a[f"RightArm_{key}"]
		_skin_face(f)
		seam(f, -4, 170, 50, 166, 104, 170, (0.25, 0.7), line=1.6, tick=5.5, w=2.2, gap=4)
		f.out.append('<clipPath id="k%s"><rect x="-5" y="-5" width="110" height="155"/></clipPath><g clip-path="url(#k%s)">' % (f.name, f.name))
		grid(f, dark=0.4)
		fold(f, 96, 20, 74, 40, 40, 62)
		fold(f, 4, 84, 28, 100, 56, 124)
		f.out.append("</g>")
	a["RightArm_T"].fill(shade(CLOTH, 1.2))
	a["RightArm_Bo"].fill(CLOTH_D)
	for side in ("Left", "Right"):
		for key in "FBOI":
			g = a[f"{side}Leg_{key}"]
			g.fill("#20264a")
			form(g, op=0.5)
		a[f"{side}Leg_T"].fill("#20264a")
		a[f"{side}Leg_Bo"].fill("#0a0d1e")


def _face(f):
	face_base(f, SKIN, SKIN_D, blush="#e0b2a0", top=14)
	# the sewn-on pieces: left of the long seam, and the cheek under the cross seam on the other side
	f.path("M-5 -5H26Q34 40 34 70Q30 100 40 135H-5Z", PATCH, opacity=0.8)
	f.path("M84 70L135 66V135H100Q88 104 84 70Z", PATCH, opacity=0.8)
	# thin pale brows
	for s, x in ((-1, 38), (1, 92)):
		f.path(f"M{x - s * 16} 38Q{x} 29 {x + s * 19} 33Q{x} 33 {x - s * 16} 40Z", "#6f8a9e")
	# wide hollow half-lidded eyes: grey on his right, dark blue on his left
	eye2(f, 38, 53, -1, 37, 17, "#8c98a6", tilt=2.0, r=12.5, lid=0.12, lash="#1e1a28", lash_t=3.0, flick=3.6, sclera="#fbf8f2", pupil=0.4, crease_line=False)
	eye2(f, 92, 53, 1, 37, 17, "#26408c", tilt=2.0, r=12.5, lid=0.12, lash="#1e1a28", lash_t=3.0, flick=3.6, sclera="#fbf8f2", pupil=0.4, crease_line=False)
	# the tired lines under them
	for s, x in ((-1, 38), (1, 92)):
		stroke(f, f"M{x - s * 14} 66Q{x} 71 {x + s * 16} 62", shade(SKIN, 0.62), 1.0)
		stroke(f, f"M{x - s * 7} 70Q{x + s * 3} 73 {x + s * 12} 69", shade(SKIN, 0.72), 0.8)
	# a small straight nose
	f.path("M63 66L69 83L61 85Q64 76 63 66Z", shade(SKIN, 0.76), opacity=0.9)
	stroke(f, "M60 85Q65 87 70 84", shade(SKIN, 0.5), 1.0)
	# the grin: wide and open, higher on one side
	mouth = "M40 89Q64 95 92 83Q89 106 67 109Q47 108 40 89Z"
	f.path(mouth, "#34101a", stroke="#1e1018", sw=1.2)
	f.path("M43 90Q64 95.6 89 84.6Q88 91 84 93Q65 99 48 97Q44 95 43 90Z", "#f8f4ec")
	for x, y in ((52, 92.5), (60, 93.3), (68, 93.5), (76, 92.5), (83, 90)):
		stroke(f, f"M{x} {y}V{y + 4.5}", "#b8aca4", 0.6)
	f.path("M55 108.5Q67 100 81 104Q76 108 67 109Q60 109 55 108.5Z", "#c8606e")
	stroke(f, "M40 89Q37 87 36 83", "#1e1018", 1.3)
	stroke(f, "M92 83Q95 80 95 76", "#1e1018", 1.3)
	# the long seam: forehead, down through the grey eye's inner edge, past the nose to the mouth corner
	seam(f, 30, -2, 32, 30, 25, 44, (0.5,))
	seam(f, 26, 66, 22, 82, 30, 100, (0.42, 0.85))
	# the cross seam: cheek to cheek over the bridge of the nose, just under the eyes
	seam(f, -4, 76, 30, 68, 64, 70, (0.24, 0.72))
	seam(f, 64, 70, 96, 68, 134, 76, (0.36, 0.78))
	# one more on the forehead
	seam(f, 86, 4, 88, 14, 84, 28, (0.5,))


def paint(a):
	R.paint(a)
	_face(a["Head_F"])
	head_rest(a, shade(SKIN, 0.82), shade(SKIN, 0.72))
	a["Head_T"].fill("#a9c8d6")
	_torso(a)
	_limbs(a)
