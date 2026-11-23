"""World 2 Track 1: Devil Hunter Tokyo (Saw Man). Night Tokyo where the devil hunters work, built to read 1-1 with the
anime's street scenes (refs and landmark list: docs/world2_refs/DevilTokyo.md):
- the hunters' headquarters: a wide government office block with stacked horizontal ribbon windows and projecting floor
  slabs (Kasumigaseki style) and a tall dark tower behind it; its emblem is a changed abstract shape, not the real mark;
- the partners' apartment: a 7-storey tiled mansion block with balconies, sliding doors, AC units, laundry and a stair core;
- a 2-storey wooden apartment with an open steel corridor and outside stairs (the hero's first cheap home);
- narrow street fronts: shophouses with shutters, awnings and vertical projecting signs, a convenience store, vending
  machines, concrete power poles with transformers and sagging wires, curved-arm street lamps, guard-railed sidewalks.
Signs are abstract coloured panels and blocks only (no text, no real shop colours or logos, design doc 5). Everything
in-house, parts only. Proposed look; the owner approves the render set (design doc 4.47)."""

import math

# Muted, slightly desaturated palette of the anime's night streets; warm sodium and white fluorescent light
ASPH, WALK, CURB = "23252C", "4A4C52", "8A8C90"
TILE, TILE2, TILE3 = "D6D0C2", "C9C2B2", "E4E0D6"
SIDING, SIDING2 = "A99C82", "8C8270"
STEEL, STEEL2, FRAME = "6E747C", "4C525A", "3A3E46"
WARM, COOL, TV = "FFD9A0", "DCEBFF", "9FC0FF"
DARK = "141824"
SIGNS = ("FF4F6A", "3FD8E8", "FFD23F", "B06CFF", "FF8A3B", "7CE36A")


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


def window(p, x, y, zf, w, h, on, frame=FRAME, sill=TILE3, mullion=True):
	"""A framed window on a facade whose front face is at zf (road side is -Z): frame, glass, sill, centre mullion."""
	B(p, (w + 0.8, h + 0.8, 0.4), (x, y, zf - 0.1), frame)
	B(p, (w, h, 0.3), (x, y, zf - 0.3), on or DARK, emit=1.6 if on else 0)
	B(p, (w + 1.2, 0.4, 1.0), (x, y - h / 2 - 0.6, zf - 0.5), sill)
	if mullion:
		B(p, (0.3, h, 0.2), (x, y, zf - 0.5), frame)


def ac_unit(p, x, y, z):
	"""An outdoor air-conditioner unit facing the road: casing and a dark fan disk."""
	B(p, (2.8, 2.0, 1.2), (x, y, z), "E6E6E2")
	C(p, (1.5, 0.2, 1.5), (x - 0.4, y, z - 0.65), "50545A", rot=(90, 0, 0))


def mansion():
	"""The partners' apartment: tiled 7-storey mansion block, balconies to the street, stair core, roof tank."""
	W, D, fh, n = 60, 26, 9, 7
	H = n * fh + 1
	zf = -D / 2
	p = []
	B(p, (W, H, D), (0, H / 2, 0), TILE)
	B(p, (W + 1, 1.5, D + 1), (0, H + 0.75, 0), TILE2)  # roof parapet cap
	# Ground floor: lit lobby, canopy, mailbox wall, bike rack
	B(p, (12, 7, 0.3), (0, 3.5, zf - 0.2), COOL, emit=2.2)
	B(p, (0.4, 7, 0.4), (0, 3.5, zf - 0.4), FRAME)
	B(p, (16, 0.8, 6), (0, 8, zf - 3), TILE3)
	B(p, (10, 4, 0.6), (-16, 3, zf - 0.3), "9A9488")
	for i in range(5):
		C(p, (0.3, 2.4, 0.3), (14 + i * 2.2, 1.2, zf - 2), STEEL, seg=6)
	B(p, (11, 0.3, 0.3), (18.4, 2.4, zf - 2), STEEL)
	unit = (W - 6) / 4
	for f in range(1, n):
		y0 = f * fh
		B(p, (W - 4, 0.8, 5), (0, y0 + 0.4, zf - 2.5), TILE3)  # balcony slab
		B(p, (W - 4, 3.4, 0.5), (0, y0 + 2.5, zf - 4.75), "EDEAE2")  # parapet panel
		B(p, (W - 4, 0.4, 0.8), (0, y0 + 4.4, zf - 4.75), STEEL)  # handrail
		for u in range(5):
			B(p, (0.5, fh - 1, 5), (-(W - 6) / 2 + u * unit, y0 + fh / 2, zf - 2.5), TILE2)  # unit dividers
		for u in range(4):
			x = -(W - 6) / 2 + unit * (u + 0.5)
			r = lit(f, u)
			on = (WARM, "FFE6C0", TV)[r % 3] if r < 6 else None
			window(p, x - 1.5, y0 + 4.3, zf, 7.5, 6.4, on, mullion=True)
			ac_unit(p, x + 4.2, y0 + 1.8, zf - 1.2)
			if r % 4 != 1:  # laundry pole and clothes
				B(p, (9, 0.25, 0.25), (x - 1, y0 + 7.4, zf - 3.6), STEEL)
				B(p, (2.2, 2.6, 0.2), (x - 3, y0 + 6, zf - 3.6), ("E8E2D2", "6A8AC0", "C05A5A", "E0C070")[(u + f) % 4])
				B(p, (1.6, 2.0, 0.2), (x + 0.5, y0 + 6.3, zf - 3.6), ("F0F0F0", "4A5A6A", "D0A0B0")[(u * 2 + f) % 3])
	# Stair core on the right end with lit slit windows, drainpipes, roof tank, lift room and antenna
	B(p, (9, H + 7, 12), (W / 2 + 4.5, (H + 7) / 2, -2), TILE2)
	for f in range(n):
		B(p, (2.2, 5.5, 0.3), (W / 2 + 4.5, f * fh + 4.5, -8.1), COOL, emit=1.4)
	for x in (-W / 2 + 0.8, W / 2 - 0.8):
		C(p, (0.7, H, 0.7), (x, H / 2, zf - 0.5), "B8B2A4", seg=6)
	B(p, (10, 6, 10), (-14, H + 3, 4), TILE2)
	for dx in (-2, 2):
		for dz in (-2, 2):
			B(p, (0.5, 4, 0.5), (14 + dx, H + 2, 4 + dz), STEEL)
	C(p, (7, 6, 7), (14, H + 7, 4), "A8B0B8", seg=12)
	C(p, (0.4, 12, 0.4), (-20, H + 6, 8), STEEL, seg=6)
	B(p, (6, 0.3, 0.3), (-20, H + 10, 8), STEEL)
	B(p, (W, 3, 0.2), (0, H + 3, zf + 0.5), "8A9098", alpha=0.5)  # roof fence
	return p


def apaato():
	"""2-storey wooden apartment: siding walls, open steel corridor and railing to the street, outside stair, tin roof."""
	W, D, fh = 40, 16, 9
	zf = -D / 2
	p = []
	B(p, (W, fh * 2, D), (0, fh, 0), SIDING)
	for x in range(-18, 20, 4):
		B(p, (0.3, fh * 2, 0.2), (x, fh, zf - 0.1), SIDING2)  # siding battens
	for f in range(2):
		y0 = f * fh
		for i in range(4):
			x = -15 + i * 10
			B(p, (3.2, 6.6, 0.4), (x, y0 + 3.6, zf - 0.3), "6E7C86")  # steel door
			B(p, (0.5, 0.5, 0.5), (x + 1.1, y0 + 3.4, zf - 0.6), "C8C8C0", metal=1, rough=0.3)
			window(p, x + 4.5, y0 + 5, zf, 3, 2.4, "F4E6C8" if lit(f, i) < 6 else None, frame="9A9A98", sill=STEEL, mullion=False)
			B(p, (1.6, 2, 0.8), (x - 3, y0 + 5.6, zf - 0.5), "9AA0A6")  # meter box
			if f == 1:
				B(p, (2.4, 3, 2.2), (x + 4.5, y0 + 2.3, zf - 1.4), "ECECEC")  # corridor washing machine
	# Upper corridor: slab, railing with balusters, posts down to the ground
	B(p, (W + 2, 0.8, 4), (0, fh + 0.4, zf - 2), STEEL2)
	B(p, (W + 2, 0.4, 0.4), (0, fh + 4.2, zf - 3.8), STEEL2)
	B(p, (W + 2, 0.3, 0.3), (0, fh + 1.2, zf - 3.8), STEEL2)
	for x in range(-20, 21, 2):
		B(p, (0.2, 3, 0.2), (x, fh + 2.7, zf - 3.8), STEEL2)
	for x in (-20, 0, 20):
		B(p, (0.6, fh, 0.6), (x, fh / 2, zf - 3.7), STEEL2)
	# Outside steel stair on the right end, climbing toward the corridor
	for s in range(9):
		B(p, (3, 0.3, 1.2), (W / 2 + 2.5, 1 + s, zf - 11 + s * 1.1), STEEL)
	for x in (W / 2 + 1, W / 2 + 4):
		B(p, (0.3, 1.2, 13), (x, fh / 2 + 0.5, zf - 6.5), STEEL2, rot=(-38, 0, 0))
	# Shallow tin roof (front and back pitch), eaves, gutter
	B(p, (W + 3, 0.6, D / 2 + 2.5), (0, fh * 2 + 1.2, -D / 4 - 0.8), "4A5A6A", rot=(-12, 0, 0))
	B(p, (W + 3, 0.6, D / 2 + 2.5), (0, fh * 2 + 1.2, D / 4 + 0.8), "4A5A6A", rot=(12, 0, 0))
	B(p, (W + 3, 0.5, 0.6), (0, fh * 2, zf - 2.4), "5A6066")
	C(p, (0.5, fh * 2, 0.5), (-W / 2 - 1, fh, zf - 2.4), "5A6066", seg=6)
	B(p, (4, 4, 3), (-W / 2 + 3, 2, zf - 3), "7A7A70")  # gas cylinders cage
	return p


def shophouse():
	"""Narrow 4-storey shophouse: lit shop with half-open shutter, awning, sign band, windows with AC units, a projecting
	vertical sign at the corner, roof tank."""
	W, D = 20, 18
	zf = -D / 2
	p = []
	H = 10 + 3 * 8.5
	B(p, (W, H, D), (0, H / 2, 0), "B8B0A2")
	B(p, (W - 2, 7, 0.3), (0, 3.5, zf - 0.1), "FFF0D0", emit=2.2)  # lit shop interior
	for y in range(5, 10):  # shutter slats, half-open
		B(p, (W - 2, 0.7, 0.4), (0, y + 0.5, zf - 0.3), "8A8E94", metal=0.6, rough=0.5)
	for i, x in enumerate((-5, 0, 5)):
		B(p, (2.5, 3, 2), (x, 1.5, zf - 1), ("C05040", "D0A040", "50809A")[i])  # goods crates
	B(p, (W + 1, 0.6, 4.5), (0, 8.2, zf - 2.2), "B8322E", rot=(-14, 0, 0))  # awning
	B(p, (W, 2.2, 0.4), (0, 10.6, zf - 0.3), "1A1A22")
	for i, x in enumerate((-6, -1.5, 3)):  # sign band glyph blocks (abstract, no letters)
		B(p, (3, 1.4, 0.2), (x, 10.6, zf - 0.55), SIGNS[i * 2 % 6], emit=3)
	for f in range(3):
		y0 = 12 + f * 8.5
		for x in (-5, 5):
			on = (WARM, TV, None, "FFE6C0")[lit(f, x) % 4]
			window(p, x, y0 + 3.8, zf, 5, 4.4, on)
		ac_unit(p, 0, y0 + 1.6, zf - 1.0)
		B(p, (1.2, 0.3, 1.2), (0, y0 + 0.5, zf - 0.8), STEEL)
	B(p, (W - 4, 0.6, 3), (0, 20.5, zf - 1.5), "9A9488")  # 2nd-floor balcony
	B(p, (W - 4, 2.4, 0.3), (0, 22, zf - 3), STEEL2, alpha=0.7)
	# Projecting vertical sign at the corner: frame and stacked lit panels with glyph blocks
	B(p, (1.2, 20, 4.6), (-W / 2 - 0.6, 22, zf - 2.5), "15151C")
	for j in range(5):
		c = SIGNS[(j + 1) % 6]
		B(p, (1.4, 3.2, 3.8), (-W / 2 - 0.6, 14 + j * 3.8, zf - 2.5), c, emit=3.5)
		B(p, (1.6, 1.2, 1.6), (-W / 2 - 0.6, 14 + j * 3.8, zf - 2.5 + (j % 2 - 0.5)), "FFFFFF", emit=2)
	B(p, (W + 0.6, 1, D + 0.6), (0, H + 0.5, 0), "9A9488")
	B(p, (4, 3, 4), (5, H + 3, 3), "A8B0B8")
	for dx in (-1.5, 1.5):
		B(p, (0.4, 2, 0.4), (5 + dx, H + 1, 3), STEEL)
	C(p, (0.3, 8, 0.3), (-6, H + 4, 5), STEEL, seg=6)
	return p


def konbini():
	"""Corner convenience store: white box, two colour bands (not a real chain's colours), glazed front with mullions over
	a lit interior with shelf rows, auto door, roof condensers, bins and a lit pole sign."""
	W, D, H = 34, 22, 12
	zf = -D / 2
	p = []
	B(p, (W, H, D), (0, H / 2, 0), "ECECEA")
	B(p, (W - 2, 8, 0.4), (0, 4.4, zf - 0.1), "F6FBFF", emit=3.0)  # lit interior seen through the glass
	for r in range(3):  # shelf rows in front of it
		for s in range(6):
			B(p, (4, 1.0, 0.4), (-12.5 + s * 5, 1.8 + r * 2.0, zf - 0.4), ("D8584A", "4A9AD8", "E8C040", "5AB870")[(r + s) % 4])
	for x in range(-16, 17, 4):
		B(p, (0.4, 8.4, 0.5), (x, 4.6, zf - 0.7), "9AA2AA", metal=0.5)  # mullions
	B(p, (W, 0.5, 0.5), (0, 8.8, zf - 0.7), "9AA2AA", metal=0.5)
	B(p, (6, 7.6, 0.3), (0, 4.2, zf - 0.9), "C8E8FF", emit=1.0, alpha=0.6)  # auto door
	B(p, (W + 0.6, 1.4, 0.5), (0, 10.0, zf - 0.3), "6A3FB5", emit=1.6)  # colour bands
	B(p, (W + 0.6, 0.8, 0.5), (0, 11.0, zf - 0.3), "8BD448", emit=1.6)
	B(p, (W + 0.6, 0.6, D + 0.6), (0, H + 0.3, 0), "C8C8C6")
	for x in (-10, -3, 4):
		B(p, (5, 3, 4), (x, H + 2, 4), "D8D8D4")
		C(p, (2.4, 0.2, 2.4), (x, H + 3.6, 4), "50545A")
	for x, c in ((-14, "4A8A5A"), (-12, "3A6AA0"), (14, "8A8A80")):
		B(p, (1.6, 3, 1.6), (x, 1.5, zf - 2), c)  # bins
	B(p, (3, 3, 2), (11, 1.5, zf - 2), "DDEEFF", emit=0.6)  # ice chest
	C(p, (0.8, 18, 0.8), (W / 2 + 3, 9, zf - 1), STEEL, seg=6)  # pole sign
	B(p, (6, 4, 1.2), (W / 2 + 3, 18, zf - 1), "F4F4F0", emit=2.5)
	B(p, (6.2, 1.2, 1.3), (W / 2 + 3, 19, zf - 1), "6A3FB5", emit=2.5)
	B(p, (6.2, 0.6, 1.3), (W / 2 + 3, 17.4, zf - 1), "8BD448", emit=2.5)
	return p


def hq():
	"""The hunters' headquarters: a wide 11-storey government office block (stacked projecting floor slabs and ribbon
	windows, Kasumigaseki style) on a podium, with a tall dark tower behind. The plaque is a changed abstract emblem."""
	W, D, fh, n = 120, 60, 8, 11
	p = []
	B(p, (W + 20, 6, D + 20), (0, 3, 0), "8E8A82")  # podium
	B(p, (40, 7, 0.4), (0, 9.5, -D / 2 - 0.3), COOL, emit=2.0)  # entrance glazing
	B(p, (50, 1.2, 14), (0, 14, -D / 2 - 7), "B8B4AC")  # entrance canopy
	for x in (-22, 22):
		C(p, (1.6, 8, 1.6), (x, 10, -D / 2 - 12), "B8B4AC")
	C(p, (12, 0.8, 12), (-40, 9, -D / 2 - 0.6), "C8C2B0", seg=16, rot=(90, 0, 0))  # changed emblem: a ring
	B(p, (6, 6, 0.4), (-40, 9, -D / 2 - 1.2), "8C1A1A", rot=(0, 0, 45))  # and a plain diamond
	for f in range(n):
		y0 = 6 + f * fh
		B(p, (W + 3, 1.4, D + 3), (0, y0 + 0.7, 0), "C8C4BA")  # projecting floor slab
		B(p, (W, fh - 1.4, D), (0, y0 + 1.4 + (fh - 1.4) / 2, 0), "2A3244")  # dark ribbon glazing core
		for face, (w, axis) in enumerate(((W, "x"), (D, "zl"), (D, "zr"))):
			for s in range(int(w / 10)):
				if lit(f, s, face) > 4:
					continue
				u = -w / 2 + 5 + s * 10
				col = (COOL, WARM, "E8F0FF")[lit(s, f) % 3]
				if axis == "x":
					B(p, (8, 4.6, 0.2), (u, y0 + 4.2, -D / 2 - 0.15), col, emit=1.4)
				else:
					B(p, (0.2, 4.6, 8), ((-W / 2 - 0.15) if axis == "zl" else (W / 2 + 0.15), y0 + 4.2, u), col, emit=1.4)
	top = 6 + n * fh
	for x in range(-58, 60, 5):  # vertical mullions on the street face
		B(p, (0.5, n * fh, 0.5), (x, 6 + n * fh / 2, -D / 2 - 0.4), "9A9890")
	for z in range(-28, 30, 5):
		for x in (-W / 2 - 0.4, W / 2 + 0.4):
			B(p, (0.5, n * fh, 0.5), (x, 6 + n * fh / 2, z), "9A9890")
	B(p, (W + 4, 1.5, D + 4), (0, top + 0.75, 0), "B8B4AC")
	B(p, (30, 8, 20), (-20, top + 5, 6), "8E8A82")  # penthouse and roof plant
	for x in (10, 22, 34):
		B(p, (8, 4, 8), (x, top + 3, 10), "A0A4A8")
		C(p, (5, 0.3, 5), (x, top + 5.2, 10), "50545A")
	C(p, (1, 30, 1), (-30, top + 24, 6), STEEL, seg=6)  # antenna masts with red beacons
	C(p, (0.8, 22, 0.8), (-12, top + 20, 6), STEEL, seg=6)
	p.append(("ball", (2.4, 2.4, 2.4), (-30, top + 40, 6), "FF2B2B", {"emit": 10}))
	p.append(("ball", (2, 2, 2), (-12, top + 32, 6), "FF2B2B", {"emit": 10}))
	# The tall dark tower behind: banded glass with lit floors and a crown
	TH, TW = 220, 56
	tz = D / 2 + TW / 2 + 10
	B(p, (TW, TH, TW), (20, TH / 2, tz), "1C2232")
	for b in range(1, int(TH / 7)):
		B(p, (TW + 0.6, 0.8, TW + 0.6), (20, b * 7, tz), "5A6070")
		for s in range(5):
			if lit(b, s) < 4:
				B(p, (9, 4.5, 0.3), (20 - 22 + s * 11, b * 7 + 3.3, tz - TW / 2 - 0.2), ("8FB8FF", WARM)[s % 2], emit=1.3)
	B(p, (TW - 10, 14, TW - 10), (20, TH + 7, tz), "2A3040")
	p.append(("ball", (3, 3, 3), (20, TH + 16, tz), "FF2B2B", {"emit": 12}))
	# Gatehouse and fence along the street
	B(p, (8, 7, 8), (52, 3.5, -D / 2 - 16), "B8B4AC")
	B(p, (6, 3, 0.3), (52, 4.5, -D / 2 - 20.1), WARM, emit=1.8)
	B(p, (W - 20, 2.5, 0.6), (-6, 1.25, -D / 2 - 20), "6A6E74")
	for x in range(-60, 46, 8):
		B(p, (0.6, 4, 0.6), (x, 2, -D / 2 - 20), "5A5E64")
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
	return p


def sign_tower():
	"""Freestanding vertical sign stack on a steel column (abstract lit panels and glyph blocks, no text)."""
	p = []
	B(p, (1.2, 30, 1.2), (0, 15, 2), "1A1A22")
	B(p, (2, 24, 6), (0, 18, 0), "101018")
	for j in range(6):
		B(p, (2.4, 3.2, 5.2), (0, 7.5 + j * 3.8, 0), SIGNS[j % 6], emit=4)
		B(p, (2.6, 1.0, 2.0), (0, 7.5 + j * 3.8, (j % 3 - 1) * 1.2), "FFFFFF", emit=2.5)
	B(p, (2.4, 1, 6.4), (0, 31, 0), SIGNS[2], emit=5)
	return p


def pole():
	"""Concrete utility pole: tapered shaft, step bolts, two crossarms with insulators, transformer drums, a cable box,
	guard sleeve, and sagging wires running both ways along the street to the next pole (40 studs apart)."""
	p = []
	C(p, (1.5, 36, 1.5), (0, 18, 0), "9A988E", taper=0.65)
	C(p, (1.7, 2.4, 1.7), (0, 1.2, 0), "E8C030")  # guard sleeve
	C(p, (1.72, 0.6, 1.72), (0, 1.6, 0), "1A1A1A")
	for i in range(8):
		B(p, (0.2, 0.2, 1.4), (0, 8 + i * 2.4, (i % 2 - 0.5) * 1.4), STEEL)
	for y, w, n in ((34, 11, 4), (30, 9, 3)):
		B(p, (w, 0.6, 0.6), (0, y, 0), STEEL)
		for i in range(n):
			C(p, (0.5, 1.0, 0.5), (-w / 2 + 0.8 + i * (w - 1.6) / max(1, n - 1), y + 0.8, 0), "D8D8D0", seg=6)
	for dx in (-1.6, 1.6):
		C(p, (1.8, 3.4, 1.8), (dx, 25, 1.2), "8A9096", seg=10)
	B(p, (4, 0.4, 0.4), (0, 26.8, 1.2), STEEL)
	B(p, (1.6, 2.2, 1.0), (0, 21, -1.0), "8A9096")  # cable box
	C(p, (0.5, 18, 0.5), (0.6, 22, 0.8), "222428", seg=6)  # down cable
	# Wires along the street: each sags from this pole to the midpoint toward the next pole
	sag = 2.2
	ang = math.degrees(math.atan2(sag, 20))
	for y, z in ((34.6, -0.2), (34.6, 0.2), (30.8, 0), (27.5, 0.5)):
		for side in (-1, 1):
			B(p, (20.2, 0.18, 0.18), (side * 10, y - sag / 2, z), "15161A", rot=(0, 0, ang if side < 0 else -ang))
	B(p, (0.25, 0.25, 4), (0, 18, -2), STEEL)  # small bracket light toward the street
	B(p, (1.2, 0.5, 1.4), (0, 17.8, -3.8), WARM, emit=6)
	return p


def lamp():
	"""Curved-arm street lamp leaning over the sidewalk edge, warm sodium head."""
	p = []
	C(p, (0.7, 17, 0.7), (0, 8.5, 0), "5E6E66")
	B(p, (0.5, 3, 0.5), (0, 17.5, -0.9), "5E6E66", rot=(-35, 0, 0))
	B(p, (0.5, 0.5, 3.6), (0, 18.8, -3.6), "5E6E66")
	B(p, (1.4, 0.7, 2.6), (0, 18.5, -6), "4A5A52")
	B(p, (1.1, 0.2, 2.2), (0, 18.1, -6), WARM, emit=9)
	C(p, (1.2, 0.8, 1.2), (0, 0.4, 0), "4A5A52")
	return p


def vending():
	"""Three street vending machines side by side (red, white, blue): lit display window with product rows, button strip,
	coin panel, dispenser slot, and two recycling bins."""
	p = []
	for i, body in enumerate(("C8302E", "ECECEC", "2E62B8")):
		x = -3.8 + i * 3.8
		B(p, (3.6, 7, 3), (x, 3.5, 0), body)
		B(p, (3.0, 3.2, 0.2), (x, 5.0, -1.55), "F4FAFF", emit=2.4)
		for r in range(3):
			for s in range(4):
				B(p, (0.5, 0.8, 0.2), (x - 1.05 + s * 0.7, 4.0 + r * 1.05, -1.7), SIGNS[(i + r + s) % 6])
		B(p, (3.0, 0.3, 0.2), (x, 3.1, -1.6), "40E060", emit=2)
		B(p, (0.8, 1.2, 0.2), (x + 1.0, 2.2, -1.6), "8A8E94", metal=0.6)
		B(p, (2.4, 0.9, 0.3), (x - 0.3, 0.8, -1.5), "15161A")
	for x in (6.4, 8.4):
		B(p, (1.6, 2.6, 1.6), (x, 1.3, 0), "3A6AA0")
		C(p, (0.8, 0.2, 0.8), (x, 2.7, 0), "15161A")
	return p


def car():
	"""Parked compact car, lengthwise along the street: body, cabin glass, wheels, head and tail lights."""
	p = []
	B(p, (13, 2.0, 6.2), (0, 1.8, 0), "E8E8E6")
	B(p, (7, 2.2, 5.6), (0.8, 3.9, 0), "DADAD8")
	B(p, (7.1, 1.7, 5.7), (0.8, 4.0, 0), "1E2430", rough=0.2)
	B(p, (6.0, 0.3, 5.0), (0.8, 5.1, 0), "E8E8E6")
	for x in (-4, 4):
		for z in (-2.9, 2.9):
			C(p, (2.2, 0.8, 2.2), (x, 1.1, z), "15161A", rot=(90, 0, 0), seg=10)
	for z in (-2.2, 2.2):
		B(p, (0.2, 0.7, 1.2), (-6.55, 2.2, z), "FFF6D8", emit=4)
		B(p, (0.2, 0.7, 1.2), (6.55, 2.2, z), "FF2020", emit=3)
	return p


def sidewalk():
	"""24-stud sidewalk run: raised slab, curb, tactile strip, white guardrail to the road side, a bollard."""
	p = []
	B(p, (24.2, 0.8, 8), (0, 0.4, 0), WALK)
	B(p, (24.2, 1.0, 0.8), (0, 0.5, -4), CURB)
	B(p, (24.2, 0.1, 1.2), (0, 0.85, 1.5), "C8A830")
	for y in (2.2, 3.0):
		B(p, (24, 0.35, 0.3), (0, y, -3.2), "E8E8E4")
	for x in (-10, -2, 6):
		C(p, (0.35, 2.6, 0.35), (x, 2.1, -3.2), "E8E8E4", seg=6)
	C(p, (0.7, 2.4, 0.7), (11, 2.0, -3.4), "C8C8C4", seg=8)
	return p


# Footprints along the road (width incl. side annexes) and depth (incl. balconies), for the street-front placer
FOOT = {"Mansion": (74, 32), "Apaato": (48, 24), "ShopHouse": (24, 22), "Konbini": (44, 24)}


def street(k, side, names, front, start, end, gap=(2, 8), avoid=()):
	"""Buildings shoulder to shoulder along one side: each one's road face sits about `front` studs from the centre line.
	`avoid`: (x, z, radius) plots kept free for the hero landmark."""
	d = start
	while d < end:
		name = k.rng.choice(names)
		w, dep = FOOT[name]
		off = side * (front + dep / 2)
		pos, yaw = k.beside(d + w / 2, off)
		free = all(math.hypot(pos[0] - x, pos[2] - z) > r for x, z, r in avoid)
		if free and k.clear_of_road(pos[0], pos[2], abs(off) * 0.92):
			k.place(name, pos, yaw + (math.pi / 2 if side > 0 else -math.pi / 2))  # -Z faces the road, as kit.along
		d += w + k.rng.uniform(*gap)


def build(k):
	for name, parts in (
		("HQ", hq()),
		("Mansion", mansion()),
		("Apaato", apaato()),
		("ShopHouse", shophouse()),
		("Konbini", konbini()),
		("Office", office()),
		("SignTower", sign_tower()),
		("Pole", pole()),
		("Lamp", lamp()),
		("Vending", vending()),
		("Car", car()),
		("Sidewalk", sidewalk()),
	):
		k.prop(name, parts)

	k.ground(ASPH, margin=500, y=0.0)
	end = k.length - 70
	# Sidewalks both sides, poles on the left (wires run pole to pole), lamps on the right
	k.along(24, (-28, 28), ["Sidewalk"], start=12, end=end)
	k.along(40, (-31,), ["Pole"], start=30, end=end)
	k.along(36, (31,), ["Lamp"], start=48, end=end)
	k.along(150, (-35, 35), ["Vending", "SignTower", "Car"], jitter=10, start=90, end=end)
	# Hero landmark: the HQ across the street at a third and at two thirds of the run; its plot stays free of houses
	hq_plots = []
	for f in (0.3, 0.36, 0.24, 0.42, 0.18, 0.68, 0.62, 0.74, 0.56, 0.8):
		if len(hq_plots) == 2 or (hq_plots and abs(f - hq_plots[0][3]) < 0.25):
			continue
		for side in (-1, 1):
			pos, yaw = k.beside(k.length * f, side * 120)
			if k.clear_of_road(pos[0], pos[2], 100):
				k.place("HQ", pos, yaw + (math.pi / 2 if side > 0 else -math.pi / 2))
				hq_plots.append((pos[0], pos[2], 95, f))
				print("HQ at", f, side)
				break
	hq_plots = [h[:3] for h in hq_plots]
	# Street fronts, then a taller back row, then the far skyline
	street(k, -1, ["ShopHouse", "ShopHouse", "Konbini", "Apaato", "Mansion"], 38, 20, end, avoid=hq_plots)
	street(k, 1, ["ShopHouse", "Apaato", "ShopHouse", "Mansion", "Konbini"], 38, 20, end, avoid=hq_plots)
	street(k, -1, ["Mansion", "Mansion", "ShopHouse"], 76, 0, end, gap=(6, 20), avoid=hq_plots)
	street(k, 1, ["Mansion", "Apaato", "Mansion"], 76, 0, end, gap=(6, 20), avoid=hq_plots)
	k.field(60, ["Office"], clearance=190, margin=450, scale=(0.7, 1.5))
	k.sky([(0.0, "4A3E56"), (0.06, "2E2E4A"), (0.25, "161C34"), (1.0, "070A16")], strength=0.9, sun=(0.5, "8FA8FF", 35, 140))
	d = 40
	while d < k.length:
		pos, _ = k.beside(d, 0, 18)
		k.light(pos, WARM, energy=50000, radius=6)
		d += 140
