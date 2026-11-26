#!/usr/bin/env python3
"""World 2 track effects (draft, owner approval pending): particle textures drawn in-house with numpy.

docs/WORLD2_SPEC.md "Track effects (draft, owner approval pending)". White on transparency, so each emitter's Color
tints them per biome. Drawn with the roblox-vfx skill's vfxtex helpers (drawn matter: crisp cel edges, holes that grow
and break the shape apart), never a soft grey smudge.

Run from the repo root:
    uv run --with numpy --with pillow python tools/blender/world2/track_fx_textures.py
Writes assets/world2_draft/track_fx/textures/ (the only files that would ever be uploaded) and a review sheet in
assets/world2_draft/track_fx/previews/ (never uploaded).
"""
import os
import sys

import numpy

SKILL = os.path.expanduser("~/.claude/skills/roblox-vfx/scripts")
sys.path.insert(0, SKILL)
import vfxtex as vt  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "world2_draft", "track_fx", "textures")
PREVIEWS = os.path.join(ROOT, "assets", "world2_draft", "track_fx", "previews")
vt.OUTPUT_DIR = OUT

NOISE = vt.tex_noise(256, scale=6, seed=11)
BILLOWS = vt.tex_noise(256, scale=5, octaves=5, seed=12)
GRIT = vt.tex_noise(256, scale=14, octaves=3, seed=13)


# Smoke puff (one-shot over a particle's life): a lumpy cel-shaded billow with a lit top and a shadow underside,
# swelling, then torn by growing holes into a few rags. Used by every column, plume and rubble smoke.
def smoke_puff(t, size):
	x, y = vt.tex_coords(size)
	wx, wy = vt.tex_warp(x, y, amount=0.09, scale=4, seed=21, t=t * 0.4)
	radius = 0.3 + 0.3 * vt.tex_ease(t * 1.8) + 0.04 * t
	body = vt.tex_blob(wx, wy, radius=radius, lumps=10, roughness=0.78, seed=22)
	lit = vt.tex_blob(wx + 0.07, wy - 0.12, radius=radius * 0.97, lumps=10, roughness=0.78, seed=22)
	rim = body + (vt.tex_sample(GRIT, x * 0.8 + t * 0.2, y * 0.8) - 0.5) * 0.18
	holes = vt.tex_sample(NOISE, x * 0.5 + 0.3, y * 0.5 - t * 0.25) - t ** 1.3 * 1.55 + 0.78
	alpha = vt.tex_edge(rim, soft=0.008) * vt.tex_edge(holes + body * 0.35, soft=0.012)
	churn = vt.tex_sample(BILLOWS, x * 0.6 + t * 0.25, y * 0.6 - t * 0.4)
	value = 0.52 + 0.4 * vt.tex_edge(lit, 0.03, soft=0.008) + (churn - 0.5) * 0.25
	return alpha, numpy.clip(value, 0.3, 1.0)


# Wisp (one-shot): a thin curling strand that draws on from its root, sways, then frays from the root up.
# Chimney smoke, roof-vent steam, corpse steam.
WISP = vt.tex_curve([(0.05, -0.78), (-0.12, -0.38), (0.14, -0.02), (-0.1, 0.34), (0.08, 0.7)])


def wisp(t, size):
	x, y = vt.tex_coords(size)
	sway = 0.12 * numpy.sin(y * 3.2 + t * 4.0) * (y + 1) * 0.5
	wx, wy = vt.tex_warp(x - sway, y, amount=0.05, scale=3, seed=31, t=t * 0.5)

	def width(u):
		return (0.13 + 0.2 * u) * numpy.sin(numpy.clip(u * 6, 0, 1) * numpy.pi / 2) * (1 - 0.35 * t)

	strand = vt.tex_stroke(wx, wy, WISP, width, start=numpy.clip((t - 0.35) * 1.4, 0, 0.95), end=0.2 + 0.8 * vt.tex_ease(t * 2.5))
	holes = vt.tex_sample(NOISE, x * 0.7, y * 0.5 - t * 0.6) - t * 0.9 + 0.62
	alpha = vt.tex_edge(strand, soft=0.01) * vt.tex_edge(holes + strand * 0.5, soft=0.02)
	return alpha, numpy.clip(0.7 + 0.3 * (y + 1) * 0.5, 0, 1)


# Haze (single texture): a wide low bank of mist, soft-edged but with a lumpy top line, for ground mist. Squashed wide by
# the emitter; low opacity. Light, not drawn matter: the edges fall off softly.
def haze(size):
	x, y = vt.tex_coords(size)
	top = 0.15 + 0.22 * vt.tex_sample(BILLOWS, x * 0.4 + 0.1, numpy.zeros_like(x) + 0.37)
	vertical = numpy.clip((top - y) / 0.5, 0, 1) * numpy.clip((y + 0.75) / 0.35, 0, 1)
	sides = numpy.clip((1 - numpy.abs(x)) / 0.45, 0, 1)
	inner = 0.75 + 0.25 * vt.tex_sample(BILLOWS, x * 0.9, y * 0.9 + 0.2)
	alpha = numpy.clip(vertical * sides * inner, 0, 1) ** 1.2
	rgba = numpy.zeros((size, size, 4))
	rgba[..., :3] = 1.0
	rgba[..., 3] = alpha
	return rgba


# Ember (single texture): a hot core with a soft halo; light keeps its symmetry. Embers, gold motes.
def ember(size):
	x, y = vt.tex_coords(size)
	r, _ = vt.tex_polar(x, y)
	core = numpy.clip(1 - r / 0.22, 0, 1) ** 1.5
	halo = numpy.clip(1 - r / 0.9, 0, 1) ** 3 * 0.55
	rgba = numpy.zeros((size, size, 4))
	rgba[..., :3] = 1.0
	rgba[..., 3] = numpy.clip(core + halo, 0, 1)
	return rgba


def main():
	os.makedirs(OUT, exist_ok=True)
	os.makedirs(PREVIEWS, exist_ok=True)
	vt.draw_flipbook("TrackFx_SmokePuff", smoke_puff, grid=4, mode="alpha")
	vt.draw_flipbook("TrackFx_Wisp", wisp, grid=4, mode="alpha")
	vt.draw_texture("TrackFx_Haze", haze, size=512)
	vt.draw_texture("TrackFx_Ember", ember, size=128)
	names = ["TrackFx_SmokePuff.flipbook.png", "TrackFx_Wisp.flipbook.png", "TrackFx_Haze.png", "TrackFx_Ember.png"]
	paths = [os.path.join(OUT, n) for n in names]
	for p in paths[:2]:
		vt.check(p)
	vt.review(paths, out=os.path.join(PREVIEWS, "textures_review.png"))


if __name__ == "__main__":
	main()
