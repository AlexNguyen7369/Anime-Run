--!nonstrict
-- Character bag and auto sell rules (docs/BAG_AND_AUTOSELL_SPEC.md, design doc 4.36). Numbers are placeholders except
-- BASE, PASS_BONUS and the tree's 50 per tier (owner 2026-11-04).
local BagConfig = {}

BagConfig.BASE = 80
BagConfig.PASS_BONUS = 100
BagConfig.MAX_SELL_CHANCE = 1e18

BagConfig.SELL_PRICE = {
	Common = 5,
	Uncommon = 10,
	Rare = 25,
	Epic = 100,
	Legendary = 500,
	Mythic = 2500,
	Secret = 10000,
}

function BagConfig.Cap(hasPass, treeBonus)
	return BagConfig.BASE + (hasPass and BagConfig.PASS_BONUS or 0) + (treeBonus or 0)
end

-- The whole number a player typed for "1 in N", or nil when it is not one in range.
function BagConfig.CleanChance(n)
	if type(n) ~= "number" or n ~= n or n < 1 or n > BagConfig.MAX_SELL_CHANCE or math.floor(n) ~= n then
		return nil
	end
	return n
end

-- Does auto sell take this roll? A character with no Chance or no price is never sold.
function BagConfig.ShouldSell(on, chance, spec)
	return on == true
		and BagConfig.CleanChance(chance) ~= nil
		and type(spec) == "table"
		and type(spec.Chance) == "number"
		and spec.Chance <= chance
		and BagConfig.SELL_PRICE[spec.Rarity] ~= nil
end

return BagConfig
