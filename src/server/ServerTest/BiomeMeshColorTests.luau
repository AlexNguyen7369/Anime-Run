--!nonstrict
-- BRIEF: docs/BUGS.md w2-dark-props. A World 2 draft mesh carries its colours as vertex colours and no texture; the part it is
-- loaded into is Roblox's default grey (0.639, 0.635, 0.647 on all 10,360 placed ones, Studio 2026-11-25) and tints them. A
-- textureless World 2 template is white, so the mesh shows its own colours; a textured one, and everything in World 1,
-- keeps the colour it was loaded with. On a copy of Server/BiomeAssets with its Row and Fetch seams.
-- Offline: lune run tools/lune/server_scenarios <1|2> BiomeMeshColorTests.biome_mesh_color
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}

local GREY = Color3.fromRGB(163, 162, 165)
local WHITE = Color3.new(1, 1, 1)
local SIZE = Vector3.new(2, 2, 2)

function Tests.biome_mesh_color()
	local r, flag = H.report("biome_mesh_color")
	local Server = script.Parent.Parent
	local WorldConfig = require(ReplicatedStorage.Shared.WorldConfig)
	local oldWorld = WorldConfig.Id
	local cleanup = {}
	local ok, err = xpcall(function()
		for _, world in { 1, 2 } do
			WorldConfig.Id = world
			local module = Server.BiomeAssets:Clone()
			module.Name, module.Parent = "ServerTestBiomeAssets" .. world, Server
			table.insert(cleanup, module)
			local A = require(module)
			A.DEBUG = false
			A.Row = function(_, key, kind)
				if kind == "Texture" then
					return { Id = "rbxassetid://2" }
				end
				return { Id = "rbxassetid://1", Key = key, Texture = key == "Textured" and "Tex" or nil }
			end
			A.Fetch = function(row)
				local part = Instance.new("MeshPart")
				part.Color = GREY
				part.TextureID = row.Key == "OwnTexture" and "rbxassetid://3" or ""
				table.insert(cleanup, part)
				return part
			end
			for key, want in
				{
					Plain = world == 2 and WHITE or GREY,
					Textured = GREY, -- a ledger Texture row
					OwnTexture = GREY, -- a texture in the asset itself
				}
			do
				for _, which in { "first", "again" } do
					local part = A.Clone("T", key, SIZE)
					flag(
						("world%d_%s_%s"):format(world, key, which),
						part ~= nil and part.Color == want,
						tostring(part and part.Color),
						tostring(want)
					)
					if part then
						part:Destroy()
					end
				end
			end
		end
	end, debug.traceback)
	WorldConfig.Id = oldWorld
	for _, instance in cleanup do
		instance:Destroy()
	end
	flag("biome_mesh_color_completed", ok, ok and 1 or tostring(err))
	return r
end

return Tests
