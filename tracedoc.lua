local next = next
local pairs = pairs
local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type
local rawset = rawset

local tracedoc = {}

local function doc_pairs(doc)
	return next, doc._lastversion
end

local function doc_len(doc)
	return #doc._lastversion
end

local function doc_change(t, k, v)
	rawset(t,k,v)
	if v == nil then
		if t._keys[k] then	-- already set
			t._doc._lastversion[k] = nil
		elseif t._doc._lastversion[k] == nil then	-- ignore since lastversion is nil
			return
		end
		t._doc._lastversion[k] = nil
	end
	t._keys[k] = true
end

tracedoc.null = setmetatable({} , { __tostring = function() return "NULL" end })	-- nil
local tracedoc_type = setmetatable({}, { __tostring = function() return "TRACEDOC" end })

function tracedoc.new(init)
	local doc = {
		_changes = { _keys = {} },
		_lastversion = {},
	}
	doc._changes._doc = doc
	setmetatable(doc._changes, {
		__index = doc._lastversion,
		__newindex = doc_change,
	})
	setmetatable(doc, {
		__newindex = doc._changes,
		__index = doc._changes,
		__pairs = doc_pairs,
		__len = doc_len,
		__metatable = tracedoc_type,	-- avoid copy by ref
	})
	if init then
		for k,v in pairs(init) do
			doc[k] = v
		end
		tracedoc.commit(doc)
	end
	return doc
end

local function doc_copy(doc, k, sub_doc, result, prefix)
	local vt = getmetatable(sub_doc)
	if vt ~= tracedoc_type and vt ~= nil then
		doc[k] = sub_doc	-- copy ref because sub_doc is an object
		return sub_doc
	end
	local target_doc = doc[k]
	if type(target_doc) ~= "table" then
		target_doc = tracedoc.new()
		doc[k] = target_doc
		for k,v in pairs(sub_doc) do
			target_doc[k] = v
			if result then
				local key = prefix and prefix .. k or k
				result[key] = v
			end
		end
	else
		for k in pairs(target_doc) do
			if sub_doc[k] == nil then
				target_doc[k] = nil
				if result then
					local key = prefix and prefix .. k or k
					result[key] = tracedoc.null
				end
			end
		end
		for k,v in pairs(sub_doc) do
			if target_doc[k] ~= v then
				target_doc[k] = v
				if result then
					local key = prefix and prefix .. k or k
					result[key] = v
				end
			end
		end
	end
	return target_doc
end

function tracedoc.commit(doc, result, prefix)
	local lastversion = doc._lastversion
	local changes = doc._changes
	local keys = changes._keys
	for k in pairs(keys) do
		local v = changes[k]
		keys[k] = nil
		if type(v) == "table" then
			if result then
				local key = (prefix and prefix .. k or k) .. "."
				v = doc_copy(lastversion, k, v, result, key)
			else
				v = doc_copy(lastversion, k, v)
			end
		elseif v == nil then
			if result then
				local key = prefix and prefix .. k or k
				result[key] = tracedoc.null
			end
		elseif lastversion[k] ~= v then
			lastversion[k] = v
			if result then
				local key = prefix and prefix .. k or k
				result[key] = v
			end
		end
		doc._changes[k] = nil
	end
	for k,v in pairs(lastversion) do
		if getmetatable(v) == tracedoc_type then
			if result then
				local key = (prefix and prefix .. k or k) .. "."
				tracedoc.commit(v, result, key)
			else
				tracedoc.commit(v)
			end
		end
	end
	return result
end

return tracedoc
