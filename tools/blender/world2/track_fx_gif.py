#!/usr/bin/env python3
"""World 2 track effects draft: turns build/track_fx/frames/<name>/f*.png (track_fx.py previews) into
assets/world2_draft/track_fx/previews/<name>.gif (12 frames, the effect in motion) and <name>_sheet.jpg (the frames on a
4 x 3 grid), plus overview.jpg (frame 6 of every effect, labelled), for the owner to judge.
	uv run --with pillow python tools/blender/world2/track_fx_gif.py
"""
import glob
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FRAMES = os.path.join(ROOT, "build", "track_fx", "frames")
OUT = os.path.join(ROOT, "assets", "world2_draft", "track_fx", "previews")


def main():
	os.makedirs(OUT, exist_ok=True)
	names = sorted(d for d in os.listdir(FRAMES) if os.path.isdir(os.path.join(FRAMES, d)))
	tiles = []
	for name in names:
		paths = sorted(glob.glob(os.path.join(FRAMES, name, "f*.png")))
		frames = [Image.open(p).convert("RGB").resize((480, 270), Image.LANCZOS) for p in paths]
		pal = [f.convert("P", palette=Image.ADAPTIVE, colors=128) for f in frames]
		pal[0].save(os.path.join(OUT, name + ".gif"), save_all=True, append_images=pal[1:], duration=250, loop=0)
		sheet = Image.new("RGB", (4 * 320, 3 * 180))
		for i, f in enumerate(frames[:12]):
			sheet.paste(f.resize((320, 180), Image.LANCZOS), ((i % 4) * 320, (i // 4) * 180))
		sheet.save(os.path.join(OUT, name + "_sheet.jpg"), quality=82)
		tile = frames[min(6, len(frames) - 1)].resize((320, 180), Image.LANCZOS)
		ImageDraw.Draw(tile).text((6, 4), name, fill=(255, 255, 255))
		tiles.append(tile)
	cols = 4
	rows = (len(tiles) + cols - 1) // cols
	overview = Image.new("RGB", (cols * 320, rows * 180), (20, 20, 24))
	for i, t in enumerate(tiles):
		overview.paste(t, ((i % cols) * 320, (i // cols) * 180))
	overview.save(os.path.join(OUT, "overview.jpg"), quality=85)
	print("previews:", len(names), OUT)


if __name__ == "__main__":
	main()
