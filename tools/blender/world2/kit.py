"""Blender helpers for the World 2 track drafts (design doc 4.47, docs/WORLD2_SPEC.md "Blender first").

1 Blender unit = 1 stud. rb(x, y, z) maps Roblox world coordinates (Y up) to Blender (Z up), as tools/blender/plaza.
Every prop mesh is made once (one mesh datablock, named W2_<Biome>_<Prop>) and instanced along the road, so each
datablock is one planned asset with its tri count. Import-safe: no bpy work at import time.
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import roadframe


_OWNERS = None  # roadframe.Owners of the chain, made on first use


def rb(x, y, z):
	return Vector((x, -z, y))


def hexcol(h, a=1.0):
	h = h.lstrip("#")
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], a)


class Kit:
	"""Scene context for one track: its road (Roblox waypoints), materials, prop meshes, instancing and shots."""

	def __init__(self, track, biome):
		self.track = track
		self.biome = biome
		self.rng = random.Random(track["Number"] * 7919)
		self.col = bpy.data.collections.new("W2_" + biome)
		bpy.context.scene.collection.children.link(self.col)
		self.lib = bpy.data.collections.new("W2_%s_Assets" % biome)  # prop masters, hidden from renders
		bpy.context.scene.collection.children.link(self.lib)
		self.lib.hide_render = True
		self.lib.hide_viewport = True
		self._mats = {}
		self.props = {}
		self.width = track["Width"]
		self.wps = [Vector(p) for p in track["Waypoints"]]
		self._cum = [0.0]
		for a, b in zip(self.wps, self.wps[1:]):
			self._cum.append(self._cum[-1] + (b - a).length)
		self.length = self._cum[-1]
		lo = Vector((min(p.x for p in self.wps), 0, min(p.z for p in self.wps)))
		hi = Vector((max(p.x for p in self.wps), 0, max(p.z for p in self.wps)))
		self.lo, self.hi = lo, hi
		self.instances = 0

	# --- materials ---
	def mat(self, color, rough=0.8, metal=0.0, emit=0.0, alpha=1.0):
		key = (color, rough, metal, emit, alpha)
		if key in self._mats:
			return self._mats[key]
		m = bpy.data.materials.new("M_%s_%d" % (color, len(self._mats)))
		m.use_nodes = True
		b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		b.inputs["Base Color"].default_value = hexcol(color)
		b.inputs["Roughness"].default_value = rough
		b.inputs["Metallic"].default_value = metal
		if emit > 0:
			b.inputs["Emission Color"].default_value = hexcol(color)
			b.inputs["Emission Strength"].default_value = emit
		if alpha < 1:
			b.inputs["Alpha"].default_value = alpha
			try:
				m.surface_render_method = "BLENDED"
			except (AttributeError, TypeError):
				pass
		self._mats[key] = m
		return m

	# --- prop meshes (Roblox-style local space: Y up, -Z toward the road) ---
	def prop(self, name, parts):
		"""parts: list of (shape, size(x,y,z), pos(x,y,z), color, opts) with shape in box|cyl|ball|cone|wedge.
		opts: rough, metal, emit, rot (x,y,z degrees), taper (cone top scale), subdiv (ball), smooth. Pos is the part centre, Y up."""
		key = "W2_%s_%s" % (self.biome, name)
		bm = bmesh.new()
		mats = []
		for shape, size, pos, color, *rest in parts:
			o = rest[0] if rest else {}
			m = self.mat(color, o.get("rough", 0.8), o.get("metal", 0.0), o.get("emit", 0.0), o.get("alpha", 1.0))
			if m not in mats:
				mats.append(m)
			idx = mats.index(m)
			sx, sy, sz = size
			before = set(bm.faces)
			if shape == "box":
				geom = bmesh.ops.create_cube(bm, size=1.0)
			elif shape == "ball":
				geom = bmesh.ops.create_icosphere(bm, subdivisions=o.get("subdiv", 2), radius=0.5)
			elif shape in ("cyl", "cone"):
				top = o.get("taper", 0.0 if shape == "cone" else 1.0)
				geom = bmesh.ops.create_cone(
					bm, cap_ends=True, segments=o.get("seg", 10), radius1=0.5, radius2=0.5 * top, depth=1.0
				)
			elif shape == "wedge":
				geom = bmesh.ops.create_cube(bm, size=1.0)
				for vert in geom["verts"]:
					if vert.co.z > 0 and vert.co.y > 0:  # Roblox wedge: slope falls toward +Z (Blender -Y)
						vert.co.z = -0.5
			else:
				raise ValueError(shape)
			verts = geom["verts"]
			rx, ry, rz = o.get("rot", (0, 0, 0))
			# Roblox local (x, y, z) -> Blender (x, -z, y); a Blender cone's axis is Z = Roblox Y (upright)
			rot = (
				Matrix.Rotation(math.radians(ry), 4, "Z")
				@ Matrix.Rotation(math.radians(rx), 4, "X")
				@ Matrix.Rotation(math.radians(-rz), 4, "Y")
			)
			mtx = Matrix.Translation(rb(*pos)) @ rot @ Matrix.Diagonal((sx, sz, sy, 1))
			bmesh.ops.transform(bm, matrix=mtx, verts=verts)
			for f in set(bm.faces) - before:
				f.material_index = idx
				f.smooth = o.get("smooth", False)
		me = bpy.data.meshes.new(key)
		bm.to_mesh(me)
		bm.free()
		for m in mats:
			me.materials.append(m)
		ob = bpy.data.objects.new(key, me)
		self.lib.objects.link(ob)
		self.props[name] = ob
		return ob

	def place(self, name, pos, yaw=0.0, scale=1.0):
		"""An instance of prop `name` at Roblox world `pos` (x, y, z), turned `yaw` radians about Y."""
		src = self.props[name]
		ob = bpy.data.objects.new(src.name + "_i", src.data)
		ob.location = rb(*pos)
		ob.rotation_euler = (0, 0, yaw)
		ob.scale = (scale, scale, scale)
		self.col.objects.link(ob)
		self.instances += 1
		return ob

	# --- the road ---
	def at(self, d):
		"""Road centre (Roblox Vector) and flat right vector at distance d (studs, clamped) along the track."""
		d = max(0.0, min(self.length, d))
		lo, hi = 0, len(self._cum) - 1
		while hi - lo > 1:
			mid = (lo + hi) // 2
			if self._cum[mid] <= d:
				lo = mid
			else:
				hi = mid
		a, b = self.wps[lo], self.wps[hi]
		seg = (self._cum[hi] - self._cum[lo]) or 1.0
		p = a.lerp(b, (d - self._cum[lo]) / seg)
		t = Vector((b.x - a.x, 0, b.z - a.z))
		t = t.normalized() if t.length > 1e-6 else Vector((0, 0, -1))
		right = Vector((-t.z, 0, t.x))
		return p, right, t

	def beside(self, d, off, y=0.0):
		"""Roblox point `off` studs right (negative: left) of the road edge... measured from the centre line."""
		p, right, t = self.at(d)
		q = p + right * off
		yaw = math.atan2(-t.x, -t.z)  # Roblox heading of the road (0 = facing -Z)
		return (q.x, p.y - 1.0 + y, q.z), yaw

	def spot(self, d, off, along=0.0):
		"""Roblox world (x, z) of a road-relative spot (roadframe.py): the centre line at d (past the ends along the end
		straights), then `along` studs on in the road's direction there and `off` studs to its right (negative: left)."""
		(cx, cz), (tx, tz), (rx, rz) = roadframe.frame(self.wps, d)
		return cx + tx * along + rx * off, cz + tz * along + rz * off

	def owns(self, x, z):
		"""True where this track owns the ground at world (x, z): its centre line is the nearest (roadframe.Owners, the
		owner's 2026-11-25 rule by base centre). Scatter draws over the track's box retry until they land on it, so the
		approved counts stand on the track's own ground on any layout (2026-11-26 re-fit)."""
		global _OWNERS
		if _OWNERS is None:
			import chain

			_OWNERS = roadframe.Owners(chain.build())
		return _OWNERS.owner(x, z) == self.track["Number"]

	def heading(self, d):
		"""Roblox heading of the road at d (0 = facing -Z); a hand-set turn is stored relative to it."""
		return roadframe.heading(self.wps, d)

	def road(self, pal):
		"""Road ribbon, edge walls and the checkpoint apron, from the track's palette (game colours)."""
		w, n = self.width, len(self.wps)
		bm = bmesh.new()
		top_l, top_r = [], []
		for i in range(n):
			p, right, _ = self.at(self._cum[i])
			for side, store in ((-1, top_l), (1, top_r)):
				q = p + right * (side * w / 2)
				store.append(bm.verts.new(rb(q.x, p.y, q.z)))
		for i in range(n - 1):
			bm.faces.new((top_l[i], top_r[i], top_r[i + 1], top_l[i + 1]))
		bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
		me = bpy.data.meshes.new("W2_%s_Road" % self.biome)
		bm.to_mesh(me)
		bm.free()
		me.materials.append(self.mat(pal.get("Road", "777777"), 0.9))
		ob = bpy.data.objects.new(me.name, me)
		sol = ob.modifiers.new("Thick", "SOLIDIFY")
		sol.thickness = 2
		self.col.objects.link(ob)
		# Walls: low strips along both edges; centre dashes in the Line colour
		wall = self.prop("Wall", [("box", (2, 5, 12.5), (0, 2.5, 0), pal.get("Wall", "DDDDDD"))])
		dash = self.prop("Dash", [("box", (1, 0.1, 6), (0, 0.05, 0), pal.get("Line", "FFFFFF"), {"emit": 0.3})])
		d = 0.0
		while d < self.length - 60:
			for side in (-1, 1):
				pos, yaw = self.beside(d, side * (w / 2 + 1), 1.0)
				self.place("Wall", pos, yaw)
			if int(d / 12) % 2 == 0:
				pos, yaw = self.beside(d, 0, 1.0)
				self.place("Dash", pos, yaw)
			d += 12
		# Checkpoint apron (last 60 studs, 30 each side) and the WinPad on the left
		self.prop("Apron", [("box", (w + 60, 0.2, 60), (0, 0.1, 0), pal.get("Checkpoint", "AAAAAA"), {"emit": 0.15})])
		pos, yaw = self.beside(self.length - 30, 0, 1.0)
		self.place("Apron", pos, yaw)
		self.prop("WinPad", [("box", (10, 0.6, 10), (0, 0.3, 0), "FFCD46", {"emit": 0.8})])
		pos, yaw = self.beside(self.length - 30, -24, 1.0)
		self.place("WinPad", pos, yaw)

	def ground(self, color, margin=400, rough=1.0, y=-1.0):
		lo, hi = self.lo, self.hi
		size = max(hi.x - lo.x, hi.z - lo.z) + margin * 2
		c = (lo + hi) / 2
		h = size / 2
		me = bpy.data.meshes.new("W2_%s_Ground" % self.biome)
		me.from_pydata([(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)], [], [(0, 1, 2, 3)])
		me.materials.append(self.mat(color, rough))
		ob = bpy.data.objects.new(me.name, me)
		ob.location = rb(c.x, y, c.z)
		self.col.objects.link(ob)
		return ob

	# --- scatter ---
	def along(self, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True):
		"""Every `every` studs, at each signed offset from the centre line, a random prop of `names`."""
		end = self.length - 70 if end is None else end
		d = start
		while d < end:
			for off in offsets:
				o = off + self.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
				pos, yaw = self.beside(d + self.rng.uniform(-jitter, jitter), o)
				if not self.clear_of_road(pos[0], pos[2], min(abs(o) - 1, 24)):
					continue  # another lap of the road runs here
				if face_road:
					yaw += math.pi / 2 if off > 0 else -math.pi / 2  # turn -Z from along the road to face it
				else:
					yaw = self.rng.uniform(0, math.tau)
				self.place(self.rng.choice(names), pos, yaw, self.rng.uniform(*scale))
			d += every

	def clear_of_road(self, x, z, clearance):
		p = Vector((x, 0, z))
		step = max(1, len(self.wps) // 600)
		return all((Vector((w.x, 0, w.z)) - p).length > clearance for w in self.wps[::step])

	def field(self, count, names, clearance, margin=300, scale=(1.0, 1.0)):
		"""`count` props at random over the track's area, never within `clearance` of the road."""
		placed, tries = 0, 0
		while placed < count and tries < count * 200:  # most of a wide layout's box is other tracks' ground
			tries += 1
			x = self.rng.uniform(self.lo.x - margin, self.hi.x + margin)
			z = self.rng.uniform(self.lo.z - margin, self.hi.z + margin)
			if self.owns(x, z) and self.clear_of_road(x, z, clearance):
				self.place(self.rng.choice(names), (x, -1.0, z), self.rng.uniform(0, math.tau), self.rng.uniform(*scale))
				placed += 1

	# --- sky, light, shots ---
	def sky(self, stops, strength=1.0, sun=None, fog=None):
		"""stops: [(position 0..1 from horizon up, hex)], sun: (energy, hex, elevation deg, azimuth deg)."""
		scene = bpy.context.scene
		world = bpy.data.worlds.new("Sky_" + self.biome)
		world.use_nodes = True
		nt = world.node_tree
		bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
		tc = nt.nodes.new("ShaderNodeTexCoord")
		sep = nt.nodes.new("ShaderNodeSeparateXYZ")
		ramp = nt.nodes.new("ShaderNodeValToRGB")
		nt.links.new(tc.outputs["Generated"], sep.inputs[0])
		half = nt.nodes.new("ShaderNodeMath")  # view Z runs -1..1; the ramp's 0..1 needs z * 0.5 + 0.5
		half.operation = "MULTIPLY_ADD"
		half.inputs[1].default_value = 0.5
		half.inputs[2].default_value = 0.5
		nt.links.new(sep.outputs["Z"], half.inputs[0])
		nt.links.new(half.outputs[0], ramp.inputs["Fac"])
		cr = ramp.color_ramp
		first, *rest = stops
		cr.elements[0].position, cr.elements[0].color = 0.5 + first[0] / 2, hexcol(first[1])
		cr.elements[1].position, cr.elements[1].color = 0.5 + rest[-1][0] / 2, hexcol(rest[-1][1])
		for pos, col in rest[:-1]:
			e = cr.elements.new(0.5 + pos / 2)
			e.color = hexcol(col)
		nt.links.new(ramp.outputs[0], bg.inputs["Color"])
		bg.inputs["Strength"].default_value = strength
		if fog:
			density, col = fog
			vol = nt.nodes.new("ShaderNodeVolumePrincipled")
			vol.inputs["Density"].default_value = density
			vol.inputs["Color"].default_value = hexcol(col)
			out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
			nt.links.new(vol.outputs[0], out.inputs["Volume"])
		scene.world = world
		if sun:
			energy, col, elev, azim = sun
			light = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
			light.data.energy = energy
			light.data.color = hexcol(col)[:3]
			light.data.angle = math.radians(3)
			light.rotation_euler = (math.radians(90 - elev), 0, math.radians(azim))
			self.col.objects.link(light)

	def light(self, pos, color, energy=2000, radius=4):
		ob = bpy.data.objects.new("Lamp", bpy.data.lights.new("Lamp", "POINT"))
		ob.data.energy = energy
		ob.data.color = hexcol(color)[:3]
		ob.data.shadow_soft_size = radius
		ob.location = rb(*pos)
		self.col.objects.link(ob)
		return ob
