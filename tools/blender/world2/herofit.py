"""Largest scale at which a hero fits beside the road (owner 2026-11-26, design log fe810a44: a hero with no spot at its
approved scale stands at the largest scale that fits its own ground). Plain numpy, no bpy.

A hero's footprint is its mesh box (w x d at scale 1) turned by `yaw` and scaled by s about its base centre. At a spot,
the largest s that keeps every road centre-line point at least `clear` outside the box (Chebyshev-expanded, a little
conservative at the corners), every checkpoint pad PAD_CLEAR away and the spawn plaza PLAZA_CLEAR away is, in the box's
own frame (u along its width, v along its depth): min over points of max((|u| - c) / (w / 2), (|v| - c) / (d / 2)).
best() searches spots ahead of the run cameras and returns the largest scale found, capped at the approved one.
"""

import math

import numpy as np

import chain
import roads as roadsmod

PAD_CLEAR = 67.0  # roads.Roads.fits: footprint points this far from a checkpoint centre
PLAZA_CLEAR = roadsmod.PLAZA_CLEAR


class Fit:
	def __init__(self, clear=24.5):
		pts = []
		for t in chain.build():
			w = np.array(t["Waypoints"])[:, [0, 2]]
			# densify to <= 6 studs so the sampled centre line cannot pass between points closer than `clear`
			seg = np.diff(w, axis=0)
			n = np.maximum(1, np.ceil(np.hypot(seg[:, 0], seg[:, 1]) / 6).astype(int))
			for a, b, k in zip(w[:-1], w[1:], n):
				pts.append(a + (b - a) * (np.arange(k)[:, None] / k))
			pts.append(w[-1:])
		self.road = np.concatenate(pts)
		r = roadsmod.Roads(1)
		self.pads = r.pads
		hx, hz = roadsmod.PLAZA
		gx, gz = np.meshgrid(np.linspace(-hx, hx, 12), np.linspace(-hz, hz, 12))
		self.plaza = np.stack([gx.ravel(), gz.ravel()], 1)
		self.clear = clear

	def max_scale(self, x, z, yaw, w, d):
		"""Largest s at which the w x d box turned `yaw` (Roblox heading) at (x, z) clears roads, pads and plaza."""
		c, s = math.cos(yaw), math.sin(yaw)
		out = math.inf
		for pts, cl in ((self.road, self.clear), (self.pads, PAD_CLEAR), (self.plaza, PLAZA_CLEAR)):
			dx, dz = pts[:, 0] - x, pts[:, 1] - z
			u = dx * c - dz * s  # the box's width axis (local X) in world: (cos yaw, -sin yaw)
			v = dx * s + dz * c  # its depth axis (local Z): (sin yaw, cos yaw)
			lim = np.maximum((np.abs(u) - cl) / (w / 2), (np.abs(v) - cl) / (d / 2))
			out = min(out, float(lim.min()))
		return out


def best(k, w, d, cap, cams=(0.06, 0.33, 0.62, 0.9), aheads=range(240, 2401, 40), sides=range(-1000, 1001, 40), owns=None, yaw_to_cam=True, base_yaw=None, fit=None):
	"""(scale, x, z, yaw, camera f) of the largest-scale spot ahead of a run camera, within its view (|side| < ahead), on
	own ground (`owns`), the hero turned to face that camera (or `base_yaw` when given); None when nothing fits at 0.3."""
	fit = fit or Fit()
	found = None
	for f in cams:
		p, right, t = k.at(k.length * f)
		ex, ez = p.x + right.x * 10, p.z + right.z * 10
		for ahead in aheads:
			for side in sides:
				if abs(side) >= ahead:
					continue
				x, z = ex + t.x * ahead + right.x * side, ez + t.z * ahead + right.z * side
				if owns and not owns(x, z):
					continue
				yaw = base_yaw if base_yaw is not None else math.atan2(-(ex - x), -(ez - z))
				sc = min(cap, fit.max_scale(x, z, yaw, w, d))
				if sc >= 0.3 and (found is None or sc > found[0] + 1e-6):
					found = (sc, x, z, yaw, f)
	return found
