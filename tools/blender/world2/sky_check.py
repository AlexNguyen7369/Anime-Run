"""The proposed sky-prop rule (docs/WORLD2_SPEC.md "Sky props on the wide layout", proposed 2026-11-26) checked on the
committed Drafts, by geometry (no fog model; the Studio check decides what the game's Atmosphere hides): every placed row
whose top stands over SKY_TOP studs above the ground and whose base centre is nearer than SKY_FAR studs to another
track's road centre line. Plain Python. Run: python3 tools/blender/world2/sky_check.py
"""

import collections
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import chain  # noqa: E402
import export_props as ep  # noqa: E402

SKY_TOP, SKY_FAR = 300.0, 1500.0  # proposed (WORLD2_SPEC)
CELL = 256.0


def main():
	tracks = chain.build()
	grid = collections.defaultdict(list)  # (cell) -> [(x, z, track)]
	for t in tracks:
		for p in t["Waypoints"][::2]:
			grid[(int(p[0] // CELL), int(p[2] // CELL))].append((p[0], p[2], t["Number"]))

	def other_road(x, z, own):
		"""Distance to the nearest centre line of another track, capped at SKY_FAR."""
		best, r = SKY_FAR, int(SKY_FAR // CELL) + 1
		cx, cz = int(x // CELL), int(z // CELL)
		for i in range(cx - r, cx + r + 1):
			for j in range(cz - r, cz + r + 1):
				for px, pz, n in grid.get((i, j), ()):
					if n != own:
						best = min(best, math.hypot(px - x, pz - z))
		return best

	orig = ep.origins()
	total = collections.Counter()
	for n, biome in sorted(ep.APPROVED.items()):
		src = open(os.path.join(ep.THEMES, biome + "Draft.luau")).read()
		sizes = dict(re.findall(r"\n\t\t(\w+) = \{\n(?:[^\n]*\n)*?\t\t\tSize = v\(([^)]*)\)", src))
		i = src.index("\tPlaced = {")
		j = src.index("\n\t},", i)
		o, yaw = orig[n]
		bad = collections.Counter()
		for line in src[i:j].splitlines():
			m = re.match(r'\s*\{ "(\w+)", (-?[\d.]+), (-?[\d.]+), (-?[\d.]+), (-?[\d.]+), (-?[\d.]+)', line)
			if not m:
				continue
			name = m.group(1)
			x, y, z, _, sc = map(float, m.groups()[1:])
			sy = float(sizes.get(name, "0, 0, 0").split(",")[1])
			w = re.search(r"\bv\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)\s*\}\s*,?\s*$", line)
			top = y + sy * (float(w.group(2)) if w and "Group" not in line else sc)
			if top <= SKY_TOP:
				continue
			wx, _, wz = ep.to_world(o, yaw, (x, y, z))
			if other_road(wx, wz, n) < SKY_FAR:
				bad[name] += 1
		total[n] = sum(bad.values())
		print("SKY T%d %s: %d rows over %d studs within %d of another road %s" % (n, biome, total[n], SKY_TOP, SKY_FAR, dict(bad.most_common(8))))
	print("SKY total", sum(total.values()))


if __name__ == "__main__":
	main()
