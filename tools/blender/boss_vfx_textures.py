# Big Raga's effect textures, white with the shape in alpha; the emitter's Color tints them (roblox-vfx skill, vfx-textures).
#   Blender -b --factory-startup --python tools/blender/boss_vfx_textures.py
# Blender only for its numpy. Writes assets/characters_avatar/boss_raga/vfx/<name>.png; upload_boss_vfx.py uploads them.
import os
import sys

import numpy

sys.path.insert(0, os.path.expanduser("~/.claude/skills/roblox-vfx/scripts"))
import vfxtex as vt  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
vt.OUTPUT_DIR = os.path.join(ROOT, "assets", "characters_avatar", "boss_raga", "vfx")
os.makedirs(vt.OUTPUT_DIR, exist_ok=True)


def dust(size):
	"""Heavy mottled dust: broken rim, strong light and dark inside, lighter on top."""
	x, y = vt.tex_coords(size)
	wx, wy = vt.tex_warp(x, y, amount=0.12, scale=5, seed=3)
	body = vt.tex_blob(wx, wy, radius=0.62, lumps=11, roughness=0.8, seed=6)
	grit = vt.tex_noise(size, scale=16, octaves=3, seed=9)
	churn = vt.tex_noise(size, scale=5, octaves=5, seed=7)
	alpha = vt.tex_edge(body + (grit - 0.5) * 0.3, soft=0.05)
	return alpha, numpy.clip(0.55 + (churn - 0.5) * 1.8 + 0.15 * y, 0.12, 0.95)


def spark(size):
	"""A lens streak: long, thin, hot middle. Light, so it falls off smoothly and keeps its symmetry."""
	x, y = vt.tex_coords(size)
	fade = numpy.clip(1 - numpy.abs(y), 0, 1)
	return numpy.clip(numpy.exp(-(x / (0.13 * fade + 1e-3)) ** 2) * fade**0.8, 0, 1)


def shard(size):
	"""Broken stone: hard angular chips in two tones."""
	x, y = vt.tex_coords(size)
	rng = numpy.random.default_rng(5)
	angles = numpy.sort(rng.uniform(0, 2 * numpy.pi, 7))
	radii = rng.uniform(0.55, 0.95, 7)
	points = numpy.stack([numpy.cos(angles) * radii, numpy.sin(angles) * radii], 1)
	inside = numpy.ones_like(x)
	lit = numpy.zeros_like(x)
	for i in range(7):
		a, b = points[i], points[(i + 1) % 7]
		side = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])
		inside = numpy.minimum(inside, side)
		lit = numpy.maximum(lit, (side < 0.09) * (i % 2))
	return vt.tex_edge(inside, soft=0.006), 0.55 + 0.45 * lit


def ring(size):
	"""A shock ring: hot rim near the edge, a soft wake behind it, torn by streaks so that it never reads as a hoop."""
	x, y = vt.tex_coords(size)
	r, a = vt.tex_polar(x, y)
	rim = numpy.exp(-(((r - 0.9) / 0.03) ** 2))
	wake = numpy.exp(-((numpy.maximum(0.9 - r, 0) / 0.22) ** 2)) * (r < 0.9) * 0.55
	streaks = vt.tex_sample(vt.tex_noise(256, scale=24, octaves=3, seed=2), numpy.cos(a) * 0.9, numpy.sin(a) * 0.9)
	return numpy.clip((rim + wake * (0.35 + 1.3 * streaks)) * (r < 0.99), 0, 1)


def cracks(size):
	"""Ground cracks: 11 jagged strokes from the centre, each forking, thick at the root."""
	x, y = vt.tex_coords(size)
	rng = numpy.random.default_rng(4)
	field = numpy.full_like(x, -1.0)
	for i in range(11):
		angle = i / 11 * 2 * numpy.pi + rng.uniform(-0.2, 0.2)
		steps = numpy.linspace(0.14, rng.uniform(0.7, 0.97), 9)
		wander = numpy.cumsum(rng.uniform(-0.3, 0.3, 9)) * 0.2
		points = numpy.stack([numpy.cos(angle + wander) * steps, numpy.sin(angle + wander) * steps], 1)
		root = rng.uniform(0.022, 0.034)
		field = numpy.maximum(field, vt.tex_stroke(x, y, points, [root, root * 0.6, 0.0]))
		for _ in range(2):
			fork = points[rng.integers(2, 6)]
			turn = angle + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
			tip = fork + numpy.array([numpy.cos(turn), numpy.sin(turn)]) * rng.uniform(0.12, 0.28)
			kink = (fork + tip) / 2 + rng.uniform(-0.03, 0.03, 2)
			field = numpy.maximum(field, vt.tex_stroke(x, y, numpy.stack([fork, kink, tip]), [root * 0.5, 0.0]))
	return vt.tex_edge(field, soft=0.003)


def flare(size):
	"""An eight-ray flare, like the wheel's eight handles, from one hot core."""
	x, y = vt.tex_coords(size)
	r, a = vt.tex_polar(x, y)
	rays = (numpy.abs(numpy.cos(a * 4)) ** 24) * numpy.clip(1 - r, 0, 1) ** 1.3
	return numpy.clip(rays + numpy.exp(-((r / 0.14) ** 2)) + 0.35 * numpy.exp(-((r / 0.42) ** 2)), 0, 1) * (r < 1)


def shaft(size):
	"""A soft block of light for beams: same falloff along both axes, so it does not matter which way a Beam maps it."""
	x, y = vt.tex_coords(size)
	return numpy.clip((1 - numpy.abs(x) ** 2.4) * (1 - numpy.abs(y) ** 8), 0, 1) ** 1.5


for name, draw, size in (("Dust", dust, 512), ("Spark", spark, 256), ("Shard", shard, 256), ("Ring", ring, 1024), ("Cracks", cracks, 1024), ("Flare", flare, 512), ("Shaft", shaft, 256)):
	print("TEX", vt.draw_texture(name, draw, size=size))
