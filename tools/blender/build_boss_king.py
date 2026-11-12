# The Golden King (boss_king) review renders, headless (design doc 4.37 Third boss; docs/BOSS_EVENT_SPEC.md "The Golden King"):
#   python3 tools/blender/paint/atlas.py boss_king
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- build side_king side_mage
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py -- sheet
#   Blender -b --factory-startup --python tools/blender/build_boss_king.py -- ea_sheet
# Writes assets/characters_avatar/boss_king/review/{front,side,back,three_quarter}.png, review/ea/*.png (Ea alone, in hand,
# raised), boss_king.blend and build/boss_event/boss_king.json; sheet: assets/characters_avatar/review/boss_king_contact_sheet.png
# from the 12 boss_king, side_king and side_mage renders; ea_sheet: review/boss_king_ea_sheet.png (Ea, before/after).
# He is a painted R15 character (paint/char_boss_king.py) merged into the 6 runner parts; the Key is its own object (origin at
# the belt) and Ea an empty at the grip whose drums are its own meshes (paint/ea_sword.py), so they animate on their own.
# The Sidekick side_king is this build with small=True (tools/blender/sidekicks/side_king.py). Nothing here uploads.
import importlib
import json
import math
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
import ea_sword  # noqa: E402

CID = "boss_king"
RDIR = os.path.join(build_avatar.OUT, CID, "review")
EA_RDIR = os.path.join(RDIR, "ea")
TMP = os.path.join(os.path.dirname(os.path.dirname(HERE)), "build", "boss_event")
# own object: name prefix of its built pieces, pivot (the key's ring at the belt)
LOOSE = {"Key": ("UpperTorso_Key", (1.2, 0.1, 2.35))}
# Ea: an empty at the grip in the right hand; its meshes (paint/ea_sword.py PARTS, the Sidekick the first two) share the pivot,
# so each drum spins about the empty's z. The ribbons (material index 1) get the emissive glow material.
EA_PIVOT = (-1.5, -0.62, 2.05)
EA_VIEWS = {"ea_front": (0, -1, 0.05), "ea_three_quarter": (0.65, -0.75, 0.15), "ea_side": (1, 0, 0.05)}
SHEET = (("boss_king", "boss_king"), ("side_king", "side_king"), ("side_mage", "side_mage"))


def _glow_mat():
	m = bpy.data.materials.new("Ea_Glow")
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (0.9, 0.08, 0.06, 1)
	bsdf.inputs["Emission Color"].default_value = (1.0, 0.12, 0.08, 1)
	bsdf.inputs["Emission Strength"].default_value = 1.4
	return m


def build(cid=CID, small=False):
	"""The king (or his Sidekick, small) under an empty root named cid: 6 merged parts, the Key, and Ea (an empty whose
	meshes are its children). Returns root, objects (Ea = the empty, its meshes under their own names), tris per object."""
	build_avatar.reset()
	bpy.context.preferences.filepaths.save_version = 0
	importlib.import_module("char_" + CID).SMALL = small
	build_avatar.build(CID, build_avatar.load_data()[CID])
	loose = {n: bm.join(n, *v) for n, v in LOOSE.items()}
	ea_parts = ea_sword.PARTS[:2] if small else ea_sword.PARTS
	ea = {n: bm.join(n, "RightHand_" + n.replace("_", ""), EA_PIVOT) for n in ea_parts}
	merged, _ = avatar_merge.merge(CID, keep=list(loose.values()) + list(ea.values()))
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
	hilt = bpy.data.objects.new("Ea", None)
	hilt.location = EA_PIVOT
	hilt.parent = root
	bpy.context.scene.collection.objects.link(hilt)
	objs["Ea"] = hilt
	glow = _glow_mat()
	for name, o in ea.items():
		o.data.materials.append(mat)
		o.data.materials.append(glow)
		o.parent = hilt
		o.location = (0, 0, 0)
		objs[name] = o
	bpy.context.view_layer.update()
	tris = {n: sum(len(p.vertices) - 2 for p in o.data.polygons) for n, o in objs.items() if o.type == "MESH"}
	return root, objs, tris


def pose(objs, rest, raised=False):
	"""Standing: Ea upright in the right hand, the arm a little forward to hold it clear of the skirt plates.
	raised: the right arm straight up and a little forward, Ea along it, so the pillar towers over him."""
	for n, o in objs.items():
		if o.parent is not objs["Ea"]:  # Ea's meshes follow the empty
			o.matrix_world = rest[n]
	arm = bm.turn(bm.JOINT["RightArm"], euler=(-160 if raised else -38, 0, 0))
	objs["RightArm"].matrix_world = arm @ rest["RightArm"]
	tilt = Matrix.Rotation(math.radians(20 if raised else 0), 4, "X")  # raised: the pillar leans a little forward
	objs["Ea"].matrix_world = Matrix.Translation(arm @ bm.HAND["RightArm"]) @ tilt
	bpy.context.view_layer.update()


def _page(name, title, rows, height):
	"""A labelled page of renders, rasterised by headless Chrome as build_boss_event's sheet is. rows = (heading, [(png, caption)])."""
	out = os.path.join(build_avatar.OUT, "review", name + ".png")
	os.makedirs(os.path.dirname(out), exist_ok=True)
	body = "".join(
		f"<h2>{h}</h2><div class=row>" + "".join(f'<figure><img src="file://{png}"><figcaption>{cap}</figcaption></figure>' for png, cap in cells) + "</div>" for h, cells in rows
	)
	html = os.path.join(TMP, name + ".html")
	with open(html, "w") as f:
		f.write(
			"<!doctype html><html><head><style>body{margin:0;padding:24px;background:#1c1d24;color:#eee;font:16px sans-serif;width:2512px}"
			"h2{margin:8px 0 4px;font-size:26px}.row{display:flex;gap:16px}figure{margin:0;width:612px}img{width:612px;height:612px;object-fit:contain;background:#c7cbd3}"
			f"figcaption{{text-align:center;padding:4px 0 12px;font-size:18px}}</style></head><body><h1>{title}</h1>{body}</body></html>"
		)
	subprocess.run(
		[bm.be.CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={TMP}/chrome", "--force-device-scale-factor=1", f"--window-size=2560,{height}", f"--screenshot={out}", "file://" + html],
		check=True,
		capture_output=True,
		timeout=180,
	)
	print("SHEET", out)


def sheet():
	"""One labelled page of the 12 renders (model, view, triangles)."""
	rows = []
	for cid, _ in SHEET:
		with open(os.path.join(TMP, cid + ".json")) as f:
			tris = json.load(f)["tris"]
		cells = [(os.path.join(build_avatar.OUT, cid, "review", view + ".png"), f"{cid} / {view} / {tris:,} tris") for view in ("front", "three_quarter", "side", "back")]
		rows.append((f"{cid}: {tris:,} triangles", cells))
	_page("boss_king_contact_sheet", "The Golden King (boss_king), side_king, side_mage: review renders, no upload", rows, 2200)


def ea_sheet():
	"""Ea alone and in hand (owner 2026-11-11: massive), and the king's front before and after the Ea and angular-armor pass."""
	with open(os.path.join(TMP, CID + ".json")) as f:
		d = json.load(f)
	ea = [(os.path.join(EA_RDIR, v + ".png"), f"Ea / {v[3:]} / {d['ea']} tris") for v in ("ea_front", "ea_three_quarter", "ea_side", "ea_detail_drums")]
	held = [(os.path.join(EA_RDIR, v + ".png"), f"boss_king / {v[10:]} / {d['tris']:,} tris") for v in ("king_with_ea_front", "king_with_ea_raised")]
	held += [(os.path.join(RDIR, "boss_king_front_before.png"), "boss_king / front / before (2026-11-11)"), (os.path.join(RDIR, "front.png"), f"boss_king / front / after: angular armor, Ea {ea_sword.BLADE} blade")]
	_page("boss_king_ea_sheet", "The Golden King: Ea redesign and angular armor, review renders, no upload", [(f"Ea: {d['ea']} triangles (budget 700)", ea), ("In hand; armor before and after", held)], 1500)


def main():
	if sys.argv[-1] == "sheet":
		sheet()
		return
	if sys.argv[-1] == "ea_sheet":
		ea_sheet()
		return
	root, objs, tris = build()
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build_avatar.OUT, CID, CID + ".blend"))
	os.makedirs(EA_RDIR, exist_ok=True)
	os.makedirs(TMP, exist_ok=True)
	cam = build_avatar.setup_render(bpy.context.scene)
	cam.data.lens = 70
	rest = {n: o.matrix_world.copy() for n, o in objs.items()}
	pose(objs, rest)
	# the main views frame the king and the whole pillar (Ea tops out near z 12.4 standing)
	for view, d in build_avatar.VIEWS.items():
		bm.render(cam, os.path.join(RDIR, view + ".png"), d, target=(0, 0, 6.2), dist=28)
	bm.render(cam, os.path.join(EA_RDIR, "king_with_ea_front.png"), build_avatar.VIEWS["front"], target=(0, 0, 6.2), dist=28)
	pose(objs, rest, raised=True)
	bm.render(cam, os.path.join(EA_RDIR, "king_with_ea_raised.png"), build_avatar.VIEWS["three_quarter"], target=(0, -1.5, 8.2), dist=36)
	# Ea alone, upright at the origin on neutral grey, and a close look at the drums
	pose(objs, rest)
	for n, o in objs.items():
		o.hide_render = o.type == "MESH" and o.parent is not objs["Ea"]
	objs["Ea"].matrix_world = Matrix.Translation((0, 0, 0.35))
	bpy.context.view_layer.update()
	for view, d in EA_VIEWS.items():
		bm.render(cam, os.path.join(EA_RDIR, view + ".png"), d, target=(0, 0, 5.4), dist=24)
	bm.render(cam, os.path.join(EA_RDIR, "ea_detail_drums.png"), (0.4, -1, 0.1), target=(0, 0, 6.2), dist=9)
	for o in objs.values():
		o.hide_render = False
	pose(objs, rest)
	total = sum(tris.values())
	ea_tris = sum(v for n, v in tris.items() if n.startswith("Ea_"))
	with open(os.path.join(TMP, CID + ".json"), "w") as f:
		json.dump({"tris": total, "largest_mesh": max(tris.values()), "parts": tris, "ea": ea_tris}, f, indent=1)
	print("TRIS", CID, total, "Ea", ea_tris, tris)
	assert ea_tris <= 700, f"Ea: {ea_tris} tris over its 700 budget"
	assert total <= 3000, f"{CID}: {total} tris over the 3,000 budget"


if __name__ == "__main__":
	main()
