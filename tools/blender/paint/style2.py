# Layered-cloth look (pilot leaf_medic, sea_captain, db_hero, leaf_hero; docs/CHARACTER_GACHA_SPEC.md "Painted textures").
# Hair is one voxel-remeshed smooth mass; clothes are lofted shells with their own silhouette. Gradients live in the
# atlas's Hair strip (Ramps), so everything here is a painted=True mesh. bpy is imported lazily: atlas.py runs under python3.
import math

from atlas import FACES, INK, SIZE, shade
from leaf_common import begin_clip, ell, end_clip


class Ramps:
	"""Named vertical gradients in the Hair strip, dark at v = 0, light at v = 1. stops = colours, evenly spaced."""

	def __init__(self, **ramps):
		self.names = list(ramps) + ["ink"]
		self.ramps = dict(ramps, ink=[INK, INK])
		self.tex = {}  # ramp name -> "strand" or "weave": lines painted over the gradient

	def textured(self, **tex):
		self.tex = tex
		return self

	def paint(self, a):
		f = a["Hair"]
		zone = f.w / len(self.names)
		for i, n in enumerate(self.names):
			stops = self.ramps[n]
			s = "".join(f'<stop offset="{k / (len(stops) - 1):.3f}" stop-color="{c}"/>' for k, c in enumerate(stops))
			f.out.append(f'<linearGradient id="ramp{i}" x1="0" y1="1" x2="0" y2="0">{s}</linearGradient>')
			f.out.append(f'<rect x="{i * zone:.2f}" y="-5" width="{zone:.2f}" height="{f.h + 10}" fill="url(#ramp{i})"/>')
			self._lines(f, self.tex.get(n), i * zone, zone, stops)

	def _lines(self, f, kind, x0, zone, stops):
		x1 = x0 + zone
		if kind == "strand":
			# strand lines running root to tip, a soft light band across them
			for k in range(26):
				x = x0 + 4 + (zone - 8) * (k + f.rng.uniform(0.1, 0.9)) / 26
				f.path(f"M{x:.1f} -5L{x + f.rng.uniform(-2, 2):.1f} 96", stroke=shade(stops[0], 0.8) if k % 2 else "#ffffff", sw=f.rng.uniform(0.7, 1.4), opacity=0.32)
			f.path(f"M{x0} 30H{x1}V44H{x0}Z", "#ffffff", opacity=0.34, blur=3)
		elif kind == "weave":
			# rings of straw round the hat, crossed by short faint stitches
			for y in range(3, 91, 6):
				f.path(f"M{x0} {y}H{x1}", stroke=shade(stops[0], 0.72), sw=1.1, opacity=0.5)
			for k in range(14):
				x = x0 + 4 + (zone - 8) * k / 14
				f.path(f"M{x:.1f} -5V96", stroke=shade(stops[0], 0.85), sw=0.7, opacity=0.35)

	def uv(self, name, v, u=0.5):
		x, y, pw, ph = FACES["Hair"][:4]
		v = max(0.0, min(1.0, v))
		return ((x + (self.names.index(name) + 0.06 + 0.88 * u) * pw / len(self.names)) / SIZE, 1 - (y + ph - 4 - v * (ph - 8)) / SIZE)


def H(b, c, t, r, flat=0.7, p=1.0, q=0.8, m=False):
	"""One hair chunk: bezier spine b-c-t, radius r, thin by flat towards the head; radius = r * (1 - t^p)^q.
	q near 1 with p 1 is a spike, p 4 with q 0.5 a rounded end. m mirrors it across x."""
	return dict(b=b, c=c, t=t, r=r, flat=flat, p=p, q=q, m=m)


def _smooth(a, b, x):
	x = max(0.0, min(1.0, (x - a) / (b - a)))
	return x * x * (3 - 2 * x)


# front stays one plane (y -0.6) from brow to chin: with flat shading there the face art has no bands
HEAD = [(0, 0, 5.3, 0.5, 0.46), (0, 0, 5.22, 0.62, 0.6), (0, 0, 4.7, 0.65, 0.6), (0, 0, 4.36, 0.62, 0.6), (0, 0, 4.16, 0.5, 0.6), (0, 0, 4.0, 0.36, 0.46)]


class Kit:
	def __init__(self, kit, parts, ramps, outline=0.04):
		self.kit, self.parts, self.R, self.outline = kit, parts, ramps, outline
		for o in parts.values():
			o["outline"] = outline

	def _mesh(self, name, part, verts, faces, flat_faces=(), outline=None):
		import bmesh
		import bpy

		bm = bmesh.new()
		vs = [bm.verts.new(v) for v in verts]
		for f in faces:
			bm.faces.new([vs[i] for i in f])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
		for i, f in enumerate(bm.faces):
			f.smooth = i not in flat_faces
		mesh = bpy.data.meshes.new(name)
		bm.to_mesh(mesh)
		bm.free()
		o = self.kit._obj(f"{part}_{name}", mesh, "#808080", self.parts[part])
		o["painted"] = True
		o["outline"] = self.outline if outline is None else outline
		return o

	def _loft(self, rings, caps=(True, True)):
		"""Quads between equal-length rings, flat n-gon caps. Returns verts, faces, cap face indices."""
		n = len(rings[0])
		verts = [p for r in rings for p in r]
		faces = [(i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k) for i in range(len(rings) - 1) for k in range(n)]
		flat = []
		for on, i in zip(caps, (0, len(rings) - 1)):
			if on:
				flat.append(len(faces))
				faces.append([i * n + k for k in range(n)])
		return verts, faces, flat

	def _ramp_uv(self, o, name, vfn, ink_verts=(), ufn=None):
		"""vfn(vertex index, position) -> ramp v; ufn(vertex index) -> place across the zone, for ramps with painted lines.
		A polygon entirely on ink verts takes the ink zone."""
		mesh = o.data
		uv = mesh.uv_layers.new(name="UVMap").data
		for poly in mesh.polygons:
			ink = all(i in ink_verts for i in poly.vertices)
			for li in poly.loop_indices:
				vi = mesh.loops[li].vertex_index
				uv[li].uv = self.R.uv("ink", 0.5) if ink else self.R.uv(name, vfn(vi, mesh.vertices[vi].co), ufn(vi) if ufn else 0.5)

	def _face_uv(self, o, block, norm, ink_verts=(), key=None):
		"""Block art by each polygon's main direction. norm[vi] = (x, y) in -1..1 across the shell, so art follows a flare."""
		import avatar_paint

		_, _, size, centre, _ = next(b for b in avatar_paint.BLOCKS if b[0] == block)
		mesh = o.data
		uv = mesh.uv_layers.new(name="UVMap").data
		hz = size[2] / 2
		for poly in mesh.polygons:
			n = poly.normal
			axis = max(range(3), key=lambda a: abs(n[a]))
			positive = n[axis] > 0
			k = key or avatar_paint._face_key(block, axis, positive)
			x0, y0, pw, ph = FACES[f"{block}_{k}"][:4]
			ink = all(i in ink_verts for i in poly.vertices)
			for li in poly.loop_indices:
				if ink:
					uv[li].uv = self.R.uv("ink", 0.5)
					continue
				vi = mesh.loops[li].vertex_index
				rx, ry = norm[vi]
				cz = mesh.vertices[vi].co.z - centre[2]
				if axis == 1:
					u = (rx + 1) / 2 if not positive else (1 - rx) / 2
					t = (hz - cz) / size[2]
				elif axis == 0:
					u = (ry + 1) / 2 if positive else (1 - ry) / 2
					t = (hz - cz) / size[2]
				else:
					u = (rx + 1) / 2
					t = (ry + 1) / 2 if positive else (1 - ry) / 2
				u, t = max(0.0, min(1.0, u)), max(0.0, min(1.0, t))
				uv[li].uv = ((x0 + 2 + u * (pw - 4)) / SIZE, 1 - (y0 + 2 + t * (ph - 4)) / SIZE)

	def tube(self, part, name, rows, skin, corner=0.4, nc=2, sub=0, ink=(False, False), zig=0.0, v=(0.25, 0.95), outline=None, fit=True, key=None):
		"""Rounded-rectangle loft along z. rows = (cx, cy, z, half width, half depth), any order. skin = ramp name or
		("face", block). ink adds a dark lip at the first / last row. zig zigzags the last row by that much (a frayed cuff).
		fit True spreads block art over the shell's own width; False keeps the art at its true position."""
		import avatar_paint

		rows = list(rows)
		if ink[0]:
			c = rows[0]
			rows.insert(0, (c[0], c[1], c[2] + 0.028 * (1 if rows[0][2] > rows[1][2] else -1), c[3] * 0.985, c[4] * 0.985))
		if ink[1]:
			c = rows[-1]
			rows.append((c[0], c[1], c[2] + 0.028 * (1 if rows[-1][2] > rows[-2][2] else -1), c[3] * 0.985, c[4] * 0.985))
		rings, norm = [], []
		zs = [r[2] for r in rows]
		for ri, (cx, cy, z, hw, hd) in enumerate(rows):
			rad = corner * min(hw, hd)
			arcs = [
				[(qx * (hw - rad) + rad * math.cos(math.radians(a0 + 90 * k / nc)), qy * (hd - rad) + rad * math.sin(math.radians(a0 + 90 * k / nc))) for k in range(nc + 1)]
				for qx, qy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270))
			]
			ring = []
			for i, arc in enumerate(arcs):
				ring += arc
				nxt = arcs[(i + 1) % 4][0]
				ring += [(arc[-1][0] + (nxt[0] - arc[-1][0]) * s / (sub + 1), arc[-1][1] + (nxt[1] - arc[-1][1]) * s / (sub + 1)) for s in range(1, sub + 1)]
			pts = []
			for k, (px, py) in enumerate(ring):
				dz = zig * (1 if k % 2 else -1) if zig and ri == len(rows) - 1 else 0.0
				pts.append((cx + px, cy + py, z + dz))
				norm.append((px / hw, py / hd))
			rings.append(pts)
		verts, faces, flat = self._loft(rings)
		o = self._mesh(name, part, verts, faces, flat, outline)
		n = len(rings[0])
		ink_verts = set()
		if ink[0]:
			ink_verts.update(range(n))
		if ink[1]:
			ink_verts.update(range((len(rows) - 1) * n, len(rows) * n))
		lo, hi = min(zs), max(zs)
		if isinstance(skin, tuple):
			block = skin[1]
			if not fit:
				_, _, size, centre, _ = next(b for b in avatar_paint.BLOCKS if b[0] == block)
				norm = [((p[0] - centre[0]) / (size[0] / 2), (p[1] - centre[1]) / (size[1] / 2)) for p in verts]
			self._face_uv(o, block, norm, ink_verts, key)
		else:
			self._ramp_uv(o, skin, lambda vi, co: v[0] + (v[1] - v[0]) * (co.z - lo) / max(hi - lo, 1e-6), ink_verts)
		return o

	def head(self, rows=HEAD):
		"""Replaces the Head block by a sculpted loft wearing the same Head_* art, its front flat-shaded."""
		self.reshape("Head", "Head", rows, corner=0.3, nc=3, fit=False, flat_front=True)

	def reshape(self, part, block, rows, corner=0.25, nc=2, fit=True, flat_front=False):
		"""Replaces a body block's mesh by a loft wearing the same art. The rig centre does not move."""
		import bpy

		o = self.tube(part, "Sculpt", rows, ("face", block), corner=corner, nc=nc, outline=0, fit=fit)
		if flat_front:
			for p in o.data.polygons:
				if p.normal.y < -0.95:
					p.use_smooth = False
		h = self.parts[part]
		loc = h.location
		for vert in o.data.vertices:
			vert.co -= loc
		old = h.data
		h.data = o.data
		bpy.data.objects.remove(o)
		bpy.data.meshes.remove(old)
		h["outline"] = self.outline

	def lathe(self, part, name, rows, skin, n=32, at=(0, 0, 0), squash=1.0, wob=None, waves=0, outline=None):
		"""Solid of revolution. rows = (radius, z, ramp v). wob(angle, row index) -> z shift, for a wavy brim. waves > 0
		runs the zone's painted lines round it that many times."""
		rings = []
		for ri, (r, z, _) in enumerate(rows):
			ring = []
			for k in range(n):
				a = 2 * math.pi * k / n
				ring.append((at[0] + max(r, 0.002) * math.cos(a), at[1] + max(r, 0.002) * squash * math.sin(a), at[2] + z + (wob(a, ri) if wob else 0.0)))
			rings.append(ring)
		verts, faces, flat = self._loft(rings)
		o = self._mesh(name, part, verts, faces, flat, outline)
		ufn = (lambda vi: abs(2 * ((vi % n) * waves / n % 1) - 1)) if waves else None
		self._ramp_uv(o, skin, lambda vi, co: rows[vi // n][2], ufn=ufn)
		return o

	def tip(self, o, deg, pivot):
		"""Tips a built mesh back about the X axis through pivot: its front rises."""
		a = math.radians(-deg)
		c, s = math.cos(a), math.sin(a)
		for vt in o.data.vertices:
			y, z = vt.co.y - pivot[1], vt.co.z - pivot[2]
			vt.co.y, vt.co.z = pivot[1] + y * c - z * s, pivot[2] + y * s + z * c
		o.data.update()
		return o

	def lock(self, part, name, ch, skin, v=(0.3, 1.0), rn=8, sn=8, outline=0.024):
		"""One separate tapered hank with painted strands: u across it, v root to tip."""
		rings, _ = _chunk_rings(ch, rn, sn)
		verts, faces, flat = self._loft(rings)
		o = self._mesh(name, part, verts, faces, flat, outline)
		u0 = 0.05 + 0.4 * (sum(map(ord, name)) * 0.37 % 1)
		self._ramp_uv(o, skin, lambda vi, co: v[0] + (v[1] - v[0]) * (vi // sn) / rn, ufn=lambda vi: u0 + 0.5 * abs(2 * (vi % sn) / sn - 1))
		return o

	def locks(self, part, tag, chunks, skin, **kw):
		i = 0
		for ch in chunks:
			for c in [ch, dict(ch, b=_mx(ch["b"]), c=_mx(ch["c"]), t=_mx(ch["t"]))] if ch["m"] else [ch]:
				self.lock(part, f"{tag}{i}", c, skin, **kw)
				i += 1

	def blob(self, part, name, at, radii, skin, v=0.6, rings=6, n=12, outline=None):
		rows = [(math.sin(math.pi * i / rings), math.cos(math.pi * i / rings)) for i in range(rings + 1)]
		verts_r = []
		for s, c in rows:
			verts_r.append([(at[0] + radii[0] * max(s, 0.01) * math.cos(2 * math.pi * k / n), at[1] + radii[1] * max(s, 0.01) * math.sin(2 * math.pi * k / n), at[2] + radii[2] * c) for k in range(n)])
		verts, faces, flat = self._loft(verts_r, caps=(True, True))
		o = self._mesh(name, part, verts, faces, flat, outline)
		self._ramp_uv(o, skin, lambda vi, co: v + 0.25 * (co.z - at[2]) / radii[2])
		return o

	def band(self, part, name, at, rx, ry, a0, a1, height, skin, thick=0.05, e=0.6, n=28, flare=0.0, rot=None, v=(0.3, 0.95), outline=None):
		"""An open ring of cloth round at (a collar, a hairband). Angle 0 is +X, -90 the front. height(a deg) -> (z0, z1)
		relative to at; flare pushes the top outwards. e < 1 squares the ellipse off. rot = Euler to tilt it."""
		from mathutils import Euler, Vector

		mat = Euler(rot).to_matrix() if rot else None
		rings = []
		for i in range(n + 1):
			ad = a0 + (a1 - a0) * i / n
			a = math.radians(ad)
			c, s = math.cos(a), math.sin(a)
			px = rx * math.copysign(abs(c) ** e, c)
			py = ry * math.copysign(abs(s) ** e, s)
			nl = math.hypot(px / rx**2, py / ry**2)
			ox, oy = px / rx**2 / nl, py / ry**2 / nl
			z0, z1 = height(ad)
			ring = []
			for off, z, fl in ((0, z0, 0), (thick, z0, 0), (thick, z1, flare), (thick * 0.5, z1 + thick * 0.4, flare), (0, z1, flare)):
				p = Vector((px + ox * (off + fl), py + oy * (off + fl), z))
				if mat:
					p = mat @ p
				ring.append((at[0] + p.x, at[1] + p.y, at[2] + p.z))
			rings.append(ring)
		verts, faces, flat = self._loft(rings)
		o = self._mesh(name, part, verts, faces, flat, outline)
		zs = [p[2] for p in verts]
		lo, hi = min(zs), max(zs)
		self._ramp_uv(o, skin, lambda vi, co: v[0] + (v[1] - v[0]) * (co.z - lo) / max(hi - lo, 1e-6))
		return o

	def band_on(self, part, name, hair, at, rot, a0, a1, half, thick, skin, v=0.72, n=48, outline=0.018):
		"""A thin band laid ON a finished hair mesh: rays from at find the surface along the arc a0..a1 (degrees, in the
		XZ plane tilted by rot about X), so it follows the mass exactly from every side."""
		from mathutils import Vector
		from mathutils.bvhtree import BVHTree

		mesh = hair.data
		# flat n-gon caps are skipped: a ray leaving through an open cap misses, and the band runs on at the skull's radius
		bvh = BVHTree.FromPolygons([vt.co.copy() for vt in mesh.vertices], [list(p.vertices) for p in mesh.polygons if len(p.vertices) <= 4])
		origin = Vector(at)
		c, s = math.cos(rot), math.sin(rot)
		nrm = Vector((0, c, s))  # the plane's normal: the band's width runs along it

		def hit(d):
			loc = bvh.ray_cast(origin, d.normalized(), 3.0)[0]
			return loc if loc is not None else origin + d.normalized() * 0.7

		edges = [[], []]
		for i in range(n + 1):
			a = math.radians(a0 + (a1 - a0) * i / n)
			d = Vector((math.cos(a), -s * math.sin(a), c * math.sin(a)))
			for e, sgn in enumerate((-1, 1)):
				edges[e].append(hit(d + nrm * sgn * half / 0.65))
		# averaging along the arc irons out small bumps in the mass: a clean edge
		for e in edges:
			e[:] = [sum(e[max(0, i - 2) : i + 3], Vector()) / len(e[max(0, i - 2) : i + 3]) for i in range(len(e))]
		rings = []
		for p0, p1 in zip(*edges):
			out = ((p0 + p1) / 2 - origin).normalized()
			rings.append([tuple(p0 - out * 0.02), tuple(p1 - out * 0.02), tuple(p1 + out * thick), tuple(p0 + out * thick)])
		verts, faces, flat = self._loft(rings)
		o = self._mesh(name, part, verts, faces, flat, outline)
		self._ramp_uv(o, skin, lambda vi, co: v)
		return o

	def hair(self, part, name, chunks, skin, voxel=0.035, target=1500, relax=6, tone=(0.5, 0.42, 0.28, 0.2), blobs=(), solids=(), outline=None):
		"""One smooth sculpted mass: chunks unioned by voxel remesh, relaxed, decimated. Each vertex's ramp v comes from
		how far it sits from the crease between its two nearest chunks, its way along the chunk, and its height.
		tone = (base, crease, root-to-tip, height). blobs = (centre, radii) ellipsoids in the union (the crown); solids =
		tube rows in the union (a bob's straight sides and clean hem)."""
		import bmesh
		import bpy
		from mathutils import Vector

		verts, faces, spines = [], [], []
		for ch in [c for ch in chunks for c in ([ch, dict(ch, b=_mx(ch["b"]), c=_mx(ch["c"]), t=_mx(ch["t"]), m=False)] if ch["m"] else [ch])]:
			base = len(verts)
			rings, spine = _chunk_rings(ch, 12, 12)
			vv, ff, _ = self._loft(rings)
			verts += vv
			faces += [[i + base for i in f] for f in ff]
			spines.append(spine)
		for centre, radii in blobs:
			base = len(verts)
			rows = 10
			rings = [[(centre[0] + radii[0] * max(math.sin(math.pi * i / rows), 0.01) * math.cos(2 * math.pi * k / 16), centre[1] + radii[1] * max(math.sin(math.pi * i / rows), 0.01) * math.sin(2 * math.pi * k / 16), centre[2] + radii[2] * math.cos(math.pi * i / rows)) for k in range(16)] for i in range(rows + 1)]
			vv, ff, _ = self._loft(rings)
			verts += vv
			faces += [[i + base for i in f] for f in ff]
			spines.append([(Vector(centre), max(radii), 0.5)])
		for rows in solids:
			base = len(verts)
			rings = []
			for cx, cy, z, hw, hd in rows:
				rad = 0.8 * min(hw, hd)
				rings.append([(cx + qx * (hw - rad) + rad * math.cos(math.radians(a0 + 15 * k)), cy + qy * (hd - rad) + rad * math.sin(math.radians(a0 + 15 * k)), z) for qx, qy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)) for k in range(7)])
			vv, ff, _ = self._loft(rings)
			verts += vv
			faces += [[i + base for i in f] for f in ff]
			spines.append([(Vector((r[0], r[1], r[2])), max(r[3], r[4]), 0.5) for r in rows])
		src = bpy.data.meshes.new(name + "_src")
		src.from_pydata(verts, [], faces)
		src.update()
		tmp = bpy.data.objects.new(name + "_tmp", src)
		bpy.context.scene.collection.objects.link(tmp)
		m = tmp.modifiers.new("r", "REMESH")
		m.mode = "VOXEL"
		m.voxel_size = voxel
		sm = tmp.modifiers.new("s", "SMOOTH")
		sm.factor = 0.6
		sm.iterations = relax
		dg = bpy.context.evaluated_depsgraph_get()
		count = len(tmp.evaluated_get(dg).data.polygons) * 2
		dec = tmp.modifiers.new("d", "DECIMATE")
		dec.ratio = min(1.0, target / max(count, 1))
		dg = bpy.context.evaluated_depsgraph_get()
		mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
		bpy.data.objects.remove(tmp)
		bpy.data.meshes.remove(src)
		# decimating a thin spike tip can leave two faces on the same three verts, which the merge cannot rebuild
		bm = bmesh.new()
		bm.from_mesh(mesh)
		seen, dup = set(), []
		for fc in bm.faces:
			key = frozenset(vt.index for vt in fc.verts)
			if key in seen:
				dup.append(fc)
			seen.add(key)
		bmesh.ops.delete(bm, geom=dup, context="FACES_ONLY")
		# remeshing can pinch a spike's very tip off: keep only the main mass
		islands, seen = [], set()
		for vt in bm.verts:
			if vt in seen:
				continue
			stack, isl = [vt], []
			seen.add(vt)
			while stack:
				q = stack.pop()
				isl.append(q)
				for e in q.link_edges:
					w = e.other_vert(q)
					if w not in seen:
						seen.add(w)
						stack.append(w)
			islands.append(isl)
		islands.sort(key=len)
		bmesh.ops.delete(bm, geom=[vt for isl in islands[:-1] for vt in isl], context="VERTS")
		bm.to_mesh(mesh)
		bm.free()
		mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
		mesh.update()
		o = self.kit._obj(f"{part}_{name}", mesh, "#808080", self.parts[part])
		o["painted"] = True
		o["outline"] = self.outline if outline is None else outline
		zs = [vt.co.z for vt in mesh.vertices]
		lo, hi = min(zs), max(zs)
		base_t, k_crease, k_t, k_z = tone

		def v_of(vi, co):
			near = [min(((co - p).length / (r + 0.03), s) for p, r, s in sp) for sp in spines]
			near.sort()
			crease = _smooth(0.0, 0.45, near[1][0] - near[0][0]) if len(near) > 1 else 1.0
			# root-to-tip blended over the nearby chunks, so no step where one chunk hands over to the next
			wt = [d**-6 for d, _ in near]
			along = sum(w * s for w, (_, s) in zip(wt, near)) / sum(wt)
			return base_t + k_crease * (crease - 0.6) + k_t * (along - 0.5) + k_z * ((co.z - lo) / max(hi - lo, 1e-6) - 0.5)

		cache = {}
		self._ramp_uv(o, skin, lambda vi, co: cache.setdefault(vi, v_of(vi, co)))
		return o


def _chunk_rings(ch, rn, sn):
	"""A chunk's section rings along its spine, and the spine as (point, radius, 0..1)."""
	from mathutils import Vector

	rings, spine, prev = [], [], None
	b, c, t = Vector(ch["b"]), Vector(ch["c"]), Vector(ch["t"])
	for i in range(rn + 1):
		s = i / rn
		p = b * (1 - s) ** 2 + c * 2 * s * (1 - s) + t * s**2
		d = ((c - b) * 2 * (1 - s) + (t - c) * 2 * s).normalized()
		out = p - Vector((0, 0, 4.9))
		a = out - d * out.dot(d)
		if a.length < 0.15:
			a = prev if prev is not None else Vector((0, -1, 0)) - d * d.y
		a.normalize()
		if prev is not None and a.dot(prev) < 0:
			a = -a
		prev = a
		w = d.cross(a).normalized()
		r = ch["r"] * max(0.0, 1 - s ** ch["p"]) ** ch["q"]
		r = max(r, 0.006)
		rings.append([tuple(p + w * r * math.cos(2 * math.pi * k / sn) + a * r * ch["flat"] * math.sin(2 * math.pi * k / sn)) for k in range(sn)])
		spine.append((p, r, s))
	return rings, spine


def _mx(p):
	return (-p[0], p[1], p[2])


# ---- the face: small, low, calm


def eye(f, cx, cy, sgn, iris, w=24, h=11, lid=3.0, tilt=1.5, flick=3.0, look=0.0, lash=INK, white="#fdfaf4"):
	"""An anime eye that holds up at game distance: clipped white, ringed iris, dark pupil, one small highlight, a heavy
	inked upper lid with a flick. Proportions stay realistic: w about a fifth of the face. sgn +1 = on the viewer's right."""
	i, o = cx - sgn * w / 2, cx + sgn * w / 2
	iy, oy = cy + h * 0.18, cy - tilt
	ctop = cy - h
	shape = f"M{i} {iy}Q{cx - sgn * w * 0.05} {ctop} {o} {oy}Q{cx + sgn * w * 0.18} {cy + h * 0.95} {i} {iy}Z"
	begin_clip(f, shape)
	f.path(shape, white)
	r, ix, ry = h * 0.62, cx + look, cy + h * 0.02
	f.path(ell(ix, ry, r), shade(iris, 0.42))
	f.path(ell(ix, ry, r * 0.84), iris)
	f.path(ell(ix, ry + r * 0.42, r * 0.56, r * 0.34), shade(iris, 1.45))
	f.path(ell(ix, ry, r * 0.42), "#0a0810")
	f.path(ell(ix - sgn * r * 0.34, ry - r * 0.36, r * 0.2), "#ffffff")
	f.path(f"M{i} {iy - h * 0.1}Q{cx} {ctop} {o} {oy - 1}V{cy - h}H{i}Z", "#1a1420", opacity=0.3)
	end_clip(f)
	f.path(f"M{i - sgn * 0.8} {iy + 0.6}Q{cx - sgn * w * 0.05} {ctop - 1.4} {o + sgn * flick} {oy - flick * 0.45}Q{cx + sgn * w * 0.02} {ctop + lid * 1.9} {i - sgn * 0.8} {iy + 0.6}Z", lash)
	f.taper(cx - sgn * w * 0.05, cy + h * 0.52, cx + sgn * w * 0.24, cy + h * 0.6, o + sgn * 0.3, oy + 0.8, 0.8, shade(f.skin, 0.4))


def brow(f, cx, cy, sgn, colour, w=24, angry=1.5, thick=1.6, arch=1.5):
	"""A definite brow with a blunt inner end. angry drops the inner end; arch lifts the middle."""
	ix, ox = cx - sgn * w / 2, cx + sgn * w / 2
	iy, oy = cy + angry, cy - angry * 0.15
	f.path(f"M{ix} {iy - thick / 2}Q{cx} {cy - arch - thick / 2} {ox} {oy}Q{cx} {cy - arch + thick * 0.6} {ix} {iy + thick / 2}Z", colour)


def face(f, skin, hairline=30, nose_y=93, shadow=None):
	"""Flat skin, one soft shadow under the hair, a clear small nose mark. Each character draws its own eyes and mouth."""
	f.skin = skin
	f.fill(skin)
	dark = shadow or shade(skin, 0.74)
	f.soft(f"M-5-5H135V{hairline + 5}Q65 {hairline - 3} -5 {hairline + 5}Z", dark, 0.75, 3)
	f.soft("M25 134Q65 124 105 134V140H25Z", dark, 0.5, 2)
	f.soft(f"M66 {nose_y - 13}L70 {nose_y}L65 {nose_y + 1}Z", dark, 0.55, 1)
	f.taper(60.5, nose_y + 0.5, 65, nose_y + 3.4, 69.5, nose_y - 0.6, 1.1, shade(skin, 0.42))
	return f


def plain(f, colour, shadow=None):
	"""A bare block: flat colour and one very soft shadow, no lines."""
	f.fill(colour)
	f.soft(f"M{f.w * 0.82}-5H{f.w + 5}V{f.h + 5}H{f.w * 0.86}Z", shadow or shade(colour, 0.82), 0.5, 5)
	return f


def head_side(f, skin, hair, back_right, front=52, top=30, nape=112):
	"""A head side: bare cheek at the front, hair behind and above, a small plain ear, hardly any shadow."""
	w = f.w
	fx = (lambda x: x) if back_right else (lambda x: w - x)
	f.fill(skin)
	f.path(f"M{fx(front)} -5H{fx(w + 5)}V{nape}Q{fx(front + 34)} {nape - 12} {fx(front + 12)} {top + 30}Q{fx(front - 2)} {top + 12} {fx(-5)} {top}V-5H{fx(front)}Z", hair)
	f.path(f"M{fx(front + 2)} 62q{'7' if back_right else '-7'} -5 {'9' if back_right else '-9'} 6q-1 12 {'-7' if back_right else '7'} 15q-3 -10 {'-2' if back_right else '2'} -21Z", skin, stroke=shade(skin, 0.55), sw=1.0)


def sandal(k, part, x, sole="sole", strap="strap"):
	k.tube(part, "Sole", [(x, -0.05, 0.09, 0.535, 0.6), (x, -0.05, 0.0, 0.52, 0.59)], sole, corner=0.3)
	k.tube(part, "ToeStrap", [(x, -0.3, 0.25, 0.525, 0.24), (x, -0.32, 0.09, 0.53, 0.26)], strap, corner=0.25)


def knot(k, part, at, size, skin, tails=((-0.14, 0.62, -0.1), (0.14, 0.5, 0.12)), v=0.62):
	"""A sash knot: a squashed lump and tails hanging from it, tails = (start x offset, length, end x offset)."""
	x, y, z = at
	for i, (dx, ln, ex) in enumerate(tails):
		w = size * 0.42
		rows = [(x + dx + ex * s * s, y - 0.02 - 0.03 * s, z - size * 0.2 - ln * s, w * (0.72 + 0.42 * s), 0.035) for s in (0, 0.4, 0.75, 1)]
		k.tube(part, f"KnotTail{i}", rows, skin, corner=0.5, nc=1, v=(0.2, 0.8), ink=(False, True))
	k.blob(part, "Knot", (x, y - 0.03, z), (size * 0.62, size * 0.42, size * 0.5), skin, v=v)
