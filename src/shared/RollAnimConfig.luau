--!nonstrict
-- Timings and sizes of the roll animation (docs/ROLL_ANIMATION_SPEC.md). Pure, so the client (Client/RollToast),
-- the server (GachaService pauses auto-roll while a long animation plays) and the tests share them.

local CharacterCatalog = require(script.Parent.CharacterCatalog)
local GachaConfig = require(script.Parent.GachaConfig)

local RollAnimConfig = {}

-- One roll: pop in -> spin -> land -> hold -> exit (seconds, before TimeScale)
RollAnimConfig.POP = 0.12
RollAnimConfig.SPIN = 1.5
RollAnimConfig.LAND = 0.2
RollAnimConfig.EXIT = 0.2
RollAnimConfig.SWITCH = 0.3 -- compact <-> enlarged view; not scaled

RollAnimConfig.HOLD = {
	Common = 0.5,
	Uncommon = 0.5,
	Rare = 0.6,
	Epic = 0.75,
	Legendary = 1.5,
	Mythic = 2.5,
	Secret = 4,
}

RollAnimConfig.FIT_INTERVAL = 2.8 -- at a shorter roll interval the animation plays faster, so it still fits

RollAnimConfig.REEL_CARS = 16 -- characters shown per roll; the last one is the result
RollAnimConfig.SLOT_GROWTH = 1.12 -- each cycle slot lasts this much longer than the one before it
RollAnimConfig.LAND_POP = 1.15 -- the result pops to this size on landing, then settles to 1x

-- Compact roll (no card: the bare figure, its "1 in N" and its name): top centre, under the hidden RacerHud/Race anchor
RollAnimConfig.COMPACT_WIDTH = 0.12 -- of the screen width (owner, 2026-10-02)
RollAnimConfig.COMPACT_MIN = 100 -- px
RollAnimConfig.COMPACT_MAX = 230 -- px
RollAnimConfig.COMPACT_HEIGHT = 110 -- px: the figure
RollAnimConfig.COMPACT_SCREEN_SHARE = 0.3 -- the figure never takes more of the screen height than this
RollAnimConfig.COMPACT_GAP = 8 -- px from the RacerHud/Race anchor's bottom edge to the roll
RollAnimConfig.COMPACT_TOP = 8 -- px from the screen top to the normal roll (placeholder)
-- Index panel top. Not tied to the figure's height: the compact roll hides while a panel is open (design doc 4.20).
RollAnimConfig.PANEL_TOP = 12 + 48 + RollAnimConfig.COMPACT_GAP + 66 + 4
-- Enlarged card: centred, about 3x the old compact card
RollAnimConfig.ENLARGED_FACTOR = 3
RollAnimConfig.ENLARGED_WIDTH = 0.6 -- of the screen width
RollAnimConfig.ENLARGED_MAX = Vector2.new(780, 336) -- px

function RollAnimConfig.Hold(rarity)
	return RollAnimConfig.HOLD[rarity] or RollAnimConfig.HOLD.Common
end

-- Multiplies POP, SPIN, LAND, HOLD and EXIT, so Common to Epic finish inside the player's roll interval.
function RollAnimConfig.TimeScale(interval)
	return math.min(1, (interval or GachaConfig.ROLL_INTERVAL) / RollAnimConfig.FIT_INTERVAL)
end

-- Seconds one roll's animation takes; an emphasized roll also opens and closes the enlarged view.
function RollAnimConfig.Duration(rarity, emphasized, interval)
	local t = (
		RollAnimConfig.POP
		+ RollAnimConfig.SPIN
		+ RollAnimConfig.LAND
		+ RollAnimConfig.Hold(rarity)
		+ RollAnimConfig.EXIT
	) * RollAnimConfig.TimeScale(interval)
	if emphasized then
		t += 2 * RollAnimConfig.SWITCH
	end
	return t
end

-- How much longer than the roll interval the server waits before the next roll, so it never covers one still playing.
function RollAnimConfig.ExtraPause(rarity, emphasized, interval)
	return math.max(0, RollAnimConfig.Duration(rarity, emphasized, interval) - (interval or GachaConfig.ROLL_INTERVAL))
end

-- Seconds of each cycle slot during Spin, one per filler: each longer than the last, summing to the scaled SPIN.
function RollAnimConfig.SpinSlots(interval)
	local slots, total = {}, 0
	for i = 1, RollAnimConfig.REEL_CARS - 1 do
		slots[i] = RollAnimConfig.SLOT_GROWTH ^ (i - 1)
		total += slots[i]
	end
	local unit = RollAnimConfig.SPIN * RollAnimConfig.TimeScale(interval) / total
	for i, weight in slots do
		slots[i] = weight * unit
	end
	return slots
end

-- A repeat is redrawn from the low rarities only, weighted by their odds (owner 2026-11-04): the catch-all takes about
-- 81 % of luck-1 rolls, so plain draws would show one character, and a rarer character must never appear above its
-- true odds as a fake near-miss.
local LOW_RARITY = { Common = true, Uncommon = true }

local function drawOther(rng, first, second)
	local id = GachaConfig.Roll(rng, 1)
	if id ~= first and id ~= second then
		return id
	end
	local pool, total = {}, 0
	for _, spec in CharacterCatalog.Rollable() do
		if LOW_RARITY[spec.Rarity] and spec.Id ~= first and spec.Id ~= second then
			table.insert(pool, spec)
			total += 1 / spec.Chance
		end
	end
	local pick = rng:NextNumber() * total
	for _, spec in pool do
		pick -= 1 / spec.Chance
		if pick <= 0 then
			return spec.Id
		end
	end
	return pool[#pool].Id
end

-- The characters shown in order; the last is the result. No two neighbours are the same. Every filler starts as a real
-- luck-1 roll.
function RollAnimConfig.Reel(rng, resultId)
	local reel = {}
	local last = RollAnimConfig.REEL_CARS - 1
	for i = 1, last do
		reel[i] = drawOther(rng, reel[i - 1], i == last and resultId or nil)
	end
	reel[RollAnimConfig.REEL_CARS] = resultId
	return reel
end

return RollAnimConfig
