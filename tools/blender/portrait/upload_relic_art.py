#!/usr/bin/env python3
# Uploads Relic and chest art (design doc 4.38, docs/RELIC_SPEC.md "Names and art") as Decals, only after the owner approves it.
# Ledger: tools/blender/relic_art_assets.json (name -> Hash, Decal, Image). A name already resolved there is skipped, even if its
# PNG has changed; delete its row to upload again. Writes no Luau: the ids are wired by hand.
#   python3 tools/blender/portrait/upload_relic_art.py [--dry-run] [<name> ...]
# With no names: Big Raga's 5 relic_* images. The Elf Mage's and The Golden King's art and chests go up only when named
# (relic_staff has none: it reuses the Dodge bar's StaffIcon). ROBLOX_OPEN_CLOUD_KEY + ROBLOX_CREATOR_ID required, except for
# --dry-run: prints upload / resolve / skip per name, no network, no writes.
import hashlib
import json
import os
import sys

RAGA_RELICS = ("relic_talisman", "relic_nail", "relic_finger", "relic_eyes", "relic_world_core")
MAGE_RELICS = ("relic_helmet", "relic_bracelet", "relic_flask", "relic_grimoire")  # The Elf Mage's (owner 2026-11-11)
KING_RELICS = ("relic_coin", "relic_goblet", "relic_chain", "relic_armor", "relic_key")  # The Golden King's (owner 2026-11-11)
RELICS = RAGA_RELICS + MAGE_RELICS + KING_RELICS
CHESTS = ("chest_raga", "chest_adapted", "chest_mage", "chest_king")


def names_from(args):
	unknown = [name for name in args if name not in RELICS + CHESTS]
	if unknown:
		raise SystemExit(f"unknown art names: {unknown}")
	return list(dict.fromkeys(args)) or list(RAGA_RELICS)


def main():
	assert names_from([]) == list(RAGA_RELICS) and names_from(["chest_raga", "chest_raga"]) == ["chest_raga"]
	assert names_from(["relic_grimoire", "chest_mage"]) == ["relic_grimoire", "chest_mage"] and "relic_staff" not in RELICS
	assert names_from(["relic_key", "chest_king"]) == ["relic_key", "chest_king"]
	dry = "--dry-run" in sys.argv
	names = names_from([a for a in sys.argv[1:] if a != "--dry-run"])
	repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
	art_dir = os.path.join(repo, "assets", "ui")
	ledger_path = os.path.join(repo, "tools", "blender", "relic_art_assets.json")
	ledger = json.load(open(ledger_path)) if os.path.exists(ledger_path) else {}
	missing = [name for name in names if not os.path.exists(os.path.join(art_dir, name + ".png"))]
	if missing:
		raise SystemExit(f"nothing drawn for {missing}")
	if dry:
		for name in names:
			row = ledger.get(name, {})
			step = "skip" if row.get("Image") else "resolve" if row.get("Decal") else "upload"
			print("DRY", step, name, os.path.getsize(os.path.join(art_dir, name + ".png")), "bytes")
		return
	for key in ("ROBLOX_OPEN_CLOUD_KEY", "ROBLOX_CREATOR_ID"):
		if key not in os.environ:
			raise SystemExit(key + " is not set")

	# upload_portraits guards its main() and sidekick_art only defines; never import upload_dodge_art, it uploads on import.
	import upload_portraits as up

	for name in names:
		path = os.path.join(art_dir, name + ".png")
		row = ledger.get(name, {})
		if row.get("Image"):
			print("SKIP", name, row["Image"], flush=True)
			continue
		# A Decal left by a failed resolve is retried without spending another upload.
		if not row.get("Decal"):
			with open(path, "rb") as f:
				digest = hashlib.sha256(f.read()).hexdigest()
			row = {"Hash": digest, "Decal": up.upload(name, path, "RelicArt", "Anime Run Relic art")}
			ledger[name] = row
			with open(ledger_path, "w") as f:
				json.dump(ledger, f, indent="\t", sort_keys=True)
			print("UPLOADED", name, row["Decal"], flush=True)
		row["Image"] = up.resolve(name, row["Decal"])
		with open(ledger_path, "w") as f:
			json.dump(ledger, f, indent="\t", sort_keys=True)
		print("RESOLVED", name, row["Image"], flush=True)


if __name__ == "__main__":
	main()
