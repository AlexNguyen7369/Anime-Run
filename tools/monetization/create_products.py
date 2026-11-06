#!/usr/bin/env python3
"""Creates Anime Run's gamepasses and developer products (docs/MONETIZATION_SPEC.md "Going live").

Usage:
  ANIMERUN_PRODUCTS_KEY=... python3 tools/monetization/create_products.py            # create what is missing, off sale
  ANIMERUN_PRODUCTS_KEY=... python3 tools/monetization/create_products.py --on-sale  # put everything in the ledger on sale

Every id goes into product_ids.json as soon as Roblox returns it, so a rerun never creates a duplicate: Roblox has no
delete for these. Names and prices mirror src/shared/MonetizationConfig.luau.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

UNIVERSE = 10773557968
API = "https://apis.roblox.com"
LEDGER = Path(__file__).with_name("product_ids.json")
PAUSE = 0.5  # the API allows about 3 requests per second

PASSES = [
    ("vip", "VIP", 499, "VIP title, +10% Money and Luck!"),
    ("auto_roll_2x", "2x Auto-Roll", 199, "Roll twice as fast!"),
    ("extra_roll_1", "Extra Roll I", 299, "+1 auto-roll at once (2 total)!"),
    ("extra_roll_2", "Extra Roll II", 599, "+1 more auto-roll (3 total)!"),
    ("money_2x", "2x Money", 249, "Doubles race payouts!"),
    ("luck_1", "Lucky", 149, "Permanent +1 Luck!"),
    ("luck_2", "ULTRA Lucky", 299, "Permanent +2 Luck!"),
    ("dojo_master", "Dojo Master", 299, "Workshop boost x1.5!"),
    ("deep_stamina", "Deep Stamina", 199, "+25% stamina for your team!"),
    ("inventory", "+ Inventory", 199, "+100 bag spaces!"),
    ("exclusive_runner", "Saitamo", 999, "Exclusive runner: 350 studs/s!"),
]
POTIONS = [
    ("potion_luck_pack", "x5 Luck Potion III", 49, "x2 Luck"),
    ("potion_money_pack", "x5 Money Potion III", 49, "x2 Money"),
    ("potion_speed_pack", "x5 Speed Potion III", 49, "x2 cruise speed"),
    ("potion_stamina_pack", "x5 Stamina Potion III", 49, "x2 stamina"),
    ("potion_bundle", "POTION BUNDLE!", 999, "x10 of EVERY potion"),
]
# Separate ids keep a delayed ordinary receipt from consuming a gift reservation (MonetizationConfig).
PRODUCTS = POTIONS + [(i + "_gift", "Gift: " + n, p, "Gift to a friend: " + d) for i, n, p, d in POTIONS]
# Ids go in MonetizationConfig on feature/alex/boss-event (SIDEKICK_SPEC, BOSS_EVENT_SPEC); prices are placeholders.
PRODUCTS += [
    ("boss_spawn", "Boss Spawn", 149, "Start a Big Raga boss event for your server"),
    ("gems_1000", "1,000 Gems", 199, "1,000 Gems for Sidekick summons"),
    ("gems_2500", "2,500 Gems", 449, "2,500 Gems for Sidekick summons"),
    ("gems_10000", "10,000 Gems", 1499, "10,000 Gems for Sidekick summons"),
    ("gems_30000", "30,000 Gems", 3999, "30,000 Gems for Sidekick summons"),
]

KINDS = {
    "passes": ("game-passes/v1/universes/%d/game-passes" % UNIVERSE, "gamePassId", PASSES),
    "products": ("developer-products/v2/universes/%d/developer-products" % UNIVERSE, "productId", PRODUCTS),
}


class ApiError(Exception):
    pass


def send(method, path, fields):
    # The key goes over stdin (-H @-), so it never shows in the process list.
    command = ["curl", "--http1.1", "-sS", "-m", "30", "-X", method, "-H", "@-", "-w", "\n%{http_code}", API + "/" + path]
    for key, value in fields.items():
        command += ["--form-string", "%s=%s" % (key, value)]
    done = subprocess.run(
        command, input="x-api-key: " + os.environ["ANIMERUN_PRODUCTS_KEY"], capture_output=True, text=True
    )
    if done.returncode != 0:
        # The request may or may not have landed: list the universe before a rerun, or a pass could be duplicated.
        raise ApiError("curl exit %d: %s" % (done.returncode, done.stderr.strip()[:200]))
    text, _, status = done.stdout.rpartition("\n")
    if status != "200":
        raise ApiError(status + " " + text[:200])
    return json.loads(text) if text else {}


def main():
    ledger = json.loads(LEDGER.read_text()) if LEDGER.exists() else {"passes": {}, "products": {}}
    on_sale = "--on-sale" in sys.argv
    failed = False
    for kind, (path, id_field, items) in KINDS.items():
        for item_id, name, price, description in items:
            known = ledger[kind].get(item_id)
            try:
                if on_sale and known:
                    send("PATCH", "%s/%d" % (path, known), {"isForSale": "true", "price": price})
                    print(kind, item_id, known, "on sale")
                elif not on_sale and not known:
                    made = send(
                        "POST",
                        path,
                        {"name": name, "description": description, "price": price, "isForSale": "false"},
                    )
                    ledger[kind][item_id] = int(made[id_field])
                    LEDGER.write_text(json.dumps(ledger, indent=2) + "\n")
                    print(kind, item_id, ledger[kind][item_id])
            except ApiError as error:
                print(kind, item_id, "FAILED", error)
                failed = True
                break  # the same error would repeat for the rest of this kind
            time.sleep(PAUSE)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
