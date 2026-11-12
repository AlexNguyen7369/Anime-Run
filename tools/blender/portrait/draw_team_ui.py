#!/usr/bin/env python3
# Draws the Team button and Team panel drafts (owner approval drafts, design doc 4.40 "Market pill and Bosses button",
# owner 2026-11-12) into assets/ui/team_draft/: the HUD with Bosses and Team in a second column (desktop and phone),
# three Team icon options in the Tab tilt style, three Team panel layouts (A Line-up, B Formation, C Presets first),
# each on desktop and phone, and a labelled sheet. Pink text marks what today's game does not have (needs a new rule).
# Reuses draw_mage_ui.py (canvas, CoreText text, PNG) and draw_boss_cards.py (Draw, panel colours, art loading).
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_team_ui.py
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_boss_cards as bc  # noqa: E402
import draw_mage_ui as base  # noqa: E402
from draw_boss_cards import CYAN, MUTED, PANEL, PANEL_DEEP, PH, PINK, PW, ROW, SOFT, Draw, button  # noqa: E402
from draw_mage_ui import GOLD, GOLD_HI, GOLD_LOW, HEAVY, NAVY, ROUND, WHITE, circle, over, polygon, rbox, resize, stamp  # noqa: E402

ROOT = bc.ROOT
OUT = os.path.join(ROOT, "assets", "ui", "team_draft")
GREEN = (60, 230, 90)  # Backpack TILE_GREEN-like: a card on the Team
RED = (232, 64, 72)
OUTLINE = (8, 10, 20)

# Catalog facts (src/shared/Characters/*.luau): name, rarity, category, series. Names are the catalog's tweaked names.
CHARS = {
	"leaf_hero": ("Narito", "Legendary", "Marathoner", "leaf"),
	"leaf_avenger": ("Saske", "Epic", "Sprinter", "leaf"),
	"leaf_medic": ("Sakara", "Uncommon", "Balanced", "leaf"),
	"leaf_copycat": ("Kakashe", "Rare", "Balanced", "leaf"),
	"sea_captain": ("Lufy", "Legendary", "Marathoner", "sea"),
	"sea_swords": ("Zoru", "Rare", "Marathoner", "sea"),
	"sea_cook": ("Sanjy", "Uncommon", "Sprinter", "sea"),
	"sea_navigator": ("Nammi", "Common", "Balanced", "sea"),
	"ds_hero": ("Tanjiru", "Legendary", "Balanced", "ds"),
	"ds_thunder": ("Zenitsa", "Rare", "Sprinter", "ds"),
	"ds_boar": ("Inosuki", "Uncommon", "Marathoner", "ds"),
	"db_prince": ("Vegata", "Legendary", "Sprinter", "db"),
	"jk_vessel": ("Yuuji", "Epic", "Sprinter", "jk"),
	"jk_shadows": ("Megumo", "Rare", "Marathoner", "jk"),
	"jk_nails": ("Nobora", "Uncommon", "Balanced", "jk"),
	"mha_hero": ("Deko", "Legendary", "Balanced", "mha"),
	"mha_blast": ("Bakugoo", "Epic", "Sprinter", "mha"),
	"soul_substitute": ("Ichigu", "Legendary", "Balanced", "soul"),
}
SERIES_NAME = {"leaf": "Narito Shippudon", "sea": "One Peace", "ds": "Demon Slicer", "jk": "Jujitsu Kaisan", "db": "Dragon Bawl Z", "mha": "My Hero Akademia", "soul": "Bleech"}
# SeriesCatalog preset trios shown in the drafts.
PRESETS = [
	("Team Seven", "leaf", ["leaf_hero", "leaf_avenger", "leaf_medic"]),
	("Straw Crew", "sea", ["sea_captain", "sea_swords", "sea_cook"]),
	("Kamada Squad", "ds", ["ds_hero", "ds_thunder", "ds_boar"]),
	("First Years", "jk", ["jk_vessel", "jk_shadows", "jk_nails"]),
]
OWNED = [c for c in CHARS if c not in ("jk_shadows", "jk_nails")]
RARITY_ORDER = ["Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"]
OWNED.sort(key=lambda c: (RARITY_ORDER.index(CHARS[c][1]), c))
RARITY_TINT = {"Common": (180, 180, 180), "Uncommon": (90, 200, 90), "Rare": (70, 140, 255), "Epic": (170, 80, 230), "Legendary": (255, 170, 40), "Mythic": (255, 70, 110), "Secret": (60, 60, 60)}
# RaceConfig / StaminaConfig (placeholders there).
RARITY_BASE = {"Common": 24, "Uncommon": 33, "Rare": 48, "Epic": 90, "Legendary": 200, "Mythic": 450, "Secret": 700}
CAT_SPEED = {"Sprinter": 1.25, "Balanced": 1, "Marathoner": 0.8}
STAM_BASE = {"Common": 13.5, "Uncommon": 15.5, "Rare": 18, "Epic": 21, "Legendary": 24, "Mythic": 27, "Secret": 30}
STAM_CAT = {"Sprinter": 0.9, "Balanced": 1, "Marathoner": 1.1}
BONUS_STAMINA, PRESET_CRUISE = {"Preset": 1.4, "Series": 1.2}, 1.1

ART = {c: f"assets/characters_avatar/{c}/portrait.png" for c in CHARS}
for icon in ("Index", "Items", "Rebirth", "Boss", "Quests", "Shop", "AutoPlay", "Upgrade"):
	ART["hud_" + icon] = f"assets/ui/hud_tabtilt/{icon}.png"


def mix(a, b, t):
	return tuple(a[i] * (1 - t) + b[i] * t for i in range(3))


def team_bonus(team):
	ids = [t for t in team if t]
	if len(ids) != 3:
		return None
	for name, _, members in PRESETS:
		if set(ids) == set(members):
			return ("Preset", name)
	series = {CHARS[i][3] for i in ids}
	return ("Series", SERIES_NAME[series.pop()]) if len(series) == 1 else None


def stats(cid, team=()):
	"""(cruise studs/s, stamina s) as the game shows them: catalog base x the team bonus, no points, potions or gear."""
	_, rarity, cat, _ = CHARS[cid]
	b = team_bonus(team) if cid in team else None
	cruise = RARITY_BASE[rarity] * CAT_SPEED[cat] * (PRESET_CRUISE if b and b[0] == "Preset" else 1)
	return cruise, STAM_BASE[rarity] * STAM_CAT[cat] * (BONUS_STAMINA[b[0]] if b else 1)


def rate(c):
	return f"{int(c + 0.5)} studs/s"


def total_stamina(team):
	return sum(stats(c, team)[1] for c in team if c)


# Small drawing helpers -------------------------------------------------------------------------------------------------------
def tri(D, pts, color):
	if D.img is None:
		return
	xs, ys = [p[0] for p in pts], [p[1] for p in pts]
	sub, X, Y = D.win(min(xs) - 4, min(ys) - 4, max(xs) + 4, max(ys) + 4)
	d = polygon(X, Y, pts)
	over(sub, NAVY, D.cov(d - 2.5))
	over(sub, color, D.cov(d))


def disc(D, cx, cy, r, color, stroke=0.0, stroke_color=NAVY, alpha=1.0):
	D.rect(cx - r, cy - r, 2 * r, 2 * r, color, r=r, stroke=stroke, stroke_color=stroke_color, alpha=alpha)


def new(D, words, x, y, px=15, anchor="l", stroke=2.0):
	"""Pink: not in today's game, needs a new rule."""
	D.text(ROUND, px, words, x, y, color=PINK, stroke=stroke, anchor=anchor)


def panel(D, title):
	"""The 1200 x 620 popup (design doc 4.42) as the boss-card drafts draw it, with the Team icon as the logo."""
	D.rect(0, 0, PW, PH, GOLD_LOW, r=18)
	D.rect(4, 4, PW - 8, PH - 8, PANEL, r=15, stroke=2, stroke_color=GOLD, grad=(PANEL, PANEL_DEEP))
	D.rect(14, 10, PW - 28, 52, PANEL_DEEP, r=12, alpha=0.9, stroke=2, stroke_color=GOLD_LOW)
	D.image("team1", 54, 30, 92)
	D.text(HEAVY, 40, title, 106, 36, color=GOLD_HI, stroke=3, anchor="l")
	D.rect(PW - 66, 12, 48, 48, (255, 70, 80), r=10, stroke=3, grad=((255, 90, 100), (190, 30, 50)))
	D.text(ROUND, 34, "X", PW - 42, 36, stroke=2.5)


def number_badge(D, x, y, n, size=30):
	disc(D, x + size / 2, y + size / 2, size / 2, GOLD, stroke=2.5)
	D.text(HEAVY, round(size * 0.66), str(n), x + size / 2, y + size / 2, color=NAVY, stroke=0)


def stamina_bar(D, x, y, w, h, seconds, px=18):
	D.rect(x, y, w, h, (14, 18, 32), r=h / 2, stroke=2.5, stroke_color=NAVY)
	D.rect(x + 3, y + 3, w - 6, h - 6, (60, 150, 255), r=(h - 6) / 2, grad=((120, 190, 255), (40, 110, 230)))
	D.text(ROUND, px, f"{seconds:.1f} s stamina", x + w / 2, y + h / 2, stroke=2.5)


def bonus_badge(D, x, y, w, team, px=20):
	"""The team bonus line in today's TeamHud words; returns the bottom."""
	b = team_bonus(team)
	if not b:
		D.rect(x, y, w, 34, (14, 18, 32), r=17, stroke=2, stroke_color=MUTED)
		D.text(ROUND, px - 3, "No team bonus", x + w / 2, y + 17, color=SOFT, stroke=2)
		return y + 34
	D.rect(x, y, w, 34, GOLD_LOW, r=17, stroke=2.5, grad=(GOLD, GOLD_LOW))
	D.text(HEAVY, px, ("★ " if b[0] == "Preset" else "") + b[1].upper(), x + w / 2, y + 17, stroke=2.5)
	return y + 34


def bonus_words(team):
	b = team_bonus(team)
	if not b:
		return ["3 of one series:", "+20% stamina"]
	return ["+40% STAMINA", "+10% SPEED"] if b[0] == "Preset" else ["+20% STAMINA"]


def toolbar_button(D, x, y, w, h, words, px=20, color=ROW):
	D.rect(x, y, w, h, color, r=10, stroke=2.5, stroke_color=CYAN if color == ROW else NAVY, grad=(color, mix(color, PANEL_DEEP, 0.5)))
	D.text(ROUND, px, words, x + w / 2, y + h / 2, stroke=2)


def search_box(D, x, y, w, h):
	D.rect(x, y, w, h, (14, 18, 32), r=10, stroke=2, stroke_color=MUTED)
	D.text(ROUND, 18, "Search", x + 14, y + h / 2, color=MUTED, stroke=0, anchor="l")


def best_team(D, x, y, w, h):
	toolbar_button(D, x, y, w, h, "Best team", color=(200, 140, 30))
	new(D, "NEW, needs a rule", x + w / 2, y - 9, px=13, anchor="c")


# Character cards ---------------------------------------------------------------------------------------------------------------
def roster_card(D, x, y, w, h, cid, team, picked=None):
	name, rarity, _, _ = CHARS[cid]
	tint = RARITY_TINT[rarity]
	slot = team.index(cid) + 1 if cid in team else None
	edge = WHITE if cid == picked else (GREEN if slot else NAVY)
	D.rect(x, y, w, h, PANEL_DEEP, r=10, stroke=3, stroke_color=edge, grad=(mix(tint, PANEL_DEEP, 0.35), mix(tint, PANEL_DEEP, 0.8)))
	D.image(cid, x + w / 2, y + h / 2 - 6, h * 0.92, clip=(x + 2, y + 2, w - 4, h - 4, 8))
	D.rect(x + 2, y + h - 40, w - 4, 38, (10, 14, 28), r=8, alpha=0.55)
	if slot:
		D.text(ROUND, 15, f"TEAM {slot}", x + 8, y + 14, color=GREEN, stroke=2.5, anchor="l")
	D.text(ROUND, 13, rate(stats(cid)[0]), x + w - 7, y + h - 31, color=GOLD, stroke=2, anchor="r")
	D.text(HEAVY, 17, name, x + w - 7, y + h - 13, stroke=2, anchor="r")


def roster_grid(D, x, y, cols, w, h, gap, team, picked, count=16):
	for i, cid in enumerate(OWNED[:count]):
		roster_card(D, x + i % cols * (w + gap), y + i // cols * (h + gap), w, h, cid, team, picked)


ORDER_WORDS = ["RUNS FIRST", "TAGS IN 2ND", "TAGS IN LAST"]


def slot_card(D, x, y, w, h, n, cid, team, glow=False, picked=None):
	r = 14
	ring = (CYAN, 6, 0.85) if glow else None
	if cid is None:
		D.rect(x, y, w, h, (18, 24, 44), r=r, stroke=3, stroke_color=CYAN if glow else MUTED, glow=ring)
		D.rect(x + 10, y + 46, w - 20, h - 58, (24, 32, 56), r=10, stroke=2, stroke_color=(70, 80, 110))
		number_badge(D, x + 12, y + 10, n)
		D.text(ROUND, 18, ORDER_WORDS[n - 1], x + 50, y + 25, color=SOFT, anchor="l")
		D.text(HEAVY, 60, "+", x + w / 2, y + h / 2 + 4, color=MUTED, stroke=0)
		D.text(ROUND, 20, "Empty slot", x + w / 2, y + h / 2 + 46, color=SOFT)
		D.text(ROUND, 16, f"Tap {CHARS[picked][0]} to put here" if picked else "Tap a character, then here", x + w / 2, y + h - 30, color=SOFT, stroke=1.5)
		return
	name, rarity, cat, _ = CHARS[cid]
	cruise, stamina = stats(cid, team)
	tint = RARITY_TINT[rarity]
	D.rect(x, y, w, h, PANEL_DEEP, r=r, stroke=3, stroke_color=tint, grad=(mix(tint, PANEL_DEEP, 0.55), PANEL_DEEP), glow=ring)
	D.dots(x, y, w, h, r, (255, 255, 255), 0.07)
	D.image(cid, x + 80, y + 40 + (h - 84) / 2, 156, clip=(x + 3, y + 42, w - 6, h - 88, 10))
	number_badge(D, x + 12, y + 10, n)
	D.text(ROUND, 18, ORDER_WORDS[n - 1], x + 50, y + 25, anchor="l")
	tx = x + 162
	D.text(HEAVY, 28, name, tx, y + 74, stroke=2.5, anchor="l")
	D.text(ROUND, 18, cat, tx, y + 104, color=CYAN, anchor="l")
	D.text(ROUND, 18, rate(cruise), tx, y + 130, color=GOLD, anchor="l")
	stamina_bar(D, x + 10, y + h - 40, w - 20, 30, stamina)


def summary(D, x, y, w, h, team, edit=False):
	D.rect(x, y, w, h, PANEL_DEEP, r=14, alpha=0.9, stroke=2, stroke_color=MUTED)
	cx = x + w / 2
	D.text(ROUND, 18, "Team bonus", cx, y + 20, color=SOFT)
	bottom = bonus_badge(D, x + 10, y + 36, w - 20, team, px=19)
	for i, words in enumerate(bonus_words(team)):
		D.text(ROUND, 17, words, cx, bottom + 18 + i * 21, color=(120, 255, 140) if team_bonus(team) else SOFT, stroke=2)
	D.text(ROUND, 18, f"Total {total_stamina(team):.1f} s", cx, y + 140, stroke=2)
	new(D, "summed stamina: NEW", cx, y + 160, px=13, anchor="c")
	if edit:
		button(D, x + 12, y + h - 50, (w - 32) / 2, 40, "Save", "go", px=22)
		button(D, x + 20 + (w - 32) / 2, y + h - 50, (w - 32) / 2, 40, "Back", "details", px=20)


# Draft A: line-up ------------------------------------------------------------------------------------------------------------------
def draft_a(D, team, picked, title="TEAM", edit=False):
	panel(D, title)
	cw, gap = 282, 26
	for i in range(3):
		x = 36 + i * (cw + gap)
		slot_card(D, x, 80, cw, 226, i + 1, team[i], team, glow=picked is not None, picked=picked)
		if i < 2:
			tri(D, [(x + cw + 6, 180), (x + cw + 20, 193), (x + cw + 6, 206)], GOLD)
	summary(D, 952, 80, 212, 226, team, edit)
	y = 326
	hint = f"{CHARS[picked][0]} picked: tap a slot. Members swap places." if picked else "Tap a character, then a slot. Members swap places."
	D.text(ROUND, 19, hint, 40, y + 18, color=SOFT, stroke=2, anchor="l")
	best_team(D, 1164 - 200 - 12 - 170 - 12 - 150, y, 150, 36)
	toolbar_button(D, 1164 - 200 - 12 - 170, y, 170, 36, "Sort: Rarity")
	search_box(D, 1164 - 200, y, 200, 36)
	roster_grid(D, 36, 372, 8, 132, 104, 9.7, team, picked)


# Draft B: formation --------------------------------------------------------------------------------------------------------------
ROLE = ["LEAD", "MIDDLE", "ANCHOR"]


def formation_row(D, x, y, w, h, n, cid, team, picked=None):
	r = 14
	if cid is None:
		D.rect(x, y, w, h, (18, 24, 44), r=r, stroke=3, stroke_color=CYAN if picked else MUTED, glow=(CYAN, 6, 0.85) if picked else None)
	else:
		tint = RARITY_TINT[CHARS[cid][1]]
		D.rect(x, y, w, h, PANEL_DEEP, r=r, stroke=3, stroke_color=tint, grad=(mix(tint, PANEL_DEEP, 0.6), PANEL_DEEP))
		for i in range(3):  # drag handle
			D.rect(x + 14, y + h / 2 - 12 + i * 10, 20, 4, SOFT, r=2)
	D.rect(x + 44, y + 10, 92, h - 20, (14, 18, 32), r=10, stroke=2, stroke_color=GOLD_LOW)
	D.text(HEAVY, 38, str(n), x + 90, y + h / 2 - 12, color=GOLD_HI, stroke=2.5)
	D.text(ROUND, 16, ROLE[n - 1], x + 90, y + h / 2 + 24, color=GOLD, stroke=2)
	if cid is None:
		D.text(ROUND, 20, "Empty: drag a character here", x + 156, y + h / 2 - 12, color=SOFT, anchor="l")
		D.text(ROUND, 16, f"or tap {CHARS[picked][0]}, then this row" if picked else "or tap one, then this row", x + 156, y + h / 2 + 16, color=SOFT, anchor="l", stroke=1.5)
		return
	name, _, cat, _ = CHARS[cid]
	cruise, stamina = stats(cid, team)
	D.image(cid, x + 200, y + h / 2 + 8, h + 14, clip=(x + 146, y + 4, 108, h - 8, 10))
	D.text(HEAVY, 28, name, x + 266, y + h / 2 - 14, stroke=2.5, anchor="l")
	D.text(ROUND, 18, cat, x + 266, y + h / 2 + 18, color=CYAN, anchor="l")
	D.text(ROUND, 19, rate(cruise), x + w - 16, y + 28, color=GOLD, anchor="r")
	stamina_bar(D, x + 404, y + h - 48, w - 418, 30, stamina, px=16)


def draft_b(D, team, picked):
	panel(D, "TEAM")
	x, w, h, gap = 36, 564, 112, 22
	new(D, "Drag ≡ to reorder, LEAD / MIDDLE / ANCHOR names: NEW", x + 4, 71, px=14)
	for i in range(3):
		y = 80 + i * (h + gap)
		formation_row(D, x, y, w, h, i + 1, team[i], team, picked)
		if i < 2:
			tri(D, [(x + 80, y + h + 4), (x + 100, y + h + 4), (x + 90, y + h + 18)], GOLD)
			D.text(ROUND, 15, "tags in at 0 stamina", x + 112, y + h + 11, color=SOFT, stroke=1.5, anchor="l")
	sy = 80 + 3 * h + 2 * gap + 16
	D.rect(x, sy, w, 592 - sy, PANEL_DEEP, r=14, alpha=0.9, stroke=2, stroke_color=GOLD_LOW)
	D.text(ROUND, 18, "Team bonus", x + 20, sy + 22, color=SOFT, anchor="l")
	bonus_badge(D, x + 14, sy + 40, 300, team)
	D.text(ROUND, 17, " ".join(bonus_words(team)), x + 164, sy + 96, color=(120, 255, 140) if team_bonus(team) else SOFT, stroke=2)
	D.text(ROUND, 18, "Total stamina", x + w - 120, sy + 30, color=SOFT)
	D.text(HEAVY, 30, f"{total_stamina(team):.1f} s", x + w - 120, sy + 62, stroke=2.5)
	new(D, "summed: NEW", x + w - 120, sy + 92, px=13, anchor="c")
	rx = 620
	best_team(D, rx, 80, 150, 36)
	toolbar_button(D, rx + 162, 80, 170, 36, "Sort: Rarity")
	search_box(D, rx + 344, 80, 200, 36)
	roster_grid(D, rx, 128, 4, 128, 108, 10.6, team, picked)


# Draft C: presets first ----------------------------------------------------------------------------------------------------------
MY_TEAMS = [
	("Team 1", ["leaf_hero", "leaf_avenger", "leaf_medic"], True),
	("Team 2", ["sea_captain", "sea_swords", "sea_cook"], False),
	("Team 3", ["ds_hero", "mha_hero", None], False),
]


def mini(D, x, y, s, cid, missing=False):
	if cid is None:
		D.rect(x, y, s, s, (24, 32, 56), r=8, stroke=2, stroke_color=(70, 80, 110))
		D.text(HEAVY, round(s * 0.5), "+", x + s / 2, y + s / 2, color=MUTED, stroke=0)
		return
	tint = RARITY_TINT[CHARS[cid][1]]
	D.rect(x, y, s, s, PANEL_DEEP, r=8, stroke=2.5, stroke_color=NAVY, grad=(mix(tint, PANEL_DEEP, 0.35), mix(tint, PANEL_DEEP, 0.8)))
	D.image(cid, x + s / 2, y + s / 2, s * 1.0, clip=(x + 2, y + 2, s - 4, s - 4, 6))
	if missing:
		D.dim(x, y, s, s, 8, 0.85)
		D.rect(x, y, s, s, (0, 0, 0), r=8, alpha=0.35)
		D.text(HEAVY, round(s * 0.42), "?", x + s / 2, y + s / 2, color=SOFT, stroke=2)


def team_card(D, x, y, w, h, name, team, in_use):
	D.rect(x, y, w, h, ROW, r=14, stroke=3, stroke_color=GREEN if in_use else MUTED, grad=(ROW, PANEL_DEEP), glow=(GREEN, 5, 0.6) if in_use else None)
	D.text(HEAVY, 26, name, x + 16, y + 26, stroke=2.5, anchor="l")
	if in_use:
		D.rect(x + w - 100, y + 12, 86, 28, GREEN, r=14, stroke=2, grad=((110, 255, 120), (16, 160, 70)))
		D.text(HEAVY, 16, "IN USE", x + w - 57, y + 26, stroke=1.5)
	s = (w - 32 - 16) / 3
	for i, cid in enumerate(team):
		mini(D, x + 16 + i * (s + 8), y + 50, s, cid)
	b = team_bonus(team)
	words = ("★ " + b[1].upper() if b[0] == "Preset" else b[1]) if b else "No team bonus"
	D.text(ROUND, 17, words, x + w / 2, y + 50 + s + 18, color=GOLD if b else SOFT, stroke=2)
	by = y + h - 50
	button(D, x + 16, by, (w - 44) / 2, 38, "In use" if in_use else "Use", "off" if in_use else "go", px=22)
	button(D, x + 28 + (w - 44) / 2, by, (w - 44) / 2, 38, "Edit", "details", px=22)


def new_team_card(D, x, y, w, h):
	D.rect(x, y, w, h, (18, 24, 44), r=14, stroke=3, stroke_color=MUTED)
	D.rect(x + 12, y + 12, w - 24, h - 24, (24, 32, 56), r=10, stroke=2, stroke_color=(70, 80, 110))
	D.text(HEAVY, 70, "+", x + w / 2, y + h / 2 - 18, color=MUTED, stroke=0)
	D.text(ROUND, 22, "New team", x + w / 2, y + h / 2 + 34, color=SOFT)
	new(D, "how many saves: open", x + w / 2, y + h / 2 + 62, px=14, anchor="c")


def bonus_team_card(D, x, y, w, h, preset, series, members):
	have = [c in OWNED for c in members]
	D.rect(x, y, w, h, PANEL_DEEP, r=14, stroke=3, stroke_color=GOLD_LOW if all(have) else MUTED, grad=((40, 34, 30), PANEL_DEEP))
	D.text(HEAVY, 22, "★ " + preset.upper(), x + 14, y + 24, color=GOLD_HI, stroke=2.5, anchor="l")
	D.text(ROUND, 15, SERIES_NAME[series], x + 16, y + 48, color=CYAN, stroke=1.5, anchor="l")
	s = (w - 28 - 16) / 3
	for i, cid in enumerate(members):
		mini(D, x + 14 + i * (s + 8), y + 64, s, cid, missing=not have[i])
	ny = y + 64 + s
	n = sum(have)
	D.text(ROUND, 15, f"{n}/3 owned", x + 14, ny + 16, color=SOFT if n < 3 else (120, 255, 140), stroke=1.5, anchor="l")
	D.text(ROUND, 15, "+40% STA  +10% SPD", x + w - 12, ny + 16, color=(120, 255, 140), stroke=1.5, anchor="r")
	button(D, x + 14, y + h - 44, w - 28, 34, "Use this team" if n == 3 else f"Missing {3 - n}", "go" if n == 3 else "off", px=19)


def draft_c(D):
	panel(D, "TEAM")
	D.text(HEAVY, 24, "MY TEAMS", 40, 82, color=GOLD_HI, stroke=2.5, anchor="l")
	new(D, "Saved teams: NEW, need a rule (save data, count, names)", 196, 82, px=15)
	w, gap, y, h = 270, 16, 98, 228
	for i, (name, team, in_use) in enumerate(MY_TEAMS):
		team_card(D, 36 + i * (w + gap), y, w, h, name, team, in_use)
	new_team_card(D, 36 + 3 * (w + gap), y, w, h)
	y2 = 346
	D.text(HEAVY, 24, "BONUS TEAMS", 40, y2, color=GOLD_HI, stroke=2.5, anchor="l")
	D.text(ROUND, 16, "a series' preset trio in any order", 236, y2, color=SOFT, stroke=1.5, anchor="l")
	new(D, "list and Use: NEW", 1164, y2, px=15, anchor="r")
	for i, (preset, series, members) in enumerate(PRESETS):
		bonus_team_card(D, 36 + i * (w + gap), y2 + 18, w, 592 - y2 - 18, preset, series, members)


# Screens ---------------------------------------------------------------------------------------------------------------------------
SCREENS = {
	"A": [
		("desktop", lambda D: draft_a(D, ["leaf_hero", "leaf_avenger", "leaf_medic"], "sea_captain"), "Draft A Line-up: Team Seven in run order; Lufy picked, so every slot lights"),
		("phone", lambda D: draft_a(D, ["sea_captain", "sea_swords", None], "sea_cook"), "Draft A on a phone: slot 3 empty, no bonus yet; Sanjy picked"),
	],
	"B": [
		("desktop", lambda D: draft_b(D, ["leaf_hero", "leaf_avenger", "leaf_medic"], None), "Draft B Formation: rows in run order, drag to reorder, roster on the right"),
		("phone", lambda D: draft_b(D, ["sea_captain", "sea_swords", None], "sea_cook"), "Draft B on a phone: ANCHOR empty; Sanjy picked"),
	],
	"C": [
		("desktop", draft_c, "Draft C Presets first: saved teams, then the series' bonus teams"),
		("phone", draft_c, "Draft C on a phone"),
		("edit", lambda D: draft_a(D, ["ds_hero", "mha_hero", None], "db_prince", title="EDIT TEAM 3", edit=True), "Draft C, Edit on Team 3: the slot view (as A) with Save and Back"),
	],
}
NOTES = {
	"A": "Pink = not in today's game. Tap a character, then a slot is today's Items flow (SlotPicker, Remotes.SetTeam).",
	"B": "Pink = not in today's game. Tap a character, then a row still works (today's flow); dragging is new.",
	"C": "Pink = not in today's game. Bonus teams are SeriesCatalog's preset trios; a Team is still 1-3 ids (SetTeam).",
}
FIGURES = "Figures: catalog base x team bonus (Preset +40% stamina, +10% cruise), no stat points, potions or gear. Sample roster."


def screen(art, masks, reqs, draw, foot, note, phone):
	P = Draw(PW, PH, 2, art, masks, reqs)
	draw(P)
	W, H = (844 * 2, 390 * 2) if phone else (1280, 720)
	S = Draw(W, H, 1, art, masks, reqs)
	if phone:
		foot += " (844 x 390, 2x)"
	if masks is None:
		for words, px in ((foot, 18 if phone else 20), (note, 16 if phone else 18), (FIGURES, 16)):
			S.text(ROUND, px, words, 0, 0)
		return None
	S.img[...] = bc.backdrop(W, H)
	if phone:
		k = min(0.96 * 844 / PW, 0.86 * 390 / PH) * 2
		pw, ph = int(round(PW * k)), int(round(PH * k))
		stamp(S.img, resize(P.img, pw, ph), (W - pw) // 2, 34)
		S.text(ROUND, 18, foot, 12, 16, anchor="l")
		S.text(ROUND, 16, note, 12, 34 + ph + 16, color=PINK, anchor="l")
	else:
		stamp(S.img, P.finish(), 40, 44)
		S.text(ROUND, 20, foot, 40, 20, anchor="l")
		S.text(ROUND, 18, note, 40, 682, color=PINK, anchor="l")
		S.text(ROUND, 16, FIGURES, 40, 704, color=SOFT, anchor="l")
	return S.img


# HUD -------------------------------------------------------------------------------------------------------------------------------
CELL_W, CELL_H, ICON, GAP = 84, 94, 72, 8  # Client/HudChrome CELL, ICON, GAP


def hud_cell(D, x, y, k, icon, label, key=None, badge=None, key_new=False):
	D.image(icon, x + CELL_W * k / 2, y + ICON * k / 2, ICON * k * 1.06)
	D.text(ROUND, 19 * k, label, x + CELL_W * k / 2, y + (CELL_H - 11) * k, stroke=2.5 * k)
	if key:
		D.text(ROUND, 16 * k, key, x + (CELL_W - 2) * k, y + 11 * k, color=PINK if key_new else WHITE, stroke=2 * k, anchor="r")
	if badge:
		disc(D, x + 12 * k, y + 8 * k, 13 * k, RED, stroke=2 * k, stroke_color=WHITE)
		D.text(ROUND, 16 * k, badge, x + 12 * k, y + 8 * k, stroke=0)


def hud(D, phone):
	W, H = D.w, D.h
	k = 0.68 if phone else 1
	D.rect(0, 0, W, H * 0.55, WHITE, grad=((120, 176, 226), (190, 222, 240)))
	D.rect(0, H * 0.5, W, H * 0.5, WHITE, grad=((118, 166, 84), (88, 134, 64)))
	D.rect(W * 0.32, H * 0.5, W * 0.36, H * 0.5, (196, 178, 150), alpha=0.85)
	x0 = 8 if phone else 14
	mid = H / 2 + (-20 if phone else -24)
	step = (CELL_H + GAP) * k
	top = mid - (3 * CELL_H + 2 * GAP) * k / 2
	for i, (icon, label, key, badge) in enumerate((("Index", "Index", "X", None), ("Items", "Items", "B", None), ("Rebirth", "Rebirth", "R", "5"))):
		hud_cell(D, x0, top + i * step, k, "hud_" + icon, label, key, badge)
	x1 = x0 + (CELL_W + GAP) * k
	boss_y, team_y = top + step / 2, top + step * 1.5
	# Guides: the gap centres the second column's cells are level with.
	for gy in (top + CELL_H * k + GAP * k / 2, top + step + CELL_H * k + GAP * k / 2):
		for dx in range(0, int((CELL_W * 2 + GAP) * k), 8):
			D.rect(x0 + dx, gy - 0.75, 4, 1.5, PINK, alpha=0.9)
	hud_cell(D, x1, boss_y, k, "hud_Boss", "Bosses")
	hud_cell(D, x1, team_y, k, "team1", "Team", "T", key_new=True)
	lx = x1 + CELL_W * k + 10 * k
	px, sw = (11, 1.2) if phone else (15, 2.0)
	new(D, "Bosses: moved here", lx, boss_y + CELL_H * k / 2 - px * 0.7, px=px, stroke=sw)
	D.text(ROUND, px, "level with Index / Items gap", lx, boss_y + CELL_H * k / 2 + px * 0.7, color=WHITE, stroke=sw, anchor="l")
	new(D, "Team: NEW button", lx, team_y + CELL_H * k / 2 - px * 1.4, px=px, stroke=sw)
	D.text(ROUND, px, "level with Items / Rebirth gap", lx, team_y + CELL_H * k / 2, color=WHITE, stroke=sw, anchor="l")
	new(D, "icon option 1, key T: proposed", lx, team_y + CELL_H * k / 2 + px * 1.4, px=px, stroke=sw)
	# Context: the right column, top-right pills, Money, the Team row, Auto / Upgrade and the TURBO bar.
	rx = W - (8 if phone else 14) - CELL_W * k
	rtop = mid - (2 * CELL_H + GAP) * k / 2
	hud_cell(D, rx, rtop, k, "hud_Quests", "Quests", "Q")
	hud_cell(D, rx, rtop + step, k, "hud_Shop", "Shop", "P")
	pw, ph = 104 * k, 34 * k
	for i, name in enumerate(("Settings", "Market", "Daily")):
		px0 = W - (8 if phone else 14) - (i + 1) * pw - i * 8 * k
		D.rect(px0, 10 * k, pw, ph, PANEL_DEEP, r=ph / 2, alpha=0.75, stroke=2 * k, stroke_color=NAVY)
		D.text(ROUND, 17 * k, name, px0 + pw / 2, 10 * k + ph / 2, stroke=2 * k)
	D.text(HEAVY, 34 * k, "$12.4M", x0 + 4 * k, H - 64 * k - 30, color=GREEN, stroke=3 * k, anchor="l")
	D.text(ROUND, 22 * k, "1,250 Gems", x0 + 4 * k, H - 32 * k - 30, color=(220, 140, 255), stroke=2.5 * k, anchor="l")
	bw = 380 * k
	bx, by = W / 2 - bw / 2, H - 34 * k - 24
	D.rect(bx, by, bw, 20 * k, (14, 18, 32), r=10 * k, stroke=2 * k, stroke_color=NAVY)
	D.rect(bx + 3 * k, by + 3 * k, bw * 0.42, 14 * k, GOLD, r=7 * k)
	D.text(ROUND, 14 * k, "TURBO LUCK", W / 2, by + 10 * k, stroke=2 * k)
	D.image("hud_AutoPlay", bx - 34 * k, by, 56 * k)
	D.image("hud_Upgrade", bx + bw + 34 * k, by, 56 * k)
	for i, cid in enumerate(("leaf_hero", "leaf_avenger", "leaf_medic")):
		cx, cy, r = W / 2 + (i - 1) * 74 * k, H - 86 * k - 24, 30 * k
		disc(D, cx, cy, r, (30, 34, 50), stroke=3 * k, stroke_color=(200, 206, 224))
		D.image(cid, cx, cy - 4 * k, 2.2 * r, clip=(cx - r, cy - r - 12 * k, 2 * r, 2 * r + 12 * k, r))
	D.text(ROUND, 15 * k, "★ TEAM SEVEN  +40% STAMINA  +10% SPEED", W / 2, H - 132 * k - 24, color=GOLD_HI, stroke=2 * k)
	return top, (3 * CELL_H + 2 * GAP) * k


def hud_screen(art, masks, reqs, phone):
	W, H = (844, 390) if phone else (1280, 720)
	D = Draw(W, H, 2, art, masks, reqs)
	foot = "HUD on a phone (844 x 390, 2x): both columns at the phone scale 0.68" if phone else "HUD 1280 x 720: Bosses and the new Team button in a second column right of Index, Items, Rebirth"
	note = "Pink = new or moved (design doc 4.40, owner 2026-11-12). Offsets, phone layout, Team icon and key T: proposed."
	if masks is None:
		hud(D, phone)
		D.text(ROUND, 16 if phone else 18, foot, 0, 0)
		D.text(ROUND, 13 if phone else 16, note, 0, 0)
		D.text(ROUND, 18, "1.6x zoom", 0, 0)
		return None
	top, col_h = hud(D, phone)
	if not phone:  # a 2x zoom of the two columns
		ss = D.ss
		y0 = int((top - 16) * ss)
		crop = D.img[y0 : y0 + int((col_h + 32) * ss), 0 : int(196 * ss)].copy()
		z = 1.6
		zoom = resize(crop, int(crop.shape[1] * z), int(crop.shape[0] * z))
		ix, iy = 720, 52
		D.rect(ix - 4, iy - 4, 196 * z + 8, (col_h + 32) * z + 8, WHITE, r=6)
		stamp(D.img, zoom, ix * ss, iy * ss)
		D.text(ROUND, 18, "1.6x zoom", ix + 10, iy + 16, anchor="l")
	D.rect(0, H - (22 if phone else 26), W, 26, (0, 0, 0), alpha=0.55)
	D.text(ROUND, 16 if phone else 18, foot, 8, 12, anchor="l", stroke=1.2 if phone else 2.0)
	D.text(ROUND, 13 if phone else 16, note, 8, H - (11 if phone else 13), color=PINK, anchor="l", stroke=1.0 if phone else 2.0)
	return D.img if phone else D.finish()


# Team icon options (Tab tilt: an object on the slanted cyan tab, thick dark outline, gradient, gloss) -----------------------
def icon_canvas(ss=3, size=512):
	n = size * ss
	Y, X = np.mgrid[0:n, 0:n].astype(np.float32)
	return base.canvas(n, n), (X + 0.5) / ss, (Y + 0.5) / ss, ss


def icov(d, ss):
	return np.clip(0.5 - d * ss, 0, 1)


def obj(img, Y, ss, d, top, bottom, y0, y1, ol=11):
	over(img, OUTLINE, icov(d - ol, ss))
	t = np.clip((Y - y0) / (y1 - y0), 0, 1)[..., None]
	over(img, np.asarray(top, np.float32) * (1 - t) + np.asarray(bottom, np.float32) * t, icov(d, ss))


def gloss(img, X, Y, ss, cx, cy, rx, ry, ang, alpha=0.45):
	c, s = np.cos(ang), np.sin(ang)
	u, v = ((X - cx) * c + (Y - cy) * s) / rx, (-(X - cx) * s + (Y - cy) * c) / ry
	over(img, WHITE, icov((np.hypot(u, v) - 1) * min(rx, ry), ss), alpha)


def tab(img, X, Y, ss):
	d = polygon(X, Y, [(88, 310), (450, 310), (415, 415), (55, 415)])
	obj(img, Y, ss, d, (40, 210, 255), (30, 130, 255), 310, 415)
	over(img, (170, 238, 255), icov(polygon(X, Y, [(100, 320), (436, 320), (434, 327), (98, 327)]), ss), 0.9)


def bust(img, X, Y, ss, cx, hy, hr, bw, bh, top, bottom, floor=342):
	hh = bh / 2
	body = np.maximum(rbox(X, Y, cx, hy + hr * 0.75 + hh, bw, hh, min(bw, hh) * 0.95), Y - floor)
	obj(img, Y, ss, body, top, bottom, hy + hr, floor)
	obj(img, Y, ss, circle(X, Y, cx, hy, hr), mix(top, WHITE, 0.2), top, hy - hr, hy + hr)
	for side in (-1, 1):
		e = np.hypot((X - cx - side * hr * 0.32) / (hr * 0.1), (Y - hy - hr * 0.08) / (hr * 0.17)) - 1
		over(img, OUTLINE, icov(e * hr * 0.1, ss))
	gloss(img, X, Y, ss, cx - hr * 0.4, hy - hr * 0.5, hr * 0.38, hr * 0.17, -0.6)


def icon_trio():
	img, X, Y, ss = icon_canvas()
	tab(img, X, Y, ss)
	bust(img, X, Y, ss, 146, 170, 50, 70, 128, (120, 235, 120), (30, 150, 70))
	bust(img, X, Y, ss, 366, 170, 50, 70, 128, (255, 140, 180), (205, 50, 110))
	bust(img, X, Y, ss, 256, 136, 62, 90, 150, (255, 222, 110), (240, 140, 30))
	return img


def icon_banner():
	img, X, Y, ss = icon_canvas()
	tab(img, X, Y, ss)
	board = rbox(X, Y, 256, 236, 168, 96, 30)
	obj(img, Y, ss, board, (255, 110, 110), (196, 36, 60), 140, 332)
	gloss(img, X, Y, ss, 150, 172, 56, 16, -0.25, 0.4)
	bar = rbox(X, Y, 256, 132, 190, 24, 20)
	obj(img, Y, ss, bar, GOLD_HI, GOLD_LOW, 108, 156)
	gloss(img, X, Y, ss, 150, 124, 60, 7, 0, 0.5)
	for i, cx in enumerate((168, 256, 344)):
		slot = circle(X, Y, cx, 244, 38)
		over(img, OUTLINE, icov(slot - 8, ss))
		over(img, (34, 30, 70), icov(slot, ss))
		fig = GOLD_HI if i == 1 else WHITE
		over(img, fig, icov(circle(X, Y, cx, 232, 12), ss))
		over(img, fig, icov(np.maximum(rbox(X, Y, cx, 268, 22, 20, 18), Y - 270), ss))
	return img


def icon_formation():
	img, X, Y, ss = icon_canvas()
	tab(img, X, Y, ss)
	pts = [(256, 116), (148, 262), (364, 262)]
	lines = np.minimum(np.minimum(base.segment(X, Y, *pts[0], *pts[1], 10), base.segment(X, Y, *pts[1], *pts[2], 10)), base.segment(X, Y, *pts[2], *pts[0], 10))
	over(img, OUTLINE, icov(lines - 8, ss))
	over(img, WHITE, icov(lines, ss))
	for i, (cx, cy) in enumerate(pts):
		r = 66 if i == 0 else 58
		top, bottom = ((255, 222, 110), (240, 140, 30)) if i == 0 else ((120, 220, 255), (40, 120, 230))
		obj(img, Y, ss, circle(X, Y, cx, cy, r), top, bottom, cy - r, cy + r)
		gloss(img, X, Y, ss, cx - r * 0.4, cy - r * 0.52, r * 0.36, r * 0.15, -0.6)
	return img


ICON_NUMBERS = [(HEAVY, 84, "1"), (HEAVY, 72, "2"), (HEAVY, 72, "3")]


def make_icons(masks):
	icons = {}
	for key, draw in (("team1", icon_trio), ("team2", icon_banner), ("team3", icon_formation)):
		icons[key] = base.finish(draw(), 512)
	for (font, px, words), (cx, cy) in zip(ICON_NUMBERS, [(256, 120), (148, 266), (364, 266)]):
		piece = base.text_image(masks[(font, px, words)], WHITE, 7)
		stamp(icons["team3"], piece, cx - piece.shape[1] / 2 - 2, cy - piece.shape[0] / 2)
	return icons


ICON_OPTIONS = [("team1", "Option 1: Trio", "three runners, the lead in front"), ("team2", "Option 2: Banner", "a plaque with 3 team slots"), ("team3", "Option 3: Formation", "run order 1, 2, 3 as a triangle")]


def icon_sheet(art, masks, reqs):
	W, H = 1280, 720
	D = Draw(W, H, 2, art, masks, reqs)
	D.rect(0, 0, W, H, (24, 26, 36))
	D.text(ROUND, 20, "Team button icon: 3 options in the Tab tilt style. Large, then at HUD size (72 px) beside Items and Bosses.", 40, 24, anchor="l")
	cw = 392
	for i, (key, title, sub) in enumerate(ICON_OPTIONS):
		x = 40 + i * (cw + 12)
		D.rect(x, 48, cw, 600, PANEL, r=16, stroke=2, stroke_color=GOLD_LOW, grad=(PANEL, PANEL_DEEP))
		D.text(HEAVY, 30, title, x + cw / 2, 80, color=GOLD_HI, stroke=2.5)
		D.text(ROUND, 18, sub, x + cw / 2, 112, color=SOFT)
		D.rect(x + 46, 130, 300, 300, (235, 236, 242), r=12)
		D.image(key, x + cw / 2, 280, 300)
		D.rect(x + 16, 446, cw - 32, 190, WHITE, r=12, grad=((120, 176, 226), (118, 166, 84)))
		for j, (icon, label, letter) in enumerate((("hud_Items", "Items", "B"), ("hud_Boss", "Bosses", None), (key, "Team", "T"))):
			hud_cell(D, x + 30 + j * 116, 470, 1, icon, label, letter, key_new=letter == "T")
		D.text(ROUND, 15, "dark ground:", x + 32, 590, color=WHITE, stroke=2, anchor="l")
		D.rect(x + 132, 568, 76, 56, (30, 26, 24), r=8)
		D.image(key, x + 170, 592, 50)
		D.rect(x + 216, 568, 76, 56, (196, 178, 150), r=8)
		D.image(key, x + 254, 592, 50)
	new(D, "Key letter proposed: T for Team. Taken: X B R Q P M; S walks back, I zooms, E and F open prompts. Icons are all new (proposed).", 40, 676, px=17)
	D.text(ROUND, 16, "Phone HUD shows the same icon at 0.68 (49 px).", 40, 700, color=SOFT, anchor="l")
	return None if masks is None else D.finish()


# Sheet -------------------------------------------------------------------------------------------------------------------------------
SHEET = [["hud_desktop", "hud_phone", "icon_options"], ["A_desktop", "A_phone", None], ["B_desktop", "B_phone", None], ["C_desktop", "C_phone", "C_edit"]]


def contact_sheet(shots, masks, reqs):
	cw, ch, lab, pad = 640, 360, 40, 16
	W, H = 3 * cw + 4 * pad, len(SHEET) * (ch + lab + pad) + pad
	S = Draw(W, H, 1, None, masks, reqs)
	legend = ["Pink text on a draft = not in", "today's game; needs a new rule", "before it is built."]
	if masks is None:
		for row in SHEET:
			for name in row:
				if name:
					S.text(ROUND, 26, name + ".png", 0, 0)
		for words in legend:
			S.text(ROUND, 26, words, 0, 0)
		return None
	over(S.img, (24, 26, 36), np.ones(S.img.shape[:2]))
	for r, row in enumerate(SHEET):
		for c, name in enumerate(row):
			x0, y0 = pad + c * (cw + pad), pad + r * (ch + lab + pad)
			if not name:
				if r == 1:
					for i, words in enumerate(legend):
						S.text(ROUND, 26, words, x0 + 20, y0 + lab + 60 + i * 40, color=PINK, anchor="l")
				continue
			S.text(ROUND, 26, name + ".png", x0 + 4, y0 + lab / 2, anchor="l")
			img = shots[name]
			h = int(round(img.shape[0] * cw / img.shape[1]))
			w = cw
			if h > ch:
				w, h = int(round(img.shape[1] * ch / img.shape[0])), ch
			stamp(S.img, resize(img, w, h), x0 + (cw - w) // 2, y0 + lab + (ch - h) // 2)
	return S.img


def render(art, masks, reqs):
	shots = {"hud_desktop": hud_screen(art, masks, reqs, False), "hud_phone": hud_screen(art, masks, reqs, True), "icon_options": icon_sheet(art, masks, reqs)}
	for letter, views in SCREENS.items():
		for view, draw, foot in views:
			shots[f"{letter}_{view}"] = screen(art, masks, reqs, draw, foot, NOTES[letter], view == "phone")
	return shots, contact_sheet(shots, masks, reqs)


def main():
	os.makedirs(OUT, exist_ok=True)
	bc.ART = ART  # bc.load_art reads its module's ART
	art = bc.load_art()
	reqs = set(ICON_NUMBERS)
	render(art, None, reqs)  # record pass: every text the drafts ask for
	masks = base.text_masks(sorted(reqs))
	art.update(make_icons(masks))
	shots, sheet = render(art, masks, reqs)
	for name, img in shots.items():
		base.write_png(os.path.join(OUT, name + ".png"), base.to_rgba8(img))
	base.write_png(os.path.join(OUT, "sheet.png"), base.to_rgba8(sheet))


if __name__ == "__main__":
	main()
