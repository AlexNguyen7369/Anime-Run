"""Where a draft prop may stand among ALL the tracks' roads, for biome layouts (docs/WORLD2_SPEC.md "Blender first": 24+
studs from the road centre line, every track's road). A quick footprint test while laying out; the exact triangle test
stays clearance.py's. Import-safe (numpy, chain.py; no bpy)."""

import math

import chain
import numpy as np

# Layout options of the swapped tracks that are only rendered, never exported: "castle_052", "turned" (biomes/ElvenPlains.py).
# Only game_shots.py sets this; it lives here because build_track.run reloads the biome modules.
OPTIONS = frozenset()
CLEAR = 25.0  # studs: the 24-stud rule and a margin
PLAZA = (94.0, 110.0)  # SpawnArea.FLOOR_SIZE / 2 at the world origin
PLAZA_CLEAR = 16.0  # BiomeDressing.CLEARANCE (8), grown boxes of turned props and a margin


class Roads:
	def __init__(self, number):
		self.number = number
		a, b, own, pads = [], [], [], []
		for t in chain.build():
			w = np.array(t["Waypoints"])[:, [0, 2]]
			a.append(w[:-1])
			b.append(w[1:])
			own.append(np.full(len(w) - 1, t["Number"]))
			u = (w[-1] - w[-2]) / np.linalg.norm(w[-1] - w[-2])
			# the checkpoint area: 100 wide by 60 behind the finish, as a disc; BiomeDressing.Prune grows it by 8
			pads.append(w[-1] - u * 30)
		self.a, self.ab, self.own = np.concatenate(a), np.concatenate(b) - np.concatenate(a), np.concatenate(own)
		self.ab2 = np.maximum((self.ab**2).sum(1), 1e-9)
		self.pads = np.array(pads)

	def nearest(self, pts):
		"""(distance to the nearest road centre line, its track number) of world points (m, 2) x, z."""
		q = np.asarray(pts, float)[:, None, :]
		t = np.clip(((q - self.a) * self.ab).sum(2) / self.ab2, 0, 1)
		d = np.sqrt(((q - self.a - t[..., None] * self.ab) ** 2).sum(2))
		k = d.argmin(1)
		return d[np.arange(len(k)), k], self.own[k]

	def fits(self, x, z, yaw, w, d, own=True, clear=CLEAR):
		"""A w x d footprint at world x, z turned `yaw` (Roblox, width along its local X) is off every road, every
		checkpoint area and the spawn plaza. own: and its centre lies nearest this track's own road."""
		c, s = math.cos(yaw), math.sin(yaw)
		n = max(3, int(math.ceil(max(w, d) / 20)) + 1)
		g = np.linspace(-0.5, 0.5, n)
		X, Z = (v.ravel() for v in np.meshgrid(g * w, g * d))
		p = np.stack((x + X * c + Z * s, z - X * s + Z * c), 1)
		dist, who = self.nearest(np.concatenate((p, [(x, z)])))
		if dist[:-1].min() < clear or (own and who[-1] != self.number):
			return False
		out = np.maximum(np.abs(p) - np.array(PLAZA), 0)
		if np.hypot(out[:, 0], out[:, 1]).min() < PLAZA_CLEAR:
			return False
		return np.sqrt(((p[:, None] - self.pads) ** 2).sum(2)).min() > 67

	def ground(self, pad=0.0):
		"""This track's own Ground in world x, z as (lo, hi) corners, shrunk by `pad` (a prop off it is not built)."""
		import export_props as ep

		origin, yaw = ep.origins()[self.number]
		(a, b) = ep.ground_rect(self.number)
		ps = [ep.to_world(origin, yaw, (x, 0, z)) for x in (a[0] + pad, b[0] - pad) for z in (a[1] + pad, b[1] - pad)]
		return (min(p[0] for p in ps), min(p[2] for p in ps)), (max(p[0] for p in ps), max(p[2] for p in ps))

	def neighbours(self, skip=(1, 6)):
		"""The footprints (centre x z, half size along its axes, axis) of the props the game builds on the other tracks
		(their exported Placed rows on their own ground). Tracks in `skip` are left out: the two swapped layouts read
		each other's export otherwise, and a second run would not be stable."""
		import os
		import re

		import export_props as ep

		out = []
		for number, biome in ep.APPROVED.items():
			if number in skip or number == self.number:
				continue
			origin, yaw = ep.origins()[number]
			glo, ghi = ep.ground_rect(number)
			src = open(os.path.join(ep.THEMES, biome + "Draft.luau")).read()
			sizes = {k: [float(x) for x in v.split(",")] for k, v in re.findall(r"\n\t\t(\w+) = \{\n\t\t\tSize = v\(([^)]*)\)", src)}
			for m in re.finditer(r'\{\s*"(\w+)",([^{}]*?)\}', src[src.index("\tPlaced = {") : src.index("\tHeroes = ")]):
				row = m.group(2)
				vecs = [[float(x) for x in q.split(",")] for q in re.findall(r"v\(([^)]*)\)", row)]
				n = [float(x) for x in re.sub(r"(Group|Whole) =.*", "", re.sub(r"v\([^)]*\)", "", row), flags=re.S).split(",") if x.strip()]
				whole = vecs[-1] if "Whole" in row else n[:3]
				if not (glo[0] <= whole[0] <= ghi[0] and glo[1] <= whole[2] <= ghi[1]):
					continue
				stretch = vecs[0] if len(n) > 5 and vecs else [n[4]] * 3
				size = np.array(sizes[m.group(1)]) * stretch
				R = np.array(ep.yaw_rot(yaw)) @ np.array(ep.from_euler_yxz(n[5] if len(n) > 5 else 0, n[3], n[6] if len(n) > 6 else 0))
				c = np.array(ep.to_world(origin, yaw, n[:3])) + R @ np.array([0, size[1] / 2, 0])
				e = np.abs(R) @ (size / 2)
				out.append((c[0], c[2], e[0], e[2], number, m.group(1)))
		return out

	def overlaps(self, near, x, z, yaw, w, d):
		"""The `near` (neighbours()) props whose world box meets the turned footprint's world box."""
		c, s = abs(math.cos(yaw)), abs(math.sin(yaw))
		ex, ez = (w * c + d * s) / 2, (w * s + d * c) / 2
		return [(n[4], n[5]) for n in near if abs(n[0] - x) < n[2] + ex and abs(n[1] - z) < n[3] + ez]


def apply_cross_track(k, path=None):
	"""cross_track.json: the props of a swapped layout whose mesh stood in another track's built prop, as
	[prop, base centre world x, z, dx, dz] (moved by dx, dz) or [prop, x, z, null, null] (left out). Heroes are never in
	it. Run last in build()."""
	import json
	import os

	import bpy
	from mathutils import Vector

	path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "cross_track.json")
	rows = json.load(open(path)).get(k.biome, []) if os.path.exists(path) else []
	if not rows:
		return
	bpy.context.view_layer.update()
	by = {}
	for name, ob in k.props.items():
		xs, ys = [v.co.x for v in ob.data.vertices], [v.co.y for v in ob.data.vertices]
		by[ob.data.name] = (name, Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 0)))
	obs = []
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name in by:
			name, c = by[ob.data.name]
			w = ob.matrix_world @ c
			obs.append((name, w.x, -w.y, ob))
	done = 0
	for name, x, z, dx, dz in rows:
		hit = min((q for q in obs if q[0] == name), key=lambda q: math.hypot(q[1] - x, q[2] - z), default=None)
		if hit is None or math.hypot(hit[1] - x, hit[2] - z) > 0.2:
			continue
		obs.remove(hit)
		done += 1
		if dx is None:
			bpy.data.objects.remove(hit[3])
		else:
			hit[3].location.x += dx
			hit[3].location.y -= dz
	print("CROSS_TRACK", k.biome, done, "of", len(rows))
