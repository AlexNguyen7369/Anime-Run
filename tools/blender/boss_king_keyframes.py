# The Golden King (boss_king) key poses for owner review: standing idle, Gates of Babylon and its 2 s volley window, Enuma Elish
# (charge, then beam), Shield Gates and the Fortified idle. Key frames only: no in-betweens, no bake, no upload. Headless:
#   Blender -b --factory-startup --python tools/blender/boss_king_keyframes.py -- [idle gates gates_window enuma_charge enuma_beam shields fortified_idle] [--arena <blend>] [--size 8]
# Needs boss_king.blend (build_boss_king.py) and the vault draft (build/arena/vault_draft.blend from tools/blender/arena/build_vault.py;
# the plain colosseum draft loads too). Writes assets/characters_avatar/boss_king/keyframes/<move>_slices.png, all_moves_overview.png
# and keys.json. Design doc 4.37 "Third boss" and BOSS_EVENT_SPEC "The Golden King": every time, count and size here is proposed.
#
# MOVES is the pose data in boss_mage_keyframes.py's shape (same R15 block body, axes and signs: front -Y, +X his left, Z up).
#   root   offset of the whole figure, model units. He stands on the centre mound: root[2] stays 0 (no hover, no bob).
#   body / torso / head   rotation about HIP / WAIST / NECK. LeftLeg/RightLeg: X Y Z Euler degrees about the hip joint.
#   LeftArm/RightArm   Euler degrees, or {"aim": point}: the hand aimed at a point in rest model space. LeftArm "grip": aimed at
#          Ea's grip above the right fist (two hands on the pillar). Block arms have no elbow, so "arms folded" is two straight
#          blocks crossed in front of the chest, the left in front (FOLD).
#   key    the Key at the belt (a child of the torso): Euler degrees about its ring.
#   ea     absent: Ea is not drawn (he fights bare-handed until he draws it). Else Euler degrees about the grip relative to the right
#          arm: (0, 0, 0) upright in the fist, (180, 0, 0) straight on from the arm. spin: the drums' angle about the pillar's axis
#          (Drum1 and Drum3 turn +spin, Drum2 -spin). keys.json holds every solved rotation, so a bake reads plain numbers.
#   fx     effect sketches (emissive meshes, never final VFX). arena: a wide view from the lane-4 runner's camera lit "gold" (the
#          vault as built) or "red" (Enuma Elish's sky tint). event: when the server charges the hit or sets the status.
#
# --rework: the 2026-11-12 animation rework (design doc 4.37 "Animation rework") on the jointed rig (boss_king_jointed.blend from
# build_boss_king.py -- jointed). JMOVES is kept apart from MOVES (shipped, pre-approved, baked by bake_boss_king.py from
# keyframes/keys.json) and writes keyframes/rework/keys.json and keyframes/rework/<move>_slices.png. He hovers (owner 2026-11-12,
# replaces "no hover"): his rest feet float HOVER_STUDS above the mound; root[2] moves him up and down from there. Key fields as MOVES, plus:
#   LeftArm/RightArm  {"aim": point, "pole": dir}: a two-bone solve in torso space; the hand reaches the point (clamped to the arm's
#          reach) and the elbow bends toward pole (default out and back). Or {"shoulder": euler, "elbow": degrees}: elbow > 0
#          bends the forearm forward. LeftArm "grip": the left fist on Ea's grip GRIP_UP above the right one.
#   LeftLeg/RightLeg  hip Euler degrees, or {"hip": euler, "knee": degrees}: knee > 0 bends the shin back.
#   ea     Euler about the grip relative to the right forearm as in MOVES, {"dir": d}: Ea's axis, turned with the body's yaw, the
#          grip in the right fist, or {"at": p, "dir": d}: free of the hand (out of or back into its ripple), p in model space.
import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boss_keyframes as bk  # noqa: E402  (guarded main: sheet text, pixels and ortho fit)
import boss_mage_keyframes as mk  # noqa: E402  (guarded main: effect primitives, pose maths, shot)
import build_boss_event as be  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "characters_avatar", "boss_king", "keyframes")
TMP = os.path.join(ROOT, "build", "boss_king_keyframes")
ARENA = os.path.join(ROOT, "build", "arena", "vault_draft.blend")

SIZE = 8.0  # his height in runner heights (design doc: 8 x a character, proposed)
CHAR_H = 5.5
R_IN, LANE_W, R_WALL = 70.0, 8.0, 164.0  # the vault: the colosseum's lanes with the wall at the in-game 164
TH0 = math.radians(-41)  # the followed runner on lane 4
FACE = TH0 + math.pi / 2  # he faces that runner, as the vault's stand-in does
REWORK = False  # main(--rework): the jointed rig and JMOVES
MODEL = "boss_king"
HIP, WAIST, NECK = mk.HIP, mk.WAIST, mk.NECK
SHOULDER, HAND, LEG = mk.SHOULDER, mk.HAND, mk.LEG
KEY_PIVOT = (1.2, 0.1, 2.35)  # build_boss_king.LOOSE
EA_PIVOT = Vector((-1.5, -0.62, 2.05))  # build_boss_king.EA_PIVOT: the grip in the right fist
EA_PARTS = ("Ea_Grip", "Ea_Drum1", "Ea_Drum2", "Ea_Drum3")
BODY = ("Torso_merged", "Head_merged", "LeftArm_merged", "RightArm_merged", "LeftLeg_merged", "RightLeg_merged")
GRIP_UP = 0.8  # the left fist this far above the right one on the grip, model units
N_PORTALS, N_SHIELDS, VOLLEY = 16, 6, 8  # proposed: 12 to 20 portals, 5 to 7 shields, 7 to 10 weapons a volley
eul, about, aim_rot, degs = mk.eul, mk.about, mk.aim_rot, mk.degs
UP = (180, 0, 0)  # Ea straight on from the right arm

# arms folded: straight blocks crossed in front of the chest (no elbow), the right across the chest, the left under it
FOLD = {"RightArm": {"aim": (1.0, -1.5, 2.7)}, "LeftArm": {"aim": (-1.0, -1.6, 1.8)}}


def fold(**k):
	d = dict(FOLD)
	d.update(k)
	return d


FIRE = {"root": (0, -0.15, 0), "body": (0, 0, 0), "torso": (14, 0, -6), "head": (6, 0, 6), "RightArm": {"aim": (-1.6, -3.5, 3.4)}, "LeftArm": {"aim": (2.6, 1.2, 2.2)}, "LeftLeg": (-10, 0, -3), "RightLeg": (12, 0, 3), "key": (14, 0, 0)}
LAST = {"root": (0, -0.1, 0), "torso": (8, 0, 4), "head": (2, 0, -4), "RightArm": {"aim": (-2.2, -3.3, 3.0)}, "LeftArm": {"aim": (2.3, 1.0, 2.2)}, "LeftLeg": (-6, 0, -3), "RightLeg": (8, 0, 3), "key": (8, 0, 0)}
MOVES = {
	"idle": {
		"title": "Idle: standing, arms folded",
		"end": 4.0,
		"loop": True,
		"keys": [
			fold(t=0.0, cap="Breath out, weight on his right leg", body=(0, 2, 0), torso=(2, 0, 3), head=(2, 0, -4), LeftLeg=(0, -2, 0), RightLeg=(0, -2, 0), key=(0, 0, 0)),
			fold(t=1.3, cap="Breath in: chest lifts, chin up", body=(0, 0, 0), torso=(-3, 0, 0), head=(-5, 0, 0), RightArm={"aim": (1.0, -1.55, 2.85)}, LeftArm={"aim": (-1.0, -1.65, 1.95)}, key=(2, 0, 0)),
			fold(t=2.7, cap="Breath out, weight shifts to his left leg", body=(0, -2, 0), torso=(2, 0, -3), head=(2, 0, 4), LeftLeg=(0, 2, 0), RightLeg=(0, 2, 0), key=(0, 0, 0)),
		],
	},
	"gates": {
		"title": "Gates of Babylon: portals open, then a 2 s volley burst",
		"end": 4.4,
		"window": [0.0, 1.6],  # the Dodge bar runs BEFORE the volleys
		"keys": [
			{"t": 0.0, "cap": "Dodge window opens: hand lifts, first ripples", "fx": ["portals_faint"], "arena": "gold", "root": (0, 0, 0), "torso": (-4, 0, 6), "head": (-4, 0, -8), "RightArm": {"aim": (-2.0, -1.6, 5.2)}, "LeftArm": fold()["LeftArm"], "LeftLeg": (0, 0, 0), "RightLeg": (0, 0, 0), "key": (0, 0, 0)},
			{"t": 0.8, "cap": f"{N_PORTALS} gold portals open round him, a weapon tip in each", "fx": ["portals_open"], "arena": "gold", "root": (0, 0, 0), "torso": (-10, 0, 0), "head": (-12, 0, 0), "RightArm": {"aim": (-1.2, -0.8, 6.4)}, "LeftArm": {"aim": (2.3, -0.4, 2.0)}, "LeftLeg": (0, -2, 0), "RightLeg": (0, 2, 0), "key": (-4, 0, 0)},
			{"t": 1.6, "cap": "Fire: arm thrust at the lanes, volley 1 of 14 (window closes, 20% hit)", "event": "Volleys", "fx": ["portals_open", "streaks:0"], "arena": "gold", **FIRE},
			{"t": 3.6, "cap": "Volley 14, the last: portals start to close", "fx": ["portals_fade", "streaks:13"], "arena": "gold", **LAST},
			fold(t=4.2, cap="Recover: arms fold again, portals gone", root=(0, 0, 0), torso=(2, 0, 0), head=(0, 0, 0), LeftLeg=(0, 0, 0), RightLeg=(0, 0, 0), key=(0, 0, 0)),
		],
	},
	"enuma_charge": {
		"title": "Enuma Elish, charge: Ea drawn and raised, 3 s Dodge window",
		"end": 5.6,
		"window": [0.0, 3.0],
		"keys": [
			{"t": 0.0, "cap": "Draws Ea from a gold ripple at his right hand", "fx": ["draw"], "root": (0, 0, 0), "torso": (6, 0, 10), "head": (4, 0, -12), "RightArm": {"aim": (-2.6, -1.2, 3.0)}, "LeftArm": {"aim": (2.4, 0.4, 2.2)}, "LeftLeg": (0, 0, 0), "RightLeg": (0, 0, 0), "key": (6, 0, 0), "ea": (0, 0, 0), "spin": 0},
			{"t": 0.8, "cap": "Both hands on the grip, Ea raised to the sky; drums start to turn", "fx": ["arrows"], "root": (0, 0.1, 0), "torso": (-8, 0, 0), "head": (-18, 0, 0), "RightArm": {"aim": (-0.6, -0.6, 6.6)}, "LeftArm": "grip", "LeftLeg": (-6, 0, -2), "RightLeg": (6, 0, 2), "key": (-6, 0, 0), "ea": UP, "spin": 30},
			{"t": 1.8, "cap": "Charge: sky turns red, wind spirals up the pillar, drums fast", "fx": ["arrows", "wind", "charge"], "arena": "red", "root": (0, 0.15, 0), "torso": (-14, 0, 0), "head": (-24, 0, 0), "RightArm": {"aim": (-0.4, -0.3, 6.8)}, "LeftArm": "grip", "LeftLeg": (-8, 0, -2), "RightLeg": (8, 0, 2), "key": (-10, 0, 0), "ea": UP, "spin": 150},
			{"t": 2.7, "cap": "Peak: red-black air gathers at the tip (window ends at 3.00 s)", "fx": ["arrows", "wind", "charge", "gather"], "arena": "red", "root": (0, 0.2, 0), "torso": (-18, 0, 0), "head": (-28, 0, 0), "RightArm": {"aim": (-0.3, 0.1, 6.9)}, "LeftArm": "grip", "LeftLeg": (-10, 0, -2), "RightLeg": (10, 0, 2), "key": (-12, 0, 0), "ea": UP, "spin": 330},
		],
	},
	"enuma_beam": {
		"title": "Enuma Elish, beam: Ea swung down, a red-black cyclone sweeps the arena for 2 s",
		"end": 5.6,
		"extends": "enuma_charge",
		"keys": [
			{"t": 3.0, "cap": "Swing: Ea comes down and forward, the beam leaves the tip (40% hit)", "event": "Beam", "fx": ["beam", "arrows"], "arena": "red", "root": (0, -0.3, 0), "body": (0, 0, -108), "torso": (22, 0, 0), "head": (-6, 0, 0), "RightArm": {"aim": (-1.0, -2.6, 5.2)}, "LeftArm": "grip", "LeftLeg": (-14, 0, -4), "RightLeg": (16, 0, 4), "key": (18, 0, 0), "ea": UP, "spin": 420},
			{"t": 3.6, "cap": "Sweep: the beam crosses the runner's lanes", "fx": ["beam", "arrows"], "arena": "red", "root": (0, -0.3, 0), "body": (0, 0, 0), "torso": (24, 0, 0), "head": (-8, 0, 0), "RightArm": {"aim": (-1.3, -3.2, 4.0)}, "LeftArm": "grip", "LeftLeg": (-14, 0, -4), "RightLeg": (16, 0, 4), "key": (18, 0, 0), "ea": UP, "spin": 600},
			{"t": 4.4, "cap": "Sweep: the far side of the ring", "fx": ["beam", "arrows"], "arena": "red", "root": (0, -0.3, 0), "body": (0, 0, 144), "torso": (24, 0, 0), "head": (-8, 0, 0), "RightArm": {"aim": (-1.3, -3.2, 4.0)}, "LeftArm": "grip", "LeftLeg": (-14, 0, -4), "RightLeg": (16, 0, 4), "key": (18, 0, 0), "ea": UP, "spin": 840},
			{"t": 5.3, "cap": "Recover: Ea lowered, drums slow, sky clears", "fx": ["embers"], "root": (0, 0, 0), "body": (0, 0, 0), "torso": (6, 0, 6), "head": (2, 0, -6), "RightArm": {"aim": (-2.4, -1.4, 2.6)}, "LeftArm": {"aim": (2.2, -0.6, 2.2)}, "LeftLeg": (0, 0, 0), "RightLeg": (0, 0, 0), "key": (4, 0, 0), "ea": (0, 0, 0), "spin": 900},
		],
	},
	"shields": {
		"title": "Shield Gates: portals open and a ring of shields hovers round him (no Dodge bar)",
		"end": 2.6,
		"keys": [
			{"t": 0.0, "cap": f"Hand raised: {N_SHIELDS} small portals open in a ring", "fx": ["shield_portals"], "root": (0, 0, 0), "torso": (-4, 0, -6), "head": (-6, 0, 6), "LeftArm": {"aim": (2.2, -1.2, 5.6)}, "RightArm": fold()["RightArm"], "LeftLeg": (0, 0, 0), "RightLeg": (0, 0, 0), "key": (0, 0, 0)},
			{"t": 0.7, "cap": "Shields emerge, half out of their portals", "fx": ["shield_portals", "shields:emerge"], "root": (0, 0, 0), "torso": (-8, 0, 0), "head": (-10, 0, 0), "LeftArm": {"aim": (1.2, -1.0, 6.4)}, "RightArm": {"aim": (-2.4, -0.6, 2.0)}, "LeftLeg": (0, -2, 0), "RightLeg": (0, 2, 0), "key": (-4, 0, 0)},
			{"t": 1.4, "cap": "Shields hover in a ring, portals fade", "fx": ["shield_portals_fade", "shields:0"], "arena": "gold", "root": (0, 0, 0), "torso": (-2, 0, 0), "head": (-2, 0, 0), "LeftArm": {"aim": (2.4, -1.8, 3.4)}, "RightArm": {"aim": (-2.4, -1.8, 3.4)}, "LeftLeg": (0, 0, 0), "RightLeg": (0, 0, 0), "key": (0, 0, 0)},
			fold(t=2.2, cap="Fortified: arms folded behind the shield ring (status set)", event="Fortified", fx=["shields:20"], arena="gold", root=(0, 0, 0), torso=(0, 0, 0), head=(-4, 0, 0), LeftLeg=(0, 0, 0), RightLeg=(0, 0, 0), key=(0, 0, 0)),
		],
	},
	"fortified_idle": {
		"title": "Fortified idle: the shield ring orbits while he stands",
		"end": 4.0,
		"loop": True,
		"keys": [
			fold(t=0.0, cap="Ring at 0 degrees, breath out", fx=["shields:0"], body=(0, 1, 0), torso=(2, 0, 2), head=(0, 0, -3), LeftLeg=(0, -1, 0), RightLeg=(0, -1, 0), key=(0, 0, 0)),
			fold(t=1.33, cap="Ring a third round, breath in", fx=["shields:120"], body=(0, 0, 0), torso=(-3, 0, 0), head=(-4, 0, 0), RightArm={"aim": (1.0, -1.55, 2.85)}, LeftArm={"aim": (-1.0, -1.65, 1.95)}, key=(2, 0, 0)),
			fold(t=2.67, cap="Ring two thirds round, breath out", fx=["shields:240"], body=(0, -1, 0), torso=(2, 0, -2), head=(0, 0, 3), LeftLeg=(0, 1, 0), RightLeg=(0, 1, 0), key=(0, 0, 0)),
		],
	},
}
# The volley window: keys on the gates clock between its Fire key (1.60 s) and its last volley (3.60 s). window panels at 0, 1, 2 s.
MOVES["gates_window"] = {
	"title": "Gates of Babylon: the 2 s volley burst from the runner's view (after key 3)",
	"extends": "gates",
	"window": "gates",
	"window_start": 1.6,
	"end": 4.4,
	"keys": [
		{"t": 1.6, "cap": "Window 0.0 s: volley 1 fires, arm thrust at the lanes", "fx": ["portals_open", "streaks:0"], "arena": "gold", **FIRE},
		{"t": 2.6, "cap": "Window 1.0 s: volley 7, torso sways with the arm", "fx": ["portals_open", "streaks:6"], "arena": "gold", "root": (0.2, -0.15, 0), "torso": (12, -6, 10), "head": (4, 2, -8), "RightArm": {"aim": (-2.6, -3.2, 3.2)}, "LeftArm": {"aim": (2.4, 1.2, 2.0)}, "LeftLeg": (-8, 0, -3), "RightLeg": (10, 0, 3), "key": (12, 0, 0)},
		{"t": 3.6, "cap": "Window 2.0 s: volley 14, the last; portals start to close", "fx": ["portals_fade", "streaks:13"], "arena": "gold", **LAST},
	],
}
# APPROVED: the keys above were pre-approved by the owner 2026-11-11 (design doc 4.37 Third boss) and baked by bake_boss_king.py.
# The 2026-11-12 animation rework re-keys every move: new keys go through the full owner gate, listed here as boss_mage_keyframes does.
PANELS = (0.0, 1.0, 2.0)  # window panel times, seconds into the volley burst
GOLD, GOLD_HI, RED, DARK = (1.0, 0.72, 0.18), (1.0, 0.92, 0.6), (0.95, 0.08, 0.04), (0.12, 0.0, 0.0)


# ---- portals, streaks and shields: layout in his model space ----


def portal_set():
	"""(centre, radius, outward normal) per portal, model units: round his sides and back, 2.5 to 10 units up."""
	rng = random.Random(7)
	out = []
	for i in range(N_PORTALS):
		th = math.radians(-30 + 240 * i / (N_PORTALS - 1))  # +X is his left, +Y his back: from left-front, round the back, to right-front
		r = 4.5 + rng.uniform(0, 3.0)
		c = Vector((r * math.cos(th), r * math.sin(th), 2.5 + rng.uniform(0, 7.5)))
		n = Vector((math.cos(th) + rng.uniform(-0.2, 0.2), math.sin(th) + rng.uniform(-0.2, 0.2), -0.15)).normalized()
		out.append((c, rng.uniform(0.7, 1.3), n))
	return out


PORTALS = portal_set()


def volley(j):
	"""Volley j of 14: VOLLEY weapons, each a portal and a direction (yaw jitter, pitch down) in his frame."""
	rng = random.Random(500 + j)
	return [(i, rng.uniform(-30, 30), rng.uniform(-14, -3)) for i in rng.sample(range(N_PORTALS), VOLLEY)]


SHIELDS = ("round", "kite", "tower", "rect", "round2", "kite2")  # proposed looks: round, kite, tower, Mesopotamian rectangular
SHIELD_R, SHIELD_Z = 4.2, 3.8  # the ring's radius and height, model units


def shield_outline(kind):
	if kind.startswith("round"):
		r = 1.1 if kind == "round" else 0.95
		return [(r * math.cos(a), r * math.sin(a)) for a in np.linspace(0, math.tau, 32, endpoint=False)]
	if kind.startswith("kite"):
		return [(-1.0, 0.9), (-0.85, 1.2), (0, 1.35), (0.85, 1.2), (1.0, 0.9), (0.55, -0.5), (0, -1.6), (-0.55, -0.5)]
	if kind == "tower":
		return [(-0.7, -1.3), (0.7, -1.3), (0.7, 1.0), (0.5, 1.3), (0, 1.4), (-0.5, 1.3), (-0.7, 1.0)]
	return [(-0.65, -1.25), (0.65, -1.25), (0.65, 1.25), (-0.65, 1.25)]  # rect: Mesopotamian


def flat_mesh(name, pts, mat, scale=1.0):
	me = bpy.data.meshes.new(name)
	me.from_pydata([(x * scale, y * scale, 0) for x, y in pts], [], [list(range(len(pts)))])
	me.materials.append(mat)
	o = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(o)
	for c in o.users_collection:
		c.objects.unlink(o)
	FX.objects.link(o)
	return o


def frame_at(c, n):
	"""A matrix whose z is n, y as upright as n allows, at c (world)."""
	z = Vector(n).normalized()
	y = Vector((0, 0, 1)) - z * z.z
	y = y.normalized() if y.length > 1e-3 else Vector((0, 1, 0))
	x = y.cross(z)
	m = Matrix((x, y, z)).transposed().to_4x4()
	m.translation = c
	return m


# ---- the scene ----


def load_scene(arena):
	bpy.ops.wm.open_mainfile(filepath=arena)
	scene = bpy.context.scene
	scene.eevee.taa_render_samples = 24
	rig = mk.Rig()
	rig.arena = [o for o in scene.objects if o.type == "MESH"]
	for o in rig.arena:
		if o.name.startswith(("KingStandIn", "MageStandIn", "MageSpellOrb")):  # the draft's block stand-in: replaced by the model
			o.hide_render = True
	mound = [o for o in rig.arena if o.name.startswith("VaultCentreMound")]
	rig.stand = max((o.matrix_world @ v.co).z for o in mound for v in o.data.vertices if v.co.x**2 + v.co.y**2 < 16) if mound else 0.0
	rig.lights = [o for o in scene.objects if o.type == "LIGHT"]
	rig.air = scene.world
	nt = rig.air.node_tree
	rig.sky = (tuple(nt.nodes["SkyMix"].inputs["A"].default_value), tuple(nt.nodes["SkyMix"].inputs["B"].default_value), next(n for n in nt.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value)
	rig.flat = bpy.data.worlds.new("Flat")
	sun = bpy.data.objects.new("FlatSun", bpy.data.lights.new("FlatSun", "SUN"))
	sun.data.energy, sun.data.angle = 2.4, math.radians(25)
	scene.collection.objects.link(sun)
	rig.sun = sun
	rig.cam = scene.camera
	rig.bloom = scene.compositing_node_group.nodes["Bloom"]
	with bpy.data.libraries.load(os.path.join(ROOT, "assets", "characters_avatar", "boss_king", MODEL + ".blend")) as (src, dst):
		dst.objects = list(src.objects)
	for o in dst.objects:
		scene.collection.objects.link(o)
	king = next(o for o in dst.objects if o.parent is None and o.type == "EMPTY")
	rig.king = king
	rig.parts = {o.name.split(".")[0]: o for o in king.children_recursive}  # the vault's key light is "Key": his Key appends as Key.001
	rig.rest = {n: o.matrix_basis.copy() for n, o in rig.parts.items()}
	pts = be.world_verts([rig.parts[n] for n in BODY])
	rig.model_h = float(pts[:, 2].max() - pts[:, 2].min())
	rig.k = SIZE * CHAR_H / rig.model_h  # studs per model unit in game
	king.location, king.rotation_euler, king.scale = (0, 0, rig.stand + (HOVER_STUDS if REWORK else 0)), (0, 0, FACE), (rig.k,) * 3
	rig.drums = {}
	for n in EA_PARTS[1:]:  # each drum's mid height and radius, Ea-local, for the spin arrows
		co = np.array([v.co for v in rig.parts[n].data.vertices])
		rig.drums[n] = (float(co[:, 2].mean()), float(np.hypot(co[:, 0], co[:, 1]).max()))
	rig.tip = float(np.array([v.co for v in rig.parts["Ea_Drum3"].data.vertices])[:, 2].max())
	bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, rig.stand - 0.02))
	rig.floor = bpy.context.object  # his close views: a plain floor at the mound's top
	rig.floor.data.materials.append(mk.matte_mat("FlatFloor", (0.5, 0.46, 0.4)))
	global FX
	FX = mk.FX = bpy.data.collections.new("FX")
	scene.collection.children.link(FX)
	return scene, rig


def look(scene, rig, mode):
	"""flat / dark: a plain backdrop for his close views. gold / red: the vault lit for a wide view."""
	arena = mode in ("gold", "red")
	for o in rig.arena:
		o.hide_render = o.hide_render if o.name.startswith(("KingStandIn", "MageStandIn", "MageSpellOrb")) else not arena
	rig.floor.hide_render = arena
	rig.sun.hide_render = arena
	for o in rig.lights:
		o.hide_render = not arena
	if arena:
		scene.world = rig.air
		nt = rig.air.node_tree
		a, b, strength = rig.sky if mode == "gold" else (mk.be_rgb("#7A1212"), mk.be_rgb("#2A0606"), 0.7)
		nt.nodes["SkyMix"].inputs["A"].default_value = a
		nt.nodes["SkyMix"].inputs["B"].default_value = b
		next(n for n in nt.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = strength
		scene.view_settings.view_transform = "AgX"
		scene.view_settings.look = "None" if mode == "gold" else "AgX - Punchy"
		rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 0.8, 0.5 if mode == "gold" else 0.9
	else:
		scene.world = rig.flat
		bg = next(n for n in rig.flat.node_tree.nodes if n.type == "BACKGROUND")
		bg.inputs["Color"].default_value = (0.78, 0.8, 0.84, 1) if mode == "flat" else (0.09, 0.025, 0.02, 1)
		bg.inputs["Strength"].default_value = 0.8 if mode == "flat" else 1.0
		rig.sun.data.energy = 2.4 if mode == "flat" else 1.5
		rig.sun.data.color = (1, 1, 1) if mode == "flat" else (1.0, 0.8, 0.75)
		rig.sun.rotation_euler = (math.radians(50), math.radians(10), FACE + math.radians(-25))
		scene.view_settings.view_transform = "Standard"
		scene.view_settings.look = "None"
		rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 1.0, 0.35


def to_world(rig, p):
	return rig.king.matrix_world @ Vector(p)


def to_world_dir(rig, d):
	return (rig.king.matrix_world.to_3x3() @ Vector(d)).normalized()


# ---- the pose solver ----


def solve(key):
	"""Model-space matrix per part (applied on top of its rest) and the plain local rotations for keys.json."""
	rot = {"Body": eul(key.get("body", (0, 0, 0))), "Torso": eul(key.get("torso", (0, 0, 0))), "Head": eul(key.get("head", (0, 0, 0))), "Key": eul(key.get("key", (0, 0, 0)))}
	for n in LEG:
		rot[n] = eul(key.get(n, (0, 0, 0)))
	for n in SHOULDER:
		a = key.get(n, (0, 0, 0))
		rot[n] = eul((0, 0, 0)) if a == "grip" else (aim_rot(SHOULDER[n], a["aim"]) if isinstance(a, dict) else eul(a))
	m = {}
	body = Matrix.Translation(key.get("root", (0, 0, 0))) @ about(HIP, rot["Body"])
	torso = body @ about(WAIST, rot["Torso"])
	m["Torso_merged"] = torso
	m["Head_merged"] = torso @ about(NECK, rot["Head"])
	m["Key"] = torso @ about(KEY_PIVOT, rot["Key"])
	for n in LEG:
		m[n + "_merged"] = body @ about(LEG[n], rot[n])
	arm = {n: about(SHOULDER[n], rot[n]) for n in SHOULDER}
	grip, spin = None, key.get("spin", 0)
	if "ea" in key:
		local = Matrix.Translation(HAND["RightArm"] - EA_PIVOT) @ about(EA_PIVOT, eul(key["ea"]))  # grip on the fist, turned about it
		ea = arm["RightArm"] @ local  # torso space
		if key.get("LeftArm") == "grip":
			rot["LeftArm"] = aim_rot(SHOULDER["LeftArm"], ea @ (EA_PIVOT + Vector((0, 0, GRIP_UP))))
			arm["LeftArm"] = about(SHOULDER["LeftArm"], rot["LeftArm"])
		m["Ea"] = torso @ ea
		r3 = local.to_3x3()
		rot["Ea"] = r3.to_4x4()
		grip = [round(v, 4) for v in local.translation - (EA_PIVOT - r3 @ EA_PIVOT)]
	for n in SHOULDER:
		m[n + "_merged"] = torso @ arm[n]
	record = {n: degs(r) for n, r in rot.items()}
	for n, sign in zip(EA_PARTS[1:], (1, -1, 1)):
		record[n] = [0.0, 0.0, round(sign * spin, 3)]
	return m, record, grip


def pose_king(rig, key):
	if REWORK:
		m, record, grip, short = jsolve(key)
		far = {k: v for k, v in short.items() if v > 0.05}
		if far:
			print("REACH", key["t"], far)
	else:
		m, record, grip = solve(key)
	for n, o in rig.parts.items():
		if n in EA_PARTS:
			o.hide_render = "ea" not in key
			o.rotation_euler = (0, 0, math.radians(record.get(n, (0, 0, 0))[2]))
		else:
			o.matrix_basis = m.get(n, Matrix()) @ rig.rest[n]
	bpy.context.view_layer.update()
	return record, grip


# ---- effects per key ----


def streak_end(p, d):
	"""Where a straight shot from p along d meets the floor or the wall, studs."""
	t = -p.z / d.z if d.z < 0 else 1e9
	a2, b2 = d.x**2 + d.y**2, 2 * (p.x * d.x + p.y * d.y)
	t = min(t, (-b2 + math.sqrt(b2 * b2 - 4 * a2 * (p.x**2 + p.y**2 - R_WALL**2))) / (2 * a2), 320.0)
	return p + d * t


def portal(rig, c, rad, n, state):
	"""A gold ripple portal: a soft disc and two rings facing outward, with a weapon tip poking out (open) or no tip (faint, fade)."""
	cw, nw, r = to_world(rig, c), to_world_dir(rig, n), rad * rig.k
	rot = frame_at(cw, nw).to_euler()
	a = {"faint": 0.3, "open": 1.0, "fade": 0.45}[state]
	rr = r * (0.55 if state == "faint" else (1.15 if state == "fade" else 1.0))
	mk.disc(cw, rr, mk.glow_mat("PortalFill", GOLD, 1.0, 0.35 * a), rot=rot)
	mk.ring(cw, rr, 0.07 * rr, mk.glow_mat("PortalRing", GOLD_HI, 3.5 * a, min(1, 0.9 * a + 0.1)), rot=rot)
	mk.ring(cw, rr * 0.62, 0.04 * rr, mk.glow_mat("PortalRipple", GOLD, 2 * a, min(1, 0.7 * a + 0.1)), rot=rot)
	if state == "open":
		tip = cw + nw * (1.1 * r)
		mk.tube([cw + nw * 0.1 * r, tip], 0.07 * r, mk.glow_mat("TipCore", GOLD_HI, 6))
		side = nw.orthogonal().normalized() * 0.3 * r
		mk.tube([cw + nw * 0.3 * r - side, cw + nw * 0.3 * r + side], 0.05 * r, mk.glow_mat("TipGuard", GOLD, 4))  # a cross guard: it is a weapon


def streak(rig, i, yaw, pitch, dim=False):
	c, rad, n = PORTALS[i]
	p = to_world(rig, c)
	th = math.atan2(c.y, c.x) + math.radians(yaw)
	d = Vector((math.cos(th) * math.cos(math.radians(pitch)), math.sin(th) * math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
	d = to_world_dir(rig, d)
	end = streak_end(p, d)
	w = 0.5 * SIZE / 4
	if dim:
		mk.tube([p, end], w * 0.6, mk.glow_mat("StreakFade", GOLD, 0.9, 0.3))
		mk.ring(end, w * 6, w * 0.6, mk.glow_mat("ClinkFade", GOLD, 0.8, 0.3))
		return
	mk.tube([p, end], w, mk.glow_mat("StreakCore", GOLD_HI, 14))
	mk.tube([p, end], w * 2.2, mk.glow_mat("StreakGlow", GOLD, 2.5, 0.5))
	mk.tube([p, end], w * 4.5, mk.glow_mat("StreakHalo", GOLD, 0.6, 0.25))["wide_only"] = True
	mk.ball(end, w * 3, mk.glow_mat("ClinkCore", GOLD_HI, 14))
	mk.ring(end, w * 6, w * 0.8, mk.glow_mat("ClinkRing", GOLD, 4, 0.8))
	mk.lamp(end + (p - end).normalized() * 4, GOLD, 2e4, 4)


def shield(rig, kind, c, n, size, portal_plane=False):
	"""One shield facing outward along n at c (model units), its field inset; gold rim, navy or red field."""
	cw, nw = to_world(rig, c), to_world_dir(rig, n)
	m = frame_at(cw, nw)
	k = rig.k * size
	pts = shield_outline(kind)
	body = flat_mesh("Shield", pts, mk.matte_mat("ShieldGold", (0.85, 0.62, 0.18)), k)
	body.modifiers.new("thick", "SOLIDIFY").thickness = 0.12 * k
	body.matrix_world = m
	field = flat_mesh("ShieldField", [(x * 0.72, y * 0.72) for x, y in pts], mk.matte_mat("ShieldNavy" if kind in ("round", "tower", "kite2") else "ShieldRed", (0.1, 0.12, 0.32) if kind in ("round", "tower", "kite2") else (0.55, 0.08, 0.08)), k)
	field.matrix_world = m @ Matrix.Translation((0, 0, 0.02 * k))
	if kind.startswith("round"):
		mk.ball(cw + nw * 0.1 * k, 0.18 * k, mk.matte_mat("ShieldGold", (0.85, 0.62, 0.18)))
	if kind == "rect":  # Mesopotamian: three gold bands across
		for y in (-0.7, 0, 0.7):
			mk.tube([m @ Vector((-0.65 * k, y * k, 0.03 * k)), m @ Vector((0.65 * k, y * k, 0.03 * k))], 0.05 * k, mk.glow_mat("Band", GOLD, 1.2))


def shield_ring(rig, yaw, state):
	"""The ring of shields round him: state emerge (in their portals) or a ring angle; portals from shield_portals."""
	for i, kind in enumerate(SHIELDS):
		th = math.radians(yaw + 360 * i / N_SHIELDS)
		n = Vector((math.cos(th), math.sin(th), 0.1)).normalized()
		c = Vector((SHIELD_R * math.cos(th), SHIELD_R * math.sin(th), SHIELD_Z + (0.4 if i % 2 else -0.3)))
		if state != "emerge":
			c += Vector((math.cos(th), math.sin(th), 0)) * 0.9
		shield(rig, kind, c, n, 0.95 if state == "emerge" else 1.0)


def shield_portals(rig, state):
	for i in range(N_SHIELDS):
		th = math.radians(360 * i / N_SHIELDS)
		c = Vector((SHIELD_R * math.cos(th), SHIELD_R * math.sin(th), SHIELD_Z + (0.4 if i % 2 else -0.3)))
		portal(rig, c, 1.4, Vector((math.cos(th), math.sin(th), 0.1)), state)


def arrows(rig, spin):
	"""Render marks only: a cyan arc with an arrowhead round each drum, its direction the drum's spin (Drum2 the other way)."""
	ea = rig.parts["Ea"].matrix_world
	for n, sign in zip(EA_PARTS[1:], (1, -1, 1)):
		z, r = rig.drums[n]
		rr = r * 1.7
		pts = [ea @ Vector((rr * math.cos(sign * a), rr * math.sin(sign * a), z)) for a in np.linspace(0, math.radians(260), 18)]
		mk.tube(pts, 0.035 * rig.k, mk.glow_mat("Arrow", (0.35, 0.9, 1.0), 6))
		head = ea.to_3x3() @ (Vector((rr * math.cos(sign * math.radians(275)), rr * math.sin(sign * math.radians(275)), z)) - Vector((rr * math.cos(sign * math.radians(255)), rr * math.sin(sign * math.radians(255)), z)))
		bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.12 * rig.k, depth=0.3 * rig.k, location=pts[-1])
		cone = mk.fx_link(bpy.context.object, mk.glow_mat("Arrow", (0.35, 0.9, 1.0), 6))
		cone.rotation_euler = Vector((0, 0, 1)).rotation_difference(head.normalized()).to_euler()
	if spin:
		mk.lamp(ea @ Vector((0, 0, rig.drums["Ea_Drum2"][0])), (0.5, 0.9, 1.0), 2e3, 2)


def wind_turns(t):
	"""Turns the swirl has made by t s on the move's clock: 1 turn per 0.8 s up to 1.45 s, speeding to 1 per 0.35 s at 2.75 s (proposed)."""
	a, b, ra, rb = 1.45, 2.75, 1 / 0.8, 1 / 0.35
	if t <= a:
		return t * ra
	u = min(t, b) - a
	return a * ra + u * ra + (rb - ra) * u * u / (2 * (b - a)) + max(t - b, 0) * rb


def wind(rig, t, view):
	"""Ea's white wind: helix ribbons round the line from his feet to Ea's tip, turned by wind_turns(t), more, tighter and with more
	turns as the charge grows. Thicker and brighter toward the tip, faded at both ends. Pieces on the camera's side of the axis are
	thin and faint so they never hide his pose (view: toward the camera); the first ribbon is pink, so the turn reads key to key."""
	k = rig.k
	ea = rig.parts["Ea"].matrix_world
	g = min(max((t - 1.45) / 1.3, 0), 1)  # 0 early charge, 1 the peak
	n, turns = 4 + round(2 * g), 1.3 + 1.0 * g
	r_low, r_high = (4.2 - 0.9 * g) * k, (1.9 - 0.4 * g) * k
	body = be.world_verts([rig.parts[b] for b in BODY])
	base = Vector((float(body[:, 0].mean()), float(body[:, 1].mean()), float(body[:, 2].min())))
	axis = ea @ Vector((0, 0, rig.tip)) - base
	e1 = axis.orthogonal().normalized()
	e2 = axis.normalized().cross(e1)
	toward = (view or Vector((0, -1, 0))).normalized()
	spin = math.tau * wind_turns(t)

	def ribbon(phase, s0, length, width, pieces, rgb, glow=2.5):
		ss = np.linspace(s0, s0 + length, pieces * 4 + 1)
		for j in range(pieces):
			seg = ss[j * 4 : j * 4 + 5]
			u = (j + 0.5) / pieces
			env = math.sin(math.pi * u) ** 0.7
			s_mid = float(seg[2])
			pts = [base + axis * s + (e1 * math.cos(phase + math.tau * turns * s) + e2 * math.sin(phase + math.tau * turns * s)) * (r_low + (r_high - r_low) * s) for s in seg]
			near = (pts[2] - (base + axis * s_mid)).dot(toward) > 0
			w = width * (0.35 + 0.65 * s_mid) * env * (0.35 if near else 1)
			alpha = round(min(1, env * (0.45 + 0.55 * s_mid) * (0.5 if near else 1)), 1)
			if alpha > 0:
				mk.tube(pts, max(w, 0.008 * k), mk.glow_mat("Wind", rgb, glow, alpha))

	for i in range(n):
		ribbon(math.tau * i / n + spin, 0.04 + 0.12 * (i % 2), 0.82, (0.09 - 0.025 * g) * k, 14, *(((1.0, 0.3, 0.42), 1.4) if i == 0 else ((1.0, 0.93, 0.92), 2.5)))
	for j in range(4 + 4 * round(g)):  # short dashes between the ribbons, climbing with time
		s0 = ((j * 0.37 + wind_turns(t)) % 1.0) * 0.8 + 0.08
		ribbon(math.tau * (j * 0.61) + spin + math.pi / n, s0, 0.05, 0.035 * k, 1, (1.0, 0.93, 0.92))


def build_fx(rig, names, seed, t=0.0, view=None):
	rng = random.Random(seed)
	k, s = rig.k, SIZE / 4
	ea = rig.parts["Ea"].matrix_world
	for name in names:
		kind, _, arg = name.partition(":")
		if kind.startswith("portals"):
			for c, rad, n in PORTALS:
				portal(rig, c, rad, n, kind.split("_")[1])
			if kind == "portals_open":
				mk.lamp(to_world(rig, (0, 2, 7)), GOLD, 1.2e4 * s * s, 6)
		elif kind == "streaks":
			j = int(arg)
			for i, yaw, pitch in volley(j):
				streak(rig, i, yaw, pitch)
			if j > 0:
				for i, yaw, pitch in volley(j - 1):
					streak(rig, i, yaw, pitch, dim=True)
		elif kind == "shield_portals":
			shield_portals(rig, "open")
		elif kind == "shield_portals_fade":
			shield_portals(rig, "fade")
		elif kind == "shields":
			shield_ring(rig, 0 if arg == "emerge" else float(arg), "emerge" if arg == "emerge" else "ring")
		elif kind == "draw":  # Ea comes out of a ripple at the fist: a portal round the grip, its plane across the blade
			g = ea.translation
			axis = ea.to_3x3() @ Vector((0, 0, 1))
			rot = frame_at(g + axis * 0.6 * k, axis).to_euler()
			mk.disc(g + axis * 0.6 * k, 1.6 * k, mk.glow_mat("PortalFill", GOLD, 1.5, 0.35), rot=rot)
			mk.ring(g + axis * 0.6 * k, 1.6 * k, 0.1 * k, mk.glow_mat("PortalRing", GOLD_HI, 8, 1.0), rot=rot)
			mk.ring(g + axis * 0.6 * k, 1.0 * k, 0.06 * k, mk.glow_mat("PortalRipple", GOLD, 4, 0.8), rot=rot)
			mk.lamp(g + axis * 1.5 * k, GOLD, 3e4 * s * s, 4)
		elif kind == "arrows":
			arrows(rig, True)
		elif kind == "wind":
			wind(rig, t, view)
		elif kind == "charge":
			tip = ea @ Vector((0, 0, rig.tip))
			mk.ball(tip, 0.5 * k, mk.glow_mat("TipGlow", RED, 6, 0.6))
			for d in EA_PARTS[1:]:
				z, r = rig.drums[d]
				mk.ring(ea @ Vector((0, 0, z)), r * 1.25 * k, 0.03 * k, mk.glow_mat("DrumGlow", RED, 5, 0.7), rot=ea.to_3x3().normalized().to_euler())
			mk.lamp(tip, RED, 1.2e5 * s * s, 6)
		elif kind == "gather":  # red-black air pulled into the tip: dark rings closing on it
			tip = ea @ Vector((0, 0, rig.tip))
			axis = ea.to_3x3() @ Vector((0, 0, 1))
			for i, rr in enumerate((2.2, 3.2, 4.4)):
				mk.ring(tip + axis * (0.4 + 0.5 * i) * k, rr * k, 0.14 * k, mk.glow_mat("GatherDark" if i % 2 else "GatherRed", DARK if i % 2 else RED, 1.5 if i % 2 else 4, 0.8), rot=frame_at(tip, axis).to_euler())
			mk.ball(tip, 1.0 * k, mk.glow_mat("GatherCore", (0.3, 0.02, 0.02), 3, 0.5))
		elif kind == "beam" and REWORK:  # the owner's later look (2026-11-12): white core, red-black layers, turning cyclone, burst
			jbeam(rig, t)
		elif kind == "beam":
			tip = ea @ Vector((0, 0, rig.tip))
			d = (ea.to_3x3() @ Vector((0, 0, 1))).normalized()
			end = streak_end(tip, d)
			L = (end - tip).length
			mk.tube([tip, end], 1.4 * s, mk.glow_mat("BeamDark", (0.3, 0.02, 0.02), 2.5))
			mk.tube([tip, end], 3.2 * s, mk.glow_mat("BeamRed", RED, 2.2, 0.5))
			mk.tube([tip, end], 7 * s, mk.glow_mat("BeamHalo", RED, 0.6, 0.2))["wide_only"] = True
			side = d.orthogonal().normalized()
			up = d.cross(side)
			for h in range(3):  # the cyclone: three strands wound round the beam, widening toward the hit
				ph = h * math.tau / 3
				pts = [tip + d * (t * L) + (side * math.cos(ph + t * 22) + up * math.sin(ph + t * 22)) * (2 + 9 * t) * s for t in np.linspace(0, 1, 90)]
				mk.tube(pts, 0.7 * s, mk.glow_mat("CycloneDark" if h == 1 else "CycloneRed", DARK if h == 1 else RED, 1.2 if h == 1 else 3, 0.75))
			mk.disc(end, 14 * s, mk.glow_mat("BeamHit", RED, 2.5, 0.6), rot=frame_at(end, -d).to_euler())
			mk.ring(end, 18 * s, 1.2 * s, mk.glow_mat("BeamHitRing", DARK, 2, 0.8), rot=frame_at(end, -d).to_euler())
			mk.ball(tip, 1.2 * k, mk.glow_mat("TipGlow", RED, 6, 0.6))
			mk.lamp(tip + d * 20, RED, 3e5 * s * s, 8)
			mk.lamp(end - d * 6, RED, 2e5 * s * s, 8)
		elif kind == "ball":  # a white ball builds at Ea's tip with red rings round it (clip 2 staging, drawn in-house)
			tip = ea @ Vector((0, 0, rig.tip))
			r = float(arg) * k
			mk.ball(tip, r, mk.glow_mat("BallCore", (1, 1, 1), 12))
			mk.ball(tip, r * 1.6, mk.glow_mat("BallHalo", (1, 0.85, 0.85), 2, 0.3))
			for i in range(3):
				mk.ring(tip, r * (1.9 + 0.5 * i), 0.06 * k, mk.glow_mat("BallRing", RED, 6, 0.9), rot=(math.radians(70 + 25 * i), math.radians(35 * i), math.radians(50 * i)))
			mk.lamp(tip, (1, 0.9, 0.9), 6e4 * s * s * float(arg), 4)
		elif kind == "flash":  # the one white flash before the beam
			tip = ea @ Vector((0, 0, rig.tip))
			mk.ball(tip, 1.1 * k, mk.glow_mat("FlashCore", (1, 1, 1), 25))
			mk.ball(tip, 2.0 * k, mk.glow_mat("FlashHalo", (1, 1, 1), 3, 0.25))
			for i in range(4):  # a white star flare across the tip
				d = Vector((math.cos(i * math.pi / 4), 0, math.sin(i * math.pi / 4)))
				mk.tube([tip - d * 4 * k, tip + d * 4 * k], 0.06 * k, mk.glow_mat("FlashRay", (1, 1, 1), 15))
			mk.lamp(tip, (1, 1, 1), 4e4 * s * s, 6)
		elif kind in ("jportals", "jvolley", "jshields", "cmd"):  # the rework's sketches (design C portals), below JMOVES
			JFX[kind](rig, arg)
		elif kind == "embers":
			tip = ea @ Vector((0, 0, rig.tip))
			for _ in range(6):
				dd = Vector([rng.uniform(-1, 1) for _ in range(3)]).normalized()
				mk.ball(tip + dd * rng.uniform(0.5, 2.0) * k, 0.12 * k, mk.glow_mat("Ember", RED, 4, 0.8))


def clear_fx():
	for o in list(FX.objects):
		bpy.data.objects.remove(o, do_unlink=True)


# ---- the animation rework: the jointed rig ----

JPARTS = ("Torso", "Head", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg")
JBODY = tuple(n + "_merged" for n in JPARTS)
ELBOW = {"LeftArm": Vector((1.5, 0, 3.1)), "RightArm": Vector((-1.5, 0, 3.1))}  # build_boss_king.SEAM: the R15 seams
KNEE = {"LeftLeg": Vector((0.5, 0, 1.1)), "RightLeg": Vector((-0.5, 0, 1.1))}
POLE = {"LeftArm": (0.6, 1, -0.3), "RightArm": (-0.6, 1, -0.3)}
SEG = {"RightArm": ("RightUpperArm", "RightLowerArm"), "LeftArm": ("LeftUpperArm", "LeftLowerArm"), "LeftLeg": ("LeftUpperLeg", "LeftLowerLeg"), "RightLeg": ("RightUpperLeg", "RightLowerLeg")}
JPARENT = {"Body": None, "Torso": "Body", "Head": "Torso", "Key": "Torso", "Ea": "RightLowerArm"}
for _limb, (_up, _lo) in SEG.items():
	JPARENT[_up], JPARENT[_lo] = ("Torso" if _limb.endswith("Arm") else "Body"), _up
# The rework keys (proposed, owner gate pending): Enuma Elish re-keyed in the air on the jointed rig. Root offsets in model units
# (1 unit = about 6.7 studs at 8x) from the hover height; legs hang, tuck and trail as an airborne body's do.
FOLD2 = {"RightArm": {"aim": (-0.2, -0.9, 3.25), "pole": (-1, 0.3, -0.8)}, "LeftArm": {"aim": (0.45, -1.15, 2.8), "pole": (1, 0.3, -0.8)}}
IDLE0 = {"root": (0, 0, 0), "body": (0, 0, 0), "torso": (2, 0, 4), "head": (-5, 0, -8), **FOLD2, "LeftLeg": {"hip": (-8, 0, -3), "knee": 22}, "RightLeg": {"hip": (4, 0, 4), "knee": 30}, "key": (0, 0, 0)}
EA_OUT = {"at": (-2.9, 0.9, 1.0), "dir": (0, 0.15, 1)}  # Ea standing in its gold ripple behind his right side, hilt at his hip
JMOVES = {
	"enuma": {
		"title": "Enuma Elish (rework, jointed rig, hovering): draw, raise, 3 s charge, swing, 2 s beam sweep, recover",
		"end": 5.6,
		"window": [0.0, 3.0],
		"cols": 5,
		"keys": [
			{"t": 0.0, "cap": "Idle key 0: arms folded, hovering, legs loose; Ea rises out of a gold ripple behind his right side", "fx": ["draw"], **IDLE0, "ea": EA_OUT, "spin": 0},
			{"t": 0.45, "cap": "Anticipation: unfolds and curls down, hips turn right, right hand drops to Ea's hilt, knees tuck, eyes up", "fx": ["draw"], "root": (-0.15, 0.1, -0.35), "body": (0, 0, -16), "torso": (20, -10, -20), "head": (-14, 4, 16), "RightArm": {"aim": (-2.3, 0.7, 2.6), "pole": (-0.5, 1, 0)}, "LeftArm": {"aim": (1.3, -1.8, 3.3), "pole": (1, 0.5, -0.5)}, "LeftLeg": {"hip": (-40, 0, -4), "knee": 70}, "RightLeg": {"hip": (-15, 0, 6), "knee": 55}, "key": (8, 0, 0), "ea": {"dir": (-0.2, 0.3, 1)}, "spin": 0},
			{"t": 0.95, "cap": "Raise, overshoot: Ea flung up on one straight arm past the top, chest arched open, left arm thrown out, legs trail", "fx": ["arrows"], "root": (0.1, 0.1, 0.35), "body": (0, 4, 10), "torso": (-22, 8, 12), "head": (-30, 4, -6), "RightArm": {"aim": (-2.0, 0.8, 5.8)}, "LeftArm": {"aim": (3.3, -0.4, 2.6)}, "LeftLeg": {"hip": (10, 0, -6), "knee": 15}, "RightLeg": {"hip": (22, 0, 8), "knee": 35}, "key": (-8, 0, 0), "ea": {"dir": (-0.25, 0.45, 1)}, "spin": 60},
			{"t": 1.45, "cap": "Settle, charge holds: Ea back upright, left fist braced low, white ball and red rings at the tip, grooves glow", "fx": ["arrows", "wind", "charge", "ball:0.5"], "root": (0, 0, 0.25), "body": (0, 0, 4), "torso": (-10, 4, 6), "head": (-20, 0, -4), "RightArm": {"aim": (-1.8, -0.2, 6.0)}, "LeftArm": {"aim": (2.5, -1.2, 2.3)}, "LeftLeg": {"hip": (-6, 0, -4), "knee": 25}, "RightLeg": {"hip": (12, 0, 6), "knee": 40}, "key": (-4, 0, 0), "ea": {"dir": (-0.1, 0.05, 1)}, "spin": 200},
			{"t": 2.1, "cap": "Charge, strain: he rises and leans back into the wind, left forearm shields his face, legs blown back, drums faster", "fx": ["arrows", "wind", "charge", "ball:0.9"], "root": (0.25, 0.15, 0.45), "body": (0, -6, 8), "torso": (-16, -6, 8), "head": (-22, -4, -8), "RightArm": {"aim": (-1.7, 0.3, 6.0)}, "LeftArm": {"aim": (0.4, -1.6, 4.4), "pole": (1, 0.3, -1)}, "LeftLeg": {"hip": (14, 0, -8), "knee": 45}, "RightLeg": {"hip": (4, 0, 10), "knee": 20}, "key": (-8, 0, 0), "ea": {"dir": (-0.05, 0.15, 1)}, "spin": 450},
			{"t": 2.75, "cap": "Wind-up: Ea cocked far back behind his head, left arm points at the arena, back arched, left knee drawn up, at his highest", "fx": ["arrows", "wind", "charge", "ball:1.4", "gather"], "root": (0, 0.35, 0.6), "body": (0, 0, -20), "torso": (-26, 0, -10), "head": (-8, 0, 8), "RightArm": {"aim": (-1.4, 1.2, 5.0), "pole": (-1, 0, -0.3)}, "LeftArm": {"aim": (1.6, -1.8, 4.0)}, "LeftLeg": {"hip": (-75, 0, -6), "knee": 95}, "RightLeg": {"hip": (18, 0, 6), "knee": 60}, "key": (-12, 0, 0), "ea": {"dir": (-0.1, 0.9, 0.45)}, "spin": 720},
			{"t": 3.0, "view": (0.25, 1, 0.2), "cap": "Contact (hit): swung down side-on, both hands on Ea levelled at the arena, torso thrown into it, legs kicked back; white flash, beam", "event": "Beam", "fx": ["flash", "beam", "arrows"], "root": (-0.3, 0, -0.3), "body": (0, 0, -180), "torso": (8, 26, 10), "head": (-6, 10, 62), "RightArm": {"aim": (-0.2, -1.3, 2.9)}, "LeftArm": "grip", "LeftLeg": {"hip": (-24, -10, 0), "knee": 50}, "RightLeg": {"hip": (14, -22, 0), "knee": 70}, "key": (6, 10, 0), "ea": {"dir": (1, -0.35, -0.2)}, "spin": 820},
			{"t": 3.9, "cap": "Beam drive: his whole body sweeps round over the lanes, hips lead, torso lags, both hands on Ea, legs braced against the recoil", "fx": ["beam", "arrows"], "root": (-0.25, 0, -0.2), "body": (0, 0, -70), "torso": (4, 18, -12), "head": (-4, 8, 58), "RightArm": {"aim": (-0.4, -1.4, 3.0)}, "LeftArm": "grip", "LeftLeg": {"hip": (-10, -16, 0), "knee": 35}, "RightLeg": {"hip": (20, -28, 0), "knee": 45}, "key": (4, 8, 0), "ea": {"dir": (1, -0.35, -0.2)}, "spin": 1000},
			{"t": 4.85, "cap": "Beam end: the sweep closes its circle, recoil pushes him upright, Ea held down on the lanes, legs swing through", "fx": ["beam", "arrows"], "root": (-0.15, 0, -0.1), "body": (0, 0, 72), "torso": (-6, 4, -22), "head": (-10, 0, 50), "RightArm": {"aim": (-0.3, -1.4, 3.3)}, "LeftArm": "grip", "LeftLeg": {"hip": (6, -6, 0), "knee": 60}, "RightLeg": {"hip": (-20, -12, 0), "knee": 30}, "key": (0, 4, 0), "ea": {"dir": (1, -0.3, -0.22)}, "spin": 1180},
			{"t": 5.6, "cap": "Recover = idle key 0: arms folded again, Ea sinks back into its ripple, drums slow", "fx": ["draw", "embers"], **IDLE0, "ea": EA_OUT, "spin": 1260},
		],
	},
}
HOVER_STUDS = 12.0  # proposed (owner 2026-11-12: he hovers as the Elf Mage does; 1.5 stud bob over 3 s is played in game, not keyed)


# ---- the rework's other moves (task a3-king, proposed, owner gate pending): idle, gates, shields, fortified_idle ----
# Every move starts and ends on IDLE0. Gates portals are design C, the sun wheel (assets/ui/boss_king/portal_draft/portal_c.png):
# a dark notched rim with dots, a gold band, a glowing face with a three-arm ripple spiral and a white four-point core star,
# 12 slanted rays (one long). They open in his right arm's sweep, his left side first (spec: a growing cascade).


# The Gates dome (owner 2026-11-13 later, design doc 4.37 "Boss effects after playing"; every value proposed): fixed tiers on a
# dome round his chest, evenly spaced, alternate tiers offset half a step, none over DOME_TOP (open sky over him), larger low.
DOME_C, DOME_R = Vector((0, 0, 3.6)), 8.7  # his chest; 8.7 units = 58 studs at 8x
DOME_TIERS = ((8, 16, 28), (22, 14, 22), (38, 12, 18), (55, 8, 14))  # (elevation degrees, portals, studs across)
DOME_TOP = 60  # degrees: no portal above this
LANE_MID = 138.0  # studs from his centre: each portal faces this ring on the deck (lanes 110 to 166)
JVOLLEY = 16  # weapons a volley from the dome (proposed; the old arch fired VOLLEY)


def jportal_set():
	"""(centre, radius, facing) per portal, model units: the ordered dome, each portal facing outward from him and tilted down to
	the lanes straight out from it, so its weapon and shot fly along that facing (design doc 4.37 "Beams follow their source").
	Sorted in his sweep order for the cascade: his left (+X) first, round the back (+Y), to his front."""
	k = SIZE * CHAR_H / 6.63
	floor = -HOVER_STUDS / k  # the deck: his rest feet minus the hover
	out = []
	for t, (el, n, across) in enumerate(DOME_TIERS):
		assert el <= DOME_TOP
		e = math.radians(el)
		for i in range(n):
			az = math.tau * (i + 0.5 * (t % 2)) / n
			h = Vector((math.cos(az), math.sin(az), 0))
			c = DOME_C + h * DOME_R * math.cos(e) + Vector((0, 0, DOME_R * math.sin(e)))
			lane = h * (LANE_MID / k) + Vector((0, 0, floor))
			out.append((c, across / 2 / k, (lane - c).normalized()))
	out.sort(key=lambda p: (math.atan2(p[0].y, p[0].x) % math.tau, p[0].z))
	return out


JPORTALS = jportal_set()
assert len(JPORTALS) == sum(n for _, n, _ in DOME_TIERS) and all(p[2].z < 0 for p in JPORTALS)  # every portal tilts down to the lanes
JSHIELD_R = 4.6  # the rework's shield ring radius, model units (proposed)
CREAM, BROWN = (1.0, 0.95, 0.75), (0.2, 0.11, 0.05)


def tri_fan(name, pts2, mat, m):
	o = flat_mesh(name, pts2, mat)
	o.matrix_world = m
	return o


def portal_c(rig, c, rad, n, grow=1.0, tip=False, turn=0.0, cw=None, nw=None):
	"""Design C, the sun wheel, at c facing n (model units; or cw/nw already in world). grow < 0.3: the first bright dot only.
	tip: a weapon blade pushing out of the face toward n."""
	cw = cw if cw is not None else to_world(rig, c)
	nw = nw if nw is not None else to_world_dir(rig, n)
	R = rad * rig.k
	m = frame_at(cw, nw) @ Matrix.Rotation(turn, 4, "Z")
	if grow < 0.3:
		mk.ball(cw, 0.22 * R, mk.glow_mat("PortalDot", CREAM, 12))
		mk.ball(cw, 0.45 * R, mk.glow_mat("PortalDotHalo", GOLD, 2, 0.35))
		return
	r = R * grow
	rot = m.to_euler()
	lift = lambda dz: m @ Matrix.Translation((0, 0, dz * r))  # noqa: E731  (layers stacked toward the viewer)
	mk.disc(cw, 0.86 * r, mk.glow_mat("PortalFaceC", (0.85, 0.42, 0.04), 0.9, 0.95), rot=rot)
	mk.disc(m @ Vector((0, 0, 0.005 * r)), 0.6 * r, mk.glow_mat("PortalMidC", (1.0, 0.68, 0.15), 1.1, 0.8), rot=rot)
	mk.disc(m @ Vector((0, 0, 0.01 * r)), 0.3 * r, mk.glow_mat("PortalCoreC", GOLD_HI, 2.0, 0.8), rot=rot)
	mk.ring(cw, 0.97 * r, 0.075 * r, mk.matte_mat("PortalRimC", BROWN), rot=rot)
	mk.ring(cw, 0.86 * r, 0.05 * r, mk.glow_mat("PortalBandC", GOLD, 1.0), rot=rot)
	for j in range(16):  # the notched rim: wedges pointing in, a dot between each pair
		a, b = math.tau * j / 16, math.tau * (j + 0.5) / 16
		tri_fan("Notch", [(0.99 * math.cos(a - 0.07), 0.99 * math.sin(a - 0.07)), (0.99 * math.cos(a + 0.07), 0.99 * math.sin(a + 0.07)), (0.88 * math.cos(a), 0.88 * math.sin(a))], mk.matte_mat("PortalRimC", BROWN), lift(0.03) @ Matrix.Scale(r, 4))
		mk.ball(m @ Vector((0.93 * r * math.cos(b), 0.93 * r * math.sin(b), 0.03 * r)), 0.022 * r, mk.matte_mat("PortalRimC", BROWN))
	for j in range(12):  # slanted rays outside the rim, one long
		a = math.tau * j / 12 + 0.2
		L = 1.6 if j == 0 else 1.25
		tri_fan("Ray", [(1.02 * math.cos(a), 1.02 * math.sin(a)), (1.02 * math.cos(a + 0.16), 1.02 * math.sin(a + 0.16)), (L * math.cos(a + 0.3), L * math.sin(a + 0.3))], mk.glow_mat("PortalRayC", (1.0, 0.75, 0.3), 0.7), m @ Matrix.Scale(r, 4))
	for h in range(3):  # the three-arm ripple spiral
		pts = [m @ Vector((rr * math.cos(h * math.tau / 3 + 5.0 * s), rr * math.sin(h * math.tau / 3 + 5.0 * s), 0.02 * r)) for s, rr in ((s, (0.1 + 0.68 * s) * r) for s in np.linspace(0, 1, 28))]
		mk.tube(pts, 0.022 * r, mk.glow_mat("PortalSpiralC", CREAM, 2.2))
	star = [(0.34 * math.cos(math.tau * j / 8) * (1 if j % 2 == 0 else 0.22), 0.34 * math.sin(math.tau * j / 8) * (1 if j % 2 == 0 else 0.22)) for j in range(8)]
	tri_fan("Star", star, mk.glow_mat("PortalStarC", (1, 1, 1), 5), lift(0.04) @ Matrix.Scale(r, 4))
	if tip:  # a weapon pushing through, tip first (tip: how far out, 0 to 1): blade, then the guard once it is out
		L = float(tip)
		mk.tube([cw + nw * 0.02 * r, cw + nw * (0.1 + 1.0 * L) * r], 0.07 * r, mk.glow_mat("TipBlade", (0.95, 0.92, 0.85), 5))
		mk.ball(cw + nw * (0.1 + 1.0 * L) * r, 0.1 * r, mk.glow_mat("TipGlint", (1, 1, 1), 12))
		if L >= 1:
			side = (m.to_3x3() @ Vector((1, 0, 0))).normalized() * 0.3 * r
			mk.tube([cw + nw * 0.12 * r - side, cw + nw * 0.12 * r + side], 0.06 * r, mk.glow_mat("TipGuard", GOLD, 4))


def fx_jportals(rig, arg):
	"""jportals:<f>[:tips|:close]: the first f of JPORTALS (sweep order) opening; the cascade grows a dot, a small wheel, full."""
	frac, _, mode = arg.partition(":")
	opened = float(frac) * (len(JPORTALS) + 1.5)
	for i, (c, rad, n) in enumerate(JPORTALS):
		g = min(max((opened - i) / 1.5, 0.0), 1.0)
		tip = min(max((opened - i - 2.0) / 1.5, 0.0), 1.0) if mode == "tips" else 0.0  # the blade only once the portal is full
		if mode == "close":
			g = float(frac) * (0.6 + 0.4 * ((i * 7) % 5) / 4)  # they shrink unevenly
			if g < 0.3:
				continue
		if g <= 0:
			continue
		portal_c(rig, c, rad, n, grow=g, tip=tip if g >= 1 else 0.0, turn=0.4 * i * (1 if i % 2 else -1))
		if REWORK and g >= 1:  # each open portal lights the darkening room round it
			mk.lamp(to_world(rig, c + n * rad * 0.6), GOLD, 1.5e3 * (SIZE / 4) ** 2 * N_PORTALS / len(JPORTALS) * 1.5, 2)
	if float(frac) > 0.3 and mode != "close":
		mk.lamp(to_world(rig, (0, 3, 7)), GOLD, 0.5e4 * (SIZE / 4) ** 2 * min(float(frac), 1.0), 6)


def fx_jvolley(rig, arg):
	"""jvolley:<j>: volley j of 14 from the open portals, straight gold streaks at the lanes with sparkle dust; the volley before
	fading. Lanes: in front of him (-Y), about 15 units out and 2 below his feet."""
	k = rig.k
	for jj, dim in ((int(arg), False), (int(arg) - 1, True)):
		if jj < 0:
			continue
		rng = random.Random(700 + jj)
		floor = -HOVER_STUDS / k  # the mound top, model units below his rest feet
		for i in rng.sample(range(len(JPORTALS)), JVOLLEY):
			c, rad, n = JPORTALS[i]
			start = c + n * rad * 1.1  # from the weapon's tip: a shot only leaves a portal holding a weapon
			end = c + n * ((c.z - floor) / -n.z)  # straight out along the portal's facing to the floor (owner 2026-11-12)
			p, q = to_world(rig, start), to_world(rig, end)
			w = 0.055 * k  # 1.5 x thicker (spec "Golden King effects")
			if dim:
				mk.tube([p, q], w * 0.6, mk.glow_mat("StreakFade", GOLD, 0.9, 0.3))["wide_only"] = True
				continue
			# Close views show each shot leaving its blade (a stub); the full streak to the lanes is drawn for the hit view only,
			# so the volley never buries his pose.
			stub = p + (q - p).normalized() * 3.5 * k
			for a, b, tag in ((p, q, "wide_only"), (p, stub, "close_only")):
				mk.tube([a, b], w * 0.45, mk.glow_mat("StreakWhite", (1, 1, 1), 14))[tag] = True
				mk.tube([a, b], w, mk.glow_mat("StreakCore", GOLD_HI, 7, 0.9))[tag] = True
				mk.tube([a, b], w * 2.6, mk.glow_mat("StreakGlow", GOLD, 1.5, 0.3))[tag] = True
			for _ in range(7):  # sparkle dust along the shot
				u = rng.uniform(0.05, 0.95)
				mk.ball(p.lerp(q, u) + Vector([rng.uniform(-1, 1) for _ in range(3)]) * 0.3 * k, 0.045 * k, mk.glow_mat("Sparkle", CREAM, 10))["wide_only"] = u > 0.15
			mk.ball(p, 0.16 * k, mk.glow_mat("MuzzleFlash", (1, 1, 1), 12))
			gold_hit(rig, q, rng)


def hand_world(rig, limb):
	lo = SEG[limb][1] + "_merged"
	return rig.parts[lo].matrix_world @ rig.rest[lo].inverted() @ HAND[limb]


def fx_cmd(rig, arg):
	"""cmd:<L|R>: the command flash at that open hand, the moment the volley (or the shields) answer his gesture."""
	k = rig.k
	h = hand_world(rig, "LeftArm" if arg == "L" else "RightArm")
	mk.ball(h, 0.28 * k, mk.glow_mat("CmdCore", (1, 1, 1), 14))
	mk.ball(h, 0.6 * k, mk.glow_mat("CmdHalo", GOLD, 2.5, 0.3))
	for j in range(4):  # a four-point glint, as the portal's core star
		a = math.tau * j / 4 + 0.4
		d = Vector((math.cos(a), 0, math.sin(a)))
		mk.tube([h - d * 1.0 * k, h + d * 1.0 * k], 0.03 * k, mk.glow_mat("CmdRay", CREAM, 10))
	mk.lamp(h, GOLD, 6e3 * (SIZE / 4) ** 2, 2)


def fx_jshields(rig, arg):
	"""jshields:<f>:<state>:<yaw>: N_SHIELDS small design C portals in a ring at his chest, opened in order from his raised left
	hand (the first f of them); state portal (portals only), emerge (shields half out), ring (shields out, portals fading), lock
	(the ring set: a gold pulse runs round it)."""
	frac, state, yaw = arg.split(":")
	frac, yaw = float(frac), float(yaw)
	for i, kind in enumerate(SHIELDS):
		g = min(max((frac * (N_SHIELDS + 1) - i) / 1.2, 0.0), 1.0)
		if g <= 0:
			continue
		th = math.radians(yaw + 360 * i / N_SHIELDS)  # shield 0 at his left, where the hand is; then round the back
		out = Vector((math.cos(th), math.sin(th), 0.08)).normalized()
		c = Vector((JSHIELD_R * math.cos(th), JSHIELD_R * math.sin(th), SHIELD_Z + (0.35 if i % 2 else -0.25)))
		if state in ("portal", "emerge") or (state == "ring" and g < 1):
			portal_c(rig, c, 1.05, out, grow=g * (1 if state != "ring" else 0.7), turn=0.5 * i)
		if state == "emerge" and g >= 1:
			shield(rig, kind, c + out * 0.35, out, 0.75)
		elif state in ("ring", "lock"):
			shield(rig, kind, c + out * 0.5, out, 1.0)
	if state == "lock":
		mk.ring(to_world(rig, (0, 0, SHIELD_Z)), (JSHIELD_R + 0.5) * rig.k, 0.05 * rig.k, mk.glow_mat("ShieldPulse", GOLD_HI, 6, 0.9))
		mk.lamp(to_world(rig, (0, 0, SHIELD_Z + 1)), GOLD, 1e4 * (SIZE / 4) ** 2, 5)


JHITS = []  # world points the key's hits land on: the hit view frames them


def gold_hit(rig, q, rng):
	"""A weapon hit on the lanes: a gold flash with a white core, a flat gold shock ring, sparks thrown up, dust."""
	k = rig.k
	JHITS.append(q.copy())
	mk.ball(q, 0.35 * k, mk.glow_mat("HitCore", (1, 1, 1), 16))
	mk.ball(q, 0.9 * k, mk.glow_mat("HitFlash", GOLD, 4, 0.55))
	mk.ring(q + Vector((0, 0, 0.05 * k)), 1.5 * k, 0.07 * k, mk.glow_mat("HitRing", GOLD_HI, 6, 0.9))
	for _ in range(6):  # sparks: short streaks thrown up and out
		d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.6, 1.4))).normalized()
		mk.tube([q + d * 0.3 * k, q + d * rng.uniform(1.0, 1.8) * k], 0.025 * k, mk.glow_mat("HitSpark", GOLD_HI, 10))
	for _ in range(4):  # dust: low brown puffs
		mk.ball(q + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.2)) * 0.8 * k, rng.uniform(0.35, 0.6) * k, mk.glow_mat("HitDust", (0.45, 0.32, 0.2), 0.15, 0.55))
	mk.lamp(q + Vector((0, 0, 1.5 * k)), GOLD, 2e3 * (SIZE / 4) ** 2, 2)


def beam_line(rig):
	"""Enuma Elish's beam line: Ea's tip, its blade axis, and where that axis meets the deck (owner 2026-11-13 later: exactly along
	the blade, no clamp, no tilt; where it lands follows the pose), or 320 studs out if it points up."""
	ea = rig.parts["Ea"].matrix_world
	tip = ea @ Vector((0, 0, rig.tip))
	d = (ea.to_3x3() @ Vector((0, 0, 1))).normalized()
	L = (tip.z - rig.stand) / -d.z if d.z < 0 else 320.0
	return tip, d, tip + d * L


BEAM_VIEW = None  # world direction toward the camera for the rim lines; None: side-on to the beam, raised (the sheet's beam view)
# Beam layers, radii in studs (owner 2026-11-13: every layer 1.5 x; proposed): hot core 21, red 60, outer 90, cyclone 99 across
BEAM_CORE, BEAM_HOT, BEAM_RED, BEAM_OUTER, BEAM_CYCLONE = 10.5, 18.0, 30.0, 45.0, 49.5


def jbeam(rig, t):
	"""Enuma Elish's beam (owner 2026-11-12 "Beams follow their source", 2026-11-13 energy look with hard black and red): straight
	along Ea's blade axis from the tip; a yellow-white hot core that fills it, orange fire billows streaming inside, a translucent
	red layer with two thin bright red rim lines, a black-red outer layer, black strands and red lightning, a red-black cyclone
	turning round it; where it lands, a red-white burst, a red-black shock wave over the floor, fire, black smoke and rubble."""
	k = rig.k
	tip, d, end = beam_line(rig)
	L = (end - tip).length
	JHITS.append(end.copy())
	side = d.orthogonal().normalized()
	up = d.cross(side)
	rng = random.Random(int(t * 100))

	def around(u, ang, rad):
		return tip + d * (u * L) + (side * math.cos(ang) + up * math.sin(ang)) * rad

	mk.tube([tip, end], BEAM_CORE, mk.glow_mat("BeamHotCore", (1, 0.95, 0.62), 5.0))
	mk.tube([tip, end], BEAM_HOT, mk.glow_mat("BeamHot", (1, 0.7, 0.2), 3.0, 0.6))
	for j in range(int(L / 3) + 6):  # orange fire billows streaming out from the tip inside the beam
		u = rng.uniform(0.02, 1.0)
		ang, rad = rng.uniform(0, math.tau), rng.uniform(6, 20)
		mk.ball(around(u, ang, rad), rng.uniform(4, 8), mk.glow_mat("BeamBillow" if j % 3 else "BeamBillowY", (1, 0.42, 0.05) if j % 3 else (1, 0.78, 0.3), 3.0, 0.7))
	mk.tube([tip, end], BEAM_RED, mk.glow_mat("BeamRed", (0.95, 0.06, 0.02), 3.0, 0.5))
	mk.tube([tip, end], BEAM_OUTER, mk.glow_mat("BeamOuter", (0.3, 0.0, 0.0), 1.2, 0.45))
	view = BEAM_VIEW or (Vector((-d.y, d.x, 0)).normalized() + Vector((0, 0, 0.3)))
	edge = d.cross(Vector(view)).normalized()
	for sgn in (1, -1):  # two thin bright red rim lines along its edges, as the camera sees them
		for rad, w in ((BEAM_RED, 0.9), (BEAM_OUTER - 1.5, 1.3)):
			mk.tube([tip + edge * sgn * rad, end + edge * sgn * rad], w, mk.glow_mat("BeamRim", (1, 0.1, 0.06), 9))
	for h in range(4):  # the cyclone: four strands turning round the blast, crimson and black
		ph = h * math.tau / 4 + t * 9
		pts = [around(u, ph + u * 9, BEAM_CYCLONE + 6 * u) for u in np.linspace(0, 1, 160)]
		mk.tube(pts, 2.2, mk.glow_mat("CycloneDark" if h % 2 else "CycloneCrimson", (0.02, 0, 0) if h % 2 else (0.75, 0.02, 0.02), 1.2, 0.95))
	for j in range(6):  # black energy strands: jagged lines wrapping the outer layer
		ang, u = rng.uniform(0, math.tau), rng.uniform(0, 0.1)
		pts = []
		while u < 1:
			pts.append(around(u, ang, rng.uniform(36, 46)))
			u += rng.uniform(0.02, 0.06)
			ang += rng.uniform(-0.7, 0.7)
		mk.tube(pts, 1.5, mk.glow_mat("CrackleBlack", (0.01, 0.0, 0.0), 1.0, 0.97))
	for j in range(6):  # red lightning wrapping it
		ang, u0 = rng.uniform(0, math.tau), rng.uniform(0, 0.8)
		pts = [around(u0 + 0.015 * q, ang + rng.uniform(-0.6, 0.6), rng.uniform(26, 46)) for q in range(14)]
		mk.tube(pts, 1.2, mk.glow_mat("RedBolt", (1, 0.12, 0.08), 6))
	mk.ball(tip, 1.2 * k, mk.glow_mat("TipGlow", (1, 0.85, 0.55), 3.0, 0.85))
	ground = Vector((end.x, end.y, rig.stand + 0.5))
	away = Vector((d.x, d.y, 0)).normalized()  # the burst leans away from him, the way the blast travels
	mk.ball(end, 14, mk.glow_mat("BurstCore", (1, 0.8, 0.65), 6))  # red-white: a white-hot heart in a red fireball
	mk.ball(end + away * 8, 24, mk.glow_mat("BurstFire", (0.95, 0.08, 0.02), 2.0, 0.45))
	for rr, w, mat in ((70, 5.0, mk.glow_mat("ShockCrimson", (0.9, 0.03, 0.0), 3, 0.95)), (88, 8.0, mk.glow_mat("ShockDark", (0.02, 0.0, 0.0), 1.0, 0.92)), (52, 3.0, mk.glow_mat("ShockHot", (1, 0.85, 0.7), 5, 0.9))):
		mk.ring(ground + away * rr * 0.35, rr, w, mat)  # the shock wave over the floor
	for j in range(12):  # low red and orange fire tongues at the lane end, beyond the hit
		a = math.tau * j / 12 + rng.uniform(-0.15, 0.15)
		base = ground + away * 30 + Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(8, 30)
		top = base + Vector((rng.uniform(-5, 5), rng.uniform(-5, 5), rng.uniform(14, 34)))
		mk.tube([base, base.lerp(top, 0.5) + Vector((rng.uniform(-4, 4), rng.uniform(-4, 4), 0)), top], rng.uniform(2.5, 4.5), mk.glow_mat("FireCrimson" if j % 3 else "FireOrange", (0.95, 0.06, 0.0) if j % 3 else (1, 0.45, 0.05), 2.0, 0.85))
	for j in range(6):  # a little black smoke low beyond the hit, never over the beam
		a = math.tau * j / 6 + rng.uniform(-0.3, 0.3)
		v = away * 60 + Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(10, 28) + Vector((0, 0, rng.uniform(4, 22)))
		mk.ball(ground + v, rng.uniform(5, 9), mk.glow_mat("Smoke", (0.015, 0.003, 0.003), 1.0, 0.85))
	rubble = mk.matte_mat("Rubble", (0.16, 0.1, 0.08))
	for j in range(26):  # rubble chunks thrown up and out of the deck
		a = rng.uniform(0, math.tau)
		r, hgt = rng.uniform(15, 60), rng.uniform(3, 45)
		mk.ball(ground + away * 10 + Vector((math.cos(a) * r, math.sin(a) * r, hgt)), rng.uniform(1.5, 4.5), rubble)
	mk.lamp(tip + d * 30, (1, 0.5, 0.2), 2e6, 20)
	mk.lamp(end + Vector((0, 0, 60)), (1, 0.3, 0.1), 3e6, 30)


SUNSET = ((0.0, "#FF9C5A"), (0.22, "#F27C76"), (0.45, "#BE5E98"), (0.7, "#8A4C9C"), (1.0, "#34306E"))  # the arena sky (build_king_arena)
REDSKY = ((0.0, "#E0301C"), (0.35, "#8A1410"), (1.0, "#1A0303"))  # Enuma Elish's red tint


def sunset_world():
	"""The close views' backdrop: the arena's sunset gradient up the frame (window space, so the ortho views get it too), mixed
	toward Enuma Elish's red; Background strength is the room's brightness."""
	w = bpy.data.worlds.get("JSunset")
	if w:
		return w
	w = bpy.data.worlds.new("JSunset")
	w.use_nodes = True
	nt = w.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	tc, sep = nt.nodes.new("ShaderNodeTexCoord"), nt.nodes.new("ShaderNodeSeparateXYZ")
	nt.links.new(tc.outputs["Window"], sep.inputs[0])
	mix = nt.nodes.new("ShaderNodeMix")
	mix.name, mix.data_type = "RedMix", "RGBA"
	for slot, stops in ((6, SUNSET), (7, REDSKY)):
		r = nt.nodes.new("ShaderNodeValToRGB")
		els = r.color_ramp.elements
		els[0].position, els[0].color = stops[0][0], mk.be_rgb(stops[0][1])
		els[1].position, els[1].color = stops[-1][0], mk.be_rgb(stops[-1][1])
		for pos, h in stops[1:-1]:
			els.new(pos).color = mk.be_rgb(h)
		nt.links.new(sep.outputs["Y"], r.inputs["Fac"])
		nt.links.new(r.outputs["Color"], mix.inputs[slot])
	nt.links.new(mix.outputs[2], bg.inputs["Color"])
	return w


def jlook(scene, rig, sky):
	"""sky (dim, red): the sunset room at brightness dim (1 full, 0.2 the dimmed room under the portals) tinted red by red; or
	"white": the full white flash (the camera sees white, he is lit dimly: a dark shape against it)."""
	look(scene, rig, "flat")
	floor = next(n for n in rig.floor.active_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	if sky == "white":
		w = bpy.data.worlds.get("JFlash") or bpy.data.worlds.new("JFlash")
		w.use_nodes = True
		nt = w.node_tree
		if not any(n.type == "LIGHT_PATH" for n in nt.nodes):
			bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
			bg.inputs["Color"].default_value, bg.inputs["Strength"].default_value = (1, 0.97, 0.95, 1), 1.0
			low = nt.nodes.new("ShaderNodeBackground")
			low.inputs["Color"].default_value, low.inputs["Strength"].default_value = (1, 0.8, 0.8, 1), 0.06
			mix, lp = nt.nodes.new("ShaderNodeMixShader"), nt.nodes.new("ShaderNodeLightPath")
			nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
			nt.links.new(low.outputs[0], mix.inputs[1])
			nt.links.new(bg.outputs[0], mix.inputs[2])
			nt.links.new(mix.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_WORLD").inputs["Surface"])
		scene.world = w
		rig.floor.hide_render = True
		rig.sun.data.energy, rig.sun.data.color = 0.08, (1, 0.9, 0.9)
		rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 1.0, 0.25
		return
	dim, red = sky[:2]
	w = sunset_world()
	scene.world = w
	w.node_tree.nodes["RedMix"].inputs[0].default_value = red
	next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = 0.04 + 0.96 * dim
	sand, scorch = Vector((0.55, 0.38, 0.22)), Vector((0.32, 0.06, 0.04))
	floor.inputs["Base Color"].default_value = (*(sand.lerp(scorch, red) * (0.25 + 0.75 * dim)), 1)
	rig.sun.data.energy = 0.5 + 2.0 * dim
	rig.sun.data.color = Vector((1.0, 0.8, 0.62)).lerp(Vector((1.0, 0.45, 0.4)), red)
	rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 0.9, sky[2] if len(sky) > 2 else 0.6  # beam keys: low, the crimson stays crimson


JFX = {"jportals": fx_jportals, "jvolley": fx_jvolley, "jshields": fx_jshields, "cmd": fx_cmd}


def jkey(t, cap, base=IDLE0, **k):
	"""A rework key: base (IDLE0) with fields replaced."""
	d = {"t": t, "cap": cap, **base}
	d.update(k)
	return d


def folded(dr=(0, 0, 0), dl=(0, 0, 0)):
	"""FOLD2 with each hand nudged (model units): breath lifts, a tighter or looser fold."""
	return {"RightArm": {**FOLD2["RightArm"], "aim": tuple(a + b for a, b in zip(FOLD2["RightArm"]["aim"], dr))}, "LeftArm": {**FOLD2["LeftArm"], "aim": tuple(a + b for a, b in zip(FOLD2["LeftArm"]["aim"], dl))}}


JMOVES["idle"] = {
	"title": "Idle (rework, jointed rig, hovering): arms folded, breathing, looking down on the runners",
	"end": 4.0,
	"loop": True,
	"cols": 5,
	"note": "4.0 s loop: key 10 = key 1 (idle key 0). No Dodge bar, no hit",
	"keys": [
		jkey(0.0, "Idle key 0: arms folded, chin up, weight hangs on his right leg, left knee loose"),
		jkey(0.45, "Breath in starts: chest rises, folded arms lift with it, legs drift forward", torso=(-1, 0, 5), head=(-8, 0, -10), **folded((0, 0, 0.07), (0, 0, 0.07)), LeftLeg={"hip": (-12, 0, -3), "knee": 26}, RightLeg={"hip": (0, 0, 4), "knee": 34}, key=(2, 0, 0)),
		jkey(0.9, "Breath in, top: chest out, he looks down his nose at the lanes", root=(0, 0, 0.04), torso=(-5, 0, 3), head=(-12, 0, -4), **folded((0, 0.05, 0.12), (0, 0.05, 0.12)), LeftLeg={"hip": (-10, 0, -4), "knee": 22}, RightLeg={"hip": (-2, 0, 5), "knee": 30}, key=(3, 0, 0)),
		jkey(1.35, "Glance: head turns to the runners on his left, shoulders follow a little, hips roll", root=(0.04, 0, 0.03), body=(0, -3, 4), torso=(-2, 2, 8), head=(-6, -2, 26), **folded((0, 0, 0.08), (0, 0, 0.06)), LeftLeg={"hip": (-6, 0, -6), "knee": 20}, RightLeg={"hip": (-6, 0, 2), "knee": 34}, key=(1, 0, 0)),
		jkey(1.8, "Breath out: chest drops, weight swings onto his left leg, right knee loosens", root=(0.05, 0, 0), body=(0, -4, 2), torso=(3, 2, 2), head=(-2, -2, 18), **folded((0, -0.03, -0.03), (0, -0.03, -0.03)), LeftLeg={"hip": (2, 0, -4), "knee": 32}, RightLeg={"hip": (-12, 0, 4), "knee": 22}, key=(-1, 0, 0)),
		jkey(2.2, "Smug lean: hips sway to his left, head tips, fold tightens", root=(0.06, 0, -0.02), body=(0, -5, -2), torso=(2, -2, -4), head=(-7, -5, 6), **folded((0.1, -0.05, 0.02), (-0.08, -0.05, 0.03)), LeftLeg={"hip": (4, 0, -5), "knee": 36}, RightLeg={"hip": (-14, 0, 5), "knee": 24}, key=(0, 0, 0)),
		jkey(2.65, "Second breath in: chest lifts again, legs drift back under him", root=(0.03, 0, 0.04), body=(0, -2, -3), torso=(-4, 0, -2), head=(-11, -2, -4), **folded((0, 0.03, 0.1), (0, 0.03, 0.1)), LeftLeg={"hip": (-4, 0, -4), "knee": 28}, RightLeg={"hip": (-8, 0, 4), "knee": 28}, key=(2, 0, 0)),
		jkey(3.1, "Glance the other way: over his right shoulder, chin high, hips counter-turn", root=(-0.02, 0, 0.02), body=(0, 2, -5), torso=(-3, -2, -8), head=(-9, 3, -28), **folded((0, 0.02, 0.06), (0, 0.02, 0.06)), LeftLeg={"hip": (-10, 0, -2), "knee": 22}, RightLeg={"hip": (2, 0, 6), "knee": 34}, key=(1, 0, 0)),
		jkey(3.55, "Breath out, settling: head comes back front, weight returns to his right leg", root=(-0.02, 0, 0), body=(0, 1, -2), torso=(3, 0, 2), head=(-3, 1, -14), **folded((0, -0.02, -0.02), (0, -0.02, -0.02)), LeftLeg={"hip": (-6, 0, -3), "knee": 24}, RightLeg={"hip": (4, 0, 4), "knee": 32}, key=(-1, 0, 0)),
		jkey(4.0, "Loop = idle key 0: arms folded, chin up, weight on his right leg"),
	],
}
AKIMBO_L = {"aim": (2.1, -0.4, 2.45), "pole": (1, 0.6, 0)}  # left fist on his hip, elbow out
JMOVES["gates"] = {
	"title": "Gates of Babylon (rework, jointed rig, hovering): a sweep of his right arm opens an ordered dome of portals round him, a command fires the volleys",
	"end": 4.4,
	"window": [0.0, 1.6],
	"strike_window": [1.6, 3.6],
	"cols": 5,
	"look": "dark",
	"note": "DODGE WINDOW 0.00 - 1.60 s (before the volleys); event gates (the 20% cost) at 1.60 s; VOLLEYS 1.60 - 3.60 s, one every 0.15 s (14), keys 5 to 9; recover to idle by 4.40 s. Portals: design C, the sun wheel (sketch), opening in his arm's sweep, his left side first, on an ordered dome round him",
	"keys": [
		jkey(0.0, "Idle key 0, Dodge bar opens: arms folded, still; one gold dot behind his left shoulder", fx=["jportals:0.04"]),
		jkey(0.4, "Coil: right hand unfolds and drops across to his left hip, torso twists left, eyes stay on the lanes; first portals of the dome open on his left", fx=["jportals:0.14"], root=(0, 0, -0.08), body=(0, 0, 8), torso=(10, 0, 18), head=(-4, 0, -16), RightArm={"aim": (-0.35, -1.2, 3.2), "pole": (-1, -0.2, -0.3)}, LeftArm=AKIMBO_L, LeftLeg={"hip": (-22, 0, -4), "knee": 46}, RightLeg={"hip": (-8, 0, 5), "knee": 40}, key=(6, 0, 0)),
		jkey(0.8, "Sweep: the open hand swings up across his chest toward his right, torso unwinds; the dome's portals cascade round him in its path, the first ones full and pushing a blade out", fx=["jportals:0.45:tips"], root=(0, 0, 0), body=(0, 0, 0), torso=(0, -2, -4), head=(-8, 0, -6), RightArm={"aim": (-1.2, -1.65, 4.0), "pole": (-0.6, 0, -1)}, LeftArm=AKIMBO_L, LeftLeg={"hip": (-8, 0, -4), "knee": 28}, RightLeg={"hip": (4, 0, 5), "knee": 34}, key=(2, 0, 0)),
		jkey(1.2, "Raised hand, sweep's end: arm up and out to his right, chest open, chin high; " + f"all {len(JPORTALS)} dome portals open, weapon tips push through (held still)", fx=["jportals:1:tips"], root=(0, 0, 0.1), body=(0, 2, -6), torso=(-8, -6, -12), head=(-14, 4, -2), RightArm={"aim": (-2.4, -0.4, 5.2)}, LeftArm=AKIMBO_L, LeftLeg={"hip": (2, 0, -5), "knee": 24}, RightLeg={"hip": (10, 0, 6), "knee": 38}, key=(-4, 0, 0)),
		jkey(1.6, "Command (hit): arm snaps down to point at the lanes, torso thrown forward, legs kick back; volley 1 of 14 leaves on the gesture", event="gates", fx=["jportals:1.3:tips", "jvolley:0", "cmd:R"], root=(0, -0.1, -0.05), body=(0, 0, 2), torso=(14, 0, -4), head=(-12, 0, -4), RightArm={"aim": (-1.9, -1.45, 3.3)}, LeftArm={"aim": (2.4, 0.9, 3.0), "pole": (1, -0.3, -0.5)}, LeftLeg={"hip": (14, 0, -4), "knee": 40}, RightLeg={"hip": (22, 0, 4), "knee": 55}, key=(10, 0, 0)),
		jkey(1.85, "Overshoot: the point carries past and down, head dips, legs swing further back; volley 2", fx=["jportals:1.3:tips", "jvolley:1"], root=(0, -0.12, -0.1), body=(0, 0, 4), torso=(19, 0, -2), head=(-15, 0, -6), RightArm={"aim": (-1.7, -1.45, 2.9)}, LeftArm={"aim": (2.3, 1.0, 2.7), "pole": (1, -0.3, -0.5)}, LeftLeg={"hip": (20, 0, -4), "knee": 50}, RightLeg={"hip": (26, 0, 4), "knee": 62}, key=(12, 0, 0)),
		jkey(2.5, "Second gesture: weight swings to his left, left arm flung wide with an open palm, right fist drawn to his chest; volley 6", fx=["jportals:1.3:tips", "jvolley:5", "cmd:L"], root=(0.08, -0.04, 0), body=(0, -3, 8), torso=(4, 3, 16), head=(-8, -2, 10), RightArm={"aim": (-0.6, -1.0, 3.4), "pole": (-1, 0, -0.5)}, LeftArm={"aim": (3.0, -0.6, 4.2)}, LeftLeg={"hip": (-10, 0, -6), "knee": 30}, RightLeg={"hip": (10, 0, 6), "knee": 48}, key=(4, 0, 0)),
		jkey(3.1, "Commanding hold: turns back, right palm out over the lanes, left fist to his hip, chin up; volley 10", fx=["jportals:1.3:tips", "jvolley:9"], root=(-0.04, 0, 0.05), body=(0, 2, -4), torso=(2, -3, -10), head=(-12, 3, -12), RightArm={"aim": (-2.7, -1.1, 4.1)}, LeftArm=AKIMBO_L, LeftLeg={"hip": (6, 0, -4), "knee": 40}, RightLeg={"hip": (-6, 0, 5), "knee": 26}, key=(0, 0, 0)),
		jkey(3.6, "Volley 14, the last, from portals still holding weapons: the hand sinks; the portals close after it", fx=["jportals:1.3:tips", "jvolley:13"], root=(-0.02, 0, 0.02), body=(0, 1, -2), torso=(4, -1, -4), head=(-6, 1, -10), RightArm={"aim": (-2.1, -1.0, 2.6), "pole": (-1, 0.3, -0.3)}, LeftArm={"aim": (1.9, -0.6, 2.5), "pole": (1, 0.6, 0)}, LeftLeg={"hip": (-4, 0, -3), "knee": 28}, RightLeg={"hip": (2, 0, 4), "knee": 30}, key=(2, 0, 0)),
		jkey(4.4, "Recover = idle key 0: arms fold again, portals gone", fx=["jportals:0:close"]),
	],
}
for _k in JMOVES["gates"]["keys"]:
	_k["view"] = (0.4, -0.9, 0.75)  # raised (2026-11-13 dome): the tiers read as rings round him, the front tier below his chest
JMOVES["gates"]["front"] = (0, -1, 0.5)
# The owner's later look (2026-11-12, design doc 4.37 "Golden King effects stronger"; the sheets are the target the game matches):
# the sunset room darkens as the portals open (dim, red per key); each portal is full before its blade shows, shots only from
# portals holding one; thick gold streaks with white cores and sparkle dust; each hit a gold flash, shock ring, sparks and dust.
JMOVES["gates"]["sky"] = [(1.0, 0), (0.8, 0), (0.45, 0), (0.2, 0), (0.12, 0), (0.12, 0), (0.12, 0), (0.12, 0), (0.18, 0), (0.7, 0)]
JMOVES["gates"]["hitcam"] = (1, -0.2, 0.6)
JMOVES["gates"]["note"] = "DODGE 0.00 - 1.60 s; event gates (20% cost) at 1.60 s; VOLLEYS 1.60 - 3.60 s, 14, one per 0.15 s (keys 5 - 9); idle by 4.40 s. The sunset room darkens as design C portals open in his sweep on an ordered dome round him (owner 2026-11-13 later: tiers at " + ", ".join(f"{e} deg x {n} ({a} studs)" for e, n, a in DOME_TIERS) + f" from his chest, dome radius {DOME_R * SIZE * CHAR_H / 6.63:.0f} studs, open sky above {DOME_TOP} deg; each faces out and down to the lanes {LANE_MID:g} studs out; {JVOLLEY} weapons a volley); a blade only in a full portal, shots only from blades along its facing (close views: the shot leaving; third view: the hits all round the lanes)"
JMOVES["enuma"]["sky"] = [(1.0, 0), (0.9, 0.15), (0.75, 0.35), (0.6, 0.6), (0.45, 0.85), (0.35, 1.0), "white", (0.06, 1.0, 0.08), (0.06, 1.0, 0.08), (0.6, 0.4)]  # the beam floods the room dark red; low bloom keeps it crimson
JMOVES["enuma"]["hitcam"] = (0.2, -0.5, 1.0)
JMOVES["enuma"]["note"] = "DODGE (charge) 0.00 - 3.00 s; HIT 3.00 s: one white full flash, then the beam 3.00 - 5.00 s; recover 5.00 - 5.60 s. The sunset room tints red through the charge; the beam runs exactly along Ea's blade axis from its tip (no clamp, no tilt), 90 studs wide: a yellow-white hot core 21, orange fire billows, red 60 with thin bright red rim lines, a red-black cyclone 99 and black strands kept strong; red-white burst, black smoke and rubble where it lands. 360 sweep (owner 2026-11-13): his whole rig turns about his centre on top of the keys so the beam's yaw goes 370 degrees one way, eased, 3.00 - 5.00 s (sweep in each beam key's caption; the row below shows 0, 90, 180, 270, 360 from above); Ea pitched down so the beam lands on the lanes all round. Beam keys seen side-on with the landing in frame"
SWEEP_DEG, SWEEP_T = 370.0, (3.0, 5.0)  # proposed (spec "Enuma 360"): the beam's yaw goes this far one way over the beam window


def ease(u):
	u = min(max(u, 0.0), 1.0)
	return u * u * (3 - 2 * u)


def beam_yaw(key):
	"""The beam's yaw in his model space without the sweep, degrees: his hips' yaw plus Ea's dir (dir is turned with the hips)."""
	x, y, _ = key["ea"]["dir"]
	return key.get("body", (0, 0, 0))[2] + math.degrees(math.atan2(y, x))


def sweep_for(key, t, first):
	"""The rig turn that puts the beam SWEEP_DEG * ease(u) round from the first beam key at time t."""
	return round(beam_yaw(first) + SWEEP_DEG * ease((t - SWEEP_T[0]) / (SWEEP_T[1] - SWEEP_T[0])) - beam_yaw(key), 1)


_beam = [k for k in JMOVES["enuma"]["keys"] if "beam" in k.get("fx", [])]
for _k in _beam:
	_k["sweep"] = sweep_for(_k, _k["t"], _beam[0])
	_k["cap"] += f" (sweep +{_k['sweep']:g} deg: beam {beam_yaw(_k) + _k['sweep'] - beam_yaw(_beam[0]):.0f} deg round)"
JMOVES["shields"] = {
	"title": "Shield Gates (rework, jointed rig, hovering): his left hand calls a ring of shields out of small portals, a fold locks it",
	"end": 2.6,
	"cols": 5,
	"look": "dark",
	"front": (0, -1, 0.3),
	"note": "No Dodge bar, no cost. Event shields at 2.20 s: Fortified set (40% less damage until his next move). The 6 shield portals (design C, small) open one after another from his raised left hand round the back; the ring locks with a gold pulse as his arms fold. The big view looks through the gap between two shields",
	"keys": [
		jkey(0.0, "Idle key 0: arms folded, still", fx=["jshields:0:portal:0"]),
		jkey(0.3, "Anticipation: left hand unfolds and sinks across his belly, shoulders hunch, torso turns right, knees tuck", fx=["jshields:0:portal:0"], root=(0, 0, -0.08), torso=(12, 0, -14), head=(4, 0, 10), RightArm=FOLD2["RightArm"], LeftArm={"aim": (0.6, -1.1, 2.8), "pole": (1, -0.2, -0.3)}, LeftLeg={"hip": (-20, 0, -4), "knee": 44}, RightLeg={"hip": (-14, 0, 4), "knee": 48}, key=(6, 0, 0)),
		jkey(0.6, "Call: the open left hand sweeps up and out to his left; the first shield portal opens beside it", fx=["jshields:0.3:portal:0"], root=(0, 0, 0), torso=(-2, 0, 8), head=(-6, 0, 14), RightArm=FOLD2["RightArm"], LeftArm={"aim": (2.6, -1.2, 4.2)}, LeftLeg={"hip": (-6, 0, -5), "knee": 30}, RightLeg={"hip": (2, 0, 5), "knee": 36}, key=(0, 0, 0)),
		jkey(0.9, "Hand high: left arm overhead, he leans back; portals open round the back in the hand's path", fx=["jshields:0.7:portal:0"], root=(0, 0, 0.06), torso=(-8, 4, 4), head=(-16, 0, 6), RightArm={"aim": (-1.6, -1.1, 2.7), "pole": (-1, 0.3, -0.5)}, LeftArm={"aim": (2.0, -0.4, 5.4)}, LeftLeg={"hip": (6, 0, -4), "knee": 30}, RightLeg={"hip": (12, 0, 5), "knee": 42}, key=(-4, 0, 0)),
		jkey(1.2, "Overshoot: hand flung up and back, chest arched, head back, right arm drops; all 6 portals open, shields push half out", fx=["jshields:1:emerge:0", "cmd:L"], root=(0, 0, 0.12), torso=(-14, 4, 2), head=(-22, 0, 4), RightArm={"aim": (-2.3, -0.5, 2.4)}, LeftArm={"aim": (1.8, 0.4, 5.5)}, LeftLeg={"hip": (12, 0, -5), "knee": 34}, RightLeg={"hip": (18, 0, 6), "knee": 50}, key=(-8, 0, 0)),
		jkey(1.5, "Spread: both arms flung up and wide in a V, palms out, the right lower; the shields come out to a full ring, portals fade", fx=["jshields:1:ring:0"], root=(0, 0, 0.1), torso=(-4, -3, -6), head=(-10, 2, -8), RightArm={"aim": (-2.9, -0.5, 4.6)}, LeftArm={"aim": (2.7, -0.3, 5.0)}, LeftLeg={"hip": (10, 0, -8), "knee": 36}, RightLeg={"hip": (-4, 0, 8), "knee": 28}, key=(-2, 0, 0)),
		jkey(1.8, "Gather: arms swing in toward his chest to fold, torso settles, the ring holds", fx=["jshields:1:ring:0"], root=(0, 0, 0.05), torso=(4, 0, -2), head=(-4, 0, -4), RightArm={"aim": (-0.8, -1.2, 3.6), "pole": (-1, 0.3, -0.8)}, LeftArm={"aim": (1.0, -1.3, 3.0), "pole": (1, 0.3, -0.8)}, LeftLeg={"hip": (-2, 0, -5), "knee": 30}, RightLeg={"hip": (-6, 0, 6), "knee": 34}, key=(2, 0, 0)),
		jkey(2.2, "Lock (Fortified): arms snap folded, chin up, a smirk; a gold pulse runs round the ring", event="shields", fx=["jshields:1:lock:0"], root=(0, 0, 0.04), torso=(-3, 0, 4), head=(-12, 0, -6), **folded((0.04, 0, 0.06), (-0.04, 0, 0.06)), LeftLeg={"hip": (-10, 0, -4), "knee": 24}, RightLeg={"hip": (2, 0, 5), "knee": 30}, key=(-2, 0, 0)),
		jkey(2.4, "Settle: the snap rocks him forward, head nods, legs swing through; the ring starts to orbit", fx=["jshields:1:ring:18"], root=(0, 0, 0), torso=(5, 0, 4), head=(-2, 0, -8), **folded((0, -0.03, -0.02), (0, -0.03, -0.02)), LeftLeg={"hip": (-12, 0, -3), "knee": 30}, RightLeg={"hip": (6, 0, 4), "knee": 36}, key=(3, 0, 0)),
		jkey(2.6, "End = idle key 0, Fortified: arms folded, the shield ring orbiting", fx=["jshields:1:ring:36"]),
	],
}
for _k in JMOVES["shields"]["keys"]:  # the main view looks through the gap between two shields (the ring yaw - 30 degrees), raised
	_a = math.radians(float(next(f for f in _k["fx"] if f.startswith("jshields")).split(":")[3]) - 30)
	_k["view"] = (round(math.cos(_a), 3), round(math.sin(_a), 3), 0.4)
JMOVES["fortified_idle"] = {
	"title": "Fortified idle (rework, jointed rig, hovering): a guarded, confident hover inside the orbiting shield ring",
	"end": 4.0,
	"loop": True,
	"cols": 5,
	"look": "dark",
	"front": (0, -1, 0.3),
	"note": "4.0 s loop while Fortified holds: key 10 = key 1 (idle key 0); the ring orbits once per loop, 90 degrees a second (proposed; in game the ring follows BossFortified). No Dodge bar, no hit. The big view looks through the shield gap nearest his front-left, so it moves a little key to key",
	"keys": [
		jkey(0.0, "Idle key 0 inside the ring: arms folded, chin up"),
		jkey(0.45, "Breath in: he leans back on the air, chin higher, legs drift forward", torso=(-6, 0, 4), head=(-14, 0, -6), **folded((0, 0.04, 0.1), (0, 0.04, 0.1)), LeftLeg={"hip": (-16, 0, -3), "knee": 30}, RightLeg={"hip": (-6, 0, 4), "knee": 36}, key=(3, 0, 0)),
		jkey(0.9, "His eyes follow a shield past his left shoulder, hips roll after them", root=(0.03, 0, 0.02), body=(0, -2, 3), torso=(-4, 2, 8), head=(-10, -2, 24), **folded((0, 0, 0.06), (0, 0, 0.06)), LeftLeg={"hip": (-10, 0, -5), "knee": 24}, RightLeg={"hip": (-8, 0, 3), "knee": 34}, key=(1, 0, 0)),
		jkey(1.35, "Beckon: the right hand unfolds and offers the lanes an open palm (come, then); left arm stays across his chest", root=(0.02, 0, 0), body=(0, 0, -2), torso=(-2, 0, -8), head=(-10, 0, -10), RightArm={"aim": (-1.6, -1.5, 3.6), "pole": (-0.8, 0, -1)}, LeftArm=FOLD2["LeftArm"], LeftLeg={"hip": (-6, 0, -4), "knee": 26}, RightLeg={"hip": (4, 0, 5), "knee": 40}, key=(0, 0, 0)),
		jkey(1.8, "Beckon flick: forearm curls up toward him, head tilts, a smirk", root=(0, 0, 0.02), body=(0, 1, -3), torso=(-3, -2, -10), head=(-12, 3, -6), RightArm={"aim": (-1.4, -1.2, 4.2), "pole": (-0.8, 0.2, -1)}, LeftArm=FOLD2["LeftArm"], LeftLeg={"hip": (-4, 0, -4), "knee": 30}, RightLeg={"hip": (8, 0, 5), "knee": 44}, key=(-1, 0, 0)),
		jkey(2.2, "Refold: the arm folds back over the left, weight drifts onto his left leg", root=(0.04, 0, -0.01), body=(0, -4, 0), torso=(2, -2, -2), head=(-8, -4, 6), **folded((0.04, 0, 0.02), (0, 0, 0)), LeftLeg={"hip": (2, 0, -4), "knee": 34}, RightLeg={"hip": (-12, 0, 4), "knee": 24}, key=(-1, 0, 0)),
		jkey(2.65, "Breath in again, chest out, looking down his nose", root=(0.02, 0, 0.03), body=(0, -2, 0), torso=(-5, 0, -2), head=(-13, 0, -2), **folded((0, 0.03, 0.1), (0, 0.03, 0.1)), LeftLeg={"hip": (-6, 0, -4), "knee": 28}, RightLeg={"hip": (-8, 0, 4), "knee": 28}, key=(2, 0, 0)),
		jkey(3.1, "Glance down at the runners on his right, hips counter-turn", root=(-0.02, 0, 0.01), body=(0, 2, -3), torso=(2, -2, -6), head=(0, 2, -22), **folded((0, 0, 0.04), (0, 0, 0.04)), LeftLeg={"hip": (-12, 0, -2), "knee": 22}, RightLeg={"hip": (2, 0, 6), "knee": 34}, key=(1, 0, 0)),
		jkey(3.55, "Settle: head back to the front, weight back on his right leg", root=(-0.01, 0, 0), body=(0, 1, -1), torso=(2, 0, 3), head=(-6, 0, -10), **folded((0, -0.02, -0.02), (0, -0.02, -0.02)), LeftLeg={"hip": (-6, 0, -3), "knee": 24}, RightLeg={"hip": (4, 0, 4), "knee": 32}, key=(-1, 0, 0)),
		jkey(4.0, "Loop = idle key 0: arms folded, the ring one full turn round"),
	],
}
for _k in JMOVES["fortified_idle"]["keys"]:  # the ring at 90 degrees a second; the main view through the gap nearest 330 degrees
	_y = 90.0 * _k["t"]
	_k["fx"] = [f"jshields:1:ring:{_y:g}"]
	_g = _y + 30 + 60 * round((330 - (_y + 30)) / 60)
	_k["view"] = (round(math.cos(math.radians(_g)), 3), round(math.sin(math.radians(_g)), 3), 0.35)


def two_bone(J, L1, L2, T, pole):
	"""Upper and lower segment rotations (model space) for a limb hanging down -Z at rest, its elbow pointing +Y at rest: the
	end reaches T (clamped to reach), the elbow bends toward pole."""
	d = T - J
	dh = d.normalized()
	dist = min(max(d.length, abs(L1 - L2) + 1e-3), L1 + L2 - 1e-4)
	a = math.acos(max(-1.0, min(1.0, (L1 * L1 + dist * dist - L2 * L2) / (2 * L1 * dist))))
	p = pole - dh * pole.dot(dh)
	p = p.normalized() if p.length > 1e-6 else dh.orthogonal().normalized()
	u = dh * math.cos(a) + p * math.sin(a)
	w = (dh * dist - u * L1).normalized()
	y = (p - u * p.dot(u)).normalized()  # the rest +Y (elbow side) goes to the pole side
	z = -u
	r1 = Matrix((y.cross(z), y, z)).transposed()
	return r1, u.rotation_difference(w).to_matrix() @ r1


def jsolve(key):
	"""jointed rig: placement per part (model space, applied on top of its rest), the local rotations for keys.json, the Ea
	grip offset in the right forearm's space, and how far each hand stops short of its aim (model units)."""
	place = {}
	sweep = Matrix.Rotation(math.radians(key.get("sweep", 0)), 4, "Z")  # Enuma's 360: the whole rig turned about his centre on top
	yaw = sweep.to_3x3() @ Matrix.Rotation(math.radians(key.get("body", (0, 0, 0))[2]), 3, "Z")
	place["Body"] = sweep @ Matrix.Translation(key.get("root", (0, 0, 0))) @ about(HIP, eul(key.get("body", (0, 0, 0))))
	place["Torso"] = place["Body"] @ about(WAIST, eul(key.get("torso", (0, 0, 0))))
	place["Head"] = place["Torso"] @ about(NECK, eul(key.get("head", (0, 0, 0))))
	place["Key"] = place["Torso"] @ about(KEY_PIVOT, eul(key.get("key", (0, 0, 0))))
	short = {}

	def put(name, parent, pivot, r3):
		at = place[parent] @ Vector(pivot)
		place[name] = Matrix.Translation(at) @ r3.to_4x4() @ Matrix.Translation(-Vector(pivot))

	def arm(limb, target=None):
		up, lo = SEG[limb]
		spec = key.get(limb, {})
		tw = place["Torso"]
		if target is None and isinstance(spec, dict) and "aim" in spec:
			target = tw @ Vector(spec["aim"])
		if target is not None:
			pole = tw.to_3x3() @ Vector(spec.get("pole", POLE[limb]) if isinstance(spec, dict) else POLE[limb])
			J = tw @ Vector(SHOULDER[limb])
			r1, r2 = two_bone(J, SHOULDER[limb][2] - ELBOW[limb].z, ELBOW[limb].z - HAND[limb].z, target, pole)
		else:
			r1 = tw.to_3x3() @ eul(spec.get("shoulder", (0, 0, 0))).to_3x3()
			e = spec.get("elbow", 0)
			r2 = r1 @ eul((-e, 0, 0) if isinstance(e, (int, float)) else e).to_3x3()
		put(up, "Torso", SHOULDER[limb], r1)
		put(lo, up, ELBOW[limb], r2)
		if target is not None:
			short[limb] = round((place[lo] @ HAND[limb] - target).length, 3)

	def leg(limb):
		up, lo = SEG[limb]
		spec = key.get(limb, (0, 0, 0))
		spec = spec if isinstance(spec, dict) else {"hip": spec}
		r1 = place["Body"].to_3x3() @ eul(spec.get("hip", (0, 0, 0))).to_3x3()
		put(up, "Body", LEG[limb], r1)
		put(lo, up, KNEE[limb], r1 @ eul((spec.get("knee", 0), 0, 0)).to_3x3())

	arm("RightArm")
	grip = None
	if "ea" in key:
		e = key["ea"]
		if isinstance(e, dict):
			r = Vector((0, 0, 1)).rotation_difference(yaw @ Vector(e["dir"])).to_matrix().to_4x4()
			at = sweep @ Vector(e["at"]) if "at" in e else place["RightLowerArm"] @ HAND["RightArm"]
			place["Ea"] = Matrix.Translation(at) @ r @ Matrix.Translation(-EA_PIVOT)
		else:
			place["Ea"] = place["RightLowerArm"] @ Matrix.Translation(HAND["RightArm"] - EA_PIVOT) @ about(EA_PIVOT, eul(e))
		local = place["RightLowerArm"].inverted() @ place["Ea"]
		grip = [round(v, 4) for v in (local @ EA_PIVOT) - EA_PIVOT]
	arm("LeftArm", place["Ea"] @ (EA_PIVOT + Vector((0, 0, GRIP_UP))) if key.get("LeftArm") == "grip" else None)
	for limb in ("LeftLeg", "RightLeg"):
		leg(limb)
	record = {}
	for n, par in JPARENT.items():
		if n in place:
			# Body is recorded without the sweep: keys.json holds the pose; sweep_deg is the turn the game adds on top about his centre
			r = (sweep.inverted() @ place[n]).to_3x3() if par is None else place[par].to_3x3().inverted() @ place[n].to_3x3()
			record[n] = degs(r.to_4x4())
	for n, sign in zip(EA_PARTS[1:], (1, -1, 1)):
		record[n] = [0.0, 0.0, round(sign * key.get("spin", 0), 3)]
	m = {(n if n in ("Key", "Ea") else n + "_merged"): v for n, v in place.items() if n != "Body"}
	return m, record, grip, short


# ---- the volley window: panels from the runner's camera and from above ----

WIN, MAP = (1000, 562), 418


def window_fx(rig, t):
	j = min(13, int(round(t / 0.15)))
	build_fx(rig, ["portals_fade" if t >= 2.0 else "portals_open", f"streaks:{j}"], seed=900 + j)
	return [f"volley {j + 1} of 14 fires: {VOLLEY} weapons", f"{N_PORTALS} portals " + ("start to close" if t >= 2.0 else "stay open"), f"volley {j} fading" if j else "none fading yet"]


def window_row(scene, rig, move):
	look(scene, rig, "gold")
	cam = rig.cam
	out = []
	for t, key in zip(PANELS, move["keys"]):
		clear_fx()
		pose_king(rig, key)
		lines = window_fx(rig, t)
		player_view(cam)
		wide = mk.shot(scene, os.path.join(TMP, f"gates_window_{t:.1f}_wide.png"), WIN)
		cam.data.type, cam.data.ortho_scale = "ORTHO", 2 * R_WALL + 10
		cam.location, cam.rotation_euler = (0, 0, 400), (0, 0, FACE)  # top view, the runner's side of the room at the bottom
		cam.data.clip_start, cam.data.clip_end = 400 - 90, 500  # only below 90 studs: no dome
		top = mk.shot(scene, os.path.join(TMP, f"gates_window_{t:.1f}_top.png"), (MAP, MAP))
		out.append((t, lines, wide, top))
	clear_fx()
	return out


# ---- Enuma's 360 sweep: in-between poses, the row from above and the hero frames ----


def lerp_val(a, b, u):
	if isinstance(a, (int, float)) and isinstance(b, (int, float)):
		return a + (b - a) * u
	if isinstance(a, (tuple, list)) and isinstance(b, (tuple, list)):
		return tuple(lerp_val(x, y, u) for x, y in zip(a, b))
	if isinstance(a, dict) and isinstance(b, dict):
		return {f: lerp_val(v, b[f], u) if f in b else v for f, v in a.items()}
	return a


def key_at(keys, t):
	"""A straight in-between of the two keys round t (a review aid only: the game blends its own in-betweens)."""
	a, b = next((a, b) for a, b in zip(keys, keys[1:]) if a["t"] <= t <= b["t"])
	u = (t - a["t"]) / (b["t"] - a["t"])
	return {**{f: lerp_val(v, b.get(f, v), u) for f, v in a.items()}, "t": t}


def sweep_time(deg):
	"""When the beam has gone deg round (inverse of the eased sweep)."""
	lo, hi = 0.0, 1.0
	for _ in range(40):
		mid = (lo + hi) / 2
		lo, hi = (mid, hi) if SWEEP_DEG * ease(mid) < deg else (lo, mid)
	return SWEEP_T[0] + lo * (SWEEP_T[1] - SWEEP_T[0])


def sweep_key(deg):
	keys = JMOVES["enuma"]["keys"]
	beam = [k for k in keys if "beam" in k.get("fx", [])]
	t = min(max(sweep_time(deg), beam[0]["t"]), beam[-1]["t"])
	key = key_at(keys, t)
	key["sweep"] = sweep_for(key, t, beam[0])
	key["fx"] = ["beam"]
	return key


def lane_marks(rig):
	"""The lanes' inner and outer edges on the deck (110 and 166 studs from his centre, proposed ring): review marks only."""
	c = rig.king.matrix_world.translation
	for r in (110.0, 166.0):
		mk.ring(Vector((c.x, c.y, rig.stand + 0.3)), r, 0.9, mk.glow_mat("LaneMark", CREAM, 3))


def sweep_row(scene, rig, move):
	"""Five panels from high above: the beam at 0, 90, 180, 270 and 360 degrees of its sweep, landing on the lanes all round."""
	global BEAM_VIEW
	cam = rig.cam
	c = rig.king.matrix_world.translation
	ground = Vector((c.x, c.y, rig.stand))
	eye = ground + to_world_dir(rig, (0, -0.75, 1)) * 470
	out = []
	pw = move.get("cols", COLS) * CELL_W // 5
	for deg in (0, 90, 180, 270, 360):
		clear_fx()
		key = sweep_key(deg)
		pose_king(rig, key)
		BEAM_VIEW = (eye - ground).normalized()
		JHITS.clear()
		build_fx(rig, ["beam"], seed=300 + deg, t=key["t"])
		lane_marks(rig)
		jlook(scene, rig, (0.06, 1.0, 0.08))
		cam.data.type, cam.data.sensor_fit, cam.data.angle = "PERSP", "AUTO", math.radians(58)
		cam.data.clip_start, cam.data.clip_end = 0.3, 4000
		cam.location, cam.rotation_euler = eye, (ground - eye).to_track_quat("-Z", "Y").to_euler()
		img = mk.shot(scene, os.path.join(TMP, f"enuma_sweep_{deg}.png"), (pw, int(pw * 0.62)))
		out.append((f"beam {deg} deg round   t {key['t']:.2f} s   sweep +{key['sweep']:g} deg on the in-between pose", img))
	BEAM_VIEW = None
	clear_fx()
	title = f"The 360 sweep from above (owner 2026-11-13): his whole rig turns about his centre so the beam's yaw goes {SWEEP_DEG:g} degrees one way, eased, {SWEEP_T[0]:.2f} - {SWEEP_T[1]:.2f} s; cream rings: the lanes' edges (110 and 166 studs). Poses between keys are straight in-betweens, a review aid"
	return title, out


def heroes(scene, rig, folder):
	"""One large frame per move from a runner's lane: the dome mid-volley, the beam mid-sweep landing on the lanes."""
	global BEAM_VIEW
	cam = rig.cam
	c = rig.king.matrix_world.translation
	ground = Vector((c.x, c.y, rig.stand))
	g = JMOVES["gates"]
	i = 6  # 2.50 s, volley 6
	clear_fx()
	pose_king(rig, g["keys"][i])
	JHITS.clear()
	build_fx(rig, g["keys"][i]["fx"], seed=106, t=g["keys"][i]["t"])
	for o in FX.objects:
		if o.get("close_only"):
			o.hide_render = True
	jlook(scene, rig, g["sky"][i])
	eye = ground + to_world_dir(rig, (0.3, -1, 0)) * 150 + Vector((0, 0, 9))
	cam.data.type, cam.data.sensor_fit, cam.data.angle = "PERSP", "AUTO", math.radians(95)
	cam.data.clip_start, cam.data.clip_end = 0.3, 4000
	cam.location, cam.rotation_euler = eye, (to_world(rig, (0, 0, 6.5)) - eye).to_track_quat("-Z", "Y").to_euler()
	mk.shot(scene, os.path.join(folder, "gates_hero.png"), (1920, 1080))
	clear_fx()
	key = sweep_key(150)
	pose_king(rig, key)
	tip, d, end = beam_line(rig)
	a = math.atan2(end.y - c.y, end.x - c.x) - math.radians(75)
	eye = ground + Vector((math.cos(a), math.sin(a), 0)) * 150 + Vector((0, 0, 14))
	at = tip.lerp(end, 0.4) + Vector((0, 0, 10))
	BEAM_VIEW = (eye - at).normalized()
	JHITS.clear()
	build_fx(rig, ["beam", "arrows"], seed=150, t=key["t"])
	lane_marks(rig)
	jlook(scene, rig, (0.06, 1.0, 0.08))
	cam.location, cam.rotation_euler = eye, (at - eye).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle = math.radians(90)
	mk.shot(scene, os.path.join(folder, "enuma_hero.png"), (1920, 1080))
	BEAM_VIEW = None
	clear_fx()


# ---- renders and the sheet ----

MAIN, FRONT, WIDE = mk.MAIN, mk.FRONT, mk.WIDE
SIDE_W, CELL_W, STRIP_H, COLS, HEAD_H = mk.SIDE_W, mk.CELL_W, mk.STRIP_H, mk.COLS, mk.HEAD_H


def player_view(cam):
	"""The colosseum's follow camera on lane 4 (build_colosseum.player_pose): 40 studs behind the runner, turned 75 degrees inward."""
	run = Vector((math.cos(TH0), math.sin(TH0), 0)) * (R_IN + 3.5 * LANE_W)
	y = math.radians(75)
	d = (Vector((-math.sin(TH0), math.cos(TH0), 0)) * math.cos(y) - Vector((math.cos(TH0), math.sin(TH0), 0)) * math.sin(y)).normalized()
	eye = run - d * 40.0 + Vector((0, 0, CHAR_H + 3))
	look_at = eye + d * 100 + Vector((0, 0, 100 * math.tan(math.radians(4))))
	cam.data.type, cam.data.sensor_fit = "PERSP", "VERTICAL"
	cam.data.clip_start, cam.data.clip_end = 0.3, 3000
	cam.location = eye
	cam.rotation_euler = (look_at - eye).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(110)


def figure_pts(rig, key):
	objs = [rig.parts[n] for n in BODY] + [rig.parts["Key"]] + ([rig.parts[n] for n in EA_PARTS] if "ea" in key else [])
	return be.world_verts(objs)


def frame_extra(rig, key):
	"""Effect anchors that the close views must keep in frame: portals and the shield ring."""
	fx = key.get("fx", [])
	pts = []
	if any(f.startswith("portals") for f in fx):
		pts += [to_world(rig, c) for c, _, _ in PORTALS]
	if any(f.startswith("shield") for f in fx):
		pts += [to_world(rig, (SHIELD_R * 1.4 * math.cos(a), SHIELD_R * 1.4 * math.sin(a), SHIELD_Z + dz)) for a in np.linspace(0, math.tau, 12) for dz in (-1.8, 1.8)]
	if REWORK and "beam" in fx:  # the whole beam and its landing (fire wall, shock wave) stay in the close views
		tip, d, end = beam_line(rig)
		g = Vector((end.x, end.y, rig.stand))
		pts += [tip, end, g + Vector((0, 0, 60))] + [g + Vector((math.cos(a), math.sin(a), 0)) * 60 for a in np.linspace(0, math.tau, 8, endpoint=False)]
	if any(f.startswith("jportals") for f in fx):
		pts += [to_world(rig, c + d) for c, r, _ in JPORTALS for d in (Vector((r, 0, r)), Vector((-r, 0, -r)))]
	if any(f.startswith("jshields") for f in fx):
		pts += [to_world(rig, (JSHIELD_R * 1.25 * math.cos(a), JSHIELD_R * 1.25 * math.sin(a), SHIELD_Z + dz)) for a in np.linspace(0, math.tau, 12) for dz in (-1.5, 1.5)]
	return pts


def run_move(scene, rig, name, move):
	keys = move["keys"]
	union = []
	for key in keys:  # pass 1: framing over every key of the move
		pose_king(rig, key)
		pts = figure_pts(rig, key)
		extra = frame_extra(rig, key)
		if extra:
			pts = np.vstack([pts] + [np.array([[p.x, p.y, p.z]]) for p in extra])
		union.append(pts)
	union = np.vstack(union)
	cam = rig.cam
	cam.data.sensor_fit = "AUTO"
	yaw = Matrix.Rotation(FACE, 3, "Z")
	three = bk.fit(cam, union, yaw @ Vector(move.get("view", (0.65, -0.75, 0.18))), MAIN[0] / MAIN[1], margin=0.9)
	front = bk.fit(cam, union, yaw @ Vector(move.get("front", (0, -1, 0.1))), FRONT[0] / FRONT[1], margin=0.9)
	span = float(np.linalg.norm(union.max(axis=0) - union.min(axis=0)))
	clip = span * 3 - span * 0.75
	cells, records = [], []
	for i, key in enumerate(keys):
		clear_fx()
		record, grip = pose_king(rig, key)
		if REWORK:  # each panel framed on its own pose: the shared frame of a sweeping 9-unit Ea leaves him too small to read
			pts = figure_pts(rig, key)
			extra = frame_extra(rig, key)  # portals and shields round him stay in frame (none for enuma's effects)
			if extra:
				pts = np.vstack([pts] + [np.array([[p.x, p.y, p.z]]) for p in extra])
			vw = yaw @ Vector(key.get("view", (0.65, -0.75, 0.18)))
			if "beam" in key.get("fx", []):  # side-on to the beam, raised: him, the whole blast and where it lands in one frame
				_, d, _ = beam_line(rig)
				sd = Vector((-d.y, d.x, 0)).normalized()
				vw = ((sd if sd.dot(vw) >= 0 else -sd) + Vector((0, 0, 0.3))).normalized()
			three = bk.fit(cam, pts, vw, MAIN[0] / MAIN[1], margin=0.85)
			front = bk.fit(cam, pts, yaw @ Vector(move.get("front", (0, -1, 0.1))), FRONT[0] / FRONT[1], margin=0.85)
			sp = float(np.linalg.norm(pts.max(axis=0) - pts.min(axis=0)))
			clip = sp * 3 - sp * 0.75
		JHITS.clear()
		build_fx(rig, key.get("fx", []), seed=100 + i, t=key["t"], view=yaw @ Vector(key.get("view", move.get("view", (0.65, -0.75, 0.18)))))
		if REWORK and "sky" in move:  # the owner's later look: the sunset room, dimmed or tinted per key
			jlook(scene, rig, move["sky"][i])
		else:
			look(scene, rig, move.get("look", "dark" if name.startswith("enuma") else "flat"))
		cell = {}
		wide_only = [o for o in FX.objects if o.get("wide_only")]
		for o in wide_only:  # halos are for the room-scale view; close up they bury him
			o.hide_render = True
		for view, size, tag in ((three, MAIN, "main"), (front, FRONT, "front")):
			cam.location, cam.rotation_euler, cam.data.ortho_scale = view
			cam.data.type, cam.data.sensor_fit = "ORTHO", "AUTO"
			cam.data.clip_start = clip  # only what is round him: room-wide effects in front of him stay out of the close views
			cell[tag] = mk.shot(scene, os.path.join(TMP, f"{name}_{i}_{tag}.png"), size)
		for o in wide_only:
			o.hide_render = False
		if REWORK and JHITS and "hitcam" in move:  # where the hits land: from above and to his side, him and the lanes in one frame
			hc = sum(JHITS, Vector()) / len(JHITS)
			me = to_world(rig, (0, 0, 4))
			at = me.lerp(hc, 0.55)
			far = max((h - me).length for h in JHITS)  # hits all round him (the dome) need the whole ring in frame
			eye = at + to_world_dir(rig, move["hitcam"]) * max(far * (1.8 if (hc - me).length > 0.5 * far else 2.4), 60)
			for o in FX.objects:
				if o.get("close_only"):
					o.hide_render = True
			cam.data.type, cam.data.sensor_fit, cam.data.angle = "PERSP", "AUTO", math.radians(50)
			cam.data.clip_start, cam.data.clip_end = 0.3, 4000
			cam.location, cam.rotation_euler = eye, (at - eye).to_track_quat("-Z", "Y").to_euler()
			cell["wide"] = mk.shot(scene, os.path.join(TMP, f"{name}_{i}_hits.png"), WIDE)
			mk.shot(scene, os.path.join(TMP, f"{name}_{i}_hits_big.png"), (1280, 720))  # a full-size copy, for checking
			cell["wide_label"] = "hits on the lanes (side view)"
		if key.get("arena"):
			look(scene, rig, key["arena"])
			player_view(cam)
			cell["wide"] = mk.shot(scene, os.path.join(TMP, f"{name}_{i}_wide.png"), WIDE)
			mk.shot(scene, os.path.join(TMP, f"{name}_{i}_wide_big.png"), (1280, 720))  # a full-size copy, for checking
		cells.append(cell)
		rec = {"t": key["t"], "caption": key["cap"], "root_offset": list(key.get("root", (0, 0, 0))), "rotations": record, "ea_shown": "ea" in key}
		if grip:
			rec["ea_grip_offset"] = grip
		if "spin" in key:
			rec["ea_drum_spin"] = key["spin"]
		if "sweep" in key:
			rec["sweep_deg"] = key["sweep"]
		for f in ("hold", "event"):
			if f in key:
				rec["hold_until" if f == "hold" else f] = key[f]
		rec["effects"] = key.get("fx", [])
		ring = [f for f in rec["effects"] if f.startswith("shields:")]
		if ring:
			rec["shield_ring"] = ring[0].split(":")[1]
		records.append(rec)
	win = window_row(scene, rig, move) if move.get("window") == "gates" else None
	row = sweep_row(scene, rig, move) if REWORK and name == "enuma" else None
	clear_fx()
	sheet(name, move, cells, win, row)
	return records


def sheet(name, move, cells, win=None, strip=None):
	keys = move["keys"]
	cols = move.get("cols", COLS)
	rows = math.ceil(len(keys) / cols)
	cell_h = MAIN[1] + STRIP_H
	win_h = 60 + 40 + WIN[1] + 8 + MAP + 16 if win else 0
	row_h = 60 + 40 + strip[1][0][1].shape[0] + 16 if strip else 0
	px = np.ones((HEAD_H + rows * cell_h + 8 + win_h + row_h, cols * CELL_W, 4), dtype=np.float32)
	px[:, :, :3] = bk.BG
	total = f"{move['end']:.1f} s" + (" loop" if move.get("loop") else "")
	note = f"Times proposed. Wide views: vault draft from a runner's camera on lane 4, him at {SIZE:g}x a runner ({SIZE * CHAR_H:g} studs) standing on the centre mound"
	if isinstance(move.get("window"), list):
		a, b = move["window"]
		note += f". DODGE WINDOW {a:.2f} - {b:.2f} s, the hit lands at {b:.2f} s (event)"
	if name == "gates":
		note += "; the 2.0 s volley burst runs 1.60 - 3.60 s, a volley every 0.15 s (gates_window shows it)"
	if name == "gates_window":
		note += ". Times on the gates clock: these keys follow its Fire key (1.60 s); its recover key stays at 4.20 s"
	if name == "enuma_beam":
		note += ". Times on the enuma clock: the beam starts at 3.00 s when the 3 s charge window ends; the sweep runs 3.00 - 5.00 s"
	if REWORK:
		note = f"Times proposed. Jointed rig (elbows, knees). He hovers {HOVER_STUDS:g} studs over the mound (the bob plays in game, not keyed); plain backdrop, no arena view (his arena is being replaced); each panel framed on its own pose (the floor line is the mound top)"
		if "note" in move:  # the later rework moves carry their own timing note
			note += ". " + move["note"]
		else:
			note += f". DODGE WINDOW (charge) {move['window'][0]:.2f} - {move['window'][1]:.2f} s; HIT at {move['window'][1]:.2f} s: white flash, beam 3.00 - 5.00 s, recover 5.00 - 5.60 s"
	if name.startswith("enuma"):
		note += ". Cyan arcs: drum spin direction, render marks only"
	if name == "idle" and not REWORK:
		note += ". Block arms have no elbow: folded arms are two straight blocks crossed in front of the chest"
	paste_txt = [(f"{move['title']}  |  The Golden King  |  {total}  |  (proposed) key frames for approval, no in-betweens", 40, 48, 24, bk.INK), (note + ".", 22, 90, 24, bk.DIM)]
	bk.paste(px, bk.text_px(paste_txt, cols * CELL_W, HEAD_H, bk.BG), 0, 0)
	for i, key in enumerate(keys):
		row, col = divmod(i, cols)
		x, y = col * CELL_W, HEAD_H + row * cell_h
		bk.paste(px, cells[i]["main"], x, y)
		bk.small_view(px, cells[i]["front"], x + MAIN[0], y, "front")
		if "wide" in cells[i]:
			bk.small_view(px, cells[i]["wide"], x + MAIN[0], y + 32 + FRONT[1] + 12, cells[i].get("wide_label", "arena view (runner's camera)"))
		head = f"{name}  key {i + 1} of {len(keys)}   {key['t']:.2f} s" + (f"   event {key['event']}" if "event" in key else "")
		cap = key["cap"]
		if len(cap) > 100:  # two lines: a long caption runs off the cell
			cut = cap.rfind(" ", 0, len(cap) // 2 + 10)
			lines = [(cap[:cut], 21, 66, 18, bk.DIM), (cap[cut + 1 :], 21, 90, 18, bk.DIM)]
		else:
			lines = [(cap, 26, 80, 18, bk.DIM)]
		bk.paste(px, bk.text_px([(head, 34, 40 if len(cap) <= 100 else 34, 18, (0.75, 0.05, 0.05) if "event" in key else bk.INK)] + lines, CELL_W, STRIP_H, bk.BG), x, y + MAIN[1])
		px[y : y + cell_h, x : x + 2] = (0.5, 0.5, 0.52, 1)
	if win:
		y0 = HEAD_H + rows * cell_h + 8
		bk.paste(px, bk.text_px([(f"The 2 s volley burst from {move['window_start']:.2f} s, timing draft (proposed): a volley of {VOLLEY} every 0.15 s from the open portals, straight gold shots across the lanes; the last volley fades", 30, 40, 18, bk.INK)], COLS * CELL_W, 60, bk.BG), 0, y0)
		pw = COLS * CELL_W // len(win)
		for k, (t, lines, wide, top) in enumerate(win):
			x, y = k * pw, y0 + 60
			bk.paste(px, bk.text_px([(f"window {t:.1f} s   (move {move['window_start'] + t:.2f} s)", 22, 28, 10, bk.INK)], pw, 40, bk.BG), x, y)
			bk.paste(px, wide, x, y + 40)
			bk.paste(px, top, x, y + 40 + WIN[1] + 8)
			txt = [("top view", 18, 26, 12, bk.DIM)] + [(s, 19, 70 + 34 * j, 12, bk.INK) for j, s in enumerate(lines)] + [("runner's side at the bottom", 16, MAP - 20, 12, bk.DIM)]
			bk.paste(px, bk.text_px(txt, pw - MAP, MAP, bk.BG), x + MAP, y + 40 + WIN[1] + 8)
			px[y : y + win_h - 60, x : x + 2] = (0.5, 0.5, 0.52, 1)
	if strip:  # a strip of panels under the keys (Enuma's 360 sweep from above)
		y0 = HEAD_H + rows * cell_h + 8 + win_h
		bk.paste(px, bk.text_px([(strip[0], 30, 40, 18, bk.INK)], cols * CELL_W, 60, bk.BG), 0, y0)
		pw = cols * CELL_W // len(strip[1])
		for j, (label, img) in enumerate(strip[1]):
			x = j * pw
			bk.paste(px, bk.text_px([(label, 22, 28, 10, bk.INK)], pw, 40, bk.BG), x, y0 + 60)
			bk.paste(px, img, x, y0 + 100)
			px[y0 + 60 : y0 + row_h, x : x + 2] = (0.5, 0.5, 0.52, 1)
	path = os.path.join(OUT, name + "_slices.png")
	bk.save_px(px, path)
	print("SHEET", path)


def overview():
	"""Every move's main views at half size, one row per move."""
	w, h = MAIN[0] // 2, MAIN[1] // 2
	cols = max(len(m["keys"]) for m in MOVES.values())
	row_h = h + 50 + 56
	px = np.ones((90 + row_h * len(MOVES), cols * w, 4), dtype=np.float32)
	px[:, :, :3] = bk.BG
	bk.paste(px, bk.text_px([("The Golden King: all moves, (proposed) key frames for approval, no in-betweens; nothing approved yet", 36, 54, 20, bk.INK)], cols * w, 90, bk.BG), 0, 0)
	for r, (name, move) in enumerate(MOVES.items()):
		y = 90 + r * row_h
		bk.paste(px, bk.text_px([(f"{name}: {move['title']}  ({move['end']:.1f} s)", 30, 40, 16, bk.INK)], cols * w, 50, bk.BG), 0, y)
		for i, key in enumerate(move["keys"]):
			path = os.path.join(TMP, f"{name}_{i}_main.png")
			if not os.path.exists(path):
				continue
			img = bk.load_px(path)[: h * 2, : w * 2]
			small = img.reshape(h, 2, w, 2, 4).mean(axis=(1, 3))
			bk.paste(px, small, i * w, y + 50)
			bk.paste(px, bk.text_px([(f"{i + 1}  {key['t']:.2f} s  {key['cap']}", 15, 24, 8, bk.DIM)], w, 56, bk.BG), i * w, y + 50 + h)
	path = os.path.join(OUT, "all_moves_overview.png")
	bk.save_px(px, path)
	print("SHEET", path)


def main():
	global SIZE
	argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
	if "--rework" in argv:
		rework(argv)
		return
	arena = argv[argv.index("--arena") + 1] if "--arena" in argv else ARENA
	if "--size" in argv:
		SIZE = float(argv[argv.index("--size") + 1])
	wanted = [a for a in argv if a in MOVES] or list(MOVES)
	for d in (OUT, TMP, bk.TMP):
		os.makedirs(d, exist_ok=True)
	scene, rig = load_scene(arena)
	print(f"SCALE size {SIZE}x: his model height {rig.model_h:.3f} units, {rig.k:.3f} studs per unit; feet on the mound at z {rig.stand:.2f} studs")
	path = os.path.join(OUT, "keys.json")
	data = json.load(open(path)) if os.path.exists(path) else {"moves": {}}
	data.update(
		{
			"units": "XYZ Euler degrees about each part's joint, relative to its parent; root_offset in model units (Z = Roblox Y up)",
			"parents": {"Body": None, "Torso": "Body", "LeftLeg": "Body", "RightLeg": "Body", "Head": "Torso", "LeftArm": "Torso", "RightArm": "Torso", "Key": "Torso", "Ea": "RightArm", "Ea_Drum1": "Ea", "Ea_Drum2": "Ea", "Ea_Drum3": "Ea"},
			"pivots": {"Body": HIP, "Torso": WAIST, "Head": NECK, **SHOULDER, **LEG, "Key": KEY_PIVOT, "Ea": list(EA_PIVOT)},
			"ea": "Ea turns about its grip (the empty); ea_grip_offset moves the grip in the right arm's space, model units. ea_shown false: Ea is not drawn. ea_drum_spin: degrees about Ea's z; Ea_Drum1 and Ea_Drum3 turn +spin, Ea_Drum2 -spin (also in rotations)",
			"effects": f"sketch labels per key: portals_* ({N_PORTALS} gold ripple portals), streaks:j (volley j of 14, {VOLLEY} shots, the previous volley fading), shield_portals*, shields:<ring yaw degrees>|emerge ({N_SHIELDS} shields), draw, arrows, wind, charge, gather, beam, embers",
			"layout": "gates_window holds keys on the gates clock between its Fire key (1.60 s) and its recover key; enuma_beam continues enuma_charge on one clock (the beam starts at 3.00 s). Dodge windows: gates 0.00-1.60 s (before the volleys), enuma 0.00-3.00 s; shields has none",
			"scale": {"studs_per_model_unit_at_8x": round(8 * CHAR_H / rig.model_h, 4), "model_height_units": round(rig.model_h, 4), "stand_z_studs": round(rig.stand, 3), "hover": 0},
			"approved": [],
		}
	)
	for name in wanted:
		m = MOVES[name]
		data["moves"][name] = {"title": m["title"], "end": m["end"], "loop": m.get("loop", False), "keys": run_move(scene, rig, name, m)}
		if isinstance(m.get("window"), list):
			data["moves"][name]["dodge_window"] = m["window"]
		if m.get("extends"):
			data["moves"][name]["extends"] = m["extends"]
		if m.get("window") == "gates":
			data["moves"][name].update({"after_key_t": m["window_start"], "window": [m["window_start"], m["window_start"] + 2.0]})
	with open(path, "w") as f:
		json.dump(data, f, indent=1)
	overview()


def rework(argv):
	"""--rework: JMOVES on the jointed rig; writes keyframes/rework/keys.json and <move>_slices.png. MOVES and keys.json stay."""
	global REWORK, MODEL, BODY, OUT, TMP
	REWORK, MODEL, BODY = True, "boss_king_jointed", JBODY
	OUT, TMP = os.path.join(OUT, "rework"), os.path.join(TMP, "rework")
	arena = argv[argv.index("--arena") + 1] if "--arena" in argv else ARENA
	wanted = [a for a in argv if a in JMOVES] or list(JMOVES)
	for d in (OUT, TMP, bk.TMP):
		os.makedirs(d, exist_ok=True)
	scene, rig = load_scene(arena)
	print(f"SCALE size {SIZE}x: model height {rig.model_h:.3f} units, {rig.k:.3f} studs per unit; rest feet {HOVER_STUDS:g} studs over the mound top {rig.stand:.2f}")
	path = os.path.join(OUT, "keys.json")
	data = json.load(open(path)) if os.path.exists(path) else {"moves": {}}
	data.update(
		{
			"rig": "jointed (build_boss_king.py -- jointed): Torso, Head, upper and lower arm and leg per side, Key, Ea; the lower arm carries the hand, the lower leg the foot",
			"units": "XYZ Euler degrees about each part's joint, relative to its parent; root_offset in model units from the hover height (Z = Roblox Y up)",
			"parents": JPARENT | {"Ea_Drum1": "Ea", "Ea_Drum2": "Ea", "Ea_Drum3": "Ea"},
			"pivots": {"Body": HIP, "Torso": WAIST, "Head": NECK, "Key": KEY_PIVOT, "Ea": list(EA_PIVOT), **{SEG[n][0]: SHOULDER[n] for n in SHOULDER}, **{SEG[n][1]: list(ELBOW[n]) for n in ELBOW}, **{SEG[n][0]: LEG[n] for n in LEG}, **{SEG[n][1]: list(KNEE[n]) for n in KNEE}},
			"ea": "Ea turns about its grip (the empty); ea_grip_offset moves the grip in the right lower arm's space, model units. ea_drum_spin: degrees about Ea's z; Ea_Drum1 and Ea_Drum3 turn +spin, Ea_Drum2 -spin (also in rotations)",
			"effects": "sketch labels per key: draw (gold ripple at Ea's grip), arrows (drum spin marks), charge (groove glow), ball:<size> (white ball and red rings at Ea's tip), wind, gather, flash (one white flash at the tip), beam (from Ea's tip along its axis), embers; the red arena tint runs with the charge and beam. Later moves: jportals:<f>[:tips|:close] (design C sun-wheel portals, the first f of them in his arm's sweep order), jvolley:<j> (volley j of 14 from them), jshields:<f>:<state>:<yaw> (shield portals and shields, state portal|emerge|ring|lock), cmd:<L|R> (the command flash at that hand). 2026-11-12 later look: jportals blades only in full portals (portal, then weapon, then shot); jvolley shots fly straight out along their portal's facing (each portal faces the lanes) and land with a gold hit (flash, white core, shock ring, sparks, dust); beam in the rework runs along Ea's blade axis, about 60 studs wide (white core 14, crimson 40, black-red outer 60, a dark-red volume, black strands, red lightning, a turning cyclone) to a red-black shock wave, red fire and black smoke where it lands. 2026-11-13 later (owner): jportals stand in an ordered dome round him (fixed tiers, open top, each facing out and down to the lanes, see the gates note); the beam runs exactly along Ea's blade axis to where it meets the deck (no clamp), 1.5 x wider with a yellow-white hot core, orange fire billows, thin bright red rim lines, the red-black cyclone and black strands kept strong, a red-white burst with black smoke and rubble; sweep_deg: the whole rig's turn about his centre on top of the key (Enuma's 360 sweep)",
			"hover": {"studs_over_mound": HOVER_STUDS, "bob_studs": 1.5, "bob_seconds": 3.0, "note": "proposed, owner 2026-11-12; the bob is played in game, not keyed"},
			"scale": {"studs_per_model_unit_at_8x": round(8 * CHAR_H / rig.model_h, 4), "model_height_units": round(rig.model_h, 4)},
			"approved": [],
		}
	)
	if "--hero" in argv:  # only the hero frames, nothing else written
		heroes(scene, rig, argv[argv.index("--hero") + 1])
		return
	for name in wanted:
		m = JMOVES[name]
		entry = {"title": m["title"], "end": m["end"], "loop": m.get("loop", False)}
		if "window" in m:
			entry["dodge_window"] = m["window"]
		if "strike_window" in m:
			entry["strike_window"] = m["strike_window"]
		entry["keys"] = run_move(scene, rig, name, m)
		data["moves"][name] = entry
	with open(path, "w") as f:
		json.dump(data, f, indent=1)
	print("KEYS", path)


if __name__ == "__main__":
	main()
