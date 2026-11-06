# Sidekick side_ant: a shadow ant-soldier marshal on chunky block proportions. Walks. Source and choices: docs/char_evidence/side_ant.md.
ID = "side_ant"
NAME = "Beroo"

RAMPS = {
	"shell": ["#05060c", "#0e1120", "#1c2542", "#384a80"],
	"plate": ["#0a0d1c", "#172038", "#2c3f72", "#5c74b8"],
	"dark": ["#020206", "#07080f", "#10121c", "#1c2030"],
	"claw": ["#262d48", "#58658e", "#a0b0d4", "#eef2ff"],
	"wing": ["#0a1024", "#1a2a58", "#2f4a94", "#6f8fd8"],
	"seam": ["#2a2ce8", "#3f48f0", "#5f70ff", "#a0b0ff"],
	"eye": ["#4c0cb0", "#6a14d8", "#8c30f4", "#c080ff"],
}
NEON = ("HeadNeon", "TorsoNeon", "LeftArmNeon", "RightArmNeon", "LeftLegNeon", "RightLegNeon")


def seam(m, part, pts, th=0.03, y=None):
	"""A thin glowing line, drawn as one flat strip between points in the XZ plane at depth y."""
	for a, c in zip(pts, pts[1:]):
		dx, dz = c[0] - a[0], c[1] - a[1]
		n = m.k.math.hypot(dx, dz) or 1
		ox, oz = -dz / n * 0.045, dx / n * 0.045
		m.plate(part, "seam", [(a[0] + ox, y, a[1] + oz), (c[0] + ox, y, c[1] + oz), (c[0] - ox, y, c[1] - oz), (a[0] - ox, y, a[1] - oz)], (0, th, 0), a=0.7, b=0.05, g=0.0)


def head(m):
	h, n = "Head", "HeadNeon"
	m.block(h, "shell", 0, 0, 5.72, 4.2, 1.0, 0.86, ch=0.14, flare=-0.22, mids=(5.1,), jit=0.015, a=0.46, b=0.42)
	# the V of the face, the big slanted eyes, and heavy brow plates over them
	m.plate(h, "dark", [(0, -0.88, 4.34), (0.9, -0.88, 5.36), (0.76, -0.88, 4.56), (0.34, -0.88, 4.2), (-0.34, -0.88, 4.2), (-0.76, -0.88, 4.56), (-0.9, -0.88, 5.36)], (0, 0.04, 0), a=0.5, b=0.05, g=0.0)
	for s in (1, -1):
		m.plate(n, "eye", [(s * 0.14, -0.92, 4.66), (s * 0.86, -0.92, 5.3), (s * 0.78, -0.92, 4.82), (s * 0.42, -0.92, 4.52)], (0, 0.03, 0), a=0.62, b=0.05, g=0.2)
		m.plate(h, "plate", [(s * 0.08, -0.95, 4.86), (s * 0.98, -0.95, 5.5), (s * 1.0, -0.95, 5.74), (s * 0.1, -0.95, 5.2)], (0, 0.1, 0), a=0.5, b=0.42, g=0.25)
		# two pairs of mandibles, closing under the chin
		m.path(h, "claw", [(s * 0.44, -0.72, 4.38), (s * 0.62, -1.28, 4.02), (s * 0.12, -1.62, 3.72)], [0.2, 0.15, 0.01], [0.14, 0.11, 0.01], n=6, a=0.42, b=0.42)
		m.path(h, "plate", [(s * 0.26, -0.8, 4.3), (s * 0.3, -1.1, 3.98), (s * 0.06, -1.2, 3.82)], [0.11, 0.08, 0.01], n=6, a=0.5, b=0.4)
		# horned crown
		m.spike(h, "plate", (s * 0.56, 0.1, 5.5), (s * 1.28, 0.42, 6.32), 0.24, flat=0.6, a=0.5, b=0.44)
		m.spike(h, "plate", (s * 0.8, 0.2, 5.0), (s * 1.5, 0.52, 5.42), 0.2, flat=0.6, a=0.48, b=0.44)
		m.spike(h, "plate", (s * 0.24, -0.2, 5.56), (s * 0.5, 0.02, 6.34), 0.2, flat=0.6, a=0.52, b=0.42)
		# the long antennae, the first thing a thumbnail shows of an ant
		m.path(h, "plate", [(s * 0.3, -0.5, 5.56), (s * 0.62, -0.5, 6.34), (s * 1.3, -0.1, 6.98), (s * 2.2, 0.6, 6.92), (s * 2.86, 1.2, 6.32)], [0.15, 0.13, 0.11, 0.08, 0.01], n=6, a=0.56, b=0.38)
	m.plate(h, "plate", [(0, -1.0, 4.2), (0.16, -1.0, 4.5), (0.2, -1.0, 5.3), (0, -1.0, 6.02), (-0.2, -1.0, 5.3), (-0.16, -1.0, 4.5)], (0, 0.12, 0), a=0.55, b=0.42, g=0.22)
	m.block(h, "dark", 0, 0, 4.3, 3.9, 0.62, 0.56, ch=0.05)


def torso(m):
	t, n = "Torso", "TorsoNeon"
	m.block(t, "dark", 0, 0, 3.98, 1.9, 1.06, 0.58, ch=0.06)
	y = -0.64
	for s in (1, -1):
		m.plate(t, "shell", [(s * 0.1, y, 3.92), (s * 1.08, y, 3.92), (s * 1.12, y, 3.14), (s * 0.62, y, 2.82), (s * 0.1, y, 2.88)], (0, 0.14, 0), a=0.46, b=0.42, g=0.26)
		seam(m, n, [(s * 0.14, 3.0), (s * 0.62, 3.04), (s * 1.02, 3.34)], y=y - 0.08)
		seam(m, n, [(s * 0.26, 3.62), (s * 0.84, 3.68)], y=y - 0.08)
		# back plates: the folded wing cases
		m.plate(t, "wing", [(s * 0.06, 0.66, 3.92), (s * 1.04, 0.66, 3.82), (s * 1.26, 0.72, 2.2), (s * 0.66, 0.78, 1.06), (s * 0.08, 0.7, 2.3)], (0, 0.08, 0), a=0.46, b=0.4, g=0.3)
		seam(m, n, [(s * 0.3, 3.5), (s * 0.7, 2.5), (s * 0.68, 1.5)], y=0.8)
	# the banded waist of a segmented insect, at full body width
	for i, z in enumerate((2.82, 2.5, 2.18)):
		m.block(t, "plate", 0, 0, z, z - 0.28, 1.1, 0.64, ch=0.05, a=0.46 - 0.03 * i, b=0.44)
	m.block(t, "shell", 0, 0, 4.14, 3.84, 0.74, 0.54, ch=0.05, a=0.46)


def gaster(m):
	"""The ant's abdomen behind the hips: it reads from the side, and sells the insect from the three-quarter view."""
	g = "Gaster"
	for i, (y, z, r) in enumerate(((0.92, 1.92, 0.5), (1.3, 1.72, 0.66), (1.74, 1.5, 0.62), (2.14, 1.28, 0.42))):
		m.ell(g, "shell", (0, y, z), (r * 1.05, 0.34, r), rows=4, n=8, a=0.46, b=0.44, g=0.1)
		if i in (1, 2):
			m.ring("TorsoNeon", "seam", (0, y + 0.2, z - 0.1), (0, 1, 0.45), r * 0.82, 0.03, n=8, a=0.7, b=0.05, g=0.0)
	m.spike(g, "plate", (0, 2.3, 1.2), (0, 2.82, 0.86), 0.16, a=0.5, b=0.42)


def arm(m, side, s):
	a, n, x = f"{side}Arm", f"{side}ArmNeon", s * 1.56
	m.block(a, "dark", x, 0, 3.86, 2.1, 0.47, 0.47)
	m.block(a, "shell", x + s * 0.04, 0, 4.3, 3.44, 0.66, 0.66, ch=0.16, mids=(3.86,), jit=0.018, a=0.48, b=0.46)
	m.block(a, "plate", x + s * 0.06, 0, 3.5, 3.16, 0.56, 0.58, ch=0.06, a=0.46, b=0.44)
	m.spike(a, "plate", (x + s * 0.22, -0.2, 4.18), (x + s * 1.02, -0.3, 5.0), 0.25, flat=0.6, a=0.5, b=0.42)
	m.spike(a, "plate", (x + s * 0.4, 0.22, 4.0), (x + s * 1.24, 0.38, 4.5), 0.2, flat=0.6, a=0.48, b=0.42)
	# the forearm is a plain block; three claw blades grow from the hand, no fingers
	m.block(a, "shell", x, 0, 3.12, 2.22, 0.55, 0.55, ch=0.06, flare=0.03, jit=0.012, a=0.46, b=0.44)
	m.spike(a, "plate", (x + s * 0.36, 0.3, 3.04), (x + s * 0.9, 0.7, 3.52), 0.15, flat=0.6, a=0.5, b=0.42)
	m.block(a, "plate", x, 0, 2.24, 1.66, 0.52, 0.52, ch=0.07, a=0.5, b=0.38)
	for dx in (-0.32, 0.0, 0.32):
		m.path(a, "claw", [(x + dx, -0.22, 1.76), (x + dx * 1.1, -0.5, 1.28), (x + dx * 1.2, -0.42, 0.62)], [0.14, 0.1, 0.01], [0.13, 0.09, 0.01], n=6, a=0.54, b=0.38)
	seam(m, n, [(x - 0.28, 2.98), (x + 0.1, 2.72), (x - 0.04, 2.34)], y=-0.6)


def leg(m, side, s):
	l, n, x = f"{side}Leg", f"{side}LegNeon", s * 0.56
	m.block(l, "dark", x, 0, 1.96, 0.3, 0.47, 0.49)
	m.block(l, "shell", x, -0.03, 1.92, 1.14, 0.53, 0.55, ch=0.05, jit=0.015, a=0.46, b=0.44)
	m.plate(l, "plate", [(x - 0.42, -0.64, 1.28), (x + 0.42, -0.64, 1.28), (x + 0.34, -0.64, 0.9), (x, -0.64, 0.68), (x - 0.34, -0.64, 0.9)], (0, 0.18, 0), a=0.52, b=0.4, g=0.2)
	m.spike(l, "plate", (x + s * 0.36, 0.1, 1.2), (x + s * 0.84, 0.3, 1.64), 0.16, flat=0.6, a=0.5, b=0.42)
	m.block(l, "shell", x, 0, 0.92, 0.3, 0.52, 0.54, ch=0.05, flare=0.02, a=0.46, b=0.44)
	m.block(l, "plate", x, -0.1, 0.34, 0, 0.56, 0.62, ch=0.05, a=0.46, b=0.44)
	for dx in (-0.3, 0.3):
		m.path(l, "claw", [(x + dx, -0.62, 0.17), (x + dx, -0.98, 0.14), (x + dx * 1.06, -1.28, 0.01)], [0.15, 0.12, 0.01], [0.12, 0.09, 0.01], n=6, a=0.54, b=0.38)
	seam(m, n, [(x + s * 0.3, 1.8), (x - s * 0.1, 1.5), (x + s * 0.12, 1.3)], y=-0.6)


def build(k):
	parts = {
		"Torso": ((0, 0, 3), None),
		"TorsoNeon": ((0, 0, 3), "Torso"),
		"Head": ((0, 0, 4.1), "Torso"),
		"HeadNeon": ((0, 0, 4.1), "Head"),
		"Gaster": ((0, 0.6, 2.1), "Torso"),
		"LeftArm": ((1.56, 0, 3.9), "Torso"),
		"LeftArmNeon": ((1.56, 0, 3.9), "LeftArm"),
		"RightArm": ((-1.56, 0, 3.9), "Torso"),
		"RightArmNeon": ((-1.56, 0, 3.9), "RightArm"),
		"LeftLeg": ((0.56, 0, 2.0), "Torso"),
		"LeftLegNeon": ((0.56, 0, 2.0), "LeftLeg"),
		"RightLeg": ((-0.56, 0, 2.0), "Torso"),
		"RightLegNeon": ((-0.56, 0, 2.0), "RightLeg"),
	}
	m = k.Model(ID, RAMPS, parts, neon=NEON)
	m.k = k
	head(m)
	torso(m)
	gaster(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm(m, side, s)
		leg(m, side, s)
	return m
