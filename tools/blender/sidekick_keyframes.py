# Sidekick attack key poses for owner review (design doc 4.37, SIDEKICK_SPEC). No in-betweens, no bake, no effects. Headless:
#   Blender -b --factory-startup --python tools/blender/sidekick_keyframes.py -- [side_ant side_pig ...]
# Reads tools/blender/sidekicks/<id>.attack.json. Writes assets/characters_avatar/<id>/keyframes/{keys.json, attack_slices.png}.
# The .blend is only read, never saved. Render marks stay out of keys.json.
#
# Data, same axes and rotation meaning as boss_keyframes.py (front is -Y, +X is the character's left, Z up):
#   movement  Walk or Fly. Walk: each body's root height is solved so its lowest leg stands on the floor, unless a key sets "air".
#   title, end  Move starts in rest at 0 s and is back in rest at "end".
#   keys      3-5 of: name, t, desc, parts {part: XYZ Euler degrees, replacing rest}, root {root part: offset in model units}.
#             Exactly one key is named Release. Only it may hold markers.
#   view      Optional main view direction, for a move whose action is on the character's right. Default three_quarter.
#   markers   Flat labelled sketch of an effect: label, shape, at, r, rgb, optional on (part, so "at" follows it), spin, sx, sy.
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boss_keyframes as bk  # noqa: E402
import build_avatar  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
IDS = "side_chain side_wyvern side_knight side_pig side_crow side_reindeer side_dogs side_ant side_reaper side_fist side_curse side_fox".split()
bk.TMP = os.path.join(REPO, "build", "sidekick_keyframes", str(os.getpid()))

MAIN, SIDE, COLS, STRIP_H, HEAD_H = (620, 680), (280, 250), 3, 104, 96
CELL_W = MAIN[0] + SIDE[0]
HIT_EVERY = 1.5
MIN_CHANGE = 12  # degrees some part must turn between neighbouring keys
ROOT_LIMIT = 0.16  # of the model's height


def outline(shape):
	def ring(n, f):
		return [(math.cos(2 * math.pi * i / n) * f(i), math.sin(2 * math.pi * i / n) * f(i)) for i in range(n)]

	if shape == "disc":
		return ring(32, lambda i: 1)
	if shape == "saw":
		return ring(24, lambda i: 1 if i % 2 else 0.72)
	if shape == "burst":
		return ring(16, lambda i: 1 if i % 2 else 0.5)
	if shape == "rect":
		return [(-1, -1), (1, -1), (1, 1), (-1, 1)]
	if shape == "cone":  # narrow end at the origin, opening along +X
		return [(0, 0), (2, -0.8), (2.3, 0), (2, 0.8)]
	if shape == "crescent":  # opens toward +X, bulges toward -X
		outer = [(-math.cos(a), math.sin(a)) for a in np.linspace(-1.25, 1.25, 16)]
		inner = [(-0.55 * math.cos(a), 0.92 * math.sin(a)) for a in np.linspace(1.25, -1.25, 16)]
		return outer + inner
	raise ValueError(shape)


def make_marker(m, i):
	pts = outline(m["shape"])
	sx, sy, r = m.get("sx", 1), m.get("sy", 1), m["r"]
	mesh = bpy.data.meshes.new(f"Mark{i}")
	mesh.from_pydata([(x * sx * r, y * sy * r, 0) for x, y in pts], [], [list(range(len(pts)))])
	mat = bk.matte(f"Mark{i}", (0, 0, 0))
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Emission Color"].default_value = (*m["rgb"], 1)
	bsdf.inputs["Emission Strength"].default_value = 1
	mesh.materials.append(mat)
	o = bpy.data.objects.new(f"Mark{i}", mesh)
	bpy.context.scene.collection.objects.link(o)
	o.hide_render = True
	return o


def apply_pose(objs, rest, rest_loc, trees, key, grounded):
	"""Sets the key's pose. Returns every part's rotation and each root's offset, with Walk root height solved."""
	rot = {n: list(rest[n]) for n in objs}
	rot.update({n: list(v) for n, v in key.get("parts", {}).items()})
	for n, o in objs.items():
		o.rotation_euler = [math.radians(d) for d in rot[n]]
	offsets = {}
	for root in trees:
		offsets[root] = list(key.get("root", {}).get(root, (0, 0, 0)))
		objs[root].location = rest_loc[root] + Vector(offsets[root])
	bpy.context.view_layer.update()
	if grounded and not key.get("air"):
		for root, members in trees.items():
			legs = [n for n in members if "Leg" in n and "Neon" not in n]
			offsets[root][2] -= min(float(bk.verts(objs[n])[:, 2].min()) for n in legs)
			objs[root].location = rest_loc[root] + Vector(offsets[root])
		bpy.context.view_layer.update()
	return rot, offsets


def marker_point(objs, m):
	return objs[m["on"]].matrix_world @ Vector(m["at"]) if "on" in m else Vector(m["at"])


def place_markers(marks, cam):
	for o, m, at in marks:
		o.location = at
		o.rotation_euler = (cam.rotation_euler.to_matrix() @ Matrix.Rotation(math.radians(m.get("spin", 0)), 3, "Z")).to_euler()
	bpy.context.view_layer.update()


def shot(scene, cam, view, size, path, marks):
	# render() positions the camera itself; set it here first so the flat marks can face it
	cam.location, cam.rotation_euler, cam.data.ortho_scale = view
	place_markers(marks, cam)
	return bk.render(scene, cam, view, size, path)


def shrink(px, n):
	h, w = px.shape[0] // n, px.shape[1] // n
	return px[: h * n, : w * n].reshape(h, n, w, n, 4).mean(axis=(1, 3))


def validate(cid, move, objs):
	keys = move["keys"]
	assert 3 <= len(keys) <= 5, f"{cid}: {len(keys)} keys"
	times = [k["t"] for k in keys]
	assert times == sorted(set(times)) and 0 < times[0] and times[-1] < move["end"] <= HIT_EVERY, f"{cid}: times {times}, end {move['end']}"
	assert [k["name"] for k in keys].count("Release") == 1, f"{cid}: needs one Release key"
	for k in keys:
		for n in k.get("parts", {}):
			assert n in objs, f"{cid} {k['name']}: no part {n}"
		assert k["name"] == "Release" or "markers" not in k, f"{cid} {k['name']}: markers belong only on Release"


def angle_between(a, b):
	qa = Euler([math.radians(v) for v in a]).to_quaternion()
	qb = Euler([math.radians(v) for v in b]).to_quaternion()
	return math.degrees(qa.rotation_difference(qb).angle)


def run(cid):
	bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, "assets", "characters_avatar", cid, cid + ".blend"))
	with open(os.path.join(HERE, "sidekicks", cid + ".attack.json")) as f:
		move = json.load(f)
	out = os.path.join(REPO, "assets", "characters_avatar", cid, "keyframes")
	os.makedirs(out, exist_ok=True)
	os.makedirs(bk.TMP, exist_ok=True)
	scene = bpy.context.scene
	objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
	validate(cid, move, objs)
	rest = {n: tuple(math.degrees(v) for v in o.rotation_euler) for n, o in objs.items()}
	rest_loc = {n: o.location.copy() for n, o in objs.items()}
	for o in objs.values():
		o.rotation_mode = "XYZ"
		o.rotation_euler = (0, 0, 0)
	bpy.context.view_layer.update()
	pivots = {n: [round(v, 3) for v in o.matrix_world.translation] for n, o in objs.items()}
	roots = [n for n, o in objs.items() if o.parent is None or o.parent.name not in objs]

	def root_of(n):
		while n not in roots:
			n = objs[n].parent.name
		return n

	trees = {r: [n for n in objs if root_of(n) == r] for r in roots}
	grounded = move["movement"] == "Walk"
	rest_px = np.vstack([bk.verts(o) for o in objs.values()])
	height = float(np.ptp(rest_px[:, 2]))
	cam = build_avatar.setup_render(scene)
	scene.render.film_transparent = False
	if grounded:
		bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
		bpy.context.object.data.materials.append(bk.matte("floor", (0.62, 0.63, 0.66)))

	apply_pose(objs, rest, rest_loc, trees, {}, grounded)
	records, union, previous = [], [], rest
	all_marks = {}
	for k in move["keys"]:
		rot, offsets = apply_pose(objs, rest, rest_loc, trees, k, grounded)
		pts = {n: bk.verts(o) for n, o in objs.items()}
		union.append(np.vstack(list(pts.values())))
		rec = {"name": k["name"], "t": k["t"], "desc": k["desc"], "root_offset": {r: [round(v, 3) for v in off] for r, off in offsets.items()}, "rotations": {n: [round(v, 3) for v in r] for n, r in rot.items()}}
		records.append(rec)
		if k["name"] == "Release":
			all_marks = [(make_marker(m, i), m, marker_point(objs, m)) for i, m in enumerate(k.get("markers", []))]
			for _, m, at in all_marks:
				reach = m["r"] * max(m.get("sx", 1), m.get("sy", 1)) * (2.3 if m["shape"] == "cone" else 1)
				# corners, so the flat mark stays in frame from any view
				union.append(np.array([[at.x + dx * reach, at.y + dy * reach, at.z + dz * reach] for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]))
		turned = max(angle_between(previous[n], rot[n]) for n in objs)
		far = max(float(np.linalg.norm(off)) for off in offsets.values())
		low = min((round(float(p[:, 2].min()), 2), n) for n, p in pts.items())
		print("KEY", cid, k["name"], k["t"], f"turned={turned:.0f}", f"root={far:.2f}", f"lowest={low}", flush=True)
		assert turned >= MIN_CHANGE, f"{cid} {k['name']}: only {turned:.0f} deg from the previous key"
		assert far <= ROOT_LIMIT * height, f"{cid} {k['name']}: root moved {far:.2f}, over {ROOT_LIMIT:.0%} of height {height:.2f}"
		if grounded:
			assert low[0] > -0.35, f"{cid} {k['name']}: {low[1]} sinks {low[0]} below the floor"
		previous = rot

	both = np.vstack(union)
	main_dir = move.get("view", build_avatar.VIEWS["three_quarter"])
	three = bk.fit(cam, both, main_dir, MAIN[0] / MAIN[1])
	side = bk.fit(cam, both, (math.copysign(1, main_dir[0]), 0, 0.1), SIDE[0] / SIDE[1])
	front = bk.fit(cam, both, build_avatar.VIEWS["front"], SIDE[0] / SIDE[1])
	rows = math.ceil(len(move["keys"]) / COLS)
	cell_h = MAIN[1]
	sheet = np.ones((HEAD_H + rows * (cell_h + STRIP_H) + 8, COLS * CELL_W, 4), dtype=np.float32)
	sheet[:, :, :3] = bk.BG
	note = f"{move['movement']}. Rest at 0 s, back in rest at {move['end']} s. Times and pose proposed; not approved. Flat coloured shapes on Release are sketch markers, not on the model."
	bk.paste(sheet, bk.text_px([(move["title"], 40, 46, 24, bk.INK), (note, 24, 84, 24, bk.DIM)], COLS * CELL_W, HEAD_H, bk.BG), 0, 0)
	for i, k in enumerate(move["keys"]):
		apply_pose(objs, rest, rest_loc, trees, k, grounded)
		is_release = k["name"] == "Release"
		marks = all_marks if is_release else []
		for o, _, _ in all_marks:
			o.hide_render = not is_release
		base = os.path.join(bk.TMP, f"{cid}_{i}")
		main_px = shot(scene, cam, three, MAIN, base + "_3q.png", marks)
		side_px = shot(scene, cam, side, SIDE, base + "_side.png", marks)
		for o, _, _ in all_marks:  # a mark in front of the body would hide the pose here
			o.hide_render = True
		front_px = shot(scene, cam, front, SIDE, base + "_front.png", [])
		row, col = divmod(i, COLS)
		x, y = col * CELL_W, HEAD_H + row * (cell_h + STRIP_H)
		bk.paste(sheet, main_px, x, y)
		bk.small_view(sheet, side_px, x + MAIN[0], y, "side")
		bk.small_view(sheet, front_px, x + MAIN[0], y + 32 + SIDE[1], "front")
		bk.paste(sheet, bk.text_px([("small read", 22, 24, 8, bk.DIM)], SIDE[0], 32, bk.BG), x + MAIN[0], y + 2 * (32 + SIDE[1]))
		bk.paste(sheet, shrink(main_px, 8), x + MAIN[0], y + 2 * (32 + SIDE[1]) + 32)
		if is_release:  # label each mark where the main view shows it
			cam.location, cam.rotation_euler, cam.data.ortho_scale = three
			scene.render.resolution_x, scene.render.resolution_y = MAIN
			bpy.context.view_layer.update()
			for o, m, at in marks:
				if not m["label"]:
					continue
				p = world_to_camera_view(scene, cam, at)
				label = bk.text_px([(m["label"], 24, 25, 6, bk.INK)], len(m["label"]) * 13 + 14, 34, (1, 1, 0.8))
				lx = int(min(max(p.x * MAIN[0] - label.shape[1] / 2, 0), MAIN[0] - label.shape[1]))
				above = m["r"] * m.get("sy", 1) * max(MAIN) / three[2]  # label sits over the mark, not on it
				ly = int(min(max((1 - p.y) * MAIN[1] - above - 34, 0), MAIN[1] - 34))
				bk.paste(sheet, label, x + lx, y + ly)
		head = f"{k['name']}   {k['t']:.2f} s"
		bk.paste(sheet, bk.text_px([(head, 34, 40, 18, (0.75, 0.05, 0.05) if is_release else bk.INK), (k["desc"], 25, 80, 18, bk.DIM)], CELL_W, STRIP_H, bk.BG), x, y + cell_h)
		sheet[y : y + cell_h + STRIP_H, x : x + 2] = (0.5, 0.5, 0.52, 1)
	path = os.path.join(out, "attack_slices.png")
	bk.save_px(sheet, path)
	release = next(k["t"] for k in move["keys"] if k["name"] == "Release")
	data = {
		"id": cid,
		"movement": move["movement"],
		"units": "XYZ Euler degrees about each part's pivot, relative to its parent; root_offset in model units, added to each root part's rest location",
		"pivots": pivots,
		"rest": {n: [round(v, 3) for v in r] for n, r in rest.items()},
		"moves": {"attack": {"title": move["title"], "end": move["end"], "Release": release, "keys": records}},
	}
	with open(os.path.join(out, "keys.json"), "w") as f:
		json.dump(data, f, indent=1)
	print("SHEET", path, flush=True)


if __name__ == "__main__":
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	for cid in [a for a in argv if a in IDS] or IDS:
		run(cid)
