"""World 2 Track 8: Monster Den (One Punch). The monsters' underground lair beneath the City Z ghost town, rebuilt 1-1
toward the manga and anime (refs: docs/world2_refs/MonsterDen.md). Everything is underground: a low rock ceiling over
the tunnels, a high rock vault with stalactites over the open caverns, a near-black sky behind.
- the lair itself, a huge underground tower of round stone floors with wide mushroom ledges, arched windows, outside
  stairs, a broken colonnade on top, tentacles and a mine-cart rail ring on a timber base (hero, cavern at 62%);
- the central hall: a round hall of dark grey stone tiers with deep black gaps, tall thin poles, a cracked flagstone
  floor, the spiked throne on a dais (hero, cavern at a third);
- the shrine deep below: a stepped temple with a wide central stair, side balustrades, square niche blocks and capped
  pillar posts on every tier, a relief slab in a rock alcove, over a lava sea (hero, head-on at the finish);
- the gold-vein mines (rail trestles, ore carts, gold and ruby veins), the graveyard of the underground people (ivory
  ring-banded dome helmets among broken flagstones), rock pillars, lava chasms, tilted chunks of the surface city
  (rock masses with embedded buildings, pipes and a pylon), colonnade ruins, flesh-grown cave walls and bone arches.
No symbols or text (design doc 5). Everything in-house, parts only. Proposed look; the owner approves the render set
(design doc 4.46)."""

import math

ROCK, ROCK2, ROCK3 = "2A262E", "3A3540", "1A171E"
WET = {"rough": 0.35}
STONE, STONE2, STONE3, GAP = "5A5650", "4A4642", "6E6A62", "080607"
BONE, BONE2 = "E6DCC4", "C8BC9E"
FLESH, FLESH2, VEIN = "7A3A36", "5E3040", "7A2030"
RUST, RUST2, WOOD = "7A4428", "4E3424", "5E4430"
GOLD, RUBY, LAVA, LAMP = "FFC23A", "E0203A", "FF6A1A", "FFB060"
CEIL_UNDER = 34  # underside of every overhead piece above the road (rule: >= 14)
VAULT = 3.2  # the ceiling prop scaled up over the open caverns: underside 109 above the road

MODEL_SHOTS = ["LairTower", "Coliseum", "Shrine", "Graveyard", "FleshWall"]  # hero models rendered close up by build_track
CLEAR_EXEMPT = {"Ceiling", "BoneArch"}  # span the road with 14+ overhead clearance (CEIL_UNDER, BoneArch docstring)
ROAD_PIECES = ("Wall", "Dash", "Apron", "WinPad", "Road", "Ground")


def _enforce_clearance(k, min_clear=24.5):
	"""Drop every dressing instance whose mesh comes within min_clear of any lap's centre line (the clearance.py
	measure), then recount INSTANCES as the instances still in the scene."""
	import bpy
	import numpy as np

	bpy.context.view_layer.update()  # matrix_world of freshly placed instances is stale until the depsgraph updates
	pts = np.array([(w.x, w.z) for w in k.wps])
	a, ab = pts[:-1], pts[1:] - pts[:-1]
	ab2 = np.maximum((ab * ab).sum(1), 1e-9)
	cache = {}
	for ob in list(k.col.objects):
		if ob.type != "MESH":
			continue
		prop = ob.data.name.split("_", 2)[-1]
		if prop in CLEAR_EXEMPT or prop.startswith(ROAD_PIECES):
			continue
		if ob.data.name not in cache:
			co = np.empty(len(ob.data.vertices) * 3)
			ob.data.vertices.foreach_get("co", co)
			cache[ob.data.name] = co.reshape(-1, 3)
		m = np.array(ob.matrix_world)
		w = cache[ob.data.name] @ m[:3, :3].T + m[:3, 3]
		v = np.stack((w[:, 0], -w[:, 1]), 1)
		c = v.mean(0)
		rad = np.sqrt(((v - c) ** 2).sum(1)).max()
		near = np.sqrt(((a - c) ** 2).sum(1)) < rad + min_clear + np.sqrt(ab2) + 1
		if not near.any():
			continue
		sa, sab, sab2 = a[near], ab[near], ab2[near]
		for i in range(0, len(v), 2048):
			p = v[i : i + 2048][:, None, :]
			t = np.clip(((p - sa) * sab).sum(2) / sab2, 0, 1)
			if np.sqrt(((p - sa - t[..., None] * sab) ** 2).sum(2)).min() < min_clear:
				k.col.objects.unlink(ob)
				break
	k.instances = sum(1 for ob in k.col.objects if ob.name.endswith("_i") or "_i." in ob.name)




def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0, clear=None, where=None):
	"""kit.along, but every prop stands on the cavern floor (y = -1) even where the road climbs a ramp; where(d) picks
	the stretches."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		if where and not where(d):
			d += every
			continue
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], clear or abs(o) * 0.9):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw += (math.pi / 2 if off > 0 else -math.pi / 2)  # turn -Z from along the road to face it, as kit.along
			k.place(k.rng.choice(names), (pos[0], y, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def covered(k, d):
	"""The low ceiling covers the tunnels; five open caverns under the high vault: a chasm, the central hall's cavern
	(a third in), the graveyard cavern (under the side review shot), the lair tower's cavern (62%) and the shrine's lava
	cavern at the finish."""
	f = d / k.length
	return not (0.18 < f < 0.24 or 0.30 < f < 0.40 or 0.44 < f < 0.52 or 0.56 < f < 0.68 or 0.86 < f)


def _arc(parts, r, cy, z, a0, a1, n, thick, col, o=None):
	"""A curved rib in the XY plane: n cylinder segments of a circle (radius r, centre (0, cy)) from a0 to a1 degrees."""
	for i in range(n):
		a = math.radians(a0 + (a1 - a0) * (i + 0.5) / n)
		seg = 2 * r * math.sin(math.radians(abs(a1 - a0) / n) / 2) + thick * 0.6
		parts.append(("cyl", (thick, seg, thick), (r * math.cos(a), cy + r * math.sin(a), z), col, dict({"seg": 8, "rot": (0, 0, math.degrees(a))}, **(o or {}))))


def _ring(parts, r, y, n, size, col, o=None, skip=()):
	"""n boxes around a circle (radius r, height y), each turned tangent to it; skip: indices left out."""
	for i in range(n):
		if i in skip:
			continue
		a = i * math.tau / n
		parts.append(("box", size, (math.cos(a) * r, y, math.sin(a) * r), col, dict({"rot": (0, -math.degrees(a) + 90, 0)}, **(o or {}))))


def _stairs(parts, x, y, z, steps, rise, run, width, ang, col):
	"""A straight flight of steps climbing from (x, y, z) in direction ang (degrees in XZ, 0 = +X)."""
	c, s = math.cos(math.radians(ang)), math.sin(math.radians(ang))
	for i in range(steps):
		parts.append(("box", (run, rise * (i + 1), width), (x + c * run * i, y + rise * (i + 1) / 2, z + s * run * i), col, {"rot": (0, -ang, 0)}))


def _veins(parts, rng, n, x, y, z, spread):
	"""Gold and ruby crystal spikes (the gold-vein mines)."""
	for i in range(n):
		h = rng.uniform(4, 10)
		parts.append(("cone", (h * 0.3, h, h * 0.3), (x + rng.uniform(-spread, spread), y + h / 2, z + rng.uniform(-spread, spread) * 0.4), (GOLD, RUBY)[i % 2], {"emit": 1.6, "seg": 5, "metal": 0.6, "rough": 0.3, "rot": (rng.uniform(-20, 20), 0, rng.uniform(-30, 30))}))


def _ceiling(k, rng):
	"""Wet rock ceiling over the road with ivory rib arches, chains with cage lanterns and stalactites outside the lane.
	Local X across the road; underside CEIL_UNDER above it. Scaled by VAULT it is the high cavern roof."""
	p = [
		("box", (220, 14, 66), (0, CEIL_UNDER + 7, 0), ROCK3, WET),
		("box", (60, 10, 50), (-70, CEIL_UNDER + 1, 6), ROCK, WET),
		("box", (50, 8, 40), (75, CEIL_UNDER + 2, -8), ROCK, WET),
		("ball", (70, 30, 56), (-44, CEIL_UNDER + 15, -6), ROCK, {"subdiv": 1, "rough": 0.4}),
		("ball", (60, 26, 50), (52, CEIL_UNDER + 14, 10), ROCK2, {"subdiv": 1, "rough": 0.4}),
		("ball", (50, 22, 44), (4, CEIL_UNDER + 13, 8), ROCK3, {"subdiv": 1, "rough": 0.4}),
		("ball", (44, 20, 40), (96, CEIL_UNDER + 12, -14), ROCK, {"subdiv": 1, "rough": 0.4}),
		("ball", (44, 20, 40), (-96, CEIL_UNDER + 12, 14), ROCK2, {"subdiv": 1, "rough": 0.4}),
	]
	for x, z, h in ((-34, -12, 22), (-48, 14, 30), (36, 10, 26), (54, -18, 34), (-90, -20, 40), (96, 18, 36), (-30, 22, 14), (31, -24, 16), (-70, 26, 28), (72, -26, 30)):
		p.append(("cone", (6 + h / 4, h, 6 + h / 4), (x, CEIL_UNDER - h / 2 + 1, z), ROCK2, {"rot": (180, 0, 0), "seg": 6, "rough": 0.35}))
	for z in (-20, 20):  # ivory rib arches: 28 over the lane edge, 34 at the crown
		_arc(p, 50, -16, z, 22, 158, 9, 3.4, BONE, {"rough": 0.5})
		_arc(p, 50, -16, z + 3, 30, 150, 7, 1.6, BONE2)
	for x, z in ((-30, -8), (30, 8), (-36, 18), (34, -16)):  # chains with cage lanterns, outside the lane
		p.append(("cyl", (0.5, 14, 0.5), (x, CEIL_UNDER - 7, z), "3A3438", {"seg": 4, "metal": 0.6}))
		p.append(("box", (2.4, 3, 2.4), (x, CEIL_UNDER - 15, z), "2A2428", {"metal": 0.5}))
		p.append(("box", (1.6, 2.2, 1.6), (x, CEIL_UNDER - 15, z), LAMP, {"emit": 1.2}))
	return k.prop("Ceiling", p)


def _seg(parts, a, b, ra, rb, col, o=None):
	"""A tapered round segment from Roblox point a (radius ra) to b (radius rb): a cone turned onto the a-b line."""
	d = [b[i] - a[i] for i in range(3)]
	ln = math.sqrt(sum(v * v for v in d)) or 1e-6
	bx, by, bz = d[0] / ln, -d[2] / ln, d[1] / ln  # Blender axes
	rx = math.degrees(math.acos(max(-1.0, min(1.0, bz))))
	ry = math.degrees(math.atan2(bx, -by)) if abs(bz) < 0.9999 else 0.0
	mid = tuple((a[i] + b[i]) / 2 for i in range(3))
	opts = {"seg": 10, "taper": rb / ra, "smooth": True, "rough": 0.35, "rot": (rx, ry, 0)}
	opts.update(o or {})
	parts.append(("cone", (2 * ra, ln * 1.06, 2 * ra), mid, col, opts))


def _limb(parts, x0, y0, z0, out, n, r0, r1, length, curl, col=FLESH2, rise=20.0, joints=True):
	"""A thick smooth tentacle or horn: n tapered segments from (x0, y0, z0) heading along the horizontal direction out
	(dx, dz), rising and then curling over at the tip (curl: total bend in degrees)."""
	ux, uz = out
	pts, rads = [(x0, y0, z0)], [r0]
	th = math.radians(rise)
	step = length / n
	for i in range(n):
		t = (i + 1) / n
		th += math.radians(curl) * (2 * t / n) * 1.0
		x, y, z = pts[-1]
		st = step * (1 - 0.45 * t)
		pts.append((x + ux * math.cos(th) * st, y + math.sin(th) * st, z + uz * math.cos(th) * st))
		rads.append(r0 + (r1 - r0) * t)
	for i in range(n):
		_seg(parts, pts[i], pts[i + 1], rads[i], rads[i + 1], col)
		if joints and 0 < i:
			parts.append(("ball", (rads[i] * 2, rads[i] * 2, rads[i] * 2), pts[i], col, {"subdiv": 1, "smooth": True, "rough": 0.35}))
	return pts


def _flesh_wall(k, rng):
	"""Organic lair wall (ref Monster_Association_HQ_Volume_23): a wet rock mass with a monster maw torn into it (dark
	throat, swollen flesh gums, two rows of ivory fangs), a glaring eye above, two thick tentacles curling out, flesh
	growths and veins."""
	p = [
		("ball", (70, 56, 34), (0, 24, 8), ROCK, {"subdiv": 2, "rough": 0.35}),
		("ball", (46, 40, 30), (-22, 40, 10), ROCK3, {"subdiv": 2, "rough": 0.4}),
		("ball", (40, 36, 28), (22, 42, 10), ROCK2, {"subdiv": 2, "rough": 0.4}),
		("ball", (30, 24, 24), (-4, 56, 12), ROCK, {"subdiv": 1, "rough": 0.4}),
		("ball", (80, 14, 30), (0, 2, -4), ROCK2, {"subdiv": 1, "rough": 0.4}),
		("ball", (34, 24, 8), (-2, 25, -8), FLESH, {"subdiv": 2, "smooth": True, "rough": 0.35}),
		("ball", (27, 15, 6), (-2, 25, -10), "0A0404", {"subdiv": 2, "smooth": True}),
		("ball", (12, 5, 4), (-2, 20, -10.6), "A0404A", {"subdiv": 1, "smooth": True}),
	]
	for i in range(9):  # fangs: upper row pointing down, lower row pointing up, longest at the corners
		x = -15 + i * 3.6
		ln = 7 - abs(i - 4) * 0.6
		p.append(("cone", (2.6, ln, 2.6), (x, 31 - ln / 2 + 1.5, -12), BONE, {"seg": 6, "rot": (180, 0, 0)}))
		p.append(("cone", (2.2, ln * 0.8, 2.2), (x + 1.8, 19 + ln * 0.4 - 1.5, -12), BONE, {"seg": 6}))
	_limb(p, 24, 8, -6, (0.8, -0.6), 10, 4.2, 0.6, 46, 260)
	_limb(p, -26, 12, -6, (-0.8, -0.6), 10, 3.8, 0.6, 42, 280)
	for x, y, s in ((24, 38, 10), (-28, 36, 9), (12, 9, 8), (-14, 8, 7)):
		p.append(("ball", (s, s * 0.8, s * 0.6), (x, y, -7), FLESH, {"subdiv": 1, "smooth": True, "rough": 0.4}))
	for i in range(6):  # veins over the rock
		p.append(("cyl", (0.9, rng.uniform(10, 18), 0.9), (rng.uniform(-28, 28), rng.uniform(10, 42), -7.6), VEIN, {"seg": 5, "rot": (0, 0, rng.uniform(-60, 60))}))
	p.append(("ball", (9, 8, 5), (6, 42, -9), FLESH, {"subdiv": 1, "smooth": True}))
	p.append(("ball", (7, 6.5, 4), (6, 42, -10.5), "E0D8C8", {"subdiv": 2, "smooth": True}))
	p.append(("ball", (3, 3, 2), (6, 42, -12.3), "1A0A0A", {"subdiv": 1}))
	p.append(("ball", (1.2, 1.2, 1), (6, 42, -13.2), RUBY, {"subdiv": 1, "emit": 3}))
	return k.prop("FleshWall", p)


def _arch(parts, x0, y0, z, rad, col, thick=2.2):
	"""A round arch in the XY plane facing -Z: 7 voussoir blocks on a half circle centred (x0, y0)."""
	for i in range(7):
		a = math.radians(180 * (i + 0.5) / 7)
		parts.append(("box", (rad * 0.48, thick, 2.4), (x0 + math.cos(a) * rad, y0 + math.sin(a) * rad, z), col, {"rot": (0, 0, math.degrees(a) + 90)}))


def _tower(k, rng):
	"""Hero: the lair as an underground tower (ref Monster_Association_HQ_Volume_23): grey round stone floors with
	ledges on corbels, arched windows, outside staircases climbing floor to floor, arched cut-away openings with a
	middle column on the middle floors, a broken arcade on top, thick curling tentacles out of the walls, a horned
	one-eyed monster head with long jagged teeth bursting out at its foot, and a timber trestle ring carrying a
	mine-cart rail with ore carts around the base."""
	S1, S2, S3, SU = "7E8084", "8A8C90", "A4A6AA", "5E6064"
	p = [("cyl", (190, 0.6, 190), (0, 0.3, 0), LAVA, {"emit": 3, "seg": 24}), ("cyl", (130, 8, 130), (0, 4, 0), WOOD, {"seg": 24})]
	for i in range(16):  # drum planks
		a = i * math.tau / 16
		p.append(("box", (3, 8, 1), (math.cos(a) * 65.5, 4, math.sin(a) * 65.5), "3A2A1E", {"rot": (0, -math.degrees(a) + 90, 0)}))
	# timber trestle ring outside the drum: posts, X braces, a deck of ties and two rails
	R, TOP = 74, 13
	for i in range(28):
		a = i * math.tau / 28
		for rr in (R - 4, R + 4):
			p.append(("box", (1.6, TOP, 1.6), (math.cos(a) * rr, TOP / 2, math.sin(a) * rr), WOOD))
		a2 = (i + 0.5) * math.tau / 28
		p.append(("box", (16.5, 1.0, 0.8), (math.cos(a2) * (R + 4), TOP * 0.5, math.sin(a2) * (R + 4)), "4E3826", {"rot": (0, -math.degrees(a2) + 90, 38 if i % 2 else -38)}))
	_ring(p, R, TOP + 0.4, 56, (1.3, 0.8, 11), "3A2A1E")
	_ring(p, R - 2.6, TOP + 1.2, 56, (8.6, 0.7, 0.6), "9A9694", {"metal": 0.7})
	_ring(p, R + 2.6, TOP + 1.2, 56, (8.6, 0.7, 0.6), "9A9694", {"metal": 0.7})
	for i, a in enumerate((math.radians(-100), math.radians(-30), math.radians(160))):  # ore carts on the ring
		x, z, yaw = math.cos(a) * R, math.sin(a) * R, -math.degrees(a) + 90
		p += [
			("box", (9, 5, 6), (x, TOP + 4.4, z), RUST2, {"metal": 0.5, "rot": (0, yaw, 0)}),
			("box", (9.6, 0.7, 6.6), (x, TOP + 7, z), RUST, {"metal": 0.5, "rot": (0, yaw, 0)}),
			("ball", (7, 3.6, 4.6), (x, TOP + 7.3, z), GOLD if i != 1 else "B8A47A", {"subdiv": 1, "metal": 0.6, "rough": 0.4, "emit": 0.5 if i != 1 else 0}),
		]
		for dt in (-3, 3):
			p.append(("cyl", (2.4, 1, 2.4), (x + math.cos(math.radians(-yaw)) * dt, TOP + 2.2, z + math.sin(math.radians(-yaw)) * dt), "2A2628", {"seg": 8, "rot": (90, yaw, 0)}))
	levels = ((44, 28), (40, 26), (38, 24), (34, 22), (38, 18))
	y = 8
	stair_at = (-140, -40, -150, -30, -120)
	for j, (r, h) in enumerate(levels):
		p.append(("cyl", (r * 2, h, r * 2), (0, y + h / 2, 0), (S1, S2)[j % 2], {"seg": 20}))
		p.append(("cyl", (r * 2 + 16, 3, r * 2 + 16), (0, y + h + 1.5, 0), S3, {"seg": 20}))
		p.append(("cone", (r * 2 + 16, 5, r * 2 + 16), (0, y + h - 2.5, 0), SU, {"seg": 20, "taper": 0.85}))
		for i in range(12):  # stone corbels under the floor slab
			a = (i + 0.25) * math.tau / 12
			p.append(("box", (3, 5, 6), (math.cos(a) * (r + 3), y + h - 3, math.sin(a) * (r + 3)), SU, {"rot": (0, -math.degrees(a), 0)}))
		cut = j in (1, 2)
		for i in range(8):
			a = (i + 0.5 * (j % 2)) * math.tau / 8
			if cut and abs(math.degrees(a) - 270) < 30:
				continue  # the cut-away opening is here
			ox, oz = math.cos(a) * (r + 0.2), math.sin(a) * (r + 0.2)
			lit = (i + j) % 3 == 0
			p.append(("box", (1, h * 0.5, 6.5), (ox, y + h * 0.4, oz), LAMP if lit else "100C10", {"rot": (0, -math.degrees(a), 0), "emit": 2.5 if lit else 0}))
			p.append(("cyl", (6.5, 1, 6.5), (ox, y + h * 0.65, oz), LAMP if lit else "100C10", {"seg": 8, "rot": (0, -math.degrees(a), 90), "emit": 2.5 if lit else 0}))
		if cut:  # arched cut-away opening on the front: dark room, middle column, two round arches, lit lamp inside
			z = -r - 0.3
			oh = h * 0.72
			p.append(("box", (28, oh, 1.6), (0, y + 1 + oh / 2, z + 0.6), "120E12"))
			p.append(("box", (30, 1.4, 4), (0, y + 1, z - 1), S3))
			for x in (-13.5, 0, 13.5):
				p.append(("cyl", (2.6, oh - 7, 2.6), (x, y + 1 + (oh - 7) / 2, z - 1.4), "B0B2B4", {"seg": 8}))
				p.append(("box", (3.6, 1.2, 3.6), (x, y + oh - 5.4, z - 1.4), S3))
			for x0 in (-6.75, 6.75):
				_arch(p, x0, y + oh - 5, z - 1.4, 6.4, S3)
			p.append(("box", (2, 2.4, 1), (-7, y + oh * 0.5, z + 0.2), LAMP, {"emit": 3}))
		# outside staircase climbing from this floor's ledge to the next, along the wall, with a parapet
		if j < len(levels) - 1:
			ad = stair_at[j]
			a = math.radians(ad)
			steps, rise = 9, (h + 3) / 9
			sx, sz = math.cos(a) * (r + 5), math.sin(a) * (r + 5)
			_stairs(p, sx, y, sz, steps, rise, 3.0, 7, ad + 90, S3)
			c, s_ = math.cos(math.radians(ad + 90)), math.sin(math.radians(ad + 90))
			ln = math.hypot(steps * 3.0, h + 3)
			p.append(("box", (ln, 1.4, 0.8), (sx + c * 13.5 + math.cos(a) * 3.8, y + (h + 3) / 2 + 2, sz + s_ * 13.5 + math.sin(a) * 3.8), S1, {"rot": (0, -(ad + 90), math.degrees(math.atan2(h + 3, steps * 3.0)))}))
		y += h + 3
	for i in range(8):
		if i in (2, 5):
			continue
		a = i * math.tau / 8
		x, z = math.cos(a) * 36, math.sin(a) * 36
		hh = 22 if i % 3 else 14
		p.append(("cyl", (3.6, hh, 3.6), (x, y + hh / 2, z), "B0B2B4", {"seg": 10}))
		p.append(("box", (6, 2.4, 6), (x, y + hh + 1.2, z), S3))
		p.append(("box", (6, 2, 6), (x, y + 1, z), S2))
	p.append(("box", (40, 3, 28), (8, y + 1.5, -6), S2, {"rot": (0, 15, 0)}))
	# front arcade on the top floor (Vol 23): columns with bases and capitals, round arches, a broken slab roof
	for x in (-22, 0, 22):
		p.append(("box", (5, 2, 5), (x, y + 1, -28), S2))
		p.append(("cyl", (3.4, 17, 3.4), (x, y + 10.5, -28), "B0B2B4", {"seg": 10}))
		p.append(("box", (5, 2, 5), (x, y + 20, -28), S3))
	for x0 in (-11, 11):
		_arch(p, x0, y + 21, -28, 9, S3, 2.6)
	p.append(("box", (30, 3, 14), (-10, y + 32, -26), S3, {"rot": (0, 0, 3)}))
	p.append(("box", (16, 3, 12), (16, y + 30, -27), S3, {"rot": (8, 0, -12)}))
	_stairs(p, 14, y + 31, -30, 6, 2.6, 2.6, 7, 90, S3)
	# thick tentacles curling out of the walls (right side, as in Vol 23)
	for (x0, y0, z0, ox, oz, ln, curl) in ((38, 70, -14, 0.9, -0.4, 60, 300), (40, 52, 10, 1.0, 0.2, 52, 260), (34, 96, 6, 0.9, -0.1, 46, 320), (-40, 40, -12, -1.0, -0.3, 44, 280)):
		_limb(p, x0, y0, z0, (ox, oz), 10, 5.5, 0.7, ln, curl)
	# the monster head bursting out at the foot (right front): one big round eye, curved horns, long jagged teeth
	hx, hz = 50, -40
	p += [
		("ball", (36, 28, 32), (hx, 30, hz), "1E1A20", {"subdiv": 2, "smooth": True}),
		("ball", (30, 12, 24), (hx + 1, 15, hz - 6), "1E1A20", {"subdiv": 2, "smooth": True}),
		("ball", (26, 9, 8), (hx, 22, hz - 13), "2A0608", {"subdiv": 1, "smooth": True}),
		("ball", (13, 13, 7), (hx - 4, 38, hz - 13), "ECE6D6", {"subdiv": 2, "smooth": True}),
		("ball", (5.6, 5.6, 3), (hx - 4, 38, hz - 16.4), "100808", {"subdiv": 1, "smooth": True}),
		("ball", (16, 4, 7), (hx - 4, 45, hz - 11), "1E1A20", {"subdiv": 1, "smooth": True}),
	]
	for i in range(9):  # long jagged teeth, upper row hanging down, lower row up, uneven lengths and tilts
		ln = rng.uniform(8, 13)
		p.append(("cone", (2.6, ln, 2.6), (hx - 11 + i * 2.8, 26 - ln / 2 + 1, hz - 15), BONE, {"seg": 5, "rot": (180 + rng.uniform(-12, 12), 0, rng.uniform(-14, 14))}))
		if i < 8:
			ln2 = rng.uniform(6, 10)
			p.append(("cone", (2.4, ln2, 2.4), (hx - 9.6 + i * 2.8, 18 + ln2 / 2 - 1, hz - 15), BONE, {"seg": 5, "rot": (rng.uniform(-12, 12), 0, rng.uniform(-14, 14))}))
	for side in (-1, 1):  # curved horns sweeping up and back
		_limb(p, hx + side * 10, 44, hz + 2, (side * 0.7, 0.7), 7, 3.2, 0.4, 34, 120, col="2A2428", rise=55, joints=False)
	return k.prop("LairTower", p)


def _coliseum(k, rng):
	"""Hero: the central hall (refs Monster_Association_Headquarters_Anime_Profile, The_Monster_Association): a round
	hall of dark grey stone tiers over deep black gaps, tall thin poles, a cracked flagstone floor and the spiked throne
	on a dais; open toward -Z so the tiers show from the road."""
	n, r, tiers = 32, 100, 13
	gap = (22, 23, 24, 25, 26)
	p = [("cyl", (2 * r + 4, 1, 2 * r + 4), (0, 0.5, 0), "6A665E", {"seg": 32})]
	seg = 2 * math.pi * r / n + 1
	_ring(p, r + 4, 56, n, (seg, 112, 4), "030202", skip=gap)
	_ring(p, r + 6.5, 56, n, (seg + 0.6, 112, 1.2), "6E6A62", skip=gap)  # grey stone outer face of the hall
	for t in range(tiers):
		rt = r - 3 - t * 0.6
		_ring(p, rt, 5 + t * 8, n, (seg * 0.98, 4, 7), ("BEBAB2", "ACA8A0")[t % 2], skip=gap)
		for i in range(n):  # the crowd: a dark monster silhouette on every tier segment
			if i in gap:
				continue
			a = (i + 0.5 * (t % 2)) * math.tau / n
			sz = rng.uniform(3.6, 4.8)
			p.append(("cone", (sz, sz * 1.6, sz), (math.cos(a) * (rt - 1), 7 + t * 8 + sz * 0.8, math.sin(a) * (rt - 1)), ("1E1A1C", "2A2426", "151214")[i % 3], {"seg": 5, "taper": 0.45}))
	_ring(p, r + 9, 52, 16, (6, 104, 8), ROCK2, skip=(11, 12, 13))
	for i in range(10):
		a = i * math.tau / 10 + 0.2
		p.append(("cyl", (1.4, 120, 1.4), (math.cos(a) * (r - 14), 60, math.sin(a) * (r - 14)), "1E1A1C", {"seg": 6, "metal": 0.5}))
	for i in range(30):  # cracks across the flagstones
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(5, r - 20)
		p.append(("box", (rng.uniform(8, 20), 0.1, 0.8), (math.cos(a) * rr, 1.06, math.sin(a) * rr), "0A0908", {"rot": (0, rng.uniform(0, 180), 0)}))
	for i in range(7):  # flagstone joints, pale on the dark floor
		o = -75 + i * 25
		p.append(("box", (170, 0.08, 0.7), (0, 1.04, o), "2A2622"))
		p.append(("box", (0.7, 0.08, 170), (o + (12 if i % 2 else 0), 1.04, 0), "2A2622"))
	p += [
		("box", (46, 5, 30), (0, 3.5, 62), STONE2),
		("box", (34, 5, 22), (0, 8.5, 64), STONE),
		("box", (22, 5, 14), (0, 13.5, 66), STONE2),
		("box", (12, 6, 8), (0, 19, 67), "4A1418"),
		("box", (14, 26, 4), (0, 29, 71), "2A0E10"),
	]
	for x, h in ((-6, 18), (-3, 24), (0, 30), (3, 24), (6, 18), (-9, 12), (9, 12)):
		p.append(("cone", (3, h, 3), (x, 42 + h / 2 - 4, 71), BONE, {"seg": 5}))
	for x in (-8, 8):
		p.append(("cone", (3, 10, 3), (x, 23, 64), BONE, {"seg": 5, "rot": (-30, 0, 0)}))
	return k.prop("Coliseum", p)


def _shrine(k, rng):
	"""Hero: the shrine deep below (ref The_Mysterious_Shrine_Manga): a stepped stone temple with a wide central stair
	and side balustrades, square niche blocks and capped pillar posts on every tier, a blank relief slab at the top, in
	a rock alcove over a lava sea. Front (-Z) faces the runner."""
	p = [("cyl", (270, 2, 270), (0, 1, 0), LAVA, {"emit": 2.5, "seg": 32})]
	for i in range(12):
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(100, 128)
		p.append(("box", (rng.uniform(10, 24), 1.2, rng.uniform(8, 18)), (math.cos(a) * rr, 2.2, math.sin(a) * rr), "2A120C", {"rot": (0, rng.uniform(0, 180), 0)}))
	tiers = 6
	for j in range(tiers):
		w, d, h = 170 - j * 24, 130 - j * 18, 14
		yb = 2 + j * h
		p.append(("box", (w, h, d), (0, yb + h / 2, 0), (STONE2, STONE)[j % 2]))
		p.append(("box", (w + 2, 1.4, d + 2), (0, yb + h - 0.7, 0), STONE3))
		zf = -d / 2 - 0.4
		for side in (-1, 1):
			for xx in (0.3, 0.62, 0.9):
				x = side * (24 + (w / 2 - 30) * xx)
				p.append(("box", (6, 6, 0.8), (x, yb + h / 2, zf), STONE3))
				p.append(("box", (3.4, 3.4, 0.9), (x, yb + h / 2 - 0.4, zf - 0.1), "1A1816"))
			x = side * (w / 2 - 5)
			p.append(("box", (8, h + 12, 8), (x, yb + h / 2 + 6, -d / 2 + 5), STONE))
			p.append(("box", (10, 1.6, 10), (x, yb + h + 12.8, -d / 2 + 5), STONE2))
			p.append(("box", (13, 6, 13), (x, yb + h + 16.6, -d / 2 + 5), STONE3))
	top = 2 + tiers * 14
	steps = 28
	z0, z1 = -100, -20
	for i in range(steps):
		t = (i + 1) / steps
		p.append(("box", (40, top * t, (z1 - z0) / steps + 0.2), (0, top * t / 2, z0 + (z1 - z0) * (i + 0.5) / steps), STONE3 if i % 2 else "7A746A"))
	slope = math.degrees(math.atan2(top, z1 - z0))
	ln = math.hypot(top, z1 - z0)
	for side in (-1, 1):
		p.append(("box", (5, 12, ln), (side * 21.5, top / 2 - 1, (z0 + z1) / 2), STONE, {"rot": (-slope, 0, 0)}))
		for j in range(tiers):  # capped posts stepping down beside the stair, one per tier
			zf = -(130 - j * 18) / 2 + 2
			yb = 2 + j * 14
			p.append(("box", (7, 24, 7), (side * 28, yb + 12, zf), STONE))
			p.append(("box", (11, 5, 11), (side * 28, yb + 26.5, zf), STONE3))
	p.append(("box", (40, 3, 40), (0, top + 1.5, z1 + 20), STONE3))
	p.append(("box", (50, 40, 4), (0, top + 20, 30), "8A847A"))
	# the relief (in-house): a dark many-legged creature carved over a scatter of small figures, as in the manga
	rel = "3A3632"
	p.append(("ball", (20, 9, 2), (0, top + 28, 27.6), rel, {"subdiv": 1, "smooth": True}))
	p.append(("ball", (8, 7, 2), (-12, top + 30, 27.5), rel, {"subdiv": 1, "smooth": True}))
	for i, (x, ang) in enumerate(((-8, 30), (-3, 15), (2, -10), (7, -25), (10, -40), (-11, 55))):
		p.append(("box", (1.2, 10, 1.2), (x, top + 22, 27.5), rel, {"rot": (0, 0, ang)}))
	for i in range(14):
		p.append(("box", (1.4, rng.uniform(2.5, 4), 1), (rng.uniform(-20, 20), top + rng.uniform(4, 14), 27.6), "5A5650", {"rot": (0, 0, rng.uniform(-30, 30))}))
	for side in (-1, 1):
		p.append(("cone", (70, 170, 60), (side * 115, 85, 30), ROCK, {"seg": 6, "taper": 0.3}))
		p.append(("cone", (50, 120, 50), (side * 75, 60, 70), ROCK2, {"seg": 6, "taper": 0.3}))
	for i in range(7):
		a = math.radians(15 + i * 25)
		p.append(("box", (50, 20, 70), (math.cos(a) * 120, 110 + math.sin(a) * 70, 40), (ROCK3, ROCK)[i % 2], {"rot": (0, 0, math.degrees(a) - 90)}))
	for x in (-60, 60):
		p.append(("cyl", (6, 6, 6), (x, 19, -62), STONE2, {"seg": 8}))
		p.append(("cone", (5, 6, 5), (x, 25, -62), LAVA, {"emit": 8, "seg": 6}))
	return k.prop("Shrine", p)


def _mine_rail(k, rng):
	"""Gold-vein mine rail: a timber trestle with ties and rails, an ore cart loaded with gold and a sack, a lantern
	post, gold and ruby veins at its foot. Runs along the road (local X)."""
	L = 48
	p = []
	for i in range(7):
		x = -L / 2 + i * L / 6
		for z in (-3, 3):
			p.append(("box", (1.2, 9, 1.2), (x, 4.5, z), WOOD))
		p.append(("box", (1.2, 1.2, 7.6), (x, 8.6, 0), "4E3826"))
		if i < 6:
			p.append(("box", (0.6, 11, 0.6), (x + L / 12, 4.5, -3), "4E3826", {"rot": (0, 0, 48)}))
	for z in (-3, 3):
		p.append(("box", (L, 1.2, 1.2), (0, 8.6, z), WOOD))
	for i in range(16):
		p.append(("box", (1.2, 0.6, 8), (-L / 2 + 1.5 + i * 3, 9.5, 0), "2E221A"))
	for z in (-2, 2):
		p.append(("box", (L, 0.6, 0.5), (0, 10.1, z), "8E8A88", {"metal": 0.7, "rough": 0.4}))
	p += [
		("box", (8, 4.5, 5.6), (6, 13.2, 0), RUST2, {"metal": 0.5}),
		("box", (8.6, 0.6, 6.2), (6, 15.6, 0), RUST, {"metal": 0.5}),
		("ball", (6.4, 3.6, 4.4), (6, 15.8, 0), GOLD, {"subdiv": 1, "metal": 0.8, "rough": 0.3, "emit": 0.6}),
		("ball", (3, 4, 3), (-8, 12.4, 0), "B8A47A", {"subdiv": 1, "smooth": True}),
		("cyl", (1.4, 1, 1.4), (-8, 14.6, 0), "7A6440", {"seg": 6}),
	]
	for dx in (-2.8, 2.8):
		for dz in (-2.2, 2.2):
			p.append(("cyl", (2, 0.8, 2), (6 + dx, 11, dz), "2A2628", {"seg": 8, "rot": (90, 0, 0)}))
	p.append(("box", (0.8, 18, 0.8), (-20, 9, -4.5), WOOD))
	p.append(("box", (0.6, 0.6, 3), (-20, 17.6, -5.5), WOOD))
	p.append(("box", (1.6, 2, 1.6), (-20, 16, -6.5), LAMP, {"emit": 5}))
	p.append(("cone", (12, 6, 8), (16, 3, 1), ROCK2, {"seg": 6}))
	_veins(p, rng, 6, 16, 3, 1, 5)
	return k.prop("MineRail", p)


def _turn(v, rot):
	"""Roblox local offset v turned by a kit rot (x, y, z degrees), in Roblox axes, as kit.prop turns parts."""
	from mathutils import Matrix, Vector

	rx, ry, rz = rot
	m = Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(-rz), 3, "Y")
	b = m @ Vector((v[0], -v[2], v[1]))
	return (b.x, b.z, -b.y)


def _graveyard(k, rng):
	"""Graveyard of the underground people (ref Subterranean_graveyard): three heaps of ivory round dome helmets, each
	with two dark ring bands around it and a black round face opening, piled among pale broken flagstone slabs, rock
	shards and bones."""
	p = [("cyl", (54, 0.4, 30), (0, 0.2, 0), "3A3632", {"seg": 16})]
	for i in range(16):  # broken pale flagstone slabs, some tipped up
		s = rng.uniform(4, 9)
		p.append(("box", (s, rng.uniform(1, 2.2), s * 0.8), (rng.uniform(-24, 24), 0.6, rng.uniform(-12, 12)), ("A8A296", "8A847A", "B8B2A6")[i % 3], {"rot": (rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25))}))
	for i in range(6):
		p.append(("cone", (rng.uniform(3, 5), rng.uniform(4, 8), rng.uniform(3, 5)), (rng.uniform(-22, 22), 2, rng.uniform(-10, 10)), "8A847A", {"seg": 4, "rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	for hx, hz, n in ((-12, 2, 9), (10, -2, 10), (0, 9, 6)):
		for i in range(n):
			ring, a = (0, 0) if i == 0 else ((1, (i - 1) * math.tau / 5) if i < 6 else (2, (i - 6) * math.tau / 4 + 0.4))
			rr = (0, 5.5, 8.5)[ring]
			y = (9.0, 4.6, 2.6)[ring]
			x, z = hx + math.cos(a) * rr, hz + math.sin(a) * rr * 0.8
			yaw = rng.uniform(-50, 50)  # faces turned toward the front (-Z), as the heap in the ref stares out
			rot = (rng.uniform(5, 35), yaw, rng.uniform(-15, 15))  # face tipped up toward the viewer
			p.append(("ball", (6.4, 6.2, 6.4), (x, y, z), "E8E0CC", {"subdiv": 2, "smooth": True, "rot": rot}))
			for dy, rad in ((1.1, 6.6), (-0.9, 6.7)):  # the two ring bands, turned with the helmet
				bx, by, bz = _turn((0, dy, 0), rot)
				p.append(("cyl", (rad, 0.6, rad), (x + bx, y + by, z + bz), "2A2622", {"seg": 12, "rot": rot}))
	for i in range(8):
		p.append(("cyl", (0.8, rng.uniform(4, 7), 0.8), (rng.uniform(-22, 22), 0.8, rng.uniform(-10, 10)), BONE, {"seg": 6, "rot": (rng.uniform(80, 100), rng.uniform(0, 180), 0)}))
	return k.prop("Graveyard", p)


def _colonnade(k, rng):
	"""Ruin of the underground people's colonnade: two columns with bases and capitals under a broken lintel, a stump
	and a fallen drum."""
	p = []
	for x, h in ((-9, 26), (9, 26), (24, 9)):
		p.append(("box", (7, 2.4, 7), (x, 1.2, 0), STONE2))
		p.append(("cyl", (4.6, h, 4.6), (x, 2.4 + h / 2, 0), STONE, {"seg": 10}))
		for t in range(1, int(h / 6) + 1):
			p.append(("cyl", (4.9, 0.4, 4.9), (x, 2.4 + t * 6, 0), STONE2, {"seg": 10}))
		if h > 20:
			p.append(("box", (7, 2.6, 7), (x, 2.4 + h + 1.3, 0), STONE3))
	p.append(("box", (26, 4, 6), (0, 33, 0), STONE3))
	p.append(("box", (10, 4, 6), (14, 30, 0), STONE3, {"rot": (0, 0, -30)}))
	p.append(("cyl", (4.6, 8, 4.6), (2, 2.3, -9), STONE, {"seg": 10, "rot": (0, 30, 90)}))
	for i in range(5):
		s = rng.uniform(2, 4)
		p.append(("box", (s, s, s), (rng.uniform(-14, 26), s / 2, rng.uniform(-8, 6)), STONE2, {"rot": (rng.uniform(0, 40), rng.uniform(0, 90), 0)}))
	return k.prop("Colonnade", p)


def _city_chunk(k, rng):
	"""A chunk of the surface city sunk into the cavern (ref Tatsumaki_lifts_...): a rock mass with two tilted buildings
	embedded in it (window bands, a broken roof), pipes sticking out with flanges, a tilted lattice pylon, rebar."""
	p = [
		("cone", (70, 40, 50), (0, 14, 6), ROCK, {"seg": 7, "taper": 0.4, "rough": 0.35}),
		("cone", (44, 30, 36), (-26, 10, -6), ROCK2, {"seg": 6, "taper": 0.3}),
		("cone", (40, 26, 30), (28, 9, -4), ROCK3, {"seg": 6, "taper": 0.3}),
	]
	for bx, by, w, h, rot, col in ((-12, 26, 18, 34, (12, 10, 18), "7A746A"), (14, 22, 14, 26, (-10, -20, -24), "8A8070")):
		p.append(("box", (w, h, 14), (bx, by, 0), col, {"rot": rot}))
		cols = int(w / 4.5)
		for f in range(int(h / 7)):  # window grid on the front face, some panes lit
			for c in range(cols):
				ox, oy = -w / 2 + (c + 0.5) * w / cols, -h / 2 + 4 + f * 7
				dx, dy, dz = _turn((ox, oy, -7.1), rot)
				lit = rng.random() < 0.15
				p.append(("box", (w / cols - 1.4, 3.2, 0.5), (bx + dx, by + dy, dz), LAMP if lit else "1E2228", {"rot": rot, "emit": 1.5 if lit else 0}))
		p.append(("box", (w + 1, 1.2, 15), (bx, by + h / 2, 0), "5E5850", {"rot": rot}))
	for x, y, z, rz, ry in ((-2, 30, -6, 70, 20), (20, 18, -8, -60, -30), (-30, 16, -10, 85, 40)):
		p.append(("cyl", (2.6, 22, 2.6), (x, y, z), RUST, {"seg": 8, "metal": 0.5, "rot": (0, ry, rz)}))
		p.append(("cyl", (3.4, 0.8, 3.4), (x, y, z), RUST2, {"seg": 8, "metal": 0.5, "rot": (0, ry, rz)}))
	rrot = (14, -8, 10)  # a torn-up slab of surface road leaning on the rock, lane dashes and a lamp post
	p.append(("box", (44, 2, 16), (2, 34, -14), "4A4844", {"rot": rrot}))
	for i in range(4):
		dx, dy, dz = _turn((-15 + i * 10, 1.1, 0), rrot)
		p.append(("box", (5, 0.3, 0.8), (2 + dx, 34 + dy, -14 + dz), "D8D2C0", {"rot": rrot}))
	dx, dy, dz = _turn((16, 8, -6), rrot)
	p.append(("cyl", (0.8, 14, 0.8), (2 + dx, 34 + dy, -14 + dz), "6E7276", {"seg": 6, "rot": rrot}))
	dx, dy, dz = _turn((16, 15.5, -7.5), rrot)
	p.append(("box", (1.6, 0.8, 3), (2 + dx, 34 + dy, -14 + dz), "FFE8C0", {"rot": rrot, "emit": 2}))
	px, py, tilt = 30, 22, (0, 0, -18)  # lattice pylon: four legs, braces, cross-arms
	for dx in (-2.5, 2.5):
		for dz in (-2.5, 2.5):
			p.append(("box", (0.7, 40, 0.7), (px + dx + 3, py + 4, dz), "5A5654", {"rot": tilt, "metal": 0.5}))
	for i in range(5):
		yy = py - 12 + i * 8
		p.append(("box", (6, 0.5, 0.5), (px + 3 + (yy - py) * 0.32, yy, -2.5), "5A5654", {"rot": (0, 0, -18 + (35 if i % 2 else -35))}))
	for yy, wd in ((py + 16, 14), (py + 21, 10)):
		p.append(("box", (wd, 0.8, 0.8), (px + 3 + (yy - py) * 0.32, yy, 0), "5A5654", {"rot": tilt}))
	for i in range(6):
		p.append(("box", (0.4, rng.uniform(5, 9), 0.4), (rng.uniform(-20, 20), rng.uniform(36, 44), rng.uniform(-5, 5)), RUST, {"rot": (rng.uniform(-30, 30), 0, rng.uniform(-30, 30))}))
	return k.prop("CityChunk", p)


def _rock_pillar(k, rng):
	"""A cavern column: a stalagmite rising into a stalactite, wet rock, gold and ruby veins glowing at its foot."""
	p = [
		("cone", (34, 30, 34), (0, 15, 0), ROCK2, {"seg": 7, "taper": 0.55, "rough": 0.35}),
		("cyl", (18, 60, 18), (0, 58, 0), ROCK, {"seg": 7, "taper": 0.8, "rough": 0.35}),
		("cyl", (15, 50, 15), (2, 110, 1), ROCK3, {"seg": 7, "taper": 1.5, "rough": 0.35}),
		("cone", (34, 40, 34), (2, 150, 1), ROCK, {"seg": 7, "taper": 1.6, "rough": 0.35}),
		("cone", (14, 18, 12), (14, 9, -6), ROCK3, {"seg": 5}),
		("cone", (10, 14, 10), (-13, 7, 7), ROCK, {"seg": 5}),
	]
	_veins(p, rng, 7, 0, 2, -12, 12)
	return k.prop("RockPillar", p)


def _lava_chasm(k, rng):
	"""A stretch of lava river in a chasm: glowing lava between raised broken-rock lips, crust plates, bones. Chained
	end to end (along local X, 120 per piece) into winding rivers."""
	p = [("cyl", (60, 0.4, 32), (x, 0.2, rng.uniform(-2, 2)), LAVA, {"emit": 4, "seg": 14}) for x in (-42, 0, 42)]
	p += [("cyl", (30, 0.4, 20), (x, 0.2, 0), LAVA, {"emit": 4, "seg": 12}) for x in (-64, 64)]
	for side in (-1, 1):
		for i in range(10):
			x = -54 + i * 12
			h = rng.uniform(6, 12)
			p.append(("box", (13, h, 10), (x, h / 2 - 1, side * (21 + rng.uniform(-1, 1))), (ROCK, ROCK2, ROCK3)[i % 3], {"rot": (side * rng.uniform(8, 22), rng.uniform(-10, 10), 0), "rough": 0.4}))
	for i in range(8):
		p.append(("box", (rng.uniform(4, 9), 0.6, rng.uniform(3, 6)), (rng.uniform(-55, 55), 0.5, rng.uniform(-6, 6)), "2A120C", {"rot": (0, rng.uniform(0, 180), 0)}))
	for i in range(4):
		p.append(("cyl", (0.9, rng.uniform(4, 7), 0.9), (rng.uniform(-50, 50), 11, rng.uniform(19, 21)), BONE, {"seg": 6, "rot": (90, rng.uniform(0, 180), 0)}))
	return k.prop("LavaChasm", p)


def _bone_arch(k, rng):
	"""Rib-bone arch over the road: two ivory rib pairs on a vertebra spine. Feet at x = +-31; at the lane edge (24 off
	the centre) the underside is 23 above the road, 34 at the crown (rule: >= 14)."""
	p = []
	for z in (-6, 6):
		_arc(p, 32, 4, z, 15, 165, 11, 4, BONE, {"rough": 0.5})
		for x in (-31, 31):
			p.append(("cyl", (4.6, 44, 4.6), (x, -10, z), BONE2, {"seg": 8, "taper": 0.8}))
			p.append(("ball", (8, 7, 8), (x, 13, z), BONE2, {"subdiv": 1, "smooth": True}))
	for x in (-16, -8, 0, 8, 16):
		y = 4 + math.sqrt(32 * 32 - x * x) + 2
		p.append(("ball", (5.5, 4.4, 15), (x, y, 0), BONE, {"subdiv": 1, "smooth": True}))
		p.append(("cone", (2.2, 7, 2.2), (x, y + 5, 0), BONE2, {"seg": 5}))
	for x in (-31, 31):
		p.append(("cone", (12, 6, 20), (x, 1, 0), ROCK2, {"seg": 6}))
	return k.prop("BoneArch", p)


def _spot(k, x, z, clearance):
	"""The nearest point to (x, z) on a widening spiral that is `clearance` clear of every lap."""
	for i in range(500):
		a, r = i * 0.7, i * 12
		px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		if k.clear_of_road(px, pz, clearance):
			return px, pz
	return x, z


def _clear_near(k, x, z, r, names):
	"""Drop dressing within r of (x, z) so a landmark stays in view."""
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.name.split("_")[2] in names and math.hypot(ob.location.x - x, -ob.location.y - z) < r:
			k.col.objects.unlink(ob)


def _eye(k, f):
	"""The runner's review camera at fraction f (build_track.shots): eye point, heading and right vector."""
	p, right, t = k.at(k.length * f)
	return p + right * 10 - t * 14, t, right


def _clear_view(k, f, x, z, width, names, keep_low=True):
	"""Drop dressing standing in the line of sight from the runner's view at fraction f to (x, z), except the low
	ceiling over the road itself."""
	p, _, t = k.at(k.length * f)
	ex, ez = p.x - t.x * 14, p.z - t.z * 14
	vx, vz = x - ex, z - ez
	ln2 = vx * vx + vz * vz
	for ob in list(k.col.objects):
		if ob.type != "MESH" or ob.name.split("_")[2] not in names or keep_low and ob.scale[0] < 1.5 and ob.name.split("_")[2] == "Ceiling":
			continue
		ox, oz = ob.location.x, -ob.location.y
		u = max(0.0, min(1.0, ((ox - ex) * vx + (oz - ez) * vz) / ln2))
		reach = (110 if ob.name.split("_")[2] == "Ceiling" else 40) * ob.scale[0]
		if math.hypot(ox - ex - vx * u, oz - ez - vz * u) < width + reach:
			k.col.objects.unlink(ob)


def _in_view(k, f, clearance):
	"""The first spot inside the runner's view at fraction f (within 30 degrees of the heading, 500-1500 ahead) that is
	`clearance` clear of every lap."""
	p, _, t = k.at(k.length * f)
	for dist in range(1300, 2201, 100):
		for deg in (0, 10, -10, 20, -20, 28, -28):
			a = math.radians(deg)
			tx, tz = t.x * math.cos(a) - t.z * math.sin(a), t.x * math.sin(a) + t.z * math.cos(a)
			x, z = p.x + tx * dist, p.z + tz * dist
			if k.clear_of_road(x, z, clearance):
				return x, z
	return _spot(k, p.x + t.x * 900, p.z + t.z * 900, clearance)


def _ahead(k, f, dist, clearance, ang=0.0):
	"""A landmark spot ahead of the runner's view at fraction f (turned ang radians off the heading), and the yaw that
	turns its -Z front back toward that view."""
	p, _, t = k.at(k.length * f)
	c, s = math.cos(ang), math.sin(ang)
	tx, tz = t.x * c - t.z * s, t.x * s + t.z * c
	x, z = _spot(k, p.x + tx * dist, p.z + tz * dist, clearance)
	return x, z, math.atan2(p.x - x, p.z - z) + math.pi


def build(k):
	rng = k.rng
	for make in (_ceiling, _flesh_wall, _tower, _coliseum, _shrine, _mine_rail, _graveyard, _colonnade, _city_chunk, _rock_pillar, _lava_chasm, _bone_arch):
		make(k, rng)

	k.ground("2E2A30", margin=2600, rough=0.7)
	big = ("FleshWall", "RockPillar", "CityChunk", "Colonnade", "LavaChasm", "Graveyard", "Ceiling", "MineRail")
	# Low ceiling over the tunnels; over the open caverns, high vault shelves well off to the sides on rock pillars
	d = 30
	while d < k.length - 40:
		pos, yaw = k.beside(d, 0, 1.0)
		if covered(k, d):
			k.place("Ceiling", pos, yaw)
			d += 64
		else:
			for side in (-1, 1):
				for along, off, sc in ((-60, 230, 1.5), (40, 300, 1.8), (100, 250, 1.4)):  # cavern columns, black void above
					r, _ = k.beside(d + along, side * off)
					if k.clear_of_road(r[0], r[2], 120):
						k.place("RockPillar", (r[0], -1.0, r[2]), rng.uniform(0, math.tau), sc)
			d += 64 * VAULT
	d = 300
	while d < k.length - 200:
		pos, yaw = k.beside(d, 0, 1.0)
		k.place("BoneArch", pos, yaw)
		d += 520 if covered(k, d) else 160
	ground_along(k, 60, (-34, 34), ["MineRail", "Graveyard", "MineRail", "Graveyard"], jitter=1, start=40, clear=27)
	ground_along(k, 100, (-52, 52), ["Colonnade", "CityChunk", "LavaChasm", "Colonnade"], jitter=4, start=70)
	ground_along(k, 52, (-72, 72), ["FleshWall"], jitter=6, start=20, scale=(0.9, 1.3), where=lambda d: covered(k, d))
	ground_along(k, 130, (-130, 130), ["CityChunk", "RockPillar", "FleshWall"], jitter=12, start=30, scale=(1.0, 1.5))
	ground_along(k, 110, (-200, 200), ["RockPillar", "FleshWall", "RockPillar"], jitter=15, start=10, scale=(1.2, 1.8))
	k.field(150, ["RockPillar", "RockPillar", "CityChunk", "Graveyard", "Colonnade", "FleshWall"], clearance=170, margin=500, scale=(1.2, 2.2))
	# Lava rivers: chasm pieces chained end to end along winding paths through the infield and outskirts
	for g in range(7):
		x = rng.uniform(k.lo.x + 150, k.hi.x - 150)
		z = rng.uniform(k.lo.z + 150, k.hi.z - 150)
		for _ in range(400):  # a river starts on this track's own ground (wide layout, 2026-11-26 re-fit)
			if k.owns(x, z):
				break
			x, z = rng.uniform(k.lo.x + 150, k.hi.x - 150), rng.uniform(k.lo.z + 150, k.hi.z - 150)
		head = rng.uniform(0, math.tau)
		for i in range(10):
			if k.clear_of_road(x, z, 90):
				k.place("LavaChasm", (x, -1.0, z), head)
			head += rng.uniform(-0.25, 0.25)
			x += math.cos(head) * 118  # local X of the piece runs along its yaw heading (Roblox: +X turned by yaw)
			z -= math.sin(head) * 118
	# 02: the central hall to the right, a city chunk to the left
	e, t, right = _eye(k, 0.33)
	hx, hz, hyaw = _ahead(k, 0.33, 300, 210, 0.5)
	_clear_near(k, hx, hz, 240, big)
	_clear_view(k, 0.33, hx, hz, 70, big)
	k.place("Coliseum", (hx, -1.0, hz), hyaw, 1.5)
	k.light((hx - (hx - e.x) * 0.3, 160, hz - (hz - e.z) * 0.3), "FFC890", energy=6e6, radius=30)
	cx, cz = e.x + t.x * 200 - right.x * 120, e.z + t.z * 200 - right.z * 120
	if k.clear_of_road(cx, cz, 95):
		_clear_near(k, cx, cz, 90, big)
		_clear_view(k, 0.33, cx, cz, 40, big)
		k.place("CityChunk", (cx, -1.0, cz), math.atan2(e.x - cx, e.z - cz) + math.pi, 1.7)
		k.light((cx + right.x * 60, 80, cz + right.z * 60), "FFB070", energy=1.5e6, radius=20)
	# 03: the lair tower framed whole, far ahead, a lava moat at its foot, lit from the runner's side
	tx, tz = _in_view(k, 0.62, 300)
	_clear_near(k, tx, tz, 330, big)
	_clear_view(k, 0.62, tx, tz, 140, big, keep_low=False)  # the tunnel roof ahead opens onto the tower
	k.place("LairTower", (tx, -1.0, tz), 0.0, 4.2)
	e, t, right = _eye(k, 0.62)
	k.light((tx + (e.x - tx) * 0.35, 520, tz + (e.z - tz) * 0.35), "C8D0E0", energy=3e7, radius=80)
	k.light((tx - (e.x - tx) * 0.3, 300, tz - (e.z - tz) * 0.3), "FF8A40", energy=3e7, radius=60)  # rim from behind
	# 04: the shrine head-on, lit low and warm as if from the lava
	sx, sz, syaw = _ahead(k, 0.9, 270, 200, -0.1)
	_clear_near(k, sx, sz, 250, big)
	_clear_view(k, 0.9, sx, sz, 80, big)
	k.place("Shrine", (sx, -1.0, sz), syaw)
	k.light((sx - math.sin(syaw) * 130, 30, sz - math.cos(syaw) * 130), "FF8A40", energy=5e5, radius=30)
	k.light((sx - math.sin(syaw) * 200, 160, sz - math.cos(syaw) * 200), "B8C0D0", energy=3e6, radius=40)
	# 05: the side camera's ground: cleared of rock, a graveyard heap, mine rail, lava and a fill light
	p, right, t = k.at(k.length * 0.48)
	g = p + right * 140 - t * 60
	_clear_near(k, g.x, g.z, 120, big)
	_clear_near(k, (g.x + p.x) / 2, (g.z + p.z) / 2, 70, ("RockPillar", "FleshWall", "CityChunk"))  # the side camera looks over this
	for name, fx, ft in (("Graveyard", 70, -20), ("Graveyard", 95, 30), ("Colonnade", 60, 60), ("CityChunk", 150, 70)):
		x, z = p.x + right.x * fx + t.x * ft, p.z + right.z * fx + t.z * ft
		if k.clear_of_road(x, z, 40):
			k.place(name, (x, -1.0, z), math.atan2(-t.x, -t.z), 1.2)
	k.light((g.x - t.x * 80, 260, g.z - t.z * 80), "D8C8B8", energy=1.5e6, radius=60)
	# Wide layout (2026-11-26 re-fit): the cavern's pillars, ruins and flesh walls out to this track's ground midline
	# (about 380 out), the approved field props at their approved scales
	print("BAND cavern", k.band(["RockPillar", "RockPillar", "CityChunk", "Graveyard", "Colonnade", "FleshWall"], 60, (200, 370), scale=(1.2, 2.2), gap=55, seed=1))
	k.sky([(0.0, "161219"), (0.2, "0A080C"), (1.0, "030204")], strength=1.0, sun=(1.6, "B8B0E0", 35, 120))
	# Warm lamps along the road, and high soft fill lights so the cavern shapes read
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 12)  # well under the rib crowns, so the ivory ribs do not glare
		k.light(pos, "FFD8A8", energy=30000, radius=6).data.use_shadow = False  # many lamps: shadows would overflow Eevee's buffer
		d += 140
	d = 200
	while d < k.length:
		pos, _ = k.beside(d, 60, 150)
		k.light(pos, "C89870", energy=2.5e6, radius=40).data.use_shadow = False
		d += 450
	# Studio lights for the MODEL_SHOTS close-ups (build_track poses each model alone at Roblox (400000, -1, -400000))
	for dx, y, dz, col, e in ((300, 420, -420, "FFE0C0", 1e8), (-380, 200, -300, "B8C4E0", 4e7), (0, 300, 450, "FFB080", 3e7), (0, 160, 0, "E8E8F0", 3e7)):
		k.light((400000 + dx, y, -400000 + dz), col, energy=e, radius=60)
	_enforce_clearance(k)
