#!/usr/bin/env python3
# Draws the Relic and chest art into assets/ui/ (design doc 4.38, docs/RELIC_SPEC.md "Names and art"): in-house digital art in the
# look of draw_raga_wheel.py, plus the contact sheet relic_art_sheet.png. Blender's Python has numpy:
# /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 tools/blender/portrait/draw_relics.py [raga] [mage] [king]
import colorsys
import os
import struct
import sys
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


# The Elf Mage's Relics (owner approval drafts): an adventuring party's keepsakes. Rarity treatment as Big Raga's set:
# Common and Epic plain, Rare a blue glow, Legendary a warm glow, Mythic a strong glow in the item's own colour.
STEEL = palette((200, 206, 216), (138, 146, 160), (88, 94, 110), (26, 26, 36))
HORN = palette((246, 234, 200), (214, 196, 150), (156, 136, 96), (48, 34, 20))
SILVER = palette((246, 250, 255), (196, 206, 222), (130, 142, 166), (22, 28, 48))
PEWTER = palette((196, 196, 186), (142, 142, 134), (96, 96, 92), (32, 30, 28))
CORK = palette((224, 184, 128), (184, 138, 84), (132, 92, 54), (52, 30, 14))
LEATHER = palette((150, 88, 176), (104, 54, 132), (66, 32, 90), (24, 10, 36))
STONE = palette((196, 192, 204), (146, 142, 158), (100, 96, 114), (32, 28, 42))
GEM = palette((236, 176, 255), (170, 86, 236), (104, 36, 168), (30, 8, 52))
GREEN = palette((150, 220, 110), (92, 170, 70), (52, 116, 48), (16, 40, 18))


def draw_helmet():
	c = Canvas()
	# Front view: a dented iron dome on a riveted brim, cheek guards and a nose guard round a dark inside, ivory horns.
	dome = np.maximum(circle(frame(0, 0.28), 1.08), frame(0, 0.28)[1])
	brim = box(frame(0, 0.36), 1.18, 0.15, 0.06)
	cheeks = [box(frame(side * 0.9, 0.86), 0.22, 0.44, 0.12) for side in (-1, 1)]
	nose = poly(P, [(-0.13, 0.45), (0.13, 0.45), (0.11, 1.12), (0, 1.26), (-0.11, 1.12)])
	for side in (-1, 1):
		horn = [(side * 0.92, -0.02), (side * 1.38, -0.26), (side * 1.56, -0.7), (side * 1.44, -1.2)]
		shape = union(*[bar(P, a, b, 0.24 - 0.07 * i, 0.17 - 0.07 * i) for i, (a, b) in enumerate(zip(horn, horn[1:]))])
		c.part(shape, HORN)
		# Growth rings across the horn.
		for ring_x, ring_y in horn[1:3]:
			c.fill(ring(frame(ring_x - side * 0.5, ring_y + 0.1), 0.52, 0.018), HORN[2], clip=shape + 0.02)
	c.fill(box(frame(0, 0.8), 0.72, 0.42, 0.2), rgb(54, 34, 26))
	c.part(dome, STEEL)
	# A raised ridge over the crown.
	c.part(np.maximum(box(frame(0, -0.3), 0.13, 0.9), dome + 0.02), STEEL)
	# Dents: a dark crescent with a lit lip under it.
	for dx, dy, r in ((-0.55, -0.15, 0.13), (0.5, -0.5, 0.1), (0.42, 0.05, 0.08)):
		dent = frame(dx, dy)
		c.fill(np.maximum(circle(dent, r), -circle((dent[0] + r * 0.4, dent[1] + r * 0.4), r)), STEEL[2])
		c.fill(np.maximum(ring(dent, r, 0.018), -dent[1]), STEEL[0])
	for cheek in cheeks:
		c.part(cheek, STEEL)
	c.part(brim, STEEL)
	c.part(nose, STEEL)
	for rivet_x in (-0.9, -0.45, 0.45, 0.9):
		c.part(circle(frame(rivet_x, 0.36), 0.065), STEEL, outline=0.03)
	c.save("relic_helmet.png")


def lotus(c, cx, cy, scale):
	# Five petals from a gold heart: a small engraved flower, not any crest.
	parts = []
	for degrees, length in ((0, 1.0), (-38, 0.86), (38, 0.86), (-74, 0.66), (74, 0.66)):
		petal = frame(cx, cy, degrees)
		petal = (petal[0] / scale, petal[1] / scale + 0.5 * length)
		parts.append(almond((petal[1], petal[0]), 0.5 * length, 0.2) * scale)
	c.part(union(*parts), BLUE, outline=0.035)
	c.part(circle(frame(cx, cy - 0.02 * scale), 0.15 * scale), GOLD, outline=0.03)


def draw_bracelet():
	c = Canvas()
	# A wide bangle seen from above the front: the top rim's oval, the far wall's inside, the front face with the flower.
	a, b, top, bottom = 1.42, 0.62, -0.44, 0.3
	outer = union(ellipse(frame(0, top), a, b), ellipse(frame(0, bottom), a, b), box(frame(0, (top + bottom) / 2), a, (bottom - top) / 2))
	hole = ellipse(frame(0, top), a - 0.24, b - 0.17)
	through = np.maximum(hole, ellipse(frame(0, bottom), a - 0.24, b - 0.17))
	body = np.maximum(outer, -through)
	c.glow(outer, BLUE[1], 0.2, 0.6)
	c.part(body, SILVER)
	# The far wall's inside, in shade.
	c.fill(np.maximum(hole, -through), SILVER[2])
	c.fill(np.abs(through), SILVER[3], clip=hole - 0.001)
	c.fill(np.abs(hole) - 0.025, SILVER[3])
	# The front face below the top rim's oval, with a groove along each edge.
	face = np.maximum(outer, -ellipse(frame(0, top), a, b))
	c.fill(np.abs(ellipse(frame(0, top), a, b)) - 0.022, SILVER[3], clip=outer)
	for y in (top + 0.12, bottom - 0.12):
		c.fill(np.abs(ellipse(frame(0, y), a - 0.04, b)) - 0.016, SILVER[2], clip=np.maximum(face, -frame(0, y)[1]))
	lotus(c, 0, bottom + b - 0.36, 0.62)
	c.save("relic_bracelet.png")


def draw_staff_relic():
	# The Dodge bar's staff icon, drawn by draw_mage_ui.py on the same 512 px, 3x grid, saved through this file's writer.
	import draw_mage_ui

	c = Canvas()
	art = draw_mage_ui.draw_staff(SIZE)
	c.premul, c.alpha = art[..., :3].astype(float) * 255, art[..., 3].astype(float)
	c.save("relic_staff.png")


def draw_flask():
	c = Canvas()
	flask = frame(0.04, 0.1, -12)
	body = box((flask[0], flask[1] - 0.38), 0.86, 0.98, 0.42)
	shoulder = poly(flask, [(-0.62, -0.48), (-0.3, -0.92), (0.3, -0.92), (0.62, -0.48)])
	neck = box((flask[0], flask[1] + 1.02), 0.24, 0.13, 0.04)
	cork = poly(flask, [(-0.2, -1.12), (-0.26, -1.56), (0.26, -1.56), (0.2, -1.12)])
	whole = union(body, shoulder, neck, cork)
	c.glow(whole, rgb(255, 160, 50), 0.24, 0.75)
	c.part(cork, CORK)
	for dot in ((-0.08, -1.3), (0.1, -1.44), (0.06, -1.24)):
		c.fill(circle((flask[0] - dot[0], flask[1] - dot[1]), 0.03), CORK[2])
	c.part(union(body, shoulder), PEWTER)
	c.part(neck, PEWTER)
	c.part(box((flask[0], flask[1] + 0.84), 0.36, 0.07, 0.03), GOLD, outline=0.04)
	# Worn: a dent and scratches.
	dent = (flask[0] - 0.5, flask[1] - 0.95)
	c.fill(np.maximum(circle(dent, 0.14), -circle((dent[0] + 0.06, dent[1] + 0.06), 0.14)), PEWTER[2])
	for scratch in ([(-0.62, 0.6), (-0.38, 0.86)], [(0.4, -0.3), (0.62, -0.12)], [(0.46, 0.92), (0.64, 0.78)]):
		c.fill(line(flask, scratch, 0.014), PEWTER[0], clip=body)
	# A plain holy emblem: a gold ring round a four-point star.
	emblem = (flask[0], flask[1] - 0.3)
	c.part(ring(emblem, 0.46, 0.07), GOLD, outline=0.04)
	c.part(poly(emblem, [(0, -0.36), (0.08, -0.08), (0.36, 0), (0.08, 0.08), (0, 0.36), (-0.08, 0.08), (-0.36, 0), (-0.08, -0.08)]), GOLD, outline=0.035)
	c.save("relic_flask.png")


def draw_grimoire():
	c = Canvas()
	pink, page_glow = rgb(255, 110, 200), rgb(255, 236, 170)
	cover_c, depth = (-0.2, -0.16), np.array((0.36, 0.32))
	cover = box(frame(*cover_c), 1.06, 1.32, 0.08)
	back = box(frame(cover_c[0] + depth[0], cover_c[1] + depth[1]), 1.06, 1.32, 0.08)
	# The page block: the cover swept back to the back cover.
	block = union(*[box(frame(cover_c[0] + t * depth[0], cover_c[1] + t * depth[1]), 1.0, 1.26, 0.04) for t in np.linspace(0.1, 0.9, 17)])
	whole = union(cover, back, block)
	c.glow(whole, pink, 0.16, 0.8)
	c.part(back, LEATHER)
	# Glowing page edges: the page block lit from within, its light spilling over the back cover.
	c.glow(block, page_glow, 0.09, 1.0)
	c.part(block, palette((255, 252, 226), (255, 238, 170), (240, 196, 110), (92, 54, 20)))
	pages = np.maximum(block, -cover)
	for t in np.linspace(0.25, 0.75, 4):
		c.fill(np.abs(box(frame(cover_c[0] + t * depth[0], cover_c[1] + t * depth[1]), 1.0, 1.26, 0.04)) - 0.012, rgb(236, 180, 96), clip=pages)
	c.part(cover, LEATHER)
	# Spine band and gold corners.
	spine = np.maximum(box(frame(cover_c[0] - 0.96, cover_c[1]), 0.12, 1.32), cover)
	c.fill(spine, LEATHER[2])
	for sx in (-1, 1):
		for sy in (-1, 1):
			x, y = cover_c[0] + sx * 1.06, cover_c[1] + sy * 1.32
			c.part(np.maximum(poly(P, [(x, y), (x - sx * 0.42, y), (x, y - sy * 0.42)]), cover), GOLD, outline=0.04)
	# The cover panel: a field of flowers under a dusk sky, in a gold frame.
	panel_c = (cover_c[0] + 0.06, cover_c[1] - 0.04)
	panel = box(frame(*panel_c), 0.68, 0.94, 0.06)
	c.part(box(frame(*panel_c), 0.78, 1.04, 0.08), GOLD)
	c.fill(panel, rgb(150, 136, 214))
	c.fill(panel, rgb(196, 176, 236), clip=grid_y - (panel_c[1] - 0.2))
	field = grid_y - (panel_c[1] + 0.08 + 0.1 * np.sin((grid_x - panel_c[0]) * 3.2))
	c.fill(np.maximum(panel, -field), GREEN[1])
	c.fill(np.maximum(panel, -(grid_y - (panel_c[1] + 0.5 + 0.08 * np.sin((grid_x - panel_c[0]) * 4 + 1)))), GREEN[2])
	c.fill(np.maximum(panel, circle(frame(panel_c[0] + 0.32, panel_c[1] - 0.5), 0.16)), rgb(255, 246, 200))
	flowers = [(-0.42, 0.2, 0), (0.0, 0.3, 1), (0.4, 0.16, 2), (-0.22, 0.56, 1), (0.24, 0.62, 0), (-0.5, 0.78, 2), (0.5, 0.8, 1), (0.02, 0.84, 2)]
	colours = (rgb(255, 255, 255), rgb(255, 150, 200), rgb(255, 222, 90))
	for fx, fy, k in flowers:
		center = (panel_c[0] + fx, panel_c[1] + fy)
		petals = union(*[circle(frame(center[0] + 0.07 * np.cos(a), center[1] + 0.07 * np.sin(a)), 0.062) for a in np.arange(5) * 2 * np.pi / 5 - np.pi / 2])
		c.fill(np.maximum(petals - 0.02, panel), GREEN[3])
		c.fill(np.maximum(petals, panel), colours[k])
		c.fill(np.maximum(circle(frame(*center), 0.04), panel), rgb(255, 176, 40) if k != 2 else rgb(220, 110, 30))
	c.fill(np.abs(panel) - 0.02, LEATHER[3])
	# The clasp: a leather strap from the pages onto the cover, held by a gold plate with a pink stone.
	strap = box(frame(cover_c[0] + 1.06, cover_c[1] + 0.12), 0.34, 0.16, 0.05)
	c.part(strap, LEATHER)
	plate = box(frame(cover_c[0] + 0.86, cover_c[1] + 0.12), 0.18, 0.26, 0.06)
	c.part(plate, GOLD)
	c.glow(circle(frame(cover_c[0] + 0.86, cover_c[1] + 0.12), 0.09), pink, 0.06, 0.8, clip=plate)
	c.part(circle(frame(cover_c[0] + 0.86, cover_c[1] + 0.12), 0.09), palette((255, 200, 236), (255, 110, 200), (196, 50, 140), (60, 10, 40)), outline=0.035)
	c.save("relic_grimoire.png")


def draw_chest_mage():
	# Big Raga's chest build in carved stone, with the staff's gold crescent round a purple gem for a lock.
	c = Canvas()
	half_w = 1.42
	body, lid = chest_shapes(half_w, 0.02, 1.12, -0.04)
	c.part(body, STONE)
	c.part(lid, STONE)
	# Stone blocks: staggered seams.
	seams = [box(frame(0, y), half_w, 0.016) for y in (0.46, 0.78, 1.1)]
	for row, y in enumerate((0.3, 0.62, 0.94, 1.26)):
		for x in (-0.5, 0.5) if row % 2 else (-1.0, 0.0, 1.0):
			seams.append(box(frame(x, y), 0.016, 0.16))
	c.fill(union(*seams), STONE[2], clip=body + 0.02)
	c.fill(np.abs(ellipse(frame(0, 0.02), half_w - 0.42, 0.62)) - 0.016, STONE[2], clip=lid + 0.03)
	for x in (-0.62, 0.62):
		c.fill(np.maximum(bar(P, (x * 0.5, -0.6), (x * 1.6, 0.02), 0.016), lid), STONE[2])
	for side in (-1, 1):
		c.part(np.maximum(box(frame(side * 0.98, 0.2), 0.14, 1.4), union(body, lid)), GOLD)
		c.part(poly(P, [(side * (half_w + 0.03), 1.06), (side * (half_w + 0.03), 1.53), (side * (half_w - 0.44), 1.53)]), GOLD)
	c.part(box(frame(0, 0.02), half_w + 0.1, 0.1), GOLD)
	# The lock: a gold plate, the staff's crescent, the purple gem.
	lock = frame(0, 0.36)
	c.part(box(lock, 0.52, 0.6, 0.16), GOLD)
	crescent = np.maximum(circle(lock, 0.44), -circle((lock[0] - 0.12, lock[1] + 0.1), 0.38))
	c.part(crescent, GOLD)
	gem = almond((lock[1], lock[0]), 0.3, 0.22)
	c.glow(gem, GEM[1], 0.08, 0.7, clip=box(lock, 0.52, 0.6, 0.16))
	c.part(gem, GEM)
	c.fill(np.maximum(gem + BEVEL, -lock[0]), GEM[2])
	c.fill(circle((lock[0] + 0.06, lock[1] + 0.12), 0.05), GEM[0])
	c.part(box(frame(0, 0.84), 0.07, 0.12, 0.03), GOLD, outline=0.035)
	c.save("chest_mage.png")


MAGE_SHEET = (
	("relic_helmet.png", "Dwarf's Helmet", "Common"),
	("relic_bracelet.png", "Hero's Bracelet", "Rare"),
	("relic_staff.png", "Elf Staff", "Epic"),
	("relic_flask.png", "Priest's Flask", "Legendary"),
	("relic_grimoire.png", "Master's Grimoire", "Mythic"),
	("chest_mage.png", "Elf Mage's Treasure", "Chest"),
)
# GachaConfig's rarity colours; the chest takes gold.
RARITY_COLOURS = {"Common": (180, 180, 180), "Rare": (70, 140, 255), "Epic": (170, 80, 230), "Legendary": (255, 170, 40), "Mythic": (255, 70, 110), "Chest": (250, 197, 72)}


def draw_mage_sheet(rows=MAGE_SHEET, out="relic_mage_art_sheet.png"):
	# relic_art_sheet.png's cells (256 px and 64 px) with a label under each; text through draw_mage_ui's CoreText helper.
	import draw_mage_ui

	columns, gap, label_h = 3, 16, 56
	cell_w, cell_h = 256 + 64 + gap, 256 + label_h
	width, height = gap + columns * (cell_w + gap), gap + 2 * (cell_h + gap)
	sheet = np.empty((height, width, 3))
	sheet[:] = (58, 62, 76)
	requests = [(draw_mage_ui.ROUND, 22, words) for _, name, rarity in rows for words in (name, rarity)]
	masks = draw_mage_ui.text_masks(requests)
	for index, (file, name, rarity) in enumerate(rows):
		left = gap + (index % columns) * (cell_w + gap)
		top = gap + (index // columns) * (cell_h + gap)
		image = read_png(file)
		assert image.shape == (SIZE, SIZE, 4), file
		for factor, (x0, y0) in ((2, (left, top)), (8, (left + 256 + gap, top + 96))):
			premul, coverage = shrink(image, factor)
			view = sheet[y0 : y0 + premul.shape[0], x0 : x0 + premul.shape[1]]
			view[:] = premul + view * (1 - coverage)
		for row, (words, colour) in enumerate(((name, (255, 255, 255)), (rarity, RARITY_COLOURS[rarity]))):
			mask = masks[(draw_mage_ui.ROUND, 22, words)][..., None]
			x0 = left + (cell_w - mask.shape[1]) // 2
			y0 = top + 256 + row * 26 - 2
			view = sheet[y0 : y0 + mask.shape[0], x0 : x0 + mask.shape[1]]
			view[:] = np.array(colour) * mask[: view.shape[0], : view.shape[1]] + view * (1 - mask[: view.shape[0], : view.shape[1]])
	alpha = np.full((height, width, 1), 255.0)
	write_png(out, np.dstack([sheet, alpha]).round().astype(np.uint8))


# The Golden King's Relics (owner approval drafts, goal boss-king k5, docs/RELIC_SPEC.md "The Golden King's drops"): the
# vault's treasures. Rarity treatment as the sets above; the Mythic key is the Dodge bar's key_icon with a gold glow.
DEEP_GOLD = palette((250, 197, 72), (203, 128, 30), (150, 86, 18), (58, 34, 14))
ARMOR_NAVY = palette((74, 84, 124), (40, 46, 78), (24, 26, 48), (10, 10, 24))
RUBY = palette((255, 120, 120), (212, 28, 40), (128, 8, 24), (50, 6, 14))


def draw_coin():
	c = Canvas()
	# A thick coin seen a little from above, a second one behind it: rim, raised edge, and a ring-and-diamond stamp (no face).
	back = frame(-0.62, -0.5, 0)
	c.part(ellipse(back, 0.92, 0.84), DEEP_GOLD)
	c.fill(np.abs(ellipse(back, 0.72, 0.64)) - 0.03, DEEP_GOLD[2], clip=ellipse(back, 0.92, 0.84) + 0.03)
	coin = frame(0.3, 0.3, 0)
	face = ellipse(coin, 1.12, 1.02)
	edge = union(face, ellipse((coin[0], coin[1] - 0.22), 1.12, 1.02), box((coin[0], coin[1] - 0.11), 1.12, 0.11))
	c.part(np.maximum(edge, -face + 0.001), DEEP_GOLD)
	c.fill(np.maximum(edge, -face), DEEP_GOLD[2])
	for ridge_x in np.linspace(-0.95, 0.95, 11):  # reeded edge
		c.fill(np.maximum(box((coin[0] - ridge_x, coin[1] - 0.12), 0.018, 0.1), -face), DEEP_GOLD[3])
	c.part(face, GOLD)
	c.fill(np.abs(ellipse(coin, 0.92, 0.82)) - 0.028, GOLD[2])
	c.fill(np.abs(ellipse(coin, 0.5, 0.44)) - 0.04, GOLD[2])
	c.fill(poly(coin, [(0, -0.3), (0.3, 0), (0, 0.3), (-0.3, 0)]), GOLD[2])
	c.fill(poly(coin, [(0, -0.18), (0.18, 0), (0, 0.18), (-0.18, 0)]), GOLD[0])
	c.fill(ellipse((coin[0] + 0.55, coin[1] + 0.5), 0.14, 0.07), rgb(255, 250, 225))
	c.save("relic_coin.png")


def draw_goblet():
	c = Canvas()
	cup = frame(0, 0, 0)
	bowl = np.maximum(ellipse((cup[0], cup[1] + 0.55), 0.98, 0.92), -(cup[1] + 0.55))  # the lower half of an oval
	rim = ellipse((cup[0], cup[1] + 0.55), 0.98, 0.3)
	stem = box((cup[0], cup[1] - 0.52), 0.11, 0.5)
	knop = ellipse((cup[0], cup[1] - 0.45), 0.24, 0.12)
	foot = ellipse((cup[0], cup[1] - 1.25), 0.72, 0.2)
	whole = union(bowl, rim, stem, knop, foot)
	c.glow(whole, BLUE[1], 0.2, 0.6)
	c.part(foot, DEEP_GOLD)
	c.fill(np.abs(ellipse((cup[0], cup[1] - 1.22), 0.5, 0.16)) - 0.02, DEEP_GOLD[2], clip=foot)
	c.part(stem, DEEP_GOLD)
	c.part(knop, DEEP_GOLD)
	c.part(bowl, DEEP_GOLD)
	# A navy band with three rubies round the bowl, and the rim's inside.
	band = np.maximum(box((cup[0], cup[1] + 0.1), 1.2, 0.17), bowl + BEVEL)
	c.fill(band, ARMOR_NAVY[1])
	for gem_x in (-0.46, 0.0, 0.46):
		gem = (cup[0] - gem_x, cup[1] + 0.1)
		c.part(poly(gem, [(0, -0.14), (0.12, 0), (0, 0.14), (-0.12, 0)]), RUBY, outline=0.03)
	c.part(rim, DEEP_GOLD)
	c.fill(ellipse((cup[0], cup[1] + 0.55), 0.82, 0.18), RUBY[1])  # wine
	c.fill(ellipse((cup[0] - 0.3, cup[1] + 0.5), 0.2, 0.05), RUBY[0])
	c.save("relic_goblet.png")


def draw_chain():
	c = Canvas()
	# Gold links along a loose S from the lower left to the upper right, one end a spear point: no face, no writing.
	t = np.linspace(0, 1, 9)
	path = np.column_stack([-1.3 + 2.5 * t, 1.1 - 2.2 * t + 0.45 * np.sin(t * np.pi * 2)])
	links = []
	for i in range(len(path) - 1):
		a, b = path[i], path[i + 1]
		mid, ang = (a + b) / 2, np.degrees(np.arctan2(b[1] - a[1], b[0] - a[0]))
		local = frame(mid[0], mid[1], ang)
		if i % 2 == 0:  # a flat link: an oval ring
			links.append(np.abs(ellipse(local, 0.3, 0.19)) - 0.065)
		else:  # a link seen edge-on: a slim bar
			links.append(box(local, 0.26, 0.075, 0.04))
	tip = frame(path[-1][0], path[-1][1], np.degrees(np.arctan2(path[-1][1] - path[-2][1], path[-1][0] - path[-2][0])))
	spear = poly(tip, [(0.1, -0.16), (0.62, 0), (0.1, 0.16)])
	ring_end = ring(frame(path[0][0], path[0][1]), 0.2, 0.07)
	for i, link in enumerate(links):
		c.part(link, GOLD if i % 2 == 0 else DEEP_GOLD)
	c.part(spear, DEEP_GOLD)
	c.part(ring_end, DEEP_GOLD)
	c.save("relic_chain.png")


def draw_armor():
	c = Canvas()
	# Front view of the cuirass: a navy underlayer, the gold breastplate with its Y line and skirt teeth, big round pauldrons.
	body = frame(0, 0.1, 0)
	under = box(body, 1.12, 1.18, 0.14)
	plate = box(body, 0.92, 1.05, 0.12)
	whole = union(under, circle(frame(-1.1, -0.55), 0.56), circle(frame(1.1, -0.55), 0.56))
	c.glow(whole, rgb(255, 180, 60), 0.24, 0.8)
	c.part(under, ARMOR_NAVY)
	c.part(plate, DEEP_GOLD)
	# Chest line: a Y from the collar to the belt, and the belt band.
	for a, b in (((-0.26, -0.9), (0, -0.3)), ((0.26, -0.9), (0, -0.3)), ((0, -0.3), (0, 0.45))):
		c.fill(bar(body, a, b, 0.03), ARMOR_NAVY[2], clip=plate + 0.03)
	c.fill(box((body[0], body[1] - 0.5), 0.92, 0.07), DEEP_GOLD[2], clip=plate + 0.02)
	for tooth_x in (-0.5, 0.5):  # navy triangles cut into the skirt plates
		c.fill(poly(body, [(tooth_x - 0.2, 0.62), (tooth_x + 0.2, 0.62), (tooth_x, 0.98)]), ARMOR_NAVY[1], clip=plate)
	# Collar and the pauldrons, each a dome over a lower ring.
	c.part(box((body[0], body[1] + 1.0), 0.42, 0.12, 0.05), DEEP_GOLD)
	for side in (-1, 1):
		shoulder = frame(side * 1.1, -0.55)
		c.part(np.maximum(ellipse((shoulder[0], shoulder[1] - 0.3), 0.62, 0.36), -(shoulder[1] - 0.3)), DEEP_GOLD)
		c.part(circle(shoulder, 0.56), GOLD)
		c.fill(np.abs(circle(shoulder, 0.36)) - 0.025, GOLD[2], clip=circle(shoulder, 0.56) + 0.02)
	c.save("relic_armor.png")


def draw_key_relic():
	# The Dodge bar's key icon (draw_king_ui.draw_key) on the same 512 px, 3x grid, with the Mythic gold glow under it.
	import draw_king_ui

	c = Canvas()
	art, shape = draw_king_ui.draw_key(SIZE, with_sdf=True)
	c.glow(shape, rgb(255, 200, 80), 0.22, 0.85)
	alpha = art[..., 3].astype(float)
	c.premul = art[..., :3].astype(float) * 255 + c.premul * (1 - alpha[..., None])
	c.alpha = alpha + c.alpha * (1 - alpha)
	c.save("relic_key.png")


def draw_chest_king():
	# Big Raga's chest build in gold, navy straps, a drum lock with a keyhole and a ruby, as the key's head.
	c = Canvas()
	half_w = 1.42
	body, lid = chest_shapes(half_w, 0.02, 1.12, -0.04)
	c.part(body, DEEP_GOLD)
	c.fill(box(frame(0, 1.02), half_w, 0.016), DEEP_GOLD[3], clip=body + 0.03)
	c.fill(box(frame(0, 0.2), half_w, 0.09), DEEP_GOLD[2], clip=body)
	c.part(lid, DEEP_GOLD)
	c.fill(np.abs(ellipse(frame(0, 0.02), half_w - 0.42, 0.62)) - 0.016, DEEP_GOLD[3], clip=lid + 0.03)
	for side in (-1, 1):
		c.part(np.maximum(box(frame(side * 0.98, 0.2), 0.14, 1.4), union(body, lid)), ARMOR_NAVY)
		c.part(poly(P, [(side * (half_w + 0.03), 1.06), (side * (half_w + 0.03), 1.53), (side * (half_w - 0.44), 1.53)]), ARMOR_NAVY)
		for rivet_y in (-0.5, 0.6, 1.2):
			c.part(circle(frame(side * 0.98, rivet_y), 0.05), GOLD, outline=0.03)
	c.part(box(frame(0, 0.02), half_w + 0.1, 0.1), ARMOR_NAVY)
	lock = frame(0, 0.4)
	c.part(circle(lock, 0.6), GOLD)
	c.part(ring(lock, 0.42, 0.04), DEEP_GOLD, outline=0.03)
	c.fill(union(circle((lock[0], lock[1] + 0.1), 0.12), poly(lock, [(-0.07, -0.1), (0.07, -0.1), (0.1, 0.3), (-0.1, 0.3)])), ARMOR_NAVY[2])
	c.part(poly((lock[0], lock[1] + 0.7), [(0, -0.14), (0.12, 0), (0, 0.14), (-0.12, 0)]), RUBY, outline=0.03)
	c.save("chest_king.png")


KING_SHEET = (
	("relic_coin.png", "Gold Coin", "Common"),
	("relic_goblet.png", "Royal Goblet", "Rare"),
	("relic_chain.png", "Chain of Heaven", "Epic"),
	("relic_armor.png", "Golden Armor", "Legendary"),
	("relic_key.png", "Key of Babylon", "Mythic"),
	("chest_king.png", "Golden King's Treasure", "Chest"),
)


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


def main(sets):
	# Sets to draw: "raga", "mage", "king", or all when none is named. Big Raga's files redraw byte for byte.
	sets = sets or ("raga", "mage", "king")
	if "raga" in sets:
		draw_talisman()
		draw_nail()
		draw_finger()
		draw_eyes()
		draw_world_core()
		draw_chest_raga()
		draw_chest_adapted()
		draw_sheet()
	if "mage" in sets:
		draw_helmet()
		draw_bracelet()
		draw_staff_relic()
		draw_flask()
		draw_grimoire()
		draw_chest_mage()
		draw_mage_sheet()
	if "king" in sets:
		draw_coin()
		draw_goblet()
		draw_chain()
		draw_armor()
		draw_key_relic()
		draw_chest_king()
		draw_mage_sheet(KING_SHEET, "relic_king_art_sheet.png")


if __name__ == "__main__":
	main(sys.argv[1:])
