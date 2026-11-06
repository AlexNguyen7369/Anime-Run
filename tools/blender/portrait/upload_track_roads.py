#!/usr/bin/env python3
# Uploads assets/track_roads/t<n>.png (road screenshots, design doc 4.15) as Decals and writes the image ids into
# src/shared/TrackCards.luau. The ledger tools/blender/track_road_assets.json skips unchanged images.
# ROBLOX_OPEN_CLOUD_KEY + ROBLOX_CREATOR_ID required.
import hashlib
import json
import os
import re

import upload_portraits as up

ROADS = os.path.join(up.REPO, "assets", "track_roads")
CARDS = os.path.join(up.REPO, "src", "shared", "TrackCards.luau")
LEDGER = os.path.join(up.REPO, "tools", "blender", "track_road_assets.json")

ledger = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {}
cards = open(CARDS).read()
for n in range(1, 11):
	path = os.path.join(ROADS, f"t{n}.png")
	digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
	row = ledger.get(str(n), {})
	if row.get("Hash") != digest or not row.get("Decal"):
		row = {"Hash": digest, "Decal": up.upload(f"track{n}", path, "TrackRoad", "Anime Run track road screenshot")}
		ledger[str(n)] = row
		json.dump(ledger, open(LEDGER, "w"), indent="\t", sort_keys=True)
	if not row.get("Image"):
		row["Image"] = up.resolve(f"track{n}", row["Decal"])
		json.dump(ledger, open(LEDGER, "w"), indent="\t", sort_keys=True)
	cards, hits = re.subn(r"(\[%d\] = \{\s*Road = )[^,]+," % n, r'\g<1>"rbxassetid://%s",' % row["Image"], cards)
	assert hits == 1, n
	print(n, row["Image"], flush=True)
open(CARDS, "w").write(cards)
