"""Road clearance check for the World 2 track drafts (WORLD2_SPEC "Blender first": props stay 24+ studs from the road
centre line).

Builds each track exactly as build_track.py does (render=False), then measures, for every placed instance that is not
a road piece, the closest mesh vertex to every lap's road centre line (distance to the line segments, in the XZ plane,
Roblox studs). Exempt: road pieces, and props a biome module lists in an optional module-level CLEAR_EXEMPT set (pieces
that span the road with 14+ overhead clearance, or sit under a raised road as its support).
Prints one FAIL line per offending instance (prop, its closest point, distance along the road, distance from the
centre line), then "CLEAR n/n" for the track, or "FAIL k".
Headless:  Blender -b --factory-startup --python tools/blender/world2/clearance.py -- <number ...|all>
Import-safe: main() runs only as a script.
"""

import importlib
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import build_track  # noqa: E402

MIN_CLEAR = 24.0
ROAD_PIECES = ("Wall", "Dash", "Apron", "WinPad", "Road", "Ground")


def check(number):
	"""Builds track `number` and returns (checked, fails) with fails = [(prop, x, z, along, dist)]."""
	k = build_track.run(number, fast=True, render=False)
	module = importlib.import_module("biomes." + k.biome)
	exempt = set(getattr(module, "CLEAR_EXEMPT", ()))
	pts = np.array([(w.x, w.z) for w in k.wps])
	a, b = pts[:-1], pts[1:]
	ab = b - a
	ab2 = np.maximum((ab * ab).sum(1), 1e-9)
	cum = np.array(k._cum[:-1])
	prefix = "W2_%s_" % k.biome
	checked, fails = 0, []
	for ob in k.col.objects:
		if ob.type != "MESH" or not ob.name.startswith(prefix):
			continue
		prop = ob.data.name[len(prefix) :]
		if prop in exempt or any(prop.startswith(r) for r in ROAD_PIECES):
			continue
		checked += 1
		mw = ob.matrix_world
		co = np.empty(len(ob.data.vertices) * 3)
		ob.data.vertices.foreach_get("co", co)
		co = co.reshape(-1, 3)
		m = np.array(mw)
		world = co @ m[:3, :3].T + m[:3, 3]
		v = np.stack((world[:, 0], -world[:, 1]), 1)  # Blender (x, y) -> Roblox (x, z)
		centre, rad = v.mean(0), np.sqrt(((v - v.mean(0)) ** 2).sum(1)).max()
		near = np.sqrt(((a - centre) ** 2).sum(1)) < rad + MIN_CLEAR + np.sqrt(ab2) + 1
		if not near.any():
			continue
		sa, sab, sab2, scum = a[near], ab[near], ab2[near], cum[near]
		best, where = np.inf, None
		for chunk in range(0, len(v), 2048):
			p = v[chunk : chunk + 2048][:, None, :]
			t = np.clip(((p - sa) * sab).sum(2) / sab2, 0, 1)
			d = np.sqrt(((p - sa - t[..., None] * sab) ** 2).sum(2))
			i = np.unravel_index(d.argmin(), d.shape)
			if d[i] < best:
				best = d[i]
				where = (v[chunk + i[0]], scum[i[1]] + t[i] * np.sqrt(sab2[i[1]]))
		if best < MIN_CLEAR:
			fails.append((prop, where[0][0], where[0][1], where[1], best))
	return checked, fails


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	nums = [a for a in argv if not a.startswith("--")]
	numbers = list(range(1, 11)) if nums in ([], ["all"]) else [int(a) for a in nums]
	for n in numbers:
		checked, fails = check(n)
		for prop, x, z, along, dist in sorted(fails, key=lambda f: f[3]):
			print("FAIL track %d %s at (%.0f, %.0f) d=%.0f: %.1f from the centre line" % (n, prop, x, z, along, dist))
		print("TRACK %d %s" % (n, ("CLEAR %d/%d" % (checked, checked)) if not fails else ("FAIL %d" % len(fails))))


if __name__ == "__main__":
	main()
