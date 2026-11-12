# The Elf Mage (boss_mage) key poses for owner review: hover idle and three attacks. Key frames only: no in-betweens, no bake. Headless:
#   Blender -b --factory-startup --python tools/blender/boss_mage_keyframes.py -- [idle lightning golem barrage] [--arena <blend>] [--size 4]
# Needs boss_mage.blend and boss_golem.blend (build_boss_mage.py) and the colosseum draft (mage m3, build/arena/colosseum_draft_r70.blend).
# Writes assets/characters_avatar/boss_mage/keyframes/<move>_slices.png, all_moves_overview.png and keys.json. Nothing uploads.
#
# MOVES is the pose data. Model axes: front faces -Y, +X is her left, Z up (Roblox Y), model units as built (she is runner sized).
#   root   offset of the whole figure, model units. "root[2]" is the Roblox Y rise; 1 model unit = SIZE*CHAR_H/her height studs in game.
#   body   rotation of the whole figure about the hips (HIP). torso: about the waist, carries head, arms, tails, staff. head: about NECK.
#   Parts  TailL/TailR, LeftLeg/RightLeg: X Y Z Euler degrees about their joint, relative to their parent (head, body).
#          LeftArm/RightArm: Euler degrees, or {"aim": point} = hand aimed at a point in rest model space (relative to the torso).
#          Signs: X+ leans a part forward (arms, tails, legs: swings the free end back); Y+ moves the top toward her left.
#   staff  "two": along the line right hand to left hand (both hands on it); else Euler degrees about the grip relative to the
#          right arm, (180, 0, 0) = straight on from the arm. keys.json holds every solved rotation, so a bake reads plain numbers.
#   golem  pose: Euler degrees per golem part, replacing its rest value; "scatter"/"crumble": its blocks loose (positions recorded).
#
# --rework: the 2026-11-12 animation rework (design doc 4.37 "Animation rework") on the jointed rig (boss_mage_jointed.blend from
# build_boss_mage.py -- jointed), as boss_king_keyframes.py --rework does. JMOVES is kept apart from MOVES (shipped, owner approved
# 2026-11-11, baked by bake_boss_mage.py from keyframes/keys.json) and writes keyframes/rework/keys.json and <move>_slices.png.
# She hovers (bob 1.5 studs over 3 s in game, not keyed; no foot plants). Key fields as MOVES, plus:
#   LeftArm/RightArm  {"aim": point, "pole": dir}: a two-bone solve in torso space (boss_king_keyframes.two_bone); the hand reaches
#          the point (clamped to reach) and the elbow bends toward pole. LeftArm "grip": the left fist on the staff GRIP2 up the shaft.
#   LeftLeg/RightLeg  hip Euler degrees, or {"hip": euler, "knee": degrees}: knee > 0 bends the shin back.
#   TailL/TailR  three Eulers, root segment first, each relative to the segment above (one Euler: the root segment only).
#   staff  as MOVES, or {"dir": d}: the shaft's axis in the body's yawed frame, the grip in the right fist.
#   look   the close views' backdrop for this key ("flash": the white-out, she a dark silhouette).
import json
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import boss_keyframes as bk  # noqa: E402  (guarded main: sheet text, pixels and ortho fit)
import build_boss_event as be  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "characters_avatar", "boss_mage", "keyframes")
TMP = os.path.join(ROOT, "build", "boss_mage_keyframes")
ORCH = os.path.dirname(ROOT)
ARENA = os.path.join(ORCH, "mage-m3", "build", "arena", "colosseum_draft_r70.blend")
CIRCLE_PNG = os.path.join(ORCH, "mage-m8", "assets", "ui", "boss_mage", "magic_circle.png")

REWORK = False  # main(--rework): the jointed rig and JMOVES
MODEL = "boss_mage"
SIZE = 4.0  # her height in runner heights; the owner may pick 6, 8 or 12 (--size): every wide view scales from this one number
CHAR_H, HOVER, GOLEM_RATIO = 5.5, 8.0, 1.6  # runner studs; her feet above the floor in studs (kept at any size); golem over her height
R_IN, LANE_W, R_WALL = 70.0, 8.0, 132.0  # colosseum r70 draft
TH0 = math.radians(-41)  # the colosseum's followed runner on lane 4
FACE = TH0 + math.pi / 2  # she faces that runner (as the colosseum's stand-in)
HIP, WAIST, NECK = (0, 0, 2.0), (0, 0, 2.0), (0, 0, 4.5)
SHOULDER = {"LeftArm": (1.5, 0, 3.8), "RightArm": (-1.5, 0, 3.8)}
HAND = {"LeftArm": Vector((1.5, 0, 2.05)), "RightArm": Vector((-1.5, 0, 2.05))}
LEG = {"LeftLeg": (0.5, 0, 2.0), "RightLeg": (-0.5, 0, 2.0)}
TAIL = {"TailL": (0.86, 0.36, 5.86), "TailR": (-0.86, 0.36, 5.86)}
GRIP = Vector((-1.5, -0.62, 2.05))  # the staff's origin
GOLEM_SPOT = (-40.0, 12.0)  # golem feet, studs at 4x, in her frame: on her right, a little back
HOVER_POSE = {
	"torso": (8, 0, 0),
	"RightArm": {"aim": (-0.95, -1.3, 2.2)},
	"LeftArm": {"aim": (1.05, -1.35, 3.25)},
	"staff": "two",
	"TailL": (-4, -30, 0),
	"TailR": (-4, 30, 0),
	"LeftLeg": (24, 0, -2),
	"RightLeg": (18, 0, 2),
}


def hover(**k):
	d = dict(HOVER_POSE)
	d.update(k)
	return d


ONE = (180, 0, 0)  # staff straight on from the right arm
MOVES = {
	"idle": {
		"title": "Idle: hover",
		"end": 3.0,
		"loop": True,
		"keys": [
			hover(t=0.0, cap="Low point, tails still flung", root=(0, 0, 0), torso=(9, 0, 4), head=(4, 0, -4), TailL=(-12, -52, 4), TailR=(-12, 52, -4), LeftLeg=(30, 0, -2), RightLeg=(24, 0, 2)),
			hover(t=0.75, cap="Rising, tails drag down-in", root=(0, 0, 0.213), torso=(5, 0, 0), head=(0, 0, 0), TailL=(10, -8, 0), TailR=(10, 8, 0), LeftLeg=(14, 0, -2), RightLeg=(8, 0, 2), RightArm={"aim": (-0.95, -1.3, 2.05)}, LeftArm={"aim": (1.05, -1.35, 3.05)}),
			hover(t=1.5, cap="High point, sway left", root=(0, 0, 0.426), torso=(10, 0, -4), head=(2, 0, 5), TailL=(-2, -26, 0), TailR=(-2, 26, 0), LeftLeg=(22, 0, -2), RightLeg=(16, 0, 2)),
			hover(t=2.25, cap="Falling, tails up and out", root=(0, 0, 0.213), torso=(11, 0, 0), head=(-3, 0, 0), TailL=(-24, -72, 6), TailR=(-24, 72, -6), LeftLeg=(38, 0, -4), RightLeg=(32, 0, 4), RightArm={"aim": (-0.95, -1.3, 2.35)}, LeftArm={"aim": (1.05, -1.35, 3.45)}),
		],
	},
	"lightning": {
		"title": "Attack: purple lightning",
		"end": 3.2,
		"keys": [
			{"t": 0.0, "cap": "Anticipation: coils, staff swung back", "root": (0, 0, -0.3), "torso": (16, 0, 28), "head": (8, 0, -14), "RightArm": {"aim": (-2.4, 1.5, 4.4)}, "staff": ONE, "LeftArm": {"aim": (0.2, -1.6, 2.6)}, "TailL": (6, -14, 0), "TailR": (6, 14, 0), "LeftLeg": (-28, 0, -6), "RightLeg": (-12, 0, 6)},
			{"t": 0.9, "cap": "Charge: staff overhead, orb builds", "fx": ["charge"], "root": (0, 0, 0.35), "torso": (-12, 0, -8), "head": (-16, 0, 0), "RightArm": {"aim": (-1.6, -0.1, 5.6)}, "staff": ONE, "LeftArm": {"aim": (3.3, -0.6, 3.4)}, "TailL": (-26, -64, 0), "TailR": (-26, 64, 0), "LeftLeg": (22, 0, -10), "RightLeg": (38, 0, 8)},
			{"t": 1.6, "cap": "Release: staff thrust up, flash", "event": "Lightning", "fx": ["release"], "arena": "violet", "root": (0, 0, 0.8), "torso": (-18, 0, 0), "head": (-26, 0, 0), "RightArm": {"aim": (-1.5, -0.25, 5.75)}, "staff": ONE, "LeftArm": {"aim": (2.4, 1.4, 2.4)}, "TailL": (-34, -84, 0), "TailR": (-34, 84, 0), "LeftLeg": (30, 0, -4), "RightLeg": (32, 0, 4)},
			{"t": 2.0, "cap": "Strike: bolts fill the room", "fx": ["strike"], "arena": "violet", "root": (0, 0, 0.5), "torso": (6, 0, 12), "head": (6, 0, -8), "RightArm": {"aim": (-2.2, -1.2, 5.2)}, "staff": ONE, "LeftArm": {"aim": (3.4, -0.6, 2.9)}, "TailL": (-12, -74, 12), "TailR": (6, 44, -12), "LeftLeg": (42, 0, -12), "RightLeg": (10, 0, 12)},
			{"t": 2.8, "cap": "Recover to hover", "fx": ["embers"], **{k: v for k, v in hover(root=(0, 0, 0.15), torso=(14, 0, 0), head=(10, 0, 0), TailL=(8, -14, 0), TailR=(8, 14, 0)).items()}},
		],
	},
	"golem": {
		"title": "Attack: stone golem slam",
		"end": 5.0,
		"view": (0.3, -1, 0.22),  # more from the front than the others: her and the golem side by side
		"keys": [
			{"t": 0.0, "cap": "Staff sweeps down to the floor", "fx": ["rune"], "root": (0, 0, -0.2), "torso": (12, -22, -18), "head": (16, -8, -22), "RightArm": {"aim": (-3.1, -0.9, 2.2)}, "staff": ONE, "LeftArm": {"aim": (3.1, 0.6, 4.6)}, "TailL": (-6, -58, 0), "TailR": (10, 10, 0), "LeftLeg": (30, 0, 10), "RightLeg": (8, 0, 14), "golem": None},
			{"t": 0.7, "cap": "Rubble lifts and gathers", "fx": ["rune", "seams"], "arena": "warm", "root": (0, 0, 0.25), "torso": (-10, -12, -14), "head": (-10, -6, -20), "RightArm": {"aim": (-3.0, -0.7, 5.0)}, "staff": ONE, "LeftArm": {"aim": (2.9, -0.9, 4.8)}, "TailL": (-24, -66, 0), "TailR": (-24, 66, 0), "LeftLeg": (26, 0, -6), "RightLeg": (34, 0, 6), "golem": {"scatter": 1.0}},
			{"t": 1.4, "cap": "Golem stands, staff on it", "root": (0, 0, 0.1), "torso": (2, -4, -24), "head": (0, -4, -26), "RightArm": {"aim": (-3.5, -0.9, 3.6)}, "staff": ONE, "LeftArm": {"aim": (2.2, 0.6, 2.4)}, "TailL": (-6, -36, 0), "TailR": (-6, 36, 0), "LeftLeg": (24, 0, -2), "RightLeg": (18, 0, 2), "golem": {"pose": {}}},
			{"t": 2.0, "hold": 4.0, "cap": "Wind-up: 2 s rhythm circles", "fx": ["dust"], "arena": "warm", "root": (0, 0, 0.3), "torso": (-14, -6, -14), "head": (-14, 0, -18), "RightArm": {"aim": (-1.9, 0.2, 5.7)}, "staff": ONE, "LeftArm": {"aim": (1.7, -1.7, 3.2)}, "TailL": (-14, -50, 0), "TailR": (-14, 50, 0), "LeftLeg": (16, 0, -6), "RightLeg": (30, 0, 6), "golem": {"pose": {"Hip": (-8, 0, 0), "Torso": (-22, 0, 0), "Head": (10, 0, 0), "ShoulderL": (0, -14, 0), "ShoulderR": (0, 14, 0), "UpperArmL": (-172, 8, 0), "UpperArmR": (-172, -8, 0), "ForearmL": (0, 55, 0), "ForearmR": (0, -55, 0), "ThighL": (-10, 0, 0), "ThighR": (-10, 0, 0), "ShinL": (10, 0, 0), "ShinR": (10, 0, 0)}}},
			{"t": 4.2, "cap": "Slam: shockwave and cracks", "event": "Slam", "fx": ["shock"], "arena": "warm", "root": (0, 0, 0.7), "torso": (-10, 12, 16), "head": (-12, 6, 10), "RightArm": {"aim": (-2.6, 1.6, 3.4)}, "staff": ONE, "LeftArm": {"aim": (3.3, 0.8, 4.4)}, "TailL": (-30, -80, 0), "TailR": (-30, 80, 0), "LeftLeg": (40, 0, -12), "RightLeg": (8, 0, 12), "golem": {"pose": {"Hip": (34, 0, 0), "Torso": (56, 0, 0), "Head": (-40, 0, 0), "ShoulderL": (0, -8, 0), "ShoulderR": (0, 8, 0), "UpperArmL": (-141, 14, 0), "UpperArmR": (-141, -14, 0), "ForearmL": (-25, 0, 0), "ForearmR": (-25, 0, 0), "ThighL": (-40, 0, 0), "ThighR": (-40, 0, 0), "ShinL": (30, 0, 0), "ShinR": (30, 0, 0)}, "drop": True}},
			{"t": 4.8, "cap": "Golem crumbles, back to hover", "fx": ["dust_low"], **{k: v for k, v in hover(root=(0, 0, 0.2), TailL=(6, -16, 0), TailR=(6, 16, 0)).items()}, "golem": {"crumble": True}},
		],
	},
	"barrage": {
		"title": "Attack: magic circle barrage",
		"end": 3.4,
		"keys": [
			{"t": 0.0, "cap": "Staff forward, held level", "root": (0, 0, 0), "torso": (14, 0, 0), "head": (4, 0, 0), "RightArm": {"aim": (-1.0, -2.0, 3.5)}, "LeftArm": {"aim": (1.0, -2.0, 3.5)}, "staff": "two", "TailL": (-4, -30, 0), "TailR": (-4, 30, 0), "LeftLeg": (26, 0, -2), "RightLeg": (20, 0, 2)},
			{"t": 0.8, "cap": "Circles open, faint", "fx": ["circles_faint"], "arena": "blue", "root": (0, 0, 0.25), "torso": (-4, 0, 0), "head": (-6, 0, 0), "RightArm": {"aim": (-1.0, -1.7, 4.9)}, "LeftArm": {"aim": (1.0, -1.7, 4.9)}, "staff": "two", "TailL": (-14, -44, 0), "TailR": (-14, 44, 0), "LeftLeg": (20, 0, -4), "RightLeg": (14, 0, 4)},
			{"t": 1.5, "cap": "Charge: hair blown back", "fx": ["circles_bright"], "arena": "blue", "root": (0, 0.1, 0.3), "torso": (-12, 0, 0), "head": (-10, 0, 0), "RightArm": {"aim": (-0.9, -2.1, 4.1)}, "LeftArm": {"aim": (0.9, -2.1, 4.1)}, "staff": "two", "TailL": (62, -26, 0), "TailR": (62, 26, 0), "LeftLeg": (44, 0, -4), "RightLeg": (36, 0, 4)},
			{"t": 2.0, "cap": "Fire: beams from every circle", "event": "Barrage", "fx": ["circles_bright", "beams"], "arena": "blue", "root": (0, 0.5, 0.35), "torso": (-20, 0, 0), "head": (-14, 0, 0), "RightArm": {"aim": (-0.9, -2.0, 4.6)}, "LeftArm": {"aim": (0.9, -2.0, 4.6)}, "staff": "two", "TailL": (78, -34, 0), "TailR": (78, 34, 0), "LeftLeg": (52, 0, -6), "RightLeg": (42, 0, 6)},
			{"t": 2.9, "cap": "Circles fade, recover", "fx": ["circles_fade"], **{k: v for k, v in hover(root=(0, 0, 0.1), TailL=(14, -18, 0), TailR=(14, 18, 0)).items()}},
		],
	},
}
APPROVED = tuple(MOVES)  # owner approved 2026-11-11: their keys never change; overview() shows only these
# boss-mage-2 g2 (owner 2026-11-11). Sustain moves: times on the parent move's clock, inserted after its strike/fire key (2.00 s);
# the parent's recover key then plays 2.0 s later than approved. window: 5 effect panels at window time 0, 0.5, 1, 1.5, 2 s.
GOLEM_FRONT = (-0.42, -0.91, 0.1)  # the golem's front in her frame (it is turned 25 degrees toward the arena centre)
MOVES.update(
	{
		"lightning_window": {
			"title": "Attack: purple lightning, 2 s strike window (sustain after key 4)",
			"extends": "lightning",
			"window": "lightning",
			"window_start": 2.0,
			"window_key": 0,
			"end": 5.2,
			"keys": [
				{"t": 2.5, "cap": "Sustain: staff held high, bolts keep falling", "fx": ["sustain"], "arena": "violet", "root": (0, 0, 0.6), "torso": (-14, 0, 0), "head": (-20, 0, 0), "RightArm": {"aim": (-1.6, -0.2, 5.6)}, "staff": ONE, "LeftArm": {"aim": (3.2, -0.4, 3.6)}, "TailL": (-30, -80, 0), "TailR": (-30, 80, 0), "LeftLeg": (34, 0, -4), "RightLeg": (28, 0, 4)},
				{"t": 3.25, "cap": "Sway: hips swing right, staff stays up", "fx": ["sustain"], "arena": "violet", "root": (-0.25, 0, 0.5), "torso": (-8, -10, -10), "head": (-14, 0, 8), "RightArm": {"aim": (-1.9, -0.5, 5.6)}, "staff": ONE, "LeftArm": {"aim": (3.0, 0.4, 3.0)}, "TailL": (-20, -60, 10), "TailR": (-36, 90, -10), "LeftLeg": (20, 0, 4), "RightLeg": (40, 0, -4)},
				{"t": 4.0, "cap": "Release: staff comes down, last bolts", "fx": ["embers"], "root": (0, 0, 0.3), "torso": (12, 0, 6), "head": (8, 0, -4), "RightArm": {"aim": (-2.4, -1.4, 3.6)}, "staff": ONE, "LeftArm": {"aim": (2.8, -0.8, 2.6)}, "TailL": (6, -20, 0), "TailR": (6, 20, 0), "LeftLeg": (30, 0, -4), "RightLeg": (16, 0, 4)},
			],
		},
		"barrage_window": {
			"title": "Attack: barrage, 2 s beam window (sustain after key 4)",
			"extends": "barrage",
			"window": "barrage",
			"window_start": 2.0,
			"window_key": 0,
			"end": 5.4,
			"keys": [
				{"t": 2.5, "cap": "Sustain: circles held open, beams keep firing", "fx": ["circles_bright", "beams_room"], "arena": "blue", "root": (0, 0.3, 0.35), "torso": (-14, 0, 0), "head": (-10, 0, 0), "RightArm": {"aim": (-0.9, -2.0, 4.4)}, "LeftArm": {"aim": (0.9, -2.0, 4.4)}, "staff": "two", "TailL": (60, -30, 0), "TailR": (60, 30, 0), "LeftLeg": (44, 0, -4), "RightLeg": (36, 0, 4)},
				{"t": 3.25, "cap": "Sway: staff tilts, beams sweep the floor", "fx": ["circles_bright", "beams_room"], "arena": "blue", "root": (0.35, 0.3, 0.3), "torso": (-10, -12, 16), "head": (-6, 4, -10), "RightArm": {"aim": (-1.5, -1.8, 3.2)}, "LeftArm": {"aim": (0.4, -2.0, 5.4)}, "staff": "two", "TailL": (50, -40, 6), "TailR": (66, 24, -6), "LeftLeg": (36, 0, -6), "RightLeg": (44, 0, 6)},
				{"t": 4.0, "cap": "Release: last beams, circles start to fade", "fx": ["circles_fade"], "arena": "blue", "root": (0, 0.1, 0.2), "torso": (4, 0, 0), "head": (0, 0, 0), "RightArm": {"aim": (-1.0, -1.8, 3.4)}, "LeftArm": {"aim": (1.0, -1.8, 3.4)}, "staff": "two", "TailL": (30, -24, 0), "TailR": (30, 24, 0), "LeftLeg": (30, 0, -2), "RightLeg": (24, 0, 2)},
			],
		},
		"golem_idle": {
			"title": "Stone Golem (miniboss): idle, heavy breathing",
			"solo": "golem",
			"end": 2.4,
			"loop": True,
			"view": (0.05, -1, 0.2),
			"front": GOLEM_FRONT,
			"keys": [
				{"t": 0.0, "cap": "Breathe in: chest lifts, shoulders up", "golem": {"ground": True, "pose": {"Torso": (6, 0, 0), "Head": (-18, 0, 0), "ShoulderL": (0, -6, 0), "ShoulderR": (0, 6, 0), "UpperArmL": (-12, 0, 4), "UpperArmR": (-12, 0, -4), "ForearmL": (-10, 0, 0), "ForearmR": (-10, 0, 0)}}},
				{"t": 1.2, "cap": "Breathe out: chest sinks, fists swing forward", "golem": {"ground": True, "pose": {"Hip": (4, 0, 0), "Torso": (18, 0, 0), "Head": (-8, 0, 0), "ShoulderL": (0, 4, 0), "ShoulderR": (0, -4, 0), "UpperArmL": (-26, 0, 4), "UpperArmR": (-26, 0, -4), "ForearmL": (-20, 0, 0), "ForearmR": (-20, 0, 0), "ThighL": (-6, 0, 0), "ThighR": (-6, 0, 0), "ShinL": (8, 0, 0), "ShinR": (8, 0, 0)}}},
			],
		},
		"golem_sweep": {
			"title": "Stone Golem (miniboss): arm sweep across the lanes",
			"solo": "golem",
			"end": 3.6,
			"view": (-0.3, -0.65, 0.75),  # high, from its front: the arm's arc across the lanes reads from above
			"front": GOLEM_FRONT,
			"keys": [
				{"t": 0.0, "cap": "Turns to its right, arm starts back", "golem": {"ground": True, "pose": {"Hip": (4, 0, -6), "Torso": (14, 0, -16), "Head": (-14, 0, 10), "ShoulderR": (0, 6, 0), "UpperArmR": (-10, 50, -20), "UpperArmL": (-30, 0, 6), "ForearmL": (-24, 0, 0), "ForearmR": (-10, 0, 0)}}},
				{"t": 0.6, "hold": 1.8, "cap": "Wind-up held: 2 s rhythm circles", "fx": ["dust"], "arena": "warm", "golem": {"ground": True, "pose": {"Hip": (6, 0, -12), "Torso": (14, 0, -32), "Head": (-14, 0, 22), "ShoulderR": (0, 12, 0), "UpperArmR": (0, 82, -42), "ForearmR": (0, 0, 0), "UpperArmL": (-44, 0, 10), "ForearmL": (-34, 0, 0), "ThighL": (-16, 0, 0), "ShinL": (12, 0, 0), "ThighR": (8, 0, 0)}}},
				{"t": 2.0, "event": "Sweep", "cap": "Sweep: the arm crosses the lanes", "fx": ["sweep"], "arena": "warm", "golem": {"ground": True, "pose": {"Hip": (10, 0, 4), "Torso": (22, 0, 10), "Head": (-24, 0, -4), "ShoulderR": (0, 4, 0), "UpperArmR": (0, 88, 90), "ForearmR": (0, 0, 0), "UpperArmL": (-10, 0, 10), "ForearmL": (-10, 0, 0), "ThighL": (6, 0, 0), "ThighR": (-14, 0, 0), "ShinR": (12, 0, 0)}}},
				{"t": 2.4, "cap": "Follow-through: arm past its left", "fx": ["dust_low"], "golem": {"ground": True, "pose": {"Hip": (8, 0, 14), "Torso": (16, 0, 36), "Head": (-14, 0, -24), "UpperArmR": (-20, 70, 110), "ForearmR": (0, 0, 0), "UpperArmL": (0, -10, 10), "ForearmL": (0, 0, 0), "ThighL": (10, 0, 0), "ThighR": (-18, 0, 0), "ShinR": (16, 0, 0)}}},
				{"t": 3.2, "cap": "Recover to its stance", "golem": {"ground": True, "pose": {}}},
			],
		},
		"golem_fall": {
			"title": "Stone Golem (miniboss): falls at 0 HP",
			"solo": "golem",
			"end": 2.0,
			"view": (0.8, -0.9, 0.25),  # from its front-left side: the knees and the forward fall read
			"front": GOLEM_FRONT,
			"keys": [
				{"t": 0.0, "cap": "HP 0: knees buckle, head drops", "golem": {"ground": True, "pose": {"Hip": (16, 0, 0), "Torso": (30, 0, 8), "Head": (24, 0, 0), "UpperArmL": (-4, -6, 0), "UpperArmR": (-4, 6, 0), "ForearmL": (0, 0, 0), "ForearmR": (0, 0, 0), "ThighL": (-44, 0, 0), "ThighR": (-34, 0, 0), "ShinL": (56, 0, 0), "ShinR": (44, 0, 0)}}},
				{"t": 0.6, "cap": "Magic fails: blocks split apart", "fx": ["seams"], "golem": {"ground": True, "break": True, "pose": {"Hip": (24, 0, 0), "Torso": (40, 0, 14), "Head": (34, 0, 10), "UpperArmL": (10, -14, 0), "UpperArmR": (10, 14, 0), "ThighL": (-60, 0, 0), "ThighR": (-52, 0, 0), "ShinL": (74, 0, 0), "ShinR": (66, 0, 0)}}},
				{"t": 1.4, "cap": "Rubble heap: the golem is gone", "fx": ["dust_low"], "golem": {"crumble": True}},
			],
		},
		"watch": {
			"title": "The Elf Mage: watch (while the golem stands)",
			"end": 3.0,
			"loop": True,
			"golem_context": True,  # the golem is drawn for context only: its pose is in golem_idle, not here
			"view": (0.3, -1, 0.22),
			"keys": [
				hover(t=0.0, cap="Calm hover, staff low, eyes on the golem", golem={"ground": True, "pose": {}}, root=(0, 0, 0), torso=(6, 0, -10), head=(4, 0, -30), RightArm={"aim": (-0.9, -1.2, 1.5)}, LeftArm={"aim": (0.7, -1.4, 2.4)}),
				hover(t=1.5, cap="Hover high, head tilts, still watching", golem={"ground": True, "pose": {}}, root=(0, 0, 0.426), torso=(8, 0, -12), head=(2, 0, -34), RightArm={"aim": (-0.9, -1.2, 1.4)}, LeftArm={"aim": (0.7, -1.4, 2.3)}, TailL=(-2, -26, 0), TailR=(-2, 26, 0)),
			],
		},
	}
)
# shortcut: circle layout is hand placed for the 4x frame (her model units); retune if a larger size crowds the arena view
CIRCLES = [  # centre in her model space, diameter, tilt (X, Y, Z degrees from facing her front)
	((0.0, 1.2, 4.6), 5.2, (0, 0, 0)),
	((-4.6, 1.8, 6.4), 3.4, (10, 25, 0)),
	((4.4, 2.2, 7.0), 4.0, (-8, -28, 0)),
	((-5.2, 0.4, 2.6), 2.0, (0, 35, 10)),
	((5.6, 0.8, 3.0), 2.6, (6, -38, 0)),
	((-2.4, 3.0, 9.4), 2.2, (-20, 12, 0)),
	((2.0, 2.6, 10.0), 1.4, (-24, -8, 0)),
	((-7.2, 2.6, 5.0), 1.2, (0, 48, 0)),
	((7.6, 2.4, 6.0), 1.6, (0, -52, 0)),
]


# ---- the mage: pose solver ----


def eul(d):
	return Euler([math.radians(v) for v in d]).to_matrix().to_4x4()


def about(p, r):
	return Matrix.Translation(p) @ r @ Matrix.Translation(-Vector(p))


def aim_rot(joint, target):
	return Vector((0, 0, -1)).rotation_difference((Vector(target) - Vector(joint)).normalized()).to_matrix().to_4x4()


def degs(m):
	return [round(math.degrees(v), 3) for v in m.to_euler("XYZ")]


def solve(key):
	"""Model-space matrix per part (applied on top of its rest) and the plain local rotations for keys.json."""
	rot = {"Body": eul(key.get("body", (0, 0, 0))), "Torso": eul(key.get("torso", (0, 0, 0))), "Head": eul(key.get("head", (0, 0, 0)))}
	for n in ("TailL", "TailR", "LeftLeg", "RightLeg"):
		rot[n] = eul(key.get(n, (0, 0, 0)))
	for n in SHOULDER:
		a = key.get(n, (0, 0, 0))
		rot[n] = aim_rot(SHOULDER[n], a["aim"]) if isinstance(a, dict) else eul(a)
	m = {}
	body = Matrix.Translation(key.get("root", (0, 0, 0))) @ about(HIP, rot["Body"])
	torso = body @ about(WAIST, rot["Torso"])
	m["Torso_merged"] = torso
	m["Head_merged"] = head = torso @ about(NECK, rot["Head"])
	for n in TAIL:
		m[n] = head @ about(TAIL[n], rot[n])
	for n in LEG:
		m[n + "_merged"] = body @ about(LEG[n], rot[n])
	arm = {n: about(SHOULDER[n], rot[n]) for n in SHOULDER}
	for n in SHOULDER:
		m[n + "_merged"] = torso @ arm[n]
	staff = key.get("staff", ONE)
	if staff == "two":
		low, high = arm["RightArm"] @ HAND["RightArm"], arm["LeftArm"] @ HAND["LeftArm"]
		r = Vector((0, 0, 1)).rotation_difference((high - low).normalized()).to_matrix().to_4x4()
		local = arm["RightArm"].inverted() @ Matrix.Translation(low) @ r @ Matrix.Translation(-GRIP)
	else:
		local = Matrix.Translation(HAND["RightArm"] - GRIP) @ about(GRIP, eul(staff))  # grip on the fist, turned about it
	m["Staff"] = m["RightArm_merged"] @ local
	r3 = local.to_3x3()
	rot["Staff"] = r3.to_4x4()
	grip = local.translation - (GRIP - r3 @ GRIP)
	record = {n: degs(r) for n, r in rot.items()}
	return m, record, [round(v, 4) for v in grip]


# ---- effects: simple emissive meshes ----

_mats = {}


def glow_mat(name, rgb, strength, alpha=1.0, image=None):
	key = (name, tuple(rgb), strength, alpha, image)
	if key in _mats:
		return _mats[key]
	m = bpy.data.materials.new(name)
	if m.node_tree is None:
		m.use_nodes = True
	nt = m.node_tree
	for n in list(nt.nodes):
		nt.nodes.remove(n)
	out, em = nt.nodes.new("ShaderNodeOutputMaterial"), nt.nodes.new("ShaderNodeEmission")
	em.inputs["Color"].default_value = (*rgb, 1)
	em.inputs["Strength"].default_value = strength
	shader = em.outputs[0]
	if alpha < 1 or image:
		mix, tr = nt.nodes.new("ShaderNodeMixShader"), nt.nodes.new("ShaderNodeBsdfTransparent")
		mix.inputs[0].default_value = alpha
		if image:
			tex = nt.nodes.new("ShaderNodeTexImage")
			tex.image = bpy.data.images.load(image, check_existing=True)
			mul, tint = nt.nodes.new("ShaderNodeMath"), nt.nodes.new("ShaderNodeMix")
			mul.operation = "MULTIPLY"
			mul.inputs[1].default_value = alpha
			nt.links.new(tex.outputs["Alpha"], mul.inputs[0])
			nt.links.new(mul.outputs[0], mix.inputs[0])
			tint.data_type, tint.blend_type = "RGBA", "MULTIPLY"
			tint.inputs["Factor"].default_value = 1
			nt.links.new(tex.outputs["Color"], tint.inputs["A"])
			tint.inputs["B"].default_value = (*rgb, 1)
			nt.links.new(tint.outputs["Result"], em.inputs["Color"])
		nt.links.new(tr.outputs[0], mix.inputs[1])
		nt.links.new(shader, mix.inputs[2])
		shader = mix.outputs[0]
		m.surface_render_method = "BLENDED"
	nt.links.new(shader, out.inputs["Surface"])
	_mats[key] = m
	return m


def matte_mat(name, rgb):
	if name not in _mats:
		_mats[name] = bk.matte(name, rgb)
	return _mats[name]


FX = None


def fx_link(o, mat):
	o.data.materials.append(mat)
	for c in o.users_collection:
		c.objects.unlink(o)
	FX.objects.link(o)
	return o


def tube(pts, r, mat):
	cu = bpy.data.curves.new("fx", "CURVE")
	cu.dimensions, cu.bevel_depth, cu.bevel_resolution, cu.use_fill_caps = "3D", r, 2, True
	sp = cu.splines.new("POLY")
	sp.points.add(len(pts) - 1)
	for p, q in zip(sp.points, pts):
		p.co = (*q, 1)
	o = bpy.data.objects.new("fx", cu)
	bpy.context.scene.collection.objects.link(o)
	return fx_link(o, mat)


def ball(c, r, mat):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=r, location=c)
	return fx_link(bpy.context.object, mat)


def ring(c, r, w, mat, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=w, major_segments=64, minor_segments=6, location=c, rotation=rot)
	return fx_link(bpy.context.object, mat)


def disc(c, r, mat, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_circle_add(vertices=32, radius=r, fill_type="NGON", location=c, rotation=rot)
	return fx_link(bpy.context.object, mat)


def block(c, s, mat, rng):
	bpy.ops.mesh.primitive_cube_add(size=s, location=c, rotation=[rng.uniform(0, 3) for _ in range(3)])
	return fx_link(bpy.context.object, mat)


def lamp(c, rgb, watts, r=2.0):
	light = bpy.data.objects.new("fxlight", bpy.data.lights.new("fxlight", "POINT"))
	light.location, light.data.color, light.data.energy, light.data.shadow_soft_size = c, rgb, watts, r
	light.data.use_shadow = False  # many effect lights: shadows overflow EEVEE's shadow buffer
	FX.objects.link(light)


def jag(a, b, n, amp, rng):
	a, b = Vector(a), Vector(b)
	d = b - a
	side = d.orthogonal().normalized()
	up = d.cross(side).normalized()
	pts = [a]
	for i in range(1, n):
		t = i / n
		pts.append(a + d * t + (side * rng.uniform(-1, 1) + up * rng.uniform(-1, 1)) * amp)
	return pts + [b]


VIOLET, WHITE, ICE = (0.55, 0.12, 1.0), (1.0, 0.94, 1.0), (0.55, 0.8, 1.0)


def bolt(a, b, r, rng, branches=2, lamp_w=0.0):
	"""A jagged bolt: white-hot core, violet-magenta glow shell, and short forks."""
	pts = jag(a, b, 12, (Vector(b) - Vector(a)).length * 0.05, rng)
	paths = [pts]
	for _ in range(branches):
		i = rng.randrange(2, len(pts) - 3)
		d = (pts[i + 1] - pts[i]).normalized()
		off = d.orthogonal().normalized() * rng.uniform(0.6, 1.2) * (Vector(b) - Vector(a)).length * 0.18
		off.rotate(Euler((0, 0, rng.uniform(0, math.tau))))
		paths.append(jag(pts[i], pts[i] + d * (Vector(b) - Vector(a)).length * 0.12 + off, 5, (Vector(b) - Vector(a)).length * 0.02, rng))
	for k, p in enumerate(paths):
		w = r if k == 0 else r * 0.5
		tube(p, w, glow_mat("BoltCore", WHITE, 30))
		tube(p, w * 2.2, glow_mat("BoltGlow", (0.62, 0.08, 1.0), 1.6, 0.6))
		tube(p, w * 5, glow_mat("BoltHalo", (0.8, 0.1, 0.9), 0.5, 0.3))["wide_only"] = True  # magenta halo, dim so it stays coloured
	if lamp_w:
		lamp(Vector(b) + Vector((0, 0, 3)), (0.4, 0.25, 1.0), lamp_w)


# ---- the scene ----


class Rig:
	pass


def load_scene(arena):
	bpy.ops.wm.open_mainfile(filepath=arena)
	scene = bpy.context.scene
	scene.eevee.taa_render_samples = 24
	rig = Rig()
	rig.arena = [o for o in scene.objects if o.name.startswith(("Colosseum", "Runner"))]
	for o in scene.objects:
		if o.name.startswith("Mage"):  # the colosseum's block stand-ins for her: replaced by the model
			o.hide_render = True
	rig.lights = {o: o.data.copy() for o in scene.objects if o.type == "LIGHT"}
	rig.air = scene.world
	rig.flat = bpy.data.worlds.new("Flat")
	sun = bpy.data.objects.new("FlatSun", bpy.data.lights.new("FlatSun", "SUN"))
	sun.data.energy, sun.data.angle = 2.4, math.radians(25)
	scene.collection.objects.link(sun)
	rig.sun = sun
	rig.cam = scene.camera
	rig.bloom = scene.compositing_node_group.nodes["Bloom"]
	mage = be.append_model("boss_mage") if MODEL == "boss_mage" else append_from(os.path.join(ROOT, "assets", "characters_avatar", "boss_mage", MODEL + ".blend"))
	golem = be.append_model("boss_golem")
	rig.mage, rig.golem = mage, golem
	rig.parts = {o.name: o for o in mage.children}
	rig.rest = {n: o.matrix_basis.copy() for n, o in rig.parts.items()}
	if REWORK:
		TPIV.update({n: rig.rest[n].translation.copy() for n in rig.parts if n.startswith("Tail")})
	pts = be.world_verts([o for n, o in rig.parts.items() if n != "Staff"])
	rig.model_h = float(pts[:, 2].max() - pts[:, 2].min())
	rig.k = SIZE * CHAR_H / rig.model_h  # studs per model unit in game
	mage.location, mage.rotation_euler, mage.scale = (0, 0, HOVER), (0, 0, FACE), (rig.k,) * 3
	staff = rig.parts["Staff"]
	co = np.array([v.co for v in staff.data.vertices])
	rig.gem = Vector(co[co[:, 2] > co[:, 2].max() - 0.9].mean(axis=0).tolist())  # the head of the staff, staff-local
	rig.gparts = {o.name: o for o in golem.children_recursive}
	rig.grest = {n: (o.location.copy(), o.rotation_euler.copy()) for n, o in rig.gparts.items()}
	gpts = be.world_verts(list(rig.gparts.values()))
	rig.golem_h = float(gpts[:, 2].max() - gpts[:, 2].min())
	kg = GOLEM_RATIO * SIZE * CHAR_H / rig.golem_h
	s = SIZE / 4
	yaw = Matrix.Rotation(FACE, 3, "Z")
	golem.location = yaw @ Vector((GOLEM_SPOT[0] * s, GOLEM_SPOT[1] * s, 0)) + Vector((0, 0, -float(gpts[:, 2].min()) * kg))
	golem.rotation_euler, golem.scale = (0, 0, FACE + math.radians(-25)), (kg,) * 3  # turned a little toward the arena centre
	rig.kg = kg
	bpy.ops.mesh.primitive_circle_add(vertices=64, radius=55 * s, fill_type="NGON", location=(golem.location.x / 2, golem.location.y / 2, 0))
	rig.floor = bpy.context.object  # her close views of the golem move: a plain floor disc
	rig.floor.data.materials.append(matte_mat("FlatFloor", (0.52, 0.47, 0.42)))
	global FX
	FX = bpy.data.collections.new("FX")
	scene.collection.children.link(FX)
	return scene, rig


def look(scene, rig, mode, floor=False):
	"""flat / dark: plain backdrop for her close views. warm, violet, blue: the colosseum lit for a wide view."""
	arena = mode in ("warm", "violet", "blue")
	for o in rig.arena:
		o.hide_render = not arena
	rig.floor.hide_render = arena or not floor
	rig.sun.hide_render = arena
	for o, d0 in rig.lights.items():
		o.hide_render = not arena
		o.data.color, o.data.energy = d0.color, d0.energy
	if arena:
		scene.world = rig.air
		nt = rig.air.node_tree
		sky = {"warm": ("#4A3426", "#0E1322", 0.5), "violet": ("#1E0C88", "#120840", 0.5), "blue": ("#0C1A78", "#060C38", 0.55)}[mode]
		mix = nt.nodes["SkyMix"]
		mix.inputs["A"].default_value = be_rgb(sky[0])
		mix.inputs["B"].default_value = be_rgb(sky[1])
		next(n for n in nt.nodes if n.type == "BACKGROUND").inputs["Strength"].default_value = sky[2]
		for o in rig.lights:
			kind = o.name.split(".")[0]
			torch = kind == "Light" and o.location.z > 15
			if mode == "warm":
				o.data.color, o.data.energy = {"Key": ((0.55, 0.4, 1.0), 0), "Fill": ((1.0, 0.78, 0.55), 170000)}.get(kind, ((1.0, 0.55, 0.22), 26000) if torch else ((1.0, 0.65, 0.3), 4000))
			elif mode == "violet":
				o.data.color, o.data.energy = {"Key": ((0.42, 0.28, 1.0), 9e5), "Fill": ((0.15, 0.1, 1.0), 30000)}.get(kind, ((0.2, 0.1, 1.0), 8000) if torch else ((0.35, 0.25, 1.0), 1500))
			else:
				o.data.color, o.data.energy = {"Key": ((0.5, 0.7, 1.0), 5e5), "Fill": ((0.25, 0.4, 1.0), 110000)}.get(kind, ((0.15, 0.3, 1.0), 9000) if torch else ((0.3, 0.5, 1.0), 1500))
		for name, (wc, cc) in {"flame": ("#FFB04A", "#D9C8FF"), "glowDoor": ("#FFB45A", "#C6B4FF")}.items():
			mat = bpy.data.materials.get(name)
			if mat:
				bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
				bsdf.inputs["Emission Color"].default_value = be_rgb(wc if mode == "warm" else cc)
		scene.view_settings.view_transform = "AgX"
		scene.view_settings.look = "None" if mode == "warm" else "AgX - Punchy"
		rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 0.8, 0.4 if mode == "warm" else 1.0
	else:
		scene.world = rig.flat
		bg = next(n for n in rig.flat.node_tree.nodes if n.type == "BACKGROUND")
		bg.inputs["Color"].default_value = {"flat": (0.78, 0.8, 0.84, 1), "dark": (0.035, 0.022, 0.085, 1), "darkblue": (0.02, 0.03, 0.08, 1), "flash": (1.0, 0.97, 1.0, 1)}[mode]
		bg.inputs["Strength"].default_value = {"flat": 0.8, "flash": 3.0}.get(mode, 1.0)
		rig.sun.data.energy = {"flat": 2.4, "flash": 0.15}.get(mode, 1.6)
		rig.sun.data.color = (1, 1, 1) if mode == "flat" else ((0.85, 0.75, 1.0) if mode == "dark" else (0.75, 0.85, 1.0))
		rig.sun.rotation_euler = (math.radians(50), math.radians(10), FACE + math.radians(-25))
		scene.view_settings.view_transform = "Standard"
		scene.view_settings.look = "None"
		rig.bloom.inputs["Threshold"].default_value, rig.bloom.inputs["Strength"].default_value = 1.0, 0.8
		if mode == "flash":  # white to the camera, near black as light: she reads as a dark silhouette against the white-out (clip 2)
			scene.world = flash_world()
			rig.bloom.inputs["Strength"].default_value = 0.25


def flash_world():
	w = bpy.data.worlds.get("FlashOut")
	if w:
		return w
	w = bpy.data.worlds.new("FlashOut")
	w.use_nodes = True
	nt = w.node_tree
	bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
	bg.inputs["Color"].default_value, bg.inputs["Strength"].default_value = (1.0, 0.97, 1.0, 1), 1.0
	dim = nt.nodes.new("ShaderNodeBackground")
	dim.inputs["Color"].default_value, dim.inputs["Strength"].default_value = (0.5, 0.4, 0.9, 1), 0.12
	mix, lp = nt.nodes.new("ShaderNodeMixShader"), nt.nodes.new("ShaderNodeLightPath")
	out = next(n for n in nt.nodes if n.type == "OUTPUT_WORLD")
	nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
	nt.links.new(dim.outputs[0], mix.inputs[1])
	nt.links.new(bg.outputs[0], mix.inputs[2])
	nt.links.new(mix.outputs[0], out.inputs["Surface"])
	return w


def append_from(path):
	"""be.append_model for a blend that is not <cid>/<cid>.blend (the jointed build)."""
	with bpy.data.libraries.load(path) as (src, dst):
		dst.objects = list(src.objects)
	for o in dst.objects:
		bpy.context.scene.collection.objects.link(o)
	return next(o for o in dst.objects if o.parent is None and o.type == "EMPTY")


def be_rgb(h):
	h = h.lstrip("#")
	return tuple((int(h[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)


def to_world(rig, p):
	"""Her model space (root at her rest feet) to studs."""
	return rig.mage.matrix_world @ Vector(p)


def pose_mage(rig, key):
	if REWORK:
		m, record, grip, short = jsolve(key)
		far = {k: v for k, v in short.items() if v > 0.05}
		if far:
			print("REACH", key["t"], far)
	else:
		m, record, grip = solve(key)
	for n, o in rig.parts.items():
		o.matrix_basis = m.get(n, Matrix()) @ rig.rest[n]
	bpy.context.view_layer.update()
	return record, grip


def pose_golem(rig, spec, rng):
	"""Returns the record of every golem part (local location in golem units, rotation in degrees) or None when hidden."""
	show = spec is not None
	rig.golem.hide_render = not show
	for o in rig.gparts.values():
		o.hide_render = not show
	if not show:
		return None
	for n, o in rig.gparts.items():
		loc, r = rig.grest[n]
		o.location, o.rotation_euler = loc, r
		if n in spec.get("pose", {}):
			o.rotation_euler = [math.radians(v) for v in spec["pose"][n]]
	bpy.context.view_layer.update()
	order = sorted(rig.gparts.values(), key=lambda o: sum(1 for _ in iter_parents(o)))
	if spec.get("scatter") or spec.get("crumble") or spec.get("break"):
		centre = rig.golem.matrix_world.translation
		targets = {}
		for o in order:
			c = Vector(be.world_verts([o]).mean(axis=0).tolist())
			flat = Vector((c.x - centre.x, c.y - centre.y, 0))
			if spec.get("break"):
				# blocks shift apart and sag where they stand: the pose still reads, the magic no longer holds it
				p = c + flat * 0.25 + Vector((rng.uniform(-2, 2), rng.uniform(-2, 2), -c.z * 0.1 + rng.uniform(-1, 1)))
				r = Euler([rng.uniform(-0.35, 0.35) for _ in range(3)])
			elif spec.get("scatter"):
				# blocks rise off the floor and drift in toward where the golem forms, spread and tumbling
				p = centre + flat * 1.7 + Vector((rng.uniform(-4, 4), rng.uniform(-4, 4), c.z * 0.45 + rng.uniform(4, 12)))
				r = Euler([rng.uniform(-0.8, 0.8) for _ in range(3)])
			else:
				p = centre + flat * 1.3 + Vector((rng.uniform(-6, 6), rng.uniform(-6, 6), 0))
				r = Euler([rng.uniform(-1.4, 1.4) for _ in range(3)])
			targets[o.name] = Matrix.Translation(p) @ r.to_matrix().to_4x4() @ Matrix.Translation(-c) @ o.matrix_world
		for o in order:  # parents first: a child's world matrix is set against its parent's new one
			o.matrix_world = targets[o.name]
			bpy.context.view_layer.update()
			if spec.get("crumble"):
				low = float(be.world_verts([o])[:, 2].min())
				lift = rng.choice((0, 0, 0, 0.6, 5.0))  # most blocks down, a few still tumbling
				o.matrix_world = Matrix.Translation((0, 0, -low + lift)) @ o.matrix_world
				bpy.context.view_layer.update()
	if spec.get("drop"):
		# slam: whole golem lowered so the fists sit on the floor
		low = min(float(be.world_verts([rig.gparts[f]])[:, 2].min()) for f in ("FistL", "FistR"))
		rig.golem.location.z -= low
		bpy.context.view_layer.update()
		print(f"SLAM root moved {-low:.2f} studs; feet lowest now {float(be.world_verts([rig.gparts[n] for n in ('ShinL', 'ShinR')])[:, 2].min()):.2f}")
		bpy.context.view_layer.update()
	if spec.get("ground"):
		# the lowest block rests on the floor (bent knees would otherwise float or sink it)
		rig.golem.location.z -= float(be.world_verts(list(rig.gparts.values()))[:, 2].min())
		bpy.context.view_layer.update()
	return {n: {"loc": [round(v, 3) for v in o.location], "rot": [round(math.degrees(v), 2) for v in o.rotation_euler]} for n, o in rig.gparts.items()}


def iter_parents(o):
	while o.parent is not None:
		o = o.parent
		yield o


# ---- effects per key ----


def build_fx(rig, names, seed):
	rng = random.Random(seed)
	staff = rig.parts["Staff"]
	gem = staff.matrix_world @ rig.gem
	k = rig.k
	s = SIZE / 4
	g = rig.golem.matrix_world.translation
	for name in names:
		if name.split(":")[0] in JFX:
			JFX[name.split(":")[0]](rig, name.partition(":")[2], rng, gem)
			continue
		if name == "charge":
			ball(gem, 0.45 * k, glow_mat("OrbCore", WHITE, 50))
			ball(gem, 0.9 * k, glow_mat("OrbGlow", VIOLET, 3, 0.35))
			for _ in range(7):
				d = Vector([rng.uniform(-1, 1) for _ in range(3)]).normalized()
				bolt(gem, gem + d * rng.uniform(1.2, 2.2) * k, 0.05 * k, rng, branches=0)
			lamp(gem, (0.7, 0.45, 1.0), 4e4 * s * s)
		elif name == "release":
			ball(gem, 0.5 * k, glow_mat("OrbCore", WHITE, 40))
			ball(gem, 1.1 * k, glow_mat("FlashGlow", VIOLET, 2, 0.15))
			ring(gem, 2.4 * k, 0.08 * k, glow_mat("FlashRing", WHITE, 12, 0.8), rot=(math.radians(90), 0, FACE))
			bolt(gem, Vector((gem.x * 0.5, gem.y * 0.5, 140)), 1.0, rng, branches=4)
			for _ in range(4):
				d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.3, 1))).normalized()
				bolt(gem, gem + d * rng.uniform(2.0, 3.4) * k, 0.06 * k, rng, branches=1)
			lamp(gem + Vector((0, 0, 12 * s)), (0.6, 0.45, 1.0), 1.2e5 * s * s, 4)
		elif name == "strike":
			ball(gem, 0.5 * k, glow_mat("OrbCore", WHITE, 50))
			ball(gem, 0.9 * k, glow_mat("OrbGlow", VIOLET, 3, 0.35))
			for _ in range(5):  # crackle around her
				d = Vector([rng.uniform(-1, 1) for _ in range(3)]).normalized()
				bolt(gem, gem + d * rng.uniform(1.5, 3.0) * k, 0.06 * k, rng, branches=1)
			for i in range(16):  # strikes all round the room; every third on the lane ring
				a = i / 16 * math.tau + rng.uniform(-0.15, 0.15)
				r = rng.uniform(R_IN + 4, R_IN + 52) if i % 3 == 0 else rng.uniform(26, R_WALL - 8)
				foot = Vector((r * math.cos(a), r * math.sin(a), 0.2))
				top = Vector((r * 0.65 * math.cos(a + rng.uniform(-0.2, 0.2)), r * 0.65 * math.sin(a + rng.uniform(-0.2, 0.2)), rng.uniform(95, 140)))
				bolt(top, foot, rng.uniform(0.7, 1.1), rng, branches=3, lamp_w=6e4)
				disc(foot, 6, glow_mat("Mark", (0.9, 0.8, 1.0), 3, 0.8))
				ring(foot, 9, 0.5, glow_mat("MarkRing", VIOLET, 4, 0.7))
		elif name == "embers":
			for _ in range(5):
				d = Vector([rng.uniform(-1, 1) for _ in range(3)]).normalized()
				bolt(gem, gem + d * rng.uniform(0.6, 1.2) * k, 0.03 * k, rng, branches=0)
		elif name == "rune":
			ring((g.x, g.y, 0.15), 15 * s, 0.35 * s, glow_mat("Rune", (0.75, 0.55, 1.0), 10, 0.9))
			ring((g.x, g.y, 0.15), 11 * s, 0.2 * s, glow_mat("Rune", (0.75, 0.55, 1.0), 10, 0.9))
			disc((g.x, g.y, 0.1), 15 * s, glow_mat("RuneFill", (0.55, 0.35, 1.0), 1.5, 0.35))
			bolt(gem, Vector((g.x, g.y, 0.3)), 0.25 * s, rng, branches=1)
		elif name == "seams":
			mat = glow_mat("Seam", (0.75, 0.5, 1.0), 2.5)
			for o in rig.gparts.values():
				c = o.copy()
				c.data = o.data.copy()
				c.data.materials.clear()
				FX.objects.link(c)
				c.parent, c.matrix_parent_inverse, c.matrix_basis = o, Matrix(), Matrix()
				w = c.modifiers.new("seam", "WIREFRAME")
				w.thickness = 0.035
				c.data.materials.append(mat)
			for _ in range(14):  # small rubble rising with them
				block(g + Vector((rng.uniform(-14, 14) * s, rng.uniform(-14, 14) * s, rng.uniform(0.5, 18) * s)), rng.uniform(1, 2.6) * s, matte_mat("Rubble", (0.55, 0.45, 0.33)), rng)
		elif name in ("dust", "dust_low"):
			for _ in range(40 if name == "dust" else 24):
				h = rng.uniform(2, 50) * s if name == "dust" else rng.uniform(0.2, 6) * s
				block(g + Vector((rng.uniform(-16, 16) * s, rng.uniform(-16, 16) * s, h)), rng.uniform(0.3, 1.1) * s, matte_mat("Dust", (0.72, 0.64, 0.52)), rng)
			if name == "dust_low":
				ring((g.x, g.y, 0.5), 30 * s, 2.2 * s, glow_mat("DustRing", (0.85, 0.78, 0.66), 1.2, 0.35))
		elif name == "shock":
			fists = [rig.gparts[f].matrix_world.translation for f in ("FistL", "FistR")]
			hit = (fists[0] + fists[1]) / 2
			hit.z = 0.2
			for rr, w, a in ((14, 1.6, 0.9), (24, 1.1, 0.6), (34, 0.7, 0.35)):
				ring(hit, rr * s, w * s, glow_mat("Shock", (1.0, 0.85, 0.6), 2.2, a))
			disc(hit, 8 * s, glow_mat("ShockCore", (1.0, 0.9, 0.7), 2.5, 0.5))
			for i in range(12):  # cracks
				a = i / 12 * math.tau + rng.uniform(-0.2, 0.2)
				pts = [hit + Vector((math.cos(a), math.sin(a), 0)) * (4 * s)]
				for _ in range(5):
					a += rng.uniform(-0.35, 0.35)
					pts.append(pts[-1] + Vector((math.cos(a), math.sin(a), 0)) * rng.uniform(4, 7) * s)
				tube([(p.x, p.y, 0.15) for p in pts], 0.35 * s, glow_mat("Crack", (1.0, 0.55, 0.2), 3))
			for _ in range(30):
				block(hit + Vector((rng.uniform(-22, 22) * s, rng.uniform(-22, 22) * s, rng.uniform(1, 20) * s)), rng.uniform(0.8, 2.8) * s, matte_mat("Rubble", (0.55, 0.45, 0.33)), rng)
			lamp(hit + Vector((0, 0, 6)), (1.0, 0.8, 0.55), 1.5e5 * s * s, 6)
		elif name in ("sustain", "beams_room"):
			# the 2 s windows' keys: room-wide hits drawn for the arena view only, so the close views keep her readable
			if name == "sustain":
				ball(gem, 0.5 * k, glow_mat("OrbCore", WHITE, 50))
				ball(gem, 0.9 * k, glow_mat("OrbGlow", VIOLET, 3, 0.35))
				for _ in range(5):
					d = Vector([rng.uniform(-1, 1) for _ in range(3)]).normalized()
					bolt(gem, gem + d * rng.uniform(1.5, 3.0) * k, 0.06 * k, rng, branches=1)
			before = set(FX.objects)
			for p, ci, h in win_spots("lightning" if name == "sustain" else "barrage", seed):
				if name == "sustain":
					bolt(Vector((p.x * 0.8, p.y * 0.8, h)), p, 0.9, rng, branches=2, lamp_w=6e4)
					disc(p, 6, glow_mat("Mark", (0.9, 0.8, 1.0), 3, 0.8))
				else:
					beam(to_world(rig, CIRCLES[ci][0]), p, 0.5 * s * 1.6)
			for o in set(FX.objects) - before:
				o["wide_only"] = True
		elif name == "sweep":
			# the fist's trail: an arc round the golem at fist height, from its right side to where the fist is now
			fist = Vector(be.world_verts([rig.gparts["FistR"]]).mean(axis=0).tolist())
			rad = math.hypot(fist.x - g.x, fist.y - g.y)
			a1 = math.atan2(fist.y - g.y, fist.x - g.x)
			pts = [Vector((g.x + rad * math.cos(a1 - math.radians(110) * (1 - i / 16)), g.y + rad * math.sin(a1 - math.radians(110) * (1 - i / 16)), fist.z)) for i in range(17)]
			tube(pts, 1.6 * s, glow_mat("SweepTrail", (1.0, 0.85, 0.6), 1.4, 0.45))
			tube(pts[6:], 0.6 * s, glow_mat("SweepCore", (1.0, 0.95, 0.85), 4, 0.9))
			for p in pts[::2]:
				block(Vector((p.x, p.y, rng.uniform(0.5, 4) * s)), rng.uniform(0.6, 1.6) * s, matte_mat("Dust", (0.72, 0.64, 0.52)), rng)
		elif name.startswith("circles"):
			bright, fade = name == "circles_bright", name == "circles_fade"
			yaw = Matrix.Rotation(FACE, 3, "Z")
			for i, (c, dia, tilt) in enumerate(CIRCLES):
				if fade and i % 3 == 2:
					continue  # already gone
				p = to_world(rig, c)
				rot = (yaw.to_4x4() @ eul((90, 0, 0)) @ eul(tilt)).to_euler()
				size = dia * k * (1.12 if fade else 1)
				bpy.ops.mesh.primitive_plane_add(size=size, location=p, rotation=rot)
				strength, alpha = (1.8, 1.0) if bright else ((0.8, 0.35) if not fade else (1.2, 0.3))
				fx_link(bpy.context.object, glow_mat("Circle", (1.0, 1.0, 1.0), strength, alpha, CIRCLE_PNG))
				if bright:
					n = rot.to_matrix() @ Vector((0, 0, 1))
					ball(p + n * 0.05, dia * k * 0.06, glow_mat("CircleCore", WHITE, 12))
					ball(p + n * 0.05, dia * k * 0.13, glow_mat("CircleGlow", ICE, 1.5, 0.25))
			if bright:
				lamp(to_world(rig, (0, 1.5, 9)), (0.6, 0.8, 1.0), 3e4 * s * s, 6)
		elif name == "beams":
			yaw = Matrix.Rotation(FACE, 3, "Z")
			for i, (c, dia, tilt) in enumerate(CIRCLES):
				p = to_world(rig, c)
				d = yaw @ Euler((math.radians(rng.uniform(8, 24)), 0, math.radians(rng.uniform(-95, 95)))).to_matrix() @ Vector((0, -1, 0))
				t = -p.z / d.z if d.z < 0 else 1e9
				a2, b2 = d.x**2 + d.y**2, 2 * (p.x * d.x + p.y * d.y)
				t = min(t, (-b2 + math.sqrt(b2 * b2 - 4 * a2 * (p.x**2 + p.y**2 - R_WALL**2))) / (2 * a2))
				end = p + d * t
				w = dia * k * 0.08
				tube([p, end], w, glow_mat("BeamCore", WHITE, 14))
				tube([p, end], w * 2.2, glow_mat("BeamGlow", (0.35, 0.62, 1.0), 2.0, 0.45))
				tube([p, end], w * 4.5, glow_mat("BeamHalo", (0.3, 0.5, 1.0), 0.5, 0.25))["wide_only"] = True
				ball(end, w * 3, glow_mat("HitCore", WHITE, 14))
				ball(end, w * 7, glow_mat("HitGlow", ICE, 1.5, 0.3))
				lamp(end + (p - end).normalized() * 4, (0.6, 0.8, 1.0), 6e4, 4)


def clear_fx():
	for o in list(FX.objects):
		bpy.data.objects.remove(o, do_unlink=True)


# ---- the 2 s windows: effect timing drafts (not final VFX) ----

WIN_N, WIN_FADE = 6, 3  # (proposed) new hits per half second; how many of the last panel's still show, fading


def win_spots(kind, j):
	"""Set j of floor spots (one set per half second of the window), half on the lane ring, half anywhere in the room."""
	rng = random.Random((700 if kind == "lightning" else 750) + j)
	out = []
	for i in range(WIN_N):
		a = rng.uniform(0, math.tau)
		r = rng.uniform(R_IN, R_IN + 7 * LANE_W) if i % 2 == 0 else rng.uniform(22, R_WALL - 8)
		out.append((Vector((r * math.cos(a), r * math.sin(a), 0.2)), rng.randrange(len(CIRCLES)), rng.uniform(95, 140)))
	return out


def beam(a, b, w, dim=False):
	if dim:
		tube([a, b], w * 0.6, glow_mat("BeamFade", (0.35, 0.62, 1.0), 0.8, 0.25))
		ring(b, w * 6, w * 0.6, glow_mat("HitFade", ICE, 0.8, 0.3))
		return
	tube([a, b], w, glow_mat("BeamCore", WHITE, 14))
	tube([a, b], w * 2.2, glow_mat("BeamGlow", (0.35, 0.62, 1.0), 2.0, 0.45))
	ball(b, w * 3, glow_mat("HitCore", WHITE, 14))
	ring(b, w * 6, w * 0.8, glow_mat("HitRing", ICE, 4, 0.8))
	lamp(b + Vector((0, 0, 4)), (0.6, 0.8, 1.0), 2e4, 4)


def window_fx(rig, kind, k):
	"""Panel k (window time 0.5 k s). Lightning: strikes on the spots marked half a second before, new white-core marks for
	the next half second, the last strikes fading. Barrage: circles open, beams from random circles to random floor spots."""
	rng = random.Random(900 + k)
	t = 0.5 * k
	now, nxt, old = win_spots(kind, k), (win_spots(kind, k + 1) if k < 4 else []), (win_spots(kind, k - 1)[:WIN_FADE] if k else [])
	if kind == "lightning":
		gem = rig.parts["Staff"].matrix_world @ rig.gem
		ball(gem, 0.5 * rig.k, glow_mat("OrbCore", WHITE, 50))
		ball(gem, 0.9 * rig.k, glow_mat("OrbGlow", VIOLET, 3, 0.35))
		for p, _, h in now:
			bolt(Vector((p.x * 0.8, p.y * 0.8, h)), p, 0.9, rng, branches=2, lamp_w=6e4)
			disc(p, 6, glow_mat("Mark", (0.9, 0.8, 1.0), 3, 0.8))
			ring(p, 9, 0.5, glow_mat("MarkRing", VIOLET, 4, 0.7))
		for p, _, _ in nxt:  # telegraph: white core on the floor, no bolt yet
			disc(p, 5, glow_mat("Tele", WHITE, 6, 0.95))
			ring(p, 8, 0.7, glow_mat("TeleRing", VIOLET, 6, 0.95))
		for p, _, h in old:
			tube(jag(Vector((p.x * 0.8, p.y * 0.8, h)), p, 10, 3, rng), 0.4, glow_mat("BoltFade", (0.62, 0.08, 1.0), 0.8, 0.25))
			ring(p, 9, 0.4, glow_mat("ScorchFade", VIOLET, 1.0, 0.3))
		when = "wind-up marks" if k == 0 else f"marked at {t - 0.5:.1f} s"
		return [f"{len(now)} bolts strike ({when})", f"{len(nxt)} new marks for {t + 0.5:.1f} s" if nxt else "no new marks: window ends", f"{len(old)} fading from {t - 0.5:.1f} s" if old else "none fading yet"]
	build_fx(rig, ["circles_bright"], seed=900 + k)
	w = 0.5 * SIZE / 4 * 1.6
	for p, ci, _ in now:
		beam(to_world(rig, CIRCLES[ci][0]), p, w)
	for p, ci, _ in old:
		beam(to_world(rig, CIRCLES[ci][0]), p, w, dim=True)
	return [f"{len(now)} beams fire", "circles stay open", f"{len(old)} fading from {t - 0.5:.1f} s" if old else "none fading yet"]


WIN, MAP = (744, 418), 418


def window_row(scene, rig, move):
	kind = move["window"]
	pose_mage(rig, move["keys"][move["window_key"]])
	look(scene, rig, "violet" if kind == "lightning" else "blue")
	cam = rig.cam
	out = []
	for k in range(5):
		clear_fx()
		lines = window_fx(rig, kind, k)
		player_view(cam)
		wide = shot(scene, os.path.join(TMP, f"{kind}_window_{k}_wide.png"), WIN)
		cam.data.type, cam.data.ortho_scale = "ORTHO", 2 * R_WALL + 10
		cam.location, cam.rotation_euler = (0, 0, 400), (0, 0, FACE)  # top view, the runner's side of the room at the bottom
		cam.data.clip_start, cam.data.clip_end = 400 - 80, 500  # only below 80 studs: no roof, bolt tops cut
		top = shot(scene, os.path.join(TMP, f"{kind}_window_{k}_top.png"), (MAP, MAP))
		out.append((0.5 * k, lines, wide, top))
	clear_fx()
	return out


# ---- renders and the sheet ----

MAIN, FRONT, WIDE = (700, 820), (540, 380), (540, 304)
SIDE_W = 540
CELL_W, STRIP_H, COLS, HEAD_H = MAIN[0] + SIDE_W, 96, 3, 110


def player_view(cam):
	"""The colosseum's follow camera on lane 4 (build_colosseum.player_pose): 40 studs behind the runner, turned 75 degrees inward."""
	run = Vector((math.cos(TH0), math.sin(TH0), 0)) * (R_IN + 3.5 * LANE_W)
	y = math.radians(75)
	d = (Vector((-math.sin(TH0), math.cos(TH0), 0)) * math.cos(y) - Vector((math.cos(TH0), math.sin(TH0), 0)) * math.sin(y)).normalized()
	back = 40.0
	while back > 1 and (run - d * back).length > R_WALL - 2.5:
		back -= 0.25
	eye = run - d * back + Vector((0, 0, CHAR_H + 3))
	look = eye + d * 100 + Vector((0, 0, 100 * math.tan(math.radians(4))))
	cam.data.type, cam.data.sensor_fit = "PERSP", "VERTICAL"
	cam.data.clip_start, cam.data.clip_end = 0.3, 3000
	cam.location = eye
	cam.rotation_euler = (look - eye).to_track_quat("-Z", "Y").to_euler()
	cam.data.angle_y = math.radians(100 if SIZE <= 4 else 110)


def figure_pts(rig, golem_on, extra=(), mage_on=True):
	objs = (list(rig.parts.values()) if mage_on else []) + (list(rig.gparts.values()) if golem_on else []) + list(extra)
	return be.world_verts(objs)


def shot(scene, path, size):
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	return bk.load_px(path)


def run_move(scene, rig, name, move):
	keys = move["keys"]
	has_golem = any("golem" in kk for kk in keys)
	solo = move.get("solo") == "golem"  # the golem alone: she is hidden and her parts are not recorded
	hidden = {o: o.hide_render for o in rig.parts.values()}
	for o in rig.parts.values():
		o.hide_render = o.hide_render or solo
	g_z = rig.golem.location.z
	records, union = [], []
	for i, key in enumerate(keys):  # pass 1: framing over every key of the move
		pose_mage(rig, key)
		rig.golem.location.z = g_z
		pose_golem(rig, key.get("golem") if has_golem else None, random.Random(i))
		extra = []
		if key.get("fx") and any(f.startswith("circles") for f in key["fx"]):
			extra = [to_world(rig, c) for c, d, _ in CIRCLES]
		pts = figure_pts(rig, has_golem and key.get("golem") is not None, mage_on=not solo)
		if extra:
			pts = np.vstack([pts] + [np.array([[p.x, p.y, p.z + dz]]) for p in extra for dz in (-3 * rig.k, 3 * rig.k)])
		union.append(pts)
	union = np.vstack(union)
	cam = rig.cam
	cam.data.sensor_fit = "AUTO"  # bk.fit sizes ortho_scale to the longer side
	yaw = Matrix.Rotation(FACE, 3, "Z")
	three = bk.fit(cam, union, yaw @ Vector(move.get("view", (0.65, -0.75, 0.18))), MAIN[0] / MAIN[1], margin=0.9)
	front = bk.fit(cam, union, yaw @ Vector(move.get("front", (0, -1, 0.1))), FRONT[0] / FRONT[1], margin=0.9)
	span = float(np.linalg.norm(union.max(axis=0) - union.min(axis=0)))
	clip = span * 3 - span * 0.75
	marker = None
	if name == "idle":  # render-only: a bar at the low point's feet, so the rise reads
		pose_mage(rig, keys[0])
		low = float(figure_pts(rig, False)[:, 2].min())
		ends = [yaw @ Vector((x * rig.k, -0.6 * rig.k, 0)) for x in (-3.0, 3.0)]
		marker = tube([Vector((e.x, e.y, low)) for e in ends], 0.12 * rig.k, matte_mat("Marker", (0.25, 0.25, 0.3)))
		FX.objects.unlink(marker)
		scene.collection.objects.link(marker)
	cells = []
	for i, key in enumerate(keys):
		clear_fx()
		record, grip = pose_mage(rig, key)
		rig.golem.location.z = g_z
		grec = pose_golem(rig, key.get("golem") if has_golem else None, random.Random(i))
		if REWORK and not move.get("shared_frame"):  # each panel framed on its own pose, as the king's rework (the figure reads bigger)
			pts = figure_pts(rig, has_golem and key.get("golem") is not None, mage_on=not solo)
			three = bk.fit(cam, pts, yaw @ Vector(key.get("view", move.get("view", (0.65, -0.75, 0.18)))), MAIN[0] / MAIN[1], margin=0.85)
			front = bk.fit(cam, pts, yaw @ Vector(move.get("front", (0, -1, 0.1))), FRONT[0] / FRONT[1], margin=0.85)
			sp = float(np.linalg.norm(pts.max(axis=0) - pts.min(axis=0)))
			clip = sp * 3 - sp * 0.75
		build_fx(rig, key.get("fx", []), seed=100 + i)
		kind = move.get("window") if isinstance(move.get("window"), str) else name
		dark = kind in ("lightning", "barrage")
		look(scene, rig, key.get("look") or (("dark" if kind == "lightning" else "darkblue") if dark else "flat"), floor=has_golem)
		cell = {}
		wide_only = [o for o in FX.objects if o.get("wide_only") or (key.get("look") == "flash" and o.type == "LIGHT")]  # flash: no effect light on her, a silhouette
		for o in wide_only:  # halos are for the room-scale view; close up they bury her
			o.hide_render = True
		for view, size, tag in ((three, MAIN, "main"), (front, FRONT, "front")):
			cam.location, cam.rotation_euler, cam.data.ortho_scale = view
			cam.data.type, cam.data.sensor_fit = "ORTHO", "AUTO"
			cam.data.clip_start = clip  # only what is round her: room-wide effects in front of her stay out of the close views
			cell[tag] = shot(scene, os.path.join(TMP, f"{name}_{i}_{tag}.png"), size)
		for o in wide_only:
			o.hide_render = False
		if key.get("arena"):
			look(scene, rig, key["arena"])
			player_view(cam)
			cell["wide"] = shot(scene, os.path.join(TMP, f"{name}_{i}_wide.png"), WIDE)
			# a full-size copy of the wide view, for checking
			shot(scene, os.path.join(TMP, f"{name}_{i}_wide_big.png"), (1280, 720))
		cells.append(cell)
		rec = {"t": key["t"], "caption": key["cap"]}
		if not solo:
			rec.update({"root_offset": list(key.get("root", (0, 0, 0))), "rotations": record, "staff_grip_offset": grip})
		if "look" in key:
			rec["look"] = key["look"]
		for f in ("hold", "event"):
			if f in key:
				rec["hold_until" if f == "hold" else f] = key[f]
		rec["effects"] = key.get("fx", [])
		if has_golem and not move.get("golem_context"):
			rec["golem"] = grec
			if grec:
				rec["golem_root_z"] = round((rig.golem.location.z - g_z) / rig.kg, 3)
		records.append(rec)
	win = window_row(scene, rig, move) if isinstance(move.get("window"), str) else None
	clear_fx()
	rig.golem.location.z = g_z
	for o, h in hidden.items():
		o.hide_render = h
	if marker:
		bpy.data.objects.remove(marker, do_unlink=True)
	sheet(name, move, cells, win)
	return records


def sheet(name, move, cells, win=None):
	keys = move["keys"]
	COLS = move.get("cols", 3)  # noqa: N806  (the old sheets: 3 a row)
	rows = math.ceil(len(keys) / COLS)
	cell_h = MAIN[1] + STRIP_H
	win_h = 60 + 40 + WIN[1] + 8 + MAP + 16 if win else 0
	px = np.ones((HEAD_H + rows * cell_h + 8 + win_h, COLS * CELL_W, 4), dtype=np.float32)
	px[:, :, :3] = bk.BG
	total = f"{move['end']:.1f} s" + (" loop" if move.get("loop") else "")
	note = f"Times proposed. Wide views: colosseum draft from a runner's camera on lane 4, her at {SIZE:g}x a runner ({SIZE * CHAR_H:g} studs), feet {HOVER:g} studs up"
	if "golem" in name or move.get("golem_context"):
		note += f", golem {GOLEM_RATIO}x her height"
	if move.get("extends"):
		note += f". Times on the {move['extends']} clock: these keys follow its approved key 4 (2.00 s); its recover key moves 2.0 s later"
	if name == "idle" and not REWORK:
		note += ". Dark bar: her feet at the low point (render mark only). Rise 1.5 studs at 4x = 0.43 model units"
	if REWORK:
		note = f"Times proposed. Jointed rig (elbows, knees, 3-segment tails), {SIZE:g}x a runner; she hovers, the 1.5-stud bob over 3 s plays in game (not keyed). Event keys in red. " + move.get("note", "")
	paste_txt = [(f"{move['title']}  |  The Elf Mage  |  {total}  |  (proposed) key frames for approval, no in-betweens", 40, 48, 24, bk.INK), (note + ".", 24, 90, 24, bk.DIM)]
	bk.paste(px, bk.text_px(paste_txt, COLS * CELL_W, HEAD_H, bk.BG), 0, 0)
	for i, key in enumerate(keys):
		row, col = divmod(i, COLS)
		x, y = col * CELL_W, HEAD_H + row * cell_h
		bk.paste(px, cells[i]["main"], x, y)
		bk.small_view(px, cells[i]["front"], x + MAIN[0], y, "front")
		if "wide" in cells[i]:
			bk.small_view(px, cells[i]["wide"], x + MAIN[0], y + 32 + FRONT[1] + 12, "arena view (runner's camera)")
		head = (f"{name}  key {i + 1} of {len(keys)}   " if REWORK else f"{i + 1}   ") + f"{key['t']:.2f} s" + (f" - {key['hold']:.2f} s" if "hold" in key else "") + (f"   event {key['event']}" + (" (HIT)" if REWORK else "") if "event" in key else "")
		cap = key["cap"]
		if len(cap) > 100:  # two lines: a long caption runs off the cell
			cut = cap.rfind(" ", 0, len(cap) // 2 + 10)
			lines = [(cap[:cut], 21, 66, 18, bk.DIM), (cap[cut + 1 :], 21, 90, 18, bk.DIM)]
		else:
			lines = [(cap, 28, 80, 18, bk.DIM)]
		bk.paste(px, bk.text_px([(head, 34, 40 if len(cap) <= 100 else 34, 18, (0.75, 0.05, 0.05) if "event" in key and REWORK else bk.INK)] + lines, CELL_W, STRIP_H, bk.BG), x, y + MAIN[1])
		px[y : y + cell_h, x : x + 2] = (0.5, 0.5, 0.52, 1)
	if win:
		y0 = HEAD_H + rows * cell_h + 8
		what = "bolts strike on spots marked 0.5 s before (white core); last strikes fade" if move["window"] == "lightning" else "circles stay open; beams hit random floor spots; last beams fade"
		bk.paste(px, bk.text_px([(f"The 2 s window from {move['window_start']:.2f} s, timing draft (proposed): {what}", 34, 40, 18, bk.INK)], COLS * CELL_W, 60, bk.BG), 0, y0)
		pw = COLS * CELL_W // 5
		for k, (t, lines, wide, top) in enumerate(win):
			x, y = k * pw, y0 + 60
			bk.paste(px, bk.text_px([(f"window {t:.1f} s   (move {move['window_start'] + t:.2f} s)", 22, 28, 10, bk.INK)], pw, 40, bk.BG), x, y)
			bk.paste(px, wide, x, y + 40)
			bk.paste(px, top, x, y + 40 + WIN[1] + 8)
			txt = [("top view", 18, 26, 12, bk.DIM)] + [(s, 19, 70 + 34 * j, 12, bk.INK) for j, s in enumerate(lines)] + [("runner's side at the bottom", 16, MAP - 20, 12, bk.DIM)]
			bk.paste(px, bk.text_px(txt, pw - MAP, MAP, bk.BG), x + MAP, y + 40 + WIN[1] + 8)
			px[y : y + win_h - 60, x : x + 2] = (0.5, 0.5, 0.52, 1)
	path = os.path.join(OUT, name + "_slices.png")
	bk.save_px(px, path)
	print("SHEET", path)


def overview():
	"""Every move's main views at half size, one row per move."""
	w, h = MAIN[0] // 2, MAIN[1] // 2
	moves = {n: MOVES[n] for n in APPROVED}  # the approved overview stays as it is
	cols = max(len(m["keys"]) for m in moves.values())
	row_h = h + 50 + 56
	px = np.ones((90 + row_h * len(moves), cols * w, 4), dtype=np.float32)
	px[:, :, :3] = bk.BG
	bk.paste(px, bk.text_px([("The Elf Mage: all moves, (proposed) key frames for approval, no in-betweens", 36, 54, 20, bk.INK)], cols * w, 90, bk.BG), 0, 0)
	for r, (name, move) in enumerate(moves.items()):
		y = 90 + r * row_h
		bk.paste(px, bk.text_px([(f"{move['title']}  ({move['end']:.1f} s)", 30, 40, 16, bk.INK)], cols * w, 50, bk.BG), 0, y)
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


# ---- the animation rework: the jointed rig (--rework) ----

JPARTS = ("Torso", "Head", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg")
ELBOW = {"LeftArm": Vector((1.5, 0, 3.1)), "RightArm": Vector((-1.5, 0, 3.1))}  # build_boss_king.SEAM: the R15 seams
KNEE = {"LeftLeg": Vector((0.5, 0, 1.1)), "RightLeg": Vector((-0.5, 0, 1.1))}
POLE = {"LeftArm": (0.6, 1, -0.3), "RightArm": (-0.6, 1, -0.3)}  # elbows out and back unless a key says otherwise
SEG = {"RightArm": ("RightUpperArm", "RightLowerArm"), "LeftArm": ("LeftUpperArm", "LeftLowerArm"), "LeftLeg": ("LeftUpperLeg", "LeftLowerLeg"), "RightLeg": ("RightUpperLeg", "RightLowerLeg")}
TAILS = {"TailL": ("TailL1", "TailL2", "TailL3"), "TailR": ("TailR1", "TailR2", "TailR3")}
TPIV = {}  # tail segment pivots, model space: read from boss_mage_jointed.blend at load
GRIP2 = 1.1  # the left fist this far up the shaft from the right one, model units (negative: below it)
JPARENT = {"Body": None, "Torso": "Body", "Head": "Torso", "Staff": "RightLowerArm"}
for _limb, (_up, _lo) in SEG.items():
	JPARENT[_up], JPARENT[_lo] = ("Torso" if _limb.endswith("Arm") else "Body"), _up
for _t, _segs in TAILS.items():
	JPARENT[_segs[0]], JPARENT[_segs[1]], JPARENT[_segs[2]] = "Head", _segs[0], _segs[1]


def jsolve(key):
	"""jointed rig: placement per part (model space, applied on top of its rest), the local rotations for keys.json, the staff
	grip offset in the right forearm's space, and how far each hand stops short of its aim (model units)."""
	import boss_king_keyframes as kk  # two_bone (imported here: that module imports this one)

	place = {}
	yaw = Matrix.Rotation(math.radians(key.get("body", (0, 0, 0))[2]), 3, "Z")
	place["Body"] = Matrix.Translation(key.get("root", (0, 0, 0))) @ about(HIP, eul(key.get("body", (0, 0, 0))))
	place["Torso"] = place["Body"] @ about(WAIST, eul(key.get("torso", (0, 0, 0))))
	place["Head"] = place["Torso"] @ about(NECK, eul(key.get("head", (0, 0, 0))))
	short = {}

	def put(name, parent, pivot, r3):
		at = place[parent] @ Vector(pivot)
		place[name] = Matrix.Translation(at) @ r3.to_4x4() @ Matrix.Translation(-Vector(pivot))

	for t, segs in TAILS.items():
		spec = key.get(t, (0, 0, 0))
		spec = [spec] if isinstance(spec[0], (int, float)) else spec
		parent = "Head"
		for n, e in zip(segs, list(spec) + [(0, 0, 0)] * 3):
			place[n] = place[parent] @ about(TPIV[n], eul(e))
			parent = n

	def arm(limb, target=None):
		up, lo = SEG[limb]
		spec = key.get(limb, {})
		tw = place["Torso"]
		if target is None and isinstance(spec, dict) and "aim" in spec:
			target = tw @ Vector(spec["aim"])
		if target is not None:
			pole = tw.to_3x3() @ Vector(spec.get("pole", POLE[limb]) if isinstance(spec, dict) else POLE[limb])
			J = tw @ Vector(SHOULDER[limb])
			r1, r2 = kk.two_bone(J, SHOULDER[limb][2] - ELBOW[limb].z, ELBOW[limb].z - HAND[limb].z, target, pole)
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

	staff = key.get("staff", ONE)
	left = key.get("LeftArm")
	if staff == "two":  # both fists aimed; the shaft runs from the right one through the left one
		arm("RightArm")
		arm("LeftArm")
		low, high = place["RightLowerArm"] @ HAND["RightArm"], place["LeftLowerArm"] @ HAND["LeftArm"]
		place["Staff"] = Matrix.Translation(low) @ Vector((0, 0, 1)).rotation_difference((high - low).normalized()).to_matrix().to_4x4() @ Matrix.Translation(-GRIP)
	else:
		arm("RightArm")
		if isinstance(staff, dict):
			r = Vector((0, 0, 1)).rotation_difference(yaw @ Vector(staff["dir"]).normalized()).to_matrix().to_4x4()
			place["Staff"] = Matrix.Translation(place["RightLowerArm"] @ HAND["RightArm"]) @ r @ Matrix.Translation(-GRIP)
		else:
			place["Staff"] = place["RightLowerArm"] @ Matrix.Translation(HAND["RightArm"] - GRIP) @ about(GRIP, eul(staff))
		if left == "grip" or (isinstance(left, dict) and "grip" in left):
			s = GRIP2 if left == "grip" else left["grip"]
			arm("LeftArm", place["Staff"] @ (GRIP + Vector((0, 0, s))))
		else:
			arm("LeftArm")
	local = place["RightLowerArm"].inverted() @ place["Staff"]
	grip = [round(v, 4) for v in (local @ GRIP) - GRIP]
	for limb in ("LeftLeg", "RightLeg"):
		leg(limb)
	record = {}
	for n, par in JPARENT.items():
		if n in place:
			r = place[n].to_3x3() if par is None else place[par].to_3x3().inverted() @ place[n].to_3x3()
			record[n] = degs(r.to_4x4())
	m = {(n if n == "Staff" or n.startswith("Tail") else n + "_merged"): v for n, v in place.items() if n != "Body"}
	return m, record, grip, short


def mirror(tail):
	"""TailR from TailL's Eulers: the same swing, mirrored across her centre line."""
	return [(x, -y, -z) for x, y, z in tail]


def fx_point(rig, arg, rng, gem):
	"""Clip 2: a bright point with a cross flare at the staff tip (arg: size, default 1)."""
	k, g = rig.k, float(arg or 1)
	yaw = Matrix.Rotation(FACE, 3, "Z")
	ball(gem, 0.13 * k * g, glow_mat("PointCore", WHITE, 40))
	ball(gem, 0.32 * k * g, glow_mat("PointGlow", (0.85, 0.7, 1.0), 2, 0.25))
	for d, ln in ((yaw @ Vector((1, 0, 0)), 1.6), (Vector((0, 0, 1)), 1.6), (yaw @ Vector((1, 0, 1)).normalized(), 0.6), (yaw @ Vector((1, 0, -1)).normalized(), 0.6)):
		tube([gem - d * ln * k * g, gem + d * ln * k * g], 0.016 * k * g, glow_mat("PointRay", WHITE, 12))
	lamp(gem, (0.85, 0.7, 1.0), 1e4 * g * (SIZE / 4) ** 2, 2)


def fx_flash(rig, arg, rng, gem):
	"""The arena-wide white flash on the first strike (owner 2026-11-12): a white veil round the whole room in the wide view; the
	close views use look "flash" (a white-out, she a dark silhouette, clip 2)."""
	veil = ball(Vector((0, 0, 0)), 900, glow_mat("FlashVeil", (1.0, 0.96, 1.0), 6, 0.6))
	veil["wide_only"] = True


def fx_cast(rig, arg, rng, gem):
	"""Clip 2: thick white-violet lightning from the staff tip along the levelled shaft into the room, with forks (arg: 'fade')."""
	staff = rig.parts["Staff"].matrix_world
	d = (staff.to_3x3() @ Vector((0, 0, 1))).normalized()
	t = min(-gem.z / d.z if d.z < -1e-3 else 1e9, 150 * SIZE / 8)
	end = gem + d * t
	s = SIZE / 4
	if arg == "fade":
		tube(jag(gem, end, 10, 2 * s, rng), 0.5 * s, glow_mat("BoltFade", (0.62, 0.08, 1.0), 0.8, 0.3))
		return
	bolt(gem, end, 1.1 * s, rng, branches=4, lamp_w=1.5e5)
	bolt(gem, end + Vector((rng.uniform(-12, 12), rng.uniform(-12, 12), -6)) * s, 0.6 * s, rng, branches=2)
	ball(gem, 0.5 * rig.k, glow_mat("OrbCore", WHITE, 50))
	ball(gem, 0.6 * rig.k, glow_mat("OrbGlow", VIOLET, 3, 0.35))


JFX = {"point": fx_point, "flash": fx_flash, "cast": fx_cast}


# The rework keys (proposed; owner pre-approval of the rework 2026-11-12, slices still shown). Root offsets in model units from the
# hover height (1 unit = about 7 studs at 8x). Hands and staff are in her torso's and body's frames; tails trail a beat behind.
TL0 = [(-4, -26, 0), (6, -6, 0), (8, -6, 0)]
IDLE0 = {"root": (0, 0, 0), "body": (0, 0, 0), "torso": (8, 0, 2), "head": (-4, 0, -4), "RightArm": {"aim": (-0.85, -1.05, 2.6)}, "LeftArm": {"aim": (0.85, -1.1, 3.45)}, "staff": "two", "TailL": TL0, "TailR": mirror(TL0), "LeftLeg": {"hip": (22, 0, -3), "knee": 28}, "RightLeg": {"hip": (10, 0, 3), "knee": 42}}
BRACE = {"RightArm": {"aim": (-1.35, -1.25, 3.2), "pole": (-0.6, 0.6, -1)}, "staff": {"dir": (-1, -0.42, 0.04)}, "LeftArm": {"grip": -1.45}}
JMOVES = {
	"lightning": {
		"title": "Purple lightning (rework, jointed rig): cast, a 2 s storm of 14 strikes, recover",
		"end": 5.2,
		"cols": 5,
		"strikes": [2.0, 4.0],
		"note": "Dodge bar before the strikes; cost event Lightning at 2.00 s (HIT, red); strike window 2.00 - 4.00 s, a strike every 0.15 s (14); the lead-in lightning_in is generated. Arena views: colosseum draft from a runner's camera on lane 4.",
		"keys": [
			{"t": 0.0, "cap": "Idle key 0: hovering, staff across the body in both hands, tails loose, legs hang", **IDLE0},
			{"t": 0.45, "cap": "Anticipation: staff drawn back and up over her right shoulder, body coils right and dips, knees tuck; tails still swing the old way", "root": (0, 0.05, -0.3), "body": (0, 0, -10), "torso": (16, -4, -22), "head": (8, 0, 22), "RightArm": {"aim": (-2.0, 0.85, 4.35), "pole": (-0.3, 0.2, -1)}, "staff": {"dir": (-0.35, 0.75, 1)}, "LeftArm": {"aim": (1.25, -1.45, 3.3)}, "TailL": [(-20, -34, 8), (-12, -10, 0), (-10, -6, 0)], "TailR": [(-8, 44, -6), (-14, 14, 0), (-12, 8, 0)], "LeftLeg": {"hip": (-32, 0, -4), "knee": 75}, "RightLeg": {"hip": (-12, 0, 6), "knee": 55}},
			{"t": 0.95, "cap": "Cast raise, overshoot: staff thrust up past the top on a straight arm, chest arched, left arm flung out; bright point and cross flare at the tip", "fx": ["point:1.2"], "root": (0.05, 0.05, 0.5), "body": (0, 0, 6), "torso": (-16, 4, 10), "head": (-24, 0, -6), "RightArm": {"aim": (-1.25, 0.3, 5.6)}, "staff": {"dir": (0.12, 0.38, 1)}, "LeftArm": {"aim": (2.95, -0.55, 3.0)}, "TailL": [(12, -14, 0), (8, -4, 0), (6, -2, 0)], "TailR": [(16, 10, 0), (10, 4, 0), (8, 2, 0)], "LeftLeg": {"hip": (12, 0, -6), "knee": 12}, "RightLeg": {"hip": (26, 0, 8), "knee": 32}},
			{"t": 1.4, "cap": "Settle: staff back upright, she sinks a little, left hand braced out; the charge crackles at the point; tails fling up and out", "fx": ["point", "charge"], "root": (0, 0, 0.3), "body": (0, 0, 2), "torso": (-6, 2, 4), "head": (-14, 0, -2), "RightArm": {"aim": (-1.4, -0.15, 5.35)}, "staff": {"dir": (0.02, 0.05, 1)}, "LeftArm": {"aim": (2.3, -1.15, 2.75)}, "TailL": [(-22, -50, 6), (-10, -12, 0), (-6, -8, 0)], "TailR": [(-18, 56, -4), (-10, 14, 0), (-4, 8, 0)], "LeftLeg": {"hip": (6, 0, -4), "knee": 32}, "RightLeg": {"hip": (18, 0, 6), "knee": 48}},
			{"t": 1.8, "cap": "Brace (Dodge bar ends): turns side-on, staff levelled at the arena in both hands, leans into it, legs split; hair and tails blown back", "fx": ["point:1.4"], "root": (0, -0.15, 0.15), "body": (0, 0, 48), "torso": (14, 6, -6), "head": (-6, 0, -34), **BRACE, "TailL": [(38, -22, 0), (14, -4, 0), (10, -2, 0)], "TailR": [(44, 30, 0), (16, 6, 0), (12, 4, 0)], "LeftLeg": {"hip": (26, 0, -6), "knee": 55}, "RightLeg": {"hip": (-34, 0, 8), "knee": 62}},
			{"t": 2.0, "event": "Lightning", "look": "flash", "arena": "violet", "cap": "HIT, strike 1 of 14: the arena flashes white; lightning bursts from the tip, the recoil kicks her back and tips the staff up; tails snap back", "fx": ["flash", "cast", "strike"], "root": (0, 0.25, 0.2), "body": (0, 0, 44), "torso": (2, 10, -2), "head": (-14, 0, -30), **BRACE, "staff": {"dir": (-1, -0.42, 0.2)}, "TailL": [(60, -18, 0), (20, 0, 0), (16, 0, 0)], "TailR": [(66, 34, 0), (22, 6, 0), (16, 4, 0)], "LeftLeg": {"hip": (34, 0, -8), "knee": 70}, "RightLeg": {"hip": (-24, 0, 8), "knee": 48}},
			{"t": 2.6, "arena": "violet", "cap": "Strike 5: she drives back against the recoil, staff tracks left across the room, weight forward; tails whip to her right", "fx": ["cast", "sustain"], "root": (0.1, -0.1, 0.1), "body": (0, 0, 70), "torso": (18, 2, -10), "head": (-4, 0, -40), **BRACE, "staff": {"dir": (-1, -0.32, -0.05)}, "TailL": [(30, -4, 10), (14, 6, 0), (12, 6, 0)], "TailR": [(52, 54, -10), (24, 14, 0), (18, 8, 0)], "LeftLeg": {"hip": (18, 0, -4), "knee": 40}, "RightLeg": {"hip": (-40, 0, 6), "knee": 75}},
			{"t": 3.35, "arena": "violet", "cap": "Strike 10: hips swing the staff back across to her right, low and level, torso twisted against it; tails whip the other way", "fx": ["cast", "sustain"], "root": (-0.1, 0, -0.05), "body": (0, 0, 22), "torso": (16, -6, 14), "head": (0, 0, -24), **BRACE, "staff": {"dir": (-1, -0.5, -0.12)}, "TailL": [(56, -40, -6), (24, -10, 0), (18, -6, 0)], "TailR": [(28, 6, 8), (12, -4, 0), (8, -6, 0)], "LeftLeg": {"hip": (36, 0, -10), "knee": 66}, "RightLeg": {"hip": (-20, 0, 10), "knee": 40}},
			{"t": 4.0, "cap": "Release (strikes end): she throws the staff up and away, body uncoils and floats up, legs swing through; last sparks; tails fly forward", "fx": ["cast:fade", "embers"], "root": (0, 0.15, 0.4), "body": (0, 0, 24), "torso": (-14, 4, 6), "head": (-16, 0, -12), "RightArm": {"aim": (-2.0, -0.9, 5.0)}, "staff": {"dir": (-0.55, -0.35, 1)}, "LeftArm": {"aim": (2.6, 0.6, 3.3), "pole": (0.3, 1, 0.3)}, "TailL": [(-28, -30, 0), (-16, -8, 0), (-12, -6, 0)], "TailR": [(-24, 36, 0), (-14, 10, 0), (-10, 6, 0)], "LeftLeg": {"hip": (4, 0, -4), "knee": 20}, "RightLeg": {"hip": (14, 0, 6), "knee": 30}},
			{"t": 5.2, "cap": "Recover = idle key 0: staff back across the body in both hands, settled", **IDLE0},
		],
	},
}


def rework(argv):
	"""--rework: JMOVES on the jointed rig at 8x (in game); writes keyframes/rework/keys.json and <move>_slices.png. MOVES and
	keyframes/keys.json stay."""
	global REWORK, MODEL, OUT, TMP, SIZE
	REWORK, MODEL, SIZE = True, "boss_mage_jointed", 8.0
	OUT, TMP = os.path.join(OUT, "rework"), os.path.join(TMP, "rework")
	arena = argv[argv.index("--arena") + 1] if "--arena" in argv else ARENA
	wanted = [a for a in argv if a in JMOVES] or list(JMOVES)
	for d in (OUT, TMP, bk.TMP):
		os.makedirs(d, exist_ok=True)
	scene, rig = load_scene(arena)
	print(f"SCALE size {SIZE}x: model height {rig.model_h:.3f} units, {rig.k:.3f} studs per unit")
	path = os.path.join(OUT, "keys.json")
	data = json.load(open(path)) if os.path.exists(path) else {"moves": {}}
	data.update(
		{
			"rig": "jointed (build_boss_mage.py -- jointed): Torso, Head, upper and lower arm and leg per side, 3 segments per twin tail, Staff; the lower arm carries the hand, the lower leg the foot",
			"units": "XYZ Euler degrees about each part's joint, relative to its parent; root_offset in model units from the hover height (Z = Roblox Y up)",
			"parents": JPARENT,
			"pivots": {"Body": HIP, "Torso": WAIST, "Head": NECK, "Staff": list(GRIP), **{SEG[n][0]: SHOULDER[n] for n in SHOULDER}, **{SEG[n][1]: list(ELBOW[n]) for n in ELBOW}, **{SEG[n][0]: LEG[n] for n in LEG}, **{SEG[n][1]: list(KNEE[n]) for n in KNEE}, **{n: [round(v, 4) for v in p] for n, p in TPIV.items()}},
			"staff": "Staff turns about its grip (its origin); staff_grip_offset moves the grip in the right lower arm's space, model units",
			"effects": "sketch labels per key: point[:size] (bright point and cross flare at the staff tip), charge, flash (the arena-wide white flash; look flash = the close views' white-out), cast[:fade] (lightning from the tip along the shaft), strike (bolts all over the room), sustain (the window's strikes, arena view only), embers",
			"hover": {"studs": HOVER, "bob_studs": 1.5, "bob_seconds": 3.0, "note": "proposed; the bob is played in game, not keyed; no foot plants"},
			"scale": {"studs_per_model_unit_at_8x": round(8 * CHAR_H / rig.model_h, 4), "model_height_units": round(rig.model_h, 4)},
			"approved": [],
		}
	)
	for name in wanted:
		m = JMOVES[name]
		data["moves"][name] = {"title": m["title"], "end": m["end"], "loop": m.get("loop", False), "keys": run_move(scene, rig, name, m)}
		for f in ("strikes", "events"):
			if f in m:
				data["moves"][name][f] = m[f]
	with open(path, "w") as f:
		json.dump(data, f, indent=1)
	print("KEYS", path)


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
	print(f"SCALE size {SIZE}x: her model height {rig.model_h:.3f} units, {rig.k:.3f} studs per unit; golem {rig.golem_h:.3f} units x {rig.kg:.3f}")
	path = os.path.join(OUT, "keys.json")
	data = json.load(open(path)) if os.path.exists(path) else {"moves": {}}
	data.update(
		{
			"units": "XYZ Euler degrees about each part's joint, relative to its parent; root_offset in model units (Z = Roblox Y up)",
			"parents": {"Body": None, "Torso": "Body", "LeftLeg": "Body", "RightLeg": "Body", "Head": "Torso", "LeftArm": "Torso", "RightArm": "Torso", "TailL": "Head", "TailR": "Head", "Staff": "RightArm"},
			"pivots": {"Body": HIP, "Torso": WAIST, "Head": NECK, **SHOULDER, **LEG, **TAIL, "Staff": list(GRIP)},
			"staff": "Staff turns about its grip (its origin); staff_grip_offset moves the grip in the right arm's space, model units",
			"golem": "per part: loc (golem units, parent space) and rot (degrees, XYZ), the object's own values; golem_root_z: drop of its root, golem units",
			"layout": "Move golem (the slam) stores the golem's parts per key next to her own rotations. golem_* moves hold the golem alone (no rotations of hers). lightning_window and barrage_window are sustain keys on their parent move's clock, inserted after its 2.00 s key; the parent's recover key then plays 2.0 s later. watch draws the golem for context only and records her alone.",
			"scale": {"studs_per_model_unit_at_4x": round(4 * CHAR_H / rig.model_h, 4), "model_height_units": round(rig.model_h, 4), "hover_feet_studs": HOVER, "golem_ratio": GOLEM_RATIO},
		}
	)
	for name in wanted:
		m = MOVES[name]
		data["moves"][name] = {"end": m["end"], "loop": m.get("loop", False), "keys": run_move(scene, rig, name, m)}
		if m.get("extends"):
			data["moves"][name].update({"extends": m["extends"], "after_key_t": m["window_start"], "window": [m["window_start"], m["window_start"] + 2.0]})
	with open(path, "w") as f:
		json.dump(data, f, indent=1)
	if any(n in APPROVED for n in wanted):
		overview()


if __name__ == "__main__":
	main()
