-- Runs server scenarios outside Studio: the repo's own modules and tests over a mock DataModel (Instances with attributes,
-- signals and children; no physics, no networking; Random is a seeded stand-in, so Roblox's exact draws differ).
--   lune run tools/lune/server_scenarios <world 1|2> <Tests module>.<function> ...      (from the repo root)
--   e.g. lune run tools/lune/server_scenarios 2 World2CastTests.world2_cast
-- W2_ART=1 in the environment gives every Sidekick of the world a Model. Studio stays the authority; this only catches what needs no engine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local WORLD = tonumber(process.args[1]) or 1

-- Signals and Instances ------------------------------------------------------------------------------------------------

local function newSignal()
	local signal = { List = {} }
	function signal:Connect(fn)
		local connection = { Connected = true }
		function connection:Disconnect()
			self.Connected = false
			local at = table.find(signal.List, connection)
			if at then
				table.remove(signal.List, at)
			end
		end
		connection.Fn = fn
		table.insert(signal.List, connection)
		return connection
	end
	signal.ConnectParallel = signal.Connect
	function signal:Once(fn)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end
	function signal:Wait()
		local thread = coroutine.running()
		self:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, connection in table.clone(signal.List) do
			task.spawn(connection.Fn, ...)
		end
	end
	return signal
end

local isMock = setmetatable({}, { __mode = "k" })
local SIGNALS = {
	AttributeChanged = true,
	ChildAdded = true,
	ChildRemoved = true,
	Changed = true,
	Destroying = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	OnServerEvent = true,
	OnClientEvent = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	Heartbeat = true,
	Stepped = true,
	PreSimulation = true,
	PromptGamePassPurchaseFinished = true,
	Event = true,
}
local DEFAULT_VALUE = { StringValue = "", IntValue = 0, NumberValue = 0, BoolValue = false }
local ANCESTORS = {
	ModuleScript = { LuaSourceContainer = true },
	Script = { LuaSourceContainer = true, BaseScript = true },
	Part = { BasePart = true, PVInstance = true },
	MeshPart = { BasePart = true, PVInstance = true },
}
local Methods = {}
local data = setmetatable({}, { __mode = "k" })

local game
local tagSignals = {}
local function tagSignal(tag)
	tagSignals[tag] = tagSignals[tag] or newSignal()
	return tagSignals[tag]
end
-- CollectionService's added signals for an instance (and its descendants) that just entered the DataModel
local function fireTags(instance)
	if game == nil or not Methods.IsDescendantOf(instance, game) then
		return
	end
	local entered = Methods.GetDescendants(instance)
	table.insert(entered, instance)
	for _, node in entered do
		for tag in data[node].Tags do
			tagSignal(tag):Fire(node)
		end
	end
end

local mt = {}
function mt.__index(self, key)
	local d = data[self]
	if Methods[key] then
		return Methods[key]
	end
	if SIGNALS[key] then
		d.Signals[key] = d.Signals[key] or newSignal()
		return d.Signals[key]
	end
	if key == "Source" then
		error("Source is not readable in a play server")
	end
	if key == "Parent" then
		return d.Parent
	end
	local value = d.Props[key]
	if value ~= nil then
		return value
	end
	return Methods.FindFirstChild(self, key)
end
local function fire(self, name, ...)
	local signal = data[self].Signals[name]
	if signal then
		signal:Fire(...)
	end
end
function mt.__newindex(self, key, value)
	local d = data[self]
	if key == "Parent" then
		local old = d.Parent
		if old == value then
			return
		end
		d.Parent = value
		if old then
			table.remove(data[old].Children, table.find(data[old].Children, self))
			fire(old, "ChildRemoved", self)
		end
		if value then
			table.insert(data[value].Children, self)
			fire(value, "ChildAdded", self)
			fireTags(self)
		end
		return
	end
	d.Props[key] = value
	local signal = d.Signals["prop:" .. tostring(key)]
	if signal then
		signal:Fire()
	end
	fire(self, "Changed", key == "Value" and value or key)
end
function mt.__tostring(self)
	return data[self].Props.Name
end

local function newInstance(class, parent)
	local self = setmetatable({}, mt)
	isMock[self] = true
	data[self] = {
		Props = { Name = class, ClassName = class, Value = DEFAULT_VALUE[class] },
		Children = {},
		Attributes = {},
		Signals = {},
		Tags = {},
	}
	if parent then
		self.Parent = parent
	end
	return self
end

function Methods.GetChildren(self)
	return table.clone(data[self].Children)
end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in data[node].Children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function Methods.FindFirstChild(self, name, recursive)
	for _, child in data[self].Children do
		if data[child].Props.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in Methods.GetDescendants(self) do
			if data[child].Props.Name == name then
				return child
			end
		end
	end
	return nil
end
Methods.WaitForChild = Methods.FindFirstChild
function Methods.FindFirstChildOfClass(self, class)
	for _, child in data[self].Children do
		if data[child].Props.ClassName == class then
			return child
		end
	end
	return nil
end
function Methods.IsA(self, class)
	local own = data[self].Props.ClassName
	return class == own or class == "Instance" or (ANCESTORS[own] ~= nil and ANCESTORS[own][class] == true)
end
function Methods.IsDescendantOf(self, ancestor)
	local at = data[self].Parent
	while at do
		if at == ancestor then
			return true
		end
		at = data[at].Parent
	end
	return false
end
function Methods.GetFullName(self)
	local parent = data[self].Parent
	return (parent and Methods.GetFullName(parent) .. "." or "") .. data[self].Props.Name
end
function Methods.SetAttribute(self, name, value)
	if data[self].Attributes[name] == value then
		return
	end
	data[self].Attributes[name] = value
	fire(self, "AttributeChanged", name)
	local signal = data[self].Signals["attr:" .. name]
	if signal then
		signal:Fire()
	end
end
function Methods.GetAttribute(self, name)
	return data[self].Attributes[name]
end
function Methods.GetAttributes(self)
	return table.clone(data[self].Attributes)
end
local function named(self, key)
	data[self].Signals[key] = data[self].Signals[key] or newSignal()
	return data[self].Signals[key]
end
function Methods.GetAttributeChangedSignal(self, name)
	return named(self, "attr:" .. name)
end
function Methods.GetPropertyChangedSignal(self, name)
	return named(self, "prop:" .. name)
end
function Methods.ClearAllChildren(self)
	for _, child in Methods.GetChildren(self) do
		child:Destroy()
	end
end
function Methods.Destroy(self)
	fire(self, "Destroying")
	Methods.ClearAllChildren(self)
	self.Parent = nil
end
function Methods.Clone(self)
	local copy = newInstance(data[self].Props.ClassName)
	for key, value in data[self].Props do
		data[copy].Props[key] = value
	end
	data[copy].Attributes = table.clone(data[self].Attributes)
	data[copy].Tags = table.clone(data[self].Tags)
	data[copy].Path, data[copy].Source = data[self].Path, data[self].Source
	for _, child in data[self].Children do
		Methods.Clone(child).Parent = copy
	end
	return copy
end
for _, name in { "FireClient", "FireAllClients", "FireServer", "Fire", "PivotTo" } do
	Methods[name] = function() end
end

-- DataModel ------------------------------------------------------------------------------------------------------------

game = newInstance("DataModel")
local services = {}
function Methods.GetService(_, name)
	if not services[name] then
		services[name] = newInstance(name, game)
	end
	return services[name]
end
local function service(name, methods)
	local instance = Methods.GetService(game, name)
	for key, value in methods or {} do
		data[instance].Props[key] = value
	end
	return instance
end
-- Numbers round trip exactly, as in Roblox (lune's JSON parser may be one ulp off); serde still does strings and rejects bad text.
local function encodeJson(value)
	if type(value) == "number" and math.abs(value) < math.huge then
		return string.format("%.17g", value)
	elseif type(value) ~= "table" then
		return serde.encode("json", value)
	end
	local parts = {}
	if next(value) == nil or #value > 0 then
		for i, item in ipairs(value) do
			parts[i] = encodeJson(item)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	for key, item in value do
		table.insert(parts, serde.encode("json", tostring(key)) .. ":" .. encodeJson(item))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local function decodeJson(text)
	serde.decode("json", text)
	local at = 1
	local function skip()
		at = string.find(text, "[^%s,:]", at) or #text + 1
		return string.sub(text, at, at)
	end
	local function read()
		local first = skip()
		if first == "{" or first == "[" then
			local out, index = {}, 0
			at += 1
			while skip() ~= "}" and skip() ~= "]" do
				index += 1
				local key = first == "{" and read() or index
				out[key] = read()
			end
			at += 1
			return out
		end
		local start = at
		if first == '"' then
			at += 1
			while string.sub(text, at, at) ~= '"' do
				at += string.sub(text, at, at) == "\\" and 2 or 1
			end
			at += 1
			return serde.decode("json", string.sub(text, start, at - 1))
		end
		at = string.find(text, "[%s,%]}]", at) or #text + 1
		local token = string.sub(text, start, at - 1)
		if token == "true" or token == "false" then
			return token == "true"
		end
		return tonumber(token) -- null: nil
	end
	return read()
end
local guids = 0
service("HttpService", {
	JSONEncode = function(_, value)
		return encodeJson(value)
	end,
	JSONDecode = function(_, text)
		return decodeJson(text)
	end,
	GenerateGUID = function()
		guids += 1
		return "guid-" .. guids
	end,
})
service("Players", {
	GetPlayers = function()
		return {}
	end,
	GetPlayerByUserId = function()
		return nil
	end,
})
service("RunService", {
	IsStudio = function()
		return true
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsRunning = function()
		return true
	end,
})
service("CollectionService", {
	GetTagged = function(_, tag)
		local out = {}
		for _, instance in game:GetDescendants() do
			if data[instance].Tags[tag] then
				table.insert(out, instance)
			end
		end
		return out
	end,
	AddTag = function(_, instance, tag)
		if data[instance].Tags[tag] then
			return
		end
		data[instance].Tags[tag] = true
		if instance:IsDescendantOf(game) then
			tagSignal(tag):Fire(instance)
		end
	end,
	HasTag = function(_, instance, tag)
		return data[instance].Tags[tag] == true
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(tag)
	end,
	GetInstanceRemovedSignal = newSignal,
})
local workspace = service("Workspace", {
	Gravity = 196.2,
	GetServerTimeNow = function()
		return os.time()
	end,
})
data[game].Props.Workspace = workspace
data[game].Props.PlaceId = 0
data[game].Props.JobId = ""
data[game].Props.BindToClose = function() end

local function mount(path, parent, name)
	local instance
	if fs.isDir(path) then
		local entry = fs.isFile(path .. "/init.luau") and path .. "/init.luau"
		instance = newInstance(entry and "ModuleScript" or "Folder")
		data[instance].Path = entry or nil
		for _, child in fs.readDir(path) do
			if child ~= "init.luau" and (fs.isDir(path .. "/" .. child) or string.match(child, "%.luau$")) then
				mount(path .. "/" .. child, instance, (string.gsub(child, "%.luau$", "")))
			end
		end
	else
		local class = string.match(path, "%.server%.luau$") and "Script" or "ModuleScript"
		instance = newInstance(class)
		data[instance].Path = path
		name = string.gsub(name, "%.server$", "")
	end
	instance.Name = name
	if data[instance].Path then
		data[instance].Source = fs.readFile(data[instance].Path)
	end
	instance.Parent = parent
	return instance
end

local ReplicatedStorage = service("ReplicatedStorage")
mount("src/shared", ReplicatedStorage, "Shared")
local server = mount("src/server", service("ServerScriptService"), "Server")
mount("src/late", service("ServerStorage"), "LateData")
local remotes = newInstance("Folder", ReplicatedStorage)
remotes.Name = "Remotes"
if WORLD == 2 then
	local id = newInstance("IntValue", ReplicatedStorage)
	id.Name = "WorldId"
	id.Value = 2
end

-- Globals --------------------------------------------------------------------------------------------------------------

local Random = {}
function Random.new(seed)
	local state = (seed or math.floor(os.clock() * 1e6)) % 2 ^ 32
	local rng = {}
	-- splitmix32: neighbouring seeds give unrelated draws
	local function draw()
		state = (state + 0x9E3779B9) % 2 ^ 32
		local z = bit32.bxor(state, bit32.rshift(state, 16))
		z = bit32.band(bit32.lshift(bit32.band(z, 0xFFFF) * 0x21F0 % 2 ^ 16, 16) + z * 0xAAAD, 0xFFFFFFFF)
		z = bit32.bxor(z, bit32.rshift(z, 15))
		z = bit32.band(bit32.lshift(bit32.band(z, 0xFFFF) * 0x735A % 2 ^ 16, 16) + z * 0x2D97, 0xFFFFFFFF)
		return bit32.bxor(z, bit32.rshift(z, 15))
	end
	function rng:NextNumber(low, high)
		local u = (draw() + draw() / 2 ^ 32) / 2 ^ 32
		return low and low + u * (high - low) or u
	end
	function rng:NextInteger(low, high)
		return low + math.floor(self:NextNumber() * (high - low + 1))
	end
	function rng:Shuffle(list)
		for i = #list, 2, -1 do
			local j = self:NextInteger(1, i)
			list[i], list[j] = list[j], list[i]
		end
	end
	return rng
end

local globals = {
	game = game,
	workspace = workspace,
	Instance = { new = newInstance },
	Random = Random,
	task = task,
	typeof = function(value)
		return isMock[value] and "Instance" or roblox.typeof and roblox.typeof(value) or typeof(value)
	end,
	Enum = roblox.Enum,
	warn = function() end,
	print = print,
	tick = os.clock,
	time = os.clock,
	debug = setmetatable({
		traceback = function(err)
			return tostring(err) -- lune's errors are userdata, which the real one refuses
		end,
	}, { __index = debug }),
}
for name, value in roblox do
	if globals[name] == nil and type(value) == "table" or type(value) == "userdata" then
		globals[name] = globals[name] or value
	end
end
-- lune's CFrame.lookAt faces away from its target (-Z should look at it); Roblox's is right.
globals.CFrame = setmetatable({
	lookAt = function(at, target, up)
		local back = (at - target).Unit
		local right = (up or roblox.Vector3.yAxis):Cross(back).Unit
		return roblox.CFrame.fromMatrix(at, right, back:Cross(right), back)
	end,
}, { __index = roblox.CFrame })
globals.TweenInfo = globals.TweenInfo or {
	new = function()
		return {}
	end,
}
globals.OverlapParams = {
	new = function()
		return {}
	end,
}
globals.RaycastParams = {
	new = function()
		return {}
	end,
}
globals.shared = {}

local loaded = {}
local function requireMock(module)
	local entry = loaded[module]
	if entry then
		assert(entry.Done, "require loop: " .. module:GetFullName())
		return entry.Value
	end
	entry = {}
	loaded[module] = entry
	local environment = table.clone(globals)
	environment.script = module
	environment.require = requireMock
	local ok, value =
		pcall(luau.load(data[module].Source, { debugName = data[module].Path, environment = environment }))
	if not ok then
		loaded[module] = nil
		error(value, 0)
	end
	entry.Value, entry.Done = value, true
	return value
end

-- Run ------------------------------------------------------------------------------------------------------------------

local tests = server.ServerTest
local failedRuns = 0
if process.env.W2_ART then -- as after the uploads: every Sidekick of this world has a Model
	local art = requireMock(ReplicatedStorage.Shared.SidekickArt)
	for _, row in requireMock(ReplicatedStorage.Shared.SidekickConfig).List do
		art[row.Id] = art[row.Id] or { Model = 1 }
	end
end
for _, name in { "GachaService", "SidekickService" } do
	requireMock(server:FindFirstChild(name)).Start() -- what Server/Main starts: the remotes
end
for i = 2, #process.args do
	local moduleName, name, maker = string.match(process.args[i], "^(%w+)%.([%w_]+)(:?m?a?k?e?)$")
	local ok, report = pcall(function()
		local module = requireMock(tests:FindFirstChild(moduleName))
		local source = maker == ":make" and module.make({}) or module
		return source[name]()
	end)
	if not ok then
		failedRuns += 1
		print(("[LUNE] %s world=%d NOT RUN: %s"):format(process.args[i], WORLD, tostring(report)))
		continue
	end
	local pass, fail = 0, 0
	for _, check in report.checks do
		if check.pass then
			pass += 1
		else
			fail += 1
			print(("  FAIL %s value=%s limit=%s"):format(check.name, tostring(check.value), tostring(check.limit)))
		end
	end
	failedRuns += fail > 0 and 1 or 0
	print(("[LUNE] %s world=%d pass=%d fail=%d"):format(process.args[i], WORLD, pass, fail))
end
process.exit(failedRuns > 0 and 1 or 0)
