"""World 2 Track 6: Elven Plains (Frieren). The northern plains the elf mage walks: bright day, rolling green meadows
with blue and white wildflowers, lone trees, mossy white stone ruins and broken columns, and a distant snowy mountain
range under soft clouds. Midway, the field outside the walled hill town where the Guillotine's army stood: rows of
abandoned suits of armour planted with their swords (statues, no gore). Landmark: the ruined fortress town on its
hill. Everything in-house, parts only; no crest or text (design doc 5). Proposed look; the owner approves the render
set (design doc 4.46)."""

import math

GRASS, GRASS2, GRASS3 = "6FA35A", "5C9150", "86B866"
STONE, STONE2, MOSS = "E8E4D8", "C8C2B2", "6E9A4E"
BLUE, WHITE, PALE = "4A7AE8", "F4F6FF", "9CC4FF"
LEAF, LEAF2, BARK = "4E8A3E", "3E7434", "6A5038"
ARMOUR, ARMOUR2 = "9AA2AE", "6E7684"
ROOF = "3E5A8A"


def row(k, every, offsets, names, clear, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), face_road=True):
	"""k.along on the ground plane, skipping any spot within `clear` of another part of the looping road."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			if k.clear_of_road(pos[0], pos[2], clear):
				k.place(k.rng.choice(names), (pos[0], -1.0, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def build(k):
	# Wildflower patches: low grass mound dotted with blue and white blooms
	for i, (a, b) in enumerate(((BLUE, WHITE), (WHITE, PALE), (BLUE, PALE))):
		parts = [("cyl", (14, 0.8, 10), (0, 0.4, 0), GRASS3, {"seg": 8})]
		for j in range(9):
			x, z = 5 * math.cos(j * 2.4), 3.6 * math.sin(j * 2.4)
			parts.append(("cyl", (0.3, 1.8, 0.3), (x, 1.3, z), LEAF, {"seg": 4}))
			parts.append(("box", (1.8, 1.2, 1.8), (x, 2.5, z), (a, b)[j % 2], {"emit": 0.15, "rot": (0, j * 20, 0)}))
		k.prop("Flowers%d" % i, parts)
	k.prop(
		"Grass",
		[
			("cone", (3, 4, 3), (0, 2, 0), GRASS2, {"seg": 5}),
			("cone", (2.4, 3, 2.4), (2, 1.5, 1), GRASS, {"seg": 5, "rot": (0, 0, -15)}),
			("cone", (2.4, 3.4, 2.4), (-2, 1.7, -0.5), GRASS3, {"seg": 5, "rot": (0, 0, 15)}),
		],
	)
	# Lone trees: a broad, round crown on a short trunk
	for i, s in enumerate((1.0, 1.3)):
		k.prop(
			"Tree%d" % i,
			[
				("cyl", (3 * s, 16 * s, 3 * s), (0, 8 * s, 0), BARK, {"seg": 8}),
				("ball", (20 * s, 16 * s, 20 * s), (0, 20 * s, 0), (LEAF, LEAF2)[i]),
				("ball", (12 * s, 10 * s, 12 * s), (7 * s, 17 * s, 3 * s), LEAF2),
				("ball", (12 * s, 10 * s, 12 * s), (-6 * s, 18 * s, -4 * s), LEAF),
			],
		)
	# Ruins: broken white columns with moss bands, a column pair with a lintel, a wall stub with an arch window
	k.prop(
		"Column",
		[
			("box", (7, 2, 7), (0, 1, 0), STONE2),
			("cyl", (4.5, 14, 4.5), (0, 9, 0), STONE, {"seg": 10}),
			("cyl", (4.7, 1.2, 4.7), (0, 3, 0), MOSS, {"seg": 10}),
			("cyl", (4.5, 5, 4.5), (6, 2.2, 3), STONE, {"seg": 10, "rot": (0, 30, 90)}),  # fallen drum
		],
	)
	k.prop(
		"Colonnade",
		[
			("box", (24, 2, 8), (0, 1, 0), STONE2),
			("cyl", (4, 20, 4), (-8, 12, 0), STONE, {"seg": 10}),
			("cyl", (4, 13, 4), (8, 8.5, 0), STONE, {"seg": 10}),
			("box", (14, 3, 5), (-4, 23, 0), STONE2, {"rot": (0, 0, -8)}),
			("box", (24.4, 1, 8.4), (0, 2.2, 0), MOSS),
			("box", (5, 3, 4), (12, 1.5, -6), STONE2, {"rot": (0, 30, 12)}),
		],
	)
	k.prop(
		"RuinWall",
		[
			("box", (26, 16, 4), (0, 8, 0), STONE),
			("box", (6, 8, 4.4), (-2, 8, 0), "BFC8D4"),  # arch window opening (shaded)
			("cyl", (6, 4.4, 6), (-2, 12, 0), "BFC8D4", {"rot": (90, 0, 0), "seg": 10}),
			("wedge", (10, 8, 4), (9, 20, 0), STONE, {"rot": (0, 90, 0)}),
			("box", (26.4, 2, 4.4), (0, 1, 0), MOSS),
			("box", (6, 2, 4.6), (-8, 15, 0), MOSS),
		],
	)
	k.prop(
		"Rock",
		[
			("ball", (9, 6, 8), (0, 2, 0), "A8A498", {"rot": (0, 20, 0)}),
			("ball", (8, 2.4, 7), (0, 4.6, 0), MOSS),
			("ball", (5, 4, 5), (5, 1.5, 2), "B8B4A8"),
		],
	)
	# Abandoned armour: a suit of plate standing at attention, sword planted, on a stone base (statue, no gore)
	k.prop(
		"Armour",
		[
			("box", (4, 1, 4), (0, 0.5, 0), STONE2),
			("box", (1.4, 4, 1.6), (-0.9, 3, 0), ARMOUR2, {"metal": 0.7, "rough": 0.4}),
			("box", (1.4, 4, 1.6), (0.9, 3, 0), ARMOUR2, {"metal": 0.7, "rough": 0.4}),
			("box", (3.6, 4.2, 2.2), (0, 7, 0), ARMOUR, {"metal": 0.7, "rough": 0.35}),
			("ball", (1.8, 1.4, 1.8), (-2.3, 8.6, 0), ARMOUR, {"metal": 0.7, "rough": 0.35}),
			("ball", (1.8, 1.4, 1.8), (2.3, 8.6, 0), ARMOUR, {"metal": 0.7, "rough": 0.35}),
			("box", (1.1, 3.6, 1.1), (-2.3, 6.6, -0.6), ARMOUR2, {"metal": 0.7}),
			("box", (1.1, 3.6, 1.1), (2.3, 6.6, -0.6), ARMOUR2, {"metal": 0.7}),
			("cyl", (2, 2.2, 2.2), (0, 10.3, 0), ARMOUR, {"seg": 8, "metal": 0.7, "rough": 0.35}),
			("box", (0.4, 1.4, 0.2), (0, 10.4, -1.1), "30343C"),  # visor slit
			("box", (0.5, 6, 0.3), (0, 3.2, -2), "D0D6E0", {"metal": 0.9, "rough": 0.2}),  # planted sword
			("box", (2.4, 0.4, 0.4), (0, 6.4, -2), "8A6A3A"),
			("box", (2.6, 3, 0.3), (0, 6, 1.2), "6A2E3A"),  # cape
		],
	)
	# Distant snowy mountains and soft clouds
	for i, (r, h) in enumerate(((360, 260), (260, 200), (440, 320))):
		k.prop(
			"Mountain%d" % i,
			[
				("cone", (r, h, r), (0, h / 2, 0), ("6E7E96", "7A889C", "66768E")[i], {"seg": 7}),
				("cone", (r * 0.42, h * 0.42, r * 0.42), (0, h * 0.79 + 0.5, 0), "F4F8FF", {"seg": 7}),
			],
		)
	for i, c in enumerate((GRASS2, GRASS3)):  # rolling meadow swells
		k.prop("Mound%d" % i, [("ball", (120, 30, 90), (0, -3, 0), c), ("ball", (70, 26, 60), (30, 0, 14), c)])
	k.prop(
		"Cloud",
		[
			("ball", (60, 18, 34), (0, 0, 0), "FFFFFF", {"emit": 0.3}),
			("ball", (36, 20, 26), (-16, 6, 2), "FFFFFF", {"emit": 0.3}),
			("ball", (40, 22, 28), (14, 7, -2), "FFFFFF", {"emit": 0.3}),
		],
	)
	# Ruined fortress town on a hill (landmark): grassy hill, curtain walls, round towers with slate cones, a keep
	ft = [("cyl", (300, 50, 300), (0, 25, 0), GRASS2, {"seg": 16, "taper": 0.62})]
	R = 80
	for j in range(8):
		a = j * math.tau / 8
		x, z = R * math.cos(a), R * math.sin(a)
		broken = j in (2, 5)
		th = 24 if broken else 38
		ft.append(("cyl", (16, th, 16), (x, 50 + th / 2, z), STONE, {"seg": 10}))
		if not broken:
			ft.append(("cone", (19, 18, 19), (x, 50 + th + 9, z), ROOF, {"seg": 10}))
		ft.append(("cyl", (16.4, 3, 16.4), (x, 51.5, z), MOSS, {"seg": 10}))
		a2 = a + math.tau / 16
		wl = 2 * R * math.sin(math.tau / 16) - 10
		wh = 10 if j in (3, 6) else 20
		ft.append(("box", (wl, wh, 5), (R * math.cos(a2) * 0.93, 50 + wh / 2, R * math.sin(a2) * 0.93), STONE2, {"rot": (0, -math.degrees(a2) - 90, 0)}))
	ft += [
		("box", (44, 50, 44), (0, 75, 0), STONE),
		("box", (46, 4, 46), (0, 100, 0), STONE2),
		("box", (24, 30, 24), (8, 115, 8), STONE),
		("wedge", (24, 14, 24), (8, 137, 8), STONE2),  # broken top
		("cyl", (12, 50, 12), (-14, 125, -14), STONE, {"seg": 10}),
		("cone", (15, 26, 15), (-14, 163, -14), ROOF, {"seg": 10}),
		("box", (8, 14, 1), (0, 64, -22.4), "4A5060"),  # gate
	]
	for x, z in ((-40, 30), (30, -40), (40, 40), (-30, -35)):
		ft.append(("box", (16, 12, 14), (x, 56, z), STONE2))
		ft.append(("wedge", (16, 8, 14), (x, 66, z), ROOF))
	k.prop("FortressHill", ft)

	k.ground(GRASS, margin=1100)
	# Meadow layers: flowers and tufts by the walls, ruins and lone trees farther out
	flowers = ["Flowers0", "Flowers1", "Flowers2", "Grass", "Grass"]
	row(k, 30, (-30, 30), flowers, 26, jitter=6, face_road=False)
	row(k, 44, (-48, 48), flowers + ["Rock"], 40, jitter=8, start=50, face_road=False)
	row(k, 110, (-38, 38), ["Column", "Column", "Colonnade", "RuinWall"], 34, jitter=10, start=80)
	row(k, 70, (-75, 75), ["Tree0", "Tree1", "Rock", "Column"], 60, jitter=16, scale=(0.9, 1.3), face_road=False)
	row(k, 140, (-120, 120), ["Tree0", "Tree1", "RuinWall", "Colonnade"], 100, jitter=25, scale=(0.9, 1.4))
	k.field(160, flowers, clearance=60, margin=500, scale=(1.0, 1.8))
	k.field(70, ["Mound0", "Mound1"], clearance=130, margin=600, scale=(0.8, 1.8))
	k.field(120, ["Tree0", "Tree1", "Rock"], clearance=90, margin=500, scale=(0.9, 1.5))
	k.field(40, ["Column", "RuinWall", "Colonnade"], clearance=90, margin=400)
	# The battlefield: ranks of abandoned armour beside the road through the middle third
	# The battlefield by the fortress: loose clusters of 3-7 abandoned suits, some tilted, some fallen
	d = k.length * 0.3
	while d < k.length * 0.42:
		off = k.rng.choice((-1, 1)) * k.rng.uniform(40, 110)
		centre, yaw = k.beside(d, off)
		for _ in range(k.rng.randint(3, 7)):
			x, z = centre[0] + k.rng.uniform(-12, 12), centre[2] + k.rng.uniform(-12, 12)
			if not k.clear_of_road(x, z, 28):
				continue
			ob = k.place("Armour", (x, -1.0, z), yaw + k.rng.uniform(-0.6, 0.6) + (math.pi if off < 0 else 0.0))
			roll = k.rng.random()
			if roll < 0.2:  # fallen on its back
				ob.rotation_euler[0] = math.radians(84)
				ob.location.z += 1.4
			elif roll < 0.5:  # leaning
				ob.rotation_euler[0] = math.radians(k.rng.uniform(-16, 16))
				ob.rotation_euler[1] = math.radians(k.rng.uniform(-10, 10))
		d += k.rng.uniform(45, 80)
	# Fortress town on its hill, and the snowy range on the far horizon
	for f, off in ((0.36, -380), (0.36, 380), (0.5, -380)):
		pos, yaw = k.beside(k.length * f, off)
		if k.clear_of_road(pos[0], pos[2], 300):
			k.place("FortressHill", (pos[0], -1.0, pos[2]), yaw, 1.6)
			break
	# The range rings the plains outside the track's whole area, so it always sits on the horizon
	cx, cz = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2
	rad = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z) / 2 + 700
	for j in range(30):
		a = j * math.tau / 30 + k.rng.uniform(-0.05, 0.05)
		r = rad + k.rng.uniform(-80, 200)
		k.place(k.rng.choice(["Mountain0", "Mountain1", "Mountain2"]), (cx + r * math.cos(a), -1.0, cz + r * math.sin(a)), k.rng.uniform(0, math.tau), k.rng.uniform(1.0, 1.6))
	for _ in range(26):
		x = k.rng.uniform(k.lo.x - 600, k.hi.x + 600)
		z = k.rng.uniform(k.lo.z - 600, k.hi.z + 600)
		k.place("Cloud", (x, k.rng.uniform(380, 520), z), k.rng.uniform(0, math.tau), k.rng.uniform(1.6, 3.0))
	# Bright day: high warm sun, clear blue sky fading pale at the horizon
	k.sky([(0.0, "D8EAFF"), (0.04, "A8CCFF"), (0.15, "74AEF2"), (1.0, "3E7ED8")], strength=0.75, sun=(3.2, "FFF4E0", 50, 150))
