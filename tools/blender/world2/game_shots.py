"""The 6 review shots of a swapped track with only the props the game builds, into trackNN_<Biome>/game/ (the draft's own
shots also hold horizon pieces off the track's ground). Built = a row of the exported <Biome>Draft.luau on its own
ground, less the rows listed in --removed=<json> {biome: [row number]} (what the game's Prune takes, from the harness).
Headless: Blender -b --factory-startup --python tools/blender/world2/game_shots.py -- <number ...> [--removed=<json>] [--fast]
--option (with CASTLE_052=1, RANK_TURNED=1 or both): that not exported layout option, every prop on the own ground, into
option_castle_052/, option_turned/ or option_castle_turned/.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_track as bt  # noqa: E402
import export_props as ep  # noqa: E402


# the option folder by which layout switches of biomes/ElvenPlains.py are set
OPTION = {(True, False): "option_castle_052", (False, True): "option_turned", (True, True): "option_castle_turned"}.get(
	(os.environ.get("CASTLE_052") == "1", os.environ.get("RANK_TURNED") == "1")
)


def built_rows(number, biome, removed):
	"""[(prop, local base x, z)] of the built rows (a cut prop's pieces as their whole)."""
	lo, hi = ep.ground_rect(number)
	src = open(os.path.join(ep.THEMES, biome + "Draft.luau")).read()
	rows = re.finditer(r'\{\s*"(\w+)",([^{}]*?)\}', src[src.index("\tPlaced = {") : src.index("\tHeroes = ")])
	out = []
	for i, m in enumerate(rows, start=1):
		whole = re.search(r"Whole = v\(([^)]*)\)", m.group(2))
		n = [float(x) for x in (whole.group(1).split(",") if whole else m.group(2).split(",")[:3])]
		if i not in removed and lo[0] <= n[0] <= hi[0] and lo[1] <= n[2] <= hi[1]:
			out.append((re.sub(r"_p\d+$", "", m.group(1)), n[0], n[2]))
	return out


def run(number, removed, fast):
	k = bt.run(number, render=False, fast=fast)
	biome = k.biome
	import bpy

	names = [n for n in k.props if n not in ep.ROAD]
	origin, yaw = ep.origins()[number]
	ctr = {}
	for n in names:
		lo, hi = ep.bounds(k.props[n].data)
		ctr[n] = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
	option = "--option" in sys.argv
	(glo, ghi) = ep.ground_rect(number)
	rows = {(p, round(x, 1), round(z, 1)) for p, x, z in built_rows(number, biome, set(removed.get(biome, ())))}
	lib, by_mesh = set(k.lib.objects), {k.props[n].data.name: n for n in names}
	meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH" and ob not in lib and ob.data.name in by_mesh and not ob.hide_render]
	shown = hidden = 0
	# placements() walks the scene's objects in the same order and with the same filter
	for ob, (name, pos, _, _) in zip(meshes, ep.placements(k, names, origin, yaw, ctr), strict=True):
		key = ep.RENAME.get(name, name)
		ok = any((key, round(pos[0] + a, 1), round(pos[2] + b, 1)) in rows for a in (0, 0.06, -0.06) for b in (0, 0.06, -0.06))
		if option:  # not exported: everything on the track's own ground
			ok = glo[0] <= pos[0] <= ghi[0] and glo[1] <= pos[2] <= ghi[1]
		ob.hide_render = not ok
		shown, hidden = shown + ok, hidden + (not ok)
	print("GAME", number, biome, "built rows", len(rows), "shown", shown, "hidden", hidden)
	bt.shots(k, bpy.context.scene.camera, os.path.join(bt.OUT, "track%02d_%s" % (number, biome), OPTION if option else "game"))


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :]
	path = next((a.split("=", 1)[1] for a in argv if a.startswith("--removed=")), None)
	removed = json.load(open(path)) if path else {}
	for n in [int(a) for a in argv if not a.startswith("--")]:
		run(n, removed, "--fast" in argv)


if __name__ == "__main__":
	main()
