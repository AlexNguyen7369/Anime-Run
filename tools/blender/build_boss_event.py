# Boss-event models (boss_raga, side_chain, side_knight, side_wyvern, side_raga), their review renders and contact sheet, headless:
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- build [<id> ...]
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- sheet
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- export <id> ...
# export reads assets/characters_avatar/<id>/<id>.blend and writes build/avatar_glb/<id>.glb for upload_avatar.py.
# avatar_merge.py keeps only meshes under an R15 name and avatar_paint.py always makes 6 body blocks, so these models do
# not use them: each is a set of named parts with their origin at the joint, faceted solids on one ramp texture
# (assets/characters_avatar/<id>/atlas.png). Front faces -Y; +X is the viewer's right in the front view.
import json
import math
import os
import random
import subprocess
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_avatar  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "characters_avatar")
TMP = os.path.join(ROOT, "build", "boss_event")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TRI_BUDGET = 20000  # per mesh, owner's cap for this event
LIGHT = Vector((-0.35, -0.6, 0.72)).normalized()
SIDEKICK_RATIO = 0.35
RAGA_HEAD_STUDS, RUNNER_STUDS, LEGEND_STUDS = 560.0, 5.75, 10.9
NAMES = {"boss_raga": "Big Raga", "side_chain": "Pochito", "side_knight": "Igriz", "side_wyvern": "Kaizel", "side_raga": "Big Raga"}
VIEW_ORDER = ("front", "three_quarter", "side", "back")
LINEUP_H = 680
HERO_SHOULDER = 4.0  # top of the R15 torso and arms, avatar_base.BOXES


def v3(p):
	return Vector(p) if not isinstance(p, Vector) else p


def lerp(a, b, t):
	return a + (b - a) * t


class Model:
	def __init__(self, cid, ramps, parts, pose=None, a=0.5, b=0.42, atlas_h=256, neon=()):
		"""parts = name -> (joint position, parent name or None). pose = name -> display rotation in degrees. a, b = default paint level and facet contrast. neon = parts drawn emissive."""
		self.cid, self.ramps, self.parts, self.pose, self.a, self.b, self.atlas_h, self.neon = cid, ramps, parts, pose or {}, a, b, atlas_h, neon
		self.names = list(ramps)
		self.bm = {n: bmesh.new() for n in parts}
		self.uv = {n: b.loops.layers.uv.new("UVMap") for n, b in self.bm.items()}
		self.count = 0

	def add(self, part, ramp, verts, faces, a=None, b=None, g=0.08, tone=0.03, jit=0.0, extra=None, smooth=False, keep=False):
		"""One solid. One light value per triangle from its normal, a soft height gradient inside: hard facets, soft paint.
		smooth: the light value follows vertex normals instead, on smooth-shaded faces. keep: trust the winding, for open surfaces."""
		self.count += 1
		a, b = self.a if a is None else a, self.b if b is None else b
		rng = random.Random(f"{self.cid}{self.count}")
		tmp = bmesh.new()
		vs = [tmp.verts.new(p) for p in verts]
		for f in faces:
			tmp.faces.new([vs[i] for i in f])
		if not keep:
			bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces[:])
		bmesh.ops.triangulate(tmp, faces=tmp.faces[:])
		for v in tmp.verts:
			if jit:
				v.co += Vector((rng.uniform(-jit, jit), rng.uniform(-jit, jit), rng.uniform(-jit, jit) * 0.7))
		tmp.normal_update()
		lo, hi = min(v.co.z for v in tmp.verts), max(v.co.z for v in tmp.verts)
		out, uv = self.bm[part], self.uv[part]
		u = (self.names.index(ramp) + 0.5) / len(self.names)
		vmap = {v: out.verts.new(v.co) for v in tmp.verts}
		for f in tmp.faces:
			base = a + b * f.normal.dot(LIGHT) + rng.uniform(-tone, tone)
			nf = out.faces.new([vmap[v] for v in f.verts])
			nf.smooth = smooth
			for l, src in zip(nf.loops, f.loops):
				if smooth:
					base = a + b * src.vert.normal.dot(LIGHT)
				val = base + g * ((src.vert.co.z - lo) / max(hi - lo, 1e-6) - 0.5)
				if extra:
					val += extra(src.vert.co)
				l[uv].uv = (u, 0.02 + 0.96 * max(0.0, min(1.0, val)))
		tmp.free()

	def _loft(self, rings):
		n = len(rings[0])
		verts = [p for r in rings for p in r]
		faces = [(i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k) for i in range(len(rings) - 1) for k in range(n)]
		faces += [list(range(n)), [(len(rings) - 1) * n + k for k in range(n)]]
		return verts, faces

	def block(self, part, ramp, x, y, z1, z0, hw, hd, ch=0.05, flare=0.0, mids=(), **kw):
		"""A chunky chamfered box from z1 down to z0. flare widens the bottom; mids add rows, more big planes under jit."""
		rows = [(z1, hw - ch, hd - ch), (z1 - ch, hw, hd)]
		rows += [(m, hw + flare * (z1 - m) / (z1 - z0), hd + flare * (z1 - m) / (z1 - z0)) for m in mids]
		rows += [(z0 + ch, hw + flare, hd + flare), (z0, hw + flare - ch, hd + flare - ch)]
		rings = []
		for z, w, d in rows:
			c = 0.2 * min(w, d)
			rings.append([(x + qx * w + ax * c, y + qy * d + ay * c, z) for qx, qy, cs in ((1, 1, ((-1, 0), (0, -1))), (-1, 1, ((0, -1), (1, 0))), (-1, -1, ((1, 0), (0, 1))), (1, -1, ((0, 1), (-1, 0)))) for ax, ay in cs])
		self.add(part, ramp, *self._loft(rings), **kw)

	def path(self, part, ramp, pts, hw, hd=None, n=8, **kw):
		"""A loft along a polyline. hw is across (lateral), hd the other way; scalars or one per point. n = 4 or 8: boxy; other n: round."""
		pts = [v3(p) for p in pts]
		count = len(pts)
		hws = hw if isinstance(hw, (list, tuple)) else [hw] * count
		hd = hw if hd is None else hd
		hds = hd if isinstance(hd, (list, tuple)) else [hd] * count
		if n == 8:
			sec = ((1, 0.6), (0.6, 1), (-0.6, 1), (-1, 0.6), (-1, -0.6), (-0.6, -1), (0.6, -1), (1, -0.6))
		elif n == 4:
			sec = ((1, 1), (-1, 1), (-1, -1), (1, -1))
		else:
			sec = tuple((math.cos(2 * math.pi * j / n), math.sin(2 * math.pi * j / n)) for j in range(n))
		rings, side = [], None
		for i in range(count):
			t = (pts[min(i + 1, count - 1)] - pts[max(i - 1, 0)]).normalized()
			if side is None:
				side = t.cross(Vector((0, 0, 1)))
				side = Vector((1, 0, 0)) if side.length < 0.08 else side.normalized()
			side = (side - t * side.dot(t)).normalized()
			up = t.cross(side)
			rings.append([tuple(pts[i] + side * a * hws[i] + up * c * hds[i]) for a, c in sec])
		self.add(part, ramp, *self._loft(rings), **kw)

	def spike(self, part, ramp, root, tip, r, flat=1.0, n=6, **kw):
		root, tip = v3(root), v3(tip)
		self.path(part, ramp, [root, root.lerp(tip, 0.5), root.lerp(tip, 0.85), tip], [r, r * 0.72, r * 0.3, 0.004], [r * flat, r * 0.72 * flat, r * 0.3 * flat, 0.004], n=n, **kw)

	def plate(self, part, ramp, pts, off, **kw):
		"""A flat solid: polygon pts extruded by off, centred on the polygon."""
		off = v3(off)
		pts = [v3(p) for p in pts]
		self.add(part, ramp, *self._loft([[tuple(p - off / 2) for p in pts], [tuple(p + off / 2) for p in pts]]), **kw)

	def sheet(self, part, ramp, grid, off, **kw):
		"""A thin closed cloth or membrane from rows of points, the same count in each row."""
		off = v3(off)
		h, w = len(grid), len(grid[0])
		verts = [tuple(v3(p) - off / 2) for r in grid for p in r] + [tuple(v3(p) + off / 2) for r in grid for p in r]
		idx = lambda r, c, layer: layer * h * w + r * w + c
		faces = []
		for r in range(h - 1):
			for c in range(w - 1):
				faces.append((idx(r, c, 0), idx(r, c + 1, 0), idx(r + 1, c + 1, 0), idx(r + 1, c, 0)))
				faces.append((idx(r, c, 1), idx(r + 1, c, 1), idx(r + 1, c + 1, 1), idx(r, c + 1, 1)))
		for r in range(h - 1):
			for c in (0, w - 1):
				faces.append((idx(r, c, 0), idx(r + 1, c, 0), idx(r + 1, c, 1), idx(r, c, 1)))
		for c in range(w - 1):
			for r in (0, h - 1):
				faces.append((idx(r, c, 0), idx(r, c + 1, 0), idx(r, c + 1, 1), idx(r, c, 1)))
		self.add(part, ramp, verts, faces, **kw)

	def ell(self, part, ramp, c, r, rows=5, n=10, **kw):
		"""A faceted ellipsoid."""
		rings = []
		for i in range(1, rows):
			a = math.pi * i / rows
			rings.append([(c[0] + r[0] * math.sin(a) * math.cos(2 * math.pi * k / n), c[1] + r[1] * math.sin(a) * math.sin(2 * math.pi * k / n), c[2] + r[2] * math.cos(a)) for k in range(n)])
		verts, faces = self._loft(rings)
		base = len(verts)
		verts += [(c[0], c[1], c[2] + r[2]), (c[0], c[1], c[2] - r[2])]
		faces = faces[:-2]
		for k in range(n):
			k1 = (k + 1) % n
			faces.append((base, k, k1))
			faces.append((base + 1, (rows - 2) * n + k1, (rows - 2) * n + k))
		self.add(part, ramp, verts, faces, **kw)

	def ring(self, part, ramp, c, normal, radius, r, n=16, **kw):
		"""A closed ring (square section) round normal."""
		c, normal = v3(c), v3(normal).normalized()
		e1 = normal.cross(Vector((0, 0, 1)))
		e1 = Vector((1, 0, 0)) if e1.length < 0.05 else e1.normalized()
		e2 = normal.cross(e1)
		rings = []
		for i in range(n):
			a = 2 * math.pi * i / n
			out = e1 * math.cos(a) + e2 * math.sin(a)
			rings.append([tuple(c + out * (radius + qa * r) + normal * qb * r) for qa, qb in ((1, 1), (-1, 1), (-1, -1), (1, -1))])
		verts = [p for ring in rings for p in ring]
		faces = [(i * 4 + k, i * 4 + (k + 1) % 4, ((i + 1) % n) * 4 + (k + 1) % 4, ((i + 1) % n) * 4 + k) for i in range(n) for k in range(4)]
		self.add(part, ramp, verts, faces, **kw)

	def disc(self, part, ramp, c, normal, r, th=0.03, n=10, squash=1.0, **kw):
		c, normal = v3(c), v3(normal).normalized()
		e1 = normal.cross(Vector((0, 0, 1)))
		e1 = Vector((1, 0, 0)) if e1.length < 0.05 else e1.normalized()
		e2 = normal.cross(e1)
		pts = [c + e1 * r * math.cos(2 * math.pi * k / n) + e2 * r * squash * math.sin(2 * math.pi * k / n) for k in range(n)]
		self.plate(part, ramp, pts, normal * th, a=kw.pop("a", 0.6), b=kw.pop("b", 0.2), **kw)

	def atlas(self):
		"""The ramp strip: one soft vertical gradient per ramp name, dark at v 0, light at v 1. Saved next to the blend."""
		os.makedirs(os.path.join(OUT, self.cid), exist_ok=True)
		w, h = 64 * len(self.names), self.atlas_h
		px = np.ones((h, w, 4), dtype=np.float32)
		for i, name in enumerate(self.names):
			stops = np.array([[int(c.lstrip("#")[j : j + 2], 16) / 255 for j in (0, 2, 4)] for c in self.ramps[name]])
			t = (np.arange(h) + 0.5) / h * (len(stops) - 1)
			k = np.minimum(t.astype(int), len(stops) - 2)
			col = stops[k] + (stops[k + 1] - stops[k]) * (t - k)[:, None]
			px[:, i * 64 : (i + 1) * 64, :3] = col[:, None, :]
		path = os.path.join(OUT, self.cid, "atlas.png")
		img = bpy.data.images.new(f"Atlas_{self.cid}", w, h, alpha=False)
		img.pixels.foreach_set(px.ravel())
		img.filepath_raw = path
		img.file_format = "PNG"
		img.save()
		img.pack()
		return img

	def finish(self):
		"""Makes the part objects under an empty named by the id, each with its origin at its joint."""
		mat = bpy.data.materials.new(f"M_{self.cid}")
		mat.use_nodes = True
		bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Roughness"].default_value = 0.85
		bsdf.inputs["Specular IOR Level"].default_value = 0.0
		tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
		tex.image = self.atlas()
		mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
		glow = None
		if self.neon:
			glow = bpy.data.materials.new(f"M_{self.cid}_Neon")
			glow.use_nodes = True
			nb = next(n for n in glow.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
			nt = glow.node_tree.nodes.new("ShaderNodeTexImage")
			nt.image = tex.image
			glow.node_tree.links.new(nt.outputs["Color"], nb.inputs["Emission Color"])
			nb.inputs["Base Color"].default_value = (0, 0, 0, 1)
			nb.inputs["Emission Strength"].default_value = 1.25
		root = bpy.data.objects.new(self.cid, None)
		bpy.context.scene.collection.objects.link(root)
		objs, tris = {}, {}
		for name, (pivot, _) in self.parts.items():
			b = self.bm[name]
			assert b.faces, f"{self.cid}.{name} has no geometry"
			for v in b.verts:
				v.co -= v3(pivot)
			mesh = bpy.data.meshes.new(name)
			b.to_mesh(mesh)
			b.free()
			mesh.materials.append(glow if name in self.neon else mat)
			mesh.update()
			tris[name] = len(mesh.polygons)
			assert tris[name] <= TRI_BUDGET, f"{self.cid}.{name}: {tris[name]} tris"
			o = bpy.data.objects.new(name, mesh)
			bpy.context.scene.collection.objects.link(o)
			objs[name] = o
		for name, (pivot, parent) in self.parts.items():
			o = objs[name]
			o.parent = objs[parent] if parent else root
			o.location = v3(pivot) - (v3(self.parts[parent][0]) if parent else Vector())
			o.rotation_euler = [math.radians(d) for d in self.pose.get(name, (0, 0, 0))]
		return root, tris


# ---- boss_raga


RAGA_RAMPS = {
	"skin": ["#6f7080", "#a5a6b4", "#d0d1da", "#f2f2f6"],
	"crease": ["#3d3e4b", "#555665", "#6e6f7e", "#878897"],
	"wrap": ["#6e6f78", "#a0a1aa", "#cccdd3", "#f4f4f6"],
	"gold": ["#6b4610", "#b5852a", "#e6bf56", "#fff1ac"],
	"black": ["#08080c", "#14151c", "#262833", "#40434f"],
	"cloth": ["#3c3e46", "#62646d", "#8a8c94", "#b0b2b8"],
	"blade": ["#101018", "#2a2b38", "#4a4c5e", "#9095aa"],
	"tooth": ["#7d9098", "#a9bcc0", "#d2dfdf", "#f4fafa"],
	"mouth": ["#0d0a10", "#1b1820", "#2e2a36", "#403c48"],
	"tip": ["#a8abba", "#d4d6de", "#eff0f4", "#ffffff"],
}


def raga_wing(m, root, tip, side):
	"""A bone from the eye socket and a fan of long flat feathers below it."""
	root, tip = v3(root), v3(tip)
	mid = root.lerp(tip, 0.5) + Vector((0, 0, 0.14))
	m.path("Head", "skin", [root, mid, tip], [0.12, 0.09, 0.01], [0.1, 0.075, 0.01], n=6, a=0.56, b=0.32)
	span = tip - root
	for i in range(5 if m.cid == "side_raga" else 7):
		t = 0.16 + i * (0.175 if m.cid == "side_raga" else 0.125)
		b = root.lerp(tip, t) + Vector((0, 0.01 * i, 0))
		# inner feathers hang down, outer ones trail along the bone
		d = (span.normalized() * (0.25 + 0.9 * t) + Vector((0, 0, -1.0))).normalized() * (0.62 + 0.42 * math.sin(math.pi * min(1, t + 0.1)))
		n = d.cross(Vector((0, 1, 0))).normalized() * 0.1
		pts = [b - d * 0.05, b + d * 0.28 + n, b + d * 0.72 + n * 0.8, b + d, b + d * 0.72 - n * 0.8, b + d * 0.28 - n]
		m.plate("Head", "wrap", pts, (0, 0.05, 0), a=0.42 - 0.04 * (i % 2), b=0.22, g=0.24)


def raga_arm(m, side, s, x):
	up, low, hand = f"{side}UpperArm", f"{side}LowerArm", f"{side}Hand"
	m.block(up, "crease", x, 0, 4.55, 3.42, 0.56, 0.56)
	m.block(up, "skin", x, 0, 4.68, 3.92, 0.67, 0.67, ch=0.1, mids=(4.3,), jit=0.02)  # deltoid
	m.block(up, "skin", x, -0.3, 3.86, 3.42, 0.42, 0.31, ch=0.06, jit=0.012)  # biceps
	m.block(up, "skin", x, 0.3, 3.86, 3.42, 0.42, 0.31, ch=0.06, jit=0.012)  # triceps
	m.block(low, "crease", x, 0, 3.42, 2.28, 0.54, 0.54)
	# the source's bandage wraps: slanted overlapping turns, wider than the arm
	for i, z in enumerate((3.3, 2.98, 2.66) if m.cid == "side_raga" else (3.3, 3.11, 2.92, 2.73, 2.54)):
		tilt = 0.05 * (1 if i % 2 else -1)
		x0, x1 = x - 0.6, x + 0.6
		h = 0.3 if m.cid == "side_raga" else 0.2
		rows = [[(x1, -0.6, z + tilt), (x1, 0.6, z - tilt), (x0, 0.6, z + tilt), (x0, -0.6, z - tilt)], [(x1, -0.6, z - h + tilt), (x1, 0.6, z - h - tilt), (x0, 0.6, z - h + tilt), (x0, -0.6, z - h - tilt)]]
		m.add(low, "wrap", *m._loft(rows), a=0.56 - 0.04 * (i % 2), b=0.34, g=0.2)
	m.block(hand, "skin", x, 0, 2.3, 1.78, 0.58, 0.58, ch=0.07, a=0.58, b=0.3)


def raga_leg(m, side, s):
	up, low, foot = f"{side}UpperLeg", f"{side}LowerLeg", f"{side}Foot"
	x = s * 0.7
	m.block(up, "crease", x, 0, 2.4, 1.25, 0.6, 0.62)
	m.block(up, "skin", x - s * 0.27, -0.36, 2.3, 1.42, 0.3, 0.3, ch=0.07, jit=0.015)
	m.block(up, "skin", x + s * 0.27, -0.36, 2.3, 1.42, 0.3, 0.3, ch=0.07, jit=0.015)
	m.block(up, "skin", x, 0.32, 2.34, 1.36, 0.6, 0.32, ch=0.07, jit=0.015)
	m.block(up, "skin", x, -0.4, 1.44, 1.2, 0.42, 0.24, ch=0.07, a=0.56)  # kneecap
	m.block(low, "crease", x, 0, 1.25, 0.34, 0.57, 0.58)
	m.block(low, "skin", x, -0.36, 1.2, 0.48, 0.46, 0.24, ch=0.06, jit=0.012)
	m.block(low, "skin", x, 0.28, 1.22, 0.52, 0.56, 0.34, ch=0.08, jit=0.015)
	m.ring(low, "black", (x, 0, 0.44), (0, 0, 1), 0.78, 0.05, n=8, a=0.46, b=0.3)
	m.block(foot, "skin", x, -0.12, 0.36, 0, 0.62, 0.78, ch=0.06, a=0.56, b=0.34)
	for i in (-1, 0, 1):
		m.block(foot, "skin", x + i * 0.4, -0.96, 0.24, 0, 0.18, 0.22, ch=0.05, a=0.58, b=0.32)
		if m.cid != "side_raga":
			m.spike(foot, "black", (x + i * 0.4, -1.12, 0.1), (x + i * 0.4, -1.32, 0.03), 0.07, flat=0.7)


def raga_head(m):
	h = "Head"
	m.block(h, "skin", 0, 0, 6.42, 4.82, 0.82, 0.76, ch=0.12, mids=(5.9, 5.3), jit=0.02)
	m.block(h, "skin", 0, -0.04, 5.0, 4.66, 0.62, 0.62, ch=0.08, a=0.46)  # chin
	# forehead furrows running down to the nose
	for s in (1, -1):
		m.plate(h, "crease", [(s * 0.08, -0.77, 6.32), (s * 0.15, -0.77, 6.32), (s * 0.2, -0.77, 5.72), (s * 0.13, -0.77, 5.72)], (0, 0.02, 0), a=0.4, b=0.1)
		m.block(h, "skin", s * 0.5, -0.74, 5.42, 5.02, 0.26, 0.09, ch=0.04, jit=0.012)  # cheek
	m.block(h, "skin", 0, -0.8, 5.88, 5.56, 0.13, 0.1, ch=0.04)  # nose
	m.block(h, "skin", 0, -0.78, 6.08, 5.92, 0.72, 0.07, ch=0.03)  # heavy brow
	# the wide mouth of square teeth with heavy lips
	m.block(h, "mouth", 0, -0.75, 5.44, 4.98, 0.52, 0.04, ch=0.01, a=0.45, b=0.05)
	m.block(h, "skin", 0, -0.82, 5.52, 5.42, 0.58, 0.075, ch=0.03, a=0.54)
	m.block(h, "skin", 0, -0.82, 5.0, 4.9, 0.54, 0.075, ch=0.03, a=0.48)
	small = m.cid == "side_raga"  # the same square teeth, fewer and wider: at Sidekick size 7 per row fall under 2 px each
	for i in (-1.5, -0.5, 0.5, 1.5) if small else range(-3, 4):
		step, hw = (0.255, 0.115) if small else (0.145, 0.068)
		m.block(h, "tooth", i * step, -0.8, 5.42, 5.23, hw, 0.035, ch=0.012, a=0.62, b=0.25)
		m.block(h, "tooth", i * step, -0.8, 5.2, 5.01, hw, 0.035, ch=0.012, a=0.55, b=0.25)
	for s, tag in ((1, "L"), (-1, "R")):
		# no eyes: a wing grows out of each socket, one pair up, one pair out
		raga_wing(m, (s * 0.5, -0.82, 5.82), (s * 2.25, -0.95, 7.05), s)
		raga_wing(m, (s * 0.56, -0.8, 5.66), (s * 2.7, -0.95, 5.5), s)


def raga_wheel(m):
	"""The eight-handled wheel, in the XZ plane round its hub: spin it about its local Y."""
	w, hub = "Wheel", Vector((0, 0.1, 7.85))
	small = m.cid == "side_raga"  # thicker bars: the wheel is the silhouette's mark and must survive at Sidekick size
	m.ring(w, "gold", hub, (0, 1, 0), 1.02, 0.12 if small else 0.075, n=16 if small else 24, a=0.55, b=0.4)
	m.ring(w, "gold", hub, (0, 1, 0), 0.5, 0.085 if small else 0.05, n=12 if small else 16, a=0.55, b=0.4)
	for i in range(8):
		a = math.pi * i / 4 + math.pi / 8
		d = Vector((math.cos(a), 0, math.sin(a)))
		n = Vector((-d.z, 0, d.x)) * (0.09 if small else 0.055)
		p0, p1 = hub + d * 0.05, hub + d * 1.28
		m.plate(w, "gold", [p0 + n, p1 + n, p1 - n, p0 - n], (0, 0.1, 0), a=0.55, b=0.4)
		m.ell(w, "gold", tuple(p1 + d * 0.06), (0.17, 0.17, 0.17), rows=4, n=8, a=0.56, b=0.5, g=0.0)
	m.ell(w, "gold", tuple(hub), (0.2, 0.2, 0.2), rows=4, n=8, a=0.56, b=0.5, g=0.0)


def raga_tail(m):
	"""Rises behind the back in pale segments split by dark bands, ending in a long white sickle."""
	t = "Tail"
	spine = [Vector(p) for p in ((0, 0.62, 2.72), (0, 1.3, 3.05), (0.05, 1.8, 3.95), (0.3, 2.05, 5.05), (0.9, 2.05, 6.1), (1.75, 1.85, 6.95), (2.6, 1.55, 7.4), (3.45, 1.3, 7.32))]
	rad = [0.56, 0.56, 0.52, 0.5, 0.46, 0.42, 0.38, 0.32]
	for i in range(len(spine) - 1):
		a, b = spine[i], spine[i + 1]
		m.path(t, "skin", [a.lerp(b, 0.02), a.lerp(b, 0.9)], [rad[i], rad[i + 1] * 1.04], n=8, a=0.56, b=0.36, jit=0.012)
		m.path(t, "black", [a.lerp(b, 0.86), a.lerp(b, 1.0)], [rad[i + 1] * 1.1, rad[i + 1] * 1.1], n=8, a=0.4, b=0.3)
	m.path(t, "tip", [spine[-1], (3.98, 1.15, 6.92), (4.3, 1.05, 6.2), (4.38, 1.0, 5.35), (4.24, 0.95, 4.7)], [0.3, 0.26, 0.19, 0.11, 0.005], [0.22, 0.17, 0.11, 0.06, 0.005], n=6, a=0.56, b=0.3)


def raga_torso(m):
	u, l = "UpperTorso", "LowerTorso"
	m.block(l, "crease", 0, 0, 2.95, 2.26, 1.24, 0.66, ch=0.06)
	m.block(l, "cloth", 0, 0, 2.92, 2.5, 1.3, 0.72, ch=0.04, jit=0.02, a=0.46, b=0.5)  # waist wrap
	# the grey cloth, torn at the hem, hanging from the wrap at the back and his left hip
	for x0, x1, y, z1 in ((-1.1, 0.15, 0.76, 0.85), (0.3, 1.32, 0.74, 1.15)):
		cols = 6
		grid = [[(lerp(x0, x1, c / cols), y, 2.75) for c in range(cols + 1)], [(lerp(x0, x1, c / cols), y + 0.1, 1.85) for c in range(cols + 1)], [(lerp(x0, x1, c / cols) * 1.04, y + 0.16, z1 + (0.26 if c % 2 else -0.08)) for c in range(cols + 1)]]
		m.sheet(l, "cloth", grid, (0, 0.05, 0), a=0.48, b=0.3, g=0.18, jit=0.012)
	m.block(u, "crease", 0, 0, 4.86, 2.95, 1.36, 0.72, ch=0.08)
	# traps and neck
	m.block(u, "skin", 0, 0.02, 5.02, 4.7, 0.66, 0.56, ch=0.08, jit=0.012)
	for s in (1, -1):
		m.plate(u, "skin", [(s * 0.05, -0.76, 4.78), (s * 1.3, -0.76, 4.8), (s * 1.26, -0.76, 4.22), (s * 0.72, -0.76, 3.98), (s * 0.05, -0.76, 4.02)], (0, 0.2, 0), g=0.2)  # pectoral
		for i, z in enumerate((3.92, 3.5, 3.1)):
			m.block(u, "skin", s * 0.31, -0.66, z, z - 0.36, 0.25, 0.13, ch=0.05, jit=0.012)  # abdominals
		m.plate(u, "skin", [(s * 0.62, -0.72, 3.9), (s * 1.26, -0.72, 4.14), (s * 1.3, -0.72, 3.0), (s * 0.62, -0.72, 3.04)], (0, 0.2, 0), g=0.2)  # flank
		m.block(u, "skin", s * 0.72, 0.68, 4.76, 3.8, 0.58, 0.12, ch=0.05, jit=0.02)  # upper back
		m.block(u, "skin", s * 0.66, 0.66, 3.72, 3.0, 0.52, 0.12, ch=0.05, jit=0.02)  # lat
		m.block(u, "skin", s * 1.32, 0, 4.7, 3.1, 0.1, 0.6, ch=0.03, jit=0.012)
	# the black rope round the shoulders and its hanging tags
	small = m.cid == "side_raga"
	m.ring(u, "black", (0, 0.08, 4.62), (0, 0.18, 1), 1.02, 0.1 if small else 0.065, n=10 if small else 16, a=0.44, b=0.34)
	for x, y, z in ((0.0, 1.1, 4.26), (0.68, 0.86, 4.5), (-0.68, 0.86, 4.5), (1.02, 0.1, 4.9)):
		m.plate(u, "black", [(x - 0.09, y, z + 0.14), (x + 0.09, y, z + 0.14), (x + 0.2, y, z - 0.42), (x, y, z - 0.3), (x - 0.2, y, z - 0.42)], (0, 0.05, 0), a=0.46, b=0.25)


def boss_raga(cid="boss_raga"):
	parts = {
		"LowerTorso": ((0, 0, 2.6), None),
		"UpperTorso": ((0, 0, 2.95), "LowerTorso"),
		"Head": ((0, 0, 4.85), "UpperTorso"),
		"Wheel": ((0, 0.1, 7.85), "Head"),
		"Tail": ((0, 0.62, 2.72), "LowerTorso"),
		"LeftUpperArm": ((2.1, 0, 4.5), "UpperTorso"),
		"LeftLowerArm": ((2.1, 0, 3.42), "LeftUpperArm"),
		"LeftHand": ((2.1, 0, 2.3), "LeftLowerArm"),
		"RightUpperArm": ((-2.1, 0, 4.5), "UpperTorso"),
		"RightLowerArm": ((-2.1, 0, 3.42), "RightUpperArm"),
		"RightHand": ((-2.1, 0, 2.3), "RightLowerArm"),
		"Sword": ((-2.1, 0, 1.78), "RightHand"),
		"LeftUpperLeg": ((0.7, 0, 2.4), "LowerTorso"),
		"LeftLowerLeg": ((0.7, 0, 1.25), "LeftUpperLeg"),
		"LeftFoot": ((0.7, 0, 0.36), "LeftLowerLeg"),
		"RightUpperLeg": ((-0.7, 0, 2.4), "LowerTorso"),
		"RightLowerLeg": ((-0.7, 0, 1.25), "RightUpperLeg"),
		"RightFoot": ((-0.7, 0, 0.36), "RightLowerLeg"),
	}
	# an A-pose so the sword clears the body and the floor; the wheel leans back so its face reads from below
	pose = {"LeftUpperArm": (0, -12, 0), "RightUpperArm": (0, 26, 0), "Wheel": (-10, 0, 0)}
	m = Model(cid, RAGA_RAMPS, parts, pose, a=0.56, b=0.3)
	raga_torso(m)
	raga_head(m)
	raga_wheel(m)
	raga_tail(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		raga_arm(m, side, s, s * 2.1)
		raga_leg(m, side, s)
	# the bandage climbs the sword arm; the iron ring sits at its wrist
	for i, z in enumerate((3.84, 3.65, 3.46)):
		m.block("RightUpperArm", "wrap", -2.1, 0, z, z - 0.22, 0.62, 0.62, ch=0.03, a=0.56 - 0.04 * (i % 2), b=0.34, jit=0.012)
	m.ring("RightLowerArm", "black", (-2.1, 0, 2.42), (0, 0, 1), 0.8, 0.05, n=8, a=0.46, b=0.3)
	s = "Sword"
	m.block(s, "black", -2.1, 0, 1.82, 1.66, 0.3, 0.14, ch=0.03, a=0.45)
	m.path(s, "blade", [(-2.1, 0, 1.7), (-2.1, 0, 0.9), (-2.1, 0, 0.1), (-2.1, 0, -0.42)], [0.15, 0.15, 0.11, 0.005], [0.045, 0.045, 0.03, 0.005], n=6, a=0.5, b=0.5)
	return m


# ---- side_chain


CHAIN_RAMPS = {
	"body": ["#a8381c", "#d4542a", "#ee7038", "#fb9460"],
	"dark": ["#17110e", "#2e2420", "#4a3c34", "#6b5a4e"],
	"steel": ["#9a9e9e", "#bfc2c0", "#dcdddb", "#f6f6f2"],
	"gleam": ["#e6e7e4", "#f0f1ee", "#f8f8f6", "#ffffff"],
	"cream": ["#dcc5a6", "#eedcc2", "#f9efdc", "#fffbf2"],
	"mouth": ["#2c0a0e", "#4e1216", "#6f1e20", "#8e2e2c"],
	"tongue": ["#c43a30", "#e65e4a", "#f58268", "#ffa88e"],
	"iris": ["#0e0a08", "#1e1612", "#33261e", "#4c382a"],
}
CHAIN_C = Vector((0, 0, 1.3))
CHAIN_R = (1.02, 1.5, 1.0)
# direction, height, width: the snout, the rump drawn out to the tail, the four hips
CHAIN_BUMPS = (
	((0, -0.98, 0.12), 0.2, 0.34),
	((0, 0.98, 0.14), 0.14, 0.26),
	((0.5, -0.5, -0.7), 0.1, 0.42),
	((-0.5, -0.5, -0.7), 0.1, 0.42),
	((0.5, 0.6, -0.65), 0.1, 0.42),
	((-0.5, 0.6, -0.65), 0.1, 0.42),
)


def chain_surface(d):
	"""Radial distance of the body surface along unit direction d: an egg, fuller at the head, with soft bumps."""
	ry = lerp(CHAIN_R[1] + 0.12, CHAIN_R[1] - 0.14, (d.y + 1) / 2)
	t = 1 / math.sqrt((d.x / CHAIN_R[0]) ** 2 + (d.y / ry) ** 2 + (d.z / CHAIN_R[2]) ** 2)
	for c, height, width in CHAIN_BUMPS:
		angle = d.angle(Vector(c).normalized())
		t += height * math.exp(-((angle / width) ** 2))
	return t


def chain_decal(m, ramp, d, r, lift, value=0.6, squash=1.0, n=32):
	"""A round marking that follows the body's curve, on the surface in direction d."""
	d = Vector(d).normalized()
	e1 = Vector((0, 0, 1)).cross(d).normalized()
	e2 = d.cross(e1)
	p0 = CHAIN_C + d * chain_surface(d)

	def on_body(a, f):
		p = p0 + e1 * r * f * math.cos(a) + e2 * r * f * squash * math.sin(a)
		q = (p - CHAIN_C).normalized()
		return tuple(CHAIN_C + q * (chain_surface(q) + lift))

	verts = [tuple(CHAIN_C + d * (chain_surface(d) + lift))]
	rings = (0.5, 1.0)
	for f in rings:
		verts += [on_body(2 * math.pi * k / n, f) for k in range(n)]
	faces = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
	faces += [(1 + k, 1 + n + k, 1 + n + (k + 1) % n, 1 + (k + 1) % n) for k in range(n)]
	m.add("Body", ramp, verts, faces, a=value, b=0.0, g=0.0, tone=0.0, smooth=True, keep=True)


def chain_body(m):
	"""The egg, with the mouth cut out as a true hollow so its edge stays clean at any mesh density."""
	rows, n = 40, 56
	verts = [tuple(CHAIN_C + Vector((0, 0, chain_surface(Vector((0, 0, 1))))))]
	for i in range(1, rows):
		a = math.pi * i / rows
		for k in range(n):
			d = Vector((math.sin(a) * math.cos(2 * math.pi * k / n), math.sin(a) * math.sin(2 * math.pi * k / n), math.cos(a)))
			verts.append(tuple(CHAIN_C + d * chain_surface(d)))
	verts.append(tuple(CHAIN_C - Vector((0, 0, chain_surface(Vector((0, 0, -1)))))))
	last = len(verts) - 1
	faces = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
	for i in range(rows - 2):
		faces += [(1 + i * n + k, 1 + (i + 1) * n + k, 1 + (i + 1) * n + (k + 1) % n, 1 + i * n + (k + 1) % n) for k in range(n)]
	faces += [(last, 1 + (rows - 2) * n + (k + 1) % n, 1 + (rows - 2) * n + k) for k in range(n)]
	centre, radii = Vector((0, -1.62, 0.94)), (0.64, 0.5, 0.46)
	cut_v, cut_f = [], []
	cr, cn = 28, 56
	cut_v.append((centre.x, centre.y, centre.z + radii[2]))
	for i in range(1, cr):
		a = math.pi * i / cr
		for k in range(cn):
			cut_v.append((centre.x + radii[0] * math.sin(a) * math.cos(2 * math.pi * k / cn), centre.y + radii[1] * math.sin(a) * math.sin(2 * math.pi * k / cn), centre.z + radii[2] * math.cos(a)))
	cut_v.append((centre.x, centre.y, centre.z - radii[2]))
	clast = len(cut_v) - 1
	cut_f += [(0, 1 + k, 1 + (k + 1) % cn) for k in range(cn)]
	for i in range(cr - 2):
		cut_f += [(1 + i * cn + k, 1 + (i + 1) * cn + k, 1 + (i + 1) * cn + (k + 1) % cn, 1 + i * cn + (k + 1) % cn) for k in range(cn)]
	cut_f += [(clast, 1 + (cr - 2) * cn + (k + 1) % cn, 1 + (cr - 2) * cn + k) for k in range(cn)]
	objs = []
	for name, vs, fs in (("ChainBodyTmp", verts, faces), ("ChainCutTmp", cut_v, cut_f)):
		me = bpy.data.meshes.new(name)
		me.from_pydata(vs, [], fs)
		me.update()
		o = bpy.data.objects.new(name, me)
		bpy.context.scene.collection.objects.link(o)
		objs.append(o)
	mod = objs[0].modifiers.new("Mouth", "BOOLEAN")
	mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", objs[1]
	bpy.context.view_layer.update()
	cut = bpy.data.meshes.new_from_object(objs[0].evaluated_get(bpy.context.evaluated_depsgraph_get()))
	for o in objs:
		me = o.data
		bpy.data.objects.remove(o)
		bpy.data.meshes.remove(me)
	co = [Vector(v.co) for v in cut.vertices]
	on_cut = [abs(((p.x - centre.x) / radii[0]) ** 2 + ((p.y - centre.y) / radii[1]) ** 2 + ((p.z - centre.z) / radii[2]) ** 2 - 1) < 0.02 for p in co]
	polys = [list(p.vertices) for p in cut.polygons]
	bpy.data.meshes.remove(cut)
	groups = {"body": [p for p in polys if not all(on_cut[i] for i in p)], "mouth": [p for p in polys if all(on_cut[i] for i in p)]}
	assert groups["mouth"], "the mouth cut left no hollow"
	for ramp, group in groups.items():
		used = sorted({i for p in group for i in p})
		index = {i: j for j, i in enumerate(used)}
		kw = dict(a=0.55, b=0.26, g=0.2) if ramp == "body" else dict(a=0.45, b=0.2, g=0.3)
		m.add("Body", ramp, [tuple(co[i]) for i in used], [[index[i] for i in p] for p in group], tone=0.0, smooth=True, keep=True, **kw)


def side_chain():
	parts = {
		"Body": ((0, 0, 1.3), None),
		"Bar": ((0, -0.95, 1.9), "Body"),
		"Handle": ((0, 0.4, 2.4), "Body"),
		"Tail": ((0, 1.42, 1.4), "Body"),
		"LegFrontL": ((0.56, -0.62, 0.62), "Body"),
		"LegFrontR": ((-0.56, -0.62, 0.62), "Body"),
		"LegBackL": ((0.56, 0.72, 0.62), "Body"),
		"LegBackR": ((-0.56, 0.72, 0.62), "Body"),
	}
	# the bar turned off the body's axis, so its broad face shows from the front as in the source's near-front art
	m = Model("side_chain", CHAIN_RAMPS, parts, {"Bar": (0, 0, 32)}, a=0.55, b=0.26, atlas_h=1024)
	chain_body(m)
	b = "Body"
	m.ell(b, "tongue", (0, -1.46, 0.74), (0.3, 0.3, 0.13), rows=12, n=24, a=0.56, b=0.24, tone=0.0, smooth=True)
	for s in (1, -1):
		m.spike(b, "cream", (s * 0.34, -1.5, 1.32), (s * 0.36, -1.52, 1.0), 0.08, flat=0.8, a=0.72, b=0.2, tone=0.0, n=12, smooth=True)
		d = (s * 0.7, -0.66, 0.4)
		chain_decal(m, "cream", d, 0.34, 0.012, value=0.88)
		chain_decal(m, "iris", d, 0.25, 0.024, value=0.5)
		chain_decal(m, "cream", (s * 0.64, -0.7, 0.52), 0.055, 0.036, value=0.95, n=12)
		chain_decal(m, "cream", (s * 0.96, -0.2, -0.16), 0.06, 0.012, value=0.88, squash=1.7, n=12)
	for name, x, y in (("LegFrontL", 0.56, -0.62), ("LegFrontR", -0.56, -0.62), ("LegBackL", 0.56, 0.72), ("LegBackR", -0.56, 0.72)):
		m.path(name, "body", [(x, y, 1.05), (x, y + 0.02, 0.42), (x, y - 0.02, 0.2), (x, y - 0.06, 0.08)], [0.25, 0.2, 0.17, 0.17], n=14, g=0.2, tone=0.0, smooth=True)
		m.ell(name, "body", (x, y - 0.1, 0.11), (0.2, 0.28, 0.11), rows=7, n=14, g=0.1, tone=0.0, smooth=True)
		for i in (-1, 0, 1):
			m.ell(name, "body", (x + i * 0.11, y - 0.32, 0.075), (0.065, 0.08, 0.075), rows=5, n=8, g=0.0, tone=0.0, smooth=True)
	# the guide bar, flat in its own plane, a dark run of links round the edge and sparse thorns on them
	base = Vector(parts["Bar"][0])
	u = Vector((0, -0.62, 0.78))
	w = Vector((0, 0.78, 0.62))
	half = 0.47
	corners = [base + w * half]
	corners += [base + u * (1.42 + half * math.sin(math.pi * k / 24)) + w * (half * math.cos(math.pi * k / 24)) for k in range(25)]
	corners += [base - w * half]
	m.plate("Bar", "steel", corners, (0.12, 0, 0), a=0.72, b=0.14, g=0.1, tone=0.0)
	for sign in (1, -1):
		for t0, t1, w0, w1 in ((0.5, 1.5, 0.08, 0.2), (0.75, 1.3, -0.16, -0.08)):
			gleam = [base + u * t0 + w * w0, base + u * t1 + w * (w0 + 0.14), base + u * t1 + w * (w1 + 0.14), base + u * t0 + w * w1]
			m.plate("Bar", "gleam", [p + Vector((sign * 0.065, 0, 0)) for p in gleam], (0.004, 0, 0), a=0.7, b=0.0, g=0.0, tone=0.0)
	# links of even length, straight runs split up
	links = [corners[0]]
	coarse = corners[:2] + corners[4:-2:3] + corners[-2:]
	for a, c in zip(coarse, coarse[1:]):
		pieces = max(1, round((c - a).length / 0.17))
		links += [a.lerp(c, (k + 1) / pieces) for k in range(pieces)]
	centre = base + u * 1.0
	for i, (a, c) in enumerate(zip(links, links[1:])):
		over = 0.025 / (c - a).length  # overlapped, so no daylight shows through the curve
		m.path("Bar", "dark", [a.lerp(c, -over), a.lerp(c, 1 + over)], 0.11, 0.075, n=8, a=0.5, b=0.3, g=0.0, tone=0.0)
		if i % 2 == 1:
			mid = a.lerp(c, 0.5)
			m.spike("Bar", "dark", mid, mid + (mid - centre).normalized() * 0.27, 0.07, a=0.6, b=0.26, tone=0.0, n=10, smooth=True)
	# the handle on the back: a dark bar along the top, its rear end plunging into the body
	m.path("Handle", "dark", [(0, -0.34, 2.24), (0, 0.5, 2.56), (0, 0.96, 2.68), (0, 0.9, 2.3), (0, 0.72, 1.96)], 0.12, 0.1, n=20, a=0.5, b=0.34, g=0.0, tone=0.0, smooth=True)
	# the pull cord for a tail: thin, ending in a triangular grip
	cord = [Vector(p) for p in ((0, 1.42, 1.4), (0, 1.66, 1.5), (0, 1.8, 1.92), (0, 1.86, 2.26), (0, 1.98, 2.5))]
	curve = []
	for i in range(len(cord) - 1):
		p0, p1, p2, p3 = cord[max(i - 1, 0)], cord[i], cord[i + 1], cord[min(i + 2, len(cord) - 1)]
		for k in range(6):
			t = k / 6
			curve.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t**3))
	curve.append(cord[-1])
	m.path("Tail", "dark", curve, [lerp(0.09, 0.045, min(1.0, i / 10)) for i in range(len(curve))], n=10, a=0.52, b=0.3, g=0.0, tone=0.0, smooth=True)
	tip = Vector((0, 1.98, 2.5))
	tri = [tip, tip + Vector((0, 0.34, 0.1)), tip + Vector((0, 0.1, 0.5))]
	for i in range(3):
		m.path("Tail", "dark", [tri[i], tri[(i + 1) % 3]], 0.05, n=12, a=0.52, b=0.3, g=0.0, tone=0.0, smooth=True)
		m.ell("Tail", "dark", tuple(tri[i]), (0.05, 0.05, 0.05), rows=6, n=12, a=0.52, b=0.3, g=0.0, tone=0.0, smooth=True)
	return m


# ---- side_knight


KNIGHT_RAMPS = {
	"red": ["#2e0507", "#650c10", "#951a1b", "#c63c34"],
	"dark": ["#0e0709", "#1f0d11", "#3a161b", "#58242a"],
	"plume": ["#7c0e18", "#bc2230", "#e4484a", "#ff9c8e"],
	"cape": ["#3a070b", "#640c12", "#8c141a", "#b02222"],
	"steel": ["#5c6272", "#99a0b2", "#d6dbe6", "#ffffff"],
	"glow": ["#d8ecff", "#ecf6ff", "#fbfdff", "#ffffff"],
}


def knight_helm(m):
	h = "Head"
	m.block(h, "red", 0, 0, 5.28, 4.02, 0.86, 0.8, ch=0.12, mids=(4.7,), jit=0.015)
	# the dark V of the visor and the two white slits
	m.plate(h, "dark", [(0, -0.82, 4.2), (0.8, -0.82, 4.94), (0.8, -0.82, 4.46), (0.3, -0.82, 4.14), (0, -0.82, 4.05), (-0.3, -0.82, 4.14), (-0.8, -0.82, 4.46), (-0.8, -0.82, 4.94)], (0, 0.03, 0), a=0.5, b=0.1, g=0.0)
	for s in (1, -1):
		m.plate(h, "glow", [(s * 0.15, -0.85, 4.46), (s * 0.68, -0.85, 4.84), (s * 0.7, -0.85, 4.74), (s * 0.26, -0.85, 4.38)], (0, 0.02, 0), a=0.95, b=0.0, g=0.0)
		# the pointed brow plate over each slit and the cheek guard below it
		m.plate(h, "red", [(s * 0.1, -0.87, 4.56), (s * 0.84, -0.87, 5.04), (s * 0.84, -0.87, 5.24), (s * 0.12, -0.87, 5.14)], (0, 0.09, 0), a=0.54, b=0.36)
		m.plate(h, "red", [(s * 0.32, -0.87, 4.26), (s * 0.84, -0.87, 4.5), (s * 0.84, -0.87, 3.96), (s * 0.48, -0.87, 3.84)], (0, 0.09, 0), a=0.5, b=0.36)
		# flaring plates climbing the sides of the helm, like a crown of blades
		for i, (x, z, tx, tz, r) in enumerate(((0.8, 4.5, 1.34, 4.72, 0.15), (0.84, 4.9, 1.42, 5.42, 0.17), (0.72, 5.2, 1.12, 5.92, 0.16))):
			m.spike(h, "red", (s * x, 0.02, z), (s * tx, 0.1, tz), r, flat=0.55, a=0.5, b=0.42)
		m.spike(h, "red", (s * 0.34, -0.2, 5.24), (s * 0.5, -0.1, 5.98), 0.16, flat=0.6, a=0.54, b=0.4)
	# the tall middle crest running from the nose up over the crown
	m.plate(h, "red", [(0, -0.9, 4.1), (0.16, -0.9, 4.42), (0.2, -0.9, 5.2), (0.2, -0.9, 5.66), (0, -0.9, 6.34), (-0.2, -0.9, 5.66), (-0.2, -0.9, 5.2), (-0.16, -0.9, 4.42)], (0, 0.14, 0), a=0.58, b=0.42, g=0.2)
	m.path(h, "dark", [(0, -0.72, 5.2), (0, -0.3, 5.5), (0, 0.2, 5.36)], [0.14, 0.15, 0.12], [0.2, 0.2, 0.14], n=6, a=0.5, b=0.3)


def knight_plume(m):
	"""The long red plume, arcing up from the crown and falling down the back."""
	h = "Head"
	main = [(0, 0.1, 5.3), (0, 0.46, 6.0), (0, 1.0, 6.3), (0, 1.56, 5.9), (0, 1.86, 5.0), (0, 1.98, 3.9), (0, 2.02, 2.8), (0, 1.98, 1.95)]
	m.path(h, "plume", main, [0.26, 0.36, 0.46, 0.5, 0.5, 0.42, 0.26, 0.02], [0.22, 0.3, 0.32, 0.34, 0.3, 0.24, 0.14, 0.02], n=6, a=0.56, b=0.34, g=0.18, jit=0.02)
	for s, dx, end in ((1, 0.28, 2.5), (-1, 0.3, 3.0)):
		m.path(h, "plume", [(0, 0.5, 6.0), (s * 0.3, 1.2, 6.06), (s * 0.44, 1.72, 5.5), (s * dx * 1.6, 1.98, 4.4), (s * dx * 2, 2.04, end)], [0.14, 0.26, 0.28, 0.2, 0.01], [0.14, 0.18, 0.2, 0.12, 0.01], n=6, a=0.5, b=0.34, g=0.18, jit=0.015)


def knight_cape(m):
	"""A long dark red cape from the shoulders, its hem and edges torn into hooked rags."""
	t = "Torso"
	cols = 12
	hem = [0.32, 0.66, 0.2, 0.74, 0.34, 0.86, 0.22, 0.7, 0.3, 0.92, 0.2, 0.62, 0.36]
	side = [0.0, 0.0, 0.0, 0.0]
	grid = []
	for r, (z, half, y) in enumerate(((4.1, 1.3, 0.56), (3.3, 1.72, 0.88), (2.3, 1.9, 1.05))):
		grid.append([(lerp(-half, half, c / cols), y + 0.04 * (c % 2), z - 0.05 * (c % 2)) for c in range(cols + 1)])
	grid.append([(lerp(-2.08, 2.08, c / cols), 1.16 + 0.05 * (c % 2), hem[c]) for c in range(cols + 1)])
	m.sheet(t, "cape", grid, (0, 0.06, 0), a=0.5, b=0.38, g=0.22, jit=0.02)


def knight_torso(m):
	t = "Torso"
	m.block(t, "dark", 0, 0, 4.02, 2.0, 1.04, 0.54, ch=0.06)
	# breastplate: two red slopes round a dark spine of ribs
	for s in (1, -1):
		m.plate(t, "red", [(s * 0.14, -0.58, 3.98), (s * 1.06, -0.58, 3.98), (s * 1.08, -0.58, 3.1), (s * 0.68, -0.58, 2.62), (s * 0.16, -0.58, 2.5)], (0, 0.16, 0), a=0.52, b=0.42, g=0.2)
		m.plate(t, "red", [(s * 0.18, 0.6, 3.98), (s * 1.06, 0.6, 3.98), (s * 1.04, 0.6, 2.5), (s * 0.18, 0.6, 2.5)], (0, 0.14, 0), a=0.46, b=0.42, g=0.2)
		# the silver four-point stars on the upper chest
		c = Vector((s * 0.62, -0.68, 3.52))
		m.plate(t, "steel", [c + Vector((0, 0, 0.26)), c + Vector((0.05, 0, 0.05)), c + Vector((0.26, 0, 0)), c + Vector((0.05, 0, -0.05)), c + Vector((0, 0, -0.26)), c + Vector((-0.05, 0, -0.05)), c + Vector((-0.26, 0, 0)), c + Vector((-0.05, 0, 0.05))], (0, 0.05, 0), a=0.66, b=0.2, g=0.0)
	for i, z in enumerate((3.84, 3.52, 3.2, 2.88, 2.56)):
		m.plate(t, "dark", [(-0.14, -0.7, z), (0.14, -0.7, z), (0.26 - 0.03 * i, -0.7, z - 0.14), (0, -0.7, z - 0.3), (-0.26 + 0.03 * i, -0.7, z - 0.14)], (0, 0.08, 0), a=0.46, b=0.42)
		m.plate(t, "red", [(-0.08, -0.74, z - 0.04), (0.08, -0.74, z - 0.04), (0.16, -0.74, z - 0.12), (0, -0.74, z - 0.22), (-0.16, -0.74, z - 0.12)], (0, 0.03, 0), a=0.6, b=0.3)
	# gorget and waist
	m.block(t, "dark", 0, 0, 4.2, 3.92, 0.68, 0.52, ch=0.05, a=0.44)
	m.block(t, "dark", 0, 0, 2.56, 2.26, 1.08, 0.6, ch=0.04, a=0.46)
	# the tassets: pointed plates hanging from the waist
	for x in (-0.76, 0.76, -0.26, 0.26):
		for y, off in ((-0.62, 0.05), (0.62, 0.05)):
			m.plate(t, "red", [(x - 0.25, y, 2.4), (x + 0.25, y, 2.4), (x + 0.2, y, 1.62), (x, y, 1.34), (x - 0.2, y, 1.62)], (0, off, 0), a=0.5, b=0.4, g=0.22)
	knight_cape(m)


def knight_arm(m, side, s):
	a, x = f"{side}Arm", s * 1.52
	m.block(a, "dark", x, 0, 3.9, 2.1, 0.46, 0.46)
	# the big layered pauldron with its blades
	m.block(a, "red", x + s * 0.03, 0, 4.26, 3.52, 0.64, 0.66, ch=0.14, mids=(3.9,), jit=0.018, a=0.54, b=0.46)
	m.block(a, "dark", x + s * 0.03, 0, 3.6, 3.36, 0.6, 0.62, ch=0.05, a=0.44)
	m.block(a, "red", x + s * 0.05, 0, 3.46, 3.2, 0.56, 0.58, ch=0.05, a=0.5, b=0.44)
	m.spike(a, "red", (x + s * 0.2, -0.28, 4.14), (x + s * 0.86, -0.4, 4.92), 0.2, flat=0.6, a=0.52, b=0.42)
	m.spike(a, "red", (x + s * 0.3, 0.22, 4.1), (x + s * 0.96, 0.32, 4.68), 0.17, flat=0.6, a=0.48, b=0.42)
	m.spike(a, "red", (x + s * 0.56, 0, 3.84), (x + s * 1.06, 0, 4.0), 0.15, flat=0.6, a=0.48, b=0.42)
	# vambrace with a blade at the elbow, then a plain block gauntlet
	m.block(a, "red", x, 0, 3.1, 2.34, 0.52, 0.52, ch=0.06, flare=0.03, jit=0.012, a=0.5, b=0.44)
	m.spike(a, "red", (x + s * 0.34, 0.3, 3.06), (x + s * 0.7, 0.64, 3.48), 0.13, flat=0.6, a=0.5, b=0.42)
	m.block(a, "dark", x, 0, 2.38, 2.16, 0.54, 0.54, ch=0.03, a=0.46)
	m.block(a, "red", x, 0, 2.2, 1.68, 0.5, 0.5, ch=0.07, a=0.56, b=0.36)


def knight_leg(m, side, s):
	l, x = f"{side}Leg", s * 0.52
	m.block(l, "dark", x, 0, 2.0, 0.3, 0.45, 0.47)
	m.block(l, "red", x, -0.03, 1.94, 1.16, 0.51, 0.53, ch=0.05, jit=0.015, a=0.48, b=0.44)
	m.plate(l, "red", [(x - 0.4, -0.6, 1.26), (x + 0.4, -0.6, 1.26), (x + 0.32, -0.6, 0.92), (x, -0.6, 0.74), (x - 0.32, -0.6, 0.92)], (0, 0.18, 0), a=0.56, b=0.4, g=0.2)  # poleyn
	m.spike(l, "red", (x + s * 0.34, 0, 1.18), (x + s * 0.74, 0.05, 1.54), 0.13, flat=0.6, a=0.5, b=0.42)
	m.block(l, "red", x, 0, 0.98, 0.3, 0.5, 0.52, ch=0.05, flare=0.02, jit=0.012, a=0.48, b=0.44)
	# sabaton, long and pointed
	m.block(l, "dark", x, 0.0, 0.32, 0.0, 0.52, 0.58, ch=0.04, a=0.46)
	m.path(l, "red", [(x, -0.14, 0.15), (x, -0.56, 0.15), (x, -0.98, 0.07)], [0.5, 0.42, 0.04], [0.15, 0.13, 0.02], n=6, a=0.55, b=0.42)


def side_knight():
	parts = {
		"Torso": ((0, 0, 3), None),
		"Head": ((0, 0, 4.1), "Torso"),
		"LeftArm": ((1.52, 0, 3.9), "Torso"),
		"RightArm": ((-1.52, 0, 3.9), "Torso"),
		"LeftLeg": ((0.52, 0, 2.0), "Torso"),
		"RightLeg": ((-0.52, 0, 2.0), "Torso"),
		"Sword": ((-1.52, 0, 1.94), "RightArm"),
	}
	m = Model("side_knight", KNIGHT_RAMPS, parts)
	knight_helm(m)
	knight_plume(m)
	knight_torso(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		knight_arm(m, side, s)
		knight_leg(m, side, s)
	# the long sword held upright clear of the body: dark toothed base, then a long pale blade
	s, x = "Sword", -1.52
	y = -0.68
	m.path(s, "dark", [(x, y, 1.46), (x, y, 2.36)], 0.09, 0.09, n=6, a=0.46)
	m.block(s, "dark", x, y, 2.46, 2.3, 0.42, 0.11, ch=0.03, a=0.46)
	for i in range(5):
		z = 2.5 + i * 0.2
		m.plate(s, "dark", [(x - 0.2, y, z), (x + 0.2, y, z), (x + 0.2, y, z + 0.14), (x + 0.3, y, z + 0.22), (x + 0.12, y, z + 0.2), (x - 0.2, y, z + 0.2)], (0, 0.09, 0), a=0.46, b=0.3)
	m.path(s, "steel", [(x, y, 2.46), (x, y, 4.6), (x, y, 6.5), (x, y, 7.05)], [0.16, 0.15, 0.12, 0.004], [0.04, 0.04, 0.03, 0.004], n=6, a=0.62, b=0.3, g=0.14)
	return m


# ---- side_wyvern


WYVERN_RAMPS = {
	"scale": ["#07080b", "#14171d", "#272c36", "#4a5160"],
	"glow": ["#17a4dc", "#2cc2f0", "#52d8fa", "#90ecff"],
	"horn": ["#8fd0ec", "#c0ecfa", "#e6fafe", "#ffffff"],
	"eye": ["#7a6ad8", "#a496f0", "#cdc4fb", "#f0ecff"],
}
# meshes the game sets to Material Neon: everything blue, each under the part it moves with
WYVERN_NEON = ("WingNeonLeft", "WingNeonRight", "BodyNeon", "NeckNeon", "HeadNeon", "TailNeon", "LegNeonLeft", "LegNeonRight")
WYVERN_SHOULDER = (0.36, -0.05, 4.12)
WYVERN_MEMBRANE = 0.12  # wing shell depth: thick enough that both faces stay apart in Roblox, inside the finger bones


def wyvern_wing(m, s, side):
	"""One spread wing. Its bones and its membrane are two parts with one origin, the root: rotate WingLeft or WingRight to flap."""
	bones, neon = f"Wing{side}", f"WingNeon{side}"
	shoulder = Vector((s * WYVERN_SHOULDER[0], WYVERN_SHOULDER[1], WYVERN_SHOULDER[2]))
	elbow = Vector((s * 1.95, 0.25, 5.15))
	wrist = Vector((s * 2.95, 0.5, 6.0))
	tips = [Vector((s * 5.0, 1.3, 6.4)), Vector((s * 5.45, 1.85, 4.95)), Vector((s * 4.7, 2.1, 3.55)), Vector((s * 3.15, 1.9, 2.95))]
	root = Vector((s * 0.3, 0.92, 3.42))
	m.path(bones, "scale", [shoulder, elbow], [0.17, 0.13], n=6, g=0.0)
	m.path(bones, "scale", [elbow, wrist], [0.13, 0.1], n=6, g=0.0)
	m.spike(bones, "horn", wrist, wrist + Vector((s * 0.1, -0.5, 0.56)), 0.09, a=0.56, b=0.3)  # the thumb claw
	for tip in tips:
		mid = wrist.lerp(tip, 0.55) + (tip - wrist).cross(Vector((0, s, 0))).normalized() * 0.16
		m.path(bones, "scale", [wrist, mid, tip], [0.09, 0.07, 0.012], n=6, g=0.0)
	# membrane between the fingers, its trailing edge scalloped towards the wrist
	soft = lambda co: 0.16 * (1 - min(1.0, (co - wrist).length / 3.2))
	chain = tips + [root]
	for a, b in zip(chain, chain[1:]):
		pull = a.lerp(b, 0.5).lerp(wrist if b is not root else elbow, 0.26)
		grid = [[wrist, wrist.lerp(pull, 0.5), wrist], [a.lerp(wrist, 0.5), pull.lerp(wrist, 0.05), b.lerp(wrist, 0.5)], [a, pull, b]]
		m.sheet(neon, "glow", grid, (0, WYVERN_MEMBRANE, 0), a=0.5, b=0.1, g=0.04, tone=0.04, extra=soft)
	m.sheet(neon, "glow", [[shoulder, elbow, wrist], [shoulder.lerp(root, 0.5), elbow.lerp(root, 0.4), wrist.lerp(root, 0.26)], [root, root.lerp(tips[3], 0.5), wrist.lerp(tips[3], 0.5)]], (0, WYVERN_MEMBRANE, 0), a=0.5, b=0.1, g=0.04, tone=0.04)
	# glowing cracks along the arm
	for a, b in ((shoulder, elbow), (elbow, wrist)):
		for t in (0.3, 0.68):
			c = a.lerp(b, t) + Vector((0, -0.15, 0))
			m.plate(neon, "glow", [c + Vector((-0.1 * s, 0, 0.07)), c + Vector((0.1 * s, 0, 0.13)), c + Vector((0.1 * s, 0, 0.07)), c + Vector((-0.1 * s, 0, 0.01))], (0, 0.03, 0), a=0.7, b=0.1, g=0.0)


def wyvern_leg(m, s, side):
	"""Tucked for flight: thigh forward under the belly, shin folded back, feet trailing."""
	leg, neon = f"Leg{side}", f"LegNeon{side}"
	x = s * 0.3
	knee, ankle, foot = Vector((x, 0.12, 2.92)), Vector((x, 0.72, 2.62)), Vector((x, 1.08, 2.56))
	m.path(leg, "scale", [(x, 0.6, 3.42), (x, 0.36, 3.14), knee], [0.17, 0.15, 0.1], [0.2, 0.17, 0.1], n=8, g=0.0)
	m.path(leg, "scale", [knee, ankle], [0.1, 0.075], n=8, g=0.0)
	m.path(leg, "scale", [ankle, foot], [0.085, 0.11], [0.06, 0.05], n=6, g=0.0)
	for i in (-1, 0, 1):
		m.spike(leg, "horn", foot + Vector((i * 0.08, 0, 0)), foot + Vector((i * 0.15, 0.42, -0.2)), 0.05, a=0.58, b=0.3)
	g = Vector((x + s * 0.17, 0.3, 3.1))
	m.plate(neon, "glow", [g + Vector((0, -0.14, 0.02)), g + Vector((0, 0.14, 0.14)), g + Vector((0, 0.14, 0.07)), g + Vector((0, -0.14, -0.05))], (0.02, 0, 0), a=0.7, b=0.1, g=0.0)


def side_wyvern():
	parts = {
		"Body": ((0, 0.3, 3.7), None),
		"BodyNeon": ((0, 0.3, 3.7), "Body"),
		"Neck": ((0, -0.42, 4.18), "Body"),
		"NeckNeon": ((0, -0.42, 4.18), "Neck"),
		"Head": ((0, -1.55, 6.05), "Neck"),
		"HeadNeon": ((0, -1.55, 6.05), "Head"),
		"WingLeft": ((WYVERN_SHOULDER[0], WYVERN_SHOULDER[1], WYVERN_SHOULDER[2]), "Body"),
		"WingNeonLeft": ((WYVERN_SHOULDER[0], WYVERN_SHOULDER[1], WYVERN_SHOULDER[2]), "WingLeft"),
		"WingRight": ((-WYVERN_SHOULDER[0], WYVERN_SHOULDER[1], WYVERN_SHOULDER[2]), "Body"),
		"WingNeonRight": ((-WYVERN_SHOULDER[0], WYVERN_SHOULDER[1], WYVERN_SHOULDER[2]), "WingRight"),
		"Tail": ((0, 1.0, 3.3), "Body"),
		"TailNeon": ((0, 1.0, 3.3), "Tail"),
		"LegLeft": ((0.3, 0.6, 3.42), "Body"),
		"LegNeonLeft": ((0.3, 0.6, 3.42), "LegLeft"),
		"LegRight": ((-0.3, 0.6, 3.42), "Body"),
		"LegNeonRight": ((-0.3, 0.6, 3.42), "LegRight"),
	}
	m = Model("side_wyvern", WYVERN_RAMPS, parts, neon=WYVERN_NEON)
	# a slim torso angled for flight, chest high, hips low and trailing
	spine = [(0, 1.0, 3.3), (0, 0.45, 3.62), (0, -0.05, 3.92), (0, -0.42, 4.18)]
	m.path("Body", "scale", spine, [0.2, 0.34, 0.38, 0.26], [0.18, 0.28, 0.32, 0.24], n=8, g=0.0, jit=0.01)
	# the glowing underbelly in bands, each a chunk of light between dark seams
	belly = [Vector(p) for p in ((0, 0.86, 3.08), (0, 0.32, 3.34), (0, -0.2, 3.62), (0, -0.62, 3.98))]
	for i in range(3):
		for j in range(2):
			a, c = belly[i].lerp(belly[i + 1], j / 2 + 0.03), belly[i].lerp(belly[i + 1], (j + 1) / 2 - 0.03)
			m.path("BodyNeon", "glow", [a, c], [lerp(0.13, 0.22, i / 2), lerp(0.15, 0.22, i / 2)], 0.05, n=6, a=0.56, b=0.18, g=0.04)
	# neck: the source's long rising S, spined along its back
	neck = [Vector(p) for p in ((0, -0.42, 4.18), (0, -0.62, 4.75), (0, -0.55, 5.3), (0, -0.95, 5.85), (0, -1.55, 6.05))]
	m.path("Neck", "scale", neck, [0.22, 0.17, 0.15, 0.14, 0.14], n=8, g=0.0)
	front = [Vector(p) for p in ((0, -0.72, 4.35), (0, -0.8, 4.78), (0, -0.72, 5.25), (0, -1.0, 5.68))]
	for i in range(3):
		for j in range(2):
			a, c = front[i].lerp(front[i + 1], j / 2 + 0.04), front[i].lerp(front[i + 1], (j + 1) / 2 - 0.04)
			m.path("NeckNeon", "glow", [a, c], [0.13 - 0.015 * i, 0.12 - 0.015 * i], 0.035, n=6, a=0.56, b=0.18, g=0.04)
	for i in range(6):
		f = (i + 0.5) / 6 * (len(neck) - 1)
		k = min(int(f), len(neck) - 2)
		p = neck[k].lerp(neck[k + 1], f - k)
		up = Vector((0, 0.9, 0.42 if k < 2 else 0.9)).normalized()
		m.spike("Neck", "scale", p + up * 0.12, p + up * 0.36, 0.06, flat=0.5, a=0.54)
	# head: an arrow of hard planes
	h = "Head"
	m.path(h, "scale", [(0, -1.35, 6.08), (0, -1.83, 6.03), (0, -2.35, 5.83), (0, -2.97, 5.47)], [0.3, 0.28, 0.17, 0.02], [0.26, 0.23, 0.14, 0.02], n=6, a=0.54, b=0.44, g=0.0)
	m.path(h, "scale", [(0, -1.57, 5.79), (0, -2.15, 5.51), (0, -2.65, 5.29)], [0.2, 0.13, 0.02], [0.07, 0.055, 0.02], n=6, a=0.46, g=0.0)
	m.path("HeadNeon", "glow", [(0, -1.67, 5.73), (0, -2.23, 5.55)], [0.15, 0.1], 0.025, n=4, a=0.7, b=0.1, g=0.0)
	for s in (1, -1):
		m.plate(h, "eye", [(s * 0.3, -1.65, 6.11), (s * 0.26, -2.0, 6.02), (s * 0.24, -1.99, 5.95), (s * 0.3, -1.71, 5.99)], (0.03, 0, 0), a=0.8, b=0.05, g=0.0)
		# the long pale horns sweeping up and back, with shorter ones below them
		m.spike(h, "horn", (s * 0.16, -1.2, 6.22), (s * 0.45, 0.43, 7.55), 0.13, flat=0.8, a=0.6, b=0.24)
		m.spike(h, "horn", (s * 0.22, -1.15, 6.08), (s * 0.92, 0.01, 6.77), 0.11, flat=0.8, a=0.6, b=0.24)
		m.spike(h, "horn", (s * 0.26, -1.23, 5.93), (s * 1.02, -0.41, 5.99), 0.085, flat=0.8, a=0.6, b=0.24)
		m.spike(h, "scale", (s * 0.22, -1.67, 6.19), (s * 0.34, -1.17, 6.61), 0.08, flat=0.6, a=0.54)
	for s, side in ((1, "Left"), (-1, "Right")):
		wyvern_wing(m, s, side)
		wyvern_leg(m, s, side)
	# the long thin tail, trailing straight out behind in flight
	t = "Tail"
	tail = [Vector(p) for p in ((0, 1.0, 3.3), (0, 1.9, 3.02), (0, 2.9, 2.82), (0.05, 3.9, 2.86), (0.2, 4.8, 3.12), (0.42, 5.6, 3.36))]
	wide = [0.2, 0.16, 0.12, 0.09, 0.055, 0.008]
	m.path(t, "scale", tail, wide, [w * 0.92 for w in wide], n=8, g=0.0)
	for i in range(5):
		f = i / 5 * 3
		k = int(f)
		p, r = tail[k].lerp(tail[k + 1], f - k), lerp(wide[k], wide[k + 1], f - k)
		m.spike(t, "scale", p + Vector((0, 0, r * 0.8)), p + Vector((0, 0.24, r + 0.22 - 0.02 * i)), 0.055, flat=0.5, a=0.54)
	for i in range(3):
		g = tail[i].lerp(tail[i + 1], 0.5)
		w = lerp(wide[i], wide[i + 1], 0.5)
		for s in (1, -1):
			m.plate("TailNeon", "glow", [g + Vector((s * w, -0.14, 0.02)), g + Vector((s * w, 0.14, -0.02)), g + Vector((s * w, 0.14, -0.08)), g + Vector((s * w, -0.14, -0.04))], (0.02, 0, 0), a=0.7, b=0.1, g=0.0)
	return m


MODELS = {"boss_raga": boss_raga, "side_chain": side_chain, "side_knight": side_knight, "side_wyvern": side_wyvern}
# Outside MODELS so the b1 contact sheet stays as the owner approved it.
BUILDS = {**MODELS, "side_raga": lambda: boss_raga("side_raga")}


# One file per later Sidekick in tools/blender/sidekicks/: ID, NAME and build(k), where k is this script's namespace (k.Model).
def load_sidekick_files():
	import importlib.util
	import types

	folder = os.path.join(HERE, "sidekicks")
	kit = types.SimpleNamespace(**globals())
	for fname in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
		if not fname.endswith(".py"):
			continue
		spec = importlib.util.spec_from_file_location(fname[:-3], os.path.join(folder, fname))
		mod = importlib.util.module_from_spec(spec)
		spec.loader.exec_module(mod)
		NAMES[mod.ID] = mod.NAME
		MODELS[mod.ID] = lambda build=mod.build: build(kit)


load_sidekick_files()


# ---- rendering


def world_verts(objs):
	bpy.context.view_layer.update()
	out = []
	for o in objs:
		if o.type == "MESH":
			co = np.empty(len(o.data.vertices) * 3)
			o.data.vertices.foreach_get("co", co)
			co = co.reshape(-1, 3)
			mw = np.array(o.matrix_world)
			out.append(co @ mw[:3, :3].T + mw[:3, 3])
	return np.vstack(out)


def bounds(root):
	pts = world_verts(list(root.children_recursive))
	return pts.min(axis=0), pts.max(axis=0)


def fit(cam, pts, d, aspect, margin=0.94):
	"""Places the ortho camera along d so pts fill the frame."""
	d = Vector(d).normalized()
	c = Vector(((pts.min(axis=0) + pts.max(axis=0)) / 2).tolist())
	span = float(np.linalg.norm(pts.max(axis=0) - pts.min(axis=0)))
	cam.location = c + d * span * 3
	build_avatar.aim(cam, c)
	bpy.context.view_layer.update()
	mw = np.array(cam.matrix_world)
	x, y = pts @ mw[:3, 0], pts @ mw[:3, 1]
	cam.location = cam.location + Vector((mw[:3, 0] * (x.min() + x.max() - 2 * np.dot(mw[:3, 3], mw[:3, 0])) / 2 + mw[:3, 1] * (y.min() + y.max() - 2 * np.dot(mw[:3, 3], mw[:3, 1])) / 2).tolist())
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = max(float(x.max() - x.min()), float(y.max() - y.min()) * aspect) / margin
	cam.data.clip_end = span * 8


def view_dir(view):
	return build_avatar.VIEWS[view]


def build_one(cid):
	build_avatar.reset()
	bpy.context.preferences.filepaths.save_version = 0
	m = BUILDS[cid]()
	root, tris = m.finish()
	os.makedirs(os.path.join(OUT, cid, "review"), exist_ok=True)
	os.makedirs(TMP, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, cid, cid + ".blend"))
	scene = bpy.context.scene
	cam = build_avatar.setup_render(scene)
	pts = world_verts(list(root.children_recursive))
	for view in VIEW_ORDER:
		for path, w, h in ((os.path.join(OUT, cid, "review", view + ".png"), 1920, 1080), (os.path.join(TMP, f"{cid}_{view}.png"), 640, 560)):
			scene.render.resolution_x, scene.render.resolution_y = w, h
			fit(cam, pts, view_dir(view), w / h)
			scene.render.filepath = path
			bpy.ops.render.render(write_still=True)
	lo, hi = bounds(root)
	report = {"tris": sum(tris.values()), "largest_mesh": max(tris.values()), "parts": tris, "size": (hi - lo).round(3).tolist(), "min_z": round(float(lo[2]), 3)}
	with open(os.path.join(TMP, cid + ".json"), "w") as f:
		json.dump(report, f, indent=1)
	print("BUILT", cid, json.dumps(report))


def append_model(cid):
	path = os.path.join(OUT, cid, cid + ".blend")
	with bpy.data.libraries.load(path) as (src, dst):
		dst.objects = [n for n in src.objects]
	for o in dst.objects:
		bpy.context.scene.collection.objects.link(o)
	return next(o for o in dst.objects if o.parent is None and o.type == "EMPTY")


def copy_tree(root):
	new = root.copy()
	bpy.context.scene.collection.objects.link(new)
	for c in root.children:
		k = copy_tree(c)
		k.parent = new
	return new


def stand(root, height, x, spin=0.0):
	"""Scales a tree to a true height with its feet on z 0 and its centre at x."""
	root.rotation_euler = (0, 0, math.radians(spin))
	root.scale = (1, 1, 1)
	root.location = (0, 0, 0)
	lo, hi = bounds(root)
	k = height / float(hi[2] - lo[2])
	root.scale = (k, k, k)
	lo, hi = bounds(root)
	root.location = (x - float(lo[0] + hi[0]) / 2, 0, -float(lo[2]))
	return bounds(root)


def alpha_height(path, x0, x1, scale, width):
	"""Measured figure height in px from the rendered alpha, inside the column range of world x0..x1."""
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	px = np.empty(w * h * 4, dtype=np.float32)
	img.pixels.foreach_get(px)
	alpha = px.reshape(h, w, 4)[:, :, 3]
	bpy.data.images.remove(img)
	c0, c1 = max(0, int(x0 * w)), min(w, int(x1 * w))
	rows = np.where((alpha[:, c0:c1] > 0.5).any(axis=1))[0]
	return int(rows.max() - rows.min() + 1), int(rows.min()), h


def lineup(cam, hero, roots, H):
	"""Panel (b). Level ortho front camera; every figure turned the same, so z heights in the render are true."""
	scene = bpy.context.scene
	w, h = 1280, LINEUP_H
	scene.render.resolution_x, scene.render.resolution_y = w, h
	x, gap = 0.0, 0.5
	spans = {}
	for cid, root in [("db_hero", hero)] + list(roots.items()):
		tall = H if cid == "db_hero" else H * SIDEKICK_RATIO
		stand(root, tall, 0.0, spin=-28)
		lo, hi = bounds(root)
		wide = float(hi[0] - lo[0])
		lo, hi = stand(root, tall, x + wide / 2, spin=-28)
		spans[cid] = (float(lo[0]), float(hi[0]), float(hi[2] - lo[2]))
		x += wide + gap
		if cid == "db_hero":
			# Kaizel flies: a copy at the hero's shoulder, room left for it in the row
			hover = copy_tree(roots["side_wyvern"])
			stand(hover, H * SIDEKICK_RATIO, 0.0, spin=-28)
			lo, hi = bounds(hover)
			hw = float(hi[0] - lo[0])
			lo, hi = stand(hover, H * SIDEKICK_RATIO, x + hw / 2 - gap, spin=-28)
			hover.location.z += HERO_SHOULDER - float(hi[2] - lo[2]) / 2
			hover_x = x + hw / 2 - gap
			x += hw
	ow = x - gap + 0.8
	# the frame is fixed to the figures: one world unit is px_per_unit pixels both ways
	scale = max(ow, (H * 1.12) * w / h)
	px_per_unit = w / scale
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = scale
	floor_px = 90
	centre_z = (h / 2 - floor_px) / px_per_unit
	cam.location = ((x - gap) / 2, -60, centre_z)
	cam.rotation_euler = (math.radians(90), 0, 0)
	path = os.path.join(TMP, "lineup.png")
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	x_left = (x - gap) / 2 - scale / 2
	result = {"px_per_unit": px_per_unit, "floor_px": floor_px, "figures": {}, "hover_x_px": (hover_x - x_left) * px_per_unit, "hover_y_px": HERO_SHOULDER * px_per_unit, "hover": hover.name}
	for cid, (a, b, world_h) in spans.items():
		px_h, row0, _ = alpha_height(path, (a - x_left) / scale, (b - x_left) / scale, scale, w)
		result["figures"][cid] = {"world_height": world_h, "px_height": px_h, "row0": row0, "x_px": ((a + b) / 2 - x_left) * px_per_unit, "top_px": px_h}
	hero_px = result["figures"]["db_hero"]["px_height"]
	for cid in roots:
		f = result["figures"][cid]
		f["ratio_world"] = f["world_height"] / H
		f["ratio_px"] = f["px_height"] / hero_px
	return result


def scale_panel(cam, raga, hero):
	"""Panel (c): true studs in one scene, plus a zoomed crop of the same scene at the feet."""
	scene = bpy.context.scene
	raga.scale = (1, 1, 1)
	raga.location = (0, 0, 0)
	lo, hi = bounds(raga)
	head = world_verts([next(o for o in raga.children_recursive if o.name.startswith("Head"))])
	# the head block, without the wings that rise from it
	head_top = float(head[np.abs(head[:, 0]) < 0.82][:, 2].max())
	overall = RAGA_HEAD_STUDS * float(hi[2] - lo[2]) / head_top
	lo, hi = stand(raga, overall, 0.0)
	raga_info = {"overall": float(hi[2] - lo[2]), "head_top_units": head_top, "unit_studs": float(raga.scale[0]), "x_max": float(hi[0]), "x_min": float(lo[0])}
	runner = copy_tree(hero)
	legend = copy_tree(hero)
	foot_edge = float(raga.scale[0]) * 1.42 + float(raga.location[0])
	stand(runner, RUNNER_STUDS, foot_edge + 8, spin=-28)
	stand(legend, LEGEND_STUDS, foot_edge + 18, spin=-28)
	raga_low = float(raga.scale[0]) * head_top
	w, h = 1280, 1260
	scene.render.resolution_x, scene.render.resolution_y = w, h
	floor_px = 44
	scale = max(float(hi[0] - lo[0]) + 80, overall * 1.07 * w / h)
	px_per = w / scale
	cx = float(lo[0] + hi[0]) / 2 + 20
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = scale
	cam.location = (cx, -2000, (h / 2 - floor_px) / px_per)
	cam.rotation_euler = (math.radians(90), 0, 0)
	cam.data.clip_end = 8000
	full = os.path.join(TMP, "scale.png")
	scene.render.filepath = full
	bpy.ops.render.render(write_still=True)
	# the zoom: 88 studs wide, the Raga's foot beside the two small figures
	zw, zh = 1280, 420
	scene.render.resolution_x, scene.render.resolution_y = zw, zh
	zs = 66.0
	zx = foot_edge - 6
	cam.data.ortho_scale = zs
	zpx = zw / zs
	zfloor = 40
	cam.location = (zx, -2000, (zh / 2 - zfloor) / zpx)
	zoom = os.path.join(TMP, "scale_zoom.png")
	scene.render.filepath = zoom
	bpy.ops.render.render(write_still=True)
	left = cx - scale / 2
	zleft = zx - zs / 2
	return {
		"raga": raga_info, "body_top": raga_low, "px_per": px_per, "floor_px": floor_px, "raga_x_px": (float(raga.location[0]) - left) * px_per,
		"runner_x_px": (foot_edge + 8 - left) * px_per, "legend_x_px": (foot_edge + 18 - left) * px_per,
		"zpx": zpx, "zfloor": zfloor, "runner_zx": (foot_edge + 8 - zleft) * zpx, "legend_zx": (foot_edge + 18 - zleft) * zpx,
	}


def html_sheet(reports, line, scale):
	css = """
	* { margin:0; padding:0; box-sizing:border-box; font-family:-apple-system, Helvetica, Arial, sans-serif; }
	body { width:2560px; background:#20232b; color:#f2f3f7; }
	h1 { font-size:46px; padding:26px 28px 6px; }
	.sub { font-size:25px; color:#b9bdca; padding:0 28px 18px; }
	h2 { font-size:34px; padding:22px 28px 10px; background:#2c3039; border-top:3px solid #4a4f5c; }
	h2 small { font-size:25px; font-weight:400; color:#c5c9d5; margin-left:18px; }
	.row { display:flex; }
	.cell { width:640px; position:relative; background:#c7ccd6; }
	.cell img { display:block; width:640px; height:560px; }
	.cell span { position:absolute; left:12px; top:10px; font-size:25px; font-weight:600; color:#14161c; background:#ffffffc8; padding:2px 10px; border-radius:6px; }
	.panels { display:flex; }
	.panel { width:1280px; position:relative; }
	.stage { position:relative; width:1280px; background:#c7ccd6; overflow:hidden; }
	.stage img { display:block; position:relative; }
	.tag { position:absolute; font-size:24px; font-weight:600; color:#14161c; text-align:center; transform:translateX(-50%); white-space:nowrap; line-height:1.2; }
	.tag small { display:block; font-size:21px; font-weight:400; }
	.floor { position:absolute; left:0; right:0; height:3px; background:#3b3f4a; }
	.hline { position:absolute; left:0; right:0; border-top:2px dashed #2c6fd0; }
	.hlabel { position:absolute; left:14px; font-size:22px; font-weight:600; color:#1c4f9c; }
	.note { font-size:23px; color:#d3d6df; padding:12px 28px 18px; line-height:1.35; }
	"""
	out = [f"<!DOCTYPE html><html><head><style>{css}</style></head><body>"]
	out.append("<h1>Boss event: design contact sheet</h1><div class=sub>For owner review. Flat readable light, orthographic cameras. Modelled in-house. Not uploaded, not in game.</div>")
	out.append("<h2>(a) Models: front, three-quarter, side, back</h2>")
	labels = {"front": "Front", "three_quarter": "Three-quarter", "side": "Side", "back": "Back"}
	for cid, rep in reports.items():
		out.append(f"<h2>{cid} &nbsp;|&nbsp; {NAMES[cid]}<small>{rep['tris']} tris total, largest mesh {rep['largest_mesh']}, {len(rep['parts'])} parts</small></h2><div class=row>")
		for v in VIEW_ORDER:
			out.append(f"<div class=cell><img src='{cid}_{v}.png'><span>{labels[v]}</span></div>")
		out.append("</div>")
	out.append("<div class=panels>")
	# panel b
	floor = line["floor_px"]
	fig = line["figures"]
	out.append(f"<div class=panel><h2>(b) True-scale line-up</h2><div class=stage style='height:{LINEUP_H}px'><img src='lineup.png' style='width:1280px;height:{LINEUP_H}px'>")
	out.append(f"<div class=floor style='top:{LINEUP_H - floor}px'></div>")
	H = fig["db_hero"]["px_height"]
	for name, frac, label in (("hero", 1.0, f"db_hero height ({H} px)"), ("35", SIDEKICK_RATIO, "35% of db_hero")):
		y = LINEUP_H - floor - H * frac
		out.append(f"<div class=hline style='top:{y:.0f}px'></div><div class=hlabel style='left:auto;right:14px;top:{y - 30:.0f}px'>{label}</div>")
	hy = LINEUP_H - floor - line["hover_y_px"]
	out.append(f"<div class=hline style='top:{hy:.0f}px;border-color:#128a5a'></div><div class=hlabel style='left:auto;right:14px;top:{hy - 30:.0f}px;color:#0d6e47'>db_hero shoulder height</div>")
	out.append(f"<div class=tag style='left:{line['hover_x_px']:.0f}px;top:{hy - 145:.0f}px'>side_wyvern hovering<small>Kaizel, flies at the shoulder</small></div>")
	for cid, f in fig.items():
		nm = "Reference" if cid == "db_hero" else NAMES[cid]
		pct = "" if cid == "db_hero" else f"<small>{f['ratio_px'] * 100:.1f}%</small>"
		out.append(f"<div class=tag style='left:{f['x_px']:.0f}px;top:{LINEUP_H - floor + 6}px;font-size:19px'>{cid}<small style='font-size:19px'>{nm}</small>{pct}</div>")
	out.append("</div>")
	ratios = ", ".join(f"{cid} {fig[cid]['ratio_px'] * 100:.1f}%" for cid in fig if cid != "db_hero")
	out.append(f"<div class=note>Height of each figure's whole bounding box, plume, wings and horns included, measured from the render's pixels: {ratios}. A sidekick is a figure scaled to the target ratio, so this checks the render, not a design outcome. side_wyvern flies: the row copy rests on the floor line only to measure it, and the copy beside db_hero is centred at its shoulder height, {HERO_SHOULDER:.0f} rig units.</div></div>")
	# panel c
	fl, pp = scale["floor_px"], scale["px_per"]
	out.append("<div class=panel><h2>(c) Scale panel, true studs</h2><div class=stage style='height:1260px'><img src='scale.png' style='width:1280px;height:1260px'>")
	out.append(f"<div class=floor style='top:{1260 - fl}px'></div>")
	for label, st in ((f"{scale['raga']['overall']:.0f} studs, top of the wheel", scale["raga"]["overall"]), (f"{scale['body_top']:.0f} studs, top of the head", scale["body_top"])):
		y = 1260 - fl - st * pp
		out.append(f"<div class=hline style='top:{y:.0f}px'></div><div class=hlabel style='top:{y + 5:.0f}px'>{label}</div>")
	out.append(f"<div class=tag style='left:{scale['raga_x_px']:.0f}px;top:{1260 - fl + 6}px'>boss_raga, Big Raga</div>")
	out.append(f"<div class=tag style='left:{scale['legend_x_px'] + 120:.0f}px;top:{1260 - fl - 118}px'>Runner + Legend<small>see zoom below</small></div>")
	out.append("</div><div class=stage style='height:420px;border-top:3px solid #3b3f4a'><img src='scale_zoom.png' style='width:1280px;height:420px'>")
	zf = scale["zfloor"]
	out.append(f"<div class=floor style='top:{420 - zf}px'></div>")
	out.append(f"<div class=tag style='left:{scale['runner_zx']:.0f}px;top:{420 - zf - 5.75 * scale['zpx'] - 62:.0f}px'>Runner<small>{RUNNER_STUDS} studs</small></div>")
	out.append(f"<div class=tag style='left:{scale['legend_zx']:.0f}px;top:{420 - zf - 10.9 * scale['zpx'] - 62:.0f}px'>Plaza Legend<small>{LEGEND_STUDS} studs</small></div>")
	out.append("<div class=hlabel style='top:8px'>Zoom of the same scene at the feet: Raga's toes on the left</div></div>")
	u = scale["raga"]["unit_studs"]
	out.append(f"<div class=note>Runner and Legend are db_hero at true size. Big Raga's head top is at {scale['body_top']:.0f} studs, the wheel sitting on top of that: {scale['raga']['overall']:.0f} studs overall, {u:.1f} studs per model unit. Head top to the runner: {scale['body_top'] / RUNNER_STUDS:.0f}x.</div></div>")
	out.append("</div></body></html>")
	path = os.path.join(TMP, "sheet.html")
	with open(path, "w") as f:
		f.write("".join(out))
	return path


def sheet():
	build_avatar.reset()
	data = build_avatar.load_data()
	hero, _ = build_avatar.placed("db_hero", data["db_hero"])
	lo, hi = bounds(hero)
	H = float(hi[2] - lo[2])
	roots = {cid: append_model(cid) for cid in ("side_chain", "side_knight", "side_wyvern")}
	# one light rig for both panels: setup_render adds a sun each call
	cam = build_avatar.setup_render(bpy.context.scene)
	bpy.context.scene.render.film_transparent = True
	line = lineup(cam, hero, roots, H)
	line["db_hero_rig_height"] = H
	for r in roots.values():
		for o in [r] + list(r.children_recursive):
			bpy.data.objects.remove(o)
	hover = bpy.data.objects[line["hover"]]
	for o in [hover] + list(hover.children_recursive):
		bpy.data.objects.remove(o)
	raga = append_model("boss_raga")
	scale = scale_panel(cam, raga, hero)
	reports = {}
	for cid in MODELS:
		with open(os.path.join(TMP, cid + ".json")) as f:
			reports[cid] = json.load(f)
	html = html_sheet(reports, line, scale)
	with open(os.path.join(TMP, "measure.json"), "w") as f:
		json.dump({"lineup": line, "scale": scale}, f, indent=1)
	review = os.path.join(OUT, "review")
	os.makedirs(review, exist_ok=True)
	png = os.path.join(review, "boss_event_contact_sheet.png")
	# the header and model rows take 2750 px, the taller panel (c) the rest, measured from a render
	height = 2750 + 75 + 1260 + 420 + 105
	subprocess.run(
		[CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={TMP}/chrome", "--force-device-scale-factor=1", f"--window-size=2560,{height}", f"--screenshot={png}", "file://" + html],
		check=True,
		capture_output=True,
		timeout=180,
	)
	print("SHEET", png, json.dumps(line), json.dumps(scale))


def export_glb(cid):
	"""GLB of the built parts at their own scale and joints. The follower sizes the model at runtime (SIDEKICK_SPEC Display)."""
	bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, cid, cid + ".blend"))
	# In memory only: a neon part's Base Color is black, so without this it turns black if the importer drops emission.
	for mat in bpy.data.materials:
		if mat.use_nodes and mat.name.endswith("_Neon"):
			nt = mat.node_tree
			tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
			nt.links.new(tex.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])
	path = os.path.join(ROOT, "build", "avatar_glb", cid + ".glb")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True, export_animations=False)
	tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
	print(f"EXPORTED {cid} tris={tris} {os.path.getsize(path)} bytes")


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	if argv[0] == "build":
		for cid in argv[1:] or MODELS:
			build_one(cid)
	elif argv[0] == "sheet":
		sheet()
	elif argv[0] == "export":
		for cid in argv[1:]:
			export_glb(cid)


main()
