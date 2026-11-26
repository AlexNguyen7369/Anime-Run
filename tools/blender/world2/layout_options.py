"""World 2 wide-layout proposal (docs/proposals/W2_WIDE_LAYOUT.md): measures the current chain and three wider options.

Offline only; changes no game file. Needs numpy, scipy and matplotlib (not the plain-Python rule of chain.py), e.g.
`uv venv v && uv pip install -p v/bin/python numpy scipy matplotlib && v/bin/python tools/blender/world2/layout_options.py`.
Chains every layout exactly as chain.py / TrackBuilder.Layout do (CHAIN_ORIGIN, heading 0, each track on the previous
finish). Plan view only: an option's segments are level Straights and Turns; hills (Slope) can sit inside its straights
later without changing the plan. Writes assets/world2_draft/layout_options/*.png and layout_options.json.
"""

import json
import math
import os
import sys

import numpy as np
from scipy.spatial import cKDTree

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chain  # noqa: E402

OUT = os.path.join(chain.ROOT, "assets", "world2_draft", "layout_options")
ROAD_HALF = 20.0  # every World 2 track is Width 40
BAND = (ROAD_HALF + 24.0, ROAD_HALF + 100.0)  # prop band: 24 studs clear of the road (CLEARANCE) out to ~100
JOINT_SKIP = 1200.0  # adjacent tracks: ignore point pairs less than this far apart along the chain through their joint
PLAZA_R = 146.0  # spawn floor 188 x 220 at the origin, as a circle (half diagonal)
STEP = 4.0
TARGETS = [round(984 * 3 * 1.25 ** (n - 1), 1) for n in range(1, 11)]  # TRACKS_AND_BIOMES_SPEC "Lengths"
TARGET_GAP = 600.0  # owner 2026-11-26: smallest road-to-road gap to any other track


def S(length):
	return {"Type": "Straight", "Length": float(length)}


def T(angle, radius):
	return {"Type": "Turn", "Angle": float(angle), "Radius": float(radius)}


def seg_len(seg):
	if seg["Type"] == "Turn":
		return abs(math.radians(seg["Angle"])) * seg["Radius"]
	if seg["Type"] == "Slope":
		return math.hypot(seg["Length"], seg["Rise"])
	return seg["Length"]


def cut(plan, lengths):
	"""Cuts one continuous plan into tracks of exactly `lengths`, each starting and ending on a level straight >= 40.
	A cut inside a straight (40+ either side) costs nothing; anywhere else a 40-stud straight is inserted."""
	plan = [dict(s) for s in plan]
	i, tracks = 0, []
	for L in lengths:
		segs, need = [], L
		if not (plan[i]["Type"] == "Straight" and plan[i]["Length"] >= 40):
			segs.append(S(40))
			need -= 40
		while need > 1e-6:
			cur = plan[i]
			l = seg_len(cur)
			if cur["Type"] == "Straight" and l >= need + 40 and need >= 40:
				segs.append(S(need))
				cur["Length"] = l - need
				need = 0
			elif cur["Type"] == "Straight" and abs(l - need) < 1e-6 and need >= 40:
				segs.append(S(need))
				i += 1
				need = 0
			elif l < need - 40:
				segs.append(dict(cur))
				need -= l
				i += 1
			else:  # end here: take need - 40 of this piece, then a 40 straight
				take = need - 40
				if cur["Type"] == "Straight":
					cur["Length"] = l - take
					segs.append(S(take + 40))
				else:
					sign = 1 if cur["Angle"] >= 0 else -1
					a = math.degrees(take / cur["Radius"])
					segs.append(T(sign * a, cur["Radius"]))
					cur["Angle"] = sign * (abs(cur["Angle"]) - a)
					if abs(cur["Angle"]) < 1e-9:
						i += 1
					segs.append(S(40))
				need = 0
		segs = [s for s in segs if seg_len(s) > 1e-6]
		tracks.append(segs)
	return tracks


# ---- options -----------------------------------------------------------------------------------------------------


def option_a(pitch=740.0, r0=450.0):
	"""(a) Same spiral form, wide lap pitch: an Archimedean spiral of right-hand 6 degree arcs around the plaza."""
	plan, turned = [], 0.0
	while sum(seg_len(s) for s in plan) < sum(TARGETS) + 5000:
		r = r0 + pitch * math.radians(turned + 3) / (2 * math.pi)
		plan.append(T(-6, r))
		turned += 6
	return cut(plan, TARGETS)


def option_b(pitch=780.0, bend_r=2000.0, bend_a=8.0):
	"""(b) Wide zigzag (serpentine): one long straight row per track with gentle S-bends, a 180 degree turn of radius
	pitch / 2 at its end into the next row; rows stack away from the plaza, alternate direction."""
	tracks = []
	for n, L in enumerate(TARGETS, 1):
		u = math.pi * pitch / 2 if n < 10 else 0.0
		body = L - 80 - u
		s_len = bend_r * math.radians(4 * bend_a)
		nb = max(0, int(body // 3200))
		straight = (body - nb * s_len) / (nb + 1)
		segs = [S(40 + straight)]
		for _ in range(nb):
			segs += [T(bend_a, bend_r), T(-2 * bend_a, bend_r), T(bend_a, bend_r), S(straight)]
		if n < 10:
			segs.append(T(-180 if n % 2 == 1 else 180, pitch / 2))
		segs.append(S(40))
		merged = []
		for s in segs:
			if merged and s["Type"] == "Straight" and merged[-1]["Type"] == "Straight":
				merged[-1] = S(merged[-1]["Length"] + s["Length"])
			else:
				merged.append(s)
		tracks.append(merged)
	return tracks


def option_c(pitch=760.0, first=900.0, corner=420.0):
	"""(c) Square spiral of long straights: right-hand 90 degree corners of radius `corner`, sides a, a, a+p, a+p, ...
	so every lap sits `pitch` outside the last; straights up to ~7,000 studs."""
	plan, k, sides = [], 0, []
	while sum(sides) < sum(TARGETS) + 8000:
		sides.append(first + pitch * (k // 2))
		k += 1
	for j, a in enumerate(sides):
		lead = corner if j > 0 else 0.0
		plan.append(S(a - lead - corner))
		plan.append(T(-90, corner))
	return cut(plan, TARGETS)


def current():
	import glob

	specs = sorted((chain.parse(p) for p in glob.glob(os.path.join(chain.TRACKS, "*.luau"))), key=lambda s: s["Number"])
	return [s["Segments"] for s in specs]


# ---- measuring ---------------------------------------------------------------------------------------------------


def world(tracks):
	origin, yaw, out = chain.ORIGIN, 0.0, []
	for segs in tracks:
		wps, end, end_heading, length = chain.layout({"Segments": segs})
		w = np.array([chain.to_world(origin, yaw, p) for p in wps])[:, [0, 2]]
		out.append({"xy": resample(w), "length": length, "segs": segs})
		origin, yaw = chain.to_world(origin, yaw, end), yaw + end_heading
	return out


def resample(w):
	d = np.r_[0, np.cumsum(np.hypot(*np.diff(w, axis=0).T))]
	s = np.arange(0, d[-1], STEP)
	s = np.r_[s, d[-1]]
	return np.c_[np.interp(s, d, w[:, 0]), np.interp(s, d, w[:, 1])]


def arc(xy):
	return np.r_[0, np.cumsum(np.hypot(*np.diff(xy, axis=0).T))]


def min_dist(a, b):
	return cKDTree(b).query(a)[0].min()


def gap(tracks, i, j):
	"""Smallest centre-line distance between tracks i and j, skipping the joint of adjacent tracks."""
	a, b = tracks[i]["xy"], tracks[j]["xy"]
	if abs(i - j) != 1:
		return min_dist(a, b)
	if j < i:  # make a the earlier track
		a, b = b, a
	ra = arc(a)[-1] - arc(a)  # distance of a's points to its finish
	rb = arc(b)  # distance of b's points from its start
	best = math.inf
	for lo in np.arange(0, JOINT_SKIP, 100):
		sel = (ra >= lo) & (ra < lo + 100)
		keep = rb >= JOINT_SKIP - lo
		if sel.any() and keep.any():
			best = min(best, min_dist(a[sel], b[keep]))
	sel = ra >= JOINT_SKIP
	if sel.any():
		best = min(best, min_dist(a[sel], b))
	return best


def measure(tracks):
	labels = np.concatenate([np.full(len(t["xy"]), k) for k, t in enumerate(tracks)])
	allpts = np.concatenate([t["xy"] for t in tracks])
	tree = cKDTree(allpts)
	rows = []
	for i, t in enumerate(tracks):
		gaps = {j + 1: gap(tracks, i, j) - 2 * ROAD_HALF for j in range(len(tracks)) if j != i}
		near = min(gaps, key=gaps.get)
		xy = t["xy"]
		tang = np.gradient(xy, axis=0)
		tang /= np.linalg.norm(tang, axis=1)[:, None]
		norm = np.c_[-tang[:, 1], tang[:, 0]]
		offs = np.arange(BAND[0], BAND[1] + 1e-6, STEP)
		pts = np.concatenate([xy + norm * s * d for d in offs for s in (1, -1)])
		pts = np.unique(np.round(pts / STEP), axis=0) * STEP
		d_own = cKDTree(xy).query(pts)[0]
		pts = pts[(d_own >= BAND[0] - STEP / 2) & (d_own <= BAND[1] + STEP / 2)]
		owner = labels[tree.query(pts)[1]]
		plaza = np.hypot(pts[:, 0], pts[:, 1]) <= PLAZA_R + 64
		share = float(((owner != i) | plaza).mean())
		plaza_gap = float(np.hypot(xy[:, 0], xy[:, 1]).min() - PLAZA_R - ROAD_HALF)
		rows.append(
			{
				"Track": i + 1,
				"Length": round(t["length"], 1),
				"Target": TARGETS[i],
				"LengthOff%": round(100 * (t["length"] - TARGETS[i]) / TARGETS[i], 2),
				"MinGapRoadToRoad": round(gaps[near], 1),
				"NearestTrack": near,
				"MinGapCentreToRoad": round(gaps[near] + ROAD_HALF, 1),
				"BandOnOtherGround%": round(100 * share, 1),
				"PlazaGap": round(plaza_gap, 1) if i > 0 else None,
				"MeanDistFromPlaza": round(float(np.hypot(xy[:, 0], xy[:, 1]).mean()), 0),
				"MinRadius": min((s["Radius"] for s in t["segs"] if s["Type"] == "Turn"), default=None),
				"FirstLast": [t["segs"][0]["Type"], round(t["segs"][0].get("Length", 0)), t["segs"][-1]["Type"], round(t["segs"][-1].get("Length", 0))],
				"Segments": len(t["segs"]),
				"LongestStraight": round(max((s["Length"] for s in t["segs"] if s["Type"] == "Straight"), default=0)),
			}
		)
	pts = np.concatenate([t["xy"] for t in tracks])
	ext = [float(pts[:, 0].min()), float(pts[:, 0].max()), float(pts[:, 1].min()), float(pts[:, 1].max())]
	means = [r["MeanDistFromPlaza"] for r in rows]
	return {
		"Rows": rows,
		"ExtentXZ": [round(v) for v in ext],
		"MaxAbs": round(max(abs(v) for v in ext) + BAND[1]),
		"SpiralsOutward": all(b > a for a, b in zip(means, means[1:])),
	}


COLOURS = ["#e6194b", "#3cb44b", "#ffe119", "#4363d8", "#f58231", "#911eb4", "#42d4f4", "#f032e6", "#9a6324", "#000075"]


def draw(tracks, m, name, title):
	fig, ax = plt.subplots(figsize=(11, 11), dpi=110)
	ax.set_facecolor("#f4f1ea")
	for i, t in enumerate(tracks):
		xy = t["xy"]
		ax.plot(xy[:, 0], -xy[:, 1], color=COLOURS[i], lw=2.2, solid_capstyle="round", label="T%d" % (i + 1))
		mid = xy[len(xy) // 2]
		ax.text(mid[0], -mid[1], str(i + 1), fontsize=13, weight="bold", ha="center", va="center", color="white",
			bbox=dict(boxstyle="circle,pad=0.25", fc=COLOURS[i], ec="black", lw=0.6))
		ax.plot(*[xy[0, 0]], *[-xy[0, 1]], marker="o", ms=4, color="black")
	ax.add_patch(plt.Circle((0, 0), PLAZA_R, color="#444", alpha=0.6))
	ax.text(0, 0, "spawn", fontsize=7, ha="center", va="center", color="white")
	worst = min(r["MinGapRoadToRoad"] for r in m["Rows"])
	ax.set_title("%s\nsmallest road-to-road gap %d studs (target %d), extent x %d..%d, z %d..%d" % (
		title, worst, TARGET_GAP, *m["ExtentXZ"]), fontsize=11)
	ax.set_aspect("equal")
	ax.grid(True, color="#ccc", lw=0.5)
	ax.set_xlabel("x (studs)")
	ax.set_ylabel("-z (studs; up = Roblox -Z, the start heading)")
	ax.legend(loc="upper right", fontsize=8, ncol=2)
	fig.tight_layout()
	fig.savefig(os.path.join(OUT, name + ".png"))
	plt.close(fig)


OPTIONS = [
	("current", "Current World 2 chain (feature/alex/world2-place)", current),
	("option_a_wide_spiral", "Option A: same spiral, lap pitch 740", option_a),
	("option_b_zigzag", "Option B: wide zigzag rows, pitch 780, gentle S-bends", option_b),
	("option_c_square_spiral", "Option C: square spiral of long straights, pitch 760", option_c),
]


def main():
	os.makedirs(OUT, exist_ok=True)
	result = {}
	for key, title, make in OPTIONS:
		tracks = world(make())
		m = measure(tracks)
		m["Segments"] = [t["segs"] for t in tracks]
		result[key] = m
		draw(tracks, m, key, title)
		print("==", title, "extent", m["ExtentXZ"], "max|xz|+band", m["MaxAbs"], "spirals outward", m["SpiralsOutward"])
		for r in m["Rows"]:
			print("  T%-2d len %7.0f (%+5.2f%%) gap %6.0f to T%-2d band-on-other %5.1f%% plaza %s mean %6.0f minR %s ends %s longest %5d" % (
				r["Track"], r["Length"], r["LengthOff%"], r["MinGapRoadToRoad"], r["NearestTrack"], r["BandOnOtherGround%"],
				r["PlazaGap"], r["MeanDistFromPlaza"], r["MinRadius"], r["FirstLast"], r["LongestStraight"]))
	json.dump(result, open(os.path.join(OUT, "layout_options.json"), "w"), indent=1)


if __name__ == "__main__":
	main()
