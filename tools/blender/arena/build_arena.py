# Blender draft of the boss sky arena (design doc 4.37, BOSS_EVENT_SPEC Arena). Owner review only: nothing here ships. Headless:
#   Blender -b --factory-startup --python tools/blender/arena/build_arena.py -- [shot ...]
# 1 Blender unit = 1 stud, ring centre at the origin, track top at z = 1200 (Roblox y). Runs counter-clockwise from above.
# Writes build/arena/arena_draft.blend and review renders to assets/arena_draft/. Prints tris and the scale measurements.
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import build_avatar  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "arena_draft")
BUILD = os.path.join(ROOT, "build", "arena")
CHARS = os.path.join(ROOT, "assets", "characters_avatar")
BOSS_BLEND = os.path.join(CHARS, "boss_raga", "boss_raga.blend")
RUNNER_BLEND = os.path.join(CHARS, "db_hero", "db_hero.blend")

R_IN, WIDTH, LANES = 850.0, 80.0, 7  # fixed by BOSS_EVENT_SPEC
R_OUT = R_IN + WIDTH
LANE_W = WIDTH / LANES
Z = 1200.0  # spec: y about 1,200
BOSS_H = 0.66 * R_IN  # head top
BOSS_SCALE = 87.1  # owner: studs per model unit, head top 560, wheel top 804.4. Model feet on z = 0, centred on its own origin
RUNNER_H = 5.75
N = 144  # ring segments: 39 studs each on lane 4, a chunky but round read
TH0 = math.radians(-120)  # where the gameplay camera sits; roughly in front of the boss
GAME_YAW = 55  # owner: the event camera turns inward. Degrees from the running direction: see the sweep in measure()
GAME_PITCH = 12
RUNNER_OFFSETS = (70, 95, 50, 110, 60, 85, 45)  # studs ahead of the near runner, one per lane 1 to 7
SECTOR = 60  # degrees between arches
ARCH_START = 15

rng = random.Random(7)
PAL = {
	"marble": "#F3EFE6", "marble2": "#E6DFCF", "marble3": "#DDD6C8", "laneA": "#F7F3EA", "laneA2": "#EEE8DB", "laneB": "#DCD5C6", "laneB2": "#D2CBBA",
	"gold": "#E8B23C", "gold2": "#C9922B", "cloud": "#FFFFFF", "cloud2": "#EAF1FA", "cloud3": "#D5E2F2", "boss": "#8A8C92", "boss2": "#74767C", "label": "#D93A2B",
}
_mats = {}


def rgb(h):
	def lin(c):
		c /= 255
		return c / 12.92 if c < 0.04045 else ((c + 0.055) / 1.055) ** 2.4

	return tuple(lin(int(h[i : i + 2], 16)) for i in (1, 3, 5)) + (1,)


def mat(name):
	if name not in _mats:
		m = bpy.data.materials.new(name)
		bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Base Color"].default_value = rgb(PAL[name])
		bsdf.inputs["Roughness"].default_value = 0.85
		_mats[name] = m
	return _mats[name]


# Hard-faceted mesh builder, same shape as plaza/build_plaza.py's M: that file runs its whole build on import, so it cannot be imported.
class M:
	def __init__(self, name):
		self.name = name
		self.v, self.f, self.fm, self.mats = [], [], [], []

	def face(self, pts, material):
		if material not in self.mats:
			self.mats.append(material)
		i = len(self.v)
		self.v.extend(Vector(p) for p in pts)
		self.f.append(tuple(range(i, i + len(pts))))
		self.fm.append(self.mats.index(material))

	def box(self, size, c, material):
		sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
		cv = Vector(c)
		p = [cv + Vector((a * sx, b * sy, d * sz)) for a in (-1, 1) for b in (-1, 1) for d in (-1, 1)]
		for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
			self.face([p[k] for k in q], material)

	def beam(self, a, b, w, material):
		a, b = Vector(a), Vector(b)
		d = (b - a).normalized()
		u = d.orthogonal().normalized()
		v = d.cross(u)
		ring = lambda c: [c + (u * math.cos((k + 0.5) / 4 * math.tau) + v * math.sin((k + 0.5) / 4 * math.tau)) * w / 2 for k in range(4)]
		ra, rb = ring(a), ring(b)
		for k in range(4):
			self.face([ra[k], ra[(k + 1) % 4], rb[(k + 1) % 4], rb[k]], material)
		self.face(ra[::-1], material)
		self.face(rb, material)

	def cyl(self, r, h, c, material, n=8, r2=None):
		cx, cy, cz = c
		r2 = r if r2 is None else r2
		lo = [(cx + r * math.cos(k / n * math.tau), cy + r * math.sin(k / n * math.tau), cz) for k in range(n)]
		hi = [(cx + r2 * math.cos(k / n * math.tau), cy + r2 * math.sin(k / n * math.tau), cz + h) for k in range(n)]
		for k in range(n):
			self.face([lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]], material)
		self.face(lo[::-1], material)
		self.face(hi, material)

	def blob(self, r, c, material, squash=0.75, jitter=0.22):
		bm = bmesh.new()
		bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1)
		cv = Vector(c)
		seen = {}
		for vert in bm.verts:
			seen[vert.index] = cv + Vector((vert.co.x * r * (1 + rng.uniform(-jitter, jitter)), vert.co.y * r * (1 + rng.uniform(-jitter, jitter)), vert.co.z * r * squash * (1 + rng.uniform(-jitter, jitter))))
		for fa in bm.faces:
			self.face([seen[vt.index] for vt in fa.verts], material)
		bm.free()

	def build(self, parent):
		me = bpy.data.meshes.new(self.name)
		me.from_pydata([tuple(p) for p in self.v], [], self.f)
		for n in self.mats:
			me.materials.append(mat(n))
		for i, poly in enumerate(me.polygons):
			poly.material_index = self.fm[i]
		me.update()
		ob = bpy.data.objects.new(self.name, me)
		parent.objects.link(ob)
		return ob


def tris(ob):
	return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def lane_r(i):
	"""Centre radius of lane i, 1 (inside) to 7 (outside)."""
	return R_IN + (i - 0.5) * LANE_W


def pol(r, a, z=Z):
	return Vector((r * math.cos(a), r * math.sin(a), z))


def tangent(a):
	return Vector((-math.sin(a), math.cos(a), 0))


def loft(m, profile, material, n=N):
	"""A closed ring surface through (r, z) profile points."""
	for (r1, z1), (r2, z2) in zip(profile, profile[1:]):
		for k in range(n):
			a, b = k / n * math.tau, (k + 1) / n * math.tau
			m.face([pol(r1, a, z1), pol(r2, a, z2), pol(r2, b, z2), pol(r1, b, z1)], material)


def arc_box(m, r1, r2, z1, z2, a1, a2, material, segs):
	"""A curved solid block: a stretch of cornice or plinth."""
	for k in range(segs):
		a, b = a1 + (a2 - a1) * k / segs, a1 + (a2 - a1) * (k + 1) / segs
		for (ra, za), (rb, zb) in (((r2, z1), (r2, z2)), ((r2, z2), (r1, z2)), ((r1, z2), (r1, z1)), ((r1, z1), (r2, z1))):
			m.face([pol(ra, a, za), pol(ra, b, za), pol(rb, b, zb), pol(rb, a, zb)], material)
	for a in (a1, a2):
		m.face([pol(r1, a, z1), pol(r2, a, z1), pol(r2, a, z2), pol(r1, a, z2)], material)


# --- The arena ---
def track():
	m = M("ArenaTrack")
	for i in range(1, LANES + 1):
		r1, r2 = R_IN + (i - 1) * LANE_W, R_IN + i * LANE_W
		line = 0.5 if i < LANES else 0
		pair = ("laneA", "laneA2") if i % 2 else ("laneB", "laneB2")
		for k in range(N):
			a, b = k / N * math.tau, (k + 1) / N * math.tau
			m.face([pol(r1, a), pol(r2 - line * 2, a), pol(r2 - line * 2, b), pol(r1, b)], pair[k % 2])
			if line:
				m.face([pol(r2 - line * 2, a), pol(r2, a), pol(r2, b), pol(r2 - line * 2, b)], "gold")
	# Rims: a low kerb on the hole side, a wall and the colonnade plinth outside. All clear of the 80 stud track.
	loft(m, [(R_IN, Z), (R_IN, Z + 2.5)], "marble3")
	loft(m, [(R_IN, Z + 2.5), (R_IN - 2, Z + 2.5)], "gold")
	loft(m, [(R_IN - 2, Z + 2.5), (R_IN - 6, Z + 2.5)], "marble")
	loft(m, [(R_OUT, Z), (R_OUT, Z + 5)], "marble3")
	loft(m, [(R_OUT, Z + 5), (R_OUT + 2, Z + 5)], "gold")
	loft(m, [(R_OUT + 2, Z + 5), (R_OUT + 6, Z + 5), (R_OUT + 6, Z + 3), (R_OUT + 30, Z + 3), (R_OUT + 30, Z - 4)], "marble2")
	# The floating hull
	hull = [(R_OUT + 30, Z - 4), (R_OUT + 24, Z - 16), (R_OUT + 8, Z - 40), (R_IN + 56, Z - 75), (R_IN + 26, Z - 75), (R_IN + 4, Z - 40), (R_IN - 6, Z - 12), (R_IN - 6, Z + 2.5)]
	loft(m, hull[:2], "gold")
	loft(m, hull[1:3], "marble3")
	loft(m, hull[2:4], "marble2")
	loft(m, hull[3:5], "gold2")
	loft(m, hull[4:6], "marble2")
	loft(m, hull[5:7], "marble3")
	loft(m, hull[6:], "marble3")
	return m


def colonnade_bay():
	"""One colonnade stretch on the outer plinth, around +X. Placed by rotating about the ring centre (one asset, many clones)."""
	m = M("ArenaColonnade")
	r, half, h, count = R_OUT + 18, math.radians(8), 62.0, 13
	base = Z + 3
	for k in range(count):
		c = pol(r, -half + 2 * half * k / (count - 1), base)
		m.box((10, 10, 3), (c.x, c.y, base + 1.5), "marble3")
		m.cyl(3.6, h, (c.x, c.y, base + 3), "marble", n=8, r2=3.0)
		m.box((10, 10, 3), (c.x, c.y, base + 3 + h + 1.5), "gold")
	top = base + h + 6
	segs = 12
	arc_box(m, r - 7, r + 7, top, top + 8, -half - 0.01, half + 0.01, "marble2", segs)
	arc_box(m, r - 9, r + 9, top + 8, top + 11, -half - 0.015, half + 0.015, "gold", segs)
	arc_box(m, r - 5, r + 5, top + 11, top + 17, -half + 0.03, half - 0.03, "marble", segs)
	return m


def track_arch():
	"""A triumphal arch over all 7 lanes, around +X. Pylons stand outside the track edges."""
	m = M("ArenaArch")
	r_in, r_out = R_IN - 8, R_OUT + 16
	cr, span = (r_in + r_out) / 2, (r_out - r_in) / 2
	spring = Z + 70
	for r in (r_in, r_out):
		m.box((16, 26, 100), (r, 0, Z + 20), "marble")
		m.box((20, 30, 5), (r, 0, Z + 2.5), "gold")
		m.box((20, 30, 5), (r, 0, spring + 2.5), "gold")
	n = 12
	pts = [Vector((cr - span * math.cos(k / n * math.pi), 0, spring + 5 + span * math.sin(k / n * math.pi) * 0.85)) for k in range(n + 1)]
	for p, q in zip(pts, pts[1:]):
		m.beam(p, q, 15, "marble2")
		m.beam(p + Vector((0, 0, 8)), q + Vector((0, 0, 8)), 5, "gold")
	m.box((13, 20, 22), (cr, 0, pts[n // 2].z + 3), "gold")
	return m


def clones(m, parent, angles):
	"""Build m once, then one more object per angle sharing its mesh. Returns the total tris placed."""
	ob = m.build(parent)
	ob.matrix_world = Matrix.Rotation(angles[0], 4, "Z")
	for a in angles[1:]:
		o = ob.copy()
		o.matrix_world = Matrix.Rotation(a, 4, "Z")
		parent.objects.link(o)
	return tris(ob), len(angles)


DAIS_R = 190  # the feet at the owner's scale reach about 165


def dais():
	m = M("ArenaBossDais")
	m.cyl(DAIS_R, 14, (0, 0, Z - 14), "marble", n=16)
	m.cyl(DAIS_R + 15, 6, (0, 0, Z - 20), "gold", n=16)
	m.cyl(DAIS_R + 15, 40, (0, 0, Z - 60), "marble2", n=16)
	m.cyl(40, 60, (0, 0, Z - 120), "gold2", n=16, r2=DAIS_R + 15)
	return m


def clouds():
	m = M("ArenaClouds")
	base = Z - 720
	rings = [0, 700, 1500, 2600, 4200, 6500, 10000, 16000, 26000]
	n = 48
	height = {}
	for i, r in enumerate(rings):
		for k in range(n):
			height[i, k] = base + (rng.uniform(-70, 70) * (1 + i / 3) if i else 0)  # one centre height: no spike fan
	for i, (r1, r2) in enumerate(zip(rings, rings[1:])):
		for k in range(n):
			a, b, k2 = k / n * math.tau, (k + 1) / n * math.tau, (k + 1) % n
			m.face([pol(r1, a, height[i, k]), pol(r2, a, height[i + 1, k]), pol(r2, b, height[i + 1, k2]), pol(r1, b, height[i, k2])], "cloud")
	for _ in range(170):  # the sea's puffs
		a, r = rng.uniform(0, math.tau), rng.uniform(300, 12000)
		s = rng.uniform(130, 340) * (1 + r / 8000)
		m.blob(s, pol(r, a, base + s * 0.1), "cloud", squash=0.45, jitter=0.2)
	for _ in range(14):  # a few wisps hanging under the ring, so it reads as floating
		a, r = rng.uniform(0, math.tau), rng.uniform(760, 1120)
		m.blob(rng.uniform(50, 110), pol(r, a, Z - rng.uniform(130, 260)), "cloud2", squash=0.45, jitter=0.2)
	return m


def soften(ob):
	"""Welded and smooth shaded, so the cloud sea reads as cloud rather than faceted ice."""
	bm = bmesh.new()
	bm.from_mesh(ob.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
	bm.to_mesh(ob.data)
	bm.free()
	ob.data.shade_smooth()
	return ob


# --- Models ---
def link_tree(ob, coll):
	coll.objects.link(ob)
	for c in ob.children:
		link_tree(c, coll)


def append_model(path, coll):
	"""Every object of a .blend, under one new empty. Keeps its own parenting."""
	with bpy.data.libraries.load(path) as (src, dst):
		dst.objects = list(src.objects)
	root = bpy.data.objects.new(os.path.basename(path), None)
	coll.objects.link(root)
	for o in dst.objects:
		if o:
			coll.objects.link(o)
			if not o.parent:
				o.parent = root
	return root


def tree(ob):
	yield ob
	for c in ob.children:
		yield from tree(c)


def bounds(root):
	bpy.context.view_layer.update()
	pts = [o.matrix_world @ Vector(c) for o in tree(root) if o.type == "MESH" for c in o.bound_box]
	return Vector(min(p[i] for p in pts) for i in range(3)), Vector(max(p[i] for p in pts) for i in range(3))


def model_tris(root):
	return sum(tris(o) for o in tree(root) if o.type == "MESH")


def fit(root, height, pos, yaw):
	"""Scale to height, stand it on pos, turn its -Y front by yaw."""
	lo, hi = bounds(root)
	s = height / (hi.z - lo.z)
	foot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
	root.matrix_world = Matrix.Translation(pos) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(s, 4) @ Matrix.Translation(-foot)


def clone_tree(ob, parent, coll):
	o = ob.copy()  # shares mesh data
	o.parent = parent
	coll.objects.link(o)
	for c in ob.children:
		clone_tree(c, o, coll)
	return o


def stand_in_boss(coll):
	"""shortcut: plain blocks, labelled. Replaced by boss_raga.blend as soon as that file exists."""
	m = M("BossStandIn")
	f = Z
	m.box((80, 90, 230), (-58, 0, f + 115), "boss")
	m.box((80, 90, 230), (58, 0, f + 115), "boss")
	m.box((230, 130, 210), (0, 0, f + 335), "boss2")
	m.box((62, 70, 310), (-150, 0, f + 285), "boss")
	m.box((62, 70, 310), (150, 0, f + 285), "boss")
	m.box((60, 60, 21), (0, 0, f + 450), "boss")
	m.box((100, 100, BOSS_H - 461), (0, 0, f + 461 + (BOSS_H - 461) / 2), "boss2")
	ob = m.build(coll)
	for yaw in (0, math.pi):
		cu = bpy.data.curves.new("BossLabel", "FONT")
		cu.body, cu.size, cu.extrude, cu.align_x, cu.align_y = "STAND-IN", 44, 1.5, "CENTER", "CENTER"
		cu.materials.append(mat("label"))
		t = bpy.data.objects.new("BossLabel", cu)
		t.matrix_world = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Translation((0, -68, f + 345)) @ Matrix.Rotation(math.pi / 2, 4, "X")
		coll.objects.link(t)
	return ob


def add_runners(coll):
	"""db_hero as the runner: its .blend when this checkout has one (gitignored), else built from the repo's own data."""
	if os.path.exists(RUNNER_BLEND):
		src, how = append_model(RUNNER_BLEND, coll), "appended db_hero.blend"
	else:
		src, _ = build_avatar.placed("db_hero", build_avatar.load_data()["db_hero"])
		how = "built db_hero in-process (no .blend in this checkout)"
	per = model_tris(src)
	near = None
	spots = [(lane_r(4), 0)] + [(lane_r(i + 1), off) for i, off in enumerate(RUNNER_OFFSETS)]
	for r, off in spots:
		o = clone_tree(src, None, coll)
		a = TH0 + off / r
		fit(o, RUNNER_H, pol(r, a), a + math.pi)  # front along the running direction
		near = near or o
	for o in tree(src):
		o.hide_render = o.hide_viewport = True
	return near, per, how


# --- World and cameras ---
def setup_world(scene):
	scene.render.engine = "CYCLES"  # EEVEE's shadow maps go blocky over a scene this large
	scene.cycles.samples = 48
	scene.cycles.use_denoising = True
	scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("Heaven")
	nt = world.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	tc = nt.nodes.new("ShaderNodeTexCoord")
	sep = nt.nodes.new("ShaderNodeSeparateXYZ")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	nt.links.new(tc.outputs["Generated"], sep.inputs[0])
	nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
	cr = ramp.color_ramp
	cr.elements[0].position, cr.elements[0].color = 0.0, rgb("#F2F8FF")
	cr.elements[1].position, cr.elements[1].color = 0.6, rgb("#5FA2EC")
	cr.elements.new(0.06).color = rgb("#E2F0FF")
	cr.elements.new(0.25).color = rgb("#A6D2F8")
	nt.links.new(ramp.outputs[0], bg.inputs["Color"])
	# Dim fill light so shadows stay neutral, but the sky itself shows at full brightness
	path = nt.nodes.new("ShaderNodeLightPath")
	boost = nt.nodes.new("ShaderNodeMath")
	boost.operation = "MULTIPLY_ADD"
	boost.inputs[1].default_value, boost.inputs[2].default_value = 0.45, 0.6
	nt.links.new(path.outputs["Is Camera Ray"], boost.inputs[0])
	nt.links.new(boost.outputs[0], bg.inputs["Strength"])
	scene.world = world
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 2.5
	sun.data.color = (1.0, 0.95, 0.85)
	sun.data.angle = math.radians(3)
	sun.rotation_euler = (math.radians(18), 0, math.radians(-40))  # high sun: colonnade shadows stay off all but the outer lane
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.sensor_fit = "VERTICAL"
	cam.data.clip_start = 0.5
	cam.data.clip_end = 60000
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def aim(cam, eye, look, fov):
	eye, look = Vector(eye), Vector(look)
	cam.location = eye
	cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(fov)
	bpy.context.view_layer.update()


def gameplay_pose(yaw_deg, back=20.0, eye_h=8.0, pitch=GAME_PITCH):
	"""A follow camera: back studs behind the near runner, turned yaw_deg inward from the running direction."""
	y = math.radians(yaw_deg)
	run = pol(lane_r(4), TH0)
	inward = -pol(1, TH0, 0)
	d = (tangent(TH0) * math.cos(y) + inward * math.sin(y)).normalized()
	eye = run - d * back + Vector((0, 0, eye_h))
	return eye, eye + d * 100 + Vector((0, 0, 100 * math.tan(math.radians(pitch))))


def shots():
	eye, look = gameplay_pose(GAME_YAW)
	mid_off = sum(RUNNER_OFFSETS) / len(RUNNER_OFFSETS)
	a = TH0 + mid_off / lane_r(4)
	across = TH0 + math.pi + math.radians(32)  # past the boss's shoulder
	return [
		("arena_01_overview", (1050, -1950, Z + 1050), (0, -40, Z + 170), 42),
		("arena_02_gameplay", eye, look, 90),
		("arena_03_lanes", pol(R_IN - 30, a, Z + 46), pol(lane_r(5), a, Z + 2), 62),
		("arena_04_boss_up", pol(lane_r(1), TH0, Z + 6), (0, 0, Z + 430), 70),
		("arena_05_far_side", pol(lane_r(4) + 20, TH0, Z + 8), pol(lane_r(4), across, Z + 40), 90),
	]


# --- Measurements: projected through the real camera, nothing assumed ---
def project(cam, p):
	return world_to_camera_view(bpy.context.scene, cam, Vector(p))


def in_frame(q):
	return q.z > 0 and 0 <= q.x <= 1 and 0 <= q.y <= 1


def px_height(cam, foot, h=RUNNER_H):
	a, b = project(cam, foot), project(cam, Vector(foot) + Vector((0, 0, h)))
	return abs(b.y - a.y) * bpy.context.scene.render.resolution_y


def ring_coverage(cam, n=720):
	"""Share of the lane 4 line in frame and, of the whole ring, in frame and not blocked. Same for the far quarter."""
	scene, dg = bpy.context.scene, bpy.context.evaluated_depsgraph_get()
	eye = cam.matrix_world.translation
	seen = clear = far_seen = far_clear = far_n = 0
	for k in range(n):
		a = k / n * math.tau
		p = pol(lane_r(4), a, Z + 3)
		rel = (a - TH0 + math.pi) % math.tau - math.pi
		is_far = abs(rel) > math.radians(135)
		far_n += is_far
		if not in_frame(project(cam, p)):
			continue
		d = p - eye
		hit = scene.ray_cast(dg, eye, d.normalized(), distance=d.length - 3)[0]
		seen += 1
		clear += not hit
		far_seen += is_far
		far_clear += is_far and not hit
	return seen / n, clear / n, far_seen / far_n, far_clear / far_n


def mesh_verts(root):
	bpy.context.view_layer.update()
	return {o.name: [o.matrix_world @ v.co for v in o.data.vertices] for o in tree(root) if o.type == "MESH"}


def boss_fit(parts):
	"""Every part against the dais and the ring: radial reach and height, in studs."""
	for name, pts in parts.items():
		reach = max(math.hypot(p.x, p.y) for p in pts)
		print(f"FIT {name}: reach {reach:.0f} (kerb {R_IN - 6:.0f}, clear {R_IN - 6 - reach:.0f}), height {min(p.z for p in pts) - Z:.0f} to {max(p.z for p in pts) - Z:.0f}")
	low = [p for pts in parts.values() for p in pts if p.z - Z < 1]
	if low:
		print(f"FIT parts within 1 stud of the dais top reach {max(math.hypot(p.x, p.y) for p in low):.0f}; dais top flat radius {DAIS_R * math.cos(math.pi / 16):.0f}")


def frame_span(cam, pts, margin=0.0):
	"""(all in frame, screen rows spanned, share of verts in frame)"""
	q = [project(cam, p) for p in pts]
	inside = sum(c.z > 0 and margin <= c.x <= 1 - margin and margin <= c.y <= 1 - margin for c in q)
	ys = [c.y for c in q if c.z > 0]
	return inside == len(q), (max(ys) - min(ys)) * bpy.context.scene.render.resolution_y if ys else 0, inside / len(q)


def measure(cam, parts, near):
	far_foot = pol(lane_r(4), TH0 + math.pi)
	column_top = 62 + 28
	for name, eye, look, fov in shots():
		aim(cam, eye, look, fov)
		s, c, fs, fc = ring_coverage(cam)
		print(f"RING {name}: in frame {s:.0%} of the lap, unblocked {c:.0%}; far quarter in frame {fs:.0%}, unblocked {fc:.0%}")
	eye, look = gameplay_pose(GAME_YAW)
	aim(cam, eye, look, 90)
	for i, off in enumerate(RUNNER_OFFSETS):
		r = lane_r(i + 1)
		print(f"PX arena_02 lane {i + 1} runner {off} studs ahead of the near runner: {px_height(cam, pol(r, TH0 + off / r)):.1f}px")
	print(f"PX arena_02 near runner, projected: {px_height(cam, pol(lane_r(4), TH0)):.1f}px")
	for gap in (800, 1600):  # 7 players evenly spaced on the lap: 800 apart
		print(f"PX arena_02 a runner {gap} studs along the track: {px_height(cam, pol(lane_r(4), TH0 + gap / lane_r(4))):.1f}px")
	pts = [p for part in parts.values() for p in part]
	body = [p for name, part in parts.items() if name != "Wheel" for p in part]
	few = pts[::6]
	runner = [p for part in mesh_verts(near).values() for p in part][::20]
	for fov in (70, 90):
		aim(cam, pol(lane_r(4) + 20, TH0, Z + 8), far_foot + Vector((0, 0, 8)), fov)
		print(f"PX FOV {fov} across the hole: far runner {px_height(cam, far_foot):.1f}px, far colonnade {px_height(cam, pol(R_OUT + 18, TH0 + math.pi), column_top):.1f}px")
	for yaw in range(30, 91, 5):  # which pitches keep the whole boss and the near runner in frame at FOV 90
		good = []
		for pitch in range(0, 41):
			e, l = gameplay_pose(yaw, pitch=pitch)
			aim(cam, e, l, 90)
			if frame_span(cam, few, 0.01)[0] and frame_span(cam, runner, 0.01)[0]:
				good.append(pitch)
		print(f"SWEEP FOV 90 yaw {yaw}: pitches with the whole boss and near runner in frame: {f'{good[0]} to {good[-1]}' if good else 'none'}")
	for name, eye, look, fov in shots():
		aim(cam, eye, look, fov)
		whole, rows, share = frame_span(cam, pts)
		print(f"BOSS {name}: whole boss in frame {whole}, {share:.1%} of verts; {rows:.0f}px wheel top to feet" + (f", body only {frame_span(cam, body)[1]:.0f}px, head top 560 at {px_height(cam, (0, 0, Z), BOSS_H):.0f}px, wheel top on the axis {px_height(cam, (0, 0, Z), 804.4):.0f}px" if name == "arena_02_gameplay" else ""))


def measure_near_runner_mask(cam, near):
	"""The near runner's real rows in the arena_02 frame: everything else hidden, alpha counted."""
	scene = bpy.context.scene
	keep = set(tree(near)) | {cam}
	hidden = [o for o in scene.objects if o not in keep and not o.hide_render]
	for o in hidden:
		o.hide_render = True
	scene.render.film_transparent = True
	samples, scene.cycles.samples = scene.cycles.samples, 8
	eye, look = gameplay_pose(GAME_YAW)
	aim(cam, eye, look, 90)
	path = os.path.join(BUILD, "mask_near_runner.png")
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	img = bpy.data.images.load(path)
	w, h = img.size
	alpha = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[:, :, 3]
	ys, xs = np.nonzero(alpha > 0.5)
	assert len(ys), "near runner not in frame"
	print(f"MASK arena_02 near runner: {ys.max() - ys.min() + 1}px tall, {xs.max() - xs.min() + 1}px wide, {len(ys) / (w * h):.2%} of the frame")
	for o in hidden:
		o.hide_render = False
	scene.render.film_transparent = False
	scene.cycles.samples = samples


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	build_avatar.reset()
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(BUILD, exist_ok=True)
	scene = bpy.context.scene
	coll = scene.collection
	near, runner_tris, runner_how = add_runners(coll)  # first: its merge step clears loose objects

	report = []
	for m in (track(), dais()):
		report.append((m.name, tris(m.build(coll)), 1))
	arch_angles = [math.radians(ARCH_START + SECTOR * k) for k in range(360 // SECTOR)]
	bay_angles = [a + math.radians(s) for a in arch_angles for s in (20, 40)]
	report.append(("ArenaColonnade", *clones(colonnade_bay(), coll, bay_angles)))
	report.append(("ArenaArch", *clones(track_arch(), coll, arch_angles)))
	cloud_tris = tris(soften(clouds().build(coll)))

	if os.path.exists(BOSS_BLEND):
		boss = append_model(BOSS_BLEND, coll)
		boss.matrix_world = Matrix.Translation((0, 0, Z)) @ Matrix.Scale(BOSS_SCALE, 4)
		boss_how, boss_tris = "boss_raga.blend", model_tris(boss)
	else:
		boss = stand_in_boss(coll)
		boss_how, boss_tris = "STAND-IN blocks", tris(boss)
	boss_lo, boss_hi = bounds(boss)

	total = 0
	for name, t, count in report:
		print(f"TRIS {name}: {t} x {count} = {t * count}")
		total += t * count
	print(f"TRIS arena (ring, dais, colonnades, arches): {total}; unique meshes {sum(t for _, t, _ in report)}")
	print(f"TRIS clouds (draft only, the game may use particles and fog): {cloud_tris}")
	print(f"TRIS boss ({boss_how}): {boss_tris}; height {boss_hi.z - boss_lo.z:.1f}, width {boss_hi.x - boss_lo.x:.1f}, scale {boss.matrix_world.to_scale().z:.2f}, verts top {max(p.z for o in tree(boss) if o.type == 'MESH' for p in [o.matrix_world @ v.co for v in o.data.vertices]) - Z:.1f}")
	print(f"TRIS runner ({runner_how}): {runner_tris} each, height {bounds(near)[1].z - bounds(near)[0].z:.2f}")

	cam = setup_world(scene)
	bpy.context.preferences.filepaths.save_version = 0
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BUILD, "arena_draft.blend"))
	parts = mesh_verts(boss)
	boss_fit(parts)
	measure(cam, parts, near)
	measure_near_runner_mask(cam, near)
	for name, eye, look, fov in shots():
		if not argv or name in argv:
			aim(cam, eye, look, fov)
			scene.render.filepath = os.path.join(OUT, name + ".png")
			bpy.ops.render.render(write_still=True)
			print("SHOT", scene.render.filepath)


if __name__ == "__main__":
	main()
