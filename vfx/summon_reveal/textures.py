"""Original textures for Client/SidekickReveal. White shapes in alpha: ImageColor3 tints them.

Run with a Python that has numpy, for example Blender's:
  /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 vfx/summon_reveal/textures.py
"""
import math
import os
import sys

import numpy

sys.path.insert(0, os.path.expanduser("~/.claude/skills/roblox-vfx/scripts"))
import vfxtex as vt

vt.OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


def smooth(low, high, value):
    t = numpy.clip((value - low) / (high - low), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vortex(t, size):
    """Three spiral arms turning inward, for the charge. Loops."""
    x, y = vt.tex_coords(size)
    r, angle = vt.tex_polar(x, y)
    wave = numpy.sin(3.0 * (angle + 2.6 * numpy.log(r + 0.08)) + 2.0 * math.pi * t)
    arms = smooth(0.15, 0.75, wave)
    return arms * smooth(1.0, 0.72, r) * smooth(0.05, 0.22, r)


def speed_lines(t, size):
    """Comic focus lines around an empty middle: a new random set each frame, so they flicker."""
    x, y = vt.tex_coords(size)
    r, angle = vt.tex_polar(x, y)
    rng = numpy.random.default_rng(int(round(t * 4)) + 11)
    alpha = numpy.zeros((size, size), dtype=numpy.float32)
    for _ in range(62):
        at = rng.uniform(-math.pi, math.pi)
        inner = rng.uniform(0.5, 0.86)
        width = rng.uniform(0.012, 0.042)
        offset = numpy.abs(numpy.arctan2(numpy.sin(angle - at), numpy.cos(angle - at)))
        # The line narrows to a point at its inner end.
        spread = width * numpy.clip((r - inner) / (1.42 - inner), 0.0, 1.0)
        alpha = numpy.maximum(alpha, vt.tex_edge(spread - offset, soft=0.003) * (r > inner))
    # Soft outer end, so the square image never shows its edge.
    return alpha * smooth(1.0, 0.82, r)


def impact(t, size):
    """A lopsided comic burst: grows fast, then breaks apart."""
    x, y = vt.tex_coords(size)
    r, angle = vt.tex_polar(x, y)
    rng = numpy.random.default_rng(5)
    spikes = 11
    reach = rng.uniform(0.45, 1.0, spikes)
    at = numpy.sort(rng.uniform(-math.pi, math.pi, spikes))
    outline = numpy.full((size, size), 0.28, dtype=numpy.float32)
    for tip, length in zip(at, reach):
        off = numpy.abs(numpy.arctan2(numpy.sin(angle - tip), numpy.cos(angle - tip)))
        outline = numpy.maximum(outline, length * numpy.clip(1.0 - off / 0.26, 0.0, 1.0))
    grow = vt.tex_ease(min(t / 0.3, 1.0))
    shape = vt.tex_edge(outline * grow * 0.96 - r, soft=0.008)
    if t > 0.3:
        eaten = (t - 0.3) / 0.7
        noise = vt.tex_noise(size, scale=5, octaves=3, seed=3)
        hole = smooth(0.0, 1.0, r / max(0.01, eaten * 1.1))
        shape = shape * (noise > eaten * 0.95) * hole
    return shape


def shock_ring(t, size):
    """An even soft ring that races out and thins."""
    x, y = vt.tex_coords(size)
    r, _ = vt.tex_polar(x, y)
    radius = 0.12 + 0.82 * vt.tex_ease(t)
    width = 0.09 * (1.0 - t) + 0.008
    return numpy.exp(-(((r - radius) / width) ** 2)) * (1.0 - t) ** 0.8 * smooth(1.0, 0.94, r)


def flare(size):
    """A four-point glint with one hot core."""
    x, y = vt.tex_coords(size)
    arms = numpy.exp(-numpy.abs(y) / 0.018) * numpy.clip(1.0 - numpy.abs(x), 0.0, 1.0) ** 2
    arms = numpy.maximum(arms, numpy.exp(-numpy.abs(x) / 0.018) * numpy.clip(1.0 - numpy.abs(y), 0.0, 1.0) ** 2)
    core = numpy.exp(-(numpy.hypot(x, y) / 0.2) ** 2)
    return numpy.clip(arms + core, 0.0, 1.0)


def glow(size):
    """A round soft light."""
    x, y = vt.tex_coords(size)
    r = numpy.hypot(x, y)
    return numpy.clip(1.0 - r, 0.0, 1.0) ** 2


def rays(size):
    """Straight rays of uneven length from one hot centre."""
    x, y = vt.tex_coords(size)
    r, angle = vt.tex_polar(x, y)
    rng = numpy.random.default_rng(9)
    alpha = numpy.zeros((size, size), dtype=numpy.float32)
    for _ in range(26):
        at = rng.uniform(-math.pi, math.pi)
        length = rng.uniform(0.55, 1.0)
        width = rng.uniform(0.03, 0.1)
        off = numpy.abs(numpy.arctan2(numpy.sin(angle - at), numpy.cos(angle - at)))
        ray = numpy.exp(-((off / width) ** 2)) * numpy.clip(1.0 - r / length, 0.0, 1.0) ** 0.7
        alpha = numpy.maximum(alpha, ray * rng.uniform(0.5, 1.0))
    return alpha


if __name__ == "__main__":
    vt.draw_flipbook("summon_vortex", vortex, grid=4, loop=True, fps=18)
    vt.draw_flipbook("summon_speedlines", speed_lines, grid=2, loop=True, fps=14)  # 512 px frames: no visible pixels
    vt.draw_flipbook("summon_impact", impact, grid=4, fps=30)
    vt.draw_flipbook("summon_ring", shock_ring, grid=4, fps=30)
    vt.draw_texture("summon_flare", flare, size=256)
    vt.draw_texture("summon_glow", glow, size=256)
    vt.draw_texture("summon_rays", rays, size=512)
