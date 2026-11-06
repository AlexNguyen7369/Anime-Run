# Sidekick side_reindeer, Choppa: the small upright reindeer doctor in its smallest form. Walks. Humanoid-ish, built as a Sidekick.
# Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_reindeer.md.
# Front faces -Y; +X is the viewer's right in the front view, the figure's own left.
ID = "side_reindeer"
NAME = "Choppa"

RAMPS = {
	"fur": ["#5e3517", "#83502a", "#a56c3f", "#c58c5b"],
	"face": ["#b67e4d", "#d9a56f", "#edc08a", "#fbdcac"],
	"hat": ["#a52b4b", "#d24869", "#ec6d87", "#fa9aab"],
	"cream": ["#d9d4c8", "#ece8de", "#f8f5ee", "#ffffff"],
	"antler": ["#4b2c15", "#6e4522", "#8f6236", "#b0814f"],
	"band": ["#a09a84", "#c6bfa6", "#e0dac4", "#f2eedc"],
	"short": ["#7f1a1c", "#ad2a2a", "#d23f3a", "#ee6355"],
	"hoof": ["#1e120d", "#33211a", "#4b342a", "#654a3c"],
	"nose": ["#123a9a", "#1f58cf", "#3f7cec", "#79a9ff"],
	"ink": ["#0a0708", "#120d0e", "#1e1718", "#2c2425"],
	"white": ["#e4e4e8", "#f2f2f4", "#fafafc", "#ffffff"],
	"mouth": ["#54161e", "#7a222c", "#99323a", "#b84a50"],
}
FACE_Y = -0.92  # the front of the head block


def antler(k, m, s, part):
	"""A branching antler through the side of the hat: a thick beam, three prongs, block-cut."""
	V = k.Vector
	a, b, c = V((s * 1.05, 0.0, 4.2)), V((s * 1.78, 0.02, 4.62)), V((s * 2.08, 0.04, 5.45))
	m.path(part, "antler", [a, b], [0.28, 0.26], [0.26, 0.24], n=6, a=0.5, b=0.36, g=0.0)
	m.path(part, "antler", [b, c, c + V((s * 0.02, 0, 0.42))], [0.24, 0.21, 0.11], [0.22, 0.18, 0.1], n=6, a=0.52, b=0.36, g=0.0)
	m.path(part, "antler", [b + V((-s * 0.1, 0, 0.05)), b + V((-s * 0.14, -0.02, 0.5)), b + V((-s * 0.1, -0.02, 0.96))], [0.21, 0.18, 0.08], [0.19, 0.16, 0.08], n=6, a=0.52, b=0.36, g=0.0)
	m.path(part, "antler", [b + V((s * 0.05, 0.02, -0.02)), b + V((s * 0.58, 0.04, 0.0)), b + V((s * 0.98, 0.04, 0.2))], [0.2, 0.16, 0.07], [0.18, 0.14, 0.07], n=6, a=0.52, b=0.36, g=0.0)


def arm(k, m, s, part):
	x = s * 0.92
	m.block(part, "fur", x, 0, 2.18, 1.42, 0.27, 0.29, ch=0.05, flare=0.02, mids=(1.8,), a=0.5, b=0.34, g=0.1)
	m.block(part, "hoof", x, 0, 1.46, 1.2, 0.27, 0.3, ch=0.05, a=0.5, b=0.34, g=0.0)  # plain block hoof, no fingers


def leg(k, m, s, part):
	x = s * 0.36
	m.block(part, "fur", x, 0, 1.0, 0.3, 0.27, 0.29, ch=0.05, a=0.5, b=0.34, g=0.1)
	m.block(part, "hoof", x, -0.05, 0.3, 0.0, 0.3, 0.37, ch=0.05, a=0.5, b=0.34, g=0.0)
	# the short leg of the shorts, a real garment with a cuff
	m.block(part, "short", x, 0, 1.12, 0.62, 0.32, 0.34, ch=0.05, flare=0.025, a=0.52, b=0.34, g=0.12)


def build(k):
	math, V = k.math, k.Vector
	parts = {
		"Body": ((0, 0, 1.1), None),
		"Head": ((0, 0, 2.3), "Body"),
		"HeadHat": ((0, 0, 2.3), "Head"),
		"HeadAntlerLeft": ((1.05, 0, 4.2), "HeadHat"),
		"HeadAntlerRight": ((-1.05, 0, 4.2), "HeadHat"),
		"ArmLeft": ((0.84, 0, 2.08), "Body"),
		"ArmRight": ((-0.84, 0, 2.08), "Body"),
		"LegLeft": ((0.36, 0, 1.0), "Body"),
		"LegRight": ((-0.36, 0, 1.0), "Body"),
	}
	m = k.Model(ID, RAMPS, parts, a=0.52, b=0.32)
	b = "Body"
	# a chunky torso, pale chest fur, the shorts as a garment with a waistband
	m.block(b, "fur", 0, 0, 2.3, 1.05, 0.68, 0.52, ch=0.07, mids=(1.7,), a=0.5, b=0.34, g=0.1)
	m.block(b, "face", 0, -0.46, 2.2, 1.45, 0.42, 0.1, ch=0.04, a=0.56, b=0.3, g=0.1)
	m.block(b, "short", 0, 0, 1.3, 0.92, 0.72, 0.56, ch=0.05, a=0.52, b=0.34, g=0.1)
	m.block(b, "short", 0, 0, 1.36, 1.22, 0.74, 0.58, ch=0.03, a=0.42, b=0.28, g=0.0)
	# neck ruff, hard points
	for x in (-0.46, -0.16, 0.16, 0.46):
		base = V((x, -0.42, 2.42))
		m.spike(b, "fur", base, base + V((x * 0.3, -0.18, -0.46)), 0.17, flat=0.45, n=6, a=0.54, b=0.32)
	m.spike(b, "fur", (0, 0.5, 1.45), (0, 0.78, 1.28), 0.14, a=0.54, b=0.32)  # the stub of a tail
	h = "Head"
	# a wide head block with cheek points of fur
	m.block(h, "face", 0, 0, 3.72, 2.3, 1.06, 0.9, ch=0.12, mids=(3.2, 2.72), a=0.58, b=0.26, g=0.08)
	for s in (1, -1):
		for z, dx in ((3.02, 0.26), (2.68, 0.2)):
			base = V((s * 1.0, -0.2, z))
			m.spike(h, "face", base, base + V((s * (dx + 0.12), -0.04, -0.2)), 0.2, flat=0.6, n=6, a=0.54, b=0.3)
		# the big round eye: white ring, black disc, glint, on a flat face
		x, z = s * 0.5, 3.05
		ey = FACE_Y - 0.02
		m.disc(h, "white", (x, ey - 0.01, z), (0, -1, 0), 0.36, th=0.03, n=14, a=0.72, b=0.0, g=0.0, tone=0.0)
		m.disc(h, "ink", (x, ey - 0.03, z), (0, -1, 0), 0.27, th=0.03, n=14, a=0.4, b=0.0, g=0.0, tone=0.0)
		m.disc(h, "white", (x - 0.1, ey - 0.05, z + 0.11), (0, -1, 0), 0.08, th=0.02, n=8, a=0.8, b=0.0, g=0.0, tone=0.0)
		# the ear, sticking out sideways under the brim
		m.path(h, "fur", [(s * 1.0, -0.06, 3.26), (s * 1.3, -0.08, 3.22), (s * 1.56, -0.1, 3.04)], [0.2, 0.2, 0.05], [0.12, 0.11, 0.04], n=6, a=0.54, b=0.34, g=0.0)
		m.path(h, "face", [(s * 1.08, -0.16, 3.2), (s * 1.42, -0.2, 3.1)], [0.11, 0.05], 0.03, n=6, a=0.58, b=0.2, g=0.0)
	# small blue nose, the short line under it, the small open smile
	m.ell(h, "nose", (0, -0.99, 2.72), (0.17, 0.1, 0.13), rows=4, n=8, a=0.56, b=0.32, g=0.0, tone=0.0)
	m.plate(h, "ink", [(-0.02, -0.92, 2.64), (0.02, -0.92, 2.64), (0.02, -0.92, 2.5), (-0.02, -0.92, 2.5)], (0, 0.03, 0), a=0.4, b=0.0, g=0.0, tone=0.0)
	m.plate(h, "mouth", [(-0.22, -0.92, 2.52), (0.22, -0.92, 2.52), (0.14, -0.92, 2.38), (-0.14, -0.92, 2.38)], (0, 0.03, 0), a=0.5, b=0.0, g=0.0, tone=0.0)
	# the hat: a big faceted drum, a wide soft brim with a thick rolled rim
	hat = "HeadHat"
	crown = [(3.62, 1.2), (4.3, 1.24), (4.95, 1.2), (5.42, 1.04)]
	m.path(hat, "hat", [(0, 0, z) for z, _ in crown], [r for _, r in crown], n=8, a=0.56, b=0.3, g=0.1, tone=0.015)
	# the top, rounded off
	m.path(hat, "hat", [(0, 0, 5.42), (0, 0, 5.6), (0, 0, 5.68)], [1.04, 0.76, 0.36], n=8, a=0.56, b=0.3, g=0.04, tone=0.015)
	rings, n = [], 16
	for z, r in ((3.68, 1.2), (3.6, 1.72), (3.5, 1.9), (3.36, 1.92), (3.32, 1.74), (3.46, 1.2)):
		ring = []
		for j in range(n):
			ang = 2 * math.pi * j / n
			wave = 0.06 * math.cos(ang * 2) * (r - 1.2) / 0.7  # dips a little at the sides, as soft cloth
			ring.append((r * math.cos(ang), r * 0.96 * math.sin(ang) - 0.04, z - wave + 0.1 * max(0.0, -math.sin(ang)) * (r - 1.2) / 0.7))
		rings.append(ring)
	m.add(hat, "hat", *m._loft(rings), a=0.5, b=0.32, g=0.06, tone=0.015)
	# the white X across the flat front of the crown
	y = -1.27
	cx, cz, long, thick = 0, 4.42, 0.62, 0.21
	for sgn in (1, -1):
		ca, sa = 0.7071 * sgn, 0.7071
		pts = [(-long, -thick), (long, -thick), (long, thick), (-long, thick)]
		m.plate(hat, "cream", [(cx + px * ca - pz * sa, y, cz + px * sa + pz * ca) for px, pz in pts], (0, 0.045, 0), a=0.8, b=0.04, g=0.0, tone=0.0)
	antler(k, m, 1, "HeadAntlerLeft")
	antler(k, m, -1, "HeadAntlerRight")
	# the bandage on one antler
	mb = V((1.42, 0.01, 4.42))
	m.path("HeadAntlerLeft", "band", [mb + V((-0.12, 0, -0.07)), mb + V((0.12, 0, 0.07))], 0.31, 0.29, n=6, a=0.6, b=0.28, g=0.0)
	arm(k, m, 1, "ArmLeft")
	arm(k, m, -1, "ArmRight")
	leg(k, m, 1, "LegLeft")
	leg(k, m, -1, "LegRight")
	return m
