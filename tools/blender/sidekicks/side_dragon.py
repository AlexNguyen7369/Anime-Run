# Sidekick side_dragon, Solara Dragon: a huge crimson dragon with a horned snout and salmon belly plates. Flies; the wings flap at
# the shoulder. Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_dragon.md.
# Front faces -Y; +X is the viewer's right in the front view, the dragon's own left.
ID = "side_dragon"
NAME = "Solara Dragon"

RAMPS = {
	"scale": ["#4e0814", "#8a1424", "#b82434", "#e0485a"],
	"ridge": ["#380610", "#641020", "#8c1c2e", "#b03848"],
	"belly": ["#5e2a24", "#8e4a3c", "#b86e58", "#de9c80"],
	"membrane": ["#420a18", "#6e1428", "#962038", "#bc3c54"],
	"horn": ["#a04058", "#d87088", "#f4a4b0", "#ffd8dc"],
	"claw": ["#2c1a1c", "#50363a", "#806064", "#b89aa0"],
	"mouth": ["#1e0408", "#380a10", "#541218", "#701e24"],
	"tooth": ["#c0b49c", "#e0d6c0", "#f6f0e2", "#ffffff"],
	"eye": ["#1c64a0", "#2c8cd0", "#58b8f0", "#b0e8ff"],
	"dark": ["#12040a", "#1e080e", "#2c0e16", "#3e1820"],
}
SH = (0.9, 0.0, 3.5)


def head(m, k):
	h, V = "Head", k.Vector
	# a flat wedge: wide cheekbones, a straight bridge, blunt nostrils
	m.path(h, "scale", [(0, -2.0, 6.5), (0, -2.5, 6.6), (0, -3.1, 6.36), (0, -3.8, 5.96), (0, -4.4, 5.62)], [0.74, 1.04, 0.84, 0.6, 0.5], [0.6, 0.64, 0.52, 0.4, 0.3], n=8, a=0.55, b=0.38, g=0.08, jit=0.01)
	m.path(h, "ridge", [(0, -2.2, 7.28), (0, -3.0, 7.0), (0, -3.7, 6.54), (0, -4.2, 6.16)], [0.24, 0.28, 0.2, 0.16], 0.12, n=6, a=0.56, b=0.38)
	# the pale nose horn and a smaller one behind it
	m.spike(h, "horn", (0, -4.14, 6.02), (0, -4.36, 6.98), 0.28, flat=1.2, n=6, a=0.6, b=0.34)
	m.spike(h, "horn", (0, -3.5, 6.46), (0, -3.5, 6.92), 0.16, flat=1.2, n=6, a=0.58, b=0.34)
	m.path(h, "dark", [(0, -2.6, 5.94), (0, -3.6, 5.64), (0, -4.36, 5.36)], [0.86, 0.6, 0.46], 0.06, n=8, a=0.4, b=0.1)
	for s in (1, -1):
		m.block(h, "ridge", s * 0.34, -4.42, 5.82, 5.58, 0.14, 0.12, ch=0.04, a=0.55, b=0.35)
		m.block(h, "dark", s * 0.34, -4.54, 5.76, 5.64, 0.07, 0.03, ch=0.01, a=0.3, b=0.05)
		# a deep dark socket under a long angry brow plate, a narrow pale blue eye
		n = V((s * 0.66, -0.66, 0.36)).normalized()
		p = V((s * 0.84, -3.0, 6.48))
		e = V((s * 0.5, 0.78, 0.36))
		e = (e - n * e.dot(n)).normalized()
		u = n.cross(e).normalized()
		u = u if u.z > 0 else -u
		m.plate(h, "dark", [p - e * 0.42 - u * 0.04, p - e * 0.05 - u * 0.24, p + e * 0.38 - u * 0.08, p + e * 0.34 + u * 0.2, p - e * 0.2 + u * 0.1], n * 0.22, a=0.45, b=0.05)
		q = p + n * 0.13
		m.plate(h, "eye", [q - e * 0.28, q - u * 0.15, q + e * 0.26 - u * 0.02, q + e * 0.2 + u * 0.13], n * 0.04, a=0.72, b=0.0, tone=0.0)
		q = p + n * 0.16 + e * 0.02
		m.plate(h, "dark", [q - e * 0.05 + u * 0.0, q - u * 0.14, q + e * 0.06, q + u * 0.1], n * 0.03, a=0.4, b=0.0, tone=0.0)
		m.path(h, "scale", [p - e * 0.62 + u * 0.06 + n * 0.1, p + u * 0.28 + n * 0.2, p + e * 0.62 + u * 0.42], [0.12, 0.18, 0.06], [0.14, 0.18, 0.05], n=6, a=0.62, b=0.38)
		# a row of short spikes up the bridge and brow
		for x, y, z, l in ((0.36, -3.4, 6.5, 0.26), (0.46, -3.0, 6.76, 0.34), (0.56, -2.6, 6.98, 0.44)):
			m.spike(h, "horn", (s * x, y, z), (s * (x + 0.08), y + 0.24, z + l), 0.15, a=0.58, b=0.36)
		# the crown: long swept horns and a fan of short ones down the cheek and jaw
		m.path(h, "horn", [(s * 0.5, -2.3, 7.0), (s * 0.78, -1.8, 7.6), (s * 0.9, -1.1, 8.0), (s * 0.8, -0.4, 8.1)], [0.27, 0.22, 0.13, 0.01], n=6, a=0.58, b=0.36)
		m.path(h, "horn", [(s * 0.86, -2.2, 6.7), (s * 1.3, -1.8, 7.0), (s * 1.62, -1.2, 7.2)], [0.22, 0.16, 0.01], n=6, a=0.58, b=0.36)
		for (x, y, z), (dx, dy, dz), r, c in (((0.98, -2.3, 6.3), (0.6, 0.6, 0.06), 0.2, "horn"), ((0.9, -2.5, 6.0), (0.5, 0.5, -0.28), 0.18, "horn"), ((0.8, -2.9, 5.86), (0.36, 0.3, -0.26), 0.13, "horn"), ((0.2, -2.1, 7.1), (0.06, 0.6, 0.5), 0.2, "ridge")):
			m.spike(h, c, (s * x, y, z), (s * (x + dx), y + dy, z + dz), r, a=0.56, b=0.36)
		for y, x, l in ((-4.36, 0.34, 0.34), (-4.0, 0.5, 0.22), (-3.6, 0.6, 0.3), (-3.2, 0.72, 0.2)):
			m.path(h, "tooth", [(s * x, y, 5.5 + 0.28 * (y + 4.36)), (s * x, y, 5.5 + 0.28 * (y + 4.36) - l)], [0.1, 0.01], n=6, a=0.7, b=0.2)
	j = "HeadJaw"
	m.path(j, "scale", [(0, -2.3, 5.86), (0, -3.0, 5.5), (0, -3.7, 5.22), (0, -4.16, 5.08)], [0.8, 0.66, 0.46, 0.32], [0.26, 0.22, 0.16, 0.12], n=8, a=0.5, b=0.36)
	m.path(j, "mouth", [(0, -2.5, 5.92), (0, -3.1, 5.68), (0, -3.9, 5.32)], [0.62, 0.5, 0.26], 0.07, n=8, a=0.5, b=0.2)
	for s in (1, -1):
		for y, x, z in ((-4.04, 0.28, 5.2), (-3.6, 0.42, 5.36), (-3.2, 0.54, 5.5)):
			m.path(j, "tooth", [(s * x, y, z), (s * x, y, z + 0.3)], [0.09, 0.01], n=6, a=0.7, b=0.2)
		m.spike(j, "horn", (s * 0.6, -2.9, 5.5), (s * 0.94, -2.6, 5.16), 0.13, a=0.56, b=0.36)
	m.spike(j, "horn", (0, -3.8, 5.04), (0, -3.72, 4.66), 0.13, a=0.56, b=0.36)


def body(m, k):
	V = k.Vector
	b, n = "Body", "Neck"
	m.path(b, "scale", [(0, 2.4, 2.5), (0, 1.5, 2.62), (0, 0.3, 2.9), (0, -0.7, 3.3), (0, -1.1, 3.6)], [0.78, 1.16, 1.4, 1.42, 1.0], [0.72, 1.0, 1.2, 1.14, 0.9], n=8, a=0.54, b=0.38, g=0.14, jit=0.018)
	neck = [V(p) for p in ((0, -0.8, 3.6), (0, -1.5, 4.4), (0, -1.7, 5.3), (0, -2.0, 6.0), (0, -2.3, 6.5))]
	m.path(n, "scale", neck, [1.04, 0.92, 0.8, 0.72, 0.6], [0.94, 0.8, 0.7, 0.62, 0.5], n=8, a=0.54, b=0.38, g=0.1, jit=0.012)
	# broad overlapping throat and belly plates
	for part, y, z, hw in ((n, -2.3, 5.55, 0.56), (n, -2.36, 5.1, 0.62), (n, -2.36, 4.65, 0.7), (n, -2.24, 4.2, 0.78), (b, -2.2, 3.74, 0.86), (b, -2.06, 3.28, 0.9), (b, -1.84, 2.84, 0.92), (b, -1.5, 2.46, 0.88)):
		m.block(part, "belly", 0, y + 0.2, z + 0.28, z - 0.3, hw * 0.92, 0.4, ch=0.08, a=0.54, b=0.36, g=0.26)
	for y, z, w in ((-0.6, 2.2, 0.92), (0.1, 1.95, 0.9), (0.8, 1.85, 0.84), (1.5, 1.82, 0.74)):
		m.block(b, "belly", 0, y, z + 0.2, z - 0.16, w, 0.34, ch=0.08, a=0.5, b=0.34)
	# dorsal spikes
	for part, y, z, dy, dz, r in ((n, -1.45, 6.4, 0.5, 0.5, 0.2), (n, -1.15, 5.8, 0.6, 0.36, 0.22), (n, -0.95, 5.1, 0.62, 0.3, 0.24), (n, -0.6, 4.5, 0.6, 0.4, 0.26), (b, -0.1, 4.0, 0.5, 0.6, 0.28), (b, 0.6, 3.8, 0.48, 0.6, 0.28), (b, 1.3, 3.5, 0.48, 0.55, 0.26), (b, 1.95, 3.15, 0.45, 0.5, 0.24)):
		m.spike(part, "ridge", (0, y, z), (0, y + dy, z + dz), r * 1.2, flat=0.8, a=0.56, b=0.38)
	# big shoulder scales
	for s in (1, -1):
		for x, y, z in ((1.2, -0.9, 3.9), (1.4, -0.4, 3.5), (1.36, 0.3, 3.1), (1.24, 1.0, 2.9)):
			m.plate(b, "ridge", [(s * x, y - 0.35, z + 0.1), (s * (x - 0.15), y, z + 0.5), (s * x, y + 0.4, z + 0.1), (s * (x + 0.06), y + 0.05, z - 0.4)], (s * 0.16, 0, 0.05), a=0.6, b=0.34)
	t = "Tail"
	tail = [V(p) for p in ((0, 2.1, 2.5), (0, 3.2, 2.2), (0.3, 4.2, 2.2), (0.7, 5.0, 2.7), (0.8, 5.5, 3.4))]
	m.path(t, "scale", tail, [0.74, 0.56, 0.42, 0.27, 0.06], [0.68, 0.5, 0.38, 0.25, 0.06], n=8, a=0.54, b=0.38, jit=0.012)
	for p in tail[1:4]:
		m.spike(t, "ridge", p + V((0, 0, 0.3)), p + V((0, 0.4, 0.8)), 0.22, a=0.56, b=0.38)
	for d in ((0.5, 0.4, 0.5), (-0.5, 0.4, 0.5), (0, 0.5, 0.75)):
		m.spike(t, "horn", tail[4] - V((0, 0.08, 0.15)), tail[4] + V(d), 0.18, flat=0.6, a=0.56, b=0.36)


def wing(m, k, s, part):
	V = k.Vector
	f = lambda x, y, z: V((s * x, y, z))
	sh, elbow, wrist = f(*SH), f(2.0, 0.5, 5.0), f(3.3, 0.3, 6.6)
	tips = [f(6.6, 1.0, 6.9), f(6.5, 1.3, 4.9), f(5.3, 1.5, 3.2), f(3.4, 1.4, 2.4), f(1.3, 0.9, 2.4)]
	m.path(part, "scale", [sh, elbow], [0.48, 0.36], [0.46, 0.34], n=8, a=0.56, b=0.38)
	m.path(part, "scale", [elbow, wrist], [0.36, 0.26], [0.34, 0.24], n=8, a=0.56, b=0.38)
	m.ell(part, "scale", tuple(elbow), (0.42, 0.4, 0.42), rows=4, n=8, a=0.56, b=0.38)
	m.spike(part, "horn", wrist, wrist + f(0.0, -0.5, 1.0), 0.24, a=0.58, b=0.36)
	roots = [wrist, wrist, wrist, elbow, sh]
	for i in range(3):
		mid = roots[i].lerp(tips[i], 0.5) + V((0, -0.1, 0.04))
		m.path(part, "scale", [roots[i], mid, tips[i]], [0.2, 0.15, 0.02], n=6, a=0.56, b=0.36)
	m.path(part, "scale", [elbow, elbow.lerp(tips[3], 0.5), tips[3]], [0.2, 0.14, 0.02], n=6, a=0.54, b=0.36)
	for i in range(4):
		a, b = tips[i], tips[i + 1]
		ra, rb = roots[i], roots[i + 1]
		# a scalloped trailing edge, three rows from the bone to the edge
		grid = []
		for r in range(4):
			v = r / 3
			row = []
			for c in range(5):
				u = c / 4
				root = ra.lerp(rb, u)
				edge = a.lerp(b, u)
				edge = edge.lerp(root, 0.2 * k.math.sin(k.math.pi * u))
				row.append(root.lerp(edge, 0.03 + 0.97 * v) + V((0, 0.16 * k.math.sin(k.math.pi * u) * v, 0)))
			grid.append(row)
		m.sheet(part, "membrane", grid, (0, 0.07, 0), a=0.54 - 0.06 * (i % 2), b=0.26, g=0.2)


def leg(m, name, s, x, y, back):
	z = 2.6 if back else 3.0
	knee = (s * (x + 0.35), y + (-0.5 if back else 0.25), 1.35)
	foot = (s * (x + 0.3), y + (0.1 if back else -0.25), 0.4)
	m.path(name, "scale", [(s * x, y, z), knee, foot], [0.62, 0.48, 0.38], [0.72, 0.5, 0.38], n=8, a=0.54, b=0.38, jit=0.012)
	m.spike(name, "horn", (knee[0], knee[1] + (-0.3 if back else 0.2), knee[2]), (knee[0] + s * 0.15, knee[1] + (-0.8 if back else 0.75), knee[2] + 0.2), 0.18, a=0.56, b=0.36)
	m.block(name, "scale", foot[0], foot[1] - 0.2, 0.5, 0, 0.5, 0.56, ch=0.1, a=0.56, b=0.38)
	for dx in (-0.34, 0, 0.34):
		m.spike(name, "claw", (foot[0] + dx, foot[1] - 0.66, 0.2), (foot[0] + dx, foot[1] - 1.2, 0.02), 0.15, a=0.62, b=0.34)


def build(k):
	from sidekick_solid import solid_blocks

	parts = {
		"Body": ((0, 0.4, 2.9), None),
		"Neck": ((0, -0.8, 3.6), "Body"),
		"Head": ((0, -2.2, 6.3), "Neck"),
		"HeadJaw": ((0, -2.4, 5.9), "Head"),
		"Tail": ((0, 2.2, 2.5), "Body"),
		"WingLeft": (SH, "Body"),
		"WingRight": ((-SH[0], SH[1], SH[2]), "Body"),
		"LegFrontLeft": ((0.95, -0.7, 2.8), "Body"),
		"LegFrontRight": ((-0.95, -0.7, 2.8), "Body"),
		"LegBackLeft": ((0.9, 1.6, 2.4), "Body"),
		"LegBackRight": ((-0.9, 1.6, 2.4), "Body"),
	}
	m = solid_blocks(k.Model(ID, RAMPS, parts))
	head(m, k)
	body(m, k)
	for s, n in ((1, "Left"), (-1, "Right")):
		wing(m, k, s, "Wing" + n)
		leg(m, "LegFront" + n, s, 0.95, -0.7, False)
		leg(m, "LegBack" + n, s, 0.9, 1.6, True)
	return m
