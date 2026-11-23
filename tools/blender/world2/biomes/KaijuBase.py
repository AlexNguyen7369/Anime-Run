"""World 2 Track 5: Kaiju Base (Kaiju No. 8). Rebuilt 2026-11-23 for a closer 1-1 read of the source (owner: "more detail
and closer reference to source material"; round 2 after the reference review). Landmarks and their references:
docs/world2_refs/KaijuBase.md.
First half: a kaiju-wrecked Tokyo district under a clear blue sky with cumulus clouds: a street grid of wrecked low-rise
blocks with craters, balconied apartment blocks and office towers with collapsed corners and scorch marks (some
leaning), smoke columns, varied rubble and wrecked cars. A giant kaiju corpse lies across the blocks and the Monster
Sweeper crews clean it up (white hooded suits on ropes, a stake-and-rope line along its back, ropes hanging from teal
lattice gantries, a craggy rock-ridge back; white vans with roof racks and crews sitting on top). Second half:
the Defense Force's Tachikawa base (low perimeter wall, the wide symmetric white HQ with its central glass tower, end
pavilions and parking lot, the observation tower beside it, hangars with armoured vehicles, the anti-kaiju rail cannon
lying low on its long rail bed).
Rules (design doc 5, WORLD2_SPEC): in-house primitives only; no text and no real insignia (the base badge is an
invented orange diamond, the sweeper vans carry a plain red band); the corpse is intact or bare bone, no wounds.
Props 24+ studs from the centre line. Budget: 12 unique meshes (road pieces excluded). Clouds are sky dressing (the
game's Sky), not prop assets.
Frames: a viewer in front of a prop (looking +Z) sees local +X on the left.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import kit

DUST, ASH, CONC, CONC2, RUST = "8C877C", "4A4A4C", "C8C2B6", "8A9098", "8A5A3A"
ROCK, WINDOW, GLASS, SCORCH = "5C5650", "2A3440", "6E8EAA", "2A2624"
FLESH, FLESH2, FLESH3, PLATE, BONE, BONE2 = "8A4A3A", "6E3A2E", "9C5A44", "5A4A4A", "E6DCC4", "C8BCA0"
HIDE, HIDE2 = "86402F", "5A2419"  # red-brown kaiju hide and its ink-dark shadow streaks
SUIT, TEAL, ROPE_Y, ROPE_B = "F4F4F0", "2F7F7A", "E8C840", "2E6FD0"
BASE, BASE2, STRIPE, NAVY, OLIVE = "ECECE6", "A8AEB4", "FF8A1E", "2E3E58", "4A5240"
ASPHALT, WALK = "3A3A3E", "A8A49C"

CTURN_DEG = -40.0  # the first corpse turns so run shots 1 and 4 see its flank (see build: layout)
CLEAR_EXEMPT = {"Pier"}  # supports under the raised road
MODEL_SHOTS = ["KaijuCorpse", "Railgun", "DefenseHQ", "SweeperVan"]  # hero models rendered close up for review

def bx(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def seg(p, a, b, col, thick=0.5, wide=None):
	"""A straight member (cable, rope) from point a to point b, as a thin box along its length."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rz = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
	ry = math.degrees(math.atan2(-dz, dx))
	bx(p, (ln, thick, wide or thick), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), col, rot=(0, ry, rz))


def cab(p, a, b, col, thick=0.5):
	"""A thin cable piece from a to b: a 3-sided cylinder (8 tris, a box is 12), oriented like seg()."""
	dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
	ln = math.sqrt(dx * dx + dy * dy + dz * dz)
	rz = math.degrees(math.atan2(dy, math.hypot(dx, dz)))
	ry = math.degrees(math.atan2(-dz, dx))
	p.append(("cyl", (thick, ln, thick), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), col, {"seg": 3, "rot": (0, ry, rz - 90)}))


def turn(p, n0, x0, z0, deg):
	"""Turns parts p[n0:] by `deg` about the Y axis through (x0, z0): -90 turns a -Z-facing figure to face +X."""
	c, s_ = math.cos(math.radians(deg)), math.sin(math.radians(deg))
	for i in range(n0, len(p)):
		shape, size, (px, py, pz), col, o = p[i]
		dx, dz = px - x0, pz - z0
		rx, ry, rz = o.get("rot", (0, 0, 0))
		p[i] = (shape, size, (x0 + dx * c + dz * s_, py, z0 + dz * c - dx * s_), col, {**o, "rot": (rx, ry + deg, rz)})


def worker(p, x, y, z, s=1.0, sit=False, lean=0, crossed=False, face=0, lo=False):
	"""A Monster Sweeper in a loose white suit, facing -Z (turned by `face` degrees): a rounded, loose hood round a plain
	face, dark goggles, a white respirator with a round side filter, harness straps and belt, a tall green pack, baggy
	rounded arms and legs. lo: a coarser hood and box gloves for small figures (tri budget)."""
	n0 = len(p)
	sm = {"smooth": True}
	p.append(("cyl", (2.3 * s, 2.8 * s, 1.9 * s), (x, y + 2.8 * s, z), SUIT, {"seg": 12, "rot": (lean, 0, 0), "taper": 0.8, **sm}))  # loose suit
	p.append(("ball", (2.5 * s, 1.0 * s, 2.0 * s), (x, y + 4.1 * s, z), SUIT, {"subdiv": 1, **sm}))  # shoulders
	p.append(("ball", (2.5 * s, 2.5 * s, 2.4 * s), (x, y + 5.0 * s, z + 0.2 * s), SUIT, {"subdiv": 1 if lo else 2, **sm}))  # rounded loose hood
	p.append(("cyl", (1.9 * s, 0.35 * s, 1.9 * s), (x, y + 4.9 * s, z - 0.95 * s), "E4E4DE", {"rot": (90, 0, 0), "seg": 8 if lo else 14, **sm}))  # hood rim
	bx(p, (1.15 * s, 1.3 * s, 0.3 * s), (x, y + 4.95 * s, z - 1.1 * s), "D9A882")  # face
	bx(p, (1.25 * s, 0.38 * s, 0.25 * s), (x, y + 5.25 * s, z - 1.27 * s), "16181C")  # dark goggles band
	p.append(("ball", (0.95 * s, 0.65 * s, 0.6 * s), (x, y + 4.55 * s, z - 1.35 * s), "EDEDE8", {"subdiv": 1}))  # white respirator
	p.append(("cyl", (0.75 * s, 0.3 * s, 0.75 * s), (x + 0.62 * s, y + 4.55 * s, z - 1.3 * s), "C8CCD0", {"rot": (0, 0, 90), "seg": 10}))  # round side filter
	for side in (-1, 1):
		bx(p, (0.3 * s, 2.6 * s, 0.15 * s), (x + side * 0.55 * s, y + 3.0 * s, z - 0.95 * s), "2A2A2E")  # harness straps
	bx(p, (2.3 * s, 0.35 * s, 1.95 * s), (x, y + 1.7 * s, z), "2A2A2E")  # belt
	bx(p, (1.7 * s, 4.4 * s, 1.15 * s), (x, y + 3.9 * s, z + 1.45 * s), "5A6A44")  # tall green pack
	bx(p, (1.5 * s, 0.5 * s, 1.05 * s), (x, y + 6.2 * s, z + 1.45 * s), "4A5838")
	hose = ((x + 0.85 * s, y + 2.2 * s, z + 1.7 * s), (x + 1.55 * s, y + 1.2 * s, z + 0.7 * s), (x + 1.15 * s, y + 1.75 * s, z - 0.3 * s))
	for a_, b_ in zip(hose, hose[1:]):  # teal hose looping from the pack to the hip
		seg(p, a_, b_, "2E9A96", thick=0.28 * s)
	if crossed:  # arms folded across the chest
		bx(p, (2.3 * s, 0.75 * s, 0.85 * s), (x, y + 3.4 * s, z - 1.05 * s), SUIT)
	for side in (-1, 1):
		if not crossed:
			p.append(("cyl", (0.8 * s, 2.5 * s, 0.8 * s), (x + side * 1.35 * s, y + 3.0 * s, z - 0.3 * s), SUIT, {"seg": 8, "rot": (-25, 0, side * 12), "taper": 0.8, **sm}))  # baggy arm
			if lo:
				bx(p, (0.6 * s, 0.6 * s, 0.6 * s), (x + side * 1.5 * s, y + 1.85 * s, z - 0.85 * s), "8A9098")  # glove
			else:
				p.append(("ball", (0.7 * s, 0.7 * s, 0.7 * s), (x + side * 1.5 * s, y + 1.85 * s, z - 0.85 * s), "8A9098", {"subdiv": 1}))  # glove
		if sit:
			p.append(("cyl", (0.9 * s, 2.4 * s, 0.9 * s), (x + side * 0.5 * s, y + 1.0 * s, z - 1.2 * s), SUIT, {"seg": 8, "rot": (90, 0, 0), **sm}))
		else:
			p.append(("cyl", (1.0 * s, 2.4 * s, 1.0 * s), (x + side * 0.5 * s, y + 0.6 * s, z), SUIT, {"seg": 8, "taper": 0.85, **sm}))  # baggy leg
			bx(p, (0.85 * s, 0.5 * s, 1.25 * s), (x + side * 0.5 * s, y - 0.45 * s, z - 0.15 * s), "4A4E56")  # boots
	if face:
		turn(p, n0, x, z, face)


def sitter(p, x, y, z, s=1.0, face=0, pose=0):
	"""An off-duty Monster Sweeper sitting slouched on the van rack (sweeper_members), facing -Z (turned by `face`
	degrees), y at the seat: white suit with the hood down, no pack. pose 0: knees up, forearms on the knees; 1: legs out,
	leaning back on the hands; 2: one knee up, an arm on it; 3: cross-legged and hunched."""
	n0 = len(p)
	sm = {"smooth": True}
	tilt = (-14, 16, -8, -24)[pose]
	p.append(("cyl", (2.2 * s, 2.8 * s, 1.8 * s), (x, y + 1.9 * s, z + 0.3 * s), SUIT, {"seg": 8, "rot": (tilt, 0, 0), "taper": 0.85, **sm}))  # torso
	p.append(("ball", (2.4 * s, 1.2 * s, 1.5 * s), (x, y + 3.15 * s, z + 0.75 * s), "E4E4DE", {"subdiv": 1, **sm}))  # hood down, bunched behind the neck
	p.append(("ball", (1.6 * s, 1.8 * s, 1.7 * s), (x, y + 3.9 * s, z - 0.3 * s), "D9A882", {"subdiv": 1, **sm}))  # head
	hair = ("1E1C1E", "5A3A22", "C2622A", "8E969C")[pose]  # black spiky, brown, orange spiky, grey beanie (sweeper_members)
	if pose == 3:
		p.append(("ball", (1.75 * s, 1.6 * s, 1.8 * s), (x, y + 4.45 * s, z - 0.15 * s), hair, {"subdiv": 1, **sm}))  # beanie
	else:
		p.append(("ball", (1.7 * s, 0.8 * s, 1.8 * s), (x, y + 4.6 * s, z - 0.1 * s), hair, {"subdiv": 1}))  # hair
		if pose in (0, 2):
			for q in range(4):  # spikes
				p.append(("cone", (0.6 * s, 1.0 * s, 0.6 * s), (x + (q - 1.5) * 0.4 * s, y + 5.0 * s, z + (0.4 - (q % 2) * 0.6) * s), hair, {"seg": 4, "rot": ((q % 2) * 30 - 15, 0, (q - 1.5) * 18)}))
	for side in (-1, 1):
		hip = (x + side * 0.55 * s, y + 0.5 * s, z)
		up_knee = (x + side * 0.6 * s, y + 1.7 * s, z - 2.0 * s), (x + side * 0.6 * s, y + 0.3 * s, z - 2.7 * s)
		flat_leg = (x + side * 0.6 * s, y + 0.5 * s, z - 1.8 * s), (x + side * 0.65 * s, y + 0.4 * s, z - 3.4 * s)
		crossed = (x + side * 1.5 * s, y + 0.7 * s, z - 1.3 * s), (x - side * 0.5 * s, y + 0.3 * s, z - 1.7 * s)
		knee, foot = (up_knee, flat_leg, up_knee if side < 0 else flat_leg, crossed)[pose]
		sh = (x + side * 1.1 * s, y + 3.0 * s, z - 0.1 * s)
		hand = (knee[0] + side * 0.1 * s, knee[1] + 0.2 * s, knee[2] + 0.1 * s)  # on the knee
		if pose == 1 or (pose == 2 and side > 0):
			hand = (x + side * 1.3 * s, y + 0.3 * s, z + 1.6 * s)  # leaning back on the hand
		seg(p, hip, knee, SUIT, thick=1.0 * s)  # thigh
		seg(p, knee, foot, SUIT, thick=0.9 * s)  # shin
		bx(p, (0.8 * s, 0.5 * s, 1.1 * s), (foot[0], foot[1] - 0.1 * s, foot[2] - 0.3 * s), "4A4E56")  # boot
		seg(p, sh, hand, SUIT, thick=0.75 * s)  # arm
	if face:
		turn(p, n0, x, z, face)


def lounger(p, x, y, z, s=1.0):
	"""An off-duty Monster Sweeper lying flat on his front along Z on the van rack (sweeper_members), head forward (-Z)
	resting on his folded arms on the rack rail; y at his front, z at his chest. Hood down, no pack."""
	sm = {"smooth": True}
	bx(p, (2.0 * s, 1.1 * s, 3.2 * s), (x, y + 0.55 * s, z + 0.4 * s), SUIT)  # torso, flat
	bx(p, (1.8 * s, 0.9 * s, 1.4 * s), (x, y + 0.5 * s, z + 2.6 * s), SUIT)  # hips
	p.append(("ball", (2.0 * s, 0.9 * s, 1.6 * s), (x, y + 1.1 * s, z - 0.7 * s), "E4E4DE", {"subdiv": 1, **sm}))  # hood down
	for side in (-1, 1):
		bx(p, (0.85 * s, 0.8 * s, 3.4 * s), (x + side * 0.5 * s, y + 0.4 * s, z + 4.9 * s), SUIT)  # straight legs
		bx(p, (0.8 * s, 0.6 * s, 0.6 * s), (x + side * 0.5 * s, y + 0.45 * s, z + 6.8 * s), "4A4E56")  # boots
	bx(p, (2.6 * s, 0.6 * s, 0.9 * s), (x, y + 0.3 * s, z - 2.0 * s), SUIT)  # arms folded under the chin
	p.append(("ball", (1.5 * s, 1.5 * s, 1.6 * s), (x, y + 1.1 * s, z - 2.1 * s), "D9A882", {"subdiv": 1, **sm}))  # head
	p.append(("ball", (1.6 * s, 0.8 * s, 1.5 * s), (x, y + 1.7 * s, z - 1.9 * s), "2A2420", {"subdiv": 1}))  # hair


def lying(p, x, y, z, s=1.0, lo=False, pack=True):
	"""A Monster Sweeper lying on his back along Z (head to -Z), y at his back: loose suit, hood, goggles, pack under."""
	if pack:
		bx(p, (1.7 * s, 1.0 * s, 4.0 * s), (x, y + 0.5 * s, z + 0.4 * s), "5A6A44")  # pack under the back
	p.append(("cyl", (2.3 * s, 3.0 * s, 1.8 * s), (x, y + 1.6 * s, z + 0.6 * s), SUIT, {"seg": 12, "rot": (90, 0, 0), "smooth": True}))
	p.append(("ball", (2.4 * s, 2.2 * s, 2.4 * s), (x, y + 1.7 * s, z - 1.9 * s), SUIT, {"subdiv": 1 if lo else 2, "smooth": True}))  # hood
	bx(p, (1.1 * s, 0.6 * s, 1.2 * s), (x, y + 2.55 * s, z - 2.0 * s), "D9A882")  # face up, set into the top of the hood
	bx(p, (1.2 * s, 0.25 * s, 0.38 * s), (x, y + 2.86 * s, z - 2.3 * s), "16181C")  # goggles
	for side in (-1, 1):
		p.append(("cyl", (1.0 * s, 2.6 * s, 0.9 * s), (x + side * 0.55 * s, y + 1.1 * s, z + 3.3 * s), SUIT, {"seg": 8, "rot": (90, 0, 0), "smooth": True}))  # legs
		p.append(("cyl", (0.75 * s, 2.4 * s, 0.75 * s), (x + side * 1.4 * s, y + 1.5 * s, z - 0.6 * s), SUIT, {"seg": 8, "rot": (90, 0, side * 20), "smooth": True}))  # arms behind the head


def car(p, x, z, col, yaw=0, state=0):
	"""state 0 parked, 1 crushed flat, 2 flipped onto its side."""
	if state == 2:
		bx(p, (2.6, 7, 14), (x, 2.5, z), col, rot=(0, yaw, 0))
		bx(p, (2.2, 6.2, 7.5), (x - 2.3, 2.5, z + 0.5), "34404E", rot=(0, yaw, 0))
		bx(p, (0.8, 7.2, 14.2), (x + 1.6, 2.5, z), "1A1A1A", rot=(0, yaw, 0))
		return
	h = 0.5 if state == 1 else 1.0
	bx(p, (7, 2.4 * h, 14), (x, 1.4 * h - 1, z), col, rot=(0, yaw, 0))
	bx(p, (6.2, 2.2 * h, 7.5), (x, 3.6 * h - 1, z + 0.5), "34404E", rot=(0, yaw, 0), rough=0.2)
	bx(p, (7.2, 0.8, 14.2), (x, 0.0, z), "1A1A1A", rot=(0, yaw, 0))


def supports(k, color):
	"""Concrete piers under raised road (the climbs), so it never floats."""
	k.prop("Pier", [("box", (10, 1, 10), (0, -0.5, 0), color), ("box", (12, 0.4, 12), (0, -0.2, 0), "4A4E56")])
	d = 0.0
	while d < k.length:
		p, _, _ = k.at(d)
		if p.y > 3:
			pos, yaw = k.beside(d, 0)
			ob = k.place("Pier", (pos[0], p.y - 0.5, pos[2]), yaw)
			ob.scale = (1, 1, p.y + 0.5)
		d += 24


def put(k, name, d, off, scale=1.0, clear=None, turn=0.0):
	"""One prop on the ground at distance d, `off` studs right (negative left) of the centre line, -Z to the road."""
	pos, yaw = k.beside(d, off)
	if not k.clear_of_road(pos[0], pos[2], abs(off) - 1 if clear is None else clear):  # no other lap of road nearer
		return None
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	return k.place(name, (pos[0], -1.0, pos[2]), yaw + turn, scale)


def row(k, a, b, every, offsets, names, jitter=0.0, scale=(1.0, 1.0), skip=(), turn=0.0, chance=1.0, lean=0.0):
	"""Props along the road. turn: random extra yaw up to +-turn; chance: share of spots filled; lean: share tilted."""
	d = a
	while d < b:
		if not any(s0 <= d <= s1 for s0, s1 in skip):
			for off in offsets:
				if k.rng.random() > chance:
					continue
				o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
				ob = put(k, k.rng.choice(names), d + k.rng.uniform(-jitter, jitter), o, k.rng.uniform(*scale), turn=k.rng.uniform(-turn, turn))
				if ob and k.rng.random() < lean:
					ob.rotation_euler[0] = math.radians(k.rng.choice((-1, 1)) * k.rng.uniform(3, 6))
					ob.location.z -= 2.0
		d += every


def local(k, d, off, lx, lz):
	"""World (x, z) of a point (lx, lz) in the frame of a prop placed by put(k, _, d, off)."""
	pos, yaw = k.beside(d, off)
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	v = Matrix.Rotation(yaw, 3, "Z") @ Vector((lx, -lz, 0))  # Blender frame: Roblox z is Blender -y
	return pos[0] + v.x, pos[2] - v.y, yaw


def shot_eye(k, f):
	"""Eye, forward and right of build_track's runner shot at fraction f (same maths as build_track.shots)."""
	p, right, t = k.at(k.length * f)
	return p + right * 10 - t * 14, t, right


HULL = "86402E"  # the torso hide masses (own material: their faces are repainted with the band and ink shadows)
MYC = 50.0  # hide mass centre height: the masses sink below the ground, so the flank rises as a steep wall
MASSES = [(-150, 110, 115, 62), (-30, 130, 145, 72), (95, 120, 135, 70), (190, 92, 82, 56)]  # x, rx, ry, rz
BAND = ("B2A290",)  # grey-beige pale band
CRAG = ("D2AC8C", "C8A080", "DCB898", "BE9474", "D6B092")  # ridge crags: pale tan against the sky (sweeper_cleaning2)
CRAG_TOP = "E6CCB0"  # lighter top faces of the ridge crags
INK = ("3E1410", "34100C", "481812")  # dark red-brown ink shadows


def corpse_z(x, y):
	"""Road-side (-Z) surface of the merged torso at (x, y): the outermost hide mass there (0 off the torso)."""
	z = 0.0
	for hx, rx, ry, rz in MASSES:
		u = 1 - ((x - hx) / rx) ** 2 - ((y - MYC) / ry) ** 2
		if u > 0:
			z = min(z, -rz * math.sqrt(u))
	return z


def corpse_top(x):
	"""Top silhouette of the merged torso at x."""
	return max([MYC + ry * math.sqrt(1 - ((x - hx) / rx) ** 2) for hx, rx, ry, rz in MASSES if abs(x - hx) < rx] or [20.0])


def corpse_band_top(rnd):
	"""Ragged top edge of the pale band (lower ~38% of the flank) as a function of x."""
	rag = [rnd.uniform(-9, 9) + (rnd.choice((-20, 0, 0, 0, 14))) for _ in range(40)]

	def band_top(x):
		f = (x + 300) / 17.0
		i = max(0, min(len(rag) - 2, int(f)))
		return 0.38 * corpse_top(x) + rag[i] + (rag[i + 1] - rag[i]) * (f - i)

	return band_top


def on_hide(p, shape, size, x, y, up, col, off=0.45, **o):
	"""A thin flat part centred on the flank at (x, y): its local Y axis (a cone's axis) runs along `up` (an (x, y)
	direction in the flank), its thin local Z axis along the hide's outward normal, `off` studs out."""
	gx = (corpse_z(x + 1, y) - corpse_z(x - 1, y)) / 2
	gy = (corpse_z(x, y + 1) - corpse_z(x, y - 1)) / 2
	n = kit.rb(gx, gy, -1).normalized()  # outward (road-side) normal, Blender frame
	d = kit.rb(up[0], up[1], gx * up[0] + gy * up[1])
	d = (d - n * d.dot(n)).normalized()
	e = Matrix((n.cross(d), n, d)).transposed().to_euler("YXZ")  # columns: Blender X, Y (= thin), Z (= axis)
	p.append((shape, size, (x, y, corpse_z(x, y) - off), col, {"rot": (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y)), **o}))


def ink_tongues(p, rnd, band_top):
	"""Ink shadows (sweeper_cleaning1): few, long flame tongues in parallel diagonal rows, all leaning the same way,
	broad at the base and pointed at the top, near-black red-brown, about 40% of the flank. Each tongue is a chain of
	4 flat tapering plates lying just off the hide, so it follows the curved flank. No closed or curved shapes."""
	slant = 34.0
	up = (math.sin(math.radians(slant)), math.cos(math.radians(slant)))
	for hx, rx, ry, rz in MASSES:
		for row_ in range(2):  # a lower and an upper row, the upper one offset by half a step
			x = hx - rx * 0.85 + row_ * 13 + rnd.uniform(-4, 4)
			while x < hx + rx * 0.75:
				y0 = band_top(x) + rnd.uniform(0, 12) + row_ * 58
				L, w = rnd.uniform(110, 170), rnd.uniform(20, 28)
				col = rnd.choice(INK)
				for q in range(4):
					f0, f1 = q / 4, (q + 1) / 4
					px, py = x + up[0] * L * (f0 + f1) / 2, y0 + up[1] * L * (f0 + f1) / 2
					if corpse_z(px, py) > -25 or py > corpse_top(px) - 6:
						break  # only on the flank: off the torso edge a piece would stick out as a spike
					w0, w1 = w * (1 - f0) ** 1.5 + 0.4, w * (1 - f1) ** 1.5 + 0.4  # flame taper: broad base, long point
					on_hide(p, "cone", (w0, L / 4 + 1.0, 0.3), px, py, up, col, seg=4, taper=w1 / w0)
				x += rnd.uniform(30, 40)


def band_edge(p, rnd, band_top):
	"""The pale band's ragged top edge (sweeper_cleaning2): pointed hide-red tongues of mixed width and depth dip down
	into the band, with a dark shadow sliver along one flank of some, and band-coloured shards point up into the hide
	between them, so the edge never runs level. HIDE is its own material, so corpse_paint leaves the tongues red."""
	x = -236.0
	while x < 250:
		w = rnd.uniform(7, 26)
		cx = x + w / 2
		top = band_top(cx) + rnd.uniform(-4, 6)
		if corpse_z(cx, top) < -20:
			h = rnd.uniform(14, 40)  # hide tongue pointing down into the band
			tilt = rnd.uniform(-0.35, 0.35)
			on_hide(p, "cone", (w, h, 0.3), cx, top - h / 2 + 4, (tilt, -1), HIDE, off=0.45, seg=3)
			if rnd.random() < 0.5:
				on_hide(p, "cone", (w * 0.35, h * 0.8, 0.3), cx + w * 0.3, top - h * 0.45 + 3, (tilt, -1), "3A1A12", off=0.5, seg=3)
			if rnd.random() < 0.6:  # band shard pointing up into the hide
				h2 = rnd.uniform(10, 26)
				on_hide(p, "cone", (w * rnd.uniform(0.5, 0.9), h2, 0.3), x + w + rnd.uniform(-2, 2), top + h2 / 2 - 4, (rnd.uniform(-0.3, 0.3), 1), BAND[0], off=0.42, seg=3)
		x += w * rnd.uniform(0.9, 1.3)


def corpse_paint(k, ob, band_top):
	"""Paints the pale band onto the torso's own faces, so it lies exactly in the hide as one flat grey-beige area with
	a ragged top edge (sweeper_cleaning2); lightens only the top faces of the ridge rocks; drops hide faces under ground."""
	me = ob.data
	hull = me.materials.find(k.mat(HULL).name)
	band = k.mat(BAND[0])
	if me.materials.find(band.name) < 0:
		me.materials.append(band)
	bi = me.materials.find(band.name)
	light = k.mat(CRAG_TOP)
	if me.materials.find(light.name) < 0:
		me.materials.append(light)
	li = me.materials.find(light.name)
	crags = {me.materials.find(k.mat(c).name) for c in CRAG} - {-1}
	bm = bmesh.new()  # drop the hide faces sunk below the ground (tri budget)
	bm.from_mesh(me)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == hull and all(v.co.z < -2.0 for v in f.verts)], context="FACES")
	bm.to_mesh(me)
	bm.free()
	for poly in me.polygons:
		if poly.material_index in crags and poly.normal.z > 0.45:
			poly.material_index = li
		elif poly.material_index == hull and poly.center.z < band_top(poly.center.x) - 14:  # the step plates carry the edge
			poly.material_index = bi


def kaiju_corpse(k):
	"""Kaiju corpse (hero): a giant Kaiju No. 8-style beast lying dead on its belly across the blocks, about 560 long and
	195 tall (sweeper_cleaning1/2). The torso is four large smooth hide masses that merge into one steep red-brown flank
	wall; its own faces carry the flush maroon ink shadows and the speckled grey-beige band on the lower flank. Big beige
	jagged rock crags lean along the top silhouette, with the stake-and-rope line among them; a second stake line crosses
	the flank. A thick neck and a horned head rest on the ground (brow crests, eye sockets, open jaw with teeth); a splayed
	clawed foreleg and a folded hind leg toward the road; a long tapering tail. Monster Sweeper cleanup: two teal lattice
	gantries with ropes down to sweepers braced feet-first on the hide, thin ropes draped from the ridge, crew on the back
	and the ground, skip bins. No wounds. The head is at -X; -Z (its flank) faces the road."""
	rnd = random.Random(8008)
	band_top = corpse_band_top(rnd)
	kc = []
	for hx, rx, ry, rz in MASSES:
		kc.append(("ball", (rx * 2, ry * 2, rz * 2), (hx, MYC, 0), HULL, {"subdiv": 4, "smooth": True}))
	flank_z, top_y = corpse_z, corpse_top

	def lean_at(x, y):
		"""Tilt (degrees about X) that lays a flat chip on the flank at (x, y)."""
		z0, z1 = flank_z(x, y - 2), flank_z(x, y + 2)
		return -math.degrees(math.atan2(z1 - z0, 4))

	for i in range(360):  # dense medium-small dark speckle chips lying flush on the band (sweeper_cleaning2)
		x, y = rnd.uniform(-240, 260), rnd.uniform(3, 0.4 * top_y(0))
		z = flank_z(x, y)
		if z > -20 or y > band_top(x) - 4:
			continue
		w = rnd.uniform(1.6, 3.4)
		kc.append(("cone", (w, w * rnd.uniform(0.6, 1.1), 0.3), (x, y, z - 0.25), rnd.choice(("4E4438", "625646", "3E362C", "6E6252")), {"seg": 3, "rot": (lean_at(x, y), 0, rnd.uniform(0, 120))}))
	x, run, left = -236.0, 1, 0
	while x < 262:  # pale-tan saw-tooth rock ridge (sweeper_cleaning2): faceted wedges and pointed tetras with sloped
		ty = top_y(x)  # tops, leaning into each other in runs, bases sunk into the hide
		if left <= 0:
			run, left = -run, rnd.randint(3, 5)  # each run of crags leans the same way, then the lean flips
		left -= 1
		h = ty * rnd.choice((rnd.uniform(0.07, 0.12), rnd.uniform(0.12, 0.2)))
		w = rnd.uniform(34, 60)
		lean = run * rnd.uniform(22, 38)
		zc = rnd.uniform(-12, 6)
		if rnd.random() < 0.55:  # pointed tetra-like crag
			kc.append(("cone", (w, h * 1.5, w * rnd.uniform(0.6, 0.9)), (x, ty + h * 0.3, zc), rnd.choice(CRAG), {"seg": 3, "taper": rnd.uniform(0.15, 0.35), "rot": (rnd.uniform(-10, 10), rnd.uniform(0, 120), lean)}))
		else:  # wedge outcrop: one long sloped face
			kc.append(("wedge", (w * 0.7, h * 1.2, w), (x, ty + h * 0.25, zc), rnd.choice(CRAG), {"rot": (rnd.uniform(-8, 8), 90 * run + rnd.uniform(-25, 25), rnd.uniform(-10, 10))}))
		x += w * rnd.uniform(0.35, 0.5)
	# neck and head, resting on the ground
	kc.append(("ball", (100, 120, 110), (-215, 56, -8), HIDE, {"subdiv": 3, "smooth": True}))  # neck
	kc.append(("ball", (92, 90, 90), (-275, 44, -12), HIDE, {"subdiv": 1}))
	bx(kc, (64, 50, 66), (-305, 40, -14), HIDE, rot=(0, 0, -6))  # heavy angular cranium
	bx(kc, (74, 24, 50), (-362, 36, -16), "7A3E30", rot=(0, 0, -12))  # upper jaw, lifted open
	kc.append(("wedge", (74, 10, 50), (-362, 50, -16), HIDE, {"rot": (0, 90, -12)}))  # snout ridge
	bx(kc, (84, 9, 50), (-356, 3.5, -16), "5E2A20")  # lower jaw resting on the ground
	bx(kc, (70, 2, 40), (-356, 8.2, -16), "3A1410")  # mouth
	for i in range(10):
		x = -330 - i * 7
		top = 24 + (-330 - x) * 0.21  # underside of the lifted upper jaw
		kc.append(("cone", (4.4, 12, 4.4), (x, top - 5, -39), BONE, {"seg": 6, "rot": (180, 0, 0)}))
		kc.append(("cone", (3.8, 10, 3.8), (x - 3, 12.5, -38), BONE, {"seg": 6}))
	ROCKS = ("8E4A38", "844434", "96503C", "7E4232")
	for s_ in (-1, 1):
		bx(kc, (16, 10, 6), (-310, 52, -14 + s_ * 30), "1A0C08")  # eye socket
		bx(kc, (46, 12, 20), (-306, 66, -14 + s_ * 26), "6A342A", rot=(0, s_ * 10, -14))  # brow crest
		bx(kc, (24, 8, 14), (-286, 74, -14 + s_ * 26), "7A3E30", rot=(s_ * 12, 0, 22))
		kc.append(("cone", (14, 44, 14), (-262, 80, -14 + s_ * 30), BONE2, {"rot": (s_ * 14, 0, 64), "seg": 6}))  # horn
	for i in range(8):  # rock plates over the skull
		bx(kc, (rnd.uniform(14, 24), rnd.uniform(5, 9), rnd.uniform(14, 24)), (-330 + i * 9 + rnd.uniform(-3, 3), 64 - i * 0.5 + rnd.uniform(0, 4), -14 + rnd.uniform(-18, 18)), rnd.choice(ROCKS), rot=(rnd.uniform(-15, 15), rnd.uniform(0, 60), rnd.uniform(-20, 10)))
	# foreleg splayed toward the road with four claws; folded hind leg
	seg(kc, (-128, 66, -48), (-150, 18, -98), HIDE, thick=30, wide=28)  # upper arm, down and out from the shoulder
	kc.append(("ball", (34, 30, 34), (-150, 16, -98), HIDE, {"subdiv": 2, "smooth": True}))  # elbow on the ground
	seg(kc, (-150, 14, -98), (-212, 9, -114), HIDE, thick=22, wide=24)  # forearm, bent forward along the ground
	kc.append(("ball", (40, 18, 36), (-226, 8, -116), HIDE, {"subdiv": 1}))
	for c in (-13, -4, 5, 14):
		kc.append(("cone", (7, 22, 7), (-246, 6, -116 + c), BONE2, {"rot": (0, 0, 80), "seg": 6}))
	seg(kc, (118, 46, -62), (92, 14, -102), HIDE, thick=26, wide=26)  # folded hind leg: thigh down to the knee
	kc.append(("ball", (26, 24, 26), (92, 13, -102), HIDE, {"subdiv": 2, "smooth": True}))
	seg(kc, (92, 12, -102), (56, 7, -120), HIDE, thick=18, wide=20)  # shin forward to the foot
	kc.append(("ball", (40, 16, 34), (48, 6, -124), HIDE, {"subdiv": 1}))
	for c in (-10, 0, 10):
		kc.append(("cone", (6, 20, 6), (28, 5, -124 + c), BONE2, {"rot": (0, 0, 80), "seg": 6}))
	# long tail curving away from the road: one continuous tapering tail to a point
	pts = [(225 + i * 26, 8 + 1.9 * i * i, 56 - i * 4.2) for i in range(12)]  # curls away from the road
	for i in range(11):
		x, z, r = pts[i]
		x1, z1, r1 = pts[i + 1]
		ln, ry = math.hypot(x1 - x, z1 - z), math.degrees(math.atan2(-(z1 - z), x1 - x))
		kc.append(("cyl", (r, ln * 1.15, r), ((x + x1) / 2, r * 0.42, (z + z1) / 2), HIDE, {"seg": 9, "rot": (0, ry, -90), "taper": r1 / r, "smooth": True}))
		kc.append(("cone", (r * 0.7, r * 0.55, r * 0.5), ((x + x1) / 2, r * 0.9, (z + z1) / 2), CRAG[i % len(CRAG)], {"seg": 3, "taper": 0.2, "rot": (0, ry, 24)}))  # pale crag on the tail ridge
	x, z, r = pts[11]
	kc.append(("cone", (r, 30, r), (x + 13, r * 0.42, z + 6), HIDE, {"seg": 9, "rot": (0, -12, -90)}))
	# stake-and-rope lines (sweeper_cleaning1/2): separate upright grey A-frame posts every 20 studs, a thin dark rope
	# sagging between the post tops; one line along the back among the crags and one across the flank
	lines = [[(x, top_y(x) - 2, -12) for x in range(-200, 241, 20)]]
	lines.append([(x, top_y(x) * 0.62, flank_z(x, top_y(x) * 0.62) - 2) for x in range(-200, 201, 20)])
	PH = 14.0
	for line in lines:
		for x, y, z in line:
			for lx in (-1.8, 1.8):  # A-frame: two slim legs splayed along the line, meeting at the top
				seg(kc, (x + lx, y, z), (x, y + PH, z - 0.8), "8A8E94", thick=1.1)
			bx(kc, (3.0, 0.6, 0.8), (x, y + PH * 0.45, z - 0.4), "8A8E94")  # cross bar
		for (x0, y0, z0), (x1, y1, z1) in zip(line, line[1:]):
			pts_ = []
			for q in range(4):  # three-piece sag between the post tops
				t = q / 3
				pts_.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + PH - 0.3 - 5.0 * 4 * t * (1 - t), z0 + (z1 - z0) * t - 0.8))
			for a_, b_ in zip(pts_, pts_[1:]):
				cab(kc, a_, b_, "2A2622", thick=0.45)
	# two teal lattice gantries straddling the body; from each, ropes down to sweepers braced feet-first on the hide
	GH, GS = 220.0, 104.0
	for gx in (-80, 140):  # the tail-side gantry stands clear of the folded hind leg
		for z in (-GS, GS):
			for x in (-10, 10):
				bx(kc, (3, GH, 3), (gx + x, GH / 2 - 1, z), TEAL, metal=0.4)
			for y in range(0, int(GH) - 10, 20):
				bx(kc, (20, 1.4, 1.4), (gx, y + 10, z), TEAL, metal=0.4)
				bx(kc, (1.1, 28, 1.1), (gx, y + 10, z), "286A66", rot=(0, 0, 45))
			bx(kc, (28, 2, 9), (gx, 0, z), "3A3E46")
		for y in (GH, GH - 10):
			for x in (-7, 7):
				bx(kc, (2.6, 2.6, GS * 2 + 8), (gx + x, y, 0), TEAL, metal=0.4)
		for i in range(12):
			z = -GS + (i + 0.5) * GS * 2 / 12
			bx(kc, (1.1, 14, 1.1), (gx + 7, GH - 5, z), "286A66", rot=(45 if i % 2 else -45, 0, 0))
		bx(kc, (18, 8, 12), (gx, GH - 6, -40), "E8C840")
		for j, (dx, fy) in enumerate(((-36, 0.62), (-16, 0.3), (20, 0.48))):  # sweepers on the hide, off the gantry legs
			S = 4.6
			px = gx + dx
			py = top_y(px) * fy
			pz = flank_z(px, py) - 0.8 * S  # turned to face the hide: boots on its surface
			worker(kc, px, py, pz, S, face=180)
			top = (gx + (-7 if dx < 0 else 7), GH - 11, -58 + j * 6)
			chest = (px, py + 3.6 * S, pz + 0.4 * S)
			seg(kc, top, chest, (ROPE_B, ROPE_Y)[j % 2], thick=1.0)
			ay = py - 12  # the rope runs on below the feet and ends on the hide
			seg(kc, chest, (px + 1, ay, flank_z(px + 1, ay) - 0.6), (ROPE_B, ROPE_Y)[j % 2], thick=1.0)
	for i in range(16):  # thin ropes from the ridge draped down the hide to the ground
		x = -185 + i * 24 + rnd.uniform(-4, 4)
		ys = [top_y(x) - 4, top_y(x) * 0.7, top_y(x) * 0.45, 30, 2]
		pts_ = [(x + rnd.uniform(-1, 1), y, flank_z(x, y) - 1.0) for y in ys]
		for a_, b_ in zip(pts_, pts_[1:]):
			cab(kc, a_, b_, (ROPE_B, ROPE_Y, "2E9A96")[i % 3], thick=0.55)
	for gx in (-80, 140):  # dozens of long ropes from the gantry beams to the ground, in front of the flank
		for q in range(18):
			z = -100 + q * 1.6 + rnd.uniform(-0.5, 0.5)
			x0 = gx + rnd.choice((-7, 7)) + rnd.uniform(-1, 1)
			x1 = x0 + rnd.uniform(-14, 14)
			mid = (x0 + (x1 - x0) * 0.6, GH * 0.4, z - rnd.uniform(0, 3))  # a slight hang
			col = (ROPE_B, ROPE_Y, "1A1A1C")[q % 3]
			cab(kc, (x0, GH - 2, z), mid, col, thick=0.6)
			cab(kc, mid, (x1, 0.3, z - 2), col, thick=0.6)
	for x in (-40, 50):  # on the back
		worker(kc, x, top_y(x) - 4, -8, 1.8, lo=True)
	for x, z, sc in ((-20, -100, 1.15), (20, -96, 1.15), (150, -88, 1.1), (-140, -150, 1.15)):  # ground crew: human scale
		worker(kc, x, -1, z, sc, lo=True)
	for x, z in ((-40, -112), (80, -104)):
		bx(kc, (14, 6, 8), (x, 2, z), "2F5FA8")
		bx(kc, (14.4, 0.6, 8.4), (x, 5.2, z), "244A84")
	kc.append(("cyl", (760, 1, 260), (20, -0.9, 0), "4A4642", {"seg": 24}))
	for i in range(16):
		s_ = rnd.uniform(5, 12)
		bx(kc, (s_, s_ * 0.6, s_), (rnd.uniform(-380, 420), s_ * 0.3 - 1, rnd.choice((-1, 1)) * rnd.uniform(110, 128)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	ink_tongues(kc, rnd, band_top)
	band_edge(kc, rnd, band_top)
	ob = k.prop("KaijuCorpse", kc)
	corpse_paint(k, ob, band_top)
	return ob


def rail_cannon(k):
	"""Rail cannon (hero): the anti-kaiju rail gun on its long rail bed (railgun.jpg): ballast, two rails and sleepers, a
	heavy carriage, a massive barrel raised 10 degrees on two support pillars, a coil stack at the breech (separate
	thick discs with air gaps, stepping up to the largest at the front, thin radial blades on their front faces), a
	chamfered square muzzle with rivet rows and a stepped recessed bore, ribbed capacitor tanks either side of the barrel
	axis behind the coil stack, side decks with handrails, and bundles of cables that leave the discs' rims at
	mid-height on both sides, arc over the handrails and run back along them in long sagging loops to junction boxes.
	Barrel to +X."""
	rg = []
	bx(rg, (250, 1.2, 34), (10, -0.6, 0), "6A645C")
	for z in (-13, 13):  # two toothed rack rails (railgun.jpg) either side of the carriage
		bx(rg, (250, 1.4, 2.2), (10, 0.7, z), "8A8E94", metal=0.7)
		for x in range(-112, 134, 4):
			bx(rg, (1.8, 1.0, 2.4), (x, 1.9, z), "6E7278", metal=0.6)
	for x in range(-112, 134, 9):
		bx(rg, (2.4, 0.7, 34), (x, 0.1, 0), "4A4038")
	bx(rg, (190, 9, 22), (20, 5.5, 0), "4E545C", metal=0.4)  # long low carriage the barrel lies on
	bx(rg, (186, 2, 18), (20, 11, 0), "3E444A", metal=0.4)  # cradle under the barrel
	for x in (-60, -20, 20, 60, 100):
		for z in (-11, 11):
			rg.append(("cyl", (6, 3, 6), (x, 3, z), "2A2A2A", {"rot": (90, 0, 0), "seg": 10}))
	el = 0.0  # the barrel lies level and low (railgun.jpg)
	ax, ay = -50.0, 28.0
	ce, se_ = math.cos(math.radians(el)), math.sin(math.radians(el))

	def along(t, up=0.0):
		return (ax + ce * t - se_ * up, ay + se_ * t + ce * up, 0.0)

	rg.append(("cyl", (30, 162, 30), along(81), "4A5058", {"rot": (0, 0, el - 90), "seg": 18, "metal": 0.6, "rough": 0.35}))
	rg.append(("cyl", (44, 56, 44), along(28), "4A5058", {"rot": (0, 0, el - 90), "seg": 20, "metal": 0.6}))  # coil sleeve
	def brot(roll):
		"""Kit rot (degrees) for a part on the raised barrel, rolled `roll` degrees about the barrel axis."""
		e = (Matrix.Rotation(math.radians(-el), 4, "Y") @ Matrix.Rotation(math.radians(roll), 4, "X")).to_euler("YXZ")
		return (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y))

	DISC = [26.0] * 8  # equal discs, centred on the barrel axis, equal gaps (railgun.jpg)

	for i in range(8):  # separate thick coil discs with air gaps, square to the barrel, radial blades on each front
		t, R = 4 + i * 7, DISC[i]  # face and a raised toothed ring round each rim
		rg.append(("cyl", (R * 2, 4.2, R * 2), along(t), ("8A9098", "6A727A")[i % 2], {"rot": (0, 0, el - 90), "seg": 24, "metal": 0.6}))
		rg.append(("cyl", (R * 2 + 1.6, 2.2, R * 2 + 1.6), along(t), "5A6068", {"rot": (0, 0, el - 90), "seg": 24, "metal": 0.6}))  # rim ring
		for f in range(20):
			a = f * 18
			c = along(t, (R + 1.3) * math.cos(math.radians(a)))
			rg.append(("box", (2.6, 1.6, 2.0), (c[0], c[1], (R + 1.3) * math.sin(math.radians(a))), "4A525A", {"rot": brot(a), "metal": 0.5}))  # rim tooth
		for f in range(12):
			a = f * 30 + (i % 2) * 15
			r_ = (23 + R - 1.2) / 2
			c = along(t + 2.6, r_ * math.cos(math.radians(a)))
			rg.append(("box", (1.0, R - 24.2, 0.9), (c[0], c[1], r_ * math.sin(math.radians(a))), "4A525A", {"rot": brot(a), "metal": 0.5}))
	for i in range(5):
		rg.append(("cyl", (34, 2.4, 34), along(66 + i * 20), "5E666E", {"rot": (0, 0, el - 90), "seg": 18, "metal": 0.6}))
	T0 = 168.0  # muzzle (railgun.jpg): a square block with chamfered corners, rivet rows, a stepped recessed bore

	def mz(size, u, v, w, col, roll=0.0, **o):
		c = along(T0 + u, v)
		rg.append(("box", size, (c[0], c[1], w), col, {"rot": brot(roll), **o}))

	H, CH = 21.0, 6.0  # half size, chamfer
	MZ = "2E3238"
	for v, w in ((H - 3.5, 0), (-H + 3.5, 0)):
		mz((12, 7, 2 * (H - CH)), 0, v, w, MZ)
	for v, w in ((0, H - 3.5), (0, -H + 3.5)):
		mz((12, 2 * (H - CH), 7), 0, v, w, MZ)
	dc = (2 * H - CH) / 2 - 3.5 / math.sqrt(2)  # chamfer slabs: outer face on the cut corner line
	for sv, sw in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
		mz((12, 7, 13), 0, sv * dc, sw * dc, MZ, roll=45 * sv * sw)
	mz((1.0, 2 * H, 2 * H), -5.6, 0, 0, MZ)  # back plate
	for v, w, sz in ((12, 0, (8, 4, 24)), (-12, 0, (8, 4, 24)), (0, 12, (8, 24, 4)), (0, -12, (8, 24, 4))):
		mz(sz, -1.0, v, w, "3A3E44")  # inner step ring, recessed 3 behind the face
	mz((0.6, 20, 20), -4.8, 0, 0, "08080A")  # the bore, black, deep inside the step
	for side in (-1, 1):  # small rivets only round the face edges (railgun.jpg); plain plate seams on the side faces
		for q in range(8):
			r_ = -15.75 + q * 4.5
			mz((0.8, 0.8, 0.8), 6.2, side * 19.2, r_, "9AA0A6")
			mz((0.8, 0.8, 0.8), 6.2, r_, side * 19.2, "9AA0A6")
		for u in (-2.0, 2.5):
			mz((0.5, 0.3, 2 * (H - CH)), u, side * (H + 0.1), 0, "1E2226")
			mz((0.5, 2 * (H - CH), 0.3), u, 0, side * (H + 0.1), "1E2226")
	for gt in (95.0, 140.0):  # low saddles on the carriage, round the barrel
		gx_, gy_, _ = along(gt, -15)
		bx(rg, (10, 4, 30), (gx_, gy_ - 1, 0), "4A5058", metal=0.4)
	for s in (-1, 1):  # ribbed grey capacitor tanks: dark ring bands and vertical ribs
		for j, x in enumerate((-62, -78)):  # two tanks each side of the barrel axis, behind the coil drum
			tz = s * 30
			rg.append(("cyl", (11, 48, 11), (x, 23, tz), "8E969E", {"seg": 12, "metal": 0.5, "rough": 0.4}))
			for q in range(8):
				rg.append(("cyl", (12.4, 1.8, 12.4), (x, 2 + q * 6, tz), ("3E444A", STRIPE)[q == 4], {"seg": 12, "metal": 0.5}))
			for a_ in range(4):
				ang = a_ * math.pi / 2 + math.pi / 4
				bx(rg, (1.0, 46, 1.0), (x + math.cos(ang) * 5.8, 23, tz + math.sin(ang) * 5.8), "5A6268")
			rg.append(("cyl", (8, 2.4, 8), (x, 48, tz), "5E666E", {"seg": 12}))
	cols = ("141414", "1E1E20", "2A2A2C", "18181A")

	def curve(p0, c, p1, n):
		return [tuple((1 - t) ** 2 * p0[q] + 2 * (1 - t) * t * c[q] + t * t * p1[q] for q in range(3)) for t in [i / n for i in range(n + 1)]]

	crng = random.Random(5150)
	POSTS = list(range(-110, 135, 16))  # handrail posts on both side decks
	for side in (-1, 1):  # junction boxes at the back of each side deck, where the cable runs end
		for jx in (-104, -88):
			bx(rg, (7, 4, 6), (jx, 8.3, side * 46), "3A3E44", metal=0.4)
	for b in range(32):  # bundles of 3-5 near-black cables on each side (railgun.jpg): each leaves a disc rim high up,
		side = (-1, 1)[b % 2]  # arcs out to a handrail post top, then hangs in one smooth loop that sags below the rail
		i = (b // 4) % 8  # top and ends flat on the deck: 5 pieces, no foot zigzag, nothing standing on the ground
		t, R = 4 + i * 7, DISC[i] + 0.7
		x0 = along(t)[0]
		first = min((px for px in POSTS if px >= x0 - 2), default=POSTS[-1])
		back = crng.choice((16, 32, 32, 48))
		for m in range(crng.choice((3, 4, 5))):
			zo = (m - 2) * 0.8
			a = math.radians(crng.uniform(20, 70) if b % 4 < 2 else crng.uniform(55, 85))  # upper rim and mid rim
			c0 = along(t + crng.uniform(-1, 1), R * math.cos(a))
			p0 = (c0[0], c0[1], side * R * math.sin(a))
			top = (first + crng.uniform(-1.5, 1.5), 11.6 + m * 0.15, side * (50.5 + zo * 0.3))
			pts_ = curve(p0, ((p0[0] + top[0]) / 2, p0[1] + 4, side * (R * math.sin(a) + 14)), top, 2)  # out to the post top
			end = (top[0] - back + crng.uniform(-3, 3), 6.7, side * (48.5 + zo))  # flat on the deck
			sag = crng.uniform(0.5, 2.5)  # the loop dips below the rail top, outside the deck edge
			pts_ += curve(top, ((top[0] + end[0]) / 2, sag, side * (53.5 + zo)), end, 3)[1:]
			th = crng.uniform(0.75, 1.0)
			for a_, b_ in zip(pts_, pts_[1:]):  # each piece runs a little past its ends, so the joints close up
				d = [b_[q] - a_[q] for q in range(3)]
				ln = math.sqrt(sum(v * v for v in d)) or 1.0
				e = [v / ln * th * 0.5 for v in d]
				cab(rg, tuple(a_[q] - e[q] for q in range(3)), tuple(b_[q] + e[q] for q in range(3)), cols[(b + m) % 4], thick=th)
	for s in (-1, 1):  # grated side decks outside the coil drum, with posts and handrails
		bx(rg, (250, 0.6, 10), (10, 6, s * 46), "5A6068", metal=0.4)
		for x in range(-110, 135, 16):
			bx(rg, (0.8, 6, 0.8), (x, 3, s * 46), "4A5058")
			bx(rg, (0.5, 5, 0.5), (x, 8.8, s * 50.5), "C8CCD0")
		bx(rg, (250, 0.5, 0.5), (10, 11, s * 50.5), "C8CCD0")
	car(rg, 70, 74, OLIVE)  # support truck on the far side
	bx(rg, (7.2, 5, 9), (70, 3, 78), "3E4636")
	k.prop("Railgun", rg)
	return k.props["Railgun"]


def build(k):
	rnd = random.Random(808)

	# --- Apartment block (mid): "mansion" with balcony slabs, rails, dividers, sliding doors, AC units; the top right
	# corner has collapsed: the floors step down, broken floor plates stick out of the break face, a slab rests from
	# the break down onto the lower roof, rubble on that roof, scorch marks round the break. ---
	ap = []
	AW, AD, fh = 40.0, 20.0, 6.0
	full, low = 9, 6
	bx(ap, (AW - 14, fh * full, AD), (-7, fh * full / 2 - 1, 0), "D9D0BC")
	bx(ap, (14, fh * low, AD), (13, fh * low / 2 - 1, 0), "D9D0BC")
	for f in range(full):
		y = f * fh + 1
		w, x = (AW, 0) if f < low else (AW - 14, -7)
		bx(ap, (w, 0.8, 4), (x, y + fh - 1.4, -AD / 2 - 2), "E6E0D2")
		bx(ap, (w, 2.2, 0.3), (x, y + fh - 3.2, -AD / 2 - 3.9), "B8C0C6", metal=0.4)
		n = int(w / 8)
		for c in range(n):
			cx = x - w / 2 + (c + 0.5) * w / n
			bx(ap, (5.6, 3.6, 0.3), (cx, y + 2.0, -AD / 2 - 0.1), WINDOW, rough=0.2)
			bx(ap, (0.3, fh - 1.4, 4), (cx + w / n / 2, y + 2.3, -AD / 2 - 2), "D0C8B4")
			if (c + f) % 3 == 0:
				bx(ap, (2.4, 1.6, 1.2), (cx + 2, y + 0.9, -AD / 2 - 1), "E8E8E8")
	for f in range(low, full):  # broken floor plates sticking out of the break face (attached to the wall)
		bx(ap, (rnd.uniform(2, 5), 0.8, AD - rnd.uniform(2, 8)), (6 + 1.5, f * fh - 0.6, rnd.uniform(-2, 2)), CONC)
		bx(ap, (0.6, fh * 0.7, 2), (6.3, f * fh + 2, rnd.uniform(-8, 8)), RUST, metal=0.5)
	seg(ap, (6, fh * full - 4, -2), (19, fh * low - 0.5, -3), CONC2, thick=1.6, wide=16)  # slab: break to roof
	for i in range(5):
		s = rnd.uniform(2.5, 5)
		bx(ap, (s, s * 0.7, s), (rnd.uniform(8, 19), fh * low - 1 + s * 0.3, rnd.uniform(-8, 8)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-15, 15)))
	for x, y, w, h in ((4, fh * 7, 6, 10), (12, fh * 5, 8, 6), (-14, fh * 2, 4, 5), (-4, fh * 4, 10, 8)):
		bx(ap, (w, h, 0.3), (x, y, -AD / 2 - 4.0), SCORCH)
	for x, y in ((-12, fh * 6 + 2), (10, fh * 3 + 2)):  # missing wall chunks: dark holes with jagged edges
		bx(ap, (7, 5, 0.4), (x, y, -AD / 2 - 4.1), "141210")
		for q in range(4):
			bx(ap, (2, 1.4, 0.6), (x - 3 + q * 2, y + 2.6 * (1 if q % 2 else -1), -AD / 2 - 4.1), CONC, rot=(0, 0, rnd.uniform(-30, 30)))
	for x, w, h in ((4, 22, 10), (16, 16, 8), (-14, 12, 6)):  # rubble cones at the foot of the break
		ap.append(("cone", (w, h, w * 0.7), (x, h / 2 - 1, -AD / 2 - 7), (ROCK, CONC2, DUST)[int(x) % 3], {"seg": 7}))
	ap.append(("wedge", (AW - 14, 7, AD), (-7, fh * full + 2.5, 0), "D9D0BC", {"rot": (0, 90, 0)}))  # sheared top: slopes down to the break
	for q in range(6):  # bent rebar along the sheared edge
		bx(ap, (0.4, 5, 0.4), (-18 + q * 4, fh * full + 4, -AD / 2 + 2), RUST, metal=0.5, rot=(rnd.uniform(-30, 30), 0, rnd.uniform(-30, 30)))
	for x, w in ((-16, 8), (2, 6)):  # soot climbing the facade above the holes
		bx(ap, (w, fh * 3, 0.3), (x, fh * 7.5, -AD / 2 - 4.05), SCORCH)
	ap.append(("cyl", (6, 5, 6), (-12, fh * full + 1.5, 2), "C8CCD0", {"seg": 10}))
	for i in range(7):
		s = rnd.uniform(3, 7)
		bx(ap, (s, s * 0.6, s), (rnd.uniform(-18, 22), s * 0.3 - 1, rnd.uniform(-20, -13)), (ROCK, CONC2, CONC)[i % 3], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), rnd.uniform(-15, 15)))
	k.prop("Apartment", ap)

	# --- Office tower (mid): curtain-wall window bands and fins; the right part has collapsed four floors below the
	# left, its floor plates jut from the break, a slab leans from the break onto the lower roof, scorch marks. ---
	of = []
	OW, OD, oh = 34.0, 30.0, 6.0
	hi_f, lo_f = 14, 10
	parts = ((-6.5, 21.0, hi_f), (10.5, 13.0, lo_f))
	for x, w, nf in parts:
		bx(of, (w, oh * nf, OD), (x, oh * nf / 2 - 1, 0), "AEB6BE")
		for f in range(nf):
			bx(of, (w + 0.2, 3.2, 0.3), (x, f * oh + 2.4, -OD / 2 - 0.1), GLASS, rough=0.1, metal=0.4)
		bx(of, (w + 0.6, 1.0, OD + 0.6), (x, oh * nf - 0.5, 0), "8E969E")
	for f in range(hi_f):
		bx(of, (0.3, 3.2, OD + 0.2), (-OW / 2 - 0.1, f * oh + 2.4, 0), GLASS, rough=0.1, metal=0.4)
	for x in range(-15, 16, 6):
		nf = hi_f if x < 4 else lo_f
		bx(of, (0.8, oh * nf, 1.2), (x, oh * nf / 2 - 1, -OD / 2 - 0.5), "C8CED4")
	for f in range(lo_f, hi_f):
		bx(of, (rnd.uniform(2, 6), 0.8, OD - rnd.uniform(2, 10)), (4 + 1.8, f * oh - 0.6, rnd.uniform(-3, 3)), CONC)
		bx(of, (0.6, oh * 0.8, 1.2), (4.3, f * oh + 2, rnd.uniform(-10, 10)), RUST, metal=0.5)
	of.append(("box", (16, 1.6, 20), (11, oh * lo_f + 5.5, 0), CONC2, {"rot": (0, 0, -34)}))  # slab: break to roof
	for i in range(4):
		s = rnd.uniform(3, 6)
		bx(of, (s, s * 0.7, s), (rnd.uniform(8, 16), oh * lo_f - 1 + s * 0.3, rnd.uniform(-10, 10)), (ROCK, CONC2)[i % 2], rot=(rnd.uniform(-15, 15), rnd.uniform(0, 90), 0))
	for x, y, w, h in ((2, oh * 12, 6, 14), (12, oh * 8, 8, 8), (-12, oh * 4, 6, 6), (-6, oh * 9, 8, 10)):
		bx(of, (w, h, 0.3), (x, y, -OD / 2 - 0.6), SCORCH)
	for x, y in ((-10, oh * 7), (8, oh * 4)):  # blown-out wall chunks
		bx(of, (8, 6, 0.4), (x, y, -OD / 2 - 0.65), "141210")
		for q in range(4):
			bx(of, (2.4, 1.4, 0.6), (x - 3.6 + q * 2.4, y + 3 * (1 if q % 2 else -1), -OD / 2 - 0.7), CONC, rot=(0, 0, rnd.uniform(-30, 30)))
	for x, w, h in ((8, 24, 11), (-6, 14, 7), (14, 12, 6)):  # rubble cones at the foot of the collapse
		of.append(("cone", (w, h, w * 0.7), (x, h / 2 - 1, -OD / 2 - 8), (ROCK, CONC2, DUST)[int(x) % 3], {"seg": 7}))
	of.append(("wedge", (21, 8, OD), (-6.5, oh * hi_f + 3, 0), "AEB6BE", {"rot": (0, -90, 0)}))  # sheared top
	for x, w in ((-12, 7), (-2, 5)):  # scorched facade above the blown-out chunks
		bx(of, (w, oh * 4, 0.3), (x, oh * 9.5, -OD / 2 - 0.62), SCORCH)
	of.append(("cyl", (6, 5, 6), (-10, oh * hi_f + 1.5, 4), "C8CCD0", {"seg": 10}))
	bx(of, (OW + 8, 1.2, OD + 8), (0, -0.4, 0), "6A6A68")
	for i in range(6):
		s = rnd.uniform(3, 8)
		bx(of, (s, s * 0.6, s), (rnd.uniform(-20, 20), s * 0.3, rnd.uniform(-22, -16)), (ROCK, CONC2)[i % 2], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	k.prop("Office", of)

	# --- Rubble (mid): concrete chunks of mixed size, a crushed car, a car flipped on its side, a toppled utility pole,
	# bent rebar, a cracked road slab, a scorch patch ---
	ru = []
	for i in range(11):
		s = rnd.uniform(1.5, 7)
		bx(ru, (s, s * rnd.uniform(0.4, 0.9), s * rnd.uniform(0.6, 1.2)), (rnd.uniform(-12, 12), s * 0.3 - 1, rnd.uniform(-5, 9)), (ROCK, CONC2, CONC, DUST, ASH)[i % 5], rot=(rnd.uniform(-25, 25), rnd.uniform(0, 90), rnd.uniform(-25, 25)))
	car(ru, 12, -2, "D8302F", yaw=24, state=1)
	car(ru, -14, 6, "E8E8E8", yaw=-60, state=2)
	ru.append(("cyl", (1.0, 26, 1.0), (-4, 2, -2), "9A9A96", {"seg": 8, "rot": (0, 30, 80)}))
	for i in range(5):
		bx(ru, (0.3, 6, 0.3), (-2 + i, 3, 2), RUST, metal=0.6, rot=(rnd.uniform(-35, 35), 0, rnd.uniform(-35, 35)))
	bx(ru, (14, 1.2, 10), (2, 0.6, 8), "4E4E50", rot=(8, 15, -6))
	bx(ru, (18, 0.2, 12), (0, -0.85, 2), SCORCH)
	k.prop("Rubble", ru)

	kaiju_corpse(k)  # hero, see its docstring

	# --- Sweeper van set (mid): one-box van with a sloped nose and raked windscreen, side windows, wheel arches, a plain
	# red band, a raised roof rack with crew sitting on top, cones and a light tower. Nose to -Z. ---
	va = []
	VW = "F4F4F2"
	bx(va, (6.6, 2.6, 15.4), (0, 1.9, 0), VW)  # lower body
	bx(va, (6.4, 3.4, 11.2), (0, 4.9, 2.0), VW)  # upper body behind the raked screen
	va.append(("wedge", (6.4, 0.7, 1.3), (0, 3.55, -7.05), VW))  # short sloped nose (Hiace)
	va.append(("wedge", (6.4, 3.2, 3.0), (0, 5.0, -5.1), VW))  # windscreen slope, raked back 43 degrees
	bx(va, (5.0, 3.0, 0.2), (0, 5.0, -5.2), "34404E", rough=0.1, rot=(43, 0, 0))  # raked windscreen, top below the roof
	for x in (-2.85, 2.85):
		bx(va, (0.8, 4.3, 0.4), (x, 5.0, -5.2), VW, rot=(43, 0, 0))  # thick A-pillars
		bx(va, (1.2, 0.8, 0.2), (x * 0.9, 2.5, -7.75), "F0F0D8", emit=0.6)  # headlamps
		bx(va, (0.5, 0.7, 0.8), (x * 1.27, 4.5, -4.3), "2A2E34")  # door mirrors
	for x in (-1.2, 1.2):
		bx(va, (2.0, 0.15, 0.15), (x, 3.98, -6.25), "1A1C20", rot=(43, 0, 12 if x < 0 else -12))  # wipers at the glass base
	bx(va, (4.2, 0.9, 0.2), (0, 2.5, -7.75), "2A2E34")  # grille
	bx(va, (6.8, 0.8, 0.6), (0, 0.9, -7.8), "5A5E64")  # bumper
	bx(va, (1.8, 0.8, 0.15), (0, 1.0, -8.15), "E8E8E0")  # blank plate
	for s_ in (-1, 1):
		bx(va, (0.2, 2.6, 2.2), (s_ * 3.25, 4.85, -2.6), "34404E", rough=0.1)  # cab door window
		for z in (0.4, 3.4, 6.3):  # big side windows
			bx(va, (0.2, 2.6, 2.7), (s_ * 3.25, 4.85, z), "34404E", rough=0.1)
		bx(va, (0.2, 0.7, 15.4), (s_ * 3.35, 2.9, 0), "C82828")  # plain red band
		for z in (-5.2, 5.0):
			bx(va, (0.2, 1.8, 3.2), (s_ * 3.33, 0.9, z), "2A2A2A")  # wheel arch
			va.append(("cyl", (2.3, 0.9, 2.3), (s_ * 3.05, 0.15, z), "1A1A1A", {"rot": (0, 0, 90), "seg": 10}))  # small wheels
	for z in (-2.6, 1.6):  # sliding-door seams on the kerb side, with the door rail
		bx(va, (0.25, 5.4, 0.2), (3.36, 3.6, z), "8A8E94")
	bx(va, (0.25, 0.25, 4.4), (3.36, 3.9, -0.5), "8A8E94")
	bx(va, (5.0, 2.0, 0.2), (0, 5.0, 7.7), "34404E", rough=0.1)  # rear window
	for x in (-2.9, 2.9):
		bx(va, (0.6, 1.4, 0.2), (x, 2.6, 7.75), "C82828", emit=0.4)
	for z in (-3.5, 1.5, 6.5):  # long roof rack
		for x in (-3.0, 3.0):
			bx(va, (0.5, 0.6, 0.5), (x, 6.9, z), "9AA0A6", metal=0.6)
		bx(va, (6.4, 0.35, 0.5), (0, 7.3, z), "9AA0A6", metal=0.6)
	for x in (-3.0, 3.0):
		bx(va, (0.4, 0.4, 11.5), (x, 7.5, 1.5), "9AA0A6", metal=0.6)
	for j, z in enumerate((-2.6, 0.2, 3.0, 5.8)):  # four sitting in a row along the rack in mixed poses (sweeper_members)
		sitter(va, 0.6, 7.7, z, 0.65, face=-90 + (18, -14, 24, -20)[j], pose=j)
	lounger(va, -2.0, 7.55, -1.5, 0.95)  # one lying flat along the rack, head forward on the front rail
	worker(va, 4.9, -1, 1.0, 1.0, lean=-6, crossed=True, lo=True)  # leaning on the van, arms crossed
	va.append(("cone", (1.6, 3, 1.6), (-8, 0.5, -10), STRIPE, {"seg": 6}))  # one cone (mid-prop tri cap)
	va.append(("cyl", (0.6, 11, 0.6), (10, 4.5, 20), "6A6E74", {"seg": 6}))  # light tower, clear of the roof crew
	bx(va, (2.4, 1.4, 1.2), (10, 10.5, 20), "E8ECF0", emit=1.0)
	bx(va, (5, 3, 5), (10, 0.5, 20), "E8C840")
	k.prop("SweeperVan", va)

	# --- Defense Force HQ (hero) with the observation tower beside it: one wide symmetric white 8-floor block, end
	# pavilions with roof masts, a central tower with a tall glass strip, pilasters and portico, a regular window grid,
	# the parking lot with white cars and a tree row in front; the tower on the viewer's left (+X): ribbed shaft,
	# glazed ring cab, radar domes, lattice mast. Badge: an invented orange diamond (not the real insignia). ---
	hq = []
	HW, HD, FH, NF = 230.0, 36.0, 8.0, 8
	HH = FH * NF
	bx(hq, (HW, HH, HD), (0, HH / 2 - 1, 0), BASE)
	for s in (-1, 1):
		px = s * (HW / 2 - 15)
		bx(hq, (30, HH + 16, HD + 4), (px, (HH + 16) / 2 - 1, -2), "E4E4DE")
		bx(hq, (31, 1.6, HD + 5), (px, HH + 15.6, -2), BASE2)
		for f in range(NF + 1):
			bx(hq, (30.6, 1.0, 1.0), (px, f * FH + 1.4, -HD / 2 - 4.4), "B4B4AE")
		bx(hq, (0.6, 24, 0.6), (px + s * 6, HH + 27, 0), "8A9096")
		bx(hq, (6, 0.4, 0.4), (px + s * 6, HH + 32, 0), "8A9096")
		bx(hq, (4, 0.4, 0.4), (px + s * 6, HH + 36, 0), "8A9096")
	for f in range(NF):
		y = f * FH + 4
		for c in range(26):
			x = -HW / 2 + 5 + c * 8.8
			if abs(x) < 17:
				continue
			pav = abs(x) > HW / 2 - 30
			bx(hq, (5.6, 4.0, 0.4), (x, y, -HD / 2 - (4.1 if pav else 0.1)), WINDOW, rough=0.2)
		bx(hq, (HW - 60, 1.0, 1.0), (0, f * FH + 1.4, -HD / 2 - 0.5), "B4B4AE")
	bx(hq, (32, HH + 14, HD + 10), (0, (HH + 14) / 2 - 1, -2), "F2F2EE")
	bx(hq, (10, HH + 4, 0.6), (0, (HH + 4) / 2 + 6, -HD / 2 - 7.2), "3E5670", rough=0.1, metal=0.4)
	for q in range(3):
		bx(hq, (0.6, HH + 4, 0.8), (-3.3 + q * 3.3, (HH + 4) / 2 + 6, -HD / 2 - 7.5), "E8E8E8")
	for f in range(NF):
		bx(hq, (10.4, 0.6, 0.9), (0, f * FH + 8, -HD / 2 - 7.5), "E8E8E8")
	for s in (-1, 1):
		bx(hq, (5, HH + 14, 1.2), (s * 13.5, (HH + 14) / 2 - 1, -HD / 2 - 7.4), "FAFAF6")
		for f in range(NF):
			bx(hq, (5, 3.4, 0.4), (s * 8.5, f * FH + 4, -HD / 2 - 7.2), WINDOW)
	bx(hq, (34, 1.6, HD + 12), (0, HH + 13.6, -2), BASE2)
	bx(hq, (5, 5, 0.6), (0, HH + 9, -HD / 2 - 7.6), STRIPE, emit=0.4, rot=(0, 0, 45))
	bx(hq, (2.6, 2.6, 0.4), (0, HH + 9, -HD / 2 - 7.9), "FFFFFF", rot=(0, 0, 45))
	bx(hq, (26, 1.4, 12), (0, 8.5, -HD / 2 - 13), "F2F2EE")
	for x in (-12, 12):
		bx(hq, (1.4, 9, 1.4), (x, 3.5, -HD / 2 - 18), "D8D8D4")
	bx(hq, (14, 7, 0.4), (0, 2.5, -HD / 2 - 7.4), "2E4256", rough=0.1)
	bx(hq, (0.5, 22, 0.5), (0, HH + 24, -2), "8A9096")
	bx(hq, (HW + 20, 0.6, 104), (0, -0.7, -HD / 2 - 60), "4A4C50")
	bx(hq, (8, 0.62, 104), (0, -0.68, -HD / 2 - 60), "6E7074")
	for c in range(30):  # front row of white cars along the lot edge
		x = -HW / 2 + 6 + c * 7.8
		if abs(x) > 6:
			car(hq, x, -HD / 2 - 104, ("F4F4F4", "E8E8E8", "D8DCE0")[c % 3], yaw=90)
	for z in (-HD / 2 - 40, -HD / 2 - 72):
		for s in (-1, 1):
			for c in range(9):
				x = s * (12 + c * 11)
				bx(hq, (0.5, 0.62, 14), (x + 5.5 * s, -0.68, z), "E8E8E8")
				if (c * 5 + s + int(z)) % 4 != 0:
					car(hq, x + 2.7 * s, z, ("F2F2F2", "C8CCD0", "E8E8E8", "9AA0A8")[c % 4])
	for c in range(16):
		x = -HW / 2 + 8 + c * 14.5
		if abs(x) < 20:
			continue
		hq.append(("ball", (10, 8, 8), (x, 3, -HD / 2 - 26), "3E6A3A", {"subdiv": 1}))
	ox, oz = HW / 2 + 40, 6.0  # observation tower
	bx(hq, (40, 16, 30), (ox, 7, oz), BASE)
	for y in (3, 9):
		for x in range(-16, 17, 6):
			bx(hq, (4, 3, 0.4), (ox + x, y, oz - 15.2), WINDOW)
	hq.append(("cyl", (14, 120, 14), (ox, 60, oz), "E8E8E2", {"seg": 16}))
	for i in range(8):
		a = i / 8 * math.tau
		bx(hq, (2.2, 118, 2.2), (ox + math.cos(a) * 7.4, 60, oz + math.sin(a) * 7.4), "BCC2C8")
	hq.append(("cyl", (30, 2, 30), (ox, 120, oz), BASE2, {"seg": 20}))
	hq.append(("cyl", (26, 1.6, 26), (ox, 110, oz), BASE2, {"seg": 20}))  # second balcony ring under the cab
	for i in range(12):
		a = i / 12 * math.tau
		bx(hq, (0.5, 3, 0.5), (ox + math.cos(a) * 12.6, 112.4, oz + math.sin(a) * 12.6), "D8D8D8")
	hq.append(("cyl", (25.6, 0.5, 25.6), (ox, 113.8, oz), "D8D8D8", {"seg": 20}))
	hq.append(("cyl", (26, 10, 26), (ox, 126, oz), "6A90B0", {"seg": 20, "rough": 0.1, "metal": 0.3, "emit": 0.2}))
	for i in range(10):
		a = i / 10 * math.tau
		bx(hq, (0.6, 10, 0.6), (ox + math.cos(a) * 13.1, 126, oz + math.sin(a) * 13.1), "F2F2EE")
	hq.append(("cyl", (32, 2, 32), (ox, 132, oz), "F2F2EE", {"seg": 20}))
	hq.append(("cyl", (32.4, 2.4, 32.4), (ox, 122.5, oz), "F2F2EE", {"seg": 20}))
	hq.append(("cyl", (18, 6, 18), (ox, 136, oz), BASE, {"seg": 16}))
	for s in (-1, 1):
		hq.append(("cyl", (1.4, 4, 1.4), (ox + s * 6, 141, oz), BASE2, {"seg": 6}))
		hq.append(("ball", (8, 8, 8), (ox + s * 6, 146, oz), "FFFFFF", {"subdiv": 2, "smooth": True}))
	for j in range(5):
		y = 140 + j * 7
		w = 4 - j * 0.5
		for sx in (-1, 1):
			for sz in (-1, 1):
				bx(hq, (0.5, 7, 0.5), (ox + sx * w / 2, y + 3.5, oz + sz * w / 2), "D8D8D8")
		bx(hq, (w + 3, 0.4, 0.4), (ox, y + 7, oz), "D8D8D8")
		bx(hq, (0.4, 0.4, w + 3), (ox, y + 7, oz), "D8D8D8")
	hq.append(("ball", (1.6, 1.6, 1.6), (ox, 176, oz), "FF2B2B", {"emit": 8}))
	k.prop("DefenseHQ", hq)

	# --- Hangar (mid): arched roof, big sliding doors with seams, abstract orange chevrons on the doors, door-base
	# hazard stripe, side office annex, front apron, an armoured Defense Force vehicle with a mounted cannon ---
	hg = []
	hg.append(("cyl", (56, 64, 40), (0, 0, 2), "8C949C", {"rot": (90, 0, 0), "seg": 16, "metal": 0.4, "rough": 0.5}))
	bx(hg, (58, 2, 66), (0, -1, 2), "5A5E66")
	bx(hg, (44, 18, 1), (0, 8, -30.4), "4A525C", metal=0.3)
	for x in (-16.5, -5.5, 5.5, 16.5):
		bx(hg, (0.5, 18, 1.4), (x, 8, -30.8), "2E343C")
	bx(hg, (46, 1.2, 1.6), (0, 17.4, -30.8), "2E343C")
	for i in range(3):
		for s in (-1, 1):
			bx(hg, (4.6, 0.9, 0.5), (s * 2.0, 10 + i * 1.8, -31.2), "D87A2A", rot=(0, 0, s * 25))
	for x in range(-22, 23, 4):
		bx(hg, (2, 1.2, 0.4), (x, 0.2, -31.1), ("E8C840", "1A1A1A")[(x // 4) % 2])
	bx(hg, (20, 12, 40), (38, 5, 0), BASE)
	for z in range(-14, 15, 7):
		bx(hg, (0.4, 3, 4), (48.1, 7, z), WINDOW)
	for x in (31, 37, 43):
		bx(hg, (4, 3, 0.4), (x, 7, -20.1), WINDOW)
	bx(hg, (21, 1, 41), (38, 11.5, 0), BASE2)
	bx(hg, (60, 0.5, 30), (0, -0.8, -46), "6A6C70")
	for x in (-12, 12):
		bx(hg, (1, 0.52, 30), (x, -0.78, -46), "E8C840")
	vz = -46
	bx(hg, (10, 5, 26), (0, 4, vz), OLIVE)
	bx(hg, (9, 4, 7), (0, 7, vz - 8), "3E4636")
	bx(hg, (8, 1.2, 2.4), (0, 8, vz - 11.8), "26303A", rough=0.1, rot=(-25, 0, 0))
	for z in (-9, -3, 3, 9):
		for x in (-5.4, 5.4):
			hg.append(("cyl", (4, 1.6, 4), (x, 1.2, vz + z), "1C1C1C", {"rot": (0, 0, 90), "seg": 10}))
	hg.append(("cyl", (7, 3, 7), (0, 8, vz + 5), "3E4636", {"seg": 10}))
	hg.append(("cyl", (1.4, 20, 1.4), (0, 10, vz - 4), "2A2E26", {"rot": (80, 0, 0), "seg": 8}))
	k.prop("Hangar", hg)

	# --- Base wall (mid): a low white wall (5 tall, so the runner sees over it) with navy band and orange stripe,
	# sparse fence posts with two wires, a pillar with a lamp ---
	bw = []
	bx(bw, (28, 5, 2.4), (0, 1.5, 0), BASE)
	bx(bw, (28.2, 1.0, 2.6), (0, 2.4, 0), NAVY)
	bx(bw, (28.2, 0.5, 2.6), (0, 3.3, 0), STRIPE, emit=0.3)
	bx(bw, (28.4, 0.6, 3.0), (0, 4.3, 0), BASE2)
	for x in range(-12, 13, 8):
		bx(bw, (0.3, 4, 0.3), (x, 6.6, 0), "7A8086", metal=0.5)
	for y in (6.0, 8.2):
		bx(bw, (28, 0.2, 0.2), (0, y, 0), "7A8086", metal=0.5)
	bx(bw, (2.6, 8, 3), (14, 3, 0), BASE2)
	bx(bw, (0.5, 6, 0.5), (14, 10, 0), "6A7078")
	bx(bw, (3, 0.8, 1.2), (13, 13.3, -0.6), "FFF2D0", emit=3.0)
	bx(bw, (28, 0.4, 10), (0, -0.8, 7), "5E7A44")  # grass verge inside the base
	for x in (-8, 4):
		bw.append(("ball", (7, 5, 6), (x, 1.5, 8), "3E6A3A", {"subdiv": 1}))
	k.prop("BaseWall", bw)

	rail_cannon(k)  # hero, see its docstring

	# --- City block (mid): a 160-stud tile of the street grid. Half-width streets and sidewalks on all four edges, so
	# tiles turned by any quarter still join up; low-rise blocks (some collapsed, scorched), a crater with a rubble rim,
	# a small park with trees, wrecked cars, poles. Tiles are laid with random quarter turns for variety. ---
	cb = []
	T = 160.0
	bx(cb, (T, 0.3, T), (0, -0.85, 0), "9C968A")
	for a in range(4):
		ca, sa = math.cos(a * math.pi / 2), math.sin(a * math.pi / 2)

		def rot2(x, z):
			return (x * ca - z * sa, x * sa + z * ca)

		x, z = rot2(0, -T / 2 + 3.5)
		bx(cb, (T if a % 2 == 0 else 7, 0.4, 7 if a % 2 == 0 else T), (x, -0.75, z), ASPHALT)
		x, z = rot2(0, -T / 2 + 8.5)
		bx(cb, (T - 14 if a % 2 == 0 else 3, 0.8, 3 if a % 2 == 0 else T - 14), (x, -0.5, z), WALK)
		for i in range(7):
			x, z = rot2(-T / 2 + 16 + i * 21, -T / 2 + 0.6)
			bx(cb, (8 if a % 2 == 0 else 0.6, 0.42, 0.6 if a % 2 == 0 else 8), (x, -0.74, z), "D8D8D0")
		x, z = rot2(-50, -T / 2 + 10.5)
		cb.append(("cyl", (1.0, 26, 1.0), (x, 12, z), "9A9A96", {"seg": 6}))
	lows = [(10, -42, 34, 2, "B8B4AC"), (-44, 22, 28, 2, "B0A898")]  # two kaiju-broken low-rises among the houses
	for i, (x, z, w, nf, col) in enumerate(lows):
		h = nf * 7
		broken = True
		hh = h * (0.55 if broken else 1)
		bx(cb, (w, hh, 22), (x, hh / 2 - 1, z), col)
		for f in range(nf if not broken else 1):
			bx(cb, (w - 3, 2.4, 0.3), (x, f * 7 + 3.5, z - 11.1), WINDOW)
		if broken:
			cb.append(("wedge", (w, h * 0.6, 12), (x, hh + h * 0.3 - 1, z + 5), col))
			bx(cb, (w * 0.8, hh * 0.7, 0.3), (x, hh * 0.4, z - 11.2), SCORCH)
			cb.append(("cone", (w * 0.7, 6, 9), (x, 2, z - 15), ROCK, {"seg": 7}))  # rubble cone at the base
		else:
			bx(cb, (w + 0.6, 0.8, 22.6), (x, h - 0.6, z), "8E8A82")
	ROOFS = ("A8483A", "8E3E32", "6E4A3A", "5A5E66", "4A5060", "7A5444")
	WALLS = ("E8E2D4", "D8D0C0", "F0ECE2", "C8C0B0", "DCD6CC")
	taken = [(10, -42, 24, 18), (-44, 22, 21, 18), (44, 36, 24, 22), (-4, 30, 18, 18)]  # broken blocks, park, crater
	hz = -60.0
	while hz < 64:  # a dense low-rise town of pitched-roof houses (sweeper_members.jpg, background)
		hx = -60.0
		while hx < 64:
			if not any(abs(hx - tx) < rx_ and abs(hz - tz) < rz_ for tx, tz, rx_, rz_ in taken):
				w, d, h = rnd.uniform(9, 13), rnd.uniform(8, 11), rnd.uniform(6, 9)
				x, z = hx + rnd.uniform(-1.5, 1.5), hz + rnd.uniform(-1.5, 1.5)
				rh, rc = rnd.uniform(3, 4.5), rnd.choice(ROOFS)
				bx(cb, (w, h, d), (x, h / 2 - 1, z), rnd.choice(WALLS))
				for sz in (-1, 1):  # gable roof: two wedges back to back, eaves over the walls
					cb.append(("wedge", (w + 1.2, rh, d / 2 + 0.7), (x, h - 1 + rh / 2, z + sz * (d / 4 + 0.35)), rc, {"rot": (0, 90 + sz * 90, 0)}))
				if rnd.random() < 0.5:  # a window strip on some (mid-prop tri cap)
					bx(cb, (w * 0.6, 1.6, 0.2), (x, h * 0.55 - 1, z - d / 2 - 0.1), WINDOW)
			hx += 15.5
		hz += 15.5
	bx(cb, (44, 0.4, 40), (44, -0.6, 36), "5E7A44")  # park
	for x, z in ((32, 24), (52, 26), (40, 46), (60, 48), (28, 50)):
		cb.append(("cyl", (1.2, 6, 1.2), (x, 2, z), "4A3A2A", {"seg": 5}))
		cb.append(("ball", (9, 8, 9), (x, 8, z), ("3E6A3A", "4A7A40")[x % 2], {"subdiv": 1}))
	cb.append(("cyl", (30, 0.6, 30), (-4, -0.6, 30), "26221E", {"seg": 12}))  # crater
	cb.append(("cyl", (20, 0.8, 20), (-4, -0.5, 30), "1A1816", {"seg": 10}))
	for i in range(8):
		a = i / 8 * math.tau
		s_ = rnd.uniform(3, 6)
		bx(cb, (s_, s_ * 0.6, s_), (-4 + math.cos(a) * 16, s_ * 0.3 - 1, 30 + math.sin(a) * 16), (ROCK, CONC2, DUST)[i % 3], rot=(rnd.uniform(-20, 20), rnd.uniform(0, 90), 0))
	car(cb, -30, -T / 2 + 3, "2F6FD8", yaw=90)
	car(cb, 40, -T / 2 + 4, "E8E8E8", yaw=60, state=1)
	car(cb, -T / 2 + 3, 40, "D8302F", yaw=5, state=2)
	k.prop("CityBlock", cb)

	# --- Smoke column (mid): scorched base with embers, four columns of faceted puffs that widen, lighten and drift as they rise ---
	sm = [("cyl", (40, 0.4, 40), (0, -0.8, 0), SCORCH, {"seg": 10})]
	for i in range(3):
		s = rnd.uniform(3, 6)
		sm.append(("ball", (s, s * 0.6, s), (rnd.uniform(-10, 10), 0.5, rnd.uniform(-10, 10)), "FF7A2A", {"subdiv": 1, "emit": 3.0}))
	cols = ("26221F", "3A3633", "514D49", "68645F", "807C77", "98948F")
	for ox, oz, sc_, n in ((0, 0, 1.0, 6), (18, 12, 0.8, 5), (-15, 9, 0.7, 5)):  # three columns of faceted puffs (2.9k tris cap)
		x, y, r = ox, 8.0, 12 * sc_
		for i in range(n):  # each level: a pair of puffs, wider and lighter as it rises, drifting downwind
			for j in range(2):
				a = j * math.pi + rnd.uniform(-0.6, 0.6) + i
				pr = r * rnd.uniform(0.85, 1.15)
				sm.append(("ball", (pr * 2, pr * 1.6, pr * 2), (x + math.cos(a) * r * 0.45, y + rnd.uniform(-r, r) * 0.2, oz + math.sin(a) * r * 0.45), cols[i], {"subdiv": 2}))
			x, y, r = x + r * 0.4, y + r * 1.25, r * 1.22
	k.prop("Smoke", sm)

	# --- layout ---
	k.ground(DUST, margin=500)
	supports(k, "3A3E46")
	city_end, base0 = 3900.0, 4050.0
	corpses = [(800.0, -190.0, 1.0), (2750.0, -200.0, 1.0)]  # heads ahead of run shots 1 and 2; measured with clearance.py
	# the first corpse turns by CTURN about a pivot behind its head (tail swung out), so run shot 4 (far behind
	# it, on the last straight) sees its flank, ridge and stake line instead of its tail end; 0 for the second
	CTURN = {800.0: math.radians(CTURN_DEG), 2750.0: 0.0}

	def corpse_frame(d, off):
		"""World origin (x, z) and yaw of a corpse placed at (d, off), turned CTURN about its local point (-300, 0)."""
		px, pz, yaw = local(k, d, off, -300, 0)
		yaw += CTURN[d]
		v = Matrix.Rotation(yaw, 3, "Z") @ Vector((-300, 0, 0))
		return px - v.x, pz + v.y, yaw

	def corpse_pt(d, off, lx):
		ox, oz, yaw = corpse_frame(d, off)
		v = Matrix.Rotation(yaw, 3, "Z") @ Vector((lx, 0, 0))
		return ox + v.x, oz - v.y
	skip = [(d - 460, d + 460) for d, _, _ in corpses]
	side = skip + [(3300.0, 3540.0)]  # right side clear under the side review camera (build_track 05_side)
	gun = skip + [(3300.0, 3660.0)]  # open ground round the rail cannon
	# rubble 50 out (measured): even turned, its widest reach (about 16) stays 24+ from the centre line
	row(k, 40, city_end, 30, (-50, 50), ["Rubble"], jitter=3, turn=math.pi, chance=0.6, scale=(0.8, 1.1))
	row(k, 40, city_end, 46, (-64,), ["Apartment", "Apartment", "Office"], jitter=4, skip=gun, turn=0.25, lean=0.2)
	row(k, 40, city_end, 46, (64,), ["Apartment", "Apartment", "Office"], jitter=4, skip=side, turn=0.25, lean=0.2)
	row(k, 60, city_end, 62, (-110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=gun, turn=0.3, lean=0.25)
	row(k, 60, city_end, 62, (110,), ["Office", "Apartment", "Office"], jitter=10, scale=(1.0, 1.6), skip=side, turn=0.3, lean=0.25)
	for d, off, s in corpses:  # both on the left
		ox, oz, yaw = corpse_frame(d, off)
		k.place("KaijuCorpse", (ox, -1.0, oz), yaw, s)
	vans = [(470, -40), (515, -40), (560, -40), (640, -40), (2520, -40), (2565, -40), (2610, -40), (2660, -40)]
	for i, (d, off) in enumerate(vans):  # parked by the corpses, in run shots 1 and 2; every other van mirrored for variety
		ob = put(k, "SweeperVan", d, off, 1.15, turn=k.rng.uniform(-0.6, 0.6))
		if ob and i % 2:
			ob.scale[0] = -ob.scale[0]
	put(k, "Railgun", 3480, -90, clear=50)
	# Base: low perimeter wall, hangars (kept out of the HQ view), a second rail cannon (muzzle to run shot 4)
	row(k, base0, k.length - 80, 28, (-31, 31), ["BaseWall"])
	row(k, base0 + 60, k.length - 100, 110, (-92,), ["Hangar"], skip=[(4250, 4950), (6400, 6960)])  # clear for the cannon
	row(k, base0 + 60, k.length - 100, 110, (92,), ["Hangar"], skip=[(4250, 4950), (6400, 6960)])  # clear for the cannon
	row(k, base0 + 100, k.length - 100, 140, (150, -150), ["Hangar", "Apartment"], jitter=10, skip=[(4250, 4950), (6500, 7000)])
	# the start straight runs parallel about 150 to the right of the last straight, so the cannon goes on the left
	for d, off in ((6740, -110), (6780, -120)):  # measured: the left side is 260+ from every other lap
		ob = put(k, "Railgun", d, off)  # on the left, local +X (the muzzle) points back at run shot 4
		if ob:
			gun2 = (d, off)
			print("KAIJUBASE gun2 at", tuple(round(v) for v in ob.location), "road", tuple(round(v) for v in k.at(d)[0]))
			break
	else:
		gun2 = (6800, -120)
	print("KAIJUBASE gun2", gun2)
	# HQ (with its tower) square-on to run shot 3, ahead-left of the camera
	eye, t, right = shot_eye(k, 0.62)
	a = math.radians(-16)
	fwd = t * math.cos(a) + right * math.sin(a)
	hqc = eye + fwd * 430
	look = eye - hqc
	k.place("DefenseHQ", (hqc.x, -1.0, hqc.z), math.atan2(-look.x, -look.z))
	print("KAIJUBASE HQ clear", round(min((Vector((w.x, 0, w.z)) - Vector((hqc.x, 0, hqc.z))).length for w in k.wps)))
	behind = hqc + fwd * 420  # nothing tall behind the HQ, so its roofline stays clean in shot 3
	tall_avoid = [(hqc.x, hqc.z, 260), (behind.x, behind.z, 460)]
	avoid = [(hqc.x, hqc.z, 260)]
	for d, off, s in [(3480, -90, 1.0), (gun2[0], gun2[1], 1.0)]:
		x, z, _ = local(k, d, off, 0, 0)
		avoid.append((x, z, 210))
	for d, off, s in corpses:  # along each corpse's full length, head to tail tip
		for lx in (-380, -250, -120, 0, 120, 250, 380, 500):
			x, z = corpse_pt(d, off, lx)
			avoid.append((x, z, 210 if lx == 0 else 170))
	# Street grid tiles (random quarter turns) over the city and the infield, a few towers on them
	towers = []
	gx = k.lo.x - 400
	while gx < k.hi.x + 400:
		gz = k.lo.z - 400
		while gz < k.hi.z + 400:
			if k.clear_of_road(gx, gz, 190) and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in avoid):
				k.place("CityBlock", (gx, -1.0, gz), k.rng.choice((0, 1, 2, 3)) * math.pi / 2)
				if k.rng.random() < 0.14 and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in tall_avoid):
					k.place(k.rng.choice(["Office", "Apartment"]), (gx, -1.0, gz), k.rng.choice((0, math.pi / 2, math.pi)), k.rng.uniform(1.0, 1.8))
					towers.append((gx, gz, 60))
			gz += 160
		gx += 160
	placed, tries = 0, 0  # smoke columns, clear of the road rows, towers and landmarks
	while placed < 9 and tries < 800:
		tries += 1
		x = k.rng.uniform(k.lo.x - 200, k.hi.x + 200)
		z = k.rng.uniform(k.lo.z - 200, k.hi.z + 200)
		if k.clear_of_road(x, z, 220) and all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid + towers + tall_avoid):
			ob = k.place("Smoke", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.2, 1.8))
			ob.visible_shadow = False  # smoke casts no hard shadow
			placed += 1
	placed, tries = 0, 0  # far skyline
	while placed < 70 and tries < 3000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 480, k.hi.x + 480)
		z = k.rng.uniform(k.lo.z - 480, k.hi.z + 480)
		if k.clear_of_road(x, z, 420) and all(math.hypot(x - ax, z - az) > r for ax, az, r in tall_avoid):
			k.place(k.rng.choice(["Office", "Apartment", "Office"]), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(1.2, 2.4))
			placed += 1
	# Clear day with big cumulus clouds (sky dressing, the game's Sky clouds; not prop assets)
	k.sky(
		[(0.0, "DDEAF2"), (0.04, "B8D4EC"), (0.18, "78AEE0"), (0.5, "3F7CC8"), (1.0, "2A5CA8")],
		strength=1.0,
		sun=(4.0, "FFF0D8", 38, 220),
	)
	bm = bmesh.new()
	c = (k.lo + k.hi) / 2
	span = max(k.hi.x - k.lo.x, k.hi.z - k.lo.z)
	for i in range(22):
		ang = i / 22 * math.tau + rnd.uniform(-0.1, 0.1)
		dist = span * rnd.uniform(1.1, 1.6)
		cx, cz, cy = c.x + math.cos(ang) * dist, c.z + math.sin(ang) * dist, rnd.uniform(380, 650)
		for j in range(rnd.randint(5, 8)):
			r = rnd.uniform(60, 130) * (1.2 if j == 0 else 1.0)
			geom = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
			loc = kit.rb(cx + rnd.uniform(-160, 160), cy + rnd.uniform(-10, 60) + (r * 0.3 if j < 2 else 0), cz + rnd.uniform(-90, 90))
			bmesh.ops.transform(bm, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((r * 1.3, r, r * 0.75, 1)), verts=geom["verts"])
	cl = bpy.data.objects.new("SkyClouds", bpy.data.meshes.new("SkyClouds"))
	bm.to_mesh(cl.data)
	bm.free()
	for poly in cl.data.polygons:
		poly.use_smooth = True
	cl.data.materials.append(k.mat("FFFFFF", rough=1.0, emit=0.35))
	k.col.objects.link(cl)
