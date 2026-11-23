"""World 2 Track 4: the haunted tunnel road (Dandadan), at night. Rebuilt 2026-11-23 for a closer 1-1 read of the source
(owner: "more detail and closer reference to source material"); landmarks and their references: docs/world2_refs/
HauntedTunnel.md. A rural Japanese town at night (tiled-roof houses, block walls, utility poles, glowing vending
machines), Seiko's house behind its stone torii and canal bridge, the mountain road (white W-beam guardrails, orange
curve mirrors, cedar forest, dark ridges), the old ivy-covered stone tunnel of Turbo Granny (horseshoe arch of dressed
stone, voussoir ring, yellow-black barriers pushed aside, sodium lamps on a round concrete lining), the white Kami High
building (pillar grid, glass stair tower, brick gate walls and green lattice gate) and the abandoned Nagi Hospital tower
under a blue moon.
Rules (design doc 5, WORLD2_SPEC): in-house primitives only; no text, no logos (boards are blank); props 24+ studs from
the centre line; the tunnel lining clears the road by 38. Budget: 12 unique meshes (road pieces excluded).
Proposed look; the owner approves the render set (design doc 4.46)."""

import math
import random

import bmesh
import bpy

import kit

CEDAR, CEDAR2, BARK = "1C3326", "243F2E", "3A2A20"
STONE, STONE2, STONE3, MORTAR = "6F7468", "5E6459", "7C8072", "3E423A"
IVY, IVY2, IVY3 = "2F5A2E", "3D6E35", "24482A"
LINING, LINING2 = "4C524A", "3A3F38"
TILE, TILE2, RIDGE = "3A3F4A", "2E323B", "23262D"
SODIUM, WARM, COOL, GLASS, DARKWIN = "FFB347", "FFD890", "BFE4FF", "7FA0B8", "141C26"
HAZ_Y, HAZ_K = "F2C230", "1A1A1A"
R, SPR = 27.0, 13.0  # tunnel inner radius and springline height (local y; local 0 is 1 below the road top)
TUNNEL = (1990.0, 2160.0)  # on the straight after the long bend; run shot 2 (1903) faces the entry portal


def bx(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def gable(p, x, z, w, d, y, h, col, rib, ribs=8):
	"""A kawara gable roof (ridge along X): two wedges, tile-row ribs down each slope and a ridge cap."""
	p.append(("wedge", (w, h, d / 2), (x, y + h / 2, z - d / 4), col))
	p.append(("wedge", (w, h, d / 2), (x, y + h / 2, z + d / 4), col, {"rot": (0, 180, 0)}))
	slope = math.degrees(math.atan2(h, d / 2))
	length = math.hypot(h, d / 2)
	for i in range(ribs):
		rx = x - w / 2 + (i + 0.5) * w / ribs
		for s in (-1, 1):
			bx(p, (0.5, 0.35, length), (rx, y + h / 2 + 0.2, z + s * d / 4), rib, rot=(s * slope, 0, 0))
	bx(p, (w + 1, 1.0, 1.4), (x, y + h + 0.2, z), RIDGE)
	for s in (-1, 1):  # onigawara end lumps
		bx(p, (1.2, 1.8, 1.8), (x + s * (w / 2 + 0.2), y + h + 0.5, z), RIDGE)


def windows(p, x0, x1, cols, y0, rows, dy, z, w, h, col, lit=(), litcol=WARM, frame=None):
	for r in range(rows):
		for c in range(cols):
			x = x0 + (x1 - x0) * (c + 0.5) / cols
			on = (r * cols + c) in lit
			if frame:
				bx(p, (w + 0.8, h + 0.8, 0.3), (x, y0 + r * dy, z + 0.1), frame)
			bx(p, (w, h, 0.4), (x, y0 + r * dy, z), litcol if on else col, emit=3.0 if on else 0.0, rough=0.3)


def _fill(k, color):
	"""Earth under the raised road (the game's hill supports), so the climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			ob = k.place("Fill", (p.x, -1.0, p.z), math.atan2(-t.x, -t.z))
			ob.scale = (k.width - 1, step + 0.5, p.y + 0.5)
		d += step


def put(k, name, d, off, scale=1.0, clear=None, turn=0.0):
	"""One prop on the ground at distance d, `off` studs right (negative left) of the centre line, -Z to the road."""
	pos, yaw = k.beside(d, off)
	if not k.clear_of_road(pos[0], pos[2], min(abs(off) - 1, 24) if clear is None else clear):
		return None
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	return k.place(name, (pos[0], -1.0, pos[2]), yaw + turn, scale)


def row(k, a, b, every, offsets, names, jitter=0.0, scale=(1.0, 1.0), flat=False, skip=(0, 0)):
	d = a
	while d < b:
		if skip[0] <= d <= skip[1]:
			d += every
			continue
		for off in offsets:
			if flat and k.at(d)[0].y > 2:
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			put(k, k.rng.choice(names), d + k.rng.uniform(-jitter, jitter), o, k.rng.uniform(*scale))
		d += every


def build(k):
	rnd = random.Random(404)

	# --- Cedars (sugi): straight trunk, tall narrow stacked crown ---
	for i, (h, col) in enumerate(((54, CEDAR), (68, CEDAR2))):
		parts = [("cyl", (2.4, h * 0.6, 2.4), (0, h * 0.3, 0), BARK, {"seg": 6})]
		for j in range(6):
			r = 15 - j * 2.2
			parts.append(("cone", (r, h * 0.26, r), (0, h * 0.28 + j * h * 0.11 + h * 0.13, 0), col, {"seg": 7}))
		parts.append(("ball", (3, 3, 3), (0, h * 1.0, 0), col, {"subdiv": 1}))
		k.prop("Cedar%d" % i, parts)

	# --- Mountain: dark forested ridge with a skirt of cedar silhouettes ---
	mt = [
		("cone", (420, 250, 420), (0, 125, 0), "15241E", {"seg": 10}),
		("cone", (260, 170, 260), (170, 85, 60), "1A2C24", {"seg": 9}),
		("cone", (240, 140, 240), (-170, 70, 30), "182820", {"seg": 9}),
	]
	for i in range(28):
		a = i / 28 * math.tau
		rr = 205 + rnd.uniform(-15, 15)
		s = rnd.uniform(26, 40)
		mt.append(("cone", (s, s * 2.2, s), (math.cos(a) * rr, s * 1.1, math.sin(a) * rr), (CEDAR, CEDAR2)[i % 2], {"seg": 6}))
	k.prop("Mountain", mt)

	# --- Guardrail: Japanese white W-beam on round posts, with a delineator ---
	gr = []
	for x in (-10, -5, 0, 5, 10):
		gr.append(("cyl", (0.7, 4.2, 0.7), (x, 2.1, 0.4), "D8DCDC", {"seg": 8, "metal": 0.4}))
		bx(gr, (0.4, 0.6, 0.6), (x, 3.1, 0.0), "B8BCBC")
	bx(gr, (24.2, 1.6, 0.25), (0, 3.2, -0.3), "EEF0F0", metal=0.5, rough=0.4)
	bx(gr, (24.2, 0.35, 0.35), (0, 3.5, -0.5), "FFFFFF", metal=0.5, rough=0.4)
	bx(gr, (24.2, 0.35, 0.35), (0, 2.9, -0.5), "FFFFFF", metal=0.5, rough=0.4)
	gr.append(("cyl", (0.5, 5, 0.5), (11.5, 2.5, 0.8), "F4F4F4", {"seg": 6}))
	bx(gr, (0.6, 0.6, 0.3), (11.5, 4.6, 0.5), "FF7A1A", emit=2.0)
	k.prop("Guardrail", gr)

	# --- Curve mirror (orange pole, round convex mirror with hood) + a blank chevron curve sign ---
	k.prop(
		"Mirror",
		[
			("cyl", (0.9, 15, 0.9), (0, 7.5, 0), "E86A1C", {"seg": 8}),
			("box", (0.5, 0.5, 2.2), (0, 14, -0.9), "E86A1C"),
			("cyl", (5.2, 0.8, 5.2), (0, 14.5, -2.2), "E86A1C", {"seg": 16, "rot": (90, 0, 0)}),
			("cyl", (4.4, 0.4, 4.4), (0, 14.5, -2.7), "D8F0FF", {"seg": 16, "rot": (90, 0, 0), "rough": 0.05, "metal": 0.9}),
			("cyl", (5.6, 0.6, 2.4), (0, 17.0, -2.6), "E86A1C", {"seg": 12, "rot": (0, 0, 90), "taper": 0.9}),
			("cyl", (0.6, 9, 0.6), (4, 4.5, 0), "9A9EA2", {"seg": 6}),
			("box", (4.2, 4.2, 0.2), (4, 8.6, -0.4), HAZ_Y, {"rot": (0, 0, 45)}),
			("box", (2.0, 0.6, 0.25), (3.6, 9.2, -0.55), HAZ_K, {"rot": (0, 0, 45)}),
			("box", (2.0, 0.6, 0.25), (3.6, 8.0, -0.55), HAZ_K, {"rot": (0, 0, -45)}),
		],
	)

	# --- Tunnel lining slice: round-topped concrete vault, walkways, cable tray, sodium lamps (12 studs) ---
	ts = []
	for s in (-1, 1):
		bx(ts, (3, SPR + 1, 12.2), (s * (R + 1.5), (SPR - 1) / 2, 0), LINING)
		bx(ts, (0.3, 4, 12.2), (s * (R - 0.1), 1.0, 0), "323830")  # damp band
		bx(ts, (3, 1.2, 12.2), (s * (R - 1.5), 1.6, 0), "6E7268")  # walkway
		bx(ts, (0.6, 0.6, 12.2), (s * (R - 0.3), 9.5, 0), "2E3230", metal=0.5)  # cable tray
		bx(ts, (0.8, 1.2, 3.6), (s * (R - 0.5), SPR + 1, 0), SODIUM, emit=8.0)
		bx(ts, (1.0, 0.4, 4.0), (s * (R - 0.6), SPR + 1.8, 0), "2A2A2A")
		bx(ts, (14, 44, 12.2), (s * (R + 10), 21, 0), "2A2E28")  # rock beside the vault
	n = 14
	for i in range(n):
		a = math.pi * (i + 0.5) / n
		rr = R + 1.5
		ts.append(("box", (2 * math.pi * rr / 2 / n * 1.08, 3, 12.2), (math.cos(a) * rr, SPR + math.sin(a) * rr, 0), LINING, {"rot": (0, 0, math.degrees(a) - 90)}))
		ts.append(("box", (2 * math.pi * R / 2 / n * 1.08, 0.6, 0.8), (math.cos(a) * (R - 0.2), SPR + math.sin(a) * (R - 0.2), 5.6), LINING2, {"rot": (0, 0, math.degrees(a) - 90)}))
	bx(ts, (82, 12, 12.2), (0, SPR + R + 8, 0), "26302A")
	k.prop("TunnelSeg", ts)

	# --- Portal (hero): Turbo Granny's tunnel mouth. Dressed-stone face in running bond around a horseshoe opening,
	# a raised voussoir ring with a keystone, cornice, ivy pouring over the top, yellow-black barriers pushed aside,
	# a blank no-entry board, and the forested hill above. -Z faces the approaching road. ---
	po = []
	top, half, ch = 58.0, 64.0, 3.6
	ring = R + 5.5
	rows = int((top + 1) / ch)
	for r in range(rows):
		yc = -1 + ch * (r + 0.5)
		if yc <= SPR:
			inner = R
		elif yc - SPR < ring:
			inner = math.sqrt(ring * ring - (yc - SPR) ** 2)
		else:
			inner = 0.0
		spans = [(-half, half)] if inner == 0 else [(-half, -inner), (inner, half)]
		for a, b in spans:  # running bond: alternate rows start with a different block width
			x, j = a, r
			while x < b - 0.5:
				w = min(((6.4, 4.6, 5.6) if r % 2 else (4.8, 6.2, 5.2))[j % 3], b - x)
				bx(po, (w - 0.35, ch - 0.35, 5), (x + w / 2, yc, rnd.uniform(-0.25, 0.25)), (STONE, STONE2, STONE3)[(j * 7 + r * 3) % 3])
				x += w
				j += 1
	# mortar backing behind the joints, above the ring only (the mouth stays open)
	bx(po, (half * 2, top - SPR - ring, 4), (0, SPR + ring + (top - SPR - ring) / 2, 1.6), MORTAR)
	nv = 19
	for i in range(nv):
		a = math.pi * (i + 0.5) / nv
		rr = R + 2.75
		key = i == nv // 2
		po.append(("box", (2 * math.pi * rr / 2 / nv * 0.92, 6.4 if key else 5.5, 6.2 if key else 5.8), (math.cos(a) * rr, SPR + math.sin(a) * rr + (0.6 if key else 0), -0.6), STONE3 if i % 2 else "858A7C", {"rot": (0, 0, math.degrees(a) - 90)}))
	for s in (-1, 1):  # impost blocks at the springline and plinths
		bx(po, (6.5, 2.4, 6.6), (s * (R + 3), SPR - 0.2, -0.7), "858A7C")
		bx(po, (6, 3, 6.4), (s * (R + 3), 0.5, -0.6), STONE2)
	bx(po, (half * 2 + 3, 2.2, 7.5), (0, top + 0.6, -0.4), "858A7C")  # cornice
	bx(po, (half * 2 + 1, 2.4, 6), (0, top + 2.8, 0.2), STONE2)  # parapet
	bx(po, (8, 4, 0.6), (0, SPR + ring + 6, -2.8), "6A6E62")  # blank plaque frame (no text)
	bx(po, (6.6, 2.8, 0.4), (0, SPR + ring + 6, -3.1), "4E5248")
	po.append(("wedge", (180, 70, 110), (0, top + 35, 58), "1E2E24", {"rot": (0, 180, 0)}))
	for s in (-1, 1):
		po.append(("wedge", (60, top, 70), (s * (half + 30), top / 2 - 1, 34), "1C2A22", {"rot": (0, -s * 90, 0)}))
	for x, z, hh in ((-48, 60, 52), (-20, 70, 62), (10, 52, 48), (36, 66, 58), (58, 46, 44), (-60, 40, 40)):
		po.append(("cone", (16, hh, 16), (x, top + 30 + hh / 2 - 10, z), (CEDAR, CEDAR2)[x % 2], {"seg": 7}))
	# ivy pouring over the cornice and down the face (green clumps and hanging strands)
	for i in range(46):
		x = rnd.uniform(-half - 4, half + 4)
		yy = top + rnd.uniform(-6, 4)
		if abs(x) > R + 10 and rnd.random() < 0.55:
			yy = rnd.uniform(6, top)
		s = rnd.uniform(4, 9)
		po.append(("ball", (s * 1.4, s, s * 0.8), (x, yy, -2.6 - rnd.uniform(0, 1.5)), (IVY, IVY2, IVY3)[i % 3], {"subdiv": 1}))
	for i in range(22):
		x = rnd.uniform(-half + 4, half - 4)
		ln = rnd.uniform(8, 26)
		if abs(x) < R + 6:
			ln = min(ln, top - SPR - math.sqrt(max(0.0, (R + 6) ** 2 - x * x)) - 2)
			if ln < 3:
				continue
		po.append(("box", (rnd.uniform(1.2, 2.6), ln, 0.6), (x, top - ln / 2, -2.9), (IVY, IVY3)[i % 2]))
	# barriers pushed aside to the walkway (posts at |x| >= 24) and a blank red-and-white board on a stand
	for s in (-1, 1):
		for j in range(2):
			cx = s * (R - 1.5 + j * 6)
			bx(po, (0.6, 5, 0.6), (cx - 2.4, 2.5, -6), "C8C8C8")
			bx(po, (0.6, 5, 0.6), (cx + 2.4, 2.5, -6), "C8C8C8")
			for q in range(4):
				bx(po, (1.2, 1.6, 0.3), (cx - 1.8 + q * 1.2, 3.8, -6.3), (HAZ_Y, HAZ_K)[q % 2])
			bx(po, (5.4, 0.4, 0.4), (cx, 3.0, -6.2), "E8E8E8")
	bx(po, (3.6, 8, 0.3), (-(R + 9), 6, -5), "F2F2EE")
	bx(po, (3.0, 7.2, 0.2), (-(R + 9), 6, -5.2), "C62828")
	bx(po, (2.4, 6.6, 0.2), (-(R + 9), 6, -5.3), "F2F2EE")
	bx(po, (0.5, 3, 0.5), (-(R + 9), 0.5, -5), "8A8A8A")
	bx(po, (0.4, 9, 0.4), (R + 11, 3.5, -4), "8A8A8A")  # small notice board on a pole (blank)
	bx(po, (3, 3.6, 0.3), (R + 11, 8.5, -4.2), "D8D8CC")
	k.prop("Portal", po)

	# --- Kami High (hero): white 4-floor block on a pillar grid, glass bays, floor bands, glass stair tower on the
	# right end, entrance canopy, clock box, roof fence, rear wing and gym, brown brick gate walls, green lattice gate. ---
	sc = []
	W, D, FL, NB = 168.0, 30.0, 12.0, 14
	H = FL * 4
	bx(sc, (W, H, D), (0, H / 2 - 1, 0), "E8E8E2")
	bay = W / NB
	lit = {3, 9, 16, 22, 30, 41, 47, 50}
	for f in range(4):
		for b in range(NB):
			x = -W / 2 + (b + 0.5) * bay
			y = f * FL + 6.5 - 1
			on = (f * NB + b) in lit
			bx(sc, (bay - 2.2, 7.2, 0.4), (x, y, -D / 2 - 0.1), "F6D9A0" if on else GLASS, emit=2.2 if on else 0.0, rough=0.15, metal=0.3)
			bx(sc, (0.4, 7.2, 0.6), (x, y, -D / 2 - 0.3), "C8CCD0")  # mullion
			bx(sc, (bay - 2.2, 0.4, 0.6), (x, y + 1.6, -D / 2 - 0.3), "C8CCD0")  # transom
		bx(sc, (W + 1, 1.4, 2.2), (0, f * FL + FL - 1.7, -D / 2 - 1), "F4F4F0")  # floor band
	for b in range(NB + 1):
		bx(sc, (1.8, H + 2, 2.6), (-W / 2 + b * bay, H / 2, -D / 2 - 1.2), "FAFAF6")  # pillar grid
	bx(sc, (W + 2, 2.4, D + 2), (0, H + 0.2, 0), "D2D2CC")  # parapet
	for x in range(-80, 81, 8):
		bx(sc, (0.3, 4, 0.3), (x, H + 3.2, -D / 2), "9AA2A0")
	bx(sc, (W, 0.4, 0.4), (0, H + 5, -D / 2), "9AA2A0")
	bx(sc, (W, 0.4, 0.4), (0, H + 3, -D / 2), "9AA2A0")
	bx(sc, (14, 8, 10), (-50, H + 5, 4), "DCDCD4")  # stair housing
	sc.append(("cyl", (9, 8, 9), (40, H + 6, 6), "C8CCD0", {"seg": 12}))  # water tank
	# glass stair tower at the right end (slightly forward)
	bx(sc, (16, H + 6, 18), (W / 2 + 8, (H + 6) / 2 - 1, -4), "9DB6C6", rough=0.1, metal=0.4)
	for q in range(5):
		bx(sc, (0.5, H + 6, 0.6), (W / 2 + 0.5 + q * 3.75, (H + 6) / 2 - 1, -13.2), "E8ECEC")
	for f in range(5):
		bx(sc, (16.4, 0.6, 18.4), (W / 2 + 8, f * FL + 2, -4), "E8ECEC")
	bx(sc, (16.6, 1.4, 18.6), (W / 2 + 8, H + 5.6, -4), "E8ECEC")
	# clock box over the centre bay (blank face, two hands)
	bx(sc, (8, 8, 2), (-6, H + 5, -D / 2 - 0.6), "F4F4F0")
	sc.append(("cyl", (6, 0.6, 6), (-6, H + 5, -D / 2 - 1.8), "FFFFFF", {"seg": 16, "rot": (90, 0, 0), "emit": 0.6}))
	bx(sc, (0.4, 2.4, 0.3), (-6, H + 6, -D / 2 - 2.2), "202020")
	bx(sc, (1.8, 0.4, 0.3), (-5.2, H + 5, -D / 2 - 2.2), "202020")
	# entrance canopy and glass doors (left of centre, as in the source)
	bx(sc, (30, 1.4, 14), (-40, 9.2, -D / 2 - 7), "F4F4F0")
	for x in (-53, -27):
		bx(sc, (1, 10, 1), (x, 4, -D / 2 - 13), "D8D8D4")
	bx(sc, (18, 8, 0.4), (-40, 3, -D / 2 - 0.4), "3A4A58", rough=0.1)
	# rear wing and gym (arched roof)
	bx(sc, (40, 36, 70), (60, 17, 50), "DCDCD6")
	windows(sc, 42, 78, 4, 4, 3, 12, 14.8, 5, 6, GLASS)
	bx(sc, (70, 22, 50), (-50, 10, 60), "C9C6BC")
	sc.append(("cyl", (50, 70, 18), (-50, 21, 60), "6C7A86", {"rot": (0, 90, 90), "seg": 14, "metal": 0.3}))
	# gate: brown brick walls with coping and course lines, gate pillars, green lattice sliding gate
	gz = -62.0
	for s in (-1, 1):
		x0, x1 = s * 16, s * 92
		cx, wl = (x0 + x1) / 2, abs(x1 - x0)
		bx(sc, (wl, 8, 3), (cx, 3, gz), "7A4E36")
		bx(sc, (wl + 0.6, 0.8, 3.6), (cx, 7.4, gz), "5E3A28")
		for c in range(3):
			bx(sc, (wl + 0.1, 0.3, 3.1), (cx, 1 + c * 2, gz), "6A4230")
		bx(sc, (5.5, 12, 5.5), (s * 13, 5, gz), "7A4E36")
		bx(sc, (6.2, 1, 6.2), (s * 13, 11.4, gz), "5E3A28")
	bx(sc, (20, 0.6, 0.6), (2, 7.5, gz - 2.5), "2E6E6A")  # lattice gate frame
	bx(sc, (20, 0.6, 0.6), (2, 0.5, gz - 2.5), "2E6E6A")
	for q in range(6):
		bx(sc, (0.35, 9.0, 0.3), (-6 + q * 3.2, 4, gz - 2.5), "2E6E6A", rot=(0, 0, 35))
		bx(sc, (0.35, 9.0, 0.3), (-6 + q * 3.2, 4, gz - 2.6), "2E6E6A", rot=(0, 0, -35))
	bx(sc, (W + 40, 0.6, 74), (0, -0.7, -26), "8C8A84")  # forecourt
	for x, z, s in ((-80, -48, 16), (-100, -40, 20), (90, -48, 18), (110, -30, 22), (-110, 10, 22)):
		sc.append(("cyl", (1.6, s * 0.6, 1.6), (x, s * 0.3 - 1, z), BARK, {"seg": 6}))
		sc.append(("ball", (s * 1.2, s, s * 1.2), (x, s * 0.9, z), ("2E5A30", "356638")[s % 2], {"subdiv": 1}))
	k.prop("School", sc)

	# --- Nagi Hospital (hero): abandoned 12-floor block with a lower wing, stained moonlit facade, dark window grid
	# (a few still glowing), blank rooftop sign frame, water tank, and the construction hoarding with hazard posts. ---
	ho = []
	HW, HD, HH, NF = 64.0, 40.0, 132.0, 12
	bx(ho, (HW, HH, HD), (0, HH / 2 - 1, 0), "48638F")
	bx(ho, (24, HH + 8, HD - 6), (HW / 2 + 10, (HH + 8) / 2 - 1, 2), "3F5682")
	fh = HH / NF
	glow = {5, 17, 30, 44, 51, 66}
	for f in range(NF):
		y = f * fh + fh * 0.55
		for c in range(8):
			i = f * 8 + c
			on = i in glow
			bx(ho, (5.4, fh * 0.5, 0.4), (-HW / 2 + 4 + c * 8, y, -HD / 2 - 0.1), "9FD8FF" if on else DARKWIN, emit=2.5 if on else 0.0, rough=0.3)
		for c in range(5):
			bx(ho, (0.4, fh * 0.5, 5.2), (-HW / 2 - 0.1, y, -HD / 2 + 4 + c * 8), DARKWIN, rough=0.3)
		for c in range(2):
			bx(ho, (6, fh * 0.5, 0.4), (HW / 2 + 4 + c * 12, y, -HD / 2 + 2.9), DARKWIN, rough=0.3)
		bx(ho, (HW + 0.6, 0.8, 0.6), (0, f * fh + 0.4, -HD / 2 - 0.2), "5A76A2")
	for x in (-25, -4, 18):  # rain streaks
		bx(ho, (2.2, HH * 0.7, 0.2), (x + 2, HH * 0.6, -HD / 2 - 0.25), "2E3E5C")
	bx(ho, (HW + 2, 3, HD + 2), (0, HH + 0.5, 0), "35486E")
	# rooftop sign frame with blank boards (the source's lettering is replaced by plain panels)
	for x in (-24, -12, 0, 12, 24):
		bx(ho, (0.6, 12, 0.6), (x, HH + 8, -HD / 2 + 2), "2A3548")
		bx(ho, (9.6, 9.6, 0.6), (x, HH + 9, -HD / 2 + 1.4), "5E7AA6")
	bx(ho, (62, 0.6, 0.6), (0, HH + 4, -HD / 2 + 2), "2A3548")
	ho.append(("cyl", (10, 10, 10), (18, HH + 7, 10), "3E506E", {"seg": 12}))
	bx(ho, (12, 9, 12), (-18, HH + 6, 10), "3A4C70")
	# lower wing on the left, front
	bx(ho, (46, 26, 50), (-HW / 2 - 18, 12, -6), "3A4E74")
	windows(ho, -HW / 2 - 40, -HW / 2 + 4, 5, 6, 2, 11, -31.3, 5, 4.6, DARKWIN)
	bx(ho, (48, 1.6, 52), (-HW / 2 - 18, 25.8, -6), "2E3E5E")
	# construction hoarding (corrugated panels) with a gate, bars and hazard-striped posts
	hz = -60.0
	for i in range(14):
		x = -78 + i * 11
		if -8 < x < 8:
			continue
		bx(ho, (10.6, 12, 0.6), (x, 5, hz), ("2E4A4A", "345454")[i % 2])
		for q in range(4):
			bx(ho, (0.5, 12, 0.9), (x - 4 + q * 2.6, 5, hz - 0.2), "28403F")
	for s in (-1, 1):
		bx(ho, (1.6, 15, 1.6), (s * 8, 6.5, hz), HAZ_K)
		for q in range(5):
			bx(ho, (1.7, 1.4, 1.7), (s * 8, 1 + q * 3, hz), HAZ_Y, rot=(0, 0, 20))
	for q in range(7):
		bx(ho, (0.4, 11, 0.4), (-6 + q * 2, 4.5, hz - 0.5), "1E2626", metal=0.6)
	bx(ho, (16, 0.5, 0.5), (0, 9.5, hz - 0.5), "1E2626", metal=0.6)
	bx(ho, (6, 7, 0.3), (-22, 6, hz - 0.5), "C8D8C8")  # blank notice board
	for i in range(10):
		ho.append(("ball", (rnd.uniform(4, 8), rnd.uniform(2, 4), rnd.uniform(4, 8)), (rnd.uniform(-75, 75), 0.5, hz - 2.5), (IVY, IVY3)[i % 2], {"subdiv": 1}))
	bx(ho, (170, 0.6, 70), (-10, -0.8, -26), "3A403E")
	k.prop("Hospital", ho)

	# --- Seiko's house (hero): granite stone torii on a stone bridge over a canal, wooden slat fence on a stone
	# base, white-walled timber-framed house with a rust-red tiled roof, a small shrine with a straw rope and paper
	# streamers, stone lanterns, garden pines. ---
	se = []
	GRAN, GRAN2, WOOD = "8E8E86", "7A7A72", "5A3E2A"
	bx(se, (120, 3, 10), (0, -1.2, -38), "1E3440", rough=0.1, metal=0.2)  # canal water
	for z in (-43.5, -32.5):
		bx(se, (120, 4, 1.4), (0, 0, z), "6A6E66")
	bx(se, (14, 1.6, 13), (0, 1.0, -38), GRAN2)  # stone bridge
	for s in (-1, 1):
		bx(se, (1, 2.4, 13), (s * 7, 2.6, -38), GRAN)
	for s in (-1, 1):  # torii: two pillars, kasagi with ends, nuki, central gakuzuka (blank)
		se.append(("cyl", (2.4, 20, 2.4), (s * 7, 10.5, -31), GRAN, {"seg": 10, "rough": 0.9}))
		se.append(("cyl", (3.2, 1.2, 3.2), (s * 7, 0.9, -31), GRAN2, {"seg": 10}))
	bx(se, (22, 1.8, 2.6), (0, 20.5, -31), GRAN)
	bx(se, (24, 1.0, 3.0), (0, 21.8, -31), GRAN2)
	bx(se, (18, 1.4, 1.6), (0, 16.5, -31), GRAN)
	bx(se, (1.4, 3, 1.2), (0, 18.6, -31), GRAN2)
	for s in (-1, 1):  # slat fence on a stone base along the canal
		cx = s * 34
		bx(se, (52, 2, 2), (cx, 1, -31), GRAN2)
		bx(se, (52, 0.8, 1.2), (cx, 8.4, -31), "8A7A62")
		for q in range(17):
			bx(se, (1.6, 6.4, 0.6), (cx - 24 + q * 3, 5, -31), ("9A8A70", "8A7A62")[q % 2])
	bx(se, (50, 0.6, 30), (0, -0.7, -14), "8A8478")  # stone paving
	for z in (-24, -18, -12, -6):
		bx(se, (6, 0.4, 3.5), (0, -0.3, z), "A8A49A")
	# the house: two floors, white plaster, dark timber frame, engawa, shoji glow, rust-red roofs
	bx(se, (44, 13, 22), (0, 5.5, 8), "E8E2D2")
	bx(se, (36, 10, 18), (0, 16.5, 9), "E2DCCC")
	for x in (-22, -11, 0, 11, 22):
		bx(se, (1.0, 12, 0.6), (x, 5, -3.2), WOOD)
	for x in (-18, -6, 6, 18):
		bx(se, (1.0, 10, 0.6), (x, 16.5, -0.2), WOOD)
	bx(se, (44.4, 1.0, 0.8), (0, 11.6, -3.2), WOOD)
	bx(se, (44.4, 1.0, 0.8), (0, 0.4, -3.3), WOOD)
	bx(se, (48, 0.8, 4), (0, 1.2, -5.5), "6A4A32")  # engawa
	windows(se, -20, 20, 4, 5.5, 1, 0, -3.4, 7, 7, "E6DEC4", lit=(1, 2), litcol="FFD58A")
	windows(se, -16, 16, 3, 17, 1, 0, -0.4, 6, 5, "D8D0B8", lit=(1,), litcol="FFD58A")
	gable(se, 0, 8, 50, 28, 11.6, 6, "8A3A2A", "6E2C20", ribs=10)
	gable(se, 0, 9, 40, 22, 21.4, 6, "8A3A2A", "6E2C20", ribs=8)
	# small shrine (hokora) on a stone base, straw rope with paper streamers
	bx(se, (10, 3, 8), (-34, 0.5, -6), GRAN2)
	bx(se, (6, 6, 5), (-34, 5, -6), "7A5236")
	gable(se, -34, -6, 9, 8, 8, 3, "3A3A40", "2A2A30", ribs=3)
	bx(se, (7, 0.7, 0.7), (-34, 7.4, -8.8), "D8C890")
	for q in range(3):
		bx(se, (0.8, 1.8, 0.2), (-36 + q * 2, 6.2, -9.0), "FFFFFF", emit=0.5)
	for x in (-14, 14):  # stone lanterns (toro)
		bx(se, (2.6, 0.8, 2.6), (x, -0.4, -22), GRAN2)
		se.append(("cyl", (1.2, 4, 1.2), (x, 2, -22), GRAN, {"seg": 8}))
		bx(se, (2.4, 2.0, 2.4), (x, 5, -22), "FFD58A", emit=3.0)
		se.append(("cone", (4, 1.8, 4), (x, 6.9, -22), GRAN, {"seg": 6}))
	for x, z, s in ((30, -14, 12), (-46, 10, 14), (38, 22, 16)):
		se.append(("cyl", (1.4, s * 0.6, 1.4), (x, s * 0.3 - 1, z), BARK, {"seg": 6}))
		se.append(("ball", (s * 1.3, s * 0.6, s * 1.3), (x, s * 0.75, z), "2C4E2E", {"subdiv": 1}))
		se.append(("ball", (s, s * 0.5, s), (x + 2, s * 1.05, z), "355C34", {"subdiv": 1}))
	k.prop("SeikoHouse", se)

	# --- Town house (mid): two floors, siding walls, kawara gable roof, annex with lean-to roof, sliding windows,
	# concrete block wall, a glowing vending machine and a concrete utility pole with transformer. ---
	hs = []
	bx(hs, (24, 18, 18), (0, 8, 4), "C9C0AE")
	for y in (3, 7, 11, 15):
		bx(hs, (24.2, 0.3, 18.2), (0, y, 4), "B0A896")
	windows(hs, -9, 9, 2, 4.5, 2, 8, -5.2, 6, 4.2, "2A3038", lit=(1, 2), frame="DADAD4")
	gable(hs, 0, 4, 28, 22, 17, 6, TILE, TILE2, ribs=9)
	bx(hs, (14, 10, 14), (18, 4, 6), "B8B0A0")
	hs.append(("wedge", (16, 3, 16), (18, 10.5, 6), TILE2, {"rot": (0, 180, 0)}))
	bx(hs, (6, 6, 0.4), (18, 4, -1.2), "FFD890", emit=2.0)
	for s in (-1, 1):  # block wall in front, a gap for the gate
		bx(hs, (14, 5, 1.4), (s * 11, 1.5, -11), "9A9A92")
		bx(hs, (14.2, 0.5, 1.8), (s * 11, 4.2, -11), "86867E")
	bx(hs, (5, 10, 4), (-15, 4, -13.5), "D8DCE0")  # vending machine
	bx(hs, (4.2, 6, 0.3), (-15, 5, -15.6), "EAF6FF", emit=4.0)
	for q in range(3):
		bx(hs, (3.6, 0.5, 0.4), (-15, 3 + q * 2, -15.8), ("E24A3A", "3A8AE2", "F2C230")[q], emit=2.0)
	hs.append(("cyl", (1.4, 34, 1.4), (12, 16, -14), "9A9A96", {"seg": 8}))
	bx(hs, (10, 0.6, 0.6), (12, 31, -14), "6A6A66")
	hs.append(("cyl", (2.2, 3.2, 2.2), (10, 26, -13), "7A7E80", {"seg": 8}))
	for x in (8, 12, 16):
		bx(hs, (0.4, 0.8, 0.4), (x, 31.6, -14), "E8E8E8")
	k.prop("House", hs)

	# --- layout ---
	k.ground("17201B", margin=550)
	_fill(k, "232822")
	orig = k.beside

	# Tunnel: lining slices every 12 studs, a portal at each mouth (entry flipped to face the approach)
	d = TUNNEL[0]
	while d < TUNNEL[1]:
		pos, yaw = orig(d, 0)
		k.place("TunnelSeg", pos, yaw)
		d += 12
	for d, flip in ((TUNNEL[0] - 3, math.pi), (TUNNEL[1] + 3, 0.0)):
		pos, yaw = orig(d, 0)
		k.place("Portal", pos, yaw + flip)
	k.light(orig(TUNNEL[0] - 40, 0, 30)[0], "7CFFB0", energy=60000, radius=10)  # ghostly green on the stone face
	k.light(orig(TUNNEL[1] + 40, 0, 30)[0], "7CFFB0", energy=40000, radius=10)
	d, i = TUNNEL[0] + 6, 0
	while d < TUNNEL[1]:
		pos, _ = orig(d, 0, 14)
		k.light(pos, SODIUM, energy=(16000, 5000, 12000, 2500)[i % 4], radius=3)
		d, i = d + 24, i + 1

	# Town A (start, with Seiko's house), town B (after the hospital)
	towns = [(30.0, 760.0), (3780.0, 5600.0)]
	for a, b in towns:
		row(k, a, b, 44, (46,), ["House"], jitter=3, flat=True)
		row(k, a, b, 44, (-46,), ["House"], jitter=3, flat=True, skip=(440, 620))
		row(k, a + 20, b, 60, (100,), ["House", "Cedar0"], jitter=10, scale=(0.9, 1.3))
		row(k, a + 20, b, 60, (-100,), ["House", "Cedar0"], jitter=10, scale=(0.9, 1.3), skip=(420, 640))
	put(k, "SeikoHouse", 530, -84, 1.15, clear=50)

	# Mountain road: guardrails, curve mirrors, cedars in layers, ridges
	mountain = [(760.0, TUNNEL[0] - 40), (TUNNEL[1] + 40, 2700.0), (3000.0, 3700.0)]
	for a, b in mountain:
		row(k, a, b, 24, (-25, 25), ["Guardrail"], flat=True)
		row(k, a + 60, b, 210, (-27, 27), ["Mirror"])
		row(k, a, b, 30, (-40, 40), ["Cedar0", "Cedar1"], jitter=4)
		row(k, a + 10, b, 34, (-58, 58), ["Cedar1", "Cedar0"], jitter=8, scale=(0.9, 1.2))
		row(k, a + 20, b, 38, (-80, 80), ["Cedar0", "Cedar1"], jitter=10, scale=(1.0, 1.4))
	d = TUNNEL[0] - 30
	while d < TUNNEL[1] + 30:
		for s in (-1, 1):
			put(k, ("Cedar0", "Cedar1")[int(d) % 2], d, s * 46)
			put(k, "Cedar1", d + 12, s * 60, 1.2)
		d += 26
	for s in (-1, 1):
		put(k, "Mountain", (TUNNEL[0] + TUNNEL[1]) / 2, s * 260, 0.7, clear=120)

	# Kami High on the left of the straight before the second climb; Nagi Hospital ahead on the left after it
	put(k, "School", 2860, -135, clear=60)
	row(k, 2700, 3000, 30, (40,), ["Cedar0", "Cedar1"], jitter=4)
	put(k, "Hospital", 3730, -150, clear=80)

	# Forest and far ridges over the whole map
	avoid = []
	for name, d, off in (("School", 2860, -135), ("Hospital", 3730, -150), ("SeikoHouse", 530, -84)):
		(x, _, z), _ = orig(d, off)
		avoid.append((x, z, 120))
	placed, tries = 0, 0
	while placed < 260 and tries < 6000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 350, k.hi.x + 350)
		z = k.rng.uniform(k.lo.z - 350, k.hi.z + 350)
		if all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid) and k.clear_of_road(x, z, 70):
			k.place(k.rng.choice(["Cedar0", "Cedar1"]), (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(0.9, 1.5))
			placed += 1
	k.field(18, ["Mountain"], clearance=420, margin=650, scale=(0.7, 1.4))

	# Night sky: deep blue, a big full moon (sky dressing, the game's Sky moon; not a prop asset)
	c = (k.lo + k.hi) / 2
	moon = bpy.data.objects.new("SkyMoon", bpy.data.meshes.new("SkyMoon"))

	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=3, radius=90)
	bm.to_mesh(moon.data)
	bm.free()
	moon.data.materials.append(k.mat("EEF6FF", emit=8.0))
	moon.location = kit.rb(c.x + 700, 650, c.z - 1500)
	k.col.objects.link(moon)
	k.sky([(0.0, "2C5488"), (0.06, "1A3460"), (0.35, "0B1838"), (1.0, "030812")], strength=1.0, sun=(1.6, "8FB0FF", 38, 160))
	# Lights: warm house and vending-machine glow in town; a few sodium lamps on the mountain road; school and hospital
	for a, b in towns:
		d = a + 20
		while d < b:
			for s in (-1, 1):
				pos, _ = orig(d, s * 36, 8)
				k.light(pos, WARM, energy=9000, radius=4)
			d += 88
	for a, b in mountain:
		d = a + 30
		while d < b:
			pos, _ = orig(d, 22, 18)
			k.light(pos, SODIUM, energy=22000, radius=5)
			d += 160
	k.light(orig(2860, -70, 30)[0], WARM, energy=60000, radius=10)
	k.light(orig(3730, -80, 60)[0], "6FA8FF", energy=160000, radius=20)
	k.light(orig(530, -50, 18)[0], "FFD58A", energy=30000, radius=6)
