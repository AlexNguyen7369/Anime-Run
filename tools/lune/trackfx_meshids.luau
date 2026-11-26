-- Reads the MeshId (and size) of the MeshPart inside each uploaded track effect Model (tools/blender/world2/upload_track_fx.py
-- downloads them to <dir>/<key>.rbxm), so the ledger gets the MeshId without Studio. Prints "key<TAB>meshid<TAB>size".
--   lune run tools/lune/trackfx_meshids <dir>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local dir = process.args[1] or "build/track_fx/upload"
for _, name in fs.readDir(dir) do
	local key = string.match(name, "^(.+)%.rbxm$")
	if key then
		local instances = roblox.deserializeModel(fs.readFile(dir .. "/" .. name))
		for _, root in instances do
			local list = root:GetDescendants()
			table.insert(list, 1, root)
			for _, d in list do
				if d.ClassName == "MeshPart" then
					local ok, id = pcall(function()
						return d.MeshId
					end)
					if not ok or id == nil or id == "" then
						ok, id = pcall(function()
							return tostring(d.MeshContent)
						end)
					end
					print(("%s\t%s\t%s"):format(key, tostring(id), tostring(d.Size)))
				end
			end
		end
	end
end
