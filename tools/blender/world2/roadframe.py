"""Road-relative spots for the World 2 drafts (docs/WORLD2_SPEC.md "World 2 track layout", the 2026-11-26 re-fit).

A hand-set spot is stored as (d, off): d studs along this track's centre line from its start, off studs to the right of it
(negative: left). Past either end, d continues along the end straight's direction (a spot behind the finish has d > length).
The same spot then follows the road when the chain is laid out again, instead of staying at a world x, z.
Plain Python (no bpy). Points are Roblox world (x, z); `wps` is a track's centre-line waypoints from chain.build().
"""

import math


def _cum(wps):
	c = [0.0]
	for a, b in zip(wps, wps[1:]):
		c.append(c[-1] + math.hypot(b[0] - a[0], b[-1] - a[-1]))
	return c


def _xz(p):
	return (p[0], p[-1])  # (x, z) of an (x, z) or (x, y, z) point


def frame(wps, d):
	"""(centre x, z), unit tangent (tx, tz) and right (rx, rz) at distance d; past the ends along the end directions."""
	pts = [_xz(p) for p in wps]
	cum = _cum(wps)
	if d <= 0.0:
		i = 0
	elif d >= cum[-1]:
		i = len(pts) - 2
	else:
		lo, hi = 0, len(cum) - 1
		while hi - lo > 1:
			mid = (lo + hi) // 2
			if cum[mid] <= d:
				lo = mid
			else:
				hi = mid
		i = lo
	a, b = pts[i], pts[i + 1]
	seg = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
	tx, tz = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
	u = d - cum[i]
	return (a[0] + tx * u, a[1] + tz * u), (tx, tz), (-tz, tx)


def point(wps, d, off, along=0.0):
	"""World (x, z) of the road-relative spot (d, off): `along` more studs in the road's direction at d (kit.spot)."""
	(cx, cz), (tx, tz), (rx, rz) = frame(wps, d)
	return cx + tx * along + rx * off, cz + tz * along + rz * off


def heading(wps, d):
	"""Roblox heading of the road at d (0 = facing -Z), as kit.beside gives it."""
	_, (tx, tz), _ = frame(wps, d)
	return math.atan2(-tx, -tz)


def locate(wps, x, z):
	"""(d, off, along) of world (x, z): the nearest centre-line point, or the end straights' extensions when that is
	nearer. `along` is 0 but outside a corner vertex, where the nearest point is the vertex itself."""
	pts = [_xz(p) for p in wps]
	cum = _cum(wps)
	best = None
	n = len(pts)
	for i in range(n - 1):
		a, b = pts[i], pts[i + 1]
		seg = math.hypot(b[0] - a[0], b[1] - a[1])
		if seg < 1e-9:
			continue
		tx, tz = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
		u = (x - a[0]) * tx + (z - a[1]) * tz
		if i > 0:
			u = max(u, 0.0)  # only the first segment extends back past the start
		if i < n - 2:
			u = min(u, seg)  # and only the last one past the finish
		px, pz = a[0] + tx * u, a[1] + tz * u
		dist = math.hypot(x - px, z - pz)
		if best is None or dist < best[0] - 1e-9:
			off = (x - px) * -tz + (z - pz) * tx
			best = (dist, cum[i] + u)
	d = best[1]
	# Not on a waypoint: there the segment frame() picks can flip with float noise (kit.Kit's waypoints are float32), so
	# a spot whose nearest point is a vertex is anchored 0.01 studs before it, with off and along in that segment's frame.
	if min(abs(d - c) for c in cum[1:-1] or [math.inf]) < 0.005:
		d -= 0.01
	(cx, cz), (tx, tz), (rx, rz) = frame(wps, d)  # off and along in the frame point() uses at d
	return d, (x - cx) * rx + (z - cz) * rz, (x - cx) * tx + (z - cz) * tz


class Owners:
	"""The owner's ground rule (WORLD2_SPEC "Ground ownership", 2026-11-25, by base centre): a spot belongs to the track
	whose centre line is nearest, measured to its waypoints (at most 12 studs apart), as export_props.owner_at does.
	`tracks`: chain.build() rows. Waypoints are bucketed on a CELL grid and searched ring by ring."""

	CELL = 128.0

	def __init__(self, tracks):
		self.b = {}
		for t in tracks:
			for p in t["Waypoints"]:
				x, z = _xz(p)
				self.b.setdefault((int(x // self.CELL), int(z // self.CELL)), []).append((x, z, t["Number"]))

	def owner(self, x, z):
		return self.nearest(x, z)[1]

	def nearest(self, x, z):
		"""(distance to the nearest centre-line waypoint of any track, that track's number)."""
		cx, cz = int(x // self.CELL), int(z // self.CELL)
		best, who, r = math.inf, None, 0
		while r < 4096:
			for i in range(cx - r, cx + r + 1):
				for j in (range(cz - r, cz + r + 1) if i in (cx - r, cx + r) else (cz - r, cz + r)):
					for px, pz, n in self.b.get((i, j), ()):
						d = (px - x) ** 2 + (pz - z) ** 2
						if d < best:
							best, who = d, n
			if who is not None and (r * self.CELL) ** 2 > best:
				return math.sqrt(best), who
			r += 1
		return math.sqrt(best), who
