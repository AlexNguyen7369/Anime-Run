# Sidekick side_reaper: a shinigami on chunky block proportions. Flies: WingLeft and WingRight rotate at their roots. Source and choices: docs/char_evidence/side_reaper.md.
ID = "side_reaper"
NAME = "Ryuuk"

RAMPS = {
	"skin": ["#5c6c92", "#8a9ac0", "#bac8e2", "#eaf0ff"],
	"lip": ["#0c0e1c", "#1a1e36", "#2c3054", "#464c78"],
	"hair": ["#04050b", "#0e101c", "#1c2034", "#3c4464"],
	"feather": ["#05060c", "#10121c", "#212438", "#4a5070"],
	"cloth": ["#07070c", "#13131c", "#242432", "#3e3e52"],
	"yellow": ["#d8980e", "#f4c41c", "#ffdc3c", "#fff08c"],
	"red": ["#860e0e", "#c21c1c", "#e8342c", "#ff6a50"],
	"pupil": ["#000000", "#040406", "#0a0a10", "#14141c"],
	"tooth": ["#b0b0a8", "#d8d8cc", "#f0f0e6", "#ffffff"],
	"silver": ["#646876", "#a2a6b4", "#d4d8e0", "#ffffff"],
	"mouth": ["#120406", "#22080c", "#361014", "#4c1a1c"],
}


def face(m):
	h = "Head"
	m.block(h, "skin", 0, 0, 6.02, 4.3, 1.0, 0.88, ch=0.14, mids=(5.2,), jit=0.012, a=0.56, b=0.3)
	m.block(h, "skin", 0, -0.08, 4.5, 4.08, 0.74, 0.72, ch=0.09, a=0.5, b=0.3)  # the jaw
	y = -0.9
	for s in (1, -1):
		# bulging eyes: dark socket, yellow ball, red ring, small black dot
		m.disc(h, "lip", (s * 0.47, y, 5.3), (0, -1, 0), 0.47, th=0.03, n=12, a=0.5, b=0.1, g=0.0)
		m.disc(h, "yellow", (s * 0.47, y - 0.05, 5.3), (0, -1, 0), 0.39, th=0.04, n=12, a=0.75, b=0.1, g=0.1)
		m.disc(h, "red", (s * 0.47, y - 0.09, 5.3), (0, -1, 0), 0.22, th=0.03, n=10, a=0.7, b=0.05, g=0.0)
		m.disc(h, "pupil", (s * 0.47, y - 0.12, 5.3), (0, -1, 0), 0.11, th=0.02, n=8, a=0.5, b=0.0, g=0.0)
		# the earring and the ear behind it
		m.block(h, "skin", s * 1.05, 0, 5.3, 4.86, 0.09, 0.2, ch=0.03, a=0.48)
		m.ring(h, "silver", (s * 1.14, -0.02, 4.64), (0, 1, 0), 0.13, 0.03, n=8, a=0.6, b=0.3, g=0.0)
	# the wide grin rising at both ends: black lips, dark mouth, two rows of jagged teeth
	lips = [(-0.96, y, 5.06), (-0.7, y, 4.82), (0, y, 4.8), (0.7, y, 4.82), (0.96, y, 5.06), (0.84, y, 4.54), (0.42, y, 4.24), (-0.42, y, 4.24), (-0.84, y, 4.54)]
	m.plate(h, "lip", lips, (0, 0.05, 0), a=0.5, b=0.05, g=0.0)
	m.plate(h, "mouth", [(-0.8, y - 0.04, 4.86), (-0.62, y - 0.04, 4.72), (0.62, y - 0.04, 4.72), (0.8, y - 0.04, 4.86), (0.72, y - 0.04, 4.56), (0.38, y - 0.04, 4.34), (-0.38, y - 0.04, 4.34), (-0.72, y - 0.04, 4.56)], (0, 0.03, 0), a=0.5, b=0.05, g=0.0)
	for i in range(-3, 4):
		x = i * 0.2
		m.plate(h, "tooth", [(x - 0.1, y - 0.08, 4.73), (x + 0.1, y - 0.08, 4.73), (x, y - 0.08, 4.5)], (0, 0.03, 0), a=0.75, b=0.1, g=0.0)
		if abs(i) < 3:
			m.plate(h, "tooth", [(x - 0.1, y - 0.08, 4.36), (x + 0.1, y - 0.08, 4.36), (x, y - 0.08, 4.56)], (0, 0.03, 0), a=0.68, b=0.1, g=0.0)
	m.block(h, "skin", 0, -0.92, 5.0, 4.86, 0.09, 0.07, ch=0.02, a=0.46)  # a small nose


def hair(m):
	h = "Head"
	m.block(h, "hair", 0, 0.06, 6.32, 5.72, 1.02, 0.86, ch=0.12, jit=0.02, a=0.5, b=0.42)
	m.block(h, "hair", 0, 0.5, 5.8, 4.5, 1.04, 0.46, ch=0.1, jit=0.02, a=0.48, b=0.42)
	# wild tall spikes all round, each a thick faceted shard
	spikes = (
		(0.0, -0.3, 6.1, 0.0, -0.5, 8.0, 0.42),
		(0.5, -0.3, 6.1, 0.92, -0.42, 7.72, 0.38),
		(-0.5, -0.3, 6.1, -0.92, -0.42, 7.72, 0.38),
		(0.84, -0.2, 5.94, 1.86, -0.3, 7.04, 0.36),
		(-0.84, -0.2, 5.94, -1.86, -0.3, 7.04, 0.36),
		(0.92, 0.0, 5.56, 2.16, -0.1, 6.04, 0.32),
		(-0.92, 0.0, 5.56, -2.16, -0.1, 6.04, 0.32),
		(0.3, 0.4, 6.12, 0.46, 0.7, 8.1, 0.4),
		(-0.3, 0.4, 6.12, -0.46, 0.7, 8.1, 0.4),
		(0.82, 0.5, 5.9, 1.56, 1.0, 7.4, 0.36),
		(-0.82, 0.5, 5.9, -1.56, 1.0, 7.4, 0.36),
		(0.9, 0.6, 5.2, 1.96, 1.1, 5.26, 0.3),
		(-0.9, 0.6, 5.2, -1.96, 1.1, 5.26, 0.3),
		(0.0, 0.8, 5.5, 0.0, 1.9, 6.0, 0.36),
		(0.5, 0.8, 4.9, 0.8, 1.6, 4.3, 0.3),
		(-0.5, 0.8, 4.9, -0.8, 1.6, 4.3, 0.3),
	)
	for x0, y0, z0, x1, y1, z1, r in spikes:
		m.spike(h, "hair", (x0, y0, z0), (x1, y1, z1), r, flat=0.75, a=0.5, b=0.46)
	# the fringe: shards falling over the forehead, between the eyes
	for x0, x1, z1 in ((-0.86, -0.98, 5.62), (-0.46, -0.3, 5.54), (0.0, -0.02, 5.42), (0.46, 0.3, 5.54), (0.86, 0.98, 5.62)):
		m.spike(h, "hair", (x0, -0.86, 6.14), (x1, -0.98, z1), 0.25, flat=0.5, a=0.54, b=0.44)


def torso(m):
	t = "Torso"
	m.block(t, "skin", 0, 0, 4.02, 2.82, 1.04, 0.56, ch=0.06, a=0.52, b=0.32)
	for s in (1, -1):
		m.plate(t, "skin", [(s * 0.06, -0.6, 3.82), (s * 0.96, -0.6, 3.82), (s * 0.94, -0.6, 3.22), (s * 0.5, -0.6, 3.02), (s * 0.06, -0.6, 3.1)], (0, 0.08, 0), a=0.56, b=0.3, g=0.2)
	# black trousers from the waist, with crossed belts and a skull-plate buckle
	m.block(t, "cloth", 0, 0, 2.92, 1.96, 1.06, 0.6, ch=0.05, a=0.48, b=0.42)
	for z, tilt in ((2.76, 0.0), (2.44, 0.12)):
		rows = [[(1.1, -0.64, z + tilt), (1.1, 0.64, z + tilt), (-1.1, 0.64, z - tilt), (-1.1, -0.64, z - tilt)], [(1.1, -0.64, z - 0.14 + tilt), (1.1, 0.64, z - 0.14 + tilt), (-1.1, 0.64, z - 0.14 - tilt), (-1.1, -0.64, z - 0.14 - tilt)]]
		m.add(t, "silver", *m._loft(rows), a=0.32, b=0.3, g=0.0)
	m.block(t, "silver", 0, -0.66, 2.86, 2.42, 0.26, 0.05, ch=0.03, a=0.62, b=0.26)
	for s in (1, -1):
		m.block(t, "pupil", s * 0.1, -0.71, 2.74, 2.64, 0.06, 0.02, ch=0.008, a=0.5, b=0.0, g=0.0)
	# the necklace of little bones and a chain across the bare chest
	for i in range(-4, 5):
		x = i * 0.21
		z = 3.46 + 0.03 * i * i
		m.block(t, "tooth", x, -0.68, z, z - 0.2, 0.05, 0.035, ch=0.012, a=0.64, b=0.22)
	# the feather ruff round the neck and over the shoulders
	for i in range(13):
		a = -1.5 + i * 0.25
		sx = 1 if a >= 0 else -1
		root = (0.5 * m.k.math.sin(a), -0.34 * m.k.math.cos(a), 4.08)
		# short in front, so the bare chest and its necklace show; long over the shoulders
		front = abs(m.k.math.cos(a))
		tip = (1.5 * m.k.math.sin(a), -0.92 * front - 0.04, 3.3 + 0.1 * (i % 2) + 0.55 * front)
		m.spike(t, "feather", root, tip, 0.25, flat=0.45, a=0.5, b=0.44)
	m.block(t, "feather", 0, 0.05, 4.22, 3.92, 0.98, 0.72, ch=0.08, jit=0.02, a=0.48, b=0.44)
	# the small back plate the wings hang from
	m.block(t, "cloth", 0, 0.62, 3.9, 3.2, 0.74, 0.1, ch=0.03, a=0.46)


def arm(m, side, s):
	a, x = f"{side}Arm", s * 1.52
	m.block(a, "cloth", x, 0, 3.92, 2.26, 0.46, 0.46, ch=0.06, a=0.46, b=0.42)
	# feathers over the shoulder
	for i, (dx, dz, tx, tz) in enumerate(((0.0, 4.02, 0.64, 3.2), (0.3, 4.02, 1.0, 3.5), (-0.2, 4.08, 0.26, 3.1))):
		m.spike(a, "feather", (x + s * dx, -0.1, dz), (x + s * tx, -0.3, tz), 0.26, flat=0.5, a=0.52, b=0.44)
		m.spike(a, "feather", (x + s * dx, 0.2, dz), (x + s * tx, 0.5, tz), 0.26, flat=0.5, a=0.46, b=0.44)
	# silver straps and a chain bracelet
	for z in (3.0, 2.72):
		m.block(a, "silver", x, 0, z, z - 0.09, 0.49, 0.49, ch=0.02, a=0.46, b=0.34)
	m.block(a, "skin", x, 0, 2.3, 1.74, 0.46, 0.46, ch=0.08, a=0.54, b=0.3)  # a plain block hand


def leg(m, side, s):
	l, x = f"{side}Leg", s * 0.52
	m.block(l, "cloth", x, 0, 2.0, 0.34, 0.47, 0.5, ch=0.05, a=0.48, b=0.42)
	# torn hems and a strap at the knee, and heavy boots
	for z in (1.26, 1.0):
		m.block(l, "silver", x, 0, z, z - 0.08, 0.5, 0.53, ch=0.02, a=0.44, b=0.34)
	m.spike(l, "feather", (x + s * 0.4, 0.0, 1.8), (x + s * 0.76, 0.0, 1.0), 0.18, flat=0.5, a=0.5, b=0.44)
	m.block(l, "cloth", x, -0.1, 0.5, 0, 0.53, 0.66, ch=0.07, a=0.44, b=0.42)
	m.block(l, "silver", x, -0.1, 0.42, 0.34, 0.54, 0.67, ch=0.02, a=0.42, b=0.34)


def wing(m, s, part):
	"""One wing of black feathers, from a root at the back: a thick arm with a double row of long jagged feathers hanging from it."""
	V = m.k.Vector
	root, elbow, wrist, tip = V((s * 0.52, 0.72, 3.72)), V((s * 1.9, 1.0, 5.3)), V((s * 3.2, 1.1, 5.8)), V((s * 4.3, 1.2, 5.3))
	m.path(part, "feather", [root, elbow, wrist, tip], [0.28, 0.3, 0.24, 0.02], [0.2, 0.2, 0.16, 0.02], n=6, a=0.5, b=0.46, jit=0.012)
	pts = [root.lerp(elbow, t / 4) for t in range(1, 5)] + [elbow.lerp(wrist, t / 4) for t in range(1, 5)] + [wrist.lerp(tip, t / 3) for t in range(1, 4)]
	count = len(pts)
	for layer, (length, width, depth, val) in enumerate(((2.1, 0.32, 0.0, 0.42), (1.1, 0.3, -0.1, 0.56))):
		for i, b in enumerate(pts):
			t = i / (count - 1)
			# inner feathers hang straight down, outer ones fan outward
			d = V((s * (0.05 + 1.0 * t), 0.05, -1.0 + 0.55 * t)).normalized() * (length * (0.8 + 0.5 * m.k.math.sin(m.k.math.pi * t)) * (0.9 + 0.12 * (i % 2)))
			n = d.cross(V((0, 1, 0))).normalized() * width
			f = b + V((0, 0.08 * i * 0.2 + depth, 0))
			m.plate(part, "feather", [f, f + d * 0.3 + n, f + d * 0.72 + n * 0.8, f + d, f + d * 0.72 - n * 0.8, f + d * 0.3 - n], (0, 0.06, 0), a=val + 0.03 * (i % 2), b=0.42, g=0.22)


def build(k):
	parts = {
		"Torso": ((0, 0, 3), None),
		"Head": ((0, 0, 4.08), "Torso"),
		"LeftArm": ((1.52, 0, 3.9), "Torso"),
		"RightArm": ((-1.52, 0, 3.9), "Torso"),
		"LeftLeg": ((0.52, 0, 2.0), "Torso"),
		"RightLeg": ((-0.52, 0, 2.0), "Torso"),
		"WingLeft": ((0.52, 0.72, 3.72), "Torso"),
		"WingRight": ((-0.52, 0.72, 3.72), "Torso"),
	}
	m = k.Model(ID, RAMPS, parts, a=0.5, b=0.42)
	m.k = k
	face(m)
	hair(m)
	torso(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm(m, side, s)
		leg(m, side, s)
		wing(m, s, f"Wing{side}")
	return m
