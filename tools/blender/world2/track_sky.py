"""World 2 track skies (owner 2026-11-25, design doc change log, owner question 33 "Four tracks"; docs/WORLD2_SPEC.md
"Track skies"): six skybox faces per track, a plain vertical gradient drawn from the approved draft's sky stops. No text,
symbols, logos or shapes; the sun disc is the engine's (CelestialBodiesShown stays on). Offline, standard library only,
no network, deterministic (the same draft gives the same bytes).

The faces reproduce the draft's Blender world (kit.Kit.sky): a colour ramp on the view direction's height, so a stop at
position p sits at elevation asin(p); the ramp mixes in linear light, the world Strength multiplies it and the Standard
view transform writes sRGB (clipped at 1). Below the first stop the first stop's colour holds, above the last the last.

	python3 tools/blender/world2/track_sky.py              # all four tracks, owner's order
	python3 tools/blender/world2/track_sky.py HellGate      # one track (biome key)
	python3 tools/blender/world2/track_sky.py --self-test   # checks only, writes to a temp folder

Writes assets/world2_draft/skies/trackNN_<Key>/W2_<Key>_Sky{Bk,Dn,Ft,Lf,Rt,Up}.png (the four sides are the same image,
so one upload can serve all four, as the plaza's SkyGolden) and manifest.json (stops, strength, sha256 per face).
Previews: tools/blender/world2/track_sky_preview.py (Blender).
"""

import hashlib
import json
import math
import os
import re
import struct
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
DRAFTS = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2")
BIOME_SCRIPTS = os.path.join(HERE, "biomes")
OUT = os.path.join(ROOT, "assets", "world2_draft", "skies")
SIZE = 512  # proposed: a plain gradient needs no more (the plaza's SkyGolden is 512 too)
FACES = ("Bk", "Dn", "Ft", "Lf", "Rt", "Up")
SIDES = ("Bk", "Ft", "Lf", "Rt")
# The owner's four (question 33), in his order: track number, biome key
TRACKS = ((10, "HellGate"), (2, "DemonCastle"), (9, "GoldenCity"), (7, "AntIsland"))


# Proposed softening (owner review round 2026-11-26): Demon Castle's dark below-horizon stop sits 0.7 degrees under its
# bright orange horizon stop, a 1-2 px hard line on a 512 px face; moved 2 degrees down, so the orange meets the dark in a
# band of about 10 px. Nothing at or above the horizon changes, so the sky still matches the draft where it shows.
SOFTEN = {"DemonCastle": {-0.012: -0.035}}


def soften(key, stops):
	moves = SOFTEN.get(key, {})
	assert all(p < 0 for p in moves), "softening only moves stops below the horizon"
	return [(moves.get(p, p), h) for p, h in stops]


def folder(number, key):
	return "track%02d_%s" % (number, key)


# --- draft stops --------------------------------------------------------------------------------------------------


def read_draft(key):
	"""(stops [(position, 'RRGGBB')], strength, ground 'RRGGBB') from src/shared/BiomeThemes/World2/<Key>Draft.luau."""
	with open(os.path.join(DRAFTS, key + "Draft.luau"), encoding="utf-8") as f:
		text = f.read()
	m = re.search(r"\n\tSky = \{\s*Stops = \{(.*?)\},\s*Strength = ([0-9.]+)", text, re.S)
	if not m:
		raise ValueError("no Sky stops in %sDraft.luau" % key)
	stops = [(float(p), h.upper()) for p, h in re.findall(r'\{\s*(-?[0-9.]+),\s*hex\("([0-9A-Fa-f]{6})"\)\s*\}', m.group(1))]
	ground = re.search(r'\n\tGround = \{ Color = hex\("([0-9A-Fa-f]{6})"\)', text)
	if len(stops) < 2 or any(b[0] <= a[0] for a, b in zip(stops, stops[1:])):
		raise ValueError("%s stops not rising: %r" % (key, stops))
	return stops, float(m.group(2)), ground.group(1).upper() if ground else None


def read_script_stops(key):
	"""The same stops from the draft's Blender script (k.sky call), for the cross-check; names like HAZE resolved."""
	with open(os.path.join(BIOME_SCRIPTS, key + ".py"), encoding="utf-8") as f:
		text = f.read()
	m = re.search(r"k\.sky\(\s*\[(.*?)\]\s*,\s*strength=([0-9.]+)", text, re.S)
	if not m:
		raise ValueError("no k.sky call in biomes/%s.py" % key)
	consts = dict(re.findall(r'^([A-Z_]+) = "([0-9A-Fa-f]{6})"', text, re.M))
	stops = []
	for p, q in re.findall(r"\(\s*(-?[0-9.]+),\s*([^)]+?)\s*\)", m.group(1)):
		q = q.strip()
		h = q.strip("\"'") if q[0] in "\"'" else consts.get(q)
		stops.append((float(p), (h or "?").upper()))
	return stops, float(m.group(2))


# --- colour -------------------------------------------------------------------------------------------------------


def to_linear(c):
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(c):
	c = min(max(c, 0.0), 1.0)
	return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_linear(h):
	return tuple(to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4))


class Ramp:
	"""Colour of the draft's sky at an elevation (radians), as 8-bit sRGB. Cached per 1/4096 of the sine."""

	def __init__(self, stops, strength):
		self.pos = [p for p, _ in stops]
		self.lin = [hex_linear(h) for _, h in stops]
		self.strength = strength
		self.cache = {}

	def at_height(self, z):
		"""z = sin(elevation), -1..1"""
		key = round(z * 4096)
		hit = self.cache.get(key)
		if hit is None:
			z = key / 4096
			pos, lin = self.pos, self.lin
			if z <= pos[0]:
				c = lin[0]
			elif z >= pos[-1]:
				c = lin[-1]
			else:
				i = next(i for i in range(1, len(pos)) if z <= pos[i])
				t = (z - pos[i - 1]) / (pos[i] - pos[i - 1])
				c = tuple(a + (b - a) * t for a, b in zip(lin[i - 1], lin[i]))
			hit = tuple(int(round(to_srgb(v * self.strength) * 255)) for v in c)
			self.cache[key] = hit
		return hit


# --- faces --------------------------------------------------------------------------------------------------------


def face_rows(ramp, face, size=SIZE):
	"""Rows top to bottom of one face, each a bytes of RGB. A side face looks along +z with v up; Up and Dn look along
	the vertical axis. Only the height of the view direction matters, so the faces join without a seam whatever their
	turn."""
	rows = []
	for j in range(size):
		v = 1 - (j + 0.5) / size * 2  # top row first
		row = bytearray()
		for i in range(size):
			u = (i + 0.5) / size * 2 - 1
			if face in SIDES:
				x, y, z = u, v, 1.0  # y up
			else:
				x, y, z = u, 1.0 if face == "Up" else -1.0, v
			row += bytes(ramp.at_height(y / math.sqrt(x * x + y * y + z * z)))
		rows.append(bytes(row))
	return rows


def png_bytes(rows, size=SIZE):
	raw = b"".join(b"\x00" + r for r in rows)

	def chunk(kind, data):
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

	return (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


def read_png(path):
	"""(width, height, rows) of an 8-bit RGB PNG written by png_bytes (filter 0 only)."""
	with open(path, "rb") as f:
		data = f.read()
	assert data[:8] == b"\x89PNG\r\n\x1a\n", path
	at, idat, w, h = 8, b"", 0, 0
	while at < len(data):
		(n,) = struct.unpack(">I", data[at : at + 4])
		kind, body = data[at + 4 : at + 8], data[at + 8 : at + 8 + n]
		if kind == b"IHDR":
			w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
			assert depth == 8 and ctype == 2, path
		elif kind == b"IDAT":
			idat += body
		at += 12 + n
	raw = zlib.decompress(idat)
	stride = 1 + w * 3
	rows = []
	for j in range(h):
		line = raw[j * stride : (j + 1) * stride]
		assert line[0] == 0, "filter"
		rows.append(line[1:])
	return w, h, rows


def make(number, key, out_root=OUT, size=SIZE):
	draft_stops, strength, ground = read_draft(key)
	stops = soften(key, draft_stops)
	ramp = Ramp(stops, strength)
	out = os.path.join(out_root, folder(number, key))
	os.makedirs(out, exist_ok=True)
	side = png_bytes(face_rows(ramp, "Bk", size), size)
	images = {"Up": png_bytes(face_rows(ramp, "Up", size), size), "Dn": png_bytes(face_rows(ramp, "Dn", size), size)}
	sums = {}
	for face in FACES:
		data = images.get(face, side)
		name = "W2_%s_Sky%s.png" % (key, face)
		with open(os.path.join(out, name), "wb") as f:
			f.write(data)
		sums[face] = hashlib.sha256(data).hexdigest()
	manifest = {
		"track": number,
		"key": key,
		"ledger_key": "W2_%s_Sky" % key,
		"source": "src/shared/BiomeThemes/World2/%sDraft.luau Sky" % key,
		"stops": stops,
		"draft_stops": draft_stops,
		"strength": strength,
		"ground": ground,
		"size": size,
		"faces": {f: "W2_%s_Sky%s.png" % (key, f) for f in FACES},
		"sha256": sums,
		"note": "Bk, Ft, Lf and Rt are the same image. Not uploaded; renders go to the owner first (owner 2026-11-25).",
	}
	with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as f:
		json.dump(manifest, f, indent=1, sort_keys=True)
		f.write("\n")
	return out, sums


# --- self-test ----------------------------------------------------------------------------------------------------


def self_test():
	fails = []

	def check(ok, what):
		print(("ok   " if ok else "FAIL ") + what)
		if not ok:
			fails.append(what)

	# the ramp itself, on a made-up two-stop sky
	r = Ramp([(0.0, "FF0000"), (1.0, "0000FF")], 1.0)
	check(r.at_height(0) == (255, 0, 0) and r.at_height(1) == (0, 0, 255), "ramp ends are the stops")
	check(r.at_height(-0.5) == (255, 0, 0), "below the first stop holds the first")
	mid = r.at_height(0.5)
	check(mid == (188, 0, 188), "mixes in linear light (0.5 of FF and 00 is BC): %r" % (mid,))
	check(Ramp([(0.0, "808080"), (1.0, "808080")], 5.0).at_height(0.3) == (255, 255, 255), "strength over 1 clips")
	try:
		read_draft("NoSuchTrack")
		check(False, "an unknown track is refused")
	except (OSError, ValueError):
		check(True, "an unknown track is refused")

	# softening: nothing at or over the horizon changes; the step under it is spread over more rows of a 512 px side face
	for key in SOFTEN:
		stops, strength, _ = read_draft(key)
		a, b = Ramp(stops, strength), Ramp(soften(key, stops), strength)
		check(all(a.at_height(k / 4096) == b.at_height(k / 4096) for k in range(0, 4097)), "%s: softening leaves the sky above the horizon alone" % key)

		def worst_step(ramp):
			rows = [ramp.at_height(v / math.sqrt(1 + v * v)) for v in (1 - (j + 0.5) / 256 for j in range(512))]
			return max(max(abs(x - y) for x, y in zip(p, q)) for p, q in zip(rows, rows[1:]))

		before, after = worst_step(a), worst_step(b)
		check(after < before and after <= 40, "%s: softer horizon line (largest row step %d -> %d of 255)" % (key, before, after))
	size = 64
	with tempfile.TemporaryDirectory() as tmp:
		for number, key in TRACKS:
			stops, strength, _ = read_draft(key)
			script, sstrength = read_script_stops(key)
			check(script == stops and sstrength == strength, "%s: draft module and Blender script agree" % key)
			out, a = make(number, key, os.path.join(tmp, "a"), size)
			_, b = make(number, key, os.path.join(tmp, "b"), size)
			check(a == b, "%s: deterministic (same bytes twice)" % key)
			check(len({a[f] for f in SIDES}) == 1, "%s: the four sides are one image" % key)
			faces = {f: read_png(os.path.join(out, "W2_%s_Sky%s.png" % (key, f))) for f in FACES}
			check(all(w == size and h == size for w, h, _ in faces.values()), "%s: %d px faces" % (key, size))
			ramp = Ramp(soften(key, stops), strength)

			def px(face, i, j):
				row = faces[face][2][j]
				return tuple(row[i * 3 : i * 3 + 3])

			def close(p, q, tol=2):
				return all(abs(x - y) <= tol for x, y in zip(p, q))

			# the horizon row of a side, centre column: the colour at the horizon (first stop at or over 0)
			# (the first row above the horizon, at its own height: DemonCastle's stops change fast there)
			j = size // 2 - 1
			v = 1 - (j + 0.5) / size * 2
			want = ramp.at_height(v / math.sqrt(1 + v * v))
			check(close(px("Bk", size // 2, j), want), "%s: just above the horizon is the draft's horizon colour" % key)
			check(close(ramp.at_height(0), Ramp([stops[[p for p, _ in stops].index(min(p for p, _ in stops if p >= 0))]], strength).at_height(0)), "%s: the horizon stop is drawn at the horizon" % key)
			# zenith (Up centre) and nadir (Dn centre)
			check(close(px("Up", size // 2, size // 2), ramp.at_height(1)), "%s: zenith is the top stop" % key)
			check(close(px("Dn", size // 2, size // 2), ramp.at_height(-1)), "%s: nadir is the lowest stop" % key)
			# no seam: a side's top row meets the Up face's edge row, its bottom row the Dn face's
			up_edge = max(max(abs(x - y) for x, y in zip(px("Bk", i, 0), px("Up", i, 0))) for i in range(size))
			dn_edge = max(max(abs(x - y) for x, y in zip(px("Bk", i, size - 1), px("Dn", i, size - 1))) for i in range(size))
			check(up_edge <= 3 and dn_edge <= 3, "%s: no seam at the Up / Dn edges (%d, %d)" % (key, up_edge, dn_edge))
			# no shapes: every face is mirror-symmetric left to right and its colour depends on the elevation only
			sym = all(faces[f][2][j][i * 3 : i * 3 + 3] == faces[f][2][j][(size - 1 - i) * 3 : (size - i) * 3] for f in FACES for j in range(size) for i in range(size // 2))
			check(sym, "%s: faces are plain gradients (mirror-symmetric, no marks)" % key)
			# every pixel's colour lies on the draft's ramp
			palette = {ramp.at_height(k / 4096) for k in range(-4096, 4097)}
			off = sum(1 for f in FACES for row in faces[f][2] for i in range(size) if tuple(row[i * 3 : i * 3 + 3]) not in palette)
			check(off == 0, "%s: every pixel is a colour of the draft's sky (%d off)" % (key, off))
	print("SELF-TEST", "PASS" if not fails else "FAIL (%d)" % len(fails))
	return not fails


def main(argv):
	if "--self-test" in argv:
		return 0 if self_test() else 1
	keys = [a for a in argv if not a.startswith("-")]
	todo = [t for t in TRACKS if not keys or t[1] in keys]
	if keys and len(todo) != len(keys):
		print("unknown track; one of:", ", ".join(k for _, k in TRACKS))
		return 2
	for number, key in todo:
		out, sums = make(number, key)
		print("WROTE", os.path.relpath(out, ROOT), "side", sums["Bk"][:12], "up", sums["Up"][:12], "dn", sums["Dn"][:12])
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
