# Export avatars for Roblox, headless (docs/CHARACTER_GACHA_SPEC.md "Avatar pipeline"):
#   Blender -b --factory-startup --python tools/blender/export_avatar.py -- [<id> ...]
# Writes build/avatar_glb/<id>.glb: 6 meshes named after the RunnerFactory parts, one painted palette texture.
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "avatar_glb")


def export(cid, c):
	build_avatar.reset()
	build_avatar.build(cid, c)
	merged, sizes = avatar_merge.merge(cid)
	tris = sum(len(o.data.polygons) for o in merged.values())
	assert tris <= build_avatar.TRI_BUDGET, f"{cid}: {tris} tris"
	for name, o in merged.items():
		o.name = name  # the originals held these names until now
		bpy.context.scene.collection.objects.link(o)
	os.makedirs(OUT, exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, cid + ".glb"), export_format="GLB", export_yup=True, export_apply=True, export_animations=False)
	with open(os.path.join(OUT, cid + ".json"), "w") as f:
		json.dump(sizes, f)
	print(f"EXPORTED {cid} tris={tris}")


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	data = build_avatar.load_data()
	for cid in argv or list(data):
		export(cid, data[cid])


main()
