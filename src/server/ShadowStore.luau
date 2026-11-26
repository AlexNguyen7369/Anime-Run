--!nonstrict
-- In-memory stand-in for a DataStore (design doc 4.24 "Harness saves"). A key is read from `source` once, with
-- GetAsync, the first time it is asked for; every write stays in this table. Nothing is ever written to `source`.
-- `source` nil, or a read that fails: the key starts empty (a new save).

local ShadowStore = {}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = copy(item)
	end
	return out
end

function ShadowStore.new(source)
	local store = { data = {}, seeded = {} }

	local function current(key)
		if not store.seeded[key] then
			store.seeded[key] = true
			if source then
				local ok, value = pcall(function()
					return (source:GetAsync(key))
				end)
				if ok then
					store.data[key] = copy(value)
				end
			end
		end
		return store.data[key]
	end

	function store:GetAsync(key)
		return copy(current(key))
	end

	function store:SetAsync(key, value)
		current(key)
		self.data[key] = copy(value)
	end

	function store:RemoveAsync(key)
		local old = current(key)
		self.data[key] = nil
		return copy(old)
	end

	function store:UpdateAsync(key, transform)
		local value = transform(copy(current(key)))
		if value == nil then
			return nil
		end
		self.data[key] = copy(value)
		return copy(value)
	end

	return store
end

return ShadowStore
