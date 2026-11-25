"""Export the owner-approved World 2 drafts for the game (docs/WORLD2_SPEC.md "Blender first", BIOME_ENVIRONMENT_SPEC 4).

Builds each approved track exactly as build_track.py does (render=False), then writes:
- build/world2/export/<Biome>/W2_<Biome>_<Prop>.glb: one upload-ready mesh per unique non-road prop (one primitive,
  material colours baked to vertex colours, glTF Y up = Roblox Y up, -Z toward the road, base centre at the origin),
  plus manifest.json (prop, tris, hero, size, placements);
- src/shared/BiomeThemes/World2/<Biome>Draft.luau: the generated data the game theme reads (props with their sizes and
  parts fallbacks, explicit placements in track-local studs, lamps, ground, sky and sun values).
Road pieces (Wall, Dash, Apron, WinPad, Road, Ground) belong to the game's track builder and are not exported.
Road test (WORLD2_SPEC 2026-11-24): every placement's real triangles, in the game's transform (unmirrored, scaled), are
tested against EVERY track's road corridor (clearance.corridors / intrudes); an intruding placement is not exported.
A mesh over PART_MAX on an axis at its largest kept scale is cut by planes into the fewest pieces under it (cuts capped),
each its own GLB and prop <Prop>_p<i>, placed so the pieces reassemble the mesh exactly. A GLB whose bytes did not change
is left untouched; new or changed ones are listed in build/world2/export/needs_upload.tsv.
Headless:  Blender -b --factory-startup --python tools/blender/world2/export_props.py -- <number ...|approved>
Import-safe: main() runs only as a script. The biome modules are read, never changed.
"""

import importlib
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

# Owner-approved and frozen 2026-11-23 / 2026-11-24 (WORLD2_SPEC "Render set approvals"). All 10.
APPROVED = {1: "ElvenPlains", 2: "DemonCastle", 3: "RuinedCityZ", 4: "HauntedTunnel", 5: "KaijuBase", 6: "DevilTokyo", 7: "AntIsland", 8: "MonsterDen", 9: "GoldenCity", 10: "HellGate"}
ROAD = {"Wall", "Dash", "Apron", "WinPad", "Road", "Ground"}
# Game names for draft props whose draft name holds a real character, brand or place name (design doc 5): asset keys and
# shipped data use the right-hand name only. The draft modules are frozen, so the rename lives here.
RENAME = {"SaitamaApt": "BrickFlat", "SeikoHouse": "OldWoodHouse", "Hallasan": "IslandVolcano", "Choga": "ThatchHouse", "KaijuCorpse": "GiantCorpse"}
EXPORT = os.path.join(ROOT, "build", "world2", "export")
THEMES = os.path.join(ROOT, "src", "shared", "BiomeThemes", "World2")
CAPS = {"hero": 20000, "mid": 3000, "unique": 12}  # BIOME_ENVIRONMENT_SPEC 4.3 / 4.5
HERO_MAX = 4  # placeholder: spec 4.3 heroes are one model each, 2-4 per biome
FALLBACK_PARTS = {"hero": 24, "mid": 6}  # placeholder: largest parts kept as the parts fallback silhouette (spec 4.2)
SPOT_STEP = 10  # studs: find_spot's grid on the own ground, tried nearest the approved spot first
STREAM_RADIUS = 1024.0  # world2.project.json StreamingTargetRadius: a hero's base centre stays this close to its own road
HERO_MOVES = os.path.join(HERE, "hero_moves.json")  # biome -> hero -> {From, To, Studs}: track-local base centres
PRUNE_CLEAR = 8.0  # BiomeDressing.CLEARANCE: Prune grows a prop's box by this
LOWER_STEP, LOWER_MAX = 0.05, 2.0  # studs: an exempt support poking into its own lane is lowered by steps, at most this
SPAWN_HALF = (94.0, 110.0)  # SpawnArea.FLOOR_SIZE / 2 at the world origin (x, z); it blocks at every height
PART_MAX = 2040  # studs per axis at placed scale: under Roblox's 2048 part limit (WORLD2_SPEC 2026-11-24 "several pieces")
UPLOADED = os.path.join(HERE, "uploaded_assets.tsv")  # biome, key, Model id, MeshId, uploaded GLB geometry hash
NEEDS_UPLOAD = os.path.join(EXPORT, "needs_upload.tsv")  # biome, key, reason: new or changed GLBs (rules audit + upload)


def origins():
	"""Track number -> (origin xyz, yaw) of its start, as chain.build chains them (TrackBuilder.CHAIN_ORIGIN)."""
	import glob

	import chain

	specs = sorted((chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))), key=lambda s: s["Number"])
	origin, yaw, out = chain.ORIGIN, 0.0, {}
	for spec in specs:
		_, end, heading, _ = chain.layout(spec)
		out[spec["Number"]] = (origin, yaw)
		origin, yaw = chain.to_world(origin, yaw, end), yaw + heading
	return out


def ground_rect(number):
	"""The track's own Ground (TrackBuilder.Build: its waypoints' box padded by Width * 3 + 200) in its start frame, as
	((x lo, z lo), (x hi, z hi)): BiomeDressing builds a Placed prop only when its base centre is on it."""
	import glob

	import chain

	spec = next(s for s in (chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))) if s["Number"] == number)
	wps, pad = chain.layout(spec)[0], spec["Width"] * 3 + 200
	xs, zs = [p[0] for p in wps], [p[2] for p in wps]
	return (min(xs) - pad, min(zs) - pad), (max(xs) + pad, max(zs) + pad)


def yaw_rot(yaw):
	"""CFrame.Angles(0, yaw, 0) as rows (Roblox)."""
	c, s = math.cos(yaw), math.sin(yaw)
	return ((c, 0.0, s), (0.0, 1.0, 0.0), (-s, 0.0, c))


def blockers():
	"""What BiomeDressing.Prune still tests a Placed prop against (WORLD2_SPEC 2026-11-24), as world boxes (centre,
	rows, half size, column): every track's checkpoint area (TrackBuilder: Width + 2 * apron by 60 behind its finish,
	the win pad's top included) and the spawn-area floor, which blocks at every height."""
	import glob

	import chain

	specs = sorted((chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))), key=lambda s: s["Number"])
	out = [((0.0, -1.0, 0.0), yaw_rot(0.0), (SPAWN_HALF[0], 0.5, SPAWN_HALF[1]), True)]
	for spec, (origin, yaw) in zip(specs, origins().values()):
		_, end, heading, _ = chain.layout(spec)
		e, ey = chain.to_world(origin, yaw, end), yaw + heading
		R = yaw_rot(ey)
		c = [e[i] + sum(R[i][j] * v for j, v in enumerate((0.0, -0.75, 30.0))) for i in range(3)]
		out.append((tuple(c), R, (spec["Width"] / 2 + 30.0, 1.2, 30.0), False))
	return out


def obb_overlap(ca, Ra, ha, cb, Rb, hb):
	"""BiomeDressing's `overlaps`: separating-axis test of two boxes (rows of Ra/Rb are world, columns the box axes)."""
	import numpy as np

	A, B = np.array(Ra).T, np.array(Rb).T  # rows: each box's axes in world
	t = np.array(cb) - np.array(ca)
	axes = list(A) + list(B) + [np.cross(a, b) for a in A for b in B]
	for ax in axes:
		n = np.linalg.norm(ax)
		if n < 1e-6:
			continue
		ax = ax / n
		ra = sum(abs(A[k] @ ax) * ha[k] for k in range(3))
		rb = sum(abs(B[k] @ ax) * hb[k] for k in range(3))
		if abs(t @ ax) >= ra + rb:
			return False
	return True


def draft_boxes(skip):
	"""Every draft prop the game builds on the other tracks, as world boxes (centre, rows, half size), read from the
	generated World2/<Biome>Draft.luau (Props sizes, Placed entries) of every approved track but `skip`. Each biome's
	CLEAR_EXEMPT props (road spans, supports under the road) are left out. A moved hero may not stand inside one."""
	import re

	import numpy as np

	out = []
	for number, (origin, yaw) in origins().items():
		if number == skip or number not in APPROVED:
			continue
		biome = APPROVED[number]
		src = open(os.path.join(THEMES, biome + "Draft.luau")).read()
		m = re.search(r"\nCLEAR_EXEMPT = \{([^}]*)\}", open(os.path.join(HERE, "biomes", biome + ".py")).read())
		exempt = {RENAME.get(n, n) for n in re.findall(r'"(\w+)"', m.group(1))} if m else set()
		sizes = {k: [float(x) for x in v.split(",")] for k, v in re.findall(r"\n\t\t(\w+) = \{\n\t\t\tSize = v\(([^)]*)\)", src)}
		for m in re.finditer(r'\{ "(\w+)", ([^{}]*?) \},\n', src[src.index("\tPlaced = {") : src.index("\tHeroes = ")]):
			name, rest = m.group(1), m.group(2).split(", Group")[0]
			if re.sub(r"_p\d+$", "", name) in exempt:
				continue
			nums = [float(x) for x in rest.split(", v(")[0].split(",")]
			st = re.search(r"v\(([^)]*)\)", rest)
			sc = [float(x) for x in st.group(1).split(",")] if st else [nums[4]] * 3
			rx, rz = (nums[5], nums[6]) if len(nums) > 6 else (0.0, 0.0)
			R = np.array(yaw_rot(yaw)) @ np.array(from_euler_yxz(rx, nums[3], rz))
			size = np.array(sizes[name]) * np.array(sc)
			c = np.array(to_world(origin, yaw, nums[:3])) + R @ np.array([0.0, size[1] / 2, 0.0])
			out.append((c, R, size / 2, number, name))
	return out


def band_raster(cell=4.0):
	"""A quick, exact-for-rejection map of the road corridors: cells (`cell` studs) lying wholly within 22 studs of a
	centre-line waypoint of any track, with the lowest and highest road top of the waypoints marking them. A point in a
	marked cell between the highest top and 14 over the lowest is inside some corridor box (clearance.corridors)."""
	import chain
	import numpy as np

	tracks = chain.build()
	# the chain's two open ends (Track 1's start, the last finish) are left out; elsewhere it runs on through the joins
	w = np.concatenate([np.array(t["Waypoints"])[(3 if i == 0 else 0) : (-3 if i == len(tracks) - 1 else None)] for i, t in enumerate(tracks)])
	lo = w[:, [0, 2]].min(0) - 64
	n = np.ceil((w[:, [0, 2]].max(0) + 64 - lo) / cell).astype(int)
	r = int(24 // cell)
	# a whole cell within 22 (2 studs of margin for the turn wedges) of the waypoint, wherever in its own cell it lies
	off = np.array([(i, j) for i in range(-r, r + 1) for j in range(-r, r + 1) if math.hypot(i, j) * cell <= 22 - cell * 1.4143])
	ij = np.floor((w[:, [0, 2]] - lo) / cell).astype(int)
	cells = (ij[:, None, :] + off[None]).reshape(-1, 2)
	top = np.repeat(w[:, 1], len(off))
	tmin, tmax = np.full(n, np.inf, np.float32), np.full(n, -np.inf, np.float32)
	np.minimum.at(tmin, (cells[:, 0], cells[:, 1]), top)
	np.maximum.at(tmax, (cells[:, 0], cells[:, 1]), top)
	return {"lo": lo, "cell": cell, "tmin": tmin, "tmax": tmax}


def band_hit(raster, pts):
	"""True when a world point (pts: (m, 3)) is certainly inside a road corridor (band_raster)."""
	import numpy as np

	ij = np.floor((pts[:, [0, 2]] - raster["lo"]) / raster["cell"]).astype(int)
	n = raster["tmin"].shape
	ok = (ij[:, 0] >= 0) & (ij[:, 1] >= 0) & (ij[:, 0] < n[0]) & (ij[:, 1] < n[1])
	ij, y = ij[ok], pts[ok, 1]
	lo, hi = raster["tmin"][ij[:, 0], ij[:, 1]], raster["tmax"][ij[:, 0], ij[:, 1]]
	# a cell no waypoint marked holds +inf / -inf: without the finite test every point off the roads counted as a hit
	return bool((np.isfinite(lo) & (y > hi + 0.05) & (y < lo + 14)).any())


PLAZA_ZONE = math.hypot(*SPAWN_HALF) + 64  # TerrainShape PlazaRadius: the spawn floor's far corner + PLAZA_MARGIN


def zone_lines(option):
	"""Proposed zone rule (docs/OWNER_QUESTIONS.md), as (points (m, 2) world x, z; their track numbers; plaza radius):
	option 1, BiomeEnvironment.ZoneAt's zones (each centre line every 64 studs, TerrainShape.POLY_STEP; zone 0 within
	the plaza radius); option 2, the nearest centre line (every waypoint, no plaza zone)."""
	import chain
	import numpy as np

	pts, own = [], []
	for t in chain.build():
		w = np.array(t["Waypoints"])[:, [0, 2]]
		if option == 1:
			cum = np.concatenate([[0], np.cumsum(np.hypot(*(w[1:] - w[:-1]).T))])
			at = np.arange(0, cum[-1] + 1e-6, 64.0)
			w = np.stack((np.interp(at, cum, w[:, 0]), np.interp(at, cum, w[:, 1])), 1)
		pts.append(w)
		own.append(np.full(len(w), t["Number"]))
	return np.concatenate(pts), np.concatenate(own), PLAZA_ZONE if option == 1 else 0.0


def zone_of(zl, xz):
	"""The zone (track number, 0 for the plaza) of world points xz (m, 2) under zone_lines(option)."""
	import numpy as np

	pts, own, radius = zl
	out = np.empty(len(xz), int)
	for i in range(0, len(xz), 512):
		q = xz[i : i + 512]
		out[i : i + 512] = own[((q[:, None, :] - pts[None]) ** 2).sum(2).argmin(1)]
	out[np.hypot(xz[:, 0], xz[:, 1]) <= radius] = 0
	return out


def hero_ctx(number, corr, zone=None):
	"""What rules_ok tests a hero against on track `number`: its own ground, its own centre line (track-local x, z),
	the Prune blockers, every corridor, and the other tracks' draft props (draft_boxes) in a 256-stud XZ grid. `zone`
	(1 or 2, zone_lines): plan under that proposed rule, keeping only props inside their own zone and the hero in its."""
	import glob

	import chain
	import numpy as np

	spec = next(s for s in (chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))) if s["Number"] == number)
	props, grid = draft_boxes(number), {}
	zl = zone_lines(zone) if zone else None
	if zl:
		import numpy as np

		inside = zone_of(zl, np.array([[b[0][0], b[0][2]] for b in props]).reshape(-1, 2)) == np.array([b[3] for b in props])
		props = [b for b, k in zip(props, inside) if k]
	for k, (c, R, h, _, _) in enumerate(props):
		ext = np.abs(R) @ h
		for gx in range(int((c[0] - ext[0]) // 256), int((c[0] + ext[0]) // 256) + 1):
			for gz in range(int((c[2] - ext[2]) // 256), int((c[2] + ext[2]) // 256) + 1):
				grid.setdefault((gx, gz), []).append(k)
	line = np.array([(p[0], p[2]) for p in chain.layout(spec)[0]])
	ctx = {"ground": ground_rect(number), "line": line, "boxes": blockers(), "corr": corr, "number": number, "props": props, "grid": grid}
	ctx["raster"] = band_raster()
	ctx["zone"] = zl
	return ctx


def hero_box(local, origin, yaw, pos, e, sc):
	"""A placed mesh's world box: (centre, rows, half size)."""
	import numpy as np

	pts = (local * np.array(sc)).reshape(-1, 3)
	lo, hi = pts.min(0), pts.max(0)
	R = np.array(yaw_rot(yaw)) @ np.array(from_euler_yxz(*e))
	return np.array(to_world(origin, yaw, pos)) + R @ ((lo + hi) / 2), R, (hi - lo) / 2


def props_overlap(local, origin, yaw, pos, e, sc, ctx):
	"""The other tracks' draft props (ctx props) whose box overlaps the placed mesh's box: (count, largest as
	"T<n> <Prop> <x>x<y>x<z>" or None). Not a rule: find_spot prefers the spot with the fewest."""
	import numpy as np

	c, R, own = hero_box(local, origin, yaw, pos, e, sc)
	oext = np.abs(R) @ own
	hits, seen = [], set()
	for gx in range(int((c[0] - oext[0]) // 256), int((c[0] + oext[0]) // 256) + 1):
		for gz in range(int((c[2] - oext[2]) // 256), int((c[2] + oext[2]) // 256) + 1):
			for k in ctx["grid"].get((gx, gz), ()):
				if k in seen:
					continue
				seen.add(k)
				bc, bR, bh, t, name = ctx["props"][k]
				if np.all(np.abs(c - bc) < oext + np.abs(bR) @ bh) and obb_overlap(c, R, own, bc, bR, bh):
					hits.append((float(np.prod(bh)), "T%d %s %s" % (t, name, "x".join("%.0f" % v for v in np.array(bh) * 2))))
	return len(hits), max(hits)[1] if hits else None


def rules_ok(local, origin, yaw, pos, e, sc, ctx, exempt, why=None):
	"""Every rule one whole Placed hero (before any cut into pieces) must pass: base centre on its own Ground
	(ground_rect) and within STREAM_RADIUS of its own centre line; its mesh box grown by PRUNE_CLEAR clear of every
	checkpoint area and the spawn area (BiomeDressing.Prune); its triangles clear of every track's road corridor (own
	track skipped when exempt). `why` (a dict) counts the failures."""
	import numpy as np

	def fail(rule):
		if why is not None:
			why[rule] = why.get(rule, 0) + 1
		return False

	(glo, ghi) = ctx["ground"]
	if not (glo[0] <= pos[0] <= ghi[0] and glo[1] <= pos[2] <= ghi[1]):
		return fail("ground")
	if np.sqrt(((ctx["line"] - (pos[0], pos[2])) ** 2).sum(1)).min() > STREAM_RADIUS:
		return fail("stream")
	if ctx.get("zone") and zone_of(ctx["zone"], np.array([to_world(origin, yaw, pos)])[:, [0, 2]])[0] != ctx["number"]:
		return fail("zone")
	c, R, own = hero_box(local, origin, yaw, pos, e, sc)
	half = own + PRUNE_CLEAR
	ext = np.abs(R) @ half
	for bc, bR, bh, column in ctx["boxes"]:
		bext = np.abs(np.array(bR)) @ np.array(bh)
		if np.any(np.abs(c[[0, 2]] - np.array(bc)[[0, 2]]) >= ext[[0, 2]] + bext[[0, 2]]):
			continue
		cc = c.copy()
		if column:
			cc[1] = bc[1]
		elif abs(c[1] - bc[1]) >= ext[1] + bext[1]:
			continue
		if obb_overlap(cc, R, half, bc, bR, bh):
			return fail("pads")
	import clearance

	tris = game_tris(local, origin, yaw, pos, e, sc)
	if not exempt and band_hit(ctx["raster"], tris.reshape(-1, 3)):  # a quick, certain rejection first
		return fail("corridor")
	if clearance.intrudes(tris, ctx["corr"], (ctx["number"],) if exempt else ()):
		return fail("corridor")
	return True


def find_spot(local, origin, yaw, pos, e, sc, ctx, exempt, why=None):
	"""The rules_ok base centre on a SPOT_STEP grid through `pos` over the own ground with the fewest other-track draft
	props overlapping the mesh's box (counted box to box, axis-aligned in world: a close upper bound of props_overlap),
	ties to the spot nearest `pos`. Returns (spot, that count) or None."""
	import numpy as np

	(glo, ghi) = ctx["ground"]
	xs = pos[0] + SPOT_STEP * np.arange(math.ceil((glo[0] - pos[0]) / SPOT_STEP), math.floor((ghi[0] - pos[0]) / SPOT_STEP) + 1)
	zs = pos[2] + SPOT_STEP * np.arange(math.ceil((glo[1] - pos[2]) / SPOT_STEP), math.floor((ghi[1] - pos[2]) / SPOT_STEP) + 1)
	X, Z = np.meshgrid(xs, zs)
	X, Z = X.ravel(), Z.ravel()
	d = np.hypot(X - pos[0], Z - pos[2])
	near = np.zeros(len(X), bool)  # the stream rule on the whole grid at once, in chunks
	for i in range(0, len(X), 4096):
		q = np.stack((X[i : i + 4096], Z[i : i + 4096]), 1)
		dmin = np.full(len(q), np.inf)
		for j in range(0, len(ctx["line"]), 256):
			dmin = np.minimum(dmin, np.sqrt(((q[:, None, :] - ctx["line"][None, j : j + 256]) ** 2).sum(2)).min(1))
		near[i : i + 4096] = dmin <= STREAM_RADIUS
	if ctx.get("zone"):  # the proposed zone rule: only candidates inside the own zone
		idx = np.nonzero(near)[0]
		wpt = np.stack((origin[0] + X[idx] * math.cos(yaw) + Z[idx] * math.sin(yaw), origin[2] - X[idx] * math.sin(yaw) + Z[idx] * math.cos(yaw)), 1)
		near[idx[zone_of(ctx["zone"], wpt) != ctx["number"]]] = False
	if why is not None:
		why["stream"] = why.get("stream", 0) + int((~near).sum())
	# other-track props per candidate: the mesh's world box moves with the candidate (its turn is fixed)
	c0, R, own = hero_box(local, origin, yaw, pos, e, sc)
	ext = np.abs(R) @ own
	cy, cs = math.cos(yaw), math.sin(yaw)
	wx = c0[0] + (X - pos[0]) * cy + (Z - pos[2]) * cs
	wz = c0[2] - (X - pos[0]) * cs + (Z - pos[2]) * cy
	pc = np.array([b[0] for b in ctx["props"]]).reshape(-1, 3)
	pe = np.array([np.abs(b[1]) @ b[2] for b in ctx["props"]]).reshape(-1, 3)
	sel = np.abs(pc[:, 1] - c0[1]) < ext[1] + pe[:, 1]
	pc, pe = pc[sel], pe[sel]
	count = np.zeros(len(X), int)
	for i in range(0, len(X), 2048):
		count[i : i + 2048] = (
			(np.abs(wx[i : i + 2048, None] - pc[None, :, 0]) < ext[0] + pe[None, :, 0]) & (np.abs(wz[i : i + 2048, None] - pc[None, :, 2]) < ext[2] + pe[None, :, 2])
		).sum(1)
	for k in np.lexsort((d, count)):
		if near[k]:
			p2 = (float(X[k]), pos[1], float(Z[k]))
			if rules_ok(local, origin, yaw, p2, e, sc, ctx, exempt, why):
				return p2, int(count[k])
	return None


def seen_by(k, pts):
	"""Which of the draft's run shots (build_track.shots: runner's-eye at 0.06, 0.33, 0.62, 0.9 of the track, 70 degree
	vertical field, 16:9) have any of the world points pts (m, 3) in frame (no occlusion)."""
	import numpy as np

	tv = math.tan(math.radians(35))
	out = []
	for f in (0.06, 0.33, 0.62, 0.9):
		p, right, t = k.at(k.length * f)
		lane = np.array((p.x + right.x * 10, p.y, p.z + right.z * 10))
		fwd = np.array((t.x, 0.0, t.z))
		eye, look = lane - fwd * 14 + (0, 8, 0), lane + fwd * 70 + (0, 4, 0)
		F = (look - eye) / np.linalg.norm(look - eye)
		r = np.cross(F, (0, 1, 0))
		r /= np.linalg.norm(r)
		u = np.cross(r, F)
		v = pts - eye
		z = v @ F
		ok = z > 1
		if ((np.abs((v @ r)[ok] / z[ok]) <= tv * 16 / 9) & (np.abs((v @ u)[ok] / z[ok]) <= tv)).any():
			out.append(f)
	return out


def to_world(origin, yaw, p):
	"""chain.to_world: a track-local point in world studs."""
	c, s = math.cos(yaw), math.sin(yaw)
	return (origin[0] + p[0] * c + p[2] * s, origin[1] + p[1], origin[2] - p[0] * s + p[2] * c)


def to_local(origin, yaw, p):
	"""Inverse of chain.to_world: a Roblox world point in the track's start frame."""
	x, y, z = p[0] - origin[0], p[1] - origin[1], p[2] - origin[2]
	c, s = math.cos(yaw), math.sin(yaw)
	return (x * c - z * s, y, x * s + z * c)


def record():
	"""Wrap Kit so the build leaves its prop parts, ground, sky and lamps on the Kit (the biome modules stay untouched)."""
	import kit

	if getattr(kit.Kit, "_recording", False):
		return
	prop, sky, ground, light = kit.Kit.prop, kit.Kit.sky, kit.Kit.ground, kit.Kit.light

	def rec(self):
		if not hasattr(self, "rec"):
			self.rec = {"parts": {}, "sky": None, "ground": None, "lights": []}
		return self.rec

	def prop_(self, name, parts):
		rec(self)["parts"][name] = [tuple(p) for p in parts]
		return prop(self, name, parts)

	def sky_(self, stops, strength=1.0, sun=None, fog=None):
		rec(self)["sky"] = {"stops": stops, "strength": strength, "sun": sun, "fog": fog}
		return sky(self, stops, strength, sun, fog)

	def ground_(self, color, margin=400, rough=1.0, y=-1.0):
		rec(self)["ground"] = {"color": color, "y": y}
		return ground(self, color, margin, rough, y)

	def light_(self, pos, color, energy=2000, radius=4):
		rec(self)["lights"].append((tuple(pos), color, energy))
		return light(self, pos, color, energy, radius)

	kit.Kit.prop, kit.Kit.sky, kit.Kit.ground, kit.Kit.light = prop_, sky_, ground_, light_
	kit.Kit._recording = True


# Blender (x, y, z) = Roblox (x, -z, y); the map is a proper rotation, so angles keep their sign per axis
def rb_of(v):
	return (v[0], v[2], -v[1])


def rb_matrix(m3):
	"""Blender 3x3 rotation -> Roblox 3x3 rows (P^T M P with P the Roblox -> Blender axis map)."""
	P = ((1, 0, 0), (0, 0, -1), (0, 1, 0))
	pm = [[sum(m3[i][k] * P[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
	return [[sum(P[k][i] * pm[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def bounds(mesh):
	pts = [rb_of(v.co) for v in mesh.vertices]
	lo = [min(p[i] for p in pts) for i in range(3)]
	hi = [max(p[i] for p in pts) for i in range(3)]
	return lo, hi


def material_of(color, o):
	if o.get("emit", 0) > 0:
		return "Neon"
	if o.get("alpha", 1) < 1:
		return "Glass"
	if o.get("metal", 0) >= 0.5:
		return "Metal"
	return "SmoothPlastic"


def fallback(parts, centre, keep):
	"""The `keep` largest parts (by volume) of a kit.prop parts list as Kit.part fields, re-centred on the prop's base
	centre. Shapes: box -> Block, ball -> Ball, wedge -> Wedge, cyl / cone -> an upright Cylinder (a cone at its mean
	width). Rot is Roblox Y, X, Z degrees (kit.prop's order)."""
	out = []
	for shape, size, pos, color, *rest in parts:
		o = rest[0] if rest else {}
		sx, sy, sz = size
		if shape == "cone" or (shape == "cyl" and o.get("taper", 1.0) != 1.0):
			k = (1 + o.get("taper", 0.0 if shape == "cone" else 1.0)) / 2
			sx, sz = sx * k, sz * k
		out.append(
			{
				"Shape": {"box": "Block", "ball": "Ball", "wedge": "Wedge", "cyl": "Cylinder", "cone": "Cylinder"}[shape],
				"Size": (sx, sy, sz),
				"Pos": (pos[0] - centre[0], pos[1] - centre[1], pos[2] - centre[2]),
				"Rot": tuple(o.get("rot", (0, 0, 0))),
				"Color": color,
				"Material": material_of(color, o),
				"Volume": abs(sx * sy * sz),
			}
		)
	out.sort(key=lambda p: -p["Volume"])
	return out[:keep]


def bake_glb(src, centre, path):
	"""One mesh, re-centred, with material base colours baked to a vertex colour layer, written as GLB."""
	import bpy

	me = src.data.copy()
	me.name = src.name + "_export"
	offset = (centre[0], -centre[2], centre[1])  # Roblox -> Blender
	for v in me.vertices:
		v.co.x -= offset[0]
		v.co.y -= offset[1]
		v.co.z -= offset[2]
	attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
	cols = []
	for m in me.materials:
		b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.use_nodes else None
		cols.append(tuple(b.inputs["Base Color"].default_value) if b else (0.5, 0.5, 0.5, 1.0))
	for poly in me.polygons:
		c = cols[poly.material_index] if cols else (0.5, 0.5, 0.5, 1.0)
		for li in poly.loop_indices:
			attr.data[li].color = c
	me.materials.clear()
	ob = bpy.data.objects.new(src.name, me)
	bpy.context.scene.collection.objects.link(ob)
	for o in bpy.context.scene.objects:
		o.select_set(o == ob)
	bpy.context.view_layer.objects.active = ob
	kw = dict(filepath=path, use_selection=True, export_format="GLB", export_yup=True, export_apply=True, export_materials="NONE")
	try:
		bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
	except TypeError:  # older exporters name it differently
		bpy.ops.export_scene.gltf(export_colors=True, **kw)
	bpy.data.objects.remove(ob)
	bpy.data.meshes.remove(me)


def placements(k, names, origin, yaw, centres):
	"""Every placed instance of a prop: (name, local pos of its base centre, local rotation rows, Roblox-axis scale)."""
	import bpy

	bpy.context.view_layer.update()
	by_mesh = {k.props[n].data.name: n for n in names}
	lib = set(k.lib.objects)
	out = []
	c, s = math.cos(yaw), math.sin(yaw)
	inv_yaw = ((c, 0, -s), (0, 1, 0), (s, 0, c))  # CFrame.Angles(0, yaw, 0) transposed
	for ob in bpy.context.scene.objects:
		if ob.type != "MESH" or ob in lib or ob.data.name not in by_mesh or ob.hide_render:
			continue
		name = by_mesh[ob.data.name]
		mw = ob.matrix_world
		m3 = [[mw[i][j] for j in range(3)] for i in range(3)]
		scl = [math.sqrt(sum(m3[i][j] ** 2 for i in range(3))) for j in range(3)]
		rot = rb_matrix([[m3[i][j] / scl[j] for j in range(3)] for i in range(3)])
		sc = (scl[0], scl[2], scl[1])  # Blender local x, z, y = Roblox local X, Y, Z
		ctr = centres[name]
		off = [sum(rot[i][j] * ctr[j] * sc[j] for j in range(3)) for i in range(3)]
		world = rb_of(mw.translation)
		base = to_local(origin, yaw, (world[0] + off[0], world[1] + off[1], world[2] + off[2]))
		lrot = [[sum(inv_yaw[i][kk] * rot[kk][j] for kk in range(3)) for j in range(3)] for i in range(3)]
		out.append((name, base, lrot, sc))
	return out


def euler_yxz(r):
	"""(rx, ry, rz) radians with r = Ry(ry) Rx(rx) Rz(rz), as CFrame.fromEulerAnglesYXZ(rx, ry, rz)."""
	rx = math.asin(max(-1.0, min(1.0, -r[1][2])))
	if abs(r[1][2]) < 0.99999:
		return rx, math.atan2(r[0][2], r[2][2]), math.atan2(r[1][0], r[1][1])
	return rx, math.atan2(-r[2][0], r[0][0]), 0.0  # gimbal lock: fold Z into Y


def from_euler_yxz(rx, ry, rz):
	def mul(a, b):
		return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

	cy, sy, cx, sx, cz, sz = math.cos(ry), math.sin(ry), math.cos(rx), math.sin(rx), math.cos(rz), math.sin(rz)
	Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
	Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
	Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
	return mul(mul(Ry, Rx), Rz)


def lua_num(x):
	return ("%.3f" % x).rstrip("0").rstrip(".") if abs(x) > 5e-4 else "0"


def lua_vec(t):
	return "v(%s)" % ", ".join(lua_num(x) for x in t)


def write_luau(biome, number, props, placed, lights, rec, path, heroes=()):
	L = [
		"--!nonstrict",
		"-- GENERATED by tools/blender/world2/export_props.py from the owner-approved Blender draft (Track %d). Do not edit:" % number,
		"-- re-run the exporter. Track-local studs (TrackBuilder origin of this track, Y up, -Z toward the road at heading 0).",
		"-- Props: Size = the mesh's box; Parts = its largest kit parts, the parts fallback (BIOME_ENVIRONMENT_SPEC 4.2).",
		"-- PartsOnly: a prop of 1-2 kit boxes is built from them exactly and is no mesh asset.",
		"-- Placed: { Prop, X, Y, Z, Yaw, Scale } for each prop's base centre (radians, CFrame.fromEulerAnglesYXZ), or",
		"-- { Prop, X, Y, Z, Yaw, 1, RX, RZ, v(SX, SY, SZ) } for a tilted or stretched one. Biggest props first.",
		"-- A piece of a cut prop also has Group (its placement) and Whole (the whole prop's base centre).",
		"-- Lights: { X, Y, Z, Color, Energy (Blender W) }, brightest first.",
		"-- Heroes: the draft's close-up models (MODEL_SHOTS); a prop cut into pieces is <Prop>_p<i> (2048-stud limit).",
		"local v, hex = Vector3.new, Color3.fromHex",
		"local M, P = Enum.Material, Enum.PartType",
		"",
		"return {",
		"\tProps = {",
	]
	for name, p in props.items():
		L.append("\t\t%s = {" % name)
		L.append("\t\t\tSize = %s," % lua_vec(p["size"]))
		L.append("\t\t\tTris = %d," % p["tris"])
		if p["hero"]:
			L.append("\t\t\tHero = true,")
		if p["partsOnly"]:
			L.append("\t\t\tPartsOnly = true,")
		L.append("\t\t\tParts = {")
		for q in p["parts"]:
			L.append(
				'\t\t\t\t{ %s, %s, hex("%s"), M.%s, P.%s, %s },'
				% (lua_vec(q["Size"]), lua_vec(q["Pos"]), q["Color"], q["Material"], q["Shape"], lua_vec(q["Rot"]))
			)
		L.append("\t\t\t},")
		L.append("\t\t},")
	L.append("\t},")
	L.append("\tPlaced = {")
	for name, pos, (rx, ry, rz), sc, *grp in placed:
		head = '"%s", %s, %s, %s, %s' % (name, lua_num(pos[0]), lua_num(pos[1]), lua_num(pos[2]), lua_num(ry))
		tail = ", Group = %d, Whole = %s" % (grp[0][0], lua_vec(grp[0][1])) if grp else ""
		uniform = max(sc) - min(sc) <= 1e-3 * max(sc)
		if uniform and abs(rx) < 1e-4 and abs(rz) < 1e-4:
			L.append("\t\t{ %s, %s%s }," % (head, lua_num(sc[0]), tail))
		else:
			L.append("\t\t{ %s, 1, %s, %s, %s%s }," % (head, lua_num(rx), lua_num(rz), lua_vec(sc), tail))
	L.append("\t},")
	L.append("\tHeroes = { %s }," % ", ".join('"%s"' % h for h in heroes))
	L.append("\tLights = {")
	for pos, col, energy in lights:
		L.append('\t\t{ %s, %s, %s, hex("%s"), %g },' % (lua_num(pos[0]), lua_num(pos[1]), lua_num(pos[2]), col, energy))
	L.append("\t},")
	g = rec["ground"] or {"color": "777777", "y": -1.0}
	L.append('\tGround = { Color = hex("%s"), Y = %s },' % (g["color"], lua_num(g["y"])))
	sky = rec["sky"]
	if sky:
		stops = ", ".join('{ %s, hex("%s") }' % (lua_num(a), b) for a, b in sky["stops"])
		L.append("\tSky = { Stops = { %s }, Strength = %s }," % (stops, lua_num(sky["strength"])))
		if sky["sun"]:
			e, col, elev, azim = sky["sun"]
			L.append('\tSun = { Energy = %s, Color = hex("%s"), Elevation = %s, Azimuth = %s },' % (lua_num(e), col, lua_num(elev), lua_num(azim)))
		if sky["fog"]:
			d, col = sky["fog"]
			L.append('\tFog = { Density = %s, Color = hex("%s") },' % (lua_num(d), col))
	L.append("}")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w") as f:
		f.write("\n".join(L) + "\n")


def local_tris(me, centre):
	"""A prop mesh's triangles (m, 3, 3) in Roblox axes relative to its base centre (numpy)."""
	import numpy as np

	me.calc_loop_triangles()
	co = np.empty(len(me.vertices) * 3)
	me.vertices.foreach_get("co", co)
	co = co.reshape(-1, 3)
	idx = np.empty(len(me.loop_triangles) * 3, int)
	me.loop_triangles.foreach_get("vertices", idx)
	rb = np.stack((co[:, 0], co[:, 2], -co[:, 1]), 1) - np.array(centre)
	return rb[idx.reshape(-1, 3)]


def parts_tris(parts):
	"""The parts fallback (fallback()'s dicts) as triangles relative to the base centre (12 per part's box; a ball or
	cylinder by its box), numpy (m, 3, 3)."""
	import numpy as np

	out = []
	cube = np.array([(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
	faces = [(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1), (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)]
	for q in parts:
		R = np.array(from_euler_yxz(*(math.radians(a) for a in q["Rot"])))
		v = (cube * np.array(q["Size"]) / 2) @ R.T + np.array(q["Pos"])
		out.extend(v[list(f)] for f in faces)
	return np.array(out).reshape(-1, 3, 3)


def game_tris(local, origin, yaw, pos, e, sc):
	"""The triangles as the game places them (BiomeDressing.placed: origin * CFrame.new(pos) * fromEulerAnglesYXZ(e),
	the mesh sized by sc), in world studs."""
	import numpy as np

	R = np.array(from_euler_yxz(*e))
	p = (local * np.array(sc)) @ R.T + np.array(pos)
	c, s = math.cos(yaw), math.sin(yaw)
	return np.stack((origin[0] + p[..., 0] * c + p[..., 2] * s, origin[1] + p[..., 1], origin[2] - p[..., 0] * s + p[..., 2] * c), -1)


def cells(size, scale):
	"""Pieces per Roblox axis so each is under PART_MAX at `scale` (per axis): the fewest equal slabs."""
	return tuple(max(1, math.ceil(size[i] * scale[i] / PART_MAX)) for i in range(3))


def split(src, lo, hi, n):
	"""Cuts prop object `src` by planes into n = (nx, ny, nz) equal slabs of its Roblox box [lo, hi]; each cut is capped
	(holes_fill on the cut edges, the cap taking a neighbour face's material). Returns [(cell, mesh)] for the non-empty
	cells, in x, y, z order. Roblox X, Y, Z = Blender x, z, -y."""
	import bmesh
	import bpy

	out = []
	for ix in range(n[0]):
		for iy in range(n[1]):
			for iz in range(n[2]):
				bm = bmesh.new()
				bm.from_mesh(src.data)
				for axis, i, k in ((0, ix, n[0]), (1, iy, n[1]), (2, iz, n[2])):
					step = (hi[axis] - lo[axis]) / k
					for edge, keep_below in ((i, False), (i + 1, True)):
						if edge in (0, k):
							continue
						at = lo[axis] + edge * step
						co, no = [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]
						# Roblox axis -> Blender (axis index, sign); the plane normal points to the side removed
						b, sign = ((0, 1), (2, 1), (1, -1))[axis]
						co[b] = at * sign
						no[b] = (1 if keep_below else -1) * sign
						res = bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-5, plane_co=co, plane_no=no, clear_outer=True)
						cut = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMEdge) and g.is_valid and g.is_boundary]
						if cut:
							for f in bmesh.ops.holes_fill(bm, edges=cut, sides=0)["faces"]:
								near = [lf for e in f.edges for lf in e.link_faces if lf is not f]
								f.material_index = near[0].material_index if near else 0
				if bm.faces:
					bmesh.ops.triangulate(bm, faces=bm.faces[:])
					me = bpy.data.meshes.new("%s_p%d" % (src.data.name, len(out) + 1))
					bm.to_mesh(me)
					for m in src.data.materials:
						me.materials.append(m)
					out.append(((ix, iy, iz), me))
				bm.free()
	return out


def piece_parts(parts, plo, phi, keep, fill):
	"""A piece's parts fallback: the parent's Kit.part fields (Pos from the parent base centre) cut to the piece box
	[plo, phi] (same frame). An unturned Block is clipped to the box exactly; another part whose centre is in the box
	keeps its centre and is shrunk to fit the box's smallest side. None left: one Block of the box in `fill`'s colour.
	shortcut: the fallback only approximates a cut curved part; the real look is the mesh."""
	out = []
	side = min(phi[i] - plo[i] for i in range(3))
	for q in parts:
		lo = [q["Pos"][i] - abs(q["Size"][i]) / 2 for i in range(3)]
		hi = [q["Pos"][i] + abs(q["Size"][i]) / 2 for i in range(3)]
		if q["Shape"] == "Block" and not any(q["Rot"]):
			clo, chi = [max(lo[i], plo[i]) for i in range(3)], [min(hi[i], phi[i]) for i in range(3)]
			if all(chi[i] - clo[i] > 1e-3 for i in range(3)):
				out.append(dict(q, Size=tuple(chi[i] - clo[i] for i in range(3)), Pos=tuple((chi[i] + clo[i]) / 2 for i in range(3))))
		elif all(plo[i] <= q["Pos"][i] <= phi[i] for i in range(3)):
			out.append(dict(q, Size=tuple(min(abs(x), side) for x in q["Size"])))
	for q in out:
		q["Volume"] = abs(q["Size"][0] * q["Size"][1] * q["Size"][2])
	out.sort(key=lambda q: -q["Volume"])
	if not out:
		out = [dict(fill, Shape="Block", Rot=(0, 0, 0), Size=tuple(phi[i] - plo[i] for i in range(3)), Pos=tuple((phi[i] + plo[i]) / 2 for i in range(3)))]
	return out[:keep]


def geometry_info(path):
	"""(sha256 of the GLB's geometry, tris, verts, bbox lo, bbox hi). The hash covers every triangle's corner positions
	(1e-4 studs), normals, UVs and vertex colours (1e-3), each triangle rotated to its smallest corner and the list
	sorted, so vertex order and other non-geometry bytes do not change it. path may be the GLB's bytes. No bpy."""
	import hashlib
	import struct

	data = path if isinstance(path, bytes) else open(path, "rb").read()
	n = struct.unpack_from("<I", data, 12)[0]
	gl, binc = json.loads(data[20 : 20 + n]), data[28 + n :]
	size = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
	width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
	scale = {5121: 255.0, 5123: 65535.0}

	def read(i, nd):
		a = gl["accessors"][i]
		v = gl["bufferViews"][a["bufferView"]]
		(fmt, b), w = size[a["componentType"]], width[a["type"]]
		stride, base = v.get("byteStride", b * w), v.get("byteOffset", 0) + a.get("byteOffset", 0)
		div = scale.get(a["componentType"], 1.0) if a.get("normalized") else 1.0
		return [tuple(round(x / div, nd) + 0.0 for x in struct.unpack_from("<%d%s" % (w, fmt), binc, base + k * stride)) for k in range(a["count"])]

	tris, verts, pts = [], 0, []
	for mesh in gl["meshes"]:
		for prim in mesh["primitives"]:
			at = prim["attributes"]
			cols = [read(at[k], 4 if k == "POSITION" else 3) for k in sorted(at)]
			corners = list(zip(*cols))
			verts, pts = verts + len(corners), pts + [c[sorted(at).index("POSITION")] for c in corners]
			idx = [i[0] for i in read(prim["indices"], 0)] if "indices" in prim else list(range(len(corners)))
			for t in range(0, len(idx), 3):
				tri = [corners[int(i)] for i in idx[t : t + 3]]
				r = tri.index(min(tri))
				tris.append(tuple(tri[r:] + tri[:r]))
	tris.sort()
	lo, hi = [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]
	return hashlib.sha256(repr(tris).encode()).hexdigest(), len(tris), verts, lo, hi


def geometry_self_test():
	"""geometry_info ignores vertex order and corner rotation, and sees a moved vertex."""
	import struct

	def glb(pos, idx):
		b = struct.pack("<%df" % len(pos), *pos) + struct.pack("<%dH" % len(idx), *idx)
		acc = [{"bufferView": 0, "componentType": 5126, "type": "VEC3", "count": len(pos) // 3}, {"bufferView": 1, "componentType": 5123, "type": "SCALAR", "count": len(idx)}]
		g = {"meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}], "accessors": acc, "bufferViews": [{}, {"byteOffset": len(pos) * 4}]}
		j = json.dumps(g).encode()
		return b"glTF" + struct.pack("<III", 2, 0, len(j)) + b"JSON" + j + struct.pack("<I", len(b)) + b"BIN\0" + b

	a = geometry_info(glb([0, 0, 0, 1, 0, 0, 0, 1, 0], [0, 1, 2]))
	assert a == geometry_info(glb([1, 0, 0, 0, 1, 0, 0, 0, 0], [0, 1, 2])), "vertex order or corner rotation changed the hash"
	assert a[0] != geometry_info(glb([0, 0, 0, 1, 0, 0, 0, 2, 0], [0, 1, 2]))[0], "a moved vertex kept the hash"


def write_glb(src, centre, path, changed, key, reason):
	"""bake_glb to a temp file; keep the old file when its bytes match, else replace it and note (key, reason)."""
	tmp = path[: -len(".glb")] + ".new.glb"  # the glTF exporter adds .glb to any other name
	bake_glb(src, centre, tmp)
	if os.path.exists(path) and open(path, "rb").read() == open(tmp, "rb").read():
		os.remove(tmp)
		return
	changed.append((key, reason if not os.path.exists(path) else "changed: the GLB bytes differ from the last export"))
	os.replace(tmp, path)


def export(number, glb=True, plan=False, zone=None):
	"""plan: report where each hero with no passing placement would go (find_spot, fresh, under the proposed `zone`
	rule when given) and write nothing: no GLB, manifest, draft module or HERO_MOVES."""
	import bpy
	import numpy as np

	import build_track
	import clearance

	if number not in APPROVED:
		raise SystemExit("track %d is not owner-approved (approved: %s)" % (number, sorted(APPROVED)))
	clearance.self_test()
	record()
	k = build_track.run(number, render=False)
	biome = k.biome
	assert biome == APPROVED[number], (number, biome)
	module = importlib.import_module("biomes." + biome)
	heroes = list(getattr(module, "MODEL_SHOTS", ()))
	exempt = set(getattr(module, "CLEAR_EXEMPT", ()))
	rec = getattr(k, "rec", {"parts": {}, "sky": None, "ground": None, "lights": []})
	names = [n for n in k.props if n not in ROAD]
	game = {n: RENAME.get(n, n) for n in names}
	origin, yaw = origins()[number]
	folder = os.path.join(EXPORT, biome)
	os.makedirs(folder, exist_ok=True)
	props, centres, bnds = {}, {}, {}
	for n in names:
		me = k.props[n].data
		me.calc_loop_triangles()
		lo, hi = bounds(me)
		bnds[n] = (lo, hi)
		centres[n] = ((lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2)
		props[n] = {
			"partsOnly": 0 < len(rec["parts"].get(n, [])) <= 2 and all(q[0] == "box" for q in rec["parts"][n]),
			"tris": len(me.loop_triangles),
			"size": tuple(hi[i] - lo[i] for i in range(3)),
			"count": 0,
		}
	warns, placed = [], []
	mirrored = {}
	for name, pos, rot, sc in placements(k, names, origin, yaw, centres):
		det = sum(rot[0][i] * (rot[1][(i + 1) % 3] * rot[2][(i + 2) % 3] - rot[1][(i + 2) % 3] * rot[2][(i + 1) % 3]) for i in range(3))
		if det < 0:  # a mirrored instance: Roblox parts cannot mirror, so it stands unmirrored (same box)
			rot = [[-r[0], r[1], r[2]] for r in rot]
			mirrored[name] = mirrored.get(name, 0) + 1
		e = euler_yxz(rot)
		back = from_euler_yxz(*e)
		assert all(abs(back[i][j] - rot[i][j]) < 1e-4 for i in range(3) for j in range(3)), (name, rot)
		placed.append((name, pos, e, sc))
		props[name]["count"] += 1
	for n, p in props.items():
		# a hero landmark (spec 4.3) is a close-up model (MODEL_SHOTS) placed at most HERO_MAX times; a repeated close-up
		# model is a mid prop
		p["hero"] = n in heroes and p["count"] <= HERO_MAX
		parts = rec["parts"].get(n, [])
		p["all_parts"] = fallback(parts, centres[n], len(parts))
		p["parts"] = p["all_parts"] if p["partsOnly"] else p["all_parts"][: FALLBACK_PARTS["hero" if p["hero"] else "mid"]]
	for name, n in mirrored.items():
		warns.append("%s: %d mirrored instances placed unmirrored" % (game[name], n))
	# Road test: each placement's triangles in the game's transform against every track's corridor (CLEAR_EXEMPT props
	# skip their own track only); an intruding placement is dropped
	corr = clearance.corridors(build_track.load_chain().values())
	local = {n: local_tris(k.props[n].data, centres[n]) for n in names}
	ptris = {n: parts_tris(props[n]["parts"]) for n in names}  # what the game builds while a mesh has no Id
	kept, dropped = [], {}
	for name, pos, e, sc in placed:
		skip = (number,) if name in exempt else ()
		hits = clearance.intrudes(game_tris(local[name], origin, yaw, pos, e, sc), corr, skip)
		if not hits and len(ptris[name]):  # its parts fallback must clear the roads too (box per part)
			hits = clearance.intrudes(game_tris(ptris[name], origin, yaw, pos, e, sc), corr, skip)
		if hits:
			for t in hits:
				dropped.setdefault(t, {}).setdefault(game[name], 0)
				dropped[t][game[name]] += 1
			props[name]["count"] -= 1
		else:
			kept.append((name, pos, e, sc))
	# A CLEAR_EXEMPT support or span whose top pokes up to LOWER_MAX studs into its own road's lane (from the road top
	# to 14 over it) is lowered just enough to clear it (a support's top then sits inside the 2-stud deck); a deeper one
	# stays and is reported.
	own_corr, lowered = {number: corr[number]}, {}
	for i, (name, pos, e, sc) in enumerate(kept):
		if name not in exempt:
			continue
		t = game_tris(local[name], origin, yaw, pos, e, sc)
		if not clearance.intrudes(t, own_corr):
			continue
		for d in [LOWER_STEP * k for k in range(1, int(LOWER_MAX / LOWER_STEP) + 1)]:
			if not clearance.intrudes(t - np.array([0.0, d, 0.0]), own_corr):
				kept[i] = (name, (pos[0], pos[1] - d, pos[2]), e, sc)
				lowered.setdefault(game[name], []).append(d)
				break
		else:
			lowered.setdefault(game[name] + " (not cleared)", []).append(None)
	# A hero with no placement that passes every game rule (rules_ok: own ground, plaza, checkpoints and win pads, every
	# corridor) moves, whole, to the clear spot nearest its approved one: the spot recorded in HERO_MOVES, else the
	# nearest found (find_spot) and recorded there. Its failing placements go. None found: it stays dropped (a decision).
	ctx = hero_ctx(number, corr, zone)
	moves = json.load(open(HERO_MOVES)) if os.path.exists(HERO_MOVES) and not plan else {}
	mine = moves.setdefault(biome, {})
	hero_tris = {h: np.concatenate([local[h]] + ([ptris[h]] if len(ptris[h]) else [])) for h in heroes if h in local}
	ok = lambda n, pos, e, sc: rules_ok(hero_tris[n], origin, yaw, pos, e, sc, ctx, n in exempt)  # noqa: E731
	moved = {}
	for h in heroes:
		if h not in props or any(q[0] == h and ok(*q) for q in kept):
			if plan and h in props:
				print("PLAN T%d %s zone=%s stays: an approved placement passes every rule" % (number, game[h], zone), flush=True)
			continue
		cands = [q for q in placed if q[0] == h]
		rec_ = mine.get(game[h])
		best = None
		if rec_:
			q = min(cands, key=lambda q: math.dist(q[1], rec_["From"]))
			at = tuple(rec_["To"])
			if ok(h, at, q[2], q[3]):
				best = (math.dist(q[1], at), q, at)
		if best is None:  # fewest other-track props over it, then nearest the approved spot
			found = []
			for q in cands:
				r = find_spot(hero_tris[h], origin, yaw, q[1], q[2], q[3], ctx, h in exempt)
				if r:
					found.append((r[1], math.dist(q[1], r[0]), q, r[0]))
			if found:
				_, dist, q, at = min(found, key=lambda f: f[:2])
				best = (dist, q, at)
		for q in [q for q in kept if q[0] == h]:
			kept.remove(q)
			props[h]["count"] -= 1
		if best:
			_, q, at = best
			kept.append((h, at, q[2], q[3]))
			props[h]["count"] += 1
			n0, big0 = props_overlap(hero_tris[h], origin, yaw, q[1], q[2], q[3], ctx)
			n1, big1 = props_overlap(hero_tris[h], origin, yaw, at, q[2], q[3], ctx)
			mine[game[h]] = {
				"From": [round(v, 3) for v in q[1]],
				"To": [round(v, 3) for v in at],
				"Studs": round(best[0], 1),
				"OverlapsFrom": [n0, big0],
				"OverlapsTo": [n1, big1],
			}
			moved[game[h]] = mine[game[h]]
			if plan:
				dist = lambda p_: np.sqrt(((ctx["line"] - (p_[0], p_[2])) ** 2).sum(1)).min()  # noqa: E731
				view = lambda p_: seen_by(k, game_tris(hero_tris[h], origin, yaw, p_, q[2], q[3]).reshape(-1, 3)[::5])  # noqa: E731
				print(
					"PLAN T%d %s zone=%s from (%.0f, %.0f) to (%.0f, %.0f) %.0f studs | own road %.0f -> %.0f | seen %s -> %s | other-track props %d (%s) -> %d (%s)"
					% (number, game[h], zone, q[1][0], q[1][2], at[0], at[2], best[0], dist(q[1]), dist(at), view(q[1]), view(at), n0, big0, n1, big1),
					flush=True,
				)
		else:
			if plan:
				print("PLAN T%d %s zone=%s no spot" % (number, game[h], zone), flush=True)
			mine.pop(game[h], None)
			warns.append("%s: no spot on its own ground passes every game rule at its approved scale" % game[h])
	if plan:
		return None, []
	with open(HERO_MOVES, "w") as f:
		json.dump(moves, f, indent=1, sort_keys=True)
	road = {
		"In": len(placed),
		"Dropped": len(placed) - len(kept),
		"Kept": len(kept),
		"By": {"track %d" % t: d for t, d in sorted(dropped.items())},
		"Heroes": {game[h]: props[h]["count"] if h in props else None for h in heroes},
		"Moved": moved,
		"Lowered": lowered,
	}
	print("ROADTEST %d %s %s" % (number, biome, json.dumps(road)))
	# Oversize meshes: cut into pieces under PART_MAX at their largest kept scale; the pieces replace the prop
	changed, pieces, objs, group = [], {}, {}, 0
	# (an unplaced prop is cut at scale 1, so its pieces keep their defs and ledger rows while it waits for a spot)
	for n in [n for n in names if not props[n]["partsOnly"]]:
		big = [max([q[3][i] for q in kept if q[0] == n] or [1.0]) for i in range(3)]
		cut = cells(props[n]["size"], big)
		if cut == (1, 1, 1):
			continue
		lo, hi = bnds[n]
		step = [(hi[i] - lo[i]) / cut[i] for i in range(3)]
		parent, made = props.pop(n), []
		fill = max(parent["all_parts"], key=lambda q: q["Volume"]) if parent["all_parts"] else {"Color": "777777", "Material": "SmoothPlastic"}
		for cell, me in split(k.props[n], lo, hi, cut):
			pn = "%s_p%d" % (n, len(made) + 1)
			game[pn] = "%s_p%d" % (game[n], len(made) + 1)
			plo, phi = bounds(me)
			centres[pn] = ((plo[0] + phi[0]) / 2, plo[1], (plo[2] + phi[2]) / 2)
			rel = [centres[pn][i] - centres[n][i] for i in range(3)]
			box_lo = [lo[i] + cell[i] * step[i] - centres[n][i] for i in range(3)]
			box_hi = [lo[i] + (cell[i] + 1) * step[i] - centres[n][i] for i in range(3)]
			ppts = piece_parts(parent["all_parts"], box_lo, box_hi, FALLBACK_PARTS["hero" if parent["hero"] else "mid"], fill)
			for q in ppts:
				q["Pos"] = tuple(q["Pos"][i] - rel[i] for i in range(3))
			me.calc_loop_triangles()
			props[pn] = {"partsOnly": False, "tris": len(me.loop_triangles), "size": tuple(phi[i] - plo[i] for i in range(3)), "count": parent["count"], "hero": parent["hero"], "parts": ppts, "piece": game[n]}
			ob = bpy.data.objects.new(me.name, me)
			bpy.context.scene.collection.objects.link(ob)
			objs[pn] = ob
			made.append((pn, rel))
		pieces[n] = made
		print("SPLIT %s %s %s at scale %s: %d pieces %s" % (biome, game[n], "x".join(map(str, cut)), [round(x, 3) for x in big], len(made), [props[pn]["tris"] for pn, _ in made]))
		out = []
		for q in kept:
			name, pos, e, sc = q[:4]
			if name != n:
				out.append(q)
				continue
			R = from_euler_yxz(*e)
			group += 1  # the game builds or skips a placement's pieces together, on the whole prop's base (`pos`)
			for pn, rel in made:
				off = [sum(R[i][j] * rel[j] * sc[j] for j in range(3)) for i in range(3)]
				out.append((pn, tuple(pos[i] + off[i] for i in range(3)), e, sc, (group, pos)))
				big_axis = max(props[pn]["size"][i] * sc[i] for i in range(3))
				assert big_axis < 2048, (pn, big_axis)
		kept = out
	names = [n for n in names if n not in pieces] + [pn for made in pieces.values() for pn, _ in made]
	# biggest first, so the game's part budget trims the small props (BiomeDressing builds the heroes before them)
	kept.sort(key=lambda p: -(props[p[0]]["size"][0] * props[p[0]]["size"][2] * p[3][0] * p[3][2]))
	lights = sorted(((to_local(origin, yaw, p), col, e) for p, col, e in rec["lights"]), key=lambda x: -x[2])
	meshes = [n for n in names if not props[n]["partsOnly"] and props[n]["count"] > 0]  # a never-placed mesh needs no asset
	for n in meshes:
		if glb:
			key = "W2_%s_%s" % (biome, game[n])
			reason = "new: piece of %s over 2048 studs" % props[n]["piece"] if "piece" in props[n] else "new: first export"
			write_glb(objs.get(n) or k.props[n], centres[n], os.path.join(folder, key + ".glb"), changed, key, reason)
	for n in pieces:  # the whole mesh is replaced by its pieces
		old = os.path.join(folder, "W2_%s_%s.glb" % (biome, game[n]))
		if os.path.exists(old):
			os.remove(old)
	breaches = []
	designed = {props[n].get("piece", game[n]) for n in meshes}  # the cap counts designed props, not pieces
	if len(designed) > CAPS["unique"]:
		breaches.append("unique meshes %d > %d" % (len(designed), CAPS["unique"]))
	for n, p in props.items():
		if p["partsOnly"]:
			continue
		cap = CAPS["hero" if p["hero"] else "mid"]
		if p["tris"] > cap:
			breaches.append("%s %s tris %d > %d" % (game[n], "hero" if p["hero"] else "mid", p["tris"], cap))
		if p["count"] == 0:
			warns.append("%s: never placed" % game[n])
		if p["hero"] and "piece" not in p and max(p["size"][0], p["size"][2]) > 60:
			warns.append("%s: hero footprint %.0f x %.0f > 60 x 60 (placeholder, spec 4.3)" % (game[n], p["size"][0], p["size"][2]))
	manifest = {
		"Track": number,
		"Biome": biome,
		"Props": {
			"W2_%s_%s" % (biome, game[n]): dict(
				{"Prop": game[n], "Tris": p["tris"], "Hero": p["hero"], "Size": [round(x, 2) for x in p["size"]], "Placements": p["count"], "File": "W2_%s_%s.glb" % (biome, game[n]) if glb else None},
				**({"PieceOf": p["piece"]} if "piece" in p else {}),
			)
			for n, p in ((n, props[n]) for n in names)
			if not p["partsOnly"] and p["count"] > 0
		},
		"PartsOnly": {game[n]: props[n]["count"] for n in names if props[n]["partsOnly"]},
		"RoadTest": road,
		"Lights": len(lights),
		"Breaches": breaches,
		"Warnings": warns[:20] + (["... %d more" % (len(warns) - 20)] if len(warns) > 20 else []),
	}
	with open(os.path.join(folder, "manifest.json"), "w") as f:
		json.dump(manifest, f, indent=1)
	props = {game[n]: props[n] for n in names}
	kept = [(game[q[0]],) + tuple(q[1:]) for q in kept]
	write_luau(biome, number, props, kept, lights, rec, os.path.join(THEMES, biome + "Draft.luau"), [game[h] for h in heroes])
	print("EXPORT", json.dumps(manifest))
	return manifest, changed


def id_re(key):
	"""A ledger row with an Id; groups 1 and 2 surround the Id, group 3 is its Reviewed value."""
	return re.compile(r"(\t\t%s = draftMesh\(\n\t\t\t\d+,\n\t\t\t)\"rbxassetid://\d+\"(, -- Id[^\n]*\n\t\t\t)(nil|\"[^\"]*\")" % re.escape(key))


def write_needs_upload(rows):
	"""Merges rows {biome: [(key, reason)]} (GLBs this run made new or changed) into NEEDS_UPLOAD and adds every
	exported mesh whose ledger row is missing or has no Id. A row stays until its ledger row has an Id, so a rerun
	that finds a GLB unchanged does not forget it still needs its audit and upload. No bpy:
	python3 tools/blender/world2/export_props.py --needs-upload"""
	import glob

	import upload_props

	table = {}
	if os.path.exists(NEEDS_UPLOAD):
		for line in open(NEEDS_UPLOAD):
			f = line.rstrip("\n").split("\t")
			if len(f) == 3 and f[0] != "biome":
				table[(f[0], f[1])] = f[2]
	for biome, rs in rows.items():
		for key, reason in rs:
			table[(biome, key)] = reason
	# The uploaded GLB's geometry hash per key (UPLOADED, 5th column; geometry_info). A GLB whose geometry differs from the
	# uploaded one would ship the old mesh: its ledger Id and Reviewed are cleared and it stays listed until uploaded again.
	# A row with no hash yet takes the GLB's, unless this run changed that GLB (then the upload was of the old bytes).
	geometry_self_test()
	rows_up = [line.rstrip("\n").split("\t") for line in open(UPLOADED) if line.strip()] if os.path.exists(UPLOADED) else []
	up = {(r[0], r[1]): r for r in rows_up}
	import subprocess

	# a GLB rewritten after the upload log was committed changed after its upload (write_glb keeps equal bytes untouched)
	since = float(subprocess.run(["git", "log", "-1", "--format=%ct", "--", UPLOADED], cwd=ROOT, capture_output=True, text=True).stdout.strip() or "inf")
	changed_now = {(b, key) for b, rs in rows.items() for key, reason in rs if reason.startswith("changed")}
	for path in glob.glob(os.path.join(EXPORT, "*", "manifest.json")):
		manifest = json.load(open(path))
		biome = manifest["Biome"]
		ledger = os.path.join(THEMES, biome + ".luau")
		src = open(ledger).read() if os.path.exists(ledger) else ""
		for key, p in manifest["Props"].items():
			glb = os.path.join(EXPORT, biome, p["File"] or "")
			r = up.get((biome, key))
			if r and os.path.isfile(glb) and not upload_props.row_re(key).search(src) and ("\t\t%s = draftMesh(" % key) in src:
				sha = geometry_info(glb)[0]
				if len(r) >= 5 and r[4] == upload_props.sha256(glb):
					r[4] = sha  # an older row's byte sha of this same GLB: same upload, now stored as its geometry hash
				if len(r) < 5 and (biome, key) not in changed_now and os.path.getmtime(glb) <= since:
					r.append(sha)
				elif (r[4] if len(r) >= 5 else None) != sha:
					src, n = id_re(key).subn(lambda m: "%snil%snil" % (m.group(1), m.group(2)), src)
					assert n == 1, (key, n)
					open(ledger, "w").write(src)
					table[(biome, key)] = "changed since upload: GLB sha differs, ledger Id and Reviewed cleared"
					continue
			if ("\t\t%s = draftMesh(" % key) not in src:
				table.setdefault((biome, key), "new: no ledger row yet (Tris %d)" % p["Tris"])
			elif upload_props.row_re(key).search(src):
				table.setdefault((biome, key), "not uploaded yet: the ledger row has no Id (Tris %d)" % p["Tris"])
			else:
				table.pop((biome, key), None)  # uploaded: its ledger row has an Id
		for (b, key) in [bk for bk in table if bk[0] == biome and bk[1] not in manifest["Props"]]:
			del table[(b, key)]  # no longer exported (a mesh replaced by its pieces)
	with open(UPLOADED, "w") as f:
		f.write("".join("\t".join(r) + "\n" for r in rows_up))
	with open(NEEDS_UPLOAD, "w") as f:
		f.write("biome\tkey\treason\n" + "".join("%s\t%s\t%s\n" % (b, k, r) for (b, k), r in sorted(table.items())))


def main():
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
	if "--needs-upload" in argv:
		return write_needs_upload({})
	nums = [a for a in argv if not a.startswith("--")]
	numbers = sorted(APPROVED) if nums in ([], ["approved"]) else [int(a) for a in nums]
	if "--plan" in argv:  # report only: writes nothing
		zone = next((int(a.split("=")[1]) for a in argv if a.startswith("--zone=")), None)
		for n in numbers:
			export(n, glb=False, plan=True, zone=zone)
		return
	rows = {}
	for n in numbers:
		_, changed = export(n, glb="--no-glb" not in argv)
		rows[APPROVED[n]] = changed
	write_needs_upload(rows)

if __name__ == "__main__":
	main()
