"""Where a draft prop may stand among ALL the tracks' roads, for biome layouts (docs/WORLD2_SPEC.md "Blender first": 24+
studs from the road centre line, every track's road). A quick footprint test while laying out; the exact triangle test
stays clearance.py's. Import-safe (numpy, chain.py; no bpy)."""

import math

import chain
import numpy as np

CLEAR = 25.0  # studs: the 24-stud rule and a margin
PLAZA = (94.0, 110.0)  # SpawnArea.FLOOR_SIZE / 2 at the world origin
PLAZA_CLEAR = 9.0  # BiomeDressing.CLEARANCE (8) and a margin


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
