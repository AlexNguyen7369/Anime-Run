"""World 2 Track 2: Demon King's Castle (Solo Levelup, enemy Barran). Round 2 rebuild 2026-11-23, following the source
1-1 (refs and landmark list: docs/world2_refs/DemonCastle.md):
- ChainTower (hero): the castle itself as the source draws it, one huge plain window-gridded slab wrapped and tied down
  by thick rust-orange chains, a wall of fire climbing its lower third, and the top floor as an open deck ringed by big
  curved horn-spikes round a throne with a bright beam of light rising from it. Placed (twice if needed) where the fixed
  runner cameras see it topping the skyline.
- Gate (hero, spans the road twice): spired gate towers, a pointed arch with fire behind it, open iron doors, and a
  three-headed horned hound statue with open jaws on a plinth each side of the approach (generic monster, no likeness).
- Wyvern: a pale wyvern with red eyes carrying a purple armoured rider with a blue blade; one crosses the 33% run shot.
- RuinA / RuinB / Chunk / Smoke: the burning ruined city of the castle floors (window-grid high-rises with translucent
  flame curtains between them), irregular ember-lit rock slabs floating in the air, and smoke-cloud slabs in the sky.
- Rampart / Brazier / Crag / Edge / Fill: plain black battlements, braziers, obsidian crags, dark flagstone strips with
  ember cracks along the road edge, and stone under the raised road. Sky: purple-black top to an ember-orange horizon.
No crests, symbols or text (design doc 5): banners carry only a plain changed shape. Everything in-house, parts only.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math

import bpy
from mathutils import Matrix, Vector

STONE, STONE2, STONE3, SLATE = "2C2536", "3C3348", "1C1724", "4E4560"
EMBER, FLAME, CORE, FIRE = "FF4A10", "FF8A1A", "FFD070", "FF6A20"
MAGENTA = "B83CFF"
RUST, RUST2, BONE = "8A3A1A", "6A2A14", "D8DCE6"
DARK, WIN = "0E0A12", "16101C"
CLOTH, CLOTH2 = "4A1670", "2E0E46"
BLUE, RIDER, GOLD = "6AC8FF", "6A2E9A", "C8A040"
CONC, CONC2, CONC3 = "3A3440", "524A5C", "2A2430"
SLAB, SLAB2 = "34303A", "2A2630"
HOUND, HOUND2 = "34403A", "262E2A"


# --- local helpers (kit.py is shared, so they live here) ---
def _rotm(rx, ry, rz):
	"""kit.prop's rotation (degrees, Roblox axes) as a Blender-space matrix."""
	return Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(-rz), 3, "Y")


def _turn(m, off):
	"""Roblox offset `off` turned by Blender matrix `m`, back in Roblox axes."""
	v = m @ Vector((off[0], -off[2], off[1]))
	return (v.x, v.z, -v.y)


def _link(parts, c, d, roll, L=12.0, W=7.0, t=2.2, col=RUST):
	"""One chain link (four bars) centred at c, long axis along unit vector d (Roblox), rolled `roll` degrees."""
	rx = -math.degrees(math.asin(max(-1.0, min(1.0, d[1]))))
	ry = math.degrees(math.atan2(d[0], d[2]))
	rot = (rx, ry, roll)
	m = _rotm(*rot)
	o = {"metal": 0.5, "rough": 0.6, "rot": rot}
	for size, off in (
		((t, t, L), (-W / 2 + t / 2, 0, 0)),
		((t, t, L), (W / 2 - t / 2, 0, 0)),
		((W, t, t), (0, 0, -L / 2 + t / 2)),
		((W, t, t), (0, 0, L / 2 - t / 2)),
	):
		q = _turn(m, off)
		parts.append(("box", size, (c[0] + q[0], c[1] + q[1], c[2] + q[2]), col, o))


def _chain(parts, a, b, sag, pitch=10.0, **kw):
	"""Links along a sagging curve from a to b (Roblox points), alternate links rolled 90 degrees and recoloured."""
	pts = []
	n = 300
	for i in range(n + 1):
		t = i / n
		pts.append(Vector((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t)))
	acc, last, k = 0.0, pts[0], 0
	for p in pts[1:]:
		acc += (p - last).length
		if acc >= pitch:
			d = (p - last).normalized()
			_link(parts, (p.x, p.y, p.z), (d.x, d.y, d.z), 90 * (k % 2), col=(RUST, RUST2)[k % 2], **kw)
			k += 1
			acc = 0.0
		last = p


def _merlons(parts, w, depth, y, z, n, col, h=4.0):
	"""Merlons on every other of n slots along x across width w, at height y, on the line z."""
	step = w / n
	for i in range(0, n, 2):
		parts.append(("box", (step, h, depth), (-w / 2 + step * (i + 0.5), y + h / 2, z), col))


def _flame(parts, pos, s=1.0, hot=FLAME, core=CORE):
	"""A flame tongue: an orange cone with a hot core and a translucent outer flicker."""
	x, y, z = pos
	parts.append(("cone", (3.6 * s, 7 * s, 3.6 * s), (x, y + 3.5 * s, z), EMBER, {"seg": 5, "emit": 4, "alpha": 0.55}))
	parts.append(("cone", (3 * s, 6 * s, 3 * s), (x, y + 3 * s, z), hot, {"seg": 5, "emit": 6}))
	parts.append(("cone", (1.6 * s, 4 * s, 1.6 * s), (x, y + 2.2 * s, z), core, {"seg": 5, "emit": 9}))


def _banner(parts, pos, h=22, w=7, face=-1):
	"""A hanging cloth with a plain changed shape (three short spikes), no real emblem. face: -1 shows it toward -Z."""
	x, y, z = pos
	parts.append(("box", (w + 2, 0.8, 0.8), (x, y, z), "45454E", {"metal": 0.7}))
	parts.append(("box", (w, h, 0.5), (x, y - h / 2, z), CLOTH))
	parts.append(("cone", (w, 5, 0.5), (x, y - h - 2.4, z), CLOTH, {"seg": 4, "rot": (180, 45, 0)}))
	for dx, hh in ((-w * 0.25, h * 0.16), (0, h * 0.24), (w * 0.25, h * 0.16)):
		parts.append(("cone", (w * 0.2, hh, 0.3), (x + dx, y - h * 0.45, z + face * 0.35), GOLD, {"seg": 4, "emit": 0.6}))


def _hound(p, pos, s=1.0):
	"""Three-headed horned hound statue on a plinth, facing +Z, jaws open. Generic monster shape."""
	x0, y0, z0 = pos

	def at(x, y, z):
		return (x0 + x * s, y0 + y * s, z0 + z * s)

	def sz(a, b, c):
		return (a * s, b * s, c * s)

	p.append(("box", sz(26, 8, 34), at(0, 4, 0), SLATE))
	p.append(("box", sz(28, 2, 36), at(0, 8.5, 0), STONE2))
	y = 9.5
	p.append(("ball", sz(18, 16, 28), at(0, y + 15, -2), HOUND, {"subdiv": 2, "rough": 0.9}))
	p.append(("ball", sz(16, 14, 14), at(0, y + 20, 8), HOUND, {"subdiv": 1}))
	for lx, lz, h in ((-6, 9, 14), (6, 9, 14), (-6, -11, 12), (6, -11, 12)):
		p.append(("box", sz(4.4, h, 4.4), at(lx, y + h / 2, lz), HOUND2))
		p.append(("box", sz(5.4, 1.6, 7), at(lx, y + 0.8, lz + 1.4), HOUND2))
	p.append(("cone", sz(4, 18, 4), at(0, y + 16, -18), HOUND2, {"seg": 5, "rot": (-70, 0, 0)}))
	for hx, turn in ((-8, -22), (0, 0), (8, 22)):
		hy = y + (30 if hx == 0 else 27)
		p.append(("cyl", sz(6, 10, 6), at(hx * 0.8, hy - 4, 12), HOUND, {"seg": 6, "rot": (35, turn, 0)}))
		p.append(("box", sz(7, 6, 7), at(hx, hy, 15), HOUND, {"rot": (0, turn, 0)}))
		p.append(("box", sz(5.6, 2.2, 8), at(hx + math.sin(math.radians(turn)) * 5, hy + 0.6, 20), HOUND, {"rot": (-14, turn, 0)}))
		p.append(("box", sz(5.2, 1.6, 7), at(hx + math.sin(math.radians(turn)) * 5, hy - 4.2, 19), HOUND2, {"rot": (28, turn, 0)}))
		p.append(("box", sz(4.6, 3, 0.4), at(hx + math.sin(math.radians(turn)) * 7, hy - 1.8, 22.6), "7A1A1A", {"rot": (0, turn, 0)}))
		for tx in (-1.6, 1.6):
			p.append(("cone", sz(0.9, 2.4, 0.9), at(hx + tx + math.sin(math.radians(turn)) * 7, hy - 1.2, 23), BONE, {"seg": 4, "rot": (180, 0, 0)}))
		for ex in (-2, 2):
			p.append(("ball", sz(1.6, 1.6, 1.6), at(hx + ex, hy + 2, 18.6), "FF2030", {"emit": 8, "subdiv": 1}))
			p.append(("cone", sz(1.8, 9, 1.8), at(hx + ex * 1.2, hy + 6, 12), BONE, {"seg": 5, "rot": (-40, 0, ex * 10)}))


def _fill(k, color):
	"""Stone under the raised road (the game's hill supports), so the stair climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			h = p.y - 0.5 + 1.0
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width + 3, step + 0.5, h)
		d += step


def _row(k, every, offsets, names, start=40.0, end=None, jitter=0.0, skip=(), scale=(1.0, 1.0), face_road=True, y=-1.0, clear=0.85):
	"""Props beside the road on the ground (or at road height + y if y is None), -Z facing the road, never near another
	stretch or inside `skip` spans."""
	end = k.length - 70 if end is None else end
	d = start
	while d < end:
		for off in offsets:
			dd = d + k.rng.uniform(-jitter, jitter)
			if any(a <= dd <= b for a, b in skip):
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			(x, yy, z), yaw = k.beside(dd, o)
			if not k.clear_of_road(x, z, abs(o) * clear):
				continue
			yaw = yaw + (math.pi / 2 if off > 0 else -math.pi / 2) if face_road else k.rng.uniform(0, math.tau)
			k.place(k.rng.choice(names), (x, -1.0 if y is not None else yy, z), yaw, k.rng.uniform(*scale))
		d += every


def _road_dist(k, x, z):
	step = max(1, len(k.wps) // 600)
	return min(math.hypot(w.x - x, w.z - z) for w in k.wps[::step])


def _shots(k):
	"""The fixed runner cameras of build_track.shots: (fraction, eye (x, y, z), heading (x, z))."""
	out = []
	for f in (0.06, 0.33, 0.62, 0.9):
		p, right, t = k.at(k.length * f)
		lane = p + right * 10
		eye = lane - t * 14
		out.append((f, (eye.x, p.y + 8, eye.z), (t.x, t.z)))
	return out


def _sees(shot, x, z, top, half=14.0, up=31.0):
	f, e, h = shot
	lo = 0.0
	if f == 0.06:
		lo, half = 24.0, 40.0  # the first gate fills the middle of this frame: the tower must stand beside it
	vx, vz = x - e[0], z - e[2]
	dist = math.hypot(vx, vz)
	ang = math.degrees(math.acos(max(-1.0, min(1.0, (vx * h[0] + vz * h[1]) / (dist or 1)))))
	if f == 0.06 and vx * -h[1] + vz * h[0] > 0:
		return False  # left of the road: the right side of this frame is filled by the gate's hound and crags
	return lo <= ang < half and math.degrees(math.atan2(top - e[1], dist)) < up


# --- props ---
W, H0, HT = 220, 20, 900  # tower slab width, foot and top heights


def _chain_tower(k):
	p = []
	# Plinth and a wall of fire climbing the lower third
	p.append(("box", (340, 12, 340), (0, 6, 0), SLATE))
	p.append(("box", (290, 10, 290), (0, 17, 0), STONE))
	for tier, (r, h, n) in enumerate(((175, 120, 22), (160, 190, 18), (148, 150, 14), (140, 100, 10))):
		for i in range(n):
			a = i * math.tau / n + tier * 0.4
			x, z = math.cos(a) * r, math.sin(a) * r
			ht = h * (0.7 + 0.3 * ((i * 7 + tier) % 5) / 4)
			base = 20 + tier * 70
			p.append(("cone", (42, ht, 42), (x, base + ht / 2, z), EMBER, {"seg": 5, "emit": 3, "alpha": 0.5}))
			p.append(("cone", (30, ht * 0.85, 30), (x, base + ht * 0.42, z), FLAME, {"seg": 5, "emit": 5}))
			if i % 2 == 0:
				p.append(("cone", (16, ht * 0.5, 16), (x, base + ht * 0.25, z), CORE, {"seg": 5, "emit": 8}))
	# The slab: plain, set back once, a dense window grid (floor bands crossed by mullions)
	for w, y0, y1 in ((W, H0, 560), (W - 24, 560, HT)):
		p.append(("box", (w, y1 - y0, w), (0, (y0 + y1) / 2, 0), SLAB))
		p.append(("box", (w + 8, 6, w + 8), (0, y1, 0), SLAB2))
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			o = {"rot": (0, face * 90, 0)}
			fh = 22
			for f in range(int((y1 - y0) // fh)):
				q = _turn(m, (0, y0 + f * fh + fh * 0.55, -w / 2 - 0.4))
				p.append(("box", (w - 10, fh * 0.5, 1), q, WIN, o))
				if (f * 3 + face) % 4 == 0:
					cx = -w * 0.35 + ((f * 37 + face * 11) % 7) * w * 0.1
					q = _turn(m, (cx, y0 + f * fh + fh * 0.55, -w / 2 - 1.0))
					p.append(("box", (w * 0.09, fh * 0.42, 1), q, FIRE, dict(o, emit=2.5)))
			for c in range(9):
				q = _turn(m, (-w / 2 + w / 8 * c, (y0 + y1) / 2, -w / 2 - 1.4))
				p.append(("box", (3.4, y1 - y0, 2), q, SLAB2, o))
	# Summit (floor 100): open deck, a ring of big curved horn-spikes round a throne, a bright beam of light
	top = HT + 6
	p.append(("cyl", (W - 10, 8, W - 10), (0, top, 0), SLATE, {"seg": 16}))
	for i in range(10):
		ang = i * math.tau / 10
		yaw = 90 - math.degrees(ang)
		r = W / 2 - 20
		p.append(("cone", (26, 110, 26), (math.cos(ang) * r, top + 50, math.sin(ang) * r), BONE, {"seg": 6, "rot": (-18, yaw, 0)}))
		p.append(("cone", (14, 80, 14), (math.cos(ang) * (r + 22), top + 130, math.sin(ang) * (r + 22)), BONE, {"seg": 6, "rot": (26, yaw, 0)}))
	p.append(("box", (24, 10, 18), (0, top + 9, 0), STONE3))
	p.append(("box", (24, 40, 4), (0, top + 24, 8), STONE3))
	p.append(("cyl", (26, 3000, 26), (0, top + 1500, 0), "FFF4E0", {"seg": 10, "emit": 14}))
	p.append(("cyl", (70, 3000, 70), (0, top + 1500, 0), "FFC880", {"seg": 10, "emit": 2, "alpha": 0.25}))
	# Thick rust chains: wrapped diagonally round the slab, and drooping from the upper corners to ground anchors
	kw = {"L": 40, "W": 24, "t": 8}
	for face in range(4):
		m = _rotm(0, face * 90, 0)
		for y1, y2 in ((700, 470), (380, 260)):
			a = _turn(m, (-W / 2 + 6, y1, -W / 2 - 10))
			b = _turn(m, (W / 2 - 6, y2, -W / 2 - 10))
			_chain(p, a, b, 30, pitch=34, **kw)
	for i in range(4):
		ang = math.radians(45 + 90 * i)
		a = (math.cos(ang) * (W - 24) * 0.72, 640, math.sin(ang) * (W - 24) * 0.72)
		b = (math.cos(ang) * 470, 50, math.sin(ang) * 470)
		_chain(p, a, b, 120, pitch=34, **kw)
		bx, bz = math.cos(ang) * 490, math.sin(ang) * 490
		yaw = -math.degrees(ang)
		p.append(("box", (70, 46, 70), (bx, 23, bz), SLATE, {"rot": (0, yaw, 0)}))
		p.append(("box", (50, 16, 50), (bx, 54, bz), STONE3, {"rot": (0, yaw, 0)}))
	k.prop("ChainTower", p)
	return top + 190


def _gate(k):
	"""Spans the road: tower inner faces 30 studs from the centre line, arch underside 28+ above the road. The runner
	comes from +Z."""
	p = []
	for sx in (-1, 1):
		x = sx * 46
		p.append(("box", (36, 8, 36), (x, 4, 0), SLATE))
		p.append(("box", (32, 92, 32), (x, 50, 0), STONE))
		for by in (24, 48, 72):
			p.append(("box", (34, 2.4, 34), (x, by, 0), SLATE))
		for cz in (-1, 1):
			p.append(("box", (8, 70, 6), (x + sx * 16, 35, cz * 10), STONE3))
		p.append(("box", (38, 6, 38), (x, 99, 0), STONE2))
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			for i in range(0, 8, 2):
				q = _turn(m, (-19 + 38 / 8 * (i + 0.5), 105, -18))
				p.append(("box", (4.6, 6, 3), (x + q[0], q[1], q[2]), STONE2, {"rot": (0, face * 90, 0)}))
		p.append(("cone", (30, 64, 30), (x, 134, 0), STONE3, {"seg": 8}))
		p.append(("cyl", (1.4, 16, 1.4), (x, 172, 0), "45454E", {"seg": 6}))
		for wy in (34, 60, 84):
			p.append(("box", (4, 9, 0.8), (x, wy, 16.3), FIRE, {"emit": 2}))
			p.append(("cone", (4, 3.6, 0.8), (x, wy + 6.3, 16.3), FIRE, {"seg": 4, "emit": 2}))
		_banner(p, (x, 92, 16.6), 34, 10, face=1)
		# open door leaves swung back against the inner faces, on the far side
		p.append(("box", (2, 44, 26), (sx * 29, 22, -14), "2A2A30", {"metal": 0.6, "rough": 0.5}))
		for dy in (8, 22, 36):
			p.append(("box", (2.6, 2, 26), (sx * 29, dy, -14), "45454E", {"metal": 0.8}))
		# fire bowls inside the passage and the hound statue on the approach
		p.append(("cyl", (6, 3, 6), (sx * 26, 14, -20), "2A2A30", {"seg": 8, "taper": 1.4}))
		_flame(p, (sx * 26, 15, -20), 2.4)
		_hound(p, (sx * 46, 0, 34), 1.25)
	p.append(("box", (60, 26, 30), (0, 72, 0), STONE2))
	p.append(("box", (64, 3, 32), (0, 86, 0), SLATE))
	_merlons(p, 60, 3, 87.5, -14.5, 9, STONE2, 5)
	_merlons(p, 60, 3, 87.5, 14.5, 9, STONE2, 5)
	prev = None
	for i in range(9):
		t = i / 8
		pt = (30 * math.cos(t * math.pi / 2) ** 0.7, 30 + 29 * math.sin(t * math.pi / 2))
		if prev:
			mx, my = (pt[0] + prev[0]) / 2, (pt[1] + prev[1]) / 2
			ang = math.degrees(math.atan2(pt[1] - prev[1], pt[0] - prev[0]))
			ln = math.hypot(pt[0] - prev[0], pt[1] - prev[1]) + 1.5
			for sx in (-1, 1):
				p.append(("box", (ln, 5, 30), (sx * mx, my, 0), SLATE, {"rot": (0, 0, ang if sx > 0 else 180 - ang)}))
				p.append(("box", (ln, 0.6, 26), (sx * mx, my - 2.8, 0), FIRE, {"emit": 0.6, "rot": (0, 0, ang if sx > 0 else 180 - ang)}))
		prev = pt
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
		p.append(("box", (36, 2.4, 2.4), (sx * 22, 4, -4), BONE, {"rot": (0, sx * 10, sx * -12)}))
		for f, (fx, fz, fl) in enumerate(((40, 4, 30), (34, 12, 26), (24, 16, 20))):
			p.append(("box", (1.4, 1.4, fl), (sx * fx, 8 - f * 2, fz), BONE, {"rot": (0, sx * (-25 + f * 18), 0)}))
		p.append(("box", (34, 0.6, 20), (sx * 24, 5, 9), "3A3E58", {"rot": (0, 0, sx * -8)}))
		p.append(("cone", (24, 0.6, 18), (sx * 32, 5.6, 20), "3A3E58", {"seg": 3, "rot": (0, 0, sx * -8)}))
		p.append(("box", (3, 10, 3), (sx * 4, -7, 6), BONE, {"rot": (30, 0, 0)}))
	p += [
		("box", (5, 8, 4), (0, 10, -2), RIDER),
		("box", (6.4, 2, 4.4), (0, 13.4, -2), GOLD, {"metal": 0.8, "rough": 0.3}),
		("ball", (3.4, 3.6, 3.4), (0, 16, -2.4), RIDER, {"subdiv": 1}),
		("cone", (0.8, 6, 0.8), (-1.6, 19.5, -2), BONE, {"seg": 4, "rot": (0, 0, -30)}),
		("cone", (0.8, 6, 0.8), (1.6, 19.5, -2), BONE, {"seg": 4, "rot": (0, 0, 30)}),
		("box", (1.6, 22, 0.6), (5.5, 18, -6), BLUE, {"emit": 8, "rot": (-30, 0, -20)}),
	]
	k.prop("Wyvern", p)


def _window_face(p, w, floors, fh, y0, cols, z, rot, x0=0.0, seed=0):
	"""A window grid on the face at local z (before turning by `rot` about Y); some panes blown out, some on fire."""
	m = _rotm(0, rot, 0)
	for f in range(floors):
		for c in range(cols):
			n = (f * 7 + c * 3 + seed) % 11
			if n == 0:
				continue
			col, o = (FIRE, {"emit": 2.2}) if n % 4 == 0 else (WIN, {})
			q = _turn(m, (x0 - w / 2 + w / cols * (c + 0.5), y0 + f * fh + fh * 0.55, z))
			p.append(("box", (w / cols * 0.55, fh * 0.55, 0.6), q, col, dict(o, rot=(0, rot, 0))))


def _curtain(p, x, z, w, h, y0=0.0):
	"""A tall translucent sheet of pink-orange flame with brighter tongues in front."""
	p.append(("box", (w, h, 1), (x, y0 + h / 2, z), "FF6A50", {"emit": 3, "alpha": 0.45}))
	p.append(("box", (w * 0.7, h * 0.7, 1), (x, y0 + h * 0.35, z - 1.2), "FF9A40", {"emit": 4, "alpha": 0.5}))
	for i in range(4):
		_flame(p, (x - w / 2 + w / 4 * (i + 0.5), y0 + h * (0.15 + 0.12 * (i % 2)), z - 2), 2.0 + (i % 2), "FF7A3A")


def _ruins(k):
	# RuinA: two burning window-grid high-rises with a flame curtain between them
	p = [("box", (70, 3, 34), (0, 1.5, 0), CONC3)]
	for x, w, h, seed in ((-22, 26, 110, 1), (22, 24, 84, 3)):
		p.append(("box", (w, h, 24), (x, h / 2, 0), CONC))
		for f in range(1, int(h // 10)):
			p.append(("box", (w + 1, 1, 25), (x, f * 10, 0), CONC2))
		p.append(("box", (w * 0.6, 10, 24), (x - w * 0.2, h + 5, 0), CONC, {"rot": (0, 0, 8)}))
		_window_face(p, w, int(h // 10), 10, 0, 4, -12.1, 0, x0=x, seed=seed)
		_flame(p, (x - w * 0.2, h + 10, 0), 3.0)
		_flame(p, (x + w * 0.3, h, -6), 2.0)
	_curtain(p, 0, -4, 20, 100)
	_curtain(p, -36, -8, 12, 60)
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
	_curtain(p, 4, -8, 22, 46)
	_flame(p, (-10, 38, -2), 2.4)
	k.prop("RuinB", p)
	# Chunk: an irregular rock slab floating in the air, ember cracks glowing underneath and along its edges
	p = []
	for i, (sx, sy, sz, x, y, z, rx, ry, rz) in enumerate((
		(40, 9, 26, 0, 0, 0, 6, 0, 8),
		(26, 8, 20, 14, -5, 6, -8, 30, -12),
		(22, 10, 18, -14, -6, -4, 12, -20, 10),
		(14, 12, 12, 2, -12, 2, 20, 45, 15),
		(10, 9, 9, -4, -18, -2, -15, 10, 25),
	)):
		p.append(("box", (sx, sy, sz), (x, y, z), ("3A2A26", "2E2220", "44322C")[i % 3], {"rot": (rx, ry, rz)}))
	for x, z, ang, ln in ((-8, 0, 20, 22), (10, 4, -35, 16), (0, -6, 80, 14)):
		p.append(("box", (1.4, 0.6, ln), (x, -5.2, z), EMBER, {"emit": 5, "rot": (6, ang, 8)}))
	p.append(("box", (30, 0.8, 18), (2, -9, 2), FIRE, {"emit": 2.5, "rot": (6, 10, 8)}))
	p.append(("cone", (6, 10, 6), (6, -26, 3), FLAME, {"seg": 5, "emit": 4, "rot": (180, 0, 0), "alpha": 0.6}))
	k.prop("Chunk", p)
	# Smoke: a slab of smoke cloud, ember-lit from below
	p = []
	for i, (x, y, z, w, h, d) in enumerate(((0, 0, 0, 140, 24, 80), (60, 8, 20, 90, 30, 60), (-64, 6, -10, 100, 28, 70), (20, 18, -30, 80, 26, 50), (-20, -10, 24, 110, 20, 60))):
		p.append(("ball", (w, h, d), (x, y, z), ("3A2E30", "2E2428", "463638")[i % 3], {"subdiv": 1, "smooth": True}))
	p.append(("cyl", (150, 2, 90), (0, -12, 0), "6A2A1A", {"seg": 9, "emit": 0.5, "alpha": 0.5}))
	k.prop("Smoke", p)


def _castle_parts(k):
	# Rampart: black wall run, plain stone merlons, buttresses, dark arrow slits, a banner; -Z faces the road
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
		p.append(("box", (1.6, 8, 0.6), (x, 14, -4.3), DARK))
		p.append(("box", (4.6, 1, 1.4), (x, 9.5, -4.6), SLATE))
	_banner(p, (0, 23, -5.4), 13, 5)
	k.prop("Rampart", p)
	# Brazier: stone post, iron bowl with claws, orange fire
	p = [
		("box", (3.6, 2, 3.6), (0, 1, 0), SLATE),
		("box", (2.4, 9, 2.4), (0, 6.5, 0), STONE2),
		("cyl", (4.6, 1.8, 4.6), (0, 11.6, 0), "2A2A30", {"seg": 8, "taper": 1.4, "metal": 0.7}),
	]
	for a in range(4):
		r = math.radians(a * 90 + 45)
		p.append(("cone", (0.8, 3, 0.8), (math.cos(r) * 2.6, 13, math.sin(r) * 2.6), "45454E", {"seg": 4}))
	_flame(p, (0, 12.4, 0), 1.1)
	k.prop("Brazier", p)
	# Crag: obsidian spires with strata bands
	p = []
	for cx, cz, h, r in ((0, 0, 44, 14), (10, 6, 28, 9), (-9, 5, 22, 8), (4, -8, 16, 7)):
		segs = 4
		for s in range(segs):
			y0, y1 = h * s / segs, h * (s + 1) / segs
			r0 = r * (1 - 0.8 * s / segs)
			r1 = r * (1 - 0.8 * (s + 1) / segs) if s < segs - 1 else 0.4
			p.append(("cone", (r0, y1 - y0, r0), (cx, (y0 + y1) / 2, cz), (STONE3, STONE, STONE3, "34203E")[s], {"seg": 5, "taper": r1 / r0, "rot": (0, s * 17, 0)}))
	k.prop("Crag", p)
	# Edge: a strip of dark flagstones with ember cracks, laid along the road just past the 24-stud line
	p = [("box", (8, 0.4, 36), (0, 0.2, 0), "1E1A22")]
	for i in range(12):
		for j in range(2):
			p.append(("box", (3.4, 0.35, 2.6), (-2 + j * 4, 0.55, -16.5 + i * 3), ("3A3442", "302A38", "443C4C")[(i + j) % 3], {"rot": (0, (i * 7 + j * 3) % 9 - 4, 0)}))
	for z, ang, ln in ((-10, 20, 7), (3, -30, 5), (12, 10, 8)):
		p.append(("box", (0.5, 0.5, ln), (0.5, 0.6, z), EMBER, {"emit": 5, "rot": (0, ang, 0)}))
	k.prop("Edge", p)


def build(k):
	top = _chain_tower(k)
	_gate(k)
	_wyvern(k)
	_ruins(k)
	_castle_parts(k)

	k.ground("1A1520", margin=2800)
	_fill(k, "2A2530")
	L = k.length
	gates = (L * 0.06 + 150, L * 0.62 + 90)  # the first far enough ahead that the tower shows over its bridge
	skip = tuple((g - 75, g + 40) for g in gates)  # the hound statues stand on the approach, before the arch
	for g in gates:
		pos, yaw = k.beside(g, 0, 1.0)
		k.place("Gate", pos, yaw)
	# Road edge: flagstone strips just outside the 24-stud line, braziers, ramparts
	d = 20.0
	while d < L - 40:
		if not any(a <= d <= b for a, b in skip):
			for side in (-1, 1):
				(x, y, z), yaw = k.beside(d, side * 28, 0.9)
				if k.clear_of_road(x, z, 24):
					k.place("Edge", (x, y, z), yaw)
		d += 44
	_row(k, 80, (-30, 30), ["Brazier"], start=50, skip=skip)
	_row(k, 44, (-48, 48), ["Rampart"], start=30, skip=skip)
	_row(k, 110, (-95, 95), ["RuinB"], start=60, jitter=20)
	_row(k, 120, (-170, 170), ["RuinA", "Crag"], start=20, jitter=24, scale=(0.8, 1.4))
	# Hero tower: where the fixed runner cameras see it top the skyline; a second copy for any shot the first misses
	shots = _shots(k)
	need = [s for s in shots if s[0] != 0.62]
	towers = []
	while need and len(towers) < 3:
		best = None
		for i in range(-30, 31):
			for j in range(-30, 31):
				x = (k.lo.x + k.hi.x) / 2 + i * 90
				z = (k.lo.z + k.hi.z) / 2 + j * 90
				if _road_dist(k, x, z) < 560 or any(math.hypot(x - a, z - b) < 900 for a, b in towers):
					continue
				seen = [s for s in need if _sees(s, x, z, top)]
				score = (len(seen), -max(math.hypot(x - s[1][0], z - s[1][2]) for s in seen) if seen else 0)
				if seen and (best is None or score > best[0]):
					best = (score, x, z, seen)
		if not best:
			break
		_, x, z, seen = best
		towers.append((x, z))
		need = [s for s in need if s not in seen]
		k.place("ChainTower", (x, -1.0, z), math.radians(12))
		print("CHAINTOWER at", (round(x), round(z)), "seen by shots", [s[0] for s in seen])
	if need:
		print("CHAINTOWER not seen by shots", [s[0] for s in need])
	k.field(40, ["RuinA", "RuinB", "RuinA"], clearance=150, margin=700, scale=(1.0, 2.2))
	k.field(20, ["Crag"], clearance=110, margin=800, scale=(1.2, 3.0))
	# keep the tower plinths and chain anchors clear of the scatter
	for ob in list(k.col.objects):
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("RuinA", "RuinB", "Crag"):
			lx, lz = ob.location.x, -ob.location.y
			if any(math.hypot(lx - a, lz - b) < 560 for a, b in towers):
				bpy.data.objects.remove(ob)
				k.instances -= 1
	# Floating rock slabs and smoke clouds, never above the road
	cx, cz = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2
	for name, n, lo_y, hi_y, sc in (("Chunk", 36, 60, 240, (0.8, 1.8)), ("Smoke", 12, 450, 750, (0.8, 1.4))):
		placed, tries = 0, 0
		while placed < n and tries < 3000:
			tries += 1
			x, z = k.rng.uniform(k.lo.x - 900, k.hi.x + 900), k.rng.uniform(k.lo.z - 900, k.hi.z + 900)
			if k.clear_of_road(x, z, 80 if name == "Chunk" else 400) and all(math.hypot(x - a, z - b) > 300 for a, b in towers):
				k.place(name, (x, k.rng.uniform(lo_y, hi_y), z), k.rng.uniform(0, math.tau), k.rng.uniform(*sc))
				placed += 1
	# Wyverns: one crossing the 33% run shot's sky, the rest circling the towers' tops
	p, right, t = k.at(L * 0.33)
	for D, off, y, sc in ((210, -40, 78, 1.3), (330, 60, 120, 1.6)):
		x, z = p.x + t.x * D + right.x * off, p.z + t.z * D + right.z * off
		k.place("Wyvern", (x, p.y + y, z), math.atan2(-right.x, -right.z) + 0.5, sc)
	for tx, tz in towers:
		for i in range(3):
			a = i * math.tau / 3 + 0.4
			r = 300 + i * 60
			k.place("Wyvern", (tx + math.cos(a) * r, top * (0.75 + 0.1 * i), tz + math.sin(a) * r), -a + math.pi, 4.0)
	# Purple-black sky down to an ember-orange horizon
	k.sky([(0.0, "FF7A2A"), (0.04, "C0442A"), (0.12, "6A2038"), (0.3, "2A0E2E"), (1.0, "08040C")], strength=0.9, sun=(2.2, "FFD0B0", 22, 210))
	for tx, tz in towers:
		k.light((tx, 160, tz), "FF7A2A", energy=4000000, radius=120)
		k.light((tx, top - 120, tz), "FFE0C0", energy=1500000, radius=40)
	for g in gates:
		pos, _ = k.beside(g + 60, 0, 16)  # fire glow beyond the arch
		k.light(pos, "FF7A2A", energy=150000, radius=12)
	d = 40
	while d < L:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, "FF9A6A", energy=45000, radius=6)
		d += 160
	counts = {}
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.data.name.startswith("W2_"):
			key = ob.data.name.split("_")[-1]
			counts[key] = counts.get(key, 0) + 1
	print("PERPROP", counts)
