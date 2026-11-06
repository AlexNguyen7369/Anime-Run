#!/usr/bin/env python3
# Draws assets/ui/raga_wheel.png (design doc 4.37, 4.38): in-house digital art of Big Raga's wheel, on the shape of raga_wheel in
# build_boss_event.py. Blender's Python has numpy:
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_raga_wheel.py
import os
import struct
import zlib

import numpy as np

SIZE, SS = 512, 3
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "..", "assets", "ui", "raga_wheel.png")

n = SIZE * SS
y, x = np.mgrid[0:n, 0:n]
# Model units: the wheel reaches 1.51 from its hub, plus outline and margin.
x = (x + 0.5) / n * 3.5 - 1.75
y = (y + 0.5) / n * 3.5 - 1.75
r = np.hypot(x, y)


def ring(radius, half):
	return np.abs(r - radius) - half


def spoke(angle, start, end, half):
	dx, dy = np.cos(angle), np.sin(angle)
	along = x * dx + y * dy
	across = np.abs(-x * dy + y * dx)
	return np.maximum.reduce([across - half, start - along, along - end])


def octagon(cx, cy, radius):
	px, py = np.abs(x - cx), np.abs(y - cy)
	return np.maximum.reduce([px, py, (px + py) * np.sqrt(0.5)]) - radius


parts = [ring(1.02, 0.1), ring(0.5, 0.07), octagon(0, 0, 0.24)]
for i in range(8):
	a = np.pi * i / 4 + np.pi / 8
	parts.append(spoke(a, 0.05, 1.3, 0.065))
	parts.append(octagon(1.34 * np.cos(a), 1.34 * np.sin(a), 0.19))
shape = np.minimum.reduce(parts)

OUTLINE = 0.055
GOLD_HI, GOLD, GOLD_LOW, INK = [np.array(c) for c in ((255, 236, 150), (250, 197, 72), (203, 128, 30), (58, 34, 14))]
# Flat cel bevel, lit from the top left: each part's edge band takes the highlight or the shadow by the way it faces.
grad_y, grad_x = np.gradient(shape)
facing = -(grad_x + grad_y) / np.maximum(np.hypot(grad_x, grad_y), 1e-9) / np.sqrt(2)
edge = shape > -0.042
rgb = np.broadcast_to(GOLD, (n, n, 3))
rgb = np.where((edge & (facing > 0.1))[..., None], GOLD_HI, rgb)
rgb = np.where((edge & (facing <= 0.1))[..., None], GOLD_LOW, rgb)
rgb = np.where((shape > 0)[..., None], INK, rgb)
alpha = (shape <= OUTLINE).astype(float)

# Box-filter down, weighted by alpha so the ink never fringes.
premul = (rgb * alpha[..., None]).reshape(SIZE, SS, SIZE, SS, 3).mean(axis=(1, 3))
coverage = alpha.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))
safe = np.maximum(coverage, 1e-6)[..., None]
image = np.dstack([premul / safe, coverage * 255]).round().astype(np.uint8)

raw = b"".join(b"\0" + image[row].tobytes() for row in range(SIZE))


def chunk(kind, data):
	return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


with open(OUT, "wb") as f:
	f.write(b"\x89PNG\r\n\x1a\n")
	f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)))
	f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
	f.write(chunk(b"IEND", b""))
print(os.path.normpath(OUT))
