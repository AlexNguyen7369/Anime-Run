"""Writes cross_track.json, what roads.apply_cross_track does last to the two swapped layouts (Tracks 1 and 6).

Ground (owner 2026-11-25, docs/WORLD2_SPEC.md "Ground ownership"): the nearest road centre line owns a spot. A prop of ours is
judged by its base centre (round 6; the owner has not ruled on centre or footprint yet). Every other track is frozen and
only read: the rows of its exported <Biome>Draft.luau on its own Ground, with its draft's meshes.
1. fix: a prop of ours off our ground, or standing in another track's prop, moves to the nearest legal spot within MOVE
   studs (the same offset from the road's heading there: the old draft's turn rule; a free-standing prop keeps its turn)
   or is left out. "Standing in" (LIMIT of sampled surface points, KIT_LIMIT for the StreetKit, whose wires reach far; both
   **proposed**): more of our points than that, or our base centre, inside the other mesh, or more of its points than that
   inside ours. Where the other prop stands on OUR ground (it is the one to go) only our points count.
2. fill: FILL's props, at the first legal spots, under the same rules and off our other props.
KEEP (the approved hero rows) is never moved or left out here.
Headless: Blender -b --factory-startup --python tools/blender/world2/cross_track.py -- [1] [6]
Import-safe: main() runs only as a script.
"""

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
import export_props as ep  # noqa: E402
import roads  # noqa: E402

PATH = os.path.join(HERE, "cross_track.json")
CACHE = os.path.join(bt.BUILD, "cross_mesh")  # the frozen drafts' meshes, rebuilt when a module is newer
# PROPOSED, not ruled by the owner and in no doc: a prop stands in another when more than 5% (StreetKit: 15%) of its sampled
# surface points are inside it. CrossWire is exempt from this test (wires over the road; it only goes when a pole is out).
LIMIT, KIT_LIMIT = 0.05, 0.15
TIE = 1.0  # studs, proposed: nearer than this to even between two roads is no one's ground, and ours stay off it
MOVE, STEP = 40, 4  # studs: how far a prop may move, and the search grid
SAMPLES = 400
KEEP = {"HQ", "HeroStatue", "Rank", "Retro", "Town", "RuinedCastle", "Mountain"}
FREE = {"Pine", "Flowers", "Office"}  # no front: a random turn
THIN = {"Pine", "Flowers", "Forest"}  # plants stand among plants (no two Forests); a solid prop's own box keeps them out
# the layouts' own footprints (width, depth), as their placers test them
BOX = {
	"Forest": (90, 62), "Pine": (12, 12), "Flowers": (26, 19), "RuinWall": (41, 21), "Mound": (150, 104), "Cottage": (30, 29),
	"HeroStatue": (24, 24), "Rank": (104, 66), "Mansion": (74, 36), "Apaato": (50, 34), "ShopHouse": (30, 24),
	"Konbini": (50, 26), "StreetKit": (48, 8), "LowBlock": (100, 100), "Retro": (32, 30), "Office": (46, 46), "HQ": (192, 130),
}  # fmt: skip
TALL = {"Pine", "Forest", "Mound", "Mansion", "ShopHouse", "Office"}  # may hide a landmark (the layout's `hidden`)
TOWER = (0.36, 0.55)  # the approved draft's Office scales
BLOCK = ep.blockers()  # the game takes a neighbour that meets these (BiomeDressing.Prune); still treated as standing here


def woods(count, name, scale, gap, seed):
	"""`name` over our own ground, seeded, at least `gap` studs from others of its kind."""

	def spots(lay):
		rng = np.random.default_rng(seed)
		for x, z in rng.uniform(lay.glo + 4, lay.ghi - 4, (6000, 2)):
			turn, sc = rng.uniform(0, math.tau), rng.uniform(*scale)
			if not lay.owned(x, z) or any(q.name == name and math.hypot(q.pos[0] - x, q.pos[2] - z) < gap for q in lay.kept):
				continue
			yield lay.make(name, x, z, turn if name in FREE else lay.road_yaw(x, z), sc)

	return {"what": name, "count": count, "spots": spots}


def towers(count, gap, seed):
	"""The skyline's offices beside the road, seeded, at least `gap` studs apart (the old draft's spacing), big ones first."""

	def spots(lay):
		rng = np.random.default_rng(seed)
		draws = sorted(((rng.uniform(*TOWER), rng.uniform(20, lay.k.length - 70), rng.choice((-1, 1)) * rng.uniform(36, 80), rng.uniform(0, math.tau)) for _ in range(9000)), reverse=True)
		for sc, d, off, turn in draws:
			(x, _, z), _ = lay.k.beside(d, off)
			if all(q.name != "Office" or math.hypot(q.pos[0] - x, q.pos[2] - z) >= gap for q in lay.kept):
				yield lay.make("Office", x, z, turn, sc)

	return {"what": "Office", "count": count, "spots": spots}


def fronts(names, offs, count, seed):
	"""Street fronts facing the road in the gaps of a street, along both sides."""

	def spots(lay):
		rng = np.random.default_rng(seed)
		for side in (-1, 1):
			last = None
			for d in range(20, int(lay.k.length) - 70, 6):
				order = [n for n in rng.permutation(names) if n != last]
				for name in order:
					w, dep = BOX[name]
					for off in offs:
						pos, yaw = lay.k.beside(d + w / 2, side * (off + dep / 2))
						if not lay.owned(pos[0], pos[2]):
							continue
						n = len(lay.kept)
						yield lay.make(name, pos[0], pos[2], yaw + side * math.pi / 2, 1.0)
						if len(lay.kept) > n:
							last = name
							break
					else:
						continue
					break

	return {"what": "street fronts", "count": count, "spots": spots}


FILL = {
	"ElvenPlains": [
		woods(5, "RuinWall", (1.0, 1.2), 70, 4),
		woods(2, "Cottage", (0.9, 1.05), 40, 5),
		woods(20, "Forest", (0.9, 1.05), 60, 6),
		woods(80, "Pine", (0.9, 1.5), 12, 7),
		woods(20, "Flowers", (1.0, 1.5), 30, 9),
	],
	"DevilTokyo": [fronts(("ShopHouse", "Apaato", "Konbini"), (40, 46, 54, 62), 80, 8), towers(41, 70, 5)],
}


def yaw_mat(y):
	return np.array(ep.yaw_rot(y))


def meshes(number):
	"""{prop (game name): triangles about its base centre} of a track's draft, cached."""
	biome = ep.APPROVED[number]
	path = os.path.join(CACHE, biome + ".npz")
	srcs = [os.path.join(HERE, "biomes", biome + ".py"), os.path.join(HERE, "kit.py")]
	if not os.path.exists(path) or os.path.getmtime(path) < max(os.path.getmtime(s) for s in srcs):
		k = bt.run(number, render=False, fast=True)
		d = {}
		for p in k.props:
			if p not in ep.ROAD:
				lo, hi = ep.bounds(k.props[p].data)
				d[ep.RENAME.get(p, p)] = ep.local_tris(k.props[p].data, ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)).astype("f4")
		os.makedirs(CACHE, exist_ok=True)
		np.savez(path, **d)
	return dict(np.load(path))


class Shape:
	"""A prop type's mesh: a BVH and sampled surface points, about its base centre."""

	def __init__(self, tris):
		from mathutils.bvhtree import BVHTree

		self.tris = tris = tris.astype(float)
		self.bvh = BVHTree.FromPolygons(tris.reshape(-1, 3).tolist(), np.arange(len(tris) * 3).reshape(-1, 3).tolist())
		area = np.linalg.norm(np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]), axis=1)
		rng = np.random.default_rng(1)
		t = tris[rng.choice(len(tris), SAMPLES, p=area / area.sum())]
		u, v = np.sqrt(rng.random(SAMPLES)), rng.random(SAMPLES)
		self.pts = t[:, 0] * (1 - u)[:, None] + t[:, 1] * (u * (1 - v))[:, None] + t[:, 2] * (u * v)[:, None]
		self.lo, self.hi = tris.reshape(-1, 3).min(0), tris.reshape(-1, 3).max(0)

	def inside(self, pts):
		"""Which points (mesh space) are inside: the first face met looking out along three directions is a back face."""
		from mathutils import Vector

		near = np.all((pts >= self.lo) & (pts <= self.hi), 1)
		out = np.zeros(len(pts), bool)
		for i in np.nonzero(near)[0]:
			p = Vector(pts[i])
			for d in ((0.31, 0.9, 0.17), (-0.7, 0.5, 0.41), (0.2, 0.6, -0.77)):
				d = Vector(d).normalized()
				h = self.bvh.ray_cast(p, d)
				if h[0] is None or h[1].dot(d) <= 0:
					break
			else:
				out[i] = True
		return out


class Placed:
	"""One placed prop: its type, world base centre, turn matrix and scale per axis."""

	def __init__(self, name, shape, pos, R, sc, track):
		self.name, self.shape, self.pos, self.R, self.sc, self.track = name, shape, np.array(pos, float), np.array(R), np.array(sc, float), track
		c = np.array([[x, y, z] for x in (0, 1) for y in (0, 1) for z in (0, 1)]) * (shape.hi - shape.lo) + shape.lo
		w = self.world(c)
		self.lo, self.hi = w.min(0), w.max(0)

	def world(self, p):
		return (p * self.sc) @ self.R.T + self.pos

	def local(self, w):
		return ((w - self.pos) @ self.R) / self.sc

	def share_in(self, other):
		return float(other.shape.inside(other.local(self.world(self.shape.pts))).mean())

	def touches(self, other):
		from mathutils.bvhtree import BVHTree

		l, h = np.maximum(self.lo, other.lo), np.minimum(self.hi, other.hi)
		sides = []
		for q in (self, other):
			T = q.world(q.shape.tris.reshape(-1, 3)).reshape(-1, 3, 3)
			T = T[np.all((T.min(1) <= h) & (T.max(1) >= l), 1)]
			if not len(T):
				return False
			sides.append(BVHTree.FromPolygons(T.reshape(-1, 3).tolist(), np.arange(len(T) * 3).reshape(-1, 3).tolist()))
		return bool(sides[0].overlap(sides[1]))


def neighbours(number, lo, hi):
	"""The props the game builds on the eight frozen tracks whose boxes reach the world box lo..hi."""
	out = []
	for n, biome in ep.APPROVED.items():
		if n in (1, 6):
			continue
		shapes, (origin, yaw), (glo, ghi), done = {}, ep.origins()[n], ep.ground_rect(n), set()
		ms = meshes(n)
		src = open(os.path.join(ep.THEMES, biome + "Draft.luau")).read()
		for m in re.finditer(r'\{\s*"(\w+)",([^{}]*?)\}', src[src.index("\tPlaced = {") : src.index("\tHeroes = ")]):
			name, body = m.groups()
			g, wh = re.search(r"Group = (\d+)", body), re.search(r"Whole = v\(([^)]*)\)", body)
			if g:  # a cut mesh: its pieces are one prop on the whole's base centre
				if g.group(1) in done:
					continue
				done.add(g.group(1))
				name = re.sub(r"_p\d+$", "", name)
			raw = re.sub(r"Whole = v\([^)]*\)|Group = \d+", "", body)
			st = re.search(r"v\(([^)]*)\)", raw)
			v = [float(x) for x in re.sub(r"v\([^)]*\)", "", raw).split(",") if x.strip()]
			pos = [float(x) for x in wh.group(1).split(",")] if wh else v[:3]
			if not (glo[0] <= pos[0] <= ghi[0] and glo[1] <= pos[2] <= ghi[1]):
				continue
			sc = [float(x) for x in st.group(1).split(",")] if st else [v[4]] * 3
			rx, rz = (v[5], v[6]) if len(v) > 6 else (0, 0)
			if name not in shapes:
				shapes[name] = Shape(ms[name])
			p = Placed(name, shapes[name], ep.to_world(origin, yaw, pos), yaw_mat(yaw) @ np.array(ep.from_euler_yxz(rx, v[3], rz)), sc, n)
			if np.all(p.lo[[0, 2]] <= hi) and np.all(p.hi[[0, 2]] >= lo):
				out.append(p)
	return out


class Layout:
	def __init__(self, number):
		roads.RAW = True
		self.number, self.biome = number, ep.APPROVED[number]
		self.r = roads.Roads(number)
		glo, ghi = self.r.ground()
		self.glo, self.ghi = np.array(glo), np.array(ghi)
		self.near = neighbours(number, self.glo - 200, self.ghi + 200)  # builds other tracks: before ours
		self.k = k = bt.run(number, render=False, fast=True)
		self.corr = clearance.corridors(bt.load_chain().values())
		import bpy
		from mathutils import Vector

		bpy.context.view_layer.update()
		names = [n for n in k.props if n not in ep.ROAD]
		self.shape, self.base, self.own = {}, {}, []
		mesh = {k.props[n].data.name: n for n in names}
		for n in names:
			lo, hi = ep.bounds(k.props[n].data)
			self.base[n] = lo[1]  # some meshes reach under the ground
			self.shape[n] = Shape(ep.local_tris(k.props[n].data, ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)))
		for ob in k.col.objects:
			if ob.type != "MESH" or ob.data.name not in mesh:
				continue
			n = mesh[ob.data.name]
			(cx, cy), m = roads.base_centre(ob.data), ob.matrix_world
			w = m @ Vector((cx, cy, min(v.co.z for v in ob.data.vertices)))
			self.own.append(self.make(n, w.x, -w.y, ob.rotation_euler[2], ob.scale[0], w.z))
		near = self.r.nearest([(q.pos[0], q.pos[2]) for q in self.near])[1]
		for q, who in zip(self.near, near):
			q.on_ours = who == number
			lo, hi = q.shape.lo * q.sc, q.shape.hi * q.sc
			c, half = q.R @ ((lo + hi) / 2) + q.pos, (hi - lo) / 2 + ep.PRUNE_CLEAR
			q.pruned = any(ep.obb_overlap(np.array((c[0], bc[1], c[2])) if col else c, q.R, half, bc, bR, bh) for bc, bR, bh, col in BLOCK)
		w = np.array([(p.x, p.z) for p in k.wps])
		self.a, self.ab = w[:-1], np.diff(w, axis=0)

	def make(self, name, x, z, yaw, scale, y=None):
		y = roads.PROP_Y.get(name, roads.GROUND_Y[self.biome]) + self.base[name] * scale if y is None else y
		p = Placed(name, self.shape[name], (x, y, z), yaw_mat(yaw), (scale,) * 3, self.number)
		p.yaw, p.scale = yaw, scale
		return p

	def owned(self, x, z):
		"""Our road is the nearest, by more than TIE."""
		r = self.r
		t = np.clip((((x, z) - r.a) * r.ab).sum(1) / r.ab2, 0, 1)
		d = np.sqrt((((x, z) - r.a - t[:, None] * r.ab) ** 2).sum(1))
		return d[r.own == self.number].min() + TIE < d[r.own != self.number].min()

	def road_yaw(self, x, z):
		"""The turn that faces -Z to the nearest point of our road."""
		t = np.clip((((x, z) - self.a) * self.ab).sum(1) / np.maximum((self.ab**2).sum(1), 1e-9), 0, 1)
		q = self.a + t[:, None] * self.ab
		c = q[((q - (x, z)) ** 2).sum(1).argmin()]
		return math.atan2(-(c[0] - x), -(c[1] - z))

	def contacts(self, p):
		"""[(neighbour, our share inside it, its share inside ours, standing in it)] of the props p's box meets."""
		out = []
		lim = KIT_LIMIT if p.name == "StreetKit" else LIMIT
		if p.name == "CrossWire":
			lim = 1.0
		for q in self.near:
			if np.any(p.lo >= q.hi) or np.any(p.hi <= q.lo):
				continue
			a, b = p.share_in(q), q.share_in(p)
			core = p.name != "CrossWire" and bool(q.shape.inside(q.local(p.pos[None] + (0, 2.0, 0)))[0])
			bad = a > lim or core or (b > lim and not q.on_ours and p.name != "StreetKit")
			out.append((q, a, b, bad))
		return out

	def box(self, p, grow=1.0):
		w, d = BOX[p.name]
		return np.array([p.pos[0], p.pos[2]]), p.yaw, np.array((w, d)) * p.scale / 2 * grow

	def meets_own(self, p, others):
		if p.name == "CrossWire":
			return False
		c, y, h = self.box(p, 0.96)
		for q in others:
			if q.name not in BOX or ({p.name, q.name} <= THIN and {p.name, q.name} != {"Forest"}):
				continue
			c2, y2, h2 = self.box(q, 0.96)
			if math.hypot(*(c - c2)) > np.linalg.norm(h) + np.linalg.norm(h2):
				continue
			ok = False
			for yy in (y, y2):
				for ax in (np.array((math.cos(yy), -math.sin(yy))), np.array((math.sin(yy), math.cos(yy)))):
					ext = sum(abs(ax @ np.array((math.cos(t), -math.sin(t)))) * e[0] + abs(ax @ np.array((math.sin(t), math.cos(t)))) * e[1] for t, e in ((y, h), (y2, h2)))
					ok = ok or abs(ax @ (c - c2)) >= ext
			if not ok:
				return True
		return False

	def blocks_camera(self, x, z):
		"""Close before a run camera (build_track.shots), where one tree would fill the view."""
		for f in (0.06, 0.33, 0.62, 0.9):
			p, right, t = self.k.at(self.k.length * f)
			v = (x - p.x - right.x * 10, z - p.z - right.z * 10)
			if -14 < v[0] * t.x + v[1] * t.z < 110 and abs(v[0] * right.x + v[1] * right.z) < 60:
				return True
		return False

	def legal(self, p, others, view=True):
		"""Own ground by base centre, the layout's footprint rule, the exact road test, no neighbour it stands in, off our props."""
		w, d = BOX[p.name]
		x, z = p.pos[0], p.pos[2]
		if not (np.all((x, z) >= self.glo + 2) and np.all((x, z) <= self.ghi - 2)):
			return False
		if not self.owned(x, z):
			return False
		clear = 24.2 if p.name == "LowBlock" else 24.5
		if not self.r.fits(x, z, p.yaw, w * p.scale, d * p.scale, clear=clear):
			return False
		if view and p.name in TALL and self.k.hidden(x, z, w * p.scale):
			return False
		if view and p.name in ("Pine", "Forest") and self.blocks_camera(x, z):
			return False
		if self.meets_own(p, others) or any(c[3] for c in self.contacts(p)):
			return False
		return not clearance.intrudes(p.world(p.shape.tris.reshape(-1, 3)).reshape(-1, 3, 3), self.corr)

	def fix(self):
		self.rows, self.adds, self.kept = [], [], []
		g = lambda p: np.all((p.pos[0], p.pos[2]) >= self.glo) and np.all((p.pos[0], p.pos[2]) <= self.ghi)  # noqa: E731
		bad, why = [], {}
		for p in self.own:
			if p.name in KEEP or p.name == "CrossWire" or not g(p):  # off our Ground: not built
				self.kept.append(p)
			elif not self.owned(p.pos[0], p.pos[2]):
				bad.append((p, "ground"))
			elif any(c[3] for c in self.contacts(p)):
				bad.append((p, "stands in"))
			else:
				self.kept.append(p)
		ring = sorted(((i, j) for i in range(-MOVE, MOVE + 1, STEP) for j in range(-MOVE, MOVE + 1, STEP) if 0 < math.hypot(i, j) <= MOVE), key=lambda q: math.hypot(*q))
		for p, reason in bad:
			x, z = p.pos[0], p.pos[2]
			new = None
			turn = p.yaw - self.road_yaw(x, z)
			for i, j in () if p.name in ("StreetKit", "Flowers") else ring:
				yaw = p.yaw if p.name in FREE else self.road_yaw(x + i, z + j) + turn
				q = self.make(p.name, x + i, z + j, yaw, p.scale, p.pos[1])
				if self.legal(q, self.kept):
					new = q
					break
			row = [p.name, round(x, 3), round(z, 3)]
			if new is None:
				self.rows.append(row + [None] * 3)
			else:
				self.kept.append(new)
				self.rows.append(row + [round(new.pos[0], 3), round(new.pos[2], 3), round(new.yaw, 5)])
			key = (p.name, reason, "out" if new is None else "moved")
			why[key] = why.get(key, 0) + 1
		# a wire over the street needs a pole at both ends
		kits = np.array([(p.pos[0], p.pos[2]) for p in self.kept if p.name == "StreetKit"]).reshape(-1, 2)
		for p in [p for p in self.kept if p.name == "CrossWire"]:
			if (np.hypot(*(kits - (p.pos[0], p.pos[2])).T) < 48).sum() < 2:
				self.kept.remove(p)
				self.rows.append(["CrossWire", round(p.pos[0], 3), round(p.pos[2], 3)] + [None] * 3)
				why[("CrossWire", "pole out", "out")] = why.get(("CrossWire", "pole out", "out"), 0) + 1
		for q, n in sorted(why.items()):
			print("FIX", self.biome, *q, n)

	def fill(self):
		for rule in FILL[self.biome]:
			placed = 0
			for p in rule["spots"](self):
				if placed >= rule["count"]:
					break
				if self.legal(p, self.kept, rule.get("view", True)):
					self.kept.append(p)
					self.adds.append([p.name, round(p.pos[0], 3), round(p.pos[2], 3), round(p.yaw, 5), round(p.scale, 3)])
					placed += 1
			print("FILL", self.biome, rule["what"], placed, "of", rule["count"])

	def report(self):
		"""Our props on another track's ground, and the neighbours on our ground that ours touch."""
		g = [p for p in self.kept if np.all((p.pos[0], p.pos[2]) >= self.glo) and np.all((p.pos[0], p.pos[2]) <= self.ghi)]
		off = [p for p in g if not self.owned(p.pos[0], p.pos[2])]
		print("OWN", self.biome, "built", len(g), "on another track's ground", len(off), [(p.name, round(p.pos[0]), round(p.pos[2])) for p in off])
		count, touch = {}, {True: {}, False: {}}
		for p in g:
			count[p.name] = count.get(p.name, 0) + 1
			for q, a, b, bad in self.contacts(p):
				if a or b or p.touches(q):
					key = (q.track, q.name, round(q.pos[0]), round(q.pos[2]), " (pruned in game)" if q.pruned else "")
					touch[bool(q.on_ours)].setdefault(key, []).append("%s%s" % (p.name, " IN" if bad else ""))
		print("COUNT", self.biome, dict(sorted(count.items())))
		for ours, rows in touch.items():
			for key, v in sorted(rows.items()):
				print("TOUCH", self.biome, "on our ground:" if ours else "on its ground:", "T%d %s (%d, %d)%s" % key, ", ".join("%s x%d" % (n, v.count(n)) for n in sorted(set(v))))


def main():
	argv = [int(a) for a in sys.argv[sys.argv.index("--") + 1 :]] or [1, 6]
	data = json.load(open(PATH)) if os.path.exists(PATH) else {}
	for number in argv:
		lay = Layout(number)
		lay.fix()
		lay.fill()
		lay.report()
		data[lay.biome] = {"fix": lay.rows, "add": lay.adds}
	with open(PATH, "w") as f:
		f.write("{\n" + ",\n".join('"%s": {\n"fix": [\n%s\n],\n"add": [\n%s\n]}' % (b, ",\n".join(json.dumps(r) for r in d["fix"]), ",\n".join(json.dumps(r) for r in d["add"])) for b, d in sorted(data.items())) + "\n}\n")


if __name__ == "__main__":
	main()
