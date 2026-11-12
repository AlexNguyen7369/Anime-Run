# Blender draft of the Golden King's own arena (design doc 4.37 "The Golden King's own arena", owner 2026-11-12; BOSS_EVENT_SPEC
# "Animation rework", bullet "The Golden King's arena"; goal boss-anim-rework, a7). Owner look reference only: nothing here ships.
# Headless:
#   Blender -b --factory-startup --python tools/blender/arena/build_king_arena.py -- [shot ...]
# 1 Blender unit = 1 stud, floor at z = 0, ring centre at the origin, runs counter-clockwise from above. Its own build, not the
# colosseum shell: only helpers are shared (build_arena's mesh builder, build_colosseum's part counter, placement and lane camera,
# build_vault's weapon, urn, gem and contact-sheet builders). No real names: the boss stand-in is "KingStandIn".
# Look: the owner's concept image of 2026-11-12 (art-backup/anime_refs/boss_king/arena_concept_2026-11-12.png; look-only, never
# shipped, never traced): an open-air sandstone stadium at sunset, orange-pink sky with purple clouds and sun rays from behind the
# stands; a podium wall of round arch bays holding gold; three tiers of stands with blue runner stairways; a top arcade of round
# arches against the sky; a great gate with a blue and gold glazed arch, a rayed fan and crenellated towers, flanked by two winged
# lion statues with crowned, bearded human heads on tall plinths; a distant stepped tower through the gate; tall red banners with
# a gold winged sun (our own emblem) between banded columns; a paved floor with blue meander bands edged in gold; ruins with gold,
# chests, crowns, goblets, sun-burst shields, swords and gems; a stepped mound of stone blocks buried in gold in the centre, the
# king hovering above it.
# Gameplay numbers (all proposed, BOSS_EVENT_SPEC): ring inner radius 110, 7 lanes of 8 (outer edge 166), wall foot (the podium's
# face) at 250, about 867 studs a lap on lane 4. The king is 44 studs (8 x a character) and hovers 12 studs over the mound's top.
# Nothing stands on the lanes; inside the ring only the mound reaches above 12 studs (checked at the end of the build).
# Writes build/arena/king_arena_draft.blend and renders assets/arena_draft/KingArena_*.png plus a contact sheet.
#
# Prop list (Roblox part estimate; the script prints the measured count per group as "PARTS"):
#   Floor             ~45   stacked discs for the paving, lanes and lane lines (smaller on top), 16 + 24 meander band slabs
#                           (blue with a gold key texture), the outside ground; paving and meander as textures
#   Podium bays      38 x 3 = 114   one arch-head mesh, one pier, one gold heap per 9 degree bay of the podium wall
#   Stands           38 x 4 = 152   per bay: 3 tier wedges (steps as a texture; here drawn as steps) and the top walk
#   Arcade           38 x 3 = 114   top arcade: pier, arch-head mesh, attic block per bay
#   Stairways         4 x 4 =  16   grand stairs up the podium (2 flanking the gate, 2 opposite)
#   Aisles           10 x 3 =  30   blue runners down the 3 tiers
#   Columns          20 x 5 = 100   shaft, base, 2 blue-and-gold bands, capital; in pairs, a banner hung between each pair
#   Banners          10 x 6 =  60   gold rod, red cloth, pointed foot, winged sun emblem (disc, 2 wing meshes)
#   Gate              ~60   2 towers (block + wedge, bands, glazed panel, 7 merlons each), arch wall, archivolt, rayed fan, merlons
#   Statues           2 x 17 = 34   plinth with a blue band, lion body, legs, chest, beard, crowned head, 2 wing meshes, tail
#   Far tower         ~7    the stepped tower outside, through the gate
#   Stand treasure   ~36    gold heaps and open chests on the first tier
#   Inner ruins      6 x ~17       column stump, broken pier, blocks, gold heap, chest, goblet, shield, sword, gems; all under 12 studs
#   Outer ruins      6 x ~16       broken arch or wall, stump, blocks, gold heap, chest, shield, crown, gems; between the lanes and the podium
#   Centre mound      ~95   4 stepped tiers of stone blocks, gold heaps, 2 big chests, a big sun shield, crowns, goblets, swords, spears, gems
#   Total target about 1,200 (proposed); the run prints the real sum. Lights are not parts: the sun, and a soft gold glow on the king.
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_arena as ba  # noqa: E402  (guarded mains: importing only defines helpers)
import build_colosseum as bc  # noqa: E402
import build_vault as bv  # noqa: E402
from build_arena import aim, pol  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
MU, put, place = bc.MU, bc.put, bc.place

# --- Gameplay geometry (BOSS_EVENT_SPEC, proposed) ---
R_IN, LANES, LANE_W = 110.0, 7, 8.0
R_OUT = R_IN + LANES * LANE_W  # 166
R_WALL = 250.0  # the podium's face, the wall foot
CHAR_H = 5.5
KING_H, HOVER = 8 * CHAR_H, 12.0
INNER_MAX_H = 12.0  # nothing inside the ring but the mound stands higher than this
TH0 = math.radians(-100)  # the followed runners' spot: the lane cameras look across the mound at the gate and the sun

# --- The stadium (proposed, this draft) ---
SEG = 40  # bays around: 9 degrees each
SEG_A = math.tau / SEG
GATE_A = math.radians(90)
POD_H = 20.0  # podium wall
TIER_D, TIER_H, TIERS = 22.0, 16.0, 3  # each tier: 4 steps and a banded parapet
R_STAND = R_WALL + 6  # first tier starts behind the podium's top walk
R_TOP = R_STAND + TIERS * TIER_D  # 322
Z_TOP = POD_H + TIERS * TIER_H  # 68
ARC_Z0, ARC_TOP = Z_TOP, Z_TOP + 38  # the top arcade: 68 to 106
BANNER_AS = [GATE_A + s * math.radians(d) for d in (27, 63, 99, 135, 171) for s in (-1, 1)]
AISLE_AS = [GATE_A + s * math.radians(d) for d in (45, 81, 117, 153) for s in (-1, 1)] + [GATE_A + math.pi]
STAIR_AS = [GATE_A + math.radians(d) for d in (-17, 17, 163, 197)]
SUN_A, SUN_E = math.radians(62), math.radians(11)  # the lamp; the sky's drawn sun sits lower, behind the stands
RES = bc.RES

bc.R_IN, bc.R_OUT, bc.R_WALL, bc.TH0 = R_IN, R_OUT, R_WALL, TH0  # bc.player_pose and bc.runners read these
bc.LANE_W, bc.CAM_BACK = LANE_W, 40.0

PAL = dict(ba.PAL)
PAL.update(
	{
		"sand": "#D2A874", "sand2": "#C49766", "sandLo": "#A87C52", "sandHi": "#E2BC88", "sandOut": "#C8955E", "recess": "#3A2420",
		"laneA": "#D8B88A", "laneB": "#CBA97C", "laneLine": "#E9C35A", "blue": "#2C3C9C", "blue2": "#1E2A78",
		"gold": "#E8B23C", "gold2": "#C08A2A", "goldHi": "#FFD86A", "goldMound": "#FFC845",
		"banner": "#A41E2A", "banner2": "#7A1220", "steel": "#D4D6DC", "hilt": "#5A3A22", "chest": "#7A3A1E", "chestBlue": "#24307E",
		"chestRed": "#9A1E24", "gemR": "#E0203A", "gemB": "#2A62E8", "gemG": "#22B05A", "urn": "#8E5A3A", "urn2": "#5C3A26",
		"statue": "#D8A862", "statueLo": "#A8783C", "zig": "#D29A78", "zig2": "#BA8466",
		"kingGold": "#F2C230", "kingNavy": "#1E2240", "kingSkin": "#F1D6C0", "kingHair": "#FFE27A", "kingRed": "#C0141E",
		"overlay": "#FFFFFF",
	}
)


def T(v):
	return Matrix.Translation(v)


def R(a, axis):
	return Matrix.Rotation(a, 4, axis)


def S(s):
	return Matrix.Scale(s, 4)


def in_gate(a, half=SEG_A):
	return abs((a - GATE_A + math.pi) % math.tau - math.pi) < half - 1e-6


SEG_KEEP = [k for k in range(SEG) if not in_gate((k + 0.5) * SEG_A)]


# --- Textures and materials ---
def np_image(name, img):
	h, w, _ = img.shape
	bimg = bpy.data.images.new(name, w, h, alpha=False)
	bimg.pixels.foreach_set(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32).ravel())
	bimg.pack()
	return bimg


def hexc(h):
	return np.array([int(h[i : i + 2], 16) for i in (1, 3, 5)], float) / 255


def tex_material(name, image, scale, box=True, uv=False):
	"""Image on object coordinates (scale studs a repeat, box projected), or on the mesh UVs. Closest filter: flat, blocky texels."""
	m = bpy.data.materials.new(name)
	nt = m.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	tex = nt.nodes.new("ShaderNodeTexImage")
	tex.image, tex.interpolation = image, "Closest"
	if not uv:
		tc, mp = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeMapping")
		mp.inputs["Scale"].default_value = (1 / scale,) * 3
		nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
		nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
		if box:
			tex.projection, tex.projection_blend = "BOX", 0.0
	nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	bsdf.inputs["Roughness"].default_value = 0.9
	ba._mats[name] = m


def paving():
	"""16 studs a repeat: 4 x 4 sandstone pavers, staggered rows, shaded, thin dark joints."""
	px, n = 16, 16
	w = n * px
	rng = np.random.default_rng(12)
	U, V = np.meshgrid((np.arange(w) + 0.5) / px, (np.arange(w) + 0.5) / px)
	img = np.tile(hexc("#D9B88E"), (w, w, 1))
	for row in range(4):
		off = (row % 2) * 2
		for col in range(-1, 5):
			x0 = off + col * 4
			sel = (V >= row * 4) & (V < row * 4 + 4) & (U >= x0) & (U < x0 + 4)
			img[sel] *= rng.uniform(0.88, 1.06)
			img[(np.abs(U - x0) < 0.09) & (V >= row * 4) & (V < row * 4 + 4)] *= 0.78
		img[np.abs(V - row * 4) < 0.09] *= 0.78
	return np_image("KingPaving", img)


def masonry():
	"""Large sandstone block courses for walls: 8 x 4 stud blocks, staggered, 16 studs a repeat."""
	px, n = 12, 16
	w = n * px
	rng = np.random.default_rng(5)
	U, V = np.meshgrid((np.arange(w) + 0.5) / px, (np.arange(w) + 0.5) / px)
	img = np.tile(hexc("#CFA170"), (w, w, 1))
	for row in range(4):
		off = (row % 2) * 4
		for col in range(-1, 3):
			x0 = off + col * 8
			sel = (V >= row * 4) & (V < row * 4 + 4) & (U >= x0) & (U < x0 + 8)
			img[sel] *= rng.uniform(0.86, 1.07)
			img[(np.abs(U - x0) < 0.1) & (V >= row * 4) & (V < row * 4 + 4)] *= 0.72
		img[np.abs(V - row * 4) < 0.1] *= 0.72
	return np_image("KingMasonry", img)


def glazed():
	"""The gate's glazed brick: deep blue courses with a gold rosette row (our pattern), 8 studs a repeat."""
	px, n = 16, 8
	w = n * px
	U, V = np.meshgrid((np.arange(w) + 0.5) / px, (np.arange(w) + 0.5) / px)
	img = np.tile(hexc("#2C3C9C"), (w, w, 1))
	for row in range(4):
		img[(V >= row * 2) & (V < row * 2 + 2) & (((U + (row % 2)) // 2) % 2 == 0)] *= 0.86
		img[np.abs(V - row * 2) < 0.07] *= 0.7
	ros = ((U - 4) ** 2 + (V - 5) ** 2 < 0.8**2) | ((np.abs(U - 4) < 0.25) & (np.abs(V - 5) < 1.4)) | ((np.abs(V - 5) < 0.25) & (np.abs(U - 4) < 1.4))
	img[ros] = hexc("#F0C040")
	img[np.abs(V - 1) < 0.18] = hexc("#F0C040")
	return np_image("KingGlazed", img)


def meander():
	"""One repeat of the floor band: a blue band, a gold Greek-key line, gold edges. u: 12 studs along the band, v: 0-1 across it."""
	px = 16
	w, h = 12 * px, 10 * px  # the band is 10 studs wide
	U, V = np.meshgrid((np.arange(w) + 0.5) / px, (np.arange(h) + 0.5) / px)
	img = np.tile(hexc("#2E3A96"), (h, w, 1))
	g = np.zeros((h, w), bool)
	g |= (V < 0.7) | (V > 9.3)  # gold edges
	t = 0.55
	key = [((0, 2.5), (0, 7.5)), ((0, 7.5), (8, 7.5)), ((8, 7.5), (8, 4)), ((8, 4), (3.5, 4)), ((3.5, 4), (3.5, 5.5)), ((3.5, 5.5), (5.5, 5.5)),
		((0, 2.5), (11, 2.5)), ((11, 2.5), (11, 7.5)), ((11, 7.5), (12, 7.5))]
	for (x1, y1), (x2, y2) in key:
		g |= (U >= min(x1, x2) - t) & (U <= max(x1, x2) + t) & (V >= min(y1, y2) - t) & (V <= max(y1, y2) + t)
	img[g] = hexc("#EAB840")
	return np_image("KingMeander", img)


def vnoise(U, V, gx, gy, seed):
	"""Smooth value noise, wrapping in U (0-1)."""
	g = np.random.default_rng(seed).random((gy + 2, gx))
	x, y = U * gx, V * gy
	x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
	fx, fy = x - x0, y - y0
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	x0 %= gx
	x1 = (x0 + 1) % gx
	y0 = np.clip(y0, 0, gy)
	y1 = np.clip(y0 + 1, 0, gy + 1)
	a = g[y0, x0] * (1 - fx) + g[y0, x1] * fx
	b = g[y1, x0] * (1 - fx) + g[y1, x1] * fx
	return a * (1 - fy) + b * fy


def sky_image():
	"""Equirectangular sunset (Blender's mapping): a gradient by elevation, a low sun with rays, purple clouds lit at the edges."""
	w, h = 2048, 1024
	u = (np.arange(w) + 0.5) / w
	v = (np.arange(h) + 0.5) / h
	U, V = np.meshgrid(u, v)
	az = (0.5 - U) * math.tau  # world angle atan2(y, x)
	el = (V - 0.5) * math.pi
	es = math.radians(4)
	cos_t = np.cos(el) * math.cos(es) * np.cos(az - SUN_A) + np.sin(el) * math.sin(es)
	th = np.degrees(np.arccos(np.clip(cos_t, -1, 1)))
	# Orange and gold stay under about 8 degrees, behind the stands; from 10 to 25 degrees, where the lane cameras see the king,
	# the sky is already violet, so his gold reads against it (the backdrop change for visibility).
	stops = [(-90, "#6A4048"), (0, "#FFBC62"), (3, "#FF9C5A"), (7, "#F27C76"), (12, "#BE5E98"), (18, "#8A4C9C"), (30, "#5C3E8E"), (55, "#34306E"), (90, "#1E2054")]
	ed = np.degrees(el)
	xs = [s[0] for s in stops]
	img = np.stack([np.interp(ed, xs, [hexc(s[1])[c] for s in stops]) for c in range(3)], axis=2)
	away = (0.5 - 0.5 * np.cos(az - SUN_A))[..., None]  # 0 at the sun's azimuth, 1 opposite: pinker, dimmer
	img = img * (1 - 0.25 * away) + hexc("#C06A9A") * 0.12 * away * (ed[..., None] > 0)
	# Clouds: streaky value noise in a band, dark purple, gold-pink where the sun is near
	n = 0.55 * vnoise(U, V, 24, 40, 1) + 0.3 * vnoise(U, V, 64, 90, 2) + 0.15 * vnoise(U, V, 160, 200, 3)
	band = np.clip((ed - 5) / 6, 0, 1) * np.clip((60 - ed) / 20, 0, 1)
	c = np.clip((n - 0.5) / 0.14, 0, 1) * band
	lit = np.exp(-th / 30)[..., None]
	cloud = hexc("#4A2E6A") * (1 - lit) + hexc("#FF9C6C") * lit
	img = img * (1 - 0.85 * c[..., None]) + cloud * 0.85 * c[..., None]
	# The sun: a disc, a glow and rays fanning from it
	east = np.cos(el) * np.sin(az - SUN_A)
	up = np.sin(el) * math.cos(es) - np.cos(el) * math.sin(es) * np.cos(az - SUN_A)
	psi = np.arctan2(east, up)
	rays = (0.5 + 0.5 * np.cos(psi * 11 + 2.5 * vnoise(U, V, 8, 4, 9))) ** 4 * np.exp(-th / 24) * (ed > 0)
	glow = np.exp(-th / 6) * 0.7 + np.exp(-th / 2.0) * 1.4 + (th < 1.5) * 2.0
	img += hexc("#FFE0A0") * glow[..., None] + hexc("#FFB070") * (0.22 * rays)[..., None]
	return np_image("KingSky", img)


def glow(name, color, strength):
	bc.glow(name, color, strength)


def metallize():
	bv.metallize()
	bsdf = next(n for n in ba._mats["kingGold"].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Metallic"].default_value, bsdf.inputs["Roughness"].default_value = 0.3, 0.5  # flat, as the Roblox plate reads
	bsdf.inputs["Emission Color"].default_value = ba.rgb("#F2C230")
	bsdf.inputs["Emission Strength"].default_value = 0.25  # the soft gold glow
	for name in ("gemG", "chestBlue"):
		if name in ba._mats:
			next(n for n in ba._mats[name].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = 0.2 if name == "gemG" else 0.5


# --- Mesh helpers ---
def ocyl(m, r, h, mtx, material, n=12, r2=None):
	"""A cylinder along the local Z of mtx."""
	m.parts += 1
	r2 = r if r2 is None else r2
	lo = [mtx @ Vector((r * math.cos(k / n * math.tau), r * math.sin(k / n * math.tau), 0)) for k in range(n)]
	hi = [mtx @ Vector((r2 * math.cos(k / n * math.tau), r2 * math.sin(k / n * math.tau), h)) for k in range(n)]
	for k in range(n):
		m.face([lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]], material)
	m.face(lo[::-1], material)
	m.face(hi, material)


def hexa(m, pts, material):
	"""A solid from 8 corners: bottom 4 then top 4, both counter-clockwise from above."""
	m.parts += 1
	b, t = pts[:4], pts[4:]
	m.face(b[::-1], material)
	m.face(t, material)
	for k in range(4):
		m.face([b[k], b[(k + 1) % 4], t[(k + 1) % 4], t[k]], material)


def arch_wall(m, x0, x1, w, oh, zs, top, material, inner=None, n=8):
	"""A wall slab across Y (|y| <= oh) from zs to top, with a round arch of half width w springing at zs; front at x0, back at x1."""
	m.parts += 1
	crown = zs + w
	arc = [(-w * math.cos(math.pi / 2 * k / n), zs + w * math.sin(math.pi / 2 * k / n)) for k in range(n + 1)]  # (-w, zs) up to the crown
	for s in (-1, 1):
		seq = [(s * oh, zs), (s * w, zs)] + [(s * -y, z) for y, z in arc[1:]] + [(0, top)]
		corner = (s * oh, top)
		for x in (x0, x1):
			for p, q in zip(seq, seq[1:]):
				m.face([(x, *corner), (x, *p), (x, *q)], material)
		ring = [(s * w, zs)] + [(s * -y, z) for y, z in arc[1:]]
		for p, q in zip(ring, ring[1:]):
			m.face([(x0, *p), (x0, *q), (x1, *q), (x1, *p)], inner or material)
		m.face([(x0, s * oh, zs), (x0, s * oh, top), (x1, s * oh, top), (x1, s * oh, zs)], material)
	m.face([(x0, -oh, top), (x0, oh, top), (x1, oh, top), (x1, -oh, top)], material)
	assert crown < top


def arc_band(m, r1, r2, a1, a2, z, material, segs, u_len=12.0):
	"""A flat curved band from a1 to a2 with UVs: u runs u_len studs a repeat along the middle, v 0-1 across."""
	rm = (r1 + r2) / 2
	for k in range(segs):
		a, b = a1 + (a2 - a1) * k / segs, a1 + (a2 - a1) * (k + 1) / segs
		ua, ub = rm * (a - a1) / u_len, rm * (b - a1) / u_len
		m.face([pol(r1, a, z), pol(r2, a, z), pol(r2, b, z), pol(r1, b, z)], material, [(ua, 0), (ua, 1), (ub, 1), (ub, 0)])
		m.parts += 1


def disc_ring(m, r1, r2, z, material, n=96):
	if r1 <= 0:
		m.face([pol(r2, k / n * math.tau, z) for k in range(n)], material)
		return
	for k in range(n):
		a, b = k / n * math.tau, (k + 1) / n * math.tau
		m.face([pol(r1, a, z), pol(r2, a, z), pol(r2, b, z), pol(r1, b, z)], material)


# --- Treasure props (bv's weapon, urn and gem builders are reused) ---
def chest(m, c, yaw, s=1.0, body="chest"):
	"""An open chest: body, lid tipped back, gold top of coins, gold front band. 3 parts."""
	mt = T(c) @ R(yaw, "Z") @ S(s)
	m.obox((3.2, 2.2, 1.8), mt @ T((0, 0, 0.9)), body)
	m.obox((3.3, 2.3, 0.5), mt @ T((0, 1.1, 1.8)) @ R(-1.83, "X") @ T((0, -1.15, 0.25)), body)
	m.obox((2.9, 1.9, 0.6), mt @ T((0, 0, 1.75)), "goldHi")
	m.obox((3.3, 0.2, 0.5), mt @ T((0, -1.1, 1.3)), "gold")
	m.parts -= 1  # the coin top is the body's top face in game


def gem(m, c, material, s=1.0):
	m.obox((0.9 * s, 0.9 * s, 0.9 * s), T(c) @ R(0.8, "X") @ R(0.6, "Y"), material)


def gem_spill(m, c, s=1.0, seed=0):
	rng = random.Random(seed)
	for k, name in enumerate(("gemR", "gemB", "gemG")):
		a = rng.uniform(0, math.tau)
		gem(m, (c[0] + 1.6 * s * math.cos(a), c[1] + 1.6 * s * math.sin(a), c[2] + 0.3 * s), name, s)


def crown(m, c, s=1.0):
	x, y, z = c
	m.cyl(1.7 * s, 1.2 * s, (x, y, z), "gold", n=10, r2=1.95 * s)
	for k in range(5):
		a = k / 5 * math.tau
		m.box((0.45 * s, 0.45 * s, 0.9 * s), (x + 1.8 * s * math.cos(a), y + 1.8 * s * math.sin(a), z + 1.5 * s), "gold")
	m.cyl(1.55 * s, 0.9 * s, (x, y, z + 0.4 * s), "chestRed", n=10)
	m.parts -= 4  # in game: the band with its points as one mesh, the red cap


def goblet(m, c, s=1.0):
	x, y, z = c
	m.cyl(0.9 * s, 0.3 * s, (x, y, z), "gold", n=10)
	m.cyl(0.25 * s, 1.3 * s, (x, y, z + 0.3 * s), "gold", n=6)
	m.cyl(0.55 * s, 1.4 * s, (x, y, z + 1.55 * s), "gold", n=10, r2=1.15 * s)
	m.parts -= 1  # foot and stem as one


def shield(m, c, yaw, tilt, r):
	"""A round sun-burst shield standing on its rim, leaning back by tilt, its face toward yaw."""
	mt = T(c) @ R(yaw, "Z") @ R(math.pi / 2 - tilt, "Y")
	ocyl(m, r, 0.6, mt, "gold", n=16)
	ocyl(m, r * 0.82, 0.12, mt @ T((0, 0, 0.6)), "blue", n=16)
	for k in range(12):  # the sun: long and short gold rays on the blue field (a decal in game)
		a = k / 12 * math.tau
		w, tip = (0.2, 0.8) if k % 2 == 0 else (0.13, 0.55)
		p = lambda rr, aa: mt @ Vector((rr * r * math.cos(aa), rr * r * math.sin(aa), 0.78))
		m.face([p(0.18, a - w), p(tip, a), p(0.18, a + w)], "goldHi")
	ocyl(m, r * 0.2, 0.5, mt @ T((0, 0, 0.7)), "gold", n=10)


def heap(m, r, c, squash=0.42, seed=0, jitter=0.15):
	ba.rng.seed(seed)
	m.blob(r, c, "goldMound", squash=squash, jitter=jitter)
	m.parts += 1


def stump(m, c, r, h, band=True):
	"""A broken round column: base block, shaft, a blue band with gold edges."""
	x, y, z = c
	m.box((r * 2.4, r * 2.4, 1.2), (x, y, z + 0.6), "sandLo")
	m.cyl(r, h, (x, y, z + 1.2), "sand", n=10)
	if band:
		m.cyl(r + 0.2, 1.4, (x, y, z + 1.2 + h * 0.62), "blue", n=10)
		m.cyl(r + 0.25, 0.3, (x, y, z + 1.2 + h * 0.62 + 1.4), "gold", n=10)
		m.parts -= 1  # band and its edge as one textured cylinder
	m.cyl(r * 0.95, 0.8, (x, y, z + 1.2 + h), "sand2", n=7, r2=r * 0.7)  # the broken top
	m.parts -= 1


def blocks(m, c, n, size, seed, spread=4.0, mats=("sand", "sand2", "sandLo")):
	rng = random.Random(seed)
	for _ in range(n):
		s = rng.uniform(*size)
		p = (c[0] + rng.uniform(-spread, spread), c[1] + rng.uniform(-spread, spread), c[2] + s * 0.38)
		m.obox((s * rng.uniform(0.9, 1.5), s, s * rng.uniform(0.6, 0.9)), T(p) @ R(rng.uniform(0, math.tau), "Z") @ R(rng.uniform(-0.25, 0.25), "X"), rng.choice(mats))


# --- The floor ---
def floor():
	m = MU("KingFloor", "floor")
	disc_ring(m, 0, R_WALL + 1, -0.3, "sandLo")  # underlay: the unwelded ring quads leave hairline cracks that showed the sky
	disc_ring(m, 0, 52, 0, "pave")
	m.parts += 1
	for r1, r2, mat_ in ((52, 53, "gold"), (53, 58, "blue"), (58, 59, "gold"), (59, 92, "pave"), (102, R_IN - 0.5, "pave"), (R_IN - 0.5, R_IN, "laneLine")):
		disc_ring(m, r1, r2, 0, mat_)
		m.parts += 1
	for i in range(1, LANES + 1):
		r1, r2 = R_IN + (i - 1) * LANE_W, R_IN + i * LANE_W
		disc_ring(m, r1, r2 - 0.5, 0, "laneA" if i % 2 else "laneB")
		disc_ring(m, r2 - 0.5, r2, 0, "laneLine")
		m.parts += 2
	disc_ring(m, R_OUT, 176, 0, "pave")
	disc_ring(m, 188, R_WALL + 0.5, 0, "pave")
	m.parts += 3
	put(m, bpy.context.scene.collection)
	# Meander bands: a full ring just inside the lanes, four arcs outside them with gaps at the stairways (as the concept)
	b = MU("KingMeander", "floor")
	arc_band(b, 92, 102, 0, math.tau, 0, "meander", 16, u_len=12)
	for k in range(4):
		a0 = GATE_A + math.radians(-90 * k)
		arc_band(b, 176, 188, a0 + math.radians(22), a0 + math.radians(68), 0, "meander", 6, u_len=12)
	gaps = MU("KingFloorGaps", "floor")
	for k in range(4):
		a0 = GATE_A + math.radians(-90 * k)
		for a1, a2 in ((a0 - math.radians(22), a0 + math.radians(22)),):
			for j in range(8):
				a, bb = a1 + (a2 - a1) * j / 8, a1 + (a2 - a1) * (j + 1) / 8
				gaps.face([pol(176, a, 0), pol(188, a, 0), pol(188, bb, 0), pol(176, bb, 0)], "pave")
	put(b, bpy.context.scene.collection)
	put(gaps, bpy.context.scene.collection)
	g = MU("KingGround", "floor")  # outside the stadium, seen through the gate
	disc_ring(g, R_WALL + 0.5, 3000, 0, "sandOut", n=96)
	g.parts += 1
	put(g, bpy.context.scene.collection)


# --- The stadium: built per 9 degree bay around +X, cloned round, the gate's two bays left open ---
def podium_bay():
	"""The podium wall: a round arch bay (dark recess, a gold heap inside) and a pier, a blue-and-gold band, its top walk."""
	m = MU("KingPodiumBay", "podium bays")
	x0, x1 = R_WALL * math.cos(SEG_A / 2), R_STAND
	oh = R_WALL * math.sin(SEG_A / 2) + 0.4
	w, zs = 10.0, 5.0
	arch_wall(m, x0, x0 + 3, w, oh, zs, POD_H - 4, "masonry", inner="sand2")
	for s in (-1, 1):
		m.box((3, oh - w, zs), (x0 + 1.5, s * (oh + w) / 2, zs / 2), "masonry")
	m.box((x1 - x0 - 3, 2 * oh, POD_H - 4), (x0 + 3 + (x1 - x0 - 3) / 2, 0, (POD_H - 4) / 2), "recess")  # dark inside of the bay
	m.box((3.2, 2 * oh, 0.6), (x0 + 1.4, 0, POD_H - 3.7), "gold")
	m.box((3.2, 2 * oh, 2.2), (x0 + 1.4, 0, POD_H - 2.3), "blue")
	m.box((3.2, 2 * oh, 0.6), (x0 + 1.4, 0, POD_H - 0.9), "gold")
	m.box((x1 - x0 + 0.5, 2 * oh + 0.4, 0.6), (x0 + (x1 - x0) / 2, 0, POD_H - 0.3), "sandHi")
	heap(m, 6.5, (x0 + 6, 0, 0), squash=0.55, seed=int(x0 * 7))
	chest(m, (x0 + 5, 4.5, 2.5), math.pi / 2 + 0.3, 1.2, "chest")
	m.parts = 3  # in game: the arch head mesh with its band as a texture, a pier, the gold heap (the chest is a bonus: cut first)
	return m


def stands_bay():
	"""Three tiers of 4 steps (one textured wedge each in game), a blue-banded parapet on each, the top walk and the back wall."""
	m = MU("KingStandsBay", "stands")
	half = SEG_A / 2 + 0.003  # a hair of overlap: no sun leaking through the joints
	segs = []  # (r1, z1, r2, z2, material); the podium's top walk is the podium bay's
	r, z = R_STAND, POD_H
	for t in range(TIERS):
		for s in range(4):
			segs.append((r, z, r, z + 2.4, "sandLo"))  # riser
			z += 2.4
			segs.append((r, z, r + TIER_D / 4, z, "sandHi"))  # tread
			r += TIER_D / 4
		if t < TIERS - 1:
			for dz, mat_ in ((0.8, "gold"), (3.6, "blue"), (2.0, "sand")):
				segs.append((r, z, r, z + dz, mat_))
				z += dz
		else:
			segs.append((r, z, r, Z_TOP, "sand"))
			z = Z_TOP
	segs += [(r, Z_TOP, r + 8, Z_TOP, "sandHi"), (r + 8, Z_TOP, r + 8, 0, "masonry")]
	assert abs(z - Z_TOP) < 1e-6 and abs(r - R_TOP) < 1e-6, (z, r)
	for r1, z1, r2, z2, mat_ in segs:
		m.face([pol(r1, -half, z1), pol(r2, -half, z2), pol(r2, half, z2), pol(r1, half, z1)], mat_)
	m.parts = 4
	return m


def arcade_bay():
	"""The top arcade: one round arch per bay against the sky, a pier at the bay's edge, an attic block with a gold line."""
	m = MU("KingArcadeBay", "arcade")
	x0 = R_TOP * math.cos(SEG_A / 2)
	oh = R_TOP * math.sin(SEG_A / 2) + 0.6
	w, zs = oh - 5.0, ARC_Z0 + 8
	arch_wall(m, x0, x0 + 5, w, oh, zs, ARC_TOP - 5, "masonry", inner="sand2")
	for s in (-1, 1):
		m.box((5, oh - w, zs - ARC_Z0), (x0 + 2.5, s * (oh + w) / 2, (ARC_Z0 + zs) / 2), "masonry")
	m.box((7, 2 * oh + 0.6, 5), (x0 + 2.5, 0, ARC_TOP - 2.5), "sand")
	m.box((7.2, 2 * oh + 0.7, 0.7), (x0 + 2.5, 0, ARC_TOP - 4.6), "gold")
	m.parts = 3
	return m


def column():
	"""A banded column on the podium's top walk: base, shaft, two blue bands edged gold, a block capital. Built at +X."""
	m = MU("KingColumn", "columns")
	x, z0, h = R_WALL + 3.2, POD_H, 40.0
	m.box((5.4, 5.4, 1.6), (x, 0, z0 + 0.8), "sandHi")
	m.cyl(2.1, h, (x, 0, z0 + 1.6), "sand", n=10)
	for zb in (z0 + 13, z0 + 30):
		m.cyl(2.35, 2.6, (x, 0, zb), "blue", n=10)
		m.cyl(2.4, 0.5, (x, 0, zb + 2.6), "gold", n=10)
		m.cyl(2.4, 0.5, (x, 0, zb - 0.5), "gold", n=10)
		m.parts -= 2  # one textured band
	m.cyl(2.6, 1.4, (x, 0, z0 + h + 1.6), "gold", n=10, r2=3.2)
	m.box((6.4, 6.4, 1.6), (x, 0, z0 + h + 3.8), "sandHi")
	m.parts -= 1
	return m


def banner():
	"""A red banner between two columns: gold rod, cloth, pointed foot, our winged sun emblem (disc, two stepped wings, crown)."""
	m = MU("KingBanner", "banners")
	x, w, z1, z2 = R_WALL + 0.4, 12.0, POD_H + 10, POD_H + 40
	m.box((0.8, 2 * R_WALL * math.sin(math.radians(2.6)), 0.8), (x + 2.6, 0, z2 + 1.2), "gold")  # rod, column to column
	m.box((0.5, w, z2 - z1), (x, 0, (z1 + z2) / 2), "banner")
	m.face([(x - 0.26, -w / 2, z1), (x - 0.26, w / 2, z1), (x - 0.26, 0, z1 - 6)], "banner")
	m.face([(x + 0.26, -w / 2, z1), (x + 0.26, w / 2, z1), (x + 0.26, 0, z1 - 6)], "banner")
	m.parts += 1
	m.box((0.3, w + 0.2, 0.5), (x - 0.2, 0, z2 - 0.6), "gold")
	m.parts -= 1  # the hem is the cloth's texture
	ex, cz = x - 0.4, z1 + 17
	disc = [Vector((ex, 1.7 * math.cos(k / 12 * math.tau), cz + 1.7 * math.sin(k / 12 * math.tau))) for k in range(12)]
	m.face(disc, "gold")
	m.parts += 1
	for s in (-1, 1):  # wings: three stepped feathers sweeping up and out
		for j, (ln, dz) in enumerate(((4.6, 0.9), (3.6, -0.5), (2.6, -1.8))):
			y0 = s * 1.4
			m.face([(ex, y0, cz + dz + 0.6), (ex, y0 + s * ln, cz + dz + 1.6 + (2 - j) * 0.5), (ex, y0 + s * ln, cz + dz + 0.7 + (2 - j) * 0.5), (ex, y0, cz + dz - 0.5)], "gold")
		m.parts += 1
	m.face([(ex, -0.7, cz - 1.6), (ex, 0.7, cz - 1.6), (ex, 1.2, cz - 5), (ex, 0, cz - 4), (ex, -1.2, cz - 5)], "gold")  # tail
	for k in range(3):  # a small crown over the sun
		m.face([(ex, -1.3 + k * 1.3 - 0.35, cz + 2.0), (ex, -1.3 + k * 1.3 + 0.35, cz + 2.0), (ex, -1.3 + k * 1.3, cz + 3.4)], "gold")
	m.face([(ex, -1.6, cz + 1.6), (ex, 1.6, cz + 1.6), (ex, 1.6, cz + 2.1), (ex, -1.6, cz + 2.1)], "gold")
	return m


def stairway():
	"""A grand stair from the floor up the podium, built at +X: a sloped flight with a blue runner, two side walls with gold caps."""
	m = MU("KingStair", "stairways")
	x0, x1, hw = R_WALL - 24, R_WALL * math.cos(SEG_A / 2) + 0.5, 8.0
	steps = 8
	for k in range(steps):
		xa = x0 + (x1 - x0) * k / steps
		m.box((x1 - xa, 2 * hw, POD_H / steps), (xa + (x1 - xa) / 2, 0, POD_H / steps * (k + 0.5)), "sandHi" if k % 2 else "sand")
	rise = math.atan2(POD_H, x1 - x0)
	ln = math.hypot(POD_H, x1 - x0)
	m.obox((ln, 6, 0.4), T(((x0 + x1) / 2, 0, POD_H / 2 + 0.25)) @ R(-rise, "Y"), "blue")
	for s in (-1, 1):
		y1, y2 = s * hw, s * (hw + 2.5)
		hexa(m, [Vector(p) for p in ((x0 - 1, y1, 0), (x0 - 1, y2, 0), (x1, y2, 0), (x1, y1, 0), (x0 - 1, y1, 3), (x0 - 1, y2, 3), (x1, y2, POD_H + 3), (x1, y1, POD_H + 3))], "masonry")
	m.parts = 4  # in game: a stair wedge with a step texture, the runner, two side walls
	return m


def aisle():
	"""A blue runner down the three tiers, built at +X."""
	m = MU("KingAisle", "aisles")
	for t in range(TIERS):
		r1 = R_STAND + t * TIER_D
		z1 = POD_H + t * (4 * 2.4 + 6.4)
		r2, z2 = r1 + TIER_D, z1 + 4 * 2.4
		rise, ln = math.atan2(z2 - z1, r2 - r1), math.hypot(z2 - z1, r2 - r1)
		m.obox((ln, 5.0, 0.6), T(((r1 + r2) / 2, 0, (z1 + z2) / 2 + 0.9)) @ R(-rise, "Y"), "blue")
	return m


def gate():
	"""The great gate at +X: two crenellated towers along the radial lines of the open bays, a glazed arch wall with an archivolt
	and a rayed fan, merlons on top. The opening looks out to the stepped tower."""
	m = MU("KingGate", "gate")
	xf, xb, inner, H = R_WALL - 8, R_TOP + 10, 24.0, ARC_TOP + 8  # towers stand forward of the podium face, over the stands' cut ends
	for s in (-1, 1):
		y_f, y_b = inner + 24, max(inner + 24, xb * math.tan(SEG_A * 1.06))
		pts = [(xf, s * inner), (xf, s * y_f), (xb, s * y_b), (xb, s * inner)]
		if s < 0:
			pts = pts[::-1]
		hexa(m, [Vector((x, y, 0)) for x, y in pts] + [Vector((x, y, H)) for x, y in pts], "masonry")
		y_out = y_f
		yc, ww = s * (inner + y_out) / 2, y_out - inner
		m.box((0.6, ww - 3, 34), (xf - 0.3, yc, 52), "glazed")  # the glazed panel on the tower front
		for zb in (30, H - 14):
			m.box((1.0, ww + 0.2, 3.0), (xf - 0.5, yc, zb), "blue")
			m.box((1.2, ww + 0.4, 0.6), (xf - 0.6, yc, zb + 1.8), "gold")
			m.box((1.2, ww + 0.4, 0.6), (xf - 0.6, yc, zb - 1.8), "gold")
			m.parts -= 2
		for k in range(4):  # merlons along the front
			m.box((4, ww / 4 - 1.6, 5), (xf + 2, s * (inner + (k + 0.5) * ww / 4), H + 2.5), "sandHi")
		for k in range(3):  # and down the inner side
			m.box((6, 3, 5), (xf + 14 + k * 22, s * (inner + 1.5), H + 2.5), "sandHi")
	# The arch wall between the towers
	x0, x1, w, zs = R_WALL - 6, R_WALL + 10, 11.0, 34.0
	arch_wall(m, x0, x1, w, inner, zs, ARC_TOP - 8, "glazed", inner="blue2")
	for s in (-1, 1):
		m.box((x1 - x0, inner - w, zs), (x0 + (x1 - x0) / 2, s * (inner + w) / 2, zs / 2), "glazed")
	m.parts += 1
	# Archivolt: gold, blue, gold rings around the opening; a rayed fan of gold and blue over it
	xa = x0 - 0.3
	for r1, r2, mat_, dx in ((w, w + 1.0, "gold", 0.3), (w + 1.0, w + 3.4, "blue", 0.2), (w + 3.4, w + 4.4, "gold", 0.3), (w + 4.4, inner - 0.5, "fan", 0.0)):
		n = 16
		for k in range(n):
			a, b = math.pi * k / n, math.pi * (k + 1) / n
			mm = mat_ if mat_ != "fan" else ("goldHi" if k % 2 else "blue")
			m.face([(xa - dx, r1 * math.cos(a), zs + r1 * math.sin(a)), (xa - dx, r2 * math.cos(a), zs + r2 * math.sin(a)), (xa - dx, r2 * math.cos(b), zs + r2 * math.sin(b)), (xa - dx, r1 * math.cos(b), zs + r1 * math.sin(b))], mm)
		m.parts += 1
	for s in (-1, 1):
		m.box((0.8, 4.4, zs), (xa - 0.2, s * (w + 2.2), zs / 2), "blue")
		m.box((1.0, 0.8, zs), (xa - 0.3, s * (w + 4.0), zs / 2), "gold")
		m.parts -= 1
	m.box((1.0, 2 * inner, 3), (xa - 0.3, 0, ARC_TOP - 14), "gold")
	for k in range(5):
		m.box((4, 4.2, 5), (x0 + 2, -inner + 3.6 + k * (2 * inner - 7.2) / 4, ARC_TOP - 5.5), "sandHi")
	return m


def statue(side):
	"""A winged lion with a crowned, bearded human head (our blocky design) on a tall banded plinth, in front of a tower, facing
	the arena centre (-X). Built in the gate's frame."""
	m = MU("KingStatue", "statues")
	cx = R_WALL - 24
	cy = side * 33.0
	m.box((15, 32, 22), (cx, cy, 11), "masonry")  # long along Y: the lion stands side-on to the arena, walking away from the gate
	m.box((16, 33, 2), (cx, cy, 23), "sandHi")
	m.box((15.4, 32.4, 2.6), (cx, cy, 18.5), "blue")
	m.box((15.6, 32.6, 0.5), (cx, cy, 20.0), "gold")
	m.parts -= 1
	z = 24
	n0 = len(m.v)
	for dx in (-5.2, 5.2):
		for dy in (-2.4, 2.4):
			m.box((2.6, 2.4, 6), (cx + dx, cy + dy, z + 3), "statue")
	m.box((15, 7, 7), (cx + 0.5, cy, z + 9.5), "statue")  # body
	m.box((5, 7.6, 10), (cx - 6, cy, z + 10.5), "statue")  # chest
	m.box((3.6, 4.4, 4), (cx - 8, cy, z + 16.5), "statue")  # neck
	m.box((4.8, 4.8, 5.4), (cx - 9.2, cy, z + 20), "statue")  # head
	m.cyl(2.7, 3.2, (cx - 9.2, cy, z + 22.7), "gold", n=8, r2=3.0)  # crown
	for k in range(4):
		a = k / 4 * math.tau + math.pi / 4
		m.box((0.9, 0.9, 1.4), (cx - 9.2 + 2.6 * math.cos(a), cy + 2.6 * math.sin(a), z + 26.6), "gold")
	m.parts -= 4
	for s in (-1, 1):  # wings: two stacked slabs sweeping up and back from the shoulders
		for j, (ln, lift, zz) in enumerate(((16, 0.6, 15.5), (13, 0.4, 13.0), (10, 0.22, 10.8))):
			mt = T((cx - 5, cy + s * (3.9 + j * 0.7), z + zz)) @ R(-lift, "Y") @ T((ln / 2, 0, 0))
			m.obox((ln, 0.9, 3.8 - j * 0.7), mt, ("statue", "statueLo", "gold")[j])
		m.parts -= 1  # a wing is 2 meshes
	m.obox((1.2, 1.2, 6), T((cx + 8.5, cy, z + 9)) @ R(0.5, "Y"), "statue")  # tail
	c, k = Vector((cx, cy, z)), 1.45  # the lion at 1.45 x its blocks: as tall as the gate's arch
	turn = R(-side * math.pi / 2, "Z")  # its front (-X as built) turned to face away from the gate along the wall
	m.v[n0:] = [c + turn @ ((p - c) * k) for p in m.v[n0:]]
	head = c + turn @ (Vector((-9.2, 0, 20)) * k)
	m.box((2.2, 4.6, 6.6), tuple(head + Vector((-3.6, 0, -4.4))), "statueLo")  # the beard, on the face turned to the arena
	m.box((0.8, 6.2, 1.0), tuple(head + Vector((-3.6, 0, 1.0))), "statueLo")  # brow
	m.box((0.6, 1.0, 0.6), tuple(head + Vector((-3.7, -1.4, -0.4))), "recess")  # eyes
	m.box((0.6, 1.0, 0.6), tuple(head + Vector((-3.7, 1.4, -0.4))), "recess")
	m.parts -= 2
	return m


def far_tower(parent):
	"""The stepped tower out past the gate (hazy colours)."""
	m = MU("KingFarTower", "far tower")
	z = 0
	for k, (w, h) in enumerate(((110, 22), (84, 20), (60, 20), (40, 18), (24, 16))):
		m.box((w, w, h), (440, 0, z + h / 2), "zig" if k % 2 == 0 else "zig2")
		z += h
	m.box((14, 14, 12), (440, 0, z + 6), "blue")
	m.box((15, 15, 1), (440, 0, z + 12.5), "gold")
	ob = put(m, parent)
	ob.matrix_world = R(GATE_A, "Z")


# --- Ruins and treasure ---
def inner_ruins(parent):
	"""Six low groups between the mound and the lanes (r 66 to 100). Every top stays under INNER_MAX_H."""
	rng = random.Random(4)
	for i in range(6):
		a = math.radians(30 + 60 * i)
		m = MU("KingRuinIn", "inner ruins")
		c = pol(80, a, 0)
		t = Vector((-math.sin(a), math.cos(a), 0))
		o = lambda dr, dt, z=0: c + pol(dr, a, 0) + t * dt + Vector((0, 0, z))
		heap(m, 7.5, o(0, 0), squash=0.4, seed=60 + i)
		stump(m, o(-4, -9), 2.6, rng.uniform(5, 8.5))
		m.box((4.5, 4.5, 9.5), tuple(o(5, 9, 4.75)), "sand")  # a broken pier
		m.obox((7, 4.4, 2.2), T(o(5.5, 7.5, 10.2)) @ R(a, "Z") @ R(0.28, "X"), "sand2")  # a fallen springer on it
		blocks(m, o(2, -4), 4, (1.8, 3.6), seed=70 + i, spread=5)
		chest(m, o(-2, 4, 1.4), a + 1.4, 1.1, ("chestBlue", "chestRed", "chest")[i % 3])
		goblet(m, o(-5, 1, 1.0))
		shield(m, o(-6.5, -3, 0.2), a + math.pi, 0.35, 3.2)
		bv.weapon(m, o(1, 2, 1.6), rng.uniform(0, math.tau), rng.uniform(0.15, 0.35), "sword", 1.0)
		gem_spill(m, o(-3, 6, 0.6), 1.0, seed=i)
		put(m, parent, a)


def outer_ruins(parent):
	"""Six groups between the lanes' outer edge and the podium (r 212 to 244), clear of the gate, stairs and banners: a broken
	arch or a low broken wall, a column stump, blocks, gold, a chest, a shield, a crown, gems."""
	rng = random.Random(14)
	for i, deg in enumerate((45, 135, 207, 243, 297, 333)):
		a = math.radians(deg)
		m = MU("KingRuinOut", "outer ruins")
		c = pol(228, a, 0)
		t = Vector((-math.sin(a), math.cos(a), 0))
		o = lambda dr, dt, z=0: c + pol(dr, a, 0) + t * dt + Vector((0, 0, z))
		heap(m, 8, o(0, 2), squash=0.45, seed=80 + i)
		if i % 2 == 0:  # a broken arch: two piers, one springer still standing
			for s in (-1, 1):
				m.box((4.5, 4.5, 15 if s < 0 else 10), tuple(o(4, s * 8, 7.5 if s < 0 else 5)), "sand")
				m.box((5.2, 5.2, 1.4), tuple(o(4, s * 8, (15 if s < 0 else 10) - 4)), "blue")
			for k in range(3):
				p, q = o(4, -8 + 2.6 * k, 15 + 1.9 * k), o(4, -8 + 2.6 * (k + 1), 15 + 1.9 * (k + 1) - 0.6 * k)
				m.beam(p, q, 4.2, "sand2")
			m.parts -= 2
		else:  # a low broken wall
			for k in range(4):
				m.box((4, 5.2, 7 - k * 1.3), tuple(o(5, -8 + k * 5.4, (7 - k * 1.3) / 2)), "masonry")
			m.box((4.2, 21.6, 1.2), tuple(o(5, -1.6 + 0, 3.0)), "blue")
			m.parts -= 2
		stump(m, o(-6, -10), 2.8, rng.uniform(6, 10))
		blocks(m, o(-2, 8), 4, (2, 4), seed=90 + i, spread=5)
		chest(m, o(-4, -3, 1.2), a + math.pi / 2 + 0.4, 1.3, ("chestBlue", "chestRed")[i % 2])
		shield(m, o(-7, 5, 0.2), a + math.pi + 0.3, 0.4, 3.6)
		crown(m, o(-3, 4, 2.6), 0.9)
		gem_spill(m, o(-6, 0, 0.6), 1.1, seed=20 + i)
		bv.urn(m, o(2, -9, 0), 1.1)
		put(m, parent, a)


def stand_treasure(parent):
	"""Gold heaps and open chests on the first tier's treads, between the columns."""
	m = MU("KingStandGold", "stand treasure")
	k = 0
	for i in range(SEG):
		a = (i + 0.5) * SEG_A
		if in_gate(a, SEG_A * 1.6) or i % 2:
			continue
		heap(m, 4.2, pol(R_STAND + 7.5, a, POD_H + 4.8), squash=0.5, seed=100 + i)
		if k % 2 == 0:
			chest(m, pol(R_STAND + 7.5, a + 0.035, POD_H + 4.8), a + math.pi / 2, 1.3, "chestBlue")
		k += 1
	put(m, parent)


def centre_mound(parent):
	"""Four stepped tiers of stone blocks (4 jittered blocks each, turned against each other) buried in gold, with treasure."""
	m = MU("KingMound", "centre mound")
	rng = random.Random(31)
	z = 0.0
	for k, (half, h) in enumerate(((34, 7.0), (26, 7.0), (19, 7.0), (12, 7.0), (7, 5.0))):
		rot = R(math.radians(45 * (k % 2) + 8), "Z")
		for qx in (-1, 1):
			for qy in (-1, 1):
				hh = h + rng.uniform(-0.8, 0.8) if k < 4 else h
				c = rot @ Vector((qx * half / 2 + rng.uniform(-1, 1), qy * half / 2 + rng.uniform(-1, 1), z + hh / 2))
				m.obox((half * rng.uniform(0.92, 1.04), half * rng.uniform(0.92, 1.04), hh), T(c) @ rot @ R(rng.uniform(-0.05, 0.05), "Z"), ("sand", "sand2", "sandLo", "sand")[(qx + qy + k) % 4])
		z += h
	top_stone = z
	# Gold pouring over the steps
	for i in range(8):
		a = i / 8 * math.tau + 0.2
		heap(m, 12, pol(34, a, 0), squash=0.42, seed=200 + i)
	for i in range(7):
		a = i / 7 * math.tau + 0.5
		heap(m, 8.5, pol(25, a, 7.0), squash=0.45, seed=210 + i)
	for i in range(5):
		a = i / 5 * math.tau + 0.9
		heap(m, 6.5, pol(17, a, 14.0), squash=0.5, seed=220 + i)
	for i in range(3):
		a = i / 3 * math.tau + 1.3
		heap(m, 5.0, pol(10, a, 21.0), squash=0.5, seed=225 + i)
	heap(m, 6.5, (0, 0, top_stone - 1.0), squash=0.55, seed=230)  # the gold cap he hovers over
	heap(m, 34, (0, 0, 0), squash=0.42, seed=231, jitter=0.08)  # the gold the lower tiers are buried in
	blocks(m, (0, 0, 0), 10, (2.5, 5), seed=33, spread=44)
	# Treasure stuck in it, facing round
	chest(m, pol(28, 0.6, 7.4), 0.6 + math.pi / 2, 2.8, "chestBlue")
	chest(m, pol(27, 3.4, 7.4), 3.4 + math.pi / 2, 2.4, "chestRed")
	chest(m, pol(20, 5.0, 14.4), 5.0 + math.pi / 2, 2.0, "chestBlue")
	shield(m, pol(38, 2.0, 0.5), 2.0, 0.3, 7.5)
	shield(m, pol(37, 4.6, 0.5), 4.6, 0.35, 5.5)
	for a, r, zz, s in ((1.2, 38, 3.5, 1.5), (4.0, 37, 3.5, 1.4), (5.6, 24, 9.2, 1.3)):
		crown(m, pol(r, a, zz), s)
	for a, r, zz in ((0.2, 40, 2.8), (2.6, 39, 2.8), (3.9, 25, 9.6), (5.3, 38, 2.8)):
		goblet(m, pol(r, a, zz), 1.7)
	for a, r, zz, kind, s in ((0.4, 15, 15.5, "sword", 2.0), (1.9, 14, 15.5, "spear", 1.4), (2.9, 23, 8.6, "sword", 1.8), (3.9, 9, 22.0, "spear", 1.5), (4.9, 25, 8.6, "sword", 1.7), (5.9, 13, 16.0, "sword", 1.9), (1.0, 31, 5.0, "sword", 1.5)):
		bv.weapon(m, pol(r, a, zz), a + rng.uniform(-0.4, 0.4), rng.uniform(0.12, 0.3), kind, s)
	for i in range(6):
		gem_spill(m, pol(rng.uniform(22, 40), i * 1.05 + 0.3, 3.0 if i % 2 else 8.5), 1.3, seed=40 + i)
	ob = put(m, parent)
	top = max((ob.matrix_world @ v.co).z for v in ob.data.vertices if v.co.x**2 + v.co.y**2 < 4**2)
	foot = max(math.hypot(v.co.x, v.co.y) for v in ob.data.vertices if v.co.z < 1.0)
	return ob, top, foot


def king(parent, z_top):
	"""Stand-in (never a real name): a gold block figure with a red cape, arms folded, 44 studs, hovering HOVER over the mound."""
	b = MU("KingStandIn", "boss stand-in")
	for s in (-1, 1):
		b.box((0.9, 0.9, 2.4), (s * 0.5, 0, 1.2), "kingGold")
		b.box((1.0, 1.0, 0.4), (s * 0.5, 0, 2.3), "kingNavy")
		b.box((0.95, 0.95, 1.0), (s * 0.5, 0, 2.9), "kingGold")  # skirt plates
	b.box((2.0, 1.0, 2.0), (0, 0, 4.0), "kingGold")
	b.box((2.2, 1.1, 0.4), (0, 0, 3.2), "kingNavy")
	for s in (-1, 1):
		b.box((1.2, 1.2, 0.8), (s * 1.45, 0, 4.85), "kingGold")
		b.box((0.8, 0.8, 1.2), (s * 1.3, -0.1, 3.5), "kingGold")
	b.box((2.4, 0.7, 0.7), (0, -0.75, 3.9), "kingGold")
	b.obox((2.8, 0.25, 5.0), T((0, 0.75, 2.8)) @ R(-0.12, "X"), "kingRed")  # the cape, flaring back
	b.box((1.2, 1.2, 1.2), (0, 0, 5.6), "kingSkin")
	b.box((1.3, 1.3, 0.5), (0, 0.05, 6.35), "kingHair")
	for s in (-1, 0, 1):
		b.obox((0.4, 0.4, 1.1), T((s * 0.45, 0.1, 6.9)) @ R(s * 0.5, "Y") @ R(-0.35, "X"), "kingHair")
	b.box((0.5, 0.05, 0.14), (0, -0.62, 5.75), "kingRed")
	ob = put(b, parent)
	feet = z_top + HOVER
	ob.matrix_world = R(TH0 + math.pi / 2, "Z") @ T((0, 0, feet)) @ S(KING_H / 7.45)
	zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
	print(f"KING stand-in: feet {min(zs):.1f} to hair top {max(zs):.1f} = {max(zs) - min(zs):.1f} studs, {min(zs) - z_top:.1f} over the mound top {z_top:.1f}")
	return ob, min(zs), max(zs)


# --- Lights, sky, cameras ---
def setup(scene, feet, head):
	for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
		try:
			scene.render.engine = eng
			break
		except TypeError:
			pass
	scene.eevee.taa_render_samples = 48
	scene.render.resolution_x, scene.render.resolution_y = RES
	scene.render.image_settings.file_format = "PNG"
	scene.view_settings.view_transform = "AgX"
	scene.view_settings.look = "AgX - Punchy"
	world = bpy.data.worlds.new("KingSunset")
	scene.world = world
	nt = world.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	env = nt.nodes.new("ShaderNodeTexEnvironment")
	env.image = sky_image()
	mix = nt.nodes.new("ShaderNodeMix")  # the camera sees the drawn sky; everything else is lit by a soft warm-violet ambience
	mix.data_type = "RGBA"
	mix.inputs["A"].default_value = ba.rgb("#C09888")
	nt.links.new(nt.nodes.new("ShaderNodeLightPath").outputs["Is Camera Ray"], mix.inputs["Factor"])
	nt.links.new(env.outputs["Color"], mix.inputs["B"])
	nt.links.new(mix.outputs["Result"], bg.inputs["Color"])
	bg.inputs["Strength"].default_value = 1.0
	sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
	d = Vector((math.cos(SUN_E) * math.cos(SUN_A), math.cos(SUN_E) * math.sin(SUN_A), math.sin(SUN_E)))
	sun.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
	sun.data.energy, sun.data.color, sun.data.angle = 5.5, (1.0, 0.68, 0.42), math.radians(3.0)
	scene.collection.objects.link(sun)
	for k in range(3):  # the king's soft gold glow (a PointLight in game): from around him, no shadows
		lt = bpy.data.objects.new("KingGlow", bpy.data.lights.new("KingGlow", "POINT"))
		lt.location = pol(18, TH0 + k * math.tau / 3, (feet + head) / 2)
		lt.data.color, lt.data.energy, lt.data.shadow_soft_size, lt.data.use_shadow = (1.0, 0.85, 0.5), 7000, 6, False
		scene.collection.objects.link(lt)
	ng = bpy.data.node_groups.new("KingComp", "CompositorNodeTree")
	ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
	rl, glare, out = ng.nodes.new("CompositorNodeRLayers"), ng.nodes.new("CompositorNodeGlare"), ng.nodes.new("NodeGroupOutput")
	glare.inputs["Type"].default_value = "Bloom"
	glare.inputs["Threshold"].default_value = 1.0
	glare.inputs["Size"].default_value = 0.8
	glare.inputs["Strength"].default_value = 0.35
	glare.name = "Glare"
	ng.links.new(rl.outputs["Image"], glare.inputs["Image"])
	ng.links.new(glare.outputs["Image"], out.inputs["Image"])
	scene.compositing_node_group = ng
	cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
	cam.data.sensor_fit = "VERTICAL"
	cam.data.clip_start, cam.data.clip_end = 0.3, 6000
	scene.collection.objects.link(cam)
	scene.camera = cam
	return cam


def plan_overlay(parent):
	"""Rings and labels for the top-down plan: ring inner and outer edge, wall foot, top of the stands."""
	obs = []
	glow("overlayMat", "#FFFFFF", 1.6)
	for r, label in ((R_IN, f"ring r {R_IN:.0f}"), (R_OUT, f"lanes out r {R_OUT:.0f}"), (R_WALL, f"wall foot r {R_WALL:.0f}"), (R_TOP, f"stands top r {R_TOP:.0f}")):
		m = MU("PlanOverlay", "overlay")
		disc_ring(m, r - 0.9, r + 0.9, ARC_TOP + 12, "overlayMat", n=128)
		obs.append(m.build(parent))
		cu = bpy.data.curves.new("PlanLabel", "FONT")
		cu.body, cu.size, cu.align_x = label, 14, "CENTER"
		cu.materials.append(ba._mats["overlayMat"])
		t = bpy.data.objects.new("PlanOverlayText", cu)
		t.location = (0, -r + 7, ARC_TOP + 13)
		parent.objects.link(t)
		obs.append(t)
	return obs


def shots():
	"""(name, eye, look, fov, ortho scale or 0, label)"""
	e4, l4, _ = bc.player_pose(4)
	e1, l1, _ = bc.player_pose(1)
	e7, l7, _ = bc.player_pose(7)
	opp = GATE_A + math.pi
	return [
		("KingArena_01_lane4", e4, l4, 100, 0, "Lane 4 runner camera (yaw 75, pitch 4, 40 back)"),
		("KingArena_02_lane1", e1, l1, 100, 0, "Lane 1 runner camera"),
		("KingArena_03_lane7", e7, l7, 100, 0, "Lane 7 runner camera"),
		("KingArena_04_establishing", pol(R_STAND + 8, opp - math.radians(22), POD_H + 9), Vector((-12, 60, 46)), 46, 0, "Establishing: from the first tier opposite the gate"),
		("KingArena_05_plan", Vector((0, 0, 900)), Vector((0, 0.01, 0)), 0, 2 * (R_TOP + 40), "Plan: ring 110-166, wall foot 250, stands top 322"),
		("KingArena_06_gate", pol(150, GATE_A - math.radians(24), 16), pol(R_WALL - 10, GATE_A + math.radians(1), 44), 62, 0, "The gate and the winged lion statues"),
		("KingArena_07_mound", pol(106, TH0 - 0.25, 12), Vector((0, 0, 44)), 62, 0, "The centre mound with the king stand-in hovering"),
	]


def checks(king_ob, mound_ob, mound_foot):
	"""Nothing on the lanes; inside the ring nothing but the mound and the king above INNER_MAX_H; the mound clear of the ring."""
	bad = []
	for ob, _ in bc.PLACED:
		if ob.name.startswith(("KingFloor", "KingMeander", "KingGround", "Runner", "KingStandIn", "PlanOverlay")):
			continue
		for v in ob.data.vertices:
			p = ob.matrix_world @ v.co
			r = math.hypot(p.x, p.y)
			if R_IN - 0.3 < r < R_OUT + 0.3 and p.z > 0.05:
				bad.append(f"{ob.name} on the lanes at r {r:.1f} z {p.z:.1f}")
				break
			if r < R_IN and p.z > INNER_MAX_H and ob is not mound_ob:
				bad.append(f"{ob.name} {p.z:.1f} high inside the ring at r {r:.1f}")
				break
	assert mound_foot < R_IN - 20, mound_foot
	assert not bad, "\n".join(bad)
	print(f"CHECK lanes clear, inner props under {INNER_MAX_H:.0f} studs, mound foot r {mound_foot:.1f}")


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	ba._mats.clear()
	bc.PLACED.clear()
	bc._parts.clear()
	ba.PAL.clear()
	ba.PAL.update(PAL)
	os.makedirs(ba.OUT, exist_ok=True)
	os.makedirs(ba.BUILD, exist_ok=True)
	scene = bpy.context.scene
	coll = scene.collection
	tex_material("pave", paving(), 16)
	tex_material("masonry", masonry(), 16)
	tex_material("glazed", glazed(), 8)
	tex_material("meander", meander(), 1, uv=True)

	floor()
	keep = [(k + 0.5) * SEG_A for k in SEG_KEEP]
	place(podium_bay(), keep, coll)
	place(stands_bay(), keep, coll)
	place(arcade_bay(), keep, coll)
	place(column(), [a + s * math.radians(2.6) for a in BANNER_AS for s in (-1, 1)], coll)
	place(banner(), BANNER_AS, coll)
	place(aisle(), AISLE_AS, coll)
	place(stairway(), STAIR_AS, coll)
	place(gate(), [GATE_A], coll)
	for side in (-1, 1):
		place(statue(side), [GATE_A], coll)
	far_tower(coll)
	stand_treasure(coll)
	inner_ruins(coll)
	outer_ruins(coll)
	mound_ob, top, foot = centre_mound(coll)
	king_ob, feet, head = king(coll, top)
	bc.runners(coll)
	metallize()
	checks(king_ob, mound_ob, foot)

	skip = {"runners", "boss stand-in", "overlay"}
	for k, v in sorted(bc._parts.items()):
		if k not in skip:
			print(f"PARTS {k}: {v}")
	print(f"PARTS total (Roblox primitive rebuild, rough): {sum(v for k, v in bc._parts.items() if k not in skip)}")
	print(f"GEOMETRY ring {R_IN:.0f}-{R_OUT:.0f}, lane 4 lap {math.tau * bc.lane_r(4):.0f} studs, wall foot {R_WALL:.0f}, stands top r {R_TOP:.0f} z {Z_TOP:.0f}, arcade top {ARC_TOP:.0f}, gate towers {ARC_TOP + 8 + 5:.0f}; mound top {top:.1f}, foot r {foot:.1f}; king feet {feet:.1f}, head {head:.1f}")

	cam = setup(scene, feet, head)
	overlay = plan_overlay(coll)
	bpy.context.preferences.filepaths.save_version = 0
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ba.BUILD, "king_arena_draft.blend"))
	for lane in (1, 4, 7):
		e, l, back = bc.player_pose(lane)
		aim(cam, e, l, 100)
		h, ok, topy = bc.boss_px(cam, [king_ob])
		print(f"PX lane {lane}: eye r {math.hypot(e.x, e.y):.1f}, camera {back:.1f} back; king {h:.0f}px tall at {RES[0]}x{RES[1]}, top {1 - topy:.0%} from the frame top, clear of the HP bar {ok}")
	done = []
	for name, eye, look, fov, ortho, label in shots():
		if ARGV and name not in ARGV:
			continue
		for o in overlay:
			o.hide_render = not ortho
		cam.data.type = "ORTHO" if ortho else "PERSP"
		scene.compositing_node_group.nodes["Glare"].inputs["Strength"].default_value = 0 if ortho else 0.35
		if ortho:
			cam.data.ortho_scale = ortho
			cam.location, cam.rotation_euler = eye, (0, 0, 0)
		else:
			aim(cam, eye, look, fov)
		scene.render.filepath = os.path.join(ba.OUT, name + ".png")
		bpy.ops.render.render(write_still=True)
		print("SHOT", scene.render.filepath)
		done.append((scene.render.filepath, label))
	if len(done) == len(shots()):
		bv.sheet(done, os.path.join(ba.OUT, "KingArena_contact_sheet.png"))


if __name__ == "__main__":
	main()
