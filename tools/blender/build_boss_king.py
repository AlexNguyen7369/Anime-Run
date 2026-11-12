# The Golden King (boss_king) review renders, headless (design doc 4.37 Third boss; docs/BOSS_EVENT_SPEC.md "The Golden King"):
#   python3 tools/blender/paint/atlas.py boss_king
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- build side_king side_mage
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py -- sheet
# Writes assets/characters_avatar/boss_king/review/{front,side,back,three_quarter}.png, boss_king.blend and build/boss_event/boss_king.json;
# sheet: assets/characters_avatar/review/boss_king_contact_sheet.png from the 12 boss_king, side_king and side_mage renders.
# He is a painted R15 character (paint/char_boss_king.py) merged into the 6 runner parts; Ea and the Key stay their own objects,
# origin at the grip and the belt, so they animate on their own. The Sidekick side_king is this build with small=True
# (tools/blender/sidekicks/side_king.py). Nothing here uploads.
import importlib
import json
import os
import subprocess
import sys

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402
import build_boss_mage as bm  # noqa: E402

CID = "boss_king"
RDIR = os.path.join(build_avatar.OUT, CID, "review")
TMP = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "boss_event")
# own object: name prefix of its built pieces, pivot (Ea grip in the right hand, the key's ring at the belt)
LOOSE = {"Ea": ("RightHand_Ea", (-1.5, -0.62, 2.05)), "Key": ("UpperTorso_Key", (1.2, 0.1, 2.35))}
SHEET = (("boss_king", "boss_king"), ("side_king", "side_king"), ("side_mage", "side_mage"))


def build(cid=CID, small=False):
	"""The king (or his Sidekick, small) under an empty root named cid: 6 merged parts plus Ea and Key. Returns root, objects, tris."""
	build_avatar.reset()
	bpy.context.preferences.filepaths.save_version = 0
	importlib.import_module("char_" + CID).SMALL = small
	build_avatar.build(CID, build_avatar.load_data()[CID])
	loose = {n: bm.join(n, *v) for n, v in LOOSE.items()}
	merged, _ = avatar_merge.merge(CID, keep=list(loose.values()))
	root = bpy.data.objects.new(cid, None)
	bpy.context.scene.collection.objects.link(root)
	mat = merged["Head"].data.materials[0]
	objs = {}
	for name, o in merged.items():
		o.location = avatar_merge.GROUPS[name][0]
		o.parent = root
		bpy.context.scene.collection.objects.link(o)
		objs[name] = o
	for name, o in loose.items():
		o.data.materials.append(mat)
		o.parent = root
		objs[name] = o
	bpy.context.view_layer.update()
	tris = {n: sum(len(p.vertices) - 2 for p in o.data.polygons) for n, o in objs.items()}
	return root, objs, tris


def pose(objs, rest):
	"""Standing: Ea upright in the right hand, the arm a little forward to hold it clear of the skirt plates."""
	for n, o in objs.items():
		o.matrix_world = rest[n]
	arm = bm.turn(bm.JOINT["RightArm"], euler=(-28, 0, 0))
	objs["RightArm"].matrix_world = arm @ rest["RightArm"]
	objs["Ea"].matrix_world = Matrix.Translation(arm @ bm.HAND["RightArm"])
	bpy.context.view_layer.update()


def sheet():
	"""One labelled page of the 12 renders (model, view, triangles), rasterised by headless Chrome as build_boss_event's sheet is."""
	out = os.path.join(build_avatar.OUT, "review", "boss_king_contact_sheet.png")
	os.makedirs(os.path.dirname(out), exist_ok=True)
	rows = []
	for cid, _ in SHEET:
		with open(os.path.join(TMP, cid + ".json")) as f:
			tris = json.load(f)["tris"]
		cells = "".join(
			f'<figure><img src="file://{os.path.join(build_avatar.OUT, cid, "review", view + ".png")}"><figcaption>{cid} / {view} / {tris:,} tris</figcaption></figure>'
			for view in ("front", "three_quarter", "side", "back")
		)
		rows.append(f"<h2>{cid}: {tris:,} triangles</h2><div class=row>{cells}</div>")
	html = os.path.join(TMP, "boss_king_sheet.html")
	with open(html, "w") as f:
		f.write(
			"<!doctype html><html><head><style>body{margin:0;padding:24px;background:#1c1d24;color:#eee;font:16px sans-serif;width:2512px}"
			"h2{margin:8px 0 4px;font-size:26px}.row{display:flex;gap:16px}figure{margin:0;width:612px}img{width:612px;height:612px;object-fit:contain;background:#c7cbd3}"
			"figcaption{text-align:center;padding:4px 0 12px;font-size:18px}</style></head><body><h1>The Golden King (boss_king), side_king, side_mage: review renders, no upload</h1>"
			+ "".join(rows)
			+ "</body></html>"
		)
	subprocess.run(
		[bm.be.CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={TMP}/chrome", "--force-device-scale-factor=1", "--window-size=2560,2200", f"--screenshot={out}", "file://" + html],
		check=True,
		capture_output=True,
		timeout=180,
	)
	print("SHEET", out)


def main():
	if sys.argv[-1] == "sheet":
		sheet()
		return
	root, objs, tris = build()
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build_avatar.OUT, CID, CID + ".blend"))
	os.makedirs(RDIR, exist_ok=True)
	os.makedirs(TMP, exist_ok=True)
	cam = build_avatar.setup_render(bpy.context.scene)
	cam.data.lens = 70
	rest = {n: o.matrix_world.copy() for n, o in objs.items()}
	pose(objs, rest)
	for view, d in build_avatar.VIEWS.items():
		bm.render(cam, os.path.join(RDIR, view + ".png"), d)
	total = sum(tris.values())
	with open(os.path.join(TMP, CID + ".json"), "w") as f:
		json.dump({"tris": total, "largest_mesh": max(tris.values()), "parts": tris}, f, indent=1)
	print("TRIS", CID, total, tris)
	assert total <= 3000, f"{CID}: {total} tris over the 3,000 budget"


if __name__ == "__main__":
	main()
