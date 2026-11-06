#!/usr/bin/env python3
# Uploads the settled summon reveal textures as Decals under the owner's account, resolves each to its image id, and keeps the
# ledger assets.json so a rerun never spends an upload twice. Needs ROBLOX_OPEN_CLOUD_KEY and ROBLOX_CREATOR_ID.
#   ROBLOX_OPEN_CLOUD_KEY="$ANIMERUN_OPEN_CLOUD_KEY" python3 vfx/summon_reveal/upload.py
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools", "blender", "portrait"))
import upload_portraits as up  # noqa: E402

FILES = {
	"Vortex": "summon_vortex.flipbook.png",
	"SpeedLines": "summon_speedlines.flipbook.png",
	"Impact": "summon_impact.flipbook.png",
	"Ring": "summon_ring.flipbook.png",
	"Flare": "summon_flare.png",
	"Glow": "summon_glow.png",
	"Rays": "summon_rays.png",
}
LEDGER = os.path.join(HERE, "assets.json")

ledger = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {}
for key, name in FILES.items():
	path = os.path.join(HERE, "out", name)
	digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
	row = ledger.get(key) or {}
	if row.get("Hash") != digest or "Decal" not in row:
		row = {"Hash": digest, "Decal": up.upload(key, path, "SummonFx")}
		ledger[key] = row
		json.dump(ledger, open(LEDGER, "w"), indent="\t", sort_keys=True)
	if "Image" not in row:
		row["Image"] = up.resolve(key, row["Decal"])
		json.dump(ledger, open(LEDGER, "w"), indent="\t", sort_keys=True)
	print(key, row["Image"])
