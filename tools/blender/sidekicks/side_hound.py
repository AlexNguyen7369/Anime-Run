# Sidekick side_hound, Rovar: a huge shaggy black hound with six ruby eyes and no ears or nose. Walks. Evidence: docs/char_evidence/side_hound.md.
# HeadNeon (eyes) draws emissive; HeadJaw is its own part. Hard facets, soft paint, in-house only.
# Front faces -Y; +X is the viewer's right in the front view, the hound's own left.
ID = "side_hound"
NAME = "Rovar"

RAMPS = {
	"fur": ["#0c0b10", "#1a1920", "#2c2a36", "#4c4a5c"],
	"shag": ["#16151e", "#2a2938", "#454356", "#74728c"],
	"muscle": ["#2a1418", "#472228", "#68343a", "#8c4c50"],
	"gum": ["#3a0a12", "#641420", "#8c2430", "#b43c44"],
	"mouth": ["#0e0306", "#1e060c", "#300a12", "#48121c"],
	"tooth": ["#a8a290", "#d2ccba", "#f2eee0", "#ffffff"],
	"socket": ["#030304", "#08070a", "#0e0d12", "#18161e"],
	"eye": ["#b00818", "#e01424", "#ff2c38", "#ff7a70"],
	"claw": ["#4a463c", "#827a68", "#bab09a", "#ece4d0"],
	"tongue": ["#701c30", "#a03048", "#c84c62", "#e87a88"],
}


def tuft(m, part, root, d, r, ramp="shag", **kw):
	root, d = m_v(root), m_v(d)
	m.spike(part, ramp, root, root + d, r, flat=0.55, a=kw.pop("a", 0.52), b=kw.pop("b", 0.38), **kw)


def m_v(p):
	from mathutils import Vector

	return Vector(p)


def head(m, k):
	h, V = "Head", k.Vector
	# a broad earless skull run straight into a long blunt muzzle: no nose
	m.path(h, "fur", [(0, -1.2, 4.1), (0, -1.9, 4.34), (0, -2.55, 4.34)], [1.15, 1.46, 1.4], [0.85, 0.96, 0.82], n=8, a=0.54, b=0.38, g=0.1)
	m.path(h, "fur", [(0, -2.3, 3.62), (0, -3.2, 3.52), (0, -3.85, 3.36)], [1.08, 0.88, 0.72], [0.52, 0.42, 0.32], n=8, a=0.54, b=0.38, g=0.1, jit=0.012)
	m.path(h, "gum", [(0, -2.2, 3.42), (0, -3.2, 3.3), (0, -3.86, 3.12)], [0.98, 0.82, 0.66], 0.14, n=8, a=0.5, b=0.3)
	m.path(h, "mouth", [(0, -1.9, 3.3), (0, -3.2, 3.2), (0, -3.6, 3.1)], [0.86, 0.68, 0.5], 0.1, n=8, a=0.4, b=0.1)
	# oversized fangs, bared all round
	def fang(x, y, z, l, r):
		m.path(h, "tooth", [(x, y, z + 0.14), (x * 1.02, y - 0.06, z - l * 0.5), (x * 0.98, y - 0.02, z - l)], [r, r * 0.72, 0.01], n=6, a=0.7, b=0.26, g=-0.08)
	for s in (1, -1):
		fang(s * 0.5, -3.84, 3.1, 1.0, 0.19)
		fang(s * 0.18, -3.95, 3.1, 0.5, 0.14)
		for y, x, l in ((-3.4, 0.76, 0.5), (-3.0, 0.86, 0.74), (-2.62, 0.94, 0.46), (-2.28, 0.96, 0.36)):
			fang(s * x, y, 3.2, l, 0.15)
		# three ruby eyes a side, climbing the skull in a slant
		n, e, u = V((0, -1, 0)), V((s * 0.9, 0, 0.44)), V((s * -0.44, 0, 0.9))
		for x, z in ((0.36, 4.36), (0.8, 4.58), (1.2, 4.86)):
			p = V((s * x, -2.6 if x < 1 else -2.56, z))
			m.plate(h, "socket", [p - e * 0.28, p - u * 0.22, p + e * 0.28, p + u * 0.2], n * 0.14, a=0.4, b=0.1)
			q = p + n * 0.09
			m.plate("HeadNeon", "eye", [q - e * 0.2, q - u * 0.15, q + e * 0.22, q + u * 0.1], n * 0.06, a=0.6, b=0.1, tone=0.0)
		# one heavy brow over the three
		m.path(h, "shag", [V((s * 0.06, -2.66, 4.52)), V((s * 0.6, -2.7, 4.82)), V((s * 1.15, -2.64, 5.1)), V((s * 1.5, -2.3, 5.16))], [0.14, 0.18, 0.16, 0.02], [0.14, 0.16, 0.14, 0.02], n=6, a=0.58, b=0.4)
		for x, y, z, dz in ((1.42, -2.0, 4.7, -0.1), (1.42, -2.1, 4.2, -0.4), (1.2, -1.9, 5.05, 0.14), (0.7, -2.2, 5.12, 0.22)):
			tuft(m, h, (s * x, y, z), (s * 0.2, 0.8, dz), 0.36)
		for (x, y, z), (dx, dy, dz), r in (((1.15, -1.7, 3.7), (0.5, 0.35, -0.62), 0.36), ((1.2, -1.55, 4.2), (0.62, 0.5, -0.18), 0.36), ((0.9, -1.45, 4.75), (0.42, 0.6, 0.34), 0.34), ((1.02, -2.1, 3.48), (0.34, 0.2, -0.56), 0.26), ((0.4, -1.5, 4.9), (0.12, 0.7, 0.42), 0.34)):
			tuft(m, h, (s * x, y, z), (s * dx, dy, dz), r)
	for y, z in ((-2.3, 5.05), (-1.8, 5.15)):
		tuft(m, h, (0, y, z), (0, 0.62, 0.3), 0.26)
	j = "HeadJaw"
	m.path(j, "fur", [(0, -1.8, 3.0), (0, -2.6, 2.62), (0, -3.3, 2.4), (0, -3.62, 2.36)], [0.92, 0.82, 0.64, 0.48], [0.32, 0.26, 0.2, 0.16], n=8, a=0.5, b=0.36, g=0.0)
	m.path(j, "gum", [(0, -1.9, 3.14), (0, -2.6, 2.84), (0, -3.3, 2.58), (0, -3.6, 2.5)], [0.84, 0.76, 0.6, 0.44], 0.08, n=8, a=0.46, b=0.3)
	m.path(j, "tongue", [(0, -2.0, 3.16), (0, -2.7, 2.96), (0, -3.3, 2.74)], [0.4, 0.42, 0.22], 0.08, n=8, a=0.55, b=0.3)
	for s in (1, -1):
		for y, x, z, l, r in ((-3.58, 0.36, 2.52, 0.62, 0.15), (-3.3, 0.54, 2.6, 0.36, 0.12), (-2.95, 0.66, 2.72, 0.46, 0.13), (-2.55, 0.74, 2.86, 0.36, 0.12)):
			m.path(j, "tooth", [(s * x, y, z - 0.12), (s * x, y, z + l * 0.5), (s * x, y, z + l)], [r, r * 0.7, 0.01], n=6, a=0.7, b=0.26)
		tuft(m, j, (s * 0.6, -2.4, 2.6), (s * 0.12, 0.3, -0.6), 0.24)
	tuft(m, j, (0, -3.0, 2.4), (0, 0.2, -0.5), 0.2)


def body(m):
	b = "Body"
	m.path(b, "fur", [(0, 2.5, 2.7), (0, 1.6, 2.85), (0, 0.4, 3.05), (0, -0.7, 3.45), (0, -1.4, 3.8)], [0.8, 1.04, 1.2, 1.42, 1.05], [0.8, 0.94, 1.1, 1.22, 0.9], n=8, a=0.52, b=0.38, g=0.16, jit=0.02)
	# bare muscle below: the pectorals and the ribbed belly
	for s in (1, -1):
		m.block(b, "muscle", s * 0.42, -1.35, 3.1, 2.2, 0.42, 0.5, ch=0.12, a=0.52, b=0.36, jit=0.012)
	for i in range(3):
		m.block(b, "muscle", 0, -0.4 + i * 0.75, 2.3 - 0.05 * i, 1.85 - 0.02 * i, 0.78 - 0.08 * i, 0.32, ch=0.1, a=0.48, b=0.34)
	rows = ((-1.35, 4.5, 1.0, 5, 0.7), (-0.75, 4.62, 1.15, 5, 0.75), (-0.05, 4.3, 1.1, 5, 0.7), (0.65, 4.0, 1.0, 4, 0.62), (1.3, 3.75, 0.9, 4, 0.58), (1.95, 3.5, 0.76, 4, 0.52))
	for i, (y, z, w, n, l) in enumerate(rows):
		for j in range(n):
			t = (j - (n - 1) / 2) / ((n - 1) / 2)
			tuft(m, b, (t * w, y, z - abs(t) ** 2 * 0.55), (t * 0.3, l * 0.75, l * (0.5 - abs(t) * 0.35)), 0.34, ramp="shag" if (i + j) % 2 else "fur")
	for s in (1, -1):
		for i, (x, y, z) in enumerate(((1.3, -1.1, 3.5), (1.4, -0.5, 3.1), (1.32, 0.2, 2.8), (1.18, 0.9, 2.65), (1.02, 1.6, 2.55), (1.4, -0.9, 4.0), (1.3, 0.1, 3.5), (1.15, 1.1, 3.2))):
			tuft(m, b, (s * x, y, z), (s * 0.42, 0.5, -0.8), 0.44, ramp="shag" if i % 2 else "fur")
		for x, z in ((0.95, 3.2), (0.5, 3.45)):
			tuft(m, b, (s * x, -1.6, z), (s * 0.1, -0.1, -0.75), 0.32)


def leg(m, name, s, x, y, back):
	z = 2.8 if back else 3.1
	knee = (s * (x + 0.12), y + (0.42 if back else -0.04), 1.3)
	foot = (s * (x + 0.1), y + (0.12 if back else -0.12), 0.4)
	m.path(name, "fur", [(s * x, y, z), (s * (x + 0.1), y, 2.2), knee, foot], [0.46, 0.56, 0.4, 0.4], [0.62, 0.66, 0.44, 0.42], n=8, a=0.52, b=0.38, g=0.14, jit=0.015)
	m.block(name, "muscle", s * (x - 0.3), y + (0.2 if back else -0.06), 2.3, 1.1, 0.2, 0.34, ch=0.08, a=0.48, b=0.34)
	m.block(name, "fur", foot[0], foot[1] - 0.18, 0.52, 0, 0.54, 0.62, ch=0.1, a=0.54, b=0.38)
	for dx in (-0.39, -0.13, 0.13, 0.39):  # four toes
		m.block(name, "shag", foot[0] + dx, foot[1] - 0.78, 0.34, 0, 0.13, 0.2, ch=0.04, a=0.54, b=0.36)
		m.spike(name, "claw", (foot[0] + dx, foot[1] - 0.92, 0.2), (foot[0] + dx, foot[1] - 1.34, 0.02), 0.11, a=0.62, b=0.3)
	for dy, dz in ((-0.4, 2.2), (0.1, 1.9), (0.45, 1.55)):
		tuft(m, name, (s * (x + 0.45), y + dy, dz), (s * 0.18, 0.3, -0.6), 0.28)
	tuft(m, name, (foot[0], foot[1] + 0.3, 0.95), (0, 0.34, -0.5), 0.26)


def build(k):
	from sidekick_solid import solid_blocks

	parts = {
		"Body": ((0, 0.4, 3.0), None),
		"Head": ((0, -1.4, 3.9), "Body"),
		"HeadNeon": ((0, -1.4, 3.9), "Head"),
		"HeadJaw": ((0, -1.9, 3.1), "Head"),
		"Tail": ((0, 2.4, 2.9), "Body"),
		"LegFrontLeft": ((0.85, -0.8, 2.8), "Body"),
		"LegFrontRight": ((-0.85, -0.8, 2.8), "Body"),
		"LegBackLeft": ((0.75, 1.85, 2.6), "Body"),
		"LegBackRight": ((-0.75, 1.85, 2.6), "Body"),
	}
	m = solid_blocks(k.Model(ID, RAMPS, parts, neon=("HeadNeon",), glow=1.3))
	head(m, k)
	body(m)
	m.path("Tail", "fur", [(0, 2.3, 2.9), (0, 3.0, 3.3), (0, 3.5, 3.9), (0, 3.6, 4.7)], [0.32, 0.46, 0.42, 0.02], n=8, a=0.52, b=0.38, jit=0.015)
	for y, z in ((2.9, 3.4), (3.3, 3.8), (3.55, 4.2)):
		for s in (1, 0, -1):
			tuft(m, "Tail", (s * 0.28, y, z), (s * 0.3, 0.35, 0.36), 0.24)
	for s, n in ((1, "Left"), (-1, "Right")):
		leg(m, "LegFront" + n, s, 0.85, -0.8, False)
		leg(m, "LegBack" + n, s, 0.75, 1.85, True)
	return m
