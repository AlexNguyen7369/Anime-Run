# Sidekick side_lucky: a white beckoning-cat figurine with a grumpy old face, walking upright. Walks. Source and choices: docs/char_evidence/side_lucky.md.
ID = "side_lucky"
NAME = "Turbo Nyan"

RAMPS = {
	"white": ["#a8a8b4", "#d0d0d8", "#f0f0f2", "#ffffff"],
	"ear": ["#8c1410", "#c4261c", "#e8402c", "#ff8064"],
	"spot": ["#2c0c0a", "#481814", "#682822", "#8c4238"],
	"ink": ["#060506", "#100e10", "#1c181c", "#302a30"],
	"mouth": ["#6c1c24", "#a83440", "#e0606a", "#ff9aa0"],
	"red": ["#6a0c10", "#a41820", "#d42a30", "#f4645c"],
	"green": ["#084028", "#106844", "#1c9464", "#4cc894"],
	"gold": ["#8a6210", "#c8962a", "#f0c648", "#fff0a8"],
	"bronze": ["#5c3a10", "#946426", "#c89444", "#f4cc80"],
}


def plate(m, part, ramp, y, pts, t=0.04, a=0.5, b=0.05):
	m.plate(part, ramp, [(x, y, z) for x, z in pts], (0, t, 0), a=a, b=b, g=0.0)


def head(m):
	h = "Head"
	# a big rounded cube head
	m.block(h, "white", 0, 0, 4.3, 2.0, 1.42, 1.14, ch=0.34, mids=(3.6, 2.7), jit=0.015, a=0.58, b=0.34)
	for s in (1, -1):
		outer = [(s * 0.36, 0.0, 4.1), (s * 0.62, 0.0, 5.0), (s * 0.98, 0.0, 5.5), (s * 1.3, 0.0, 4.9), (s * 1.4, 0.0, 3.8)]
		inner = [(s * 0.54, -0.2, 4.2), (s * 0.74, -0.2, 4.86), (s * 0.97, -0.2, 5.2), (s * 1.18, -0.2, 4.78), (s * 1.22, -0.2, 4.02)]
		m.plate(h, "white", outer, (0, 0.36, 0), a=0.56, b=0.34)
		m.plate(h, "ear", inner, (0, 0.08, 0), a=0.54, b=0.2)
	# the dark patch on the crown between the ears, running over the front edge
	m.block(h, "spot", 0, 0, 4.33, 4.2, 0.42, 0.8, ch=0.02, a=0.5, b=0.44)
	m.plate(h, "spot", [(-0.42, -0.79, 4.31), (0.42, -0.79, 4.31), (0.36, -1.02, 4.08), (0, -1.1, 4.0), (-0.36, -1.02, 4.08)], (0, -0.04, 0.04), a=0.5, b=0.3)
	# it runs down the back of the head too
	m.plate(h, "spot", [(-0.42, 0.79, 4.31), (0.42, 0.79, 4.31), (0.5, 1.12, 3.98), (-0.5, 1.12, 3.98)], (0, 0.04, 0.04), a=0.5, b=0.3)
	plate(m, h, "spot", 1.15, [(-0.5, 3.98), (0.5, 3.98), (0.56, 3.5), (0.2, 3.22), (-0.16, 3.4), (-0.52, 3.3)], t=0.05, a=0.5, b=0.2)
	for s in (1, -1):
		m.plate(h, "ear", [(s * 0.62, 0.19, 4.3), (s * 0.97, 0.19, 5.1), (s * 1.2, 0.19, 4.2)], (0, 0.03, 0), a=0.2, b=0.2)
	y = -1.16
	for s in (1, -1):
		# sour half-shut eyes: a heavy flat lid, a thin white slit with a wide bar pupil looking sideways, lashes above
		plate(m, h, "ink", y - 0.02, [(s * 0.26, 3.2), (s * 1.16, 3.26), (s * 1.12, 2.98), (s * 0.66, 2.9), (s * 0.28, 3.0)])
		plate(m, h, "white", y - 0.05, [(s * 0.36, 3.13), (s * 1.06, 3.17), (s * 1.02, 3.04), (s * 0.66, 2.98), (s * 0.38, 3.04)], a=0.95)
		plate(m, h, "ink", y - 0.08, [(0.1 + s * 0.56, 3.16), (0.1 + s * 0.9, 3.16), (0.1 + s * 0.86, 3.0), (0.1 + s * 0.58, 3.0)])
		plate(m, h, "ink", y - 0.06, [(s * 0.2, 3.26), (s * 1.24, 3.34), (s * 1.24, 3.22), (s * 0.2, 3.14)])
		for i in range(3):
			x = 0.5 + i * 0.24
			plate(m, h, "ink", y - 0.03, [(s * x, 3.3), (s * (x + 0.07), 3.3), (s * (x + 0.1), 3.48), (s * (x + 0.06), 3.48)])
		plate(m, h, "ink", y - 0.02, [(s * 0.14, 3.46), (s * 0.2, 3.36), (s * 0.5, 3.64), (s * 0.48, 3.72)])  # frown
		for i in range(3):
			z = 2.74 - i * 0.18
			plate(m, h, "ink", y - 0.02, [(s * 0.72, z), (s * 1.24, z + 0.06 - i * 0.05), (s * 1.24, z - 0.02 - i * 0.05), (s * 0.72, z - 0.07)])
	m.block(h, "ink", 0, y - 0.04, 2.86, 2.66, 0.18, 0.1, ch=0.05, a=0.56, b=0.3)
	# the mouth: an open scowl, turned down at both ends
	plate(m, h, "ink", y - 0.02, [(0, 2.6), (0.18, 2.56), (0.44, 2.12), (0.36, 2.08), (0, 2.18), (-0.36, 2.08), (-0.44, 2.12), (-0.18, 2.56)])
	plate(m, h, "mouth", y - 0.05, [(0, 2.5), (0.14, 2.46), (0.28, 2.2), (0, 2.24), (-0.28, 2.2), (-0.14, 2.46)], a=0.6)


def body(m):
	b = "Body"
	m.block(b, "white", 0, 0, 2.14, 0.66, 0.8, 0.66, ch=0.16, flare=0.12, mids=(1.5,), jit=0.015, a=0.54, b=0.36)
	m.block(b, "red", 0, 0, 2.12, 1.88, 0.84, 0.74, ch=0.06, a=0.54, b=0.42)
	# the green bib under the collar with its scalloped edge
	plate(m, b, "green", -0.78, [(-0.76, 1.9), (0.76, 1.9), (0.8, 1.5), (0.44, 1.3), (0, 1.2), (-0.44, 1.3), (-0.8, 1.5)], t=0.14, a=0.52, b=0.4)
	m.ell(b, "gold", (0, -0.92, 1.84), (0.2, 0.18, 0.2), rows=5, n=8, a=0.6, b=0.4)
	m.block(b, "ink", 0, -1.08, 1.86, 1.7, 0.025, 0.04, ch=0.01, a=0.5)
	# the big oval gold coin, its marks plain bars and a diamond, no writing
	m.disc(b, "bronze", (0, -0.96, 1.08), (0, -1, 0), 0.44, th=0.14, n=14, squash=1.42, a=0.56, b=0.3)
	m.disc(b, "gold", (0, -1.05, 1.08), (0, -1, 0), 0.36, th=0.05, n=14, squash=1.42, a=0.66, b=0.1)
	plate(m, b, "spot", -1.09, [(0, 1.5), (0.14, 1.32), (0, 1.14), (-0.14, 1.32)])
	for z in (1.02, 0.86, 0.7):
		plate(m, b, "spot", -1.09, [(-0.16, z), (0.16, z), (0.16, z - 0.07), (-0.16, z - 0.07)])
	# a tied bow at the back of the collar and a patch on the back
	for s in (1, -1):
		m.plate(b, "red", [(s * 0.04, 0.8, 1.98), (s * 0.44, 0.84, 2.16), (s * 0.46, 0.84, 1.72), (s * 0.04, 0.8, 1.86)], (0, 0.12, 0), a=0.54, b=0.4)
	m.block(b, "red", 0, 0.84, 2.06, 1.8, 0.12, 0.1, ch=0.03, a=0.6, b=0.4)
	plate(m, b, "spot", 0.72, [(-0.6, 1.5), (-0.1, 1.6), (0.0, 1.3), (-0.2, 1.06), (-0.62, 1.14)], t=0.08, a=0.5, b=0.2)
	m.block("Tail", "spot", 0, 1.3, 1.74, 1.46, 0.19, 0.19, ch=0.05, a=0.5, b=0.4)
	m.path("Tail", "white", [(0, 0.66, 0.94), (0, 1.0, 1.0), (0, 1.26, 1.3), (0, 1.3, 1.62)], [0.2, 0.2, 0.19, 0.1], n=8, a=0.54, b=0.36)


def build(k):
	from sidekick_solid import solid_blocks

	parts = {
		"Body": ((0, 0, 1.2), None),
		"Head": ((0, 0, 2.1), "Body"),
		"LeftArm": ((0.84, 0, 1.8), "Body"),
		"RightArm": ((-0.84, 0, 1.8), "Body"),
		"LeftLeg": ((0.44, 0, 0.7), "Body"),
		"RightLeg": ((-0.44, 0, 0.7), "Body"),
		"Tail": ((0, 0.66, 0.94), "Body"),
	}
	m = k.Model(ID, RAMPS, parts, {"RightArm": (0, 8, 0)})
	solid_blocks(m)
	head(m)
	body(m)
	# the beckoning paw up at the cheek, holding a gold ball; the other hangs
	m.path("LeftArm", "white", [(0.8, 0, 1.76), (1.32, -0.16, 1.5), (1.62, -0.4, 1.96), (1.64, -0.48, 2.14)], [0.28, 0.28, 0.27, 0.22], n=8, a=0.56, b=0.36)
	m.block("LeftArm", "white", 1.64, -0.48, 2.3, 1.92, 0.3, 0.28, ch=0.08, a=0.6, b=0.34)
	m.ell("LeftArm", "gold", (1.64, -0.5, 2.5), (0.26, 0.26, 0.26), rows=6, n=10, a=0.58, b=0.44)
	m.path("RightArm", "white", [(-0.8, 0, 1.76), (-1.16, -0.1, 1.36), (-1.2, -0.2, 0.9)], [0.28, 0.28, 0.26], n=8, a=0.54, b=0.36)
	m.block("RightArm", "white", -1.2, -0.22, 1.06, 0.68, 0.29, 0.29, ch=0.08, a=0.58, b=0.34)
	for s, side in ((1, "Left"), (-1, "Right")):
		l, x = f"{side}Leg", s * 0.46
		m.block(l, "white", x, 0, 0.86, 0.1, 0.4, 0.42, ch=0.08, a=0.54, b=0.36)
		m.block(l, "white", x, -0.18, 0.3, 0.0, 0.42, 0.6, ch=0.08, a=0.58, b=0.36)
		for dx in (-0.13, 0.13):
			m.block(l, "spot", x + dx, -0.79, 0.2, 0.04, 0.02, 0.02, ch=0.006, a=0.4)
	return m
