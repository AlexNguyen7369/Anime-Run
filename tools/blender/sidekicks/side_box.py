# Sidekick side_box, Mimik: a red treasure chest that bites. Walks (hops). Lid swings on the back hinge, Tongue is its own part.
# Hard facets, soft paint, in-house only. Evidence: docs/char_evidence/side_box.md. Front faces -Y.
ID = "side_box"
NAME = "Mimik"

RAMPS = {
	"wood": ["#5c0e14", "#971a20", "#c62a2a", "#ea5246"],
	"band": ["#3e2412", "#684022", "#8f5c32", "#bb8450"],
	"chip": ["#1c0d0a", "#2c1610", "#40221a", "#583226"],
	"mouth": ["#0c0508", "#1a0a10", "#2a1018", "#3e1a24"],
	"gum": ["#4a1424", "#742034", "#9c3248", "#c05064"],
	"tongue": ["#8a2a48", "#c04a6a", "#e2748e", "#f8a4b4"],
	"tooth": ["#b8ae96", "#dcd4be", "#f6f0e0", "#ffffff"],
	"iron": ["#2a241e", "#4c4236", "#786a54", "#b0a080"],
}
W, D, H = 1.9, 1.25, 1.95  # half width, half depth, height of the base
HINGE = (0, D, H)
OPEN = -38


def chips(m, part, spots, y):
	"""Worn patches: jagged dark flakes on the front face."""
	for x, z, r in spots:
		pts = [(x + dx * r, y, z + dz * r) for dx, dz in ((-1, 0.1), (-0.4, 0.6), (0.3, 0.45), (1.0, 0.7), (0.7, -0.2), (0.1, -0.7), (-0.5, -0.35))]
		m.plate(part, "chip", pts, (0, 0.05, 0), a=0.5, b=0.05)


def tooth(m, part, x, y, z, dx, dy, dz, r):
	m.path(part, "tooth", [(x, y, z - 0.12 * (1 if dz > 0 else -1)), (x + dx * 0.55, y + dy * 0.55, z + dz * 0.55), (x + dx, y + dy, z + dz)], [r, r * 0.7, 0.012], [r * 0.6, r * 0.45, 0.012], n=6, a=0.68, b=0.28, g=0.1 if dz > 0 else -0.1)


def base(m):
	b = "Base"
	m.block(b, "wood", 0, 0, H - 0.22, 0.0, W, D, ch=0.07, a=0.54, b=0.34, g=0.22, tone=0.015)
	# the rim round the mouth, and the dark throat inside it
	for x, y, hw, hd in ((0, -D + 0.12, W + 0.02, 0.16), (0, D - 0.12, W + 0.02, 0.16), (W - 0.12, 0, 0.16, D), (-W + 0.12, 0, 0.16, D)):
		m.block(b, "band", x, y, H, H - 0.32, hw, hd, ch=0.05, a=0.56, b=0.34)
	m.block(b, "mouth", 0, 0, H - 0.12, H - 0.3, W - 0.2, D - 0.2, ch=0.02, a=0.4, b=0.1)
	for x in (-W + 0.11, -0.66, 0.66, W - 0.11):
		for y in (-D, D):
			m.block(b, "band", x, y, H - 0.2, 0.0, 0.13, 0.07, ch=0.03, a=0.54, b=0.34, g=0.2)
	for s in (1, -1):
		for y in (-D + 0.11, 0.0, D - 0.11):
			m.block(b, "band", s * W, y, H - 0.2, 0.0, 0.07, 0.13, ch=0.03, a=0.54, b=0.34, g=0.2)
		m.block(b, "band", s * W, 0, 0.17, -0.02, 0.1, D + 0.06, ch=0.03, a=0.5, b=0.34)
		m.block(b, "band", 0, s * D, 0.17, -0.02, W + 0.06, 0.1, ch=0.03, a=0.5, b=0.34)
		# iron ring handle on each end
		m.ring(b, "iron", (s * (W + 0.18), -0.02, 1.12), (1, 0, 0.25), 0.3, 0.06, n=10, a=0.55, b=0.4)
	# the broken lock plate
	m.block(b, "iron", 0, -D - 0.06, 1.42, 0.78, 0.32, 0.1, ch=0.06, a=0.56, b=0.38)
	m.block(b, "chip", 0, -D - 0.16, 1.24, 0.94, 0.08, 0.04, ch=0.02, a=0.2, b=0.05)
	chips(m, b, ((-1.25, 0.5, 0.2), (1.2, 1.3, 0.24), (0.98, 0.36, 0.14), (-1.0, 1.36, 0.16)), -D - 0.01)
	chips(m, b, ((-1.2, 1.1, 0.24), (1.1, 0.6, 0.22), (0.1, 1.2, 0.18)), D + 0.01)
	n = 7
	for i in range(n):
		x = -W + 0.24 + i * (2 * W - 0.48) / (n - 1)
		if i == 2:
			continue  # the tongue lolls here
		tooth(m, b, x, -D + 0.12, H, 0.0, -0.16, 0.62 if i % 2 == 0 else 0.46, 0.2)
	for s in (1, -1):
		for y, h in ((-0.6, 0.44), (-0.05, 0.56), (0.5, 0.36)):
			tooth(m, b, s * (W - 0.12), y, H, s * 0.14, 0, h, 0.19)


def lid(m, k):
	"""Built shut, then every point turned about the hinge, so the paint follows the open pose."""
	l, M = "Lid", k.math
	t = M.radians(OPEN)
	raw = m.add

	def turn(p):
		y, z = p[1] - HINGE[1], p[2] - HINGE[2]
		return (p[0], HINGE[1] + y * M.cos(t) - z * M.sin(t), HINGE[2] + y * M.sin(t) + z * M.cos(t))

	m.add = lambda part, ramp, verts, faces, **kw: raw(part, ramp, [turn(p) for p in verts], faces, **kw)

	def barrel(ramp, x0, x1, grow, z0=H + 0.04, **kw):
		prof = [(-D - grow, z0)] + [(-(D + grow) * M.cos(M.pi * i / 8), z0 + 0.4 + (0.95 + grow) * M.sin(M.pi * i / 8)) for i in range(9)] + [(D + grow, z0)]
		m.add(l, ramp, *m._loft([[(x0, y, z) for y, z in prof], [(x1, y, z) for y, z in prof]]), **kw)

	barrel("wood", -W, W, 0.0, a=0.54, b=0.34, g=0.2, tone=0.02)
	for x0, x1 in ((-W - 0.05, -W + 0.18), (-0.78, -0.54), (0.54, 0.78), (W - 0.18, W + 0.05)):
		barrel("band", x0, x1, 0.08, a=0.54, b=0.36, g=0.2, tone=0.015)
	for s in (1, -1):
		m.block(l, "band", 0, s * (D - 0.04), H + 0.28, H, W + 0.06, 0.16, ch=0.05, a=0.56, b=0.34)
	# the red end panels inside their brown edge
	for s in (1, -1):
		end = [(0, -(D - 0.16) * M.cos(M.pi * i / 8), H + 0.44 + 0.78 * M.sin(M.pi * i / 8)) for i in range(9)]
		end = [(s * (W + 0.05), y, z) for _, y, z in [(0, -D + 0.16, H + 0.3)] + end + [(0, D - 0.16, H + 0.3)]]
		m.plate(l, "wood", end, (0.08, 0, 0), a=0.5, b=0.2)
	m.block(l, "mouth", 0, 0, H + 0.1, H - 0.06, W - 0.16, D - 0.16, ch=0.02, a=0.45, b=0.12)
	m.block(l, "gum", 0, -D + 0.2, H + 0.05, H - 0.1, W - 0.1, 0.1, ch=0.03, a=0.5, b=0.25)
	# a ribbed palate
	for y in (-0.45, 0.0, 0.45):
		m.block(l, "gum", 0, y, H, H - 0.12, W - 0.4, 0.08, ch=0.03, a=0.42, b=0.25)
	m.block(l, "iron", 0, -D - 0.1, H + 0.5, H - 0.02, 0.26, 0.1, ch=0.05, a=0.56, b=0.38)
	n = 9
	for i in range(n):
		x = -W + 0.22 + i * (2 * W - 0.44) / (n - 1)
		tooth(m, l, x, -D + 0.08, H + 0.02, 0.0, -0.1, -0.6 if i % 2 == 0 else -0.46, 0.18)
	for s in (1, -1):
		for y, h in ((-0.65, -0.5), (-0.1, -0.4), (0.4, -0.28)):
			tooth(m, l, s * (W - 0.12), y, H + 0.02, s * 0.1, 0, h, 0.18)
	# worn patches on the curve and the ends
	for x, i, r in ((-1.2, 1.6, 0.22), (1.15, 2.4, 0.26), (0.0, 1.3, 0.2), (-1.1, 5.0, 0.24), (1.2, 6.2, 0.22), (0.05, 3.4, 0.22)):
		a = M.pi * i / 8
		c = k.Vector((x, -(D + 0.01) * M.cos(a), H + 0.44 + 0.96 * M.sin(a)))
		n_ = k.Vector((0, -M.cos(a) / D, M.sin(a) / 0.95)).normalized()
		u = k.Vector((0, n_.z, -n_.y))
		pts = [c + k.Vector((dx * r, 0, 0)) + u * dz * r * 0.8 for dx, dz in ((-1, 0.1), (-0.4, 0.6), (0.3, 0.45), (1.0, 0.7), (0.7, -0.2), (0.1, -0.7), (-0.5, -0.35))]
		m.plate(l, "chip", pts, n_ * 0.12, a=0.5, b=0.05)
	m.add = raw


def tongue(m):
	t = "Tongue"
	m.path(t, "tongue", [(-0.66, 0.5, H - 0.02), (-0.66, -0.5, H + 0.12), (-0.66, -1.3, H + 0.16), (-0.60, -1.72, H - 0.2), (-0.52, -1.78, H - 0.75), (-0.46, -1.7, H - 1.16)], [0.4, 0.52, 0.54, 0.52, 0.42, 0.14], [0.1, 0.14, 0.14, 0.14, 0.12, 0.05], n=8, a=0.56, b=0.34, g=0.1)
	m.path(t, "gum", [(-0.66, -0.6, H + 0.26), (-0.66, -1.36, H + 0.31), (-0.60, -1.87, H - 0.16), (-0.52, -1.92, H - 0.72)], [0.06, 0.07, 0.07, 0.02], 0.03, n=4, a=0.55, b=0.1)


def build(k):
	from sidekick_solid import solid_blocks

	m = solid_blocks(k.Model(ID, RAMPS, {"Base": ((0, 0, 0.8), None), "Lid": (HINGE, "Base"), "Tongue": ((-0.6, 0.4, H), "Base")}))
	base(m)
	lid(m, k)
	tongue(m)
	return m
