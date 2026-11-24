# Target look kit for the fr_ series (design doc section 5): the shared solids plus what these travellers and mages wear: an open coat,
# a back cape, a skirt that rides the legs, staffs, horns, long hair. Hair and faces stay in each char_<id>.py. bpy stays lazy: atlas.py runs this under python3.
from atlas import shade
from char_boss_mage import rod, wrap  # noqa: F401
from ds_style3 import eye, xf
from jk_common import brow2, form
from jk_style3 import bake, crown, jacket, torso_core  # noqa: F401
from solo_style3 import Kit, Ramps, big_head, block, boot, collar, ears, finish, gem, head_rest, prism, rblock, slab, sleeve, trouser  # noqa: F401

T = "UpperTorso"


def locks(k, tag, root, rows, **kw):
	"""A fringe: flat locks from one root (or their own) over the brow. rows = (tip, radius) or (root, tip, radius)."""
	for i, row in enumerate(rows):
		b, t, r = row if len(row) == 3 else (root, *row)
		gem(k, "Head", f"{tag}{i}", b, t, r, **dict(dict(flat=0.38, twist=0.12 + 0.05 * (i % 3), a=0.5 + 0.04 * (i % 2), across=(1, 0, 0)), **kw))


def helmet(k, low=4.5, ramp="hair", back_y=0.3, scalp=None, brow=5.2):
	"""The scalp under the locks: a dome, a cap over the skull, a solid back down to low."""
	crown(k, [(0.98, 5.4), (1.05, 5.6), (1.0, 5.84), (0.68, 6.04), (0.2, 6.12)], ramp)
	block(k, "Head", "Cap", 0, 0.06, 5.7, brow, 1.0, 0.88, ramp, ch=0.08, corner=0.3, a=0.46, b=0.42)
	block(k, "Head", "Scalp", 0, (0.98 + back_y) / 2, 5.4, low, 1.0, (0.98 - back_y) / 2, scalp or ramp, ch=0.08, corner=0.25, a=0.44, b=0.42)


def pleat(k, part, name, rows, ramp, n=5, depth=0.07, d=1, curl=0.0, ragged=0.0, th=0.14, **bk):
	"""One continuous folded sheet: ridges run the whole way down. rows = (z, centre x, y, half width), top first. d +1 faces the back,
	-1 the front; curl wraps its sides round the body; ragged ends every ridge in a point."""
	rings, m = [], 2 * n
	for ri, (z, cx, y, hw) in enumerate(rows):
		last = ri == len(rows) - 1
		amp = depth * min(1.0, 0.35 + ri * 0.35)
		out, inn = [], []
		for j in range(m + 1):
			u = 2 * j / m - 1
			base = y - d * curl * u**4
			zz = z + (ragged * (-1.0 - 0.5 * (j % 4 == 1) if j % 2 else 0.6) if last else 0.0)
			out.append((cx + u * hw, base + d * (amp if j % 2 else -amp), zz))
			inn.append((cx + u * hw * 0.98, base - d * th, zz))
		rings.append(out + inn[::-1])
	verts, faces, flat = k._loft(rings)
	return bake(k._mesh(name, part, verts, faces, flat, outline=0), ramp, k, **dict(dict(a=0.52, b=0.5, g=0.12), **bk))


def mane(k, low, ramp="hair", mid=1.05, end=0.8, y=1.0, n=5):
	"""Long hair down the back: one layered fall from the crown to uneven points."""
	rows = [(6.0, 0, 0.3, 0.42), (5.72, 0, 0.74, 0.72), (5.2, 0, y, 0.94), (4.4, 0, y + 0.06, mid), ((4.4 + low) / 2, 0, y + 0.1, (mid * 1.1 + end) / 2), (low, 0, y + 0.14, end)]
	pleat(k, "Head", "Mane", rows, ramp, n=n, depth=0.09, curl=0.24, ragged=0.24, th=0.2, a=0.54, b=0.5)


def elf_ears(k, out=1.72, up=5.16):
	for s, tag in ((1, "L"), (-1, "R")):
		gem(k, "Head", f"Ear{tag}", (s * 0.84, 0.0, 4.72), (s * out, 0.16, up), 0.2, ramp="skin", flat=0.3, twist=0.0, a=0.6, across=(0, 0, 1))


def horns(k, pts, r, ramp="horn"):
	for s in (1, -1):
		rod(k, "Head", f"Horn{s}", [(s * x, y, z) for x, y, z in pts], r, ramp, n=6, a=0.52, b=0.46)


def skirt(k, ramp, hem, trim=None, flare=0.1, w=0.56, d=0.64, th=0.14):
	"""A skirt or robe in two halves that ride the legs, so it never clips when they swing."""
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		block(k, leg, "Skirt", s * w, 0, 2.03, hem, w, d, ramp, ch=0.02, flare=flare, corner=0.12, sub=1, jit=0.015, mids=((2 + hem) / 2,), a=0.5, b=0.5, g=0.12)
		if trim:
			block(k, leg, "SkirtTrim", s * w, 0, hem + th, hem - 0.02, w + flare + 0.015, d + flare + 0.015, trim, ch=0.02, corner=0.12, a=0.56, b=0.42)


def open_coat(k, ramp, trim, hem, gap=0.4, low_gap=0.5, back_ramp=None):
	"""A coat open down the front: a back and sides, two front panels with a trim band, and panels that ride the legs to hem."""
	block(k, T, "CoatBody", 0, 0.23, 4.06, 1.94, 1.12, 0.46, back_ramp or ramp, ch=0.05, corner=0.14, sub=1, jit=0.015, a=0.5, b=0.46, g=0.1)
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		prism(k, T, f"Panel{s}", [(s * gap, 4.06), (s * 1.12, 4.06), (s * 1.12, 1.94), (s * low_gap, 1.94)], -0.7, -0.2, ramp, a=0.5, b=0.5)
		prism(k, T, f"Band{s}", [(s * (gap - 0.1), 4.06), (s * (gap + 0.04), 4.06), (s * (low_gap + 0.04), 1.94), (s * (low_gap - 0.1), 1.94)], -0.74, -0.62, trim, a=0.54, b=0.46)
		w = (1.16 - low_gap) / 2
		block(k, leg, "CoatF", s * (low_gap + w), -0.7, 2.0, hem, w, 0.06, ramp, ch=0.02, flare=0.04, a=0.5, b=0.5, g=0.1)
		block(k, leg, "CoatFB", s * (low_gap - 0.02), -0.74, 2.0, hem, 0.07, 0.05, trim, ch=0.015, a=0.54, b=0.46)
		block(k, leg, "CoatS", s * 1.14, 0, 2.0, hem, 0.07, 0.74, ramp, ch=0.02, flare=0.04, a=0.48, b=0.5, g=0.1)
		block(k, leg, "CoatB", s * 0.57, 0.68, 2.0, hem, 0.64, 0.07, back_ramp or ramp, ch=0.02, flare=0.04, a=0.5, b=0.46, g=0.1)
		for tag, x, y, hw, hd in (("F", low_gap + w, -0.71, w + 0.05, 0.075), ("S", 1.15, 0, 0.1, 0.76), ("B", 0.57, 0.69, 0.66, 0.1)):
			block(k, leg, "CoatHem" + tag, s * x, y, hem + 0.1, hem - 0.02, hw, hd, trim, ch=0.02, a=0.52, b=0.46)


def cape(k, ramp, lining, hem, trim=None, w=0.74, y=0.78):
	"""A cape down the back, wider than the body so it shows from the front; below the waist it rides the legs."""
	pleat(k, T, "CapeTop", [(4.1, 0, y, 1.06), (3.2, 0, y + 0.04, 1.16), (1.96, 0, y + 0.06, 1.3)], ramp, n=6, depth=0.08, th=0.1)
	pleat(k, T, "CapeIn", [(4.0, 0, y - 0.1, 1.04), (1.98, 0, y - 0.06, 1.28)], lining, n=2, depth=0.02, d=-1, th=0.04)
	for s, side in ((1, "Left"), (-1, "Right")):
		leg = f"{side}UpperLeg"
		pleat(k, leg, "Cape", [(2.03, s * 0.65, y + 0.06, 0.65), ((2 + hem) / 2, s * 0.7, y + 0.1, 0.72), (hem, s * 0.74, y + 0.13, 0.8)], ramp, n=3, depth=0.08, th=0.1)
		pleat(k, leg, "CapeIn", [(2.0, s * 0.65, y - 0.06, 0.63), (hem + 0.04, s * 0.74, y + 0.0, 0.78)], lining, n=2, depth=0.02, d=-1, th=0.04)
		if trim:
			block(k, leg, "CapeTrim", s * w * 0.95, y + 0.08, hem + 0.14, hem - 0.02, w * 0.95 + 0.14, 0.19, trim, ch=0.02, a=0.56, b=0.42)


def turned(fn, pivot, rx=0.0, ry=0.0, rz=0.0, scale=1.0, move=(0, 0, 0)):
	"""Runs fn, then scales, turns and moves everything it built: a held prop drawn upright first."""
	import bpy

	before = set(bpy.data.objects)
	fn()
	for o in set(bpy.data.objects) - before:
		for v in o.data.vertices:
			v.co = [pivot[i] + (v.co[i] - pivot[i]) * scale for i in range(3)]
		xf(o, pivot, rx, ry, rz)
		for v in o.data.vertices:
			v.co = [v.co[i] + move[i] for i in range(3)]


# ---- paint


def face(f, skin, dark, iris, lash, brow, mouth, w=34, up=13, dn=10, inner=3.0, outer=-3.0, ir=(10.5, 13), lid=0.26, wing=4.5, thick=1.2, cy=67, brow_y=44, brow_w=30, brow_t=3.6, tilt=1.2, arc=-1.5, blush=0.18, pu=(3.2, 4.8), cx=28):
	"""Skin shading, two sharp eyes, brows, nose and mouth; every number is the character's own."""
	f.fill(skin)
	f.soft("M-5-5H135V28Q65 36 -5 28Z", dark, 0.65, 3)
	f.soft("M-5 30H9Q5 90 28 135H-5Z", dark, 0.5, 5)
	f.soft("M135 30H121Q125 90 102 135H135Z", dark, 0.65, 5)
	f.soft("M30 124Q65 116 100 124V135H30Z", dark, 0.45, 3)
	if blush:
		f.soft("M14 82Q28 76 36 90Q26 98 14 92Z", "#f08878", blush, 3)
		f.soft("M116 82Q102 76 94 90Q104 98 116 92Z", "#f08878", blush, 3)
	for s in (-1, 1):
		eye(f, 65 + s * cx, cy, s, iris, w=w, up=up, dn=dn, inner=inner, outer=outer, ir=ir, pu=pu, lash=lash, wing=wing, thick=thick, lid=lid)
		brow2(f, 65 + s * cx, brow_y, s, brow_w, brow_t, tilt, brow, arc=arc)
	f.soft("M60 88L65 80L70 88Q65 92 60 88Z", dark, 0.5, 1)
	f.path("M61 89Q65 91 69 89", stroke=shade(dark, 0.8), sw=1.0)
	f.path(mouth, stroke="#8a4440", sw=2.0)


def scalp(a, colour):
	"""The head block's own paint is hair above and behind the cheeks, so a gap between locks never shows skin."""
	a["Head_T"].fill(colour)
	a["Head_B"].fill(colour)
	a["Head_L"].path("M-5-5H125V135H66V46H-5Z", colour)
	a["Head_R"].path("M125-5H-5V135H54V46H125Z", colour)


def fill_body(a, skin, skin_d, torso, arm, leg, top, hand=None):
	"""Every body face under the garments, so nothing pale peeks out."""
	head_rest(a, shade(skin, 0.84), shade(skin, 0.62))
	scalp(a, top)
	for n in "FBLR":
		a[f"Torso_{n}"].fill(torso)
		form(a[f"Torso_{n}"], shade(torso, 0.5), 0.45)
	a["Torso_T"].fill(torso)
	a["Torso_Bo"].fill(shade(torso, 0.6))
	for side in ("Left", "Right"):
		for key in "FBOI":
			a[f"{side}Arm_{key}"].fill(arm)
			a[f"{side}Leg_{key}"].fill(leg)
		a[f"{side}Arm_T"].fill(arm)
		a[f"{side}Arm_Bo"].fill(hand or skin_d)
		a[f"{side}Leg_T"].fill(leg)
		a[f"{side}Leg_Bo"].fill(shade(leg, 0.6))
