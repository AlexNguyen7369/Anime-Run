--!nonstrict
-- Shared acceptance fixtures: detached data copies model DataStore commit/rollback boundaries.
local Support = {}

function Support.module(parent, name)
	local source = parent:FindFirstChild(name)
	local ok, value = pcall(function()
		return source and require(source)
	end)
	return ok and type(value) == "table" and value or nil
end

function Support.report(name)
	local result = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(result.checks, {
			name = label,
			pass = ok == true,
			value = value == nil and (ok and 1 or 0) or value,
			limit = limit or 1,
		})
		result.pass = result.pass and ok == true
	end
	return result, flag
end

-- The placeholder runner rig (docs/WORLD_REDESIGN_SPEC.md section 2): a Model with Head, Torso, 2 parts named *Arm*,
-- 2 named *Leg*, no VehicleSeat / Seat and no part named *wheel*. Display models (pedestals, tiles) use the same rig.
function Support.isRig(model)
	if not (typeof(model) == "Instance" and model:IsA("Model")) then
		return false
	end
	local arms, legs, carParts = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			carParts += 1
		elseif d:IsA("BasePart") then
			if string.find(string.lower(d.Name), "wheel", 1, true) then
				carParts += 1
			elseif string.find(d.Name, "Arm", 1, true) then
				arms += 1
			elseif string.find(d.Name, "Leg", 1, true) then
				legs += 1
			end
		end
	end
	local head, torso = model:FindFirstChild("Head", true), model:FindFirstChild("Torso", true)
	return head ~= nil
		and head:IsA("BasePart")
		and torso ~= nil
		and torso:IsA("BasePart")
		and arms == 2
		and legs == 2
		and carParts == 0
end

-- The display model a pedestal / holder shows: child "Runner" (or the IVS name "Car", kept as a test seam).
function Support.shown(holder)
	return holder and (holder:FindFirstChild("Runner") or holder:FindFirstChild("Car")) or nil
end

function Support.copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = Support.copy(item)
	end
	return out
end

function Support.same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not Support.same(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function Support.store(records)
	local store = { data = Support.copy(records or {}), updates = 0, writes = 0 }
	function store:GetAsync(key)
		if self.fail then
			error("acceptance read failure")
		end
		return Support.copy(self.data[key])
	end
	function store:SetAsync()
		error("acceptance requires atomic UpdateAsync")
	end
	function store:UpdateAsync(key, transform)
		self.updates += 1
		if self.fail then
			error("acceptance store failure")
		end
		-- A callback may run again after a conflict, without committing its first proposed value.
		if self.retry then
			transform(Support.copy(self.data[key]))
		end
		local value = transform(Support.copy(self.data[key]))
		if self.inspect then
			self.inspect(key, value)
		end
		if self.failAfterTransform then
			error("acceptance commit failure")
		end
		if value ~= nil then
			self.writes += 1
			self.data[key] = Support.copy(value)
		end
		return Support.copy(value)
	end
	return store
end

function Support.player(cleanup, id)
	local player = Instance.new("Folder")
	player.Name = "CarTestAcceptance_" .. id
	player:SetAttribute("UserId", id)
	player.Parent = workspace
	table.insert(cleanup, player)
	return player
end

return Support
