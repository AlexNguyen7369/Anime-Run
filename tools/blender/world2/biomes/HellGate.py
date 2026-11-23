"""World 2 Track 10: Hell Gate (Saw Man). The devils' Hell from the Hell arc, built to read 1-1 with the source (refs and
landmark list: docs/world2_refs/HellGate.md):
- a wide grassy, flowery plain with low hills under a red-orange sky;
- countless identical doors: rows of free-standing panel doors beside the road, and rows of doors hanging in the sky;
- giant pale six-fingered hands rising out of the ground;
- the last stretch is the darkness: black ground, pale severed arms floating in the air, and two rows of kneeling,
  praying astronauts facing each other across the road (whole figures, no gore, no mission patch);
- the landmark: one giant door standing open over the road, the door the darkness came through.
No symbols or text (design doc 5). Everything in-house, parts only. Track 10 is about 22,000 studs long, so spacing is
wide to keep the instance count down. Proposed look; the owner approves the render set (design doc 4.46)."""

import math

GRASS, GRASS2, HILL = "3E4420", "5A6230", "4A4826"
PALE, PALE2, NAIL = "F2E6DA", "DDCCBE", "E8C8C0"
DOOR, DOOR2, FRAMEC, KNOB = "8A5A3A", "74482C", "5A3A26", "C8A040"
SUIT, SUIT2, VISOR = "ECEAE4", "C8C6C0", "0A0A10"
BLACK = "060406"
HAZE = "FF8A4A"  # the horizon colour: the far plain fades into it


# The darkness finale, 700 and 330 studs before the finish (runner lane); build_track renders these too
EXTRA_SHOTS = [
	("06_finale_700", (-4137.9, 9.0, 35.5), (-4137.9, 5.0, -48.5)),
	("07_finale_330", (-4137.9, 9.0, -334.5), (-4137.9, 5.0, -418.5)),
]


def B(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def seg(p, a, b, r, col, ball=True, **o):
	"""A limb from point a to point b (Roblox local), radius r, with a ball joint at b. rot = tilt from +Y, then yaw."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rx = math.degrees(math.acos(max(-1.0, min(1.0, dy / ln))))
	ry = math.degrees(math.atan2(dx, dz))
	mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
	o.setdefault("seg", 10)
	p.append(("cyl", (2 * r, ln, 2 * r), mid, col, dict(o, rot=(rx, ry, 0), smooth=True)))
	if ball:
		p.append(("ball", (2 * r, 2 * r, 2 * r), b, col, {"subdiv": 1, "smooth": True}))


def ground_along(k, every, offsets, names, jitter=0.0, start=40.0, end=None, scale=(1.0, 1.0), y=-1.0, spin=False, clear=0.9):
	"""kit.along, but every prop stands at height y (ground: -1) even beside ramps, and never near another road stretch."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			pos, yaw = k.beside(d + k.rng.uniform(-jitter, jitter), o)
			if not k.clear_of_road(pos[0], pos[2], abs(o) * clear):
				continue  # another stretch of road passes closer than this one: skip, never on a road
			yaw = k.rng.uniform(0, math.tau) if spin else yaw + (math.pi / 2 if off > 0 else -math.pi / 2)  # -Z faces the road
			yy = k.rng.uniform(*y) if isinstance(y, tuple) else y
			k.place(k.rng.choice(names), (pos[0], yy, pos[2]), yaw, k.rng.uniform(*scale))
		d += every


def sky_field(k, count, names, y, margin, scale):
	"""Props hung in the sky over the whole track area, any yaw, at random heights."""
	for _ in range(count):
		x = k.rng.uniform(k.lo.x - margin, k.hi.x + margin)
		z = k.rng.uniform(k.lo.z - margin, k.hi.z + margin)
		k.place(k.rng.choice(names), (x, k.rng.uniform(*y), z), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))


def door(ajar=0, w=8, h=16):
	"""A free-standing panel door: sill step, frame posts and lintel with architrave, the slab (six raised panels, knob
	and plate, hinges) hinged on the left and swung `ajar` degrees away from the road; black beyond when open."""
	a = math.radians(ajar)
	p = [
		("box", (w + 4, 0.8, 4), (0, 0.4, 0), "4A3A2A"),
		("box", (1.4, h + 1.6, 1.8), (-w / 2 - 0.7, h / 2 + 1.2, 0), FRAMEC),
		("box", (1.4, h + 1.6, 1.8), (w / 2 + 0.7, h / 2 + 1.2, 0), FRAMEC),
		("box", (w + 2.8, 1.4, 1.8), (0, h + 1.5, 0), FRAMEC),
		("box", (w + 4, 0.8, 2.2), (0, h + 2.4, 0), FRAMEC),  # architrave cap
	]
	# Slab parts in hinge space: (x from the hinge, y, z offset), rotated about the hinge at x = -w/2
	def put(size, x, y, z, col, **o):
		cx = -w / 2 + math.cos(a) * x + math.sin(a) * z
		cz = -math.sin(a) * x + math.cos(a) * z
		p.append(("box", size, (cx, y, cz), col, dict(o, rot=(0, ajar, 0))))

	put((w, h, 0.6), w / 2, h / 2 + 0.8, 0, DOOR)
	for col_i in range(2):
		for row in range(3):
			ph = (h - 4) / 3 - 1
			put((w / 2 - 1.6, ph, 0.3), w / 4 + col_i * w / 2, 2.6 + ph / 2 + row * (ph + 1), -0.4, DOOR2)
	put((0.9, 1.6, 0.2), w - 1.2, h / 2, -0.5, KNOB, metal=1, rough=0.3)
	put((0.8, 0.8, 0.8), w - 1.2, h / 2, -0.9, KNOB, metal=1, rough=0.3)
	for y in (3, h - 1.5):
		put((0.5, 1.4, 0.8), 0.2, y, 0, "3A3030", metal=0.8)
	if ajar:
		p.append(("box", (w - 0.2, h - 0.2, 0.2), (0, h / 2 + 0.8, 0.2), BLACK))  # the dark beyond
	return p


def sky_door():
	"""One upright door hanging in Hell's sky: frame, panelled slab on both faces, knobs. All face the same way."""
	p = []
	B(p, (1, 17, 1.4), (-4.5, 8.5, 0), FRAMEC)
	B(p, (1, 17, 1.4), (4.5, 8.5, 0), FRAMEC)
	B(p, (10, 1, 1.4), (0, 17.5, 0), FRAMEC)
	B(p, (8, 16, 0.6), (0, 8.5, 0), DOOR)
	for z in (-0.4, 0.4):
		for x in (-2, 2):
			for y in (4.5, 11.5):
				B(p, (3, 5.5, 0.2), (x, y, z), DOOR2)
		B(p, (0.7, 0.7, 0.4), (3, 8, z * 1.8), KNOB, metal=1, rough=0.3)
	return p


def finger(p, base, spread, curl, lengths, r):
	"""A finger of jointed segments from `base`: fanned `spread` degrees sideways, each joint bending a further `curl`
	degrees toward the road (-Z), tapering, with a nail on the tip."""
	a, bend = base, 0.0
	s = math.radians(spread)
	for j, ln in enumerate(lengths):
		bend += math.radians(curl)
		d = (math.sin(s) * math.cos(bend), math.cos(s) * math.cos(bend), -math.sin(bend))
		b = (a[0] + d[0] * ln, a[1] + d[1] * ln, a[2] + d[2] * ln)
		seg(p, a, b, r * (1 - 0.1 * j), PALE if j % 2 == 0 else PALE2, seg=10)
		a = b
	p.append(("ball", (r * 1.3, r * 0.7, r * 1.3), (a[0], a[1], a[2] - r * 0.6), NAIL, {"subdiv": 1, "smooth": True}))


def hand(curl):
	"""A giant pale hand rising out of the ground, palm toward the road (-Z): smooth tapered forearm flowing through a
	rounded wrist into a tapered palm (narrow at the wrist, wide at the knuckles), five fingers of natural length with one
	gentle curl per joint, and a thumb set on the palm base. Earth heaped round the arm."""
	p = [
		("cone", (34, 6, 30), (0, 2, 0), HILL, {"seg": 12, "taper": 0.35}),
		("cyl", (12, 44, 11), (0, 21, 0), PALE2, {"seg": 16, "taper": 0.84, "smooth": True}),
		("ball", (10.4, 7, 9.4), (0, 43, 0), PALE2, {"subdiv": 2, "smooth": True}),  # wrist: same width as the forearm top
		("cyl", (11, 15, 6.4), (0, 51.5, 0), PALE, {"seg": 16, "taper": 1.4, "smooth": True}),  # palm, widening upward
		("ball", (15.6, 5, 6.6), (0, 59, 0), PALE, {"subdiv": 2, "smooth": True}),  # knuckle ridge
		("ball", (6, 9, 5), (-4.5, 47, -0.6), PALE, {"subdiv": 2, "smooth": True}),  # thumb mound on the palm base
	]
	for x, spread, lengths in (
		(-5.4, -7, (5.6, 3.8, 2.8)),
		(-1.8, -2, (6.2, 4.2, 3.0)),
		(1.8, 2, (5.8, 4.0, 2.9)),
		(5.2, 7, (4.6, 3.2, 2.4)),
	):
		finger(p, (x, 60, 0), spread, curl, lengths, 1.55)
	# Thumb: from the mound at the palm base, angled out and up, then curling across toward the road
	a = (-6.5, 47, -0.8)
	for b, r in (((-10.5, 52, -2.0), 1.8), ((-12.0, 56.5, -3.0 - curl / 12), 1.6)):
		seg(p, a, b, r, PALE)
		a = b
	p.append(("ball", (2.0, 1.1, 2.0), (a[0], a[1], a[2] - 1.0), NAIL, {"subdiv": 1, "smooth": True}))
	return p


def arm():
	"""A pale arm reaching up out of the darkness: forearm rising from below, a soft bend, an open hand at the top with
	five fingers. The lower end sinks into the black ground or the haze, so no cut end shows."""
	p = []
	sh, el, wr = (0, -14, 0), (1.5, 0, -1.5), (0.5, 12, -3)
	seg(p, sh, el, 1.6, PALE2)
	seg(p, el, wr, 1.3, PALE)
	p.append(("ball", (3.6, 4.6, 2.0), (0.5, 15, -3.2), PALE, {"subdiv": 2, "smooth": True}))  # palm
	for i in range(4):
		a = (-1.1 + i * 0.8, 17, -3.2)
		seg(p, a, (-1.7 + i * 1.2, 21.5 - abs(i - 1.5) * 0.6, -4.2), 0.45, PALE, ball=False, seg=6)
	seg(p, (-1.0, 14, -3.2), (-3.2, 16.5, -4.0), 0.5, PALE, ball=False, seg=6)
	return p


def astronaut():
	"""A kneeling astronaut praying, facing -Z (the road): white suit, helmet with dark visor and side lamps, backpack,
	gloved hands pressed together before the visor. No patch or emblem."""
	p = []
	for sx in (-1, 1):
		x = sx * 0.85
		seg(p, (x, 0.55, -0.4), (x, 0.55, 2.4), 0.6, SUIT2)  # shin flat on the ground
		B(p, (1.3, 1.3, 1.6), (x, 0.65, 2.9), "8A8880")  # boot
		seg(p, (x, 0.7, -0.5), (x, 3.0, 0.3), 0.7, SUIT)  # thigh up to the hip
		p.append(("ball", (1.5, 1.5, 1.5), (x, 0.7, -0.5), SUIT2, {"subdiv": 1, "smooth": True}))  # knee
		seg(p, (sx * 1.7, 5.7, 0.2), (sx * 1.5, 4.4, -1.0), 0.55, SUIT)  # upper arm
		seg(p, (sx * 1.5, 4.4, -1.0), (sx * 0.35, 6.3, -1.7), 0.5, SUIT)  # forearm up to the hands
		B(p, (0.6, 1.5, 0.9), (sx * 0.3, 6.6, -1.75), "D8D6CE")  # glove
		B(p, (0.3, 1.0, 0.3), (sx * 1.45, 7.4, -0.2), "D8D2B0", emit=0.6)  # helmet side lamp
	p.append(("cyl", (2.8, 3.0, 2.2), (0, 4.5, 0.25), SUIT, {"seg": 12, "smooth": True}))  # torso
	B(p, (3.2, 1.8, 2.2), (0, 5.4, 0.25), SUIT)  # chest
	B(p, (1.4, 0.9, 0.3), (0, 5.2, -0.9), "9A9890")  # chest control box
	B(p, (2.8, 3.4, 1.4), (0, 5.0, 1.8), SUIT2)  # life-support backpack
	p.append(("cyl", (2.2, 0.5, 2.2), (0, 6.3, 0.1), "A8A6A0", {"seg": 12}))  # neck ring
	p.append(("ball", (2.9, 2.9, 2.9), (0, 7.5, 0.1), SUIT, {"subdiv": 2, "smooth": True}))  # helmet
	p.append(("ball", (2.4, 2.1, 1.4), (0, 7.4, -0.85), VISOR, {"subdiv": 2, "smooth": True, "rough": 0.08, "metal": 0.6}))
	return p


def dark_gate():
	"""The landmark: one giant panel door standing open over the road. Posts sit 27+ studs from the centre line and run
	deep into the ground (ramps), the lintel is 110 studs up, the slab is swung open away from the runner, black inside."""
	W, H = 54, 110
	p = [
		("box", (8, H + 60, 10), (-W / 2 - 4, (H - 60) / 2, 0), FRAMEC),
		("box", (8, H + 60, 10), (W / 2 + 4, (H - 60) / 2, 0), FRAMEC),
		("box", (W + 16, 10, 10), (0, H + 5, 0), FRAMEC),
		("box", (W + 24, 4, 13), (0, H + 12, 0), "4A3020"),
		("box", (12, 6, 14), (-W / 2 - 4, 2, 0), "3A2A1A"),
		("box", (12, 6, 14), (W / 2 + 4, 2, 0), "3A2A1A"),
	]
	# The slab, hinged on the left post and swung 140 degrees open toward -Z (away from the runner, off the road)
	ang = 140
	a = math.radians(ang)
	hx = -W / 2

	def put(size, x, y, z, col, **o):
		p.append(("box", size, (hx + math.cos(a) * x + math.sin(a) * z, y, -math.sin(a) * x + math.cos(a) * z), col, dict(o, rot=(0, ang, 0))))

	put((W, H, 3), W / 2, H / 2, 0, DOOR)
	for ci in range(2):
		for row in range(3):
			ph = (H - 20) / 3 - 4
			put((W / 2 - 8, ph, 1.2), W / 4 + ci * W / 2, 10 + ph / 2 + row * (ph + 4), 1.8, DOOR2)
	put((5, 8, 1), W - 6, H / 2, 2.4, KNOB, metal=1, rough=0.3)
	put((4, 4, 4), W - 6, H / 2, 4.2, KNOB, metal=1, rough=0.3)
	# Darkness spilling out on the ground beyond the threshold, off the road on both sides
	for sx in (-1, 1):
		p.append(("cyl", (40, 0.4, 70), (sx * 48, -0.6, -40), BLACK, {"seg": 16}))
	return p


def grass():
	"""A grass clump with small pale flowers."""
	p = []
	for i in range(9):
		ang = i * 2.4
		r = 0.6 + (i % 3) * 0.5
		p.append(("cone", (0.7, 3.0 + (i % 4) * 0.6, 0.7), (math.cos(ang) * r, 1.2, math.sin(ang) * r), GRASS2 if i % 2 else GRASS, {"seg": 4, "rot": ((i % 3 - 1) * 12, 0, (i % 2 - 0.5) * 20)}))
	for i, c in enumerate(("F2E8D8", "E8C8D0", "F0E090")):
		ang = i * 2.1 + 0.5
		p.append(("ball", (0.5, 0.4, 0.5), (math.cos(ang) * 1.2, 3.2 + i * 0.3, math.sin(ang) * 1.2), c, {"subdiv": 1}))
	return p


def ground_shader(k, mat, ox, oz, near, far):
	"""The plain reaches the horizon: the ground fades from grass into the sky's horizon colour (unlit), measured from
	the track centre, so the edge never shows and the far plain melts into the haze."""
	nt = mat.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
	geo = nt.nodes.new("ShaderNodeNewGeometry")
	dist = nt.nodes.new("ShaderNodeVectorMath")
	dist.operation = "DISTANCE"
	dist.inputs[1].default_value = (ox, oz, 0.0)
	nt.links.new(geo.outputs["Position"], dist.inputs[0])
	rng = nt.nodes.new("ShaderNodeMapRange")
	rng.inputs["From Min"].default_value = near
	rng.inputs["From Max"].default_value = far
	nt.links.new(dist.outputs["Value"], rng.inputs["Value"])
	emit = nt.nodes.new("ShaderNodeEmission")
	emit.inputs["Color"].default_value = hexcol(HAZE)
	emit.inputs["Strength"].default_value = 1.0
	mix = nt.nodes.new("ShaderNodeMixShader")
	nt.links.new(rng.outputs["Result"], mix.inputs["Fac"])
	nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
	nt.links.new(emit.outputs["Emission"], mix.inputs[2])
	nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def hexcol(h):
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], 1.0)


def scatter_ring(k, count, names, rmin, rmax, scale, y=-1.0):
	"""Props spread over the far plain between radius rmin and rmax from the track centre (rolling hills to the edge)."""
	c = (k.lo + k.hi) / 2
	for _ in range(count):
		ang = k.rng.uniform(0, math.tau)
		r = math.sqrt(k.rng.uniform(rmin * rmin, rmax * rmax))
		k.place(k.rng.choice(names), (c.x + math.cos(ang) * r, y, c.z + math.sin(ang) * r), k.rng.uniform(0, math.tau), k.rng.uniform(*scale))


def build(k):
	k.prop("DoorClosed", door())
	k.prop("DoorOpen", door(ajar=50))
	k.prop("SkyDoor", sky_door())
	k.prop("HandOpen", hand(9))
	k.prop("HandGrasp", hand(24))
	k.prop("ArmReach", arm())
	k.prop("Astronaut", astronaut())
	k.prop("DarkGate", dark_gate())
	k.prop("Grass", grass())
	k.prop("Hill", [("ball", (2, 0.35, 2), (0, 0, 0), HILL, {"subdiv": 3, "smooth": True})])
	k.prop("Void", [("cyl", (120, 0.3, 120), (0, 0, 0), BLACK, {"seg": 24})])
	k.prop("Haze", [("ball", (1, 0.45, 1), (0, 0, 0), BLACK, {"subdiv": 2, "smooth": True, "alpha": 0.22, "rough": 1.0})])

	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	g = k.ground(GRASS, margin=24000, rough=1.0)
	ground_shader(k, g.data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)  # Blender XY: (x, -z)
	ground_shader(k, k.props["Hill"].data.materials[0], c.x, -c.z, span * 0.75, span * 2.6)  # far hills melt into the haze too
	haze = k.props["Haze"].data.materials[0]
	hb = next(n for n in haze.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	hb.inputs["Specular IOR Level"].default_value = 0.0  # pure dark haze: no sky sheen
	hb.inputs["Alpha"].default_value = 0.45
	L = k.length
	dark = L - 1500  # the darkness falls over the last 1500 studs
	doors = ["DoorClosed", "DoorClosed", "DoorOpen"]
	# Rows of identical doors standing on the plain: a near row and a far row each side, square to the road
	ground_along(k, 66, (-38, 38), doors, jitter=4, start=40, end=dark - 60, clear=0.8)
	ground_along(k, 70, (-70, 70), doors, jitter=6, start=60, end=dark - 60, scale=(1.2, 1.2), clear=0.8)
	ground_along(k, 100, (-120, 120), doors, jitter=10, start=30, end=dark - 60, scale=(1.6, 1.6), clear=0.8)
	k.field(60, doors, clearance=180, margin=700, scale=(1.6, 2.6))
	# Grass and flowers near the road; rolling hills across the plain out to the horizon
	ground_along(k, 75, (-28, 28, -52, 52), ["Grass"], jitter=10, start=20, end=dark, spin=True, scale=(2.2, 3.4), clear=0.7)
	k.field(50, ["Hill"], clearance=260, margin=800, scale=(80, 160))
	scatter_ring(k, 90, ["Hill"], span * 0.75, span * 2.4, (250, 650))
	# The giant pale hands rising out of the ground
	ground_along(k, 700, (-140, 140), ["HandOpen", "HandGrasp"], jitter=60, start=400, end=dark - 200, scale=(1.8, 2.6))
	k.field(18, ["HandOpen", "HandGrasp"], clearance=320, margin=700, scale=(3.0, 4.5))
	# Doors fill the sky: single upright doors on a jittered grid over the track disc, all facing the same way, layered in height
	step = 400  # one door per 400 x 400 studs over the round track area keeps the part budget
	x = c.x - span * 0.75
	while x < c.x + span * 0.75:
		z = c.z - span * 0.75
		while z < c.z + span * 0.75:
			if math.hypot(x - c.x, z - c.z) > span * 0.75:
				z += step
				continue
			k.place(
				"SkyDoor",
				(x + k.rng.uniform(-90, 90), k.rng.uniform(320, 1100), z + k.rng.uniform(-90, 90)),
				math.radians(k.rng.uniform(-6, 6)),
				k.rng.uniform(4.5, 7.0),
			)
			z += step
		x += step
	# The darkness: black ground pieces thickening toward the finish, black haze drifting over them, arms reaching out
	d = dark - 400
	while d < L - 20:
		t = max(0.0, (d - (dark - 400)) / (L - dark + 380))  # 0 at the edge of the darkness, 1 at the finish
		offs = (-60, 60) if t < 0.3 else (-60, 60, -150, 150) if t < 0.65 else (-50, 50, -120, 120, -210, 210)
		for o in offs:
			pos, _ = k.beside(d + k.rng.uniform(-20, 20), o + k.rng.uniform(-15, 15))
			if k.clear_of_road(pos[0], pos[2], abs(o) * 0.5):
				k.place("Void", (pos[0], -0.85, pos[2]), k.rng.uniform(0, math.tau), 0.6 + t * 0.9)
		d += 150 - t * 70
	ground_along(k, 100, (-90, 90, -180, 180), ["Haze"], jitter=8, start=dark - 150, end=L - 20, y=(-8.0, 25.0), spin=True, scale=(110, 130), clear=0.75)  # edge stays 24+ off the road
	ground_along(k, 60, (-42, 42, -85, 85), ["ArmReach"], jitter=18, start=dark, end=L - 80, y=(-4.0, 40.0), spin=True, scale=(1.6, 2.6), clear=0.8)
	ground_along(k, 14, (-30, 30), ["Astronaut"], start=dark + 200, end=L - 260, scale=(1.5, 1.5), clear=0.9)
	pos, yaw = k.beside(L - 200, 0, 0.0)
	k.place("DarkGate", pos, yaw)
	k.sky([(0.0, HAZE), (0.06, "F0602E"), (0.22, "C02018"), (0.55, "820A12"), (1.0, "3A0208")], strength=1.2, sun=(2.2, "FFC8A8", 25, 200))
