# Sidekick side_crow, Kasugay: a small sharp messenger crow that flies. WingLeft and WingRight are separate parts with their
# origin at the shoulder, to flap. Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_crow.md.
# Front faces -Y; +X is the viewer's right in the front view, the bird's own left.
ID = "side_crow"
NAME = "Kasugay"

RAMPS = {
	"black": ["#07080e", "#12141e", "#232838", "#3e475e"],
	"sheen": ["#0e1019", "#1a1f2e", "#2b3347", "#434e6a"],
	"beak": ["#2b303a", "#4f5664", "#7a8392", "#aab3c0"],
	"gum": ["#0a0a0f", "#15151c", "#22222c", "#30303c"],
	"iris": ["#8c88a0", "#b0acc4", "#d4d0e2", "#f2f0fa"],
	"pupil": ["#050508", "#0c0c12", "#15151e", "#20202a"],
	"talon": ["#1a1c22", "#30333c", "#4b4f5a", "#6c717e"],
}
HEAD_C, HEAD_R = (0, -0.95, 3.58), (0.74, 0.8, 0.72)
SHOULDER = (0.62, 0.05, 2.95)


def spot(k, m, part, ramp, c, r, d, rad, squash=1.0, lift=0.03, th=0.03, n=12, a=0.6, b=0.0):
	d = k.Vector(d).normalized()
	p = k.Vector((c[0] + r[0] * d.x, c[1] + r[1] * d.y, c[2] + r[2] * d.z))
	nrm = k.Vector((d.x / r[0], d.y / r[1], d.z / r[2])).normalized()
	m.disc(part, ramp, p + nrm * lift, nrm, rad, th=th, n=n, squash=squash, a=a, b=b, g=0.0, tone=0.0)


def feather(k, m, part, ramp, root, tip, wide, y_off=0.035, **kw):
	"""One flat pointed feather from root to tip, its broad face to the front."""
	V = k.Vector
	root, tip = V(root), V(tip)
	along = tip - root
	across = along.cross(V((0, 1, 0))).normalized() * wide
	pts = [root - across * 0.55, root + across * 0.55, root.lerp(tip, 0.72) + across, tip, root.lerp(tip, 0.72) - across * 0.7]
	m.plate(part, ramp, pts, (0, y_off, 0), **kw)


def wing(k, m, s, part):
	"""A half-spread wing: arm, wrist, long primaries splayed at the tip, secondaries, and two rows of short coverts."""
	V = k.Vector
	sh = V((s * SHOULDER[0], SHOULDER[1], SHOULDER[2]))
	elbow, wrist = V((s * 1.35, 0.22, 3.72)), V((s * 2.25, 0.42, 3.95))
	m.path(part, "black", [sh, elbow], [0.28, 0.22], [0.3, 0.24], n=8, a=0.5, b=0.36, g=0.0)
	m.path(part, "black", [elbow, wrist], [0.22, 0.14], [0.24, 0.15], n=8, a=0.5, b=0.36, g=0.0)
	primaries = [((3.95, 0.8, 4.3), 0.15), ((4.2, 0.85, 3.72), 0.16), ((4.1, 0.88, 3.12), 0.17), ((3.8, 0.88, 2.56), 0.18), ((3.35, 0.85, 2.1), 0.19)]
	for tip, wide in primaries:
		m_tip = V((s * tip[0], tip[1], tip[2]))
		feather(k, m, part, "black", wrist + V((0, 0.03, 0)), m_tip, wide, a=0.5, b=0.22, g=0.14)
	secondaries = [(2.85, 1.85), (2.3, 1.72), (1.75, 1.72), (1.25, 1.85)]
	for i, (x, z) in enumerate(secondaries):
		root = elbow.lerp(wrist, 1.0 - i / 3.0) if i < 3 else elbow.lerp(sh, 0.5)
		feather(k, m, part, "black", root + V((0, 0.06, -0.05)), (s * x, 0.72 - 0.05 * i, z), 0.26, a=0.5, b=0.22, g=0.14)
	for i in range(5):
		t = i / 4
		root = sh.lerp(elbow, min(1, t * 2)) if t <= 0.5 else elbow.lerp(wrist, (t - 0.5) * 2)
		feather(k, m, part, "sheen", root + V((0, -0.08, -0.04)), root + V((s * 0.2, 0.0, -0.95)), 0.24, a=0.4, b=0.26, g=0.16)
		root2 = root + V((s * 0.1, -0.13, 0.03))
		feather(k, m, part, "black", root2, root2 + V((s * 0.1, 0.0, -0.5)), 0.2, a=0.52, b=0.3, g=0.12)


def leg(k, m, s, part):
	V = k.Vector
	x = s * 0.3
	hip, ankle, foot = V((x, 0.45, 1.75)), V((x, 0.55, 1.15)), V((x, 0.42, 0.95))
	m.path(part, "black", [hip, hip.lerp(ankle, 0.4)], [0.2, 0.13], n=8, a=0.5, b=0.3, g=0.0)
	m.path(part, "talon", [hip.lerp(ankle, 0.3), ankle, foot], [0.075, 0.06, 0.07], n=6, a=0.5, b=0.34, g=0.0)
	for i in (-1, 0, 1):
		m.spike(part, "talon", foot, foot + V((i * 0.22, -0.34, -0.2)), 0.07, a=0.55, b=0.34)
	m.spike(part, "talon", foot, foot + V((0, 0.3, -0.18)), 0.06, a=0.55, b=0.34)


def build(k):
	V = k.Vector
	parts = {
		"Body": ((0, 0.2, 2.45), None),
		"Head": ((0, -0.75, 3.1), "Body"),
		"WingLeft": (SHOULDER, "Body"),
		"WingRight": ((-SHOULDER[0], SHOULDER[1], SHOULDER[2]), "Body"),
		"Tail": ((0, 1.05, 1.8), "Body"),
		"LegLeft": ((0.3, 0.45, 1.75), "Body"),
		"LegRight": ((-0.3, 0.45, 1.75), "Body"),
	}
	m = k.Model(ID, RAMPS, parts, a=0.46, b=0.36)
	b = "Body"
	# the body, upright for hovering: full chest, hips drawn back
	m.path(b, "black", [(0, 1.15, 1.72), (0, 0.55, 2.02), (0, -0.05, 2.45), (0, -0.48, 2.98), (0, -0.74, 3.28)], [0.34, 0.68, 0.84, 0.78, 0.58], [0.3, 0.7, 0.86, 0.72, 0.56], n=8, g=0.16, jit=0.01)
	# shaggy throat and chest feathers, hard points
	for row, (z, y, rx, count) in enumerate(((3.1, -1.05, 0.62, 5), (2.75, -0.95, 0.72, 5), (2.38, -0.84, 0.66, 4))):
		for i in range(count):
			x = (i - (count - 1) / 2) / max(1, (count - 1) / 2) * rx
			base = V((x, y + abs(x) * 0.45, z + 0.14))
			m.spike(b, "black", base, base + V((x * 0.1, -0.18, -0.5)), 0.17, flat=0.45, n=6, a=0.46, b=0.34)
	h = "Head"
	m.ell(h, "black", HEAD_C, HEAD_R, rows=6, n=10, g=0.1, jit=0.012)
	# flat crown and shaggy nape
	for x, y, z, tx, ty, tz in ((0, -0.8, 4.12, 0.0, -0.05, 0.32), (0.26, -0.68, 4.08, 0.1, 0.16, 0.26), (-0.26, -0.68, 4.08, -0.1, 0.16, 0.26), (0.0, -0.32, 3.96, 0.0, 0.34, 0.14), (0.38, -0.34, 3.76, 0.1, 0.34, 0.02), (-0.38, -0.34, 3.76, -0.1, 0.34, 0.02), (0.0, -0.16, 3.48, 0.0, 0.38, -0.1)):
		base = V((x, y, z))
		m.spike(h, "black", base, base + V((tx, ty, tz)), 0.16, flat=0.55, n=6, a=0.46, b=0.36)
	# the heavy sharp beak: a high ridged upper, a shorter lower, a dark line between
	m.path(h, "beak", [(0, -1.55, 3.58), (0, -1.95, 3.52), (0, -2.35, 3.34), (0, -2.62, 3.14)], [0.3, 0.26, 0.15, 0.012], [0.2, 0.19, 0.12, 0.012], n=6, a=0.52, b=0.34, g=0.04, tone=0.01)
	m.path(h, "beak", [(0, -1.55, 3.27), (0, -1.95, 3.25), (0, -2.32, 3.18)], [0.24, 0.17, 0.012], [0.09, 0.075, 0.012], n=6, a=0.38, b=0.26, g=0.0, tone=0.01)
	m.path(h, "gum", [(0, -1.55, 3.39), (0, -1.98, 3.33), (0, -2.4, 3.21)], [0.25, 0.17, 0.02], 0.025, n=4, a=0.5, b=0.0, g=0.0, tone=0.0)
	for s in (1, -1):
		d = (s * 0.62, -0.62, 0.28)
		spot(k, m, h, "pupil", HEAD_C, HEAD_R, d, 0.17, lift=0.04, a=0.5)
		spot(k, m, h, "iris", HEAD_C, HEAD_R, d, 0.125, lift=0.07, a=0.68)
		spot(k, m, h, "pupil", HEAD_C, HEAD_R, d, 0.065, lift=0.1, a=0.5)
		# the slanted brow gives the sharp look
		eye = V(HEAD_C) + V((HEAD_R[0] * s * 0.65, HEAD_R[1] * -0.65, HEAD_R[2] * 0.48))
		m.path(h, "black", [eye + V((s * -0.24, -0.12, -0.08)), eye + V((s * 0.02, 0.0, 0.04)), eye + V((s * 0.22, 0.2, 0.1))], [0.06, 0.09, 0.04], 0.05, n=6, a=0.56, b=0.42, g=0.0)
	# the wedge tail, fanned
	for x, y, z, w in ((0.0, 3.05, 0.86, 0.26), (0.26, 2.95, 0.92, 0.25), (-0.26, 2.95, 0.92, 0.25), (0.5, 2.72, 1.05, 0.23), (-0.5, 2.72, 1.05, 0.23)):
		root = V((x * 0.4, 1.0, 1.82))
		tip = V((x, y, z))
		along = tip - root
		across = along.cross(V((0, 0, 1))).normalized() * w
		pts = [root - across * 0.5, root + across * 0.5, root.lerp(tip, 0.82) + across, tip, root.lerp(tip, 0.82) - across]
		m.plate("Tail", "black", pts, along.cross(across).normalized() * 0.1, a=0.46, b=0.34, g=0.12)
	wing(k, m, 1, "WingLeft")
	wing(k, m, -1, "WingRight")
	leg(k, m, 1, "LegLeft")
	leg(k, m, -1, "LegRight")
	return m
