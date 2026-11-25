"""PROPOSAL: Track 5's kaiju-only export. Takes the committed KaijuBaseDraft.luau and a fresh export of Track 5 (a scratch copy's
export_props.py -- 5 --no-glb) and writes the committed file with only the approved kaiju changed (WORLD2_SPEC, owner 2026-11-25):
- the GiantCorpse prop's data, its 2 placements and the 12 fill placements (9 Apartment, 3 Office) are the fresh ones;
- rows that stand inside a body (measure()) go; each one's slot takes a new row, so no other row's Placed_<n> changes;
- every other row and prop keeps its text: no DefenseHQ, the Railgun, Piers and vans as they are.
measure() judges the committed rows mesh against mesh in the game's transform. INSIDE is the share of a row's vertices under the
corpse's surface (a ray from above meets it first) that counts as standing inside; a row that only touches stays and is listed.
Pure:     python3 tools/blender/world2/kaiju_export.py --self-test
          python3 tools/blender/world2/kaiju_export.py --filter <fresh Draft> <measure json>
Headless: Blender -b --factory-startup --python tools/blender/world2/kaiju_export.py -- --measure <fresh Draft> <json out> <scratch>
"""

import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DRAFT = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2", "KaijuBaseDraft.luau")
HERO = "GiantCorpse"
ADDED = {"GiantCorpse": 2, "Apartment": 9, "Office": 3}
INSIDE = 0.5
ROW = re.compile(r'^\t\t(\{ "(\w+)", .* \}),$')


def placed(text):
	"""(text before the Placed rows, the rows, text after them); every line of the block must be a row."""
	a = text.index("\tPlaced = {\n") + len("\tPlaced = {\n")
	b = text.index("\n\t},\n", a) + 1
	lines = text[a:b].rstrip("\n").split("\n")
	for line in lines:
		if not ROW.match(line):
			raise SystemExit("not a placement row: " + line)
	return text[:a], lines, text[b:]


def prop_block(text, name):
	"""Where a prop's `Props` entry starts and ends."""
	m = re.search(r"^\t\t%s = \{\n.*?^\t\t\},\n" % name, text, re.S | re.M)
	if not m:
		raise SystemExit("no prop " + name)
	return m.span()


def merge(old, fresh, inside, added=ADDED):
	"""The committed text with the kaiju's data and rows from the fresh one. inside: indices (from 1) of the rows to drop."""
	_, frows, _ = placed(fresh)
	head, rows, tail = placed(old)
	name = lambda line: ROW.match(line).group(2)  # noqa: E731
	extra = collections.Counter(frows) - collections.Counter(rows)
	new = [line for line in frows if name(line) in added and extra[line] > 0]
	got = collections.Counter(name(line) for line in new)
	if got != collections.Counter(added):
		raise SystemExit("the fresh export adds %s, not %s" % (dict(got), added))
	if len(set(new)) != len(new) or len(set(inside)) != len(inside) or len(inside) > len(new):
		raise SystemExit("repeated or too many rows")
	out = list(rows)
	for n, i in enumerate(sorted(inside)):
		if name(rows[i - 1]) in ("SweeperVan", "Pier", "Railgun", HERO):
			raise SystemExit("row %d is a %s: not this filter's to drop" % (i, name(rows[i - 1])))
		out[i - 1] = new[n]
	out += new[len(inside) :]
	a, b = prop_block(head, HERO)
	fa, fb = prop_block(fresh, HERO)
	head = head[:a] + fresh[fa:fb] + head[b:]
	return head + "\n".join(out) + "\n" + tail


def self_test():
	def doc(size, rows):
		return "return {\n\tProps = {\n\t\tGiantCorpse = {\n\t\t\tSize = %s,\n\t\t},\n\t\tPier = {\n\t\t\tSize = 1,\n\t\t},\n\t},\n\tPlaced = {\n%s\t},\n\tHeroes = {},\n}\n" % (
			size,
			"".join("\t\t%s,\n" % r for r in rows),
		)

	r = lambda n, x: '{ "%s", %d, 0, 0, 0, 1 }' % (n, x)  # noqa: E731
	old = doc("9", [r("Railgun", 1), r("Pier", 2), r("Rubble", 3), r("SweeperVan", 4), r("Rubble", 5)])
	fresh = doc("3", [r("DefenseHQ", 8), r("GiantCorpse", 1), r("Railgun", 1), r("Pier", 7), r("Apartment", 6), r("SweeperVan", 9), r("Rubble", 5)])
	added = {"GiantCorpse": 1, "Apartment": 1}
	out = merge(old, fresh, [3], added)
	assert placed(out)[1] == ["\t\t%s," % q for q in (r("Railgun", 1), r("Pier", 2), r("GiantCorpse", 1), r("SweeperVan", 4), r("Rubble", 5), r("Apartment", 6))], out
	assert "Size = 3" in out and "Size = 1" in out and "Size = 9" not in out and "DefenseHQ" not in out
	assert placed(merge(old, fresh, [], added))[1][:5] == placed(old)[1]
	for bad in ((old, fresh, [4], added), (old, fresh, [2], added), (old, fresh, [1], added), (old, fresh, [3, 3], added), (old, fresh, [3], ADDED), (old, fresh, [3, 5, 1], added)):
		try:
			merge(*bad)
		except SystemExit:
			continue
		raise AssertionError("accepted " + str(bad[2:]))
	print("kaiju_export self-test ok")


def measure(fresh_path, out_path, scratch):
	import build_track

	build_track.OUT, build_track.BUILD = os.path.join(scratch, "out"), os.path.join(scratch, "build")
	import export_props as ep
	import numpy as np
	from mathutils import Vector
	from mathutils.bvhtree import BVHTree

	k = build_track.run(5, fast=True, render=False)
	(origin, yaw) = ep.origins()[5]
	real = {v: n for n, v in ep.RENAME.items()}
	local = {}

	def tris(line):
		m = ROW.match(line)
		n, raw = m.group(2), m.group(1).split(",", 1)[1].rstrip(" }")
		st = re.search(r"v\(([^)]*)\)", raw)
		nums = [float(x) for x in re.sub(r",\s*v\([^)]*\)", "", raw).split(",")]
		ob = k.props[real.get(n, n)]
		if n not in local:
			lo, hi = ep.bounds(ob.data)
			local[n] = ep.local_tris(ob.data, ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2))
		sc = tuple(float(x) for x in st.group(1).split(",")) if st else (nums[4],) * 3
		e = (nums[5], nums[3], nums[6]) if len(nums) > 6 else (0.0, nums[3], 0.0)
		return n, nums[:3], ep.game_tris(local[n], origin, yaw, nums[:3], e, sc)

	def bvh(T):
		return BVHTree.FromPolygons([tuple(v) for v in T.reshape(-1, 3)], [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(len(T))])

	_, rows, _ = placed(open(DRAFT).read())
	_, frows, _ = placed(open(fresh_path).read())
	extra = collections.Counter(frows) - collections.Counter(rows)
	bodies, fill = [], []
	for line in frows:
		n, pos, T = tris(line) if extra[line] and ROW.match(line).group(2) in ADDED else (None, None, None)
		if n:
			(bodies if n == HERO else fill).append((n, pos, T, bvh(T), T.reshape(-1, 3).min(0), T.reshape(-1, 3).max(0)))
	assert (len(bodies), len(fill)) == (2, 12)
	res = []
	for i, line in enumerate(rows, 1):
		n, pos, T = tris(line)
		P = T.reshape(-1, 3)
		lo, hi = P.min(0), P.max(0)
		row = {"Row": i, "Prop": n, "Pos": pos, "World": [round(float(v), 1) for v in ep.to_world(origin, yaw, pos)]}
		hit = False
		for group, label in ((bodies, "Body"), (fill, "Fill")):
			for j, (fn, fpos, _, B, flo, fhi) in enumerate(group, 1):
				if np.any(lo > fhi) or np.any(hi < flo):
					continue
				touch = len(B.overlap(bvh(T)))
				V = np.unique(np.round(P, 3), axis=0)
				under = sum(1 for v in V if (lambda h: h[0] is not None and h[0].y > v[1])(B.ray_cast(Vector((v[0], fhi[1] + 10, v[2])), Vector((0, -1, 0)))))
				row["%s%d" % (label, j)] = {"Prop": fn, "Pos": fpos, "TouchingTris": touch, "Under": round(under / len(V), 3)}
				hit = hit or touch > 0 or under > 0
		if hit or n == "SweeperVan":
			res.append(row)
	with open(out_path, "w") as f:
		json.dump({"Bodies": [b[1] for b in bodies], "Fill": [[b[0], b[1]] for b in fill], "Rows": res}, f, indent=1)
	for row in res:
		print("MEASURE", json.dumps(row))


def inside_rows(measured):
	return [r["Row"] for r in measured["Rows"] if r["Prop"] == "Rubble" and any(r.get(b, {}).get("Under", 0) >= INSIDE for b in ("Body1", "Body2"))]


if __name__ == "__main__":
	if HERE not in sys.path:
		sys.path.insert(0, HERE)
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
	if argv[0] == "--self-test":
		self_test()
	elif argv[0] == "--measure":
		measure(*argv[1:4])
	elif argv[0] == "--filter":
		old = open(DRAFT).read()
		drop = inside_rows(json.load(open(argv[2])))
		text = merge(old, open(argv[1]).read(), drop)
		open(DRAFT, "w").write(text)
		print("dropped", [placed(old)[1][i - 1].strip() for i in drop])
