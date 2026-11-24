"""World 2 road chain for the Blender drafts (design doc 4.47, docs/WORLD2_SPEC.md "Blender first").

Plain Python (no bpy): a port of Shared/TrackBuilder.Layout and the Main.server chaining, so every Blender draft sits
on the exact road the game builds. Reads src/shared/Tracks/World2/*.luau, writes build/world2/chain.json with each
track's centre-line waypoints in Roblox world coordinates (studs, Y up). Run: python3 tools/blender/world2/chain.py
"""

import glob
import json
import math
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TRACKS = os.path.join(ROOT, "src", "shared", "Tracks", "World2")
OUT = os.path.join(ROOT, "build", "world2", "chain.json")
# Committed sample for the biome harness's CHAIN PARITY (build/ is gitignored): per track its waypoint count and every
# CHECK_STEP-th waypoint plus the last. Rewritten by main(); regenerate after any World 2 track change.
CHECK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chain_check.json")
CHECK_STEP = 8
ORIGIN = (-118.0, 1.0, 80.0)  # TrackBuilder.CHAIN_ORIGIN, heading 0
TURN_STEP_DEG, WAYPOINT_SPACING, SLOPE_STEP = 6, 12, 8


def fwd(h):
	return (-math.sin(h), 0.0, -math.cos(h))


def left(h):
	return (-math.cos(h), 0.0, math.sin(h))


def add(a, b, k=1.0):
	return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


def parse(path):
	src = open(path).read()
	spec = {
		"Name": re.search(r'Name = "(\w+)"', src).group(1),
		"Number": int(re.search(r"Number = (\d+)", src).group(1)),
		"Biome": re.search(r'Biome = "(\w+)"', src).group(1),
		"Width": float(re.search(r"Width = ([\d.]+)", src).group(1)),
		"Palette": dict(re.findall(r'(\w+) = Color3\.fromHex\("(\w+)"\)', src)),
		"Segments": [],
	}
	for body in re.findall(r"\{ (Type = [^}]*)\}", src[src.index("Segments"):]):
		seg = {"Type": re.search(r'Type = "(\w+)"', body).group(1)}
		for key, value in re.findall(r"(Length|Angle|Radius|Rise) = (-?[\d.]+)", body):
			seg[key] = float(value)
		spec["Segments"].append(seg)
	return spec


def layout(spec):
	"""Local waypoints and end pose, as TrackBuilder.Layout (Straight, Turn, Slope; World 2 has no Loop)."""
	pos, heading, length = (0.0, 0.0, 0.0), 0.0, 0.0
	wps = [pos]
	for seg in spec["Segments"]:
		kind = seg["Type"]
		if kind == "Straight":
			d, n = fwd(heading), max(1, math.ceil(seg["Length"] / WAYPOINT_SPACING))
			for i in range(1, n + 1):
				wps.append(add(pos, d, seg["Length"] * i / n))
			pos = add(pos, d, seg["Length"])
			length += seg["Length"]
		elif kind == "Turn":
			theta, r = math.radians(seg["Angle"]), seg["Radius"]
			s = 1 if theta >= 0 else -1
			centre = add(pos, left(heading), r * s)
			n = max(1, math.ceil(abs(seg["Angle"]) / TURN_STEP_DEG), math.ceil(abs(theta) * r / WAYPOINT_SPACING))
			for i in range(1, n + 1):
				wps.append(add(centre, left(heading + theta * i / n), -r * s))
			pos = wps[-1]
			heading += theta
			length += abs(theta) * r
		elif kind == "Slope":
			run, rise = seg["Length"], seg["Rise"]
			d, n = fwd(heading), max(2, math.ceil(run / SLOPE_STEP))
			start = pos
			for i in range(1, n + 1):
				t = i / n
				p = add(start, d, run * t)
				wps.append((p[0], p[1] + rise * (1 - math.cos(math.pi * t)) / 2, p[2]))
			pos = wps[-1]
			length += math.hypot(run, rise)
		else:
			raise ValueError("unknown segment " + kind)
	return wps, pos, heading, length


def to_world(origin, yaw, p):
	"""origin * CFrame.Angles(0, yaw, 0) applied to local p (Roblox: rotation about +Y)."""
	c, s = math.cos(yaw), math.sin(yaw)
	return (origin[0] + p[0] * c + p[2] * s, origin[1] + p[1], origin[2] - p[0] * s + p[2] * c)


def build():
	specs = sorted((parse(p) for p in glob.glob(os.path.join(TRACKS, "*.luau"))), key=lambda s: s["Number"])
	origin, yaw, out = ORIGIN, 0.0, []
	for spec in specs:
		wps, end, end_heading, length = layout(spec)
		target = 984 * 3 * 1.25 ** (spec["Number"] - 1)  # TRACKS_AND_BIOMES_SPEC "Lengths"
		out.append(
			{
				"Name": spec["Name"],
				"Number": spec["Number"],
				"Biome": spec["Biome"],
				"Width": spec["Width"],
				"Palette": spec["Palette"],
				"Length": round(length, 1),
				"Target": round(target, 1),
				"Waypoints": [[round(v, 2) for v in to_world(origin, yaw, p)] for p in wps],
			}
		)
		origin, yaw = to_world(origin, yaw, end), yaw + end_heading
	return out


def main():
	chain = build()
	for t in chain:
		off = abs(t["Length"] - t["Target"]) / t["Target"]
		assert off <= 0.05, "%s length %.0f vs target %.0f" % (t["Name"], t["Length"], t["Target"])
		print("%2d %-16s %-14s %7.0f studs (target %7.0f) %5d waypoints" % (t["Number"], t["Name"], t["Biome"], t["Length"], t["Target"], len(t["Waypoints"])))
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	json.dump(chain, open(OUT, "w"))
	check = []
	for t in chain:
		w = t["Waypoints"]
		idx = sorted(set(range(0, len(w), CHECK_STEP)) | {len(w) - 1})
		check.append({"Number": t["Number"], "Count": len(w), "Step": CHECK_STEP, "Points": [[round(c, 3) for c in w[i]] for i in idx]})
	json.dump(check, open(CHECK, "w"), separators=(",", ":"))
	print("wrote", OUT, "and", CHECK)


if __name__ == "__main__":
	main()
