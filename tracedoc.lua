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
				result._n = (result._n or 0) + 1
			end
		end
	else
		for k in pairs(target_doc) do
			if sub_doc[k] == nil then
				target_doc[k] = nil
				if result then
					local key = prefix and prefix .. k or k
					result[key] = tracedoc.null
					result._n = (result._n or 0) + 1
				end
			end
		end
		for k,v in pairs(sub_doc) do
			if target_doc[k] ~= v then
				target_doc[k] = v
				if result then
					local key = prefix and prefix .. k or k
					result[key] = v
					result._n = (result._n or 0) + 1
				end
			end
		end
	end
	return target_doc
end

function tracedoc.commit(doc, result, prefix)
	if doc._ignore then
		return result
	end
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
				result._n = (result._n or 0) + 1
			end
		elseif lastversion[k] ~= v then
			lastversion[k] = v
			if result then
				local key = prefix and prefix .. k or k
				result[key] = v
				result._n = (result._n or 0) + 1
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

function tracedoc.ignore(doc, enable)
	rawset(doc, "_ignore", enable)	-- ignore it during commit when enable
end

----- change set

local function genkey(keys, key)
	if keys[key] then
		return
	end
	key = key:gsub("(%.)(%d+)","[%2]")
	key = key:gsub("^(%d+)","[%1]")
	keys[key] = assert(load ("return function(doc) return doc.".. key .." end"))()
end

function tracedoc.changeset(map)
	local set = {
		watching_n = 0,
		watching = {} ,
		mapping = {} ,
		keys = {},
	}
	for _,v in ipairs(map) do
		local n = #v
		assert(n >=2 and type(v[1]) == "function")
		if n == 2 then
			local f = v[1]
			local k = v[2]
			local tq = type(set.watching[k])
			genkey(set.keys, k)
			if tq == "nil" then
				set.watching[k] = f
				set.watching_n = set.watching_n + 1
			elseif tq == "function" then
				local q = { set.watching[k], f }
				set.watching[k] = q
			else
				assert (tq == "table")
				table.insert(set.watching[k], q)
			end
		else
			table.insert(set.mapping, { table.unpack(v) })
			for i = 2, #v do
				genkey(set.keys, v[i])
			end
		end
	end
	return set
end

local function do_funcs(doc, funcs, v)
	if v == tracedoc.null then
		v = nil
	end
	if type(funcs) == "function" then
		funcs(doc, v)
	else
		for _, func in ipairs(funcs) do
			func(doc, v)
		end
	end
end

local function do_mapping(doc, mapping, changes, keys, args)
	local n = #mapping
	for i=2,n do
		local key = mapping[i]
		local v = changes[key]
		if v == nil then
			v = keys[key](doc)
		elseif v == tracedoc.null then
			v = nil
		end
		args[i-1] = v
	end
	mapping[1](doc, table.unpack(args,1,n-1))
end

function tracedoc.mapchange(doc, set, c)
	local changes = tracedoc.commit(doc, c or {})
	local changes_n = changes._n or 0
	if changes_n == 0 then
		return changes
	end
	if changes_n > set.watching_n then
		-- a lot of changes
		for key, funcs in pairs(set.watching) do
			local v = changes[key]
			if v then
				do_funcs(doc, funcs, v)
			end
		end
	else
		-- a lot of watching funcs
		local watching_func = set.watching
		for key, v in pairs(changes) do
			local funcs = watching_func[key]
			if funcs then
				do_funcs(doc, funcs, v)
			end
		end
	end
	-- mapping
	local keys = set.keys
	local tmp = {}
	for _, mapping in ipairs(set.mapping) do
		for i=2,#mapping do
			local key = mapping[i]
			if changes[key] then
				do_mapping(doc, mapping, changes, keys, tmp)
				break
			end
		end
	end
	return changes
end

function tracedoc.mapupdate(doc, set, prefix)
	local lprefix = #prefix
	local keys = set.keys
	for key, funcs in pairs(set.watching) do
		if key:sub(1, lprefix) == prefix then
			local v = keys[key](doc)
			do_funcs(doc, funcs, v)
		end
	end
	local args = {}
	for _, mapping in ipairs(set.mapping) do
		local n = #mapping
		for i=2,n do
			local key = mapping[i]
			local v = keys[key](doc)
			args[i-1] = v
		end
		mapping[1](doc, table.unpack(args,1,n-1))
	end
end

return tracedoc
