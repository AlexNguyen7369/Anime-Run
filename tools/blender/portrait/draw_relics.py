#!/usr/bin/env python3
# Draws the Relic and chest art into assets/ui/ (design doc 4.38, docs/RELIC_SPEC.md "Names and art"): in-house digital art in the
# look of draw_raga_wheel.py, plus the contact sheet relic_art_sheet.png. Blender's Python has numpy:
# /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 tools/blender/portrait/draw_relics.py
import colorsys
import os
import struct
import zlib

import numpy as np

SIZE, SS = 512, 3
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "ui"))

# Same model units, ink and bevel widths as draw_raga_wheel.py, so the set matches at every size.
EXTENT = 1.75
OUTLINE = 0.055
BEVEL = 0.042

n = SIZE * SS
grid_y, grid_x = np.mgrid[0:n, 0:n]
grid_x = (grid_x + 0.5) / n * EXTENT * 2 - EXTENT
grid_y = (grid_y + 0.5) / n * EXTENT * 2 - EXTENT
P = (grid_x, grid_y)
# Fades soft light out before the image edge, so a glow never ends in a hard square.
EDGE_FADE = np.clip((1.72 - np.maximum(np.abs(grid_x), np.abs(grid_y))) / 0.3, 0, 1)


def rgb(*c):
	return np.array(c, dtype=float)


def palette(hi, mid, low, ink):
	return tuple(rgb(*c) for c in (hi, mid, low, ink))


GOLD = palette((255, 236, 150), (250, 197, 72), (203, 128, 30), (58, 34, 14))
WOOD = palette((186, 122, 70), (146, 88, 48), (104, 58, 32), (48, 26, 14))
METAL = palette((112, 118, 146), (66, 70, 92), (40, 42, 58), (14, 12, 20))
IRON = palette((222, 232, 244), (150, 163, 180), (88, 100, 120), (24, 28, 42))
ICE = palette((215, 248, 255), (112, 214, 250), (44, 140, 214), (10, 30, 66))
BLUE = palette((190, 240, 255), (72, 184, 250), (28, 112, 214), (10, 26, 70))
PAPER = palette((246, 243, 232), (218, 214, 202), (170, 165, 155), (50, 44, 44))
RED = palette((226, 92, 78), (182, 50, 46), (126, 28, 32), (58, 14, 18))
MUMMY = palette((122, 86, 68), (78, 52, 44), (46, 30, 28), (20, 11, 11))
CLAW = palette((236, 222, 176), (190, 170, 124), (128, 108, 76), (32, 20, 14))
WRAP = palette((196, 180, 150), (148, 130, 104), (102, 86, 68), (34, 24, 18))
NAVY = palette((74, 112, 176), (28, 44, 92), (14, 22, 56), (6, 12, 34))
PRISM = palette((96, 78, 166), (48, 36, 98), (24, 17, 56), (8, 5, 22))
HALO = palette((255, 255, 240), (238, 232, 214), (160, 150, 170), (24, 18, 40))


# Coordinates and shapes. A point set p is an (x, y) pair of arrays; y points down the image.
def frame(cx, cy, degrees=0.0, p=P):
	a = np.radians(degrees)
	dx, dy = p[0] - cx, p[1] - cy
	return dx * np.cos(a) + dy * np.sin(a), -dx * np.sin(a) + dy * np.cos(a)


def circle(p, radius):
	return np.hypot(p[0], p[1]) - radius


def ring(p, radius, half):
	return np.abs(np.hypot(p[0], p[1]) - radius) - half


def box(p, half_w, half_h, corner=0.0):
	qx, qy = np.abs(p[0]) - half_w + corner, np.abs(p[1]) - half_h + corner
	return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - corner


def ellipse(p, a, b):
	k0 = np.hypot(p[0] / a, p[1] / b)
	k1 = np.maximum(np.hypot(p[0] / a**2, p[1] / b**2), 1e-6)
	return k0 * (k0 - 1) / k1


def bar(p, a, b, ra, rb=None):
	# Round bar from a to b, tapering from radius ra to rb.
	rb = ra if rb is None else rb
	ex, ey = b[0] - a[0], b[1] - a[1]
	t = np.clip(((p[0] - a[0]) * ex + (p[1] - a[1]) * ey) / (ex * ex + ey * ey), 0, 1)
	return np.hypot(p[0] - a[0] - ex * t, p[1] - a[1] - ey * t) - (ra + (rb - ra) * t)


def line(p, points, half):
	return np.minimum.reduce([bar(p, a, b, half) for a, b in zip(points, points[1:])])


def poly(p, points):
	# Exact signed distance to a closed polygon.
	points = np.array(points, dtype=float)
	best = np.full(p[0].shape, np.inf)
	inside = np.zeros(p[0].shape, dtype=bool)
	for a, b in zip(points, np.roll(points, 1, axis=0)):
		ex, ey = b - a
		wx, wy = p[0] - a[0], p[1] - a[1]
		t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
		best = np.minimum(best, np.hypot(wx - ex * t, wy - ey * t))
		inside ^= ((a[1] > p[1]) != (b[1] > p[1])) & (wx < ex * wy / (ey if ey != 0 else 1e-9))
	return np.where(inside, -best, best)


def ngon_points(sides, radius, degrees=0.0, cx=0.0, cy=0.0):
	angles = np.radians(degrees) + np.arange(sides) * 2 * np.pi / sides
	return np.column_stack([cx + radius * np.cos(angles), cy + radius * np.sin(angles)])


def ngon(p, sides, radius, degrees=0.0):
	return poly(p, ngon_points(sides, radius, degrees))


def octagon(p, radius):
	px, py = np.abs(p[0]), np.abs(p[1])
	return np.maximum.reduce([px, py, (px + py) * np.sqrt(0.5)]) - radius


def almond(p, half_w, half_h):
	# Two circles' overlap: an eye shape with sharp corners at +-half_w on the x axis.
	radius = (half_w**2 + half_h**2) / (2 * half_h)
	offset = radius - half_h
	return np.maximum(circle((p[0], p[1] - offset), radius), circle((p[0], p[1] + offset), radius))


def union(*shapes):
	return np.minimum.reduce(shapes)


def smooth_union(a, b, k):
	h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)


class Canvas:
	# Premultiplied layers: raga_wheel's alpha-weighted downsample, so the ink never fringes.
	def __init__(self):
		self.premul = np.zeros((n, n, 3))
		self.alpha = np.zeros((n, n))

	def over(self, color, coverage):
		coverage = coverage[..., None] if coverage.ndim == 2 else coverage
		self.premul = color * coverage + self.premul * (1 - coverage)
		self.alpha = coverage[..., 0] + self.alpha * (1 - coverage[..., 0])

	def fill(self, shape, color, clip=None):
		mask = shape <= 0 if clip is None else (shape <= 0) & (clip <= 0)
		self.over(color, mask.astype(float))

	def glow(self, shape, color, reach, strength, clip=None):
		# Soft light that falls off away from the shape.
		light = strength * np.exp(-np.maximum(shape, 0) / reach) * EDGE_FADE
		self.over(color, light if clip is None else light * (clip <= 0))

	def part(self, shape, colors, outline=OUTLINE, clip=None):
		# Flat cel bevel, lit from the top left: each part's edge band takes the highlight or the shadow by the way it faces.
		hi, mid, low, ink = colors
		grad_y, grad_x = np.gradient(shape)
		facing = -(grad_x + grad_y) / np.maximum(np.hypot(grad_x, grad_y), 1e-9) / np.sqrt(2)
		edge = shape > -BEVEL
		body = np.where((edge & (facing > 0.1))[..., None], hi, np.where(edge[..., None], low, mid))
		body = np.where((shape > 0)[..., None], ink, body)
		mask = shape <= outline
		self.over(body, (mask if clip is None else mask & (clip <= 0)).astype(float))

	def save(self, name):
		premul = self.premul.reshape(SIZE, SS, SIZE, SS, 3).mean(axis=(1, 3))
		coverage = self.alpha.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))
		safe = np.maximum(coverage, 1e-6)[..., None]
		write_png(name, np.dstack([premul / safe, coverage * 255]).round().clip(0, 255).astype(np.uint8))


def _chunk(kind, data):
	return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def write_png(name, image):
	path = os.path.join(OUT_DIR, name)
	raw = b"".join(b"\0" + image[row].tobytes() for row in range(image.shape[0]))
	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n")
		f.write(_chunk(b"IHDR", struct.pack(">IIBBBBB", image.shape[1], image.shape[0], 8, 6, 0, 0, 0)))
		f.write(_chunk(b"IDAT", zlib.compress(raw, 9)))
		f.write(_chunk(b"IEND", b""))
	print(path)


def read_png(name):
	# Reads only what write_png and draw_raga_wheel.py write: 8-bit RGBA, no line filter.
	with open(os.path.join(OUT_DIR, name), "rb") as f:
		data = f.read()
	assert data[:8] == b"\x89PNG\r\n\x1a\n", name
	pos, idat, size = 8, b"", None
	while pos < len(data):
		length, kind = struct.unpack(">I4s", data[pos : pos + 8])
		body = data[pos + 8 : pos + 8 + length]
		if kind == b"IHDR":
			size = struct.unpack(">IIBBBBB", body)
		elif kind == b"IDAT":
			idat += body
		pos += 12 + length
	width, height, depth, color = size[:4]
	assert (depth, color) == (8, 6), name
	rows = np.frombuffer(zlib.decompress(idat), dtype=np.uint8).reshape(height, width * 4 + 1)
	assert not rows[:, 0].any(), name
	return rows[:, 1:].reshape(height, width, 4).astype(float)


# The Relics.
def draw_talisman():
	c = Canvas()
	strip = frame(-0.08, -0.42, 10)
	# A slight S-bend so the charm hangs like paper, not a plank.
	bent = (strip[0] + 0.05 * np.sin(strip[1] * 2.4), strip[1])
	paper = box(bent, 0.6, 1.08, 0.02)
	tail = (bent[0], bent[1] - 1.08)
	# Red cord and a big tassel under the paper's lower edge.
	c.part(bar(tail, (0, -0.05), (0, 0.24), 0.055), RED)
	threads = poly(tail, [(-0.15, 0.24), (0.15, 0.24), (0.38, 0.92), (-0.38, 0.92)])
	c.part(threads, RED)
	for offset in (-0.1, 0.1):
		c.fill(line(tail, [(offset * 0.7, 0.42), (offset * 1.7, 0.84)], 0.02), RED[3])
	c.part(octagon((tail[0], tail[1] - 0.22), 0.17), GOLD)
	c.part(paper, PAPER)
	# Bold bars and an abstract seal: a ring, a diamond and a dot, not any writing.
	for bar_y, half in ((-0.86, 0.09), (-0.66, 0.04), (0.66, 0.04), (0.86, 0.09)):
		c.fill(box((bent[0], bent[1] - bar_y), 0.47, half), RED[1])
	c.fill(ring(bent, 0.42, 0.075), RED[1])
	c.fill(poly(bent, [(0, -0.27), (0.27, 0), (0, 0.27), (-0.27, 0)]), RED[1])
	c.fill(circle(bent, 0.085), PAPER[0])
	c.save("relic_talisman.png")


def draw_nail():
	c = Canvas()
	nail = frame(0, 0, 45)
	# Local axis: the head at -x (top left, into the light), the point at +x. Long and thin, so it never reads as a mallet.
	shank = poly(nail, [(-1.5, -0.2), (1.2, -0.15), (2.12, 0), (1.2, 0.15), (-1.5, 0.2)])
	collar = poly(nail, [(-1.54, -0.56), (-1.32, -0.2), (-1.32, 0.2), (-1.54, 0.56)])
	head = box((nail[0] + 1.62, nail[1]), 0.1, 0.62, 0.04)
	whole = union(shank, collar, head)
	c.glow(whole, BLUE[1], 0.2, 0.6)
	c.part(shank, IRON)
	# Square-section shank: one darker face, split along the middle.
	c.fill(shank + BEVEL, IRON[2], clip=-nail[1])
	# Grip rings under the head.
	for ring_x in (-1.14, -0.98, -0.82):
		c.fill(box((nail[0] - ring_x, nail[1]), 0.024, 0.2), IRON[3], clip=shank)
	c.part(collar, IRON)
	c.part(head, IRON)
	# The cool blue accent: a tempered point and a glowing band.
	tip = np.maximum(shank, 1.08 - nail[0])
	c.part(tip, BLUE)
	c.fill(tip + BEVEL, BLUE[2], clip=-nail[1])
	c.part(box((nail[0] - 0.4, nail[1]), 0.13, 0.27, 0.04), BLUE)
	c.save("relic_nail.png")


def draw_finger():
	c = Canvas()
	# Three joints along a line that hooks to the right, lower left to upper right, thin between knobbly knuckles.
	joints = [(-1.18, 1.3), (-0.72, 0.36), (-0.02, -0.42), (0.86, -0.74)]
	base = frame(-1.1, 1.12, 26)
	finger = bar(P, joints[0], joints[1], 0.38, 0.33)
	finger = smooth_union(finger, bar(P, joints[1], joints[2], 0.33, 0.3), 0.1)
	finger = smooth_union(finger, bar(P, joints[2], joints[3], 0.3, 0.29), 0.1)
	finger = smooth_union(finger, circle(frame(*joints[1]), 0.42), 0.1)
	finger = smooth_union(finger, circle(frame(*joints[2]), 0.39), 0.1)
	finger = np.maximum(finger, base[1] - 0.1)
	# A fingernail on the end joint, inside the finger's line but for a short overgrown point.
	tip = frame(*joints[3], -20)
	nail = union(box((tip[0] + 0.02, tip[1]), 0.34, 0.2, 0.16), poly(tip, [(0.12, -0.2), (0.5, 0), (0.12, 0.2)]))
	c.glow(union(finger, nail), rgb(255, 150, 40), 0.24, 0.75)
	c.part(finger, MUMMY)
	# Deep wrinkles across each knuckle: these make it a finger.
	for joint, degrees in ((joints[1], -56), (joints[2], -34)):
		local = frame(*joint, degrees)
		for offset, half in ((-0.13, 0.28), (0.0, 0.33), (0.13, 0.28)):
			c.fill(line(local, [(offset, -half), (offset * 1.4, 0), (offset, half)], 0.024), MUMMY[3], clip=finger + 0.04)
	c.part(nail, CLAW)
	# Glowing cracks: forked, narrowing lines from the finger's edge, so they read as splits and not as writing.
	cracks = [
		[(-0.5, 0.74), (-0.72, 0.68), (-0.72, 0.86), (-0.92, 0.9)],
		[(-0.62, -0.26), (-0.46, -0.12), (-0.42, 0.06), (-0.24, 0.1), (-0.2, 0.2)],
		[(-0.42, 0.06), (-0.56, 0.16)],
		[(0.2, -0.9), (0.28, -0.7), (0.18, -0.58), (0.3, -0.46), (0.26, -0.36)],
		[(0.18, -0.58), (0.02, -0.56)],
	]
	shape = union(*[bar(P, a, b, 0.07 - 0.012 * i, 0.058 - 0.012 * i) for crack in cracks for i, (a, b) in enumerate(zip(crack, crack[1:]))])
	inside = finger + 0.03
	c.glow(shape, rgb(255, 150, 40), 0.07, 0.6, clip=inside)
	c.fill(shape, rgb(255, 176, 52), clip=inside)
	c.fill(shape + 0.022, rgb(255, 240, 170), clip=inside)
	# Old wrappings end the finger, so no cut end shows and nothing reads as gore.
	c.part(box((base[0], base[1] + 0.02), 0.45, 0.13, 0.04), WRAP)
	c.part(box((base[0], base[1] - 0.2), 0.42, 0.12, 0.04), WRAP)
	c.save("relic_finger.png")


def draw_eyes():
	c = Canvas()
	plate = ngon(P, 6, 1.5, 0)
	# Rays out of the plate's six corners.
	rays = union(*[poly(frame(0, 0, 60 * i), [(1.2, -0.13), (1.72, 0), (1.2, 0.13)]) for i in range(6)])
	c.glow(plate, ICE[1], 0.14, 0.7)
	c.part(rays, ICE)
	c.part(plate, NAVY)
	c.part(ring(P, 0.3, 0.05), ICE)
	c.fill(ngon(P, 6, 0.16, 0), ICE[0])
	for i in range(6):
		a = np.radians(60 * i)
		eye = frame(0.98 * np.cos(a), 0.98 * np.sin(a))
		iris = circle(eye, 0.2)
		shape = almond(eye, 0.46, 0.27)
		c.glow(shape, ICE[1], 0.07, 0.55, clip=plate + 0.04)
		c.part(shape, palette((255, 255, 255), (232, 248, 255), (176, 222, 246), ICE[3]))
		c.fill(iris, ICE[2], clip=shape)
		c.fill(iris + 0.045, ICE[1], clip=shape)
		c.fill(circle(eye, 0.075), ICE[3], clip=shape)
		c.fill(circle((eye[0] + 0.075, eye[1] + 0.085), 0.055), rgb(255, 255, 255), clip=shape)
	c.save("relic_eyes.png")


def rainbow(angle):
	# Flat wedges of colour, 12 to the circle.
	table = np.array([colorsys.hsv_to_rgb(i / 12, 0.85, 1.0) for i in range(12)]) * 255
	return table[np.floor((angle / (2 * np.pi) % 1.0) * 12).astype(int) % 12]


def draw_world_core():
	c = Canvas()
	orbit = frame(0, 0, -22)
	band = np.abs(ellipse(orbit, 1.6, 0.66)) - 0.06
	orb = ngon(P, 10, 1.14, 18)
	c.glow(orb, rgb(170, 130, 255), 0.2, 0.55)
	c.part(band, HALO)
	c.part(orb, PRISM)
	# Facets: a shaded fan between two rings of corners, lit from the top left.
	outer = ngon_points(10, 1.14 - BEVEL, 18)
	inner = ngon_points(10, 0.6, 0)
	for i in range(10):
		a, b, d = outer[i], outer[(i + 1) % 10], inner[(i + 1) % 10]
		e = inner[i]
		mid = (a + b + d + e) / 4
		light = -(mid[0] + mid[1]) / (np.hypot(*mid) * np.sqrt(2))
		tone = PRISM[0] if light > 0.5 else PRISM[1] if light > -0.3 else PRISM[2]
		c.fill(poly(P, [a, b, d, e]), tone)
	for i in range(10):
		c.fill(line(P, [outer[i], inner[i]], 0.012), PRISM[3])
		c.fill(line(P, [inner[i], inner[(i + 1) % 10]], 0.012), PRISM[3])
	# Prismatic core: sharp wedges of rainbow around a white-hot heart.
	core = ngon(P, 10, 0.56, 0)
	angle = np.arctan2(grid_y, grid_x)
	c.over(rainbow(angle), (core <= 0).astype(float))
	c.glow(circle(P, 0.1), rgb(255, 255, 255), 0.13, 1.0, clip=core)
	# The near half of the orbit passes in front of the orb, with a small moon.
	c.part(band, HALO, clip=-orbit[1])
	moon = np.radians(40)
	moon_x, moon_y = 1.6 * np.cos(moon), 0.66 * np.sin(moon)
	tilt = np.radians(-22)
	c.part(octagon(frame(moon_x * np.cos(tilt) - moon_y * np.sin(tilt), moon_x * np.sin(tilt) + moon_y * np.cos(tilt)), 0.18), HALO)
	c.save("relic_world_core.png")


# The chests. Front view on one shared build, so Adapted reads as the same chest made grander.
def wheel_emblem(c, cx, cy, scale):
	# raga_wheel's shape: a ring, a hub and 8 spokes with octagon knobs, turned the same 22.5 degrees. Heavier, to hold at 64 px.
	local = frame(cx, cy)
	local = (local[0] / scale, local[1] / scale)
	parts = [ring(local, 1.02, 0.15), octagon(local, 0.36)]
	for i in range(8):
		a = np.pi * i / 4 + np.pi / 8
		spoke = frame(0, 0, np.degrees(a), local)
		parts.append(np.maximum.reduce([np.abs(spoke[1]) - 0.11, 0.05 - spoke[0], spoke[0] - 1.3]))
		parts.append(octagon((local[0] - 1.34 * np.cos(a), local[1] - 1.34 * np.sin(a)), 0.22))
	c.part(union(*parts) * scale, GOLD)


def chest_shapes(half_w, lid_bottom, lid_height, body_top):
	# An arched lid over a box, seen square on. Returns (body, lid).
	bottom = 1.5
	body = box(frame(0, (body_top + bottom) / 2), half_w, (bottom - body_top) / 2, 0.03)
	lid_center = frame(0, lid_bottom)
	return body, np.maximum(ellipse(lid_center, half_w + 0.08, lid_height), lid_center[1])


def draw_chest_raga():
	c = Canvas()
	half_w = 1.42
	body, lid = chest_shapes(half_w, 0.02, 1.12, -0.04)
	c.part(body, WOOD)
	c.fill(box(frame(0, 1.02), half_w, 0.016), WOOD[3], clip=body + 0.03)
	c.fill(box(frame(0, 0.2), half_w, 0.09), WOOD[2], clip=body)
	c.part(lid, WOOD)
	c.fill(np.abs(ellipse(frame(0, 0.02), half_w - 0.42, 0.62)) - 0.016, WOOD[3], clip=lid + 0.03)
	# Gold straps, rim and corner brackets.
	for side in (-1, 1):
		c.part(np.maximum(box(frame(side * 0.98, 0.2), 0.14, 1.4), union(body, lid)), GOLD)
		c.part(poly(P, [(side * (half_w + 0.03), 1.06), (side * (half_w + 0.03), 1.53), (side * (half_w - 0.44), 1.53)]), GOLD)
	c.part(box(frame(0, 0.02), half_w + 0.1, 0.1), GOLD)
	# A small wheel: Adapted's is half as big again.
	c.part(octagon(frame(0, 0.24), 0.78), GOLD)
	c.part(octagon(frame(0, 0.24), 0.62), WOOD)
	wheel_emblem(c, 0, 0.24, 0.36)
	c.save("chest_raga.png")


def draw_chest_adapted():
	c = Canvas()
	half_w = 1.38
	crimson, hot = rgb(255, 42, 54), rgb(255, 226, 200)
	seam_y = 0.1
	body, lid = chest_shapes(half_w, -0.12, 0.98, 0.32)
	spikes = [poly(P, [(x - 0.17, y + 0.22), (x + lean, y - 0.26), (x + 0.17, y + 0.22)]) for x, y, lean in ((-1.02, -0.82, -0.1), (0, -1.1, 0), (1.02, -0.82, 0.1))]
	whole = union(body, lid, *spikes)
	# Crimson light from the lifted seam, under everything: rays, a side flare and a halo.
	dist = np.hypot(grid_x, grid_y - seam_y)
	rays = (np.cos(np.arctan2(grid_y - seam_y, grid_x) * 16) > 0.35) & (dist > 0.2)
	c.over(crimson, rays * np.clip(1 - dist / 1.9, 0, 1) * EDGE_FADE * 0.85)
	c.glow(whole, crimson, 0.17, 0.65)
	c.glow(box(frame(0, seam_y), half_w + 0.3, 0.02), crimson, 0.12, 1.0)
	for spike in spikes:
		c.part(spike, GOLD)
	# The seam is a real gap of light: the lid has lifted off the body.
	c.fill(box(frame(0, seam_y), half_w + 0.02, 0.24), crimson)
	c.fill(box(frame(0, seam_y), half_w + 0.02, 0.055), hot)
	c.part(body, METAL)
	c.part(lid, METAL)
	c.glow(box(frame(0, seam_y), half_w, 0.22), crimson, 0.2, 0.85, clip=union(body, lid) + 0.05)
	# Heavy gold: rims, straps, base.
	for side in (-1, 1):
		c.part(np.maximum(box(frame(side * 1.08, -0.4), 0.17, 0.9), lid), GOLD)
		c.part(np.maximum(box(frame(side * 1.08, 0.9), 0.17, 0.62), body), GOLD)
	c.part(box(frame(0, -0.16), half_w + 0.14, 0.09), GOLD)
	c.part(box(frame(0, 0.36), half_w + 0.06, 0.08), GOLD)
	c.part(box(frame(0, 1.42), half_w + 0.12, 0.1), GOLD)
	# The bigger wheel straddles the seam, light showing through its spokes, with a crimson heart.
	wheel_emblem(c, 0, seam_y, 0.6)
	c.fill(octagon(frame(0, seam_y), 0.11), crimson)
	c.save("chest_adapted.png")


SHEET_ORDER = (
	"relic_talisman.png",
	"relic_nail.png",
	"raga_wheel.png",
	"relic_finger.png",
	"relic_eyes.png",
	"relic_world_core.png",
	"chest_raga.png",
	"chest_adapted.png",
)


def shrink(image, factor):
	# Alpha-weighted box filter, the same one the art is drawn with.
	size = image.shape[0] // factor
	alpha = image[..., 3:] / 255
	premul = (image[..., :3] * alpha).reshape(size, factor, size, factor, 3).mean(axis=(1, 3))
	coverage = alpha.reshape(size, factor, size, factor, 1).mean(axis=(1, 3))
	return premul, coverage


def draw_sheet():
	# No Pillow in Blender's Python, so no labels: left to right, top to bottom in SHEET_ORDER.
	columns, rows, gap = 4, 2, 16
	cell_w, cell_h = 256 + 64 + gap, 256
	width, height = gap + columns * (cell_w + gap), gap + rows * (cell_h + gap)
	sheet = np.empty((height, width, 3))
	sheet[:] = (58, 62, 76)
	for index, name in enumerate(SHEET_ORDER):
		left = gap + (index % columns) * (cell_w + gap)
		top = gap + (index // columns) * (cell_h + gap)
		image = read_png(name)
		assert image.shape == (SIZE, SIZE, 4), name
		for factor, (x0, y0) in ((2, (left, top)), (8, (left + 256 + gap, top + 96))):
			premul, coverage = shrink(image, factor)
			view = sheet[y0 : y0 + premul.shape[0], x0 : x0 + premul.shape[1]]
			view[:] = premul + view * (1 - coverage)
	alpha = np.full((height, width, 1), 255.0)
	write_png("relic_art_sheet.png", np.dstack([sheet, alpha]).round().astype(np.uint8))


if __name__ == "__main__":
	draw_talisman()
	draw_nail()
	draw_finger()
	draw_eyes()
	draw_world_core()
	draw_chest_raga()
	draw_chest_adapted()
	draw_sheet()
