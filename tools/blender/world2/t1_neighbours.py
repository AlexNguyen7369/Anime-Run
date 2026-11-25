"""Plans the moves and removals of the other tracks' props that stand on Track 1's ground (owner 2026-11-25, design doc change
log; docs/WORLD2_SPEC.md "Ground ownership": nearest road, base centre) and writes their rows into cross_track.json ("fix"
only, under the other track's biome; roads.apply_cross_track runs them last in those builds).
Not touched: KEEP (the one-eyed monster), and what the game already prunes (the plaza's ground is an open question).
A prop moves to the nearest legal spot within MOVE studs, its turn, height and scale unchanged, or is left out; a hero
(MODEL_SHOTS) is searched within HERO_MOVE, the smoke column within SIGHT_MOVE. Legal: its own track's Ground and own ground by more than TIE,
every vertex 24+ studs from its own centre line (clearance.py), its real triangles off every corridor (the export's test), off the plaza and checkpoints (Prune), and not standing in any
built prop of any track (cross_track.Placed, LIMIT) nor touching one of Tracks 1 and 6 (but Flowers). SIGHT props must also leave Track 1's 6% view.
Run it on the drafts before its own rows (it drops them from cross_track.json first), then with --patch, once.
Headless: Blender -b --factory-startup --python tools/blender/world2/t1_neighbours.py
Import-safe: main() runs only as a script.
"""

import importlib
import json
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import build_track as bt  # noqa: E402
import clearance  # noqa: E402
import cross_track as ct  # noqa: E402
import export_props as ep  # noqa: E402
import roads  # noqa: E402

KEEP = {(8, "FleshWall")}  # the one-eyed monster, accepted unchanged
SIGHT = {(5, "Smoke")}  # off Track 1's 6% view
MOVE, HERO_MOVE, SIGHT_MOVE, STEP = 120, 600, 2000, 6  # studs, proposed
# pieces with a hollow or a ground shape that "inside" cannot judge
VAST = {"Island", "Ceiling", "Barrier", "Abyss", "Fill", "Bank", "Pier"}


def pruned(p):
	"""BiomeDressing.Prune takes it in game."""
	lo, hi = p.shape.lo * p.sc, p.shape.hi * p.sc
	c, half = p.R @ ((lo + hi) / 2) + p.pos, (hi - lo) / 2 + ep.PRUNE_CLEAR
	return any(ep.obb_overlap(np.array((c[0], bc[1], c[2])) if col else c, p.R, half, bc, bR, bh) for bc, bR, bh, col in ct.BLOCK)


def owner_of(r, x, z):
	"""The track whose road is nearest to (x, z), None nearer than TIE to even."""
	t = np.clip((((x, z) - r.a) * r.ab).sum(1) / r.ab2, 0, 1)
	d = np.sqrt((((x, z) - r.a - t[:, None] * r.ab) ** 2).sum(1))
	who = r.own[d.argmin()]
	return who if d[r.own == who].min() + ct.TIE < d[r.own != who].min() else None


def moved(p, x, z):
	return ct.Placed(p.name, p.shape, (x, p.pos[1], z), p.R, p.sc, p.track)


def standing(p, others):
	"""The built props `p` stands in, or that stand in it."""
	out = []
	for q in others:
		if q is p or q.name in VAST or np.any(p.lo >= q.hi) or np.any(p.hi <= q.lo):
			continue
		core = bool(q.shape.inside(q.local(p.pos[None] + (0, 2.0, 0)))[0]) or bool(p.shape.inside(p.local(q.pos[None] + (0, 2.0, 0)))[0])
		if core or p.share_in(q) > ct.LIMIT or q.share_in(p) > ct.LIMIT:
			out.append(q)
	return out


def flat_gap(p, rn):
	"""The least XZ distance of p's vertices to its own road's centre line (clearance.py's test, no overhead rule)."""
	v = p.world(p.shape.tris.reshape(-1, 3))[:, [0, 2]]
	a, ab, ab2 = rn.a[rn.own == rn.number], rn.ab[rn.own == rn.number], rn.ab2[rn.own == rn.number]
	near = np.sqrt(((a + ab / 2 - v.mean(0)) ** 2).sum(1)) < np.sqrt(((v - v.mean(0)) ** 2).sum(1)).max() + np.sqrt(ab2) + 30
	if not near.any():
		return np.inf
	a, ab, ab2 = a[near], ab[near], ab2[near]
	best = np.inf
	for i in range(0, len(v), 2048):
		q = v[i : i + 2048][:, None]
		t = np.clip(((q - a) * ab).sum(2) / ab2, 0, 1)
		best = min(best, float(np.sqrt(((q - a - t[..., None] * ab) ** 2).sum(2)).min()))
	return best


def in_view(kit1, p, f):
	"""Any point of p's mesh in the frame of Track 1's run view `f` (no occlusion)."""
	pts = p.world(p.shape.tris.reshape(-1, 3))
	return f in ep.seen_by(kit1, pts)


def main():
	data = json.load(open(ct.PATH))
	for b in [b for b in data if b not in ("ElvenPlains", "DevilTokyo")]:
		del data[b]
	save(data)
	r = roads.Roads(1)
	glo, ghi = (np.array(v) for v in r.ground())
	every = ct.neighbours(1, glo - 900, ghi + 900, skip=())
	here = [p for p in every if p.track != 1 and r.nearest([(p.pos[0], p.pos[2])])[1][0] == 1 and (p.track != 6)]
	corr = clearance.corridors(bt.load_chain().values())
	k1 = bt.run(1, render=False, fast=True)
	views = {id(p): ep.seen_by(k1, p.world(p.shape.tris.reshape(-1, 3))) for p in here}
	gone, jobs = set(), []
	for p in here:
		if (p.track, p.name) in KEEP:
			print("STAY kept T%d %s (%.0f, %.0f)" % (p.track, p.name, p.pos[0], p.pos[2]))
		elif pruned(p):
			print("STAY pruned in game T%d %s (%.0f, %.0f)" % (p.track, p.name, p.pos[0], p.pos[2]))
		else:
			jobs.append(p)
			gone.add(id(p))
	stand = [p for p in every if id(p) not in gone]
	heroes, rects, exempt, rows, rn_of = {}, {}, {}, {}, {}
	for p in sorted(jobs, key=lambda q: -np.prod((q.hi - q.lo)[[0, 2]])):
		n = p.track
		if n not in heroes:
			m = importlib.import_module("biomes." + ep.APPROVED[n])
			heroes[n] = {ep.RENAME.get(h, h) for h in m.MODEL_SHOTS}
			exempt[n] = {ep.RENAME.get(h, h) for h in getattr(m, "CLEAR_EXEMPT", ())}
			rn = roads.Roads(n)
			rn_of[n] = rn
			rects[n] = [np.array(v) for v in rn.ground()]
		hero = p.name in heroes[n]
		lim = HERO_MOVE if hero else SIGHT_MOVE if (n, p.name) in SIGHT else MOVE
		ring = sorted(((i, j) for i in range(-lim, lim + 1, STEP) for j in range(-lim, lim + 1, STEP) if 0 < math.hypot(i, j) <= lim), key=lambda q: math.hypot(*q))
		new, why = None, {}

		def no(rule, why=why):
			why[rule] = why.get(rule, 0) + 1

		for i, j in ring:
			x, z = p.pos[0] + i, p.pos[2] + j
			if not (np.all((x, z) >= rects[n][0] + 2) and np.all((x, z) <= rects[n][1] - 2)) or owner_of(r, x, z) != n:
				no("ground")
				continue
			q = moved(p, x, z)
			if pruned(q):
				no("plaza or pads")
			elif p.name not in exempt[n] and flat_gap(q, rn_of[n]) < clearance.MIN_CLEAR:
				no("own road (clearance.py)")
			elif clearance.intrudes(q.world(q.shape.tris.reshape(-1, 3)).reshape(-1, 3, 3), corr, (n,) if p.name in exempt[n] else ()):
				no("corridor")
			elif standing(q, stand) or any(o.track in (1, 6) and o.name != "Flowers" and np.all(q.lo < o.hi) and np.all(q.hi > o.lo) and q.touches(o) for o in stand):
				no("stands in")
			elif (n, p.name) in SIGHT and in_view(k1, q, 0.06):
				no("in Track 1's 6% view")
			else:
				new = q
				break
		if new is not None:
			stand.append(new)
		rows.setdefault(n, []).append((p, new))
		print(
			"PLAN T%d %s (%.1f, %.1f) %s %s in T1 views %s%s"
			% (
				n,
				p.name,
				p.pos[0],
				p.pos[2],
				"hero" if hero else "",
				"to (%.1f, %.1f) %.0f studs" % (new.pos[0], new.pos[2], math.hypot(*(new.pos - p.pos)[[0, 2]])) if new is not None else "OUT %s" % why,
				views[id(p)],
				" then %s" % ep.seen_by(k1, new.world(new.shape.tris.reshape(-1, 3))) if new is not None else "",
			),
			flush=True,
		)
	for n, todo in rows.items():
		data[ep.APPROVED[n]] = {"fix": sorted(draft_rows(n, todo)), "add": []}
	save(data)


def draft_rows(n, todo):
	"""The fix rows for track n's (from, to) pairs, at the draft's own base centres."""
	import bpy
	from mathutils import Vector

	k = bt.run(n, render=False, fast=True)
	bpy.context.view_layer.update()
	centre = {name: roads.base_centre(ob.data) for name, ob in k.props.items()}
	mesh = {ob.data.name: name for name, ob in k.props.items()}
	obs = []
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.data.name in mesh:
			name = mesh[ob.data.name]
			w = ob.matrix_world @ Vector((*centre[name], 0))
			obs.append((name, w.x, -w.y))
	lights = [(ob.location.x, -ob.location.y) for ob in bpy.context.scene.objects if ob.type == "LIGHT" and ob.data.type != "SUN"]
	for p, new in todo:
		hit = min((o for o in obs if ep.RENAME.get(o[0], o[0]) == p.name), key=lambda o: math.hypot(o[1] - p.pos[0], o[2] - p.pos[2]))
		gap = math.hypot(hit[1] - p.pos[0], hit[2] - p.pos[2])
		if gap > 8:  # a tilted prop's centre is off its base centre by a little
			raise SystemExit("T%d %s: no draft object at (%.1f, %.1f), nearest %.1f" % (n, p.name, p.pos[0], p.pos[2], gap))
		obs.remove(hit)
		near = [q for q in lights if math.hypot(q[0] - p.pos[0], q[1] - p.pos[2]) < 40]
		print("ROW T%d %s gap %.3f lights within 40: %d" % (n, p.name, gap, len(near)))
		d = None if new is None else (new.pos - p.pos)
		yield [hit[0], round(hit[1], 3), round(hit[2], 3)] + ([None] * 3 if d is None else [round(hit[1] + d[0], 3), round(hit[2] + d[2], 3), None])


def save(data):
	with open(ct.PATH, "w") as f:
		f.write(ct.dump(data))


def patch():
	"""Writes the rows into the exported <Biome>Draft.luau files in place (no export: a re-export of the frozen tracks today also
	brings unrelated changes, lowered supports and hero moves)."""
	for n, biome in ep.APPROVED.items():
		todo = json.load(open(ct.PATH)).get(biome, {"fix": []})["fix"] if n not in (1, 6) else []
		if not todo:
			continue
		path = os.path.join(ep.THEMES, biome + "Draft.luau")
		src = open(path).read()
		origin, yaw = ep.origins()[n]
		for name, x, z, nx, nz, _ in todo:
			name = ep.RENAME.get(name, name)
			a = ep.to_local(origin, yaw, (x, 0, z))
			head = src.index("\tPlaced = {")
			rows, best = list(re.finditer(r'\t\t\{\s*"(\w+)",([^{}]*?)\},\n', src[head : src.index("\tHeroes = ")])), None
			for m in rows:
				if re.sub(r"_p\d+$", "", m.group(1)) == name:
					w = re.search(r"Whole = v\(([^)]*)\)", m.group(2))
					v = [float(q) for q in (w.group(1) if w else m.group(2)).split(",")[:3]]
					gap = math.hypot(v[0] - a[0], v[2] - a[2])
					if best is None or gap < best[0]:
						best = (gap, m)
			g = re.search(r"Group = \d+", best[1].group(2))
			if best[0] > 0.05 or (g and nx is not None):
				raise SystemExit("%s %s (%.1f, %.1f): no row to patch, nearest %.2f%s" % (biome, name, x, z, best[0], ", cut mesh" if g else ""))
			hit = [m for m in rows if re.search(g.group(0) + r"\b", m.group(2))] if g else [best[1]]
			for m in reversed(hit):
				new = ""
				if nx is not None:
					b = ep.to_local(origin, yaw, (nx, 0, nz))
					v = m.group(2).split(",")
					v[0], v[2] = (re.sub(r"-?[\d.]+", ep.lua_num(q), t, count=1) for q, t in ((b[0], v[0]), (b[2], v[2])))
					new = m.group(0).replace(m.group(2), ",".join(v))
				src = src[: head + m.start()] + new + src[head + m.end() :]
			print("PATCH", biome, name, "rows", len(hit), "out" if nx is None else "moved")
		with open(path, "w") as f:
			f.write(src)


if __name__ == "__main__":
	patch() if "--patch" in sys.argv else main()
