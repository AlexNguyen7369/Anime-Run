# The Auto HUD icon (design doc 4.40), cut from the owner's screenshot: the green parts on black, without the viewer's
# "Edit" and share buttons. Blender -b --factory-startup --python tools/blender/plaza/auto_icon.py
# assets/ui/AutoIconSource.png -> assets/ui/AutoIcon.png (the whole icon), AutoIconOff.png (grey, unused since the spin),
# Then draws AutoIconArrows.png and AutoIconPlay.png, redrawn in the HUD icons' chunky outlined style (owner 2026-11-06) on one
# canvas: the arrows spin about its centre (design doc 4.40).
import os

import bpy
import numpy as np

UI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "ui")
SIZE = 512
MIN_PART = 500  # px: smaller connected parts are not the icon


def load(path):
	im = bpy.data.images.load(path)
	im.colorspace_settings.name = "Non-Color"  # keep the file's bytes
	w, h = im.size
	return np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]


def save(name, rgba):
	h, w = rgba.shape[:2]
	im = bpy.data.images.new(name, w, h, alpha=True)
	im.colorspace_settings.name = "Non-Color"
	im.pixels[:] = rgba[::-1].ravel().tolist()
	im.filepath_raw = os.path.join(UI, name + ".png")
	im.file_format = "PNG"
	im.save()


def green_parts(rgb):
	"""Mask of connected parts whose pixels are mostly green: the 2 arrows and the play triangle."""
	seed = rgb.max(axis=2) > 0.1
	h, w = seed.shape
	seen = np.zeros(seed.shape, dtype=bool)
	keep = np.zeros(seed.shape, dtype=bool)
	for y0, x0 in zip(*np.nonzero(seed)):
		if seen[y0, x0]:
			continue
		seen[y0, x0] = True
		stack, part = [(y0, x0)], []
		while stack:
			y, x = stack.pop()
			part.append((y, x))
			for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
				if 0 <= ny < h and 0 <= nx < w and seed[ny, nx] and not seen[ny, nx]:
					seen[ny, nx] = True
					stack.append((ny, nx))
		ys, xs = zip(*part)
		px = rgb[list(ys), list(xs)]
		if len(part) >= MIN_PART and (px[:, 1] > px[:, 0] * 1.05).mean() > 0.6 and (px[:, 1] > px[:, 2] * 1.3).mean() > 0.6:
			keep[ys, xs] = True
	return keep


OUTLINE_COLOUR = np.array([0.06, 0.13, 0.07])
BIG = 2 * SIZE  # drawn large, averaged down for smooth edges


def grow(mask, n):
	out = mask.copy()
	for i in range(n):
		next_ = out.copy()
		next_[1:] |= out[:-1]
		next_[:-1] |= out[1:]
		next_[:, 1:] |= out[:, :-1]
		next_[:, :-1] |= out[:, 1:]
		if i % 2:  # diagonals every other step: a rounder corner
			next_[1:, 1:] |= out[:-1, :-1]
			next_[:-1, :-1] |= out[1:, 1:]
			next_[1:, :-1] |= out[:-1, 1:]
			next_[:-1, 1:] |= out[1:, :-1]
		out = next_
	return out


def shrink(mask, n):
	return ~grow(~mask, n)


def in_triangle(x, y, a, b, c):
	def side(p, q):
		return (x - q[0]) * (p[1] - q[1]) - (p[0] - q[0]) * (y - q[1])
	d1, d2, d3 = side(a, b), side(b, c), side(c, a)
	return ~(((d1 < 0) | (d2 < 0) | (d3 < 0)) & ((d1 > 0) | (d2 > 0) | (d3 > 0)))


def paint(mask, top, bottom, outline_px, name):
	"""A flat shape as a HUD icon: vertical gradient, light rim top left, shade bottom right, thick dark outline."""
	h = BIG
	t = np.linspace(0, 1, h)[:, None, None]
	rgb = np.ones((h, h, 3)) * (np.array(top) * (1 - t) + np.array(bottom) * t)
	inner = shrink(mask, 10)
	lit = mask & ~np.roll(np.roll(inner, 12, axis=0), 12, axis=1)
	shade = mask & ~np.roll(np.roll(inner, -12, axis=0), -12, axis=1)
	rgb[shade] = rgb[shade] * 0.72
	rgb[lit] = rgb[lit] * 0.45 + 0.55
	outer = grow(mask, outline_px)
	rgb[outer & ~mask] = OUTLINE_COLOUR
	rgba = np.dstack([rgb, outer.astype(np.float64)])
	rgba[:, :, :3] *= rgba[:, :, 3:]  # average premultiplied
	small = rgba.reshape(SIZE, 2, SIZE, 2, 4).mean(axis=(1, 3))
	small[:, :, :3] /= np.maximum(small[:, :, 3:], 1e-3)
	save(name, small.astype(np.float32))


def draw_parts():
	c = BIG / 2
	y, x = np.mgrid[0 : BIG, 0 : BIG] + 0.5
	dx, dy = x - c, y - c
	r = np.hypot(dx, dy)
	theta = np.degrees(np.arctan2(dx, -dy)) % 360  # clockwise from the top
	radius, thick, head_half, head_len = 0.355 * BIG, 0.105 * BIG, 0.135 * BIG, 0.15 * BIG
	arrows = np.zeros((BIG, BIG), dtype=bool)
	for start in (20, 200):
		sweep = 125
		arrows |= (np.abs(r - radius) < thick / 2) & (((theta - start) % 360) < sweep)
		end = np.radians(start + sweep)
		px, py = c + radius * np.sin(end), c - radius * np.cos(end)  # the head's base centre
		out = (np.sin(end), -np.cos(end))
		along = (np.cos(end), np.sin(end))  # clockwise
		arrows |= in_triangle(
			x,
			y,
			(px + out[0] * head_half, py + out[1] * head_half),
			(px - out[0] * head_half, py - out[1] * head_half),
			(px + along[0] * head_len, py + along[1] * head_len),
		)
	paint(arrows, (0.62, 0.98, 0.26), (0.13, 0.66, 0.16), 18, "AutoIconArrows")
	size = 0.17 * BIG
	play = in_triangle(x, y, (c - size * 0.72, c - size), (c - size * 0.72, c + size), (c + size * 1.08, c))
	paint(shrink(grow(play, 6), 0), (0.78, 1.0, 0.36), (0.2, 0.74, 0.2), 18, "AutoIconPlay")


def main():
	rgb = load(os.path.join(UI, "AutoIconSource.png"))
	mask = green_parts(rgb)
	ys, xs = np.nonzero(mask)
	assert len(ys) > 10000, "icon not found"
	top, left, bottom, right = ys.min(), xs.min(), ys.max() + 1, xs.max() + 1
	rgb, mask = rgb[top:bottom, left:right], mask[top:bottom, left:right]
	# The outline fades into the black background: its brightness is the edge's alpha.
	alpha = mask * np.clip(rgb.max(axis=2) / 0.22, 0, 1)
	# Undo the blend with black, so a light background shows no dark fringe.
	colour = np.clip(rgb / np.maximum(alpha[:, :, None], 1e-3), 0, 1)
	# Pad to a square, then bilinear resample.
	side = max(rgb.shape[:2])
	square = np.zeros((side, side, 4), dtype=np.float32)
	y0, x0 = (side - rgb.shape[0]) // 2, (side - rgb.shape[1]) // 2
	square[y0 : y0 + rgb.shape[0], x0 : x0 + rgb.shape[1], :3] = colour
	square[y0 : y0 + rgb.shape[0], x0 : x0 + rgb.shape[1], 3] = alpha
	idx = (np.arange(SIZE) + 0.5) * side / SIZE
	lo, frac = np.floor(idx - 0.5).astype(int).clip(0, side - 2), (idx - 0.5 - np.floor(idx - 0.5)).clip(0, 1)

	def resample(image):
		f = frac[:, None, None]
		rows = image[lo] * (1 - f) + image[lo + 1] * f
		f = frac[None, :, None]
		return rows[:, lo] * (1 - f) + rows[:, lo + 1] * f

	on = resample(square)
	save("AutoIcon", on)
	off = on.copy()
	luma = (on[:, :, :3] * [0.3, 0.59, 0.11]).sum(axis=2) * 0.8
	off[:, :, 0], off[:, :, 1], off[:, :, 2] = luma, luma, luma
	save("AutoIconOff", off)
	draw_parts()
	print("auto_icon: wrote", SIZE, "px, cut", (left, top, right, bottom))


main()
