#!/usr/bin/env python3
# Draws the Elf Mage boss UI art into assets/ui/boss_mage/ (owner approval drafts): the Dodge bar staff icon, the osu-style hit
# circle set for the golem slam, three status icons, the barrage's magic circle, mock-up screens and a contact sheet.
# Same method as draw_raga_wheel.py: numpy signed distances, supersampled, flat cel colours, PNG written with zlib.
# Text in the mock-ups comes from macOS CoreText through the system `swift` (no Pillow in Blender's or the system Python).
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_mage_ui.py
import os
import struct
import subprocess
import tempfile
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "ui", "boss_mage")

INK = (58, 34, 14)  # raga_wheel.png's outline
NAVY = (18, 22, 43)  # UiTheme.Outline
GOLD_HI, GOLD, GOLD_LOW = (255, 236, 150), (250, 197, 72), (203, 128, 30)
WHITE = (255, 255, 255)


# Canvas: premultiplied float RGBA at the supersampled size ---------------------------------------------------------------
def canvas(w, h):
	return np.zeros((h, w, 4), np.float32)


def grid(size, ss, half):
	"""Pixel centres in model units, x right and y down, -half..half."""
	n = size * ss
	y, x = np.mgrid[0:n, 0:n].astype(np.float32)
	return (x + 0.5) / n * 2 * half - half, (y + 0.5) / n * 2 * half - half


def over(img, color, cov, alpha=1.0):
	cov = np.clip(cov, 0, 1).astype(np.float32) * alpha
	color = np.asarray(color, np.float32) / 255
	a = cov[..., None]
	img[..., :3] = color * a + img[..., :3] * (1 - a)
	img[..., 3] = cov + img[..., 3] * (1 - cov)


def stamp(img, src, x0, y0):
	"""Premultiplied src over img with its top left at (x0, y0), clipped."""
	h, w = src.shape[:2]
	H, W = img.shape[:2]
	x0, y0 = int(round(x0)), int(round(y0))
	ax, ay, bx, by = max(x0, 0), max(y0, 0), min(x0 + w, W), min(y0 + h, H)
	if ax >= bx or ay >= by:
		return
	s = src[ay - y0 : by - y0, ax - x0 : bx - x0]
	d = img[ay:by, ax:bx]
	d[...] = s + d * (1 - s[..., 3:4])


def box_matrix(n_out, n_in):
	"""Area weights from n_in samples to n_out: a box filter down, a near neighbour up."""
	scale = n_in / n_out
	edges = np.arange(n_out + 1) * scale
	j = np.arange(n_in)
	lo, hi = edges[:-1, None], edges[1:, None]
	m = np.clip(np.minimum(hi, j + 1) - np.maximum(lo, j), 0, None)
	return (m / m.sum(axis=1, keepdims=True)).astype(np.float32)


def resize(img, w, h):
	my, mx = box_matrix(h, img.shape[0]), box_matrix(w, img.shape[1])
	return np.einsum("yi,ijc,xj->yxc", my, img, mx, optimize=True)


def tint(img, color, alpha=1.0):
	out = img.copy()
	out[..., :3] *= np.asarray(color, np.float32) / 255
	return out * alpha


def to_rgba8(img):
	a = img[..., 3:4]
	rgb = img[..., :3] / np.maximum(a, 1e-6)
	return (np.clip(np.concatenate([rgb, a], axis=2), 0, 1) * 255).round().astype(np.uint8)


def from_rgba8(image):
	f = image.astype(np.float32) / 255
	f[..., :3] *= f[..., 3:4]
	return f


def write_png(path, image):
	h, w = image.shape[:2]
	raw = b"".join(b"\0" + image[row].tobytes() for row in range(h))

	def chunk(kind, data):
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

	with open(path, "wb") as f:
		f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
		f.write(chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
	print(os.path.normpath(path))


def finish(img, size, path=None):
	"""Downsample the supersampled canvas to size x size; write it when given a path."""
	ss = img.shape[0] // size
	small = img.reshape(size, ss, size, ss, 4).mean(axis=(1, 3))
	if path:
		write_png(path, to_rgba8(small))
	return small


# Signed distances --------------------------------------------------------------------------------------------------------
def circle(x, y, cx, cy, r):
	return np.hypot(x - cx, y - cy) - r


def ring(x, y, cx, cy, r, half):
	return np.abs(np.hypot(x - cx, y - cy) - r) - half


def segment(x, y, ax, ay, bx, by, r):
	ex, ey = bx - ax, by - ay
	t = np.clip(((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey), 0, 1)
	return np.hypot(x - ax - ex * t, y - ay - ey * t) - r


def polyline(x, y, pts, r0, r1=None):
	"""Capsule chain, its radius running from r0 to r1 along the points."""
	r1 = r0 if r1 is None else r1
	d = np.full(x.shape, np.inf, np.float32)
	for i in range(len(pts) - 1):
		r = r0 + (r1 - r0) * (i + 0.5) / (len(pts) - 1)
		d = np.minimum(d, segment(x, y, *pts[i], *pts[i + 1], r))
	return d


def polygon(x, y, pts):
	"""Exact distance to a closed polygon, negative inside."""
	d = np.full(x.shape, np.inf, np.float32)
	s = np.ones(x.shape, np.float32)
	for i in range(len(pts)):
		ax, ay = pts[i]
		bx, by = pts[i - 1]
		ex, ey = bx - ax, by - ay
		wx, wy = x - ax, y - ay
		t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
		d = np.minimum(d, (wx - ex * t) ** 2 + (wy - ey * t) ** 2)
		c1, c2, c3 = y >= ay, y < by, ex * wy > ey * wx
		s = np.where((c1 & c2 & c3) | (~c1 & ~c2 & ~c3), -s, s)
	return s * np.sqrt(d)


def rbox(x, y, cx, cy, hw, hh, round_=0.0):
	qx, qy = np.abs(x - cx) - hw + round_, np.abs(y - cy) - hh + round_
	return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - round_


def cel(sdf, base, hi, lo, band):
	"""Flat cel bevel lit from the top left, as draw_raga_wheel.py: the edge band takes hi or lo by the way it faces."""
	gy, gx = np.gradient(sdf)
	facing = -(gx + gy) / np.maximum(np.hypot(gx, gy), 1e-9) / np.sqrt(2)
	edge = (sdf > -band)[..., None]
	rgb = np.where(edge & (facing > 0.1)[..., None], hi, base)
	return np.where(edge & (facing <= 0.1)[..., None], lo, rgb).astype(np.float32)


def part(img, sdf, colors, outline, band, ink=INK):
	over(img, ink, sdf <= outline)
	over(img, cel(sdf, *colors, band), sdf <= 0)


# 1. Staff icon -------------------------------------------------------------------------------------------------------------
def draw_staff(size=512):
	ss, half = 3, 1.9
	X, Y = grid(size, ss, half)
	tilt = np.radians(40)  # head to the upper right, like a held staff
	# Staff space: s across (to the lower right on screen), u along the shaft (to the upper right).
	u = X * np.sin(tilt) - Y * np.cos(tilt) + 0.2
	s = X * np.cos(tilt) + Y * np.sin(tilt) - 0.02
	img = canvas(size * ss, size * ss)
	OL, BAND = 0.06, 0.05
	gold = (GOLD, GOLD_HI, GOLD_LOW)
	maroon = ((128, 34, 32), (178, 64, 50), (78, 18, 20))
	ribbon = ((214, 44, 48), (255, 112, 104), (140, 18, 32))
	gy, gu = 0.0, 1.0  # gem centre

	# Two short flat ribbon tails hanging from the wrap, thinner than the shaft, with swallowtail ends.
	for (ox, oy), (dx, dy), length in (((0.1, 0.06), (0.5, -0.87), 0.5), ((0.1, 0.18), (0.72, -0.69), 0.62)):
		nx, ny = -dy, dx
		ex, ey = ox + dx * length, oy + dy * length
		w0, w1 = 0.055, 0.075
		tail = polygon(s, u, [(ox + nx * w0, oy + ny * w0), (ex + nx * w1, ey + ny * w1), (ex - dx * 0.09, ey - dy * 0.09), (ex - nx * w1, ey - ny * w1), (ox - nx * w0, oy - ny * w0)])
		part(img, tail, ribbon, OL, BAND)
	# Shaft and its gold butt band.
	part(img, segment(s, u, 0, -2.05, 0, 0.5, 0.1), maroon, OL, BAND)
	part(img, rbox(s, u, 0, -1.78, 0.14, 0.07, 0.03), gold, OL, BAND)
	# Crescent: a disc less an offset disc, thick on the outer side, curling up around the gem ring to a knob.
	crescent = np.maximum(circle(s, u, gy, gu, 0.68), -circle(s, u, gy - 0.17, gu + 0.06, 0.55))
	crescent = np.maximum(crescent, -(u - 0.42))  # its lower tip ends on the collar
	crescent = np.maximum(crescent, -(s + 0.16))  # open on the far side: no thin hoop behind the ring
	knob_s, knob_u = -0.2, 1.66
	crescent = np.minimum(crescent, circle(s, u, knob_s, knob_u, 0.11))
	part(img, crescent, gold, OL, BAND)
	# Neck and collar under the ring.
	part(img, rbox(s, u, 0, 0.62, 0.075, 0.16, 0.03), gold, OL, BAND)
	part(img, rbox(s, u, 0, 0.44, 0.18, 0.075, 0.04), gold, OL, BAND)
	# Ribbon wrap: a red band round the shaft, its turns marked by dark slants.
	wrap = rbox(s, u, 0, 0.14, 0.135, 0.17, 0.04)
	part(img, wrap, ribbon, OL, BAND)
	for k in range(3):
		over(img, ribbon[2], (np.abs(u - s * 0.55 - (0.03 + k * 0.11)) < 0.017) & (wrap < -0.02))
	# Gold ring and the red gem.
	part(img, ring(s, u, gy, gu, 0.32, 0.075), gold, OL, BAND)
	gem = circle(s, u, gy, gu, 0.235)
	over(img, INK, gem <= 0.02)
	over(img, cel(gem, (212, 28, 40), (255, 96, 96), (128, 8, 24), 0.06), gem <= 0)
	# Glint toward the screen's top left, whatever the tilt.
	glint = np.hypot((X - (np.sin(tilt) * (gu - 0.2) + np.cos(tilt) * 0.02 - 0.1)) / 0.075, (Y - (-np.cos(tilt) * (gu - 0.2) + np.sin(tilt) * 0.02 - 0.08)) / 0.05)
	over(img, (255, 236, 236), glint <= 1)
	return img


# 2. Osu circle set ---------------------------------------------------------------------------------------------------------
def magic_pattern(x, y, scale, line):
	"""Distance to a light magic-circle line pattern of radius `scale`: two rings, rune ticks, 5 round lobes, a hub."""
	d = np.minimum(ring(x, y, 0, 0, scale, line), ring(x, y, 0, 0, scale * 0.8, line * 0.8))
	ang = np.arctan2(y, x)
	r = np.hypot(x, y)
	# Rune band: short ticks between the two rings, every third one a dot.
	cells = 36
	k = np.floor((ang + np.pi) / (2 * np.pi) * cells)
	mid = (k + 0.5) / cells * 2 * np.pi - np.pi
	along = r * np.sin(ang - mid)
	radial = r * np.cos(ang - mid) - scale * 0.9
	tick = np.maximum(np.abs(along) - line * 0.9, np.abs(radial) - scale * 0.045)
	dot = np.hypot(along, radial) - line * 1.6
	d = np.minimum(d, np.where(k % 3 == 0, dot, tick))
	for i in range(5):
		a = -np.pi / 2 + i * 2 * np.pi / 5
		lx, ly = np.cos(a) * scale * 0.5, np.sin(a) * scale * 0.5
		d = np.minimum(d, ring(x, y, lx, ly, scale * 0.18, line))
		d = np.minimum(d, circle(x, y, lx, ly, scale * 0.07))
		b = a + np.pi / 5
		d = np.minimum(d, segment(x, y, np.cos(b) * scale * 0.2, np.sin(b) * scale * 0.2, np.cos(b) * scale * 0.8, np.sin(b) * scale * 0.8, line * 0.6))
	return np.minimum(d, ring(x, y, 0, 0, scale * 0.14, line))


def draw_osu_circle(size=256):
	ss = 4
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	r = np.hypot(x, y)
	over(img, (24, 14, 54), r <= 0.92, 0.35)  # soft shadow ring outside the rim, so it holds on a bright sky
	over(img, (96, 60, 196), r <= 0.72, 0.5)  # translucent fill
	over(img, (214, 200, 255), magic_pattern(x, y, 0.6, 0.012) <= 0, 0.4)
	over(img, NAVY, ring(x, y, 0, 0, 0.78, 0.12) <= 0)
	over(img, WHITE, ring(x, y, 0, 0, 0.78, 0.09) <= 0)
	return img


RING_RADIUS = 0.78  # the approach ring at scale 1 lies on the hit circle's rim


def draw_osu_ring(size=256):
	ss = 4
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	d = ring(x, y, 0, 0, RING_RADIUS, 0.035)
	over(img, WHITE, np.exp(-np.maximum(d, 0) / 0.03), 0.55)  # white so the game tints it per circle
	over(img, NAVY, ring(x, y, 0, 0, RING_RADIUS, 0.055) <= 0)
	over(img, WHITE, d <= 0)
	return img


def draw_osu_hit(size=256):
	ss = 4
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	r = np.hypot(x, y)
	glow = np.exp(-np.abs(r - 0.62) / 0.08)
	over(img, (140, 210, 255), glow, 0.7)
	over(img, (230, 246, 255), ring(x, y, 0, 0, 0.62, 0.05) <= 0)
	spikes = np.full(x.shape, np.inf, np.float32)
	for i in range(8):
		a = i * np.pi / 4 + np.pi / 8
		reach = 0.95 if i % 2 == 0 else 0.75
		ca, sa = np.cos(a), np.sin(a)
		pts = [(ca * 0.36, sa * 0.36), (ca * 0.56 - sa * 0.12, sa * 0.56 + ca * 0.12), (ca * reach, sa * reach), (ca * 0.56 + sa * 0.12, sa * 0.56 - ca * 0.12)]
		spikes = np.minimum(spikes, polygon(x, y, pts))
	over(img, NAVY, spikes <= 0.035)
	core = np.clip(-spikes / 0.06, 0, 1)[..., None]
	over(img, (110, 190, 255) * (1 - core) + np.array(WHITE) * core, spikes <= 0)
	for i in range(6):  # sparkles between the spikes
		a = i * np.pi / 3
		sx, sy = np.cos(a) * 0.4, np.sin(a) * 0.4
		over(img, WHITE, circle(x, y, sx, sy, 0.035) <= 0)
	return img


def draw_osu_miss(size=256):
	ss = 4
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	d = np.minimum(segment(x, y, -0.55, -0.55, 0.55, 0.55, 0.16), segment(x, y, -0.55, 0.55, 0.55, -0.55, 0.16))
	part(img, d, ((255, 70, 80), (255, 150, 150), (178, 20, 44)), 0.08, 0.06, NAVY)
	return img


# 3. Status icons -----------------------------------------------------------------------------------------------------------
def status_base(size, color, deep):
	ss = 4
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	tile = rbox(x, y, 0, 0, 0.9, 0.9, 0.22)  # UiTheme.Corner "S" on a square cell
	over(img, NAVY, tile <= 0.08)
	over(img, np.where((y > 0.25)[..., None], deep, color), tile <= 0)  # two bands, bright over deep, as the HP fill
	return img, x, y


def glyph(img, d):
	over(img, NAVY, d <= 0.11)
	over(img, WHITE, d <= 0)


def draw_status_shocked(size=128):
	img, x, y = status_base(size, (150, 76, 236), (104, 44, 190))
	bolt = [(0.12, -0.72), (-0.42, 0.06), (-0.04, 0.06), (-0.16, 0.74), (0.44, -0.12), (0.06, -0.12), (0.2, -0.72)]
	glyph(img, polygon(x, y, bolt) - 0.02)
	return img


def draw_status_crushed(size=128):
	img, x, y = status_base(size, (176, 142, 100), (122, 94, 64))
	arrow = [(-0.2, -0.66), (0.2, -0.66), (0.2, 0.0), (0.5, 0.0), (0.0, 0.62), (-0.5, 0.0), (-0.2, 0.0)]
	d = polygon(x, y, arrow) - 0.03
	glyph(img, d)
	crack = polyline(x, y, [(-0.36, -0.18), (-0.08, -0.26), (0.08, -0.06), (0.36, -0.16)], 0.055)
	over(img, NAVY, (crack <= 0) & (d <= 0.11))
	return img


def draw_status_blasted(size=128):
	img, x, y = status_base(size, (64, 150, 240), (30, 96, 196))
	r, ang = np.hypot(x, y), np.arctan2(y, x)
	wave = 0.34 + 0.32 * np.abs(np.cos(ang * 4)) ** 4  # sharp 8-point burst
	burst = (r - wave) * 0.6
	glyph(img, burst)
	over(img, (64, 150, 240), circle(x, y, 0, 0, 0.2) <= 0)
	over(img, WHITE, circle(x, y, 0, 0, 0.1) <= 0)
	return img


# 4. Magic circle -----------------------------------------------------------------------------------------------------------
def draw_magic_circle(size=512):
	ss = 3
	x, y = grid(size, ss, 1.0)
	img = canvas(size * ss, size * ss)
	line = 0.011
	d = np.minimum(ring(x, y, 0, 0, 0.93, line * 1.4), ring(x, y, 0, 0, 0.78, line))
	r, ang = np.hypot(x, y), np.arctan2(y, x)
	# Rune band: 48 cells, each a small mark from a set of five, picked by a fixed pattern.
	cells = 48
	k = np.floor((ang + np.pi) / (2 * np.pi) * cells)
	mid = (k + 0.5) / cells * 2 * np.pi - np.pi
	a = r * np.sin(ang - mid)  # across the band
	b = r * np.cos(ang - mid) - 0.855  # along the radius
	kind = (k * 7 + 3) % 5
	marks = [
		np.maximum(np.abs(a) - line * 0.8, np.abs(b) - 0.035),  # bar
		np.abs(np.hypot(a, b) - 0.022) - line * 0.7,  # small ring
		np.minimum(np.hypot(a, b - 0.022) - line * 1.4, np.hypot(a, b + 0.022) - line * 1.4),  # two dots
		np.minimum(segment(a, b, -0.025, -0.03, 0, 0.03, line * 0.7), segment(a, b, 0.025, -0.03, 0, 0.03, line * 0.7)),  # V
		np.minimum(np.maximum(np.abs(a) - line * 0.8, np.abs(b) - 0.035), np.maximum(np.abs(b) - line * 0.8, np.abs(a) - 0.022)),  # cross
	]
	rune = np.select([kind == i for i in range(5)], marks)
	d = np.minimum(d, rune)
	# Inner ring, 5 round lobes with a pupil each, each joined to the hub by a spoke, curved petals between them, the hub.
	d = np.minimum(d, ring(x, y, 0, 0, 0.7, line))
	for i in range(5):
		t = -np.pi / 2 + i * 2 * np.pi / 5
		d = np.minimum(d, segment(x, y, np.cos(t) * 0.16, np.sin(t) * 0.16, np.cos(t) * 0.28, np.sin(t) * 0.28, line * 0.9))
		pm = t + np.pi / 5  # petal: an ellipse outline between two lobes
		pa = x * np.cos(pm) + y * np.sin(pm) - 0.4
		pb = -x * np.sin(pm) + y * np.cos(pm)
		d = np.minimum(d, np.abs(np.hypot(pa / 0.19, pb / 0.065) - 1) * 0.065 - line * 0.7)
		lx, ly = np.cos(t) * 0.43, np.sin(t) * 0.43
		d = np.minimum(d, ring(x, y, lx, ly, 0.15, line * 1.3))
		d = np.minimum(d, ring(x, y, lx, ly, 0.105, line * 0.7))
		d = np.minimum(d, circle(x, y, lx, ly, 0.06))
		d = np.minimum(d, circle(x, y, np.cos(pm) * 0.66, np.sin(pm) * 0.66, 0.026))
	d = np.minimum(d, ring(x, y, 0, 0, 0.16, line * 1.2))
	d = np.minimum(d, ring(x, y, 0, 0, 0.09, line * 0.8))
	d = np.minimum(d, circle(x, y, 0, 0, 0.04))
	over(img, (90, 170, 255), np.exp(-np.maximum(d, 0) / 0.022), 0.75)
	over(img, (170, 220, 255), d <= line * 0.9)
	over(img, (246, 252, 255), d <= 0)
	return img


# Text through CoreText -----------------------------------------------------------------------------------------------------
SWIFT = r"""
import AppKit
var out = Data()
while let line = readLine() {
	let f = line.components(separatedBy: "\t")
	let size = CGFloat(Double(f[1])!)
	let font = NSFont(name: f[0], size: size) ?? NSFont.boldSystemFont(ofSize: size)
	let str = NSAttributedString(string: f[2], attributes: [.font: font, .foregroundColor: NSColor.white])
	let b = str.size()
	let pad = Int(size * 0.15)
	let w = Int(ceil(b.width)) + 2 * pad, h = Int(ceil(b.height)) + 2 * pad
	let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
		space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
	NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
	str.draw(at: NSPoint(x: pad, y: pad))
	out.append("\(w) \(h)\n".data(using: .utf8)!)
	out.append(Data(bytes: ctx.data!, count: w * h))
}
FileHandle.standardOutput.write(out)
"""
ROUND, HEAVY = "ArialRoundedMTBold", "AvenirNext-HeavyItalic"  # stand-ins for FredokaOne and AnimeSkin's heavy italic


def text_masks(requests):
	"""requests: (font, px, text) tuples -> {request: float mask}, in one swift run."""
	with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
		f.write(SWIFT)
	try:
		lines = "".join(f"{font}\t{px}\t{text}\n" for font, px, text in requests)
		data = subprocess.run(["swift", f.name], input=lines.encode(), capture_output=True, check=True).stdout
	finally:
		os.unlink(f.name)
	masks, at = {}, 0
	for req in requests:
		end = data.index(b"\n", at)
		w, h = map(int, data[at:end].split())
		masks[req] = np.frombuffer(data, np.uint8, w * h, end + 1).reshape(h, w).astype(np.float32) / 255
		at = end + 1 + w * h
	return masks


def dilate(mask, r):
	pad = int(np.ceil(r))
	m = np.pad(mask, pad)
	out = np.zeros_like(m)
	h, w = mask.shape
	for dy in range(-pad, pad + 1):
		for dx in range(-pad, pad + 1):
			if dx * dx + dy * dy <= r * r:
				out[pad : pad + h, pad : pad + w] = np.maximum(out[pad : pad + h, pad : pad + w], m[pad + dy : pad + dy + h, pad + dx : pad + dx + w])
	return out


def text_image(mask, color, stroke=0.0, stroke_color=NAVY, alpha=1.0):
	pad = int(np.ceil(stroke))
	m = np.pad(mask, pad)
	img = canvas(m.shape[1], m.shape[0])
	if stroke:
		over(img, stroke_color, dilate(mask, stroke))
	over(img, color, m)
	return img * alpha


# 5. Mock-up screens --------------------------------------------------------------------------------------------------------
class Mock:
	def __init__(self, w, h, ss, art, masks):
		self.w, self.h, self.ss, self.art, self.masks = w, h, ss, art, masks
		self.img = canvas(w * ss, h * ss)
		self.y, self.x = (np.mgrid[0 : h * ss, 0 : w * ss].astype(np.float32) + 0.5) / ss

	def text(self, font, px, words, cx, cy, color=WHITE, stroke=0.0, alpha=1.0):
		mask = self.masks[(font, round(px * self.ss), words)]
		piece = text_image(mask, color, stroke * self.ss, alpha=alpha)
		stamp(self.img, piece, cx * self.ss - piece.shape[1] / 2, cy * self.ss - piece.shape[0] / 2)

	def image(self, name, cx, cy, size, color=None, alpha=1.0):
		px = max(1, int(round(size * self.ss)))
		piece = resize(self.art[name], px, px)
		piece = tint(piece, color, alpha) if color else piece * alpha
		stamp(self.img, piece, cx * self.ss - px / 2, cy * self.ss - px / 2)

	def rect(self, x0, y0, w, h, color, alpha=1.0, round_=0.0, stroke=0.0, stroke_color=GOLD):
		d = rbox(self.x, self.y, x0 + w / 2, y0 + h / 2, w / 2, h / 2, round_)
		if stroke:
			over(self.img, stroke_color, d <= stroke)
		over(self.img, color, d <= 0, alpha)
		return d

	def finish(self):
		ss = self.ss
		return self.img.reshape(self.h, ss, self.w, ss, 4).mean(axis=(1, 3))


def text_requests(phone, ss):
	"""Every (font, px, text) a mock-up of this size asks for."""
	k = 375 / 900 if phone else 720 / 900
	title = round(40 * k)
	reqs = [(HEAVY, title, "The Elf Mage"), (ROUND, round(48 * k * 0.62), "72%")]
	if phone:
		reqs += [(HEAVY, 18, "Tap when the bar hits the white!"), (HEAVY, 22, "Golem Slam! Hit every circle!"), (HEAVY, 30, "Dodged!")]
		reqs += [(ROUND, 31, str(i)) for i in range(1, 5)]
	else:
		reqs += [(HEAVY, 26, "Press SPACE when the bar hits the white!"), (HEAVY, 40, "Golem Slam! Hit every circle!"), (HEAVY, 54, "Dodged!")]
		reqs += [(ROUND, 47, str(i)) for i in range(1, 5)]
	return [(f, round(px * ss), t) for f, px, t in reqs]


def arena(m):
	w, h = m.w, m.h
	m.rect(0, 0, w, h, (40, 28, 24))
	m.rect(0, h * 0.28, w, h * 0.22, (146, 100, 50))  # ochre-brown wall band
	step = h * 0.11
	for i in range(int(w / step) + 2):  # dim diamond pattern on the band
		cx, cy = i * step, h * 0.39
		d = (np.abs(m.x - cx) + np.abs(m.y - cy)) - step * 0.32
		over(m.img, (118, 78, 38), d <= 0)
	m.rect(0, h * 0.5, w, h * 0.02, (70, 48, 32))
	m.rect(0, h * 0.52, w, h * 0.48, (78, 66, 58))  # floor
	m.rect(0, h * 0.52, w, h * 0.12, (92, 78, 68))


def boss_bar(m, phone):
	k = 375 / 900 if phone else 720 / 900
	w = min(max(m.w * 0.62, 280), m.w - 156)
	x0, top = (m.w - w) / 2, 8
	title, track = round(40 * k), round(48 * k * 1.25)
	m.text(HEAVY, title, "The Elf Mage", m.w / 2, top + title / 2, stroke=2)
	ty = top + title + 2
	m.rect(x0, ty, w, track, (50, 50, 55), round_=4, stroke=2, stroke_color=(255, 214, 90))
	fill_w = w * 0.72
	d = rbox(m.x, m.y, x0 + fill_w / 2, ty + track / 2, fill_w / 2, track / 2, 4)
	over(m.img, np.where((m.y < ty + track / 2)[..., None], (255, 70, 80), (150, 14, 40)), d <= 0)
	m.text(ROUND, round(48 * k * 0.62), "72%", m.w / 2, ty + track / 2, stroke=2)
	return ty + track


def mock_dodge(art, masks, w, h, phone):
	ss = 3 if phone else 2
	m = Mock(w, h, ss, art, masks)
	arena(m)
	boss_bar(m, phone)
	width = min(640, w * 0.58)
	height = 24 if phone else 36
	bottom = h - 130  # BossDodgeUi's fallback when no Team row is found
	x0, y0 = (w - width) / 2, bottom - height
	m.rect(x0, y0, width, height, (24, 18, 12), alpha=0.8, round_=height * 0.3, stroke=2)
	spot, slider = 0.68, 0.47
	sw = width * 0.125
	sx = x0 + width * spot
	t = np.clip(np.abs(m.x - sx) / (sw / 2), 0, 1)[..., None]  # gold to white to gold, as the Spot's gradient
	spot_rgb = np.array(WHITE) * (1 - t) + np.array(GOLD) * t
	over(m.img, spot_rgb, (np.abs(m.x - sx) <= sw / 2) & (np.abs(m.y - (y0 + height / 2)) <= height * 0.45))
	m.rect(x0 + width * slider - 3, y0 + height / 2 - height * 0.75, 6, height * 1.5, WHITE, stroke=1.5, stroke_color=(0, 0, 0))
	m.image("staff_icon", x0, y0 + height / 2, height * 2.2)
	words = 18 if phone else 26
	prompt = "Tap when the bar hits the white!" if phone else "Press SPACE when the bar hits the white!"
	m.text(HEAVY, words, prompt, w / 2, y0 - height * 0.7 - words / 2)
	return m.finish()


# Golem slam timing for the mock-ups: due times (s) and the approach window. Placeholders, as in the spec's proposal.
DUE = [0.55, 1.0, 1.4, 1.8]
APPROACH, RING_FROM, BURST_SECONDS = 0.9, 2.5, 0.5
SPOTS = [(380, 260), (560, 450), (760, 260), (930, 450)]  # px on a 1280x720 screen; scaled to the phone
RING_TINTS = [(196, 140, 255), (120, 220, 255)]


def mock_osu(art, masks, w, h, phone, t=1.0):
	ss = 3 if phone else 2
	m = Mock(w, h, ss, art, masks)
	arena(m)
	m.rect(0, 0, w, h, (60, 30, 110), alpha=0.25)  # the slam's tinted dim
	below = boss_bar(m, phone)
	k = h / 720
	cap = 22 if phone else 40
	cy = below + (14 if phone else 32) + cap / 2
	m.text(HEAVY, cap, "Golem Slam! Hit every circle!", w / 2, cy, stroke=2.5)
	# Timer strip: 2 seconds, emptying from the right.
	tw, th = w * 0.36, (5 if phone else 8)
	tx, ty = (w - tw) / 2, cy + cap / 2 + (6 if phone else 10)
	m.rect(tx, ty, tw, th, (24, 18, 12), alpha=0.85, round_=th / 2, stroke=1.5, stroke_color=NAVY)
	left = max(0.0, 1 - t / 2.0)
	if left > 0:
		m.rect(tx, ty, tw * left, th, (214, 190, 255), round_=th / 2)
	diameter = 68 if phone else 104  # image size; the white rim's outer edge is 0.9 of it
	for i, (px, py) in enumerate(SPOTS):
		cx, cy2 = px * k, py * k
		if phone:  # pack the rows tighter and lower, so the largest ring stays below the timer strip
			cy2 = 175 + (py - 260) * 0.48
		due = DUE[i]
		shown = due - APPROACH
		if t < shown:
			continue
		if t > due:  # hit: the burst, fading
			age = t - due
			if age <= BURST_SECONDS:
				fade = 1 - age / BURST_SECONDS * 0.6
				m.image("osu_hit", cx, cy2, diameter * (1.3 + age * 0.6), alpha=fade)
			continue
		fade_in = min(1.0, (t - shown) / 0.2 + 0.35)
		m.image("osu_circle", cx, cy2, diameter, alpha=fade_in)
		m.text(ROUND, 31 if phone else 47, str(i + 1), cx, cy2, stroke=2, alpha=fade_in)
		scale = 1 + (RING_FROM - 1) * (due - t) / APPROACH
		m.image("osu_ring", cx, cy2, diameter * scale, color=RING_TINTS[i % 2], alpha=fade_in)
	if t >= 2.0:
		m.text(HEAVY, 30 if phone else 54, "Dodged!", w / 2, h * 0.5, color=(255, 214, 90), stroke=3, alpha=1)
	return m.finish()


def sequence_strip(art, masks):
	frames = []
	for t in (0.0, 0.7, 1.3, 2.0):
		full = mock_osu(art, masks, 1280, 720, False, t)
		frames.append((t, resize(full, 640, 360)))
	gap, label = 16, 44
	strip = canvas(4 * 640 + 5 * gap, 360 + label + 2 * gap)
	over(strip, (24, 26, 36), np.ones(strip.shape[:2]))
	for i, (t, frame) in enumerate(frames):
		x0 = gap + i * (640 + gap)
		piece = text_image(masks[(ROUND, 30, f"{t:.1f} s")], WHITE)
		stamp(strip, piece, x0 + 320 - piece.shape[1] / 2, gap + label / 2 - piece.shape[0] / 2)
		stamp(strip, frame, x0, gap + label)
	return strip


# 6. Contact sheet ----------------------------------------------------------------------------------------------------------
def contact_sheet(art, hires, masks):
	names = list(art)
	pad, label = 24, 40
	half_w = pad + 512 + pad + 128 + pad + 64 + pad
	cell_w, cell_h = 2 * half_w, label + 512 + 2 * pad
	cols = 2
	rows = (len(names) + cols - 1) // cols
	sheet = canvas(cols * cell_w, rows * cell_h)
	over(sheet, (128, 130, 140), np.ones(sheet.shape[:2]))
	for i, name in enumerate(names):
		cx0, cy0 = (i % cols) * cell_w, (i // cols) * cell_h
		for j, bg in enumerate([(235, 236, 242), (32, 43, 71)]):
			x0 = cx0 + j * half_w
			block = canvas(half_w, cell_h)
			over(block, bg, np.ones(block.shape[:2]))
			stamp(sheet, block, x0, cy0)
			stamp(sheet, hires[name], x0 + pad, cy0 + label + pad)
			stamp(sheet, resize(art[name], 128, 128), x0 + pad + 512 + pad, cy0 + label + pad + 192)
			stamp(sheet, resize(art[name], 64, 64), x0 + pad + 512 + pad + 128 + pad, cy0 + label + pad + 224)
		piece = text_image(masks[(ROUND, 26, name + ".png")], WHITE, 2)
		stamp(sheet, piece, cx0 + pad, cy0 + 6)
	return sheet


def main():
	os.makedirs(OUT, exist_ok=True)
	draws = {
		"staff_icon": (draw_staff, 512),
		"osu_circle": (draw_osu_circle, 256),
		"osu_ring": (draw_osu_ring, 256),
		"osu_hit": (draw_osu_hit, 256),
		"osu_miss": (draw_osu_miss, 256),
		"status_shocked": (draw_status_shocked, 128),
		"status_crushed": (draw_status_crushed, 128),
		"status_blasted": (draw_status_blasted, 128),
		"magic_circle": (draw_magic_circle, 512),
	}
	art, hires = {}, {}
	for name, (draw, size) in draws.items():
		art[name] = finish(draw(size), size, os.path.join(OUT, name + ".png"))
		hires[name] = art[name] if size == 512 else finish(draw(512), 512)
	# The shipped files at their own size are what the mock-ups and the sheet's small views use.
	art = {name: from_rgba8(to_rgba8(img)) for name, img in art.items()}

	reqs = set(text_requests(False, 2)) | set(text_requests(True, 3))
	reqs |= {(ROUND, 30, f"{t:.1f} s") for t in (0.0, 0.7, 1.3, 2.0)} | {(ROUND, 26, n + ".png") for n in draws}
	masks = text_masks(sorted(reqs))

	for size, phone, tag in ((1280, False, "desktop"), (667, True, "phone")):
		h = 720 if not phone else 375
		write_png(os.path.join(OUT, f"mock_dodge_bar_{tag}.png"), to_rgba8(mock_dodge(art, masks, size, h, phone)))
		write_png(os.path.join(OUT, f"mock_osu_{tag}.png"), to_rgba8(mock_osu(art, masks, size, h, phone)))
	write_png(os.path.join(OUT, "mock_osu_sequence.png"), to_rgba8(sequence_strip(art, masks)))
	write_png(os.path.join(OUT, "ui_art_sheet.png"), to_rgba8(contact_sheet(art, hires, masks)))


if __name__ == "__main__":
	main()
