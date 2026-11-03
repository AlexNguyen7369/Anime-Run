# Build Roblox-avatar style characters and review renders, headless:
#   Blender -b --factory-startup --python tools/blender/build_avatar.py -- [<id> ...]
#   Blender -b --factory-startup --python tools/blender/build_avatar.py -- --sheet
# Data: tools/blender/avatar_chars/*.json (one per series, keyed by Id). Output: assets/characters_avatar/.
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import avatar_base  # noqa: E402
import avatar_merge  # noqa: E402
from avatar_base import build_body, build_face, build_folds, build_pieces  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "characters_avatar")
TRI_BUDGET = 12000  # proposed (CHARACTER_GACHA_SPEC Avatar pipeline)
VIEWS = {"front": (0, -1, 0.1), "side": (1, 0, 0.1), "back": (0, 1, 0.1), "three_quarter": (0.65, -0.75, 0.18)}


def load_data():
	data = {}
	cdir = os.path.join(HERE, "avatar_chars")
	for fname in sorted(os.listdir(cdir)):
		with open(os.path.join(cdir, fname)) as f:
			data.update({k: v for k, v in json.load(f).items() if not k.startswith("_")})
	return data


def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	avatar_base.clear_mats()


def setup_render(scene, res=640):
	for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
		try:
			scene.render.engine = eng
			break
		except TypeError:
			pass
	scene.render.resolution_x = scene.render.resolution_y = res
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("W")
	bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
	bg.inputs["Color"].default_value = (0.78, 0.8, 0.84, 1)
	bg.inputs["Strength"].default_value = 0.8
	scene.world = world
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	sun.data.energy = 2.2
	sun.data.angle = math.radians(25)
	sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-25))
	scene.collection.objects.link(sun)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def build(cid, c):
	parts = build_body(c)
	build_face(c, parts["Head"])
	build_folds(cid, c, parts)
	build_pieces(c, parts)
	return parts


def placed(cid, c, keep=()):
	"""Build + merge, the 6 parts linked at their rig positions under an empty root named by Id."""
	build(cid, c)
	merged, _ = avatar_merge.merge(cid, keep)
	root = bpy.data.objects.new(cid, None)
	bpy.context.scene.collection.objects.link(root)
	for name, o in merged.items():
		o.location = avatar_merge.GROUPS[name][0]
		o.parent = root
		bpy.context.scene.collection.objects.link(o)
	return root, sum(len(o.data.polygons) for o in merged.values())


def aim(cam, target):
	dx, dy, dz = (target[i] - cam.location[i] for i in range(3))
	cam.rotation_euler = (math.atan2(math.hypot(dx, dy), -dz), 0, math.atan2(dy, dx) - math.pi / 2)


def build_one(cid, c):
	reset()
	bpy.context.preferences.filepaths.save_version = 0
	_, tris = placed(cid, c)
	assert tris <= TRI_BUDGET, f"{cid}: {tris} tris > {TRI_BUDGET}"
	cam = setup_render(bpy.context.scene)
	cam.data.lens = 70
	rdir = os.path.join(OUT, cid, "review")
	os.makedirs(rdir, exist_ok=True)
	for view, (x, y, z) in VIEWS.items():
		n = math.sqrt(x * x + y * y + z * z)
		cam.location = (x / n * 16, y / n * 16, 3.1 + z / n * 16)
		aim(cam, (0, 0, 3.1))
		bpy.context.scene.render.filepath = os.path.join(rdir, view + ".png")
		bpy.ops.render.render(write_still=True)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, cid, cid + ".blend"))
	print(f"BUILT {cid} tris={tris}")


def contact_sheet(data, cols=6, res=1800):
	reset()
	ids = list(data)
	cols = min(cols, len(ids))
	gap, row_h = 4.4, 7.4
	rows = math.ceil(len(ids) / cols)
	for i, cid in enumerate(ids):
		root, _ = placed(cid, data[cid], keep=list(bpy.data.objects))
		row, col = divmod(i, cols)
		root.location = ((col - (cols - 1) / 2) * gap, 0, -row * row_h)
		root.rotation_euler = (0, 0, math.radians(-25))
	scene = bpy.context.scene
	cam = setup_render(scene, res)
	scene.render.resolution_y = int(res * max(0.5, rows * row_h / (cols * gap)))
	cam.data.type = "ORTHO"
	cam.data.ortho_scale = max(cols * gap, rows * row_h) + 0.5
	cam.location = (0, -50, 3.1 - (rows - 1) * row_h / 2)
	cam.rotation_euler = (math.radians(90), 0, 0)
	scene.render.filepath = os.path.join(OUT, "contact_sheet.png")
	bpy.ops.render.render(write_still=True)
	print("SHEET", scene.render.filepath)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	data = load_data()
	if argv == ["--sheet"]:
		contact_sheet(data)
		return
	for cid in argv or list(data):
		build_one(cid, data[cid])


if __name__ == "__main__":  # export_avatar.py imports build()
	main()
