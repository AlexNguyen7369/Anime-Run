# Drawing and mesh helpers shared by the char_mha_*.py paint scripts.
import math

from atlas import FACES, INK, SIZE, shade

INSET = 2  # px kept from a face's edge, as avatar_paint


def ell(cx, cy, rx, ry=None):
	ry = rx if ry is None else ry
	return f"M{cx - rx} {cy}a{rx} {ry} 0 1 0 {2 * rx} 0a{rx} {ry} 0 1 0 {-2 * rx} 0Z"


def anime_eye(f, cx, cy, sgn, iris, w=20, h=14, arch=1.0, tilt=0.0, ir=None, lash=4.0, pupil=0.45, white="#fbf8f4", lash_col=INK):
	"""One hand-set eye. sgn +1 = on the viewer's right. tilt > 0 lifts the outer corner (a glare)."""
	inner, outer = cx - sgn * w / 2, cx + sgn * w / 2
	yi, yo = cy + tilt, cy - tilt
	top = cy - h * 0.62 * arch
	bot = cy + h * 0.5
	ir = ir or h * 0.5
	f.path(f"M{inner} {yi}Q{cx} {top - h * 0.1} {outer} {yo}Q{cx + sgn * w * 0.1} {bot + h * 0.2} {inner} {yi}Z", white, stroke=lash_col, sw=0.6)
	ix, iy = cx - sgn * w * 0.04, cy - h * 0.02
	f.path(ell(ix, iy, ir, ir * 1.12), iris)
	f.path(f"M{ix - ir} {iy - 0.5}a{ir} {ir * 1.05} 0 0 1 {2 * ir} 0Z", shade(iris, 0.42))
	f.path(f"M{ix - ir * 0.72} {iy + ir * 0.45}a{ir * 0.72} {ir * 0.5} 0 0 0 {1.44 * ir} 0Z", shade(iris, 1.55), opacity=0.85)
	f.path(ell(ix, iy, ir * pupil, ir * pupil * 1.15), "#0a0810")
	f.path(ell(ix - sgn * ir * 0.35, iy - ir * 0.42, max(0.9, ir * 0.22)), "#ffffff")
	# upper lid: a crescent heavier than the white, runs past the outer corner
	mid = top - h * 0.1
	f.path(f"M{inner - sgn} {yi + 1}Q{cx} {mid - lash} {outer + sgn * 2.2} {yo - 0.8}Q{cx} {mid + lash * 0.3} {inner - sgn} {yi + 1}Z", lash_col)
	f.ink(f"M{cx - sgn * w * 0.3} {bot + 0.8}Q{cx + sgn * w * 0.1} {bot + 1.6} {outer - sgn} {yo + 2}", 0.8, lash_col)


def nape(f, skin, hair, y=92):
	"""A head's back face: hair down to a jagged hairline, shadowed skin of the neck below it."""
	f.fill(shade(skin, 0.82))
	f.path(f"M-5 {y + 20}H135V135H-5Z", shade(skin, 0.6), opacity=0.7, blur=3)
	pts = "".join(f"L{x} {y + (10 if i % 2 else -6)}" for i, x in enumerate(range(130, -1, -13)))
	f.path(f"M-5-5H135V{y}{pts}L-5 {y}Z", hair)
	for x in range(8, 130, 13):
		f.taper(x, 0, x + 3, y * 0.5, x + 1, y - 6, 1.1, shade(hair, 0.55))


def fingers(f, y0, y1, skin_line, n=3):
	for i in range(n):
		x = (i + 1) * 100 / (n + 1)
		f.taper(x, y0, x + 1, (y0 + y1) / 2, x, y1, 1.0, skin_line)


# ---- meshes (kit is avatar_base; only called inside Blender)


def _finish(kit, name, verts, faces, colour, parent, smooth=True, root=None, tip=None):
	import bmesh
	import bpy

	bm = bmesh.new()
	vs = [bm.verts.new(v) for v in verts]
	for q in faces:
		bm.faces.new([vs[i] for i in q])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	if smooth:
		for p in mesh.polygons:
			p.use_smooth = True
	o = kit._obj(name, mesh, colour, parent)
	if root:
		o["lock"] = (list(root), list(tip))
	return o


def loft(kit, name, rings, colour, parent, sides=12, power=2.0, root=None, tip=None, smooth=True):
	"""Closed skin over rings (cx, cy, z, rx, ry) of superellipse section; power 2 is an oval, 4 a soft square."""
	verts, faces = [], []
	e = 2 / power
	for cx, cy, z, rx, ry in rings:
		for k in range(sides):
			a = 2 * math.pi * k / sides
			c, s = math.cos(a), math.sin(a)
			verts.append((cx + rx * math.copysign(abs(c) ** e, c), cy + ry * math.copysign(abs(s) ** e, s), z))
	for i in range(len(rings) - 1):
		for k in range(sides):
			k1 = (k + 1) % sides
			faces.append((i * sides + k, i * sides + k1, (i + 1) * sides + k1, (i + 1) * sides + k))
	faces.append(tuple(range(sides)))
	faces.append(tuple((len(rings) - 1) * sides + k for k in range(sides)))
	return _finish(kit, name, verts, faces, colour, parent, smooth, root, tip)


def tube(kit, name, spine, radii, colour, parent, flatten=0.8, sides=6, strands=True):
	"""A tube along spine; the last radius 0 makes a point. Frames are parallel-transported, so hooks do not twist."""
	from mathutils import Vector

	spine = [Vector(p) for p in spine]
	first = (spine[1] - spine[0]).normalized()
	side = first.cross(Vector((0, 0, 1)))
	if side.length < 0.05:
		side = first.cross(Vector((1, 0, 0)))
	side.normalize()
	verts, faces = [], []
	n = len(spine)
	for i in range(n - 1):
		d = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized()
		side = (side - d * side.dot(d)).normalized()
		up = side.cross(d).normalized()
		for k in range(sides):
			a = 2 * math.pi * k / sides
			verts.append(tuple(spine[i] + side * radii[i] * math.cos(a) + up * radii[i] * flatten * math.sin(a)))
	verts.append(tuple(spine[-1]))
	end = len(verts) - 1
	for i in range(n - 2):
		for k in range(sides):
			k1 = (k + 1) % sides
			faces.append((i * sides + k, i * sides + k1, (i + 1) * sides + k1, (i + 1) * sides + k))
	for k in range(sides):
		faces.append(((n - 2) * sides + k, (n - 2) * sides + (k + 1) % sides, end))
	faces.append(tuple(range(sides)))
	return _finish(kit, name, verts, faces, colour, parent, True, tuple(spine[0]) if strands else None, tuple(spine[-1]) if strands else None)


def tuft(kit, name, base, direction, length, r, bend, colour, parent, flatten=0.85, n=6, sides=6):
	"""A fat hooked lock: swells after the root, then bends towards `bend` as it narrows, the way a curl rolls over."""
	from mathutils import Vector

	d0, b = Vector(direction).normalized(), Vector(bend)
	p = Vector(base)
	spine = [p.copy()]
	for i in range(n):
		t = (i + 1) / n
		p = p + (d0 + b * t**1.4).normalized() * (length / n)
		spine.append(p.copy())
	radii = [r * math.sin(math.pi * (0.22 + 0.78 * (i / n))) ** 0.8 if i < n else 0.0 for i in range(n + 1)]
	return tube(kit, name, spine, radii, colour, parent, flatten, sides)


def torus(kit, name, centre, axis_x, r, thick, colour, parent, n=10, sides=4):
	"""A ring standing in the YZ plane at `centre` (axis_x True) or in the XZ plane."""
	verts, faces = [], []
	for i in range(n):
		a = 2 * math.pi * i / n
		for k in range(sides):
			b = 2 * math.pi * k / sides
			rr = r + thick * math.cos(b)
			off = thick * math.sin(b)
			u, v = rr * math.cos(a), rr * math.sin(a)
			verts.append((centre[0] + off, centre[1] + u, centre[2] + v) if axis_x else (centre[0] + u, centre[1] + off, centre[2] + v))
	for i in range(n):
		i1 = (i + 1) % n
		for k in range(sides):
			k1 = (k + 1) % sides
			faces.append((i * sides + k, i * sides + k1, i1 * sides + k1, i1 * sides + k))
	return _finish(kit, name, verts, faces, colour, parent)


def shell(kit, name, block, parent, rings):
	"""A shaped box painted with `block`'s own atlas faces, so a broad build keeps its art: rings top to bottom,
	(z, x0, x1, y0, y1). Texture stretches to the ring, unlike the fixed 6 blocks underneath it."""
	import bmesh
	import bpy

	limb = block not in ("Head", "Torso")
	px = ("O" if block.startswith("Left") else "I") if limb else "L"
	nx = ("I" if block.startswith("Left") else "O") if limb else "R"
	zt, zb = rings[0][0], rings[-1][0]
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	vs = []
	for z, x0, x1, y0, y1 in rings:
		vs += [bm.verts.new(p) for p in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))]
	# per side: the corner pair and the u of each, viewer's right as avatar_paint maps it
	sides = ((0, 1, "F"), (1, 2, px), (2, 3, "B"), (3, 0, nx))
	made = []
	for i in range(len(rings) - 1):
		ta, tb = (zt - rings[i][0]) / (zt - zb), (zt - rings[i + 1][0]) / (zt - zb)
		for a, c, key in sides:
			f = bm.faces.new((vs[i * 4 + a], vs[i * 4 + c], vs[(i + 1) * 4 + c], vs[(i + 1) * 4 + a]))
			made.append((f, key, {f.verts[0]: (0, ta), f.verts[1]: (1, ta), f.verts[2]: (1, tb), f.verts[3]: (0, tb)}))
	top = bm.faces.new(vs[:4])
	made.append((top, "T", {vs[0]: (0, 0), vs[1]: (1, 0), vs[2]: (1, 1), vs[3]: (0, 1)}))
	bot = bm.faces.new(vs[-4:])
	made.append((bot, "Bo", {vs[-4]: (0, 1), vs[-3]: (1, 1), vs[-2]: (1, 0), vs[-1]: (0, 0)}))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
	for f, key, m in made:
		x, y, pw, ph = FACES[f"{block}_{key}"][:4]
		for l in f.loops:
			u, t = m[l.vert]
			l[uv].uv = ((x + INSET + u * (pw - 2 * INSET)) / SIZE, 1 - (y + INSET + t * (ph - 2 * INSET)) / SIZE)
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	o = kit._obj(name, mesh, "#808080", parent)
	o["painted"] = True
	return o


def lr(part, **p):
	"""The same prop on both limbs; a prop's own `mirror` would parent both copies to one limb."""
	out = []
	for side, sgn in (("Left", 1), ("Right", -1)):
		q = dict(p, part=side + part)
		if "at" in q:
			q["at"] = [sgn * q["at"][0], q["at"][1], q["at"][2]]
		if "lock" in q:
			q["lock"] = [[sgn * c[0], c[1], c[2]] for c in q["lock"]]
		out.append(q)
	return out
