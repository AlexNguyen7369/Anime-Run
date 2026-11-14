-- Register a real uploaded image without changing any authored summon template content.
-- lune run <this file> <absolute repository path> <image id>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local root, imageId = process.args[1], process.args[2]
assert(root and imageId and imageId:match("^[1-9]%d*$"), "repository path and actual numeric image ID required")
local path = root .. "/assets/studio/SummonScreenAssets.rbxm"
local objects = roblox.deserializeModel(fs.readFile(path))
assert(#objects == 1 and objects[1].Name == "SummonScreenAssets", "unexpected asset root")
local assets = objects[1]
local count = #assets:GetDescendants()
assets:SetAttribute("HybridBackdropImage", "rbxassetid://" .. imageId)
assets:SetAttribute("HybridBackdropSource", "BlossomShrineV2_Cleanplate")
assets:SetAttribute("HybridBackdropVerifiedViewport", "1024x499_EditPreview")
assets:SetAttribute("HybridPresentationVersion", 2)
assets:SetAttribute("HybridFloorScreenLocked", true)
local data = roblox.serializeModel(objects)
local check = roblox.deserializeModel(data)[1]
assert(#check:GetDescendants() == count and check:FindFirstChild("SummoningStage"), "native stage content changed")
assert(check:GetAttribute("HybridBackdropImage") == "rbxassetid://" .. imageId)
fs.writeFile(path, data)
fs.writeFile(root .. "/assets/ui/summon_shrine/asset.json", serde.encode("json", {
	Image = "rbxassetid://" .. imageId,
	Source = "Backdrop.png",
	ApprovedComposition = "summon_blossom_shrine_v2.png",
	Method = "Ropilot image upload, inspected before upload",
	Stage = "Client/SummonHybrid",
	Registration = "ReplicatedStorage.SummonScreenAssets.HybridBackdropImage",
}, true) .. "\n")
print("Registered", check:GetAttribute("HybridBackdropImage"), "preserved native descendants", count)
