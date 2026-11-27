--!nonstrict
-- The boss gate guide's popup, layout B (owner 2026-11-25, docs/BOSS_GUIDE_SPEC.md), in Client/AnimeSkin.IndexFrame's design
-- units. Client/BossGuideUi places it; phones keep the standard frame (650 x 420, content from 144).
local BossGuideLayout = {}

BossGuideLayout.FRAME_H = 520 -- desktop frame height (IndexFrame H)
BossGuideLayout.TOP = 120 -- desktop content start: no tabs row (IndexFrame Top)
BossGuideLayout.TEXT = 48 -- desktop line size (AnimeSkin.UnitSize.Speech); phones use Item

local GAP, RIM = 12, 2
local NEXT_W, NEXT_H = 200, 44
local PHONE_CARD = 110
local BAR = 6 -- the slip's vermilion edge

local function rect(x, y, w, h)
	return { X = x, Y = y, W = w, H = h }
end

-- content: the frame's content area { X, Y, W, H }. Returns rects Card, Portrait, Line, Next, the line's text Role, and on
-- desktop Slip and Bar.
function BossGuideLayout.Rects(content, small)
	local c = content
	local body = small and c.H - NEXT_H - GAP or c.H
	local side = small and PHONE_CARD or body
	local card = rect(c.X, c.Y + (body - side) / 2, side, side)
	local portrait = rect(card.X + RIM, card.Y + RIM, side - 2 * RIM, side - 2 * RIM)
	local x = card.X + side + GAP
	local w = c.X + c.W - x
	if small then
		return {
			Card = card,
			Portrait = portrait,
			Line = rect(x, c.Y, w, body),
			Next = rect(c.X + (c.W - NEXT_W) / 2, c.Y + c.H - NEXT_H, NEXT_W, NEXT_H),
			Role = "Item",
		}
	end
	return {
		Card = card,
		Portrait = portrait,
		Slip = rect(x, c.Y, w, body),
		Bar = rect(x, c.Y, BAR, body),
		Line = rect(x + 32, c.Y + GAP, w - 56, body - NEXT_H - 3 * GAP),
		Next = rect(x + w - NEXT_W - GAP, c.Y + body - NEXT_H - GAP, NEXT_W, NEXT_H),
		Role = "Speech",
	}
end

return BossGuideLayout
