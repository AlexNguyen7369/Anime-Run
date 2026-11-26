"""Previews of the World 2 track skies (docs/WORLD2_SPEC.md "Track skies") for the owner, before any upload.
Reads the faces track_sky.py wrote and, per track, writes into assets/world2_draft/skies/trackNN_<Key>/:
  equirect.png      the six faces put back together as a 360 x 180 degree panorama (checks the cube's layout and seams)
  studio_sky.png    the track's Studio picture of 2026-11-25 (assets/world2_draft/audit/lighting_2026-11-25/T<N>_road.jpg,
                    the default blue sky) with its sky pixels (and the default sky's pale band over the horizon) replaced
                    by the new sky at each row's elevation (vertical FOV 70, the camera taken as level at the picture's
                    horizon), and the fog band under the horizon recoloured by the change of the fog colours (Kit WithSky).
                    Approximate: a picture edit, not the engine; the sun disc is the engine's. Only where a picture exists
                    (none for Track 2).
  studio_sky_dusk.png  Ant Island only: the same with its scenery regraded from today's light to its SkyLook (exposure,
                    outdoor light, tint, saturation; the lower sun's shadows are not redone)
  game_view.png     where there is no Studio picture: a level view (FOV 70) of the new sky over flat ground of the draft's
                    ground colour
  preview.png       one board: Studio now | Studio with the new sky (Ant Island: and its dusk light; Track 2: the game
                    view) / the approved draft render | the panorama
And checks the faces against the draft's own Blender world (kit.Kit.sky): a Cycles panorama of that world, compared
pixel by pixel with equirect.png (printed as SKYCHECK lines; drawn the same way, the difference should be a few levels).
Offline. Headless:
  nice blender -b --factory-startup --python tools/blender/world2/track_sky_preview.py -- [Key ...]
"""

import json
import math
import os
import sys
import tempfile

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kit  # noqa: E402
import track_sky as ts  # noqa: E402

AUDIT = os.path.join(ts.ROOT, "assets", "world2_draft", "audit", "lighting_2026-11-25")
DRAFT_SHOT = "02_run_33.jpg"
W, H = 960, 540  # board panel
FOV = 70  # Roblox's default vertical field of view


def load(path):
	"""float sRGB array [rows top first, cols, 3] of an image file"""
	img = bpy.data.images.load(path, check_existing=False)
	w, h = img.size
	px = np.empty(w * h * 4, dtype=np.float32)
	img.pixels.foreach_get(px)
	bpy.data.images.remove(img)
	return px.reshape(h, w, 4)[::-1, :, :3].copy()


def save(arr, path):
	h, w = arr.shape[:2]
	img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
	px = np.ones((h, w, 4), dtype=np.float32)
	px[:, :, :3] = np.clip(arr[::-1], 0, 1)
	img.pixels.foreach_set(px.ravel())
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	bpy.data.images.remove(img)


def fit(arr, w=W, h=H):
	"""nearest resize into w x h, letterboxed on black"""
	ih, iw = arr.shape[:2]
	s = min(w / iw, h / ih)
	nw, nh = max(1, int(iw * s)), max(1, int(ih * s))
	ys = np.minimum((np.arange(nh) / s).astype(int), ih - 1)
	xs = np.minimum((np.arange(nw) / s).astype(int), iw - 1)
	out = np.zeros((h, w, 3), dtype=np.float32)
	oy, ox = (h - nh) // 2, (w - nw) // 2
	out[oy : oy + nh, ox : ox + nw] = arr[ys][:, xs]
	return out


class Cube:
	"""Samples the six faces by view direction (x right, y up, z forward)."""

	def __init__(self, folder, key):
		self.faces = {f: load(os.path.join(folder, "W2_%s_Sky%s.png" % (key, f))) for f in ts.FACES}
		self.n = self.faces["Up"].shape[0]

	def sample(self, x, y, z):
		ax, ay, az = np.abs(x), np.abs(y), np.abs(z)
		out = np.zeros(x.shape + (3,), dtype=np.float32)
		vert = (ay >= ax) & (ay >= az)
		n = self.n

		def put(mask, face, u, v):
			i = np.clip(((u + 1) / 2 * n).astype(int), 0, n - 1)
			j = np.clip(((1 - v) / 2 * n).astype(int), 0, n - 1)
			out[mask] = self.faces[face][j[mask], i[mask]]

		with np.errstate(divide="ignore", invalid="ignore"):
			put(vert & (y > 0), "Up", x / ay, z / ay)
			put(vert & (y <= 0), "Dn", x / ay, z / ay)
			sx = ~vert & (ax >= az)
			put(sx & (x > 0), "Rt", -z / ax, y / ax)
			put(sx & (x <= 0), "Lf", z / ax, y / ax)
			sz = ~vert & (az > ax)
			put(sz & (z > 0), "Ft", x / az, y / az)
			put(sz & (z <= 0), "Bk", -x / az, y / az)
		return out

	def equirect(self, w=1024, h=512):
		lon = (np.arange(w) + 0.5) / w * 2 * math.pi - math.pi
		lat = math.pi / 2 - (np.arange(h) + 0.5) / h * math.pi
		lon, lat = np.meshgrid(lon, lat)
		return self.sample(np.cos(lat) * np.sin(lon), np.sin(lat), np.cos(lat) * np.cos(lon))

	def at_elevation(self, elev):
		"""colour per elevation (radians), looking forward"""
		return self.sample(np.zeros_like(elev), np.sin(elev), np.cos(elev))


def game_view(cube, ground_hex, key, w=W, h=H):
	f = (h / 2) / math.tan(math.radians(FOV / 2))
	j = np.arange(h) + 0.5
	i = np.arange(w) + 0.5
	ii, jj = np.meshgrid(i, j)
	x, y, z = (ii - w / 2) / f, (h * 0.55 - jj) / f, np.ones_like(ii)  # horizon a little above the middle
	n = np.sqrt(x * x + y * y + z * z)
	sky = cube.sample(x / n, y / n, z / n)
	g = np.array([int(ground_hex[k : k + 2], 16) / 255 for k in (0, 2, 4)], dtype=np.float32)
	horizon = fog_colours(key)[1][0]  # the fog's colour while the sky shows (Kit WithSky)
	dist = np.where(y < 0, 12 / np.maximum(-y / np.sqrt(x * x + z * z), 1e-4), 0)  # eye 12 studs over flat ground
	fog = (1 - np.exp(-dist / 1500))[..., None]  # proposed look only: ground fades to the horizon colour
	ground = g * (1 - fog) + horizon * fog
	return np.where((y < 0)[..., None], ground, sky)


def hexf(h):
	return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def fog_colours(key):
	"""(old, new) fog (Atmosphere Color, Decay) of a track, as Kit.fromDraft makes them: old = the draft's horizon stop and
	the stop two above it; new (while its sky shows) = the drawn sky at the horizon and about 2 degrees up. sRGB 0..1."""
	stops, strength, _ = ts.read_draft(key)
	first = next(i for i, (p, _) in enumerate(stops) if p >= 0)
	old = (hexf(stops[first][1]), hexf(stops[min(first + 2, len(stops) - 1)][1]))
	ramp = ts.Ramp(ts.soften(key, stops), strength)
	new = (np.array(ramp.at_height(0), np.float32) / 255, np.array(ramp.at_height(0.035), np.float32) / 255)
	return old, new


def studio_with_sky(cube, shot, key):
	"""The Studio picture with its default sky replaced by the new sky at each row's elevation, and its fog band (the far
	ground in haze just under the horizon) recoloured by the change of the fog colours. Approximate: a picture edit, not
	the engine."""
	h, w = shot.shape[:2]
	r, g, b = shot[..., 0], shot[..., 1], shot[..., 2]
	blue = (b > r + 0.1) & (b > g) & (b > 0.55)  # the bright blue default sky; dark navy scenery stays
	rows = blue.mean(axis=1)
	sky_rows = np.nonzero(rows > 0.03)[0]  # a narrow street gap still counts
	horizon = int(sky_rows.max()) + 1 if len(sky_rows) else h // 2
	f = (h / 2) / math.tan(math.radians(FOV / 2))
	elev = np.arctan((horizon - (np.arange(h) + 0.5)) / f)
	colour = cube.at_elevation(np.maximum(elev, 0))  # [h, 3]; just under the line the horizon colour
	# soft edge: how far past the blue threshold a pixel is (anti-aliased outlines blend)
	alpha = np.clip((b - r - 0.04) / 0.12, 0, 1) * (b > 0.45) * (b >= g - 0.02)
	# the default sky's pale band over the horizon: light, weakly coloured pixels
	band = np.zeros(h, bool)
	band[max(0, horizon - 60) : horizon + 2] = True
	sat = shot.max(axis=2) - shot.min(axis=2)
	pale = (sat < 0.25) & (shot.mean(axis=2) > 0.42) & band[:, None]
	alpha = np.maximum(alpha, pale.astype(np.float32))
	alpha[horizon + 2 :] = 0
	out = shot * (1 - alpha[..., None]) + colour[:, None, :] * alpha[..., None]

	# Where the far ground shows as an even fog band across the picture (Track 10's plain), the old sky faded into it
	# over a few rows under the horizon: that fade now runs from the new sky's horizon colour into the fog, recoloured by
	# the change of the fog colours (Kit WithSky). Where scenery hides it (Tracks 7 and 9), nothing is done there.
	def even(j):
		m = np.median(shot[j], axis=0)
		return m, (np.abs(shot[j] - m).max(axis=1) < 0.06).mean()

	(old_c, old_d), (new_c, new_d) = fog_colours(key)
	gain = (new_c + new_d) / np.maximum(old_c + old_d, 1e-3)
	fog_start, fog_rows = None, 0
	for j in range(horizon, min(h - 7, horizon + 60)):
		m, frac = even(j)
		if frac > 0.8 and np.abs(m - even(j + 6)[0]).max() < 0.02:
			fog_start = j
			break
	if fog_start is not None:
		ref = even(fog_start)[0]
		j = fog_start
		while j < min(h, fog_start + 150):
			m, frac = even(j)
			if frac < 0.5 or np.abs(m - ref).max() > 0.2:
				break
			near = np.abs(shot[j] - m).max(axis=1) < 0.15
			out[j, near] = np.clip(shot[j, near] * gain, 0, 1)
			j += 1
		fog_rows = j - fog_start
		fog_new = np.clip(ref * gain, 0, 1)
		top = colour[horizon - 1]
		for j in range(horizon, fog_start):
			near = shot[j].mean(axis=1) > 0.25  # the fade itself (the doors' dark tops stay)
			t = (j - horizon + 0.5) / (fog_start - horizon)
			out[j, near] = top * (1 - t) + fog_new * t
			alpha[j, near] = 1
	return out, horizon, alpha, fog_rows


# Ant Island's light under its sky (themes SkyLook) against today's, for a picture regrade; game values (world2_skies)
ANT_LIGHT = {
	"old": {"Brightness": 1.44, "Outdoor": "997966", "Sun": "FFB070", "Exposure": 0.0, "Tint": 0.15, "Saturation": 0.18},
	"new": {"Brightness": 1.4, "Outdoor": "A37D6D", "Sun": "FFB070", "Exposure": -0.3, "Tint": 0.3, "Saturation": -0.1},
}


def regrade(pic, keep, look):
	"""A rough picture regrade of lit scenery from one light to another (sun x Brightness + outdoor ambient, exposure,
	tint, saturation). The lower sun's shadows are not redone. keep: per-pixel weight of pixels to leave (the sky)."""

	def light(v):
		sun = hexf(v["Sun"])
		tint = 1 + (sun - 1) * v["Tint"]
		return (v["Brightness"] * sun * 0.5 + hexf(v["Outdoor"])) * 2 ** v["Exposure"] * tint

	old, new = look["old"], look["new"]
	gain = light(new) / light(old)
	out = np.clip(pic * gain, 0, 1)
	lum = out.mean(axis=2, keepdims=True)
	out = lum + (out - lum) * (1 + new["Saturation"]) / (1 + old["Saturation"])
	k = keep[..., None]
	return pic * k + np.clip(out, 0, 1) * (1 - k)


def draft_world_panorama(key, w=256, h=128):
	"""The draft's own Blender world (kit.Kit.sky, no sun), rendered by Cycles as a panorama: the reference."""
	stops, strength, _ = ts.read_draft(key)
	scene = bpy.context.scene
	for ob in list(bpy.data.objects):
		bpy.data.objects.remove(ob)

	class Stub:
		biome = key
		col = scene.collection

	kit.Kit.sky(Stub(), [(p, h_) for p, h_ in stops], strength)
	cam = bpy.data.objects.new("Pano", bpy.data.cameras.new("Pano"))
	scene.collection.objects.link(cam)
	scene.camera = cam
	cam.rotation_euler = (math.radians(90), 0, 0)  # level, looking along +Y
	scene.render.engine = "CYCLES"
	cam.data.type = "PANO"
	try:
		cam.data.panorama_type = "EQUIRECTANGULAR"
	except (AttributeError, TypeError):
		cam.data.cycles.panorama_type = "EQUIRECTANGULAR"
	scene.cycles.samples = 4
	scene.cycles.device = "CPU"
	scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = w, h, 100
	scene.render.filter_size = 0.01
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "PNG"
	with tempfile.TemporaryDirectory() as tmp:
		path = os.path.join(tmp, "pano.png")
		scene.render.filepath = path
		bpy.ops.render.render(write_still=True)
		return load(path)


def run(number, key):
	folder = os.path.join(ts.OUT, ts.folder(number, key))
	cube = Cube(folder, key)
	with open(os.path.join(folder, "manifest.json"), encoding="utf-8") as f:
		manifest = json.load(f)
	pano = cube.equirect()
	save(pano, os.path.join(folder, "equirect.png"))

	ref = draft_world_panorama(key)
	ours = cube.equirect(ref.shape[1], ref.shape[0])
	diff = np.abs(ref - ours) * 255
	band = slice(4, ref.shape[0] // 2)  # the sky over the horizon (softening only moves stops under it); poles' rows skipped
	print(
		"SKYCHECK %s mean %.2f p99 %.1f max %.1f (0-255, over the horizon, our faces vs the draft's Cycles world)"
		% (key, diff[band].mean(), np.percentile(diff[band], 99), diff[band].max()),
		flush=True,
	)

	draft = fit(load(os.path.join(ts.ROOT, "assets", "world2_draft", ts.folder(number, key), DRAFT_SHOT)))
	studio_path = os.path.join(AUDIT, "T%d_road.jpg" % number)
	if os.path.exists(studio_path):
		shot = load(studio_path)
		swapped, horizon, alpha, fog_rows = studio_with_sky(cube, shot, key)
		save(swapped, os.path.join(folder, "studio_sky.png"))
		print("STUDIO %s horizon row %d of %d, fog band %d rows" % (key, horizon, shot.shape[0], fog_rows), flush=True)
		if key == "AntIsland":
			swapped = regrade(swapped, alpha, ANT_LIGHT)
			save(swapped, os.path.join(folder, "studio_sky_dusk.png"))
		top, bottom = [fit(shot), fit(swapped)], [draft, fit(pano)]
	else:
		view = game_view(cube, manifest["ground"] or "808080", key)
		save(view, os.path.join(folder, "game_view.png"))
		top, bottom = [fit(view), draft], [fit(pano), np.zeros((H, W, 3), np.float32)]
	gap = np.full((8, W * 2 + 8, 3), 0.08, np.float32)
	vgap = np.full((H, 8, 3), 0.08, np.float32)
	board = np.concatenate([np.concatenate([top[0], vgap, top[1]], 1), gap, np.concatenate([bottom[0], vgap, bottom[1]], 1)], 0)
	save(board, os.path.join(folder, "preview.png"))
	print("PREVIEW", os.path.relpath(os.path.join(folder, "preview.png"), ts.ROOT), flush=True)


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	for number, key in ts.TRACKS:
		if not argv or key in argv:
			run(number, key)


main()
