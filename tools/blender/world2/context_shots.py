"""Review shots of a swapped track with every track's road and built props drawn, into trackNN_<Biome>/context/ (the
closest render to what a player sees). Built = the exported rows on each track's own ground (game_shots.built_rows).
Missing: game terrain and ground colours of the other tracks, Prune, streaming distance, the other tracks' lights, the
game's own lighting, the plaza, moved heroes of other tracks. The sky, sun and lamps are the reviewed track's.
Headless: Blender -b --factory-startup --python tools/blender/world2/context_shots.py -- <number ...> [--fast] [--out=<folder>] [--fog=<studs>]
"""

import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_track as bt  # noqa: E402
import export_props as ep  # noqa: E402
import game_shots as gs  # noqa: E402


def keep_built(k, number):
	import bpy

	names = [n for n in k.props if n not in ep.ROAD]
	origin, yaw = ep.origins()[number]
	ctr = {}
	for n in names:
		lo, hi = ep.bounds(k.props[n].data)
		ctr[n] = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
	rows = {(p, round(x, 1), round(z, 1)) for p, x, z in gs.built_rows(number, k.biome, set())}
	bpy.context.view_layer.update()
	lib, by = set(k.lib.objects), {k.props[n].data.name: n for n in names}
	meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH" and ob not in lib and ob.data.name in by and not ob.hide_render]
	shown = 0
	for ob, (n, pos, _, _) in zip(meshes, ep.placements(k, names, origin, yaw, ctr), strict=True):
		key = ep.RENAME.get(n, n)
		ok = any((key, round(pos[0] + a, 1), round(pos[2] + b, 1)) in rows for a in (0, 0.06, -0.06) for b in (0, 0.06, -0.06))
		ob.hide_render = not ok
		shown += ok
	print("BUILT", number, k.biome, "shown", shown, "of", len(rows), flush=True)


FOG = None  # --fog=<studs>: half-visibility distance of an approximate fog (the game's Atmosphere is not modelled exactly)


def add_fog(scene, half):
	"""An even fog over the whole scene: the world gets a scattering volume that halves what is seen every `half` studs
	(Beer-Lambert), tinted by the sky's horizon. An approximation of the game's Atmosphere fog (Kit.fromDraft: Density 0.3
	by day, 0.22 at night) for the sky-prop rule's check (WORLD2_SPEC "Sky props", proposed); a Studio check decides."""
	import math

	nt = scene.world.node_tree
	out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
	vol = nt.nodes.new("ShaderNodeVolumePrincipled")
	vol.inputs["Density"].default_value = math.log(2) / half
	vol.inputs["Color"].default_value = (0.8, 0.8, 0.8, 1.0)
	nt.links.new(vol.outputs["Volume"], out.inputs["Volume"])
	for attr, v in (("volumetric_end", 20000.0), ("volumetric_start", 1.0), ("volumetric_tile_size", "8")):
		try:
			setattr(scene.eevee, attr, v)
		except (AttributeError, TypeError) as err:
			print("FOG setting skipped:", attr, err)


def run(number, fast):
	import bpy
	import kit

	own = bt.run(number, render=False, fast=fast)
	scene = bpy.context.scene
	world = scene.world
	keep_built(own, number)
	for n, track in bt.load_chain().items():
		if n == number:
			continue
		before = set(scene.objects)
		k = kit.Kit(track, track["Biome"])
		k.road(track["Palette"])
		importlib.import_module("biomes." + track["Biome"]).build(k)
		for ob in set(scene.objects) - before:
			if ob.type == "LIGHT" or (ob.data and ob.data.name.endswith("_Ground")):
				ob.hide_render = True
		keep_built(k, n)
	scene.world = world
	if FOG:
		add_fog(scene, FOG)
	bt.shots(own, scene.camera, os.path.join(bt.OUT, "track%02d_%s" % (number, own.biome), "context_fog" if FOG else "context"))


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	out = next((a.split("=", 1)[1] for a in argv if a.startswith("--out=")), None)
	if out:  # another review set's folder (relative to the repo root), e.g. assets/world2_draft/relayout_2026-11-26
		bt.OUT = os.path.join(bt.ROOT, out)
	global FOG
	FOG = next((float(a.split("=", 1)[1]) for a in argv if a.startswith("--fog=")), None)
	for n in [int(a) for a in argv if not a.startswith("--")]:
		run(n, "--fast" in argv)


if __name__ == "__main__":
	main()
