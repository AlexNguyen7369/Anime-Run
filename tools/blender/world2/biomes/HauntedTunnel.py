"""World 2 Track 4: the haunted tunnel road (Dandadan), at night. The mountain road where the turbo granny haunts the
old tunnel: steep forested slopes of tall cedars, curve mirrors and guard posts, a long concrete tunnel over the
road with flickering lamps, plain torii-like gates over the stone stair climbs, a small hillside shrine with stone
lanterns, and the high school with its gate and fence. Moonlight, with a green-cyan ghostly glow of floating wisps.
The tunnel roof and the gates span the road with their undersides 16+ studs above it (TRACKS_AND_BIOMES_SPEC
"Biomes"). No symbols, plaques or text (design doc 5). Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

CEDAR, CEDAR2, BARK, MOSS = "1F3A2C", "2A4A36", "3A2A20", "33463A"
CONC, CONC2, STONE, VERM = "8A8E88", "6A6E6A", "777A74", "B8402E"
GHOST, GHOST2, LAMP, SICK = "5CFFD0", "3BE8FF", "FFE7A8", "D8F070"
TUNNEL = (1790.0, 2100.0)  # the 335-stud straight after the wisteria bends: flat and straight


def _fill(k, color):
	"""Stone under the raised road (the game's hill supports), so the stair climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width - 1, step + 0.5, p.y + 0.5)
		d += step


def _grounded(k, skip=()):
	"""k.along on the ground (y = -1), turned so the prop's -Z really faces the road, and kept out of `skip`
	(a, b, side) ranges: side 0 both sides, else only that side. Returns the original beside."""
	orig = k.beside

	def beside(d, off, y=0.0):
		(x, _, z), yaw = orig(d, off, y)
		if any(a <= d <= b and (side == 0 or side * off > 0) for a, b, side in skip):
			return (x, -500.0, z), yaw  # sunk out of sight; shortcut: wastes an instance, fine for a draft
		return (x, -1.0 + y, z), yaw  # kit.along now turns -Z to face the road

	k.beside = beside
	return orig


def _scatter(k, count, names, clearance, margin, scale, avoid):
	"""k.field, also keeping out of circles `avoid` [(x, z, r)] (the school grounds)."""
	placed, tries = 0, 0
	while placed < count and tries < count * 20:
		tries += 1
		x = k.rng.uniform(k.lo.x - margin, k.hi.x + margin)
		z = k.rng.uniform(k.lo.z - margin, k.hi.z + margin)
		if all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid) and k.clear_of_road(x, z, clearance):
			k.place(k.rng.choice(names), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))
			placed += 1


def build(k):
	# Japanese cedars: tall straight trunk, stacked narrow cones (two shades)
	for i, (h, col) in enumerate(((44, CEDAR), (56, CEDAR2), (36, CEDAR))):
		parts = [("cyl", (2, h * 0.5, 2), (0, h * 0.25, 0), BARK, {"seg": 6})]
		for j in range(4):
			r = 14 - j * 3
			parts.append(("cone", (r, h * 0.38, r), (0, h * 0.3 + j * h * 0.16 + h * 0.19, 0), col, {"seg": 7}))
		k.prop("Cedar%d" % i, parts)
	# Mountain slope ridge (long low hill facing the road) and far peaks
	k.prop("Ridge", [("wedge", (90, 40, 50), (0, 20, 0), MOSS, {"rot": (0, 180, 0)}), ("cone", (40, 50, 40), (10, 30, 18), CEDAR, {"seg": 7})])
	k.prop("Peak", [("cone", (420, 260, 420), (0, 130, 0), "1A2A26", {"seg": 9}), ("cone", (200, 160, 200), (120, 80, 60), "203430", {"seg": 8})])
	# Mountain-road furniture: a curve mirror on an orange pole, a guard post pair
	k.prop(
		"Mirror",
		[
			("cyl", (0.8, 12, 0.8), (0, 6, 0), "E07A2A", {"seg": 8}),
			("cyl", (4, 0.6, 4), (0, 12.5, -0.6), "E07A2A", {"seg": 12, "rot": (90, 0, 0)}),
			("cyl", (3.4, 0.4, 3.4), (0, 12.5, -1.0), "BFE8FF", {"seg": 12, "rot": (90, 0, 0), "rough": 0.1, "metal": 0.8}),
		],
	)
	k.prop("Posts", [("cyl", (1, 4, 1), (x, 2, 0), "E8E8E0", {"seg": 6}) for x in (-6, -2, 2, 6)] + [("box", (14, 0.8, 0.4), (0, 3, -0.6), "E8E8E0")])
	# Ghost wisps: floating green-cyan glows (a cluster)
	k.prop("Wisp", [("ball", (s, s, s), (x, y, z), c, {"emit": 9}) for s, x, y, z, c in ((2.4, 0, 10, 0, GHOST), (1.6, 4, 13, 2, GHOST2), (1.2, -3, 15, -1, GHOST), (1.0, 2, 7, -3, GHOST2))])
	# Tunnel: concrete side walls (inner faces at 25 studs), flat roof with its underside 16 above the road,
	# earth and cedars on top. One 12-stud slice, laid end to end. Lamps on the walls at 24.4 studs.
	k.prop(
		"TunnelSeg",
		[
			("box", (5, 20, 13), (-27.5, 9, 0), CONC),
			("box", (5, 20, 13), (27.5, 9, 0), CONC),
			("box", (62, 5, 13), (0, 19.5, 0), CONC2),
			("box", (80, 8, 13), (0, 26, 0), MOSS),
		],
	)
	k.prop(
		"TunnelLamp",
		[("box", (0.6, 1.2, 3), (-24.7, 13, 0), SICK, {"emit": 7}), ("box", (0.6, 1.2, 3), (24.7, 13, 0), LAMP, {"emit": 7})],
	)
	# Portal face at each mouth: a thick concrete headwall around the opening and a hill of cedars above
	k.prop(
		"Portal",
		[
			("box", (24, 34, 6), (-37, 16, 0), CONC2),
			("box", (24, 34, 6), (37, 16, 0), CONC2),
			("box", (98, 12, 6), (0, 28, 0), CONC2),
			("box", (100, 2, 7), (0, 34.5, 0), CONC),
			("wedge", (140, 50, 70), (0, 57, 34), MOSS, {"rot": (0, 180, 0)}),
			("cone", (16, 34, 16), (-30, 75, 40), CEDAR, {"seg": 7}),
			("cone", (18, 40, 18), (20, 80, 50), CEDAR2, {"seg": 7}),
		],
	)
	# Plain torii-like gate spanning the road (posts at 27, lower beam underside 17 above y0)
	k.prop(
		"Gate",
		[
			("cyl", (3, 26, 3), (-27, 13, 0), VERM, {"seg": 10}),
			("cyl", (3, 26, 3), (27, 13, 0), VERM, {"seg": 10}),
			("box", (62, 2, 2), (0, 19, 0), VERM),
			("box", (72, 2.4, 3.6), (0, 25.5, 0), VERM),
			("box", (74, 1.2, 4), (0, 27.2, 0), "2A2224"),
		],
	)
	# Hillside shrine: stone platform with steps, small hall with a pitched roof, stone lanterns, a small gate
	k.prop(
		"Shrine",
		[
			("box", (50, 20, 44), (0, 10, 6), STONE),
			("wedge", (16, 20, 26), (0, 10, -29), STONE),
			("box", (20, 10, 16), (0, 25, 12), "6A4A34"),
			("wedge", (24, 7, 10), (0, 33.5, 7), "2A2C30"),
			("wedge", (24, 7, 10), (0, 33.5, 17), "2A2C30", {"rot": (0, 180, 0)}),
			("cyl", (1.6, 12, 1.6), (-8, 26, -8), VERM, {"seg": 8}),
			("cyl", (1.6, 12, 1.6), (8, 26, -8), VERM, {"seg": 8}),
			("box", (22, 1.2, 1.6), (0, 32, -8), VERM),
			("box", (19, 1, 1.2), (0, 29.5, -8), VERM),
			("box", (2.4, 5, 2.4), (-14, 22.5, -6), STONE),
			("box", (2, 1.6, 2), (-14, 25, -6), LAMP, {"emit": 4}),
			("box", (2.4, 5, 2.4), (14, 22.5, -6), STONE),
			("box", (2, 1.6, 2), (14, 25, -6), LAMP, {"emit": 4}),
		],
	)
	# The high school: a long 3-floor block, stair tower, gym, gate pillars and a fence along the front
	school = [
		("box", (150, 36, 30), (0, 18, 0), "D8D4C8"),
		("box", (152, 1.5, 32), (0, 36.7, 0), "9A9890"),
		("box", (20, 46, 20), (-55, 23, -4), "CFCAB8"),
		("box", (60, 26, 50), (95, 13, 25), "B8B4A8"),
		("wedge", (60, 6, 25), (95, 29, 12.5), "5A6A78"),
		("wedge", (60, 6, 25), (95, 29, 37.5), "5A6A78", {"rot": (0, 180, 0)}),
		("box", (5, 10, 5), (-12, 5, -60), CONC),
		("box", (5, 10, 5), (12, 5, -60), CONC),
		("box", (220, 1.2, 140), (10, 0.6, -10), "6E6658"),  # schoolyard
	]
	for f in range(3):
		school.append(("box", (146, 0.8, 1.6), (0, 12 * (f + 1) - 0.4, -15.6), "B0ACA0"))
		for i in range(14):
			lit = (i * 3 + f) % 5 == 0
			school.append(("box", (7, 6, 0.4), (-65 + i * 10, 6 + f * 12, -15.2), (SICK if lit else "1C2630"), {"emit": 3 if lit else 0}))
	for x in range(-100, 121, 20):
		if abs(x) > 15:
			school.append(("box", (20, 6, 0.6), (x, 3, -60), "5C6660"))
	k.prop("School", school)

	k.ground("1E2420", margin=550)
	_fill(k, "262A28")
	# Tunnel over its straight: slices every 12 studs, lamps every 36, portals at both mouths
	orig = k.beside
	d = TUNNEL[0]
	while d < TUNNEL[1]:
		pos, yaw = orig(d, 0)
		k.place("TunnelSeg", pos, yaw)
		if int((d - TUNNEL[0]) / 12) % 3 == 0:
			k.place("TunnelLamp", pos, yaw)
		d += 12
	for d, flip in ((TUNNEL[0] - 6, math.pi), (TUNNEL[1] + 6, 0.0)):
		pos, yaw = orig(d, 0)
		k.place("Portal", pos, yaw + flip)
	# Gates before each stair climb
	for d in (140.0, 3060.0):
		pos, yaw = orig(d, 0)
		k.place("Gate", pos, yaw)
	# Roadside and forest layers (off the tunnel, whose walls already line it)
	skip = [(TUNNEL[0] - 50, TUNNEL[1] + 50, 0), (2470.0, 2750.0, 1)]  # tunnel; school grounds (right)
	_grounded(k, skip)
	k.along(70, (-27, 27), ["Mirror", "Posts", "Posts"], jitter=1, start=50)
	k.along(34, (-38, 38), ["Cedar0", "Cedar1", "Cedar2"], jitter=4, start=20)
	k.along(40, (-58, 58), ["Cedar1", "Cedar0", "Cedar2", "Cedar1"], jitter=8, start=30)
	k.along(120, (-90, 90), ["Ridge"], jitter=10, start=60)
	k.along(90, (-48, 48), ["Wisp"], jitter=10, start=70)
	k.beside = orig
	# Ridges along the tunnel stretch (the mountain the tunnel runs through)
	d = TUNNEL[0] - 30
	while d < TUNNEL[1] + 30:
		for side in (-1, 1):
			(x, _, z), yaw = orig(d, side * 75)
			k.place("Ridge", (x, -1.0, z), yaw + side * math.pi / 2, 1.4)
		d += 60
	# Shrine beside the first stair top; school by the straight after the tunnel's corner
	(x, _, z), yaw = orig(320, -62)
	k.place("Shrine", (x, -1.0, z), yaw - math.pi / 2)
	(sx, _, sz), yaw = orig(2610, 150)
	k.place("School", (sx, -1.0, sz), yaw + math.pi / 2)
	avoid = [(sx, sz, 160)]
	_scatter(k, 200, ["Cedar0", "Cedar1", "Cedar2"], 70, 350, (0.9, 1.5), avoid)
	_scatter(k, 40, ["Wisp"], 60, 200, (1.0, 2.0), avoid)
	_scatter(k, 22, ["Peak"], 420, 600, (0.7, 1.4), avoid)
	# Moon: a big pale disc high over the forest
	k.prop("Moon", [("ball", (90, 90, 90), (0, 0, 0), "E8F4FF", {"emit": 6})])
	c = (k.lo + k.hi) / 2
	k.place("Moon", (c.x + 900, 700, c.z - 1400))
	k.sky([(0.0, "1E4A52"), (0.08, "102A3A"), (0.4, "08142A"), (1.0, "03060F")], strength=0.9, sun=(0.9, "9FC0FF", 40, 160))
	# Moonlit road lamps; inside the tunnel, close-spaced lamps of uneven colour and strength (the flicker)
	d = 40
	while d < k.length:
		if not TUNNEL[0] - 20 < d < TUNNEL[1] + 20:
			pos, _ = orig(d, 0, 18)
			k.light(pos, "BFFFF0", energy=50000, radius=6)
		d += 150
	d, i = TUNNEL[0] + 10, 0
	while d < TUNNEL[1]:
		pos, _ = orig(d, 0, 12)
		k.light(pos, (LAMP, SICK, GHOST)[i % 3], energy=(14000, 4000, 9000, 2000)[i % 4], radius=3)
		d, i = d + 36, i + 1
