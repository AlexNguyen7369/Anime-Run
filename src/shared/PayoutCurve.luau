--!nonstrict
-- Track payout and price curves (design doc "payout and price curves", owner 2026-10-27; constants are placeholders).
-- Payouts grow exponentially per track; prices grow as the payout ratio ^ COST_POWER, faster than payouts.
local PayoutCurve = {}

PayoutCurve.BASE_CASH = 100 -- Track 1 payout
PayoutCurve.GROWTH = { 10, 7.5 } -- per track from Track 2, repeating: Track 2 x10, Track 3 x7.5, Track 4 x10, ...
PayoutCurve.COST_POWER = 1.5
-- World 2 (design doc 4.47, owner 2026-11-24; WORLD2_SPEC "Rewards"): Track N pays World 1 Track 10 x WORLD2_STEP^N.
PayoutCurve.WORLD1_LAST = 10
PayoutCurve.WORLD2_STEP = 2 -- placeholder

local function clean(n)
	if type(n) ~= "number" or n ~= n or n == math.huge then
		return 1
	end
	return math.max(1, math.floor(n))
end

-- Payout of Track n / payout of Track 1.
function PayoutCurve.Ratio(n)
	local growth = PayoutCurve.GROWTH
	local ratio = 1
	for k = 2, clean(n) do
		ratio *= growth[(k - 2) % #growth + 1]
	end
	return ratio
end

function PayoutCurve.Cash(n)
	return math.floor(PayoutCurve.BASE_CASH * PayoutCurve.Ratio(n) + 0.5)
end

-- Pad Cash of Track n in world `world` (1 = PayoutCurve.Cash, unchanged).
function PayoutCurve.TrackCash(n, world)
	if world == 2 then
		return math.floor(PayoutCurve.Cash(PayoutCurve.WORLD1_LAST) * PayoutCurve.WORLD2_STEP ^ clean(n) + 0.5)
	end
	return PayoutCurve.Cash(n)
end

-- Two significant figures, halves up; 0 for bad input.
function PayoutCurve.NiceRound(x)
	if type(x) ~= "number" or x ~= x or x <= 0 or x == math.huge then
		return 0
	end
	local unit = 10 ^ (math.floor(math.log10(x)) - 1)
	return math.floor(x / unit + 0.5) * unit
end

-- Price of step `step` of a ladder whose first step costs `base`.
function PayoutCurve.Cost(base, step)
	return PayoutCurve.NiceRound(base * PayoutCurve.Ratio(step) ^ PayoutCurve.COST_POWER)
end

return PayoutCurve
