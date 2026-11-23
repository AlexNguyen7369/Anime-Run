"""World 2 Track 1: Devil Hunter Tokyo (Saw Man). Night Tokyo where the devil hunters work, built to read 1-1 with the
anime's street scenes (refs and landmark list: docs/world2_refs/DevilTokyo.md):
- the hunters' headquarters: the tallest mass in town, a pale grey stepped government block with deep horizontal slabs
  (Kasumigaseki style), sparse lit offices, a lit forecourt and a large changed emblem (ring and diamond, not the real
  mark) on the roof edge, standing at the end of a street axis the runner looks down;
- the partners' apartment: a 7-storey mansion block with balconies on one face and the open corridor face (walkway,
  railing, row of steel doors, lit stair slits) on the other; some face the road with the corridor;
- a 2-storey wooden apartment with an open steel corridor, outside stairs and a vending cluster at its end;
- narrow-street dressing outside the road walls: dark pavement on a raised kerb, white guardrail, curved-arm lamps with
  warm pools, concrete utility poles (a transformer drum on every second one) with 8 sagging wires per span, black cable
  bundles and wires crossing high over the street;
- shophouses with shutters, awnings, narrow stacked corner signs and a pair of vending machines; a convenience store;
- the infield as low back-street blocks: coin parking, small houses, a pocket park;
- a Jinbocho corner from the film: a retro tiled building and a lit phone booth.
Signs are abstract coloured panels with glyph blocks only (no text, no real shop colours or logos, design doc 5).
Everything in-house, parts only. Building walls vary per instance (grey concrete, brown tile, off-white, green) through the
material's object-random colour (the game needs a colour per instance the same way). Proposed look; the owner approves the
render set (design doc 4.47)."""

import math

MODEL_SHOTS = ["HQ", "Mansion", "Apaato", "Konbini", "Retro"]  # hero close-ups judged at full size (build_track)
CLEAR_EXEMPT = {"CrossWire"}  # wires spanning the street overhead: lowest point 20+ studs over the road top (14+ rule)

ASPH, PAVE, CURB = "3A3C40", "2C2E33", "9A9C9E"
MANSION_WALL, SHOP_WALL, APA_WALL = "D6D0C3", "B8B0A3", "A99C83"  # keys for the per-instance colour variation
TILE2, TILE3 = "C9C2B2", "E4E0D6"
SIDING2 = "8C8270"
STEEL, STEEL2, FRAME = "6E747C", "4C525A", "3A3E46"
WARM, SODIUM, COOL, TV = "FFD9A0", "FFA850", "DCEBFF", "9FC0FF"
DARK = "141824"
SIGNS = ("C88068", "7AA8A4", "D8B068", "9A8AB0", "E0A060", "A8B890")  # muted: amber, off-white teal, dusty tones
HQ_GREY, HQ_SLAB = "B4B6B6", "D2D4D2"


def B(p, size, pos, col, **o):
	p.append(("box", size, pos, col, o))


def C(p, size, pos, col, **o):
	o.setdefault("seg", 8)
	p.append(("cyl", size, pos, col, o))


def lit(*a):
	"""Deterministic 0..9 for a window, so the same facade always shows the same lit rooms."""
	h = 0
	for v in a:
		h = (h * 131 + int(v * 7) + 17) % 9973
	return (h * 2654435761 >> 7) % 10


def window(p, x, y, zf, w, h, on, frame=FRAME, sill=TILE3, mullion=True, panes=2):
	"""A framed window on a facade whose front face is at zf (road side is -Z): frame, glass, sill, and mullions splitting
	it into `panes` panes."""
	B(p, (w + 0.8, h + 0.8, 0.4), (x, y, zf - 0.1), frame)
	B(p, (w, h, 0.3), (x, y, zf - 0.3), on or DARK, emit=1.6 if on else 0)
	B(p, (w + 1.2, 0.4, 1.0), (x, y - h / 2 - 0.6, zf - 0.5), sill)
	if mullion:
		for i in range(1, panes):
			B(p, (0.3, h, 0.2), (x - w / 2 + i * w / panes, y, zf - 0.5), frame)


def side_window(p, xs, z, y, w, h, on, frame=FRAME):
	"""A framed window on a side elevation whose face is at x = xs (sign of xs says which side)."""
	s = 1 if xs > 0 else -1
	B(p, (0.4, h + 0.8, w + 0.8), (xs + s * 0.1, y, z), frame)
	B(p, (0.3, h, w), (xs + s * 0.3, y, z), on or DARK, emit=1.6 if on else 0)
	B(p, (1.0, 0.4, w + 1.2), (xs + s * 0.5, y - h / 2 - 0.6, z), TILE3)


def ac_unit(p, x, y, z, face=-1):
	"""An outdoor air-conditioner unit: casing and a dark fan disk on the -Z (face -1) or +Z (face 1) side."""
	B(p, (2.8, 2.0, 1.2), (x, y, z), "E6E6E2")
	C(p, (1.5, 0.2, 1.5), (x - 0.4, y, z + face * 0.65), "50545A", rot=(90, 0, 0))


def vending_pair(p, x0, z0, n=2, face=-1):
	"""n vending machines side by side against a wall, front toward face (-Z or +Z), after vending_night.jpg: red or white
	bodies; an upper lit window with 3 horizontal shelves of small bottles over pale price strips; a poster panel in the
	middle of the body beside a dark coin unit; the dispenser slot; a red recycling bin with a domed lid at the end."""
	f = face
	for i in range(n):
		x = x0 + i * 3.8
		body = ("C8282A", "F2F2F0", "C8282A", "E8E8E6")[i % 4]
		B(p, (3.6, 7, 3), (x, 3.5, z0), body)
		B(p, (3.0, 3.2, 0.2), (x, 5.0, z0 + f * 1.55), "F8FCFF", emit=2.6)  # lit window
		for r in range(3):
			y = 3.75 + r * 1.05
			B(p, (2.9, 0.18, 0.3), (x, y - 0.05, z0 + f * 1.65), "B8D0F0", emit=1.2)  # price strip
			for c in range(6):
				col = ("3A8A4A", "E8E4D8", "C83A30", "D8A040", "4A6AB0", "F0F0EC")[(i * 2 + r + c) % 6]
				B(p, (0.34, 0.75, 0.3), (x - 1.15 + c * 0.46, y + 0.45, z0 + f * 1.7), col)
		B(p, (1.7, 1.4, 0.15), (x - 0.55, 2.45, z0 + f * 1.56), ("D8C8A0", "6A8AB0", "E0B070")[i % 3], emit=0.5)  # poster
		B(p, (0.9, 1.4, 0.3), (x + 1.05, 2.45, z0 + f * 1.6), "1E2024")  # dark coin unit
		B(p, (0.3, 0.2, 0.1), (x + 1.05, 2.8, z0 + f * 1.76), "60E070", emit=1.5)
		B(p, (2.6, 0.9, 0.3), (x - 0.2, 0.8, z0 + f * 1.5), "15161A")  # dispenser slot
	bx = x0 + n * 3.8 - 0.6
	B(p, (1.8, 2.8, 1.8), (bx, 1.4, z0), "C02A26")  # red recycling bin
	p.append(("ball", (1.9, 1.0, 1.9), (bx, 2.8, z0), "C02A26", {"subdiv": 1}))
	C(p, (0.8, 0.2, 0.8), (bx, 2.2, z0 + f * 0.92), "2A1A1A", rot=(90, 0, 0))  # bottle slot


def mansion():
	"""The partners' apartment: 7-storey tiled mansion block. -Z face: balconies with sliding doors, AC units, laundry.
	+Z face: the open corridor with a parapet and rail, a row of steel doors, meter boxes and ceiling lights. Sides: window
	grids, tile bands, drainpipes, AC units. Stair core with lit slits, roof tank, lift room."""
	W, D, fh, n = 60, 26, 9, 7
	H = n * fh + 1
	zf, zb = -D / 2, D / 2
	p = []
	B(p, (W, H, D), (0, H / 2, 0), MANSION_WALL)
	B(p, (W + 1, 1.5, D + 1), (0, H + 0.75, 0), TILE2)
	for f in range(1, n + 1):
		B(p, (W + 0.4, 0.5, D + 0.4), (0, f * fh - 0.3, 0), TILE2)  # tile band at every floor
	# Ground floor: lit lobby, canopy, mailbox wall, bike rack
	B(p, (12, 7, 0.3), (0, 3.5, zf - 0.2), COOL, emit=2.2)
	B(p, (16, 0.8, 6), (0, 8, zf - 3), TILE3)
	B(p, (10, 4, 0.6), (-16, 3, zf - 0.3), "9A9488")
	for i in range(5):
		C(p, (0.3, 2.4, 0.3), (14 + i * 2.2, 1.2, zf - 2), STEEL, seg=6)
	unit = (W - 6) / 4
	for f in range(1, n):
		y0 = f * fh
		# Balcony face
		B(p, (W - 4, 0.8, 5), (0, y0 + 0.4, zf - 2.5), TILE3)
		B(p, (W - 4, 3.4, 0.5), (0, y0 + 2.5, zf - 4.75), "EDEAE2")
		B(p, (W - 4, 0.4, 0.8), (0, y0 + 4.4, zf - 4.75), STEEL)
		for u in range(5):
			B(p, (0.5, fh - 1, 5), (-(W - 6) / 2 + u * unit, y0 + fh / 2, zf - 2.5), TILE2)
		for u in range(4):
			x = -(W - 6) / 2 + unit * (u + 0.5)
			r = lit(f, u)
			on = (WARM, "FFE6C0", TV)[r % 3] if r < 6 else None
			window(p, x - 1.5, y0 + 4.3, zf, 7.5, 6.4, on, frame="E8E8E4", panes=4)  # white frame, 4 panes
			ac_unit(p, x + 4.2, y0 + 6.2, zf - 0.8)  # one per unit, hung on the wall above the balcony wall
			if r % 4 != 1:
				B(p, (9, 0.25, 0.25), (x - 1, y0 + 7.4, zf - 3.6), STEEL)
				B(p, (2.2, 2.6, 0.2), (x - 3, y0 + 6, zf - 3.6), ("E8E2D2", "6A8AC0", "C05A5A", "E0C070")[(u + f) % 4])
		# Corridor face: walkway slab, concrete parapet, rail, steel doors with meter boxes, small lit windows, lights
		B(p, (W - 2, 0.8, 4), (0, y0 + 0.4, zb + 2), TILE3)
		B(p, (W - 2, 3.2, 0.6), (0, y0 + 2.4, zb + 3.8), "E2DED4")
		B(p, (W - 2, 0.35, 0.5), (0, y0 + 4.4, zb + 3.8), STEEL)
		for u in range(5):
			x = -24 + u * 12
			B(p, (3.4, 6.8, 0.4), (x, y0 + 4.2, zb + 0.3), ("5E6A74", "6E5A4E")[f % 2])
			B(p, (0.5, 0.5, 0.5), (x + 1.2, y0 + 4.0, zb + 0.6), "C8C8C0", metal=1, rough=0.3)
			B(p, (1.6, 2, 0.6), (x + 3.2, y0 + 5.6, zb + 0.4), "9AA0A6")
			B(p, (2.6, 1.8, 0.3), (x + 6.6, y0 + 5.8, zb + 0.3), "F4E6C8" if lit(f, u, 7) < 6 else DARK, emit=1.4 if lit(f, u, 7) < 6 else 0)
			B(p, (1.0, 0.3, 1.0), (x + 4.5, y0 + fh - 0.6, zb + 2), "FFF4E0", emit=4)
	# Side elevations: two windows per floor each side, AC units, drainpipes
	for xs in (-W / 2, W / 2):
		for f in range(1, n):
			for z in (-6, 6):
				side_window(p, xs, z, f * fh + 4.5, 4.5, 4.5, (WARM, None, TV, None, "FFE6C0")[lit(f, z, xs) % 5])
			if f % 2:
				B(p, (1.2, 2.0, 2.8), (xs + (1 if xs > 0 else -1) * 0.8, f * fh + 1.6, 0), "E6E6E2")
		C(p, (0.7, H, 0.7), (xs + (0.5 if xs > 0 else -0.5), H / 2, 11), "A8A296", seg=6)
	# Stair core on the right end with lit slits both ways
	B(p, (9, H + 7, 12), (W / 2 + 4.5, (H + 7) / 2, -2), TILE2)
	for f in range(n):
		B(p, (2.2, 5.5, 0.3), (W / 2 + 4.5, f * fh + 4.5, -8.1), COOL, emit=1.6)
		B(p, (2.2, 5.5, 0.3), (W / 2 + 4.5, f * fh + 4.5, 4.1), COOL, emit=1.6)
	for x in (-W / 2 + 0.8, W / 2 - 0.8):
		C(p, (0.7, H, 0.7), (x, H / 2, zf - 0.5), "B8B2A4", seg=6)
	# Fence round the roof edge: posts every 4 studs and two rails
	for y in (H + 3.0, H + 5.2):
		B(p, (W, 0.3, 0.3), (0, y, zf + 0.4), STEEL)
		B(p, (W, 0.3, 0.3), (0, y, zb - 0.4), STEEL)
		for xs in (-W / 2 + 0.4, W / 2 - 0.4):
			B(p, (0.3, 0.3, D), (xs, y, 0), STEEL)
	for x in range(-28, 29, 4):
		for z in (zf + 0.4, zb - 0.4):
			B(p, (0.25, 4, 0.25), (x, H + 3.5, z), STEEL)
	for z in range(-10, 11, 4):
		for xs in (-W / 2 + 0.4, W / 2 - 0.4):
			B(p, (0.25, 4, 0.25), (xs, H + 3.5, z), STEEL)
	B(p, (10, 6, 10), (-14, H + 3, 4), TILE2)
	for dx in (-2, 2):
		for dz in (-2, 2):
			B(p, (0.5, 4, 0.5), (14 + dx, H + 2, 4 + dz), STEEL)
	C(p, (7, 6, 7), (14, H + 7, 4), "A8B0B8", seg=12)
	C(p, (0.4, 12, 0.4), (-20, H + 6, 8), STEEL, seg=6)
	return p


def apaato():
	"""2-storey wooden apartment: siding, open steel corridor and railing to the street, outside stair, tin roof, side
	windows, and a cluster of three vending machines with a bin at its end."""
	W, D, fh = 40, 16, 9
	zf = -D / 2
	p = []
	B(p, (W, fh * 2, D), (0, fh, 0), APA_WALL)
	for x in range(-18, 20, 4):
		B(p, (0.3, fh * 2, 0.2), (x, fh, zf - 0.1), SIDING2)
	for f in range(2):
		y0 = f * fh
		for i in range(4):
			x = -15 + i * 10
			B(p, (3.2, 6.6, 0.4), (x, y0 + 3.6, zf - 0.3), "6E7C86")
			window(p, x + 4.5, y0 + 5, zf, 3, 2.4, "F4E6C8" if lit(f, i) < 6 else None, frame="9A9A98", sill=STEEL, mullion=False)
			B(p, (1.6, 2, 0.8), (x - 3, y0 + 5.6, zf - 0.5), "9AA0A6")
			if f == 1 and i < 3:
				B(p, (2.4, 3, 2.0), (x + 4.5, y0 + 2.3, zf - 1.2), "ECECEC")  # washing machine by the door
		for xs in (-W / 2, W / 2):
			side_window(p, xs, 2, y0 + 5, 4, 3, "F4E6C8" if lit(f, xs) < 5 else None, frame="9A9A98")
	B(p, (W + 2, 0.8, 4), (0, fh + 0.4, zf - 2), STEEL2)
	B(p, (W + 2, 0.4, 0.4), (0, fh + 4.2, zf - 3.8), STEEL2)
	B(p, (W + 2, 0.3, 0.3), (0, fh + 1.2, zf - 3.8), STEEL2)
	for x in range(-20, 21, 2):
		B(p, (0.2, 3, 0.2), (x, fh + 2.7, zf - 3.8), STEEL2)
	for x in (-20, 0, 20):
		B(p, (0.6, fh, 0.6), (x, fh / 2, zf - 3.7), STEEL2)
	for s in range(9):
		B(p, (3, 0.3, 1.2), (W / 2 + 2.5, 1 + s, zf - 11 + s * 1.1), STEEL)
	for x in (W / 2 + 1, W / 2 + 4):
		B(p, (0.3, 1.2, 13), (x, fh / 2 + 0.5, zf - 6.5), STEEL2, rot=(-38, 0, 0))
	B(p, (W + 3, 0.6, D / 2 + 2.5), (0, fh * 2 + 1.2, -D / 4 - 0.8), "4A5A6A", rot=(-12, 0, 0))
	B(p, (W + 3, 0.6, D / 2 + 2.5), (0, fh * 2 + 1.2, D / 4 + 0.8), "4A5A6A", rot=(12, 0, 0))
	B(p, (W + 3, 0.5, 0.6), (0, fh * 2, zf - 2.4), "5A6066")
	C(p, (0.5, fh * 2, 0.5), (-W / 2 - 1, fh, zf - 2.4), "5A6066", seg=6)
	vending_pair(p, -W / 2 + 2, zf - 2.5, n=3)
	# Kei car parked along the front
	B(p, (10, 2.2, 4.8), (2, 1.9, zf - 8), "E8E8E2")
	B(p, (6.5, 2.6, 4.4), (1.4, 4.2, zf - 8), "1E2430")
	B(p, (6.0, 0.3, 4.2), (1.4, 5.6, zf - 8), "E8E8E2")
	for x in (-1.6, 5.6):
		for z in (-2.3, 2.3):
			C(p, (1.8, 0.6, 1.8), (x, 0.9, zf - 8 + z), "15161A", seg=8, rot=(90, 0, 0))
	B(p, (0.2, 0.6, 1.0), (-3.05, 2.2, zf - 9.6), "FFF6D8", emit=2)
	B(p, (0.2, 0.6, 1.0), (-3.05, 2.2, zf - 6.4), "FFF6D8", emit=2)
	return p


def corner_signs(p, x, zf, top, n, k0):
	"""A narrow vertical sign stack on a building corner: dark frame, small lit panels with glyph blocks."""
	B(p, (0.8, n * 3.2 + 1, 2.8), (x, top - n * 1.6, zf - 1.8), "15151C")
	for y in (top - 0.6, top - n * 3.2 + 0.4):
		B(p, (0.5, 0.5, 1.0), (x, y, zf - 0.4), STEEL)  # brackets back to the wall
	for j in range(n):
		y = top - 1.6 - j * 3.2
		B(p, (1.0, 2.6, 2.2), (x, y, zf - 1.8), SIGNS[(j + k0) % 6], emit=0.9)
		B(p, (1.2, 0.9, 0.9), (x, y + (j % 2 - 0.5) * 0.6, zf - 1.8), "3A3430")  # dark glyph block


def shophouse():
	"""Narrow 4-storey shophouse: lit shop with half-open shutter, awning, sign band, windows with AC units on front and
	sides, narrow stacked signs on both corners, a vending pair at the side, drainpipe, roof tank."""
	W, D = 20, 18
	zf = -D / 2
	p = []
	H = 10 + 3 * 8.5
	B(p, (W, H, D), (0, H / 2, 0), SHOP_WALL)
	B(p, (W - 2, 7, 0.3), (0, 3.5, zf - 0.1), "FFF0D0", emit=2.2)
	for y in range(5, 10):
		B(p, (W - 2, 0.7, 0.4), (0, y + 0.5, zf - 0.3), "8A8E94", metal=0.6, rough=0.5)
	for i, x in enumerate((-5, 0, 5)):
		B(p, (2.5, 3, 2), (x, 1.5, zf - 1), ("C05040", "D0A040", "50809A")[i])
	B(p, (W + 1, 0.6, 4.5), (0, 8.2, zf - 2.2), ("B8322E", "3A6A50")[0], rot=(-14, 0, 0))
	B(p, (W, 2.2, 0.4), (0, 10.6, zf - 0.3), "1A1A22")
	for i, x in enumerate((-6, -1.5, 3)):
		B(p, (3, 1.4, 0.2), (x, 10.6, zf - 0.55), SIGNS[i * 2 % 6], emit=1.1)
	for f in range(3):
		y0 = 12 + f * 8.5
		for x in (-5, 5):
			window(p, x, y0 + 3.8, zf, 5, 4.4, (WARM, TV, None, "FFE6C0")[lit(f, x) % 4])
		ac_unit(p, 0, y0 + 1.6, zf - 1.0)
		B(p, (W + 0.4, 0.4, D + 0.4), (0, y0, 0), "9A9488")
		for xs in (-W / 2, W / 2):
			side_window(p, xs, -2, y0 + 3.8, 4, 4, (WARM, None, TV)[lit(f, xs) % 3])
	for bx in (-7.5, -4.5):  # parked bicycles
		for wx in (-1.4, 1.4):
			C(p, (2.2, 0.2, 2.2), (bx + wx * 0, 1.1, zf - 2.2 + wx), "1A1A1A", seg=10, rot=(0, 0, 90))
		B(p, (0.25, 0.25, 2.8), (bx, 1.9, zf - 2.2), "8A2A2A")
		B(p, (0.25, 1.4, 0.25), (bx, 2.4, zf - 1.2), "8A8A8A")
	for px in (6.5, 8.5):  # potted plants
		C(p, (1.4, 1.2, 1.4), (px, 0.6, zf - 1.2), "8A5A3A", seg=8)
		p.append(("ball", (1.8, 1.8, 1.8), (px, 1.9, zf - 1.2), "3E6A40", {"subdiv": 1}))
	C(p, (0.6, H, 0.6), (-W / 2 + 1.8, H / 2, zf - 0.4), "8A8478", seg=6)  # front drainpipe
	corner_signs(p, -W / 2 + 0.6, zf, H - 2, 6, 1)
	corner_signs(p, W / 2 - 0.6, zf, H - 6, 4, 4)
	C(p, (0.6, H, 0.6), (W / 2 - 0.6, H / 2, D / 2 - 0.6), "8A8478", seg=6)
	vending_pair(p, W / 2 + 2.2, zf + 2, n=2)
	B(p, (W + 0.6, 1, D + 0.6), (0, H + 0.5, 0), "9A9488")
	B(p, (4, 3, 4), (5, H + 3, 3), "A8B0B8")
	C(p, (0.3, 8, 0.3), (-6, H + 4, 5), STEEL, seg=6)
	return p


def konbini():
	"""Convenience store: white box, two colour bands (not a real chain's colours), glazed front over a lit interior with
	shelf rows, auto door, roof condensers, bins, a vending pair and a lit pole sign."""
	W, D, H = 34, 22, 12
	zf = -D / 2
	p = []
	B(p, (W, H, D), (0, H / 2, 0), "ECECEA")
	B(p, (W - 2, 8, 0.4), (0, 4.4, zf - 0.1), "F6F4EC", emit=1.8)
	for r in range(3):
		for s in range(6):
			B(p, (4, 1.0, 0.4), (-12.5 + s * 5, 1.8 + r * 2.0, zf - 0.4), ("D8584A", "4A9AD8", "E8C040", "5AB870")[(r + s) % 4])
	for x in range(-16, 17, 4):
		B(p, (0.4, 8.4, 0.5), (x, 4.6, zf - 0.7), "9AA2AA", metal=0.5)
	B(p, (W, 0.5, 0.5), (0, 8.8, zf - 0.7), "9AA2AA", metal=0.5)
	B(p, (6, 7.6, 0.3), (0, 4.2, zf - 0.9), "C8E8FF", emit=1.0, alpha=0.6)
	B(p, (W + 0.6, 1.4, 0.5), (0, 10.0, zf - 0.3), "D89A48", emit=0.7)  # muted amber and teal bands (no real chain's)
	B(p, (W + 0.6, 0.8, 0.5), (0, 11.0, zf - 0.3), "6A9A92", emit=0.7)
	B(p, (W + 0.6, 0.6, D + 0.6), (0, H + 0.3, 0), "C8C8C6")
	for x in (-10, -3, 4):
		B(p, (5, 3, 4), (x, H + 2, 4), "D8D8D4")
		C(p, (2.4, 0.2, 2.4), (x, H + 3.6, 4), "50545A")
	vending_pair(p, -W / 2 - 4.2, zf + 2, n=2)
	for xs in (-W / 2, W / 2):  # side elevations: frosted strip windows, staff door, poster panel, AC unit, drainpipe
		s = 1 if xs > 0 else -1
		for z in (-4, 2):
			side_window(p, xs, z, 8.6, 4.4, 2.0, "E8F0F0", frame="9AA2AA")
		B(p, (0.4, 7, 3.6), (xs + s * 0.2, 3.5, 7), "8A9096")
		B(p, (0.3, 4, 2.8), (xs + s * 0.3, 4.4, -8), "E8D8B0", emit=0.6)
		B(p, (1.2, 2.0, 2.8), (xs + s * 0.8, 1.0, 1), "E6E6E2")
		C(p, (0.6, H, 0.6), (xs + s * 0.4, H / 2, D / 2 - 0.6), "8A8478", seg=6)
		B(p, (0.3, 1.0, D), (xs + s * 0.25, 10.5, 0), "D89A48", emit=0.4)
	C(p, (0.8, 18, 0.8), (W / 2 + 3, 9, zf - 1), STEEL, seg=6)
	B(p, (6, 4, 1.2), (W / 2 + 3, 18, zf - 1), "F0ECE0", emit=1.2)
	B(p, (6.2, 1.2, 1.3), (W / 2 + 3, 19, zf - 1), "D89A48", emit=1.2)
	return p


def hq():
	"""The hunters' headquarters, after the Kasumigaseki government blocks: a wide, low pale-grey block (about 2:1 width
	to height above its podium) of 10 deep projecting slab bands over recessed dark ribbon windows, pale piers between
	bays, sparse warm-lit offices, on a 2-storey podium with a lit lobby band. A lit forecourt, a low penthouse, and a large
	changed emblem (ring and diamond, not the real mark) on the roof edge."""
	p = []
	W, D, fh, n, base = 170, 70, 8, 10, 18
	B(p, (W + 16, base, D + 16), (0, base / 2, 0), "8E908E")  # podium
	B(p, (W + 16.4, 5, D + 16.4), (0, 6, 0), "302C28")
	for x in range(-88, 90, 8):
		B(p, (6.6, 4.2, 0.3), (x, 6, -D / 2 - 8.3), WARM if lit(x, 1) < 6 else "E8ECF0", emit=0.9)  # lobby band
	B(p, (W + 20, 1.6, D + 20), (0, base + 0.8, 0), "C4C6C4")
	for f in range(n):
		y0 = base + 1.6 + f * fh
		B(p, (W + 14, 2.4, D + 14), (0, y0 + 1.2, 0), "DCD6C8", emit=0.25)  # deep pale-beige slab band, 7 studs out
		B(p, (W - 1, fh - 2.4, D - 1), (0, y0 + 2.4 + (fh - 2.4) / 2, 0), "34404E")  # recessed ribbon glazing
		for s_ in range(int(W / 10)):
			if lit(f, s_) < 2:
				B(p, (8, 4.2, 0.2), (-W / 2 + 5 + s_ * 10, y0 + 4.8, -D / 2 + 0.4), (WARM, "F2E6D0")[s_ % 2], emit=1.0)
		for s_ in range(int(D / 10)):
			if lit(s_, f, 3) < 2:
				for xs in (-W / 2 + 0.4, W / 2 - 0.4):
					B(p, (0.2, 4.2, 8), (xs, y0 + 4.8, -D / 2 + 5 + s_ * 10), WARM, emit=0.9)
	top = base + 1.6 + n * fh
	for x in range(-80, 85, 10):  # pale piers between bays on the street face
		B(p, (1.4, n * fh, 1.2), (x, base + 1.6 + n * fh / 2, -D / 2 - 0.4), "B0B2B0")
	for z in range(-30, 35, 10):
		for xs in (-W / 2 - 0.4, W / 2 + 0.4):
			B(p, (1.2, n * fh, 1.4), (xs, base + 1.6 + n * fh / 2, z), "B0B2B0")
	# Two mullions in every bay between the piers: narrow-paned ribbon windows (gov_building4.jpg)
	ym = base + 1.6 + n * fh / 2
	for b in range(-85, 85, 10):
		for m in (10 / 3, 20 / 3):
			B(p, (0.5, n * fh, 0.6), (b + m, ym, -D / 2 - 0.1), "A8A49A")
	for b in range(-35, 35, 10):
		for m in (10 / 3, 20 / 3):
			for xs in (-W / 2 - 0.1, W / 2 + 0.1):
				B(p, (0.6, n * fh, 0.5), (xs, ym, b + m), "A8A49A")
	B(p, (W + 10, 2.4, D + 10), (0, top + 1.2, 0), "D0D2D0", emit=0.15)
	B(p, (60, 8, 30), (20, top + 6, 10), "9A9C9A")  # penthouse and roof plant
	for x in (-30, -18, -6):
		B(p, (8, 4, 8), (x, top + 4.4, 14), "8A8E90")
	# Emblem on the street-side roof edge
	B(p, (2, 12, 2), (-12, top + 7, -D / 2 + 2), STEEL2)
	B(p, (2, 12, 2), (12, top + 7, -D / 2 + 2), STEEL2)
	C(p, (28, 1.2, 28), (0, top + 16, -D / 2 + 0.5), "E8E0C8", seg=24, rot=(90, 0, 0), emit=1.4)
	C(p, (22, 1.4, 22), (0, top + 16, -D / 2 + 0.4), "2A2420", seg=24, rot=(90, 0, 0))
	B(p, (10, 10, 0.8), (0, top + 16, -D / 2 - 0.5), "C83A2A", rot=(0, 0, 45), emit=1.6)
	C(p, (1, 24, 1), (60, top + 12, 14), STEEL, seg=6)
	p.append(("ball", (2.2, 2.2, 2.2), (60, top + 25, 14), "FF2B2B", {"emit": 8}))
	# Lit forecourt
	fz = -D / 2 - 8 - 20
	B(p, (130, 0.4, 40), (0, 0.2, fz), "8A8A86")
	for x in range(-56, 60, 14):
		B(p, (7, 0.2, 1.4), (x, 0.5, fz), "FFE0B0", emit=1.6)
		C(p, (0.6, 2.6, 0.6), (x, 1.5, fz - 18), "DADAD0", seg=6, emit=1.0)
	# Hedge planters along the base and a row of tall conifers in front of them, both sides of the entrance
	for s in (-1, 1):
		for x in (40, 72):
			B(p, (28, 2.4, 4.4), (s * x, 1.2, -D / 2 - 11), "9A968C")
			B(p, (27, 2.8, 3.6), (s * x, 3.6, -D / 2 - 11), "3A5A36")
		for x in range(36, 90, 9):
			C(p, (0.9, 4, 0.9), (s * x, 2, -D / 2 - 16), "4A3A2A", seg=6)
			p.append(("cone", (7, 20, 7), (s * x, 14, -D / 2 - 16), "2C4A30", {"seg": 8, "taper": 0.0}))
	for x in (-6, 0, 6):
		C(p, (0.5, 24, 0.5), (x, 12, fz + 12), "C8C8C8", seg=6)
	B(p, (60, 1.4, 14), (0, 14, -D / 2 - 14), "C4C6C4")
	return p


def office():
	"""Distant office tower for the skyline: banded floors, vertical mullions, random lit windows, roof crown, beacon."""
	W, H = 44, 150
	p = []
	B(p, (W, H, W), (0, H / 2, 0), "1E2434")
	for b in range(1, int(H / 6)):
		B(p, (W + 0.5, 0.6, W + 0.5), (0, b * 6, 0), "4A5060")
	for x in range(-20, 21, 5):
		B(p, (0.4, H, 0.4), (x, H / 2, -W / 2 - 0.2), "3A4050")
		B(p, (0.4, H, 0.4), (-W / 2 - 0.2, H / 2, x), "3A4050")
	for b in range(1, int(H / 6)):
		for s in range(8):
			if lit(b, s, 3) < 3:
				B(p, (4.2, 3.6, 0.2), (-17.5 + s * 5, b * 6 + 2.6, -W / 2 - 0.15), ("9FC8FF", WARM, "E8F0FF")[s % 3], emit=1.5)
			if lit(s, b, 5) < 2:
				B(p, (0.2, 3.6, 4.2), (-W / 2 - 0.15, b * 6 + 2.6, -17.5 + s * 5), ("9FC8FF", WARM)[s % 2], emit=1.5)
	B(p, (W - 8, 10, W - 8), (0, H + 5, 0), "2A3040")
	p.append(("ball", (2.4, 2.4, 2.4), (0, H + 11, 0), "FF2B2B", {"emit": 10}))
	for dx in (-1, 1):  # red aircraft-warning beacons on the roof corners (tokyo_night_skyline.jpg)
		for dz in (-1, 1):
			B(p, (2.2, 2.2, 2.2), (dx * (W / 2 - 1.5), H + 1.2, dz * (W / 2 - 1.5)), "FF2B2B", emit=10)
	return p


def wire(p, x0, y0, z0, x1, y1, z1, r, sag, n=4, t0=0.0, t1=1.0):
	"""A drooping cable on the span (x0,y0,z0)-(x1,y1,z1), dipping `sag` studs at mid-span (a parabola, close to a
	catenary at this sag), drawn from span fraction t0 to t1 as n thin straight pieces."""

	def at(t):
		return (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t - sag * 4 * t * (1 - t), z0 + (z1 - z0) * t)

	for k in range(n):
		a, b = at(t0 + (t1 - t0) * k / n), at(t0 + (t1 - t0) * (k + 1) / n)
		dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
		ln = math.sqrt(dx * dx + dy * dy + dz * dz)
		rx = math.degrees(math.acos(max(-1.0, min(1.0, dy / ln))))
		ry = math.degrees(math.atan2(dx, dz))
		p.append(("cyl", (r, ln + r, r), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), "101114", {"seg": 3, "rot": (rx, ry, 0)}))


def street_kit():
	"""48 studs of narrow-street edge, placed with its road side (-Z) toward the road at 35 studs from the centre line:
	dark pavement on a raised kerb, white guardrail, a curved-arm sodium lamp with its warm pool, and two concrete utility
	poles crowded with crossarms and insulators (a finned transformer box on the second), 7 thin drooping power wires and
	a loose telecom bundle per span. The wires crossing the street are the separate CrossWire prop."""
	p = []
	B(p, (48.2, 0.6, 10), (0, 0.3, -1), PAVE)
	B(p, (48.2, 0.9, 0.8), (0, 0.45, -6), CURB)
	B(p, (48.2, 0.1, 1.0), (0, 0.65, 0.5), "B89A30")  # tactile strip
	for y in (2.0, 2.8):
		B(p, (48, 0.35, 0.3), (0, y, -5.2), "EDEDE8")
	for x in range(-22, 24, 6):
		B(p, (0.35, 2.4, 0.35), (x, 1.8, -5.2), "EDEDE8")
	# Lamp and its pool (head ends 28.2 studs from the centre line on a straight, 24+ inside bends: kit at 35, head edge at local z -6.8)
	C(p, (0.7, 17, 0.7), (0, 8.5, 0.5), "5E6E66")
	B(p, (0.5, 3, 0.5), (0, 17.5, -0.4), "5E6E66", rot=(-35, 0, 0))
	B(p, (0.5, 0.5, 3.6), (0, 18.8, -3.1), "5E6E66")
	B(p, (1.4, 0.7, 2.6), (0, 18.5, -5.5), "4A5A52")
	B(p, (1.1, 0.2, 2.2), (0, 18.1, -5.5), SODIUM, emit=10)
	C(p, (16, 0.05, 10), (0, 0.66, -1), SODIUM, seg=16, emit=0.6, alpha=0.35)
	# Two poles at x = -12 and +12 (utility_poles_takadanobaba.jpg): 4 crossarms with insulators, banding, step bolts, a
	# riser cable and a cable coil; the second carries a grey finned transformer box with bushings on top
	H = 36
	arms = ((34, 11, (-3.5, 0, 3.5)), (31.5, 9, (-3, 3)), (29, 9, (-3, 3)), (26.5, 7, (-2.5, 2.5)))
	for px, tbox in ((-12, False), (12, True)):
		C(p, (1.5, H, 1.5), (px, H / 2, 1), "9A988E", taper=0.65)
		C(p, (1.7, 2.4, 1.7), (px, 1.2, 1), "E8C030")
		C(p, (1.72, 0.6, 1.72), (px, 1.6, 1), "1A1A1A")
		for y in (7, 13, 18.5):
			C(p, (1.55, 0.35, 1.55), (px, y, 1), "D0D0C8", seg=6)  # banding
		for i in range(6):
			B(p, (0.2, 0.2, 1.4), (px, 8 + i * 3, 1 + (i % 2 - 0.5) * 1.4), STEEL)  # step bolts
		for y, w, ins in arms:
			B(p, (0.5, 0.5, w), (px, y, 1), STEEL)  # crossarm across the street direction
			for zz in ins:
				C(p, (0.45, 0.9, 0.45), (px, y + 0.7, 1 + zz), "D8D8D0", seg=6)
		if tbox:
			B(p, (2.6, 4.2, 2.2), (px, 22.5, -1.0), "8A9096")
			for i in range(4):
				B(p, (0.25, 3.6, 0.5), (px - 1.05 + i * 0.7, 22.5, -2.3), "7A8086")  # fins
			B(p, (2.9, 0.4, 2.5), (px, 24.8, -1.0), "6A7076")
			for i in range(3):
				C(p, (0.4, 0.9, 0.4), (px - 0.8 + i * 0.8, 25.4, -1.0), "D8D8D0", seg=6)  # bushings
			B(p, (0.5, 0.5, 2.4), (px, 23.5, 0.1), STEEL)
		C(p, (0.4, 22, 0.4), (px + 0.6, 21, 1.8), "1A1B1E", seg=6)  # riser cable
		C(p, (2.4, 0.3, 2.4), (px + 0.9, 17, 2.0), "1A1B1E", seg=8, rot=(0, 0, 90))  # cable coil
		B(p, (0.5, 0.5, 2.2), (px, 21.6, 1.8), STEEL)  # telecom bracket
	# Wires along the street, each drooping between the poles (24-stud spans, sag 3) and drawn as 4 pieces pole to pole and
	# 2 pieces for each half span out to the kit ends (the low point of the neighbour spans): 7 thin power wires from the
	# insulators and a loose telecom bundle of 3 lower down that droops more
	lines = [(y + 0.9, zz, 0.22, 3.0) for y, w, ins in arms[:3] for zz in ins]
	lines += [(21.6, 1.8 + dz, 0.3, 4.5) for dz in (-0.35, 0.0, 0.35)]
	for y, zz, r, sag in lines:
		z = 1 + zz
		wire(p, -12, y, z, 12, y, z, r, sag)
		wire(p, -36, y, z, -12, y, z, r, sag, n=2, t0=0.5)
		wire(p, 12, y, z, 36, y, z, r, sag, n=2, t1=0.5)
	# Orange curve mirror on its own post at the kerb
	C(p, (0.5, 10, 0.5), (-20, 5, -4.4), "E07020", seg=6)
	C(p, (3.6, 0.5, 3.6), (-20, 10.5, -5.0), "E07020", seg=14, rot=(90, 0, 0))
	C(p, (3.0, 0.3, 3.0), (-20, 10.5, -5.3), "C8D0D8", seg=14, rot=(90, 0, 0), metal=0.8, rough=0.15)
	return p


def cross_wire():
	"""Three wires crossing high over the street from a pole on one side (local x 12, z 1) to the far side 70 studs toward
	-Z; sag 7, so the lowest point is 20.5 studs up (road top at 1). Its own prop so the clearance check can exempt it."""
	p = []
	for y, dz in ((33, -2), (30, 0), (27.5, 2)):
		wire(p, 12, y, 1 + dz, 12, y, -69 + dz, 0.22, 7.0, n=6)
	return p


def low_block():
	"""An infield back-street block, 100 x 100: coin parking with stall lines, two parked cars, a pay machine, a small
	2-storey house with a hipped tile roof, a pocket park with trees and a bench, low walls, a lamp with its pool."""
	p = []
	B(p, (100, 0.3, 100), (0, 0.15, 0), "3E4046")
	B(p, (46, 0.2, 44), (-24, 0.35, -24), "2A2C30")  # parking
	for i in range(5):
		B(p, (0.5, 0.1, 14), (-44 + i * 9, 0.5, -36), "DADAD0")
	for x, c in ((-39.5, "E8E8E6"), (-21.5, "2A4A7A")):
		B(p, (6.2, 2.0, 12), (x, 1.8, -34), c)
		B(p, (5.6, 2.0, 6.5), (x, 3.8, -33), "1E2430")
		for zz in (-38, -30):
			C(p, (2.0, 6.6, 2.0), (x, 1.1, zz), "15161A", rot=(0, 0, 90), seg=8)
	B(p, (1.6, 4, 1.2), (-4, 2, -44), "E8C030")
	B(p, (1.2, 1.6, 0.2), (-4, 3, -44.7), "F4FAFF", emit=2)
	# House with hipped roof
	B(p, (28, 16, 22), (26, 8, -26), "C8BCA8")
	B(p, (30, 0.8, 24), (26, 16.4, -26), "4A3A32")
	B(p, (22, 5, 16), (26, 19.2, -26), "5A4038")
	for xw in (19, 26, 33):
		for yw in (4.5, 11.5):
			window(p, xw, yw, -37, 3.6, 3.6, (WARM, None, TV)[lit(xw, yw) % 3], frame="7A6A58")
	ac_unit(p, 14, 2, -37.8)
	# Pocket park
	B(p, (44, 0.4, 40), (-24, 0.4, 26), "2F4A30")
	for x, z in ((-36, 16), (-14, 34), (-30, 38)):
		C(p, (1.2, 8, 1.2), (x, 4, z), "4A3A2A", seg=6)
		p.append(("ball", (9, 8, 9), (x, 10, z), "2E5A38", {"subdiv": 1}))
	B(p, (6, 1, 2), (-20, 1.2, 18), "6A5040")
	# Low walls and a lamp
	B(p, (100, 2.4, 0.8), (0, 1.2, 49.6), "8A8A84")
	B(p, (0.8, 2.4, 100), (49.6, 1.2, 0), "8A8A84")
	C(p, (0.6, 14, 0.6), (4, 7, 6), "5E6E66", seg=6)
	B(p, (1.4, 0.6, 2), (4, 14, 4.8), SODIUM, emit=8)
	C(p, (14, 0.05, 14), (4, 0.6, 4), SODIUM, seg=16, emit=0.5, alpha=0.3)
	# A row of small back houses along the inner edge
	for i in range(3):
		x = 6 + i * 15
		B(p, (13, 12, 14), (x, 6, 30), ("B8AC98", "9AA0A0", "A89078")[i])
		B(p, (14, 0.8, 15), (x, 12.4, 30), "3A3A40")
		window(p, x, 7, 23, 4, 3.6, (WARM, None, "FFE6C0")[i], frame="6A6A62")
	return p


def roof_tile():
	"""320 x 320 of low back-street rooftops for the far city out to the horizon: an 8 x 8 grid of 2-7 storey blocks in
	muted greys and tans, roof units and tanks, and a few lit window strips."""
	p = []
	B(p, (320, 0.4, 320), (0, 0.2, 0), "34363A")
	for i in range(8):
		for j in range(8):
			x, z = -140 + i * 40, -140 + j * 40
			h = 8 + lit(i, j) * 2.4
			w = 26 + lit(j, i, 2) * 1.0
			col = ("8A8C8C", "9A948A", "7A7C80", "A8A498", "6E7276")[lit(i, j, 5) % 5]
			B(p, (w, h, w - 2), (x, h / 2, z), col)
			if lit(i, j, 7) < 6:
				B(p, (6, 3, 6), (x + 6, h + 1.5, z + 4), "8E9094")
			# Lit window bands: an emissive ring inset round the block at 1-2 floors, read as lit rooms from afar
			for b in range(1 + (h > 18)):
				col = (WARM, "F2E6D0", TV, "FFE6C0")[lit(j, i, b) % 4]
				B(p, (w + 0.2, 1.4, w - 1.8), (x, h * (0.35 + 0.35 * b), z), col, emit=1.3)
	return p


def retro():
	"""A Jinbocho corner from the film: a 3-storey retro tiled building (brown tile, arched windows, cornice, lit
	ground-floor cafe glazing, a striped awning) and a lit green phone booth on the pavement beside it."""
	W, D = 30, 20
	zf = -D / 2
	p = []
	B(p, (W, 28, D), (0, 14, 0), "8A5A44")
	B(p, (W + 2, 1.6, D + 2), (0, 28.8, 0), "C8B8A0")
	B(p, (W + 1, 1.0, D + 1), (0, 10, 0), "C8B8A0")
	for f in range(2):
		for x in (-10, -3.3, 3.3, 10):
			y = 15 + f * 8
			window(p, x, y, zf, 3.6, 4.6, (WARM, None, "FFE6C0", None)[lit(f, x) % 4], frame="E8DCC8")
			C(p, (3.6, 0.6, 1.2), (x, y + 2.4, zf - 0.3), "E8DCC8", seg=10, rot=(90, 0, 0))  # arch head
	for xs in (-W / 2, W / 2):  # side elevations: arched windows on both floors, lit cafe window, drainpipe
		s = 1 if xs > 0 else -1
		for f in range(2):
			for z in (-4, 4):
				side_window(p, xs, z, 15 + f * 8, 3.6, 4.6, (WARM, None, "FFE6C0")[lit(f, z, xs) % 3], frame="E8DCC8")
				C(p, (1.2, 0.6, 3.6), (xs + s * 0.3, 17.4 + f * 8, z), "E8DCC8", seg=10, rot=(0, 0, 90))  # arch head
		side_window(p, xs, -3, 4.5, 8, 5, "FFD8A0", frame="3A2A22")
		C(p, (0.6, 28, 0.6), (xs + s * 0.4, 14, D / 2 - 0.6), "6A5A4A", seg=6)
	corner_signs(p, -W / 2 + 0.6, zf, 26, 5, 2)  # narrow sign stack on the near corner
	B(p, (W - 4, 7, 0.3), (0, 4.5, zf - 0.1), "FFD8A0", emit=2.4)
	for x in range(-12, 14, 4):
		B(p, (0.5, 7.4, 0.5), (x, 4.5, zf - 0.4), "3A2A22")
	for i in range(6):
		B(p, (W / 6, 0.5, 4), (-W / 2 + W / 12 + i * W / 6, 8.6, zf - 2), ("2A6A4A", "E8E0D0")[i % 2], rot=(-15, 0, 0))
	# Phone booth: green frame, glass, lit ceiling, phone box
	bx = -8  # in front of the facade (near end for the 0.06 run camera), so every camera that sees the building sees the booth
	for dx in (-1.6, 1.6):
		for dz in (-1.6, 1.6):
			B(p, (0.4, 8, 0.4), (bx + dx, 4, zf - 7 + dz), "2E8A4A")
	B(p, (3.8, 0.6, 3.8), (bx, 8.2, zf - 7), "2E8A4A")
	B(p, (3.2, 1.0, 3.2), (bx, 9.0, zf - 7), "7AE0A0", emit=3)  # lit green roof cap, reads over the road wall
	B(p, (3.4, 0.3, 3.4), (bx, 7.8, zf - 7), "F4FFF4", emit=4)
	B(p, (3.2, 7, 3.2), (bx, 4, zf - 7), "C8F0D8", alpha=0.5, emit=2.2)
	B(p, (1.2, 1.8, 0.8), (bx, 4.6, zf - 5.7), "3A8A5A")
	B(p, (3.8, 0.4, 3.8), (bx, 0.2, zf - 7), "2E8A4A")
	return p


# Footprints along the road (width incl. side annexes) and depth (incl. balconies), for the street-front placer
FOOT = {"Mansion": (74, 34), "Apaato": (50, 32), "ShopHouse": (30, 22), "Konbini": (50, 24)}


def vary(k, color, palette):
	"""Per-instance wall colour: the material picks one palette colour from its object's random value."""
	m = k._mats.get((color, 0.8, 0.0, 0.0, 1.0))
	if not m:
		return
	nt = m.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	info = nt.nodes.new("ShaderNodeObjectInfo")
	ramp = nt.nodes.new("ShaderNodeValToRGB")
	ramp.color_ramp.interpolation = "CONSTANT"
	els = ramp.color_ramp.elements
	els[0].position, els[0].color = 0.0, hexcol(palette[0])
	els[1].position, els[1].color = 1.0 / len(palette), hexcol(palette[1])
	for i, c in enumerate(palette[2:], start=2):
		e = els.new(i / len(palette))
		e.color = hexcol(c)
	nt.links.new(info.outputs["Random"], ramp.inputs["Fac"])
	nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])


def hexcol(h):
	srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
	lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
	return (lin[0], lin[1], lin[2], 1.0)


def street(k, side, names, front, start, end, gap=(2, 8), avoid=(), flip=0.0):
	"""Buildings shoulder to shoulder along one side: each one's road face sits about `front` studs from the centre line.
	`avoid`: (x, z, radius) plots kept free. `flip`: share of mansions turned to show the corridor face to the road."""
	d = start
	while d < end:
		name = k.rng.choice(names)
		w, dep = FOOT[name]
		off = side * (front + dep / 2)
		pos, yaw = k.beside(d + w / 2, off)
		free = all(math.hypot(pos[0] - x, pos[2] - z) > r for x, z, r in avoid)
		if free and k.clear_of_road(pos[0], pos[2], abs(off) * 0.92):
			yaw += math.pi / 2 if side > 0 else -math.pi / 2  # -Z faces the road, as kit.along
			if name == "Mansion" and k.rng.random() < flip:
				yaw += math.pi  # Aki's apartment beat: the corridor face toward the road
			k.place(name, pos, yaw)
		d += w + k.rng.uniform(*gap)


def build(k):
	for name, parts in (
		("HQ", hq()),
		("Mansion", mansion()),
		("Apaato", apaato()),
		("ShopHouse", shophouse()),
		("Konbini", konbini()),
		("Office", office()),
		("StreetKit", street_kit()),
		("LowBlock", low_block()),
		("Retro", retro()),
		("RoofTile", roof_tile()),
		("CrossWire", cross_wire()),
	):
		k.prop(name, parts)
	vary(k, MANSION_WALL, ("D6D0C3", "9EA0A0", "8C6A52", "E8E4DA", "8FA08A"))  # off-white, grey concrete, brown tile, green
	vary(k, SHOP_WALL, ("B8B0A3", "8A8C8C", "7A5A48", "A8B4A0", "C8C0B0"))
	vary(k, APA_WALL, ("A99C83", "8E9A90", "B4A890"))

	k.ground(ASPH, margin=500, y=0.0)
	L = k.length
	end = L - 70
	# Street edge both sides: pavement, kerb, guardrail, lamps with pools, poles with wires over the street
	# As k.along (same rng calls, so the street layout is unchanged), but a kit is skipped on a tight inner bend where its
	# straight 48-stud length would bring a road-side corner (local x +-24, z -6.4) within 24 studs of the centre line.
	d = 24
	while d < end:
		for off in (-35, 35):
			k.rng.uniform(0, 0)
			pos, yaw = k.beside(d + k.rng.uniform(0, 0), off)
			if not k.clear_of_road(pos[0], pos[2], 24):
				continue
			name, _ = k.rng.choice(["StreetKit"]), k.rng.uniform(1.0, 1.0)
			p, right, t = k.at(d)
			s = 1 if off > 0 else -1
			corners = [p + right * (off - s * 6.4) + t * e for e in (-24, 24)]
			if all(k.clear_of_road(c.x, c.z, 24.6) for c in corners):
				k.place(name, pos, yaw + s * math.pi / 2)
		d += 48
	# Hero landmark: the HQ at the end of the street axis seen by the run cameras (0.06, 0.33, 0.62, 0.9 of the run)
	hq_plots = []
	for f in (0.33, 0.62, 0.9, 0.06):
		if len(hq_plots) == 2:
			break
		p, right, t = k.at(L * f)
		for ahead in (300, 360, 420, 250):
			q = p + right * 10 + t * ahead
			if k.clear_of_road(q.x, q.z, 110) and all(math.hypot(q.x - x, q.z - z) > 300 for x, z, _ in hq_plots):
				yaw = math.atan2(-t.x, -t.z) + math.pi  # front (-Z) faces back down the axis toward the camera
				k.place("HQ", (q.x, 0.0, q.z), yaw)
				hq_plots.append((q.x, q.z, 120))
				for side in (-1, 1):  # floodlights washing the pale front
					fx, fz = q.x - t.x * 70 + right.x * side * 40, q.z - t.z * 70 + right.z * side * 40
					k.light((fx, 30, fz), "E8F0FF", energy=100000, radius=10).data.use_shadow = False
				print("HQ at", f, ahead)
				break
	# Aki's apartment beat: one hero mansion square-on at the end of an early street axis, corridor face to the camera
	hero_plot = []
	for f in (0.33, 0.06):
		if hero_plot:
			break
		p, right, t = k.at(L * f)
		for ahead in (170, 200, 140, 230):
			q = p + right * 10 + t * ahead
			if k.clear_of_road(q.x, q.z, 48) and all(math.hypot(q.x - x, q.z - z) > 160 for x, z, _ in hq_plots):
				k.place("Mansion", (q.x, 0.0, q.z), math.atan2(-t.x, -t.z))  # +Z (corridor face) toward the camera
				hero_plot.append((q.x, q.z, 50))
				print("Hero mansion at", f, ahead)
				break
	hq_plots += hero_plot
	# The Jinbocho corner near the start, on the right
	pos, yaw = k.beside(L * 0.06 + 75, 40 + 10)
	k.place("Retro", pos, yaw + math.pi / 2)
	retro_plot = [(pos[0], pos[2], 30)]
	# Street fronts, a taller back row, the infield as low blocks, the far skyline kept below the HQ
	street(k, -1, ["ShopHouse", "ShopHouse", "Konbini", "Apaato", "Mansion"], 40, 20, end, avoid=hq_plots, flip=0.5)
	street(k, 1, ["ShopHouse", "Apaato", "ShopHouse", "Mansion", "Konbini"], 40, 20, end, avoid=hq_plots + retro_plot, flip=0.5)
	street(k, -1, ["Mansion", "Mansion", "ShopHouse"], 76, 0, end, gap=(6, 20), avoid=hq_plots)
	street(k, 1, ["Mansion", "Apaato", "Mansion"], 76, 0, end, gap=(6, 20), avoid=hq_plots)
	# Infield back streets: low blocks on an aligned 110-stud grid, each with a sodium light over its parking and park
	c = (k.lo + k.hi) / 2
	for i in range(-4, 5):
		for j in range(-4, 5):
			x, z = c.x + i * 110, c.z + j * 110
			if k.clear_of_road(x, z, 125) and all(math.hypot(x - a, z - b) > r + 70 for a, b, r in hq_plots):
				k.place("LowBlock", (x, 0.0, z), 0.0)
				k.light((x - 10, 20, z - 10), SODIUM, energy=60000, radius=8).data.use_shadow = False
	# The far city: rooftop tiles on an aligned 320-stud grid out to the horizon, offices standing among them
	for i in range(-7, 8):
		for j in range(-7, 8):
			x, z = c.x + i * 320, c.z + j * 320
			if math.hypot(i, j) <= 6.6 and k.clear_of_road(x, z, 330) and all(math.hypot(x - a, z - b) > r + 230 for a, b, r in hq_plots):
				k.place("RoofTile", (x, 0.0, z), 0.0)
	k.field(40, ["Office"], clearance=230, margin=450, scale=(0.4, 0.55))
	k.field(30, ["Office"], clearance=520, margin=1100, scale=(0.35, 0.5))  # back ring of lit towers to the horizon
	# Wires over the street: one set per 48 studs from the left kits' second pole (placed last: street layout unchanged)
	k.along(48, (-35,), ["CrossWire"], start=24, end=end)
	# Night: teal-blue ambient for cool shadows, warm sodium point lights at the lamps
	k.sky([(0.0, "3A4A5A"), (0.06, "22344A"), (0.25, "122236"), (1.0, "060C18")], strength=1.0, sun=(0.6, "6FA8C0", 35, 140))
	d = 24
	while d < L:
		for side in (-1, 1):
			pos, _ = k.beside(d + (0 if side < 0 else 24), side * 22, 18)
			k.light(pos, SODIUM, energy=26000, radius=4).data.use_shadow = False  # many lamps: shadows off
		d += 96
