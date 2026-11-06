#!/usr/bin/env python3
# Draws assets/ui/dodge_star.png (design doc 4.37): the in-house gold 5-point star of the Dodge bar's burst. White core, so a
# particle's Color or an image's tint can warm it. Blender's Python has numpy, as for draw_raga_wheel.py.
import os
import struct
import zlib

import numpy as np

SIZE, SS = 128, 4
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "ui", "dodge_star.png")
n = SIZE * SS
y, x = np.mgrid[0:n, 0:n]
x = (x + 0.5) / n * 2 - 1
y = (y + 0.5) / n * 2 - 1
angle = np.arctan2(x, -y) % (2 * np.pi / 5)
angle = np.abs(angle - np.pi / 5)
r = np.hypot(x, y)
# Distance past the star's edge: 5 points of radius 0.92, the inner corners at 0.42.
outer, inner = np.array([0, 0.92]), np.array([np.sin(np.pi / 5) * 0.42, np.cos(np.pi / 5) * 0.42])
px, py = r * np.sin(np.pi / 5 - angle), r * np.cos(np.pi / 5 - angle)
edge = (inner - outer) / np.linalg.norm(inner - outer)
normal = np.array([edge[1], -edge[0]])
if normal @ outer < 0:
	normal = -normal
shape = (px - outer[0]) * normal[0] + (py - outer[1]) * normal[1]
GOLD, CORE = np.array((255, 196, 40)), np.array((255, 248, 214))
core = np.clip(-shape / 0.16, 0, 1)[..., None]
rgb = GOLD * (1 - core) + CORE * core
alpha = (shape <= 0).astype(float)
premul = (rgb * alpha[..., None]).reshape(SIZE, SS, SIZE, SS, 3).mean(axis=(1, 3))
coverage = alpha.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))
image = np.dstack([premul / np.maximum(coverage, 1e-6)[..., None], coverage * 255]).round().astype(np.uint8)
raw = b"".join(b"\0" + image[row].tobytes() for row in range(SIZE))


def chunk(kind, data):
	return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


with open(OUT, "wb") as f:
	f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)))
	f.write(chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
print(os.path.normpath(OUT))
