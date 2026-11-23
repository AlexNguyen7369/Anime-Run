"""World 2 Track 2: Demon King's Castle (Solo Levelup, enemy Barran). Rebuilt 2026-11-23 for a closer read of the
source (refs and landmark list: docs/world2_refs/DemonCastle.md):
- ChainTower (hero, infield): the castle itself, a 100-floor black tower bound by giant chains that droop to anchor
  blocks, fire and an abyss-glow moat at its foot, and the top floor as an open summit ringed by curved horn-spikes round
  a throne, with a pale pillar of light into the sky.
- Gate (hero, spans the road twice): the gatekeeper's gate, two spired gate towers, a pointed arch, open iron doors and a
  three-headed hound statue on the bridge.
- Wyvern: a pale wyvern with red eyes carrying a purple armoured rider with a blue blade, circling the tower top.
- RuinA / RuinB / Chunk: the burning ruined city inside the castle floors (window-grid high-rises and collapsed blocks in
  pink-purple fire) and burning chunks of rubble floating in the air.
- Rampart / Watchtower / Brazier / Crag / Fissure: black battlements, round towers, braziers, obsidian crags with strata
  and glowing fissures, under a purple-black sky with a crimson horizon.
No crests, symbols or text (design doc 5): banners carry only a plain changed shape. Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

import bpy
from mathutils import Matrix, Vector

STONE, STONE2, STONE3, SLATE = "2C2536", "3C3348", "1C1724", "4E4560"
EMBER, FLAME, LAVA = "FF4A1C", "FFB347", "FF6A20"
PINK, MAGENTA, ABYSS = "FF5AD2", "B83CFF", "7A1FBF"
IRON, IRON2, BONE = "2A2A30", "45454E", "D8DCE6"
DARK, WIN = "0E0A12", "16101C"
CLOTH, CLOTH2 = "4A1670", "2E0E46"
BLUE, RIDER, GOLD = "6AC8FF", "6A2E9A", "C8A040"
CONC, CONC2, CONC3 = "3A3440", "524A5C", "2A2430"


# --- local helpers (kit.py is shared, so they live here) ---
def _rotm(rx, ry, rz):
	"""kit.prop's rotation (degrees, Roblox axes) as a Blender-space matrix."""
	return Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(-rz), 3, "Y")


def _turn(m, off):
	"""Roblox offset `off` turned by Blender matrix `m`, back in Roblox axes."""
	v = m @ Vector((off[0], -off[2], off[1]))
	return (v.x, v.z, -v.y)


def _link(parts, c, d, roll, L=12.0, W=7.0, t=2.2, col=IRON):
	"""One chain link (four bars) centred at c, long axis along unit vector d (Roblox), rolled `roll` degrees."""
	rx = -math.degrees(math.asin(max(-1.0, min(1.0, d[1]))))
	ry = math.degrees(math.atan2(d[0], d[2]))
	rot = (rx, ry, roll)
	m = _rotm(*rot)
	o = {"metal": 0.8, "rough": 0.45, "rot": rot}
	for size, off in (
		((t, t, L), (-W / 2 + t / 2, 0, 0)),
		((t, t, L), (W / 2 - t / 2, 0, 0)),
		((W, t, t), (0, 0, -L / 2 + t / 2)),
		((W, t, t), (0, 0, L / 2 - t / 2)),
	):
		q = _turn(m, off)
		parts.append(("box", size, (c[0] + q[0], c[1] + q[1], c[2] + q[2]), col, o))


def _chain(parts, a, b, sag, pitch=10.0, **kw):
	"""Links along a sagging curve from a to b (Roblox points), alternate links rolled 90 degrees."""
	pts = []
	n = 240
	for i in range(n + 1):
		t = i / n
		pts.append(Vector((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t)))
	acc, last, k = 0.0, pts[0], 0
	for p in pts[1:]:
		acc += (p - last).length
		if acc >= pitch:
			d = (p - last).normalized()
			_link(parts, (p.x, p.y, p.z), (d.x, d.y, d.z), 90 * (k % 2), **kw)
			k += 1
			acc = 0.0
		last = p


def _merlons(parts, w, depth, y, z, n, col, h=4.0):
	"""Merlons on every other of n slots along x across width w, at height y, on the line z."""
	step = w / n
	for i in range(0, n, 2):
		parts.append(("box", (step, h, depth), (-w / 2 + step * (i + 0.5), y + h / 2, z), col))


def _flame(parts, pos, s=1.0, hot=PINK, core="FFD0F4"):
	parts.append(("cone", (3 * s, 6 * s, 3 * s), (pos[0], pos[1] + 3 * s, pos[2]), hot, {"seg": 5, "emit": 7}))
	parts.append(("cone", (1.6 * s, 4 * s, 1.6 * s), (pos[0], pos[1] + 2.4 * s, pos[2]), core, {"seg": 5, "emit": 10}))


def _banner(parts, pos, h=22, w=7):
	"""A hanging cloth with a plain changed shape (three short spikes), no real emblem. Hangs on the -Z side of pos."""
	x, y, z = pos
	parts.append(("box", (w + 2, 0.8, 0.8), (x, y, z), IRON2, {"metal": 0.7}))
	parts.append(("box", (w, h, 0.5), (x, y - h / 2, z), CLOTH))
	parts.append(("cone", (w, 5, 0.5), (x, y - h - 2.4, z), CLOTH, {"seg": 4, "rot": (180, 45, 0)}))
	for dx, hh in ((-w * 0.25, h * 0.16), (0, h * 0.24), (w * 0.25, h * 0.16)):
		parts.append(("cone", (w * 0.2, hh, 0.3), (x + dx, y - h * 0.45, z - 0.35), GOLD, {"seg": 4, "emit": 0.6}))


def _fill(k, color):
	"""Stone under the raised road (the game's hill supports), so the stair climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			h = p.y - 0.5 + 1.0
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width - 1, step + 0.5, h)
		d += step


def _row(k, every, offsets, names, start=40.0, end=None, jitter=0.0, skip=(), scale=(1.0, 1.0), face_road=True):
	"""Props on the ground (y = -1) beside the road, -Z facing it, never near another stretch or inside `skip` spans."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			dd = d + k.rng.uniform(-jitter, jitter)
			if any(a <= dd <= b for a, b in skip):
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			(x, _, z), yaw = k.beside(dd, o)
			if not k.clear_of_road(x, z, abs(o) * 0.85):
				continue
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			k.place(k.rng.choice(names), (x, -1.0, z), yaw, k.rng.uniform(*scale))
		d += every


def _road_dist(k, x, z):
	step = max(1, len(k.wps) // 600)
	return min(math.hypot(w.x - x, w.z - z) for w in k.wps[::step])


# --- props ---
def _chain_tower(k):
	p = []
	# Stepped plinth with an abyss-glow moat and fire round its foot
	p.append(("cyl", (420, 1, 420), (0, 0.2, 0), ABYSS, {"seg": 24, "emit": 1.6}))
	p.append(("cyl", (360, 1.2, 360), (0, 0.4, 0), DARK, {"seg": 24}))
	for i, w in enumerate((250, 210, 170)):
		p.append(("box", (w, 10, w), (0, 5 + i * 10, 0), (SLATE, STONE2, STONE)[i]))
	for a in range(16):
		ang = a * math.tau / 16
		_flame(p, (math.cos(ang) * 150, 0, math.sin(ang) * 150), 3.2, LAVA, FLAME)
	# Shaft: four set-back sections with floor bands, window rows, corner buttresses with pinnacles, merlons
	y = 30.0
	attach = None
	for si, (w, h) in enumerate(((120, 150), (106, 140), (92, 130), (80, 110))):
		p.append(("box", (w, h, w), (0, y + h / 2, 0), (STONE, STONE2, STONE, STONE2)[si]))
		bands = int(h // 28)
		for b in range(bands + 1):
			by = y + b * h / bands
			p.append(("box", (w + 3, 2.4, w + 3), (0, by, 0), SLATE))
			if b == bands:
				continue
			wy = by + h / bands / 2
			for face in range(4):
				m = _rotm(0, face * 90, 0)
				for c in range(4):
					lit = (si + b + c + face) % 5 == 0
					col, o = (PINK, {"emit": 4}) if lit else (WIN, {})
					q = _turn(m, (-w * 0.33 + c * w * 0.22, wy, -w / 2 - 0.3))
					p.append(("box", (5, 13, 0.8), q, col, dict(o, rot=(0, face * 90, 0))))
		for sx in (-1, 1):
			for sz in (-1, 1):
				cx, cz = sx * (w / 2 + 2), sz * (w / 2 + 2)
				p.append(("box", (12, h, 12), (cx, y + h / 2, cz), STONE3))
				p.append(("cone", (13, 26, 13), (cx, y + h + 13, cz), SLATE, {"seg": 4, "rot": (0, 45, 0)}))
				p.append(("ball", (2.4, 2.4, 2.4), (cx, y + h + 27, cz), PINK, {"emit": 6, "subdiv": 1}))
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			for i in range(0, 7, 2):
				q = _turn(m, (-w / 2 + w / 7 * (i + 0.5), y + h + 3, -w / 2 + 2))
				p.append(("box", (w / 7, 6, 4), q, STONE2, {"rot": (0, face * 90, 0)}))
		if si == 2:
			attach = (y + h * 0.6, w / 2 + 2)
		y += h
	top = y
	# Summit (floor 100): open deck, a ring of curved horn-spikes round the throne, pillar of light
	p.append(("cyl", (96, 6, 96), (0, top + 3, 0), SLATE, {"seg": 16}))
	p.append(("cyl", (70, 2, 70), (0, top + 6.5, 0), ABYSS, {"seg": 16, "emit": 1.2}))
	for i in range(10):
		ang = i * math.tau / 10
		yaw = 90 - math.degrees(ang)
		p.append(("cone", (9, 40, 9), (math.cos(ang) * 40, top + 24, math.sin(ang) * 40), BONE, {"seg": 6, "rot": (-14, yaw, 0)}))
		p.append(("cone", (5, 30, 5), (math.cos(ang) * 46, top + 54, math.sin(ang) * 46), BONE, {"seg": 6, "rot": (22, yaw, 0)}))
	p.append(("box", (16, 6, 12), (0, top + 10, 0), STONE3))
	p.append(("box", (16, 26, 3), (0, top + 20, 5), STONE3))
	p.append(("cone", (5, 12, 2), (-6, top + 37, 5), BONE, {"seg": 4}))
	p.append(("cone", (5, 12, 2), (6, top + 37, 5), BONE, {"seg": 4}))
	p.append(("cyl", (16, 2600, 16), (0, top + 1306, 0), "E8D8FF", {"seg": 10, "emit": 6}))
	p.append(("cyl", (34, 2600, 34), (0, top + 1306, 0), "9A6AFF", {"seg": 10, "emit": 1.5, "alpha": 0.35}))
	# Giant chains from the third section's corners to anchor blocks on the ground
	ay, ar = attach
	for i in range(4):
		ang = math.radians(45 + 90 * i)
		a = (math.cos(ang) * ar * 1.414, ay, math.sin(ang) * ar * 1.414)
		b = (math.cos(ang) * 230, 30, math.sin(ang) * 230)
		_chain(p, a, b, 70, pitch=11.0, L=14, W=8, t=2.6)
		bx, bz = math.cos(ang) * 238, math.sin(ang) * 238
		yaw = -math.degrees(ang)
		p.append(("box", (30, 22, 30), (bx, 11, bz), SLATE, {"rot": (0, yaw, 0)}))
		p.append(("box", (22, 8, 22), (bx, 26, bz), STONE3, {"rot": (0, yaw, 0)}))
		p.append(("box", (40, 1.2, 40), (bx, 0.6, bz), EMBER, {"emit": 3, "rot": (0, yaw + 45, 0)}))
	k.prop("ChainTower", p)
	return top


def _gate(k):
	"""Spans the road: tower inner faces 30 studs from the centre line, arch underside 30+ above the road."""
	p = []
	for sx in (-1, 1):
		x = sx * 46
		p.append(("box", (36, 8, 36), (x, 4, 0), SLATE))
		p.append(("box", (32, 92, 32), (x, 50, 0), STONE))
		for by in (24, 48, 72):
			p.append(("box", (34, 2.4, 34), (x, by, 0), SLATE))
		for cz in (-1, 1):  # buttress fins on the outer side
			p.append(("box", (8, 70, 6), (x + sx * 16, 35, cz * 10), STONE3))
		p.append(("box", (38, 6, 38), (x, 99, 0), STONE2))  # machicolation ring
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			for i in range(0, 8, 2):
				q = _turn(m, (-19 + 38 / 8 * (i + 0.5), 105, -18))
				p.append(("box", (4.6, 6, 3), (x + q[0], q[1], q[2]), STONE2, {"rot": (0, face * 90, 0)}))
		p.append(("cone", (30, 64, 30), (x, 134, 0), STONE3, {"seg": 8}))
		p.append(("cyl", (1.4, 16, 1.4), (x, 172, 0), IRON2, {"seg": 6}))
		p.append(("ball", (3, 3, 3), (x, 180, 0), PINK, {"emit": 8, "subdiv": 1}))
		for wy in (34, 60, 84):  # lit pointed windows facing both ways along the road
			for wz in (-16.3, 16.3):
				p.append(("box", (5, 10, 0.8), (x, wy, wz), PINK, {"emit": 4}))
				p.append(("cone", (5, 4, 0.8), (x, wy + 7, wz), PINK, {"seg": 4, "emit": 4}))
		_banner(p, (x, 92, -16.6), 34, 10)
		_flame(p, (x - sx * 14, 108, -14), 1.4)
		# open door leaves against the inner faces
		p.append(("box", (2, 44, 26), (sx * 29, 22, -14), IRON, {"metal": 0.6, "rough": 0.5}))
		for dy in (8, 22, 36):
			p.append(("box", (2.6, 2, 26), (sx * 29, dy, -14), IRON2, {"metal": 0.8}))
	# Bridge over the road with a pointed arch beneath it
	p.append(("box", (60, 26, 30), (0, 72, 0), STONE2))
	p.append(("box", (64, 3, 32), (0, 86, 0), SLATE))
	_merlons(p, 60, 3, 87.5, -14.5, 9, STONE2, 5)
	_merlons(p, 60, 3, 87.5, 14.5, 9, STONE2, 5)
	prev = None
	for i in range(9):  # voussoirs from the springing (30 up at the tower face) to the pointed apex (59 up)
		t = i / 8
		pt = (30 * math.cos(t * math.pi / 2) ** 0.7, 30 + 29 * math.sin(t * math.pi / 2))
		if prev:
			mx, my = (pt[0] + prev[0]) / 2, (pt[1] + prev[1]) / 2
			ang = math.degrees(math.atan2(pt[1] - prev[1], pt[0] - prev[0]))
			ln = math.hypot(pt[0] - prev[0], pt[1] - prev[1]) + 1.5
			for sx in (-1, 1):
				p.append(("box", (ln, 5, 30), (sx * mx, my, 0), SLATE, {"rot": (0, 0, ang if sx > 0 else 180 - ang)}))
		prev = pt
	p.append(("box", (2, 30, 0.8), (0, 72, -15.3), ABYSS, {"emit": 3}))
	# Three-headed hound gatekeeper statue on the bridge
	hy = 89
	p.append(("ball", (22, 14, 30), (0, hy + 12, 2), STONE3, {"subdiv": 2}))
	for lx, lz in ((-8, -10), (8, -10), (-8, 12), (8, 12)):
		p.append(("box", (5, 12, 5), (lx, hy + 5, lz), STONE3))
	p.append(("cone", (5, 18, 5), (0, hy + 14, 20), STONE3, {"seg": 5, "rot": (-70, 0, 0)}))
	for hx, tilt in ((-9, -20), (0, 0), (9, 20)):
		p.append(("cyl", (6, 12, 6), (hx * 0.8, hy + 20, -10), STONE3, {"seg": 6, "rot": (25, 0, tilt)}))
		p.append(("box", (7, 6, 10), (hx, hy + 26, -16), STONE3, {"rot": (0, tilt * 0.6, 0)}))
		p.append(("box", (6, 2.4, 7), (hx, hy + 22, -18), STONE3, {"rot": (14, tilt * 0.6, 0)}))
		for ex in (-1.8, 1.8):
			p.append(("ball", (1.4, 1.4, 1.4), (hx + ex, hy + 27.5, -21), "FF2030", {"emit": 8, "subdiv": 1}))
			p.append(("cone", (1.6, 7, 1.6), (hx + ex * 1.4, hy + 31, -14), BONE, {"seg": 5, "rot": (-35, 0, ex * 12)}))
	k.prop("Gate", p)


def _wyvern(k):
	"""Pale wyvern, red eyes, swept horns; a purple armoured rider with a blue blade. Faces -Z."""
	p = [
		("ball", (12, 11, 34), (0, 0, 0), BONE, {"subdiv": 2, "smooth": True}),
		("cone", (7, 22, 7), (0, 6, -20), BONE, {"seg": 8, "taper": 0.6, "rot": (-55, 0, 0), "smooth": True}),
		("box", (6, 5, 12), (0, 12, -34), BONE),
		("box", (5, 2, 9), (0, 9, -36), BONE, {"rot": (12, 0, 0)}),
		("cone", (4, 26, 4), (0, -1, 28), BONE, {"seg": 6, "rot": (80, 0, 0)}),
		("cone", (6, 8, 1), (0, 0, 42), BONE, {"seg": 4, "rot": (80, 0, 0)}),
	]
	for sx in (-1, 1):
		p.append(("ball", (1.4, 1.4, 1.4), (sx * 2.4, 13.5, -38.5), "FF2030", {"emit": 9, "subdiv": 1}))
		p.append(("cone", (1.6, 14, 1.6), (sx * 3, 16, -27), BONE, {"seg": 5, "rot": (70, 0, sx * 15)}))
		p.append(("cone", (1.2, 9, 1.2), (sx * 5.5, 12, -28), BONE, {"seg": 5, "rot": (75, 0, sx * 40)}))
		# wing: arm bone, three finger spars, a dark membrane in two panels
		p.append(("box", (36, 2.4, 2.4), (sx * 22, 4, -4), BONE, {"rot": (0, sx * 10, sx * -12)}))
		for f, (fx, fz, fl) in enumerate(((40, 4, 30), (34, 12, 26), (24, 16, 20))):
			p.append(("box", (1.4, 1.4, fl), (sx * fx, 8 - f * 2, fz), BONE, {"rot": (0, sx * (-25 + f * 18), 0)}))
		p.append(("box", (34, 0.6, 20), (sx * 24, 5, 9), "3A3E58", {"rot": (0, 0, sx * -8)}))
		p.append(("cone", (24, 0.6, 18), (sx * 32, 5.6, 20), "3A3E58", {"seg": 3, "rot": (0, 0, sx * -8)}))
		p.append(("box", (3, 10, 3), (sx * 4, -7, 6), BONE, {"rot": (30, 0, 0)}))
	# rider: purple armour, gold plates, horns, blue blade
	p += [
		("box", (5, 8, 4), (0, 10, -2), RIDER),
		("box", (6.4, 2, 4.4), (0, 13.4, -2), GOLD, {"metal": 0.8, "rough": 0.3}),
		("ball", (3.4, 3.6, 3.4), (0, 16, -2.4), RIDER, {"subdiv": 1}),
		("cone", (0.8, 6, 0.8), (-1.6, 19.5, -2), BONE, {"seg": 4, "rot": (0, 0, -30)}),
		("cone", (0.8, 6, 0.8), (1.6, 19.5, -2), BONE, {"seg": 4, "rot": (0, 0, 30)}),
		("box", (1.6, 22, 0.6), (5.5, 18, -6), BLUE, {"emit": 8, "rot": (-30, 0, -20)}),
	]
	k.prop("Wyvern", p)


def _window_face(p, w, floors, fh, y0, cols, z, rot, lit_every=4, seed=0):
	"""A window grid on the face at local z (before turning by `rot` about Y); a few panes blown out, some on fire."""
	m = _rotm(0, rot, 0)
	for f in range(floors):
		for c in range(cols):
			n = (f * 7 + c * 3 + seed) % 11
			if n == 0:
				continue
			col, o = (EMBER, {"emit": 1.8}) if n % lit_every == 0 else (WIN, {})
			q = _turn(m, (-w / 2 + w / cols * (c + 0.5), y0 + f * fh + fh * 0.55, z))
			p.append(("box", (w / cols * 0.55, fh * 0.55, 0.6), q, col, dict(o, rot=(0, rot, 0))))


def _ruins(k):
	# RuinA: burning high-rise of the ruined city, a broken stepped top and floor slabs showing
	p = [("box", (40, 100, 30), (0, 50, 0), CONC), ("box", (44, 3, 34), (0, 1.5, 0), CONC3)]
	for f in range(1, 10):
		p.append(("box", (41, 1.2, 31), (0, f * 10, 0), CONC2))
	p += [
		("box", (18, 14, 30), (-11, 107, 0), CONC),
		("box", (12, 6, 22), (8, 103, 3), CONC, {"rot": (0, 0, 14)}),
		("box", (1.2, 18, 1.2), (4, 109, -6), IRON2, {"rot": (0, 0, 25)}),
		("box", (1.2, 14, 1.2), (-2, 116, 4), IRON2, {"rot": (0, 0, -18)}),
	]
	_window_face(p, 40, 9, 10, 0, 5, -15.1, 0, seed=1)
	_window_face(p, 30, 9, 10, 0, 4, -20.1, 90, seed=3)
	_window_face(p, 30, 9, 10, 0, 4, -20.1, -90, seed=5)
	for fx, fy, fz, s in ((-12, 114, -6, 2.6), (6, 106, -8, 2.0), (-14, 62, -16, 1.4)):
		_flame(p, (fx, fy, fz), s)
	k.prop("RuinA", p)
	# RuinB: collapsed low block, leaning slabs, broken columns, rubble and fire
	p = [
		("box", (46, 26, 30), (0, 13, 4), CONC),
		("box", (24, 12, 30), (-11, 32, 4), CONC),
		("box", (30, 2, 22), (12, 22, -14), CONC2, {"rot": (0, 10, 32)}),
		("box", (26, 2, 18), (-6, 8, -20), CONC2, {"rot": (-18, -8, 10)}),
	]
	for i, (cx, h) in enumerate(((-20, 18), (-8, 12), (6, 22), (18, 9))):
		p.append(("box", (3, h, 3), (cx, h / 2, -12), "5A5266", {"rot": (0, 0, (i - 1.5) * 6)}))
	for i in range(12):
		a = i * 2.4
		p.append(("box", (4 + i % 3 * 2, 2.5 + i % 2 * 2, 3 + i % 4), (math.cos(a) * (14 + i % 5 * 3), 1.2, -18 + math.sin(a) * 6), (CONC3, CONC, "4A4256")[i % 3], {"rot": (i * 9, i * 37, i * 13)}))
	_window_face(p, 46, 2, 10, 4, 6, -11.1, 0, seed=2)
	for fx, fy, fz, s in ((-10, 38, -2, 2.2), (14, 26, -10, 1.6)):
		_flame(p, (fx, fy, fz), s)
	k.prop("RuinB", p)
	# Chunk: a burning slab of rubble with a piece of building on it, floating
	p = [
		("cone", (36, 24, 30), (0, -12, 0), "3A2E34", {"seg": 7, "rot": (180, 0, 0)}),
		("cone", (20, 16, 18), (6, -20, 4), "2A2228", {"seg": 6, "rot": (180, 0, 0)}),
		("box", (34, 3, 28), (0, 0, 0), "4A3E44", {"rot": (0, 20, 0)}),
		("box", (16, 22, 12), (-4, 12, 2), CONC, {"rot": (0, 20, 6)}),
		("cyl", (24, 0.6, 20), (0, -6, 0), LAVA, {"seg": 7, "emit": 3}),
	]
	_window_face(p, 16, 2, 10, 1, 3, -6.2, 20, seed=4)
	_flame(p, (-6, 23, 0), 2.0)
	_flame(p, (8, 1.5, -6), 1.6, LAVA, FLAME)
	k.prop("Chunk", p)


def _castle_parts(k):
	# Rampart: black wall run, merlons, buttresses, lit pointed windows, a banner and torch sconces; -Z faces the road
	p = [
		("box", (44, 4, 12), (0, 2, 0), SLATE),
		("box", (40, 22, 8), (0, 13, 0), STONE),
		("box", (42, 2, 9), (0, 24.5, 0), SLATE),
		("box", (40.4, 1.4, 8.4), (0, 8, 0), STONE2),
	]
	_merlons(p, 40, 3, 25.5, -3, 11, STONE2, 4.5)
	_merlons(p, 40, 3, 25.5, 3, 11, STONE2, 4.5)
	for x in (-20, 0, 20):
		p.append(("box", (5, 20, 5), (x, 10, -5.5), STONE3))
		p.append(("cone", (5, 6, 5), (x, 23, -5.5), STONE3, {"seg": 4, "rot": (0, 45, 0)}))
	for x in (-10, 10):
		p.append(("box", (3, 7, 0.6), (x, 13, -4.3), PINK, {"emit": 3.5}))
		p.append(("cone", (3, 3, 0.6), (x, 18, -4.3), PINK, {"seg": 4, "emit": 3.5}))
		p.append(("box", (4.6, 1, 1.4), (x, 9.5, -4.6), SLATE))
	_banner(p, (0, 23, -5.4), 13, 5)
	for x in (-15, 15):
		p.append(("box", (1, 3, 2), (x, 17, -5), IRON2))
		_flame(p, (x, 18.5, -6), 0.6, LAVA, FLAME)
	k.prop("Rampart", p)
	# Watchtower: round, tapered foot, corbel ring, crenellated parapet, cone spire, arched windows, a banner
	h = 54
	p = [
		("cyl", (22, 10, 22), (0, 5, 0), SLATE, {"seg": 12, "taper": 0.82}),
		("cyl", (17, h, 17), (0, h / 2, 0), STONE2, {"seg": 12}),
		("cyl", (17.6, 1.6, 17.6), (0, 20, 0), SLATE, {"seg": 12}),
		("cyl", (17.6, 1.6, 17.6), (0, 38, 0), SLATE, {"seg": 12}),
		("cyl", (22, 5, 22), (0, h + 2.5, 0), STONE, {"seg": 12}),
		("cone", (18, 40, 18), (0, h + 26, 0), STONE3, {"seg": 12}),
		("cyl", (0.8, 10, 0.8), (0, h + 50, 0), IRON2, {"seg": 5}),
		("ball", (1.8, 1.8, 1.8), (0, h + 55, 0), PINK, {"emit": 7, "subdiv": 1}),
	]
	for i in range(12):
		a = i * math.tau / 12
		p.append(("box", (2.4, 3, 3), (math.sin(a) * 9.6, h - 1.5, -math.cos(a) * 9.6), SLATE, {"rot": (0, -math.degrees(a), 0)}))
		if i % 2 == 0:
			p.append(("box", (4.4, 4, 2), (math.sin(a) * 10.4, h + 7, -math.cos(a) * 10.4), STONE, {"rot": (0, -math.degrees(a), 0)}))
	for wy, a in ((14, 0), (30, 0), (46, 0), (30, 90), (30, -90)):
		r = math.radians(a)
		x, z = math.sin(r) * 8.7, -math.cos(r) * 8.7
		p.append(("box", (2.6, 6, 0.6), (x, wy, z), PINK, {"emit": 3.5, "rot": (0, -a, 0)}))
		p.append(("cone", (2.6, 2.4, 0.6), (x, wy + 4.2, z), PINK, {"seg": 4, "emit": 3.5, "rot": (0, -a, 0)}))
	_banner(p, (0, h - 4, -9.2), 16, 5)
	k.prop("Watchtower", p)
	# Brazier: stone post, iron bowl with claws, pink-violet and ember fire
	p = [
		("box", (3.6, 2, 3.6), (0, 1, 0), SLATE),
		("box", (2.4, 9, 2.4), (0, 6.5, 0), STONE2),
		("cyl", (4.6, 1.8, 4.6), (0, 11.6, 0), IRON, {"seg": 8, "taper": 1.4, "metal": 0.7}),
	]
	for a in range(4):
		r = math.radians(a * 90 + 45)
		p.append(("cone", (0.8, 3, 0.8), (math.cos(r) * 2.6, 13, math.sin(r) * 2.6), IRON2, {"seg": 4}))
	_flame(p, (0, 12.4, 0), 1.0)
	_flame(p, (0.8, 12.4, 0.6), 0.6, LAVA, FLAME)
	k.prop("Brazier", p)
	# Crag: obsidian spires with strata bands and a violet seam
	p = []
	for cx, cz, h, r in ((0, 0, 44, 14), (10, 6, 28, 9), (-9, 5, 22, 8), (4, -8, 16, 7)):
		segs = 4
		for s in range(segs):
			y0, y1 = h * s / segs, h * (s + 1) / segs
			r0 = r * (1 - 0.8 * s / segs)
			r1 = r * (1 - 0.8 * (s + 1) / segs) if s < segs - 1 else 0.4
			p.append(("cone", (r0, y1 - y0, r0), (cx, (y0 + y1) / 2, cz), (STONE3, STONE, STONE3, "34203E")[s], {"seg": 5, "taper": r1 / r0, "rot": (0, s * 17, 0)}))
		p.append(("box", (r * 0.08, h * 0.5, 0.5), (cx, h * 0.3, cz - r * 0.45), MAGENTA, {"emit": 3}))
	k.prop("Crag", p)
	# Fissure: zigzag crack, lava core with a violet rim
	p = []
	x, z = 0.0, -24.0
	for i in range(8):
		ang = (25 if i % 2 else -25) + (i * 7 % 11) - 5
		ln = 7 + i % 3 * 2
		r = math.radians(ang)
		cx, cz = x + math.sin(r) * ln / 2, z + math.cos(r) * ln / 2
		p.append(("box", (3.2 - i * 0.2, 0.3, ln), (cx, 0.15, cz), LAVA, {"emit": 5, "rot": (0, ang, 0)}))
		p.append(("box", (5.5 - i * 0.3, 0.2, ln + 1), (cx, 0.08, cz), ABYSS, {"emit": 1.5, "rot": (0, ang, 0)}))
		x, z = x + math.sin(r) * ln, z + math.cos(r) * ln
	k.prop("Fissure", p)


def build(k):
	top = _chain_tower(k)
	_gate(k)
	_wyvern(k)
	_ruins(k)
	_castle_parts(k)

	k.ground("1A1520", margin=650)
	_fill(k, "2A2530")
	L = k.length
	gates = (L * 0.06 + 70, L * 0.62 + 90)
	skip = tuple((g - 30, g + 30) for g in gates)
	for g in gates:
		pos, yaw = k.beside(g, 0, 1.0)
		k.place("Gate", pos, yaw)
	_row(k, 48, (-27, 27), ["Brazier"], start=36, skip=skip)
	_row(k, 44, (-48, 48), ["Rampart"], start=30, skip=tuple((a - 20, b + 20) for a, b in skip))
	_row(k, 150, (-74, 74), ["Watchtower"], start=80, jitter=10, skip=skip)
	_row(k, 120, (-100, 100), ["RuinA", "RuinB", "RuinB"], start=60, jitter=20)
	_row(k, 70, (-140, 140), ["Crag", "RuinB", "Crag"], start=20, jitter=24, face_road=False, scale=(0.8, 1.6))
	# Hero tower: dead ahead of the runner's camera at one of the review points, as close as its chain anchors allow
	best = None
	far = (k.lo.z + k.hi.z) / 2 + 100  # not on the overview camera's (+Z) side, where it would hide the track
	for f in (0.33, 0.9, 0.62, 0.06):
		p, right, t = k.at(L * f)
		for D in range(320, 1400, 20):
			x, z = p.x + right.x * 10 + t.x * D, p.z + right.z * 10 + t.z * D
			if _road_dist(k, x, z) >= 300 and z < far:
				if best is None or D < best[0]:
					best = (D, x, z, f)
				break
	_, cx, cz, f = best
	s = 1.0
	k.place("ChainTower", (cx, -1.0, cz), math.radians(12), s)
	print("CHAINTOWER at", (round(cx), round(cz)), "ahead of shot", f, "by", best[0])
	k.field(60, ["RuinA", "RuinB", "RuinA"], clearance=150, margin=520, scale=(1.0, 2.2))
	k.field(50, ["Crag"], clearance=110, margin=560, scale=(1.2, 3.0))
	k.field(40, ["Fissure"], clearance=50, margin=400, scale=(1.0, 2.5))
	# Keep the tower's plinth and chain anchors clear of the scattered ruins and crags
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("RuinA", "RuinB", "Crag", "Fissure"):
			lx, lz = ob.location.x, -ob.location.y
			if math.hypot(lx - cx, lz - cz) < 280 * s:
				bpy.data.objects.remove(ob)
				k.instances -= 1
	# Floating burning rubble over the land, never above the road
	placed, tries = 0, 0
	while placed < 40 and tries < 2000:
		tries += 1
		x, z = k.rng.uniform(k.lo.x - 500, k.hi.x + 500), k.rng.uniform(k.lo.z - 500, k.hi.z + 500)
		if k.clear_of_road(x, z, 60) and math.hypot(x - cx, z - cz) > 300 * s:
			k.place("Chunk", (x, k.rng.uniform(60, 220), z), k.rng.uniform(0, math.tau), k.rng.uniform(0.7, 1.6))
			placed += 1
	# Wyverns circling the tower top, never above the road
	placed, tries = 0, 0
	while placed < 6 and tries < 2000:
		tries += 1
		a = k.rng.uniform(0, math.tau)
		r = k.rng.uniform(170, 380) * s
		x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
		if k.clear_of_road(x, z, 60):
			k.place("Wyvern", (x, top * s * k.rng.uniform(0.55, 1.05), z), -a + math.pi, k.rng.uniform(1.6, 2.4))
			placed += 1
	# Purple-black sky, crimson horizon glow (lava below), dim violet moonlight
	k.sky([(0.0, "B0284A"), (0.05, "7A1A50"), (0.18, "3A1048"), (0.5, "1A0A26"), (1.0, "08040E")], strength=0.8, sun=(2.4, "D8C8FF", 30, 210))
	k.light((cx, 40, cz), "FF6A30", energy=900000, radius=60)
	k.light((cx, top * s + 40, cz), "C8A0FF", energy=600000, radius=30)
	for g in gates:
		pos, _ = k.beside(g, 0, 60)
		k.light(pos, "FF5AD2", energy=120000, radius=10)
	d = 40
	while d < L:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, "FF8A6A", energy=45000, radius=6)
		d += 160
