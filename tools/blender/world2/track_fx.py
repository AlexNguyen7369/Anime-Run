"""World 2 track effects (draft, owner approval pending): in-house meshes and preview renders.

docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)"; numbers mirror Shared/TrackFxConfig (the game's
source of truth; the previews copy them by hand and are approximate). Everything is Blender geometry or the numpy
textures of track_fx_textures.py: no generator, no library asset.

Headless (devbox or Mac), from the repo root:
	Blender -b --factory-startup --python tools/blender/world2/track_fx.py -- meshes
	Blender -b --factory-startup --python tools/blender/world2/track_fx.py -- previews [name ...] [--props <glb dir>]
Live Blender (MCP): exec this file, then run(["meshes"]) in a fresh scene.
meshes: builds the drake (body + one wing) and the spirit eel (head + segment), prints tris, writes GLBs to
assets/world2_draft/track_fx/meshes/ and a turnaround to previews/. previews: renders 12 frames per effect to
build/track_fx/frames/<name>/ (then track_fx_gif.py makes the GIFs and sheets). --props: a folder of the approved
props' GLBs (W2_<Biome>_<Prop>.glb, export_props.py); a missing one is drawn as a plain stand-in block.
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
FX = os.path.join(ROOT, "assets", "world2_draft", "track_fx")
TEX = os.path.join(FX, "textures")
MESHES = os.path.join(FX, "meshes")
PREVIEWS = os.path.join(FX, "previews")
FRAMES = os.path.join(ROOT, "build", "track_fx", "frames")
PROPS = os.path.expanduser("~/Anime-Run.worktrees/feature-alex-agent-1/build/world2/reexport")


def hexc(h, a=1.0):
	h = h.lstrip("#")
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], a)


# ----------------------------------------------------------------------------------------------------------- scene


def clear():
	for ob in list(bpy.data.objects):
		bpy.data.objects.remove(ob, do_unlink=True)
	for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
		for item in list(coll):
			if item.users == 0:
				coll.remove(item)


def set_engine(scene):
	for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = engine
			return
		except TypeError:
			pass


def vcol_material(name="TrackFxVCol"):
	mat = bpy.data.materials.get(name)
	if mat:
		return mat
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	nt = mat.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	attr = nt.nodes.new("ShaderNodeVertexColor")
	attr.layer_name = "Col"
	tint = nt.nodes.new("ShaderNodeAttribute")
	tint.attribute_type = "OBJECT"
	tint.attribute_name = "tint"
	mul = nt.nodes.new("ShaderNodeMix")
	mul.data_type = "RGBA"
	mul.blend_type = "MULTIPLY"
	mul.inputs[0].default_value = 1.0
	nt.links.new(attr.outputs["Color"], mul.inputs[6])
	nt.links.new(tint.outputs["Color"], mul.inputs[7])
	nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.85
	return mat


def flat_material(name, color, emit=0.0):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = color
	bsdf.inputs["Roughness"].default_value = 0.9
	if emit > 0:
		bsdf.inputs["Emission Color"].default_value = color
		bsdf.inputs["Emission Strength"].default_value = emit
	return mat


def stage(sky, ground, sun_energy=3.0, sun_color="FFF4E0", sun_angle=(50, 0, 30), size=(640, 360)):
	"""Empty scene with a coloured sky, a ground plane and a sun."""
	clear()
	scene = bpy.context.scene
	set_engine(scene)
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.film_transparent = False
	try:
		scene.view_settings.view_transform = "Standard"
	except TypeError:
		pass
	world = scene.world or bpy.data.worlds.new("World")
	scene.world = world
	world.use_nodes = True
	bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
	bg.inputs["Color"].default_value = hexc(sky)
	bg.inputs["Strength"].default_value = 1.0
	bpy.ops.mesh.primitive_plane_add(size=4000)
	g = bpy.context.object
	g.name = "Ground"
	g.data.materials.append(flat_material("Ground", hexc(ground)))
	sun = bpy.data.lights.new("Sun", "SUN")
	sun.energy = sun_energy
	sun.color = hexc(sun_color)[:3]
	so = bpy.data.objects.new("Sun", sun)
	so.rotation_euler = Euler([math.radians(a) for a in sun_angle])
	scene.collection.objects.link(so)
	return scene


def road(length=600, width=40, y=0.0, color="3A3A3E"):
	bpy.ops.mesh.primitive_plane_add(size=1)
	r = bpy.context.object
	r.name = "Road"
	r.scale = (width, length, 1)
	r.location = (0, y, 0.05)
	r.data.materials.append(flat_material("Road", hexc(color)))
	return r


def camera(loc, target, lens=32):
	cam = bpy.data.cameras.new("Cam")
	cam.lens = lens
	cam.clip_end = 20000
	co = bpy.data.objects.new("Cam", cam)
	bpy.context.scene.collection.objects.link(co)
	co.location = loc
	d = Vector(target) - Vector(loc)
	co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
	bpy.context.scene.camera = co
	return co


def prop(biome, name, loc=(0, 0, 0), yaw=0.0, scale=1.0, stand_in=(20, 20, 30), color="888888"):
	"""An approved prop's GLB (Roblox Y up, studs) placed by its base centre; a block when the GLB is missing."""
	path = os.path.join(PROPS, "W2_%s_%s.glb" % (biome, name))
	if os.path.exists(path):
		before = set(bpy.data.objects)
		bpy.ops.import_scene.gltf(filepath=path)
		obs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
		mat = vcol_material()
		for o in obs:
			o.data.materials.clear()
			o.data.materials.append(mat)
			o["tint"] = (1.0, 1.0, 1.0, 1.0)
			if o.data.color_attributes:
				o.data.color_attributes[0].name = "Col"
		bpy.context.view_layer.update()
		zs = [(o.matrix_world @ Vector(c)) for o in obs for c in o.bound_box]
		lo = Vector((min(p.x for p in zs), min(p.y for p in zs), min(p.z for p in zs)))
		hi = Vector((max(p.x for p in zs), max(p.y for p in zs), max(p.z for p in zs)))
		centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
		root = bpy.data.objects.new("Prop_" + name, None)
		bpy.context.scene.collection.objects.link(root)
		for o in obs:
			if o.parent is None or o.parent not in obs:
				o.parent = root
				o.location -= centre
		root.location = loc
		root.rotation_euler = (0, 0, yaw)
		root.scale = (scale, scale, scale)
		size = (hi - lo) * scale
		return root, size
	bpy.ops.mesh.primitive_cube_add(size=1)
	b = bpy.context.object
	b.name = "StandIn_" + name
	b.scale = stand_in
	b.location = (loc[0], loc[1], loc[2] + stand_in[2] / 2)
	b.data.materials.append(flat_material("StandIn", hexc(color)))
	return b, Vector(stand_in)


def render(path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------------------------------------------- meshes


def paint(me, fn):
	"""Vertex colour per face corner from fn(face centre, face normal) -> grey 0..1"""
	attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	for poly in me.polygons:
		g = fn(poly.center, poly.normal)
		for li in poly.loop_indices:
			attr.data[li].color = (g, g, g, 1.0)


def loft(bm, rings, sides=6):
	"""Rings: (y, z, half width, half height); closed tube from the first ring to the last, capped by points."""
	loops = []
	for y, z, w, h in rings:
		loop = []
		for i in range(sides):
			a = (i + 0.5) / sides * math.pi * 2
			loop.append(bm.verts.new((math.cos(a) * w, y, z + math.sin(a) * h)))
		loops.append(loop)
	for a, b in zip(loops, loops[1:]):
		for i in range(sides):
			j = (i + 1) % sides
			bm.faces.new((a[i], a[j], b[j], b[i]))
	for loop, tip_y in ((loops[0], rings[0][0] - 1.0), (loops[-1], rings[-1][0] + 1.0)):
		tip = bm.verts.new((0, tip_y, sum(v.co.z for v in loop) / sides))
		for i in range(sides):
			j = (i + 1) % sides
			if loop is loops[0]:
				bm.faces.new((loop[j], loop[i], tip))
			else:
				bm.faces.new((loop[i], loop[j], tip))
	return loops


def spike(bm, base, length, width, direction):
	"""A three-sided cone from `base` along `direction`"""
	d = Vector(direction).normalized()
	side = d.cross(Vector((0, 0, 1)))
	if side.length < 1e-3:
		side = Vector((1, 0, 0))
	side.normalize()
	up = side.cross(d).normalized()
	b = Vector(base)
	vs = [bm.verts.new(b + (side * math.cos(a) + up * math.sin(a)) * width) for a in (0, 2.094, 4.189)]
	tip = bm.verts.new(b + d * length)
	for i in range(3):
		bm.faces.new((vs[i], vs[(i + 1) % 3], tip))
	bm.faces.new((vs[2], vs[1], vs[0]))


def finish(bm, name, painter):
	me = bpy.data.meshes.new(name)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(me)
	bm.free()
	paint(me, painter)
	for p in me.polygons:
		p.use_smooth = False  # hard facets (design doc 5 target look)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	ob.data.materials.append(vcol_material())
	ob["tint"] = (1.0, 1.0, 1.0, 1.0)
	return ob


def tris(ob):
	return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def drake_body():
	"""Generic drake, head toward +Y (Roblox -Z), about 64 long: wedge head, two swept horns, long neck, no legs."""
	bm = bmesh.new()
	rings = [  # y, z, half width, half height: tail tip to snout
		(-33, 1.0, 0.35, 0.3),
		(-27, 0.6, 0.9, 0.8),
		(-20, 0.2, 1.6, 1.4),
		(-12, 0.0, 2.6, 2.4),
		(-5, 0.0, 5.4, 4.0),
		(1, 0.4, 6.4, 4.6),
		(7, 1.0, 5.2, 3.8),
		(11, 2.0, 2.6, 2.4),
		(15, 3.2, 1.9, 1.9),
		(19, 4.2, 1.8, 1.8),
		(23, 4.8, 2.6, 2.2),
		(27, 4.6, 2.3, 1.7),
		(30, 4.0, 1.4, 1.1),
	]
	loft(bm, rings)
	spike(bm, (-1.2, 22.5, 6.2), 7.0, 0.5, (-0.25, -1, 0.55))  # horns sweep back and up
	spike(bm, (1.2, 22.5, 6.2), 7.0, 0.5, (0.25, -1, 0.55))
	for y, z, h in ((-14, 2.2, 2.4), (-8, 3.6, 3.0), (-2, 4.6, 3.4), (4, 4.6, 3.0), (-20, 1.4, 1.8)):
		spike(bm, (0, y, z), h, 0.8, (0, -0.5, 1))  # dorsal spines
	# the tail's spade: a flat diamond
	diamond = ((0, -33.5), (-2.4, -36.5), (0, -40.0), (2.4, -36.5))
	top = [bm.verts.new((x, y, 1.25)) for x, y in diamond]
	bot = [bm.verts.new((x, y, 0.75)) for x, y in diamond]
	bm.faces.new(top)
	bm.faces.new(list(reversed(bot)))
	for i in range(4):
		j = (i + 1) % 4
		bm.faces.new((top[j], top[i], bot[i], bot[j]))
	ob = finish(bm, "TrackFx_DrakeBody", lambda c, n: 0.9 if n.z < -0.35 else (0.3 if c.z > 5.5 or c.y < -33 else 0.62))
	return ob


def drake_wing():
	"""One wing: root on +X at x=0, tip at -44, leading edge toward +Y. Flat, two sided (the right wing is this one turned
	180 degrees about the body's long axis). Membrane between three finger spars."""
	bm = bmesh.new()
	t = 0.35  # half thickness
	outline = [(0, 6), (-14, 10), (-30, 8), (-44, 2), (-34, -4), (-30, -12), (-20, -8), (-14, -16), (-6, -9), (0, -8)]
	for z in (t, -t):
		vs = [bm.verts.new((x, y, z)) for x, y in outline]
		if z > 0:
			top = vs
		else:
			bot = vs
	bm.faces.new(top)
	bm.faces.new(list(reversed(bot)))
	n = len(outline)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((top[i], top[j], bot[j], bot[i]))
	for tip in ((-44, 2), (-30, -12), (-14, -16)):  # finger spars, raised on both faces (seen from below in game)
		for z in (0.4, -0.4):
			spike(bm, (-2, 4, z), Vector((tip[0] + 2, tip[1] - 4, 0)).length, 0.55, (tip[0] + 2, tip[1] - 4, 0))
	bmesh.ops.triangulate(bm, faces=bm.faces)
	return finish(bm, "TrackFx_DrakeWing", lambda c, n: 0.35 if abs(c.z) > 0.38 else (0.55 if abs(n.z) > 0.5 else 0.4))


def eel_head():
	"""Spirit eel head toward +Y: blunt rounded snout, a fin crest, no horns, no whiskers, no limbs."""
	bm = bmesh.new()
	rings = [(-7, 0, 3.0, 3.2), (-3, 0.2, 3.4, 3.2), (1, 0.2, 3.2, 2.8), (4, 0, 2.6, 2.1), (6, -0.2, 1.6, 1.3)]
	loft(bm, rings, sides=8)
	for y, h in ((-5, 4.0), (-2, 3.0), (1, 2.0)):
		spike(bm, (0, y, 2.8), h, 0.6, (0, -0.7, 1))  # crest
	bmesh.ops.triangulate(bm, faces=bm.faces)
	return finish(bm, "TrackFx_EelHead", lambda c, n: 0.95 if n.z < -0.3 else (0.5 if c.z > 3 else 0.75))


def eel_segment():
	bm = bmesh.new()
	loft(bm, [(-4.5, 0, 3.0, 3.2), (0, 0, 3.2, 3.4), (4.5, 0, 3.0, 3.2)], sides=8)
	spike(bm, (0, 0, 3.2), 3.4, 0.6, (0, -0.8, 1))
	bmesh.ops.triangulate(bm, faces=bm.faces)
	return finish(bm, "TrackFx_EelSegment", lambda c, n: 0.95 if n.z < -0.3 else (0.5 if c.z > 3.3 else 0.75))


def export_glb(ob, path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	for o in bpy.context.scene.objects:
		o.select_set(o == ob)
	bpy.context.view_layer.objects.active = ob
	kw = dict(filepath=path, use_selection=True, export_format="GLB", export_yup=True, export_apply=True, export_materials="NONE")
	try:
		bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
	except TypeError:
		bpy.ops.export_scene.gltf(export_colors=True, **kw)


def build_meshes(export=True):
	body, wing, head, seg = drake_body(), drake_wing(), eel_head(), eel_segment()
	out = {}
	for ob in (body, wing, head, seg):
		ob.data.update()
		dims = tuple(round(x, 2) for x in ob.dimensions)
		out[ob.name] = (tris(ob), dims)
		print("TRACKFX MESH %s tris=%d size=%s" % (ob.name, tris(ob), dims))
		if export:
			export_glb(ob, os.path.join(MESHES, ob.name + ".glb"))
	return body, wing, head, seg, out


def assemble_drake(body, wing, tint, flap_deg=0.0):
	"""The game's assembly (Client/TrackFx updateDragon): left wing at the hinge, right = the same mesh turned 180."""
	body["tint"] = tint
	hinge = Vector((5, 6, 3))  # Blender axes of TrackFxConfig.Drake.WingHinge (5, 3, -6)
	left = wing
	left["tint"] = tint
	right = wing.copy()
	right.data = wing.data
	bpy.context.scene.collection.objects.link(right)
	right["tint"] = tint
	a = math.radians(flap_deg)
	left.parent = body
	right.parent = body
	left.matrix_parent_inverse = Matrix.Identity(4)
	right.matrix_parent_inverse = Matrix.Identity(4)
	# left wing: root at x=0 already, tip toward -X
	left.matrix_basis = Matrix.Translation(Vector((-hinge.x, hinge.y, hinge.z))) @ Matrix.Rotation(-a, 4, "Y")
	right.matrix_basis = (
		Matrix.Translation(Vector((hinge.x, hinge.y, hinge.z))) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(math.pi, 4, "Y")
	)
	return left, right


def set_flap(left, right, flap_deg):
	a = math.radians(flap_deg)
	tl, tr = left.matrix_basis.to_translation(), right.matrix_basis.to_translation()
	left.matrix_basis = Matrix.Translation(tl) @ Matrix.Rotation(-a, 4, "Y")
	right.matrix_basis = Matrix.Translation(tr) @ Matrix.Rotation(a, 4, "Y") @ Matrix.Rotation(math.pi, 4, "Y")


def turnaround():
	stage("9FB8D0", "6E8A5A", sun_energy=3.5)
	body, wing, head, seg, info = build_meshes(export=False)
	assemble_drake(body, wing, hexc("6E8A5A"), flap_deg=20)
	body.location = (0, 0, 30)
	head.location = (60, 0, 30)
	head["tint"] = hexc("BFE8F0")
	for i in range(1, 8):
		s = seg.copy()
		bpy.context.scene.collection.objects.link(s)
		s.location = (60 + math.sin(i * 0.9) * 3 * i / 8, -i * 8.5 - 3, 30)
		s.scale = [1 - 0.45 * i / 14] * 3
		s["tint"] = hexc("BFE8F0")
	seg.location = (60, -3.5, 30)
	seg["tint"] = hexc("BFE8F0")
	views = {"three_quarter": ((95, -95, 75), (30, -10, 30)), "top": ((30, -10, 190), (30, -10, 30)), "side": ((30, -150, 34), (30, -10, 30))}
	for name, (loc, target) in views.items():
		cam = camera(loc, target, lens=35)
		render(os.path.join(PREVIEWS, "meshes_%s.png" % name))
		bpy.data.objects.remove(cam)
	return info


# -------------------------------------------------------------------------------------------------------- particles

FLIP = {"TrackFx_SmokePuff": True, "TrackFx_Wisp": True, "TrackFx_Haze": False, "TrackFx_Ember": False}
# Shared/TrackFxConfig.Presets, copied: Rate, Lifetime, Speed, Accel (Roblox X, Y up, Z), Spread, Drag, Size keys,
# Transparency keys, RotSpeed, LightInfluence, LightEmission, Area (Roblox X, Y, Z), Squash
PRESETS = {
	"SmokeColumn": dict(tex="TrackFx_SmokePuff", rate=3, life=(8, 11), speed=(7, 11), acc=(1.2, 1.5, 0), spread=12, drag=0.15,
		size=[(0, 18), (0.5, 38), (1, 52)], tr=[(0, 1), (0.08, 0.25), (0.75, 0.45), (1, 1)], rot=(-10, 10), li=0.85, le=0, area=(40, 6, 40)),
	"RubbleSmoke": dict(tex="TrackFx_SmokePuff", rate=2, life=(6, 8), speed=(4, 7), acc=(0.8, 0.8, 0), spread=18, drag=0.2,
		size=[(0, 6), (0.6, 16), (1, 22)], tr=[(0, 1), (0.1, 0.4), (0.7, 0.6), (1, 1)], rot=(-15, 15), li=0.9, le=0, area=(14, 2, 14)),
	"Chimney": dict(tex="TrackFx_Wisp", rate=2, life=(4, 5.5), speed=(3, 5), acc=(1.5, 0.6, 0), spread=8, drag=0.3,
		size=[(0, 5), (0.5, 12), (1, 16)], tr=[(0, 1), (0.1, 0.3), (0.8, 0.55), (1, 1)], rot=(-6, 6), li=0.8, le=0, area=(2, 1, 2)),
	"Steam": dict(tex="TrackFx_Wisp", rate=4, life=(2.5, 3.5), speed=(5, 8), acc=(0.5, 1, 0), spread=14, drag=0.4,
		size=[(0, 3), (0.6, 8), (1, 11)], tr=[(0, 1), (0.1, 0.35), (0.7, 0.6), (1, 1)], rot=(-20, 20), li=0.6, le=0.1, area=(6, 1, 6)),
	"GroundHaze": dict(tex="TrackFx_Haze", rate=0.6, life=(14, 18), speed=(0.6, 1.4), acc=(0.3, 0, 0), spread=80, drag=0,
		size=[(0, 30), (1, 46)], tr=[(0, 1), (0.25, 0.78), (0.75, 0.78), (1, 1)], rot=(0, 0), li=1, le=0, area=(70, 2, 70), squash=-0.55),
	"Embers": dict(tex="TrackFx_Ember", rate=6, life=(2.5, 4), speed=(6, 12), acc=(1, 2, 0), spread=25, drag=0.5,
		size=[(0, 0.9), (1, 0.2)], tr=[(0, 0), (0.7, 0.2), (1, 1)], rot=(0, 0), li=0, le=1, area=(20, 4, 20)),
	"Motes": dict(tex="TrackFx_Ember", rate=4, life=(6, 9), speed=(0.5, 1.5), acc=(0, 0.2, 0), spread=180, drag=0.6,
		size=[(0, 0.6), (0.5, 1.3), (1, 0.4)], tr=[(0, 1), (0.2, 0.2), (0.8, 0.3), (1, 1)], rot=(0, 0), li=0, le=1, area=(40, 16, 40)),
}


def keys_at(keys, t):
	for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
		if t <= t1:
			return v0 + (v1 - v0) * ((t - t0) / (t1 - t0) if t1 > t0 else 0)
	return keys[-1][1]


def particle_material(tex, li, le):
	"""Billboard material: the texture (one flipbook cell chosen by the object's 'cell'), tinted by the object's 'col',
	alpha from its 'alpha'. Lit by the scene by LightInfluence, glowing by LightEmission."""
	name = "P_%s_%s_%s" % (tex, li, le)
	mat = bpy.data.materials.get(name)
	if mat:
		return mat
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	try:
		mat.surface_render_method = "BLENDED"
	except (AttributeError, TypeError):
		mat.blend_method = "BLEND"
	nt = mat.node_tree
	for n in list(nt.nodes):
		nt.nodes.remove(n)
	out = nt.nodes.new("ShaderNodeOutputMaterial")
	img = nt.nodes.new("ShaderNodeTexImage")
	path = os.path.join(TEX, tex + (".flipbook.png" if FLIP[tex] else ".png"))
	img.image = bpy.data.images.load(path, check_existing=True)
	img.extension = "CLIP"
	uv = nt.nodes.new("ShaderNodeTexCoord")
	cell = nt.nodes.new("ShaderNodeAttribute")
	cell.attribute_type = "OBJECT"
	cell.attribute_name = "cell"
	col = nt.nodes.new("ShaderNodeAttribute")
	col.attribute_type = "OBJECT"
	col.attribute_name = "col"
	alpha = nt.nodes.new("ShaderNodeAttribute")
	alpha.attribute_type = "OBJECT"
	alpha.attribute_name = "alpha"
	if FLIP[tex]:
		# u = (uv.x + cell % 4) / 4 ; v = (uv.y + 3 - floor(cell / 4)) / 4
		sep = nt.nodes.new("ShaderNodeSeparateXYZ")
		nt.links.new(uv.outputs["UV"], sep.inputs[0])

		def math_node(op, a, b):
			m = nt.nodes.new("ShaderNodeMath")
			m.operation = op
			for i, x in enumerate((a, b)):
				if isinstance(x, (int, float)):
					m.inputs[i].default_value = x
				else:
					nt.links.new(x, m.inputs[i])
			return m.outputs[0]

		c = cell.outputs["Fac"]
		col4 = math_node("MODULO", c, 4)
		row = math_node("FLOOR", math_node("DIVIDE", c, 4), 0)
		u = math_node("DIVIDE", math_node("ADD", sep.outputs["X"], col4), 4)
		v = math_node("DIVIDE", math_node("ADD", sep.outputs["Y"], math_node("SUBTRACT", 3, row)), 4)
		comb = nt.nodes.new("ShaderNodeCombineXYZ")
		nt.links.new(u, comb.inputs[0])
		nt.links.new(v, comb.inputs[1])
		nt.links.new(comb.outputs[0], img.inputs["Vector"])
	else:
		nt.links.new(uv.outputs["UV"], img.inputs["Vector"])
	# colour: the texture's grey (value) times the tint
	tint = nt.nodes.new("ShaderNodeMix")
	tint.data_type = "RGBA"
	tint.blend_type = "MULTIPLY"
	tint.inputs[0].default_value = 1.0
	nt.links.new(img.outputs["Color"], tint.inputs[6])
	nt.links.new(col.outputs["Color"], tint.inputs[7])
	diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
	nt.links.new(tint.outputs[2], diffuse.inputs["Color"])
	emit = nt.nodes.new("ShaderNodeEmission")
	nt.links.new(tint.outputs[2], emit.inputs["Color"])
	emit.inputs["Strength"].default_value = 1.0 + 3.0 * le
	lit = nt.nodes.new("ShaderNodeMixShader")
	lit.inputs[0].default_value = 1.0 - li * 0.7  # keep some self light so the smoke never goes black in a preview
	nt.links.new(diffuse.outputs[0], lit.inputs[1])
	nt.links.new(emit.outputs[0], lit.inputs[2])
	a = nt.nodes.new("ShaderNodeMath")
	a.operation = "MULTIPLY"
	nt.links.new(img.outputs["Alpha"], a.inputs[0])
	nt.links.new(alpha.outputs["Fac"], a.inputs[1])
	transparent = nt.nodes.new("ShaderNodeBsdfTransparent")
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(a.outputs[0], mix.inputs[0])
	nt.links.new(transparent.outputs[0], mix.inputs[1])
	nt.links.new(lit.outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], out.inputs["Surface"])
	return mat


class Emitter:
	"""A Roblox ParticleEmitter approximated in Python: Box shape, Top emission, the preset's sequences."""

	def __init__(self, preset, at, colors, seed=1, rate_scale=1.0, area=None):
		self.p = dict(PRESETS[preset])
		if area:
			self.p["area"] = tuple(max(a, b) for a, b in zip(self.p["area"], area))  # TrackFxPlan.Area
		self.at = Vector(at)  # Blender coordinates of the emitter part's centre
		self.colors = [hexc(c) for c in colors]
		self.rng = random.Random(seed)
		self.list = []
		self.carry = 0.0
		self.rate = self.p["rate"] * rate_scale

	def step(self, dt):
		p = self.p
		self.carry += self.rate * dt
		while self.carry >= 1:
			self.carry -= 1
			ax, ay, az = p["area"]  # Roblox axes: Y up
			pos = self.at + Vector(((self.rng.random() - 0.5) * ax, (self.rng.random() - 0.5) * az, (self.rng.random() - 0.5) * ay))
			sp = math.radians(p["spread"])
			th, ph = self.rng.uniform(-sp, sp), self.rng.uniform(0, math.pi * 2)
			d = Vector((math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph), math.cos(th)))
			life = self.rng.uniform(*p["life"])
			self.list.append(dict(pos=pos, vel=d * self.rng.uniform(*p["speed"]), age=0.0, life=life,
				rot=self.rng.uniform(0, 360), rs=self.rng.uniform(*p["rot"])))
		ax, ay, az = p["acc"]
		acc = Vector((ax, -az, ay))
		keep = []
		for q in self.list:
			q["age"] += dt
			if q["age"] >= q["life"]:
				continue
			q["vel"] = (q["vel"] + acc * dt) * (2 ** (-p["drag"] * dt))
			q["pos"] = q["pos"] + q["vel"] * dt
			q["rot"] += q["rs"] * dt
			keep.append(q)
		self.list = keep


class Billboards:
	"""A pool of camera-facing planes that draws a set of emitters each frame."""

	def __init__(self):
		self.pool = {}

	def draw(self, emitters, cam):
		used = {}
		cam_rot = cam.matrix_world.to_3x3()
		for e in emitters:
			p = e.p
			mat = particle_material(p["tex"], p["li"], p["le"])
			for q in e.list:
				key = mat.name
				used[key] = used.get(key, 0) + 1
				ob = self.get(key, used[key], mat)
				t = q["age"] / q["life"]
				s = keys_at(p["size"], t)
				sq = p.get("squash", 0)
				sx, sy = (s * (1 - sq * 0.8), s * (1 + sq)) if sq < 0 else (s, s)
				ob.matrix_world = Matrix.Translation(q["pos"]) @ cam_rot.to_4x4() @ Matrix.Rotation(math.radians(q["rot"]), 4, "Z") @ Matrix.Diagonal((sx, sy, 1, 1))
				ob["cell"] = min(15, int(t * 16)) if FLIP[p["tex"]] else 0
				c0, c1 = e.colors
				ob["col"] = tuple(c0[i] + (c1[i] - c0[i]) * t for i in range(3)) + (1.0,)
				ob["alpha"] = 1.0 - keys_at(p["tr"], t)
				ob.hide_render = False
		for key, obs in self.pool.items():
			for i, ob in enumerate(obs):
				if i >= used.get(key, 0):
					ob.hide_render = True

	def get(self, key, n, mat):
		obs = self.pool.setdefault(key, [])
		while len(obs) < n:
			me = bpy.data.meshes.get("Billboard") or self.plane()  # shared quad with one empty slot
			ob = bpy.data.objects.new("P", me)
			bpy.context.scene.collection.objects.link(ob)
			ob.material_slots[0].link = "OBJECT"  # each billboard carries its own material
			ob.material_slots[0].material = mat
			obs.append(ob)
		return obs[n - 1]

	@staticmethod
	def plane():
		me = bpy.data.meshes.new("Billboard")
		bm = bmesh.new()
		vs = [bm.verts.new(c) for c in ((-0.5, -0.5, 0), (0.5, -0.5, 0), (0.5, 0.5, 0), (-0.5, 0.5, 0))]
		bm.faces.new(vs)
		bm.to_mesh(me)
		bm.free()
		uvl = me.uv_layers.new(name="UVMap")
		for i, c in enumerate(((0, 0), (1, 0), (1, 1), (0, 1))):
			uvl.data[i].uv = c
		me.materials.append(None)
		return me


def run_particles(name, emitters, cam, frames=12, spacing=0.5, warm=None, step=1 / 15, before_frame=None):
	warm = warm if warm is not None else max(e.p["life"][1] for e in emitters)
	board = Billboards()
	t = 0.0
	while t < warm:
		for e in emitters:
			e.step(step)
		t += step
	for f in range(frames):
		if before_frame:
			before_frame(f, t)
		board.draw(emitters, cam)
		render(os.path.join(FRAMES, name, "f%02d.png" % f))
		n = int(round(spacing / step))
		for _ in range(n):
			for e in emitters:
				e.step(step)
			t += step


# Roblox Offset (-1..1 of the box) -> Blender point on a prop whose base centre is `loc` and size `size` (Blender axes)
def box_point(loc, size, offset):
	ox, oy, oz = offset  # Roblox X, Y (up), Z
	return Vector((loc[0] + ox * size.x / 2, loc[1] - oz * size.y / 2, loc[2] + size.z / 2 + oy * size.z / 2))


# --------------------------------------------------------------------------------------------------------- previews


def preview_smoke(name, sky, ground, biome, props, rows, cam_loc, cam_target, sun=3.0, sun_color="FFF4E0", lens=30, road_on=True):
	"""props: [(prop name, loc, yaw, scale)]; rows: [(preset, prop name or None, offset or Blender point, colours)]"""
	stage(sky, ground, sun_energy=sun, sun_color=sun_color)
	if road_on:
		road(length=3000, width=40, y=0, color="3A3A3E")
	placed = {}
	for pname, loc, yaw, scale in props:
		ob, size = prop(biome, pname, loc, yaw, scale)
		placed.setdefault(pname, []).append((loc, size))
	cam = camera(cam_loc, cam_target, lens=lens)
	emitters = []
	for i, row in enumerate(rows):
		preset, pname, offset, colors = row[:4]
		fill = row[4] if len(row) > 4 else None
		if pname is None:
			emitters.append(Emitter(preset, offset, colors, seed=10 + i))
			continue
		for j, (loc, size) in enumerate(placed.get(pname, [])):
			area = fill and (size.x * fill[0], size.z * fill[1], size.y * fill[2])  # Roblox X, Y up, Z
			emitters.append(Emitter(preset, box_point(loc, size, offset), colors, seed=100 * i + j, area=area))
	run_particles(name, emitters, cam)


def preview_drake(name="dragon_drake", tint="2E2236", sky="6A4470", ground="2A2230", sun=3.0, sun_color="FFB0D0"):
	stage(sky, ground, sun_energy=sun, sun_color=sun_color)
	road(length=4000, width=40)
	body, wing, head, seg, _ = build_meshes(export=False)
	for o in (head, seg):
		bpy.data.objects.remove(o)
	left, right = assemble_drake(body, wing, hexc(tint))
	body.scale = (1.6, 1.6, 1.6)  # TrackFxConfig.Drake sizes are the meshes at x1.6
	# the loop of TrackFxConfig (Lateral 380, Radius 200, Altitude 320), seen from a runner on the road
	centre = Vector((380, 200, 320))
	cam = camera((0, -120, 8), (330, 200, 300), lens=38)
	period, flap_period = 64.0, 1.8
	for f in range(12):
		t = f * 0.3 + 20
		u = (t / period) % 1
		a = u * math.pi * 2
		r = 200 * (1 + 0.18 * math.sin(a * 2 + 1))
		pos = centre + Vector((math.cos(a) * r, math.sin(a) * r * 0.7, 22 * math.sin(a * 3)))
		a2 = a + 0.02
		r2 = 200 * (1 + 0.18 * math.sin(a2 * 2 + 1))
		nxt = centre + Vector((math.cos(a2) * r2, math.sin(a2) * r2 * 0.7, 22 * math.sin(a2 * 3)))
		fwd = (nxt - pos).normalized()
		rot = fwd.to_track_quat("Y", "Z").to_matrix().to_4x4()
		flap = math.sin((t / flap_period) % 1 * math.pi * 2)
		body.matrix_world = Matrix.Translation(pos - Vector((0, 0, flap * 4))) @ rot @ Matrix.Rotation(math.radians(-18), 4, "Y") @ Matrix.Diagonal((1.6, 1.6, 1.6, 1))
		set_flap(left, right, 32 * flap)
		render(os.path.join(FRAMES, name, "f%02d.png" % f))
	# a close-up flap cycle, in daylight so the shape reads
	stage("9FB8D0", "6E8A5A", sun_energy=3.5)
	body, wing, head, seg, _ = build_meshes(export=False)
	for o in (head, seg):
		bpy.data.objects.remove(o)
	left, right = assemble_drake(body, wing, hexc("6E8A5A"))
	body.matrix_world = Matrix.Translation((0, 0, 40)) @ Matrix.Rotation(math.radians(-90), 4, "Z")
	camera((70, -80, 60), (0, 0, 40), lens=35)
	for f in range(12):
		set_flap(left, right, 32 * math.sin(f / 12 * math.pi * 2))
		render(os.path.join(FRAMES, name + "_flap", "f%02d.png" % f))


def preview_eel(name="dragon_eel"):
	stage("2A3658", "2A3A2E", sun_energy=1.6, sun_color="BFD0FF")
	road(length=4000, width=40, color="2A2A2E")
	for i in range(14):
		ob, _ = prop("HauntedTunnel", "Cedar", (-60 - (i % 3) * 25, i * 70 - 200, 0), i * 0.7, 1.0)
	body, wing, head, seg, _ = build_meshes(export=False)
	for o in (body, wing):
		bpy.data.objects.remove(o)
	tint = hexc("BFE8F0")
	head_ob = head
	head["tint"] = tint
	segs = [seg]
	for i in range(13):
		s = seg.copy()
		bpy.context.scene.collection.objects.link(s)
		segs.append(s)
	for i, s in enumerate(segs):
		s["tint"] = tint
		s.scale = [2.5 * (1 - 0.45 * (i + 1) / 14)] * 3  # TrackFxConfig.Eel: the meshes at x2.5
	head.scale = (2.5, 2.5, 2.5)
	cam = camera((0, -150, 10), (330, 150, 230), lens=40)
	centre = Vector((360, 150, 240))
	# TrackFxPlan.DragonPath's 8 control points, its closed Catmull-Rom spline and its arc-length table (SplineAt), so
	# the segments are laid out by distance exactly as Client/TrackFx does
	ctrl = []
	for i in range(8):
		a = i / 8 * math.pi * 2
		r = 200 * (1 + 0.18 * math.sin(a * 2 + 1))
		ctrl.append(centre + Vector((math.cos(a) * r, math.sin(a) * r * 0.7, 22 * math.sin(a * 3))))

	def spline(u):
		n = len(ctrl)
		f = (u % 1) * n
		k = int(math.floor(f))
		t = f - k
		p0, p1, p2, p3 = ctrl[(k - 1) % n], ctrl[k % n], ctrl[(k + 1) % n], ctrl[(k + 2) % n]
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)

	us, ds, total, last = [0.0], [0.0], 0.0, spline(0)
	for k in range(1, 257):
		p = spline(k / 256)
		total += (p - last).length
		last = p
		us.append(k / 256)
		ds.append(total)

	def at(dist):
		g = dist % total
		k = max(i for i in range(len(ds)) if ds[i] <= g)
		k = min(k, len(ds) - 2)
		span = ds[k + 1] - ds[k]
		return spline(us[k] + (us[k + 1] - us[k]) * ((g - ds[k]) / span if span > 0 else 0))

	for f in range(12):
		t = 10 + f * 0.4
		head = ((t / 75) % 1) * total
		for k, ob in enumerate([head_ob] + segs):
			dd = head - sum(21 * (1 - 0.45 * (j - 0.5) / 14) for j in range(1, k + 1))  # TrackFxPlan.EelBack
			p, q = at(dd), at(dd + 1)
			fwd = (q - p).normalized()
			side = fwd.cross(Vector((0, 0, 1))).normalized()
			wave = math.sin(t / 3.2 * math.pi * 2 - k / 9 * math.pi * 2) * 15 * (k / 14)
			sc = ob.scale.copy()
			ob.matrix_world = Matrix.Translation(p + side * wave) @ fwd.to_track_quat("Y", "Z").to_matrix().to_4x4()
			ob.scale = sc
		render(os.path.join(FRAMES, name, "f%02d.png" % f))


def preview_motion(name, sky, ground, biome, pname, kind, n, spacing, cam_loc, cam_target, amp, period, roll=0.0, sun=3.0, lift=0.0):
	stage(sky, ground, sun_energy=sun)
	road(length=3000, width=40)
	obs = []
	rng = random.Random(4)
	for i in range(n):
		loc = (-50 - (i % 2) * spacing * 0.6, i * spacing - n * spacing / 3, lift)
		ob, size = prop(biome, pname, loc, rng.uniform(0, 6.28), 1.0)
		obs.append((ob, Vector(loc), rng.random()))
	cam = camera(cam_loc, cam_target, lens=30)
	for f in range(12):
		t = f * period / 12
		for ob, loc, phase in obs:
			w = math.pi * 2 * (t / period + phase)
			if kind == "Sway":
				ob.rotation_euler = (math.radians(amp) * math.sin(w), math.radians(amp) * 0.6 * math.sin(w * 0.73 + 1.3), ob.rotation_euler.z)
			else:
				ob.location = loc + Vector((0, 0, amp * math.sin(w)))
				ob.rotation_euler = (math.radians(roll) * math.sin(w * 0.8 + 0.7), 0, ob.rotation_euler.z)
		render(os.path.join(FRAMES, name, "f%02d.png" % f))


def preview_flicker(name="motion_flicker"):
	"""Night street with the draft lamps' flicker (TrackFxPlan.Flicker, HauntedTunnel row: Depth 0.15, Speed 4, Dropout 0.03)"""
	stage("0E1220", "1E2A22", sun_energy=0.3, sun_color="BFD0FF")
	road(length=3000, width=40, color="2A2A2E")
	lamps = []
	for i in range(5):
		y = i * 90 - 100
		bpy.ops.mesh.primitive_cylinder_add(radius=0.6, depth=18, location=(-28, y, 9))
		bpy.context.object.data.materials.append(flat_material("Pole", hexc("555A60")))
		light = bpy.data.lights.new("Lamp%d" % i, "POINT")
		light.energy = 400000
		light.color = hexc("FFD9A0")[:3]
		lo = bpy.data.objects.new("Lamp%d" % i, light)
		lo.location = (-24, y, 17)
		bpy.context.scene.collection.objects.link(lo)
		bpy.ops.mesh.primitive_uv_sphere_add(radius=1.2, location=(-24, y, 17))
		bulb = bpy.context.object
		mat = flat_material("Bulb%d" % i, hexc("FFE0B0"), emit=8)
		bulb.data.materials.append(mat)
		# the lamp's pool of light on the road, drawn as a glowing disc (headless EEVEE point lights barely show here)
		bpy.ops.mesh.primitive_circle_add(vertices=24, radius=16, fill_type="TRIFAN", location=(-16, y, 0.12))
		pool = bpy.context.object
		pmat = flat_material("Pool%d" % i, hexc("6A5232"), emit=1.5)
		pool.data.materials.append(pmat)
		lamps.append((light, mat, i, pmat))
	for i in range(8):
		prop("HauntedTunnel", "Cedar", (-70 - (i % 3) * 20, i * 60 - 100, 0), i * 0.9, 1.0)
	camera((10, -170, 14), (-20, 120, 10), lens=28)
	flick = dict(Depth=0.15, Speed=4, Dropout=0.03)

	def flicker(t, seed):
		s = t * flick["Speed"] + seed * 17.31
		n = math.sin(s) * 0.5 + math.sin(s * 2.37 + 1.1) * 0.3 + math.sin(s * 5.11 + 2.3) * 0.2
		k = 1 - flick["Depth"] * (0.5 + 0.5 * n)
		window = math.floor(t / 0.12)
		h = math.sin(window * 12.9898 + seed * 78.233) * 43758.5453
		if h - math.floor(h) < flick["Dropout"] * 8:  # dropouts made 8x likelier so the 12 frames show one
			k = 0.08
		return max(0, min(1, k))

	for f in range(12):
		t = f * 0.12 + 3
		for light, mat, seed, pmat in lamps:
			k = flicker(t, (seed + 1) * 0.618)
			light.energy = 400000 * k
			for m, strength in ((mat, 8), (pmat, 1.5)):
				b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
				b.inputs["Emission Strength"].default_value = strength * k
		render(os.path.join(FRAMES, name, "f%02d.png" % f))


def previews(names):
	jobs = {
		"smoke_demoncastle": lambda: preview_smoke(
			"smoke_demoncastle", "2A1A30", "2A2230", "DemonCastle",
			[("Smoke", (-160, 260, 0), 0, 1), ("RuinB", (90, 160, 0), 1.2, 1), ("Wyvern", (120, 420, 90), 0.3, 1)],
			[("SmokeColumn", "Smoke", (0, 0.7, 0), ("7A2A6A", "241C28")),
			 ("Embers", "RuinB", (0, 0.6, 0), ("FF5FB8", "FF9A3A")),
			 ("RubbleSmoke", "RuinB", (0, 0.9, 0), ("5A2A52", "2A2230"))],
			(0, -120, 12), (-20, 200, 80), sun=2.0, sun_color="FFB0D0"),
		"smoke_kaijubase": lambda: preview_smoke(
			"smoke_kaijubase", "A8C4DC", "8A8478", "KaijuBase",
			[("Smoke", (-150, 300, 0), 0, 1), ("Rubble", (70, 120, 0), 0.5, 1), ("Rubble", (-60, 60, 0), 2.0, 1)],
			[("SmokeColumn", "Smoke", (0, 0.7, 0), ("8C8884", "B8B4AE")),
			 ("RubbleSmoke", "Rubble", (0, 0.6, 0), ("8A8580", "ADA8A2"))],
			(0, -110, 12), (-20, 200, 70)),
		"smoke_elvenplains": lambda: preview_smoke(
			"smoke_elvenplains", "9FC4E0", "6FA656", "ElvenPlains",
			[("Cottage", (-70, 90, 0), 0.4, 1), ("Cottage", (-110, 170, 0), 2.2, 1), ("Forest", (90, 160, 0), 0.0, 1), ("Pine", (60, 60, 0), 0, 1)],
			[("Chimney", "Cottage", (0.35, 1, 0.2), ("E4E2DA", "F4F4F0")),
			 ("GroundHaze", "Forest", (0, -0.85, 0), ("E6F0E6", "F2F6F0"))],
			(0, -60, 10), (-20, 150, 25)),
		"steam_deviltokyo": lambda: preview_smoke(
			"steam_deviltokyo", "141A2C", "2A2C30", "DevilTokyo",
			[("Konbini", (-55, 70, 0), 1.57, 1), ("ShopHouse", (60, 110, 0), -1.57, 1), ("CrossWire", (0, 140, 0), 0, 1)],
			[("Steam", "Konbini", (0.4, 1, 0.3), ("D8DEE6", "EEF2F6")),
			 ("Steam", "ShopHouse", (-0.3, 1, 0.4), ("D0D6DE", "E8ECF0"))],
			(0, -40, 8), (0, 120, 25), sun=0.8, sun_color="BFD0FF"),
		"haze_hauntedtunnel": lambda: preview_smoke(
			"haze_hauntedtunnel", "1A2238", "26342A", "HauntedTunnel",
			[("Cedar", (-50 - (i % 3) * 22, i * 45, 0), i * 0.7, 1) for i in range(8)] + [("Cedar", (55 + (i % 2) * 20, i * 50 + 20, 0), i, 1) for i in range(6)],
			[("GroundHaze", "Cedar", (0, -0.95, 0), ("8FA6C0", "A8BAD0"))],
			(0, -60, 9), (0, 150, 10), sun=1.0, sun_color="BFD0FF"),
		"lava_monsterden": lambda: preview_smoke(
			"lava_monsterden", "3A2420", "3A3034", "MonsterDen",
			[("LavaChasm", (-90, 120, 0), 1.57, 1), ("RockPillar", (70, 90, 0), 0, 1), ("RockPillar", (-40, 220, 0), 0, 1)],
			[("Steam", "LavaChasm", (0, 0, 0), ("FF9A4A", "7A5A50"), (0.8, 0, 0.5)),
			 ("Embers", "LavaChasm", (0, 0, 0), ("FF7A2A", "FFC060"), (0.8, 0, 0.5)),
			 ("GroundHaze", "RockPillar", (0, -0.95, 0), ("5A5260", "6A6270"))],
			(10, -10, 22), (-70, 120, 10), sun=2.0, sun_color="FF9A6A"),
		"smoke_ruinedcityz": lambda: preview_smoke(
			"smoke_ruinedcityz", "B8C8D8", "8A8278", "RuinedCityZ",
			[("Collapsed", (-90, 140, 0), 0.3, 1), ("Rubble", (60, 80, 0), 1, 1), ("Rubble", (-50, 40, 0), 2, 1)],
			[("RubbleSmoke", "Collapsed", (0, 0.5, 0), ("9A8E80", "BEB3A4")),
			 ("GroundHaze", "Rubble", (0, -0.8, 0), ("B8AC98", "CFC6B6"))],
			(0, -70, 12), (-20, 150, 30)),
		"smoke_antisland": lambda: preview_smoke(
			"smoke_antisland", "E09070", "C8B080", "AntIsland",
			[("Camp", (-90, 130, 0), 0.5, 1), ("ThatchHouse", (60, 80, 0), 1.2, 1), ("ThatchHouse", (80, 160, 0), 2.5, 1)],
			[("RubbleSmoke", "Camp", (0, 0.3, 0), ("6E6258", "A89A8A")),
			 ("Chimney", "ThatchHouse", (0.3, 1, 0), ("C9BFB2", "E0D8CE"))],
			(0, -50, 10), (0, 140, 20), sun=2.5, sun_color="FFB080"),
		"motes_goldencity": lambda: preview_smoke(
			"motes_goldencity", "F0B070", "C8A050", "GoldenCity",
			[("Square", (0, 120, 0), 0, 1)],
			[("Motes", "Square", (0, -0.2, 0), ("FFD36A", "FFF0B0"), (0.7, 0, 0.7))],
			(0, 70, 8), (0, 125, 6), sun=2.5, sun_color="FFC080", road_on=False),
		"haze_hellgate": lambda: preview_smoke(
			"haze_hellgate", "A02818", "B8AA8C", "HellGate",
			[("Hill", (-120, 200, 0), 0, 1), ("Hill", (110, 260, 0), 1, 1), ("SkyDoor", (-40, 180, 90), 0.3, 1)],
			[("GroundHaze", "Hill", (0, -0.6, 0), ("C8504A", "D8786A"))],
			(0, -60, 10), (0, 200, 30), sun=2.5, sun_color="FFB0A0"),
		"dragon_drake": lambda: preview_drake(),
		"dragon_eel": lambda: preview_eel(),
		"motion_pine_sway": lambda: preview_motion(
			"motion_pine_sway", "9FC4E0", "6FA656", "ElvenPlains", "Pine", "Sway", 8, 30, (0, -40, 10), (-50, 60, 15), 2, 4.6),
		"motion_ship_bob": lambda: preview_motion(
			"motion_ship_bob", "E09070", "3A6A80", "AntIsland", "Ship", "Bob", 4, 60, (0, -60, 8), (-50, 40, 4), 0.8, 5, roll=3, sun=2.5),
		"motion_skydoor_bob": lambda: preview_motion(
			"motion_skydoor_bob", "A02818", "B8AA8C", "HellGate", "SkyDoor", "Bob", 6, 50, (0, -70, 12), (-60, 60, 60), 4, 9, roll=1.5, lift=55),
		"motion_flicker": lambda: preview_flicker(),
	}
	for name in names or list(jobs):
		print("TRACKFX PREVIEW", name)
		jobs[name]()


def run(args):
	global PROPS
	if "--props" in args:
		PROPS = args[args.index("--props") + 1]
	if not args or args[0] == "meshes":
		clear()
		_, _, _, _, info = build_meshes(export=True)
		info = turnaround()
		return info
	if args[0] == "previews":
		names = [a for a in args[1:] if not a.startswith("--") and a != PROPS]
		previews(names)


if __name__ == "__main__":
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	run(argv)
