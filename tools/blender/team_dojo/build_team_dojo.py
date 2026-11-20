"""Team Select night-dojo clean plate (goal team-dojo, d1).

Builds the whole scene from an empty file and renders the backdrop:
    blender -b --factory-startup -P build_team_dojo.py -- [--variant main|alt] [--out PATH] [--scale 1.0]

Low-poly, flat-shaded hall: crimson torii centred at the back, shoji walls lit blue-violet by
moonlight, hanging paper lanterns, stone lanterns along the side walls, one sakura tree per side,
glossy dark plank floor with a pink glow pooled where the centre altar goes.
No stage, pedestals, characters or UI: the game draws those on top.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "ui", "team_dojo"))

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def arg(name, default):
	return argv[argv.index(name) + 1] if name in argv else default


VARIANT = arg("--variant", "main")
OUT = arg("--out", os.path.join(OUT_DIR, "Backdrop.png" if VARIANT == "main" else "Backdrop_alt.png"))
SCALE = float(arg("--scale", "1.0"))

random.seed(7)

# ---------------------------------------------------------------- reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COL = scene.collection


# ---------------------------------------------------------------- materials
def mat(name, color, rough=0.6, emit=None, strength=0.0, metal=0.0):
	m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
	m.use_nodes = True
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	b.inputs["Base Color"].default_value = (*color, 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if emit:
		b.inputs["Emission Color"].default_value = (*emit, 1)
		b.inputs["Emission Strength"].default_value = strength
	return m


M = {
	"wood": mat("DarkWood", (0.09, 0.018, 0.016), 0.55),
	"wood2": mat("DarkWood2", (0.13, 0.03, 0.022), 0.5),
	"beam": mat("CeilBeam", (0.14, 0.03, 0.025), 0.6),
	"lattice": mat("Lattice", (0.018, 0.006, 0.008), 0.6),
	"pane": mat("ShojiPane", (0.1, 0.08, 0.25), 0.8, (0.22, 0.16, 0.85), 0.9),
	"pane2": mat("ShojiPaneDim", (0.08, 0.06, 0.2), 0.8, (0.25, 0.14, 0.75), 0.55),
	"torii": mat("ToriiRed", (0.55, 0.035, 0.025), 0.45, (0.6, 0.02, 0.01), 0.18),
	"kasagi": mat("ToriiBlack", (0.025, 0.010, 0.012), 0.4),
	"plaque": mat("Plaque", (0.02, 0.008, 0.01), 0.35),
	"gold": mat("Gold", (0.8, 0.45, 0.12), 0.3, (1.0, 0.5, 0.15), 0.6, metal=0.8),
	"paper": mat("LanternPaper", (0.6, 0.1, 0.01), 0.7, (1.0, 0.16, 0.01), 2.2),
	"cap": mat("LanternCap", (0.02, 0.01, 0.01), 0.5),
	"stone": mat("Stone", (0.11, 0.07, 0.08), 0.85),
	"stonelight": mat("StoneLight", (0.6, 0.12, 0.01), 0.7, (1.0, 0.18, 0.01), 2.6),
	"trunk": mat("Trunk", (0.04, 0.016, 0.018), 0.8),
	"blossom": mat("Blossom", (0.8, 0.06, 0.3), 0.7, (0.95, 0.1, 0.42), 0.45),
	"blossom2": mat("Blossom2", (0.95, 0.18, 0.5), 0.7, (1.0, 0.25, 0.58), 0.6),
	"blossom3": mat("Blossom3", (0.55, 0.03, 0.2), 0.7, (0.7, 0.04, 0.25), 0.3),
	"plank": [
		mat("Plank0", (0.16, 0.03, 0.02), 0.14),
		mat("Plank1", (0.2, 0.045, 0.028), 0.12),
		mat("Plank2", (0.12, 0.022, 0.018), 0.16),
	],
	"groove": mat("Groove", (0.01, 0.003, 0.003), 0.6),
	"petal": mat("Petal", (1.0, 0.5, 0.7), 0.6, (1.0, 0.45, 0.7), 1.2),
}


# ---------------------------------------------------------------- mesh kit
class Kit:
	"""Accumulates flat-shaded faces into one mesh object."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.mats = []

	def _mi(self, m):
		if m not in self.mats:
			self.mats.append(m)
		return self.mats.index(m)

	def poly(self, verts, faces, m):
		vs = [self.bm.verts.new(v) for v in verts]
		mi = self._mi(m)
		for f in faces:
			face = self.bm.faces.new([vs[i] for i in f])
			face.material_index = mi

	def box(self, c, s, m, rz=0.0):
		cx, cy, cz = c
		hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
		cs, sn = math.cos(rz), math.sin(rz)
		v = []
		for z in (-hz, hz):
			for x, y in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
				v.append((cx + x * cs - y * sn, cy + x * sn + y * cs, cz + z))
		f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
		self.poly(v, f, m)

	def cyl(self, c, r, h, m, n=10, r2=None, caps=True):
		r2 = r if r2 is None else r2
		cx, cy, cz = c
		v = []
		for z, rr in ((cz, r), (cz + h, r2)):
			for i in range(n):
				a = 2 * math.pi * i / n
				v.append((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
		f = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
		if caps:
			f += [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
		self.poly(v, f, m)

	def beam(self, a, b, w, m, n=5):
		a, b = Vector(a), Vector(b)
		d = (b - a).normalized()
		up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
		u = d.cross(up).normalized()
		vv = d.cross(u).normalized()
		v = []
		for p, ww in ((a, w), (b, w * 0.7)):
			for i in range(n):
				t = 2 * math.pi * i / n
				v.append(tuple(p + (u * math.cos(t) + vv * math.sin(t)) * ww))
		f = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
		f += [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
		self.poly(v, f, m)

	def blob(self, c, r, m, squash=0.75):
		tmp = bmesh.new()
		bmesh.ops.create_icosphere(tmp, subdivisions=1, radius=r)
		for vtx in tmp.verts:
			j = 1 + random.uniform(-0.18, 0.18)
			vtx.co = Vector((vtx.co.x * j + c[0], vtx.co.y * j + c[1], vtx.co.z * j * squash + c[2]))
		self.poly([vtx.co[:] for vtx in tmp.verts], [[vv.index for vv in f.verts] for f in tmp.faces], m)
		tmp.free()

	def bent_beam(self, cx, cy, cz, length, h, d, lift, m, n=20, end_taper=0.0):
		"""Box beam along X whose ends curve upward (torii kasagi)."""
		v = []
		for i in range(n + 1):
			t = i / n * 2 - 1
			x = cx + t * length / 2
			zl = cz + lift * abs(t) ** 3.2
			hh = h * (1 - end_taper * abs(t) ** 4)
			for y, z in ((-d / 2, 0), (d / 2, 0), (d / 2, hh), (-d / 2, hh)):
				v.append((x, cy + y, zl + z + (0.12 * abs(t) ** 3 if z else 0)))
		f = []
		for i in range(n):
			a, b = i * 4, (i + 1) * 4
			for k in range(4):
				f.append((a + k, b + k, b + (k + 1) % 4, a + (k + 1) % 4))
		f.append((3, 2, 1, 0))
		f.append(tuple(n * 4 + k for k in range(4)))
		self.poly(v, f, m)

	def build(self):
		me = bpy.data.meshes.new(self.name)
		bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
		self.bm.to_mesh(me)
		self.bm.free()
		for m in self.mats:
			me.materials.append(m)
		for p in me.polygons:
			p.use_smooth = False
		ob = bpy.data.objects.new(self.name, me)
		COL.objects.link(ob)
		return ob


def bevel(ob, w=0.03):
	mod = ob.modifiers.new("Bevel", "BEVEL")
	mod.width = w
	mod.segments = 1
	mod.limit_method = "ANGLE"


# ---------------------------------------------------------------- hall dimensions
HW = 11.0  # half width (side walls at x = +-HW)
BACK = 13.0  # back wall y
FRONT = -14.0
CEIL = 9.0
TORII_Y = 7.5
PIL_X = 3.25


# ---------------------------------------------------------------- floor
def build_floor():
	k = Kit("Floor")
	k.box((0, 0, -0.06), (2 * HW + 2, BACK - FRONT + 2, 0.1), M["groove"])
	w = 0.62
	x = -HW
	while x < HW:
		y = FRONT
		while y < BACK:
			ln = random.uniform(3.0, 6.0)
			ln = min(ln, BACK - y)
			k.box((x + w / 2, y + ln / 2, 0.0), (w - 0.035, ln - 0.04, 0.04), random.choice(M["plank"]))
			y += ln
		x += w
	return k.build()


# ---------------------------------------------------------------- shoji wall panel
def shoji(k, origin, along, width, height, z0, cols, rows, pane):
	"""Lit pane with a dark lattice in front. along: unit vector of the wall run; normal faces the hall."""
	ox, oy = origin
	ax, ay = along
	nx, ny = ay, -ax  # hall-facing normal (right of the run direction)

	def P(s, z, off):
		return (ox + ax * s + nx * off, oy + ay * s + ny * off, z)

	# pane
	k.poly([P(0, z0, 0), P(width, z0, 0), P(width, z0 + height, 0), P(0, z0 + height, 0)], [(0, 1, 2, 3)], pane)
	rz = math.atan2(ay, ax)
	t = 0.07
	# verticals
	for i in range(cols + 1):
		s = width * i / cols
		tt = t * (2.2 if i in (0, cols) else 1)
		k.box(P(s, z0 + height / 2, 0.05), (tt, 0.08, height), M["lattice"], rz)
	for j in range(rows + 1):
		z = z0 + height * j / rows
		tt = t * (2.2 if j in (0, rows) else 1)
		k.box(P(width / 2, z, 0.05), (width, 0.08, tt), M["lattice"], rz)


def build_walls():
	k = Kit("Walls")
	# back wall: dark wood face behind shoji, shoji bays either side of (and behind) the torii
	k.box((0, BACK + 0.2, CEIL / 2), (2 * HW + 1, 0.3, CEIL + 1), M["wood"])
	bays = [(-HW, -4.6), (-4.6, -1.6), (-1.6, 1.6), (1.6, 4.6), (4.6, HW)]
	for a, b in bays:
		shoji(k, (a + 0.15, BACK), (1, 0), b - a - 0.3, 5.6, 1.0, max(3, round((b - a) / 0.9)), 7, M["pane"])
		k.box((a, BACK - 0.1, CEIL / 2), (0.45, 0.45, CEIL), M["wood2"])
	k.box((HW, BACK - 0.1, CEIL / 2), (0.45, 0.45, CEIL), M["wood2"])
	k.box((0, BACK - 0.15, 0.5), (2 * HW, 0.3, 1.0), M["wood2"])  # wainscot
	k.box((0, BACK - 0.15, 6.85), (2 * HW, 0.35, 0.5), M["wood2"])  # head rail
	# side walls
	for sx in (-1, 1):
		x = sx * HW
		k.box((x + sx * 0.2, (BACK + FRONT) / 2, CEIL / 2), (0.3, BACK - FRONT, CEIL + 1), M["wood"])
		y = BACK
		while y > FRONT + 1:
			y2 = y - 3.2
			# run direction so the normal faces the hall
			if sx < 0:
				shoji(k, (x, y2 + 0.15), (0, 1), 2.9, 5.0, 1.0, 4, 7, M["pane2"])
			else:
				shoji(k, (x, y - 0.15), (0, -1), 2.9, 5.0, 1.0, 4, 7, M["pane2"])
			k.box((x - sx * 0.1, y, CEIL / 2), (0.45, 0.45, CEIL), M["wood2"])
			y = y2
		k.box((x - sx * 0.1, (BACK + FRONT) / 2, 0.5), (0.3, BACK - FRONT, 1.0), M["wood2"])
		k.box((x - sx * 0.1, (BACK + FRONT) / 2, 6.3), (0.35, BACK - FRONT, 0.5), M["wood2"])
	ob = k.build()
	bevel(ob, 0.015)
	return ob


def build_ceiling():
	k = Kit("Ceiling")
	k.box((0, 0, CEIL + 0.3), (2 * HW + 1, BACK - FRONT + 2, 0.3), M["wood"])
	y = BACK - 1.0
	while y > FRONT:
		k.box((0, y, CEIL - 0.25), (2 * HW, 0.5, 0.6), M["beam"])
		y -= 2.6
	for x in (-HW + 0.4, -6.5, -2.2, 2.2, 6.5, HW - 0.4):
		k.box((x, 0, CEIL - 0.7), (0.45, BACK - FRONT, 0.45), M["beam"])
	# rafters between beams
	for x in [i * 1.1 - HW for i in range(int(2 * HW / 1.1) + 1)]:
		k.box((x, 0, CEIL + 0.05), (0.14, BACK - FRONT, 0.14), M["wood2"])
	ob = k.build()
	bevel(ob, 0.03)
	return ob


# ---------------------------------------------------------------- torii
def build_torii(scale=1.0):
	k = Kit("Torii")
	s = scale
	y = TORII_Y
	px = PIL_X * s
	H = 7.6 * s
	for sx in (-1, 1):
		k.cyl((sx * px, y, 0), 0.42 * s, H - 0.2, M["torii"], n=12, r2=0.36 * s)
		k.cyl((sx * px, y, 0), 0.55 * s, 0.55, M["kasagi"], n=12)  # black base (kamaki)
	# nuki (lower beam)
	k.box((0, y, H - 1.75 * s), (2 * px + 2.0 * s, 0.38 * s, 0.42 * s), M["torii"])
	# shimaki under the kasagi (red), then black kasagi with curved ends
	k.bent_beam(0, y, H - 0.65 * s, 2 * px + 3.4 * s, 0.4 * s, 0.6 * s, 0.35 * s, M["torii"])
	k.bent_beam(0, y, H - 0.27 * s, 2 * px + 4.4 * s, 0.38 * s, 0.75 * s, 0.6 * s, M["kasagi"])
	# gakuzuka (centre strut) and plaque
	k.box((0, y, H - 1.2 * s), (0.35 * s, 0.32 * s, 1.1 * s), M["torii"])
	k.box((0, y - 0.2, H - 1.2 * s), (1.05 * s, 0.12, 0.85 * s), M["plaque"])
	k.box((0, y - 0.27, H - 1.2 * s), (0.85 * s, 0.03, 0.65 * s), M["gold"])
	k.box((0, y - 0.28, H - 1.2 * s), (0.7 * s, 0.03, 0.5 * s), M["plaque"])
	ob = k.build()
	bevel(ob, 0.04)
	return ob


# ---------------------------------------------------------------- lanterns
def hanging_lantern(k, x, y, z, r, h, lights, warm=1.0):
	k.cyl((x, y, z), r, h, M["paper"], n=10)
	k.cyl((x, y, z - 0.08), r * 0.82, 0.12, M["cap"], n=10)
	k.cyl((x, y, z + h - 0.04), r * 0.82, 0.12, M["cap"], n=10)
	for i in range(4):  # ribs
		k.cyl((x, y, z + h * (i + 1) / 5 - 0.015), r * 1.01, 0.03, M["cap"], n=10, caps=False)
	k.box((x, y, z + h + 0.15), (0.1, 0.1, 0.25), M["cap"])
	k.box((x, y, (z + h + CEIL) / 2), (0.03, 0.03, CEIL - z - h), M["cap"])
	k.box((x, y, z - 0.25), (0.05, 0.05, 0.3), M["cap"])
	lights.append(((x, y, z + h / 2), 260 * r * warm, (1.0, 0.45, 0.15), r))


def stone_lantern(k, x, y, lights):
	k.box((x, y, 0.12), (0.7, 0.7, 0.24), M["stone"])
	k.box((x, y, 0.55), (0.28, 0.28, 0.7), M["stone"])
	k.box((x, y, 0.95), (0.6, 0.6, 0.12), M["stone"])
	k.box((x, y, 1.23), (0.46, 0.46, 0.45), M["stonelight"])
	for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
		k.box((x + dx * 0.21, y + dy * 0.21, 1.23), (0.08, 0.08, 0.45), M["stone"])
	k.poly(
		[(x - 0.48, y - 0.48, 1.45), (x + 0.48, y - 0.48, 1.45), (x + 0.48, y + 0.48, 1.45), (x - 0.48, y + 0.48, 1.45), (x, y, 1.8)],
		[(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)],
		M["stone"],
	)
	k.box((x, y, 1.86), (0.1, 0.1, 0.14), M["stone"])
	lights.append(((x, y, 1.23), 60, (1.0, 0.5, 0.18), 0.2))


def build_lanterns(variant):
	k = Kit("Lanterns")
	lights = []
	warm = 1.35 if variant == "alt" else 1.0
	# big hanging lanterns high left/right, smaller pairs further back
	for sx in (-1, 1):
		hanging_lantern(k, sx * 8.0, -3.0, 5.5, 0.6, 1.25, lights, warm)
		hanging_lantern(k, sx * 6.4, 6.0, 5.6, 0.42, 0.95, lights, warm)
		hanging_lantern(k, sx * 9.2, 9.5, 5.4, 0.38, 0.85, lights, warm)
		for y in (-3.0, 2.0, 7.0, 11.4):
			stone_lantern(k, sx * (HW - 0.9), y, lights)
	ob = k.build()
	bevel(ob, 0.02)
	for i, (p, power, c, r) in enumerate(lights):
		ld = bpy.data.lights.new(f"LanternLight{i}", "POINT")
		ld.energy = power
		ld.color = c
		ld.shadow_soft_size = r
		ld.use_shadow = r > 0.3  # stone lantern lights stay shadowless: keeps the Eevee shadow pool in budget
		lo = bpy.data.objects.new(f"LanternLight{i}", ld)
		lo.location = p
		COL.objects.link(lo)
	return ob


# ---------------------------------------------------------------- sakura
def build_sakura(sx):
	k = Kit(f"Sakura{'L' if sx < 0 else 'R'}")
	bx, by = sx * 8.4, 2.6
	top = Vector((bx - sx * 0.3, by, 3.3))
	k.beam((bx, by, 0), top, 0.32, M["trunk"], n=6)
	k.cyl((bx, by, 0), 0.5, 0.25, M["trunk"], n=6, r2=0.3)
	tips = []
	for i in range(6):
		a = (i / 6) * 2 * math.pi + 0.4
		reach = random.uniform(1.1, 1.8)
		tip = top + Vector((math.cos(a) * reach, math.sin(a) * reach * 0.8, random.uniform(0.6, 1.8)))
		k.beam(top, tip, 0.15, M["trunk"], n=5)
		tips.append(tip)
	tips.append(top + Vector((0, 0, 2.0)))
	bl = [M["blossom"], M["blossom2"], M["blossom3"]]
	for t in tips:
		for _ in range(8):
			c = t + Vector((random.uniform(-0.8, 0.8), random.uniform(-0.6, 0.6), random.uniform(-0.3, 0.6)))
			k.blob(c, random.uniform(0.3, 0.55), random.choice(bl))
	ob = k.build()
	bevel(ob, 0.02)
	return ob


def build_petals():
	k = Kit("Petals")
	for _ in range(36):
		c = Vector((random.uniform(-9, 9), random.uniform(-4, 10), random.uniform(1.0, 7.0)))
		if abs(c.x) < 3.5 and c.z < 4.5:
			continue  # keep the altar area clean
		a = random.uniform(0, math.pi)
		s = 0.09
		k.poly(
			[c + Vector((math.cos(a) * s, 0, math.sin(a) * s)), c + Vector((0, s * 0.6, 0)), c - Vector((math.cos(a) * s, 0, math.sin(a) * s)), c - Vector((0, s * 0.6, 0))],
			[(0, 1, 2, 3)],
			M["petal"],
		)
	return k.build()


# ---------------------------------------------------------------- lights, world, camera, render
def add_light(name, kind, loc, energy, color, rot=None, size=None, spot=None, blend=0.6):
	ld = bpy.data.lights.new(name, kind)
	ld.energy = energy
	ld.color = color
	if size is not None:
		if kind == "AREA":
			ld.size = size
		else:
			ld.shadow_soft_size = size
	if spot is not None:
		ld.spot_size = spot
		ld.spot_blend = blend
	ob = bpy.data.objects.new(name, ld)
	ob.location = loc
	if rot:
		ob.rotation_euler = rot
	COL.objects.link(ob)
	return ob


def setup_lights(variant):
	# pink/red glow pooled where the centre altar stands
	pool = add_light("StagePool", "SPOT", (0, 3.5, 8.7), 12000 if variant == "main" else 14000, (1.0, 0.18, 0.45), spot=math.radians(38), blend=1.0, size=1.5)
	pool.data.use_shadow = False
	# crimson wash on the torii from the front
	add_light("ToriiWash", "SPOT", (0, -2, 7.5), 1800, (1.0, 0.18, 0.12), rot=(math.radians(65), 0, 0), spot=math.radians(50), blend=0.8, size=1.0)
	# moonlight spilling in through the shoji: cool fills from the walls
	add_light("MoonBack", "AREA", (0, BACK - 0.6, 4.0), 350, (0.4, 0.3, 1.0), rot=(math.radians(90), 0, 0), size=20)
	for sx in (-1, 1):
		add_light(f"MoonSide{sx}", "AREA", (sx * (HW - 0.5), 0, 4.0), 250, (0.45, 0.3, 1.0), rot=(0, math.radians(90 * sx), 0), size=18)
	# ceiling bounce so beams read in red
	add_light("CeilWarm", "AREA", (0, 2, 5.0), 3000, (1.0, 0.15, 0.12), rot=(math.radians(180), 0, 0), size=18)
	# warm red fill over the whole floor
	add_light("FloorWarm", "AREA", (0, 0, 8.0), 900, (1.0, 0.2, 0.15), size=16)


def setup_world():
	w = bpy.data.worlds.new("NightWorld")
	scene.world = w
	w.use_nodes = True
	bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
	bg.inputs["Color"].default_value = (0.02, 0.004, 0.012, 1)
	bg.inputs["Strength"].default_value = 1.0


def setup_camera(variant):
	cd = bpy.data.cameras.new("Cam")
	cd.lens = 24 if variant == "main" else 25
	cd.sensor_width = 36
	cam = bpy.data.objects.new("Cam", cd)
	cam.location = (0, -10.5, 3.3)
	target = Vector((0, 8.0, 2.25 if variant == "main" else 2.9))
	cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
	COL.objects.link(cam)
	scene.camera = cam


def setup_render():
	r = scene.render
	r.engine = "BLENDER_EEVEE"
	r.resolution_x = 2560
	r.resolution_y = 1240
	r.resolution_percentage = int(100 * SCALE)
	r.image_settings.file_format = "PNG"
	r.image_settings.color_mode = "RGB"
	e = scene.eevee
	e.taa_render_samples = 64
	e.use_raytracing = True
	e.use_shadows = True
	try:
		e.shadow_pool_size = "1024"
	except TypeError:
		pass
	try:
		e.ray_tracing_options.resolution_scale = "1"
	except (TypeError, AttributeError):
		pass
	try:
		scene.view_settings.view_transform = "AgX"
		scene.view_settings.look = "AgX - Punchy"
	except TypeError:
		pass
	scene.view_settings.exposure = 0.2
	# bloom via compositor glare
	ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
	scene.compositing_node_group = ng
	rl = ng.nodes.new("CompositorNodeRLayers")
	g = ng.nodes.new("CompositorNodeGlare")
	g.inputs["Type"].default_value = "Bloom"
	g.inputs["Quality"].default_value = "High"
	g.inputs["Threshold"].default_value = 0.9
	g.inputs["Strength"].default_value = 0.55
	g.inputs["Size"].default_value = 0.7
	out = ng.nodes.new("NodeGroupOutput")
	ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
	ng.links.new(rl.outputs["Image"], g.inputs["Image"])
	ng.links.new(g.outputs["Image"], out.inputs[0])
	r.use_compositing = True


def main():
	build_floor()
	build_walls()
	build_ceiling()
	build_torii(1.05 if VARIANT == "alt" else 1.0)
	build_lanterns(VARIANT)
	build_sakura(-1)
	build_sakura(1)
	build_petals()
	setup_lights(VARIANT)
	setup_world()
	setup_camera(VARIANT)
	setup_render()
	dg = bpy.context.evaluated_depsgraph_get()
	tris = sum(sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons) for o in scene.objects if o.type == "MESH")
	print(f"OBJECTS {len(scene.objects)} MESHES {sum(o.type == 'MESH' for o in scene.objects)} TRIS {tris}")
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	r = scene.render
	r.filepath = OUT
	bpy.ops.render.render(write_still=True)
	print("WROTE", OUT, r.resolution_x * r.resolution_percentage // 100, r.resolution_y * r.resolution_percentage // 100)


main()
