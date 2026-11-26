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
CLEAR_EXEMPT = {"Overpass", "Fill"}  # spans the road 18 over it / the raised road's own ground support
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
				if prop in MODEL_SHOTS:
					print("CLEARANCE dropped hero", prop, ob.location)
				k.col.objects.unlink(ob)
				break
	k.instances = sum(1 for ob in k.col.objects if ob.name.endswith("_i") or "_i." in ob.name)


def _fill(k, color):
	"""Ground fill under the raised road (the game's hill supports), so the cliff road is not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			# its top under the road over its whole length (kit.support_top), not at the centre's height
			ob, h = k.support("Fill", p.x, p.z, math.atan2(-t.x, -t.z), d - 0.25, d + step + 0.25)
			ob.scale = (k.width - 1, step + 0.5, h)
		d += step


_GROUND = {}


def _on_ground(k, x, z):
	"""World (x, z) on this track's own Ground rect (TrackBuilder: waypoint box + Width x 3 + 200): a Placed prop
	whose base centre is off it is not built by the game (BiomeDressing), so it is not placed here either."""
	n = k.track["Number"]
	if n not in _GROUND:
		from roads import Roads

		_GROUND[n] = Roads(n).ground(0)
	(lox, loz), (hix, hiz) = _GROUND[n]
	return lox <= x <= hix and loz <= z <= hiz


def _row(k, every, off, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), clear=None, yaw_jit=0.0):
	"""Both sides of the road every `every` studs, on the ground (y = -1), -Z facing the road; skipped where another
	stretch of road passes closer than `clear` (default 0.9 x the offset)."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for o in (-off, off):
			oo = o + k.rng.uniform(-jitter, jitter) * (1 if o > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), oo)
			# on this track's own ground only (owner 2026-11-25; the wide layout's re-fit, 2026-11-26)
			if k.clear_of_road(pos[0], pos[2], clear or abs(oo) * 0.9) and k.owns(pos[0], pos[2]) and _on_ground(k, pos[0], pos[2]):
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
	wall = "8A8C90"  # cool mid-grey stained concrete (refs: day and S1E4 night)
	p = [("box", (w, h, d), (0, h / 2, 0), wall)]
	# Street face (-Z): deep brick balcony stack, three units per floor, a round-fan AC unit on every balcony
	p.append(("box", (w, h - g, 0.3), (0, g + (h - g) / 2, -d / 2 - 0.15), "1C1816"))  # black recesses behind the balconies
	DB = 11  # balcony depth: deep brick boxes standing well out of the wall
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w + 0.8, 1.2, DB), (0, y, -d / 2 - DB / 2), "8A8278"))
		p.append(("box", (w + 0.8, 0.5, 0.6), (0, y - 0.6, -d / 2 - DB + 0.3), "5E4A3E"))  # dark drip edge under each slab
		p.append(("box", (w + 0.6, 1.0, DB - 0.4), (0, y - 1.1, -d / 2 - DB / 2), "141210"))  # deep near-black soffit under the slab
		for x in (-13, -4.33, 4.33, 13):
			p.append(("box", (0.9, fh, DB), (x, y + fh / 2, -d / 2 - DB / 2), BRICK))
		for ux in (-8.67, 0, 8.67):
			p.append(("box", (7.6, 4.2, 1.0), (ux, y + 2.6, -d / 2 - DB + 0.5), BRICK))
			p.append(("box", (7.8, 0.45, 1.3), (ux, y + 4.9, -d / 2 - DB + 0.5), "9A8A78"))
			for i in range(3):  # brick coursing lines on the parapet
				p.append(("box", (7.62, 0.12, 1.02), (ux, y + 1.4 + i * 1.1, -d / 2 - DB + 0.5), "5E382A"))
			p.append(("box", (4.4, 6.6, 0.3), (ux - 1.4, y + 3.8, -d / 2 - 0.35), "0E0E10", {"rough": 0.3}))
			# AC unit sitting on top of the parapet, its fan grille facing the street (ref)
			zf = -d / 2 - DB + 0.6
			p.append(("box", (3.4, 2.6, 1.8), (ux + 1.8, y + 6.45, zf), "B8B6B0"))
			p.append(("cyl", (2.1, 0.3, 2.1), (ux + 1.6, y + 6.45, zf - 0.95), "4A4A48", {"seg": 12, "rot": (90, 0, 0)}))
			p.append(("cyl", (0.7, 0.35, 0.7), (ux + 1.6, y + 6.45, zf - 1.05), "2A2A28", {"seg": 6, "rot": (90, 0, 0)}))
		# steel-railed corner balconies at the far end of both end walls (ref: right edge of the end wall)
		for sx in (-1, 1):
			bx = sx * (w / 2 + 2.6)
			p.append(("box", (5.2, 0.7, 8), (bx, y, d / 2 - 4.5), "8A8278"))
			p.append(("box", (0.3, 0.3, 8), (bx + sx * 2.45, y + 3.6, d / 2 - 4.5), STEEL))
			p.append(("box", (5.2, 0.3, 0.3), (bx, y + 3.6, d / 2 - 8.4), STEEL))
			for zz in (-8.4, -6.0, -3.5, -1.0):
				p.append(("box", (0.22, 3.3, 0.22), (bx + sx * 2.45, y + 1.95, d / 2 + zz + 0.4), STEEL))
	# Ground floor: three grey rolled shutters with grooves and roll boxes, one boarded, a canopy, wall lamps
	for x, boarded in ((-8.67, False), (0, True), (8.67, False)):
		p.append(("box", (7.6, 7.5, 0.4), (x, 3.75, -d / 2 - 0.2), "A2A4A8", {"metal": 0.3}))
		p.append(("box", (8.0, 1.2, 1.2), (x, 8.1, -d / 2 - 0.6), "7E8084"))
		for i in range(7):
			p.append(("box", (7.6, 0.2, 0.5), (x, 0.8 + i * 1, -d / 2 - 0.25), "6E7074"))
		if boarded:
			for dy, r in ((2.5, 18), (5, -14)):
				p.append(("box", (8.2, 1, 0.4), (x, dy, -d / 2 - 0.6), BOARD, {"rot": (0, 0, r)}))
	p.append(("box", (w, 0.5, 3.4), (0, 9.2, -d / 2 - 1.7), "8A8278"))
	for x in (-12, -4.3, 4.3, 12):
		p.append(("box", (1.0, 0.6, 0.6), (x, 8.6, -d / 2 - 2.6), "E8E4D0", {"emit": 0.4}))
	# Low brown railing fence in front of the shutters, shrubs behind it
	p.append(("box", (w + 2, 2.0, 1), (0, 1.0, -d / 2 - 8), "8E8A82"))
	for i in range(15):
		p.append(("box", (0.3, 3.2, 0.3), (-w / 2 + i * w / 14, 3.6, -d / 2 - 8), "4A3426"))
	for y in (3.0, 5.2):
		p.append(("box", (w + 2, 0.35, 0.35), (0, y, -d / 2 - 8), "4A3426"))
	for x in (-9, 2, 10):
		p.append(("ball", (3.4, 2.6, 3.0), (x, 3.4, -d / 2 - 6), "4E6B3A", {"subdiv": 1, "smooth": True}))
	# Blank end walls: large darker rectangular patches, panel seams, dark bolt dots, a drain pipe
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		for u, y, pw, ph, col in ((-9, 26, 12, 18, "6A6C70"), (8, 45, 10, 22, "64666A"), (-6, 63, 14, 12, "6E7074"), (10, 73, 9, 13, "66686C")):
			_add(p, face, cx, 0, u, 0.12, y, pw, ph, 0.24, col)  # 4 large darker rectangular patches (ref)
		for fl in range(1, floors + 1):
			_add(p, face, cx, 0, 0, 0.18, g + fl * fh, d, 0.35, 0.3, "6E7074")
		for fl in range(floors):
			for u in (-11, -3.5, 3.5, 11):
				_add(p, face, cx, 0, u, 0.32, g + fl * fh + 5, 0.9, 0.9, 0.6, "2E2C28")
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
	broad round base with a sheer rim wall and a pale deck dotted with low blocks, a ribbed truncated octagonal hull,
	and on its top a dense stepped cluster of dark blocks peaking in the middle; wide highways on piers radiating out.
	No emblem."""
	body, body2, deck, rib = "2A3038", "3A424C", "6E747C", "4A525C"
	RIM, HB, HT, HH = 52, 197, 120, 76  # rim wall height; hull foot radius (75% of the deck's 263), wide flat top, height
	top = RIM + 3 + HH
	p = [
		("cyl", (520, RIM, 520), (0, RIM / 2, 0), body2, {"seg": 40}),
		("cyl", (526, 3, 526), (0, RIM + 1.5, 0), deck, {"seg": 40}),
		("cyl", (530, 2, 530), (0, 8, 0), "1E2228", {"seg": 40}),
		("cyl", (524, 1.5, 524), (0, RIM - 6, 0), "222830", {"seg": 40}),
		("cone", (HB * 2, HH, HB * 2), (0, RIM + 3 + HH / 2, 0), body, {"seg": 8, "taper": HT / HB}),
		("cyl", (HT * 2, 4, HT * 2), (0, top - 2, 0), deck, {"seg": 8}),
	]
	tilt = math.degrees(math.atan2(HB - HT, HH))
	ln = math.hypot(HB - HT, HH)
	for i in range(24):  # hull ribs running down the faceted slope from the top to the foot
		a = (i + 0.5) * math.tau / 24
		rm = (HB + HT) / 2 * 0.95  # between the octagon's vertex radius and its face apothem
		p.append(("box", (5, ln, 6), (math.cos(a) * rm, RIM + 3 + HH / 2, math.sin(a) * rm), rib, {"rot": (0, -math.degrees(a), tilt), "metal": 0.4}))
	for j in range(30):  # low blocks on the narrow deck ring left around the hull
		a = rng.uniform(0, math.tau)
		r = rng.uniform(210, 250)
		s = rng.uniform(5, 11)
		hh = rng.uniform(4, 12)
		p.append(("box", (s, hh, s * rng.uniform(0.7, 1.4)), (math.cos(a) * r, RIM + 3 + hh / 2, math.sin(a) * r), (body, body2, "22282E")[j % 3], {"rot": (0, rng.uniform(0, 90), 0)}))
	for j in range(120):  # broad dense block cluster over 60% of the hull top, stepping up to the middle
		r = 72 * math.sqrt(rng.random())
		a = rng.uniform(0, math.tau)
		hh = max(8, 92 - r * 1.15 + rng.uniform(-10, 10))
		s = rng.uniform(10, 20)
		x, z = math.cos(a) * r, math.sin(a) * r
		p.append(("box", (s, hh, s * rng.uniform(0.7, 1.3)), (x, top + hh / 2, z), (body, "222830", body2, "303842")[j % 4]))
		if j % 3 == 0:
			p.append(("box", (s * 0.8, 0.8, 0.4), (x, top + hh * rng.uniform(0.4, 0.85), z - s / 2 - 0.2), "8AB0D0", {"emit": 0.8}))
	p.append(("box", (30, 108, 30), (0, top + 54, 0), "222830"))
	p.append(("box", (16, 14, 16), (0, top + 115, 0), body2))
	# the brown cratered plain it stands on (ref New_Hero_Association_Headquarters_Anime), reaching back to the city
	p.append(("cyl", (1300, 0.3, 1300), (0, 0.15, 0), "6E5A44", {"seg": 40}))
	for i in range(14):
		a = rng.uniform(0, math.tau)
		r = rng.uniform(330, 600)
		s = rng.uniform(30, 80)
		p.append(("cyl", (s, 0.4, s * 0.8), (math.cos(a) * r, 0.3, math.sin(a) * r), ("5A4836", "7A6650")[i % 2], {"seg": 12}))
	for i in range(30):
		a = rng.uniform(0, math.tau)
		r = rng.uniform(320, 620)
		p.append(("box", (rng.uniform(40, 120), 0.4, 3), (math.cos(a) * r, 0.35, math.sin(a) * r), "4A3A2C", {"rot": (0, rng.uniform(0, 180), 0)}))

	def road(x0, z0, ang, ln, y):
		"""One straight highway deck on piers: pale deck, edge barriers, lane dashes."""
		c, s = math.cos(ang), math.sin(ang)
		cx, cz = x0 + c * ln / 2, z0 + s * ln / 2
		rot = {"rot": (0, -math.degrees(ang), 0)}
		p.append(("box", (ln + 2, 4, 44), (cx, y, cz), "9A9EA2", rot))
		for dz in (-21, 21):
			p.append(("box", (ln + 2, 2.4, 1.6), (cx - s * dz, y + 3, cz + c * dz), "B8BCC0", rot))
		for dz in (-7, 7):
			for j in range(int(ln / 26)):
				t = (j + 0.5) * 26
				p.append(("box", (10, 0.3, 1.0), (x0 + c * t - s * dz, y + 2.1, z0 + s * t + c * dz), "E8E8E0", rot))
		for j in range(int(ln / 70) + 1):
			t = j * 70 + 20
			p.append(("box", (10, y - 2, 14), (x0 + c * t, (y - 2) / 2, z0 + s * t), "6E7276", rot))

	for i in range(12):  # radiating highways, each entering the sheer rim through a dark slot; every third one bends
		a = i * math.tau / 12 + 0.15
		p.append(("box", (8, 20, 54), (math.cos(a) * 259, 25, math.sin(a) * 259), "08090C", {"rot": (0, -math.degrees(a), 0)}))
		road(math.cos(a) * 262, math.sin(a) * 262, a, 300, 22)
		if i % 3 == 0:
			x, z, ang = math.cos(a) * 262, math.sin(a) * 262, a
			for j in range(4):  # a curve made of short turned spans
				x += math.cos(ang) * 75
				z += math.sin(ang) * 75
				ang += 0.22
				road(x - math.cos(ang) * 75, z - math.sin(ang) * 75, ang, 78, 24)
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
		p.append(("box", (9, 20, 9), (x, 8, 0), "4A4C50"))  # piers stand on the ground, 2 below the road (flat crossings only)
		p.append(("box", (12, 4, 30), (x, 16, 0), "3A3C40"))
		p.append(("box", (11, 1.5, 11), (x, -1.25, 0), "3A3C40"))
		for z in (-4.6, 4.6):
			p.append(("box", (9.4, 16, 0.4), (x, 7, z), "3A3C40"))
	for x in (-60, -30, 0, 30, 60):
		p.append(("box", (6, 0.2, 0.6), (x, 27.1, 0), "B8B2A0"))
	for x in (-55, -10, 35):
		p.append(("cyl", (0.7, 12, 0.7), (x, 36, 13.5), STEEL, {"seg": 6}))
		p.append(("box", (0.5, 0.5, 5), (x, 42, 11.2), STEEL))
		p.append(("box", (1.6, 0.6, 2.2), (x, 41.7, 9), "E8E4D0", {"emit": 0.5}))
	for side in (-1, 1):  # chain-link fence under the deck, outside the road, with barbed wire on top
		x0, x1 = side * 27, side * 72
		xm, ln = (x0 + x1) / 2, abs(x1 - x0)
		for i in range(int((ln - 9) / 1.6)):  # chain-link: two crossing sets of thin diagonal wires, kept between the posts
			x = x0 + side * (4.5 + (i + 0.5) * 1.6)
			for r in (45, -45):
				p.append(("box", (0.14, 12.4, 0.14), (x, 3.4, 0), "7A8086", {"rot": (0, 0, r), "metal": 0.6}))
		for i in range(6):  # posts set in concrete footings on the ground
			px = x0 + side * i * ln / 5
			p.append(("cyl", (0.45, 12.5, 0.45), (px, 4.25, 0), STEEL, {"seg": 6}))
			p.append(("box", (1.4, 1.4, 1.4), (px, -1.3, 0), "8A8680"))
			p.append(("box", (0.25, 2.4, 0.25), (px, 11.2, -0.7), STEEL, {"rot": (-35, 0, 0)}))  # barbed-wire arm
		for yy in (-1.6, 8.6):  # bottom and top rails
			p.append(("cyl", (0.3, ln, 0.3), (xm, yy, 0), STEEL, {"seg": 4, "rot": (0, 0, 90)}))
		for i in range(int(ln / 2.4)):
			p.append(("cyl", (0.2, 2.6, 0.2), (x0 + side * (i + 0.5) * 2.4, 10.6, 0), "3A3A38", {"seg": 4, "rot": (35 * (1 if i % 2 else -1), 0, 90)}))
			p.append(("cyl", (1.6, 0.18, 1.6), (x0 + side * (i + 0.5) * 2.4, 11.6, 0), "2E2E2C", {"seg": 6, "rot": (90, 0, 20)}))  # barbed coil loop
	# Broken-off end beyond the right pier: hanging slab, exposed rebar, rubble on the ground
	p.append(("box", (32, 5, 28), (90, 14, 0), deck, {"rot": (0, 0, -32)}))
	p.append(("box", (32, 4, 1.6), (90, 11.5, -8), gir, {"rot": (0, 0, -32)}))
	_rebar(p, 76, 22, 0, 10, rng, spread=11)
	for i in range(10):
		s = rng.uniform(4, 8)
		p.append(("box", (s, s * 0.6, s * 1.2), (rng.uniform(86, 112), s * 0.25 - 2, rng.uniform(-12, 12)), "4A4C50", {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))}))
	return k.prop("Overpass", p)


def _midrise_apartment(k, rng):
	"""Warm-grey mid-rise apartments: window grids on every face, balconies with railings, AC units, shutters (some
	boarded), rain streaks and patches, rooftop tank, stair core."""
	w, d, g, fh, floors = 30, 18, 9, 9, 6
	h = g + floors * fh
	p = [("box", (w, h, d), (0, h / 2, 0), "C6CACE")]  # cool white block (refs: ghost-town profile, apartment street)
	_grid(p, "z", 0, -d / 2, w, g, floors, fh, 5, rng, frame="DADCDE", broken=0.3, boarded=0.1)
	_grid(p, "z+", 0, d / 2, w, g, floors, fh, 5, rng, frame="DADCDE", broken=0.3)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 2, rng, frame="DADCDE", broken=0.3)
		_stains(p, face, cx, 0, d, g, h - g, rng, n=2, patches=1)
	_stains(p, "z", 0, -d / 2, w, g, h - g, rng, n=6, patches=2)
	for fl in range(floors):
		y = g + fl * fh
		p.append(("box", (w, 0.7, 3), (0, y + 0.2, -d / 2 - 1.5), "B4B8BC"))
		p.append(("box", (w, 1.8, 0.3), (0, y + 1.3, -d / 2 - 2.9), "D2D4D6", {"rough": 0.6}))
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
	p.append(("box", (6, h + 4, 7), (w / 2 + 3, (h + 4) / 2, 2), "A8ACB0"))  # plain outside stair core
	for fl in range(floors + 1):
		p.append(("box", (6.4, 0.6, 7.4), (w / 2 + 3, g + fl * fh - 0.5, 2), "B4B8BC"))
		if fl < floors:
			p.append(("box", (0.3, 4, 1.6), (w / 2 + 6.05, g + fl * fh + 4, 2), DARK))  # slit window
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
	body, frame = "A4AAB0", "C2C6CA"  # light cool grey
	p = [("box", (w, h, d), (0, h / 2, 0), body)]
	_grid(p, "z", 0, -d / 2, w - 4, g, floors, fh, 6, rng, glass=GLASS2, frame=frame, broken=0.25)
	_grid(p, "z+", 0, d / 2, w - 4, g, floors, fh, 4, rng, glass=GLASS2, frame=frame, broken=0.1)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, floors, fh, 4, rng, glass=GLASS2, frame=frame, broken=0.15)
	_stains(p, "z", 0, -d / 2, w, g, h - g, rng, n=6, patches=2)
	for x in (-w / 2, w / 2):
		for z in (-d / 2, d / 2):
			p.append(("box", (2.4, h, 2.4), (x, h / 2, z), "D0D4D8"))
	p.append(("box", (w - 6, g - 2, 0.4), (0, (g - 2) / 2, -d / 2 - 0.2), "1A1E24", {"rough": 0.2}))
	p.append(("box", (w + 2, 1, 6), (0, g - 1.5, -d / 2 - 3), "9A948A"))
	p.append(("box", (w - 8, 12, d - 8), (0, h + 6, 0), "8E9296"))
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
	p = [("box", (w, hs, d), (0, hs / 2, 0), "8A5A46")]  # brick block
	_grid(p, "z", 0, -d / 2, w - 2, g, 9, fh, 5, rng, broken=0.55, boarded=0.1)
	_grid(p, "z+", 0, d / 2, w - 2, g, 9, fh, 4, rng, broken=0.3)
	for face, cx in (("x+", w / 2), ("x-", -w / 2)):
		_grid(p, face, cx, 0, d - 4, g, 9, fh, 3, rng, broken=0.4)
	_stains(p, "z", 0, -d / 2, w, g, hs - g, rng, n=5, patches=2)
	# Left half stands two storeys higher as a bare frame: floor slabs on stub columns, broken edges, rebar
	for j in range(2):
		y = hs + (j + 1) * fh
		lw = w * (0.55 - j * 0.12)
		p.append(("box", (lw, 1, d), (-w / 2 + lw / 2, y, 0), "8E887E", {"rot": (rng.uniform(-2, 2), 0, rng.uniform(-3, 3))}))
		for x in (-w / 2 + 1.2, -w / 2 + lw - 1.5):
			for z in (-d / 2 + 1.2, 0, d / 2 - 1.2):
				p.append(("box", (1.4, fh, 1.4), (x, y - fh / 2, z), "A8A296"))
		_rebar(p, -w / 2 + lw, y, 0, 3, rng, spread=5)
	# Right half sheared off: floor slabs pancaked and hanging down off the shaft edge at steep angles
	for j, ang in enumerate((38, 55, 70)):
		ln = w * 0.5
		ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
		x0, y0 = w / 2 - 0.5, hs + 0.5 - j * fh * 1.2  # peeled floors hinged on the facade edge, dangling outward
		p.append(("box", (ln, 1.1, d - 2 - j * 3), (x0 + ca * ln / 2, y0 - sa * ln / 2, rng.uniform(-1.5, 1.5)), ("8E887E", "9A948A", "7E786E")[j], {"rot": (0, 0, -ang)}))
		_rebar(p, x0, y0, 0, 1, rng, spread=3)
	p.append(("box", (20, 44, 14), (w / 2 + 6, 16, -6), CONC, {"rot": (6, 20, -22)}))
	p.append(("box", (16, 30, 0.4), (w / 2 + 2, 16, -13.2), GLASS, {"rot": (6, 20, -22)}))
	_rebar(p, w / 2 + 10, 34, -6, 3, rng)
	for i in range(5):
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
	for x0, x1 in ((-30, -16), (12, 28)):  # low block wall with a brown railing on it, shrubs behind (ref apartment street)
		xm, ln = (x0 + x1) / 2, x1 - x0
		p.append(("box", (ln, 1.6, 1.0), (xm, 0.8, 3.2), "9A968C"))
		for y in (2.6, 3.9):
			p.append(("box", (ln, 0.25, 0.25), (xm, y, 3.2), "4A3426"))
		for i in range(int(ln / 2) + 1):
			p.append(("box", (0.22, 2.4, 0.22), (x0 + i * 2, 2.8, 3.2), "4A3426"))
		for i in range(3):
			p.append(("ball", (4.2, 3.4, 3.2), (x0 + 2.5 + i * (ln - 5) / 2, 2.6, 5.4), ("4E6B3A", "5E7E44", "445E32")[i], {"subdiv": 1, "smooth": True}))
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
	"""Hero, infield: a deep impact pit torn into a city street (refs Z-City_Street_Crater, Meteor_fragment_aftermath).
	The ground cannot be cut, so the street is a raised flat asphalt plateau, HP high, around a narrow pit (RP radius:
	walls more than half the pit's width tall). Its front (-Z, turned to the road camera) is broken down to a low street
	lip with a lane dash and kerbs running to the hole, so the deep dark walls and the pipe face that camera. 7 large
	grey asphalt plates overhang the hole; the walls are jagged mottled stacks of dark earth; a light-grey sewer pipe
	(about a quarter of the pit's width) juts from the right wall, turns down at an elbow and ends in a wide bell
	collar. Footprint radius about 145."""
	EARTH = ("454038", "302822", "16130F", "3A3630")  # grey-brown, dark umber, near-black, grey
	TOPC, PLATE = "4A4846", ("6A6864", "5E5C58", "747270")
	RP, RO, HP, HL = 40, 104, 46, 7  # pit radius, plateau edge, plateau height, front lip height

	def height(a):  # plateau height at angle a: low across the front notch (-Z), full elsewhere
		off = abs((math.degrees(a) - 270 + 180) % 360 - 180)
		w = max(0.0, min(1.0, (off - 48) / 20))
		return HL + (HP - HL) * w

	p = [("cyl", (288, 0.2, 288), (0, 0.1, 0), "46443F", {"seg": 32}), ("cyl", (RP * 2 + 6, 0.3, RP * 2 + 6), (0, 0.2, 0), "0C0A08", {"seg": 20})]
	n = 32
	for i in range(n):  # the plateau ring with a ragged outer slope of heaved asphalt
		a = (i + 0.5) * math.tau / n
		c, s = math.cos(a), math.sin(a)
		h = height(a)
		rr = {"rot": (0, -math.degrees(a) + 90, 0)}
		p.append(("box", (22, h - 2, RO - RP + 2), (c * (RP + RO) / 2, (h - 2) / 2, s * (RP + RO) / 2), EARTH[i % 2], rr))  # earth body: the notch flanks show dark
		p.append(("box", (22.4, 2.4, RO - RP + 2), (c * (RP + RO) / 2, h - 1, s * (RP + RO) / 2), TOPC, rr))  # asphalt crust
		sk = rng.uniform(22, 32) if h > HL + 1 else 10
		hs = h * rng.uniform(0.85, 0.98)
		p.append(("wedge", (23, hs, sk), (c * (RO + sk / 2 - 1), hs / 2, s * (RO + sk / 2 - 1)), ("3E3C39", "36342F")[i % 2], {"rot": (0, math.degrees(math.atan2(-c, -s)), 0)}))
	for i in range(40):  # pit walls: tall jagged stacks of mottled dark earth, no grid
		a = (i + rng.uniform(-0.4, 0.4)) * math.tau / 40
		c, s = math.cos(a), math.sin(a)
		H = height(a)
		y = 0.0
		while y < H - 0.5:
			hj = min(H - y, rng.uniform(4, 9))
			r = RP + rng.uniform(-1, 3.5)
			p.append((rng.choice(("wedge", "box", "wedge")), (rng.uniform(7, 12), hj + 1.5, rng.uniform(5, 9)), (c * r, y + hj / 2, s * r), rng.choice(EARTH), {"rot": (rng.uniform(-8, 8), -math.degrees(a) + 90 + rng.uniform(-12, 12), rng.uniform(-10, 10))}))
			y += hj * rng.uniform(0.7, 0.95)
	# 7 large grey asphalt plates overhanging the hole, tilted down into it, dark earth caked under them
	for i, deg in enumerate((262, 300, 345, 30, 90, 150, 205)):
		a = math.radians(deg + rng.uniform(-8, 8))
		c, s = math.cos(a), math.sin(a)
		r = RP + rng.uniform(5, 8)
		y = height(a) + 1.5
		rot = (-rng.uniform(10, 22), -math.degrees(a) + 90 + rng.uniform(-15, 15), rng.uniform(-8, 8))
		w, dd = rng.uniform(26, 36), rng.uniform(22, 28)
		p.append(("box", (w, 4, dd), (c * r, y, s * r), PLATE[i % 3], {"rot": rot}))
		p.append(("box", (w * 0.85, 3, dd * 0.8), (c * (r + 1.5), y - 3.2, s * (r + 1.5)), EARTH[i % 4], {"rot": rot}))
	# the street on the low front lip: a lane dash and two kerbs with a reddish sidewalk, all running to the hole
	for j in range(5):
		p.append(("box", (1.4, 0.2, 7), (0, HL + 0.1, -(RP + 10 + j * 13)), "D8D2C0"))
	z0 = math.sqrt(RP * RP - 28 * 28) + 3
	ln = RO + 8 - z0
	for sx in (-1, 1):
		p.append(("box", (1.6, 1.0, ln), (sx * 28, HL + 0.5, -(z0 + ln / 2)), "9A968C"))
		p.append(("box", (12, 0.5, ln), (sx * 35, HL + 0.25, -(z0 + ln / 2)), "7A5A4A"))
		p.append(("box", (0.5, 0.06, ln), (sx * 30, HL + 0.53, -(z0 + ln / 2)), "D8B23A"))
	# the sewer pipe on the right wall (seen from the front), about a quarter of the pit's width
	PIPE, PJ = "8E8C88", "76746F"
	p += [
		("cyl", (19, 30, 19), (-RP - 2, 30, 6), PIPE, {"seg": 14, "rot": (0, 0, 78)}),
		("cyl", (22, 3, 22), (-RP + 6, 28.4, 6), PJ, {"seg": 14, "rot": (0, 0, 78)}),
		("ball", (19.5, 19.5, 19.5), (-RP + 15, 26.5, 6), PIPE, {"subdiv": 2, "smooth": True}),
		("cyl", (19, 10, 19), (-RP + 16, 19.5, 6), PIPE, {"seg": 14}),
		("cyl", (28, 13, 28), (-RP + 16, 8.5, 6), PJ, {"seg": 16}),
		("cyl", (29.5, 2, 29.5), (-RP + 16, 14.6, 6), PIPE, {"seg": 16}),
		("cyl", (23, 0.6, 23), (-RP + 16, 15.4, 6), "1A1816", {"seg": 16}),
	]
	for j in range(9):  # rock clods and plate chunks fallen to the pit floor
		a = rng.uniform(0, math.tau)
		sz = rng.uniform(5, 10)
		r = rng.uniform(4, 30)
		p.append(("ball", (sz, sz * 0.7, sz), (math.cos(a) * r, sz * 0.3, math.sin(a) * r), EARTH[j % 4], {"subdiv": 1}))
	for j in range(8):  # asphalt chunks on the plateau
		a = rng.uniform(0, math.tau)
		r = rng.uniform(55, 95)
		sz = rng.uniform(4, 8)
		p.append(("box", (sz, 2.2, sz * 0.8), (math.cos(a) * r, height(a) + 1, math.sin(a) * r), PLATE[j % 3], {"rot": (rng.uniform(-25, 25), rng.uniform(0, 90), rng.uniform(-25, 25))}))
	# a wrecked block leaning on the back of the plateau (ref Meteor_fragment_aftermath): body, dark storey bands, rebar
	rot, yb = (0, 0, -16), HP
	p.append(("box", (22, 46, 16), (-40, yb + 20, 72), CONC2, {"rot": rot}))
	for b in (-14, -4, 6, 16):
		p.append(("box", (22.4, 3, 16.4), (-40 + b * math.sin(math.radians(16)), yb + 20 + b * math.cos(math.radians(16)), 72), "1E2226", {"rot": rot}))
	_rebar(p, -36, yb + 42, 72, 4, rng, spread=5)
	for i in range(12):  # cracks out from the slope, flat on the street
		a = i * math.tau / 12 + 0.2
		ln = rng.uniform(8, 12)
		p.append(("box", (ln, 0.1, 1.8), (math.cos(a) * (RO + 30 + ln / 2), 0.15, math.sin(a) * (RO + 30 + ln / 2)), "141210", {"rot": (0, -math.degrees(a) + rng.uniform(-12, 12), 0)}))
	return k.prop("Crater", p)


def _clear_seg(k, x, z, r):
	"""True when (x, z) is more than r from every lap's centre line, measured to the segments (kit.clear_of_road only
	checks the waypoints, which sit far apart on long straights)."""
	for a, b in zip(k.wps, k.wps[1:]):
		vx, vz = b.x - a.x, b.z - a.z
		ln2 = vx * vx + vz * vz or 1e-9
		t = max(0.0, min(1.0, ((x - a.x) * vx + (z - a.z) * vz) / ln2))
		if math.hypot(x - a.x - vx * t, z - a.z - vz * t) < r:
			return False
	return True


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

	k.ground("4A4744", margin=9000)  # reaches out under the HQ on the skyline
	_fill(k, "3E3C3A")
	L = k.length
	c = (k.lo + k.hi) / 2
	# Street grid: block tiles wherever no road runs, kept off the crater
	x = k.lo.x - 700
	while x < k.hi.x + 700:
		z = k.lo.z - 700
		while z < k.hi.z + 700:
			if math.hypot(x - c.x, z - c.z) > 300 and k.clear_of_road(x, z, 190) and k.owns(x, z) and _on_ground(k, x, z):
				k.place("Blocks", (x, -1.0, z), 0.0)
			z += TILE
		x += TILE
	# Kerb line: pole sets at a fixed spacing (their wires reach the next pole), then cordons and rubble
	_row(k, POLE_GAP, 29, ["Kerb"], start=20, clear=25)
	_row(k, 75, 37, ["Barricade", "Rubble", "Barricade"], jitter=1.5, start=50, clear=28)
	# Street walls: apartments and offices, then high-rises behind
	_row(k, 48, 58, ["MidRise", "OfficeBroken", "MidRise", "Collapsed"], jitter=3, start=30)
	_row(k, 80, 108, ["MidRise", "Collapsed", "HighRise", "OfficeBroken"], jitter=8, start=20)
	_row(k, 140, 175, ["HighRise", "OfficeBroken", "Collapsed"], jitter=15, start=50, scale=(1.0, 1.5), yaw_jit=0.4)
	# Wide layout (WORLD2_SPEC "World 2 track layout", 2026-11-26; re-fit round 2): the city goes on in depth over this
	# track's own band out to about its midline (380 studs), at about the approved density of buildings, instead of
	# ending at 175. The outer row keeps to mid-rises (no tower in the band's outer 100 studs). Proposed.
	_row(k, 58, 235, ["HighRise", "OfficeBroken", "MidRise", "Collapsed", "MidRise"], jitter=18, start=35, scale=(1.0, 1.4), yaw_jit=0.35)
	_row(k, 52, 300, ["MidRise", "OfficeBroken", "Collapsed", "MidRise"], jitter=20, start=20, scale=(1.0, 1.3), yaw_jit=0.4)
	_row(k, 50, 355, ["Collapsed", "MidRise", "OfficeBroken"], jitter=12, start=45, scale=(0.9, 1.2), yaw_jit=0.5)
	# The 0.9 view looks down the last straight past the finish onto the next track's ground: towers flanking the last
	# stretch (clear of the checkpoint apron and the WinPad) close the skyline at its end. Proposed.
	for dd, off, sc in ((230, -95, 1.45), (180, 100, 1.4), (140, -120, 1.3), (300, 120, 1.35), (95, 135, 1.25), (260, -150, 1.3)):
		pos, yaw = k.beside(L - dd, off)
		if k.clear_of_road(pos[0], pos[2], abs(off) * 0.9) and k.owns(pos[0], pos[2]) and _on_ground(k, pos[0], pos[2]):
			_clear_near(k, pos[0], pos[2], 34, ("MidRise", "OfficeBroken", "Collapsed", "HighRise"))
			k.place("HighRise", (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2), sc)
	BUILD = ("MidRise", "OfficeBroken", "Collapsed", "HighRise")
	# Expressway crossings on flat straights, piers clear of every lap (none in front of the 33% view: it frames the HQ)
	for f in (0.14, 0.45, 0.72):
		for step in range(20):
			d = L * f + 60 + step * 15
			p0, _, _ = k.at(d - 40)
			p1, _, _ = k.at(d + 40)
			pos, yaw = k.beside(d, 0, 1.0)
			_, right, _ = k.at(d)
			piers = [(pos[0] + right.x * s, pos[2] + right.z * s) for s in (-44, 44, 95)]
			if abs(p0.y - p1.y) < 0.5 and p0.y < 1.6 and all(k.clear_of_road(x, z, 26) for x, z in piers):
				k.place("Overpass", pos, yaw)  # local X runs across the road
				break
	# The crater in the infield; the infield and the outskirts fill with ruins, away from its bowl
	if k.owns(c.x, c.z):  # the wide layout's box centre is another track's ground: no infield crater there
		k.place("Crater", (c.x, -1.0, c.z), 0.3, 1.5)
	for count, names, clearance, margin, scale in (
		(25, ["Rubble", "Rubble", "Kerb"], 50, 300, (0.8, 1.5)),
		(30, ["HighRise", "Collapsed", "MidRise", "OfficeBroken", "MidRise", "OfficeBroken"], 130, 220, (0.9, 1.3)),  # no lone towers out on the plain
	):
		placed, tries = 0, 0
		while placed < count and tries < count * 300:  # most of the wide layout's box is other tracks' ground
			tries += 1
			x = rng.uniform(k.lo.x - margin, k.hi.x + margin)
			z = rng.uniform(k.lo.z - margin, k.hi.z + margin)
			if math.hypot(x - c.x, z - c.z) > 250 and k.clear_of_road(x, z, clearance) and k.owns(x, z) and _on_ground(k, x, z):
				name = rng.choice(names)
				if name == "HighRise" and k.clear_of_road(x, z, 280):
					name = "MidRise"  # no tower in the band's outer 100 studs
				k.place(name, (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(*scale))
				placed += 1
	# Heights vary instance to instance (Roblox: Size.Y on the same mesh)
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.name.split("_")[2] in BUILD:
			ob.scale[2] *= rng.uniform(0.75, 1.3)
	# 01: the hero's apartment on the right, its blank end wall turned toward the camera, the balconies in view
	e, t = _eye(k, 0.06)
	_, right, _ = k.at(L * 0.06)
	# 136 studs on along the road and 72 right of it from the 0.06 point (on a straight: 150 ahead of the eye, 62 right of
	# it, as approved); along the road, so in a bend it keeps its place beside the road (2026-11-26 re-fit)
	(ax, _, az), _ = k.beside(L * 0.06 + 136, 72)
	pos, yaw = k.beside(L * 0.06 + 81, 52)
	_clear_view(k, e, ax, az, 40, BUILD + ("Kerb", "Rubble", "Barricade"))
	_clear_near(k, ax, az, 42, BUILD + ("Rubble", "Barricade"))
	# front (-Z, the balconies) turned 45 degrees off the line to the camera: balconies and end wall both in view
	to_cam = Vector((e.x - ax, 0, e.z - az)).normalized()
	ca, sa = math.cos(math.radians(45)), math.sin(math.radians(45))
	f = Vector((to_cam.x * ca - to_cam.z * sa, 0, to_cam.x * sa + to_cam.z * ca))
	k.place("SaitamaApt", (ax, -1.0, az), math.atan2(-f.x, -f.z))
	# 01: a cordon (yellow-black barrier, fence, white board) on the left across the side street
	pos, yaw = k.beside(L * 0.06 + 45, -33)
	_clear_near(k, pos[0], pos[2], 20, ("Rubble", "Barricade"))
	k.place("Barricade", (pos[0], -1.0, pos[2]), yaw - math.pi / 2)
	# 01 and 04: the street kit close along the run views: utility poles with wires, street trees, vending machines, low
	# railing walls with shrubs (refs Saitamas_Apartment_Anime, Z-City_Street_Crater); none in the apartment's sight line
	for f in (0.06, 0.9):
		d0 = L * f
		for i in range(10):
			d = d0 - 10 + i * 30
			for side in (-1, 1):
				if f == 0.06 and side > 0 and 40 < d - d0 < 140:
					continue
				for off in (31, 35, 39):  # inside a bend the pole's straight wires need more room
					pos, yaw = k.beside(d, side * off)
					if k.clear_of_road(pos[0], pos[2], off - 4) and k.owns(pos[0], pos[2]):
						break
				else:
					continue
				_clear_near(k, pos[0], pos[2], 12, ("Kerb", "Rubble", "Barricade"))
				k.place("Kerb", (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if side > 0 else -math.pi / 2))
	# 03 and 04: half-collapsed blocks close to the road ahead
	for f, ahead, off in ((0.62, 110, 54), (0.62, 170, -54), (0.9, 150, 54)):
		pos, yaw = k.beside(L * f + ahead, off)
		if k.clear_of_road(pos[0], pos[2], 46):
			_clear_near(k, pos[0], pos[2], 36, BUILD)
			k.place("Collapsed", (pos[0], -1.0, pos[2]), yaw + (math.pi / 2 if off > 0 else -math.pi / 2))
	# 04: an intact balconied mid-rise leaning about 20 degrees along the street onto a high-rise neighbour, rubble
	# heaped at its base (ref Meteor_fragment_aftermath); the same meshes, the lean is the instance's own rotation
	for ahead, off in ((100, -60), (100, 60), (150, -60), (60, -62)):
		p, right, t = k.at(L * 0.9 + ahead)
		base = p + right * off
		nb = base + t * 52
		if not (k.clear_of_road(base.x, base.z, 46) and k.clear_of_road(nb.x, nb.z, 46)):
			continue
		_clear_near(k, base.x, base.z, 40, BUILD + ("Rubble", "Kerb", "Barricade"))
		_clear_near(k, nb.x, nb.z, 30, BUILD)
		_, yaw = k.beside(L * 0.9 + ahead, off)
		yaw += math.pi / 2 if off > 0 else -math.pi / 2
		ob = k.place("MidRise", (base.x, -3.5, base.z), yaw)
		lean = math.radians(20) * (1 if math.cos(yaw) * t.x - math.sin(yaw) * t.z > 0 else -1)  # top toward +t
		ob.rotation_euler = (0, lean, yaw)
		k.place("HighRise", (nb.x, -1.0, nb.z), yaw)
		for dt, dr, sc in ((-16, 0, 1.5), (-6, 8, 1.2), (8, -4, 1.3)):
			q = base + t * dt + right * (dr if off > 0 else -dr)
			k.place("Rubble", (q.x, -1.0, q.z), yaw + dt * 0.1, sc)
		break
	# 03 / 04: a second crater close beside the road ahead, inside the 62% or the 90% view; sight line cleared
	done = False
	for f in (0.62, 0.9):
		e, t = _eye(k, f)
		for dist in (200, 240, 280, 320, 380, 450):
			for deg in (18, -18, 26, -26, 10, -10):
				a = math.radians(deg)
				x = e.x + (t.x * math.cos(a) - t.z * math.sin(a)) * dist
				z = e.z + (t.x * math.sin(a) + t.z * math.cos(a)) * dist
				if _clear_seg(k, x, z, 210):  # crater radius about 182 at this scale, plus the 24-stud rule
					_clear_near(k, x, z, 200, BUILD + ("Kerb", "Rubble", "Blocks", "Barricade"))
					_clear_view(k, e, x, z, 110, BUILD)
					fc = Vector((e.x - x, 0, e.z - z)).normalized()  # the low front notch turned to the camera
					k.place("Crater", (x, -1.0, z), math.atan2(-fc.x, -fc.z), 1.25)
					done = True
					break
			if done:
				break
		if done:
			break
	# 02: the infield crater (approved: scale 1.5, turn 0.3, the dark bowl the 33% view looks at). Its approved spot, the
	# track box's centre, is another track's ground on the wide layout, so it stands beside the road ahead of the 0.33
	# camera instead, its whole bowl clear of every road (24 studs), its base centre on this track's own ground and Ground
	# rect, the sight line to it cleared; not on the 0.62 crater or an overpass (re-fit round 2, proposed spot).
	e, t = _eye(k, 0.33)
	side = Vector((-t.z, 0, t.x))
	spot = None
	others = [(ob.location.x, -ob.location.y) for ob in k.col.objects if ob.type == "MESH" and ob.name.split("_")[2] in ("Crater", "Overpass")]
	for dist in range(350, 1301, 50):
		for lat in (260, -260, 285, -285, 310, -310):
			x, z = e.x + t.x * dist + side.x * lat, e.z + t.z * dist + side.z * lat
			if (
				_clear_seg(k, x, z, 218 + 24)
				and k.owns(x, z)
				and _on_ground(k, x, z)
				and all(math.hypot(x - a, z - b) > 300 for a, b in others)
			):
				spot = (x, z)
				break
		if spot:
			break
	if spot:
		x, z = spot
		_clear_near(k, x, z, 240, BUILD + ("Kerb", "Rubble", "Blocks", "Barricade"))
		# the street walls between the camera and the bowl go, in a wedge widening to the bowl's width, so the low dark
		# plateau (about 69 studs high at 1.5) shows from the runner's lane
		vx, vz = x - e.x, z - e.z
		ln = math.hypot(vx, vz)
		for ob in list(k.col.objects):
			if ob.type != "MESH" or ob.name.split("_")[2] not in BUILD:
				continue
			ox, oz = ob.location.x - e.x, -ob.location.y - e.z
			u = (ox * vx + oz * vz) / (ln * ln)
			if 0.02 < u < 1.05 and abs(ox * vz - oz * vx) / ln < 25 + 225 * u:
				k.col.objects.unlink(ob)
		k.place("Crater", (x, -1.0, z), 0.3, 1.5)
		print("CRATER 033 at", round(x), round(z))
	else:
		print("CRATER 033: no spot")
	# The Hero Association HQ dominating the skyline, dead ahead of the 33% view (ref New_Hero_Association_Headquarters_
	# Anime): the nearest spot along that view's heading where its whole footprint clears the road; big enough to fill
	# about a quarter of the frame height; the street corridor toward it cleared
	e, t = _eye(k, 0.33)
	hq, hq_scale = None, 3.0
	for dist in range(1500, 9001, 100):
		sc = max(2.3, dist / 800)
		q = Vector((e.x + t.x * dist, 0, e.z + t.z * dist))
		if k.clear_of_road(q.x, q.z, 660 * sc + 40):
			hq, hq_scale = q, sc
			break
	if hq is None:
		hq, hq_scale = Vector((k.hi.x + 1240, 0, k.lo.z - 1620)), 2.3
	print("HQ", hq, hq_scale)
	_clear_view(k, e + t * 420, hq.x, hq.z, 160, BUILD)  # only past the end of the straight: the street walls stay
	k.place("HeroHQ", (hq.x, -1.0, hq.z), 0.4, hq_scale)
	# 05: the side camera's street: buildings cleared, wrecks, vending machines, cordons and overgrowth at street level
	p, right, t = k.at(L * 0.48)
	g = p + right * 140 - t * 60
	_clear_near(k, g.x, g.z, 120, BUILD)
	placed, tries = 0, 0
	while placed < 26 and tries < 600:
		tries += 1
		x, z = p.x + right.x * rng.uniform(40, 150) + t.x * rng.uniform(-110, 110), p.z + right.z * rng.uniform(40, 150) + t.z * rng.uniform(-110, 110)
		if k.clear_of_road(x, z, 34) and k.owns(x, z):
			k.place(("Rubble", "Kerb", "Rubble", "Barricade")[placed % 4], (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(0.9, 1.4))
			placed += 1
	# 05: the side view's frame beyond its wreck street: empty lots (Blocks tiles with no building on them) get the approved
	# buildings at approved scales, facing the road, so the frame is a city, not grey lots (re-fit round 2, proposed)
	near = [(ob.location.x, -ob.location.y) for ob in k.col.objects if ob.type == "MESH" and ob.name.split("_")[2] in BUILD + ("Crater", "Overpass", "SaitamaApt")]
	street = lambda x, z: abs((x - p.x) * t.x + (z - p.z) * t.z) < 130 and 20 < (x - p.x) * right.x + (z - p.z) * right.z < 165  # noqa: E731
	filled = 0
	for along in range(-420, 421, 44):
		for lat in list(range(-370, -50, 44)) + list(range(66, 371, 44)):
			q = p + t * (along + rng.uniform(-8, 8)) + right * (lat + rng.uniform(-8, 8))
			if street(q.x, q.z) or not (k.owns(q.x, q.z) and _on_ground(k, q.x, q.z) and _clear_seg(k, q.x, q.z, 58)):
				continue
			if any(math.hypot(q.x - a, q.z - b) < 34 for a, b in near):
				continue
			name = rng.choice(("MidRise", "OfficeBroken", "Collapsed", "MidRise") if abs(lat) > 270 else ("MidRise", "OfficeBroken", "Collapsed", "HighRise"))
			_, yaw = k.beside(L * 0.48 + along, lat)
			ob = k.place(name, (q.x, -1.0, q.z), yaw + (math.pi / 2 if lat > 0 else -math.pi / 2) + rng.uniform(-0.3, 0.3), rng.uniform(1.0, 1.3))
			ob.scale[2] *= rng.uniform(0.75, 1.3)
			near.append((q.x, q.z))
			filled += 1
	print("05 INFILL", filled)
	k.sky([(0.0, "E2DCCC"), (0.07, "C6CFD4"), (0.3, "8FB4D8"), (1.0, "3C74BE")], strength=1.0, sun=(4.0, "FFEED6", 46, 150))
	_enforce_clearance(k)
