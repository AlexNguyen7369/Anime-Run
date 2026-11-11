# The Elf Mage (boss_mage) review renders and the size line-up with the stone golem (boss_golem), headless:
#   python3 tools/blender/paint/atlas.py boss_mage
#   Blender -b --factory-startup --python tools/blender/build_boss_event.py -- build boss_golem
#   Blender -b --factory-startup --python tools/blender/build_boss_mage.py
#   Blender -b --factory-startup --python tools/blender/build_boss_mage.py -- portraits
# Writes assets/characters_avatar/boss_mage/review/{front,side,back,three_quarter,hover,hover_three_quarter,lineup}.png,
# boss_mage.blend and boss_golem/review/slam_pose.png; portraits: boss_mage and boss_golem portrait.png and head.png.
# She is a painted R15 character (paint/char_boss_mage.py) merged into the 6 runner parts; the staff and the two twin tails stay
# their own objects, origin at their grip or root, so they animate on their own. Nothing here uploads.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import avatar_merge  # noqa: E402
import build_avatar  # noqa: E402
import build_boss_event as be  # noqa: E402

CID = "boss_mage"
SCALE = 4.0  # drawn at 4x a runner in game, built at runner size
GOLEM_RATIO = 1.6  # golem height over the scaled mage's height
SLAM_BEND = 55  # forearms bent in over the head so the fists meet
HOVER = 1.5  # her feet above the ground in game, in runner heights
RDIR = os.path.join(build_avatar.OUT, CID, "review")
# own object: name prefix of its built pieces, pivot (tail root, staff grip)
LOOSE = {"TailL": ("Head_TailL", (0.86, 0.36, 5.86)), "TailR": ("Head_TailR", (-0.86, 0.36, 5.86)), "Staff": ("RightHand_Staff", (-1.5, -0.62, 2.05))}
JOINT = {"LeftArm": (1.5, 0, 3.8), "RightArm": (-1.5, 0, 3.8), "LeftLeg": (0.5, 0, 2.0), "RightLeg": (-0.5, 0, 2.0)}
HAND = {"LeftArm": Vector((1.5, 0, 2.05)), "RightArm": Vector((-1.5, 0, 2.05))}


def join(name, prefix, pivot):
	"""The built pieces under prefix as one mesh object, unparented, its origin at pivot."""
	bpy.context.view_layer.update()
	pieces = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(prefix)]
	assert pieces, prefix
	bm = bmesh.new()
	for o in pieces:
		me = o.data.copy()
		me.transform(o.matrix_world)
		bm.from_mesh(me)
		bpy.data.meshes.remove(me)
		bpy.data.objects.remove(o)
	bmesh.ops.translate(bm, verts=bm.verts[:], vec=-Vector(pivot))
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	o = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(o)
	o.location = pivot
	return o


def build():
	build_avatar.reset()
	bpy.context.preferences.filepaths.save_version = 0
	build_avatar.build(CID, build_avatar.load_data()[CID])
	loose = {n: join(n, *v) for n, v in LOOSE.items()}
	merged, _ = avatar_merge.merge(CID, keep=list(loose.values()))
	root = bpy.data.objects.new(CID, None)
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


def turn(pivot, direction=None, euler=None):
	"""Rotation about pivot: aims the part's down axis along direction, or by euler degrees."""
	if direction is not None:
		r = Vector((0, 0, -1)).rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
	else:
		r = Matrix.Rotation(math.radians(euler[2]), 4, "Z") @ Matrix.Rotation(math.radians(euler[1]), 4, "Y") @ Matrix.Rotation(math.radians(euler[0]), 4, "X")
	return Matrix.Translation(pivot) @ r @ Matrix.Translation(-Vector(pivot))


def pose(objs, rest, kind):
	for n, o in objs.items():
		o.matrix_world = rest[n]
	m = {}
	if kind == "stand":
		# staff upright in the right hand, the arm a little forward to hold it clear of the body
		m["RightArm"] = turn(JOINT["RightArm"], euler=(-28, 0, 0))
		hand = m["RightArm"] @ HAND["RightArm"]
		objs["Staff"].matrix_world = Matrix.Translation(hand)
	else:
		# hovering as in the key art: the staff across the body in both hands, a slight forward lean, legs together and swung
		# back so the toes point down (the leg is one block: no ankle), tails spread wide and high
		targets = {"RightArm": Vector((-0.95, -1.3, 2.2)), "LeftArm": Vector((1.05, -1.35, 3.25))}
		for side, t in targets.items():
			m[side] = turn(JOINT[side], direction=t - Vector(JOINT[side]))
		low, high = m["RightArm"] @ HAND["RightArm"], m["LeftArm"] @ HAND["LeftArm"]
		r = Vector((0, 0, 1)).rotation_difference((high - low).normalized()).to_matrix().to_4x4()
		m["Staff"] = Matrix.Translation(low) @ r @ rest["Staff"].inverted()
		m["TailL"] = turn(LOOSE["TailL"][1], euler=(-4, -30, 0))
		m["TailR"] = turn(LOOSE["TailR"][1], euler=(-4, 30, 0))
		lean = turn((0, 0, 2.0), euler=(8, 0, 0))
		for n in ("Head", "Torso", "LeftArm", "RightArm", "TailL", "TailR", "Staff"):
			m[n] = lean @ m.get(n, Matrix())
		m["LeftLeg"] = turn(JOINT["LeftLeg"], euler=(24, 0, -2))
		m["RightLeg"] = turn(JOINT["RightLeg"], euler=(18, 0, 2))
	for n, mat in m.items():
		objs[n].matrix_world = mat @ rest[n]
	bpy.context.view_layer.update()


def render(cam, path, d, res=1024, target=(0, 0, 3.1), dist=16):
	scene = bpy.context.scene
	scene.render.resolution_x = scene.render.resolution_y = res
	n = Vector(d).normalized()
	cam.location = Vector(target) + n * dist
	build_avatar.aim(cam, target)
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


def label(text, x, z, size):
	cu = bpy.data.curves.new(text, "FONT")
	cu.body = text
	cu.size = size
	cu.align_x = "CENTER"
	o = bpy.data.objects.new(text, cu)
	o.location = (x, -30, z)
	o.rotation_euler = (math.radians(90), 0, 0)
	o.data.materials.append(bpy.data.materials.get("Ink") or ink_mat())
	bpy.context.scene.collection.objects.link(o)
	return o


def ink_mat():
	m = bpy.data.materials.new("Ink")
	m.use_nodes = True
	bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = (0.02, 0.02, 0.03, 1)
	return m


def lineup(cam, mage_root):
	"""A runner (db_hero), the mage at 4x and the golem at 1.6x her scaled height, feet on one ground line, level ortho front camera."""
	data = build_avatar.load_data()
	hero, _ = build_avatar.placed("db_hero", data["db_hero"], keep=list(bpy.data.objects))
	golem = be.append_model("boss_golem")
	lo, hi = be.bounds(hero)
	runner_h = float(hi[2] - lo[2])
	lo, hi = be.bounds(mage_root)
	mage_h = float(hi[2] - lo[2]) * SCALE
	golem_h = mage_h * GOLEM_RATIO
	x, gap, spans = 0.0, 3.0, []
	for root, h in ((hero, runner_h), (mage_root, mage_h), (golem, golem_h)):
		be.stand(root, h, 0.0, spin=-20)
		lo, hi = be.bounds(root)
		wide = float(hi[0] - lo[0])
		be.stand(root, h, x + wide / 2, spin=-20)
		spans.append((x + wide / 2, h))
		x += wide + gap
	mage_root.location.z += HOVER * runner_h  # she hovers: feet this many runner heights up
	width = x - gap
	ground = build_avatar.avatar_base.rbox("Ground", (width + 8, 6, 0.3), (width / 2, 0, -0.15), "#3a3e4a", bevel=0)
	size = golem_h * 0.035
	names = ("Runner (db_hero), 1x", f"boss_mage at {SCALE:.0f}x, hovering", f"boss_golem, {GOLEM_RATIO}x the mage")
	for (cx, h), text in zip(spans, names):
		label(text, cx, -size * 2.2, size)
		label(f"{h / runner_h:.1f} runner heights", cx, -size * 3.6, size * 0.8)
	scene = bpy.context.scene
	scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
	pts = be.world_verts([o for o in scene.objects if o.type == "MESH"])
	pts = be.np.vstack([pts, [[pts[:, 0].min(), 0, -size * 4.4]]])
	be.fit(cam, pts, (0, -1, 0), 1920 / 1080, margin=0.92)
	scene.render.filepath = os.path.join(RDIR, "lineup.png")
	bpy.ops.render.render(write_still=True)
	print("LINEUP runner", round(runner_h, 3), "mage", round(mage_h, 3), "golem", round(golem_h, 3), "ground", ground.name)


def golem_slam():
	"""Both arms raised overhead, fists together: the joints pose cleanly. Rotations replace the rest pose's, about each joint."""
	build_avatar.reset()
	root = be.append_model("boss_golem")
	slam = {"Torso": (-6, 0, 0), "Head": (6, 0, 0), "ShoulderL": (0, -14, 0), "ShoulderR": (0, 14, 0), "UpperArmL": (-172, 8, 0), "UpperArmR": (-172, -8, 0), "ForearmL": (0, SLAM_BEND, 0), "ForearmR": (0, -SLAM_BEND, 0)}
	for o in root.children_recursive:
		if o.name in slam:
			o.rotation_euler = [math.radians(d) for d in slam[o.name]]
	cam = build_avatar.setup_render(bpy.context.scene)
	scene = bpy.context.scene
	scene.render.resolution_x = scene.render.resolution_y = 1024
	be.fit(cam, be.world_verts(list(root.children_recursive)), (0.35, -1, 0.12), 1.0, margin=0.9)
	scene.render.filepath = os.path.join(build_avatar.OUT, "boss_golem", "review", "slam_pose.png")
	bpy.ops.render.render(write_still=True)


def portraits():
	"""The drawn UI portraits (portrait.png, head.png): the mage by the character pipeline, the golem by its non-humanoid path."""
	sys.path.insert(0, os.path.join(HERE, "portrait"))
	import render_portrait as rp

	rp.render(CID, CID, build_avatar.load_data()[CID], False)
	rp.SIDEKICK_VIEWS["boss_golem"] = {
		# close crops round the small head, sunk between the shoulders (world centre in the hunched rest pose)
		"portrait": {"show": ("Head", "Torso", "Shoulder", "UpperArm"), "focus": (0, -1.6, 6.2), "side": 6.4, "turn": 20},
		"head": {"show": ("Head", "Torso", "Shoulder"), "focus": (0, -1.9, 6.75), "side": 3.0, "turn": 15},
	}
	rp.render_sidekick("boss_golem", build_avatar.OUT)


def main():
	if sys.argv[-1] == "slam":
		golem_slam()
		return
	if sys.argv[-1] == "portraits":
		portraits()
		return
	root, objs, tris = build()
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build_avatar.OUT, CID, CID + ".blend"))
	os.makedirs(RDIR, exist_ok=True)
	cam = build_avatar.setup_render(bpy.context.scene)
	cam.data.lens = 70
	rest = {n: o.matrix_world.copy() for n, o in objs.items()}
	pose(objs, rest, "stand")
	for view, d in build_avatar.VIEWS.items():
		render(cam, os.path.join(RDIR, view + ".png"), d)
	pose(objs, rest, "hover")
	render(cam, os.path.join(RDIR, "hover.png"), (0.12, -1, 0.04), target=(0, 0, 3.4))
	render(cam, os.path.join(RDIR, "hover_three_quarter.png"), build_avatar.VIEWS["three_quarter"], target=(0, 0, 3.4))
	print("TRIS", CID, sum(tris.values()), tris)
	lineup(cam, root)
	golem_slam()


if __name__ == "__main__":
	main()
