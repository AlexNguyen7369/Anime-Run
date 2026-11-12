#!/usr/bin/env python3
# Draws three layout drafts of the "Bosses" card popup (owner approval drafts, goal boss-mage-2 g1) into
# assets/ui/boss_cards_draft/: A (two tall cards), B (one big card and a side strip), C (horizontal rows), each live, idle
# and at a phone's 844 x 390, plus a labelled contact sheet. Reuses draw_mage_ui.py's canvas, text (CoreText through
# `swift`) and PNG helpers. Portraits and reward art are loaded through CoreGraphics (no Pillow in these Pythons).
# /Applications/Blender.app/Contents/Resources/*/python/bin/python3* tools/blender/portrait/draw_boss_cards.py [king]
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_mage_ui as base  # noqa: E402
from draw_mage_ui import GOLD, GOLD_HI, GOLD_LOW, HEAVY, NAVY, ROUND, WHITE, over, rbox, resize, stamp  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "ui", "boss_cards_draft")
ART = {
	"raga": "assets/characters_avatar/side_raga/portrait.png",  # BossCatalog: Big Raga's Portrait is side_raga's
	"mage": "assets/characters_avatar/boss_mage/portrait.png",
	"king": "assets/ui/boss_king/portrait.png",  # k5 draft; assets/characters_avatar/boss_king/portrait.png once approved
	"chest_raga": "assets/ui/chest_raga.png",
	"chest_king": "assets/ui/chest_king.png",
	"chest_adapted": "assets/ui/chest_adapted.png",
	"gem": "assets/ui/gem.png",
}

PANEL, PANEL_DEEP, ROW, MUTED = (32, 43, 71), (16, 22, 42), (41, 55, 83), (104, 111, 135)  # UiTheme.Palette
CYAN, PINK, GREEN, GREEN_DEEP = (90, 220, 255), (255, 92, 160), (60, 230, 90), (16, 160, 70)
SOFT = (200, 206, 224)
PW, PH = 1200, 620  # the standard popup

BOSSES = {
	"raga": {
		"name": "Big Raga",
		"sub": "2 phases",  # BossCatalog Stages
		"top": 0.0,  # empty share at the top of the portrait
		"rewards": [("chest_raga", "1x"), ("money", "100K"), ("chest_adapted", "1x"), ("gem", "1K")],
	},
	"mage": {"name": "The Elf Mage", "sub": "1 phase", "top": 0.36, "rewards": [("chest_raga", "1x"), ("money", "100K")]},
	# top None: measured from the portrait; gap: the card's top kept clear of the drawn part, so the name block never crosses his hair
	"king": {"name": "The Golden King", "sub": "1 phase", "top": None, "gap": 180, "rewards": [("chest_king", "1x"), ("money", "100K")], "line": "The Golden King is judging you right now"},
}
# Per draft state: each boss's card state. live: the running boss; next: the idle timer's boss; off: "Not this time".
STATES = {"live": {"mage": "live", "raga": "off"}, "idle": {"raga": "next", "mage": "off"}, "king": {"king": "live", "raga": "off", "mage": "off"}}
MAIN = {"live": "mage", "idle": "raga", "king": "king"}  # the big card's boss per state
FOOT = {"live": "The Elf Mage live", "idle": "no event, Big Raga next", "king": "The Golden King live (k5 draft, draft B with 3 bosses)"}
TIME_LEFT, TIME_FRAC, NEXT_IN = "5:12 left", 312 / 480, "Next event in 12:34"
NOT_THIS_TIME = "Not this time*"  # * proposal, footnoted on the screen

LOAD_SWIFT = r"""
import AppKit
var out = Data()
for p in CommandLine.arguments.dropFirst() {
	var r = NSRect.zero
	let cg = NSImage(contentsOfFile: p)!.cgImage(forProposedRect: &r, context: nil, hints: nil)!
	let w = cg.width, h = cg.height
	let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
		space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
	ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
	out.append("\(w) \(h)\n".data(using: .utf8)!)
	out.append(Data(bytes: ctx.data!, count: w * h * 4))
}
FileHandle.standardOutput.write(out)
"""


def load_art():
	"""{key: premultiplied float RGBA} for every ART file, in one swift run."""
	with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as f:
		f.write(LOAD_SWIFT)
	try:
		paths = [os.path.join(ROOT, p) for p in ART.values()]
		data = subprocess.run(["swift", f.name, *paths], capture_output=True, check=True).stdout
	finally:
		os.unlink(f.name)
	art, at = {}, 0
	for key in ART:
		end = data.index(b"\n", at)
		w, h = map(int, data[at:end].split())
		art[key] = np.frombuffer(data, np.uint8, w * h * 4, end + 1).reshape(h, w, 4).astype(np.float32) / 255
		at = end + 1 + w * h * 4
	return art


class Draw:
	"""A supersampled canvas in design px. With masks None it only records the text it would ask for."""

	def __init__(self, w, h, ss, art, masks, reqs):
		self.w, self.h, self.ss, self.art, self.masks, self.reqs = w, h, ss, art, masks, reqs
		self.img = None if masks is None else base.canvas(w * ss, h * ss)

	def win(self, x0, y0, x1, y1):
		ss = self.ss
		ax, ay = max(int(x0 * ss), 0), max(int(y0 * ss), 0)
		bx, by = min(int(np.ceil(x1 * ss)), self.w * ss), min(int(np.ceil(y1 * ss)), self.h * ss)
		Y, X = np.mgrid[ay:by, ax:bx].astype(np.float32)
		return self.img[ay:by, ax:bx], (X + 0.5) / ss, (Y + 0.5) / ss

	def cov(self, d):
		return np.clip(0.5 - d * self.ss, 0, 1)

	def rect(self, x, y, w, h, color, r=0.0, alpha=1.0, stroke=0.0, stroke_color=NAVY, grad=None, glow=None):
		if self.img is None:
			return
		pad = max(stroke, glow[1] * 4 if glow else 0) + 2
		sub, X, Y = self.win(x - pad, y - pad, x + w + pad, y + h + pad)
		d = rbox(X, Y, x + w / 2, y + h / 2, w / 2, h / 2, r)
		if glow:
			over(sub, glow[0], np.exp(-np.maximum(d, 0) / glow[1]) * (d > 0), glow[2])
		if stroke:
			over(sub, stroke_color, self.cov(d - stroke), alpha)
		if grad:
			t = np.clip((Y - y) / h, 0, 1)[..., None]
			color = np.asarray(grad[0], np.float32) * (1 - t) + np.asarray(grad[1], np.float32) * t
		over(sub, color, self.cov(d), alpha)

	def dots(self, x, y, w, h, r, color, alpha, step=11):
		"""Halftone dots clipped to the rounded box, growing toward the bottom (the reference's dotted card)."""
		if self.img is None:
			return
		sub, X, Y = self.win(x, y, x + w, y + h)
		fx, fy = np.mod(X - x, step) - step / 2, np.mod(Y - y, step) - step / 2
		rad = 0.6 + 2.2 * np.clip((Y - y) / h, 0, 1)
		over(sub, color, self.cov(np.hypot(fx, fy) - rad) * self.cov(rbox(X, Y, x + w / 2, y + h / 2, w / 2, h / 2, r)), alpha)

	def dim(self, x, y, w, h, r, amount):
		"""Grey and darken the box: the not-live look."""
		if self.img is None:
			return
		sub, X, Y = self.win(x, y, x + w, y + h)
		m = (self.cov(rbox(X, Y, x + w / 2, y + h / 2, w / 2, h / 2, r)) * amount)[..., None]
		lum = (sub[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32))[..., None] * 0.5
		sub[..., :3] = sub[..., :3] * (1 - m) + lum * m

	def image(self, key, cx, cy, size, clip=None, alpha=1.0):
		"""A square art file centred at (cx, cy), size px wide, optionally clipped to a rounded box (x, y, w, h, r)."""
		if self.img is None:
			return
		px = max(1, int(round(size * self.ss)))
		piece = resize(self.art[key], px, px) * alpha
		x0, y0 = int(round(cx * self.ss - px / 2)), int(round(cy * self.ss - px / 2))
		if clip:
			yy, xx = np.mgrid[y0 : y0 + px, x0 : x0 + px].astype(np.float32)
			x, y, w, h, r = clip
			piece = piece * self.cov(rbox((xx + 0.5) / self.ss, (yy + 0.5) / self.ss, x + w / 2, y + h / 2, w / 2, h / 2, r))[..., None]
		stamp(self.img, piece, x0, y0)

	def text(self, font, px, words, x, y, color=WHITE, stroke=2.0, anchor="c", alpha=1.0):
		"""Draws words with its vertical centre at y; anchor c, l or r on x. Returns the width in design px."""
		key = (font, round(px * self.ss), words)
		if self.masks is None:
			self.reqs.add(key)
			return len(words) * px * 0.55
		mask = self.masks[key]
		inner = int(key[1] * 0.15)  # the swift snippet's side padding
		width = (mask.shape[1] - 2 * inner) / self.ss
		piece = base.text_image(mask, color, stroke * self.ss, alpha=alpha)
		left = {"c": x - width / 2, "l": x, "r": x - width}[anchor]
		spad = int(np.ceil(stroke * self.ss))
		stamp(self.img, piece, left * self.ss - inner - spad, y * self.ss - piece.shape[0] / 2)
		return width

	def finish(self):
		ss = self.ss
		return self.img.reshape(self.h, ss, self.w, ss, 4).mean(axis=(1, 3))


# Shared pieces -------------------------------------------------------------------------------------------------------------
def panel(D):
	"""The popup frame: gold edge, navy body, header plate with BOSSES and the red X."""
	D.rect(0, 0, PW, PH, GOLD_LOW, r=18)
	D.rect(4, 4, PW - 8, PH - 8, PANEL, r=15, stroke=2, stroke_color=GOLD, grad=(PANEL, PANEL_DEEP))
	D.rect(14, 10, PW - 28, 52, PANEL_DEEP, r=12, alpha=0.9, stroke=2, stroke_color=GOLD_LOW)
	D.text(HEAVY, 40, "BOSSES", 34, 36, color=GOLD_HI, stroke=3, anchor="l")
	D.rect(PW - 66, 12, 48, 48, (255, 70, 80), r=10, stroke=3, grad=((255, 90, 100), (190, 30, 50)))
	D.text(ROUND, 34, "X", PW - 42, 36, stroke=2.5)


def button(D, x, y, w, h, words, kind, px=26):
	look = {
		"go": ((110, 255, 120), GREEN_DEEP, NAVY),
		"details": (ROW, PANEL_DEEP, CYAN),
		"spawn": (GOLD_HI, GOLD_LOW, NAVY),
		"off": ((90, 94, 110), (60, 62, 74), NAVY),
	}[kind]
	D.rect(x, y, w, h, look[0], r=min(12, h / 2), stroke=2.5, stroke_color=look[2], grad=look[:2])
	D.text(ROUND if kind != "go" else HEAVY, px, words, x + w / 2, y + h / 2, color=WHITE if kind != "off" else SOFT, stroke=2.5)


def pill(D, x, y, state, px=22):
	"""The state tag at (x, y) top left; returns its width."""
	if state == "off":
		return 0
	words, color = ("LIVE", PINK) if state == "live" else ("NEXT", GOLD_LOW)
	w = D.text(HEAVY, px, words, -1000, -1000) + (44 if state == "live" else 28)  # measure (drawn off-canvas)
	h = px + 12
	D.rect(x, y, w, h, color, r=h / 2, stroke=2)
	tx = x + 14
	if state == "live":
		D.rect(x + 12, y + h / 2 - 6, 12, 12, WHITE, r=6)
		tx = x + 30
	D.text(HEAVY, px, words, tx, y + h / 2, anchor="l", stroke=1.5)
	return w


def card_back(D, x, y, w, h, state, r=16):
	live = state == "live"
	glow = (CYAN, 7, 0.9) if live else None
	edge = CYAN if live else MUTED
	D.rect(x, y, w, h, (20, 40, 72), r=r, stroke=3, stroke_color=edge, grad=((22, 34, 66), (40, 150, 170)), glow=glow)
	D.dots(x, y, w, h, r, (190, 250, 255), 0.18)


def state_bar(D, x, y, w, h, state, px=24):
	"""Time left (live), the next event's countdown (next) or the neutral line (off)."""
	D.rect(x, y, w, h, (14, 18, 32), r=h / 2, alpha=0.9, stroke=2.5, stroke_color=GOLD if state != "off" else MUTED)
	if state == "live":
		D.rect(x + 3, y + 3, (w - 6) * TIME_FRAC, h - 6, CYAN, r=(h - 6) / 2, grad=((150, 240, 255), (40, 150, 220)))
		D.text(ROUND, px, TIME_LEFT, x + w / 2, y + h / 2, stroke=2.5)
	elif state == "next":
		D.text(ROUND, px, NEXT_IN, x + w / 2, y + h / 2, color=GOLD_HI, stroke=2.5)
	else:
		D.text(ROUND, px, NOT_THIS_TIME, x + w / 2, y + h / 2, color=SOFT, stroke=2)


def tile(D, x, y, s, key, count):
	D.rect(x, y, s, s, (14, 24, 52), r=10, stroke=2.5, stroke_color=(47, 107, 255), grad=((40, 60, 110), (14, 24, 52)))
	if key == "money":
		D.text(HEAVY, round(s * 0.5), "$", x + s / 2, y + s * 0.44, color=(60, 255, 60), stroke=2.5)
	else:
		D.image(key, x + s / 2, y + s / 2, s * 0.86)
	D.text(ROUND, 20, count, x + s - 6, y + s - 13, anchor="r", stroke=2.5)


def rewards(D, x, y, w, boss, s=72, label=True, per_row=4):
	"""The Rewards strip at (x, y) and its tiles under it; returns the bottom."""
	if label:
		D.rect(x, y, w, 32, PANEL_DEEP, r=8, alpha=0.85)
		D.text(ROUND, 22, "Rewards", x + 12, y + 16, anchor="l", stroke=2)
		y += 40
	for i, (key, count) in enumerate(BOSSES[boss]["rewards"]):
		tile(D, x + i % per_row * (s + 10), y + i // per_row * (s + 10), s, key, count)


def portrait(D, boss, cx, bottom, avail, max_w, clip):
	"""The boss's drawn portrait standing on `bottom`, its drawn part at most `avail` tall."""
	top = BOSSES[boss]["top"]
	if top is None:
		a = D.art[boss][..., 3]
		top = float((a.max(axis=1) > 0.1).argmax()) / a.shape[0]
	size = min(max_w, avail / (1 - top))
	D.image(boss, cx, bottom - size / 2, size, clip=clip)


def name_block(D, x, y, boss, big=34, small=22):
	D.text(HEAVY, big, BOSSES[boss]["name"], x, y, stroke=3, anchor="l")
	D.text(ROUND, small, BOSSES[boss]["sub"], x + 2, y + big * 0.5 + small * 0.75, color=CYAN, stroke=2, anchor="l")


def info_plate(D, x, y, w, h, live):
	"""The panel's own column: the random pick and the paid Spawn boss button (offered only with no event)."""
	D.rect(x, y, w, h, PANEL_DEEP, r=14, alpha=0.9, stroke=2, stroke_color=MUTED)
	cx = x + w / 2
	D.text(ROUND, 24, "Each event picks", cx, y + 36, color=SOFT)
	D.text(ROUND, 24, "one boss at random", cx, y + 66, color=SOFT)
	button(D, x + 24, y + h - 84, w - 48, 60, "Spawn boss", "off" if live else "spawn", px=30)
	if live:
		D.text(ROUND, 20, "Not during an event", cx, y + h - 104, color=SOFT)


def dim_amount(state):
	return {"live": 0.0, "next": 0.45, "off": 0.75}[state]


# Draft A: two tall cards side by side, rewards under each ----------------------------------------------------------------------
def card_tall(D, x, y, w, h, boss, state):
	r = 16
	card_back(D, x, y, w, h, state, r)
	bar_y = y + h - 196
	portrait(D, boss, x + w / 2, bar_y + 24, bar_y + 24 - (y + 116), w - 30, (x, y, w, h, r))
	D.rect(x + 10, y + 10, w - 20, 44, PANEL_DEEP, r=10, alpha=0.85)
	pill(D, x + 18, y + 15, state)
	name_block(D, x + 18, y + 84, boss)
	D.dim(x, y, w, h, r, dim_amount(state))
	button(D, x + w - 124, y + 15, 108, 34, "Details", "details", px=22)
	go_w = 100 if state == "live" else 0
	state_bar(D, x + 14, bar_y, w - 28 - go_w - (10 if go_w else 0), 44, state)
	if go_w:
		button(D, x + w - 14 - go_w, bar_y - 3, go_w, 50, "Go", "go", px=30)
	rewards(D, x + 14, y + h - 140, w - 28, boss)


def draft_a(D, state):
	panel(D)
	st = STATES[state]
	card_tall(D, 36, 80, 380, 512, "mage", st["mage"])
	card_tall(D, 436, 80, 380, 512, "raga", st["raga"])
	info_plate(D, 840, 80, 324, 512, state == "live")


# Draft B: one big card for the live or next boss, a side strip for the other -------------------------------------------------
def card_big(D, x, y, w, h, boss, state):
	r = 18
	card_back(D, x, y, w, h, state, r)
	portrait(D, boss, x + 250, y + h - 6, h - BOSSES[boss].get("gap", 136), 440, (x, y, w, h, r))
	D.rect(x + 10, y + 10, w - 20, 48, PANEL_DEEP, r=10, alpha=0.85)
	pill(D, x + 18, y + 17, state, px=24)
	if state == "live" and "line" in BOSSES[boss]:  # the boss's ActiveText, in the header plate between the tag and Details
		D.text(ROUND, 20, BOSSES[boss]["line"], x + 150, y + 34, color=SOFT, anchor="l")
	name_block(D, x + 20, y + 94, boss, big=44, small=26)
	D.dim(x, y, w, h, r, dim_amount(state))
	button(D, x + w - 130, y + 16, 114, 36, "Details", "details", px=22)
	cx, cw = x + w - 250, 230
	if state == "live":
		state_bar(D, cx, y + 150, cw, 48, state, px=26)
		button(D, cx, y + 210, cw, 64, "Go", "go", px=38)
	else:
		state_bar(D, cx, y + 180, cw, 48, state, px=22)
	rewards(D, cx, y + h - 230, cw, boss, s=78, per_row=2)


def card_small(D, x, y, w, h, boss, state):
	r = 14
	card_back(D, x, y, w, h, state, r)
	f = 170
	portrait(D, boss, x + 10 + f / 2, y + h - 10, h - 20, 999, (x + 10, y + 10, f, h - 20, 12))
	tx = x + f + 22
	name_block(D, tx, y + 40, boss, big=26, small=20)
	D.dim(x, y, w, h, r, dim_amount(state))
	state_bar(D, tx, y + 96, x + w - 14 - tx, 40, state, px=22)
	button(D, x + w - 124, y + h - 50, 108, 34, "Details", "details", px=22)


def card_compact(D, x, y, w, h, boss, state):
	"""card_small for a strip of two: a smaller portrait, the state pill and Details side by side."""
	r = 14
	card_back(D, x, y, w, h, state, r)
	f = 120
	portrait(D, boss, x + 10 + f / 2, y + h - 10, h - 20, 999, (x + 10, y + 10, f, h - 20, 12))
	tx = x + f + 22
	name_block(D, tx, y + 36, boss, big=24, small=18)
	D.dim(x, y, w, h, r, dim_amount(state))
	state_bar(D, tx, y + h - 48, 122, 34, state, px=16)
	button(D, x + w - 112, y + h - 48, 100, 34, "Details", "details", px=20)


def draft_b(D, state):
	panel(D)
	st = STATES[state]
	main = MAIN[state]
	others = [b for b in st if b != main]
	card_big(D, 36, 80, 720, 512, main, st[main])
	if len(others) == 1:
		card_small(D, 776, 80, 388, 210, others[0], st[others[0]])
		info_plate(D, 776, 306, 388, 286, st[main] == "live")
	else:  # three bosses: two compact cards in the strip, the info box under them
		for i, other in enumerate(others):
			card_compact(D, 776, 80 + i * 160, 388, 150, other, st[other])
		info_plate(D, 776, 400, 388, 192, st[main] == "live")


# Draft C: horizontal cards in a vertical list --------------------------------------------------------------------------------
def card_row(D, x, y, w, h, boss, state):
	r = 16
	card_back(D, x, y, w, h, state, r)
	portrait(D, boss, x + h / 2, y + h - 10, h - 20, 999, (x + 10, y + 10, h - 20, h - 20, 12))
	pw = pill(D, x + h + 10, y + 18, state)
	name_block(D, x + h + 10 + (pw + 12 if pw else 0), y + 34, boss)
	D.dim(x, y, w, h, r, dim_amount(state))
	bx, bw = x + h + 10, 330
	state_bar(D, bx, y + 106, bw, 46, state)
	if state == "live":
		button(D, bx + bw + 12, y + 102, 110, 54, "Go", "go", px=32)
	button(D, x + w - 130, y + 16, 114, 36, "Details", "details", px=22)
	rewards(D, x + 720, y + 66, 380, boss, s=82, label=False)
	D.text(ROUND, 22, "Rewards", x + 720, y + 36, anchor="l", stroke=2)


def draft_c(D, state):
	panel(D)
	st = STATES[state]
	card_row(D, 36, 80, 1128, 200, "mage", st["mage"])
	card_row(D, 36, 296, 1128, 200, "raga", st["raga"])
	D.rect(36, 512, 1128, 80, PANEL_DEEP, r=14, alpha=0.9, stroke=2, stroke_color=MUTED)
	D.text(ROUND, 24, "Each event picks one boss at random", 60, 552, color=SOFT, anchor="l")
	button(D, 1164 - 260, 522, 244, 60, "Spawn boss", "off" if state == "live" else "spawn", px=30)
	if state == "live":
		D.text(ROUND, 20, "Not during an event", 1164 - 276, 552, color=SOFT, anchor="r")


DRAFTS = {"A": draft_a, "B": draft_b, "C": draft_c}


# Screens ---------------------------------------------------------------------------------------------------------------------
def backdrop(w, h):
	"""A dimmed dusk stand-in for the game behind the popup."""
	img = base.canvas(w, h)
	t = np.linspace(0, 1, h, dtype=np.float32)[:, None, None]
	img[..., :3] = (np.array([70, 52, 70], np.float32) * (1 - t) + np.array([40, 34, 30], np.float32) * t) / 255 * 0.55
	img[..., 3] = 1
	return img


def note(D, words, x, y, color=PINK, px=20):
	D.text(ROUND, px, words, x, y, color=color, stroke=2, anchor="l")


def screen(art, masks, reqs, letter, state, phone):
	ss = 2
	P = Draw(PW, PH, ss, art, masks, reqs)
	DRAFTS[letter](P, state)
	W, H = (844 * 2, 390 * 2) if phone else (1280, 720)
	S = Draw(W, H, 1, art, masks, reqs)
	foot = f"Draft {letter}: {FOOT[state]}" + (" (844 x 390 phone, 2x)" if phone else "")
	foot2 = "* \"Not this time\" text is a proposal. Times and counts are sample values."
	if masks is None:
		note(S, foot, 0, 0, WHITE, px=18 if phone else 20)
		note(S, foot2, 0, 0)
		return None
	S.img[...] = backdrop(W, H)
	if phone:
		k = min(0.96 * 844 / PW, 0.94 * 390 / PH) * 2
		pw, ph = int(round(PW * k)), int(round(PH * k))
		stamp(S.img, resize(P.img, pw, ph), (W - pw) // 2, (H - ph) // 2 + 6)
		note(S, foot, 12, 14, WHITE, px=18)
	else:
		stamp(S.img, P.finish(), 40, 44)
		note(S, foot, 40, 20, WHITE)
		note(S, foot2, 40, 692)
	return S.img


def contact_sheet(shots, masks, reqs):
	cw, ch, lab, pad = 640, 360, 40, 16
	W, H = 3 * cw + 4 * pad, 3 * (ch + lab) + 4 * pad
	S = Draw(W, H, 1, None, masks, reqs)
	order = [(L, s) for L in DRAFTS for s in ("live", "idle", "phone")]
	if masks is None:
		for L, s in order:
			S.text(ROUND, 26, f"{L}_{s}.png", 0, 0)
		return None
	S.img[...] = 0
	over(S.img, (24, 26, 36), np.ones(S.img.shape[:2]))
	for i, (L, s) in enumerate(order):
		x0, y0 = pad + (i % 3) * (cw + pad), pad + (i // 3) * (ch + lab + pad)
		S.text(ROUND, 26, f"{L}_{s}.png", x0 + 4, y0 + lab / 2, anchor="l")
		img = shots[(L, s)]
		h = int(round(img.shape[0] * cw / img.shape[1]))
		stamp(S.img, resize(img, cw, h), x0, y0 + lab + (ch - h) // 2)
	return S.img


def render(art, masks, reqs):
	shots = {}
	for L in DRAFTS:
		for s, state, phone in (("live", "live", False), ("idle", "idle", False), ("phone", "live", True)):
			shots[(L, s)] = screen(art, masks, reqs, L, state, phone)
	return shots, contact_sheet(shots, masks, reqs)


def render_king(art, masks, reqs):
	"""`king`: only The Golden King's draft B screens, B_king_live.png and B_king_phone.png (goal boss-king k5)."""
	return {s: screen(art, masks, reqs, "B", "king", s == "phone") for s in ("live", "phone")}


def main():
	os.makedirs(OUT, exist_ok=True)
	art = load_art()
	reqs = set()
	king = "king" in sys.argv[1:]
	(render_king if king else render)(art, None, reqs)  # record pass: every text the drafts ask for
	masks = base.text_masks(sorted(reqs))
	if king:
		for s, img in render_king(art, masks, reqs).items():
			base.write_png(os.path.join(OUT, f"B_king_{s}.png"), base.to_rgba8(img))
		return
	shots, sheet = render(art, masks, reqs)
	for (L, s), img in shots.items():
		base.write_png(os.path.join(OUT, f"{L}_{s}.png"), base.to_rgba8(img))
	base.write_png(os.path.join(OUT, "sheet.png"), base.to_rgba8(sheet))


if __name__ == "__main__":
	main()
