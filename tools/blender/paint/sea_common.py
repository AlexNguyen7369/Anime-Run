# Shared painting and bespoke mesh helpers for the sea_* cast (docs/CHARACTER_GACHA_SPEC.md "Painted textures").
# bpy and bmesh are imported inside the mesh helpers: atlas.py imports this file under plain python3.
import math

from atlas import INK, shade


def circle(cx, cy, rx, ry=None):
	ry = rx if ry is None else ry
	return f"M{cx - rx} {cy}a{rx} {ry} 0 1 0 {2 * rx} 0a{rx} {ry} 0 1 0 {-2 * rx} 0Z"


def fx(side, key, t):
	"""Face x on a limb's O or I face for t = 0 (front of the body) .. 1 (back)."""
	front_left = (side == "Left") == (key == "O")
	return (t if front_left else 1 - t) * 100


def out_sgn(side, key):
	"""+1 when the limb's outer side is on the viewer's right of its F or B face."""
	return 1 if (side == "Left") == (key == "F") else -1


def strand_zone(a, i, n, colour, weave=False, lines=None):
	"""Repaints zone i of n in the Hair strip for cloth or straw instead of hair: an even tone with streaks, a soft shadow
	at the root end. weave adds cross rings for straw."""
	f = a["Hair"]
	zone = f.w / n
	x0 = i * zone
	f.path(f"M{x0} -5H{x0 + zone}V96H{x0}Z", colour)
	f.path(f"M{x0} 96V68H{x0 + zone}V96Z", shade(colour, 0.72), opacity=0.8, blur=2)
	f.path(f"M{x0} 0H{x0 + zone}V16H{x0}Z", shade(colour, 1.18), opacity=0.7, blur=2)
	for k in range(lines or int(zone / 9)):
		x = x0 + (k + f.rng.uniform(0.1, 0.9)) * zone / (lines or int(zone / 9))
		f.taper(x, f.rng.uniform(-5, 30), x + f.rng.uniform(-3, 3), 45, x + f.rng.uniform(-2, 2), f.rng.uniform(60, 96), 0.9, shade(colour, f.rng.choice((0.55, 0.7, 1.2))))
	if weave:
		for y in range(3, 91, 7):
			f.path(f"M{x0} {y}H{x0 + zone}", stroke=shade(colour, 0.66), sw=1.0, opacity=0.8)


# ---- bodies


def chest(f, skin, cx=100, w=1.0, abs_rows=3, deep=1.0):
	"""Painted chest and abs: clavicles, pecs with an underside shadow, a centre line, ab blocks and obliques."""
	d = shade(skin, 0.66)
	e = shade(skin, 0.42)
	l = shade(skin, 1.14)
	u = 50 * w
	f.soft(f"M{cx - u * 1.5} 62Q{cx - u * 0.8} 92 {cx - 3} 78V88Q{cx - u * 0.8} 104 {cx - u * 1.5} 80Z", d, 0.85 * deep, 2)
	f.soft(f"M{cx + u * 1.5} 62Q{cx + u * 0.8} 92 {cx + 3} 78V88Q{cx + u * 0.8} 104 {cx + u * 1.5} 80Z", d, 0.85 * deep, 2)
	f.soft(f"M{cx - u} 34Q{cx - u * 0.5} 26 {cx - 8} 40Q{cx - u * 0.5} 62 {cx - u} 54Z", l, 0.65, 3)
	f.soft(f"M{cx + u} 34Q{cx + u * 0.5} 26 {cx + 8} 40Q{cx + u * 0.5} 62 {cx + u} 54Z", l, 0.65, 3)
	# collar bones and the pit of the neck
	f.taper(cx - 4, 16, cx - u * 0.6, 12, cx - u * 1.4, 18, 1.5, e)
	f.taper(cx + 4, 16, cx + u * 0.6, 12, cx + u * 1.4, 18, 1.5, e)
	f.path(f"M{cx - 5} 14Q{cx} 22 {cx + 5} 14Q{cx} 10 {cx - 5} 14Z", d, opacity=0.9)
	# pec lines
	f.taper(cx - 1, 82, cx - u * 0.75, 96, cx - u * 1.42, 62, 1.9, INK)
	f.taper(cx + 1, 82, cx + u * 0.75, 96, cx + u * 1.42, 62, 1.9, INK)
	f.taper(cx, 30, cx - 1, 60, cx, 88, 1.1, e)
	# abs
	y0, step = 96, 62 / max(1, abs_rows)
	for i in range(abs_rows):
		y = y0 + i * step
		ww = u * (0.5 - i * 0.03)
		f.soft(f"M{cx - ww} {y + step * 0.55}H{cx + ww}V{y + step}H{cx - ww}Z", d, 0.5 * deep, 1)
		f.taper(cx - ww, y + step, cx - ww * 0.5, y + step + 1.6, cx - 1.5, y + step - 1, 1.0, e)
		f.taper(cx + ww, y + step, cx + ww * 0.5, y + step + 1.6, cx + 1.5, y + step - 1, 1.0, e)
		f.taper(cx - ww * 1.05, y, cx - ww * 1.14, y + step / 2, cx - ww * 1.05, y + step, 1.1, e)
		f.taper(cx + ww * 1.05, y, cx + ww * 1.14, y + step / 2, cx + ww * 1.05, y + step, 1.1, e)
	f.taper(cx, 90, cx + 0.8, 130, cx, 170, 1.2, e)
	# obliques down to the hip
	f.taper(cx - u * 1.3, 94, cx - u * 1.2, 130, cx - u * 0.72, 172, 1.4, e)
	f.taper(cx + u * 1.3, 94, cx + u * 1.2, 130, cx + u * 0.72, 172, 1.4, e)
	f.soft(f"M{cx - u * 2} 92Q{cx - u * 1.3} 130 {cx - u * 0.8} 180H{cx - u * 2}Z", d, 0.6, 3)
	f.soft(f"M{cx + u * 2} 92Q{cx + u * 1.3} 130 {cx + u * 0.8} 180H{cx + u * 2}Z", d, 0.85, 3)


def bare_back(f, skin, deep=1.0):
	d = shade(skin, 0.66)
	e = shade(skin, 0.42)
	f.fill(skin)
	f.soft("M100 8Q84 90 94 186H106Q116 90 100 8Z", d, 0.9 * deep, 2)
	f.taper(100, 18, 99, 100, 100, 180, 1.2, e)
	for s in (-1, 1):
		f.soft(f"M{100 + s * 18} 24Q{100 + s * 62} 26 {100 + s * 74} 66Q{100 + s * 52} 84 {100 + s * 24} 62Z", shade(skin, 1.12), 0.6, 3)
		f.taper(100 + s * 24, 66, 100 + s * 60, 90, 100 + s * 78, 62, 1.6, e)
		f.taper(100 + s * 16, 28, 100 + s * 18, 50, 100 + s * 24, 66, 1.2, e)
		f.soft(f"M{100 + s * 100} 70Q{100 + s * 58} 124 {100 + s * 34} 182H{100 + s * 100}Z", d, 0.7, 3)
		f.taper(100 + s * 78, 92, 100 + s * 56, 130, 100 + s * 36, 172, 1.4, e)
	f.taper(60, 8, 80, 18, 92, 12, 1.0, e)
	f.taper(140, 8, 120, 18, 108, 12, 1.0, e)
	f.edges()


def bare_side(f, skin):
	"""A torso side: the lat, the ribs, a shadow towards the back."""
	d = shade(skin, 0.66)
	e = shade(skin, 0.42)
	f.fill(skin)
	f.soft("M-5 66Q50 56 105 70V100Q50 86 -5 96Z", d, 0.5, 3)
	for y in (92, 108, 124, 140):
		f.taper(28, y, 50, y + 5, 74, y - 2, 1.1, e)
	f.taper(50, 22, 44, 80, 50, 170, 1.0, e)
	f.soft("M-5 170H105V205H-5Z", d, 0.5, 3)
	f.edges(0.34)


def arm_muscle(f, side, key, skin, y0=0, wrist=172):
	"""Bare arm from y0 to the wrist: deltoid, biceps or triceps, elbow crease, forearm. Hands are drawn by hand()."""
	d = shade(skin, 0.66)
	e = shade(skin, 0.42)
	l = shade(skin, 1.14)
	f.path(f"M-5 {y0}H105V{wrist}H-5Z", skin)
	if y0 < 40:
		f.taper(14, 44, 50, 66, 88, 42, 1.6, e)  # deltoid edge
		f.soft("M20 8Q50 0 80 8Q84 30 50 48Q18 30 20 8Z", l, 0.6, 3)
	f.soft(f"M26 62Q50 54 74 62Q78 90 50 104Q24 90 26 62Z", l, 0.55, 3)
	f.taper(24, 64, 20, 84, 32, 102, 1.3, e)
	f.taper(76, 64, 80, 84, 68, 102, 1.3, e)
	f.taper(30, 106, 50, 113, 70, 106, 1.3, e)  # elbow
	f.soft("M72 40Q90 80 78 120Q90 150 82 172H105V40Z", d, 0.7, 2)
	f.soft("M-5 110Q14 130 8 172H-5Z", d, 0.5, 2)
	f.taper(30, 120, 24, 145, 34, 168, 1.2, e)
	f.taper(68, 120, 72, 145, 62, 168, 1.1, e)


def hand(f, side, key, skin, y=172):
	"""Clenched fist in the last stretch of an arm face."""
	d = shade(skin, 0.62)
	e = shade(skin, 0.38)
	h = 205 - y
	f.path(f"M-5 {y}H105V210H-5Z", skin)
	f.taper(-5, y, 50, y + 2, 105, y, 1.2, e)
	f.soft(f"M-5 {y + h * 0.82}H105V210H-5Z", d, 0.8, 1)
	if key == "O":  # back of the hand, knuckle bumps along the bottom
		for x in (22, 42, 62, 82):
			f.ink(f"M{x - 8} {y + h * 0.78}Q{x} {y + h * 0.62} {x + 8} {y + h * 0.78}", 1.1, e)
			f.taper(x, y + h * 0.15, x + 1, y + h * 0.4, x, y + h * 0.62, 0.6, d)
	elif key == "I":  # curled fingers, thumb across them
		for yy in (0.3, 0.52, 0.74):
			f.ink(f"M8 {y + h * yy}Q50 {y + h * yy + 3} 92 {y + h * yy}", 1.2, e)
		f.path(f"M18 {y + h * 0.1}Q50 {y + h * 0.02} 74 {y + h * 0.22}Q76 {y + h * 0.42} 56 {y + h * 0.46}Q30 {y + h * 0.46} 18 {y + h * 0.3}Z", shade(skin, 1.05), stroke=e, sw=1.1)
	elif key == "F":  # thumb side
		s = -out_sgn(side, key)
		x = 50 + s * 22
		f.path(f"M{x - 14} {y + h * 0.08}Q{x + 14} {y + h * 0.05} {x + 13} {y + h * 0.5}Q{x + 10} {y + h * 0.72} {x} {y + h * 0.7}Q{x - 12} {y + h * 0.5} {x - 14} {y + h * 0.08}Z", shade(skin, 1.05), stroke=e, sw=1.1)
		f.ink(f"M{x - 36 * s} {y + h * 0.2}V{y + h * 0.95}", 1.1, e)
		f.ink(f"M{x - 60 * s} {y + h * 0.28}V{y + h * 0.95}", 1.1, e)
	else:  # little finger side
		f.ink(f"M12 {y + h * 0.62}Q50 {y + h * 0.5} 88 {y + h * 0.62}", 1.2, e)
		f.taper(50, y + h * 0.1, 48, y + h * 0.3, 52, y + h * 0.5, 0.7, d)


def leg_muscle(f, skin, y0, y1):
	"""Bare leg stretch: knee cap, calf and shin."""
	d = shade(skin, 0.66)
	e = shade(skin, 0.42)
	f.path(f"M-5 {y0}H105V{y1}H-5Z", skin)
	k = y0 + (y1 - y0) * 0.22
	f.ink(f"M32 {k}Q50 {k - 8} 68 {k}", 1.2, e)
	f.ink(f"M34 {k + 10}Q50 {k + 16} 66 {k + 10}", 1.1, e)
	f.soft(f"M74 {y0}Q90 {(y0 + y1) / 2} 76 {y1}H105V{y0}Z", d, 0.75, 2)
	f.soft(f"M-5 {y0}Q8 {(y0 + y1) / 2} -5 {y1}Z", d, 0.5, 2)
	f.taper(30, k + 18, 24, (k + y1) / 2 + 4, 36, y1 - 6, 1.2, e)
	f.taper(70, k + 18, 76, (k + y1) / 2 + 4, 64, y1 - 6, 1.1, e)


def head_side(f, skin, hair, front_on_left, hair_front=0.42, low=0.5, back_low=0.8, ear=True, hair_d=None):
	"""A head side: jaw and cheek shading, an inked ear, the hair mass painted behind and above it."""
	w, h = f.w, f.h
	hd = hair_d or shade(hair, 0.55)
	X = (lambda t: t * w) if front_on_left else (lambda t: (1 - t) * w)  # t = 0 is the face side
	f.fill(skin)
	f.soft(f"M{X(-0.05)} {h * 0.74}Q{X(0.5)} {h * 0.84} {X(1.05)} {h * 0.7}V{h + 5}H{X(-0.05)}Z", shade(skin, 0.62), 0.85, 2)
	f.soft(f"M{X(0.0)} {h * 0.5}Q{X(0.18)} {h * 0.7} {X(0.04)} {h + 5}H{X(-0.05)}V{h * 0.5}Z", shade(skin, 1.1), 0.5, 2)
	f.ink(f"M{X(0.0)} {h * 0.95}Q{X(0.3)} {h * 0.92} {X(0.5)} {h * 0.7}", 1.1, shade(skin, 0.45))
	f.path(f"M{X(-0.05)} -5H{X(1.05)}V{h * back_low}Q{X(0.8)} {h * (back_low - 0.04)} {X(hair_front + 0.14)} {h * low}Q{X(hair_front)} {h * (low - 0.2)} {X(-0.05)} {h * 0.2}Z", hair)
	for t, y in ((0.25, 0.14), (0.45, 0.26), (0.68, 0.46), (0.88, 0.62)):
		f.taper(X(t), 2, X(t + 0.06), h * y * 0.6, X(t - 0.02), h * y, 1.6, hd)
	if ear:
		ex = X(hair_front + 0.06)
		f.path(f"M{ex - 9} {h * 0.42}q9 -11 18 0q2 11 -6 22q-5 4 -8 -2q-5 -10 -4 -20Z", skin, stroke=INK, sw=1.4)
		f.ink(f"M{ex - 4} {h * 0.45}q5 -5 9 1q0 7 -4 12", 1.0, shade(skin, 0.5))


def hair_back(f, hair, skin=None, nape=None, jag=8, seed_lines=9):
	"""A head back: the hair mass with inked strand clumps; nape = y where skin starts below a jagged edge."""
	w, h = f.w, f.h
	hd = shade(hair, 0.55)
	hl = shade(hair, 1.4)
	f.fill(skin or hair)
	end = nape if nape else h + 5
	zig = " ".join(f"L{w - i * w / jag:.1f} {end - (8 if i % 2 else 0)}" for i in range(jag + 1))
	f.path(f"M-5 -5H{w + 5}V{end} {zig}L-5 {end}Z", hair)
	f.soft(f"M-5 {h * 0.1}Q{w / 2} {h * 0.3} {w + 5} {h * 0.1}V{h * 0.3}Q{w / 2} {h * 0.46} -5 {h * 0.3}Z", hl, 0.35, 3)
	for i in range(seed_lines):
		x = (i + 0.5) * w / seed_lines
		f.taper(x, f.rng.uniform(-5, 14), x + f.rng.uniform(-8, 8), end * 0.55, x + f.rng.uniform(-6, 6), end - f.rng.uniform(3, 12), 1.7, hd)


# ---- bespoke meshes (run inside Blender only)


def _finish(kit, name, bm, colour, parent, smooth=True, lock=None):
	import bmesh
	import bpy

	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	if smooth:
		for p in mesh.polygons:
			p.use_smooth = True
	o = kit._obj(name, mesh, colour, parent)
	if lock:
		o["lock"] = (list(lock[0]), list(lock[1]))
	return o


def _catmull(pts, n):
	"""Resamples a polyline into n + 1 points on a Catmull-Rom curve through it."""
	out = []
	m = len(pts) - 1
	for k in range(n + 1):
		u = k / n * m
		i = min(int(u), m - 1)
		t = u - i
		p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, m)]
		out.append(tuple(0.5 * (2 * p1[a] + (p2[a] - p0[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t * t + (3 * p1[a] - p0[a] - 3 * p2[a] + p3[a]) * t * t * t) for a in range(3)))
	return out


def strand(kit, name, pts, r, colour, parent, flatten=0.5, rings=6, wide=None, blunt=0.0, belly=0.3):
	"""A long tapered ribbon through pts: 6 sided so painted strands map across it. wide = the world direction its broad
	side faces across; belly = where along it the width peaks; blunt = tip radius fraction (0 is a point)."""
	import bmesh
	from mathutils import Vector

	spine = [Vector(p) for p in _catmull(pts, rings)]
	bm = bmesh.new()
	prev = first = None
	for i in range(rings):
		t = i / rings
		d = (spine[i + 1] - spine[max(i - 1, 0)]).normalized()
		w = Vector(wide) if wide else d.cross(Vector((0, 0, 1)))
		if w.length < 0.05:
			w = Vector((1, 0, 0))
		w = (w - d * w.dot(d)).normalized()
		up = w.cross(d).normalized()
		rad = r * (min(1.0, 0.72 + t / max(belly, 0.01) * 0.28) if t < belly else max(blunt, ((1 - t) / (1 - belly)) ** 0.75))
		ring = [bm.verts.new(spine[i] + w * rad * math.cos(2 * math.pi * k / 6) + up * rad * flatten * math.sin(2 * math.pi * k / 6)) for k in range(6)]
		if prev:
			for k in range(6):
				bm.faces.new((prev[k], prev[(k + 1) % 6], ring[(k + 1) % 6], ring[k]))
		else:
			first = ring
		prev = ring
	end = bm.verts.new(spine[-1])
	for k in range(6):
		bm.faces.new((prev[k], prev[(k + 1) % 6], end))
	bm.faces.new(list(reversed(first)))
	return _finish(kit, name, bm, colour, parent, lock=(pts[0], pts[-1]))


def hairline(points):
	"""points = [(degrees, z)], interpolated round the head. 0 = the character's left (+X), 90 = back, 270 = front."""
	pts = sorted(points)

	def z(theta):
		theta %= 360
		for (a0, z0), (a1, z1) in zip(pts + [], pts[1:] + [(pts[0][0] + 360, pts[0][1])]):
			if a0 <= theta <= a1:
				return z0 + (z1 - z0) * (theta - a0) / (a1 - a0)
		a0, z0 = pts[-1]
		a1, z1 = pts[0][0] + 360, pts[0][1]
		t = theta + 360 if theta < pts[0][0] else theta
		return z0 + (z1 - z0) * (t - a0) / (a1 - a0)

	return z


def cap(kit, name, colour, parent, line, a=0.7, b=0.655, top=5.42, n=3.4, rings=6, seg=36, cy=0.0, p=3.2):
	"""Hair shell over the blocky head, rim at line(theta), rounded to a crown pole. Its strands run up the head."""
	import bmesh

	bm = bmesh.new()
	loops = []

	def at(theta, s):
		c, q = math.cos(math.radians(theta)), math.sin(math.radians(theta))
		return (a * s * math.copysign(abs(c) ** (2 / n), c), cy + b * s * math.copysign(abs(q) ** (2 / n), q))

	for i in range(rings + 2):
		ring = []
		for k in range(seg):
			theta = k * 360 / seg
			low = line(theta)
			if i == 0:  # rim tucks in under itself onto the head
				x, y = at(theta, 0.9)
				z = low + 0.02
			else:
				u = (i - 1) / (rings + 1)
				s = (1 - u**p) ** (1 / p)
				x, y = at(theta, s)
				z = low + (top - low) * u
			ring.append(bm.verts.new((x, y, z)))
		loops.append(ring)
	for r0, r1 in zip(loops, loops[1:]):
		for k in range(seg):
			bm.faces.new((r0[k], r0[(k + 1) % seg], r1[(k + 1) % seg], r1[k]))
	pole = bm.verts.new((0, cy, top))
	for k in range(seg):
		bm.faces.new((loops[-1][k], loops[-1][(k + 1) % seg], pole))
	bm.faces.new(list(reversed(loops[0])))
	return _finish(kit, name, bm, colour, parent, lock=((0, 0, line(90) - 0.1), (0, 0, top)))


def lathe(kit, name, prof, colour, parent, at=(0, 0, 0), seg=24, sx=1.0, sy=1.0, rot=(0, 0, 0), deform=None, lock=None, smooth=True):
	"""A spun mesh. prof = [(r, z)] bottom to top, closed at r = 0 ends. deform(x, y, z) -> (x, y, z) before rot and at."""
	import bmesh
	from mathutils import Euler, Vector

	bm = bmesh.new()
	e = Euler(rot, "XYZ")
	base = Vector(at)

	def vert(x, y, z):
		if deform:
			x, y, z = deform(x, y, z)
		v = Vector((x, y, z))
		v.rotate(e)
		return bm.verts.new(v + base)

	rows = []
	for r, z in prof:
		if r == 0:
			rows.append(vert(0, 0, z))
		else:
			rows.append([vert(r * sx * math.cos(2 * math.pi * k / seg), r * sy * math.sin(2 * math.pi * k / seg), z) for k in range(seg)])
	for r0, r1 in zip(rows, rows[1:]):
		for k in range(seg):
			k1 = (k + 1) % seg
			if isinstance(r0, list) and isinstance(r1, list):
				bm.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
			elif isinstance(r1, list):
				bm.faces.new((r0, r1[k1], r1[k]))
			else:
				bm.faces.new((r0[k], r0[k1], r1))
	if isinstance(rows[0], list):
		bm.faces.new(rows[0])
	if isinstance(rows[-1], list):
		bm.faces.new(list(reversed(rows[-1])))
	return _finish(kit, name, bm, colour, parent, smooth=smooth, lock=lock)


def sheet(kit, name, rows, colour, parent, thick=0.07, lock=None, inward=(0, 0, 4.7)):
	"""A hair or cloth sheet: rows of outer surface points from root to tip, each row the same length. It is given
	thickness towards the `inward` point, so a fringe can wrap the head."""
	import bmesh
	from mathutils import Vector

	bm = bmesh.new()
	c = Vector(inward)
	loops = []
	for row in rows:
		outer = [Vector(p) for p in row]
		inner = [p + (c - p).normalized() * thick for p in outer]
		loops.append([bm.verts.new(p) for p in outer] + [bm.verts.new(p) for p in reversed(inner)])
	n = len(loops[0])
	for r0, r1 in zip(loops, loops[1:]):
		for k in range(n):
			bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
	bm.faces.new(loops[0])
	bm.faces.new(list(reversed(loops[-1])))
	root = rows[0][len(rows[0]) // 2]
	tip = rows[-1][len(rows[-1]) // 2]
	return _finish(kit, name, bm, colour, parent, lock=lock or (root, tip))


def tube(kit, name, pts, r, colour, parent, rings=None, sides=8):
	"""A round tube of constant radius through pts, closed at both ends: staffs, swords, straps."""
	import bmesh
	from mathutils import Vector

	spine = [Vector(p) for p in (_catmull(pts, rings) if rings else pts)]
	bm = bmesh.new()
	prev = first = None
	for i, s in enumerate(spine):
		d = (spine[min(i + 1, len(spine) - 1)] - spine[max(i - 1, 0)]).normalized()
		w = d.cross(Vector((0, 0, 1)))
		if w.length < 0.05:
			w = Vector((1, 0, 0))
		w.normalize()
		up = w.cross(d).normalized()
		ring = [bm.verts.new(s + w * r * math.cos(2 * math.pi * k / sides) + up * r * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
		if prev:
			for k in range(sides):
				bm.faces.new((prev[k], prev[(k + 1) % sides], ring[(k + 1) % sides], ring[k]))
		else:
			first = ring
		prev = ring
	bm.faces.new(first)
	bm.faces.new(list(reversed(prev)))
	return _finish(kit, name, bm, colour, parent)


def lifted_zone(a, i, n, base, line, band):
	"""Zone i of n for near black hair: a lifted base tone, darker inked strands and a cool sheen band, or the strand
	drawing is lost on the model."""
	f = a["Hair"]
	zone = f.w / n
	x0 = i * zone
	f.path(f"M{x0} -5H{x0 + zone}V96H{x0}Z", base)
	f.path(f"M{x0} 96V70H{x0 + zone}V96Z", line, opacity=0.8, blur=2)
	for k in range(int(zone / 12)):
		x = x0 + (k + 0.5) * 12
		f.taper(x, f.rng.uniform(-3, 18), x + f.rng.uniform(-3, 3), 50, x + f.rng.uniform(-2, 2), 91, 1.4, line)
	f.path(f"M{x0} 30H{x0 + zone}V50H{x0}Z", band, opacity=0.6, blur=2)


def skirt(kit, name, colour, parent, panels, z0, z1, flare=0.08, rows=4, thick=0.05, hem=0.0):
	"""Hanging coat or jacket panels off the waist. panels = lists of (x, y) outline points at z0, pushed outwards with
	flare as they fall to z1; hem staggers every other point of the bottom edge."""
	for i, pl in enumerate(panels):
		out = []
		for r in range(rows):
			t = r / (rows - 1)
			z = z0 + (z1 - z0) * t
			row = []
			for k, (x, y) in enumerate(pl):
				n = (x * x + y * y) ** 0.5 or 1
				hemz = hem * (k % 2) * (1 if r == rows - 1 else 0)
				row.append((x + x / n * flare * t, y + y / n * flare * t, z + hemz))
			out.append(row)
		sheet(kit, f"{name}{i}", out, colour, parent, thick=thick, inward=(0, 0, (z0 + z1) / 2), lock=((0, 0, z1), (0, 0, z0)))


def bead(kit, name, at, r, colour, parent):
	lathe(kit, name, [(0, -r), (r * 0.72, -r * 0.65), (r, 0), (r * 0.72, r * 0.65), (0, r)], colour, parent, at=at, seg=6)


def disc(kit, name, at, r, depth, colour, parent, seg=12):
	"""A coin facing -Y."""
	lathe(kit, name, [(0, -depth), (r, -depth), (r, depth), (0, depth)], colour, parent, at=at, seg=seg, rot=(math.pi / 2, 0, 0))
