"""World 2 Track 2: Demon King's Castle (Solo Levelup, enemy Barran). Round 3 rebuild 2026-11-23, following the source
1-1 (refs and landmark list: docs/world2_refs/DemonCastle.md):
- ChainTower (hero, one only): the castle as the source draws it, one huge plain window-gridded slab (1300 studs) with
  orange-to-yellow flame sheets climbing about 70% of it with black ash flecks, floor ledges over every window row,
  three huge rusty chains sagging in from anchors high in the sky and biting into its upper faces, and the top floor
  as an open deck ringed by big curved pale horns
  round an enthroned purple-and-gold figure, with a bright beam of light rising from it. Placed where the most fixed
  runner cameras see it; EXTRA_SHOTS adds a runner-lane view of it.
- Gate (hero, spans the road twice): low spired gate towers, a pointed arch, heavy iron doors swung open, a wall of fire
  beyond the arch. Hound (hero): the three-headed horned hound as a statue on a plinth each side of the approach.
- Wyvern: pale grey-white wyvern, dark membrane wings on three finger spars, a swept horn crown, red eyes, carrying a
  purple armoured rider with a blue blade; two cross the 33% run shot, four circle the castle top.
- RuinA / RuinB / Chunk / Smoke: the burning ruined city of the castle floors (window-grid high-rises with pink-magenta
  fire billowing up around them), irregular rock slabs burning in the air, smoke clouds.
- Rampart / Crag / Edge / Fill: plain black battlements with a brazier in front, obsidian crags, dark flagstone strips with
  ember cracks along the road edge, stone under the raised road. Sky: purple-black top to an ember-orange horizon.
Flames come in three shapes (tongue, sheet, bud) at varied scale. No crests, symbols or text (design doc 5); the
figures are generic. Everything in-house, parts only. Proposed look; the owner approves the render set (design doc 4.46)."""

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
SLAB, SLAB2 = "4A4452", "2A2630"
HOUND, HOUND2 = "34403A", "262E2A"

# Extra review shots, filled in by build() (build_track.py renders them): [(file, eye, look), ...]
EXTRA_SHOTS = []
# Hero models rendered as full-size close-ups
MODEL_SHOTS = ["ChainTower", "Gate", "Hound", "Wyvern"]
# Spans the road (arch 28+ overhead), supports under the raised road, wyverns flying 60+ above the road
CLEAR_EXEMPT = {"Gate", "Fill", "Wyvern"}


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


def _flame(parts, pos, s=1.0, hot=FLAME, core=CORE, kind=None, outer=EMBER):
	"""A flame in one of three shapes, picked from its position unless `kind` is given:
	tongue (a tall curved tongue in two leaning pieces), sheet (a wide flat sheet with tongues), bud (a small low flame)."""
	x, y, z = pos
	if kind is None:
		kind = ("tongue", "sheet", "tongue", "bud")[int(abs(x * 7.3 + z * 3.1 + y)) % 4]
	lean = (int(abs(x * 13 + z * 5)) % 5 - 2) * 6
	if kind == "tongue":
		parts.append(("cone", (3.4 * s, 6 * s, 2.2 * s), (x, y + 3 * s, z), outer, {"seg": 5, "emit": 4, "alpha": 0.6, "rot": (0, 0, lean * 0.5)}))
		parts.append(("cone", (2.4 * s, 7 * s, 1.6 * s), (x + lean * 0.05 * s, y + 7 * s, z), hot, {"seg": 5, "emit": 6, "rot": (0, 0, lean)}))
		parts.append(("cone", (1.4 * s, 4 * s, 1.2 * s), (x, y + 2.4 * s, z), core, {"seg": 5, "emit": 9}))
	elif kind == "sheet":
		parts.append(("cone", (8 * s, 6 * s, 1.2 * s), (x, y + 3 * s, z), outer, {"seg": 6, "emit": 4, "alpha": 0.6, "rot": (0, 0, lean * 0.3)}))
		for dx, h in ((-2.2, 5), (0.4, 7.5), (2.6, 4.5)):
			parts.append(("cone", (2.4 * s, h * s, 0.8 * s), (x + dx * s, y + h * 0.5 * s, z - 0.4 * s), hot, {"seg": 4, "emit": 6, "rot": (0, 0, lean + dx * 4)}))
		parts.append(("cone", (4 * s, 3 * s, 0.9 * s), (x, y + 1.5 * s, z - 0.6 * s), core, {"seg": 5, "emit": 9}))
	else:
		parts.append(("cone", (2.6 * s, 3.4 * s, 2.6 * s), (x, y + 1.7 * s, z), hot, {"seg": 5, "emit": 6}))
		parts.append(("cone", (1.2 * s, 2 * s, 1.2 * s), (x, y + 1 * s, z), core, {"seg": 5, "emit": 9}))


def _banner(parts, pos, h=22, w=7, face=-1):
	"""A hanging cloth with a plain changed shape (three short spikes), no real emblem. face: -1 shows it toward -Z."""
	x, y, z = pos
	parts.append(("box", (w + 2, 0.8, 0.8), (x, y, z), "45454E", {"metal": 0.7}))
	parts.append(("box", (w, h, 0.5), (x, y - h / 2, z), CLOTH))
	parts.append(("cone", (w, 5, 0.5), (x, y - h - 2.4, z), CLOTH, {"seg": 4, "rot": (180, 45, 0)}))
	for dx, hh in ((-w * 0.25, h * 0.16), (0, h * 0.24), (w * 0.25, h * 0.16)):
		parts.append(("cone", (w * 0.2, hh, 0.3), (x + dx, y - h * 0.45, z + face * 0.35), GOLD, {"seg": 4, "emit": 0.6}))


def _frame(ux, uy, uz):
	"""kit.prop rot (degrees) that turns a part's local X, Y, Z onto the Roblox unit vectors ux, uy, uz."""
	m = Matrix(((ux[0], -ux[2], ux[1]), (-uz[0], uz[2], -uz[1]), (uy[0], -uy[2], uy[1]))).transposed()
	e = m.to_euler("YXZ")
	return (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y))


def _seg(p, a, b, t, col, opts=None, shape="box", t2=None):
	"""A bone, horn or limb from Roblox point a to b: box (t square), cyl, or cone pointing at b (taper t2/t)."""
	a, b = Vector(a), Vector(b)
	d = b - a
	if d.length < 1e-4:
		return
	uy = d.normalized()
	ref = Vector((0, 0, 1)) if abs(uy.y) > 0.9 else Vector((0, 1, 0))
	ux = ref.cross(uy).normalized()
	uz = ux.cross(uy)
	o = dict(opts or {}, rot=_frame(ux, uy, uz))
	if shape != "box":
		o.setdefault("seg", 6)
		if t2 is not None:
			o["taper"] = t2 / t
	c = (a + b) / 2
	p.append((shape, (t, d.length, t), (c.x, c.y, c.z), col, o))


def _tri(p, A, B, C, col, t=0.5, opts=None):
	"""A flat triangle (membrane, blade) through Roblox points A, B, C, as two right-angled wedges."""
	A, B, C = Vector(A), Vector(B), Vector(C)
	A, B, C = max(((A, B, C), (B, C, A), (C, A, B)), key=lambda v: (v[1] - v[0]).length)
	ab = B - A
	H = A + ab * ((C - A).dot(ab) / ab.length_squared)
	hc = C - H
	if hc.length < 1e-3:
		return
	uy = hc.normalized()
	for P in (A, B):
		leg = P - H
		if leg.length < 1e-3:
			continue
		uz = -leg.normalized()
		c = H + hc / 2 + leg / 2
		p.append(("wedge", (t, hc.length, leg.length), (c.x, c.y, c.z), col, dict(opts or {}, rot=_frame(uy.cross(uz), uy, uz))))


def _hound(k):
	"""Hound (own prop): the castle gate's three-headed hound as a statue on a plinth, facing -Z: a dark green upright
	brute on its haunches, arms forward with claws, a pale mane; three snarling heads with jaws wide open (rows of fangs,
	red tongue, red eyes), curled tan horns on the middle and right heads, a pale helm with pointed ears on the left one.
	A generic monster, no likeness issue."""
	# a tall stepped pedestal: its top stands clear of the ramparts in the runner's view, so the statue reads seated on it
	PH = 30
	p = [("box", (50, 20, 50), (0, -6, 0), STONE3), ("box", (46, 6, 46), (0, 7, 0), SLATE), ("box", (40, PH, 40), (0, 10 + PH / 2, 0), SLATE)]
	p += [("box", (42, 2, 42), (0, 9 + PH, 0), STONE2), ("box", (36, 3, 36), (0, 11.5 + PH, 0), STONE)]
	for x in (-19, 19):
		for z in (-19, 19):
			p.append(("box", (4, PH + 10, 4), (x, (PH + 10) / 2, z), STONE3))
	for by in (18, 30):
		p.append(("box", (41, 1.6, 41), (0, by, 0), STONE3))
	for i in range(2):  # fire bowls on the pedestal's front corners
		_flame(p, ((-1) ** i * 16, 13 + PH, -16), 1.6, kind="tongue")
	y = 13 + PH
	sm = {"subdiv": 2, "smooth": True, "rough": 0.7}
	MANE, HORN, TOOTH, MOUTH = "B8A060", "A8783A", "EEE8D8", "8A1418"
	# haunches, belly and a broad upright chest (cerberus_gate: a massive brute)
	for sx in (-1, 1):
		p.append(("ball", (16, 15, 20), (sx * 10, y + 7, 6), HOUND, sm))
		_seg(p, (sx * 11, y + 4, 10), (sx * 12, y + 1, -3), 7, HOUND2, shape="cyl")
		p.append(("ball", (9, 4, 10), (sx * 12, y + 2, -6), HOUND2, {"subdiv": 1}))
	p.append(("ball", (28, 22, 22), (0, y + 15, 4), HOUND, sm))
	p.append(("ball", (58, 36, 30), (0, y + 34, -1), HOUND, sm))  # a huge, broad chest
	for sx in (-1, 1):  # pectorals
		p.append(("ball", (24, 16, 10), (sx * 12, y + 38, -13), "3C4A40", sm))
	p.append(("ball", (18, 14, 6), (0, y + 23, -11), "4A5A48", sm))  # pale belly plate
	for i in range(3):
		p.append(("box", (14 - i * 2, 1.2, 1), (0, y + 19 + i * 3.6, -13.6 + i * 0.4), HOUND2))
	# huge arms flung wide toward the viewer, open clawed hands
	for sx in (-1, 1):
		sh, el, wr = (sx * 26, y + 44, -3), (sx * 40, y + 36, -14), (sx * 46, y + 44, -28)
		p.append(("ball", (30, 27, 27), sh, HOUND, sm))  # massive shoulders
		_seg(p, sh, el, 21, HOUND, shape="cyl", t2=18)
		p.append(("ball", (20, 20, 20), el, HOUND, sm))
		_seg(p, el, wr, 16, HOUND, shape="cyl", t2=17)
		p.append(("ball", (17, 17, 12), wr, HOUND2, {"subdiv": 1}))
		for i in (-1.5, -0.5, 0.5, 1.5):  # fingers spread, claws curled at the viewer
			b0 = (wr[0] + i * 3.6, wr[1] + 6, wr[2] - 4)
			b1 = (wr[0] + i * 5, wr[1] + 11, wr[2] - 9)
			_seg(p, b0, b1, 3.4, HOUND2, shape="cyl")
			_seg(p, b1, (b1[0] + i * 0.6, b1[1] - 1, b1[2] - 6), 2.2, TOOTH, shape="cone", t2=0.1)
		_seg(p, (wr[0] - sx * 5, wr[1], wr[2] - 2), (wr[0] - sx * 9, wr[1] + 2, wr[2] - 7), 1.8, TOOTH, shape="cone", t2=0.1)  # thumb claw
	# tan mane rising behind the heads (seen from the front between and above them), spikes down the back
	for i in range(11):
		x = (i - 5) * 3.8
		_seg(p, (x, y + 40, 8), (x * 1.5, y + 74 - abs(i - 5) * 2.4, 14), 7, MANE, shape="cone", t2=0.3)
	for i in range(5):
		_seg(p, (0, y + 34 - i * 5, 12 + i * 1.5), (0, y + 40 - i * 5, 20 + i * 1.5), 3, HOUND2, shape="cone", t2=0.1)
	# three big heads side by side above the shoulders, each facing the viewer and tipped a little down at the road:
	# a short muzzle, the upper jaw tipped back about 40 degrees and the lower jaw dropped round a round red maw ringed
	# with fangs, a red tongue, red eyes; thick curled ram horns on the middle and right heads, a pale pointed-ear helm
	# on the left one (cerberus_gate)
	for hx, turn, hy in ((-19, 16, 52), (0, 0, 57), (19, -16, 52)):  # sitting low between the shoulders
		hc = Vector((hx, y + hy, -10))
		_seg(p, (hx * 0.5, y + 40, -2), hc + Vector((0, -3, 5)), 13, HOUND, shape="cyl")
		m = _rotm(-28, turn, 0)  # negative pitch tips the muzzle down at the road camera below

		def at(off, s=1.35):
			q = _turn(m, (off[0] * s, off[1] * s, off[2] * s))
			return (hc.x + q[0], hc.y + q[1], hc.z + q[2])

		def bar(a_, b_, w, th, col, o=None):
			"""A plate from local a_ to b_, w wide (head X) and th thick."""
			A, B = Vector(at(a_)), Vector(at(b_))
			uy = (B - A).normalized()
			sx = Vector(at((1, 0, 0))) - Vector(at((0, 0, 0)))
			ux = (sx - uy * sx.dot(uy)).normalized()
			c = (A + B) / 2
			p.append(("box", (w * 1.35, (B - A).length, th * 1.35), (c.x, c.y, c.z), col, dict(o or {}, rot=_frame(ux, uy, ux.cross(uy)))))

		helm = hx > 0  # the viewer's left head
		p.append(("ball", (14 * 1.35, 12 * 1.35, 13 * 1.35), at((0, 3, 3)), HOUND, sm))  # cranium
		# a protruding snout gaping top to bottom: the upper jaw thrust forward and tipped up 30 degrees, the lower jaw
		# dropped 35, a dark red palate, floor and back wall between them (a tall wedge-shaped opening, not a disc)
		du, dl = Vector((0, 0.5, -0.866)), Vector((0, -0.574, -0.819))
		nu, nl = Vector((0, -0.866, -0.5)), Vector((0, 0.819, -0.574))  # into the mouth from each jaw
		U0, L0 = Vector((0, 3, -1)), Vector((0, -3, -1))
		U, L = U0 + du * 13, L0 + dl * 11
		bar(U0, U, 9, 4, "D0CCC4" if helm else HOUND, {"rough": 0.7})  # snout
		bar(U - du * 1.2 - nu * 0.6, U + du * 0.3 - nu * 0.6, 4, 3, "2A2A2E")  # nose pad
		bar(L0, L, 8, 3, HOUND2)  # lower jaw
		bar(U0 + nu * 2.2, U + nu * 2.2, 7.4, 0.8, MOUTH, {"emit": 0.5})  # palate
		bar(L0 + nl * 1.7, L + nl * 1.7, 6.8, 0.8, MOUTH, {"emit": 0.5})  # mouth floor
		bar((0, 2.4, -1.6), (0, -2.6, -1.6), 8, 1, "3A0408")  # throat wall
		for sx in (-1, 1):  # dark red cheek webs close the wedge's sides
			_tri(p, at((sx * 4, 2.6, -1)), at(U * 0.9 + Vector((sx * 3.8, 0, 0)) + nu * 2), at(L * 0.9 + Vector((sx * 3.6, 0, 0)) + nl * 1.6), "5A0A10", 0.6)
		for jaw0, tipv, n, ln, half in ((U0, U, nu, 3.6, 2.0), (L0, L, nl, 3.0, 1.5)):  # one row of long fangs on each jaw edge
			for i in range(5):
				t = 0.3 + i * 0.16
				for sx in (-1, 1):
					q = jaw0.lerp(tipv, t) + n * half + Vector((sx * 3.4, 0, 0))
					_seg(p, at(q), at(q + n * (ln * 1.4 + (1.4 if i == 3 else 0))), 2.1, TOOTH, shape="cone", t2=0.1)
			for sx in (-1.4, 1.4):
				q = tipv + n * half + Vector((sx, 0, 0))
				_seg(p, at(q), at(q + n * ln * 1.1), 1.8, TOOTH, shape="cone", t2=0.1)
		tg = L0 + nl * 2.0
		bar(tg + dl * 1, tg + dl * 8.5, 4.6, 1.2, "D0303A", {"emit": 0.7})  # red tongue lying in the lower jaw, tip just past it
		for sx in (-1, 1):
			p.append(("ball", (3.4 * 1.35, 2.4 * 1.35, 1.8 * 1.35), at((sx * 4.2, 7.4, -4.8)), "FF1010", {"emit": 6, "subdiv": 1}))  # red eyes, all heads
			bar((sx * 4.6, 10, -1), (sx * 4, 9, -5.6), 4, 1.6, "D0CCC4" if helm else HOUND2)  # brow
			if not helm:  # thick curled ram horns
				curl = [(5, 8, 3), (9, 13, 5), (13, 13, 10), (14.4, 8, 12), (13, 4, 9), (10.6, 4.4, 5.6)]
				for j in range(len(curl) - 1):
					q0 = at((sx * curl[j][0], curl[j][1], curl[j][2]))
					q1 = at((sx * curl[j + 1][0], curl[j + 1][1], curl[j + 1][2]))
					t0 = 6.4 - j * 1.0
					_seg(p, q0, q1, t0, HORN if j % 2 == 0 else "B88A48", shape="cone" if j == len(curl) - 2 else "cyl", t2=t0 - 1.0 if j < len(curl) - 2 else 0.6)
		if helm:  # pale helm over the skull and snout, two tall flat pointed ears flared out
			HELM = "D0CCC4"
			p.append(("ball", (15 * 1.35, 9 * 1.35, 13 * 1.35), at((0, 7, 2)), HELM, {"subdiv": 2, "smooth": True}))
			bar(U0 - nu * 2.4, U - nu * 2.4, 9.6, 1.4, HELM)  # snout guard on the upper jaw
			for sx in (-1, 1):
				_tri(p, at((sx * 4, 10, 3)), at((sx * 9, 5, -1)), at((sx * 18, 21, 0)), HELM, 1.6)
				_tri(p, at((sx * 5.4, 9.4, 0.4)), at((sx * 8.8, 6.6, -1.6)), at((sx * 15.4, 18.6, -1.2)), "7A5A58", 0.6)
				bar((sx * 4.2, 9, 0), (sx * 4.6, 10, -6), 3, 2, HELM)  # cheek guard
	k.prop("Hound", p)


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
W, H0, HT = 280, 20, 1300  # tower slab width, foot and top heights
SKY_R, SKY_Y = 1150, 2050  # huge chains hang in from anchors high off to the sides: radius from the tower centre, height
CHAIN_AT = ((20, 1120), (160, 1040), (295, 960), (215, 1180))  # chain runs: azimuth (deg) and the height they bite into the slab


def _chain_runs():
	"""The huge chains as (anchor, bite) Roblox points in the tower's local space."""
	out = []
	for az, ay in CHAIN_AT:
		ang = math.radians(az)
		out.append(((math.cos(ang) * SKY_R, SKY_Y, math.sin(ang) * SKY_R), (math.cos(ang) * (W - 30) / 2, ay, math.sin(ang) * (W - 30) / 2)))
	return out


def _chain_tower(k):
	p = []
	p.append(("box", (420, 14, 420), (0, 7, 0), SLATE))
	p.append(("box", (360, 10, 360), (0, 19, 0), STONE))
	# The slab: plain, set back once, a dense window grid (floor bands crossed by mullions)
	for w, y0, y1 in ((W, H0, 820), (W - 30, 820, HT)):
		p.append(("box", (w, y1 - y0, w), (0, (y0 + y1) / 2, 0), "A8A098"))  # pale stone (webtoon_castle)
		p.append(("box", (w + 10, 8, w + 10), (0, y1, 0), SLAB2))
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			o = {"rot": (0, face * 90, 0)}
			fh = 24
			for f in range(int((y1 - y0) // fh)):
				q = _turn(m, (0, y0 + f * fh + fh * 0.55, -w / 2 - 0.4))
				p.append(("box", (w - 12, fh * 0.5, 1), q, WIN, o))
				q = _turn(m, (0, y0 + f * fh + 1.5, -w / 2 - 2))  # floor ledge, so every window row reads
				p.append(("box", (w + 4, 3.4, 4), q, "C8C0B6", o))
				if (f * 3 + face) % 4 == 0:  # lit windows over the full height
					cx = -w * 0.35 + ((f * 37 + face * 11) % 7) * w * 0.1
					q = _turn(m, (cx, y0 + f * fh + fh * 0.55, -w / 2 - 1.0))
					p.append(("box", (w * 0.09, fh * 0.42, 1), q, FIRE, dict(o, emit=2.5)))
			for c in range(9):
				q = _turn(m, (-w / 2 + w / 8 * c, (y0 + y1) / 2, -w / 2 - 1.4))
				p.append(("box", (4, y1 - y0, 2), q, "B4ACA2", o))
	# Fire wrapping the slab (webtoon_castle): a few big, see-through, curling orange flame tongues up each face over the
	# full height, each a broad body with a ragged forked, tapered top and a paler core; broad ragged black ash tatters
	# running diagonally across; the pale stone, the dark window grid and the floor ledges read through
	for face in range(4):
		m = _rotm(0, face * 90, 0)
		o = {"rot": (0, face * 90, 0)}
		for i, (x, y0, wd, hh) in enumerate(((-70, 20, 150, 330), (80, 60, 140, 380), (-10, 300, 170, 360), (-80, 560, 130, 330), (70, 640, 140, 320), (0, 880, 150, 300), (-60, 1080, 110, 200))):
			lean = ((i * 7 + face * 3) % 5 - 2) * 6
			z = -W / 2 - 10 - (i % 2) * 2
			q = _turn(m, (x, y0 + hh * 0.32, z))
			p.append(("box", (wd, hh * 0.64, 1), q, "FF6A14", dict(o, emit=2.2, alpha=0.28)))  # body
			for dx, tw, th, tl in ((-0.28, 0.5, 0.55, -1), (0.12, 0.62, 0.75, 1), (0.36, 0.3, 0.4, 1)):  # forked, ragged top
				q = _turn(m, (x + dx * wd, y0 + hh * 0.62 + hh * th / 2, z - 0.4))
				p.append(("cone", (wd * tw, hh * th, 1), q, ("FF8A1C", "FFA030")[i % 2], {"seg": 4, "taper": 0.08, "emit": 2.6, "alpha": 0.3, "rot": (0, face * 90, lean + tl * 8)}))
			q = _turn(m, (x, y0 + hh * 0.3, z - 1.2))
			p.append(("cone", (wd * 0.5, hh * 0.6, 1), q, "FFD060", {"seg": 4, "taper": 0.2, "emit": 4, "alpha": 0.35, "rot": (0, face * 90, lean)}))  # core
		for i in range(5):  # broad ragged black ash tatters, diagonal
			x = -W * 0.38 + ((i * 53 + face * 19) % 76) / 76 * W * 0.76
			y = 140 + ((i * 71 + face * 29) % 100) / 100 * 1000
			ln = 170 + (i * 37 % 4) * 40
			tilt = (35 if (i + face) % 2 else -35) + (i * 7 % 11) - 5
			q = _turn(m, (x, y, -W / 2 - 14))
			p.append(("box", (34 + i % 3 * 12, ln, 1), q, "0A0606", dict(o, alpha=0.8, rot=(0, face * 90, tilt))))
			q = _turn(m, (x + math.copysign(26, tilt), y + ln * 0.36, -W / 2 - 14.4))
			p.append(("box", (16, ln * 0.45, 1), q, "0A0606", dict(o, alpha=0.8, rot=(0, face * 90, tilt * 1.6))))  # torn edge
	for a in range(8):  # low fire round the foot: wide soft sheets
		ang = a * math.tau / 8
		p.append(("box", (130, 70, 1), (math.cos(ang) * 190, 50, math.sin(ang) * 190), "FF7A18", {"emit": 3, "alpha": 0.3, "rot": (0, 90 - math.degrees(ang), 0)}))
	# Summit (floor 100): a ring of big curved pale horns round an enthroned purple-and-gold figure, a beam of light
	top = HT + 8
	p.append(("cyl", (W - 20, 10, W - 20), (0, top, 0), SLATE, {"seg": 16}))
	for i in range(9):
		ang = i * math.tau / 9
		yaw = 90 - math.degrees(ang)
		r = W / 2 - 30
		ca, sa = math.cos(ang), math.sin(ang)
		for (rr, y, wd, h, tilt) in ((r, 60, 40, 130, -16), (r + 34, 170, 28, 110, 12), (r + 50, 262, 16, 90, 40)):
			p.append(("cone", (wd, h, wd), (ca * rr, top + y, sa * rr), BONE, {"seg": 6, "taper": 0.45 if tilt < 30 else 0.0, "rot": (tilt, yaw, 0)}))
	p.append(("box", (60, 24, 46), (0, top + 17, 0), STONE3))  # throne
	p.append(("box", (60, 90, 12), (0, top + 50, 22), STONE3))
	p.append(("cone", (14, 40, 8), (-22, top + 113, 22), BONE, {"seg": 4}))
	p.append(("cone", (14, 40, 8), (22, top + 113, 22), BONE, {"seg": 4}))
	fy = top + 29  # the seated figure: generic armoured demon lord, purple with gold plates
	p += [
		("box", (26, 34, 16), (0, fy + 17, 6), RIDER),
		("box", (34, 8, 18), (0, fy + 34, 6), GOLD, {"metal": 0.8, "rough": 0.3}),
		("box", (24, 10, 26), (0, fy + 5, -6), RIDER),
		("box", (8, 26, 8), (-8, fy - 8, -18), RIDER),
		("box", (8, 26, 8), (8, fy - 8, -18), RIDER),
		("box", (9, 6, 9), (-8, fy - 2, -18), GOLD, {"metal": 0.8, "rough": 0.3}),
		("box", (9, 6, 9), (8, fy - 2, -18), GOLD, {"metal": 0.8, "rough": 0.3}),
		("box", (7, 22, 7), (-20, fy + 22, 0), RIDER, {"rot": (-30, 0, 0)}),
		("box", (7, 22, 7), (20, fy + 22, 0), RIDER, {"rot": (-30, 0, 0)}),
		("ball", (14, 15, 14), (0, fy + 46, 6), RIDER, {"subdiv": 1}),
		("ball", (2.6, 2.6, 2.6), (-3, fy + 47, -0.8), "FF2030", {"emit": 8, "subdiv": 1}),
		("ball", (2.6, 2.6, 2.6), (3, fy + 47, -0.8), "FF2030", {"emit": 8, "subdiv": 1}),
		("cone", (3, 22, 3), (-6, fy + 60, 8), BONE, {"seg": 5, "rot": (20, 0, -30)}),
		("cone", (3, 22, 3), (6, fy + 60, 8), BONE, {"seg": 5, "rot": (20, 0, 30)}),
		("box", (5, 70, 2), (26, fy + 30, -14), BLUE, {"emit": 8, "rot": (-20, 0, -10)}),
	]
	p.append(("cyl", (30, 900, 30), (0, top + 450, 0), "FFF4E0", {"seg": 10, "emit": 14}))
	p.append(("cyl", (80, 900, 80), (0, top + 450, 0), "FFC880", {"seg": 10, "emit": 2, "alpha": 0.25}))
	# Huge rusty chains with big links sagging diagonally in from anchors high off to the sides (webtoon_castle) and
	# biting into the upper faces; thinner chains cross the faces
	kw = {"L": 184, "W": 112, "t": 36}  # links about a quarter of the tower's width
	for a_, b_ in _chain_runs():
		_chain(p, a_, b_, 260, pitch=160, **kw)
		p.append(("cyl", (70, 34, 70), b_, RUST2, {"seg": 10, "metal": 0.5, "rot": (90, 90 - math.degrees(math.atan2(b_[2], b_[0])), 0)}))  # the bracket it bites
	for face in range(4):
		m = _rotm(0, face * 90, 0)
		for (x0, y0_), (x1, y1_) in (((-W / 2, 1180), (W / 2, 880)), ((-W / 2, 620), (W / 2, 900))):
			a_ = _turn(m, (x0 + 6, y0_, -W / 2 - 24))
			b_ = _turn(m, (x1 - 6, y1_, -W / 2 - 24))
			_chain(p, a_, b_, 30, pitch=30, L=34, W=20, t=6)
	k.prop("ChainTower", p)
	return top + 300


def _sheet(p, x, y0, z, w, h, rot=0, seed=0, n=3):
	"""A see-through orange-to-yellow flame sheet facing -Z (before turning `rot` about Y): one wide body, a ragged top
	of a few broad tapered tongues, and a paler core low down."""
	m = _rotm(0, rot, 0)
	o = {"rot": (0, rot, 0)}
	p.append(("box", (w, h * 0.6, 0.8), (x, y0 + h * 0.3, z), "FF6A14", dict(o, emit=2.5, alpha=0.22)))
	for i in range(n):
		r = (((i + seed) * 37) % 10) / 9
		th = h * (0.3 + 0.35 * r)
		off = _turn(m, (-w / 2 + w * (i + 0.5) / n, 0, -0.4))
		lean = (((i + seed) * 13) % 5 - 2) * 5
		p.append(("cone", (w / n * 1.25, th, 0.8), (x + off[0], y0 + h * 0.58 + th / 2, z + off[2]), ("FF8A20", "FFA030")[i % 2], dict(o, seg=4, taper=0.1, emit=3, alpha=0.26, rot=(0, rot, lean))))
	q = _turn(m, (0, 0, -0.9))
	p.append(("cone", (w * 0.7, h * 0.5, 0.8), (x + q[0], y0 + h * 0.25, z + q[2]), "FFD060", dict(o, seg=4, taper=0.35, emit=4, alpha=0.3)))


def _gate(k):
	"""Spans the road: tower inner faces 30 studs from the centre line, arch underside 28+ above the road. The runner
	comes from +Z. Low enough that its spires stay in the runner's frame."""
	p = []
	for sx in (-1, 1):
		x = sx * 44
		p.append(("box", (32, 8, 32), (x, 4, 0), SLATE))
		p.append(("box", (28, 70, 28), (x, 39, 0), STONE))
		for by in (24, 48):
			p.append(("box", (30, 2.4, 30), (x, by, 0), SLATE))
		for cz in (-1, 1):
			p.append(("box", (8, 56, 6), (x + sx * 14, 28, cz * 9), STONE3))
		p.append(("box", (34, 6, 34), (x, 77, 0), STONE2))
		for face in range(4):
			m = _rotm(0, face * 90, 0)
			for i in range(0, 8, 2):
				q = _turn(m, (-17 + 34 / 8 * (i + 0.5), 83, -16))
				p.append(("box", (4.2, 6, 3), (x + q[0], q[1], q[2]), STONE2, {"rot": (0, face * 90, 0)}))
		p.append(("cone", (26, 60, 26), (x, 116, 0), STONE3, {"seg": 8}))
		for px in (-1, 1):
			for pz in (-1, 1):
				p.append(("cone", (6, 22, 6), (x + px * 14, 97, pz * 14), STONE3, {"seg": 4, "rot": (0, 45, 0)}))
		p.append(("cyl", (1.4, 14, 1.4), (x, 152, 0), "45454E", {"seg": 6}))
		for wy in (30, 56):
			p.append(("box", (4, 9, 0.8), (x, wy, 14.3), FIRE, {"emit": 2}))
			p.append(("cone", (4, 3.6, 0.8), (x, wy + 6.3, 14.3), FIRE, {"seg": 4, "emit": 2}))
		_banner(p, (x, 74, 14.6), 26, 9, face=1)
		# heavy iron doors swung open toward the runner, hinged at the inner faces
		ang = math.radians(sx * 60)
		lc = (sx * 30 + math.sin(ang) * 12, 20, 14 + math.cos(ang) * 12)
		p.append(("box", (2.4, 40, 24), lc, "2A2A30", {"metal": 0.6, "rough": 0.5, "rot": (0, sx * 60, 0)}))
		for dy in (6, 20, 34):
			p.append(("box", (3, 2, 24), (lc[0], dy, lc[2]), "55555E", {"metal": 0.8, "rot": (0, sx * 60, 0)}))
		p.append(("ball", (2, 2, 2), (lc[0] - sx * 1.6, 20, lc[2]), "8A6A3A", {"metal": 0.9, "subdiv": 1}))
	for sx in (-1, 1):  # tall dark-red square pillars wrapped in fire flanking the gate (cerberus_gate)
		for px, ph, pz in ((76, 150, 6), (104, 190, -14)):
			x = sx * px
			p.append(("box", (18, 6, 18), (x, 3, pz), STONE3))
			p.append(("box", (14, ph, 14), (x, ph / 2, pz), "6A2418"))
			p.append(("box", (17, 5, 17), (x, ph + 2.5, pz), "4A160E"))
			for by in range(30, int(ph), 36):
				p.append(("box", (15, 2.4, 15), (x, by, pz), "4A160E"))
			for f_ in range(4):  # the base wrapped in flame on all four sides
				ang = math.radians(f_ * 90)
				_sheet(p, x + math.sin(ang) * 10, 0, pz - math.cos(ang) * 10, 26, ph * 0.4, f_ * 90, seed=f_ + px, n=2)
		# a dark-red lintel across each pillar pair
		_seg(p, (sx * 76, 138, 6), (sx * 104, 138, -14), 12, "5A1C12")
		_seg(p, (sx * 76, 146, 6), (sx * 104, 146, -14), 14, "4A160E")
	# a full wall of yellow-orange fire behind the arch (cerberus_gate): over the road it starts 14 up, beside the road
	# it rises from the ground, and it runs out behind the pillars
	_sheet(p, 0, 14, -34, 58, 62, 0, seed=1, n=3)
	for sx in (-1, 1):
		_sheet(p, sx * 46, 0, -36, 40, 80, 0, seed=2 + sx, n=2)
		_sheet(p, sx * 92, 0, -40, 66, 120, 0, seed=4 + sx, n=3)
	p.append(("box", (60, 20, 28), (0, 60, 0), STONE2))
	p.append(("box", (64, 3, 30), (0, 71.5, 0), SLATE))
	_merlons(p, 60, 3, 73, -13.5, 9, STONE2, 5)
	_merlons(p, 60, 3, 73, 13.5, 9, STONE2, 5)
	prev = None
	for i in range(9):
		t = i / 8
		pt = (30 * math.cos(t * math.pi / 2) ** 0.7, 28 + 22 * math.sin(t * math.pi / 2))
		if prev:
			mx, my = (pt[0] + prev[0]) / 2, (pt[1] + prev[1]) / 2
			ang = math.degrees(math.atan2(pt[1] - prev[1], pt[0] - prev[0]))
			ln = math.hypot(pt[0] - prev[0], pt[1] - prev[1]) + 1.5
			for sx in (-1, 1):
				p.append(("box", (ln, 5, 28), (sx * mx, my, 0), SLATE, {"rot": (0, 0, ang if sx > 0 else 180 - ang)}))
		prev = pt
	k.prop("Gate", p)


def _wyvern(k):
	"""Pale grey-white wyvern (kaisel_flight): long curved neck, a long narrow ridged skull (diamond-section snout with a
	centre ridge and brow ridges), long horns swept back along the neck and a second pair flared sideways, glowing red
	eyes; wings raised in a shallow V and pitched so their full near-black membranes read from the front, a finger spar
	fan with a scalloped trailing edge, spines down the back, a long tail with a spade. Rider (baran_anime, a changed
	design): purple armour, gold pauldrons, belt plates and knee plates, antler horns, a white flame mane, a purple tail
	and a blue blade raised forward. Faces -Z."""
	PALE, PALE2, MEM, MEM2 = "D4D8E2", "A8ACBA", "0C0A10", "151019"
	e3 = {"emit": 0.3}
	g = {"subdiv": 2, "smooth": True, "emit": 0.3}
	sl = {"emit": 0.3, "seg": 8}
	p = []
	# a sleek body of tapered eight-sided segments (chest, belly, hips) with ridged plates across the back and belly
	body = [((0, 2, -22), 10), ((0, 2.4, -12), 15), ((0, 1.4, 0), 15.5), ((0, 0.4, 10), 12), ((0, 0, 15), 8)]
	for (a_, ta), (b_, tb) in zip(body, body[1:]):
		_seg(p, a_, b_, ta, PALE, dict(sl, taper=tb / ta), "cyl")
	for i in range(8):
		z = -18 + i * 4.4
		w = 14 - abs(i - 3) * 1.4
		p.append(("box", (w * 0.8, 1.2, 3), (0, 9 - abs(i - 3) * 0.5, z), PALE2, dict(e3, rot=(8, 0, 0))))  # dorsal plates
		p.append(("box", (w * 0.7, 1.2, 3.4), (0, -6.4 + abs(i - 3) * 0.4, z), PALE2, dict(e3, rot=(-8, 0, 0))))  # belly plates
	neck = [((0, 2, -20), 9), ((0, 6, -27), 8), ((0, 11, -33), 7), ((0, 15.5, -39), 6)]
	for (a_, ta), (b_, tb) in zip(neck, neck[1:]):
		_seg(p, a_, b_, ta, PALE, dict(sl, taper=tb / ta), "cyl")
		mid = Vector(a_).lerp(Vector(b_), 0.5)
		_seg(p, mid, mid + Vector((0, 4, 1)), 2.2, PALE2, None, "cone", 0.1)  # neck spines
	# the long narrow ridged skull
	p.append(("ball", (7.4, 6.4, 12), (0, 16.4, -43), PALE, g))
	_seg(p, (0, 16, -46), (0, 12.2, -82), 6.0, PALE, dict(e3, seg=4), "cone", 1.0)  # long, narrow, tapering snout
	_seg(p, (0, 12.4, -45), (0, 10.4, -74), 3.8, PALE2, dict(e3, seg=4), "cone", 0.9)  # lower jaw
	_tri(p, (0, 22.5, -38), (0, 14, -81), (0, 16.6, -40), PALE2, 1.4, e3)  # centre ridge plate, crown to snout tip
	for sx in (-1, 1):
		_seg(p, (sx * 2.4, 17.4, -50), (sx * 1.1, 13.8, -76), 1.1, PALE2, e3)  # snout side ridges
	for sx in (-1, 1):
		_seg(p, (sx * 3.2, 18.6, -42), (sx * 1.8, 16.6, -54), 1.3, PALE2, e3)  # brow ridges
		p.append(("ball", (2, 1.2, 3.2), (sx * 3.1, 16.6, -48), "FF1A24", {"emit": 14, "subdiv": 1}))
		_seg(p, (sx * 2.4, 19.6, -41), (sx * 8, 31, -19), 2.8, PALE, e3, "cone", 0.2)  # long brow horns swept back and up, clear of the head
		_seg(p, (sx * 3.6, 18, -43), (sx * 20, 21, -30), 2.6, PALE, e3, "cone", 0.1)  # side horns flaring out sideways
		_seg(p, (sx * 3.6, 14.4, -46), (sx * 12, 12, -36), 1.6, PALE, e3, "cone", 0.1)  # cheek horns
		_seg(p, (sx * 3.2, 15, -39), (sx * 8, 13, -31), 1.2, PALE, e3, "cone", 0.1)
		for j in range(4):
			_seg(p, (sx * 2.2, 12.8, -48 - j * 2.6), (sx * 2.4, 11.2, -48.4 - j * 2.6), 0.8, "EEEEF4", None, "cone", 0.1)
		# hind legs tucked under
		p.append(("ball", (6, 8, 11), (sx * 6.5, -3, 9), PALE, g))
		_seg(p, (sx * 6.5, -6, 11), (sx * 6, -11, 18), 3, PALE, None, "cyl")
		for c in (-1, 0, 1):
			_seg(p, (sx * 6 + c, -11, 18), (sx * 6 + c * 1.6, -13, 21), 0.9, "2A2A30", None, "cone", 0.1)
		# wing: arm and four finger spars in a raised V, membrane pitched down toward the trailing edge
		S, E, W_ = Vector((sx * 6, 6, -10)), Vector((sx * 22, 16, -6)), Vector((sx * 36, 28, -12))
		F = [Vector((sx * 80, 46, -6)), Vector((sx * 76, 30, 16)), Vector((sx * 60, 16, 30)), Vector((sx * 38, 6, 34))]
		R = Vector((sx * 7, 2, 16))
		_seg(p, S, E, 3.8, PALE, e3, "cyl")
		_seg(p, E, W_, 3.2, PALE, e3, "cyl")
		p.append(("ball", (4.6, 4.6, 4.6), tuple(E), PALE, {"subdiv": 1}))
		p.append(("ball", (4.2, 4.2, 4.2), tuple(W_), PALE, {"subdiv": 1}))
		_seg(p, W_, W_ + Vector((-sx * 1, 6, -6)), 1.8, "EEEEF4", None, "cone", 0.1)  # thumb claw
		for i, f in enumerate(F):
			_seg(p, W_, f, 2.0 - i * 0.3, PALE2, None, "cyl", 0.6)
		edge = F + [R]
		for i in range(len(edge) - 1):
			a_, b_ = edge[i], edge[i + 1]
			notch = a_.lerp(b_, 0.5).lerp(W_, 0.12)
			_tri(p, W_, a_, notch, (MEM, MEM2)[i % 2], 1.0)
			_tri(p, W_, notch, b_, (MEM, MEM2)[i % 2], 1.0)
		_tri(p, W_, R, E, MEM, 1.0)
		_tri(p, E, R, S, MEM2, 1.0)
		_tri(p, S, E, W_ + Vector((0, 0, -2)), MEM, 0.8)
	for i in range(7):  # spines down the back
		z = -14 + i * 5
		_seg(p, (0, 6.5 - abs(i - 2) * 0.4, z), (0, 10.5 - i * 0.3, z + 3), 2, PALE2, None, "cone", 0.1)
	tail = [(0, 0, 14), (0, -1, 26), (0, -1.5, 38), (0, -1, 50), (0, 0.5, 61)]
	for i in range(1, len(tail)):
		_seg(p, tail[i - 1], tail[i], 7 - i * 1.4, PALE, {"emit": 0.3, "smooth": True}, "cyl", 6 - i * 1.4)
	_tri(p, (-5, 0.5, 60), (5, 0.5, 60), (0, 0.5, 70), PALE2, 0.8)
	# rider: seated astride the shoulders, about 1.3 times the wyvern's body height
	RD, RD2, GL = RIDER, "4E1E78", {"metal": 0.8, "rough": 0.3}
	y0, z0 = 8, -6
	for sx in (-1, 1):
		hip, knee, foot = (sx * 3, y0 + 3, z0), (sx * 9.6, y0 + 2, z0 - 5), (sx * 11, y0 - 4, z0 - 3)  # legs astride, clear of the flanks
		_seg(p, hip, knee, 3.4, RD, None, "cyl")
		_seg(p, knee, foot, 3, RD, None, "cyl")
		p.append(("box", (3.6, 3.6, 2.2), (knee[0], knee[1], knee[2] - 1.4), GOLD, GL))  # knee plate
		p.append(("box", (3, 2, 4.4), (foot[0], foot[1] - 1, foot[2] - 1), RD2))
		p.append(("box", (2.4, 3.6, 1), (sx * 2, y0 + 3.2, z0 - 3), GOLD, GL))  # fauld plates
	p += [
		("box", (7.6, 3.4, 5.4), (0, y0 + 4.4, z0), RD),
		("box", (8, 1.2, 5.8), (0, y0 + 6.4, z0), GOLD, GL),  # belt
		("box", (7.4, 6.4, 4.6), (0, y0 + 10, z0 + 0.4), RD),  # waist and chest
		("box", (9.4, 4.4, 5.2), (0, y0 + 14.4, z0 + 0.4), RD),
		("box", (5, 3, 0.8), (0, y0 + 11.6, z0 - 2), RD2),  # ab plates
		("box", (6.4, 2.4, 0.8), (0, y0 + 14.8, z0 - 2.3), GOLD, GL),  # chest trim
		("ball", (4.2, 5, 4.4), (0, y0 + 19.4, z0 + 0.2), RD, {"subdiv": 1}),  # head
		("box", (3.2, 1, 1), (0, y0 + 20.4, z0 - 2), "2A0E3A"),  # visor ridge
	]
	for sx in (-1, 1):
		p.append(("ball", (5.6, 4.2, 5.6), (sx * 5.8, y0 + 16.4, z0 + 0.4), GOLD, dict(GL, subdiv=1)))  # pauldrons
		_seg(p, (sx * 6.6, y0 + 17.6, z0 + 0.4), (sx * 8.6, y0 + 20.6, z0 + 1.4), 1.6, GOLD, GL, "cone", 0.1)
		p.append(("ball", (1, 0.8, 0.6), (sx * 1, y0 + 19.8, z0 - 2), "FF2030", {"emit": 12, "subdiv": 1}))
		# antler horns: up and out, a tine forward
		a0, a1, a2 = (sx * 1.4, y0 + 21.4, z0 + 0.4), (sx * 5, y0 + 26, z0 + 2), (sx * 10, y0 + 27, z0 + 5)
		_seg(p, a0, a1, 1.1, "3A2A44", None, "cyl", 0.8)
		_seg(p, a1, a2, 0.8, "3A2A44", None, "cone", 0.1)
		_seg(p, (sx * 4, y0 + 24.8, z0 + 1.6), (sx * 5.4, y0 + 28.4, z0 - 1.4), 0.6, "3A2A44", None, "cone", 0.1)
	# left arm down to the reins, right arm raised forward with the blade
	_seg(p, (-5.8, y0 + 15, z0 + 0.4), (-6.4, y0 + 9.6, z0 - 3), 2.6, RD, None, "cyl")
	_seg(p, (-6.4, y0 + 9.6, z0 - 3), (-3, y0 + 8, z0 - 8), 2.2, RD, None, "cyl")
	hand = Vector((7.6, y0 + 15, z0 - 9))
	_seg(p, (5.8, y0 + 15, z0 + 0.4), (8.4, y0 + 11, z0 - 4), 2.6, RD, None, "cyl")
	_seg(p, (8.4, y0 + 11, z0 - 4), hand, 2.2, RD, None, "cyl")
	p.append(("box", (2.6, 2.4, 2.6), tuple(hand), GOLD, GL))
	tip = hand + Vector((4, 26, -14))
	_tri(p, hand + Vector((-1.2, 0, 0)), hand + Vector((1.6, 1.2, 0.4)), tip, BLUE, 0.6, {"emit": 9})  # blade
	_tri(p, hand + Vector((-2.4, -0.6, 0.6)), hand + Vector((3, 1.4, 1.2)), hand + Vector((5, 24, -10)), "2A7CFF", 0.3, {"emit": 4, "alpha": 0.5})
	# a white flame mane about the size of the torso (baran_anime), streaming back and off to the rider's left behind
	# the antlers: layered flame plates, each with a side lobe for a flickering edge
	hb = Vector((0, y0 + 21, z0 + 2))
	MS = 2.0
	for i, (dx, up, back, w, ln) in enumerate((
		(-6, 8, 10, 7, 1.0), (-12, 10, 14, 7, 1.0), (-18, 6, 18, 6, 1.0), (-22, 0, 20, 5, 0.9), (-9, 14, 18, 6, 0.9),
		(-15, 13, 24, 5, 0.8), (-4, 4, 16, 6, 1.0), (3, 9, 8, 4, 0.8), (-24, 8, 26, 4, 0.7))):
		tip = hb + Vector((dx, up, back)) * ln * MS
		root = hb + Vector((dx * 0.1, 0, 1.5))
		wv = Vector((0.55 + (i % 3) * 0.2, 0.8, 0.2 * (i % 2))).normalized() * w * 0.8 * MS * 0.8  # plates at varied angles
		mid = root.lerp(tip, 0.5) + wv * 0.4
		_tri(p, root - wv * 0.5, root + wv * 0.5, mid, "F2F4FF", 0.6, {"emit": 3})
		_tri(p, mid - wv * 0.7, mid + wv * 0.5, tip, ("E6EAFF", "F8F8FF")[i % 2], 0.6, {"emit": 3})
		_tri(p, mid, mid + wv * 0.5, mid.lerp(tip, 0.4) + wv * 1.1, "DCE2FF", 0.6, {"emit": 3})  # flame lobe
	# purple tail curling down the wyvern's flank
	tl = [(0, y0 + 2, z0 + 3), (1.6, y0 - 1, z0 + 8), (3.4, y0 - 2, z0 + 14), (6.6, y0 - 4, z0 + 18), (9, y0 - 7, z0 + 19)]
	for i in range(1, len(tl)):
		_seg(p, tl[i - 1], tl[i], 2.6 - i * 0.4, RD, None, "cyl", 2.2 - i * 0.4)
	k.prop("Wyvern", p)


def _window_face(p, w, floors, fh, y0, cols, z, rot, x0=0.0, seed=0):
	"""A window grid on the face at local z (before turning by `rot` about Y); some panes blown out, some on fire."""
	m = _rotm(0, rot, 0)
	for f in range(floors):
		for c in range(cols):
			n = (f * 7 + c * 3 + seed) % 11
			if n == 0:
				continue
			col, o = (FIRE, {"emit": 2.2}) if n % 7 == 0 else ("F0A8D8", {"emit": 1.0}) if (f + seed) % 3 != 0 else (WIN, {})  # whole rows lit pale pink
			q = _turn(m, (x0 - w / 2 + w / cols * (c + 0.5), y0 + f * fh + fh * 0.55, z))
			p.append(("box", (w / cols * 0.55, fh * 0.55, 0.6), q, col, dict(o, rot=(0, rot, 0))))


def _rows(p, w, floors, fh, y0, z, rot, x0=0.0, seed=0):
	"""Lit window rows on a facade: one pale pink strip per floor (two of three lit), cheap for the back and sides."""
	m = _rotm(0, rot, 0)
	for f in range(floors):
		if (f + seed) % 3 == 0:
			continue
		for c in range(3):  # three small pale pink cells per floor
			q = _turn(m, (x0 - w / 3 + w / 3 * c, y0 + f * fh + fh * 0.55, z))
			p.append(("box", (w / 3 * 0.5, fh * 0.45, 0.6), q, "F0A8D8", {"emit": 1.0, "rot": (0, rot, 0)}))


def _billow(p, x, z, w, h, rot=0, seed=0, y0=0.0, dense=False):
	"""Pink fire as tall soft veils climbing a facade from the street (anime_castle2): a faint full-width veil, then
	overlapping translucent streak strips of ragged height in front of it; flat tops, no peaks."""
	m = _rotm(0, rot, 0)
	q = _turn(m, (x, y0 + h * 0.35, z))
	k_ = 1.8 if dense else 1.0  # road-facing facades get denser smoke-fire
	p.append(("box", (w, h * 0.7, 0.3), q, "E07AD8", {"emit": 1.2, "alpha": 0.12 * k_, "rot": (0, rot, 0)}))
	n = max(3, int(w / 5))
	for i in range(n):
		r = (((i + seed) * 37) % 10) / 9
		hh = h * (0.7 + 0.3 * r)
		dx = -w / 2 + w * (i + 0.5) / n
		sw = w / n * (0.9 + 0.4 * (((i + seed) * 13) % 3) / 2)
		q = _turn(m, (x + dx, y0 + hh / 2, z - 0.4))
		p.append(("box", (sw, hh, 0.3), q, "FF8AD8", {"emit": 1.4, "alpha": 0.13 * k_, "rot": (0, rot, 0)}))
		h2 = hh * 1.15
		q = _turn(m, (x + dx + sw * 0.3, y0 + h2 / 2, z - 0.8))
		p.append(("box", (sw * 0.5, h2, 0.3), q, "F0B0F0", {"emit": 1.2, "alpha": 0.1 * k_, "rot": (0, rot, 0)}))


def _ruins(k):
	# RuinA: two burning window-grid high-rises, pink-magenta fire billowing up between and around them
	p = [("box", (70, 3, 34), (0, 1.5, 0), CONC3)]
	for x, w, h, seed in ((-22, 26, 110, 1), (22, 24, 84, 3)):
		p.append(("box", (w, h, 24), (x, h / 2, 0), CONC))
		for f in range(1, int(h // 10)):
			p.append(("box", (w + 1, 1, 25), (x, f * 10, 0), CONC2))
		p.append(("box", (w * 0.6, 10, 24), (x - w * 0.2, h + 5, 0), CONC, {"rot": (0, 0, 8)}))
		_window_face(p, w, int(h // 10), 10, 0, 4, -12.1, 0, x0=x, seed=seed)
		for sd in (-1, 1):  # both sides (rot 90 maps local (a, y, c) to (c, y, -a))
			_rows(p, 24, int(h // 10), 10, 0, x + sd * (w / 2 + 0.1), 90, seed=seed + 2)
		_billow(p, x, -12.8, w * 1.02, h * 0.6, seed=seed + 2, dense=True)  # dense veils on the road-facing window face
		_billow(p, x, 12.8, w * 1.02, h * 0.45, seed=seed + 5)  # and the back
		side = -1 if x < 0 else 1  # the outer side face too (rot 90 maps local (a, y, c) to (c, y, -a))
		_billow(p, 0, x + side * (w / 2 + 0.8), 24, h * 0.5, rot=90, seed=seed + 4)
	k.prop("RuinA", p)
	# RuinB: collapsed low block, leaning slabs, broken columns, rubble and pink fire
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
	_rows(p, 46, 2, 10, 4, 19.1, 0, seed=1)
	_billow(p, 0, -11.4, 44, 24, seed=3, dense=True)  # on the front facade, from the rubble up
	k.prop("RuinB", p)
	# Chunk: an irregular rock slab floating in the air, ember cracks along its underside, small fire on top
	p = []
	for i, (sx, sy, sz, x, y, z, rx, ry, rz) in enumerate((
		(40, 9, 26, 0, 0, 0, 6, 0, 8),
		(26, 8, 20, 14, -5, 6, -8, 30, -12),
		(22, 10, 18, -14, -6, -4, 12, -20, 10),
		(14, 12, 12, 2, -12, 2, 20, 45, 15),
		(10, 9, 9, -4, -18, -2, -15, 10, 25),
	)):
		p.append(("box", (sx, sy, sz), (x, y, z), ("3A2A26", "2E2220", "44322C")[i % 3], {"rot": (rx, ry, rz)}))
		g = _turn(_rotm(rx, ry, rz), (0, -sy / 2 - 0.35, 0))  # ember-lit orange underside on every piece
		p.append(("box", (sx * 0.92, 0.6, sz * 0.92), (x + g[0], y + g[1], z + g[2]), "FF6A20", {"emit": 3.5, "rot": (rx, ry, rz)}))
	for x, z, ang, ln in ((-8, 0, 20, 22), (10, 4, -35, 16), (0, -6, 80, 14)):
		p.append(("box", (1.4, 0.6, ln), (x, -5.2, z), EMBER, {"emit": 5, "rot": (6, ang, 8)}))
	# a torn-off building slab in the cluster, its window grid lit
	bx, by, bz, br = 24, 2, -4, (8, 24, -10)
	mb = _rotm(*br)
	p.append(("box", (22, 14, 10), (bx, by, bz), CONC, {"rot": br}))
	g = _turn(mb, (0, -7.35, 0))
	p.append(("box", (20, 0.6, 9), (bx + g[0], by + g[1], bz + g[2]), "FF6A20", {"emit": 3.5, "rot": br}))
	for r_ in range(2):
		for c in range(4):
			g = _turn(mb, (-7.5 + c * 5, -2.6 + r_ * 5.4, -5.2))
			p.append(("box", (3, 3, 0.6), (bx + g[0], by + g[1], bz + g[2]), ("FFC2E6", WIN, "FFC2E6", FIRE)[(r_ + c) % 4], {"emit": 1.6 if (r_ + c) % 4 != 1 else 0.0, "rot": br}))
	k.prop("Chunk", p)
	# Smoke: a slab of smoke cloud
	p = []
	for i, (x, y, z, w, h, d) in enumerate(((0, 0, 0, 140, 24, 80), (60, 8, 20, 90, 30, 60), (-64, 6, -10, 100, 28, 70), (20, 18, -30, 80, 26, 50), (-20, -10, 24, 110, 20, 60))):
		p.append(("ball", (w, h, d), (x, y, z), ("3A2E30", "2E2428", "463638")[i % 3], {"subdiv": 1, "smooth": True}))
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
	# a brazier in front of the wall: stone post, iron bowl with claws, orange fire
	bz = -14
	p += [
		("box", (3.6, 2, 3.6), (14, 1, bz), SLATE),
		("box", (2.4, 9, 2.4), (14, 6.5, bz), STONE2),
		("cyl", (4.6, 1.8, 4.6), (14, 11.6, bz), "2A2A30", {"seg": 8, "taper": 1.4, "metal": 0.7}),
	]
	for a in range(4):
		r = math.radians(a * 90 + 45)
		p.append(("cone", (0.8, 3, 0.8), (14 + math.cos(r) * 2.6, 13, bz + math.sin(r) * 2.6), "45454E", {"seg": 4}))
	_flame(p, (14, 12.4, bz), 1.3, kind="tongue")
	k.prop("Rampart", p)
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



def _clearance(k, skip=("Road", "Wall", "Dash", "Apron", "WinPad", "Ground", "Fill", "Gate")):
	"""Print, per prop, the least distance from any corner of an instance's bounding box to the road centre line (a
	conservative check of the 24-stud rule; flying props are listed with their least height too)."""
	step = max(1, len(k.wps) // 1500)
	pts = [(w.x, w.z, w.y) for w in k.wps[::step]]
	out = {}
	for ob in k.col.objects:
		if ob.type != "MESH" or not ob.data.name.startswith("W2_"):
			continue
		name = ob.data.name.split("_")[-1]
		if name in skip:
			continue
		best = out.get(name, 1e9)
		for c in ob.bound_box:
			v = ob.matrix_basis @ Vector(c)  # matrix_world is stale until the depsgraph updates
			x, z = v.x, -v.y
			best = min(best, min(math.hypot(x - a, z - b) for a, b, _ in pts))
		out[name] = round(best, 1)
	print("CLEARANCE", out)


def _tower_ok(k, x, z, yaw):
	"""The plinth 340+ from the road, and each huge chain's ground track 40+ from it (24-stud rule, with margin)."""
	if _road_dist(k, x, z) < 340:
		return False
	c, s_ = math.cos(yaw), math.sin(yaw)
	for (ax, _, az), _b in _chain_runs():
		for i in range(1, 11):
			t = i / 10
			lx, lz = ax * t, az * t
			if _road_dist(k, x + lx * c - lz * s_, z + lx * s_ + lz * c) < 40:
				return False
	return True


def build(k):
	global EXTRA_SHOTS
	top = _chain_tower(k)
	_gate(k)
	_hound(k)
	_wyvern(k)
	_ruins(k)
	_castle_parts(k)

	gr = k.ground("2E2232", margin=12000)
	b = next(n for n in gr.data.materials[0].node_tree.nodes if n.type == "BSDF_PRINCIPLED")  # a faint ember glow, so the
	b.inputs["Emission Color"].default_value = (0.09, 0.03, 0.05, 1.0)  # far ground reads as land, not a black void
	b.inputs["Emission Strength"].default_value = 1.0
	_fill(k, "2A2530")
	L = k.length
	gates = (L * 0.06 + 230, L * 0.62 + 200)  # far enough ahead of the 6% and 62% cameras that the spires stay in frame
	skip = tuple((g - 110, g + 50) for g in gates)  # the hound statues stand on the approach, before the arch
	for g in gates:
		pos, yaw = k.beside(g, 0, 1.0)
		k.place("Gate", pos, yaw)
		for side in (-1, 1):  # the hound statues on the approach, facing the runner
			(x, _, z), hyaw = k.beside(g - 62, side * 84)  # 84: the flung arms and flared ears stay 24+ off the road
			k.place("Hound", (x, -1.0, z), hyaw + math.pi, 1.0)
	d = 20.0
	while d < L - 40:
		if not any(a <= d <= b for a, b in skip):
			for side in (-1, 1):
				(x, y, z), yaw = k.beside(d, side * 32, 0.9)
				if k.clear_of_road(x, z, 31):
					k.place("Edge", (x, y, z), yaw)
		d += 44
	_row(k, 44, (-48, 48), ["Rampart"], start=30, skip=skip)
	_row(k, 110, (-95, 95), ["RuinB"], start=60, jitter=20, skip=skip)
	_row(k, 120, (-170, 170), ["RuinA", "Crag"], start=20, jitter=24, scale=(0.8, 1.4))
	# The one castle: the spot (and turn) seen by the most fixed runner cameras, its chains and anchors clear of the road
	shots = _shots(k)
	best = None
	cx0, cz0 = (k.lo.x + k.hi.x) / 2, (k.lo.z + k.hi.z) / 2
	for i in range(-32, 33):
		for j in range(-32, 33):
			x, z = cx0 + i * 100, cz0 + j * 100
			if _road_dist(k, x, z) < 340:
				continue
			seen = [s for s in shots if _sees(s, x, z, HT, half=30.0, up=42.0)]
			if not seen:
				continue
			dmax = max(math.hypot(x - s[1][0], z - s[1][2]) for s in seen)
			score = (len(seen), -dmax)
			if best is None or score > best[0]:
				for yd in range(0, 90, 15):
					if _tower_ok(k, x, z, math.radians(yd)):
						best = (score, x, z, math.radians(yd), seen)
						break
	_, tx, tz, tyaw, seen = best
	ob = k.place("ChainTower", (tx, -1.0, tz), 0.0)
	ob.rotation_euler = (0, 0, -tyaw)  # Roblox yaw about Y turns +X toward +Z, Blender's about Z the other way
	print("CHAINTOWER at", (round(tx), round(tz)), "seen by shots", [s[0] for s in seen])
	# Review shot: from the runner's lane where the road heads most straight at the tower
	pick = None
	d = 60.0
	while d < L - 60:
		if not any(a - 60 <= d <= b for a, b in skip):
			p, right, t = k.at(d)
			lane = p + right * 10
			vx, vz = tx - lane.x, tz - lane.z
			dist = math.hypot(vx, vz)
			ang = math.degrees(math.acos(max(-1.0, min(1.0, (vx * t.x + vz * t.z) / dist))))
			if 1300 < dist < 2600 and (pick is None or ang < pick[0]):
				pick = (ang, d)
		d += 20
	p, right, t = k.at(pick[1])
	eye = p + right * 10 - t * 14
	EXTRA_SHOTS = [("06_castle", (eye.x, p.y + 8.5, eye.z), (tx, 520.0, tz))]
	print("EXTRA 06_castle at", round(pick[1] / L, 2), "of the track,", round(pick[0]), "deg off the road heading")
	k.field(40, ["RuinA", "RuinB", "RuinA"], clearance=150, margin=700, scale=(1.0, 2.2))
	k.field(20, ["Crag"], clearance=110, margin=800, scale=(1.2, 3.0))
	p5, r5, t5 = k.at(L * 0.48)  # build_track's raised side camera (05_side): keep scatter out of its near frame
	e5 = (p5.x + r5.x * 140 - t5.x * 60, p5.z + r5.z * 140 - t5.z * 60)
	for ob in list(k.col.objects):  # keep the plinth, chains and anchors clear of the scatter
		if ob.type == "MESH" and ob.data.name.split("_")[-1] in ("RuinA", "RuinB", "Crag"):
			lx, lz = ob.location.x, -ob.location.y
			if math.hypot(lx - tx, lz - tz) < 360 or math.hypot(lx - e5[0], lz - e5[1]) < 120:
				bpy.data.objects.remove(ob)
				k.instances -= 1
	# Floating burning rock slabs and smoke clouds, never above the road
	for name, n, lo_y, hi_y, sc in (("Chunk", 50, 60, 260, (0.8, 1.9)), ("Smoke", 12, 450, 800, (0.8, 1.4))):
		placed, tries = 0, 0
		while placed < n and tries < 3000:
			tries += 1
			x, z = k.rng.uniform(k.lo.x - 900, k.hi.x + 900), k.rng.uniform(k.lo.z - 900, k.hi.z + 900)
			if k.clear_of_road(x, z, 80 if name == "Chunk" else 400) and math.hypot(x - tx, z - tz) > 400:
				k.place(name, (x, k.rng.uniform(lo_y, hi_y), z), k.rng.uniform(0, math.tau), k.rng.uniform(*sc))
				placed += 1
	# Wyverns: two crossing the 33% run shot's sky, four circling the castle top
	p, right, t = k.at(L * 0.33)
	for D, off, y, sc in ((190, -110, 70, 1.4), (380, 100, 135, 1.7)):
		x, z = p.x + t.x * D + right.x * off, p.z + t.z * D + right.z * off
		k.place("Wyvern", (x, p.y + y, z), math.atan2(-right.x, -right.z) + 0.5, sc)
	for i in range(4):
		a = i * math.tau / 4 + 0.4
		r = 420 + i * 70
		k.place("Wyvern", (tx + math.cos(a) * r, HT * (0.72 + 0.08 * i), tz + math.sin(a) * r), -a + math.pi, 5.0)
	# Purple-black sky down to an ember-orange horizon; below it the ground colour, so the ground plane's far edge melts in
	k.sky([(-0.012, "2E2232"), (0.0, "FF7A2A"), (0.04, "C0442A"), (0.12, "6A2038"), (0.3, "2A0E2E"), (1.0, "08040C")], strength=0.9, sun=(2.2, "FFD0B0", 22, 210))
	k.light((tx, 300, tz), "FF7A2A", energy=9000000, radius=160)
	k.light((tx, HT + 120, tz), "FFE0C0", energy=2500000, radius=40)
	for g in gates:
		pos, _ = k.beside(g + 40, 0, 16)  # fire glow beyond the arch
		k.light(pos, "FF7A2A", energy=150000, radius=12)
	d = 40
	while d < L:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, "FF9A6A", energy=45000, radius=6)
		d += 160
	for f in (0.33,):  # the stair climb ahead of the 33% camera is the road deck in its own shadow: light it
		pos, _ = k.beside(L * f + 30, 0, 22)
		k.light(pos, "FF9A6A", energy=90000, radius=10)
	counts = {}
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.data.name.startswith("W2_"):
			key = ob.data.name.split("_")[-1]
			counts[key] = counts.get(key, 0) + 1
	print("PERPROP", counts)
	_clearance(k)
