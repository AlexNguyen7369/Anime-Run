# Shared drawing for the leaf series: anime eyes cut by the lid, marks, hands, sandals and painted relief geometry.
# bpy-side imports stay inside functions: atlas.py runs this module in plain python.
import math

from atlas import INK, shade, swirl_d

STEEL = "#aab1ba"


def begin_clip(f, d):
	cid = f"k{f.name}{len(f.out)}"
	f.out.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath><g clip-path="url(#{cid})">')


def end_clip(f):
	f.out.append("</g>")


def ell(cx, cy, rx, ry=None):
	ry = rx if ry is None else ry
	return f"M{cx - rx:.2f} {cy:.2f}a{rx:.2f} {ry:.2f} 0 1 0 {2 * rx:.2f} 0a{rx:.2f} {ry:.2f} 0 1 0 {-2 * rx:.2f} 0Z"


def tomoe(f, cx, cy, r, n=3, colour="#0c0a10", a0=-90):
	"""The three-comma red eye pattern."""
	for i in range(n):
		a = math.radians(a0 + i * 360 / n)
		x, y = cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a)
		s = r * 0.24
		f.path(ell(x, y, s), colour)
		b = a + 1.15
		f.path(f"M{x + s * math.cos(a):.2f} {y + s * math.sin(a):.2f}Q{x + s * 1.9 * math.cos(b):.2f} {y + s * 1.9 * math.sin(b):.2f} {x + s * 2.3 * math.cos(a + 2.1):.2f} {y + s * 2.3 * math.sin(a + 2.1):.2f}Q{x + s * math.cos(a + 1.9):.2f} {y + s * math.sin(a + 1.9):.2f} {x - s * math.cos(a):.2f} {y - s * math.sin(a):.2f}Z", colour)


def ani_eye(f, cx, cy, sgn, iris, w=24, h=12, tilt=3, lid=3, ir=None, look=0, dy=-1, pupil=0.42, flick=2.5, sclera="#f2eee6", lash=INK, glint=True, style=None, lower=0.8, peak=0.05):
	"""A sharp eye: iris cut by the upper lid. sgn +1 = eye on the viewer's right, tilt lifts the outer corner."""
	ix, ox = cx - sgn * w / 2, cx + sgn * w / 2
	iy, oy = cy + tilt * 0.6, cy - tilt * 0.6
	tx, ty = cx - sgn * w * peak, cy - h * 1.1
	bx, by = cx + sgn * w * 0.1, cy + h * 0.85
	shape = f"M{ix:.2f} {iy:.2f}Q{tx:.2f} {ty:.2f} {ox:.2f} {oy:.2f}Q{bx:.2f} {by:.2f} {ix:.2f} {iy:.2f}Z"
	f.path(shape, sclera)
	begin_clip(f, shape)
	r = ir or h * 0.66
	gx, gy = cx + look, cy + dy
	f.path(ell(gx, gy, r, r * 1.12), shade(iris, 0.55))
	f.path(ell(gx, gy + r * 0.12, r * 0.84, r * 0.9), iris)
	f.path(f"M{gx - r} {gy + r * 0.2}Q{gx} {gy + r * 1.25} {gx + r} {gy + r * 0.2}Q{gx} {gy + r * 0.7} {gx - r} {gy + r * 0.2}Z", shade(iris, 1.45), opacity=0.8)
	if style == "red":
		f.path(ell(gx, gy, r * 0.84, r * 0.92), stroke="#0c0a10", sw=0.5)
		tomoe(f, gx, gy, r * 0.82)
		f.path(ell(gx, gy, r * 0.2), "#0c0a10")
	else:
		f.path(ell(gx, gy, r * pupil, r * pupil * 1.1), "#08070c")
	f.path(f"M{ix - 2} {cy - h}H{ox + sgn * 2}V{oy + 2.2}Q{tx} {ty + 3.6} {ix} {iy + 1}Z", "#1a1426", opacity=0.3)
	if glint:
		f.path(ell(gx - sgn * r * 0.35, gy - r * 0.3, r * 0.24), "#ffffff")
	end_clip(f)
	f.path(f"M{ix - sgn:.2f} {iy + 0.7:.2f}Q{tx:.2f} {ty - lid * 1.5:.2f} {ox + sgn * flick:.2f} {oy - flick * 0.3:.2f}Q{tx:.2f} {ty + lid * 0.25:.2f} {ix:.2f} {iy:.2f}Z", lash)
	f.path(f"M{ox + sgn * 0.5:.2f} {oy - 0.6:.2f}Q{bx + sgn * w * 0.2:.2f} {(by + oy) / 2:.2f} {bx:.2f} {cy + h * 0.46:.2f}Q{bx + sgn * w * 0.2:.2f} {(by + oy) / 2 + lower:.2f} {ox + sgn * 0.5:.2f} {oy - 0.6:.2f}Z", lash)


def ani_brow(f, cx, cy, sgn, colour, w=25, angry=4, thick=4, arch=2.5):
	"""Blunt at the inner end, tapering outward. angry drops the inner end."""
	ix, ox = cx - sgn * w / 2, cx + sgn * w / 2
	f.path(f"M{ix:.2f} {cy + angry:.2f}Q{cx:.2f} {cy - arch:.2f} {ox:.2f} {cy - angry * 0.3:.2f}Q{cx:.2f} {cy - arch + thick:.2f} {ix + sgn * 0.8:.2f} {cy + angry + thick * 0.72:.2f}Z", colour)


def face_shade(f, skin, top=46, cast=None):
	"""Skin with hard cel planes: hair shadow, temples, cheekbones, jaw."""
	w, h = f.w, f.h
	dark = shade(skin, 0.74)
	f.fill(skin)
	if top:
		zig = "".join(f"L{x} {top + (5 if i % 2 else -3)}" for i, x in enumerate(range(w - 10, 0, -14)))
		f.path(f"M-5-5H{w + 5}V{top}{zig}L-5 {top}Z", cast or dark)
	f.path(f"M-5 30H9Q6 74 14 96Q20 116 34 135H-5Z", dark, opacity=0.65)
	f.path(f"M{w + 5} 30H{w - 9}Q{w - 6} 74 {w - 14} 96Q{w - 20} 116 {w - 34} 135H{w + 5}Z", dark)
	f.path(f"M34 135Q65 120 96 135Z", dark)


def nose(f, skin, x=65, y=86, size=1.0, bridge=True):
	dark = shade(skin, 0.7)
	s = size
	if bridge:
		f.path(f"M{x + 1 * s} {y - 15 * s}L{x + 5 * s} {y - 1 * s}L{x + 5.5 * s} {y + 2 * s}L{x} {y + 2.5 * s}Q{x + 3 * s} {y - 8 * s} {x + 1 * s} {y - 15 * s}Z", dark, opacity=0.8)
	f.taper(x - 4 * s, y + 2 * s, x, y + 4.4 * s, x + 6 * s, y + 1.2 * s, 0.8, shade(skin, 0.38))


def strands(f, n, x0, x1, y0, y1, colour, width=1.1, lean=0.0, seed=None):
	"""Inked hair strands falling between two heights."""
	r = f.rng
	for i in range(n):
		x = x0 + (i + r.uniform(0.25, 0.75)) * (x1 - x0) / n
		a = y0 + r.uniform(0, 12)
		b = y1 - r.uniform(0, 14)
		f.taper(x, a, x + lean / 2 + r.uniform(-3, 3), (a + b) / 2, x + lean, b, width, colour)


def head_band_side(f, cloth, y0, y1, knot=False):
	"""The cloth band crossing a head side or back."""
	f.path(f"M-5 {y0}H{f.w + 5}V{y1}H-5Z", cloth)
	f.path(f"M-5 {y0}H{f.w + 5}V{y0 + 3}H-5Z", shade(cloth, 1.7))
	f.path(f"M-5 {(y0 + y1) / 2 + 2}H{f.w + 5}V{y1}H-5Z", shade(cloth, 0.6), opacity=0.7)
	f.ink(f"M-5 {y0}H{f.w + 5}M-5 {y1}H{f.w + 5}", 1.2)


def village_mark(f, cx, cy, r, colour=INK, sw=None, light=None):
	"""The village spiral with its leaf tip, cut into the plate."""
	sw = sw or r * 0.26
	d = swirl_d(cx, cy, r, turns=2.0, a0=math.radians(-200))
	tip = f"M{cx - r * 0.98:.2f} {cy - r * 0.32:.2f}L{cx - r * 0.42:.2f} {cy - r * 1.42:.2f}L{cx + r * 0.2:.2f} {cy - r * 0.98:.2f}"
	if light:
		f.path(d, stroke=light, sw=sw, opacity=0.8)
		f.path(tip, stroke=light, sw=sw, opacity=0.8)
	off = f"translate(0 {-sw * 0.28:.2f})"
	f.out.append(f'<g transform="{off}">')
	f.path(d, stroke=colour, sw=sw)
	f.path(tip, stroke=colour, sw=sw)
	f.out.append("</g>")


def steel_plate(f, x0, y0, x1, y1, slash=False):
	"""The forehead plate: brushed steel, bevel, four rivets, the village mark."""
	w = x1 - x0
	h = y1 - y0
	f.path(f"M{x0} {y0}H{x1}V{y1}H{x0}Z", STEEL, stroke=INK, sw=1.6)
	f.path(f"M{x0} {y0}H{x1}V{y0 + h * 0.42}Q{(x0 + x1) / 2} {y0 + h * 0.6} {x0} {y0 + h * 0.5}Z", "#d9dee4")
	f.path(f"M{x0} {y1}H{x1}V{y1 - h * 0.2}H{x0}Z", "#6d747e")
	f.path(f"M{x1} {y0}V{y1}H{x1 - w * 0.09}V{y0}Z", "#7a818b", opacity=0.8)
	f.path(f"M{x0 + w * 0.14} {y0 + 2}L{x0 + w * 0.28} {y1 - 3}", stroke="#f4f6f8", sw=1.1, opacity=0.8)
	for x in (x0 + w * 0.06, x1 - w * 0.06):
		for y in (y0 + h * 0.2, y1 - h * 0.2):
			f.path(ell(x, y, 1.5), "#50565e", stroke=INK, sw=0.5)
	village_mark(f, (x0 + x1) / 2 + 0.5, (y0 + y1) / 2 + h * 0.1, h * 0.25, "#272b33", light="#eef1f4")
	if slash:
		f.path(f"M{x0 + 7} {(y0 + y1) / 2 + 3}L{x1 - 7} {(y0 + y1) / 2 - 2}", stroke=INK, sw=2.6)
		f.path(f"M{x0 + 7} {(y0 + y1) / 2 + 4.6}L{x1 - 7} {(y0 + y1) / 2 - 0.4}", stroke="#f4f6f8", sw=0.8)


def front_dir(side, key):
	"""Which way the character's front lies on a limb's side view: -1 viewer's left, +1 viewer's right."""
	return -1 if (side == "Left") == (key == "O") else 1


def hand(f, key, side, skin, y0=170, nails=None, glove=None, knuckle=None):
	"""A hand on a 100-wide arm face. glove is a fingerless glove colour."""
	dark = shade(skin, 0.68)
	line = shade(skin, 0.42)
	f.path(f"M-5 {y0}H105V210H-5Z", skin)
	f.path(f"M-5 {y0}H105V{y0 + 5}Q50 {y0 + 9} -5 {y0 + 5}Z", dark, opacity=0.8)
	f.path(f"M-5 198Q50 202 105 198V210H-5Z", dark)
	if key in "FB":
		if glove:
			f.path(f"M-5 {y0}H105V190Q50 194 -5 190Z", glove)
			f.ink("M-5 190Q50 194 105 190", 1.2)
			for x in (26, 50, 74):
				f.taper(x, 184, x + 1, 189, x, 193, 0.7, shade(glove, 1.9))
		else:
			for x in (24, 50, 76):
				f.taper(x - 2, y0 + 8, x, y0 + 11, x + 2, y0 + 8, 0.7, line)
		for x in (25, 50, 75):
			f.taper(x, 190, x + 0.8, 198, x, 207, 1.1, line)
		if nails:
			for x in (12, 37, 62, 88):
				f.path(f"M{x - 5} 201H{x + 5}V207H{x - 5}Z", nails, stroke=INK, sw=0.5)
	elif key == "I":
		f.path(f"M16 {y0 + 4}Q34 {y0 + 2} 46 {y0 + 14}Q52 {y0 + 26} 42 {y0 + 28}Q28 {y0 + 26} 18 {y0 + 20}Z", shade(skin, 1.06), stroke=INK, sw=1.2)
		f.taper(58, y0 + 18, 76, y0 + 12, 90, y0 + 16, 0.8, line)
	else:
		f.taper(14, y0 + 20, 50, y0 + 14, 88, y0 + 22, 0.8, line)
		f.taper(70, 194, 80, 200, 92, 202, 0.7, line)


def sandal(f, key, side, strap, skin, y0=170, nails=None, sole="#14141a"):
	"""The open-toed ninja sandal on a 100-wide leg face."""
	dark = shade(strap, 0.62)
	light = shade(strap, 1.7)
	f.path(f"M-5 {y0}H105V205H-5Z", strap)
	if key == "F":
		f.path(f"M-5 {y0 + 13}H105V192H-5Z", skin)
		f.path(f"M-5 {y0 + 13}H105V{y0 + 19}H-5Z", shade(skin, 0.6))
		for x in (20, 38, 56, 75):
			f.taper(x, y0 + 15, x, 188, x + 1, 193, 1.0, shade(skin, 0.4))
		if nails:
			for x, wd in ((9, 8), (29, 5), (47, 5), (65, 5), (86, 6)):
				f.path(f"M{x - wd / 2} 185H{x + wd / 2}V190H{x - wd / 2}Z", nails, stroke=INK, sw=0.4)
		f.path(f"M-5 {y0}H105V{y0 + 13}H-5Z", strap)
		f.path(f"M-5 {y0 + 2}H105V{y0 + 5}H-5Z", light)
		f.ink(f"M-5 {y0 + 13}H105", 1.2)
	elif key == "B":
		f.path(f"M18 {y0 + 3}H82V192H18Z", skin)
		f.path(f"M18 {y0 + 3}H82V{y0 + 8}H18Z", shade(skin, 0.6))
		f.path(f"M-5 {y0}H105V{y0 + 3}H-5Z", light)
		f.ink(f"M18 {y0 + 3}V192M82 {y0 + 3}V192", 1.2)
		f.path(f"M-5 {y0 + 9}H105V{y0 + 15}H-5Z", dark, stroke=INK, sw=0.9)
	else:
		fd = front_dir(side, key)
		x0, x1 = (-5, 40) if fd < 0 else (60, 105)
		f.path(f"M{x0} {y0 + 12}H{x1}V192H{x0}Z", skin)
		f.path(f"M{x0} {y0 + 12}H{x1}V{y0 + 17}H{x0}Z", shade(skin, 0.6))
		f.path(f"M-5 {y0 + 2}H105V{y0 + 5}H-5Z", light)
		f.path(f"M-5 {y0 + 8}H105V{y0 + 12}H-5Z", dark)
		f.ink(f"M{x0 if fd > 0 else x1} {y0}V192", 1.1)
	f.path("M-5 192H105V205H-5Z", sole)
	f.path("M-5 192H105V194H-5Z", "#50505a")


def cloud_d(cx, cy, s):
	"""The puffy storm cloud of the crow's cloak: five lobes over a pointed tail."""
	a = lambda x, y: f"{cx + x * s:.2f} {cy + y * s:.2f}"
	r = lambda v: f"{v * s:.2f} {v * s:.2f}"
	return (
		f"M{a(-1.05, 0.4)}A{r(0.42)} 0 0 1 {a(-1.08, -0.3)}A{r(0.4)} 0 0 1 {a(-0.42, -0.5)}A{r(0.46)} 0 0 1 {a(0.3, -0.62)}"
		f"A{r(0.4)} 0 0 1 {a(0.92, -0.32)}A{r(0.4)} 0 0 1 {a(1.08, 0.32)}A{r(0.36)} 0 0 1 {a(0.58, 0.52)}"
		f"A{r(0.34)} 0 0 1 {a(0.02, 0.52)}A{r(0.34)} 0 0 1 {a(-0.52, 0.56)}A{r(0.3)} 0 0 1 {a(-1.05, 0.4)}Z"
	)


def cloud(f, cx, cy, s, red="#c0202a"):
	d = cloud_d(cx, cy, s)
	f.path(d, stroke=INK, sw=s * 0.42)
	f.path(d, stroke="#f6f2ea", sw=s * 0.3)
	f.path(d, red)
	f.path(f"M{cx - s * 0.9} {cy + s * 0.12}Q{cx} {cy + s * 0.56} {cx + s * 0.9} {cy + s * 0.12}Q{cx + s * 0.8} {cy + s * 0.52} {cx + s * 0.4} {cy + s * 0.46}Q{cx} {cy + s * 0.5} {cx - s * 0.5} {cy + s * 0.46}Z", shade(red, 0.62), opacity=0.8)


def fan(f, cx, cy, s, outline=INK):
	"""The clan fan: red dome over white, short handle."""
	f.path(f"M{cx - s * 0.13} {cy + s * 0.5}H{cx + s * 0.13}V{cy + s * 1.08}H{cx - s * 0.13}Z", "#f2eee6", stroke=outline, sw=s * 0.05)
	f.path(f"M{cx - s * 0.78} {cy + s * 0.14}A{s * 0.78} {s * 0.78} 0 1 1 {cx + s * 0.78} {cy + s * 0.14}Z", "#c8202a", stroke=outline, sw=s * 0.06)
	f.path(f"M{cx - s * 0.6} {cy - s * 0.32}Q{cx} {cy - s * 0.74} {cx + s * 0.3} {cy - s * 0.46}Q{cx - s * 0.2} {cy - s * 0.46} {cx - s * 0.6} {cy - s * 0.1}Z", "#ef6a5e", opacity=0.7)
	f.path(f"M{cx - s * 0.78} {cy + s * 0.14}H{cx + s * 0.78}Q{cx + s * 0.6} {cy + s * 0.68} {cx} {cy + s * 0.68}Q{cx - s * 0.6} {cy + s * 0.68} {cx - s * 0.78} {cy + s * 0.14}Z", "#f2eee6", stroke=outline, sw=s * 0.06)


def spike(az, el, length, r, bend=0.0, z=4.98, reach=0.8, flatten=0.62, colour=None, side=0.0):
	"""A hair lock leaving the skull. az: 0 front, 90 character's left, 180 back, 270 right. el: degrees above level."""
	a, e = math.radians(az), math.radians(el)
	dx, dy, dz = math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)
	b = [0.6 * reach * dx, 0.56 * reach * dy, z + 0.42 * reach * dz]
	t = [b[0] + dx * length + side, b[1] + dy * length, b[2] + dz * length]
	c = [(b[0] + t[0]) / 2, (b[1] + t[1]) / 2, (b[2] + t[2]) / 2 + bend]
	out = {"b": b, "c": c, "t": t, "r": r, "flatten": flatten}
	if colour:
		out["colour"] = colour
	return out


def lk(b, c, t, r, flatten=0.5, colour=None, mirror=False, **extra):
	out = {"b": list(b), "c": list(c), "t": list(t), "r": r, "flatten": flatten, **extra}
	if colour:
		out["colour"] = colour
	if mirror:
		out["mirror"] = True
	return out


# ---- bespoke geometry that carries the paint


def _axis(block, key):
	if key in ("F", "B"):
		return 1, key == "B"
	if key in ("T", "Bo"):
		return 2, key == "T"
	if key in ("L", "R"):
		return 0, key == "L"
	return 0, block.startswith("Left") == (key == "O")


def project(o, block, key=None):
	"""Maps a mesh onto its block's painted faces by world position, so it stands out of the art drawn under it.
	key forces one face (a plate: its rims take the colour of the art at its edge); None picks each polygon's face."""
	import atlas
	import avatar_paint

	_, _, size, centre, _ = next(b for b in avatar_paint.BLOCKS if b[0] == block)
	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	mat = o.matrix_basis.copy()
	rot = mat.to_3x3()
	clamp = lambda t: max(0.0, min(1.0, t))
	hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
	for poly in mesh.polygons:
		if key:
			k = key
			axis, positive = _axis(block, key)
		else:
			n = rot @ poly.normal
			axis = max(range(3), key=lambda a: abs(n[a]))
			positive = n[axis] > 0
			k = avatar_paint._face_key(block, axis, positive)
		x0, y0, pw, ph = atlas.FACES[f"{block}_{k}"][:4]
		for li in poly.loop_indices:
			c = mat @ mesh.vertices[mesh.loops[li].vertex_index].co
			cx, cy, cz = c.x - centre[0], c.y - centre[1], c.z - centre[2]
			if axis == 1:
				u = (cx + hx) / size[0] if not positive else (hx - cx) / size[0]
				t = (hz - cz) / size[2]
			elif axis == 0:
				u = (cy + hy) / size[1] if positive else (hy - cy) / size[1]
				t = (hz - cz) / size[2]
			else:
				u = (cx + hx) / size[0]
				t = (cy + hy) / size[1] if positive else (hy - cy) / size[1]
			uv[li].uv = ((x0 + 2 + clamp(u) * (pw - 4)) / atlas.SIZE, 1 - (y0 + 2 + clamp(t) * (ph - 4)) / atlas.SIZE)
	o["painted"] = True
	return o


def wrap(o, face):
	"""Stretches a whole mesh's front-view bounds over one atlas face: art for a piece that overhangs its block."""
	import atlas

	mesh = o.data
	uv = mesh.uv_layers.new(name="UVMap").data
	xs = [v.co.x for v in mesh.vertices]
	zs = [v.co.z for v in mesh.vertices]
	x0, y0, pw, ph = atlas.FACES[face][:4]
	for li, loop in enumerate(mesh.loops):
		c = mesh.vertices[loop.vertex_index].co
		u = (c.x - min(xs)) / (max(xs) - min(xs))
		t = (max(zs) - c.z) / (max(zs) - min(zs))
		uv[li].uv = ((x0 + 2 + u * (pw - 4)) / atlas.SIZE, 1 - (y0 + 2 + t * (ph - 4)) / atlas.SIZE)
	o["painted"] = True
	return o


def relief(kit, parts, part, name, block, size, at, key=None, bevel=0.025, rot=(0, 0, 0)):
	"""A box standing out of the block, wearing the art painted under it."""
	o = kit.rbox(f"{part}_{name}", size, at, "#808080", parts[part], bevel=bevel, rot=rot)
	return project(o, block, key)


def shard(kit, name, l, colour, parent, sides=4):
	"""A hair spike with planar facets and a straight taper: reads as a hard cel-shaded anime spike, where a round lock
	reads as a sausage. Lock data format, strands painted root to tip."""
	import bmesh
	from mathutils import Vector

	b, c, t = l["b"], l["c"], l["t"]
	r, flatten = l["r"], l.get("flatten", 0.5)
	rings = l.get("rings", 3)
	spine = [Vector(kit._bezier(b, c, t, i / rings)) for i in range(rings + 1)]
	bm = bmesh.new()
	prev = first = last_sd = None
	for i in range(rings):
		d = (spine[i + 1] - spine[i]).normalized()
		sd = d.cross(Vector((0, 0, 1)))
		if sd.length < 0.05:
			sd = last_sd or Vector((1, 0, 0))
		sd.normalize()
		if last_sd and sd.dot(last_sd) < 0:  # the spine passing vertical must not twist the section
			sd = -sd
		last_sd = sd
		up = sd.cross(d).normalized()
		rad = r * (1 - i / rings) ** l.get("taper", 1.0)
		ring = [bm.verts.new(spine[i] + sd * rad * math.cos(2 * math.pi * k / sides) + up * rad * flatten * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
		if prev:
			for k in range(sides):
				bm.faces.new((prev[k], prev[(k + 1) % sides], ring[(k + 1) % sides], ring[k]))
		else:
			first = ring
		prev = ring
	end = bm.verts.new(spine[-1])
	for k in range(sides):
		bm.faces.new((prev[k], prev[(k + 1) % sides], end))
	bm.faces.new(list(reversed(first)))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = bpy_mesh(name)
	bm.to_mesh(mesh)
	bm.free()
	o = kit._obj(name, mesh, colour, parent)
	o["lock"] = (list(b), list(t))
	return o


def bpy_mesh(name):
	import bpy

	return bpy.data.meshes.new(name)


def hair_model(kit, parts, shards, colour, tag="Shard"):
	for i, l in enumerate(shards):
		for sgn in (1, -1) if l.get("mirror") else (1,):
			m = {k: l[k] for k in ("r", "flatten", "rings", "taper") if k in l}
			m.update({k: [sgn * l[k][0], l[k][1], l[k][2]] for k in "bct"})
			shard(kit, f"Head_{tag}{i}{'L' if sgn > 0 else 'R'}", m, l.get("colour", colour), parts["Head"])


def side_hair(f, skin, hair, dark, back_right, edge=54, nape=118, top=30, ear=True, jag=True):
	"""A head side: skin at the front, the hair mass behind a jagged edge, inked ear on the hairline."""
	w, h = f.w, f.h
	fx = (lambda x: x) if back_right else (lambda x: w - x)
	f.fill(skin)
	f.path(f"M{fx(-5)} 108Q{fx(40)} 126 {fx(edge + 10)} 135H{fx(-5)}Z", shade(skin, 0.68))
	f.path(f"M{fx(edge * 0.2)} 40L{fx(edge * 0.1)} 110H{fx(-5)}V40Z", shade(skin, 0.86))
	pts = f"M{fx(-5)} -5H{fx(w + 5)}V{h + 5}H{fx(edge + 26)}"
	if jag:
		pts += f"L{fx(edge + 22)} {nape}L{fx(edge + 12)} {nape - 8}L{fx(edge + 8)} {nape + 4}L{fx(edge + 2)} {nape - 26}L{fx(edge - 6)} {nape - 18}L{fx(edge - 3)} {top + 34}L{fx(edge - 18)} {top + 14}"
	else:
		pts += f"L{fx(edge)} {nape}L{fx(edge)} {top + 10}"
	pts += f"L{fx(-5)} {top}Z"
	f.path(pts, hair)
	f.path(f"M{fx(edge + 20)} {top + 10}L{fx(edge + 30)} {nape}H{fx(w + 5)}V{top + 10}Z", dark, opacity=0.55)
	strands(f, 5, min(fx(edge + 8), fx(w)), max(fx(edge + 8), fx(w)), top + 8, nape + 8, shade(dark, 0.6))
	if ear:
		ex = fx(edge - 8)
		f.path(f"M{ex - 10} 68q10 -11 20 0q2 13 -6 23q-6 4 -9 -3q-6 -10 -5 -20Z", skin, stroke=INK, sw=1.4)
		f.ink(f"M{ex - 5} 72q5 -4 10 1q0 7 -4 12", 1.0, shade(skin, 0.5))


def pecs(f, skin, x0, x1, y0, y1):
	"""Bare chest: pectoral undercuts, sternum, abs, inked."""
	dark = shade(skin, 0.66)
	cx = (x0 + x1) / 2
	h = y1 - y0
	f.path(f"M{cx - 42} {y0 + h * 0.3}Q{cx - 18} {y0 + h * 0.54} {cx - 1} {y0 + h * 0.34}V{y0 + h * 0.42}Q{cx - 18} {y0 + h * 0.62} {cx - 42} {y0 + h * 0.38}Z", dark)
	f.path(f"M{cx + 42} {y0 + h * 0.3}Q{cx + 18} {y0 + h * 0.54} {cx + 1} {y0 + h * 0.34}V{y0 + h * 0.42}Q{cx + 18} {y0 + h * 0.62} {cx + 42} {y0 + h * 0.38}Z", dark)
	f.taper(cx, y0 + h * 0.06, cx + 1, y0 + h * 0.4, cx, y0 + h, 1.4, shade(skin, 0.42))
	for i in range(3):
		y = y0 + h * (0.6 + i * 0.15)
		f.taper(cx - 3, y, cx - 11, y + 2.5, cx - 18 + i * 3, y - 2, 1.0, shade(skin, 0.5))
		f.taper(cx + 3, y, cx + 11, y + 2.5, cx + 18 - i * 3, y - 2, 1.0, shade(skin, 0.5))
