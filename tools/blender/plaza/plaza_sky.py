# The plaza's golden-hour skybox, drawn in-house (design doc 4.24): a vertical gradient by true elevation, so the 4 side
# faces join without a seam. Blender -b --factory-startup --python tools/blender/plaza/plaza_sky.py
# Writes assets/biomes/Plaza/sky/SkyGolden{Side,Up,Dn}.png (the same Side image serves Bk, Ft, Lf and Rt).
import os

import bpy
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "biomes", "Plaza", "sky")
SIZE = 512
# elevation in degrees, sRGB: the draft's sky (build_plaza.py setup_world)
STOPS = [(-90, "#E8B98C"), (0, "#FFD9A8"), (6, "#FFC890"), (17, "#F4BFA6"), (40, "#A9B4DC"), (90, "#7E9BD6")]


def ramp(elev):
	xs = [s[0] for s in STOPS]
	cols = np.array([[int(s[1][i : i + 2], 16) / 255 for i in (1, 3, 5)] for s in STOPS])
	return np.stack([np.interp(elev, xs, cols[:, k]) for k in range(3)], axis=-1)


def save(name, elev):
	rgb = ramp(elev)
	px = np.ones((SIZE, SIZE, 4), dtype=np.float32)
	px[:, :, :3] = rgb
	img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
	img.pixels.foreach_set(px.ravel())
	img.filepath_raw = os.path.join(OUT, name + ".png")
	img.file_format = "PNG"
	img.save()


os.makedirs(OUT, exist_ok=True)
coords = (np.arange(SIZE) + 0.5) / SIZE * 2 - 1
u, v = np.meshgrid(coords, coords)  # v runs bottom to top in Blender's pixel order
save("SkyGoldenSide", np.degrees(np.arctan2(v, np.sqrt(1 + u * u))))
save("SkyGoldenUp", np.degrees(np.arctan2(1, np.sqrt(u * u + v * v))))
save("SkyGoldenDn", -np.degrees(np.arctan2(1, np.sqrt(u * u + v * v))))
