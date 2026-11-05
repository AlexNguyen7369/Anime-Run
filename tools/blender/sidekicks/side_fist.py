# Sidekick side_fist: a muscular fighting spirit on chunky block proportions. Flies with no wings: the hips and legs are separate Float parts that hang free below the torso. Source and choices: docs/char_evidence/side_fist.md.
ID = "side_fist"
NAME = "Star Platina"

RAMPS = {
	"skin": ["#2a2868", "#4745a4", "#716ed8", "#b2b4f8"],
	"mask": ["#12123a", "#1e1e56", "#2e2e76", "#444494"],
	"hair": ["#06040e", "#120a22", "#20143c", "#3a2664"],
	"gold": ["#6c480e", "#b88824", "#e8c250", "#fff0a8"],
	"scarf": ["#8c2210", "#cc4216", "#f0642a", "#ffa062"],
	"glove": ["#0c1a14", "#1c3026", "#2e4c3c", "#507460"],
	"cloth": ["#9a98a8", "#c8c6d2", "#e8e6ee", "#ffffff"],
	"cream": ["#b8a878", "#dccca0", "#f2e6c4", "#fffaea"],
	"white": ["#c4cce0", "#dfe6f4", "#f4f8ff", "#ffffff"],
}


def head(m):
	h = "Head"
	m.block(h, "skin", 0, 0, 5.82, 4.2, 0.92, 0.84, ch=0.12, mids=(5.0,), jit=0.012, a=0.54, b=0.36)
	y = -0.86
	# the dark band over the eyes and down the bridge of the nose
	m.plate(h, "mask", [(-0.9, y, 5.38), (0.9, y, 5.38), (0.9, y, 4.98), (0.2, y, 4.82), (0.14, y, 4.5), (-0.14, y, 4.5), (-0.2, y, 4.82), (-0.9, y, 4.98)], (0, 0.03, 0), a=0.5, b=0.1, g=0.0)
	for s in (1, -1):
		m.plate(h, "white", [(s * 0.2, y - 0.03, 5.06), (s * 0.74, y - 0.03, 5.26), (s * 0.76, y - 0.03, 5.08), (s * 0.3, y - 0.03, 4.94)], (0, 0.02, 0), a=0.9, b=0.0, g=0.0)
		m.plate(h, "hair", [(s * 0.12, y - 0.05, 5.1), (s * 0.82, y - 0.05, 5.38), (s * 0.82, y - 0.05, 5.5), (s * 0.12, y - 0.05, 5.24)], (0, 0.03, 0), a=0.5, b=0.1, g=0.0)  # a hard frown
	m.block(h, "skin", 0, -0.86, 4.84, 4.5, 0.11, 0.08, ch=0.03, a=0.58)  # nose
	m.plate(h, "mask", [(-0.34, y - 0.01, 4.42), (0.34, y - 0.01, 4.42), (0.3, y - 0.01, 4.34), (-0.3, y - 0.01, 4.34)], (0, 0.02, 0), a=0.5, b=0.1, g=0.0)  # a set mouth
	m.block(h, "skin", 0, -0.04, 4.36, 4.04, 0.66, 0.68, ch=0.08, a=0.48)  # jaw
	# the gold headband in three pieces with its upright oval
	for s in (1, -1):
		m.block(h, "gold", s * 0.52, -0.02, 5.72, 5.5, 0.44, 0.9, ch=0.04, a=0.58, b=0.32)
	m.disc(h, "gold", (0, -0.92, 5.62), (0, -1, 0), 0.2, th=0.08, n=10, squash=1.5, a=0.64, b=0.3)
	m.disc(h, "cream", (0, -0.97, 5.62), (0, -1, 0), 0.1, th=0.03, n=8, squash=1.5, a=0.7, b=0.1, g=0.0)


def hair(m):
	h = "Hair"
	m.block(h, "hair", 0, 0.1, 6.34, 5.66, 1.02, 0.96, ch=0.14, jit=0.025, a=0.5, b=0.46)
	m.block(h, "hair", 0, 0.62, 5.86, 4.36, 1.04, 0.46, ch=0.1, jit=0.025, a=0.48, b=0.44)
	# locks over the sides of the face
	for s in (1, -1):
		m.path(h, "hair", [(s * 0.92, -0.4, 5.9), (s * 1.08, -0.5, 5.1), (s * 1.0, -0.56, 4.38)], [0.2, 0.2, 0.01], [0.28, 0.22, 0.01], n=6, a=0.52, b=0.44)
	# the long wild hair, thrown up and back to one side as if in a wind
	locks = (
		((0.0, 0.2, 6.2), (0.5, 0.2, 7.1), (1.5, 0.4, 7.72), (2.7, 0.7, 7.5), 0.46),
		((0.4, 0.3, 6.2), (1.1, 0.5, 6.9), (2.2, 0.9, 6.92), (3.3, 1.2, 6.32), 0.42),
		((0.6, 0.5, 5.8), (1.4, 0.9, 6.0), (2.4, 1.2, 5.6), (3.2, 1.5, 4.7), 0.42),
		((-0.4, 0.2, 6.2), (-0.7, 0.3, 7.2), (-0.86, 0.5, 7.6), (-0.5, 0.7, 7.96), 0.48),
		((-0.7, 0.3, 6.0), (-1.5, 0.5, 6.7), (-2.3, 0.7, 7.1), (-3.0, 0.9, 6.96), 0.4),
		((-0.8, 0.5, 5.5), (-1.6, 0.8, 5.5), (-2.3, 1.1, 5.1), (-2.76, 1.3, 4.4), 0.38),
		((0.1, 0.9, 5.6), (0.4, 1.5, 5.2), (0.7, 1.9, 4.3), (0.5, 2.1, 3.2), 0.46),
		((-0.4, 0.9, 5.2), (-0.8, 1.4, 4.7), (-0.9, 1.7, 3.9), (-0.8, 1.86, 2.9), 0.42),
		((0.7, 0.8, 5.0), (1.2, 1.2, 4.4), (1.5, 1.5, 3.7), (1.34, 1.6, 2.96), 0.36),
		((0.0, -0.2, 6.3), (0.14, -0.5, 6.9), (0.62, -0.4, 7.46), (1.2, -0.2, 7.7), 0.42),
	)
	for a, b, c, d, r in locks:
		m.path(h, "hair", [a, b, c, d], [r * 1.25, r * 1.4, r * 1.0, 0.01], [r * 0.95, r * 1.0, r * 0.75, 0.01], n=6, a=0.5, b=0.46, jit=0.012)


def torso(m):
	t = "Torso"
	m.block(t, "skin", 0, 0, 4.02, 2.3, 1.1, 0.6, ch=0.06, a=0.48, b=0.36)
	y = -0.62
	for s in (1, -1):
		# big square chest plates, and four rows of abdominal blocks
		m.plate(t, "skin", [(s * 0.04, y, 3.96), (s * 1.08, y, 3.96), (s * 1.12, y, 3.36), (s * 0.7, y, 3.04), (s * 0.04, y, 3.08)], (0, 0.14, 0), a=0.58, b=0.32, g=0.24)
		for z in (3.0, 2.72, 2.44):
			m.block(t, "skin", s * 0.34, y - 0.01, z, z - 0.25, 0.28, 0.08, ch=0.04, a=0.56, b=0.34)
		m.block(t, "skin", s * 0.84, y + 0.03, 3.0, 2.3, 0.2, 0.06, ch=0.03, a=0.48, b=0.34)
		# broad back plates
		m.plate(t, "skin", [(s * 0.04, 0.62, 3.98), (s * 1.08, 0.62, 3.98), (s * 1.1, 0.62, 3.0), (s * 0.6, 0.62, 2.4), (s * 0.04, 0.62, 2.4)], (0, 0.12, 0), a=0.5, b=0.34, g=0.2)
	# the gold line that wanders down the body
	line = [(0.0, 3.96), (0.0, 3.4), (0.14, 3.1), (-0.08, 2.74), (0.06, 2.3)]
	for a, c in zip(line, line[1:]):
		m.plate(t, "gold", [(a[0] - 0.045, y - 0.1, a[1]), (a[0] + 0.045, y - 0.1, a[1]), (c[0] + 0.045, y - 0.1, c[1]), (c[0] - 0.045, y - 0.1, c[1])], (0, 0.03, 0), a=0.68, b=0.1, g=0.0)
	m.block(t, "skin", 0, 0, 4.22, 3.9, 0.66, 0.54, ch=0.06, a=0.48)


def scarf(m):
	"""The short loop of scarf round the neck, and one end blown out behind."""
	c = "Scarf"
	m.block(c, "scarf", 0, -0.02, 4.34, 3.82, 0.92, 0.82, ch=0.14, flare=0.08, jit=0.02, a=0.5, b=0.42)
	m.plate(c, "scarf", [(-0.2, -0.9, 4.02), (0.62, -0.9, 3.98), (0.74, -0.84, 3.36), (0.26, -0.88, 3.56), (-0.1, -0.9, 3.24)], (0, 0.12, 0), a=0.54, b=0.4, g=0.22)
	m.plate(c, "scarf", [(-0.7, 0.72, 4.16), (0.0, 0.72, 4.16), (0.56, 1.4, 3.7), (1.1, 1.86, 3.62), (0.9, 2.1, 3.18), (0.34, 1.7, 3.1), (-0.52, 1.0, 3.5)], (0, 0.1, 0), a=0.5, b=0.38, g=0.26)


def shoulder(m, part, x, s):
	"""The big gold shoulder pad with its pale face and spiral line."""
	m.block(part, "gold", x + s * 0.06, 0, 4.4, 3.42, 0.72, 0.72, ch=0.2, mids=(3.86,), jit=0.015, a=0.52, b=0.42)
	top = (x + s * 0.06, 0, 4.44)
	m.disc(part, "cream", top, (0, 0, 1), 0.46, th=0.05, n=10, a=0.66, b=0.1, g=0.0)
	m.ring(part, "gold", (x + s * 0.06, 0, 4.47), (0, 0, 1), 0.36, 0.035, n=10, a=0.42, b=0.1, g=0.0)
	m.ring(part, "gold", (x + s * 0.06, 0, 4.47), (0, 0, 1), 0.18, 0.035, n=8, a=0.42, b=0.1, g=0.0)
	m.disc(part, "cream", (x + s * 0.06, -0.74, 3.94), (0, -1, 0), 0.38, th=0.04, n=10, a=0.66, b=0.1, g=0.0)
	m.ring(part, "gold", (x + s * 0.06, -0.76, 3.94), (0, -1, 0), 0.26, 0.03, n=10, a=0.42, b=0.1, g=0.0)
	m.ring(part, "gold", (x + s * 0.06, -0.76, 3.94), (0, -1, 0), 0.11, 0.03, n=8, a=0.42, b=0.1, g=0.0)


def arm(m, side, s):
	a, x = f"{side}Arm", s * 1.62
	m.block(a, "skin", x, 0, 3.94, 2.96, 0.54, 0.54, ch=0.06, a=0.52, b=0.34, jit=0.012)
	shoulder(m, a, x, s)
	m.block(a, "gold", x, 0, 3.06, 2.84, 0.58, 0.58, ch=0.04, a=0.56, b=0.36)  # elbow guard
	# the long dark glove with its gold band and studs, a plain block hand
	m.block(a, "glove", x, 0, 2.88, 1.76, 0.57, 0.57, ch=0.08, flare=0.02, a=0.5, b=0.42)
	m.block(a, "gold", x, 0, 2.5, 2.34, 0.6, 0.6, ch=0.03, a=0.56, b=0.36)
	for dx in (-0.3, -0.1, 0.1, 0.3):
		m.block(a, "gold", x + dx, -0.6, 2.0, 1.86, 0.075, 0.05, ch=0.015, a=0.66, b=0.3)


def lower_body(m):
	"""Hips and legs hang free under the torso, with a gap the game shows as hovering: each piece bobs on its own."""
	c = "FloatHips"
	m.block(c, "skin", 0, 0, 2.28, 1.8, 1.04, 0.58, ch=0.05, a=0.46, b=0.34)
	m.block(c, "gold", 0, 0, 2.36, 2.16, 1.12, 0.66, ch=0.04, a=0.54, b=0.38)
	m.ell(c, "gold", (0.62, -0.68, 2.26), (0.24, 0.1, 0.24), rows=4, n=8, a=0.56, b=0.4, g=0.0)
	# the white cloth, wrapped at the hips and flying open on one side
	m.plate(c, "cloth", [(-1.12, -0.72, 2.18), (0.46, -0.72, 2.18), (0.74, -0.84, 1.5), (0.36, -0.9, 0.86), (-0.12, -0.88, 1.2), (-0.58, -0.86, 0.56), (-1.24, -0.82, 1.04)], (0, 0.06, 0), a=0.6, b=0.28, g=0.24)
	# the loose end flies out past the hip
	m.plate(c, "cloth", [(0.5, -0.68, 2.14), (1.12, -0.62, 2.14), (1.86, -0.3, 1.52), (2.44, 0.1, 0.72), (1.72, -0.1, 0.92), (1.36, -0.3, 0.62), (0.86, -0.56, 1.3)], (0, 0.06, 0), a=0.56, b=0.28, g=0.24)
	m.plate(c, "cloth", [(-1.04, 0.72, 2.18), (1.04, 0.72, 2.18), (1.3, 0.86, 1.3), (0.62, 0.96, 0.74), (0.08, 0.92, 1.1), (-0.6, 0.94, 0.62), (-1.28, 0.86, 1.24)], (0, 0.06, 0), a=0.54, b=0.28, g=0.24)


def leg(m, side, s):
	l, sh, x = f"FloatLeg{side}", f"FloatShin{side}", s * 0.58
	m.block(l, "skin", x, 0, 1.78, 0.96, 0.52, 0.56, ch=0.06, a=0.52, b=0.36, jit=0.012)
	m.block(l, "gold", x, -0.04, 1.04, 0.72, 0.5, 0.58, ch=0.06, a=0.56, b=0.38)  # knee guard
	# the shin floats a little clear of the knee; boot trim in gold, toes down
	m.block(sh, "skin", x, 0, 0.66, 0.06, 0.5, 0.54, ch=0.06, a=0.5, b=0.36)
	m.block(sh, "gold", x, 0, 0.14, -0.04, 0.54, 0.58, ch=0.03, a=0.56, b=0.38)
	m.block(sh, "skin", x, -0.08, -0.04, -0.44, 0.5, 0.58, ch=0.08, a=0.46, b=0.4)
	m.block(sh, "gold", x, -0.44, -0.2, -0.44, 0.34, 0.24, ch=0.04, a=0.58, b=0.36)


def build(k):
	parts = {
		"Torso": ((0, 0, 3), None),
		"Head": ((0, 0, 4.1), "Torso"),
		"Hair": ((0, 0, 5.8), "Head"),
		"Scarf": ((0, 0, 4.1), "Torso"),
		"LeftArm": ((1.62, 0, 3.9), "Torso"),
		"RightArm": ((-1.62, 0, 3.9), "Torso"),
		"FloatHips": ((0, 0, 2.2), "Torso"),
		"FloatLegLeft": ((0.58, 0, 1.8), "FloatHips"),
		"FloatLegRight": ((-0.58, 0, 1.8), "FloatHips"),
		"FloatShinLeft": ((0.58, 0, 0.66), "FloatLegLeft"),
		"FloatShinRight": ((-0.58, 0, 0.66), "FloatLegRight"),
	}
	# one fist thrown forward; the legs trail behind for flight
	pose = {"RightArm": (-68, 0, 0), "FloatLegLeft": (16, 0, 0), "FloatLegRight": (26, 0, 0), "FloatShinLeft": (14, 0, 0), "FloatShinRight": (18, 0, 0)}
	m = k.Model(ID, RAMPS, parts, pose)
	head(m)
	hair(m)
	torso(m)
	scarf(m)
	lower_body(m)
	for s, side in ((1, "Left"), (-1, "Right")):
		arm(m, side, s)
		leg(m, side, s)
	return m
