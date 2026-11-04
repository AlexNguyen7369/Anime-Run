# A soft sakura petal for the plaza's particles and trail, drawn in-house (design doc 4.24).
# Blender -b --factory-startup --python tools/blender/plaza/plaza_petal.py -> assets/biomes/Plaza/Petal.png
import os

import bpy
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "biomes", "Plaza", "Petal.png")
SIZE = 128
c = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
x, y = np.meshgrid(c, c)
# A teardrop: wide near the tip end, narrowing to the stem; soft edge in the alpha
width = 0.62 * np.sqrt(np.clip((1 - y) / 2, 0, 1)) * np.clip((1 + y) * 1.3, 0, 1)
inside = np.clip((width - np.abs(x)) / 0.08, 0, 1)
shade = np.clip(0.55 + 0.45 * (1 - np.abs(x) / 0.62), 0, 1)
px = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
px[:, :, 0] = 1.0
px[:, :, 1] = 0.62 + 0.25 * shade
px[:, :, 2] = 0.78 + 0.15 * shade
px[:, :, 3] = inside
img = bpy.data.images.new("Petal", SIZE, SIZE, alpha=True)
img.pixels.foreach_set(px.ravel())
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
