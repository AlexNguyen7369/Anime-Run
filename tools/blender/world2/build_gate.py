"""Blender draft of the World 2 gate on the World 1 plaza (design doc 4.47, docs/WORLD2_SPEC.md "Travel and gate").

The same geometry as Shared/SpawnArea.WorldGate (parts, sizes in studs), locked and open states side by side on a
patch of plaza paving, rendered to assets/world2_draft/gate/. Live (MCP): import build_gate; build_gate.run()
Headless: Blender -b --factory-startup --python tools/blender/world2/build_gate.py
"""

import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
	sys.path.insert(0, HERE)

import build_track  # noqa: E402
import kit  # noqa: E402

OUT = os.path.join(build_track.ROOT, "assets", "world2_draft", "gate")
R, SEG = 11, 16  # SpawnArea RING_RADIUS, RING_SEGMENTS
STONE, BLACK, RING = "9E988C", "221E1E", "46404F"


def gate_parts(locked, swirl):
	cy = R + 3
	parts = []
	for a in range(4):  # the octagon dais: 4 bars 45 degrees apart
		parts.append(("box", (30, 1.2, 30 * math.tan(math.pi / 8)), (0, 0.6, 0), STONE, {"rot": (0, a * 45, 0)}))
	for side in (-1, 1):
		parts.append(("box", (3.4, R * 2 + 8, 4), (side * (R + 3.5), R + 4, 0), BLACK, {"rot": (0, 0, side * 6), "rough": 0.6}))
	length = 2 * math.pi * R / SEG + 0.6
	for i in range(SEG):
		a = i / SEG * math.tau
		x, y = -math.sin(a) * R, math.cos(a) * R
		parts.append(("box", (length, 2.4, 3), (x, cy + y, 0), RING, {"rot": (0, 0, math.degrees(a))}))
		parts.append(
			("box", (length, 0.4, 3.2), (x - -math.sin(a) * 1.3, cy + y - math.cos(a) * 1.3, 0), swirl, {"rot": (0, 0, math.degrees(a)), "emit": 6})
		)
	disc = R * 2 - 1.5
	face = "4A2290" if locked else swirl  # locked: a dim, sealed portal so the chains read in front of it
	parts.append(("cyl", (disc, 0.4, disc), (0, cy, 0), face, {"rot": (90, 0, 0), "emit": 1.2 if locked else 5, "seg": 32}))
	if locked:
		for tilt in (40, -40):
			parts.append(("box", (R * 2.1, 1.4, 1.4), (0, cy, -1.2), "8C8880", {"rot": (0, 0, tilt), "metal": 0.8, "rough": 0.4}))
		parts.append(("box", (5, 5.6, 1.8), (0, cy - 0.8, -2.2), "D6A83C", {"metal": 1, "rough": 0.35}))
		parts.append(("box", (3.2, 3, 1), (0, cy + 3, -2.2), "A0A0A0", {"metal": 1, "rough": 0.35}))
	return parts


def run(render=True):
	bpy.ops.wm.read_homefile(use_empty=True)
	cam = build_track.setup(fast=False)
	track = {"Number": 0, "Width": 36, "Waypoints": [[-60, 1, 0], [60, 1, 0]]}
	k = kit.Kit(track, "Gate")
	k.prop("WorldGateLocked", gate_parts(True, "9646FF"))
	k.prop("WorldGateOpen", gate_parts(False, "46D2FF"))
	k.place("WorldGateLocked", (-25, 1, 0), 0)
	k.place("WorldGateOpen", (25, 1, 0), 0)
	k.ground("CDBB9E", margin=120, y=1.0)  # plaza paving (SpawnArea Floor colour)
	k.sky([(0.0, "FFD9A8"), (0.1, "FFC890"), (0.6, "86A6DC")], strength=1.0, sun=(3.2, "FFD19E", 35, -30))
	k.light((-25, R + 3, -4), "9646FF", energy=8000, radius=4)
	k.light((25, R + 3, -4), "46D2FF", energy=8000, radius=4)
	for ob in k.lib.objects:
		ob.data.calc_loop_triangles()
		print("ASSET", ob.name, len(ob.data.loop_triangles))
	bpy.ops.wm.save_as_mainfile(filepath=os.path.join(build_track.BUILD, "world_gate.blend"), copy=True)
	if render:
		os.makedirs(OUT, exist_ok=True)
		build_track.shoot(cam, (0, 14, -75), (0, 12, 0), os.path.join(OUT, "01_both_front.jpg"), 50)
		build_track.shoot(cam, (-25, 7, -32), (-25, 14, 0), os.path.join(OUT, "02_locked_close.jpg"), 60)
		build_track.shoot(cam, (40, 22, -50), (0, 10, 0), os.path.join(OUT, "03_three_quarter.jpg"), 55)


if __name__ == "__main__":
	run()
