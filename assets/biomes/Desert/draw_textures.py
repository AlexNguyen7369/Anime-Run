# Track 7 in-house textures: dust mote particle and a plain dark underground skybox (6 faces).
import os, sys
import numpy as np
from PIL import Image

OUT = sys.argv[1]
os.makedirs(os.path.join(OUT, "sky"), exist_ok=True)
rng = np.random.default_rng(7)

# Dust mote: 128 px soft irregular speck, white on transparent (the emitter tints it)
n = 128
y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
ang = np.arctan2(y, x)
r = np.hypot(x, y) / (0.62 + 0.08 * np.sin(3 * ang + 1.1) + 0.05 * np.sin(5 * ang))
alpha = np.clip(1 - r, 0, 1) ** 1.8
alpha *= 0.85 + 0.15 * rng.random((n, n))
core = np.clip(1 - r * 2.2, 0, 1) ** 2
rgba = np.zeros((n, n, 4))
rgba[..., :3] = 0.85 + 0.15 * core[..., None]
rgba[..., 3] = np.clip(alpha * 0.9 + core * 0.1, 0, 1)
Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "dust_particle.png"))

# Skybox: plain near-black blue-grey, slightly lighter low on the side faces, faint noise; no shapes, no text
s = 1024
base = np.array([0x0E, 0x12, 0x14]) / 255
low = np.array([0x1A, 0x22, 0x24]) / 255
def face(kind):
    if kind == "side":
        t = (np.arange(s) / (s - 1))[:, None, None]  # 0 top .. 1 bottom
        img = base + (low - base) * t ** 2
        img = np.broadcast_to(img, (s, s, 3)).copy()
    elif kind == "up":
        img = np.broadcast_to(base * 0.85, (s, s, 3)).copy()
    else:
        img = np.broadcast_to(low, (s, s, 3)).copy()
    img += (rng.random((s, s, 1)) - 0.5) * (3 / 255)
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
for name, kind in [("Bk", "side"), ("Ft", "side"), ("Lf", "side"), ("Rt", "side"), ("Up", "up"), ("Dn", "down")]:
    face(kind).save(os.path.join(OUT, "sky", f"SkyUnderground{name}.png"))
print("ok")
