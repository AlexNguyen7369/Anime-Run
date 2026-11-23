"""World 2 Track 3: City Z, ruined (One Punch). The abandoned ghost-town district of City Z in bright, hazy daylight,
rebuilt closer 1-1 to the anime (refs: docs/world2_refs/RuinedCityZ.md):
- the hero's narrow mid-rise apartment block: brick balcony stack with AC units on the street face, a blank stained
  grey concrete end wall with square patches and bolts, roof railing and water tank (hero landmark near the start);
- empty grey high-rises and mid-rise apartments with window grids, balconies, rooftop tanks and stair cores, some
  smashed, half-collapsed with exposed floors and rebar;
- the dark elevated expressway that crosses the ghost town, broken off at one end;
- the evacuation cordon: chain-link fence, yellow-black barrier, blank red-and-white warning board (no text), cones;
- Japanese concrete utility poles with transformers and street lamps, street trees, rubble with a crushed car;
- the meteor crater in the infield (City A/Z damage) and the Hero Association HQ on the horizon: a stepped cluster of
  dark towers on a ribbed sloped hull over a round base with radiating highways (no emblem).
The route slopes are filled from the ground (TrackBuilder's hill supports). No signs with text, no logos (design doc 5).
Everything in-house, parts only. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

CONC, CONC2, BEIGE, TAN = "B4B0A8", "9AA0A6", "D6C4A4", "B8875E"
GLASS, GLASS2, DARK, FRAME = "3E5A72", "5C7890", "2E2B28", "C9C7C0"
BRICK, BRICK2, RUST, SCORCH = "8B5A45", "74483A", "8A5A3A", "3A3028"
ASPH, STEEL, HQ, HQ2, HQGLASS = "4E4B47", "7E848A", "3A4250", "5A6474", "2C3A4E"


def _fill(k, color):
	"""Ground fill under the raised road (the game's hill supports), so the cliff road is not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width - 1, step + 0.5, p.y + 0.5)
		d += step


def _row(k, every, off, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), clear=None, yaw_jit=0.0):
	"""Both sides of the road every `every` studs, on the ground (y = -1), -Z facing the road; skipped where another
	stretch of road passes closer than `clear` (default 0.9 x the offset)."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for o in (-off, off):
			oo = o + k.rng.uniform(-jitter, jitter) * (1 if o > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), oo)
			if k.clear_of_road(pos[0], pos[2], clear or abs(oo) * 0.9):
				yaw += (math.pi / 2 if o > 0 else -math.pi / 2) + k.rng.uniform(-yaw_jit, yaw_jit)
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def _put(k, name, d, off, scale=1.0):
	"""One instance facing the road at distance d, offset off; searches forward until clear of every lap."""
	for step in range(12):
		pos, yaw = k.beside(d + step * 25, off)
		if k.clear_of_road(pos[0], pos[2], abs(off) * 0.85):
			return k.place(name, (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2), scale)
	return None


# --- local part helpers (Roblox local space: Y up, -Z is the face toward the road) ---
def _f(face, cx, cz, u, n, y, su, sy, sn):
	"""Size and centre of a slab on a wall: u along the wall, n out of it. face z (the -Z front), x+ or x-."""
	if face in ("z", "z+"):
		return (su, sy, sn), (cx + u, y, cz + (n if face == "z+" else -n))
	s = 1 if face == "x+" else -1
	return (sn, sy, su), (cx + s * n, y, cz + u)


def _add(parts, face, cx, cz, u, n, y, su, sy, sn, col, o=None):
	size, pos = _f(face, cx, cz, u, n, y, su, sy, sn)
	parts.append(("box", size, pos, col, o or {}))


def _grid(parts, face, cx, cz, w, y0, floors, fh, cols, rng, glass=GLASS, frame=FRAME, broken=0.0):
	"""Window grid: one glass sheet, spandrel bands per floor and mullions over it, some smashed (dark) panes."""
	h = floors * fh
	_add(parts, face, cx, cz, 0, 0.15, y0 + h / 2, w - 1, h, 0.3, glass, {"rough": 0.25, "metal": 0.3})
	for fl in range(floors + 1):
		_add(parts, face, cx, cz, 0, 0.5, y0 + fl * fh, w, fh * 0.32, 0.8, frame)
	for i in range(cols + 1):
		_add(parts, face, cx, cz, -w / 2 + i * w / cols, 0.45, y0 + h / 2, 0.8, h, 0.7, frame)
	for fl in range(floors):
		for i in range(cols):
			if rng.random() < broken:
				_add(parts, face, cx, cz, -w / 2 + (i + 0.5) * w / cols, 0.35, y0 + (fl + 0.5) * fh, w / cols - 1.4, fh * 0.6, 0.3, DARK)


def _crack(parts, face, cx, cz, u, y, length, ang):
	"""A dark crack line on a wall."""
	size, pos = _f(face, cx, cz, u, 0.25, y, 0.5, length, 0.3)
	rot = (0, 0, ang) if face[0] == "z" else (ang, 0, 0)
	parts.append(("box", size, pos, "3A3632", {"rot": rot}))


def _rebar(parts, x, y, z, n, rng, spread=3.0):
	for _ in range(n):
		parts.append(("box", (0.35, rng.uniform(4, 9), 0.35), (x + rng.uniform(-spread, spread), y + 2.5, z + rng.uniform(-spread, spread)), RUST, {"rot": (rng.uniform(-35, 35), 0, rng.uniform(-35, 35)), "metal": 0.4}))


def _tank(parts, x, y, z, s=1.0):
	"""Rooftop water tank on a steel stand."""
	for dx in (-1.6, 1.6):
		for dz in (-1.6, 1.6):
			parts.append(("box", (0.4, 3 * s, 0.4), (x + dx * s, y + 1.5 * s, z + dz * s), STEEL))
	parts.append(("cyl", (5 * s, 5 * s, 5 * s), (x, y + 5.5 * s, z), "C8C4BA", {"seg": 10}))
	parts.append(("cyl", (5.4 * s, 0.4, 5.4 * s), (x, y + 8.2 * s, z), "8E8A84", {"seg": 10}))


def _roof(parts, w, d, h, col=CONC2):
	"""Roof parapet and a stair core with its door."""
	for (sx, sz, x, z) in ((w, 0.8, 0, -d / 2 + 0.4), (w, 0.8, 0, d / 2 - 0.4), (0.8, d, -w / 2 + 0.4, 0), (0.8, d, w / 2 - 0.4, 0)):
		parts.append(("box", (sx, 2, sz), (x, h + 1, z), col))
	parts.append(("box", (7, 7, 6), (-w / 2 + 5, h + 3.5, d / 2 - 4.5), col))
	parts.append(("box", (2.4, 4.5, 0.3), (-w / 2 + 5, h + 2.25, d / 2 - 7.6), DARK))


def _saitama_apartment(k, rng):
	"""Hero: the hero's narrow mid-rise apartment block (anime ep. 1, refs Saitamas_Apartment_Anime, _at_night)."""
	w, d, g, fh, floors = 24, 20, 10, 9, 7
	h = g + floors * fh
	p = [("box", (w, h, d), (0, h / 2, 0), "A9A59D")]
	# Street face (-Z): brick balcony stack, three units per floor, AC units on the balconies
	p.append(("box", (w, h - g, 0.3), (0, g + (h - g) / 2, -d / 2 - 0.15), BRICK2))
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w + 0.6, 0.8, 3.6), (0, y, -d / 2 - 1.8), "B2AEA6"))
		for x in (-12, -4, 4, 12):
			p.append(("box", (0.7, fh, 3.6), (x, y + fh / 2, -d / 2 - 1.8), BRICK))
		for ux in (-8, 0, 8):
			p.append(("box", (7.4, 3.6, 0.7), (ux, y + 2.2, -d / 2 - 3.3), BRICK))
			p.append(("box", (7.6, 0.4, 0.9), (ux, y + 4.1, -d / 2 - 3.3), "C2B8A8"))
			p.append(("box", (4.2, 6.4, 0.3), (ux - 1.2, y + 3.6, -d / 2 - 0.35), "3A4450", {"rough": 0.3}))
			p.append(("box", (2.6, 2.2, 1.2), (ux + 2.3, y + 1.5, -d / 2 - 2.2), "D9D6CE"))
			p.append(("cyl", (1.6, 0.3, 1.6), (ux + 2.1, y + 1.5, -d / 2 - 2.85), "6E6E6A", {"seg": 8, "rot": (90, 0, 0)}))
	# Ground floor: rolled shutters with grooves, entrance with a canopy, wall lamps, low fence with a railing
	p.append(("box", (11, 7.5, 0.4), (-6, 3.75, -d / 2 - 0.2), "8E9096", {"metal": 0.3}))
	for i in range(7):
		p.append(("box", (11, 0.25, 0.5), (-6, 0.8 + i * 1, -d / 2 - 0.25), "6E7076"))
	p.append(("box", (5, 7.5, 0.4), (6, 3.75, -d / 2 - 0.2), DARK))
	p.append(("box", (9, 0.5, 3.4), (6, 8, -d / 2 - 1.7), "B2AEA6"))
	for x in (-10, -6, -2):
		p.append(("box", (0.4, 0.4, 1.6), (x, 8.6, -d / 2 - 0.8), "3A3A3A"))
		p.append(("box", (1.0, 0.6, 0.6), (x, 8.3, -d / 2 - 1.6), "E8E4D0", {"emit": 0.4}))
	p.append(("box", (w + 2, 2.4, 1), (0, 1.2, -d / 2 - 7), "B8B6AE"))
	for i in range(14):
		p.append(("box", (0.25, 3, 0.25), (-w / 2 + i * 2, 3.9, -d / 2 - 7), "4A3A30"))
	p.append(("box", (w + 2, 0.35, 0.35), (0, 5.4, -d / 2 - 7), "4A3A30"))
	for x in (-8, 3, 10):
		p.append(("ball", (3.4, 2.6, 3.0), (x, 3.4, -d / 2 - 5.2), "4E6B3A", {"subdiv": 1, "smooth": True}))
	# Blank stained concrete end walls: square patches, panel seams, bolts, rust streaks, a drain pipe
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		for _ in range(6):
			pw, ph = rng.uniform(5, 10), rng.uniform(6, 14)
			_add(p, face, cx, 0, rng.uniform(-d / 2 + pw / 2 + 1, d / 2 - pw / 2 - 1), 0.12, rng.uniform(g + ph, h - ph / 2 - 2), pw, ph, 0.24, rng.choice(("8E8B84", "9A968E", "B6B2AA")))
		for fl in range(1, floors + 1):
			_add(p, face, cx, 0, 0, 0.18, g + fl * fh, d, 0.35, 0.3, "8A8780")
		for fl in range(floors):
			for u in (-6, 0, 6):
				_add(p, face, cx, 0, u, 0.3, g + fl * fh + 5, 0.5, 0.5, 0.6, "55534E")
		for _ in range(4):
			_add(p, face, cx, 0, rng.uniform(-8, 8), 0.14, rng.uniform(25, 60), rng.uniform(0.8, 2), rng.uniform(8, 18), 0.2, "7E6E60")
	p.append(("cyl", (0.9, h, 0.9), (w / 2 + 0.6, h / 2, -d / 2 + 1), "6E6E6A", {"seg": 6}))
	# Back: small windows
	_grid(p, "z+", 0, d / 2, w - 4, g, floors, fh, 4, rng)
	# Roof: parapet, railing posts and rail, water tank, stair core, antenna
	_roof(p, w, d, h, "A9A59D")
	for i in range(9):
		p.append(("box", (0.25, 3, 0.25), (-w / 2 + 0.6 + i * (w - 1.2) / 8, h + 3.5, -d / 2 + 0.6), STEEL))
	p.append(("box", (w, 0.3, 0.3), (0, h + 5, -d / 2 + 0.6), STEEL))
	_tank(p, w / 2 - 5, h, 2)
	p.append(("cyl", (0.3, 9, 0.3), (2, h + 4.5, 4), STEEL, {"seg": 6}))
	p.append(("box", (5, 0.3, 0.3), (2, h + 8, 4), STEEL))
	return k.prop("SaitamaApt", p)


def _hero_hq(k, rng):
	"""Hero, horizon: the Hero Association HQ (refs New_Hero_Association_Headquarters_Anime, Hero_Association_HQ): a
	stepped cluster of dark towers on a ribbed sloped hull over a round base, highways radiating out. No emblem."""
	p = [
		("cyl", (520, 4, 520), (0, 2, 0), "4A4E54", {"seg": 32}),
		("cyl", (420, 18, 420), (0, 9, 0), HQ, {"seg": 32}),
		("cyl", (428, 3, 428), (0, 17, 0), HQ2, {"seg": 32}),
		("cone", (300, 70, 300), (0, 53, 0), HQ, {"seg": 24, "taper": 0.5}),
		("cyl", (156, 4, 156), (0, 90, 0), HQ2, {"seg": 24}),
	]
	for i in range(24):  # hull ribs: from r 150 at y 18 up to r 75 at y 88
		a = i * math.tau / 24
		p.append(("box", (4, 103, 6), (math.cos(a) * 112, 53, math.sin(a) * 112), HQ2, {"rot": (0, -math.degrees(a), 47)}))
	for i in range(12):  # dark window slots between the ribs
		a = (i + 0.5) * math.tau / 12
		p.append(("box", (2, 40, 14), (math.cos(a) * 118, 50, math.sin(a) * 118), HQGLASS, {"rot": (0, -math.degrees(a), 47), "emit": 0.2}))
	p.append(("box", (30, 250, 30), (0, 92 + 125, 0), HQ))
	p.append(("box", (32, 4, 32), (0, 92 + 250, 0), HQ2))
	p.append(("cyl", (2, 50, 2), (0, 92 + 275, 0), STEEL, {"seg": 6}))
	for j in range(44):  # stepped tower cluster, tallest at the middle
		r = rng.uniform(16, 70)
		a = rng.uniform(0, math.tau)
		hh = max(14, 200 - r * 2.4 + rng.uniform(-25, 25))
		s = rng.uniform(10, 22)
		x, z = math.cos(a) * r, math.sin(a) * r
		p.append(("box", (s, hh, s), (x, 92 + hh / 2, z), (HQ, "323A46", HQ2)[j % 3]))
		p.append(("box", (s * 0.8, 0.8, 0.4), (x, 92 + hh * 0.7, z - s / 2 - 0.2), HQGLASS, {"emit": 0.4}))
	for j in range(22):  # blocks on the rim of the base
		a = j * math.tau / 22 + 0.1
		s = rng.uniform(6, 12)
		p.append(("box", (s, s * 1.4, s), (math.cos(a) * 172, 18 + s * 0.7, math.sin(a) * 172), HQ2))
	for i in range(10):  # radiating highways on piers
		a = i * math.tau / 10 + 0.15
		c, s = math.cos(a), math.sin(a)
		p.append(("box", (420, 3, 16), (c * 420, 10, s * 420), "6A6E74", {"rot": (0, -math.degrees(a), 0)}))
		for r in (260, 380, 500, 610):
			p.append(("box", (5, 10, 8), (c * r, 4, s * r), "5A5E64", {"rot": (0, -math.degrees(a), 0)}))
	return k.prop("HeroHQ", p)


def _overpass(k, rng):
	"""The dark elevated expressway over the ghost town (ref Z-City_Ghost_Town_Anime_Profile), crossing the road.
	Local X runs across the road; piers at x = +-42, deck underside 22 above the road (rule: >= 14)."""
	p = [("box", (150, 3, 26), (0, 23.5, 0), "4A4C50")]
	for z in (-8, 0, 8):
		p.append(("box", (150, 2.5, 1.6), (0, 21.0, z), "3A3C40"))
	for z in (-12.5, 12.5):
		p.append(("box", (150, 3, 1), (0, 26.5, z), "6A6C70"))
		p.append(("box", (150, 0.5, 1.4), (0, 28.2, z), "8A8C90"))
	for x in (-42, 42):
		p.append(("box", (7, 52, 7), (x, -8, 0), "5A5C60"))
		p.append(("box", (9, 3, 28), (x, 20.5, 0), "4A4C50"))
		p.append(("box", (7.4, 3, 7.4), (x, -1.5, 0), "4A4C50"))
	for x in (-70, -20, 20):
		p.append(("box", (1.2, 3.2, 26), (x, 23.6, 0), "2E3034"))
	for x in (-60, -30, 0, 30):
		p.append(("box", (6, 0.2, 0.6), (x, 25.1, 0), "D8D2C0"))
	for x in (-55, -10, 35):
		p.append(("cyl", (0.7, 12, 0.7), (x, 31, 12.5), STEEL, {"seg": 6}))
		p.append(("box", (0.5, 0.5, 5), (x, 37, 10.2), STEEL))
		p.append(("box", (1.6, 0.6, 2.2), (x, 36.7, 8), "E8E4D0", {"emit": 0.5}))
	# Broken-off end beyond the right pier: hanging slab, exposed rebar, rubble on the ground
	p.append(("box", (32, 3, 26), (88, 14, 0), "4A4C50", {"rot": (0, 0, -32)}))
	p.append(("box", (32, 2.5, 1.6), (88, 12.5, -8), "3A3C40", {"rot": (0, 0, -32)}))
	_rebar(p, 75, 21, 0, 8, rng, spread=10)
	for i in range(8):
		s = rng.uniform(4, 8)
		p.append(("box", (s, s * 0.6, s * 1.2), (rng.uniform(88, 110), -s * 0.2 - 2, rng.uniform(-12, 12)), "5A5C60", {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	return k.prop("Overpass", p)


def _midrise_apartment(k, rng):
	"""Grey mid-rise apartments: window grid, balconies with railings, AC units, shutters, rooftop tank, stair core."""
	w, d, g, fh, floors = 30, 18, 9, 9, 6
	h = g + floors * fh
	p = [("box", (w, h, d), (0, h / 2, 0), CONC2)]
	_grid(p, "z", 0, -d / 2, w, g, floors, fh, 5, rng, frame="A8ACAE", broken=0.25)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 2, rng, frame="A8ACAE", broken=0.2)
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w, 0.7, 3), (0, y + 0.2, -d / 2 - 1.5), "C4C6C4"))
		p.append(("box", (w, 1.8, 0.3), (0, y + 1.3, -d / 2 - 2.9), "B8BEC4", {"rough": 0.4}))
		p.append(("box", (w, 0.35, 0.35), (0, y + 3.4, -d / 2 - 2.9), STEEL))
		for x in (-w / 2 + 0.3, -5, 5, w / 2 - 0.3):
			p.append(("box", (0.35, 3.2, 0.35), (x, y + 1.8, -d / 2 - 2.9), STEEL))
		for x in (-9, 3):
			if rng.random() < 0.7:
				p.append(("box", (2.6, 2.0, 1.2), (x + rng.uniform(-2, 2), y + 1.4, -d / 2 - 1.8), "D9D6CE"))
	for i, x in enumerate((-10, 0, 10)):
		p.append(("box", (8.5, 6.5, 0.4), (x, 3.25, -d / 2 - 0.2), DARK if i == 1 else "8E9096", {"metal": 0.3}))
		if i != 1:
			for j in range(4):
				p.append(("box", (8.5, 0.25, 0.5), (x, 1 + j * 1.5, -d / 2 - 0.25), "6E7076"))
	p.append(("box", (w, 0.6, 2.5), (0, g - 1.5, -d / 2 - 1.25), "C4C6C4"))
	_roof(p, w, d, h)
	_tank(p, w / 2 - 5, h, 0)
	for _ in range(4):
		_crack(p, "z", 0, -d / 2 - 0.4, rng.uniform(-12, 12), rng.uniform(15, 50), rng.uniform(5, 10), rng.uniform(-40, 40))
	return k.prop("MidRise", p)


def _office_damaged(k, rng):
	"""Beige office block with its top corner torn off: broken floor slabs, rebar, a punched hole, cracks."""
	w, d, g, fh = 28, 22, 9, 9
	hl, hr = g + 8 * fh, g + 4 * fh
	p = [("box", (16, hl, d), (-6, hl / 2, 0), BEIGE), ("box", (12, hr, d), (8, hr / 2, 0), BEIGE)]
	_grid(p, "z", -6, -d / 2, 16, g, 8, fh, 3, rng, broken=0.35)
	_grid(p, "z", 8, -d / 2, 12, g, 4, fh, 2, rng, broken=0.5)
	_grid(p, "x-", -w / 2, 0, d - 4, g, 8, fh, 3, rng, broken=0.3)
	_grid(p, "x+", w / 2, 0, d - 4, g, 4, fh, 3, rng, broken=0.4)
	for fl in range(4, 8):  # torn floors: slabs sticking out of the left part over the gap
		y = g + fl * fh
		ln = rng.uniform(4, 10)
		p.append(("box", (ln, 0.9, d - 2), (2 + ln / 2, y, rng.uniform(-1, 1)), "C8B898", {"rot": (0, 0, rng.uniform(-14, 6))}))
		p.append(("box", (0.9, fh - 1, 0.9), (1.5, y + fh / 2, -d / 2 + 1), "B8A888"))
		_rebar(p, 2 + ln, y, 0, 2, rng, spread=6)
	p.append(("wedge", (12, 7, d), (8, hr + 3.5, 0), "C8B898", {"rot": (0, 90, 0)}))
	_rebar(p, 8, hr + 4, 0, 4, rng, spread=5)
	p.append(("box", (7, 8, 0.6), (-8, g + 4.5 * fh, -d / 2 - 0.4), "1E1C1A"))
	for dx, dy, r in ((-11.5, 0, 20), (-4.5, 1, -15), (-8, 4.3, 80), (-8, -4.2, 95)):
		p.append(("box", (2.5, 1.2, 1.2), (dx, g + 4.5 * fh + dy, -d / 2 - 0.8), BEIGE, {"rot": (0, 0, r)}))
	for _ in range(5):
		_crack(p, "z", 0, -d / 2 - 0.4, rng.uniform(-12, 12), rng.uniform(12, 60), rng.uniform(6, 14), rng.uniform(-50, 50))
	p.append(("box", (16, 2, d), (-6, hl + 1, 0), TAN))
	_tank(p, -10, hl + 2, 3, 0.9)
	for i in range(6):
		s = rng.uniform(3, 6)
		p.append(("box", (s, s * 0.7, s), (rng.uniform(4, 16), s * 0.3, rng.uniform(-d / 2 - 8, -d / 2 - 2)), ("C8B898", BEIGE, CONC)[i % 3], {"rot": (rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25))}))
	return k.prop("OfficeBroken", p)


def _highrise(k, rng):
	"""Empty grey high-rise: curtain grid on three faces, corner fins, lobby canopy, setback crown, roof plant, mast."""
	w, d, g, fh, floors = 34, 30, 12, 9, 16
	h = g + floors * fh
	p = [("box", (w, h, d), (0, h / 2, 0), "7E8790")]
	_grid(p, "z", 0, -d / 2, w - 4, g, floors, fh, 6, rng, glass=GLASS2, frame="8E969E", broken=0.2)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 5, rng, glass=GLASS2, frame="8E969E", broken=0.15)
	for x in (-w / 2, w / 2):
		for z in (-d / 2, d / 2):
			p.append(("box", (2.4, h, 2.4), (x, h / 2, z), "A4AAB0"))
	p.append(("box", (w - 6, g - 2, 0.4), (0, (g - 2) / 2, -d / 2 - 0.2), "1E2630", {"rough": 0.2}))
	p.append(("box", (w + 2, 1, 6), (0, g - 1.5, -d / 2 - 3), "C0C4C8"))
	p.append(("box", (w - 8, 12, d - 8), (0, h + 6, 0), "7E8792"))
	p.append(("box", (w - 6, 1, d - 6), (0, h + 12.5, 0), "C0C4C8"))
	for x, z, s in ((-8, -4, 5), (6, 5, 6), (-2, 7, 4)):
		p.append(("box", (s, 3, s), (x, h + 14.5, z), STEEL))
	p.append(("cyl", (1.2, 30, 1.2), (6, h + 28, -4), "C04A3A", {"seg": 6}))
	p.append(("ball", (1.6, 1.6, 1.6), (6, h + 43.5, -4), "FF4A3A", {"emit": 3, "subdiv": 1}))
	for _ in range(3):
		_crack(p, "z", 0, -d / 2 - 0.5, rng.uniform(-12, 12), rng.uniform(20, 120), rng.uniform(8, 16), rng.uniform(-40, 40))
	return k.prop("HighRise", p)


def _collapsed(k, rng):
	"""Half-collapsed high-rise: a grid shaft, then exposed floor slabs on stub columns, a tilted top slab, rebar,
	a fallen chunk leaning on the foot and rubble."""
	w, d, g, fh = 32, 28, 9, 9
	hs = g + 9 * fh
	p = [("box", (w, hs, d), (0, hs / 2, 0), CONC)]
	_grid(p, "z", 0, -d / 2, w - 2, g, 9, fh, 5, rng, broken=0.55)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, 9, fh, 4, rng, broken=0.5)
	for j in range(3):  # exposed floors, each a little smaller, with stub columns between
		y = hs + j * fh
		cut = j * 5
		p.append(("box", (w - cut, 1, d - cut * 0.6), (-cut / 2, y + fh, 0), "A8A49C", {"rot": (rng.uniform(-3, 3), 0, rng.uniform(-4, 4))}))
		for x in (-w / 2 + 1.5, -2, w / 2 - 1.5 - cut):
			for z in (-d / 2 + 1.5, d / 2 - 1.5):
				if rng.random() < 0.75:
					p.append(("box", (1.4, fh, 1.4), (x, y + fh / 2, z), "C0BCB4"))
		_rebar(p, w / 2 - cut, y + fh, 0, 3, rng, spread=8)
	p.append(("box", (w * 0.7, 1.2, d * 0.8), (-6, hs + 3 * fh + 4, 2), "A8A49C", {"rot": (8, 10, 22)}))
	p.append(("box", (20, 44, 14), (w / 2 + 6, 16, -6), CONC, {"rot": (6, 20, -22)}))
	p.append(("box", (16, 30, 0.4), (w / 2 + 2, 16, -13.2), GLASS, {"rot": (6, 20, -22)}))
	_rebar(p, w / 2 + 10, 34, -6, 5, rng)
	for i in range(8):
		s = rng.uniform(3, 8)
		p.append(("box", (s, s * 0.6, s), (rng.uniform(-w / 2, w / 2 + 12), s * 0.2, rng.uniform(-d / 2 - 10, -d / 2 - 2)), (CONC, "A8A49C", CONC2)[i % 3], {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	return k.prop("Collapsed", p)


def _barricade(k, rng):
	"""Evacuation cordon (ref Z-City_Ghost_Town_Anime_Profile): chain-link fence with barbed wire, a yellow-black
	barrier in front, a blank red-and-white warning board (no text) and cones. Runs along the road (local X)."""
	L = 36
	p = [("box", (L, 9, 0.12), (0, 5, 0), "9AA0A4", {"alpha": 0.35, "metal": 0.5})]
	for i in range(7):
		x = -L / 2 + i * L / 6
		p.append(("cyl", (0.5, 10.5, 0.5), (x, 5.25, 0), STEEL, {"seg": 6, "metal": 0.5}))
		p.append(("box", (0.25, 2, 0.25), (x, 11, -0.6), STEEL, {"rot": (-35, 0, 0)}))
	for y in (0.6, 9.6):
		p.append(("cyl", (0.35, L, 0.35), (0, y, 0), STEEL, {"seg": 6, "rot": (0, 0, 90)}))
	for zz in (-0.9, -1.4):
		p.append(("cyl", (0.15, L, 0.15), (0, 11.4 + zz * 0.4, zz), "6A6A66", {"seg": 4, "rot": (0, 0, 90)}))
	for x in (-12, 12):  # barrier: two legs, a striped beam
		for dx in (-4.8, 4.8):
			p.append(("box", (0.5, 3.4, 2.2), (x + dx, 1.7, -4), "D8D4C8"))
		for j in range(8):
			p.append(("box", (1.25, 1.3, 0.5), (x - 4.4 + j * 1.25, 2.9, -4), ("F2C230", "222222")[j % 2]))
	p.append(("box", (0.4, 9, 0.4), (3, 4.5, -2.4), STEEL))
	p.append(("box", (4.4, 7.6, 0.3), (3, 6.6, -2.7), "F2F0EA"))
	p.append(("box", (4.4, 1.8, 0.35), (3, 9.5, -2.75), "C8202A"))
	for x in (-2.5, 8, 18.5):
		p.append(("cone", (1.8, 3.2, 1.8), (x, 1.6, -6.5), "F06A1A", {"seg": 8}))
		p.append(("cyl", (1.25, 0.5, 1.25), (x, 2.0, -6.5), "F2F0EA", {"seg": 8}))
		p.append(("box", (2.2, 0.3, 2.2), (x, 0.15, -6.5), "F06A1A"))
	return k.prop("Barricade", p)


def _pole(k, rng):
	"""Japanese concrete utility pole: crossarms with insulators, a transformer drum, step bolts, a street lamp arm
	toward the road, wire stubs, and a blank red hydrant marker disc on its own post (no text)."""
	p = [("cyl", (1.5, 42, 1.5), (0, 21, 0), "A4A49C", {"seg": 8, "taper": 0.7}), ("box", (2.4, 1, 2.4), (0, 0.5, 0), "8E8E86")]
	for y in (36, 39.5):
		p.append(("box", (11, 0.6, 0.6), (0, y, 0), "6E6E66"))
		for x in (-4.5, -1.5, 1.5, 4.5):
			p.append(("cyl", (0.5, 1.0, 0.5), (x, y + 0.8, 0), "E8E8E0", {"seg": 6}))
	p.append(("cyl", (2.6, 4.2, 2.6), (0, 30, 1.8), "8E9496", {"seg": 10}))
	p.append(("box", (0.4, 1, 2), (0, 32.4, 0.9), "6E6E66"))
	for i in range(8):
		p.append(("box", (1.4, 0.2, 0.2), (0, 12 + i * 2.2, 0), "6E6E66", {"rot": (0, (i % 2) * 90, 0)}))
	p.append(("box", (0.4, 0.4, 7), (0, 26, -3.6), "6E6E66", {"rot": (-12, 0, 0)}))
	p.append(("box", (1.8, 0.7, 2.6), (0, 26.4, -7), "D8D4C8"))
	p.append(("box", (1.4, 0.2, 2), (0, 26.0, -7), "FFF2C8", {"emit": 0.6}))
	for x in (-4.5, 1.5, 4.5):
		p.append(("cyl", (0.15, 14, 0.15), (x + (7 if x > 0 else -7), 38, 0), "2A2A2A", {"seg": 4, "rot": (0, 0, 82 if x > 0 else -82)}))
	p.append(("cyl", (0.5, 9, 0.5), (3, 4.5, -2.5), "C8202A", {"seg": 6}))
	p.append(("cyl", (2.6, 0.3, 2.6), (3, 9.6, -2.5), "C8202A", {"seg": 12, "rot": (90, 0, 0)}))
	p.append(("cyl", (2.0, 0.32, 2.0), (3, 9.6, -2.5), "F2F0EA", {"seg": 12, "rot": (90, 0, 0)}))
	p.append(("box", (2.6, 1.0, 0.25), (3, 7.6, -2.6), "F2F0EA"))
	return k.prop("UtilityPole", p)


def _rubble(k, rng):
	"""Rubble heap: concrete chunks, cracked slabs, rebar, a broken pipe and a crushed dusty car."""
	p = []
	for j in range(11):
		s = rng.uniform(2.5, 7)
		p.append(("box", (s, s * 0.7, s * 1.2), (rng.uniform(-8, 6), s * 0.3, rng.uniform(-4, 6)), (CONC, CONC2, BEIGE, "A8A398")[j % 4], {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	for j in range(3):
		p.append(("box", (9, 0.8, 7), (rng.uniform(-6, 6), 1.2, rng.uniform(-2, 4)), "A8A398", {"rot": (rng.uniform(-18, 18), rng.uniform(0, 90), rng.uniform(-18, 18))}))
	_rebar(p, -2, 1, 1, 6, rng, spread=5)
	p.append(("cyl", (1.6, 10, 1.6), (4, 1.2, 6), "7E7A74", {"seg": 8, "rot": (0, 30, 80)}))
	cx, cz = 10, -3  # crushed car
	p += [
		("box", (6, 2.2, 12), (cx, 1.6, cz), "6E7F8E", {"metal": 0.3, "rough": 0.5}),
		("box", (5.4, 1.0, 5), (cx, 3.0, cz + 1), "55636E", {"rot": (4, 0, 6)}),
		("box", (5.4, 1.2, 0.3), (cx, 3.0, cz - 1.8), "28323A", {"rough": 0.2, "rot": (40, 0, 0)}),
		("box", (6.2, 0.8, 0.5), (cx, 1.2, cz - 6.1), "3A3A3A"),
		("box", (1.2, 0.6, 0.3), (cx - 2, 1.9, cz - 6.2), "E8E4D0"),
		("box", (1.2, 0.6, 0.3), (cx + 2, 1.9, cz - 6.2), "E8E4D0"),
		("box", (6, 2.5, 4), (cx + 1, 4.5, cz + 2), CONC2, {"rot": (14, 25, -10)}),
	]
	for x, z in ((-3, -4), (3, -4), (-3, 4), (3, 4)):
		p.append(("cyl", (2, 1, 2), (cx + x, 0.9, cz + z), DARK, {"seg": 8, "rot": (0, 0, 90)}))
	return k.prop("Rubble", p)


def _tree(k, rng):
	"""Overgrown street tree in a square curbed pit (refs: trees line the ghost-town streets)."""
	p = [("cyl", (1.6, 14, 1.6), (0, 7, 0), "5A4636", {"seg": 7, "taper": 0.7}), ("cyl", (0.8, 7, 0.8), (1.6, 13, 0), "5A4636", {"seg": 6, "rot": (0, 0, -35)}), ("cyl", (0.8, 6, 0.8), (-1.4, 12, 0.6), "5A4636", {"seg": 6, "rot": (20, 0, 35)})]
	for x, y, z, s, c in ((0, 17, 0, 10, "4E6B3A"), (4, 15, 1, 7, "5E7E44"), (-4, 15, -1, 7, "445E32"), (1, 20, -2, 6, "5E7E44"), (-1, 14, 3.5, 6, "4E6B3A")):
		p.append(("ball", (s, s * 0.8, s), (x, y, z), c, {"subdiv": 1, "smooth": True}))
	for sx, sz, x, z in ((6, 0.5, 0, -2.75), (6, 0.5, 0, 2.75), (0.5, 6, -2.75, 0), (0.5, 6, 2.75, 0)):
		p.append(("box", (sx, 0.8, sz), (x, 0.4, z), "B8B6AE"))
	return k.prop("Tree", p)


def _crater(k, rng):
	"""Hero, infield: the meteor crater (City A/Z damage): upturned asphalt plates on the rim, a scorched stepped bowl,
	radial ground cracks, buried building stumps and the glowing meteor core."""
	p = [("cyl", (330, 0.6, 330), (0, 0.3, 0), "5A5048", {"seg": 32}), ("cyl", (250, 1.2, 250), (0, 0.6, 0), SCORCH, {"seg": 28}), ("cyl", (150, 1.8, 150), (0, 0.9, 0), "2A231E", {"seg": 24})]
	for a in range(40):  # upturned rim plates: asphalt on top, concrete edge under it
		ang = a * math.tau / 40 + rng.uniform(-0.03, 0.03)
		r = 132 + rng.uniform(-6, 6)
		tilt = rng.uniform(30, 58)
		x, z = math.cos(ang) * r, math.sin(ang) * r
		p.append(("box", (24, 2.2, 18), (x, 6, z), ASPH, {"rot": (0, -math.degrees(ang), tilt)}))
		p.append(("box", (24, 1.6, 18), (math.cos(ang) * (r + 1.2), 5, math.sin(ang) * (r + 1.2)), (TAN, "8C7A62", BEIGE)[a % 3], {"rot": (0, -math.degrees(ang), tilt)}))
		if a % 4 == 0:
			p.append(("box", (2, 0.2, 0.4), (x, 10, z), "D8D2C0", {"rot": (0, -math.degrees(ang) + 90, tilt)}))
	for a in range(18):  # radial cracks beyond the rim
		ang = a * math.tau / 18 + 0.1
		ln = rng.uniform(40, 80)
		r = 150 + ln / 2
		p.append(("box", (ln, 0.4, 1.2), (math.cos(ang) * r, 0.7, math.sin(ang) * r), "2A2420", {"rot": (0, -math.degrees(ang) + rng.uniform(-8, 8), 0)}))
	for a in range(9):  # buried building stumps with window bands
		ang = a * math.tau / 9 + 0.3
		r = rng.uniform(70, 105)
		x, z = math.cos(ang) * r, math.sin(ang) * r
		hh = rng.uniform(16, 34)
		rot = (rng.uniform(-28, 28), a * 23, rng.uniform(-28, 28))
		p.append(("box", (14, hh, 14), (x, hh * 0.35, z), (CONC2, BEIGE, CONC)[a % 3], {"rot": rot}))
		p.append(("box", (14.4, 2.5, 14.4), (x, hh * 0.35, z), GLASS, {"rot": rot}))
	for j in range(9):  # meteor core: charred rock with glowing seams
		p.append(("ball", (rng.uniform(16, 28), rng.uniform(12, 20), rng.uniform(16, 26)), (rng.uniform(-24, 24), 6, rng.uniform(-24, 24)), ("4A3E36", "3A302A")[j % 2], {"subdiv": 1}))
	for j in range(10):
		p.append(("box", (rng.uniform(6, 14), 0.6, 0.8), (rng.uniform(-26, 26), rng.uniform(8, 14), rng.uniform(-26, 26)), "FF7A2A", {"emit": 3, "rot": (rng.uniform(-30, 30), rng.uniform(0, 180), rng.uniform(-30, 30))}))
	return k.prop("Crater", p)


def _clear_side_shot(k):
	"""Keep the raised side review camera (build_track.shots, 48% along, 140 right) out of the buildings."""
	p, right, t = k.at(k.length * 0.48)
	eye = p + right * 140 - t * 60
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.name.startswith("W2_%s_" % k.biome) and ob.name.split("_")[2] in ("HighRise", "Collapsed", "MidRise", "OfficeBroken", "SaitamaApt"):
			x, z = ob.location.x, -ob.location.y  # Blender back to Roblox XZ
			if math.hypot(x - eye.x, z - eye.z) < 45:
				k.col.objects.unlink(ob)


def build(k):
	rng = k.rng
	_saitama_apartment(k, rng)
	_hero_hq(k, rng)
	_overpass(k, rng)
	_midrise_apartment(k, rng)
	_office_damaged(k, rng)
	_highrise(k, rng)
	_collapsed(k, rng)
	_barricade(k, rng)
	_pole(k, rng)
	_rubble(k, rng)
	_tree(k, rng)
	_crater(k, rng)

	k.ground("7A746A", margin=900)
	_fill(k, "4A4744")
	L = k.length
	# Kerb line: poles, trees, rubble and the cordon fences right outside the road walls
	_row(k, 44, 29, ["UtilityPole"], jitter=1, start=20, clear=25)
	_row(k, 52, 33, ["Rubble", "Tree", "Barricade", "Tree", "Rubble"], jitter=2, start=42, clear=26)
	# Street walls: apartments and offices, then high-rises behind
	_row(k, 40, 58, ["MidRise", "OfficeBroken", "MidRise", "Collapsed"], jitter=3, start=30)
	_row(k, 62, 108, ["MidRise", "Collapsed", "HighRise", "OfficeBroken"], jitter=8, start=20)
	_row(k, 105, 175, ["HighRise", "OfficeBroken", "Collapsed"], jitter=15, start=50, scale=(1.0, 1.5), yaw_jit=0.4)
	# The hero's apartment where the runner's camera sees it (start, a third in, the last stretch)
	for f, off in ((0.06, 46), (0.33, -46), (0.62, 46), (0.9, -46)):
		_put(k, "SaitamaApt", L * f + 55, off)
	# Expressway crossings on flat straights, piers clear of every lap
	for f in (0.14, 0.34, 0.63):
		for step in range(20):
			d = L * f + 60 + step * 15
			p0, _, _ = k.at(d - 40)
			p1, _, _ = k.at(d + 40)
			pos, yaw = k.beside(d, 0, 1.0)
			_, right, _ = k.at(d)
			piers = [(pos[0] + right.x * s, pos[2] + right.z * s) for s in (-42, 42, 90)]
			if abs(p0.y - p1.y) < 0.5 and all(k.clear_of_road(x, z, 26) for x, z in piers):
				k.place("Overpass", pos, yaw)  # local X runs across the road
				break
	# The crater in the infield; the infield and the outskirts fill with ruins, away from its bowl
	c = (k.lo + k.hi) / 2
	k.place("Crater", (c.x, -1.0, c.z), 0.3, 1.3)
	for count, names, clearance, margin, scale in (
		(70, ["Rubble", "Rubble", "Tree", "UtilityPole"], 50, 300, (0.8, 1.5)),
		(45, ["HighRise", "Collapsed", "MidRise", "OfficeBroken", "MidRise", "OfficeBroken"], 130, 600, (0.9, 1.3)),
	):
		placed, tries = 0, 0
		while placed < count and tries < count * 30:
			tries += 1
			x = rng.uniform(k.lo.x - margin, k.hi.x + margin)
			z = rng.uniform(k.lo.z - margin, k.hi.z + margin)
			if math.hypot(x - c.x, z - c.z) > 240 and k.clear_of_road(x, z, clearance):
				k.place(rng.choice(names), (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(*scale))
				placed += 1
	# Hero Association HQ on the horizon, beyond the far side of the city
	# straight ahead of the runner a third of the way in, far outside the city
	p, _, t = k.at(k.length * 0.33)
	q = p.copy()
	while k.lo.x - 250 < q.x < k.hi.x + 250 and k.lo.z - 250 < q.z < k.hi.z + 250:
		q += t * 20
	q += t * 450
	k.place("HeroHQ", (q.x, -1.0, q.z), 0.4, 1.6)
	_clear_side_shot(k)
	k.sky([(0.0, "E6E2D6"), (0.07, "C9D6DE"), (0.3, "8FB8DE"), (1.0, "3C78C4")], strength=1.0, sun=(4.2, "FFF0D8", 48, 150))
