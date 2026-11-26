"""World 2 Track 5: Kaiju Base (Kaiju No. 8). Rebuilt 2026-11-23 for a closer 1-1 read of the source (owner: "more detail
and closer reference to source material"; round 2 after the reference review). Landmarks and their references:
docs/world2_refs/KaijuBase.md.
First half: a kaiju-wrecked Tokyo district under a clear blue sky with cumulus clouds: a street grid of wrecked low-rise
blocks with craters, balconied apartment blocks and office towers with collapsed corners and scorch marks (some
leaning), smoke columns, varied rubble and wrecked cars. A giant kaiju corpse lies across the blocks and the Monster
Sweeper crews clean it up (white hooded suits on ropes hanging from teal lattice gantries; white vans with
roof racks and crews sitting on top); the beast itself is invented, whole and unwounded (owner 2026-11-25). Second half:
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
			# its top under the road over its 12-stud cap (kit.support_top), not at the centre's height; it hangs from its top
			top = k.support_top(d - 6, d + 6)
			h = top + 1.0
			if h < kit.SUPPORT_MIN:
				h = kit.SUPPORT_MIN  # sunk, never dropped
			ob = k.place("Pier", (pos[0], top, pos[2]), yaw)
			ob.scale = (1, 1, h)
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


# --- dead kaiju (reworked 2026-11-25, owner: remodel and blend in) ---
# The body is a signed-distance field (numpy) meshed once by OpenVDB: no seams, no plates laid on top. Body tables are in
# the mesh's Blender frame: +X the head end, +Y the road side, Z up, the ground at Z 0.
HIDE_RAMP = ("2A1C19", "33221E", "3C2722", "462D26", "50342B", "5A3B30", "654235", "704A3B", "7B5241", "865C49")  # back and flank hide, dark to light
BELLY_RAMP = ("5E4C3C", "6C5846", "7A6550", "88725A", "967F64", "A38C70")  # belly scutes
KEEL_RAMP = ("4A4038", "5C5044", "6E6152", "807260", "93846F", "A5967F")  # dorsal keels, horns and brow
MID_RAMP = ("5E4034", "694A3B", "755543", "80604C", "8A6C56")  # between hide and belly
DUSTY = "857A6C"  # hide dusted by the ground it lies in
STANDIN = "010203"  # the stand-in parts of the body (the parts fallback's silhouette); their faces never ship
BODY_TRIS, BERM = 11050, ("5B544C", "665F56", "716A60", "7A7368", "817A6F", "878277", DUST)  # berm: churned earth at the body out to the ground colour
SPINE = [(-80, 57, 2, 2.4), (-102, 55, 4, 4.6), (-121, 47, 6, 7), (-134, 31, 8, 10), (-134, 12, 11, 13.5), (-119, -5, 15, 17.5), (-95, -16, 20, 23), (-62, -22, 26, 30), (-28, -25, 31, 32), (8, -25, 37, 38), (42, -18, 36, 36), (70, -3, 28, 25), (91, 13, 20, 18.5), (106, 27, 16, 16)]
HEAD_AT, HEAD_YAW, HEAD_ROLL = (110, 27, 18), math.radians(44), math.radians(-24)  # the skull's back; the snout points toward the road and forward
LIMBS = {  # joints (x, y, z, radius); the last is the palm or sole
	"fore_near": [(44, 10, 42, 22), (34, 40, 24, 13.5), (34, 45, 17, 12.5), (59, 51, 11, 8), (69, 52.5, 8, 8.5)],
	"fore_far": [(42, -42, 40, 20), (18, -50, 22, 12.5), (34, -54, 8, 9), (46, -54, 5, 8)],
	"hind_near": [(-62, 2, 34, 25), (-40, 32, 29, 18), (-38, 35, 24, 15), (-11, 46, 11, 8.6), (0, 50, 7, 8.5)],
	"hind_far": [(-64, -42, 30, 19), (-36, -49, 20, 13), (-62, -54, 8, 9), (-50, -56, 5, 8)],
}
DIGITS = {"fore_near": ((7, 8.6), (14, 3.0), (14, -3.0), (9, -9)), "fore_far": ((10, 5.5), (14, 0), (10, -5.5)), "hind_near": ((9, 7.6), (14, 2.2), (13.5, -3.4), (8, -9)), "hind_far": ((11, 5.5), (14, 0), (11, -5.5))}


def spine_at(s):
	"""Point and radius on the body's centre line, s in 0 (tail tip) .. 1 (skull), smooth through SPINE."""
	n = len(SPINE) - 1
	f = min(max(s, 0.0), 0.99999) * n
	i, t = int(f), f - int(f)
	p = [SPINE[max(0, min(n, j))] for j in (i - 1, i, i + 1, i + 2)]
	return [0.5 * (2 * p[1][a] + (p[2][a] - p[0][a]) * t + (2 * p[0][a] - 5 * p[1][a] + 4 * p[2][a] - p[3][a]) * t * t + (3 * p[1][a] - p[0][a] - 3 * p[2][a] + p[3][a]) * t**3) for a in range(4)]


def head_pt(u, v, w):
	"""Body point of skull coordinates: u toward the snout, v to the skull's left, w up."""
	ax = head_axes()
	return tuple(HEAD_AT[i] + u * ax[0][i] + v * ax[1][i] + w * ax[2][i] for i in range(3))


class Field:
	"""A smooth-blended signed distance field on a regular grid; each primitive only touches the cells near it."""

	def __init__(self, lo, hi, cell):
		import numpy as np

		self.np, self.lo, self.cell = np, np.array(lo, float), cell
		self.n = [int(math.ceil((hi[i] - lo[i]) / cell)) + 1 for i in range(3)]
		self.f = np.full(self.n, 60.0, np.float32)

	def window(self, lo, hi):
		a = [max(0, int((lo[i] - self.lo[i]) / self.cell)) for i in range(3)]
		b = [min(self.n[i], int((hi[i] - self.lo[i]) / self.cell) + 2) for i in range(3)]
		if any(a[i] >= b[i] for i in range(3)):
			return None, None
		ax = [self.lo[i] + self.cell * self.np.arange(a[i], b[i]) for i in range(3)]
		return tuple(slice(a[i], b[i]) for i in range(3)), self.np.meshgrid(*ax, indexing="ij")

	def blend(self, sl, d, k, cut=False):
		np, f = self.np, self.f[sl]
		if cut:
			h = np.clip(0.5 - 0.5 * (f + d) / k, 0, 1)
			self.f[sl] = f * (1 - h) - d * h + k * h * (1 - h)
		else:
			h = np.clip(0.5 + 0.5 * (f - d) / k, 0, 1)
			self.f[sl] = f * (1 - h) + d * h - k * h * (1 - h)

	def cone(self, a, b, ra, rb, k=4.0, cut=False):
		"""A round cone from a to b."""
		np, m = self.np, max(ra, rb) + 3 * k + 3
		sl, g = self.window([min(a[i], b[i]) - m for i in range(3)], [max(a[i], b[i]) + m for i in range(3)])
		if sl is None:
			return
		ab = [b[i] - a[i] for i in range(3)]
		t = np.clip(sum((g[i] - a[i]) * ab[i] for i in range(3)) / max(sum(v * v for v in ab), 1e-6), 0, 1)
		d = np.sqrt(sum((g[i] - a[i] - t * ab[i]) ** 2 for i in range(3))) - (ra + (rb - ra) * t)
		self.blend(sl, d, k, cut)

	def ball(self, c, r, k=4.0, axes=None, cut=False):
		"""An ellipsoid: radii r along the unit axes (rows; default the grid's)."""
		np, m = self.np, max(r) + 3 * k + 3
		sl, g = self.window([c[i] - m for i in range(3)], [c[i] + m for i in range(3)])
		if sl is None:
			return
		axes = axes or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
		q = [sum((g[i] - c[i]) * ax[i] for i in range(3)) for ax in axes]
		k0 = np.sqrt(sum((q[i] / r[i]) ** 2 for i in range(3)))
		k1 = np.sqrt(sum((q[i] / r[i] ** 2) ** 2 for i in range(3)))
		self.blend(sl, k0 * (k0 - 1) / np.maximum(k1, 1e-6), k, cut)

	def at(self, pts):
		"""Field values at points (m, 3), trilinear."""
		np = self.np
		q = np.clip((pts - self.lo) / self.cell, 0, np.array(self.n) - 1.001)
		i = q.astype(int)
		t = q - i
		out = 0.0
		for dx in (0, 1):
			for dy in (0, 1):
				for dz in (0, 1):
					wt = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
					out = out + wt * self.f[i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz]
		return out


def head_axes(pitch=0.0):
	"""The skull's axes as rows (toward the snout, its left, its up): yawed, pitched, and rolled onto its cheek."""
	c, s, cp, sp = math.cos(HEAD_YAW), math.sin(HEAD_YAW), math.cos(pitch), math.sin(pitch)
	cr, sr = math.cos(HEAD_ROLL), math.sin(HEAD_ROLL)
	l, u = (-s, c, 0), (-c * sp, -s * sp, cp)
	return ((c * cp, s * cp, sp), tuple(l[i] * cr + u[i] * sr for i in range(3)), tuple(u[i] * cr - l[i] * sr for i in range(3)))


def keels():
	"""The dorsal keels: (base, tip, radius) in three rows, the middle row tallest over the shoulders."""
	rnd, out = random.Random(515), []
	for i in range(21):
		s = 0.12 + i * 0.041
		x, y, z, r = spine_at(s)
		x2, y2, _, _ = spine_at(s + 0.01)
		ln = math.hypot(x2 - x, y2 - y) or 1
		tx, ty = (x2 - x) / ln, (y2 - y) / ln
		for lat, share in ((0, 1.0), (-1, 0.55), (1, 0.55)):
			if lat and (i % 2 or not 4 < i < 18):
				continue
			a = lat * 0.62
			ox, oy, oz = -ty * math.sin(a), tx * math.sin(a), math.cos(a)
			h = (3.5 + 0.34 * r) * share * rnd.uniform(0.7, 1.15)
			b = (x + ox * r * 0.86, y + oy * r * 0.86, z + oz * r * 0.86)
			back = h * 0.55  # each keel leans to the tail
			e = (x + ox * (r + h) - tx * back, y + oy * (r + h) - ty * back, z + oz * (r + h))
			out.append((b, e, (2.6 + 0.12 * r) * (0.8 if lat else 1.0)))
	return out


def flank_plates(F):
	"""Low oval plates along the upper flanks: (centre on the skin, axes), flat against it (marched from the body's line)."""
	np, out = F.np, []
	for i in range(9):
		for side, degs in ((1, (34, 62)), (-1, (40, 70))):
			for j, deg in enumerate(degs):
				x, y, z, _ = spine_at(0.36 + i * 0.052 + 0.02 * j)
				a = math.radians(deg) * side
				dr = (0.0, math.sin(a), math.cos(a))
				rr = next((q for q in range(12, 64) if F.at(np.array([[x, y + dr[1] * q, z + dr[2] * q]]))[0] > 0), 0)
				if rr and z + dr[2] * rr > 24:
					out.append(((x, y + dr[1] * rr, z + dr[2] * rr), ((1, 0, 0), (0, math.cos(a), -math.sin(a)), dr)))
	return out


def corpse_field():
	"""The whole body's field: spine masses, ribcage, girdles, jointed limbs, skull and jaw, keels, then skin relief."""
	import numpy as np

	F = Field((-152, -76, -5), (152, 70, 104), 1.1)
	n = 64
	pts = [spine_at(i / n) for i in range(n + 1)]
	for a, b in zip(pts, pts[1:]):
		F.cone(a[:3], b[:3], a[3] * 0.93, b[3] * 0.93, 5.0)
	F.ball((10, -20, 38), (44, 42, 37), 10)  # ribcage
	F.ball((12, 2, 22), (40, 30, 19), 12)  # the belly sags to the road side: the beast lies rolled that way
	F.ball((-30, -2, 18), (30, 24, 16), 12)
	for i in range(8):  # ribs under the hide, on both flanks
		x0 = -22 + i * 9.0
		for side in (1, -1):
			arc = []
			for j in range(7):
				a = math.radians(38 + j * 15) * side
				c0, dr = (x0 + 8 - j * 3.6, -22.0, 36.0), (0.0, math.sin(a), math.cos(a))
				rr = next((q for q in range(20, 64) if F.at(np.array([[c0[n_] + dr[n_] * q for n_ in range(3)]]))[0] > 0), 40)
				arc.append(tuple(c0[n_] + dr[n_] * (rr + 0.2) for n_ in range(3)))
			for p, q in zip(arc, arc[1:]):
				F.cone(p, q, 3.3, 3.0, 2.2)
	F.ball((46, 6, 56), (13, 11, 24), 8, (Vector((0.95, 0.1, -0.3)).normalized()[:], (0.0, 1.0, 0.0), Vector((0.3, 0.0, 0.95)).normalized()[:]))  # shoulder blade
	F.ball((-62, 0, 48), (20, 12, 15), 8)  # hip
	for name, js in LIMBS.items():
		for a, b in zip(js, js[1:]):
			F.cone(a[:3], b[:3], a[3], b[3], 4.5)
		x, y, z, r = js[2] if len(js) > 4 else js[1]
		F.ball((x, y + (3 if y > 0 else -3), z), (r * 0.9,) * 3, 4)  # elbow or knee
		px, py, pz, pr = js[-1]
		F.ball((px, py, pz), (pr * 1.15, pr, pr * 0.62), 4)
		for dx, dy in DIGITS[name]:
			kn, tp = (px + dx * 0.72, py + dy, pz + 1.6), (px + dx * 1.15, py + dy * 1.15, pz - 2.6)
			F.cone((px, py + dy * 0.6, pz), kn, 3.0, 2.7, 1.2)
			F.ball(kn, (3.3, 2.6, 2.9), 0.9)  # knuckle
			F.cone(kn, tp, 2.6, 2.3, 0.9)
			F.ball(tp, (2.7, 2.5, 2.5), 0.8)  # cuff the claw grows from
		ds = DIGITS[name]
		for (ax_, ay), (bx_, by_) in zip(ds, ds[1:]):  # the clefts between the toes
			hind = name.startswith("hind")
			F.cone((px + (8 if hind else 4), py + (ay + by_) * 0.5, pz + 3), (px + (ax_ + bx_) * 0.6 + 3, py + (ay + by_) * 0.6, pz - 1), 0.7 if hind else 1.3, 1.1 if hind else 1.6, 0.8, cut=True)
		wx, wy, wz, wr = js[-2]
		F.cone((wx + 2, wy - wr * 0.7, wz + wr * 1.05), (wx + 2, wy + wr * 0.7, wz + wr * 1.05), 1.1, 1.1, 1.6, cut=True)  # the wrist's break
	# muscle: upper arm, forearm, thigh and calf
	F.ball((38, 31, 34), (12, 9, 16), 6)
	F.ball((-52, 22, 36), (22, 12, 18), 7)
	F.ball((-24, 43, 18), (14, 8, 9), 5)
	# skull: heavy braincase, broad flat snout, brow shelves, cheeks; a hung lower jaw on the ground
	F.ball(head_pt(-1, 0, 4), (18, 16, 13.5), 6, head_axes())
	F.ball(head_pt(17, 0, 4.5), (20, 11.5, 8), 5, head_axes(-0.1))
	F.ball(head_pt(33, 0, 3.2), (9.5, 9.5, 5.6), 4, head_axes(-0.1))
	for v in (-1, 1):
		F.ball(head_pt(2, v * 13, -4), (11, 6.5, 9), 4, head_axes())  # jaw muscle
		F.cone(head_pt(21, v * 7.5, 10.5), head_pt(-3, v * 11.5, 16.5), 3.2, 5.0, 1.8)  # brow shelf
		F.cone(head_pt(22, v * 6, 11), head_pt(38, v * 4.2, 7.6), 2.0, 2.0, 1.8)  # snout ridge to the nostril
		def sv(u, w):
			return next((q / 4 for q in range(20, 100) if F.at(np.array([head_pt(u, v * q / 4, w)]))[0] > 0), 12)

		F.ball(head_pt(23.5, v * 8.8, 7.0), (5.5, 2.0, 2.6), 2.0, head_axes(-0.1))  # softens the overhang on the cheek, below the outline
		F.cone(head_pt(18.5, v * 10.0, 11.2), head_pt(5, v * 13.0, 12.4), 1.5, 1.9, 1.0)  # brow ridge over the lid
		for a_, b_ in (((19, 2.4), (6, 1.4)), ((3, 7.5), (1, 0.5)), ((27, 4.6), (20, 3.0))):  # folds of the cheek
			F.cone(head_pt(a_[0], v * (sv(*a_) + 0.2), a_[1]), head_pt(b_[0], v * (sv(*b_) + 0.2), b_[1]), 0.9, 0.9, 1.6, cut=True)
		F.ball(head_pt(41.5, v * 4.6, 4.6), (2.8, 2.2, 2.0), 0.7, head_axes(), cut=True)  # nostril
		F.cone(head_pt(-6, v * 11, 14), head_pt(-17, v * 19, 25), 5.2, 3.8, 2.0)  # horn, swept back
		F.cone(head_pt(-17, v * 19, 25), head_pt(-29, v * 21.8, 32.4), 3.8, 2.4, 1.2)
		F.cone(head_pt(-2, v * 16, -3), head_pt(-12, v * 22, -4), 3.2, 1.0, 1.8)  # cheek spine
		F.cone(head_pt(0, v * 10.5, -9), head_pt(33, v * 7 + 3, -14.5), 4.2, 3.2, 2.5)  # jaw bar
		for q in range(4):  # rings at the horn's root
			t_ = 0.15 + q * 0.28
			F.ball(head_pt(-6 - 11 * t_, v * (11 + 8 * t_), 14 + 11 * t_), (5.6 - q * 0.4,) * 3, 0.5)
		F.cone(head_pt(2, v * 18, -10), head_pt(9, v * 17, 3), 1.0, 1.0, 1.4, cut=True)  # jaw hinge crease
		F.cone(head_pt(10, v * 11.2, 0.2), head_pt(33, v * 7.6, -0.4), 1.5, 1.5, 2.0)  # upper lip
	F.ball(head_pt(32, 3, -14.5), (9, 8.5, 3.6), 3, head_axes())  # chin
	F.ball(head_pt(19, 1.5, -14.5), (18, 8, 2.8), 2, head_axes())  # floor of the mouth
	F.ball(head_pt(27, 1, -6.2), (21, 12.5, 5.2), 1.6, head_axes(-0.04), cut=True)  # the slack gap between the jaws
	for a, b, ra, rb in (((8, 1, -10), (30, 4, -8.6), 4.6, 4.2), ((30, 4, -8.6), (39, 8, -10.5), 4.2, 3.6), ((39, 8, -10.5), (44, 10, -17), 3.6, 2.8)):
		F.cone(head_pt(*a), head_pt(*b), ra, rb, 1.2)  # the tongue, lolling over the jaw's lip
	F.cone(head_pt(14, 2, -4.6), head_pt(38, 7.6, -5.8), 1.1, 1.1, 0.8, cut=True)  # the tongue's groove
	for a, b, r in keels():
		F.cone(a, b, r, r * 0.28, 2.0)
		F.ball(a, (r * 1.5, r * 1.5, r * 0.95), 1.2)  # the collar it stands in
	for c_, ax_ in flank_plates(F):
		F.ball(c_, (6.2, 4.6, 1.5), 1.0, ax_)
	for arc in ((("x", 62), (-18, 55), 34), (("x", -38), (-8, 56), 30), (("x", -98), (-16, 48), 26)):  # creases at shoulder, hip and tail root
		cx = arc[0][1]
		ring = []
		for j in range(6):
			a_ = math.radians(-24 + j * 17)
			c0, dr = (cx + 3 * math.sin(a_ * 2), arc[1][0], 22.0), (0.0, math.sin(a_), math.cos(a_))
			rr = next((q for q in range(8, 70) if F.at(np.array([[c0[m] + dr[m] * q for m in range(3)]]))[0] > 0), 30)
			ring.append(tuple(c0[m] + dr[m] * rr for m in range(3)))
		for p, q in zip(ring, ring[1:]):
			F.cone(p, q, 1.3, 1.3, 2.2, cut=True)
	# skin relief: folds at the joints, belly scutes, broad lumps
	ax = [F.lo[i] + F.cell * np.arange(F.n[i]) for i in range(3)]
	X, Y, Z = np.meshgrid(*ax, indexing="ij")
	near = np.abs(F.f) < 8
	x, y, z = X[near], Y[near], Z[near]
	lump = np.sin(x * 0.21 + 2.1 * np.sin(y * 0.11)) * np.sin(y * 0.19 + 1.7 * np.sin(z * 0.14)) * np.sin(z * 0.23 + x * 0.05)
	fold = np.sin(x * 0.62 + 1.4 * np.sin(z * 0.16) + 0.4 * y * np.sin(x * 0.03))
	scute = np.abs(np.sin(x * 0.33 + 0.02 * y * np.sin(x * 0.05)))
	low = np.clip((26 - z) / 14, 0, 1) * np.clip(1.4 - np.abs(x + 0) / 62, 0, 1)
	neck = np.clip(1 - np.abs(x - 84) / 20, 0, 1) * np.clip((y + 12) / 14, 0, 1) * np.clip((32 - np.abs(y - 8)) / 8, 0, 1) * np.clip((40 - z) / 8, 0, 1)
	F.f[near] += (-0.9 * lump - 1.1 * fold * neck + 1.4 * low * (1 - scute) ** 2).astype(np.float32)
	return F


def ramp_mat(k, ramp, t):
	return k.mat(ramp[max(0, min(len(ramp) - 1, int(t * len(ramp))))], 0.85)


def corpse_body(k):
	"""The body mesh: the field's surface, cut at the ground, decimated to BODY_TRIS with the head and digits kept dense,
	its faces painted by place on the body, cavity and noise. Returns (mesh, field)."""
	import numpy as np
	import openvdb

	F = corpse_field()
	grid = openvdb.FloatGrid(20.0)
	grid.copyFromArray(F.f.clip(-20, 20))
	verts, quads = grid.convertToQuads(0.0)
	verts = verts * F.cell + F.lo
	# keep what is above the ground; a closed body, so pieces under it never show
	me = bpy.data.meshes.new("KaijuBodyTmp")
	me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(int(i) for i in q) for q in quads])
	bm = bmesh.new()
	bm.from_mesh(me)
	bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -1.2), plane_no=(0, 0, 1), clear_inner=True)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	# drop loose crumbs (keep the biggest island)
	left, islands = set(bm.verts), []
	while left:
		stack, isl = [left.pop()], []
		while stack:
			v = stack.pop()
			isl.append(v)
			for e in v.link_edges:
				o = e.other_vert(v)
				if o in left:
					left.remove(o)
					stack.append(o)
		islands.append(isl)
	islands.sort(key=len, reverse=True)
	print("KAIJU islands", [len(i) for i in islands[:6]])
	for isl in islands[1:]:
		bmesh.ops.delete(bm, geom=isl, context="VERTS")
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new("KaijuBodyTmp", me)
	bpy.context.scene.collection.objects.link(ob)
	vg = ob.vertex_groups.new(name="keep")
	hx, hy, hz = head_pt(16, 0, 0)
	tips = [js[-1] for js in LIMBS.values()]
	for v in me.vertices:
		c = v.co
		w = max(0.0, 1 - math.dist(c, (hx, hy, hz)) / 44)
		for t in tips:
			w = max(w, 0.66 * max(0.0, 1 - math.dist(c, (t[0] + 7, t[1], t[2])) / 24))
		vg.add([v.index], 1.0 - 0.9 * min(1.0, w * 1.5), "REPLACE")  # never fully held: an even mesh, no dense patches
	cur = len(me.polygons)
	dec = ob.modifiers.new("d", "DECIMATE")
	dec.ratio = BODY_TRIS / cur
	dec.vertex_group = "keep"
	dec.vertex_group_factor = 1.0
	dg = bpy.context.evaluated_depsgraph_get()
	out = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
	bpy.data.objects.remove(ob)
	# paint
	nP = len(out.polygons)
	ctr = np.array([p.center[:] for p in out.polygons])
	nor = np.array([p.normal[:] for p in out.polygons])
	if F.at(ctr + nor * 2).mean() < F.at(ctr - nor * 2).mean():  # OpenVDB winding: face outward
		out.flip_normals()
		nor = -nor
	ao = np.clip(0.5 * (F.at(ctr + nor * 3.0) / 3.0) + 0.5 * (F.at(ctr + nor * 8.0) / 8.0), 0, 1)  # open 1, cavity 0
	ss = np.array([spine_at(i / 120) for i in range(121)])
	near = np.zeros(nP, int)
	for i in range(0, nP, 2048):
		near[i : i + 2048] = ((ctr[i : i + 2048, None] - ss[None, :, :3]) ** 2).sum(2).argmin(1)
	up = (ctr[:, 2] - ss[near, 2]) / np.maximum(ss[near, 3], 4)  # height on the body, -1 belly .. 1 back
	x, y, z = ctr.T
	n1 = np.sin(x * 0.31 + 2 * np.sin(y * 0.17)) * np.sin(y * 0.27 + 2 * np.sin(z * 0.21)) * np.sin(z * 0.37 + x * 0.11)
	n2 = np.sin(x * 0.9 + y * 0.7) * np.sin(y * 1.1 - z * 0.8)
	edge = 0.16 * np.sin(x * 0.07 + 1.1) + 0.12 * np.sin(x * 0.19 + y * 0.05) + 0.06 * n1
	belly = np.clip((-0.2 - up + edge) * 1.7, 0, 1) * (nor[:, 2] < 0.55)
	kk = keels()
	ka, kb = np.array([q[0] for q in kk]), np.array([q[1] for q in kk])
	kr = np.array([q[2] for q in kk])
	kd = np.full(nP, 1e9)
	kt = np.zeros(nP)
	for a, b, r in zip(ka, kb, kr):
		t = np.clip(((ctr - a) @ (b - a)) / ((b - a) @ (b - a)), 0, 1)
		d = np.linalg.norm(ctr - a - t[:, None] * (b - a), axis=1) - (r * (1 - 0.72 * t))
		d = np.where(t < 0.35, 1e9, d)  # the base stays hide: the keel grows out of it
		kt = np.where(d < kd, t, kt)
		kd = np.minimum(kd, d)
	H = np.array(head_pt(0, 0, 0))
	hax = np.array(head_axes())
	hu, hv, hw = ((ctr - H) @ hax.T).T
	mats, idx = [], {}

	def slot(m):
		if m.name not in idx:
			idx[m.name] = len(mats)
			mats.append(m)
			out.materials.append(m)
		return idx[m.name]

	out.materials.clear()
	for i, poly in enumerate(out.polygons):
		band = max(0.0, math.sin(x[i] * 0.15 + 0.5 * math.sin(z[i] * 0.11) + 0.8 * n1[i])) * max(0.0, min(1.0, up[i] * 1.6 + 0.2))
		light = 0.56 + 0.09 * n1[i] + 0.02 * n2[i] + 0.8 * (ao[i] - 0.62) - 0.30 * band + 0.10 * (nor[i, 2] - 0.2)
		ramp = HIDE_RAMP
		if abs(x[i]) < 128 and 0.22 < belly[i] < 0.55:  # the hide pales into the belly over a band, no hard edge
			ramp, light = MID_RAMP, 1.1 * belly[i] + 0.8 * (ao[i] - 0.62) + 0.14 + 0.06 * n2[i]
		elif belly[i] >= 0.55 and abs(x[i]) < 128:
			ramp, light = BELLY_RAMP, 0.6 + 0.06 * n2[i] + 0.9 * (ao[i] - 0.62)
		if kd[i] < 0.9:
			ramp, light = KEEL_RAMP, 0.2 + 0.6 * kt[i] + 0.04 * n2[i]
		in_head = -34 < hu[i] < 46 and abs(hv[i]) < 27 and hw[i] > -20
		if in_head and ramp is HIDE_RAMP:
			light = 0.6 + 0.12 * math.sin(hu[i] * 0.16) + 0.25 * (max(ao[i], 0.45) - 0.62)  # calm, no speckle
		if in_head:
			av = abs(hv[i])
			if hu[i] < -7 and av > 10 and hw[i] > 17:
				ramp, light = KEEL_RAMP, 0.5 + 0.2 * n2[i]
			elif 22 < hu[i] < 48 and -1 < hv[i] < 14 and -20 < hw[i] < -5.5 and abs(hv[i] - 4 - max(0, hu[i] - 30) * 0.45) < 4.4 and (hw[i] > -11.5 or hu[i] > 41.5):
				ramp, light = ("4E4450", "655866"), 0.4 + 0.3 * n2[i]  # tongue, grey mauve
			elif 0 < hu[i] < 46 and av < 10.5 and -13 < hw[i] < -1 and ao[i] < 0.62:
				ramp, light = ("2A1814", "3A211C"), 0.3 + 0.4 * ao[i]  # inside of the mouth: dark, no gore
			elif hw[i] < -10:
				ramp, light = BELLY_RAMP, 0.45 + 0.4 * (ao[i] - 0.6) + 0.15 * n2[i]
		if z[i] < 2.4 + 1.6 * n1[i]:
			m = k.mat(DUSTY, 0.95)
		else:
			m = ramp_mat(k, ramp, float(light))
		poly.material_index = slot(m)
		poly.use_smooth = True
	return out, F


def corpse_berm(k, F, rnd):
	"""The ground the body broke: a low irregular heap of churned earth against its whole outline, running out below the
	ground at a ragged edge (so no rim shows), jagged dark cracks in it. Returns its mesh."""
	import numpy as np

	step = 7.0
	xs, ys = np.arange(-154, 154.1, step), np.arange(-83, 64.1, step)
	jx = np.array([[rnd.uniform(-2.2, 2.2) for _ in ys] for _ in xs])
	jy = np.array([[rnd.uniform(-2.2, 2.2) for _ in ys] for _ in xs])
	X, Y = np.meshgrid(xs, ys, indexing="ij")
	X, Y = X + jx, Y + jy
	d = F.at(np.stack((X.ravel(), Y.ravel(), np.full(X.size, 3.0)), 1)).reshape(X.shape)
	d = np.where((np.abs(X) > 150) | (np.abs(Y) > 68), np.maximum(d, 16), d)  # past the field's box
	nz = np.sin(X * 0.11 + 1.3 * np.sin(Y * 0.13)) + np.sin(Y * 0.17 + X * 0.07)
	reach = 27 + 9 * nz  # how far the heap runs out, ragged
	rag = 5 * np.sin(X * 0.13 + 0.8) + 4 * np.sin(X * 0.31 + 2)
	edge = np.maximum(np.maximum(np.abs(X) - 128 + rag, Y - 46 + rag * 0.9), -Y - 54 + rag) / 19
	t = np.clip(1 - np.maximum(d, 0) / np.maximum(reach, 8) - np.clip(edge, 0, 1), 0, 1)
	hgt = 8.0 * np.clip(t - 0.12, 0, 1) ** 2 * (0.85 + 0.25 * nz)
	# banks the body sank into: chin, forearm, belly, hind foot, tail (x, y, height, radius)
	for bx_, by_, bh, br in BANKS:
		hgt = np.maximum(hgt, np.clip((58 - Y - 0.4 * rag) / 15, 0, 1) ** 1.6 * bh * np.exp(-(((X - bx_) ** 2 + ((Y - by_) * 1.5) ** 2) / br**2)) * (0.9 + 0.12 * nz))
	crack = np.abs(np.sin(np.arctan2(Y, X * 0.5) * 11 + 1.6 * np.sin(d * 0.16) + nz)) < 0.1
	crack &= (d > 4) & (t > 0.3)
	hgt = hgt * np.clip((60 + 0.3 * rag - Y) / 14, 0, 1) ** 1.4 * np.clip((147 + 0.4 * rag - np.abs(X)) / 18, 0, 1) ** 1.4  # level with the plain at the road side and both ends
	hgt = np.where(crack, hgt - 0.9, hgt)
	fade = np.clip(t / 0.3, 0, 1)  # the outer band runs down through the ground, in the ground's own colour
	hgt = hgt * fade**1.5 - 0.25 * (1 - fade) + 0.06 * fade
	me = bpy.data.meshes.new("KaijuBermTmp")
	verts, faces, vi = [], [], {}
	T = {}

	def vert(i, j):
		if (i, j) not in vi:
			vi[i, j] = len(verts)
			verts.append((float(X[i, j]), float(Y[i, j]), float(hgt[i, j])))
			T[vi[i, j]] = (float(t[i, j]), bool(crack[i, j]), float(nz[i, j]))
		return vi[i, j]

	for i in range(len(xs) - 1):
		for j in range(len(ys) - 1):
			cs = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
			for tri in ((cs[0], cs[1], cs[2]), (cs[0], cs[2], cs[3])):
				if max(t[c] for c in tri) > 0.01 and min(d[c] for c in tri) < 60 and max(d[c] for c in tri) > -3:
					faces.append(tuple(vert(*c) for c in tri))
	me.from_pydata(verts, [], faces)
	me.update()
	cols = [k.mat(c, 1.0) for c in BERM] + [k.mat("3A342E", 1.0)]
	for m in cols:
		me.materials.append(m)
	for p in me.polygons:
		ts = [T[v] for v in p.vertices]
		q = sum(v[0] for v in ts) / 3 + 0.06 * ts[0][2]
		n_ = len(BERM)
		p.material_index = n_ if sum(v[1] for v in ts) >= 2 else max(0, min(n_ - 1, int((1 - (q - 0.3) / 0.5) * (n_ - 1) + 0.999)))
		p.use_smooth = q < 0.4
	return me


BANKS = [(124, 46, 3.6, 15), (76, 49, 5.2, 14), (34, 52, 4.4, 13), (6, 50, 5.2, 13), (-34, 50, 5.4, 12), (-80, 52, 4.2, 12), (-120, 48, 3.5, 13), (98, 46, 5.4, 11)]


def pose(p, n0, at, yaw=0.0, pitch=0.0, roll=0.0):
	"""Turns parts p[n0:], built round the local origin, as one rigid piece and moves them to `at` (Roblox axes)."""
	R = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ Matrix.Rotation(math.radians(-roll), 3, "Y")
	for i in range(n0, len(p)):
		shape, size, (px, py, pz), col, o = p[i]
		v = R @ Vector((px, -pz, py))
		rx, ry, rz = o.get("rot", (0, 0, 0))
		M = R @ Matrix.Rotation(math.radians(ry), 3, "Z") @ Matrix.Rotation(math.radians(rx), 3, "X") @ Matrix.Rotation(math.radians(-rz), 3, "Y")
		e = M.to_euler("YXZ")
		p[i] = (shape, size, (at[0] + v.x, at[1] + v.z, at[2] - v.y), col, {**o, "rot": (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y))})


def wreck(p, rnd, x, z, w, dp, floors, yaw, pitch, roll, y=-3.0, tone="9AA2AA"):
	"""A broken building of the city (the Office's language): floors of uneven height, each slipped a little on the one
	below, dusty at the bottom; window bands, some blown out; the upper corner sheared off step by step, the last floor
	only a bare slab; rebar, scorch. Tilted as one piece and let down until its whole base is buried."""
	n0, yy = len(p), 0.0
	for f in range(floors):
		fh = rnd.uniform(4.6, 7.2)
		cut = max(0.0, (f - floors * 0.35) / floors) * rnd.uniform(0.75, 1.15)
		fw, ox = w * (1 - cut), -w * cut / 2 + rnd.uniform(-0.8, 0.8)
		a, oz = rnd.uniform(-5, 5), rnd.uniform(-0.8, 0.8)
		col = ("8C8478", "928C82", tone)[min(2, f)] if rnd.random() < 0.8 else "7E7870"
		if f == floors - 1:  # bare top slab, snapped
			bx(p, (fw * 0.7, 1.1, dp * 0.8), (ox, yy + 0.4, oz), "757A7E", rot=(rnd.uniform(-9, 9), a, rnd.uniform(-14, 6)))
		else:
			if f == floors - 2:  # a corner broken out
				bx(p, (fw * 0.58, fh, dp), (ox - fw * 0.21, yy + fh / 2, oz), col, rot=(0, a, 0))
				bx(p, (fw * 0.42, fh * 0.8, dp * 0.5), (ox + fw * 0.29, yy + fh * 0.4, oz + dp * 0.24), "6A655E", rot=(0, a, 0))
				bx(p, (fw * 0.6, 1.0, dp + 1.2), (ox - fw * 0.22, yy + fh - 0.4, oz), "6C7074", rot=(0, a, rnd.uniform(-2, 2)))
				bx(p, (fw * 0.4, fh * 0.45, dp + 0.5), (ox - fw * 0.24, yy + fh * 0.42, oz), rnd.choice(("465866", "1C1E22")), rot=(0, a, 0))
				yy += fh
				continue
			bx(p, (fw, fh, dp), (ox, yy + fh / 2, oz), col, rot=(0, a, 0))
			bx(p, (fw + 1.2, 1.0, dp + 1.2), (ox, yy + fh - 0.4, oz), "6C7074", rot=(0, a, rnd.uniform(-2, 2)))
			bx(p, (fw * rnd.uniform(0.55, 0.88), fh * 0.45, dp + 0.5), (ox + rnd.uniform(-1, 1), yy + fh * 0.42, oz), rnd.choice(("465866", "3C4A56", "1C1E22")), rot=(0, a, 0))
			bx(p, (fw + 0.5, fh * 0.45, dp * 0.7), (ox, yy + fh * 0.42, oz), rnd.choice(("3C4A56", "1C1E22")), rot=(0, a, 0))
			if cut > 0.08:  # torn floor hanging from the sheared corner, rebar
				bx(p, (w * cut * 0.9, 0.9, dp * rnd.uniform(0.4, 0.8)), (w / 2 - w * cut * 0.5, yy + rnd.uniform(0, 2), rnd.uniform(-2, 2)), "8A867E", rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), rnd.uniform(-40, -12)))
				cab(p, (ox + fw / 2, yy + 2, rnd.uniform(-dp / 3, dp / 3)), (ox + fw / 2 + rnd.uniform(2, 5), yy + rnd.uniform(1, 5), rnd.uniform(-dp / 3, dp / 3)), RUST, thick=0.5)
		yy += fh
	bx(p, (w * 0.32, yy * 0.34, dp + 0.9), (w * rnd.uniform(-0.2, 0.25), yy * 0.36, 0), SCORCH, rot=(0, 0, rnd.uniform(-9, 9)))
	R = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X") @ Matrix.Rotation(math.radians(-roll), 3, "Y")
	high = max((R @ Vector((sx * w / 2, sz * dp / 2, 0))).z for sx in (-1, 1) for sz in (-1, 1))
	pose(p, n0, (x, min(y, -high - 1.2), z), yaw, pitch, roll)
	p.append(("cone", (w * 1.45, 4.2, dp * 1.7), (x, 1.1, z), "7A7368", {"seg": 9, "taper": 0.62, "rot": (0, yaw, 0)}))  # its own debris heaped at the foot
	for q in range(5):
		a = math.radians(yaw) + rnd.uniform(0, math.tau)
		s_ = rnd.uniform(1.4, 3.2)
		bx(p, (s_ * 1.5, s_ * 0.7, s_), (x + math.cos(a) * w * 0.62, 1.6, z + math.sin(a) * dp * 0.75), rnd.choice((CONC2, "8E8A82", "757A7E")), rot=(rnd.uniform(-25, 25), rnd.uniform(0, 90), rnd.uniform(-25, 25)))


def flat_car(p, x, y, z, col, yaw, crush=1.0, roll=0.0):
	"""A crushed car: low body, caved cabin, dark glass, wheels as two axles."""
	n0 = len(p)
	bx(p, (9.0, 2.0, 4.2), (0, 1.4, 0), col)
	p.append(("wedge", (4.2, 1.6 * crush, 4.6), (0.4, 2.4 + 0.8 * crush, 0), "2A3440", {"rot": (0, 90, 8)}))
	bx(p, (4.0, 0.4, 3.9), (-0.2, 2.5 + 1.2 * crush, 0.2), col, rot=(rnd_tilt(x), 0, -9))
	for wx in (-2.9, 2.9):
		p.append(("cyl", (1.9, 4.5, 1.9), (wx, 0.7, 0), "1C1C1E", {"seg": 5, "rot": (90, 0, 0)}))
	pose(p, n0, (x, y, z), yaw, 0, roll)


def rnd_tilt(x):
	return 7 if int(x) % 2 else -8


def crew(p, x, y, z, s=1.0, face=0.0, bend=0.0, arms=(-32, -32)):
	"""A Monster Sweeper at figure scale, plain white suit, no mark of any kind (about 130 tris): hood, dark goggles, pack."""
	n0 = len(p)
	p.append(("cyl", (2.2, 2.7, 1.7), (0, 2.6, 0), SUIT, {"seg": 6, "taper": 0.8, "smooth": True}))
	p.append(("ball", (2.2, 2.3, 2.2), (0, 4.8, 0.1), SUIT, {"subdiv": 1, "smooth": True}))
	bx(p, (1.2, 0.4, 0.14), (0, 5.0, -0.93), "16181C")
	bx(p, (1.5, 2.8, 1.0), (0, 3.2, 1.2), "5A6A44")
	bx(p, (2.1, 0.35, 1.8), (0, 1.6, 0), "2A2A2E")
	for sd in (-1, 1):
		bx(p, (0.75, 2.4, 0.8), (sd * 1.35, 2.9, -0.5), SUIT, rot=(arms[sd > 0], 0, sd * 10))
		bx(p, (0.85, 1.9, 1.0), (sd * 0.5, 0.5, 0), SUIT)
	for i in range(n0, len(p)):
		sh, size, pos, col, o = p[i]
		p[i] = (sh, tuple(v * s for v in size), tuple(v * s for v in pos), col, o)
	pose(p, n0, (x, y, z), face, bend, 0)


def kaiju_corpse(k):
	"""Dead kaiju (hero, reworked 2026-11-25): an invented generic beast, whole and unwounded, collapsed on its belly and
	rolled a little to the road, curled so the neck turns the head to the road and the tail wraps round in front. One
	continuous body (corpse_field): shoulder, ribs, hip, jointed limbs and digits, slack jaw, dorsal keels on the back.
	It lies in a heap of churned, cracked earth among the building edges it crushed. Monster Sweeper cleanup, light: two teal
	gantries, ropes, a few crew. About 300 x 130 on the ground, the head at +X, its front (-Z) to the road."""
	from mathutils.bvhtree import BVHTree

	rnd = random.Random(8008)
	body, F = corpse_body(k)
	tree = BVHTree.FromPolygons([v.co[:] for v in body.vertices], [p.vertices[:] for p in body.polygons])

	def top(x, z):
		"""Height of the body's top at a Roblox local (x, z), or None beside it."""
		hit = tree.ray_cast(Vector((x, -z, 200)), Vector((0, 0, -1)))[0]
		return hit.z if hit else None

	def flank(x, y):
		"""Roblox local z of the road-side skin at (x, height y), or None."""
		hit = tree.ray_cast(Vector((x, 90, y)), Vector((0, -1, 0)))[0]
		return -hit.y if hit else None

	berm = corpse_berm(k, F, random.Random(77))
	btree = BVHTree.FromPolygons([v.co[:] for v in berm.vertices], [p.vertices[:] for p in berm.polygons])

	def ground(x, z):
		"""Height of the churned earth at a Roblox local (x, z), 0 off it."""
		hit = btree.ray_cast(Vector((x, -z, 60)), Vector((0, 0, -1)))[0]
		return max(0.0, hit.z) if hit else 0.0

	def hug(path):
		"""A rope's path resampled every 1.5 studs, each point pushed out of the body along the field, then thinned to
		the fewest straight pieces that stay outside the skin."""
		np, P = F.np, []
		for a, b in zip(path, path[1:]):
			n = max(1, int(math.dist(a, b) / 1.5))
			P += [[a[m] + (b[m] - a[m]) * q / n for m in range(3)] for q in range(n)]
		P = np.array(P + [list(path[-1])])
		B = np.stack((P[:, 0], -P[:, 2], P[:, 1]), 1)
		for _ in range(12):
			f = F.at(B)
			g = np.stack([F.at(B + e) - F.at(B - e) for e in np.eye(3)], 1)
			g /= np.maximum(np.linalg.norm(g, axis=1), 1e-6)[:, None]
			B = B + g * np.maximum(1.0 - f, 0)[:, None].clip(0, 1.2)
		out, i = [0], 0
		while i < len(B) - 1:
			j = i + 1
			while j + 1 < len(B):
				t = np.linspace(0, 1, 8)[:, None]
				ch = B[i] + (B[j + 1] - B[i]) * t
				dev = np.abs(B[i : j + 2] - (B[i] + (B[j + 1] - B[i]) * np.linspace(0, 1, j + 2 - i)[:, None])).max()
				if F.at(ch).min() < 0.55 or dev > 2.2:
					break
				j += 1
			out.append(j)
			i = j
		return [(float(B[n][0]), float(B[n][2]), float(-B[n][1])) for n in out]

	kc = []
	for i in range(16):  # stand-ins for the parts fallback; swapped for the body mesh below
		x, y, z, r = spine_at((i + 0.5) / 16)
		kc.append(("ball", (2.1 * r, 2 * r, 2 * r), (x, z, -y), STANDIN, {"subdiv": 1}))
	hx, hy, hz = head_pt(14, 0, 2)
	kc.append(("box", (48, 22, 24), (hx, hz, -hy), STANDIN, {"rot": (0, math.degrees(HEAD_YAW), 0)}))
	for js in LIMBS.values():
		for a, b in zip(js, js[1:]):
			seg(kc, (a[0], a[2], -a[1]), (b[0], b[2], -b[1]), STANDIN, thick=1.6 * min(a[3], b[3]))
	def skin(a, b):
		"""First hit of the body from a toward b (mesh frame) as (point, normal), or None."""
		v = Vector(b) - Vector(a)
		h = tree.ray_cast(Vector(a), v.normalized(), v.length)
		return (h[0], h[1]) if h[0] else None

	def R_(v):
		return (v[0], v[2], -v[1])

	# teeth: uneven, rooted through the lip line; claws out of their cuffs, pressed down; the lids' dark slits
	hax = head_axes()
	for v in (-1, 1):
		up_ = Vector(hax[2])
		for i in range(8):  # rooted: each stands where a ray from the open mouth meets its jaw
			u = 11 + i * 3.3 + rnd.uniform(-0.5, 0.5)
			for low in (0, 1):
				lat = v * ((10.2 - 0.075 * i * i) * (0.86 if low else 1.0)) + (u * 0.08 if low else 0)
				ln = rnd.choice((2.4, 3.4, 4.8)) * (0.8 if low else 1.0)
				o = Vector(head_pt(u, lat, -6.4))
				h = tree.ray_cast(o, -up_ if low else up_, 12)
				if not h[0] or abs(h[1].dot(up_)) < 0.2:
					continue
				c = h[0] + up_ * (ln * 0.28 if low else -ln * 0.28)
				kc.append(("cone", (1.5 + ln * 0.22, ln + 1.4, 1.5 + ln * 0.22), R_(c), "D8CDB0", {"seg": 5, "rot": ((0 if low else 180) + math.degrees(HEAD_ROLL) * 0.7, 0, 0)}))
		hits = [skin(head_pt(u, v * 30, w), head_pt(u, 0, w)) for u, w in ((12, 7.4), (8.5, 7.4), (15.5, 7.4), (12, 5), (12, 9.4))]
		hits = [h for h in hits if h]
		if hits:  # the closed eye: a lid cap in hide colour on a darker rim cap, both square to the skin, and its crease
			c = hits[0][0]
			n = sum((h[1] for h in hits), Vector()).normalized()
			a = (Vector(hax[0]) - n * Vector(hax[0]).dot(n)).normalized()
			w_ = a.cross(n) if a.cross(n).dot(Vector(hax[2])) > 0 else n.cross(a)
			M = Matrix((a, w_.cross(a), w_)).transposed()
			e = M.to_euler("YXZ")
			rot = (math.degrees(e.x), math.degrees(e.z), -math.degrees(e.y))
			kc.append(("ball", (11.0, 7.8, 3.4), R_(c - n * 0.75), "4A3028", {"subdiv": 2, "smooth": True, "rot": rot}))
			kc.append(("ball", (9.4, 6.2, 5.2), R_(c - n * 1.0), "6E4A3B", {"subdiv": 2, "smooth": True, "rot": rot}))
			pts = []
			for q in range(8):
				x_, y_ = -3.75 + q * 7.5 / 7, -0.5 - 0.5 * math.sin(q / 7 * math.pi)
				z_ = 2.6 * math.sqrt(max(0.0, 1 - (x_ / 4.7) ** 2 - (y_ / 3.1) ** 2)) - 1.12
				pts.append(R_(c + a * x_ + w_ * y_ + n * z_))
			for p_, q_ in zip(pts, pts[1:]):
				cab(kc, p_, q_, "2A1A16", thick=0.5)
		kc.append(("ball", (3.6, 2.8, 2.4), R_(head_pt(39.4, v * 4.2, 4.8)), "20140F", {"subdiv": 1}))  # nostril
	for name, js in LIMBS.items():
		px, py, pz, pr = js[-1]
		for dx, dy in DIGITS[name]:
			ax = math.degrees(math.atan2(dy * 0.15, dx * 0.43))
			tx, ty, tz = px + dx * 1.15 + 1.2, py + dy * 1.15, max(pz - 2.4, 4.2)
			n0 = len(kc)
			kc.append(("cone", (3.3, 3.2, 3.3), (1.2, 0.2, 0), "CFC3A4", {"seg": 6, "taper": 0.7, "rot": (0, 0, -100)}))
			kc.append(("cone", (2.35, 4.6, 2.35), (4.5, -1.2, 0), "EADFC4", {"seg": 6, "rot": (0, 0, -122)}))
			pose(kc, n0, (tx, tz, -ty), ax)
	# buildings it came down on: pinned under jaw, chest, hind leg and tail, the rest pushed over behind
	for x, z, w, dp, fl, yaw, pitch, roll, y, tone in (
		(103, -41, 18, 13, 5, 20, 8, 20, -2, "D9D0BC"), (26, -49, 24, 12, 3, 4, 14, 32, -2, "AEB6BE"), (-34, -50, 22, 11, 3, -6, 12, -28, -2, "D9D0BC"),
		(-103, -30, 24, 18, 5, -20, 12, -18, -4, "AEB6BE"), (-100, 48, 26, 15, 5, 12, -24, 10, -4, "AEB6BE"), (82, 41, 25, 17, 6, -18, -20, -10, -4, "D9D0BC"), (120, 8, 18, 16, 4, 30, -10, 24, -3, "AEB6BE"),
	):
		if x == 103:  # the jaw's: its own stream, so the rest of the site stays put
			wreck([], rnd, x, z, w, dp, fl, yaw, pitch, roll, y, tone)
			wreck(kc, random.Random(31), 102, -43, 20, 13, 4, 14, 10, 31, -2, "8E9296")
			continue
		wreck(kc, rnd, x, z, w, dp, fl, yaw, pitch, roll, y, tone)
	for x0, yy in ((14, 20), (-70, 16)):  # facade slabs thrown up against the hide
		h = skin((x0, 90, yy), (x0, -90, yy))
		if not h:
			continue
		n0 = len(kc)
		w = rnd.uniform(9, 13)
		bx(kc, (w, 15, 1.2), (0, 0, 0), rnd.choice(("8E959B", "A79F90")))
		bx(kc, (w * 0.8, 2.6, 1.5), (0.6, 1.2, 0), "2C3640")
		bx(kc, (w * 0.5, 5, 1.1), (w * 0.36, 8, 0), "8E959B", rot=(0, 0, 24))
		z = min(-h[0].y - 2.5, -14)
		pose(kc, n0, (x0, yy * 0.5, max(z, -56)), rnd.uniform(-20, 20), -38, rnd.uniform(-30, 30))
	h = skin((-2, 90, 20), (-2, -90, 20))
	if h:  # a floor slab folded against the belly
		z0 = -h[0].y
		n0 = len(kc)
		bx(kc, (20, 1.4, 11), (0, 0, -4.6), "8A867E")
		pose(kc, n0, (-2, 5, max(z0 - 4, -56)), 6, 22, 0)
		n0 = len(kc)
		bx(kc, (20, 1.4, 13), (0, 6, 0), "7E7A72")
		pose(kc, n0, (-2, 6, max(z0 - 1.5, -54)), 6, -70, 0)
		for q in (-6, 0, 6):
			cab(kc, (-2 + q, 6, z0 - 4), (-2 + q + 1, 9, z0 - 5), RUST, thick=0.5)
	# broken street: tilted asphalt and concrete slabs thick at the body, thinning outward; rubble; kerbs
	for i in range(130):
		x, z = rnd.uniform(-143, 143), rnd.uniform(-60, 57)
		d = float(F.at(F.np.array([[x, max(-68, min(68, -z)), 3.0]]))[0])
		if not 1 < d < 36 or rnd.random() > 1.2 - d / 36 or top(x, z):
			continue
		s_ = rnd.uniform(2.2, 6.0) * (1.1 - d / 46)
		g = ground(x, z)
		if i % 2:  # street slabs, flatter and smaller with distance
			tl = 20 * max(0.1, 1 - d / 22)
			bx(kc, (s_ * 1.9, 0.8, s_ * 1.4), (x, g + 0.15, z), rnd.choice(("4E4E50", "625E58", "77716A", "8A857C")), rot=(rnd.uniform(-tl, tl), rnd.uniform(0, 90), rnd.uniform(-tl, tl)))
		else:
			bx(kc, (s_ * rnd.uniform(0.7, 1.4), s_ * 0.6, s_ * 0.8), (x, g + s_ * 0.12, z), rnd.choice((CONC2, "A09A8E", ROCK, "8E8A82")), rot=(rnd.uniform(-25, 25), rnd.uniform(0, 90), rnd.uniform(-25, 25)))
	for i in range(120):  # broken asphalt over the earth's outer edge: road side, tail end, head end, thinning outward
		if i % 4 == 3:
			x, z = rnd.choice((-1, 1)) * rnd.uniform(126, 147), rnd.uniform(-58, 30)
		else:
			x, z = rnd.uniform(-138, 136), -rnd.uniform(49, 60.5)
		d = float(F.at(F.np.array([[x, max(-68, min(68, -z)), 3.0]]))[0])
		if not 1.5 < d < 30 or top(x, z):
			continue
		s_ = rnd.uniform(1.4, 4.4) * (1.1 - d / 40)
		kc.append(("cyl", (s_ * 1.7, 0.7, s_ * rnd.uniform(0.9, 1.5)), (x, ground(x, z) + 0.12, z), rnd.choice(("5A5854", "6C6862", "7A756D", "847F76", "87827A")), {"seg": rnd.choice((3, 4, 5)), "rot": (rnd.uniform(-9, 9), rnd.uniform(0, 120), rnd.uniform(-9, 9))}))
	# the road-side bank: crushed cars, street barriers, crew on the banks (they show over the road's barrier)
	for x, y, z, col, yaw, cr, ro in ((108, 1.5, -58, "B8342E", 24, 0.5, 10), (50, 4.0, -60, "D8D8D4", -12, 0.3, -14), (-62, 2.5, -59, "2F5FA8", 14, 0.5, 8), (-96, 1.2, -59.5, "C8A838", -30, 0.7, 4), (-136, 0.2, -46, "8A9098", 60, 0.6, 0)):
		flat_car(kc, x, ground(x, z) - 0.2, z, col, yaw, cr, ro)
	for x, z, yaw in ((132, -60, 8), (122, -61, -6), (-44, -61, 4), (-72, -61, -10), (-110, -61, 12)):  # concrete street barriers
		g = ground(x, z)
		bx(kc, (9, 1.6, 2.4), (x, g + 0.4, z), "8E9298", rot=(0, yaw * 2, 0))
		bx(kc, (9, 2.2, 1.0), (x, g + 2.0, z), "A4A8AC", rot=(0, yaw * 2, 0))
	for x, z, f, bd, ar in ((105, -50, 30, 0, (-95, -20)), (98, -57, 210, 4, (-40, -70)), (38, -57, 160, 0, (10, -140)), (-29, -54, 120, 6, (-60, -60)), (-47, -57.5, 20, 0, (-32, 8)), (119, -53, 60, 6, (-60, -10))):
		crew(kc, x, ground(x, z) + 0.75, z, 1.15, f, bd, ar)
	# stake line along the back with its rope, then ropes from stakes over the hide down to pegs in the ground
	stakes = []
	for i in range(10):
		x = -70 + i * 14.5
		z = 11 if x < 60 else 4
		y = top(x, z)
		if y and y > 30:
			stakes.append((x, y, z))
			seg(kc, (x - 1.0, y - 1.5, z), (x, y + 7, z), "8A8E94", thick=0.8)
	for a, b in zip(stakes, stakes[1:]):
		m = ((a[0] + b[0]) / 2, max((a[1] + b[1]) / 2 + 4.0, (top((a[0] + b[0]) / 2, (a[2] + b[2]) / 2) or 0) + 1), (a[2] + b[2]) / 2)
		cab(kc, (a[0], a[1] + 6.5, a[2]), m, "2A2622", thick=0.45)
		cab(kc, m, (b[0], b[1] + 6.5, b[2]), "2A2622", thick=0.45)
	for n_, (x, y, z) in enumerate(stakes):
		pts, q, last = [(x, y + 6.5, z)], z - 2, None  # along the body's upper surface toward the road, never through it
		while q > -60:
			t = top(x, q)
			if t is None:
				break
			pts.append((x, max(t, top(x, q - 1) or 0, top(x, q + 1) or 0) + 0.8, q))
			q -= 2
		reach = len(pts) if n_ % 3 == 0 else min(len(pts), (9, 14, 11)[n_ % 3] + n_ % 2 * 3)
		pts = pts[:reach]
		keep = [pts[0]]
		for a, m, b in zip(pts, pts[1:], pts[2:]):  # drop the points a straight piece already covers
			u = (m[2] - keep[-1][2]) / ((b[2] - keep[-1][2]) or 1)
			if abs(keep[-1][1] + (b[1] - keep[-1][1]) * u - m[1]) > 0.5:
				keep.append(m)
		keep.append(pts[-1])
		lx, ly, lz = keep[-1]
		col = (ROPE_B, ROPE_Y, "2E9A96")[n_ % 3]
		if n_ % 3 == 0:  # to the ground, over the edge, tied to a weight
			gz = max(lz - 2, -61)
			keep.append((x, ground(x, gz) + 1.6, gz))
			bx(kc, (2.2, 2.2, 2.2), (x, ground(x, gz) + 0.8, gz), "3A3E46")
		else:  # ends on a sweeper's harness
			crew(kc, lx, ly - 2.2, lz - 1.4, 1.2, 180 + (-24, 18, -8, 30)[n_ % 4], (-18, -6, -26)[n_ % 3], ((-120, -60), (-40, -110), (-90, -90))[n_ % 3])
		keep = hug(keep)
		for a, b in zip(keep, keep[1:]):
			cab(kc, a, b, col, thick=0.6)
	# two lattice gantries over the waist and the tail root, on footings, braced at the corners
	GH = 106.0
	for gx, zn, zf in ((-91, -62.5, 52), (-14, -58.5, None)):
		jib, end = zf is None, 20.0 if zf is None else zf
		for z in (zn,) if jib else (zn, zf):
			for x in (-3.5, 3.5):
				bx(kc, (1.3, GH, 1.3), (gx + x, GH / 2 - 1, z), TEAL, metal=0.4)
			for y in range(0, int(GH) - 24, 16):
				cab(kc, (gx - 3.5, y + 8, z), (gx + 3.5, y + 8, z), TEAL, thick=0.9)
				cab(kc, (gx - 3.5, y + 8, z), (gx + 3.5, y + 24, z), "286A66", thick=0.7)
			bx(kc, (12, 3.4, 4.4), (gx, 0.6, z), "6E6C68")  # footing
			inn = 1 if z < 0 else -1
			for x in (-3.5, 3.5):
				cab(kc, (gx + x, GH - 22, z), (gx + x, GH - 6, z + inn * 14), TEAL, thick=1.0)
		for x in (-3, 3):
			bx(kc, (1.2, 1.2, end - zn), (gx + x, GH, (zn + end) / 2), TEAL, metal=0.4)
			bx(kc, (1.0, 1.0, end - zn), (gx + x, GH - 7, (zn + end) / 2), TEAL, metal=0.4)
		for i in range(10):
			z0, z1 = zn + (end - zn) * i / 10, zn + (end - zn) * (i + 1) / 10
			a, b = (GH - 7, GH) if i % 2 else (GH, GH - 7)
			cab(kc, (gx + 3, a, z0), (gx + 3, b, z1), "286A66", thick=0.8)
		if jib:  # the body fills the lane behind, so this one is a mast with a stayed jib: no leg through the beast
			for x in (-3, 3):
				cab(kc, (gx + x, GH - 1, zn), (gx, GH + 8, zn), TEAL, thick=1.2)
				cab(kc, (gx, GH + 8, zn), (gx + x, GH, end - 2), "2A2622", thick=0.5)
			for dx in (-30, 46):  # guys to the ground along the road side, never toward the road
				cab(kc, (gx, GH + 8, zn), (gx + dx, 2.0, zn), "2A2622", thick=0.5)
				bx(kc, (3.4, 2.6, 2.6), (gx + dx, ground(gx + dx, zn) + 0.6, zn), "6E6C68")
		hz = -14 if jib else 14
		bx(kc, (9, 4, 7), (gx, GH - 3, hz), "E8C840")
		t = top(gx, hz)
		if t:  # the hoist's cable to a hook block, and a sling from it to both sides of the hide
			cab(kc, (gx, GH - 5, hz), (gx, t + 12, hz), "1A1A1C", thick=0.6)
			bx(kc, (2.6, 3, 2.6), (gx, t + 11, hz), "E8C840")
			for sx in (-9, 9):
				t2 = top(gx + sx, hz)
				if t2:
					cab(kc, (gx, t + 10, hz), (gx + sx, t2 + 0.4, hz), "2A2622", thick=0.6)
		cab(kc, (gx - 2, GH - 7, zn + 5), (gx - 4, 2.4, zn + 1), ROPE_B, thick=0.5)  # tag lines tied off at the footing
		cab(kc, (gx + 2, GH - 7, zn + 8), (gx + 4, 2.4, zn + 1), ROPE_Y, thick=0.5)
	for x, z in ((15, 8), (38, 16)):  # on the back
		y = top(x, z)
		if y:
			crew(kc, x, y + 0.6, z, 1.15, 40 + x * 4, 0, (-20, -100))
	ob = k.prop("KaijuCorpse", kc)
	me = ob.data
	bm = bmesh.new()
	bm.from_mesh(me)
	stand = me.materials.find(k.mat(STANDIN).name)
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == stand], context="FACES")
	bm.normal_update()
	co = F.np.array([v.co[:] for v in bm.verts])
	inside = F.at(co) < -1.6  # gear buried in the body, and what lies under the ground, never shows
	inside &= (F.np.abs(co[:, 0]) < 150) & (F.np.abs(co[:, 1]) < 68)
	bm.verts.index_update()
	hid = [f for f in bm.faces if all(inside[v.index] for v in f.verts) or all(v.co.z < 0.0 for v in f.verts) or (f.normal.z < -0.75 and all(v.co.z < 2.4 for v in f.verts))]
	print("KAIJU hidden faces dropped", len(hid))
	bmesh.ops.delete(bm, geom=hid, context="FACES")
	for part in (body, berm):
		remap = []
		for m in part.materials:
			if me.materials.find(m.name) < 0:
				me.materials.append(m)
			remap.append(me.materials.find(m.name))
		for p in part.polygons:
			p.material_index = remap[p.material_index]
		bm.from_mesh(part)
	# nothing hangs under the ground: whatever was sunk is cut 0.8 below it
	bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, -0.8), plane_no=(0, 0, 1), clear_inner=True)
	bm.to_mesh(me)
	bm.free()
	me.calc_loop_triangles()
	lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
	hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
	print("KAIJU tris", len(me.loop_triangles), "body", len(body.polygons), "size", [round(hi[i] - lo[i], 1) for i in (0, 2, 1)], "low", round(lo[2], 2))
	return ob



SITES = ((1057.0, -92.0, 1.0, -2.0), (2683.0, -91.0, 1.0, -1.0))  # d, off, scale, turn (degrees): the two legal pockets beside Track 5's city half

FILL = []  # (x, z, prop) of the last build's added fill, for kaiju_reference.py


def other_draft_boxes(label="on disk", folder=None, tracks=None):
	"""Every prop of the other tracks' Draft files as boxes shaped like export_props.draft_boxes rows (centre, rows, half
	size, track, prop), CLEAR_EXEMPT props included (the owner's ruling for the fill: no other track's scenery at all).
	Default: the Draft files on disk of this checkout, under export_props' track numbers. A caller may name another folder
	and its full {track: biome} table; a missing folder, track or file stops the build. Prints the files used."""
	import hashlib
	import os
	import re

	import export_props as ep
	import numpy as np

	if (folder is None) != (tracks is None):
		raise SystemExit("other_draft_boxes: a folder and its track table go together")
	folder, tracks = folder or ep.THEMES, tracks or ep.APPROVED
	if not os.path.isdir(folder):
		raise SystemExit("other_draft_boxes: no folder %s" % folder)
	origins, out = ep.origins(), []
	missing = [n for n in origins if n != 5 and n not in tracks]
	if missing or len(set(tracks.values())) != len(tracks):
		raise SystemExit("other_draft_boxes: tracks without a biome %s, or a biome named twice: %s" % (missing, tracks))
	for number, (origin, yaw) in origins.items():
		if number == 5:
			continue
		path = os.path.join(folder, tracks[number] + "Draft.luau")
		if not os.path.isfile(path):
			raise SystemExit("other_draft_boxes: no Draft file %s for track %d" % (path, number))
		src, n0 = open(path).read(), len(out)
		sizes = {a: [float(x) for x in v.split(",")] for a, v in re.findall(r"\n\t\t(\w+) = \{\n\t\t\tSize = v\(([^)]*)\)", src)}
		for m in re.finditer(r'\{ "(\w+)", ([^{}]*?) \},\n', src[src.index("\tPlaced = {") : src.index("\tHeroes = ")]):
			name, rest = m.group(1), m.group(2).split(", Group")[0]
			nums = [float(x) for x in rest.split(", v(")[0].split(",")]
			st = re.search(r"v\(([^)]*)\)", rest)
			sc = [float(x) for x in st.group(1).split(",")] if st else [nums[4]] * 3
			R = np.array(ep.yaw_rot(yaw)) @ np.array(ep.from_euler_yxz(*((nums[5], nums[3], nums[6]) if len(nums) > 6 else (0.0, nums[3], 0.0))))
			size = np.array(sizes[name]) * np.array(sc)
			out.append((np.array(ep.to_world(origin, yaw, nums[:3])) + R @ np.array([0.0, size[1] / 2, 0.0]), R, size / 2, number, name))
		print("KAIJUBASE drafts %s: T%d %s %d props sha256 %s" % (label, number, path, len(out) - n0, hashlib.sha256(src.encode()).hexdigest()[:12]))
	return out


def instance_box(ob):
	"""A placed prop's box in the game, as export_props.hero_box gives it: (centre, rows, half size), Roblox world."""
	import export_props as ep
	import numpy as np

	m3 = [[ob.matrix_world[i][j] for j in range(3)] for i in range(3)]
	scl = [math.sqrt(sum(m3[i][j] ** 2 for i in range(3))) for j in range(3)]
	R = np.array(ep.rb_matrix([[m3[i][j] / scl[j] for j in range(3)] for i in range(3)]))
	lo, hi = (np.array(v) * (scl[0], scl[2], scl[1]) for v in ep.bounds(ob.data))
	return np.array(ep.rb_of(ob.matrix_world.translation)) + R @ ((lo + hi) / 2), R, (hi - lo) / 2


def overlapped(box, boxes):
	"""Track number -> how many of `boxes` (draft_boxes) the box (instance_box) overlaps."""
	import export_props as ep
	import numpy as np

	c, R, h = box
	ext, out = np.abs(R) @ h, {}
	for bc, bR, bh, t, _ in boxes:
		if np.all(np.abs(c - bc) < ext + np.abs(bR) @ bh) and ep.obb_overlap(c, R, h, bc, bR, bh):
			out[t] = out.get(t, 0) + 1
	return out


# Owner 2026-11-25 "A with 12": left out of fill draft A, (x, z, prop); each touches a van as placed.
LEFT_OUT = ((-471.8, 875.3, "Apartment"), (-613.6, 876.6, "Apartment"))


def cut_fill(k, label, boxes):
	"""Owner 2026-11-25: the site fill (k.fill) keeps only props clear of every other track's scenery, box against box, less
	LEFT_OUT."""
	bpy.context.view_layer.update()
	pre, stays, cut, by, left, out = "W2_%s_" % k.biome, {}, {}, {}, [], set()
	for ob in k.fill:
		name, hit = ob.data.name[len(pre) :], overlapped(instance_box(ob), boxes)
		if not hit and any(name == n and abs(ob.location.x - x) < 0.2 and abs(-ob.location.y - z) < 0.2 for x, z, n in LEFT_OUT):
			hit = {"owner": 1}
			out.add((round(ob.location.x, 1), round(-ob.location.y, 1), name))
		for t in hit:
			by[t] = by.get(t, 0) + 1
		(cut if hit else stays)[name] = (cut if hit else stays).get(name, 0) + 1
		if hit:
			bpy.data.objects.remove(ob)
		else:
			left.append(ob)
	print("KAIJUBASE owner left out", sorted(out))
	k.fill = left
	FILL[:] = [(o.location.x, -o.location.y, o.data.name[len(pre) :]) for o in left]
	print("KAIJUBASE fill against drafts %s: kept" % label, len(left), stays, "removed", sum(cut.values()), cut, "removed props by track", dict(sorted(by.items(), key=str)))


def corpse_sites(k, city_end, windows, avoid, tall_avoid):
	"""The corpses in their legal pockets and the city closed up round them (reopened by the owner 2026-11-25). Additive, on
	its own random stream: the frozen instances are not touched, except the ones a body lies on, which it crushed."""
	rng = random.Random(525)
	frames = []
	for d, off, sc, turn_ in SITES:
		pos, yaw = k.beside(d, off)
		yaw += math.radians(turn_) - math.pi / 2
		k.place("KaijuCorpse", (pos[0], -1.0, pos[2]), yaw, sc)
		frames.append((Vector((pos[0], -pos[2], 0)), yaw, sc))

	def near_body(x, z, mx, mz):
		"""Inside a corpse's footprint (165 x 78 half) grown by mx along and mz across it."""
		for c, yaw, sc in frames:
			v = Matrix.Rotation(-yaw, 3, "Z") @ (Vector((x, -z, 0)) - c)
			if abs(v.x) < 165 * sc + mx and abs(v.y) < 78 * sc + mz:
				return True
		return False

	fixed = ("Wall", "Dash", "Apron", "WinPad", "Road", "Ground", "Pier", "KaijuCorpse")
	pre = "W2_%s_" % k.biome
	gone = {}
	for ob in list(k.col.objects):  # what a body lies on
		name = ob.data.name[len(pre) :] if ob.type == "MESH" and ob.data.name.startswith(pre) else ""
		if not name or name in fixed:
			continue
		r = {"CityBlock": 55, "Rubble": 4}.get(name, 12)
		if near_body(ob.location.x, -ob.location.y, r, r):
			gone[name] = gone.get(name, 0) + 1
			bpy.data.objects.remove(ob)
	print("KAIJUBASE crushed", gone)
	kept = set(k.col.objects)

	def fill(d, off, names, sc, turn, lean):
		pos, _ = k.beside(d, off)
		if near_body(pos[0], pos[2], 24, 22) or not k.clear_of_road(pos[0], pos[2], abs(off) - 1):
			return
		ob = put(k, rng.choice(names), d, off, sc, turn=rng.uniform(-turn, turn))
		if ob and rng.random() < lean:
			ob.rotation_euler[0] = math.radians(rng.choice((-1, 1)) * rng.uniform(4, 9))
			ob.location.z -= 3.0

	for a, b in windows:  # the street rows again, where the old clearings left a bare apron
		d = max(a, 40.0)
		while d < min(b, city_end):
			for off, names, sc in ((64, ["Apartment", "Apartment", "Office"], 1.0), (-64, ["Apartment", "Apartment", "Office"], 1.0), (112, ["Office", "Apartment"], 1.25), (-112, ["Office", "Apartment"], 1.25)):
				if rng.random() < 0.86:
					fill(d + rng.uniform(-5, 5), off + rng.uniform(-3, 3) * (1 if off > 0 else -1), names, sc * rng.uniform(0.85, 1.15), 0.25, 0.3)
			d += 48
	for (c, yaw, sc), (d, off, _, _) in zip(frames, SITES):  # broken towers leaning in over the body, rubble at its ends
		for lx in (-150, -95, -35, 30, 92, 150):
			v = c + Matrix.Rotation(yaw, 3, "Z") @ Vector((lx + rng.uniform(-8, 8), -112 - rng.uniform(0, 12), 0))
			if not k.clear_of_road(v.x, -v.y, 60):
				continue
			ob = k.place(rng.choice(("Office", "Apartment")), (v.x, -4.0, -v.y), yaw + math.pi + rng.uniform(-0.4, 0.4), rng.uniform(0.9, 1.35))
			ob.rotation_euler[0] = math.radians(rng.uniform(-11, 5))
		for lx, ly in ((-178, 18), (-182, -26), (-168, -60), (174, -8), (170, -44), (184, 22), (-120, -84), (-40, -86), (50, -88), (120, -86)):
			v = c + Matrix.Rotation(yaw, 3, "Z") @ Vector((lx, ly, 0))
			if k.clear_of_road(v.x, -v.y, 44):
				k.place("Rubble", (v.x, -1.0, -v.y), rng.uniform(0, math.tau), rng.uniform(0.8, 1.15))
	# street blocks over what the old clearings left bare
	gx = k.lo.x - 400
	while gx < k.hi.x + 400:
		gz = k.lo.z - 400
		while gz < k.hi.z + 400:
			taken = any(math.hypot(gx - ax, gz - az) <= r for ax, az, r in avoid[: 1 + 2])  # the HQ and the cannons
			bare = any(math.hypot(gx - ax, gz - az) <= r for ax, az, r in avoid[1 + 2 :])
			if bare and not taken and k.clear_of_road(gx, gz, 190) and not near_body(gx, gz, 60, 60):
				k.place("CityBlock", (gx, -1.0, gz), rng.choice((0, 1, 2, 3)) * math.pi / 2)
				if rng.random() < 0.2 and all(math.hypot(gx - ax, gz - az) > r for ax, az, r in tall_avoid):
					k.place(rng.choice(("Office", "Apartment")), (gx, -1.0, gz), rng.choice((0, math.pi / 2, math.pi)), rng.uniform(1.0, 1.6))
			gz += 160
		gx += 160

	# the fill only counts where the game would build it: an instance on any track's road corridor goes (export drops it)
	import build_track
	import clearance
	import export_props

	corr = clearance.corridors(build_track.load_chain().values())
	bpy.context.view_layer.update()
	local_, drop = {}, {}
	import numpy as np

	for ob in [o for o in k.col.objects if o not in kept and o.type == "MESH"]:
		me = ob.data
		if me.name not in local_:
			local_[me.name] = export_props.local_tris(me, (0, 0, 0))
		m = np.array(ob.matrix_world)
		t = local_[me.name]
		b = np.stack((t[..., 0], -t[..., 2], t[..., 1]), -1) @ m[:3, :3].T + m[:3, 3]
		if clearance.intrudes(np.stack((b[..., 0], b[..., 2], -b[..., 1]), -1), corr):
			drop[me.name[len(pre) :]] = drop.get(me.name[len(pre) :], 0) + 1
			bpy.data.objects.remove(ob)
	# the bare apron round each body: city tiles, then rubble, on a fine grid, wherever every track's corridor allows it
	def legal(name, x, z, yaw_, sc_=1.0):
		me = k.props[name].data
		if me.name not in local_:
			local_[me.name] = export_props.local_tris(me, (0, 0, 0))
		c_, s_ = math.cos(yaw_), math.sin(yaw_)
		t = local_[me.name] * sc_
		return not clearance.intrudes(np.stack((x + t[..., 0] * c_ + t[..., 2] * s_, t[..., 1] - 1.0, z - t[..., 0] * s_ + t[..., 2] * c_), -1), corr)

	spots = {"CityBlock": [], "other": []}
	for ob in k.col.objects:
		if ob.type == "MESH" and ob.data.name.startswith(pre) and ob.data.name[len(pre) :] not in fixed:
			spots["CityBlock" if ob.data.name.endswith("CityBlock") else "other"].append((ob.location.x, -ob.location.y))
	apron = {}
	for name, step, reach, gap, gap2, mx in (("CityBlock", 40, 460, 160, 0, 82), ("Apartment", 34, 330, 80, 58, 34), ("Rubble", 24, 300, 70, 30, 18)):
		for c, _, _ in frames:
			n_ = int(reach // step)
			for i in range(-n_, n_ + 1):
				for j in range(-n_, n_ + 1):
					x, z = c.x + i * step, -c.y + j * step
					if name != "CityBlock":  # off the grid
						x, z = x + rng.uniform(-9, 9), z + rng.uniform(-9, 9)
					if math.hypot(i, j) * step > reach or near_body(x, z, mx, mx) or any(math.hypot(x - ax, z - az) < r for ax, az, r in avoid[:3]):
						continue
					if any(max(abs(x - a), abs(z - b)) < gap for a, b in spots["CityBlock"]) or any(math.hypot(x - a, z - b) < gap2 for a, b in spots["other"]):
						continue
					near_ = min(k.wps, key=lambda w: (w.x - x) ** 2 + (w.z - z) ** 2)
					yaw_, what, sc_ = rng.choice((0, 1, 2, 3)) * math.pi / 2, name, 1.0
					if name == "Apartment":  # windowed front (-Z) to the road, a mix of both buildings
						yaw_ = math.atan2(-(near_.x - x), -(near_.z - z)) + rng.uniform(-0.3, 0.3)
						what, sc_ = rng.choice(("Office", "Apartment", "Office")), rng.uniform(1.0, 1.5)
					elif name == "Rubble":
						yaw_, sc_ = rng.uniform(0, math.tau), rng.uniform(0.8, 1.1)
					if legal(what, x, z, yaw_, sc_) and k.clear_of_road(x, z, {"CityBlock": 120, "Apartment": 66, "Rubble": 46}[name]):
						k.place(what, (x, -1.0, z), yaw_, sc_)
						spots["CityBlock" if name == "CityBlock" else "other"].append((x, z))
						apron[what] = apron.get(what, 0) + 1
	k.fill = [o for o in k.col.objects if o not in kept and o.type == "MESH"]
	cut_fill(k, "on disk", other_draft_boxes())
	print("KAIJUBASE apron filled", apron)
	print("KAIJUBASE fill dropped by the corridor test", drop)


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
	# the frozen layout's clearings (round 16's corpse spots): the rows, streets and towers below still skip them, so the
	# random stream and every frozen instance stay exactly where the owner approved them; corpse_sites() fills them after
	corpses = [(800.0, -190.0, 1.0), (2750.0, -200.0, 1.0)]
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
	vans = [(740, -40), (780, -40), (820, -40), (865, -40), (2375, -40), (2415, -40), (2455, -40), (2500, -40)]
	for i, (d, off) in enumerate(vans):  # parked up the road from the corpses; every other van mirrored for variety
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
	corpse_sites(k, city_end, [(d - 460, d + 460) for d, _, _ in corpses], avoid, tall_avoid)
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
