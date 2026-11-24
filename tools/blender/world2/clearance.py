"""Road clearance check for the World 2 track drafts (WORLD2_SPEC "Blender first": props stay 24+ studs from the road
centre line).

Builds each track exactly as build_track.py does (render=False), then measures, for every placed instance that is not
a road piece, the closest mesh vertex to every lap's road centre line (distance to the line segments, in the XZ plane,
Roblox studs). Exempt: road pieces, and props a biome module lists in an optional module-level CLEAR_EXEMPT set (pieces
that span the road with 14+ overhead clearance, or sit under a raised road as its support).
Prints one FAIL line per offending instance (prop, its closest point, distance along the road, distance from the
centre line), then "CLEAR n/n" for the track, or "FAIL k".
--all-tracks (WORLD2_SPEC "Render set approvals", 2026-11-24): instead tests every placed instance's real triangles
against EVERY track's road corridor (corridors(), intrudes()); export_props.py runs the same test on the game transform.
Headless:  Blender -b --factory-startup --python tools/blender/world2/clearance.py -- <number ...|all> [--all-tracks]
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
OVERHEAD = 14.0  # a piece 14+ studs over the road top clears it
JOIN = 2.0  # each segment box runs this far past its ends, closing the outer wedge of a 6-degree turn step (1.3 deep)
ROAD_PIECES = ("Wall", "Dash", "Apron", "WinPad", "Road", "Ground")


def corridors(tracks):
	"""Each track's road corridor as boxes, one per centre-line segment (tracks: chain.build() rows, world waypoints).
	A box runs along the segment (JOIN past each end), MIN_CLEAR each side of the centre line, and from the road top
	(the waypoint Y, the lower end of a slope step) to OVERHEAD over its higher end: the union is the space within 24
	studs of the centre line and under 14 over the road. Returns {number: dict of (S,) arrays}."""
	out = {}
	for t in tracks:
		w = np.array(t["Waypoints"], float)
		a, b = w[:-1], w[1:]
		d = b[:, [0, 2]] - a[:, [0, 2]]
		L = np.sqrt((d * d).sum(1))
		keep = L > 1e-6
		a, b, d, L = a[keep], b[keep], d[keep], L[keep]
		u = d / L[:, None]
		lat = np.stack((-u[:, 1], u[:, 0]), 1)
		hl = L / 2 + JOIN
		ylo, yhi = np.minimum(a[:, 1], b[:, 1]) + 0.05, np.maximum(a[:, 1], b[:, 1]) + OVERHEAD  # flush with the top: clear
		ext = np.abs(u) * hl[:, None] + np.abs(lat) * MIN_CLEAR  # the box's half extent on world x, z
		out[t["Number"]] = {"c": (a[:, [0, 2]] + b[:, [0, 2]]) / 2, "u": u, "lat": lat, "hl": hl, "ylo": ylo, "yhi": yhi, "ext": ext}
	return out


def _tri_box(P, h):
	"""Separating-axis test (Akenine-Moller): triangles P (n, 3, 3) in their boxes' frames, boxes centred at the origin
	with half sizes h (n, 3). True where a triangle touches its box."""
	ok = np.all((P.min(1) <= h) & (P.max(1) >= -h), 1)
	e = (P[:, 1] - P[:, 0], P[:, 2] - P[:, 1], P[:, 0] - P[:, 2])
	n = np.cross(e[0], e[1])
	ok &= np.abs((n * P[:, 0]).sum(1)) <= (np.abs(n) * h).sum(1)
	z = np.zeros(len(P))
	for f in e:
		for ax in (np.stack((z, -f[:, 2], f[:, 1]), 1), np.stack((f[:, 2], z, -f[:, 0]), 1), np.stack((-f[:, 1], f[:, 0], z), 1)):
			p = np.einsum("nkj,nj->nk", P, ax)
			r = (np.abs(ax) * h).sum(1)
			ok &= ~((p.min(1) > r) | (p.max(1) < -r))
	return ok


def intrudes(tris, corr, skip=()):
	"""Track numbers whose corridor (corridors()) a set of world triangles (m, 3, 3; Roblox studs, Y up) touches,
	skipping the tracks in `skip`. Exact for the boxes: every triangle against every segment box near it."""
	lo, hi = tris.min(1), tris.max(1)
	glo, ghi = lo.min(0)[[0, 2]], hi.max(0)[[0, 2]]
	centre, rad = (glo + ghi) / 2, np.sqrt((((ghi - glo) / 2) ** 2).sum())
	hits = set()
	for number, c in corr.items():
		if number in skip:
			continue
		near = np.nonzero(np.sqrt(((c["c"] - centre) ** 2).sum(1)) < rad + c["hl"] + MIN_CLEAR + 1)[0]
		if not len(near):
			continue
		for chunk in range(0, len(tris), 1024):
			T, tlo, thi = tris[chunk : chunk + 1024], lo[chunk : chunk + 1024], hi[chunk : chunk + 1024]
			ti, si = np.nonzero(
				(tlo[:, None, 0] <= c["c"][near, 0] + c["ext"][near, 0])
				& (thi[:, None, 0] >= c["c"][near, 0] - c["ext"][near, 0])
				& (tlo[:, None, 2] <= c["c"][near, 1] + c["ext"][near, 1])
				& (thi[:, None, 2] >= c["c"][near, 1] - c["ext"][near, 1])
				& (tlo[:, None, 1] <= c["yhi"][near])
				& (thi[:, None, 1] >= c["ylo"][near])
			)
			if not len(ti):
				continue
			s = near[si]
			P = T[ti]
			rel = P[:, :, [0, 2]] - c["c"][s][:, None, :]
			ymid = (c["ylo"][s] + c["yhi"][s]) / 2
			Q = np.stack(((rel * c["u"][s][:, None, :]).sum(2), P[:, :, 1] - ymid[:, None], (rel * c["lat"][s][:, None, :]).sum(2)), 2)
			h = np.stack((c["hl"][s], (c["yhi"][s] - c["ylo"][s]) / 2, np.full(len(s), MIN_CLEAR)), 1)
			if _tri_box(Q, h).any():
				hits.add(number)
				break
	return hits


def self_test():
	"""The corridor test on known cases (one straight road along -Z at y 1): raises on a wrong answer."""
	corr = corridors([{"Number": 1, "Waypoints": [(0, 1, 0), (0, 1, -100)]}])
	tri = lambda *p: np.array([p], float)  # noqa: E731
	assert intrudes(tri((30, 2, -50), (-30, 2, -50), (30, 2, -60)), corr) == {1}  # a long triangle across the road, no vertex near
	assert intrudes(tri((25, 2, -50), (40, 2, -50), (25, 9, -60)), corr) == set()  # 25 off the line
	assert intrudes(tri((-5, 16, -50), (5, 16, -50), (0, 30, -60)), corr) == set()  # 15 over the road top
	assert intrudes(tri((-5, 0, -50), (5, 0, -50), (0, -9, -60)), corr) == set()  # under the road top
	assert intrudes(tri((23, 2, -50), (40, 2, -50), (40, 9, -60)), corr) == {1}  # one corner 23 off
	assert intrudes(tri((0, 5, 1.5), (3, 5, 1.5), (0, 8, 1.5)), corr) == {1}  # within JOIN past the end
	assert intrudes(tri((0, 5, 5), (3, 5, 5), (0, 8, 5)), corr) == set()  # past the end of the road
	assert intrudes(tri((-30, -5, -50), (30, -5, -50), (0, 40, -50)), corr) == {1}  # a wall standing across the road


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


def check_all(number):
	"""Builds track `number`; returns (checked, {prop: {track: instances}}) for the instances whose real triangles (as
	the draft places them) intrude on any track's corridor. CLEAR_EXEMPT props skip their own track only."""
	self_test()
	k = build_track.run(number, fast=True, render=False)
	exempt = set(getattr(importlib.import_module("biomes." + k.biome), "CLEAR_EXEMPT", ()))
	corr = corridors(build_track.load_chain().values())
	prefix = "W2_%s_" % k.biome
	checked, fails = 0, {}
	for ob in k.col.objects:
		if ob.type != "MESH" or not ob.name.startswith(prefix):
			continue
		prop = ob.data.name[len(prefix) :]
		if any(prop.startswith(r) for r in ROAD_PIECES):
			continue
		checked += 1
		me = ob.data
		me.calc_loop_triangles()
		co = np.empty(len(me.vertices) * 3)
		me.vertices.foreach_get("co", co)
		idx = np.empty(len(me.loop_triangles) * 3, int)
		me.loop_triangles.foreach_get("vertices", idx)
		m = np.array(ob.matrix_world)
		w = co.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
		w = np.stack((w[:, 0], w[:, 2], -w[:, 1]), 1)  # Blender -> Roblox
		for t in intrudes(w[idx.reshape(-1, 3)], corr, (number,) if prop in exempt else ()):
			fails.setdefault(prop, {}).setdefault(t, 0)
			fails[prop][t] += 1
	return checked, fails


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	nums = [a for a in argv if not a.startswith("--")]
	numbers = list(range(1, 11)) if nums in ([], ["all"]) else [int(a) for a in nums]
	if "--all-tracks" in argv:
		for n in numbers:
			checked, fails = check_all(n)
			for prop, by in sorted(fails.items()):
				print("FAIL track %d %s intrudes on %s" % (n, prop, ", ".join("track %d x%d" % kv for kv in sorted(by.items()))))
			print("TRACK %d %s" % (n, "CLEAR %d/%d" % (checked, checked) if not fails else "FAIL %d" % sum(sum(b.values()) for b in fails.values())))
		return
	for n in numbers:
		checked, fails = check(n)
		for prop, x, z, along, dist in sorted(fails, key=lambda f: f[3]):
			print("FAIL track %d %s at (%.0f, %.0f) d=%.0f: %.1f from the centre line" % (n, prop, x, z, along, dist))
		print("TRACK %d %s" % (n, ("CLEAR %d/%d" % (checked, checked)) if not fails else ("FAIL %d" % len(fails))))


if __name__ == "__main__":
	main()
