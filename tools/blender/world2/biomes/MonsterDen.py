"""World 2 Track 8: Monster Den (One Punch). The monsters' underground lair beneath the City Z ghost town, rebuilt closer
1-1 to the manga and anime (refs: docs/world2_refs/MonsterDen.md):
- the lair itself, an underground tower of round stone floors with wide ledges, arched openings, stone colonnades,
  outside staircases, tentacles breaking out and a mine-cart rail ring at its foot (hero landmark);
- the central hall: a round coliseum of horizontal stone tiers with dark gaps, poles and a cracked flagstone floor, the
  king's spiked throne on a dais (hero landmark);
- the shrine deep below: a stepped stone temple with a central staircase, square niche blocks and pillar posts on every
  tier, in a rock alcove over a lava sea (hero landmark near the finish);
- the gold-vein mines: rail trestles with ore carts, gold and ruby crystal veins;
- the graveyard of the underground people: broken flagstones and ringed dome helmets among bones;
- bone-and-flesh organic cave walls and rib arches, rusted pipes, colonnade ruins and sunken blocks of the old city.
A rock ceiling covers long stretches of the road. No symbols or text (design doc 5). Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

ROCK, ROCK2, ROCK3, FLOOR = "2E2830", "3E3640", "1E1A22", "2A2428"
STONE, STONE2, STONE3 = "8A8680", "6E6A66", "B0AAA0"
BONE, BONE2 = "E0D6BE", "C4B89A"
FLESH, FLESH2, VEIN = "86403C", "6A3442", "8A2030"
RUST, RUST2, WOOD = "8A4A2A", "5E3A2A", "6A4A30"
GOLD, RUBY, LAVA, LAMP = "FFC23A", "E0203A", "FF6A1A", "FFB060"
CEIL_UNDER = 34  # underside of every overhead piece above the road (rule: >= 14)


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
	"""The ceiling covers the road except for four open caverns: a chasm, the central hall's cavern (a third in), a
	second chasm and the shrine's lava cavern at the finish."""
	f = d / k.length
	return not (0.18 < f < 0.24 or 0.31 < f < 0.40 or 0.55 < f < 0.60 or 0.86 < f)


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


def _ceiling(k, rng):
	"""Rock ceiling over the road with flesh rib arches, veins, chains with cage lanterns and stalactites outside the
	lane. Local X across the road; underside CEIL_UNDER above it."""
	p = [
		("box", (220, 14, 66), (0, CEIL_UNDER + 7, 0), ROCK3),
		("box", (60, 10, 50), (-70, CEIL_UNDER + 1, 6), ROCK),
		("box", (50, 8, 40), (75, CEIL_UNDER + 2, -8), ROCK),
		("cone", (40, 22, 30), (-40, CEIL_UNDER + 24, -10), ROCK, {"seg": 6}),
		("cone", (30, 16, 24), (60, CEIL_UNDER + 21, 12), ROCK2, {"seg": 6}),
	]
	for x, z, h in ((-34, -12, 22), (-48, 14, 30), (36, 10, 26), (54, -18, 34), (-90, -20, 40), (96, 18, 36), (-28, 22, 14), (30, -24, 16)):
		p.append(("cone", (6 + h / 4, h, 6 + h / 4), (x, CEIL_UNDER - h / 2 + 1, z), ROCK2, {"rot": (180, 0, 0), "seg": 6}))
	for z in (-20, 20):  # flesh rib arches: 28 over the lane edge, 34 at the crown
		_arc(p, 50, -16, z, 22, 158, 9, 3.4, FLESH)
		_arc(p, 50, -16, z + 2.5, 30, 150, 7, 1.4, BONE2)
	for x in (-14, 6, 18):  # veins along the underside
		p.append(("box", (1.2, 0.8, 60), (x, CEIL_UNDER - 0.2, rng.uniform(-3, 3)), VEIN, {"emit": 0.3, "rot": (0, rng.uniform(-20, 20), 0)}))
	for x, z in ((-30, -8), (30, 8), (-36, 18), (34, -16)):  # chains with cage lanterns, outside the lane
		p.append(("cyl", (0.5, 14, 0.5), (x, CEIL_UNDER - 7, z), "4A4448", {"seg": 4, "metal": 0.6}))
		p.append(("box", (2.4, 3, 2.4), (x, CEIL_UNDER - 15, z), "3A3438", {"metal": 0.5}))
		p.append(("box", (1.6, 2.2, 1.6), (x, CEIL_UNDER - 15, z), LAMP, {"emit": 6}))
	return k.prop("Ceiling", p)


def _flesh_wall(k, rng):
	"""Organic cave wall: a rock mass grown over with flesh lumps, embedded ribs, a tentacle, an eye bulb and veins."""
	p = [
		("box", (64, 46, 26), (0, 23, 6), ROCK),
		("wedge", (64, 18, 16), (0, 9, -15), ROCK2),
		("cone", (36, 30, 22), (-14, 58, 6), ROCK3, {"seg": 6}),
		("cone", (28, 24, 20), (18, 54, 8), ROCK2, {"seg": 6}),
	]
	for x, y, s in ((-22, 14, 14), (-6, 28, 18), (14, 18, 15), (24, 36, 12), (-18, 38, 12), (4, 8, 10)):
		p.append(("ball", (s, s * 0.8, s * 0.6), (x, y, -7), (FLESH, FLESH2)[int(x) % 2], {"subdiv": 1, "smooth": True, "rough": 0.5}))
	for x in (-26, -16, -6, 4, 14, 24):  # embedded rib bones curving out of the wall
		p.append(("cyl", (2.2, 30, 2.2), (x, 22, -9), BONE, {"seg": 6, "rot": (-18, 0, 10)}))
	for i in range(6):  # tentacle curling out toward the road
		t = i / 5
		p.append(("cyl", (5 - i * 0.7, 7, 5 - i * 0.7), (20 + t * 4, 6 + i * 5.5, -12 - math.sin(t * 2.5) * 8), FLESH2, {"seg": 8, "rot": (-25 - i * 14, 0, -10), "smooth": True}))
	p.append(("ball", (7, 7, 4), (-8, 30, -12.5), "E8E0D0", {"subdiv": 1, "smooth": True}))
	p.append(("ball", (3, 3, 2), (-8, 30, -14.2), "1A0A0A", {"subdiv": 1}))
	p.append(("ball", (1.2, 1.2, 1), (-8, 30, -15.1), VEIN, {"subdiv": 1, "emit": 3}))
	for i in range(5):
		p.append(("box", (0.8, rng.uniform(14, 26), 0.6), (rng.uniform(-28, 28), rng.uniform(10, 34), -8.5), VEIN, {"emit": 0.3, "rot": (0, 0, rng.uniform(-40, 40))}))
	return k.prop("FleshWall", p)


def _tower(k, rng):
	"""Hero: the lair as an underground tower (ref Monster_Association_HQ_Volume_23): round stone floors with wide
	mushroom ledges, arched openings, outside stairs, a broken colonnade top, tentacles and a rail ring at its foot."""
	p = [("cyl", (130, 8, 130), (0, 4, 0), WOOD, {"seg": 24}), ("cyl", (134, 2, 134), (0, 8.5, 0), "4A3424", {"seg": 24})]
	_ring(p, 58, 9.4, 32, (2, 0.8, 9), "3A2A20")  # rail ties
	_ring(p, 55, 10.2, 32, (11.6, 0.6, 0.6), "8E8A88", {"metal": 0.7})
	_ring(p, 61, 10.2, 32, (12.4, 0.6, 0.6), "8E8A88", {"metal": 0.7})
	levels = ((44, 28), (40, 26), (38, 24), (34, 22), (38, 18))
	y = 8
	for j, (r, h) in enumerate(levels):
		p.append(("cyl", (r * 2, h, r * 2), (0, y + h / 2, 0), (STONE2, STONE)[j % 2], {"seg": 20}))
		p.append(("cyl", (r * 2 + 18, 3, r * 2 + 18), (0, y + h + 1.5, 0), STONE3, {"seg": 20}))
		p.append(("cyl", (r * 2 + 19, 1, r * 2 + 19), (0, y + h - 0.3, 0), "4A4644", {"seg": 20}))
		for i in range(8):  # arched openings: a dark recess with a rounded head
			a = (i + 0.5 * (j % 2)) * math.tau / 8
			ox, oz = math.cos(a) * (r + 0.2), math.sin(a) * (r + 0.2)
			lit = (i + j) % 3 == 0
			p.append(("box", (1, h * 0.55, 7), (ox, y + h * 0.42, oz), LAMP if lit else "141016", {"rot": (0, -math.degrees(a), 0), "emit": 2 if lit else 0}))
			p.append(("cyl", (7, 1, 7), (ox, y + h * 0.7, oz), "141016", {"seg": 8, "rot": (0, -math.degrees(a), 90)}))
		ang = j * 72 + 20  # an outside stair from this ledge to the next
		a = math.radians(ang)
		_stairs(p, math.cos(a) * (r + 5), y + h + 3, math.sin(a) * (r + 5), 7, 3.2, 3, 6, ang + 90, STONE3)
		y += h + 3
	for i in range(8):  # broken colonnade crowning the top ledge
		if i in (2, 5):
			continue
		a = i * math.tau / 8
		x, z = math.cos(a) * 36, math.sin(a) * 36
		hh = 22 if i % 3 else 14
		p.append(("cyl", (3.6, hh, 3.6), (x, y + hh / 2, z), STONE3, {"seg": 10}))
		p.append(("box", (6, 2.4, 6), (x, y + hh + 1.2, z), STONE3))
		p.append(("box", (6, 2, 6), (x, y + 1, z), STONE2))
	for i in (0, 3, 6):
		a0, a1 = i * math.tau / 8, (i + 1) * math.tau / 8
		p.append(("box", (30, 4, 6), (math.cos((a0 + a1) / 2) * 34, y + 24.4, math.sin((a0 + a1) / 2) * 34), STONE, {"rot": (0, -math.degrees((a0 + a1) / 2) + 90, 0)}))
	p.append(("box", (40, 3, 28), (8, y + 1.5, -6), STONE, {"rot": (0, 15, 0)}))
	p.append(("box", (14, 18, 14), (-20, y + 9, 16), "BFB8AA"))
	for side, base in ((1, 40), (-1, 70)):  # two tentacles bursting out of the walls
		for i in range(7):
			t = i / 6
			p.append(("cyl", (9 - i, 10, 9 - i), (side * (38 + i * 6), base + i * 6 + math.sin(t * 3) * 6, -10 - t * 10), FLESH2, {"seg": 8, "smooth": True, "rot": (0, 0, -side * (40 + i * 12))}))
	p += [  # an ore cart on the rail ring
		("box", (8, 4.4, 5), (0, 14, -58), RUST2, {"metal": 0.5}),
		("box", (8.6, 0.6, 5.6), (0, 16.4, -58), RUST, {"metal": 0.5}),
		("ball", (6, 3, 4), (0, 16.6, -58), GOLD, {"subdiv": 1, "metal": 0.8, "rough": 0.3, "emit": 0.4}),
	]
	for dx in (-2.6, 2.6):
		for dz in (-2.4, 2.4):
			p.append(("cyl", (2, 0.8, 2), (dx, 11.6, -58 + dz), "3A3638", {"seg": 8, "rot": (90, 0, 0)}))
	return k.prop("LairTower", p)


def _coliseum(k, rng):
	"""Hero: the central hall (refs Monster_Association_Headquarters_Anime_Profile, The_Monster_Association): a round
	hall of horizontal stone tiers with dark gaps, tall poles, a cracked flagstone floor and the spiked throne on a dais;
	open toward -Z so the tiers show from the road."""
	n, r, tiers = 32, 110, 8
	gap = (23, 24, 25)  # the open side faces -Z (index 24 sits at -90 degrees)
	p = [("cyl", (2 * r + 4, 1, 2 * r + 4), (0, 0.5, 0), "9A968E", {"seg": 32})]
	seg = 2 * math.pi * r / n + 1
	_ring(p, r + 4, 34, n, (seg, 68, 4), "1E1A1C", skip=gap)
	for t in range(tiers):
		_ring(p, r - 3 - t * 1.2, 4 + t * 8, n, (seg * 0.98, 3.6, 7 + t * 0.4), (STONE, STONE3)[t % 2], skip=gap)
	_ring(p, r + 9, 30, 16, (6, 60, 8), ROCK2)
	for i in range(8):
		a = i * math.tau / 8 + 0.2
		p.append(("cyl", (2, 80, 2), (math.cos(a) * (r - 14), 40, math.sin(a) * (r - 14)), "4A4448", {"seg": 6, "metal": 0.5}))
	for i in range(22):
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(5, r - 20)
		p.append(("box", (rng.uniform(8, 20), 0.3, 0.6), (math.cos(a) * rr, 1.1, math.sin(a) * rr), "3A3634", {"rot": (0, rng.uniform(0, 180), 0)}))
	p += [  # the king's throne on a three-step dais at the back (+Z)
		("box", (40, 3, 26), (0, 2.5, 70), STONE2),
		("box", (30, 3, 18), (0, 5.5, 72), STONE),
		("box", (20, 3, 12), (0, 8.5, 74), STONE2),
		("box", (12, 6, 8), (0, 13, 75), "5A1A1E"),
		("box", (14, 26, 4), (0, 23, 79), "3A1416"),
	]
	for x, h in ((-6, 18), (-3, 24), (0, 30), (3, 24), (6, 18), (-9, 12), (9, 12)):
		p.append(("cone", (3, h, 3), (x, 36 + h / 2 - 4, 79), BONE, {"seg": 5}))
	for x in (-8, 8):
		p.append(("cone", (3, 10, 3), (x, 17, 72), BONE, {"seg": 5, "rot": (-30, 0, 0)}))
	return k.prop("Coliseum", p)


def _shrine(k, rng):
	"""Hero: the shrine deep below (ref The_Mysterious_Shrine_Manga): a stepped stone temple with a wide central stair
	and side balustrades, square niche blocks and pillar posts with caps on every tier, a blank relief slab at the top,
	in a rock alcove over a lava sea. Front (-Z) faces the road."""
	p = [("cyl", (420, 2, 420), (0, 1, 0), LAVA, {"emit": 5, "seg": 32})]
	for i in range(14):  # dark crust plates floating on the lava
		a = rng.uniform(0, math.tau)
		rr = rng.uniform(110, 200)
		p.append(("box", (rng.uniform(10, 24), 1.2, rng.uniform(8, 18)), (math.cos(a) * rr, 2.2, math.sin(a) * rr), "3A1A12", {"rot": (0, rng.uniform(0, 180), 0)}))
	tiers = 6
	for j in range(tiers):
		w, d, h = 170 - j * 24, 130 - j * 18, 14
		yb = 2 + j * h
		p.append(("box", (w, h, d), (0, yb + h / 2, 0), (STONE2, STONE)[j % 2]))
		p.append(("box", (w + 2, 1.4, d + 2), (0, yb + h - 0.7, 0), STONE3))
		zf = -d / 2 - 0.4
		for side in (-1, 1):
			for xx in (0.38, 0.72):  # square niche blocks either side of the stair
				x = side * (24 + (w / 2 - 30) * xx)
				p.append(("box", (6, 6, 0.8), (x, yb + h / 2, zf), STONE3))
				p.append(("box", (3, 3, 0.9), (x, yb + h / 2 - 0.4, zf - 0.1), "2A2624"))
			x = side * (w / 2 - 4)  # pillar post with a cap on the tier's front corner
			p.append(("box", (7, h + 8, 7), (x, yb + h / 2 + 4, -d / 2 + 4), STONE))
			p.append(("box", (9, 3, 9), (x, yb + h + 9.5, -d / 2 + 4), STONE3))
	top = 2 + tiers * 14
	run, steps = (130 - (tiers - 1) * 18) / 2, 28
	z0, z1 = -65, -65 + (130 - 34) / 2 + 10
	for i in range(steps):  # the central staircase
		t = (i + 1) / steps
		p.append(("box", (34, top * t, (z1 - z0) / steps + 0.2), (0, top * t / 2, z0 + (z1 - z0) * (i + 0.5) / steps), STONE3 if i % 2 else "A49E94"))
	slope = math.degrees(math.atan2(top, z1 - z0))
	ln = math.hypot(top, z1 - z0)
	for side in (-1, 1):
		p.append(("box", (4, 4, ln), (side * 19, top / 2 + 2, (z0 + z1) / 2), STONE, {"rot": (-slope, 0, 0)}))
	p.append(("box", (40, 3, 30), (0, top + 1.5, z1 + 10), STONE3))
	p.append(("box", (50, 40, 4), (0, top + 20, 30), "C8C0B0"))  # blank relief wall
	for x, y, s in ((-12, top + 26, 6), (6, top + 30, 8), (14, top + 18, 5), (-4, top + 14, 4)):
		p.append(("ball", (s, s * 0.6, 2), (x, y, 27.6), "8A8478", {"subdiv": 1}))
	for side in (-1, 1):  # rock alcove: side masses and an arched roof of slabs
		p.append(("cone", (70, 170, 60), (side * 115, 85, 30), ROCK, {"seg": 6, "taper": 0.3}))
		p.append(("cone", (50, 120, 50), (side * 75, 60, 70), ROCK2, {"seg": 6, "taper": 0.3}))
	for i in range(7):
		a = math.radians(15 + i * 25)
		p.append(("box", (50, 20, 70), (math.cos(a) * 120, 110 + math.sin(a) * 70, 40), (ROCK3, ROCK)[i % 2], {"rot": (0, 0, math.degrees(a) - 90)}))
	for x in (-60, 60):  # braziers on the base tier
		p.append(("cyl", (6, 6, 6), (x, 19, -62), STONE2, {"seg": 8}))
		p.append(("cone", (5, 6, 5), (x, 25, -62), LAVA, {"emit": 8, "seg": 6}))
	return k.prop("Shrine", p)


def _mine_rail(k, rng):
	"""Gold-vein mine rail (ref Underground Gold Veins): a timber trestle with ties and rails, an ore cart loaded with
	gold and a sack, a lantern post. Runs along the road (local X)."""
	L = 48
	p = []
	for i in range(7):
		x = -L / 2 + i * L / 6
		for z in (-3, 3):
			p.append(("box", (1.2, 9, 1.2), (x, 4.5, z), WOOD))
		p.append(("box", (1.2, 1.2, 7.6), (x, 8.6, 0), "5A3E28"))
		if i < 6:
			p.append(("box", (0.6, 11, 0.6), (x + L / 12, 4.5, -3), "5A3E28", {"rot": (0, 0, 48)}))
	for z in (-3, 3):
		p.append(("box", (L, 1.2, 1.2), (0, 8.6, z), WOOD))
	for i in range(16):
		p.append(("box", (1.2, 0.6, 8), (-L / 2 + 1.5 + i * 3, 9.5, 0), "3A2A20"))
	for z in (-2, 2):
		p.append(("box", (L, 0.6, 0.5), (0, 10.1, z), "8E8A88", {"metal": 0.7, "rough": 0.4}))
	p += [
		("box", (8, 4.5, 5.6), (6, 13.2, 0), RUST2, {"metal": 0.5}),
		("box", (8.6, 0.6, 6.2), (6, 15.6, 0), RUST, {"metal": 0.5}),
		("ball", (6.4, 3.6, 4.4), (6, 15.8, 0), GOLD, {"subdiv": 1, "metal": 0.8, "rough": 0.3, "emit": 0.5}),
		("ball", (3, 4, 3), (-8, 12.4, 0), "C8B48A", {"subdiv": 1, "smooth": True}),
		("cyl", (1.4, 1, 1.4), (-8, 14.6, 0), "8A7448", {"seg": 6}),
	]
	for dx in (-2.8, 2.8):
		for dz in (-2.2, 2.2):
			p.append(("cyl", (2, 0.8, 2), (6 + dx, 11, dz), "3A3638", {"seg": 8, "rot": (90, 0, 0)}))
	p.append(("box", (0.8, 18, 0.8), (-20, 9, -4.5), WOOD))
	p.append(("box", (0.6, 0.6, 3), (-20, 17.6, -5.5), WOOD))
	p.append(("box", (1.6, 2, 1.6), (-20, 16, -7), LAMP, {"emit": 5}))
	for i in range(5):
		p.append(("box", (rng.uniform(1.5, 3),) * 3, (rng.uniform(16, 24), 1, rng.uniform(-6, -2)), GOLD, {"metal": 0.8, "emit": 0.4, "rot": (rng.uniform(0, 45), rng.uniform(0, 90), 0)}))
	return k.prop("MineRail", p)


def _graveyard(k, rng):
	"""Graveyard of the underground people (ref Subterranean_graveyard): tilted broken flagstones, ringed dome helmets
	with dark eye slits, scattered bones."""
	p = []
	for i in range(12):
		s = rng.uniform(4, 8)
		p.append(("box", (s, 1.4, s * 0.8), (rng.uniform(-14, 14), 0.6, rng.uniform(-5, 5)), (STONE3, "A49E94", STONE)[i % 3], {"rot": (rng.uniform(-22, 22), rng.uniform(0, 90), rng.uniform(-22, 22))}))
	for i in range(10):
		x, z = rng.uniform(-16, 16), rng.uniform(-6, 6)
		y = rng.uniform(1.4, 3.2)
		r = (rng.uniform(-30, 30), rng.uniform(0, 360), rng.uniform(-30, 30))
		p.append(("ball", (5, 4.4, 5), (x, y, z), "C8C2B4", {"subdiv": 1, "smooth": True, "rot": r}))
		p.append(("cyl", (5.3, 0.7, 5.3), (x, y + 0.4, z), "7A746A", {"seg": 10, "rot": r}))
		p.append(("box", (3, 0.7, 1), (x, y - 0.3, z), "141012", {"rot": r}))
	for i in range(8):
		p.append(("cyl", (0.8, rng.uniform(4, 7), 0.8), (rng.uniform(-14, 14), 0.6, rng.uniform(-5, 5)), BONE, {"seg": 6, "rot": (rng.uniform(80, 100), rng.uniform(0, 180), 0)}))
	return k.prop("Graveyard", p)


def _colonnade(k, rng):
	"""Ruin of the underground people's colonnade: two columns with bases and capitals under a broken lintel, a
	stump and a fallen drum."""
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


def _ruin_block(k, rng):
	"""A sunken block of the old city above, tilted into the cavern floor: window grid, broken balcony, rebar, rocks."""
	w, h, d = 24, 34, 16
	rot = (8, 0, 14)
	p = [("box", (w, h, d), (0, h / 2 - 6, 0), "7A7670", {"rot": rot})]
	ca, sa = math.cos(math.radians(14)), math.sin(math.radians(14))
	for f in range(4):  # floor bands and window strips on the -Z face, tilted with the block
		y = f * 8 - 2
		for dy, col, hh in ((0, "5E5A56", 1.6), (4, "2A3038", 4)):
			yy = y + dy
			p.append(("box", (w + 0.4, hh, 0.6), (-yy * sa, yy * ca + (h / 2 - 6) * (1 - ca), -d / 2 - 0.2), col, {"rot": rot}))
	p.append(("box", (12, 0.8, 4), (-6, 22, -d / 2 - 2), "8E8A84", {"rot": (20, 0, 14)}))
	for i in range(5):
		p.append(("box", (0.4, rng.uniform(5, 9), 0.4), (rng.uniform(-14, 4), 28 + rng.uniform(-2, 3), rng.uniform(-6, 6)), RUST, {"rot": (rng.uniform(-30, 30), 0, rng.uniform(-30, 30))}))
	for i in range(7):
		s = rng.uniform(5, 10)
		p.append(("cone", (s, s * 0.8, s), (rng.uniform(-18, 18), s * 0.3, rng.uniform(-12, 10)), (ROCK, ROCK2)[i % 2], {"seg": 5, "rot": (0, rng.uniform(0, 90), 0)}))
	return k.prop("RuinBlock", p)


def _pipes(k, rng):
	"""Rusted pipe run on stands: two pipes with flanges, a valve wheel with spokes, a gauge and a riser elbow."""
	p = [
		("cyl", (3, 46, 3), (0, 7, 0), RUST, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6, "rough": 0.6}),
		("cyl", (2, 46, 2), (0, 4, 3.5), RUST2, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6, "rough": 0.6}),
		("cyl", (3, 30, 3), (23, 22, 0), RUST, {"seg": 8, "metal": 0.6, "rough": 0.6}),
		("ball", (3.6, 3.6, 3.6), (23, 7, 0), RUST2, {"subdiv": 1, "metal": 0.6}),
	]
	for x in (-20, -12, -4, 4, 12, 20):
		p.append(("cyl", (3.8, 0.8, 3.8), (x, 7, 0), RUST2, {"rot": (0, 0, 90), "seg": 8, "metal": 0.6}))
		p.append(("cyl", (2.8, 0.6, 2.8), (x, 4, 3.5), "4A3028", {"rot": (0, 0, 90), "seg": 8, "metal": 0.6}))
	for x in (-16, 0, 16):
		p.append(("box", (1.4, 7, 9), (x, 3.5, 1.5), "3A3036"))
	p.append(("cyl", (1, 3.5, 1), (2, 10, 0), "5A5054", {"seg": 6}))
	p.append(("cyl", (5, 0.6, 5), (2, 12, 0), "B8B0A8", {"seg": 10, "metal": 0.8}))
	p.append(("box", (4.4, 0.4, 0.5), (2, 12.2, 0), "B8B0A8", {"metal": 0.8}))
	p.append(("box", (0.5, 0.4, 4.4), (2, 12.2, 0), "B8B0A8", {"metal": 0.8}))
	p.append(("cyl", (2, 0.5, 2), (-8, 9, -1.6), "D8D4C8", {"seg": 8, "rot": (90, 0, 0)}))
	p.append(("box", (0.8, 1.2, 0.8), (-8, 7.8, -1), "3A3036"))
	for y in (14, 24, 33):
		p.append(("box", (5, 1, 5), (23, y, 0), "3A3036"))
	return k.prop("PipeRun", p)


def _crystals(k, rng):
	"""Gold and ruby vein cluster on a rock base (the gold-vein mines)."""
	p = [("cone", (14, 8, 12), (0, 4, 0), ROCK2, {"seg": 6}), ("cone", (9, 6, 8), (6, 3, 3), ROCK, {"seg": 5})]
	for x, z, h, rz, col in ((0, 0, 14, 0, GOLD), (4, 2, 9, -22, GOLD), (-3, -2, 8, 24, RUBY), (-5, 3, 10, 30, GOLD), (2, -4, 7, -12, RUBY), (6, -1, 6, -35, RUBY)):
		p.append(("cone", (h * 0.3, h, h * 0.3), (x, 5 + h / 2, z), col, {"emit": 1.6, "seg": 5, "metal": 0.6, "rough": 0.3, "rot": (rng.uniform(-15, 15), 0, rz)}))
	return k.prop("Crystals", p)


def _bone_arch(k, rng):
	"""Rib-bone arch over the road: two rib pairs on a vertebra spine. Feet at x = +-31; at the lane edge (24 off the
	centre) the underside is 23 above the road, 34 at the crown (rule: >= 14)."""
	p = []
	for z in (-6, 6):
		_arc(p, 32, 4, z, 15, 165, 11, 4, BONE)
		for x in (-31, 31):
			p.append(("cyl", (4.6, 44, 4.6), (x, -10, z), BONE2, {"seg": 8, "taper": 0.8}))
			p.append(("ball", (8, 7, 8), (x, 13, z), BONE2, {"subdiv": 1, "smooth": True}))
	for x in (-16, -8, 0, 8, 16):
		y = 4 + math.sqrt(32 * 32 - x * x) + 2
		p.append(("ball", (5.5, 4.4, 15), (x, y, 0), BONE, {"subdiv": 1, "smooth": True}))
		p.append(("cone", (2.2, 7, 2.2), (x, y + 5, 0), BONE2, {"seg": 5}))
	for x in (-31, 31):
		p.append(("ball", (7, 4, 18), (x, 0.5, 0), FLESH, {"subdiv": 1, "smooth": True}))
	return k.prop("BoneArch", p)


def _spot(k, x, z, clearance, margin=0):
	"""The nearest point to (x, z) on a widening spiral that is `clearance` clear of every lap."""
	for i in range(400):
		a, r = i * 0.7, i * 12
		px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		if k.clear_of_road(px, pz, clearance):
			return px, pz
	return x, z


def _clear_side_shot(k):
	"""Keep the raised side review camera (build_track.shots, 48% along, 140 right) out of the cave walls."""
	p, right, t = k.at(k.length * 0.48)
	eye = p + right * 140 - t * 60
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.name.split("_")[2] in ("FleshWall", "RuinBlock", "Colonnade"):
			if math.hypot(ob.location.x - eye.x, -ob.location.y - eye.z) < 70:
				k.col.objects.unlink(ob)


def build(k):
	rng = k.rng
	for make in (_ceiling, _flesh_wall, _tower, _coliseum, _shrine, _mine_rail, _graveyard, _colonnade, _ruin_block, _pipes, _crystals, _bone_arch):
		make(k, rng)

	k.ground("3A3238", margin=500, rough=0.9)
	# Ceiling over the covered stretches, spaced to its 66-stud depth so it reads as one roof
	d = 30
	while d < k.length - 40:
		if covered(k, d):
			pos, yaw = k.beside(d, 0, 1.0)
			k.place("Ceiling", pos, yaw)
		d += 64
	# Bone arches inside the open chasm stretches and at intervals elsewhere
	d = 300
	while d < k.length - 200:
		pos, yaw = k.beside(d, 0, 1.0)
		k.place("BoneArch", pos, yaw)
		d += 520 if covered(k, d) else 160
	ground_along(k, 60, (-34, 34), ["MineRail", "PipeRun", "Graveyard", "MineRail", "Crystals"], jitter=1, start=40, clear=27)
	ground_along(k, 90, (-46, 46), ["Colonnade", "Crystals", "RuinBlock", "Graveyard"], jitter=6, start=70)
	ground_along(k, 52, (-70, 70), ["FleshWall"], jitter=6, start=20, scale=(0.9, 1.3), where=lambda d: covered(k, d))
	ground_along(k, 120, (-120, 120), ["RuinBlock", "Colonnade", "FleshWall", "Crystals"], jitter=12, start=30, scale=(1.0, 1.6))
	ground_along(k, 90, (-190, 190), ["FleshWall"], jitter=12, start=10, scale=(1.2, 1.8), where=lambda d: covered(k, d))
	# Hero landmarks: the lair tower and the central hall in the infield, the shrine near the finish
	c = (k.lo + k.hi) / 2
	tx, tz = _spot(k, c.x, c.z, 215)
	k.place("LairTower", (tx, -1.0, tz), 0.0, 2.4)
	k.light((tx + 150, 650, tz - 150), "FFC890", energy=4e7, radius=40)
	p, _, t = k.at(k.length * 0.33)
	hx, hz = _spot(k, p.x + t.x * 260, p.z + t.z * 260, 225)
	if math.hypot(hx - tx, hz - tz) > 330:
		k.place("Coliseum", (hx, -1.0, hz), math.atan2(p.x - hx, p.z - hz) + math.pi, 1.5)
		k.light((hx, 320, hz), "E8E0FF", energy=1.2e7, radius=30)
	pos, yaw = k.beside(k.length * 0.93, 280)
	k.place("Shrine", (pos[0], -1.0, pos[2]), yaw + math.pi / 2)
	k.light((pos[0], 200, pos[2]), "FF9A50", energy=2e7, radius=30)
	k.field(170, ["FleshWall", "FleshWall", "Colonnade", "RuinBlock", "Crystals", "Graveyard"], clearance=190, margin=450, scale=(1.2, 2.4))
	_clear_side_shot(k)
	k.sky([(0.0, "2A2030"), (0.15, "1C1622"), (0.5, "0E0A12"), (1.0, "060408")], strength=1.4, sun=(1.4, "D0B0FF", 40, 120))
	# Warm and pale-green lamps along the road so it reads under the ceiling
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 24)
		k.light(pos, "FFD8A8" if int(d / 140) % 2 else "D8FFC0", energy=80000, radius=6)
		d += 140
