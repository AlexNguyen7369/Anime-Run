# Target look for foe_mha (Shigaraky): shaggy pale blue hair, one red eye staring through the fingers of a big lilac-grey severed
# hand held over the face, fourteen such hands gripping head, neck, arms and body, each wrist capped by a brass block with two round
# sockets, red cables looping from those blocks above the head. Black long-sleeved deep V-neck shirt over bare chest, black cropped
# trousers, bare ankles, red high-top sneakers, white soles, black laces.
# The worn hands have fingers because they are the costume; the figure's own hands stay plain blocks (design doc 5).
import math

from atlas import shade
from mha_style3 import anime_eye, bake, block, brow_block, core, gem, hand, head_faces, jitter, lump, strip
from style2 import Kit, Ramps
from style3 import big_head, finish

SKIN = "#efdcc8"
SKIN_D = "#c4a690"
DEFAULT = "#25252d"
HAIR_COL = "#6EA8C8"
R = Ramps(
	hair=["#234e74", "#3f7aa2", "#6ea8c8", "#9accde", "#cfe9ef"],
	skin=["#a98a76", "#d4b8a0", "#efdcc8", "#fbf0e2"],
	# the worn hands: cold and lilac, against his warm own skin
	dead=["#615e7a", "#8a87a2", "#b8b5c8", "#e6e3ee"],
	brass=["#5c3f10", "#a0741e", "#d8a838", "#f6d878"],
	shirt=["#08080c", "#15151b", "#25252d", "#3e3e4a"],
	trousers=["#060608", "#111115", "#1f1f26", "#34343e"],
	cable=["#5c0a12", "#94141e", "#c8202c", "#ee5050"],
	red=["#6a0c12", "#9c141c", "#c8222c", "#ee5252"],
	sole=["#8a8488", "#c8c2c4", "#efeae8", "#ffffff"],
	lace=["#050507", "#0f0f12", "#1c1c20", "#303036"],
)
HAIR = {"colour": HAIR_COL, "locks": []}
PROPS = []


def _add(*vs):
	return tuple(sum(c) for c in zip(*vs))


def _mul(v, k):
	return tuple(c * k for c in v)


def _dot(a, b):
	return sum(x * y for x, y in zip(a, b))


def _cross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(v):
	n = _dot(v, v) ** 0.5
	return tuple(c / n for c in v)


def _ortho(v, ref):
	"""ref made perpendicular to v, unit length."""
	return _unit(_add(ref, _mul(v, -_dot(v, ref))))


def _oct(p, a, b, ra, rb, ch=0.3):
	"""An eight-point ring: a box section with cut corners, half sizes ra along a, rb along b."""
	ca, cb = ra * (1 - ch), rb * (1 - ch)
	return [_add(p, _mul(a, x), _mul(b, y)) for x, y in ((ca, -rb), (ra, -cb), (ra, cb), (ca, rb), (-ca, rb), (-ra, cb), (-ra, -cb), (-ca, -rb))]


def _hex(p, a, b, ra, rb, off=0.0):
	return [_add(p, _mul(a, ra * math.cos(off + math.pi * j / 3)), _mul(b, rb * math.sin(off + math.pi * j / 3))) for j in range(6)]


def _solid(k, part, name, rings, ramp, **bk):
	verts, faces, flat = k._loft(rings)
	return bake(k, k._mesh(name, part, verts, faces, flat, outline=0), ramp, **dict(dict(a=0.5, b=0.4, g=0.05), **bk))


def _digit(k, part, name, base, d, up, across, segs, rad, curl, sc):
	"""A chunky finger: hexagon rings along three joints, turning towards -up by curl degrees at each joint."""
	cur, rings = base, []
	for i, q in enumerate((1.0, 0.98, 0.9, 0.72)[: len(segs) + 1]):
		rings.append(_hex(cur, across, up, rad[0] * sc * q, rad[1] * sc * q))
		if i < len(segs):
			a = math.radians(curl[i])
			d, up = _add(_mul(d, math.cos(a)), _mul(up, -math.sin(a))), _add(_mul(up, math.cos(a)), _mul(d, math.sin(a)))
			cur = _add(cur, _mul(d, segs[i] * sc))
	_solid(k, part, name, rings, "dead")


def _worn(k, part, tag, c, v, n, sc=1.0, curl=(20, 35, 30), fingers=None, thumb=1, thumb_to=(0.75, 0.65), stub=0.26, stub_dir=None, sock=None):
	"""One worn hand. c palm centre, v towards the fingertips, n the back of the hand. Fingers curl away from n.
	fingers: (place across the palm -1..1, fan degrees, length factor). The wrist runs along stub_dir to a brass block with two sockets, on its end or, given sock, on the wide face turned that way.
	Returns the block's outer centre, where a cable can plug in."""
	v = _unit(v)
	n = _ortho(v, n)
	u = _cross(v, n)
	hw, hl, ht = 0.27 * sc, 0.23 * sc, 0.085 * sc
	_solid(k, part, f"W{tag}Palm", [_oct(_add(c, _mul(v, -hl)), u, n, hw * 0.8, ht * 0.95), _oct(_add(c, _mul(n, ht * 0.25)), u, n, hw * 0.98, ht * 1.1), _oct(_add(c, _mul(v, hl)), u, n, hw, ht * 0.9)], "dead")
	for i, (off, fan, ln) in enumerate(fingers or ((-0.74, -7, 0.85), (-0.25, -2, 1.0), (0.25, 2, 1.05), (0.74, 7, 0.95))):
		a = math.radians(fan)
		d = _add(_mul(v, math.cos(a)), _mul(u, math.sin(a)))
		across = _add(_mul(u, math.cos(a)), _mul(v, -math.sin(a)))
		base = _add(c, _mul(v, hl * 0.9), _mul(u, off * hw))
		_digit(k, part, f"W{tag}F{i}", base, d, n, across, (0.2 * ln, 0.16 * ln, 0.12 * ln), (0.075, 0.07), curl, sc)
	if thumb:
		base = _add(c, _mul(v, -hl * 0.35), _mul(u, thumb * hw * 0.85))
		d = _unit(_add(_mul(u, thumb * thumb_to[0]), _mul(v, thumb_to[1])))
		_digit(k, part, f"W{tag}Thumb", base, d, n, _cross(d, n), (0.19, 0.15), (0.085, 0.075), (10, 25), sc)
	# the wrist
	sd = _unit(stub_dir) if stub_dir else _mul(v, -1)
	a = _ortho(sd, u)
	b = _cross(sd, a)
	w0 = _add(c, _mul(v, -hl * 0.85))
	w1 = _add(w0, _mul(sd, stub * sc))
	_solid(k, part, f"W{tag}Wrist", [_oct(w0, a, b, hw * 0.7, ht * 0.95), _oct(_add(w0, _mul(sd, stub * sc * 0.55)), a, b, hw * 0.58, ht * 1.15), _oct(w1, a, b, hw * 0.62, ht * 1.3)], "dead")
	# the brass block
	bw, bt, bl = 0.235 * sc, 0.15 * sc, 0.1 * sc
	e = 0.022 * sc
	rows = [(0, 0.86), (e, 1.0), (2 * bl - e, 1.0), (2 * bl, 0.86)]
	_solid(k, part, f"W{tag}Brass", [_oct(_add(w1, _mul(sd, t)), a, b, bw * q, bt * q, ch=0.14) for t, q in rows], "brass", a=0.54, b=0.5, g=0.03)
	out = _add(w1, _mul(sd, 2 * bl))
	mid = _add(w1, _mul(sd, bl))
	sb = (b if _dot(b, sock) > 0 else _mul(b, -1)) if sock else sd
	sa = a
	for j, q in enumerate((-1, 1)):
		p = _add(_add(mid, _mul(sb, bt)) if sock else out, _mul(sa, q * bw * 0.46))
		rim = _cross(sb, sa)
		_solid(k, part, f"W{tag}Socket{j}", [_hex(_add(p, _mul(sb, -0.004)), sa, rim, 0.07 * sc, 0.07 * sc), _hex(_add(p, _mul(sb, 0.006)), sa, rim, 0.06 * sc, 0.06 * sc)], "brass", a=0.08, b=0.06, g=0.0)
	return out


def _cable(k, part, name, pts, r=0.078):
	"""A rubbery red cable through pts: a rounded path, square-cut section."""
	path = []
	for i in range(len(pts) - 1):
		p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
		for t in (0, 0.33, 0.66):
			t2, t3 = t * t, t * t * t
			path.append(tuple(0.5 * (2 * p1[j] + (p2[j] - p0[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (3 * p1[j] - p0[j] - 3 * p2[j] + p3[j]) * t3) for j in range(3)))
	path.append(pts[-1])
	rings = []
	for i, p in enumerate(path):
		d = _unit(_add(path[min(i + 1, len(path) - 1)], _mul(path[max(i - 1, 0)], -1)))
		a = _ortho(d, (0.13, 0.97, 0.21))
		rings.append(_hex(p, a, _cross(d, a), r, r))
	_solid(k, part, name, rings, "cable", a=0.56, b=0.42, g=0.02)


def _hair(k):
	h = "Head"
	dome = k.lathe(h, "Crown", [(0.94, 5.28, 0.5), (1.04, 5.54, 0.5), (0.98, 5.9, 0.5), (0.6, 6.16, 0.5), (0.16, 6.24, 0.5)], "hair", n=10, at=(0, 0.06, 0), squash=0.97, outline=0)
	jitter(dome, 0.03)
	bake(k, dome, "hair", a=0.42, b=0.34)
	for i, (at, r) in enumerate((((-0.62, -0.18, 5.98), (0.46, 0.46, 0.38)), ((0.06, -0.3, 6.12), (0.52, 0.46, 0.38)), ((0.66, -0.16, 5.98), (0.46, 0.46, 0.38)), ((-0.46, 0.46, 6.08), (0.5, 0.48, 0.38)), ((0.46, 0.46, 6.08), (0.5, 0.48, 0.38)), ((-0.96, 0.22, 5.56), (0.34, 0.54, 0.44)), ((0.98, 0.22, 5.56), (0.34, 0.54, 0.44)), ((0.0, 0.86, 5.5), (0.72, 0.34, 0.56)))):
		lump(k, h, f"Mass{i}", at, r, "hair")
	root = (0, 0.08, 5.65)

	def out(tip, f=0.42):
		return tuple(root[i] + (tip[i] - root[i]) * f for i in range(3))

	# the shag: layers of wide flat shards falling and flicking out, longest at the sides and nape, none standing up
	top = (((-1.28, -0.28, 5.94), 0.31), ((-0.86, -0.72, 6.12), 0.3), ((-0.3, -0.84, 6.2), 0.31), ((0.36, -0.82, 6.22), 0.32), ((0.92, -0.68, 6.08), 0.3), ((1.32, -0.24, 5.9), 0.31), ((1.36, 0.36, 6.0), 0.32), ((-1.34, 0.4, 6.02), 0.32), ((-0.84, 0.96, 6.2), 0.33), ((0.84, 0.98, 6.2), 0.33), ((0.02, 1.16, 6.22), 0.34), ((-0.46, 0.5, 6.42), 0.34), ((0.48, 0.46, 6.4), 0.34))
	for i, (tip, r) in enumerate(top):
		gem(k, h, f"Top{i}", out(tip), tip, r, flat=0.55, bend=0.1, twist=0.2 + 0.13 * i % 0.5)
	mid = (((-1.36, -0.34, 5.26), 0.3), ((-1.42, 0.08, 5.1), 0.32), ((-1.34, 0.56, 5.3), 0.32), ((1.38, -0.32, 5.22), 0.3), ((1.44, 0.1, 5.06), 0.32), ((1.32, 0.6, 5.28), 0.32), ((-0.82, 1.14, 5.42), 0.34), ((0.0, 1.28, 5.32), 0.36), ((0.8, 1.14, 5.4), 0.34))
	for i, (tip, r) in enumerate(mid):
		gem(k, h, f"Mid{i}", out(tip, 0.36), tip, r, flat=0.5, bend=0.14, twist=0.15 + 0.17 * i % 0.5)
	# the fringe, thick and uneven, hanging to the eyes behind the fingers
	for i, (x, xt, zt, r) in enumerate(((-0.84, -1.0, 4.82, 0.27), (-0.56, -0.64, 4.92, 0.28), (-0.27, -0.3, 4.88, 0.28), (0.02, 0.02, 4.96, 0.28), (0.3, 0.34, 5.06, 0.27), (0.58, 0.66, 5.02, 0.27), (0.84, 1.0, 4.8, 0.27))):
		gem(k, h, f"Fringe{i}", (x * 0.92, -0.52, 5.84), (xt, -0.95, zt), r, flat=0.45, twist=0.18 + 0.19 * i % 0.5, bend=0.16)
	for i, (x, xt, zt, r) in enumerate(((-0.72, -0.96, 5.34, 0.3), (-0.4, -0.46, 5.26, 0.32), (-0.08, -0.1, 5.36, 0.32), (0.26, 0.26, 5.28, 0.32), (0.6, 0.8, 5.38, 0.3))):
		gem(k, h, f"Bang{i}", (x * 0.8, -0.34, 6.1), (xt, -0.97, zt), r, flat=0.45, twist=0.3 + 0.21 * i % 0.5, bend=0.14)
	for s in (1, -1):
		# the sides, down past the jaw
		for i, (y, zt, r, o) in enumerate(((-0.54, 4.46, 0.27, 1.06), (-0.16, 4.24, 0.3, 1.14), (0.24, 4.2, 0.32, 1.16), (0.6, 4.3, 0.3, 1.1))):
			gem(k, h, f"Side{s}{i}", (s * 0.88, y * 0.9, 5.56), (s * o, y * 1.06, zt + 0.06 * (i % 2)), r, flat=0.5, twist=0.2 + 0.23 * i, across=(0, 1, 0))
	block(k, h, "Nape", 0, 0.42, 5.7, 4.3, 0.98, 0.5, "hair", ch=0.1, corner=0.26, jit=0.03, mids=(5.0,), a=0.42, b=0.42, g=0.1)
	for i, x in enumerate((-0.84, -0.46, -0.06, 0.34, 0.76)):
		gem(k, h, f"NapeS{i}", (x * 0.92, 0.8, 5.3), (x * 1.08, 1.06, 3.98 + 0.13 * (i % 3)), 0.34, flat=0.45, twist=0.2 + 0.11 * i, across=(1, 0, 0))


def _head_hands(k):
	h = "Head"
	# over the face: palm on the mouth, wrist under the chin, fingers fanned up the forehead with one eye clear between them
	_worn(k, h, "Face", (-0.14, -1.0, 4.34), (0, 0.02, 1), (0, -1, 0.05), sc=1.34, curl=(-6, 8, 22), fingers=((-0.82, -18, 0.86), (-0.28, -7, 1.02), (0.2, 1, 1.08), (0.76, 27, 1.0)), thumb=0, stub=0.1, sock=(0, -1, 0))
	# the thumb, out along the cheek under the open eye
	_digit(k, h, "WFaceThumb", (0.14, -1.02, 4.16), _unit((0.84, 0.12, 0.5)), (0, -1, 0), (-0.5, 0, 0.84), (0.2, 0.17), (0.095, 0.075), (6, 22), 1.3)
	# on the crown, fingers forward over the hair, wrist standing up at the back
	crown = _worn(k, h, "Crown", (0.02, 0.2, 6.42), (0.05, -1, -0.3), (0, -0.28, 1), sc=1.08, curl=(20, 30, 28), thumb=-1, stub=0.24, stub_dir=(0, 0.82, 0.57), sock=(0, -0.6, 0.8))
	# the back of the skull
	_worn(k, h, "Nape", (0.06, 1.14, 5.02), (0.18, 0.05, 1), (0, 1, 0), sc=1.02, curl=(25, 35, 30), thumb=1, stub=0.28, stub_dir=(-0.1, 0.82, -0.5))
	# two red cables, wide square-shouldered loops over the head, from the crown block down to the blocks of the neck hands
	_cable(k, h, "CableL", [crown, (-0.3, 1.02, 7.12), (-1.0, 0.88, 7.2), (-1.66, 0.66, 6.9), (-1.8, 0.48, 6.1), (-1.72, 0.32, 5.34), (-1.47, 0.23, 4.8)])
	_cable(k, h, "CableR", [crown, (0.36, 1.06, 7.02), (1.06, 0.94, 7.06), (1.72, 0.7, 6.72), (1.84, 0.5, 5.98), (1.72, 0.32, 5.3), (1.47, 0.23, 4.8)])


def _shirt(k):
	t = "UpperTorso"
	rows = [(0, 0, 3.98, 0.98, 0.5), (0, 0, 3.9, 1.06, 0.58), (0, 0, 3.4, 1.07, 0.585), (0, 0, 2.7, 1.08, 0.59), (0, 0, 2.3, 1.1, 0.6), (0, 0, 2.22, 1.04, 0.54)]
	jitter(k.tube(t, "Body", rows, ("face", "Torso"), corner=0.14, nc=1, outline=0), 0.012)
	# the shirt hangs loose over the trousers
	block(k, t, "Hem", 0, 0, 2.36, 2.14, 1.13, 0.63, "shirt", ch=0.03, jit=0.012, a=0.42, b=0.5)
	block(k, t, "Hips", 0, 0, 2.14, 1.88, 1.06, 0.585, "trousers", ch=0.02, a=0.42, b=0.55)
	block(k, t, "Neck", 0, 0.02, 4.12, 3.9, 0.46, 0.42, "skin", ch=0.03, a=0.46, b=0.28)
	# the V's raised edges, front; a low collar at the back
	for s in (1, -1):
		strip(k, t, f"VEdge{s}", (s * 0.7, 3.99), (0, 2.96), 0.06, -0.635, 0.06, "shirt", a=0.56, b=0.5)
	block(k, t, "CollarBack", 0, 0.44, 4.02, 3.9, 0.62, 0.16, "shirt", ch=0.03, a=0.5, b=0.5)
	back = dict(thumb=1, curl=(24, 34, 28))
	# two from behind round the ribs: wrist hidden in the body, block standing off the back
	for s, tag in ((1, "L"), (-1, "R")):
		_worn(k, t, f"Rib{tag}", (s * 1.02, -0.66, 2.68), (-s, 0, 0.14), (0, -1, 0), sc=0.92, curl=(8, 28, 30), thumb=0, stub=1.32, stub_dir=(0, 1, 0))
	# on the neck: palm on the shoulder, fingers hanging over the collarbone, wrist rising behind the head
	for s, tag in ((1, "L"), (-1, "R")):
		_worn(k, t, f"Neck{tag}", (s * 0.92, -0.24, 4.14), (-s * 0.2, -0.95, -0.24), (s * 0.08, -0.26, 0.96), sc=1.1, curl=(30, 42, 28), thumb=-s, stub=0.62, stub_dir=(s * 0.56, 0.52, 0.66), sock=(0, -1, 0.3))
	# across the shoulder blades, and one low on the spine
	_worn(k, t, "BackL", (0.5, 0.67, 3.5), (0.3, 0, 0.95), (0, 1, 0), stub=0.3, stub_dir=(0.34, 0.86, -0.38), **back)
	_worn(k, t, "BackR", (-0.5, 0.67, 3.34), (-0.3, 0, 0.95), (0, 1, 0), stub=0.3, stub_dir=(-0.34, 0.86, -0.3), **back)
	_worn(k, t, "BackC", (0.02, 0.68, 2.72), (0.12, 0, 1), (0, 1, 0), stub=0.28, stub_dir=(0.1, 0.9, -0.42), **back)


def _arm(k, side, s):
	arm = f"{side}UpperArm"
	ax = s * 1.5
	block(k, arm, "Sleeve", ax, 0, 4.0, 2.72, 0.52, 0.53, "shirt", ch=0.1, corner=0.2, jit=0.022, sub=1, mids=(3.5, 3.05), a=0.46, b=0.58, tone=0.04)
	block(k, arm, "Cuff", ax, 0, 2.78, 2.44, 0.56, 0.57, "shirt", ch=0.04, corner=0.18, jit=0.012, a=0.42, b=0.52)
	hand(k, arm, ax, "skin", z1=2.48)
	# two gripping the arm from outside: palm and fingers across the front, wrists kicked out to break the outline
	fx = ax + s * 0.34
	_worn(k, arm, f"{side}U", (fx, -0.62, 3.56), (-s, 0, -0.1), (0, -1, 0), sc=1.0, curl=(4, 22, 34), thumb=s, thumb_to=(0.85, 0.3), stub=0.38, stub_dir=(s * 0.88, 0.3, 0.38), sock=(0, -1, 0))
	_worn(k, arm, f"{side}F", (fx, -0.62, 3.02), (-s, 0, 0.1), (0, -1, 0), sc=1.0, curl=(4, 22, 34), thumb=-s, thumb_to=(0.85, 0.3), stub=0.38, stub_dir=(s * 0.88, 0.3, -0.38), sock=(0, -1, 0))


def _leg(k, side, s):
	leg = f"{side}UpperLeg"
	x = s * 0.53
	block(k, leg, "Pants", x, 0, 1.95, 0.98, 0.525, 0.57, "trousers", ch=0.04, flare=0.03, corner=0.16, jit=0.04, mids=(1.5, 1.2), a=0.46, b=0.56, tone=0.05)
	# creases at the knee, raised facets
	for i, (z0, z1, dx) in enumerate(((1.4, 1.32, 0.12), (1.2, 1.28, -0.1))):
		strip(k, leg, f"Crease{i}", (x - 0.32 + dx, z0), (x + 0.32 + dx, z1), 0.028, -0.625, 0.04, "trousers", a=0.66, b=0.3)
	block(k, leg, "TrouserCuff", x, 0, 1.06, 0.92, 0.565, 0.61, "trousers", ch=0.03, a=0.42, b=0.5)
	# the bare ankle above the sneaker
	block(k, leg, "Ankle", x, 0.0, 0.94, 0.62, 0.45, 0.47, "skin", ch=0.02, a=0.5, b=0.3)
	# the high-top: red upper, padded collar, tongue, black laces, white sole
	block(k, leg, "Shoe", x, 0.0, 0.62, 0.14, 0.53, 0.58, "red", ch=0.05, corner=0.22, a=0.54, b=0.5)
	block(k, leg, "ShoeCollar", x, 0.04, 0.66, 0.56, 0.5, 0.52, "red", ch=0.03, a=0.64, b=0.42)
	block(k, leg, "Toe", x, -0.44, 0.44, 0.14, 0.51, 0.4, "red", ch=0.09, corner=0.28, a=0.56, b=0.5)
	block(k, leg, "Tongue", x, -0.6, 0.66, 0.42, 0.13, 0.05, "red", ch=0.02, a=0.72, b=0.3)
	for i, z in enumerate((0.58, 0.47, 0.36)):
		y = -0.62 - 0.12 * i
		block(k, leg, f"Lace{i}", x, y, z + 0.03, z - 0.03, 0.22, 0.045, "lace", ch=0.012, a=0.5, b=0.4)
	block(k, leg, "Sole", x, -0.16, 0.17, 0.0, 0.57, 0.78, "sole", ch=0.03, a=0.58, b=0.38)


def model(parts, kit):
	k = Kit(kit, parts, R, outline=0)
	big_head(k)
	core(k)
	_hair(k)
	_head_hands(k)
	_shirt(k)
	for s, side in ((1, "Left"), (-1, "Right")):
		_arm(k, side, s)
		_leg(k, side, s)
	finish()


def _paint_face(a):
	f = head_faces(a, SKIN, SKIN_D, HAIR_COL)
	lid = "#5c4650"
	line = shade(SKIN_D, 0.52)
	for s, x, ww in ((-1, 34, 28), (1, 96, 32)):
		# sunken, sleepless sockets
		f.soft(f"M{x - 25} 38H{x + 25}V72Q{x} 88 {x - 25} 72Z", "#6e5a68", 0.72, 3)
		anime_eye(f, x, 58, s, "#c8141e", w=ww, up=11, dn=12, lift=1, lt=2.8, wing=1.5, ir=7.5, pupil=0.3, lash=lid, white="#f8f2ea")
		# dry creased skin round the eye, from years of scratching
		for dx0, y0, dx1, y1 in ((-18, 74, -6, 80), (-8, 78, 8, 83), (8, 76, 20, 72), (-20, 40, -6, 34), (6, 34, 20, 40)):
			f.taper(x + s * dx0, y0, x + s * (dx0 + dx1) / 2, (y0 + y1) / 2 + 1, x + s * dx1, y1, 1.2, line)
		brow_block(f, s, 12, 44, 40, 36, 3.2, "#5e8fac")
	# the scar down the eyelid over the viewer's left eye, and one at the viewer's right of the lip
	f.path("M30 36L33 52L30.5 53Z", "#8a5a56")
	f.path("M30 66L33 80L30.5 81Z", "#8a5a56")
	f.path("M48 106Q65 100 82 106Q65 110 48 106Z", "#a87c70", stroke="#6e4a48", sw=1.0)
	f.path("M84 100L88 112L85.5 113Z", "#8a5a56")


def _paint_torso(a):
	cloth, dark, lit = "#25252d", "#121217", "#3a3a46"
	f = a["Torso_F"]
	f.fill(cloth)
	f.soft("M-5 150H205V205H-5Z", dark, 0.65, 8)
	f.soft("M-5-5H26V205H-5Z", lit, 0.25, 5)
	f.folds(10, dark, lit, y0=0.52, y1=0.92, pinch=(100, 118), width=1.6)
	# the deep V and the bare chest inside it, pale and drawn
	v = "M30 -5H170L100 102Z"
	f.path(v, SKIN)
	f.out.append('<clipPath id="vneck"><path d="M30 -5H170L100 102Z"/></clipPath><g clip-path="url(#vneck)">')
	f.soft("M30 -5H170V16Q100 34 30 16Z", SKIN_D, 0.75, 3)
	f.soft("M72 38Q86 58 100 44V66Q82 72 72 38Z", SKIN_D, 0.75, 2)
	f.soft("M128 38Q114 58 100 44V66Q118 72 128 38Z", SKIN_D, 0.8, 2)
	f.path("M100 26V98", stroke=shade(SKIN_D, 0.65), sw=1.6)
	f.taper(64, 30, 82, 25, 98, 24, 1.2, shade(SKIN_D, 0.62))
	f.taper(136, 30, 118, 25, 102, 24, 1.2, shade(SKIN_D, 0.62))
	f.taper(84, 62, 92, 68, 99, 62, 1.1, shade(SKIN_D, 0.6))
	f.taper(116, 62, 108, 68, 101, 62, 1.1, shade(SKIN_D, 0.6))
	f.out.append("</g>")
	b = a["Torso_B"]
	b.fill(cloth)
	b.soft("M-5 150H205V205H-5Z", dark, 0.65, 8)
	b.folds(10, dark, lit, y0=0.5, y1=0.92, pinch=(100, 120), width=1.6)
	for n in ("Torso_L", "Torso_R"):
		a[n].fill(shade(cloth, 0.8))
		a[n].soft("M-5 140H105V205H-5Z", dark, 0.7, 8)
	a["Torso_T"].fill(shade(cloth, 1.3))
	a["Torso_Bo"].fill(dark)


def paint(a):
	R.paint(a)
	_paint_face(a)
	_paint_torso(a)
