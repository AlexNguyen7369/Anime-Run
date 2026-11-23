"""Blender draft of one World 2 track and its biome (design doc 4.47, docs/WORLD2_SPEC.md "Blender first").

Owner 2026-11-23: every World 2 track and its assets are made and rendered in Blender for approval before any of it
goes in the game. Builds the exact game road (chain.py), the biome module tools/blender/world2/biomes/<Biome>.py, saves
build/world2/track<NN>_<Biome>.blend and renders review shots to assets/world2_draft/track<NN>_<Biome>/.
Headless:  Blender -b --factory-startup --python tools/blender/world2/build_track.py -- <number ...|all> [--fast]
Live (MCP): import build_track; build_track.run(<number>)
Import-safe: main() runs only as a script.
"""

import importlib
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import chain  # noqa: E402
import kit  # noqa: E402

OUT = os.path.join(ROOT, "assets", "world2_draft")
BUILD = os.path.join(ROOT, "build", "world2")
RUNNER_EYE = (14, 8)  # studs behind and above the runner's lane: the game's track camera (CAMERA_SPEC, about)


def load_chain():
	path = os.path.join(BUILD, "chain.json")
	data = chain.build()
	os.makedirs(BUILD, exist_ok=True)
	json.dump(data, open(path, "w"))
	return {t["Number"]: t for t in data}


def bloom(scene):
	"""A soft bloom on neon and lamps (Roblox's Bloom post effect stands in for it in the game). Blender 5 API."""
	try:
		tree = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
		tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
		layers = tree.nodes.new("CompositorNodeRLayers")
		glare = tree.nodes.new("CompositorNodeGlare")
		glare.inputs["Type"].default_value = "Bloom"
		glare.inputs["Threshold"].default_value = 0.9
		glare.inputs["Strength"].default_value = 0.6
		out = tree.nodes.new("NodeGroupOutput")
		tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
		tree.links.new(glare.outputs["Image"], out.inputs[0])
		scene.compositing_node_group = tree
	except (AttributeError, KeyError, TypeError) as err:
		print("BLOOM skipped:", err)


def setup(fast):
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x, scene.render.resolution_y = (960, 540) if fast else (1600, 900)
	scene.render.image_settings.file_format = "JPEG"
	scene.render.image_settings.quality = 88
	scene.view_settings.view_transform = "Standard"
	try:
		scene.eevee.taa_render_samples = 16 if fast else 48
	except AttributeError:
		pass
	bloom(scene)
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.sensor_fit = "VERTICAL"
	cam.data.clip_start = 0.5
	cam.data.clip_end = 30000
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def shoot(cam, eye, look, path, fov=70):
	e, l = kit.rb(*eye), kit.rb(*look)
	cam.location = e
	cam.rotation_euler = (l - e).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(fov)
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	print("SHOT", path)


def shots(k, cam, folder):
	"""Overview, four runner's-eye views along the road and one raised side view."""
	os.makedirs(folder, exist_ok=True)
	lo, hi = k.lo, k.hi
	c = (lo + hi) / 2
	span = max(hi.x - lo.x, hi.z - lo.z)
	shoot(cam, (c.x, span * 0.9, c.z + span * 0.75), (c.x, 0, c.z), os.path.join(folder, "00_overview.jpg"), 50)
	for i, f in enumerate((0.06, 0.33, 0.62, 0.9), start=1):
		d = k.length * f
		p, right, t = k.at(d)
		lane = p + right * 10  # TrackBuilder.LANE_OFFSET: the runner's lane
		eye = lane - t * RUNNER_EYE[0]
		ahead = lane + t * 70
		shoot(cam, (eye.x, p.y + RUNNER_EYE[1], eye.z), (ahead.x, p.y + 4, ahead.z), os.path.join(folder, "%02d_run_%d.jpg" % (i, int(f * 100))))
	p, right, t = k.at(k.length * 0.48)
	eye = p + right * 140 - t * 60
	shoot(cam, (eye.x, p.y + 75, eye.z), (p.x, p.y, p.z), os.path.join(folder, "05_side.jpg"), 60)


def run(number, fast=False, render=True):
	tracks = load_chain()
	track = tracks[number]
	biome = track["Biome"]
	bpy.ops.wm.read_homefile(use_empty=True)
	cam = setup(fast)
	k = kit.Kit(track, biome)
	module = importlib.import_module("biomes." + biome)
	importlib.reload(module)
	k.road(track["Palette"])
	module.build(k)
	tris = {}
	for ob in k.lib.objects:
		if ob.type == "MESH":
			ob.data.calc_loop_triangles()
			tris[ob.name] = len(ob.data.loop_triangles)
	print("ASSETS", biome, json.dumps(tris))
	print("INSTANCES", k.instances)
	name = "track%02d_%s" % (number, biome)
	os.makedirs(BUILD, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BUILD, name + ".blend"), copy=True)
	if render:
		shots(k, cam, os.path.join(OUT, name))
	return k


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	fast = "--fast" in argv
	nums = [a for a in argv if not a.startswith("--")]
	numbers = list(range(1, 11)) if nums in ([], ["all"]) else [int(a) for a in nums]
	for n in numbers:
		run(n, fast)


if __name__ == "__main__":
	main()
