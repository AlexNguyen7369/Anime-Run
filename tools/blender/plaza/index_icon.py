# The Index HUD icon, drawn in-house (design doc 4.24, WORLD_REDESIGN_SPEC 1: no car art): a fan of three character cards.
# Blender -b --factory-startup --python tools/blender/plaza/index_icon.py -> assets/ui/IndexIcon.png
import math
import os

import bpy
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "ui", "IndexIcon.png")


def material(name, hexcol, emit=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	col = [((int(hexcol[i : i + 2], 16) / 255 + 0.055) / 1.055) ** 2.4 for i in (0, 2, 4)] + [1]
	b.inputs["Base Color"].default_value = col
	b.inputs["Roughness"].default_value = 0.35
	if emit:
		b.inputs["Emission Color"].default_value = col
		b.inputs["Emission Strength"].default_value = emit
	return m


def card(x, tilt, depth, hexcol, rim):
	bpy.ops.mesh.primitive_cube_add(size=1)
	o = bpy.context.object
	o.scale = (1.7, 0.12, 4.0)
	o.location = (x, depth, 0)
	o.rotation_euler = (0, math.radians(tilt), 0)
	bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
	bev = o.modifiers.new("b", "BEVEL")
	bev.width, bev.segments = 0.16, 4
	o.data.materials.append(material("rim" + hexcol, rim))
	bpy.ops.mesh.primitive_cube_add(size=1)
	f = bpy.context.object
	f.scale = (1.42, 0.03, 3.7)
	f.location = (x, depth - 0.07, 0)
	f.rotation_euler = (0, math.radians(tilt), 0)
	bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)
	bev = f.modifiers.new("b", "BEVEL")
	bev.width, bev.segments = 0.1, 3
	f.data.materials.append(material("face" + hexcol, hexcol))
	return f


def star(x, depth, tilt, size):
	verts = []
	for i in range(10):
		a = math.pi / 2 + i * math.pi / 5
		r = size if i % 2 == 0 else size * 0.45
		verts.append((r * math.cos(a), r * math.sin(a)))
	me = bpy.data.meshes.new("star")
	me.from_pydata([(v[0], 0, v[1]) for v in verts], [], [list(range(10))])
	o = bpy.data.objects.new("star", me)
	bpy.context.scene.collection.objects.link(o)
	o.location = (x, depth, 0)
	o.rotation_euler = (0, math.radians(tilt), 0)
	me.materials.append(material("star", "FFFFFF", 1.2))


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
card(-1.2, -16, 0.3, "2F6FE0", "F4F7FF")
card(1.2, 16, 0.3, "9A4BE0", "F4F7FF")
card(0, 0, 0, "F0A020", "FFFFFF")
star(0, -0.13, 0, 0.82)
scene.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT") if e in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items])
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.8
sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(70), 0, math.radians(-20))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 5.1
cam.location = Vector((0, -8, 0))
cam.rotation_euler = (math.pi / 2, 0, 0)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.filepath = OUT
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
bpy.ops.render.render(write_still=True)
