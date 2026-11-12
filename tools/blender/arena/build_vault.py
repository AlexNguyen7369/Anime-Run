# Blender draft of the treasure vault: the mage colosseum shell re-dressed for the third boss (design doc 4.37 "Third boss",
# BOSS_EVENT_SPEC "The Golden King" Arena row, evidence docs/char_evidence/boss_king.md "Vault"; goal boss-king, k3). Owner look
# reference only: nothing here ships. Headless:
#   Blender -b --factory-startup --python tools/blender/arena/build_vault.py -- [shot ...]
# The shell (floor, lanes, wall pieces, pillars, doors, dome, cameras) is build_colosseum.py's, imported, with its wall moved to the
# in-game 164 behind the walkway and 3 low stands. Lanes, ring, wall radius, walkway and the boss spot are not moved. Only the
# palette, the wall tile and the props are new. No real names: the boss stand-in is "KingStandIn".
# Look: the owner's vault reference (art-backup/anime_refs/boss_king, the treasure-room shot; look-only): grey-brown stone brick,
# round arches on short columns, torches in iron brackets between the arches, gold-on-brown banners with a diamond emblem, a gold
# door, open chests of coins and gems, coin heaps along every wall, a round stepped stone dais under the boss's gold heap, warm
# torch light under a dark cave ceiling. It replaces the design doc's proposed "sandstone pointed arches, red drapes" list.
# Writes build/arena/vault_draft.blend and renders to assets/arena_draft/Vault2_*.png (pass 2; pass 1 is Vault_*.png), plus the
# plain shell for comparison.
#
# Prop list (Roblox part estimate for k8; the shell itself is 1,030 parts in game, cap 1,150):
#   Arch bays        22 x  7 =  154   2 short columns, 2 capitals, round head (in game a half cylinder + a recess-coloured one), dark recess box
#   Bay chests       22 x  3 =   66   open chest (box + tilted lid, gold top face) and 2 gems, one in each arch bay at the wall foot
#   Banners          10 x  4 =   40   gold back board, brown panel, gold diamond emblem, pointed foot; between arches and flanking the doors
#   Wall torches     12 x  3 =   36   iron bracket, torch, flame (plus a point light each); between the arches the banners leave free
#   Stand gold        1 x 64 =   64   one lofted gold layer over the 3 stands and up the wall foot (4 arc pieces per 22.5 degrees), under 6 studs inside r 160.5
#   Stand coin heaps 12 x  1 =   12   lumps on the gold layer, tops 5.8 over the deck
#   Leaning weapons  16 x ~2 =   36   swords and spears stuck in the wall-foot gold
#   Door urns         4 x  3 =   12   tall gold urns flanking both doors
#   Inner mounds      6 x ~16 =  94   squashed gold ball + urn (3) + 3 weapons (~8) + open chest (2) + 2 gems, on the checker inside the ring
#   Centre dais       1 x 24 =   24   2 round stone steps, gold heap (r 19), 2 chests (4), 4 gems, 3 goblets, a crown, 2 swords
#   Dressing total            ~535    (script output "PARTS dressing total"). Over the cap with the full shell: k8 drops the shell's
#                                     Motif parts (3 a wall piece), the 14 cracks and the rubble, and can halve the bay chests or torches.
# Lights are not parts: 8 torch and 8 doorway glows (shell), 12 wall torches, 7 gold point lights over the mounds.
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_arena as ba  # noqa: E402
import build_colosseum as bc  # noqa: E402  (guarded main: importing only defines the shell)
from build_arena import aim, loft, pol  # noqa: E402

ARGV = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
bc.R_WALL = 164.0  # the in-game wall (BossArenaConfig WallRadius); the draft shell had 132
bc.TILE_W = math.tau * bc.R_WALL / bc.TILES
R_IN, R_OUT, R_WALL, TH0 = bc.R_IN, bc.R_OUT, bc.R_WALL, bc.TH0
WALK_OUT = R_OUT + 1 + 14  # the walkway's outer edge; stands from here to the wall, as BossColosseum.luau
STAND_TIERS, STAND_RISE = 3, 1.2
EYE_R, EYE_H = 160.5, 6.0  # nothing nearer the centre than 160.5 may stand higher than 6 over the deck (the running camera's eye)
TILE_A = [k / bc.TILES * math.tau for k in range(bc.TILES)]  # 32 wall tiles; pillars on 2, 6, 10 ...; doors on 8 and 24
PILLAR_K = {2, 6, 10, 14, 18, 22, 26, 30}
DOOR_K = {8, 24}
ARCH_K = [k for k in range(bc.TILES) if k not in PILLAR_K and k not in DOOR_K]
BANNER_K = [0, 4, 6, 9, 12, 16, 20, 22, 25, 28]  # banners on the tile boundary after these tiles (clear of the pillars and doors)
TORCH_K = [1, 3, 5, 11, 13, 15, 17, 19, 21, 27, 29, 31]  # torches on the boundary after these
KING_H = 8 * bc.CHAR_H  # 44 studs, 8 x a character (proposed)

PLAIN_PAL = dict(ba.PAL)  # the ochre colosseum, for the comparison render
VAULT_PAL = dict(PLAIN_PAL)
VAULT_PAL.update(
	{
		"ochre": "#6E645A", "ochre2": "#625850", "ochreLo": "#4E463E", "pale": "#9A9084", "pale2": "#857B70", "recess": "#2A2420",
		"floorA": "#A49A8C", "floorB": "#6A6058", "laneA": "#8E8476", "laneB": "#80766A", "laneLine": "#C4BAAA", "walk": "#6E665C",
		"bronze": "#8A6A34", "gold": "#E2B347", "iron": "#A07E2A", "iron2": "#C49A34", "iron3": "#7A5C1C", "rivet": "#E8C050",
		"dome": "#201A16", "dome2": "#2A2420",
		"gold2": "#B8862A", "goldHi": "#F6D878", "goldMound": "#FFD25A", "banner": "#5A3A22", "banner2": "#3E2816", "torchIron": "#2A2626",
		"urn": "#8E5A3A", "urn2": "#5C3A26", "steel": "#C9CCD2", "hilt": "#5A3A22", "chest": "#6A3A20", "gemR": "#D02838", "gemB": "#2A62D8",
		"kingGold": "#E6B83A", "kingNavy": "#1E2240", "kingSkin": "#F1D6C0", "kingHair": "#F2DC7A", "kingRed": "#C0242C",
	}
)
MY_LIGHTS = []


def draw_brick():
	"""The vault's wall tile: grey-brown brick courses in the motif zone (rows 0-33), a dark brown frieze with gold diamonds (rows 33-41)."""
	px, TW = 16, bc.TILE_W
	w, h = round(TW * px), 41 * px
	U, V = np.meshgrid((np.arange(w) + 0.5) / px, (np.arange(h) + 0.5) / px)
	rng = np.random.default_rng(7)
	img = np.tile(np.array([0x72, 0x68, 0x5E], float) / 255, (h, w, 1))
	for row in range(6):  # staggered blocks, shaded, dark joints
		y0, y1 = row * 5.5, (row + 1) * 5.5
		off = (row % 2) * TW / 4
		for col in range(-1, 3):
			x0 = off + col * TW / 2
			sel = (V >= y0) & (V < y1) & (U >= x0) & (U < x0 + TW / 2)
			img[sel] *= rng.uniform(0.86, 1.1)
			img[(np.abs(U - x0) < 0.1) & (V >= y0) & (V < y1)] *= 0.78
		img[np.abs(V - y0) < 0.1] *= 0.78
	img *= (1 + rng.normal(0, 0.02, (h, w)))[..., None]
	fz = V >= 33
	img[fz] = np.array([0x3E, 0x2A, 0x1C], float) / 255
	gold = np.array([0xE2, 0xB3, 0x47], float) / 255
	dw = TW / 8
	mask = np.zeros((h, w), bool)
	for k in range(-1, 9):
		mask |= np.abs(U - (k + 0.5) * dw) / (dw * 0.36) + np.abs(V - 37) / 2.4 <= 1
	img[fz & mask] = gold
	img[fz & ((np.abs(V - 33.7) < 0.25) | (np.abs(V - 40.3) < 0.25))] = gold
	bimg = bpy.data.images.new("VaultWallTile", w, h, alpha=False)
	bimg.pixels.foreach_set(np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32).ravel())
	bimg.pack()
	return bimg


# --- Shell additions (in game already) ---
def stands():
	"""Three low tiers from the walkway's edge to the wall, as BossColosseum.luau (tops 1.2, 2.4, 3.6 over the deck)."""
	m = bc.MU("VaultStands", "shell stands")
	tw = (R_WALL - WALK_OUT) / STAND_TIERS
	prof = [(WALK_OUT, 0.5)]
	for t in range(STAND_TIERS):
		prof += [(WALK_OUT + t * tw, STAND_RISE * (t + 1)), (WALK_OUT + (t + 1) * tw, STAND_RISE * (t + 1))]
	loft(m, prof, "walk", n=bc.N)
	m.parts += STAND_TIERS
	return m


# --- The dressing ---
def arch_bay():
	"""One round blind arch on the wall face at +X, in the motif zone between the ledges: two short columns with capitals, a 4-block semicircular head, dark recess."""
	m = bc.MU("VaultArch", "arch bays")
	R, hw, zc = R_WALL, 7.5, 27.0  # half the opening, the springing line
	for s_ in (-1, 1):
		m.cyl(1.4, zc - 12.2, (R - 1.0, s_ * (hw + 1.3), 12.2), "pale", n=10)
		m.box((2.6, 3.4, 1.4), (R - 1.0, s_ * (hw + 1.3), zc), "pale2")
	rr, n = hw + 1.3, 6
	pts = [(rr * math.cos(math.pi * k / n), zc + rr * math.sin(math.pi * k / n)) for k in range(n + 1)]
	for (y1, z1), (y2, z2) in zip(pts, pts[1:]):
		m.beam((R - 0.9, y1, z1), (R - 0.9, y2, z2), 2.4, "pale")
	rec = [(hw, 12.5), (hw, zc)] + [(hw * math.cos(math.pi * k / 8), zc + hw * math.sin(math.pi * k / 8)) for k in range(1, 8)] + [(-hw, zc), (-hw, 12.5)]
	m.face([(R - 0.35, y, z) for y, z in rec], "recess")
	m.parts = 7  # in game: 2 columns, 2 capitals, head as a half cylinder over a recess-coloured half cylinder, 1 recess box
	return m


def bay_chest():
	"""An open chest of coins and two gems at the wall foot inside each arch bay (inner face past radius 160.5, the eye rule)."""
	m = bc.MU("VaultBayChest", "bay chests")
	z = STAND_RISE * STAND_TIERS + 3.0  # on the gold layer
	chest(m, (162.3, 0, z), math.pi / 2)
	gems(m, (161.3, 1.8, z + 0.2), 0.3)
	m.parts -= 1  # the two gems as one part in game
	return m


def banner():
	"""A tall gold-on-brown banner on the wall between two arches: gold board, brown panel, gold diamond emblem, a pointed foot."""
	m = bc.MU("VaultBanner", "banners")
	R, w, z1, z2 = R_WALL, 7.6, 18.0, 44.0
	m.box((0.4, w + 1.2, z2 - z1), (R - 0.5, 0, (z1 + z2) / 2), "gold2")
	m.box((0.4, w, z2 - z1 - 1.4), (R - 0.8, 0, (z1 + z2) / 2 + 0.7), "banner")
	m.obox((0.4, 3.4, 3.4), Matrix.Translation((R - 1.1, 0, 33)) @ Matrix.Rotation(math.pi / 4, 4, "X"), "gold")
	m.face([(R - 0.6, -(w + 1.2) / 2, z1), (R - 0.6, (w + 1.2) / 2, z1), (R - 0.6, 0, z1 - 4.5)], "gold2")
	m.face([(R - 0.9, -w / 2, z1), (R - 0.9, w / 2, z1), (R - 0.9, 0, z1 - 3.6)], "banner2")
	m.parts += 1
	return m


def torch():
	"""A wall torch in an iron bracket between arches, at the pillars' torch height."""
	m = bc.MU("VaultTorch", "wall torches")
	R = R_WALL
	m.box((2.4, 1.2, 1.0), (R - 1.2, 0, 23.0), "torchIron")
	m.box((1.0, 1.0, 3.2), (R - 2.6, 0, 24.2), "torchIron")
	m.box((1.2, 1.2, 1.6), (R - 2.6, 0, 26.6), "flame")
	return m


def gems(m, c, yaw):
	"""Two cut gems spilling from a chest: turned cubes, red and blue (owner's vault reference)."""
	x, y, z = c
	for k, name in enumerate(("gemR", "gemB")):
		mt = Matrix.Translation((x + 1.6 * math.cos(yaw + k * 2.2), y + 1.6 * math.sin(yaw + k * 2.2), z)) @ Matrix.Rotation(0.8, 4, "X") @ Matrix.Rotation(0.6, 4, "Y")
		m.obox((0.9, 0.9, 0.9), mt, name)


def urn(m, c, scale=1.0):
	"""Foot, belly and flared neck, standing at c (its base)."""
	x, y, z = c
	m.cyl(0.9 * scale, 0.6 * scale, (x, y, z), "gold2", n=10)
	m.cyl(1.6 * scale, 3.8 * scale, (x, y, z + 0.6 * scale), "gold", n=10, r2=1.0 * scale)
	m.cyl(1.0 * scale, 1.3 * scale, (x, y, z + 4.4 * scale), "gold2", n=10, r2=1.35 * scale)


def weapon(m, base, yaw, tilt, kind, scale=1.0):
	"""A sword (blade down, stuck in the gold) or a spear (butt in the gold, head up) from base, leaning tilt radians toward yaw."""
	mt = Matrix.Translation(base) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y")
	s = scale
	at = lambda z: mt @ Matrix.Translation((0, 0, z * s))
	if kind == "sword":
		m.obox((0.35 * s, 1.3 * s, 6.5 * s), at(3.25), "steel")
		m.obox((0.6 * s, 3.4 * s, 0.6 * s), at(6.8), "gold2")
		m.obox((0.5 * s, 0.6 * s, 1.8 * s), at(8.0), "hilt")
		m.obox((0.8 * s, 0.8 * s, 0.6 * s), at(9.2), "gold2")
		m.parts -= 1  # grip and pommel as one part in game
	else:
		m.obox((0.45 * s, 0.45 * s, 14 * s), at(7), "hilt")
		m.obox((0.3 * s, 1.4 * s, 2.8 * s), at(15.3), "steel")


def chest(m, c, yaw):
	x, y, z = c
	mt = Matrix.Translation((x, y, z)) @ Matrix.Rotation(yaw, 4, "Z")
	m.obox((3.2, 2.2, 1.8), mt @ Matrix.Translation((0, 0, 0.9)), "chest")
	m.obox((3.3, 2.3, 0.5), mt @ Matrix.Translation((0, -1.0, 2.4)) @ Matrix.Rotation(-0.9, 4, "X") @ Matrix.Translation((0, 1.1, 0)), "chest")
	m.obox((2.9, 1.9, 0.4), mt @ Matrix.Translation((0, 0, 1.9)), "goldHi")
	m.parts -= 1  # the gold inside is the chest's top face in game


def centre_mound(parent):
	"""The boss's spot: a round stepped stone dais over the rayed disc with a big gold heap on top and its own treasure."""
	m = bc.MU("VaultCentreMound", "centre mound")
	m.cyl(27, 2.4, (0, 0, 0.3), "pale", n=24)  # the round stepped stone dais of the owner's vault reference, a smaller round top
	m.cyl(22, 2.4, (0, 0, 2.7), "pale2", n=24)
	ba.rng.seed(21)
	m.blob(19, (0, 0, 5.1), "goldMound", squash=0.42, jitter=0.12)  # the gold heap on it, about 8 studs high
	m.parts += 1
	chest(m, (12, 7, 7.2), 0.6)
	chest(m, (-10, -11, 7.4), 2.4)
	gems(m, (12, 9.5, 7.6), 0.6)
	gems(m, (-10, -13.5, 7.8), 2.4)
	for a, r in ((0.9, 14.5), (2.2, 13.5), (4.4, 15.0)):
		m.cyl(0.7, 1.6, pol(r, a, 7.6), "gold", n=8, r2=1.05)
	m.cyl(1.7, 1.2, (-13.5, 6, 8.0), "gold", n=8, r2=1.9)  # a crown
	weapon(m, pol(14, 3.4, 6.0), 3.4, 0.35, "sword", 1.3)
	weapon(m, pol(15.5, 5.6, 5.8), 5.6, -0.3, "sword", 1.2)
	ob = bc.put(m, parent)
	return ob, max((ob.matrix_world @ v.co).z for v in ob.data.vertices if (v.co.x**2 + v.co.y**2) < 16)


def inner_mounds(parent):
	"""Six heaps on the checker floor between the rayed disc and the lanes, each with an urn, weapons and an open chest."""
	rng = random.Random(4)
	for i in range(6):
		a = math.radians(30 + 60 * i)
		c = pol(44, a, 0)
		m = bc.MU("VaultMound", "treasure mounds")
		ba.rng.seed(30 + i)
		m.blob(8.5, c, "goldMound", squash=0.42, jitter=0.18)
		m.parts += 1
		urn(m, pol(44, a + 0.22, 1.6), 1.3)
		for k in range(3):
			b = a + rng.uniform(-0.12, 0.12) + (k - 1) * 0.1
			r = 44 + rng.uniform(-3.5, 3.5)
			weapon(m, pol(r, b, 1.2), rng.uniform(0, math.tau), rng.uniform(0.15, 0.45), rng.choice(("sword", "sword", "spear")), rng.uniform(0.9, 1.3))
		chest(m, pol(41.5, a - 0.2, 1.8), a + 1.2)
		gems(m, pol(39.5, a - 0.26, 1.6), a + 1.2)
		bc.put(m, parent, a)
		light = bpy.data.objects.new("MoundGlow", bpy.data.lights.new("MoundGlow", "POINT"))
		light.location = pol(44, a, 9)
		light.data.color, light.data.energy, light.data.shadow_soft_size = (1.0, 0.8, 0.4), 9000, 3
		light.data.use_shadow = False
		parent.objects.link(light)
		MY_LIGHTS.append(light)


def wall_foot(parent):
	"""Gold over the three stands and up the wall foot, weapons leaning in it at the wall, coin lumps on top."""
	m = bc.MU("VaultStandGold", "stand gold")  # one bumpy ring: tops stay under EYE_H inside EYE_R, then up the wall foot
	loft(m, [(WALK_OUT, 0.5), (WALK_OUT + 0.5, 1.8), (146, 3.4), (151, 4.6), (156, 5.5), (EYE_R, 5.8), (EYE_R + 0.6, 9.5), (R_WALL, 12.0)], "goldMound", n=bc.N)
	m.parts += 64
	bc.put(m, parent)
	rng = random.Random(8)
	w = bc.MU("VaultWallWeapons", "leaning weapons")
	for i in range(16):
		a = math.radians(11.25 + 22.5 * i) + rng.uniform(-0.06, 0.06)  # between the pillars' and doors' angles
		base = pol(161.6, a, 8.5)
		w.obox((0.1, 0.1, 0.1), Matrix.Translation(base), "gold")  # anchor, no part
		w.parts -= 1
		weapon(w, base, a, -rng.uniform(0.12, 0.22), rng.choice(("sword", "spear", "spear")), rng.uniform(0.9, 1.2))  # leans on the wall
	bc.put(w, parent)
	h = bc.MU("VaultCoinHeap", "stand coin heaps")
	for i in range(12):
		a = math.radians(15 + 30 * i)
		ba.rng.seed(50 + i)
		h.blob(5.0, pol(151, a, 3.8), "goldMound", squash=0.4, jitter=0.15)  # top 5.8 over the deck: under the eye's 6
		h.parts += 1
	bc.put(h, parent)


def urns(parent):
	"""Four tall gold urns flanking the doors (the reference's one gold urn, repeated)."""
	m = bc.MU("VaultUrns", "door urns")
	for d in (bc.DOOR_A, bc.DISC_A):
		for s_ in (-1, 1):
			urn(m, pol(161.6, d + s_ * 24.0 / R_WALL, STAND_RISE * STAND_TIERS + 3.0), 1.7)
	bc.put(m, parent)


def king(parent, z_top):
	"""Stand-in: a blocky R15 body in gold plate over navy, arms folded, spiky upswept hair; 44 studs, standing on the centre mound."""
	b = bc.MU("KingStandIn", "boss stand-in")
	for s in (-1, 1):
		b.box((0.9, 0.9, 2.4), (s * 0.5, 0, 1.2), "kingNavy")
		b.box((0.9, 0.9, 1.0), (s * 0.5, 0, 2.9), "kingGold")  # skirt plates
	b.box((2.0, 1.0, 2.0), (0, 0, 4.0), "kingGold")  # torso
	b.box((2.2, 1.1, 0.5), (0, 0, 3.35), "kingNavy")
	for s in (-1, 1):
		b.box((1.1, 1.1, 0.7), (s * 1.45, 0, 4.85), "kingGold")  # round pauldrons as blocks
		b.box((0.8, 0.8, 1.2), (s * 1.3, -0.1, 3.5), "kingGold")  # upper arms
	b.box((2.4, 0.7, 0.7), (0, -0.75, 3.9), "kingGold")  # forearms folded across the chest
	b.box((1.2, 1.2, 1.2), (0, 0, 5.6), "kingSkin")
	b.box((1.3, 1.3, 0.5), (0, 0.05, 6.35), "kingHair")
	for s in (-1, 0, 1):  # spiky upswept hair
		b.obox((0.4, 0.4, 1.1), Matrix.Translation((s * 0.45, 0.1, 6.9)) @ Matrix.Rotation(s * 0.5, 4, "Y") @ Matrix.Rotation(-0.35, 4, "X"), "kingHair")
	b.box((0.5, 0.05, 0.14), (0, -0.62, 5.75), "kingRed")  # eyes
	ob = bc.put(b, parent)
	ob.matrix_world = Matrix.Rotation(TH0 + math.pi / 2, 4, "Z") @ Matrix.Translation((0, 0, z_top)) @ Matrix.Scale(KING_H / 7.45, 4)
	zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]
	print(f"KING stand-in: feet {min(zs):.1f} to hair top {max(zs):.1f} = {max(zs) - min(zs):.1f} studs on the mound (top {z_top:.1f})")
	return ob


def metallize():
	"""Gold reads as metal; the mounds get a coin-like bump."""
	for name, rough in (("gold", 0.35), ("gold2", 0.4), ("goldHi", 0.3), ("rivet", 0.4), ("goldMound", 0.3), ("kingGold", 0.4), ("steel", 0.3)):
		m = ba._mats.get(name)
		if not m:
			continue
		bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Metallic"].default_value = 1.0
		bsdf.inputs["Roughness"].default_value = rough
		if name == "goldMound":
			nt = m.node_tree
			noise, bump = nt.nodes.new("ShaderNodeTexNoise"), nt.nodes.new("ShaderNodeBump")
			noise.inputs["Scale"].default_value = 2.2
			noise.inputs["Detail"].default_value = 6
			bump.inputs["Strength"].default_value = 0.6
			nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
			nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	for name in ("gemR", "gemB"):
		if name in ba._mats:
			next(n for n in ba._mats[name].node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Roughness"].default_value = 0.15


def vault_light(scene):
	"""Warm gold over bc.lighting('warm'): gold torches and doorway glows, a gold-brown sky through the dome's hole, a gold key over the centre mound."""
	nt = scene.world.node_tree
	nt.nodes["SkyMix"].inputs["A"].default_value = ba.rgb("#1A1410")  # a dark cave ceiling through the dome's hole
	nt.nodes["SkyMix"].inputs["B"].default_value = ba.rgb("#1A1208")
	for ob, kind in bc.LIGHTS:
		if kind == "torch":
			ob.data.color, ob.data.energy = (1.0, 0.72, 0.32), 42000
		elif kind == "door":
			ob.data.color, ob.data.energy = (1.0, 0.8, 0.4), 5000
		elif kind == "fill":
			ob.data.color, ob.data.energy = (1.0, 0.8, 0.55), 100000  # low: the torches make the pools
	key = bpy.data.objects.new("CentreGlow", bpy.data.lights.new("CentreGlow", "POINT"))
	key.location, key.data.color, key.data.energy, key.data.shadow_soft_size = (0, 0, 20), (1.0, 0.82, 0.45), 120000, 8
	scene.collection.objects.link(key)
	MY_LIGHTS.append(key)
	for k in TORCH_K:
		light = bpy.data.objects.new("WallTorchGlow", bpy.data.lights.new("WallTorchGlow", "POINT"))
		light.location = pol(R_WALL - 5, (k + 1) / bc.TILES * math.tau, 27)
		light.data.color, light.data.energy, light.data.shadow_soft_size = (1.0, 0.62, 0.25), 26000, 1.5
		light.data.use_shadow = False  # EEVEE's shadow pool fills with 35 shadowed lights
		scene.collection.objects.link(light)
		MY_LIGHTS.append(light)
	for name, c, strength in (("flame", "#FFA030", 10), ("glowDoor", "#FFD070", 12)):
		bsdf = next(n for n in ba._mats[name].node_tree.nodes if n.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Base Color"].default_value = bsdf.inputs["Emission Color"].default_value = ba.rgb(c)
		bsdf.inputs["Emission Strength"].default_value = strength


def build(plain):
	"""The shell with either the vault dressing or the plain ochre look (cracks, rubble, the mage stand-in)."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	ba._mats.clear()
	bc.PLACED.clear()
	bc.LIGHTS.clear()
	bc._parts.clear()
	MY_LIGHTS.clear()
	ba.PAL.clear()
	ba.PAL.update(PLAIN_PAL if plain else VAULT_PAL)
	scene = bpy.context.scene
	coll = scene.collection
	bc.textured("wallTex", bc.draw_tile() if plain else draw_brick())
	bc.glow("flame", "#FFB04A", 40)
	bc.glow("glowDoor", "#FFB45A", 12)
	bc.glow("spellOrb", "#F2EEFF", 60)
	bc.put(bc.floor(), coll)
	bc.put(stands(), coll)
	bc.place(bc.wall_piece(), [k / bc.PIECES * math.tau for k in range(bc.PIECES)], coll)
	bc.place(bc.pillar(), bc.PILLAR_AS, coll)
	bc.place(bc.great_doors(), [bc.DOOR_A], coll)
	bc.place(bc.disc_door(), [bc.DISC_A], coll)
	bc.put(bc.dome(), coll)
	if plain:
		bc.wall_cracks(coll)
		bc.rubble(coll)
		bc.boss(coll)
	else:
		bc.place(arch_bay(), [TILE_A[k] for k in ARCH_K], coll)
		bc.place(bay_chest(), [TILE_A[k] for k in ARCH_K], coll)
		bc.place(banner(), [(k + 1) / bc.TILES * math.tau for k in BANNER_K], coll)
		bc.place(torch(), [(k + 1) / bc.TILES * math.tau for k in TORCH_K], coll)
		urns(coll)
		wall_foot(coll)
		inner_mounds(coll)
		_, top = centre_mound(coll)
		king(coll, top)
	bc.runners(coll)
	cam = bc.setup(scene)
	bc.lighting("warm")
	if not plain:
		metallize()
		vault_light(scene)
	return scene, cam


def hide_dome(on):
	for ob, _ in bc.PLACED:
		ob.hide_render = on and ob.name.startswith("ColosseumDome")


def shots():
	"""(name, eye, look, fov, hide the dome)"""
	e4, l4, _ = bc.player_pose(4)
	pa = TILE_A[4]  # the 45 degree arch, a banner on its right
	return [
		("Vault2_01_wide_lane4", e4, l4, 100, False),
		("Vault2_02_overhead", Vector((0, -40, 310)), Vector((0, 0, 0)), 64, True),
		("Vault2_03_centre_mound", pol(104, TH0, 12), Vector((0, 0, 22)), 62, False),
		("Vault2_04_arch_bay", pol(R_WALL - 38, pa - math.radians(9), 17), pol(R_WALL - 2, pa, 29), 56, False),
	]


def render(scene, cam, name, eye, look, fov, no_dome):
	hide_dome(no_dome)
	aim(cam, Vector(eye), Vector(look), fov)
	scene.render.filepath = os.path.join(ba.OUT, name + ".png")
	bpy.ops.render.render(write_still=True)
	print("SHOT", scene.render.filepath)
	return scene.render.filepath


def sheet(entries, path, cols=3):
	"""A labelled contact sheet, cols wide, drawn by an orthographic camera over emissive image planes (bc.sheet's method, 3 columns)."""
	rows = math.ceil(len(entries) / cols)
	W, H = 12.8 * cols, 8.0 * rows
	sc = bpy.data.scenes.new("Sheet")
	sc.render.engine = bpy.context.scene.render.engine
	sc.render.resolution_x, sc.render.resolution_y = round(W * 100), round(H * 100)
	sc.view_settings.view_transform = "Standard"
	sc.world = bpy.data.worlds.new("SheetBg")
	next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND").inputs["Color"].default_value = (0.02, 0.02, 0.025, 1)
	cam = bpy.data.objects.new("SheetCam", bpy.data.cameras.new("SheetCam"))
	cam.data.type, cam.data.ortho_scale = "ORTHO", max(W, H)
	cam.location = (W / 2, H / 2, 10)
	sc.collection.objects.link(cam)
	sc.camera = cam

	def emit(name, image=None, color=(1, 1, 1, 1)):
		m = bpy.data.materials.new(name)
		nt = m.node_tree
		for n in list(nt.nodes):
			if n.type != "OUTPUT_MATERIAL":
				nt.nodes.remove(n)
		em = nt.nodes.new("ShaderNodeEmission")
		em.inputs["Color"].default_value = color
		if image:
			tex = nt.nodes.new("ShaderNodeTexImage")
			tex.image = bpy.data.images.load(image)
			nt.links.new(tex.outputs["Color"], em.inputs["Color"])
		nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs["Surface"])
		return m

	for i, (img, label) in enumerate(entries):
		x0, y0 = (i % cols) * 12.8, H - (i // cols) * 8
		me = bpy.data.meshes.new("SheetImg")
		me.from_pydata([(x0, y0 - 7.2, 0), (x0 + 12.8, y0 - 7.2, 0), (x0 + 12.8, y0, 0), (x0, y0, 0)], [], [(0, 1, 2, 3)])
		uv = me.uv_layers.new()
		for li, q in zip(me.polygons[0].loop_indices, ((0, 0), (1, 0), (1, 1), (0, 1))):
			uv.data[li].uv = q
		me.materials.append(emit("SheetImg", img))
		sc.collection.objects.link(bpy.data.objects.new("SheetImg", me))
		cu = bpy.data.curves.new("SheetLabel", "FONT")
		cu.body, cu.size, cu.align_x = label, 0.36, "CENTER"
		cu.materials.append(emit("SheetText", color=(1, 0.95, 0.85, 1)))
		t = bpy.data.objects.new("SheetLabel", cu)
		t.location = (x0 + 6.4, y0 - 7.75, 0)
		sc.collection.objects.link(t)
	sc.render.filepath = path
	bpy.ops.render.render(write_still=True, scene=sc.name)
	print("SHOT", path)


def main():
	os.makedirs(ba.OUT, exist_ok=True)
	os.makedirs(ba.BUILD, exist_ok=True)
	bpy.context.preferences.filepaths.save_version = 0
	scene, cam = build(plain=False)
	shell = {"floor", "wall", "pillars", "doors", "disc door", "dome", "shell stands", "runners", "boss stand-in"}
	for k, v in sorted(bc._parts.items()):
		print(f"PARTS {k}: {v}")
	print(f"PARTS dressing total: {sum(v for k, v in bc._parts.items() if k not in shell)}; shell (draft count): {sum(v for k, v in bc._parts.items() if k in shell)}")
	assert bc.R_WALL == 164 and bc.R_IN == 70 and bc.WIDTH == 56, "the shell's gameplay radii moved"
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ba.BUILD, "vault_draft.blend"))
	labels = {"Vault2_01_wide_lane4": "Vault: wide view, lane 4 runner camera", "Vault2_02_overhead": "Vault: overhead (dome hidden)", "Vault2_03_centre_mound": "Vault: toward the dais, gold heap and the boss", "Vault2_04_arch_bay": "Vault: arch bays with chests, a banner and a torch"}
	done = []
	for name, eye, look, fov, no_dome in shots():
		if ARGV and name not in ARGV:
			continue
		done.append((render(scene, cam, name, eye, look, fov, no_dome), labels[name]))
	name = "Vault2_05_plain_colosseum_wide"
	if not ARGV or name in ARGV:
		scene, cam = build(plain=True)
		e4, l4, _ = bc.player_pose(4)
		done.append((render(scene, cam, name, e4, l4, 100, False), "Plain colosseum shell, same camera, for comparison"))
	if len(done) == 5:
		sheet(done, os.path.join(ba.OUT, "Vault2_contact_sheet.png"))


if __name__ == "__main__":
	main()
