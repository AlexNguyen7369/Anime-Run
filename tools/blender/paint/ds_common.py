# Shared cloth, face and shell helpers for the ds_ ids. Costume patterns are painted in the atlas on every face.
import math
import sys

import atlas
from atlas import FACES, INK, SIZE, shade, side_head

# Free atlas rows: the hanging coat skirt (F, outer, back run left to right) and small painted bits.
EXTRA = {
	"Coat": (480, 745, 390, 60, 300, 100),
	"CoatIn": (870, 745, 10, 60, 10, 60),
	"Extra": (1000, 600, 24, 120, 24, 120),
}
# atlas.py run as a script is __main__, a second copy of the module: both need the extra faces.
for _m in (atlas, sys.modules.get("__main__")):
	if hasattr(_m, "FACES"):
		_m.FACES.update(EXTRA)

UNI = "#1b1b27"
UNI_L = "#454560"
WRAP = "#ece9df"
_clips = [0]


def L(b, c, t, r, **kw):
	return dict(b=b, c=c, t=t, r=r, **kw)


def fore(tx, tz, r=0.24, rx=None, y=-0.7, top=5.5, **kw):
	"""A forelock: off the crown, over the brow, down to its tip at (tx, tz) on the forehead."""
	rx = tx if rx is None else rx
	return L([rx, -0.1, top + 0.02], [rx, y - 0.22, top - 0.24], [tx, y, tz], r, flatten=kw.pop("flatten", 0.42), **kw)


def dome(xs=(-0.44, 0.0, 0.44), r=0.36, top=5.86, back=0.76, low=4.86, **kw):
	"""Crown locks from over the brow to behind the head: the head's top reads round, never as a block."""
	return [L([x, -0.2, 5.14], [x * 1.08, 0.1, top], [x * 1.12, back, low], r, flatten=kw.get("flatten", 0.5), **{k: v for k, v in kw.items() if k != "flatten"}) for x in xs]


def tone(locks, colour):
	"""Locks without their own colour take the painted strand colour; the cap keeps the darker HAIR colour."""
	return [dict({"colour": colour}, **l) for l in locks]


# ---- svg helpers


def ell(cx, cy, rx, ry):
	return f"M{cx - rx:.2f} {cy:.2f}a{rx:.2f} {ry:.2f} 0 1 0 {2 * rx:.2f} 0a{rx:.2f} {ry:.2f} 0 1 0 {-2 * rx:.2f} 0Z"


def clip(f, d):
	_clips[0] += 1
	i = f"k{_clips[0]}"
	f.out.append(f'<clipPath id="{i}"><path d="{d}"/></clipPath><g clip-path="url(#{i})">')


def unclip(f):
	f.out.append("</g>")


# ---- patterns: all draw across the face's whole area, wobbled a little so they read as hand painted


def checks(f, a, b, s, ox=0, oy=0, wob=0.9):
	f.fill(a)
	w, h = f.w, f.h
	pt = {}
	r = f.rng

	def p(i, j):
		if (i, j) not in pt:
			pt[(i, j)] = (ox + i * s + r.uniform(-wob, wob), oy + j * s + r.uniform(-wob, wob))
		return "%.1f %.1f" % pt[(i, j)]

	d = ""
	for j in range(-1, int(h / s) + 2):
		for i in range(-1, int(w / s) + 2):
			if (i + j) % 2 == 0:
				d += f"M{p(i, j)}L{p(i + 1, j)}L{p(i + 1, j + 1)}L{p(i, j + 1)}Z"
	f.path(d, b)


def scales(f, base, tri, tw, th, ox=0, oy=0, edge=None):
	"""Interlocking triangle rows."""
	f.fill(base)
	r = f.rng
	d = ""
	for j in range(-1, int(f.h / th) + 2):
		off = ox + (tw / 2 if j % 2 else 0)
		for i in range(-1, int(f.w / tw) + 2):
			x = off + i * tw
			y = oy + j * th
			w0, w1 = r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6)
			d += f"M{x + w0:.1f} {y + th:.1f}L{x + tw / 2 + w1:.1f} {y:.1f}L{x + tw + w0:.1f} {y + th:.1f}Z"
	f.path(d, tri, stroke=edge, sw=0.7) if edge else f.path(d, tri)


def asanoha(f, colour, s, sw=0.9, ox=0, oy=0):
	"""Hemp-leaf stars: a triangular lattice, each triangle's centre spoked to its three corners."""
	h = s * math.sqrt(3) / 2
	d = ""
	for j in range(-1, int(f.h / h) + 2):
		for i in range(-1, int(f.w / s) + 2):
			x = ox + i * s + (s / 2 if j % 2 else 0)
			y = oy + j * h
			tris = (((x, y), (x + s, y), (x + s / 2, y + h)), ((x + s, y), (x + s / 2, y + h), (x + 1.5 * s, y + h)))
			for t in tris:
				cx = sum(q[0] for q in t) / 3
				cy = sum(q[1] for q in t) / 3
				for q in t:
					d += f"M{cx:.1f} {cy:.1f}L{q[0]:.1f} {q[1]:.1f}"
				d += f"M{t[0][0]:.1f} {t[0][1]:.1f}L{t[1][0]:.1f} {t[1][1]:.1f}L{t[2][0]:.1f} {t[2][1]:.1f}Z"
	f.path(d, stroke=colour, sw=sw)


def shades(f, n, y0=0.0, y1=1.0, pinch=None, op=0.36, light="#ffffff", lop=0.16, width=1.0, colour=INK):
	"""Folds that work over a pattern: translucent shadow, ink edge, faint lit edge."""
	r, w, h = f.rng, f.w, f.h
	px, py = pinch or (w / 2, h * (y0 + y1) / 2)
	for i in range(n):
		side = -1 if i % 2 == 0 else 1
		x0 = px + side * r.uniform(0.3, 0.48) * w
		y = h * (y0 + (y1 - y0) * ((i // 2 + r.uniform(0.2, 0.8)) / max(1, (n + 1) // 2)))
		k = r.uniform(0.3, 0.55)
		x1 = x0 + (px - x0) * (1 - k * 0.5)
		yb = y + (py - y) * (1 - k)
		cx, cy = (x0 + x1) / 2, (y + yb) / 2 + r.uniform(2, 6)
		fat = r.uniform(6, 11)
		f.path(f"M{x0:.1f} {y:.1f}Q{cx:.1f} {cy:.1f} {x1:.1f} {yb:.1f}Q{cx:.1f} {cy + fat:.1f} {x0:.1f} {y + fat * 0.5:.1f}Z", "#0a0614", opacity=op)
		f.taper(x0, y, cx, cy, x1, yb, width, colour)
		if light:
			f.path(f"M{x0:.1f} {y - 3:.1f}Q{cx:.1f} {cy - 4:.1f} {x1:.1f} {yb - 3:.1f}", stroke=light, sw=1.1, opacity=lop)


def flames(f, base_y, h, step, colours, x0=-10, x1=None, jitter=0.25):
	"""Rising flame tongues above base_y, one layer per colour, back to front, each lower than the last."""
	x1 = x1 if x1 is not None else f.w + 10
	r = f.rng
	for li, col in enumerate(colours):
		hh = h * (1 - li * 0.3)
		s = step * (1 - li * 0.12)
		d = f"M{x0} {f.h + 8}L{x0} {base_y:.1f}"
		x = x0 + (li * s * 0.45)
		while x < x1:
			t = r.uniform(1 - jitter, 1 + jitter) * hh
			lean = r.uniform(s * 0.05, s * 0.5)
			d += f"C{x + s * 0.05:.1f} {base_y - t * 0.3:.1f} {x + s * 0.6:.1f} {base_y - t * 0.6:.1f} {x + lean:.1f} {base_y - t:.1f}"
			d += f"C{x + s * 0.8:.1f} {base_y - t * 0.55:.1f} {x + s * 0.9:.1f} {base_y - t * 0.2:.1f} {x + s:.1f} {base_y:.1f}"
			x += s
		d += f"L{x:.1f} {f.h + 8}Z"
		f.path(d, col, stroke=INK if li == 0 else None, sw=1.5)


# ---- body parts


def sandal(f, key, skin=WRAP, sole="#b89a62", strap="#3c2e28"):
	"""Foot: wrapped sock and straw sandal, y 182 to 200."""
	f.path("M-5 182H105V205H-5Z", skin)
	f.path("M-5 190H105V205H-5Z", sole, stroke=INK, sw=1.3)
	for x in range(0, 105, 9):
		f.ink(f"M{x} 192L{x + 3} 200", 0.6, shade(sole, 0.62))
	if key == "F":
		f.path("M50 190L18 180L14 186L46 192ZM50 190L82 180L86 186L54 192Z", strap, stroke=INK, sw=1)


def wraps(f, key, top=118, bottom=184, cloth=WRAP, line="#8a8578"):
	"""White cloth wound round the calf."""
	f.path(f"M-5 {top}H105V{bottom}H-5Z", cloth)
	f.soft(f"M72 {top}Q86 {(top + bottom) / 2} 74 {bottom}H105V{top}Z", "#544e60", 0.5, 2)
	f.soft(f"M-5 {top}H105V{top + 8}H-5Z", "#544e60", 0.45, 2)
	for y in range(top + 8, bottom, 11):
		f.taper(-3, y + 5, 50, y + 1, 103, y - 5, 0.9, line)
	f.ink(f"M-5 {top}Q50 {top + 5} 105 {top}", 1.6)


def trousers(f, colour=UNI, light=UNI_L, bottom=124):
	f.path(f"M-5-5H105V{bottom}H-5Z", colour)
	f.soft(f"M60-5Q80 60 70 {bottom}H105V-5Z", "#000000", 0.3, 3)
	shades(f, 5, 0.04, bottom / 200, (50, bottom * 0.95), op=0.5, light=light, lop=0.6)


def hand(f, key, skin, y0=180):
	dk = shade(skin, 0.66)
	f.path(f"M-5 {y0}H105V210H-5Z", skin)
	f.soft(f"M-5 {y0}H105V{y0 + 5}H-5Z", dk, 0.7, 1)
	if key in "FB":
		for x in (26, 50, 74):
			f.taper(x, y0 + 8, x + 1, y0 + 16, x, 206, 0.7, shade(skin, 0.45))
		f.taper(14, y0 + 7, 50, y0 + 10, 88, y0 + 7, 0.6, dk)
	elif key == "I":
		f.path(f"M30 {y0 + 3}Q60 {y0 + 2} 66 {y0 + 14}Q58 {y0 + 21} 36 {y0 + 18}Z", shade(skin, 1.05), stroke=INK, sw=1)


def head_sides(a, skin, hair, light=None, tip=None):
	"""Head L/R/B/T under the modelled hair, with strands so nothing reads as a plain fill if a gap shows."""
	light = light or shade(hair, 1.5)
	side_head(a["Head_L"], skin, hair, 1)
	side_head(a["Head_R"], skin, hair, -1)
	for n in ("Head_B", "Head_T"):
		f = a[n]
		f.fill(hair)
		for i in range(14):
			x = f.rng.uniform(4, f.w - 4)
			f.taper(x, 0, x + f.rng.uniform(-8, 8), f.h * 0.5, x + f.rng.uniform(-10, 10), f.h, 1.2, light if i % 3 == 0 else shade(hair, 0.4))
	a["Head_Bo"].fill(shade(skin, 0.6))


def sharp_eye(f, ix, iy, ox, oy, top, bot, iris, iris_d, iris_l, r, dx=0, dy=0, pupil=0.48, lid=2.6, lash=INK, shine=1.5, sclera="#f6f2ec", flick=2.5):
	"""A sharp eye between its inner (ix, iy) and outer (ox, oy) corners. top/bot = lid heights at the middle."""
	sgn = 1 if ox > ix else -1
	mx, my = (ix + ox) / 2, (iy + oy) / 2
	shape = f"M{ix} {iy}Q{mx - sgn} {my - top * 2:.1f} {ox} {oy}Q{mx + sgn * 2} {my + bot * 2:.1f} {ix} {iy}Z"
	f.path(shape, sclera)
	clip(f, shape)
	cx, cy = mx + dx, my + dy
	f.path(ell(cx, cy, r, r * 1.14), iris_d)
	f.path(ell(cx, cy + r * 0.22, r * 0.86, r * 0.84), iris)
	f.path(f"M{cx - r * 0.72} {cy + r * 0.28}Q{cx} {cy + r * 1.28} {cx + r * 0.72} {cy + r * 0.28}Q{cx} {cy + r * 0.72} {cx - r * 0.72} {cy + r * 0.28}Z", iris_l, opacity=0.9)
	if pupil:
		f.path(ell(cx, cy, r * pupil, r * pupil * 1.12), "#0a0810")
	f.path(ell(cx, cy, r, r * 1.14), stroke=INK, sw=0.9)
	f.path(f"M{ix} {iy}Q{mx} {my - top * 2:.1f} {ox} {oy}V{oy + 3.5}Q{mx} {my - top * 1.1:.1f} {ix} {iy + 2}Z", "#1b1228", opacity=0.34)
	if shine:
		f.path(ell(cx - sgn * r * 0.34, cy - r * 0.42, shine, shine), "#ffffff")
	unclip(f)
	# heavy upper lid with a flick past the outer corner, thin lower lid
	fx, fy = ox + sgn * flick, oy - flick * 0.45
	f.path(f"M{ix - sgn} {iy + 1}Q{mx - sgn} {my - top * 2 - lid:.1f} {fx} {fy}Q{ox} {oy + 1} {ox - sgn} {oy + 1.2}Q{mx} {my - top * 2 + lid * 0.7:.1f} {ix - sgn} {iy + 1}Z", lash)
	f.path(f"M{ix} {iy + 0.6}Q{mx + sgn * 2} {my + bot * 2:.1f} {ox} {oy}", stroke=lash, sw=0.8)


def hairline(f, colour, y=25):
	"""Top of the face under the hair: gaps between locks show dark hair, not grey skin."""
	f.path(f"M-5-5H135V{y}L112 {y + 3}L92 {y - 2}L66 {y + 3}L40 {y - 2}L18 {y + 3}L-5 {y}Z", colour)


# ---- hair strip


def tip_tone(a, i, n, colour, depth=40, op=0.95):
	"""Paint zone i of n towards the tips (top of the strip) in another colour."""
	f = a["Hair"]
	z = f.w / n
	x0 = i * z
	f.path(f"M{x0} -5H{x0 + z}V{depth * 0.5}H{x0}Z", colour, opacity=op)
	f.path(f"M{x0} {depth * 0.3}H{x0 + z}V{depth}H{x0}Z", colour, opacity=op * 0.55, blur=3)


# ---- bespoke meshes (Blender only)


def _uv(face, u, v):
	x, y, pw, ph, uw, uh = FACES[face]
	return ((x + 2 + u / uw * (pw - 4)) / SIZE, 1 - (y + 2 + v / uh * (ph - 4)) / SIZE)


def panels(kit, name, parent, quads, lining=None):
	"""Painted mesh from quads [(pos, (face, u, v)) * 4], counter-clockwise from outside. lining = (face, u, v) adds an
	inner wall so the back of the cloth shows when seen from inside."""
	bm = kit.bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	verts = {}

	def vert(p, pool):
		k = tuple(round(c, 4) for c in p)
		if k not in pool:
			pool[k] = bm.verts.new(p)
		return pool[k]

	for q in quads:
		f = bm.faces.new([vert(p, verts) for p, _ in q])
		for loop, (_, tag) in zip(f.loops, q):
			loop[uv].uv = _uv(*tag)
	if lining:
		bm.normal_update()
		inner = {}
		for q in quads:
			n = kit.Vector(q[0][0]) - kit.Vector(q[1][0])
			m = kit.Vector(q[2][0]) - kit.Vector(q[1][0])
			nrm = m.cross(n).normalized()
			f = bm.faces.new([vert(tuple(kit.Vector(p) - nrm * 0.015), inner) for p, _ in reversed(q)])
			for loop in f.loops:
				loop[uv].uv = _uv(*lining)
	mesh = kit.bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	o = kit._obj(name, mesh, "#808080", parent)
	o["painted"] = True
	return o


def coat(kit, parts, zb, flare=0.14, zt=2.02, front_flare=None):
	"""Hanging skirt of a coat, one shell per leg so it swings with the leg instead of being pierced by it."""
	ff = flare if front_flare is None else front_flare
	for sgn, part in ((1, "LeftUpperLeg"), (-1, "RightUpperLeg")):
		yf, yb, xi, xo = -0.52, 0.52, 0.0, 1.03
		T = lambda x, y: (x, y, zt)
		Bt = lambda x, y: (x, y, zb)
		xo2, yf2, yb2 = xo + flare, yf - ff, yb + ff
		runs = [
			# corners TL, BL, BR, TR seen from outside and the Coat u range
			((T(xi, yf), Bt(xi, yf2), Bt(xo2, yf2), T(xo, yf)), (0, 100)),
			((T(xo, yf), Bt(xo2, yf2), Bt(xo2, yb2), T(xo, yb)), (100, 200)),
			((T(xo, yb), Bt(xo2, yb2), Bt(xi, yb2), T(xi, yb)), (200, 300)),
		]
		quads = []
		for (tl, bl, br, tr), (u0, u1) in runs:
			q = [(tl, ("Coat", u0, 0)), (bl, ("Coat", u0, 100)), (br, ("Coat", u1, 100)), (tr, ("Coat", u1, 0))]
			if sgn < 0:
				q = [((-p[0], p[1], p[2]), t) for p, t in reversed(q)]
			quads.append(q)
		panels(kit, f"{part}_Coat", parts[part], quads, lining=("CoatIn", 5, 30))


def sleeve(kit, parts, zb, flare=0.14, drop=0.0, zt=4.02):
	"""Wide sleeve: a flared shell using the arm's own painted faces, the hand block left showing below it."""
	for sgn, side in ((1, "Left"), (-1, "Right")):
		def uv(face, x, y, z):
			v = max(0, min(205, (4 - z) / 2 * 205))
			if face == "F":
				u = (x - 1) * 100 if sgn > 0 else (2 - x) * 100
			elif face == "O":
				u = (y + 0.5) * 100 if sgn > 0 else (0.5 - y) * 100
			elif face == "B":
				u = (2 - x) * 100 if sgn > 0 else (x - 1) * 100
			else:
				u = (0.5 - y) * 100 if sgn > 0 else (y + 0.5) * 100
			return (f"{side}Arm_{face}", max(0, min(100, u)), v)

		def wide(x, y, z):
			"""Inflated at the top, flared towards the bottom, the outer lower edge drops."""
			t = (zt - z) / (zt - zb)
			nx = x + (0.02 + flare * t if x > 1.5 else -0.02)
			ny = y + (0.02 + flare * 0.7 * t) * (1 if y > 0 else -1)
			return (nx, ny, z - (drop * t if x > 1.5 else 0))

		xi, xo, yf, yb = 1.0, 2.0, -0.5, 0.5
		runs = (("F", (xi, yf), (xo, yf)), ("O", (xo, yf), (xo, yb)), ("B", (xo, yb), (xi, yb)), ("I", (xi, yb), (xi, yf)))
		quads = []
		for face, (x0, y0), (x1, y1) in runs:
			q = [(wide(x0, y0, zt), uv(face, x0, y0, zt)), (wide(x0, y0, zb), uv(face, x0, y0, zb)), (wide(x1, y1, zb), uv(face, x1, y1, zb)), (wide(x1, y1, zt), uv(face, x1, y1, zt))]
			if sgn < 0:
				# the mirrored arm reads its own face at the same mirrored spot
				q = [((-p[0], p[1], p[2]), t) for p, t in reversed(q)]
			quads.append(q)
		panels(kit, f"{side}Arm_Sleeve", parts[f"{side}UpperArm"], quads, lining=("CoatIn", 5, 30))


def katana(sheath, wrap, guard, rx=1.2, x=1.1, guard_size=0.34):
	"""Sword through the belt on the left hip, handle forward and up, tip down behind."""
	s, c = math.sin(rx), math.cos(rx)
	at = lambda d: [x, 0.35 - s * d, 1.85 + c * d]
	return [
		{"part": "LowerTorso", "box": [0.13, 0.13, 2.1], "at": at(0), "rot": [rx, 0, 0], "colour": sheath, "bevel": 0.03},
		{"part": "LowerTorso", "box": [guard_size, guard_size, 0.05], "at": at(1.08), "rot": [rx, 0, 0], "colour": guard, "bevel": 0.02},
		{"part": "LowerTorso", "box": [0.12, 0.12, 0.62], "at": at(1.42), "rot": [rx, 0, 0], "colour": wrap, "bevel": 0.03},
		{"part": "LowerTorso", "box": [0.14, 0.14, 0.05], "at": at(1.74), "rot": [rx, 0, 0], "colour": guard, "bevel": 0.01},
	]


# ---- whole outfits


def jacket(f, colour=UNI, light=UNI_L, belt=WRAP, buckle="#c9a23a", buttons=True):
	"""Corps uniform front: black stand-collar jacket, gold buttons, white belt."""
	f.fill(colour)
	f.soft("M60 0Q100 10 140 0V40Q100 50 60 40Z", light, 0.35, 5)
	shades(f, 6, 0.08, 0.8, (100, 170), op=0.5, light=light, lop=0.7)
	f.ink("M100 0V166", 1.6)
	if buttons:
		for y in (22, 58, 94, 130):
			f.path(ell(100, y, 4.2, 4.2), buckle, stroke=INK, sw=1)
			f.path(ell(99, y - 1, 1.5, 1.5), "#fff0b0")
	f.path("M-5 166H205V180H-5Z", belt, stroke=INK, sw=1.4)
	f.path("M-5 176H205V180H-5Z", shade(belt, 0.7))
	f.path("M88 163H112V183H88Z", buckle, stroke=INK, sw=1.3)
	f.path("M93 168H107V178H93Z", shade(buckle, 0.6))
	f.ink("M-5 180H205", 1.4)
	shades(f, 2, 0.92, 1.0, (100, 190), op=0.4, light=light, lop=0.5)


def haori_body(a, pattern, skin, inner=jacket, sleeve_y=176, coat_hem=None, cuff=UNI, coat_open=38, trouser=UNI, trouser_l=UNI_L, wrap_top=118, lapel=None, sleeve_hem=None, torso_hem=None, strap="#3c2e28", hem_y=None, ink=INK):
	"""Open coat over an inner layer on every torso, arm and coat-skirt face. pattern(f) paints the cloth across f."""
	lapel = lapel or INK
	f = a["Torso_F"]
	inner(f)
	f.soft("M58-5H72L66 205H50ZM142-5H128L134 205H150Z", "#06030c", 0.55, 3)
	for d in ("M-5-5H62Q64 90 54 205H-5Z", "M205-5H138Q136 90 146 205H205Z"):
		clip(f, d)
		pattern(f)
		if torso_hem:
			torso_hem(f)
		unclip(f)
	shades(f, 5, 0.05, 0.98, (100, 170), op=0.26, colour=ink)
	f.path("M62-5Q64 90 54 205", stroke=lapel, sw=5)
	f.path("M138-5Q136 90 146 205", stroke=lapel, sw=5)
	f.ink("M64-5Q66 90 57 205M136-5Q134 90 143 205", 1.1)
	f.ink("M59-5Q61 90 51 205M141-5Q139 90 149 205", 1.1)
	f.edges()
	f = a["Torso_B"]
	pattern(f)
	if torso_hem:
		torso_hem(f)
	f.soft("M50-5Q100 26 150-5Z", "#06030c", 0.5, 3)
	shades(f, 6, 0.04, 0.98, (100, 170), op=0.26, colour=ink)
	f.ink("M100 16V205", 1.4)
	f.edges()
	for n in ("Torso_L", "Torso_R"):
		f = a[n]
		pattern(f)
		if torso_hem:
			torso_hem(f)
		shades(f, 4, 0.05, 0.98, (50, 170), op=0.26, colour=ink)
		f.edges(0.3)
	pattern(a["Torso_T"])
	a["Torso_Bo"].fill(UNI)
	for side in ("Left", "Right"):
		for key in "FBOI":
			f = a[f"{side}Arm_{key}"]
			f.fill(cuff)
			clip(f, f"M-5-5H105V{sleeve_y}H-5Z")
			pattern(f)
			if sleeve_hem:
				sleeve_hem(f)
			unclip(f)
			shades(f, 3, 0.03, sleeve_y / 205, (50, 96), op=0.26, colour=ink)
			f.ink(f"M-5 {sleeve_y}H105", 2.4)
			f.path(f"M-5 {sleeve_y + 1}H105V{sleeve_y + 5}H-5Z", "#000000", opacity=0.45)
			hand(f, key, skin, 187)
			f.edges()
		pattern(a[f"{side}Arm_T"])
		a[f"{side}Arm_Bo"].fill(shade(skin, 0.8))
		for key in "FBOI":
			f = a[f"{side}Leg_{key}"]
			f.fill(trouser)
			trousers(f, trouser, trouser_l)
			wraps(f, key, wrap_top)
			sandal(f, key, strap=strap)
			f.edges()
		a[f"{side}Leg_T"].fill(UNI)
		a[f"{side}Leg_Bo"].fill("#8a7044")
	f = a["Coat"]
	f.fill(trouser)
	shades(f, 2, 0, 1, (coat_open / 2, 50), op=0.5, light=trouser_l, lop=0.6)
	clip(f, f"M{coat_open} -5H305V105H{coat_open}Z")
	pattern(f)
	if coat_hem:
		coat_hem(f)
	unclip(f)
	shades(f, 5, 0.02, 0.7, (150, 112), op=0.2, width=1.4, colour=ink)
	f.path(f"M{coat_open}-5V105", stroke=lapel, sw=4)
	f.ink(f"M{coat_open + 2}-5V105M{coat_open - 2}-5V105", 1)
	f.ink("M100-5V105M200-5V105", 0.8)
	f.ink(f"M{coat_open} {hem_y or 96}H305", 1.6)
	f.soft("M-5 96H305V105H-5Z", "#000000", 0.4, 1)
	a["CoatIn"].fill(shade(trouser, 0.7))
