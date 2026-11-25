--!nonstrict
-- Which of the Summon altar's two meshes a player sees (WORLD_REDESIGN_SPEC 4.2), display only: both stand, tagged
-- (Shared/PlazaPieces ALTAR_TAGS), and one is shown. Client/SidekickAltarView applies it for its own player.
local CollectionService = game:GetService("CollectionService")
local PlazaPieces = require(script.Parent.PlazaPieces)

local PlazaPieceLook = {}

-- A tagged part shown or not; a glow part never casts a shadow.
function PlazaPieceLook.Show(part, shown)
	part.Transparency = shown and 0 or 1
	part.CastShadow = shown and string.sub(part.Name, 1, 5) ~= "Glow_"
end

function PlazaPieceLook.Altar(locked)
	for state, tag in PlazaPieces.ALTAR_TAGS do
		for _, part in CollectionService:GetTagged(tag) do
			PlazaPieceLook.Show(part, (state == "Locked") == locked)
		end
	end
end

return PlazaPieceLook
