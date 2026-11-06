# The Auto HUD icon (design doc 4.40), cut from the owner's screenshot: the green parts on black, without the viewer's
# "Edit" and share buttons. Blender -b --factory-startup --python tools/blender/plaza/auto_icon.py
# assets/ui/AutoIconSource.png -> assets/ui/AutoIcon.png (on) and AutoIconOff.png (grey, off).
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
	f = frac[:, None, None]
	rows = square[lo] * (1 - f) + square[lo + 1] * f
	f = frac[None, :, None]
	on = rows[:, lo] * (1 - f) + rows[:, lo + 1] * f
	save("AutoIcon", on)
	off = on.copy()
	luma = (on[:, :, :3] * [0.3, 0.59, 0.11]).sum(axis=2) * 0.8
	off[:, :, 0], off[:, :, 1], off[:, :, 2] = luma, luma, luma
	save("AutoIconOff", off)
	print("auto_icon: wrote", SIZE, "px, cut", (left, top, right, bottom))


main()
