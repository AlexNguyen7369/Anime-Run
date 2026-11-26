"""World 2 Track 4: the haunted tunnel road (Dandadan), at night. Rebuilt 2026-11-23 for a closer 1-1 read of the source
(owner: "more detail and closer reference to source material"; round 2 after the reference review). Landmarks and
their references: docs/world2_refs/HauntedTunnel.md. A rural Japanese town at night (two house types with tiled roofs,
block walls, utility poles, glowing vending machines), Seiko's house behind its granite torii and canal bridge, the
mountain road (white W-beam guardrails over a concrete ditch, orange curve mirrors, cedar forest, stepped forested
ridges), the old ivy-covered stone tunnel of Turbo Granny (horseshoe arch of rough dressed stone, ivy curtains, moss
stains, barriers and a no-entry board, a near-black curving vault with a few yellow lamp pools), the white Kami High
building (pillar grid, glass stair tower on the right, brick gate walls and green lattice gate) and the abandoned Nagi
Hospital tower under a big blue moon.
Rules (design doc 5, WORLD2_SPEC): in-house primitives only; no text, no logos (boards are blank); props 24+ studs from
the centre line; the tunnel lining clears the road by 38. Budget: 12 unique meshes (road pieces excluded).
Frames: a viewer in front of a prop (looking +Z) sees local +X on the left, so source left/right map to +X/-X.
Proposed look; the owner approves the render set (design doc 4.46)."""

import math
import random

import bmesh
import bpy

import kit

CEDAR, CEDAR2, BARK = "1C3326", "243F2E", "3A2A20"
STONE, STONE2, STONE3, MORTAR = "6F7468", "5E6459", "7C8072", "2E322A"
STONES = (STONE, STONE2, STONE3, "5A6152", "666B5A", "727664")
IVY, IVY2, IVY3, MOSS = "2F5A2E", "3D6E35", "24482A", "232C1E"
LINING, LINING2 = "121412", "0C0E0C"
TILE, TILE2, RIDGE = "3A3F4A", "2E323B", "23262D"
SODIUM, WARM, GLASS, DARKWIN = "FFB347", "FFD890", "7FA0B8", "141C26"
HAZ_Y, HAZ_K = "F2C230", "1A1A1A"
R, SPR = 27.0, 13.0  # tunnel inner radius and springline height (local y; local 0 is 1 below the road top)
TUNNEL = (1990.0, 2330.0)  # run shot 2 (1903) faces the entry portal; the far end runs into the bend, hiding the exit
LAMPS = (34.0, 68.0, 104.0)
MIRROR_TURN = math.radians(50)  # curve mirrors turn from facing across the road toward the oncoming runner  # the only lamps: this far inside each mouth (local +Z), on alternate walls

CLEAR_EXEMPT = {"Fill", "TunnelSeg", "Portal"}  # road support; the tunnel lining and portals span the road 38 overhead
MODEL_SHOTS = ["Portal", "Hospital", "School", "SeikoHouse"]  # hero models rendered close up for review

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
			bx(p, (w, h, 0.4), (x, y0 + r * dy, z), litcol if on else col, emit=1.4 if on else 0.0, rough=0.3)


def _fill(k, color):
	"""Earth under the raised road (the game's hill supports), so the climbs are not on stilts."""
	k.prop("Fill", [("box", (1, 1, 1), (0, 0.5, 0), color)])
	step, d = 8.0, 0.0
	while d < k.length:
		p, _, t = k.at(d + step / 2)
		if p.y > 1.5:
			# its top under the road over its whole length (kit.support_top), not at the centre's height
			ob, h = k.support("Fill", p.x, p.z, math.atan2(-t.x, -t.z), d - 0.25, d + step + 0.25)
			ob.scale = (k.width - 1, step + 0.5, h)
		d += step


def put(k, name, d, off, scale=1.0, clear=None, turn=0.0):
	"""One prop on the ground at distance d, `off` studs right (negative left) of the centre line, -Z to the road."""
	pos, yaw = k.beside(d, off)
	if not k.clear_of_road(pos[0], pos[2], min(abs(off) - 1, 24) if clear is None else clear):
		return None
	yaw += math.pi / 2 if off > 0 else -math.pi / 2
	return k.place(name, (pos[0], -1.0, pos[2]), yaw + turn, scale)


def row(k, a, b, every, offsets, names, jitter=0.0, scale=(1.0, 1.0), flat=False, skip=(), turns=(0.0,)):
	d = a
	while d < b:
		for off in offsets:
			if flat and k.at(d)[0].y > 2:
				continue
			if any(s0 <= d <= s1 and (side == 0 or side * off > 0) for s0, s1, side in skip):
				continue
			o = off + k.rng.uniform(-jitter, jitter) * (1 if off > 0 else -1)
			put(k, k.rng.choice(names), d + k.rng.uniform(-jitter, jitter), o, k.rng.uniform(*scale), turn=k.rng.choice(turns))
		d += every


def shot_eye(k, f):
	"""Eye, forward and right of build_track's runner shot at fraction f (same maths as build_track.shots)."""
	p, right, t = k.at(k.length * f)
	eye = p + right * 10 - t * 14
	return eye, t, right, p.y + 8


def build(k):
	rnd = random.Random(404)

	# --- Cedar (sugi): straight trunk, tall narrow stacked crown; one mesh, sizes vary by scale ---
	h = 60
	parts = [("cyl", (2.4, h * 0.6, 2.4), (0, h * 0.3, 0), BARK, {"seg": 6})]
	for j in range(6):
		r = 15 - j * 2.2
		parts.append(("cone", (r, h * 0.26, r), (0, h * 0.28 + j * h * 0.11 + h * 0.13, 0), (CEDAR, CEDAR2)[j % 2], {"seg": 7}))
	parts.append(("ball", (3, 3, 3), (0, h * 1.0, 0), CEDAR, {"subdiv": 1}))
	k.prop("Cedar", parts)

	# --- Mountain: an irregular ridge line of stepped peaks, covered in cedar silhouettes ---
	mt = []
	peaks = []
	x = -260.0
	while x < 260:
		hh = rnd.uniform(110, 230)
		rr = hh * rnd.uniform(1.0, 1.3)
		z = rnd.uniform(-40, 40)
		peaks.append((x, z, rr, hh))
		x += rr * rnd.uniform(0.7, 0.95)
	for x, z, rr, hh in peaks:
		for step in range(3):  # stepped shoulders: stacked tapering tiers, slightly offset
			f0 = step / 3
			mt.append(("cyl", (2 * rr * (1 - f0), hh / 3, 2 * rr * (1 - f0) * 0.9), (x + rnd.uniform(-8, 8), hh * f0 + hh / 6, z), ("16251F", "1A2B23", "14221C")[step], {"seg": 9, "taper": 0.66}))
		for i in range(14):
			a = rnd.uniform(0, math.tau)
			rho = rr * rnd.uniform(0.15, 0.95)
			yy = hh * (1 - rho / rr)
			s = rnd.uniform(16, 28)
			mt.append(("cone", (s, s * 2.4, s), (x + math.cos(a) * rho, yy + s * 0.9, z + math.sin(a) * rho * 0.9), (CEDAR, CEDAR2)[i % 2], {"seg": 5}))
	k.prop("Mountain", mt)

	# --- Guardrail (48 studs): white W-beam on round posts, a concrete U-ditch in front, a grassy verge behind ---
	gr = []
	for x in range(-24, 25, 4):
		gr.append(("cyl", (0.7, 4.2, 0.7), (x, 2.1, 0.4), "D8DCDC", {"seg": 6, "metal": 0.4}))
	bx(gr, (48.2, 1.6, 0.25), (0, 3.2, -0.3), "EEF0F0", metal=0.5, rough=0.4)
	bx(gr, (48.2, 0.35, 0.35), (0, 3.5, -0.5), "FFFFFF", metal=0.5, rough=0.4)
	bx(gr, (48.2, 0.35, 0.35), (0, 2.9, -0.5), "FFFFFF", metal=0.5, rough=0.4)
	for x in (-12, 12):
		gr.append(("cyl", (0.5, 5, 0.5), (x, 2.5, 0.8), "F4F4F4", {"seg": 6}))
		bx(gr, (0.6, 0.6, 0.3), (x, 4.6, 0.5), "FF7A1A", emit=2.0)
	bx(gr, (48, 0.6, 3.2), (0, -0.4, -3.2), "7C7E78")  # U-ditch rim
	bx(gr, (48, 0.3, 2.0), (0, -0.2, -3.2), "1C2228", rough=0.2)  # its dark water line
	bx(gr, (48, 0.5, 8), (0, -0.55, 4.5), "23301F")  # verge grass
	for i in range(9):
		s = rnd.uniform(1.5, 3.5)
		gr.append(("cone", (s, s * 1.2, s), (rnd.uniform(-22, 22), s * 0.4 - 0.6, rnd.uniform(1.5, 8)), ("2C3E26", "35482C")[i % 2], {"seg": 5}))
	k.prop("Guardrail", gr)

	# --- Curve mirror (orange pole, round convex mirror with hood) + a blank chevron curve sign ---
	k.prop(
		"Mirror",
		[
			("cyl", (0.9, 13, 0.9), (0, 6.5, 0), "E86A1C", {"seg": 8}),  # pole ends below the disc
			("box", (0.7, 2.6, 0.7), (0, 13.6, 0), "E86A1C"),  # bracket: up from the pole top, then forward
			("box", (0.7, 0.7, 2.6), (0, 14.6, -1.0), "E86A1C"),
			("cyl", (6.0, 1.0, 6.0), (0, 15.2, -2.6), "E86A1C", {"seg": 18, "rot": (90, 0, 0)}),  # orange rim, solid back
			("cyl", (5.0, 0.5, 5.0), (0, 15.2, -3.2), "C9D4DC", {"seg": 18, "rot": (90, 0, 0), "rough": 0.25, "metal": 0.4, "emit": 0.35}),
			("box", (6.4, 0.5, 2.0), (0, 18.6, -3.0), "E86A1C", {"rot": (-12, 0, 0)}),  # flat hood above the disc
			("cyl", (0.6, 9, 0.6), (4, 4.5, 0), "9A9EA2", {"seg": 6}),
			("box", (4.2, 4.2, 0.2), (4, 8.6, -0.4), HAZ_Y, {"rot": (0, 0, 45)}),
			("box", (2.0, 0.6, 0.25), (3.6, 9.2, -0.55), HAZ_K, {"rot": (0, 0, 45)}),
			("box", (2.0, 0.6, 0.25), (3.6, 8.0, -0.55), HAZ_K, {"rot": (0, 0, -45)}),
		],
	)

	# --- Tunnel lining slice: a near-black round vault (no lamps; the portal carries the few lamps), 14 deep so the
	# slices overlap through the bend ---
	ts = []
	for s in (-1, 1):
		bx(ts, (3, SPR + 1, 14), (s * (R + 1.5), (SPR - 1) / 2, 0), LINING)
		bx(ts, (0.3, 4, 14), (s * (R - 0.1), 1.0, 0), LINING2)
		bx(ts, (3, 1.2, 14), (s * (R - 1.5), 1.6, 0), "262A24")
		bx(ts, (14, 44, 14), (s * (R + 10), 21, 0), "1E221C")
	n = 14
	for i in range(n):
		a = math.pi * (i + 0.5) / n
		rr = R + 1.5
		ts.append(("box", (2 * math.pi * rr / 2 / n * 1.08, 3, 14), (math.cos(a) * rr, SPR + math.sin(a) * rr, 0), LINING, {"rot": (0, 0, math.degrees(a) - 90)}))
	bx(ts, (82, 12, 14), (0, SPR + R + 8, 0), "1E2A22")
	k.prop("TunnelSeg", ts)

	# --- Portal (hero): Turbo Granny's tunnel mouth. Rough dressed-stone face in running bond with uneven blocks and
	# depths, a raised voussoir ring, dark moss stains, ivy curtains pouring down both spandrels and over the ring to
	# the ground, yellow-black barriers and a red-and-white no-entry board by the walkway, the forested hill above,
	# and the tunnel's only lamps (two per mouth, far inside). -Z faces the approaching road. ---
	po = []
	top, half, ch = 62.0, 46.0, 3.6  # the arch fills about 60% of the face width, with short spandrels (source)
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
		for a, b in spans:  # running bond, uneven widths, tones and depths
			x = a
			while x < b - 0.5:
				w = min(rnd.choice((3.6, 4.4, 5.2, 6.0, 7.2)), b - x)
				dep = rnd.uniform(4.2, 6.2)
				bx(po, (w - 0.4, ch - 0.4, dep), (x + w / 2, yc + rnd.uniform(-0.1, 0.1), 2.5 - dep / 2 + rnd.uniform(-0.3, 0.3)), rnd.choice(STONES))
				x += w
	bx(po, (half * 2, top - SPR - ring, 4), (0, SPR + ring + (top - SPR - ring) / 2, 1.6), MORTAR)
	bx(po, (half * 2, top - SPR - R - 1, 1.5), (0, SPR + R + 1 + (top - SPR - R - 1) / 2, 3.4), MORTAR)  # backing over the crown: no see-through gaps
	for s in (-1, 1):  # mortar behind the side joints too
		bx(po, (half - R - 1, top + 1, 3), (s * (half + R + 1) / 2, (top - 1) / 2, 2.2), MORTAR)
	nv = 10  # large voussoirs in one grey-green tone, and a recessed inner ring for a stepped deep reveal
	for i in range(nv):
		a = math.pi * (i + 0.5) / nv
		rr = R + 3.2
		tone = rnd.choice(("6A7062", "5A6052", "767C6C", "62685A", "707466"))
		po.append(("box", (2 * math.pi * rr / 2 / nv * 0.94, 7.4 if i == nv // 2 else 6.6, 7.0), (math.cos(a) * rr, SPR + math.sin(a) * rr, -0.9), tone, {"rot": (0, 0, math.degrees(a) - 90 + rnd.uniform(-1.5, 1.5))}))
		po.append(("box", (2 * math.pi * (R + 0.6) / 2 / nv * 0.96, 1.6, 4.0), (math.cos(a) * (R + 0.6), SPR + math.sin(a) * (R + 0.6), 2.4), "4A5046", {"rot": (0, 0, math.degrees(a) - 90)}))
	for s in (-1, 1):
		bx(po, (6.5, 2.4, 6.6), (s * (R + 3), SPR - 0.2, -0.7), "7A7E70")
		bx(po, (6, 3, 6.4), (s * (R + 3), 0.5, -0.6), STONE2)
	bx(po, (half * 2 + 3, 2.2, 7.5), (0, top + 0.6, -0.4), "6E7266")  # cornice
	bx(po, (half * 2 + 1, 3.0, 6), (0, top + 3.1, 0.2), STONE2)  # parapet
	bx(po, (half * 2 + 4, 1.2, 7.4), (0, top + 5.2, 0.2), "7A7E70")  # parapet cap
	for s in (-1, 1):  # pilaster edges, proud of the face, stepped at the foot
		bx(po, (7, top + 1, 8.5), (s * (half - 2.5), (top - 1) / 2, -1.2), "6A6E60")
		bx(po, (8.6, 6, 9.6), (s * (half - 2.5), 2, -1.4), STONE2)
		bx(po, (8.2, 1.4, 9.2), (s * (half - 2.5), top - 1.2, -1.4), "7A7E70")
	# dark moss and water stains: streaks down from the cornice and up from the ground
	for i in range(34):
		x = rnd.uniform(-half + 2, half - 2)
		if abs(x) < R + 4:
			continue
		ln = rnd.uniform(6, 34)
		y = top - ln / 2 if i % 2 else ln / 2 - 1
		bx(po, (rnd.uniform(1, 4), ln, 0.3), (x, y, -2.7), (MOSS, "1E2619", "2C3424")[i % 3])
	for i in range(10):  # stains on the ring itself
		a = rnd.uniform(0.2, math.pi - 0.2)
		bx(po, (rnd.uniform(1.5, 3), rnd.uniform(4, 9), 0.3), (math.cos(a) * (R + 3), SPR + math.sin(a) * (R + 3), -3.85), MOSS)
	# the hillside over the tunnel: a lumpy forested mound (overlapping faceted masses) rising back from the parapet,
	# with ivy and undergrowth clumps and cedars on it
	# the hill: layered earth tiers stepping back up the slope, each with a grey rock ledge at its lip and cedars
	# along it, so it reads as a terraced forested hillside; low side wedges carry the earth down beside the face
	VT = SPR + R + 3  # the hill sits on the tunnel vault: below this the bore stays open (earth only beside it)
	for s in (-1, 1):
		bx(po, ((half * 2 + 110) / 2 - R - 3, VT + 1, 170), (s * ((half * 2 + 110) / 2 + R + 3) / 2, VT / 2 - 1, 2 + 85), "1E2E24")
	tiers = [(VT - 1, top + 7 - VT, half * 2 + 110, 200, 2), (top + 5, 26, half * 2 + 70, 150, 26), (top + 30, 24, half * 2 + 30, 100, 52)]
	for t, (y0, th, wx, dz, z0) in enumerate(tiers):
		hc = z0 + dz / 2 * 0.866
		# turned 30 degrees so a flat side (not a corner) faces the road; a corner would poke through the face
		po.append(("cyl", (wx, th, dz), (0, y0 + th / 2, hc), ("1E2E24", "22362A", "1A2A20")[t], {"seg": 6, "taper": 0.86, "rot": (0, 30, 0)}))
		po.append(("cyl", (wx * 0.88, 3, dz * 0.88), (0, y0 + th, hc), "4A5046", {"seg": 6, "rot": (0, 30, 0)}))  # rock ledge at the lip
		lip_z, lip_w = z0 + dz / 2 * 0.866 * 0.12, wx * 0.86 / 4
		for i in range(5):  # cedars along the lip, down the front slope
			x = -lip_w + i * lip_w / 2 + rnd.uniform(-4, 4)
			hh = rnd.uniform(40, 58)
			y = y0 + th + 1
			po.append(("cyl", (2.6, hh * 0.4, 2.6), (x, y + hh * 0.2, lip_z + 4), BARK, {"seg": 6}))
			for j in range(3):
				w = (28, 21, 14)[j] * hh / 54
				po.append(("cone", (w, hh * 0.38, w), (x, y + hh * (0.34 + j * 0.2), lip_z + 4), (CEDAR, CEDAR2)[(i + j) % 2], {"seg": 8}))
		for i in range(4):  # rock outcrops on the slope face
			po.append(("box", (rnd.uniform(10, 20), rnd.uniform(5, 9), 6), (rnd.uniform(-wx * 0.3, wx * 0.3), y0 + th * rnd.uniform(0.3, 0.8), z0 + 3), "3E443C", {"rot": (rnd.uniform(-20, 0), rnd.uniform(-15, 15), rnd.uniform(-15, 15))}))
	for s in (-1, 1):
		po.append(("wedge", (60, top, 70), (s * (half + 30), top / 2 - 1, 34), "1C2A22", {"rot": (0, -s * 90, 0)}))
	for i in range(26):  # ivy hanging over the parapet and its cap
		x = rnd.uniform(-half, half)
		hh = rnd.uniform(4, 12)
		po.append(("ball", (rnd.uniform(3, 6), hh, 1.6), (x, top + 5 - hh / 2, -3.6), (IVY, IVY3, IVY2)[i % 3], {"subdiv": 1}))
	# ivy: a heavy uneven mass of small flat leaf clusters over the top-right (viewer's right is -X), thinner on the
	# left; the voussoir ring is left mostly bare
	for i in range(110):
		x = rnd.uniform(-half - 4, -6) if i < 80 else rnd.uniform(8, half)
		depth = rnd.uniform(4, 30) if i < 80 else rnd.uniform(2, 8)
		y = top + 2 - depth * rnd.random()
		if abs(x) < R + 9 and y < SPR + math.sqrt(max(0.0, (R + 9) ** 2 - x * x)) + 1:
			continue
		sz = rnd.uniform(2, 6)
		po.append(("ball", (sz * rnd.uniform(1.2, 2.0), sz * rnd.uniform(0.5, 0.9), sz * 0.3), (x, y, -3.0 - rnd.uniform(0, 1.6)), (IVY, IVY2, IVY3)[rnd.randrange(3)], {"subdiv": 1, "rot": (0, 0, rnd.uniform(-30, 30))}))
	for s, n in ((-1, 13), (1, 5)):  # curtains: many on the right, a few on the left, some reaching the ground
		for i in range(n):
			x = s * rnd.uniform(R + 7, half + 2)
			bottom = -1 if i % 3 == 0 else rnd.uniform(4, top * 0.6)
			y = top
			while y > bottom:
				w = rnd.uniform(2.5, 7.5)
				hh = rnd.uniform(3.5, 8)
				po.append(("ball", (w, hh, rnd.uniform(1.2, 2.4)), (x + rnd.uniform(-2, 2), y - hh / 2, -3.1 - rnd.uniform(0, 0.7)), (IVY, IVY3, IVY2)[rnd.randrange(3)], {"subdiv": 1}))
				y -= hh * rnd.uniform(0.6, 0.85)
	for i in range(5):
		po.append(("ball", (rnd.uniform(6, 14), rnd.uniform(3, 7), 5), (-rnd.uniform(R + 8, half), 1, -4), IVY3, {"subdiv": 1}))
	for i in range(4):  # a few strands over the voussoirs, stopping short of the opening
		x = rnd.uniform(-R - 4, R + 4)
		bottom = SPR + math.sqrt(max(0.0, R * R - x * x)) + rnd.uniform(0.5, 4)
		y = top
		while y > bottom:
			hh = min(rnd.uniform(3, 6), y - bottom + 1)
			po.append(("ball", (rnd.uniform(2, 4.5), hh, 1.4), (x + rnd.uniform(-0.8, 0.8), y - hh / 2, -4.2), (IVY, IVY3, IVY2)[rnd.randrange(3)], {"subdiv": 1}))
			y -= hh * 0.7
	# three large yellow-black A-frame barriers (1.5x) and a tall red-and-white board at the mouth, a notice board on a
	# pole at the left (+X); all 24+ from the centre
	for cx, cz in ((-33, -14), (33, -12), (50, -18)):
		for ex in (-7.8, 7.8):
			for lean in (-12, 12):
				bx(po, (1.2, 19, 1.2), (cx + ex, 8.1, cz + lean * 0.18), "D8D8D8", rot=(lean, 0, 0))
		for q in range(12):
			bx(po, (1.4, 5.1, 0.5), (cx - 7.7 + q * 1.4, 14.7, cz - 1.2), (HAZ_Y, HAZ_K)[q % 2], rot=(0, 0, 20))
		bx(po, (17, 5.4, 0.4), (cx, 14.7, cz - 1.0), HAZ_Y)
		for q in range(12):
			bx(po, (1.4, 3.6, 0.5), (cx - 7.7 + q * 1.4, 6.0, cz - 1.2), (HAZ_Y, HAZ_K)[q % 2], rot=(0, 0, 20))
	bx(po, (8, 20, 0.4), (29.5, 16, -24), "F2F2EE")  # beside the left barriers (viewer's left is +X)
	bx(po, (6.8, 18.8, 0.3), (29.5, 16, -24.2), "C62828")
	bx(po, (5.6, 17.6, 0.3), (29.5, 16, -24.3), "F2F2EE")
	for ex in (-2.8, 2.8):
		bx(po, (0.6, 7, 0.6), (29.5 + ex, 2.5, -24), "8A8A8A")
	bx(po, (0.8, 16, 0.8), (64, 7, -14), "8A8A8A")  # notice board on a pole at the left (blank)
	bx(po, (8, 6, 0.4), (64, 15, -14.4), "D8D8CC")
	bx(po, (8.6, 6.6, 0.3), (64, 15, -14.2), "5A5A50")
	for j, z in enumerate(LAMPS):  # the tunnel's lamps: one fixture each, on alternate walls
		s = (-1, 1)[j % 2]
		bx(po, (1.4, 2.0, 5.0), (s * (R - 0.8), SPR + 3, z), SODIUM, emit=14.0)
		bx(po, (1.8, 0.6, 5.6), (s * (R - 0.9), SPR + 4.3, z), "2A2A2A")
	k.prop("Portal", po)

	# --- Kami High (hero): white 4-floor block on a pillar grid, glass bays, floor bands, the glass stair tower at the
	# right end and the entrance canopy left of centre (as seen from the road), clock box, roof fence, rear wing, gym,
	# low brown brick gate walls and piers, an entrance canopy at the left opening, a green sliding lattice gate at the right. ---
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
			bx(sc, (0.4, 7.2, 0.6), (x, y, -D / 2 - 0.3), "C8CCD0")
			bx(sc, (bay - 2.2, 0.4, 0.6), (x, y + 1.6, -D / 2 - 0.3), "C8CCD0")
		bx(sc, (W + 1, 1.4, 2.2), (0, f * FL + FL - 1.7, -D / 2 - 1), "F4F4F0")
	for b in range(NB + 1):
		bx(sc, (1.8, H + 2, 2.6), (-W / 2 + b * bay, H / 2, -D / 2 - 1.2), "FAFAF6")
	bx(sc, (W + 2, 2.4, D + 2), (0, H + 0.2, 0), "D2D2CC")
	for x in range(-80, 81, 8):
		bx(sc, (0.3, 4, 0.3), (x, H + 3.2, -D / 2), "9AA2A0")
	bx(sc, (W, 0.4, 0.4), (0, H + 5, -D / 2), "9AA2A0")
	bx(sc, (W, 0.4, 0.4), (0, H + 3, -D / 2), "9AA2A0")
	bx(sc, (14, 8, 10), (50, H + 5, 4), "DCDCD4")
	sc.append(("cyl", (9, 8, 9), (-40, H + 6, 6), "C8CCD0", {"seg": 12}))
	tx = -(W / 2 + 8)  # glass stair tower: -X is the viewer's right
	bx(sc, (16, H + 6, 18), (tx, (H + 6) / 2 - 1, -4), "9DB6C6", rough=0.1, metal=0.4)
	for q in range(5):
		bx(sc, (0.5, H + 6, 0.6), (tx - 7.5 + q * 3.75, (H + 6) / 2 - 1, -13.2), "E8ECEC")
	for f in range(5):
		bx(sc, (16.4, 0.6, 18.4), (tx, f * FL + 2, -4), "E8ECEC")
	bx(sc, (16.6, 1.4, 18.6), (tx, H + 5.6, -4), "E8ECEC")
	bx(sc, (8, 8, 2), (6, H + 5, -D / 2 - 0.6), "F4F4F0")  # clock box (blank face, two hands)
	sc.append(("cyl", (6, 0.6, 6), (6, H + 5, -D / 2 - 1.8), "FFFFFF", {"seg": 16, "rot": (90, 0, 0), "emit": 0.6}))
	bx(sc, (0.4, 2.4, 0.3), (6, H + 6, -D / 2 - 2.2), "202020")
	bx(sc, (1.8, 0.4, 0.3), (6.8, H + 5, -D / 2 - 2.2), "202020")
	bx(sc, (34, 3.0, 22), (40, 10, -D / 2 - 11), "F4F4F0")  # deep slab canopy, left of centre as seen
	bx(sc, (34.4, 0.8, 22.4), (40, 8.2, -D / 2 - 11), "C8C8C2")
	for x in (25, 55):
		bx(sc, (1.6, 10, 1.6), (x, 4, -D / 2 - 21), "D8D8D4")
	bx(sc, (18, 8, 0.4), (40, 3, -D / 2 - 0.4), "3A4A58", rough=0.1)
	bx(sc, (40, 36, 70), (-60, 17, 50), "DCDCD6")
	bx(sc, (70, 22, 50), (50, 10, 60), "C9C6BC")
	sc.append(("cyl", (50, 70, 18), (50, 21, 60), "6C7A86", {"rot": (0, 90, 90), "seg": 14, "metal": 0.3}))
	gz = -62.0  # gate line, as in the source: low brick walls, brick piers, an entrance canopy at the left opening,
	# a green sliding lattice gate in the right opening; no lamps, no centred double gate
	BR, BR2, BR3 = "7A4E36", "5E3A28", "6A4230"
	for x0, x1 in ((44, 92), (-40, -92)):  # low brick walls with coping and coursing
		cx, wl = (x0 + x1) / 2, abs(x1 - x0)
		bx(sc, (wl, 10, 3.4), (cx, 4, gz), BR)
		bx(sc, (wl + 0.6, 1.0, 4.0), (cx, 9.4, gz), BR2)
		for c in range(4):
			bx(sc, (wl + 0.1, 0.3, 3.5), (cx, 0.5 + c * 2.2, gz), BR3)
	for px in (40, 12, -38):  # brick piers with stepped coping
		bx(sc, (8, 17, 8), (px, 7.5, gz), BR)
		for c in range(5):
			bx(sc, (8.1, 0.3, 8.1), (px, 1 + c * 3, gz), BR3)
		bx(sc, (9.4, 1.2, 9.4), (px, 16.6, gz), BR2)
		bx(sc, (7, 1.4, 7), (px, 17.9, gz), BR3)
	bx(sc, (24, 1.0, 24), (26, 14, gz + 8), "E6E6E0")  # entrance canopy over the left opening, toward the building
	bx(sc, (24.4, 1.6, 0.6), (26, 13.4, gz - 4.2), "C8CCD0")
	for x in (16, 36):
		bx(sc, (0.8, 14, 0.8), (x, 6.5, gz - 3.4), "C8CCD0")
	# sliding lattice gate: drawn mostly across the right opening (from the pier at 12 toward -38), on a ground rail
	bx(sc, (52, 0.4, 1.2), (-13, -0.6, gz - 2.6), "4A4E54", metal=0.6)
	for y in (0.6, 12.4):
		bx(sc, (40, 0.8, 0.8), (-12, y, gz - 2.6), "2E7E78")
	for x in (-32, -12, 8):
		bx(sc, (0.8, 12.6, 0.8), (x, 6.5, gz - 2.6), "2E7E78")
	for q in range(-5, 5):
		for r, dz in ((40, 0), (-40, -0.1)):
			bx(sc, (0.4, 15, 0.4), (-12 + q * 3.2 + 1.6, 6.5, gz - 2.6 + dz), "2E7E78", rot=(0, 0, r))
	for x in (-30, 6):
		sc.append(("cyl", (1.4, 0.6, 1.4), (x, -0.2, gz - 2.6), "2A2A2A", {"rot": (90, 0, 0), "seg": 8}))  # castors
	bx(sc, (W + 40, 0.6, 74), (0, -0.7, -26), "8C8A84")
	for x, z, s in ((-80, -48, 16), (-100, -40, 20), (90, -48, 18), (110, -30, 22), (-110, 10, 22)):
		sc.append(("cyl", (1.6, s * 0.6, 1.6), (x, s * 0.3 - 1, z), BARK, {"seg": 6}))
		sc.append(("ball", (s * 1.2, s, s * 1.2), (x, s * 0.9, z), ("2E5A30", "356638")[s % 2], {"subdiv": 1}))
	k.prop("School", sc)

	# --- Nagi Hospital (hero): abandoned 12-floor block, a taller narrow shaft on the viewer's right, a lower wing on
	# the left, dark vertical stain strips, a darker stepped crown carrying the blank sign frame, the construction
	# hoarding pushed forward toward the road. ---
	ho = []
	HW, HD, HH, NF = 80.0, 40.0, 132.0, 12
	bx(ho, (HW, HH, HD), (0, HH / 2 - 1, 0), "34507E")  # dark-blue concrete
	bx(ho, (24, HH + 8, HD - 6), (-HW / 2 - 10, (HH + 8) / 2 - 1, 2), "2E4672")
	bx(ho, (12, HH, 0.04), (-12, HH / 2 - 1, -HD / 2 - 0.53), "1A2640")  # vertical grime band: over the frames, under the glass
	fh = HH / NF
	glow = {5, 17, 30, 44, 51, 66}
	for f in range(NF):
		y = f * fh + fh * 0.55
		for c in range(10):
			on = (f * 8 + c) in glow
			bx(ho, (6.6, fh * 0.62, 0.5), (-HW / 2 + 4 + c * 8, y, -HD / 2 - 0.25), "22324E")  # dark recess round each window
			bx(ho, (5.2, fh * 0.48, 0.3), (-HW / 2 + 4 + c * 8, y, -HD / 2 - 0.45), "9FD8FF" if on else DARKWIN, emit=2.5 if on else 0.0, rough=0.3)
		for c in range(5):
			bx(ho, (0.4, fh * 0.5, 5.2), (HW / 2 + 0.1, y, -HD / 2 + 4 + c * 8), DARKWIN, rough=0.3)
		for c in range(2):
			bx(ho, (6, fh * 0.5, 0.4), (-HW / 2 - 4 - c * 12, y, -HD / 2 + 2.9), DARKWIN, rough=0.3)
		bx(ho, (HW + 0.6, 0.8, 0.6), (0, f * fh + 0.4, -HD / 2 - 0.2), "5A76A2")
	for c in range(11):  # vertical pilaster strips between the window columns
		bx(ho, (1.4, HH, 1.2), (-HW / 2 + c * 8, HH / 2 - 1, -HD / 2 - 0.6), "52709C")
	for i in range(22):  # thin, lighter rain streaks down from the crown
		x = rnd.uniform(-HW / 2 + 1, HW / 2 - 1)
		ln = rnd.uniform(20, HH * 0.8)
		bx(ho, (rnd.uniform(0.4, 0.9), ln, 0.2), (x, HH - ln / 2, -HD / 2 - 0.75), ("6A84AC", "5E7AA4", "7A92B6")[i % 3])
	for i in range(5):
		ln = rnd.uniform(30, 90)
		bx(ho, (0.2, ln, rnd.uniform(2, 4)), (HW / 2 + 0.3, HH - ln / 2, rnd.uniform(-HD / 2 + 3, HD / 2 - 3)), "1E2A44")
	# two-height stepped sign crown: a lower block on the viewer's left (+X), a taller one on the right (-X), each
	# carrying blank dark sign panels flush on its front
	bx(ho, (HW / 2 + 1, 8, HD), (HW / 4, HH + 3, 0), "2A3E62")
	bx(ho, (HW / 2 + 1, 17, HD), (-HW / 4, HH + 7.5, 0), "26385A")
	bx(ho, (HW / 2 + 1.6, 1.2, HD + 1), (HW / 4, HH + 7.6, 0), "1E2C48")
	bx(ho, (HW / 2 + 1.6, 1.2, HD + 1), (-HW / 4, HH + 16.6, 0), "1E2C48")
	for c in range(2):
		bx(ho, (9, 6, 0.5), (HW / 4 - 6 + c * 12, HH + 3, -HD / 2 - 0.3), "2A3448")
	for c in range(3):
		bx(ho, (10, 10, 0.5), (-HW / 4 - 12 + c * 12, HH + 8, -HD / 2 - 0.3), "2A3448")
	ho.append(("cyl", (10, 10, 10), (-14, HH + 20, 8), "2E3E5C", {"seg": 12}))  # roof tank
	bx(ho, (46, 26, 50), (HW / 2 + 18, 12, -6), "3A4E74")  # lower wing, viewer's left
	windows(ho, HW / 2 - 4, HW / 2 + 40, 5, 6, 2, 11, -31.3, 5, 4.6, DARKWIN)
	bx(ho, (48, 1.6, 52), (HW / 2 + 18, 25.8, -6), "2E3E5E")
	hz = -95.0  # hoarding (1.3x scale: 26 from the road), 24 tall; hazard posts at the gate and at the near (+X) end
	for i in range(16):
		x = -86 + i * 11
		if -8 < x < 8:
			continue
		bx(ho, (10.6, 24, 0.6), (x, 11, hz), ("2E4A4A", "345454")[i % 2])
		for q in range(4):
			bx(ho, (0.5, 24, 0.9), (x - 4 + q * 2.6, 11, hz - 0.2), "28403F")
	for px in (-8, 8, 92):
		bx(ho, (2.2, 27, 2.2), (px, 12.5, hz - 0.6), HAZ_K)
		for q in range(9):
			bx(ho, (2.3, 1.5, 2.3), (px, 1 + q * 3, hz - 0.6), HAZ_Y, rot=(0, 0, 20))
	for q in range(7):
		bx(ho, (0.4, 11, 0.4), (-6 + q * 2, 4.5, hz - 0.5), "1E2626", metal=0.6)
	bx(ho, (16, 0.5, 0.5), (0, 9.5, hz - 0.5), "1E2626", metal=0.6)
	bx(ho, (6, 7, 0.3), (-22, 6, hz - 0.5), "C8D8C8")
	for i in range(10):
		ho.append(("ball", (rnd.uniform(4, 8), rnd.uniform(2, 4), rnd.uniform(4, 8)), (rnd.uniform(-80, 80), 0.5, hz + 4), (IVY, IVY3)[i % 2], {"subdiv": 1}))
	bx(ho, (190, 0.6, 100), (0, -0.8, -46), "3A403E")
	k.prop("Hospital", ho)

	# --- Seiko's house (hero), on a stone embankment so the canal shows over the road wall: the canal at the front
	# edge with a stone bridge, the light granite torii and two lit stone lanterns in front of the house (shifted
	# toward the approaching runner, local +X), a slatted fence on a stone base, the white-walled timber-framed house
	# with rust-red tiled roofs, a small shrine with a straw rope and paper streamers, garden pines. ---
	se = []
	GRAN, GRAN2, WOOD = "A2A49C", "8C8E86", "5A3E2A"
	bx(se, (124, 7.0, 1.4), (0, -3.6, -38.6), "7A7E76")  # embankment face
	bx(se, (124, 7, 74), (0, -3.5, 0), "6A6E66")  # terrace
	for x in range(-60, 61, 6):
		bx(se, (0.3, 7.0, 1.5), (x, -3.6, -38.7), "5E625A")
	PAR = "8E887C"  # stone parapet with square posts along the front edge
	bx(se, (124, 0.6, 1.4), (0, -0.2, -37.6), PAR)  # low front lip only, so the canal shows from the road
	bx(se, (124, 1, 12), (0, -0.45, -30.5), "24485A", rough=0.05, metal=0.3, emit=0.25)  # dark canal water
	bx(se, (124, 2.0, 1.4), (0, 1.0, -24.0), PAR)  # stone parapet with square posts on the far bank
	for x in range(-60, 61, 8):
		if abs(x - 24) > 8:
			bx(se, (2.2, 3.6, 2.2), (x, 1.8, -24.0), "7E786C")
	TX, TZ = 24.0, -20.0
	bx(se, (14, 1.6, 15), (TX, 1.0, -30.5), "8A847A")  # stone bridge over the canal, square-post parapets
	for s_ in (-1, 1):
		bx(se, (1.2, 1.4, 15), (TX + s_ * 7, 3.8, -30.5), PAR)
		for z in (-37, -33.5, -30, -26.5, -23.5):
			bx(se, (1.8, 3.6, 1.8), (TX + s_ * 7, 2.8, z), "7E786C")
	# weathered warm-grey granite torii: round pillars on plinths, nuki tie-beam, a curved kasagi in three pieces with
	# upturned ends over a shimaki, a central strut; dark and light speckles over the stone
	STN, STN2 = "9A9286", "847C70"
	for s_ in (-1, 1):
		se.append(("cyl", (6.2, 26, 6.2), (TX + s_ * 8, 13.5, TZ), STN, {"seg": 16, "rough": 1.0, "taper": 0.92, "smooth": True}))
		se.append(("cyl", (7.8, 1.8, 7.8), (TX + s_ * 8, 0.9, TZ), STN2, {"seg": 16, "smooth": True}))
		bx(se, (7.6, 2.4, 3.6), (TX + s_ * 10.8, 28.2, TZ), STN, rot=(0, 0, s_ * 9))
		bx(se, (6, 1.4, 3.8), (TX + s_ * 11, 29.7, TZ), STN2, rot=(0, 0, s_ * 9))
	bx(se, (15, 2.4, 3.6), (TX, 27.6, TZ), STN)
	bx(se, (16, 1.4, 3.8), (TX, 29.1, TZ), STN2)
	bx(se, (24, 1.8, 3.0), (TX, 25.6, TZ), STN2)
	bx(se, (24, 2.0, 2.0), (TX, 21.0, TZ), STN)
	bx(se, (1.8, 2.8, 1.6), (TX, 23.2, TZ), STN2)
	for i in range(48):  # speckles all round the pillars and on the beams
		if i < 36:
			a = rnd.uniform(0, math.tau)
			x = TX + rnd.choice((-8, 8)) + math.cos(a) * 3.1
			z = TZ + math.sin(a) * 3.1
			y = rnd.uniform(2, 25)
		else:
			x, y, z = TX + rnd.uniform(-13, 13), rnd.uniform(25, 29), TZ - 1.95
		bx(se, (0.5, 0.5, 0.5), (x, y, z), rnd.choice(("6A645A", "B4AC9E", "5E584E")))
	for s_ in (-1, 1):  # lit stone lanterns either side of the torii
		lx = TX + s_ * 15
		bx(se, (5, 1.4, 5), (lx, 0.2, TZ + 2), STN2)
		se.append(("cyl", (2.2, 9, 2.2), (lx, 5.3, TZ + 2), STN, {"seg": 8}))
		bx(se, (4.6, 1.0, 4.6), (lx, 10.2, TZ + 2), STN2)
		bx(se, (3.8, 3.6, 3.8), (lx, 12.5, TZ + 2), "FFD58A", emit=3.0)
		se.append(("cone", (7, 3.2, 7), (lx, 16.0, TZ + 2), STN, {"seg": 6}))
		se.append(("ball", (1.6, 1.6, 1.6), (lx, 18.0, TZ + 2), STN, {"subdiv": 1}))
	FZ = -22.6  # tall slatted fence on a stone base along the canal bank, open at the bridge and torii
	for a, b in ((-62, TX - 9), (TX + 9, 62)):
		cx, wl = (a + b) / 2, b - a
		bx(se, (wl, 2.4, 2), (cx, 1.2, FZ), "7E786C")
		bx(se, (wl, 0.8, 1.2), (cx, 9.2, FZ), "4A3424")
		bx(se, (wl, 0.6, 1.0), (cx, 5.6, FZ + 0.5), "4A3424")
		for q in range(int(wl / 2.4)):
			bx(se, (1.4, 7.0, 0.6), (a + 1.2 + q * 2.4, 5.6, FZ), ("5A4030", "6A4A36")[q % 2])
		for q in range(int(wl / 9) + 1):
			bx(se, (1.6, 9.8, 1.6), (a + q * 9, 4.9, FZ + 0.4), "3E2C1E")
	bx(se, (50, 0.6, 26), (0, -0.7, -12), "8A8478")
	for z in (-22, -16, -10, -5):
		bx(se, (6, 0.4, 3.5), (0, -0.3, z), "A8A49A")
	bx(se, (44, 13, 22), (0, 5.5, 8), "E8E2D2")
	bx(se, (36, 10, 18), (0, 16.5, 9), "E2DCCC")
	for x in (-22, -11, 0, 11, 22):
		bx(se, (1.0, 12, 0.6), (x, 5, -3.2), WOOD)
	for x in (-18, -12, -6, 0, 6, 12, 18):  # white upper floor with dark timber framing: posts, rails, braces
		bx(se, (1.0, 10, 0.6), (x, 16.5, -0.2), WOOD)
	for y in (12.0, 21.0):
		bx(se, (36.4, 1.0, 0.6), (0, y, -0.2), WOOD)
	for x, r in ((-15, 40), (15, -40)):
		bx(se, (0.8, 9.4, 0.5), (x, 16.5, -0.3), WOOD, rot=(0, 0, r))
	bx(se, (44.4, 1.0, 0.8), (0, 11.6, -3.2), WOOD)
	bx(se, (44.4, 1.0, 0.8), (0, 0.4, -3.3), WOOD)
	bx(se, (48, 0.8, 4), (0, 1.2, -5.5), "6A4A32")
	windows(se, -20, 20, 4, 5.5, 1, 0, -3.4, 7, 7, "E6DEC4", lit=(1, 2), litcol="FFD58A")
	windows(se, -16, 16, 3, 17, 1, 0, -0.4, 6, 5, "D8D0B8", lit=(1,), litcol="FFD58A")
	gable(se, 0, 8, 50, 28, 11.6, 6, "8A3A2A", "6E2C20", ribs=10)
	gable(se, 0, 9, 40, 22, 21.4, 6, "8A3A2A", "6E2C20", ribs=8)
	# hokora (small shrine) on a stone plinth, high enough to show over the fence: thick straw rope with paper streamers
	HX, HZ = -34, -10
	bx(se, (12, 6, 10), (HX, 2, HZ), GRAN2)
	bx(se, (13, 0.8, 11), (HX, 5.2, HZ), STN)
	bx(se, (8, 7, 6), (HX, 9, HZ), "7A5236")
	bx(se, (4, 5, 0.3), (HX, 8.5, HZ - 3.1), "4A3424")
	gable(se, HX, HZ, 12, 9, 12.4, 4, "3A3A40", "2A2A30", ribs=3)
	se.append(("cyl", (1.3, 10, 1.3), (HX, 11.6, HZ - 3.6), "D8C890", {"rot": (0, 0, 90), "seg": 8}))  # shimenawa
	for q in range(4):  # shide streamers
		bx(se, (0.9, 1.4, 0.15), (HX - 3 + q * 2, 10.4, HZ - 4.3), "FFFFFF", emit=0.5)
		bx(se, (0.9, 1.4, 0.15), (HX - 2.6 + q * 2, 9.2, HZ - 4.3), "FFFFFF", emit=0.5)
	for x, z, s_ in ((36, -12, 18), (-50, 4, 20), (40, 20, 22), (-16, 22, 18)):  # garden pines, crowns over the fence
		se.append(("cyl", (1.8, s_ * 0.9, 1.8), (x, s_ * 0.45 - 1, z), BARK, {"seg": 6, "rot": (0, 0, 8)}))
		for j, (dx, dy, w) in enumerate(((-2, 0.62, 1.4), (3, 0.86, 1.1), (-1, 1.08, 0.8))):
			se.append(("ball", (s_ * w, s_ * 0.22, s_ * w * 0.8), (x + dx, s_ * dy, z), ("2C4E2E", "355C34")[j % 2], {"subdiv": 1}))
	k.prop("SeikoHouse", se)

	# --- Town houses (mid), two types; each carries block walls with caps across its whole 44-stud lot front, a lit
	# vending machine, a utility pole with crossarm and wires running to the lot edges (so poles link up) ---
	def lot(p, gap=(-3, 3)):
		for a, b in ((-22, gap[0]), (gap[1], 22)):
			bx(p, (b - a, 5, 1.4), ((a + b) / 2, 1.5, -15), "9A9A92")
			bx(p, (b - a + 0.4, 0.7, 2.2), ((a + b) / 2, 4.3, -15), "5E5E58")
			for x in range(int(a) + 3, int(b) - 1, 6):  # block courses
				bx(p, (0.3, 5, 1.5), (x, 1.5, -15), "86867E")
		for x in (-22, 22):
			bx(p, (1.4, 5, 28), (x, 1.5, -1), "8E8E86")

	def vending(p, x, z, body, cols):
		bx(p, (5.4, 10, 4), (x, 4, z), body)
		bx(p, (4.6, 6.4, 0.3), (x, 5.2, z - 2.1), "EAF6FF", emit=2.2)
		for q, c in enumerate(cols):
			for r_ in range(3):
				bx(p, (1.1, 0.9, 0.4), (x - 1.5 + r_ * 1.5, 3.2 + q * 1.6, z - 2.3), c, emit=1.6)
		bx(p, (4.6, 1.4, 0.4), (x, 8.6, z - 2.2), cols[0], emit=1.8)

	def pole(p, x, z):
		p.append(("cyl", (1.4, 34, 1.4), (x, 16, z), "9A9A96", {"seg": 8}))
		bx(p, (10, 0.6, 0.6), (x, 31, z), "6A6A66")
		p.append(("cyl", (2.2, 3.2, 2.2), (x - 2, 26, z + 1), "7A7E80", {"seg": 8}))
		for dx in (-4, 0, 4):
			bx(p, (0.4, 0.8, 0.4), (x + dx, 31.6, z), "E8E8E8")
			for side in (-1, 1):  # wires to the lot edge, sagging slightly
				ln = abs(side * 22 - x)
				bx(p, (ln, 0.15, 0.15), ((x + side * 22) / 2, 31.8 - 0.6 - dx * 0.05, z + dx * 0.1), "1A1A1A")

	hs = []  # two floors, tan siding, dark kawara gable, balcony, sliding-door bay, annex
	bx(hs, (24, 18, 18), (0, 8, 4), "BFB39A")
	for y in (3, 7, 11, 15):
		bx(hs, (24.2, 0.3, 18.2), (0, y, 4), "A89C84")
	windows(hs, -9, 9, 2, 12.5, 1, 0, -5.2, 6, 4.2, "2A3038", lit=(1,), frame="DADAD4")
	bx(hs, (14, 6, 0.4), (-3, 2.5, -5.2), "3A4450", rough=0.1)  # sliding-door bay
	for x in (-10, -3, 4):
		bx(hs, (0.5, 6.2, 0.6), (x, 2.5, -5.4), "D8D8D0")
	bx(hs, (16, 0.8, 4), (-2, 9, -7), "B0A898")  # balcony
	bx(hs, (16, 2.4, 0.3), (-2, 10.6, -8.9), "C8CCD0", metal=0.3)
	gable(hs, 0, 4, 28, 22, 17, 6, TILE, TILE2, ribs=9)
	bx(hs, (14, 10, 14), (16, 4, 6), "A8A090")
	hs.append(("wedge", (16, 3, 16), (16, 10.5, 6), TILE2, {"rot": (0, 180, 0)}))
	bx(hs, (6, 5, 0.4), (16, 4, -1.2), "FFD890", emit=1.0)
	lot(hs)
	vending(hs, -15, -18.5, "C83A2E", ("FF5A4A", "4AA8FF", "FFD24A"))
	vending(hs, -9, -18.5, "E8E8E8", ("4AA8FF", "7AE070", "FF8A3A"))
	pole(hs, 12, -18)
	k.prop("House", hs)

	h2 = []  # one wide floor, warm plaster, brown hip roof, sliding-door bays and engawa, garden pine
	bx(h2, (32, 10, 22), (0, 4, 4), "CDBB98")
	for s in (-1, 1):
		h2.append(("wedge", (36, 6, 13), (0, 12, 4 + s * 6.5), "5A3A2C", {"rot": (0, 0 if s < 0 else 180, 0)}))
		h2.append(("wedge", (26, 6, 6), (s * 15, 12, 4), "5A3A2C", {"rot": (0, -s * 90, 0)}))
	bx(h2, (37, 0.8, 1.2), (0, 15.2, 4), RIDGE)
	for x in (-10, 0, 10):  # sliding-door bays with frames, two lit
		bx(h2, (8.4, 7, 0.3), (x, 3.5, -7.1), "5A4A38")
		bx(h2, (7.4, 6.2, 0.4), (x, 3.5, -7.3), "FFD58A" if x != 0 else "E6DEC4", emit=1.0 if x != 0 else 0.0)
		bx(h2, (0.4, 6.2, 0.5), (x, 3.5, -7.5), "5A4A38")
	bx(h2, (34, 0.6, 3), (0, 0.4, -8.5), "6A4A32")
	lot(h2, gap=(4, 10))
	h2.append(("cyl", (1.2, 8, 1.2), (-14, 3, -10), BARK, {"seg": 6}))
	h2.append(("ball", (10, 4, 10), (-14, 7.5, -10), "2C4E2E", {"subdiv": 1}))
	vending(h2, 14, -18.5, "2E6AC8", ("FFD24A", "FF5A4A", "7AE070"))
	pole(h2, -4, -18)
	k.prop("House2", h2)

	# --- layout ---
	k.ground("1E2A22", margin=550)
	_fill(k, "232822")
	orig = k.beside

	d = TUNNEL[0] + 4  # slices (14 deep) stay behind both portal faces, so none pokes out in front of the stone
	while d <= TUNNEL[1] - 4:
		pos, yaw = orig(d, 0)
		k.place("TunnelSeg", pos, yaw)
		d += 12
	for d, flip, inward in ((TUNNEL[0] - 3, math.pi, 1), (TUNNEL[1] + 3, 0.0, -1)):
		pos, yaw = orig(d, 0)
		k.place("Portal", pos, yaw + flip)
		for j, z in enumerate(LAMPS):  # a yellow pool on the wall under each lamp, nothing else inside
			k.light(orig(d + inward * z, (-1, 1)[j % 2] * (R - 6), SPR + 2)[0], SODIUM, energy=7000, radius=1.2)
	# green wash on the masonry from high in front of each face, so it does not reach into the black vault
	k.light(orig(TUNNEL[0] - 16, 0, 78)[0], "7CFFA8", energy=26000, radius=6)
	k.light(orig(TUNNEL[1] + 16, 0, 78)[0], "7CFFB0", energy=26000, radius=6)

	# Town A (start, with Seiko's house at the near left edge), town B (after the hospital)
	towns = [(30.0, 760.0), (3780.0, 5600.0)]
	turns = (0.0, 0.0, 0.0, math.pi / 2, -math.pi / 2)
	for a, b in towns:
		row(k, a, b, 46, (52, -52), ["House", "House2"], jitter=2, flat=True, scale=(0.85, 1.1), skip=[(400, 640, -1), (5200, 5300, 0)])
		row(k, a + 20, b, 64, (100, -100), ["House2", "House", "Cedar"], jitter=10, scale=(0.9, 1.3), skip=[(390, 660, -1)], turns=turns)
	ob = put(k, "SeikoHouse", 510, -(25 + 39.3 * 2.0), 2.0, clear=50)
	if ob:
		ob.location.z += 14.0  # stands on its own embankment (its local -7 meets the ground)  # downhill of shot 1, so the canal and fence show over the wall
	# run shot 4's near field: a house with its lit vending machine on the right, a curve mirror on the left
	put(k, "House", 5250, 52)
	put(k, "House2", 5290, -52)
	put(k, "Mirror", 5232, -31, turn=-MIRROR_TURN)

	# Mountain road: guardrails (with ditch and verge), curve mirrors, cedars in layers, ridges
	mountain = [(760.0, TUNNEL[0] - 40), (TUNNEL[1] + 40, 2700.0), (3000.0, 3700.0)]
	clear = [(2560, 3000, 1), (2690, 2910, -1), (3450, 3780, -1)]  # side review camera; school front; hospital sightline
	for a, b in mountain:
		row(k, a, b, 48, (-34, 34), ["Guardrail"], flat=True)  # 34: on bends the straight 48-stud run cuts in by up to 5
		d = a + 60
		while d < b:
			for off in (-31, 31):
				put(k, "Mirror", d + k.rng.uniform(-6, 6), off, turn=MIRROR_TURN if off > 0 else -MIRROR_TURN)
			d += 210
		row(k, a, b, 34, (-42, 42), ["Cedar"], jitter=4, scale=(0.85, 1.1), skip=clear)
		row(k, a + 10, b, 40, (-60, 60), ["Cedar"], jitter=8, scale=(0.9, 1.2), skip=clear)
		row(k, a + 20, b, 46, (-82, 82), ["Cedar"], jitter=10, scale=(1.0, 1.4), skip=clear)
	d = TUNNEL[0] - 30
	while d < TUNNEL[1] + 30:
		for s in (-1, 1):
			put(k, "Cedar", d, s * 46, k.rng.uniform(0.9, 1.2))
		d += 30
	for s in (-1, 1):
		put(k, "Mountain", (TUNNEL[0] + TUNNEL[1]) / 2, s * 420, 0.6, clear=380)

	eye3, t3, r3, _ = shot_eye(k, 0.62)  # run shot 3's left half: a ridge, cedars and houses out to the horizon
	def toward(deg, dist):
		a_ = math.radians(deg)
		v = (t3 * math.cos(a_) - r3 * math.sin(a_)) * dist
		return eye3.x + v.x, eye3.z + v.z
	for dist in (900, 1000, 1150, 1300):
		x, z = toward(46, dist)
		if k.clear_of_road(x, z, 420):
			k.place("Mountain", (x, -1.0, z), k.rng.uniform(0, math.tau), 0.65)
			break
	for i in range(60):
		deg, dist = k.rng.uniform(40, 62), k.rng.uniform(140, 700)
		if deg < 47 and dist < 330:
			continue  # keep the sightline to the hospital
		x, z = toward(deg, dist)
		if k.clear_of_road(x, z, 40):
			k.place("Cedar" if i % 5 else "House2", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(0.9, 1.4))
	put(k, "School", 2790, -135, clear=60)  # square in the side shot (it looks across the road at 2768)
	row(k, 2600, 2960, 22, (46, 70, 95, 120), ["Cedar"], jitter=6, scale=(0.3, 0.5))  # low growth under the side camera
	put(k, "Hospital", 3820, -150, 1.15, clear=80)

	# Forest and far ridges, clear of the landmarks, the side camera and the hospital sightline
	avoid = []
	for d, off, r in ((2790, -135, 130), (3740, -150, 170), (510, -98, 130), (3650, -70, 110), (2740, 110, 140)):
		(x, _, z), _ = orig(d, off)
		avoid.append((x, z, r))
	placed, tries = 0, 0
	while placed < 190 and tries < 6000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 350, k.hi.x + 350)
		z = k.rng.uniform(k.lo.z - 350, k.hi.z + 350)
		if all(math.hypot(x - ax, z - az) > r for ax, az, r in avoid) and k.clear_of_road(x, z, 70):
			k.place("Cedar", (x, -1.0, z), k.rng.uniform(0, math.tau), k.rng.uniform(0.9, 1.5))
			placed += 1
	placed, tries = 0, 0  # far ridges, kept well away from the landmarks so none stands in front of them
	while placed < 14 and tries < 6000:
		tries += 1
		x = k.rng.uniform(k.lo.x - 650, k.hi.x + 650)
		z = k.rng.uniform(k.lo.z - 650, k.hi.z + 650)
		sc = k.rng.uniform(0.8, 1.4)
		reach = 580 * sc + 40  # a ridge spans about 560 studs from its centre at scale 1
		if all(math.hypot(x - ax, z - az) > r + reach for ax, az, r in avoid) and k.clear_of_road(x, z, reach):
			k.place("Mountain", (x, -1.0, z), k.rng.uniform(0, math.tau), sc)
			placed += 1

	# Night sky and a big full moon (sky dressing, the game's Sky moon; not a prop asset), set up-left of run shot 3
	moon = bpy.data.objects.new("SkyMoon", bpy.data.meshes.new("SkyMoon"))
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=3, radius=95)
	bm.to_mesh(moon.data)
	bm.free()
	moon.data.materials.append(k.mat("EEF6FF", emit=8.0))
	eye, t, right, ey = shot_eye(k, 0.62)
	az, el, dist = math.radians(15), math.radians(24), 1800  # up-left of the hospital crown, still clear of the frame edge (no stretch)
	v = (t * math.cos(az) - right * math.sin(az)) * dist * math.cos(el)
	moon.location = kit.rb(eye.x + v.x, ey + dist * math.sin(el), eye.z + v.z)
	k.col.objects.link(moon)
	k.sky([(0.0, "2C5488"), (0.06, "1A3460"), (0.35, "0B1838"), (1.0, "030812")], strength=1.0, sun=(1.5, "8FB0FF", 38, 160))
	for ob in k.col.objects:  # soft moonlight: wide light angle, so cedar shadows on the verge are soft
		if ob.type == "LIGHT" and ob.data.type == "SUN":
			ob.data.angle = math.radians(22)
	for a, b in towns:
		d = a + 20
		while d < b:
			for s in (-1, 1):
				pos, _ = orig(d, s * 36, 8)
				k.light(pos, WARM, energy=3500, radius=4)
			d += 88
	for a, b in mountain:
		d = a + 30
		while d < b:
			pos, _ = orig(d, 22, 18)
			k.light(pos, SODIUM, energy=22000, radius=5)
			d += 160
	k.light(orig(2790, -70, 20)[0], "FFE8B0", energy=50000, radius=8)  # school gate
	k.light(orig(2790, -100, 50)[0], WARM, energy=50000, radius=10)
	k.light(orig(3730, -80, 60)[0], "6FA8FF", energy=160000, radius=20)
	k.light(orig(510, -80, 50)[0], "B8C8E0", energy=9000, radius=12)  # soft cool fill, no glow on the stone
