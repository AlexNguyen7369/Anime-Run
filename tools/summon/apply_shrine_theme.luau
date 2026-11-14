-- Apply the same runtime shrine theme to the native editable UI template.
-- lune run <this file> <absolute repository path>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local root = assert(process.args[1], "absolute repository path required")
local env = setmetatable({}, { __index = getfenv() })
for _, key in { "Instance", "Vector2", "Vector3", "UDim", "UDim2", "Color3", "ColorSequence", "Enum" } do
	env[key] = roblox[key]
end
local chunk = assert(loadstring(fs.readFile(root .. "/src/client/SummonShrineTheme.luau")))
setfenv(chunk, env)
local theme = chunk()
local path = root .. "/assets/studio/RacerSidekicks.rbxm"
local objects = roblox.deserializeModel(fs.readFile(path))
assert(#objects == 1 and objects[1].Name == "RacerSidekicks", "unexpected UI root")
local gui = objects[1]
local buttons = {}
for _, item in gui:GetDescendants() do
	if item:IsA("TextButton") then
		buttons[item] = { item.Position, item.Size, item.Text }
	end
end
theme.Apply(gui)
local count = #gui:GetDescendants()
theme.Apply(gui)
assert(#gui:GetDescendants() == count, "theme must be idempotent")
local themed = 0
for item, original in buttons do
	assert(item.Position == original[1] and item.Size == original[2], "button layout changed")
	if item.Name ~= "Close" then
		assert(item.Text == original[3], "action caption changed")
	end
	assert(item:GetAttribute("ShrineButtonTheme") == 1, "button not themed")
	themed += 1
end
local serialized = roblox.serializeModel(objects)
local restored = roblox.deserializeModel(serialized)[1]
assert(restored:GetAttribute("SummonTheme") == "BlossomShrine", "theme registration lost")
assert(#restored:GetDescendants() == count, "native descendants lost")
fs.writeFile(path, serialized)
print("Shrine native theme verified", themed, "buttons; idempotent; layout/action captions preserved")
