local tracedoc = require "tracedoc"

local doc = tracedoc.new {
	a = 1,
	b = { 1,2,3 },
	c = { d = 4 , e = 5 },
	d = {},
}

local function dump(doc)
	local changes = tracedoc.commit(doc, {})
	print("Dump:")
	for k,v in pairs(doc) do
		print(k,v)
		if type(v) == "table" then
			for k, v in pairs(v) do
				print("\t",k,v)
			end
		end
	end
	print("changes:")
	for k,v in pairs(changes) do
		print(k,v)
	end
end

dump(doc)

tracedoc.opaque(doc.d, true)
doc.d.x = 1	-- d change ( d is opaque)
doc.d.y = 2	-- d change ( d is opaque)

doc.a = nil	-- change

assert(doc.a == nil)
assert(doc.b[1] == 1)
assert(doc.b[2] == 2)
assert(doc.b[3] == 3)
assert(doc.c.d == 4)

doc.b[1] = 0	-- change
doc.b[2] = 2	-- not change
doc.b[3] = nil	-- remove

local tmp = doc.c

dump(doc)

doc.a = 2	-- change
assert(doc.a == 2)
doc.b = 2	-- change and delete table
assert(doc.b == 2)
doc.c = { e = 5 } -- change table
assert(doc.c.d == nil)
doc.b = nil
doc.d = setmetatable({}, { __tostring = function() return "userobject" end })	-- table with metatable is an userobject
doc.e = { x = 1, y = 2 }

dump(doc)

assert(tmp.e == 5)


