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
		p.append(("box", (1.6, 2.2, 1.6), (x, CEIL_UNDER - 15, z), LAMP, {"emit": 6}))
	return k.prop("Ceiling", p)


def _flesh_wall(k, rng):
	"""Organic lair wall (ref Monster_Association_HQ_Volume_23): a wet rock mass with a toothed maw torn into it (dark
	throat, flesh lips, ivory fangs), two thick tentacles curling out, a few flesh growths and an eye bulb."""
	p = [
		("box", (64, 46, 26), (0, 23, 6), ROCK, WET),
		("wedge", (64, 18, 16), (0, 9, -15), ROCK2, WET),
		("ball", (40, 26, 28), (-12, 50, 6), ROCK3, {"subdiv": 1, "rough": 0.4}),
		("ball", (30, 22, 24), (18, 48, 8), ROCK2, {"subdiv": 1, "rough": 0.4}),
		("ball", (30, 20, 6), (-4, 26, -8), FLESH, {"subdiv": 1, "smooth": True, "rough": 0.4}),
		("ball", (24, 13, 5), (-4, 26, -10), "0A0404", {"subdiv": 1}),
	]
	for i in range(7):  # fangs: upper row pointing down, lower row pointing up
		x = -14 + i * 4.6
		p.append(("cone", (2.6, 6, 2.6), (x, 29.5, -11), BONE, {"seg": 5, "rot": (180, 0, 0)}))
		p.append(("cone", (2.2, 5, 2.2), (x + 2.3, 22.5, -11), BONE, {"seg": 5}))
	for side, x0, y0 in ((1, 20, 6), (-1, -24, 10)):  # thick curling tentacles
		for i in range(8):
			t = i / 7
			p.append(("cyl", (7 - i * 0.7, 11, 7 - i * 0.7), (x0 + side * t * 10, y0 + i * 5, -12 - math.sin(t * 3.2) * 12), FLESH2, {"seg": 8, "smooth": True, "rot": (-20 - i * 18, 0, -side * 12)}))
	for x, y, s in ((24, 36, 10), (-26, 34, 9), (10, 10, 8)):
		p.append(("ball", (s, s * 0.8, s * 0.6), (x, y, -7), FLESH, {"subdiv": 1, "smooth": True, "rough": 0.4}))
	p.append(("ball", (6, 6, 4), (12, 40, -10), "E0D8C8", {"subdiv": 1, "smooth": True}))
	p.append(("ball", (2.6, 2.6, 2), (12, 40, -11.6), "1A0A0A", {"subdiv": 1}))
	p.append(("ball", (1.0, 1.0, 1), (12, 40, -12.4), RUBY, {"subdiv": 1, "emit": 3}))
	return k.prop("FleshWall", p)


def _tower(k, rng):
	"""Hero: the lair as an underground tower (ref Monster_Association_HQ_Volume_23): round stone floors with wide
	mushroom ledges, arched windows (some lit), outside stairs, a broken colonnade top, tentacles, a rail ring on a
	timber base at its foot."""
	S1, S2, S3 = "8A857C", "9A958C", "B4AEA2"
	p = [("cyl", (170, 0.6, 170), (0, 0.3, 0), LAVA, {"emit": 4, "seg": 24}), ("cyl", (130, 8, 130), (0, 4, 0), WOOD, {"seg": 24}), ("cyl", (134, 2, 134), (0, 8.5, 0), "3A2A1E", {"seg": 24})]
	for i in range(16):
		a = i * math.tau / 16
		p.append(("box", (3, 8, 1), (math.cos(a) * 65.5, 4, math.sin(a) * 65.5), "3A2A1E", {"rot": (0, -math.degrees(a) + 90, 0)}))
	_ring(p, 58, 9.4, 32, (2, 0.8, 9), "2A1E16")
	_ring(p, 55, 10.2, 32, (11.6, 0.6, 0.6), "8E8A88", {"metal": 0.7})
	_ring(p, 61, 10.2, 32, (12.4, 0.6, 0.6), "8E8A88", {"metal": 0.7})
	levels = ((44, 28), (40, 26), (38, 24), (34, 22), (38, 18))
	y = 8
	for j, (r, h) in enumerate(levels):
		p.append(("cyl", (r * 2, h, r * 2), (0, y + h / 2, 0), (S1, S2)[j % 2], {"seg": 20}))
		p.append(("cyl", (r * 2 + 22, 3, r * 2 + 22), (0, y + h + 1.5, 0), S3, {"seg": 20}))
		p.append(("cone", (r * 2 + 22, 5, r * 2 + 22), (0, y + h - 2.5, 0), S1, {"seg": 20, "taper": 0.85}))
		for i in range(8):
			a = (i + 0.5 * (j % 2)) * math.tau / 8
			ox, oz = math.cos(a) * (r + 0.2), math.sin(a) * (r + 0.2)
			lit = (i + j) % 3 == 0
			p.append(("box", (1, h * 0.5, 6.5), (ox, y + h * 0.4, oz), LAMP if lit else "100C10", {"rot": (0, -math.degrees(a), 0), "emit": 2.5 if lit else 0}))
			p.append(("cyl", (6.5, 1, 6.5), (ox, y + h * 0.65, oz), LAMP if lit else "100C10", {"seg": 8, "rot": (0, -math.degrees(a), 90), "emit": 2.5 if lit else 0}))
		ang = j * 72 + 20
		a = math.radians(ang)
		_stairs(p, math.cos(a) * (r + 6), y + h + 3, math.sin(a) * (r + 6), 7, 3.2, 3, 7, ang + 90, S3)
		y += h + 3
	for i in range(8):
		if i in (2, 5):
			continue
		a = i * math.tau / 8
		x, z = math.cos(a) * 36, math.sin(a) * 36
		hh = 22 if i % 3 else 14
		p.append(("cyl", (3.6, hh, 3.6), (x, y + hh / 2, z), STONE3, {"seg": 10}))
		p.append(("box", (6, 2.4, 6), (x, y + hh + 1.2, z), STONE3))
		p.append(("box", (6, 2, 6), (x, y + 1, z), STONE2))
	for i in (0, 3, 6):
		a = (i + 0.5) * math.tau / 8
		p.append(("box", (30, 4, 6), (math.cos(a) * 34, y + 24.4, math.sin(a) * 34), STONE, {"rot": (0, -math.degrees(a) + 90, 0)}))
	p.append(("box", (40, 3, 28), (8, y + 1.5, -6), STONE, {"rot": (0, 15, 0)}))
	for side, base in ((1, 40), (-1, 70), (1, 95)):
		for i in range(7):
			t = i / 6
			p.append(("cyl", (9 - i, 14, 9 - i), (side * (38 + i * 6), base + i * 6 + math.sin(t * 3) * 6, -10 - t * 10 + (base - 40) * 0.3), FLESH2, {"seg": 8, "smooth": True, "rot": (0, 0, -side * (40 + i * 12))}))
	p += [
		("box", (8, 4.4, 5), (0, 14, -58), RUST2, {"metal": 0.5}),
		("box", (8.6, 0.6, 5.6), (0, 16.4, -58), RUST, {"metal": 0.5}),
		("ball", (6, 3, 4), (0, 16.6, -58), GOLD, {"subdiv": 1, "metal": 0.8, "rough": 0.3, "emit": 0.6}),
	]
	return k.prop("LairTower", p)


def _coliseum(k, rng):
	"""Hero: the central hall (refs Monster_Association_Headquarters_Anime_Profile, The_Monster_Association): a round
	hall of dark grey stone tiers over deep black gaps, tall thin poles, a cracked flagstone floor and the spiked throne
	on a dais; open toward -Z so the tiers show from the road."""
	n, r, tiers = 32, 100, 13
	gap = (24, 25)
	p = [("cyl", (2 * r + 4, 1, 2 * r + 4), (0, 0.5, 0), "2E2A26", {"seg": 32})]
	seg = 2 * math.pi * r / n + 1
	_ring(p, r + 4, 56, n, (seg, 112, 4), "030202", skip=gap)
	for t in range(tiers):
		_ring(p, r - 3 - t * 0.6, 5 + t * 8, n, (seg * 0.98, 4, 7), (STONE, STONE3)[t % 2], skip=gap)
	_ring(p, r + 9, 52, 16, (6, 104, 8), ROCK2)
	for i in range(10):
		a = i * math.tau / 10 + 0.2
		p.append(("cyl", (1.4, 120, 1.4), (math.cos(a) * (r - 14), 60, math.sin(a) * (r - 14)), "1E1A1C", {"seg": 6, "metal": 0.5}))
	for i in range(30):  # cracks across the flagstones
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(5, r - 20)
		p.append(("box", (rng.uniform(8, 20), 0.1, 0.8), (math.cos(a) * rr, 1.06, math.sin(a) * rr), "0A0908", {"rot": (0, rng.uniform(0, 180), 0)}))
	for i in range(7):  # flagstone joints, pale on the dark floor
		o = -75 + i * 25
		p.append(("box", (170, 0.08, 0.6), (0, 1.04, o), "5E5A52"))
		p.append(("box", (0.6, 0.08, 170), (o, 1.04, 0), "5E5A52"))
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
	p = [("cyl", (270, 2, 270), (0, 1, 0), LAVA, {"emit": 4, "seg": 32})]
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
			x = side * (w / 2 - 4)
			p.append(("box", (7, h + 8, 7), (x, yb + h / 2 + 4, -d / 2 + 4), STONE))
			p.append(("box", (9, 3, 9), (x, yb + h + 9.5, -d / 2 + 4), STONE3))
	top = 2 + tiers * 14
	steps = 28
	z0, z1 = -65, -7
	for i in range(steps):
		t = (i + 1) / steps
		p.append(("box", (40, top * t, (z1 - z0) / steps + 0.2), (0, top * t / 2, z0 + (z1 - z0) * (i + 0.5) / steps), STONE3 if i % 2 else "7A746A"))
	slope = math.degrees(math.atan2(top, z1 - z0))
	ln = math.hypot(top, z1 - z0)
	for side in (-1, 1):
		p.append(("box", (5, 5, ln), (side * 22.5, top / 2 + 2.5, (z0 + z1) / 2), STONE, {"rot": (-slope, 0, 0)}))
		for j in range(tiers):  # capped posts stepping down beside the stair, one per tier
			zf = -(130 - j * 18) / 2 + 2
			yb = 2 + j * 14
			p.append(("box", (6, 22, 6), (side * 27, yb + 11, zf), STONE))
			p.append(("box", (8, 3, 8), (side * 27, yb + 23.5, zf), STONE3))
	p.append(("box", (40, 3, 30), (0, top + 1.5, z1 + 10), STONE3))
	p.append(("box", (50, 40, 4), (0, top + 20, 30), "8A847A"))
	for x, y, s in ((-12, top + 26, 6), (6, top + 30, 8), (14, top + 18, 5), (-4, top + 14, 4)):
		p.append(("ball", (s, s * 0.6, 2), (x, y, 27.6), "5A5650", {"subdiv": 1}))
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


def _graveyard(k, rng):
	"""Graveyard of the underground people (ref Subterranean_graveyard): two heaps of ivory dome helmets, each with two
	dark ring bands and a black eye slit, among broken flat tiles and bones."""
	p = []
	for i in range(14):
		s = rng.uniform(4, 8)
		p.append(("box", (s, 0.8, s * 0.8), (rng.uniform(-19, 19), 0.3, rng.uniform(-5, 5)), (STONE3, "8A847A", STONE)[i % 3], {"rot": (rng.uniform(-8, 8), rng.uniform(0, 90), rng.uniform(-8, 8))}))
	for hx in (-9, 9):
		for j, (r, y, n) in enumerate(((4.6, 2.6, 6), (0, 6.6, 1), (2.4, 6.0, 1))):
			for i in range(n):
				a = i * math.tau / max(n, 1) + hx
				x, z = hx + math.cos(a) * r + (j == 2) * 2, math.sin(a) * r * 0.8
				rot = (rng.uniform(-30, 30), rng.uniform(0, 360), rng.uniform(-30, 30))
				p.append(("ball", (6.4, 5.6, 6.4), (x, y, z), "E4DCC8", {"subdiv": 1, "smooth": True, "rot": rot}))
				p.append(("cyl", (6.7, 0.8, 6.7), (x, y + 0.6, z), "2A2622", {"seg": 8, "rot": rot}))
				p.append(("cyl", (6.5, 0.5, 6.5), (x, y - 0.6, z), "2A2622", {"seg": 8, "rot": rot}))
				p.append(("box", (3.6, 0.8, 6.6), (x, y - 0.1, z), "0A0808", {"rot": rot}))
	for i in range(8):
		p.append(("cyl", (0.8, rng.uniform(4, 7), 0.8), (rng.uniform(-18, 18), 0.6, rng.uniform(-4, 4)), BONE, {"seg": 6, "rot": (rng.uniform(80, 100), rng.uniform(0, 180), 0)}))
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
		for f in range(int(h / 7)):
			yy = by - h / 2 + 4 + f * 7
			p.append(("box", (w + 0.4, 2.6, 14.4), (bx, yy, 0), "1E2228", {"rot": rot}))
		p.append(("box", (w + 1, 1.2, 15), (bx, by + h / 2, 0), "5E5850", {"rot": rot}))
	for x, y, z, rz, ry in ((-2, 30, -6, 70, 20), (20, 18, -8, -60, -30), (-30, 16, -10, 85, 40)):
		p.append(("cyl", (2.6, 22, 2.6), (x, y, z), RUST, {"seg": 8, "metal": 0.5, "rot": (0, ry, rz)}))
		p.append(("cyl", (3.4, 0.8, 3.4), (x, y, z), RUST2, {"seg": 8, "metal": 0.5, "rot": (0, ry, rz)}))
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
	p = [("box", (124, 0.4, 22), (0, 0.2, 0), LAVA, {"emit": 5})]
	for side in (-1, 1):
		for i in range(10):
			x = -54 + i * 12
			h = rng.uniform(6, 12)
			p.append(("box", (13, h, 10), (x, h / 2 - 1, side * (15 + rng.uniform(-1, 1))), (ROCK, ROCK2, ROCK3)[i % 3], {"rot": (side * rng.uniform(8, 22), rng.uniform(-10, 10), 0), "rough": 0.4}))
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
				q, _ = k.beside(d, side * 360, 0)  # stalactite tips stay 50+ off the centre line
				if k.clear_of_road(q[0], q[2], 250):
					k.place("Ceiling", (q[0], pos[1], q[2]), yaw, VAULT)
					for along in (-70, 70):  # pillars holding the shelf up
						r, _ = k.beside(d + along, side * 330)
						k.place("RockPillar", (r[0], -1.0, r[2]), rng.uniform(0, math.tau), 0.9)
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
	for g in range(18):
		x = rng.uniform(k.lo.x - 300, k.hi.x + 300)
		z = rng.uniform(k.lo.z - 300, k.hi.z + 300)
		head = rng.uniform(0, math.tau)
		for i in range(6):
			if k.clear_of_road(x, z, 90):
				k.place("LavaChasm", (x, -1.0, z), head)
			head += rng.uniform(-0.35, 0.35)
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
	k.light((tx + (e.x - tx) * 0.35, 520, tz + (e.z - tz) * 0.35), "FFC890", energy=8e7, radius=80)
	k.light((tx - (e.x - tx) * 0.3, 300, tz - (e.z - tz) * 0.3), "FF8A40", energy=3e7, radius=60)  # rim from behind
	# 04: the shrine head-on, lit low and warm as if from the lava
	sx, sz, syaw = _ahead(k, 0.9, 330, 235, -0.15)
	_clear_near(k, sx, sz, 250, big)
	_clear_view(k, 0.9, sx, sz, 80, big)
	k.place("Shrine", (sx, -1.0, sz), syaw)
	k.light((sx - math.sin(syaw) * 130, 30, sz - math.cos(syaw) * 130), "FF8A40", energy=2.5e6, radius=30)
	k.light((sx - math.sin(syaw) * 200, 160, sz - math.cos(syaw) * 200), "C8B8A8", energy=1.5e6, radius=40)
	# 05: the side camera's ground: cleared of rock, a graveyard heap, mine rail, lava and a fill light
	p, right, t = k.at(k.length * 0.48)
	g = p + right * 140 - t * 60
	_clear_near(k, g.x, g.z, 120, big)
	_clear_near(k, (g.x + p.x) / 2, (g.z + p.z) / 2, 70, ("RockPillar", "FleshWall", "CityChunk"))  # the side camera looks over this
	for name, fx, ft in (("Graveyard", 70, -20), ("Graveyard", 95, 30), ("LavaChasm", 115, -70), ("Colonnade", 60, 60), ("CityChunk", 150, 70)):
		x, z = p.x + right.x * fx + t.x * ft, p.z + right.z * fx + t.z * ft
		if k.clear_of_road(x, z, 40):
			k.place(name, (x, -1.0, z), math.atan2(-t.x, -t.z), 1.2)
	k.light((g.x, 140, g.z), "FFC8A0", energy=8e6, radius=40)
	k.sky([(0.0, "161219"), (0.2, "0A080C"), (1.0, "030204")], strength=1.0, sun=(1.6, "B8B0E0", 35, 120))
	# Warm lamps along the road, and high soft fill lights so the cavern shapes read
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 24)
		k.light(pos, "FFD8A8", energy=150000, radius=6)
		d += 140
	d = 200
	while d < k.length:
		pos, _ = k.beside(d, 60, 150)
		k.light(pos, "C89870", energy=6e6, radius=40)
		d += 450
