# Sidekick side_cat, Meowee: a round-headed grey-white house cat with dark patches, sleepy half-lidded eyes and a ringed tail. Walks. Evidence: docs/char_evidence/side_cat.md.
ID = "side_cat"
NAME = "Meowee"
RAMPS = {
	"fur": ["#a89c8e", "#cfc4b6", "#efe7dc", "#ffffff"],
	"dark": ["#2c2624", "#463e3a", "#665c56", "#8c827a"],
	"pink": ["#9c5458", "#c67c80", "#eaa6a8", "#ffd0d0"],
	"eye": ["#a87a14", "#d8a828", "#f6d458", "#fff4b0"],
	"pupil": ["#08070a", "#100e12", "#1a171c", "#28242a"],
}


def build(k):
	import sidekick_solid

	parts = {"Body": ((0, 0.4, 1.4), None), "Head": ((0, -0.9, 2.3), "Body"), "Tail": ((0, 1.6, 1.8), "Body")}
	for n, x, y in (("FrontLeft", 0.46, -0.5), ("FrontRight", -0.46, -0.5), ("BackLeft", 0.5, 1.1), ("BackRight", -0.5, 1.1)):
		parts["Leg" + n] = ((x, y, 1.0), "Body")
	m = k.Model(ID, RAMPS, parts)
	sidekick_solid.solid_blocks(m)
	m.path("Body", "fur", [(0, 1.7, 1.5), (0, 0.9, 1.62), (0, 0, 1.6), (0, -0.8, 1.74)], [0.5, 0.78, 0.76, 0.62], [0.5, 0.72, 0.7, 0.6], n=8, jit=0.02)
	m.plate("Body", "dark", [(-0.66, 0.0, 2.1), (0.5, 0.0, 2.3), (0.7, 0.9, 2.2), (-0.1, 1.2, 2.36), (-0.7, 0.8, 2.1)], (0, 0, 0.06), a=0.5)
	h, y = "Head", -0.96
	m.block(h, "fur", 0, y, 3.5, 1.96, 1.1, 0.9, ch=0.24, mids=(2.6,), jit=0.018, a=0.56, b=0.34)
	for s in (1, -1):
		m.path(h, "dark" if s > 0 else "fur", [(s * 0.7, y + 0.1, 3.3), (s * 0.86, y + 0.1, 3.96)], [0.46, 0.01], [0.24, 0.01], n=4)
		m.plate(h, "pink", [(s * 0.52, y - 0.14, 3.46), (s * 0.92, y - 0.14, 3.46), (s * 0.82, y - 0.04, 3.8)], (0, 0.04, 0))
		ey = y - 0.92
		m.plate(h, "eye", [(s * 0.24, ey, 2.94), (s * 0.82, ey, 2.94), (s * 0.78, ey, 2.66), (s * 0.54, ey, 2.54), (s * 0.28, ey, 2.66)], (0, 0.04, 0), a=0.7, b=0.1)
		m.plate(h, "pupil", [(s * 0.47, ey - 0.03, 2.92), (s * 0.62, ey - 0.03, 2.92), (s * 0.6, ey - 0.03, 2.6), (s * 0.5, ey - 0.03, 2.6)], (0, 0.02, 0))
		m.plate(h, "dark" if s > 0 else "fur", [(s * 0.2, ey - 0.05, 3.06), (s * 0.88, ey - 0.05, 3.06), (s * 0.84, ey - 0.05, 2.86), (s * 0.26, ey - 0.05, 2.86)], (0, 0.06, 0), a=0.6)
		for dz in (0.0, -0.16):
			m.spike(h, "fur", (s * 0.6, ey + 0.1, 2.36 + dz), (s * 1.36, ey, 2.4 + dz * 1.6), 0.03, a=0.8)
	m.plate(h, "dark", [(0.1, y - 0.93, 3.24), (1.02, y - 0.9, 3.1), (0.96, y - 0.9, 2.5), (0.7, y - 0.93, 3.06)], (0, 0.03, 0))
	m.block(h, "fur", 0, y - 0.9, 2.5, 2.12, 0.42, 0.14, ch=0.08, a=0.64)
	m.plate(h, "pink", [(-0.13, y - 1.06, 2.52), (0.13, y - 1.06, 2.52), (0, y - 1.06, 2.36)], (0, 0.05, 0))
	for s in (1, -1):
		m.plate(h, "pupil", [(0, y - 1.06, 2.34), (s * 0.22, y - 1.06, 2.22), (s * 0.2, y - 1.06, 2.18), (0, y - 1.06, 2.29)], (0, 0.02, 0))
	pts = [(0, 1.6, 1.7), (0.2, 2.1, 1.9), (0.3, 2.4, 2.5), (0.16, 2.3, 3.1)]
	m.path("Tail", "fur", pts, [0.2, 0.2, 0.19, 0.1], [0.2, 0.2, 0.19, 0.1], n=6)
	m.path("Tail", "dark", [(0.28, 2.38, 2.5), (0.16, 2.3, 3.14)], [0.21, 0.08], [0.21, 0.08], n=6)
	for n, x, yy in (("FrontLeft", 0.46, -0.5), ("FrontRight", -0.46, -0.5), ("BackLeft", 0.5, 1.1), ("BackRight", -0.5, 1.1)):
		m.block("Leg" + n, "fur", x, yy, 1.4, 0.0, 0.26, 0.28, ch=0.06)
		m.block("Leg" + n, "fur", x, yy - 0.12, 0.28, 0.0, 0.3, 0.4, ch=0.08, a=0.6)
	return m
