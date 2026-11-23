"""World 2 Track 3: City Z, ruined (One Punch). The abandoned ghost-town district of City Z in bright, hazy daylight,
rebuilt 1-1 toward the anime (refs: docs/world2_refs/RuinedCityZ.md):
- the hero's apartment block, one unique landmark at the start: a deep brown-brick balcony stack with a round-fan AC
  unit on every balcony, a huge blank warm-grey end wall with darker square patches and dark bolt dots, a roof railing,
  street shutters behind a low brown railing fence;
- weathered warm-grey high-rises and mid-rises with window grids on every face, rain streaks and patches, smashed black
  panes with jagged frame bits, boarded shutters, some torn open or half-collapsed with exposed floors and rebar;
- the dark elevated expressway crossing the ghost town: heavy girdered underside, square piers, chain-link fence below,
  broken off at one end;
- the evacuation cordon: chain-link fence with coiled barbed wire, a yellow-black barrier, a tall white board with a red
  header band (no text), cones;
- kerb sets: Japanese concrete utility poles strung with wires, transformers, street lamps, vending machines, trees;
- city blocks: sidewalks, kerbs and crossings laid in a street grid over the asphalt plain;
- the meteor crater in the infield (City A/Z damage): a raised rim of tilted asphalt slabs around a scorched bowl,
  ground cracks, buried stumps; and the Hero Association HQ filling the skyline: a near-black ribbed sloped hull, a
  stepped tower cluster peaking in the middle, highways on piers (no emblem).
The route slopes are filled from the ground (TrackBuilder's hill supports). No signs with text, no logos (design doc 5).
Everything in-house, parts only. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

from mathutils import Vector

CONC, CONC2, BEIGE, TAN = "A39C92", "8C877F", "BFAE92", "9E7A5A"
GLASS, GLASS2, DARK, FRAME = "36424C", "42505C", "141312", "9C968C"
BRICK, BRICK2, RUST, SCORCH = "7A4A36", "5E382A", "7A4A2E", "2E2620"
STAIN, STAIN2, BOARD = "6E665C", "5A544C", "7A5E3E"
ASPH, STEEL, HQ, HQ2, HQGLASS = "3E3C3A", "6E7276", "1C2026", "2C323A", "222C38"

MODEL_SHOTS = ["SaitamaApt", "HeroHQ", "Crater", "Overpass"]  # hero models rendered close up by build_track


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


# --- local part helpers (Roblox local space: Y up, -Z is the face toward the road) ---
def _f(face, cx, cz, u, n, y, su, sy, sn):
	"""Size and centre of a slab on a wall: u along the wall, n out of it. face z (the -Z front), z+, x+ or x-."""
	if face in ("z", "z+"):
		return (su, sy, sn), (cx + u, y, cz + (n if face == "z+" else -n))
	s = 1 if face == "x+" else -1
	return (sn, sy, su), (cx + s * n, y, cz + u)


def _add(parts, face, cx, cz, u, n, y, su, sy, sn, col, o=None):
	size, pos = _f(face, cx, cz, u, n, y, su, sy, sn)
	parts.append(("box", size, pos, col, o or {}))


def _grid(parts, face, cx, cz, w, y0, floors, fh, cols, rng, glass=GLASS, frame=FRAME, broken=0.0, boarded=0.0):
	"""Window grid: one glass sheet, spandrel bands per floor and mullions over it; smashed panes are black with jagged
	frame bits, boarded panes get planks."""
	h = floors * fh
	cw = w / cols
	_add(parts, face, cx, cz, 0, 0.15, y0 + h / 2, w - 1, h, 0.3, glass, {"rough": 0.3, "metal": 0.2})
	for fl in range(floors + 1):
		_add(parts, face, cx, cz, 0, 0.5, y0 + fl * fh, w, fh * 0.32, 0.8, frame)
	for i in range(cols + 1):
		_add(parts, face, cx, cz, -w / 2 + i * cw, 0.45, y0 + h / 2, 0.8, h, 0.7, frame)
	for fl in range(floors):
		for i in range(cols):
			u, y = -w / 2 + (i + 0.5) * cw, y0 + (fl + 0.5) * fh
			r = rng.random()
			if r < broken:
				_add(parts, face, cx, cz, u, 0.35, y, cw - 1.2, fh * 0.62, 0.3, DARK)
				size, pos = _f(face, cx, cz, u - cw * 0.2, 0.5, y + fh * 0.18, cw * 0.4, 0.5, 0.3)
				parts.append(("box", size, pos, frame, {"rot": (0, 0, 28) if face[0] == "z" else (28, 0, 0)}))
			elif r < broken + boarded:
				for dy in (-1.2, 0.4, 2.0):
					_add(parts, face, cx, cz, u, 0.55, y + dy - 0.4, cw - 1.0, 1.0, 0.3, BOARD)


def _stains(parts, face, cx, cz, w, y0, h, rng, n=6, patches=3):
	"""Weathering: rain streaks running down from the roof line and darker patches."""
	for _ in range(n):
		ln = rng.uniform(h * 0.2, h * 0.6)
		_add(parts, face, cx, cz, rng.uniform(-w / 2 + 2, w / 2 - 2), 0.62, y0 + h - ln / 2, rng.uniform(1, 3.5), ln, 0.2, STAIN)
	for _ in range(patches):
		s = rng.uniform(4, 9)
		_add(parts, face, cx, cz, rng.uniform(-w / 2 + s, w / 2 - s), 0.6, rng.uniform(y0 + s, y0 + h - s), s, s * rng.uniform(0.8, 1.6), 0.2, STAIN2)


def _crack(parts, face, cx, cz, u, y, length, ang):
	"""A dark crack line on a wall."""
	size, pos = _f(face, cx, cz, u, 0.7, y, 0.5, length, 0.3)
	rot = (0, 0, ang) if face[0] == "z" else (ang, 0, 0)
	parts.append(("box", size, pos, "2A2622", {"rot": rot}))


def _rebar(parts, x, y, z, n, rng, spread=3.0):
	for _ in range(n):
		parts.append(("box", (0.35, rng.uniform(4, 9), 0.35), (x + rng.uniform(-spread, spread), y + 2.5, z + rng.uniform(-spread, spread)), RUST, {"rot": (rng.uniform(-35, 35), 0, rng.uniform(-35, 35)), "metal": 0.4}))


def _tank(parts, x, y, z, s=1.0):
	"""Rooftop water tank on a steel stand."""
	for dx in (-1.6, 1.6):
		for dz in (-1.6, 1.6):
			parts.append(("box", (0.4, 3 * s, 0.4), (x + dx * s, y + 1.5 * s, z + dz * s), STEEL))
	parts.append(("cyl", (5 * s, 5 * s, 5 * s), (x, y + 5.5 * s, z), "A8A296", {"seg": 10}))
	parts.append(("cyl", (5.4 * s, 0.4, 5.4 * s), (x, y + 8.2 * s, z), "6E6A64", {"seg": 10}))


def _roof(parts, w, d, h, col=CONC2):
	"""Roof parapet and a stair core with its door."""
	for (sx, sz, x, z) in ((w, 0.8, 0, -d / 2 + 0.4), (w, 0.8, 0, d / 2 - 0.4), (0.8, d, -w / 2 + 0.4, 0), (0.8, d, w / 2 - 0.4, 0)):
		parts.append(("box", (sx, 2, sz), (x, h + 1, z), col))
	parts.append(("box", (7, 7, 6), (-w / 2 + 5, h + 3.5, d / 2 - 4.5), col))
	parts.append(("box", (2.4, 4.5, 0.3), (-w / 2 + 5, h + 2.25, d / 2 - 7.6), DARK))


def _saitama_apartment(k, rng):
	"""Hero: the hero's apartment block (anime ep. 1, refs Saitamas_Apartment_Anime, _at_night). Street face -Z: the
	brick balcony stack; both end walls (+-X) are the huge blank stained concrete walls."""
	w, d, g, fh, floors = 26, 34, 10, 9, 8
	h = g + floors * fh
	wall = "9A9388"
	p = [("box", (w, h, d), (0, h / 2, 0), wall)]
	# Street face (-Z): deep brick balcony stack, three units per floor, a round-fan AC unit on every balcony
	p.append(("box", (w, h - g, 0.3), (0, g + (h - g) / 2, -d / 2 - 0.15), BRICK2))
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w + 0.8, 1.0, 5.4), (0, y, -d / 2 - 2.7), "8A8278"))
		for x in (-13, -4.33, 4.33, 13):
			p.append(("box", (0.9, fh, 5.4), (x, y + fh / 2, -d / 2 - 2.7), BRICK))
		for ux in (-8.67, 0, 8.67):
			p.append(("box", (7.6, 3.8, 0.9), (ux, y + 2.4, -d / 2 - 5.0), BRICK))
			p.append(("box", (7.8, 0.4, 1.1), (ux, y + 4.4, -d / 2 - 5.0), "9A8A78"))
			p.append(("box", (4.4, 6.6, 0.3), (ux - 1.4, y + 3.8, -d / 2 - 0.35), "262A2E", {"rough": 0.3}))
			p.append(("box", (3.0, 2.4, 1.4), (ux + 2.2, y + 1.7, -d / 2 - 3.6), "D2CEC4"))
			p.append(("cyl", (2.1, 0.3, 2.1), (ux + 2.2, y + 1.7, -d / 2 - 4.35), "4A4A48", {"seg": 12, "rot": (90, 0, 0)}))
			p.append(("cyl", (0.6, 0.35, 0.6), (ux + 2.2, y + 1.7, -d / 2 - 4.45), "2A2A28", {"seg": 6, "rot": (90, 0, 0)}))
	# Ground floor: rolled shutters with grooves, one boarded, entrance with a canopy, wall lamps
	for x, boarded in ((-8, False), (0, True)):
		p.append(("box", (7.5, 7.5, 0.4), (x, 3.75, -d / 2 - 0.2), "7E8086", {"metal": 0.3}))
		for i in range(7):
			p.append(("box", (7.5, 0.25, 0.5), (x, 0.8 + i * 1, -d / 2 - 0.25), "5E6066"))
		if boarded:
			for dy, r in ((2.5, 18), (5, -14)):
				p.append(("box", (8.2, 1, 0.4), (x, dy, -d / 2 - 0.6), BOARD, {"rot": (0, 0, r)}))
	p.append(("box", (5, 7.5, 0.4), (8, 3.75, -d / 2 - 0.2), DARK))
	p.append(("box", (8, 0.5, 3.4), (8, 8, -d / 2 - 1.7), "8A8278"))
	for x in (-10, -5, 0):
		p.append(("box", (1.0, 0.6, 0.6), (x, 8.6, -d / 2 - 0.5), "E8E4D0", {"emit": 0.4}))
	# Low brown railing fence in front of the shutters, shrubs behind it
	p.append(("box", (w + 2, 2.0, 1), (0, 1.0, -d / 2 - 8), "8E8A82"))
	for i in range(15):
		p.append(("box", (0.3, 3.2, 0.3), (-w / 2 + i * w / 14, 3.6, -d / 2 - 8), "4A3426"))
	for y in (3.0, 5.2):
		p.append(("box", (w + 2, 0.35, 0.35), (0, y, -d / 2 - 8), "4A3426"))
	for x in (-9, 2, 10):
		p.append(("ball", (3.4, 2.6, 3.0), (x, 3.4, -d / 2 - 6), "4E6B3A", {"subdiv": 1, "smooth": True}))
	# Blank end walls: darker square patches, panel seams, dark bolt dots, rain streaks, a drain pipe
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		for _ in range(7):
			pw = rng.uniform(6, 11)
			_add(p, face, cx, 0, rng.uniform(-d / 2 + pw / 2 + 1, d / 2 - pw / 2 - 1), 0.12, rng.uniform(g + pw, h - pw), pw, pw * rng.uniform(0.9, 1.3), 0.24, rng.choice(("847C72", "8C857A", "7A7268")))
		for fl in range(1, floors + 1):
			_add(p, face, cx, 0, 0, 0.18, g + fl * fh, d, 0.35, 0.3, "7E776C")
		for fl in range(floors):
			for u in (-11, -3.5, 3.5, 11):
				_add(p, face, cx, 0, u, 0.32, g + fl * fh + 5, 0.9, 0.9, 0.6, "2E2C28")
		_stains(p, face, cx, 0, d, g, h - g, rng, n=7, patches=0)
	p.append(("cyl", (0.9, h, 0.9), (w / 2 + 0.6, h / 2, -d / 2 + 1), "5E5E5A", {"seg": 6}))
	_grid(p, "z+", 0, d / 2, w - 4, g, floors, fh, 4, rng, broken=0.2)
	# Roof: parapet, railing posts and rail all round, water tank, stair core, antenna
	_roof(p, w, d, h, wall)
	for sx, sz, x, z in ((w, 0.3, 0, -d / 2 + 0.6), (w, 0.3, 0, d / 2 - 0.6), (0.3, d, -w / 2 + 0.6, 0), (0.3, d, w / 2 - 0.6, 0)):
		p.append(("box", (sx, 0.3, sz), (x, h + 5, z), STEEL))
	for i in range(10):
		p.append(("box", (0.25, 3, 0.25), (-w / 2 + 0.6 + i * (w - 1.2) / 9, h + 3.5, -d / 2 + 0.6), STEEL))
		p.append(("box", (0.25, 3, 0.25), (w / 2 - 0.6, h + 3.5, -d / 2 + 0.6 + i * (d - 1.2) / 9), STEEL))
		p.append(("box", (0.25, 3, 0.25), (-w / 2 + 0.6, h + 3.5, -d / 2 + 0.6 + i * (d - 1.2) / 9), STEEL))
	_tank(p, w / 2 - 5, h, 6)
	p.append(("cyl", (0.3, 9, 0.3), (2, h + 4.5, 8), STEEL, {"seg": 6}))
	p.append(("box", (5, 0.3, 0.3), (2, h + 8, 8), STEEL))
	return k.prop("SaitamaApt", p)


def _hero_hq(k, rng):
	"""Hero, skyline: the Hero Association HQ (refs New_Hero_Association_Headquarters_Anime, Hero_Association_HQ): a
	stepped cluster of near-black towers peaking in the middle on a ribbed sloped hull over a round base, highways on
	piers radiating out. No emblem."""
	p = [
		("cyl", (520, 4, 520), (0, 2, 0), "3A3E44", {"seg": 32}),
		("cyl", (420, 18, 420), (0, 9, 0), HQ, {"seg": 32}),
		("cyl", (428, 3, 428), (0, 17, 0), HQ2, {"seg": 32}),
		("cone", (300, 70, 300), (0, 53, 0), HQ, {"seg": 24, "taper": 0.5}),
		("cyl", (156, 4, 156), (0, 90, 0), HQ2, {"seg": 24}),
	]
	for i in range(32):  # hull ribs: from r 150 at y 18 up to r 75 at y 88
		a = i * math.tau / 32
		p.append(("box", (4, 103, 6), (math.cos(a) * 112, 53, math.sin(a) * 112), HQ2, {"rot": (0, -math.degrees(a), 47), "metal": 0.4}))
	for i in range(16):
		a = (i + 0.5) * math.tau / 16
		p.append(("box", (2, 40, 10), (math.cos(a) * 118, 50, math.sin(a) * 118), HQGLASS, {"rot": (0, -math.degrees(a), 47), "emit": 0.15}))
	p.append(("box", (32, 270, 32), (0, 92 + 135, 0), HQ))
	p.append(("box", (36, 5, 36), (0, 92 + 270, 0), HQ2))
	p.append(("box", (20, 30, 20), (0, 92 + 287, 0), HQ))
	p.append(("cyl", (2, 60, 2), (0, 92 + 330, 0), STEEL, {"seg": 6}))
	for j in range(56):  # stepped tower cluster, tallest at the middle
		r = rng.uniform(16, 72)
		a = rng.uniform(0, math.tau)
		hh = max(14, 210 - r * 2.3 + rng.uniform(-12, 12))
		s = rng.uniform(10, 22)
		x, z = math.cos(a) * r, math.sin(a) * r
		p.append(("box", (s, hh, s), (x, 92 + hh / 2, z), (HQ, "262C34", HQ2)[j % 3]))
		p.append(("box", (s * 0.8, 0.8, 0.4), (x, 92 + hh * 0.7, z - s / 2 - 0.2), "4A6A8A", {"emit": 0.6}))
	for j in range(26):  # blocks spilling over the rim of the base
		a = j * math.tau / 26 + 0.1
		s = rng.uniform(6, 12)
		p.append(("box", (s, s * 1.4, s), (math.cos(a) * 172, 18 + s * 0.7, math.sin(a) * 172), HQ2))
	for i in range(10):  # radiating highways on piers
		a = i * math.tau / 10 + 0.15
		c, s = math.cos(a), math.sin(a)
		p.append(("box", (240, 3, 16), (c * 330, 20, s * 330), "4A4E54", {"rot": (0, -math.degrees(a), 0)}))
		for r in (240, 300, 360, 420):
			p.append(("box", (5, 20, 8), (c * r, 9, s * r), "3A3E44", {"rot": (0, -math.degrees(a), 0)}))
	return k.prop("HeroHQ", p)


def _overpass(k, rng):
	"""The dark elevated expressway over the ghost town (ref Z-City_Ghost_Town_Anime_Profile), crossing the road: a heavy
	deck on five deep girders with diaphragms, square piers with caps, chain-link fence underneath, broken off at one end.
	Local X runs across the road; piers at x = +-44, girder undersides 18 above the road (rule: >= 14)."""
	deck, gir = "33363A", "26282C"
	p = [("box", (150, 5, 28), (0, 24.5, 0), deck)]
	for z in (-11, -5.5, 0, 5.5, 11):
		p.append(("box", (150, 4, 1.6), (0, 20.0, z), gir))
	for x in range(-70, 75, 14):
		p.append(("box", (1.2, 3.6, 24), (x, 20.2, 0), "2E3034"))
	for z in (-13.5, 13.5):
		p.append(("box", (150, 3.2, 1.2), (0, 28.6, z), "5A5C60"))
		p.append(("box", (150, 0.5, 1.6), (0, 30.4, z), "6E7074"))
	for x in (-44, 44):
		p.append(("box", (9, 52, 9), (x, -8, 0), "4A4C50"))
		p.append(("box", (12, 4, 30), (x, 16, 0), "3A3C40"))
		for z in (-4.6, 4.6):
			p.append(("box", (9.4, 40, 0.4), (x, -4, z), "3A3C40"))
	for x in (-60, -30, 0, 30, 60):
		p.append(("box", (6, 0.2, 0.6), (x, 27.1, 0), "B8B2A0"))
	for x in (-55, -10, 35):
		p.append(("cyl", (0.7, 12, 0.7), (x, 36, 13.5), STEEL, {"seg": 6}))
		p.append(("box", (0.5, 0.5, 5), (x, 42, 11.2), STEEL))
		p.append(("box", (1.6, 0.6, 2.2), (x, 41.7, 9), "E8E4D0", {"emit": 0.5}))
	for side in (-1, 1):  # chain-link fence under the deck, outside the road, with barbed wire on top
		x0, x1 = side * 27, side * 72
		xm, ln = (x0 + x1) / 2, abs(x1 - x0)
		p.append(("box", (ln, 9, 0.15), (xm, 4.5, 0), "5A6066", {"alpha": 0.55, "metal": 0.5}))
		for i in range(6):
			p.append(("cyl", (0.45, 10.5, 0.45), (x0 + side * i * ln / 5, 5.25, 0), STEEL, {"seg": 6}))
		p.append(("cyl", (0.3, ln, 0.3), (xm, 9.5, 0), STEEL, {"seg": 4, "rot": (0, 0, 90)}))
		for i in range(int(ln / 2.4)):
			p.append(("cyl", (0.2, 2.6, 0.2), (x0 + side * (i + 0.5) * 2.4, 10.6, 0), "3A3A38", {"seg": 4, "rot": (35 * (1 if i % 2 else -1), 0, 90)}))
	# Broken-off end beyond the right pier: hanging slab, exposed rebar, rubble on the ground
	p.append(("box", (32, 5, 28), (90, 14, 0), deck, {"rot": (0, 0, -32)}))
	p.append(("box", (32, 4, 1.6), (90, 11.5, -8), gir, {"rot": (0, 0, -32)}))
	_rebar(p, 76, 22, 0, 10, rng, spread=11)
	for i in range(10):
		s = rng.uniform(4, 8)
		p.append(("box", (s, s * 0.6, s * 1.2), (rng.uniform(86, 112), -s * 0.2 - 2, rng.uniform(-12, 12)), "4A4C50", {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	return k.prop("Overpass", p)


def _midrise_apartment(k, rng):
	"""Warm-grey mid-rise apartments: window grids on every face, balconies with railings, AC units, shutters (some
	boarded), rain streaks and patches, rooftop tank, stair core."""
	w, d, g, fh, floors = 30, 18, 9, 9, 6
	h = g + floors * fh
	p = [("box", (w, h, d), (0, h / 2, 0), CONC2)]
	_grid(p, "z", 0, -d / 2, w, g, floors, fh, 5, rng, frame="8A847A", broken=0.3, boarded=0.1)
	_grid(p, "z+", 0, d / 2, w, g, floors, fh, 5, rng, frame="8A847A", broken=0.3)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 2, rng, frame="8A847A", broken=0.3)
		_stains(p, face, cx, 0, d, g, h - g, rng, n=2, patches=1)
	_stains(p, "z", 0, -d / 2, w, g, h - g, rng, n=6, patches=2)
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w, 0.7, 3), (0, y + 0.2, -d / 2 - 1.5), "9A948A"))
		p.append(("box", (w, 1.8, 0.3), (0, y + 1.3, -d / 2 - 2.9), "8E8880", {"rough": 0.6}))
		p.append(("box", (w, 0.35, 0.35), (0, y + 3.4, -d / 2 - 2.9), STEEL))
		for x in (-w / 2 + 0.3, -5, 5, w / 2 - 0.3):
			p.append(("box", (0.35, 3.2, 0.35), (x, y + 1.8, -d / 2 - 2.9), STEEL))
		for x in (-9, 3):
			if rng.random() < 0.7:
				p.append(("box", (2.6, 2.0, 1.2), (x + rng.uniform(-2, 2), y + 1.4, -d / 2 - 1.8), "C8C2B6"))
	for i, x in enumerate((-10, 0, 10)):
		p.append(("box", (8.5, 6.5, 0.4), (x, 3.25, -d / 2 - 0.2), DARK if i == 1 else "6E7076", {"metal": 0.3}))
		if i == 2:
			for dy, r in ((2, 15), (4.5, -12)):
				p.append(("box", (9, 1, 0.4), (x, dy, -d / 2 - 0.6), BOARD, {"rot": (0, 0, r)}))
		elif i == 0:
			for j in range(4):
				p.append(("box", (8.5, 0.25, 0.5), (x, 1 + j * 1.5, -d / 2 - 0.25), "54565C"))
	p.append(("box", (w, 0.6, 2.5), (0, g - 1.5, -d / 2 - 1.25), "9A948A"))
	p.append(("box", (6, h + 4, 7), (w / 2 + 3, (h + 4) / 2, 2), "7E786E"))  # outside stair core with flights
	for fl in range(floors + 1):
		p.append(("box", (6.4, 0.6, 7.4), (w / 2 + 3, g + fl * fh - 0.5, 2), "9A948A"))
		p.append(("box", (0.4, 7.5, 7.6), (w / 2 + 6.2, g + fl * fh - 4.5, 2), "5E5850", {"rot": (40 if fl % 2 else -40, 0, 0)}))
	_roof(p, w, d, h)
	_tank(p, w / 2 - 5, h, 0)
	for _ in range(4):
		_crack(p, "z", 0, -d / 2 - 0.4, rng.uniform(-12, 12), rng.uniform(15, 50), rng.uniform(5, 10), rng.uniform(-40, 40))
	return k.prop("MidRise", p)


def _office_damaged(k, rng):
	"""Beige office block with its top corner torn off: broken floor slabs, rebar, a punched hole, cracks, streaks."""
	w, d, g, fh = 28, 22, 9, 9
	hl, hr = g + 8 * fh, g + 4 * fh
	p = [("box", (16, hl, d), (-6, hl / 2, 0), BEIGE), ("box", (12, hr, d), (8, hr / 2, 0), BEIGE)]
	_grid(p, "z", -6, -d / 2, 16, g, 8, fh, 3, rng, frame="A89878", broken=0.4, boarded=0.1)
	_grid(p, "z", 8, -d / 2, 12, g, 4, fh, 2, rng, frame="A89878", broken=0.5)
	_grid(p, "z+", -6, d / 2, 16, g, 8, fh, 3, rng, frame="A89878", broken=0.4)
	_grid(p, "z+", 8, d / 2, 12, g, 4, fh, 2, rng, frame="A89878", broken=0.4)
	_grid(p, "x-", -w / 2, 0, d - 4, g, 8, fh, 3, rng, frame="A89878", broken=0.35)
	_grid(p, "x+", w / 2, 0, d - 4, g, 4, fh, 3, rng, frame="A89878", broken=0.4)
	_stains(p, "z", -6, -d / 2, 16, g, hl - g, rng, n=4, patches=2)
	_stains(p, "x-", -w / 2, 0, d, g, hl - g, rng, n=3, patches=1)
	for fl in range(4, 8):  # torn floors: slabs sticking out of the left part over the gap
		y = g + fl * fh
		ln = rng.uniform(4, 10)
		p.append(("box", (ln, 0.9, d - 2), (2 + ln / 2, y, rng.uniform(-1, 1)), "B0A088", {"rot": (0, 0, rng.uniform(-14, 6))}))
		p.append(("box", (0.9, fh - 1, 0.9), (1.5, y + fh / 2, -d / 2 + 1), "A09078"))
		_rebar(p, 2 + ln, y, 0, 2, rng, spread=6)
	p.append(("wedge", (12, 7, d), (8, hr + 3.5, 0), "B0A088", {"rot": (0, 90, 0)}))
	_rebar(p, 8, hr + 4, 0, 4, rng, spread=5)
	p.append(("box", (7, 8, 0.6), (-8, g + 4.5 * fh, -d / 2 - 0.4), DARK))
	for dx, dy, r in ((-11.5, 0, 20), (-4.5, 1, -15), (-8, 4.3, 80), (-8, -4.2, 95)):
		p.append(("box", (2.5, 1.2, 1.2), (dx, g + 4.5 * fh + dy, -d / 2 - 0.8), BEIGE, {"rot": (0, 0, r)}))
	for _ in range(5):
		_crack(p, "z", 0, -d / 2 - 0.4, rng.uniform(-12, 12), rng.uniform(12, 60), rng.uniform(6, 14), rng.uniform(-50, 50))
	p.append(("box", (16, 2, d), (-6, hl + 1, 0), TAN))
	_tank(p, -10, hl + 2, 3, 0.9)
	for i in range(6):
		s = rng.uniform(3, 6)
		p.append(("box", (s, s * 0.7, s), (rng.uniform(4, 16), s * 0.3, rng.uniform(-d / 2 - 8, -d / 2 - 2)), ("B0A088", BEIGE, CONC)[i % 3], {"rot": (rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25))}))
	return k.prop("OfficeBroken", p)


def _highrise(k, rng):
	"""Empty weathered high-rise: window grids on all four faces, corner fins, rain streaks, lobby canopy, setback
	crown, roof plant, mast."""
	w, d, g, fh, floors = 34, 30, 12, 9, 16
	h = g + floors * fh
	body, frame = "6E747C", "7E848A"
	p = [("box", (w, h, d), (0, h / 2, 0), body)]
	_grid(p, "z", 0, -d / 2, w - 4, g, floors, fh, 6, rng, glass=GLASS2, frame=frame, broken=0.25)
	_grid(p, "z+", 0, d / 2, w - 4, g, floors, fh, 4, rng, glass=GLASS2, frame=frame, broken=0.1)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 4, rng, glass=GLASS2, frame=frame, broken=0.15)
	_stains(p, "z", 0, -d / 2, w, g, h - g, rng, n=6, patches=2)
	for x in (-w / 2, w / 2):
		for z in (-d / 2, d / 2):
			p.append(("box", (2.4, h, 2.4), (x, h / 2, z), "9A948A"))
	p.append(("box", (w - 6, g - 2, 0.4), (0, (g - 2) / 2, -d / 2 - 0.2), "1A1E24", {"rough": 0.2}))
	p.append(("box", (w + 2, 1, 6), (0, g - 1.5, -d / 2 - 3), "9A948A"))
	p.append(("box", (w - 8, 12, d - 8), (0, h + 6, 0), "6E6860"))
	p.append(("box", (w - 6, 1, d - 6), (0, h + 12.5, 0), "9A948A"))
	for x, z, s in ((-8, -4, 5), (6, 5, 6), (-2, 7, 4)):
		p.append(("box", (s, 3, s), (x, h + 14.5, z), STEEL))
	p.append(("cyl", (1.2, 30, 1.2), (6, h + 28, -4), "A04A3A", {"seg": 6}))
	for _ in range(3):
		_crack(p, "z", 0, -d / 2 - 0.5, rng.uniform(-12, 12), rng.uniform(20, 120), rng.uniform(8, 16), rng.uniform(-40, 40))
	return k.prop("HighRise", p)


def _collapsed(k, rng):
	"""Half-collapsed high-rise: a grid shaft, then exposed floor slabs on stub columns, a tilted top slab, rebar,
	a fallen chunk leaning on the foot and rubble."""
	w, d, g, fh = 32, 28, 9, 9
	hs = g + 9 * fh
	p = [("box", (w, hs, d), (0, hs / 2, 0), "A08E78")]
	_grid(p, "z", 0, -d / 2, w - 2, g, 9, fh, 5, rng, broken=0.55, boarded=0.1)
	_grid(p, "z+", 0, d / 2, w - 2, g, 9, fh, 4, rng, broken=0.3)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, 9, fh, 3, rng, broken=0.4)
	_stains(p, "z", 0, -d / 2, w, g, hs - g, rng, n=5, patches=2)
	for j in range(3):  # exposed floors, each a little smaller, with stub columns between
		y = hs + j * fh
		cut = j * 5
		p.append(("box", (w - cut, 1, d - cut * 0.6), (-cut / 2, y + fh, 0), "8E887E", {"rot": (rng.uniform(-3, 3), 0, rng.uniform(-4, 4))}))
		for x in (-w / 2 + 1.5, -2, w / 2 - 1.5 - cut):
			for z in (-d / 2 + 1.5, d / 2 - 1.5):
				if rng.random() < 0.75:
					p.append(("box", (1.4, fh, 1.4), (x, y + fh / 2, z), "A8A296"))
		_rebar(p, w / 2 - cut, y + fh, 0, 3, rng, spread=8)
	p.append(("box", (w * 0.7, 1.2, d * 0.8), (-6, hs + 3 * fh + 4, 2), "8E887E", {"rot": (8, 10, 22)}))
	p.append(("box", (20, 44, 14), (w / 2 + 6, 16, -6), CONC, {"rot": (6, 20, -22)}))
	p.append(("box", (16, 30, 0.4), (w / 2 + 2, 16, -13.2), GLASS, {"rot": (6, 20, -22)}))
	_rebar(p, w / 2 + 10, 34, -6, 5, rng)
	for i in range(8):
		s = rng.uniform(3, 8)
		p.append(("box", (s, s * 0.6, s), (rng.uniform(-w / 2, w / 2 + 12), s * 0.2, rng.uniform(-d / 2 - 10, -d / 2 - 2)), (CONC, "8E887E", CONC2)[i % 3], {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	return k.prop("Collapsed", p)


def _barricade(k, rng):
	"""Evacuation cordon (ref Z-City_Ghost_Town_Anime_Profile): chain-link fence with coiled barbed wire, a yellow-black
	striped barrier in front, a tall white board with a red header band (no text) on two posts, cones. Along local X."""
	L = 36
	p = [("box", (L, 9, 0.15), (0, 5, 0), "5A6066", {"alpha": 0.55, "metal": 0.5})]
	for i in range(7):
		x = -L / 2 + i * L / 6
		p.append(("cyl", (0.5, 10.5, 0.5), (x, 5.25, 0), STEEL, {"seg": 6, "metal": 0.5}))
		p.append(("box", (0.25, 2.4, 0.25), (x, 11.2, -0.7), STEEL, {"rot": (-35, 0, 0)}))
	for y in (0.6, 9.6):
		p.append(("cyl", (0.35, L, 0.35), (0, y, 0), STEEL, {"seg": 6, "rot": (0, 0, 90)}))
	for i in range(int(L / 1.8)):  # coiled barbed wire: crossing zig-zag strands over the top
		x = -L / 2 + (i + 0.5) * 1.8
		for s in (-1, 1):
			p.append(("cyl", (0.22, 2.4, 0.22), (x, 11.8, -1.1), "2E2E2C", {"seg": 4, "rot": (s * 50, 0, 90)}))
	for x in (-12, 12):  # barrier: two legs, a tall striped beam
		for dx in (-4.8, 4.8):  # tall legs: the striped beam reads over the road wall
			p.append(("box", (0.6, 9.5, 2.4), (x + dx, 4.75, -4), "C8C4B8"))
		for j in range(8):
			p.append(("box", (1.25, 2.8, 0.5), (x - 4.4 + j * 1.25, 8.2, -4), ("F2C230", "1E1E1E")[j % 2]))
	for x in (0.5, 5.5):
		p.append(("box", (0.45, 15, 0.45), (x, 7.5, -2.4), STEEL))
	p.append(("box", (5.8, 11, 0.3), (3, 8.5, -2.75), "F2F0EA"))
	p.append(("box", (5.8, 2.4, 0.35), (3, 12.8, -2.8), "C8202A"))
	p.append(("box", (5.8, 0.3, 0.35), (3, 3.1, -2.8), "C8202A"))
	for x in (-2.5, 8, 18.5):
		p.append(("cone", (1.8, 3.2, 1.8), (x, 1.6, -6.5), "F06A1A", {"seg": 8}))
		p.append(("cyl", (1.25, 0.5, 1.25), (x, 2.0, -6.5), "F2F0EA", {"seg": 8}))
		p.append(("box", (2.2, 0.3, 2.2), (x, 0.15, -6.5), "F06A1A"))
	return k.prop("Barricade", p)


POLE_GAP = 60


def _kerb(k, rng):
	"""Kerb set: a Japanese concrete utility pole (crossarms, insulators, transformer, step bolts, street lamp over the
	road) strung with wires to the next pole POLE_GAP studs on, a pair of vending machines and a street tree."""
	p = [("cyl", (1.5, 42, 1.5), (0, 21, 0), "9A968C", {"seg": 8, "taper": 0.7}), ("box", (2.4, 1, 2.4), (0, 0.5, 0), "7E7A72")]
	for y in (36, 39.5):
		p.append(("box", (11, 0.6, 0.6), (0, y, 0), "5E5E58"))
		for x in (-4.5, -1.5, 1.5, 4.5):
			p.append(("cyl", (0.5, 1.0, 0.5), (x, y + 0.8, 0), "D8D8D0", {"seg": 6}))
	p.append(("cyl", (2.6, 4.2, 2.6), (0, 30, 1.8), "7E8486", {"seg": 10}))
	p.append(("box", (0.4, 1, 2), (0, 32.4, 0.9), "5E5E58"))
	for i in range(8):
		p.append(("box", (1.4, 0.2, 0.2), (0, 12 + i * 2.2, 0), "5E5E58", {"rot": (0, (i % 2) * 90, 0)}))
	p.append(("box", (0.4, 0.4, 3.6), (0, 26, -1.8), "5E5E58", {"rot": (-12, 0, 0)}))  # lamp ends 24.1 off the centre line
	p.append(("box", (1.8, 0.7, 2.4), (0, 26.4, -3.6), "C8C4B8"))
	p.append(("box", (1.4, 0.2, 1.8), (0, 26.0, -3.6), "FFF2C8", {"emit": 0.6}))
	for x, y in ((-4.5, 37.2), (4.5, 37.2), (-1.5, 40.7), (4.5, 40.7)):  # wires to the next pole (+X), slight sag
		for half in (0, 1):
			p.append(("cyl", (0.16, POLE_GAP / 2 + 0.4, 0.16), (POLE_GAP / 4 + half * POLE_GAP / 2, y - 0.8, x * 0.15), "1E1E1E", {"seg": 4, "rot": (0, 0, 87 if half == 0 else 93)}))
	for i, x in enumerate((5.5, 9.2)):  # vending machines (no text): body, lit panel, sample row, slot
		col = ("E8E6E0", "C82A2A")[i]
		p.append(("box", (3.4, 6.4, 2.8), (x, 3.2, -1.5), col))
		p.append(("box", (2.8, 2.6, 0.2), (x, 4.6, -2.95), "DCEAF2", {"emit": 0.8}))
		for j in range(4):
			p.append(("box", (0.4, 0.8, 0.2), (x - 1.05 + j * 0.7, 4.6, -3.05), ("3A6AC8", "E8B83A", "3AA85A", "C83A3A")[j]))
		p.append(("box", (2.2, 0.6, 0.3), (x, 1.2, -3.0), "1E1E1E"))
	tx = -12
	p += [("cyl", (1.4, 13, 1.4), (tx, 6.5, 0), "4A3A2C", {"seg": 7, "taper": 0.7}), ("cyl", (0.7, 6, 0.7), (tx + 1.5, 12, 0), "4A3A2C", {"seg": 6, "rot": (0, 0, -35)})]
	for x, y, z, s, c in ((0, 16, 0, 9, "4E6B3A"), (3.5, 14, 1, 6.5, "5E7E44"), (-3.5, 14, -1, 6.5, "445E32"), (1, 19, -1.5, 5.5, "5E7E44")):
		p.append(("ball", (s, s * 0.8, s), (tx + x, y, z), c, {"subdiv": 1, "smooth": True}))
	for sx, sz, x, z in ((5, 0.4, 0, -2.3), (5, 0.4, 0, 2.3), (0.4, 5, -2.3, 0), (0.4, 5, 2.3, 0)):
		p.append(("box", (sx, 0.6, sz), (tx + x, 0.3, z), "A8A296"))
	return k.prop("Kerb", p)


def _rubble(k, rng):
	"""Rubble heap: concrete chunks, cracked slabs, rebar, a broken pipe and a crushed dusty car."""
	p = []
	for j in range(11):
		s = rng.uniform(2.5, 7)
		p.append(("box", (s, s * 0.7, s * 1.2), (rng.uniform(-8, 6), s * 0.3, rng.uniform(-4, 6)), (CONC, CONC2, BEIGE, "8E887E")[j % 4], {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	for j in range(3):
		p.append(("box", (9, 0.8, 7), (rng.uniform(-6, 6), 1.2, rng.uniform(-2, 4)), "8E887E", {"rot": (rng.uniform(-18, 18), rng.uniform(0, 90), rng.uniform(-18, 18))}))
	_rebar(p, -2, 1, 1, 6, rng, spread=5)
	p.append(("cyl", (1.6, 10, 1.6), (4, 1.2, 6), "6E6A64", {"seg": 8, "rot": (0, 30, 80)}))
	cx, cz = 10, -3  # crushed car
	p += [
		("box", (6, 2.2, 12), (cx, 1.6, cz), "5E6A74", {"metal": 0.3, "rough": 0.6}),
		("box", (5.4, 1.0, 5), (cx, 3.0, cz + 1), "4A545C", {"rot": (4, 0, 6)}),
		("box", (5.4, 1.2, 0.3), (cx, 3.0, cz - 1.8), "1E2428", {"rough": 0.2, "rot": (40, 0, 0)}),
		("box", (6.2, 0.8, 0.5), (cx, 1.2, cz - 6.1), "2A2A2A"),
		("box", (1.2, 0.6, 0.3), (cx - 2, 1.9, cz - 6.2), "C8C4B0"),
		("box", (1.2, 0.6, 0.3), (cx + 2, 1.9, cz - 6.2), "C8C4B0"),
		("box", (6, 2.5, 4), (cx + 1, 4.5, cz + 2), CONC2, {"rot": (14, 25, -10)}),
	]
	for x, z in ((-3, -4), (3, -4), (-3, 4), (3, 4)):
		p.append(("cyl", (2, 1, 2), (cx + x, 0.9, cz + z), DARK, {"seg": 8, "rot": (0, 0, 90)}))
	for x, z, s in ((-9, 5, 4), (-4, 7, 3), (14, 5, 3.5), (6, 6, 2.5)):  # weeds and shrubs growing through
		p.append(("ball", (s, s * 0.7, s), (x, s * 0.3, z), ("4E6B3A", "5E7E44")[int(s) % 2], {"subdiv": 1, "smooth": True}))
	return k.prop("Rubble", p)


TILE = 240


def _blocks(k, rng):
	"""City-block tile, TILE studs square: four raised sidewalk blocks with kerbs, the streets between them in the
	ground's asphalt, crosswalk stripes, lane dashes, parking-lot lines and low lot walls."""
	p = []
	b = 96  # block size; streets 24 wide
	for bx in (-60, 60):
		for bz in (-60, 60):
			p.append(("box", (b, 0.6, b), (bx, 0.3, bz), "625E57"))
			for sx, sz, x, z in ((b, 0.9, 0, -b / 2), (b, 0.9, 0, b / 2), (0.9, b, -b / 2, 0), (0.9, b, b / 2, 0)):
				p.append(("box", (sx, 0.9, sz), (bx + x, 0.45, bz + z), "7A766E"))
			for i in range(5):
				p.append(("box", (0.5, 0.05, 10), (bx - 20 + i * 8, 0.63, bz + 24), "D8D2C0"))
			p.append(("box", (40, 2.4, 0.8), (bx + 20, 1.2, bz - 30), "7A746A"))
			p.append(("box", (0.8, 2.4, 30), (bx + 40, 1.2, bz - 15), "7A746A"))
	for ang in (0, 90):  # crosswalks at the centre crossing, lane dashes along both streets
		for s in (-1, 1):
			for i in range(6):
				o = -7.5 + i * 3
				pos = (o, 0.04, s * 15) if ang == 0 else (s * 15, 0.04, o)
				size = (1.6, 0.08, 6) if ang == 0 else (6, 0.08, 1.6)
				p.append(("box", size, pos, "D8D2C0"))
		for i in range(8):
			o = -105 + i * 30
			if abs(o) < 20:
				continue
			p.append(("box", (6, 0.08, 0.6) if ang == 0 else (0.6, 0.08, 6), (o, 0.04, 0) if ang == 0 else (0, 0.04, o), "C8C2B0"))
	return k.prop("Blocks", p)


def _crater(k, rng):
	"""Hero, infield: the meteor crater (City A/Z damage): a raised berm rim with tilted asphalt slabs on its inner face
	around a scorched sunken-looking bowl, cracks laid on the ground outside, buried building stumps, the meteor core."""
	p = [("cyl", (230, 0.2, 230), (0, 0.1, 0), SCORCH, {"seg": 32}), ("cyl", (120, 0.2, 120), (0, 0.2, 0), "1E1A16", {"seg": 24})]
	n = 40
	for i in range(n):  # berm: inner slope (falls toward the centre) and outer slope, crest at r 150
		a = i * math.tau / n
		c, s = math.cos(a), math.sin(a)
		ins = math.degrees(math.atan2(-c, -s))
		outs = math.degrees(math.atan2(c, s))
		hb = rng.uniform(9, 20)  # ragged crest height
		p.append(("wedge", (26, hb, 44), (c * 128, hb / 2, s * 128), "3E362E", {"rot": (0, ins, 0)}))
		p.append(("wedge", (26, hb, 40), (c * 170, hb / 2, s * 170), ("5A5044", "4A4238")[i % 2], {"rot": (0, outs, 0)}))
		if i % 2 == 0:  # asphalt plates heaved up on the outer face too, kerb stripe on the edge
			tilt = -math.degrees(math.atan2(hb, 40)) - rng.uniform(5, 25)
			p.append(("box", (18, 1.4, 14), (c * 168, hb * 0.55 + 1, s * 168), ASPH, {"rot": (0, -math.degrees(a), tilt)}))
			p.append(("box", (18, 0.2, 0.6), (c * 168, hb * 0.55 + 1.9, s * 168), "C8C2B0", {"rot": (0, -math.degrees(a), tilt)}))
	for i in range(30):  # asphalt slabs tilted on the inner face, some flipped up at the crest
		a = i * math.tau / 30 + rng.uniform(-0.04, 0.04)
		up = i % 4 == 0
		r = 146 if up else rng.uniform(118, 136)
		tilt = rng.uniform(45, 65) if up else rng.uniform(18, 28)
		y = 17 if up else 2 + (r - 106) * 0.41
		p.append(("box", (20, 1.6, 15), (math.cos(a) * r, y, math.sin(a) * r), ASPH, {"rot": (0, -math.degrees(a), tilt)}))
		p.append(("box", (20, 0.2, 0.6), (math.cos(a) * r, y + 0.9, math.sin(a) * r), "C8C2B0", {"rot": (0, -math.degrees(a), tilt)}))
	for i in range(18):  # ground cracks running out from the rim, laid flat on the ground
		a = i * math.tau / 18 + 0.1
		ln = rng.uniform(40, 90)
		r = 188 + ln / 2
		p.append(("box", (ln, 0.1, 3.5), (math.cos(a) * r, 0.05, math.sin(a) * r), "141210", {"rot": (0, -math.degrees(a) + rng.uniform(-8, 8), 0)}))
		p.append(("box", (ln * 0.4, 0.1, 2.2), (math.cos(a) * (r + ln * 0.3), 0.06, math.sin(a) * (r + ln * 0.3)), "141210", {"rot": (0, -math.degrees(a) + rng.uniform(20, 40), 0)}))
	for i in range(16):  # jagged slabs thrust up near vertical along the crest, boulders between them
		a = i * math.tau / 16 + rng.uniform(-0.1, 0.1)
		r = 150 + rng.uniform(-6, 6)
		p.append(("box", (16, 1.8, 12), (math.cos(a) * r, 20, math.sin(a) * r), ASPH, {"rot": (rng.uniform(-15, 15), -math.degrees(a), rng.uniform(62, 80) * (1 if i % 2 else -1))}))
		p.append(("ball", (10, 7, 9), (math.cos(a + 0.2) * r, 16, math.sin(a + 0.2) * r), ("5A5044", "6A6052")[i % 2], {"subdiv": 1}))
	for a in range(8):  # buried building stumps, sunk deep into the bowl and rim
		ang = a * math.tau / 8 + 0.3
		r = rng.uniform(70, 100)
		x, z = math.cos(ang) * r, math.sin(ang) * r
		hh = rng.uniform(20, 36)
		rot = (rng.uniform(-30, 30), a * 23, rng.uniform(-30, 30))
		p.append(("box", (14, hh, 14), (x, hh * 0.15, z), (CONC2, BEIGE, CONC)[a % 3], {"rot": rot}))
		p.append(("box", (14.4, 2.5, 14.4), (x, hh * 0.15 + 3, z), GLASS, {"rot": rot}))
		for j in range(3):
			s = rng.uniform(3, 6)
			p.append(("box", (s, s * 0.6, s), (x + rng.uniform(-10, 10), s * 0.2, z + rng.uniform(-10, 10)), CONC2, {"rot": (rng.uniform(-25, 25), rng.uniform(0, 90), 0)}))
	for j in range(9):  # meteor core: charred rock half sunk, glowing seams
		p.append(("ball", (rng.uniform(16, 28), rng.uniform(12, 20), rng.uniform(16, 26)), (rng.uniform(-24, 24), 2, rng.uniform(-24, 24)), ("3A302A", "2A221E")[j % 2], {"subdiv": 1}))
	for j in range(10):
		p.append(("box", (rng.uniform(6, 14), 0.6, 0.8), (rng.uniform(-24, 24), rng.uniform(5, 10), rng.uniform(-24, 24)), "FF7A2A", {"emit": 3, "rot": (rng.uniform(-30, 30), rng.uniform(0, 180), rng.uniform(-30, 30))}))
	return k.prop("Crater", p)


def _eye(k, f):
	"""The runner's review camera at fraction f (build_track.shots): eye point (y ignored) and heading."""
	p, right, t = k.at(k.length * f)
	return p + right * 10 - t * 14, t


def _clear_near(k, x, z, r, names):
	"""Drop instances of names within r of (x, z)."""
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.name.split("_")[2] in names and math.hypot(ob.location.x - x, -ob.location.y - z) < r:
			k.col.objects.unlink(ob)


def _clear_view(k, e, x, z, width, names):
	"""Drop instances of names standing in the sight line from eye e to (x, z)."""
	vx, vz = x - e.x, z - e.z
	ln2 = vx * vx + vz * vz
	for ob in list(k.col.objects):
		if ob.type != "MESH" or ob.name.split("_")[2] not in names:
			continue
		ox, oz = ob.location.x, -ob.location.y
		u = max(0.0, min(1.0, ((ox - e.x) * vx + (oz - e.z) * vz) / ln2))
		if math.hypot(ox - e.x - vx * u, oz - e.z - vz * u) < width:
			k.col.objects.unlink(ob)


def build(k):
	rng = k.rng
	for make in (_saitama_apartment, _hero_hq, _overpass, _midrise_apartment, _office_damaged, _highrise, _collapsed, _barricade, _kerb, _rubble, _blocks, _crater):
		make(k, rng)

	k.ground("4A4744", margin=2600)
	_fill(k, "3E3C3A")
	L = k.length
	c = (k.lo + k.hi) / 2
	# Street grid: block tiles wherever no road runs, kept off the crater
	x = k.lo.x - 700
	while x < k.hi.x + 700:
		z = k.lo.z - 700
		while z < k.hi.z + 700:
			if math.hypot(x - c.x, z - c.z) > 300 and k.clear_of_road(x, z, 190):
				k.place("Blocks", (x, -1.0, z), 0.0)
			z += TILE
		x += TILE
	# Kerb line: pole sets at a fixed spacing (their wires reach the next pole), then cordons and rubble
	_row(k, POLE_GAP, 29, ["Kerb"], start=20, clear=25)
	_row(k, 75, 33, ["Barricade", "Rubble", "Barricade"], jitter=2, start=50, clear=26)
	# Street walls: apartments and offices, then high-rises behind
	_row(k, 48, 58, ["MidRise", "OfficeBroken", "MidRise", "Collapsed"], jitter=3, start=30)
	_row(k, 80, 108, ["MidRise", "Collapsed", "HighRise", "OfficeBroken"], jitter=8, start=20)
	_row(k, 140, 175, ["HighRise", "OfficeBroken", "Collapsed"], jitter=15, start=50, scale=(1.0, 1.5), yaw_jit=0.4)
	BUILD = ("MidRise", "OfficeBroken", "Collapsed", "HighRise")
	# Expressway crossings on flat straights, piers clear of every lap (none in front of the 33% view: it frames the HQ)
	for f in (0.14, 0.45, 0.63):
		for step in range(20):
			d = L * f + 60 + step * 15
			p0, _, _ = k.at(d - 40)
			p1, _, _ = k.at(d + 40)
			pos, yaw = k.beside(d, 0, 1.0)
			_, right, _ = k.at(d)
			piers = [(pos[0] + right.x * s, pos[2] + right.z * s) for s in (-44, 44, 95)]
			if abs(p0.y - p1.y) < 0.5 and all(k.clear_of_road(x, z, 26) for x, z in piers):
				k.place("Overpass", pos, yaw)  # local X runs across the road
				break
	# The crater in the infield; the infield and the outskirts fill with ruins, away from its bowl
	k.place("Crater", (c.x, -1.0, c.z), 0.3, 1.2)
	for count, names, clearance, margin, scale in (
		(25, ["Rubble", "Rubble", "Kerb"], 50, 300, (0.8, 1.5)),
		(30, ["HighRise", "Collapsed", "MidRise", "OfficeBroken", "MidRise", "OfficeBroken"], 130, 600, (0.9, 1.3)),
	):
		placed, tries = 0, 0
		while placed < count and tries < count * 30:
			tries += 1
			x = rng.uniform(k.lo.x - margin, k.hi.x + margin)
			z = rng.uniform(k.lo.z - margin, k.hi.z + margin)
			if math.hypot(x - c.x, z - c.z) > 250 and k.clear_of_road(x, z, clearance):
				k.place(rng.choice(names), (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(*scale))
				placed += 1
	# Heights vary instance to instance (Roblox: Size.Y on the same mesh)
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.name.split("_")[2] in BUILD:
			ob.scale[2] *= rng.uniform(0.75, 1.3)
	# 01: the hero's apartment on the right, its blank end wall turned toward the camera, the balconies in view
	e, t = _eye(k, 0.06)
	_, right, _ = k.at(L * 0.06)
	ax, az = e.x + t.x * 95 + right.x * 52, e.z + t.z * 95 + right.z * 52
	pos, yaw = k.beside(L * 0.06 + 81, 52)
	_clear_view(k, e, ax, az, 40, BUILD + ("Kerb", "Rubble", "Barricade"))
	_clear_near(k, ax, az, 42, BUILD + ("Rubble", "Barricade"))
	k.place("SaitamaApt", (ax, -1.0, az), yaw + math.pi / 2 - 0.5)
	# 01: a cordon (yellow-black barrier, fence, white board) on the left across the side street
	pos, yaw = k.beside(L * 0.06 + 45, -33)
	_clear_near(k, pos[0], pos[2], 20, ("Rubble", "Barricade"))
	k.place("Barricade", (pos[0], -1.0, pos[2]), yaw - math.pi / 2)
	# 03 and 04: half-collapsed blocks close to the road ahead
	for f, ahead, off in ((0.62, 110, 54), (0.62, 170, -54), (0.9, 95, -54), (0.9, 150, 54)):
		pos, yaw = k.beside(L * f + ahead, off)
		if k.clear_of_road(pos[0], pos[2], 46):
			_clear_near(k, pos[0], pos[2], 36, BUILD)
			k.place("Collapsed", (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2))
	# 04: a second crater ahead of the last stretch, its sight line cleared
	e, t = _eye(k, 0.9)
	for dist in (480, 560, 650, 750):
		hit = None
		for deg in (0, -15, 15, -28, 28):
			a = math.radians(deg)
			x = e.x + (t.x * math.cos(a) - t.z * math.sin(a)) * dist
			z = e.z + (t.x * math.sin(a) + t.z * math.cos(a)) * dist
			if k.clear_of_road(x, z, 250):
				hit = (x, z)
				break
		if hit:
			_clear_near(k, hit[0], hit[1], 260, BUILD + ("Kerb", "Rubble", "Blocks"))
			_clear_view(k, e, hit[0], hit[1], 140, BUILD)
			k.place("Crater", (hit[0], -1.0, hit[1]), math.atan2(e.x - hit[0], e.z - hit[1]), 1.3)
			break
	# The Hero Association HQ beyond the north-east corner, inside both the 33% and 62% views; sight lines cleared
	hq = Vector((k.hi.x + 1240, 0, k.lo.z - 1620))
	for f in (0.33, 0.62):
		e, _ = _eye(k, f)
		_clear_view(k, e, hq.x, hq.z, 90, BUILD)
	k.place("HeroHQ", (hq.x, -1.0, hq.z), 0.4, 4.0)
	# 05: the side camera's street: buildings cleared, wrecks, vending machines, cordons and overgrowth at street level
	p, right, t = k.at(L * 0.48)
	g = p + right * 140 - t * 60
	_clear_near(k, g.x, g.z, 120, BUILD)
	placed, tries = 0, 0
	while placed < 14 and tries < 400:
		tries += 1
		x, z = p.x + right.x * rng.uniform(40, 150) + t.x * rng.uniform(-110, 110), p.z + right.z * rng.uniform(40, 150) + t.z * rng.uniform(-110, 110)
		if k.clear_of_road(x, z, 34):
			k.place(("Rubble", "Rubble", "Kerb", "Barricade")[placed % 4], (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(0.9, 1.4))
			placed += 1
	k.sky([(0.0, "E2DCCC"), (0.07, "C6CFD4"), (0.3, "8FB4D8"), (1.0, "3C74BE")], strength=1.0, sun=(4.0, "FFEED6", 46, 150))
