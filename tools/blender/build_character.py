# Build one draft character and its review renders, headless:
#   Blender -b --factory-startup --python tools/blender/build_character.py -- <id> [<id> ...]
#   Blender -b --factory-startup --python tools/blender/build_character.py -- --sheet   (contact sheet of all ids)
# Data: tools/blender/characters.json (keyed by Id). Output: assets/characters/<id>/ (docs/CHARACTER_GACHA_SPEC.md).
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import chibi_base  # noqa: E402
from chibi_base import R15_PARTS, build_body, build_face  # noqa: E402
from hair import build_hair  # noqa: E402
from outfit import build_accessories, build_outfit  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(REPO, "assets", "characters")
TRI_BUDGET = 4000  # proposed (CHARACTER_GACHA_SPEC Draft pipeline)
VIEWS = {"front": (0, -1, 0.15), "side": (1, 0, 0.15), "back": (0, 1, 0.15), "three_quarter": (0.7, -0.7, 0.25)}


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	chibi_base._mats.clear()


def set_engine(scene):
	for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
		try:
			scene.render.engine = eng
			return
		except TypeError:
			pass
	raise RuntimeError("no EEVEE engine")


def setup_render(scene, res=512):
	set_engine(scene)
	scene.render.resolution_x = res
	scene.render.resolution_y = res
	scene.render.film_transparent = False
	scene.render.use_freestyle = True
	scene.render.line_thickness_mode = "ABSOLUTE"
	scene.render.line_thickness = 1.4
	world = bpy.data.worlds.new("W")
	bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
	bg.inputs["Color"].default_value = (0.82, 0.84, 0.88, 1)
	scene.world = world
	try:
		scene.view_settings.view_transform = "Standard"
	except TypeError:
		pass
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 3
	sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(-30))
	scene.collection.objects.link(sun)


def tri_count(objs):
	return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == "MESH")


def build(cid, c):
	reset()
	parts = build_body(c)
	build_face(c, parts["Head"])
	build_hair(cid, c["hair"], parts["Head"], c.get("head_scale", 1.0))
	build_outfit(c, parts)
	build_accessories(c, parts)
	root = bpy.data.objects.new(cid, None)  # empty root named by Id only
	bpy.context.scene.collection.objects.link(root)
	for name in R15_PARTS:
		parts[name].parent = root
	missing = [n for n in R15_PARTS if bpy.data.objects.get(n) is None]
	assert not missing, f"{cid}: missing R15 parts {missing}"
	meshes = [o for o in bpy.data.objects if o.type == "MESH"]
	orphans = [o.name for o in meshes if o.parent is None]
	assert not orphans, f"{cid}: unparented meshes {orphans}"
	tris = tri_count(meshes)
	assert tris <= TRI_BUDGET, f"{cid}: {tris} tris > {TRI_BUDGET}"
	return root, tris


def frame_camera(scene, direction, height, dist):
	cam = scene.camera
	x, y, z = direction
	n = math.sqrt(x * x + y * y + z * z)
	cam.location = (x / n * dist, y / n * dist, height / 2 + z / n * dist)
	look = (0, 0, height * 0.5)
	dx, dy, dz = look[0] - cam.location[0], look[1] - cam.location[1], look[2] - cam.location[2]
	cam.rotation_euler = (math.atan2(math.hypot(dx, dy), -dz), 0, math.atan2(dy, dx) - math.pi / 2)


def render_views(cid):
	scene = bpy.context.scene
	setup_render(scene)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	scene.collection.objects.link(cam)
	scene.camera = cam
	cam.data.lens = 60
	top = max((o.matrix_world.to_translation().z for o in bpy.data.objects if o.type == "MESH"), default=3.5)
	height = max(3.6, top + 0.6)
	rdir = os.path.join(OUT, cid, "review")
	os.makedirs(rdir, exist_ok=True)
	for view, d in VIEWS.items():
		frame_camera(scene, d, height, height * 2.0)
		scene.render.filepath = os.path.join(rdir, view + ".png")
		bpy.ops.render.render(write_still=True)


def build_one(cid, data):
	bpy.context.preferences.filepaths.save_version = 0  # no .blend1 backups
	c = data[cid]
	root, tris = build(cid, c)
	os.makedirs(os.path.join(OUT, cid), exist_ok=True)
	render_views(cid)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, cid, cid + ".blend"))
	print(f"BUILT {cid} tris={tris}")


def contact_sheet(data, cols=6, res=1800):
	"""All characters in one 3/4 render, laid out in a grid of `cols` columns."""
	reset()
	ids = list(data.keys())
	gap = 2.4
	for i, cid in enumerate(ids):
		c = data[cid]
		parts = build_body(c)
		build_face(c, parts["Head"])
		build_hair(cid, c["hair"], parts["Head"], c.get("head_scale", 1.0))
		build_outfit(c, parts)
		build_accessories(c, parts)
		root = bpy.data.objects.new(cid, None)
		bpy.context.scene.collection.objects.link(root)
		for name in R15_PARTS:
			parts[name].parent = root
			parts[name].name = f"{cid}.{name}"  # avoid name clashes in the shared sheet scene
		row, col = divmod(i, cols)
		root.location = ((col - (cols - 1) / 2) * gap, 0, -row * 4.6)  # rows stacked in Z so none hides another
		root.rotation_euler = (0, 0, math.radians(-30))
	scene = bpy.context.scene
	setup_render(scene, res)
	scene.render.resolution_y = int(res * 0.9)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	scene.collection.objects.link(cam)
	scene.camera = cam
	cam.data.type = "ORTHO"
	rows = math.ceil(len(ids) / cols)
	cam.data.ortho_scale = max(cols * gap, rows * 4.6 / 0.9) + 0.5
	cz = 1.9 - (rows - 1) * 4.6 / 2
	cam.location = (0, -50, cz + 50 * math.tan(math.radians(8)))
	cam.rotation_euler = (math.radians(82), 0, 0)
	scene.render.filepath = os.path.join(OUT, "contact_sheet.png")
	bpy.ops.render.render(write_still=True)
	print("SHEET", scene.render.filepath)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	with open(os.path.join(HERE, "characters.json")) as f:
		data = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
	if argv == ["--sheet"]:
		contact_sheet(data)
		return
	for cid in argv or list(data.keys()):
		build_one(cid, data)


main()
