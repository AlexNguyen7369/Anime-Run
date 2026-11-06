# Sidekick side_fox: an orange nine-tailed fox on four chunky legs. Walks. Tail1 to Tail9 are separate parts rotating at the rump. Source and choices: docs/char_evidence/side_fox.md.
ID = "side_fox"
NAME = "Kurami"

RAMPS = {
	"fur": ["#a2400c", "#d8661a", "#f28e2e", "#ffbc64"],
	"deep": ["#702a08", "#ae4c12", "#d46e1e", "#f09644"],
	"pale": ["#c8843c", "#e8ac60", "#f8ce8c", "#fff0cc"],
	"dark": ["#0a0606", "#1a100e", "#2c1c18", "#463026"],
	"eye": ["#d0b878", "#ecd896", "#fbf2c4", "#ffffff"],
	"iris": ["#7c0c0c", "#ba1c14", "#e23a20", "#ff6e42"],
	"tooth": ["#c0b8a0", "#e0dac6", "#f4f0e0", "#ffffff"],
	"mouth": ["#340a0c", "#5a1214", "#7e1e1e", "#a23028"],
	"claw": ["#403426", "#7c6c58", "#c8b8a0", "#f6efe0"],
}
TAIL_ROOT = (0, 1.5, 1.9)


def head(m):
	h, cy = "Head", -1.2
	# wide angular skull, wedge muzzle
	m.block(h, "fur", 0, cy, 3.28, 1.72, 1.14, 0.82, ch=0.16, mids=(2.6,), jit=0.018, a=0.56, b=0.36)
	m.block(h, "fur", 0, cy - 0.72, 2.46, 1.52, 0.62, 0.52, ch=0.12, flare=-0.05, jit=0.012, a=0.58, b=0.34)
	m.block(h, "fur", 0, cy - 1.06, 2.34, 1.76, 0.38, 0.32, ch=0.08, a=0.6, b=0.32)
	y = cy - 0.84
	# the dark mask running from each eye up into the ear, the eye a white slant with a red iris
	for s in (1, -1):
		m.plate(h, "dark", [(s * 0.14, y, 2.5), (s * 0.54, y, 2.34), (s * 1.16, y, 2.84), (s * 1.16, y, 3.28), (s * 0.68, y, 3.12)], (0, 0.04, 0), a=0.5, b=0.05, g=0.0)
		m.plate(h, "eye", [(s * 0.24, y - 0.04, 2.58), (s * 0.56, y - 0.04, 2.46), (s * 0.94, y - 0.04, 2.84), (s * 0.68, y - 0.04, 2.92)], (0, 0.02, 0), a=0.9, b=0.0, g=0.0)
		m.plate(h, "iris", [(s * 0.42, y - 0.06, 2.54), (s * 0.66, y - 0.06, 2.56), (s * 0.74, y - 0.06, 2.8), (s * 0.54, y - 0.06, 2.8)], (0, 0.02, 0), a=0.72, b=0.0, g=0.0)
		m.plate(h, "dark", [(s * 0.5, y - 0.08, 2.58), (s * 0.58, y - 0.08, 2.58), (s * 0.64, y - 0.08, 2.74), (s * 0.56, y - 0.08, 2.76)], (0, 0.01, 0), a=0.5, b=0.0, g=0.0)
		# the hooded brow, heavy and angry
		m.plate(h, "fur", [(s * 0.08, y - 0.08, 2.72), (s * 1.18, y - 0.08, 3.14), (s * 1.18, y - 0.08, 3.4), (s * 0.08, y - 0.08, 3.1)], (0, 0.12, 0), a=0.58, b=0.36, g=0.24)
		# fur tufts at the cheek
		for i, (x, z, tx, tz) in enumerate(((1.0, 2.0, 1.56, 1.66), (1.0, 2.4, 1.62, 2.26), (0.8, 1.76, 1.16, 1.3))):
			m.spike(h, "fur", (s * x, cy, z), (s * tx, cy + 0.2, tz), 0.26, flat=0.6, a=0.54, b=0.36)
		ear(m, s)
	# muzzle: black nose, black lips round the fanged grin
	ym = cy - 1.42
	m.block(h, "dark", 0, ym, 2.36, 2.08, 0.22, 0.1, ch=0.05, a=0.56, b=0.3)
	m.plate(h, "dark", [(-0.62, ym + 0.14, 2.06), (0.62, ym + 0.14, 2.06), (0.5, ym + 0.14, 1.54), (-0.5, ym + 0.14, 1.54)], (0, 0.04, 0), a=0.5, b=0.05, g=0.0)
	m.plate(h, "mouth", [(-0.5, ym + 0.1, 2.0), (0.5, ym + 0.1, 2.0), (0.42, ym + 0.1, 1.62), (-0.42, ym + 0.1, 1.62)], (0, 0.03, 0), a=0.5, b=0.05, g=0.0)
	for i in range(-2, 3):
		x = i * 0.2
		long = 0.34 if abs(i) == 2 else 0.2
		m.plate(h, "tooth", [(x - 0.09, ym + 0.07, 2.0), (x + 0.09, ym + 0.07, 2.0), (x, ym + 0.07, 2.0 - long)], (0, 0.03, 0), a=0.78, b=0.1, g=0.0)
		m.plate(h, "tooth", [(x - 0.08, ym + 0.07, 1.62), (x + 0.08, ym + 0.07, 1.62), (x, ym + 0.07, 1.8)], (0, 0.03, 0), a=0.7, b=0.1, g=0.0)


def ear(m, s):
	"""Very long and upright, like a rabbit's: an orange slab with a black inner face."""
	h = "Head"
	outer = [(s * 0.46, -1.0, 3.1), (s * 0.3, -1.0, 4.1), (s * 0.6, -1.0, 5.2), (s * 1.04, -1.0, 5.72), (s * 1.42, -1.0, 4.9), (s * 1.42, -1.0, 3.9), (s * 1.12, -1.0, 2.98)]
	inner = [(s * 0.62, -1.09, 3.28), (s * 0.5, -1.09, 4.1), (s * 0.74, -1.09, 5.0), (s * 1.02, -1.09, 5.36), (s * 1.26, -1.09, 4.8), (s * 1.26, -1.09, 3.94), (s * 1.0, -1.09, 3.16)]
	m.plate(h, "fur", outer, (0, 0.18, 0), a=0.56, b=0.34, g=0.24)
	m.plate(h, "dark", inner, (0, 0.02, 0), a=0.2, b=0.05, g=0.05)


def body(m):
	b = "Body"
	m.path(b, "fur", [(0, -0.5, 1.5), (0, 0.3, 1.46), (0, 1.1, 1.62), (0, 1.56, 1.82)], [0.9, 0.86, 0.8, 0.46], [0.74, 0.72, 0.72, 0.46], n=8, a=0.54, b=0.36, jit=0.02)
	# the shaggy chest ruff and the shoulder humps
	for x, z, tz, r in ((0, 1.5, 0.6, 0.42), (0.5, 1.6, 0.74, 0.34), (-0.5, 1.6, 0.74, 0.34), (0.86, 1.8, 1.14, 0.3), (-0.86, 1.8, 1.14, 0.3)):
		m.spike(b, "pale", (x, -1.0, z), (x, -1.3, tz), r, flat=0.65, a=0.6, b=0.3)
	m.spike(b, "fur", (0, 0.4, 2.1), (0, 0.62, 2.74), 0.42, flat=0.55, a=0.56, b=0.36)
	m.spike(b, "fur", (0, 1.0, 2.2), (0, 1.3, 2.74), 0.34, flat=0.55, a=0.54, b=0.36)


def leg(m, name, x, y, s, hip_z, elbow, paw_y):
	"""One thick leg, splayed like a crouching beast's, ending in a block paw and three pale claws."""
	knee = (x + s * elbow, y, 0.92)
	foot = (x + s * (elbow + 0.1), paw_y, 0.3)
	m.path(name, "fur", [(x, y, hip_z), knee, foot], [0.46, 0.4, 0.36], [0.5, 0.42, 0.36], n=8, a=0.54, b=0.36, jit=0.012)
	m.block(name, "fur", foot[0], paw_y - 0.14, 0.36, 0, 0.44, 0.52, ch=0.08, a=0.56, b=0.36)
	for dx in (-0.28, 0.0, 0.28):
		m.spike(name, "claw", (foot[0] + dx, paw_y - 0.56, 0.14), (foot[0] + dx, paw_y - 1.02, 0.01), 0.12, flat=0.7, a=0.62, b=0.3)


def tail(m, i, k):
	"""One of nine: fat in the middle, hooked to a point, spread in a fan from the rump."""
	n = f"Tail{i + 1}"
	V = k.Vector
	a = k.math.radians(-96 + 24 * i)
	d = V((k.math.sin(a), 0, k.math.cos(a)))
	side = V((d.z, 0, -d.x))
	bend = 1 if i % 2 else -1
	root = V(TAIL_ROOT)
	y = 0.3 + 0.1 * abs(i - 4)
	length = 3.6 + 0.6 * (1 - abs(i - 4) / 4)
	pts = [root, root + d * 0.3 * length + V((0, y, 0)), root + d * 0.62 * length + side * 0.28 * bend + V((0, y + 0.2, 0)), root + d * 0.88 * length + side * 0.2 * bend + V((0, y + 0.3, 0)), root + d * length - side * 0.62 * bend + V((0, y + 0.3, 0))]
	m.path(n, "deep", pts, [0.22, 0.36, 0.42, 0.28, 0.01], [0.26, 0.38, 0.44, 0.3, 0.01], n=8, a=0.56, b=0.36, g=0.1, jit=0.018)
	# a brighter upper fur along the crest of each tail
	m.path(n, "fur", [pts[1] + side * 0.08 * bend + V((0, -0.1, 0)), pts[2] + side * 0.08 * bend + V((0, -0.1, 0)), pts[3] + V((0, -0.08, 0))], [0.22, 0.32, 0.16], [0.3, 0.38, 0.18], n=6, a=0.6, b=0.34, g=0.1)


def build(k):
	parts = {
		"Body": ((0, 0.4, 1.5), None),
		"Head": ((0, -1.0, 1.9), "Body"),
		"LegFrontLeft": ((0.62, -0.5, 1.4), "Body"),
		"LegFrontRight": ((-0.62, -0.5, 1.4), "Body"),
		"LegBackLeft": ((0.68, 1.0, 1.4), "Body"),
		"LegBackRight": ((-0.68, 1.0, 1.4), "Body"),
	}
	parts.update({f"Tail{i + 1}": (TAIL_ROOT, "Body") for i in range(9)})
	m = k.Model(ID, RAMPS, parts)
	head(m)
	body(m)
	for name, x, y, s, hip, elbow, paw in (("LegFrontLeft", 0.62, -0.5, 1, 1.4, 0.72, -1.0), ("LegFrontRight", -0.62, -0.5, -1, 1.4, 0.72, -1.0), ("LegBackLeft", 0.68, 1.0, 1, 1.5, 0.62, 0.84), ("LegBackRight", -0.68, 1.0, -1, 1.5, 0.62, 0.84)):
		leg(m, name, x, y, s, hip, elbow, paw)
	for i in range(9):
		tail(m, i, k)
	return m
