# Track 7 fight scene particle and beam textures (in-house, numpy). Run: python3 draw_fight_textures.py <out dir>
# White or near-white on transparent; the emitters and beams tint them. No shapes beyond dots, streaks and petals.
import os
import sys

import numpy as np
from PIL import Image

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(71)


def grid(n):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    return x, y


def save(name, rgb, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.dstack([np.clip(rgb, 0, 1) * np.ones_like(a)[..., None], a])
    Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))


# 1. star dot: a tiny soft white dot with a faint four-point glint
n = 64
x, y = grid(n)
r = np.hypot(x, y)
dot = np.exp(-((r / 0.18) ** 2))
glint = np.exp(-((x / 0.05) ** 2)) * np.exp(-((y / 0.6) ** 2)) + np.exp(-((y / 0.05) ** 2)) * np.exp(-((x / 0.6) ** 2))
save("fight_star.png", np.ones(3), dot + 0.35 * glint)

# 2. galaxy streak: a smeared spiral band of tiny stars (white; the emitter tints it blue to violet)
n = 256
x, y = grid(n)
r, th = np.hypot(x, y), np.arctan2(y, x)
band = np.exp(-(((r - 0.55 - 0.12 * np.sin(2 * th)) / 0.12) ** 2)) * np.clip(1 - r, 0, 1) ** 0.5
band *= 0.5 + 0.5 * np.sin(th * 2 + r * 6) ** 2
stars = (rng.random((n, n)) > 0.985) * rng.random((n, n))
save("fight_galaxy.png", np.ones(3), 0.7 * band + stars * band * 2)

# 3. light streak for the beams: soft white band across, fading at both ends (U along the beam)
w, h = 256, 64
u = np.linspace(-1, 1, w)[None, :]
v = np.linspace(-1, 1, h)[:, None]
streak = np.exp(-((v / 0.35) ** 2)) * np.clip(1 - np.abs(u) ** 3, 0, 1)
Image.fromarray(
    (np.dstack([np.ones((h, w, 3)), np.clip(streak, 0, 1)[..., None]]) * 255).astype(np.uint8), "RGBA"
).save(os.path.join(OUT, "fight_beam.png"))

# 4. petal: one five-petal pale flower (white; tinted pale pink)
n = 128
x, y = grid(n)
r, th = np.hypot(x, y), np.arctan2(y, x)
edge = 0.55 + 0.35 * np.abs(np.cos(2.5 * th))
petal = np.clip((edge - r) / 0.06, 0, 1)
centre = np.exp(-((r / 0.15) ** 2))
save("fight_petal.png", np.ones(3) * 0.95, petal * 0.95 + centre * 0.05)

# 5. droplet: a round deep-red-ready droplet with a white highlight (white body tinted red by the emitter; the
# highlight stays near white because the tint multiplies a lighter value less)
n = 128
x, y = grid(n)
body = np.clip((0.7 - np.hypot(x, (y + 0.1) * 1.1)) / 0.05, 0, 1)
tip = np.clip((0.35 - np.hypot(x * 2.2, y + 0.6)) / 0.05, 0, 1) * (y < -0.2)
alpha = np.clip(body + tip, 0, 1)
hl = np.exp(-(((x + 0.25) / 0.12) ** 2 + ((y + 0.05) / 0.16) ** 2))
rgb = (0.55 + 0.45 * hl)[..., None] * np.ones(3)
save("fight_droplet.png", rgb, alpha)
print("ok")
