"""World 2 Track 3: City Z, ruined (One Punch). The hero's city after the meteor strike and the monster raids, in dusty
daylight: broken sidewalk slabs and rubble along cracked avenues, leaning and half-collapsed skyscrapers with dark
shattered windows, the abandoned ghost-town block of low apartments, toppled power poles and dead cars, and the giant
meteor crater with its rock rim and charred floor as the landmark. The two route slopes are filled from the ground
(TrackBuilder's hill supports). No signs with text, no logos (design doc 5). Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

CONC, CONC2, BEIGE, TAN, GLASS = "B4B0A8", "8E97A2", "D6C4A4", "B8875E", "3E5A72"
DARK, RUST, SCORCH, DUST = "2E2B28", "8A5A3A", "3A3028", "D8C8A8"


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


def _grounded(k):
	"""Make k.along place on the ground (y = -1) even where the road climbs, -Z facing the road; returns the original
	beside."""
	orig = k.beside

	def beside(d, off, y=0.0):
		(x, _, z), yaw = orig(d, off, y)
		return (x, -1.0 + y, z), yaw  # kit.along now turns -Z to face the road

	k.beside = beside
	return orig


def _windows(parts, w, h, face_z, x0, floors, lit_every, rng, broken=0.35):
	"""Window grid on the road face; some panes are smashed (dark), the rest dusty glass."""
	for f in range(floors):
		for i in range(int(w / 6)):
			x = x0 - w / 2 + 3 + i * 6
			col = DARK if rng.random() < broken else GLASS
			parts.append(("box", (3.4, 3.6, 0.4), (x, 5 + f * lit_every, face_z), col, {"rough": 0.3 if col == GLASS else 0.9}))


def build(k):
	rng = k.rng
	# Skyscrapers: intact-but-leaning, and half-collapsed with a jagged broken top
	for i, (w, h, col) in enumerate(((30, 90, CONC), (26, 120, BEIGE), (34, 75, CONC2))):
		parts = [("box", (w, h, w), (0, h / 2, 0), col), ("box", (w + 1, 2, w + 1), (0, h + 1, 0), DARK)]
		_windows(parts, w, h, -w / 2 - 0.2, 0, min(int(h / 10), 10), 9, rng)
		k.prop("Tower%d" % i, parts)
		# collapsed twin: lower shaft, then tilted broken slabs on top and a fallen chunk at the foot
		hb = h * 0.55
		parts = [("box", (w, hb, w), (0, hb / 2, 0), col)]
		parts += [
			("wedge", (w * 0.55, 16, w), (-w * 0.22, hb + 8, 0), col, {"rot": (0, 90, 0)}),
			("wedge", (w * 0.45, 9, w * 0.8), (w * 0.25, hb + 4.5, 0), col, {"rot": (0, -90, 0)}),
			("box", (w * 0.4, 6, w * 0.3), (w * 0.15, hb + 2, -w * 0.2), DARK, {"rot": (0, 0, 9)}),
			("box", (0.6, 10, 0.6), (w * 0.35, hb + 4, w * 0.3), RUST, {"rot": (0, 0, 25)}),
			("box", (0.6, 8, 0.6), (w * 0.4, hb + 3, -w * 0.3), RUST, {"rot": (15, 0, -20)}),
			("box", (0.6, 12, 0.6), (-w * 0.1, hb + 5, -w * 0.35), RUST, {"rot": (-10, 0, 10)}),
			("box", (w * 0.9, 8, 12), (w * 0.6, 4, -w * 0.2), col, {"rot": (0, 40, 12)}),
		]
		_windows(parts, w, hb, -w / 2 - 0.2, 0, max(1, int(hb / 10)), 9, rng, broken=0.6)
		k.prop("Broken%d" % i, parts)
	# Ghost-town low apartments: 2-3 floors, balconies, mostly dark windows, roof water tank
	for i, floors in enumerate((2, 3)):
		h = floors * 10
		parts = [
			("box", (30, h, 18), (0, h / 2, 0), (BEIGE, TAN)[i]),
			("box", (32, 1, 20), (0, h + 0.5, 0), CONC2),
			("cyl", (4, 5, 4), (9, h + 3.5, 4), "8E8A84", {"seg": 8}),
			("box", (10, 5, 0.6), (-8, 3, -9.2), DARK),  # torn-open shopfront
		]
		for f in range(floors):
			parts.append(("box", (28, 0.6, 2.4), (0, 10 * (f + 1) - 0.5, -10.2), CONC2))
			for x in (-9, -3, 3, 9):
				parts.append(("box", (3.6, 4, 0.4), (x, 5.5 + f * 10, -9.1), DARK if rng.random() < 0.7 else GLASS))
		k.prop("Apartment%d" % floors, parts)
	# Rubble piles (concrete chunks, a rebar stick) and broken sidewalk slabs lifted at angles
	for i in range(3):
		parts = []
		for j in range(7):
			s = rng.uniform(3, 7)
			parts.append(
				("box", (s, s * 0.7, s * 1.2), (rng.uniform(-7, 7), s * 0.3, rng.uniform(-5, 5)), (CONC, CONC2, BEIGE, TAN)[j % 4], {"rot": (rng.uniform(-30, 30), rng.uniform(0, 90), rng.uniform(-30, 30))})
			)
		parts.append(("box", (0.4, 7, 0.4), (2, 4, 0), RUST, {"rot": (20, 0, 30)}))
		k.prop("Rubble%d" % i, parts)
	k.prop(
		"Slabs",
		[
			("box", (10, 0.8, 8), (0, 0.6, 0), "A8A398", {"rot": (12, 0, 4)}),
			("box", (8, 0.8, 8), (9, 1.4, 2), "A8A398", {"rot": (-6, 20, 18)}),
			("box", (7, 0.8, 6), (-8, 0.9, 3), "938E84", {"rot": (8, -15, -10)}),
		],
	)
	# Toppled power pole with a crossbar, and a dead car (dusty, crushed roof)
	k.prop("PoleDown", [("cyl", (1.1, 30, 1.1), (0, 2, 0), "8E8E86", {"seg": 8, "rot": (0, 0, 78)}), ("box", (0.5, 8, 0.5), (-12, 4, 0), "6E6E66", {"rot": (0, 0, -12)})])
	k.prop(
		"Car",
		[
			("box", (6, 2.2, 12), (0, 1.6, 0), "6E7F8E"),
			("box", (5.4, 1.4, 6), (0, 3.2, 1), "55636E", {"rot": (6, 0, 4)}),
			("box", (5.6, 1.0, 0.4), (0, 3.2, -2.2), DARK),
			("cyl", (2, 1, 2), (3, 0.8, -4), DARK, {"seg": 8, "rot": (0, 0, 90)}),
			("cyl", (2, 1, 2), (-3, 0.8, 4), DARK, {"seg": 8, "rot": (0, 0, 90)}),
		],
	)
	# Dust plume over the ruins (soft translucent puffs)
	k.prop("Dust", [("ball", (s, s * 0.8, s), (x, y, z), DUST, {"alpha": 0.35, "rough": 1}) for s, x, y, z in ((22, 0, 10, 0), (16, 9, 22, 3), (14, -8, 30, -2), (10, 3, 40, 1))])
	# Meteor fragment boulder (charred rock with a faint ember core)
	k.prop("Fragment", [("ball", (14, 10, 12), (0, 4, 0), "4A3E36"), ("cone", (8, 9, 8), (5, 6, 3), SCORCH, {"seg": 5}), ("ball", (3, 3, 3), (-3, 8, -5), "FF7A2A", {"emit": 2})])
	# The meteor crater: charred bowl floor, a rock rim of tilted slabs, buried building stumps and a boulder pile
	crater = [("cyl", (300, 1, 300), (0, 0.2, 0), SCORCH, {"seg": 24}), ("cyl", (180, 1, 180), (0, 0.5, 0), "2A231E", {"seg": 20})]
	for a in range(36):
		ang = a * math.tau / 36
		r = 160 + (a % 3) * 6
		crater.append(("wedge", (30, 16 + (a % 4) * 5, 22), (math.cos(ang) * r, 6, math.sin(ang) * r), (TAN, "8C7A62", BEIGE)[a % 3], {"rot": (0, -math.degrees(ang) - 90, 0)}))
	for a in range(10):
		ang = a * math.tau / 10 + 0.3
		crater.append(("box", (14, 18 + a * 2, 14), (math.cos(ang) * 110, 6, math.sin(ang) * 110), CONC2, {"rot": (rng.uniform(-25, 25), a * 17, rng.uniform(-25, 25))}))
	for j in range(6):
		crater.append(("ball", (26, 18, 22), (rng.uniform(-30, 30), 6, rng.uniform(-30, 30)), "4A3E36"))
	k.prop("Crater", crater)

	k.ground("8A7F70", margin=520)
	_fill(k, "4A4744")
	orig = _grounded(k)
	k.along(40, (-34, 34), ["Slabs", "Rubble0", "Car", "Slabs", "Rubble1"], jitter=1, start=30)
	k.along(110, (-33, 33), ["PoleDown", "Fragment", "Rubble2"], jitter=1, start=75)
	k.along(46, (-54, 54), ["Apartment2", "Apartment3", "Broken0", "Rubble1", "Apartment2", "Broken2"], jitter=3, start=25)
	k.along(150, (-62, 62), ["Dust"], jitter=10, start=90, face_road=False)
	k.along(70, (-96, 96), ["Tower0", "Tower1", "Tower2", "Broken0", "Broken1", "Broken2"], jitter=10, start=20)
	k.beside = orig
	# Leaning skyscrapers in the back rows: tilt about the road axis
	d = 60
	while d < k.length - 80:
		for side in (-1, 1):
			pos, yaw = k.beside(d + rng.uniform(-20, 20), side * rng.uniform(150, 200))
			ob = k.place(rng.choice(["Tower0", "Tower1", "Tower2", "Broken1"]), (pos[0], -1.0, pos[2]), yaw + side * math.pi / 2 + rng.uniform(-0.4, 0.4))
			ob.rotation_euler[0] = math.radians(rng.uniform(-9, 9))
			ob.rotation_euler[1] = math.radians(rng.uniform(-9, 9))
		d += 90
	# The crater sits in the infield, visible across the road from the long straights; scatter keeps off its bowl
	c = (k.lo + k.hi) / 2
	k.place("Crater", (c.x, -1.0, c.z), 0.3)
	for count, names, clearance, margin, scale in (
		(60, ["Rubble0", "Rubble1", "Rubble2", "Fragment", "Car"], 60, 300, (0.8, 1.6)),
		(40, ["Broken0", "Broken1", "Broken2", "Tower1"], 230, 480, (0.9, 1.6)),
		(30, ["Dust"], 50, 250, (0.8, 2.0)),
	):
		placed, tries = 0, 0
		while placed < count and tries < count * 20:
			tries += 1
			x = rng.uniform(k.lo.x - margin, k.hi.x + margin)
			z = rng.uniform(k.lo.z - margin, k.hi.z + margin)
			if math.hypot(x - c.x, z - c.z) > 210 and k.clear_of_road(x, z, clearance):
				k.place(rng.choice(names), (x, -1.0, z), rng.uniform(0, math.tau), rng.uniform(*scale))
				placed += 1
	k.sky([(0.0, "DCCDAE"), (0.06, "BFC3C0"), (0.25, "86AACB"), (1.0, "3F74AC")], strength=1.0, sun=(4.0, "FFE6C0", 40, 150))
