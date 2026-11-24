# Sidekick side_bird, Stilla: a small plump orange bird of iron, very fast. Flies; WingLeft and WingRight flap at the shoulder.
# Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_bird.md.
# Front faces -Y; +X is the viewer's right in the front view, the bird's own left.
ID = "side_bird"
NAME = "Stilla"

RAMPS = {
	"orange": ["#8e4418", "#c4692a", "#e28a40", "#f8b46c"],
	"deep": ["#6a3010", "#984c1c", "#bc6a2e", "#dc9050"],
	"breast": ["#a85a24", "#d88238", "#f0a458", "#ffcc88"],
	"beak": ["#1c1b18", "#33312b", "#4c4840", "#777060"],
	"ring": ["#7a6a34", "#a08c4a", "#c4ae66", "#e0cc88"],
	"pupil": ["#060606", "#0e0d0c", "#181614", "#24211e"],
	"glint": ["#e8e8e8", "#f4f4f4", "#ffffff", "#ffffff"],
	"leg": ["#24201a", "#3e382e", "#5a5244", "#7e745e"],
}
HC, HR = (0, -0.95, 3.45), (0.92, 0.94, 0.9)
SH = (0.78, 0.0, 2.75)


def feather(k, m, part, ramp, root, tip, wide, up=(0, 1, 0), th=0.09, **kw):
	V = k.Vector
	root, tip = V(root), V(tip)
	along = tip - root
	across = along.cross(V(up)).normalized() * wide
	m.plate(part, ramp, [root - across * 0.6, root + across * 0.6, root.lerp(tip, 0.72) + across, tip + across * 0.25, tip - across * 0.25, root.lerp(tip, 0.72) - across], along.cross(across).normalized() * th, **kw)


def wing(k, m, s, part):
	"""Short and broad, swept up and back: five primaries, three secondaries, two rows of round coverts."""
	V = k.Vector
	sh, wrist = V((s * SH[0], SH[1], SH[2])), V((s * 1.85, 0.2, 3.5))
	m.path(part, "orange", [sh, V((s * 1.3, 0.05, 3.2)), wrist], [0.34, 0.32, 0.2], [0.3, 0.26, 0.16], n=8, a=0.56, b=0.34, g=0.0)
	for i, (x, z) in enumerate(((3.1, 4.75), (3.42, 4.2), (3.42, 3.6), (3.2, 3.02), (2.85, 2.52))):
		feather(k, m, part, "deep" if i % 2 else "orange", wrist + V((0, 0.05 + 0.05 * i, 0)), (s * x, 0.95 - 0.03 * i, z), 0.27, a=0.52, b=0.26, g=0.16)
	for i, (x, z) in enumerate(((2.35, 2.15), (1.8, 1.95), (1.3, 1.9))):
		feather(k, m, part, "deep" if i % 2 == 0 else "orange", wrist.lerp(sh, 0.2 + 0.3 * i) + V((0, 0.12, 0)), (s * x, 0.8, z), 0.3, a=0.52, b=0.26, g=0.16)
	for i in range(5):
		r = wrist.lerp(sh, i / 4)
		feather(k, m, part, "orange", r + V((0, -0.1, 0.05)), r + V((s * (0.6 - 0.15 * i), 0.1, -0.85)), 0.26, a=0.58, b=0.28, g=0.2)
		if i < 4:
			feather(k, m, part, "breast", r + V((s * -0.1, -0.2, 0.12)), r + V((s * (0.25 - 0.08 * i), -0.1, -0.42)), 0.22, a=0.54, b=0.28, g=0.16)


def leg(k, m, s, part):
	V = k.Vector
	x = s * 0.34
	hip, foot = V((x, 0.2, 1.75)), V((x, 0.05, 0.85))
	m.path(part, "deep", [hip, hip + V((0, 0, -0.4))], [0.26, 0.15], n=8, a=0.54, b=0.3)
	m.path(part, "leg", [hip + V((0, 0, -0.3)), hip + V((0, 0.1, -0.6)), foot], [0.11, 0.1, 0.11], n=6, a=0.54, b=0.34)
	for i in (-1, 0, 1):
		m.path(part, "leg", [foot, foot + V((i * 0.2, -0.28, 0.0)), foot + V((i * 0.28, -0.5, -0.22))], [0.1, 0.09, 0.01], n=6, a=0.56, b=0.34)
	m.path(part, "leg", [foot, foot + V((0, 0.26, -0.02)), foot + V((0, 0.4, -0.2))], [0.1, 0.08, 0.01], n=6, a=0.54, b=0.34)


def build(k):
	V = k.Vector
	parts = {
		"Body": ((0, 0.1, 2.3), None),
		"Head": ((0, -0.6, 2.95), "Body"),
		"WingLeft": (SH, "Body"),
		"WingRight": ((-SH[0], SH[1], SH[2]), "Body"),
		"Tail": ((0, 1.1, 1.85), "Body"),
		"LegLeft": ((0.34, 0.2, 1.75), "Body"),
		"LegRight": ((-0.34, 0.2, 1.75), "Body"),
	}
	m = k.Model(ID, RAMPS, parts, a=0.54, b=0.36)
	b, h = "Body", "Head"
	# plump: a fat breast drawn back to a short rump
	m.path(b, "orange", [(0, 1.35, 1.8), (0, 0.75, 1.98), (0, 0.0, 2.2), (0, -0.55, 2.6), (0, -0.82, 3.1), (0, -0.92, 3.6)], [0.3, 0.72, 1.02, 1.08, 1.0, 0.7], [0.26, 0.7, 0.98, 0.94, 0.9, 0.6], n=8, g=0.2, jit=0.012)
	# breast feathers in short hard points
	for z, y, rx, n in ((2.98, -1.72, 0.42, 3), (2.64, -1.6, 0.54, 4), (2.3, -1.38, 0.42, 3)):
		for i in range(n):
			x = (i - (n - 1) / 2) / ((n - 1) / 2) * rx
			m.spike(b, "breast", (x, y + abs(x) * 0.3, z + 0.1), (x * 1.1, y - 0.02 + abs(x) * 0.3, z - 0.36), 0.2, flat=0.45, a=0.56, b=0.34)
	m.ell(h, "orange", HC, HR, rows=7, n=12, g=0.12)
	# the crest: three points blown back off the nape of the crown
	for x, y, z, tx, ty, tz, r in ((0, -0.5, 4.2, 0, 0.62, 0.36, 0.24), (0.2, -0.4, 4.08, 0.12, 0.62, 0.06, 0.2), (-0.2, -0.4, 4.08, -0.12, 0.62, 0.06, 0.2), (0, -0.25, 3.95, 0, 0.6, -0.18, 0.2)):
		m.spike(h, "orange", (x, y, z), (x + tx, y + ty, z + tz), r, flat=0.7, a=0.56, b=0.36)
	# the long sharp dark beak
	m.path(h, "beak", [(0, -1.7, 3.5), (0, -2.1, 3.47), (0, -2.6, 3.4), (0, -3.1, 3.3)], [0.3, 0.23, 0.13, 0.01], [0.19, 0.13, 0.07, 0.01], n=6, a=0.58, b=0.36, g=0.04)
	m.path(h, "beak", [(0, -1.68, 3.28), (0, -2.2, 3.26), (0, -2.85, 3.24)], [0.24, 0.17, 0.01], [0.1, 0.08, 0.01], n=6, a=0.36, b=0.28, g=0.0)
	for s in (1, -1):
		d = V((s * 0.74, -0.64, 0.2)).normalized()
		p = V((HC[0] + HR[0] * d.x, HC[1] + HR[1] * d.y, HC[2] + HR[2] * d.z))
		n = V((d.x / HR[0], d.y / HR[1], d.z / HR[2])).normalized()
		m.disc(h, "ring", p + n * 0.01, n, 0.27, th=0.06, n=10, a=0.62, b=0.0, g=0.0, tone=0.0)
		m.disc(h, "pupil", p + n * 0.05, n, 0.165, th=0.04, n=10, a=0.5, b=0.0, g=0.0, tone=0.0)
		m.disc(h, "glint", p + n * 0.08 + V((0, -0.04, 0.07)), n, 0.05, th=0.03, n=6, a=0.9, b=0.0, g=0.0, tone=0.0)
		m.path(h, "deep", [p + n * 0.04 + V((s * -0.16, -0.22, 0.2)), p + n * 0.1 + V((0, 0, 0.25)), p + n * 0.04 + V((s * 0.1, 0.3, 0.2))], [0.06, 0.09, 0.03], 0.06, n=6, a=0.5, b=0.3)
	for x, y, z, w in ((0.0, 3.0, 1.45, 0.28), (0.3, 2.8, 1.48, 0.25), (-0.3, 2.8, 1.48, 0.25)):
		feather(k, m, "Tail", "deep" if x else "orange", (x * 0.5, 1.1, 1.86), (x * 1.4, y, z), w, up=(0, 0, 1), th=0.12, a=0.54, b=0.34, g=0.1)
	for s, n in ((1, "Left"), (-1, "Right")):
		wing(k, m, s, "Wing" + n)
		leg(k, m, s, "Leg" + n)
	return m
