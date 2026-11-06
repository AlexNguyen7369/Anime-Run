#!/usr/bin/env python3
# Uploads the Dodge bar's art (design doc 4.37, 4.38) as Decals and writes the image ids into their config. The ledgers skip an
# unchanged image. ROBLOX_OPEN_CLOUD_KEY + ROBLOX_CREATOR_ID required.
import hashlib
import json
import os
import re

import upload_portraits as up

ROWS = (
	("raga_wheel", "RagaWheel", "RelicConfig.luau", r'(RelicConfig\.WheelArt = )"[^"]*"', "raga_wheel_asset.json"),
	("dodge_star", "DodgeStar", "BossDodge.luau", r'(BossDodge\.StarArt = )"[^"]*"', "dodge_star_asset.json"),
)
for key, title, config, pattern, ledger_name in ROWS:
	art = os.path.join(up.REPO, "assets", "ui", key + ".png")
	config_path = os.path.join(up.REPO, "src", "shared", config)
	ledger = os.path.join(up.REPO, "tools", "blender", ledger_name)
	row = json.load(open(ledger)) if os.path.exists(ledger) else {}
	digest = hashlib.sha256(open(art, "rb").read()).hexdigest()
	if row.get("Hash") != digest or not row.get("Decal"):
		row = {"Hash": digest, "Decal": up.upload(key, art, title, "Anime Run Dodge bar art")}
		json.dump(row, open(ledger, "w"), indent="\t", sort_keys=True)
	if not row.get("Image"):
		row["Image"] = up.resolve(key, row["Decal"])
		json.dump(row, open(ledger, "w"), indent="\t", sort_keys=True)
	text, hits = re.subn(pattern, r'\g<1>"rbxassetid://%s"' % row["Image"], open(config_path).read())
	assert hits == 1
	open(config_path, "w").write(text)
	print(key, row["Image"], flush=True)
