#!/usr/bin/env python3
# Draws The Golden King's boss UI art into assets/ui/boss_king/ (owner approval drafts, goal boss-king k5): the Dodge bar's
# Key of Babylon icon, the Fortified boss status icon, mock-up screens, and (with --sheet, run last) the labelled contact
# sheet ui_art_sheet.png of everything k5 delivers (icons, portraits, Relics, the Bosses card, mock-ups).
# Same method and helpers as draw_mage_ui.py: numpy signed distances, supersampled, flat cel colours, CoreText through `swift`.
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_king_ui.py [--sheet]
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_mage_ui as base  # noqa: E402
from draw_mage_ui import GOLD, GOLD_HI, GOLD_LOW, HEAVY, INK, NAVY, ROUND, WHITE, canvas, circle, finish, from_rgba8, grid, over, part, rbox, resize, ring, stamp, to_rgba8  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "boss_king")
NAME = "The Golden King"
NOTICE = "The Golden King has fortified his defenses"  # BOSS_EVENT_SPEC "The Golden King", proposed
RED = (255, 45, 45)  # BossDodgeUi's hit text


# 1. Key icon: the Key of Babylon, a flat gold key, long notched blade, round drum head over a geared cylinder ------------------
def draw_key(size=512, with_sdf=False):
	ss, half = 3, 1.9
	X, Y = grid(size, ss, half)
	tilt = np.radians(40)  # head to the upper right, held like the staff icon
	u = X * np.sin(tilt) - Y * np.cos(tilt) + 0.1  # along the key, blade tip at -u
	s = X * np.cos(tilt) + Y * np.sin(tilt) - 0.02  # across it, teeth on +s
	img = canvas(size * ss, size * ss)
	OL, BAND = 0.06, 0.05
	gold = (GOLD, GOLD_HI, GOLD_LOW)
	deep = (GOLD_LOW, GOLD, (150, 86, 18))
	# The geared cylinder behind the drum: a wide block with dark tooth grooves across it.
	gear = rbox(s, u, 0, 1.52, 0.4, 0.34, 0.05)
	part(img, gear, deep, OL, BAND)
	for k in range(5):
		over(img, INK, (np.abs(s - (-0.32 + k * 0.16)) < 0.025) & (gear < -0.03))
	# Blade with its bit: square teeth on one edge, a slot cut in from the other, a hole through it.
	blade = rbox(s, u, 0, -0.8, 0.13, 1.1, 0.03)
	for tu, th in ((-1.74, 0.22), (-1.5, 0.12), (-1.24, 0.28), (-0.96, 0.16)):
		blade = np.minimum(blade, rbox(s, u, 0.13 + th / 2, tu, th / 2, 0.085, 0.02))
	blade = np.maximum(blade, -rbox(s, u, -0.13, -1.38, 0.08, 0.07))  # the slot
	blade = np.maximum(blade, -rbox(s, u, 0, -0.5, 0.05, 0.11))  # the hole
	part(img, blade, gold, OL, BAND)
	# Collar, drum disc, its inner ring and hub.
	part(img, rbox(s, u, 0, 0.42, 0.23, 0.1, 0.03), gold, OL, BAND)
	disc = circle(s, u, 0, 1.02, 0.52)
	part(img, disc, gold, OL, BAND)
	part(img, ring(s, u, 0, 1.02, 0.36, 0.045), deep, 0.04, 0.03)
	part(img, circle(s, u, 0, 1.02, 0.13), deep, 0.04, 0.03)
	# Glint toward the screen's top left on the disc.
	glint = np.hypot((X - (np.sin(tilt) * 0.85 - 0.17)) / 0.09, (Y - (-np.cos(tilt) * 0.85 - 0.12)) / 0.055)
	over(img, (255, 250, 225), glint <= 1)
	whole = np.minimum.reduce([gear, blade, disc, rbox(s, u, 0, 0.42, 0.23, 0.1, 0.03)])
	return (img, whole) if with_sdf else img


# 2. Fortified status icon: a gold shield ring (the boss-side status under his HP bar, no seconds) ---------------------------------
def draw_status_fortified(size=128):
	img, x, y = base.status_base(size, (250, 197, 72), (203, 128, 30))
	shield = base.polygon(x, y, [(-0.56, -0.6), (0.56, -0.6), (0.56, -0.02), (0.0, 0.64), (-0.56, -0.02)]) - 0.02
	base.glyph(img, np.abs(shield + 0.14) - 0.085)  # the shield's outline as a ring
	base.glyph(img, circle(x, y, 0, -0.08, 0.1))
	return img


# 3. Mock-ups -------------------------------------------------------------------------------------------------------------------
def arena_vault(m):
	"""The colosseum shell in its vault dressing: sandstone arches over treasure mounds (design doc 4.37, proposed)."""
	w, h = m.w, m.h
	m.rect(0, 0, w, h, (34, 24, 18))
	m.rect(0, h * 0.26, w, h * 0.26, (176, 140, 88))  # sandstone wall band
	step = h * 0.16
	for i in range(int(w / step) + 2):  # pointed arch openings along the band
		cx, top = i * step + step / 2, h * 0.3
		arch = np.minimum(circle(m.x, m.y, cx, top + step * 0.22, step * 0.22), base.polygon(m.x, m.y, [(cx - step * 0.22, top + step * 0.22), (cx, top - step * 0.05), (cx + step * 0.22, top + step * 0.22)]))
		arch = np.minimum(arch, rbox(m.x, m.y, cx, top + step * 0.6, step * 0.22, step * 0.38))
		over(m.img, (58, 38, 26), arch <= 0)
		over(m.img, (214, 180, 120), (np.abs(arch) <= step * 0.03) & (arch <= 0.5))
	m.rect(0, h * 0.52, w, h * 0.02, (90, 62, 30))
	m.rect(0, h * 0.54, w, h * 0.46, (120, 92, 40))  # a floor of gold under the lanes
	m.rect(0, h * 0.54, w, h * 0.1, (160, 124, 52))


def boss_bar(m, phone, name=NAME):
	"""draw_mage_ui.boss_bar with the boss's name; returns the track's bottom and its left edge."""
	k = 375 / 900 if phone else 720 / 900
	w = min(max(m.w * 0.62, 280), m.w - 156)
	x0, top = (m.w - w) / 2, 8
	title, track = round(40 * k), round(48 * k * 1.25)
	m.text(HEAVY, title, name, m.w / 2, top + title / 2, stroke=2)
	ty = top + title + 2
	m.rect(x0, ty, w, track, (50, 50, 55), round_=4, stroke=2, stroke_color=(255, 214, 90))
	fill_w = w * 0.72
	d = rbox(m.x, m.y, x0 + fill_w / 2, ty + track / 2, fill_w / 2, track / 2, 4)
	over(m.img, np.where((m.y < ty + track / 2)[..., None], (255, 70, 80), (150, 14, 40)), d <= 0)
	m.text(ROUND, round(48 * k * 0.62), "72%", m.w / 2, ty + track / 2, stroke=2)
	return ty + track, x0


def dodge_bar(m, phone):
	"""The Dodge bar with the key at its left end; returns (y0, height)."""
	w, h = m.w, m.h
	width = min(640, w * 0.58)
	height = 24 if phone else 36
	bottom = h - 130
	x0, y0 = (w - width) / 2, bottom - height
	m.rect(x0, y0, width, height, (24, 18, 12), alpha=0.8, round_=height * 0.3, stroke=2)
	spot, slider = 0.68, 0.47
	sw = width * 0.125
	sx = x0 + width * spot
	t = np.clip(np.abs(m.x - sx) / (sw / 2), 0, 1)[..., None]
	spot_rgb = np.array(WHITE) * (1 - t) + np.array(GOLD) * t
	over(m.img, spot_rgb, (np.abs(m.x - sx) <= sw / 2) & (np.abs(m.y - (y0 + height / 2)) <= height * 0.45))
	m.rect(x0 + width * slider - 3, y0 + height / 2 - height * 0.75, 6, height * 1.5, WHITE, stroke=1.5, stroke_color=(0, 0, 0))
	m.image("key_icon", x0, y0 + height / 2, height * 2.2)
	return x0, y0, height


def mock_dodge(art, masks, w, h, phone):
	ss = 3 if phone else 2
	m = base.Mock(w, h, ss, art, masks)
	arena_vault(m)
	boss_bar(m, phone)
	_, y0, height = dodge_bar(m, phone)
	words = 18 if phone else 26
	prompt = "Tap when the bar hits the white!" if phone else "Press SPACE when the bar hits the white!"
	m.text(HEAVY, words, prompt, w / 2, y0 - height * 0.7 - words / 2)
	return m.finish()


def mock_notice(art, masks, w, h):
	"""Shield Gates: the Fortified icon under his HP bar and the notice in the hit text's red at the Dodge bar's place."""
	m = base.Mock(w, h, 2, art, masks)
	arena_vault(m)
	below, x0 = boss_bar(m, False)
	cell = 72  # BossEventUi BOSS_ICON
	m.rect(x0, below + 8, cell, cell, (16, 22, 42), alpha=0.75, round_=10)
	m.image("status_fortified", x0 + cell / 2, below + 8 + cell / 2, cell - 12)
	m.text(HEAVY, 40, NOTICE, w / 2, h - 130 - 18, color=RED, stroke=3)
	return m.finish()


# 4. Contact sheet --------------------------------------------------------------------------------------------------------------
LIGHT, DARK, GREY = (235, 236, 242), (32, 43, 71), (58, 62, 76)
PORTRAITS = ("portrait", "head", "side_king_portrait", "side_king_head", "side_mage_portrait", "side_mage_head")
SCREENS = (("boss_king/mock_dodge_bar_desktop", 1280, 720), ("boss_king/mock_dodge_bar_phone", 667, 375), ("boss_king/mock_fortified_notice", 1280, 720), ("boss_cards_draft/B_king_live", 1280, 720))


def load(paths):
	"""{name: premultiplied float RGBA} through draw_boss_cards' CoreGraphics loader."""
	import draw_boss_cards as cards

	cards.ART = {name: os.path.join("assets", "ui", rel + ".png") for name, rel in paths.items()}
	return cards.load_art()


def label(sheet, masks, words, x, y, color=WHITE):
	piece = base.text_image(masks[(ROUND, 26, words)], color, 2)
	stamp(sheet, piece, x, y)


def sheet(art, hires, masks):
	pad, lab = 24, 40
	W = 2640
	rows = []
	# Icons: the mage sheet's cell, 512 on light then 128 and 64 on dark.
	icons = canvas(W, lab + 512 + 2 * pad)
	over(icons, GREY, np.ones(icons.shape[:2]))
	for i, name in enumerate(("key_icon", "status_fortified")):
		x0 = pad + i * 1000
		for j, bg in enumerate((LIGHT, DARK)):
			block = canvas(512 if j == 0 else 280, 512 + pad)
			over(block, bg, np.ones(block.shape[:2]))
			stamp(icons, block, x0 + j * (512 + pad), lab + pad - pad // 2)
		stamp(icons, hires[name], x0, lab + pad)
		stamp(icons, resize(art[name], 128, 128), x0 + 512 + 2 * pad, lab + pad + 192)
		stamp(icons, resize(art[name], 64, 64), x0 + 512 + 3 * pad + 128, lab + pad + 224)
		label(icons, masks, name + ".png", x0, 6)
	rows.append(icons)
	# Portraits at 256 on light, each head also at 60 (the Team minibar's size).
	ports = canvas(W, lab + 256 + 2 * pad)
	over(ports, GREY, np.ones(ports.shape[:2]))
	for i, name in enumerate(PORTRAITS):
		x0 = pad + i * 430
		block = canvas(256 + 80, 256 + pad)
		over(block, LIGHT if i % 2 == 0 else DARK, np.ones(block.shape[:2]))
		stamp(ports, block, x0, lab + pad // 2)
		stamp(ports, resize(art[name], 256, 256), x0, lab + pad)
		if name.endswith("head"):
			stamp(ports, resize(art[name], 60, 60), x0 + 256 + 10, lab + pad + 196)
		label(ports, masks, name + ".png", x0, 6)
	rows.append(ports)
	# The Relic sheet as drawn by draw_relics.py king, then the screens at 640 wide.
	relics = art["relic_sheet"]
	band = canvas(W, lab + relics.shape[0] + 2 * pad)
	over(band, GREY, np.ones(band.shape[:2]))
	stamp(band, relics, pad, lab + pad)
	label(band, masks, "relic_king_art_sheet.png (draw_relics.py king)", pad, 6)
	rows.append(band)
	screens = canvas(W, lab + 360 + 2 * pad)
	over(screens, GREY, np.ones(screens.shape[:2]))
	for i, (name, w, h) in enumerate(SCREENS):
		x0 = pad + i * (640 + 16)
		hh = int(round(h * 640 / w))
		stamp(screens, resize(art[name], 640, hh), x0, lab + pad + (360 - hh) // 2)
		label(screens, masks, name + ".png", x0, 6)
	rows.append(screens)
	H = sum(r.shape[0] for r in rows)
	out = canvas(W, H)
	y = 0
	for r in rows:
		stamp(out, r, 0, y)
		y += r.shape[0]
	return out


def draw_sheet():
	paths = {"key_icon": "boss_king/key_icon", "status_fortified": "boss_king/status_fortified", "relic_sheet": "relic_king_art_sheet"}
	paths.update({name: "boss_king/" + name for name in PORTRAITS})
	paths.update({name: name for name, _, _ in SCREENS})
	art = load(paths)
	hires = {"key_icon": finish(draw_key(512), 512), "status_fortified": finish(draw_status_fortified(512), 512)}
	words = [n + ".png" for n in ("key_icon", "status_fortified", *PORTRAITS)] + [n + ".png" for n, _, _ in SCREENS] + ["relic_king_art_sheet.png (draw_relics.py king)"]
	masks = base.text_masks([(ROUND, 26, w) for w in words])
	base.write_png(os.path.join(OUT, "ui_art_sheet.png"), to_rgba8(sheet(art, hires, masks)))


def main():
	os.makedirs(OUT, exist_ok=True)
	if "--sheet" in sys.argv:
		draw_sheet()
		return
	art = {}
	for name, draw, size in (("key_icon", draw_key, 512), ("status_fortified", draw_status_fortified, 128)):
		art[name] = from_rgba8(to_rgba8(finish(draw(size), size, os.path.join(OUT, name + ".png"))))
	reqs = set()
	for phone, ss in ((False, 2), (True, 3)):  # every (font, px * ss, text) the mock-ups ask Mock.text for
		k = 375 / 900 if phone else 720 / 900
		items = [(HEAVY, round(40 * k), NAME), (ROUND, round(48 * k * 0.62), "72%")]
		items.append((HEAVY, 18, "Tap when the bar hits the white!") if phone else (HEAVY, 26, "Press SPACE when the bar hits the white!"))
		reqs |= {(f, round(px * ss), t) for f, px, t in items}
	reqs.add((HEAVY, 40 * 2, NOTICE))
	masks = base.text_masks(sorted(reqs))
	for size, h, phone, tag in ((1280, 720, False, "desktop"), (667, 375, True, "phone")):
		base.write_png(os.path.join(OUT, f"mock_dodge_bar_{tag}.png"), to_rgba8(mock_dodge(art, masks, size, h, phone)))
	base.write_png(os.path.join(OUT, "mock_fortified_notice.png"), to_rgba8(mock_notice(art, masks, 1280, 720)))


if __name__ == "__main__":
	main()
