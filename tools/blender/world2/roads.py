"""Where a draft prop may stand among ALL the tracks' roads, for biome layouts (docs/WORLD2_SPEC.md "Blender first": 24+
studs from the road centre line, every track's road). A quick footprint test while laying out; the exact triangle test
stays clearance.py's. Import-safe (numpy, chain.py; no bpy)."""

import math

import chain
import numpy as np

# Layout options of the swapped tracks that are only rendered, never exported: "castle_052", "turned" (biomes/ElvenPlains.py).
# Only game_shots.py sets this; it lives here because build_track.run reloads the biome modules.
OPTIONS = frozenset()
RAW = False  # only cross_track.py sets it: the layout before cross_track.json
GROUND_Y = {"ElvenPlains": -1.0, "DevilTokyo": 0.0}  # the height of a placed prop
PROP_Y = {"Office": -1.0}  # where a prop type differs
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

	def neighbours(self, skip=(1, 6), own_ground=False):
		"""The footprints (centre x z, half size along its axes, axis) of the props the game builds on the other tracks
		(their exported Placed rows on their own ground). Tracks in `skip` are left out: the two swapped layouts read
		each other's export otherwise, and a second run would not be stable. own_ground: not the props whose base
		centre stands on this track's ground (nearest road, owner 2026-11-25): they are the ones to go."""
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
				base = ep.to_world(origin, yaw, whole)
				if own_ground and self.nearest([(base[0], base[2])])[1][0] == self.number:
					continue
				out.append((c[0], c[2], e[0], e[2], number, m.group(1)))
		return out

	def overlaps(self, near, x, z, yaw, w, d):
		"""The `near` (neighbours()) props whose world box meets the turned footprint's world box."""
		c, s = abs(math.cos(yaw)), abs(math.sin(yaw))
		ex, ez = (w * c + d * s) / 2, (w * s + d * c) / 2
		return [(n[4], n[5]) for n in near if abs(n[0] - x) < n[2] + ex and abs(n[1] - z) < n[3] + ez]


def base_centre(me):
	"""The Blender-local centre (x, y) of a mesh's box: its base centre is what the exporter calls the prop's place."""
	xs, ys = [v.co.x for v in me.vertices], [v.co.y for v in me.vertices]
	return (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2


def apply_cross_track(k, path=None):
	"""cross_track.json (written by cross_track.py), run last in build(). Per biome: "fix", rows [prop, base centre world
	x, z, new x, new z, yaw] (moved and turned) or [prop, x, z, null, null, null] (left out); "add", rows [prop, base
	centre x, z, yaw, scale]. HQ, HeroStatue, Rank and Retro are never in it. A row that finds no prop raises: the layout
	changed under the file, which must then be written again. Skipped while RAW is set (cross_track.py) and under a
	not exported layout option (whose layout is another one)."""
	import json
	import os

	import bpy
	from mathutils import Vector

	if RAW or OPTIONS:
		return
	path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "cross_track.json")
	data = json.load(open(path)).get(k.biome, {"fix": [], "add": []})
	bpy.context.view_layer.update()
	centre = {name: base_centre(ob.data) for name, ob in k.props.items()}
	mesh = {ob.data.name: name for name, ob in k.props.items()}
	obs = []
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name in mesh:
			name = mesh[ob.data.name]
			w = ob.matrix_world @ Vector((*centre[name], 0))
			obs.append((name, w.x, -w.y, ob))

	def put(ob, name, x, z, yaw):
		"""Turns `ob` to `yaw` and moves it so its base centre stands at world x, z."""
		ob.rotation_euler[2] = yaw
		cx, cy = centre[name][0] * ob.scale[0], centre[name][1] * ob.scale[1]
		ob.location.x = x - (cx * math.cos(yaw) - cy * math.sin(yaw))
		ob.location.y = -z - (cx * math.sin(yaw) + cy * math.cos(yaw))

	for name, x, z, nx, nz, yaw in data["fix"]:
		hit = min((q for q in obs if q[0] == name), key=lambda q: math.hypot(q[1] - x, q[2] - z), default=None)
		if hit is None or math.hypot(hit[1] - x, hit[2] - z) > 0.05:
			raise SystemExit("cross_track.json: no %s %s at (%.3f, %.3f): write it again (cross_track.py)" % (k.biome, name, x, z))
		obs.remove(hit)
		if nx is None:
			bpy.data.objects.remove(hit[3])
		else:
			put(hit[3], name, nx, nz, yaw)
	for name, x, z, yaw, scale in data["add"]:
		ob = k.place(name, (x, PROP_Y.get(name, GROUND_Y[k.biome]), z), yaw, scale)
		put(ob, name, x, z, yaw)
	print("CROSS_TRACK", k.biome, "fix", len(data["fix"]), "add", len(data["add"]))
